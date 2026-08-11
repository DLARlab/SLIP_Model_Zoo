function [production, identity] = evaluatorIdentity( ...
        callback, expectedFunction)
%EVALUATORIDENTITY Verify a v2 production callback by package/file identity.
%
%   TF = FLOQUET.INTERNAL.PROVENANCE.EVALUATORIDENTITY(HANDLE,NAME) is true
%   only when HANDLE names NAME and MATLAB bound the handle to the canonical
%   qualified implementation shipped in this Floquet-v2 tree. Historical
%   v1 global callback identities are never production evaluators.
%
%   Supported production callbacks are floquet.computeFDM and
%   floquet.validatePeriodicOrbit. IDENTITY uses the v2 provenance schema.

    if ~isa(callback, 'function_handle')
        error('IsCanonicalFloquetEvaluator:FunctionHandle', ...
            'callback must be a function handle.');
    end
    if isstring(expectedFunction) && isscalar(expectedFunction)
        expectedFunction = char(expectedFunction);
    end
    if ~ischar(expectedFunction)
        error('IsCanonicalFloquetEvaluator:ExpectedFunction', ...
            'expectedFunction must be scalar text.');
    end

    provenanceRoot = fileparts(mfilename('fullpath'));
    packageRoot = fileparts(fileparts(provenanceRoot));
    floquetRoot = fileparts(packageRoot);
    switch expectedFunction
        case 'floquet.computeFDM'
            expectedFile = fullfile(packageRoot, 'computeFDM.m');
            legacyFunction = 'ComputeFloquetFDM';
        case 'floquet.validatePeriodicOrbit'
            expectedFile = fullfile(packageRoot, 'validatePeriodicOrbit.m');
            legacyFunction = 'ValidatePeriodicOrbit';
        otherwise
            error('IsCanonicalFloquetEvaluator:UnsupportedFunction', ...
                'Unsupported production callback %s.', expectedFunction);
    end
    if ~isfile(expectedFile)
        error('IsCanonicalFloquetEvaluator:MissingCanonicalFile', ...
            'Canonical callback file is missing: %s', expectedFile);
    end

    metadata = functions(callback);
    callbackName = func2str(callback);
    callbackType = '';
    if isfield(metadata, 'type') && ~isempty(metadata.type)
        callbackType = char(string(metadata.type));
    end
    actualFile = '';
    if isfield(metadata, 'file') && ~isempty(metadata.file) && ...
            isfile(metadata.file)
        actualFile = CanonicalPath(metadata.file);
    else
        resolvedFile = which(callbackName);
        if ~isempty(resolvedFile) && isfile(resolvedFile)
            actualFile = CanonicalPath(resolvedFile);
        end
    end
    expectedFile = CanonicalPath(expectedFile);

    nameMatches = strcmp(callbackName, expectedFunction);
    fileMatches = ~isempty(actualFile) && strcmp(actualFile, expectedFile);
    production = nameMatches && fileMatches;
    identity = struct( ...
        'SchemaVersion', 'floquet-evaluator-identity-v2', ...
        'Function', callbackName, ...
        'Type', callbackType, ...
        'ExpectedFunction', expectedFunction, ...
        'ExpectedFile', expectedFile, ...
        'ActualFile', actualFile, ...
        'NameMatches', nameMatches, ...
        'FileMatches', fileMatches, ...
        'ProductionEvaluator', production, ...
        'AuthorityModel', 'qualified-package-file-identity', ...
        'LegacyV1Function', legacyFunction, ...
        'LegacyV1ReadPolicy', [ ...
            'Completed v1 analysis artifacts are read-only evidence; ' ...
            'legacy callbacks and v1 checkpoints have no v2 production authority.'], ...
        'FloquetRoot', CanonicalPath(floquetRoot));
end

function path = CanonicalPath(path)
    path = char(java.io.File(char(string(path))).getCanonicalPath());
end
