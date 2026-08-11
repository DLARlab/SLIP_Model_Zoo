function identity = FloquetParentIdentity(config)
%FLOQUETPARENTIDENTITY Resolve and fingerprint the current parent branch.
%
% Identity includes both the bytes of the MAT container and the numeric
% 29-by-N branch payload.  The optional ExpectedParentSHA256 configuration
% pins the container bytes and is enforced whenever it is nonempty.

    filename = floquet.workflow.internal.ResolveFloquetParentBranch(config);
    loaded = load(filename);
    [branch, variable] = ExtractBranch(loaded);
    ValidateBranch(branch);

    identity = struct();
    identity.CanonicalPath = filename;
    identity.FileSHA256 = floquet.workflow.internal.FloquetFileSHA256(filename);
    identity.BranchSHA256 = floquet.workflow.internal.FloquetNumericSHA256(branch);
    identity.Variable = variable;
    identity.PointCount = size(branch, 2);
    identity.Size = size(branch);

    expected = ExpectedFingerprint(config);
    identity.ExpectedFileSHA256 = expected;
    if ~isempty(expected) && ~strcmp(identity.FileSHA256, expected)
        error('TemplateExperiment:ParentFingerprintMismatch', [ ...
            'The current parent MAT file does not match ' ...
            'config.ExpectedParentSHA256. Expected %s, observed %s (%s).'], ...
            expected, identity.FileSHA256, filename);
    end
end

function [branch, variable] = ExtractBranch(container)
    names = {'results','branch','continuation_branch','ContinuationBranch'};
    for k = 1:numel(names)
        if isfield(container, names{k}) && isnumeric(container.(names{k}))
            variable = names{k};
            branch = container.(names{k});
            return
        end
    end
    error('TemplateExperiment:ParentBranchVariable', [ ...
        'Parent MAT must contain numeric results, branch, ' ...
        'continuation_branch, or ContinuationBranch data.']);
end

function ValidateBranch(branch)
    if ~isnumeric(branch) || ~isreal(branch) || ~ismatrix(branch) || ...
            size(branch, 1) ~= 29 || isempty(branch)
        error('TemplateExperiment:ParentBranchShape', ...
            'The parent continuation branch must be a real 29-by-N array.');
    end
end

function expected = ExpectedFingerprint(config)
    expected = '';
    if ~isfield(config, 'ExpectedParentSHA256') || ...
            isempty(config.ExpectedParentSHA256)
        return
    end
    value = config.ExpectedParentSHA256;
    if isstring(value) && isscalar(value)
        value = char(value);
    end
    if ~ischar(value)
        error('TemplateExperiment:ExpectedParentFingerprint', ...
            'ExpectedParentSHA256 must be empty or one SHA-256 string.');
    end
    expected = lower(strtrim(value));
    if isempty(regexp(expected, '^[0-9a-f]{64}$', 'once'))
        error('TemplateExperiment:ExpectedParentFingerprint', ...
            'ExpectedParentSHA256 must contain exactly 64 hexadecimal digits.');
    end
end
