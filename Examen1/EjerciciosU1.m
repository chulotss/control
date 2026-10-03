A=[0 1; -2 -1];
B=[0;1];
C=[1 0];
D=[0];
P=[1.75 0.25;0.25 0.75];
Comp=A'*P+P*A;
disp(Comp)
disp(eig(P));
syms lambda;
lam=[lambda -1;2 lambda+1];
pol=det(lam);
disp(pol);
disp(double(solve(pol==0,lambda)));

