function layout = InspectFloquetWorkflowLayout(config)
%INSPECTFLOQUETWORKFLOWLAYOUT Classify config version and persisted state.
%
% The classifier is read-only. In particular, a legacy configuration is
% never supplemented with v2 paths or rebased beneath ExperimentRoot.

    if ~isstruct(config) || ~isscalar(config)
        error('FloquetWorkflow:ConfigContract', ...
            'Workflow configuration must be one scalar struct.');
    end

    [schemaVersion, implicitLegacy] = SchemaVersion(config);
    layout = struct( ...
        'SchemaVersion', schemaVersion, ...
        'ArtifactLayoutVersion', '', ...
        'ImplicitLegacyVersion', implicitLegacy, ...
        'IsLegacy', false, ...
        'Writable', false, ...
        'HasNonemptyChain', false, ...
        'ExistingArtifactFiles', {{}}, ...
        'ExistingCheckpointFiles', {{}}, ...
        'CanMigrate', false, ...
        'Status', '', ...
        'Message', '');

    switch schemaVersion
        case 'floquet-workflow-config-v1'
            layout.IsLegacy = true;
            layout.ArtifactLayoutVersion = 'legacy-explicit-paths';
            [layout.ExistingArtifactFiles, ...
                layout.ExistingCheckpointFiles] = ExistingLegacyState(config);
            layout.HasNonemptyChain = ...
                ~isempty(layout.ExistingArtifactFiles) || ...
                ~isempty(layout.ExistingCheckpointFiles);
            layout.CanMigrate = ~layout.HasNonemptyChain;
            if layout.HasNonemptyChain
                layout.Status = 'legacy-read-only';
                if ~isempty(layout.ExistingCheckpointFiles)
                    layout.Message = [ ...
                        'Legacy v1 checkpoints cannot be resumed by the v2 ' ...
                        'workflow. The explicit legacy paths remain ' ...
                        'available for read-only inspection.'];
                else
                    layout.Message = [ ...
                        'This legacy v1 artifact chain is read-only. Its ' ...
                        'explicit paths were preserved and were not rebased.'];
                end
            else
                layout.Status = 'legacy-empty-migration-required';
                layout.Message = [ ...
                    'This empty legacy v1 configuration must be explicitly ' ...
                    'converted with floquet.workflow.migrate before a ' ...
                    'workflow stage can run.'];
            end
        case 'floquet-workflow-config-v2'
            artifactVersion = RequiredTextField(config, ...
                'ArtifactLayoutVersion');
            if ~strcmp(artifactVersion, 'numbered-artifacts-v1')
                error('FloquetWorkflow:UnsupportedArtifactLayout', [ ...
                    'Unsupported ArtifactLayoutVersion "%s". Expected ' ...
                    'numbered-artifacts-v1.'], artifactVersion);
            end
            layout.ArtifactLayoutVersion = artifactVersion;
            layout.Writable = true;
            layout.Status = 'current';
            layout.Message = ...
                'Current writable v2 configuration with numbered artifacts.';
        otherwise
            error('FloquetWorkflow:UnsupportedConfigVersion', ...
                'Unsupported workflow SchemaVersion "%s".', schemaVersion);
    end
end

function [value, implicitLegacy] = SchemaVersion(config)
    implicitLegacy = ~isfield(config, 'SchemaVersion') || ...
        isempty(config.SchemaVersion);
    if implicitLegacy
        value = 'floquet-workflow-config-v1';
        return
    end
    value = RequiredTextField(config, 'SchemaVersion');
end

function value = RequiredTextField(source, field)
    value = source.(field);
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error('FloquetWorkflow:ConfigContract', ...
            'config.%s must be scalar text.', field);
    end
    value = strtrim(char(string(value)));
    if isempty(value)
        error('FloquetWorkflow:ConfigContract', ...
            'config.%s cannot be empty.', field);
    end
end

function [artifacts, checkpoints] = ExistingLegacyState(config)
    artifacts = {};
    checkpoints = {};
    if isfield(config, 'Files') && isstruct(config.Files) && ...
            isscalar(config.Files)
        names = fieldnames(config.Files);
        for k = 1:numel(names)
            value = config.Files.(names{k});
            if ~IsScalarText(value)
                continue
            end
            filename = strtrim(char(string(value)));
            if isempty(filename)
                continue
            end
            if isfile(filename)
                artifacts{end + 1} = Canonical(filename); %#ok<AGROW>
            elseif isfolder(filename) && DirectoryContainsFile(filename)
                artifacts{end + 1} = Canonical(filename); %#ok<AGROW>
            end
        end
    end
    checkpoints = ExistingCheckpoint(config, 'AnalysisOptions', checkpoints);
    checkpoints = ExistingCheckpoint(config, 'Continuation', checkpoints);
    artifacts = unique(artifacts, 'stable');
    checkpoints = unique(checkpoints, 'stable');
end

function files = ExistingCheckpoint(config, section, files)
    if ~isfield(config, section) || ~isstruct(config.(section)) || ...
            ~isscalar(config.(section)) || ...
            ~isfield(config.(section), 'CheckpointFile')
        return
    end
    value = config.(section).CheckpointFile;
    if ~IsScalarText(value)
        return
    end
    filename = strtrim(char(string(value)));
    if ~isempty(filename) && isfile(filename)
        files{end + 1} = Canonical(filename);
    end
end

function tf = DirectoryContainsFile(folder)
    entries = dir(fullfile(folder, '**', '*'));
    tf = any(~[entries.isdir]);
end

function value = Canonical(value)
    value = char(java.io.File(value).getCanonicalPath());
end

function tf = IsScalarText(value)
    tf = ischar(value) || (isstring(value) && isscalar(value));
end
