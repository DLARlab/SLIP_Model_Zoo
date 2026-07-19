function ParameterVarying2D_Quadruped_v2(para_new,ParaScan,radius,numOPTS)

switch ParaScan
    case 'kl'
        pindex = 1;
    case 'ks'
        pindex = 2;
    case 'j'
        pindex = 3;
    case 'll'
        pindex = 4;
    case 'lb'
        pindex = 6;
    case 'krl'
        pindex = 7;
end


fileinfo = dir('*.mat');

fnames = {fileinfo.name};

for i = 1:size(fnames,2)
    filename = cell2mat(fnames(i));
    load(filename)
    
    if round(0.3*size(results,2)) == 0
        xINIIAL1 = results(1:22,ceil(0.3*size(results,2)));
        xINIIAL2 = results(1:22,ceil(0.3*size(results,2))+1);
    else
        xINIIAL1 = results(1:22,round(0.3*size(results,2)));    
        xINIIAL2 = results(1:22,round(0.3*size(results,2))+1);
    end
    Para     = results(23:end,1);

    para_last = Para(pindex);

    [xFINAL1, xFINAL2, Para] = InterimSearch( para_new, para_last, pindex, xINIIAL1, xINIIAL2, Para, numOPTS);
    disp('Norm = ')
    norm(xFINAL1-xFINAL2)
    while norm(xFINAL1-xFINAL2)<radius
        disp('Distance between initials too short.')
        xINIIAL2 = xFINAL2 + (rand-0.0)*0.01;
        [xFINAL2, ~] = fsolve(@(X) Quadrupedal_ZeroFun_v2(X,Para,'skipSolve'), xINIIAL2, numOPTS);
        disp('Norm = ')
        norm(xFINAL1-xFINAL2)
    end

    disp('Numertical search starts')
    pause(1)
 
    disp('Numertical search starts')
    pause(1)
    results = NumericalContinuation1D_Quadruped_v2(xFINAL1,xFINAL2,Para,radius,numOPTS);

    SaveSolutionBranch(results,ParaScan)

    pause(1)
    disp('Solution saved:')
    disp(filename)
    delete('solution_staging.mat')

    
end

end

%% Interim Search: Given two parameters, change gradually by 10 steps from para_last to para_current
function [xFINAL1, xFINAL2, Para] = InterimSearch(para_current,para_last,pindex, xINIIAL1, xINIIAL2, Para, numOPTS)
    disp('Initial parameter: ' +  string(para_last))
    disp('Target parameter: '  +  string(para_current))
    pause(0.5)
    inter = ( para_current - para_last )/10 ;
    for m = 1:10
        Para(pindex) = para_last + m*inter;
        [xFINAL1, ~] = fsolve(@(X) Quadrupedal_ZeroFun_v2(X,Para,'skipSolve'), xINIIAL1, numOPTS);
        [xFINAL2, ~] = fsolve(@(X) Quadrupedal_ZeroFun_v2(X,Para,'skipSolve'), xINIIAL2, numOPTS);
        xINIIAL1 = xFINAL1;
        xINIIAL2 = xFINAL2;
        disp('Para = ')
        disp(Para)
        pause(0.5)
        [gait,abbr, color_plot, linetype] = Gait_Identification(xFINAL1);
        disp('Current Gait: ')
        disp(abbr)
    end

end
%% Save Solution Branch: Depending on the parameter scanned, and the gait of the branch
function SaveSolutionBranch(result,ParaScan)
    results = result;
    switch ParaScan
        case 'kl'
            pindex = 1;
        case 'ks'
            pindex = 2;
        case 'j'
            pindex = 3;
        case 'll'
            pindex = 4;
        case 'lb'
            pindex = 6;
        case 'krl'
            pindex = 7;
    end
    Para = results(23:end,1);
    
    [gait, abbr, color_plot, linetype] = Gait_Identification(results);
    abbr = char(abbr);
    if abbr(2) == '2'
        title = "BD2_";
    else
        title = "BD1_";
    end
    if string(ParaScan)=='kl' || string(ParaScan)=='ks' || string(ParaScan)=='j'
        filename = title + string(Para(1)) + '_' + string(Para(2)) + '_' + string(Para(3)) + '_' + string(abbr) + '.mat';
    else
        filename = title + string(Para(1)) + '_' + string(Para(2)) + '_' + string(Para(3)) + '_' + string(abbr) + '_' + string(Para(pindex)) + '.mat';
    end
    save(filename,'results')
    
end