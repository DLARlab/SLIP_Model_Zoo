function validation = ValidatePronkingDaughterBranches(refinement, directions, options)
%VALIDATEPRONKINGDAUGHTERBRANCHES Compare the critical +1 space to known gaits.
%
%   VALIDATION = VALIDATEPRONKINGDAUGHTERBRANCHES(REFINEMENT,DIRECTIONS)
%   performs a held-out comparison between a refined pronking critical
%   orbit, its symmetry-resolved three-dimensional additional +1 space, and
%   the six saved roadmap branches BE/BG/FE/FG/HE/HG.  Saved daughter data
%   are used only here, after the Floquet space has been computed.
%
%   The test removes the local pronking tangent in the same scaled metric
%   used to resolve the critical space.  It then checks whether deterministic
%   outgoing daughter secants lie in that space and whether their timing
%   symmetries agree with bounding, front-spread half-bounding, and
%   hind-spread half-bounding.  This validates linear branch prediction; it
%   does not claim blind nonlinear enumeration of all six rays.

    if nargin < 3 || isempty(options)
        options = struct();
    end
    opts = ParseOptions(options);
    [criticalZ, parameters, tangent, criticalAccepted] = ...
        ResolveCriticalInputs(refinement);
    [criticalBasis, stateScale] = ResolveDirectionInputs(directions);

    if opts.RequireAcceptedRefinement && ~criticalAccepted
        error('ValidatePronkingDaughterBranches:UnacceptedRefinement', ...
            'The critical-orbit refinement must be accepted.');
    end

    tangentScaled = tangent(:) ./ stateScale;
    tangentNorm = norm(tangentScaled);
    if ~(isfinite(tangentNorm) && tangentNorm > opts.MinimumDirectionNorm)
        error('ValidatePronkingDaughterBranches:InvalidTangent', ...
            'The scaled pronking tangent is zero or nonfinite.');
    end
    tangentScaled = tangentScaled / tangentNorm;

    basisScaled = criticalBasis ./ stateScale;
    [~, basisRank] = OrthonormalColumns( ...
        basisScaled, opts.MinimumDirectionNorm);
    if basisRank ~= 3
        error('ValidatePronkingDaughterBranches:CriticalBasisRank', ...
            'The symmetry-resolved additional critical basis must have rank three.');
    end
    for column = 1:3
        columnNorm = norm(basisScaled(:,column));
        if columnNorm <= opts.MinimumDirectionNorm
            error('ValidatePronkingDaughterBranches:CriticalBasisRank', ...
                'A symmetry-resolved direction has zero scaled norm.');
        end
        basisScaled(:,column) = basisScaled(:,column) / columnNorm;
    end
    gramError = norm(basisScaled' * basisScaled - eye(3),'fro');
    if gramError > 100 * opts.MinimumDirectionNorm
        error('ValidatePronkingDaughterBranches:CriticalBasisOrthogonality', ...
            ['Bounding/front/hind directions are not mutually orthogonal in ' ...
             'the declared scaled metric (Gram error %.3e).'], gramError);
    end

    specifications = DaughterSpecifications(opts.RoadmapDirectory);
    daughters = repmat(EmptyDaughter(), 1, numel(specifications));
    for k = 1:numel(specifications)
        daughters(k) = AnalyzeDaughter(specifications(k), criticalZ, ...
            parameters, tangentScaled, basisScaled, stateScale, opts);
    end

    daughterDirections = [daughters.transverseOutgoingDirectionScaled];
    representative = [1 3 5]; % BE, FE, HE: one independently stored class each
    representativeDirections = daughterDirections(:, representative);
    [daughterBasis, daughterRank] = OrthonormalColumns( ...
        representativeDirections, opts.MinimumDirectionNorm);
    principalCosines = svd(basisScaled' * daughterBasis);
    principalCosines = min(1, max(0, real(principalCosines(:))));
    principalAngles = acosd(principalCosines);

    pairwiseCosines = real(daughterDirections' * daughterDirections);
    pairwiseCosines = max(-1, min(1, pairwiseCosines));
    offDiagonal = pairwiseCosines(~eye(size(pairwiseCosines)));

    alignments = [daughters.transverseAlignment];
    distances = [daughters.scaledOrbitDistance22];
    parameterErrors = [daughters.parameterErrorNormInf];
    periodicAccepted = [daughters.periodicOrbitAccepted];
    classMatches = [daughters.classificationMatches];
    timingMatches = [daughters.timingSymmetryMatches];

    assertions = struct();
    assertions.acceptedRefinement = criticalAccepted;
    assertions.parametersMatch = all(parameterErrors <= opts.ParameterTolerance);
    assertions.savedPointsNearCritical = all(distances <= opts.MaximumSavedOrbitDistance);
    assertions.savedPeriodicOrbitsAccepted = ...
        ~opts.ValidatePeriodicOrbits || all(periodicAccepted);
    assertions.allSecantsInCriticalSpace = ...
        all(alignments >= opts.MinimumSubspaceAlignment);
    assertions.threeIndependentGaitDirections = daughterRank == 3;
    assertions.criticalAndDaughterSpacesAgree = ...
        numel(principalCosines) == 3 && ...
        min(principalCosines) >= opts.MinimumPrincipalCosine;
    assertions.gaitClassesIdentified = all(classMatches);
    assertions.timingSymmetriesVerified = all(timingMatches);
    assertions.sixOrientedSecantsDistinct = ...
        isempty(offDiagonal) || max(offDiagonal) < opts.MaximumDuplicateCosine;

    names = fieldnames(assertions);
    values = false(size(names));
    for k = 1:numel(names)
        values(k) = logical(assertions.(names{k}));
    end

    validation = struct();
    validation.version = 'pronking-daughter-validation-v1';
    validation.generatedAt = char(datetime('now', ...
        'Format','yyyyMMdd''T''HHmmss'));
    validation.accepted = all(values);
    validation.status = Ternary(validation.accepted, 'validated', 'rejected');
    validation.criticalSolution = criticalZ;
    validation.parameters = parameters;
    validation.stateScale = stateScale;
    validation.tangentScaled = tangentScaled;
    validation.criticalBasisScaled = basisScaled;
    validation.criticalBasisPhysical = stateScale .* basisScaled;
    validation.daughters = daughters;
    validation.representativeIndices = representative;
    validation.representativeCodes = {daughters(representative).code};
    validation.daughterDirectionRank = daughterRank;
    validation.principalCosines = principalCosines;
    validation.principalAnglesDegrees = principalAngles;
    validation.pairwiseOrientedCosines = pairwiseCosines;
    validation.assertions = assertions;
    validation.options = opts;
    validation.linearPredictionValidated = ...
        assertions.allSecantsInCriticalSpace && ...
        assertions.criticalAndDaughterSpacesAgree;
    validation.threeGaitClassesIdentified = ...
        assertions.gaitClassesIdentified && ...
        assertions.timingSymmetriesVerified;
    validation.savedDaughterAgreementValidated = validation.accepted;
    validation.blindSixArmDiscoveryValidated = false;
    validation.nonlinearEnumerationStatus = ...
        ['not established by held-out secant validation; use the ' ...
         'multiplicity-aware sector search'];

    if opts.ThrowOnFailure && ~validation.accepted
        failed = names(~values);
        error('ValidatePronkingDaughterBranches:ValidationRejected', ...
            'Failed assertions: %s.', strjoin(failed, ', '));
    end
end

function opts = ParseOptions(options)
    if ~isstruct(options) || ~isscalar(options)
        error('ValidatePronkingDaughterBranches:InvalidOptions', ...
            'options must be a scalar structure.');
    end
    paths = PronkingExperimentPaths();
    defaults = struct();
    defaults.RoadmapDirectory = paths.DaughterBranchRoot;
    defaults.FloquetOptions = struct( ...
        'TopologyMode','clustered', ...
        'CheckTimingRepeatability',true, ...
        'ErrorOnFailure',false);
    defaults.ValidatePeriodicOrbits = true;
    defaults.RequireAcceptedRefinement = true;
    defaults.ParameterTolerance = 1e-12;
    defaults.MaximumSavedOrbitDistance = 0.1;
    defaults.MinimumSubspaceAlignment = 0.98;
    defaults.MinimumPrincipalCosine = 0.98;
    defaults.MaximumDuplicateCosine = 0.98;
    defaults.PairSymmetryTolerance = 1e-7;
    defaults.BrokenSymmetryTolerance = 1e-4;
    defaults.SectorClassificationTolerance = 0.1;
    defaults.MinimumDirectionNorm = 1e-12;
    defaults.ThrowOnFailure = false;

    opts = defaults;
    supplied = fieldnames(options);
    allowed = fieldnames(defaults);
    for k = 1:numel(supplied)
        hit = find(strcmpi(supplied{k}, allowed), 1);
        if isempty(hit)
            error('ValidatePronkingDaughterBranches:UnknownOption', ...
                'Unknown option ''%s''.', supplied{k});
        end
        opts.(allowed{hit}) = options.(supplied{k});
    end

    logicalFields = {'ValidatePeriodicOrbits','RequireAcceptedRefinement', ...
        'ThrowOnFailure'};
    for k = 1:numel(logicalFields)
        value = opts.(logicalFields{k});
        if ~(isscalar(value) && (islogical(value) || ...
                (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
            error('ValidatePronkingDaughterBranches:InvalidLogical', ...
                '%s must be a scalar logical.', logicalFields{k});
        end
        opts.(logicalFields{k}) = logical(value);
    end

    positiveFields = {'ParameterTolerance','MaximumSavedOrbitDistance', ...
        'MinimumSubspaceAlignment','MinimumPrincipalCosine', ...
        'MaximumDuplicateCosine','PairSymmetryTolerance', ...
        'BrokenSymmetryTolerance','SectorClassificationTolerance', ...
        'MinimumDirectionNorm'};
    for k = 1:numel(positiveFields)
        value = opts.(positiveFields{k});
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value > 0)
            error('ValidatePronkingDaughterBranches:InvalidTolerance', ...
                '%s must be a positive finite scalar.', positiveFields{k});
        end
    end
    bounded = {'MinimumSubspaceAlignment','MinimumPrincipalCosine', ...
        'MaximumDuplicateCosine','SectorClassificationTolerance'};
    for k = 1:numel(bounded)
        if opts.(bounded{k}) >= 1
            error('ValidatePronkingDaughterBranches:InvalidUnitTolerance', ...
                '%s must be less than one.', bounded{k});
        end
    end
    opts.RoadmapDirectory = char(string(opts.RoadmapDirectory));
    if ~isfolder(opts.RoadmapDirectory)
        error('ValidatePronkingDaughterBranches:MissingRoadmap', ...
            'Roadmap directory does not exist: %s', opts.RoadmapDirectory);
    end
end

function [z, parameters, tangent, accepted] = ResolveCriticalInputs(refinement)
    if ~isstruct(refinement) || ~isscalar(refinement)
        error('ValidatePronkingDaughterBranches:InvalidRefinement', ...
            'refinement must be the scalar diagnostics from RefineCriticalOrbit.');
    end
    accepted = LogicalField(refinement, 'accepted', false);
    if isfield(refinement,'solution') && ~isempty(refinement.solution)
        z = refinement.solution(:);
    elseif isfield(refinement,'X') && isfield(refinement,'E')
        z = [refinement.X(:); refinement.E(:)];
    else
        z = [];
    end
    parameters = FieldOr(refinement, 'parameters', []);
    tangent = FieldOr(refinement, 'localBranchTangent', []);
    parameters = parameters(:);
    tangent = tangent(:);
    if numel(z) ~= 22 || any(~isfinite(z)) || ...
            numel(parameters) ~= 7 || ...
            any(~isfinite(parameters) & ~isinf(parameters)) || ...
            numel(tangent) ~= 12 || any(~isfinite(tangent))
        error('ValidatePronkingDaughterBranches:IncompleteRefinement', ...
            'Refinement must contain finite solution, parameters, and 12-state tangent.');
    end
end

function [basis, stateScale] = ResolveDirectionInputs(directions)
    if ~isstruct(directions) || ~isscalar(directions)
        error('ValidatePronkingDaughterBranches:InvalidDirections', ...
            'directions must be a scalar symmetry-resolution structure.');
    end
    basis = FieldOr(directions, 'Matrix', []);
    stateScale = FieldOr(directions, 'StateScale', []);
    stateScale = stateScale(:);
    if ~isequal(size(basis),[12 3]) || any(~isfinite(basis(:))) || ...
            numel(stateScale) ~= 12 || any(~isfinite(stateScale)) || ...
            any(stateScale <= 0)
        error('ValidatePronkingDaughterBranches:DirectionShape', ...
            'directions.Matrix and StateScale must be finite 12-by-3 and 12-by-1 arrays.');
    end
end

function specifications = DaughterSpecifications(directory)
    codes = {'BE','BG','FE','FG','HE','HG'};
    classes = {'B','B','F','F','H','H'};
    names = {'Bounding extended','Bounding gathered', ...
        'Front-spread half-bound extended', ...
        'Front-spread half-bound gathered', ...
        'Hind-spread half-bound extended', ...
        'Hind-spread half-bound gathered'};
    near = [1 1 1 2 1 538];
    outgoing = [2 2 2 3 2 537];
    specifications = repmat(struct(), 1, numel(codes));
    for k = 1:numel(codes)
        specifications(k).code = codes{k};
        specifications(k).expectedClass = classes{k};
        specifications(k).description = names{k};
        specifications(k).file = fullfile(directory, ...
            sprintf('BD1_20_2_%s.mat',codes{k}));
        specifications(k).nearIndex = near(k);
        specifications(k).outgoingIndex = outgoing(k);
    end
end

function daughter = AnalyzeDaughter(specification, criticalZ, parameters, ...
        tangentScaled, basisScaled, stateScale, opts)
    if ~isfile(specification.file)
        error('ValidatePronkingDaughterBranches:MissingDaughterFile', ...
            'Missing saved daughter branch: %s', specification.file);
    end
    loaded = load(specification.file,'results');
    if ~isfield(loaded,'results') || size(loaded.results,1) ~= 29 || ...
            any(~isfinite(loaded.results(:)))
        error('ValidatePronkingDaughterBranches:InvalidDaughterFile', ...
            'Daughter file must contain a finite 29-by-N results array: %s', ...
            specification.file);
    end
    results = loaded.results;
    if max(specification.nearIndex, specification.outgoingIndex) > size(results,2)
        error('ValidatePronkingDaughterBranches:DaughterIndex', ...
            'Configured daughter indices exceed the branch length for %s.', ...
            specification.code);
    end

    nearSolution = results(1:22,specification.nearIndex);
    outgoingSolution = results(1:22,specification.outgoingIndex);
    nearParameters = results(23:29,specification.nearIndex);
    parameterError = norm(nearParameters - parameters, inf);

    qNear = nearSolution([1 2 4:13]);
    qOutgoing = outgoingSolution([1 2 4:13]);
    secantScaled = (qOutgoing - qNear) ./ stateScale;
    transverse = secantScaled - tangentScaled * (tangentScaled' * secantScaled);
    transverseNorm = norm(transverse);
    if ~(isfinite(transverseNorm) && transverseNorm > opts.MinimumDirectionNorm)
        error('ValidatePronkingDaughterBranches:DegenerateDaughterSecant', ...
            'The tangent-projected %s daughter secant is degenerate.', ...
            specification.code);
    end
    transverse = transverse / transverseNorm;

    coefficients = basisScaled' * transverse;
    alignment = norm(coefficients);
    angleDegrees = acosd(min(1,max(0,alignment)));
    projectionResidual = norm(transverse - basisScaled * coefficients);
    sectorFractions = abs(coefficients) / max(norm(coefficients), eps);
    predictedClass = ClassifyFromSectors( ...
        sectorFractions, opts.SectorClassificationTolerance);

    [hindError, frontError] = PairPhaseErrors(nearSolution(14:22));
    timingMatches = TimingClassMatches(specification.expectedClass, ...
        hindError, frontError, opts);
    [gait, abbreviation] = Gait_Identification(nearSolution);
    abbreviation = char(string(abbreviation));
    gait = char(string(gait));
    abbreviationMatches = startsWith(abbreviation, specification.expectedClass);

    if opts.ValidatePeriodicOrbits
        periodic = floquet.validatePeriodicOrbit( ...
            nearSolution, nearParameters, ...
            opts.FloquetOptions);
        periodicAccepted = periodic.accepted;
    else
        periodic = struct('accepted',NaN, ...
            'status','not-requested','rejectionReasons',{{}});
        periodicAccepted = true;
    end

    daughter = EmptyDaughter();
    daughter.code = specification.code;
    daughter.file = specification.file;
    daughter.description = specification.description;
    daughter.expectedClass = specification.expectedClass;
    daughter.nearIndex = specification.nearIndex;
    daughter.outgoingIndex = specification.outgoingIndex;
    daughter.nearSolution = nearSolution;
    daughter.outgoingSolution = outgoingSolution;
    daughter.nearDx = nearSolution(1);
    daughter.outgoingDx = outgoingSolution(1);
    daughter.scaledOrbitDistance22 = ScaledOrbitDistance(nearSolution, criticalZ);
    daughter.parameterErrorNormInf = parameterError;
    daughter.transverseOutgoingDirectionScaled = transverse;
    daughter.criticalCoordinates = coefficients;
    daughter.symmetrySectorFractions = sectorFractions;
    daughter.transverseAlignment = alignment;
    daughter.angleDegrees = angleDegrees;
    daughter.projectionResidual = projectionResidual;
    daughter.predictedClass = predictedClass;
    daughter.classificationMatches = strcmp(predictedClass, ...
        specification.expectedClass) && abbreviationMatches;
    daughter.hindPairPhaseError = hindError;
    daughter.frontPairPhaseError = frontError;
    daughter.timingSymmetryMatches = timingMatches;
    daughter.gait = gait;
    daughter.abbreviation = abbreviation;
    daughter.abbreviationMatches = abbreviationMatches;
    daughter.periodicValidation = periodic;
    daughter.periodicOrbitAccepted = periodicAccepted;
end

function daughter = EmptyDaughter()
    daughter = struct('code','','file','','description','', ...
        'expectedClass','','nearIndex',NaN,'outgoingIndex',NaN, ...
        'nearSolution',[],'outgoingSolution',[], ...
        'nearDx',NaN,'outgoingDx',NaN,'scaledOrbitDistance22',Inf, ...
        'parameterErrorNormInf',Inf, ...
        'transverseOutgoingDirectionScaled',[], ...
        'criticalCoordinates',[],'symmetrySectorFractions',[], ...
        'transverseAlignment',NaN,'angleDegrees',NaN, ...
        'projectionResidual',Inf,'predictedClass','', ...
        'classificationMatches',false,'hindPairPhaseError',Inf, ...
        'frontPairPhaseError',Inf,'timingSymmetryMatches',false, ...
        'gait','','abbreviation','','abbreviationMatches',false, ...
        'periodicValidation',struct(),'periodicOrbitAccepted',false);
end

function label = ClassifyFromSectors(fractions, tolerance)
    frontOdd = fractions(2);
    hindOdd = fractions(3);
    if frontOdd <= tolerance && hindOdd <= tolerance
        label = 'B';
    elseif frontOdd > tolerance && hindOdd <= tolerance
        label = 'F';
    elseif frontOdd <= tolerance && hindOdd > tolerance
        label = 'H';
    else
        label = 'mixed';
    end
end

function matches = TimingClassMatches(label, hindError, frontError, opts)
    switch label
        case 'B'
            matches = hindError <= opts.PairSymmetryTolerance && ...
                frontError <= opts.PairSymmetryTolerance;
        case 'F'
            matches = hindError <= opts.PairSymmetryTolerance && ...
                frontError >= opts.BrokenSymmetryTolerance;
        case 'H'
            matches = frontError <= opts.PairSymmetryTolerance && ...
                hindError >= opts.BrokenSymmetryTolerance;
        otherwise
            matches = false;
    end
end

function [hindError, frontError] = PairPhaseErrors(E)
    E = E(:);
    T = E(9);
    difference = @(a,b) mod((a-b)/T + 0.5,1) - 0.5;
    hindError = max(abs([difference(E(1),E(5)), ...
        difference(E(2),E(6))]));
    frontError = max(abs([difference(E(3),E(7)), ...
        difference(E(4),E(8))]));
end

function distance = ScaledOrbitDistance(candidate, reference)
    candidate = candidate(:);
    reference = reference(:);
    difference = candidate - reference;
    referencePeriod = reference(22);
    difference(14:21) = mod(difference(14:21) + ...
        0.5*referencePeriod, referencePeriod) - 0.5*referencePeriod;
    meanPeriod = mean([candidate(22), reference(22)]);
    scale = [10;1;1;0.5;0.5;0.3*ones(8,1); ...
        max(0.05,0.25*meanPeriod)*ones(8,1); ...
        max(0.1,0.5*meanPeriod)];
    distance = norm(difference ./ scale);
end

function [basis, numericalRank] = OrthonormalColumns(values, tolerance)
    [U,S,~] = svd(values,'econ');
    singularValues = diag(S);
    numericalRank = sum(singularValues > tolerance * ...
        max(1, singularValues(1)));
    basis = U(:,1:numericalRank);
    for k = 1:size(basis,2)
        [~,pivot] = max(abs(basis(:,k)));
        if basis(pivot,k) < 0
            basis(:,k) = -basis(:,k);
        end
    end
end

function value = FieldOr(structure, name, defaultValue)
    if isfield(structure,name) && ~isempty(structure.(name))
        value = structure.(name);
    else
        value = defaultValue;
    end
end

function value = LogicalField(structure, name, defaultValue)
    value = FieldOr(structure,name,defaultValue);
    value = isscalar(value) && logical(value);
end

function output = Ternary(condition, ifTrue, ifFalse)
    if condition
        output = ifTrue;
    else
        output = ifFalse;
    end
end
