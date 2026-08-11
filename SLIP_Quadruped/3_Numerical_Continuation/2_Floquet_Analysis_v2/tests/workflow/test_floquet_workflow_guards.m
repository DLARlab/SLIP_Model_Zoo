function tests = test_floquet_workflow_guards
%TEST_FLOQUET_WORKFLOW_GUARDS Fast workflow tests without dynamics integration.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testDirectory = fileparts(mfilename('fullpath'));
    floquetRoot = fileparts(fileparts(testDirectory));
    templateRoot = fullfile(floquetRoot, 'templates', ...
        'new_branch_workflow');
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(floquetRoot);
    addpath(templateRoot, '-begin');
    testCase.TestData.FloquetRoot = floquetRoot;
end

function testTemplateGuardAndNestedPath(testCase)
    clear ExperimentConfig main_RunDiscovery
    verifyError(testCase, @() main_RunDiscovery(), ...
        'main_RunDiscovery:ConfigRequired');
    root = tempname;
    mkdir(root);
    cleanup = onCleanup(@() RemoveDirectory(root)); %#ok<NASGU>
    parentFile = fullfile(root,'parent.mat');
    results = zeros(29,2);
    save(parentFile,'results');
    config = ExperimentConfig(parentFile);
    config.ExperimentRoot = fullfile(testCase.TestData.FloquetRoot, ...
        'examples', 'blind_parent_profiles', 'synthetic_parent');
    verifyEqual(testCase, AddFloquetWorkflowPath(config), ...
        testCase.TestData.FloquetRoot);
    verifyEqual(testCase, ...
        floquet.workflow.internal.AddFloquetNumericalPaths(config), ...
        testCase.TestData.FloquetRoot);
end

function testRelativeParentPathUsesExperimentRoot(testCase)
    root = tempname;
    mkdir(fullfile(root, 'data', 'parent_branch'));
    cleanup = onCleanup(@() RemoveDirectory(root));
    results = zeros(29, 2);
    expected = fullfile(root, 'data', 'parent_branch', 'parent.mat');
    save(expected, 'results');
    config = struct('ExperimentRoot', root, ...
        'ParentBranchFile', fullfile('data', 'parent_branch', 'parent.mat'));

    resolved = ...
        floquet.workflow.internal.ResolveFloquetParentBranch(config);

    verifyEqual(testCase, resolved, ...
        char(java.io.File(expected).getCanonicalPath()));
end

function testStagesOneThroughFourEnforceHeldOutInformationBarrier(testCase)
    config = struct('Validation', struct( ...
        'ReferenceDaughterBranchFiles', {{'known_daughter.mat'}}, ...
        'Function', []));
    verifyError(testCase, @() ...
        floquet.workflow.internal.EnforceFloquetInformationBarrier( ...
        config, 'synthetic stage'), ...
        'TemplateExperiment:InformationBarrier');
end

function testInformationBarrierAcceptsOmittedStageName(testCase)
    config = struct('Validation', struct( ...
        'ReferenceDaughterBranchFiles', {{}}, 'Function', []));
    floquet.workflow.internal.EnforceFloquetInformationBarrier(config);
    verifyTrue(testCase, true);
end

function testStageTwoRequiresExplicitCandidateSelectionConfirmation(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    config.Selection.Confirmed = false;

    verifyError(testCase, @() ...
        floquet.workflow.internal.refinementStage(config), ...
        'TemplateExperiment:CandidateSelectionNotConfirmed');
end

function testUnresolvedCandidatesDoNotAbort(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    candidate = repmat(struct('CandidateID', '', 'Type', '+1', ...
        'LeftIndex', 1, 'RightIndex', 2), 1, 3);
    candidate(1).CandidateID = 'repeat_c0001_c0002';
    candidate(2) = candidate(1);
    candidate(3).CandidateID = 'fold_c0002_c0004';
    candidate(3).LeftIndex = 2;
    candidate(3).RightIndex = 4;
    analysis = SyntheticDiscoveryAnalysis(config, candidate);
    analysis.states(1, :) = [0 1 0 1];
    save(config.Files.Discovery, 'analysis');

    report = floquet.workflow.internal.refinementStage(config);
    verifyEqual(testCase, numel(report.Records), 2);
    verifyEqual(testCase, report.SourceDiscoverySHA256, ...
        floquet.workflow.internal.FloquetFileSHA256( ...
        config.Files.Discovery));
    verifyEqual(testCase, report.Records(1).Status, ...
        'unsupported-repeated-critical-group');
    verifyEqual(testCase, report.Records(2).Status, ...
        'unresolved-fixed-dx-fold');
    verifyTrue(testCase, isfile(config.Files.RefinementSummary));
    verifyError(testCase, @() ...
        floquet.workflow.internal.refinementStage(config), ...
        'TemplateExperiment:ArtifactExists');
end

function testUnsupportedSwitchAndDisabledContinuationAreArtifacts(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    records = repmat(BaseRefinementRecord(), 1, 2);
    records(1).CandidateID = 'minus1_c0001_c0002';
    records(1).CandidateType = '-1';
    records(2).CandidateID = 'plus1_c0002_c0003';
    records(2).CandidateType = '+1';
    records(2).Diagnostics = struct('branchSwitchReady', false);
    refinementReport = struct('Records', records);
    InstallSyntheticDiscovery(config);
    SaveRefinementReport(config, refinementReport);

    seeds = floquet.workflow.internal.seedSearchStage(config);
    verifyEqual(testCase, seeds.SourceRefinementSHA256, ...
        floquet.workflow.internal.FloquetFileSHA256( ...
        config.Files.Refinement));
    verifyEmpty(testCase, seeds.Attempts);
    verifyEqual(testCase, seeds.CandidateRecords(1).Status, ...
        'unsupported-crossing-type');
    verifyEqual(testCase, seeds.CandidateRecords(2).Status, ...
        'unsupported-not-switch-ready');
    daughters = floquet.workflow.internal.continuationStage(config);
    verifyEqual(testCase, daughters.SourceSeedSHA256, ...
        floquet.workflow.internal.FloquetFileSHA256(config.Files.Seeds));
    verifyEqual(testCase, daughters.Status, ...
        'complete-continuation-disabled');
    validation = floquet.workflow.internal.validationStage(config);
    verifyEqual(testCase, validation.SourceDaughterSHA256, ...
        floquet.workflow.internal.FloquetFileSHA256( ...
        config.Files.Daughters));
    verifyEqual(testCase, validation.GenericDaughterChecks.Status, ...
        'valid-no-daughter-continuation-applied');
    verifyFalse(testCase, validation.Accepted);
    verifyEqual(testCase, validation.Status, ...
        'rejected-no-evidence-backed-daughter-ray');
    verifyTrue(testCase, isfile(config.Files.ValidationSummary));
end

function testExportOnlyCreatesMissingViews(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    results = SyntheticBranch(4);
    save(config.ParentBranchFile, 'results');
    config.ExpectedParentSHA256 = ...
        floquet.workflow.internal.FloquetFileSHA256( ...
        config.ParentBranchFile);
    config.AnalysisOptions = MockAnalysisOptions();
    floquet.workflow.internal.discoveryStage(config);
    delete(config.Files.CandidateInventory);
    delete(config.Files.RejectedPoints);
    delete(config.Files.RejectedIntervals);
    config.Discovery.ExportOnly = true;
    floquet.workflow.internal.discoveryStage(config);
    files = {config.Files.CandidateInventory, ...
        config.Files.RejectedPoints, config.Files.RejectedIntervals};
    verifyTrue(testCase, all(cellfun(@isfile, files)));
    floquet.workflow.internal.discoveryStage(config);
end

function testDiscoveryDiskArtifactIsEnriched(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    results = SyntheticBranch(6);
    save(config.ParentBranchFile, 'results');
    config.ExpectedParentSHA256 = ...
        floquet.workflow.internal.FloquetFileSHA256( ...
        config.ParentBranchFile);
    config.AnalysisOptions = MockAnalysisOptions();

    returned = floquet.workflow.internal.discoveryStage(config);
    loaded = load(config.Files.Discovery, 'analysis', 'stage');
    verifyTrue(testCase, isfield(loaded, 'stage'));
    verifyTrue(testCase, isfield(loaded.analysis, 'workflowStage'));
    verifyEqual(testCase, loaded.analysis.workflowStage.Name, ...
        'parent-only-full-branch-discovery');
    verifyTrue(testCase, isfield(loaded.analysis.candidates, 'CandidateID'));
    verifyEqual(testCase, {loaded.analysis.candidates.CandidateID}, ...
        {returned.candidates.CandidateID});
    verifyTrue(testCase, any(strcmp( ...
        {loaded.analysis.candidates.CandidateID}, ...
        'plus1_c0003_c0004')));
end

function testRepeatedModeUsesResolverAndCustomCorrectorContract(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    record = BaseRefinementRecord();
    record.CandidateID = 'plus1_c0002_c0003';
    record.CandidateType = '+1';
    record.CandidateCount = 2;
    record.Diagnostics = struct('branchSwitchReady', false);
    refinementReport = struct('Records', record);
    InstallSyntheticDiscovery(config);
    SaveRefinementReport(config, refinementReport);
    config.BranchSwitch.DirectionResolver = @FakeDirectionResolver;
    config.BranchSwitch.CorrectorFunction = @FakeCorrector;
    config.BranchSwitch.Amplitudes = [];

    report = floquet.workflow.internal.seedSearchStage(config);
    verifyEqual(testCase, report.CandidateRecords.Status, ...
        'unsupported-no-configured-rays');
    verifyEqual(testCase, report.CandidateRecords.DirectionIDs, ...
        {'resolved_physical_mode'});

    context = struct('Record', record, 'Direction', struct(), ...
        'X', zeros(13, 1), 'E', [zeros(8, 1); 1], ...
        'Parameters', ones(7, 1), 'PredictorInfo', struct(), ...
        'CorrectorOptions', struct(), 'Amplitude', 1e-3, 'Sign', 1);
    [corrected, info] = ...
        floquet.workflow.internal.ApplyFloquetBranchCorrector( ...
        context, @FakeCorrector);
    verifySize(testCase, corrected, [22 1]);
    verifyTrue(testCase, info.accepted);
end

function testStageThreeRejectsUnrefinedDiagnosticDirection(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallSyntheticDiscovery(config);
    record = BaseRefinementRecord();
    record.CandidateID = 'plus1_c0002_c0003';
    record.CandidateType = '+1';
    X = zeros(13, 1);
    X(2) = 1;
    E = [(0.05:0.10:0.75).'; 1];
    record.Diagnostics = struct('branchSwitchReady', true, ...
        'eigenData', struct('Eigenvector', ones(12, 1), ...
            'Multiplier', 1), ...
        'X', X, 'E', E, ...
        'parameters', [10; 20; Inf; 1; 0; 0.5; 1]);
    SaveRefinementReport(config, struct('Records', record));
    config.BranchSwitch.Amplitudes = 1e-3;
    config.BranchSwitch.Signs = 1;

    report = floquet.workflow.internal.seedSearchStage(config);

    verifyEqual(testCase, numel(report.Attempts), 1);
    verifyFalse(testCase, report.Attempts.Accepted);
    verifyEqual(testCase, report.Attempts.ErrorIdentifier, ...
        'PredictBranchDirection:UnrefinedDirection');
    verifyTrue(testCase, ...
        report.Reproducibility.RequireProductionReadyPredictor);
end

function testStageFourPreflightsPerRayArtifactsBeforeInventoryOverwrite(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    candidateID = 'plus1_c0002_c0003';
    directionID = 'physical_mode';
    attempts = repmat(struct('CandidateID', candidateID, ...
        'DirectionID', directionID, 'Sign', 1, 'Amplitude', 1e-3, ...
        'Accepted', true), 1, 2);
    attempts(2).Amplitude = 2e-3;
    seedReport = struct('Attempts', attempts, ...
        'CandidateRecords', struct([]));
    InstallSyntheticDiscovery(config);
    SaveRefinementReport(config, struct('Records', struct([])));
    SaveSeedReport(config, seedReport);
    config = SelectAllEligibleRays(config);

    rayKey = sprintf('%s__%s__sign_%+d', candidateID, directionID, 1);
    rayKey = regexprep(rayKey, '[^A-Za-z0-9_.-]+', '_');
    outputFile = fullfile(config.Files.DaughterDirectory, candidateID, ...
        rayKey, 'branch.mat');
    mkdir(fileparts(outputFile));
    marker = true;
    save(outputFile, 'marker');

    config.Continuation.Enabled = true;
    config.OverwriteResults = true;
    config.Continuation.Overwrite = false;
    verifyError(testCase, @() ...
        floquet.workflow.internal.continuationStage(config), ...
        'TemplateExperiment:DaughterArtifactExists');
    verifyFalse(testCase, isfile(config.Files.Daughters));
end

function testStageFourRetainsRejectedArtifactWhenCallerRequestsThrow(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    attempts = ContinuationAttempts();
    seedReport = struct('Attempts', attempts, ...
        'CandidateRecords', struct([]));
    InstallSyntheticDiscovery(config);
    SaveRefinementReport(config, struct('Records', struct([])));
    SaveSeedReport(config, seedReport);
    config = SelectAllEligibleRays(config);

    config.Continuation.Enabled = true;
    config.Continuation.Options = struct( ...
        'ContinuationFunction', @FakeStageContinuation, ...
        'ValidationFunction', @FakeStageValidation, ...
        'MinimumOutputPoints', 4, ...
        'ThrowOnFailure', true);

    report = floquet.workflow.internal.continuationStage(config);

    verifyEqual(testCase, numel(report.Records), 1);
    record = report.Records(1);
    verifyFalse(testCase, record.Accepted);
    verifyEqual(testCase, record.Status, ...
        'rejected-continuation-validation');
    verifyNotEmpty(testCase, record.OutputFile);
    verifyTrue(testCase, isfile(record.OutputFile));
    verifyEqual(testCase, record.OutputSHA256, ...
        floquet.workflow.internal.FloquetFileSHA256(record.OutputFile));
    saved = load(record.OutputFile, 'info');
    verifyFalse(testCase, saved.info.options.ThrowOnFailure);
    verifyFalse(testCase, saved.info.validationEvidenceComplete);
    verifyFalse(testCase, ...
        saved.info.validationAuthority.scientificAcceptanceEligible);
end

function testStageFourRequiresConfirmedSHASelectedRays(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    config.Continuation.Enabled = true;
    verifyError(testCase, @() ...
        floquet.workflow.internal.continuationStage(config), ...
        'TemplateExperiment:ContinuationNotConfirmed');

    config.Continuation.Confirmed = true;
    verifyError(testCase, @() ...
        floquet.workflow.internal.continuationStage(config), ...
        'TemplateExperiment:RaySelectionsRequired');

    InstallSyntheticDiscovery(config);
    SaveRefinementReport(config, struct('Records', struct([])));
    SaveSeedReport(config, struct('Attempts', ContinuationAttempts(), ...
        'CandidateRecords', struct([])));
    config = SelectAllEligibleRays(config);
    config.Continuation.Enabled = true;
    config.Continuation.RaySelections.SourceSeedSHA256 = repmat('0', 1, 64);
    verifyError(testCase, @() ...
        floquet.workflow.internal.continuationStage(config), ...
        'TemplateExperiment:RaySelectionSeedMismatch');
end

function testStageFourCatalogAndCheckpointResumeBetweenRays(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallSyntheticDiscovery(config);
    SaveRefinementReport(config, struct('Records', struct([])));
    SaveSeedReport(config, struct('Attempts', TwoRayAttempts(), ...
        'CandidateRecords', struct([])));
    catalog = floquet.workflow.internal.InspectFloquetDaughterRays(config);
    verifyEqual(testCase, numel(catalog.Rows), 2);
    verifyTrue(testCase, all([catalog.Rows.Eligible]));
    verifyEqual(testCase, catalog.Rows(1).DistinctAttemptIndices, [1 2]);
    verifyEqual(testCase, catalog.Rows(2).DistinctAttemptIndices, [3 4]);

    config = SelectAllEligibleRays(config);
    config.Continuation.Enabled = true;
    config.Continuation.DeleteCheckpointOnSuccess = false;
    config.Continuation.ControlFcn = @(event) event.localIndex <= 1;
    config.Continuation.Options = struct( ...
        'ContinuationFunction', @FakeStageContinuation, ...
        'ValidationFunction', @FakeStageValidation, ...
        'MinimumOutputPoints', 4);

    paused = floquet.workflow.internal.continuationStage(config);
    verifyEqual(testCase, paused.Status, 'paused-between-selected-rays');
    verifyFalse(testCase, paused.FinalArtifactWritten);
    verifyEqual(testCase, numel(paused.Records), 1);
    verifyTrue(testCase, isfile(config.Continuation.CheckpointFile));
    verifyFalse(testCase, isfile(config.Files.Daughters));
    firstSHA = paused.Records(1).OutputSHA256;

    config.Continuation.ControlFcn = [];
    config.Continuation.ResumeFromCheckpoint = true;
    completed = floquet.workflow.internal.continuationStage(config);
    verifyTrue(testCase, completed.FinalArtifactWritten);
    verifyTrue(testCase, completed.Checkpoint.Resumed);
    verifyEqual(testCase, numel(completed.Records), 2);
    verifyEqual(testCase, completed.Records(1).OutputSHA256, firstSHA);
    verifyTrue(testCase, isfile(config.Files.Daughters));
    verifyTrue(testCase, isfile(config.Continuation.CheckpointFile));
end

function testStageFourResumeRejectsChangedCompletedRay(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallSyntheticDiscovery(config);
    SaveRefinementReport(config, struct('Records', struct([])));
    SaveSeedReport(config, struct('Attempts', TwoRayAttempts(), ...
        'CandidateRecords', struct([])));
    config = SelectAllEligibleRays(config);
    config.Continuation.Enabled = true;
    config.Continuation.DeleteCheckpointOnSuccess = false;
    config.Continuation.ControlFcn = @(event) event.localIndex <= 1;
    config.Continuation.Options = struct( ...
        'ContinuationFunction', @FakeStageContinuation, ...
        'ValidationFunction', @FakeStageValidation, ...
        'MinimumOutputPoints', 4);
    paused = floquet.workflow.internal.continuationStage(config);
    changed = true;
    save(paused.Records(1).OutputFile, 'changed');

    config.Continuation.ControlFcn = [];
    config.Continuation.ResumeFromCheckpoint = true;
    verifyError(testCase, @() ...
        floquet.workflow.internal.continuationStage(config), ...
        'TemplateExperiment:ContinuationCheckpointOutput');
    verifyFalse(testCase, isfile(config.Files.Daughters));
end

function testStageFourRecoversAtomicallySavedActiveRay(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallSyntheticDiscovery(config);
    SaveRefinementReport(config, struct('Records', struct([])));
    SaveSeedReport(config, struct('Attempts', TwoRayAttempts(), ...
        'CandidateRecords', struct([])));
    config = SelectAllEligibleRays(config);
    config.Continuation.Enabled = true;
    config.Continuation.DeleteCheckpointOnSuccess = false;
    config.Continuation.ControlFcn = @(~) false;
    config.Continuation.Options = struct( ...
        'ContinuationFunction', @FakeStageContinuation, ...
        'ValidationFunction', @FakeStageValidation, ...
        'MinimumOutputPoints', 4);
    paused = floquet.workflow.internal.continuationStage(config);
    verifyEmpty(testCase, paused.Records);

    WriteSelectedRayArtifact(config, config.Continuation.RaySelections(1));
    loaded = load(config.Continuation.CheckpointFile, 'checkpoint');
    checkpoint = loaded.checkpoint;
    checkpoint.ActiveRayIndex = 1;
    checkpoint.NextRayIndex = 1;
    save(config.Continuation.CheckpointFile, 'checkpoint', '-v7.3');

    config.Continuation.ControlFcn = [];
    config.Continuation.ResumeFromCheckpoint = true;
    completed = floquet.workflow.internal.continuationStage(config);
    verifyEqual(testCase, numel(completed.Records), 2);
    verifyTrue(testCase, endsWith(completed.Records(1).Status, ...
        '-recovered-from-checkpoint'));
    verifyTrue(testCase, isfile(completed.Records(1).OutputFile));
end

function testStageFiveAcceptsStrictEvidenceAndInfiniteInertia(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    branchFile = fullfile(fileparts(config.Files.Daughters), ...
        'valid_branch.mat');
    [results, info] = EvidenceArtifact();
    SaveEvidenceArtifact(branchFile, results, info);
    daughterReport = struct('ContinuationEnabled', true, ...
        'Records', EvidenceRecord('valid-ray', branchFile, true));
    InstallChainThroughSeeds(config);
    SaveDaughterReport(config, daughterReport);

    report = floquet.workflow.internal.validationStage(config);
    evidence = report.GenericDaughterChecks.RayEvidence;

    verifyTrue(testCase, evidence.ResultStructureValid);
    verifyTrue(testCase, evidence.ValidationEvidenceComplete);
    verifyTrue(testCase, evidence.EvidenceAccepted);
    verifyEqual(testCase, ...
        report.GenericDaughterChecks.EvidenceBackedRayCount, 1);
    verifyTrue(testCase, report.Accepted);
    verifyEqual(testCase, report.Status, ...
        'accepted-generic-evidence-no-held-out-identity-claim');
end

function testStageFiveRejectsMalformedMatricesAndTruthyFlags(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    [baseResults, baseInfo] = EvidenceArtifact();
    mutationNames = { ...
        'wrong-row-count', 'complex-results', 'nonfinite-state', ...
        'unsupported-infinite-parameter', 'incomplete-evidence', ...
        'truthy-info-accepted', 'truthy-mask', ...
        'truthy-validation-accepted', 'truthy-geometry', ...
        'truthy-inventory-accepted'};
    records = repmat(EvidenceRecord('', '', true), ...
        1, numel(mutationNames));
    for k = 1:numel(mutationNames)
        results = baseResults;
        info = baseInfo;
        inventoryAccepted = true;
        switch mutationNames{k}
            case 'wrong-row-count'
                results = [results; zeros(1, size(results, 2))]; %#ok<AGROW>
            case 'complex-results'
                results(1, 1) = 1i;
            case 'nonfinite-state'
                results(4, 1) = NaN;
            case 'unsupported-infinite-parameter'
                results(23, 1) = Inf;
            case 'incomplete-evidence'
                info.validationEvidenceComplete = false;
            case 'truthy-info-accepted'
                info.accepted = 2;
            case 'truthy-mask'
                info.outputValidatedMask = [1 2 1];
            case 'truthy-validation-accepted'
                info.outputValidation(2).accepted = 2;
            case 'truthy-geometry'
                info.daughterGeometry.accepted = 0.5;
            case 'truthy-inventory-accepted'
                inventoryAccepted = 2;
        end
        branchFile = fullfile(fileparts(config.Files.Daughters), ...
            [mutationNames{k}, '.mat']);
        SaveEvidenceArtifact(branchFile, results, info);
        records(k) = EvidenceRecord(mutationNames{k}, branchFile, ...
            inventoryAccepted);
    end
    daughterReport = struct('ContinuationEnabled', true, ...
        'Records', records);
    InstallChainThroughSeeds(config);
    SaveDaughterReport(config, daughterReport);

    report = floquet.workflow.internal.validationStage(config);
    evidence = report.GenericDaughterChecks.RayEvidence;

    verifyFalse(testCase, any([evidence.EvidenceAccepted]));
    verifyEqual(testCase, ...
        report.GenericDaughterChecks.EvidenceBackedRayCount, 0);
    verifyFalse(testCase, evidence(1).ResultStructureValid);
    verifyFalse(testCase, evidence(2).ResultStructureValid);
    verifyFalse(testCase, evidence(3).ResultStructureValid);
    verifyFalse(testCase, evidence(4).ResultStructureValid);
    verifyFalse(testCase, evidence(5).ValidationEvidenceComplete);
    verifyFalse(testCase, evidence(7).OutputValidationContractValid);
    verifyFalse(testCase, evidence(8).OutputValidationContractValid);
end

function testStageFiveRejectsTruthyContinuationEnabled(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    branchFile = fullfile(fileparts(config.Files.Daughters), ...
        'valid_branch_invalid_inventory.mat');
    [results, info] = EvidenceArtifact();
    SaveEvidenceArtifact(branchFile, results, info);
    daughterReport = struct('ContinuationEnabled', 2, ...
        'Records', EvidenceRecord('invalid-inventory-ray', ...
            branchFile, true));
    InstallChainThroughSeeds(config);
    SaveDaughterReport(config, daughterReport);

    report = floquet.workflow.internal.validationStage(config);

    verifyEqual(testCase, report.GenericDaughterChecks.Status, ...
        'invalid-daughter-inventory-contract');
    verifyFalse(testCase, ...
        report.GenericDaughterChecks.ContinuationEnabledFlagValid);
    verifyFalse(testCase, ...
        report.GenericDaughterChecks.RayEvidence.EvidenceAccepted);
end

function testStageFiveRejectsReplacedDaughterBranchArtifact(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    branchFile = fullfile(fileparts(config.Files.Daughters), ...
        'frozen_daughter.mat');
    [results, info] = EvidenceArtifact();
    SaveEvidenceArtifact(branchFile, results, info);
    daughterReport = struct('ContinuationEnabled', true, ...
        'Records', EvidenceRecord('frozen-ray', branchFile, true));
    InstallChainThroughDaughters(config, daughterReport);
    replacement = 1;
    save(branchFile, 'replacement');

    verifyError(testCase, @() ...
        floquet.workflow.internal.validationStage(config), ...
        'TemplateExperiment:ArtifactHashMismatch');
    verifyFalse(testCase, isfile(config.Files.Validation));
end

function testStageFiveAllowsRejectedRecordWithoutOutputArtifact(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    record = EvidenceRecord('rejected-no-output', '', false);
    daughterReport = struct('ContinuationEnabled', true, 'Records', record);
    InstallChainThroughDaughters(config, daughterReport);

    report = floquet.workflow.internal.validationStage(config);

    verifyFalse(testCase, report.Accepted);
    verifyFalse(testCase, ...
        report.GenericDaughterChecks.RayEvidence.OutputFileExists);
    verifyTrue(testCase, isfile(config.Files.Validation));
end

function testSHA256KnownVectorAndMutation(testCase)
    root = tempname;
    mkdir(root);
    cleanup = onCleanup(@() RemoveDirectory(root));
    filename = fullfile(root, 'known-vector.bin');
    WriteBytes(filename, uint8('abc'));
    expected = [ ...
        'ba7816bf8f01cfea414140de5dae2223' ...
        'b00361a396177a9cb410ff61f20015ad'];
    verifyEqual(testCase, ...
        floquet.workflow.internal.FloquetFileSHA256(filename), expected);
    WriteBytes(filename, uint8('abcd'));
    verifyNotEqual(testCase, ...
        floquet.workflow.internal.FloquetFileSHA256(filename), expected);
end

function testArtifactPreflightRejectsAliasesEvenWithOverwrite(testCase)
    root = tempname;
    mkdir(fullfile(root, 'nested'));
    cleanup = onCleanup(@() RemoveDirectory(root));
    output = fullfile(root, 'artifact.mat');
    alias = fullfile(root, 'nested', '..', 'artifact.mat');
    verifyError(testCase, @() ...
        floquet.workflow.internal.PreflightFloquetArtifacts( ...
        {output, alias}, true), ...
        'TemplateExperiment:DuplicateArtifactOutput');
    protected = fullfile(root, 'parent.mat');
    parent = 1;
    save(protected, 'parent');
    protectedAlias = fullfile(root, 'nested', '..', 'parent.mat');
    verifyError(testCase, @() ...
        floquet.workflow.internal.PreflightFloquetArtifacts( ...
        {protectedAlias}, true, {protected}), ...
        'TemplateExperiment:ArtifactAliasesProtectedInput');
end

function testStageOutputCannotAliasParentWhenOverwriteEnabled(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallSyntheticDiscovery(config);
    config.Files.Refinement = config.ParentBranchFile;
    config.OverwriteResults = true;
    verifyError(testCase, @() ...
        floquet.workflow.internal.refinementStage(config), ...
        'TemplateExperiment:ArtifactAliasesProtectedInput');
end

function testStageTwoRejectsIncompleteDiscoveryCoverage(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    analysis = SyntheticDiscoveryAnalysis(config, struct([]));
    analysis.sampleIndices = [1 2 4];
    save(config.Files.Discovery, 'analysis');
    verifyError(testCase, @() ...
        floquet.workflow.internal.refinementStage(config), ...
        'TemplateExperiment:DiscoveryNotFullBranch');
end

function testDiscoveryRejectsTamperedAuthorityAndCoverageFlags(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    baseline = SyntheticDiscoveryAnalysis(config, struct([]));
    mutations = { ...
        'analysis-scientific-authority', ...
        'analysis-full-parent', ...
        'analysis-full-ordered', ...
        'coverage-full-parent', ...
        'coverage-full-ordered', ...
        'provenance-full-parent', ...
        'provenance-full-ordered', ...
        'provenance-scientific-authority', ...
        'provenance-coverage-full-parent', ...
        'provenance-coverage-full-ordered', ...
        'stage-scientific-use', ...
        'compute-function-authority'};
    for k = 1:numel(mutations)
        analysis = baseline;
        switch mutations{k}
            case 'analysis-scientific-authority'
                analysis.scientificAuthority = true;
            case 'analysis-full-parent'
                analysis.fullParentCoverage = false;
            case 'analysis-full-ordered'
                analysis.fullOrderedParentCoverage = false;
            case 'coverage-full-parent'
                analysis.coverage.fullParentCoverage = false;
            case 'coverage-full-ordered'
                analysis.coverage.fullOrderedParentCoverage = false;
            case 'provenance-full-parent'
                analysis.provenance.fullParentCoverage = false;
            case 'provenance-full-ordered'
                analysis.provenance.orderedParentCoverage = false;
            case 'provenance-scientific-authority'
                analysis.provenance.scientificAuthority = true;
            case 'provenance-coverage-full-parent'
                analysis.provenance.coverage.fullParentCoverage = false;
            case 'provenance-coverage-full-ordered'
                analysis.provenance.coverage.fullOrderedParentCoverage = false;
            case 'stage-scientific-use'
                analysis.workflowStage.ScientificUseAllowed = true;
            case 'compute-function-authority'
                analysis.provenance.computeFunction = 'ComputeFloquetFDM';
        end
        save(config.Files.Discovery, 'analysis');
        verifyError(testCase, @() ...
            floquet.workflow.internal.ValidateFloquetArtifactChain( ...
            config, 'discovery'), ...
            'TemplateExperiment:DiscoveryContract');
    end
    analysis = baseline;
    save(config.Files.Discovery, 'analysis');
    chain = floquet.workflow.internal.ValidateFloquetArtifactChain( ...
        config, 'discovery');
    verifyEqual(testCase, chain.DiscoveryAuthority, ...
        'test-only-nonproduction-authority');
end

function testNonproductionDiscoveryNeedsExplicitTestGate(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallSyntheticDiscovery(config);
    config = rmfield(config, 'Testing');
    verifyError(testCase, @() ...
        floquet.workflow.internal.ValidateFloquetArtifactChain( ...
        config, 'discovery'), ...
        'TemplateExperiment:NonProductionDiscovery');
end

function testProductionDiscoveryRejectsTamperedEvaluatorIdentity(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    analysis = SyntheticDiscoveryAnalysis(config, struct([]));
    [production, evaluatorIdentity] = ...
        floquet.internal.provenance.evaluatorIdentity( ...
            @floquet.computeFDM, 'floquet.computeFDM');
    verifyTrue(testCase, production);
    analysis.provenance.computeFunction = 'floquet.computeFDM';
    analysis.provenance.productionEvaluator = true;
    analysis.provenance.computeEvaluatorIdentity = evaluatorIdentity;
    analysis.provenance.scientificAuthority = true;
    analysis.scientificAuthority = true;
    analysis.workflowStage.Authority = ...
        'production-scientific-authority';
    analysis.workflowStage.ScientificUseAllowed = true;

    [~, authority] = ...
        floquet.workflow.internal.ValidateFloquetDiscoveryArtifact( ...
        analysis, config, true);
    verifyEqual(testCase, authority, ...
        'production-scientific-authority');

    mutations = { ...
        @(value) SetField(value, 'ProductionEvaluator', false), ...
        @(value) SetField(value, 'Function', 'ShadowEvaluator'), ...
        @(value) SetField(value, 'NameMatches', false), ...
        @(value) SetField(value, 'FileMatches', false), ...
        @(value) SetField(value, 'ExpectedFile', config.ParentBranchFile), ...
        @(value) SetField(value, 'ActualFile', config.ParentBranchFile)};
    for k = 1:numel(mutations)
        tampered = analysis;
        tampered.provenance.computeEvaluatorIdentity = mutations{k}( ...
            tampered.provenance.computeEvaluatorIdentity);
        verifyError(testCase, @() ...
            floquet.workflow.internal.ValidateFloquetDiscoveryArtifact( ...
            tampered, config, true), ...
            'TemplateExperiment:DiscoveryContract');
    end
end

function testExpectedParentSHA256IsEnforced(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    config.ExpectedParentSHA256 = repmat('0', 1, 64);
    verifyError(testCase, @() ...
        floquet.workflow.internal.FloquetParentIdentity(config), ...
        'TemplateExperiment:ParentFingerprintMismatch');
end

function testRecursiveChainRejectsMutatedDiscovery(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallChainThroughSeeds(config);
    loaded = load(config.Files.Discovery, 'analysis');
    analysis = loaded.analysis;
    analysis.intentionalMutation = true;
    save(config.Files.Discovery, 'analysis');
    verifyError(testCase, @() ...
        floquet.workflow.internal.continuationStage(config), ...
        'TemplateExperiment:ArtifactHashMismatch');
end

function testRecursiveChainRejectsMutatedRefinement(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallChainThroughSeeds(config);
    loaded = load(config.Files.Refinement, 'refinementReport');
    refinementReport = loaded.refinementReport;
    refinementReport.intentionalMutation = true;
    save(config.Files.Refinement, 'refinementReport');
    verifyError(testCase, @() ...
        floquet.workflow.internal.continuationStage(config), ...
        'TemplateExperiment:ArtifactHashMismatch');
end

function testRecursiveChainRejectsCurrentParentMutation(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallChainThroughDaughters(config, struct( ...
        'ContinuationEnabled', false, 'Records', struct([])));
    loaded = load(config.ParentBranchFile);
    branch = loaded.branch;
    branch(1, 1) = branch(1, 1) + 1;
    save(config.ParentBranchFile, 'branch');
    verifyError(testCase, @() ...
        floquet.workflow.internal.validationStage(config), ...
        'TemplateExperiment:ParentFingerprintMismatch');
end

function testRayPreflightRejectsSanitizedOutputCollision(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallSyntheticDiscovery(config);
    SaveRefinementReport(config, struct('Records', struct([])));
    attempts = repmat(struct('CandidateID', 'plus1_c0001_c0002', ...
        'DirectionID', 'a+b', 'Sign', 1, 'Amplitude', 1e-3, ...
        'Accepted', true), 1, 4);
    attempts(2).Amplitude = 2e-3;
    attempts(3).DirectionID = 'a b';
    attempts(4).DirectionID = 'a b';
    attempts(4).Amplitude = 2e-3;
    SaveSeedReport(config, struct('Attempts', attempts, ...
        'CandidateRecords', struct([])));
    config = SelectAllEligibleRays(config);
    config.Continuation.Enabled = true;
    verifyError(testCase, @() ...
        floquet.workflow.internal.continuationStage(config), ...
        'TemplateExperiment:DuplicateArtifactOutput');
    verifyFalse(testCase, isfile(config.Files.Daughters));
end

function testHeldOutRejectedReportAndProvenanceAreRetained(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallChainThroughDaughters(config, struct( ...
        'ContinuationEnabled', false, 'Records', struct([])));
    reference = fullfile(fileparts(config.Files.Daughters), 'reference.mat');
    heldOutReference = 42;
    save(reference, 'heldOutReference');
    config.Validation.ReferenceDaughterBranchFiles = {reference};
    config.Validation.Function = @FakeHeldOutRejected;

    report = floquet.workflow.internal.validationStage(config);

    verifyFalse(testCase, report.HeldOutValidation.Accepted);
    verifyEqual(testCase, report.HeldOutValidation.Status, ...
        'rejected-held-out-evidence');
    verifyFalse(testCase, report.Accepted);
    provenance = report.HeldOutValidatorProvenance;
    verifyEqual(testCase, provenance.Callback.Function, ...
        'FakeHeldOutRejected');
    verifyTrue(testCase, provenance.Callback.FileBacked);
    verifyEqual(testCase, provenance.References.SHA256, ...
        floquet.workflow.internal.FloquetFileSHA256(reference));
    loaded = load(config.Files.Validation, 'validationReport');
    verifyFalse(testCase, loaded.validationReport.HeldOutValidation.Accepted);
    summary = readtable(config.Files.ValidationSummary);
    verifyTrue(testCase, ismember('HeldOutAccepted', ...
        summary.Properties.VariableNames));
    verifyFalse(testCase, any(summary.HeldOutAccepted));
end


function testOverallAcceptanceRequiresConfiguredHeldOutAcceptance(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    branchFile = fullfile(fileparts(config.Files.Daughters), ...
        'valid_branch_with_held_out.mat');
    [results, info] = EvidenceArtifact();
    SaveEvidenceArtifact(branchFile, results, info);
    daughterReport = struct('ContinuationEnabled', true, ...
        'Records', EvidenceRecord('valid-held-out-ray', branchFile, true));
    InstallChainThroughDaughters(config, daughterReport);
    reference = fullfile(fileparts(config.Files.Daughters), ...
        'independent_reference.mat');
    heldOutReference = 42;
    save(reference, 'heldOutReference');
    config.Validation.ReferenceDaughterBranchFiles = {reference};
    config.Validation.Function = @FakeHeldOutAccepted;

    report = floquet.workflow.internal.validationStage(config);

    verifyTrue(testCase, report.Accepted);
    verifyEqual(testCase, report.Status, ...
        'accepted-generic-and-held-out-validation');
    verifyTrue(testCase, report.HeldOutRequiredForAcceptance);
end

function testHeldOutValidatorExceptionIsRetained(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallChainThroughDaughters(config, struct( ...
        'ContinuationEnabled', false, 'Records', struct([])));
    config.Validation.Function = @FakeHeldOutException;
    report = floquet.workflow.internal.validationStage(config);
    verifyFalse(testCase, report.HeldOutValidation.Accepted);
    verifyEqual(testCase, report.HeldOutValidation.Status, ...
        'validator-exception');
    verifyTrue(testCase, isfile(config.Files.Validation));
end

function testHeldOutValidatorContractRejectsAmbiguousOutput(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallChainThroughDaughters(config, struct( ...
        'ContinuationEnabled', false, 'Records', struct([])));
    config.Validation.Function = @FakeHeldOutAmbiguous;
    verifyError(testCase, @() ...
        floquet.workflow.internal.validationStage(config), ...
        'TemplateExperiment:HeldOutReportContract');
end

function testValidationOutputCannotAliasHeldOutReference(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallChainThroughDaughters(config, struct( ...
        'ContinuationEnabled', false, 'Records', struct([])));
    reference = fullfile(fileparts(config.Files.Daughters), 'reference.mat');
    heldOutReference = 42;
    save(reference, 'heldOutReference');
    config.Validation.ReferenceDaughterBranchFiles = {reference};
    config.Validation.Function = @FakeHeldOutRejected;
    config.Files.Validation = reference;
    config.OverwriteResults = true;
    verifyError(testCase, @() ...
        floquet.workflow.internal.validationStage(config), ...
        'TemplateExperiment:ArtifactAliasesProtectedInput');
end

function testHeldOutReferenceCannotReuseParentOrUpstreamArtifact(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallChainThroughDaughters(config, struct( ...
        'ContinuationEnabled', false, 'Records', struct([])));
    config.Validation.Function = @FakeHeldOutRejected;
    prohibited = {config.ParentBranchFile, config.Files.Discovery, ...
        config.Files.Refinement, config.Files.Seeds, config.Files.Daughters};
    for k = 1:numel(prohibited)
        local = config;
        local.Validation.ReferenceDaughterBranchFiles = prohibited(k);
        verifyError(testCase, @() ...
            floquet.workflow.internal.validationStage(local), ...
            'TemplateExperiment:ReferenceNotIndependent');
    end
    verifyFalse(testCase, isfile(config.Files.Validation));
end

function testHeldOutReferenceCannotReuseGeneratedDaughterBranch(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    branchFile = fullfile(fileparts(config.Files.Daughters), ...
        'generated_daughter.mat');
    generated = 1;
    save(branchFile, 'generated');
    record = EvidenceRecord('generated-ray', branchFile, false);
    InstallChainThroughDaughters(config, struct( ...
        'ContinuationEnabled', true, 'Records', record));
    config.Validation.Function = @FakeHeldOutRejected;
    config.Validation.ReferenceDaughterBranchFiles = {branchFile};

    verifyError(testCase, @() ...
        floquet.workflow.internal.validationStage(config), ...
        'TemplateExperiment:ReferenceNotIndependent');
    verifyFalse(testCase, isfile(config.Files.Validation));
end

function testHeldOutReferenceMutationIsRejected(testCase)
    [config, cleanup] = SyntheticConfig(testCase); %#ok<ASGLU>
    InstallChainThroughDaughters(config, struct( ...
        'ContinuationEnabled', false, 'Records', struct([])));
    reference = fullfile(fileparts(config.Files.Daughters), 'reference.mat');
    heldOutReference = 42;
    save(reference, 'heldOutReference');
    config.Validation.ReferenceDaughterBranchFiles = {reference};
    config.Validation.Function = @FakeHeldOutMutatesReference;
    verifyError(testCase, @() ...
        floquet.workflow.internal.validationStage(config), ...
        'TemplateExperiment:ReferenceChangedDuringValidation');
    verifyFalse(testCase, isfile(config.Files.Validation));
end

function [config, cleanup] = SyntheticConfig(testCase)
    root = tempname;
    mkdir(root);
    cleanup = onCleanup(@() RemoveDirectory(root));
    parentFile = fullfile(root, 'parent.mat');
    branch = zeros(29, 4);
    save(parentFile, 'branch');
    config = ExperimentConfig(parentFile);
    config.ExperimentRoot = fullfile(testCase.TestData.FloquetRoot, ...
        'examples', 'blind_parent_profiles', 'synthetic_parent');
    config.FloquetRoot = '';
    config.OverwriteResults = false;
    config.Testing = struct('AllowNonProductionDiscovery', true);
    config.Selection.Confirmed = true;
    config.ParentBranchFile = parentFile;
    config.AnalysisOptions.CheckpointFile = fullfile(root, ...
        'floquet_scan_checkpoint.mat');
    config.Files.Discovery = fullfile(root, 'discovery.mat');
    config.Files.CandidateInventory = fullfile(root, 'candidate_inventory.csv');
    config.Files.RejectedPoints = fullfile(root, 'rejected_points.csv');
    config.Files.RejectedIntervals = fullfile(root, 'rejected_intervals.csv');
    config.Files.Refinement = fullfile(root, 'refinement.mat');
    config.Files.RefinementSummary = fullfile(root, 'refinement_summary.csv');
    config.Files.Seeds = fullfile(root, 'seeds.mat');
    config.Files.SeedAttempts = fullfile(root, 'seed_attempts.csv');
    config.Files.Daughters = fullfile(root, 'daughters.mat');
    config.Files.DaughterInventory = fullfile(root, 'daughter_inventory.csv');
    config.Files.DaughterDirectory = fullfile(root, 'branches');
    config.Continuation.CheckpointFile = fullfile(root, ...
        'daughter_continuation_checkpoint.mat');
    config.Files.DaughterCheckpoint = ...
        config.Continuation.CheckpointFile;
    config.Continuation.ResumeFromCheckpoint = false;
    config.Files.Validation = fullfile(root, 'validation.mat');
    config.Files.ValidationSummary = fullfile(root, 'validation_summary.csv');
end

function config = SelectAllEligibleRays(config)
    catalog = floquet.workflow.internal.InspectFloquetDaughterRays(config);
    rows = catalog.Rows([catalog.Rows.Eligible]);
    selections = repmat(struct('RayID', '', ...
        'SeedAttemptIndices', [], 'SeedAmplitudes', [], ...
        'SourceSeedSHA256', ''), 1, numel(rows));
    for k = 1:numel(rows)
        indices = rows(k).DistinctAttemptIndices(1:2);
        amplitudes = rows(k).DistinctAmplitudes(1:2);
        selections(k) = struct('RayID', rows(k).RayID, ...
            'SeedAttemptIndices', indices, ...
            'SeedAmplitudes', amplitudes, ...
            'SourceSeedSHA256', catalog.SourceSeedSHA256);
    end
    config.Continuation.Confirmed = true;
    config.Continuation.RaySelections = selections;
end

function options = MockAnalysisOptions()
    options = struct( ...
        'Verbose', false, ...
        'ComputeFunction', @MockFloquetEvaluator, ...
        'AllowNonProductionComputeFunction', true, ...
        'ContinuationParameterRow', 4, ...
        'ContinuationParameterName', 'synthetic coordinate');
end

function InstallSyntheticDiscovery(config, candidates)
    if nargin < 2
        candidates = struct([]);
    end
    analysis = SyntheticDiscoveryAnalysis(config, candidates);
    save(config.Files.Discovery, 'analysis');
end

function analysis = SyntheticDiscoveryAnalysis(config, candidates)
    identity = floquet.workflow.internal.FloquetParentIdentity(config);
    columns = 1:identity.PointCount;
    source = struct('kind', 'mat-file', ...
        'file', identity.CanonicalPath, ...
        'variable', identity.Variable, ...
        'fileSHA256', identity.FileSHA256, ...
        'branchSHA256', identity.BranchSHA256, ...
        'fullBranchPointCount', identity.PointCount, ...
        'selectedPointCount', identity.PointCount, ...
        'selectedColumns', columns);
    stage = struct('Name', 'parent-only-full-branch-discovery', ...
        'ParentBranchFile', identity.CanonicalPath, ...
        'ParentIdentity', identity, ...
        'FullBranchSelection', true, ...
        'Authority', 'test-only-nonproduction-authority', ...
        'ScientificUseAllowed', false);
    coverage = struct('fullParentPointCount', identity.PointCount, ...
        'selectedPointCount', identity.PointCount, ...
        'selectedColumns', columns, ...
        'selectionPreservesContinuationOrder', true, ...
        'fullParentCoverage', true, ...
        'fullOrderedParentCoverage', true);
    [~, evaluatorIdentity] = ...
        floquet.internal.provenance.evaluatorIdentity( ...
        @MockFloquetEvaluator, 'floquet.computeFDM');
    provenance = struct('parentDataOnly', true, ...
        'computeFunction', 'MockFloquetEvaluator', ...
        'productionEvaluator', false, ...
        'computeEvaluatorIdentity', evaluatorIdentity, ...
        'fullParentCoverage', true, ...
        'orderedParentCoverage', true, ...
        'scientificAuthority', false, ...
        'coverage', coverage);
    analysis = struct( ...
        'version', 'floquet-branch-analysis-v2', ...
        'algorithmID', ...
            'reduced-poincare-fdm-v2-canonical-branch-scan', ...
        'parentOnly', true, 'daughterDataLoaded', false, ...
        'coverage', coverage, ...
        'fullParentCoverage', true, ...
        'fullOrderedParentCoverage', true, ...
        'scientificAuthority', false, ...
        'source', source, ...
        'provenance', provenance, ...
        'branchIndices', columns, 'sampleIndices', columns, ...
        'states', zeros(13, identity.PointCount), ...
        'candidates', candidates, ...
        'rejectedReport', struct('points', struct([]), ...
            'intervals', struct([])), ...
        'workflowStage', stage);
    analysis.states(1, :) = columns;
end

function value = SetField(value, field, replacement)
    value.(field) = replacement;
end

function SaveRefinementReport(config, refinementReport)
    source = char(java.io.File( ...
        config.Files.Discovery).getCanonicalPath());
    refinementReport.WorkflowStage = 'critical-orbit-confirmation';
    refinementReport.SourceDiscoveryFile = source;
    refinementReport.SourceDiscoverySHA256 = ...
        floquet.workflow.internal.FloquetFileSHA256(source);
    save(config.Files.Refinement, 'refinementReport');
end

function SaveSeedReport(config, seedReport)
    source = char(java.io.File( ...
        config.Files.Refinement).getCanonicalPath());
    seedReport.WorkflowStage = 'local-daughter-seed-search';
    seedReport.SourceRefinementFile = source;
    seedReport.SourceRefinementSHA256 = ...
        floquet.workflow.internal.FloquetFileSHA256(source);
    save(config.Files.Seeds, 'seedReport');
end

function SaveDaughterReport(config, daughterReport)
    source = char(java.io.File(config.Files.Seeds).getCanonicalPath());
    daughterReport.WorkflowStage = 'continued-daughter-branch-candidates';
    daughterReport.SourceSeedFile = source;
    daughterReport.SourceSeedSHA256 = ...
        floquet.workflow.internal.FloquetFileSHA256(source);
    save(config.Files.Daughters, 'daughterReport');
end

function InstallChainThroughSeeds(config)
    InstallSyntheticDiscovery(config);
    SaveRefinementReport(config, struct('Records', struct([])));
    SaveSeedReport(config, struct('Attempts', struct([]), ...
        'CandidateRecords', struct([])));
end

function InstallChainThroughDaughters(config, daughterReport)
    InstallChainThroughSeeds(config);
    SaveDaughterReport(config, daughterReport);
end

function WriteBytes(filename, bytes)
    fileID = fopen(filename, 'wb');
    if fileID < 0
        error('TestFixture:FileOpen', 'Could not open fixture file.');
    end
    cleanup = onCleanup(@() fclose(fileID));
    fwrite(fileID, bytes, 'uint8');
    clear cleanup
end

function attempts = ContinuationAttempts()
    critical = zeros(22, 1);
    critical(2) = 1;
    critical(14:21) = (0.1:0.1:0.8).';
    critical(22) = 1;
    direction = zeros(12, 1);
    direction(1) = 1;
    parameters = [10; 20; Inf; 1; 0; 0.5; 1];
    predictor = struct('zBase', critical, 'directionQ', direction, ...
        'stateScale', ones(12, 1));
    attempts = repmat(struct( ...
        'CandidateID', 'plus1_c0002_c0003', ...
        'DirectionID', 'physical_mode', 'Sign', 1, ...
        'Amplitude', 1e-3, 'Accepted', true, ...
        'CorrectedSolution', critical, 'PredictorInfo', predictor, ...
        'CorrectorInfo', struct(), 'Parameters', parameters, ...
        'Status', 'accepted-corrected-seed'), 1, 2);
    attempts(1).CorrectedSolution(1) = 0.01;
    attempts(2).Amplitude = 2e-3;
    attempts(2).CorrectedSolution(1) = 0.02;
end

function attempts = TwoRayAttempts()
    first = ContinuationAttempts();
    second = first;
    for k = 1:numel(second)
        second(k).DirectionID = 'physical_mode_2';
    end
    attempts = [first second];
end

function WriteSelectedRayArtifact(config, selection)
    loaded = load(config.Files.Seeds, 'seedReport');
    attempts = loaded.seedReport.Attempts(selection.SeedAttemptIndices);
    first = attempts(1);
    second = attempts(2);
    options = config.Continuation.Options;
    options.CriticalSolution = first.PredictorInfo.zBase;
    options.Direction = first.PredictorInfo.directionQ;
    options.SectionScale = first.PredictorInfo.stateScale;
    options.RequireSameRay = true;
    options.SaveResult = true;
    options.ThrowOnFailure = false;
    options.Overwrite = false;
    rayFolder = regexprep(selection.RayID, '[^A-Za-z0-9_.-]+', '_');
    candidateFolder = regexprep(first.CandidateID, ...
        '[^A-Za-z0-9_.-]+', '_');
    options.OutputFile = fullfile(config.Files.DaughterDirectory, ...
        candidateFolder, rayFolder, 'branch.mat');
    floquet.continueDaughterBranch(first.CorrectedSolution, ...
        second.CorrectedSolution, first.Parameters, options);
end

function [results, flags, info] = FakeStageContinuation(z1, z2, Para, ~, ~, ~)
    z3 = z2 + 0.5 * (z2 - z1);
    results = [[z1; Para], [z2; Para], [z3; Para]];
    flags = ["synthetic complete", "synthetic complete"];
    info = struct('fixture', true);
end

function report = FakeStageValidation(solution, ~, options)
    topology = floquet.internal.events.classifyTopology( ...
        solution(14:22), options);
    report = struct('accepted', true, 'status', 'accepted', ...
        'rejectionReasons', {{}}, 'periodicResidualNormInf', 0, ...
        'mapInfo', struct('timingResidualNormInf', 0, ...
            'eventTopology', topology));
end

function [results, info] = EvidenceArtifact()
    results = zeros(29, 3);
    results(22, :) = 1;
    results(23:29, :) = repmat([10; 20; Inf; 1; 0; 0.5; 1], 1, 3);
    info = struct();
    info.accepted = true;
    info.validationEvidenceComplete = true;
    info.pointCount = 3;
    info.outputValidatedMask = true(1, 3);
    info.outputValidation = repmat(struct('accepted', true), 1, 3);
    info.daughterGeometry = struct('checked', true, 'accepted', true, ...
        'sameRayAlignedCount', 3);
    info.gaitNames = {'synthetic', 'synthetic', 'synthetic'};
    info.gaitAbbreviations = {'S', 'S', 'S'};
end

function record = EvidenceRecord(rayID, outputFile, accepted)
    outputSHA256 = '';
    if ~isempty(outputFile) && isfile(outputFile)
        outputSHA256 = ...
            floquet.workflow.internal.FloquetFileSHA256(outputFile);
    end
    record = struct('RayID', rayID, 'Status', 'accepted', ...
        'Accepted', accepted, 'OutputFile', outputFile, ...
        'OutputSHA256', outputSHA256);
end

function SaveEvidenceArtifact(filename, results, info)
    folder = fileparts(filename);
    if ~isfolder(folder)
        mkdir(folder);
    end
    save(filename, 'results', 'info');
end

function record = BaseRefinementRecord()
    record = struct('CandidateID', '', 'CandidateType', '', ...
        'CandidateCount', 1, 'Candidate', struct(), ...
        'GroupCandidates', struct([]), 'Solution', [], ...
        'Diagnostics', struct(), 'Accepted', true, ...
        'ChartCheck', struct(), 'NearbyFoldWarning', false, ...
        'Status', 'accepted-refined-critical-orbit', ...
        'ErrorIdentifier', '', 'Message', '');
end

function branch = SyntheticBranch(pointCount)
    coordinate = 1:pointCount;
    branch = zeros(29, pointCount);
    branch(1, :) = 2;
    branch(2, :) = coordinate;
    branch(4:13, :) = repmat((0.04:0.01:0.13).', 1, pointCount);
    branch(4, :) = coordinate;
    branch(14:21, :) = repmat((0.05:0.10:0.75).', 1, pointCount);
    branch(22, :) = 1;
    branch(23:29, :) = 1;
    branch(25, :) = Inf;
end

function [matrix, multipliers, vectors, detail] = ...
        MockFloquetEvaluator(solution, ~, options)
    eventTimes = [(0.05:0.10:0.75).'; 1];
    topology = floquet.internal.events.classifyTopology(eventTimes, options);
    critical = 0.65 + 0.10 * solution(4);
    multipliers = [critical; linspace(-0.8, 0.4, 11).'];
    matrix = diag(multipliers);
    vectors = eye(12);
    detail = struct( ...
        'accepted', true, 'valid', true, 'status', 'accepted', ...
        'rejectionReasons', {{}}, ...
        'mapDefinition', 'reduced apex-to-apex Poincare return map', ...
        'reducedStateIndices', [1 2 4:13], ...
        'baseSolvedEventTimes', eventTimes, ...
        'referenceTopology', topology, ...
        'derivativeConvergence', struct('finestRelativeError', 1e-8), ...
        'maximumFinestForwardBackwardError', 2e-8, ...
        'selectedPerturbationMagnitude', 1e-6, ...
        'baseValidation', struct( ...
            'periodicResidualNormInf', 1e-12, ...
            'timingRepeatability', struct( ...
                'eventTimingErrorNormInf', 1e-13), ...
            'mapInfo', struct('solvedEventTimes', eventTimes, ...
                'eventTopology', topology, ...
                'timingResidualNormInf', 1e-12)));
end

function directions = FakeDirectionResolver(~)
    directions = struct('ID', 'resolved_physical_mode', ...
        'EigenData', struct('Eigenvector', ones(12, 1)));
end

function [corrected, info] = FakeCorrector(~)
    corrected = [zeros(21, 1); 1];
    info = struct('accepted', true, 'message', 'synthetic accepted');
end

function report = FakeHeldOutRejected(~, ~)
    report = struct('Accepted', false, ...
        'Status', 'rejected-held-out-evidence', ...
        'Claims', {{'predicted and reference daughter gait identity agree'}}, ...
        'Message', 'Synthetic held-out evidence rejected the claim.');
end

function report = FakeHeldOutAccepted(~, ~)
    report = struct('Accepted', true, ...
        'Status', 'accepted-held-out-evidence', ...
        'Claims', {{'independent daughter evidence supports branch identity'}}, ...
        'Message', 'Synthetic held-out evidence accepted the claim.');
end

function report = FakeHeldOutException(~, ~)
    report = struct(); %#ok<NASGU>
    error('TestFixture:HeldOutFailure', ...
        'Synthetic held-out validator failure.');
end

function report = FakeHeldOutAmbiguous(~, ~)
    report = struct('Accepted', 2, 'Status', '', 'Claims', {{}});
end

function report = FakeHeldOutMutatesReference(~, options)
    mutation = true;
    save(options.ReferenceDaughterBranchFiles{1}, 'mutation');
    report = struct('Accepted', false, 'Status', 'mutated-reference', ...
        'Claims', {{'reference remained immutable'}}, ...
        'Message', 'Synthetic mutation fixture.');
end

function RemoveDirectory(directory)
    if isfolder(directory)
        rmdir(directory, 's');
    end
end
