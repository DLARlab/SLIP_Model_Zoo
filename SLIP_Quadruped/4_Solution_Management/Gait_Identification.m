% From MATLAB 2023a
%    orderedcolors('gem12');
%    [         0    0.4470    0.7410     % Pronking
%         0.8500    0.3250    0.0980     % Bounding
%         0.9290    0.6940    0.1250     % Half-Bounding-Hind-Spread
%         0.4940    0.1840    0.5560     % Galloping
%         0.4660    0.6740    0.1880     % Half-Bounding-Fore-Spread
%         0.3010    0.7450    0.9330
%         0.6350    0.0780    0.1840     % Tolting
%         1.0000    0.8390    0.0390
%         0.3960    0.5090    0.9920
%         1.0000    0.2700    0.2270   
%              0    0.6390    0.6390     % Trotting
%         0.7960    0.5170    0.3640];   % Pacing

%% Identifying the type of gaits for a given solution or solution branch, return the name of gait and the color for visualization
function [gait,abbr, color_plot, linetype] = Gait_Identification(results)
    if size(results,2)<15
        [gait,abbr, color_plot, linetype] = Type_of_Gait(results(:,1));
    else
        downsample_rate = fix(size(results,2)/15);
        indices = downsample(1:size(results,2),downsample_rate);
        count = 1;
        
        [gait_last,abbr_current, color_current, linetype_current] = Type_of_Gait(results(:,indices(1)));

        for i = 2:length(indices)

            X = EventTimingRegulation(results(1:22,indices(i)));

            [gait_current,abbr_current, color_current, linetype_current] = Type_of_Gait(X);

            if string(gait_current)==string(gait_last)
                count = count +1;
                if count>6
                    gait = gait_current;
                    abbr = abbr_current;
                    color_plot = color_current;
                    linetype = linetype_current;
                    return
                end
            end

            if i == length(indices)
                    disp('Gait identification error for current branch.')
                    disp('Using gait of current solution for representative.')
                    [gait,abbr, color_plot, linetype] = Type_of_Gait(X);
            end

            gait_last = gait_current;
        end

    end
end

%% Gait identifying function
function [gait,abbr, color_plot, linetype] = Type_of_Gait(X)
    
    gait = [];
    abbr = [];
    color_plot = [];
    linetype = [];


    threshold = 1e-6; % threshold for identifying 'equal'

    if abs(abs(X(14)-X(18))/X(22) - 0.5)<threshold && abs(abs(X(15)-X(19))/X(22) - 0.5)<threshold...
       && abs(abs(X(16)-X(20))/X(22) - 0.5)<threshold && abs(abs(X(17)-X(21))/X(22) - 0.5)<threshold
        % Symmetrical Gaits
         [nof, maxstance] = FlightStancePhaseCheck(X);

        if abs(X(14)-X(16))<threshold && abs(X(15)-X(17))<threshold && abs(X(18)-X(20))<threshold && abs(X(19)-X(21))<threshold
            type1 = 'Pacing';
            abbr1 = 'PC';
            color_plot = [0.7960  0.5170  0.3640];
            if ~(nof == 2)
                type2 = '-Walk';
                abbr2 = '-W';
                linetype = '-.';
            else
                type2 = '';
                abbr2 = '';
                linetype = '-';
            end
        elseif abs(X(14)-X(20))<threshold && abs(X(15)-X(21))<threshold && abs(X(16)-X(18))<threshold && abs(X(17)-X(19))<threshold
            type1 = 'Trotting';
            abbr1 = 'TR';
            color_plot = [0  0.6390  0.6390] ;
            if ~(nof == 2)
                type2 = '-Walk';
                abbr2 = '-W';
                linetype = '-.';
            else
                type2 = '';
                abbr2 = '';
                linetype = '-';
            end
        else
            type1 = 'Tolting';   % lateral sequence walking, ambling, tolting
            abbr1 = 'TL';
            color_plot = [0.6350  0.0780  0.1840];
            if maxstance>2
                type2 = '-Walk';
                abbr2 = '-W';
                linetype = '-.';
            elseif maxstance>1
                type2 = '-Amble';
                abbr2 = '-A';
                linetype = '-';
            else
                type2 = '';
                abbr2 = '';
                linetype = '--';
            end
        end
    
        gait = string(type1) + string(type2);
        abbr = string(abbr1) + string(abbr2);
        
    else
        % Asymmetical Gaits
        if abs(X(14)-X(18))<threshold && abs(X(16)-X(20))<threshold && abs(X(14)-X(16))<threshold && abs(X(16)-X(20))<threshold
            type1 = 'Pronking';
            abbr1 = 'PF';
            color_plot = [0 0.4470 0.7410];
        elseif abs(X(14)-X(18))<threshold && abs(X(16)-X(20))<threshold
            type1 = 'Bounding';
            abbr1 = 'B';
            color_plot = [0.8500 0.3270 0.0980];
        elseif abs(X(14)-X(18))<threshold 
            type1 = 'Half-Bounding with Front Legs Spread';
            abbr1 = 'F';
            color_plot = [0.4660 0.6740 0.1880];
        elseif abs(X(16)-X(20))<threshold 
            type1 = 'Half-Bounding with Hind Legs Spread';
            abbr1 = 'H';
            color_plot = [0.9290 0.6940 0.1270];
        else
            type1 = 'Galloping';
            abbr1 = 'G';
            color_plot = [0.4940 0.1840 0.5560];
        end
        
        [nof, maxstance] = FlightStancePhaseCheck(X);
        MidstanceDiff = CalMidstance(X);
        % if ~(nof==1) && ( MidstanceDiff>0.3 && MidstanceDiff<0.70)
        if  MidstanceDiff>0.3 && MidstanceDiff<0.70
            type2 = '_with Additional Flight Phases';
            abbr2 = '2';
            linetype = '--';
        elseif abs(X(5))<1e-9
            type2 = '';
            abbr2 = '';
            linetype = '-';
        elseif X(5)>0
            type2 = '_with Gathered Suspension';
            abbr2 = 'G';
            linetype = '-';
        elseif  X(5)<0
            type2 = '_with Extended Suspension';
            abbr2 = 'E';
            linetype = ':';
        end
        
        gait = string(type1) + string(type2);
        abbr = string(abbr1) + string(abbr2);
    end


end

%% Flight phase check
function [nof, maxstance] = FlightStancePhaseCheck(X)
   X(14:22) = round(X(14:22),4);
   % draw time line
   dt = 1e-4;
   timeline = 0:dt:X(22);

   % extract the stance time of each leg
   if X(14)<X(15)
      bls = X(14):dt:X(15);
   else
      bls = [0:dt:X(15)  X(14):dt:X(22)];
   end 
   if X(16)<X(17)
      fls = X(16):dt:X(17);
   else
      fls = [0:dt:X(17)  X(16):dt:X(22)];
   end  
   if X(18)<X(19)
      brs = X(18):dt:X(19);
   else
      brs = [0:dt:X(19)  X(18):dt:X(22)];
   end 
   if X(20)<X(21)
      frs = X(20):dt:X(21);
   else
      frs = [0:dt:X(21)  X(20):dt:X(22)];
   end

   % extract total stance time
   stance = unique(sort(round([bls fls brs frs],4)));

   diffstance = round(diff(stance)/dt);
   nof = length(find(~(diffstance==1)));

   if X(14)<X(15) && X(16)<X(17) && X(18)<X(19) && X(20)<X(21)
       nof = nof +1;
   end

   % bounding gait exception
   if abs(X(14)-X(18))<1e-6 && abs(X(16)-X(20))<1e-6 
       if sign(X(5))==1 && X(16)-X(15)<0.2*X(22)
           nof = 1;
       end
       if sign(X(5))==-1 && X(14)-X(17)<0.2*X(22)
           nof = 1;
       end
   end

   %  Compute max number of legs in stance at any time 
   bls_mask = ismember(round(timeline,4), round(bls,4));
   fls_mask = ismember(round(timeline,4), round(fls,4));
   brs_mask = ismember(round(timeline,4), round(brs,4));
   frs_mask = ismember(round(timeline,4), round(frs,4));
   total_stance_mask = bls_mask + fls_mask + brs_mask + frs_mask;
   maxstance = max(total_stance_mask);

end
%% Midstance Diff Check
function MidstanceDiff = CalMidstance(X)
    % calculate mid stance of left hind
    if X(14)<X(15)
        lh_ms = (X(14)+X(15))/2/X(22);
    elseif X(14)>X(15)
        lh_ms = (X(14)+X(15)+X(22))/2/X(22);
    end
    
    % calculate mid stance of right hind
    if X(18)<X(19)
        rh_ms = (X(18)+X(19))/2/X(22);
    elseif X(18)>X(19)
        rh_ms = (X(18)+X(19)+X(22))/2/X(22);
    end

    % calculate midstance of hind leg pair
    if norm(lh_ms-rh_ms)<0.5
        hms = (lh_ms+rh_ms)/2;
    else
        hms = (lh_ms + rh_ms + 1)/2;
    end
        
    if hms>1
        hms = hms-1;
    end

    % calculate mid stance of left front
    if X(16)<X(17)
        lf_ms = (X(16)+X(17))/2/X(22);
    elseif X(16)>X(17)
        lf_ms = (X(16)+X(17)+X(22))/2/X(22);
    end

    % calculate mid stance of right front
    if X(20)<X(21)
        rf_ms = (X(20)+X(21))/2/X(22);
    elseif X(20)>X(21)
        rf_ms = (X(20)+X(21)+X(22))/2/X(22);
    end

    % calculate midstance of hind leg pair
    if norm(lf_ms-rf_ms)<0.5
        fms = (lf_ms+rf_ms)/2;
    else
        fms = (lf_ms+rf_ms+1)/2;
    end

    if fms>1
        fms = fms-1;
    end

    MidstanceDiff = norm(fms-hms);


end