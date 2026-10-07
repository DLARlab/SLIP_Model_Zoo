function inventory=AppendCriticalRoundSources_v3()
%APPENDCRITICALROUNDSOURCES_V3 Register exact saved critical neighborhoods.
% Complete byte-identical snapshots and precise nested variable paths remain
% authoritative. Extracted arrays are exact saved data, not solved v3 orbits.
    v3=V3Root_v3(mfilename('fullpath'));folder=fullfile(v3,'Research_v3','next_round');
    file=fullfile(folder,'source_inventory.mat');loaded=load(V3Path_v3(file),'inventory');inventory=loaded.inventory;
    if isfield(inventory,'critical_catalog_registered'),return;end
    catalogFile=fullfile(folder,'theory','critical_branch_catalog.mat');
    if ~isfile(V3Path_v3(catalogFile)),return;end
    loaded=load(V3Path_v3(catalogFile),'catalog');catalog=loaded.catalog;indices=[];aliases=struct([]);
    for k=1:numel(catalog.entries)
        entry=catalog.entries(k);raw=entry.raw;
        if size(raw,1)~=29,error('AppendCriticalRoundSources_v3:Rows','Critical predictor must contain29 rows.');end
        % Keep provenance aliases, but do not spend correction budget twice
        % on an exactly duplicated complete numeric array.
        duplicate=0;
        for j=1:k-1
            if isequaln(raw,catalog.entries(j).raw),duplicate=j;break;end
        end
        if duplicate>0
            alias=struct('catalog_index',k,'identical_array_catalog_index',duplicate,'source',entry.source,'variable',entry.variable);
            if isempty(aliases),aliases=alias;else,aliases(end+1)=alias;end %#ok<AGROW>
            continue
        end
        n=size(raw,2);x=zeros(14,n);x(2:14,:)=LegacyStateAdapter_v3.toV3Unknown(raw(1:13,:));
        q=false(4,n);p=zeros(10,n);E=nan(1,n);s=QuadrupedSchema_v3.shared();
        for column=1:n
            p(:,column)=LegacyParameterAdapter_v3.toV3(raw(23:29,column),'v2-exact');
            q(:,column)=LegacyModeAdapter_v3.toV3(raw([15,17,19,21],column)<raw([14,16,18,20],column));
            ex=s.expandParameters(p(:,column));theta=x(5,column)+x(s.Leg.AngleIndices,column);
            height=x(3,column)+ex.s.*sin(x(5,column));compression=zeros(4,1);
            compression(q(:,column))=ex.l_0(q(:,column))-height(q(:,column))./cos(theta(q(:,column)));
            E(column)=x(3,column)+.5*(x(2,column)^2+x(4,column)^2)+.5*ex.j_pitch*x(6,column)^2+sum(.5*ex.k_l.*compression.^2);
        end
        if contains(entry.source.source_path,'reference_experiments'),study='P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits';
        else,study='P2_All_Common_Quadrupedal_Gaits';end
        source=struct('study',study,'source_path',entry.source.source_path,'fixture_path',entry.source.fixture_path, ...
            'sha256',entry.source.sha256,'bytes',entry.source.bytes,'source_head',entry.source.source_commit, ...
            'policy','v2-exact','label_is_source_only',true);
        variable=struct('variable',entry.variable,'rows',29,'columns',n,'energy',E, ...
            'initial_horizontal_speed',x(2,:),'period_predictor',raw(22,:),'pitch',x(5,:), ...
            'mapped_initial_state',x,'mapped_initial_mode',q,'mapped_physical_parameters',p, ...
            'parameter_target_columns',find(max(abs(p-[10;10;20;20;1;1;0;0;2;.5]),[],1)<1e-12), ...
            'coordinate_roles','exact saved29-row data or22-state/event/period+own7-physicalparameters', ...
            'raw_array',raw,'construction',entry.construction,'family_hint',entry.family_hint);
        record=struct('source',source,'fixture_sha256',entry.source.sha256,'source_sha256',entry.source.sha256,'variables',variable);
        inventory.records(end+1)=record;indices(end+1)=numel(inventory.records); %#ok<AGROW>
        inventory.columns_inventoried=inventory.columns_inventoried+n;
    end
    inventory.critical_catalog_registered=true;inventory.critical_catalog_file='Research_v3/next_round/theory/critical_branch_catalog.mat';
    inventory.critical_record_indices=indices;inventory.critical_provenance_aliases=aliases;
    RoundSave_v3(file,struct('inventory',inventory));
    registration=struct('schema_version','critical-source-supplement-registration-v3-1', ...
        'registered_utc',char(datetime('now','TimeZone','UTC')),'source_catalog',inventory.critical_catalog_file, ...
        'source_catalog_sha256',RoundSHA256_v3(catalogFile),'new_inventory_indices',indices, ...
        'provenance_aliases',aliases,'domain_changed',false,'role','Critical predictors and complete sources; no numerical acceptance or ancestry from import.');
    RoundJSON_v3(fullfile(folder,'critical_source_supplement_registration.json'),registration);
end
