function validation = ValidateRoadmapTransition(analysis, specification, options)
%VALIDATEROADMAPTRANSITION Compare frozen predictions with held-out data.
%
%   This is the only experiment stage that loads SPEC.DaughterFile.  It
%   compares the already-refined critical orbit and already-corrected +/-
%   branches with a saved daughter secant.  Event-time variables participate
%   in orbit validation and distance calculations, but never in the Floquet
%   eigenvector or its subspace alignment.

    if nargin < 3 || isempty(options)
        options = struct();
    end
    opts = ParseOptions(options);
    ValidateInputs(analysis,specification);
    loaded = load(specification.DaughterFile,'results');
    daughter = ValidateDaughterData(loaded,specification);
    near = daughter(:,specification.DaughterNearIndex);
    outgoing = daughter(:,specification.DaughterOutgoingIndex);
    refinement = analysis.refinement;

    parameterError = norm(near(23:29)-refinement.parameters,inf);
    coordinateError = abs(refinement.coordinate-near(1));
    [orbitDistance,orbitDifference,orbitScale] = ...
        ScaledOrbitDistance(refinement.solution,near(1:22));

    qIndex = [1 2 4:13];
    stateScale = refinement.eigenData.StateScale(:);
    tangent = refinement.localBranchTangent(:)./stateScale;
    tangent = tangent/norm(tangent);
    predicted = refinement.eigenData.Eigenvector(:)./stateScale;
    predicted = RemoveTangent(predicted,tangent);
    daughterSecant = (outgoing(qIndex)-near(qIndex))./stateScale;
    daughterSecant = RemoveTangent(daughterSecant,tangent);
    directionAlignment = abs(predicted'*daughterSecant);

    attempts = analysis.attempts([analysis.attempts.acceptedBranchPoint]);
    correctionAlignments = NaN(1,numel(attempts));
    for k = 1:numel(attempts)
        direction = attempts(k).scaledTransverseDirection(:);
        correctionAlignments(k) = abs(direction'*daughterSecant);
    end
    finiteAlignment = correctionAlignments(isfinite(correctionAlignments));
    if isempty(finiteAlignment)
        minimumCorrectionAlignment = NaN;
        maximumCorrectionAlignment = NaN;
    else
        minimumCorrectionAlignment = min(finiteAlignment);
        maximumCorrectionAlignment = max(finiteAlignment);
    end
    correctionAlignmentAccepted = PersistentSmallestRadiusAlignment( ...
        attempts,correctionAlignments,analysis, ...
        opts.MinimumCorrectionAlignment);

    [criticalPairStateError,criticalPairTimingError] = ...
        PairSymmetryErrors(refinement.solution,specification.ExpectedBrokenPair);
    [daughterPairStateError,daughterPairTimingError] = ...
        PairSymmetryErrors(near(1:22),specification.ExpectedBrokenPair);
    try
        [daughterGait,daughterAbbreviation] = Gait_Identification(near(1:22));
        daughterGait = char(string(daughterGait));
        daughterAbbreviation = char(string(daughterAbbreviation));
        gaitError = '';
    catch exception
        daughterGait = '';
        daughterAbbreviation = '';
        gaitError = sprintf('%s: %s',exception.identifier,exception.message);
    end

    if opts.ValidatePeriodicOrbits
        periodicOptions = opts.PeriodicValidationOptions;
        periodicOptions.ReferenceTopology = [];
        nearPeriodic = floquet.validatePeriodicOrbit( ...
            near(1:22),near(23:29),periodicOptions);
        outgoingPeriodic = floquet.validatePeriodicOrbit( ...
            outgoing(1:22),outgoing(23:29),periodicOptions);
    else
        nearPeriodic = struct('accepted',true,'status','not-requested');
        outgoingPeriodic = struct('accepted',true,'status','not-requested');
    end

    assertions = struct();
    assertions.parentPredictionWasFrozenBeforeValidation = ...
        ~analysis.daughterDataLoaded && ...
        ~analysis.parentOnlyValidation.daughterDataUsed;
    assertions.parametersMatch = parameterError <= opts.ParameterTolerance;
    assertions.criticalCoordinateNearSavedAttachment = ...
        coordinateError <= opts.MaximumCoordinateDifference;
    assertions.savedDaughterNearCriticalOrbit = ...
        orbitDistance <= opts.MaximumScaledOrbitDistance;
    assertions.savedDaughterSecantMatchesFloquetMode = ...
        directionAlignment >= opts.MinimumDirectionAlignment;
    assertions.correctedBranchesMatchDaughterDirection = ...
        correctionAlignmentAccepted;
    assertions.criticalParentRetainsPairSymmetry = ...
        criticalPairStateError <= opts.ParentPairStateTolerance && ...
        criticalPairTimingError <= opts.ParentPairTimingTolerance;
    assertions.daughterBreaksExpectedPairSymmetry = ...
        daughterPairStateError >= opts.MinimumBrokenPairState && ...
        daughterPairTimingError >= opts.MinimumBrokenPairTiming;
    assertions.daughterGaitMatchesExpectation = ...
        strcmp(daughterAbbreviation,specification.ExpectedGaitAbbreviation);
    assertions.savedDaughterOrbitsArePeriodic = ...
        nearPeriodic.accepted && outgoingPeriodic.accepted;
    names = fieldnames(assertions);
    values = false(size(names));
    for k = 1:numel(names)
        values(k) = logical(assertions.(names{k}));
    end

    validation = struct();
    validation.version = 'roadmap-held-out-transition-validation-v1';
    validation.generatedAt = Timestamp();
    validation.accepted = all(values);
    validation.status = Ternary(validation.accepted,'validated','rejected');
    validation.transitionID = specification.ID;
    validation.daughterFile = specification.DaughterFile;
    validation.daughterNearIndex = specification.DaughterNearIndex;
    validation.daughterOutgoingIndex = specification.DaughterOutgoingIndex;
    validation.daughterDataRole = specification.DaughterDataRole;
    validation.parameterErrorNormInf = parameterError;
    validation.coordinateDifference = coordinateError;
    validation.scaledOrbitDistance22 = orbitDistance;
    validation.scaledOrbitDifference22 = orbitDifference;
    validation.orbitScale22 = orbitScale;
    validation.linearDirectionAlignment = directionAlignment;
    validation.correctionDirectionAlignments = correctionAlignments;
    validation.minimumCorrectionDirectionAlignment = ...
        minimumCorrectionAlignment;
    validation.maximumCorrectionDirectionAlignment = ...
        maximumCorrectionAlignment;
    validation.criticalPairStateError = criticalPairStateError;
    validation.criticalPairTimingError = criticalPairTimingError;
    validation.daughterPairStateError = daughterPairStateError;
    validation.daughterPairTimingError = daughterPairTimingError;
    validation.daughterGait = daughterGait;
    validation.daughterGaitAbbreviation = daughterAbbreviation;
    validation.gaitClassificationError = gaitError;
    validation.nearPeriodicValidation = nearPeriodic;
    validation.outgoingPeriodicValidation = outgoingPeriodic;
    validation.assertions = assertions;
    validation.rejectionReasons = names(~values).';
    validation.options = opts;
    if opts.ThrowOnFailure && ~validation.accepted
        error('ValidateRoadmapTransition:Rejected', ...
            '%s failed: %s',specification.ID, ...
            strjoin(validation.rejectionReasons,' | '));
    end
end

function opts = ParseOptions(options)
    defaults = struct();
    defaults.ValidatePeriodicOrbits = true;
    defaults.ParameterTolerance = 1e-12;
    defaults.MaximumCoordinateDifference = 0.02;
    defaults.MaximumScaledOrbitDistance = 0.25;
    defaults.MinimumDirectionAlignment = 0.90;
    defaults.MinimumCorrectionAlignment = 0.80;
    defaults.ParentPairStateTolerance = 1e-6;
    defaults.ParentPairTimingTolerance = 1e-6;
    defaults.MinimumBrokenPairState = 1e-4;
    defaults.MinimumBrokenPairTiming = 1e-5;
    defaults.PeriodicValidationOptions = struct( ...
        'TopologyMode','clustered', ...
        'CheckTimingRepeatability',true, ...
        'ErrorOnFailure',false);
    defaults.ThrowOnFailure = false;
    if ~isstruct(options) || ~isscalar(options)
        error('ValidateRoadmapTransition:Options', ...
            'options must be a scalar structure.');
    end
    opts = defaults;
    names = fieldnames(options);
    allowed = fieldnames(defaults);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k},allowed),1);
        if isempty(hit)
            error('ValidateRoadmapTransition:UnknownOption', ...
                'Unknown option %s.',names{k});
        end
        opts.(allowed{hit}) = options.(names{k});
    end
    opts.ValidatePeriodicOrbits = ValidateLogical( ...
        opts.ValidatePeriodicOrbits,'ValidatePeriodicOrbits');
    opts.ThrowOnFailure = ValidateLogical(opts.ThrowOnFailure,'ThrowOnFailure');
    if ~isstruct(opts.PeriodicValidationOptions) || ...
            ~isscalar(opts.PeriodicValidationOptions)
        error('ValidateRoadmapTransition:PeriodicOptions', ...
            'PeriodicValidationOptions must be a scalar structure.');
    end
    positive = {'ParameterTolerance','MaximumCoordinateDifference', ...
        'MaximumScaledOrbitDistance','MinimumDirectionAlignment', ...
        'MinimumCorrectionAlignment','ParentPairStateTolerance', ...
        'ParentPairTimingTolerance','MinimumBrokenPairState', ...
        'MinimumBrokenPairTiming'};
    for k = 1:numel(positive)
        value = opts.(positive{k});
        if ~(isscalar(value) && isfinite(value) && value > 0)
            error('ValidateRoadmapTransition:PositiveOption', ...
                '%s must be positive and finite.',positive{k});
        end
    end
    if opts.MinimumDirectionAlignment > 1 || ...
            opts.MinimumCorrectionAlignment > 1
        error('ValidateRoadmapTransition:Alignment', ...
            'Alignment thresholds cannot exceed one.');
    end
end

function ValidateInputs(analysis,specification)
    if ~isstruct(analysis) || ~isscalar(analysis) || ...
            ~isfield(analysis,'accepted') || ~analysis.accepted || ...
            ~isfield(analysis,'parentOnlyValidation') || ...
            ~analysis.parentOnlyValidation.accepted
        error('ValidateRoadmapTransition:ParentAnalysis', ...
            'An accepted frozen parent-only analysis is required.');
    end
    if ~isstruct(specification) || ~isscalar(specification) || ...
            ~isfield(specification,'DaughterFile') || ...
            ~isfile(specification.DaughterFile)
        error('ValidateRoadmapTransition:DaughterFile', ...
            'A valid held-out daughter specification is required.');
    end
    if ~strcmp(analysis.ID,specification.ID)
        error('ValidateRoadmapTransition:TransitionMismatch', ...
            'Analysis and specification IDs do not match.');
    end
end

function results = ValidateDaughterData(loaded,specification)
    if ~isstruct(loaded) || ~isfield(loaded,'results') || ...
            ~isnumeric(loaded.results) || size(loaded.results,1) ~= 29 || ...
            any(~isfinite(loaded.results(:)))
        error('ValidateRoadmapTransition:DaughterData', ...
            'Held-out daughter must contain finite 29-by-N results.');
    end
    results = loaded.results;
    if ~isfield(specification,'DaughterNearIndex') || ...
            ~isfield(specification,'DaughterOutgoingIndex')
        error('ValidateRoadmapTransition:DaughterIndex', ...
            'The daughter specification must define near/outgoing indices.');
    end
    indices = [specification.DaughterNearIndex, ...
        specification.DaughterOutgoingIndex];
    validIndices = isnumeric(indices) && numel(indices) == 2 && ...
        all(isfinite(indices)) && all(indices >= 1) && ...
        all(indices == floor(indices));
    if ~validIndices
        error('ValidateRoadmapTransition:DaughterIndex', ...
            'Daughter near/outgoing indices must be positive finite integers.');
    end
    if any(indices > size(results,2))
        error('ValidateRoadmapTransition:DaughterIndex', ...
            'Configured daughter indices exceed the saved branch.');
    end
    if indices(1) == indices(2)
        error('ValidateRoadmapTransition:DaughterSecant', ...
            'Daughter near/outgoing indices must be distinct.');
    end
end

function accepted = PersistentSmallestRadiusAlignment( ...
        attempts,alignments,analysis,threshold)
    signs = [-1 1];
    requiredRadii = 1;
    if isstruct(analysis.parentOnlyValidation) && ...
            isfield(analysis.parentOnlyValidation, ...
                'minimumAcceptedRadiiPerSign')
        candidate = analysis.parentOnlyValidation.minimumAcceptedRadiiPerSign;
        if isnumeric(candidate) && isscalar(candidate) && ...
                isfinite(candidate) && candidate >= 1 && ...
                candidate == floor(candidate)
            requiredRadii = candidate;
        end
    end

    acceptedBySign = false(size(signs));
    for k = 1:numel(signs)
        selected = [attempts.sign] == signs(k) & isfinite(alignments);
        if ~any(selected)
            continue
        end
        radii = [attempts(selected).amplitude];
        if any(~isfinite(radii)) || any(radii <= 0) || ...
                numel(unique(radii)) < requiredRadii
            continue
        end
        smallestRadius = min(radii);
        radiusTolerance = 10*eps(max(1,smallestRadius));
        atSmallestRadius = selected & ...
            abs([attempts.amplitude]-smallestRadius) <= radiusTolerance;
        acceptedBySign(k) = any(atSmallestRadius) && ...
            all(alignments(atSmallestRadius) >= threshold);
    end
    accepted = all(acceptedBySign);
end

function direction = RemoveTangent(direction,tangent)
    direction = direction-tangent*(tangent'*direction);
    magnitude = norm(direction);
    if ~(isfinite(magnitude) && magnitude > 1e-12)
        error('ValidateRoadmapTransition:DegenerateDirection', ...
            'A transverse comparison direction is degenerate.');
    end
    direction = direction/magnitude;
end

function [distance,difference,scale] = ScaledOrbitDistance(a,b)
    a = a(:);
    b = b(:);
    qIndex = [1 2 4:13];
    qScale = [10;1;0.5;0.5;0.3*ones(8,1)];
    periods = [a(22),b(22)];
    if any(~isfinite(periods)) || any(periods <= 0)
        error('ValidateRoadmapTransition:OrbitPeriod', ...
            'Compared periodic orbits must have positive finite periods.');
    end
    referencePeriod = mean(periods);
    eventScale = max(0.05,0.25*referencePeriod);
    periodScale = max(0.1,0.5*referencePeriod);
    dq = a(qIndex)-b(qIndex);
    phaseA = mod(a(14:21)/periods(1),1);
    phaseB = mod(b(14:21)/periods(2),1);
    phaseDifference = mod(phaseA-phaseB+0.5,1)-0.5;
    % Retain the historical time-valued diagnostic and scale while deriving
    % it from circular phase. This avoids comparing unlike raw times when
    % the two periodic orbits have slightly different periods.
    dE = referencePeriod*phaseDifference;
    dT = a(22)-b(22);
    difference = [dq;dE;dT];
    scale = [qScale;eventScale*ones(8,1);periodScale];
    distance = norm(difference./scale);
end

function [stateError,timingError] = PairSymmetryErrors(z,pair)
    z = z(:);
    if strcmp(pair,'hind')
        stateLeft = [6 7]; stateRight = [10 11];
        timeLeft = [14 15]; timeRight = [18 19];
    else
        stateLeft = [8 9]; stateRight = [12 13];
        timeLeft = [16 17]; timeRight = [20 21];
    end
    stateError = norm(z(stateLeft)-z(stateRight));
    T = z(22);
    timingDifference = z(timeLeft)-z(timeRight);
    timingDifference = mod(timingDifference+0.5*T,T)-0.5*T;
    timingError = norm(timingDifference);
end

function value = ValidateLogical(value,name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
        error('ValidateRoadmapTransition:LogicalOption', ...
            '%s must be scalar logical.',name);
    end
    value = logical(value);
end

function value = Ternary(condition,a,b)
    if condition, value = a; else, value = b; end
end

function value = Timestamp()
    value = char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
end
