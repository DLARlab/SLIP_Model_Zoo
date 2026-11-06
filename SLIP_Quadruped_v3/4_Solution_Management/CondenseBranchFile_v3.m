function receipt=CondenseBranchFile_v3(sourceReference,outputFile,options)
%CONDENSEBRANCHFILE_V3 Source-bound schema2 to essential schema4 export.
% Reuses the public essential scientific projection without running a map,
% root, classifier or admission. Source handles are never modified. Dense
% trajectories/runtime captures are intentionally unavailable afterwards;
% trajectory-dependent continuation must freshly replay the native state.
% The known Consolidate component_graph schemas are transported with
% the established essential-export graph adapter plus the literal original9
% E-only predecessor schema. Unknown graph/proof forms
% refuse; arbitrary other metadata is source-bound but not interpreted.
% The caller owns the writer lease, source closure and returned receipt.
% A returned receipt is storage verification, not fresh scientific admission.

    entered=tic;startUTC=unixNow();K=EssentialBranchSolutionFile_v3;
    keys={'MaximumBytes','MaxWallSeconds','SaveMarginSeconds','ReadbackIndices'};
    assert(isstruct(options)&&isscalar(options)&&isequal(sort(fieldnames(options)),sort(keys(:))), ...
        'CondenseBranch:Options','Supply exactly MaximumBytes, MaxWallSeconds, SaveMarginSeconds and ReadbackIndices.');
    o=options;
    for key={'MaximumBytes','MaxWallSeconds','SaveMarginSeconds'}
        validateattributes(o.(key{1}),{'double'},{'real','scalar','finite','positive'});
    end
    assert(o.SaveMarginSeconds<o.MaxWallSeconds,'CondenseBranch:Budget','The save reserve must be smaller than the whole wall cap.');
    source=checkedReference(sourceReference);outputFile=canonical(outputFile);
    assert(~isfile(outputFile)&&~isfolder(outputFile)&&isfolder(fileparts(outputFile)), ...
        'CondenseBranch:Fresh','Use a fresh output in an existing directory.');
    assert(~strcmp(source.file,outputFile),'CondenseBranch:Additive','The source cannot be overwritten.');
    methods={mfilename('fullpath'),which('EssentialBranchSolutionFile_v3'),which('BranchSolutionFile_v3'), ...
        which('OrbitContentIdentity_v3'),which('RecordedReturnPolicy_v3'),which('C1ScientificDigest_v3'),which('RoundSHA256_v3'), ...
        which('ProjectRecordedMethodDescriptors_v3')};
    methods{1}=[methods{1},'.m'];methodReferences=cellfun(@reference,methods,'UniformOutput',false).';
    guard(false);ix=BranchSolutionFile_v3.index(source.file);N=numel(ix.points);
    assert(isa(o.ReadbackIndices,'double')&&isreal(o.ReadbackIndices)&&(isvector(o.ReadbackIndices)||isempty(o.ReadbackIndices)) ...
        &&all(isfinite(o.ReadbackIndices(:)))&&all(o.ReadbackIndices(:)==fix(o.ReadbackIndices(:))) ...
        &&all(o.ReadbackIndices(:)>=1&o.ReadbackIndices(:)<=N), ...
        'CondenseBranch:ReadbackIndices','Readback indices must name literal source occurrences.');
    selected=unique(o.ReadbackIndices(:),'stable');
    assert(N>0||isempty(selected),'CondenseBranch:EmptyReadback','An empty source requires empty readback indices.');
    assert(N==0||~isempty(selected),'CondenseBranch:Readback','Select at least one independent native readback for a nonempty source.');
    records=cell(N,1);points=cell(N,1);contexts=cell(N,1);physical=cell(numel(ix.edges),1);
    digests=cell(N,1);nativeIDs=cell(N,1);originalMetadataDigests=cell(N,1);methodDispositions=cell(N,1);scopeDispositions=cell(N,1);
    for k=1:N
        p=ix.points{k};m=struct('component_identity',p.component_identity,'order',p.order);
        for key={'classification','nativeE','signedmeanU'}
            if isfield(p,key{1}),m.(key{1})=p.(key{1});end
        end
        m.edge_enabled=false;m.edge_from=[];points{k}=m;
        contexts{k}=struct('role','historical-unknown', ...
            'occurrence_id',sprintf('source-sha256:%s:index:%d',source.sha256,k), ...
            'source_reference',source,'source_index',k,'expected_index',k);
        originalMetadataDigests{k}=C1ScientificDigest_v3(p.metadata);
    end
    for k=1:numel(ix.edges)
        e=ix.edges{k};a=e.from;b=e.to;
        assert(a<b&&a>=1&&b<=N&&strcmp(ix.points{a}.component_identity,ix.points{b}.component_identity) ...
            &&strcmp(e.component_identity,ix.points{b}.component_identity)&&~points{b}.edge_enabled, ...
            'CondenseBranch:PhysicalEdge','Preserve only the literal unique earlier same-owner predecessor.');
        provenance=struct('kind','historical_physical_edge','source_reference',source, ...
            'source_from',a,'source_to',b,'receipt_reference',source,'receipt_availability','historical_locator');
        points{b}.edge_enabled=true;points{b}.edge_from=a;contexts{b}.physical_edge_provenance=provenance;
        physical{k}=struct('from',a,'to',b,'component_identity',e.component_identity,'provenance',provenance);
    end
    % Native object deserialization is amortized in bounded blocks. Only
    % these eight raw orbit/report pairs coexist; projected records are plain.
    blockEnd=0;sourceReadBlocks=cell(0,1);blockSaved=struct();
    for k=1:N
        guard(false);p=ix.points{k};
        if k>blockEnd
            clear blockSaved
            blockEnd=min(k+7,N);variables=cell(2*(blockEnd-k+1),1);
            for j=k:blockEnd
                point=ix.points{j};at=2*(j-k)+1;variables{at}=point.solution_variable;variables{at+1}=point.report_variable;
            end
            reading=tic;blockSaved=load(source.file,variables{:});
            sourceReadBlocks{end+1,1}=struct('first_index',k,'last_index',blockEnd, ...
                'selected_native_pairs',blockEnd-k+1,'acquisition_elapsed_seconds',toc(reading));
        end
        orbit=blockSaved.(p.solution_variable);report=blockSaved.(p.report_variable);
        assert(isa(orbit,'HybridOrbit_v3')&&isscalar(orbit)&&isstruct(report)&&isscalar(report), ...
            'CondenseBranch:NativeRecord','Each source point must contain its native orbit and scalar saved report.');
        context=contexts{k};context.role=sourceRole(report,p.metadata,points{k}.edge_enabled);
        try
            [report,methodEvidence]=ProjectRecordedMethodDescriptors_v3(report);
            [report,scopeEvidence]=projectAcquisitionScope(report);
            r=K.project(orbit,report,points{k},context);
        catch problem
            failure=MException('CondenseBranch:UnsupportedProjection', ...
                'Source point %d is unsupported by the existing essential projection (%s): %s. Source and output authority are unchanged.',k,problem.identifier,problem.message);
            failure=addCause(failure,problem);throw(failure)
        end
        % The projection checks every literal core value and policy. NativeID
        % is an additional whole-record check, not a substitute for raw data.
        if completeIdentity(orbit)
            assert(strcmp(r.native_id,OrbitContentIdentity_v3(orbit)),'CondenseBranch:NativeID','Literal source NativeID changed.');
        else
            assert(isempty(r.native_id),'CondenseBranch:NativeID','An incomplete original record cannot acquire an identity.');
        end
        for key={'initial_state','initial_mode','parameter','period','stride_displacement','poincare_state'}
            assert(isequaln(r.orbit.(key{1}),orbit.(key{1})),'CondenseBranch:LiteralCore','Literal %s changed.',key{1});
        end
        records{k}=r;digests{k}=C1ScientificDigest_v3(r);nativeIDs{k}=r.native_id;methodDispositions{k}=methodEvidence;scopeDispositions{k}=scopeEvidence;
        clear orbit report r
    end
    clear blockSaved
    % Reuse the source-backed graph projection previously exercised by the
    % retained essential exporter. It preserves distinct E/A/M semantics;
    % it performs no new alias/meeting qualification or historical file I/O.
    [metadata,graphCounts]=wholeGraph(ix,source,records,physical,methodReferences,'Condensed');
    metadata.role='source-bound-condensed-branch';
    guard(false);verifyReference(source);verifyMethods();
    returned=K.writeProjections(outputFile,metadata,records,o.MaximumBytes);
    % An output left by a failed/late caller remains unqualified; no source
    % is ever removed by this utility.
    guard(true);
    assert(numel(returned.points)==N&&isequal(returned.record_native_ids,nativeIDs), ...
        'CondenseBranch:AllNativeIDs','Every stored occurrence must retain its source NativeID, including missingness.');
    assert(isequal(returned.edges,ix.edges),'CondenseBranch:PhysicalTable','Literal P endpoints, orientations and owners changed.');
    for k=1:N
        actual=lower(reshape(dec2hex(returned.record_projection_digests(:,k),2).',1,[]));
        assert(strcmp(actual,digests{k}),'CondenseBranch:AllProjectionDigests','The stored scientific projection changed at point %d.',k);
    end
    [one,oneReports,oneMetadata]=K.loadSolutions(outputFile,selected);
    [two,twoReports,twoMetadata]=K.loadSolutions(outputFile,selected);
    for j=1:numel(selected)
        k=selected(j);a=K.project(one{j},oneReports{j},oneMetadata{j},records{k}.context);
        b=K.project(two{j},twoReports{j},twoMetadata{j},records{k}.context);
        assert(isequaln(a,records{k})&&isequaln(b,records{k}), ...
            'CondenseBranch:Readback','Two independent native readbacks must equal the retained source projection.');
        assert(~(one{j}==two{j}),'CondenseBranch:Clone','Independent loads must not share the native orbit handle.');
    end
    guard(true);verifyReference(source);verifyMethods();out=reference(outputFile);
    contract=K.contract();receipt=struct('schema','source-bound-branch-condensation-v1', ...
        'source_reference',source,'output_reference',out,'source_point_count',N, ...
        'source_index_digest',C1ScientificDigest_v3(ix),'original_point_metadata_digests',{originalMetadataDigests}, ...
        'point_role_metadata_facts',{cellfun(@(p)roleMetadataFacts(p.metadata),ix.points,'UniformOutput',false)}, ...
        'original_physical_edges',{ix.edges},'physical_edge_count',numel(ix.edges), ...
        'original_branch_metadata',ix.metadata,'typed_graph_counts',graphCounts, ...
        'graph_projection_donor',struct('archive_sha256','ac9a431ede708adf650f5b19dca40d1cb92d16ad46b3d6aa8927f6389e4a8779', ...
            'member','methods/ExportC1EssentialCompleteStoresFinal03_20261030.m','member_sha256','975906621435d23c01f290c76c749b49e05dc4c491a4215e18279b6b51b99b23'), ...
        'record_native_ids',{nativeIDs},'record_projection_digests',{digests}, ...
        'recorded_method_descriptor_dispositions',{methodDispositions}, ...
        'structured_acquisition_scope_dispositions',{scopeDispositions}, ...
        'recorded_method_descriptor_projection_count',sum(cellfun(@numel,methodDispositions)), ...
        'selected_readback_indices',selected,'selected_independent_read2_verified',true, ...
        'all_literal_core_values_verified',true,'all_saved_projection_digests_verified',true, ...
        'source_posthash',true,'source_methods',{methodReferences},'options',o, ...
        'source_read_block_size',8,'source_read_blocks',{sourceReadBlocks}, ...
        'source_selected_native_load_calls',numel(sourceReadBlocks), ...
        'memory_measurement_scope','The caller measures process peak RSS externally. Block cardinality and acquisition timings are not native-memory or RSS measurements.', ...
        'loss_disclosure',contract.omissions, ...
        'source_metadata_scope','Literal point owner/order/classification/E/velocity and physical P plus known source graph E/A/M are transported; original branch metadata is retained literally in this receipt, Known wrapper/nonedge role facts and their source field paths are additionally retained; other original point metadata remains digest-bound. Context roles use those known metadata contracts before saved native-report acceptance.', ...
        'historical_locator_availability','Source headers stay literal; caller must record any subsequent source retirement.', ...
        'requires_fresh_replay',true,'new_admission_claimed',false,'new_physical_edges_created',0, ...
        'whole_original_runtime_equality_claimed',false,'elapsed_seconds',toc(entered));

    function guard(final)
        left=o.MaxWallSeconds-max(toc(entered),unixNow()-startUTC);
        if ~final,left=left-o.SaveMarginSeconds;end
        assert(left>0,'CondenseBranch:WallCap','The bounded storage cap/reserve was reached; retain any additive output as unqualified.');
    end
    function verifyMethods()
        for z=1:numel(methodReferences),verifyReference(methodReferences{z});end
    end
end

function [report,evidence]=projectAcquisitionScope(report)
% Exact RunC1GPitchAcquisition storage envelope; retain literal flags/data in
% the receipt because Essential.report currently allows a primitive here.
% Removing this optional report field neither admits nor rejects an orbit.
    evidence=struct();
    if ~isfield(report,'acquisition_scope')||~isstruct(report.acquisition_scope),return;end
    value=report.acquisition_scope;
    expected={'native_return_timely','capture','attachment_claimed','pitch_sign_determines_posture_claimed','classical_derivative_claimed'};
    exactFields(value,expected,'RunC1GPitchAcquisition acquisition_scope');
    assert(islogical(value.native_return_timely)&&isscalar(value.native_return_timely) ...
        &&isequal(value.attachment_claimed,false)&&isequal(value.pitch_sign_determines_posture_claimed,false) ...
        &&isequal(value.classical_derivative_claimed,false)&&isstruct(value.capture)&&isscalar(value.capture), ...
        'CondenseBranch:AcquisitionScope','Preserve only the exact known GPitch scope; no false/unknown scientific claim is normalized.');
    capture={'same_policy','same_parameters','same_mode','same_chart','full13_scaled_inf', ...
        'relative_period_change','relative_stride_change','actual_pitch','pitch_error','passed'};
    assert(isempty(fieldnames(value.capture))||isequal(sort(fieldnames(value.capture)),sort(capture(:))), ...
        'CondenseBranch:AcquisitionScope','Unknown capture fields must remain raw rather than be silently projected.');
    C1ScientificDigest_v3(value); % Reject unknown runtime objects/captures.
    evidence=struct('path','report.acquisition_scope','original_literal_value',value, ...
        'source_contract','RunC1GPitchAcquisition_v3:107-108', ...
        'action','known_structured_optional_field_retained_in_receipt', ...
        'replacement_report_field_present',false,'scientific_flags_changed',false, ...
        'scope','Literal acquisition/capture flags are stored as data here; no wrapper capture, edge or admission follows.');
    report=rmfield(report,'acquisition_scope');
end

function role=sourceRole(report,metadata,edgeEnabled)
    role='';m=metadata;
    for depth=1:16
        assert(isstruct(m)&&isscalar(m),'CondenseBranch:RoleMetadata','Known role metadata envelopes must be scalar structures.');
        if isfield(m,'independent_NONEDGE_control')
            assert(isequal(m.independent_NONEDGE_control,true),'CondenseBranch:RoleMarker','Do not reinterpret a false/unknown declared independent-control marker.');role='nonedge-control';break
        end
        if ~isfield(m,'provenance'),break;end;p=m.provenance;if ~isstruct(p)||~isscalar(p),break;end
        if isfield(p,'kind')&&strcmp(p.kind,'imported nonedge initial pair'),role='nonedge-control';break;end
        if isfield(p,'kind')&&strcmp(p.kind,'native all-nine return rejected by continuation wrapper')
            assert(isequal(p.wrapper_accepted,false)&&isequal(p.edge_claimed,false),'CondenseBranch:RoleMarker','Known isolated-native disposition must retain literal wrapper/edge falseflags.');role='isolated';break
        end
        if isfield(p,'historical_predictor')&&isequal(p.historical_predictor,true)&&isfield(p,'edge_claimed')&&isequal(p.edge_claimed,false),role='nonedge-control';break;end
        if isfield(p,'original_point_metadata')
            fields={'source_file','source_sha256','source_index','source_catalog_file','source_catalog_entry','original_point_metadata','qualification_flags_changed'};
            exactFields(p,fields,'Consolidate direct provenance');assert(isequal(p.qualification_flags_changed,false),'CondenseBranch:RoleMarker','A historical wrapper cannot claim upgraded flags.');m=p.original_point_metadata;
        else,break;end
        assert(depth<16,'CondenseBranch:RoleDepth','Known source metadata wrappers exceed the explicit bound; do not infer a role.');
    end
    if isempty(role)
        if literalAccepted(report),role='accepted';
        elseif isfield(report,'accepted')&&isequal(report.accepted,false)&&isfield(report,'status')&&strcmp(report.status,'rejected'),role='rejected';
        else,role='historical-unknown';end
    end
    if strcmp(role,'rejected'),assert(~isfield(report,'accepted')||~isequal(report.accepted,true),'CondenseBranch:RoleConflict','A rejected claim cannot relabel a saved accepted return.');end
    if isfield(metadata,'role'),assert(strcmp(metadata.role,role),'CondenseBranch:RoleConflict','An explicit unknown/contradictory source role is not silently discarded.');end
    if edgeEnabled,assert(~ismember(role,{'nonedge-control','isolated','rejected'}),'CondenseBranch:RoleEdge','A literal control/isolated/rejected role cannot acquire a physical predecessor.');end
end


function facts=roleMetadataFacts(metadata)
    facts=cell(0,1);m=metadata;path='metadata';
    for depth=1:16
        assert(isstruct(m)&&isscalar(m),'CondenseBranch:RoleFacts','Role metadata envelopes must be scalar structures.');
        for key={'role','independent_NONEDGE_control'}
            name=key{1};if isfield(m,name),facts{end+1,1}=struct('field_path',[path,'.',name],'literal_value',m.(name));end
        end
        if ~isfield(m,'provenance')||~isstruct(m.provenance)||~isscalar(m.provenance),break;end
        p=m.provenance;
        for key={'kind','wrapper_accepted','committed','edge_claimed','historical_predictor','qualification_flags_changed'}
            name=key{1};if isfield(p,name),facts{end+1,1}=struct('field_path',[path,'.provenance.',name],'literal_value',p.(name));end
        end
        if ~isfield(p,'original_point_metadata'),break;end
        m=p.original_point_metadata;path=[path,'.provenance.original_point_metadata'];
        assert(depth<16,'CondenseBranch:RoleDepth','Known source metadata wrappers exceed the explicit bound.');
    end
end

function yes=literalAccepted(r)
    names={'full_closure','mode_closure','target_energy','trajectory_energy_variation','unscaled_family_equations','family_constraint','physical_inequalities','primitive_identity','replay_determinism'};
    yes=isstruct(r)&&isscalar(r)&&isfield(r,'accepted')&&isequal(r.accepted,true)&&isfield(r,'status')&&strcmp(r.status,'accepted') ...
        &&isfield(r,'acceptance_gates')&&isstruct(r.acceptance_gates)&&isscalar(r.acceptance_gates)&&isequal(sort(fieldnames(r.acceptance_gates)),sort(names(:)));
    if yes,yes=all(cellfun(@(k)isequal(r.acceptance_gates.(k),true),names));end
end


function yes=completeIdentity(o)
    yes=numel(o.initial_state)==14&&numel(o.initial_mode)==4&&numel(o.parameter)==10 ...
        &&isscalar(o.period)&&numel(o.stride_displacement)==14;
end
function r=checkedReference(r)
    assert(isstruct(r)&&isscalar(r)&&all(isfield(r,{'file','sha256'})), ...
        'CondenseBranch:Reference','Supply an immutable source FILE/SHA reference.');
    original=r;r=struct('file',canonical(r.file),'sha256',char(r.sha256));verifyReference(r);
    if isfield(original,'bytes'),s=dir(r.file);assert(isequal(s.bytes,original.bytes),'CondenseBranch:Bytes','Source bytes changed.');end
end
function verifyReference(r)
    assert(isfile(r.file)&&strcmp(RoundSHA256_v3(r.file),r.sha256), ...
        'CondenseBranch:Hash','Required immutable source changed or is unavailable: %s',r.file);
end
function r=reference(file)
    file=canonical(file);assert(isfile(file),'CondenseBranch:Missing','Required source is missing: %s',file);
    s=dir(file);r=struct('file',file,'sha256',RoundSHA256_v3(file),'bytes',s.bytes);
end
function file=canonical(file)
    file=char(java.io.File(char(file)).getCanonicalPath());
end
function value=unixNow()
    value=posixtime(datetime('now','TimeZone','UTC'));
end

% Graph adapter donor: retained seven-method source archive; functions below
% copied from the donor, with only the explicit original9 graph-schema case
% added to wholeGraph after native observation; relation evidence is unchanged.
function [branch,counts]=wholeGraph(ix,source,records,physical,code,label)
    names={'record_equalities','qualified_aliases','numerical_seams'};oldNames={'exact_record_equalities','qualified_record_aliases','qualified_numerical_overlaps'};
    evidenceNames={'equality_evidence','qualified_alias_evidence','numerical_overlap_evidence'};relations=struct('record_equalities',{cell(0,1)},'qualified_aliases',{cell(0,1)},'numerical_seams',{cell(0,1)});
    if isfield(ix.metadata,'component_graph')
        g=ix.metadata.component_graph;
        earliestFields={'schema','nodes','original_explicit_edges','exact_record_equalities','effective_edges','equality_evidence','connected','isolated_record_catalogue','equality_links_are_continuation_edges'};
        legacyFields={'schema','nodes','original_explicit_edges','exact_record_equalities','qualified_record_aliases','qualified_alias_evidence','effective_edges','equality_evidence','connected','isolated_record_catalogue','equality_links_are_continuation_edges','qualified_aliases_are_exact_record_equalities','qualified_aliases_are_continuation_edges'};
        numericalFields={'qualified_numerical_overlaps','numerical_overlap_evidence','strict_trace_scope','numerical_storage_scope','numerical_adjacencies_are_identity_quotients','numerical_adjacencies_are_physical_edges'};
        assert(isstruct(g)&&isscalar(g),'C1EssentialComplete:GraphSource','Use a scalar literal Consolidate graph snapshot.');
        if isequal(sort(fieldnames(g)),sort(earliestFields(:)))
            relationCount=1; % Exact original9 producer declares only E, with no A/M fields or flags.
        elseif isequal(sort(fieldnames(g)),sort(legacyFields(:)))
            relationCount=2; % The exact legacy producer has no numerical relation table or numerical flags.
        elseif isequal(sort(fieldnames(g)),sort([legacyFields(:);numericalFields(:)]))
            relationCount=3;
            assert(isequal(g.numerical_adjacencies_are_identity_quotients,false)&&isequal(g.numerical_adjacencies_are_physical_edges,false), ...
                'C1EssentialComplete:GraphSource','Retain the distinct modern numerical-adjacency semantics, without identity or physical-edge claims.');
        else
            error('C1EssentialComplete:GraphSource','Unknown or mixed Consolidate graph fields; require exactly the known original9, legacy13 or modern19 producer.');
        end
        assert(strcmp(g.schema,'C1-connected-component-graph-v1')&&isequal(g.equality_links_are_continuation_edges,false), ...
            'C1EssentialComplete:GraphSource','Preserve the literal original nonphysical equality flag.');
        if relationCount>=2
            assert(isequal(g.qualified_aliases_are_exact_record_equalities,false)&&isequal(g.qualified_aliases_are_continuation_edges,false), ...
                'C1EssentialComplete:GraphSource','Preserve alias flags only when declared by the known source producer.');
        end
        assert(isnumeric(g.nodes)&&isreal(g.nodes)&&isscalar(g.nodes)&&isfinite(g.nodes)&&g.nodes==fix(g.nodes)&&g.nodes>=1&&g.nodes<=numel(records), ...
            'C1EssentialComplete:GraphSnapshot','The literal consolidation snapshot is bounded by the current store; later physical appends remain authoritative in the current index.');
        snapshot=g.original_explicit_edges;
        assert(isnumeric(snapshot)&&isreal(snapshot)&&ismatrix(snapshot)&&size(snapshot,2)==2&&all(isfinite(snapshot(:))) ...
            &&all(snapshot(:)==fix(snapshot(:)))&&all(snapshot(:)>=1)&&all(snapshot(:)<=g.nodes)&&all(snapshot(:,1)~=snapshot(:,2)), ...
            'C1EssentialComplete:GraphSnapshot','Preserve bounded literal physical snapshot edges without replacing the current public index edges.');
        for kind=1:relationCount,snapshot=[snapshot;g.(oldNames{kind})];end %#ok<AGROW>
        assert(isequal(g.effective_edges,snapshot),'C1EssentialComplete:GraphSnapshot','The exact producer effective snapshot is the ordered physical/equality/alias and, only for modern19, numerical concatenation.');
        for kind=1:relationCount
            assert(isfield(g,oldNames{kind})&&isfield(g,evidenceNames{kind}),'C1EssentialComplete:GraphEvidence','Every known relation table needs its literal complete evidence table.');
            pairs=g.(oldNames{kind});evidence=g.(evidenceNames{kind});assert(isnumeric(pairs)&&isreal(pairs)&&size(pairs,2)==2&&iscell(evidence)&&numel(evidence)==size(pairs,1), ...
                'C1EssentialComplete:GraphEvidence','All actual pair/evidence rows must correspond in exact source order.');rows=cell(size(pairs,1),1);
            for j=1:size(pairs,1)
                a=pairs(j,1);b=pairs(j,2);assert(all(isfinite([a,b]))&&all([a,b]==fix([a,b]))&&all([a,b]>=1)&&all([a,b]<=g.nodes)&&all([a,b]<=numel(records))&&a~=b, ...
                    'C1EssentialComplete:RelationBounds','Every relation endpoint must be an actual distinct occurrence.');
                [scalars,fines,schema]=relationEvidence(kind,evidence{j},records{a},records{b},a,ix,records);
                rows{j}=struct('from',a,'to',b,'from_native_id',records{a}.native_id,'to_native_id',records{b}.native_id, ...
                    'receipt_reference',source,'evidence',struct('schema',schema,'scalars',scalars,'original_fines',{fines}));
            end
            relations.(names{kind})=rows;
        end
    end
    branch=struct('schema','C1-essential-branch-graph-v1','role','unpublished-complete-store-measurement','displayname',[label,' complete literal source store'], ...
        'physical_edges',{physical},'record_equalities',{relations.record_equalities},'qualified_aliases',{relations.qualified_aliases}, ...
        'numerical_seams',{relations.numerical_seams},'source_versions',{cellfun(@ref2,code(:),'UniformOutput',false)});
    counts=struct('physical_edges',numel(physical),'record_equalities',numel(relations.record_equalities),'qualified_aliases',numel(relations.qualified_aliases),'numerical_seams',numel(relations.numerical_seams));
end

function [s,fines,schema]=relationEvidence(kind,e,left,right,leftIndex,ix,records)
    fines=cell(0,1);assert(~isempty(left.native_id)&&~isempty(right.native_id),'C1EssentialComplete:RelationID','Nonphysical relations require literal complete endpoint IDs.');
    if kind==1
        exactFields(e,{'native_ID','exact_state_mode_parameter_period_stride','translation_gauge_normalized','matching_return_section','new_continuation_edge_created'},'exact equality evidence');
        assert(isequal(e.exact_state_mode_parameter_period_stride,true)&&isequal(e.translation_gauge_normalized,true)&&isequal(e.new_continuation_edge_created,false) ...
            &&strcmp(e.native_ID,left.native_id)&&strcmp(e.native_ID,right.native_id),'C1EssentialComplete:Equality','Literal original exact-identity evidence must bind both actual NativeIDs.');
        a=identityRecord(left);b=identityRecord(right);a.initial_state(1)=0;b.initial_state(1)=0;rawEqual3(a,b,b,'actual normalized exact equality');checkMatching(e.matching_return_section,left,right);
        s=struct('exact_state_mode_parameter_period_stride',e.exact_state_mode_parameter_period_stride,'translation_gauge_normalized',e.translation_gauge_normalized,'new_continuation_edge_created',e.new_continuation_edge_created);
        s=mergeScalars(s,matchingScalars(e.matching_return_section));schema='ConsolidateC1ConnectedComponents_v3:exact-record-equality-v1';
    elseif kind==2
        fields={'schema','qualified','scope','left_native_ID','right_native_ID','exact_full_initial_state_mode_parameter','physical_parameters_schema_valid','canonical_point_label','left_admission','right_admission','matching_return_section','relative_absolute_tolerance','scale_formula','period_difference','period_scale','scaled_period_difference','stride_difference','stride_scale','scaled_stride_difference_inf','exact_record_equality_claimed','new_continuation_edge_created','original_orbits_reports_and_native_IDs_must_be_retained','request','qualification_source'};
        exactFields(e,fields,'qualified alias evidence');assert(strcmp(e.schema,'C1-qualified-record-alias-v1')&&isequal(e.qualified,true)&&isequal(e.exact_full_initial_state_mode_parameter,true)&&isequal(e.new_continuation_edge_created,false) ...
            &&e.relative_absolute_tolerance==1e-10&&e.scaled_period_difference<=1e-10&&e.scaled_stride_difference_inf<=1e-10, ...
            'C1EssentialComplete:Alias','Copy only the known original qualified-alias contract and fixed stored tolerances.');
        bindIDs(e,left,right);for key={'initial_state','initial_mode','parameter'},rawEqual3(left.orbit.(key{1}),right.orbit.(key{1}),right.orbit.(key{1}),'literal alias raw identity');end
        checkMatching(e.matching_return_section,left,right);checkAdmission(e.left_admission,left,false);checkAdmission(e.right_admission,right,false);
        s=pickScalars(e,{'qualified','exact_full_initial_state_mode_parameter','physical_parameters_schema_valid','canonical_point_label','relative_absolute_tolerance','period_difference','period_scale','scaled_period_difference','stride_difference','stride_scale','scaled_stride_difference_inf','exact_record_equality_claimed','new_continuation_edge_created'});
        s.original_full_runtime_required_at_qualification=e.original_orbits_reports_and_native_IDs_must_be_retained;s=mergeScalars(s,matchingScalars(e.matching_return_section));s=mergeScalars(s,aliasTransport(e));schema=e.schema;
    else
        fields={'schema','qualified','full_native_proof_validated','audit_reference','proof_identity','execution_witness','raw_reference','trial_reference','checkpoint_reference','literal_control_reference','literal_control_raw_reference','left_selector','right_selector','left_native_ID','right_native_ID','left_record','right_record','left_admission','right_admission','comparison','left_original_fines','right_original_fines','earned_physical_edge','validation_source_references','all_source_references_posthash_verified','identity_claimed','quotient_identification','new_continuation_edge_created','classification_or_admission_flags_changed','original_orbits_reports_and_native_IDs_retained','scope','cohort_scope','energy_scope','runtime_comparison_scope'};
        exactFields(e,fields,'qualified numerical evidence');assert(strcmp(e.schema,'C1-qualified-PK-numerical-overlap-v1')&&isequal(e.qualified,true)&&isequal(e.full_native_proof_validated,true) ...
            &&isequal(e.all_source_references_posthash_verified,true)&&isequal(e.identity_claimed,false)&&isequal(e.quotient_identification,false)&&isequal(e.new_continuation_edge_created,false)&&isequal(e.classification_or_admission_flags_changed,false) ...
            &&strcmp(e.proof_identity,'43b7037ec366d628018b40205545194a17f5291c45c3775ef4ddec290900d43c') ...
            &&strcmp(e.proof_identity,e.audit_reference.sha256)&&isequal(e.original_orbits_reports_and_native_IDs_retained,true),'C1EssentialComplete:Seam','Only the distinct complete original numerical-qualification schema is projected.');
        bindIDs(e,left,right);rawEqual3(e.left_record,identityRecord(left),identityRecord(left),'numerical left original raw record');rawEqual3(e.right_record,identityRecord(right),identityRecord(right),'numerical right original raw record');
        checkAdmission(e.left_admission,left,true);checkAdmission(e.right_admission,right,true);c=e.comparison;assert(isequal(c.conditions_met,true),'C1EssentialComplete:Seam','Do not promote an originally false finite comparison.');checkMatching(c.matching_section,left,right);
        incoming=find(cellfun(@(edge)edge.to==leftIndex,ix.edges));assert(isscalar(incoming),'C1EssentialComplete:SeamParent','The earned seam endpoint must have one actual incoming physical edge.');edge=ix.edges{incoming};parent=records{edge.from};
        rawEqual3(e.earned_physical_edge.from_record,identityRecord(parent),identityRecord(parent),'literal earned-parent raw record');
        assert(strcmp(e.earned_physical_edge.from_native_ID,parent.native_id)&&e.earned_physical_edge.from==2&&e.earned_physical_edge.to==3 ...
            &&isequal(e.earned_physical_edge.actual_new_points,1)&&isequal(e.earned_physical_edge.actual_new_edges,1) ...
            &&strcmp(parent.metadata.component_identity,left.metadata.component_identity)&&strcmp(edge.component_identity,left.metadata.component_identity), ...
            'C1EssentialComplete:SeamParent','Only after raw parent identity/actual same-owner edge binding may its NativeID be retained.');
        ownerRows=ix.metadata.source_owner_map;owners=find(cellfun(@(r)strcmp(r.output_component_identity,left.metadata.component_identity),ownerRows));
        assert(isscalar(owners)&&strcmp(ownerRows{owners}.source_component_identity,e.earned_physical_edge.owner),'C1EssentialComplete:SeamOwner','The explicit Consolidate owner map must preserve original earned ownership.');
        s=pickScalars(e,{'qualified','full_native_proof_validated','all_source_references_posthash_verified','identity_claimed','quotient_identification','new_continuation_edge_created','classification_or_admission_flags_changed'});
        s.original_full_runtime_retained_at_qualification=e.original_orbits_reports_and_native_IDs_retained;
        s=mergeScalars(s,pickScalars(c,{'raw_full13_delta','raw_full13_scaled_inf','period_delta','period_tolerance','full_stride_delta','full_stride_tolerance','native_energy_delta','exact_state_equal','exact_p_q_equal','exact_complete_policy_equal','same_section_event_signature','conditions_met'}));
        s=mergeScalars(s,matchingScalars(c.matching_section));s.earned_parent_native_id=parent.native_id;s.actual_new_points=e.earned_physical_edge.actual_new_points;s.actual_new_edges=e.earned_physical_edge.actual_new_edges;
        w=e.execution_witness;assert(strcmp(w.schema,'C1-external-GateB-process-exit-witness-v1')&&w.process_session_id==39141&&isequal(w.actual_process_exit_observed,true)&&w.exit_code==0 ...
            &&strcmp(w.run_name,'GateBOwned01')&&strcmp(w.audit_reference.sha256,e.proof_identity),'C1EssentialComplete:SeamExecution','Retain the original separately observed native process closure.');
        s.execution_witness_schema=w.schema;s.execution_session_id=w.process_session_id;s.execution_exit_observed=w.actual_process_exit_observed;s.execution_exit_code=w.exit_code;s.execution_run_name=w.run_name;
        s=mergeScalars(s,fineScalars(e.left_original_fines,'left'));s=mergeScalars(s,fineScalars(e.right_original_fines,'right'));
        fines=[fineProjection(e.left_original_fines,e.audit_reference);fineProjection(e.right_original_fines,e.audit_reference)];schema=e.schema;
    end
end

function out=fineProjection(rows,source)
    assert(iscell(rows)&&numel(rows)==2,'C1EssentialComplete:Fines','Each original endpoint retains exactly two ordered original-state fine observations.');out=cell(2,1);steps=[.0005,.00025];
    for k=1:2
        f=rows{k};requiredFields(f,{'observation','raw_custody','passed','MaxStep','full13_norm','initial_trajectory_row_exact','matching_saved_section','primitive','saved_period_scaled_error','saved_stride_scaled_error'},'original fine');
        assert(f.MaxStep==steps(k)&&isequal(f.passed,true)&&isequal(f.initial_trajectory_row_exact,true)&&isequal(f.matching_saved_section.compatible,true) ...
            &&f.primitive.cover_count==1&&strcmp(f.primitive.status,'primitive_within_checked_bound')&&f.full13_norm<=1e-8&&f.saved_period_scaled_error<=1e-8&&f.saved_stride_scaled_error<=1e-8 ...
            &&f.observation.invoked&&f.observation.returned&&f.observation.return_timely ...
            &&f.raw_custody.storage_completed&&f.raw_custody.storage_timely&&f.raw_custody.readback_completed&&f.raw_custody.readback_timely, ...
            'C1EssentialComplete:Fines','Preserve actual fine/primitive/original-state/timing/custody flags; no absent gate is manufactured.');
        out{k}=struct('source_reference',ref2(source),'MaxStep',f.MaxStep,'full_closure',f.full13_norm, ...
            'period_scaled_error',f.saved_period_scaled_error,'stride_scaled_error',f.saved_stride_scaled_error, ...
            'primitive',{{f.primitive.status;f.primitive.cover_count}},'invoked',f.observation.invoked,'returned',f.observation.returned,'return_timely',f.observation.return_timely, ...
            'storage_completed',f.raw_custody.storage_completed,'storage_timely',f.raw_custody.storage_timely,'readback_completed',f.raw_custody.readback_completed,'readback_timely',f.raw_custody.readback_timely,'passed',f.passed);
    end
end

function out=fineScalars(rows,side)
    out=struct();for k=1:2
        out.(sprintf('%s_fine%d_initial_trajectory_row_exact',side,k))=rows{k}.initial_trajectory_row_exact;
        out.(sprintf('%s_fine%d_matching_section_compatible',side,k))=rows{k}.matching_saved_section.compatible;
    end
end

function out=aliasTransport(e)
    historicalReference(e.qualification_source);r=e.request;exactFields(r,{'left_node','right_node','kind','input_request'},'Consolidate alias request');
    validateattributes(r.left_node,{'numeric'},{'real','scalar','finite','integer','positive'});validateattributes(r.right_node,{'numeric'},{'real','scalar','finite','integer','positive'});
    out=struct('alias_qualification_source_file',e.qualification_source.file,'alias_qualification_source_sha256',e.qualification_source.sha256, ...
        'alias_request_kind',r.kind,'alias_historical_left_node',r.left_node,'alias_historical_right_node',r.right_node);
    if strcmp(r.kind,'explicit_requested_numeric_alias')
        exactFields(r.input_request,{'left_file','left_index','right_file','right_index'},'explicit alias selector');
        for key={'left_file','right_file'},path=r.input_request.(key{1});assert((ischar(path)&&isrow(path)&&~isempty(path))||(isstring(path)&&isscalar(path)&&~ismissing(path)&&strlength(path)>0), ...
                'C1EssentialComplete:AliasLocator','Retain literal historical selector paths without reopening retired inputs.');end
        for key={'left_index','right_index'},validateattributes(r.input_request.(key{1}),{'numeric'},{'real','scalar','finite','integer','positive'});end
        out.alias_request_left_file=r.input_request.left_file;out.alias_request_left_index=r.input_request.left_index;out.alias_request_right_file=r.input_request.right_file;out.alias_request_right_index=r.input_request.right_index;
    else
        assert(strcmp(r.kind,'inherited_qualified_record_alias'),'C1EssentialComplete:AliasTransport','Unknown claimed alias-transport kinds require review.');
        exactFields(r.input_request,{'source_file','source_sha256','source_alias_row'},'inherited alias locator');
        historicalReference(struct('file',r.input_request.source_file,'sha256',r.input_request.source_sha256));validateattributes(r.input_request.source_alias_row,{'numeric'},{'real','scalar','finite','integer','positive'});
        out.alias_request_source_file=r.input_request.source_file;out.alias_request_source_sha256=r.input_request.source_sha256;out.alias_request_source_row=r.input_request.source_alias_row;
    end
end

function historicalReference(r)
    exactFields(r,{'file','sha256'},'historical file/SHA locator');
    assert(((ischar(r.file)&&isrow(r.file)&&~isempty(r.file))||(isstring(r.file)&&isscalar(r.file)&&~ismissing(r.file)&&strlength(r.file)>0)) ...
        &&ischar(r.sha256)&&isrow(r.sha256)&&~isempty(regexp(r.sha256,'^[0-9a-f]{64}$','once')), ...
        'C1EssentialComplete:HistoricalReference','A historical locator requires literal scalar path text and lowercase SHA256; availability is not inferred.');
end

function classifierProjectionEqual(historical,retained)
    % Exact9f classifier contract: compare selected presence/order/leaves only.
    % Unselected original contact/display/sample trees are never copied.
    names={'contract_version','synchrony_predicate_version','label','alias','abbreviation','status','reason','validated_gait_type','canonical_point_label','canonical_label_qualified','suspension_reference_posture','primitive_flight_count','flight_count_certain','descriptive_only','isotropy_proved','period_used','flight_count','raw_positive_flight_count','flight_count_over_recorded_period','hind_pair_asymmetry','fore_pair_asymmetry','hind_pair_synchronized','front_pair_synchronized','fore_pair_synchronized','legacy_original_suffix_verified_flight_count','v3_abbreviation_suffix2_measured','displaylabel'};
    assert(isstruct(historical)&&isscalar(historical)&&isstruct(retained)&&isscalar(retained),'C1EssentialComplete:HistoricalClassifier','Both classifier projections must preserve scalar structure.');
    keys=fieldnames(historical);expected=keys(ismember(keys,names));
    for key={'contact_reconstruction','tolerances','borderline'},if isfield(historical,key{1}),expected{end+1,1}=key{1};end,end
    assert(isequal(fieldnames(retained),expected),'C1EssentialComplete:HistoricalClassifier','Retained classifier field presence and projection order must match the historical contract.');
    for k=1:numel(expected)
        key=expected{k};
        if strcmp(key,'contact_reconstruction')
            retainedSubsetEqual(historical.(key),retained.(key),{'complete','reason','initial_mode','final_mode','cohorts','event_time_tolerance','atomic_cohorts'},{},'historical contact projection');
        elseif strcmp(key,'tolerances')
            retainedSubsetEqual(historical.(key),retained.(key),{'ContactTolerance','MotionTolerance','AngleTolerance','RateTolerance','StanceRateTolerance','SyncFlowTolerance','ParameterTolerance','ApexTolerance','EventTimeTolerance','FlightDurationTolerance','ObservationRelTol','ObservationAbsTol','ObservationMaxStep','ObservationSafetyFactor','GeometryTolerance','SampleCount'},{'PrimitiveOptions'},'historical tolerance projection');
        else,rawEqual3(historical.(key),retained.(key),retained.(key),'historical retained classifier value');end
    end
end

function retainedSubsetEqual(historical,retained,names,tail,label)
    assert(isstruct(historical)&&isscalar(historical)&&isstruct(retained)&&isscalar(retained),'C1EssentialComplete:HistoricalClassifier','The %s must preserve scalar structure.',label);
    keys=fieldnames(historical);expected=keys(ismember(keys,names));for k=1:numel(tail),if isfield(historical,tail{k}),expected{end+1,1}=tail{k};end,end
    assert(isequal(fieldnames(retained),expected),'C1EssentialComplete:HistoricalClassifier','The %s must preserve every retained field and its literal missingness/order.',label);
    for k=1:numel(expected),key=expected{k};rawEqual3(historical.(key),retained.(key),retained.(key),label);end
end

function bindIDs(e,left,right)
    assert(strcmp(e.left_native_ID,left.native_id)&&strcmp(e.right_native_ID,right.native_id),'C1EssentialComplete:HistoricalID','Original qualifier IDs must match both literal actual endpoints.');
end

function out=identityRecord(r)
    o=r.orbit;out=struct('initial_state',o.initial_state,'initial_mode',o.initial_mode,'parameter',o.parameter,'period',o.period,'stride_displacement',o.stride_displacement,'return_policy_name',o.return_policy_name);
end

function checkAdmission(a,r,numerical)
    assert(isequal(a.all_nine_literal_true,true)&&isequal(a.accepted,true),'C1EssentialComplete:HistoricalAdmission','Original historical all-nine/accepted flags must remain true.');
    names={'full_closure','mode_closure','target_energy','trajectory_energy_variation','unscaled_family_equations','family_constraint','physical_inequalities','primitive_identity','replay_determinism'};
    assert(isfield(r.report,'acceptance_gates')&&all(cellfun(@(n)isfield(r.report.acceptance_gates,n)&&isequal(r.report.acceptance_gates.(n),true),names)), ...
        'C1EssentialComplete:HistoricalAdmission','Every literal retained root gate must agree with the existing historical qualification.');
    status='';if isfield(r.report,'status'),status=r.report.status;elseif isfield(r.report,'native_status'),status=r.report.native_status;end
    assert(isequaln(a.stored_status,status),'C1EssentialComplete:HistoricalAdmission','Original stored admission status must bind the actual retained report.');
    if numerical
        assert(r.policy.complete,'C1EssentialComplete:HistoricalPolicy','Numerical qualification requires the actual complete retained policy.');rawEqual3(a.policy_configuration,r.policy.configuration,r.policy.configuration,'numerical admission policy');
        classifierProjectionEqual(a.classification,r.report.classification);
    else
        g=r.report.classification;assert(strcmp(a.classification_contract,g.contract_version)&&strcmp(a.canonical_point_label,g.canonical_point_label)&&strcmp(a.validated_gait_type,g.validated_gait_type) ...
            &&isequaln(a.flight_count_certain,g.flight_count_certain)&&isequaln(a.flight_count,g.flight_count),'C1EssentialComplete:HistoricalClassifier','Alias scalar admission/classification facts must bind the actual retained classifier.');
    end
end

function checkMatching(m,left,right)
    assert(isequal(m.compatible,true)&&isequal(m.actual_policy_configuration_checked,true)&&isequal(m.policy_configuration_matches_declared_identity,true)&&isequal(m.rephase_or_chart_transition_inferred,false) ...
        &&isempty(m.left_missing_fields)&&isempty(m.right_missing_fields),'C1EssentialComplete:HistoricalSection','The known original MatchingReturnSection evidence must be complete and unchanged.');
    rawEqual3(m.left_identity,sectionIdentity(left),sectionIdentity(left),'historical left section');rawEqual3(m.right_identity,sectionIdentity(right),sectionIdentity(right),'historical right section');
    assert(left.policy.complete&&right.policy.complete,'C1EssentialComplete:HistoricalPolicy','Both actual retained policies must remain complete.');
    rawEqual3(m.left_policy_configuration,left.policy.configuration,left.policy.configuration,'historical left policy');rawEqual3(m.right_policy_configuration,right.policy.configuration,right.policy.configuration,'historical right policy');
end

function out=sectionIdentity(r)
    o=r.orbit;name=char(o.return_policy_name);assert(~isempty(name),'C1EssentialComplete:SectionName','A qualified known section cannot acquire a missing/fallback policy name.');
    out=struct('return_policy_name',name,'initial_mode',logical(o.initial_mode(:)),'section',struct(),'return_occurrence',1);
    keys={'id','geometry','crossing_orientation','boundary_ownership','translational_gauge'};
    for k=1:numel(keys),assert(isfield(o.section_chart,keys{k}),'C1EssentialComplete:Section','A known qualified section field is missing.');out.section.(keys{k})=o.section_chart.(keys{k});end
    if ismember(name,{'BL-marked-apex-return','BLMarkedApexReturnPolicy_v3'}),out.return_occurrence=o.section_chart.BL_touchdowns_per_return;
    elseif ismember(name,{'iterated-section-return','IteratedReturnPolicy_v3'}),out.return_occurrence=o.return_multiplicity;end
end

function out=matchingScalars(m)
    out=struct('matching_section_compatible',m.compatible,'actual_policy_configuration_checked',m.actual_policy_configuration_checked, ...
        'policy_configuration_matches_declared_identity',m.policy_configuration_matches_declared_identity,'rephase_or_chart_transition_inferred',m.rephase_or_chart_transition_inferred);
end

function out=pickScalars(value,names)
    requiredFields(value,names,'known scalar evidence');out=struct();for k=1:numel(names),out.(names{k})=value.(names{k});end
end

function out=mergeScalars(out,extra)
    for key=fieldnames(extra).',assert(~isfield(out,key{1}),'C1EssentialComplete:EvidenceCollision','Essential scalar evidence fields must be distinct.');out.(key{1})=extra.(key{1});end
end

function exactFields(value,names,label)
    assert(isstruct(value)&&isscalar(value)&&isequal(sort(fieldnames(value)),sort(names(:))),'C1EssentialComplete:KnownSchema','Use the exact source-backed %s fieldset; unknown qualifications refuse.',label);
end

function requiredFields(value,names,label)
    assert(isstruct(value)&&isscalar(value)&&all(isfield(value,names)),'C1EssentialComplete:RequiredEvidence','The known %s is missing required actual fields.',label);
end
function out=ref2(r),out=struct('file',canonical(r.file),'sha256',r.sha256);end

function rawEqual3(expected,a,b,where)
    assert(strcmp(class(expected),class(a))&&strcmp(class(expected),class(b))&&isequal(size(expected),size(a),size(b)),'C1PackedPilot:ExactType','Type/shape changed at %s.',where);
    if isnumeric(expected)
        assert(isequal(isreal(expected),isreal(a),isreal(b)),'C1PackedPilot:ExactRealness','Numeric realness changed at %s.',where);
        assert(isequal(typecast(real(expected(:)),'uint8'),typecast(real(a(:)),'uint8'),typecast(real(b(:)),'uint8')),'C1PackedPilot:ExactBytes','Real numeric raw bytes changed at %s.',where);
        if ~isreal(expected),assert(isequal(typecast(imag(expected(:)),'uint8'),typecast(imag(a(:)),'uint8'),typecast(imag(b(:)),'uint8')),'C1PackedPilot:ExactBytes','Imaginary raw bytes changed at %s.',where);end
    elseif islogical(expected)||ischar(expected)
        assert(isequal(expected,a,b),'C1PackedPilot:ExactValue','Literal values changed at %s.',where);
    elseif isstring(expected)
        assert(isequaln(expected,a,b),'C1PackedPilot:ExactString','Literal strings/missingness changed at %s.',where);
    elseif iscell(expected)
        for k=1:numel(expected),rawEqual3(expected{k},a{k},b{k},sprintf('%s{%d}',where,k));end
    elseif isstruct(expected)
        f=fieldnames(expected);assert(isequal(f,fieldnames(a),fieldnames(b)),'C1PackedPilot:ExactFields','Field names/order changed at %s.',where);
        for k=1:numel(expected),for j=1:numel(f),rawEqual3(expected(k).(f{j}),a(k).(f{j}),b(k).(f{j}),[where,'.',f{j}]);end,end
    else
        error('C1PackedPilot:ExactClass','Unsupported projection class %s at %s.',class(expected),where);
    end
end
