clc; clear; close all;
modeloBoard = 'Mega2560';
puertoCOM   = 'COM5';   % AJUSTAR a tu puerto real

try
    a = arduino(puertoCOM, modeloBoard, 'Libraries', {'RotaryEncoder', 'I2C'});
    fprintf('Conexión con Arduino (%s) establecida correctamente.\n', modeloBoard);
catch
    error('No se pudo conectar la placa. Verifica el puerto COM y la conexión.');
end

% ---------- PINES MOTOR 1 y 2 ----------
pinENA = 'D5';  pinIN1 = 'D11'; pinIN2 = 'D10'; pinEncA1 = 'D2';  pinEncB1 = 'D3';
pinENB = 'D6';  pinIN3 = 'D12'; pinIN4 = 'D13'; pinEncA2 = 'D18'; pinEncB2 = 'D19';

configurePin(a, pinIN1, 'DigitalOutput'); configurePin(a, pinIN2, 'DigitalOutput');
configurePin(a, pinIN3, 'DigitalOutput'); configurePin(a, pinIN4, 'DigitalOutput');

ppr = 520

;
encoder1 = rotaryEncoder(a, pinEncA1, pinEncB1, ppr);
encoder2 = rotaryEncoder(a, pinEncA2, pinEncB2, ppr);

% ---------- MPU6050 POR I2C DIRECTO ----------
imu = device(a, 'I2CAddress', 0x68);
writeRegister(imu, 0x6B, 0, 'uint8'); % saca al MPU6050 del modo sleep
pause(0.1);

%% ---------- CALIBRACIÓN (ROBOT QUIETO Y VERTICAL) ----------
fprintf('Calibrando IMU. Sostén el robot exactamente VERTICAL y no lo muevas...\n');
pause(2);

nCal = 200;
gxOffset = 0; angleAccSum = 0;
for i = 1:nCal
    [axC, ayC, azC, gx] = leerIMU(imu);
    gxOffset = gxOffset + gx;
    angleAccSum = angleAccSum + atan2(-axC, sqrt(ayC^2 + azC^2)) * 180/pi;
end
gxOffset = gxOffset / nCal;
angleOffset = angleAccSum / nCal;
fprintf('Offset giroscopio: %.3f °/s | Ángulo cero: %.3f°\n', gxOffset, angleOffset);

alpha = 0.98;
angle = angleOffset; % arranca asumiendo vertical

%% ---------- PARAMETROS DE LA SEÑAL SENO ----------
amplitud       = 0.4;  % duty cycle máximo (0-1)
frecuencia     = 0.05;  % Hz
duracionPrueba = 10;   % s

resetCount(encoder1); resetCount(encoder2);
writePWMDutyCycle(a, pinENA, 0); writePWMDutyCycle(a, pinENB, 0);

dirActual = true;
writeDigitalPin(a, pinIN1, dirActual); writeDigitalPin(a, pinIN2, ~dirActual);
writeDigitalPin(a, pinIN3, dirActual); writeDigitalPin(a, pinIN4, ~dirActual);

tiempoData = []; pwmData = []; anguloData = []; velData1 = []; velData2 = [];

%% ---------- APAGADO SEGURO GARANTIZADO ----------
limpiar = onCleanup(@() apagarMotores(a, pinENA, pinENB, pinIN1, pinIN2, pinIN3, pinIN4));

%% ---------- BUCLE DE ADQUISICION ----------
tInicio = tic; tUltimo = tic;
fprintf('Iniciando prueba de identificación (seno). Ctrl+C para detener.\n');

while toc(tInicio) < duracionPrueba
    tActual = toc(tInicio);
    dt = toc(tUltimo); tUltimo = tic;
    if dt <= 0, dt = 0.02; end

    % --- Señal seno ---
    senal = amplitud * sin(2*pi*frecuencia*tActual);

    dirNueva = senal >= 0;
    if dirNueva ~= dirActual
        writePWMDutyCycle(a, pinENA, 0); writePWMDutyCycle(a, pinENB, 0);
        writeDigitalPin(a, pinIN1, dirNueva); writeDigitalPin(a, pinIN2, ~dirNueva);
        writeDigitalPin(a, pinIN3, dirNueva); writeDigitalPin(a, pinIN4, ~dirNueva);
        dirActual = dirNueva;
    end
    duty = min(abs(senal), 1.0);
    writePWMDutyCycle(a, pinENA, duty);
    writePWMDutyCycle(a, pinENB, duty);

    % --- Ángulo (filtro complementario) ---
    [ax, ay, az, gxRaw] = leerIMU(imu);
    gx = gxRaw - gxOffset;
    angleAcc = atan2(-ax, sqrt(ay^2 + az^2)) * 180/pi;
    angle = alpha * (angle + gx*dt) + (1-alpha) * angleAcc;

    % --- Velocidad de cada motor ---
    rpm1 = readSpeed(encoder1); rpm2 = readSpeed(encoder2);
    if ~dirActual, rpm1 = -rpm1; rpm2 = -rpm2; end

    % --- Guardar ---
    tiempoData(end+1) = tActual;         %#ok<SAGROW>
    pwmData(end+1)    = senal;           %#ok<SAGROW>
    anguloData(end+1) = angle - angleOffset; %#ok<SAGROW>
    velData1(end+1)   = rpm1;            %#ok<SAGROW>
    velData2(end+1)   = rpm2;            %#ok<SAGROW>
end

clear limpiar;
disp('Prueba finalizada.');

%% ---------- TABLA Y GUARDADO ----------
tabla_datos = table(tiempoData', pwmData', anguloData', velData1', velData2', ...
    'VariableNames', {'Tiempo_s','Senal_PWM','Angulo_deg','Velocidad_M1_RPM','Velocidad_M2_RPM'});

disp(tabla_datos(1:min(10,height(tabla_datos)), :));

fechaHora = datestr(now, 'yyyy_mm_dd_HHMMSS');
nombreCSV = sprintf('datos_identificacion_%s.csv', fechaHora);
writetable(tabla_datos, nombreCSV);
save(strrep(nombreCSV, '.csv', '.mat'), 'tabla_datos');
fprintf('Datos guardados en: %s\n', nombreCSV);

figure('Name', 'Identificación TWSBR');
subplot(2,1,1);
plot(tabla_datos.Tiempo_s, tabla_datos.Senal_PWM, 'b-'); grid on;
ylabel('PWM'); title('Señal aplicada');
subplot(2,1,2);
plot(tabla_datos.Tiempo_s, tabla_datos.Angulo_deg, 'm-'); grid on;
xlabel('Tiempo (s)'); ylabel('Ángulo (°)'); title('Respuesta del ángulo');

%% ============================================================
%  FUNCIONES AUXILIARES
% ============================================================
function [ax, ay, az, gx] = leerIMU(imu)
    raw = readRegister(imu, 0x3B, 14);
    valores = combinarBytes(raw);
    ax = valores(1) / 16384.0;
    ay = valores(2) / 16384.0;
    az = valores(3) / 16384.0;
    gx = valores(5) / 131.0;
end

function valores = combinarBytes(raw)
    valores = zeros(1,7);
    for k = 1:7
        hi = int16(raw(2*k - 1));
        lo = int16(raw(2*k));
        v = bitshift(hi, 8) + lo;
        if v > 32767
            v = v - 65536;
        end
        valores(k) = double(v);
    end
end

function apagarMotores(a, pinENA, pinENB, pinIN1, pinIN2, pinIN3, pinIN4)
    try
        writePWMDutyCycle(a, pinENA, 0); writePWMDutyCycle(a, pinENB, 0);
        writeDigitalPin(a, pinIN1, 0); writeDigitalPin(a, pinIN2, 0);
        writeDigitalPin(a, pinIN3, 0); writeDigitalPin(a, pinIN4, 0);
        fprintf('Motores detenidos de forma segura.\n');
    catch
    end
end