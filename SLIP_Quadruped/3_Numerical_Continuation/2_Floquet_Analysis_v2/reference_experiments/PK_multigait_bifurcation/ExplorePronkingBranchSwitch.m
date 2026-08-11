function exploration = ExplorePronkingBranchSwitch(refinement, directions, options)
%EXPLOREPRONKINGBRANCHSWITCH Search the critical space for daughter branches.
%
%   EXPLORATION = EXPLOREPRONKINGBRANCHSWITCH(REFINEMENT,DIRECTIONS,OPTIONS)
%   performs a deterministic, validation-independent multistart search in
%   the three-dimensional additional +1 space.  Every reduced state seed is
%   lifted through the production event-timing solver using the selected
%   one-sided hybrid sector, then corrected with the canonical periodic
%   residual.  The default symmetry-amplitude corrector fixes the relevant
%   b/f/h critical coordinate and imposes only the isotropy conditions of
%   the requested daughter class outside the dynamics core.  The legacy
%   fixed-radius corrector remains available for comparison.  No saved
%   daughter branch is used.
%
%   This is an exploratory multiplicity-aware wrapper around the existing
%   radius corrector.  It records every failure and declares six-arm
%   discovery only when six oriented clusters (two B, two F, two H) persist
%   over multiple radii.  A negative result does not invalidate the linear
%   Floquet critical-space calculation.

    if nargin < 3 || isempty(options)
        options = struct();
    end
    opts = ParseOptions(options);
    [X,E,parameters,tangent,topology] = ResolveRefinement(refinement);
    [criticalBasis,stateScale,eigenData] = ResolveDirections(directions,tangent);
    coefficientSeeds = BuildCoefficientSeeds(opts);
    attemptCount = numel(opts.Radii) * size(coefficientSeeds,2);
    attempts = repmat(EmptyAttempt(),1,attemptCount);
    attemptIndex = 0;

    if opts.Verbose
        fprintf(['Pronking branch-switch search: %d directions x %d radii ' ...
            '= %d attempts\n'],size(coefficientSeeds,2),numel(opts.Radii), ...
            attemptCount);
    end

    for radiusIndex = 1:numel(opts.Radii)
        radius = opts.Radii(radiusIndex);
        for seedIndex = 1:size(coefficientSeeds,2)
            attemptIndex = attemptIndex + 1;
            coefficients = coefficientSeeds(:,seedIndex);
            attempt = EmptyAttempt();
            attempt.index = attemptIndex;
            attempt.radiusIndex = radiusIndex;
            attempt.seedIndex = seedIndex;
            attempt.radius = radius;
            attempt.seedCoefficients = coefficients;
            attempt.seedLabel = SeedLabel(coefficients);
            attempt.targetGaitClass = SeedGaitClass( ...
                coefficients,opts.ClassCoordinateTolerance);
            attempt.requestedGaitClass = attempt.targetGaitClass;
            attempt.classSelectionMethod = 'critical-coordinate-support';

            mode = criticalBasis * coefficients;
            selectedEigenData = eigenData;
            selectedEigenData.eigenvector = mode;
            selectedEigenData.Eigenvector = mode;
            try
                predictorOptions = PredictorOptions(opts, stateScale, ...
                    topology, radius);
                [deltaZ,zPredictor,predictorInfo] = ...
                    floquet.predictBranchDirection(X,E,parameters, ...
                        selectedEigenData,predictorOptions);
                attempt.predictorAccepted = true;
                attempt.deltaZ = deltaZ;
                attempt.zPredictor = zPredictor;
                attempt.predictorInfo = predictorInfo;
                attempt.sectorSignature = TopologySignature( ...
                    predictorInfo.sectorTopology);
            catch predictorError
                attempt.predictorAccepted = false;
                attempt.rejectionStage = 'predictor';
                attempt.rejectionIdentifier = predictorError.identifier;
                attempt.rejectionMessage = predictorError.message;
                attempts(attemptIndex) = attempt;
                PrintAttempt(attempt,opts);
                continue
            end

            try
                useGaitCorrector = strcmp(opts.CorrectorMode, ...
                    'symmetry-amplitude') && any(strcmp( ...
                    attempt.targetGaitClass,{'B','F','H'}));
                if useGaitCorrector
                    correctorOptions = GaitCorrectorOptions(opts, ...
                        predictorInfo.sectorTopology);
                    [zCorrected,correctorInfo] = ...
                        CorrectPronkingGaitBranch(X,E,parameters, ...
                            predictorInfo,directions, ...
                            attempt.targetGaitClass,correctorOptions);
                    canonicalField = 'canonicalResidualNormInf';
                    mapValidation = FieldOr(correctorInfo, ...
                        'periodicValidation',struct());
                    attempt.correctorMethod = ...
                        'pronking-symmetry-amplitude-corrector';
                else
                    correctorOptions = CorrectorOptions(opts,E,stateScale, ...
                        predictorInfo.sectorTopology);
                    [zCorrected,correctorInfo] = ...
                        floquet.correctBranchSwitch( ...
                        X,E,parameters,predictorInfo,correctorOptions);
                    canonicalField = 'canonicalResidualNorm';
                    mapValidation = FieldOr(correctorInfo, ...
                        'mapValidation',struct());
                    attempt.correctorMethod = 'generic-radius-corrector';
                end
                attempt.correctorAccepted = correctorInfo.accepted;
                attempt.zCorrected = zCorrected;
                attempt.correctorInfo = correctorInfo;
                attempt.canonicalResidualNorm = FieldOr( ...
                    correctorInfo,canonicalField,Inf);
                attempt.returnResidualNorm = FieldOr(correctorInfo, ...
                    'returnResidualNorm',FieldOr(mapValidation, ...
                    'returnResidualNorm',FieldOr(mapValidation, ...
                    'reducedPeriodicResidualNormInf',Inf)));
                attempt.eventTimeError = FieldOr(correctorInfo, ...
                    'eventTimeError',FieldOr(mapValidation, ...
                    'eventTimeError',Inf));
                if correctorInfo.accepted
                    attempt = CharacterizeCorrection(attempt,X,tangent, ...
                        criticalBasis,stateScale,opts);
                else
                    attempt.rejectionStage = 'corrector-validation';
                    attempt.rejectionIdentifier = ...
                        'CorrectBranchSwitch:CorrectionRejected';
                    attempt.rejectionMessage = correctorInfo.message;
                end
            catch correctorError
                attempt.correctorAccepted = false;
                attempt.rejectionStage = 'corrector';
                attempt.rejectionIdentifier = correctorError.identifier;
                attempt.rejectionMessage = correctorError.message;
            end
            attempts(attemptIndex) = attempt;
            PrintAttempt(attempt,opts);
        end
    end

    [clusters,clusterDiagnostics] = ClusterAttempts(attempts,opts);
    isPersistent = [clusters.persistent];
    persistentClusters = clusters(isPersistent);
    persistentClasses = {persistentClusters.gaitClass};
    classCounts = [nnz(strcmp(persistentClasses,'B')), ...
        nnz(strcmp(persistentClasses,'F')), ...
        nnz(strcmp(persistentClasses,'H'))];
    sixArmVerified = numel(persistentClusters) == 6 && ...
        isequal(classCounts,[2 2 2]);

    exploration = struct();
    exploration.version = 'pronking-sector-search-v2';
    exploration.generatedAt = char(datetime('now', ...
        'Format','yyyyMMdd''T''HHmmss'));
    exploration.status = SearchStatus(sixArmVerified,attempts);
    exploration.options = opts;
    exploration.correctorMode = opts.CorrectorMode;
    exploration.coefficientSeeds = coefficientSeeds;
    exploration.attempts = attempts;
    exploration.clusters = clusters;
    exploration.clusterDiagnostics = clusterDiagnostics;
    exploration.attemptCount = numel(attempts);
    exploration.predictorAcceptedCount = nnz([attempts.predictorAccepted]);
    exploration.correctorAcceptedCount = nnz([attempts.correctorAccepted]);
    exploration.nonParentAcceptedCount = nnz([attempts.nonParentAccepted]);
    exploration.persistentClusterCount = numel(persistentClusters);
    exploration.persistentClassCounts = classCounts;
    exploration.sixArmSearchValidated = sixArmVerified;
    exploration.blindSixArmDiscoveryValidated = sixArmVerified && ...
        isempty(opts.CoefficientSeeds);
    if sixArmVerified
        exploration.message = ...
            'Six persistent oriented rays were recovered: two B, two F, and two H.';
    else
        exploration.message = sprintf([ ...
            'Blind search did not certify six persistent rays ' ...
            '(persistent=%d, class counts=[%d %d %d]).'], ...
            numel(persistentClusters),classCounts);
    end

    if opts.ThrowOnFailure && ~sixArmVerified
        error('ExplorePronkingBranchSwitch:SixArmSearchIncomplete', ...
            '%s',exploration.message);
    end
end

function opts = ParseOptions(options)
    if ~isstruct(options) || ~isscalar(options)
        error('ExplorePronkingBranchSwitch:InvalidOptions', ...
            'options must be a scalar structure.');
    end
    defaults = struct();
    defaults.Radii = [1e-2 5e-3];
    % Two signs, 30 degrees away from -b, seed the two orientations in
    % each exact b-f and b-h invariant plane. Together with +/-b this is a
    % deterministic six-direction grid; it uses no daughter branch data.
    defaults.PlaneAnglesDegrees = [-150 150];
    defaults.CoefficientSeeds = [];
    defaults.SeedProvenance = '';
    defaults.CorrectorMode = 'symmetry-amplitude';
    defaults.ClassCoordinateTolerance = 1e-10;
    defaults.IncludeFibonacciSphere = false;
    defaults.FibonacciPointCount = 24;
    defaults.FloquetOptions = struct('TopologyMode','clustered', ...
        'ErrorOnFailure',true);
    defaults.TimingProbeFactor = 1;
    defaults.FsolveOptions = optimset( ...
        'Algorithm','levenberg-marquardt','Display','off', ...
        'TolFun',1e-10,'TolX',1e-10,'MaxIter',400,'MaxFunEvals',6000);
    defaults.CanonicalResidualTolerance = 1e-8;
    defaults.ReturnMapTolerance = 1e-7;
    defaults.EventTimeTolerance = 1e-6;
    defaults.ConstraintTolerance = 1e-7;
    defaults.PairSymmetryTolerance = 1e-6;
    defaults.BrokenSymmetryTolerance = 1e-4;
    defaults.MinimumTransverseFraction = 0.2;
    defaults.ClusterCosineThreshold = 0.985;
    defaults.MinimumPersistentRadii = 2;
    defaults.MinimumDirectionNorm = 1e-10;
    defaults.Verbose = true;
    defaults.ThrowOnFailure = false;

    opts = defaults;
    supplied = fieldnames(options);
    allowed = fieldnames(defaults);
    for k = 1:numel(supplied)
        hit = find(strcmpi(supplied{k},allowed),1);
        if isempty(hit)
            error('ExplorePronkingBranchSwitch:UnknownOption', ...
                'Unknown option ''%s''.', supplied{k});
        end
        opts.(allowed{hit}) = options.(supplied{k});
    end
    logicalFields = {'IncludeFibonacciSphere','Verbose','ThrowOnFailure'};
    for k = 1:numel(logicalFields)
        value = opts.(logicalFields{k});
        if ~(isscalar(value) && (islogical(value) || ...
                (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
            error('ExplorePronkingBranchSwitch:InvalidLogical', ...
                '%s must be a scalar logical.',logicalFields{k});
        end
        opts.(logicalFields{k}) = logical(value);
    end
    opts.Radii = unique(opts.Radii(:).','stable');
    if isempty(opts.Radii) || any(~isfinite(opts.Radii)) || any(opts.Radii <= 0)
        error('ExplorePronkingBranchSwitch:InvalidRadii', ...
            'Radii must contain positive finite values.');
    end
    if any(~isfinite(opts.PlaneAnglesDegrees(:)))
        error('ExplorePronkingBranchSwitch:InvalidAngles', ...
            'PlaneAnglesDegrees must be finite.');
    end
    if ~isempty(opts.CoefficientSeeds) && ...
            (~isnumeric(opts.CoefficientSeeds) || ...
             size(opts.CoefficientSeeds,1) ~= 3 || ...
             any(~isfinite(opts.CoefficientSeeds(:))) || ...
             any(vecnorm(opts.CoefficientSeeds,2,1) <= 0))
        error('ExplorePronkingBranchSwitch:InvalidCoefficientSeeds', ...
            'CoefficientSeeds must be empty or a finite nonzero 3-by-N matrix.');
    end
    opts.SeedProvenance = char(string(opts.SeedProvenance));
    opts.CorrectorMode = lower(char(string(opts.CorrectorMode)));
    if ~any(strcmp(opts.CorrectorMode,{'symmetry-amplitude','radius'}))
        error('ExplorePronkingBranchSwitch:InvalidCorrectorMode', ...
            'CorrectorMode must be symmetry-amplitude or radius.');
    end
    if isempty(opts.SeedProvenance)
        if isempty(opts.CoefficientSeeds)
            opts.SeedProvenance = 'deterministic-symmetry-grid';
        else
            opts.SeedProvenance = 'user-supplied';
        end
    end
    positiveFields = {'TimingProbeFactor','CanonicalResidualTolerance', ...
        'ReturnMapTolerance','EventTimeTolerance','ConstraintTolerance', ...
        'PairSymmetryTolerance','BrokenSymmetryTolerance', ...
        'MinimumTransverseFraction','ClusterCosineThreshold', ...
        'MinimumDirectionNorm','ClassCoordinateTolerance'};
    for k = 1:numel(positiveFields)
        value = opts.(positiveFields{k});
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value > 0)
            error('ExplorePronkingBranchSwitch:InvalidTolerance', ...
                '%s must be a positive finite scalar.',positiveFields{k});
        end
    end
    if opts.MinimumTransverseFraction >= 1 || opts.ClusterCosineThreshold >= 1
        error('ExplorePronkingBranchSwitch:InvalidUnitTolerance', ...
            'MinimumTransverseFraction and ClusterCosineThreshold must be below one.');
    end
    if opts.BrokenSymmetryTolerance <= opts.PairSymmetryTolerance
        error('ExplorePronkingBranchSwitch:InvalidClassificationBand', ...
            ['BrokenSymmetryTolerance must exceed ' ...
             'PairSymmetryTolerance.']);
    end
    if ~(isscalar(opts.MinimumPersistentRadii) && ...
            opts.MinimumPersistentRadii >= 1 && ...
            opts.MinimumPersistentRadii == floor(opts.MinimumPersistentRadii))
        error('ExplorePronkingBranchSwitch:InvalidPersistence', ...
            'MinimumPersistentRadii must be a positive integer.');
    end
    if ~(isscalar(opts.FibonacciPointCount) && opts.FibonacciPointCount >= 4 && ...
            opts.FibonacciPointCount == floor(opts.FibonacciPointCount))
        error('ExplorePronkingBranchSwitch:InvalidFibonacciCount', ...
            'FibonacciPointCount must be an integer of at least four.');
    end
end

function [X,E,parameters,tangent,topology] = ResolveRefinement(refinement)
    if ~isstruct(refinement) || ~isscalar(refinement) || ...
            ~LogicalField(refinement,'accepted',false)
        error('ExplorePronkingBranchSwitch:InvalidRefinement', ...
            'An accepted scalar RefineCriticalOrbit diagnostics structure is required.');
    end
    X = FieldOr(refinement,'X',[]);
    E = FieldOr(refinement,'E',[]);
    parameters = FieldOr(refinement,'parameters',[]);
    tangent = FieldOr(refinement,'localBranchTangent',[]);
    topology = FieldOr(refinement,'topology',[]);
    X = X(:); E = E(:); parameters = parameters(:); tangent = tangent(:);
    if numel(X) ~= 13 || numel(E) ~= 9 || numel(parameters) ~= 7 || ...
            numel(tangent) ~= 12 || any(~isfinite(X)) || any(~isfinite(E)) || ...
            any(~isfinite(parameters) & ~isinf(parameters)) || ...
            any(~isfinite(tangent)) || ~isstruct(topology)
        error('ExplorePronkingBranchSwitch:IncompleteRefinement', ...
            'Refinement lacks a valid state, timing, parameter, tangent, or topology.');
    end
end

function [basis,stateScale,eigenData] = ResolveDirections(directions,tangent)
    if ~isstruct(directions) || ~isscalar(directions)
        error('ExplorePronkingBranchSwitch:InvalidDirections', ...
            'directions must be a scalar symmetry-resolution structure.');
    end
    basis = FieldOr(directions,'Matrix',[]);
    stateScale = FieldOr(directions,'StateScale',[]);
    stateScale = stateScale(:);
    if ~isequal(size(basis),[12 3]) || any(~isfinite(basis(:))) || ...
            numel(stateScale) ~= 12 || any(~isfinite(stateScale)) || ...
            any(stateScale <= 0)
        error('ExplorePronkingBranchSwitch:DirectionShape', ...
            'directions.Matrix and StateScale must be 12-by-3 and 12-by-1.');
    end
    scaled = basis ./ stateScale;
    for k = 1:3
        scaledNorm = norm(scaled(:,k));
        if scaledNorm <= eps
            error('ExplorePronkingBranchSwitch:DegenerateDirection', ...
                'A symmetry-resolved direction is degenerate.');
        end
        basis(:,k) = basis(:,k) / scaledNorm;
    end
    eigenData = struct('eigenvector',basis(:,1), ...
        'Eigenvector',basis(:,1),'multiplier',1,'Multiplier',1, ...
        'Type','+1','type','+1', ...
        'IsAdditionalNullDirection',true, ...
        'IsTrivialBranchTangent',false, ...
        'NullDirectionClassification','additional-null-direction', ...
        'BranchTangent',tangent(:));
end

function seeds = BuildCoefficientSeeds(opts)
    if ~isempty(opts.CoefficientSeeds)
        seeds = opts.CoefficientSeeds;
        for k = 1:size(seeds,2)
            seeds(:,k) = seeds(:,k) / norm(seeds(:,k));
        end
        rounded = round(seeds.' * 1e12) / 1e12;
        [~,uniqueRows] = unique(rounded,'rows','stable');
        seeds = seeds(:,sort(uniqueRows));
        return
    end
    seeds = [1 -1;0 0;0 0];
    angles = opts.PlaneAnglesDegrees(:).';
    for angle = angles
        radians = deg2rad(angle);
        seeds(:,end+1) = [cos(radians);sin(radians);0]; %#ok<AGROW>
        seeds(:,end+1) = [cos(radians);0;sin(radians)]; %#ok<AGROW>
    end
    if opts.IncludeFibonacciSphere
        count = opts.FibonacciPointCount;
        golden = pi * (3 - sqrt(5));
        for k = 0:count-1
            z = 1 - 2*(k+0.5)/count;
            radial = sqrt(max(0,1-z*z));
            azimuth = golden*k;
            seeds(:,end+1) = ...
                [radial*cos(azimuth);radial*sin(azimuth);z]; %#ok<AGROW>
        end
    end
    for k = 1:size(seeds,2)
        seeds(:,k) = seeds(:,k) / norm(seeds(:,k));
    end
    rounded = round(seeds.' * 1e12) / 1e12;
    [~,uniqueRows] = unique(rounded,'rows','stable');
    seeds = seeds(:,sort(uniqueRows));
end

function options = PredictorOptions(opts,stateScale,topology,radius)
    mapOptions = opts.FloquetOptions;
    mapOptions.TopologyMode = 'clustered';
    mapOptions.ReferenceTopology = topology;
    mapOptions.ErrorOnFailure = true;
    options = struct( ...
        'Amplitude',radius, ...
        'StateScale',stateScale, ...
        'TimingProbeFactor',opts.TimingProbeFactor, ...
        'TimingLiftMode','one-sided-sector', ...
        'MapOptions',mapOptions, ...
        'ExpectedTopology',topology, ...
        'Multiplier',1, ...
        'RequirePlusOne',true, ...
        'RequireAdditionalNullDirection',true);
end

function options = CorrectorOptions(opts,E,stateScale,sectorTopology)
    mapOptions = opts.FloquetOptions;
    % The predictor's already-split sector is the reference. Clustered mode
    % permits harmless permutations inside a still-simultaneous left/right
    % pair, while forbidding the separated sector clusters from merging,
    % crossing, or interleaving. This rejects return to pronking without
    % assigning significance to roundoff-level ordering inside a pair.
    mapOptions.TopologyMode = 'clustered';
    mapOptions.ReferenceTopology = sectorTopology;
    mapOptions.ErrorOnFailure = false;
    scale22 = FullStateScale(E,stateScale);
    options = struct( ...
        'Constraints',{{}}, ...
        'ConstraintMode','radius', ...
        'FsolveOptions',opts.FsolveOptions, ...
        'StateScale',scale22, ...
        'ResidualTolerance',opts.CanonicalResidualTolerance, ...
        'ConstraintTolerance',opts.ConstraintTolerance, ...
        'ReturnMapTolerance',opts.ReturnMapTolerance, ...
        'EventTimeTolerance',opts.EventTimeTolerance, ...
        'ValidateWithPoincareMap',true, ...
        'MapOptions',mapOptions, ...
        'ExpectedTopology',sectorTopology, ...
        'ThrowOnFailure',false);
end

function options = GaitCorrectorOptions(opts,sectorTopology)
    mapOptions = opts.FloquetOptions;
    mapOptions.TopologyMode = 'clustered';
    mapOptions.ReferenceTopology = sectorTopology;
    mapOptions.ErrorOnFailure = false;
    options = struct( ...
        'FsolveOptions',opts.FsolveOptions, ...
        'MapOptions',mapOptions, ...
        'ExpectedTopology',sectorTopology, ...
        'ResidualTolerance',opts.CanonicalResidualTolerance, ...
        'SymmetryTolerance',opts.ConstraintTolerance, ...
        'AmplitudeTolerance',opts.ConstraintTolerance, ...
        'ReturnMapTolerance',opts.ReturnMapTolerance, ...
        'EventTimeTolerance',opts.EventTimeTolerance, ...
        'PairSymmetryTolerance',opts.PairSymmetryTolerance, ...
        'BrokenSymmetryTolerance',opts.BrokenSymmetryTolerance, ...
        'ThrowOnFailure',false);
end

function scale = FullStateScale(E,stateScale)
    scale = ones(22,1);
    scale([1 2 4:13]) = stateScale;
    scale(3) = 1;
    T = E(9);
    scale(14:21) = max(0.05,0.25*T);
    scale(22) = max(0.1,0.5*T);
end

function attempt = CharacterizeCorrection(attempt,X,tangent, ...
        criticalBasis,stateScale,opts)
    corrected = attempt.zCorrected(:);
    qIndex = [1 2 4:13];
    deltaQScaled = (corrected(qIndex) - X(qIndex)) ./ stateScale;
    tangentScaled = tangent(:) ./ stateScale;
    tangentScaled = tangentScaled / norm(tangentScaled);
    transverse = deltaQScaled - tangentScaled * ...
        (tangentScaled' * deltaQScaled);
    transverseNorm = norm(transverse);
    totalNorm = norm(deltaQScaled);
    attempt.transverseFraction = transverseNorm / max(totalNorm,eps);
    basisScaled = criticalBasis ./ stateScale;
    for k = 1:3
        basisScaled(:,k) = basisScaled(:,k) / norm(basisScaled(:,k));
    end
    if transverseNorm > opts.MinimumDirectionNorm
        normalized = transverse / transverseNorm;
        coefficients = basisScaled' * normalized;
        coefficientNorm = norm(coefficients);
        if coefficientNorm > opts.MinimumDirectionNorm
            coefficients = coefficients / coefficientNorm;
        end
        attempt.correctedCoefficients = coefficients;
        attempt.transverseCriticalAlignment = coefficientNorm;
    else
        attempt.correctedCoefficients = [NaN;NaN;NaN];
        attempt.transverseCriticalAlignment = 0;
    end
    [hindError,frontError,foreHindSeparation] = ...
        TimingDefects(corrected(14:22));
    attempt.hindPairPhaseError = hindError;
    attempt.frontPairPhaseError = frontError;
    attempt.foreHindPhaseSeparation = foreHindSeparation;
    attempt.gaitClass = ClassifyGait(hindError,frontError, ...
        foreHindSeparation,opts);
    [gait,abbreviation] = Gait_Identification(corrected);
    attempt.gait = char(string(gait));
    attempt.abbreviation = char(string(abbreviation));
    attempt.nonParentAccepted = attempt.correctorAccepted && ...
        attempt.transverseFraction >= opts.MinimumTransverseFraction && ...
        any(strcmp(attempt.gaitClass,{'B','F','H'}));
    if ~attempt.nonParentAccepted
        attempt.rejectionStage = 'non-parent-filter';
        attempt.rejectionIdentifier = ...
            'ExplorePronkingBranchSwitch:ParentOrUnclassified';
        attempt.rejectionMessage = sprintf( ...
            'transverse fraction %.3f, gait class %s.', ...
            attempt.transverseFraction,attempt.gaitClass);
    end
end

function [clusters,diagnostics] = ClusterAttempts(attempts,opts)
    acceptedIndices = find([attempts.nonParentAccepted]);
    clusters = repmat(EmptyCluster(),1,0);
    for index = acceptedIndices
        direction = attempts(index).correctedCoefficients(:);
        gaitClass = attempts(index).gaitClass;
        best = 0;
        bestCosine = -Inf;
        for k = 1:numel(clusters)
            if ~strcmp(clusters(k).gaitClass,gaitClass)
                continue
            end
            cosine = dot(direction,clusters(k).meanDirection);
            if cosine >= opts.ClusterCosineThreshold && cosine > bestCosine
                best = k;
                bestCosine = cosine;
            end
        end
        if best == 0
            cluster = EmptyCluster();
            cluster.id = numel(clusters)+1;
            cluster.gaitClass = gaitClass;
            cluster.attemptIndices = index;
            cluster.meanDirection = direction / norm(direction);
            clusters(end+1) = cluster; %#ok<AGROW>
        else
            clusters(best).attemptIndices(end+1) = index;
            allDirections = [attempts(clusters(best).attemptIndices).correctedCoefficients];
            meanDirection = mean(allDirections,2);
            clusters(best).meanDirection = meanDirection / norm(meanDirection);
        end
    end
    for k = 1:numel(clusters)
        indices = clusters(k).attemptIndices;
        clusters(k).radii = unique([attempts(indices).radius]);
        clusters(k).persistent = ...
            numel(clusters(k).radii) >= opts.MinimumPersistentRadii;
        clusters(k).maximumCanonicalResidual = ...
            max([attempts(indices).canonicalResidualNorm]);
        clusters(k).maximumReturnResidual = ...
            max([attempts(indices).returnResidualNorm]);
    end
    diagnostics = struct();
    diagnostics.acceptedAttemptIndices = acceptedIndices;
    diagnostics.clusterCount = numel(clusters);
    diagnostics.persistentClusterCount = nnz([clusters.persistent]);
    diagnostics.cosineThreshold = opts.ClusterCosineThreshold;
    diagnostics.minimumPersistentRadii = opts.MinimumPersistentRadii;
end

function attempt = EmptyAttempt()
    attempt = struct('index',NaN,'radiusIndex',NaN,'seedIndex',NaN, ...
        'radius',NaN,'seedCoefficients',[],'seedLabel','', ...
        'targetGaitClass','ambiguous','requestedGaitClass','ambiguous', ...
        'classSelectionMethod','','correctorMethod','', ...
        'predictorAccepted',false,'correctorAccepted',false, ...
        'nonParentAccepted',false,'deltaZ',[],'zPredictor',[], ...
        'predictorInfo',struct(),'zCorrected',[],'correctorInfo',struct(), ...
        'sectorSignature','','canonicalResidualNorm',Inf, ...
        'returnResidualNorm',Inf,'eventTimeError',Inf, ...
        'transverseFraction',0,'correctedCoefficients',[NaN;NaN;NaN], ...
        'transverseCriticalAlignment',0,'hindPairPhaseError',Inf, ...
        'frontPairPhaseError',Inf,'foreHindPhaseSeparation',0, ...
        'gaitClass','unclassified','gait','','abbreviation','', ...
        'rejectionStage','','rejectionIdentifier','','rejectionMessage','');
end

function cluster = EmptyCluster()
    cluster = struct('id',NaN,'gaitClass','','attemptIndices',[], ...
        'meanDirection',[],'radii',[],'persistent',false, ...
        'maximumCanonicalResidual',Inf,'maximumReturnResidual',Inf);
end

function [hindError,frontError,foreHind] = TimingDefects(E)
    E = E(:);
    T = E(9);
    phase = @(a,b) mod((a-b)/T + 0.5,1)-0.5;
    hindError = max(abs([phase(E(1),E(5)),phase(E(2),E(6))]));
    frontError = max(abs([phase(E(3),E(7)),phase(E(4),E(8))]));
    foreHind = max(abs([phase(E(1),E(3)),phase(E(2),E(4)), ...
        phase(E(5),E(7)),phase(E(6),E(8))]));
end

function label = ClassifyGait(hindError,frontError,foreHind,opts)
    hindSymmetric = hindError <= opts.PairSymmetryTolerance;
    frontSymmetric = frontError <= opts.PairSymmetryTolerance;
    if hindSymmetric && frontSymmetric
        if foreHind >= opts.BrokenSymmetryTolerance
            label = 'B';
        else
            label = 'PK';
        end
    elseif hindSymmetric && frontError >= opts.BrokenSymmetryTolerance
        label = 'F';
    elseif frontSymmetric && hindError >= opts.BrokenSymmetryTolerance
        label = 'H';
    else
        label = 'mixed';
    end
end

function label = SeedLabel(coefficients)
    [~,dominant] = max(abs(coefficients));
    names = {'b','f','h'};
    label = sprintf('%s:%+.3f,%+.3f,%+.3f', ...
        names{dominant},coefficients(1),coefficients(2),coefficients(3));
end

function gaitClass = SeedGaitClass(coefficients,tolerance)
    frontActive = abs(coefficients(2)) > tolerance;
    hindActive = abs(coefficients(3)) > tolerance;
    if ~frontActive && ~hindActive
        gaitClass = 'B';
    elseif frontActive && ~hindActive
        gaitClass = 'F';
    elseif hindActive && ~frontActive
        gaitClass = 'H';
    else
        gaitClass = 'ambiguous';
    end
end

function signature = TopologySignature(topology)
    signature = char(string(FieldOr(topology,'signature','')));
    if isempty(signature) && isfield(topology,'sortedEventNumbers')
        signature = mat2str(topology.sortedEventNumbers(:).');
    end
end

function PrintAttempt(attempt,opts)
    if ~opts.Verbose
        return
    end
    if attempt.nonParentAccepted
        fprintf(['  [%d] rho=%.1e %s accepted gait=%s residual=%.2e ' ...
            'return=%.2e transverse=%.3f\n'],attempt.index,attempt.radius, ...
            attempt.seedLabel,attempt.gaitClass,attempt.canonicalResidualNorm, ...
            attempt.returnResidualNorm,attempt.transverseFraction);
    elseif attempt.correctorAccepted
        fprintf('  [%d] rho=%.1e %s filtered: %s\n', ...
            attempt.index,attempt.radius,attempt.seedLabel, ...
            attempt.rejectionMessage);
    else
        fprintf('  [%d] rho=%.1e %s rejected at %s: %s\n', ...
            attempt.index,attempt.radius,attempt.seedLabel, ...
            attempt.rejectionStage,attempt.rejectionMessage);
    end
end

function status = SearchStatus(verified,attempts)
    if verified
        status = 'verified';
    elseif any([attempts.nonParentAccepted])
        status = 'partial';
    else
        status = 'no-accepted-rays';
    end
end

function value = FieldOr(structure,name,defaultValue)
    if isstruct(structure) && isfield(structure,name) && ...
            ~isempty(structure.(name))
        value = structure.(name);
    else
        value = defaultValue;
    end
end

function value = LogicalField(structure,name,defaultValue)
    candidate = FieldOr(structure,name,defaultValue);
    value = isscalar(candidate) && logical(candidate);
end
