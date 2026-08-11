function canonicalOutputs = PreflightFloquetArtifacts( ...
        filenames, overwrite, protectedInputs)
%PREFLIGHTFLOQUETARTIFACTS Validate an artifact write set before any write.
%
% In addition to the ordinary immutable-by-default policy, this guard rejects
% two output names that resolve to the same canonical path and rejects an
% output that aliases a protected parent, upstream artifact, reference file,
% or callback implementation.  Alias checks are unconditional: Overwrite=true
% authorizes replacing the intended output, never an input.

    if nargin < 3 || isempty(protectedInputs)
        protectedInputs = {};
    end
    overwrite = StrictLogical(overwrite, 'overwrite');
    outputs = NormalizePaths(filenames, 'output');
    protected = NormalizePaths(protectedInputs, 'protected input');
    canonicalOutputs = cellfun(@CanonicalPath, outputs, ...
        'UniformOutput', false);
    canonicalProtected = cellfun(@CanonicalPath, protected, ...
        'UniformOutput', false);

    [~, first] = unique(PathKeys(canonicalOutputs), 'stable');
    if numel(first) ~= numel(canonicalOutputs)
        duplicate = FirstDuplicate(canonicalOutputs);
        error('TemplateExperiment:DuplicateArtifactOutput', [ ...
            'Two stage outputs resolve to the same canonical path: %s. ' ...
            'Every MAT/CSV/ray artifact must have one unique destination.'], ...
            duplicate);
    end

    protectedKeys = PathKeys(canonicalProtected);
    outputKeys = PathKeys(canonicalOutputs);
    aliases = ismember(outputKeys, protectedKeys);
    if any(aliases)
        output = canonicalOutputs{find(aliases, 1)};
        error('TemplateExperiment:ArtifactAliasesProtectedInput', [ ...
            'Refusing to write output %s because it aliases a protected ' ...
            'parent, upstream, reference, or implementation file. ' ...
            'Overwrite permission cannot override this safety boundary.'], ...
            output);
    end

    if overwrite
        return
    end
    existing = canonicalOutputs(cellfun(@isfile, canonicalOutputs));
    if ~isempty(existing)
        error('TemplateExperiment:ArtifactExists', [ ...
            'Refusing to overwrite existing stage artifact(s): %s. Set ' ...
            'config.OverwriteResults=true only for an intentional rerun.'], ...
            strjoin(existing, ', '));
    end
end

function values = NormalizePaths(values, label)
    if isempty(values)
        values = {};
        return
    end
    values = cellstr(string(values));
    values = values(:).';
    for k = 1:numel(values)
        if isempty(strtrim(values{k}))
            error('TemplateExperiment:ArtifactPath', ...
                'A configured %s path is empty.', label);
        end
    end
end

function filename = CanonicalPath(filename)
    filename = char(java.io.File(filename).getCanonicalPath());
end

function keys = PathKeys(paths)
    keys = string(paths);
    if ispc
        keys = lower(keys);
    end
end

function duplicate = FirstDuplicate(paths)
    keys = PathKeys(paths);
    duplicate = paths{1};
    for k = 2:numel(keys)
        if any(keys(k) == keys(1:k - 1))
            duplicate = paths{k};
            return
        end
    end
end

function value = StrictLogical(value, name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isreal(value) && isfinite(value) && ...
             any(value == [0 1]))))
        error('TemplateExperiment:ArtifactPreflightFlag', ...
            '%s must be scalar logical or numeric 0/1.', name);
    end
    value = logical(value);
end
