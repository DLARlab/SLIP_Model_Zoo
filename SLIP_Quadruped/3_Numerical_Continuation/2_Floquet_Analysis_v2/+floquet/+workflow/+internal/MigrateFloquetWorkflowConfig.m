function [config, configFile, metadata] = ...
        MigrateFloquetWorkflowConfig(input, options)
%MIGRATEFLOQUETWORKFLOWCONFIG Explicit empty-v1 to v2 conversion.

    if nargin < 2 || isempty(options)
        options = struct();
    end
    options = ParseOptions(options);
    [legacy, source] = ...
        floquet.workflow.internal.LoadFloquetWorkflowConfig(input);
    layout = ...
        floquet.workflow.internal.InspectFloquetWorkflowLayout(legacy);
    if ~layout.IsLegacy
        error('FloquetWorkflow:MigrationSourceVersion', ...
            'Only a legacy v1 workflow configuration can be migrated.');
    end
    if ~isempty(layout.ExistingCheckpointFiles)
        error('FloquetWorkflow:LegacyCheckpointNonResumable', '%s', ...
            layout.Message);
    end
    if layout.HasNonemptyChain
        error('FloquetWorkflow:LegacyMigrationNonempty', [ ...
            'A nonempty legacy artifact chain cannot be rewritten as v2. ' ...
            'Preserve the legacy configuration for read-only inspection ' ...
            'and create a new v2 workflow root for recomputation.']);
    end

    experimentRoot = RequiredText(legacy, 'ExperimentRoot');
    floquetRoot = OptionalText(legacy, 'FloquetRoot');
    config = floquet.workflow.internal.BuildFloquetWorkflowConfig( ...
        experimentRoot, floquetRoot);
    config = CopyTopLevelSettings(config, legacy);
    config.AnalysisOptions = CopySectionSettings( ...
        config.AnalysisOptions, legacy, 'AnalysisOptions');
    config.Continuation = CopySectionSettings( ...
        config.Continuation, legacy, 'Continuation');

    metadata = struct( ...
        'SchemaVersion', config.SchemaVersion, ...
        'ArtifactLayoutVersion', config.ArtifactLayoutVersion, ...
        'MigratedAt', Timestamp(), ...
        'Generator', mfilename, ...
        'MATLABVersion', version, ...
        'SourceKind', source.Kind, ...
        'SourceFile', source.CanonicalFile, ...
        'SourceSHA256', source.SHA256, ...
        'MigrationPolicy', [ ...
            'Explicit path rebase from an empty v1 configuration; no v1 ' ...
            'artifact or checkpoint was reused.']);

    configFile = '';
    if ~options.SaveConfig
        return
    end
    if isempty(options.ConfigFile)
        configFile = fullfile(experimentRoot, 'workflow_config.mat');
    else
        configFile = options.ConfigFile;
        file = java.io.File(configFile);
        if ~file.isAbsolute()
            configFile = fullfile(experimentRoot, configFile);
        end
    end
    configFile = char(java.io.File(configFile).getCanonicalPath());
    if SamePath(configFile, RequiredText(legacy, 'ParentBranchFile'))
        error('FloquetWorkflow:MigrationConfigAliasesParent', ...
            'The migrated workflow config cannot overwrite its parent branch.');
    end
    floquet.workflow.internal.WriteFloquetArtifact(configFile, ...
        struct('config', config, 'workflowConfigMetadata', metadata), ...
        options.Overwrite);
end

function config = CopyTopLevelSettings(config, legacy)
    pathOwned = {'SchemaVersion','ArtifactLayoutVersion','Directories', ...
        'Files','AnalysisOptions','Continuation','ExperimentRoot', ...
        'FloquetRoot'};
    names = fieldnames(legacy);
    for k = 1:numel(names)
        if ~ismember(names{k}, pathOwned)
            config.(names{k}) = legacy.(names{k});
        end
    end
end

function target = CopySectionSettings(target, source, field)
    if ~isfield(source, field) || ~isstruct(source.(field)) || ...
            ~isscalar(source.(field))
        return
    end
    pathOwned = {'CheckpointFile','ResumeFromCheckpoint'};
    names = fieldnames(source.(field));
    for k = 1:numel(names)
        if ~ismember(names{k}, pathOwned)
            target.(names{k}) = source.(field).(names{k});
        end
    end
end

function options = ParseOptions(options)
    if ~isstruct(options) || ~isscalar(options)
        error('FloquetWorkflow:MigrationOptions', ...
            'Migration options must be one scalar struct.');
    end
    defaults = struct('SaveConfig', false, 'ConfigFile', '', ...
        'Overwrite', false);
    names = fieldnames(options);
    for k = 1:numel(names)
        match = find(strcmpi(names{k}, fieldnames(defaults)), 1);
        if isempty(match)
            error('FloquetWorkflow:MigrationOptions', ...
                'Unknown migration option %s.', names{k});
        end
        allowed = fieldnames(defaults);
        defaults.(allowed{match}) = options.(names{k});
    end
    options = defaults;
    options.SaveConfig = LogicalScalar(options.SaveConfig, 'SaveConfig');
    options.Overwrite = LogicalScalar(options.Overwrite, 'Overwrite');
    if ~(ischar(options.ConfigFile) || ...
            (isstring(options.ConfigFile) && isscalar(options.ConfigFile)))
        error('FloquetWorkflow:MigrationOptions', ...
            'ConfigFile must be scalar text.');
    end
    options.ConfigFile = strtrim(char(string(options.ConfigFile)));
end

function value = RequiredText(source, field)
    value = OptionalText(source, field);
    if isempty(value)
        error('FloquetWorkflow:ConfigContract', ...
            'Legacy config.%s must be nonempty scalar text.', field);
    end
end

function value = OptionalText(source, field)
    value = '';
    if ~isfield(source, field)
        return
    end
    candidate = source.(field);
    if ~(ischar(candidate) || (isstring(candidate) && isscalar(candidate)))
        error('FloquetWorkflow:ConfigContract', ...
            'Legacy config.%s must be scalar text.', field);
    end
    value = strtrim(char(string(candidate)));
end

function value = LogicalScalar(value, name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isreal(value) && isfinite(value) && ...
             any(value == [0 1]))))
        error('FloquetWorkflow:MigrationOptions', ...
            '%s must be scalar logical.', name);
    end
    value = logical(value);
end

function tf = SamePath(left, right)
    left = char(java.io.File(left).getCanonicalPath());
    right = char(java.io.File(right).getCanonicalPath());
    if ispc || ismac
        tf = strcmpi(left, right);
    else
        tf = strcmp(left, right);
    end
end

function value = Timestamp()
    value = char(datetime('now', 'TimeZone', 'local', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end
