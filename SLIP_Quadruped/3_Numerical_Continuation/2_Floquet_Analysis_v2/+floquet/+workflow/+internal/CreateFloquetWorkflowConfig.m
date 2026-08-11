function [config, configFile, metadata] = CreateFloquetWorkflowConfig( ...
        parentBranchFile, experimentRoot, options)
%CREATEFLOQUETWORKFLOWCONFIG Freeze a parent-only GUI workflow configuration.
%
%   CONFIG = CREATEFLOQUETWORKFLOWCONFIG(PARENT,ROOT) constructs the same
%   fail-closed five-stage configuration used by the reusable experiment
%   template. PARENT is fingerprinted immediately. No expected bifurcation,
%   gait label, daughter branch, or held-out reference enters the config.
%
%   By default ROOT/workflow_config.mat is installed atomically. Set
%   OPTIONS.SaveConfig=false to construct an in-memory config only.

    if nargin < 3 || isempty(options)
        options = struct();
    end
    options = ParseOptions(options);
    internalRoot = fileparts(mfilename('fullpath'));
    analysisRoot = fileparts(fileparts(fileparts(internalRoot)));
    floquet.internal.ensureRuntimePaths(true);

    parentBranchFile = ExistingMatFile(parentBranchFile, ...
        'CreateFloquetWorkflowConfig:ParentBranch');
    experimentRoot = CanonicalDirectoryPath(experimentRoot);
    RejectMixedLegacyOutputRoot(experimentRoot);
    [~, parentStem] = fileparts(parentBranchFile);
    if isempty(options.ExperimentName)
        experimentName = parentStem;
    else
        experimentName = options.ExperimentName;
    end

    config = floquet.workflow.internal.BuildFloquetWorkflowConfig( ...
        experimentRoot, analysisRoot);
    config.ExperimentName = experimentName;
    config.ParentBranchFile = parentBranchFile;
    config.AnalysisOptions = MergeStruct( ...
        config.AnalysisOptions, options.AnalysisOptions);

    identityConfig = struct('ExperimentRoot', experimentRoot, ...
        'ParentBranchFile', parentBranchFile, 'ExpectedParentSHA256', '');
    parentIdentity = ...
        floquet.workflow.internal.FloquetParentIdentity(identityConfig);
    config.ExpectedParentSHA256 = parentIdentity.FileSHA256;

    if isempty(options.ConfigFile)
        configFile = fullfile(experimentRoot, 'workflow_config.mat');
    else
        configFile = options.ConfigFile;
        if ~IsAbsolutePath(configFile)
            configFile = fullfile(experimentRoot, configFile);
        end
        configFile = char(java.io.File(configFile).getCanonicalPath());
    end
    if SamePath(configFile, parentBranchFile)
        error('CreateFloquetWorkflowConfig:ConfigAliasesParent', ...
            'The workflow config file cannot overwrite the parent branch.');
    end

    metadata = struct();
    metadata.SchemaVersion = config.SchemaVersion;
    metadata.ArtifactLayoutVersion = config.ArtifactLayoutVersion;
    metadata.CreatedAt = Timestamp();
    metadata.Generator = mfilename;
    metadata.MATLABVersion = version;
    metadata.ParentIdentity = parentIdentity;
    metadata.InformationBarrier = [ ...
        'This parent-only configuration contains no daughter branch, ' ...
        'expected gait, expected crossing, or selected scan window.'];

    if options.SaveConfig
        if ~isfolder(experimentRoot)
            mkdir(experimentRoot);
        end
        floquet.workflow.internal.WriteFloquetArtifact( ...
            configFile, struct( ...
            'config', config, 'workflowConfigMetadata', metadata), ...
            options.Overwrite);
    else
        configFile = '';
    end
end

function RejectMixedLegacyOutputRoot(experimentRoot)
    legacyResults = fullfile(experimentRoot, 'results');
    if isfolder(legacyResults) && DirectoryContainsFile(legacyResults)
        error('FloquetWorkflow:LegacyOutputRootNotEmpty', [ ...
            'The selected output root contains a nonempty legacy results/ ' ...
            'tree. Preserve it for read-only inspection and create the v2 ' ...
            'workflow in a new empty output root.']);
    end

    existingConfig = fullfile(experimentRoot, 'workflow_config.mat');
    if ~isfile(existingConfig)
        return
    end
    variables = whos('-file', existingConfig);
    if ~any(strcmp({variables.name}, 'config'))
        return
    end
    loaded = load(existingConfig, 'config');
    if ~isstruct(loaded.config) || ~isscalar(loaded.config)
        return
    end
    layout = ...
        floquet.workflow.internal.InspectFloquetWorkflowLayout(loaded.config);
    if layout.IsLegacy
        error('FloquetWorkflow:LegacyConfigMigrationRequired', [ ...
            'The selected output root contains a legacy workflow_config.mat. ' ...
            'Use floquet.workflow.migrate for an empty legacy configuration, ' ...
            'or choose a new root for a nonempty legacy chain.']);
    end
end

function tf = DirectoryContainsFile(folder)
    entries = dir(fullfile(folder, '**', '*'));
    tf = any(~[entries.isdir]);
end

function options = ParseOptions(options)
    if ~isstruct(options) || ~isscalar(options)
        error('CreateFloquetWorkflowConfig:InvalidOptions', ...
            'options must be one scalar struct.');
    end
    defaults = struct('ExperimentName', '', 'AnalysisOptions', struct(), ...
        'SaveConfig', true, 'Overwrite', false, 'ConfigFile', '');
    supplied = fieldnames(options);
    for k = 1:numel(supplied)
        hit = find(strcmpi(supplied{k}, fieldnames(defaults)), 1);
        if isempty(hit)
            error('CreateFloquetWorkflowConfig:UnknownOption', ...
                'Unknown option %s.', supplied{k});
        end
        names = fieldnames(defaults);
        defaults.(names{hit}) = options.(supplied{k});
    end
    options = defaults;
    textFields = {'ExperimentName', 'ConfigFile'};
    for k = 1:numel(textFields)
        value = options.(textFields{k});
        if isstring(value) && isscalar(value)
            value = char(value);
        end
        if ~ischar(value)
            error('CreateFloquetWorkflowConfig:TextOption', ...
                '%s must be scalar text.', textFields{k});
        end
        options.(textFields{k}) = strtrim(value);
    end
    if ~isstruct(options.AnalysisOptions) || ...
            ~isscalar(options.AnalysisOptions)
        error('CreateFloquetWorkflowConfig:AnalysisOptions', ...
            'AnalysisOptions must be one scalar struct.');
    end
    options.SaveConfig = LogicalScalar(options.SaveConfig, 'SaveConfig');
    options.Overwrite = LogicalScalar(options.Overwrite, 'Overwrite');
end

function merged = MergeStruct(base, overrides)
    merged = base;
    names = fieldnames(overrides);
    for k = 1:numel(names)
        merged.(names{k}) = overrides.(names{k});
    end
end

function filename = ExistingMatFile(value, identifier)
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error(identifier, 'Parent branch path must be scalar text.');
    end
    filename = char(string(value));
    if ~isfile(filename)
        error(identifier, 'Parent branch file does not exist: %s', filename);
    end
    [~, ~, extension] = fileparts(filename);
    if ~strcmpi(extension, '.mat')
        error(identifier, 'Parent branch must be a MAT file.');
    end
    filename = char(java.io.File(filename).getCanonicalPath());
end

function directory = CanonicalDirectoryPath(value)
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error('CreateFloquetWorkflowConfig:ExperimentRoot', ...
            'Experiment root must be scalar text.');
    end
    directory = strtrim(char(string(value)));
    if isempty(directory)
        error('CreateFloquetWorkflowConfig:ExperimentRoot', ...
            'Experiment root cannot be empty.');
    end
    directory = char(java.io.File(directory).getCanonicalPath());
end

function tf = IsAbsolutePath(filename)
    file = java.io.File(filename);
    tf = file.isAbsolute();
end

function tf = SamePath(left, right)
    if ispc || ismac
        tf = strcmpi(left, right);
    else
        tf = strcmp(left, right);
    end
end

function value = LogicalScalar(value, name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isreal(value) && isfinite(value) && ...
             any(value == [0 1]))))
        error('CreateFloquetWorkflowConfig:LogicalOption', ...
            '%s must be scalar logical.', name);
    end
    value = logical(value);
end

function value = Timestamp()
    value = char(datetime('now', 'TimeZone', 'local', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end
