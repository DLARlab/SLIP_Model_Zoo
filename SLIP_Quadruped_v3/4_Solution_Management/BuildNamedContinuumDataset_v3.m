function bundle=BuildNamedContinuumDataset_v3(groups)
%BUILDNAMEDCONTINUUMDATASET_V3 Combine storage groups without joining curves.
% C0 is the canonical PIP parent; C1/C2 denote one/two physical flights.
% Group membership is an organizational convention, not connectivity evidence.
    assert(~isempty(groups)&&numel(unique([groups.study]))==1);
    study=groups(1).study;assert(ismember(study,[1,2]));abbr=groups(1).abbreviation;
    assert(all(strcmp({groups.abbreviation},abbr))&&numel(unique({groups.key}))==numel(groups));
    region='';if isfield(groups,'branch_designation'),region=groups(1).branch_designation;assert(all(strcmp({groups.branch_designation},region)));end
    % Historical region provenance remains separate from the new compact
    % reference-posture name; it never manufactures a gait or connectivity.
    solutions={};records=struct([]);components=struct([]);descriptors=struct([]);parameter=[];
    for g=1:numel(groups)
        group=groups(g);n=numel(group.solutions);assert(n==numel(group.records)&&n>0);
        assert(~isempty(group.components)&&isequal(sort([group.components.record_indices]),1:n), ...
            'BuildNamedContinuumDataset_v3:ComponentPartition','Every stored record must belong to exactly one source component.');
        assert(all([group.records.component_index]>=1&[group.records.component_index]<=numel(group.components)));
        for j=1:numel(group.components)
            assert(all([group.records(group.components(j).record_indices).component_index]==j), ...
                'BuildNamedContinuumDataset_v3:ComponentOwnership','Record ownership must match its original component.');
        end
        firstRecord=numel(solutions);firstComponent=numel(components);
        for j=1:n
            orbit=group.solutions{j};p=orbit.parameter(:);
            if isempty(parameter),parameter=p;end
            assert(isequal(p,parameter),'BuildNamedContinuumDataset_v3:Parameters','A named gait dataset must retain one exact physical parameter vector.');
            record=group.records(j);assert(record.solution_index==j);
            record.solution_index=firstRecord+j;record.component_index=record.component_index+firstComponent;
            record.source_group_key=group.key;
            if ~isfield(record,'stable_record_id')||isempty(record.stable_record_id)
                record.stable_record_id=sprintf('%s|sha:%s|record:%d', ...
                    record.source_path,record.source_sha256,record.source_record_index);
            end
            % Keep source classification and admission fields unchanged.
            % New interpretation is explicitly versioned alongside them.
            record.current_classification=GaitIdentification_v3(orbit);
            if isempty(records),records=record;else,records(end+1)=orderfields(record,records(1));end %#ok<AGROW>
        end
        for j=1:numel(group.components)
            component=group.components(j);assert(component.index==j);
            assert(all(component.record_indices>=1&component.record_indices<=n));
            component.index=firstComponent+j;component.record_indices=component.record_indices+firstRecord;
            component.source_group_key=group.key;
            if ~isfield(component,'component_id')||isempty(component.component_id)
                component.component_id=sprintf('%s|source:%s|sha:%s|component:%d', ...
                    group.key,component.source_path,component.source_sha256,j);
            end
            if ~isfield(component,'parent_component_id')||isempty(component.parent_component_id)
                component.parent_component_id=component.component_id;
            end
            if ~isfield(component,'naming_audit'),component.naming_audit=struct();end
            if isempty(components),components=component;else,components(end+1)=orderfields(component,components(1));end %#ok<AGROW>
        end
        descriptor=struct('key',group.key,'kind',group.kind,'display_name',group.display_name, ...
            'dataset_type',group.dataset_type,'note',group.note,'record_indices',firstRecord+(1:n), ...
            'component_indices',firstComponent+(1:numel(group.components)), ...
            'connections_to_other_groups_claimed',false,'branch_designation',region);
        if isempty(descriptors),descriptors=descriptor;else,descriptors(end+1)=descriptor;end %#ok<AGROW>
        solutions=[solutions,reshape(group.solutions,1,[])]; %#ok<AGROW>
    end
    assert(numel(parameter)==10);
    stableBranch=strjoin(sort({groups.key}),'||');
    if strcmp(abbr,'PIP')
        parents=cell(1,numel(groups));
        for j=1:numel(groups)
            if isfield(groups(j),'canonical_parent_identity'),parents{j}=char(groups(j).canonical_parent_identity);
            else,parents{j}=groups(j).key;end
        end
        assert(numel(unique(parents))==1,'BuildNamedContinuumDataset_v3:PIPIdentity', ...
            'Distinct PIP parent branch identities require separate canonical C0 datasets; source names cannot establish a shared parent.');
        stableBranch=parents{1};
    end
    currentLabel=~isempty(regexp(abbr,'^(PIP|PK|[BHFG][GEMU][0-9]+)$','once'));
    if currentLabel
        identity=NamedDatasetIdentity_v3(study,abbr,parameter,stableBranch);
        id=identity.continuum_id;study=identity.continuum_number;key=identity.dataset_key;filename=identity.filename;
    else
        % Read-compatible historical staging is diagnostic, never a current
        % canonical publication or a mechanical old/new letter exchange.
        id=sprintf('C%d',study);key=sprintf('%s|historical:%s|%s',id,abbr,jsonencode(parameter(:).'));
        values=arrayfun(@token,parameter(:).','UniformOutput',false);
        filename=sprintf('%s_%s_p10_%s.mat',id,abbr,strjoin(values,'_'));
        identity=struct('stable_dataset_id',sprintf('%s|p10:%s|branch:%s',id,jsonencode(parameter(:).'),stableBranch));
    end
    ordered=false;
    for j=1:numel(components)
        kind=components(j).record_kind;
        ordered=ordered||(numel(components(j).record_indices)>1&&(startsWith(kind,'ordered_')||strcmp(kind,'accepted_local_bridge')));
    end
    type='accepted_orbit_samples';if ordered,type='saved_continuation_components_and_samples';end
    bundle=struct('continuum_id',id,'continuum_number',study,'dataset_key',key,'filename',filename, ...
        'abbreviation',abbr,'physical_parameter',parameter,'solutions',{solutions},'records',records, ...
        'components',components,'source_groups',descriptors,'dataset_type',type, ...
        'note','C0 identifies one canonical PIP parent identity; C1/C2 place one/two physical flights. Source groups, signed samples, marked phases and ordered components retain separate provenance; a common C prefix creates no connection, distinct-cycle or bifurcation claim.');
    bundle.dataset_role='native_admitted_gait_dataset';
    bundle.branch_designation=region;
    bundle.stable_dataset_id=identity.stable_dataset_id;
    bundle.stable_branch_identity=stableBranch;
    bundle.historical_aliases={groups.key};
    bundle.canonical_name_qualified=false;bundle.naming_status='provisional_unsampled';
    if strcmp(abbr,'PIP')
        bundle.dataset_role='canonical_PIP_parent';
        valid=arrayfun(@(r)strcmp(char(r.current_classification.validated_gait_type),'PIP') ...
            &&r.current_classification.canonical_label_qualified,records);
        bundle.canonical_name_qualified=all(valid);bundle.naming_status='C0_PIP_explicit_exception';
    elseif currentLabel
        qualified=true;
        for j=1:numel(components)
            audit=components(j).naming_audit;
            qualified=qualified&&isstruct(audit)&&isscalar(audit)&&isfield(audit,'canonical_name_qualified') ...
                &&isequal(audit.canonical_name_qualified,true)&&isfield(audit,'mode')&&strcmp(audit.mode,abbr);
        end
        bundle.canonical_name_qualified=qualified;
        if qualified,bundle.naming_status='qualified_twenty_speed_modal_name';end
    end
end
function value=token(number)
    validateattributes(number,{'numeric'},{'scalar','real'});
    value=strrep(sprintf('%.17g',number),'.','p');value=strrep(value,'+','');value=strrep(value,'-','m');
end
