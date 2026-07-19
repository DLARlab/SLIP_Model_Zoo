function [ LegVertices, LegFaces ] = ComputeLegGraphics( vecS, l_leg, l_leg_rest, gamma_leg )

% Leg Compression:
comp = (l_leg - l_leg_rest) / l_leg_rest;
% comp = l_leg - l_leg_rest;
% Spring Part 1************************************************************
SWidth = 0.09;
vert_xsp1 = [repmat([ -SWidth,SWidth],1,7), -SWidth];
vert_ysp1 = [-0.4, linspace(-0.4, -0.8 - comp, 13), -0.8 - comp] * l_leg_rest;
vsp1 = LTrans([vert_xsp1;vert_ysp1], gamma_leg, vecS);
fsp1 = [linspace(1,14,14)', linspace(2,15,14)'];

% Upper Leg****************************************************************
% 1. Outline of upper leg
xul(1:3)   = [-0.05, -0.05, -0.10];
yul(1:3)   = [-0.70 - comp, -0.39, -0.39] * l_leg_rest;
phi        = linspace(pi, 0, 20);
xul(4:23)  = cos(phi) * 0.1;
yul(4:23)  = sin(phi) * 0.08 * l_leg_rest;
xul(24:26) = [0.10, 0.05, 0.05];
yul(24:26) = fliplr(yul(1:3));
vul = LTrans([xul; yul], gamma_leg, vecS);
ful = [26, 1:1:25];

% 2. Shaded region in upper leg
vert_xul(1:5)   = linspace(-0.1, 0.1, 5);
vert_yul(1:5)   = -0.39 * l_leg_rest;
vert_xul(6:25)  = 0.1;
vert_yul(6:25)  = linspace(-0.39, 0, 20) * l_leg_rest;
phi             = linspace(0, pi, 15);
vert_xul(26:40) = cos(phi) * 0.1;
vert_yul(26:40) = sin(phi) * 0.08 * l_leg_rest;
vert_xul(41:60) = -0.1;
vert_yul(41:60) = linspace(0, -0.39, 20) * l_leg_rest;
vul2 = LTrans([vert_xul; vert_yul], gamma_leg, vecS);
ful2 = [1,12;3,9;57,15;54,18;51,21;48,24;45,28;42,31;];

% Lower Leg ***************************************************************
xll(1:2)   = [-0.03, -0.03];
yll(1:2)   = [-0.70, -0.81] * l_leg_rest;
phi        = linspace(pi/2, 0, 20);
xll(3:22)  = cos(phi) * 0.10 - 0.1;
yll(3:22)  = (sin(phi) * 0.19 - 1) * l_leg_rest;
phi        = linspace(pi/2, pi/2 + 2*pi, 20);
xll(23:42) = cos(phi) * 0.01;
yll(23:42) = (sin(phi) * 0.01 - 1) * l_leg_rest;
phi        = linspace(pi, pi/2, 10);
xll(43:52) = cos(phi) * 0.10 + 0.1;
yll(43:52) = (sin(phi) * 0.19 - 1) * l_leg_rest;
xll(53:54) = [+0.03, +0.03];
yll(53:54) = [-0.81, -0.70] * l_leg_rest;

% % Compute alignment shift
% y_shift = -comp*l_leg_rest;
% 
% % Scale and shift
% yll = yll  + y_shift;

vll  = LTrans([xll; yll - comp*l_leg_rest], gamma_leg, vecS);
fll  = 1:54;
fsp2 = [1:2:13; 2:2:14]';

% Spring Part 2 ***********************************************************
LegVertices = struct('L_Sp1', vsp1, 'L_UpBO', vul, 'L_Ups', vul2, 'L_low', vll);
LegFaces    = struct('L_Sp1', fsp1, 'L_UpBO', ful, 'L_Ups', ful2, 'L_low', fll, 'L_Sp2', fsp2);

% *********************************************************************
% Local function: rotate and shift objects using linear transformation
function VecTrans = LTrans(VecTrans, gamma, vecS)
    RotM = [cos(gamma), -sin(gamma); sin(gamma), cos(gamma)];
    vec_rot = RotM * VecTrans;
    vec_ = vec_rot + vecS * ones(1, size(VecTrans, 2));
    VecTrans = vec_';
end
% *********************************************************************
end
