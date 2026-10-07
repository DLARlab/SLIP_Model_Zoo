function [results,flags,info] = NumericalContinuation1D_Quadruped_v2(X1,X2,Para,Radius,numOPTS,runOptions)
%NUMERICALCONTINUATION1D_QUADRUPED_V2 Continue a periodic-solution branch.
% Call with five inputs for standalone plotting and command-window output.
% GUI callers can pass runOptions.Callbacks with onAcceptedPoint, onStatus,
% and onFinish handlers; every handler receives a continuation state struct.
% PreserveSeedOrder=true keeps X1 -> X2 as the initial oriented secant.
% DirectionCount=1 searches only that orientation. Defaults (false and 2)
% retain descending-speed seed ordering and the two-direction search.

    if nargin < 6 || isempty(runOptions)
        runOptions = struct();
    end

    runtime = ContinuationRuntimeSettings(runOptions);

    if runtime.ResetFigureOnStart
        close all
    end
    if runtime.ClearCommandWindow
        clc
    end

    if nargin < 4 || isempty(Radius)
        Radius = 0.05;
    end
    if nargin < 5 || isempty(numOPTS)
        numOPTS = DefaultContinuationOptions();
    end

    X1 = EventTimingRegulation(X1(:));
    X2 = EventTimingRegulation(X2(:));
    Para = Para(:);

    % Historical callers search descending velocity first. Branch switching
    % can instead supply an already oriented pair, including equal-dx seeds.
    results(:,1) = [X1;Para]; 
    results(:,2) = [X2;Para];
    if ~runtime.PreserveSeedOrder
        results = flip(sortrows(results.',1).',2); % historical descending-speed seed order
    end
    lifted_results = ReliftSequence(results(1:22,:));
    flags = strings(1,runtime.DirectionCount);
    InitializeTemporarySolution(runtime, results, lifted_results);
    log_path = CreateContinuationLogPath();
    direction_labels = ["Descending Velocity","Ascending Velocity"];
    if runtime.PreserveSeedOrder
        direction_labels = ["Seed secant","Opposite secant"];
    end
    direction_labels = direction_labels(1:runtime.DirectionCount);
    BranchPlot = InitializeBranchPlot(results, runtime);

    AppendContinuationLog(log_path, sprintf( ...
        'Run start | Radius=%.6g | Seeds speed=[%.6g %.6g] | T=[%.6g %.6g] | minTimingGap=[%.6g %.6g]', ...
        Radius, results(1,1), results(1,2), results(22,1), results(22,2), ...
        MinimumTimingGap(results(1:22,1)), MinimumTimingGap(results(1:22,2))));
    RunContinuationCallback(runtime.Callbacks.onStatus, ContinuationCallbackState( ...
        'start', '1D continuation started.', results, lifted_results, Para, Radius, '', [], [], [], [], [], ...
        struct('logFile', log_path, 'solutionSolved', false)));
    
      
     
    % Search one oriented secant, or both orientations as requested.
    for direction_idx = 1:runtime.DirectionCount
            direction_name = direction_labels(direction_idx);
            AppendContinuationLog(log_path, sprintf( ...
                '%s start | branchCols=%d | endSpeed=%.6g | endT=%.6g | minTimingGap=%.6g', ...
                char(direction_name), size(results,2), results(1,end), results(22,end), MinimumTimingGap(results(1:22,end))));
            RunContinuationCallback(runtime.Callbacks.onStatus, ContinuationCallbackState( ...
                'direction-start', sprintf('%s start.', char(direction_name)), ...
                results, lifted_results, Para, Radius, direction_name, direction_idx, 0, ...
                results(1:22,end), [], [], struct('logFile', log_path, 'solutionSolved', false)));
            % Searching for solutions along 1 direction
            [results,lifted_results,flag,last_iteration] = UniDirectionSearch( ...
                results,lifted_results,Radius,numOPTS,runtime,BranchPlot,log_path,direction_name,direction_idx);

            % Finish searching for one direction, if the algorithm stops because of meeting the setup criteria
            if runtime.DirectionPauseSeconds > 0
                pause(runtime.DirectionPauseSeconds);
            end
            flags(direction_idx) = string(flag);
            [~, end_gait_abbr] = SafeGaitIdentification(results(1:22,end));
            AppendContinuationLog(log_path, sprintf( ...
                '%s stop | terminated=1 | lastIteration=%d | flag=%s | branchCols=%d | dx=%.6g | gait=%s', ...
                char(direction_name), last_iteration, char(flags(direction_idx)), size(results,2), ...
                results(1,end), end_gait_abbr));
            RunContinuationCallback(runtime.Callbacks.onStatus, ContinuationCallbackState( ...
                'direction-stop', sprintf('%s stop | %s', char(direction_name), char(flags(direction_idx))), ...
                results, lifted_results, Para, Radius, direction_name, direction_idx, last_iteration, ...
                results(1:22,end), [], [], struct( ...
                'flag', char(flags(direction_idx)), ...
                'terminated', true, ...
                'terminationReason', char(flags(direction_idx)), ...
                'logFile', log_path, ...
                'solutionSolved', false)));
            SaveTemporarySolution(runtime, results, lifted_results, flag);
            if strcmp(flag, 'Algorithm stopped by user.')
                if direction_idx < numel(flags)
                    flags(direction_idx + 1:end) = "Not run: user stop.";
                end
                break;
            end
            if direction_idx == 1 && runtime.DirectionCount > 1 && ClosedSolutionComponentDetected(flag)
                flags(direction_idx + 1:end) = ...
                    "Not run: first direction closed the solution component.";
                AppendContinuationLog(log_path, ...
                    'Opposite direction skipped | first direction closed the solution component.');
                disp('Algorithm stopped, the closed solution component is fully covered.')
                break;
            end
            % Flip the results matrix(sort ascendingly), prepare for searching for the other direction.
            if direction_idx < runtime.DirectionCount
                results = flip(results,2);
                lifted_results = ReliftSequence(results(1:22,:));
                AppendContinuationLog(log_path, sprintf( ...
                    'Direction flip | newEndSpeed=%.6g | newEndT=%.6g | minTimingGap=%.6g', ...
                    results(1,end), results(22,end), MinimumTimingGap(results(1:22,end))));
                fprintf('Finish searching %s, start searching %s.\n', ...
                    char(direction_labels(1)), char(direction_labels(2)));
            else
                if runtime.DirectionCount == 2
                    disp('Algorithm stopped, the entire branch found.')
                else
                    disp('Algorithm stopped, the requested continuation direction finished.')
                end
            end
    end

    % Delete explicitly only after a criteria-driven return. An onCleanup
    % handler would also run during Ctrl+C unwinding and erase the checkpoint.
    temporary_file = TemporarySolutionPath(runtime);
    temporary_solution_deleted = false;
    if runtime.DeleteTempSolOnFinish && StoppedByAutomaticCriteria(flags)
        temporary_solution_deleted = DeleteTemporarySolution(temporary_file);
        AppendContinuationLog(log_path, sprintf( ...
            'Temporary solution cleanup | criteriaDriven=1 | deleted=%d | file=%s', ...
            temporary_solution_deleted, temporary_file));
    elseif runtime.DeleteTempSolOnFinish
        AppendContinuationLog(log_path, sprintf( ...
            'Temporary solution preserved | criteriaDriven=0 | file=%s', temporary_file));
    end

    info = BuildContinuationInfo(lifted_results, Para, log_path, direction_labels, Radius, numOPTS);
    info.flags = flags;
    info.termination_reasons = cellstr(flags);
    info.total_points = size(results,2);
    info.preserve_seed_order = runtime.PreserveSeedOrder;
    info.direction_count = runtime.DirectionCount;
    info.temporary_solution_file = temporary_file;
    info.temporary_solution_deleted_on_finish = temporary_solution_deleted;
    AppendContinuationLog(log_path, sprintf('Run end | flags=[%s] | finalCols=%d', strjoin(cellstr(flags), ' | '), size(results,2)));
    finish_extra = struct();
    finish_extra.flags = flags;
    finish_extra.info = info;
    finish_extra.logFile = log_path;
    finish_extra.terminationReasons = cellstr(flags);
    finish_extra.solutionSolved = false;
    RunContinuationCallback(runtime.Callbacks.onFinish, ContinuationCallbackState( ...
        'finish', sprintf('1D continuation finished with %d points.', size(results,2)), ...
        results, lifted_results, Para, Radius, '', [], [], [], [], [], ...
        finish_extra));
end
%% UniDirection search algorithm
function [results,lifted_results,flag,last_iteration] = UniDirectionSearch(results,lifted_results,Radius,numOPTS,runtime,BranchPlot,log_path,direction_name,direction_idx)
    Para = results(23:end,1);
    direction_label = char(direction_name);
    search_config = SearchSetting(Radius, runtime);

    % Numerical scaling controls solver/iteration adaptation.
    numerical_radius = Radius;
    stagnation_count = 0;
    failed_step_count = 0;
    revisit_count = 0;
    previous_revisit_index = NaN;

    flag = 'Maximum iteration count reached.';
    last_iteration = 0;
    predict_solution = [];
    predict_text = [];

    if runtime.IlluSols
        ClearPredictorOverlay(BranchPlot);
    end

for k = 1:search_config.max_iterations
       last_iteration = k;
       new_step_scaled = NaN;
       failure_reason = 'Algorithm stops because of numerical issues.';
       user_stop_requested = WaitForContinuationControl(runtime.Callbacks.onControl);
       if user_stop_requested
           flag = 'Algorithm stopped by user.';
           ReportUserContinuationStop(runtime, log_path, results, lifted_results, Para, Radius, ...
               direction_name, direction_idx, k, [], []);
           break;
       end

       state_scale = LocalScaleVector(lifted_results(:,end), lifted_results(:,end-1));
       secant = lifted_results(:,end) - lifted_results(:,end-1);
       secant_norm = norm(secant ./ state_scale);
       if secant_norm < 1e-10
            flag = 'Algorithm stopped: lifted secant collapsed.';
            AppendContinuationLog(log_path, sprintf( ...
                '%s | iter %d | secant collapsed | scaledSecant=%.6g | numericalRadius=%.6g', ...
                direction_label, k, secant_norm, numerical_radius));
            disp(flag)
            break;
       end
       tangent = secant / secant_norm;
       [direction_radius, theta_turn] = DirectionRadiusScaling( ...
           lifted_results, search_config.radius_floor, search_config.radius_ceiling);
       predictor_radius = min(numerical_radius, direction_radius);
       AppendContinuationLog(log_path, sprintf([ ...
           '%s | iter %d | predict | speed=%.6g | T=%.6g | theta=%.6g | ' ...
           'numericalRadius=%.6g | directionRadius=%.6g | predictorRadius=%.6g | minTimingGap=%.6g'], ...
           direction_label, k, results(1,end), results(22,end), theta_turn, ...
           numerical_radius, direction_radius, predictor_radius, MinimumTimingGap(results(1:22,end))));

       % Numerical Continuation using Prediction-Correction method: assume a new solution always exists in the neighborhood of existing solutions
       % Prediction of new solution: X(k)* = X(k-1) + (X(k-1)-X(k-2))*d
       % Prediction of the k th solution
       % Time check funtion: ensure timing events are in between [0, T]
       X_anchor_lifted = lifted_results(:,end) + predictor_radius * tangent;
       X_anchor_chart = EventTimingRegulation(X_anchor_lifted);
       X0 = X_anchor_chart;
       RunContinuationCallback(runtime.Callbacks.onStatus, ContinuationCallbackState( ...
           'corrector-start', sprintf('%s | iter %d | solving predicted solution.', direction_label, k), ...
           results, lifted_results, Para, Radius, direction_name, direction_idx, k, ...
           results(1:22,end), [], [], struct( ...
           'solutionSolved', false, ...
           'predictedSolution', X0, ...
           'predictorRadius', predictor_radius, ...
           'numericalRadius', numerical_radius, ...
           'directionRadius', direction_radius, ...
           'thetaTurn', theta_turn, ...
           'logFile', log_path)));
       
       % Code for Illustration
       if runtime.IlluSols
           [predict_solution, predict_text] = UpdatePredictorOverlay( ...
               BranchPlot, results, X0, predict_solution, predict_text);
       end

       % Correction of the prediction of k th solution
       tangent_state_scaled = tangent ./ state_scale;
       accepted_predictor_radius = predictor_radius;
       accepted_backtrack_attempt = 0;
       [xFINAL,fval,exitflag,output,solver_error] = SafeCorrectorSolve( ...
           X_anchor_chart,Para,X_anchor_chart,state_scale,tangent_state_scaled,numOPTS, ...
           runtime.Callbacks.onControl);
       user_stop_requested = WaitForContinuationControl(runtime.Callbacks.onControl);
       if user_stop_requested
           flag = 'Algorithm stopped by user.';
           ReportUserContinuationStop(runtime, log_path, results, lifted_results, Para, Radius, ...
               direction_name, direction_idx, k, fval, output);
           break;
       end
       if ~isempty(solver_error)
           failure_reason = 'Algorithm stopped: corrector solver exception.';
       end
       accepted = exitflag > 0 && SolutionAccepted(fval, xFINAL);
       if isempty(solver_error)
           AppendContinuationLog(log_path, sprintf( ...
               '%s | iter %d | corrector primary | exitflag=%d | residual=%.6g | solverIterations=%.6g | funcCount=%.6g', ...
               direction_label, k, exitflag, SafeResidualNorm(fval), ...
               SafeIterationCount(output), SafeFunctionCount(output)));
       else
           AppendContinuationLog(log_path, sprintf( ...
               '%s | iter %d | corrector primary | exitflag=%g | residual=%.6g | solverIterations=%.6g | funcCount=%.6g | exception=%s', ...
               direction_label, k, exitflag, SafeResidualNorm(fval), ...
               SafeIterationCount(output), SafeFunctionCount(output), solver_error));
       end

       if ~accepted
           for attempt = 1:search_config.backtrack_attempts
               user_stop_requested = WaitForContinuationControl(runtime.Callbacks.onControl);
               if user_stop_requested
                   break;
               end
               radius_try = predictor_radius / (2^attempt);
               X_anchor_try_lifted = lifted_results(:,end) + radius_try * tangent;
               X_anchor_try_chart = EventTimingRegulation(X_anchor_try_lifted);
               RunContinuationCallback(runtime.Callbacks.onStatus, ContinuationCallbackState( ...
                   'backtrack', sprintf('%s | iter %d | backtrack %d | solving at radius %.4g.', ...
                   direction_label, k, attempt, radius_try), results, lifted_results, Para, Radius, ...
                   direction_name, direction_idx, k, results(1:22,end), fval, output, struct( ...
                   'solutionSolved', false, ...
                   'predictedSolution', X_anchor_try_chart, ...
                   'correctorAttempt', attempt, ...
                   'predictorRadius', radius_try, ...
                   'numericalRadius', numerical_radius, ...
                   'directionRadius', direction_radius, ...
                   'thetaTurn', theta_turn, ...
                   'exitflag', exitflag, ...
                   'logFile', log_path)));
               [xTRY,fTRY,exitflag_try,output_try,solver_error_try] = SafeCorrectorSolve( ...
                   X_anchor_try_chart,Para,X_anchor_try_chart,state_scale,tangent_state_scaled,numOPTS, ...
                   runtime.Callbacks.onControl);
               user_stop_requested = WaitForContinuationControl(runtime.Callbacks.onControl);
               if user_stop_requested
                   fval = fTRY;
                   output = output_try;
                   break;
               end
               if ~isempty(solver_error_try)
                   failure_reason = 'Algorithm stopped: corrector solver exception.';
                   AppendContinuationLog(log_path, sprintf( ...
                       '%s | iter %d | backtrack %d | radiusTry=%.6g | exitflag=%g | residual=%.6g | solverIterations=%.6g | funcCount=%.6g | exception=%s', ...
                       direction_label, k, attempt, radius_try, exitflag_try, SafeResidualNorm(fTRY), ...
                       SafeIterationCount(output_try), SafeFunctionCount(output_try), solver_error_try));
               else
                   AppendContinuationLog(log_path, sprintf( ...
                       '%s | iter %d | backtrack %d | radiusTry=%.6g | exitflag=%d | residual=%.6g | solverIterations=%.6g | funcCount=%.6g', ...
                       direction_label, k, attempt, radius_try, exitflag_try, SafeResidualNorm(fTRY), ...
                       SafeIterationCount(output_try), SafeFunctionCount(output_try)));
               end
               if exitflag_try > 0 && SolutionAccepted(fTRY, xTRY)
                   xFINAL = xTRY;
                   fval = fTRY;
                   exitflag = exitflag_try;
                   output = output_try;
                   accepted_predictor_radius = radius_try;
                   accepted_backtrack_attempt = attempt;
                   accepted = true;
                   break;
               end
               % Keep the most recent attempt as the final failure diagnostic.
               xFINAL = xTRY;
               fval = fTRY;
               exitflag = exitflag_try;
               output = output_try;
           end
       end

       if user_stop_requested
           flag = 'Algorithm stopped by user.';
           ReportUserContinuationStop(runtime, log_path, results, lifted_results, Para, Radius, ...
               direction_name, direction_idx, k, fval, output);
           break;
       end

       % Save the solution and keep searching if the solution is periodic,
       % or stop searching when the solution is not converging
       if accepted % && xFINAL(1)<18) || (norm(fval) < 5e-7 && xFINAL(1)>18)
          previous_X_wrapped = results(1:22,end);
          X_wrapped = EventTimingRegulation(xFINAL);
          X_lifted = LiftTimingStateToReference(X_wrapped, lifted_results(:,end));
          new_step_scaled = norm((X_lifted - lifted_results(:,end)) ./ state_scale);
          state_distance = norm(X_wrapped(1:13) - previous_X_wrapped(1:13));
          if ~CandidateIsNew(X_lifted, lifted_results, state_scale, accepted_predictor_radius)
              accepted = false;
              failure_reason = 'Algorithm stopped: duplicate solution detected near the current point.';
              AppendContinuationLog(log_path, sprintf( ...
                  '%s | iter %d | duplicate candidate | scaledStep=%.6g | residual=%.6g', ...
                  direction_label, k, new_step_scaled, SafeResidualNorm(fval)));
          end
       end

       if accepted % && xFINAL(1)<18) || (norm(fval) < 5e-7 && xFINAL(1)>18)
          lifted_results(:,end+1) = X_lifted;
          results(:,end+1) = [X_wrapped;Para];
          failed_step_count = 0;

          if runtime.IlluSols
              AppendRealSolutionMarker(BranchPlot, X_wrapped);
          end

          iter_count = SafeIterationCount(output);
          numerical_radius = NumericalRadiusScaling( ...
              accepted_predictor_radius, iter_count, search_config.numerical_target_iterations, ...
              search_config.radius_floor, search_config.radius_ceiling);
          [next_direction_radius, theta_next] = DirectionRadiusScaling( ...
              [lifted_results, X_lifted], search_config.radius_floor, search_config.radius_ceiling);
          next_predictor_radius = min(numerical_radius, next_direction_radius);

          % Save the solution and continue searching
          if runtime.SaveTempSol
              SaveTemporarySolution(runtime, results, lifted_results, 'Running');
          end
          [gait_name, gait_abbr] = SafeGaitIdentification(X_wrapped);
          accepted_state = ContinuationCallbackState( ...
              'accepted-point', '', results, lifted_results, Para, Radius, ...
              direction_name, direction_idx, k, X_wrapped, fval, output, ...
              struct('solutionSolved', true, ...
                     'solverIterations', iter_count, ...
                     'solverFunctionCount', SafeFunctionCount(output), ...
                     'exitflag', exitflag, ...
                     'correctorAttempt', accepted_backtrack_attempt, ...
                     'currentDx', X_wrapped(1), ...
                     'period', X_wrapped(22), ...
                     'gait', gait_name, ...
                     'gaitAbbr', gait_abbr, ...
                     'distanceFromPreviousState', state_distance, ...
                     'scaledStep', new_step_scaled, ...
                     'numericalRadius', numerical_radius, ...
                     'directionRadius', next_direction_radius, ...
                     'predictorRadius', next_predictor_radius, ...
                     'thetaTurn', theta_next, ...
                     'minimumTimingGap', MinimumTimingGap(X_wrapped), ...
                     'logFile', log_path));
          accepted_state.message = FormatAcceptedPointStatus(accepted_state);
          AppendContinuationLog(log_path, FormatAcceptedPointLog(accepted_state));
          RunContinuationCallback(runtime.Callbacks.onAcceptedPoint, accepted_state);
          RunContinuationCallback(runtime.Callbacks.onStatus, accepted_state);
          % Display the current solution summary at once.
          if runtime.DisplayCommandStatus
              DisplayContinuationStatus(accepted_state);
          end

          if runtime.PromptVelocityZeroCrossing
              [stop_for_zero_crossing, zero_crossing_flag] = PromptVelocityZeroCrossing( ...
                  results(1,end-1), results(1,end), direction_label, k, log_path);
          else
              stop_for_zero_crossing = false;
              zero_crossing_flag = '';
          end
          if stop_for_zero_crossing
              flag = zero_crossing_flag;
              AppendContinuationLog(log_path, sprintf('%s | iter %d | stop | %s', direction_label, k, flag));
              disp(flag)
              break;
          end
       else % Terminated because the current solution cannot converge due to the numerical issue based the ode options.
          failed_step_count = failed_step_count + 1;
          if numerical_radius > search_config.radius_floor * (1 + 1e-8) ...
                  && failed_step_count < search_config.failed_step_limit
              numerical_radius = max(search_config.radius_floor, 0.5 * predictor_radius);
              AppendContinuationLog(log_path, sprintf( ...
                  '%s | iter %d | failed correction | reason=%s | retryNumericalRadius=%.6g | failedCount=%d', ...
                  direction_label, k, failure_reason, numerical_radius, failed_step_count));
              RunContinuationCallback(runtime.Callbacks.onStatus, ContinuationCallbackState( ...
                  'retry', sprintf('%s | iter %d | reducing radius to %.4g after failed correction.', ...
                  direction_label, k, numerical_radius), results, lifted_results, Para, Radius, ...
                  direction_name, direction_idx, k, results(1:22,end), fval, output, struct( ...
                  'flag', failure_reason, ...
                  'solutionSolved', false, ...
                  'exitflag', exitflag, ...
                  'numericalRadius', numerical_radius, ...
                  'predictorRadius', predictor_radius, ...
                  'failedStepCount', failed_step_count, ...
                  'logFile', log_path)));
              if runtime.RadiusReductionPauseSeconds > 0
                  pause(runtime.RadiusReductionPauseSeconds);
              end
              disp('Reducing numerical radius after failed correction.'); disp(numerical_radius)
              if runtime.RadiusReductionPauseSeconds > 0
                  pause(runtime.RadiusReductionPauseSeconds);
              end
              continue;
          end
          flag = failure_reason;
          AppendContinuationLog(log_path, sprintf( ...
              '%s | iter %d | stop on failed correction | flag=%s | residual=%.6g | failedCount=%d', ...
              direction_label, k, flag, SafeResidualNorm(fval), failed_step_count));
          RunContinuationCallback(runtime.Callbacks.onStatus, ContinuationCallbackState( ...
              'stop', sprintf('%s | iter %d | %s', direction_label, k, flag), ...
              results, lifted_results, Para, Radius, direction_name, direction_idx, k, ...
              results(1:22,end), fval, output, struct( ...
              'flag', flag, ...
              'terminated', true, ...
              'terminationReason', flag, ...
              'solutionSolved', false, ...
              'exitflag', exitflag, ...
              'logFile', log_path)));
          disp(flag)
          if runtime.FailurePauseSeconds > 0
              pause(runtime.FailurePauseSeconds)
          end
          break;
       end
       
                  
       % There are additional criterias that will terminate the algorithm.
       if search_config.minimum_timing_boundary_margin > 0 ...
               && MinimumTimingGap(results(1:22,end)) <= search_config.minimum_timing_boundary_margin
            flag = sprintf('Algorithm stopped: event timing reached boundary margin %.6g.', ...
                search_config.minimum_timing_boundary_margin);
            AppendContinuationLog(log_path, sprintf( ...
                '%s | iter %d | stop | %s | minTimingGap=%.6g', ...
                direction_label, k, flag, MinimumTimingGap(results(1:22,end))));
            disp(flag)
            break;
       end
       if PersistentSharpTurnDetected( ...
               lifted_results, search_config.sharp_turn_threshold, search_config.sharp_turn_persistence)
            flag = 'Algorithm stopped: persistent irregular branch direction detected.';
            AppendContinuationLog(log_path, sprintf('%s | iter %d | stop | %s', direction_label, k, flag));
            disp(flag)
            break;
       end
       [revisit_found, revisit_info] = HistoricalSolutionRevisit( ...
           results(1:22,:), search_config);
       if revisit_found
            if revisit_info.match_index == 1
                revisit_count = search_config.revisit_persistence;
            elseif isfinite(previous_revisit_index) ...
                    && abs(revisit_info.match_index - previous_revisit_index) ...
                    <= search_config.revisit_match_index_jump
                revisit_count = revisit_count + 1;
            else
                revisit_count = 1;
            end
            previous_revisit_index = revisit_info.match_index;
            AppendContinuationLog(log_path, sprintf([ ...
                '%s | iter %d | historical revisit candidate | matchIndex=%d | ' ...
                'distance=%.6g | tangentAlignment=%.6g | currentFraction=%.6g | ' ...
                'historicalFraction=%.6g | persistence=%d/%d'], ...
                direction_label, k, revisit_info.match_index, revisit_info.distance, ...
                revisit_info.tangent_alignment, revisit_info.current_fraction, ...
                revisit_info.historical_fraction, revisit_count, ...
                search_config.revisit_persistence));
       else
            revisit_count = 0;
            previous_revisit_index = NaN;
       end
       if revisit_count >= search_config.revisit_persistence
            flag = 'Algorithm stopped: closed solution component detected.';
            AppendContinuationLog(log_path, sprintf([ ...
                '%s | iter %d | stop | %s | matchIndex=%d | ' ...
                'distance=%.6g | tangentAlignment=%.6g | currentFraction=%.6g | ' ...
                'historicalFraction=%.6g'], ...
                direction_label, k, flag, revisit_info.match_index, ...
                revisit_info.distance, revisit_info.tangent_alignment, ...
                revisit_info.current_fraction, revisit_info.historical_fraction));
            disp(flag)
            break;
       end
       if PersistentCoupletChangeDetected(results, search_config.bifurcation_persistence)
            flag = 'Algorithm stopped: persistent bifurcation signature detected.';
            AppendContinuationLog(log_path, sprintf('%s | iter %d | stop | %s', direction_label, k, flag));
            disp(flag)
            break;
       end
       if results(1,end)> 25
            flag = 'Algorithm stopped: Torso speed faster than 15.';
            AppendContinuationLog(log_path, sprintf('%s | iter %d | stop | %s', direction_label, k, flag));
            disp('Algorithm stopped: Torso speed faster than 15.')
            break;
       end
       if results(2,end)< 0.3*Para(4)
            flag = 'Algorithm stopped: Torso height smaller than 30% of leg length.';
            AppendContinuationLog(log_path, sprintf('%s | iter %d | stop | %s', direction_label, k, flag));
            disp('Algorithm stopped: Torso height smaller than 30% of leg length.')
            break;
       end

       if norm((lifted_results(:,end)-lifted_results(:,end-1)) ./ state_scale) < search_config.stagnation_tol
            stagnation_count = stagnation_count + 1;
            if stagnation_count >= search_config.stagnation_limit
                flag = 'Algorithm stopped: stagnation detected in the lifted chart.';
                AppendContinuationLog(log_path, sprintf('%s | iter %d | stop | %s', direction_label, k, flag));
                disp(flag)
                break;
            end
       else
            stagnation_count = 0;
       end

end

SaveTemporarySolution(runtime, results, lifted_results, flag);
end

%% Configuration Helpers
function runtime = ContinuationRuntimeSettings(runOptions)
    runtime = struct();
    runtime.ResetFigureOnStart = true;
    runtime.ClearCommandWindow = true;
    runtime.SaveTempSol = 1;
    runtime.TemporarySolutionFile = 'solution_tempo.mat';
    runtime.DeleteTempSolOnFinish = false;
    runtime.RequireTemporarySave = false;
    runtime.IlluSols = 1;
    runtime.DisplayCommandStatus = true;
    runtime.DirectionPauseSeconds = 5;
    runtime.FailurePauseSeconds = 3;
    runtime.RadiusReductionPauseSeconds = 0.2;
    runtime.PromptVelocityZeroCrossing = true;
    runtime.PreserveSeedOrder = false;
    runtime.DirectionCount = 2;
    runtime.BranchTitle = '1D Continuation';
    runtime.MaxIterationsPerDirection = [];
    runtime.MinimumTimingBoundaryMargin = [];
    runtime.Callbacks = DefaultContinuationCallbacks();

    if nargin < 1 || isempty(runOptions)
        return;
    end

    runtime = ApplyRuntimeOptions(runtime, runOptions);
    if ~(isscalar(runtime.PreserveSeedOrder) && ...
            (islogical(runtime.PreserveSeedOrder) || isnumeric(runtime.PreserveSeedOrder)) && ...
            isreal(runtime.PreserveSeedOrder) && any(runtime.PreserveSeedOrder == [0 1]))
        error('NumericalContinuation1D:InvalidPreserveSeedOrder', ...
            'PreserveSeedOrder must be logical true or false.');
    end
    if ~(isnumeric(runtime.DirectionCount) && isreal(runtime.DirectionCount) && ...
            isscalar(runtime.DirectionCount) && any(runtime.DirectionCount == [1 2]))
        error('NumericalContinuation1D:InvalidDirectionCount', ...
            'DirectionCount must be 1 or 2.');
    end
    runtime.PreserveSeedOrder = logical(runtime.PreserveSeedOrder);
    runtime.Callbacks = NormalizeContinuationCallbacks(runtime.Callbacks);
end

function InitializeTemporarySolution(runtime, results, lifted_results)
    if ~runtime.SaveTempSol
        return;
    end

    SaveTemporarySolution(runtime, results, lifted_results, 'Initialized');
end

function SaveTemporarySolution(runtime, results, lifted_results, flag)
    if ~runtime.SaveTempSol
        return;
    end

    temporary_file = TemporarySolutionPath(runtime);

    temporary_data = struct();
    temporary_data.results = results;
    temporary_data.lifted_results = lifted_results;
    temporary_data.flag = char(string(flag));
    temporary_data.saved_at = datetime('now');
    try
        save(temporary_file, '-struct', 'temporary_data');
    catch ME
        if runtime.RequireTemporarySave
            rethrow(ME);
        end
        warning('NumericalContinuation1D_Quadruped_v2:TemporarySaveFailed', ...
            'Unable to save temporary continuation file "%s": %s', temporary_file, ME.message);
    end
end

function temporary_file = TemporarySolutionPath(runtime)
    temporary_file = char(string(runtime.TemporarySolutionFile));
    if isempty(strtrim(temporary_file))
        temporary_file = 'solution_tempo.mat';
    end
end

function criteria_driven = StoppedByAutomaticCriteria(flags)
    reasons = lower(strtrim(string(flags)));
    has_reason = strlength(reasons) > 0;
    manually_stopped = contains(reasons, 'stopped by user') ...
        | contains(reasons, 'user stopped') ...
        | contains(reasons, 'user stop');
    abnormal_stop = contains(reasons, 'solver exception') ...
        | contains(reasons, 'numerical issues');
    criteria_driven = all(has_reason) && ~any(manually_stopped | abnormal_stop);
end

function deleted = DeleteTemporarySolution(temporary_file)
    deleted = false;
    if isempty(strtrim(temporary_file)) || ~isfile(temporary_file)
        return;
    end

    try
        delete(temporary_file);
        deleted = ~isfile(temporary_file);
    catch ME
        warning('NumericalContinuation1D_Quadruped_v2:TemporaryDeleteFailed', ...
            'Unable to delete temporary continuation file "%s": %s', temporary_file, ME.message);
    end
end

function callbacks = DefaultContinuationCallbacks()
    callbacks = struct();
    callbacks.onAcceptedPoint = [];
    callbacks.onStatus = [];
    callbacks.onFinish = [];
    callbacks.onControl = [];
end

function runtime = ApplyRuntimeOptions(runtime, runOptions)
    optionFields = fieldnames(runOptions);
    for i = 1:numel(optionFields)
        fieldName = optionFields{i};
        runtime.(fieldName) = runOptions.(fieldName);
    end
end

function callbacks = NormalizeContinuationCallbacks(callbacks)
    defaults = DefaultContinuationCallbacks();
    if isempty(callbacks) || ~isstruct(callbacks)
        callbacks = defaults;
        return;
    end

    defaultFields = fieldnames(defaults);
    for i = 1:numel(defaultFields)
        fieldName = defaultFields{i};
        if ~isfield(callbacks, fieldName)
            callbacks.(fieldName) = defaults.(fieldName);
        end
    end
end

function RunContinuationCallback(callbackFcn, state)
    if isempty(callbackFcn)
        return;
    end

    try
        callbackFcn(state);
    catch ME
        callback_phase = 'unknown';
        if isstruct(state) && isfield(state, 'phase') && ~isempty(state.phase)
            callback_phase = char(string(state.phase));
        end
        callback_location = '';
        if ~isempty(ME.stack)
            callback_location = sprintf(' in %s (line %d)', ME.stack(1).name, ME.stack(1).line);
        end
        warning('NumericalContinuation1D_Quadruped_v2:CallbackError', ...
            'Continuation callback failed during %s%s: %s', ...
            callback_phase, callback_location, ME.message);
    end
end

function stop_requested = WaitForContinuationControl(control_callback)
    stop_requested = false;
    if isempty(control_callback)
        return;
    end

    while true
        drawnow;
        control = ReadContinuationControl(control_callback);
        if control.stopRequested
            stop_requested = true;
            return;
        end
        if ~control.pauseRequested
            return;
        end
        pause(0.05);
    end
end

function control = ReadContinuationControl(control_callback)
    control = struct('pauseRequested', false, 'stopRequested', false);
    try
        callback_value = control_callback();
        if isstruct(callback_value)
            if isfield(callback_value, 'pauseRequested') && ~isempty(callback_value.pauseRequested)
                control.pauseRequested = logical(callback_value.pauseRequested(1));
            end
            if isfield(callback_value, 'stopRequested') && ~isempty(callback_value.stopRequested)
                control.stopRequested = logical(callback_value.stopRequested(1));
            end
        elseif islogical(callback_value) && isscalar(callback_value)
            control.stopRequested = callback_value;
        end
    catch ME
        warning('NumericalContinuation1D_Quadruped_v2:ControlCallbackError', ...
            'Continuation control callback failed: %s', ME.message);
    end
end

function ReportUserContinuationStop(runtime, log_path, results, lifted_results, Para, Radius, ...
        direction_name, direction_idx, iteration, fval, output)
    stop_message = sprintf('%s | iter %d | Algorithm stopped by user.', ...
        char(direction_name), iteration);
    AppendContinuationLog(log_path, stop_message);
    RunContinuationCallback(runtime.Callbacks.onStatus, ContinuationCallbackState( ...
        'stop', stop_message, results, lifted_results, Para, Radius, ...
        direction_name, direction_idx, iteration, results(1:22,end), fval, output, struct( ...
        'flag', 'Algorithm stopped by user.', ...
        'terminated', true, ...
        'terminationReason', 'Algorithm stopped by user.', ...
        'solutionSolved', false, ...
        'logFile', log_path)));
end

function state = ContinuationCallbackState(phase, message, results, lifted_results, Para, Radius, direction_name, direction_idx, iteration, X, fval, output, extra)
    if nargin < 13 || isempty(extra)
        extra = struct();
    end
    if nargin < 12
        output = [];
    end
    if nargin < 11
        fval = [];
    end
    if nargin < 10
        X = [];
    end
    if nargin < 9
        iteration = [];
    end
    if nargin < 8
        direction_idx = [];
    end
    if nargin < 7 || isempty(direction_name)
        direction_name = '';
    end

    state = struct();
    state.phase = char(string(phase));
    state.message = char(string(message));
    state.results = results;
    state.lifted_results = lifted_results;
    state.results_lifted = [lifted_results; repmat(Para(:), 1, size(lifted_results, 2))];
    state.Para = Para(:);
    state.Radius = Radius;
    state.directionName = char(string(direction_name));
    state.directionIndex = direction_idx;
    state.iteration = iteration;
    state.pointIndex = size(results, 2);
    state.X = X;
    state.residualNorm = SafeResidualNorm(fval);
    state.output = output;
    state.solutionSolved = false;
    state.solverIterations = SafeIterationCount(output);
    state.solverFunctionCount = SafeFunctionCount(output);
    state.exitflag = NaN;
    state.currentDx = NaN;
    state.period = NaN;
    state.gait = '';
    state.gaitAbbr = '';
    state.distanceFromPreviousState = NaN;
    state.terminated = false;
    state.terminationReason = '';
    state.logFile = '';

    if ~isempty(X)
        X_column = X(:);
        if numel(X_column) >= 1
            state.currentDx = X_column(1);
        end
        if numel(X_column) >= 22
            state.period = X_column(22);
            [state.gait, state.gaitAbbr] = SafeGaitIdentification(X_column);
        end
    end

    extraFields = fieldnames(extra);
    for i = 1:numel(extraFields)
        fieldName = extraFields{i};
        state.(fieldName) = extra.(fieldName);
    end
end

function status_message = FormatAcceptedPointStatus(state)
    status_message = sprintf([ ...
        '%s | new solution solved | continuation iter %d | point %d | ' ...
        'solver iter %.6g | dx %.6g | gait %s | state distance %.6g | residual %.3e'], ...
        state.directionName, state.iteration, state.pointIndex, state.solverIterations, ...
        state.currentDx, state.gaitAbbr, state.distanceFromPreviousState, state.residualNorm);
end

function log_message = FormatAcceptedPointLog(state)
    log_message = sprintf([ ...
        '%s | iter %d | accepted | solved=1 | point=%d | solverIterations=%.6g | funcCount=%.6g | ' ...
        'exitflag=%.6g | correctorBacktrack=%d | dx=%.6g | gait=%s | gaitName=%s | ' ...
        'stateDistance=%.6g | T=%.6g | residual=%.6g | scaledStep=%.6g | ' ...
        'nextNumericalRadius=%.6g | nextDirectionRadius=%.6g | nextPredictorRadius=%.6g | ' ...
        'nextTheta=%.6g | minTimingGap=%.6g | cols=%d'], ...
        state.directionName, state.iteration, state.pointIndex, state.solverIterations, ...
        state.solverFunctionCount, state.exitflag, state.correctorAttempt, state.currentDx, ...
        state.gaitAbbr, state.gait, state.distanceFromPreviousState, state.period, ...
        state.residualNorm, state.scaledStep, state.numericalRadius, state.directionRadius, ...
        state.predictorRadius, state.thetaTurn, state.minimumTimingGap, state.pointIndex);
end

function search_config = SearchSetting(Radius, runtime)
    search_config = struct();
    search_config.radius_floor = max(1e-4, 0.1 * Radius);
    search_config.radius_ceiling = max(2 * Radius, Radius);
    search_config.stagnation_tol = 0.05 * search_config.radius_floor;
    search_config.stagnation_limit = 8;
    search_config.numerical_target_iterations = 25;
    search_config.failed_step_limit = 12;
    search_config.sharp_turn_threshold = (3/4) * pi;
    search_config.sharp_turn_persistence = 2;
    search_config.bifurcation_persistence = 2;
    search_config.max_iterations = 100000;
    search_config.minimum_timing_boundary_margin = 0;
    search_config.backtrack_attempts = 5;
    search_config.revisit_tolerance = search_config.radius_floor;
    search_config.revisit_guard_arclength = max(10 * Radius, ...
        5 * search_config.radius_ceiling);
    search_config.revisit_tangent_alignment = cos(pi / 9); % 20 degrees
    search_config.revisit_persistence = 2;
    search_config.revisit_match_index_jump = 10;

    if ~isempty(runtime.MaxIterationsPerDirection) ...
            && isnumeric(runtime.MaxIterationsPerDirection) ...
            && isscalar(runtime.MaxIterationsPerDirection) ...
            && isfinite(runtime.MaxIterationsPerDirection) ...
            && runtime.MaxIterationsPerDirection >= 1
        search_config.max_iterations = floor(runtime.MaxIterationsPerDirection);
    end
    if ~isempty(runtime.MinimumTimingBoundaryMargin) ...
            && isnumeric(runtime.MinimumTimingBoundaryMargin) ...
            && isscalar(runtime.MinimumTimingBoundaryMargin) ...
            && isfinite(runtime.MinimumTimingBoundaryMargin) ...
            && runtime.MinimumTimingBoundaryMargin > 0
        search_config.minimum_timing_boundary_margin = runtime.MinimumTimingBoundaryMargin;
    end
end

function numOPTS = DefaultContinuationOptions()
    numOPTS = optimset('Algorithm','levenberg-marquardt', ...
               'Display','iter', ...
               'MaxFunEvals',50000, ...
               'MaxIter',3000, ...
               'UseParallel', false, ...
               'TolFun',1e-12, ...
               'TolX',1e-12);
end

function BranchPlot = InitializeBranchPlot(results, runtime)
    if runtime.IlluSols
        BranchPlot = BranchPlotSearching(results);
    else
        BranchPlot = [];
    end
end

function info = BuildContinuationInfo(lifted_results, Para, log_path, direction_labels, Radius, numOPTS)
    info = struct();
    info.results_lifted = [lifted_results; repmat(Para, 1, size(lifted_results,2))];
    info.log_file = log_path;
    info.direction_labels = direction_labels;
    info.radius = Radius;
    [info.numOPTS, omittedFields] = SolverOptionsForPersistence(numOPTS);
    info.transient_solver_option_fields_omitted = omittedFields;
    info.state_scale = LatestStateScale(lifted_results);
    info.scale = info.state_scale;
end

function [savedOptions, omittedFields] = SolverOptionsForPersistence(numOPTS)
    savedOptions = numOPTS;
    omittedFields = cell(0, 1);
    if ~isstruct(savedOptions)
        return;
    end

    optionFields = fieldnames(savedOptions);
    for i = 1:numel(optionFields)
        fieldName = optionFields{i};
        if ContainsFunctionHandle(savedOptions.(fieldName))
            savedOptions.(fieldName) = [];
            omittedFields{end + 1, 1} = fieldName; %#ok<AGROW>
        end
    end
end

function tf = ContainsFunctionHandle(value)
    if isa(value, 'function_handle')
        tf = true;
        return;
    end
    if iscell(value)
        tf = any(cellfun(@ContainsFunctionHandle, value));
        return;
    end
    tf = false;
end

function state_scale = LatestStateScale(lifted_results)
    if size(lifted_results,2) > 1
        state_scale = LocalScaleVector(lifted_results(:,end), lifted_results(:,end-1));
    else
        state_scale = LocalScaleVector(lifted_results(:,1), lifted_results(:,1));
    end
end

function [xFINAL,fval,exitflag,output,solver_error] = SafeCorrectorSolve( ...
        X0,Para,X_anchor,state_scale,tangent_state_scaled,numOPTS,control_callback)
    solver_error = '';

    if nargin < 7
        control_callback = [];
    end

    try
        [xFINAL,fval,exitflag,output] = ContinuationFun_Quadruped_v2( ...
            X0,Para,X_anchor,state_scale,tangent_state_scaled,numOPTS,control_callback);
    catch solver_exception
        xFINAL = X0;
        fval = NaN;
        exitflag = -Inf;
        output = struct();

        if isempty(solver_exception.identifier)
            solver_error = solver_exception.message;
        else
            solver_error = sprintf('%s: %s', solver_exception.identifier, solver_exception.message);
        end
        solver_error = strrep(solver_error, sprintf('\n'), ' | ');
    end
end

%% Continuation Function that is used to set the 1-D continuation
function [xFINAL,fval,exitflag,output] = ContinuationFun_Quadruped_v2( ...
        X0,Para,X_anchor,state_scale,tangent_state_scaled,numOPTS,control_callback)
% Find solution X zero in residual values
solver_options = numOPTS;
existing_output_fcn = [];
if nargin >= 7 && ~isempty(control_callback)
    existing_output_fcn = optimget(numOPTS, 'OutputFcn', []);
    solver_options = optimset(numOPTS, 'OutputFcn', @ControlledSolverOutput);
end
[xFINAL,fval,exitflag,output] = fsolve(@Residual, X0, solver_options);


function residual = Residual(X)
    
    % Build new residual values zero in fsolve
    [residual,T,Y,P] = Quadrupedal_ZeroFun_v2(X,Para,'skipSolve');
    % Constrain the corrector to the predictor hyperplane.
    diff_scaled = StateDifferenceToReferenceChart(X(1:22), X_anchor(1:22)) ./ state_scale;
    residual(end+1) = dot(diff_scaled, tangent_state_scaled);
end

function stop = ControlledSolverOutput(X, optim_values, solver_state)
    stop = RunExistingSolverOutput(existing_output_fcn, X, optim_values, solver_state);
    if ~stop
        stop = WaitForContinuationControl(control_callback);
    end
end

end

function stop = RunExistingSolverOutput(output_fcn, X, optim_values, solver_state)
    stop = false;
    if isempty(output_fcn)
        return;
    end

    try
        if isa(output_fcn, 'function_handle')
            callback_stop = output_fcn(X, optim_values, solver_state);
            if ~isempty(callback_stop)
                stop = any(logical(callback_stop(:)));
            end
        elseif iscell(output_fcn)
            for i = 1:numel(output_fcn)
                if isa(output_fcn{i}, 'function_handle')
                    callback_stop = output_fcn{i}(X, optim_values, solver_state);
                    if ~isempty(callback_stop)
                        stop = stop || any(logical(callback_stop(:)));
                    end
                end
            end
        end
    catch ME
        warning('NumericalContinuation1D_Quadruped_v2:OutputCallbackError', ...
            'Existing fsolve output callback failed: %s', ME.message);
    end
end

%% Scaling and Radius Helpers
function [direction_radius, theta_turn] = DirectionRadiusScaling(lifted_results, radius_floor, radius_ceiling)
    if size(lifted_results,2) < 3
        direction_radius = radius_ceiling;
        theta_turn = 0;
        return;
    end

    theta_turn = ThetaDiffLifted(lifted_results);
    theta_flat = pi / 36;
    theta_sharp = pi / 3;

    if theta_turn <= theta_flat
        direction_radius = radius_ceiling;
        return;
    end

    if theta_turn >= theta_sharp
        direction_radius = radius_floor;
        return;
    end

    turn_ratio = (theta_turn - theta_flat) / (theta_sharp - theta_flat);
    direction_radius = radius_ceiling - (radius_ceiling - radius_floor) * turn_ratio;
end

function numerical_radius = NumericalRadiusScaling(predictor_radius, iter_count, numerical_target_iterations, radius_floor, radius_ceiling)
    if ~(isfinite(iter_count) && iter_count > 0)
        numerical_radius = min(radius_ceiling, max(radius_floor, predictor_radius));
        return;
    end

    ratio = numerical_target_iterations / iter_count;
    if ratio >= 1
        growth_factor = ratio^(1/4);
        numerical_radius = predictor_radius * growth_factor;
    else
        shrink_factor = sqrt(ratio);
        numerical_radius = predictor_radius * shrink_factor;
    end

    numerical_radius = min(radius_ceiling, max(radius_floor, numerical_radius));
end

function scale = LocalScaleVector(X1, X2)
    Tpair = [X1(22), X2(22)];
    Tpair = Tpair(isfinite(Tpair) & Tpair > 0);

    if isempty(Tpair)
        Tref = 1;
    else
        Tref = mean(Tpair);
    end

    timing_scale = max(0.05, 0.25 * Tref);
    T_scale = max(0.1, 0.50 * Tref);

    scale = [10; 1; 1; 0.5; 0.5; ...
             0.3; 0.3; 0.3; 0.3; ...
             0.3; 0.3; 0.3; 0.3; ...
             timing_scale * ones(8,1); ...
             T_scale];
end

function nIter = SafeIterationCount(output)
    nIter = NaN;

    if isstruct(output) && isfield(output, 'iterations')
        nIter = output.iterations;
    end
end

function nEval = SafeFunctionCount(output)
    nEval = NaN;

    if isstruct(output) && isfield(output, 'funcCount')
        nEval = output.funcCount;
    end
end

function [gait_name, gait_abbr] = SafeGaitIdentification(X)
    gait_name = 'Unknown';
    gait_abbr = 'Unknown';

    try
        [gait_value, abbr_value, ~, ~] = Gait_Identification(X);
        gait_name = char(string(gait_value));
        gait_abbr = char(string(abbr_value));
    catch
        % Status reporting must never interrupt continuation.
    end
end

%% Continuation State and Geometry Helpers
function seq_lifted = ReliftSequence(seq_wrapped)
    seq_lifted = zeros(size(seq_wrapped));
    seq_lifted(:,1) = EventTimingRegulation(seq_wrapped(:,1));

    for i = 2:size(seq_wrapped, 2)
        X_here = EventTimingRegulation(seq_wrapped(:,i));
        seq_lifted(:,i) = LiftTimingStateToReference(X_here, seq_lifted(:,i-1));
    end
end

function X_lift = LiftTimingStateToReference(X_in, X_ref)
%LIFTTIMINGSTATETOREFERENCE Pick the nearest timing representative to X_ref.
%
%   X_lift = LiftTimingStateToReference(X_in, X_ref) keeps the continuous
%   states and stride time from X_in, and shifts each event timing by an
%   integer multiple of the stride so it lies closest to the corresponding
%   event timing in X_ref.

    X_in  = X_in(:);
    X_ref = X_ref(:);

    if numel(X_in) ~= 22 || numel(X_ref) ~= 22
        error('LiftTimingStateToReference:InvalidInput', ...
            'Both inputs must be 22-element transition vectors.');
    end

    X_lift = X_in;

    Tref = X_in(22);
    if ~(isfinite(Tref) && Tref > 0)
        Tref = X_ref(22);
    end

    if ~(isfinite(Tref) && Tref > 0)
        return;
    end

    dt = WrappedTimeDifference(X_in(14:21), X_ref(14:21), Tref);
    X_lift(14:21) = X_ref(14:21) + dt;
end

function dX = StateDifferenceToReferenceChart(X_in, X_ref)
%STATEDIFFERENCETOREFERENCECHART Local state difference with wrapped timings.
%
%   dX = StateDifferenceToReferenceChart(X_in, X_ref) returns a local
%   coordinate difference that treats event timings as circular variables on
%   the stride period while keeping the remaining states linear.

    X_in  = X_in(:);
    X_ref = X_ref(:);

    if numel(X_in) ~= 22 || numel(X_ref) ~= 22
        error('StateDifferenceToReferenceChart:InvalidInput', ...
            'Both inputs must be 22-element transition vectors.');
    end

    dX = X_in - X_ref;

    Tref = X_ref(22);
    if ~(isfinite(Tref) && Tref > 0)
        Tref = X_in(22);
    end

    if isfinite(Tref) && Tref > 0
        dX(14:21) = WrappedTimeDifference(X_in(14:21), X_ref(14:21), Tref);
    end
end

function thetadiff = ThetaDiff2(results)
    if size(results,2) < 3
        thetadiff = 0;
        return;
    end

    lifted_local = ReliftSequence(results(1:22,end-2:end));
    thetadiff = ThetaScaled(lifted_local(:,1), lifted_local(:,2), lifted_local(:,3));
end

function thetadiff = ThetaDiffLifted(lifted_results)
    if size(lifted_results,2) < 3
        thetadiff = 0;
        return;
    end

    thetadiff = ThetaScaled(lifted_results(:,end-2), lifted_results(:,end-1), lifted_results(:,end));
end

function theta = ThetaScaled(X1, X2, X3)
    scale = LocalScaleVector(X3, X2);
    d1 = (X3 - X2) ./ scale;
    d2 = (X2 - X1) ./ scale;

    n1 = norm(d1);
    n2 = norm(d2);
    if n1 < 1e-12 || n2 < 1e-12
        theta = 0;
        return;
    end

    cos_theta = dot(d1, d2) / (n1 * n2);
    cos_theta = max(-1, min(1, cos_theta));
    theta = acos(cos_theta);
end

function dt = WrappedTimeDifference(t1, t2, T)
%WRAPPEDTIMEDIFFERENCE Centered circular timing difference on [0, T).
%
%   dt = WrappedTimeDifference(t1, t2, T) returns the shortest signed
%   difference between two timing values on a stride of duration T. When T
%   is invalid, the function falls back to the linear difference.

    if ~(isscalar(T) && isfinite(T) && T > 0)
        dt = t1 - t2;
        return;
    end

    dt = mod((t1 - t2) + 0.5*T, T) - 0.5*T;
end

function gap = MinimumTimingGap(X)
    T = X(22);
    timings = X(14:21);

    if ~(isfinite(T) && T > 0)
        gap = min(abs(timings));
        return;
    end

    gap = min(min(abs(timings)), min(abs(timings - T)));
end

%% Acceptance and Branch-Criteria Helpers
function ok = PersistentSharpTurnDetected(lifted_results, theta_threshold, persistence_count)
    if size(lifted_results,2) < persistence_count + 2
        ok = false;
        return;
    end

    ok = true;
    for offset = 0:(persistence_count-1)
        idx = size(lifted_results,2) - 2 - offset;
        theta_local = ThetaScaled( ...
            lifted_results(:,idx), ...
            lifted_results(:,idx+1), ...
            lifted_results(:,idx+2));
        if theta_local <= theta_threshold
            ok = false;
            return;
        end
    end
end

function ok = PersistentCoupletChangeDetected(results, persistence_count)
    if size(results,2) < persistence_count + 1
        ok = false;
        return;
    end

    recent_idx = (size(results,2) - persistence_count):size(results,2);
    couplet_history = zeros(1, numel(recent_idx));
    for k = 1:numel(recent_idx)
        couplet_history(k) = Couplet(results(1:22, recent_idx(k)));
    end

    prior_value = couplet_history(1);
    recent_values = couplet_history(2:end);
    ok = all(recent_values == recent_values(1)) && recent_values(1) ~= prior_value;
end

function ok = SolutionAccepted(fval, X)
    if X(1) < 15
        ok = norm(fval) < 1e-9;
    else
        ok = norm(fval) < 1e-6;
    end
end

function ok = CandidateIsNew(X_candidate, lifted_results, state_scale, predictor_radius)
    step_last = norm((X_candidate - lifted_results(:,end)) ./ state_scale);
    novelty_tol = max(1e-8, 1e-3 * predictor_radius);
    ok = step_last > novelty_tol;
end

function closed = ClosedSolutionComponentDetected(flag)
    reason = lower(strtrim(char(string(flag))));
    closed = contains(reason, 'closed solution component') ...
        || contains(reason, 'solution circle found');
end

function [found, info] = HistoricalSolutionRevisit(states, search_config)
%HISTORICALSOLUTIONREVISIT Detect a return to an older branch segment.
% Event timings are compared modulo the stride period. Recent points are
% excluded by accumulated scaled arc length so ordinary neighboring points
% cannot be mistaken for a closed branch. The newest continuation segment is
% compared with historical segments, rather than only with stored endpoints,
% so a loop closure between two adaptive samples is not missed. Tangent
% agreement distinguishes a smooth recurrence from a transverse crossing.

    info = struct( ...
        'match_index', NaN, ...
        'distance', Inf, ...
        'tangent_alignment', NaN, ...
        'current_fraction', NaN, ...
        'historical_fraction', NaN);
    found = false;

    point_count = size(states, 2);
    if size(states, 1) ~= 22 || point_count < 4
        return;
    end

    guard_arclength = 0;
    eligible_last = 0;
    for idx = (point_count - 1):-1:1
        guard_arclength = guard_arclength + ScaledChartDistance( ...
            states(:,idx + 1), states(:,idx));
        if guard_arclength >= search_config.revisit_guard_arclength
            eligible_last = idx;
            break;
        end
    end
    if eligible_last < 1
        return;
    end

    for idx = 1:eligible_last
        [distance, tangent_alignment, current_fraction, historical_fraction] = ...
            HistoricalSegmentComparison(states, idx);
        if distance > search_config.revisit_tolerance
            continue;
        end
        if tangent_alignment < search_config.revisit_tangent_alignment
            continue;
        end

        if distance < info.distance
            info.match_index = idx;
            info.distance = distance;
            info.tangent_alignment = tangent_alignment;
            info.current_fraction = current_fraction;
            info.historical_fraction = historical_fraction;
            found = true;
        end
    end
end

function [distance, alignment, current_fraction, historical_fraction] = ...
        HistoricalSegmentComparison(states, historical_index)
    historical_reference = states(:,historical_index);
    scale = LocalScaleVector(states(:,end), historical_reference);

    current_end = StateDifferenceToReferenceChart( ...
        states(:,end), historical_reference) ./ scale;
    current_step = StateDifferenceToReferenceChart( ...
        states(:,end), states(:,end - 1)) ./ scale;
    current_start = current_end - current_step;

    historical_start = zeros(22,1);
    historical_step = StateDifferenceToReferenceChart( ...
        states(:,historical_index + 1), historical_reference) ./ scale;
    historical_end = historical_step;

    [distance, current_fraction, historical_fraction] = ...
        ClosestSegmentDistance(current_start, current_end, ...
        historical_start, historical_end);

    current_norm = norm(current_step);
    historical_norm = norm(historical_step);
    if current_norm <= 1e-12 || historical_norm <= 1e-12 ...
            || ~isfinite(current_norm) || ~isfinite(historical_norm)
        alignment = -Inf;
        return;
    end
    alignment = abs(dot(current_step, historical_step) ...
        / (current_norm * historical_norm));
    alignment = min(1, max(0, alignment));
end

function [distance, s_best, t_best] = ClosestSegmentDistance(P0, P1, Q0, Q1)
%CLOSESTSEGMENTDISTANCE Minimum distance between two segments in N-D.
    u = P1 - P0;
    v = Q1 - Q0;
    w = P0 - Q0;

    a = dot(u,u);
    b = dot(u,v);
    c = dot(v,v);
    d = dot(u,w);
    e = dot(v,w);
    determinant = a*c - b*b;

    candidates = zeros(2,0);
    determinant_tolerance = 1e-12 * max(1, a*c);
    if determinant > determinant_tolerance
        s = (b*e - c*d) / determinant;
        t = (a*e - b*d) / determinant;
        if s >= 0 && s <= 1 && t >= 0 && t <= 1
            candidates(:,end + 1) = [s;t]; %#ok<AGROW>
        end
    end

    for s = [0,1]
        if c > 1e-14
            t = dot(v, P0 + s*u - Q0) / c;
        else
            t = 0;
        end
        candidates(:,end + 1) = [s; min(1, max(0, t))]; %#ok<AGROW>
    end
    for t = [0,1]
        if a > 1e-14
            s = dot(u, Q0 + t*v - P0) / a;
        else
            s = 0;
        end
        candidates(:,end + 1) = [min(1, max(0, s)); t]; %#ok<AGROW>
    end

    distance = Inf;
    s_best = NaN;
    t_best = NaN;
    for idx = 1:size(candidates,2)
        s = candidates(1,idx);
        t = candidates(2,idx);
        candidate_distance = norm(w + s*u - t*v);
        if candidate_distance < distance
            distance = candidate_distance;
            s_best = s;
            t_best = t;
        end
    end
end

function distance = ScaledChartDistance(X1, X2)
    difference = StateDifferenceToReferenceChart(X1, X2);
    scale = LocalScaleVector(X1, X2);
    distance = norm(difference ./ scale);
end

function noc = Couplet(X)
    noc = 0;
    if abs(WrappedTimeDifference(X(14), X(18), X(22)))<0.01*X(22) ...
            && abs(WrappedTimeDifference(X(15), X(19), X(22)))<0.01*X(22)
         noc = noc + 1;
    end
    if abs(WrappedTimeDifference(X(16), X(20), X(22)))<0.01*X(22) ...
            && abs(WrappedTimeDifference(X(17), X(21), X(22)))<0.01*X(22)
         noc = noc + 1;
    end
    if abs(WrappedTimeDifference(X(14), X(16), X(22)))<0.01*X(22) ...
            && abs(WrappedTimeDifference(X(14), X(17), X(22)))<0.01*X(22)
         noc = noc + 1;
    end
end

%% Logging, Diagnostics, and Reporting Helpers
function log_path = CreateContinuationLogPath()
    ms = floor(mod(now * 24 * 60 * 60 * 1000, 1000));
    log_name = sprintf('continuation_debug_%s_%03d.log', datestr(now, 30), ms);
    log_path = fullfile(pwd, log_name);
    AppendContinuationLog(log_path, 'Continuation debug log created.');
end

function AppendContinuationLog(log_path, message)
    fid = fopen(log_path, 'a');
    if fid < 0
        return;
    end

    ms = floor(mod(now * 24 * 60 * 60 * 1000, 1000));
    timestamp = sprintf('%s.%03d', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ms);
    fprintf(fid, '[%s] %s\n', timestamp, message);
    fclose(fid);
end

function rnorm = SafeResidualNorm(fval)
    if isempty(fval) || any(~isfinite(fval))
        rnorm = NaN;
    else
        rnorm = norm(fval);
    end
end

function DisplayContinuationStatus(state)
    solution_status = struct( ...
        'Solved', state.solutionSolved, ...
        'ContinuationIteration', state.iteration, ...
        'SolverIterations', state.solverIterations, ...
        'CurrentDx', state.currentDx, ...
        'Residual', state.residualNorm, ...
        'StateDistance', state.distanceFromPreviousState, ...
        'CoupletLegPairs', Couplet(state.X), ...
        'Gait', string(state.gaitAbbr));
    radius_status = struct( ...
        'PredictorRadius', state.predictorRadius, ...
        'NumericalRadius', state.numericalRadius, ...
        'DirectionRadius', state.directionRadius, ...
        'DirectionAngle', state.thetaTurn, ...
        'ScaledContinuationStep', state.scaledStep);

    disp('')
    disp('')
    disp(struct2table(solution_status));
    disp(struct2table(radius_status));
    pause(0.5)
end

%% Plotting Helpers
function BranchPlot = BranchPlotSearching(results)
    % Plot position settings
    ScreenSize = get(0,'ScreenSize');
    PlotSize = [(2.5/10)*ScreenSize(3)   (12/16)*(2.5/10)*ScreenSize(3)
             ScreenSize(3)/5        (12/16)*ScreenSize(3)/5     ];
    PlotPositions = [(1/2)*ScreenSize(3)-(2/2 + 1/10)*PlotSize(1,1)  (0.5/10)*ScreenSize(4)+PlotSize(2,2)  PlotSize(1,1)  PlotSize(1,2)
                  (1/2)*ScreenSize(3)-(0/2 - 1/10)*PlotSize(1,1)  (0.5/10)*ScreenSize(4)+PlotSize(2,2)  PlotSize(1,1)  PlotSize(1,2)];

    % Simulate the system and initialize the branch view.
    [~,~,Y] = Quadrupedal_ZeroFun_v2(results(1:22,end),results(23:end,end),'skipSolve');
    [~,~, color_plot, ~] = Gait_Identification(results(1:22,end));

    figExists = ~isempty(findobj('Type', 'figure', 'Number', 305));
    if ~figExists
        fig = figure(305);
    else
        fig = figure();
    end
    BranchPlot = SLIP_PeriodicOrbit_Quad(Y,PlotPositions(2,:),fig,color_plot);
    ConfigureBranchPlotForContinuation(BranchPlot, results);
    InitializeRealSolutionMarkers(BranchPlot, results);
end

function [predict_solution, predict_text] = UpdatePredictorOverlay(BranchPlot, results, X_state, predict_solution, predict_text)
    UpdateBranchPlotAxes(BranchPlot, results, X_state);
    view(BranchPlot.axes, [0 0]);

    if isempty(predict_solution) || ~isgraphics(predict_solution)
        predict_solution = scatter3( ...
            X_state(1),X_state(3),X_state(5),120,'Parent',BranchPlot.axes, ...
            'MarkerEdgeColor',[0 0 0], ...
            'MarkerFaceColor','none', ...
            'LineWidth',1.25);
        predict_solution.Tag = 'PredictedSolutionMarker';
    end

    if isempty(predict_text) || ~isgraphics(predict_text)
        label_position = PredictorTextPosition(X_state, BranchPlot.axes);
        predict_text = text( ...
            label_position(1), label_position(2), label_position(3), ...
            'Predicted Solution', ...
            'Parent', BranchPlot.axes, ...
            'Color', [0 0 0], ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', ...
            'Clipping', 'off');
        predict_text.Tag = 'PredictedSolutionText';
    end

    predict_solution.XData = X_state(1);
    predict_solution.YData = X_state(3);
    predict_solution.ZData = X_state(5);
    predict_text.Position = PredictorTextPosition(X_state, BranchPlot.axes);
    try
        uistack(predict_solution, 'top');
    catch
    end
    drawnow limitrate;
end

function ConfigureBranchPlotForContinuation(BranchPlot, results)
    if isempty(BranchPlot) || ~isprop(BranchPlot, 'axes') || ~isgraphics(BranchPlot.axes)
        return;
    end

    if isprop(BranchPlot, 'Orbit') && isgraphics(BranchPlot.Orbit)
        delete(BranchPlot.Orbit);
    end
    if isprop(BranchPlot, 'Current_Position') && isgraphics(BranchPlot.Current_Position)
        delete(BranchPlot.Current_Position);
    end
    if isprop(BranchPlot, 'Poincare_Section') && isgraphics(BranchPlot.Poincare_Section)
        delete(BranchPlot.Poincare_Section);
    end
    if isprop(BranchPlot, 'Text') && isstruct(BranchPlot.Text)
        if isfield(BranchPlot.Text, 'textPS') && isgraphics(BranchPlot.Text.textPS)
            delete(BranchPlot.Text.textPS);
        end
        if isfield(BranchPlot.Text, 'textPO') && isgraphics(BranchPlot.Text.textPO)
            delete(BranchPlot.Text.textPO);
        end
    end

    UpdateBranchPlotAxes(BranchPlot, results);
    view(BranchPlot.axes, [0 0]);
    BranchPlot.axes.Title.String = 'Searching for Solution Branch...';
end

function InitializeRealSolutionMarkers(BranchPlot, results)
    if isempty(BranchPlot) || ~isprop(BranchPlot, 'axes') || ~isgraphics(BranchPlot.axes)
        return;
    end

    delete(findobj(BranchPlot.axes, 'Tag', 'RealSolutionMarker'));

    marker_colors = zeros(size(results,2), 3);
    for idx = 1:size(results,2)
        marker_colors(idx,:) = SafeGaitColor(results(1:22,idx));
    end

    h = scatter3(results(1,:),results(3,:),results(5,:),120,marker_colors,'filled', ...
        'Parent',BranchPlot.axes, ...
        'MarkerEdgeColor','flat', ...
        'MarkerFaceColor','flat');
    h.Tag = 'RealSolutionMarker';
    drawnow limitrate;
end

function AppendRealSolutionMarker(BranchPlot, X_state)
    if isempty(BranchPlot) || ~isprop(BranchPlot, 'axes') || ~isgraphics(BranchPlot.axes)
        return;
    end

    real_solution = findobj(BranchPlot.axes, 'Tag', 'RealSolutionMarker');
    if isempty(real_solution) || ~isgraphics(real_solution(1))
        InitializeRealSolutionMarkers(BranchPlot, X_state(:));
        return;
    end
    real_solution = real_solution(1);

    x_data = [real_solution.XData(:).', X_state(1)];
    y_data = [real_solution.YData(:).', X_state(3)];
    z_data = [real_solution.ZData(:).', X_state(5)];
    color_data = [real_solution.CData; SafeGaitColor(X_state)];
    set(real_solution, ...
        'XData', x_data, ...
        'YData', y_data, ...
        'ZData', z_data, ...
        'CData', color_data);
    drawnow limitrate;
end

function color_plot = SafeGaitColor(X_state)
    color_plot = [0 0.4470 0.7410];
    try
        [~,~, candidate_color, ~] = Gait_Identification(X_state);
        if isnumeric(candidate_color) && numel(candidate_color) == 3 ...
                && all(isfinite(candidate_color(:)))
            color_plot = reshape(candidate_color, 1, 3);
        end
    catch
        % Plotting diagnostics must never interrupt continuation.
    end
end

function ClearPredictorOverlay(BranchPlot)
    if isempty(BranchPlot) || ~isprop(BranchPlot, 'axes') || ~isgraphics(BranchPlot.axes)
        return;
    end

    delete(findobj(BranchPlot.axes, 'Tag', 'PredictedSolutionMarker'));
    delete(findobj(BranchPlot.axes, 'Tag', 'PredictedSolutionText'));
end

function UpdateBranchPlotAxes(BranchPlot, results, extra_state)
    x_values = results(1,:);
    y_values = results(3,:);
    z_values = results(5,:);

    if nargin >= 3 && ~isempty(extra_state)
        x_values = [x_values, extra_state(1)];
        y_values = [y_values, extra_state(3)];
        z_values = [z_values, extra_state(5)];
    end

    BranchPlot.axes.XLim = ExpandedAxisLimits(x_values);
    BranchPlot.axes.YLim = ExpandedAxisLimits(y_values, 0);
    BranchPlot.axes.ZLim = ExpandedAxisLimits(z_values);
end

function limits = ExpandedAxisLimits(values, reference_value)
    values = values(isfinite(values));
    has_reference = nargin >= 2 && isfinite(reference_value);
    if nargin >= 2 && isfinite(reference_value)
        values = [values(:); reference_value];
    end

    if isempty(values)
        limits = [-1, 1];
        return;
    end

    min_value = min(values);
    max_value = max(values);
    if abs(max_value - min_value) < eps
        center = 0.5 * (min_value + max_value);
        pad = max(0.1, 0.1 * max(abs(center), 1));
        limits = [center - pad, center + pad];
        return;
    end

    lower = min_value - 0.1 * max(abs(min_value), 1e-12);
    upper = max_value + 0.1 * max(abs(max_value), 1e-12);

    if has_reference
        reference_pad = max(0.1, 0.1 * (max_value - min_value));
        if abs(reference_value - min_value) < eps
            lower = min(lower, reference_value - reference_pad);
        end
        if abs(reference_value - max_value) < eps
            upper = max(upper, reference_value + reference_pad);
        end
    end

    if lower >= upper
        center = 0.5 * (min_value + max_value);
        pad = max(0.1, 0.1 * max(abs(center), 1));
        limits = [center - pad, center + pad];
    else
        limits = [lower, upper];
    end
end

function label_position = PredictorTextPosition(X_state, branch_axes)
    x_limits = branch_axes.XLim;
    z_limits = branch_axes.ZLim;

    x_span = x_limits(2) - x_limits(1);
    z_span = z_limits(2) - z_limits(1);

    if ~(isfinite(x_span) && x_span > 0)
        x_span = 1;
    end
    if ~(isfinite(z_span) && z_span > 0)
        z_span = 1;
    end

    label_position = [ ...
        X_state(1) + 0.02 * x_span, ...
        X_state(3), ...
        X_state(5) + 0.03 * z_span];
end

%% Interaction Helpers
function [stop_search, stop_flag] = PromptVelocityZeroCrossing(previous_speed, current_speed, direction_label, iter_idx, log_path)
    stop_search = false;
    stop_flag = '';
    timeout_seconds = 5;

    zero_tol = 1e-6;
    crossed_zero = ((previous_speed > zero_tol) && (current_speed <= zero_tol)) || ...
                   ((previous_speed < -zero_tol) && (current_speed >= -zero_tol));

    if ~crossed_zero
        return;
    end

    AppendContinuationLog(log_path, sprintf( ...
        '%s | iter %d | zero crossing detected | previousSpeed=%.6g | currentSpeed=%.6g', ...
        direction_label, iter_idx, previous_speed, current_speed));

    prompt_message = sprintf([ ...
        '%s crossed velocity = 0.\n\n' ...
        'Previous speed: %.6g\n' ...
        'Current speed: %.6g\n\n' ...
        'Do you want to continue searching in this direction?'], ...
        direction_label, previous_speed, current_speed);
    dialog_title = 'Velocity Zero Crossing';
    user_choice = '';

    try
        if usejava('desktop')
            drawnow;
            user_choice = TimedContinueStopDialog(prompt_message, dialog_title, timeout_seconds);
        end
    catch
        user_choice = '';
    end

    if isempty(user_choice)
        fprintf(['\n%s\n\nNo desktop dialog available. ' ...
            'Defaulting to Stop in %.0f seconds.\n'], ...
            prompt_message, timeout_seconds);
        pause(timeout_seconds);
        user_choice = 'Stop';
    end

    if strcmpi(strtrim(user_choice), 'Continue')
        AppendContinuationLog(log_path, sprintf('%s | iter %d | zero crossing decision | continue', direction_label, iter_idx));
        return;
    end

    stop_search = true;
    stop_flag = 'Algorithm stopped: user stopped after velocity zero crossing.';
    AppendContinuationLog(log_path, sprintf('%s | iter %d | zero crossing decision | stop', direction_label, iter_idx));
end

function user_choice = TimedContinueStopDialog(prompt_message, dialog_title, timeout_seconds)
    user_choice = 'Stop';

    prompt_lines = regexp(prompt_message, '\n', 'split');
    prompt_lines = [prompt_lines, {sprintf('No response in %.0f seconds => Stop.', timeout_seconds)}];

    screen_size = get(0, 'ScreenSize');
    dialog_width = min(max(420, 0.30 * screen_size(3)), 620);
    dialog_height = min(max(190, 110 + 24 * numel(prompt_lines)), 320);
    dialog_left = screen_size(1) + (screen_size(3) - dialog_width) / 2;
    dialog_bottom = screen_size(2) + (screen_size(4) - dialog_height) / 2;
    font_size = min(14, max(10, round(0.015 * screen_size(4))));

    dlg = dialog( ...
        'Name', dialog_title, ...
        'Position', [dialog_left, dialog_bottom, dialog_width, dialog_height], ...
        'WindowStyle', 'normal', ...
        'Resize', 'on', ...
        'CloseRequestFcn', @closeAsStop);

    setappdata(dlg, 'user_choice', 'Stop');

    uicontrol( ...
        'Parent', dlg, ...
        'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.05, 0.32, 0.90, 0.60], ...
        'String', prompt_lines, ...
        'HorizontalAlignment', 'left', ...
        'FontSize', font_size);

    uicontrol( ...
        'Parent', dlg, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.18, 0.08, 0.26, 0.15], ...
        'String', 'Continue', ...
        'FontSize', font_size, ...
        'Callback', @(~,~) setChoiceAndResume('Continue'));

    uicontrol( ...
        'Parent', dlg, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.56, 0.08, 0.26, 0.15], ...
        'String', 'Stop', ...
        'FontSize', font_size, ...
        'Callback', @(~,~) setChoiceAndResume('Stop'));

    uiwait(dlg, timeout_seconds);

    if ishghandle(dlg)
        user_choice = getappdata(dlg, 'user_choice');
        delete(dlg);
    end

    function setChoiceAndResume(choice)
        if ishghandle(dlg)
            setappdata(dlg, 'user_choice', choice);
            uiresume(dlg);
        end
    end

    function closeAsStop(~, ~)
        setChoiceAndResume('Stop');
    end
end
