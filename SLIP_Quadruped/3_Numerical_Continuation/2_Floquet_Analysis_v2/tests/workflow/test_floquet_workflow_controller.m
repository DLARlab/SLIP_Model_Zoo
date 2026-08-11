function tests = test_floquet_workflow_controller
%TEST_FLOQUETWORKFLOWCONTROLLER Fast graphics-free workflow state tests.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    floquetRoot = fileparts(fileparts(testRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(floquetRoot, '-begin');
    testCase.TestData.FloquetRoot = floquetRoot;
end

function testNoArgumentControllerUsesCanonicalRunners(testCase)
    controller = floquet.workflow.Session();
    state = controller.GetState();
    verifyFalse(testCase, state.Loaded);
    verifySize(testCase, state.RunnerIdentities, [1 5]);
    verifyFalse(testCase, any([state.RunnerIdentities.TestInjected]));
    for k = 1:5
        verifyNotEmpty(testCase, state.RunnerIdentities(k).ImplementationFile);
        verifySubstring(testCase, ...
            state.RunnerIdentities(k).ImplementationFile, ...
            fullfile('+floquet', '+workflow', '+internal'));
        verifySubstring(testCase, state.RunnerIdentities(k).Function, ...
            'floquet.workflow.internal.');
        verifyTrue(testCase, endsWith( ...
            state.RunnerIdentities(k).ImplementationFile, ...
            [state.RunnerIdentities(k).CanonicalName '.m']));
    end
end

function testResetDetachesSessionWithoutDeletingInput(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    controller = floquet.workflow.Session();
    state = controller.LoadConfig(config);
    verifyTrue(testCase, state.Loaded);
    parentFile = config.ParentBranchFile;

    state = controller.Reset();

    verifyFalse(testCase, state.Loaded);
    verifyEmpty(testCase, fieldnames(controller.Config));
    verifyEmpty(testCase, fieldnames(controller.ConfigSource));
    verifyTrue(testCase, isfile(parentFile), ...
        'Reset must detach only the session and preserve parent data.');
end

function testConfigLoaderAcceptsStructAndFingerprintMat(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    [fromMemory, memorySource] = floquet.workflow.load(config);
    verifyEqual(testCase, fromMemory.ExperimentName, config.ExperimentName);
    verifyEqual(testCase, memorySource.Kind, 'memory-struct');

    filename = fullfile(fileparts(config.ParentBranchFile), 'config.mat');
    save(filename, 'config');
    [fromFile, fileSource] = floquet.workflow.load(filename);
    verifyEqual(testCase, fromFile.ParentBranchFile, config.ParentBranchFile);
    verifyEqual(testCase, fileSource.Kind, 'mat-file');
    verifyEqual(testCase, numel(fileSource.SHA256), 64);
    verifyError(testCase, @() floquet.workflow.load( ...
        strrep(filename, '.mat', '.m')), ...
        'FloquetWorkflow:ConfigFileType');
end

function testInspectionExposesOnlyValidatedDiscovery(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    state = floquet.workflow.inspect(config);
    verifyEqual(testCase, state.Stages(1).Status, 'ready');
    verifyTrue(testCase, state.Stages(1).CanRun);
    verifyFalse(testCase, state.Stages(2).CanRun);
    verifyEmpty(testCase, state.Discovery.Analysis);

    FakeDiscoveryStage(config);
    state = floquet.workflow.inspect(config);
    verifyTrue(testCase, state.Stages(1).Valid);
    verifyTrue(testCase, state.Discovery.Available);
    verifyEqual(testCase, height(state.CandidateTable), 1);
    verifyEqual(testCase, state.CandidateTable.CandidateID, ...
        "plus1_c0002_c0003");
    verifyFalse(testCase, state.Discovery.ScientificUseAllowed);
    verifyEqual(testCase, state.Discovery.Authority, ...
        'test-only-nonproduction-authority');

    changed = ones(29, 4);
    save(config.ParentBranchFile, 'changed');
    state = floquet.workflow.inspect(config);
    verifyEqual(testCase, state.Stages(1).Status, 'invalid');
    verifyFalse(testCase, state.Discovery.Available);
    verifyEmpty(testCase, state.Discovery.Analysis);
end

function testInjectedRunnersRequireExplicitNonproductionFlag(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    config.Testing = rmfield(config.Testing, ...
        'AllowWorkflowControllerInjection');
    controller = InjectedController();
    verifyError(testCase, @() controller.LoadConfig(config), ...
        'FloquetWorkflow:TestInjectionNotAuthorized');
end

function testControllerRunsFiveStagesInOrder(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    controller = InjectedController();
    controller.LoadConfig(config);
    verifyError(testCase, @() controller.RunStage(2), ...
        'FloquetWorkflow:StageNotReady');

    phases = strings(0, 1);
    [~, state] = controller.RunStage('discovery', @RecordStatus);
    verifyTrue(testCase, state.Stages(1).Valid);
    verifyFalse(testCase, state.Stages(1).CanRun);
    verifyTrue(testCase, all(ismember( ...
        ["started"; "progress"; "completed"], phases)));
    verifyError(testCase, @() controller.RunStage(2), ...
        'FloquetWorkflow:StageNotReady');

    state = controller.ConfirmCandidates('plus1_c0002_c0003');
    verifyTrue(testCase, state.Selection.Confirmed);
    verifyTrue(testCase, state.Stages(2).CanRun);
    [~, state] = controller.RunStage('refinement');
    verifyTrue(testCase, state.Stages(2).Valid);
    [~, state] = controller.RunStage('seeds');
    verifyTrue(testCase, state.Stages(3).Valid);
    verifyFalse(testCase, state.Stages(4).CanRun);
    verifyEqual(testCase, numel(state.Continuation.RayCatalog.Rows), 2);

    ray = struct('RayID', ...
        'plus1_c0002_c0003__physical_mode__sign_+1', ...
        'SeedAttemptIndices', [1 2]);
    state = controller.SetContinuationSelections(ray);
    verifyTrue(testCase, state.Continuation.Confirmed);
    verifyTrue(testCase, state.Stages(4).CanRun);
    verifyEqual(testCase, ...
        state.Config.Continuation.RaySelections.SeedAmplitudes, ...
        [1e-3 2e-3]);
    verifyEqual(testCase, numel( ...
        state.Config.Continuation.SourceSeedSHA256), 64);

    stageFourPhases = strings(0, 1);
    [~, state] = controller.RunStage(4, @RecordStageFourStatus);
    verifyTrue(testCase, state.Stages(4).Valid);
    verifyTrue(testCase, all(ismember( ...
        ["started"; "progress"; "completed"], stageFourPhases)));
    verifyTrue(testCase, state.Stages(5).CanRun);
    [~, state] = controller.RunStage(5);
    verifyTrue(testCase, state.Stages(5).Valid);
    verifyFalse(testCase, state.Stages(5).CanRun);
    verifyEqual(testCase, state.LastRun.Status, 'completed');

    function RecordStatus(event)
        phases(end + 1, 1) = string(event.Phase);
    end

    function RecordStageFourStatus(event)
        stageFourPhases(end + 1, 1) = string(event.Phase);
    end
end

function testBusyControllerRejectsReentrantMutation(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    controller = InjectedController();
    controller.LoadConfig(config);
    nestedIdentifier = '';
    controller.RunStage(1, @TryRefresh);
    verifyEqual(testCase, nestedIdentifier, 'FloquetWorkflow:Busy');
    verifyFalse(testCase, controller.GetState().IsBusy);

    function TryRefresh(event)
        if strcmp(event.Phase, 'started')
            try
                controller.Refresh();
            catch exception
                nestedIdentifier = exception.identifier;
            end
        end
    end
end

function testFailedRunnerReleasesBusyState(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    hooks = struct('StageFunctions', {{@FakeDiscoveryStage, ...
        @FailingRefinementStage, @FakeSeedStage, ...
        @FakeContinuationStage, @FakeValidationStage}});
    controller = floquet.workflow.Session('TestHooks', hooks);
    controller.LoadConfig(config);
    controller.RunStage(1);
    controller.ConfirmCandidates({});
    verifyError(testCase, @() controller.RunStage(2), ...
        'TestFixture:InjectedStageFailure');
    state = controller.GetState();
    verifyFalse(testCase, state.IsBusy);
    verifyEqual(testCase, state.ActiveStage, 0);
    verifyEqual(testCase, state.LastRun.Status, 'failed');
    verifyEqual(testCase, state.LastRun.ErrorIdentifier, ...
        'TestFixture:InjectedStageFailure');
end

function testCandidateAndRayConfirmationsFailClosed(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    controller = InjectedController();
    controller.LoadConfig(config);
    controller.RunStage(1);
    verifyError(testCase, @() controller.ConfirmCandidates('unknown'), ...
        'FloquetWorkflow:UnknownCandidateID');
    controller.ConfirmCandidates({});
    controller.RunStage(2);
    verifyError(testCase, @() controller.ConfirmCandidates({}), ...
        'FloquetWorkflow:CandidateSelectionFrozen');
    controller.RunStage(3);

    mixed = struct('RayID', ...
        'plus1_c0002_c0003__physical_mode__sign_+1', ...
        'SeedAttemptIndices', [1 3]);
    verifyError(testCase, ...
        @() controller.SetContinuationSelections(mixed), ...
        'FloquetWorkflow:RaySelectionMixedRay');
    rejected = struct('RayID', ...
        'plus1_c0002_c0003__physical_mode__sign_-1', ...
        'SeedAttemptIndices', [3 4]);
    verifyError(testCase, ...
        @() controller.SetContinuationSelections(rejected), ...
        'FloquetWorkflow:RaySelectionRejectedSeed');
end

function testHeldOutInputsLockStagesOneThroughFour(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    config.Validation.ReferenceDaughterBranchFiles = {'held_out.mat'};
    state = floquet.workflow.inspect(config);
    verifyFalse(testCase, ...
        state.InformationBarrier.ClearForStagesOneToFour);
    verifyFalse(testCase, any([state.Stages(1:4).CanRun]));
    controller = InjectedController();
    controller.LoadConfig(config);
    verifyError(testCase, @() controller.RunStage(1), ...
        'FloquetWorkflow:StageNotReady');
end

function controller = InjectedController()
    hooks = struct('StageFunctions', {{@FakeDiscoveryStage, ...
        @FakeRefinementStage, @FakeSeedStage, ...
        @FakeContinuationStage, @FakeValidationStage}});
    controller = floquet.workflow.Session('TestHooks', hooks);
end

function analysis = FakeDiscoveryStage(config)
    candidate = struct('CandidateID', 'plus1_c0002_c0003', ...
        'Type', '+1', 'BifurcationType', 'plus-one', ...
        'LeftIndex', 2, 'RightIndex', 3, ...
        'LeftBranchColumn', 2, 'RightBranchColumn', 3, ...
        'ContinuationCoordinate', 0.5, 'Multiplier', 1, ...
        'ConfidenceScore', 0.9, 'NullMultiplicity', 1, ...
        'NullDirectionClassification', 'additional-null-direction', ...
        'BranchSwitchReady', false);
    analysis = SyntheticDiscoveryAnalysis(config, candidate);
    save(config.Files.Discovery, 'analysis');
    if isfield(config.AnalysisOptions, 'StatusFcn') && ...
            isa(config.AnalysisOptions.StatusFcn, 'function_handle')
        config.AnalysisOptions.StatusFcn(struct( ...
            'message', 'Synthetic Stage-1 progress.'));
    end
end

function refinementReport = FakeRefinementStage(config)
    record = struct('CandidateID', 'plus1_c0002_c0003', ...
        'CandidateType', '+1', 'CandidateCount', 1, ...
        'Accepted', true, 'Diagnostics', struct());
    refinementReport = struct('Records', record, ...
        'SourceDiscoveryFile', Canonical(config.Files.Discovery), ...
        'SourceDiscoverySHA256', ...
            floquet.workflow.internal.FloquetFileSHA256( ...
            config.Files.Discovery));
    save(config.Files.Refinement, 'refinementReport');
end

function report = FailingRefinementStage(~)
    report = struct(); %#ok<NASGU>
    error('TestFixture:InjectedStageFailure', ...
        'Synthetic refinement runner failed deliberately.');
end

function seedReport = FakeSeedStage(config)
    attempts = SyntheticAttempts();
    seedReport = struct('Attempts', attempts, ...
        'CandidateRecords', struct([]), ...
        'SourceRefinementFile', Canonical(config.Files.Refinement), ...
        'SourceRefinementSHA256', ...
            floquet.workflow.internal.FloquetFileSHA256( ...
            config.Files.Refinement));
    save(config.Files.Seeds, 'seedReport');
end

function daughterReport = FakeContinuationStage(config)
    daughterReport = struct('ContinuationEnabled', true, ...
        'Records', struct([]), ...
        'SourceSeedFile', Canonical(config.Files.Seeds), ...
        'SourceSeedSHA256', ...
        floquet.workflow.internal.FloquetFileSHA256(config.Files.Seeds));
    save(config.Files.Daughters, 'daughterReport');
    if isfield(config.Continuation, 'StatusFcn') && ...
            isa(config.Continuation.StatusFcn, 'function_handle')
        config.Continuation.StatusFcn(struct( ...
            'message', 'Synthetic Stage-4 progress.'));
    end
end

function validationReport = FakeValidationStage(config)
    validationReport = struct('Accepted', false, ...
        'Status', 'synthetic-no-evidence', ...
        'SourceDaughterFile', Canonical(config.Files.Daughters), ...
        'SourceDaughterSHA256', ...
            floquet.workflow.internal.FloquetFileSHA256( ...
            config.Files.Daughters));
    save(config.Files.Validation, 'validationReport');
end

function attempts = SyntheticAttempts()
    attempts = repmat(struct('CandidateID', 'plus1_c0002_c0003', ...
        'DirectionID', 'physical_mode', 'Sign', 1, ...
        'Amplitude', 1e-3, 'Accepted', true), 1, 4);
    attempts(2).Amplitude = 2e-3;
    attempts(3).Sign = -1;
    attempts(4).Sign = -1;
    attempts(4).Amplitude = 2e-3;
    attempts(4).Accepted = false;
end

function [config, cleanup] = SyntheticConfig(testCase)
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@() RemoveDirectory(temporaryRoot));
    branch = zeros(29, 4);
    parentFile = fullfile(temporaryRoot, 'parent.mat');
    save(parentFile, 'branch');
    config = struct();
    config.SchemaVersion = 'floquet-workflow-config-v2';
    config.ArtifactLayoutVersion = 'numbered-artifacts-v1';
    config.ExperimentName = 'controller_synthetic';
    config.ExperimentRoot = fullfile(testCase.TestData.FloquetRoot, ...
        'examples', 'blind_parent_profiles', 'controller_synthetic');
    config.FloquetRoot = testCase.TestData.FloquetRoot;
    config.OverwriteResults = false;
    config.ParentBranchFile = parentFile;
    config.ExpectedParentSHA256 = '';
    config.AnalysisOptions = struct('Verbose', false, ...
        'ComputeFunction', @MockControllerEvaluator, ...
        'AllowNonProductionComputeFunction', true);
    config.Discovery = struct('ExportOnly', false);
    config.Selection = struct('Confirmed', false, ...
        'CandidateIDs', {{}});
    config.Refinement = struct('Options', struct(), ...
        'ConfigureGroup', [], 'DxMonotonicityNeighborRadius', 1, ...
        'DxMonotonicityTolerance', []);
    config.BranchSwitch = struct('Amplitudes', [1e-3 2e-3], ...
        'Signs', [-1 1], 'DirectionResolver', [], ...
        'CorrectorFunction', [], 'PredictorOptions', struct(), ...
        'CorrectorOptions', struct());
    config.Continuation = struct('Enabled', false, ...
        'Confirmed', false, 'RaySelections', struct([]), ...
        'SourceSeedSHA256', '', 'SeedAmplitudes', [], ...
        'Overwrite', false, 'StoreResultsInInventory', false, ...
        'Options', struct());
    config.Validation = struct('ReferenceDaughterBranchFiles', {{}}, ...
        'Function', []);
    config.Testing = struct('AllowNonProductionDiscovery', true, ...
        'AllowWorkflowControllerInjection', true);
    config.Files = struct( ...
        'Discovery', fullfile(temporaryRoot, 'discovery.mat'), ...
        'Refinement', fullfile(temporaryRoot, 'refinement.mat'), ...
        'Seeds', fullfile(temporaryRoot, 'seeds.mat'), ...
        'Daughters', fullfile(temporaryRoot, 'daughters.mat'), ...
        'Validation', fullfile(temporaryRoot, 'validation.mat'));
end

function analysis = SyntheticDiscoveryAnalysis(config, candidates)
    identity = floquet.workflow.internal.FloquetParentIdentity(config);
    columns = 1:identity.PointCount;
    source = struct('kind', 'mat-file', ...
        'file', identity.CanonicalPath, 'variable', identity.Variable, ...
        'fileSHA256', identity.FileSHA256, ...
        'branchSHA256', identity.BranchSHA256, ...
        'fullBranchPointCount', identity.PointCount, ...
        'selectedPointCount', identity.PointCount, ...
        'selectedColumns', columns);
    stage = struct('Name', 'parent-only-full-branch-discovery', ...
        'ParentBranchFile', identity.CanonicalPath, ...
        'ParentIdentity', identity, 'FullBranchSelection', true, ...
        'Authority', 'test-only-nonproduction-authority', ...
        'ScientificUseAllowed', false);
    coverage = struct('fullParentPointCount', identity.PointCount, ...
        'selectedPointCount', identity.PointCount, ...
        'selectedColumns', columns, ...
        'selectionPreservesContinuationOrder', true, ...
        'fullParentCoverage', true, 'fullOrderedParentCoverage', true);
    [~, evaluatorIdentity] = ...
        floquet.internal.provenance.evaluatorIdentity( ...
        @MockControllerEvaluator, 'floquet.computeFDM');
    provenance = struct('parentDataOnly', true, ...
        'computeFunction', 'MockControllerEvaluator', ...
        'productionEvaluator', false, ...
        'computeEvaluatorIdentity', evaluatorIdentity, ...
        'fullParentCoverage', true, 'orderedParentCoverage', true, ...
        'scientificAuthority', false, 'coverage', coverage);
    analysis = struct('version', 'floquet-branch-analysis-v2', ...
        'algorithmID', ...
            'reduced-poincare-fdm-v2-canonical-branch-scan', ...
        'parentOnly', true, 'daughterDataLoaded', false, ...
        'coverage', coverage, 'fullParentCoverage', true, ...
        'fullOrderedParentCoverage', true, ...
        'scientificAuthority', false, 'source', source, ...
        'provenance', provenance, 'branchIndices', columns, ...
        'sampleIndices', columns, 'states', zeros(13, identity.PointCount), ...
        'candidates', candidates, ...
        'rejectedReport', struct('points', struct([]), ...
            'intervals', struct([])), 'workflowStage', stage);
    analysis.states(1, :) = columns;
end

function output = MockControllerEvaluator(varargin)
    output = varargin; %#ok<NASGU>
    error('TestFixture:UnexpectedEvaluatorCall', ...
        'The synthetic workflow must not call the numerical evaluator.');
end

function filename = Canonical(filename)
    filename = char(java.io.File(filename).getCanonicalPath());
end

function RemoveDirectory(directory)
    if isfolder(directory)
        rmdir(directory, 's');
    end
end
