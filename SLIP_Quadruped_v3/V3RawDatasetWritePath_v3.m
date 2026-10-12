function [file,publication]=V3RawDatasetWritePath_v3(study,basename,epoch)
%V3RAWDATASETWRITEPATH_V3 Plan a fresh raw export, independent of read indices.
% This function creates no directory, dataset or index. A publisher may later
% register the completed artifact under its logical alias at a stopped boundary.
    root=fileparts(mfilename('fullpath'));
    study=scalarText(study);basename=scalarText(basename);epoch=scalarText(epoch);
    assert(ismember(study,{'P1_Single_Flight_Phase_Continua','P2_Double_Flight_Phase_Continua'}), ...
        'V3RawDatasetWritePath_v3:Study','A raw export must name the exact P1 or P2 study.');
    assert(~isempty(regexp(basename,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')) ...
        &&isempty(regexp(basename,'^C[0-9]+_','once')), ...
        'V3RawDatasetWritePath_v3:Basename','A raw export needs an unprefixed safe basename without an extension.');
    assert(~isempty(regexp(epoch,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')), ...
        'V3RawDatasetWritePath_v3:Epoch','An export epoch must be a safe explicit version identifier.');
    logical=fullfile(study,[basename,'.mat']);
    relative=fullfile(study,'Bifurcation_Audits','Raw_Dataset_Exports',epoch,[basename,'.mat']);
    file=V3OutputPath_v3(fullfile(root,relative));
    assert(~isfile(file),'V3RawDatasetWritePath_v3:Overwrite','A versioned raw export already exists: %s.',file);
    publication=struct('logical_path',strrep(logical,'\','/'),'write_path',file, ...
        'relative_write_path',strrep(relative,'\','/'),'epoch',epoch, ...
        'read_resolver_used',false,'live_index_updated',false,'historical_bytes_overwritten',false, ...
        'index_registration_required_after_completed_publication',true);
end
function value=scalarText(value)
    assert((ischar(value)&&isrow(value))||(isstring(value)&&isscalar(value)), ...
        'V3RawDatasetWritePath_v3:Text','Write path components must be scalar text.');
    value=char(value);assert(~isempty(value),'V3RawDatasetWritePath_v3:Text','Write path components cannot be empty.');
end
