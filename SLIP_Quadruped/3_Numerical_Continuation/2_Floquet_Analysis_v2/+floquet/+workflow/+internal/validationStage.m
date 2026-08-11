function validationReport = validationStage(config)
%VALIDATEFLOQUETEXPERIMENTSTAGE Audit continued rays, then held-out data.
%
% This is the first stage allowed to receive reference daughter paths.
% Generic checks read each branch.mat and report only evidence actually
% present: continuation acceptance, result dimensions, independent periodic
% revalidation, same-ray geometry, and post-correction gait labels.

    ValidateConfig(config);
    floquet.workflow.internal.RequireWritableFloquetWorkflowConfig(config);
    RequireFile(config.Files.Daughters, ...
        'Run the daughter-continuation stage first.');
    chain = floquet.workflow.internal.ValidateFloquetArtifactChain(config, 'daughters');
    loaded = load(chain.Daughters.CanonicalPath, 'daughterReport');
    if ~isfield(loaded, 'daughterReport') || ...
            ~isstruct(loaded.daughterReport) || ...
            ~isscalar(loaded.daughterReport)
        error('TemplateExperiment:DaughterReportContract', ...
            'Daughter inventory must contain one scalar daughterReport struct.');
    end
    daughterReport = loaded.daughterReport;
    validator = config.Validation.Function;
    if ~(isempty(validator) || isa(validator, 'function_handle'))
        error('TemplateExperiment:InvalidValidationFunction', ...
            'config.Validation.Function must be empty or a function handle.');
    end
    referenceFiles = ResolveReferenceFiles(config);
    if isempty(validator) && ~isempty(referenceFiles)
        error('TemplateExperiment:MissingValidationFunction', ...
            ['Held-out daughter files were configured, but no validation ' ...
             'function was supplied. A filename or gait label alone does ' ...
             'not verify branch identity.']);
    end
    validatorIdentity = floquet.workflow.internal.FloquetCallbackIdentity(validator);
    upstreamFiles = ChainPaths(chain);
    generatedDaughterFiles = DaughterBranchFiles(daughterReport);
    EnforceReferenceIndependence(referenceFiles, ...
        [upstreamFiles, generatedDaughterFiles]);
    referenceProvenance = ReferenceProvenance(referenceFiles);
    summaryFile = ResolveSummaryFile(config);
    overwrite = floquet.workflow.internal.FloquetWorkflowOverwrite(config);
    protected = [upstreamFiles, referenceFiles, generatedDaughterFiles];
    if validatorIdentity.FileBacked
        protected{end + 1} = validatorIdentity.ImplementationFile;
    end
    floquet.workflow.internal.PreflightFloquetArtifacts( ...
        {config.Files.Validation, summaryFile}, overwrite, protected);

    generic = BuildGenericEvidence(daughterReport);
    if isempty(validator)
        heldOut = struct('Accepted', false, 'Status', 'not-configured', ...
            'Claims', {{}}, ...
            'Message', 'No independent daughter data were supplied.');
    else
        validationConfig = config.Validation;
        validationConfig.ReferenceDaughterBranchFiles = referenceFiles;
        try
            heldOut = RunHeldOutValidator( ...
                validator, daughterReport, validationConfig);
        catch exception
            VerifyReferenceProvenance(referenceProvenance);
            VerifyCallbackIdentity(validatorIdentity);
            rethrow(exception);
        end
    end
    VerifyReferenceProvenance(referenceProvenance);
    VerifyCallbackIdentity(validatorIdentity);
    [overallAccepted, overallStatus] = OverallDisposition( ...
        generic, validatorIdentity.Configured, heldOut);

    validationReport = struct();
    validationReport.WorkflowStage = 'generic-or-held-out-validation';
    validationReport.WorkflowConfigSchemaVersion = config.SchemaVersion;
    validationReport.ArtifactLayoutVersion = config.ArtifactLayoutVersion;
    validationReport.Accepted = overallAccepted;
    validationReport.Status = overallStatus;
    validationReport.HeldOutRequiredForAcceptance = ...
        validatorIdentity.Configured;
    validationReport.SourceDaughterFile = chain.Daughters.CanonicalPath;
    validationReport.SourceDaughterSHA256 = chain.Daughters.SHA256;
    validationReport.ValidatedArtifactChain = chain;
    validationReport.GenericDaughterChecks = generic;
    validationReport.HeldOutValidation = heldOut;
    validationReport.HeldOutValidatorProvenance = struct( ...
        'Callback', validatorIdentity, ...
        'References', referenceProvenance);
    validationReport.Reproducibility = struct( ...
        'MATLABVersion', version, ...
        'Validator', validatorIdentity, ...
        'CanonicalReferenceFiles', {referenceFiles});
    validationReport.CreatedAt = Timestamp();
    validationReport.ClaimBoundary = [ ...
        'Generic checks do not establish unique daughter curves, approach ' ...
        'to the critical point, or gait identity. Those claims require a ' ...
        'project-specific validator and independent evidence.'];

    floquet.workflow.internal.WriteFloquetArtifact(config.Files.Validation, ...
        struct('validationReport', validationReport), overwrite);
    floquet.workflow.internal.WriteFloquetAuditTable(summaryFile, ...
        ValidationSummary(generic, heldOut), overwrite);
end

function filename = ResolveSummaryFile(config)
    if isfield(config.Files, 'ValidationSummary') && ...
            ~isempty(config.Files.ValidationSummary)
        filename = config.Files.ValidationSummary;
    else
        filename = fullfile(fileparts(config.Files.Validation), ...
            'validation_summary.csv');
    end
end

function summary = ValidationSummary(generic, heldOut)
    evidence = generic.RayEvidence;
    count = max(1, numel(evidence));
    rowKind = repmat("ray-evidence", count, 1);
    rayID = strings(count, 1);
    genericStatus = repmat(string(generic.Status), count, 1);
    inventoryAccepted = false(count, 1);
    fullInfoAccepted = false(count, 1);
    resultStructureValid = false(count, 1);
    validationEvidenceComplete = false(count, 1);
    pointCount = NaN(count, 1);
    outputValidationCheckedCount = zeros(count, 1);
    outputValidationAcceptedCount = zeros(count, 1);
    geometryAccepted = false(count, 1);
    sameRayAlignedCount = NaN(count, 1);
    evidenceAccepted = false(count, 1);
    failures = strings(count, 1);
    [heldOutAcceptedValue, heldOutAcceptedValid] = ...
        LogicalField(heldOut, 'Accepted');
    HeldOutAccepted = repmat(heldOutAcceptedValid && ...
        heldOutAcceptedValue, count, 1);
    heldOutStatus = repmat(string(TextField(heldOut, 'Status')), count, 1);
    heldOutMessage = repmat(string(TextField(heldOut, 'Message')), count, 1);
    if isempty(evidence)
        rowKind(1) = "overall-no-ray";
        if isfield(generic, 'GlobalFailures') && ...
                ~isempty(generic.GlobalFailures)
            failures(1) = string(strjoin(generic.GlobalFailures, ' | '));
        end
    else
        for k = 1:numel(evidence)
            rayID(k) = string(evidence(k).RayID);
            inventoryAccepted(k) = evidence(k).InventoryAccepted;
            fullInfoAccepted(k) = evidence(k).FullInfoAccepted;
            resultStructureValid(k) = evidence(k).ResultStructureValid;
            validationEvidenceComplete(k) = ...
                evidence(k).ValidationEvidenceComplete;
            pointCount(k) = evidence(k).PointCount;
            outputValidationCheckedCount(k) = ...
                evidence(k).OutputValidationCheckedCount;
            outputValidationAcceptedCount(k) = ...
                evidence(k).OutputValidationAcceptedCount;
            geometryAccepted(k) = evidence(k).GeometryAccepted;
            sameRayAlignedCount(k) = evidence(k).SameRayAlignedCount;
            evidenceAccepted(k) = evidence(k).EvidenceAccepted;
            failures(k) = string(strjoin(evidence(k).Failures, ' | '));
        end
    end
    summary = table(rowKind, rayID, genericStatus, inventoryAccepted, ...
        fullInfoAccepted, resultStructureValid, ...
        validationEvidenceComplete, pointCount, outputValidationCheckedCount, ...
        outputValidationAcceptedCount, geometryAccepted, ...
        sameRayAlignedCount, evidenceAccepted, failures, heldOutStatus, ...
        HeldOutAccepted, heldOutMessage);
end

function referenceFiles = ResolveReferenceFiles(config)
    configured = config.Validation.ReferenceDaughterBranchFiles;
    if isempty(configured)
        referenceFiles = {};
        return
    end
    referenceFiles = cellstr(string(configured));
    referenceFiles = referenceFiles(:).';
    for k = 1:numel(referenceFiles)
        filename = referenceFiles{k};
        if isempty(strtrim(filename))
            error('TemplateExperiment:MissingReferenceDaughter', ...
                'Held-out reference paths must be nonempty.');
        end
        if ~IsAbsolutePath(filename)
            if ~isfield(config, 'ExperimentRoot')
                error('TemplateExperiment:MissingReferenceDaughter', [ ...
                    'ExperimentRoot is required to resolve relative held-out ' ...
                    'reference paths.']);
            end
            filename = fullfile(config.ExperimentRoot, filename);
        end
        if ~isfile(filename)
            error('TemplateExperiment:MissingReferenceDaughter', ...
                'Held-out daughter file does not exist: %s', filename);
        end
        referenceFiles{k} = ...
            char(java.io.File(filename).getCanonicalPath());
    end
    keys = string(referenceFiles);
    if ispc
        keys = lower(keys);
    end
    if numel(unique(keys)) ~= numel(keys)
        error('TemplateExperiment:DuplicateReferenceDaughter', ...
            'Held-out daughter references must resolve to unique files.');
    end
end

function report = RunHeldOutValidator(validator, daughterReport, options)
    try
        report = validator(daughterReport, options);
    catch exception
        report = struct('Accepted', false, ...
            'Status', 'validator-exception', ...
            'Claims', {{ ...
                'held-out validator execution failed before claim evaluation'}}, ...
            'Message', exception.message, ...
            'ErrorIdentifier', exception.identifier);
        return
    end
    ValidateHeldOutReport(report);
    report.Accepted = logical(report.Accepted);
end

function ValidateHeldOutReport(report)
    if ~isstruct(report) || ~isscalar(report)
        error('TemplateExperiment:HeldOutReportContract', ...
            'Held-out validator output must be one scalar struct.');
    end
    [~, acceptedValid] = LogicalField(report, 'Accepted');
    if ~acceptedValid
        error('TemplateExperiment:HeldOutReportContract', ...
            'Held-out report Accepted must be scalar logical or numeric 0/1.');
    end
    status = TextField(report, 'Status');
    if isempty(strtrim(status))
        error('TemplateExperiment:HeldOutReportContract', ...
            'Held-out report Status must be nonempty scalar text.');
    end
    claimFields = {'Claims','ClaimResults','Checks'};
    declared = false;
    for k = 1:numel(claimFields)
        if isfield(report, claimFields{k}) && ...
                ~isempty(report.(claimFields{k}))
            declared = true;
            break
        end
    end
    if ~declared
        error('TemplateExperiment:HeldOutReportContract', [ ...
            'Held-out report must declare nonempty Claims, ClaimResults, ' ...
            'or Checks so acceptance and rejection remain auditable.']);
    end
end

function [accepted, status] = OverallDisposition( ...
        generic, heldOutConfigured, heldOut)
    genericAccepted = isfield(generic, ...
        'HasEvidenceBackedContinuedBranchCandidate') && ...
        isequal(generic.HasEvidenceBackedContinuedBranchCandidate, true);
    [heldOutAccepted, heldOutFlagValid] = ...
        LogicalField(heldOut, 'Accepted');
    accepted = genericAccepted && (~heldOutConfigured || ...
        (heldOutFlagValid && heldOutAccepted));
    if ~genericAccepted
        status = 'rejected-no-evidence-backed-daughter-ray';
    elseif heldOutConfigured && ~(heldOutFlagValid && heldOutAccepted)
        status = 'rejected-held-out-validation';
    elseif heldOutConfigured
        status = 'accepted-generic-and-held-out-validation';
    else
        status = 'accepted-generic-evidence-no-held-out-identity-claim';
    end
end

function provenance = ReferenceProvenance(referenceFiles)
    provenance = repmat(struct('CanonicalPath', '', 'SHA256', ''), ...
        1, numel(referenceFiles));
    for k = 1:numel(referenceFiles)
        provenance(k).CanonicalPath = referenceFiles{k};
        provenance(k).SHA256 = floquet.workflow.internal.FloquetFileSHA256(referenceFiles{k});
    end
end

function EnforceReferenceIndependence(referenceFiles, prohibitedFiles)
    if isempty(referenceFiles) || isempty(prohibitedFiles)
        return
    end
    referenceKeys = CanonicalPathKeys(referenceFiles);
    prohibitedKeys = CanonicalPathKeys(prohibitedFiles);
    aliases = ismember(referenceKeys, prohibitedKeys);
    if any(aliases)
        filename = referenceFiles{find(aliases, 1)};
        error('TemplateExperiment:ReferenceNotIndependent', [ ...
            'Held-out reference %s aliases the parent branch, an upstream ' ...
            'workflow artifact, or a generated daughter branch. Independent ' ...
            'validation evidence must come from a distinct frozen file.'], ...
            filename);
    end
end

function keys = CanonicalPathKeys(filenames)
    keys = strings(1, numel(filenames));
    for k = 1:numel(filenames)
        keys(k) = string(java.io.File( ...
            filenames{k}).getCanonicalPath());
    end
    if ispc
        keys = lower(keys);
    end
end

function VerifyReferenceProvenance(provenance)
    for k = 1:numel(provenance)
        filename = provenance(k).CanonicalPath;
        if ~isfile(filename) || ...
                ~strcmp(floquet.workflow.internal.FloquetFileSHA256(filename), provenance(k).SHA256)
            error('TemplateExperiment:ReferenceChangedDuringValidation', [ ...
                'Held-out reference changed while the validator was running: ' ...
                '%s. No validation artifact was written.'], filename);
        end
    end
end

function VerifyCallbackIdentity(identity)
    if ~identity.FileBacked
        return
    end
    filename = identity.ImplementationFile;
    if ~isfile(filename) || ~strcmp(floquet.workflow.internal.FloquetFileSHA256(filename), ...
            identity.ImplementationSHA256)
        error('TemplateExperiment:ValidatorChangedDuringValidation', [ ...
            'Held-out validator implementation changed while it was running: ' ...
            '%s. No validation artifact was written.'], filename);
    end
end

function paths = ChainPaths(chain)
    fields = {'Parent','Discovery','Refinement','Seeds','Daughters'};
    paths = cell(1, numel(fields));
    for k = 1:numel(fields)
        paths{k} = chain.(fields{k}).CanonicalPath;
    end
end

function paths = DaughterBranchFiles(daughterReport)
    paths = {};
    if ~isfield(daughterReport, 'Records') || ...
            ~isstruct(daughterReport.Records)
        return
    end
    records = daughterReport.Records;
    for k = 1:numel(records)
        filename = TextField(records(k), 'OutputFile');
        if ~isempty(filename) && isfile(filename)
            paths{end + 1} = ...
                char(java.io.File(filename).getCanonicalPath()); %#ok<AGROW>
        end
    end
end

function tf = IsAbsolutePath(filename)
    if ispc
        tf = ~isempty(regexp(filename, ...
            '^[A-Za-z]:[\\/]|^\\\\', 'once'));
    else
        tf = startsWith(filename, filesep);
    end
end

function ValidateConfig(config)
    required = {'Validation','Files'};
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

function generic = BuildGenericEvidence(daughterReport)
    recordsContractValid = true;
    if isfield(daughterReport, 'Records')
        records = daughterReport.Records;
        if ~isstruct(records)
            records = struct([]);
            recordsContractValid = false;
        end
    else
        records = struct([]);
        recordsContractValid = false;
    end
    evidence = repmat(EmptyRayEvidence(), 1, numel(records));
    for k = 1:numel(records)
        evidence(k) = InspectRay(records(k));
    end

    [continuationEnabled, continuationEnabledFlagValid] = ...
        LogicalField(daughterReport, 'ContinuationEnabled');
    globalFailures = {};
    if ~continuationEnabledFlagValid
        globalFailures = AppendFailure(globalFailures, [ ...
            'daughter inventory ContinuationEnabled must be scalar logical ' ...
            'or a finite numeric 0/1 value']);
        for k = 1:numel(evidence)
            evidence(k).Failures = AppendFailure(evidence(k).Failures, ...
                globalFailures{end});
            evidence(k).EvidenceAccepted = false;
        end
    end
    if ~recordsContractValid
        globalFailures = AppendFailure(globalFailures, ...
            'daughter inventory Records must be a struct array');
        for k = 1:numel(evidence)
            evidence(k).Failures = AppendFailure(evidence(k).Failures, ...
                globalFailures{end});
            evidence(k).EvidenceAccepted = false;
        end
    end
    inventoryContractValid = continuationEnabledFlagValid && ...
        recordsContractValid;

    generic = struct();
    generic.Status = GenericStatus(continuationEnabled, ...
        inventoryContractValid, evidence);
    generic.ContinuationEnabled = continuationEnabled;
    generic.ContinuationEnabledFlagValid = continuationEnabledFlagValid;
    generic.RecordsContractValid = recordsContractValid;
    generic.RayCount = numel(records);
    generic.WorkflowAcceptedRayCount = CountTrue(records, 'Accepted');
    generic.EvidenceBackedRayCount = nnz([evidence.EvidenceAccepted]);
    generic.EvidenceBackedBranchCandidateCount = ...
        generic.EvidenceBackedRayCount;
    generic.HasEvidenceBackedContinuedBranchCandidate = ...
        generic.EvidenceBackedRayCount > 0;
    generic.RayEvidence = evidence;
    generic.FailureSummaries = FailureSummaries(evidence);
    generic.GlobalFailures = globalFailures;
    generic.ClaimsNotEstablished = { ...
        'duplicate-curve elimination', ...
        'asymptotic approach to the critical point', ...
        'physical gait identity without held-out validation'};
end

function evidence = InspectRay(record)
    evidence = EmptyRayEvidence();
    evidence.RayID = TextField(record, 'RayID');
    evidence.RecordStatus = TextField(record, 'Status');
    [evidence.InventoryAccepted, inventoryFlagValid] = ...
        LogicalField(record, 'Accepted');
    if ~inventoryFlagValid
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'inventory Accepted must be scalar logical or finite numeric 0/1');
    end
    evidence.OutputFile = TextField(record, 'OutputFile');
    if isempty(evidence.OutputFile) || ~isfile(evidence.OutputFile)
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'continued branch artifact is missing');
        return
    end
    evidence.OutputFileExists = true;
    evidence.ExpectedOutputSHA256 = TextField(record, 'OutputSHA256');
    if isempty(regexp(evidence.ExpectedOutputSHA256, ...
            '^[0-9a-fA-F]{64}$', 'once'))
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'continued branch record lacks a valid OutputSHA256');
        return
    end
    evidence.ObservedOutputSHA256 = ...
        floquet.workflow.internal.FloquetFileSHA256(evidence.OutputFile);
    evidence.OutputFingerprintValid = strcmp( ...
        lower(evidence.ExpectedOutputSHA256), ...
        evidence.ObservedOutputSHA256);
    if ~evidence.OutputFingerprintValid
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'continued branch artifact SHA-256 does not match its inventory');
        return
    end

    try
        loaded = load(evidence.OutputFile, 'results', 'info');
    catch exception
        evidence.Failures = AppendFailure(evidence.Failures, ...
            sprintf('could not load branch artifact: %s', exception.message));
        return
    end
    if ~isfield(loaded, 'results')
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'branch artifact has no results variable');
        return
    end
    if ~isfield(loaded, 'info') || ~isstruct(loaded.info) || ...
            ~isscalar(loaded.info)
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'branch artifact has no scalar info variable');
        return
    end
    results = loaded.results;
    info = loaded.info;
    evidence.SchemaVersion = TextField(info, 'schemaVersion');
    [evidence.ResultStructureValid, resultMessage] = ...
        ValidateResultStructure(results);
    if isnumeric(results) && ismatrix(results)
        evidence.ResultColumnCount = size(results, 2);
    end
    if ~evidence.ResultStructureValid
        evidence.Failures = AppendFailure(evidence.Failures, resultMessage);
    end
    [evidence.FullInfoAccepted, fullInfoFlagValid] = ...
        LogicalField(info, 'accepted');
    if ~fullInfoFlagValid
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'info.accepted must be scalar logical or finite numeric 0/1');
    end
    [evidence.ValidationEvidenceComplete, evidenceFlagValid] = ...
        LogicalField(info, 'validationEvidenceComplete');
    evidence.ValidationEvidenceFlagValid = evidenceFlagValid;
    if ~evidenceFlagValid
        evidence.Failures = AppendFailure(evidence.Failures, [ ...
            'info.validationEvidenceComplete must be scalar logical or ' ...
            'finite numeric 0/1']);
    elseif ~evidence.ValidationEvidenceComplete
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'continuation validation evidence is explicitly incomplete');
    end
    if strcmp(evidence.SchemaVersion, 'daughter-continuation-v1.1')
        [evidence.ValidationAuthorityEligible, authorityValid] = ...
            NestedLogicalField(info, ...
                {'validationAuthority','scientificAcceptanceEligible'});
        [evidence.OutputValidationCoverageComplete, coverageValid] = ...
            LogicalField(info, 'outputValidationCoverageComplete');
        [evidence.AcceptedOutputTopologyEvidenceComplete, topologyValid] = ...
            LogicalField(info, 'acceptedOutputTopologyEvidenceComplete');
        [acceptedMaskValid, acceptedMask] = StrictLogicalVectorField( ...
            info, 'outputAcceptedEvidenceMask', size(results, 2));
        evidence.OutputAcceptedEvidenceCount = nnz(acceptedMask);
        if ~authorityValid || ~evidence.ValidationAuthorityEligible
            evidence.Failures = AppendFailure(evidence.Failures, [ ...
                'v1.1 continuation lacks production scientific validation ' ...
                'authority']);
        end
        if ~coverageValid || ~evidence.OutputValidationCoverageComplete
            evidence.Failures = AppendFailure(evidence.Failures, ...
                'v1.1 continuation lacks complete output-validation coverage');
        end
        if ~topologyValid || ...
                ~evidence.AcceptedOutputTopologyEvidenceComplete
            evidence.Failures = AppendFailure(evidence.Failures, [ ...
                'v1.1 continuation lacks complete accepted-output topology ' ...
                'evidence']);
        end
        if ~acceptedMaskValid
            evidence.Failures = AppendFailure(evidence.Failures, ...
                'v1.1 outputAcceptedEvidenceMask is missing or malformed');
        end
    end
    evidence.PointCount = NumericField(info, 'pointCount');
    evidence.PointCountConsistent = evidence.ResultStructureValid && ...
        isfinite(evidence.PointCount) && evidence.PointCount >= 1 && ...
        evidence.PointCount == floor(evidence.PointCount) && ...
        evidence.PointCount == evidence.ResultColumnCount && ...
        size(results, 1) == 29;
    if inventoryFlagValid && ~evidence.InventoryAccepted
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'inventory did not accept this continuation');
    end
    if fullInfoFlagValid && ~evidence.FullInfoAccepted
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'full continuation info did not accept this continuation');
    end
    if ~evidence.PointCountConsistent
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'result dimensions disagree with recorded point count');
    end

    [checkedCount, acceptedCount, allAccepted, validationContractValid, ...
        validationContractMessage] = InspectOutputValidation( ...
            info, evidence.ResultColumnCount);
    evidence.OutputValidationCheckedCount = checkedCount;
    evidence.OutputValidationAcceptedCount = acceptedCount;
    evidence.OutputValidationAllAccepted = allAccepted;
    evidence.OutputValidationContractValid = validationContractValid;
    if ~validationContractValid
        evidence.Failures = AppendFailure(evidence.Failures, ...
            validationContractMessage);
    elseif checkedCount == 0
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'no independently revalidated output points were recorded');
    elseif ~allAccepted
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'at least one independently revalidated output point failed');
    end

    if isfield(info, 'daughterGeometry') && ...
            isstruct(info.daughterGeometry) && ...
            isscalar(info.daughterGeometry)
        geometry = info.daughterGeometry;
        [evidence.GeometryChecked, geometryCheckedFlagValid] = ...
            LogicalField(geometry, 'checked');
        [evidence.GeometryAccepted, geometryAcceptedFlagValid] = ...
            LogicalField(geometry, 'accepted');
        evidence.SameRayAlignedCount = NumericField( ...
            geometry, 'sameRayAlignedCount');
    else
        geometryCheckedFlagValid = false;
        geometryAcceptedFlagValid = false;
    end
    if ~geometryCheckedFlagValid || ~geometryAcceptedFlagValid
        evidence.Failures = AppendFailure(evidence.Failures, [ ...
            'daughter geometry checked/accepted flags must be scalar ' ...
            'logical or finite numeric 0/1']);
    end
    if geometryCheckedFlagValid && ~evidence.GeometryChecked
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'same-ray output geometry was not checked');
    elseif geometryAcceptedFlagValid && ~evidence.GeometryAccepted
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'same-ray output geometry was rejected');
    end
    if ~(isfinite(evidence.SameRayAlignedCount) && ...
            evidence.SameRayAlignedCount >= 0 && ...
            evidence.SameRayAlignedCount == ...
                floor(evidence.SameRayAlignedCount) && ...
            evidence.SameRayAlignedCount <= evidence.ResultColumnCount)
        evidence.Failures = AppendFailure(evidence.Failures, ...
            'same-ray aligned count is missing or inconsistent');
    end

    evidence.PostCorrectionGaitNames = UniqueTextField(info, 'gaitNames');
    evidence.PostCorrectionGaitAbbreviations = ...
        UniqueTextField(info, 'gaitAbbreviations');
    evidence.EvidenceAccepted = isempty(evidence.Failures);
end

function [value, valid] = NestedLogicalField(source, path)
    value = false;
    valid = false;
    for k = 1:numel(path) - 1
        if ~isstruct(source) || ~isscalar(source) || ...
                ~isfield(source, path{k})
            return
        end
        source = source.(path{k});
    end
    [value, valid] = LogicalField(source, path{end});
end

function [valid, mask] = StrictLogicalVectorField(source, field, count)
    valid = false;
    mask = false(1, count);
    if ~isstruct(source) || ~isscalar(source) || ~isfield(source, field)
        return
    end
    raw = source.(field);
    valid = isvector(raw) && numel(raw) == count && ...
        (islogical(raw) || (isnumeric(raw) && isreal(raw) && ...
         all(isfinite(raw(:))) && all(raw(:) == 0 | raw(:) == 1)));
    if valid
        mask = logical(raw(:).');
    end
end

function [checkedCount, acceptedCount, allAccepted, contractValid, message] = ...
        InspectOutputValidation(info, expectedCount)
    checkedCount = 0;
    acceptedCount = 0;
    allAccepted = false;
    contractValid = false;
    message = 'output-validation arrays are missing or malformed';
    if ~isfield(info, 'outputValidatedMask') || ...
            ~isfield(info, 'outputValidation')
        return
    end
    rawMask = info.outputValidatedMask;
    if ~(isvector(rawMask) && ...
            (islogical(rawMask) || ...
             (isnumeric(rawMask) && isreal(rawMask) && ...
              all(isfinite(rawMask(:))) && ...
              all(rawMask(:) == 0 | rawMask(:) == 1))) && ...
            numel(rawMask) == expectedCount)
        message = [ ...
            'outputValidatedMask must be a logical/finite-0-or-1 vector ' ...
            'with one entry per stored branch point'];
        return
    end
    mask = logical(rawMask(:).');
    checkedCount = nnz(mask);
    if ~isstruct(info.outputValidation) || ...
            numel(info.outputValidation) ~= numel(mask)
        message = [ ...
            'outputValidation must be a struct array with one entry per ' ...
            'stored branch point'];
        return
    end
    contractValid = true;
    message = '';
    if checkedCount == 0
        return
    end
    checked = info.outputValidation(mask);
    accepted = false(1, numel(checked));
    for k = 1:numel(checked)
        [accepted(k), valid] = LogicalField(checked(k), 'accepted');
        if ~valid
            contractValid = false;
            message = [ ...
                'every checked outputValidation.accepted flag must be ' ...
                'scalar logical or finite numeric 0/1'];
            return
        end
    end
    acceptedCount = nnz(accepted);
    allAccepted = all(accepted);
end

function status = GenericStatus(enabled, inventoryContractValid, evidence)
    if ~inventoryContractValid
        status = 'invalid-daughter-inventory-contract';
    elseif ~enabled
        status = 'valid-no-daughter-continuation-applied';
    elseif isempty(evidence)
        status = 'valid-no-qualified-rays';
    elseif any([evidence.EvidenceAccepted])
        status = 'complete-with-evidence-backed-continued-rays';
    else
        status = 'complete-no-evidence-backed-continued-ray';
    end
end

function summaries = FailureSummaries(evidence)
    summaries = {};
    for k = 1:numel(evidence)
        if isempty(evidence(k).Failures)
            continue
        end
        summaries{end + 1} = sprintf('%s: %s', evidence(k).RayID, ...
            strjoin(evidence(k).Failures, ' | ')); %#ok<AGROW>
    end
end

function count = CountTrue(records, field)
    count = 0;
    for k = 1:numel(records)
        [value, valid] = LogicalField(records(k), field);
        count = count + double(valid && value);
    end
end

function [value, valid] = LogicalField(source, field)
    value = false;
    valid = false;
    if isstruct(source) && isscalar(source) && isfield(source, field) && ...
            isscalar(source.(field))
        candidate = source.(field);
        valid = islogical(candidate) || ...
            (isnumeric(candidate) && isreal(candidate) && ...
             isfinite(candidate) && any(candidate == [0 1]));
        if valid
            value = logical(candidate);
        end
    end
end

function value = NumericField(source, field)
    value = NaN;
    if isstruct(source) && isscalar(source) && isfield(source, field) && ...
            isnumeric(source.(field)) && isreal(source.(field)) && ...
            isscalar(source.(field)) && isfinite(source.(field))
        value = source.(field);
    end
end

function [valid, message] = ValidateResultStructure(results)
    valid = false;
    message = ...
        'results must be a real numeric, nonempty, exactly 29-by-N matrix';
    if ~isnumeric(results) || ~isreal(results) || ~ismatrix(results) || ...
            size(results, 1) ~= 29 || size(results, 2) < 1
        return
    end
    if any(~isfinite(results(1:22, :)), 'all')
        message = 'state/event-time rows 1:22 contain a nonfinite value';
        return
    end
    parameters = results(23:29, :);
    allowedInfiniteInertia = false(size(parameters));
    allowedInfiniteInertia(3, :) = ...
        isinf(parameters(3, :)) & parameters(3, :) > 0;
    if any(~(isfinite(parameters) | allowedInfiniteInertia), 'all')
        message = [ ...
            'parameter rows contain a nonfinite value other than the ' ...
            'supported positive-Inf inertia in branch row 25'];
        return
    end
    valid = true;
    message = '';
end

function value = TextField(source, field)
    value = '';
    if isstruct(source) && isscalar(source) && isfield(source, field) && ...
            (ischar(source.(field)) || ...
             (isstring(source.(field)) && isscalar(source.(field))))
        value = char(source.(field));
    end
end

function values = UniqueTextField(source, field)
    values = {};
    if ~isstruct(source) || ~isscalar(source) || ~isfield(source, field)
        return
    end
    try
        values = unique(cellstr(string(source.(field))), 'stable');
    catch
        values = {};
    end
end

function failures = AppendFailure(failures, message)
    failures{end + 1} = message;
end

function evidence = EmptyRayEvidence()
    evidence = struct('RayID', '', 'RecordStatus', '', ...
        'OutputFile', '', 'OutputFileExists', false, ...
        'ExpectedOutputSHA256', '', 'ObservedOutputSHA256', '', ...
        'OutputFingerprintValid', false, ...
        'SchemaVersion', '', ...
        'InventoryAccepted', false, 'FullInfoAccepted', false, ...
        'ResultStructureValid', false, ...
        'ValidationEvidenceComplete', false, ...
        'ValidationEvidenceFlagValid', false, ...
        'ValidationAuthorityEligible', false, ...
        'OutputValidationCoverageComplete', false, ...
        'AcceptedOutputTopologyEvidenceComplete', false, ...
        'OutputAcceptedEvidenceCount', 0, ...
        'PointCount', NaN, 'ResultColumnCount', NaN, ...
        'PointCountConsistent', false, ...
        'OutputValidationCheckedCount', 0, ...
        'OutputValidationAcceptedCount', 0, ...
        'OutputValidationAllAccepted', false, ...
        'OutputValidationContractValid', false, ...
        'GeometryChecked', false, 'GeometryAccepted', false, ...
        'SameRayAlignedCount', NaN, ...
        'PostCorrectionGaitNames', {{}}, ...
        'PostCorrectionGaitAbbreviations', {{}}, ...
        'EvidenceAccepted', false, 'Failures', {{}});
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
