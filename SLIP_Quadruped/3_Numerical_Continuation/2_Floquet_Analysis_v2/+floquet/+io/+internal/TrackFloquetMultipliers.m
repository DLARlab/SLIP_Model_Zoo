function [trackedEigenvalues, trackedEigenvectors, trackingInfo] = ...
        TrackFloquetMultipliers(eigenvalues, eigenvectors, options)
%TRACKFLOQUETMULTIPLIERS Track reduced Poincare-map eigendata along a branch.
%
%   [LAMBDA_TRACKED,V_TRACKED,INFO] = TRACKFLOQUETMULTIPLIERS(LAMBDA,V)
%   gives the multipliers at every continuation point a consistent mode
%   ordering.  Numeric LAMBDA is nMode-by-nPoint.  A cell array is also
%   accepted, with one numeric eigenvalue vector per point.  V may be an
%   nState-by-nMode-by-nPoint numeric array, a cell array of eigenvector
%   matrices, a single matrix for a one-point input, or empty.
%
%   The primary adjacent-point cost is exactly
%
%       C(i,j) = abs(LAMBDA_TRACKED(i,k-1) - LAMBDA_RAW(j,k)).
%
%   A global minimum-cost assignment is found with an in-file Hungarian
%   implementation; no Statistics and Machine Learning Toolbox is needed.
%   If both endpoints have complete and consistent real/conjugate-pair
%   topology, matching is globally minimized subject to preserving those
%   pairs.  INFO also records the unconstrained optimum and its cost, so
%   any cost incurred by the pair constraint is explicit.  At a
%   real/complex transition the routine deterministically falls back to
%   the unconstrained assignment.
%
%   Eigenvectors are reordered after the eigenvalue assignment.  Their
%   complex phases are aligned to the preceding point.  Conjugate partners
%   share a coordinated phase convention, avoiding independent phase
%   flips inside a pair.  Magnitudes and directions are otherwise left
%   unchanged.
%
%   OPTIONS is a scalar structure with these fields (case-insensitive;
%   underscore-separated aliases are accepted):
%       Reliability                 one logical per point (default true)
%       IntervalReliability         one logical per adjacent interval
%       InitialOrder                first-point permutation (default input)
%       PreserveConjugatePairs      logical scalar (default true)
%       ConjugateTolerance          scaled pair tolerance (default 1e-8)
%       RealTolerance               scaled imaginary tolerance (default 1e-10)
%       PhaseAlignEigenvectors      logical scalar (default true)
%       CoordinateConjugatePhases  logical scalar (default true)
%       ComputeAssignmentGap        logical scalar (default true)
%       RestartOrder                'canonical' or 'input' (default canonical)
%       InvalidCost                 finite pairing sentinel (default 1e12)
%
%   Unreliable or nonfinite spectra are not connected to adjacent points.
%   Tracking restarts deterministically after each such point.  INFO
%   contains assignments, the raw C matrices, selected costs, exact
%   second-best assignment gaps, reliability/restart flags, conjugate-pair
%   topology, pair-constraint diagnostics, and applied vector phases.
%
%   Exact repeated multipliers have no unique scalar-mode identity.  A
%   zero assignment gap reports that ambiguity.  Within a numerically
%   exact repeated cluster, a unitary Procrustes rotation aligns the
%   invariant subspace; real-mode assignment ties additionally use vector
%   overlap. Repeated conjugate subspaces are coordinated as a pair.

    if nargin < 1
        error('TrackFloquetMultipliers:NotEnoughInputs', ...
            'An eigenvalue series is required.');
    end
    if nargin < 2
        eigenvectors = [];
    end
    if nargin < 3
        options = struct();
    end
    if nargin == 2 && isstruct(eigenvectors)
        options = eigenvectors;
        eigenvectors = [];
    end

    options = resolveOptions(options);
    [valueSeries, valueFormat] = unpackEigenvalues(eigenvalues);
    nPoint = numel(valueSeries);
    nMode = valueFormat.ModeCount;
    [vectorSeries, vectorFormat] = unpackEigenvectors( ...
        eigenvectors, nPoint, nMode);

    if nPoint == 0
        trackedEigenvalues = packEigenvalues(valueSeries, valueFormat);
        trackedEigenvectors = packEigenvectors(vectorSeries, vectorFormat);
        trackingInfo = emptyTrackingInfo(options, nMode);
        return
    end

    requestedReliability = resolveReliability(options.Reliability, nPoint);
    intervalReliability = resolveIntervalReliability( ...
        options.IntervalReliability, nPoint);
    finiteSpectrum = false(1, nPoint);
    rawConjugateInfo = cell(1, nPoint);
    for k = 1:nPoint
        valueSeries{k} = valueSeries{k}(:);
        finiteSpectrum(k) = allFinite(valueSeries{k});
        rawConjugateInfo{k} = classifyConjugates(valueSeries{k}, options);
    end
    validPoint = requestedReliability & finiteSpectrum;

    trackedValues = complex(NaN(nMode, nPoint), NaN(nMode, nPoint));
    trackedVectorSeries = cell(1, nPoint);
    assignments = NaN(nMode, nPoint);
    unconstrainedAssignments = NaN(nMode, nPoint);
    rawCostMatrices = cell(1, nPoint);
    selectedCosts = NaN(nMode, nPoint);
    totalAssignmentCost = NaN(1, nPoint);
    unconstrainedTotalCost = NaN(1, nPoint);
    assignmentGap = NaN(1, nPoint);
    pairTopologyConsistent = false(1, nPoint);
    pairConstraintApplied = false(1, nPoint);
    pairConstraintCostPenalty = NaN(1, nPoint);
    topologyFallback = false(1, nPoint);
    restart = false(1, nPoint);
    segmentStart = false(1, nPoint);
    status = repmat({''}, 1, nPoint);
    trackedConjugateInfo = cell(1, nPoint);
    conjugateTransitions = cell(1, nPoint);
    phaseFactors = cell(1, nPoint);
    phaseMethods = cell(1, nPoint);
    eigenvectorColumnValid = false(nMode, nPoint);
    eigenvectorRestart = false(1, nPoint);
    conjugatePhaseCoordinated = false(1, nPoint);
    overlapTieBreakApplied = false(1, nPoint);

    for k = 1:nPoint
        current = valueSeries{k};
        isAdjacentTrack = k > 1 && validPoint(k - 1) && validPoint(k) && ...
            intervalReliability(k - 1);

        if k == 1
            order = initialPointOrder(current, rawConjugateInfo{k}, ...
                validPoint(k), options);
            restart(k) = true;
            segmentStart(k) = validPoint(k);
            if validPoint(k)
                status{k} = 'initial';
            else
                status{k} = 'invalid';
            end
        elseif ~isAdjacentTrack
            order = restartPointOrder(current, rawConjugateInfo{k}, options);
            restart(k) = true;
            segmentStart(k) = validPoint(k) && ...
                (~validPoint(k - 1) || ~intervalReliability(k - 1));
            if validPoint(k)
                status{k} = 'restart';
            else
                status{k} = 'invalid';
            end
        else
            previous = trackedValues(:, k - 1);
            cost = abs(bsxfun(@minus, previous, current(:).'));
            if any(~isfinite(cost(:)))
                error('TrackFloquetMultipliers:CostOverflow', ...
                    ['The finite spectra at points %d and %d produce a ' ...
                     'nonfinite absolute-distance cost.  Rescale the ' ...
                     'problem before tracking.'], k - 1, k);
            end
            rawCostMatrices{k} = cost;

            [unconstrained, unconstrainedDetail] = solveUnconstrained( ...
                cost, current);
            if ~unconstrainedDetail.Feasible
                error('TrackFloquetMultipliers:NoAssignment', ...
                    'No global assignment exists between points %d and %d.', ...
                    k - 1, k);
            end
            [unconstrained, overlapUsed] = RefineRepeatedRealAssignment( ...
                unconstrained, current, trackedVectorSeries{k - 1}, ...
                vectorSeries{k}, cost, options);
            overlapTieBreakApplied(k) = overlapUsed;
            unconstrainedAssignments(:, k) = unconstrained;
            unconstrainedTotalCost(k) = assignmentCost(cost, unconstrained);

            previousPairInfo = trackedConjugateInfo{k - 1};
            currentPairInfo = rawConjugateInfo{k};
            [consistent, topologyReason] = conjugateTopologyIsConsistent( ...
                previousPairInfo, currentPairInfo);
            usePairConstraint = options.PreserveConjugatePairs && ...
                consistent && previousPairInfo.PairCount > 0;
            attemptedPairPenalty = NaN;

            if usePairConstraint
                [constrainedOrder, constrainedDetail] = solvePairConstrained( ...
                    cost, previousPairInfo, currentPairInfo);
                if constrainedDetail.Feasible
                    penalty = assignmentCost(cost, constrainedOrder) - ...
                        unconstrainedTotalCost(k);
                else
                    penalty = Inf;
                end
                attemptedPairPenalty = penalty;
                penaltyTolerance = max(100 * eps * ...
                    (1 + unconstrainedTotalCost(k)), ...
                    options.ConjugateTolerance * ...
                    (1 + unconstrainedTotalCost(k)));
                if ~constrainedDetail.Feasible || penalty > penaltyTolerance
                    consistent = false;
                    topologyReason = ...
                        'pair-constraint-has-material-assignment-penalty';
                    usePairConstraint = false;
                else
                    order = constrainedOrder;
                    assignmentDetail = constrainedDetail;
                    pairConstraintApplied(k) = true;
                    pairConstraintCostPenalty(k) = penalty;
                    status{k} = 'tracked-pair-preserving';
                end
            end
            if ~usePairConstraint
                order = unconstrained;
                assignmentDetail = unconstrainedDetail;
                if isnan(attemptedPairPenalty)
                    pairConstraintCostPenalty(k) = 0;
                else
                    pairConstraintCostPenalty(k) = attemptedPairPenalty;
                end
                topologyFallback(k) = options.PreserveConjugatePairs && ...
                    ~consistent && (previousPairInfo.PairCount > 0 || ...
                    currentPairInfo.PairCount > 0);
                if topologyFallback(k)
                    status{k} = 'tracked-topology-transition';
                else
                    status{k} = 'tracked';
                end
            end
            [order, selectedOverlapUsed] = RefineRepeatedRealAssignment( ...
                order, current, trackedVectorSeries{k - 1}, ...
                vectorSeries{k}, cost, options);
            overlapTieBreakApplied(k) = overlapTieBreakApplied(k) || ...
                selectedOverlapUsed;
            pairTopologyConsistent(k) = consistent;

            linear = sub2ind([nMode, nMode], (1:nMode).', order);
            selectedCosts(:, k) = cost(linear);
            totalAssignmentCost(k) = sum(selectedCosts(:, k));
            if options.ComputeAssignmentGap
                assignmentGap(k) = secondBestAssignmentGap( ...
                    cost, order, totalAssignmentCost(k), ...
                    previousPairInfo, currentPairInfo, current, ...
                    usePairConstraint);
            end

            transition = struct();
            transition.Consistent = consistent;
            transition.Reason = topologyReason;
            transition.ConstraintApplied = usePairConstraint;
            transition.PreviousPairs = previousPairInfo.Pairs;
            transition.CurrentPairs = currentPairInfo.Pairs;
            transition.PairBlockAssignment = assignmentDetail.PairBlockAssignment;
            transition.PairOrientations = assignmentDetail.PairOrientations;
            transition.UnconstrainedAssignment = unconstrained;
            transition.UnconstrainedTotalCost = unconstrainedTotalCost(k);
            transition.SelectedTotalCost = totalAssignmentCost(k);
            transition.ConstraintCostPenalty = pairConstraintCostPenalty(k);
            conjugateTransitions{k} = transition;
        end

        order = order(:);
        assignments(:, k) = order;
        if ~isAdjacentTrack
            unconstrainedAssignments(:, k) = order;
        end
        trackedValues(:, k) = current(order);
        trackedConjugateInfo{k} = classifyConjugates( ...
            trackedValues(:, k), options);

        previousVectors = [];
        alignToPrevious = false;
        if isAdjacentTrack && ~isempty(trackedVectorSeries{k - 1})
            previousVectors = trackedVectorSeries{k - 1};
            alignToPrevious = true;
        end
        [trackedVectorSeries{k}, phaseFactors{k}, phaseMethods{k}, ...
            eigenvectorColumnValid(:, k), conjugatePhaseCoordinated(k)] = ...
            prepareEigenvectors(vectorSeries{k}, order, ...
            trackedValues(:, k), previousVectors, alignToPrevious, options);
        eigenvectorRestart(k) = ~alignToPrevious && ...
            ~isempty(trackedVectorSeries{k});
    end

    trackedEigenvalues = packEigenvalues( ...
        num2cell(trackedValues, 1), valueFormat);
    trackedEigenvectors = packEigenvectors( ...
        trackedVectorSeries, vectorFormat);

    trackingInfo = struct();
    trackingInfo.Assignments = assignments;
    trackingInfo.UnconstrainedAssignments = unconstrainedAssignments;
    trackingInfo.RawCostMatrices = rawCostMatrices;
    trackingInfo.CostMatrices = rawCostMatrices;
    trackingInfo.SelectedCosts = selectedCosts;
    trackingInfo.TotalAssignmentCost = totalAssignmentCost;
    trackingInfo.UnconstrainedTotalCost = unconstrainedTotalCost;
    trackingInfo.AssignmentGap = assignmentGap;
    trackingInfo.ValidPoint = validPoint;
    trackingInfo.Reliability = validPoint;
    trackingInfo.RequestedReliability = requestedReliability;
    trackingInfo.IntervalReliability = intervalReliability;
    trackingInfo.FiniteSpectrum = finiteSpectrum;
    trackingInfo.Restart = restart;
    trackingInfo.SegmentStart = segmentStart;
    trackingInfo.Status = status;
    trackingInfo.PairTopologyConsistent = pairTopologyConsistent;
    trackingInfo.PairConstraintApplied = pairConstraintApplied;
    trackingInfo.PairConstraintCostPenalty = pairConstraintCostPenalty;
    trackingInfo.TopologyFallback = topologyFallback;
    trackingInfo.RawConjugateInfo = rawConjugateInfo;
    trackingInfo.ConjugateInfo = trackedConjugateInfo;
    trackingInfo.ConjugateTransitions = conjugateTransitions;
    trackingInfo.PhaseFactors = phaseFactors;
    trackingInfo.PhaseMethods = phaseMethods;
    trackingInfo.EigenvectorColumnValid = eigenvectorColumnValid;
    trackingInfo.EigenvectorRestart = eigenvectorRestart;
    trackingInfo.ConjugatePhaseCoordinated = conjugatePhaseCoordinated;
    trackingInfo.OverlapTieBreakApplied = overlapTieBreakApplied;
    trackingInfo.Options = options;
    trackingInfo.InputFormat = struct( ...
        'Eigenvalues', valueFormat.Kind, ...
        'Eigenvectors', vectorFormat.Kind);

    % Lower-case aliases support MAT datasets and callers that use the
    % repository's lower-case field convention.
    trackingInfo.assignments = assignments;
    trackingInfo.unconstrained_assignments = unconstrainedAssignments;
    trackingInfo.raw_cost_matrices = rawCostMatrices;
    trackingInfo.cost_matrices = rawCostMatrices;
    trackingInfo.selected_costs = selectedCosts;
    trackingInfo.total_assignment_cost = totalAssignmentCost;
    trackingInfo.unconstrained_total_cost = unconstrainedTotalCost;
    trackingInfo.assignment_gap = assignmentGap;
    trackingInfo.assignmentGap = assignmentGap;
    trackingInfo.valid_point = validPoint;
    trackingInfo.reliability = validPoint;
    trackingInfo.interval_reliability = intervalReliability;
    trackingInfo.restarts = restart;
    trackingInfo.segment_start = segmentStart;
    trackingInfo.pair_topology_consistent = pairTopologyConsistent;
    trackingInfo.pair_constraint_applied = pairConstraintApplied;
    trackingInfo.pair_constraint_cost_penalty = pairConstraintCostPenalty;
    trackingInfo.conjugate_info = trackedConjugateInfo;
    trackingInfo.conjugate_transitions = conjugateTransitions;
    trackingInfo.phase_factors = phaseFactors;
    trackingInfo.overlap_tie_break_applied = overlapTieBreakApplied;
end

function options = resolveOptions(supplied)
    options = struct();
    options.Reliability = [];
    options.IntervalReliability = [];
    options.InitialOrder = [];
    options.PreserveConjugatePairs = true;
    options.ConjugateTolerance = 1e-8;
    options.RealTolerance = 1e-10;
    options.PhaseAlignEigenvectors = true;
    options.CoordinateConjugatePhases = true;
    options.ComputeAssignmentGap = true;
    options.RestartOrder = 'canonical';
    options.InvalidCost = 1e12;

    if isempty(supplied)
        return
    end
    if ~isstruct(supplied) || ~isscalar(supplied)
        error('TrackFloquetMultipliers:OptionsType', ...
            'options must be a scalar structure.');
    end

    names = fieldnames(supplied);
    for i = 1:numel(names)
        canonical = canonicalOptionName(names{i});
        if isempty(canonical)
            error('TrackFloquetMultipliers:UnknownOption', ...
                'Unknown tracking option ''%s''.', names{i});
        end
        options.(canonical) = supplied.(names{i});
    end

    logicalNames = {'PreserveConjugatePairs', ...
        'PhaseAlignEigenvectors', 'CoordinateConjugatePhases', ...
        'ComputeAssignmentGap'};
    for i = 1:numel(logicalNames)
        name = logicalNames{i};
        value = options.(name);
        if ~isLogicalScalar(value)
            error('TrackFloquetMultipliers:LogicalOption', ...
                '%s must be a scalar logical value.', name);
        end
        options.(name) = logical(value);
    end

    if ~(isnumeric(options.ConjugateTolerance) && ...
            isscalar(options.ConjugateTolerance) && ...
            isfinite(options.ConjugateTolerance) && ...
            options.ConjugateTolerance > 0)
        error('TrackFloquetMultipliers:ConjugateTolerance', ...
            'ConjugateTolerance must be a positive finite scalar.');
    end
    if ~(isnumeric(options.RealTolerance) && ...
            isscalar(options.RealTolerance) && ...
            isfinite(options.RealTolerance) && options.RealTolerance >= 0)
        error('TrackFloquetMultipliers:RealTolerance', ...
            'RealTolerance must be a nonnegative finite scalar.');
    end
    if ~(isnumeric(options.InvalidCost) && isscalar(options.InvalidCost) && ...
            isfinite(options.InvalidCost) && options.InvalidCost > 2)
        error('TrackFloquetMultipliers:InvalidCost', ...
            'InvalidCost must be a finite scalar greater than 2.');
    end

    if isa(options.RestartOrder, 'string') && isscalar(options.RestartOrder)
        options.RestartOrder = char(options.RestartOrder);
    end
    if ~ischar(options.RestartOrder) || ...
            ~any(strcmpi(options.RestartOrder, {'canonical', 'input'}))
        error('TrackFloquetMultipliers:RestartOrder', ...
            'RestartOrder must be ''canonical'' or ''input''.');
    end
    options.RestartOrder = lower(options.RestartOrder);

    if ~isempty(options.InitialOrder) && ...
            ~(isnumeric(options.InitialOrder) && isvector(options.InitialOrder))
        error('TrackFloquetMultipliers:InitialOrderType', ...
            'InitialOrder must be empty or a numeric permutation vector.');
    end
    if ~isempty(options.Reliability) && ...
            ~(isnumeric(options.Reliability) || islogical(options.Reliability))
        error('TrackFloquetMultipliers:ReliabilityType', ...
            'Reliability must be empty or a logical/numeric vector.');
    end
    if ~isempty(options.IntervalReliability) && ...
            ~(isnumeric(options.IntervalReliability) || ...
              islogical(options.IntervalReliability))
        error('TrackFloquetMultipliers:IntervalReliabilityType', ...
            'IntervalReliability must be empty or a logical/numeric vector.');
    end
end

function canonical = canonicalOptionName(name)
    key = lower(regexprep(name, '[_\-\s]', ''));
    switch key
        case {'reliability', 'pointreliability', 'validpoints', 'valid'}
            canonical = 'Reliability';
        case {'intervalreliability', 'validintervals', 'intervalvalid'}
            canonical = 'IntervalReliability';
        case 'initialorder'
            canonical = 'InitialOrder';
        case {'preserveconjugatepairs', 'preservepairs'}
            canonical = 'PreserveConjugatePairs';
        case {'conjugatetolerance', 'pairingtolerance', 'pairtolerance'}
            canonical = 'ConjugateTolerance';
        case {'realtolerance', 'realmodetolerance'}
            canonical = 'RealTolerance';
        case {'phasealigneigenvectors', 'phasealignvectors', 'phasealign'}
            canonical = 'PhaseAlignEigenvectors';
        case {'coordinateconjugatephases', 'coordinatepairphases'}
            canonical = 'CoordinateConjugatePhases';
        case {'computeassignmentgap', 'assignmentgap'}
            canonical = 'ComputeAssignmentGap';
        case 'restartorder'
            canonical = 'RestartOrder';
        case 'invalidcost'
            canonical = 'InvalidCost';
        otherwise
            canonical = '';
    end
end

function tf = isLogicalScalar(value)
    tf = (islogical(value) && isscalar(value)) || ...
        (isnumeric(value) && isscalar(value) && isfinite(value) && ...
        any(value == [0 1]));
end

function reliability = resolveReliability(value, nPoint)
    if isempty(value)
        reliability = true(1, nPoint);
        return
    end
    if ~isvector(value) || numel(value) ~= nPoint || ...
            any(~isfinite(double(value(:)))) || ...
            any(~ismember(double(value(:)), [0 1]))
        error('TrackFloquetMultipliers:ReliabilitySize', ...
            ['Reliability must contain exactly one logical value per ' ...
             'continuation point.']);
    end
    reliability = logical(value(:).');
end

function reliability = resolveIntervalReliability(value, nPoint)
    intervalCount = max(0, nPoint - 1);
    if isempty(value)
        reliability = true(1, intervalCount);
        return
    end
    if ~isvector(value) || numel(value) ~= intervalCount || ...
            any(~isfinite(double(value(:)))) || ...
            any(~ismember(double(value(:)), [0 1]))
        error('TrackFloquetMultipliers:IntervalReliabilitySize', ...
            ['IntervalReliability must contain exactly one logical value ' ...
             'per adjacent continuation interval.']);
    end
    reliability = logical(value(:).');
end

function [series, format] = unpackEigenvalues(input)
    format = struct('Kind', '', 'CellSize', [], 'ValueSizes', {{}}, ...
        'ModeCount', 0);
    if isnumeric(input)
        if ~ismatrix(input)
            error('TrackFloquetMultipliers:EigenvalueDimension', ...
                'Numeric eigenvalues must be an nMode-by-nPoint matrix.');
        end
        format.Kind = 'numeric';
        format.ModeCount = size(input, 1);
        if size(input, 1) == 0 && size(input, 2) > 0
            error('TrackFloquetMultipliers:EmptySpectrum', ...
                'Every continuation point must contain at least one eigenvalue.');
        end
        if isempty(input)
            series = cell(1, size(input, 2));
            return
        end
        series = cell(1, size(input, 2));
        for k = 1:size(input, 2)
            series{k} = input(:, k);
        end
        return
    end

    if ~iscell(input)
        error('TrackFloquetMultipliers:EigenvalueType', ...
            'eigenvalues must be a numeric matrix or cell array.');
    end
    format.Kind = 'cell';
    format.CellSize = size(input);
    format.ValueSizes = cell(size(input));
    if isempty(input)
        series = cell(1, 0);
        return
    end

    series = input(:).';
    firstCount = [];
    for k = 1:numel(series)
        value = series{k};
        if ~isnumeric(value) || ~isvector(value) || isempty(value)
            error('TrackFloquetMultipliers:EigenvalueCell', ...
                'Cell %d must contain a nonempty numeric eigenvalue vector.', k);
        end
        if isempty(firstCount)
            firstCount = numel(value);
        elseif numel(value) ~= firstCount
            error('TrackFloquetMultipliers:ChangingDimension', ...
                ['The reduced Poincare-map dimension changes at point %d. ' ...
                 'Tracking is undefined across a dimension change.'], k);
        end
        format.ValueSizes{k} = size(value);
        series{k} = value(:);
    end
    format.ModeCount = firstCount;
end

function output = packEigenvalues(series, format)
    switch format.Kind
        case 'numeric'
            if isempty(series)
                output = NaN(format.ModeCount, 0);
            else
                output = [series{:}];
            end
        case 'cell'
            output = cell(format.CellSize);
            flat = output(:);
            for k = 1:numel(series)
                flat{k} = reshape(series{k}, format.ValueSizes{k});
            end
            output = reshape(flat, format.CellSize);
        otherwise
            output = [];
    end
end

function [series, format] = unpackEigenvectors(input, nPoint, nMode)
    format = struct('Kind', 'none', 'CellSize', [], ...
        'StateDimension', 0);
    series = cell(1, nPoint);
    if isempty(input)
        return
    end

    if iscell(input)
        if numel(input) ~= nPoint
            error('TrackFloquetMultipliers:EigenvectorCount', ...
                'There must be one eigenvector matrix per branch point.');
        end
        format.Kind = 'cell';
        format.CellSize = size(input);
        series = input(:).';
    elseif isnumeric(input)
        if ndims(input) > 3
            error('TrackFloquetMultipliers:EigenvectorDimension', ...
                'Numeric eigenvectors must be a matrix or 3-D array.');
        end
        if size(input, 2) ~= nMode
            error('TrackFloquetMultipliers:EigenvectorModeCount', ...
                'Each eigenvector matrix must have nMode columns.');
        end
        if nPoint == 1 && size(input, 3) == 1
            format.Kind = 'numeric2d';
            series{1} = input(:, :, 1);
        elseif size(input, 3) == nPoint
            format.Kind = 'numeric3d';
            for k = 1:nPoint
                series{k} = input(:, :, k);
            end
        else
            error('TrackFloquetMultipliers:EigenvectorCount', ...
                ['The third eigenvector-array dimension must equal the ' ...
                 'number of continuation points.']);
        end
    else
        error('TrackFloquetMultipliers:EigenvectorType', ...
            'eigenvectors must be numeric, a cell array, or empty.');
    end

    stateDimension = [];
    for k = 1:nPoint
        matrix = series{k};
        if isempty(matrix)
            if ~strcmp(format.Kind, 'cell')
                error('TrackFloquetMultipliers:EmptyEigenvectorMatrix', ...
                    'Numeric eigenvector pages may not be empty.');
            end
            continue
        end
        if ~isnumeric(matrix) || ~ismatrix(matrix) || ...
                size(matrix, 2) ~= nMode
            error('TrackFloquetMultipliers:EigenvectorMatrix', ...
                ['Eigenvector cell %d must be a numeric matrix with ' ...
                 'nMode columns.'], k);
        end
        if isempty(stateDimension)
            stateDimension = size(matrix, 1);
        elseif size(matrix, 1) ~= stateDimension
            error('TrackFloquetMultipliers:EigenvectorStateDimension', ...
                'Eigenvector row dimension changes at point %d.', k);
        end
    end
    if isempty(stateDimension)
        stateDimension = 0;
    end
    format.StateDimension = stateDimension;
end

function output = packEigenvectors(series, format)
    switch format.Kind
        case 'none'
            output = [];
        case 'cell'
            output = reshape(series, format.CellSize);
        case 'numeric2d'
            output = series{1};
        case 'numeric3d'
            if isempty(series)
                output = NaN(format.StateDimension, 0, 0);
            else
                output = cat(3, series{:});
            end
        otherwise
            output = [];
    end
end

function order = initialPointOrder(values, pairInfo, valid, options)
    nMode = numel(values);
    if ~isempty(options.InitialOrder)
        order = validatePermutation(options.InitialOrder, nMode, ...
            'InitialOrder');
    elseif ~valid && strcmp(options.RestartOrder, 'canonical')
        order = canonicalSpectrumOrder(values, pairInfo);
    else
        order = (1:nMode).';
    end
end

function order = restartPointOrder(values, pairInfo, options)
    if strcmp(options.RestartOrder, 'canonical')
        order = canonicalSpectrumOrder(values, pairInfo);
    else
        order = (1:numel(values)).';
    end
end

function permutation = validatePermutation(value, count, optionName)
    permutation = value(:);
    if numel(permutation) ~= count || any(~isfinite(permutation)) || ...
            any(permutation ~= fix(permutation)) || ...
            ~isequal(sort(permutation), (1:count).')
        error('TrackFloquetMultipliers:Permutation', ...
            '%s must be a permutation of 1:nMode.', optionName);
    end
end

function info = classifyConjugates(values, options)
    values = values(:);
    nMode = numel(values);
    finite = isfinite(real(values)) & isfinite(imag(values));
    scale = max(1, abs(values));
    realMask = finite & abs(imag(values)) <= ...
        options.RealTolerance .* scale;
    positive = find(finite & ~realMask & imag(values) > 0);
    negative = find(finite & ~realMask & imag(values) < 0);

    positive = sortValueIndices(values, positive);
    negative = sortValueIndices(values, negative);
    pairList = zeros(0, 2);
    absoluteResidual = zeros(0, 1);
    scaledResidual = zeros(0, 1);

    nPositive = numel(positive);
    nNegative = numel(negative);
    if nPositive > 0 && nNegative > 0
        residual = zeros(nPositive, nNegative);
        for i = 1:nPositive
            for j = 1:nNegative
                denominator = max([1, abs(values(positive(i))), ...
                    abs(values(negative(j)))]);
                residual(i, j) = abs(values(positive(i)) - ...
                    conj(values(negative(j)))) / denominator;
            end
        end

        dimension = nPositive + nNegative;
        forbiddenPairCost = max(options.InvalidCost, 2 * (dimension + 1));
        pairingCost = forbiddenPairCost * ones(dimension, dimension);
        normalized = residual ./ options.ConjugateTolerance;
        allowed = normalized <= 1;
        block = pairingCost(1:nPositive, 1:nNegative);
        block(allowed) = normalized(allowed);
        pairingCost(1:nPositive, 1:nNegative) = block;
        for i = 1:nPositive
            pairingCost(i, nNegative + i) = 1;
        end
        for j = 1:nNegative
            pairingCost(nPositive + j, j) = 1;
        end
        pairingCost(nPositive + 1:end, nNegative + 1:end) = 0;

        [pairAssignment, feasible] = hungarianAssignment(pairingCost);
        if ~feasible
            error('TrackFloquetMultipliers:InternalPairingFailure', ...
                'The padded conjugate-pair assignment is infeasible.');
        end
        for i = 1:nPositive
            j = pairAssignment(i);
            if j <= nNegative && residual(i, j) <= ...
                    options.ConjugateTolerance
                pairList(end + 1, :) = [positive(i), negative(j)]; %#ok<AGROW>
                absoluteResidual(end + 1, 1) = abs(values(positive(i)) - ...
                    conj(values(negative(j)))); %#ok<AGROW>
                scaledResidual(end + 1, 1) = residual(i, j); %#ok<AGROW>
            end
        end
    end

    if ~isempty(pairList)
        keys = [real(values(pairList(:, 1))), ...
            abs(imag(values(pairList(:, 1)))), pairList];
        [~, pairOrder] = sortrows(keys, 1:size(keys, 2));
        pairList = pairList(pairOrder, :);
        absoluteResidual = absoluteResidual(pairOrder);
        scaledResidual = scaledResidual(pairOrder);
    end

    paired = pairList(:);
    complexIndices = [positive(:); negative(:)];
    unpaired = setdiff(complexIndices, paired, 'stable');
    realIndices = sortValueIndices(values, find(realMask));
    nonfiniteIndices = find(~finite);
    pairIds = zeros(nMode, 1);
    partner = zeros(nMode, 1);
    orientation = zeros(nMode, 1);
    for p = 1:size(pairList, 1)
        pairIds(pairList(p, :)) = p;
        partner(pairList(p, 1)) = pairList(p, 2);
        partner(pairList(p, 2)) = pairList(p, 1);
        orientation(pairList(p, 1)) = 1;
        orientation(pairList(p, 2)) = -1;
    end

    info = struct();
    info.Pairs = pairList;
    info.PairCount = size(pairList, 1);
    info.PairResidual = absoluteResidual;
    info.ScaledPairResidual = scaledResidual;
    info.RealIndices = realIndices(:);
    info.RealCount = numel(realIndices);
    info.UnpairedComplexIndices = unpaired(:);
    info.NonfiniteIndices = nonfiniteIndices(:);
    info.PairIds = pairIds;
    info.Partner = partner;
    info.Orientation = orientation;
    info.IsComplete = isempty(unpaired) && isempty(nonfiniteIndices);
    info.Signature = [info.RealCount, info.PairCount, numel(unpaired)];
end

function order = canonicalSpectrumOrder(values, info)
    values = values(:);
    order = zeros(numel(values), 1);
    next = 1;
    if ~isempty(info.RealIndices)
        count = numel(info.RealIndices);
        order(next:next + count - 1) = info.RealIndices(:);
        next = next + count;
    end
    for p = 1:info.PairCount
        % Positive-imaginary member first, then its negative partner.
        order(next:next + 1) = info.Pairs(p, :).';
        next = next + 2;
    end
    if ~isempty(info.UnpairedComplexIndices)
        unpaired = sortValueIndices(values, info.UnpairedComplexIndices);
        count = numel(unpaired);
        order(next:next + count - 1) = unpaired(:);
        next = next + count;
    end
    if ~isempty(info.NonfiniteIndices)
        count = numel(info.NonfiniteIndices);
        order(next:next + count - 1) = info.NonfiniteIndices(:);
    end
    if numel(order) ~= numel(values) || ...
            ~isequal(sort(order), (1:numel(values)).')
        error('TrackFloquetMultipliers:InternalCanonicalOrder', ...
            'Internal canonical ordering did not produce a permutation.');
    end
end

function indices = sortValueIndices(values, indices)
    indices = indices(:);
    if isempty(indices)
        return
    end
    keys = [real(values(indices)), imag(values(indices)), ...
        abs(values(indices)), indices];
    [~, order] = sortrows(keys, 1:size(keys, 2));
    indices = indices(order);
end

function [consistent, reason] = conjugateTopologyIsConsistent(previous, current)
    if ~previous.IsComplete || ~current.IsComplete
        consistent = false;
        reason = 'incomplete-conjugate-pairing';
    elseif previous.PairCount ~= current.PairCount
        consistent = false;
        reason = 'pair-count-change';
    elseif previous.RealCount ~= current.RealCount
        consistent = false;
        reason = 'real-mode-count-change';
    else
        consistent = true;
        reason = 'consistent';
    end
end

function [assignment, detail] = solveUnconstrained(cost, currentValues)
    columnOrder = sortValueIndices(currentValues, (1:numel(currentValues)).');
    [localAssignment, feasible] = hungarianAssignment(cost(:, columnOrder));
    assignment = zeros(size(localAssignment));
    if feasible
        assignment = columnOrder(localAssignment);
    end
    detail = emptyAssignmentDetail();
    detail.Feasible = feasible;
    detail.ColumnTieBreakOrder = columnOrder;
end

function [assignment, applied] = RefineRepeatedRealAssignment( ...
        assignment, currentValues, previousVectors, currentVectors, ...
        eigenvalueCost, options)
% Keep the exact eigenvalue cost primary; use vector overlap only inside
% numerically identical real-eigenvalue columns where that cost is tied.
    applied = false;
    if isempty(previousVectors) || isempty(currentVectors) || ...
            size(previousVectors, 2) ~= numel(assignment) || ...
            size(currentVectors, 2) ~= numel(assignment)
        return;
    end
    clusters = RepeatedRealClusters(currentValues, options);
    for clusterIndex = 1:numel(clusters)
        columns = clusters{clusterIndex};
        if numel(columns) < 2
            continue;
        end
        rows = find(ismember(assignment, columns));
        if numel(rows) ~= numel(columns)
            continue;
        end
        previous = previousVectors(:, rows);
        current = currentVectors(:, columns);
        previousNorm = vecnorm(previous, 2, 1);
        currentNorm = vecnorm(current, 2, 1);
        if any(~isfinite(previousNorm)) || any(previousNorm <= 0) || ...
                any(~isfinite(currentNorm)) || any(currentNorm <= 0)
            continue;
        end
        overlap = abs((previous ./ previousNorm)' * ...
            (current ./ currentNorm));
        [localMap, feasible] = hungarianAssignment(max(0, 1 - overlap));
        if ~feasible
            continue;
        end
        candidate = assignment;
        candidate(rows) = columns(localMap);
        oldCost = assignmentCost(eigenvalueCost, assignment);
        newCost = assignmentCost(eigenvalueCost, candidate);
        tolerance = 100 * eps * (1 + abs(oldCost));
        if abs(newCost - oldCost) <= tolerance && ...
                ~isequal(candidate, assignment)
            assignment = candidate;
            applied = true;
        end
    end
end

function clusters = RepeatedRealClusters(values, options)
    clusters = RepeatedValueClusters(values);
    keep = false(1, numel(clusters));
    scale = 1 + max(abs(values));
    for i = 1:numel(clusters)
        keep(i) = all(abs(imag(values(clusters{i}))) <= ...
            options.RealTolerance * scale);
    end
    clusters = clusters(keep);
end

function clusters = RepeatedValueClusters(values)
    values = values(:);
    scale = 1 + max(abs(values));
    exactTolerance = max(100 * eps(scale), realmin);
    remaining = find(isfinite(real(values)) & isfinite(imag(values)));
    clusters = {};
    while ~isempty(remaining)
        anchor = remaining(1);
        memberMask = abs(values(remaining) - values(anchor)) <= ...
            exactTolerance;
        cluster = remaining(memberMask);
        if numel(cluster) > 1
            clusters{end + 1} = cluster(:); %#ok<AGROW>
        end
        remaining(memberMask) = [];
    end
end

function [assignment, detail] = solvePairConstrained(cost, previous, current)
    nMode = size(cost, 1);
    nPair = previous.PairCount;
    assignment = zeros(nMode, 1);
    detail = emptyAssignmentDetail();

    pairCost = zeros(nPair, nPair);
    directCost = zeros(nPair, nPair);
    swappedCost = zeros(nPair, nPair);
    for p = 1:nPair
        previousPair = previous.Pairs(p, :);
        for q = 1:nPair
            currentPair = current.Pairs(q, :);
            directCost(p, q) = cost(previousPair(1), currentPair(1)) + ...
                cost(previousPair(2), currentPair(2));
            swappedCost(p, q) = cost(previousPair(1), currentPair(2)) + ...
                cost(previousPair(2), currentPair(1));
            pairCost(p, q) = min(directCost(p, q), swappedCost(p, q));
        end
    end
    [pairMap, pairFeasible] = hungarianAssignment(pairCost);
    if ~pairFeasible
        return
    end

    orientations = zeros(nPair, 1);
    for p = 1:nPair
        q = pairMap(p);
        previousPair = previous.Pairs(p, :);
        currentPair = current.Pairs(q, :);
        if directCost(p, q) <= swappedCost(p, q)
            assignment(previousPair(1)) = currentPair(1);
            assignment(previousPair(2)) = currentPair(2);
            orientations(p) = 1;
        else
            assignment(previousPair(1)) = currentPair(2);
            assignment(previousPair(2)) = currentPair(1);
            orientations(p) = -1;
        end
    end

    previousReal = previous.RealIndices(:);
    currentReal = current.RealIndices(:);
    realMap = zeros(0, 1);
    realFeasible = true;
    if ~isempty(previousReal)
        realValues = currentReal;
        [localMap, realFeasible] = hungarianAssignment( ...
            cost(previousReal, realValues));
        if realFeasible
            realMap = realValues(localMap);
            assignment(previousReal) = realMap;
        end
    end

    detail.Feasible = pairFeasible && realFeasible && ...
        all(assignment > 0) && numel(unique(assignment)) == nMode;
    detail.PairBlockAssignment = pairMap;
    detail.PairOrientations = orientations;
    detail.PairCostMatrix = pairCost;
    detail.PairDirectCostMatrix = directCost;
    detail.PairSwappedCostMatrix = swappedCost;
    detail.RealAssignment = realMap;
end

function detail = emptyAssignmentDetail()
    detail = struct('Feasible', false, ...
        'ColumnTieBreakOrder', [], ...
        'PairBlockAssignment', [], ...
        'PairOrientations', [], ...
        'PairCostMatrix', [], ...
        'PairDirectCostMatrix', [], ...
        'PairSwappedCostMatrix', [], ...
        'RealAssignment', []);
end

function gap = secondBestAssignmentGap(cost, assignment, bestCost, ...
        previousInfo, currentInfo, currentValues, usePairConstraint)
    nMode = numel(assignment);
    if nMode <= 1
        gap = Inf;
        return
    end
    alternativeCost = Inf;
    for row = 1:nMode
        modified = cost;
        modified(row, assignment(row)) = Inf;
        if usePairConstraint
            [trial, detail] = solvePairConstrained( ...
                modified, previousInfo, currentInfo);
        else
            [trial, detail] = solveUnconstrained( ...
                modified, currentValues);
        end
        if detail.Feasible
            selected = sub2ind(size(cost), (1:nMode).', trial);
            trialCost = sum(cost(selected));
            alternativeCost = min(alternativeCost, trialCost);
        end
    end
    if isfinite(alternativeCost)
        gap = max(0, alternativeCost - bestCost);
    else
        gap = Inf;
    end
end

function total = assignmentCost(cost, assignment)
    rows = (1:numel(assignment)).';
    total = sum(cost(sub2ind(size(cost), rows, assignment)));
end

function [assignment, feasible] = hungarianAssignment(cost)
    [nRow, nColumn] = size(cost);
    if nRow ~= nColumn
        error('TrackFloquetMultipliers:AssignmentDimension', ...
            'The assignment cost matrix must be square.');
    end
    if nRow == 0
        assignment = zeros(0, 1);
        feasible = true;
        return
    end
    if any(cost(isfinite(cost)) < 0)
        error('TrackFloquetMultipliers:NegativeCost', ...
            'Assignment costs must be nonnegative.');
    end
    if any(all(~isfinite(cost), 2)) || any(all(~isfinite(cost), 1))
        assignment = zeros(nRow, 1);
        feasible = false;
        return
    end

    % Shortest augmenting-path form of the Hungarian algorithm.  Inf is a
    % forbidden edge; the finite-feasibility check below catches a returned
    % assignment that could only use such an edge.
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
            j1 = 0;
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
            if ~isfinite(delta) || j1 == 0
                feasible = false;
                assignment = zeros(nRow, 1);
                return
            end
            for j = 1:nColumn + 1
                if used(j)
                    u(p(j) + 1) = u(p(j) + 1) + delta;
                    v(j) = v(j) - delta;
                elseif isfinite(minv(j))
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
    rows = (1:nRow).';
    feasible = all(assignment > 0) && ...
        all(isfinite(cost(sub2ind(size(cost), rows, assignment))));
end

function [matrix, factors, methods, columnValid, pairCoordinated] = ...
        prepareEigenvectors(rawMatrix, order, trackedValues, ...
        previousMatrix, alignToPrevious, options)
    nMode = numel(order);
    factors = [];
    methods = {};
    columnValid = false(nMode, 1);
    pairCoordinated = false;
    if isempty(rawMatrix)
        matrix = [];
        return
    end

    matrix = rawMatrix(:, order);
    if alignToPrevious && ~isempty(previousMatrix)
        matrix = AlignRepeatedSubspaces( ...
            matrix, trackedValues, previousMatrix);
        matrix = CoordinateRepeatedConjugateSubspaces( ...
            matrix, trackedValues, options);
    end
    factors = complex(NaN(nMode, 1), NaN(nMode, 1));
    methods = repmat({'invalid'}, nMode, 1);
    for j = 1:nMode
        columnValid(j) = allFinite(matrix(:, j)) && norm(matrix(:, j)) > 0;
    end
    if ~options.PhaseAlignEigenvectors
        factors(columnValid) = 1;
        methods(columnValid) = repmat({'unchanged'}, nnz(columnValid), 1);
        return
    end

    pairInfo = classifyConjugates(trackedValues, options);
    handled = false(nMode, 1);
    if options.CoordinateConjugatePhases
        for p = 1:pairInfo.PairCount
            positiveIndex = pairInfo.Pairs(p, 1);
            negativeIndex = pairInfo.Pairs(p, 2);
            handled([positiveIndex, negativeIndex]) = true;

            [matrix, factors, methods] = alignOneColumn( ...
                matrix, factors, methods, positiveIndex, previousMatrix, ...
                alignToPrevious, columnValid);

            if columnValid(negativeIndex) && columnValid(positiveIndex)
                target = conj(matrix(:, positiveIndex));
                [factor, ok] = phaseFactorForTarget( ...
                    target, matrix(:, negativeIndex));
                if ok
                    matrix(:, negativeIndex) = ...
                        matrix(:, negativeIndex) * factor;
                    factors(negativeIndex) = factor;
                    methods{negativeIndex} = 'conjugate-coordinate';
                    pairCoordinated = true;
                else
                    [matrix, factors, methods] = alignOneColumn( ...
                        matrix, factors, methods, negativeIndex, ...
                        previousMatrix, alignToPrevious, columnValid);
                end
            else
                [matrix, factors, methods] = alignOneColumn( ...
                    matrix, factors, methods, negativeIndex, ...
                    previousMatrix, alignToPrevious, columnValid);
            end
        end
    end

    for j = 1:nMode
        if ~handled(j)
            [matrix, factors, methods] = alignOneColumn( ...
                matrix, factors, methods, j, previousMatrix, ...
                alignToPrevious, columnValid);
        end
    end
end

function matrix = AlignRepeatedSubspaces( ...
        matrix, values, previousMatrix)
    clusters = RepeatedValueClusters(values);
    for clusterIndex = 1:numel(clusters)
        columns = clusters{clusterIndex};
        current = matrix(:, columns);
        previous = previousMatrix(:, columns);
        if ~allFinite(current) || ~allFinite(previous)
            continue;
        end
        dimension = numel(columns);
        tolerance = 100 * eps * max(1, max(norm(current), norm(previous)));
        if rank(current, tolerance) < dimension || ...
                rank(previous, tolerance) < dimension
            continue;
        end
        [left, ~, right] = svd(current' * previous, 'econ');
        rotation = left * right';
        matrix(:, columns) = current * rotation;
    end
end

function matrix = CoordinateRepeatedConjugateSubspaces( ...
        matrix, values, options)
    pairInfo = classifyConjugates(values, options);
    clusters = RepeatedValueClusters(values);
    scale = 1 + max(abs(values));
    for clusterIndex = 1:numel(clusters)
        positive = clusters{clusterIndex};
        if any(imag(values(positive)) <= ...
                options.RealTolerance * scale)
            continue;
        end
        negative = pairInfo.Partner(positive);
        if any(negative <= 0) || ...
                numel(unique(negative)) ~= numel(positive)
            continue;
        end
        current = matrix(:, negative);
        target = conj(matrix(:, positive));
        if ~allFinite(current) || ~allFinite(target)
            continue;
        end
        dimension = numel(positive);
        tolerance = 100 * eps * max(1, max(norm(current), norm(target)));
        if rank(current, tolerance) < dimension || ...
                rank(target, tolerance) < dimension
            continue;
        end
        [left, ~, right] = svd(current' * target, 'econ');
        matrix(:, negative) = current * (left * right');
    end
end

function [matrix, factors, methods] = alignOneColumn( ...
        matrix, factors, methods, index, previousMatrix, ...
        alignToPrevious, columnValid)
    if ~columnValid(index)
        return
    end

    factor = NaN;
    aligned = false;
    if alignToPrevious && ~isempty(previousMatrix) && ...
            size(previousMatrix, 2) >= index && ...
            allFinite(previousMatrix(:, index)) && ...
            norm(previousMatrix(:, index)) > 0
        [factor, aligned] = phaseFactorForTarget( ...
            previousMatrix(:, index), matrix(:, index));
        if aligned
            methods{index} = 'previous-overlap';
        end
    end
    if ~aligned
        [factor, aligned] = canonicalPhaseFactor(matrix(:, index));
        if aligned
            methods{index} = 'canonical-pivot';
        end
    end
    if aligned
        matrix(:, index) = matrix(:, index) * factor;
        factors(index) = factor;
    end
end

function [factor, ok] = phaseFactorForTarget(target, vector)
    factor = NaN;
    ok = false;
    denominator = norm(target) * norm(vector);
    if ~(isfinite(denominator) && denominator > 0)
        return
    end
    inner = target' * vector;
    if ~allFinite(inner) || abs(inner) <= 100 * eps * denominator
        return
    end
    factor = exp(-1i * angle(inner));
    ok = true;
end

function [factor, ok] = canonicalPhaseFactor(vector)
    factor = NaN;
    ok = false;
    [magnitude, pivot] = max(abs(vector));
    if isempty(pivot) || ~isfinite(magnitude) || magnitude <= 0
        return
    end
    factor = exp(-1i * angle(vector(pivot)));
    ok = true;
end

function tf = allFinite(value)
    tf = isnumeric(value) && all(isfinite(real(value(:)))) && ...
        all(isfinite(imag(value(:))));
end

function info = emptyTrackingInfo(options, nMode)
    info = struct();
    info.Assignments = NaN(nMode, 0);
    info.UnconstrainedAssignments = NaN(nMode, 0);
    info.RawCostMatrices = cell(1, 0);
    info.CostMatrices = cell(1, 0);
    info.SelectedCosts = NaN(nMode, 0);
    info.TotalAssignmentCost = NaN(1, 0);
    info.UnconstrainedTotalCost = NaN(1, 0);
    info.AssignmentGap = NaN(1, 0);
    info.ValidPoint = false(1, 0);
    info.Reliability = false(1, 0);
    info.RequestedReliability = false(1, 0);
    info.IntervalReliability = false(1, 0);
    info.FiniteSpectrum = false(1, 0);
    info.Restart = false(1, 0);
    info.SegmentStart = false(1, 0);
    info.Status = cell(1, 0);
    info.PairTopologyConsistent = false(1, 0);
    info.PairConstraintApplied = false(1, 0);
    info.PairConstraintCostPenalty = NaN(1, 0);
    info.TopologyFallback = false(1, 0);
    info.RawConjugateInfo = cell(1, 0);
    info.ConjugateInfo = cell(1, 0);
    info.ConjugateTransitions = cell(1, 0);
    info.PhaseFactors = cell(1, 0);
    info.PhaseMethods = cell(1, 0);
    info.EigenvectorColumnValid = false(nMode, 0);
    info.EigenvectorRestart = false(1, 0);
    info.ConjugatePhaseCoordinated = false(1, 0);
    info.OverlapTieBreakApplied = false(1, 0);
    info.Options = options;
    info.InputFormat = struct('Eigenvalues', '', 'Eigenvectors', '');
    info.assignments = info.Assignments;
    info.unconstrained_assignments = info.UnconstrainedAssignments;
    info.raw_cost_matrices = info.RawCostMatrices;
    info.cost_matrices = info.CostMatrices;
    info.selected_costs = info.SelectedCosts;
    info.total_assignment_cost = info.TotalAssignmentCost;
    info.unconstrained_total_cost = info.UnconstrainedTotalCost;
    info.assignment_gap = info.AssignmentGap;
    info.assignmentGap = info.AssignmentGap;
    info.valid_point = info.ValidPoint;
    info.reliability = info.Reliability;
    info.interval_reliability = info.IntervalReliability;
    info.restarts = info.Restart;
    info.segment_start = info.SegmentStart;
    info.pair_topology_consistent = info.PairTopologyConsistent;
    info.pair_constraint_applied = info.PairConstraintApplied;
    info.pair_constraint_cost_penalty = info.PairConstraintCostPenalty;
    info.conjugate_info = info.ConjugateInfo;
    info.conjugate_transitions = info.ConjugateTransitions;
    info.phase_factors = info.PhaseFactors;
    info.overlap_tie_break_applied = info.OverlapTieBreakApplied;
end
