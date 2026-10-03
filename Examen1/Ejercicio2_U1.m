clc 
clear; 
close all; 
A=[0 1;-1 2]; 
B=[0;2]; 
C=[1 0]; 
D=[0]; 
P=[-1.5 0.5;0.5 -0.5];
disp(A'*P+P*A);
disp(eig(P));

syms x
lam=[x -1; 1 x-2];
pol=det(lam);
disp(pol);
disp(double(solve(pol==0,x)));
