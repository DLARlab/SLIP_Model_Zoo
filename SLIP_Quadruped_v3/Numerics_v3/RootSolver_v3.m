classdef RootSolver_v3
    %ROOTSOLVER_V3 Solve a continuous residual with discrete-mode closure.
    %   RESULT = SOLVE(SOLVER, RESIDUAL, U0, P, Q0) tries Q0 and any
    %   neighboring modes exposed by RESIDUAL or RESIDUAL.Map.System.  Each
    %   mode is a separate continuous solve; a discrete mode is never passed
    %   to fsolve as a numerical unknown.

    properties
        Algorithm = 'auto'            % 'auto', 'fsolve', or 'newton'
        Display = 'off'
        FunctionTolerance = 1e-9
        StepTolerance = 1e-10
        OptimalityTolerance = 1e-9
        MaxIterations = 150
        MaxFunctionEvaluations = 5000
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
        ReuseJacobian = false
        InitialJacobian = []
        UseBroyden = false
        JacobianRefreshInterval = 5
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

            try
                r0 = cachedObjective(scaledInitial);
                if obj.RequireSquare && numel(r0) ~= numel(u0)
                    error('RootSolver_v3:NonSquareResidual', ...
                        ['The residual has %d equations for %d continuous ' ...
                         'unknowns. Use a reduced section chart or disable ' ...
                         'RequireSquare explicitly.'], numel(r0), numel(u0));
                end
            catch ME
                attempt.message = ME.message;
                attempt.errorIdentifier = ME.identifier;
                return
            end

            algorithm = lower(char(obj.Algorithm));
            candidates = {};
            if norm(r0, Inf) <= obj.ResidualAcceptanceTolerance
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
                candidates{end + 1} = obj.runFsolve( ...
                    @fsolveObjective, scaledInitial);
            end
            if norm(r0, Inf) > obj.ResidualAcceptanceTolerance && ...
                    (strcmp(algorithm, 'newton') ...
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
                candidates{end + 1} = obj.runDampedNewton( ...
                    @cachedObjective, @safeObjective, @jacobianAt, ...
                    newtonStart, initialJacobian);
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
            attempt.solver = solved.solver;
            attempt.message = solved.message;
            attempt.errorIdentifier = solved.errorIdentifier;
            attempt.converged = solved.converged && ...
                solved.residualNorm <= obj.ResidualAcceptanceTolerance;
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
                attempt.finalJacobian = solved.jacobian * diag(1 ./ stateScale);
            end

            try
                [~, validReturn, evalInfo] = safeObjective( ...
                    attempt.state ./ stateScale);
                attempt.evaluationInfo = evalInfo;
                if ~validReturn
                    attempt.converged = false;
                    attempt.message = 'Residual evaluation reported an invalid hybrid return.';
                end
                if isstruct(evalInfo) && isfield(evalInfo,'full_physical_closure_norm')
                    tolerance = obj.getMember(residual,'ClosureTolerance');
                    if isempty(tolerance),tolerance=obj.ResidualAcceptanceTolerance;end
                    if ~isfinite(evalInfo.full_physical_closure_norm) || ...
                            evalInfo.full_physical_closure_norm > tolerance
                        attempt.converged=false;
                        attempt.message='Independent residual passed but full physical closure failed.';
                    end
                end
                attempt.fullState = obj.fullState( ...
                    residual, attempt.state, p, q);
                attempt.orbit = obj.createOrbit( ...
                    residual, attempt.state, p, q, evalInfo);
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
                attempt.message = ME.message;
                attempt.errorIdentifier = ME.identifier;
            end
            attempt.functionEvaluationCount = functionEvaluations;
            attempt.mapEvaluationCount = mapEvaluations;
            attempt.cacheHitCount = cacheHits;
            attempt.invalidEvaluationCount = invalidEvaluations;
            attempt.jacobianEvaluationCount = jacobianEvaluations;

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

            function [r, valid, info] = safeObjective(scaledState, varargin)
                [r, valid, info] = evaluateScaled(scaledState, varargin{:});
            end

            function [r, J] = fsolveObjective(scaledState)
                r = cachedObjective(scaledState);
                if nargout > 1
                    [J, ~] = jacobianAt(scaledState, r);
                end
            end

            function [J, fdInfo] = jacobianAt(scaledState, baseline)
                jacobianEvaluations = jacobianEvaluations + 1;
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
            end

            function [r, metadata] = hybridObjective(scaledState, varargin)
                [r, valid, metadata] = safeObjective( ...
                    scaledState, varargin{:});
                if isempty(metadata) || ~isstruct(metadata)
                    metadata = struct();
                end
                metadata.valid = valid;
                metadata.integration_success = valid;
            end

            function [r, valid, info, errorIdentifier, message] = ...
                    evaluateScaled(scaledState, varargin)
                functionEvaluations = functionEvaluations + 1;
                scaledState = scaledState(:);
                key = sprintf('%.17g,', scaledState);
                if obj.EnableMapCache && isKey(cache, key)
                    record = cache(key);
                    cacheHits = cacheHits + 1;
                else
                    record = struct('residual', [], 'info', struct(), ...
                        'valid', false, 'errorIdentifier', '', 'message', '');
                    mapEvaluations = mapEvaluations + 1;
                    physicalState = scaledState .* stateScale;
                    try
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
                    end
                    if obj.EnableMapCache
                        cache(key) = record;
                    end
                end
                r = record.residual;
                valid = record.valid;
                info = record.info;
                errorIdentifier = record.errorIdentifier;
                message = record.message;
                if ~valid
                    invalidEvaluations = invalidEvaluations + 1;
                    if isempty(message)
                        message = 'Invalid hybrid residual evaluation.';
                    end
                end
            end
        end

        function solved = runFsolve(obj, objective, u0)
            solved = obj.emptySolved();
            solved.solver = 'fsolve';
            try
                options = optimset( ...
                    'Display', obj.Display, ...
                    'TolFun', obj.FunctionTolerance, ...
                    'TolX', obj.StepTolerance, ...
                    'MaxIter', obj.MaxIterations, ...
                    'MaxFunEvals', obj.MaxFunctionEvaluations);
                if obj.ProvideJacobianToFsolve
                    options = optimset(options, 'Jacobian', 'on');
                end
                [u, fval, exitflag, output] = fsolve(objective, u0, options);
                solved.state = u(:);
                solved.residual = fval(:);
                solved.residualNorm = norm(fval(:), Inf);
                solved.exitflag = exitflag;
                solved.output = output;
                solved.converged = exitflag > 0 && ...
                    solved.residualNorm <= obj.ResidualAcceptanceTolerance;
                if isfield(output, 'message')
                    solved.message = output.message;
                end
            catch ME
                solved.state = u0;
                solved.message = ME.message;
                solved.errorIdentifier = ME.identifier;
            end
        end

        function solved = runDampedNewton(obj, objective, safeObjective, ...
                jacobianFunction, u0, initialJacobian)
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
                if ~isempty(J) && size(J, 1) ~= numel(r)
                    J = [];
                    jacobianReliable = false;
                end
                phi = 0.5 * real(r' * r);
                for iteration = 1:obj.MaxIterations
                    if norm(r, Inf) <= obj.FunctionTolerance
                        exitflag = 1;
                        message = 'Residual tolerance satisfied.';
                        break
                    end
                    refreshJacobian = isempty(J) || ~obj.UseBroyden || ...
                        mod(acceptedIterations, obj.JacobianRefreshInterval) == 0;
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
                    matrix = normal + lambda * diag(diagonal);
                    step = -matrix \ gradient;
                    if any(~isfinite(step))
                        step = -pinv(matrix) * gradient;
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
                            if obj.UseBroyden && sameTopology && ...
                                    all(isfinite(acceptedStep)) && ...
                                    acceptedStep' * acceptedStep > eps
                                correction = r - oldResidual - J * acceptedStep;
                                J = J + correction * acceptedStep' / ...
                                    (acceptedStep' * acceptedStep);
                                lastUsableJacobian = J;
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
                solved.message = ME.message;
                solved.errorIdentifier = ME.identifier;
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
                'jacobianReliable', false, ...
                'derivativeModel', '', 'derivativeEvaluated', false, ...
                'acceptedNewtonIterations', 0, ...
                'invalidTrialCount', 0, 'jacobianDiagnostics', struct(), ...
                'selectedFiniteDifferenceSteps', [], ...
                'perColumnReliability', [], ...
                'cyclicEventSignature', '', ...
                'sectionRelativeSignature', '', ...
                'eventClusterSignature', '');
        end

        function solved = emptySolved(~)
            solved = struct( ...
                'state', [], 'residual', [], 'residualNorm', Inf, ...
                'exitflag', -Inf, 'output', struct(), 'solver', '', ...
                'message', '', 'errorIdentifier', '', 'converged', false, ...
                'jacobian', [], 'jacobianReliable', false);
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
            if ~any(strcmpi(obj.Algorithm, {'auto', 'fsolve', 'newton'}))
                error('RootSolver_v3:Algorithm', ...
                    'Algorithm must be auto, fsolve, or newton.');
            end
            if obj.FunctionTolerance <= 0 || obj.StepTolerance <= 0 || ...
                    obj.MaxIterations < 1 || obj.MaxFunctionEvaluations < 1
                error('RootSolver_v3:Options', ...
                    'Solver tolerances and limits must be positive.');
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
                'MATLAB:unassignedOutputs'}));
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
