function identity = FloquetCallbackIdentity(callback)
%FLOQUETCALLBACKIDENTITY Record a callback name and file fingerprint.

    identity = struct('Configured', false, 'Function', '', 'Type', '', ...
        'FileBacked', false, 'ImplementationFile', '', ...
        'ImplementationSHA256', '', 'FingerprintStatus', 'not-configured');
    if isempty(callback)
        return
    end
    if ~isa(callback, 'function_handle')
        error('TemplateExperiment:CallbackIdentity', ...
            'Configured callback values must be function handles.');
    end
    metadata = functions(callback);
    identity.Configured = true;
    identity.Function = func2str(callback);
    if isfield(metadata, 'type')
        identity.Type = char(string(metadata.type));
    end
    filename = '';
    if isfield(metadata, 'file') && ~isempty(metadata.file) && ...
            isfile(metadata.file)
        filename = metadata.file;
    else
        located = which(identity.Function);
        if ~isempty(located) && isfile(located)
            filename = located;
        end
    end
    if isempty(filename)
        identity.FingerprintStatus = 'not-file-backed';
        return
    end
    filename = char(java.io.File(filename).getCanonicalPath());
    identity.FileBacked = true;
    identity.ImplementationFile = filename;
    identity.ImplementationSHA256 = floquet.workflow.internal.FloquetFileSHA256(filename);
    identity.FingerprintStatus = 'computed';
end
