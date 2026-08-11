function [inspection, payload] = inspectAnalysis(source)
%INSPECTANALYSIS Validate and summarize an existing Floquet result.
%
%   INSPECTION = floquet.inspectAnalysis(SOURCE) accepts one of:
%       * a canonical AnalyzeFloquetBranch `analysis` artifact;
%       * a validated diagnostic/viewer `FloquetData` artifact;
%       * a five-stage workflow `config`; or
%       * a workflow state returned by InspectFloquetWorkflowState.
%
%   SOURCE may be the scalar structure itself, a scalar wrapper using the
%   canonical variable name, or a MAT filename containing exactly one of
%   the supported variables. Existing artifact validators are used. No
%   Floquet matrix, periodic orbit or event timing is recomputed.
%
%   INSPECTION has the stable schema `floquet-inspection-v1` and fields
%   SourceType, Source and Summary. SourceType is one of
%   `canonical-analysis`, `floquet-dataset`, `workflow-config`, or
%   `workflow-state`. [INSPECTION,PAYLOAD] additionally returns the
%   validated native analysis/dataset or the freshly inspected workflow
%   state. A workflow state is re-inspected from its embedded configuration
%   so stale artifact-chain claims are never trusted.

    if nargin ~= 1 || isempty(source)
        error('floquet:inspectAnalysis:MissingSource', ...
            'Supply one supported structure or MAT filename.');
    end
    [sourceType, value, sourceInfo] = ResolveSource(source);
    switch sourceType
        case 'canonical-analysis'
            analysis = RequireScalarStruct(value, 'analysis');
            [~, loadInfo] = ...
                floquet.io.loadDataset(struct('analysis', analysis));
            payload = analysis;
            summary = SummarizeAnalysis(analysis, loadInfo);
            payloadSchema = TextField(analysis, 'version');
        case 'floquet-dataset'
            [payload, loadInfo] = floquet.io.loadDataset(value);
            summary = SummarizeDataset(payload, loadInfo);
            payloadSchema = loadInfo.schema_version;
        case 'workflow-config'
            config = RequireScalarStruct(value, 'config');
            [config, configSource] = ...
                floquet.workflow.internal.LoadFloquetWorkflowConfig(config);
            payload = ...
                floquet.workflow.internal.InspectFloquetWorkflowState(config);
            summary = SummarizeWorkflow(payload);
            payloadSchema = TextField(configSource, 'SchemaVersion');
        case 'workflow-state'
            suppliedState = RequireScalarStruct(value, 'workflow state');
            payload = ReinspectWorkflowState(suppliedState);
            summary = SummarizeWorkflow(payload);
            payloadSchema = TextField(payload, 'SchemaVersion');
        otherwise
            error('floquet:inspectAnalysis:InternalSourceType', ...
                'Unsupported internal source type %s.', sourceType);
    end

    inspection = struct();
    inspection.SchemaVersion = 'floquet-inspection-v1';
    inspection.SourceType = sourceType;
    inspection.Source = sourceInfo;
    inspection.PayloadSchemaVersion = payloadSchema;
    inspection.Summary = summary;
    inspection.Compatibility = InspectionCompatibility( ...
        sourceType, payloadSchema, payload);
end

function compatibility = InspectionCompatibility(sourceType, schema, payload)
    compatibility = struct('Policy','native-v2', ...
        'ReadOnly',true,'CheckpointResumable',false,'Message','');
    legacyAnalysis = strcmp(sourceType,'canonical-analysis') && ...
        strcmp(schema,'floquet-branch-analysis-v1');
    legacyWorkflow = strcmp(sourceType,'workflow-config') && ...
        strcmp(schema,'floquet-workflow-config-v1');
    legacyWorkflowState = strcmp(sourceType,'workflow-state') && ...
        isstruct(payload) && isscalar(payload) && ...
        isfield(payload,'ConfigurationLayout') && ...
        isstruct(payload.ConfigurationLayout) && ...
        isscalar(payload.ConfigurationLayout) && ...
        isfield(payload.ConfigurationLayout,'IsLegacy') && ...
        IsTrue(payload.ConfigurationLayout.IsLegacy);
    if legacyAnalysis
        compatibility.Policy = 'legacy-v1-read-only';
        compatibility.Message = [ ...
            'Completed v1 analysis is accepted as historical evidence. ' ...
            'Its global evaluator identity is not v2 production authority, ' ...
            'and associated v1 checkpoints cannot be resumed.'];
    elseif legacyWorkflow || legacyWorkflowState
        compatibility.Policy = 'legacy-v1-read-only';
        compatibility.Message = [ ...
            'The v1 workflow is inspection-only. Empty configurations may ' ...
            'be migrated explicitly; nonempty chains remain historical ' ...
            'records, and v1 checkpoints cannot be resumed.'];
    else
        compatibility.Message = [ ...
            'Inspection is nonmutating; start or resume execution through ' ...
            'the owning v2 workflow rather than this read API.'];
    end
end

function [sourceType, value, info] = ResolveSource(source)
    info = EmptySourceInfo();
    if IsScalarText(source)
        filename = char(string(source));
        if ~isfile(filename)
            error('floquet:inspectAnalysis:MissingFile', ...
                'Inspection source does not exist: %s', filename);
        end
        [~, ~, extension] = fileparts(filename);
        if ~strcmpi(extension, '.mat')
            error('floquet:inspectAnalysis:FileType', ...
                'Inspection files must be MAT files.');
        end
        filename = char(java.io.File(filename).getCanonicalPath());
        variables = whos('-file', filename);
        names = {variables.name};
        supported = {'analysis', 'FloquetData', 'config', 'state', ...
            'workflowState'};
        present = supported(ismember(supported, names));
        if isempty(present)
            error('floquet:inspectAnalysis:MissingVariable', [ ...
                'MAT file must contain one supported variable: analysis, ' ...
                'FloquetData, config, state, or workflowState.']);
        end
        if numel(present) ~= 1
            error('floquet:inspectAnalysis:AmbiguousFile', ...
                'MAT file contains multiple supported variables: %s.', ...
                strjoin(present, ', '));
        end
        variable = present{1};
        loaded = load(filename, variable);
        value = loaded.(variable);
        sourceType = TypeForVariable(variable, value);
        info.Kind = 'mat-file';
        info.File = filename;
        info.Variable = variable;
        return
    end

    source = RequireScalarStruct(source, 'source');
    wrapperNames = {'analysis', 'FloquetData', 'config', 'state', ...
        'workflowState'};
    present = wrapperNames(isfield(source, wrapperNames));
    if ~isempty(present)
        if numel(present) ~= 1
            error('floquet:inspectAnalysis:AmbiguousStructure', ...
                'Source wraps multiple supported values: %s.', ...
                strjoin(present, ', '));
        end
        variable = present{1};
        value = source.(variable);
        sourceType = TypeForVariable(variable, value);
        info.Kind = 'memory-wrapper';
        info.Variable = variable;
        return
    end

    value = source;
    if IsCanonicalAnalysis(value)
        sourceType = 'canonical-analysis';
        info.Variable = 'analysis';
    elseif IsFloquetDataset(value)
        sourceType = 'floquet-dataset';
        info.Variable = 'FloquetData';
    elseif IsWorkflowState(value)
        sourceType = 'workflow-state';
        info.Variable = 'state';
    elseif IsWorkflowConfig(value)
        sourceType = 'workflow-config';
        info.Variable = 'config';
    else
        error('floquet:inspectAnalysis:UnsupportedStructure', [ ...
            'The scalar structure is not a canonical analysis, FloquetData, ' ...
            'workflow configuration, or workflow state.']);
    end
    info.Kind = 'memory-struct';
end

function sourceType = TypeForVariable(variable, value)
    switch variable
        case 'analysis'
            sourceType = 'canonical-analysis';
            RequireType(value, @IsCanonicalAnalysis, 'analysis');
        case 'FloquetData'
            sourceType = 'floquet-dataset';
            RequireType(value, @IsFloquetDataset, 'FloquetData');
        case 'config'
            sourceType = 'workflow-config';
            RequireType(value, @IsWorkflowConfig, 'config');
        case {'state', 'workflowState'}
            sourceType = 'workflow-state';
            RequireType(value, @IsWorkflowState, variable);
        otherwise
            error('floquet:inspectAnalysis:InternalVariable', ...
                'Unsupported internal variable %s.', variable);
    end
end

function RequireType(value, predicate, label)
    if ~predicate(value)
        error('floquet:inspectAnalysis:VariableContract', ...
            'Variable %s does not satisfy its supported schema.', label);
    end
end

function tf = IsCanonicalAnalysis(value)
    tf = isstruct(value) && isscalar(value) && ...
        isfield(value, 'version') && IsScalarText(value.version) && ...
        startsWith(char(string(value.version)), ...
            'floquet-branch-analysis-');
end

function tf = IsFloquetDataset(value)
    tf = isstruct(value) && isscalar(value) && ...
        isfield(value, 'branch_index') && ...
        isfield(value, 'computation_info');
end

function tf = IsWorkflowConfig(value)
    required = {'ExperimentRoot', 'ParentBranchFile', 'AnalysisOptions', ...
        'Selection', 'Refinement', 'BranchSwitch', 'Continuation', ...
        'Validation', 'Files'};
    tf = isstruct(value) && isscalar(value) && ...
        all(isfield(value, required));
end

function tf = IsWorkflowState(value)
    supported = {'floquet-workflow-state-v1', ...
        'floquet-workflow-state-v2'};
    tf = isstruct(value) && isscalar(value) && ...
        isfield(value, 'SchemaVersion') && ...
        IsScalarText(value.SchemaVersion) && ...
        ismember(char(string(value.SchemaVersion)), supported) && ...
        isfield(value, 'Config') && isstruct(value.Config) && ...
        isscalar(value.Config);
end

function state = ReinspectWorkflowState(supplied)
    if ~IsWorkflowState(supplied)
        error('floquet:inspectAnalysis:WorkflowStateContract', ...
            ['Workflow state must use schema floquet-workflow-state-v1 ' ...
             'or floquet-workflow-state-v2.']);
    end
    state = floquet.workflow.internal.InspectFloquetWorkflowState( ...
        supplied.Config);
end

function summary = SummarizeAnalysis(analysis, loadInfo)
    summary = EmptySummary();
    summary.PointCount = loadInfo.point_count;
    summary.AcceptedCount = loadInfo.accepted_count;
    summary.RejectedCount = summary.PointCount - summary.AcceptedCount;
    summary.CandidateCount = StructCount(FieldOr(analysis, ...
        'candidates', struct([])));
    summary.Status = TextField(analysis, 'status');
    if isempty(summary.Status)
        summary.Status = loadInfo.status;
    end
    summary.ScientificAuthority = LogicalField( ...
        analysis, 'scientificAuthority');
end

function summary = SummarizeDataset(data, loadInfo)
    summary = EmptySummary();
    summary.PointCount = loadInfo.point_count;
    summary.AcceptedCount = loadInfo.accepted_count;
    summary.RejectedCount = summary.PointCount - summary.AcceptedCount;
    summary.Status = loadInfo.status;
    info = data.computation_info;
    summary.ScientificAuthority = LogicalField( ...
        info, 'scientific_authority');
    if isfield(info, 'authoritative_candidates') && ...
            isstruct(info.authoritative_candidates)
        summary.CandidateCount = numel(info.authoritative_candidates);
    elseif isfield(data, 'bifurcation_indicator') && ...
            isstruct(data.bifurcation_indicator)
        summary.CandidateCount = CountIndicatorCandidates( ...
            data.bifurcation_indicator);
    end
end

function summary = SummarizeWorkflow(state)
    summary = EmptySummary();
    stages = state.Stages;
    summary.StageCount = numel(stages);
    summary.CompletedStageCount = nnz(strcmp({stages.Status}, 'complete'));
    summary.ValidStageCount = nnz([stages.Valid]);
    if state.Discovery.Available && isstruct(state.Discovery.Analysis) && ...
            isscalar(state.Discovery.Analysis)
        analysis = state.Discovery.Analysis;
        if isfield(analysis, 'branchIndices')
            summary.PointCount = numel(analysis.branchIndices);
        end
        if isfield(analysis, 'accepted')
            accepted = logical(analysis.accepted(:));
            summary.AcceptedCount = nnz(accepted);
            summary.RejectedCount = numel(accepted) - nnz(accepted);
        end
        summary.CandidateCount = StructCount(FieldOr(analysis, ...
            'candidates', struct([])));
        summary.ScientificAuthority = ...
            state.Discovery.ScientificUseAllowed;
    end
    if summary.ValidStageCount == summary.StageCount
        summary.Status = 'complete';
    elseif summary.ValidStageCount > 0
        summary.Status = 'partial';
    else
        summary.Status = 'not-started';
    end
end

function summary = EmptySummary()
    summary = struct('Status', '', 'PointCount', 0, ...
        'AcceptedCount', 0, 'RejectedCount', 0, ...
        'CandidateCount', 0, 'StageCount', 0, ...
        'CompletedStageCount', 0, 'ValidStageCount', 0, ...
        'ScientificAuthority', false);
end

function info = EmptySourceInfo()
    info = struct('Kind', '', 'File', '', 'Variable', '');
end

function count = CountIndicatorCandidates(indicators)
    count = 0;
    for k = 1:numel(indicators)
        if isfield(indicators(k), 'details') && ...
                isstruct(indicators(k).details)
            count = count + numel(indicators(k).details);
        elseif isfield(indicators(k), 'is_candidate') && ...
                IsTrue(indicators(k).is_candidate)
            count = count + 1;
        end
    end
end

function count = StructCount(value)
    if isstruct(value)
        count = numel(value);
    else
        count = 0;
    end
end

function value = FieldOr(source, name, fallback)
    value = fallback;
    if isstruct(source) && isscalar(source) && isfield(source, name)
        value = source.(name);
    end
end

function value = TextField(source, name)
    value = '';
    if isstruct(source) && isscalar(source) && isfield(source, name) && ...
            IsScalarText(source.(name))
        value = char(string(source.(name)));
    end
end

function value = LogicalField(source, name)
    value = false;
    if isstruct(source) && isscalar(source) && isfield(source, name) && ...
            IsBooleanScalar(source.(name))
        value = logical(source.(name));
    end
end

function tf = IsTrue(value)
    tf = IsBooleanScalar(value) && logical(value);
end

function tf = IsBooleanScalar(value)
    tf = isscalar(value) && ...
        (islogical(value) || (isnumeric(value) && isreal(value) && ...
        isfinite(value) && any(value == [0 1])));
end

function value = RequireScalarStruct(value, label)
    if ~isstruct(value) || ~isscalar(value)
        error('floquet:inspectAnalysis:ScalarStructure', ...
            '%s must be one scalar structure.', label);
    end
end

function tf = IsScalarText(value)
    tf = ischar(value) || (isstring(value) && isscalar(value));
end
