classdef FloquetAnalysis_v3
    %FLOQUETANALYSIS_V3 Finite-difference hybrid Poincare stability.
    %   The differentiated object is the complete event-driven return map,
    %   including guard-time changes and reset maps.  Perturbations are made
    %   only in a section-tangent, symmetry-reduced coordinate set.

    properties
        TangentIndices = []
        Differencing = 'forward'
        RelativeStep = []
        Jacobian = []
        StabilityTolerance = 1e-6
        RequireDiscreteClosure = true
        RequireMatchingEventSignature = false
        ProjectionFunction = []
        ComputeAmbientJacobian = true
    end

    methods
        function obj = FloquetAnalysis_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            if ~any(strcmpi(obj.Differencing, {'forward', 'central'}))
                error('FloquetAnalysis_v3:Differencing', ...
                    'Differencing must be forward or central.');
            end
        end

        function result = analyze(obj, map, x, q, p, options)
            if nargin < 6
                options = struct();
            end
            local = obj;
            if ~isempty(options)
                local = local.applyOptions(options);
            end
            x = x(:);
            p = p(:);
            xTemplate = local.projectState(map, x, p);
            indices = local.resolveTangentIndices(map, numel(xTemplate));
            eta0 = xTemplate(indices);

            evaluations = repmat(struct( ...
                'coordinates', [], 'state', [], 'nextState', [], ...
                'mapInfo', struct(), 'eventSignature', '', ...
                'discreteClosed', true), 1, 0);
            ambientEvaluations = repmat(struct( ...
                'state', [], 'projectedState', [], 'nextState', [], ...
                'mapInfo', struct(), 'eventSignature', '', ...
                'discreteClosed', true), 1, 0);

            if isempty(local.Jacobian)
                arguments = {'Method', local.Differencing};
                if ~isempty(local.RelativeStep)
                    arguments = [arguments, {'RelativeStep', local.RelativeStep}];
                end
                fd = FiniteDifferenceJacobian_v3(arguments{:});
            else
                fd = local.Jacobian;
            end
            [DP, etaNext, fdInfo] = fd.compute(@reducedReturn, eta0);
            if size(DP, 1) ~= numel(indices) || ...
                    size(DP, 2) ~= numel(indices)
                error('FloquetAnalysis_v3:MapDimension', ...
                    ['The reduced return map must preserve chart dimension; ' ...
                     'received a %d-by-%d derivative.'], ...
                    size(DP, 1), size(DP, 2));
            end

            ambientDP = [];
            ambientNext = [];
            ambientFdInfo = struct();
            if local.ComputeAmbientJacobian
                [ambientDP, ambientNext, ambientFdInfo] = ...
                    fd.compute(@ambientReturn, xTemplate);
            end

            [eigenvectors, diagonal] = eig(DP);
            multipliers = diag(diagonal);
            spectralRadius = max(abs(multipliers));
            if isempty(spectralRadius)
                spectralRadius = 0;
            end
            margin = 1 - spectralRadius;
            if margin > local.StabilityTolerance
                stability = 'stable';
            elseif margin < -local.StabilityTolerance
                stability = 'unstable';
            else
                stability = 'marginal';
            end

            signatures = {evaluations.eventSignature};
            if isempty(signatures)
                baseSignature = '';
                matchingSignatures = true;
                baseInfo = struct();
            else
                baseSignature = signatures{1};
                matchingSignatures = all(strcmp(baseSignature, signatures));
                baseInfo = evaluations(1).mapInfo;
            end
            closure = [evaluations.discreteClosed];
            matchingClosure = isempty(closure) || all(closure);
            reliable = matchingClosure && matchingSignatures;
            if local.RequireMatchingEventSignature && ~matchingSignatures
                error('FloquetAnalysis_v3:EventSignatureChanged', ...
                    ['Finite-difference trials changed the physical event ' ...
                     'sequence; a single smooth Floquet matrix is not valid ' ...
                     'at this perturbation scale.']);
            end

            result = struct();
            result.poincareMatrix = DP;
            result.floquetMatrix = DP;
            result.jacobian = DP;
            result.multipliers = multipliers;
            result.eigenvectors = eigenvectors;
            result.ambientEigenvectors = local.liftEigenvectors( ...
                eigenvectors, indices, numel(xTemplate));
            result.ambientJacobian = ambientDP;
            result.ambientPoincareMatrix = ambientDP;
            result.ambientReturnState = ambientNext;
            result.ambientPerturbations = ambientEvaluations;
            result.ambientFiniteDifference = ambientFdInfo;
            result.spectralRadius = spectralRadius;
            result.stabilityMargin = margin;
            result.stability_margin = margin;
            result.stability = stability;
            result.stable = strcmp(stability, 'stable');
            result.reliable = reliable;
            result.eventSignaturesMatch = matchingSignatures;
            result.discreteClosurePreserved = matchingClosure;
            result.eventSignature = baseSignature;
            result.tangentIndices = indices;
            result.baseState = xTemplate;
            result.baseCoordinates = eta0;
            result.returnCoordinates = etaNext;
            result.baseMapInfo = baseInfo;
            result.perturbations = evaluations;
            result.finiteDifference = fdInfo;
            if ~matchingSignatures
                result.warning = ['Finite-difference trials changed event ' ...
                    'signature; the map is piecewise smooth at this scale.'];
            elseif ~matchingClosure
                result.warning = ['A finite-difference trial did not return ' ...
                    'to the initial discrete mode.'];
            else
                result.warning = '';
            end

            function coordinatesNext = reducedReturn(coordinates)
                trial = xTemplate;
                trial(indices) = coordinates(:);
                trial = local.projectState(map, trial, p);
                [nextState, mapInfo] = local.evaluateMap(map, trial, q, p);
                nextState = nextState(:);
                if numel(nextState) ~= numel(trial) || ...
                        any(~isfinite(nextState))
                    error('FloquetAnalysis_v3:InvalidReturnState', ...
                        'The Poincare map returned an invalid state.');
                end
                discreteClosed = local.discreteClosed(mapInfo, q);
                if local.RequireDiscreteClosure && ~discreteClosed
                    % Keep the value for diagnostics, then reject the map.
                    error('FloquetAnalysis_v3:DiscreteClosure', ...
                        'A perturbed return did not close in the discrete mode.');
                end
                coordinatesNext = nextState(indices);
                record = struct();
                record.coordinates = coordinates(:);
                record.state = trial;
                record.nextState = nextState;
                record.mapInfo = mapInfo;
                record.eventSignature = local.eventSignature(mapInfo);
                record.discreteClosed = discreteClosed;
                evaluations(end + 1) = record;
            end

            function nextState = ambientReturn(state)
                state = state(:);
                projected = local.projectState(map, state, p);
                [nextState, mapInfo] = local.evaluateMap( ...
                    map, projected, q, p);
                nextState = nextState(:);
                if numel(nextState) ~= numel(projected) || ...
                        any(~isfinite(nextState))
                    error('FloquetAnalysis_v3:InvalidAmbientReturnState', ...
                        'The ambient Poincare map returned an invalid state.');
                end
                discreteClosed = local.discreteClosed(mapInfo, q);
                if local.RequireDiscreteClosure && ~discreteClosed
                    error('FloquetAnalysis_v3:AmbientDiscreteClosure', ...
                        ['An ambient finite-difference trial did not return ', ...
                         'to the initial discrete mode.']);
                end
                record = struct();
                record.state = state;
                record.projectedState = projected;
                record.nextState = nextState;
                record.mapInfo = mapInfo;
                record.eventSignature = local.eventSignature(mapInfo);
                record.discreteClosed = discreteClosed;
                ambientEvaluations(end + 1) = record;
            end
        end

        function result = analyzeResidual(obj, residual, u, p, q, options)
            if nargin < 6
                options = struct();
            end
            if ~(isobject(residual) && isprop(residual, 'Map')) && ...
                    ~(isstruct(residual) && isfield(residual, 'Map'))
                error('FloquetAnalysis_v3:ResidualInterface', ...
                    'The residual must expose its Poincare Map.');
            end
            map = residual.Map;
            if isobject(residual) && ismethod(residual, 'fullState')
                x = residual.fullState(u);
            elseif isstruct(residual) && isfield(residual, 'fullState')
                x = residual.fullState(u);
            else
                x = u(:);
            end
            if isobject(residual) && isprop(residual, 'TangentIndices')
                options.TangentIndices = residual.TangentIndices;
            elseif isstruct(residual) && isfield(residual, 'TangentIndices')
                options.TangentIndices = residual.TangentIndices;
            end
            result = obj.analyze(map, x, q, p, options);
        end

        function [multipliers, eigenvectors, margin, result] = ...
                compute(obj, varargin)
            result = obj.analyze(varargin{:});
            multipliers = result.multipliers;
            eigenvectors = result.eigenvectors;
            margin = result.stabilityMargin;
        end

        function result = analyzeOrbit(obj, map, orbit, options)
            if nargin < 4
                options = struct();
            end
            result = obj.analyze(map, orbit.initial_state, ...
                orbit.initial_mode, orbit.parameter, options);
            if isobject(orbit) && ismethod(orbit, 'setFloquetResult')
                orbit.setFloquetResult(result);
            end
        end
    end

    methods (Access = private)
        function state = projectState(obj, map, state, p)
            state = state(:);
            if ~isempty(obj.ProjectionFunction)
                state = obj.ProjectionFunction(state, p);
                state = state(:);
                return
            end
            section = obj.member(map, 'Section', []);
            if ~isempty(section)
                if isobject(section) && ismethod(section, 'project')
                    state = section.project(state, p);
                elseif isstruct(section) && isfield(section, 'project')
                    state = section.project(state, p);
                end
            end
            state = state(:);
        end

        function indices = resolveTangentIndices(obj, map, n)
            indices = obj.TangentIndices;
            if isempty(indices)
                system = obj.member(map, 'System', []);
                indices = obj.member(system, 'DefaultTangentIndices', []);
            end
            if isempty(indices)
                warning('FloquetAnalysis_v3:AmbientCoordinates', ...
                    ['No reduced tangent indices were supplied. The full ' ...
                     'ambient derivative can contain phase or symmetry modes.']);
                indices = 1:n;
            end
            indices = indices(:).';
            if any(indices < 1) || any(indices > n) || ...
                    numel(unique(indices)) ~= numel(indices)
                error('FloquetAnalysis_v3:TangentIndices', ...
                    'TangentIndices must be unique valid state indices.');
            end
        end

        function [next, info] = evaluateMap(~, map, x, q, p)
            info = struct();
            if isa(map, 'function_handle')
                try
                    [next, info] = map(x, q, p);
                catch firstError
                    try
                        next = map(x, q, p);
                    catch
                        rethrow(firstError)
                    end
                end
            elseif isobject(map) && ismethod(map, 'evaluate')
                [next, info] = map.evaluate(x, q, p);
            elseif isstruct(map) && isfield(map, 'evaluate')
                [next, info] = map.evaluate(x, q, p);
            else
                error('FloquetAnalysis_v3:MapInterface', ...
                    'map must be a function handle or expose evaluate().');
            end
        end

        function tf = discreteClosed(~, info, q)
            tf = true;
            if ~isstruct(info)
                return
            end
            if isfield(info, 'discrete_closed')
                tf = logical(info.discrete_closed);
            elseif isfield(info, 'mode_closed')
                tf = logical(info.mode_closed);
            elseif isfield(info, 'final_mode')
                tf = isequal(info.final_mode, q);
            end
        end

        function signature = eventSignature(~, info)
            signature = '';
            if ~isstruct(info)
                return
            end
            sequence = [];
            fields = {'event_sequence', 'eventSequence', 'event_history'};
            for i = 1:numel(fields)
                if isfield(info, fields{i})
                    sequence = info.(fields{i});
                    break
                end
            end
            if isempty(sequence)
                return
            end
            if isstruct(sequence)
                if isfield(sequence, 'event_type')
                    sequence = {sequence.event_type};
                elseif isfield(sequence, 'name')
                    sequence = {sequence.name};
                elseif isfield(sequence, 'event_id')
                    sequence = {sequence.event_id};
                else
                    signature = sprintf('struct[%d]', numel(sequence));
                    return
                end
            end
            if isnumeric(sequence) || islogical(sequence)
                signature = mat2str(sequence(:).');
            elseif ischar(sequence)
                signature = sequence;
            elseif isstring(sequence)
                signature = strjoin(cellstr(sequence(:)), '>');
            elseif iscell(sequence)
                parts = cell(size(sequence));
                for i = 1:numel(sequence)
                    item = sequence{i};
                    if isnumeric(item) || islogical(item)
                        parts{i} = mat2str(item);
                    elseif ischar(item)
                        parts{i} = item;
                    elseif isstring(item)
                        parts{i} = char(item);
                    else
                        parts{i} = class(item);
                    end
                end
                signature = strjoin(parts(:).', '>');
            end
        end

        function lifted = liftEigenvectors(~, vectors, indices, n)
            lifted = zeros(n, size(vectors, 2), 'like', vectors);
            lifted(indices, :) = vectors;
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

        function obj = applyOptions(obj, options)
            if ~isstruct(options)
                error('FloquetAnalysis_v3:Options', ...
                    'Options must be a structure.');
            end
            names = fieldnames(options);
            for i = 1:numel(names)
                obj = obj.setOption(names{i}, options.(names{i}));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin), 2) ~= 0
                error('FloquetAnalysis_v3:NameValue', ...
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
                error('FloquetAnalysis_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(list{match}) = value;
        end
    end
end
