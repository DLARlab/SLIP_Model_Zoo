classdef BifurcationDetector_v3
    %BIFURCATIONDETECTOR_V3 Track multipliers and bracket crossings.
    %   Detects smooth codimension-one candidates from sign changes between
    %   continuation points:
    %       unit candidate    real(lambda)-1 crosses zero,
    %       period-doubling   real(lambda)+1 crosses zero,
    %       Neimark-Sacker    abs(lambda)-1 crosses zero for a complex pair.

    properties
        CrossingTolerance = 1e-6
        ImaginaryTolerance = 1e-7
        PairTolerance = 1e-4
        EigenvectorWeight = 0.05
        RequireReliable = true
        RequireCompatibleTopology = true
    end

    methods
        function obj = BifurcationDetector_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
        end

        function [events, tracks] = detect(obj, data, varargin)
            [multipliers, eigenvectors, coordinate, parameters, reliability] = ...
                obj.extractSeries(data, varargin{:});
            tracks = obj.trackMultipliers( ...
                multipliers, eigenvectors, coordinate, parameters, reliability);
            topologyCompatibility = obj.topologyCompatibility( ...
                data, numel(reliability));
            tracks.topologyCompatible = topologyCompatibility;
            events = repmat(obj.emptyEvent(), 1, 0);
            lambda = tracks.multipliers;
            if isempty(lambda) || size(lambda, 2) < 2
                return
            end

            for k = 1:size(lambda, 2) - 1
                intervalReliable = reliability(k) && reliability(k + 1);
                if obj.RequireReliable && ~intervalReliable
                    continue
                end
                intervalTopology = isempty(topologyCompatibility) || ...
                    topologyCompatibility(k);
                if obj.RequireCompatibleTopology && ~intervalTopology
                    continue
                end
                for j = 1:size(lambda, 1)
                    left = lambda(j, k);
                    right = lambda(j, k + 1);
                    if obj.isRealPair(left, right)
                        [crossed, theta] = obj.crossingFraction( ...
                            real(left) - 1, real(right) - 1);
                        if crossed
                            event = obj.makeEvent('unit_multiplier_candidate', j, k, ...
                                theta, left, right, tracks, intervalReliable);
                            events = obj.appendUnique(events, event);
                        end
                        [crossed, theta] = obj.crossingFraction( ...
                            real(left) + 1, real(right) + 1);
                        if crossed
                            event = obj.makeEvent('period_doubling_candidate', j, k, ...
                                theta, left, right, tracks, intervalReliable);
                            events = obj.appendUnique(events, event);
                        end
                    elseif obj.isPositiveComplexTrack(left, right) && ...
                            obj.hasConjugateCompanion(lambda, j, k)
                        [crossed, theta] = obj.crossingFraction( ...
                            abs(left) - 1, abs(right) - 1);
                        if crossed
                            event = obj.makeEvent('Neimark_Sacker_candidate', j, k, ...
                                theta, left, right, tracks, intervalReliable);
                            events = obj.appendUnique(events, event);
                        end
                    end
                end
            end
        end

        function tracks = trackMultipliers(obj, multiplierSeries, ...
                eigenvectorSeries, coordinate, parameters, reliability)
            if isnumeric(multiplierSeries)
                multiplierSeries = arrayfun( ...
                    @(k) multiplierSeries(:, k), ...
                    1:size(multiplierSeries, 2), 'UniformOutput', false);
            end
            count = numel(multiplierSeries);
            if count == 0
                tracks = struct('multipliers', [], 'eigenvectors', {{}}, ...
                    'coordinate', [], 'parameters', [], 'reliable', [], ...
                    'assignments', {{}}, 'cost', {{}});
                return
            end
            n = numel(multiplierSeries{1});
            ordered = NaN(n, count) + 1i * NaN(n, count);
            ordered(:, 1) = multiplierSeries{1}(:);
            orderedVectors = cell(1, count);
            if nargin >= 3 && ~isempty(eigenvectorSeries)
                orderedVectors{1} = eigenvectorSeries{1};
            end
            assignments = cell(1, count);
            costs = cell(1, count);
            assignments{1} = (1:n).';

            for k = 2:count
                current = multiplierSeries{k}(:);
                if numel(current) ~= n
                    error('BifurcationDetector_v3:ChangingDimension', ...
                        'Multiplier count changed between branch points.');
                end
                previousVectors = [];
                currentVectors = [];
                if ~isempty(eigenvectorSeries) && ...
                        numel(eigenvectorSeries) >= k
                    previousVectors = orderedVectors{k - 1};
                    currentVectors = eigenvectorSeries{k};
                end
                finitePair = all(isfinite(ordered(:, k - 1))) && ...
                    all(isfinite(current));
                reliablePair = numel(reliability) < k || ...
                    (logical(reliability(k - 1)) && logical(reliability(k)));
                if finitePair && reliablePair
                    cost = obj.matchCost(ordered(:, k - 1), current, ...
                        previousVectors, currentVectors);
                    assignment = obj.minimumAssignment(cost);
                else
                    % An unreliable/nonfinite point breaks the smooth
                    % multiplier track. Restart ordering at this point;
                    % intervals touching it are rejected by detect().
                    cost = NaN(n, n);
                    assignment = (1:n).';
                end
                ordered(:, k) = current(assignment);
                assignments{k} = assignment;
                costs{k} = cost;
                if ~isempty(currentVectors) && size(currentVectors, 2) == n
                    orderedVectors{k} = currentVectors(:, assignment);
                else
                    orderedVectors{k} = [];
                end
            end
            tracks = struct();
            tracks.multipliers = ordered;
            tracks.eigenvectors = orderedVectors;
            tracks.coordinate = coordinate(:).';
            tracks.parameters = parameters;
            tracks.reliable = reliability(:).';
            tracks.assignments = assignments;
            tracks.cost = costs;
        end

        function [matched, assignment, cost] = match(obj, previous, current, ...
                previousVectors, currentVectors)
            if nargin < 4
                previousVectors = [];
            end
            if nargin < 5
                currentVectors = [];
            end
            if any(~isfinite(previous(:))) || any(~isfinite(current(:)))
                error('BifurcationDetector_v3:NonfiniteMatchingData', ...
                    'Multiplier matching requires finite endpoint data.');
            end
            cost = obj.matchCost(previous(:), current(:), ...
                previousVectors, currentVectors);
            assignment = obj.minimumAssignment(cost);
            matched = current(assignment);
        end
    end

    methods (Access = private)
        function [series, vectors, coordinate, parameters, reliability] = ...
                extractSeries(obj, data, varargin)
            if isnumeric(data)
                series = arrayfun(@(k) data(:, k), ...
                    1:size(data, 2), 'UniformOutput', false);
                if ~isempty(varargin)
                    coordinate = varargin{1};
                else
                    coordinate = 1:size(data, 2);
                end
                if numel(varargin) >= 2
                    vectors = varargin{2};
                else
                    vectors = cell(1, size(data, 2));
                end
                parameters = [];
                reliability = true(1, size(data, 2));
                obj.validateSeriesLengths(series, coordinate, reliability);
                return
            end
            if ~isstruct(data)
                error('BifurcationDetector_v3:Input', ...
                    'Input must be a continuation branch or multiplier matrix.');
            end

            items = {};
            if isfield(data, 'stability') && ~isempty(data.stability)
                items = data.stability;
                if ~iscell(items)
                    items = num2cell(items);
                end
            elseif isfield(data, 'orbit') && ~isempty(data.orbit)
                items = data.orbit;
                if ~iscell(items)
                    items = num2cell(items);
                end
            elseif isfield(data, 'points') && ~isempty(data.points)
                items = arrayfun(@(point) point.stability, data.points, ...
                    'UniformOutput', false);
            end
            count = numel(items);
            if count == 0
                error('BifurcationDetector_v3:NoStabilityData', ...
                    'The branch contains no multiplier data.');
            end

            series = cell(1, count);
            vectors = cell(1, count);
            reliability = true(1, count);
            for k = 1:count
                [series{k}, vectors{k}, reliability(k)] = ...
                    obj.unpackStability(items{k});
            end
            if isfield(data, 'arclength') && numel(data.arclength) == count && ...
                    all(isfinite(data.arclength))
                coordinate = data.arclength;
            elseif isfield(data, 'continuationCoordinate') && ...
                    numel(data.continuationCoordinate) == count
                coordinate = data.continuationCoordinate;
            else
                coordinate = 1:count;
            end
            if isfield(data, 'p') && size(data.p, 2) == count
                parameters = data.p;
                if ~isfield(data, 'arclength') && ...
                        isfield(data, 'activeParameterIndex')
                    coordinate = data.p(data.activeParameterIndex, :);
                end
            else
                parameters = [];
            end
            obj.validateSeriesLengths(series, coordinate, reliability);
        end

        function [lambda, vectors, reliable] = unpackStability(obj, item)
            lambda = [];
            vectors = [];
            reliable = true;
            if isempty(item)
                error('BifurcationDetector_v3:EmptyStability', ...
                    'A continuation point has no stability result.');
            end
            if isobject(item)
                if isprop(item, 'floquet_multiplier')
                    lambda = item.floquet_multiplier;
                end
                if isprop(item, 'stability') && isstruct(item.stability)
                    nested = item.stability;
                    if isempty(lambda)
                        lambda = obj.member(nested, 'multipliers', []);
                    end
                    vectors = obj.member(nested, 'eigenvectors', []);
                    reliable = obj.member(nested, 'reliable', true);
                end
            elseif isstruct(item)
                lambda = obj.member(item, 'multipliers', []);
                if isempty(lambda)
                    lambda = obj.member(item, 'floquet_multiplier', []);
                end
                if isempty(lambda) && isfield(item, 'stability') && ...
                        isstruct(item.stability)
                    lambda = obj.member(item.stability, 'multipliers', []);
                    vectors = obj.member(item.stability, 'eigenvectors', []);
                    reliable = obj.member(item.stability, 'reliable', true);
                else
                    vectors = obj.member(item, 'eigenvectors', []);
                    reliable = obj.member(item, 'reliable', true);
                end
            end
            if isempty(lambda) || ~isnumeric(lambda)
                error('BifurcationDetector_v3:MissingMultipliers', ...
                    'A stability result does not contain multipliers.');
            end
            lambda = lambda(:);
            reliable = logical(reliable) && all(isfinite(lambda));
        end

        function validateSeriesLengths(~, series, coordinate, reliability)
            count = numel(series);
            if numel(coordinate) ~= count || numel(reliability) ~= count
                error('BifurcationDetector_v3:SeriesLength', ...
                    'Multiplier, coordinate, and reliability lengths differ.');
            end
        end

        function cost = matchCost(obj, previous, current, Vprevious, Vcurrent)
            n = numel(previous);
            if numel(current) ~= n
                error('BifurcationDetector_v3:MatchDimension', ...
                    'Previous and current multiplier counts differ.');
            end
            cost = zeros(n, n);
            useVectors = ~isempty(Vprevious) && ~isempty(Vcurrent) && ...
                size(Vprevious, 2) == n && size(Vcurrent, 2) == n && ...
                size(Vprevious, 1) == size(Vcurrent, 1);
            for i = 1:n
                for j = 1:n
                    scale = 1 + abs(previous(i)) + abs(current(j));
                    cost(i, j) = abs(previous(i) - current(j)) / scale;
                    if useVectors
                        a = Vprevious(:, i);
                        b = Vcurrent(:, j);
                        denominator = norm(a) * norm(b);
                        if denominator > 0
                            mac = abs(a' * b) / denominator;
                            cost(i, j) = cost(i, j) + ...
                                obj.EigenvectorWeight * (1 - min(mac, 1));
                        end
                    end
                end
            end
        end

        function assignment = minimumAssignment(~, cost)
            % Shortest augmenting-path form of the Hungarian algorithm.
            [n, m] = size(cost);
            if n ~= m
                error('BifurcationDetector_v3:AssignmentDimension', ...
                    'Multiplier matching requires a square cost matrix.');
            end
            if any(~isfinite(cost(:)))
                error('BifurcationDetector_v3:NonfiniteMatchingCost', ...
                    'Hungarian multiplier matching requires finite costs.');
            end
            u = zeros(n + 1, 1);
            v = zeros(m + 1, 1);
            p = zeros(m + 1, 1);
            way = zeros(m + 1, 1);
            for i = 1:n
                p(1) = i;
                j0 = 1;
                minv = Inf(m + 1, 1);
                used = false(m + 1, 1);
                while true
                    used(j0) = true;
                    i0 = p(j0);
                    delta = Inf;
                    j1 = 1;
                    for j = 2:m + 1
                        if ~used(j)
                            current = cost(i0, j - 1) - u(i0 + 1) - v(j);
                            if current < minv(j)
                                minv(j) = current;
                                way(j) = j0;
                            end
                            if minv(j) < delta
                                delta = minv(j);
                                j1 = j;
                            end
                        end
                    end
                    for j = 1:m + 1
                        if used(j)
                            u(p(j) + 1) = u(p(j) + 1) + delta;
                            v(j) = v(j) - delta;
                        else
                            minv(j) = minv(j) - delta;
                        end
                    end
                    j0 = j1;
                    if p(j0) == 0
                        break
                    end
                end
                while true
                    j1 = way(j0);
                    p(j0) = p(j1);
                    j0 = j1;
                    if j0 == 1
                        break
                    end
                end
            end
            assignment = zeros(n, 1);
            for j = 2:m + 1
                if p(j) > 0
                    assignment(p(j)) = j - 1;
                end
            end
        end

        function [tf, theta] = crossingFraction(obj, left, right)
            scale = max([1, abs(left), abs(right)]);
            tolerance = obj.CrossingTolerance * scale;
            tf = isfinite(left) && isfinite(right) && ...
                left * right <= 0 && ...
                max(abs([left, right])) > tolerance && ...
                abs(right - left) > tolerance;
            if tf
                theta = -left / (right - left);
                theta = min(max(theta, 0), 1);
            else
                theta = NaN;
            end
        end

        function tf = isRealPair(obj, left, right)
            scale = 1 + max(abs([left, right]));
            tf = abs(imag(left)) <= obj.ImaginaryTolerance * scale && ...
                abs(imag(right)) <= obj.ImaginaryTolerance * scale;
        end

        function tf = isPositiveComplexTrack(obj, left, right)
            scale = 1 + max(abs([left, right]));
            genuinelyComplex = max(abs(imag([left, right]))) > ...
                obj.ImaginaryTolerance * scale;
            tf = genuinelyComplex && mean(imag([left, right])) > 0;
        end

        function tf = hasConjugateCompanion(obj, lambda, track, interval)
            tf = false;
            for other = 1:size(lambda, 1)
                if other == track
                    continue
                end
                leftScale = 1 + abs(lambda(track, interval));
                rightScale = 1 + abs(lambda(track, interval + 1));
                leftMatch = abs(lambda(other, interval) - ...
                    conj(lambda(track, interval))) <= obj.PairTolerance * leftScale;
                rightMatch = abs(lambda(other, interval + 1) - ...
                    conj(lambda(track, interval + 1))) <= obj.PairTolerance * rightScale;
                if leftMatch && rightMatch
                    tf = true;
                    return
                end
            end
        end

        function event = makeEvent(~, type, track, interval, theta, ...
                left, right, tracks, reliable)
            event = BifurcationDetector_v3.emptyEventStatic();
            event.type = type;
            event.trackIndex = track;
            event.leftIndex = interval;
            event.rightIndex = interval + 1;
            event.fraction = theta;
            event.leftCoordinate = tracks.coordinate(interval);
            event.rightCoordinate = tracks.coordinate(interval + 1);
            event.location = (1 - theta) * event.leftCoordinate + ...
                theta * event.rightCoordinate;
            event.parameter = event.location;
            if ~isempty(tracks.parameters)
                event.parameterVector = (1 - theta) * ...
                    tracks.parameters(:, interval) + theta * ...
                    tracks.parameters(:, interval + 1);
            end
            event.multiplierLeft = left;
            event.multiplierRight = right;
            event.multiplierEstimate = (1 - theta) * left + theta * right;
            event.direction = sign(abs(right) - abs(left));
            if strcmp(type, 'unit_multiplier_candidate')
                event.direction = sign(real(right) - real(left));
            elseif strcmp(type, 'period_doubling_candidate')
                event.direction = sign(real(right) - real(left));
            end
            event.topologyCompatible = true;
            if isfield(tracks, 'topologyCompatible') && ...
                    numel(tracks.topologyCompatible) >= interval
                event.topologyCompatible = ...
                    logical(tracks.topologyCompatible(interval));
            end
            event.reliable = reliable && event.topologyCompatible;
            event.bracketWidth = abs(event.rightCoordinate - event.leftCoordinate);
        end

        function compatible = topologyCompatibility(obj, data, count)
            compatible = true(1, max(0, count - 1));
            if count < 2 || ~isstruct(data)
                return
            end
            signatures = obj.member(data, 'cyclic_signature', {});
            multiplicity = obj.member(data, 'return_multiplicity', []);
            boundaries = obj.member(data, 'topology_boundary', []);
            points = obj.member(data, 'points', []);
            if isempty(signatures) && ~isempty(points) && ...
                    isfield(points, 'cyclic_signature')
                signatures = {points.cyclic_signature};
            end
            if isempty(multiplicity) && ~isempty(points) && ...
                    isfield(points, 'return_multiplicity')
                multiplicity = [points.return_multiplicity];
            end
            if isempty(boundaries) && ~isempty(points) && ...
                    isfield(points, 'topologyBoundary')
                boundaries = [points.topologyBoundary];
            end
            for index = 1:numel(compatible)
                if numel(signatures) >= index + 1
                    compatible(index) = compatible(index) && ...
                        isequal(string(signatures{index}), ...
                            string(signatures{index + 1}));
                end
                if numel(multiplicity) >= index + 1
                    compatible(index) = compatible(index) && ...
                        isequal(multiplicity(index), multiplicity(index + 1));
                end
                if numel(boundaries) >= index + 1
                    compatible(index) = compatible(index) && ...
                        ~logical(boundaries(index + 1));
                end
            end
        end

        function events = appendUnique(obj, events, candidate)
            for i = 1:numel(events)
                sameType = strcmp(events(i).type, candidate.type);
                sameTrack = events(i).trackIndex == candidate.trackIndex;
                scale = 1 + abs(candidate.location);
                sameLocation = abs(events(i).location - candidate.location) <= ...
                    obj.CrossingTolerance * scale;
                if sameType && sameTrack && sameLocation
                    return
                end
            end
            events(end + 1) = candidate;
        end

        function event = emptyEvent(~)
            event = BifurcationDetector_v3.emptyEventStatic();
        end

        function value = member(~, source, name, default)
            value = default;
            if isstruct(source) && isfield(source, name)
                value = source.(name);
            elseif isobject(source) && isprop(source, name)
                value = source.(name);
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
                error('BifurcationDetector_v3:NameValue', ...
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
                error('BifurcationDetector_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(list{match}) = value;
        end
    end

    methods (Static, Access = private)
        function event = emptyEventStatic()
            event = struct( ...
                'type', '', 'trackIndex', [], 'leftIndex', [], ...
                'rightIndex', [], 'fraction', NaN, ...
                'leftCoordinate', NaN, 'rightCoordinate', NaN, ...
                'location', NaN, 'parameter', NaN, ...
                'parameterVector', [], 'multiplierLeft', NaN, ...
                'multiplierRight', NaN, 'multiplierEstimate', NaN, ...
                'direction', 0, 'reliable', true, ...
                'topologyCompatible', true, 'bracketWidth', NaN);
        end
    end
end
