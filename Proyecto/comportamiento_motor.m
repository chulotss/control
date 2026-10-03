clc;
clear;
close all;

puertoCOM = "COM10";
modeloBoard = "Mega2560";

a = arduino(puertoCOM, modeloBoard, ...
    'Libraries', 'RotaryEncoder');

pinENA = 'D5';
pinIN1 = 'D11';
pinIN2 = 'D10';

pinENB = 'D6';
pinIN3 = 'D13';
pinIN4 = 'D12';

encoder1 = rotaryEncoder(a, 'D2', 'D3');
encoder2 = rotaryEncoder(a, 'D18', 'D19');

resetCount(encoder1);
resetCount(encoder2);

Ts = 0.05;

PWM_inicial = 0;
PWM_final = 200;

tiempoRampa = 40;

fprintf('\n');
fprintf('============================================================\n');
fprintf('          PRUEBA DE MOTORES - RAMPA POSITIVA\n');
fprintf('============================================================\n');
fprintf('PWM inicial = %d\n', PWM_inicial);
fprintf('PWM final   = %d\n', PWM_final);
fprintf('Tiempo      = %.2f s\n', tiempoRampa);
fprintf('Periodo     = %.3f s\n', Ts);
fprintf('============================================================\n\n');

fprintf('%10s %10s %15s %15s %12s %12s\n', ...
    'Tiempo', 'PWM', 'Encoder 1', 'Encoder 2', 'RPM 1', 'RPM 2');

fprintf('--------------------------------------------------------------------------\n');

resetCount(encoder1);
resetCount(encoder2);

writeDigitalPin(a, pinIN1, 1);
writeDigitalPin(a, pinIN2, 0);

writeDigitalPin(a, pinIN3, 1);
writeDigitalPin(a, pinIN4, 0);

figure('Name','Prueba de motores - Rampa positiva');

subplot(3,1,1);

hPWM = animatedline( ...
    'Color',[0.4940 0.1840 0.5560], ...
    'LineWidth',1.8);

grid on;
xlabel('Tiempo [s]');
ylabel('PWM');

title('Entrada: rampa positiva');

ylim([0 PWM_final + 20]);

subplot(3,1,2);

hEnc1 = animatedline( ...
    'Color',[0 0.4470 0.7410], ...
    'LineWidth',1.8);

hEnc2 = animatedline( ...
    'Color',[0.8500 0.3250 0.0980], ...
    'LineWidth',1.8);

grid on;
xlabel('Tiempo [s]');
ylabel('Ticks');

title('Respuesta de los encoders');

legend('Motor 1','Motor 2','Location','northwest');

subplot(3,1,3);

hRPM1 = animatedline( ...
    'Color',[0 0.4470 0.7410], ...
    'LineWidth',1.8);

hRPM2 = animatedline( ...
    'Color',[0.8500 0.3250 0.0980], ...
    'LineWidth',1.8);

grid on;
xlabel('Tiempo [s]');
ylabel('RPM');

title('Velocidad de los motores');

legend('Motor 1','Motor 2','Location','northwest');

tInicio = tic;

tAnterior = 0;

ticks1Anterior = 0;
ticks2Anterior = 0;

while true

    tiempo = toc(tInicio);

    if tiempo >= tiempoRampa
        break;
    end

    if tiempo - tAnterior >= Ts

        dt = tiempo - tAnterior;

        PWM_actual = PWM_inicial + ...
            (PWM_final - PWM_inicial) * ...
            (tiempo / tiempoRampa);

        PWM_actual = min(PWM_actual, PWM_final);

        writePWMDutyCycle(a, pinENA, PWM_actual / 255);
        writePWMDutyCycle(a, pinENB, PWM_actual / 255);

        ticks1 = readCount(encoder1);
        ticks2 = readCount(encoder2);

        deltaTicks1 = ticks1 - ticks1Anterior;
        deltaTicks2 = ticks2 - ticks2Anterior;

        rpm1 = (deltaTicks1 / dt) * 60 / 840;
        rpm2 = (deltaTicks2 / dt) * 60 / 840;

        addpoints(hPWM, tiempo, PWM_actual);

        addpoints(hEnc1, tiempo, ticks1);
        addpoints(hEnc2, tiempo, ticks2);

        addpoints(hRPM1, tiempo, rpm1);
        addpoints(hRPM2, tiempo, rpm2);

        drawnow limitrate;

        fprintf('%10.2f %10.1f %15d %15d %12.2f %12.2f\n', ...
            tiempo, ...
            PWM_actual, ...
            ticks1, ...
            ticks2, ...
            rpm1, ...
            rpm2);

        ticks1Anterior = ticks1;
        ticks2Anterior = ticks2;

        tAnterior = tiempo;
    end
end

writePWMDutyCycle(a, pinENA, 0);
writePWMDutyCycle(a, pinENB, 0);

writeDigitalPin(a, pinIN1, 0);
writeDigitalPin(a, pinIN2, 0);

writeDigitalPin(a, pinIN3, 0);
writeDigitalPin(a, pinIN4, 0);

ticks1Final = readCount(encoder1);
ticks2Final = readCount(encoder2);

fprintf('\n');
fprintf('============================================================\n');
fprintf('                    PRUEBA TERMINADA\n');
fprintf('============================================================\n');

fprintf('Ticks finales Motor 1 = %d\n', ticks1Final);
fprintf('Ticks finales Motor 2 = %d\n', ticks2Final);

fprintf('============================================================\n');