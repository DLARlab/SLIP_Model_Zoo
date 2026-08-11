function tests = test_blind_parent_workflow_configs
%TEST_BLIND_PARENT_WORKFLOW_CONFIGS Audit the five parent-only demo profiles.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    floquetRoot = fileparts(fileparts(testRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(floquetRoot);
    testCase.TestData.FloquetRoot = floquetRoot;
end

function testAllProfilesAreBlindFrozenFullScanConfigurations(testCase)
    names = {'PK_parent','BE_parent','BG_parent','FG_parent','HE_parent'};
    entryPoints = {'PKParentWorkflowConfig','BEParentWorkflowConfig', ...
        'BGParentWorkflowConfig','FGParentWorkflowConfig', ...
        'HEParentWorkflowConfig'};
    expectedHashes = { ...
        '45835bb5024b1dc9b875c7b8f7b205769f537a4ff4144c763058537f44dbf401', ...
        '3ab8e1f47ea788a95faa541bed9bf02ad53b5e4107f5601a19f96f5464b87d0c', ...
        'ccff690f6a6b468ee623259f68dfe71dc077dcf552e35869324bc39c132b2be0', ...
        '231895dbb454f914a6f9bd269d2108e761728f3e1cc7a5548be7f0b6a1b6cbf3', ...
        'c3f7bd53f05729cada19cdb8b074e91d6861849d13c0555b2e5a1812a532c892'};
    profilesRoot = fullfile(testCase.TestData.FloquetRoot, ...
        'examples', 'blind_parent_profiles');
    requiredFiles = {'Discovery','CandidateInventory','RejectedPoints', ...
        'RejectedIntervals','Refinement','RefinementSummary','Seeds', ...
        'SeedAttempts','Daughters','DaughterInventory', ...
        'DaughterDirectory','DaughterCheckpoint','Validation', ...
        'ValidationSummary'};

    for k = 1:numel(names)
        profileRoot = fullfile(profilesRoot, names{k});
        addpath(profileRoot, '-begin');
        cleanup = onCleanup(@() RemoveProfilePath(profileRoot));
        constructor = str2func(entryPoints{k});
        config = constructor();

        verifyEqual(testCase, config.ExperimentName, names{k});
        verifyEqual(testCase, config.SchemaVersion, ...
            'floquet-workflow-config-v2');
        verifyEqual(testCase, config.ArtifactLayoutVersion, ...
            'numbered-artifacts-v1');
        verifyEqual(testCase, CanonicalPath(config.ExperimentRoot), ...
            CanonicalPath(profileRoot));
        verifyTrue(testCase, isfile(config.ParentBranchFile));
        verifyEqual(testCase, config.ExpectedParentSHA256, ...
            expectedHashes{k});
        verifyEqual(testCase, ...
            floquet.workflow.internal.FloquetFileSHA256( ...
            config.ParentBranchFile), expectedHashes{k});

        metadata = whos('-file', config.ParentBranchFile, 'results');
        verifyNumElements(testCase, metadata, 1);
        verifyEqual(testCase, metadata.size(1), 29);
        verifyGreaterThan(testCase, metadata.size(2), 1);
        verifyEqual(testCase, metadata.class, 'double');

        verifyFalse(testCase, config.OverwriteResults);
        verifyFalse(testCase, config.Discovery.ExportOnly);
        verifyEmpty(testCase, config.Selection.CandidateIDs);
        verifyFalse(testCase, config.Selection.Confirmed);
        verifyEmpty(testCase, config.Refinement.ConfigureGroup);
        verifyEmpty(testCase, config.BranchSwitch.DirectionResolver);
        verifyEmpty(testCase, config.BranchSwitch.CorrectorFunction);
        verifyFalse(testCase, config.Continuation.Enabled);
        verifyFalse(testCase, config.Continuation.Confirmed);
        verifyEmpty(testCase, config.Continuation.RaySelections);
        verifyTrue(testCase, ...
            config.Continuation.DeleteCheckpointOnSuccess);
        verifyEmpty(testCase, config.Continuation.StatusFcn);
        verifyEmpty(testCase, config.Continuation.ControlFcn);
        verifyEmpty(testCase, config.Validation.ReferenceDaughterBranchFiles);
        verifyEmpty(testCase, config.Validation.Function);
        verifyEqual(testCase, config.AnalysisOptions.CheckpointEvery, 5);
        verifyTrue(testCase, ...
            config.AnalysisOptions.DeleteCheckpointOnSuccess);
        verifyEqual(testCase, config.Continuation.CheckpointFile, ...
            config.Files.DaughterCheckpoint);
        verifyEqual(testCase, fileparts(config.Files.Discovery), ...
            fullfile(profileRoot, 'artifacts', '01_discovery'));
        verifyEqual(testCase, fileparts(config.Files.Refinement), ...
            fullfile(profileRoot, 'artifacts', '02_refinement'));
        verifyEqual(testCase, fileparts(config.Files.Seeds), ...
            fullfile(profileRoot, 'artifacts', '03_seed_search'));
        verifyEqual(testCase, config.Files.DaughterDirectory, ...
            fullfile(profileRoot, 'artifacts', ...
            '04_daughter_branches'));
        verifyEqual(testCase, fileparts(config.Files.Validation), ...
            fullfile(profileRoot, 'artifacts', '05_validation'));
        verifyEqual(testCase, fileparts( ...
            config.AnalysisOptions.CheckpointFile), ...
            fullfile(profileRoot, 'checkpoints'));

        expected = floquet.workflow.create(config.ParentBranchFile, ...
            profileRoot,struct('ExperimentName',names{k}, ...
            'AnalysisOptions',struct('CheckpointEvery',5), ...
            'SaveConfig',false));
        if k > 1
            expected.BranchSwitch.PredictorOptions = struct( ...
                'TimingLiftMode', 'one-sided-sector');
            expected.BranchSwitch.CorrectorOptions = struct( ...
                'ConstraintMode', 'oriented-amplitude');
        end
        verifyEqual(testCase, config, expected, ...
            sprintf('%s drifted from the canonical config schema.', ...
            names{k}));

        source = fileread(fullfile(profileRoot, ...
            [entryPoints{k} '.m']));
        verifySubstring(testCase, source, ...
            'floquet.workflow.create');
        verifyFalse(testCase, contains(source, ...
            'floquet.workflow.internal.BuildFloquetWorkflowConfig'));
        verifyFalse(testCase, contains(source, 'function files = WorkflowFiles'));

        verifyEqual(testCase, fieldnames(config.Files), ...
            requiredFiles(:), ...
            ['The writable workflow contract must expose exactly the ' ...
             'numbered-stage files and their derived audit views.']);
        for j = 1:numel(requiredFiles)
            target = CanonicalPathAllowMissing( ...
                config.Files.(requiredFiles{j}));
            verifyTrue(testCase, IsInside(target, ...
                CanonicalPath(config.ExperimentRoot)));
        end

        clear cleanup
        RemoveProfilePath(profileRoot);
    end
end

function RemoveProfilePath(profileRoot)
    if contains([path, pathsep], [profileRoot, pathsep])
        rmpath(profileRoot);
    end
end

function filename = CanonicalPath(filename)
    filename = char(java.io.File(filename).getCanonicalPath());
end

function filename = CanonicalPathAllowMissing(filename)
    filename = char(java.io.File(filename).getCanonicalPath());
end

function tf = IsInside(filename, root)
    prefix = [root, filesep];
    tf = strcmp(filename, root) || startsWith(filename, prefix);
end
