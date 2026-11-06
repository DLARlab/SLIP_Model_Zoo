function plan=PlanNamedCatalogMigration_v3(catalogPaths,proposals)
%PLANNAMEDCATALOGMIGRATION_V3 Read-only publication/MAT/link consistency plan.
% proposals contain target_file, staged_file, entry. Paths are v3-root
% relative. Original bytes are identified before any overwrite; this helper
% never edits evidence text, aliases, MAT files, or active catalogs.
    if ischar(catalogPaths)||isstring(catalogPaths),catalogPaths=cellstr(catalogPaths);end
    root=V3Root_v3();prior=struct([]);issues={};
    for k=1:numel(catalogPaths)
        catalogPath=inside(catalogPaths{k},root);catalog=jsondecode(fileread(catalogPath));
        item=struct('path',relative(catalogPath,root),'sha256',RoundSHA256_v3(catalogPath), ...
            'kind','catalog','aliases',{{}},'reported_hash_match',true);
        prior=append(prior,item);
        for j=1:numel(catalog.datasets)
            entry=catalog.datasets(j);path=char(entry.file);
            if isfield(entry,'file_scope')&&strcmp(entry.file_scope,'v3-root')
                path=fullfile(root,path);
            elseif ~startsWith(path,[root,filesep]),path=fullfile(fileparts(catalogPath),path);end
            path=inside(path,root);
            if ~isfile(path),issues{end+1}=sprintf('Missing original dataset %s',path);continue;end %#ok<AGROW>
            hash=RoundSHA256_v3(path);matches=true;
            if isfield(entry,'dataset_sha256'),matches=strcmp(hash,entry.dataset_sha256);end
            aliases={char(entry.file)};
            if isfield(entry,'dataset_key'),aliases{end+1}=char(entry.dataset_key);end
            item=struct('path',relative(path,root),'sha256',hash,'kind','dataset', ...
                'aliases',{aliases},'reported_hash_match',matches);
            prior=append(prior,item);
            if ~matches,issues{end+1}=sprintf('Original catalog hash differs from actual bytes: %s',path);end %#ok<AGROW>
        end
    end
    updates=struct([]);targets={};identities={};
    for k=1:numel(proposals)
        proposal=proposals(k);
        if ~all(isfield(proposal,{'target_file','staged_file','entry'}))
            error('PlanNamedCatalogMigration_v3:Proposal','Each proposal requires target_file, staged_file and entry.');
        end
        target=inside(proposal.target_file,root);entry=proposal.entry;
        required={'stable_dataset_id','continuum_id','abbreviation','physical_parameter','canonical_name_qualified'};
        if ~all(isfield(entry,required))
            issues{end+1}=sprintf('Proposal %d lacks stable identity/classification metadata.',k);continue %#ok<AGROW>
        end
        try
            parameter=CatalogPhysicalParameter_v3(entry);
        catch exception
            issues{end+1}=sprintf('Proposal %d has invalid full parameter metadata: %s',k,exception.message);continue %#ok<AGROW>
        end
        isReference=isfield(entry,'is_reference')&&isequal(entry.is_reference,true);
        if isReference
            if ~isfield(entry,'canonical_parent_file')||~isfield(entry,'canonical_parent_id')
                issues{end+1}=sprintf('Reference proposal %d lacks canonical C0 parent identity/path.',k);continue %#ok<AGROW>
            end
            staged=inside(entry.canonical_parent_file,root);
            action='catalog_reference_only';hash='';
            if isfile(staged),hash=RoundSHA256_v3(staged);end
        else
            staged=inside(proposal.staged_file,root);action='publish_staged_mat';hash='';
            if ~isfile(staged),issues{end+1}=sprintf('Missing staged MAT %s',staged); %#ok<AGROW>
            else
                hash=RoundSHA256_v3(staged);variables=whos('-file',staged);
                if ~any(ismember({variables.name},{'solution','solutions','orbit','branch'}))
                    issues{end+1}=sprintf('Staged MAT is not loadable by the existing GUI: %s',staged); %#ok<AGROW>
                end
                if any(strcmp({variables.name},'summary'))
                    metadata=load(staged,'summary');summary=metadata.summary;
                    if ~isstruct(summary)||~isscalar(summary)||~all(isfield(summary,{'stable_dataset_id','physical_parameter'})) ...
                            ||~strcmp(summary.stable_dataset_id,entry.stable_dataset_id) ...
                            ||~isequal(summary.physical_parameter(:),parameter)
                        issues{end+1}=sprintf('Staged MAT full parameter/stable identity differs from catalog entry: %s',staged); %#ok<AGROW>
                    end
                else
                    issues{end+1}=sprintf('Staged MAT lacks identity/full-parameter summary: %s',staged); %#ok<AGROW>
                end
            end
            if ~entry.canonical_name_qualified
                issues{end+1}=sprintf('Canonical proposal %d has a provisional name; retain it as diagnostic evidence.',k); %#ok<AGROW>
            end
            if strcmp(entry.abbreviation,'PIP')&&~strcmp(entry.continuum_id,'C0')
                issues{end+1}=sprintf('PIP proposal %d must have canonical C0 identity.',k); %#ok<AGROW>
            end
            targets{end+1}=target;identities{end+1}=entry.stable_dataset_id; %#ok<AGROW>
        end
        old=prior(strcmp({prior.path},relative(target,root))&strcmp({prior.kind},'dataset'));
        oldHashes={old.sha256};
        updates=append(updates,struct('target_file',relative(target,root), ...
            'staged_file',relative(staged,root),'new_sha256',hash,'action',action, ...
            'stable_dataset_id',entry.stable_dataset_id,'prior_sha256',{oldHashes}, ...
            'metadata_rewrite_changes_hash',~isempty(oldHashes)&&~all(strcmp(oldHashes,hash)), ...
            'prior_bytes_must_be_preserved',~isempty(oldHashes),'entry',entry));
    end
    if numel(unique(targets))~=numel(targets),issues{end+1}='Canonical target filename collision; preserve distinct branch identities with explicit disambiguating filenames.';end
    if numel(unique(identities))~=numel(identities),issues{end+1}='Duplicate canonical dataset identity; use references rather than copied canonical parents.';end
    for k=1:numel(updates)
        if ~strcmp(updates(k).action,'catalog_reference_only'),continue;end
        parent=updates(k).entry;path=inside(parent.canonical_parent_file,root);
        stagedParent=find(strcmp({updates.target_file},relative(path,root)) ...
            &strcmp({updates.stable_dataset_id},parent.canonical_parent_id) ...
            &strcmp({updates.action},'publish_staged_mat'));
        if ~isfile(path)&&isempty(stagedParent)
            issues{end+1}=sprintf('Unresolved C0 parent reference: %s',parent.canonical_parent_file); %#ok<AGROW>
        elseif ~isempty(stagedParent)
            actual=updates(stagedParent(1)).entry;
            if ~strcmp(actual.continuum_id,'C0')||~strcmp(actual.abbreviation,'PIP') ...
                    ||~isequal(CatalogPhysicalParameter_v3(actual),CatalogPhysicalParameter_v3(parent))
                issues{end+1}=sprintf('C0 parent reference has inconsistent full parameters/role: %s',parent.canonical_parent_file); %#ok<AGROW>
            end
        else
            metadata=load(path,'summary');
            if ~isfield(metadata,'summary')||~all(isfield(metadata.summary,{'stable_dataset_id','physical_parameter','continuum_id','abbreviation'})) ...
                    ||~strcmp(metadata.summary.stable_dataset_id,parent.canonical_parent_id) ...
                    ||~strcmp(metadata.summary.continuum_id,'C0')||~strcmp(metadata.summary.abbreviation,'PIP') ...
                    ||~isequal(metadata.summary.physical_parameter(:),CatalogPhysicalParameter_v3(parent))
                issues{end+1}=sprintf('Existing C0 parent file does not match its reference identity: %s',parent.canonical_parent_file); %#ok<AGROW>
            end
        end
    end
    plan=struct('schema_version','named-catalog-migration-plan-v3.1','valid',isempty(issues), ...
        'issues',{issues},'original_bytes',prior,'updates',updates,'writes_performed',0, ...
        'required_publication_order',{{'Preserve original dataset/catalog bytes by path plus actual hash.', ...
        'Verify staged MAT classifications, sampling audits, parameters and separate components.', ...
        'Publish canonical C0 parent once and resolve C1/C2 parent references.', ...
        'Publish MAT files, then atomically replace validated catalogs and alias/evidence-link manifest.', ...
        'Verify GUI load/selection/plotting and every referenced file/hash.'}}, ...
        'historical_evidence_text_rewritten',false,'connectivity_claimed',false);
end
function path=inside(path,root)
    path=char(path);if ~startsWith(path,filesep),path=fullfile(root,path);end
    path=char(java.io.File(path).getCanonicalPath());
    if ~startsWith(path,[root,filesep]),error('PlanNamedCatalogMigration_v3:Scope','Migration paths must remain under SLIP_Quadruped_v3.');end
end
function path=relative(path,root),path=strrep(path(numel(root)+2:end),filesep,'/');end
function result=append(result,item)
    if isempty(result),result=item;else,result(end+1)=item;end
end
