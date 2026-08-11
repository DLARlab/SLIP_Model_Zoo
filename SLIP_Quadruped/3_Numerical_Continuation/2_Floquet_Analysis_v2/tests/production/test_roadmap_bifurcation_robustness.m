function tests = test_roadmap_bifurcation_robustness
%TEST_ROADMAP_BIFURCATION_ROBUSTNESS Reproducible packaged-data tests.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    floquetRoot = fileparts(fileparts(testRoot));
    experimentsRoot = fullfile(floquetRoot,'reference_experiments');
    sharedImplementationRoot = fullfile(experimentsRoot,'roadmap_common');
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(floquetRoot,sharedImplementationRoot);
    floquet.internal.ensureRuntimePaths(true);
    [definitions,definitionFunctions] = PackageDefinitions(experimentsRoot);
    packages = repmat(EmptyPackage(),1,numel(definitions));
    transitionCells = cell(1,numel(definitions));
    analysisCells = cell(1,numel(definitions));
    validationCells = cell(1,numel(definitions));
    for k = 1:numel(definitions)
        definition = definitions(k);
        paths = RoadmapRobustnessPaths(definition.ExperimentRoot);
        transitions = RoadmapBifurcationCases(paths,definition.TransitionIDs);
        resultFile = fullfile(paths.FinalResultsRoot, ...
            'roadmap_bifurcation_robustness_results.mat');
        testCase.assertTrue(isfile(resultFile),sprintf( ...
            'Missing independent %s package result.',definition.Code));
        loaded = load(resultFile,'report');
        testCase.assertTrue(isfield(loaded,'report'),sprintf( ...
            'Independent %s result lacks report.',definition.Code));
        packages(k) = struct('code',definition.Code, ...
            'root',definition.ExperimentRoot, ...
            'transitionIDs',{definition.TransitionIDs}, ...
            'definitionFunction',definitionFunctions{k}, ...
            'definition',definition,'paths',paths, ...
            'transitions',transitions,'resultFile',resultFile, ...
            'report',loaded.report);
        transitionCells{k} = transitions;
        analysisCells{k} = loaded.report.analyses;
        validationCells{k} = loaded.report.validations;
    end
    transitions = [transitionCells{:}];
    testCase.TestData.SharedImplementationRoot = sharedImplementationRoot;
    testCase.TestData.ExperimentsRoot = experimentsRoot;
    testCase.TestData.Packages = packages;
    testCase.TestData.Transitions = transitions;
    testCase.TestData.Analyses = [analysisCells{:}];
    testCase.TestData.Validations = [validationCells{:}];
end

function testRequiredEntryPointsResolve(testCase)
    names = {'floquet.computeFDM', ...
        'floquet.internal.poincare.buildMap', ...
        'floquet.internal.tracking.trackMultipliers', ...
        'floquet.detectBifurcations','floquet.refineCriticalOrbit', ...
        'floquet.predictBranchDirection','floquet.correctBranchSwitch', ...
        'ComputeRoadmapFloquetScan', ...
        'AnalyzeRoadmapBifurcationCase','ResolveRoadmapSymmetryBreakingMode', ...
        'ValidateRoadmapSignPairs','ValidateRoadmapTransition', ...
        'WriteRoadmapRobustnessArtifacts', ...
        'RunRoadmapReferenceExperiment', ...
        'main_Test_RoadmapBifurcationRobustness', ...
        'main_Refresh_RoadmapReferenceArtifacts', ...
        'main_HandValidate_RoadmapBifurcations'};
    for k = 1:numel(names)
        testCase.verifyNotEmpty(which(names{k}),names{k});
    end
    packages = testCase.TestData.Packages;
    for k = 1:numel(packages)
        testCase.verifyNotEmpty(which(packages(k).definitionFunction), ...
            packages(k).definitionFunction);
    end
    sharedFunction = which('RoadmapRobustnessPaths');
    testCase.verifyTrue(startsWith(sharedFunction, ...
        testCase.TestData.SharedImplementationRoot));
end

function testSharedEntryPointsRequireExplicitOwnership(testCase)
    testCase.verifyError(@() RoadmapRobustnessPaths(), ...
        'RoadmapRobustnessPaths:ExperimentRootRequired');
    testCase.verifyError(@() RoadmapBifurcationCases(), ...
        'RoadmapBifurcationCases:PathsRequired');
    package = RequirePackage(testCase,'BE');
    testCase.verifyError(@() RoadmapBifurcationCases(package.paths,{}), ...
        'RoadmapBifurcationCases:TransitionIDsRequired');
    testCase.verifyError(@() main_Test_RoadmapBifurcationRobustness(struct()), ...
        'main_Test_RoadmapBifurcationRobustness:ExperimentRootRequired');
    testCase.verifyError(@() main_HandValidate_RoadmapBifurcations(struct()), ...
        'main_HandValidate_RoadmapBifurcations:ExperimentRootRequired');
    testCase.verifyError(@() main_Refresh_RoadmapReferenceArtifacts(struct()), ...
        'main_Refresh_RoadmapReferenceArtifacts:ExperimentRootRequired');
    testCase.verifyError(@() RunRoadmapReferenceExperiment(struct(),'run'), ...
        'RunRoadmapReferenceExperiment:Definition');
    testCase.verifyError(@() RunRoadmapReferenceExperiment( ...
        package.definition,'unknown-action'), ...
        'RunRoadmapReferenceExperiment:Action');
end

function testPackageDefinitionsAreDeclarativeAndLocal(testCase)
    packages = testCase.TestData.Packages;
    expectedCodes = {'BG','BE','FG','HE'};
    expectedIDs = {{'bg_to_hg','bg_to_fg'}, {'be_to_fe','be_to_he'}, ...
        {'fg_to_gg'}, {'he_to_ge'}};
    for k = 1:numel(packages)
        definition = packages(k).definition;
        testCase.verifyEqual(definition.SchemaVersion, ...
            'floquet-roadmap-reference-definition-v1');
        testCase.verifyEqual(definition.Code,expectedCodes{k});
        testCase.verifyEqual(definition.ExperimentRoot,packages(k).root);
        testCase.verifyEqual(definition.TransitionIDs,expectedIDs{k});
        testCase.verifyFalse(any(isfield(definition, ...
            {'RoadmapCommonRoot','SharedRoadmapRoot'})));
        resolved = which(packages(k).definitionFunction);
        testCase.verifyTrue(startsWith(resolved, ...
            [packages(k).root,filesep]),resolved);
    end
end

function testNumberedReferenceArtifactLayout(testCase)
    packages = testCase.TestData.Packages;
    for k = 1:numel(packages)
        paths = packages(k).paths;
        files = { ...
            paths.ReferenceConfigFile, ...
            fullfile(paths.DiscoveryRoot,'floquet_analysis.mat'), ...
            fullfile(paths.DiscoveryRoot,'candidate_inventory.csv'), ...
            fullfile(paths.RefinementRoot,'refined_candidates.mat'), ...
            fullfile(paths.RefinementRoot,'refinement_summary.csv'), ...
            fullfile(paths.SeedSearchRoot,'daughter_seed_search.mat'), ...
            fullfile(paths.SeedSearchRoot,'daughter_seed_attempts.csv'), ...
            fullfile(paths.DaughterBranchesRoot,'inventory.mat'), ...
            fullfile(paths.DaughterBranchesRoot,'inventory.csv'), ...
            fullfile(paths.ValidationRoot,'validation_report.mat'), ...
            fullfile(paths.ValidationRoot,'validation_summary.csv')};
        for j = 1:numel(files)
            testCase.verifyTrue(isfile(files{j}),files{j});
        end
        testCase.verifyFalse(isfolder(fullfile(paths.ExperimentRoot, ...
            'results')));
        loaded = load(paths.ReferenceConfigFile,'referenceConfig');
        testCase.verifyEqual(loaded.referenceConfig.SchemaVersion, ...
            'floquet-reference-experiment-config-v2');
        testCase.verifyEqual(loaded.referenceConfig.ArtifactLayoutVersion, ...
            'numbered-artifacts-v1');
        testCase.verifyEqual(loaded.referenceConfig.WorkflowCompatibility, ...
            'not-resumable-by-floquet.workflow.Session');

        validationFile = fullfile(paths.ValidationRoot, ...
            'validation_report.mat');
        indexed = load(validationFile,'validationReport');
        testCase.verifyEqual(indexed.validationReport.SchemaVersion, ...
            'floquet-reference-validation-index-v3');
        payload = indexed.validationReport.Payload;
        testCase.verifyEqual(payload.Scope,'validation-only-index');
        testCase.verifyEqual(payload.ArtifactRole, ...
            'compact-index-to-authoritative-specialized-report');
        testCase.verifyEqual(numel(payload.Transitions), ...
            numel(packages(k).transitionIDs));
        testCase.verifyFalse(any(isfield(payload, ...
            {'analyses','validations','parentOnly','artifacts'})));
        testCase.verifyEqual(payload.AuthoritativeResult.SHA256, ...
            floquet.workflow.internal.FloquetFileSHA256( ...
                packages(k).resultFile));
        details = dir(validationFile);
        testCase.verifyLessThan(details.bytes,2*1024^2, ...
            'Stage-5 index unexpectedly embeds upstream numerical payloads.');
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
    package = RequirePackage(testCase,'BE');
    paths = package.paths;
    selected = RoadmapBifurcationCases(paths, ...
        {'be_to_he','BE_TO_FE'});
    testCase.verifyEqual({selected.ID}, ...
        {'be_to_he','be_to_fe'});
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
        testCase.TestData.SharedImplementationRoot);
    testCase.verifyNotEqual(localPaths.SharedImplementationRoot, ...
        localPaths.ExperimentRoot);
    testCase.verifyError(@() RoadmapBifurcationCases(localPaths, ...
        {'be_to_he'}),'RoadmapBifurcationCases:MissingBranchData');
end

function testIndependentPackagesUseRoleSpecificDataOnly(testCase)
    packages = testCase.TestData.Packages;
    for p = 1:numel(packages)
        paths = packages(p).paths;
        testCase.verifyFalse(isfolder(fullfile(paths.DataRoot, ...
            'branch_library')),packages(p).code);
        transitions = packages(p).transitions;
        for k = 1:numel(transitions)
            testCase.verifyEqual(fileparts(transitions(k).ParentFile), ...
                paths.ParentBranchRoot,transitions(k).ID);
            testCase.verifyEqual(fileparts(transitions(k).DaughterFile), ...
                paths.HeldOutDaughterBranchRoot,transitions(k).ID);
        end
    end
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

function testIndependentResultsContainFrozenParentStages(testCase)
    packages = testCase.TestData.Packages;
    total = 0;
    for p = 1:numel(packages)
        report = packages(p).report;
        count = numel(packages(p).transitionIDs);
        total = total+count;
        testCase.verifyEqual(report.version,'roadmap-bifurcation-robustness-v1');
        testCase.verifyTrue(report.parentOnly.complete,packages(p).code);
        testCase.verifyTrue(report.parentOnly.accepted,packages(p).code);
        testCase.verifyTrue(report.parentOnly.retrospectiveWindowCalibration, ...
            packages(p).code);
        testCase.verifyEqual(numel(report.parentOnly.analyses),count, ...
            packages(p).code);
        testCase.verifyTrue(all( ...
            ~[report.parentOnly.analyses.daughterDataLoaded]),packages(p).code);
        for k = 1:count
            testCase.verifyFalse(report.parentOnly.analyses(k). ...
                parentOnlyValidation.daughterDataUsed,packages(p).code);
        end
    end
    testCase.verifyEqual(total,6);
end

function testAllFiniteDifferenceMapsPassed(testCase)
    analyses = testCase.TestData.Analyses;
    for k = 1:numel(analyses)
        analysis = analyses(k);
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
    analyses = testCase.TestData.Analyses;
    expected = [4.50648 5.64574 4.83385 6.04811 5.91165 6.13617];
    actual = arrayfun(@(a)a.refinement.coordinate,analyses);
    testCase.verifyEqual(actual,expected,'AbsTol',5e-4);
    testCase.verifyTrue(all(strcmp( ...
        arrayfun(@(a)a.candidate.Type,analyses,'UniformOutput',false),'+1')));
end

function testRefinedNullDirectionsAreUniqueAndPairOdd(testCase)
    analyses = testCase.TestData.Analyses;
    for k = 1:numel(analyses)
        analysis = analyses(k);
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
    analyses = testCase.TestData.Analyses;
    transitions = testCase.TestData.Transitions;
    for k = 1:numel(analyses)
        analysis = analyses(k);
        attempts = analysis.attempts;
        for signValue = [-1 1]
            selected = [attempts.sign] == signValue;
            testCase.verifyGreaterThanOrEqual(nnz( ...
                [attempts(selected).acceptedBranchPoint]),2,analysis.ID);
            abbreviations = {attempts(selected).gaitAbbreviation};
            testCase.verifyTrue(all(strcmp(abbreviations, ...
                transitions(k).ExpectedGaitAbbreviation)),analysis.ID);
        end
        testCase.verifyTrue(analysis.signPairSymmetry.accepted,analysis.ID);
    end
end

function testHeldOutDaughterValidationPassed(testCase)
    validations = testCase.TestData.Validations;
    transitions = testCase.TestData.Transitions;
    testCase.verifyTrue(all([validations.accepted]));
    for k = 1:numel(validations)
        value = validations(k);
        testCase.verifyGreaterThanOrEqual(value.linearDirectionAlignment,0.90);
        testCase.verifyLessThanOrEqual(value.coordinateDifference,0.02);
        testCase.verifyEqual(value.daughterGaitAbbreviation, ...
            transitions(k).ExpectedGaitAbbreviation);
    end
end

function testIndependentSummariesDeclareSixValidatedCrossings(testCase)
    packages = testCase.TestData.Packages;
    transitionCount = 0;
    detectedCount = 0;
    parentAcceptedCount = 0;
    heldOutAcceptedCount = 0;
    for p = 1:numel(packages)
        summary = packages(p).report.summary;
        testCase.verifyTrue(summary.accepted,packages(p).code);
        transitionCount = transitionCount+summary.transitionCount;
        detectedCount = detectedCount+summary.detectedCrossingCount;
        parentAcceptedCount = parentAcceptedCount+ ...
            summary.parentOnlyAcceptedCount;
        heldOutAcceptedCount = heldOutAcceptedCount+ ...
            summary.heldOutAcceptedCount;
    end
    testCase.verifyEqual(transitionCount,6);
    testCase.verifyEqual(numel(packages),4);
    testCase.verifyEqual(detectedCount,6);
    testCase.verifyEqual(parentAcceptedCount,6);
    testCase.verifyEqual(heldOutAcceptedCount,6);
end

function testProductionSubsetRerunWhenEnabled(testCase)
    enabled = strcmp(getenv('SLIP_RUN_LONG_ROADMAP_TESTS'),'1');
    testCase.assumeTrue(enabled, ...
        ['Set SLIP_RUN_LONG_ROADMAP_TESTS=1 before MATLAB startup to run ' ...
         'an independent production BE-package BE->FE recomputation.']);
    package = RequirePackage(testCase,'BE');
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@() RemoveTemporaryRoot(temporaryRoot));
    % Keep the outer test-run diary active; this run is temporary.
    options = struct('OutputDirectory',fullfile(temporaryRoot,'final'), ...
        'IntermediateDirectory',fullfile(temporaryRoot,'intermediate'), ...
        'LogFile','', ...
        'MakePlots',false,'SaveArtifacts',false,'Verbose',false, ...
        'ThrowOnFailure',true);
    definition = package.definition;
    definition.TransitionIDs = {'be_to_fe'};
    rerun = RunRoadmapReferenceExperiment(definition,'run',options);
    referenceIndex = RequireTransitionIndex( ...
        package.report.transitions,'be_to_fe');
    rerunIndex = RequireTransitionIndex(rerun.transitions,'be_to_fe');
    testCase.verifyTrue(rerun.summary.accepted);
    testCase.verifyEqual(rerun.analyses(rerunIndex).refinement.coordinate, ...
        package.report.analyses(referenceIndex).refinement.coordinate, ...
        'AbsTol',1e-5);
end

function [definitions,functionNames] = PackageDefinitions(experimentsRoot)
    folders = {'BG_half_bounding_bifurcation', ...
        'BE_half_bounding_bifurcation','FG_GG_bifurcation', ...
        'GE_HE_bifurcation'};
    functionNames = {'BGHalfBoundingReferenceExperiment', ...
        'BEHalfBoundingReferenceExperiment','FGGGReferenceExperiment', ...
        'GEHEReferenceExperiment'};
    definitions = repmat(EmptyDefinition(),1,numel(functionNames));
    for k = 1:numel(functionNames)
        addpath(fullfile(experimentsRoot,folders{k}));
        definitions(k) = feval(functionNames{k});
    end
end

function definition = EmptyDefinition()
    definition = struct('SchemaVersion','','ID','','Code','', ...
        'ExperimentRoot','','TransitionIDs',{{}});
end

function package = EmptyPackage()
    package = struct('code','','root','','transitionIDs',{{}}, ...
        'definitionFunction','','definition',EmptyDefinition(), ...
        'paths',struct(),'transitions',struct([]),'resultFile','', ...
        'report',struct());
end

function package = RequirePackage(testCase,code)
    packages = testCase.TestData.Packages;
    index = find(strcmp({packages.code},code));
    testCase.assertEqual(numel(index),1,sprintf( ...
        'Expected one independent package with code %s.',code));
    package = packages(index);
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
