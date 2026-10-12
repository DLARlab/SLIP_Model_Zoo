function [file,receipt]=V3ReadArchivedJSONReport_v3(logicalPath,expectedSHA,manifestFile,manifestSHA)
%V3READARCHIVEDJSONREPORT_V3 Explicit historical byte identity, private restore.
% This never rewrites the logical report or substitutes a compact view's SHA.
    root=V3Root_v3();logicalPath=char(java.io.File(V3Path_v3(logicalPath)).getCanonicalPath());
    manifestFile=char(java.io.File(V3Path_v3(manifestFile)).getCanonicalPath());
    assert(startsWith(logicalPath,[root,filesep])&&endsWith(logicalPath,'.json') ...
        &&startsWith(manifestFile,[root,filesep])&&isfile(manifestFile), ...
        'V3ReadArchivedJSONReport_v3:Scope','Require the exact v3 JSON identity and archive manifest.');
    for hash={expectedSHA,manifestSHA},assert(ischar(hash{1})&&~isempty(regexp(hash{1},'^[0-9a-f]{64}$','once')));end
    assert(strcmp(RoundSHA256_v3(manifestFile),manifestSHA),'V3ReadArchivedJSONReport_v3:ManifestHash');
    archive=jsondecode(fileread(manifestFile));
    assert(strcmp(archive.schema_version,'large-JSON-exact-byte-archive-v3-1') ...
        &&strcmp(archive.original_logical_path,logicalPath)&&strcmp(archive.original_sha256,expectedSHA) ...
        &&strcmp(archive.manifest_file,manifestFile)&&archive.original_bytes>=100000000 ...
        &&archive.maximum_part_bytes==64000000&&~isempty(archive.parts), ...
        'V3ReadArchivedJSONReport_v3:Identity','Old logical path AND original SHA are required.');
    folder=fileparts(manifestFile);file=[tempname(tempdir),'.original.json'];
    temporary=char(java.io.File(file).getCanonicalPath());
    assert(~startsWith(temporary,[root,filesep]),'V3ReadArchivedJSONReport_v3:Destination');
    output=fopen(file,'wb');assert(output>=0);outputClose=onCleanup(@()fclose(output));offset=0;
    try
        for k=1:numel(archive.parts)
            part=archive.parts(k);
            assert(part.ordinal==k&&part.offset==offset&&part.bytes>0&&part.bytes<=archive.maximum_part_bytes ...
                &&strcmp(part.relative_path,sprintf('byte_parts/part_%06d.bin',k)), ...
                'V3ReadArchivedJSONReport_v3:PartOrder');
            partFile=char(java.io.File(fullfile(folder,strrep(part.relative_path,'/',filesep))).getCanonicalPath());
            partStat=dir(partFile);assert(startsWith(partFile,[folder,filesep])&&isfile(partFile)&&isscalar(partStat)&&partStat.bytes==part.bytes ...
                &&strcmp(RoundSHA256_v3(partFile),part.sha256),'V3ReadArchivedJSONReport_v3:PartHash');
            input=fopen(partFile,'rb');assert(input>=0);inputClose=onCleanup(@()fclose(input));written=0;
            while written<part.bytes
                bytes=fread(input,min(1048576,part.bytes-written),'*uint8');assert(~isempty(bytes));
                assert(fwrite(output,bytes,'uint8')==numel(bytes));written=written+numel(bytes);
            end
            [~,ioerror]=ferror(input);assert(ioerror==0,'V3ReadArchivedJSONReport_v3:Read');
            assert(isempty(fread(input,1,'*uint8'))&&feof(input));clear inputClose;
            assert(strcmp(RoundSHA256_v3(partFile),part.sha256),'V3ReadArchivedJSONReport_v3:PartChanged');
            offset=offset+written;
        end
        clear outputClose;
        restoredStat=dir(file);assert(offset==archive.original_bytes&&isscalar(restoredStat)&&restoredStat.bytes==offset ...
            &&strcmp(RoundSHA256_v3(file),expectedSHA),'V3ReadArchivedJSONReport_v3:OriginalHash');
        assert(strcmp(RoundSHA256_v3(manifestFile),manifestSHA),'V3ReadArchivedJSONReport_v3:ManifestChanged');
    catch exception
        clear outputClose;if isfile(file),delete(file);end;rethrow(exception)
    end
    receipt=struct('schema_version','large-JSON-private-restoration-v3-1', ...
        'original_logical_path',logicalPath,'original_sha256',expectedSHA, ...
        'manifest_file',manifestFile,'manifest_sha256',manifestSHA,'read_path',file, ...
        'reconstructed_sha256',expectedSHA,'reconstructed_bytes',offset, ...
        'part_count',numel(archive.parts),'logical_report_rewritten',false, ...
        'compact_view_not_used_as_historical_bytes',true,'caller_must_remove_temporary_after_read',true,'new_maps',0);
end
