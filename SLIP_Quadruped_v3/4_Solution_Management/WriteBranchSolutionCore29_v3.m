function receipt=WriteBranchSolutionCore29_v3(sourceReference,componentPointIndex,outputFile,originalV2Reference,options)
%WRITEBRANCHSOLUTIONCORE29_V3 Transport one frozen raw storage component.
% Components use P+E+A+M connectivity. The four relation kinds stay distinct;
% no imported seed edge, identity, qualification or scientific result is added.
% The source audit/closure are opaque caller-supplied provenance, not a
% certificate verified here. Full native source records remain authoritative.
% The unchanged loader currently supports complete recorded BL apex policies.
    entered=clockPair();required={'Budget','MaxWallSeconds','SaveMarginSeconds', ...
        'SourceAuditReference','SourceClosureReference','AuditFile'};
    assert(isstruct(options)&&isscalar(options),'BranchCore29:Options','Use scalar explicit options.');
    working=isfield(options,'WorkingStorage');allowed=required;
    if working,allowed{end+1}='WorkingStorage';end
    assert(isequal(sort(fieldnames(options)),sort(allowed(:))), ...
        'BranchCore29:Options','Supply the fixed options, optionally with one explicit WorkingStorage policy.');
    workingPolicy=[];workingReader=[];
    if working
        workingPolicy=options.WorkingStorage;
        assert(isstruct(workingPolicy)&&isscalar(workingPolicy) ...
            &&isequal(sort(fieldnames(workingPolicy)),{'MaximumFileBytes';'Reason'}) ...
            &&ischar(workingPolicy.Reason)&&isrow(workingPolicy.Reason)&&~isempty(strtrim(workingPolicy.Reason)), ...
            'BranchCore29:WorkingPolicy','Declare an explicit necessary-data ceiling and reason.');
        validateattributes(workingPolicy.MaximumFileBytes,{'double'},{'real','scalar','finite','integer','positive','<=',flintmax});
    end
    b=options.Budget;validateattributes(options.MaxWallSeconds,{'double'},{'real','finite','scalar','positive'});
    validateattributes(options.SaveMarginSeconds,{'double'},{'real','finite','scalar','positive','<',options.MaxWallSeconds});
    assert(isstruct(b)&&isscalar(b)&&all(isfield(b,{'deadline_unix_seconds','deadline_monotonic_ns'})), ...
        'BranchCore29:Budget','Use the original UTC and monotonic publication deadlines.');
    outer=struct('utc',b.deadline_unix_seconds,'mono',b.deadline_monotonic_ns);
    assert(left(outer)>options.MaxWallSeconds+2,'BranchCore29:WholeFit','The complete declared export cap must fit the original clocks.');
    finish=struct('utc',min(outer.utc,entered.utc+options.MaxWallSeconds), ...
        'mono',min(outer.mono,entered.mono+options.MaxWallSeconds*1e9));
    work=struct('utc',finish.utc-options.SaveMarginSeconds,'mono',finish.mono-options.SaveMarginSeconds*1e9);
    sourceReference=checked(sourceReference);originalV2Reference=checked(originalV2Reference);
    sourceAudit=checked(options.SourceAuditReference);sourceClosure=checked(options.SourceClosureReference);
    outputFile=literalPath(outputFile);auditFile=literalPath(options.AuditFile);
    stage=[outputFile,'.pending.mat'];auditStage=[auditFile,'.pending.mat'];
    paths={outputFile;stage;auditFile;auditStage};
    for k=1:numel(paths)
        [~,~,ext]=fileparts(paths{k});assert(strcmp(ext,'.mat')&&isfolder(fileparts(paths{k})), ...
            'BranchCore29:Path','Fresh MAT paths require existing parent directories.');
    end
    refs={sourceReference;originalV2Reference;sourceAudit;sourceClosure};
    assert(numel(unique(paths))==4&&~any(ismember(paths,cellfun(@(r)r.file,refs,'UniformOutput',false))), ...
        'BranchCore29:Additive','All output/stage paths must be distinct and separate from inputs.');fresh(paths);
    [runtime,environment,codes]=methodsAndEnvironment();
    if working
        method=which('LoadC1WorkingSolutionCore29_v3');
        assert(~isempty(method),'BranchCore29:WorkingReader','Install the explicit working reader before export.');
        workingReader=checked(struct('file',method,'sha256',RoundSHA256_v3(method)));codes{end+1,1}=workingReader;
    end
    refs=[refs;codes];
    original=dir(originalV2Reference.file);assert(isscalar(original)&&original.bytes>0&&original.bytes<=flintmax/5, ...
        'BranchCore29:OriginalV2','Bind the whole original v2 file bytes.');cap=5*original.bytes;
    if working
        assert(workingPolicy.MaximumFileBytes>=cap,'BranchCore29:WorkingCeiling','Retain the original strict target and declare a sufficient working ceiling.');
    end
    producer=checked(struct('file',[mfilename('fullpath'),'.m'],'sha256',RoundSHA256_v3([mfilename('fullpath'),'.m'])));
    receipt=struct('schema','C1-raw-branch-core29-export-v1','completed',false,'source_reference',sourceReference, ...
        'source_audit_reference',sourceAudit,'source_closure_reference',sourceClosure, ...
        'external_source_process_exit_verified_by_this_writer',false,'own_process_exit_observed',false, ...
        'source_provenance_scope','Opaque hash-bound caller-supplied historical authorities; caller owns external exit/pending reconciliation.', ...
        'output_file',outputFile,'stage_file',stage,'audit_file',auditFile,'producer_reference',producer, ...
        'component_point_selector',componentPointIndex,'source_point_count',0,'point_count',0, ...
        'source_indices',zeros(0,1),'occurrence_map',zeros(0,2),'connectivity',struct(), ...
        'source_index_digest','','source_point_metadata',{{}},'source_index_orders',[], ...
        'metadata_transport',{{}},'all_bulk_reads',0,'retained_projection_read2',false, ...
        'native_reconstructions',0,'all_native_ids_and_policies_verified',false, ...
        'source_posthash',false,'stage_save_returned',false,'stage_native_read2',false, ...
        'publication_returned',false,'installed_native_read2',false,'loader_smoke_returned',false, ...
        'original_v2_reference',originalV2Reference,'original_v2_bytes',original.bytes, ...
        'maximum_core_bytes',cap,'core_bytes',[],'core_sha256','','failure',struct(), ...
        'new_admission_claimed',false,'aggregate_storage_reduction_claimed',false, ...
        'working_storage_enabled',working,'working_storage_policy',workingPolicy, ...
        'working_reader_reference',workingReader,'strict_target_met',false);
    if working,receipt.schema='C1-necessary-data-working-core29-export-v1';end
    try
        guard(work,refs);view=C1StoredComponentSource_v3.prepare(sourceReference);
        ix=C1StoredComponentSource_v3.index(view);refs=[refs;view.input_references];codes=[codes;view.recipe_references];
        receipt.source_kind=view.kind;receipt.source_plan_scope=view.plan_scope;
        receipt.actual_public_bulk_calls=0;receipt.source_passes_completed=0;
        receipt.maximum_native_bulk_records=0;receipt.source_acquisition_groups=cell(2,1);
        receipt.native_cache_shared_across_passes=false;receipt.independence_handle_witness_records=1;
        receipt.new_full_trajectory_materialization_claimed=false;
        receipt.source_order_transport_scope='Input point.order remains literal (global plan order for a composite source); physical edge_from is mapped to chosen-component local indices; context.source_index is the global source selector and expected_index is the local output ordinal.';
        receipt.source_point_count=numel(ix.points);receipt.source_index_digest=digest(ix);
        validateattributes(componentPointIndex,{'double'},{'real','finite','scalar','integer','positive','<=',numel(ix.points)});
        graphSource=sourceGraph(ix);bins=componentBins(graphSource.pairs,numel(ix.points),4);
        selected=find(bins==bins(componentPointIndex)).';selected=selected(:);N=numel(selected);
        map=zeros(numel(ix.points),1);map(selected)=1:N;
        receipt.source_indices=selected;receipt.point_count=N;receipt.occurrence_map=[selected,(1:N).'];
        receipt.connectivity=connectivity(graphSource.pairs,numel(ix.points),selected);
        receipt.source_graph_snapshot=graphSource;receipt.source_point_metadata=cell(N,1);
        receipt.source_index_orders=zeros(N,1);receipt.metadata_transport=cell(N,1);
        closure=struct('schema','C1-raw-branch-core29-declared-provenance-v1','source_reference',sourceReference, ...
            'external_closure_reference',sourceClosure,'external_exit_verified_by_this_writer',false, ...
            'scope','Historical caller-supplied source provenance only; this is not a fresh scientific qualification certificate.');
        c=emptyCore(N,sourceReference,sourceAudit,sourceClosure,closure,originalV2Reference,original.bytes,cap,runtime,environment,producer);
        if strcmp(view.kind,'composite-graph-plan')
            if working,receipt.schema='C1-composite-source-working-core29-export-v1';
            else,receipt.schema='C1-composite-source-core29-export-v1';end
            c.historical_audit_scope=['Exact retained projection of original stored occurrences through a graph-only selector plan. ', ...
                'Both failed raw-copy attempts remain historical failures. No aggregate full-trajectory file/readback or new admission is claimed. ', ...
                'Complete policy/section and required primitive/classifier heads remain literal; full original records stay authoritative.'];
        end
        kept=[];
        for pass=1:2
            guard(work,refs);groups=C1StoredComponentSource_v3.groups(view,selected);coverage=false(N,1);
            receipt.source_acquisition_groups{pass}=groups;
            for bulk=1:numel(groups)
                group=groups{bulk};check(work);
                fprintf('C1_BRANCH_CORE29_BEFORE_SOURCE_LOAD pass=%d group=%d/%d records=%d\n',pass,bulk,numel(groups),numel(group.positions));
                [orbits,reports,metadata]=C1StoredComponentSource_v3.load(view,group.indices);
                receipt.actual_public_bulk_calls=receipt.actual_public_bulk_calls+1;
                receipt.all_bulk_reads=receipt.actual_public_bulk_calls;
                receipt.maximum_native_bulk_records=max(receipt.maximum_native_bulk_records,numel(group.positions));
                fprintf('C1_BRANCH_CORE29_AFTER_SOURCE_LOAD_RETURN pass=%d group=%d/%d\n',pass,bulk,numel(groups));
                count=numel(group.positions);
                assert(isequal(size(orbits),[count,1])&&isequal(size(reports),[count,1])&&isequal(size(metadata),[count,1]), ...
                    'BranchCore29:Rows','Independent public source-group acquisitions must retain requested ordered column cells.');
                first=find(group.positions==1);
                if pass==2&&~isempty(first)
                    assert(isscalar(first)&&~(kept==orbits{first}),'BranchCore29:IndependentHandles','Use independently deserialized native records.');
                end
                for within=1:count
                    k=group.positions(within);check(work);sourceIndex=selected(k);point=ix.points{sourceIndex};same(metadata{within},point.metadata);
                    [entry,transport]=makeEntry(orbits{within},reports{within},metadata{within},point,k,sourceIndex,map,sourceReference);
                    verifyEntry(entry,orbits{within},reports{within},metadata{within},point,k,sourceIndex,map,sourceReference);
                    if pass==1
                        c=putEntry(c,k,entry);receipt.source_point_metadata{k}=metadata{within};
                        receipt.source_index_orders(k)=point.order;receipt.metadata_transport{k}=transport;
                    else,same(entry,getEntry(c,k));same(transport,receipt.metadata_transport{k});end
                    receipt.native_reconstructions=receipt.native_reconstructions+1;
                end
                assert(~any(coverage(group.positions)),'BranchCore29:Coverage','A source pass repeated occurrence positions.');coverage(group.positions)=true;
                if pass==1&&~isempty(first),kept=orbits{first};end
                clear orbits reports metadata entry
            end
            assert(all(coverage),'BranchCore29:Coverage','A source pass omitted occurrence positions.');
            receipt.source_passes_completed=pass;guard(work,refs);
        end
        clear kept
        receipt.retained_projection_read2=true;receipt.all_native_ids_and_policies_verified=true;
        c.graph=transportGraph(graphSource,ix,selected,map,c.native_ids,sourceReference,codes);
        receipt.typed_graph_counts=graphCounts(c.graph);receipt.typed_graph_digest=digest(c.graph);
        core_digest=digest(c);solution_core29=c;clear c
        working_storage=[];working_storage_digest='';
        if working
            working_storage=struct('schema','C1-necessary-data-working-core29-v1','core_digest',core_digest, ...
                'maximum_file_bytes',workingPolicy.MaximumFileBytes,'strict_target_bytes',cap,'reason',workingPolicy.Reason, ...
                'reader_method',struct('name','LoadC1WorkingSolutionCore29_v3','sha256',workingReader.sha256), ...
                'scope','Necessary complete-data working storage; the original strict5x target is unchanged. No new admission, branch completion or publication-size success is claimed.');
            working_storage_digest=digest(working_storage);
        end
        observed=whos('solution_core29');assert(observed.bytes<1750000000,'BranchCore29:Headroom','Observed v7 headroom requires a larger service design; no silent omission.');
        guard(work,refs);fresh(paths);fprintf('C1_BRANCH_CORE29_BEFORE_STAGE_SAVE\n');
        if working,save(stage,'solution_core29','core_digest','working_storage','working_storage_digest','-v7');
        else,save(stage,'solution_core29','core_digest','-v7');end
        receipt.stage_save_returned=true;
        fprintf('C1_BRANCH_CORE29_AFTER_STAGE_SAVE_RETURN\n');
        info=dir(stage);receipt.core_bytes=info.bytes;receipt.core_sha256=RoundSHA256_v3(stage);
        receipt.strict_target_met=info.bytes<=cap;
        if working
            assert(info.bytes<=workingPolicy.MaximumFileBytes,'BranchCore29:WorkingCeiling','Complete necessary data exceed the declared working ceiling; retain stage.');
        else
            assert(info.bytes<=cap,'BranchCore29:FiveTimes','Measured whole core exceeds the existing loader cap. Retain stage; do not split a connected component or drop required data to fit.');
        end
        verifyCoreReads(stage,solution_core29,core_digest,working_storage,working_storage_digest);receipt.stage_native_read2=true;
        if working,[o,~,p]=LoadC1WorkingSolutionCore29_v3(stage,1,receipt.core_sha256);
        else,[o,~,p]=LoadC1SolutionCore29_v3(stage,1,receipt.core_sha256);end
        assert(strcmp(OrbitContentIdentity_v3(o),p.native_id),'BranchCore29:Loader','Actual selected loader identity differs.');clear o p
        receipt.loader_smoke_returned=true;guard(finish,refs);fresh({outputFile});
        assert(strcmp(RoundSHA256_v3(stage),receipt.core_sha256),'BranchCore29:StageChanged','Only the verified stage may be published.');
        javaMethod('createLink','java.nio.file.Files',java.io.File(outputFile).toPath(),java.io.File(stage).toPath());
        receipt.publication_returned=true;
        assert(javaMethod('isSameFile','java.nio.file.Files',java.io.File(outputFile).toPath(),java.io.File(stage).toPath()), ...
            'BranchCore29:PublicationIdentity','Published output must identify the owned stage.');
        javaMethod('delete','java.nio.file.Files',java.io.File(stage).toPath());
        verifyCoreReads(outputFile,solution_core29,core_digest,working_storage,working_storage_digest);receipt.installed_native_read2=true;
        guard(finish,refs);assert(strcmp(RoundSHA256_v3(outputFile),receipt.core_sha256),'BranchCore29:OutputChanged','Published core bytes changed.');
        receipt.source_posthash=true;receipt.completed=true;
    catch problem
        receipt.completed=false;receipt.failure=struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack);
    end
    returned=clockPair();receipt.elapsed_before_audit_seconds=(returned.mono-entered.mono)/1e9;
    receipt.projection_contract='Literal state14/stride14/T/p/q, NativeIDs, full policy and section, all11 orbit evidence names (primitive/classifier heads16/15), original accepted/status/full closure/all gates, and full four typed graph tables/evidence. Original point metadata/index orders stay in this audit; only declared owner/order/physical predecessor bookkeeping enters the core. Trajectory, solver/diagnostic histories and contact/cohort detail remain in the full frozen source. No full-source-object losslessness or fresh admission claim.';
    receipt.completion_scope='Core transport checks before receipt publication; actual audit-publication/deadline return is checked separately.';
    receipt.completed=receipt.completed&&left(finish)>0;
    fresh({auditFile;auditStage});save(auditStage,'receipt','-v7');data=load(auditStage,'receipt');same(receipt,data.receipt);
    javaMethod('createLink','java.nio.file.Files',java.io.File(auditFile).toPath(),java.io.File(auditStage).toPath());
    javaMethod('delete','java.nio.file.Files',java.io.File(auditStage).toPath());
    receipt.audit_publication_returned=true;
    returned=clockPair();receipt.elapsed_seconds=(returned.mono-entered.mono)/1e9;
    receipt.final_return_timely=left(finish)>0;receipt.completed=receipt.completed&&receipt.final_return_timely;
    summary=struct('completed',receipt.completed,'point_count',receipt.point_count,'core_bytes',receipt.core_bytes, ...
        'maximum_core_bytes',cap,'working_storage_enabled',working,'strict_target_met',receipt.strict_target_met, ...
        'output_file',outputFile,'audit_file',auditFile,'publication_returned',receipt.publication_returned, ...
        'source_posthash',receipt.source_posthash,'audit_publication_returned',true,'final_return_timely',receipt.final_return_timely, ...
        'new_admission_claimed',false,'failure',failureHeader(receipt.failure));
    fprintf('C1_BRANCH_CORE29_ACTUAL_RETURN %s\n',jsonencode(summary));
    assert(receipt.completed,'BranchCore29:Incomplete','Transport audit retained; source and any failed stage remain authoritative.');
end

function c=emptyCore(N,source,audit,qualification,closure,v2,v2bytes,cap,runtime,environment,producer)
    rows=cell(N,1);c=struct('schema','C1-self-contained-solution-core29-v1', ...
        'layout','rows1:14=initial_state;15:28=full_stride;29=period; columns=stored occurrences', ...
        'point_count',N,'solution_matrix',zeros(29,N),'parameters',{rows},'modes',{rows},'native_ids',{rows}, ...
        'point_metadata',{rows},'contexts',{rows},'policies',{rows},'section_charts',{rows},'orbit_evidence',{rows}, ...
        'saved_reports',{rows},'native_energy',zeros(1,N),'signed_mean_U',zeros(1,N),'graph',struct(), ...
        'source_projection_digests',{rows},'source_reference',source,'qualification_reference',qualification, ...
        'qualification_closure',closure,'writer_audit_reference',audit,'original_v2_reference',v2, ...
        'original_v2_bytes',v2bytes,'maximum_core_bytes',cap,'runtime_methods',{runtime}, ...
        'runtime_environment',environment,'producer_reference',producer, ...
        'historical_audit_scope','Raw branch transport, not K60 qualification. Source audit/closure are opaque caller-provided provenance. Saved decisions and projected primitive/classifier heads are historical; dense trajectories, solver histories and detailed contact/cohort audits stay in the full source. source_projection_digests bind the declared source load/plot/replay projection, not full historical source objects or this new core. Complete core_digest binds this file. No own-process-exit, new classification or admission claim.', ...
        'replay_scope','Trajectory-free seed with literal parameters/modes and complete recorded BL policy/section. Fresh explicitly declared integration/acceptance/deadlines are required for replay.');
end

function [e,transport]=makeEntry(o,r,m,point,k,sourceIndex,map,source)
    assert(isa(o.initial_state,'double')&&isreal(o.initial_state)&&~issparse(o.initial_state)&&isequal(size(o.initial_state),[14,1]) ...
        &&isa(o.stride_displacement,'double')&&isreal(o.stride_displacement)&&~issparse(o.stride_displacement)&&isequal(size(o.stride_displacement),[14,1]) ...
        &&isa(o.period,'double')&&isreal(o.period)&&~issparse(o.period)&&isscalar(o.period)&&o.period>0 ...
        &&all(isfinite([o.initial_state;o.stride_displacement;o.period])), ...
        'BranchCore29:Matrix','Refuse conversion: literal dense double14-state/14-stride/positive-period are required.');
    [~,policy]=RecordedReturnPolicy_v3(r);assert(policy.complete&&strcmp(policy.configuration.source_class,'BLMarkedApexReturnPolicy_v3'), ...
        'BranchCore29:Policy','Every record requires the actual complete known BL policy, without defaults.');
    chart=o.section_chart;assert(isstruct(chart)&&isscalar(chart)&&all(isfield(chart, ...
        {'id','geometry','crossing_orientation','boundary_ownership','translational_gauge','BL_touchdowns_per_return'})), ...
        'BranchCore29:Section','Retain the full recorded section chart.');
    assert(isa(point.order,'double')&&isscalar(point.order)&&isfinite(point.order)&&point.order>0 ...
        &&ischar(m.component_identity)&&strcmp(m.component_identity,point.component_identity), ...
        'BranchCore29:Bookkeeping','Use the actual stored index owner/order; refuse bookkeeping conversion.');
    meta=pick(m,{'component_identity','order','edge_enabled','edge_from'});added=cell(0,1);
    if ~isfield(meta,'order'),meta.order=point.order;added={'order'};else,same(meta.order,point.order);end
    if isfield(meta,'edge_from')&&~isempty(meta.edge_from)
        assert(meta.edge_enabled&&map(meta.edge_from)>0,'BranchCore29:Parent','A selected component must retain every physical parent.');
        meta.edge_from=map(meta.edge_from);
    end
    [primitive,classifier]=heads();saved=pick(r,{'schema_version','status','native_status','accepted','full_closure','full_closure_residual','acceptance_gates','classification','primitive'});
    for name={'classification','primitive'}
        key=name{1};if isfield(saved,key)
            if strcmp(key,'classification'),saved.(key)=head(saved.(key),classifier);else,saved.(key)=head(saved.(key),primitive);end
        end
    end
    evidence=struct();keys=evidenceNames();
    for j=1:numel(keys),evidence.(keys{j})=o.(keys{j});end
    evidence.primitive_cycle=head(evidence.primitive_cycle,primitive);evidence.gait_identification=head(evidence.gait_identification,classifier);
    id=OrbitContentIdentity_v3(o);context=struct('role','raw-stored-occurrence','occurrence_id',sprintf('source-sha256:%s:index:%d',source.sha256,sourceIndex), ...
        'source_reference',source,'source_index',sourceIndex,'expected_index',k,'native_id',id);
    original=struct('state',o.initial_state,'mode',o.initial_mode,'parameter',o.parameter,'period',o.period,'stride',o.stride_displacement, ...
        'native_id',id,'original_point_metadata',m,'source_index_order',point.order,'policy',policy,'section_chart',chart,'orbit_evidence',evidence,'saved_report',saved);
    e=struct('matrix',[o.initial_state;o.stride_displacement;o.period],'parameter',o.parameter,'mode',o.initial_mode, ...
        'native_id',id,'metadata',meta,'context',context,'policy',policy,'chart',chart,'evidence',evidence,'report',saved, ...
        'energy',QuadrupedEnergy_v3.evaluate(o.initial_state,o.initial_mode,o.parameter), ...
        'mean_U',o.stride_displacement(1)/o.period,'source_digest',digest(original));
    transport=struct('source_index',sourceIndex,'target_index',k,'added_metadata_fields',{added}, ...
        'source_index_order',point.order,'edge_from_remapped',isfield(m,'edge_from')&&~isempty(m.edge_from));
    verifyReconstruction(e);
end

function verifyEntry(e,o,r,m,point,k,sourceIndex,map,source)
    same(e.matrix(1:14),o.initial_state);same(e.matrix(15:28),o.stride_displacement);same(e.matrix(29),o.period);
    same(e.parameter,o.parameter);same(e.mode,o.initial_mode);same(e.chart,o.section_chart);
    names=fieldnames(m);names=names(ismember(names,{'component_identity','order','edge_enabled','edge_from'}));
    if ~ismember('order',names),names{end+1,1}='order';end
    same(fieldnames(e.metadata),names);
    for name=names.'
        key=name{1};if strcmp(key,'order'),same(e.metadata.(key),point.order);
        elseif strcmp(key,'edge_from')&&~isempty(m.edge_from),same(e.metadata.edge_from,map(m.edge_from));
        else,same(e.metadata.(key),m.(key));end
    end
    same(e.context.source_reference,source);same(e.context.source_index,sourceIndex);same(e.context.expected_index,k);
    [~,p]=RecordedReturnPolicy_v3(r);same(e.policy,p);
    [primitive,classifier]=heads();verifyHead(e.report,r,{'schema_version','status','native_status','accepted','full_closure','full_closure_residual','acceptance_gates','classification','primitive'},primitive,classifier);
    keys=evidenceNames();assert(isequal(fieldnames(e.evidence),keys(:)),'BranchCore29:EvidenceFields','Retain all11 declared orbit evidence properties.');
    for j=1:numel(keys)
        key=keys{j};if strcmp(key,'primitive_cycle'),verifyHead(e.evidence.(key),o.(key),primitive,{},{});
        elseif strcmp(key,'gait_identification'),verifyHead(e.evidence.(key),o.(key),classifier,{},{});
        else,same(e.evidence.(key),o.(key));end
    end
    assert(strcmp(e.native_id,OrbitContentIdentity_v3(o)),'BranchCore29:SourceID','Actual source NativeID changed.');
end

function g=sourceGraph(ix)
    names={'physical_edges','record_equalities','qualified_aliases','numerical_seams'};
    pairs=cell(4,1);evidence=cell(4,1);pairs{1}=zeros(numel(ix.edges),2);evidence{1}=ix.edges;
    for k=1:numel(ix.edges),pairs{1}(k,:)=[ix.edges{k}.from,ix.edges{k}.to];end
    for k=2:4,pairs{k}=zeros(0,2);evidence{k}=cell(0,1);end
    if isfield(ix.metadata,'component_graph')
        s=ix.metadata.component_graph;
        legacy={'schema','nodes','original_explicit_edges','exact_record_equalities','qualified_record_aliases','qualified_alias_evidence','effective_edges','equality_evidence','connected','isolated_record_catalogue','equality_links_are_continuation_edges','qualified_aliases_are_exact_record_equalities','qualified_aliases_are_continuation_edges'};
        modern={'qualified_numerical_overlaps','numerical_overlap_evidence','strict_trace_scope','numerical_storage_scope','numerical_adjacencies_are_identity_quotients','numerical_adjacencies_are_physical_edges'};
        assert(isstruct(s)&&isscalar(s),'BranchCore29:Graph','Unknown non-scalar graph metadata refuses.');
        if isequal(sort(fieldnames(s)),sort(legacy(:))),count=2;
        elseif isequal(sort(fieldnames(s)),sort([legacy(:);modern(:)])),count=3;
        else,error('BranchCore29:GraphSchema','Only the actual known Consolidate graph schemas are supported.');end
        assert(strcmp(s.schema,'C1-connected-component-graph-v1')&&isequal(s.equality_links_are_continuation_edges,false) ...
            &&isequal(s.qualified_aliases_are_exact_record_equalities,false)&&isequal(s.qualified_aliases_are_continuation_edges,false), ...
            'BranchCore29:GraphKinds','Stored exact/alias relations must retain nonphysical semantics.');
        if count==3,assert(isequal(s.numerical_adjacencies_are_identity_quotients,false)&&isequal(s.numerical_adjacencies_are_physical_edges,false), ...
                'BranchCore29:NumericalKinds','Numerical seams are neither identities nor physical edges.');end
        validateattributes(s.nodes,{'numeric'},{'real','finite','scalar','integer','positive','<=',numel(ix.points)});
        old={'exact_record_equalities','qualified_record_aliases','qualified_numerical_overlaps'};
        ev={'equality_evidence','qualified_alias_evidence','numerical_overlap_evidence'};snapshot=s.original_explicit_edges;
        assert(isnumeric(snapshot)&&isreal(snapshot)&&ismatrix(snapshot)&&size(snapshot,2)==2 ...
            &&all(isfinite(snapshot(:)))&&all(snapshot(:)==fix(snapshot(:))) ...
            &&all(snapshot(:)>=1)&&all(snapshot(:)<=s.nodes)&&all(snapshot(:,1)<snapshot(:,2)), ...
            'BranchCore29:PhysicalSnapshot','The original physical snapshot must retain bounded oriented source indices.');
        assert(all(ismember(snapshot,pairs{1},'rows')),'BranchCore29:PhysicalSnapshotChanged','Every original physical snapshot edge must still exist in the current index.');
        for k=1:count
            pairs{k+1}=s.(old{k});evidence{k+1}=s.(ev{k});snapshot=[snapshot;pairs{k+1}]; %#ok<AGROW>
            assert(all(pairs{k+1}(:)<=s.nodes),'BranchCore29:RelationSnapshot','Frozen nonphysical endpoints must stay inside their original snapshot.');
            assert(iscell(evidence{k+1})&&numel(evidence{k+1})==size(pairs{k+1},1),'BranchCore29:GraphEvidence','Every relation requires its retained evidence row.');
        end
        same(snapshot,s.effective_edges);
    end
    for k=1:4
        p=pairs{k};assert(isnumeric(p)&&isreal(p)&&ismatrix(p)&&size(p,2)==2&&all(isfinite(p(:))) ...
            &&all(p(:)==fix(p(:)))&&all(p(:)>=1)&&all(p(:)<=numel(ix.points))&&all(p(:,1)~=p(:,2)), ...
            'BranchCore29:GraphBounds','Every typed relation endpoint must bind a real source occurrence.');
    end
    g=struct('names',{names},'pairs',{pairs},'evidence',{evidence});
end

function g=transportGraph(s,ix,selected,map,ids,source,codes)
    rows=cell(4,1);
    for kind=1:4
        rows{kind}=cell(0,1);p=s.pairs{kind};
        for j=1:size(p,1)
            a=p(j,1);b=p(j,2);if map(a)==0&&map(b)==0,continue;end
            assert(map(a)>0&&map(b)>0,'BranchCore29:ComponentCut','A selected all-layer component cannot cut a stored relation.');
            if kind==1
                e=struct('from',map(a),'to',map(b),'component_identity',ix.edges{j}.component_identity, ...
                    'source_reference',source,'source_from',a,'source_to',b,'original_edge',ix.edges{j});
            else
                evidence=s.evidence{kind}{j};
                assert(isstruct(evidence)&&isscalar(evidence),'BranchCore29:RelationEvidenceShape','Transport only the actual scalar qualified relation evidence.');
                if kind==2
                    assert(isfield(evidence,'native_ID')&&strcmp(evidence.native_ID,ids{map(a)})&&strcmp(evidence.native_ID,ids{map(b)}), ...
                        'BranchCore29:EqualityID','Original exact-equality evidence must bind both actual source NativeIDs.');
                else
                    assert(all(isfield(evidence,{'qualified','left_native_ID','right_native_ID'}))&&isequal(evidence.qualified,true) ...
                        &&strcmp(evidence.left_native_ID,ids{map(a)})&&strcmp(evidence.right_native_ID,ids{map(b)}), ...
                        'BranchCore29:RelationID','Retained alias/numerical evidence must bind actual endpoint NativeIDs.');
                end
                e=struct('from',map(a),'to',map(b),'from_native_id',ids{map(a)},'to_native_id',ids{map(b)}, ...
                    'receipt_reference',source,'evidence',evidence);
            end
            rows{kind}{end+1,1}=e;
        end
    end
    assert(numel(selected)==numel(ids),'BranchCore29:GraphCount','Graph occurrence map must bind every selected NativeID.');
    g=struct('schema','C1-essential-branch-graph-v1','role','raw-branch-component-transport', ...
        'displayname','Stored all-layer component; relation kinds remain distinct', ...
        'physical_edges',{rows{1}},'record_equalities',{rows{2}},'qualified_aliases',{rows{3}}, ...
        'numerical_seams',{rows{4}},'source_versions',{codes});
end

function bins=componentBins(pairs,N,last)
    edges=zeros(0,2);for k=1:last,edges=[edges;pairs{k}];end %#ok<AGROW>
    bins=conncomp(graph(edges(:,1),edges(:,2),[],N));
end
function out=connectivity(pairs,N,selected)
    labels={'physical','physical_plus_exact','physical_plus_exact_plus_alias','all_layers'};out=struct();
    for k=1:4
        bins=componentBins(pairs,N,k);out.(labels{k})=struct('source_component_count',numel(unique(bins)), ...
            'selected_component_count',numel(unique(bins(selected))));
    end
    out.scope='Undirected storage connectivity only. Physical edge orientation is retained; reverse Run execution is not authorized. Aliases and numerical seams are not physical/exact identity.';
end
function out=graphCounts(g)
    out=struct();for name={'physical_edges','record_equalities','qualified_aliases','numerical_seams'},out.(name{1})=numel(g.(name{1}));end
end
function c=putEntry(c,k,e)
    c.solution_matrix(:,k)=e.matrix;c.parameters{k}=e.parameter;c.modes{k}=e.mode;c.native_ids{k}=e.native_id;
    c.point_metadata{k}=e.metadata;c.contexts{k}=e.context;c.policies{k}=e.policy;c.section_charts{k}=e.chart;
    c.orbit_evidence{k}=e.evidence;c.saved_reports{k}=e.report;c.native_energy(k)=e.energy;c.signed_mean_U(k)=e.mean_U;c.source_projection_digests{k}=e.source_digest;
end
function e=getEntry(c,k)
    e=struct('matrix',c.solution_matrix(:,k),'parameter',c.parameters{k},'mode',c.modes{k},'native_id',c.native_ids{k}, ...
        'metadata',c.point_metadata{k},'context',c.contexts{k},'policy',c.policies{k},'chart',c.section_charts{k}, ...
        'evidence',c.orbit_evidence{k},'report',c.saved_reports{k},'energy',c.native_energy(k),'mean_U',c.signed_mean_U(k),'source_digest',c.source_projection_digests{k});
end
function [p,g]=heads()
    p={'status','reason','recorded_period','primitive_period','cover_count','drift','primitive_drift','closure_error','mode_closed','checked_cover_bound','state_tolerance','event_phase_tolerance','evidence_level','global_primitivity_proved','event_history_complete','proper_apex_count'};
    g={'contract_version','synchrony_predicate_version','label','alias','abbreviation','status','validated_gait_type','canonical_point_label','canonical_label_qualified','flight_count','flight_count_certain','primitive_flight_count','period_used','descriptive_only','isotropy_proved'};
end
function keys=evidenceNames()
    keys={'return_policy','return_policy_name','return_multiplicity','candidate_section_count','candidate_apex_count','accepted_crossing_index','accepted_apex_index','section_relative_event_signature','cyclic_event_signature','primitive_cycle','gait_identification'};
end
function out=head(value,allowed)
    assert(isstruct(value)&&isscalar(value),'BranchCore29:Header','Unknown non-scalar/nonstruct historical header refuses projection.');out=pick(value,allowed);
end
function out=pick(value,allowed)
    assert(isstruct(value)&&isscalar(value),'BranchCore29:PlainRecord','Use actual scalar source structs.');out=struct();
    for name=fieldnames(value).',if ismember(name{1},allowed),out.(name{1})=value.(name{1});end,end
end
function verifyHead(out,source,allowed,primitive,classifier)
    assert(isstruct(out)&&isscalar(out)&&isstruct(source)&&isscalar(source),'BranchCore29:HeaderShape','Retained header shapes must remain literal.');
    expected=fieldnames(source);expected=expected(ismember(expected,allowed));same(fieldnames(out),expected);
    for name=expected.'
        key=name{1};if strcmp(key,'primitive')&&~isempty(primitive),verifyHead(out.(key),source.(key),primitive,{},{});
        elseif strcmp(key,'classification')&&~isempty(classifier),verifyHead(out.(key),source.(key),classifier,{},{});
        else,same(out.(key),source.(key));end
    end
end
function verifyCoreReads(file,core,expected,working,workingDigest)
    variables={'solution_core29','core_digest'};
    if ~isempty(working),variables=[variables,{'working_storage','working_storage_digest'}];end
    names=whos('-file',file);assert(isequal(sort({names.name}),sort(variables)),'BranchCore29:Variables','Unexpected saved variables.');
    a=load(file,variables{:});b=load(file,variables{:});
    same(core,a.solution_core29);same(core,b.solution_core29);
    assert(strcmp(a.core_digest,expected)&&strcmp(b.core_digest,expected),'BranchCore29:NativeRead2','Whole core typed native readback differs.');
    if ~isempty(working)
        same(working,a.working_storage);same(working,b.working_storage);
        assert(strcmp(a.working_storage_digest,workingDigest)&&strcmp(b.working_storage_digest,workingDigest), ...
            'BranchCore29:WorkingRead2','Complete working header native readback differs.');
    end
end
function verifyReconstruction(e)
    o=HybridOrbit_v3(struct('initial_state',e.matrix(1:14),'initial_mode',e.mode,'parameter',e.parameter, ...
        'stride_displacement',e.matrix(15:28),'period',e.matrix(29)));
    for name=properties(o).',o.(name{1})=[];end
    o.initial_state=e.matrix(1:14);o.initial_mode=e.mode;o.parameter=e.parameter;
    o.stride_displacement=e.matrix(15:28);o.period=e.matrix(29);
    for name=fieldnames(e.evidence).',o.(name{1})=e.evidence.(name{1});end
    o.section_chart=e.chart;o.validate();
    assert(strcmp(OrbitContentIdentity_v3(o),e.native_id),'BranchCore29:Identity','Actual loader-style native reconstruction changed identity-bearing values.');
    c=e.policy.configuration;descriptor=struct('diagnostic_kind','runtime-object-descriptor','source_class',c.source_class,'settings',c.settings);
    [~,policy]=RecordedReturnPolicy_v3(struct('correction_return_policy',descriptor));
    assert(policy.complete,'BranchCore29:PolicyReconstruction','Every literal policy must reconstruct without defaults.');same(policy.configuration,c);
end
function out=failureHeader(failure)
    out=struct();if isempty(fieldnames(failure)),return;end
    text=failure.message;out=struct('identifier',failure.identifier,'message_prefix',text(1:min(512,numel(text))), ...
        'message_characters',numel(text),'full_failure_retained_in_audit',true);
end
function [runtime,environment,codes]=methodsAndEnvironment()
    names={'LoadC1SolutionCore29_v3','RoundSHA256_v3','V3Path_v3','V3Root_v3','C1ScientificDigest_v3','HybridOrbit_v3','OrbitContentIdentity_v3', ...
        'QuadrupedSchema_v3','RecordedReturnPolicy_v3','BLMarkedApexReturnPolicy_v3','ReturnPolicyBase_v3'};
    runtime=cell(numel(names),1);codes=cell(numel(names)+3,1);
    for k=1:numel(names),codes{k}=checked(struct('file',which(names{k}),'sha256',RoundSHA256_v3(which(names{k}))));runtime{k}=struct('name',names{k},'sha256',codes{k}.sha256);end
    assert(strcmp(runtime{1}.sha256,'79e879e565c1a6d6dd6112f327635f85efb5f3a2329cbec7588adf6a197a81a6'), ...
        'BranchCore29:LoaderVersion','Keep the existing unchanged public79e loader.');
    for k=1:3,name={'WriteBranchSolutionCore29_v3','BranchSolutionFile_v3','QuadrupedEnergy_v3'};file=which(name{k});codes{numel(names)+k}=checked(struct('file',file,'sha256',RoundSHA256_v3(file)));end
    relative=fullfile('Audits_v3','Folder_Organization','locations.json');map=literalPath(fullfile(V3Root_v3(),relative));
    environment=struct('locations_map_relative_path',relative,'locations_map_sha256',RoundSHA256_v3(map), ...
        'scope','Current runtime resolver map; not a historical scientific sidecar.');
    codes{end+1,1}=struct('file',map,'sha256',environment.locations_map_sha256);
end
function r=checked(r)
    assert(isstruct(r)&&isscalar(r)&&isequal(sort(fieldnames(r)),{'file';'sha256'}) ...
        &&ischar(r.sha256)&&isrow(r.sha256)&&~isempty(regexp(r.sha256,'^[0-9a-f]{64}$','once')), ...
        'BranchCore29:Reference','Use exact file/SHA256 references.');r.file=literalPath(r.file);
    assert(isfile(r.file)&&strcmp(RoundSHA256_v3(r.file),r.sha256),'BranchCore29:SourceSHA','A declared input changed: %s.',r.file);
end
function file=literalPath(file)
    file=char(java.io.File(char(file)).getCanonicalPath());resolved=char(java.io.File(V3Path_v3(file)).getCanonicalPath());
    assert(strcmp(file,resolved),'BranchCore29:LiteralPath','Hash/load/write must use the same literal canonical path, without an alias.');
end
function fresh(paths)
    for k=1:numel(paths),assert(~isfile(paths{k})&&~isfolder(paths{k}),'BranchCore29:Fresh','Preserve an existing output/stage for reconciliation: %s.',paths{k});end
end
function guard(limit,refs)
    check(limit);for k=1:numel(refs),checked(refs{k});end
end
function same(a,b),assert(strcmp(digest(a),digest(b)),'BranchCore29:TypedEquality','Retained class/shape/field order/raw bits differ.');end
function d=digest(value),d=C1ScientificDigest_v3(value);end
function check(limit),assert(left(limit)>0,'BranchCore29:Deadline','The original export deadline expired.');end
function t=clockPair(),t=struct('utc',posixtime(datetime('now','TimeZone','UTC')),'mono',double(java.lang.System.nanoTime()));end
function value=left(limit),t=clockPair();value=min(limit.utc-t.utc,(limit.mono-t.mono)/1e9);end
