function [file,resolution]=V3SavedReadPath_v3(inputPath,expectedSHA,indexFile)
%V3SAVEDREADPATH_V3 Resolve saved inputs; never use this for output paths.
% Only direct unprefixed P1/P2 raw MAT aliases use the versioned raw index.
% Task, audit, fixture and canonical paths retain ordinary V3Path semantics.
    root=fileparts(mfilename('fullpath'));
    assert((ischar(inputPath)&&isrow(inputPath))||(isstring(inputPath)&&isscalar(inputPath)), ...
        'V3SavedReadPath_v3:Path','A saved input path must be scalar text.');
    requested=strrep(char(inputPath),'\','/');
    assert(~isempty(requested),'V3SavedReadPath_v3:Path','A saved input path cannot be empty.');
    assert(~any(ismember(strsplit(requested,'/'),{'.','..'})), ...
        'V3SavedReadPath_v3:Traversal','Dot path segments cannot identify saved inputs.');
    if nargin<2,expectedSHA='';end
    assert(ischar(expectedSHA)||(isstring(expectedSHA)&&isscalar(expectedSHA)), ...
        'V3SavedReadPath_v3:Hash','An expected SHA must be scalar text.');
    expectedSHA=lower(char(expectedSHA));
    assert(isempty(expectedSHA)||~isempty(regexp(expectedSHA,'^[a-f0-9]{64}$','once')), ...
        'V3SavedReadPath_v3:Hash','An expected SHA must contain 64 hexadecimal characters.');
    file=char(V3Path_v3(requested));
    if ~java.io.File(file).isAbsolute(),file=fullfile(root,file);end
    prefix=[strrep(root,'\','/'),'/'];normalized=strrep(file,'\','/');logical='';
    if startsWith(normalized,prefix),logical=normalized(numel(prefix)+1:end);end
    raw=~isempty(regexp(logical, ...
        '^(P1_Single_Flight_Phase_Continua|P2_Double_Flight_Phase_Continua)/(?!C[0-9]+_)[^/]+\.mat$','once'));
    if raw
        if nargin<3,[file,resolution]=V3ReadDatasetPath_v3(file,expectedSHA);
        else,[file,resolution]=V3ReadDatasetPath_v3(file,expectedSHA,indexFile);end
        return
    end
    assert(isfile(file),'V3SavedReadPath_v3:Missing','Saved input is missing: %s.',requested);
    actualSHA=RoundSHA256_v3(file);
    assert(isempty(expectedSHA)||strcmp(actualSHA,expectedSHA), ...
        'V3SavedReadPath_v3:Hash','Saved input differs from its recorded SHA: %s.',requested);
    resolution=struct('requested_path',requested,'logical_path',logical,'read_path',file, ...
        'mode','ordinary_saved_read','sha256',actualSHA,'expected_sha256',expectedSHA, ...
        'raw_index_used',false,'write_routing_prohibited',true);
end
