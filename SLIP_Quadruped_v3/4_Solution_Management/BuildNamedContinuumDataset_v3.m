function bundle=BuildNamedContinuumDataset_v3(groups)
%BUILDNAMEDCONTINUUMDATASET_V3 Combine storage groups without joining curves.
% C1 denotes the user's P1 continuum; C2 denotes the user's P2 continuum.
% Group membership is an organizational convention, not connectivity evidence.
    assert(~isempty(groups)&&numel(unique([groups.study]))==1);
    study=groups(1).study;assert(ismember(study,[1,2]));abbr=groups(1).abbreviation;
    assert(all(strcmp({groups.abbreviation},abbr))&&numel(unique({groups.key}))==numel(groups));
    region='';if isfield(groups,'branch_designation'),region=groups(1).branch_designation;assert(all(strcmp({groups.branch_designation},region)));end
    assert(isempty(region)||(strcmp(abbr,'F2')&&study==2&&ismember(region,{'L','H'})));
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
            if isempty(records),records=record;else,records(end+1)=orderfields(record,records(1));end %#ok<AGROW>
        end
        for j=1:numel(group.components)
            component=group.components(j);assert(component.index==j);
            assert(all(component.record_indices>=1&component.record_indices<=n));
            component.index=firstComponent+j;component.record_indices=component.record_indices+firstRecord;
            component.source_group_key=group.key;
            if isempty(components),components=component;else,components(end+1)=orderfields(component,components(1));end %#ok<AGROW>
        end
        descriptor=struct('key',group.key,'kind',group.kind,'display_name',group.display_name, ...
            'dataset_type',group.dataset_type,'note',group.note,'record_indices',firstRecord+(1:n), ...
            'component_indices',firstComponent+(1:numel(group.components)), ...
            'connections_to_other_groups_claimed',false,'branch_designation',region);
        if isempty(descriptors),descriptors=descriptor;else,descriptors(end+1)=descriptor;end %#ok<AGROW>
        solutions=[solutions,reshape(group.solutions,1,[])]; %#ok<AGROW>
    end
    assert(numel(parameter)==10&&parameter(1)==parameter(2)&&parameter(3)==parameter(4));
    id=sprintf('C%d',study);key=sprintf('%s|%s|%s',id,abbr,jsonencode(parameter(:).'));
    filename=sprintf('%s_%s_%s_%s_%s.mat',id,abbr,token(parameter(1)),token(parameter(3)),token(parameter(9)));
    if ~isempty(region),key=[key,'|region:',region];filename=[erase(filename,'.mat'),'_',region,'.mat'];end
    ordered=false;
    for j=1:numel(components)
        kind=components(j).record_kind;
        ordered=ordered||(numel(components(j).record_indices)>1&&(startsWith(kind,'ordered_')||strcmp(kind,'accepted_local_bridge')));
    end
    type='accepted_orbit_samples';if ordered,type='saved_continuation_components_and_samples';end
    bundle=struct('continuum_id',id,'continuum_number',study,'dataset_key',key,'filename',filename, ...
        'abbreviation',abbr,'physical_parameter',parameter,'solutions',{solutions},'records',records, ...
        'components',components,'source_groups',descriptors,'dataset_type',type, ...
        'note','C1/P1 and C2/P2 identify the user continuum convention. Source groups, signed samples, marked phases and ordered components retain separate provenance; a common C prefix creates no connection, family, distinct-cycle or bifurcation claim.');
    bundle.dataset_role='native_admitted_gait_dataset';
    bundle.branch_designation=region;
    if strcmp(abbr,'PIP'),bundle.dataset_role='shared_PIP_parent_reference';end
end
function value=token(number)
    validateattributes(number,{'numeric'},{'scalar','real','finite','nonnegative'});
    value=strrep(sprintf('%.12g',number),'.','p');value=strrep(value,'+','');
end
