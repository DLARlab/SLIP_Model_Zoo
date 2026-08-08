function tests = test_be_half_bounding_bifurcation
%TEST_BE_HALF_BOUNDING_BIFURCATION Verify the independent BE package.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    experimentRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(experimentRoot);
    paths = BEHalfBoundingExperimentPaths();
    addpath(paths.RoadmapCommonRoot);
    testCase.TestData.Paths = paths;
    testCase.TestData.ResultFile = fullfile(paths.FinalResultsRoot, ...
        'roadmap_bifurcation_robustness_results.mat');
end

function testUniqueEntryPointsResolve(testCase)
    names = {'BEHalfBoundingExperimentPaths', ...
        'main_Test_BEHalfBoundingBifurcation', ...
        'main_HandValidate_BEHalfBoundingBifurcation', ...
        'main_Refresh_BEHalfBoundingReferenceArtifacts', ...
        'main_Test_RoadmapBifurcationRobustness'};
    for k = 1:numel(names)
        testCase.verifyNotEmpty(which(names{k}),names{k});
    end
end

function testPackagedInputsAreLocalAndFinite(testCase)
    paths = testCase.TestData.Paths;
    files = [{paths.ParentBranchFile},paths.DaughterBranchFiles];
    for k = 1:numel(files)
        testCase.assertTrue(isfile(files{k}),files{k});
        loaded = load(files{k},'results');
        testCase.verifyEqual(size(loaded.results,1),29,files{k});
        testCase.verifyTrue(all(isfinite(loaded.results(:))),files{k});
        testCase.verifyTrue(startsWith(files{k},paths.ExperimentRoot));
    end
end

function testSavedReferenceContainsTwoAcceptedTransitions(testCase)
    report = LoadReport(testCase);
    testCase.verifyEqual({report.transitions.ID}, ...
        {'be_to_fe','be_to_he'});
    testCase.verifyTrue(report.summary.accepted);
    testCase.verifyEqual(report.summary.transitionCount,2);
    testCase.verifyTrue(all([report.analyses.accepted]));
    testCase.verifyTrue(all([report.validations.accepted]));
    actual = arrayfun(@(x)x.refinement.coordinate,report.analyses);
    testCase.verifyEqual(actual,[4.83363821441 6.04807025559], ...
        'AbsTol',1e-8);
    VerifyLocalProvenance(testCase,report);
end

function testProductionRerunWhenEnabled(testCase)
    testCase.assumeTrue(strcmp(getenv( ...
        'SLIP_RUN_LONG_BE_PACKAGE_TESTS'),'1'));
    rerun = ProductionRerun();
    testCase.verifyTrue(rerun.summary.accepted);
    testCase.verifyEqual({rerun.transitions.ID},{'be_to_fe','be_to_he'});
end

function report = LoadReport(testCase)
    testCase.assertTrue(isfile(testCase.TestData.ResultFile), ...
        'Generate or export the package-local reference result first.');
    loaded = load(testCase.TestData.ResultFile,'report');
    testCase.assertTrue(isfield(loaded,'report'));
    report = loaded.report;
end

function VerifyLocalProvenance(testCase,report)
    root = testCase.TestData.Paths.ExperimentRoot;
    for k = 1:numel(report.transitions)
        testCase.verifyTrue(startsWith( ...
            report.transitions(k).ParentFile,root));
        testCase.verifyTrue(startsWith( ...
            report.transitions(k).DaughterFile,root));
    end
end

function report = ProductionRerun()
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@()RemoveTemporaryRoot(temporaryRoot));
    options = struct('OutputDirectory',fullfile(temporaryRoot,'final'), ...
        'IntermediateDirectory',fullfile(temporaryRoot,'intermediate'), ...
        'LogFile','','MakePlots',false,'SaveArtifacts',false, ...
        'Verbose',false,'ThrowOnFailure',true);
    report = main_Test_BEHalfBoundingBifurcation(options);
end

function RemoveTemporaryRoot(pathname)
    if isfolder(pathname), rmdir(pathname,'s'); end
end
