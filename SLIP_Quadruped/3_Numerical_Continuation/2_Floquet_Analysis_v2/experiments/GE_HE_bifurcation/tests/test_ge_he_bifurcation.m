function tests = test_ge_he_bifurcation
%TEST_GE_HE_BIFURCATION Verify HE parent -> GE daughter provenance.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    experimentRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(experimentRoot);
    paths = GEHEExperimentPaths();
    addpath(paths.RoadmapCommonRoot);
    testCase.TestData.Paths = paths;
    testCase.TestData.ResultFile = fullfile(paths.FinalResultsRoot, ...
        'roadmap_bifurcation_robustness_results.mat');
end

function testUniqueEntryPointsResolve(testCase)
    names = {'GEHEExperimentPaths','main_Test_GEHEBifurcation', ...
        'main_HandValidate_GEHEBifurcation', ...
        'main_Refresh_GEHEReferenceArtifacts', ...
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

function testSavedReferenceUsesHEParentAndGEDaughter(testCase)
    report = LoadReport(testCase);
    testCase.verifyEqual({report.transitions.ID},{'he_to_ge'});
    testCase.verifyEqual(report.transitions.ParentCode,'HE');
    testCase.verifyEqual(report.transitions.DaughterCode,'GE');
    testCase.verifyTrue(report.summary.accepted);
    testCase.verifyEqual(report.summary.transitionCount,1);
    testCase.verifyTrue(report.analyses.accepted);
    testCase.verifyTrue(report.validations.accepted);
    testCase.verifyEqual(report.analyses.refinement.coordinate, ...
        6.13622289546,'AbsTol',1e-8);
    VerifyLocalProvenance(testCase,report);
end

function testProductionRerunWhenEnabled(testCase)
    testCase.assumeTrue(strcmp(getenv( ...
        'SLIP_RUN_LONG_GEHE_PACKAGE_TESTS'),'1'));
    rerun = ProductionRerun();
    testCase.verifyTrue(rerun.summary.accepted);
    testCase.verifyEqual({rerun.transitions.ID},{'he_to_ge'});
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
    report = main_Test_GEHEBifurcation(options);
end

function RemoveTemporaryRoot(pathname)
    if isfolder(pathname), rmdir(pathname,'s'); end
end
