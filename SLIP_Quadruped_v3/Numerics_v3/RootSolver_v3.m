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
    end

    methods
        function obj = RootSolver_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            if isempty(obj.Jacobian)
                obj.Jacobian = FiniteDifferenceJacobian_v3( ...
                    'Method', 'forward');
            end
            obj.validateOptions();
        end

        function [u, result] = solve(obj, residual, u0, p, q0)
            if nargin < 5
                q0 = [];
            end
            u0 = u0(:);
            p = p(:);
            modes = obj.candidateModes(residual, u0, p, q0);
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
        end

        function [u, fval, exitflag, output, q, result] = ...
                solveFsolveStyle(obj, residual, u0, p, q0)
            [u, result] = obj.solve(residual, u0, p, q0);
            fval = result.residual;
            exitflag = result.exitflag;
            output = result.output;
            q = result.mode;
        end

        function modes = candidateModes(obj, residual, u, p, q0)
            modes = {q0};
            modes = obj.appendModes(modes, obj.ModeCandidates, q0);

            % A residual may own chart-specific mode-candidate logic.
            candidates = obj.tryModeProvider(residual, u, q0, p);
            modes = obj.appendModes(modes, candidates, q0);

            % Otherwise query the hybrid system using a reconstructed state.
            map = obj.getMember(residual, 'Map');
            system = obj.getMember(map, 'System');
            if ~isempty(system)
                x = obj.fullState(residual, u, p, q0);
                candidates = obj.tryModeProvider(system, x, q0, p);
                modes = obj.appendModes(modes, candidates, q0);
            end
            modes = obj.uniqueModes(modes);
        end
    end

    methods (Access = private)
        function attempt = solveOne(obj, residual, u0, p, q)
            attempt = obj.emptyAttempt();
            attempt.mode = q;
            attempt.state = u0;
            objective = @(u) obj.objectiveValue(residual, u, p, q);

            try
                r0 = objective(u0);
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
            if any(strcmp(algorithm, {'auto', 'fsolve'})) && ...
                    exist('fsolve', 'file') == 2
                candidates{end + 1} = obj.runFsolve(objective, u0);
            end
            if strcmp(algorithm, 'newton') || strcmp(algorithm, 'auto') || ...
                    isempty(candidates)
                newtonStart = u0;
                if ~isempty(candidates) && ...
                        all(isfinite(candidates{end}.state))
                    newtonStart = candidates{end}.state;
                end
                candidates{end + 1} = obj.runDampedNewton(objective, newtonStart);
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

            attempt.state = solved.state;
            attempt.residual = solved.residual;
            attempt.residualNorm = solved.residualNorm;
            attempt.exitflag = solved.exitflag;
            attempt.output = solved.output;
            attempt.solver = solved.solver;
            attempt.message = solved.message;
            attempt.errorIdentifier = solved.errorIdentifier;
            attempt.converged = solved.converged && ...
                solved.residualNorm <= obj.ResidualAcceptanceTolerance;

            try
                [~, evalInfo] = obj.evaluateResidual( ...
                    residual, attempt.state, p, q);
                attempt.evaluationInfo = evalInfo;
                if ~obj.infoIsValid(evalInfo)
                    attempt.converged = false;
                    attempt.message = 'Residual evaluation reported an invalid hybrid return.';
                end
                attempt.fullState = obj.fullState( ...
                    residual, attempt.state, p, q);
                attempt.orbit = obj.createOrbit( ...
                    residual, attempt.state, p, q, evalInfo);
            catch ME
                attempt.converged = false;
                attempt.message = ME.message;
                attempt.errorIdentifier = ME.identifier;
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

        function solved = runDampedNewton(obj, objective, u0)
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

            try
                r = objective(u);
                functionCount = functionCount + 1;
                phi = 0.5 * real(r' * r);
                for iteration = 1:obj.MaxIterations
                    if norm(r, Inf) <= obj.FunctionTolerance
                        exitflag = 1;
                        message = 'Residual tolerance satisfied.';
                        break
                    end
                    [J, ~, fdInfo] = obj.Jacobian.compute(objective, u);
                    functionCount = functionCount + fdInfo.evaluations;
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
                        rTrial = objective(uTrial);
                        functionCount = functionCount + 1;
                        phiTrial = 0.5 * real(rTrial' * rTrial);
                        if isfinite(phiTrial) && phiTrial < phi
                            u = uTrial;
                            r = rTrial;
                            phi = phiTrial;
                            accepted = true;
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
                'message', message);
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

        function [r, info] = evaluateResidual(~, residual, u, p, q)
            info = struct();
            if isa(residual, 'function_handle')
                r = RootSolver_v3.callFunction(residual, u, p, q);
                return
            end
            if isstruct(residual)
                if isfield(residual, 'evaluateWithInfo') && ...
                        isa(residual.evaluateWithInfo, 'function_handle')
                    [r, info] = RootSolver_v3.callTwoOutput( ...
                        residual.evaluateWithInfo, u, p, q);
                    return
                elseif isfield(residual, 'evaluate') && ...
                        isa(residual.evaluate, 'function_handle')
                    r = RootSolver_v3.callFunction(residual.evaluate, u, p, q);
                    return
                end
            end
            if ismethod(residual, 'evaluateWithInfo')
                [r, info] = RootSolver_v3.callObjectTwoOutput( ...
                    residual, 'evaluateWithInfo', u, p, q);
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
            fields = {'success', 'valid', 'modeClosure', 'mode_closed'};
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
            catch
                orbit = [];
            end
        end

        function candidates = tryModeProvider(~, provider, x, q, p)
            candidates = {};
            if isempty(provider)
                return
            end
            try
                if isstruct(provider) && isfield(provider, 'modeCandidates')
                    fun = provider.modeCandidates;
                    candidates = RootSolver_v3.callModeFunction(fun, x, q, p);
                elseif isobject(provider) && ismethod(provider, 'modeCandidates')
                    candidates = RootSolver_v3.callObjectModes(provider, x, q, p);
                end
            catch
                candidates = {};
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
                'selectedAttempt', [], 'initialGuess', []);
        end

        function solved = emptySolved(~)
            solved = struct( ...
                'state', [], 'residual', [], 'residualNorm', Inf, ...
                'exitflag', -Inf, 'output', struct(), 'solver', '', ...
                'message', '', 'errorIdentifier', '', 'converged', false);
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
        end
    end

    methods (Static, Access = private)
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
