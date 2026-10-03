%% IDENTIFICACION AUTOMATICA MOTOR DC CON ENCODER (ESCALON / RAMPA - MULTICICLO)
clc
clear
close all

%% ===============================
% PARAMETROS CONFIGURABLES
% ===============================
puerto = "COM5";          % Puerto Arduino
board = "Uno";       % Tipo de placa




pinPWM = "D10";            % Pin PWM motor
dir1   = 'D9';           % Direccion 1
dir2   = 'D8';           % Direccion 2
pinEncA = "D2";           % Encoder canal A
pinEncB = "D3";           % Encoder canal B
Ts = 0.02;                % Tiempo de muestreo
Texp = 10;                % Duracion del experimento en segundos (aprox.)
pulsos_rev = 840;         % Pulsos por revolucion encoder
PWM_max = 0.20;            % Porcentaje de PWM maximo (0-1)
PWM_step = 0.05;          % Salto de PWM por datos N (para modo escalon)
PWM_inicial = 0.15;       % PWM aplicado inicial
num_ciclos = 1;           % Numero de ciclos a ejecutar
orden_ss = 2;             % Numero de estados

% --- TIPO DE EXPERIMENTO ---
% "escalon" -> Incrementos discretos por tramos
% "rampa"   -> Cambio continuo e incremental suave por muestra Ts
modo_experimento = "escalon"; 

%% ===== PARAMETRO FILTRO EN TIEMPO REAL (MEDIA MOVIL) =====
N_media = 10;   % Numero de muestras para promedio durante la lectura

%% ===== CONFIGURACION FILTRADO PARA IDENTIFICACION =====
aplicar_filtro_ident = false;          % true: Filtra los datos antes de ssest | false: Usa datos crudos
tipo_filtro_ident    = "idfilt";      % Opciones: "idfilt", "butterworth", "movmean"

% Parametros para cada filtro:
fc_corte = 5;       % Frecuencia de corte en Hz (para "idfilt" y "butterworth")
win_movmean = 15;   % Ventana de suavizado (para "movmean")

%% ===============================
% CONEXION CON ARDUINO
% ===============================
a = arduino(puerto,board,"Libraries","rotaryEncoder");
enc = rotaryEncoder(a,pinEncA,pinEncB,pulsos_rev);

%% ===============================
% INICIALIZACION Y CALCULO DE TRAMOS
% ===============================
num_pasos = (PWM_max - PWM_inicial) / PWM_step;
% Muestras por escalon/bloque basico (asegurado como entero)
N_pwm_step = round(Texp / (2 * num_pasos + 1) / Ts);

% Calculo de tramos por ciclo (forzados a enteros)
N_tramo_subida = round(num_pasos * N_pwm_step);
N_tramo_meseta = round(N_pwm_step); % Tiempo en PWM_max
N_tramo_bajada = round(num_pasos * N_pwm_step);
N_ciclo = N_tramo_subida + N_tramo_meseta + N_tramo_bajada;

% Tramo inicial y final de reposo global
N_reposo_inicial = round(N_pwm_step);
N_reposo_final   = round(N_pwm_step);

% Muestras totales del experimento global (Entero estricto para zeros)
N_total = round(N_reposo_inicial + (N_ciclo * num_ciclos) + N_reposo_final);
u = zeros(N_total,1);
y = zeros(N_total,1);
t = (0:N_total-1)*Ts;

% Pendiente incremental por muestra Ts para modo rampa continua
delta_PWM_subida = (PWM_max - PWM_inicial) / N_tramo_subida;
delta_PWM_bajada = (PWM_max - PWM_inicial) / N_tramo_bajada;

% Buffer para media movil en tiempo real
rpm_buffer = zeros(N_media,1);

% Configurar sentido de giro
writePWMDutyCycle(a,pinPWM, 0);
writeDigitalPin(a,dir1,1);
writeDigitalPin(a,dir2,0);
resetCount(enc);
disp(["Iniciando experimento en MODO: ", upper(modo_experimento), " (", num2str(num_ciclos), " ciclos)"])

%% ===============================
% EXPERIMENTO AUTOMATICO
% ===============================
idx_global = 1;

% ---------------------------------------------------------------
% 1. REPOSO INICIAL GLOBAL (Motor parado: u = 0)
% ---------------------------------------------------------------
disp("Tomando datos de reposo INICIAL (u = 0)");
writePWMDutyCycle(a, pinPWM, 0);
for k = 1:N_reposo_inicial
    t_paso = tic;
    
    rpm = readSpeed(enc);
    rpm_buffer = [rpm; rpm_buffer(1:end-1)];
    rpm_filtrado = mean(rpm_buffer);
    
    u(idx_global) = 0;
    y(idx_global) = rpm_filtrado;
    
    idx_global = idx_global + 1;
    
    t_ejecucion = toc(t_paso);
    if Ts > t_ejecucion
        pause(Ts - t_ejecucion);
    end
end

% ---------------------------------------------------------------
% 2. EJECUCION DE LOS CICLOS DE EXPERIMENTACION
% ---------------------------------------------------------------
for ciclo = 1:num_ciclos
    disp(["Inicio del Ciclo ", num2str(ciclo), " de ", num2str(num_ciclos)]);
    PWM = PWM_inicial; % Reiniciar PWM inicial para cada ciclo
    
    for k = 1:N_ciclo
        t_paso = tic; % Cronometro para controlar Ts
        
        if strcmp(modo_experimento, "escalon")
            % =============================================
            % MODO ESCALON (PASOS DISCRETOS)
            % =============================================
            if k <= N_tramo_subida
                if mod(k-1, N_pwm_step) == 0 && k > 1
                    PWM = PWM + PWM_step;
                    if PWM > PWM_max, PWM = PWM_max; end
                    disp(["Subiendo PWM (Escalón):", num2str(PWM)]);
                elseif k == 1
                    disp(["Iniciando PWM del ciclo:", num2str(PWM)]);
                end
            elseif k <= (N_tramo_subida + N_tramo_meseta)
                if k == (N_tramo_subida + 1)
                    PWM = PWM_max;
                    disp(["Manteniendo PWM Maximo:", num2str(PWM)]);
                end
            else
                k_bajada = k - (N_tramo_subida + N_tramo_meseta);
                if mod(k_bajada-1, N_pwm_step) == 0
                    PWM = PWM - PWM_step;
                    if PWM < PWM_inicial, PWM = PWM_inicial; end
                    disp(["Bajando PWM (Escalón):", num2str(PWM)]);
                end
            end
            
        elseif strcmp(modo_experimento, "rampa")
            % =============================================
            % MODO RAMPA (VARIACION CONTINUA POR Ts)
            % =============================================
            if k <= N_tramo_subida
                % Subida continua
                if k == 1
                    PWM = PWM_inicial;
                    disp("Iniciando Rampa de Subida...");
                else
                    PWM = PWM + delta_PWM_subida;
                end
                if PWM > PWM_max, PWM = PWM_max; end
                
            elseif k <= (N_tramo_subida + N_tramo_meseta)
                % Meseta constante en PWM_max
                if k == (N_tramo_subida + 1)
                    disp(["Iniciando Meseta PWM Máximo: ", num2str(PWM_max)]);
                end
                PWM = PWM_max;
                
            else
                % Bajada continua
                if k == (N_tramo_subida + N_tramo_meseta + 1)
                    disp("Iniciando Rampa de Bajada...");
                end
                PWM = PWM - delta_PWM_bajada;
                if PWM < PWM_inicial, PWM = PWM_inicial; end
            end
        end
        
        % Aplicar PWM
        writePWMDutyCycle(a, pinPWM, PWM);
        
        % Leer encoder
        rpm = readSpeed(enc);
        
        %% ===== FILTRO MEDIA MOVIL =====
        rpm_buffer = [rpm; rpm_buffer(1:end-1)];
        rpm_filtrado = mean(rpm_buffer);
        
        y(idx_global) = rpm_filtrado;
        u(idx_global) = PWM;
        
        idx_global = idx_global + 1;
        
        % Control estricto del periodo de muestreo Ts
        t_ejecucion = toc(t_paso);
        if Ts > t_ejecucion
            pause(Ts - t_ejecucion);
        end
    end
end

% ---------------------------------------------------------------
% 3. REPOSO FINAL GLOBAL (Motor parado: u = 0)
% ---------------------------------------------------------------
disp("Tomando datos de reposo FINAL (u = 0)");
writePWMDutyCycle(a, pinPWM, 0);
for k = 1:N_reposo_final
    t_paso = tic;
    
    rpm = readSpeed(enc);
    rpm_buffer = [rpm; rpm_buffer(1:end-1)];
    rpm_filtrado = mean(rpm_buffer);
    
    u(idx_global) = 0;
    y(idx_global) = rpm_filtrado;
    
    idx_global = idx_global + 1;
    
    t_ejecucion = toc(t_paso);
    if Ts > t_ejecucion
        pause(Ts - t_ejecucion);
    end
end

disp("Experimento terminado")

%% ===============================
% PREPROCESAMIENTO Y FILTRADO DE DATOS
% ===============================
data_raw = iddata(y, u, Ts);
data = data_raw; % Por defecto usa los datos sin filtro adicional

if aplicar_filtro_ident
    disp(["Aplicando filtro para identificación: ", tipo_filtro_ident]);
    
    switch lower(tipo_filtro_ident)
        case "idfilt"
            % idfilt: Filtro paso bajo de Butterworth de 5to orden (System ID Toolbox)
            % Wn se especifica en rad/s (o frecuencia de corte escalada)
            Wn = 2 * pi * fc_corte; 
            data = idfilt(data_raw, 5, Wn / (pi/Ts));
            
        case "butterworth"
            % Filtro paso bajo Butterworth de fase cero (Signal Processing Toolbox)
            fs = 1/Ts;
            [b_filt, a_filt] = butter(4, fc_corte / (fs/2), 'low');
            y_filtrado = filtfilt(b_filt, a_filt, y);
            data = iddata(y_filtrado, u, Ts);
            
        case "movmean"
            % Media móvil fuera de línea (sin desfase temporal)
            y_filtrado = movmean(y, win_movmean);
            data = iddata(y_filtrado, u, Ts);
            
        otherwise
            warning("Tipo de filtro desconocido. Se utilizarán los datos crudos.");
    end
end

%% ===============================
% IDENTIFICACION DEL SISTEMA
% ===============================
opt = ssestOptions;
opt.EnforceStability = true;
opt.Display = 'on'; 
opt.Focus = 'simulation'; 
orden = orden_ss;
sys = ssest(data, orden, 'Form', 'canonical', opt);

%% ===============================
% MATRICES DEL ESPACIO DE ESTADOS
% ===============================
A = sys.A;
B = sys.B;
C = sys.C;
D = sys.D;
assignin("base","A",A)
assignin("base","B",B)
assignin("base","C",C)
assignin("base","D",D)
disp("Matrices continuas guardadas en workspace")

%% ===============================
% COMPARACION MODELO vs DATOS
% ===============================
figure
if aplicar_filtro_ident
    compare(data_raw, sys, data)
    legend('Datos Reales (Medidos)', 'Modelo Identificado', 'Datos Filtrados')
else
    compare(data, sys)
end
title(["Modelo identificado vs datos (Modo: ", upper(modo_experimento), ")"])

%% ===============================
% MODELO DISCRETO
% ===============================
sysd = c2d(sys,Ts);
Ad = sysd.A;
Bd = sysd.B;
Cd = sysd.C;
Dd = sysd.D;
assignin("base","Ad",Ad)
assignin("base","Bd",Bd)
assignin("base","Cd",Cd)
assignin("base","Dd",Dd)
assignin("base","sysd",sysd)
disp("Modelo discreto guardado")

clear a;
clear enc;