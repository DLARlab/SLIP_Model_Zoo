function analysis = discoveryStage(config)
%RUNFLOQUETDISCOVERYSTAGE Run a parent-only scan over every branch column.
%
% ANALYSIS = RUNFLOQUETDISCOVERYSTAGE(CONFIG) is the reusable implementation
% behind an experiment's main_RunDiscovery wrapper.  It deliberately passes
% [] as the branch selection, freezes stable candidate IDs, saves the
% canonical MAT artifact, and writes flat CSV audit views.  The CSV files are
% derived outputs and are never read by later numerical stages.

    ValidateConfig(config);
    floquet.workflow.internal.RequireWritableFloquetWorkflowConfig(config);
    floquet.workflow.internal.EnforceFloquetInformationBarrier(config, 'parent-only discovery');
    floquet.workflow.internal.AddFloquetNumericalPaths(config);
    files = ResolveOutputFiles(config);
    overwrite = floquet.workflow.internal.FloquetWorkflowOverwrite(config);
    parentIdentity = floquet.workflow.internal.FloquetParentIdentity(config);
    if ExportOnly(config)
        analysis = LoadCanonicalAnalysis(files.Discovery);
        RequireAnalysisContract(analysis);
        floquet.workflow.internal.ValidateFloquetDiscoveryArtifact(analysis, config, true);
        ExportAuditViews(files, analysis, overwrite, true, ...
            {files.Discovery, parentIdentity.CanonicalPath});
        return
    end
    RejectUnauthorizedNonProductionEvaluator(config);
    outputs = {files.Discovery, ...
        files.CandidateInventory, files.RejectedPoints, ...
        files.RejectedIntervals};
    floquet.workflow.internal.PreflightFloquetArtifacts(outputs, overwrite, ...
        {parentIdentity.CanonicalPath});
    checkpoint = ConfiguredCheckpoint(config.AnalysisOptions);
    if ~isempty(checkpoint)
        floquet.workflow.internal.PreflightFloquetArtifacts([outputs {checkpoint}], true, ...
            {parentIdentity.CanonicalPath});
    end
    if isempty(which('floquet.analyzeBranch'))
        error('TemplateExperiment:MissingAnalyzeFloquetBranch', ...
            ['floquet.analyzeBranch is not on the MATLAB path. Add the ' ...
             'Floquet-v2 root or update this template to the installed API.']);
    end

    EnsureParentDirectory(files.Discovery);
    analysisOptions = config.AnalysisOptions;
    analysisOptions.SaveAnalysis = true;
    analysisOptions.OutputFile = files.Discovery;
    analysisOptions.Overwrite = overwrite;
    parentBranchFile = parentIdentity.CanonicalPath;
    analysis = floquet.analyzeBranch( ...
        parentBranchFile, [], analysisOptions);
    RequireAnalysisContract(analysis);
    analysis.candidates = AttachStableCandidateIDs( ...
        analysis.candidates, analysis.sampleIndices);

    stage = struct();
    stage.Name = 'parent-only-full-branch-discovery';
    stage.WorkflowConfigSchemaVersion = config.SchemaVersion;
    stage.ArtifactLayoutVersion = config.ArtifactLayoutVersion;
    stage.ParentBranchFile = parentBranchFile;
    stage.ParentIdentity = parentIdentity;
    stage.FullBranchSelection = true;
    if analysis.provenance.productionEvaluator
        stage.Authority = 'production-scientific-authority';
        stage.ScientificUseAllowed = true;
    else
        stage.Authority = 'test-only-nonproduction-authority';
        stage.ScientificUseAllowed = false;
    end
    stage.CreatedAt = Timestamp();
    stage.ProhibitedInputs = { ...
        'daughter branches', 'expected crossing locations', ...
        'expected gait labels', 'hand-selected scan windows'};
    stage.AuditViewPolicy = [ ...
        'CSV files are flat, derived hand-audit views; the MAT analysis ' ...
        'artifact is the sole numerical authority.'];
    stage.Reproducibility = struct( ...
        'MATLABVersion', version, ...
        'AnalysisOptions', analysis.options, ...
        'ComputeEvaluator', floquet.workflow.internal.FloquetCallbackIdentity( ...
            AnalysisComputeFunction(config.AnalysisOptions)));
    analysis.workflowStage = stage;
    floquet.workflow.internal.ValidateFloquetDiscoveryArtifact(analysis, config, true);

    % AnalyzeFloquetBranch has already installed a valid atomic canonical
    % file (and only then may delete its checkpoint). Enrich that complete
    % artifact atomically; if this rewrite fails, the analyzer's file remains.
    floquet.workflow.internal.WriteFloquetArtifact(files.Discovery, ...
        struct('analysis', analysis, 'stage', stage), true);
    ExportAuditViews(files, analysis, overwrite, false, ...
        {files.Discovery, parentIdentity.CanonicalPath});
end

function tf = ExportOnly(config)
    tf = false;
    if ~isfield(config, 'Discovery') || ...
            ~isfield(config.Discovery, 'ExportOnly')
        return
    end
    value = config.Discovery.ExportOnly;
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
        error('TemplateExperiment:ExportOnly', ...
            'Discovery.ExportOnly must be scalar logical.');
    end
    tf = logical(value);
end

function analysis = LoadCanonicalAnalysis(filename)
    RequireFile(filename, ...
        'ExportOnly requires an existing canonical discovery artifact.');
    loaded = load(filename, 'analysis');
    if ~isfield(loaded, 'analysis')
        error('TemplateExperiment:DiscoveryContract', ...
            'Discovery MAT file does not contain variable analysis.');
    end
    analysis = loaded.analysis;
end

function ExportAuditViews(files, analysis, overwrite, missingOnly, protected)
    targets = {files.CandidateInventory, files.RejectedPoints, ...
        files.RejectedIntervals};
    floquet.workflow.internal.PreflightFloquetArtifacts(targets, overwrite || missingOnly, protected);
    if overwrite || ~isfile(files.CandidateInventory)
        WriteCandidateInventory( ...
            files.CandidateInventory, analysis.candidates, overwrite);
    end
    if overwrite || ~isfile(files.RejectedPoints)
        WriteRejectedPoints(files.RejectedPoints, analysis, overwrite);
    end
    if overwrite || ~isfile(files.RejectedIntervals)
        WriteRejectedIntervals(files.RejectedIntervals, analysis, overwrite);
    end
end

function filename = ConfiguredCheckpoint(options)
    filename = '';
    if isfield(options, 'CheckpointFile') && ~isempty(options.CheckpointFile)
        value = options.CheckpointFile;
        if ~(ischar(value) || (isstring(value) && isscalar(value)))
            error('TemplateExperiment:CheckpointPath', ...
                'AnalysisOptions.CheckpointFile must be scalar text.');
        end
        filename = char(string(value));
    end
end

function callback = AnalysisComputeFunction(options)
    if isfield(options, 'ComputeFunction') && ...
            ~isempty(options.ComputeFunction)
        callback = options.ComputeFunction;
    else
        callback = @floquet.computeFDM;
    end
end

function RejectUnauthorizedNonProductionEvaluator(config)
    callback = AnalysisComputeFunction(config.AnalysisOptions);
    if ~isa(callback, 'function_handle')
        error('TemplateExperiment:DiscoveryEvaluator', ...
            'AnalysisOptions.ComputeFunction must be a function handle.');
    end
    production = floquet.internal.provenance.evaluatorIdentity( ...
        callback, 'floquet.computeFDM');
    if production
        return
    end
    allow = false;
    if isfield(config, 'Testing') && isstruct(config.Testing) && ...
            isscalar(config.Testing) && ...
            isfield(config.Testing, 'AllowNonProductionDiscovery')
        value = config.Testing.AllowNonProductionDiscovery;
        if ~(isscalar(value) && (islogical(value) || ...
                (isnumeric(value) && isreal(value) && isfinite(value) && ...
                 any(value == [0 1]))))
            error('TemplateExperiment:TestingConfiguration', [ ...
                'Testing.AllowNonProductionDiscovery must be scalar logical ' ...
                'or numeric 0/1.']);
        end
        allow = logical(value);
    end
    if ~allow
        error('TemplateExperiment:NonProductionDiscovery', [ ...
            'A nonproduction discovery evaluator is permitted only with ' ...
            'config.Testing.AllowNonProductionDiscovery=true.']);
    end
end

function ValidateConfig(config)
    if nargin < 1 || ~isstruct(config) || ~isscalar(config)
        error('TemplateExperiment:InvalidConfiguration', ...
            'The shared workflow requires one scalar ExperimentConfig struct.');
    end
    required = {'ExperimentRoot','ParentBranchFile','AnalysisOptions','Files'};
    for k = 1:numel(required)
        if ~isfield(config, required{k})
            error('TemplateExperiment:MissingConfiguration', ...
                'ExperimentConfig is missing field %s.', required{k});
        end
    end
    if ExportOnly(config)
        return
    end
    floquet.workflow.internal.ResolveFloquetParentBranch(config);
end

function files = ResolveOutputFiles(config)
    if ~isfield(config.Files, 'Discovery') || ...
            isempty(config.Files.Discovery)
        error('TemplateExperiment:MissingDiscoveryPath', ...
            'config.Files.Discovery is required.');
    end
    files = config.Files;
    folder = fileparts(files.Discovery);
    files = DefaultFile(files, 'CandidateInventory', ...
        fullfile(folder, 'candidate_inventory.csv'));
    files = DefaultFile(files, 'RejectedPoints', ...
        fullfile(folder, 'rejected_points.csv'));
    files = DefaultFile(files, 'RejectedIntervals', ...
        fullfile(folder, 'rejected_intervals.csv'));
end

function source = DefaultFile(source, field, value)
    if ~isfield(source, field) || isempty(source.(field))
        source.(field) = value;
    end
end

function RequireAnalysisContract(analysis)
    required = {'candidates','sampleIndices','rejectedReport'};
    if ~isstruct(analysis) || ~isscalar(analysis)
        error('TemplateExperiment:AnalysisContract', ...
            'AnalyzeFloquetBranch must return one scalar analysis struct.');
    end
    for k = 1:numel(required)
        if ~isfield(analysis, required{k})
            error('TemplateExperiment:AnalysisContract', ...
                'Analysis is missing required field %s.', required{k});
        end
    end
end

function candidates = AttachStableCandidateIDs(candidates, sampleIndices)
    if isempty(candidates)
        return
    end
    sampleIndices = sampleIndices(:).';
    for k = 1:numel(candidates)
        type = CandidateField(candidates(k), {'Type','type'});
        left = CandidateField(candidates(k), {'LeftIndex','leftIndex'});
        right = CandidateField(candidates(k), {'RightIndex','rightIndex'});
        if ~(isscalar(left) && isscalar(right) && left >= 1 && right >= 1 && ...
                left <= numel(sampleIndices) && right <= numel(sampleIndices))
            error('TemplateExperiment:CandidateIndexContract', ...
                'Candidate %d does not map to two sampled branch columns.', k);
        end
        columns = sort([sampleIndices(left), sampleIndices(right)]);
        candidates(k).LeftBranchColumn = columns(1);
        candidates(k).RightBranchColumn = columns(2);
        if ~isfield(candidates, 'CandidateID') || ...
                isempty(candidates(k).CandidateID)
            candidates(k).CandidateID = sprintf('%s_c%04d_c%04d', ...
                NormalizeType(type), columns(1), columns(2));
        end
    end
end

function WriteCandidateInventory(filename, candidates, overwrite)
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
    classification = strings(count, 1);
    for k = 1:count
        candidateID(k) = StringField(candidates(k), {'CandidateID'});
        type(k) = StringField(candidates(k), {'Type','type'});
        bifurcationType(k) = StringField(candidates(k), ...
            {'BifurcationType'});
        leftColumn(k) = NumericField(candidates(k), ...
            {'LeftBranchColumn','LeftBranchIndex'});
        rightColumn(k) = NumericField(candidates(k), ...
            {'RightBranchColumn','RightBranchIndex'});
        coordinate(k) = NumericField(candidates(k), ...
            {'ContinuationCoordinate','ContinuationParameter','Parameter'});
        multiplier = ValueField(candidates(k), ...
            {'Multiplier','multiplier'}, NaN);
        if isnumeric(multiplier) && isscalar(multiplier)
            multiplierReal(k) = real(multiplier);
            multiplierImag(k) = imag(multiplier);
        end
        confidence(k) = NumericField(candidates(k), ...
            {'ConfidenceScore'});
        classification(k) = StringField(candidates(k), ...
            {'NullDirectionClassification'});
    end
    inventory = table(candidateID, type, bifurcationType, leftColumn, ...
        rightColumn, coordinate, multiplierReal, multiplierImag, ...
        confidence, classification);
    floquet.workflow.internal.WriteFloquetAuditTable(filename, inventory, overwrite);
end

function WriteRejectedPoints(filename, analysis, overwrite)
    items = analysis.rejectedReport.points;
    count = numel(items);
    localIndex = NaN(count, 1);
    branchColumn = NaN(count, 1);
    status = strings(count, 1);
    message = strings(count, 1);
    reasons = strings(count, 1);
    for k = 1:count
        localIndex(k) = NumericField(items(k), {'LocalIndex'});
        branchColumn(k) = NumericField(items(k), {'BranchIndex'});
        status(k) = StringField(items(k), {'Status'});
        message(k) = StringField(items(k), {'Message'});
        reasons(k) = JoinedField(items(k), {'Reasons'});
    end
    report = table(localIndex, branchColumn, status, message, reasons);
    floquet.workflow.internal.WriteFloquetAuditTable(filename, report, overwrite);
end

function WriteRejectedIntervals(filename, analysis, overwrite)
    items = analysis.rejectedReport.intervals;
    count = numel(items);
    localLeft = NaN(count, 1);
    localRight = NaN(count, 1);
    branchLeft = NaN(count, 1);
    branchRight = NaN(count, 1);
    reasons = strings(count, 1);
    topologyStatus = strings(count, 1);
    for k = 1:count
        localLeft(k) = NumericField(items(k), {'LocalLeft'});
        localRight(k) = NumericField(items(k), {'LocalRight'});
        branchLeft(k) = NumericField(items(k), {'BranchLeft'});
        branchRight(k) = NumericField(items(k), {'BranchRight'});
        reasons(k) = JoinedField(items(k), {'Reasons'});
        comparison = ValueField(items(k), {'TopologyComparison'}, struct());
        topologyStatus(k) = StringField(comparison, {'Status'});
    end
    report = table(localLeft, localRight, branchLeft, branchRight, ...
        reasons, topologyStatus);
    floquet.workflow.internal.WriteFloquetAuditTable(filename, report, overwrite);
end

function value = CandidateField(candidate, names)
    value = ValueField(candidate, names, []);
    if isempty(value)
        error('TemplateExperiment:CandidateContract', ...
            'Candidate is missing required field %s.', strjoin(names, '/'));
    end
end

function value = NumericField(source, names)
    value = ValueField(source, names, NaN);
    if ~(isnumeric(value) && isscalar(value))
        value = NaN;
    end
end

function value = StringField(source, names)
    value = ValueField(source, names, '');
    if iscell(value) && isscalar(value)
        value = value{1};
    end
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        value = '';
    end
    value = string(value);
end

function value = JoinedField(source, names)
    value = ValueField(source, names, {});
    if ischar(value) || (isstring(value) && isscalar(value))
        value = string(value);
    elseif iscell(value)
        value = strjoin(string(value), ' | ');
    else
        value = "";
    end
end

function value = ValueField(source, names, fallback)
    value = fallback;
    if ~isstruct(source) || ~isscalar(source)
        return
    end
    for k = 1:numel(names)
        if isfield(source, names{k})
            value = source.(names{k});
            return
        end
    end
end

function label = NormalizeType(type)
    type = lower(char(string(type)));
    switch type
        case {'+1','plus-one','plus1'}
            label = 'plus1';
        case {'-1','minus-one','minus1','period-doubling'}
            label = 'minus1';
        case {'complex-unit-circle','neimark-sacker','unit-circle'}
            label = 'complex_unit_circle';
        otherwise
            label = regexprep(type, '[^a-z0-9]+', '_');
            label = regexprep(label, '^_+|_+$', '');
    end
end

function RequireFile(filename, hint)
    if ~isfile(filename)
        error('TemplateExperiment:MissingStageArtifact', ...
            '%s Missing file: %s', hint, filename);
    end
end

function EnsureParentDirectory(filename)
    directory = fileparts(filename);
    if ~isempty(directory) && ~isfolder(directory)
        mkdir(directory);
    end
end

function value = Timestamp()
    value = char(datetime('now', 'TimeZone', 'local', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end
