function [orbit,report,point,view]=LoadC1WorkingSolutionCore29_v3(file,index,expectedSHA)
%LOADC1WORKINGSOLUTIONCORE29_V3 Explicit necessary-data working representation.
% The unchanged solution_core29 retains its original full-v2 five-times target.
% This distinct four-variable format permits an explicitly declared byte ceiling
% while preserving every strict core/schema/graph/policy/NativeID/method check.
% expectedSHA is mandatory; this reader does not make fresh admission claims.
% Saved qualification and classifications remain historical evidence.
    assert(nargin==3,'C1WorkingCore29:ExpectedSHA','Bind the complete working file by explicit SHA256.');
    file=literalPath(file);externalBinding=true;before=RoundSHA256_v3(file);
    if externalBinding,validSHA(expectedSHA);assert(strcmp(before,expectedSHA),'C1Core29:SourceSHA','The declared core bytes changed.');end
    names=whos('-file',file);assert(isequal(sort({names.name}), ...
        {'core_digest','solution_core29','working_storage','working_storage_digest'}), ...
        'C1WorkingCore29:Variables','Require the distinct declared four-variable working format.');
    data=load(file,'solution_core29','core_digest','working_storage','working_storage_digest');c=data.solution_core29;
    validateCore(c,data.core_digest);bytes=dir(file);
    working=validateWorkingStorage(data.working_storage,data.working_storage_digest,c,data.core_digest,bytes);
    validateattributes(index,{'double'},{'real','scalar','finite','integer','>=',1,'<=',c.point_count});
    verifyMethods(c.runtime_methods,c.runtime_environment);
    [orbit,report]=reconstruct(c,index);report.core29_view.external_binding_checked=externalBinding;report.core29_view.observed_file_sha256=before;
    report.core29_view.working_storage=working;
    point=struct('index',index,'native_id',c.native_ids{index},'metadata',c.point_metadata{index}, ...
        'context',c.contexts{index},'recorded_policy_evidence',c.policies{index}, ...
        'historical_source_projection_digest',c.source_projection_digests{index}, ...
        'requires_fresh_replay',true,'fresh_admission_claimed',false,'external_binding_checked',externalBinding,'observed_file_sha256',before, ...
        'working_storage',working, ...
        'verification_scope','SHA-bound whole working file, all original typed/transport checks and requested NativeID/policy reconstruction. The strict5x target is reported separately; no fresh qualification is claimed.');
    if nargout>3
        view=struct('schema',c.schema,'solution_matrix',c.solution_matrix,'native_energy',c.native_energy, ...
            'signed_mean_U',c.signed_mean_U,'point_metadata',{c.point_metadata},'native_ids',{c.native_ids}, ...
            'contexts',{c.contexts},'typed_graph',c.graph,'source_reference',c.source_reference,'external_binding_checked',externalBinding,'observed_file_sha256',before, ...
            'working_storage',working, ...
            'scope','Necessary-data working storage. Saved scalar/graph plotting data; only physical_edges are physical continuation. No trajectory, new classification, endpoint or completion claim.');
    end
    literalPath(file);assert(strcmp(RoundSHA256_v3(file),before),'C1Core29:Changed','Core bytes changed while loading; no concurrent-writer or ABA guarantee is claimed.');
end

function observed=validateWorkingStorage(w,digest,c,coreDigest,bytes)
    keys={'schema','core_digest','maximum_file_bytes','strict_target_bytes','reason','reader_method','scope'};
    assert(isstruct(w)&&isscalar(w)&&isequal(sort(fieldnames(w)),sort(keys(:))) ...
        &&strcmp(w.schema,'C1-necessary-data-working-core29-v1'), ...
        'C1WorkingCore29:Header','Require the explicit necessary-data working header.');
    validSHA(digest);assert(strcmp(C1ScientificDigest_v3(w),digest), ...
        'C1WorkingCore29:HeaderDigest','The complete working header typed digest changed.');
    validSHA(w.core_digest);assert(strcmp(w.core_digest,coreDigest) ...
        &&isequal(w.strict_target_bytes,c.maximum_core_bytes), ...
        'C1WorkingCore29:CoreBinding','Working storage must retain the actual core digest and original strict target.');
    validateattributes(w.maximum_file_bytes,{'double'},{'real','scalar','finite','integer','>=',w.strict_target_bytes,'<=',flintmax});
    text(w.reason);assert(~isempty(strtrim(w.reason)),'C1WorkingCore29:Reason','Retain the explicit necessary-data storage reason.');
    assert(strcmp(w.scope,'Necessary complete-data working storage; the original strict5x target is unchanged. No new admission, branch completion or publication-size success is claimed.'), ...
        'C1WorkingCore29:Scope','The working scope must remain explicit.');
    m=w.reader_method;assert(isstruct(m)&&isscalar(m)&&isequal(sort(fieldnames(m)),{'name';'sha256'}) ...
        &&strcmp(m.name,'LoadC1WorkingSolutionCore29_v3'), ...
        'C1WorkingCore29:Reader','Bind this distinct working reader.');
    validSHA(m.sha256);method=which(m.name);assert(~isempty(method) ...
        &&strcmp(RoundSHA256_v3(literalPath(method)),m.sha256), ...
        'C1WorkingCore29:ReaderSHA','The declared working reader implementation changed.');
    assert(isscalar(bytes)&&~bytes.isdir&&bytes.bytes<=w.maximum_file_bytes, ...
        'C1WorkingCore29:FileCap','The complete working file exceeds its explicit necessary-data ceiling.');
    observed=struct('schema',w.schema,'reason',w.reason,'actual_file_bytes',bytes.bytes, ...
        'strict_target_bytes',w.strict_target_bytes,'strict_target_met',bytes.bytes<=w.strict_target_bytes, ...
        'maximum_file_bytes',w.maximum_file_bytes,'reader_method',m,'scope',w.scope);
end

function validateCore(c,digest)
    keys={'schema','layout','point_count','solution_matrix','parameters','modes','native_ids','point_metadata','contexts', ...
        'policies','section_charts','orbit_evidence','saved_reports','native_energy','signed_mean_U','graph', ...
        'source_projection_digests','source_reference','qualification_reference','qualification_closure', ...
        'writer_audit_reference','original_v2_reference','original_v2_bytes','maximum_core_bytes','runtime_methods','runtime_environment', ...
        'producer_reference','historical_audit_scope','replay_scope'};
    assert(isstruct(c)&&isscalar(c)&&isequal(sort(fieldnames(c)),sort(keys(:))) ...
        &&strcmp(c.schema,'C1-self-contained-solution-core29-v1') ...
        &&strcmp(c.layout,'rows1:14=initial_state;15:28=full_stride;29=period; columns=stored occurrences'), ...
        'C1Core29:Schema','Unknown core schema/fields refuse.');
    validSHA(digest);assert(strcmp(C1ScientificDigest_v3(c),digest),'C1Core29:Digest','The complete plain core typed digest changed.');
    N=c.point_count;validateattributes(N,{'double'},{'real','scalar','finite','integer','positive'});
    assert(isa(c.solution_matrix,'double')&&isreal(c.solution_matrix)&&~issparse(c.solution_matrix)&&isequal(size(c.solution_matrix),[29,N]) ...
        &&all(isfinite(c.solution_matrix(:)))&&all(c.solution_matrix(29,:)>0),'C1Core29:Matrix','The declared29-by-N finite real double layout is required.');
    for name={'parameters','modes','native_ids','point_metadata','contexts','policies','section_charts','orbit_evidence','saved_reports','source_projection_digests'}
        assert(iscell(c.(name{1}))&&isequal(size(c.(name{1})),[N,1]),'C1Core29:Rows','All occurrence arrays are Nx1 cells.');
    end
    assert(isa(c.native_energy,'double')&&isreal(c.native_energy)&&isequal(size(c.native_energy),[1,N])&&all(isfinite(c.native_energy)) ...
        &&isa(c.signed_mean_U,'double')&&isreal(c.signed_mean_U)&&isequal(size(c.signed_mean_U),[1,N])&&all(isfinite(c.signed_mean_U)), ...
        'C1Core29:Scalars','Stored plot scalars must be finite literal doubles.');
    ids=cell(N,1);owners=ids;orders=zeros(N,1);
    for k=1:N
        p=c.parameters{k};q=c.modes{k};assert(isnumeric(p)&&isreal(p)&&numel(p)==10&&all(isfinite(p(:))) ...
            &&(isnumeric(q)||islogical(q))&&isreal(q)&&numel(q)==4&&all(isfinite(q(:))),'C1Core29:PQ','Literal p10/q4 are required, without class/shape coercion.');
        nativeID(c.native_ids{k});validSHA(c.source_projection_digests{k});
        m=c.point_metadata{k};x=c.contexts{k};
        assert(isstruct(m)&&isscalar(m)&&all(isfield(m,{'component_identity','order'})) ...
            &&isstruct(x)&&isscalar(x)&&all(isfield(x,{'role','occurrence_id','expected_index','source_reference','source_index'})) ...
            &&isequal(x.expected_index,k),'C1Core29:Occurrence','Each literal source occurrence must retain its owner/context/order.');
        text(m.component_identity);text(x.occurrence_id);validateattributes(m.order,{'double'},{'real','scalar','finite','integer','positive'});
        if isfield(x,'native_id'),assert(isequaln(x.native_id,c.native_ids{k}),'C1Core29:ContextID','Context NativeID differs.');end
        owners{k}=m.component_identity;orders(k)=m.order;ids{k}=x.occurrence_id;
        prior=find(strcmp(owners(1:k-1),owners{k}),1,'last');
        assert(isempty(prior)||orders(k)>orders(prior),'C1Core29:OwnerOrder','Within-owner order must strictly increase.');
        policy=c.policies{k};assert(isstruct(policy)&&isscalar(policy)&&isequal(policy.complete,true) ...
            &&isstruct(policy.configuration)&&isscalar(policy.configuration) ...
            &&strcmp(policy.configuration.source_class,'BLMarkedApexReturnPolicy_v3'),'C1Core29:Policy','Only complete recorded BL policy configurations are supported.');
        chart=c.section_charts{k};assert(isstruct(chart)&&isscalar(chart)&&all(isfield(chart, ...
            {'id','geometry','crossing_orientation','boundary_ownership','translational_gauge','BL_touchdowns_per_return'})), ...
            'C1Core29:Section','A complete recorded section chart is load-required.');
        assert(isstruct(c.orbit_evidence{k})&&isscalar(c.orbit_evidence{k})&&isstruct(c.saved_reports{k})&&isscalar(c.saved_reports{k}), ...
            'C1Core29:HistoricalEvidence','Historical evidence remains plain and explicit.');
    end
    assert(numel(unique(ids))==N,'C1Core29:OccurrenceIDs','Occurrence IDs must be unique; NativeIDs may repeat.');
    validateGraph(c.graph,c.point_metadata,c.native_ids);
    assert(isnumeric(c.original_v2_bytes)&&isscalar(c.original_v2_bytes)&&isfinite(c.original_v2_bytes)&&c.original_v2_bytes>0 ...
        &&c.original_v2_bytes<=flintmax/5&&isequal(c.maximum_core_bytes,5*c.original_v2_bytes),'C1Core29:Cap','The whole component payload cap is exactly5 times the original fullv2 file bytes.');
end

function validateGraph(g,metadata,ids)
    keys={'schema','role','displayname','physical_edges','record_equalities','qualified_aliases','numerical_seams','source_versions'};
    assert(isstruct(g)&&isscalar(g)&&isequal(sort(fieldnames(g)),sort(keys(:)))&&strcmp(g.schema,'C1-essential-branch-graph-v1'), ...
        'C1Core29:Graph','Retain the whole qualified literal graph metadata.');
    N=numel(ids);incoming=zeros(N,1);
    for name={'physical_edges','record_equalities','qualified_aliases','numerical_seams'}
        rows=g.(name{1});assert(iscell(rows)&&iscolumn(rows),'C1Core29:GraphRows','Each typed graph remains a separate column cell table.');
        for j=1:numel(rows)
            e=rows{j};assert(isstruct(e)&&isscalar(e)&&all(isfield(e,{'from','to'})),'C1Core29:Relation','Unknown relation row.');
            validateattributes(e.from,{'double'},{'real','scalar','finite','integer','>=',1,'<=',N});
            validateattributes(e.to,{'double'},{'real','scalar','finite','integer','>=',1,'<=',N});
            assert(e.from~=e.to,'C1Core29:SelfEdge','Stored relation endpoints differ.');
            if strcmp(name{1},'physical_edges')
                assert(e.from<e.to&&strcmp(e.component_identity,metadata{e.from}.component_identity) ...
                    &&strcmp(e.component_identity,metadata{e.to}.component_identity),'C1Core29:PhysicalOwner','Physical edges require the original orientation and same owner.');
                incoming(e.to)=incoming(e.to)+1;
                assert(incoming(e.to)==1&&isequal(metadata{e.to}.edge_enabled,true)&&isequal(metadata{e.to}.edge_from,e.from), ...
                    'C1Core29:PhysicalPredecessor','Actual saved point/physical-edge predecessors must agree.');
            else
                assert(strcmp(e.from_native_id,ids{e.from})&&strcmp(e.to_native_id,ids{e.to}) ...
                    &&all(isfield(e,{'receipt_reference','evidence'})),'C1Core29:RelationID','Typed nonphysical links retain both actual endpoint IDs and evidence.');
            end
        end
    end
    for k=1:N
        enabled=isfield(metadata{k},'edge_enabled')&&isequal(metadata{k}.edge_enabled,true);
        assert(enabled==(incoming(k)==1),'C1Core29:Incoming','No enabled physical point edge may be omitted.');
    end
end

function [o,r]=reconstruct(c,k)
    v=struct('initial_state',c.solution_matrix(1:14,k),'initial_mode',c.modes{k},'parameter',c.parameters{k}, ...
        'stride_displacement',c.solution_matrix(15:28,k),'period',c.solution_matrix(29,k));
    o=HybridOrbit_v3(v);for name=properties(o).',o.(name{1})=[];end
    for name=fieldnames(v).',o.(name{1})=v.(name{1});end
    evidence=c.orbit_evidence{k};for name=fieldnames(evidence).',assert(isprop(o,name{1}),'C1Core29:OrbitProperty','Unknown retained orbit property.');o.(name{1})=evidence.(name{1});end
    o.section_chart=c.section_charts{k};o.validate();
    assert(strcmp(OrbitContentIdentity_v3(o),c.native_ids{k}),'C1Core29:NativeID','Fresh native reconstruction changed actual identity-bearing values.');
    configuration=c.policies{k}.configuration;r=c.saved_reports{k};
    r.correction_return_policy=struct('diagnostic_kind','runtime-object-descriptor','source_class',configuration.source_class,'settings',configuration.settings);
    [~,restored]=RecordedReturnPolicy_v3(r);
    assert(isequal(restored.complete,true)&&strcmp(C1ScientificDigest_v3(restored.configuration),C1ScientificDigest_v3(configuration)), ...
        'C1Core29:PolicyRoundtrip','The actual known policy constructor must preserve every recorded setting.');
    r.core29_view=struct('schema',c.schema,'requires_fresh_replay',true,'saved_decisions_are_historical',true, ...
        'fresh_all_nine_admission_claimed',false,'dense_trajectory_available',false);
end

function verifyMethods(rows,environment)
    assert(iscell(rows)&&iscolumn(rows),'C1Core29:Methods','Use a declared runtime method tuple.');
    required={'LoadC1SolutionCore29_v3','RoundSHA256_v3','V3Path_v3','V3Root_v3','C1ScientificDigest_v3','HybridOrbit_v3','OrbitContentIdentity_v3', ...
        'QuadrupedSchema_v3','RecordedReturnPolicy_v3','BLMarkedApexReturnPolicy_v3','ReturnPolicyBase_v3'};names=cell(numel(rows),1);
    for k=1:numel(rows)
        r=rows{k};assert(isstruct(r)&&isscalar(r)&&isequal(sort(fieldnames(r)),{'name';'sha256'}),'C1Core29:Method','Unknown runtime method row.');
        text(r.name);validSHA(r.sha256);file=which(r.name);assert(~isempty(file)&&strcmp(literalPath(file),canonical(file))&&strcmp(RoundSHA256_v3(file),r.sha256),'C1Core29:MethodSHA','The declared runtime implementation changed: %s.',r.name);names{k}=r.name;
    end
    assert(numel(unique(names))==numel(names)&&all(ismember(required,names)),'C1Core29:MethodTuple','The complete declared loader/constructor tuple is required; it is not a transitive execution trace.');
    assert(isstruct(environment)&&isscalar(environment)&&isequal(sort(fieldnames(environment)),sort({'locations_map_relative_path';'locations_map_sha256';'scope'})) ...
        &&strcmp(environment.locations_map_relative_path,fullfile('Audits_v3','Folder_Organization','locations.json')),'C1Core29:RuntimeEnvironment','Use the declared current-model runtime location map, not a historical scientific sidecar.');
    validSHA(environment.locations_map_sha256);root=V3Root_v3(which('V3Path_v3'));map=literalPath(fullfile(root,environment.locations_map_relative_path));
    assert(strcmp(RoundSHA256_v3(map),environment.locations_map_sha256),'C1Core29:LocationMap','The current runtime location map changed.');
end

function nativeID(v),text(v);assert(~isempty(regexp(v,'^native-orbit-record:sha256:[0-9a-f]{64}$','once')),'C1Core29:ID','Use actual OrbitContentIdentity output.');end
function validSHA(v),assert(ischar(v)&&isrow(v)&&~isempty(regexp(v,'^[0-9a-f]{64}$','once')),'C1Core29:SHA','Use a literal lowercaseSHA256.');end
function text(v),assert(ischar(v)&&isrow(v)&&~isempty(v),'C1Core29:Text','Use a nonempty character row.');end
function p=canonical(p),p=char(java.io.File(char(p)).getCanonicalPath());end
function p=literalPath(p)
    p=canonical(p);resolved=canonical(V3Path_v3(p));
    assert(strcmp(p,resolved),'C1Core29:LiteralPath','Hash, native load and publication must address the same literal canonical path; a legacy alias refuses.');
end

