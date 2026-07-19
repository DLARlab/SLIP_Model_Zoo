%% Bipedal Swing phase dynamics
clear
clc

syms x y phi alphaL alphaR g m1 m2 len J

x1 = [x;y];
x2 = [x+sin(alphaL)*len ;y-cos(alphaL)*len];
x3 = [x+sin(alphaR)*len ;y-cos(alphaR)*len];
q = [x;y;alphaL;alphaR];

I_Js1 = jacobian(x1,q);
I_Js2 = jacobian(x2,q);
I_Js3 = jacobian(x3,q);

I_Jr1 = jacobian(phi,q);
I_Jr2 = jacobian(alphaL,q);
I_Jr3 = jacobian(alphaR,q);

M = simplify(I_Js1.'*[m1 0; 0 m1]*I_Js1 + I_Js2.'*[m2 0; 0 m2]*I_Js2 + I_Js3.'*[m2 0; 0 m2]*I_Js3);% + ...
%             I_Jr1.'*J*I_Jr1 + I_Jr2.'*m2*len^2*I_Jr2 + I_Jr3.'*m2*len^2*I_Jr3);
disp('M = ')
disp(M)


syms dx dy dphi dalphaL dalphaR
dq = [dx;dy;dalphaL;dalphaR];
I_sigmass1 = jacobian(I_Js1*dq,q)*dq;
I_sigmass2 = jacobian(I_Js2*dq,q)*dq;
I_sigmass3 = jacobian(I_Js3*dq,q)*dq;

I_sigmar1 = jacobian(I_Jr1*dq,q)*dq;
I_sigmar2 = jacobian(I_Jr2*dq,q)*dq;
I_sigmar3 = jacobian(I_Jr3*dq,q)*dq;

f = I_Js1.'*m1*I_sigmass1 + I_Js2.'*m2*I_sigmass2 + I_Js3.'*m2*I_sigmass3;% +...
%     I_Jr1.'*(J*I_sigmar1 + dphi^2*J) + I_Jr2.'*(m2*len^2*I_sigmar2 + + dalphaL^2*m2*len^2) + I_Jr3.'*(m2*len^2*I_sigmar2 + + dalphaR^2*m2*len^2);
disp('f = ')
disp(f)


Fg1 = [0;-m1*g];
Fg2 = [0;-m2*g];
Fg3 = [0;-m2*g];
g_total = I_Js1.'*Fg1 + I_Js2.'*Fg2 + I_Js3.'*Fg3;% +...
%           I_Jr1.'*0  + I_Jr2.'*(-m2*g)*sin(alphaL) + I_Jr3.'*(-m2*g)*sin(alphaR);
disp('g_total = ')
disp(g_total)

syms Fx Fy omega
tau = [Fx;Fy;-omega^2*m2*len^2*alphaL;-omega^2*m2*len^2*alphaR];
% tau = [0;0;0;0];
disp('tau')
disp(tau)

ddq = simplify( M\(tau - f + g_total));
% disp('ddq')
% disp(ddq)
ddq = simplify(limit(ddq,m2,0));
disp('ddq')
disp(ddq)

%% Bipedal Stance Phase Dynamics
x_touchdown = x + tan(alphaL)*y;
xd_touchdown = jacobian(x_touchdown,q)*dq;
disp('xd_touchdown = ')
disp(xd_touchdown)

syms ddx ddy  ddalphaL ddalphaR
ddq = [ddx; ddy; ddalphaL; ddalphaR];
xdd_touchdown = jacobian(xd_touchdown,q)*dq + jacobian(x_touchdown,q)*ddq ==0;
disp('xdd_touchdown = ')
disp(xdd_touchdown)

ddalphaL = solve(xdd_touchdown,ddalphaL);
ddalphaL = simplify(ddalphaL);
disp('ddalphaL = ')
disp(ddalphaL)


%% Quadrapedal Swing Phase Dynamics
clear
clc

syms x y phi alphaBL alphaBR alphaFL alphaFR   real
q = [x y phi alphaBL alphaBR alphaFL alphaFR]';
syms dx dy dphi dalphaBL dalphaBR dalphaFL dalphaFR   real
dq = [dx dy dphi dalphaBL dalphaBR dalphaFL dalphaFR]';
syms ddx ddy ddphi ddalphaBL ddalphaBR ddalphaFL ddalphaFR   real
ddq = [ddx ddy ddphi ddalphaBL ddalphaBR ddalphaFL ddalphaFR]';


syms Mb J lb L m l_0 g k w real
% set Body length = 1, we trach the ratio of lb/L and l-0/L
syms Fx Fy Torq real;
% Position vector of torso
pos0 = [x;y];
posB = pos0 + lb*[cos(phi + pi);sin(phi + pi)];
posF = pos0 + (1-lb)*[cos(phi);sin(phi)];
% Position vector of feet
posBLFoot = posB + l_0*[sin(alphaBL+phi);-cos(alphaBL+phi)];
posBRFoot = posB + l_0*[sin(alphaBR+phi);-cos(alphaBR+phi)];
posFLFoot = posF + l_0*[sin(alphaFL+phi);-cos(alphaFL+phi)];
posFRFoot = posF + l_0*[sin(alphaFR+phi);-cos(alphaFR+phi)];

% Jaccobian of each element
I_Js0 = jacobian(pos0,q);
I_JsBL = jacobian(posBLFoot,q);
I_JsBR = jacobian(posBRFoot,q);
I_JsFL = jacobian(posFLFoot,q);
I_JsFR = jacobian(posFRFoot,q);

I_Jr0 = jacobian(phi,q);
I_JrBL = jacobian(alphaBL,q);
I_JrBR = jacobian(alphaBR,q);
I_JrFL = jacobian(alphaFL,q);
I_JrFR = jacobian(alphaFR,q);

% Mass matrix
M = simplify(I_Js0.'*Mb*I_Js0 + I_JsBL.'*m*I_JsBL + I_JsBR.'*m*I_JsBR + I_JsFL.'*m*I_JsFL + I_JsFR.'*m*I_JsFR +...
             I_Jr0.'*J*I_Jr0);% + I_JrBL'*m*l_0^2*I_JrBL + I_JrBR'*m*l_0^2*I_JrBR + I_JrFL'*m*l_0^2*I_JrFL + I_JrFR'*m*l_0^2*I_JrFR);
disp('M = ')
disp(M)
% M = simplify(limit(M,m,0));

% f matrix
I_sigmas0 = jacobian(I_Js0*dq,q)*dq;
I_sigmasBL = jacobian(I_JsBL*dq,q)*dq;
I_sigmasBR = jacobian(I_JsBR*dq,q)*dq;
I_sigmasFL = jacobian(I_JsFL*dq,q)*dq;
I_sigmasFR = jacobian(I_JsFR*dq,q)*dq;

I_sigmar0 = jacobian(I_Jr0*dq,q)*dq;
I_sigmarBL = jacobian(I_JrBL*dq,q)*dq;
I_sigmarBR = jacobian(I_JrBR*dq,q)*dq;
I_sigmarFL = jacobian(I_JrFL*dq,q)*dq;
I_sigmarFR = jacobian(I_JrFR*dq,q)*dq;

f = I_Js0.'*Mb*I_sigmas0 + I_JsBL.'*m*I_sigmasBL + I_JsBR.'*m*I_sigmasBR + I_JsFL.'*m*I_sigmasFL + I_JsFR.'*m*I_sigmasFR +...
    I_Jr0.'*J*I_sigmar0;% + I_JsBL.'*m*I_sigmasBL + I_JsBR.'*m*I_sigmasBR + I_JsFL.'*m*I_sigmasFL + I_JsFR.'*m*I_sigmasFR;

% g matrix
Fg0 = [0;-Mb*g];
FgBL = [0;-m*g];
FgBR = [0;-m*g];
FgFL = [0;-m*g];
FgFR = [0;-m*g];
g_total = I_Js0.'*Fg0 + I_JsBL.'*FgBL + I_JsBR.'*FgBR + I_JsFL.'*FgFL + I_JsFR.'*FgFR;% +...
%           I_Jr1.'*0  + I_Jr2.'*(-m2*g)*sin(alphaL) + I_Jr3.'*(-m2*g)*sin(alphaR);

% tau matrix
syms Fx Fy T   real 
tau = [Fx; Fy; T; -w^2*m*l_0^2*alphaBL; -w^2*m*l_0^2*alphaBR; -w^2*m*l_0^2*alphaBL;-w^2*m*l_0^2*alphaBR];


ddq = simplify( M\(tau - f + g_total));
ddq = simplify(limit(ddq,m2,0));
disp('ddq')
disp(ddq)

%% Quadrupedal Stance Phase Dynamics: Front and Back Only
clear
clc

syms x y phi alphaB alphaF   real
q = [x y phi alphaB alphaF]';
syms dx dy dphi dalphaB dalphaF   real
dq = [dx dy dphi dalphaB dalphaF]';
syms ddx ddy ddphi ddalphaB ddalphaF   real
ddq = [ddx ddy ddphi ddalphaB ddalphaF]';


syms Mb J lb L m l_0 g k w real
% set Body length = 1, we trach the ratio of lb/L and l-0/L
syms Fx Fy Torq real;

% lb = 0.5;

% Position vector of torso
pos0 = [x;y];
posB = pos0 + lb*[cos(phi + pi);sin(phi + pi)];
posF = pos0 + (1-lb)*[cos(phi);sin(phi)];

% Horizontal position of feet
x_touchdown_B = posB(1) + tan(alphaB+phi+pi)*posB(2);
dx_touchdown_B = jacobian(x_touchdown_B,q)*dq;


x_touchdown_F = posF(1) + tan(alphaF+phi+pi)*posF(2);
dx_touchdown_F = jacobian(x_touchdown_F,q)*dq;


% disp('dx_touchdown = ')
% disp(dx_touchdown)

ddx_touchdown_B = simplify(jacobian(dx_touchdown_B,q)*dq + jacobian(dx_touchdown_B,dq)*ddq == 0);
ddx_touchdown_F = simplify(jacobian(dx_touchdown_F,q)*dq + jacobian(dx_touchdown_F,dq)*ddq == 0);

% disp('ddx_touchdown_BL = ')
% disp(ddx_touchdown_BL)

dalphaB = simplify(solve(dx_touchdown_B,dalphaB));
ddalphaB = simplify(solve(ddx_touchdown_B,ddalphaB));
disp('ddalphaB = ')
disp(ddalphaB)

matlabFunction(dalphaB,ddalphaB,'File','Func_alphaB_VA_v2','Outputs',{'dalphaB','ddalphaB'},'Vars',{[q;dq;ddq;lb]});


dalphaF = simplify(solve(dx_touchdown_F,dalphaF));
ddalphaF = simplify(solve(ddx_touchdown_F,ddalphaF));
disp('ddalphaF = ')
disp(ddalphaF)


matlabFunction(dalphaF,ddalphaF,'File','Func_alphaF_VA_v2','Outputs',{'dalphaF','ddalphaF'},'Vars',{[q;dq;ddq;lb]});

%% Quadrupedal Stance Phase Dynamics: Four Legs Version
clear
clc

syms x y phi alphaBL alphaBR alphaFL alphaFR   real
q = [x y phi alphaBL alphaBR alphaFL alphaFR]';
syms dx dy dphi dalphaBL dalphaBR dalphaFL dalphaFR   real
dq = [dx dy dphi dalphaBL dalphaBR dalphaFL dalphaFR]';
syms ddx ddy ddphi ddalphaBL ddalphaBR ddalphaFL ddalphaFR   real
ddq = [ddx ddy ddphi ddalphaBL ddalphaBR ddalphaFL ddalphaFR]';


syms Mb J lb L m l_0 g k w real
% set Body length = 1, we trach the ratio of lb/L and l-0/L
syms Fx Fy Torq real;

lb = 0.5;

% Position vector of torso
pos0 = [x;y];
posB = pos0 + lb*[cos(phi + pi);sin(phi + pi)];
posF = pos0 + (1-lb)*[cos(phi);sin(phi)];

% Horizontal position of feet
x_touchdown_B = posB(1) + tan(alphaBL+phi+pi)*posB(2);
dx_touchdown_B = jacobian(x_touchdown_B,q)*dq;
x_touchdown_BR = posB(1) + tan(alphaBR+phi+pi)*posB(2);
dx_touchdown_BR = jacobian(x_touchdown_BR,q)*dq;

x_touchdown_F = posF(1) + tan(alphaFL+phi+pi)*posF(2);
dx_touchdown_F = jacobian(x_touchdown_F,q)*dq;
x_touchdown_FR = posB(1) + tan(alphaFR+phi+pi)*posF(2);
dx_touchdown_FR = jacobian(x_touchdown_FR,q)*dq;

% disp('dx_touchdown = ')
% disp(dx_touchdown)

ddx_touchdown_BL = simplify(jacobian(dx_touchdown_B,q)*dq + jacobian(dx_touchdown_B,dq)*ddq == 0);
ddx_touchdown_BR = simplify(jacobian(dx_touchdown_BR,q)*dq + jacobian(dx_touchdown_BR,dq)*ddq == 0);
ddx_touchdown_FL = simplify(jacobian(dx_touchdown_F,q)*dq + jacobian(dx_touchdown_F,dq)*ddq == 0);
ddx_touchdown_FR = simplify(jacobian(dx_touchdown_FR,q)*dq + jacobian(dx_touchdown_FR,dq)*ddq == 0);

% disp('ddx_touchdown_BL = ')
% disp(ddx_touchdown_BL)

dalphaBL = simplify(solve(dx_touchdown_B,ddalphaBL));
disp('dalphaBL = ')
disp(dalphaBL)
ddalphaBL = simplify(solve(ddx_touchdown_BL,ddalphaBL));
disp('ddalphaBL = ')
disp(ddalphaBL)

matlabFunction(dalphaBL,ddalphaBL,'File','Func_alphaB_VA_v2','Outputs',{'dalphaBL','ddalphaBL'},'Vars',{[q;dq;ddq]});



dalphaFL = simplify(solve(dx_touchdown_F,ddalphaFL));
disp('dalphaFL = ')
disp(dalphaFL)
ddalphaFL = simplify(solve(ddx_touchdown_FL,ddalphaFL));
disp('ddalphaFL = ')
disp(ddalphaFL)

matlabFunction(dalphaFL,ddalphaFL,'File','Func_alphaF_VA_v2','Outputs',{'dalphaFL','ddalphaFL'},'Vars',{[q;dq;ddq]});