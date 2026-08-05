classdef NumericalContinuation1D_v3
    %NUMERICALCONTINUATION1D_V3 Previous-solution parameter continuation.
    %   No event times or event ordering enter the unknown vector.  Hybrid
    %   histories are collected from each accepted orbit and stored as data.

    properties
        RootSolver = []
        ActiveParameterIndex = 1
        StopOnFailure = true
        ComputeStability = false
        StabilityAnalyzer = []
        Display = 'off'
    end

    methods
        function obj = NumericalContinuation1D_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            if isempty(obj.RootSolver)
                obj.RootSolver = RootSolver_v3();
            end
        end

        function branch = run(obj, residual, u0, p0, q0, parameterValues)
            if nargin < 6 || isempty(parameterValues)
                error('NumericalContinuation1D_v3:ParameterValues', ...
                    'A nonempty vector of continuation-parameter values is required.');
            end
            p0 = p0(:);
            uGuess = u0(:);
            qGuess = q0;
            index = obj.ActiveParameterIndex;
            if ~isscalar(index) || index < 1 || index > numel(p0) || ...
                    index ~= floor(index)
                error('NumericalContinuation1D_v3:ParameterIndex', ...
                    'ActiveParameterIndex is outside the parameter vector.');
            end
            parameterValues = parameterValues(:).';
            points = repmat(obj.emptyPoint(), 1, 0);
            failures = repmat(obj.emptyPoint(), 1, 0);

            for k = 1:numel(parameterValues)
                p = p0;
                p(index) = parameterValues(k);
                [u, solveInfo] = obj.RootSolver.solve( ...
                    residual, uGuess, p, qGuess);
                point = obj.makePoint(residual, u, p, solveInfo.mode, solveInfo);
                point.continuationCoordinate = parameterValues(k);
                point.index = k;
                if solveInfo.converged
                    point.stability = obj.computePointStability( ...
                        residual, point, solveInfo);
                    points(end + 1) = point; %#ok<AGROW>
                    uGuess = u;
                    qGuess = solveInfo.mode;
                    if strcmpi(obj.Display, 'iter')
                        fprintf(['Continuation point %d: p(%d)=%.12g, ' ...
                            '||R||_inf=%.3e, mode=%s\n'], ...
                            k, index, parameterValues(k), ...
                            solveInfo.residualNorm, obj.modeText(qGuess));
                    end
                else
                    failures(end + 1) = point; %#ok<AGROW>
                    if strcmpi(obj.Display, 'iter')
                        fprintf('Continuation point %d failed: %s\n', ...
                            k, solveInfo.message);
                    end
                    if obj.StopOnFailure
                        break
                    end
                end
            end
            branch = obj.assembleBranch(points, failures, index, parameterValues);
        end

        function branch = continueTo(obj, residual, u0, p0, q0, ...
                targetValue, stepSize)
            if stepSize == 0
                error('NumericalContinuation1D_v3:StepSize', ...
                    'stepSize must be nonzero.');
            end
            startValue = p0(obj.ActiveParameterIndex);
            direction = sign(targetValue - startValue);
            if direction == 0
                values = startValue;
            else
                stepSize = direction * abs(stepSize);
                values = startValue:stepSize:targetValue;
                if isempty(values) || values(end) ~= targetValue
                    values(end + 1) = targetValue;
                end
            end
            branch = obj.run(residual, u0, p0, q0, values);
        end
    end

    methods (Access = private)
        function point = makePoint(obj, residual, u, p, q, solveInfo)
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
            point.period = obj.member(point.orbit, 'period', NaN);
            point.event_history = obj.member( ...
                point.orbit, 'event_history', {});
            point.mode_history = obj.member( ...
                point.orbit, 'mode_history', {});
            point.stability = obj.member(point.orbit, 'stability', []);
            if isnan(point.period)
                point.period = obj.member(solveInfo.evaluationInfo, 'period', NaN);
            end
            if isempty(point.event_history)
                point.event_history = obj.member( ...
                    solveInfo.evaluationInfo, 'event_history', {});
            end
            if isempty(point.mode_history)
                point.mode_history = obj.member( ...
                    solveInfo.evaluationInfo, 'mode_history', {});
            end
            if isempty(point.orbit)
                point.orbit = obj.tryCreateOrbit(residual, u, p, q, ...
                    solveInfo.evaluationInfo);
            end
        end

        function stability = computePointStability(obj, residual, point, solveInfo)
            stability = point.stability;
            if ~obj.ComputeStability || isempty(obj.StabilityAnalyzer)
                return
            end
            try
                analyzer = obj.StabilityAnalyzer;
                if isa(analyzer, 'function_handle')
                    n = nargin(analyzer);
                    if n == 1
                        stability = analyzer(point.orbit);
                    elseif n == 2
                        stability = analyzer(point.orbit, point);
                    else
                        stability = analyzer( ...
                            residual, point.x, point.p, point.mode, point.orbit);
                    end
                elseif isobject(analyzer) && ismethod(analyzer, 'analyze')
                    map = obj.member(residual, 'Map', []);
                    stability = analyzer.analyze( ...
                        map, solveInfo.fullState, point.mode, point.p);
                end
            catch ME
                stability = struct('reliable', false, ...
                    'errorIdentifier', ME.identifier, 'message', ME.message);
            end
        end

        function orbit = tryCreateOrbit(~, residual, u, p, q, info)
            orbit = [];
            if isa(residual, 'function_handle')
                return
            end
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

        function branch = assembleBranch(~, points, failures, index, requested)
            branch = struct();
            branch.type = 'simple-parameter';
            branch.activeParameterIndex = index;
            branch.requestedParameterValues = requested;
            branch.points = points;
            branch.failures = failures;
            branch.count = numel(points);
            branch.success = isempty(failures);
            branch.x = [];
            branch.p = [];
            branch.full_state = {};
            branch.mode = {};
            branch.period = [];
            branch.event_history = {};
            branch.mode_history = {};
            branch.stability = {};
            branch.orbit = {};
            branch.solver_info = {};
            branch.continuationCoordinate = [];
            if isempty(points)
                return
            end
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
            branch.continuationCoordinate = [points.continuationCoordinate];
        end

        function point = emptyPoint(~)
            point = struct( ...
                'index', [], 'continuationCoordinate', NaN, ...
                'x', [], 'fullState', [], 'p', [], 'mode', [], ...
                'period', NaN, 'event_history', {{}}, ...
                'mode_history', {{}}, 'stability', [], 'orbit', [], ...
                'residual', [], 'residualNorm', Inf, 'converged', false, ...
                'solverInfo', struct());
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
                error('NumericalContinuation1D_v3:NameValue', ...
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
                error('NumericalContinuation1D_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(list{match}) = value;
        end
    end
end
