clc; 
clear; 
close all; 
A=[0 1; 0.5 1]; 
B=[0;2]; 
C=[1 0]; 
D=[0];
P=[0.75 -1; -1 0.5];
disp(A'*P*A*P);