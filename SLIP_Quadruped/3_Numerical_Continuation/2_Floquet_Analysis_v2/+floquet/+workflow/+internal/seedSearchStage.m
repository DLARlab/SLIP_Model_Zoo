function seedReport = seedSearchStage(config)
%FINDFLOQUETDAUGHTERSEEDSSTAGE Correct supported local +1 predictors.
%
% Every refinement record receives a disposition.  Unsupported -1 and
% complex crossings, non-switch-ready +1 modes, and unresolved repeated
% spaces remain visible instead of aborting the experiment.

    ValidateConfig(config);
    floquet.workflow.internal.RequireWritableFloquetWorkflowConfig(config);
    floquet.workflow.internal.EnforceFloquetInformationBarrier(config, 'local daughter-seed search');
    RequireFile(config.Files.Refinement, ...
        'Run the critical-orbit refinement stage first.');
    floquet.workflow.internal.AddFloquetNumericalPaths(config);
    chain = floquet.workflow.internal.ValidateFloquetArtifactChain(config, 'refinement');
    attemptsFile = ResolveAttemptsFile(config);
    overwrite = floquet.workflow.internal.FloquetWorkflowOverwrite(config);
    floquet.workflow.internal.PreflightFloquetArtifacts({config.Files.Seeds, attemptsFile}, overwrite, ...
        {chain.Parent.CanonicalPath, chain.Discovery.CanonicalPath, ...
         chain.Refinement.CanonicalPath});
    loaded = load(config.Files.Refinement, 'refinementReport');
    if ~isfield(loaded, 'refinementReport')
        error('TemplateExperiment:RefinementContract', ...
            'Refinement MAT file does not contain refinementReport.');
    end
    refinementReport = loaded.refinementReport;

    attempts = repmat(EmptyAttempt(), 1, 0);
    candidateRecords = repmat(EmptyCandidateRecord(), 1, ...
        numel(refinementReport.Records));
    for recordIndex = 1:numel(refinementReport.Records)
        record = refinementReport.Records(recordIndex);
        disposition = EmptyCandidateRecord();
        disposition.CandidateID = record.CandidateID;
        disposition.CandidateType = record.CandidateType;
        disposition.RefinementAccepted = logical(record.Accepted);

        if ~record.Accepted
            disposition.Status = 'skipped-refinement-not-accepted';
            disposition.Message = RecordMessage(record, ...
                'Critical-orbit refinement was not accepted.');
            candidateRecords(recordIndex) = disposition;
            continue
        end
        if ~IsPlusOne(record.CandidateType)
            disposition.Status = 'unsupported-crossing-type';
            disposition.Message = [ ...
                'Generic same-stride switching supports only an additional ' ...
                'real +1 mode; -1 needs P^2 and complex crossings need an ' ...
                'invariant-circle/normal-form method.'];
            candidateRecords(recordIndex) = disposition;
            continue
        end
        diagnostics = record.Diagnostics;
        if record.CandidateCount == 1 && ...
                (~isfield(diagnostics, 'branchSwitchReady') || ...
                 ~diagnostics.branchSwitchReady)
            disposition.Status = 'unsupported-not-switch-ready';
            disposition.Message = [ ...
                'Refinement did not establish an additional non-tangent +1 ' ...
                'direction suitable for same-stride branch switching.'];
            candidateRecords(recordIndex) = disposition;
            continue
        end
        if record.CandidateCount > 1 && ...
                (~isfield(config.BranchSwitch, 'CorrectorFunction') || ...
                 isempty(config.BranchSwitch.CorrectorFunction))
            disposition.Status = ...
                'unsupported-repeated-mode-without-custom-corrector';
            disposition.Message = [ ...
                'A repeated critical space requires an experiment-specific ' ...
                'corrector in addition to a physical DirectionResolver.'];
            candidateRecords(recordIndex) = disposition;
            continue
        end

        firstAttempt = numel(attempts) + 1;
        try
            directions = ResolveDirections(record, config.BranchSwitch);
            disposition.DirectionIDs = {directions.ID};
            for directionIndex = 1:numel(directions)
                for amplitude = config.BranchSwitch.Amplitudes(:).'
                    for signValue = config.BranchSwitch.Signs(:).'
                        attempts(end + 1) = RunAttempt( ...
                            record, directions(directionIndex), amplitude, ...
                            signValue, config.BranchSwitch); %#ok<AGROW>
                    end
                end
            end
            disposition.AttemptIndices = firstAttempt:numel(attempts);
            if isempty(disposition.AttemptIndices)
                disposition.Status = 'unsupported-no-configured-rays';
                disposition.Message = ...
                    'No amplitude/sign combinations were configured.';
            elseif any([attempts(disposition.AttemptIndices).Accepted])
                disposition.Status = 'accepted-local-seed';
                disposition.Supported = true;
                disposition.Message = ...
                    'At least one nonlinear corrected local seed was accepted.';
            else
                disposition.Status = 'attempted-no-accepted-seed';
                disposition.Supported = true;
                disposition.Message = ...
                    'All configured predictor/corrector attempts were rejected.';
            end
        catch exception
            disposition.Status = DirectionFailureStatus(exception.identifier);
            disposition.ErrorIdentifier = exception.identifier;
            disposition.Message = exception.message;
        end
        candidateRecords(recordIndex) = disposition;
    end

    seedReport = struct();
    seedReport.WorkflowStage = 'local-daughter-seed-search';
    seedReport.WorkflowConfigSchemaVersion = config.SchemaVersion;
    seedReport.ArtifactLayoutVersion = config.ArtifactLayoutVersion;
    seedReport.SourceRefinementFile = chain.Refinement.CanonicalPath;
    seedReport.SourceRefinementSHA256 = chain.Refinement.SHA256;
    seedReport.ValidatedArtifactChain = chain;
    seedReport.CandidateRecords = candidateRecords;
    seedReport.Attempts = attempts;
    seedReport.AcceptedAttemptIndices = find([attempts.Accepted]);
    seedReport.Status = SeedReportStatus(candidateRecords, attempts);
    seedReport.CreatedAt = Timestamp();
    seedReport.Scope = [ ...
        'Accepted results are local corrected seeds. Unsupported crossings ' ...
        'remain inventory records; daughter continuation and independent ' ...
        'identity validation are separate stages.'];
    seedReport.Reproducibility = struct( ...
        'MATLABVersion', version, ...
        'Amplitudes', config.BranchSwitch.Amplitudes, ...
        'Signs', config.BranchSwitch.Signs, ...
        'PredictorOptions', config.BranchSwitch.PredictorOptions, ...
        'RequireProductionReadyPredictor', true, ...
        'CorrectorOptions', config.BranchSwitch.CorrectorOptions, ...
        'DirectionResolver', floquet.workflow.internal.FloquetCallbackIdentity( ...
            OptionCallback(config.BranchSwitch, 'DirectionResolver')), ...
        'CorrectorFunction', floquet.workflow.internal.FloquetCallbackIdentity( ...
            OptionCallback(config.BranchSwitch, 'CorrectorFunction')));

    floquet.workflow.internal.WriteFloquetArtifact(config.Files.Seeds, ...
        struct('seedReport', seedReport), overwrite);
    floquet.workflow.internal.WriteFloquetAuditTable(attemptsFile, ...
        SeedAttemptSummary(candidateRecords, attempts), overwrite);
end

function callback = OptionCallback(options, field)
    callback = [];
    if isfield(options, field)
        callback = options.(field);
    end
end

function filename = ResolveAttemptsFile(config)
    if isfield(config.Files, 'SeedAttempts') && ...
            ~isempty(config.Files.SeedAttempts)
        filename = config.Files.SeedAttempts;
    else
        filename = fullfile(fileparts(config.Files.Seeds), ...
            'daughter_seed_attempts.csv');
    end
end

function summary = SeedAttemptSummary(candidateRecords, attempts)
    rowCount = numel(candidateRecords) + numel(attempts);
    rowKind = strings(rowCount, 1);
    candidateID = strings(rowCount, 1);
    candidateType = strings(rowCount, 1);
    directionID = strings(rowCount, 1);
    amplitude = NaN(rowCount, 1);
    signValue = NaN(rowCount, 1);
    supported = false(rowCount, 1);
    accepted = false(rowCount, 1);
    status = strings(rowCount, 1);
    errorIdentifier = strings(rowCount, 1);
    message = strings(rowCount, 1);
    for k = 1:numel(candidateRecords)
        rowKind(k) = "candidate-disposition";
        candidateID(k) = string(candidateRecords(k).CandidateID);
        candidateType(k) = string(candidateRecords(k).CandidateType);
        supported(k) = candidateRecords(k).Supported;
        status(k) = string(candidateRecords(k).Status);
        errorIdentifier(k) = string(candidateRecords(k).ErrorIdentifier);
        message(k) = string(candidateRecords(k).Message);
    end
    offset = numel(candidateRecords);
    for k = 1:numel(attempts)
        row = offset + k;
        rowKind(row) = "predictor-corrector-attempt";
        candidateID(row) = string(attempts(k).CandidateID);
        directionID(row) = string(attempts(k).DirectionID);
        amplitude(row) = attempts(k).Amplitude;
        signValue(row) = attempts(k).Sign;
        supported(row) = true;
        accepted(row) = attempts(k).Accepted;
        status(row) = string(attempts(k).Status);
        errorIdentifier(row) = string(attempts(k).ErrorIdentifier);
        message(row) = string(attempts(k).Message);
    end
    summary = table(rowKind, candidateID, candidateType, directionID, ...
        amplitude, signValue, supported, accepted, status, ...
        errorIdentifier, message);
end

function ValidateConfig(config)
    required = {'ExperimentRoot','BranchSwitch','Files'};
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
end

function directions = ResolveDirections(record, options)
    if record.CandidateCount > 1
        resolver = options.DirectionResolver;
        if isempty(resolver) || ~isa(resolver, 'function_handle')
            error('TemplateExperiment:RepeatedModeNeedsDirectionResolver', ...
                ['Candidate %s is a repeated critical group. Supply a ' ...
                 'symmetry/subspace DirectionResolver; raw eigensolver ' ...
                 'columns are not physical branch labels.'], record.CandidateID);
        end
        directions = resolver(record);
    else
        directions = struct('ID', 'simple_plus1', ...
            'EigenData', record.Diagnostics.eigenData);
    end
    if ~isstruct(directions) || isempty(directions) || ...
            ~all(isfield(directions, {'ID','EigenData'}))
        error('TemplateExperiment:InvalidDirections', ...
            'DirectionResolver must return structs with ID and EigenData.');
    end
end

function attempt = RunAttempt(record, direction, amplitude, signValue, options)
    attempt = EmptyAttempt();
    attempt.CandidateID = record.CandidateID;
    attempt.DirectionID = char(string(direction.ID));
    attempt.Amplitude = amplitude;
    attempt.Sign = signValue;
    diagnostics = record.Diagnostics;
    if isfield(diagnostics, 'parameters')
        attempt.Parameters = diagnostics.parameters;
    end
    try
        predictorOptions = options.PredictorOptions;
        predictorOptions.Amplitude = amplitude;
        predictorOptions.PerturbationSign = signValue;
        % Standardized experiment artifacts may be used for continuation;
        % diagnostic crossing vectors are never sufficient authority here.
        predictorOptions.RequireProductionReady = true;
        if isfield(diagnostics, 'localBranchTangent')
            predictorOptions.BranchTangent = diagnostics.localBranchTangent;
        end
        [deltaZ, zPredictor, predictorInfo] = ...
            floquet.predictBranchDirection( ...
            diagnostics.X, diagnostics.E, diagnostics.parameters, ...
            direction.EigenData, predictorOptions);
        attempt.DeltaZ = deltaZ;
        attempt.Predictor = zPredictor;
        attempt.PredictorInfo = predictorInfo;

        correctorOptions = options.CorrectorOptions;
        if isfield(predictorInfo, 'sectorTopology')
            correctorOptions.ExpectedTopology = predictorInfo.sectorTopology;
        end
        context = struct('Record', record, 'Direction', direction, ...
            'X', diagnostics.X, 'E', diagnostics.E, ...
            'Parameters', diagnostics.parameters, ...
            'PredictorInfo', predictorInfo, ...
            'CorrectorOptions', correctorOptions, ...
            'Amplitude', amplitude, 'Sign', signValue);
        callback = [];
        if isfield(options, 'CorrectorFunction')
            callback = options.CorrectorFunction;
        end
        [corrected, correctorInfo] = ...
            floquet.workflow.internal.ApplyFloquetBranchCorrector(context, callback);
        attempt.CorrectedSolution = corrected;
        attempt.CorrectorInfo = correctorInfo;
        if correctorInfo.accepted
            validationOptions = struct('ErrorOnFailure', false);
            if isfield(predictorInfo, 'sectorTopology') && ...
                    isstruct(predictorInfo.sectorTopology) && ...
                    isscalar(predictorInfo.sectorTopology) && ...
                    ~isempty(fieldnames(predictorInfo.sectorTopology))
                validationOptions.ReferenceTopology = ...
                    predictorInfo.sectorTopology;
            end
            independent = floquet.validatePeriodicOrbit(corrected, ...
                diagnostics.parameters, validationOptions);
        else
            independent = struct('accepted', false, ...
                'message', 'Corrector itself rejected the candidate.');
        end
        attempt.IndependentValidation = independent;
        attempt.Accepted = logical(correctorInfo.accepted) && ...
            logical(independent.accepted);
        if attempt.Accepted
            attempt.Status = 'accepted-corrected-local-seed';
            attempt.Message = 'Nonlinear periodic-orbit correction was accepted.';
        else
            attempt.Status = 'rejected-corrected-local-seed';
            if correctorInfo.accepted && ~independent.accepted
                attempt.Message = RecordMessage(independent, ...
                    'Independent periodic-orbit validation was rejected.');
            else
                attempt.Message = RecordMessage(correctorInfo, ...
                    'Nonlinear periodic-orbit correction was rejected.');
            end
        end
    catch exception
        attempt.Accepted = false;
        attempt.Status = 'failed-predictor-or-corrector';
        attempt.ErrorIdentifier = exception.identifier;
        attempt.Message = exception.message;
    end
end

function tf = IsPlusOne(type)
    tf = any(strcmpi(char(string(type)), {'+1','plus-one','plus1'}));
end

function status = DirectionFailureStatus(identifier)
    switch identifier
        case 'TemplateExperiment:RepeatedModeNeedsDirectionResolver'
            status = 'unsupported-repeated-mode-without-direction-resolver';
        otherwise
            status = 'failed-direction-resolution';
    end
end

function message = RecordMessage(record, fallback)
    message = fallback;
    if isstruct(record) && isfield(record, 'Message') && ...
            ~isempty(record.Message)
        message = char(string(record.Message));
    elseif isstruct(record) && isfield(record, 'message') && ...
            ~isempty(record.message)
        message = char(string(record.message));
    end
end

function status = SeedReportStatus(candidateRecords, attempts)
    if isempty(candidateRecords)
        status = 'complete-no-refined-candidates';
    elseif isempty(attempts)
        status = 'complete-no-supported-branch-switch';
    elseif any([attempts.Accepted])
        status = 'complete-with-accepted-local-seeds';
    else
        status = 'complete-no-accepted-local-seed';
    end
end

function attempt = EmptyAttempt()
    attempt = struct('CandidateID', '', 'DirectionID', '', ...
        'Amplitude', NaN, 'Sign', NaN, 'Accepted', false, ...
        'Status', 'not-evaluated', 'DeltaZ', [], 'Predictor', [], ...
        'PredictorInfo', struct(), 'Parameters', [], ...
        'CorrectedSolution', [], 'CorrectorInfo', struct(), ...
        'IndependentValidation', struct(), ...
        'ErrorIdentifier', '', 'Message', '');
end

function record = EmptyCandidateRecord()
    record = struct('CandidateID', '', 'CandidateType', '', ...
        'RefinementAccepted', false, 'Supported', false, ...
        'DirectionIDs', {{}}, 'AttemptIndices', [], ...
        'Status', 'not-evaluated', 'ErrorIdentifier', '', 'Message', '');
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
