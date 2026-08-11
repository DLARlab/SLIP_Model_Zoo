function [results, info] = continueDaughterBranch(seedInner, seedOuter, Para, options)
%CONTINUEDAUGHTERBRANCH Continue a daughter branch from two corrected seeds.
%
%   [RESULTS,INFO] = CONTINUEDAUGHTERBRANCH(Z1,Z2,PARA,OPTIONS) validates
%   two 22-variable periodic solutions on the same outgoing branch-switch
%   ray and passes them to NumericalContinuation1D_Quadruped_v2. Z1 and Z2
%   must be independently corrected periodic orbits at two different
%   nonzero amplitudes; the critical orbit and its raw Floquet eigenvector
%   are not continuation seeds.
%
%   To enforce the same-ray condition, supply OPTIONS.CriticalSolution
%   (22 values) and OPTIONS.Direction (12 reduced-section values). The two
%   scaled projections on Direction must have the same sign. Important
%   options are:
%
%       Radius                    continuation step radius (default 0.02)
%       NumericalOptions          fsolve options for the continuation core
%       RunOptions                runtime options for the continuation core
%       ValidationOptions         options passed to ValidatePeriodicOrbit
%       ValidationFunction        validation hook (default ValidatePeriodicOrbit)
%       AllowNonProductionValidationFunction default false; an explicitly
%                                  allowed custom callback remains diagnostic;
%                                  custom reports are never production authority
%                                  even when topology is independently checked
%       ValidateSeeds             default true
%       ValidateOutput            default true
%       RequireConsistentOutputTopology default true
%       OutputValidationStride    default 1 (validate every point)
%       MinimumOutputPoints       default 3
%       CriticalSolution          optional 22-vector
%       Direction                 optional 12-vector; required with critical
%       SectionScale              positive 12-vector for ray geometry
%       RequireSameRay            default true when critical/direction exist
%       MinimumDirectionCosine    local output alignment threshold, 0.8
%       MinimumSameRayOutputPoints minimum aligned output points, 3
%       SaveResult                default false
%       OutputFile                MAT file used when SaveResult is true
%       Overwrite                 default false
%
%   ContinuationFunction is a test/integration hook with the same six-input
%   contract as NumericalContinuation1D_Quadruped_v2.

    if nargin < 4 || isempty(options)
        options = struct();
    end
    floquet.internal.ensureRuntimePaths(true);

    opts = ParseOptions(options);
    [productionValidationEvaluator,validationEvaluatorIdentity] = ...
        floquet.internal.provenance.evaluatorIdentity( ...
            opts.ValidationFunction, 'floquet.validatePeriodicOrbit');
    if (opts.ValidateSeeds || opts.ValidateOutput) && ...
            ~productionValidationEvaluator && ...
            ~opts.RequireConsistentOutputTopology && ...
            ~opts.AllowNonProductionValidationFunction
        error('ContinueDaughterBranch:CustomValidationRequiresOptIn', [ ...
            'A custom ValidationFunction without independent topology ' ...
            'checking is nonproduction evidence. Set ' ...
            'AllowNonProductionValidationFunction=true only for an ' ...
            'explicit diagnostic/test run.']);
    end
    z1 = ValidateSeed(seedInner, 'seedInner');
    z2 = ValidateSeed(seedOuter, 'seedOuter');
    Para = ValidateParameters(Para);
    z1 = EventTimingRegulation(z1);
    z2 = EventTimingRegulation(z2);

    [ray, separation] = ValidateSeedGeometry(z1, z2, opts);
    seedValidation = repmat(EmptyValidation(), 1, 2);
    referenceTopology = struct();
    seedTopologyEvidenceValid = ~opts.RequireConsistentOutputTopology;
    if opts.ValidateSeeds
        firstReport = opts.ValidationFunction( ...
            z1, Para, opts.ValidationOptions);
        seedValidation(1) = SummarizeValidation(firstReport);
        firstAccepted = seedValidation(1).evaluatorAccepted;
        firstTopology = ExtractEventTopology(firstReport);
        if firstAccepted && opts.RequireConsistentOutputTopology && ...
                ~ValidEventTopology(firstTopology)
            error('ContinueDaughterBranch:MissingSeedTopology', [ ...
                'The accepted first-seed validation did not return a valid ' ...
                'event topology. Topology-consistent continuation requires ' ...
                'a valid firstReport.mapInfo.eventTopology reference.']);
        end
        if firstAccepted && ValidEventTopology(firstTopology)
            referenceTopology = firstTopology;
        end
        seedValidation(1) = ApplyTopologyEvidence(seedValidation(1), ...
            firstTopology, referenceTopology, ...
            opts.RequireConsistentOutputTopology, opts.ValidationOptions, ...
            true);
        secondOptions = opts.ValidationOptions;
        if opts.RequireConsistentOutputTopology && ~isempty(fieldnames( ...
                referenceTopology))
            secondOptions.ReferenceTopology = referenceTopology;
        end
        secondReport = opts.ValidationFunction(z2, Para, secondOptions);
        seedValidation(2) = SummarizeValidation(secondReport);
        seedValidation(2) = ApplyTopologyEvidence(seedValidation(2), ...
            ExtractEventTopology(secondReport), referenceTopology, ...
            opts.RequireConsistentOutputTopology, opts.ValidationOptions, ...
            false);
        seedTopologyEvidenceValid = ~opts.RequireConsistentOutputTopology || ...
            all([seedValidation.topologyEvidenceValid] & ...
                [seedValidation.topologyConsistent]);
        if ~all([seedValidation.accepted])
            messages = {seedValidation(~[seedValidation.accepted]).message};
            error('ContinueDaughterBranch:InvalidSeedOrbit', ...
                'A continuation seed failed validation: %s', ...
                strjoin(messages, ' | '));
        end
    end

    startTime = tic;
    [results, flags, continuationInfo] = opts.ContinuationFunction( ...
        z1, z2, Para, opts.Radius, opts.NumericalOptions, opts.RunOptions);
    elapsed = toc(startTime);
    ValidateContinuationOutput(results, Para);

    pointCount = size(results, 2);
    outputValidation = repmat(EmptyValidation(), 1, pointCount);
    validatedMask = false(1, pointCount);
    if opts.ValidateOutput
        validationIndices = unique([1:opts.OutputValidationStride:pointCount, ...
            pointCount]);
        outputValidationOptions = opts.ValidationOptions;
        if opts.RequireConsistentOutputTopology && ...
                ~isempty(fieldnames(referenceTopology))
            outputValidationOptions.ReferenceTopology = referenceTopology;
        end
        for k = validationIndices
            validatedMask(k) = true;
            outputReport = opts.ValidationFunction(results(1:22, k), ...
                results(23:29, k), outputValidationOptions);
            outputValidation(k) = SummarizeValidation(outputReport);
            outputValidation(k) = ApplyTopologyEvidence( ...
                outputValidation(k), ExtractEventTopology(outputReport), ...
                referenceTopology, opts.RequireConsistentOutputTopology, ...
                opts.ValidationOptions, false);
        end
    end

    distinctPointCount = CountDistinctSolutions(results(1:22, :), opts);
    enoughPoints = distinctPointCount >= opts.MinimumOutputPoints;
    daughterGeometry = ValidateOutputGeometry(results, ray, opts);
    outputAcceptedMask = validatedMask & ...
        LogicalSummaryField(outputValidation, 'accepted');
    if opts.RequireConsistentOutputTopology
        outputAcceptedMask = outputAcceptedMask & ...
            LogicalSummaryField(outputValidation, 'topologyEvidenceValid') & ...
            LogicalSummaryField(outputValidation, 'topologyConsistent');
    end
    daughterGeometry = AddValidatedRunEvidence(daughterGeometry, ...
        results(1:22, :), outputAcceptedMask, opts);
    outputCoverageComplete = opts.ValidateOutput && all(validatedMask);
    acceptedOutputTopologyComplete = ...
        AcceptedTopologyEvidenceComplete(outputValidation, validatedMask, ...
        opts.RequireConsistentOutputTopology);
    independentTopologyChecked = opts.RequireConsistentOutputTopology && ...
        seedTopologyEvidenceValid && acceptedOutputTopologyComplete;
    validationAuthority = BuildValidationAuthority(opts, ...
        productionValidationEvaluator, independentTopologyChecked, ...
        validationEvaluatorIdentity);
    validationEvidenceComplete = opts.ValidateSeeds && ...
        opts.ValidateOutput && outputCoverageComplete && ...
        seedTopologyEvidenceValid && ...
        validationAuthority.scientificAcceptanceEligible;
    validatedAccepted = validationEvidenceComplete && ...
        all([outputValidation(validatedMask).accepted]);
    geometryAccepted = daughterGeometry.checked && ...
        daughterGeometry.accepted;
    [gaitNames, gaitAbbreviations] = ClassifyGaits(results(1:22, :));

    info = struct();
    info.schemaVersion = 'daughter-continuation-v1.1';
    info.generatedAt = Timestamp();
    info.accepted = enoughPoints && validatedAccepted && geometryAccepted;
    if ~validationEvidenceComplete
        info.status = 'unvalidated-test-or-diagnostic-output';
    else
        info.status = Ternary(info.accepted, 'accepted', 'rejected');
    end
    info.message = BuildMessage(enoughPoints, validatedAccepted, ...
        geometryAccepted, daughterGeometry, pointCount, ...
        distinctPointCount, opts.MinimumOutputPoints, ...
        validationEvidenceComplete);
    info.seedSolutions = [z1 z2];
    info.parameters = Para;
    info.seedSeparation = separation;
    info.rayGeometry = ray;
    info.daughterGeometry = daughterGeometry;
    info.seedValidation = seedValidation;
    info.referenceTopology = referenceTopology;
    info.seedTopologyEvidenceValid = seedTopologyEvidenceValid;
    info.flags = flags;
    info.continuationInfo = continuationInfo;
    info.outputValidation = outputValidation;
    info.outputValidatedMask = validatedMask;
    info.outputValidationCoverageComplete = outputCoverageComplete;
    info.outputAcceptedEvidenceMask = outputAcceptedMask;
    info.acceptedOutputTopologyEvidenceComplete = ...
        acceptedOutputTopologyComplete;
    info.validationAuthority = validationAuthority;
    info.validationEvidenceComplete = validationEvidenceComplete;
    info.gaitNames = gaitNames;
    info.gaitAbbreviations = gaitAbbreviations;
    info.pointCount = pointCount;
    info.distinctPointCount = distinctPointCount;
    info.elapsedSeconds = elapsed;
    info.options = SerializableOptions(opts);

    if opts.SaveResult
        info.outputFile = CanonicalFile(opts.OutputFile);
        SaveOutput(info.outputFile, results, info, opts.Overwrite);
    else
        info.outputFile = '';
    end

    if ~info.accepted && opts.ThrowOnFailure
        error('ContinueDaughterBranch:ContinuationRejected', '%s', ...
            info.message);
    end
end

function opts = ParseOptions(options)
    if ~isstruct(options) || ~isscalar(options)
        error('ContinueDaughterBranch:InvalidOptions', ...
            'options must be a scalar structure.');
    end
    defaults = struct();
    defaults.Radius = 0.02;
    defaults.NumericalOptions = optimset( ...
        'Algorithm', 'levenberg-marquardt', 'Display', 'off', ...
        'MaxFunEvals', 50000, 'MaxIter', 3000, 'UseParallel', false, ...
        'TolFun', 1e-12, 'TolX', 1e-12);
    defaults.RunOptions = struct( ...
        'ResetFigureOnStart', false, 'ClearCommandWindow', false, ...
        'SaveTempSol', false, 'DeleteTempSolOnFinish', false, ...
        'IlluSols', false, 'DisplayCommandStatus', false, ...
        'DirectionPauseSeconds', 0, 'FailurePauseSeconds', 0, ...
        'RadiusReductionPauseSeconds', 0, ...
        'PromptVelocityZeroCrossing', false);
    defaults.ValidationOptions = struct('ErrorOnFailure', false);
    defaults.ValidationFunction = @floquet.validatePeriodicOrbit;
    defaults.AllowNonProductionValidationFunction = false;
    defaults.ValidateSeeds = true;
    defaults.ValidateOutput = true;
    defaults.RequireConsistentOutputTopology = true;
    defaults.OutputValidationStride = 1;
    defaults.MinimumOutputPoints = 3;
    defaults.CriticalSolution = [];
    defaults.Direction = [];
    defaults.SectionScale = ones(12, 1);
    defaults.RequireSameRay = [];
    defaults.MinimumSeedSeparation = 1e-7;
    defaults.MinimumRayProjection = 1e-8;
    defaults.MinimumDirectionCosine = 0.8;
    defaults.MinimumSameRayOutputPoints = 3;
    defaults.SaveResult = false;
    defaults.OutputFile = '';
    defaults.Overwrite = false;
    defaults.ThrowOnFailure = false;
    defaults.ContinuationFunction = @NumericalContinuation1D_Quadruped_v2;

    opts = defaults;
    supplied = fieldnames(options);
    allowed = fieldnames(defaults);
    for k = 1:numel(supplied)
        hit = find(strcmpi(supplied{k}, allowed), 1);
        if isempty(hit)
            error('ContinueDaughterBranch:UnknownOption', ...
                'Unknown option %s.', supplied{k});
        end
        opts.(allowed{hit}) = options.(supplied{k});
    end

    positiveScalars = {'Radius', 'MinimumSeedSeparation', ...
        'MinimumRayProjection'};
    for k = 1:numel(positiveScalars)
        value = opts.(positiveScalars{k});
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value > 0)
            error('ContinueDaughterBranch:InvalidPositiveOption', ...
                '%s must be a positive finite scalar.', positiveScalars{k});
        end
    end
    integerScalars = {'OutputValidationStride', 'MinimumOutputPoints', ...
        'MinimumSameRayOutputPoints'};
    for k = 1:numel(integerScalars)
        value = opts.(integerScalars{k});
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
                value >= 1 && value == floor(value))
            error('ContinueDaughterBranch:InvalidIntegerOption', ...
                '%s must be a positive integer.', integerScalars{k});
        end
    end
    if ~(isnumeric(opts.MinimumDirectionCosine) && ...
            isscalar(opts.MinimumDirectionCosine) && ...
            isfinite(opts.MinimumDirectionCosine) && ...
            opts.MinimumDirectionCosine > 0 && ...
            opts.MinimumDirectionCosine <= 1)
        error('ContinueDaughterBranch:MinimumDirectionCosine', ...
            'MinimumDirectionCosine must lie in (0,1].');
    end
    logicalFields = {'ValidateSeeds', 'ValidateOutput', ...
        'RequireConsistentOutputTopology', 'SaveResult', 'Overwrite', ...
        'ThrowOnFailure', 'AllowNonProductionValidationFunction'};
    for k = 1:numel(logicalFields)
        opts.(logicalFields{k}) = ValidateLogical( ...
            opts.(logicalFields{k}), logicalFields{k});
    end
    if isempty(opts.RequireSameRay)
        opts.RequireSameRay = ~isempty(opts.CriticalSolution) || ...
            ~isempty(opts.Direction);
    else
        opts.RequireSameRay = ValidateLogical( ...
            opts.RequireSameRay, 'RequireSameRay');
    end
    if ~isa(opts.ContinuationFunction, 'function_handle')
        error('ContinueDaughterBranch:ContinuationFunction', ...
            'ContinuationFunction must be a function handle.');
    end
    if ~isa(opts.ValidationFunction, 'function_handle')
        error('ContinueDaughterBranch:ValidationFunction', ...
            'ValidationFunction must be a function handle.');
    end
    if ~isstruct(opts.RunOptions) || ~isscalar(opts.RunOptions) || ...
            ~isstruct(opts.ValidationOptions) || ...
            ~isscalar(opts.ValidationOptions)
        error('ContinueDaughterBranch:NestedOptions', ...
            'RunOptions and ValidationOptions must be scalar structures.');
    end
    opts.SectionScale = opts.SectionScale(:);
    if numel(opts.SectionScale) ~= 12 || ...
            any(~isfinite(opts.SectionScale)) || any(opts.SectionScale <= 0)
        error('ContinueDaughterBranch:SectionScale', ...
            'SectionScale must be a positive finite 12-vector.');
    end
    if opts.RequireSameRay
        if isempty(opts.CriticalSolution) || isempty(opts.Direction)
            error('ContinueDaughterBranch:MissingRayReference', ...
                ['CriticalSolution and Direction are both required when ' ...
                 'RequireSameRay is true.']);
        end
        opts.CriticalSolution = ValidateSeed( ...
            opts.CriticalSolution, 'CriticalSolution');
        opts.Direction = opts.Direction(:);
        if numel(opts.Direction) ~= 12 || ...
                any(~isfinite(opts.Direction)) || norm(opts.Direction) == 0
            error('ContinueDaughterBranch:Direction', ...
                'Direction must be a finite nonzero reduced 12-vector.');
        end
    end
    if opts.RequireConsistentOutputTopology && ~opts.ValidateSeeds
        error('ContinueDaughterBranch:TopologyReferenceRequiresSeedValidation', ...
            ['RequireConsistentOutputTopology needs ValidateSeeds=true so ' ...
             'all validated seeds and outputs can be compared with a valid ' ...
             'first-seed event topology.']);
    end
    if opts.SaveResult
        if isstring(opts.OutputFile) && isscalar(opts.OutputFile)
            opts.OutputFile = char(opts.OutputFile);
        end
        if ~ischar(opts.OutputFile) || isempty(strtrim(opts.OutputFile))
            error('ContinueDaughterBranch:OutputFile', ...
                'OutputFile is required when SaveResult is true.');
        end
        [~, ~, extension] = fileparts(opts.OutputFile);
        if ~strcmpi(extension, '.mat')
            error('ContinueDaughterBranch:OutputExtension', ...
                'OutputFile must have a .mat extension.');
        end
    end
end

function seed = ValidateSeed(seed, name)
    if isstruct(seed) && isscalar(seed)
        candidates = {'zCorrected', 'correctedSolution', ...
            'solution', 'z', 'Seed'};
        value = [];
        for k = 1:numel(candidates)
            if isfield(seed, candidates{k})
                value = seed.(candidates{k});
                break
            end
        end
        seed = value;
    end
    seed = seed(:);
    if ~isnumeric(seed) || ~isreal(seed) || numel(seed) ~= 22 || ...
            any(~isfinite(seed)) || seed(22) <= 0
        error('ContinueDaughterBranch:InvalidSeed', ...
            '%s must contain 22 finite real values and a positive period.', name);
    end
end

function Para = ValidateParameters(Para)
    Para = Para(:);
    if ~isnumeric(Para) || ~isreal(Para) || numel(Para) ~= 7
        error('ContinueDaughterBranch:InvalidParameters', ...
            'Para must have seven real values; only Para(3) may be positive Inf.');
    end
    allowedInf = (1:7).' == 3 & isinf(Para) & Para > 0;
    if any(~(isfinite(Para) | allowedInf))
        error('ContinueDaughterBranch:InvalidParameters', ...
            'Para must have seven real values; only Para(3) may be positive Inf.');
    end
end

function [ray, separation] = ValidateSeedGeometry(z1, z2, opts)
    local = LocalStateDifference(z2, z1);
    scale22 = [opts.SectionScale(1:2); 1; opts.SectionScale(3:12); ...
        max(0.05, 0.25 * max(z1(22), z2(22))) * ones(8, 1); ...
        max(0.1, 0.5 * max(z1(22), z2(22)))];
    separation = norm(local ./ scale22);
    if ~(isfinite(separation) && separation > opts.MinimumSeedSeparation)
        error('ContinueDaughterBranch:CoincidentSeeds', ...
            'The two corrected seeds are not numerically distinct.');
    end

    ray = struct('checked', false, 'sameRay', NaN, ...
        'projection', [NaN NaN], 'orientation', NaN, ...
        'directionCosine', [NaN NaN], ...
        'scaledDistance', [NaN NaN], 'outwardOrdered', NaN, ...
        'criticalSolution', [], 'direction', []);
    if ~opts.RequireSameRay
        return
    end
    qCritical = ReducedState(opts.CriticalSolution(1:13));
    q1 = ReducedState(z1(1:13));
    q2 = ReducedState(z2(1:13));
    directionScaled = opts.Direction ./ opts.SectionScale;
    directionScaled = directionScaled / norm(directionScaled);
    p1 = dot((q1 - qCritical) ./ opts.SectionScale, directionScaled);
    p2 = dot((q2 - qCritical) ./ opts.SectionScale, directionScaled);
    displacement1 = (q1 - qCritical) ./ opts.SectionScale;
    displacement2 = (q2 - qCritical) ./ opts.SectionScale;
    cosine1 = abs(p1) / max(norm(displacement1), eps);
    cosine2 = abs(p2) / max(norm(displacement2), eps);
    outwardOrdered = abs(p2) > abs(p1) + opts.MinimumSeedSeparation;
    sameRay = isfinite(p1) && isfinite(p2) && p1 * p2 > 0 && ...
        min(abs([p1 p2])) >= opts.MinimumRayProjection && ...
        min([cosine1 cosine2]) >= opts.MinimumDirectionCosine && ...
        outwardOrdered;
    ray = struct('checked', true, 'sameRay', sameRay, ...
        'projection', [p1 p2], 'orientation', sign(p1 + p2), ...
        'directionCosine', [cosine1 cosine2], ...
        'scaledDistance', [norm(displacement1) norm(displacement2)], ...
        'outwardOrdered', outwardOrdered, ...
        'criticalSolution', opts.CriticalSolution, ...
        'direction', opts.Direction);
    if ~sameRay
        error('ContinueDaughterBranch:OppositeOrDegenerateRays', ...
            ['The seeds must be ordered inner-to-outer, have same-sign ' ...
             'nonzero projections, and each meet the configured direction ' ...
             'cosine on the selected outgoing ray.']);
    end
end

function geometry = ValidateOutputGeometry(results, ray, opts)
    pointCount = size(results, 2);
    geometry = struct('checked', false, 'accepted', false, ...
        'projection', NaN(1, pointCount), ...
        'scaledDistance', NaN(1, pointCount), ...
        'directionCosine', NaN(1, pointCount), ...
        'sameRayAlignedMask', false(1, pointCount), ...
        'sameRayAlignedCount', NaN, ...
        'sameRayAlignedDistinctCount', NaN, ...
        'maximumConsecutiveAlignedDistinctCount', NaN, ...
        'maximumConsecutiveAlignedRange', [NaN NaN], ...
        'minimumRequiredCount', opts.MinimumSameRayOutputPoints, ...
        'minimumDirectionCosine', opts.MinimumDirectionCosine, ...
        'orientation', ray.orientation);
    if ~ray.checked
        return
    end

    geometry.checked = true;
    qCritical = ReducedState(ray.criticalSolution(1:13));
    directionScaled = ray.direction ./ opts.SectionScale;
    directionScaled = directionScaled / norm(directionScaled);
    for k = 1:pointCount
        displacement = (ReducedState(results(1:13, k)) - qCritical) ./ ...
            opts.SectionScale;
        distance = norm(displacement);
        projection = dot(displacement, directionScaled);
        geometry.projection(k) = projection;
        geometry.scaledDistance(k) = distance;
        if distance > 0
            geometry.directionCosine(k) = abs(projection) / distance;
        end
    end
    geometry.sameRayAlignedMask = ...
        ray.orientation * geometry.projection >= opts.MinimumRayProjection & ...
        geometry.directionCosine >= opts.MinimumDirectionCosine;
    geometry.sameRayAlignedCount = nnz(geometry.sameRayAlignedMask);
    geometry.sameRayAlignedDistinctCount = CountDistinctSolutions( ...
        results(1:22, geometry.sameRayAlignedMask), opts);
    [geometry.maximumConsecutiveAlignedDistinctCount, ...
        geometry.maximumConsecutiveAlignedRange] = ...
        MaximumConsecutiveDistinctSolutions( ...
            results(1:22, :), geometry.sameRayAlignedMask, opts);
    geometry.accepted = ...
        geometry.maximumConsecutiveAlignedDistinctCount >= ...
        opts.MinimumSameRayOutputPoints;
end

function geometry = AddValidatedRunEvidence(geometry, solutions, ...
        outputAcceptedMask, opts)
    outputAcceptedMask = logical(outputAcceptedMask(:).');
    if geometry.checked
        combinedMask = geometry.sameRayAlignedMask & outputAcceptedMask;
    else
        combinedMask = false(size(outputAcceptedMask));
    end
    [count, range] = MaximumConsecutiveDistinctSolutions( ...
        solutions, combinedMask, opts);
    minimum = max(opts.MinimumOutputPoints, ...
        opts.MinimumSameRayOutputPoints);
    geometry.rawGeometryAccepted = geometry.accepted;
    geometry.validationAcceptedMask = outputAcceptedMask;
    geometry.sameRayValidatedAcceptedMask = combinedMask;
    geometry.sameRayValidatedAcceptedCount = nnz(combinedMask);
    geometry.maximumConsecutiveValidatedAlignedDistinctCount = count;
    geometry.maximumConsecutiveValidatedAlignedRange = range;
    geometry.minimumValidatedAlignedRunCount = minimum;
    geometry.accepted = geometry.checked && count >= minimum;
end

function [maximum, range] = MaximumConsecutiveDistinctSolutions( ...
        solutions, mask, opts)
    maximum = 0;
    range = [NaN NaN];
    first = 1;
    while first <= numel(mask)
        while first <= numel(mask) && ~mask(first)
            first = first + 1;
        end
        if first > numel(mask)
            break
        end
        last = first;
        while last < numel(mask) && mask(last + 1)
            last = last + 1;
        end
        count = CountDistinctSolutions(solutions(:, first:last), opts);
        if count > maximum
            maximum = count;
            range = [first last];
        end
        first = last + 1;
    end
end

function q = ReducedState(X)
    q = X([1 2 4:13]);
end

function difference = LocalStateDifference(candidate, reference)
    difference = candidate(:) - reference(:);
    period = reference(22);
    difference(14:21) = mod(difference(14:21) + 0.5 * period, period) - ...
        0.5 * period;
end

function count = CountDistinctSolutions(solutions, opts)
    count = 0;
    representatives = zeros(22, 0);
    for k = 1:size(solutions, 2)
        candidate = solutions(:, k);
        distinct = true;
        for j = 1:size(representatives, 2)
            difference = LocalStateDifference(candidate, ...
                representatives(:, j));
            eventScale = max(0.05, 0.25 * representatives(22, j));
            periodScale = max(0.1, 0.5 * representatives(22, j));
            scale = [opts.SectionScale(1:2); 1; ...
                opts.SectionScale(3:12); eventScale * ones(8, 1); ...
                periodScale];
            if norm(difference ./ scale) <= opts.MinimumSeedSeparation
                distinct = false;
                break
            end
        end
        if distinct
            representatives(:, end + 1) = candidate; %#ok<AGROW>
            count = count + 1;
        end
    end
end

function ValidateContinuationOutput(results, Para)
    if ~isnumeric(results) || ~isreal(results) || size(results, 1) ~= 29 || ...
            isempty(results) || any(~isfinite(results(1:22, :)), 'all')
        error('ContinueDaughterBranch:InvalidContinuationOutput', ...
            'The continuation function must return a real numeric 29-by-N branch.');
    end
    parameters = results(23:29, :);
    for k = 1:size(parameters, 2)
        candidate = parameters(:, k);
        finiteMatch = isfinite(candidate) & isfinite(Para) & ...
            abs(candidate - Para) <= 1e-12 * max(1, abs(Para));
        infiniteMatch = isinf(candidate) & isinf(Para) & ...
            sign(candidate) == sign(Para);
        if ~all(finiteMatch | infiniteMatch)
            error('ContinueDaughterBranch:ParameterDrift', ...
                'The continuation output changed the fixed parameter vector.');
        end
    end
end

function summary = EmptyValidation()
    summary = struct('accepted', false, 'evaluatorAccepted', false, ...
        'evaluated', false, 'status', 'not-run', ...
        'periodicResidualNormInf', NaN, 'timingResidualNormInf', NaN, ...
        'topologySignature', '', 'topologyEvidenceValid', false, ...
        'topologyConsistent', false, 'topologyMessage', ...
        'not evaluated', 'message', 'not evaluated');
end

function summary = SummarizeValidation(report)
    if ~isstruct(report) || ~isscalar(report) || ...
            ~isfield(report, 'accepted') || ...
            ~IsBooleanScalar(report.accepted)
        error('ContinueDaughterBranch:InvalidValidationReport', [ ...
            'ValidationFunction must return a scalar structure with an ' ...
            'accepted field equal to logical/finite 0 or 1.']);
    end
    summary = EmptyValidation();
    summary.evaluated = true;
    summary.evaluatorAccepted = logical(report.accepted);
    summary.accepted = summary.evaluatorAccepted;
    if isfield(report, 'status') && ...
            (ischar(report.status) || ...
             (isstring(report.status) && isscalar(report.status)))
        summary.status = char(string(report.status));
    else
        summary.status = Ternary(summary.accepted, 'accepted', 'rejected');
    end
    if isfield(report, 'periodicResidualNormInf')
        summary.periodicResidualNormInf = report.periodicResidualNormInf;
    end
    if isfield(report, 'mapInfo') && isfield(report.mapInfo, ...
            'timingResidualNormInf')
        summary.timingResidualNormInf = report.mapInfo.timingResidualNormInf;
    end
    if isfield(report, 'mapInfo') && isfield(report.mapInfo, ...
            'eventTopology') && isfield(report.mapInfo.eventTopology, 'signature')
        summary.topologySignature = report.mapInfo.eventTopology.signature;
    end
    if summary.accepted
        summary.message = 'accepted';
    elseif isfield(report, 'rejectionReasons') && ~isempty(report.rejectionReasons)
        summary.message = strjoin(report.rejectionReasons, ' | ');
    else
        summary.message = 'periodic-orbit validation rejected the point';
    end
end

function topology = ExtractEventTopology(report)
    topology = struct();
    if isstruct(report) && isscalar(report) && ...
            isfield(report, 'mapInfo') && ...
            isstruct(report.mapInfo) && isscalar(report.mapInfo) && ...
            isfield(report.mapInfo, 'eventTopology')
        topology = report.mapInfo.eventTopology;
    end
end

function summary = ApplyTopologyEvidence(summary, topology, reference, ...
        requireTopology, validationOptions, isReference)
    if ~requireTopology
        summary.topologyMessage = ...
            'Independent topology comparison disabled.';
        return
    end
    summary.topologyEvidenceValid = ValidEventTopology(topology);
    if ~summary.evaluatorAccepted
        summary.topologyMessage = ...
            'Evaluator rejected the point; topology is not acceptance evidence.';
        return
    end
    if ~summary.topologyEvidenceValid
        summary.accepted = false;
        summary.status = 'rejected-missing-topology-evidence';
        summary.topologyMessage = ...
            'Accepted evaluator report omitted a valid event topology.';
        summary.message = summary.topologyMessage;
        return
    end
    summary.topologySignature = char(string(topology.signature));
    if isReference
        summary.topologyConsistent = true;
        summary.topologyMessage = 'First-seed reference topology accepted.';
        return
    end
    if ~ValidEventTopology(reference)
        summary.accepted = false;
        summary.status = 'rejected-missing-reference-topology';
        summary.topologyMessage = ...
            'No valid first-seed reference topology is available.';
        summary.message = summary.topologyMessage;
        return
    end
    comparison = floquet.internal.events.compareTopology( ...
        reference, topology, validationOptions);
    summary.topologyConsistent = comparison.valid && comparison.consistent;
    if summary.topologyConsistent
        summary.topologyMessage = ...
            'Topology independently matches the first-seed reference.';
    else
        summary.accepted = false;
        summary.status = 'rejected-topology-change';
        if isfield(comparison, 'rejectionReasons') && ...
                ~isempty(comparison.rejectionReasons)
            summary.topologyMessage = strjoin( ...
                comparison.rejectionReasons, ' | ');
        else
            summary.topologyMessage = ...
                'Event topology differs from the first-seed reference.';
        end
        summary.message = summary.topologyMessage;
    end
end

function values = LogicalSummaryField(summaries, field)
    values = false(1, numel(summaries));
    for k = 1:numel(summaries)
        if isfield(summaries(k), field) && ...
                IsBooleanScalar(summaries(k).(field))
            values(k) = logical(summaries(k).(field));
        end
    end
end

function complete = AcceptedTopologyEvidenceComplete(summaries, ...
        validatedMask, requireTopology)
    if ~requireTopology
        complete = false;
        return
    end
    evaluatedAccepted = validatedMask & ...
        LogicalSummaryField(summaries, 'evaluatorAccepted');
    complete = all(LogicalSummaryField( ...
        summaries(evaluatedAccepted), 'topologyEvidenceValid')) && ...
        all(LogicalSummaryField( ...
        summaries(evaluatedAccepted), 'topologyConsistent'));
end

function authority = BuildValidationAuthority(opts, productionEvaluator, ...
        independentTopologyChecked, evaluatorIdentity)
    authority = struct();
    authority.evaluator = func2str(opts.ValidationFunction);
    authority.productionEvaluator = productionEvaluator;
    authority.evaluatorIdentity = evaluatorIdentity;
    authority.customEvaluator = ~productionEvaluator;
    authority.nonProductionExplicitlyAllowed = ...
        opts.AllowNonProductionValidationFunction;
    authority.independentTopologyChecked = independentTopologyChecked;
    authority.scientificAcceptanceEligible = productionEvaluator && ...
        independentTopologyChecked;
    if productionEvaluator && independentTopologyChecked
        authority.classification = ...
            'production-validator-with-independent-topology-check';
    elseif productionEvaluator
        authority.classification = ...
            'production-validator-without-complete-topology-evidence';
    elseif independentTopologyChecked
        authority.classification = ...
            ['custom-validator-with-independent-topology-check-' ...
             'nonauthoritative'];
    elseif opts.AllowNonProductionValidationFunction
        authority.classification = ...
            'explicit-nonproduction-custom-validator';
    else
        authority.classification = 'unverified-custom-validator';
    end
end

function valid = IsBooleanScalar(value)
    valid = isscalar(value) && ...
        (islogical(value) || (isnumeric(value) && isreal(value) && ...
        isfinite(value) && any(value == [0 1])));
end

function valid = ValidEventTopology(topology)
    valid = false;
    required = {'valid','sortedEventNumbers','clusters', ...
        'normalizedPhases','signature'};
    if ~isstruct(topology) || ~isscalar(topology) || ...
            ~all(isfield(topology, required)) || ...
            ~IsTrueLogical(topology.valid)
        return
    end
    order = topology.sortedEventNumbers(:);
    phases = topology.normalizedPhases(:);
    if ~isnumeric(order) || ~isreal(order) || numel(order) ~= 9 || ...
            any(~isfinite(order)) || ...
            ~isequal(sort(order), (1:9).') || ...
            ~isnumeric(phases) || ~isreal(phases) || ...
            numel(phases) ~= 9 || any(~isfinite(phases)) || ...
            ~iscell(topology.clusters) || isempty(topology.clusters) || ...
            ~(ischar(topology.signature) || ...
              (isstring(topology.signature) && isscalar(topology.signature)))
        return
    end
    members = zeros(0, 1);
    for k = 1:numel(topology.clusters)
        cluster = topology.clusters{k};
        if ~isnumeric(cluster) || ~isreal(cluster) || isempty(cluster) || ...
                any(~isfinite(cluster(:))) || ...
                any(cluster(:) ~= floor(cluster(:))) || ...
                any(cluster(:) < 1 | cluster(:) > 9)
            return
        end
        members = [members; cluster(:)]; %#ok<AGROW>
    end
    valid = isequal(sort(members), (1:9).');
end

function tf = IsTrueLogical(value)
    tf = isscalar(value) && ...
        (islogical(value) || (isnumeric(value) && isreal(value) && ...
        isfinite(value) && any(value == [0 1]))) && logical(value);
end

function [names, abbreviations] = ClassifyGaits(solution)
    count = size(solution, 2);
    names = repmat({''}, 1, count);
    abbreviations = repmat({''}, 1, count);
    if ~exist('Gait_Identification', 'file')
        return
    end
    for k = 1:count
        try
            [name, abbreviation] = Gait_Identification(solution(:, k));
            names{k} = char(string(name));
            abbreviations{k} = char(string(abbreviation));
        catch
            names{k} = 'unclassified';
            abbreviations{k} = '';
        end
    end
end

function message = BuildMessage(enoughPoints, validationAccepted, ...
        geometryAccepted, geometry, count, distinctCount, minimum, ...
        validationEvidenceComplete)
    if ~validationEvidenceComplete
        message = [ ...
            'Complete validation authority was not established. Scientific ' ...
            'acceptance requires both seeds and every stored output point ' ...
            'to be independently evaluated, plus valid topology evidence ' ...
            'for every evaluator-accepted point. Stride-sampled or ' ...
            'nonproduction-only output remains diagnostic.'];
    elseif ~enoughPoints
        message = sprintf([ ...
            'Continuation returned %d stored points but only %d distinct ' ...
            'points; at least %d distinct points are required.'], ...
            count, distinctCount, minimum);
    elseif ~validationAccepted
        message = 'At least one independently revalidated daughter point failed.';
    elseif ~geometryAccepted
        message = sprintf([ ...
            'Only %d consecutive distinct, independently validated points ' ...
            'remain on the seeded ray with direction cosine >= %.3g; at ' ...
            'least %d are required.'], ...
            geometry.maximumConsecutiveValidatedAlignedDistinctCount, ...
            geometry.minimumDirectionCosine, ...
            geometry.minimumValidatedAlignedRunCount);
    else
        message = sprintf(['Accepted %d-point continued branch candidate. ' ...
            'Gait labels are post-correction classifications, not acceptance ' ...
            'targets; independent daughter validation remains required.'], count);
    end
end

function SaveOutput(filename, results, info, overwrite)
    filename = char(string(filename));
    if isfile(filename) && ~overwrite
        error('ContinueDaughterBranch:OutputExists', ...
            'Output file already exists: %s', filename);
    end
    folder = fileparts(filename);
    if ~isempty(folder) && ~isfolder(folder)
        mkdir(folder);
    end
    temporary = [tempname(Ternary(isempty(folder), pwd, folder)), '.mat'];
    cleanup = onCleanup(@() DeleteIfPresent(temporary));
    save(temporary, 'results', 'info', '-v7.3');
    if overwrite
        [ok, message] = movefile(temporary, filename, 'f');
    else
        [ok, message] = movefile(temporary, filename);
    end
    if ~ok
        error('ContinueDaughterBranch:SaveFailed', '%s', message);
    end
    clear cleanup
end

function options = SerializableOptions(options)
    options.ContinuationFunction = func2str(options.ContinuationFunction);
    options.ValidationFunction = func2str(options.ValidationFunction);
    if isfield(options.RunOptions, 'Callbacks')
        options.RunOptions.Callbacks = '<runtime callbacks omitted>';
    end
end

function value = ValidateLogical(value, name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
        error('ContinueDaughterBranch:LogicalOption', ...
            '%s must be scalar logical.', name);
    end
    value = logical(value);
end

function DeleteIfPresent(filename)
    if isfile(filename)
        delete(filename);
    end
end

function filename = CanonicalFile(filename)
    file = java.io.File(filename);
    filename = char(file.getCanonicalPath());
end

function value = Ternary(condition, yes, no)
    if condition
        value = yes;
    else
        value = no;
    end
end

function value = Timestamp()
    value = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end
