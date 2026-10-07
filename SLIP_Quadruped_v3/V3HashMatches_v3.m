function [matched, detail] = V3HashMatches_v3(expectedSha256, file)
%V3HASHMATCHES_V3 Check bytes or an explicitly journaled source relocation.
% Historical checksums remain unchanged. A journaled match reports the actual
% current checksum separately and verifies the archived original source bytes.
% The organization journal records path-only edits; this function verifies its
% source epochs, rather than certifying numerical equivalence of edited code.
    if ~(ischar(expectedSha256) || (isstring(expectedSha256) && isscalar(expectedSha256)))
        error('V3HashMatches_v3:InvalidChecksum', 'Expected checksum must be a text scalar.');
    end
    expectedSha256 = lower(char(expectedSha256));
    if isempty(regexp(expectedSha256, '^[0-9a-f]{64}$', 'once'))
        error('V3HashMatches_v3:InvalidChecksum', 'Expected checksum must contain 64 hexadecimal digits.');
    end
    if ~(ischar(file) || (isstring(file) && isscalar(file)))
        error('V3HashMatches_v3:InvalidPath', 'File path must be a text scalar.');
    end
    root = fileparts(mfilename('fullpath'));
    currentPath = resolvePath(file, root);
    matched = false;
    detail = struct('match_kind', 'missing_current_file', ...
        'current_path', currentPath, 'expected_sha256', expectedSha256, ...
        'current_sha256', '');
    if ~isfile(currentPath), return; end
    actualSha256 = RoundSHA256_v3(currentPath);
    detail.current_sha256 = actualSha256;
    if strcmp(actualSha256, expectedSha256)
        matched = true;
        detail.match_kind = 'exact_bytes';
        return;
    end
    detail.match_kind = 'checksum_mismatch';
    journalFile = fullfile(root, 'Audits_v3', 'Folder_Organization', 'source_relocations.json');
    if ~isfile(journalFile), return; end
    journal = jsondecode(fileread(journalFile));
    if ~isstruct(journal) || ~isfield(journal, 'records')
        error('V3HashMatches_v3:InvalidJournal', 'The source relocation journal must contain records.');
    end
    records = journal.records;
    required = {'old_path', 'new_path', 'before_sha256', 'after_sha256', 'before_archive'};
    for k = 1:numel(records)
        if iscell(records), record = records{k}; else, record = records(k); end
        if ~isstruct(record) || ~all(isfield(record, required))
            error('V3HashMatches_v3:InvalidJournal', 'A source relocation record lacks required fields.');
        end
        if ~strcmp(expectedSha256, record.before_sha256) || ~strcmp(actualSha256, record.after_sha256)
            continue;
        end
        relocatedPath = resolvePath(record.new_path, root);
        if ~strcmp(currentPath, relocatedPath), continue; end
        archivePath = resolvePath(record.before_archive, root);
        canonicalRoot = char(java.io.File(root).getCanonicalPath());
        if ~startsWith(archivePath, [canonicalRoot, filesep]) || ~isfile(archivePath)
            continue;
        end
        if ~strcmp(RoundSHA256_v3(archivePath), record.before_sha256), continue; end
        matched = true;
        detail.match_kind = 'journaled_source_relocation';
        return;
    end
end

function file = resolvePath(file, root)
    file = char(file);
    if ~java.io.File(file).isAbsolute(), file = fullfile(root, file); end
    file = V3Path_v3(file);
    file = char(java.io.File(file).getCanonicalPath());
end
