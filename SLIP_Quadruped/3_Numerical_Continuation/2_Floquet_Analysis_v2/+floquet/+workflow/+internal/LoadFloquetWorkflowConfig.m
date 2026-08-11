function [config, source] = LoadFloquetWorkflowConfig(input)
%LOADFLOQUETWORKFLOWCONFIG Load one workflow configuration without executing code.
%
%   CONFIG = LOADFLOQUETWORKFLOWCONFIG(SOURCE) accepts either one scalar
%   configuration struct or a MAT filename containing a scalar variable
%   named `config`.  Script/function filenames are deliberately not
%   executed: a GUI-selected file must be data, not arbitrary MATLAB code.
%
%   [CONFIG, SOURCEINFO] also describes whether the configuration came from
%   memory or a fingerprinted MAT file.

    if nargin ~= 1
        error('FloquetWorkflow:ConfigInput', ...
            'Supply one scalar config struct or one MAT filename.');
    end

    source = struct('Kind', '', 'CanonicalFile', '', 'SHA256', '', ...
        'SchemaVersion', '', 'ArtifactLayoutVersion', '', ...
        'LegacyReadOnly', false, 'MigrationRequired', false);
    if isstruct(input)
        if ~isscalar(input)
            error('FloquetWorkflow:ConfigContract', ...
                'An in-memory workflow configuration must be scalar.');
        end
        config = input;
        source.Kind = 'memory-struct';
    elseif IsScalarText(input)
        filename = char(string(input));
        [~, ~, extension] = fileparts(filename);
        if ~strcmpi(extension, '.mat')
            error('FloquetWorkflow:ConfigFileType', ...
                'A workflow configuration file must be a MAT file.');
        end
        if ~isfile(filename)
            error('FloquetWorkflow:ConfigFileMissing', ...
                'Workflow configuration MAT file does not exist: %s', ...
                filename);
        end
        filename = char(java.io.File(filename).getCanonicalPath());
        variables = whos('-file', filename);
        if ~any(strcmp({variables.name}, 'config'))
            error('FloquetWorkflow:ConfigVariableMissing', [ ...
                'Workflow configuration MAT file must contain one scalar ' ...
                'struct variable named config: %s'], filename);
        end
        loaded = load(filename, 'config');
        if ~isstruct(loaded.config) || ~isscalar(loaded.config)
            error('FloquetWorkflow:ConfigContract', ...
                'MAT variable config must be one scalar struct.');
        end
        config = loaded.config;
        source.Kind = 'mat-file';
        source.CanonicalFile = filename;
        AddPackagePath();
        source.SHA256 = ...
            floquet.workflow.internal.FloquetFileSHA256(filename);
    else
        error('FloquetWorkflow:ConfigInput', ...
            'Supply one scalar config struct or one MAT filename.');
    end

    RequireTopLevelContract(config);
    layout = ...
        floquet.workflow.internal.InspectFloquetWorkflowLayout(config);
    source.SchemaVersion = layout.SchemaVersion;
    source.ArtifactLayoutVersion = layout.ArtifactLayoutVersion;
    source.LegacyReadOnly = layout.IsLegacy;
    source.MigrationRequired = layout.IsLegacy;
end

function RequireTopLevelContract(config)
    required = {'ExperimentRoot', 'ParentBranchFile', 'AnalysisOptions', ...
        'Selection', 'Refinement', 'BranchSwitch', 'Continuation', ...
        'Validation', 'Files'};
    for k = 1:numel(required)
        if ~isfield(config, required{k})
            error('FloquetWorkflow:ConfigContract', ...
                'Workflow configuration is missing field %s.', required{k});
        end
    end
    if ~isstruct(config.Files) || ~isscalar(config.Files)
        error('FloquetWorkflow:ConfigContract', ...
            'config.Files must be one scalar struct.');
    end
    requiredFiles = {'Discovery', 'Refinement', 'Seeds', 'Daughters', ...
        'Validation'};
    for k = 1:numel(requiredFiles)
        name = requiredFiles{k};
        if ~isfield(config.Files, name) || ...
                ~IsScalarText(config.Files.(name)) || ...
                isempty(strtrim(char(string(config.Files.(name)))))
            error('FloquetWorkflow:ConfigContract', ...
                'config.Files.%s must be a nonempty scalar path.', name);
        end
    end
end

function AddPackagePath()
    internalRoot = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(fileparts(internalRoot)));
    entries = strsplit(path, pathsep);
    if ispc || ismac
        present = any(strcmpi(entries, root));
    else
        present = any(strcmp(entries, root));
    end
    if ~present
        addpath(root, '-begin');
    end
end

function tf = IsScalarText(value)
    tf = ischar(value) || (isstring(value) && isscalar(value));
end
