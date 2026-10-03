clc;
clearvars -except ss1 ss3 tf1;
close all;
X0=[0;0;0;0];
ss4 = ss(tf1);

disp(ss4)
pole(ss4)
damp(ss4)
dcgain(ss4)