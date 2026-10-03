%% CONTROL PID SEGWAY
% MATLAB R2025b
% Arduino Mega 2560 + MPU6050 + 2 motores + 2 encoders

clc;
clear;
close all;


%% ============================================================
% 1. CONEXION CON ARDUINO MEGA
% =============================================================

puertoCOM = "COM10";

try

    a = arduino( ...
        puertoCOM, ...
        "Mega2560", ...
        "Libraries", ...
        {"I2C","RotaryEncoder"});

    fprintf("Conexion exitosa con Arduino Mega 2560.\n");

catch ME

    error( ...
        "No se pudo conectar con Arduino Mega.\n%s", ...
        ME.message);

end


%% ============================================================
% 2. MPU6050
% =============================================================

imu = mpu6050( ...
    a, ...
    I2CAddress="0x68", ...
    SampleRate=100, ...
    SamplesPerRead=1, ...
    ReadMode="latest");

fprintf("MPU6050 conectado en I2C 0x68.\n");


%% ============================================================
% 3. PINES DE LOS MOTORES
% =============================================================

ENA = "D5";
IN1 = "D11";
IN2 = "D10";

ENB = "D6";
IN3 = "D12";
IN4 = "D13";


%% ============================================================
% 4. CONFIGURACION DE LOS MOTORES
% =============================================================

configurePin(a,ENA,"PWM");

configurePin(a,IN1,"DigitalOutput");
configurePin(a,IN2,"DigitalOutput");

configurePin(a,ENB,"PWM");

configurePin(a,IN3,"DigitalOutput");
configurePin(a,IN4,"DigitalOutput");


% Motores detenidos

writePWMDutyCycle(a,ENA,0);
writePWMDutyCycle(a,ENB,0);

writeDigitalPin(a,IN1,0);
writeDigitalPin(a,IN2,0);

writeDigitalPin(a,IN3,0);
writeDigitalPin(a,IN4,0);


%% ============================================================
% 5. ENCODERS
% =============================================================

% CAMBIA ESTE VALOR POR EL PPR REAL DE TUS ENCODERS

ppr = 850;

encoder1 = rotaryEncoder( ...
    a, ...
    "D2", ...
    "D3", ...
    ppr);

encoder2 = rotaryEncoder( ...
    a, ...
    "D18", ...
    "D19", ...
    ppr);

resetCount(encoder1);
resetCount(encoder2);

fprintf("Encoders configurados.\n");


%% ============================================================
% 6. PARAMETROS PID
% =============================================================

Kp = 16.2794;

Ki = 100.9729;

Kd = 0.58317;


%% ============================================================
% 7. PARAMETROS DEL CONTROL
% =============================================================

setpoint = 180.0;

Ts = 0.01;

pwmMax = 170;

pwmMin = -170;

pwmMinEfectivo = 35;

anguloCaida = 35;


%% ============================================================
% 8. DIRECCION DEL CONTROL
% =============================================================

% Si el robot corrige en la direccion incorrecta,
% cambia este valor de 1 a -1.

controlSign = 1;


% Si uno de los motores gira al reves respecto al otro,
% cambia el correspondiente valor a -1.

motor1Sign = 1;

motor2Sign = 1;


%% ============================================================
% 9. FILTRO COMPLEMENTARIO DEL MPU6050
% =============================================================

alpha = 0.98;

anguloFiltrado = 0;

gyroBias = 0;


%% ============================================================
% 10. CALIBRACION DEL GIROSCOPIO
% =============================================================

fprintf("\n");
fprintf("============================================\n");
fprintf("CALIBRACION DEL MPU6050\n");
fprintf("============================================\n");
fprintf("NO MUEVAS EL SEGWAY.\n");
fprintf("Mantenerlo quieto durante 3 segundos.\n");
fprintf("\n");

numeroMuestras = 300;

gyroSamples = zeros(numeroMuestras,1);

for k = 1:numeroMuestras

    gyro = readAngularVelocity(imu);

    % Velocidad angular Y
    gyroSamples(k) = gyro(2);

    pause(Ts);

end

gyroBias = mean(gyroSamples);

fprintf("Bias del giroscopio Y = %.6f rad/s\n",gyroBias);


%% ============================================================
% 11. CALIBRACION DEL ANGULO INICIAL
% =============================================================

fprintf("\n");
fprintf("Coloca el Segway en la posicion vertical.\n");
fprintf("Esta posicion sera 180 grados.\n");
fprintf("Esperando 2 segundos...\n");

pause(2);

accel = readAcceleration(imu);

ax = accel(1);

az = accel(3);


% Angulo obtenido del acelerometro

pitchInicial = atan2(ax,az);

pitchInicial = rad2deg(pitchInicial);


% Offset para que la posicion inicial sea 180 grados

anguloOffset = 180 - pitchInicial;


anguloFiltrado = pitchInicial;


fprintf("Angulo inicial del acelerometro = %.3f grados\n", ...
    pitchInicial);

fprintf("Offset aplicado = %.3f grados\n", ...
    anguloOffset);

fprintf("Angulo inicial final = %.3f grados\n", ...
    pitchInicial + anguloOffset);


%% ============================================================
% 12. VARIABLES DEL PID
% =============================================================

errorAnterior = 0;

integral = 0;

pwmSalida = 0;


%% ============================================================
% 13. VARIABLES PARA EL TIEMPO
% =============================================================

tInicio = tic;

tiempoAnterior = tic;


%% ============================================================
% 14. VARIABLES PARA GRAFICAS
% =============================================================

tiempoData = [];

anguloData = [];

setpointData = [];

errorData = [];

pwmData = [];

rpm1Data = [];

rpm2Data = [];


%% ============================================================
% 15. CONFIGURACION DE GRAFICAS
% =============================================================

fig = figure( ...
    "Name","Control PID Segway", ...
    "NumberTitle","off", ...
    "Position",[100 50 1100 800]);


subplot(4,1,1);

hAngulo = plot(nan,nan,"b","LineWidth",1.5);

hold on;

hSetpoint = plot(nan,nan,"r--","LineWidth",1.5);

grid on;

ylabel("Angulo (°)");

legend( ...
    "Angulo", ...
    "Setpoint", ...
    "Location","best");

title("Angulo del Segway");


subplot(4,1,2);

hError = plot(nan,nan,"k","LineWidth",1.5);

grid on;

ylabel("Error (°)");

title("Error de control");


subplot(4,1,3);

hPWM = plot(nan,nan,"m","LineWidth",1.5);

grid on;

ylabel("PWM");

title("Señal de control");


subplot(4,1,4);

hRPM1 = plot(nan,nan,"b","LineWidth",1.2);

hold on;

hRPM2 = plot(nan,nan,"r","LineWidth",1.2);

grid on;

xlabel("Tiempo (s)");

ylabel("RPM");

legend("Motor 1","Motor 2");

title("Velocidad de los motores");


%% ============================================================
% 16. DURACION DE LA PRUEBA
% =============================================================

duracionPrueba = 60;


fprintf("\n");
fprintf("============================================\n");
fprintf("CONTROL PID INICIADO\n");
fprintf("============================================\n");

fprintf("Kp = %.6f\n",Kp);

fprintf("Ki = %.6f\n",Ki);

fprintf("Kd = %.6f\n",Kd);

fprintf("Setpoint = %.2f grados\n",setpoint);

fprintf("PWM maximo = %d\n",pwmMax);

fprintf("============================================\n");
fprintf("\n");


%% ============================================================
% 17. BUCLE PRINCIPAL DE CONTROL
% =============================================================

try

    while toc(tInicio) < duracionPrueba


        %% ----------------------------------------------------
        % A. TIEMPO REAL
        % -----------------------------------------------------

        tActual = toc(tInicio);

        dtReal = toc(tiempoAnterior);

        tiempoAnterior = tic;


        if dtReal <= 0

            dtReal = Ts;

        end


        %% ----------------------------------------------------
        % B. LEER MPU6050
        % -----------------------------------------------------

        accel = readAcceleration(imu);

        gyro = readAngularVelocity(imu);


        %% ----------------------------------------------------
        % C. ACELEROMETRO
        % -----------------------------------------------------

        ax = accel(1);

        az = accel(3);


        pitchAccel = atan2(ax,az);

        pitchAccel = rad2deg(pitchAccel);


        %% ----------------------------------------------------
        % D. GIROSCOPIO
        % -----------------------------------------------------

        gyroY = gyro(2);

        gyroY = gyroY - gyroBias;

        gyroYdeg = rad2deg(gyroY);


        %% ----------------------------------------------------
        % E. FILTRO COMPLEMENTARIO
        % -----------------------------------------------------

        pitchGyro = ...
            anguloFiltrado - anguloOffset + ...
            gyroYdeg * dtReal;


        pitchFiltrado = ...
            alpha * pitchGyro + ...
            (1-alpha) * pitchAccel;


        anguloFiltrado = pitchFiltrado + anguloOffset;


        angulo = anguloFiltrado;


        %% ----------------------------------------------------
        % F. ERROR
        % -----------------------------------------------------

        errorSegway = setpoint - angulo;


        %% ----------------------------------------------------
        % G. PROTECCION CONTRA CAIDA
        % -----------------------------------------------------

        if abs(errorSegway) > anguloCaida

            pwmSalida = 0;

            integral = 0;

            errorAnterior = errorSegway;


            % Motor 1

            writePWMDutyCycle(a,ENA,0);

            writeDigitalPin(a,IN1,0);

            writeDigitalPin(a,IN2,0);


            % Motor 2

            writePWMDutyCycle(a,ENB,0);

            writeDigitalPin(a,IN3,0);

            writeDigitalPin(a,IN4,0);


            fprintf( ...
                "PROTECCION: Angulo = %.2f grados\n", ...
                angulo);


            tiempoData(end+1) = tActual;

            anguloData(end+1) = angulo;

            setpointData(end+1) = setpoint;

            errorData(end+1) = errorSegway;

            pwmData(end+1) = 0;

            rpm1Data(end+1) = 0;

            rpm2Data(end+1) = 0;


            set(hAngulo, ...
                "XData",tiempoData, ...
                "YData",anguloData);

            set(hSetpoint, ...
                "XData",tiempoData, ...
                "YData",setpointData);

            set(hError, ...
                "XData",tiempoData, ...
                "YData",errorData);

            set(hPWM, ...
                "XData",tiempoData, ...
                "YData",pwmData);


            drawnow limitrate;


            pause(Ts);

            continue;

        end


        %% ----------------------------------------------------
        % H. PID PROPORCIONAL
        % -----------------------------------------------------

        P = Kp * errorSegway;


        %% ----------------------------------------------------
        % I. PID INTEGRAL
        % -----------------------------------------------------

        integralAnterior = integral;

        integral = ...
            integral + ...
            errorSegway * dtReal;


        I = Ki * integral;


        %% ----------------------------------------------------
        % J. PID DERIVATIVO
        % -----------------------------------------------------

        derivada = ...
            (errorSegway - errorAnterior) / dtReal;


        D = Kd * derivada;


        %% ----------------------------------------------------
        % K. PID TOTAL
        % -----------------------------------------------------

        u = ...
            P + ...
            I + ...
            D;


        %% ----------------------------------------------------
        % L. DIRECCION DEL CONTROL
        % -----------------------------------------------------

        u = controlSign * u;


        %% ----------------------------------------------------
        % M. SATURACION
        % -----------------------------------------------------

        if u > pwmMax

            u = pwmMax;

            integral = integralAnterior;

        elseif u < pwmMin

            u = pwmMin;

            integral = integralAnterior;

        end


        %% ----------------------------------------------------
        % N. PWM MINIMO
        % -----------------------------------------------------

        pwmSalida = u;


        if pwmSalida ~= 0 && ...
                abs(pwmSalida) < pwmMinEfectivo


            if pwmSalida > 0

                pwmSalida = pwmMinEfectivo;

            else

                pwmSalida = -pwmMinEfectivo;

            end

        end


        %% ----------------------------------------------------
        % O. SATURACION FINAL
        % -----------------------------------------------------

        pwmSalida = ...
            max(pwmMin, ...
            min(pwmMax,pwmSalida));


        %% ----------------------------------------------------
        % P. PWM NORMALIZADO
        % -----------------------------------------------------

        duty = abs(pwmSalida) / 255;


        %% ----------------------------------------------------
        % Q. MOTOR 1
        % -----------------------------------------------------

        comandoMotor1 = ...
            motor1Sign * pwmSalida;


        if comandoMotor1 > 0

            writeDigitalPin(a,IN1,1);

            writeDigitalPin(a,IN2,0);

        elseif comandoMotor1 < 0

            writeDigitalPin(a,IN1,0);

            writeDigitalPin(a,IN2,1);

        else

            writeDigitalPin(a,IN1,0);

            writeDigitalPin(a,IN2,0);

        end


        writePWMDutyCycle( ...
            a, ...
            ENA, ...
            abs(comandoMotor1)/255);


        %% ----------------------------------------------------
        % R. MOTOR 2
        % -----------------------------------------------------

        comandoMotor2 = ...
            motor2Sign * pwmSalida;


        if comandoMotor2 > 0

            writeDigitalPin(a,IN3,1);

            writeDigitalPin(a,IN4,0);

        elseif comandoMotor2 < 0

            writeDigitalPin(a,IN3,0);

            writeDigitalPin(a,IN4,1);

        else

            writeDigitalPin(a,IN3,0);

            writeDigitalPin(a,IN4,0);

        end


        writePWMDutyCycle( ...
            a, ...
            ENB, ...
            abs(comandoMotor2)/255);


        %% ----------------------------------------------------
        % S. ENCODERS
        % -----------------------------------------------------

        rpm = readSpeed([encoder1,encoder2]);


        rpm1 = rpm(1);

        rpm2 = rpm(2);


        %% ----------------------------------------------------
        % T. ACTUALIZAR ERROR
        % -----------------------------------------------------

        errorAnterior = errorSegway;


        %% ----------------------------------------------------
        % U. GUARDAR DATOS
        % -----------------------------------------------------

        tiempoData(end+1) = tActual;

        anguloData(end+1) = angulo;

        setpointData(end+1) = setpoint;

        errorData(end+1) = errorSegway;

        pwmData(end+1) = pwmSalida;

        rpm1Data(end+1) = rpm1;

        rpm2Data(end+1) = rpm2;


        %% ----------------------------------------------------
        % V. GRAFICAS
        % -----------------------------------------------------

        set(hAngulo, ...
            "XData",tiempoData, ...
            "YData",anguloData);

        set(hSetpoint, ...
            "XData",tiempoData, ...
            "YData",setpointData);

        set(hError, ...
            "XData",tiempoData, ...
            "YData",errorData);

        set(hPWM, ...
            "XData",tiempoData, ...
            "YData",pwmData);

        set(hRPM1, ...
            "XData",tiempoData, ...
            "YData",rpm1Data);

        set(hRPM2, ...
            "XData",tiempoData, ...
            "YData",rpm2Data);


        drawnow limitrate;


        %% ----------------------------------------------------
        % W. MOSTRAR DATOS
        % -----------------------------------------------------

        fprintf( ...
            "t=%6.2f | Ang=%7.2f | Err=%7.2f | PWM=%4d | RPM1=%7.2f | RPM2=%7.2f\n", ...
            tActual, ...
            angulo, ...
            errorSegway, ...
            round(pwmSalida), ...
            rpm1, ...
            rpm2);


        %% ----------------------------------------------------
        % X. CONTROL DE FRECUENCIA
        % -----------------------------------------------------

        tiempoCiclo = toc(tiempoAnterior);

        tiempoEspera = Ts - tiempoCiclo;


        if tiempoEspera > 0

            pause(tiempoEspera);

        end

    end


catch ME

    fprintf("\n");
    fprintf("ERROR DURANTE EL CONTROL:\n");
    fprintf("%s\n",ME.message);

end


%% ============================================================
% 18. APAGADO DE SEGURIDAD
% =============================================================

writePWMDutyCycle(a,ENA,0);

writePWMDutyCycle(a,ENB,0);

writeDigitalPin(a,IN1,0);

writeDigitalPin(a,IN2,0);

writeDigitalPin(a,IN3,0);

writeDigitalPin(a,IN4,0);


fprintf("\n");
fprintf("============================================\n");
fprintf("MOTORES DETENIDOS\n");
fprintf("CONTROL FINALIZADO\n");
fprintf("============================================\n");