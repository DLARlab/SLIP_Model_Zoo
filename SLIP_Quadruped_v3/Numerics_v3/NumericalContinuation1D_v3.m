classdef NumericalContinuation1D_v3
    %NUMERICALCONTINUATION1D_V3 Previous-solution parameter continuation.
    %   No event times or event ordering enter the unknown vector.  Hybrid
    %   histories are collected from each accepted orbit and stored as data.

    properties
        RootSolver = []
        ActiveParameterIndex = 1
        ActiveParameter = []
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
            [index, parameterName] = obj.resolveParameter( ...
                residual, numel(p0));
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
                    point.topologyBoundary = ...
                        ~isempty(point.section_coincident_events);
                    if ~isempty(points)
                        point.topologyBoundary = point.topologyBoundary || ...
                            ~obj.compatibleTopology(points(end), point);
                    end
                    if point.topologyBoundary
                        point.stability = struct('reliable', false, ...
                            'warning', ['Stability is unresolved at a ', ...
                                'marked hybrid topology boundary.']);
                    else
                        point.stability = obj.computePointStability( ...
                            residual, point, solveInfo);
                    end
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
            branch = obj.assembleBranch(points, failures, index, ...
                parameterName, parameterValues);
        end

        function branch = continueTo(obj, residual, u0, p0, q0, ...
                targetValue, stepSize)
            if stepSize == 0
                error('NumericalContinuation1D_v3:StepSize', ...
                    'stepSize must be nonzero.');
            end
            [index, ~] = obj.resolveParameter(residual, numel(p0));
            startValue = p0(index);
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
            mapInfo = obj.mapInfo(solveInfo.evaluationInfo);
            point.return_multiplicity = obj.memberAny(mapInfo, ...
                {'return_multiplicity', 'returnMultiplicity'}, 1);
            point.section_relative_signature = obj.memberAny(mapInfo, ...
                {'section_relative_event_signature', ...
                 'sectionRelativeEventSignature', 'event_signature'}, '');
            point.cyclic_signature = obj.memberAny(mapInfo, ...
                {'cyclic_event_signature', 'cyclicEventSignature', ...
                 'cycle_signature'}, '');
            point.event_counts = obj.memberAny(mapInfo, ...
                {'event_counts', 'eventCounts'}, []);
            point.guard_transversality = obj.memberAny(mapInfo, ...
                {'guard_transversality', 'guardTransversality', ...
                 'guard_transversality_margin', ...
                 'guard_transversality_margins', ...
                 'minimum_guard_transversality'}, []);
            point.topology_margins = obj.memberAny(mapInfo, ...
                {'topology_margins', 'topologyMargins'}, struct());
            point.stance_force_admissibility_margin = obj.memberAny( ...
                mapInfo, {'stance_force_admissibility_margin', ...
                'minimum_stance_admissibility_margin'}, Inf);
            point.section_coincident_events = obj.memberAny(mapInfo, ...
                {'section_coincident_events', ...
                 'sectionCoincidentEvents'}, struct([]));
            point.root_statistics = struct( ...
                'functionEvaluations', obj.member(solveInfo, ...
                    'functionEvaluationCount', 0), ...
                'mapEvaluations', obj.member(solveInfo, ...
                    'mapEvaluationCount', 0), ...
                'cacheHits', obj.member(solveInfo, 'cacheHitCount', 0), ...
                'invalidEvaluations', obj.member(solveInfo, ...
                    'invalidEvaluationCount', 0), ...
                'modesAttempted', numel(obj.member( ...
                    solveInfo, 'candidateModes', {})));
            point.schema_metadata = obj.schemaMetadata(residual);
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

        function branch = assembleBranch(~, points, failures, index, ...
                parameterName, requested)
            branch = struct();
            branch.type = 'simple-parameter';
            branch.activeParameterIndex = index;
            branch.activeParameter = parameterName;
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
            branch.return_multiplicity = [];
            branch.section_relative_signature = {};
            branch.cyclic_signature = {};
            branch.event_counts = {};
            branch.guard_transversality = {};
            branch.topology_margins = {};
            branch.stance_force_admissibility_margin = [];
            branch.section_coincident_events = {};
            branch.root_statistics = {};
            branch.schema_metadata = {};
            branch.topology_boundary = [];
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
            branch.return_multiplicity = [points.return_multiplicity];
            branch.section_relative_signature = ...
                {points.section_relative_signature};
            branch.cyclic_signature = {points.cyclic_signature};
            branch.event_counts = {points.event_counts};
            branch.guard_transversality = {points.guard_transversality};
            branch.topology_margins = {points.topology_margins};
            branch.stance_force_admissibility_margin = ...
                [points.stance_force_admissibility_margin];
            branch.section_coincident_events = ...
                {points.section_coincident_events};
            branch.root_statistics = {points.root_statistics};
            branch.schema_metadata = {points.schema_metadata};
            branch.topology_boundary = [points.topologyBoundary];
        end

        function point = emptyPoint(~)
            point = struct( ...
                'index', [], 'continuationCoordinate', NaN, ...
                'x', [], 'fullState', [], 'p', [], 'mode', [], ...
                'period', NaN, 'event_history', {{}}, ...
                'mode_history', {{}}, 'stability', [], 'orbit', [], ...
                'residual', [], 'residualNorm', Inf, 'converged', false, ...
                'solverInfo', struct(), 'return_multiplicity', NaN, ...
                'section_relative_signature', '', 'cyclic_signature', '', ...
                'event_counts', [], 'guard_transversality', [], ...
                'topology_margins', struct(), 'root_statistics', struct(), ...
                'stance_force_admissibility_margin', Inf, ...
                'section_coincident_events', {struct([])}, ...
                'schema_metadata', struct(), 'topologyBoundary', false);
        end

        function [index, name] = resolveParameter(obj, residual, count)
            selector = obj.ActiveParameter;
            if isempty(selector)
                selector = obj.ActiveParameterIndex;
            end
            names = obj.parameterNames(residual);
            if ischar(selector) || (isstring(selector) && isscalar(selector))
                name = char(selector);
                index = find(strcmp(name, names), 1);
                if isempty(index)
                    error('NumericalContinuation1D_v3:ParameterName', ...
                        'Unknown active parameter "%s".', name);
                end
            else
                index = selector;
                if ~(isnumeric(index) && isscalar(index) && isfinite(index) && ...
                        index == floor(index) && index >= 1 && index <= count)
                    error('NumericalContinuation1D_v3:ParameterIndex', ...
                        'Active parameter index is outside the parameter vector.');
                end
                if numel(names) >= index
                    name = names{index};
                else
                    name = sprintf('p%d', index);
                end
            end
        end

        function names = parameterNames(obj, residual)
            names = {};
            map = obj.member(residual, 'Map', []);
            system = obj.member(map, 'System', []);
            names = obj.member(system, 'ParameterNames', {});
            if isstring(names)
                names = cellstr(names(:).');
            end
        end

        function info = mapInfo(~, evaluationInfo)
            info = evaluationInfo;
            if isstruct(evaluationInfo) && isfield(evaluationInfo, 'map_info')
                info = evaluationInfo.map_info;
            end
            if isempty(info) || ~isstruct(info)
                info = struct();
            end
        end

        function value = memberAny(obj, source, names, default)
            value = default;
            for index = 1:numel(names)
                candidate = obj.member(source, names{index}, []);
                if ~isempty(candidate)
                    value = candidate;
                    return
                end
            end
        end

        function metadata = schemaMetadata(obj, residual)
            metadata = struct();
            map = obj.member(residual, 'Map', []);
            system = obj.member(map, 'System', []);
            try
                if isobject(system) && ismethod(system, 'schemaMetadata')
                    metadata = system.schemaMetadata();
                end
            catch
                metadata = struct();
            end
        end

        function compatible = compatibleTopology(~, left, right)
            compatible = isequal(string(left.cyclic_signature), ...
                string(right.cyclic_signature)) && ...
                isequal(string(left.section_relative_signature), ...
                    string(right.section_relative_signature)) && ...
                isequal(left.return_multiplicity, right.return_multiplicity) && ...
                isequal(left.mode, right.mode) && ...
                isempty(right.section_coincident_events);
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
