classdef RootSolver_v3
    %ROOTSOLVER_V3 Solve a continuous residual with discrete-mode closure.
    %   RESULT = SOLVE(SOLVER, RESIDUAL, U0, P, Q0) tries Q0 and any
    %   neighboring modes exposed by RESIDUAL or RESIDUAL.Map.System.  Each
    %   mode is a separate continuous solve; a discrete mode is never passed
    %   to fsolve as a numerical unknown.

    properties
        Algorithm = 'auto'            % 'auto', 'fsolve', 'newton', or 'root-newton'
        Display = 'off'
        FunctionTolerance = 1e-9
        StepTolerance = 1e-10
        OptimalityTolerance = 1e-9
        MaxIterations = 150
        MaxFunctionEvaluations = 5000
        MaxWallSeconds = Inf
        InitialDamping = 1e-6
        InitialTrustRadius = 1
        MinimumTrustRadius = 1e-12
        MaximumTrustRadius = 1e4
        RequireSquare = true
        ResidualAcceptanceTolerance = 1e-7
        Jacobian = []
        ModeCandidates = {}
        StateScale = []
        ParameterScale = []
        EnableMapCache = true
        ProvideJacobianToFsolve = true
        FsolveAlgorithm = ''          % Empty retains the native default.
        FsolveInitialDamping = []     % Explicit LM only; optimoptions API.
        FsolveScaleProblem = ''       % Empty, 'none', or LM 'jacobian'.
        ReuseJacobian = false
        InitialJacobian = []
        UseBroyden = false
        JacobianRefreshInterval = 5
        RootNewtonMinimumRcond = 1e-14 % Numerical matrix guard for root-newton only.
    end

    methods
        function obj = RootSolver_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            if isempty(obj.Jacobian)
                obj.Jacobian = HybridFiniteDifferenceJacobian_v3();
            end
            obj.validateOptions();
        end

        function [u, result] = solve(obj, residual, u0, p, q0)
            if nargin < 5
                q0 = [];
            end
            u0 = u0(:);
            p = p(:);
            [modes, modeResolution] = obj.candidateModes( ...
                residual, u0, p, q0);
            if isempty(modes)
                modes = {q0};
            end

            attempts = repmat(obj.emptyAttempt(), 1, numel(modes));
            bestIndex = 0;
            bestScore = Inf;
            for i = 1:numel(modes)
                attempts(i) = obj.solveOne(residual, u0, p, modes{i});
                score = attempts(i).residualNorm;
                if attempts(i).converged
                    score = score - 1;
                end
                if isfinite(score) && score < bestScore
                    bestScore = score;
                    bestIndex = i;
                end
            end

            if bestIndex == 0
                bestIndex = 1;
            end
            chosen = attempts(bestIndex);
            u = chosen.state;
            result = chosen;
            result.attempts = attempts;
            result.candidateModes = modes;
            result.selectedAttempt = bestIndex;
            result.parameter = p;
            result.initialGuess = u0;
            result.modeResolution = modeResolution;
            result.selectedMode = result.mode;
            result.rejectedModeDiagnostics = attempts(~[attempts.converged]);
        end

        function [u, fval, exitflag, output, q, result] = ...
                solveFsolveStyle(obj, residual, u0, p, q0)
            [u, result] = obj.solve(residual, u0, p, q0);
            fval = result.residual;
            exitflag = result.exitflag;
            output = result.output;
            q = result.mode;
        end

        function [modes, diagnostics] = candidateModes(obj, residual, u, p, q0)
            modes = {q0};
            diagnostics = repmat(struct('mode', [], 'reason', '', ...
                'source', ''), 1, 0);
            diagnostics(end + 1) = struct('mode', q0, ...
                'reason', 'previous accepted or supplied section mode', ...
                'source', 'q0');
            modes = obj.appendModes(modes, obj.ModeCandidates, q0);
            diagnostics = obj.appendModeDiagnostics(diagnostics, ...
                obj.ModeCandidates, 'explicit solver candidate', 'solver');

            % A residual may own chart-specific mode-candidate logic.
            residualOwnsProvider = obj.hasModeProvider(residual);
            [candidates, providerDiagnostics] = ...
                obj.tryModeProvider(residual, u, q0, p);
            modes = obj.appendModes(modes, candidates, q0);
            diagnostics = obj.appendModeDiagnostics(diagnostics, ...
                providerDiagnostics, 'local residual candidate', 'residual');

            % Otherwise query the hybrid system using a reconstructed state.
            map = obj.getMember(residual, 'Map');
            system = obj.getMember(map, 'System');
            if ~isempty(system) && ~residualOwnsProvider
                x = obj.fullState(residual, u, p, q0);
                [candidates, providerDiagnostics] = ...
                    obj.tryModeProvider(system, x, q0, p);
                modes = obj.appendModes(modes, candidates, q0);
                diagnostics = obj.appendModeDiagnostics(diagnostics, ...
                    providerDiagnostics, 'system candidate', 'system');
            end
            modes = obj.uniqueModes(modes);
            diagnostics = obj.uniqueModeDiagnostics(diagnostics, modes);
        end
    end

    methods (Access = private)
        function attempt = solveOne(obj, residual, u0, p, q)
            attempt = obj.emptyAttempt();
            attempt.mode = q;
            attempt.state = u0;
            stateScale = obj.resolveScale(obj.StateScale, u0, 'StateScale');
            parameterScale = obj.resolveScale( ...
                obj.ParameterScale, p, 'ParameterScale');
            scaledInitial = u0(:) ./ stateScale;
            cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            functionEvaluations = 0;
            mapEvaluations = 0;
            cacheHits = 0;
            invalidEvaluations = 0;
            jacobianEvaluations = 0;
            invalidEvaluationDiagnostics = {};
            fsolveFailure = struct();
            evaluationPhase = 'initial-residual';
            evaluatingJacobian = false;
            solveClock = tic;
            iterationJournal = struct([]);
            lastAcceptedIterate = struct();
            lastFiniteEvaluatedBase = struct();
            latestJacobianInfo = struct();
            latestJacobianReliable = false;
            fallbackSource = 'original-seed';

            rootTolerance = obj.ResidualAcceptanceTolerance;
            if strcmpi(obj.Algorithm,'root-newton')
                rootTolerance = min(obj.FunctionTolerance,obj.ResidualAcceptanceTolerance);
            end
            try
                r0 = cachedObjective(scaledInitial);
                if strcmpi(obj.Algorithm,'root-newton') && ...
                        (isempty(u0)||~isreal(u0)||any(~isfinite(u0))||~isnumeric(r0)||~isreal(r0)||numel(r0)~=numel(u0)||any(~isfinite(r0(:))))
                    error('RootSolver_v3:RootNewtonSquare','root-newton requires a finite real square root system, even when RequireSquare is false.');
                end
                if obj.RequireSquare && numel(r0) ~= numel(u0)
                    error('RootSolver_v3:NonSquareResidual', ...
                        ['The residual has %d equations for %d continuous ' ...
                         'unknowns. Use a reduced section chart or disable ' ...
                         'RequireSquare explicitly.'], numel(r0), numel(u0));
                end
            catch ME
                attempt.message = ME.message;
                attempt.errorIdentifier = ME.identifier;
                attempt.primaryMessage = ME.message;
                attempt.primaryErrorIdentifier = ME.identifier;
                attempt.functionEvaluationCount = functionEvaluations;
                attempt.mapEvaluationCount = mapEvaluations;
                attempt.invalidEvaluationCount = invalidEvaluations;
                attempt.invalidEvaluationDiagnostics = invalidEvaluationDiagnostics;
                attempt.status = obj.failureStatus(ME.identifier,'initial-residual');
                attempt.iterationJournal = iterationJournal;
                attempt.lastAcceptedIterate = lastAcceptedIterate;
                attempt.lastFiniteEvaluatedBase = lastFiniteEvaluatedBase;
                attempt.originalSeedFallback = u0;
                attempt.fallbackSource = fallbackSource;
                return
            end
            recordAccepted(scaledInitial,r0,struct('iteration',0, ...
                'algorithm','initial-validated-base'));

            algorithm = lower(char(obj.Algorithm));
            candidates = {};
            if norm(r0, Inf) <= rootTolerance
                initialSolution = obj.emptySolved();
                initialSolution.state = scaledInitial;
                initialSolution.residual = r0;
                initialSolution.residualNorm = norm(r0, Inf);
                initialSolution.exitflag = 1;
                initialSolution.output = struct( ...
                    'iterations', 0, 'funcCount', 1, ...
                    'algorithm', 'verified initial residual', ...
                    'message', 'Initial point satisfies the root tolerance.');
                initialSolution.solver = 'residual-check';
                initialSolution.message = ...
                    'Initial point satisfies the root tolerance.';
                initialSolution.converged = true;
                % No derivative has been evaluated on this short path.  A
                % small initial residual validates the root, not a Jacobian.
                initialSolution.jacobianReliable = false;
                candidates{end + 1} = initialSolution;
            elseif any(strcmp(algorithm, {'auto', 'fsolve'})) && ...
                    exist('fsolve', 'file') == 2
                evaluationPhase = 'fsolve';
                candidates{end + 1} = obj.runFsolve( ...
                    @fsolveObjective, scaledInitial, @observeFsolve, @fsolveFallback);
            end
            if norm(r0, Inf) > rootTolerance && ...
                    (strcmp(algorithm, 'root-newton') || strcmp(algorithm, 'newton') ...
                    || strcmp(algorithm, 'auto') || isempty(candidates))
                newtonStart = scaledInitial;
                if ~isempty(candidates) && ...
                        all(isfinite(candidates{end}.state))
                    newtonStart = candidates{end}.state;
                end
                initialJacobian = [];
                if obj.ReuseJacobian && ~isempty(obj.InitialJacobian) && ...
                        size(obj.InitialJacobian, 2) == numel(u0)
                    initialJacobian = obj.InitialJacobian * diag(stateScale);
                end
                if strcmp(algorithm,'root-newton')
                    evaluationPhase = 'root-newton';
                    candidates{end + 1} = obj.runRootNewton( ...
                        @safeObjective,@jacobianAt,newtonStart,initialJacobian,@recordAccepted);
                else
                evaluationPhase = 'newton';
                candidates{end + 1} = obj.runDampedNewton( ...
                    @cachedObjective, @safeObjective, @jacobianAt, ...
                    newtonStart, initialJacobian, @recordAccepted);
                end
            end

            scores = Inf(1, numel(candidates));
            for i = 1:numel(candidates)
                scores(i) = candidates{i}.residualNorm;
                if candidates{i}.converged
                    scores(i) = scores(i) - 1;
                end
            end
            [~, best] = min(scores);
            if isempty(best) || ~isfinite(scores(best))
                best = 1;
            end
            solved = candidates{best};

            attempt.state = solved.state(:) .* stateScale;
            attempt.residual = solved.residual;
            attempt.residualNorm = solved.residualNorm;
            attempt.exitflag = solved.exitflag;
            attempt.output = solved.output;
            attempt.fsolveOptions = solved.fsolveOptions;
            attempt.solver = solved.solver;
            attempt.message = solved.message;
            attempt.errorIdentifier = solved.errorIdentifier;
            attempt.converged = solved.converged && ...
                solved.residualNorm <= obj.ResidualAcceptanceTolerance;
            attempt.primaryConverged = attempt.converged;
            attempt.primaryMessage = solved.message;
            attempt.primaryErrorIdentifier = solved.errorIdentifier;
            attempt.primaryExitflag = solved.exitflag;
            attempt.stateScale = stateScale;
            attempt.parameterScale = parameterScale;
            attempt.functionEvaluationCount = functionEvaluations;
            attempt.mapEvaluationCount = mapEvaluations;
            attempt.cacheHitCount = cacheHits;
            attempt.invalidEvaluationCount = invalidEvaluations;
            attempt.jacobianEvaluationCount = jacobianEvaluations;
            attempt.finalJacobian = [];
            attempt.jacobianReliable = solved.jacobianReliable;
            attempt.derivativeModel = obj.derivativeModelName();
            attempt.derivativeEvaluated = jacobianEvaluations > 0;
            attempt.acceptedNewtonIterations = obj.outputMember( ...
                solved.output, 'acceptedIterations', 0);
            attempt.invalidTrialCount = obj.outputMember( ...
                solved.output, 'invalidTrialCount', 0);
            attempt.jacobianDiagnostics = obj.outputMember( ...
                solved.output, 'jacobianInfo', struct());
            attempt.selectedFiniteDifferenceSteps = obj.outputMember( ...
                attempt.jacobianDiagnostics, 'selectedSteps', []);
            attempt.perColumnReliability = obj.outputMember( ...
                attempt.jacobianDiagnostics, 'perColumnReliability', []);
            if ~isempty(solved.jacobian)
                % Elementwise column scaling preserves a failed column's
                % NaNs locally; NaN*0 in a diagonal matrix product otherwise
                % contaminates every diagnostic column.
                attempt.finalJacobian = solved.jacobian ./ stateScale(:).';
            end

            evaluationPhase = 'final-validation';
            try
                [~, validReturn, evalInfo] = safeObjective( ...
                    attempt.state ./ stateScale);
                attempt.evaluationInfo = evalInfo;
                if ~validReturn
                    attempt.converged = false;
                    attempt.finalizationMessage = 'Residual evaluation reported an invalid hybrid return.';
                end
                if isstruct(evalInfo) && isfield(evalInfo,'full_physical_closure_norm')
                    tolerance = obj.getMember(residual,'ClosureTolerance');
                    if isempty(tolerance),tolerance=obj.ResidualAcceptanceTolerance;end
                    if ~isfinite(evalInfo.full_physical_closure_norm) || ...
                            evalInfo.full_physical_closure_norm > tolerance
                        attempt.converged=false;
                        attempt.finalizationMessage='Reduced residual candidate failed full physical closure.';
                        attempt.finalizationErrorIdentifier='RootSolver_v3:FullClosure';
                    end
                end
                attempt.fullState = obj.fullState( ...
                    residual, attempt.state, p, q);
                % An unconverged candidate is diagnostic evidence, not an
                % orbit. Do not let createOrbit replace the primary exit.
                if attempt.converged
                    attempt.orbit = obj.createOrbit( ...
                        residual, attempt.state, p, q, evalInfo);
                end
                attempt.cyclicEventSignature = obj.infoMember(evalInfo, ...
                    {'cyclic_event_signature', 'cyclicEventSignature', ...
                     'cycle_signature', 'cycleSignature'}, '');
                attempt.sectionRelativeSignature = obj.infoMember(evalInfo, ...
                    {'section_relative_event_signature', ...
                     'sectionRelativeEventSignature', ...
                     'section_event_signature', 'sectionEventSignature'}, '');
                attempt.eventClusterSignature = obj.infoMember(evalInfo, ...
                    {'event_cluster_signature', 'eventClusterSignature', ...
                     'cluster_signature', 'clusterSignature'}, '');
            catch ME
                attempt.converged = false;
                attempt.finalizationMessage = ME.message;
                attempt.finalizationErrorIdentifier = ME.identifier;
            end
            if attempt.primaryConverged && ~attempt.converged
                attempt.message = attempt.finalizationMessage;
                attempt.errorIdentifier = attempt.finalizationErrorIdentifier;
            end
            attempt.functionEvaluationCount = functionEvaluations;
            attempt.mapEvaluationCount = mapEvaluations;
            attempt.cacheHitCount = cacheHits;
            attempt.invalidEvaluationCount = invalidEvaluations;
            attempt.jacobianEvaluationCount = jacobianEvaluations;
            attempt.invalidEvaluationDiagnostics = invalidEvaluationDiagnostics;
            attempt.fsolveFailure = fsolveFailure;
            attempt.iterationJournal = iterationJournal;
            attempt.lastAcceptedIterate = lastAcceptedIterate;
            attempt.lastFiniteEvaluatedBase = lastFiniteEvaluatedBase;
            attempt.originalSeedFallback = u0;
            attempt.fallbackSource = fallbackSource;
            if attempt.converged
                attempt.status = 'converged';
            elseif strcmp(attempt.finalizationErrorIdentifier,'RootSolver_v3:FullClosure')
                attempt.status = 'failed_full_closure';
            elseif any(cellfun(@(entry)contains(entry.identifier,'Budget'),invalidEvaluationDiagnostics))
                attempt.status = 'budget_refusal';
            elseif ~isempty(attempt.primaryErrorIdentifier)
                attempt.status = obj.failureStatus(attempt.primaryErrorIdentifier,'correction');
            elseif attempt.exitflag == -3
                attempt.status = 'derivative_failure';
            else
                attempt.status = 'nonconverged_finite_residual';
            end

            function stop = observeFsolve(scaledState,optimValues,solverState)
                stop = false;
                if any(strcmp(solverState,{'init','iter','done'})) ...
                        && isfield(optimValues,'fval') && all(isfinite(optimValues.fval(:)))
                    control = struct('iteration',obj.outputMember(optimValues,'iteration',NaN), ...
                        'algorithm','fsolve','native_state',solverState, ...
                        'step',obj.outputMember(optimValues,'step',[]), ...
                        'damping',obj.outputMember(optimValues,'lambda',NaN), ...
                        'trust_radius',obj.outputMember(optimValues,'trustregionradius',NaN));
                    recordAccepted(scaledState,optimValues.fval,control);
                end
            end

            function [state,value,source] = fsolveFallback()
                if ~isempty(fieldnames(lastAcceptedIterate))
                    row = lastAcceptedIterate;source = 'last-accepted-iterate';
                elseif ~isempty(fieldnames(lastFiniteEvaluatedBase))
                    row = lastFiniteEvaluatedBase;source = 'last-finite-evaluated-base';
                else
                    state = scaledInitial;value = [];source = 'original-seed';
                    fallbackSource = source;return
                end
                state = row.scaled_coordinates;value = row.scaled_residual;
                fallbackSource = source;
            end

            function recordAccepted(scaledState,value,control)
                key = sprintf('%.17g,',scaledState(:));info = struct();
                if isKey(cache,key)
                    cached = cache(key);info = cached.info;
                elseif ~isempty(fieldnames(lastFiniteEvaluatedBase)) ...
                        && isequal(scaledState(:),lastFiniteEvaluatedBase.scaled_coordinates)
                    info = lastFiniteEvaluatedBase.diagnostic_info;
                end
                row = journalRow(scaledState,value,info,true,'','',true);
                row.kind = 'accepted-iterate';row.derivative_probe = false;
                row.iteration = obj.outputMember(control,'iteration',NaN);
                row.algorithm = obj.outputMember(control,'algorithm','');
                row.native_state = obj.outputMember(control,'native_state','');
                row.scaled_step = obj.outputMember(control,'step',[]);
                if numel(row.scaled_step)~=numel(scaledState),row.scaled_step=[];end
                if isempty(row.scaled_step)&&~isempty(fieldnames(lastAcceptedIterate))
                    row.scaled_step = scaledState(:)-lastAcceptedIterate.scaled_coordinates;
                end
                if ~isempty(row.scaled_step),row.step = row.scaled_step(:).*stateScale;end
                row.damping = obj.outputMember(control,'damping',NaN);
                row.trust_radius = obj.outputMember(control,'trust_radius',NaN);
                row.line_search_fraction = obj.outputMember(control,'line_search_fraction',NaN);
                row.jacobian_reliable = obj.outputMember(control,'jacobian_reliable',latestJacobianReliable);
                lastAcceptedIterate = row;
                if isempty(iterationJournal),iterationJournal=row;
                else,iterationJournal(end+1)=row;end
            end

            function row = journalRow(scaledState,value,info,valid,identifier,message,fromCache,mapSeconds)
                if nargin<8,mapSeconds=0;end
                diagnosticInfo = compactInfo(info);
                row = struct('kind','evaluation','phase',evaluationPhase, ...
                    'function_evaluation_index',functionEvaluations, ...
                    'map_evaluation_count',mapEvaluations,'elapsed_seconds',toc(solveClock), ...
                    'coordinates',scaledState(:).*stateScale, ...
                    'scaled_coordinates',scaledState(:),'state_scale',stateScale, ...
                    'parameter',p,'parameter_scale',parameterScale,'mode',q, ...
                    'scaled_residual',value(:), ...
                    'unscaled_residual',obj.outputMember(info,'physical_residual',value(:)), ...
                    'residual_scale',obj.outputMember(info,'residual_scale',ones(numel(value),1)), ...
                    'residual_norm',norm(value(:),inf),'valid',logical(valid), ...
                    'from_cache',fromCache,'derivative_probe',evaluatingJacobian, ...
                    'map_elapsed_seconds',mapSeconds, ...
                    'identifier',identifier,'message',message, ...
                    'native_energy',obj.outputMember(info,'energy',NaN), ...
                    'free_energy',obj.outputMember(info,'augmented_energy',NaN), ...
                    'energy_is_free',obj.getMember(residual,'Augmented'), ...
                    'full13_closure',obj.outputMember(info,'full_physical_closure_residual',[]), ...
                    'full13_closure_norm',obj.outputMember(info,'full_physical_closure_norm',NaN), ...
                    'selector_error',obj.outputMember(info,'constraint_residual',NaN), ...
                    'cyclic_event_signature',obj.outputMember(info,'cyclic_event_signature',''), ...
                    'section_relative_event_signature',obj.outputMember(info,'section_relative_event_signature',''), ...
                    'event_cluster_signature',obj.outputMember(info,'event_cluster_signature',''), ...
                    'physical_margins',obj.outputMember(info,'minimum_physical_margins',struct()), ...
                    'minimum_physical_margin',obj.outputMember(info,'minimum_physical_margin',NaN), ...
                    'topology_margins',obj.outputMember(info,'topology_margins',struct()), ...
                    'jacobian_reliable',latestJacobianReliable, ...
                    'jacobian_selected_steps',obj.outputMember(latestJacobianInfo,'selectedSteps',[]), ...
                    'jacobian_column_reliability',obj.outputMember(latestJacobianInfo,'perColumnReliability',[]), ...
                    'iteration',NaN,'algorithm','','native_state','', ...
                    'scaled_step',[],'step',[],'damping',NaN,'trust_radius',NaN, ...
                    'line_search_fraction',NaN,'diagnostic_info',diagnosticInfo);
                if isempty(value)||~valid,row.residual_norm=Inf;end
            end

            function output = compactInfo(info)
                output = struct();
                names = {'physical_residual','residual_scale','energy','augmented_energy', ...
                    'full_physical_closure_residual','full_physical_closure_norm', ...
                    'constraint_residual','cyclic_event_signature', ...
                    'section_relative_event_signature','event_cluster_signature', ...
                    'minimum_physical_margins','minimum_physical_margin','topology_margins'};
                for nameIndex=1:numel(names)
                    if isstruct(info)&&isfield(info,names{nameIndex})
                        output.(names{nameIndex}) = info.(names{nameIndex});
                    end
                end
            end

            function r = cachedObjective(scaledState)
                [r, valid, ~, errorIdentifier, message] = ...
                    evaluateScaled(scaledState);
                if ~valid
                    if isempty(errorIdentifier)
                        errorIdentifier = 'RootSolver_v3:InvalidHybridTrial';
                    end
                    error(errorIdentifier, '%s', message);
                end
            end

            function [r, valid, info, errorIdentifier, message] = safeObjective(scaledState, varargin)
                [r, valid, info, errorIdentifier, message] = evaluateScaled(scaledState, varargin{:});
            end

            function [r, J] = fsolveObjective(scaledState)
                stage = 'objective-residual';
                r = [];
                J = [];
                fdInfo = struct();
                jacobianRejectionReason = '';
                try
                    r = cachedObjective(scaledState);
                    if nargout > 1
                        stage = 'objective-jacobian';
                        [J, fdInfo] = jacobianAt(scaledState, r);
                        % A failed hybrid column must not enter native
                        % fsolve as NaN and generate a nonfinite trial.
                        % Explicit Jacobians without reliability metadata
                        % retain the same trust convention as Newton.
                        if ~isnumeric(J) || isempty(J) || ...
                                ~isequal(size(J), [numel(r), numel(scaledState)])
                            jacobianRejectionReason = 'incomplete or incorrectly sized derivative';
                        elseif any(~isfinite(J(:)))
                            jacobianRejectionReason = 'nonfinite derivative column';
                        elseif ~obj.jacobianInfoReliable(fdInfo)
                            jacobianRejectionReason = 'derivative reliability checks failed';
                        end
                        if ~isempty(jacobianRejectionReason)
                            error('RootSolver_v3:InvalidJacobian', ...
                                ['A complete finite reliable Jacobian is ' ...
                                 'required before the fsolve step: %s.'], ...
                                jacobianRejectionReason);
                        end
                    end
                catch exception
                    fsolveFailure = struct('stage', stage, ...
                        'scaled_coordinates', scaledState(:), ...
                        'coordinates', scaledState(:).*stateScale, ...
                        'state_scale', stateScale, 'parameter', p, 'mode', q, ...
                        'identifier', exception.identifier, ...
                        'message', exception.message, 'stack', exception.stack, ...
                        'invalid_evaluation_count', numel(invalidEvaluationDiagnostics), ...
                        'base_residual', r, 'derivative_matrix', J, ...
                        'derivative_report', fdInfo, ...
                        'derivative_rejection_reason', jacobianRejectionReason, ...
                        'base_residual_valid', strcmp(stage, 'objective-jacobian'), ...
                        'scope', ['Jacobian-stage coordinates identify the derivative base, ' ...
                        'not an offending probe; original map stacks are in invalidEvaluationDiagnostics.']);
                    rethrow(exception)
                end
            end

            function [J, fdInfo] = jacobianAt(scaledState, baseline)
                jacobianEvaluations = jacobianEvaluations + 1;
                latestJacobianReliable = false;
                evaluatingJacobian = true;
                jacobianCleanup = onCleanup(@finishJacobian); %#ok<NASGU>
                if isa(obj.Jacobian, 'HybridFiniteDifferenceJacobian_v3')
                    [J, ~, fdInfo] = obj.Jacobian.compute( ...
                        @hybridObjective, scaledState);
                else
                    [J, ~, fdInfo] = obj.Jacobian.compute( ...
                        @cachedObjective, scaledState);
                end
                if nargin >= 2 && ~isempty(baseline)
                    fdInfo.baselineResidual = baseline;
                end
                latestJacobianInfo = fdInfo;
                latestJacobianReliable = obj.jacobianInfoReliable(fdInfo) ...
                    && isnumeric(J)&&~isempty(J)&&all(isfinite(J(:)));
            end

            function finishJacobian()
                evaluatingJacobian = false;
            end

            function [r, metadata] = hybridObjective(scaledState, varargin)
                [r, valid, metadata, errorIdentifier, message] = safeObjective( ...
                    scaledState, varargin{:});
                if isempty(metadata) || ~isstruct(metadata)
                    metadata = struct();
                end
                metadata.valid = valid;
                metadata.integration_success = valid;
                if ~valid
                    metadata.errorIdentifier = errorIdentifier;
                    metadata.message = message;
                end
            end

            function [r, valid, info, errorIdentifier, message] = ...
                    evaluateScaled(scaledState, varargin)
                functionEvaluations = functionEvaluations + 1;
                scaledState = scaledState(:);
                key = sprintf('%.17g,', scaledState);
                % p, q and the residual/map are fixed for this local solve.
                % Context overrides (including tighter derivative ODE
                % settings) deliberately bypass the local cache.
                useCache = obj.EnableMapCache && isempty(varargin);
                fromCache = false;
                if useCache && isKey(cache, key)
                    record = cache(key);
                    cacheHits = cacheHits + 1;
                    fromCache = true;
                else
                    record = struct('residual', [], 'info', struct(), ...
                        'valid', false, 'errorIdentifier', '', 'message', '', ...
                        'originalExceptionStack', struct([]), 'mapStarted', false, ...
                        'mapElapsedSeconds',0);
                    physicalState = scaledState .* stateScale;
                    try
                        if toc(solveClock) > obj.MaxWallSeconds
                            error('RootSolver_v3:WallBudget', ...
                                'Correction wall budget exhausted before another map evaluation.');
                        end
                        if mapEvaluations >= obj.MaxFunctionEvaluations
                            error('RootSolver_v3:MapEvaluationBudget', ...
                                'Correction map-evaluation budget exhausted, including derivative samples.');
                        end
                        mapEvaluations = mapEvaluations + 1;
                        record.mapStarted = true;
                        mapClock=tic;
                        [value, evaluationInfo] = obj.evaluateResidual( ...
                            residual, physicalState, p, q, varargin{:});
                        value = value(:);
                        if ~isnumeric(value) || any(~isfinite(value))
                            error('RootSolver_v3:InvalidResidual', ...
                                'Residual values must be finite numeric values.');
                        end
                        record.residual = value;
                        record.info = evaluationInfo;
                        record.valid = obj.infoIsValid(evaluationInfo);
                        if ~record.valid
                            record.errorIdentifier = ...
                                'RootSolver_v3:InvalidHybridReturn';
                            record.message = ...
                                'The hybrid return map reported an invalid trial.';
                        end
                    catch exception
                        record.errorIdentifier = exception.identifier;
                        record.message = exception.message;
                        record.originalExceptionStack = exception.stack;
                    end
                    if record.mapStarted,record.mapElapsedSeconds=toc(mapClock);end
                    if useCache
                        cache(key) = record;
                    end
                end
                r = record.residual;
                valid = record.valid;
                info = record.info;
                errorIdentifier = record.errorIdentifier;
                message = record.message;
                mapSeconds=0;
                if ~fromCache&&record.mapStarted,mapSeconds=record.mapElapsedSeconds;end
                row = journalRow(scaledState,r,info,valid,errorIdentifier,message,fromCache,mapSeconds);
                if isempty(iterationJournal),iterationJournal=row;
                else,iterationJournal(end+1)=row;end
                if valid&&~evaluatingJacobian
                    lastFiniteEvaluatedBase = row;
                end
                if ~valid
                    invalidEvaluations = invalidEvaluations + 1;
                    if isempty(message)
                        message = 'Invalid hybrid residual evaluation.';
                    end
                    stage = evaluationPhase;
                    if evaluatingJacobian, stage = [stage, '-derivative-probe']; end
                    invalidEvaluationDiagnostics{end+1} = struct( ...
                        'stage', stage, 'scaled_coordinates', scaledState, ...
                        'coordinates', scaledState.*stateScale, ...
                        'state_scale', stateScale, 'parameter', p, 'mode', q, ...
                        'identifier', errorIdentifier, 'message', message, ...
                        'original_exception_stack', record.originalExceptionStack, ...
                        'function_evaluation_index', functionEvaluations, ...
                        'map_evaluation_count', mapEvaluations, ...
                        'map_started', record.mapStarted, 'from_cache', fromCache, ...
                        'context_override_present', ~isempty(varargin));
                    % For cache hits, map_started describes the original
                    % cached evaluation, not another map in this callback.
                end
            end
        end

        function solved = runFsolve(obj, objective, u0, observer, fallback)
            solved = obj.emptySolved();
            solved.solver = 'fsolve';
            try
                options = optimset( ...
                    'Display', obj.Display, ...
                    'TolFun', obj.FunctionTolerance, ...
                    'TolX', obj.StepTolerance, ...
                    'MaxIter', obj.MaxIterations, ...
                    'MaxFunEvals', obj.MaxFunctionEvaluations, ...
                    'OutputFcn', observer);
                if obj.ProvideJacobianToFsolve
                    options = optimset(options, 'Jacobian', 'on');
                end
                if ~isempty(char(obj.FsolveAlgorithm))
                    options = optimset(options, 'Algorithm', lower(char(obj.FsolveAlgorithm)));
                end
                if ~isempty(char(obj.FsolveScaleProblem))
                    options = optimset(options, 'ScaleProblem', lower(char(obj.FsolveScaleProblem)));
                end
                if ~isempty(obj.FsolveInitialDamping)
                    % optimoptions accepts solver-option objects as its
                    % second argument, not an optimset struct. Copy only
                    % the explicitly set legacy fields via native aliases.
                    nativeOptions = optimoptions('fsolve');
                    optionNames = fieldnames(options);
                    for optionIndex = 1:numel(optionNames)
                        optionName = optionNames{optionIndex};
                        if ~isempty(options.(optionName))
                            nativeOptions.(optionName) = options.(optionName);
                        end
                    end
                    nativeOptions.InitDamping = obj.FsolveInitialDamping;
                    options = nativeOptions;
                end
                effectiveOptions = optimoptions('fsolve');
                if ~isempty(char(obj.FsolveAlgorithm))
                    effectiveOptions.Algorithm = lower(char(obj.FsolveAlgorithm));
                end
                if ~isempty(char(obj.FsolveScaleProblem))
                    effectiveOptions.ScaleProblem = lower(char(obj.FsolveScaleProblem));
                end
                if ~isempty(obj.FsolveInitialDamping)
                    effectiveOptions.InitDamping = obj.FsolveInitialDamping;
                end
                solved.fsolveOptions = struct( ...
                    'Algorithm', effectiveOptions.Algorithm, ...
                    'InitDamping', effectiveOptions.InitDamping, ...
                    'ScaleProblem', effectiveOptions.ScaleProblem, ...
                    'requestedAlgorithm', char(obj.FsolveAlgorithm), ...
                    'requestedInitialDamping', obj.FsolveInitialDamping, ...
                    'requestedScaleProblem', char(obj.FsolveScaleProblem), ...
                    'scope', ['Configured options before fsolve; successful ' ...
                    'native output.algorithm records the executed algorithm.']);
                [u, fval, exitflag, output] = fsolve(objective, u0, options);
                solved.state = u(:);
                solved.residual = fval(:);
                solved.residualNorm = norm(fval(:), Inf);
                solved.exitflag = exitflag;
                solved.output = output;
                solved.output.iterate_observer = 'native fsolve OutputFcn';
                solved.converged = exitflag > 0 && ...
                    solved.residualNorm <= obj.ResidualAcceptanceTolerance;
                if isfield(output, 'message')
                    solved.message = output.message;
                end
            catch ME
                [solved.state,solved.residual,source] = fallback();
                if ~isempty(solved.residual)
                    solved.residualNorm = norm(solved.residual,inf);
                end
                solved.output = struct('fallbackSource',source, ...
                    'iterate_observer','native fsolve OutputFcn');
                solved.message = ME.message;
                solved.errorIdentifier = ME.identifier;
            end
        end

        function solved = runRootNewton(obj, safeObjective, jacobianFunction, ...
                u0, initialJacobian, observer)
            % Square Newton equations with a domain-only trial safeguard.
            % A valid full step is accepted even when the residual increases.
            solved=obj.emptySolved();solved.solver='root-newton';u=u0(:);r=[];
            tolerance=min(obj.FunctionTolerance,obj.ResidualAcceptanceTolerance);
            J=initialJacobian;lastUsableJacobian=[];jacobianReliable=false;
            jacobianFreshAtCurrent=false;lastJacobianInfo=struct();
            iteration=0;acceptedIterations=0;invalidTrialCount=0;functionCount=0;
            lastStep=Inf;lastRcond=NaN;lastBackwardError=NaN;initialJacobianUsed=false;
            exitflag=0;message='Maximum iteration count reached without a root.';
            failureIdentifier='';iterationDiagnostics={};missingReason='initial';
            try
                [r,valid,evaluationInfo]=safeObjective(u);functionCount=functionCount+1;
                if ~valid,error('RootSolver_v3:RootNewtonInvalidInitial','Initial root residual is not a valid native return.');end
                if ~isnumeric(r)||~isreal(r)||numel(r)~=numel(u)||any(~isfinite(r(:)))
                    error('RootSolver_v3:RootNewtonSquare','root-newton requires one finite real equation per real unknown.');
                end
                if ~isempty(J)&&(~isnumeric(J)||~isreal(J)||~isequal(size(J),[numel(u),numel(u)])||any(~isfinite(J(:))))
                    error('RootSolver_v3:RootNewtonInitialJacobian','A supplied root Jacobian must be finite, real and square.');
                end
                for iteration=1:obj.MaxIterations
                    residualNorm=norm(r,Inf);
                    if residualNorm<=tolerance,exitflag=1;message='Root residual tolerance satisfied.';break;end
                    useInitial=iteration==1&&~isempty(J);initialJacobianUsed=initialJacobianUsed||useInitial;
                    refresh=isempty(J)||(~useInitial&&(~obj.UseBroyden||mod(acceptedIterations,obj.JacobianRefreshInterval)==0));
                    reason='retained-root-Jacobian';
                    if refresh
                        if isempty(J),reason=missingReason;elseif ~obj.UseBroyden,reason='fresh-each-iteration';else,reason='periodic-refresh';end
                        % A failed refresh must never silently reuse the prior matrix.
                        J=NaN(numel(u));jacobianReliable=false;jacobianFreshAtCurrent=false;
                        [J,lastJacobianInfo]=jacobianFunction(u,r);
                        jacobianReliable=obj.jacobianInfoReliable(lastJacobianInfo);
                        jacobianFreshAtCurrent=true;
                    elseif useInitial,reason='supplied-root-Jacobian';end
                    if isempty(J)||~isnumeric(J)||~isreal(J)||~isequal(size(J),[numel(u),numel(u)])||any(~isfinite(J(:)))
                        error('RootSolver_v3:RootNewtonJacobian','No finite real square root Jacobian is available.');
                    end
                    lastRcond=rcond(full(J));
                    if ~isfinite(lastRcond)||lastRcond<=obj.RootNewtonMinimumRcond
                        error('RootSolver_v3:RootNewtonJacobianCondition','Root Jacobian reciprocal condition %.17g does not exceed %.17g.',lastRcond,obj.RootNewtonMinimumRcond);
                    end
                    lastUsableJacobian=J;
                    step=J\(-r(:));
                    if ~isreal(step)||any(~isfinite(step))
                        error('RootSolver_v3:RootNewtonLinearSolve','Direct square Newton step is nonfinite or nonreal.');
                    end
                    linearScale=norm(J,Inf)*norm(step,Inf)+norm(r,Inf);
                    linearDefect=norm(J*step+r(:),Inf);
                    if ~isfinite(linearScale)||linearScale<=0||~isfinite(linearDefect)
                        error('RootSolver_v3:RootNewtonLinearSolve','Direct Newton linear residual cannot be verified finitely.');
                    end
                    lastBackwardError=linearDefect/linearScale;
                    if lastBackwardError>128*max(1,numel(u))*eps(class(J))
                        error('RootSolver_v3:RootNewtonLinearSolve','Direct Newton linear solve failed its backward-error guard.');
                    end
                    lastStep=norm(step,Inf);
                    detail=struct('iteration',iteration,'residual_infinity_norm_before',residualNorm, ...
                        'Jacobian_refreshed',refresh,'Jacobian_source',reason,'reciprocal_condition',lastRcond, ...
                        'linear_relative_backward_error',lastBackwardError,'trials',{{}},'accepted',false, ...
                        'topology_compatible',[],'Broyden_updated',false,'Jacobian_action_after_acceptance','');
                    iterationDiagnostics{end+1,1}=detail;slot=numel(iterationDiagnostics);accepted=false;
                    for trial=1:12
                        alpha=2^(-(trial-1));uTrial=u+alpha*step;
                        trialRow=struct('fraction',alpha,'invoked',true,'returned',false,'native_valid',false, ...
                            'real_finite_square',false,'accepted',false,'residual_infinity_norm',[], ...
                            'identifier','','message','');detail.trials{trial,1}=trialRow;iterationDiagnostics{slot}=detail;
                        try
                            [rTrial,validTrial,trialInfo,trialID,trialMessage]=safeObjective(uTrial);
                        catch trialFailure
                            trialRow.identifier=trialFailure.identifier;trialRow.message=trialFailure.message;
                            detail.trials{trial}=trialRow;iterationDiagnostics{slot}=detail;rethrow(trialFailure);
                        end
                        functionCount=functionCount+1;trialRow.returned=true;trialRow.native_valid=logical(validTrial);
                        trialDomain=isreal(uTrial)&&all(isfinite(uTrial))&&isnumeric(rTrial)&&isreal(rTrial)&&numel(rTrial)==numel(u)&&all(isfinite(rTrial(:)));
                        trialRow.real_finite_square=trialDomain;trialRow.identifier=trialID;trialRow.message=trialMessage;
                        if trialDomain,trialRow.residual_infinity_norm=norm(rTrial,Inf);end
                        if ~(validTrial&&trialDomain)
                            invalidTrialCount=invalidTrialCount+1;detail.trials{trial}=trialRow;iterationDiagnostics{slot}=detail;continue
                        end
                        detail.trials{trial}=trialRow;iterationDiagnostics{slot}=detail;
                        % FIRST valid trial wins. There is no residual-decrease test.
                        actualStep=uTrial-u;
                        if norm(actualStep,Inf)<=obj.StepTolerance*(1+norm(u,Inf))&&norm(rTrial,Inf)>tolerance
                            error('RootSolver_v3:RootNewtonStagnation','Domain-safe Newton trial cannot move while the root residual is nonzero.');
                        end
                        oldResidual=r;sameTopology=obj.topologyCompatible(evaluationInfo,trialInfo);
                        u=uTrial;r=rTrial(:);evaluationInfo=trialInfo;accepted=true;acceptedIterations=acceptedIterations+1;
                        trialRow.accepted=true;detail.trials{trial}=trialRow;detail.accepted=true;
                        detail.residual_infinity_norm_after=norm(r,Inf);detail.topology_compatible=sameTopology;
                        observer(u,r,struct('iteration',iteration,'algorithm','root-newton','step',actualStep, ...
                            'line_search_fraction',alpha,'jacobian_reliable',jacobianReliable));
                        jacobianFreshAtCurrent=false;
                        if obj.UseBroyden&&sameTopology
                            denominator=actualStep.'*actualStep;
                            if denominator>eps
                                J=J+(r-oldResidual-J*actualStep)*actualStep.'/denominator;
                                jacobianReliable=false;detail.Broyden_updated=true;
                            end
                            if all(isfinite(J(:))),lastUsableJacobian=J;detail.Jacobian_action_after_acceptance='retained-root-secant';
                            else,J=[];jacobianReliable=false;missingReason='nonfinite-secant-update';detail.Jacobian_action_after_acceptance='cleared-nonfinite-secant';end
                        else
                            J=[];jacobianReliable=false;
                            if ~sameTopology,missingReason='topology-invalidation';else,missingReason='fresh-each-iteration';end
                            detail.Jacobian_action_after_acceptance=['cleared-' missingReason];
                        end
                        iterationDiagnostics{slot}=detail;break
                    end
                    if ~accepted,error('RootSolver_v3:RootNewtonDomainSafeguard','All12 registered Newton fractions failed the native/domain contract.');end
                    if functionCount>=obj.MaxFunctionEvaluations,message='Maximum function-evaluation count reached without a root.';break;end
                end
            catch failure
                message=failure.message;failureIdentifier=failure.identifier;exitflag=-1;
            end
            solved.state=u;
            if isnumeric(r)&&isreal(r)&&~isempty(r)&&all(isfinite(r(:)))
                solved.residual=r(:);solved.residualNorm=norm(r,Inf);
            end
            if isempty(failureIdentifier)&&solved.residualNorm<=tolerance
                exitflag=1;message='Root residual tolerance satisfied.';
            end
            solved.exitflag=exitflag;solved.message=message;solved.errorIdentifier=failureIdentifier;
            solved.converged=exitflag==1&&isempty(failureIdentifier)&&solved.residualNorm<=tolerance;
            solved.output=struct('iterations',iteration,'funcCount',functionCount,'algorithm','direct square Newton with domain-only safeguard', ...
                'rootTolerance',tolerance,'stepsize',lastStep,'acceptedIterations',acceptedIterations, ...
                'invalidTrialCount',invalidTrialCount,'initialJacobianUsed',initialJacobianUsed, ...
                'RootNewtonMinimumRcond',obj.RootNewtonMinimumRcond,'lastReciprocalCondition',lastRcond, ...
                'lastLinearRelativeBackwardError',lastBackwardError,'trialFractions',2.^(-(0:11)), ...
                'validResidualGrowthIsAccepted',true,'jacobianInfo',lastJacobianInfo, ...
                'finalJacobianFreshAtFinalState',jacobianFreshAtCurrent,'iterationDiagnostics',{iterationDiagnostics},'message',message);
            if isempty(J),solved.jacobian=lastUsableJacobian;else,solved.jacobian=J;end
            solved.jacobianReliable=jacobianReliable&&jacobianFreshAtCurrent;
        end

        function solved = runDampedNewton(obj, objective, safeObjective, ...
                jacobianFunction, u0, initialJacobian, observer)
            solved = obj.emptySolved();
            solved.solver = 'damped-newton';
            u = u0(:);
            lambda = obj.InitialDamping;
            trustRadius = obj.InitialTrustRadius;
            functionCount = 0;
            message = 'Maximum iteration count reached.';
            exitflag = 0;
            lastStep = Inf;
            firstOrder = Inf;
            iteration = 0;
            acceptedIterations = 0;
            invalidTrialCount = 0;
            initialJacobianUsed = false;
            J = initialJacobian;
            lastUsableJacobian = J;
            jacobianReliable = ~isempty(J);
            lastJacobianInfo = struct();

            try
                [r, valid, evaluationInfo] = safeObjective(u);
                functionCount = functionCount + 1;
                if ~valid
                    solved.state = u;
                    solved.message = 'Initial hybrid residual evaluation was invalid.';
                    solved.errorIdentifier = 'RootSolver_v3:InvalidInitialTrial';
                    return
                end
                if ~isempty(J) && (size(J, 1) ~= numel(r) || ...
                        size(J, 2) ~= numel(u) || any(~isfinite(J(:))))
                    J = [];
                    lastUsableJacobian = [];
                    jacobianReliable = false;
                end
                phi = 0.5 * real(r' * r);
                for iteration = 1:obj.MaxIterations
                    if norm(r, Inf) <= obj.FunctionTolerance
                        exitflag = 1;
                        message = 'Residual tolerance satisfied.';
                        break
                    end
                    % A validated supplied matrix must survive iteration 1.
                    % Subsequent refresh intervals and topology invalidation
                    % retain their existing behavior.
                    useInitialJacobian = iteration == 1 && ~isempty(J);
                    refreshJacobian = isempty(J) || (~useInitialJacobian && ...
                        (~obj.UseBroyden || ...
                        mod(acceptedIterations, obj.JacobianRefreshInterval) == 0));
                    initialJacobianUsed = initialJacobianUsed || useInitialJacobian;
                    if refreshJacobian
                        try
                            [J, lastJacobianInfo] = jacobianFunction(u, r);
                            lastUsableJacobian = J;
                            jacobianReliable = obj.jacobianInfoReliable( ...
                                lastJacobianInfo);
                        catch jacobianError
                            if isempty(J)
                                exitflag = -3;
                                message = ['Jacobian evaluation failed: ', ...
                                    jacobianError.message];
                                break
                            end
                            jacobianReliable = false;
                        end
                    end
                    if isempty(J) || any(~isfinite(J(:)))
                        exitflag = -3;
                        jacobianReliable = false;
                        message = 'No finite hybrid Jacobian is available in the requested perturbation chart.';
                        break
                    end
                    gradient = real(J' * r);
                    firstOrder = norm(gradient, Inf);
                    if firstOrder <= obj.OptimalityTolerance
                        exitflag = 3;
                        message = 'First-order optimality tolerance satisfied.';
                        break
                    end

                    normal = real(J' * J);
                    diagonal = max(abs(diag(normal)), 1);
                    assert(isreal(lambda) && isscalar(lambda) && isfinite(lambda) && lambda >= 0, ...
                        'RootSolver_v3:InitialDamping', 'LM damping must be finite, real and nonnegative.');
                    % The real step minimizes the identical complex-residual
                    % LM objective, without solving formed normal equations.
                    matrix = [real(J); imag(J); sqrt(lambda) * diag(sqrt(diagonal))];
                    rightHandSide = -[real(r(:)); imag(r(:)); zeros(size(J, 2), 1)];
                    step = matrix \ rightHandSide;
                    if any(~isfinite(step))
                        step = pinv(matrix) * rightHandSide;
                    end
                    stepNorm = norm(step);
                    if stepNorm > trustRadius
                        step = step .* (trustRadius / stepNorm);
                        stepNorm = trustRadius;
                    end
                    lastStep = stepNorm;
                    if stepNorm <= obj.StepTolerance * (1 + norm(u))
                        exitflag = 2;
                        message = 'Step tolerance satisfied.';
                        break
                    end

                    accepted = false;
                    alpha = 1;
                    for trial = 1:12
                        uTrial = u + alpha * step;
                        [rTrial, validTrial, trialInfo] = safeObjective(uTrial);
                        functionCount = functionCount + 1;
                        if ~validTrial
                            invalidTrialCount = invalidTrialCount + 1;
                            alpha = alpha / 2;
                            continue
                        end
                        phiTrial = 0.5 * real(rTrial' * rTrial);
                        if isfinite(phiTrial) && phiTrial < phi
                            acceptedStep = alpha * step;
                            oldResidual = r;
                            sameTopology = obj.topologyCompatible( ...
                                evaluationInfo, trialInfo);
                            u = uTrial;
                            r = rTrial;
                            evaluationInfo = trialInfo;
                            phi = phiTrial;
                            accepted = true;
                            acceptedIterations = acceptedIterations + 1;
                            observer(u,r,struct('iteration',iteration, ...
                                'algorithm','damped-newton','step',acceptedStep, ...
                                'damping',lambda,'trust_radius',trustRadius, ...
                                'line_search_fraction',alpha, ...
                                'jacobian_reliable',jacobianReliable));
                            if obj.UseBroyden && sameTopology && ...
                                    all(isfinite(acceptedStep))
                                % A tiny accepted step cannot support a
                                % stable rank-one update. Keep the current
                                % finite matrix instead of discarding it.
                                stepSquared = acceptedStep' * acceptedStep;
                                if stepSquared > eps
                                    correction = r - oldResidual - J * acceptedStep;
                                    J = J + correction * acceptedStep' / stepSquared;
                                    lastUsableJacobian = J;
                                end
                            else
                                J = [];
                                if ~sameTopology
                                    jacobianReliable = false;
                                end
                            end
                            lambda = max(lambda / 3, eps);
                            trustRadius = min(obj.MaximumTrustRadius, ...
                                max(trustRadius, 2 * alpha * stepNorm));
                            break
                        end
                        alpha = alpha / 2;
                    end
                    if ~accepted
                        lambda = min(lambda * 10, 1 / eps);
                        trustRadius = max(obj.MinimumTrustRadius, trustRadius / 2);
                        if trustRadius <= obj.MinimumTrustRadius
                            exitflag = -2;
                            message = 'Trust region collapsed without a decreasing step.';
                            break
                        end
                    end
                    if functionCount >= obj.MaxFunctionEvaluations
                        message = 'Maximum function-evaluation count reached.';
                        break
                    end
                end
            catch ME
                solved.state = u;
                if exist('r','var')&&~isempty(r)&&all(isfinite(r))
                    solved.residual = r(:);solved.residualNorm = norm(r,inf);
                end
                solved.message = ME.message;
                solved.errorIdentifier = ME.identifier;
                solved.output = struct('iterations',iteration, ...
                    'acceptedIterations',acceptedIterations, ...
                    'invalidTrialCount',invalidTrialCount,'jacobianInfo',lastJacobianInfo);
                return
            end

            solved.state = u;
            solved.residual = r(:);
            solved.residualNorm = norm(r, Inf);
            solved.exitflag = exitflag;
            solved.converged = exitflag > 0 && ...
                solved.residualNorm <= obj.ResidualAcceptanceTolerance;
            solved.message = message;
            solved.output = struct( ...
                'iterations', iteration, ...
                'funcCount', functionCount, ...
                'algorithm', 'damped Levenberg-Newton trust region', ...
                'firstorderopt', firstOrder, ...
                'stepsize', lastStep, ...
                'acceptedIterations', acceptedIterations, ...
                'invalidTrialCount', invalidTrialCount, ...
                'initialJacobianUsed', initialJacobianUsed, ...
                'jacobianInfo', lastJacobianInfo, ...
                'message', message);
            if isempty(J)
                solved.jacobian = lastUsableJacobian;
            else
                solved.jacobian = J;
            end
            solved.jacobianReliable = jacobianReliable;
        end

        function r = objectiveValue(obj, residual, u, p, q)
            [r, info] = obj.evaluateResidual(residual, u(:), p, q);
            r = r(:);
            if ~isnumeric(r) || any(~isfinite(r))
                error('RootSolver_v3:InvalidResidual', ...
                    'Residual values must be finite numeric values.');
            end
            if ~obj.infoIsValid(info)
                error('RootSolver_v3:InvalidHybridReturn', ...
                    'The hybrid return map reported an invalid trial.');
            end
        end

        function [r, info] = evaluateResidual( ...
                ~, residual, u, p, q, varargin)
            info = struct();
            if isa(residual, 'function_handle')
                [r, info] = RootSolver_v3.callResidualFunction( ...
                    residual, u, p, q, varargin{:});
                return
            end
            if isstruct(residual)
                if isfield(residual, 'evaluateWithInfo') && ...
                        isa(residual.evaluateWithInfo, 'function_handle')
                    [r, info] = RootSolver_v3.callResidualFunction( ...
                        residual.evaluateWithInfo, u, p, q, varargin{:});
                    return
                elseif isfield(residual, 'evaluate') && ...
                        isa(residual.evaluate, 'function_handle')
                    [r, info] = RootSolver_v3.callResidualFunction( ...
                        residual.evaluate, u, p, q, varargin{:});
                    return
                end
            end
            if ismethod(residual, 'evaluateWithInfo')
                if isempty(varargin)
                    [r, info] = RootSolver_v3.callObjectTwoOutput( ...
                        residual, 'evaluateWithInfo', u, p, q);
                else
                    [r, info] = residual.evaluateWithInfo( ...
                        u, p, q, varargin{:});
                end
            elseif ismethod(residual, 'evaluate')
                r = RootSolver_v3.callObjectOneOutput( ...
                    residual, 'evaluate', u, p, q);
            else
                error('RootSolver_v3:ResidualInterface', ...
                    'Residual must be a function handle or expose evaluate().');
            end
        end

        function tf = infoIsValid(~, info)
            tf = true;
            if isempty(info) || ~isstruct(info)
                return
            end
            fields = {'success', 'valid', 'admissible', ...
                'integration_success', 'integrationSuccess', ...
                'modeClosure', 'mode_closed', 'discrete_closed', ...
                'cycle_complete', 'cycleComplete', 'return_policy_accepted'};
            for i = 1:numel(fields)
                if isfield(info, fields{i}) && ...
                        isscalar(info.(fields{i})) && ~info.(fields{i})
                    tf = false;
                    return
                end
            end
        end

        function x = fullState(~, residual, u, p, q)
            x = u(:);
            if isempty(residual) || isa(residual, 'function_handle')
                return
            end
            try
                if isstruct(residual) && isfield(residual, 'fullState')
                    x = RootSolver_v3.callFunction( ...
                        residual.fullState, u, p, q);
                elseif ismethod(residual, 'fullState')
                    x = RootSolver_v3.callObjectOneOutput( ...
                        residual, 'fullState', u, p, q);
                end
            catch
                x = u(:);
            end
            x = x(:);
        end

        function orbit = createOrbit(~, residual, u, p, q, evalInfo)
            orbit = [];
            if isempty(residual) || isa(residual, 'function_handle')
                return
            end
            try
                if isstruct(residual) && isfield(residual, 'createOrbit')
                    fun = residual.createOrbit;
                    orbit = RootSolver_v3.callOrbitFunction( ...
                        fun, u, p, q, evalInfo);
                elseif ismethod(residual, 'createOrbit')
                    orbit = RootSolver_v3.callObjectOrbit( ...
                        residual, u, p, q, evalInfo);
                end
            catch exception
                rethrow(exception)
            end
        end

        function [candidates, diagnostics] = tryModeProvider(~, provider, x, q, p)
            candidates = {};
            diagnostics = {};
            if isempty(provider)
                return
            end
            try
                if isstruct(provider) && isfield(provider, 'modeCandidates')
                    fun = provider.modeCandidates;
                    try
                        [candidates, diagnostics] = ...
                            RootSolver_v3.callModeFunctionTwo(fun, x, q, p);
                    catch
                        candidates = RootSolver_v3.callModeFunction(fun, x, q, p);
                        diagnostics = candidates;
                    end
                elseif isobject(provider) && ismethod(provider, 'modeCandidates')
                    try
                        [candidates, diagnostics] = ...
                            RootSolver_v3.callObjectModesTwo(provider, x, q, p);
                    catch
                        candidates = RootSolver_v3.callObjectModes(provider, x, q, p);
                        diagnostics = candidates;
                    end
                end
            catch
                candidates = {};
                diagnostics = {};
            end
        end

        function diagnostics = appendModeDiagnostics(obj, diagnostics, ...
                candidates, defaultReason, source)
            normalized = obj.normalizeModes(candidates, []);
            if isstruct(candidates) && isfield(candidates, 'mode')
                normalized = arrayfun(@(entry) entry.mode, candidates, ...
                    'UniformOutput', false);
            end
            for index = 1:numel(normalized)
                reason = defaultReason;
                candidateSource = source;
                if isstruct(candidates) && numel(candidates) >= index
                    if isfield(candidates, 'reason') && ...
                            ~isempty(candidates(index).reason)
                        reason = char(string(candidates(index).reason));
                    end
                    if isfield(candidates, 'source') && ...
                            ~isempty(candidates(index).source)
                        candidateSource = char(string(candidates(index).source));
                    end
                end
                diagnostics(end + 1) = struct( ... %#ok<AGROW>
                    'mode', normalized{index}, 'reason', reason, ...
                    'source', candidateSource);
            end
        end

        function diagnostics = uniqueModeDiagnostics(~, diagnostics, modes)
            output = repmat(struct('mode', [], 'reason', '', 'source', ''), ...
                1, 0);
            for modeIndex = 1:numel(modes)
                match = [];
                for diagnosticIndex = 1:numel(diagnostics)
                    if isequaln(diagnostics(diagnosticIndex).mode, modes{modeIndex})
                        match = diagnosticIndex;
                        break
                    end
                end
                if isempty(match)
                    output(end + 1) = struct('mode', modes{modeIndex}, ... %#ok<AGROW>
                        'reason', 'candidate mode', 'source', 'unknown');
                else
                    output(end + 1) = diagnostics(match); %#ok<AGROW>
                end
            end
            diagnostics = output;
        end

        function scale = resolveScale(~, supplied, reference, name)
            reference = reference(:);
            if isempty(reference)
                scale = zeros(0, 1);
                return
            end
            if isempty(supplied)
                scale = 1 + abs(reference);
            else
                scale = supplied(:);
                if isscalar(scale)
                    scale = repmat(scale, numel(reference), 1);
                end
                if numel(scale) ~= numel(reference) || ...
                        any(~isfinite(scale)) || any(scale <= 0)
                    error('RootSolver_v3:Scale', ...
                        '%s must be positive and match its vector.', name);
                end
            end
        end

        function reliable = jacobianInfoReliable(~, info)
            reliable = true;
            if isempty(info) || ~isstruct(info)
                return
            end
            if isfield(info, 'allReliable')
                reliable = logical(info.allReliable);
            elseif isfield(info, 'success')
                reliable = logical(info.success);
            end
        end

        function compatible = topologyCompatible(obj, left, right)
            compatible = obj.infoIsValid(left) && obj.infoIsValid(right);
            if ~compatible || ~isstruct(left) || ~isstruct(right)
                return
            end
            multiplicityFields = {'return_multiplicity', 'returnMultiplicity'};
            [leftMultiplicity, leftPresent] = obj.firstPresent( ...
                left, multiplicityFields);
            [rightMultiplicity, rightPresent] = obj.firstPresent( ...
                right, multiplicityFields);
            if xor(leftPresent, rightPresent) || ...
                    (leftPresent && rightPresent && ...
                     ~isequal(leftMultiplicity, rightMultiplicity))
                compatible = false;
                return
            end
            signatureGroups = { ...
                {'cyclic_event_signature', 'cyclicEventSignature', ...
                 'cycle_signature', 'cycleSignature'}, ...
                {'section_relative_event_signature', ...
                 'sectionRelativeEventSignature', ...
                 'section_event_signature', 'sectionEventSignature'}, ...
                {'event_cluster_signature', 'eventClusterSignature', ...
                 'cluster_signature', 'clusterSignature'}};
            for groupIndex = 1:numel(signatureGroups)
                fields = signatureGroups{groupIndex};
                [leftValue, leftPresent] = obj.firstPresent(left, fields);
                [rightValue, rightPresent] = obj.firstPresent(right, fields);
                if xor(leftPresent, rightPresent) || ...
                        (leftPresent && rightPresent && ...
                         ~isequal(string(leftValue), string(rightValue)))
                    compatible = false;
                    return
                end
            end
        end

        function name = derivativeModelName(obj)
            if isa(obj.Jacobian, 'HybridFiniteDifferenceJacobian_v3')
                name = 'hybrid-topology-compatible-finite-difference';
            elseif isa(obj.Jacobian, 'FiniteDifferenceJacobian_v3')
                name = 'ordinary-finite-difference';
            else
                name = class(obj.Jacobian);
            end
        end

        function value = outputMember(~, source, name, defaultValue)
            value = defaultValue;
            if isstruct(source) && isfield(source, name)
                value = source.(name);
            end
        end

        function value = infoMember(obj, source, names, defaultValue)
            [value, present] = obj.firstPresent(source, names);
            if ~present
                value = defaultValue;
            end
        end

        function [value, present] = firstPresent(~, source, names)
            value = [];
            present = false;
            if ~isstruct(source)
                return
            end
            for index = 1:numel(names)
                if isfield(source, names{index})
                    value = source.(names{index});
                    present = true;
                    return
                end
            end
        end

        function value = getMember(~, source, name)
            value = [];
            if isempty(source)
                return
            end
            if isstruct(source) && isfield(source, name)
                value = source.(name);
            elseif isobject(source) && isprop(source, name)
                value = source.(name);
            end
        end

        function tf = hasModeProvider(~, provider)
            tf = (~isempty(provider) && isobject(provider) ...
                    && ismethod(provider, 'modeCandidates')) ...
                || (isstruct(provider) ...
                    && isfield(provider, 'modeCandidates'));
        end

        function modes = appendModes(obj, modes, candidates, q0)
            normalized = obj.normalizeModes(candidates, q0);
            modes = [modes, normalized];
        end

        function modes = normalizeModes(~, candidates, q0)
            modes = {};
            if isempty(candidates)
                return
            end
            if iscell(candidates)
                modes = reshape(candidates, 1, []);
                return
            end
            if isstruct(candidates)
                if isfield(candidates, 'mode')
                    modes = arrayfun(@(s) s.mode, candidates, ...
                        'UniformOutput', false);
                end
                return
            end
            if ~(isnumeric(candidates) || islogical(candidates) || ...
                    ischar(candidates) || isstring(candidates))
                return
            end
            if isempty(q0) || isscalar(q0)
                if isvector(candidates) && numel(candidates) > 1
                    modes = num2cell(candidates(:).');
                else
                    modes = {candidates};
                end
            elseif ismatrix(candidates) && size(candidates, 2) == numel(q0)
                modes = mat2cell(candidates, ones(1, size(candidates, 1)), ...
                    size(candidates, 2));
                modes = reshape(modes, 1, []);
            elseif ismatrix(candidates) && size(candidates, 1) == numel(q0)
                modes = mat2cell(candidates, size(candidates, 1), ...
                    ones(1, size(candidates, 2)));
            else
                modes = {candidates};
            end
        end

        function modes = uniqueModes(~, modes)
            keep = true(1, numel(modes));
            for i = 1:numel(modes)
                for j = 1:i-1
                    if keep(j) && isequaln(modes{i}, modes{j})
                        keep(i) = false;
                        break
                    end
                end
            end
            modes = modes(keep);
        end

        function attempt = emptyAttempt(~)
            attempt = struct( ...
                'state', [], 'fullState', [], 'parameter', [], 'mode', [], ...
                'residual', [], 'residualNorm', Inf, 'exitflag', -Inf, ...
                'output', struct(), 'solver', '', 'message', '', ...
                'errorIdentifier', '', 'converged', false, ...
                'evaluationInfo', struct(), 'orbit', [], ...
                'attempts', [], 'candidateModes', {{}}, ...
                'selectedAttempt', [], 'initialGuess', [], ...
                'modeResolution', struct([]), 'selectedMode', [], ...
                'rejectedModeDiagnostics', struct([]), ...
                'stateScale', [], 'parameterScale', [], ...
                'functionEvaluationCount', 0, 'mapEvaluationCount', 0, ...
                'cacheHitCount', 0, 'invalidEvaluationCount', 0, ...
                'jacobianEvaluationCount', 0, 'finalJacobian', [], ...
                'fsolveOptions', struct(), 'fsolveFailure', struct(), ...
                'invalidEvaluationDiagnostics', {{}}, ...
                'jacobianReliable', false, ...
                'derivativeModel', '', 'derivativeEvaluated', false, ...
                'acceptedNewtonIterations', 0, ...
                'invalidTrialCount', 0, 'jacobianDiagnostics', struct(), ...
                'selectedFiniteDifferenceSteps', [], ...
                'perColumnReliability', [], ...
                'primaryConverged', false, 'primaryMessage', '', ...
                'primaryErrorIdentifier', '', 'primaryExitflag', -Inf, ...
                'finalizationMessage', '', 'finalizationErrorIdentifier', '', ...
                'cyclicEventSignature', '', ...
                'sectionRelativeSignature', '', ...
                'eventClusterSignature', '');
            attempt.status = 'not_started';
            attempt.iterationJournal = struct([]);
            attempt.lastAcceptedIterate = struct();
            attempt.lastFiniteEvaluatedBase = struct();
            attempt.originalSeedFallback = [];
            attempt.fallbackSource = 'original-seed';
        end

        function status = failureStatus(~,identifier,stage)
            if contains(identifier,'Budget')
                status = 'budget_refusal';
            elseif contains(identifier,'Jacobian')||contains(identifier,'Derivative')
                status = 'derivative_failure';
            elseif strcmp(stage,'initial-residual')
                status = 'invalid_initial_return';
            elseif contains(identifier,'FullClosure')
                status = 'failed_full_closure';
            else
                status = 'invalid_trial_during_correction';
            end
        end

        function solved = emptySolved(~)
            solved = struct( ...
                'state', [], 'residual', [], 'residualNorm', Inf, ...
                'exitflag', -Inf, 'output', struct(), 'solver', '', ...
                'message', '', 'errorIdentifier', '', 'converged', false, ...
                'jacobian', [], 'jacobianReliable', false, 'fsolveOptions', struct());
        end

        function obj = applyOptions(obj, options)
            names = fieldnames(options);
            for i = 1:numel(names)
                obj = obj.setOption(names{i}, options.(names{i}));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin), 2) ~= 0
                error('RootSolver_v3:NameValue', ...
                    'Options must be supplied as name/value pairs.');
            end
            for i = 1:2:numel(varargin)
                obj = obj.setOption(varargin{i}, varargin{i + 1});
            end
        end

        function obj = setOption(obj, name, value)
            list = properties(obj);
            match = find(strcmpi(char(name), list), 1);
            if isempty(match)
                error('RootSolver_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(list{match}) = value;
        end

        function validateOptions(obj)
            for name = {'FsolveAlgorithm','FsolveScaleProblem'}
                value = obj.(name{1});
                if ~((ischar(value) && (isempty(value) || isrow(value))) ...
                        || (isstring(value) && isscalar(value)))
                    error('RootSolver_v3:FsolveOptions', '%s must be scalar text.', name{1});
                end
            end
            fsolveAlgorithm = lower(char(obj.FsolveAlgorithm));
            fsolveScaling = lower(char(obj.FsolveScaleProblem));
            if ~any(strcmp(fsolveAlgorithm, {'','trust-region-dogleg','trust-region','levenberg-marquardt'})) ...
                    || ~any(strcmp(fsolveScaling, {'','none','jacobian'}))
                error('RootSolver_v3:FsolveOptions', 'Unknown fsolve algorithm or scaling policy.');
            end
            if ~isempty(obj.FsolveInitialDamping) && ...
                    ~(isnumeric(obj.FsolveInitialDamping) && isreal(obj.FsolveInitialDamping) ...
                    && isscalar(obj.FsolveInitialDamping) && isfinite(obj.FsolveInitialDamping) ...
                    && obj.FsolveInitialDamping > 0)
                error('RootSolver_v3:FsolveOptions', 'FsolveInitialDamping must be empty or a finite positive scalar.');
            end
            if (~isempty(obj.FsolveInitialDamping) || strcmp(fsolveScaling,'jacobian')) ...
                    && ~strcmp(fsolveAlgorithm,'levenberg-marquardt')
                error('RootSolver_v3:FsolveOptions', 'Damping and Jacobian scaling require explicit levenberg-marquardt.');
            end
            if ~any(strcmpi(obj.Algorithm, {'auto', 'fsolve', 'newton', 'root-newton'}))
                error('RootSolver_v3:Algorithm', ...
                    'Algorithm must be auto, fsolve, newton, or root-newton.');
            end
            if strcmpi(obj.Algorithm,'root-newton')
                for rootName={'FunctionTolerance','ResidualAcceptanceTolerance','StepTolerance'}
                    value=obj.(rootName{1});
                    if ~(isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value)&&value>0)
                        error('RootSolver_v3:RootNewtonOptions','%s must be a finite positive scalar for root-newton.',rootName{1});
                    end
                end
                for rootName={'MaxIterations','MaxFunctionEvaluations','JacobianRefreshInterval'}
                    value=obj.(rootName{1});
                    if ~(isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value)&&value>=1&&value==fix(value))
                        error('RootSolver_v3:RootNewtonOptions','%s must be a finite positive integer for root-newton.',rootName{1});
                    end
                end
            end
            if obj.FunctionTolerance <= 0 || obj.StepTolerance <= 0 || ...
                    obj.MaxIterations < 1 || obj.MaxFunctionEvaluations < 1 ...
                    || ~(isscalar(obj.MaxWallSeconds) && obj.MaxWallSeconds > 0)
                error('RootSolver_v3:Options', ...
                    'Solver tolerances and limits must be positive.');
            end
            if ~(isnumeric(obj.RootNewtonMinimumRcond)&&isreal(obj.RootNewtonMinimumRcond)&&isscalar(obj.RootNewtonMinimumRcond)&&isfinite(obj.RootNewtonMinimumRcond)&&obj.RootNewtonMinimumRcond>0&&obj.RootNewtonMinimumRcond<1)
                error('RootSolver_v3:RootNewtonMinimumRcond','RootNewtonMinimumRcond must be finite and strictly between0 and1.');
            end
            if obj.JacobianRefreshInterval < 1 || ...
                    obj.JacobianRefreshInterval ~= floor(obj.JacobianRefreshInterval)
                error('RootSolver_v3:JacobianRefreshInterval', ...
                    'JacobianRefreshInterval must be a positive integer.');
            end
        end
    end

    methods (Static, Access = private)
        function [value, info] = callResidualFunction( ...
                fun, u, p, q, varargin)
            info = struct();
            n = nargin(fun);
            if n == 1
                arguments = {u};
            elseif n == 2
                arguments = {u, p};
            elseif n == 3
                arguments = {u, p, q};
            elseif n >= 4
                if isempty(varargin)
                    arguments = {u, p, q, struct()};
                else
                    arguments = {u, p, q, varargin{:}};
                end
            else
                arguments = {u, p, q, varargin{:}};
            end
            try
                [value, info] = fun(arguments{:});
            catch exception
                if ~RootSolver_v3.tooManyOutputs(exception)
                    rethrow(exception)
                end
                value = fun(arguments{:});
                info = struct();
            end
        end

        function value = callFunction(fun, u, p, q)
            n = nargin(fun);
            if n == 1
                value = fun(u);
            elseif n == 2
                value = fun(u, p);
            else
                value = fun(u, p, q);
            end
        end

        function tf = tooManyOutputs(exception)
            tf = any(strcmp(exception.identifier, { ...
                'MATLAB:maxlhs', 'MATLAB:TooManyOutputs', ...
                'MATLAB:unassignedOutputs', 'MATLAB:needMoreRhsOutputs'}));
        end

        function [value, info] = callTwoOutput(fun, u, p, q)
            n = nargin(fun);
            if n == 1
                [value, info] = fun(u);
            elseif n == 2
                [value, info] = fun(u, p);
            else
                [value, info] = fun(u, p, q);
            end
        end

        function value = callObjectOneOutput(object, method, u, p, q)
            try
                value = RootSolver_v3.invokeOne(object, method, u, p, q);
            catch firstError
                try
                    value = RootSolver_v3.invokeOne(object, method, u, p);
                catch
                    try
                        value = RootSolver_v3.invokeOne(object, method, u);
                    catch
                        rethrow(firstError)
                    end
                end
            end
        end

        function [value, info] = callObjectTwoOutput(object, method, u, p, q)
            try
                [value, info] = RootSolver_v3.invokeTwo( ...
                    object, method, u, p, q);
            catch firstError
                try
                    [value, info] = RootSolver_v3.invokeTwo( ...
                        object, method, u, p);
                catch
                    try
                        [value, info] = RootSolver_v3.invokeTwo( ...
                            object, method, u);
                    catch
                        rethrow(firstError)
                    end
                end
            end
        end

        function orbit = callOrbitFunction(fun, u, p, q, info)
            n = nargin(fun);
            if n <= 3 && n >= 0
                orbit = RootSolver_v3.callFunction(fun, u, p, q);
            else
                orbit = fun(u, p, q, info);
            end
        end

        function orbit = callObjectOrbit(object, u, p, q, info)
            try
                orbit = object.createOrbit(u, p, q, info);
            catch firstError
                try
                    orbit = object.createOrbit(u, p, q);
                catch
                    try
                        orbit = object.createOrbit(u, p);
                    catch
                        rethrow(firstError)
                    end
                end
            end
        end

        function modes = callModeFunction(fun, x, q, p)
            n = nargin(fun);
            if n == 1
                modes = fun(x);
            elseif n == 2
                modes = fun(x, q);
            else
                modes = fun(x, q, p);
            end
        end

        function [modes, diagnostics] = callModeFunctionTwo(fun, x, q, p)
            n = nargin(fun);
            if n == 1
                [modes, diagnostics] = fun(x);
            elseif n == 2
                [modes, diagnostics] = fun(x, q);
            else
                [modes, diagnostics] = fun(x, q, p);
            end
        end

        function modes = callObjectModes(object, x, q, p)
            try
                modes = object.modeCandidates(x, q, p);
            catch firstError
                try
                    modes = object.modeCandidates(q, x, p);
                catch
                    try
                        modes = object.modeCandidates(x, p, q);
                    catch
                        rethrow(firstError)
                    end
                end
            end
        end

        function [modes, diagnostics] = callObjectModesTwo(object, x, q, p)
            try
                [modes, diagnostics] = object.modeCandidates(x, q, p);
            catch firstError
                try
                    [modes, diagnostics] = object.modeCandidates(q, x, p);
                catch
                    try
                        [modes, diagnostics] = object.modeCandidates(x, p, q);
                    catch
                        rethrow(firstError)
                    end
                end
            end
        end

        function value = invokeOne(object, method, varargin)
            switch method
                case 'evaluate'
                    value = object.evaluate(varargin{:});
                case 'fullState'
                    value = object.fullState(varargin{:});
                otherwise
                    error('RootSolver_v3:InternalMethod', ...
                        'Unsupported object method "%s".', method);
            end
        end

        function [value, info] = invokeTwo(object, method, varargin)
            switch method
                case 'evaluateWithInfo'
                    [value, info] = object.evaluateWithInfo(varargin{:});
                otherwise
                    error('RootSolver_v3:InternalMethod', ...
                        'Unsupported two-output method "%s".', method);
            end
        end
    end
end
