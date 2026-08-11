function tests = test_floquet_workflow_package_api
%TEST_FLOQUET_WORKFLOW_PACKAGE_API Stable namespaced workflow entry points.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    workflowTestRoot = fileparts(mfilename('fullpath'));
    analysisRoot = fileparts(fileparts(workflowTestRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(analysisRoot);
    addpath(fullfile(analysisRoot, 'templates', ...
        'new_branch_workflow'));
    testCase.TestData.AnalysisRoot = analysisRoot;
    testCase.TestData.TemplateRoot = fullfile(analysisRoot, ...
        'templates', 'new_branch_workflow');
end

function testPublicEntryPointsAreResolvable(testCase)
    names = {'floquet.workflow.create', 'floquet.workflow.load', ...
        'floquet.workflow.migrate', ...
        'floquet.workflow.inspect', 'floquet.workflow.runStage', ...
        'floquet.workflow.confirmCandidates', ...
        'floquet.workflow.confirmRays'};
    for k = 1:numel(names)
        testCase.verifyNotEmpty(which(names{k}), names{k});
    end
end

function testWorkflowImplementationsArePackageOwned(testCase)
    names = {'BuildFloquetWorkflowConfig', ...
        'CreateFloquetWorkflowConfig', ...
        'LoadFloquetWorkflowConfig', 'InspectFloquetWorkflowState', ...
        'NormalizeFloquetRaySelections'};
    internalRoot = fullfile(testCase.TestData.AnalysisRoot, '+floquet', ...
        '+workflow', '+internal');
    for k = 1:numel(names)
        qualified = ['floquet.workflow.internal.' names{k}];
        resolved = which(qualified);
        testCase.verifyEqual(resolved, ...
            fullfile(internalRoot, [names{k} '.m']), qualified);
    end

    controller = floquet.workflow.Session();
    testCase.verifyTrue(isa(controller,'floquet.workflow.Session'));

    legacyRoot = fullfile(testCase.TestData.AnalysisRoot, ...
        'compatibility','legacy_api');
    testCase.verifyFalse(isfolder(legacyRoot), ...
        'The clean-root package must not ship global legacy wrappers.');
    globalNames = {'CreateFloquetWorkflowConfig', ...
        'LoadFloquetWorkflowConfig', 'InspectFloquetWorkflowState', ...
        'NormalizeFloquetRaySelections', 'FloquetWorkflowController'};
    for k = 1:numel(globalNames)
        testCase.verifyEmpty(which(globalNames{k}), ...
            sprintf('Global wrapper must not resolve: %s',globalNames{k}));
    end
end

function testCreateLoadInspectRoundTrip(testCase)
    [parentFile, outputRoot, cleanup] = FixturePaths(); %#ok<ASGLU>
    [config, configFile, metadata] = floquet.workflow.create( ...
        parentFile, outputRoot, struct('AnalysisOptions', ...
        struct('Verbose', false)));

    testCase.verifyTrue(isfile(configFile));
    testCase.verifyEqual(metadata.SchemaVersion, ...
        'floquet-workflow-config-v2');
    testCase.verifyEqual(metadata.ArtifactLayoutVersion, ...
        'numbered-artifacts-v1');
    testCase.verifyEqual(config.SchemaVersion, ...
        'floquet-workflow-config-v2');
    testCase.verifyEqual(config.ArtifactLayoutVersion, ...
        'numbered-artifacts-v1');
    testCase.verifyEqual(config.Continuation.CheckpointFile, ...
        config.Files.DaughterCheckpoint);
    testCase.verifyEmpty(config.Continuation.StatusFcn);
    testCase.verifyEmpty(config.Continuation.ControlFcn);
    testCase.verifyEqual(config.AnalysisOptions.CheckpointEvery, 1);
    VerifyNumberedLayout(testCase, config, outputRoot);
    [loaded, source] = floquet.workflow.load(configFile);
    testCase.verifyEqual(loaded.ExpectedParentSHA256, ...
        config.ExpectedParentSHA256);
    testCase.verifyEqual(source.Kind, 'mat-file');
    testCase.verifyNotEmpty(source.SHA256);

    state = floquet.workflow.inspect(loaded);
    testCase.verifyTrue(state.Stages(1).CanRun);
    testCase.verifyFalse(any([state.Stages.Valid]));
    testCase.verifyFalse(state.Stages(2).CanRun);
end

function testLegacyLoadPreservesEveryExplicitPath(testCase)
    [parentFile, outputRoot, cleanup] = FixturePaths(); %#ok<ASGLU>
    current = floquet.workflow.create(parentFile, outputRoot, ...
        struct('SaveConfig', false));
    legacy = MakeLegacy(current);
    names = fieldnames(legacy.Files);
    for k = 1:numel(names)
        legacy.Files.(names{k}) = fullfile(outputRoot, 'legacy-owned', ...
            sprintf('%02d_%s', k, names{k}));
    end
    legacy.AnalysisOptions.CheckpointFile = fullfile( ...
        outputRoot, 'legacy-checkpoints', 'scan.mat');
    legacy.Continuation.CheckpointFile = fullfile( ...
        outputRoot, 'legacy-checkpoints', 'daughter.mat');
    before = legacy;

    [loaded, source] = floquet.workflow.load(legacy);

    testCase.verifyEqual(loaded, before, ...
        'Loading a legacy config must not supplement or rebase its paths.');
    testCase.verifyEqual(source.SchemaVersion, ...
        'floquet-workflow-config-v1');
    testCase.verifyEqual(source.ArtifactLayoutVersion, ...
        'legacy-explicit-paths');
    testCase.verifyTrue(source.LegacyReadOnly);
end

function testLegacyConfigsAreInspectionOnly(testCase)
    [parentFile, outputRoot, cleanup] = FixturePaths(); %#ok<ASGLU>
    current = floquet.workflow.create(parentFile, outputRoot, ...
        struct('SaveConfig', false));
    legacy = MakeLegacy(current);

    state = floquet.workflow.inspect(legacy);
    testCase.verifyTrue(state.ConfigurationLayout.IsLegacy);
    testCase.verifyTrue(state.ConfigurationLayout.CanMigrate);
    testCase.verifyFalse(any([state.Stages.CanRun]));
    testCase.verifyError(@() floquet.workflow.runStage(legacy, 1), ...
        'FloquetWorkflow:LegacyConfigMigrationRequired');

    legacyFolder = fileparts(legacy.Files.Discovery);
    if ~isfolder(legacyFolder)
        mkdir(legacyFolder);
    end
    analysis = struct('legacyMarker', true);
    save(legacy.Files.Discovery, 'analysis');
    state = floquet.workflow.inspect(legacy);
    testCase.verifyTrue(state.ConfigurationLayout.HasNonemptyChain);
    testCase.verifyFalse(state.ConfigurationLayout.CanMigrate);
    testCase.verifyError(@() floquet.workflow.runStage(legacy, 1), ...
        'FloquetWorkflow:LegacyConfigReadOnly');
    testCase.verifyError(@() floquet.workflow.migrate(legacy), ...
        'FloquetWorkflow:LegacyMigrationNonempty');
end

function testLegacyCheckpointCannotResume(testCase)
    [parentFile, outputRoot, cleanup] = FixturePaths(); %#ok<ASGLU>
    current = floquet.workflow.create(parentFile, outputRoot, ...
        struct('SaveConfig', false));
    legacy = MakeLegacy(current);
    checkpointFolder = fileparts(legacy.AnalysisOptions.CheckpointFile);
    if ~isfolder(checkpointFolder)
        mkdir(checkpointFolder);
    end
    checkpoint = struct('legacy', true);
    save(legacy.AnalysisOptions.CheckpointFile, 'checkpoint');

    testCase.verifyError(@() floquet.workflow.runStage(legacy, 1), ...
        'FloquetWorkflow:LegacyCheckpointNonResumable');
    testCase.verifyError(@() floquet.workflow.migrate(legacy), ...
        'FloquetWorkflow:LegacyCheckpointNonResumable');
end

function testExplicitEmptyLegacyMigrationRebasesToV2(testCase)
    [parentFile, outputRoot, cleanup] = FixturePaths(); %#ok<ASGLU>
    current = floquet.workflow.create(parentFile, outputRoot, ...
        struct('SaveConfig', false));
    legacy = MakeLegacy(current);
    oldDiscovery = legacy.Files.Discovery;
    legacy.AnalysisOptions.Verbose = false;

    [migrated, configFile, metadata] = ...
        floquet.workflow.migrate(legacy);

    testCase.verifyEmpty(configFile);
    testCase.verifyEqual(migrated.SchemaVersion, ...
        'floquet-workflow-config-v2');
    testCase.verifyEqual(metadata.ArtifactLayoutVersion, ...
        'numbered-artifacts-v1');
    testCase.verifyFalse(migrated.AnalysisOptions.Verbose);
    testCase.verifyEqual(migrated.ParentBranchFile, ...
        legacy.ParentBranchFile);
    testCase.verifyNotEqual(migrated.Files.Discovery, oldDiscovery);
    VerifyNumberedLayout(testCase, migrated, outputRoot);
end

function testCreateRejectsMixedLegacyOutputRoot(testCase)
    [parentFile, outputRoot, cleanup] = FixturePaths(); %#ok<ASGLU>
    legacyFolder = fullfile(outputRoot, 'results', 'discovery');
    mkdir(legacyFolder);
    legacy = true;
    save(fullfile(legacyFolder, 'floquet_analysis.mat'), 'legacy');

    testCase.verifyError(@() floquet.workflow.create( ...
        parentFile, outputRoot, struct('SaveConfig', false)), ...
        'FloquetWorkflow:LegacyOutputRootNotEmpty');
end

function testStageGateIsPreservedByNamespace(testCase)
    [parentFile, outputRoot, cleanup] = FixturePaths(); %#ok<ASGLU>
    config = floquet.workflow.create(parentFile, outputRoot, ...
        struct('SaveConfig', false));

    testCase.verifyError( ...
        @() floquet.workflow.runStage(config, 'refinement'), ...
        'FloquetWorkflow:StageNotReady');
    testCase.verifyError( ...
        @() floquet.workflow.confirmCandidates(config, {'candidate-1'}), ...
        'FloquetWorkflow:DiscoveryRequired');
    testCase.verifyError( ...
        @() floquet.workflow.confirmRays(config, struct()), ...
        'FloquetWorkflow:SeedSearchRequired');
end

function testFactoryAndCopyableTemplateUseCanonicalDefaultConfig(testCase)
    [parentFile, outputRoot, cleanup] = FixturePaths(); %#ok<ASGLU>
    generated = floquet.workflow.create(parentFile, outputRoot, ...
        struct('SaveConfig', false));
    template = ExperimentConfig(parentFile);

    expectedTemplate = floquet.workflow.create(parentFile, ...
        testCase.TestData.TemplateRoot, struct( ...
        'ExperimentName','REPLACE_WITH_EXPERIMENT_NAME', ...
        'SaveConfig',false));
    testCase.verifyEqual(template, expectedTemplate);

    expectedGenerated = ...
        floquet.workflow.internal.BuildFloquetWorkflowConfig( ...
        generated.ExperimentRoot, generated.FloquetRoot);
    expectedGenerated.ExperimentName = 'parent';
    expectedGenerated.ParentBranchFile = generated.ParentBranchFile;
    expectedGenerated.ExpectedParentSHA256 = ...
        generated.ExpectedParentSHA256;
    testCase.verifyEqual(generated, expectedGenerated);
end

function testTemplateAdaptersUseCanonicalStageRunner(testCase)
    files = {'main_RunDiscovery.m', 'main_RefineCandidates.m', ...
        'main_FindDaughterBranches.m', ...
        'main_ContinueDaughterBranches.m', ...
        'main_ValidateExperiment.m'};
    retiredCalls = {'RunFloquetDiscoveryStage(config)', ...
        'RefineFloquetCandidateStage(config)', ...
        'FindFloquetDaughterSeedsStage(config)', ...
        'ContinueFloquetDaughterStage(config)', ...
        'ValidateFloquetExperimentStage(config)'};
    for stage = 1:5
        source = fileread(fullfile(testCase.TestData.TemplateRoot, ...
            files{stage}));
        testCase.verifySubstring(source, ...
            'AddFloquetWorkflowPath(config);', files{stage});
        testCase.verifySubstring(source, sprintf( ...
            'floquet.workflow.runStage(config, %d)', stage), files{stage});
        testCase.verifyFalse(contains(source, retiredCalls{stage}), ...
            files{stage});
    end

    [parentFile, ~, cleanup] = FixturePaths(); %#ok<ASGLU>
    resolvedRoot = AddFloquetWorkflowPath(ExperimentConfig(parentFile));
    testCase.verifyEqual(resolvedRoot, testCase.TestData.AnalysisRoot);
end

function testQualifiedInternalHashHasPackageOwnership(testCase)
    value = reshape(1:12, 3, 4);
    first = floquet.workflow.internal.FloquetNumericSHA256(value);
    second = floquet.workflow.internal.FloquetNumericSHA256(value);
    expectedFile = fullfile(testCase.TestData.AnalysisRoot, '+floquet', ...
        '+workflow', '+internal', 'FloquetNumericSHA256.m');

    testCase.verifyEqual(first, second);
    testCase.verifyEqual(which( ...
        'floquet.workflow.internal.FloquetNumericSHA256'), expectedFile);
    testCase.verifyEmpty(which('FloquetNumericSHA256'));
end

function [parentFile, outputRoot, cleanup] = FixturePaths()
    fixtureRoot = tempname;
    mkdir(fixtureRoot);
    cleanup = onCleanup(@() RemoveFixture(fixtureRoot));
    parentFile = fullfile(fixtureRoot, 'parent.mat');
    outputRoot = fullfile(fixtureRoot, 'workflow');
    results = zeros(29, 3);
    results(1, :) = 1:3;
    results(22, :) = 1;
    save(parentFile, 'results');
end

function legacy = MakeLegacy(current)
    legacy = rmfield(current, ...
        {'SchemaVersion','ArtifactLayoutVersion','Directories'});
    legacy.Files.Discovery = fullfile(legacy.ExperimentRoot, ...
        'results', 'discovery', 'floquet_analysis.mat');
    legacy.AnalysisOptions.CheckpointFile = fullfile( ...
        legacy.ExperimentRoot, 'results', 'discovery', ...
        'floquet_scan_checkpoint.mat');
    legacy.Continuation.CheckpointFile = fullfile( ...
        legacy.ExperimentRoot, 'results', 'daughter_branches', ...
        'daughter_continuation_checkpoint.mat');
end

function VerifyNumberedLayout(testCase, config, outputRoot)
    canonicalFiles = {'Discovery';'CandidateInventory';'RejectedPoints'; ...
        'RejectedIntervals';'Refinement';'RefinementSummary';'Seeds'; ...
        'SeedAttempts';'Daughters';'DaughterInventory'; ...
        'DaughterDirectory';'DaughterCheckpoint';'Validation'; ...
        'ValidationSummary'};
    testCase.verifyEqual(fieldnames(config.Files), canonicalFiles, ...
        ['config.Files must not gain a parallel monolithic result or ' ...
         'untracked stage authority.']);
    artifactRoot = fullfile(outputRoot, 'artifacts');
    testCase.verifyEqual(config.Directories.Artifacts, artifactRoot);
    testCase.verifyEqual(fileparts(config.Files.Discovery), ...
        fullfile(artifactRoot, '01_discovery'));
    testCase.verifyEqual(fileparts(config.Files.Refinement), ...
        fullfile(artifactRoot, '02_refinement'));
    testCase.verifyEqual(fileparts(config.Files.Seeds), ...
        fullfile(artifactRoot, '03_seed_search'));
    testCase.verifyEqual(config.Files.DaughterDirectory, ...
        fullfile(artifactRoot, '04_daughter_branches'));
    testCase.verifyEqual(fileparts(config.Files.Validation), ...
        fullfile(artifactRoot, '05_validation'));
    testCase.verifyEqual(fileparts( ...
        config.AnalysisOptions.CheckpointFile), ...
        fullfile(outputRoot, 'checkpoints'));
    testCase.verifyEqual(fileparts( ...
        config.Continuation.CheckpointFile), ...
        fullfile(outputRoot, 'checkpoints'));
    testCase.verifyEqual(config.Directories.Views, ...
        fullfile(outputRoot, 'views'));
    testCase.verifyEqual(config.Directories.Logs, ...
        fullfile(outputRoot, 'logs'));
end

function RemoveFixture(fixtureRoot)
    if isfolder(fixtureRoot)
        rmdir(fixtureRoot, 's');
    end
end
