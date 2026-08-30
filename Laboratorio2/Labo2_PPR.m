%% SCRIPT UNIFICADO DE CALIBRACIÓN DE PPR Y PRUEBA DE 1 VUELTA EXACTA
% Opción 1: Giro manual con motor desconectado.
% Opción 2: Ajuste motorizado con potenciómetro (A1) e inversión de giro (D5).
% Opción 3: Prueba automática de 1 vuelta exacta según PPR ingresados.

clc; clear; close all;

%% 1. CONEXIÓN ARDUINO - MATLAB
modeloBoard = 'Mega2560'; % Cambiar a 'Uno' si aplica
puertoCOM   = 'COM3';

try
    a = arduino(puertoCOM, modeloBoard, 'Libraries', 'RotaryEncoder');
    fprintf('Conexión con Arduino (%s) establecida correctamente.\n', modeloBoard);
catch
    error('No se pudo conectar a la placa. Verifica el puerto COM.');
end

%% CONFIGURACIÓN FIJA DE PINES
pinBoton   = 'D5';  % Entrada digital (Inversión de giro)
pinLED     = 'D6';  % Salida digital (Indicador de sentido / Parpadeo)
pinPot     = 'A1';  % Entrada analógica (Control de PWM / Velocidad)
pinPWM     = 'D4';  % Salida PWM (Enable Driver)
pinDir1    = 'D22'; % Dirección Motor IN1
pinDir2    = 'D23'; % Dirección Motor IN2
pinEncA    = 'D2';  % Canal A Encoder
pinEncB    = 'D3';  % Canal B Encoder

configurePin(a, pinBoton, 'DigitalInput');
configurePin(a, pinLED, 'DigitalOutput');
configurePin(a, pinDir1, 'DigitalOutput');
configurePin(a, pinDir2, 'DigitalOutput');

% APAGADO INICIAL DE SEGURIDAD
writePWMDutyCycle(a, pinPWM, 0);
writeDigitalPin(a, pinDir1, 0);
writeDigitalPin(a, pinDir2, 0);
writeDigitalPin(a, pinLED, 0);

%% MENÚ PRINCIPAL
disp('============================================================');
disp('          MENÚ DE PRUEBAS Y CALIBRACIÓN DE PPR             ');
disp('============================================================');
disp('1. Método Manual (Motor desconectado, giro a mano para 1 vuelta)');
disp('2. Ajuste Motorizado (Potenciómetro A1 + Inversión con Botón D5)');
disp('3. Prueba Automática de 1 Vuelta Exacta (Ingresando PPR)');
disp('------------------------------------------------------------');
opcion = input('Seleccione una opción (1, 2 o 3): ');

if opcion ~= 1 && opcion ~= 2 && opcion ~= 3
    error('Opción no válida. Reinicie el programa y seleccione 1, 2 o 3.');
end

% Inicialización del Encoder (PPR = 1 para obtener cuentas puras de cuadratura)
encoderObj = rotaryEncoder(a, pinEncA, pinEncB, 1);

%% ========================================================================
% OPCIÓN 1: MÉTODO MANUAL (MOTOR DESCONECTADO Y GIRO A MANO)
% ========================================================================
if opcion == 1
    disp(' ');
    disp('============================================================');
    disp('                  MÉTODO MANUAL: GIRO A MANO                 ');
    disp('============================================================');
    disp('ADVERTENCIA: Desconecta la potencia del motor (VM / 12V).');
    input('Presiona ENTER cuando estés listo para comenzar...');
    
    resetCount(encoderObj);
    pulsosAnteriores = -1;
    
    disp('------------------------------------------------------------');
    disp('Gira el motor MANUALMENTE exactamente 1 vuelta.');
    disp('Presiona Ctrl+C en la ventana de comandos para finalizar.');
    disp('------------------------------------------------------------');
    
    try
        while true
            pulsosActuales = readCount(encoderObj);
            
            if pulsosActuales ~= pulsosAnteriores
                pulsosAnteriores = pulsosActuales;
                fprintf('\r[MONITOREO MANUAL] Pulsos Acumulados: %4d cuentas', pulsosActuales);
            end
            pause(0.02);
        end
    catch
        fprintf('\n\n------------------------------------------------------------\n');
        disp('Lectura finalizada.');
        fprintf('Total de pulsos registrados en 1 vuelta: %d cuentas.\n', pulsosActuales);
        disp('------------------------------------------------------------');
    end

%% ========================================================================
% OPCIÓN 3: PRUEBA SIMPLIFICADA (VUELTAS + PWM + RAMPA CON PISO DE INERCIA)
% ========================================================================
elseif opcion == 3
    disp(' ');
    disp('============================================================');
    disp('   MÉTODO 3: CONTROL DE VUELTAS CON RAMPA Y ARRANQUE SUAVE   ');
    disp('============================================================');
    
    pprIngresado = input('Ingrese los PPR de su motor/encoder (ej. 800 o 3200): ');
    numVueltas   = input('Ingrese la cantidad de vueltas a dar (ej. 1, 2.5, 5): ');
    pwmLimite    = input('Ingrese el PWM máximo deseado (0.1 a 0.50) [Recomendado: 0.25]: ');
    pwmLimite    = max(0.1, min(0.50, pwmLimite)); % Límite de seguridad
    
    % Cálculo de la meta total de pulsos
    pulsosObjetivo = round(pprIngresado * numVueltas);
    
    input('\nPresione ENTER para iniciar el movimiento...');
    
    % Configurar dirección (Sentido Horario)
    writeDigitalPin(a, pinDir1, 1);
    writeDigitalPin(a, pinDir2, 0);
    
    resetCount(encoderObj);
    pulsosActuales   = 0;
    pulsosAnteriores = -1;
    
    % ---------------------------------------------------------------------
    % FASE 1: ARRANQUE PROGRESIVO PARA ROMPER INERCIA
    % ---------------------------------------------------------------------
    disp('--> Rompiendo inercia inicial...');
    pwmArranque = 0.05;
    
    while pulsosActuales == 0 && pwmArranque <= pwmLimite
        writePWMDutyCycle(a, pinPWM, pwmArranque);
        pause(0.02);
        pulsosActuales = abs(readCount(encoderObj));
        if pulsosActuales == 0
            pwmArranque = pwmArranque + 0.001; % Sube poco a poco hasta que empiece a girar
            disp(pwmArranque)
        end
    end
    
    % Aseguramos que el PWM de arranque no supere el límite del usuario
    pwmArranque = min(pwmLimite, pwmArranque);
    fprintf('   [OK] PWM de arranque detectado: %4.3f\n\n', pwmArranque);
    
    % ---------------------------------------------------------------------
    % FASE 2: RECORRIDO PRINCIPAL Y RAMPA DE DESACELERACIÓN
    % ---------------------------------------------------------------------
    zonaFrenado = round(pulsosObjetivo * 0.30); % La desaceleración inicia al faltar el 30%
    
    while pulsosActuales < pulsosObjetivo
        pulsosActuales = abs(readCount(encoderObj));
        pulsosRestantes = pulsosObjetivo - pulsosActuales;
        
        % Cálculo del PWM Progresivo
        if pulsosRestantes <= zonaFrenado && pulsosRestantes > 0
            % Factor decreciente de 1 a 0
            factorProporcional = pulsosRestantes / zonaFrenado;
            
            % Disminuimos el PWM paulatinamente
            pwmDinamico = factorProporcional * pwmLimite;
            
            % El piso inferior se fija en pwmArranque para garantizar movimiento continuo
            pwmAplicado = max(pwmArranque, min(pwmLimite, pwmDinamico));
        else
            % Velocidad constante de crucero
            pwmAplicado = pwmLimite;
        end
        
        % Aplicar PWM al motor
        writePWMDutyCycle(a, pinPWM, pwmAplicado);
        
        % Progreso en consola
        porcentaje = min(100, (pulsosActuales / pulsosObjetivo) * 100);
        fprintf('\r[EJECUCIÓN] Pulsos: %5d / %5d | PWM: %4.3f | Progreso: %5.1f%%', ...
                pulsosActuales, pulsosObjetivo, pwmAplicado, porcentaje);
        
        pause(0.005);
    end
    
    % ---------------------------------------------------------------------
    % FASE 3: APAGADO PASIVO FINAL
    % ---------------------------------------------------------------------
    writePWMDutyCycle(a, pinPWM, 0);
    writeDigitalPin(a, pinDir1, 0);
    writeDigitalPin(a, pinDir2, 0);
    
    % Parpadeo del LED como indicación visual de meta
    for k = 1:3
        writeDigitalPin(a, pinLED, 1); pause(0.15);
        writeDigitalPin(a, pinLED, 0); pause(0.15);
    end
    
    pause(0.2);
    pulsosFinales = abs(readCount(encoderObj));
    vueltasReales = pulsosFinales / pprIngresado;
    
    fprintf('\n\n============================================================\n');
    disp('¡RECORRIDO COMPLETADO!');
    fprintf('Vueltas solicitadas : %.2f vueltas\n', numVueltas);
    fprintf('Vueltas reales      : %.2f vueltas\n', vueltasReales);
    fprintf('Pulsos objetivo     : %d cuentas\n', pulsosObjetivo);
    fprintf('Pulsos finales      : %d cuentas\n', pulsosFinales);
    fprintf('Error de sobrepaso  : %+d cuentas\n', pulsosFinales - pulsosObjetivo);
    disp('============================================================\n');
end
%% APAGADO DE SEGURIDAD FINAL
writePWMDutyCycle(a, pinPWM, 0);
writeDigitalPin(a, pinDir1, 0);
writeDigitalPin(a, pinDir2, 0);
writeDigitalPin(a, pinLED, 0);

disp('============================================================');
disp('                   MOTOR DETENIDO Y SALIDA                  ');
disp('============================================================');