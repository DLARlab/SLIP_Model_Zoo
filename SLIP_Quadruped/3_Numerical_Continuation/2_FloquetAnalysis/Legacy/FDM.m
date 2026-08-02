%% Finite Difference Method
clc
filename = 'BD1_20_2_PK.mat';
load(filename)
fn = string(filename(1:strfind(filename,'_v')-1));

EigenValues = zeros(22,size(results,2));
EigenValuesNorm = zeros(13,size(results,2));
EigenVectors = cell(1,size(results,2));
% dLamda = zeros(13,size(results,2));

Onecross = zeros(1,size(results,2));
Bifurindex = zeros(1,size(results,2));
% BifurIndex = zeros(21,size(results,2));

% numOPTS = optimset('Algorithm','levenberg-marquardt',... 
%                    'Display','iter',...
%                    'MaxFunEvals',15000,...
%                    'MaxIter',3000,...
%                    'UseParallel', false,...
%                    'TolFun',1e-6,...
%                    'TolX',1e-9);

% Select the version of framework
TestVersion = 2;

for j = 100:150 % size(results,2)
     index = j;
%      X0 = results(1:22,index);
%      X0 = results(1:13,index);
     Para = results(23:end,index);
     
     fdm  = zeros(13,13);
     fdms = 1e-2;
     for i  = 1:13
         if TestVersion==2
            fdv = zeros(22,1);
            X0 = results(1:22,index);
         else
            fdv = zeros(13,1);
            X0 = results(1:13,index);
         end         
         fdv(i) = fdms;
         X = X0 + fdv;
         % Select the version of framework
         switch TestVersion
             case 2
                [residual,T,Y,P,GRF,Y_EVENT] = Quadrupedal_ZeroFun_v2(X,Para);
             case 2.5
                [residual,T,Y,tEVENT,Y_EVENT,GRF] = Quadrupedal_ZeroFun_v2_5(X,Para);
             case 3
                [residual,T,Y,tEVENT,Y_EVENT,GRF]  = Quadrupedal_ZeroFun_v3(X,Para);
             case 4
                StepSize = 1e-6;
                [residual,T,Y,tEVENT,Y_EVENT,GRF]  = Quadrupedal_ZeroFun_v4(X,Para,StepSize);
         end
         
         fdm(:,i) = Y(end,2:14)' - X0(1:13); 
     end
     fdm = fdm / fdms;
     [V,D] = eig(fdm);
    %  disp('V=')
    %  disp(V)
    %  disp('D=')
    %  disp(D)
    eigenvalues = zeros(13,1);
    for i = 1:13
        eigenvalues(i) = D(i,i);
    end
    EigenValues(:,j) = eigenvalues;
    EigenValuesNorm(:,j) = vecnorm(D)';
    EigenVectors(j)  = {V};
        
    oneminus = size(find((EigenValues(:,j)-1)<-1e-3),1);
    if j>100
        if ~oneminus==oneminus_pre
            Bifurindex(j) = j;
        end
    end
    oneminus_pre = oneminus;
    
    disp('Current Interation:')
    disp(j)
    pause(1.5)
    
    if TestVersion ==4
        filename = 'EV_' + string(fn) + '_v' + string(TestVersion) + '_' + string(fdms) + '_' +  string(StepSize) + '.mat';
    else
        filename = 'EV_' + string(fn) + '_v' + string(TestVersion) + '_' + string(fdms) + '.mat';
    end
    save(filename,'EigenValues','EigenValuesNorm','EigenVectors','Bifurindex')
    
    
end


%% Search for One cross
 Bifurindex = zeros(size(EigenValues,2),1);
for i = 1:size(EigenValues,2)
    
    oneminus = size(find((EigenValues(:,i)-1)<-1e-3),1);
    if i>2
        if ~(oneminus==oneminus_pre)
            Bifurindex(i) = i;
        end
    end
    oneminus_pre = oneminus;
end

Bifurindex(find(Bifurindex==0))=[];

%% Plot EigenValues on the Complex Plane
% load('EV_Pronk_10_20_2.5_Test_v3_1e-3.mat')
x = -1:0.01:1;
y = [sqrt(1-x.^2);-sqrt(1-x.^2)];
figure(10);
box on; hold on;
plot(x,y,'r')
range = 100:270;
R = real(EigenValues(:,range(1)));
I = imag(EigenValues(:,range(1)));
qu = quiver(zeros(13,1),zeros(13,1),R,I,'AutoScale','Off');
for i = range
    R = real(EigenValues(:,i));
    I = imag(EigenValues(:,i));
    set(qu,'UData',R,'VData',I)
    xlim([-2 2])
    ylim([-1.5 1.5])
    pause(0.1)
end

%% Solve for Real Periodic Solution of The New Framework
clc

filename = 'PK_20_2.5.mat';
load(filename)
% numOPTS = optimset('Algorithm','levenberg-marquardt',...
%                    'ScaleProblem','jacobian',...
%                    'Display','iter',...
%                    'MaxFunEvals',15000,...
%                    'MaxIter',3000,...
%                    'UseParallel', false,...
%                    'TolFun',1e-9,...
%                    'TolX',1e-12);
numOPTS = optimset('Algorithm','levenberg-marquardt','Display','iter');

TestVersion = 2.1;
result = zeros(size(results,1),size(results,2));
for i = 10:size(results,2)-10
    X0 = results(1:13,i);
    Para = results(23:end,i);
    switch TestVersion
        case 2.1
            [xFINAL2, ~] = fsolve(@(X) Quadrupedal_ZeroFun_v2_1(X,Para), X0, numOPTS);
            [residual,T,Y,tEVENT,Y_EVENT,GRF]  = Quadrupedal_ZeroFun_v2_1(xFINAL2,Para);
        case 2.5
            [xFINAL2, ~] = fsolve(@(X) Quadrupedal_ZeroFun_v2_5(X,Para), X0, numOPTS);
            [residual,T,Y,tEVENT,Y_EVENT,GRF]  = Quadrupedal_ZeroFun_v2_5(xFINAL2,Para);
        case 3
            [xFINAL2, ~] = fsolve(@(X) Quadrupedal_ZeroFun_v3(X,Para), X0, numOPTS);
            [residual,T,Y,tEVENT,Y_EVENT,GRF]  = Quadrupedal_ZeroFun_v3(xFINAL2,Para);
        case 4
            StepSize = 1e-5;
            [xFINAL2, ~] = fsolve(@(X) Quadrupedal_ZeroFun_v4(X,Para,StepSize), X0, numOPTS);
            [residual,T,Y,tEVENT,Y_EVENT,GRF]  = Quadrupedal_ZeroFun_v4(xFINAL2,Para,StepSize);
    end
    result(1:13,i) = xFINAL2;   
    result(15,i)   = norm(residual);
    result(23:end,i) = Para;
    disp('Interation = ')
    disp(i)
    pause(1)
end
results = result;
if TestVersion ==4
    filename = string(filename(1:strfind(filename,'.mat')-1)) + '_v' + string(TestVersion) +'_' + string(StepSize) +'_Test0.mat';
else
    filename = string(filename(1:strfind(filename,'.mat')-1)) + '_v' + string(TestVersion) +'_Test0.mat';
end
save(filename,'results','numOPTS')

