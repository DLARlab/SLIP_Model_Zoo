function fingerprint = FloquetFileSHA256(filename)
%FLOQUETFILESHA256 Return the lowercase SHA-256 of an upstream artifact.
%
% Stage handoffs save this digest alongside the source path so a frozen
% experiment cannot silently combine downstream results with a replaced MAT
% file. Failure to hash is a reproducibility error, not an empty provenance
% field.

    if isstring(filename) && isscalar(filename)
        filename = char(filename);
    end
    if ~ischar(filename) || ~isfile(filename)
        error('TemplateExperiment:HashSourceMissing', ...
            'Cannot hash missing upstream artifact: %s', char(string(filename)));
    end
    fileID = fopen(filename, 'rb');
    if fileID < 0
        error('TemplateExperiment:HashSourceUnreadable', ...
            'Cannot open upstream artifact for hashing: %s', filename);
    end
    cleanup = onCleanup(@() fclose(fileID));
    try
        digest = java.security.MessageDigest.getInstance('SHA-256');
        while true
            bytes = fread(fileID, 1024 * 1024, '*uint8');
            if isempty(bytes)
                break
            end
            digest.update(typecast(bytes(:), 'int8'));
        end
        raw = typecast(digest.digest(), 'uint8');
        fingerprint = lower(reshape(dec2hex(raw, 2).', 1, []));
    catch exception
        error('TemplateExperiment:HashFailed', ...
            'Could not hash upstream artifact %s: %s', ...
            filename, exception.message);
    end
    clear cleanup
end
