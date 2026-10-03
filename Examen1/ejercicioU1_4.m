A=[1/2 1; -2 1];
B=[0;1];
C=[1 0];
D=[0];
P=[-1 0; 0 -1/2];
pos=A'*P+P*A;
eig(pos);
syms x
pol=x^2-3/2*x+5/2;
disp(double(solve(pol==0,x)));