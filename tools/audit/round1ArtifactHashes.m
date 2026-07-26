function hashes = round1ArtifactHashes(repositoryRoot)
%ROUND1ARTIFACTHASHES SHA-256 hashes for research artifacts.
%   HASHES = ROUND1ARTIFACTHASHES(REPOSITORYROOT) returns a table covering
%   every MAT, FIG, and MLX file below REPOSITORYROOT. The function is
%   read-only.

    if nargin < 1 || isempty(repositoryRoot)
        repositoryRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    end

    patterns = {'*.mat', '*.fig', '*.mlx'};
    files = dir(fullfile(repositoryRoot, '**', patterns{1}));
    for iPattern = 2:numel(patterns)
        files = [files; dir(fullfile(repositoryRoot, '**', patterns{iPattern}))]; %#ok<AGROW>
    end

    fullPaths = strings(numel(files), 1);
    relativePaths = strings(numel(files), 1);
    bytes = zeros(numel(files), 1);
    sha256 = strings(numel(files), 1);

    rootPrefix = string(repositoryRoot) + filesep;
    for iFile = 1:numel(files)
        fullPath = fullfile(files(iFile).folder, files(iFile).name);
        fullPaths(iFile) = string(fullPath);
        relativePaths(iFile) = erase(string(fullPath), rootPrefix);
        bytes(iFile) = files(iFile).bytes;
        sha256(iFile) = HashFileSha256(fullPath);
    end

    hashes = table(relativePaths, bytes, sha256, fullPaths, ...
        'VariableNames', {'relative_path', 'bytes', 'sha256', 'full_path'});
    hashes = sortrows(hashes, 'relative_path');
end

function digestText = HashFileSha256(filename)
    messageDigest = java.security.MessageDigest.getInstance('SHA-256');
    fileID = fopen(filename, 'rb');
    if fileID < 0
        error('round1ArtifactHashes:OpenFailed', ...
            'Unable to open "%s" for hashing.', filename);
    end
    cleanup = onCleanup(@() fclose(fileID));

    while true
        block = fread(fileID, 1024 * 1024, '*uint8');
        if isempty(block)
            break;
        end
        messageDigest.update(block);
    end

    digest = typecast(messageDigest.digest(), 'uint8');
    digestText = lower(string(reshape(dec2hex(digest, 2).', 1, [])));
end
