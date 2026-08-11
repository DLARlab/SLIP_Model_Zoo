function [Candidates, Report] = detectBifurcations(Data, ContinuationCoordinate, Options)
%DETECTBIFURCATION Detect persistent crossings of tracked Floquet multipliers.
%
%   [CANDIDATES, REPORT] = DETECTBIFURCATION(DATA, S, OPTIONS) detects
%   signed/bracketed crossings of +1, -1, and the unit circle. DATA may be
%   the output of TrackMultipliers, a multiplier matrix/cell array, or a
%   struct array of Floquet results. S is the continuation coordinate. Raw
%   spectra are globally matched before detection; event-time variables and
%   continuation-Jacobian eigenvalues are not inputs to this routine.
%
%   A crossing is accepted only when its signed side persists at neighboring
%   continuation points. Thus proximity (for example abs(lambda-1)<tol) is
%   never the sole bifurcation criterion. Complex crossings additionally
%   require a persistent conjugate companion and only the upper-half-plane
%   member is reported.
%
%   Important OPTIONS fields are:
%       PersistencePoints             neighboring points per side (>= 1)
%       CrossingTolerance             zero/sign tolerance
%       MinimumSignedExcursion         required outer-neighbor excursion
%       ImaginaryTolerance             real/complex classification tolerance
%       ConjugateTolerance             conjugate-pair relative tolerance
%       Reliability                    one logical per continuation point
%       IntervalReliability            one logical per adjacent interval
%       EventTopologyConsistent        point- or interval-logical vector
%       BranchStates                   reduced section states, nState-by-nPoint
%       BranchTangents                 optional precomputed reduced tangents
%       ReducedStateIndices            select reduced rows from the above
%       RejectTrivialBranchTangent     default true
%       RejectAmbiguousBranchTangent   default true
%       RequireBranchTangentForPlusOne default false
%       ParameterValues                parameter vector(s), nParam-by-nPoint
%       Eigenvectors                   vectors for raw multiplier input
%       TrackOptions                   options passed to TrackMultipliers
%
%   For a +1 crossing, the phase-aligned critical eigenvector is compared
%   with the supplied (or differenced) reduced branch tangent. Collinear
%   directions are labelled as the trivial branch-tangent mode and rejected
%   by default; a linearly independent direction is reported as an
%   additional null direction only for a simple tracked +1 mode.  When the
%   near-+1 cluster is repeated, individual eigensolver columns are basis
%   dependent: the bracket remains a screening candidate, but its direction
%   is marked unresolved until an invariant-subspace refinement resolves a
%   physical branch-switch direction. Ambiguous and rejected brackets remain
%   in REPORT.Rejected with an explicit reason and diagnostics.

    if nargin < 2
        ContinuationCoordinate = [];
    end
    if nargin < 3
        Options = struct();
    end
    if isstruct(ContinuationCoordinate) && nargin < 3
        Options = ContinuationCoordinate;
        ContinuationCoordinate = [];
    end

    opts = defaultOptions();
    opts = mergeOptions(opts, Options);
    validateOptions(opts);

    embeddedCoordinate = extractEmbeddedCoordinate(Data);
    if isTracked(Data)
        tracks = canonicalTracks(Data);
        nPoint = size(tracks.Multipliers, 2);
        [pointReliability, intervalReliability] = ...
            resolveReliabilityMasks(tracks.PointReliability, ...
                trackedIntervalReliability(tracks, nPoint), opts, ...
                nPoint, false);
    else
        nPoint = inputPointCount(Data);
        [trackingPointReliability, intervalReliability] = ...
            resolveReliabilityMasks( ...
                extractEmbeddedPointReliability(Data, nPoint), ...
                true(1, max(0, nPoint - 1)), opts, nPoint, true);
        vectors = opts.Eigenvectors;
        if isempty(vectors)
            vectors = extractEmbeddedVectors(Data);
        end
        trackOptions = opts.TrackOptions;
        % These are the final masks after combining embedded validity,
        % detector masks, event topology, and nested TrackOptions masks.
        % Force them into the tracker so nested options cannot bridge a gap.
        trackOptions = setFieldCaseInsensitive(trackOptions, ...
            'Reliability', trackingPointReliability);
        trackOptions = setFieldCaseInsensitive(trackOptions, ...
            'IntervalReliability', intervalReliability);
        tracks = floquet.internal.tracking.trackMultipliers( ...
            Data, vectors, trackOptions);
        pointReliability = validateLogicalVector( ...
            tracks.PointReliability, nPoint, ...
            'DetectBifurcation:TrackReliability', ...
            'Tracked PointReliability') & trackingPointReliability;
    end

    lambda = tracks.Multipliers;
    [nMode, trackedPointCount] = size(lambda);
    if trackedPointCount ~= nPoint
        error('DetectBifurcation:PointCount', ...
            'Multiplier tracking changed the number of continuation points.');
    end
    if isempty(ContinuationCoordinate)
        ContinuationCoordinate = embeddedCoordinate;
    end
    if isempty(ContinuationCoordinate)
        ContinuationCoordinate = 1:nPoint;
    end
    coordinate = ContinuationCoordinate(:).';
    if numel(coordinate) ~= nPoint || ~isreal(coordinate) || ...
            any(~isfinite(coordinate))
        error('DetectBifurcation:Coordinate', ...
            ['ContinuationCoordinate must be a finite real vector with one ' ...
             'entry per Floquet spectrum.']);
    end

    [parameterValues, parameterError] = orientParameters( ...
        opts.ParameterValues, nPoint);
    if ~isempty(parameterError)
        error('DetectBifurcation:ParameterValues', '%s', parameterError);
    end

    eigenDimension = firstEigenvectorDimension(tracks.Eigenvectors);
    [branchTangents, tangentSource] = resolveBranchTangents( ...
        opts, coordinate, nPoint, eigenDimension);
    if isempty(eigenDimension) && ~isempty(branchTangents)
        eigenDimension = size(branchTangents, 1);
    end
    stateScales = resolveStateScales( ...
        opts.StateScale, nPoint, eigenDimension);

    Candidates = repmat(emptyCandidate(), 1, 0);
    rejected = repmat(emptyRejection(), 1, 0);
    rawBracketCount = 0;

    if nPoint < 2 || nMode == 0
        Report = makeReport(tracks, opts, coordinate, Candidates, rejected, ...
            rawBracketCount, pointReliability, intervalReliability, ...
            tangentSource);
        return
    end

    for track = 1:nMode
        trackValues = lambda(track, :);

        % Real +1 and -1 crossings.
        for target = [1, -1]
            if target == 1
                type = '+1';
                bifurcationType = 'plus-one';
            else
                type = '-1';
                bifurcationType = 'period-doubling';
            end
            signedValues = real(trackValues) - target;
            for k = 1:nPoint - 1
                scale = 1 + max(abs(trackValues(k:k + 1)));
                tolerance = opts.CrossingTolerance * scale;
                [bracketed, fraction] = scalarBracket( ...
                    signedValues(k), signedValues(k + 1), tolerance);
                if ~bracketed
                    continue
                end
                rawBracketCount = rawBracketCount + 1;

                [persisted, persistence] = persistenceCheck( ...
                    signedValues, trackValues, k, opts);
                if ~persisted
                    rejected(end + 1) = rejection(type, track, k, ...
                        persistence.Reason, persistence); %#ok<AGROW>
                    continue
                end
                window = persistence.Window;
                if ~isRealWindow(trackValues(window), opts)
                    rejected(end + 1) = rejection(type, track, k, ...
                        'track-is-not-real-through-persistence-window', ...
                        struct('Window', window)); %#ok<AGROW>
                    continue
                end
                [reliable, reliabilityDetails] = reliabilityCheck( ...
                    window, pointReliability, intervalReliability);
                if ~reliable
                    rejected(end + 1) = rejection(type, track, k, ...
                        'validation-or-event-topology-failed', ...
                        reliabilityDetails); %#ok<AGROW>
                    continue
                end

                vector = interpolateEigenvector( ...
                    tracks.Eigenvectors, track, k, fraction);
                multiplier = (1 - fraction) * trackValues(k) + ...
                    fraction * trackValues(k + 1);
                candidate = buildCandidate(type, bifurcationType, target, ...
                    track, k, fraction, multiplier, vector, coordinate, ...
                    parameterValues, tracks, persistence, opts);

                if target == 1
                    tangent = interpolateTangent( ...
                        branchTangents, k, fraction);
                    metricScale = interpolateStateScale( ...
                        stateScales, k, fraction);
                    [classification, nullMetrics] = classifyNullDirection( ...
                        vector, tangent, metricScale, opts);
                    candidate.NullDirectionClassification = classification;
                    candidate.IsAdditionalNullDirection = ...
                        nullMetrics.IsAdditional;
                    candidate.IsTrivialBranchTangent = nullMetrics.IsTrivial;
                    candidate.BranchTangentOverlap = nullMetrics.Overlap;
                    candidate.AdditionalNullMetric = nullMetrics.Residual;
                    candidate.NullDirectionRank = nullMetrics.Rank;
                    candidate.BranchTangent = tangent;
                    candidate.NullDirectionScale = metricScale;
                    candidate.NullMultiplicity = estimatedNullMultiplicity( ...
                        lambda, k, fraction, opts.NullClusterRadius);
                    candidate.CriticalClusterCount = ...
                        candidate.NullMultiplicity;
                    if candidate.NullMultiplicity > 1
                        % Individual vectors in a repeated eigenspace can
                        % rotate under arbitrarily small perturbations. Keep
                        % the crossing as a screening result, but do not turn
                        % this basis-dependent column into a physical branch
                        % direction.
                        candidate.BasisDependentTrackDiagnostics = ...
                            nullMetrics;
                        candidate.NullDirectionClassification = ...
                            'unresolved-repeated-plus-one-cluster';
                        candidate.IsAdditionalNullDirection = NaN;
                        candidate.IsTrivialBranchTangent = NaN;
                        candidate.BranchTangentOverlap = NaN;
                        candidate.AdditionalNullMetric = NaN;
                        candidate.NullDirectionRank = NaN;
                        candidate.RepeatedNullCluster = true;
                        candidate.BasisInvariantDirectionResolved = false;
                        candidate.RequiresInvariantSubspaceRefinement = true;
                        candidate.BranchSwitchReadiness = ...
                            'requires-invariant-subspace-refinement';
                        candidate.Confidence.TangentSeparation = NaN;
                    else
                        candidate.RepeatedNullCluster = false;
                        candidate.BasisInvariantDirectionResolved = true;
                        candidate.RequiresInvariantSubspaceRefinement = false;
                        candidate.Confidence.TangentSeparation = ...
                            nullMetrics.Confidence;
                    end
                    candidate = refreshConfidence(candidate);

                    rejectReason = plusOneRejectionReason( ...
                        classification, opts);
                    if ~isempty(rejectReason)
                        details = nullMetrics;
                        details.Candidate = candidate;
                        rejected(end + 1) = rejection(type, track, k, ...
                            rejectReason, details); %#ok<AGROW>
                        continue
                    end
                end

                [Candidates, rejected] = appendUniqueCandidate( ...
                    Candidates, candidate, rejected, opts);
            end
        end

        % Complex unit-circle crossings. A signed radius bracket is used;
        % closeness to the circle only determines numerical tolerances.
        radiusSigned = abs(trackValues) - 1;
        for k = 1:nPoint - 1
            scale = 1 + max(abs(trackValues(k:k + 1)));
            tolerance = opts.CrossingTolerance * scale;
            [bracketed, fraction] = scalarBracket( ...
                radiusSigned(k), radiusSigned(k + 1), tolerance);
            if ~bracketed
                continue
            end
            criticalMultiplier = interpolateUnitMultiplier( ...
                trackValues(k), trackValues(k + 1), fraction);

            % The lower-half-plane member is the conjugate duplicate.
            if imag(criticalMultiplier) < -opts.ImaginaryTolerance * scale
                continue
            end
            rawBracketCount = rawBracketCount + 1;
            if abs(imag(criticalMultiplier)) <= ...
                    opts.ImaginaryTolerance * scale
                rejected(end + 1) = rejection('complex-unit-circle', ...
                    track, k, 'crossing-is-real-at-the-unit-circle', ...
                    struct('Multiplier', criticalMultiplier)); %#ok<AGROW>
                continue
            end

            [persisted, persistence] = persistenceCheck( ...
                radiusSigned, trackValues, k, opts);
            if ~persisted
                rejected(end + 1) = rejection('complex-unit-circle', ...
                    track, k, persistence.Reason, persistence); %#ok<AGROW>
                continue
            end
            window = persistence.Window;
            if ~isComplexWindow(trackValues(window), opts)
                rejected(end + 1) = rejection('complex-unit-circle', ...
                    track, k, 'complex-track-collapses-to-real-axis', ...
                    struct('Window', window)); %#ok<AGROW>
                continue
            end
            [companion, conjugacyError] = findConjugateCompanion( ...
                lambda, track, window, opts.ConjugateTolerance);
            if isempty(companion)
                rejected(end + 1) = rejection('complex-unit-circle', ...
                    track, k, 'no-persistent-conjugate-companion', ...
                    struct('Window', window, ...
                           'BestRelativeConjugacyError', conjugacyError)); %#ok<AGROW>
                continue
            end
            [reliable, reliabilityDetails] = reliabilityCheck( ...
                window, pointReliability, intervalReliability);
            if ~reliable
                rejected(end + 1) = rejection('complex-unit-circle', ...
                    track, k, 'validation-or-event-topology-failed', ...
                    reliabilityDetails); %#ok<AGROW>
                continue
            end

            vector = interpolateEigenvector( ...
                tracks.Eigenvectors, track, k, fraction);
            candidate = buildCandidate('complex-unit-circle', ...
                'Neimark-Sacker', NaN, track, k, fraction, ...
                criticalMultiplier, vector, coordinate, parameterValues, ...
                tracks, persistence, opts);
            candidate.ConjugateTrackIndex = companion;
            candidate.MultiplierPair = [criticalMultiplier; ...
                conj(criticalMultiplier)];
            candidate.ConjugacyError = conjugacyError;
            candidate.Confidence.Conjugacy = max(0, ...
                1 - conjugacyError / opts.ConjugateTolerance);
            candidate = refreshConfidence(candidate);
            [Candidates, rejected] = appendUniqueCandidate( ...
                Candidates, candidate, rejected, opts);
        end
    end

    Report = makeReport(tracks, opts, coordinate, Candidates, rejected, ...
        rawBracketCount, pointReliability, intervalReliability, tangentSource);
end

function opts = defaultOptions()
    opts = struct();
    opts.PersistencePoints = 1;
    opts.CrossingTolerance = 1e-8;
    opts.MinimumSignedExcursion = 1e-6;
    opts.ImaginaryTolerance = 1e-7;
    opts.ConjugateTolerance = 1e-4;
    opts.CandidateMergeTolerance = 1e-8;
    opts.ConfidenceCostScale = 0.25;
    opts.Reliability = [];
    opts.IntervalReliability = [];
    opts.EventTopologyConsistent = [];
    opts.BranchStates = [];
    opts.BranchTangents = [];
    opts.StateScale = [];
    opts.ReducedStateIndices = [];
    opts.TrivialTangentAngleDegrees = 10;
    opts.AdditionalTangentAngleDegrees = 25;
    opts.RejectTrivialBranchTangent = true;
    opts.RejectAmbiguousBranchTangent = true;
    opts.RequireBranchTangentForPlusOne = false;
    opts.NullClusterRadius = 5e-2;
    opts.NullRankTolerance = 1e-6;
    opts.ParameterValues = [];
    opts.Eigenvectors = [];
    opts.TrackOptions = struct();
end

function opts = mergeOptions(opts, supplied)
    if isempty(supplied)
        return
    end
    if ~isstruct(supplied) || numel(supplied) ~= 1
        error('DetectBifurcation:OptionsType', ...
            'Options must be a scalar struct.');
    end
    names = fieldnames(supplied);
    defaults = fieldnames(opts);
    for i = 1:numel(names)
        hit = find(strcmpi(names{i}, defaults), 1);
        if isempty(hit)
            error('DetectBifurcation:UnknownOption', ...
                'Unknown option "%s".', names{i});
        end
        opts.(defaults{hit}) = supplied.(names{i});
    end
end

function validateOptions(opts)
    if ~isscalar(opts.PersistencePoints) || ...
            opts.PersistencePoints < 1 || ...
            opts.PersistencePoints ~= floor(opts.PersistencePoints)
        error('DetectBifurcation:PersistencePoints', ...
            'PersistencePoints must be an integer greater than or equal to 1.');
    end
    positive = {'CrossingTolerance', 'MinimumSignedExcursion', ...
        'ImaginaryTolerance', 'ConjugateTolerance', ...
        'CandidateMergeTolerance', 'ConfidenceCostScale', ...
        'NullClusterRadius', 'NullRankTolerance'};
    for i = 1:numel(positive)
        value = opts.(positive{i});
        if ~isscalar(value) || ~isfinite(value) || value <= 0
            error('DetectBifurcation:PositiveOption', ...
                '%s must be a positive finite scalar.', positive{i});
        end
    end
    angles = [opts.TrivialTangentAngleDegrees, ...
        opts.AdditionalTangentAngleDegrees];
    if any(~isfinite(angles)) || angles(1) < 0 || ...
            angles(2) <= angles(1) || angles(2) >= 90
        error('DetectBifurcation:TangentAngles', ...
            ['Tangent angles must satisfy 0 <= trivial < additional < 90 ' ...
             'degrees.']);
    end
    logicalNames = {'RejectTrivialBranchTangent', ...
        'RejectAmbiguousBranchTangent', ...
        'RequireBranchTangentForPlusOne'};
    for i = 1:numel(logicalNames)
        value = opts.(logicalNames{i});
        if ~(isscalar(value) && (islogical(value) || ...
                (isnumeric(value) && isreal(value) && isfinite(value) && ...
                 any(value == [0 1]))))
            error('DetectBifurcation:LogicalOption', ...
                '%s must be a scalar logical value.', logicalNames{i});
        end
    end
    if ~isstruct(opts.TrackOptions) || ~isscalar(opts.TrackOptions)
        error('DetectBifurcation:TrackOptions', ...
            'TrackOptions must be a scalar struct.');
    end
end

function tf = isTracked(data)
    tf = isstruct(data) && isscalar(data) && ...
        logical(firstField(data, {'IsTracked'}, false)) && ...
        ~isempty(firstField(data, {'Multipliers', 'multipliers'}, []));
end

function tracks = canonicalTracks(data)
    tracks = data;
    tracks.Multipliers = firstField(data, ...
        {'Multipliers', 'multipliers'});
    tracks.Eigenvectors = firstField(data, ...
        {'Eigenvectors', 'eigenvectors'}, ...
        cell(1, size(tracks.Multipliers, 2)));
    if isempty(tracks.Eigenvectors)
        tracks.Eigenvectors = cell(1, size(tracks.Multipliers, 2));
    end
    tracks.PointReliability = firstField(data, ...
        {'PointReliability'}, true(1, size(tracks.Multipliers, 2)));
    tracks.Diagnostics = firstField(data, {'Diagnostics'}, struct());
end

function coordinate = extractEmbeddedCoordinate(data)
    coordinate = [];
    if ~isstruct(data)
        return
    end
    if isscalar(data)
        coordinate = firstField(data, {'ContinuationCoordinate', ...
            'continuationCoordinate', 'Coordinate', 'coordinate', ...
            'Arclength', 'arclength'}, []);
    else
        names = {'ContinuationCoordinate', 'continuationCoordinate', ...
            'Coordinate', 'coordinate', 'Arclength', 'arclength'};
        for j = 1:numel(names)
            if all(isfield(data, names{j}))
                values = [data.(names{j})];
                if numel(values) == numel(data)
                    coordinate = values;
                    return
                end
            end
        end
    end
end

function vectors = extractEmbeddedVectors(data)
    vectors = [];
    if ~isstruct(data)
        return
    end
    if isscalar(data)
        vectors = firstField(data, {'Eigenvectors', 'eigenvectors', ...
            'FloquetEigenvectors', 'floquetEigenvectors'}, []);
    else
        vectors = cell(1, numel(data));
        present = false;
        for k = 1:numel(data)
            vectors{k} = firstField(data(k), ...
                {'Eigenvectors', 'eigenvectors', 'FloquetEigenvectors', ...
                 'floquetEigenvectors'}, []);
            present = present || ~isempty(vectors{k});
        end
        if ~present
            vectors = [];
        end
    end
end

function [pointReliability, intervalReliability] = ...
        resolveReliabilityMasks(basePoint, baseInterval, opts, nPoint, ...
        includeTrackOptions)
    pointReliability = validateLogicalVector(basePoint, nPoint, ...
        'DetectBifurcation:TrackReliability', ...
        'Embedded or tracked PointReliability');
    intervalReliability = validateLogicalVector(baseInterval, ...
        max(0, nPoint - 1), ...
        'DetectBifurcation:TrackIntervalReliability', ...
        'Embedded tracked IntervalReliability');

    if includeTrackOptions
        nestedPoint = getFieldCaseInsensitive( ...
            opts.TrackOptions, 'Reliability', []);
        if ~isempty(nestedPoint)
            pointReliability = pointReliability & validateLogicalVector( ...
                nestedPoint, nPoint, ...
                'DetectBifurcation:TrackReliability', ...
                'TrackOptions.Reliability');
        end
        nestedInterval = getFieldCaseInsensitive( ...
            opts.TrackOptions, 'IntervalReliability', []);
        if ~isempty(nestedInterval)
            intervalReliability = intervalReliability & ...
                validateLogicalVector(nestedInterval, ...
                    max(0, nPoint - 1), ...
                    'DetectBifurcation:TrackIntervalReliability', ...
                    'TrackOptions.IntervalReliability');
        end
    end

    if ~isempty(opts.Reliability)
        pointReliability = pointReliability & validateLogicalVector( ...
            opts.Reliability, nPoint, ...
            'DetectBifurcation:Reliability', 'Reliability');
    end
    if ~isempty(opts.IntervalReliability)
        intervalReliability = intervalReliability & ...
            validateLogicalVector(opts.IntervalReliability, ...
                max(0, nPoint - 1), ...
                'DetectBifurcation:IntervalReliability', ...
                'IntervalReliability');
    end

    topology = opts.EventTopologyConsistent;
    if ~isempty(topology)
        if numel(topology) == nPoint
            pointReliability = pointReliability & validateLogicalVector( ...
                topology, nPoint, ...
                'DetectBifurcation:EventTopologyConsistent', ...
                'EventTopologyConsistent');
        elseif numel(topology) == max(0, nPoint - 1)
            intervalReliability = intervalReliability & ...
                validateLogicalVector(topology, max(0, nPoint - 1), ...
                    'DetectBifurcation:EventTopologyConsistent', ...
                    'EventTopologyConsistent');
        else
            error('DetectBifurcation:EventTopologyConsistent', ...
                ['EventTopologyConsistent must have exactly nPoint or ' ...
                 'nPoint-1 entries.']);
        end
    end
end

function reliability = trackedIntervalReliability(tracks, nPoint)
    reliability = true(1, max(0, nPoint - 1));
    if isstruct(tracks.Diagnostics) && isscalar(tracks.Diagnostics)
        supplied = getFieldCaseInsensitive( ...
            tracks.Diagnostics, 'IntervalReliability', []);
        if ~isempty(supplied)
            reliability = supplied;
        end
    end
end

function count = inputPointCount(data)
    if isnumeric(data)
        if isempty(data)
            count = 0;
        elseif isvector(data)
            count = 1;
        else
            count = size(data, 2);
        end
    elseif iscell(data)
        count = numel(data);
    elseif isstruct(data) && numel(data) > 1
        count = numel(data);
    elseif isstruct(data) && isscalar(data)
        values = firstField(data, {'Multipliers', 'multipliers', ...
            'FloquetMultipliers', 'floquetMultipliers'});
        if iscell(values)
            count = numel(values);
        elseif isnumeric(values) && isempty(values)
            count = 0;
        elseif isnumeric(values) && isvector(values)
            count = 1;
        elseif isnumeric(values)
            count = size(values, 2);
        else
            error('DetectBifurcation:InputMultipliers', ...
                'The multiplier field must be numeric or a cell array.');
        end
    else
        error('DetectBifurcation:InputType', ...
            'Data must contain numeric, cell, or structured spectra.');
    end
end

function reliability = extractEmbeddedPointReliability(data, nPoint)
    reliability = true(1, nPoint);
    if ~isstruct(data)
        return
    end
    if isscalar(data)
        supplied = firstField(data, {'PointReliability', 'Reliability', ...
            'reliability'}, []);
        if ~isempty(supplied)
            reliability = supplied;
        end
        return
    end
    for k = 1:nPoint
        reliability(k) = validateLogicalVector(firstField(data(k), ...
            {'Reliable', 'reliable', 'Valid', 'valid'}, true), 1, ...
            'DetectBifurcation:TrackReliability', ...
            sprintf('Embedded reliability at point %d', k));
    end
end

function values = validateLogicalVector(values, count, identifier, label)
    validShape = (count == 0 && isempty(values)) || ...
        (count > 0 && isvector(values) && numel(values) == count);
    if ~(validShape && (islogical(values) || isnumeric(values)) && ...
            isreal(values) && all(isfinite(double(values(:)))) && ...
            all(ismember(double(values(:)), [0 1])))
        error(identifier, ...
            '%s must contain exactly %d finite logical (0/1) values.', ...
            label, count);
    end
    values = logical(values(:).');
end

function value = getFieldCaseInsensitive(source, name, fallback)
    fields = fieldnames(source);
    match = find(strcmpi(name, fields), 1);
    if isempty(match)
        value = fallback;
    else
        value = source.(fields{match});
    end
end

function source = setFieldCaseInsensitive(source, name, value)
    fields = fieldnames(source);
    matches = fields(strcmpi(name, fields));
    if ~isempty(matches)
        source = rmfield(source, matches);
    end
    source.(name) = value;
end

function [parameters, message] = orientParameters(parameters, nPoint)
    message = '';
    if isempty(parameters)
        return
    end
    if isvector(parameters) && numel(parameters) == nPoint
        parameters = parameters(:).';
    elseif size(parameters, 2) == nPoint
        % Already nParameter-by-nPoint.
    elseif size(parameters, 1) == nPoint
        parameters = parameters.';
    else
        message = ['ParameterValues must have one column (or row) per ' ...
                   'continuation point.'];
    end
end

function dimension = firstEigenvectorDimension(vectors)
    dimension = [];
    for k = 1:numel(vectors)
        if ~isempty(vectors{k})
            dimension = size(vectors{k}, 1);
            return
        end
    end
end

function [tangents, source] = resolveBranchTangents( ...
        opts, coordinate, nPoint, eigenDimension)
    tangents = [];
    source = 'not supplied';
    if ~isempty(opts.BranchTangents)
        tangents = orientStateSeries(opts.BranchTangents, nPoint, ...
            opts.ReducedStateIndices, eigenDimension, 'BranchTangents');
        source = 'supplied reduced BranchTangents';
    elseif ~isempty(opts.BranchStates)
        states = orientStateSeries(opts.BranchStates, nPoint, ...
            opts.ReducedStateIndices, eigenDimension, 'BranchStates');
        tangents = finiteDifferenceTangents(states, coordinate);
        source = 'finite difference of reduced BranchStates';
    end
    if ~isempty(tangents)
        magnitudes = sqrt(sum(abs(tangents) .^ 2, 1));
        valid = isfinite(magnitudes) & magnitudes > 0;
        if any(valid)
            tangents(:, valid) = tangents(:, valid) ./ magnitudes(valid);
        end
        tangents(:, ~valid) = NaN;
    end
end

function scales = resolveStateScales(value, nPoint, dimension)
    if isempty(dimension)
        scales = [];
        return
    end
    if isempty(value)
        scales = ones(dimension, nPoint);
        return
    end
    if ~isnumeric(value) || ~isreal(value)
        error('DetectBifurcation:StateScale', ...
            'StateScale must be a positive finite numeric vector or matrix.');
    end
    if isvector(value)
        value = value(:);
        if numel(value) ~= dimension
            error('DetectBifurcation:StateScale', ...
                'StateScale vector dimension does not match the Floquet state.');
        end
        scales = repmat(value, 1, nPoint);
    elseif isequal(size(value), [dimension nPoint])
        scales = value;
    elseif isequal(size(value), [nPoint dimension])
        scales = value.';
    else
        error('DetectBifurcation:StateScale', ...
            'StateScale must be nState-by-nPoint or one nState vector.');
    end
    if any(~isfinite(scales), 'all') || any(scales <= 0, 'all')
        error('DetectBifurcation:StateScale', ...
            'StateScale entries must be positive and finite.');
    end
end

function values = orientStateSeries(values, nPoint, indices, ...
        eigenDimension, label)
    if ~isnumeric(values) || ~ismatrix(values)
        error('DetectBifurcation:StateSeries', ...
            '%s must be a numeric matrix.', label);
    end
    if size(values, 2) == nPoint
        % Preferred orientation.
    elseif size(values, 1) == nPoint
        values = values.';
    else
        error('DetectBifurcation:StateSeriesSize', ...
            '%s must have one column or row per branch point.', label);
    end
    if ~isempty(indices)
        indices = indices(:);
        if any(indices < 1) || any(indices > size(values, 1)) || ...
                any(indices ~= floor(indices))
            error('DetectBifurcation:ReducedStateIndices', ...
                'ReducedStateIndices are outside the supplied state series.');
        end
        values = values(indices, :);
    end
    if ~isempty(eigenDimension) && size(values, 1) ~= eigenDimension
        error('DetectBifurcation:TangentDimension', ...
            ['%s has %d reduced coordinates but the Floquet eigenvectors ' ...
             'have %d. Supply ReducedStateIndices for the same chart.'], ...
            label, size(values, 1), eigenDimension);
    end
end

function tangents = finiteDifferenceTangents(states, coordinate)
    [dimension, nPoint] = size(states);
    tangents = NaN(dimension, nPoint);
    if nPoint == 1
        return
    end
    for k = 1:nPoint
        left = max(1, k - 1);
        right = min(nPoint, k + 1);
        denominator = coordinate(right) - coordinate(left);
        if right == left
            continue
        end
        if abs(denominator) <= eps(max(1, abs(coordinate(k))))
            tangents(:, k) = (states(:, right) - states(:, left)) / ...
                (right - left);
        else
            tangents(:, k) = (states(:, right) - states(:, left)) / denominator;
        end
    end
end

function [tf, fraction] = scalarBracket(left, right, tolerance)
    leftSign = tolerantSign(left, tolerance);
    rightSign = tolerantSign(right, tolerance);
    enoughChange = isfinite(left) && isfinite(right) && ...
        abs(right - left) > tolerance;
    tf = enoughChange && ((leftSign * rightSign < 0) || ...
        (xor(leftSign == 0, rightSign == 0)));
    if ~tf
        fraction = NaN;
    elseif leftSign == 0
        fraction = 0;
    elseif rightSign == 0
        fraction = 1;
    else
        fraction = min(1, max(0, -left / (right - left)));
    end
end

function signValue = tolerantSign(value, tolerance)
    if ~isfinite(value) || abs(value) <= tolerance
        signValue = 0;
    else
        signValue = sign(value);
    end
end

function [tf, details] = persistenceCheck( ...
        signedValues, multipliers, interval, opts)
    nPoint = numel(signedValues);
    width = opts.PersistencePoints;
    details = struct();
    details.Reason = '';
    if interval - width < 1 || interval + 1 + width > nPoint
        tf = false;
        details.Reason = 'insufficient-neighboring-points-for-persistence';
        details.Window = max(1, interval - width): ...
            min(nPoint, interval + 1 + width);
        return
    end
    leftIndices = interval - width:interval;
    rightIndices = interval + 1:interval + 1 + width;
    window = leftIndices(1):rightIndices(end);
    scale = 1 + max(abs(multipliers(window)));
    tolerance = opts.CrossingTolerance * scale;
    minimumExcursion = opts.MinimumSignedExcursion * scale;
    leftSigns = arrayfun(@(x) tolerantSign(x, tolerance), ...
        signedValues(leftIndices));
    rightSigns = arrayfun(@(x) tolerantSign(x, tolerance), ...
        signedValues(rightIndices));
    leftNonzero = leftSigns(leftSigns ~= 0);
    rightNonzero = rightSigns(rightSigns ~= 0);

    details.Window = window;
    details.LeftIndices = leftIndices;
    details.RightIndices = rightIndices;
    details.LeftSigns = leftSigns;
    details.RightSigns = rightSigns;
    details.Tolerance = tolerance;
    details.MinimumRequiredExcursion = minimumExcursion;
    details.PersistenceMargin = min(abs([signedValues(leftIndices(1)), ...
        signedValues(rightIndices(end))]));

    if isempty(leftNonzero) || isempty(rightNonzero)
        tf = false;
        details.Reason = 'neighboring-side-is-numerically-unresolved';
    elseif any(leftNonzero ~= leftNonzero(1)) || ...
            any(rightNonzero ~= rightNonzero(1))
        tf = false;
        details.Reason = 'crossing-does-not-persist-on-neighboring-points';
    elseif leftNonzero(1) == rightNonzero(1)
        tf = false;
        details.Reason = 'neighboring-points-do-not-bracket-opposite-sides';
    elseif details.PersistenceMargin < minimumExcursion
        tf = false;
        details.Reason = 'neighboring-excursion-is-below-numerical-margin';
    else
        tf = true;
    end
end

function tf = isRealWindow(values, opts)
    scale = 1 + max(abs(values));
    tf = all(abs(imag(values)) <= opts.ImaginaryTolerance * scale);
end

function tf = isComplexWindow(values, opts)
    scale = 1 + max(abs(values));
    imaginaryParts = imag(values);
    tf = all(abs(imaginaryParts) > opts.ImaginaryTolerance * scale) && ...
        (all(imaginaryParts > 0) || all(imaginaryParts < 0));
end

function [tf, details] = reliabilityCheck( ...
        window, pointReliability, intervalReliability)
    pointStatus = pointReliability(window);
    if numel(window) > 1
        intervals = window(1):window(end) - 1;
        intervalStatus = intervalReliability(intervals);
    else
        intervals = [];
        intervalStatus = true;
    end
    tf = all(pointStatus) && all(intervalStatus);
    details = struct('Window', window, 'PointStatus', pointStatus, ...
        'Intervals', intervals, 'IntervalStatus', intervalStatus);
end

function vector = interpolateEigenvector(vectors, track, interval, fraction)
    vector = [];
    if numel(vectors) < interval + 1 || ...
            isempty(vectors{interval}) || isempty(vectors{interval + 1}) || ...
            size(vectors{interval}, 2) < track || ...
            size(vectors{interval + 1}, 2) < track
        return
    end
    left = vectors{interval}(:, track);
    right = vectors{interval + 1}(:, track);
    if numel(left) ~= numel(right) || any(~isfinite(left)) || ...
            any(~isfinite(right))
        return
    end
    inner = left' * right;
    if abs(inner) > 0
        right = right * exp(-1i * angle(inner));
    end
    vector = (1 - fraction) * left + fraction * right;
    magnitude = norm(vector);
    if magnitude <= eps || ~isfinite(magnitude)
        if fraction <= 0.5
            vector = left;
        else
            vector = right;
        end
        magnitude = norm(vector);
    end
    if magnitude > 0 && isfinite(magnitude)
        vector = vector / magnitude;
    else
        vector = [];
    end
end

function multiplier = interpolateUnitMultiplier(left, right, fraction)
    leftAngle = angle(left);
    angleIncrement = mod(angle(right) - leftAngle + pi, 2 * pi) - pi;
    criticalAngle = leftAngle + fraction * angleIncrement;
    multiplier = exp(1i * criticalAngle);
end

function [companion, bestError] = findConjugateCompanion( ...
        lambda, track, window, tolerance)
    companion = [];
    bestError = Inf;
    for other = 1:size(lambda, 1)
        if other == track
            continue
        end
        scale = max(1, abs(lambda(track, window)));
        errorValues = abs(lambda(other, window) - ...
            conj(lambda(track, window))) ./ scale;
        relativeError = max(errorValues);
        if relativeError < bestError
            bestError = relativeError;
            companion = other;
        end
    end
    if bestError > tolerance
        companion = [];
    end
end

function tangent = interpolateTangent(tangents, interval, fraction)
    tangent = [];
    if isempty(tangents)
        return
    end
    tangent = (1 - fraction) * tangents(:, interval) + ...
        fraction * tangents(:, interval + 1);
    magnitude = norm(tangent);
    if ~isfinite(magnitude) || magnitude == 0
        tangent = [];
    else
        tangent = tangent / magnitude;
    end
end

function scale = interpolateStateScale(scales, interval, fraction)
    scale = [];
    if isempty(scales)
        return
    end
    scale = (1 - fraction) * scales(:, interval) + ...
        fraction * scales(:, interval + 1);
end

function [classification, metrics] = classifyNullDirection( ...
        vector, tangent, scale, opts)
    metrics = struct('IsAdditional', NaN, 'IsTrivial', NaN, ...
        'Overlap', NaN, 'Residual', NaN, 'Rank', NaN, ...
        'Confidence', 0.5, 'StateScale', scale);
    if isempty(tangent)
        classification = 'unresolved-no-branch-tangent';
        return
    end
    if isempty(vector) || numel(vector) ~= numel(tangent)
        classification = 'unresolved-no-critical-eigenvector';
        return
    end
    if isempty(scale) || numel(scale) ~= numel(vector)
        scale = ones(numel(vector), 1);
        metrics.StateScale = scale;
    end
    vector = vector(:) ./ scale(:);
    tangent = tangent(:) ./ scale(:);
    vector = vector / norm(vector);
    tangent = tangent / norm(tangent);
    overlap = min(1, abs(tangent' * vector));
    residual = sqrt(max(0, 1 - overlap ^ 2));
    singularValues = svd([tangent, vector], 'econ');
    numericalRank = sum(singularValues > ...
        opts.NullRankTolerance * singularValues(1));
    trivialLimit = sind(opts.TrivialTangentAngleDegrees);
    additionalLimit = sind(opts.AdditionalTangentAngleDegrees);

    metrics.Overlap = overlap;
    metrics.Residual = residual;
    metrics.Rank = numericalRank;
    if residual <= trivialLimit || numericalRank < 2
        classification = 'trivial-branch-tangent';
        metrics.IsAdditional = false;
        metrics.IsTrivial = true;
        metrics.Confidence = max(0, 1 - residual / max(trivialLimit, eps));
    elseif residual >= additionalLimit
        classification = 'additional-null-direction';
        metrics.IsAdditional = true;
        metrics.IsTrivial = false;
        metrics.Confidence = min(1, ...
            (residual - trivialLimit) / (additionalLimit - trivialLimit));
    else
        classification = 'ambiguous-relative-to-branch-tangent';
        metrics.IsAdditional = NaN;
        metrics.IsTrivial = NaN;
        midpoint = 0.5 * (trivialLimit + additionalLimit);
        metrics.Confidence = abs(residual - midpoint) / ...
            max(eps, 0.5 * (additionalLimit - trivialLimit));
    end
end

function reason = plusOneRejectionReason(classification, opts)
    reason = '';
    if strcmp(classification, 'trivial-branch-tangent') && ...
            opts.RejectTrivialBranchTangent
        reason = 'plus-one-mode-is-trivial-branch-tangent';
    elseif strcmp(classification, ...
            'ambiguous-relative-to-branch-tangent') && ...
            opts.RejectAmbiguousBranchTangent
        reason = 'plus-one-null-direction-is-numerically-ambiguous';
    elseif strncmp(classification, 'unresolved-', 11) && ...
            ~strcmp(classification, ...
                'unresolved-repeated-plus-one-cluster') && ...
            opts.RequireBranchTangentForPlusOne
        reason = 'plus-one-null-direction-could-not-be-distinguished';
    end
end

function multiplicity = estimatedNullMultiplicity( ...
        lambda, interval, fraction, radius)
    estimate = (1 - fraction) * lambda(:, interval) + ...
        fraction * lambda(:, interval + 1);
    multiplicity = sum(abs(estimate - 1) <= radius);
end

function candidate = buildCandidate(type, bifurcationType, target, track, ...
        interval, fraction, multiplier, vector, coordinate, parameters, ...
        tracks, persistence, opts)
    candidate = emptyCandidate();
    candidate.Type = type;
    candidate.type = type;
    candidate.BifurcationType = bifurcationType;
    candidate.TrackIndex = track;
    candidate.LeftIndex = interval;
    candidate.RightIndex = interval + 1;
    candidate.Fraction = fraction;
    candidate.Bracket = coordinate(interval:interval + 1);
    candidate.BracketWidth = abs(diff(candidate.Bracket));
    candidate.ContinuationParameter = (1 - fraction) * ...
        coordinate(interval) + fraction * coordinate(interval + 1);
    candidate.ContinuationCoordinate = candidate.ContinuationParameter;
    candidate.Parameter = candidate.ContinuationParameter;
    candidate.parameter = candidate.ContinuationParameter;
    if ~isempty(parameters)
        candidate.ParameterVector = (1 - fraction) * ...
            parameters(:, interval) + fraction * parameters(:, interval + 1);
    end
    candidate.MultiplierLeft = tracks.Multipliers(track, interval);
    candidate.MultiplierRight = tracks.Multipliers(track, interval + 1);
    candidate.Multiplier = multiplier;
    candidate.multiplier = multiplier;
    candidate.MultiplierPair = multiplier;
    candidate.Target = target;
    candidate.Direction = sign(real(candidate.MultiplierRight - ...
        candidate.MultiplierLeft));
    if strcmp(type, 'complex-unit-circle')
        candidate.Direction = sign(abs(candidate.MultiplierRight) - ...
            abs(candidate.MultiplierLeft));
    end
    candidate.Eigenvector = vector;
    candidate.eigenvector = vector;
    candidate.Persistence = persistence;
    candidate.Confidence = crossingConfidence( ...
        tracks, track, interval, persistence, candidate, opts);
    candidate = refreshConfidence(candidate);
end

function confidence = crossingConfidence( ...
        tracks, track, interval, persistence, candidate, opts)
    confidence = emptyConfidence();
    diagnostics = tracks.Diagnostics;
    if isfield(diagnostics, 'SelectedCost') && ...
            size(diagnostics.SelectedCost, 2) >= interval + 1
        cost = diagnostics.SelectedCost(track, interval + 1);
        if isfinite(cost)
            confidence.Matching = exp(-cost / opts.ConfidenceCostScale);
        end
    end
    if isfield(diagnostics, 'SelectedEigenvectorOverlap') && ...
            size(diagnostics.SelectedEigenvectorOverlap, 2) >= interval + 1
        overlap = diagnostics.SelectedEigenvectorOverlap(track, interval + 1);
        if isfinite(overlap)
            confidence.EigenvectorContinuity = max(0, min(1, overlap));
        end
    end
    if isfield(diagnostics, 'SecondBestAssignmentGap') && ...
            numel(diagnostics.SecondBestAssignmentGap) >= interval + 1
        gap = diagnostics.SecondBestAssignmentGap(interval + 1);
        if isinf(gap)
            confidence.AssignmentUniqueness = 1;
        elseif isfinite(gap)
            confidence.AssignmentUniqueness = gap / ...
                (gap + opts.ConfidenceCostScale);
        end
    end
    margin = persistence.PersistenceMargin;
    confidence.Persistence = margin / ...
        (margin + 10 * persistence.Tolerance);
    if strcmp(candidate.Type, 'complex-unit-circle')
        left = abs(candidate.MultiplierLeft) - 1;
        right = abs(candidate.MultiplierRight) - 1;
    else
        left = real(candidate.MultiplierLeft) - candidate.Target;
        right = real(candidate.MultiplierRight) - candidate.Target;
    end
    confidence.CrossingStrength = min(1, abs(right - left) / ...
        (abs(left) + abs(right) + persistence.Tolerance));
end

function candidate = refreshConfidence(candidate)
    values = [candidate.Confidence.Matching, ...
        candidate.Confidence.AssignmentUniqueness, ...
        candidate.Confidence.EigenvectorContinuity, ...
        candidate.Confidence.Persistence, ...
        candidate.Confidence.CrossingStrength, ...
        candidate.Confidence.Conjugacy, ...
        candidate.Confidence.TangentSeparation];
    values = values(isfinite(values));
    if isempty(values)
        candidate.Confidence.Overall = NaN;
    else
        candidate.Confidence.Overall = mean(values);
    end
    candidate.ConfidenceScore = candidate.Confidence.Overall;
    candidate.ConfidenceMetrics = candidate.Confidence;
end

function [candidates, rejected] = appendUniqueCandidate( ...
        candidates, candidate, rejected, opts)
    duplicate = [];
    for i = 1:numel(candidates)
        sameType = strcmp(candidates(i).Type, candidate.Type);
        sameTrack = candidates(i).TrackIndex == candidate.TrackIndex;
        scale = 1 + abs(candidate.ContinuationParameter);
        sameLocation = abs(candidates(i).ContinuationParameter - ...
            candidate.ContinuationParameter) <= ...
            opts.CandidateMergeTolerance * scale;
        if sameType && sameTrack && sameLocation
            duplicate = i;
            break
        end
    end
    if isempty(duplicate)
        candidates(end + 1) = candidate;
        return
    end
    if candidate.ConfidenceScore > candidates(duplicate).ConfidenceScore
        old = candidates(duplicate);
        candidates(duplicate) = candidate;
        rejected(end + 1) = rejection(old.Type, old.TrackIndex, ...
            old.LeftIndex, 'duplicate-exact-sample-crossing', ...
            struct('Candidate', old));
    else
        rejected(end + 1) = rejection(candidate.Type, candidate.TrackIndex, ...
            candidate.LeftIndex, 'duplicate-exact-sample-crossing', ...
            struct('Candidate', candidate));
    end
end

function item = rejection(type, track, interval, reason, details)
    item = emptyRejection();
    item.Type = type;
    item.TrackIndex = track;
    item.LeftIndex = interval;
    item.RightIndex = interval + 1;
    item.Reason = reason;
    item.Details = details;
end

function report = makeReport(tracks, opts, coordinate, candidates, ...
        rejected, rawBracketCount, pointReliability, ...
        intervalReliability, tangentSource)
    report = struct();
    report.Tracks = tracks;
    report.Options = opts;
    report.ContinuationCoordinate = coordinate;
    report.Candidates = candidates;
    report.Rejected = rejected;
    report.RejectedDiagnostics = rejected;
    report.RawBracketCount = rawBracketCount;
    report.AcceptedCandidateCount = numel(candidates);
    report.ScreeningCandidateCount = numel(candidates);
    report.BranchSwitchReadyCandidateCount = nnz( ...
        [candidates.BranchSwitchReady]);
    report.RejectedCandidateCount = numel(rejected);
    report.PointReliability = pointReliability;
    report.IntervalReliability = intervalReliability;
    report.BranchTangentSource = tangentSource;
    report.Method = ['global adjacent multiplier assignment; signed bracket ' ...
        'with neighboring-point persistence'];
end

function confidence = emptyConfidence()
    confidence = struct('Overall', NaN, 'Matching', 0.5, ...
        'AssignmentUniqueness', 0.5, 'EigenvectorContinuity', 0.5, ...
        'Persistence', 0.5, 'CrossingStrength', 0.5, ...
        'Conjugacy', 1, 'TangentSeparation', 1);
end

function candidate = emptyCandidate()
    candidate = struct('Type', '', 'type', '', 'BifurcationType', '', ...
        'TrackIndex', NaN, 'LeftIndex', NaN, 'RightIndex', NaN, ...
        'Fraction', NaN, 'Bracket', [], 'BracketWidth', NaN, ...
        'ContinuationParameter', NaN, 'ContinuationCoordinate', NaN, ...
        'Parameter', NaN, 'parameter', NaN, ...
        'ParameterVector', [], 'MultiplierLeft', NaN, ...
        'MultiplierRight', NaN, 'Multiplier', NaN, 'multiplier', NaN, ...
        'MultiplierPair', [], 'Target', NaN, 'Direction', NaN, ...
        'Eigenvector', [], 'eigenvector', [], 'ConjugateTrackIndex', NaN, ...
        'ConjugacyError', NaN, 'Persistence', struct(), ...
        'NullDirectionClassification', 'not-applicable', ...
        'IsAdditionalNullDirection', NaN, ...
        'IsTrivialBranchTangent', NaN, 'BranchTangentOverlap', NaN, ...
        'AdditionalNullMetric', NaN, 'NullDirectionRank', NaN, ...
        'NullMultiplicity', NaN, 'BranchTangent', [], ...
        'NullDirectionScale', [], ...
        'CriticalClusterCount', NaN, 'RepeatedNullCluster', false, ...
        'BasisInvariantDirectionResolved', false, ...
        'RequiresInvariantSubspaceRefinement', false, ...
        'BasisDependentTrackDiagnostics', struct(), ...
        'ScreeningCandidate', true, ...
        'RefinementStatus', 'unrefined-detector-bracket', ...
        'BranchSwitchReady', false, ...
        'BranchSwitchReadiness', 'unrefined-detector-candidate', ...
        'Confidence', emptyConfidence(), 'ConfidenceMetrics', ...
        emptyConfidence(), 'ConfidenceScore', NaN);
end

function item = emptyRejection()
    item = struct('Type', '', 'TrackIndex', NaN, 'LeftIndex', NaN, ...
        'RightIndex', NaN, 'Reason', '', 'Details', struct());
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
        error('DetectBifurcation:MissingField', ...
            'A required multiplier field is missing.');
    end
end
