%% SCRIPT DE CONTROL Y PRUEBAS EN ARDUINO CON MATLAB (20s POR PRUEBA)
% Script con rampa PWM de Subida (0 a 0.5) y Bajada (0.5 a 0) en Motor (D4) y LED (D6).

clc; clear; close all;

%% 1. CONEXIÓN ARDUINO - MATLAB
modeloBoard = 'Uno'; % Cambiar a 'Uno' si aplica
puertoCOM   = 'COM4';

try
    a = arduino(puertoCOM, modeloBoard, 'Libraries', 'RotaryEncoder');
    fprintf('Conexión con Arduino (%s) establecida correctamente.\n', modeloBoard);
catch
    error('No se pudo conectar a la placa. Verifica el puerto COM y la conexión.');
end

%% CONFIGURACIÓN DE PINES (CONFIGURACIÓN FIJA DEFINIDA POR EL USUARIO)
pinBoton   = 'D5';  % Entrada digital
pinLED     = 'D6';  % Salida PWM/Digital (LED)
pinPot     = 'A1';  % Entrada analógica
pinPWM     = 'D4';  % Salida PWM (Enable Driver)
pinDir1    = 'D12'; % Dirección Motor IN1
pinDir2    = 'D13'; % Dirección Motor IN2
pinEncA    = 'D2';  % Canal A Encoder (Pin de Interrupción)
pinEncB    = 'D3';  % Canal B Encoder (Pin de Interrupción)

% Configuración del modo de cada pin
configurePin(a, pinBoton, 'DigitalInput');
configurePin(a, pinLED, 'PWM'); % Se configura como PWM para controlar su brillo
configurePin(a, pinDir1, 'DigitalOutput');
configurePin(a, pinDir2, 'DigitalOutput');

% Inicialización del objeto Encoder (800 Pulsos Por Revolución)
ppr = 850; 
encoderObj = rotaryEncoder(a, pinEncA, pinEncB, ppr);

% Tiempo asignado por cada prueba secuencial
duracionPrueba = 20; % Tiempo en segundos

%% ========================================================================
% PRUEBA 1: ENTRADA Y SALIDA DIGITAL (Duración: 20 segundos)
% ========================================================================
disp('------------------------------------------------------------');
disp('PRUEBA 1: Entrada Digital (D5) y Salida Digital (D6)');
disp('Instrucción: Presiona el botón en D5 para encender o apagar el LED en D6.');
disp('------------------------------------------------------------');

tic;
while toc < duracionPrueba
    % 2. Lectura y Escritura Digital
    estadoBoton = readDigitalPin(a, pinBoton);
    
    if estadoBoton == 1
        writePWMDutyCycle(a, pinLED, 1); % Encendido completo
    else
        writePWMDutyCycle(a, pinLED, 0); % Apagado completo
    end
    
    pause(0.05); % Pausa para estabilizar la lectura
end
writePWMDutyCycle(a, pinLED, 0); % Apagado de seguridad
disp('--> Prueba 1 finalizada.');

%% ========================================================================
% PRUEBA 2: ENTRADA ANALÓGICA (Duración: 20 segundos)
% ========================================================================
disp('------------------------------------------------------------');
disp('PRUEBA 2: Entrada Analógica (A1)');
disp('Instrucción: Varía el potenciómetro en A1 para ver el voltaje.');
disp('------------------------------------------------------------');

tic;
while toc < duracionPrueba
    % 2. Lectura Analógica
    voltajePot = readVoltage(a, pinPot);
    fprintf('Voltaje en Potenciómetro (%s): %.2f V\n', pinPot, voltajePot);
    pause(0.5); % Mapeo de datos cada 500 ms
end
disp('--> Prueba 2 finalizada.');

%% ========================================================================
% PRUEBA 3: RAMPA PWM DE SUBIDA Y BAJADA (0 -> 0.5 -> 0), MOTOR, LED Y PLOT
% COMPARATIVA: resetCount vs readSpeed
% ========================================================================
disp('------------------------------------------------------------');
disp('PRUEBA 3: Rampa PWM con Comparativa en Tiempo Real (resetCount vs readSpeed)');
disp('Instrucción: Se genera aceleración y desaceleración continua.');
disp('------------------------------------------------------------');

% 4. Control de Dirección (Sentido Horario)
writePWMDutyCycle(a, pinPWM, 0);
writeDigitalPin(a, pinDir1, 1);
writeDigitalPin(a, pinDir2, 0);

% 7. Configuración del Plot para Velocidad y PWM
figure('Name', 'Monitoreo Rampa PWM Subida/Bajada y Comparativa de Velocidad', 'NumberTitle', 'off');

% Subplot 1: Rampa PWM aplicada
subplot(2,1,1);
hLinePWM = plot(nan, nan, 'r-', 'LineWidth', 1.5);
grid on;
ylabel('Ciclo PWM (0 a 0.5)');
title('Rampa Triangulada de Ciclo PWM en D4 y D6');

% Subplot 2: Comparativa de Velocidad resultante en RPM
subplot(2,1,2);
hLineVelManual = plot(nan, nan, 'b-', 'LineWidth', 1.2, 'DisplayName', 'Manual (resetCount)');
hold on;
hLineVelNativa = plot(nan, nan, 'm--', 'LineWidth', 1.5, 'DisplayName', 'Nativa (readSpeed)');
hold off;
grid on;
xlabel('Tiempo (s)');
ylabel('Velocidad (RPM)');
title('Comparativa de Velocidad del Motor: Cálculo Manual vs readSpeed');
legend('Location', 'northwest');

dt = 0.02; % Tiempo de muestreo deseado (20 ms)
tiempoData         = [];
pwmData            = [];
velocidadManualData = [];
velocidadNativaData = [];
mitadTiempo = duracionPrueba / 2; % 10 segundos para subida y 10 para bajada

% Inicializamos el contador del encoder a 0 antes del bucle
resetCount(encoderObj);

tInicioPrueba  = tic;
tLecturaPrevia = tic; % Cronómetro para medir el dt real de ejecución

while toc(tInicioPrueba) < duracionPrueba
    tActual = toc(tInicioPrueba);
    
    % --- 3. Generación de Rampa Triangulada (Subida 0->0.5 y Bajada 0.5->0) ---
    if tActual <= mitadTiempo
        dutyCycle = (tActual / mitadTiempo) * 0.5;
    else
        dutyCycle = 0.5 - ((tActual - mitadTiempo) / mitadTiempo) * 0.5;
    end
    
    % Aseguramos límites entre 0 y 0.5
    dutyCycle = max(0.0, min(0.5, dutyCycle));
    
    % Aplicamos el PWM tanto al motor como al LED
    writePWMDutyCycle(a, pinPWM, dutyCycle);
    writePWMDutyCycle(a, pinLED, dutyCycle);
    
    % --- 5. Método 1: Cálculo Manual de Velocidad (resetCount) ---
    cuentas = readCount(encoderObj); % Se leen los pulsos acumulados en este intervalo
    resetCount(encoderObj);          % Se reinicia el contador a 0 para la siguiente iteración
    
    dtActual = toc(tLecturaPrevia);   % Tiempo exacto transcurrido entre lecturas
    tLecturaPrevia = tic;             % Reinicio del timer para el próximo ciclo
    
    % Cálculo manual considerando cuadratura (PPR * 4) y el delta de tiempo real
    rpmManual = (cuentas / (ppr * 4)) * (60 / dtActual);
    
    % --- 6. Método 2: Función Nativa (readSpeed) ---
    rpmNativa = readSpeed(encoderObj);
    
    % Registro de vectores para visualización
    tiempoData(end+1)          = tActual;
    pwmData(end+1)             = dutyCycle;
    velocidadManualData(end+1) = rpmManual;
    velocidadNativaData(end+1) = rpmNativa;
    
    % --- 7. Actualización del Plot ---
    set(hLinePWM, 'XData', tiempoData, 'YData', pwmData);
    set(hLineVelManual, 'XData', tiempoData, 'YData', velocidadManualData);
    set(hLineVelNativa, 'XData', tiempoData, 'YData', velocidadNativaData);
    
    subplot(2,1,1); xlim([0, duracionPrueba]); ylim([0, 0.6]);
    subplot(2,1,2); xlim([0, duracionPrueba]);
    drawnow;
    
    pause(dt);
end
%% APAGADO DE SEGURIDAD
writePWMDutyCycle(a, pinPWM, 0);
writePWMDutyCycle(a, pinLED, 0);
writeDigitalPin(a, pinDir1, 0);
writeDigitalPin(a, pinDir2, 0);
disp('------------------------------------------------------------');
disp('Todas las pruebas secuenciales han concluido. Motor y LED apagados.');
disp('------------------------------------------------------------');