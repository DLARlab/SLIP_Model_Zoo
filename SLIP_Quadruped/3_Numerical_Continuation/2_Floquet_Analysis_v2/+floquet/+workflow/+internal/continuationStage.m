function daughterReport = continuationStage(config)
%CONTINUEFLOQUETDAUGHTERSTAGE Continue pairs of corrected same-ray seeds.
%
% An inventory is always saved, including when continuation is disabled or
% no signed ray has two accepted amplitudes.  Large branch matrices live in
% each ray's branch.mat and are not duplicated in the inventory by default.
% When enabled, Stage 4 requires an explicitly confirmed RaySelections plan
% bound to the current Stage-3 seed SHA-256.  A checkpoint is installed
% before each ray and after each terminal ray result, so a GUI can stop and
% safely resume between rays without silently changing the scientific plan.

    ValidateConfig(config);
    floquet.workflow.internal.RequireWritableFloquetWorkflowConfig(config);
    floquet.workflow.internal.EnforceFloquetInformationBarrier(config, 'daughter continuation');
    RequireFile(config.Files.Seeds, ...
        'Run the local daughter-seed search stage first.');
    floquet.workflow.internal.AddFloquetNumericalPaths(config);
    chain = floquet.workflow.internal.ValidateFloquetArtifactChain(config, 'seeds');
    rayCatalog = floquet.workflow.internal.InspectFloquetDaughterRays(config);
    inventoryFile = ResolveInventoryFile(config);
    checkpointFile = ResolveCheckpointFile(config);
    overwrite = floquet.workflow.internal.FloquetWorkflowOverwrite(config);
    stageOutputs = {config.Files.Daughters, inventoryFile};
    protected = {chain.Parent.CanonicalPath, ...
        chain.Discovery.CanonicalPath, chain.Refinement.CanonicalPath, ...
        chain.Seeds.CanonicalPath};
    floquet.workflow.internal.PreflightFloquetArtifacts(stageOutputs, overwrite, protected);
    loaded = load(config.Files.Seeds, 'seedReport');
    if ~isfield(loaded, 'seedReport')
        error('TemplateExperiment:SeedReportContract', ...
            'Seed MAT file does not contain seedReport.');
    end
    seedReport = loaded.seedReport;

    records = repmat(EmptyRecord(), 1, 0);
    selections = repmat(EmptySelection(), 1, 0);
    resumed = false;
    stopped = false;
    completedRayCount = 0;
    stageLock = []; %#ok<NASGU>
    if config.Continuation.Enabled
        selections = ValidateRaySelections(config, seedReport, rayCatalog);
        stageLock = AcquireStageLock(checkpointFile); %#ok<NASGU>
        plannedOutputs = {selections.OutputFile};
        floquet.workflow.internal.PreflightFloquetArtifacts( ...
            [plannedOutputs {checkpointFile}], true, ...
            [protected stageOutputs]);
        signature = CheckpointSignature(config, chain, selections);
        [checkpoint, resumed] = PrepareCheckpoint(config, checkpointFile, ...
            signature, selections, seedReport, overwrite);
        records = checkpoint.Records;
        completedRayCount = numel(records);
        NotifyStatus(config, 'stage-ready', completedRayCount, ...
            numel(selections), '', checkpointFile, resumed, ...
            completedRayCount, ...
            'Stage 4 ray plan validated.');
        for k = checkpoint.NextRayIndex:numel(selections)
            event = StatusEvent('before-ray', k, numel(selections), ...
                selections(k).RayID, checkpointFile, resumed, ...
                completedRayCount, 'Ready to continue selected ray.');
            if ShouldStop(config, event)
                stopped = true;
                checkpoint.ActiveRayIndex = 0;
                checkpoint.NextRayIndex = k;
                checkpoint.UpdatedAt = Timestamp();
                WriteCheckpoint(checkpointFile, checkpoint);
                NotifyStatus(config, 'paused-between-rays', k, ...
                    numel(selections), selections(k).RayID, ...
                    checkpointFile, resumed, ...
                    completedRayCount, ...
                    'Stage 4 paused before the selected ray.');
                break
            end

            checkpoint.ActiveRayIndex = k;
            checkpoint.NextRayIndex = k;
            checkpoint.UpdatedAt = Timestamp();
            WriteCheckpoint(checkpointFile, checkpoint);
            NotifyStatus(config, 'ray-started', k, numel(selections), ...
                selections(k).RayID, checkpointFile, resumed, ...
                completedRayCount, ...
                'Continuing selected daughter ray.');

            record = RecoverOrContinueRay(selections(k), seedReport, ...
                config, checkpointFile, resumed);
            records(end + 1) = record; %#ok<AGROW>
            completedRayCount = numel(records);
            checkpoint.Records = records;
            checkpoint.ActiveRayIndex = 0;
            checkpoint.NextRayIndex = k + 1;
            checkpoint.UpdatedAt = Timestamp();
            WriteCheckpoint(checkpointFile, checkpoint);
            NotifyStatus(config, 'ray-completed', k, numel(selections), ...
                selections(k).RayID, checkpointFile, resumed, ...
                completedRayCount, ...
                record.Message);
        end
    end

    daughterReport = struct();
    daughterReport.WorkflowStage = 'continued-daughter-branch-candidates';
    daughterReport.WorkflowConfigSchemaVersion = config.SchemaVersion;
    daughterReport.ArtifactLayoutVersion = config.ArtifactLayoutVersion;
    daughterReport.SourceSeedFile = chain.Seeds.CanonicalPath;
    daughterReport.SourceSeedSHA256 = chain.Seeds.SHA256;
    daughterReport.ValidatedArtifactChain = chain;
    daughterReport.ContinuationEnabled = logical(config.Continuation.Enabled);
    daughterReport.SelectionConfirmed = ContinuationConfirmed(config);
    daughterReport.RayCatalog = rayCatalog.Rows;
    daughterReport.EligibleRayIDs = rayCatalog.EligibleRayIDs;
    daughterReport.RaySelectionContract = rayCatalog.SelectionContract;
    daughterReport.SelectedRays = selections;
    if isfield(seedReport, 'CandidateRecords')
        daughterReport.SeedCandidateRecords = seedReport.CandidateRecords;
    else
        daughterReport.SeedCandidateRecords = struct([]);
    end
    daughterReport.Records = records;
    daughterReport.AcceptedRayIDs = {records([records.Accepted]).RayID};
    daughterReport.Status = DaughterReportStatus( ...
        config.Continuation.Enabled, records, stopped);
    daughterReport.FinalArtifactWritten = ~stopped;
    daughterReport.Checkpoint = struct( ...
        'File', checkpointFile, ...
        'ResumeRequested', ResumeRequested(config), ...
        'Resumed', resumed, ...
        'CompletedRayCount', completedRayCount, ...
        'PlannedRayCount', numel(selections), ...
        'Available', isfile(checkpointFile), ...
        'DeleteOnSuccess', DeleteCheckpointOnSuccess(config));
    daughterReport.Checkpoint.LockDirectory = [checkpointFile '.lock'];
    daughterReport.CreatedAt = Timestamp();
    daughterReport.Scope = [ ...
        'Accepted records are numerically continued same-ray branch ' ...
        'candidates. Branch identity, uniqueness, and agreement with a ' ...
        'historical gait require separate validation.'];
    daughterReport.StoragePolicy = [ ...
        'Full results are stored once in each OutputFile. The inventory ' ...
        'retains compact quality/provenance; Results is populated only when ' ...
        'Continuation.StoreResultsInInventory=true.'];
    daughterReport.Reproducibility = struct( ...
        'MATLABVersion', version, ...
        'NumericalOptions', config.Continuation.Options, ...
        'ContinuationFunction', floquet.workflow.internal.FloquetCallbackIdentity( ...
            OptionCallback(config.Continuation.Options, ...
                'ContinuationFunction')), ...
        'ValidationFunction', floquet.workflow.internal.FloquetCallbackIdentity( ...
            OptionCallback(config.Continuation.Options, ...
                'ValidationFunction')), ...
        'StatusFunction', CallbackName(ContinuationCallback( ...
            config, 'StatusFcn')), ...
        'ControlFunction', CallbackName(ContinuationCallback( ...
            config, 'ControlFcn')));

    if stopped
        return
    end

    floquet.workflow.internal.WriteFloquetArtifact(config.Files.Daughters, ...
        struct('daughterReport', daughterReport), overwrite);
    floquet.workflow.internal.WriteFloquetAuditTable(inventoryFile, ...
        DaughterInventorySummary(records), overwrite);
    if config.Continuation.Enabled && DeleteCheckpointOnSuccess(config) && ...
            isfile(checkpointFile)
        delete(checkpointFile);
        daughterReport.Checkpoint.Available = false;
        daughterReport.Checkpoint.DeletedOnSuccess = true;
        floquet.workflow.internal.WriteFloquetArtifact(config.Files.Daughters, ...
            struct('daughterReport', daughterReport), true);
    else
        daughterReport.Checkpoint.DeletedOnSuccess = false;
    end
    NotifyStatus(config, 'stage-completed', numel(selections), ...
        numel(selections), '', checkpointFile, resumed, ...
        completedRayCount, ...
        'Stage 4 completed and installed its final inventory.');
end

function filename = ResolveInventoryFile(config)
    if isfield(config.Files, 'DaughterInventory') && ...
            ~isempty(config.Files.DaughterInventory)
        filename = config.Files.DaughterInventory;
    else
        filename = fullfile(fileparts(config.Files.Daughters), ...
            'daughter_branch_inventory.csv');
    end
end

function filename = ResolveCheckpointFile(config)
    if isfield(config.Continuation, 'CheckpointFile') && ...
            ~isempty(config.Continuation.CheckpointFile)
        filename = ScalarText(config.Continuation.CheckpointFile, ...
            'Continuation.CheckpointFile');
    else
        filename = fullfile(fileparts(config.Files.Daughters), ...
            'daughter_continuation_checkpoint.mat');
    end
    filename = char(java.io.File(filename).getCanonicalPath());
end

function cleanup = AcquireStageLock(checkpointFile)
    lockDirectory = [checkpointFile '.lock'];
    parent = fileparts(lockDirectory);
    if ~isempty(parent) && ~isfolder(parent)
        mkdir(parent);
    end
    created = java.io.File(lockDirectory).mkdir();
    if ~created
        error('TemplateExperiment:ContinuationStageBusy', [ ...
            'Stage 4 already has a writer lock at %s. If MATLAB was ' ...
            'terminated abnormally, verify that no Stage-4 process is ' ...
            'running before removing the stale empty lock directory.'], ...
            lockDirectory);
    end
    cleanup = onCleanup(@() ReleaseStageLock(lockDirectory));
end

function ReleaseStageLock(lockDirectory)
    if isfolder(lockDirectory)
        [ok, message] = rmdir(lockDirectory);
        if ~ok
            warning('TemplateExperiment:ContinuationLockCleanup', ...
                'Could not remove Stage-4 lock %s: %s', ...
                lockDirectory, message);
        end
    end
end

function summary = DaughterInventorySummary(records)
    count = numel(records);
    rayID = strings(count, 1);
    candidateID = strings(count, 1);
    directionID = strings(count, 1);
    signValue = NaN(count, 1);
    availableAmplitudes = strings(count, 1);
    seedAmplitudes = strings(count, 1);
    seedAttemptIndices = strings(count, 1);
    sourceSeedSHA256 = strings(count, 1);
    accepted = false(count, 1);
    status = strings(count, 1);
    pointCount = NaN(count, 1);
    sameRayAlignedCount = NaN(count, 1);
    geometryAccepted = false(count, 1);
    outputValidationAccepted = false(count, 1);
    outputFile = strings(count, 1);
    outputSHA256 = strings(count, 1);
    errorIdentifier = strings(count, 1);
    message = strings(count, 1);
    for k = 1:count
        rayID(k) = string(records(k).RayID);
        candidateID(k) = string(records(k).CandidateID);
        directionID(k) = string(records(k).DirectionID);
        signValue(k) = records(k).Sign;
        availableAmplitudes(k) = NumberList(records(k).AvailableAmplitudes);
        seedAmplitudes(k) = NumberList(records(k).SeedAmplitudes);
        seedAttemptIndices(k) = IntegerList(records(k).SeedAttemptIndices);
        sourceSeedSHA256(k) = string(records(k).SourceSeedSHA256);
        accepted(k) = records(k).Accepted;
        status(k) = string(records(k).Status);
        pointCount(k) = NestedNumber(records(k).ContinuationInfo, ...
            {'pointCount'});
        sameRayAlignedCount(k) = NestedNumber( ...
            records(k).ContinuationInfo, ...
            {'daughterGeometry','sameRayAlignedCount'});
        geometryAccepted(k) = NestedLogical(records(k).ContinuationInfo, ...
            {'daughterGeometry','accepted'});
        outputValidationAccepted(k) = NestedLogical( ...
            records(k).ContinuationInfo, ...
            {'OutputValidation','AllCheckedAccepted'});
        outputFile(k) = string(records(k).OutputFile);
        outputSHA256(k) = string(records(k).OutputSHA256);
        errorIdentifier(k) = string(records(k).ErrorIdentifier);
        message(k) = string(records(k).Message);
    end
    summary = table(rayID, candidateID, directionID, signValue, ...
        availableAmplitudes, seedAmplitudes, seedAttemptIndices, ...
        sourceSeedSHA256, accepted, status, pointCount, ...
        sameRayAlignedCount, geometryAccepted, outputValidationAccepted, ...
        outputFile, outputSHA256, errorIdentifier, message);
end

function value = IntegerList(values)
    if isempty(values)
        value = "";
    else
        value = string(strjoin(compose('%d', values(:).'), ';'));
    end
end

function value = NumberList(values)
    if isempty(values)
        value = "";
    else
        value = string(strjoin(compose('%.16g', values(:).'), ';'));
    end
end

function value = NestedNumber(source, path)
    value = NestedValue(source, path, NaN);
    if ~(isnumeric(value) && isscalar(value))
        value = NaN;
    end
end

function value = NestedLogical(source, path)
    value = NestedValue(source, path, false);
    value = isscalar(value) && ...
        (islogical(value) || (isnumeric(value) && isfinite(value))) && ...
        logical(value);
end

function value = NestedValue(source, path, fallback)
    value = source;
    for k = 1:numel(path)
        if ~isstruct(value) || ~isscalar(value) || ...
                ~isfield(value, path{k})
            value = fallback;
            return
        end
        value = value.(path{k});
    end
end

function ValidateConfig(config)
    required = {'ExperimentRoot','Continuation','Files'};
    if nargin < 1 || ~isstruct(config) || ~isscalar(config)
        error('TemplateExperiment:InvalidConfiguration', ...
            'The shared workflow requires one scalar ExperimentConfig struct.');
    end
    for k = 1:numel(required)
        if ~isfield(config, required{k})
            error('TemplateExperiment:MissingConfiguration', ...
                'ExperimentConfig is missing field %s.', required{k});
        end
    end
    if ~isfield(config.Continuation, 'Enabled') || ...
            ~(isscalar(config.Continuation.Enabled) && ...
              (islogical(config.Continuation.Enabled) || ...
               (isnumeric(config.Continuation.Enabled) && ...
                isfinite(config.Continuation.Enabled) && ...
                any(config.Continuation.Enabled == [0 1]))))
        error('TemplateExperiment:ContinuationEnabled', ...
            'Continuation.Enabled must be scalar logical.');
    end
    if ~isfield(config.Continuation, 'Overwrite') || ...
            ~(isscalar(config.Continuation.Overwrite) && ...
            (islogical(config.Continuation.Overwrite) || ...
             (isnumeric(config.Continuation.Overwrite) && ...
              isfinite(config.Continuation.Overwrite) && ...
              any(config.Continuation.Overwrite == [0 1]))))
        error('TemplateExperiment:ContinuationOverwrite', ...
            'Continuation.Overwrite must be scalar logical.');
    end
    optionalLogical = {'Confirmed','ResumeFromCheckpoint', ...
        'DeleteCheckpointOnSuccess'};
    for k = 1:numel(optionalLogical)
        name = optionalLogical{k};
        if isfield(config.Continuation, name) && ...
                ~IsLogicalScalar(config.Continuation.(name))
            error('TemplateExperiment:ContinuationOption', ...
                'Continuation.%s must be scalar logical.', name);
        end
    end
    optionalCallbacks = {'StatusFcn','ControlFcn'};
    for k = 1:numel(optionalCallbacks)
        name = optionalCallbacks{k};
        if isfield(config.Continuation, name) && ...
                ~(isempty(config.Continuation.(name)) || ...
                  isa(config.Continuation.(name), 'function_handle'))
            error('TemplateExperiment:ContinuationCallback', ...
                'Continuation.%s must be empty or a function handle.', name);
        end
    end
    if logical(config.Continuation.Enabled)
        if ~ContinuationConfirmed(config)
            error('TemplateExperiment:ContinuationNotConfirmed', [ ...
                'Continuation.Enabled=true requires an explicit ' ...
                'Continuation.Confirmed=true after reviewing Stage 3.']);
        end
        if ~isfield(config.Continuation, 'RaySelections') || ...
                ~isstruct(config.Continuation.RaySelections) || ...
                isempty(config.Continuation.RaySelections)
            error('TemplateExperiment:RaySelectionsRequired', [ ...
                'Enabled Stage 4 requires a nonempty struct array in ' ...
                'Continuation.RaySelections.']);
        end
    end
end

function selections = ValidateRaySelections(config, seedReport, catalog)
    raw = config.Continuation.RaySelections;
    required = {'RayID','SeedAttemptIndices','SeedAmplitudes', ...
        'SourceSeedSHA256'};
    selections = repmat(EmptySelection(), 1, numel(raw));
    attempts = seedReport.Attempts;
    for k = 1:numel(raw)
        for j = 1:numel(required)
            if ~isfield(raw(k), required{j})
                error('TemplateExperiment:RaySelectionContract', ...
                    'Ray selection %d is missing %s.', k, required{j});
            end
        end
        rayID = ScalarText(raw(k).RayID, ...
            sprintf('Continuation.RaySelections(%d).RayID', k));
        sourceSHA = lower(ScalarText(raw(k).SourceSeedSHA256, ...
            sprintf(['Continuation.RaySelections(%d).' ...
            'SourceSeedSHA256'], k)));
        if ~IsSHA256(sourceSHA) || ...
                ~strcmp(sourceSHA, lower(catalog.SourceSeedSHA256))
            error('TemplateExperiment:RaySelectionSeedMismatch', [ ...
                'Ray selection %d is not bound to the current Stage-3 ' ...
                'seed artifact SHA-256.'], k);
        end
        indices = raw(k).SeedAttemptIndices;
        if ~isnumeric(indices) || ~isreal(indices) || numel(indices) ~= 2 || ...
                any(~isfinite(indices)) || any(indices ~= fix(indices)) || ...
                any(indices < 1) || any(indices > numel(attempts)) || ...
                indices(1) == indices(2)
            error('TemplateExperiment:RaySelectionAttemptIndices', [ ...
                'Ray selection %d must name exactly two distinct valid ' ...
                'SeedAttemptIndices.'], k);
        end
        indices = reshape(indices, 1, 2);
        amplitudes = raw(k).SeedAmplitudes;
        if ~isnumeric(amplitudes) || ~isreal(amplitudes) || ...
                numel(amplitudes) ~= 2 || any(~isfinite(amplitudes)) || ...
                any(amplitudes <= 0) || amplitudes(1) >= amplitudes(2)
            error('TemplateExperiment:RaySelectionAmplitudes', [ ...
                'Ray selection %d SeedAmplitudes must be two positive, ' ...
                'strictly increasing values.'], k);
        end
        amplitudes = reshape(amplitudes, 1, 2);
        chosen = attempts(indices);
        if ~all(arrayfun(@AttemptAccepted, chosen))
            error('TemplateExperiment:RaySelectionRejectedAttempt', ...
                'Ray selection %d includes a non-accepted seed attempt.', k);
        end
        chosenKeys = arrayfun(@RayKey, chosen, 'UniformOutput', false);
        if ~all(strcmp(chosenKeys, rayID))
            error('TemplateExperiment:RaySelectionMixedRay', ...
                'Ray selection %d attempts do not both belong to RayID %s.', ...
                k, rayID);
        end
        actualAmplitudes = [chosen.Amplitude];
        tolerance = 100 * eps * max(1, max(abs( ...
            [actualAmplitudes amplitudes])));
        if any(abs(actualAmplitudes - amplitudes) > tolerance)
            error('TemplateExperiment:RaySelectionAmplitudeMismatch', [ ...
                'Ray selection %d SeedAmplitudes do not match the named ' ...
                'seed attempts in the same order.'], k);
        end
        row = catalog.Rows(strcmp({catalog.Rows.RayID}, rayID));
        if numel(row) ~= 1 || ~row.Eligible
            error('TemplateExperiment:RaySelectionIneligible', ...
                'Ray selection %d does not identify one eligible ray.', k);
        end
        selection = EmptySelection();
        selection.RayID = rayID;
        selection.CandidateID = row.CandidateID;
        selection.DirectionID = row.DirectionID;
        selection.Sign = row.Sign;
        selection.SeedAttemptIndices = indices;
        selection.SeedAmplitudes = amplitudes;
        selection.SourceSeedSHA256 = sourceSHA;
        selection.OutputFile = char(java.io.File(fullfile( ...
            config.Files.DaughterDirectory, ...
            Sanitize(selection.CandidateID), Sanitize(selection.RayID), ...
            'branch.mat')).getCanonicalPath());
        selections(k) = selection;
    end
    if numel(unique({selections.RayID})) ~= numel(selections)
        error('TemplateExperiment:DuplicateRaySelection', ...
            'Continuation.RaySelections contains a duplicate RayID.');
    end
end

function signature = CheckpointSignature(config, chain, selections)
    signature = struct();
    signature.SchemaVersion = 'daughter-stage-checkpoint-signature-v1';
    signature.WorkflowConfigSchemaVersion = config.SchemaVersion;
    signature.ArtifactLayoutVersion = config.ArtifactLayoutVersion;
    signature.SourceSeedFile = chain.Seeds.CanonicalPath;
    signature.SourceSeedSHA256 = chain.Seeds.SHA256;
    signature.RaySelections = selections;
    signature.ContinuationOptions = config.Continuation.Options;
    signature.StoreResultsInInventory = StoreResultsInInventory( ...
        config.Continuation);
end

function [checkpoint, resumed] = PrepareCheckpoint(config, filename, ...
        signature, selections, seedReport, stageOverwrite)
    resumed = false;
    completeOverwrite = stageOverwrite && ...
        logical(config.Continuation.Overwrite);
    if isfile(filename) && ResumeRequested(config)
        loaded = load(filename, 'checkpoint');
        if ~isfield(loaded, 'checkpoint') || ...
                ~ValidCheckpointShape(loaded.checkpoint) || ...
                ~isequaln(loaded.checkpoint.Signature, signature)
            error('TemplateExperiment:ContinuationCheckpointIncompatible', [ ...
                'The Stage-4 checkpoint does not match the current seed ' ...
                'artifact, ray selection plan, or numerical options.']);
        end
        checkpoint = loaded.checkpoint;
        ValidateCompletedRecords(checkpoint, selections);
        activeBeforeRecovery = checkpoint.ActiveRayIndex;
        checkpoint = RecoverActiveRay(checkpoint, selections, seedReport, ...
            config);
        if activeBeforeRecovery > 0 && checkpoint.ActiveRayIndex == 0
            WriteCheckpoint(filename, checkpoint);
        end
        ValidateUnclaimedOutputs(checkpoint, selections, false);
        resumed = true;
        return
    end
    if isfile(filename) && ~completeOverwrite
        error('TemplateExperiment:ContinuationCheckpointExists', [ ...
            'A Stage-4 checkpoint already exists. Set ' ...
            'Continuation.ResumeFromCheckpoint=true to resume its exact ' ...
            'plan, or explicitly enable both overwrite flags for a rerun.']);
    end
    checkpoint = struct( ...
        'SchemaVersion', 'daughter-stage-checkpoint-v1', ...
        'Signature', signature, ...
        'Records', repmat(EmptyRecord(), 1, 0), ...
        'NextRayIndex', 1, ...
        'ActiveRayIndex', 0, ...
        'CreatedAt', Timestamp(), ...
        'UpdatedAt', Timestamp());
    ValidateUnclaimedOutputs(checkpoint, selections, completeOverwrite);
    WriteCheckpoint(filename, checkpoint);
end

function checkpoint = RecoverActiveRay(checkpoint, selections, seedReport, ...
        config)
    active = checkpoint.ActiveRayIndex;
    if active == 0
        return
    end
    if active ~= checkpoint.NextRayIndex || ...
            numel(checkpoint.Records) ~= active - 1
        error('TemplateExperiment:ContinuationCheckpointContract', ...
            'Stage-4 checkpoint active-ray bookkeeping is inconsistent.');
    end
    selection = selections(active);
    if ~isfile(selection.OutputFile)
        checkpoint.ActiveRayIndex = 0;
        return
    end
    record = RecoverRayArtifact(selection, seedReport, config);
    checkpoint.Records(end + 1) = record;
    checkpoint.ActiveRayIndex = 0;
    checkpoint.NextRayIndex = active + 1;
    checkpoint.UpdatedAt = Timestamp();
end

function ValidateCompletedRecords(checkpoint, selections)
    records = checkpoint.Records;
    if numel(records) > numel(selections) || ...
            checkpoint.NextRayIndex ~= numel(records) + 1 || ...
            checkpoint.NextRayIndex < 1 || ...
            checkpoint.NextRayIndex > numel(selections) + 1
        error('TemplateExperiment:ContinuationCheckpointContract', ...
            'Stage-4 checkpoint completed-ray bookkeeping is invalid.');
    end
    for k = 1:numel(records)
        if ~strcmp(records(k).RayID, selections(k).RayID)
            error('TemplateExperiment:ContinuationCheckpointContract', ...
                'Checkpoint record %d does not match the ordered ray plan.', k);
        end
        if ~isempty(records(k).OutputFile)
            expected = selections(k).OutputFile;
            if ~SamePath(records(k).OutputFile, expected) || ...
                    ~isfile(expected) || ...
                    ~IsSHA256(records(k).OutputSHA256) || ...
                    ~strcmpi(floquet.workflow.internal.FloquetFileSHA256(expected), ...
                        records(k).OutputSHA256)
                error('TemplateExperiment:ContinuationCheckpointOutput', [ ...
                    'Completed ray %s has a missing, replaced, or ' ...
                    'unexpected branch artifact.'], records(k).RayID);
            end
        elseif isfile(selections(k).OutputFile)
            error('TemplateExperiment:ContinuationCheckpointOutput', [ ...
                'Checkpoint ray %s claims no output, but its branch path ' ...
                'exists and has no recorded SHA-256.'], records(k).RayID);
        end
    end
end

function ValidateUnclaimedOutputs(checkpoint, selections, allowOverwrite)
    claimed = false(1, numel(selections));
    claimed(1:numel(checkpoint.Records)) = true;
    if checkpoint.ActiveRayIndex > 0
        claimed(checkpoint.ActiveRayIndex) = true;
    end
    existing = false(1, numel(selections));
    for k = 1:numel(selections)
        existing(k) = isfile(selections(k).OutputFile);
    end
    unclaimed = existing & ~claimed;
    if any(unclaimed) && ~allowOverwrite
        names = {selections(unclaimed).OutputFile};
        error('TemplateExperiment:DaughterArtifactExists', [ ...
            'Unclaimed per-ray artifact(s) are not reusable checkpoint ' ...
            'evidence: %s. Resume the matching checkpoint or intentionally ' ...
            'enable both overwrite flags for a complete Stage-4 rerun.'], ...
            strjoin(names, ', '));
    end
end

function record = RecoverOrContinueRay(selection, seedReport, config, ~, ...
        resumed)
    if resumed && isfile(selection.OutputFile)
        record = RecoverRayArtifact(selection, seedReport, config);
        return
    end
    attempts = seedReport.Attempts(selection.SeedAttemptIndices);
    record = ContinueRay(selection, attempts, config);
end

function record = RecoverRayArtifact(selection, seedReport, config)
    loaded = load(selection.OutputFile, 'results', 'info');
    if ~isfield(loaded, 'results') || ~isfield(loaded, 'info') || ...
            ~isnumeric(loaded.results) || size(loaded.results, 1) ~= 29 || ...
            ~isstruct(loaded.info) || ~isscalar(loaded.info) || ...
            ~isfield(loaded.info, 'seedSolutions') || ...
            ~isnumeric(loaded.info.seedSolutions) || ...
            ~isequal(size(loaded.info.seedSolutions), [22 2]) || ...
            ~isfield(loaded.info, 'accepted') || ...
            ~IsLogicalScalar(loaded.info.accepted)
        error('TemplateExperiment:ContinuationOrphanMismatch', [ ...
            'The active ray artifact cannot be safely recovered from its ' ...
            'checkpoint.']);
    end
    if ~isfield(loaded.info, 'outputFile') || ...
            ~SamePath(loaded.info.outputFile, selection.OutputFile)
        error('TemplateExperiment:ContinuationOrphanMismatch', [ ...
            'The active ray artifact does not identify the expected ' ...
            'SHA-bound output path.']);
    end
    attempts = seedReport.Attempts(selection.SeedAttemptIndices);
    expectedSeeds = [attempts(1).CorrectedSolution, ...
        attempts(2).CorrectedSolution];
    expectedSeeds(:, 1) = EventTimingRegulation(expectedSeeds(:, 1));
    expectedSeeds(:, 2) = EventTimingRegulation(expectedSeeds(:, 2));
    scale = max(1, max(abs(expectedSeeds), [], 'all'));
    if any(abs(loaded.info.seedSolutions - expectedSeeds) > ...
            1e-11 * scale, 'all')
        error('TemplateExperiment:ContinuationOrphanMismatch', [ ...
            'The active ray artifact seed solutions do not match the ' ...
            'SHA-bound selected attempts.']);
    end
    record = InitializeRecord(selection, attempts);
    record = AttachContinuationResult(record, loaded.results, loaded.info, ...
        config);
    record.Status = [record.Status '-recovered-from-checkpoint'];
end

function WriteCheckpoint(filename, checkpoint)
    floquet.workflow.internal.WriteFloquetArtifact(filename, struct('checkpoint', checkpoint), true);
end

function tf = ValidCheckpointShape(checkpoint)
    required = {'SchemaVersion','Signature','Records','NextRayIndex', ...
        'ActiveRayIndex','CreatedAt','UpdatedAt'};
    tf = isstruct(checkpoint) && isscalar(checkpoint) && ...
        all(isfield(checkpoint, required)) && ...
        isstruct(checkpoint.Records) && ...
        isnumeric(checkpoint.NextRayIndex) && ...
        isscalar(checkpoint.NextRayIndex) && ...
        isfinite(checkpoint.NextRayIndex) && ...
        checkpoint.NextRayIndex == fix(checkpoint.NextRayIndex) && ...
        isnumeric(checkpoint.ActiveRayIndex) && ...
        isscalar(checkpoint.ActiveRayIndex) && ...
        isfinite(checkpoint.ActiveRayIndex) && ...
        checkpoint.ActiveRayIndex == fix(checkpoint.ActiveRayIndex);
end

function callback = OptionCallback(options, field)
    callback = [];
    if isfield(options, field)
        callback = options.(field);
    end
end

function record = ContinueRay(selection, attempts, config)
    record = InitializeRecord(selection, attempts);
    try
        firstAttempt = attempts(1);
        secondAttempt = attempts(2);

        options = config.Continuation.Options;
        options.CriticalSolution = record.CriticalSolution;
        options.Direction = record.ReducedDirection;
        if isfield(firstAttempt.PredictorInfo, 'stateScale')
            options.SectionScale = firstAttempt.PredictorInfo.stateScale;
        end
        options.RequireSameRay = true;
        options.SaveResult = true;
        % Stage 4 owns the inventory record for every attempted ray.  A
        % rejected ContinueDaughterBranch call saves its detailed branch.mat
        % before ThrowOnFailure is evaluated; forcing false keeps the saved
        % path and rejection diagnostics attached to this inventory record.
        options.ThrowOnFailure = false;
        options.Overwrite = config.Continuation.Overwrite;
        options.OutputFile = selection.OutputFile;
        parameters = ResolveParameters(firstAttempt);
        [results, continuationInfo] = floquet.continueDaughterBranch( ...
            firstAttempt.CorrectedSolution, ...
            secondAttempt.CorrectedSolution, parameters, options);
        record = AttachContinuationResult(record, results, ...
            continuationInfo, config);
    catch exception
        record.Accepted = false;
        record.Status = 'failed-continuation-exception';
        record.ErrorIdentifier = exception.identifier;
        record.Message = exception.message;
    end
end

function record = InitializeRecord(selection, attempts)
    record = EmptyRecord();
    record.RayID = selection.RayID;
    record.CandidateID = selection.CandidateID;
    record.DirectionID = selection.DirectionID;
    record.Sign = selection.Sign;
    record.AvailableAmplitudes = selection.SeedAmplitudes;
    record.SeedAmplitudes = selection.SeedAmplitudes;
    record.SeedAttemptIndices = selection.SeedAttemptIndices;
    record.SourceSeedSHA256 = selection.SourceSeedSHA256;
    firstAttempt = attempts(1);
    secondAttempt = attempts(2);
    record.SeedSolutions = [firstAttempt.CorrectedSolution, ...
        secondAttempt.CorrectedSolution];
    record.CriticalSolution = firstAttempt.PredictorInfo.zBase;
    record.ReducedDirection = firstAttempt.PredictorInfo.directionQ;
    record.SeedProvenance = struct( ...
        'CandidateID', record.CandidateID, ...
        'DirectionID', record.DirectionID, ...
        'Sign', record.Sign, ...
        'AttemptIndices', selection.SeedAttemptIndices, ...
        'Amplitudes', selection.SeedAmplitudes, ...
        'SourceSeedSHA256', selection.SourceSeedSHA256, ...
        'PredictorStatus', {{firstAttempt.Status, secondAttempt.Status}});
end

function record = AttachContinuationResult(record, results, info, config)
    record.ContinuationInfo = CompactContinuationInfo(info);
    if isfield(info, 'outputFile')
        record.OutputFile = info.outputFile;
    end
    if ~isempty(record.OutputFile) && isfile(record.OutputFile)
        record.OutputFile = char(java.io.File( ...
            record.OutputFile).getCanonicalPath());
        record.OutputSHA256 = floquet.workflow.internal.FloquetFileSHA256(record.OutputFile);
    end
    if StoreResultsInInventory(config.Continuation)
        record.Results = results;
    end
    record.Accepted = logical(info.accepted);
    if record.Accepted
        record.Status = 'accepted-continued-branch-candidate';
    else
        record.Status = 'rejected-continuation-validation';
    end
    record.Message = info.message;
end

function compact = CompactContinuationInfo(info)
    names = {'schemaVersion','generatedAt','accepted','status','message', ...
        'parameters','seedSeparation','rayGeometry','daughterGeometry', ...
        'flags','pointCount','elapsedSeconds','outputFile', ...
        'validationEvidenceComplete','seedTopologyEvidenceValid'};
    compact = struct();
    for k = 1:numel(names)
        if isfield(info, names{k})
            compact.(names{k}) = info.(names{k});
        end
    end
    compact.OutputValidation = SummarizeOutputValidation(info);
    compact.GaitClassification = SummarizeGaits(info);
end

function summary = SummarizeOutputValidation(info)
    summary = struct('Checked', false, 'CheckedCount', 0, ...
        'AcceptedCount', 0, 'RejectedCount', 0, 'AllCheckedAccepted', false);
    if ~isfield(info, 'outputValidatedMask') || ...
            ~isfield(info, 'outputValidation')
        return
    end
    mask = logical(info.outputValidatedMask(:).');
    summary.Checked = any(mask);
    summary.CheckedCount = nnz(mask);
    if any(mask)
        validations = info.outputValidation(mask);
        accepted = false(1, numel(validations));
        if isstruct(validations) && isfield(validations, 'accepted')
            accepted = logical([validations.accepted]);
        end
        summary.AcceptedCount = nnz(accepted);
        summary.RejectedCount = nnz(~accepted);
        summary.AllCheckedAccepted = all(accepted);
    end
end

function summary = SummarizeGaits(info)
    summary = struct('PostCorrectionOnly', true, ...
        'UniqueNames', {{}}, 'UniqueAbbreviations', {{}}, 'PointCount', 0);
    if isfield(info, 'gaitNames')
        names = cellstr(string(info.gaitNames));
        summary.UniqueNames = unique(names, 'stable');
        summary.PointCount = numel(names);
    end
    if isfield(info, 'gaitAbbreviations')
        abbreviations = cellstr(string(info.gaitAbbreviations));
        summary.UniqueAbbreviations = unique(abbreviations, 'stable');
    end
end

function tf = StoreResultsInInventory(options)
    if ~isfield(options, 'StoreResultsInInventory')
        tf = false;
        return
    end
    value = options.StoreResultsInInventory;
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
        error('TemplateExperiment:StoreResultsInInventory', ...
            'Continuation.StoreResultsInInventory must be scalar logical.');
    end
    tf = logical(value);
end

function parameters = ResolveParameters(attempt)
    if isfield(attempt, 'Parameters') && ~isempty(attempt.Parameters)
        parameters = attempt.Parameters;
    elseif isfield(attempt.CorrectorInfo, 'parameters')
        parameters = attempt.CorrectorInfo.parameters;
    else
        error('TemplateExperiment:MissingParameters', ...
            ['Predictor/corrector output did not retain the seven model ' ...
             'parameters needed for continuation.']);
    end
    parameters = parameters(:);
end

function key = RayKey(attempt)
    key = sprintf('%s__%s__sign_%+d', char(string(attempt.CandidateID)), ...
        char(string(attempt.DirectionID)), sign(attempt.Sign));
end

function status = DaughterReportStatus(enabled, records, stopped)
    if ~enabled
        status = 'complete-continuation-disabled';
    elseif stopped
        status = 'paused-between-selected-rays';
    elseif isempty(records)
        status = 'complete-no-qualified-rays';
    elseif any([records.Accepted])
        status = 'complete-with-continued-branch-candidates';
    else
        status = 'complete-no-accepted-continuation';
    end
end

function record = EmptyRecord()
    record = struct('RayID', '', 'CandidateID', '', 'DirectionID', '', ...
        'Sign', NaN, 'AvailableAmplitudes', [], 'SeedAmplitudes', [], ...
        'SeedAttemptIndices', [], 'SourceSeedSHA256', '', ...
        'SeedSolutions', [], 'CriticalSolution', [], ...
        'ReducedDirection', [], 'SeedProvenance', struct(), ...
        'Results', [], 'ContinuationInfo', struct(), 'OutputFile', '', ...
        'OutputSHA256', '', ...
        'Accepted', false, 'Status', 'not-evaluated', ...
        'ErrorIdentifier', '', 'Message', '');
end

function selection = EmptySelection()
    selection = struct('RayID', '', 'CandidateID', '', ...
        'DirectionID', '', 'Sign', NaN, 'SeedAttemptIndices', [], ...
        'SeedAmplitudes', [], 'SourceSeedSHA256', '', 'OutputFile', '');
end

function tf = ContinuationConfirmed(config)
    tf = isfield(config.Continuation, 'Confirmed') && ...
        IsLogicalScalar(config.Continuation.Confirmed) && ...
        logical(config.Continuation.Confirmed);
end

function tf = ResumeRequested(config)
    tf = isfield(config.Continuation, 'ResumeFromCheckpoint') && ...
        IsLogicalScalar(config.Continuation.ResumeFromCheckpoint) && ...
        logical(config.Continuation.ResumeFromCheckpoint);
end

function tf = DeleteCheckpointOnSuccess(config)
    tf = isfield(config.Continuation, 'DeleteCheckpointOnSuccess') && ...
        IsLogicalScalar(config.Continuation.DeleteCheckpointOnSuccess) && ...
        logical(config.Continuation.DeleteCheckpointOnSuccess);
end

function callback = ContinuationCallback(config, name)
    callback = [];
    if isfield(config.Continuation, name)
        callback = config.Continuation.(name);
    end
end

function name = CallbackName(callback)
    if isempty(callback)
        name = '';
    else
        name = func2str(callback);
    end
end

function NotifyStatus(config, state, index, count, rayID, checkpointFile, ...
        resumed, completedCount, message)
    callback = ContinuationCallback(config, 'StatusFcn');
    if isempty(callback)
        return
    end
    event = StatusEvent(state, index, count, rayID, checkpointFile, ...
        resumed, completedCount, message);
    callback(event);
end

function event = StatusEvent(state, index, count, rayID, checkpointFile, ...
        resumed, completedCount, message)
    event = struct( ...
        'stage', 'daughter-continuation', ...
        'state', state, ...
        'localIndex', index, ...
        'total', count, ...
        'rayID', rayID, ...
        'completedRayCount', completedCount, ...
        'checkpointFile', checkpointFile, ...
        'resumed', logical(resumed), ...
        'message', message);
end

function stop = ShouldStop(config, event)
    callback = ContinuationCallback(config, 'ControlFcn');
    if isempty(callback)
        stop = false;
        return
    end
    response = callback(event);
    if IsLogicalScalar(response)
        stop = ~logical(response);
        return
    end
    if (ischar(response) && isrow(response)) || ...
            (isstring(response) && isscalar(response))
        response = lower(strtrim(char(string(response))));
        if strcmp(response, 'continue')
            stop = false;
            return
        elseif any(strcmp(response, {'stop','pause','cancel'}))
            stop = true;
            return
        end
    end
    error('TemplateExperiment:ContinuationControlResponse', [ ...
        'Continuation.ControlFcn must return true/"continue" to proceed ' ...
        'or false/"stop"/"pause"/"cancel" to pause between rays.']);
end

function tf = AttemptAccepted(attempt)
    tf = isfield(attempt, 'Accepted') && ...
        IsLogicalScalar(attempt.Accepted) && logical(attempt.Accepted);
end

function tf = IsLogicalScalar(value)
    tf = isscalar(value) && isreal(value) && ...
        (islogical(value) || ...
         (isnumeric(value) && isfinite(value) && any(value == [0 1])));
end

function tf = IsSHA256(value)
    tf = ischar(value) && isrow(value) && ...
        ~isempty(regexp(value, '^[0-9a-f]{64}$', 'once'));
end

function value = ScalarText(value, name)
    if ~((ischar(value) && isrow(value)) || ...
            (isstring(value) && isscalar(value))) || ...
            strlength(strtrim(string(value))) == 0
        error('TemplateExperiment:ContinuationText', ...
            '%s must be nonempty scalar text.', name);
    end
    value = char(string(value));
end

function tf = SamePath(left, right)
    left = char(java.io.File(left).getCanonicalPath());
    right = char(java.io.File(right).getCanonicalPath());
    if ispc
        tf = strcmpi(left, right);
    else
        tf = strcmp(left, right);
    end
end

function label = Sanitize(label)
    label = regexprep(char(string(label)), '[^A-Za-z0-9_.-]+', '_');
end

function RequireFile(filename, hint)
    if ~isfile(filename)
        error('TemplateExperiment:MissingStageArtifact', ...
            '%s Missing file: %s', hint, filename);
    end
end

function value = Timestamp()
    value = char(datetime('now', 'TimeZone', 'local', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end
