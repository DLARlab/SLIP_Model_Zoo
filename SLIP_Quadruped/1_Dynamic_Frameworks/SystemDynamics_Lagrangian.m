%% Quadrupedal System Dynamics: Swing Legs and Torso using Lagrangian Method
clc
clear

syms x y phi alphaB alphaF real
q = [x y phi alphaB alphaF];
syms dx dy dphi dalphaB dalphaF  real
dqdt = [dx dy dphi dalphaB dalphaF];
syms ddx ddy ddphi ddalphaB ddalphaF real
dqddt = [ddx ddy ddphi ddalphaB ddalphaF];

syms M m J lb lf L l g k ks real
syms Fx Fy Tor real;

pos0 = [x;y];
rot0  = phi;

posB = pos0 + lb*L*[cos(phi + pi);sin(phi + pi)];
posF = pos0 + (1-lb)*L*[cos(phi);sin(phi)];


posBFoot = posB + l*[sin(alphaB+phi);-cos(alphaB+phi)];
posFFoot = posF + l*[sin(alphaF+phi);-cos(alphaF+phi)];


JS0 = jacobian(pos0,q');
JR0 = jacobian(rot0,q');

JSB = jacobian(posB,q');
JSF = jacobian(posF,q');

% CoG-velocities (computed via jacobians):
d_CoGS0    = JS0*dqdt.';
d_CoGR0    = JR0*dqdt.';
d_CoGSB   = JSB*dqdt.';
d_CoGSF   = JSF*dqdt.';


% Potential Energy (due to gravity):
V = pos0(2)*M*g + posbl(2)*m*g + posbr(2)*m*g + posfl(2)*m*g + posfr(2)*m*g;
V = simplify(V);

% Kinetic Energy:         
T = 0.5 * (M * sum(d_CoGS0.^2) + ...
           m * sum(d_CoGSbl.^2) + ...
           m * sum(d_CoGSbr.^2) + ...
           m * sum(d_CoGSfl.^2) + ...
           m * sum(d_CoGSfr.^2) + ...
           J * d_CoGR0^2);
T = simplify(T);

% Lagrangian:
L = T-V;
% Partial derivatives:
dLdq   = jacobian(L,q).';
dLdqdt = jacobian(L,dqdt).';
      
% Compute Mass Matrix:
MassMatrix = jacobian(dLdqdt,dqdt);
MassMatrix = simplify(MassMatrix);
disp(MassMatrix)

% Compute the coriolis and gravitational forces:
dL_dqdt_dt = jacobian(dLdqdt,q)*dqdt.';
f_cg = dLdq - dL_dqdt_dt;
f_cg = simplify(f_cg);
disp(f_cg)

% External forces:
u = [Fx Fy Tor -abl*ks*m -abr*ks*m -afl*ks*m -afr*ks*m]';
disp (u);

% The equations of motion are given with these functions as:   
% M * dqddt = f_cg(q, dqdt) + u;
Minv = inv(MassMatrix);
% Minv = simplify(Minv);

qdd = Minv*(f_cg + u);
% qdd1 = simplify(qdd);
% qdd2 = limit(qdd1, J, inf);
qdd2 = limit(qdd, m, 0);
qdd3 = simplify(qdd2);
disp(qdd3)

%% Quadrupedal System Dynamics: Stance Leg using Lagrangian Method

clc;
clear;

syms x y phi alphaB alphaF ...
     dx dy dphi dalphaB dalphaF ...
     ddx ddy ddphi ddalphaB ddalphaF real

q = [x y phi alphaB alphaF]';
dqdt = [dx dy dphi dalphaB dalphaF]';
dqddt = [ddx ddy ddphi ddalphaB ddalphaF]';



syms lb l J M ks Tor Fx Fy real
Para = [lb l J M ks Tor Fx Fy]';

% compute foot position and its derivative:

pos0 = [x;y];

% Back position
posB = pos0 + lb*[cos(phi + pi);sin(phi + pi)] ;
% Back foot position
xFootB = posB(1) + posB(2)*tan(phi + alphaB);
% Back foot velocity
dxFootB  = jacobian(xFootB,q)*dqdt;
% Front foot acceleration
ddxFootB = jacobian(dxFootB,q)*dqdt + ...
           jacobian(dxFootB,dqdt)*dqddt;
% solve to yield dalphaF und dd alphaF:
Fun_dalphaB  = simplify(solve(dxFootB, dalphaB));
Fun_ddalphaB = simplify(solve(ddxFootB, ddalphaB));

% matlabFunction(Fun_dalphaB, Fun_ddalphaB,'File','Func_alphaB_VA_Lag','Outputs',{'dalphaB','ddalphaB'}, 'Vars',{[q;dqdt;dqddt;Para]});
matlabFunction(Fun_dalphaB,'File','Func_dalphaB_Stance','Outputs',{'dalphaB'}, 'Vars',{[q;dqdt;dqddt;Para]});
matlabFunction(Fun_ddalphaB,'File','Func_ddalphaB_Stance','Outputs',{'ddalphaB'}, 'Vars',{[q;dqdt;dqddt;Para]});



% Shoulder position
posF = pos0 + (1-lb)*[cos(phi);sin(phi)] ;
% Front foot position
xFootF = posF(1) + posF(2)*tan(phi + alphaF);
% Front foot velocity
dxFootF  = jacobian(xFootF,q)*dqdt;
% Front foot acceleration
ddxFootF = jacobian(dxFootF,q)*dqdt + ...
           jacobian(dxFootF,dqdt)*dqddt;
% solve to yield dalphaF und dd alphaF:
Fun_dalphaF  = simplify(solve(dxFootF, dalphaF));
Fun_ddalphaF = simplify(solve(ddxFootF, ddalphaF));

% matlabFunction(Fun_dalphaF,Fun_ddalphaF,'File','Func_alphaF_VA_Lag','Outputs',{'dalphaF','ddalphaF'},'Vars',{[q;dqdt;dqddt;Para]});
matlabFunction(Fun_dalphaF,'File','Func_dalphaF_Stance','Outputs',{'dalphaF'},'Vars',{[q;dqdt;dqddt;Para]});
matlabFunction(Fun_ddalphaF,'File','Func_ddalphaF_Stance','Outputs',{'ddalphaF'},'Vars',{[q;dqdt;dqddt;Para]});



%% Quadrupedal System Dynamics: Derivative of Stance Leg Length

clc;
clear;

syms x y phi alphaB alphaF ...
     dx dy dphi dalphaB dalphaF ...
     ddx ddy ddphi ddalphaB ddalphaF real

q = [x y phi alphaB alphaF]';
dqdt = [dx dy dphi dalphaB dalphaF]';
dqddt = [ddx ddy ddphi ddalphaB ddalphaF]';



syms lb l J M ks Tor Fx Fy real
Para = [Fx Fy lb]';
% compute foot position and its derivative:

pos0 = [x;y];
rot0  = phi;




% Hip position
posB = pos0 + lb*[cos(phi + pi);sin(phi + pi)] ;
% Back foot position

l_lb = posB(2)/cos(phi + alphaB);
% Back foot velocity
dl_lb  = jacobian(l_lb,q)*dqdt;
% Front foot acceleration
ddl_lb = jacobian(dl_lb,q)*dqdt + ...
           jacobian(dl_lb,dqdt)*dqddt;
% solve to yield dalphaF und dd alphaF:
Fun_dl_lb  = simplify(dl_lb);
Fun_ddl_lb = simplify(ddl_lb);

matlabFunction(Fun_dl_lb, Fun_ddl_lb,'File','Func_ddLB_Stance_v1','Outputs',{'dLB','ddLB'}, 'Vars',{[q;dqdt;dqddt;Para]});
% matlabFunction(Fun_dl_lb,'File','Func_dLB_Stance','Outputs',{'dLB'},'Vars',{[q;dqdt;dqddt;Para]});
% matlabFunction(Fun_ddl_lb,'File','Func_ddLB_Stance','Outputs',{'ddLB'}, 'Vars',{[q;dqdt;dqddt;Para]});

% Shoulder position
posF = pos0 + (1-lb)*[cos(phi);sin(phi)] ;
% Front foot position
l_lf = posF(2)/cos(phi + alphaF);
% Front foot velocity
dl_lf  = jacobian(l_lf,q)*dqdt;
% Front foot acceleration
ddl_lf = jacobian(dl_lf,q)*dqdt + ...
           jacobian(dl_lf,dqdt)*dqddt;
% solve to yield dalphaF und dd alphaF:
Fun_dl_lf  = simplify(dl_lf);
Fun_ddl_lf = simplify(ddl_lf);

matlabFunction(Fun_dl_lf,Fun_ddl_lf,'File','Func_ddLF_Stance_v1','Outputs',{'dLF','ddLF'},'Vars',{[q;dqdt;dqddt;Para]});
% matlabFunction(Fun_dl_lf,'File','Func_dLF_Stance','Outputs',{'dLF'},'Vars',{[q;dqdt;dqddt;Para]});
% matlabFunction(Fun_ddl_lf,'File','Func_ddLF_Stance','Outputs',{'ddLF'},'Vars',{[q;dqdt;dqddt;Para]});
