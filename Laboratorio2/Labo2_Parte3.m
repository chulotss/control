    %% SCRIPT DE CONTROL DUAL PID CON TRANSICIÓN SUAVE (BUMPLESS TRANSFER)
    clc; clear; close all;
    
    %% 1. CONEXIÓN Y CONFIGURACIÓN DE ARDUINO
    modeloBoard = 'Uno';
    puertoCOM   = 'COM5';
    try
        a = arduino(puertoCOM, modeloBoard, 'Libraries', 'RotaryEncoder');
        fprintf('Conexión exitosa con Arduino %s.\n', modeloBoard);
    catch
        error('No se pudo conectar a la placa Arduino. Revisa el puerto COM.');
    end
    
    %PIN POTENCIOMETRO 
    pinPot= 'A2';
    %PINES MOTOR 
    pinDir2 = 'D8';
    pinDir1 = 'D9';
    pinPWM = 'D10';
    pinEncA = 'D2';
    pinEncB = 'D3';
    %PIN LED 
    pinLED = 'D5';
    %PIN BOTON 
    pinBoton = 'D6';
    
    configurePin(a, pinBoton, 'DigitalInput');
    configurePin(a, pinLED, 'PWM');
    configurePin(a, pinDir1, 'DigitalOutput');
    configurePin(a, pinDir2, 'DigitalOutput');
    
    ppr = 890; 
    encoderObj = rotaryEncoder(a, pinEncA, pinEncB, ppr);
    
    writePWMDutyCycle(a, pinPWM, 0);
    writeDigitalPin(a, pinDir1, 1);
    writeDigitalPin(a, pinDir2, 0);
    
    %% 2. PARÁMETROS DE CONTROL Y COEFICIENTES
    Kp = 0.001;   
    Ki = 0.02;   
    Kd = 0.00001;    
    
    %Kp = 0.000499; 
    %Ki = 0.00335; 
    %Kd = 1.85e-05;
    
    dt = 0.05;     
    rpmMax = 200;  
    pwmMax = 1;  
    pwmMin = 0.0;  
    
    % --- Coeficientes PID Incremental: u[k] = u[k-1] + a0*e[k] + a1*e[k-1] + a2*e[k-2] ---
    a0 = Kp + (Ki * dt) + (Kd / dt);
    a1 = -Kp - (2 * Kd / dt);
    a2 = Kd / dt;
    
    % --- Variables de Estado y Control ---
    pwmSalida        = 0.0; 
    integralPos      = 0.0;
    errorAnteriorPos = 0.0;
    u_prevInc        = 0.0;
    e_k0             = 0.0;
    e_k1             = 0.0;
    e_k2             = 0.0;
    
    % --- Máquina de Estados (0: PID Base, 1: PID Incremental) ---
    modoControl   = 1; 
    estadoBotPrev = 0;     
    
    nombresModos = {'MODO PID BASE (Posicional)', 'MODO PID INCREMENTAL'};
    
    % --- CONFIGURACIÓN DE FILTRO DE MEDIA MÓVIL ---
    tamanoVentana = 3;                        
    bufferRPM     = zeros(1, tamanoVentana);   
    idxBuffer     = 1;                        
    
    %% 3. GRÁFICAS EN TIEMPO REAL
    fig = figure('Name', 'Control Dual PID', 'NumberTitle', 'off', 'Position', [100 100 900 600]);
    
    subplot(2,1,1);
    hLineRPMBruta = plot(nan, nan, 'Color', [0.7 0.7 0.7], 'LineWidth', 1); hold on; 
    hLineRPMFilt  = plot(nan, nan, 'b-', 'LineWidth', 1.8);                         
    hLineRef      = plot(nan, nan, 'g--', 'LineWidth', 1.5);
    grid on; ylabel('Velocidad (RPM)');
    hTitle = title(sprintf('Estado: %s', nombresModos{modoControl+1}));
    legend('RPM Bruta', 'RPM Filtrada', 'Setpoint', 'Location', 'southeast');
    
    subplot(2,1,2);
    hLinePWM      = plot(nan, nan, 'r-', 'LineWidth', 1.5); grid on;
    xlabel('Tiempo (s)'); ylabel('PWM Aplicado (0-0.5)');
    title('Señal de Control (D4 y D6)');
    
    tiempoData = []; rpmBrutaData = []; rpmFiltData = []; refData = []; pwmData = [];
    
    %% 4. BUCLE DE CONTROL EN TIEMPO REAL
    duracionPrueba = 60;
    resetCount(encoderObj);
    tInicio = tic;
    
    while toc(tInicio) < duracionPrueba
        tActual = toc(tInicio);
        
        % --- A. Conmutación por Botón (D5) con Transición Suave ---
        estadoBotActual = readDigitalPin(a, pinBoton);
        if estadoBotActual == 1 && estadoBotPrev == 0
            modoControl = mod(modoControl + 1, 2); % Alterna entre 0 y 1
            
            if modoControl == 0 % Se conmuta a PID Base
                % Cargar el nivel actual de PWM en el término integral
                if Ki ~= 0
                    integralPos = pwmSalida / Ki; 
                else
                    integralPos = 0.0;
                end
                errorAnteriorPos = 0.0;
            else % Se conmuta a PID Incremental
                u_prevInc = pwmSalida;
                e_k0      = 0.0;
                e_k1      = 0.0;
                e_k2      = 0.0;
            end
            
            fprintf('-> Cambio de Estado: %s\n', nombresModos{modoControl+1});
        end
        estadoBotPrev = estadoBotActual;
        
        % --- B. Lectura del Potenciómetro (A1) ---
        voltajePot = readVoltage(a, pinPot); 
        
        % --- C. Lectura de Encoder ---
        rpmBruta = readSpeed(encoderObj);
        
        % --- D. Filtro Media Móvil ---
        bufferRPM(idxBuffer) = rpmBruta;                  
        idxBuffer = mod(idxBuffer, tamanoVentana) + 1;    
        rpmFiltrada = mean(bufferRPM);                    
        
        % --- E. Selección del Algoritmo de Control ---
        setpointRPM = (voltajePot / 5.0) * rpmMax;
        
        switch modoControl
            case 0 % --- PID Base (Posicional Clásico) ---
                errorRPM = setpointRPM - rpmFiltrada;
                
                P = Kp * errorRPM;
                integralPos = integralPos + (errorRPM * dt);
                I = Ki * integralPos;
                derivada = (errorRPM - errorAnteriorPos) / dt;
                D = Kd * derivada;
                errorAnteriorPos = errorRPM;
                
                u = P + I + D;
                
                % Anti-Windup clásico
                if u > pwmMax
                    u = pwmMax;
                    integralPos = integralPos - (errorRPM * dt); 
                elseif u < pwmMin
                    u = pwmMin;
                    integralPos = integralPos - (errorRPM * dt);
                end
                
                pwmSalida = u;
                rpmReferencia = setpointRPM;
                
            case 1 % --- PID Incremental ---
               
                % Actualizar historial de error
                e_k2 = e_k1;
                e_k1 = e_k0;
                e_k0 = setpointRPM - rpmFiltrada;
                
                % Ecuación de diferencias u[k] = u[k-1] + a0*e[k] + a1*e[k-1] + a2*e[k-2]
                u_k = u_prevInc + (a0 * e_k0) + (a1 * e_k1) + (a2 * e_k2);
                
                % Saturación
                pwmSalida = max(pwmMin, min(pwmMax, u_k));
                u_prevInc = pwmSalida;
                
                rpmReferencia = setpointRPM;
        end
        
        % --- F. Salida PWM a Motor y LED ---
        writePWMDutyCycle(a, pinPWM, pwmSalida);
        writePWMDutyCycle(a, pinLED, pwmSalida);
        
        % --- G. Graficar ---
        tiempoData(end+1)   = tActual;
        rpmBrutaData(end+1) = rpmBruta;
        rpmFiltData(end+1)  = rpmFiltrada;
        refData(end+1)      = rpmReferencia;
        pwmData(end+1)      = pwmSalida;
        
        set(hLineRPMBruta, 'XData', tiempoData, 'YData', rpmBrutaData);
        set(hLineRPMFilt,  'XData', tiempoData, 'YData', rpmFiltData);
        set(hLineRef,       'XData', tiempoData, 'YData', refData);
        set(hLinePWM,       'XData', tiempoData, 'YData', pwmData);
        set(hTitle, 'String', sprintf('Estado: %s', nombresModos{modoControl+1}));
        
        subplot(2,1,1); xlim([0, duracionPrueba]);
        subplot(2,1,2); xlim([0, duracionPrueba]); ylim([0, 0.6]);
        drawnow;
        
        pause(dt);
    end
    
    %% APAGADO DE SEGURIDAD
    writePWMDutyCycle(a, pinPWM, 0);
    writePWMDutyCycle(a, pinLED, 0);
    writeDigitalPin(a, pinDir1, 0);
    writeDigitalPin(a, pinDir2, 0);