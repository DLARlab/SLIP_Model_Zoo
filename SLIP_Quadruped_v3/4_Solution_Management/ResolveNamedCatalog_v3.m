function [matches,resolution]=ResolveNamedCatalog_v3(catalog,query)
%RESOLVENAMEDCATALOG_V3 Resolve stable keys, names and transparent aliases.
% C2_B2 is intentionally a family query that may return several branches.
% References are entries; this read-only helper does not duplicate parents.
    if ischar(catalog)||isstring(catalog),catalog=jsondecode(fileread(char(catalog)));end
    if ~isstruct(catalog)||~isscalar(catalog)||~isfield(catalog,'datasets')
        error('ResolveNamedCatalog_v3:Catalog','Expected a native catalog with dataset entries.');
    end
    query=char(query);entries=catalog.datasets;keep=false(1,numel(entries));
    for k=1:numel(entries)
        entry=entries(k);names={};
        for field={'stable_dataset_id','dataset_key','file','abbreviation','canonical_name'}
            if isfield(entry,field{1}),names{end+1}=char(entry.(field{1}));end %#ok<AGROW>
        end
        if isfield(entry,'aliases'),names=[names,reshape(cellstr(string(entry.aliases)),1,[])];end %#ok<AGROW>
        keep(k)=any(strcmp(names,query));
        if strcmp(query,'C2_B2')&&isfield(entry,'abbreviation')
            keep(k)=isfield(entry,'continuum_id')&&strcmp(entry.continuum_id,'C2') ...
                &&~isempty(regexp(char(entry.abbreviation),'^B[GEMU]2$','once'));
        end
    end
    matches=entries(keep);
    resolution=struct('query',query,'match_count',sum(keep),'is_unique',sum(keep)==1, ...
        'family_alias',strcmp(query,'C2_B2'),'all_matching_branches_returned',true, ...
        'connectivity_implied',false,'canonical_parent_copies_created',0);
end
