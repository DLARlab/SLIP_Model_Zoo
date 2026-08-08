function tests = test_roadmap_bifurcation_robustness
%TEST_ROADMAP_BIFURCATION_ROBUSTNESS Reproducible packaged-data tests.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    experimentRoot = fileparts(testRoot);
    addpath(experimentRoot);
    paths = RoadmapRobustnessPaths();
    addpath(paths.FloquetRoot,paths.UtilitiesRoot,paths.DynamicsRoot, ...
        paths.ContinuationAlgorithmRoot,paths.SolutionManagementRoot);
    transitions = RoadmapBifurcationCases(paths);
    resultFile = fullfile(paths.FinalResultsRoot, ...
        'roadmap_bifurcation_robustness_results.mat');
    testCase.TestData.Paths = paths;
    testCase.TestData.Transitions = transitions;
    testCase.TestData.ResultFile = resultFile;
    if isfile(resultFile)
        loaded = load(resultFile,'report');
        testCase.TestData.Report = loaded.report;
    else
        testCase.TestData.Report = struct();
    end
end

function testRequiredEntryPointsResolve(testCase)
    names = {'ComputeFloquetFDM','BuildPoincareMap','TrackMultipliers', ...
        'DetectBifurcation','RefineCriticalOrbit','PredictBranchDirection', ...
        'CorrectBranchSwitch','ComputeRoadmapFloquetScan', ...
        'AnalyzeRoadmapBifurcationCase','ResolveRoadmapSymmetryBreakingMode', ...
        'ValidateRoadmapSignPairs','ValidateRoadmapTransition', ...
        'WriteRoadmapRobustnessArtifacts', ...
        'main_Test_RoadmapBifurcationRobustness', ...
        'main_Refresh_RoadmapReferenceArtifacts', ...
        'main_HandValidate_RoadmapBifurcations'};
    for k = 1:numel(names)
        testCase.verifyNotEmpty(which(names{k}),names{k});
    end
end

function testRegistryDefinesFourParentsAndSixTransitions(testCase)
    cases = testCase.TestData.Transitions;
    testCase.verifyEqual(numel(cases),6);
    testCase.verifyEqual(numel(unique({cases.ParentExperiment})),4);
    testCase.verifyEqual(nnz(strcmp({cases.ParentCode},'BG')),2);
    testCase.verifyEqual(nnz(strcmp({cases.ParentCode},'BE')),2);
    testCase.verifyEqual(nnz(strcmp({cases.ParentCode},'FG')),1);
    testCase.verifyEqual(nnz(strcmp({cases.ParentCode},'HE')),1);
    testCase.verifyTrue(all(strcmp({cases.DaughterDataRole}, ...
        'held-out-validation-only')));
    for k = 1:numel(cases)
        daughterIndices = [cases(k).DaughterNearIndex, ...
            cases(k).DaughterOutgoingIndex];
        testCase.verifyTrue(all(isfinite(daughterIndices)),cases(k).ID);
        testCase.verifyTrue(all(daughterIndices >= 1),cases(k).ID);
        testCase.verifyEqual(daughterIndices,floor(daughterIndices),cases(k).ID);
        testCase.verifyNotEqual(daughterIndices(1),daughterIndices(2),cases(k).ID);
        loaded = load(cases(k).DaughterFile,'results');
        testCase.verifyLessThanOrEqual(max(daughterIndices), ...
            size(loaded.results,2),cases(k).ID);
    end
end

function testRegistrySelectionPreservesOrderAndRejectsBadIDs(testCase)
    paths = testCase.TestData.Paths;
    selected = RoadmapBifurcationCases(paths, ...
        {'he_to_ge','BG_TO_FG','be_to_fe'});
    testCase.verifyEqual({selected.ID}, ...
        {'he_to_ge','bg_to_fg','be_to_fe'});
    testCase.verifyError(@() RoadmapBifurcationCases(paths, ...
        {'be_to_fe','BE_TO_FE'}), ...
        'RoadmapBifurcationCases:DuplicateTransition');
    testCase.verifyError(@() RoadmapBifurcationCases(paths, ...
        {'not_a_transition'}), ...
        'RoadmapBifurcationCases:UnknownTransition');
end

function testLocalExperimentRootUsesRoleSpecificSelectedData(testCase)
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@() RemoveTemporaryRoot(temporaryRoot));
    localPaths = RoadmapRobustnessPaths(temporaryRoot);
    mkdir(localPaths.ParentBranchRoot);
    mkdir(localPaths.HeldOutDaughterBranchRoot);
    parentFile = fullfile(localPaths.ParentBranchRoot,'BD1_20_2_BE.mat');
    daughterFile = fullfile(localPaths.HeldOutDaughterBranchRoot, ...
        'BD1_20_2_FE.mat');
    TouchFile(parentFile);
    TouchFile(daughterFile);

    selected = RoadmapBifurcationCases(localPaths,{'BE_TO_FE'});
    testCase.verifyEqual(numel(selected),1);
    testCase.verifyEqual(selected.ID,'be_to_fe');
    testCase.verifyEqual(selected.ParentFile,parentFile);
    testCase.verifyEqual(selected.DaughterFile,daughterFile);
    testCase.verifyEqual(localPaths.ExperimentRoot,temporaryRoot);
    testCase.verifyEqual(localPaths.SharedImplementationRoot, ...
        testCase.TestData.Paths.ExperimentRoot);
    testCase.verifyError(@() RoadmapBifurcationCases(localPaths, ...
        {'be_to_he'}),'RoadmapBifurcationCases:MissingBranchData');
end

function testCanonicalRegistryFallsBackToBranchLibrary(testCase)
    paths = testCase.TestData.Paths;
    selected = RoadmapBifurcationCases(paths,{'be_to_fe'});
    testCase.verifyEqual(fileparts(selected.ParentFile), ...
        paths.BranchLibraryRoot);
    testCase.verifyEqual(fileparts(selected.DaughterFile), ...
        paths.BranchLibraryRoot);
end

function testHeldOutAlignmentUsesPersistentSmallestRadiusBySign(testCase)
    specification = testCase.TestData.Transitions(1);
    analysis = SyntheticHeldOutAnalysis(specification);
    validation = ValidateRoadmapTransition(analysis,specification, ...
        struct('ValidatePeriodicOrbits',false));

    testCase.verifyTrue(validation.accepted);
    testCase.verifyTrue( ...
        validation.assertions.correctedBranchesMatchDaughterDirection);
    testCase.verifyLessThan(validation.minimumCorrectionDirectionAlignment, ...
        1e-10);
    testCase.verifyGreaterThan(validation.maximumCorrectionDirectionAlignment, ...
        1-1e-10);

    loaded = load(specification.DaughterFile,'results');
    near = loaded.results(1:22,specification.DaughterNearIndex);
    periods = [analysis.refinement.solution(22),near(22)];
    expectedPhaseDifference = mod( ...
        analysis.refinement.solution(14:21)/periods(1) - ...
        near(14:21)/periods(2) + 0.5,1)-0.5;
    expectedTimeDiagnostic = mean(periods)*expectedPhaseDifference;
    testCase.verifyEqual(validation.scaledOrbitDifference22(13:20), ...
        expectedTimeDiagnostic,'AbsTol',1e-14);
end

function testHeldOutDaughterIndicesAreValidated(testCase)
    specification = testCase.TestData.Transitions(1);
    analysis = SyntheticHeldOutAnalysis(specification);
    specification.DaughterNearIndex = 0;
    testCase.verifyError(@() ValidateRoadmapTransition( ...
        analysis,specification,struct('ValidatePeriodicOrbits',false)), ...
        'ValidateRoadmapTransition:DaughterIndex');

    specification = testCase.TestData.Transitions(1);
    loaded = load(specification.DaughterFile,'results');
    specification.DaughterOutgoingIndex = size(loaded.results,2)+1;
    testCase.verifyError(@() ValidateRoadmapTransition( ...
        analysis,specification,struct('ValidatePeriodicOrbits',false)), ...
        'ValidateRoadmapTransition:DaughterIndex');
end

function testPackagedBranchLibraryIsFiniteAndParameterAligned(testCase)
    cases = testCase.TestData.Transitions;
    files = unique([{cases.ParentFile},{cases.DaughterFile}]);
    expectedParameter = [10;20;2;1;0;0.5;1];
    for k = 1:numel(files)
        loaded = load(files{k},'results');
        testCase.verifyEqual(size(loaded.results,1),29,files{k});
        testCase.verifyTrue(all(isfinite(loaded.results(:))),files{k});
        errorValue = max(abs(loaded.results(23:29,:)-expectedParameter),[],1);
        testCase.verifyLessThanOrEqual(max(errorValue),1e-12,files{k});
    end
end

function testSavedResultExistsAndContainsFrozenParentStage(testCase)
    testCase.assertTrue(isfile(testCase.TestData.ResultFile), ...
        'Run main_Test_RoadmapBifurcationRobustness first.');
    report = testCase.TestData.Report;
    testCase.verifyEqual(report.version,'roadmap-bifurcation-robustness-v1');
    testCase.verifyTrue(report.parentOnly.complete);
    testCase.verifyTrue(report.parentOnly.accepted);
    testCase.verifyTrue(report.parentOnly.retrospectiveWindowCalibration);
    testCase.verifyEqual(numel(report.parentOnly.analyses),6);
    testCase.verifyTrue(all(~[report.parentOnly.analyses.daughterDataLoaded]));
    for k = 1:6
        testCase.verifyFalse( ...
            report.parentOnly.analyses(k).parentOnlyValidation.daughterDataUsed);
    end
end

function testAllFiniteDifferenceMapsPassed(testCase)
    report = RequireReport(testCase);
    for k = 1:numel(report.analyses)
        analysis = report.analyses(k);
        testCase.verifyTrue(all(analysis.scan.accepted),analysis.ID);
        testCase.verifyLessThan(max( ...
            analysis.scan.convergence.derivativeRelativeError),1e-4,analysis.ID);
        testCase.verifyLessThan(max( ...
            analysis.scan.convergence.forwardBackwardRelativeError),1e-2, ...
            analysis.ID);
        testCase.verifyTrue(all(isfinite( ...
            analysis.scan.convergence.timingResidual)),analysis.ID);
        testCase.verifyLessThan(max( ...
            analysis.scan.convergence.timingResidual),1e-8,analysis.ID);
    end
end

function testSixRefinedCoordinatesMatchHistoricalAttachments(testCase)
    report = RequireReport(testCase);
    expected = [4.50648 5.64574 4.83385 6.04811 5.91165 6.13617];
    actual = arrayfun(@(a)a.refinement.coordinate,report.analyses);
    testCase.verifyEqual(actual,expected,'AbsTol',5e-4);
    testCase.verifyTrue(all(strcmp( ...
        arrayfun(@(a)a.candidate.Type,report.analyses,'UniformOutput',false),'+1')));
end

function testRefinedNullDirectionsAreUniqueAndPairOdd(testCase)
    report = RequireReport(testCase);
    for k = 1:numel(report.analyses)
        analysis = report.analyses(k);
        testCase.verifyTrue(analysis.refinement.accepted,analysis.ID);
        testCase.verifyTrue(analysis.refinement.branchSwitchReady,analysis.ID);
        testCase.verifyEqual( ...
            analysis.refinement.branchSwitchReadinessDiagnostics.svdNullity,2, ...
            analysis.ID);
        testCase.verifyTrue(analysis.symmetry.accepted,analysis.ID);
        testCase.verifyEqual(analysis.symmetry.oddNullRank,1,analysis.ID);
        testCase.verifyLessThan(analysis.symmetry.criticalOddResidual,1e-3, ...
            analysis.ID);
    end
end

function testBothNonlinearDirectionsPersistAndSwap(testCase)
    report = RequireReport(testCase);
    for k = 1:numel(report.analyses)
        analysis = report.analyses(k);
        attempts = analysis.attempts;
        for signValue = [-1 1]
            selected = [attempts.sign] == signValue;
            testCase.verifyGreaterThanOrEqual(nnz( ...
                [attempts(selected).acceptedBranchPoint]),2,analysis.ID);
            abbreviations = {attempts(selected).gaitAbbreviation};
            testCase.verifyTrue(all(strcmp(abbreviations, ...
                report.transitions(k).ExpectedGaitAbbreviation)),analysis.ID);
        end
        testCase.verifyTrue(analysis.signPairSymmetry.accepted,analysis.ID);
    end
end

function testHeldOutDaughterValidationPassed(testCase)
    report = RequireReport(testCase);
    testCase.verifyTrue(all([report.validations.accepted]));
    for k = 1:numel(report.validations)
        value = report.validations(k);
        testCase.verifyGreaterThanOrEqual(value.linearDirectionAlignment,0.90);
        testCase.verifyLessThanOrEqual(value.coordinateDifference,0.02);
        testCase.verifyEqual(value.daughterGaitAbbreviation, ...
            report.transitions(k).ExpectedGaitAbbreviation);
    end
end

function testSavedSummaryDeclaresSixValidatedCrossings(testCase)
    report = RequireReport(testCase);
    testCase.verifyTrue(report.summary.accepted);
    testCase.verifyEqual(report.summary.transitionCount,6);
    testCase.verifyEqual(report.summary.parentExperimentCount,4);
    testCase.verifyEqual(report.summary.detectedCrossingCount,6);
    testCase.verifyEqual(report.summary.parentOnlyAcceptedCount,6);
    testCase.verifyEqual(report.summary.heldOutAcceptedCount,6);
end

function testProductionSubsetRerunWhenEnabled(testCase)
    enabled = strcmp(getenv('SLIP_RUN_LONG_ROADMAP_TESTS'),'1');
    testCase.assumeTrue(enabled, ...
        ['Set SLIP_RUN_LONG_ROADMAP_TESTS=1 before MATLAB startup to run ' ...
         'an independent production BE->FE recomputation.']);
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@() RemoveTemporaryRoot(temporaryRoot));
    % Keep the outer test-run diary active; this run is temporary.
    options = struct('TransitionIDs',{{'be_to_fe'}}, ...
        'OutputDirectory',fullfile(temporaryRoot,'final'), ...
        'IntermediateDirectory',fullfile(temporaryRoot,'intermediate'), ...
        'LogFile','', ...
        'MakePlots',false,'SaveArtifacts',false,'Verbose',false, ...
        'ThrowOnFailure',true);
    rerun = main_Test_RoadmapBifurcationRobustness(options);
    referenceIndex = RequireTransitionIndex( ...
        testCase.TestData.Report.transitions,'be_to_fe');
    rerunIndex = RequireTransitionIndex(rerun.transitions,'be_to_fe');
    testCase.verifyTrue(rerun.summary.accepted);
    testCase.verifyEqual(rerun.analyses(rerunIndex).refinement.coordinate, ...
        testCase.TestData.Report.analyses(referenceIndex).refinement.coordinate, ...
        'AbsTol',1e-5);
end

function report = RequireReport(testCase)
    testCase.assertFalse(isempty(fieldnames(testCase.TestData.Report)), ...
        'Packaged final result is unavailable.');
    report = testCase.TestData.Report;
end

function analysis = SyntheticHeldOutAnalysis(specification)
    loaded = load(specification.DaughterFile,'results');
    near = loaded.results(:,specification.DaughterNearIndex);
    outgoing = loaded.results(:,specification.DaughterOutgoingIndex);
    solution = SymmetrizeExpectedPair( ...
        near(1:22),specification.ExpectedBrokenPair);
    qIndex = [1 2 4:13];
    stateScale = max(abs(solution(qIndex)),[1;1;0.5*ones(10,1)]);
    rawSecant = (outgoing(qIndex)-near(qIndex))./stateScale;
    [~,tangentIndex] = min(abs(rawSecant));
    scaledTangent = zeros(12,1);
    scaledTangent(tangentIndex) = 1;
    transverse = rawSecant-scaledTangent* ...
        (scaledTangent'*rawSecant);
    transverse = transverse/norm(transverse);
    [~,orthogonalIndex] = min(abs(transverse));
    orthogonal = zeros(12,1);
    orthogonal(orthogonalIndex) = 1;
    orthogonal = orthogonal-transverse*(transverse'*orthogonal);
    orthogonal = orthogonal/norm(orthogonal);

    amplitudes = [1e-2 1e-2 3e-3 3e-3 1e-3 1e-3];
    signs = [-1 1 -1 1 -1 1];
    attempts = repmat(struct('acceptedBranchPoint',true, ...
        'scaledTransverseDirection',[],'amplitude',NaN,'sign',NaN),1,6);
    for k = 1:numel(attempts)
        attempts(k).amplitude = amplitudes(k);
        attempts(k).sign = signs(k);
        if amplitudes(k) == max(amplitudes)
            attempts(k).scaledTransverseDirection = orthogonal;
        else
            attempts(k).scaledTransverseDirection = signs(k)*transverse;
        end
    end

    analysis = struct();
    analysis.accepted = true;
    analysis.ID = specification.ID;
    analysis.daughterDataLoaded = false;
    analysis.parentOnlyValidation = struct('accepted',true, ...
        'daughterDataUsed',false,'minimumAcceptedRadiiPerSign',2);
    analysis.refinement = struct('coordinate',near(1), ...
        'solution',solution,'parameters',near(23:29), ...
        'eigenData',struct('StateScale',stateScale, ...
            'Eigenvector',outgoing(qIndex)-near(qIndex)), ...
        'localBranchTangent',stateScale.*scaledTangent);
    analysis.attempts = attempts;
end

function solution = SymmetrizeExpectedPair(solution,pair)
    solution = solution(:);
    if strcmp(pair,'hind')
        stateLeft = [6 7]; stateRight = [10 11];
        timeLeft = [14 15]; timeRight = [18 19];
    else
        stateLeft = [8 9]; stateRight = [12 13];
        timeLeft = [16 17]; timeRight = [20 21];
    end
    stateMean = 0.5*(solution(stateLeft)+solution(stateRight));
    solution(stateLeft) = stateMean;
    solution(stateRight) = stateMean;
    timeMean = 0.5*(solution(timeLeft)+solution(timeRight));
    solution(timeLeft) = timeMean;
    solution(timeRight) = timeMean;
end

function index = RequireTransitionIndex(transitions,id)
    index = find(strcmp({transitions.ID},id));
    if numel(index) ~= 1
        error('test_roadmap_bifurcation_robustness:TransitionID', ...
            'Expected exactly one transition with ID %s.',id);
    end
end

function RemoveTemporaryRoot(pathname)
    if isfolder(pathname)
        try
            rmdir(pathname,'s');
        catch
            % Preserve the primary test result if cleanup is unavailable.
        end
    end
end


function TouchFile(filename)
    handle = fopen(filename,'w');
    if handle < 0
        error('test_roadmap_bifurcation_robustness:TouchFile', ...
            'Unable to create fixture %s.',filename);
    end
    fclose(handle);
end
