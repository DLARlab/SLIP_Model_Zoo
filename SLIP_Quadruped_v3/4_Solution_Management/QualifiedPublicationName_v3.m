function name=QualifiedPublicationName_v3(data)
%QUALIFIEDPUBLICATIONNAME_V3 Point name from the versioned native contract.
% This is a point qualification, not a modal branch naming or admission.
% Legacy letters and aggregate spread are preserved as historical evidence.
    gait=data.report.classification;
    original='';if isfield(gait,'abbreviation'),original=char(gait.abbreviation);end
    name=struct('qualified',false,'abbreviation',original,'branch_designation','', ...
        'reason','Recompute the current classification from the admitted native cycle.', ...
        'native_classification',gait,'registered_naming_provenance',struct(), ...
        'contract_version','','canonical_continuum_id','','family_alias','', ...
        'is_point_label',true,'is_sampled_branch_name',false);
    fields={'contract_version','validated_gait_type','canonical_point_label', ...
        'canonical_label_qualified','primitive_flight_count','flight_count_certain'};
    [~,currentContract]=GaitSemanticTable_v3();
    if ~all(isfield(gait,fields))||~strcmp(gait.contract_version,currentContract),return;end
    name.contract_version=gait.contract_version;
    name.abbreviation=char(gait.canonical_point_label);
    name.qualified=isequal(gait.canonical_label_qualified,true);
    base=char(gait.validated_gait_type);count=gait.primitive_flight_count;
    if strcmp(base,'PIP')
        name.canonical_continuum_id='C0';
    elseif gait.flight_count_certain&&ismember(count,[1,2])
        name.canonical_continuum_id=sprintf('C%d',count);
    end
    if strcmp(base,'B')&&gait.flight_count_certain&&count==2,name.family_alias='C2_B2';end
    if name.qualified
        name.reason='Validated versioned point type, primitive physical flight count and reference-flight posture; branch sampling remains separate.';
    else
        name.reason='Point classification is unresolved, excluded, mixed, near an angle boundary, or has an uncertain primitive flight count; retained as a diagnostic.';
    end
    if isfield(data,'trial')&&isfield(data.trial,'publication_naming_provenance')
        name.registered_naming_provenance=data.trial.publication_naming_provenance;
    end
end
