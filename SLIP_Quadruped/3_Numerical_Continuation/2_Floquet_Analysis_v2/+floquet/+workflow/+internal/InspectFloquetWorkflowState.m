function state = InspectFloquetWorkflowState(input)
%INSPECTFLOQUETWORKFLOWSTATE Read and validate a five-stage workflow state.
%
% This function never writes an artifact.  A report is exposed only after
% its complete upstream path/SHA-256 handoff has passed the canonical
% artifact-chain validator.  A stale artifact is therefore shown as invalid
% rather than silently becoming GUI state.

    [config, configSource] = ...
        floquet.workflow.internal.LoadFloquetWorkflowConfig(input);
    AddWorkflowPaths();

    state = EmptyState(config, configSource);
    [state.InformationBarrier.ClearForStagesOneToFour, ...
        state.InformationBarrier.Message] = InformationBarrierState(config);

    stageVariables = {'analysis', 'refinementReport', 'seedReport', ...
        'daughterReport'};
    terminalNames = {'discovery', 'refinement', 'seeds', 'daughters'};
    reportFields = {'Analysis', 'Refinement', 'Seeds', 'Daughters'};
    chainFields = {'Discovery', 'Refinement', 'Seeds', 'Daughters'};
    latestChain = struct();
    for stageNumber = 1:4
        artifact = state.Stages(stageNumber).ArtifactFile;
        if isempty(artifact) || ~isfile(artifact)
            continue
        end
        try
            chain = floquet.workflow.internal.ValidateFloquetArtifactChain( ...
                config, terminalNames{stageNumber});
            report = LoadScalarStruct(artifact, ...
                stageVariables{stageNumber});
            ValidateStageReport(report, stageNumber);
            identity = chain.(chainFields{stageNumber});
            state.Stages(stageNumber) = MarkComplete( ...
                state.Stages(stageNumber), identity);
            state.Reports.(reportFields{stageNumber}) = report;
            latestChain = chain;
            if stageNumber == 1
                state.Discovery.Available = true;
                state.Discovery.Analysis = report;
                state.Discovery.Source = StructField(report, 'source');
                state.Discovery.Authority = chain.DiscoveryAuthority;
                state.Discovery.ScientificUseAllowed = strcmp( ...
                    chain.DiscoveryAuthority, ...
                    'production-scientific-authority');
                state.Parent = chain.Parent;
                state.CandidateTable = BuildCandidateTable( ...
                    report, config.Selection);
            end
        catch exception
            state.Stages(stageNumber) = MarkInvalid( ...
                state.Stages(stageNumber), exception);
        end
    end

    validationArtifact = state.Stages(5).ArtifactFile;
    if ~isempty(validationArtifact) && isfile(validationArtifact)
        try
            chain = floquet.workflow.internal.ValidateFloquetArtifactChain( ...
                config, 'daughters');
            report = LoadScalarStruct(validationArtifact, ...
                'validationReport');
            ValidateStageReport(report, 5);
            ValidateValidationHandoff(report, chain.Daughters);
            identity = ArtifactIdentity(validationArtifact);
            state.Stages(5) = MarkComplete(state.Stages(5), identity);
            state.Reports.Validation = report;
            latestChain = chain;
        catch exception
            state.Stages(5) = MarkInvalid( ...
                state.Stages(5), exception);
        end
    end
    state.ValidatedArtifactChain = latestChain;

    if state.Stages(3).Valid
        try
            state.Continuation.RayCatalog = ...
                floquet.workflow.internal.InspectFloquetDaughterRays(config);
        catch exception
            state.Continuation.RayCatalogErrorIdentifier = ...
                exception.identifier;
            state.Continuation.RayCatalogMessage = exception.message;
        end
    end

    [selectionReady, selectionMessage] = ...
        CandidateSelectionState(config.Selection, ...
            state.Discovery.Analysis);
    state.Selection.Confirmed = selectionReady;
    state.Selection.CandidateIDs = ConfiguredCandidateIDs(config.Selection);
    state.Selection.Message = selectionMessage;

    [continuationReady, continuationMessage, selections] = ...
        ContinuationSelectionState(config.Continuation, ...
            state.Reports.Seeds, state.Stages(3).SHA256);
    state.Continuation.Confirmed = continuationReady;
    state.Continuation.RaySelections = selections;
    state.Continuation.Message = continuationMessage;

    clearBarrier = state.InformationBarrier.ClearForStagesOneToFour;
    writable = state.ConfigurationLayout.Writable;
    stageOneReady = clearBarrier && writable;
    stageOneReason = FirstReason( ...
        writable, state.ConfigurationLayout.Message, ...
        clearBarrier, state.InformationBarrier.Message);
    state.Stages(1) = SetReadiness(state.Stages(1), stageOneReady, ...
        stageOneReason, ...
        AllowStageOverwrite(config, 1));
    stageTwoPrerequisite = state.Stages(1).Valid && selectionReady && ...
        clearBarrier && writable;
    stageTwoReason = FirstReason( ...
        state.Stages(1).Valid, 'Stage 1 discovery is not valid.', ...
        selectionReady, selectionMessage, ...
        writable, state.ConfigurationLayout.Message, ...
        clearBarrier, state.InformationBarrier.Message);
    state.Stages(2) = SetReadiness( ...
        state.Stages(2), stageTwoPrerequisite, stageTwoReason, ...
        AllowStageOverwrite(config, 2));
    stageThreePrerequisite = state.Stages(2).Valid && clearBarrier && writable;
    stageThreeReason = FirstReason( ...
        state.Stages(2).Valid, 'Stage 2 refinement is not valid.', ...
        writable, state.ConfigurationLayout.Message, ...
        clearBarrier, state.InformationBarrier.Message);
    state.Stages(3) = SetReadiness( ...
        state.Stages(3), stageThreePrerequisite, stageThreeReason, ...
        AllowStageOverwrite(config, 3));
    stageFourPrerequisite = state.Stages(3).Valid && ...
        continuationReady && clearBarrier && writable;
    stageFourReason = FirstReason( ...
        state.Stages(3).Valid, 'Stage 3 seed search is not valid.', ...
        continuationReady, continuationMessage, ...
        writable, state.ConfigurationLayout.Message, ...
        clearBarrier, state.InformationBarrier.Message);
    state.Stages(4) = SetReadiness( ...
        state.Stages(4), stageFourPrerequisite, stageFourReason, ...
        AllowStageOverwrite(config, 4));
    stageFiveReason = FirstReason( ...
        state.Stages(4).Valid, ...
        'Stage 4 daughter inventory is not valid.', ...
        writable, state.ConfigurationLayout.Message);
    state.Stages(5) = SetReadiness(state.Stages(5), ...
        state.Stages(4).Valid && writable, stageFiveReason, ...
        AllowStageOverwrite(config, 5));
end

function state = EmptyState(config, configSource)
    state = struct();
    state.SchemaVersion = 'floquet-workflow-state-v2';
    state.Config = config;
    state.ConfigSource = configSource;
    state.ConfigurationLayout = ...
        floquet.workflow.internal.InspectFloquetWorkflowLayout(config);
    state.ExperimentName = TextField(config, 'ExperimentName');
    state.ExperimentRoot = TextField(config, 'ExperimentRoot');
    state.ParentBranchFile = TextField(config, 'ParentBranchFile');
    state.Parent = struct();
    state.InformationBarrier = struct( ...
        'ClearForStagesOneToFour', true, 'Message', '');
    state.Discovery = struct('Available', false, 'Analysis', struct([]), ...
        'Source', struct(), 'Authority', '', ...
        'ScientificUseAllowed', false);
    state.Reports = struct('Analysis', struct([]), ...
        'Refinement', struct([]), 'Seeds', struct([]), ...
        'Daughters', struct([]), 'Validation', struct([]));
    state.CandidateTable = EmptyCandidateTable();
    state.Selection = struct('Confirmed', false, ...
        'CandidateIDs', {{}}, 'Message', '');
    state.Continuation = struct('Confirmed', false, ...
        'RaySelections', struct([]), 'Message', '', ...
        'RayCatalog', struct([]), ...
        'RayCatalogErrorIdentifier', '', 'RayCatalogMessage', '');
    state.ValidatedArtifactChain = struct();
    names = {'Full branch FDM and bifurcation detection', ...
        'Critical-orbit refinement', ...
        'Timing-aware predictors and seed correction', ...
        'Daughter-branch continuation', ...
        'Independent daughter validation'};
    ids = {'discovery', 'refinement', 'seeds', ...
        'continuation', 'validation'};
    fileFields = {'Discovery', 'Refinement', 'Seeds', ...
        'Daughters', 'Validation'};
    state.Stages = repmat(EmptyStage(), 1, 5);
    for k = 1:5
        state.Stages(k).Number = k;
        state.Stages(k).ID = ids{k};
        state.Stages(k).Name = names{k};
        state.Stages(k).ArtifactField = fileFields{k};
        state.Stages(k).ArtifactFile = ConfiguredFile(config, fileFields{k});
        state.Stages(k).ArtifactExists = ...
            ~isempty(state.Stages(k).ArtifactFile) && ...
            isfile(state.Stages(k).ArtifactFile);
    end
end

function stage = EmptyStage()
    stage = struct('Number', NaN, 'ID', '', 'Name', '', ...
        'ArtifactField', '', 'ArtifactFile', '', 'ArtifactExists', false, ...
        'Status', 'not-run', 'Valid', false, 'Ready', false, ...
        'CanRun', false, 'Message', '', 'ErrorIdentifier', '', ...
        'SHA256', '');
end

function stage = MarkComplete(stage, identity)
    stage.Status = 'complete';
    stage.Valid = true;
    stage.Message = 'Validated artifact and upstream lineage are complete.';
    stage.ErrorIdentifier = '';
    stage.ArtifactExists = true;
    stage.ArtifactFile = identity.CanonicalPath;
    stage.SHA256 = identity.SHA256;
end

function stage = MarkInvalid(stage, exception)
    stage.Status = 'invalid';
    stage.Valid = false;
    stage.Message = exception.message;
    stage.ErrorIdentifier = exception.identifier;
    stage.ArtifactExists = true;
end

function stage = SetReadiness(stage, ready, reason, allowOverwrite)
    blockedByArtifact = stage.ArtifactExists && ~allowOverwrite;
    stage.Ready = logical(ready) && ~blockedByArtifact;
    stage.CanRun = stage.Ready;
    if ~ready && ~stage.Valid
        if isempty(stage.Message)
            stage.Message = reason;
        elseif ~isempty(reason)
            stage.Message = sprintf('%s Prerequisite: %s', ...
                stage.Message, reason);
        end
    elseif stage.Ready && strcmp(stage.Status, 'not-run')
        stage.Status = 'ready';
        stage.Message = 'All workflow prerequisites are satisfied.';
    elseif stage.Valid && ~allowOverwrite
        stage.Message = [ ...
            'Validated artifact is complete; start an intentional overwrite ' ...
            'or a new artifact set to rerun this stage.'];
    elseif stage.ArtifactExists && ~allowOverwrite && ~stage.Valid
        stage.Message = sprintf('%s %s', stage.Message, [ ...
            'The invalid artifact must be removed or explicitly overwritten ' ...
            'before this stage can run.']);
    end
end

function tf = AllowStageOverwrite(config, stageNumber)
    tf = isfield(config, 'OverwriteResults') && ...
        IsStrictLogicalTrue(config.OverwriteResults);
    if stageNumber == 4
        tf = tf && isfield(config, 'Continuation') && ...
            isstruct(config.Continuation) && ...
            isscalar(config.Continuation) && ...
            isfield(config.Continuation, 'Overwrite') && ...
            IsStrictLogicalTrue(config.Continuation.Overwrite);
    end
end

function tf = IsStrictLogicalTrue(value)
    tf = islogical(value) && isscalar(value) && value;
end

function [ready, message] = CandidateSelectionState(selection, analysis)
    ready = false;
    message = ['Inspect Stage 1 and explicitly confirm candidate IDs; ' ...
        'a confirmed empty list means all discovered candidate groups.'];
    if ~isstruct(selection) || ~isscalar(selection) || ...
            ~isfield(selection, 'Confirmed') || ...
            ~isfield(selection, 'CandidateIDs') || ...
            ~(islogical(selection.Confirmed) && isscalar(selection.Confirmed))
        message = ['config.Selection must contain logical scalar Confirmed ' ...
            'and CandidateIDs.'];
        return
    end
    if ~selection.Confirmed
        return
    end
    if isempty(fieldnames(analysis))
        message = 'A valid Stage-1 analysis is required before confirmation.';
        return
    end
    try
        configured = NormalizeTextList(selection.CandidateIDs, ...
            'config.Selection.CandidateIDs');
        available = CandidateIDs(analysis);
    catch exception
        message = exception.message;
        return
    end
    unknown = setdiff(configured, available, 'stable');
    if ~isempty(unknown)
        message = sprintf('Unknown confirmed candidate ID(s): %s.', ...
            strjoin(unknown, ', '));
        return
    end
    ready = true;
    if isempty(configured)
        message = 'Candidate inventory confirmed; all groups are selected.';
    else
        message = sprintf('%d candidate group(s) explicitly confirmed.', ...
            numel(configured));
    end
end

function ids = CandidateIDs(analysis)
    if ~isfield(analysis, 'candidates') || ~isstruct(analysis.candidates)
        error('FloquetWorkflow:CandidateContract', ...
            'Validated analysis candidates must be a struct array.');
    end
    candidates = analysis.candidates;
    ids = cell(1, numel(candidates));
    for k = 1:numel(candidates)
        if ~isfield(candidates(k), 'CandidateID')
            error('FloquetWorkflow:CandidateContract', ...
                'Discovery candidate %d has no stable CandidateID.', k);
        end
        ids{k} = ScalarText(candidates(k).CandidateID, 'CandidateID');
    end
    ids = unique(ids, 'stable');
end

function ids = ConfiguredCandidateIDs(selection)
    ids = {};
    if isstruct(selection) && isscalar(selection) && ...
            isfield(selection, 'CandidateIDs')
        try
            ids = NormalizeTextList(selection.CandidateIDs, ...
                'config.Selection.CandidateIDs');
        catch
            ids = {};
        end
    end
end

function [ready, message, selections] = ContinuationSelectionState( ...
        continuation, seedReport, seedSHA256)
    ready = false;
    selections = struct([]);
    if ~isstruct(continuation) || ~isscalar(continuation)
        message = 'config.Continuation must be one scalar struct.';
        return
    end
    required = {'Enabled', 'Confirmed', 'RaySelections'};
    if ~all(isfield(continuation, required))
        message = ['config.Continuation must contain Enabled, Confirmed, ' ...
            'and RaySelections.'];
        return
    end
    if ~(islogical(continuation.Enabled) && ...
            isscalar(continuation.Enabled) && continuation.Enabled)
        message = 'Continuation.Enabled must be explicitly true.';
        return
    end
    if ~(islogical(continuation.Confirmed) && ...
            isscalar(continuation.Confirmed) && continuation.Confirmed)
        message = 'Continuation.Confirmed must be explicitly true.';
        return
    end
    if isempty(fieldnames(seedReport)) || isempty(seedSHA256)
        message = 'A valid Stage-3 seed artifact is required.';
        return
    end
    try
        selections = ...
            floquet.workflow.internal.NormalizeFloquetRaySelections( ...
            continuation.RaySelections, seedReport, seedSHA256);
    catch exception
        message = exception.message;
        return
    end
    if isfield(continuation, 'SourceSeedSHA256') && ...
            ~isempty(continuation.SourceSeedSHA256) && ...
            ~strcmpi(strtrim(char(string( ...
                continuation.SourceSeedSHA256))), seedSHA256)
        message = 'Continuation confirmation is bound to a stale seed artifact.';
        selections = struct([]);
        return
    end
    ready = true;
    message = sprintf('%d signed continuation ray(s) explicitly confirmed.', ...
        numel(selections));
end

function tableValue = BuildCandidateTable(analysis, selection)
    if ~isfield(analysis, 'candidates') || isempty(analysis.candidates)
        tableValue = EmptyCandidateTable();
        return
    end
    candidates = analysis.candidates;
    count = numel(candidates);
    candidateID = strings(count, 1);
    type = strings(count, 1);
    bifurcationType = strings(count, 1);
    leftColumn = NaN(count, 1);
    rightColumn = NaN(count, 1);
    coordinate = NaN(count, 1);
    multiplierReal = NaN(count, 1);
    multiplierImag = NaN(count, 1);
    confidence = NaN(count, 1);
    nullMultiplicity = NaN(count, 1);
    classification = strings(count, 1);
    branchSwitchReady = false(count, 1);
    for k = 1:count
        candidateID(k) = string(TextValue(candidates(k), ...
            {'CandidateID'}));
        type(k) = string(TextValue(candidates(k), {'Type', 'type'}));
        bifurcationType(k) = string(TextValue(candidates(k), ...
            {'BifurcationType'}));
        leftColumn(k) = NumericValue(candidates(k), ...
            {'LeftBranchColumn', 'LeftBranchIndex'});
        rightColumn(k) = NumericValue(candidates(k), ...
            {'RightBranchColumn', 'RightBranchIndex'});
        coordinate(k) = NumericValue(candidates(k), ...
            {'ContinuationCoordinate', 'ContinuationParameter', 'Parameter'});
        multiplier = FieldValue(candidates(k), ...
            {'Multiplier', 'multiplier'}, NaN);
        if isnumeric(multiplier) && isscalar(multiplier)
            multiplierReal(k) = real(multiplier);
            multiplierImag(k) = imag(multiplier);
        end
        confidence(k) = NumericValue(candidates(k), {'ConfidenceScore'});
        nullMultiplicity(k) = NumericValue(candidates(k), ...
            {'NullMultiplicity'});
        classification(k) = string(TextValue(candidates(k), ...
            {'NullDirectionClassification'}));
        branchSwitchReady(k) = LogicalValue(candidates(k), ...
            {'BranchSwitchReady'});
    end
    configured = ConfiguredCandidateIDs(selection);
    confirmed = isstruct(selection) && isscalar(selection) && ...
        isfield(selection, 'Confirmed') && ...
        islogical(selection.Confirmed) && isscalar(selection.Confirmed) && ...
        selection.Confirmed;
    if confirmed && isempty(configured)
        selected = true(count, 1);
    elseif confirmed
        selected = ismember(candidateID, string(configured));
    else
        selected = false(count, 1);
    end
    tableValue = table(selected, candidateID, type, bifurcationType, ...
        leftColumn, rightColumn, coordinate, multiplierReal, ...
        multiplierImag, confidence, nullMultiplicity, classification, ...
        branchSwitchReady, 'VariableNames', ...
        {'Selected', 'CandidateID', 'Type', 'BifurcationType', ...
         'LeftColumn', 'RightColumn', 'Coordinate', 'MultiplierReal', ...
         'MultiplierImag', 'Confidence', 'NullMultiplicity', ...
         'Classification', 'BranchSwitchReady'});
end

function value = EmptyCandidateTable()
    value = table(false(0, 1), strings(0, 1), strings(0, 1), ...
        strings(0, 1), NaN(0, 1), NaN(0, 1), NaN(0, 1), NaN(0, 1), ...
        NaN(0, 1), NaN(0, 1), NaN(0, 1), strings(0, 1), false(0, 1), ...
        'VariableNames', {'Selected', 'CandidateID', 'Type', ...
        'BifurcationType', 'LeftColumn', 'RightColumn', 'Coordinate', ...
        'MultiplierReal', 'MultiplierImag', 'Confidence', ...
        'NullMultiplicity', 'Classification', 'BranchSwitchReady'});
end

function ValidateValidationHandoff(report, daughterIdentity)
    required = {'SourceDaughterFile', 'SourceDaughterSHA256'};
    if ~all(isfield(report, required))
        error('FloquetWorkflow:ValidationArtifactContract', ...
            'Validation report is missing its daughter source identity.');
    end
    source = CanonicalExistingFile(report.SourceDaughterFile);
    if ~SamePath(source, daughterIdentity.CanonicalPath)
        error('FloquetWorkflow:ValidationArtifactSource', ...
            'Validation report points to a different daughter inventory.');
    end
    savedSHA = strtrim(char(string(report.SourceDaughterSHA256)));
    if ~strcmpi(savedSHA, daughterIdentity.SHA256)
        error('FloquetWorkflow:ValidationArtifactHash', ...
            'Validation report is stale relative to the daughter inventory.');
    end
end

function identity = ArtifactIdentity(filename)
    filename = CanonicalExistingFile(filename);
    identity = struct('CanonicalPath', filename, ...
        'SHA256', ...
        floquet.workflow.internal.FloquetFileSHA256(filename));
end

function report = LoadScalarStruct(filename, variable)
    loaded = load(filename, variable);
    if ~isfield(loaded, variable) || ...
            ~isstruct(loaded.(variable)) || ~isscalar(loaded.(variable))
        error('FloquetWorkflow:ArtifactContract', ...
            '%s must contain one scalar struct variable %s.', ...
            filename, variable);
    end
    report = loaded.(variable);
end

function ValidateStageReport(report, stageNumber)
    switch stageNumber
        case 1
            required = {'candidates', 'sampleIndices', 'states'};
            RequireReportFields(report, required, 'discovery analysis');
            if ~isstruct(report.candidates) || ~isnumeric(report.sampleIndices) || ...
                    ~isnumeric(report.states)
                error('FloquetWorkflow:ArtifactContract', ...
                    'Discovery candidate, index, or state data are malformed.');
            end
        case 2
            RequireReportFields(report, {'Records'}, 'refinement report');
            if ~isstruct(report.Records)
                error('FloquetWorkflow:ArtifactContract', ...
                    'Refinement Records must be a struct array.');
            end
        case 3
            RequireReportFields(report, {'Attempts'}, 'seed report');
            if ~isstruct(report.Attempts)
                error('FloquetWorkflow:ArtifactContract', ...
                    'Seed Attempts must be a struct array.');
            end
        case 4
            RequireReportFields(report, ...
                {'ContinuationEnabled', 'Records'}, 'daughter report');
            if ~IsLogicalScalar(report.ContinuationEnabled) || ...
                    ~isstruct(report.Records)
                error('FloquetWorkflow:ArtifactContract', [ ...
                    'Daughter ContinuationEnabled and Records are ' ...
                    'malformed.']);
            end
        case 5
            RequireReportFields(report, {'Accepted', 'Status', ...
                'SourceDaughterFile', 'SourceDaughterSHA256'}, ...
                'validation report');
            if ~IsLogicalScalar(report.Accepted) || ...
                    ~(ischar(report.Status) || ...
                      (isstring(report.Status) && isscalar(report.Status))) || ...
                    strlength(strtrim(string(report.Status))) == 0
                error('FloquetWorkflow:ArtifactContract', ...
                    'Validation Accepted or Status is malformed.');
            end
    end
end

function RequireReportFields(report, fields, label)
    missing = fields(~isfield(report, fields));
    if ~isempty(missing)
        error('FloquetWorkflow:ArtifactContract', ...
            '%s is missing field(s): %s.', label, strjoin(missing, ', '));
    end
end

function tf = IsLogicalScalar(value)
    tf = isscalar(value) && isreal(value) && ...
        (islogical(value) || ...
         (isnumeric(value) && isfinite(value) && any(value == [0 1])));
end

function [clear, message] = InformationBarrierState(config)
    clear = true;
    message = '';
    validation = config.Validation;
    if ~isstruct(validation) || ~isscalar(validation)
        clear = false;
        message = 'config.Validation must be one scalar struct.';
        return
    end
    references = isfield(validation, 'ReferenceDaughterBranchFiles') && ...
        ~isempty(validation.ReferenceDaughterBranchFiles);
    callback = isfield(validation, 'Function') && ...
        ~isempty(validation.Function);
    if references || callback
        clear = false;
        message = ['Stages 1--4 are locked because this configuration ' ...
            'contains held-out daughter evidence. Load a parent-only ' ...
            'configuration; add held-out inputs only for Stage 5.'];
    end
end

function message = FirstReason(varargin)
    message = '';
    for k = 1:2:numel(varargin)
        if ~varargin{k}
            message = varargin{k + 1};
            return
        end
    end
end

function filename = ConfiguredFile(config, field)
    filename = '';
    if ~isfield(config.Files, field) || ...
            ~(ischar(config.Files.(field)) || ...
              (isstring(config.Files.(field)) && ...
               isscalar(config.Files.(field))))
        return
    end
    filename = strtrim(char(string(config.Files.(field))));
    if ~isempty(filename)
        filename = char(java.io.File(filename).getCanonicalPath());
    end
end

function filename = CanonicalExistingFile(filename)
    if ~(ischar(filename) || (isstring(filename) && isscalar(filename)))
        error('FloquetWorkflow:ArtifactPath', ...
            'Artifact source paths must be scalar text.');
    end
    filename = char(java.io.File(char(string(filename))).getCanonicalPath());
    if ~isfile(filename)
        error('FloquetWorkflow:ArtifactMissing', ...
            'Artifact source file does not exist: %s', filename);
    end
end

function tf = SamePath(first, second)
    first = char(java.io.File(first).getCanonicalPath());
    second = char(java.io.File(second).getCanonicalPath());
    if ispc
        tf = strcmpi(first, second);
    else
        tf = strcmp(first, second);
    end
end

function values = NormalizeTextList(values, label)
    if isempty(values)
        values = {};
        return
    end
    if ischar(values) || (isstring(values) && isscalar(values))
        values = {char(string(values))};
    elseif isstring(values) || iscellstr(values)
        values = cellstr(values(:).');
    else
        error('FloquetWorkflow:TextList', ...
            '%s must be text or a cell/string vector.', label);
    end
    values = cellfun(@strtrim, values, 'UniformOutput', false);
    if any(cellfun(@isempty, values)) || ...
            numel(unique(values, 'stable')) ~= numel(values)
        error('FloquetWorkflow:TextList', ...
            '%s must contain unique nonempty IDs.', label);
    end
end

function value = ScalarText(value, label)
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error('FloquetWorkflow:TextValue', ...
            '%s must be scalar text.', label);
    end
    value = strtrim(char(string(value)));
    if isempty(value)
        error('FloquetWorkflow:TextValue', ...
            '%s must not be empty.', label);
    end
end

function value = StructField(source, field)
    value = struct();
    if isstruct(source) && isscalar(source) && isfield(source, field) && ...
            isstruct(source.(field))
        value = source.(field);
    end
end

function value = TextField(source, field)
    value = '';
    if isstruct(source) && isscalar(source) && isfield(source, field) && ...
            (ischar(source.(field)) || ...
             (isstring(source.(field)) && isscalar(source.(field))))
        value = char(string(source.(field)));
    end
end

function value = FieldValue(source, names, fallback)
    value = fallback;
    for k = 1:numel(names)
        if isfield(source, names{k}) && ~isempty(source.(names{k}))
            value = source.(names{k});
            return
        end
    end
end

function value = TextValue(source, names)
    value = FieldValue(source, names, '');
    if iscell(value) && isscalar(value)
        value = value{1};
    end
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        value = '';
    end
    value = char(string(value));
end

function value = NumericValue(source, names)
    value = FieldValue(source, names, NaN);
    if ~(isnumeric(value) && isscalar(value))
        value = NaN;
    end
end

function value = LogicalValue(source, names)
    value = FieldValue(source, names, false);
    value = isscalar(value) && ...
        (islogical(value) || ...
         (isnumeric(value) && isreal(value) && isfinite(value) && ...
          any(value == [0 1]))) && logical(value);
end

function AddWorkflowPaths()
    internalRoot = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(fileparts(internalRoot)));
    paths = {root};
    for k = 1:numel(paths)
        entries = strsplit(path, pathsep);
        if ispc || ismac
            present = any(strcmpi(entries, paths{k}));
        else
            present = any(strcmp(entries, paths{k}));
        end
        if ~present
            addpath(paths{k}, '-begin');
        end
    end
end
