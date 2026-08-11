function paths = ensureRuntimePaths(includeContinuation)
%ENSURERUNTIMEPATHS Add unchanged SLIP production dependencies.
%
% Package functions own their dependency setup so callers need add only the
% Floquet root. This helper never exposes package internals as global APIs.

    if nargin < 1
        includeContinuation = false;
    end
    internalRoot = fileparts(mfilename('fullpath'));
    floquetRoot = fileparts(fileparts(internalRoot));
    slipRoot = fileparts(fileparts(floquetRoot));
    paths = { ...
        fullfile(slipRoot,'1_Dynamic_Frameworks','v2'), ...
        fullfile(slipRoot,'4_Solution_Management')};
    if includeContinuation
        paths{end+1} = fullfile(slipRoot,'3_Numerical_Continuation', ...
            '1_Continuation_Algorithm');
    end
    for k = 1:numel(paths)
        if ~isfolder(paths{k})
            error('floquet:runtime:MissingDependency', ...
                'Required unchanged SLIP dependency is missing: %s',paths{k});
        end
        if ~PathContains(paths{k})
            addpath(paths{k},'-end');
        end
    end
end

function tf = PathContains(folder)
    expected = CanonicalPath(folder);
    entries = strsplit(path,pathsep);
    tf = false;
    for k = 1:numel(entries)
        if isempty(entries{k})
            continue
        end
        try
            if strcmp(CanonicalPath(entries{k}),expected)
                tf = true;
                return
            end
        catch
            % Ignore stale path entries.
        end
    end
end

function value = CanonicalPath(value)
    value = char(java.io.File(char(string(value))).getCanonicalPath());
end
