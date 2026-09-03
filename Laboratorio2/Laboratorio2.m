clc; clear; close all;

modeloBoard = 'Uno';
puertoCOM = 'COM5';
%CONEXION ARDUINO
try 
    a=arduino(puertoCOM, modeloBoard, 'Libraries','RotaryEncoder');
    fprintf('Conexion con Arduino (%s) establecida correctamente. \n', modeloBoard);
catch
    error('No se pudo conectar la placa. Verificar el puerto COM y la conexion.');
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
pinLed = 'D5';
%PIN BOTON 
pinBoton = 'D6';
%CONFIGURACION DE LOS PINES 
configurePin(a,pinDir1, 'DigitalOutput');
configurePin(a,pinDir2, 'DigitalOutput');
configurePin(a, pinLed, 'PWM');
configurePin(a, pinBoton, 'DigitalInput');
    
%TIEMPO DE PRUEBA EN S
duracionPrueba =30; 
%INICIALICACION OBJETO ENCONDER (850 PULSOS POR REVOLUCION)
ppr= 850; 
encoderObj=rotaryEncoder(a, pinEncA,pinEncB,ppr);
%VARIABLES DE ESTADO 
est1=1;
est2=0;
aux=0;
%CONFIGURACION DEL CONTROL DE LA DIRECCION DEL PUENTE H
writePWMDutyCycle(a,pinPWM, 0);
writeDigitalPin(a, pinDir1, est1);
writeDigitalPin(a, pinDir2, est2); 

%TIEMPO DE MUESTREO EN mS (20 ms)
dt=0.02; 
tiempoData          =[];
pwmData             =[]; 
velocidadNativaData =[];
%INICIALIZAR EL CONTADOR DEL ENCODER A 0 ANTES DEL WHILE 
resetCount(encoderObj);
tInicioPrueba = tic;
tLecturaPrevia = tic; %Cronometro para medir el dt real de ejecucion

% GRAFICAS
figure;

subplot(2,1,1);

hLinePWM = plot(nan, nan, 'b-', ...
    'LineWidth', 1.5, ...
    'DisplayName', 'PWM');

grid on;
xlabel('Tiempo (s)');
ylabel('Duty Cycle');
title('PWM aplicado al motor');
legend('Location', 'northwest');

xlim([0 duracionPrueba]);
ylim([0 0.5]);

% --- Grafica velocidad ---
subplot(2,1,2);

hLineVelNativa = plot(nan, nan, 'm-', ...
    'LineWidth', 1.5, ...
    'DisplayName', 'RPM');

grid on;
xlabel('Tiempo (s)');
ylabel('Velocidad (RPM)');
title('Velocidad del motor');

legend('Location', 'northwest');

xlim([0 duracionPrueba]);
%MAIN

while toc(tInicioPrueba) < duracionPrueba
    tActual=toc(tInicioPrueba);
    %RECOLECCION DATOS BOTON 
    estadoBoton = readDigitalPin(a, pinBoton);
    voltajePot=readVoltage(a, pinPot);
    %fprintf('Voltaje en Potenciometro (%s): %.2f V\n', pinPot, voltajePot);
    ValorPWM=voltajePot*0.1;
    %ASEGURAR EL VALOR ENTRE 0 Y 0.5 
    ValorPWM = max(0.0, min(0.5, ValorPWM));
    fprintf('Valor de PwM: %.2f\n', ValorPWM);
    %APLICAR EL VALOR DEL PWM AL MOTOR 
    writePWMDutyCycle(a, pinPWM, ValorPWM);
    writePWMDutyCycle(a, pinLed, ValorPWM);
    %FUNSION NATIVA 
    rpmNativa = readSpeed(encoderObj);
    %Registro de vectores 
    tiempoData(end+1)               = tActual; 
    pwmData(end+1)                  = ValorPWM;
    velocidadNativaData(end+1)      =rpmNativa; 
    fprintf ('La velocidad actual es de: %.2f RPM\n',rpmNativa);
    %CAMBIO DE ESTADO 
    if estadoBoton == 1
        aux=est2;
        est2=est1;
        est1=aux;
        %fprintf('estado1: %.2f estado2: %.2f \n',est1,est2);
        writePWMDutyCycle (a, pinPWM, 0);
        pause(0.5);
        writeDigitalPin(a, pinDir1, est1);
        writeDigitalPin(a, pinDir2, est2); 
        writePWMDutyCycle (a, pinPWM, ValorPWM);
    else 
        aux=est1;
    end
        
    set(hLinePWM, 'XData', tiempoData, 'YData', pwmData);
    set(hLineVelNativa, 'XData', tiempoData, 'YData', velocidadNativaData);
    
    subplot(2,1,1);
    xlim([0, duracionPrueba]);
    ylim=([0, 0.5]);
    
    subplot(2,1,2);
    xlim([0, duracionPrueba]);
    
    drawnow;

    pause(dt);
end
writePWMDutyCycle (a, pinPWM, 0);
writeDigitalPin(a, pinDir1, 0); 
writeDigitalPin(a, pinDir2, 0);
writePWMDutyCycle(a, pinLed,0);
disp('Prueba finalizada.')


