function archive=ArchiveLargeJSONReport_v3(file,expectedSHA,archiveFolder)
%ARCHIVELARGEJSONREPORT_V3 Exact byte parts, no input removal or replacement.
% The caller separately publishes a compact view and a source-bound receipt.
    root=V3Root_v3();
    file=char(java.io.File(V3Path_v3(file)).getCanonicalPath());
    archiveFolder=char(java.io.File(V3OutputPath_v3(archiveFolder)).getCanonicalPath());
    assert(startsWith(file,[root,filesep])&&endsWith(file,'.json')&&isfile(file), ...
        'ArchiveLargeJSONReport_v3:Scope','Only an existing v3 scientific JSON report is an input.');
    assert(startsWith(archiveFolder,[root,filesep])&&~isfolder(archiveFolder)&&~isfile(archiveFolder), ...
        'ArchiveLargeJSONReport_v3:Destination','Use a fresh v3 archive directory.');
    assert(ischar(expectedSHA)&&~isempty(regexp(expectedSHA,'^[0-9a-f]{64}$','once')));
    original=dir(file);assert(isscalar(original)&&original.bytes>=100000000, ...
        'ArchiveLargeJSONReport_v3:Size','This explicit archive seam is for oversized JSON reports.');
    assert(strcmp(RoundSHA256_v3(file),expectedSHA),'ArchiveLargeJSONReport_v3:Hash');
    mkdir(archiveFolder);partsFolder=fullfile(archiveFolder,'byte_parts');mkdir(partsFolder);
    parts=struct('ordinal',{},'relative_path',{},'offset',{},'bytes',{},'sha256',{});
    maximumPartBytes=64000000;source=fopen(file,'rb');assert(source>=0);sourceClose=onCleanup(@()fclose(source));
    offset=0;ordinal=0;
    while offset<original.bytes
        ordinal=ordinal+1;relative=sprintf('byte_parts/part_%06d.bin',ordinal);
        partFile=fullfile(archiveFolder,strrep(relative,'/',filesep));part=fopen(partFile,'wb');assert(part>=0);
        partClose=onCleanup(@()fclose(part));written=0;wanted=min(maximumPartBytes,original.bytes-offset);
        while written<wanted
            bytes=fread(source,min(1048576,wanted-written),'*uint8');
            assert(~isempty(bytes),'ArchiveLargeJSONReport_v3:UnexpectedEOF');
            assert(fwrite(part,bytes,'uint8')==numel(bytes),'ArchiveLargeJSONReport_v3:Write');written=written+numel(bytes);
        end
        clear partClose;partStat=dir(partFile);assert(isscalar(partStat)&&partStat.bytes==wanted&&wanted<=maximumPartBytes);
        parts(end+1)=struct('ordinal',ordinal,'relative_path',relative,'offset',offset, ...
            'bytes',wanted,'sha256',RoundSHA256_v3(partFile)); %#ok<AGROW>
        offset=offset+wanted;
    end
    % MATLAB records the intentional read past EOF in ferror. Check actual
    % transfer errors before that probe; an empty probe+feof is expected.
    [~,ioerror]=ferror(source);assert(ioerror==0,'ArchiveLargeJSONReport_v3:Read');
    assert(isempty(fread(source,1,'*uint8'))&&feof(source),'ArchiveLargeJSONReport_v3:SourceGrew');
    clear sourceClose;
    finalStat=dir(file);assert(strcmp(RoundSHA256_v3(file),expectedSHA)&&isscalar(finalStat)&&finalStat.bytes==original.bytes, ...
        'ArchiveLargeJSONReport_v3:SourceChanged');
    manifest=fullfile(archiveFolder,'byte_archive.json');
    archive=struct('schema_version','large-JSON-exact-byte-archive-v3-1', ...
        'original_logical_path',file,'original_sha256',expectedSHA,'original_bytes',original.bytes, ...
        'maximum_part_bytes',maximumPartBytes,'parts',parts,'manifest_file',manifest, ...
        'original_file_removed',false,'original_file_modified',false,'new_maps',0, ...
        'read_contract','V3ReadArchivedJSONReport_v3(original_logical_path,original_sha256,manifest_file,manifest_sha256) returns exact original bytes in private temporary storage. Ordinary RoundSHA/V3SavedReadPath semantics are unchanged.');
    RoundJSON_v3(manifest,archive);manifestSHA=RoundSHA256_v3(manifest);
    [restored,receipt]=V3ReadArchivedJSONReport_v3(file,expectedSHA,manifest,manifestSHA);
    restoredStat=dir(restored);assert(strcmp(receipt.reconstructed_sha256,expectedSHA)&&isscalar(restoredStat)&&restoredStat.bytes==original.bytes);delete(restored);
    archive.manifest_sha256=manifestSHA;archive.verified_exact_reconstruction=true;
    RoundJSON_v3(fullfile(archiveFolder,'archive_verification.json'),archive);
end
