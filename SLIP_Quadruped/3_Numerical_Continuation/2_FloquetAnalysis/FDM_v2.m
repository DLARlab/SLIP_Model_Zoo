%% Finite Difference Method
clc
% filename = 'PK_10_20_2.mat';
[filename, pathname] = uigetfile('*.mat', 'Select a MAT file');
load(filename)

load(filename)
fn = string(filename(1:strfind(filename,'_v')-1));

EigenValues = zeros(13,size(results,2));
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


% symmetries = {'(BL,BR)'};
symmetries = {'(FL,FR)'};
% symmetries = {'(FL,FR)','(BL,BR)'};
range = 1:size(results,2);
for j = range 
     index = j;
%      X0 = results(1:13,index);
%      X0 = results(1:13,index);
     X0 = results(1:22,index);
     Para = results(23:end,index);
     
     fd_measurement  = zeros(13,13);
     % finite difference: smaller
     % central differetiating
     fd_size = 1e-6;
     
     
     numOPTS = optimset('Algorithm','levenberg-marquardt',...
                   'ScaleProblem','jacobian',...
                   'Display','iter',...
                   'MaxFunEvals',10000,...
                   'MaxIter',1000,...
                   'UseParallel', false,...
                   'TolFun',fd_size,...
                   'TolX',fd_size*1e-3);



     for i  = 1:13

         fd_variation = zeros(13,1);
         
         fd_variation(i) = fd_size;
         Q_pertuated = X0(1:13) + fd_variation;
         
%          % use fsolve to find the real timing variables after pertubation
%          if i>0 && i<14
        
         E_initial  = X0(14:22);
         [E_real, ~] = fsolve(@(E) Quadrupedal_ZeroFun_v2_FDM(Q_pertuated,E,Para,symmetries), E_initial, numOPTS);
         [residual,T,Y,P,GRFs,Y_EVENT] = Quadrupedal_ZeroFun_v2_FDM(Q_pertuated,E_real,Para,symmetries);
         fd_measurement(:,i) = Y(end,2:14)' - X0(1:13); 
%          else
%              Q  = [X_pertubated(1:13);X_pertubated(13)];
%              E_pertuated  = X_pertubated(14:21);
%              [Q_final, ~] = fsolve(@(Q) Quadrupedal_ZeroFun_v2_FDM(Q,E_pertuated,Para), Q, numOPTS);
%              [residual,T,Y,P,GRFs,Y_EVENT] = Quadrupedal_ZeroFun_v2_FDM(Q_final,E_pertuated,Para);
%              fd_measurement(:,i) = [Y(end,2:14)' - X0(1:13); E_pertuated - X0(14:21);Q_pertuated(end) - X_pertubated(13)]; 
%          end
     end

     fd_measurement = fd_measurement / fd_size;
     [V,D] = eig(fd_measurement);
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
    if j>range(1)
        if ~oneminus==oneminus_pre
            Bifurindex(j) = j;
        end
    end
    oneminus_pre = oneminus;
    
    disp('Current Interation:')
    disp(j)
    pause(0.5)
      
    
end

[~, name, ~] = fileparts(filename); 

% Convert symmetries list to a safe string for filename
symmetries_string = strjoin(symmetries, '_');                     % Join symmetries with underscore
safe_symmetries = regexprep(symmetries_string, '[^a-zA-Z0-9]', ''); % Remove non-alphanumeric characters

% Create the final filename with symmetries at the end using []
save_filename = [name, '_', num2str(fd_size), '_', safe_symmetries, '.mat'];

save(save_filename,'EigenValues','EigenValuesNorm','EigenVectors','Bifurindex','results','symmetries')


%% Plot EigenValues on the Complex Plane

PlotEigenvaluesInteractive()

%% Check if it is bifurcation

% filename = 'Test_PK_1e-9_sorted.mat';
[filename, pathname] = uigetfile('*.mat', 'Select a MAT file');
load(filename)
numOPTS = optimset('Algorithm','levenberg-marquardt',...
                   'ScaleProblem','jacobian',...
                   'Display','off',...
                   'MaxFunEvals',10000,...
                   'MaxIter',1000,...
                   'UseParallel', false,...
                   'TolFun',1e-9,...
                   'TolX',1e-12);

for j = 1:length(crossingIndices)
    index = crossingIndices(j);
    disp('Current Solution Index = ')
    disp(index)

    X = results(1:22,index);
    Para = results(23:end,index);
    
    eigenvector = eigenvectorCells{1,index};
    
    index_cross = find(crossingMatrix(:,index)==1);
    for i = 1:length(index_cross)
        
        bifur_pertu = eigenvector(:,index_cross(i));
        
        if isreal(bifur_pertu)
            Q_pertuated = X(1:13) + 1e-1*bifur_pertu;
        else
            Q_pertuated = X(1:13) + 1e-2*real(bifur_pertu) + 1e-1*imag(bifur_pertu);
        end
    
        E_initial  = X(14:22);
        [E_real, ~] = fsolve(@(E) Quadrupedal_ZeroFun_v2_FDM(Q_pertuated,E,Para), E_initial, numOPTS);
        [residual,T,Y,P,GRF,Y_EVENT] = Quadrupedal_ZeroFun_v2_FDM(Q_pertuated,E_real,Para);
    
    
        
        % % Light version of plotting: 1.Traj and GRF only   2. Animation and PO
        ShowTrajectory_Quadruped(X,T,Y,GRF)
    %     ShowAnimation_Quadruped(X,T,Y,P)
        
        disp("Hit Enter to Continue.")
        pause()
    end

end
