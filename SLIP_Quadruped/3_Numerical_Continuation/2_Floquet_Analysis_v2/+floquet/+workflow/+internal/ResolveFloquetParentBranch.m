function filename = ResolveFloquetParentBranch(config)
%RESOLVEFLOQUETPARENTBRANCH Resolve the parent MAT path reproducibly.
%
% Relative ParentBranchFile values are interpreted relative to
% config.ExperimentRoot, never relative to MATLAB's ambient working folder.

    if ~isstruct(config) || ~isscalar(config) || ...
            ~isfield(config, 'ExperimentRoot') || ...
            ~isfield(config, 'ParentBranchFile')
        error('TemplateExperiment:ParentBranchConfiguration', ...
            'ExperimentRoot and ParentBranchFile are required.');
    end
    root = TextScalar(config.ExperimentRoot, 'ExperimentRoot');
    filename = TextScalar(config.ParentBranchFile, 'ParentBranchFile');
    if isempty(strtrim(filename))
        error('TemplateExperiment:ParentBranchNotConfigured', ...
            ['Set ParentBranchFile before running parent-branch ' ...
             'discovery or refinement.']);
    end
    if ~IsAbsolutePath(filename)
        filename = fullfile(root, filename);
    end
    if ~isfile(filename)
        error('TemplateExperiment:ParentBranchMissing', ...
            'Parent branch file does not exist: %s', filename);
    end
    filename = char(java.io.File(filename).getCanonicalPath());
end

function value = TextScalar(value, name)
    if isstring(value) && isscalar(value)
        value = char(value);
    end
    if ~ischar(value)
        error('TemplateExperiment:ParentBranchConfiguration', ...
            '%s must be a character vector or scalar string.', name);
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
