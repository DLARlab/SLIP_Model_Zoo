function name=QualifiedPublicationName_v3(data)
%QUALIFIEDPUBLICATIONNAME_V3 Name original admitted classification evidence.
% Geometry G/E is native measured gathered/extended suspension geometry.
% F2 L/H is a separately registered source region, never inferred from energy.
    gait=data.report.classification;trial=data.trial;label=char(gait.label);flights=gait.flight_count;
    name=struct('qualified',true,'abbreviation',char(gait.abbreviation),'branch_designation','', ...
        'reason','Original native classification retained.','native_classification',gait,'registered_naming_provenance',struct());
    if ismember(label,{'PK','PIP'}),name.abbreviation=label;return;end
    if strcmp(label,'unclassified'),name.abbreviation=sprintf('UBL%d',flights);return;end
    if flights==1&&ismember(label,{'BD','HB_front','HB_hind','GP'})
        geometry='';if isfield(gait,'suspension_geometry'),geometry=char(gait.suspension_geometry.description);end
        if ~strcmp(char(gait.status),'classified')||~ismember(geometry,{'gathered','extended'})
            name.qualified=false;name.reason='Original one-flight geometry/classification is mixed or borderline; G/E is not assigned.';return
        end
        base={'B','F','H','G'};labels={'BD','HB_front','HB_hind','GP'};suffix='G';if strcmp(geometry,'extended'),suffix='E';end
        name.abbreviation=[base{strcmp(labels,label)},suffix];name.reason='Actual native one-flight base class and gathered/extended geometry.';return
    end
    if flights==2&&strcmp(name.abbreviation,'F2')
        region='';if isfield(trial,'publication_branch_suffix'),region=char(trial.publication_branch_suffix);end
        provenance=struct();if isfield(trial,'publication_naming_provenance'),provenance=trial.publication_naming_provenance;end
        required={'registered_before_maps','method_registration','method_sha256','branch_region'};
        if ~strcmp(char(gait.status),'classified')||~ismember(region,{'L','H'})||~isstruct(provenance)||~isscalar(provenance)||~all(isfield(provenance,required))
            name.qualified=false;name.reason='F2 region L/H lacks its explicit original registered naming provenance.';return
        end
        path=V3Path_v3(provenance.method_registration);
        root=V3Root_v3(mfilename('fullpath'));path=char(java.io.File(path).getCanonicalPath());
        if ~isequal(provenance.registered_before_maps,true)||~strcmp(char(provenance.branch_region),region)||~isfile(path) ...
                ||~startsWith(path,[root,filesep])||~strcmp(RoundSHA256_v3(path),provenance.method_sha256)
            name.qualified=false;name.reason='F2 region registration identity or pre-map binding does not match.';return
        end
        saved=load(path,'method');
        if ~isfield(saved,'method')||~isfield(saved.method,'branch_region')||~strcmp(char(saved.method.branch_region),region)
            name.qualified=false;name.reason='Actual saved method does not declare the same F2 branch region.';return
        end
        name.branch_designation=region;name.registered_naming_provenance=provenance;
        name.reason='Actual native two-flight F2 with separately registered source-region designation.';
    end
end
