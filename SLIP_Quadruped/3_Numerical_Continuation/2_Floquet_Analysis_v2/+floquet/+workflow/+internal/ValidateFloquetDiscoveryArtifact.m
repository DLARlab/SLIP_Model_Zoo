function [parentIdentity, authority] = ...
        ValidateFloquetDiscoveryArtifact(analysis, config, requireStageStamp)
%VALIDATEFLOQUETDISCOVERYARTIFACT Enforce canonical full-parent discovery.
%
% Production scientific stages accept only the canonical reduced-Poincare
% branch analyzer, every parent column in original order, and the exact
% current parent file/numeric payload.  A nonproduction evaluator is allowed
% only behind config.Testing.AllowNonProductionDiscovery=true and is stamped
% as test-only authority by Stage 1.

    if nargin < 3
        requireStageStamp = true;
    end
    parentIdentity = floquet.workflow.internal.FloquetParentIdentity(config);
    RequireScalarStruct(analysis, 'analysis');
    if isfield(analysis,'version') && IsScalarText(analysis.version) && ...
            strcmp(char(string(analysis.version)), ...
                'floquet-branch-analysis-v1')
        error('TemplateExperiment:LegacyDiscoveryReadOnly', [ ...
            'A v1 discovery artifact may be inspected as historical ' ...
            'evidence, but cannot authorize v2 refinement or branch ' ...
            'switching. Regenerate Stage 1 with floquet.analyzeBranch.']);
    end
    RequireTextEqual(analysis, 'version', 'floquet-branch-analysis-v2');
    RequireTextEqual(analysis, 'algorithmID', ...
        'reduced-poincare-fdm-v2-canonical-branch-scan');
    RequireTrue(analysis, 'parentOnly');
    RequireFalse(analysis, 'daughterDataLoaded');
    if ~isfield(analysis, 'provenance') || ...
            ~isstruct(analysis.provenance) || ~isscalar(analysis.provenance)
        ContractError('Discovery provenance is missing or malformed.');
    end
    RequireTrue(analysis.provenance, 'parentDataOnly');
    production = StrictBooleanField(analysis.provenance, ...
        'productionEvaluator');
    if ~isfield(analysis.provenance, 'computeFunction') || ...
            ~IsScalarText(analysis.provenance.computeFunction)
        ContractError('provenance.computeFunction is missing or malformed.');
    end
    computeIsProduction = strcmp( ...
        char(string(analysis.provenance.computeFunction)), ...
        'floquet.computeFDM');
    if production ~= computeIsProduction
        ContractError([ ...
            'provenance.productionEvaluator contradicts ' ...
            'provenance.computeFunction.']);
    end
    ValidateComputeEvaluatorIdentity(analysis.provenance, production);
    allowTest = AllowTestNonProduction(config);
    if ~production && ~allowTest
        error('TemplateExperiment:NonProductionDiscovery', [ ...
            'Scientific workflow stages require the production ' ...
            'floquet.computeFDM evaluator. The explicit test hook is ' ...
            'config.Testing.AllowNonProductionDiscovery=true.']);
    end
    if production
        authority = 'production-scientific-authority';
    else
        authority = 'test-only-nonproduction-authority';
    end

    ValidateCoverageAuthority(analysis, production, ...
        parentIdentity.PointCount);

    pointCount = parentIdentity.PointCount;
    expectedColumns = 1:pointCount;
    RequireExactColumns(analysis, 'sampleIndices', expectedColumns);
    RequireExactColumns(analysis, 'branchIndices', expectedColumns);
    if ~isfield(analysis, 'source') || ...
            ~isstruct(analysis.source) || ~isscalar(analysis.source)
        ContractError('Discovery source identity is missing or malformed.');
    end
    source = analysis.source;
    RequireTextEqual(source, 'kind', 'mat-file');
    RequireSamePath(source, 'file', parentIdentity.CanonicalPath);
    RequireDigest(source, 'fileSHA256', parentIdentity.FileSHA256);
    RequireDigest(source, 'branchSHA256', parentIdentity.BranchSHA256);
    RequireTextEqual(source, 'variable', parentIdentity.Variable);
    RequireNumberEqual(source, 'fullBranchPointCount', pointCount);
    RequireNumberEqual(source, 'selectedPointCount', pointCount);
    RequireExactColumns(source, 'selectedColumns', expectedColumns);

    if requireStageStamp
        ValidateStageStamp(analysis, parentIdentity, authority);
    end
end

function ValidateComputeEvaluatorIdentity(provenance, production)
    field = 'computeEvaluatorIdentity';
    if ~isfield(provenance, field) || ...
            ~isstruct(provenance.(field)) || ...
            ~isscalar(provenance.(field))
        ContractError( ...
            'provenance.computeEvaluatorIdentity is missing or malformed.');
    end
    identity = provenance.(field);
    identityProduction = StrictBooleanField( ...
        identity, 'ProductionEvaluator');
    if identityProduction ~= production
        ContractError([ ...
            'computeEvaluatorIdentity.ProductionEvaluator contradicts ' ...
            'provenance.productionEvaluator.']);
    end
    RequireTextEqual(identity, 'SchemaVersion', ...
        'floquet-evaluator-identity-v2');
    RequireTextEqual(identity, 'ExpectedFunction', 'floquet.computeFDM');
    if ~isfield(identity, 'Function') || ...
            ~IsScalarText(identity.Function) || ...
            ~strcmp(char(string(identity.Function)), ...
            char(string(provenance.computeFunction)))
        ContractError([ ...
            'computeEvaluatorIdentity.Function contradicts ' ...
            'provenance.computeFunction.']);
    end
    nameMatches = StrictBooleanField(identity, 'NameMatches');
    expectedNameMatch = strcmp(char(string(identity.Function)), ...
        'floquet.computeFDM');
    if nameMatches ~= expectedNameMatch
        ContractError([ ...
            'computeEvaluatorIdentity.NameMatches is internally ' ...
            'inconsistent.']);
    end
    fileMatches = StrictBooleanField(identity, 'FileMatches');
    if ~production
        return
    end
    RequireTextEqual(identity, 'Function', 'floquet.computeFDM');
    if ~nameMatches || ~fileMatches
        ContractError([ ...
            'A production evaluator identity requires true NameMatches ' ...
            'and FileMatches evidence.']);
    end

    workflowRoot = fileparts(mfilename('fullpath'));
    floquetRoot = fileparts(fileparts(fileparts(workflowRoot)));
    canonicalCompute = fullfile(floquetRoot, '+floquet', 'computeFDM.m');
    if ~isfile(canonicalCompute)
        ContractError('The canonical +floquet/computeFDM.m file is missing.');
    end
    RequireEvaluatorPath(identity, 'ExpectedFile', canonicalCompute);
    RequireEvaluatorPath(identity, 'ActualFile', canonicalCompute);
end

function RequireEvaluatorPath(source, field, expected)
    if ~isfield(source, field) || ~IsScalarText(source.(field)) || ...
            isempty(strtrim(char(string(source.(field)))))
        ContractError(sprintf( ...
            'computeEvaluatorIdentity.%s must contain a file path.', field));
    end
    actual = char(java.io.File( ...
        char(string(source.(field)))).getCanonicalPath());
    expected = char(java.io.File(expected).getCanonicalPath());
    if ispc
        equal = strcmpi(actual, expected);
    else
        equal = strcmp(actual, expected);
    end
    if ~equal
        ContractError(sprintf([ ...
            'computeEvaluatorIdentity.%s does not identify the canonical ' ...
            '+floquet/computeFDM.m file.'], field));
    end
end

function ValidateCoverageAuthority(analysis, expectedAuthority, pointCount)
    RequireBooleanEqual(analysis, 'scientificAuthority', expectedAuthority);
    RequireTrue(analysis, 'fullParentCoverage');
    RequireTrue(analysis, 'fullOrderedParentCoverage');
    if ~isfield(analysis, 'coverage') || ...
            ~isstruct(analysis.coverage) || ~isscalar(analysis.coverage)
        ContractError('analysis.coverage is missing or malformed.');
    end
    coverage = analysis.coverage;
    RequireTrue(coverage, 'fullParentCoverage');
    RequireTrue(coverage, 'fullOrderedParentCoverage');
    RequireTrue(coverage, 'selectionPreservesContinuationOrder');
    RequireNumberEqual(coverage, 'fullParentPointCount', pointCount);
    RequireNumberEqual(coverage, 'selectedPointCount', pointCount);
    RequireExactColumns(coverage, 'selectedColumns', 1:pointCount);

    provenance = analysis.provenance;
    RequireTrue(provenance, 'fullParentCoverage');
    RequireTrue(provenance, 'orderedParentCoverage');
    RequireBooleanEqual(provenance, 'scientificAuthority', ...
        expectedAuthority);
    if ~isfield(provenance, 'coverage') || ...
            ~isstruct(provenance.coverage) || ...
            ~isscalar(provenance.coverage)
        ContractError('provenance.coverage is missing or malformed.');
    end
    RequireTrue(provenance.coverage, 'fullParentCoverage');
    RequireTrue(provenance.coverage, 'fullOrderedParentCoverage');
end

function ValidateStageStamp(analysis, parentIdentity, authority)
    if ~isfield(analysis, 'workflowStage') || ...
            ~isstruct(analysis.workflowStage) || ...
            ~isscalar(analysis.workflowStage)
        ContractError('Discovery lacks the Stage-1 workflow stamp.');
    end
    stage = analysis.workflowStage;
    RequireTextEqual(stage, 'Name', 'parent-only-full-branch-discovery');
    RequireTrue(stage, 'FullBranchSelection');
    RequireTextEqual(stage, 'Authority', authority);
    RequireBooleanEqual(stage, 'ScientificUseAllowed', ...
        strcmp(authority, 'production-scientific-authority'));
    RequireSamePath(stage, 'ParentBranchFile', ...
        parentIdentity.CanonicalPath);
    if ~isfield(stage, 'ParentIdentity') || ...
            ~isstruct(stage.ParentIdentity) || ...
            ~isscalar(stage.ParentIdentity)
        ContractError('Stage-1 parent identity stamp is missing.');
    end
    saved = stage.ParentIdentity;
    RequireSamePath(saved, 'CanonicalPath', parentIdentity.CanonicalPath);
    RequireDigest(saved, 'FileSHA256', parentIdentity.FileSHA256);
    RequireDigest(saved, 'BranchSHA256', parentIdentity.BranchSHA256);
    RequireTextEqual(saved, 'Variable', parentIdentity.Variable);
    RequireNumberEqual(saved, 'PointCount', parentIdentity.PointCount);
end

function allow = AllowTestNonProduction(config)
    allow = false;
    if ~isfield(config, 'Testing') || isempty(config.Testing)
        return
    end
    if ~isstruct(config.Testing) || ~isscalar(config.Testing)
        error('TemplateExperiment:TestingConfiguration', ...
            'config.Testing must be a scalar struct when supplied.');
    end
    if ~isfield(config.Testing, 'AllowNonProductionDiscovery')
        return
    end
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

function RequireScalarStruct(value, name)
    if ~isstruct(value) || ~isscalar(value)
        ContractError(sprintf('%s must be one scalar struct.', name));
    end
end

function value = StrictBooleanField(source, field)
    if ~isfield(source, field)
        ContractError(sprintf('Missing Boolean field %s.', field));
    end
    value = source.(field);
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isreal(value) && isfinite(value) && ...
             any(value == [0 1]))))
        ContractError(sprintf('%s must be scalar logical or numeric 0/1.', ...
            field));
    end
    value = logical(value);
end

function RequireTrue(source, field)
    if ~StrictBooleanField(source, field)
        ContractError(sprintf('%s must be true.', field));
    end
end

function RequireFalse(source, field)
    if StrictBooleanField(source, field)
        ContractError(sprintf('%s must be false.', field));
    end
end

function RequireBooleanEqual(source, field, expected)
    actual = StrictBooleanField(source, field);
    if actual ~= expected
        ContractError(sprintf('%s contradicts the expected authority.', field));
    end
end

function RequireTextEqual(source, field, expected)
    if ~isfield(source, field) || ~IsScalarText(source.(field)) || ...
            ~strcmp(char(string(source.(field))), expected)
        ContractError(sprintf('%s must equal %s.', field, expected));
    end
end

function RequireSamePath(source, field, expected)
    if ~isfield(source, field) || ~IsScalarText(source.(field)) || ...
            isempty(strtrim(char(string(source.(field)))))
        ContractError(sprintf('%s must contain a source path.', field));
    end
    actual = char(java.io.File(char(string(source.(field)))).getCanonicalPath());
    expected = char(java.io.File(expected).getCanonicalPath());
    if ispc
        equal = strcmpi(actual, expected);
    else
        equal = strcmp(actual, expected);
    end
    if ~equal
        error('TemplateExperiment:DiscoveryParentPathMismatch', ...
            'Discovery parent path is stale: %s does not match %s.', ...
            actual, expected);
    end
end

function RequireDigest(source, field, expected)
    if ~isfield(source, field) || ~IsScalarText(source.(field))
        ContractError(sprintf('%s must contain a SHA-256 digest.', field));
    end
    actual = lower(strtrim(char(string(source.(field)))));
    if isempty(regexp(actual, '^[0-9a-f]{64}$', 'once'))
        ContractError(sprintf('%s is not a SHA-256 digest.', field));
    end
    if ~strcmp(actual, expected)
        error('TemplateExperiment:DiscoveryParentFingerprintMismatch', ...
            'Discovery %s is stale (saved %s, current %s).', ...
            field, actual, expected);
    end
end

function RequireNumberEqual(source, field, expected)
    if ~isfield(source, field) || ~isnumeric(source.(field)) || ...
            ~isscalar(source.(field)) || ~isfinite(source.(field)) || ...
            source.(field) ~= expected
        ContractError(sprintf('%s must equal %d.', field, expected));
    end
end

function RequireExactColumns(source, field, expected)
    if ~isfield(source, field) || ~isnumeric(source.(field)) || ...
            ~isequal(source.(field)(:).', expected)
        error('TemplateExperiment:DiscoveryNotFullBranch', [ ...
            'Canonical discovery must cover every parent column exactly ' ...
            'once and in original order; field %s is inconsistent.'], field);
    end
end

function tf = IsScalarText(value)
    tf = ischar(value) || (isstring(value) && isscalar(value));
end

function ContractError(message)
    error('TemplateExperiment:DiscoveryContract', '%s', message);
end
