function floquetRoot = AddFloquetWorkflowPath(config)
%ADDFLOQUETWORKFLOWPATH Bootstrap the canonical Floquet workflow package.

    floquetRoot = ConfiguredFloquetRoot(config);
    if ~isempty(floquetRoot)
        ValidateFloquetRoot(floquetRoot);
    else
        startDirectory = fileparts(mfilename('fullpath'));
        floquetRoot = FindFloquetRoot(startDirectory);
    end
    addpath(floquetRoot, '-begin');
end

function root = ConfiguredFloquetRoot(config)
    root = '';
    if ~isstruct(config) || ~isscalar(config) || ...
            ~isfield(config, 'FloquetRoot') || isempty(config.FloquetRoot)
        return
    end
    value = config.FloquetRoot;
    if ~((ischar(value) && (isrow(value) || isempty(value))) || ...
            (isstring(value) && isscalar(value)))
        error('TemplateExperiment:InvalidFloquetRoot', ...
            'config.FloquetRoot must be a scalar path.');
    end
    root = char(string(value));
end

function root = FindFloquetRoot(startDirectory)
    current = startDirectory;
    for depth = 0:8
        if IsFloquetRoot(current)
            root = current;
            return
        end
        parent = fileparts(current);
        if isempty(parent) || strcmp(parent, current)
            break
        end
        current = parent;
    end
    error('TemplateExperiment:FloquetRootNotFound', [ ...
        'Could not locate a Floquet-v2 root exposing ' ...
        'floquet.workflow.runStage from %s. Set config.FloquetRoot ' ...
        'explicitly.'], startDirectory);
end

function ValidateFloquetRoot(root)
    if ~IsFloquetRoot(root)
        error('TemplateExperiment:InvalidFloquetRoot', [ ...
            'Configured FloquetRoot does not expose ' ...
            'floquet.workflow.runStage: %s'], root);
    end
end

function tf = IsFloquetRoot(root)
    tf = isfolder(root) && isfile(fullfile(root, '+floquet', ...
        '+workflow', 'runStage.m'));
end
