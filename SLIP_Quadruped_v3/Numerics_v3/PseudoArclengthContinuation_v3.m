classdef PseudoArclengthContinuation_v3
    %PSEUDOARCLENGTHCONTINUATION_V3 One-parameter predictor/corrector.
    %   For u in R^m and one active scalar parameter mu, the corrector is
    %
    %       [ R(u,p(mu));
    %         t' * (([u;mu]-[u0;mu0])./scale) - ds ] = 0.
    %
    %   The tangent is the one-dimensional null vector of the finite-
    %   difference Jacobian of R with respect to [u;mu].  The full seven-
    %   parameter model vector is retained, but only one scalar parameter is
    %   freed; otherwise the displayed system would be underdetermined.

    properties
        RootSolver = []
        Jacobian = []
        ActiveParameterIndex = 1
        StepSize = 0.02
        MinimumStepSize = 1e-5
        MaximumStepSize = 0.2
        StepGrowth = 1.25
        StepShrink = 0.5
        MaxPoints = 100
        InitialDirection = 1
        InitialTangent = []
        AutoScale = true
        Scale = []
        ParameterBounds = [-Inf, Inf]
        ComputeStability = false
        StabilityAnalyzer = []
        Display = 'off'
    end

    methods
        function obj = PseudoArclengthContinuation_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            if isempty(obj.RootSolver)
                obj.RootSolver = RootSolver_v3();
            end
            if isempty(obj.Jacobian)
                obj.Jacobian = FiniteDifferenceJacobian_v3( ...
                    'Method', 'forward');
            end
            obj.validateOptions();
        end

        function branch = run(obj, residual, u0, p0, q0)
            pReference = p0(:);
            index = obj.ActiveParameterIndex;
            if index < 1 || index > numel(pReference) || index ~= floor(index)
                error('PseudoArclengthContinuation_v3:ParameterIndex', ...
                    'ActiveParameterIndex is outside the parameter vector.');
            end

            [u, initialSolve] = obj.RootSolver.solve( ...
                residual, u0(:), pReference, q0);
            if ~initialSolve.converged
                error('PseudoArclengthContinuation_v3:InitialPoint', ...
                    'The initial fixed-parameter solve failed: %s', ...
                    initialSolve.message);
            end
            q = initialSolve.mode;
            mu = pReference(index);
            z = [u(:); mu];
            initialPoint = obj.makeInitialPoint( ...
                residual, u, pReference, q, initialSolve);
            initialPoint.index = 1;
            initialPoint.arclength = 0;
            initialPoint.continuationCoordinate = mu;
            initialPoint.stability = obj.computePointStability( ...
                residual, initialPoint);
            points = initialPoint;
            failures = repmat(obj.emptyPoint(), 1, 0);

            [tScaled, scale, tangentInfo] = obj.computeTangent( ...
                residual, z, pReference, q, []);
            points(1).tangent = scale .* tScaled;
            points(1).tangentInfo = tangentInfo;
            previousPhysicalTangent = scale .* tScaled;
            ds = min(max(abs(obj.StepSize), obj.MinimumStepSize), ...
                obj.MaximumStepSize);
            accumulatedLength = 0;

            while numel(points) < obj.MaxPoints
                accepted = false;
                trialStep = ds;
                failurePoint = obj.emptyPoint();
                while trialStep >= obj.MinimumStepSize
                    zPredict = z + trialStep .* (scale .* tScaled);
                    muPredict = zPredict(end);
                    if muPredict < obj.ParameterBounds(1) || ...
                            muPredict > obj.ParameterBounds(2)
                        branch = obj.assembleBranch(points, failures, index);
                        branch.terminationReason = 'parameter bound reached';
                        return
                    end
                    pPredict = obj.parameterAt(pReference, muPredict);
                    modes = obj.RootSolver.candidateModes( ...
                        residual, zPredict(1:end-1), pPredict, q);
                    if isempty(modes)
                        modes = {q};
                    end

                    [corrected, correction] = obj.correctAcrossModes( ...
                        residual, zPredict, z, tScaled, scale, trialStep, ...
                        pReference, modes);
                    if correction.converged
                        accepted = true;
                        zNew = corrected(:);
                        uNew = zNew(1:end-1);
                        muNew = zNew(end);
                        pNew = obj.parameterAt(pReference, muNew);
                        qNew = correction.mode;
                        point = obj.makeCorrectedPoint( ...
                            residual, uNew, pNew, qNew, correction);
                        accumulatedLength = accumulatedLength + trialStep;
                        point.index = numel(points) + 1;
                        point.arclength = accumulatedLength;
                        point.continuationCoordinate = muNew;

                        [nextTScaled, nextScale, tangentInfo] = ...
                            obj.computeTangent(residual, zNew, ...
                                pReference, qNew, previousPhysicalTangent);
                        point.tangent = nextScale .* nextTScaled;
                        point.tangentInfo = tangentInfo;
                        point.stability = obj.computePointStability( ...
                            residual, point);
                        points(end + 1) = point; %#ok<AGROW>

                        z = zNew;
                        q = qNew;
                        pReference(index) = muNew;
                        previousPhysicalTangent = nextScale .* nextTScaled;
                        tScaled = nextTScaled;
                        scale = nextScale;
                        ds = min(obj.MaximumStepSize, trialStep * obj.StepGrowth);
                        if strcmpi(obj.Display, 'iter')
                            fprintf(['Pseudo-arclength point %d: mu=%.12g, ' ...
                                'ds=%.3g, ||G||_inf=%.3e, mode=%s\n'], ...
                                numel(points), muNew, trialStep, ...
                                correction.residualNorm, obj.modeText(qNew));
                        end
                        break
                    end
                    failurePoint = obj.makeFailurePoint( ...
                        zPredict, pPredict, q, correction);
                    trialStep = trialStep * obj.StepShrink;
                end

                if ~accepted
                    failures(end + 1) = failurePoint; %#ok<AGROW>
                    branch = obj.assembleBranch(points, failures, index);
                    branch.terminationReason = 'corrector failed at minimum step';
                    return
                end
            end
            branch = obj.assembleBranch(points, failures, index);
            branch.terminationReason = 'maximum point count reached';
        end
    end

    methods (Access = private)
        function [zBest, resultBest] = correctAcrossModes(obj, residual, ...
                zPredict, zBase, tScaled, scale, ds, pReference, modes)
            resultBest = obj.emptyCorrection();
            zBest = zPredict;
            bestScore = Inf;
            for i = 1:numel(modes)
                qTrial = modes{i};
                augmented = @(candidate) obj.augmentedResidual( ...
                    residual, candidate, zBase, tScaled, scale, ds, ...
                    pReference, qTrial);
                [zCandidate, rootInfo] = obj.RootSolver.solve( ...
                    augmented, zPredict, zeros(0, 1), []);
                score = rootInfo.residualNorm;
                if rootInfo.converged
                    score = score - 1;
                end
                if isfinite(score) && score < bestScore
                    bestScore = score;
                    zBest = zCandidate;
                    resultBest = obj.emptyCorrection();
                    resultBest.converged = rootInfo.converged;
                    resultBest.mode = qTrial;
                    resultBest.residual = rootInfo.residual;
                    resultBest.residualNorm = rootInfo.residualNorm;
                    resultBest.rootInfo = rootInfo;
                    resultBest.message = rootInfo.message;
                end
            end
        end

        function value = augmentedResidual(obj, residual, candidate, ...
                zBase, tangent, scale, ds, pReference, q)
            candidate = candidate(:);
            u = candidate(1:end-1);
            p = obj.parameterAt(pReference, candidate(end));
            r = obj.evaluateResidual(residual, u, p, q);
            arclengthConstraint = tangent' * ((candidate - zBase) ./ scale) - ds;
            value = [r(:); arclengthConstraint];
        end

        function [tScaled, scale, info] = computeTangent(obj, residual, z, ...
                pReference, q, previousPhysical)
            scale = obj.scaling(z);
            functionValue = @(candidate) obj.evaluateAtExtendedPoint( ...
                residual, candidate, pReference, q);
            [A, ~, fdInfo] = obj.Jacobian.compute(functionValue, z);
            if size(A, 2) ~= size(A, 1) + 1
                error('PseudoArclengthContinuation_v3:TangentDimension', ...
                    ['A one-parameter continuation requires an m-by-(m+1) ' ...
                     'extended Jacobian; received %d-by-%d.'], ...
                    size(A, 1), size(A, 2));
            end
            scaledJacobian = A * diag(scale);
            [~, singularValues, V] = svd(scaledJacobian);
            tScaled = V(:, end);
            tScaled = tScaled ./ norm(tScaled);
            physical = scale .* tScaled;

            if isempty(previousPhysical)
                if ~isempty(obj.InitialTangent)
                    reference = obj.InitialTangent(:);
                    if numel(reference) ~= numel(physical)
                        error('PseudoArclengthContinuation_v3:InitialTangent', ...
                            'InitialTangent has an incompatible dimension.');
                    end
                    if dot(physical, reference) < 0
                        tScaled = -tScaled;
                    end
                elseif sign(tScaled(end)) ~= sign(obj.InitialDirection) && ...
                        abs(tScaled(end)) > sqrt(eps)
                    tScaled = -tScaled;
                end
            elseif dot(physical, previousPhysical) < 0
                tScaled = -tScaled;
            end

            values = diag(singularValues);
            info = struct();
            info.extendedJacobian = A;
            info.scaledJacobian = scaledJacobian;
            info.singularValues = values;
            info.rank = sum(values > max(size(A)) * eps(max(values)));
            info.finiteDifference = fdInfo;
            info.scale = scale;
        end

        function r = evaluateAtExtendedPoint(obj, residual, z, pReference, q)
            z = z(:);
            p = obj.parameterAt(pReference, z(end));
            r = obj.evaluateResidual(residual, z(1:end-1), p, q);
        end

        function [r, info] = evaluateResidual(~, residual, u, p, q)
            info = struct();
            if isa(residual, 'function_handle')
                n = nargin(residual);
                if n == 1
                    r = residual(u);
                elseif n == 2
                    r = residual(u, p);
                else
                    r = residual(u, p, q);
                end
            elseif isobject(residual) && ismethod(residual, 'evaluateWithInfo')
                [r, info] = residual.evaluateWithInfo(u, p, q);
            elseif isobject(residual) && ismethod(residual, 'evaluate')
                r = residual.evaluate(u, p, q);
            elseif isstruct(residual) && isfield(residual, 'evaluateWithInfo')
                [r, info] = residual.evaluateWithInfo(u, p, q);
            elseif isstruct(residual) && isfield(residual, 'evaluate')
                r = residual.evaluate(u, p, q);
            else
                error('PseudoArclengthContinuation_v3:ResidualInterface', ...
                    'Residual must be a function handle or expose evaluate().');
            end
            r = r(:);
            if any(~isfinite(r))
                error('PseudoArclengthContinuation_v3:NonfiniteResidual', ...
                    'The residual contains nonfinite values.');
            end
            if isstruct(info)
                names = {'success', 'valid', 'modeClosure', 'mode_closed'};
                for i = 1:numel(names)
                    if isfield(info, names{i}) && ~info.(names{i})
                        error('PseudoArclengthContinuation_v3:InvalidReturn', ...
                            'The hybrid return map rejected this trial.');
                    end
                end
            end
        end

        function scale = scaling(obj, z)
            if ~isempty(obj.Scale)
                scale = obj.Scale(:);
                if isscalar(scale)
                    scale = repmat(scale, numel(z), 1);
                end
                if numel(scale) ~= numel(z) || any(scale <= 0)
                    error('PseudoArclengthContinuation_v3:Scale', ...
                        'Scale must be positive and match [u;mu].');
                end
            elseif obj.AutoScale
                scale = 1 + abs(z(:));
            else
                scale = ones(numel(z), 1);
            end
        end

        function p = parameterAt(obj, reference, mu)
            p = reference(:);
            p(obj.ActiveParameterIndex) = mu;
        end

        function point = makeInitialPoint(obj, ~, u, p, q, solveInfo)
            point = obj.emptyPoint();
            point.x = u(:);
            point.p = p(:);
            point.mode = q;
            point.residual = solveInfo.residual;
            point.residualNorm = solveInfo.residualNorm;
            point.converged = solveInfo.converged;
            point.solverInfo = solveInfo;
            point.orbit = solveInfo.orbit;
            point.fullState = solveInfo.fullState;
            point = obj.populateOrbitFields(point, solveInfo.evaluationInfo);
        end

        function point = makeCorrectedPoint(obj, residual, u, p, q, correction)
            point = obj.emptyPoint();
            point.x = u(:);
            point.p = p(:);
            point.mode = q;
            point.converged = correction.converged;
            point.solverInfo = correction.rootInfo;
            [baseResidual, evalInfo] = obj.evaluateResidual(residual, u, p, q);
            point.residual = baseResidual;
            point.residualNorm = norm(baseResidual, Inf);
            point.fullState = obj.fullState(residual, u, p, q);
            point.orbit = obj.createOrbit(residual, u, p, q, evalInfo);
            point = obj.populateOrbitFields(point, evalInfo);
        end

        function point = populateOrbitFields(obj, point, evalInfo)
            point.period = obj.member(point.orbit, 'period', NaN);
            point.event_history = obj.member( ...
                point.orbit, 'event_history', {});
            point.mode_history = obj.member( ...
                point.orbit, 'mode_history', {});
            point.stability = obj.member(point.orbit, 'stability', []);
            if isnan(point.period)
                point.period = obj.member(evalInfo, 'period', NaN);
            end
            if isempty(point.event_history)
                point.event_history = obj.member(evalInfo, 'event_history', {});
            end
            if isempty(point.mode_history)
                point.mode_history = obj.member(evalInfo, 'mode_history', {});
            end
        end

        function point = makeFailurePoint(obj, z, p, q, correction)
            point = obj.emptyPoint();
            point.x = z(1:end-1);
            point.p = p;
            point.mode = q;
            point.continuationCoordinate = z(end);
            point.residual = correction.residual;
            point.residualNorm = correction.residualNorm;
            point.solverInfo = correction.rootInfo;
        end

        function x = fullState(~, residual, u, p, q)
            x = u(:);
            try
                if isobject(residual) && ismethod(residual, 'fullState')
                    try
                        x = residual.fullState(u, p, q);
                    catch
                        try
                            x = residual.fullState(u, p);
                        catch
                            x = residual.fullState(u);
                        end
                    end
                elseif isstruct(residual) && isfield(residual, 'fullState')
                    n = nargin(residual.fullState);
                    if n == 1
                        x = residual.fullState(u);
                    elseif n == 2
                        x = residual.fullState(u, p);
                    else
                        x = residual.fullState(u, p, q);
                    end
                end
            catch
                x = u(:);
            end
            x = x(:);
        end

        function orbit = createOrbit(~, residual, u, p, q, info)
            orbit = [];
            try
                if isobject(residual) && ismethod(residual, 'createOrbit')
                    try
                        orbit = residual.createOrbit(u, p, q, info);
                    catch
                        orbit = residual.createOrbit(u, p, q);
                    end
                elseif isstruct(residual) && isfield(residual, 'createOrbit')
                    orbit = residual.createOrbit(u, p, q, info);
                end
            catch
                orbit = [];
            end
        end

        function stability = computePointStability(obj, residual, point)
            stability = point.stability;
            if ~obj.ComputeStability || isempty(obj.StabilityAnalyzer)
                return
            end
            try
                analyzer = obj.StabilityAnalyzer;
                if isa(analyzer, 'function_handle')
                    stability = analyzer(residual, point.x, point.p, ...
                        point.mode, point.orbit);
                else
                    map = obj.member(residual, 'Map', []);
                    stability = analyzer.analyze( ...
                        map, point.fullState, point.mode, point.p);
                end
            catch ME
                stability = struct('reliable', false, ...
                    'errorIdentifier', ME.identifier, 'message', ME.message);
            end
        end

        function branch = assembleBranch(~, points, failures, index)
            branch = struct();
            branch.type = 'pseudo-arclength';
            branch.activeParameterIndex = index;
            branch.points = points;
            branch.failures = failures;
            branch.count = numel(points);
            branch.success = isempty(failures);
            branch.x = [points.x];
            branch.p = [points.p];
            branch.full_state = {points.fullState};
            branch.mode = {points.mode};
            branch.period = [points.period];
            branch.event_history = {points.event_history};
            branch.mode_history = {points.mode_history};
            branch.stability = {points.stability};
            branch.orbit = {points.orbit};
            branch.solver_info = {points.solverInfo};
            branch.arclength = [points.arclength];
            branch.continuationCoordinate = [points.continuationCoordinate];
            branch.tangent = {points.tangent};
        end

        function value = member(~, source, name, default)
            value = default;
            if isempty(source)
                return
            end
            if isstruct(source) && isfield(source, name)
                value = source.(name);
            elseif isobject(source) && isprop(source, name)
                value = source.(name);
            end
        end

        function point = emptyPoint(~)
            point = struct( ...
                'index', [], 'arclength', NaN, ...
                'continuationCoordinate', NaN, 'x', [], 'fullState', [], ...
                'p', [], 'mode', [], 'period', NaN, ...
                'event_history', {{}}, 'mode_history', {{}}, ...
                'stability', [], 'orbit', [], 'tangent', [], ...
                'tangentInfo', struct(), 'residual', [], ...
                'residualNorm', Inf, 'converged', false, ...
                'solverInfo', struct());
        end

        function correction = emptyCorrection(~)
            correction = struct('converged', false, 'mode', [], ...
                'residual', [], 'residualNorm', Inf, 'rootInfo', struct(), ...
                'message', 'No mode candidate converged.');
        end

        function text = modeText(~, mode)
            if isnumeric(mode) || islogical(mode)
                text = mat2str(mode);
            elseif ischar(mode)
                text = mode;
            elseif isstring(mode)
                text = char(mode);
            else
                text = class(mode);
            end
        end

        function obj = applyOptions(obj, options)
            names = fieldnames(options);
            for i = 1:numel(names)
                obj = obj.setOption(names{i}, options.(names{i}));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin), 2) ~= 0
                error('PseudoArclengthContinuation_v3:NameValue', ...
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
                error('PseudoArclengthContinuation_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(list{match}) = value;
        end

        function validateOptions(obj)
            if obj.StepSize == 0 || obj.MinimumStepSize <= 0 || ...
                    obj.MaximumStepSize < obj.MinimumStepSize || ...
                    obj.StepShrink <= 0 || obj.StepShrink >= 1 || ...
                    obj.StepGrowth <= 1 || obj.MaxPoints < 1
                error('PseudoArclengthContinuation_v3:Options', ...
                    'Pseudo-arclength step controls are inconsistent.');
            end
            if numel(obj.ParameterBounds) ~= 2 || ...
                    obj.ParameterBounds(1) > obj.ParameterBounds(2)
                error('PseudoArclengthContinuation_v3:ParameterBounds', ...
                    'ParameterBounds must be [lower upper].');
            end
        end
    end
end
