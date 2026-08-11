function fingerprint = FloquetNumericSHA256(value)
%FLOQUETNUMERICSHA256 Hash a numeric array using the analyzer's exact chart.
%
% The class and dimensions are included before the column-major payload.
% This deliberately matches AnalyzeFloquetBranch/NumericArraySHA256 so a
% stage can independently verify the branch matrix stored in the parent MAT.

    if ~isnumeric(value)
        error('TemplateExperiment:NumericHashInput', ...
            'FloquetNumericSHA256 requires a numeric array.');
    end
    try
        digest = java.security.MessageDigest.getInstance('SHA-256');
        header = uint8(sprintf('%s|%s|', class(value), mat2str(size(value))));
        digest.update(typecast(header(:), 'int8'));
        bytes = typecast(value(:), 'uint8');
        digest.update(typecast(bytes(:), 'int8'));
        raw = typecast(digest.digest(), 'uint8');
        fingerprint = lower(reshape(dec2hex(raw, 2).', 1, []));
    catch exception
        error('TemplateExperiment:NumericHashFailed', ...
            'Could not hash numeric branch data: %s', exception.message);
    end
end
