function tests = test_fg_gg_bifurcation
%TEST_FG_GG_BIFURCATION Verify the independent FG->GG package.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    experimentRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(experimentRoot);
    paths = FGGGExperimentPaths();
    addpath(paths.RoadmapCommonRoot);
    testCase.TestData.Paths = paths;
    testCase.TestData.ResultFile = fullfile(paths.FinalResultsRoot, ...
        'roadmap_bifurcation_robustness_results.mat');
end

function testUniqueEntryPointsResolve(testCase)
    names = {'FGGGExperimentPaths','main_Test_FGGGBifurcation', ...
        'main_HandValidate_FGGGBifurcation', ...
        'main_Refresh_FGGGReferenceArtifacts', ...
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

function testSavedReferenceContainsAcceptedTransition(testCase)
    report = LoadReport(testCase);
    testCase.verifyEqual({report.transitions.ID},{'fg_to_gg'});
    testCase.verifyTrue(report.summary.accepted);
    testCase.verifyEqual(report.summary.transitionCount,1);
    testCase.verifyTrue(report.analyses.accepted);
    testCase.verifyTrue(report.validations.accepted);
    testCase.verifyEqual(report.analyses.refinement.coordinate, ...
        5.91164917105,'AbsTol',1e-8);
    VerifyLocalProvenance(testCase,report);
end

function testProductionRerunWhenEnabled(testCase)
    testCase.assumeTrue(strcmp(getenv( ...
        'SLIP_RUN_LONG_FGGG_PACKAGE_TESTS'),'1'));
    rerun = ProductionRerun();
    testCase.verifyTrue(rerun.summary.accepted);
    testCase.verifyEqual({rerun.transitions.ID},{'fg_to_gg'});
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
    testCase.verifyTrue(startsWith(report.transitions.ParentFile,root));
    testCase.verifyTrue(startsWith(report.transitions.DaughterFile,root));
end

function report = ProductionRerun()
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@()RemoveTemporaryRoot(temporaryRoot));
    options = struct('OutputDirectory',fullfile(temporaryRoot,'final'), ...
        'IntermediateDirectory',fullfile(temporaryRoot,'intermediate'), ...
        'LogFile','','MakePlots',false,'SaveArtifacts',false, ...
        'Verbose',false,'ThrowOnFailure',true);
    report = main_Test_FGGGBifurcation(options);
end

function RemoveTemporaryRoot(pathname)
    if isfolder(pathname), rmdir(pathname,'s'); end
end
