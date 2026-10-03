%% FILTRO DE KALMAN EN TIEMPO REAL
clc
clear
close all

%% ===============================
% PARAMETROS
% ===============================

puerto = "COM5";
board = "Uno";


pinPot     = 'A2';  
pinPWM     = 'D10';  
dir1    = 'D8'; 
dir2    = 'D9'; 
pinEncA    = 'D3';  
pinEncB    = 'D2';  

pulsos_rev = 850;
vol_max = 0.5;
rpm_max = 200; % Ejemplo: RPM máximo de tu motor


%% ===============================
% MODELO DISCRETO (obtenido antes)
% ===============================
load("C:\Users\Froilán Pardo\Documents\Ezequiel\controlPL\control\Laboratorio3\datos85.mat");
Ad = sysd.A;
Bd = sysd.B;
Cd = sysd.C;
Dd = sysd.D;
Ts = sysd.Ts;
%CONDICION INICIAL
xk=zeros(size(Ad, 1), 1);
%% ===============================
% PARAMETROS KALMAN
% ===============================
ruido_std = 0;   % desviacion del ruido RPM
sigma = (ruido_std / 100) * rpm_max;


Qn = 0.05;  
Rn = 1;   

x_est = zeros(size(Ad, 1), 1);
P = eye(size(Ad));

%% ===============================
% CONEXION ARDUINO
% ===============================

a = arduino(puerto,board,"Libraries","rotaryEncoder");

enc = rotaryEncoder(a,pinEncA,pinEncB,pulsos_rev);
% Configurar sentido de giro
writePWMDutyCycle(a,pinPWM,0);
writeDigitalPin(a,dir1,1);
writeDigitalPin(a,dir2,0);
resetCount(enc)

%% ===============================
% GRAFICA EN TIEMPO REAL
% ===============================

figure
hold on
grid on

h0 = animatedline('Color','y','LineWidth',1);
h1 = animatedline('Color','b','LineWidth',1.5);
h2 = animatedline('Color','r','LineWidth',1);
h3 = animatedline('Color','g','LineWidth',2);

legend("RPM modelado", "RPM real", "RPM con ruido", "Kalman", 'Location', 'northwest')

xlabel("Tiempo (s)")
ylabel("RPM")

t = 0;

disp("Ejecutando filtro Kalman (CTRL+C para detener)")

%% ===============================
% LOOP PRINCIPAL
% ===============================

while true

    %% Leer potenciometro
    pot = readVoltage(a,pinPot);
    
    PWM = pot/5 *vol_max;
    
    writePWMDutyCycle(a,pinPWM,PWM);
    
    %% Leer encoder
   
    rpm = readSpeed(enc);
    
    %% Agregar ruido
    
    y_ruido = rpm + sigma * randn;
    
    %% Kalman
    % ---- PREDICCION ----
    x_pred = Ad*x_est + Bd*PWM;
    
    P_pred = Ad*P*Ad' + Qn;
    % ---- CALCULO DE GANANCIA KALMAN ----
    
    K = P_pred*Cd'/(Cd*P_pred*Cd' + Rn);

    % ---- CORRECCION DEL ESTADO ----
    
    x_est = x_pred + K*(y_ruido - Cd*x_pred);
    
    % ---- ACTUALIZACION DE INCERTIDUMBRE----
    
    P = (eye(size(Ad)) - K*Cd)*P_pred;
    %% ===============================
    % Calculo Velocidad Estimada
    % ===============================    
    y_est = Cd * x_est + Dd * PWM;

    %% ===============================
    % Calculo Velocidad Modelado
    % ===============================    
    
    % 1. Calcular la salida actual y[k] con el estado actual x[k]
    y_modelo = Cd * xk + Dd * PWM;
    
    % 2. Calcular el siguiente estado x[k+1]
    x_k1 = Ad * xk + Bd * PWM;
    
    % 3. Actualizar el estado para la siguiente iteración
    xk = x_k1;

    %% ===============================
    % GRAFICA
    % ===============================
    
    addpoints(h0,t,y_modelo)
    addpoints(h1,t,rpm)
    addpoints(h2,t,y_ruido)
    addpoints(h3,t,y_est(1))
    
    drawnow
    
    pause(Ts)
    
    t = t + Ts;

end