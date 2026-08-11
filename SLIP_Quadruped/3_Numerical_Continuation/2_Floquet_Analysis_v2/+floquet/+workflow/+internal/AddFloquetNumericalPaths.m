function floquetRoot = AddFloquetNumericalPaths(config)
%ADDFLOQUETNUMERICALPATHS Resolve and add the Floquet-v2 numerical root.
%
% CONFIG.FloquetRoot, when nonempty, is authoritative and must contain
% +floquet/computeFDM.m. Otherwise a bounded upward search starts at the
% workflow root, allowing templates and reference packages nested below the
% clean Floquet-v2 root.

    if nargin < 1 || ~isstruct(config) || ~isscalar(config) || ...
            ~isfield(config, 'ExperimentRoot')
        error('TemplateExperiment:InvalidConfiguration', ...
            'ExperimentRoot is required to resolve the Floquet-v2 path.');
    end
    if isfield(config, 'FloquetRoot') && ~isempty(config.FloquetRoot)
        floquetRoot = char(string(config.FloquetRoot));
        ValidateFloquetRoot(floquetRoot, 'configured');
    else
        floquetRoot = FindFloquetRoot(config.ExperimentRoot);
    end
    addpath(floquetRoot);
end

function root = FindFloquetRoot(startDirectory)
    current = char(string(startDirectory));
    for depth = 0:8
        if isfile(fullfile(current, '+floquet', 'computeFDM.m'))
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
        'Could not find an ancestor containing +floquet/computeFDM.m from %s. ' ...
        'Set config.FloquetRoot explicitly.'], char(string(startDirectory)));
end

function ValidateFloquetRoot(root, source)
    if ~isfolder(root) || ...
            ~isfile(fullfile(root, '+floquet', 'computeFDM.m'))
        error('TemplateExperiment:InvalidFloquetRoot', ...
            '%s FloquetRoot does not contain +floquet/computeFDM.m: %s', ...
            source, root);
    end
end
