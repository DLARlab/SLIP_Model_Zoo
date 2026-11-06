function reference=SharedPIPCatalogReference_v3(parent,study)
%SHAREDPIPCATALOGREFERENCE_V3 Expose the same C0 parent without copying it.
% The referenced file path is relative to the v3 root and is loaded directly.
    required={'file','stable_dataset_id','continuum_id','abbreviation','physical_parameter'};
    if ~isstruct(parent)||~isscalar(parent)||~all(isfield(parent,required)) ...
            ||~strcmp(parent.continuum_id,'C0')||~strcmp(parent.abbreviation,'PIP') ...
            ||~ismember(study,[1,2])
        error('SharedPIPCatalogReference_v3:Parent','One identified canonical C0 PIP parent and logical study 1 or 2 are required.');
    end
    reference=parent;reference.continuum_id=sprintf('C%d',study);reference.continuum_number=study;
    reference.dataset_role='shared_PIP_parent_reference';reference.is_reference=true;
    reference.canonical_parent_id=parent.stable_dataset_id;reference.canonical_parent_file=parent.file;
    reference.content_continuum_id='C0';reference.content_dataset_key=parent.stable_dataset_id;
    reference.reference_id=sprintf('C%d|parent-reference:%s',study,parent.stable_dataset_id);
    reference.file_scope='v3-root';
    reference.canonical_parent_copy_created=false;
    reference.note='Logical catalog reference to the identical canonical C0 PIP dataset; no additional orbit, two-flight claim, or attachment edge.';
end
