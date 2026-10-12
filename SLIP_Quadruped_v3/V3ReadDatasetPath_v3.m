function [file,resolution]=V3ReadDatasetPath_v3(inputPath,expectedSHA,indexFile)
%V3READDATASETPATH_V3 Resolve scientific raw MAT reads, never output paths.
% Logical aliases are unprefixed MAT files directly under the P1/P2 roots.
% An optional expected SHA selects a recorded historical version. Without it,
% an index must explicitly name exactly one current version. The optional
% indexFile supports prospective native controls; it never creates an index.
    root=fileparts(mfilename('fullpath'));
    requested=textScalar(inputPath,'Input');rejectTraversal(requested);
    logical=relativePath(root,V3Path_v3(requested));study=rawStudy(logical);
    if nargin<2,expectedSHA='';end
    expectedSHA=hashText(expectedSHA,true);
    if nargin<3,indexFile=fullfile(root,'Audits_v3','Raw_Dataset_Locations','current.json');end
    indexFile=canonicalWithin(root,textScalar(indexFile,'IndexPath'));
    indexRelative=relativePath(root,indexFile);
    assert(startsWith(indexRelative,'Audits_v3/')||startsWith(indexRelative,'Research_v3/'), ...
        'V3ReadDatasetPath_v3:IndexPath','A read index must be inside the v3 audit or research tree.');
    indexed=false;indexHash='';entryIndex=NaN;recordedSHA='';
    file=canonicalWithin(root,logical);
    if isfile(indexFile)
        indexHash=physicalSHA(indexFile);index=jsondecode(fileread(indexFile));
        assert(isfield(index,'schema_version')&&strcmp(index.schema_version,'scientific-raw-dataset-read-index-v3-1') ...
            &&isfield(index,'publication_complete')&&islogical(index.publication_complete)&&isscalar(index.publication_complete)&&index.publication_complete ...
            &&isfield(index,'writer_state')&&strcmp(index.writer_state,'stopped'), ...
            'V3ReadDatasetPath_v3:IndexWriter','A staged or running writer index cannot route scientific reads.');
        assert(isfield(index,'entries')&&isstruct(index.entries), ...
            'V3ReadDatasetPath_v3:IndexSchema','The read index must contain structured entries.');
        matches=[];entryHashes=cell(1,numel(index.entries));
        for k=1:numel(index.entries)
            entry=index.entries(k);
            assert(all(isfield(entry,{'logical_path','read_path','sha256','is_current'})), ...
                'V3ReadDatasetPath_v3:IndexSchema','Every entry needs logical_path, read_path, sha256 and is_current.');
            entryLogical=relativePath(root,textScalar(entry.logical_path,'LogicalPath'));entryStudy=rawStudy(entryLogical);
            target=relativePath(root,textScalar(entry.read_path,'ReadPath'));
            allowed=strcmp(target,entryLogical)||startsWith(target,[entryStudy,'/Bifurcation_Audits/']);
            [~,~,extension]=fileparts(target);
            assert(allowed&&strcmpi(extension,'.mat'),'V3ReadDatasetPath_v3:ReadPath', ...
                'A raw read target must be its direct logical file or a MAT in the same study Bifurcation_Audits tree.');
            entryHashes{k}=hashText(entry.sha256,false);
            assert(islogical(entry.is_current)&&isscalar(entry.is_current),'V3ReadDatasetPath_v3:IndexSchema','is_current must be logical.');
            if strcmp(entryLogical,logical),matches(end+1)=k;end %#ok<AGROW>
        end
        if ~isempty(matches)
            if isempty(expectedSHA)
                chosen=matches([index.entries(matches).is_current]);
            else
                chosen=matches(strcmp(entryHashes(matches),expectedSHA));
            end
            assert(isscalar(chosen),'V3ReadDatasetPath_v3:AmbiguousVersion', ...
                'Exactly one explicit current entry or exact historical logical-path/SHA entry is required.');
            entryIndex=chosen;entry=index.entries(chosen);recordedSHA=hashText(entry.sha256,false);
            file=canonicalWithin(root,entry.read_path);indexed=true;
        end
        assert(strcmp(indexHash,physicalSHA(indexFile)),'V3ReadDatasetPath_v3:IndexRace','The read index changed during resolution.');
    end
    assert(isfile(file),'V3ReadDatasetPath_v3:Missing','No dataset exists for logical path %s.',logical);
    actualSHA=physicalSHA(file);
    assert(isempty(recordedSHA)||strcmp(actualSHA,recordedSHA),'V3ReadDatasetPath_v3:Hash','Indexed dataset bytes differ from their registered SHA.');
    assert(isempty(expectedSHA)||strcmp(actualSHA,expectedSHA),'V3ReadDatasetPath_v3:Hash','Dataset bytes differ from the requested historical SHA.');
    if indexed,mode='indexed_read';else,mode='direct_current_read';end
    resolution=struct('requested_path',requested,'logical_path',logical,'study',study,'read_path',file, ...
        'mode',mode,'sha256',actualSHA,'expected_sha256',expectedSHA,'index_file',indexFile, ...
        'index_sha256',indexHash,'index_entry',entryIndex,'write_routing_prohibited',true);
end
function value=textScalar(value,label)
    assert((ischar(value)&&isrow(value))||(isstring(value)&&isscalar(value)), ...
        ['V3ReadDatasetPath_v3:',label],'Paths and hashes must be text scalars.');
    value=strrep(char(value),'\','/');
    assert(~isempty(value),['V3ReadDatasetPath_v3:',label],'A path cannot be empty.');
end
function rejectTraversal(value)
    parts=strsplit(strrep(value,'\','/'),'/');
    assert(~any(strcmp(parts,'..'))&&~any(strcmp(parts,'.')), ...
        'V3ReadDatasetPath_v3:Traversal','Dot path segments cannot identify scientific datasets.');
end
function path=canonicalWithin(root,path)
    rejectTraversal(path);
    if ~startsWith(path,'/'),path=fullfile(root,path);end
    path=char(java.io.File(path).getCanonicalPath());prefix=[root,filesep];
    assert(startsWith(path,prefix),'V3ReadDatasetPath_v3:OutsideRoot','Dataset and index paths must stay inside v3.');
end
function value=relativePath(root,path)
    path=canonicalWithin(root,path);value=strrep(path(numel(root)+2:end),'\','/');
end
function study=rawStudy(logical)
    parts=strsplit(logical,'/');
    studies={'P1_Single_Flight_Phase_Continua','P2_Double_Flight_Phase_Continua'};
    assert(numel(parts)==2&&ismember(parts{1},studies)&&endsWith(parts{2},'.mat') ...
        &&isempty(regexp(parts{2},'^C[0-9]+_','once')), ...
        'V3ReadDatasetPath_v3:LogicalScope','Only unprefixed top-level scientific P1/P2 raw MAT aliases belong to this reader.');
    study=parts{1};
end
function hash=hashText(hash,allowEmpty)
    assert(ischar(hash)||(isstring(hash)&&isscalar(hash)),'V3ReadDatasetPath_v3:Hash','SHA must be scalar text.');
    hash=lower(char(hash));
    assert((allowEmpty&&isempty(hash))||~isempty(regexp(hash,'^[a-f0-9]{64}$','once')), ...
        'V3ReadDatasetPath_v3:Hash','SHA must contain exactly 64 hexadecimal characters.');
end
function hash=physicalSHA(file)
    fid=fopen(file,'rb');assert(fid>=0,'V3ReadDatasetPath_v3:Read','Cannot read %s.',file);
    close=onCleanup(@()fclose(fid));digest=java.security.MessageDigest.getInstance('SHA-256');
    while ~feof(fid),digest.update(fread(fid,1048576,'*uint8'));end
    raw=typecast(digest.digest(),'uint8');hash=lower(reshape(dec2hex(raw,2).',1,[]));
end
