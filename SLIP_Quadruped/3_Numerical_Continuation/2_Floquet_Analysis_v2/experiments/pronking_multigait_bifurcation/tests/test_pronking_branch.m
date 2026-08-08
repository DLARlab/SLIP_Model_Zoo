function tests = test_pronking_branch
%TEST_PRONKING_BRANCH Deterministic tests for reduced Floquet analysis.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    experimentRoot = fileparts(testRoot);
    addpath(experimentRoot);
    paths = PronkingExperimentPaths();
    addpath(paths.FloquetRoot);
    addpath(paths.UtilitiesRoot);
    addpath(paths.DynamicsRoot);
    addpath(paths.SolutionManagementRoot);

    canonical = load(paths.PronkingBranchFile,'results');

    testCase.TestData.AnalysisRoot = paths.FloquetRoot;
    testCase.TestData.SlipRoot = paths.SlipRoot;
    testCase.TestData.RepositoryRoot = paths.RepositoryRoot;
    testCase.TestData.CanonicalResults = canonical.results;
    % The historical comparison branch is exactly the first 358 columns of
    % the packaged canonical branch, so no duplicate legacy MAT is needed.
    testCase.TestData.LegacyResults = canonical.results(:,1:358);
end

function testRequiredEntryPointsResolve(testCase)
    names = {'ComputeFloquetFDM','BuildPoincareMap','DetectBifurcation', ...
        'RefineCriticalOrbit','PredictBranchDirection','CorrectBranchSwitch', ...
        'ExtractSectionState', ...
        'ApplySectionPerturbation','ScalePerturbation','TrackMultipliers', ...
        'ValidatePeriodicOrbit'};
    for i = 1:numel(names)
        testCase.verifyNotEmpty(which(names{i}),names{i});
    end
end

function testCriticalRefinementRejectsUnspecifiedParameterLaw(testCase)
    [left,right,parameters,candidate] = SyntheticRefinementInputs();
    parameters(2,2) = parameters(2,1) + 0.1;

    testCase.verifyError(@() RefineCriticalOrbit( ...
        left,right,parameters,candidate,struct('ThrowOnFailure',true)), ...
        'RefineCriticalOrbit:VaryingParameters');
end

function testCriticalRefinementRejectsAmbiguousCoordinateMap(testCase)
    [~,~,parameters,candidate] = SyntheticRefinementInputs();
    results = zeros(29,4);
    results(1,:) = [0 0 1 2];
    results(14:22,:) = repmat((0.1:0.1:0.9).',1,4);
    results(23:29,:) = repmat(parameters(:,1),1,4);
    candidate = rmfield(candidate,{'LeftIndex','RightIndex'});

    testCase.verifyError(@() RefineCriticalOrbit( ...
        results,candidate,struct('ThrowOnFailure',true)), ...
        'RefineCriticalOrbit:AmbiguousCoordinateMap');
end

function testCriticalRefinementRequiresAdjacentBracketByDefault(testCase)
    [~,~,parameters,candidate] = SyntheticRefinementInputs();
    results = zeros(29,3);
    results(1,:) = [0 1 2];
    results(14:22,:) = repmat((0.1:0.1:0.9).',1,3);
    results(23:29,:) = repmat(parameters(:,1),1,3);
    candidate.LeftIndex = 1;
    candidate.RightIndex = 3;
    candidate.Bracket = [0 2];

    testCase.verifyError(@() RefineCriticalOrbit( ...
        results,candidate,struct('ThrowOnFailure',true)), ...
        'RefineCriticalOrbit:NonadjacentBracket');
end

function testPronkingFixtureIsCanonicalAndLegacyAligned(testCase)
    canonical = testCase.TestData.CanonicalResults;
    legacy = testCase.TestData.LegacyResults;
    testCase.verifySize(canonical,[29 891]);
    testCase.verifySize(legacy,[29 358]);
    testCase.verifyEqual(canonical(:,1:358),legacy);
    testCase.verifyLessThan(max(abs(canonical(3,1:358))),4e-12);
    testCase.verifyGreaterThan(min(diff(canonical(1,1:358))),0);
end

function testSectionChartExcludesApexNormalCoordinate(testCase)
    X = (1:13).';
    [q,info] = ExtractSectionState(X);
    testCase.verifyEqual(q,X([1 2 4:13]));
    testCase.verifyEqual(info.excludedSectionStateIndex,3);

    [perturbed,perturbation] = ApplySectionPerturbation(X,3,0.125);
    testCase.verifyEqual(perturbed(3),X(3));
    testCase.verifyEqual(perturbed(4),X(4)+0.125);
    testCase.verifyTrue(perturbation.sectionConstraintPreservedExactly);
end

function testScaledStepsUseStateMagnitudeAndMultipleLevels(testCase)
    q = [0; 2; 0.1*ones(10,1)];
    options = struct('PerturbationMagnitude',1e-6, ...
        'PerturbationFactors',[2 1], 'StateScale',ones(12,1));
    [steps,info] = ScalePerturbation(q,[],options);
    testCase.verifySize(steps,[12 2]);
    testCase.verifyEqual(info.relativeMagnitudes,[2e-6 1e-6]);
    expectedScale = max(abs(q),ones(12,1));
    testCase.verifyEqual(steps(:,1),2e-6*expectedScale,'AbsTol',eps);
    testCase.verifyEqual(steps(:,2),1e-6*expectedScale,'AbsTol',eps);
end

function testSimultaneousPronkingEventsAreGrouped(testCase)
    E = testCase.TestData.CanonicalResults(14:22,196);
    groupedOptions = struct('TopologyMode','clustered', ...
        'TopologyClusterTolerance',1e-7);
    reference = ClassifyEventTopology(E,groupedOptions);
    sizes = cellfun(@numel,reference.clusters);
    testCase.verifyTrue(reference.valid);
    testCase.verifyEqual(reference.clusterCount,3);
    testCase.verifyEqual(sizes(:),[4;4;1]);

    splitE = E;
    splitE([1 3 5 7]) = splitE([1 3 5 7]) + ...
        [-1.5;-0.5;0.5;1.5]*1e-5;
    candidate = ClassifyEventTopology(splitE,groupedOptions);
    groupedComparison = CompareEventTopology(reference,candidate,groupedOptions);
    testCase.verifyTrue(groupedComparison.consistent);
    testCase.verifyGreaterThan( ...
        groupedComparison.maximumReferenceClusterPhaseSpread,0);

    strictOptions = groupedOptions;
    strictOptions.TopologyMode = 'strict';
    strictComparison = CompareEventTopology(reference,candidate,strictOptions);
    testCase.verifyFalse(strictComparison.consistent);
end

function testGlobalTrackingPreservesSyntheticModeIdentity(testCase)
    pointCount = 6;
    truth = [ones(1,pointCount); ...
        0.80 0.90 0.98 1.02 1.10 1.20; ...
        0.45*ones(1,pointCount)];
    permutations = [1 2 3; 2 3 1; 3 1 2; 2 1 3; 1 3 2; 3 2 1].';
    raw = zeros(size(truth));
    vectors = cell(1,pointCount);
    basis = eye(3);
    for k = 1:pointCount
        order = permutations(:,k);
        raw(:,k) = truth(order,k);
        vectors{k} = basis(:,order);
    end
    [tracks,diagnostics] = TrackMultipliers(raw,vectors);
    testCase.verifyEqual(tracks.Multipliers,truth,'AbsTol',1e-14);
    testCase.verifyTrue(all(diagnostics.ValidPoint));
    for k = 2:pointCount
        testCase.verifyGreaterThan(min(diagnostics.SelectedEigenvectorOverlap(:,k)), ...
            1-1e-12);
    end
end

function testDetectorFindsPersistentAdditionalPlusOneDirection(testCase)
    pointCount = 6;
    lambda = [ones(1,pointCount); ...
        0.80 0.90 0.98 1.02 1.10 1.20; ...
        0.45*ones(1,pointCount)];
    vectors = repmat({eye(3)},1,pointCount);
    tracks = TrackMultipliers(lambda,vectors);
    coordinate = 0:(pointCount-1);
    branchStates = [coordinate; zeros(2,pointCount)];
    options = struct('PersistencePoints',1, ...
        'BranchStates',branchStates, ...
        'RequireBranchTangentForPlusOne',true, ...
        'RejectTrivialBranchTangent',true, ...
        'RejectAmbiguousBranchTangent',true);
    [candidates,report] = DetectBifurcation(tracks,coordinate,options);

    isPlus = strcmp({candidates.Type},'+1');
    testCase.verifyTrue(any(isPlus));
    plus = candidates(find(isPlus,1));
    testCase.verifyTrue(plus.IsAdditionalNullDirection);
    testCase.verifyFalse(plus.IsTrivialBranchTangent);
    testCase.verifyGreaterThan(plus.ConfidenceScore,0);
    testCase.verifyGreaterThan(report.RejectedCandidateCount,0); % constant tangent mode
end

function testDetectorClassifiesMinusOneAndComplexCrossings(testCase)
    radius = [0.85 0.92 0.98 1.02 1.08 1.15];
    angleValue = 0.7;
    lambda = [0.4*ones(1,6); ...
        -0.75 -0.88 -0.98 -1.02 -1.12 -1.25; ...
        radius.*exp(1i*angleValue); ...
        radius.*exp(-1i*angleValue)];
    vectors = repmat({eye(4)},1,6);
    tracks = TrackMultipliers(lambda,vectors);
    [candidates,~] = DetectBifurcation(tracks,0:5, ...
        struct('PersistencePoints',1));
    types = {candidates.Type};
    testCase.verifyTrue(any(strcmp(types,'-1')));
    testCase.verifyEqual(nnz(strcmp(types,'complex-unit-circle')),1);
end

function testUnlabelledRealPredictorIsRejected(testCase)
    X = zeros(13,1);
    E = [0.1:0.1:0.8 1].';
    Para = ones(7,1);
    testCase.verifyError(@() PredictBranchDirection( ...
        X,E,Para,ones(12,1),struct()), ...
        'PredictBranchDirection:MultiplierRequired');
end

function testProductionPronkingFiniteDifferenceIsValidatedWhenEnabled(testCase)
    testCase.assumeTrue(strcmp(getenv('SLIP_RUN_LONG_FLOQUET_TESTS'),'1'), ...
        ['Set SLIP_RUN_LONG_FLOQUET_TESTS=1 before starting MATLAB to run ' ...
         'the expensive production timing-solver/Floquet test.']);

    column = 40;
    result = testCase.TestData.CanonicalResults(:,column);
    options = struct( ...
        'PerturbationMagnitude',1e-6, ...
        'PerturbationFactors',[2 1], ...
        'TopologyMode','clustered', ...
        'DerivativeConvergenceTolerance',0.1, ...
        'ForwardBackwardTolerance',0.1, ...
        'RejectOnDerivativeNonconvergence',true, ...
        'RejectOnForwardBackwardMismatch',true, ...
        'ErrorOnFailure',false);
    [M,lambda,V,diagnostics] = ComputeFloquetFDM( ...
        result(1:22),result(23:29),options);

    testCase.verifyTrue(isfield(diagnostics,'accepted'));
    if diagnostics.accepted
        testCase.verifySize(M,[12 12]);
        testCase.verifySize(lambda,[12 1]);
        testCase.verifySize(V,[12 12]);
        testCase.verifyTrue(diagnostics.baseValidation.accepted);
        testCase.verifyTrue(diagnostics.derivativeConverged);
        testCase.verifyTrue(diagnostics.forwardBackwardConsistent);
    else
        % A robust rejection is a scientifically valid outcome at the
        % simultaneous pronking event manifold, but it must be explained.
        testCase.verifyEmpty(M);
        testCase.verifyEmpty(lambda);
        testCase.verifyEmpty(V);
        testCase.verifyNotEmpty(diagnostics.rejectionReasons);
    end
end

function [left,right,parameters,candidate] = SyntheticRefinementInputs()
    left = zeros(22,1);
    left(14:22) = (0.1:0.1:0.9).';
    right = left;
    right(1) = 1;
    parameters = repmat(ones(7,1),1,2);
    candidate = struct('Type','-1','LeftIndex',1,'RightIndex',2, ...
        'Bracket',[0 1]);
end
