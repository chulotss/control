clc;
clear;
close all;

%% =========================================================
%  CONEXION CON ARDUINO
% ==========================================================

modeloBoard = 'Uno';
puertoCOM = 'COM5';

try
    a = arduino(puertoCOM, modeloBoard, 'Libraries', 'RotaryEncoder');
    fprintf('Arduino conectado correctamente.\n');
catch
    error('No se pudo conectar con Arduino. Verifica el puerto COM.');
end


%% =========================================================
%  CONFIGURACION DE PINES
% ==========================================================

pinDir1 = 'D8';
pinDir2 = 'D9';
pinPWM = 'D10';

pinEncA = 'D2';
pinEncB = 'D3';


%% =========================================================
%  CONFIGURACION DE PINES
% ==========================================================

configurePin(a, pinDir1, 'DigitalOutput');
configurePin(a, pinDir2, 'DigitalOutput');


%% =========================================================
%  CONFIGURACION DEL ENCODER
% ==========================================================

% PPR determinado experimentalmente
ppr = 28;

encoderObj = rotaryEncoder(a, pinEncA, pinEncB, ppr);

resetCount(encoderObj);


%% =========================================================
%  CONFIGURACION DEL MOTOR
% ==========================================================

% Direccion
writeDigitalPin(a, pinDir1, 1);
writeDigitalPin(a, pinDir2, 0);

% Inicialmente motor apagado
writePWMDutyCycle(a, pinPWM, 0);


%% =========================================================
%  PARAMETROS DE LA PRUEBA
% ==========================================================

dutyMotor = 0.30;       % 30 % de PWM
tiempoEstabilizacion = 3;   % segundos
duracionPrueba = 30;        % segundos


%% =========================================================
%  ESTABILIZACION DEL MOTOR
% ==========================================================

fprintf('\n--------------------------------------------\n');
fprintf('INICIANDO ESTABILIZACION DEL MOTOR\n');
fprintf('PWM = %.0f %%\n', dutyMotor * 100);
fprintf('Tiempo de estabilizacion = %.1f s\n', tiempoEstabilizacion);
fprintf('--------------------------------------------\n');

writePWMDutyCycle(a, pinPWM, dutyMotor);

pause(tiempoEstabilizacion);


%% =========================================================
%  PREPARACION DE VARIABLES
% ==========================================================

tiempoData = [];
velocidadData = [];
TsData = [];

tAnterior = [];


%% =========================================================
%  INICIO DE LA MEDICION
% ==========================================================

fprintf('\n--------------------------------------------\n');
fprintf('INICIANDO MEDICION DEL TIEMPO DE MUESTREO\n');
fprintf('Duracion = %.1f segundos\n', duracionPrueba);
fprintf('--------------------------------------------\n');

tInicio = tic;


%% =========================================================
%  ADQUISICION DE DATOS
% ==========================================================

while toc(tInicio) < duracionPrueba

    % Tiempo actual
    tActual = toc(tInicio);

    % Calcular tiempo entre muestras
    if isempty(tAnterior)

        % Primera muestra: no calculamos Ts
        TsReal = NaN;

    else

        TsReal = tActual - tAnterior;

    end

    % Guardar tiempo para la siguiente iteracion
    tAnterior = tActual;


    % Leer velocidad del encoder
    rpm = readSpeed(encoderObj);


    % Guardar datos
    tiempoData(end+1) = tActual;
    velocidadData(end+1) = rpm;
    TsData(end+1) = TsReal;

end


%% =========================================================
%  DETENER MOTOR
% ==========================================================

writePWMDutyCycle(a, pinPWM, 0);

writeDigitalPin(a, pinDir1, 0);
writeDigitalPin(a, pinDir2, 0);

fprintf('\nMotor detenido.\n');


%% =========================================================
%  ELIMINAR PRIMER VALOR
% ==========================================================

% La primera muestra no tiene un Ts valido
TsValidos = TsData(~isnan(TsData));


%% =========================================================
%  CALCULOS DEL TIEMPO DE MUESTREO
% ==========================================================

TsMin = min(TsValidos);
TsMax = max(TsValidos);
TsPromedio = mean(TsValidos);
TsMediana = median(TsValidos);

TsDesviacion = std(TsValidos);

% Percentiles
P95 = prctile(TsValidos, 95);
P99 = prctile(TsValidos, 99);


%% =========================================================
%  FRECUENCIA DE MUESTREO
% ==========================================================

FsPromedio = 1 / TsPromedio;
FsMax = 1 / TsMin;
FsPeorCaso = 1 / TsMax;


%% =========================================================
%  PORCENTAJE DE MUESTRAS CERCA DEL VALOR CENTRAL
% ==========================================================

% Usaremos la mediana como referencia

diferencia = abs(TsValidos - TsMediana);


% Dentro de +/- 5 %
muestras5 = diferencia <= 0.05 * TsMediana;

porcentaje5 = mean(muestras5) * 100;


% Dentro de +/- 10 %
muestras10 = diferencia <= 0.10 * TsMediana;

porcentaje10 = mean(muestras10) * 100;


%% =========================================================
%  MOSTRAR RESULTADOS
% ==========================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('        RESULTADOS DEL TIEMPO DE MUESTREO\n');
fprintf('====================================================\n');

fprintf('Numero de muestras       : %d\n', length(TsValidos));

fprintf('\n');

fprintf('Ts minimo                : %.6f s  (%.3f ms)\n', ...
    TsMin, TsMin*1000);

fprintf('Ts promedio              : %.6f s  (%.3f ms)\n', ...
    TsPromedio, TsPromedio*1000);

fprintf('Ts mediana               : %.6f s  (%.3f ms)\n', ...
    TsMediana, TsMediana*1000);

fprintf('Ts maximo                : %.6f s  (%.3f ms)\n', ...
    TsMax, TsMax*1000);

fprintf('Desviacion estandar      : %.6f s  (%.3f ms)\n', ...
    TsDesviacion, TsDesviacion*1000);

fprintf('\n');

fprintf('P95                      : %.6f s  (%.3f ms)\n', ...
    P95, P95*1000);

fprintf('P99                      : %.6f s  (%.3f ms)\n', ...
    P99, P99*1000);

fprintf('\n');

fprintf('Frecuencia promedio     : %.2f Hz\n', FsPromedio);

fprintf('Frecuencia maxima       : %.2f Hz\n', FsMax);

fprintf('Frecuencia peor caso    : %.2f Hz\n', FsPeorCaso);

fprintf('\n');

fprintf('Muestras dentro de +/-5%%  : %.2f %%\n', porcentaje5);

fprintf('Muestras dentro de +/-10%% : %.2f %%\n', porcentaje10);

fprintf('====================================================\n');


%% =========================================================
%  GRAFICA DEL TIEMPO DE MUESTREO
% ==========================================================

figure;

plot(tiempoData(2:end), TsValidos * 1000, 'LineWidth', 1);

grid on;

xlabel('Tiempo [s]');
ylabel('Tiempo entre muestras [ms]');

title('Tiempo de muestreo real durante la adquisición');


%% =========================================================
%  HISTOGRAMA DE Ts
% ==========================================================

figure;

histogram(TsValidos * 1000);

grid on;

xlabel('Tiempo entre muestras [ms]');
ylabel('Cantidad de muestras');

title('Distribución del tiempo de muestreo');


%% =========================================================
%  GRAFICA DE VELOCIDAD
% ==========================================================

figure;

plot(tiempoData, velocidadData, 'LineWidth', 1);

grid on;

xlabel('Tiempo [s]');
ylabel('Velocidad [RPM]');

title('Velocidad del motor durante la prueba');


%% =========================================================
%  MENSAJE FINAL
% ==========================================================

fprintf('\nPrueba de tiempo de muestreo finalizada correctamente.\n');

fprintf('\nPara el criterio de PEOR CASO:\n');

fprintf('Ts = %.6f s = %.3f ms\n', TsMax, TsMax*1000);