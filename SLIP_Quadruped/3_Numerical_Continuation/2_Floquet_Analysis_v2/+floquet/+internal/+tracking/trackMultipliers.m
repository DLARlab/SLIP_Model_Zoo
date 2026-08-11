function [Tracks, Diagnostics] = trackMultipliers(Multipliers, Eigenvectors, Options)
%TRACKMULTIPLIERS Globally match Floquet multipliers at adjacent branch points.
%
%   TRACKS = TRACKMULTIPLIERS(LAMBDA, V) accepts either an nMode-by-nPoint
%   matrix (or a cell array with one multiplier vector per point) and a
%   cell array of eigenvector matrices.  At every adjacent pair of valid
%   continuation points, a minimum-cost *global* assignment is computed.
%   The cost combines a scaled multiplier distance with the lack of modal
%   assurance (eigenvector overlap).  This avoids the duplicate matches
%   produced by nearest-neighbour/greedy sorting near clustered roots.
%
%   [TRACKS, DIAGNOSTICS] = TRACKMULTIPLIERS(..., OPTIONS) supports:
%       MultiplierWeight       nonnegative scalar, default 1
%       EigenvectorWeight      nonnegative scalar, default 0.25
%       Reliability            logical vector, one value per point
%       IntervalReliability    logical vector, one per adjacent interval
%       InitialOrder           permutation used at the first point
%       ComputeAssignmentGap   compute exact second-best gap, default true
%       InvalidCost            finite replacement for forbidden costs
%
%   The eigenvectors at point k are phase aligned with the matched vectors
%   at point k-1.  Consequently, interpolating a critical eigenvector along
%   a short continuation interval is meaningful up to eigenspace changes.
%
%   A struct array of Floquet results is also accepted when each element
%   contains Multipliers/multipliers and Eigenvectors/eigenvectors fields.

    if nargin < 2
        Eigenvectors = [];
    end
    if nargin < 3
        Options = struct();
    end
    if isstruct(Eigenvectors) && nargin < 3 && ...
            ~isFloquetResultStruct(Eigenvectors)
        Options = Eigenvectors;
        Eigenvectors = [];
    end

    opts = defaultOptions();
    opts = mergeOptions(opts, Options);
    validateOptions(opts);

    [lambdaSeries, vectorSeries, embeddedReliability] = ...
        unpackInput(Multipliers, Eigenvectors);
    nPoint = numel(lambdaSeries);
    if nPoint == 0
        Tracks = emptyTracks();
        Diagnostics = Tracks.Diagnostics;
        return
    end

    nMode = numel(lambdaSeries{1});
    if nMode == 0
        error('TrackMultipliers:EmptySpectrum', ...
            'Every continuation point must contain at least one multiplier.');
    end
    for k = 1:nPoint
        lambdaSeries{k} = lambdaSeries{k}(:);
        if numel(lambdaSeries{k}) ~= nMode
            error('TrackMultipliers:ChangingDimension', ...
                ['The reduced Poincare-map dimension changes at point %d. ' ...
                 'Multiplier tracking is undefined across that change.'], k);
        end
    end

    reliability = embeddedReliability;
    if ~isempty(opts.Reliability)
        reliability = logical(opts.Reliability(:).');
    end
    if isempty(reliability)
        reliability = true(1, nPoint);
    end
    if numel(reliability) ~= nPoint
        error('TrackMultipliers:ReliabilitySize', ...
            'Reliability must contain one value per continuation point.');
    end
    intervalReliability = true(1, max(0, nPoint - 1));
    if ~isempty(opts.IntervalReliability)
        suppliedIntervals = opts.IntervalReliability(:).';
        if numel(suppliedIntervals) ~= nPoint - 1 || ...
                ~(islogical(suppliedIntervals) || isnumeric(suppliedIntervals)) || ...
                any(~isfinite(double(suppliedIntervals))) || ...
                any(~ismember(double(suppliedIntervals), [0 1]))
            error('TrackMultipliers:IntervalReliabilitySize', ...
                ['IntervalReliability must contain one logical value per ' ...
                 'adjacent continuation interval.']);
        end
        intervalReliability = logical(suppliedIntervals);
    end

    initialOrder = (1:nMode).';
    if ~isempty(opts.InitialOrder)
        initialOrder = opts.InitialOrder(:);
        if numel(initialOrder) ~= nMode || ...
                ~isequal(sort(initialOrder), (1:nMode).')
            error('TrackMultipliers:InitialOrder', ...
                'InitialOrder must be a permutation of 1:nMode.');
        end
    end

    ordered = complex(NaN(nMode, nPoint), NaN(nMode, nPoint));
    ordered(:, 1) = lambdaSeries{1}(initialOrder);
    orderedVectors = cell(1, nPoint);
    if ~isempty(vectorSeries{1})
        orderedVectors{1} = normalizeVectorMatrix( ...
            vectorSeries{1}(:, initialOrder), nMode);
    end

    assignments = NaN(nMode, nPoint);
    assignments(:, 1) = initialOrder;
    costMatrices = cell(1, nPoint);
    overlapMatrices = cell(1, nPoint);
    distanceMatrices = cell(1, nPoint);
    phaseFactors = cell(1, nPoint);
    selectedCost = NaN(nMode, nPoint);
    selectedOverlap = NaN(nMode, nPoint);
    selectedDistance = NaN(nMode, nPoint);
    totalCost = NaN(1, nPoint);
    assignmentGap = NaN(1, nPoint);
    validPoint = reliability & cellfun(@allFinite, lambdaSeries);
    restart = false(1, nPoint);

    if ~validPoint(1)
        reliability(1) = false;
    end

    for k = 2:nPoint
        current = lambdaSeries{k};
        if ~validPoint(k) || ~validPoint(k - 1) || ...
                ~intervalReliability(k - 1)
            % There is intentionally no track across an invalid point or
            % interval. A deterministic restart permits later valid segments
            % to be analysed without pretending continuity through a rejected
            % map, source-column gap, or event-topology change.
            ordered(:, k) = current;
            assignments(:, k) = (1:nMode).';
            restart(k) = true;
            if ~isempty(vectorSeries{k})
                orderedVectors{k} = normalizeVectorMatrix( ...
                    vectorSeries{k}, nMode);
            end
            continue
        end

        previousVectors = orderedVectors{k - 1};
        currentVectors = vectorSeries{k};
        if ~isempty(currentVectors)
            currentVectors = normalizeVectorMatrix(currentVectors, nMode);
        end
        [cost, distance, overlap] = matchingCost( ...
            ordered(:, k - 1), current, previousVectors, currentVectors, opts);
        assignment = minimumAssignment(cost, opts.InvalidCost);
        linear = sub2ind([nMode, nMode], (1:nMode).', assignment);

        assignments(:, k) = assignment;
        ordered(:, k) = current(assignment);
        costMatrices{k} = cost;
        distanceMatrices{k} = distance;
        overlapMatrices{k} = overlap;
        selectedCost(:, k) = cost(linear);
        selectedDistance(:, k) = distance(linear);
        selectedOverlap(:, k) = overlap(linear);
        totalCost(k) = sum(cost(linear));
        if opts.ComputeAssignmentGap && nMode > 1
            assignmentGap(k) = secondBestGap( ...
                cost, assignment, totalCost(k), opts.InvalidCost);
        end

        if ~isempty(currentVectors)
            currentVectors = currentVectors(:, assignment);
            [currentVectors, factors] = phaseAlignVectors( ...
                previousVectors, currentVectors);
            orderedVectors{k} = currentVectors;
            phaseFactors{k} = factors;
        end
    end

    Diagnostics = struct();
    Diagnostics.ValidPoint = validPoint;
    Diagnostics.Reliability = reliability;
    Diagnostics.IntervalReliability = intervalReliability;
    Diagnostics.Restart = restart;
    Diagnostics.CostMatrices = costMatrices;
    Diagnostics.MultiplierDistanceMatrices = distanceMatrices;
    Diagnostics.EigenvectorOverlapMatrices = overlapMatrices;
    Diagnostics.SelectedCost = selectedCost;
    Diagnostics.SelectedMultiplierDistance = selectedDistance;
    Diagnostics.SelectedEigenvectorOverlap = selectedOverlap;
    Diagnostics.TotalAssignmentCost = totalCost;
    Diagnostics.SecondBestAssignmentGap = assignmentGap;
    Diagnostics.PhaseFactors = phaseFactors;
    Diagnostics.Options = opts;

    Tracks = struct();
    Tracks.Multipliers = ordered;
    Tracks.Eigenvectors = orderedVectors;
    Tracks.Assignments = assignments;
    Tracks.PointReliability = validPoint;
    Tracks.IsTracked = true;
    Tracks.Diagnostics = Diagnostics;
    % Lower-case aliases make the utility convenient with older result
    % structs without changing the legacy implementation.
    Tracks.multipliers = ordered;
    Tracks.eigenvectors = orderedVectors;
    Tracks.assignments = assignments;
end

function opts = defaultOptions()
    opts = struct();
    opts.MultiplierWeight = 1;
    opts.EigenvectorWeight = 0.25;
    opts.Reliability = [];
    opts.IntervalReliability = [];
    opts.InitialOrder = [];
    opts.ComputeAssignmentGap = true;
    opts.InvalidCost = 1e12;
end

function opts = mergeOptions(opts, supplied)
    if isempty(supplied)
        return
    end
    if ~isstruct(supplied) || numel(supplied) ~= 1
        error('TrackMultipliers:OptionsType', ...
            'Options must be a scalar struct.');
    end
    names = fieldnames(supplied);
    defaults = fieldnames(opts);
    for i = 1:numel(names)
        hit = find(strcmpi(names{i}, defaults), 1);
        if isempty(hit)
            error('TrackMultipliers:UnknownOption', ...
                'Unknown option "%s".', names{i});
        end
        opts.(defaults{hit}) = supplied.(names{i});
    end
end

function validateOptions(opts)
    weights = [opts.MultiplierWeight, opts.EigenvectorWeight];
    if ~isnumeric(weights) || any(~isfinite(weights)) || ...
            any(weights < 0) || all(weights == 0)
        error('TrackMultipliers:Weights', ...
            'Matching weights must be finite, nonnegative, and not both zero.');
    end
    if ~isscalar(opts.ComputeAssignmentGap)
        error('TrackMultipliers:ComputeAssignmentGap', ...
            'ComputeAssignmentGap must be scalar.');
    end
    if ~isscalar(opts.InvalidCost) || ~isfinite(opts.InvalidCost) || ...
            opts.InvalidCost <= 0
        error('TrackMultipliers:InvalidCost', ...
            'InvalidCost must be a positive finite scalar.');
    end
end

function [series, vectors, reliability] = unpackInput(input, vectorInput)
    reliability = [];
    embeddedVectors = [];
    if isnumeric(input)
        if isvector(input)
            input = input(:);
        end
        series = arrayfun(@(k) input(:, k), 1:size(input, 2), ...
            'UniformOutput', false);
    elseif iscell(input)
        series = input(:).';
    elseif isstruct(input)
        [series, embeddedVectors, reliability] = unpackStruct(input);
    else
        error('TrackMultipliers:InputType', ...
            'Multipliers must be numeric, a cell array, or Floquet structs.');
    end

    if isempty(vectorInput)
        vectorInput = embeddedVectors;
    end
    vectors = unpackVectors(vectorInput, numel(series));
end

function [series, vectors, reliability] = unpackStruct(input)
    if numel(input) > 1
        series = cell(1, numel(input));
        vectors = cell(1, numel(input));
        reliability = true(1, numel(input));
        for k = 1:numel(input)
            series{k} = firstField(input(k), ...
                {'Multipliers', 'multipliers', 'FloquetMultipliers', ...
                 'floquetMultipliers'});
            vectors{k} = firstField(input(k), ...
                {'Eigenvectors', 'eigenvectors', 'FloquetEigenvectors', ...
                 'floquetEigenvectors'}, []);
            reliability(k) = logical(firstField(input(k), ...
                {'Reliable', 'reliable', 'Valid', 'valid'}, true));
        end
        return
    end

    values = firstField(input, ...
        {'Multipliers', 'multipliers', 'FloquetMultipliers', ...
         'floquetMultipliers'});
    if iscell(values)
        series = values(:).';
    elseif isnumeric(values)
        if isvector(values)
            values = values(:);
        end
        series = arrayfun(@(k) values(:, k), 1:size(values, 2), ...
            'UniformOutput', false);
    else
        error('TrackMultipliers:StructMultipliers', ...
            'The multiplier field must be numeric or a cell array.');
    end
    vectors = firstField(input, {'Eigenvectors', 'eigenvectors'}, []);
    reliability = firstField(input, ...
        {'PointReliability', 'Reliability', 'reliability'}, []);
end

function vectors = unpackVectors(input, nPoint)
    vectors = cell(1, nPoint);
    if isempty(input)
        return
    end
    if iscell(input)
        if numel(input) ~= nPoint
            error('TrackMultipliers:EigenvectorCount', ...
                'There must be one eigenvector matrix per branch point.');
        end
        vectors = input(:).';
    elseif isnumeric(input) && ndims(input) == 3
        if size(input, 3) ~= nPoint
            error('TrackMultipliers:EigenvectorCount', ...
                'The third eigenvector-array dimension must count points.');
        end
        for k = 1:nPoint
            vectors{k} = input(:, :, k);
        end
    elseif isnumeric(input) && nPoint == 1
        vectors{1} = input;
    else
        error('TrackMultipliers:EigenvectorType', ...
            'Eigenvectors must be a cell array or a 3-D numeric array.');
    end
end

function value = firstField(source, names, default)
    if nargin < 3
        default = [];
    end
    value = default;
    for i = 1:numel(names)
        if isfield(source, names{i})
            value = source.(names{i});
            return
        end
    end
    if nargin < 3
        error('TrackMultipliers:MissingField', ...
            'A Floquet result does not contain a multiplier field.');
    end
end

function tf = isFloquetResultStruct(value)
    tf = isstruct(value) && any(isfield(value, ...
        {'Multipliers', 'multipliers', 'Eigenvectors', 'eigenvectors'}));
end

function tf = allFinite(value)
    tf = isnumeric(value) && all(isfinite(real(value(:)))) && ...
        all(isfinite(imag(value(:))));
end

function matrix = normalizeVectorMatrix(matrix, nMode)
    if ~isnumeric(matrix) || size(matrix, 2) ~= nMode
        error('TrackMultipliers:EigenvectorDimension', ...
            'Each eigenvector matrix must have nMode columns.');
    end
    for j = 1:nMode
        column = matrix(:, j);
        lengthColumn = norm(column);
        if ~isfinite(lengthColumn) || lengthColumn == 0
            matrix(:, j) = NaN(size(column));
            continue
        end
        column = column / lengthColumn;
        [~, pivot] = max(abs(column));
        if abs(column(pivot)) > 0
            column = column * exp(-1i * angle(column(pivot)));
        end
        if isreal(matrix) || norm(imag(column)) <= ...
                100 * eps * max(1, norm(real(column)))
            column = real(column);
        end
        matrix(:, j) = column;
    end
end

function [cost, distance, overlap] = matchingCost( ...
        previous, current, previousVectors, currentVectors, opts)
    nMode = numel(previous);
    distance = zeros(nMode, nMode);
    overlap = NaN(nMode, nMode);
    useVectors = ~isempty(previousVectors) && ~isempty(currentVectors) && ...
        size(previousVectors, 2) == nMode && ...
        size(currentVectors, 2) == nMode && ...
        size(previousVectors, 1) == size(currentVectors, 1);

    for i = 1:nMode
        for j = 1:nMode
            scale = max([1, abs(previous(i)), abs(current(j))]);
            distance(i, j) = abs(previous(i) - current(j)) / scale;
            if useVectors
                a = previousVectors(:, i);
                b = currentVectors(:, j);
                denominator = norm(a) * norm(b);
                if denominator > 0 && isfinite(denominator)
                    overlap(i, j) = min(1, abs(a' * b) / denominator);
                end
            end
        end
    end

    cost = opts.MultiplierWeight * distance;
    if useVectors
        modalPenalty = 1 - overlap;
        modalPenalty(~isfinite(modalPenalty)) = 1;
        cost = cost + opts.EigenvectorWeight * modalPenalty;
    end
    cost(~isfinite(cost)) = opts.InvalidCost;
end

function assignment = minimumAssignment(cost, invalidCost)
    % Shortest augmenting-path implementation of the Hungarian algorithm.
    [nRow, nColumn] = size(cost);
    if nRow ~= nColumn
        error('TrackMultipliers:AssignmentDimension', ...
            'The multiplier assignment cost must be square.');
    end
    if nRow == 1
        assignment = 1;
        return
    end
    cost(~isfinite(cost)) = invalidCost;
    u = zeros(nRow + 1, 1);
    v = zeros(nColumn + 1, 1);
    p = zeros(nColumn + 1, 1);
    way = zeros(nColumn + 1, 1);

    for i = 1:nRow
        p(1) = i;
        j0 = 1;
        minv = Inf(nColumn + 1, 1);
        used = false(nColumn + 1, 1);
        while true
            used(j0) = true;
            i0 = p(j0);
            delta = Inf;
            j1 = 1;
            for j = 2:nColumn + 1
                if ~used(j)
                    candidate = cost(i0, j - 1) - u(i0 + 1) - v(j);
                    if candidate < minv(j)
                        minv(j) = candidate;
                        way(j) = j0;
                    end
                    if minv(j) < delta
                        delta = minv(j);
                        j1 = j;
                    end
                end
            end
            if ~isfinite(delta)
                error('TrackMultipliers:NoAssignment', ...
                    'No finite global multiplier assignment exists.');
            end
            for j = 1:nColumn + 1
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

    assignment = zeros(nRow, 1);
    for j = 2:nColumn + 1
        if p(j) > 0
            assignment(p(j)) = j - 1;
        end
    end
end

function gap = secondBestGap(cost, assignment, bestCost, invalidCost)
    nMode = numel(assignment);
    alternative = Inf;
    for i = 1:nMode
        modified = cost;
        modified(i, assignment(i)) = invalidCost;
        trial = minimumAssignment(modified, invalidCost);
        linear = sub2ind(size(cost), (1:nMode).', trial);
        trialCost = sum(cost(linear));
        if all(trialCost < invalidCost)
            alternative = min(alternative, trialCost);
        end
    end
    if isfinite(alternative)
        gap = max(0, alternative - bestCost);
    else
        gap = Inf;
    end
end

function [vectors, factors] = phaseAlignVectors(previous, vectors)
    nMode = size(vectors, 2);
    factors = ones(nMode, 1);
    if isempty(previous) || size(previous, 1) ~= size(vectors, 1) || ...
            size(previous, 2) ~= nMode
        return
    end
    for j = 1:nMode
        a = previous(:, j);
        b = vectors(:, j);
        inner = a' * b;
        if isfinite(real(inner)) && isfinite(imag(inner)) && abs(inner) > 0
            factors(j) = exp(-1i * angle(inner));
            vectors(:, j) = b * factors(j);
            if isreal(a) && norm(imag(vectors(:, j))) <= ...
                    100 * eps * max(1, norm(real(vectors(:, j))))
                vectors(:, j) = real(vectors(:, j));
            end
        end
    end
end

function tracks = emptyTracks()
    diagnostics = struct('ValidPoint', [], 'Reliability', [], ...
        'IntervalReliability', [], ...
        'Restart', [], 'CostMatrices', {{}}, ...
        'MultiplierDistanceMatrices', {{}}, ...
        'EigenvectorOverlapMatrices', {{}}, 'SelectedCost', [], ...
        'SelectedMultiplierDistance', [], ...
        'SelectedEigenvectorOverlap', [], 'TotalAssignmentCost', [], ...
        'SecondBestAssignmentGap', [], 'PhaseFactors', {{}}, ...
        'Options', struct());
    tracks = struct('Multipliers', [], 'Eigenvectors', {{}}, ...
        'Assignments', [], 'PointReliability', [], 'IsTracked', true, ...
        'Diagnostics', diagnostics, 'multipliers', [], ...
        'eigenvectors', {{}}, 'assignments', []);
end
