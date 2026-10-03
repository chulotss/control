clc;
clear;
close all;

%% CONFIGURACION ARDUINO

modeloBoard = 'Uno';
puertoCOM = 'COM5';

try
    a = arduino(puertoCOM, modeloBoard, 'Libraries', 'RotaryEncoder');

    fprintf('Arduino conectado correctamente.\n');

catch
    error('No se pudo conectar con Arduino. Verifica el puerto COM.');
end

%% CONFIGURACION DEL ENCODER

pinEncA = 'D2';
pinEncB = 'D3';

pprProvisional = 10000;

encoderObj = rotaryEncoder(a, pinEncA, pinEncB, pprProvisional);

%% NUMERO DE VUELTAS

numeroVueltas = 1;

%% REINICIAR CONTADOR

resetCount(encoderObj);

%% INFORMACION

fprintf('\n');
fprintf('========================================\n');
fprintf('     MEDICION DE PULSOS POR VUELTA\n');
fprintf('========================================\n');
fprintf('\n');

fprintf('Gira el eje de salida de la caja reductora\n');
fprintf('exactamente %d vuelta completa.\n', numeroVueltas);

fprintf('\n');
fprintf('Gira siempre en el mismo sentido.\n');
fprintf('Comienza y termina en la misma posicion.\n');
fprintf('\n');

input('Presiona ENTER para comenzar...', 's');

%% REINICIAR CONTADOR

resetCount(encoderObj);

fprintf('\n');
fprintf('========================================\n');
fprintf('        COMIENZA LA MEDICION\n');
fprintf('========================================\n');
fprintf('\n');

fprintf('GIRA EL EJE DE SALIDA %d VUELTA.\n', numeroVueltas);
fprintf('\n');

input('Presiona ENTER cuando hayas terminado...', 's');

%% LEER PULSOS

pulsos = readCount(encoderObj);

%% CALCULAR PULSOS POR VUELTA

PPR_experimental = abs(pulsos) / numeroVueltas;

%% RESULTADOS

fprintf('\n');
fprintf('========================================\n');
fprintf('              RESULTADOS\n');
fprintf('========================================\n');

fprintf('Numero de vueltas = %d\n', numeroVueltas);
fprintf('Pulsos detectados = %d\n', pulsos);
fprintf('PPR experimental  = %.2f pulsos/vuelta\n', PPR_experimental);

fprintf('========================================\n');

fprintf('\nPrueba finalizada.\n');