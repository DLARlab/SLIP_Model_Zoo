function summary=ContinuePeriodicBranch_v3(outputFile,sourceFile,pointIndices,options)
%CONTINUEPERIODICBRANCH_V3 Persistent native state-PAL with coupled free energy.
% RUN=ContinuePeriodicBranch_v3(OUTPUT,SOURCE,[PREVIOUS BASE],OPTIONS).
% Supported native apex charts and complete BL1 one-flight policies only.
% Existing EnergyFamilyResidual/ConstrainedEnergyResidual and all nine PSS
% checks are unchanged. PAL uses the scaled STATE chord; E is a free unknown
% with zero weight in the PAL normal. No classical derivative is claimed.
% A call gets its requested finite local wall limit; resume preserves the
% pair/controller/method epoch. An unknown prepared solver call HOLDs.
% One BranchSolutionFile plus a small session checkpoint. Default storage
% omits the qualified orbit's dense trajectory from a CLONE, never its input.
    if nargin<4,options=struct();end
    entryUTC=nowUnix();entryMono=nano();
    o=defaults(options);
    budget=runBudget(o,entryUTC,entryMono);
    integrationProfile=struct('RelTol',1e-12,'AbsTol',1e-14,'MaxStep',o.IntegrationMaxStep);
    o.MethodContextSnapshot=methodContext(o,integrationProfile);
    outputFile=canonical(outputFile);sourceFile=canonical(sourceFile);
    assert(~o.InPlace||~strcmp(member(budget,'schema',''),'absolute-UTC-native-budget-v1'), ...
        'PeriodicContinuation:AbsoluteOwner','An explicit absolute grant uses a separate small output branch.');
    checkpointFile=o.CheckpointFile;
    if isempty(checkpointFile),checkpointFile=[outputFile(1:end-4),'_run_checkpoint.mat'];else,checkpointFile=canonical(checkpointFile);end
    protected={outputFile,sourceFile,[outputFile,'.pending.mat'],[sourceFile,'.pending.mat']};
    for protectedFile=protected
        assert(~sameFile(checkpointFile,protectedFile{1})&&~sameFile([checkpointFile,'.pending.mat'],protectedFile{1}), ...
            'PeriodicContinuation:CheckpointPath','The checkpoint and its stage must be distinct from source/output branch files and their reserved stages.');
    end
    assert(~isfile([checkpointFile,'.pending.mat']),'PeriodicContinuation:PendingCheckpointStage', ...
        'Retain and reconcile an existing owned checkpoint stage before another run.');
    if isfile(checkpointFile)
        z=load(checkpointFile,'summary');hold=z.summary;clear z
        assert(isstruct(hold)&&isscalar(hold)&&strcmp(hold.output_file,outputFile), ...
            'PeriodicContinuation:CheckpointOwner','Checkpoint belongs to another output.');
        assert(isfield(hold,'configuration')&&isfield(hold.configuration,'engine_schema'), ...
            'PeriodicContinuation:LegacyCheckpoint','A historical checkpoint needs an explicit new segment; no automatic migration.');
        transaction=member(hold,'service_transaction',struct());
        pendingStage=member(member(hold,'pending_admission',struct()),'stage','');
        if contains(pendingStage,'isolated_append_attempted')
            summary=hold;summary.checkpoint_stored_native_calls=member(hold,'native_calls',0);summary.native_calls=0;summary.status='isolated_storage_requires_reconciliation';return
        end
        if ismember(member(transaction,'phase',''),{'prepared','unknown'})
            summary=hold;summary.checkpoint_stored_native_calls=member(hold,'native_calls',0);summary.native_calls=0;summary.status='unknown_solver_outcome_requires_reconciliation';return
        end
    end
    lease=writerLease(outputFile); %#ok<NASGU>
    assert(o.InPlace==strcmp(outputFile,sourceFile),'PeriodicContinuation:Output', ...
        'Use a separate output branch by default; InPlace explicitly requires the source and output to be identical.');
    assert(isnumeric(pointIndices)&&numel(pointIndices)==2&& ...
        all(isfinite(pointIndices))&&all(pointIndices==fix(pointIndices))&& ...
        all(pointIndices>0)&&pointIndices(1)~=pointIndices(2), ...
        'PeriodicContinuation:Pair','Two distinct positive source indices are required.');
    symmetry=char(o.Symmetry);
    assert(ismember(symmetry,{'none','fore-pair','hind-pair','left-right','pronk'}), ...
        'PeriodicContinuation:Symmetry','Use an existing native symmetry chart.');
    finish=struct('deadline_unix_seconds',min(budget.research_deadline_unix_seconds,entryUTC+o.MaxWallSeconds), ...
        'deadline_monotonic_ns',min(budget.research_deadline_monotonic_ns,entryMono+o.MaxWallSeconds*1e9));
    work=finish;work.deadline_unix_seconds=work.deadline_unix_seconds-o.SaveMarginSeconds;
    work.deadline_monotonic_ns=work.deadline_monotonic_ns-o.SaveMarginSeconds*1e9;
    check(work);
    adoptedReference=[];
    ownedResume=isfile(outputFile)&&isfile(checkpointFile)&&exist('hold','var') ...
        &&~strcmp(member(hold,'kind',''),'source-intake');
    if ownedResume
        assert(strcmp(hold.configuration.source_file,sourceFile)&&isequal(hold.configuration.source_indices,pointIndices(:).'), ...
            'PeriodicContinuation:OriginChanged','Retain the original origin locator/pair or start a new segment; no new source is silently adopted.');
        [initial,reports,metadata]=BranchSolutionFile_v3.loadSolutions(outputFile,[1,2]);
        adoptedReference=hold.configuration.source_reference;
    elseif isempty(o.SourceContext)
        [initial,reports,metadata]=sourceSolutions(sourceFile,pointIndices);
    else
        context=o.SourceContext;adoptedReference=sourceReference(sourceFile);
        assert(strcmp(member(context,'schema',''),'public-selected-native-context-v1') ...
            &&isequaln(context.source_reference,adoptedReference) ...
            &&isequal(context.point_indices(:),pointIndices(:)) ...
            &&strcmp(context.branch_provider.file,which('BranchSolutionFile_v3')) ...
            &&strcmp(context.branch_provider.sha256,RoundSHA256_v3(context.branch_provider.file)), ...
            'PeriodicContinuation:SourceContext','Resident adoption must match this immutable file generation, pair and public provider epoch.');
        initial=context.orbits;reports=context.reports;metadata=context.metadata;
        assert(iscell(initial)&&iscell(reports)&&iscell(metadata)&&numel(initial)==2 ...
            &&numel(reports)==2&&numel(metadata)==2 ...
            &&strcmp(OrbitContentIdentity_v3(initial{1}),context.native_ids{1}) ...
            &&strcmp(OrbitContentIdentity_v3(initial{2}),context.native_ids{2}), ...
            'PeriodicContinuation:SourceContext','Resident selected native views must retain their adopted identities.');
    end
    a=initial{1};b=initial{2};ra=reports{1};rb=reports{2};ma=metadata{1};mb=metadata{2};
    [~,ea]=admitted(a,ra,o.AllowedClasses);[~,eb]=admitted(b,rb,o.AllowedClasses);
    assert(isequaln(ea.configuration,eb.configuration)&& ...
        strcmp(ma.component_identity,mb.component_identity), ...
        'PeriodicContinuation:Pair','The source pair needs one component and identical actual policy.');
    pair=MatchingReturnSection_v3(a,b,{ra,rb});
    assert(pair.compatible&&isequal(a.parameter(:),b.parameter(:)), ...
        'PeriodicContinuation:Section','Source modes, parameters and complete marked section must match.');
    if isempty(o.ComponentIdentity),o.ComponentIdentity=char(ma.component_identity);end
    assert(~o.InPlace||strcmp(char(ma.component_identity),o.ComponentIdentity), ...
        'PeriodicContinuation:Pair','The requested continuation owner must match the selected pair.');
    config=struct('protocol','C1-compact-native-state-PAL-v1','source_file',sourceFile, ...
        'source_indices',pointIndices(:).','symmetry',symmetry, ...
        'component_identity',o.ComponentIdentity,'physical_parameter',b.parameter(:), ...
        'policy_configuration',eb.configuration,'allowed_classes',{o.AllowedClasses}, ...
        'scope','Finite native corrected links only; no canonical label, endpoint or formal bifurcation is assumed.');
    if ownedResume
        ownedEdge=hold.configuration.initializer_owned_edge;
    else
        sourceGraph=sourceIndex(sourceFile);
        hit=find(cellfun(@(e)(e.from==pointIndices(1)&&e.to==pointIndices(2)) ...
            ||(e.from==pointIndices(2)&&e.to==pointIndices(1)),sourceGraph.edges));
        assert(isscalar(hit),'PeriodicContinuation:OwnedPair','The ordered initializer pair must name one actual stored physical source edge; imports remain nonedges.');
        ownedEdge=sourceGraph.edges{hit};clear sourceGraph
    end
    if isempty(adoptedReference),adoptedReference=sourceReference(sourceFile);end
    config.source_reference=adoptedReference;
    config.source_native_ids={OrbitContentIdentity_v3(a),OrbitContentIdentity_v3(b)};
    % Absolute/local wall budgets are invocation limits, not numerical method identity.
    config.acquisition=struct('batch_size',o.BatchSize,'adaptive_step',o.AdaptiveStep, ...
        'maximum_correction_step_ratio',o.MaximumCorrectionStepRatio,'maximum_turn_degrees',o.MaximumTurnDegrees);
    if ~strcmp(o.CorrectorInitializer,'predictor'),config.corrector_initializer=o.CorrectorInitializer;end
    config.engine_schema='native-periodic-branch-session-v1';
    config.method=methodContext(o,integrationProfile);
    config.source_reference=adoptedReference;
    config.initializer_owned_edge=ownedEdge;
    if ownedResume,config.source_native_ids=hold.configuration.source_native_ids;else,config.source_native_ids={OrbitContentIdentity_v3(a),OrbitContentIdentity_v3(b)};end
    if o.InPlace
        error('PeriodicContinuation:InPlace','Use a new output segment; imported sources remain immutable.');
    elseif isfile(outputFile)
        ix=BranchSolutionFile_v3.index(outputFile);
        assert(isfield(ix.metadata,'engine_schema')&&isequaln(ix.metadata,config),'PeriodicContinuation:MethodEpoch','Resume method/source/chart changed or checkpoint predates this engine; retain it and start an explicit new segment.');
    else
        ix=BranchSolutionFile_v3.initialize(outputFile,config);
    end
    initial={a,b};reports={ra,rb};metadata={ma,mb};
    if numel(ix.points)<2
        [initial,reports,intakeState]=intakePair(initial,reports,symmetry,o,config,checkpointFile,outputFile,work,finish);
        if ~intakeState.accepted
            summary=intakeState;return
        end
        a=initial{1};b=initial{2};ra=reports{1};rb=reports{2};
    else
        assert(isfile(checkpointFile),'PeriodicContinuation:MissingSession','Existing output needs its exact session checkpoint; do not infer a controller from last records.');
    end
    for k=numel(ix.points)+1:2
        assert(~o.InPlace,'PeriodicContinuation:InPlacePair','In-place seeds must already exist.');
        check(work);p=metadata{k};p.component_identity=o.ComponentIdentity;
        p.edge_enabled=false;if isfield(p,'edge_from'),p=rmfield(p,'edge_from');end
        if isfield(p,'order'),p=rmfield(p,'order');end
        p.provenance=struct('kind','fresh fixed-state nonedge initializer', ...
            'source_file',sourceFile,'source_index',pointIndices(k), ...
            'original_provenance',member(p,'provenance',struct()));
        p.classification=storageLabel(reports{k}.classification);
        p.nativeE=QuadrupedEnergy_v3.evaluate(initial{k}.initial_state,initial{k}.initial_mode,initial{k}.parameter);
        p.signedmeanU=initial{k}.stride_displacement(1)/initial{k}.period;
        [savedOrbit,savedReport]=storageCopy(initial{k},compactReport(reports{k}),o.Storage,checkpointFile,k);
        [ix,~]=BranchSolutionFile_v3.append(outputFile,savedOrbit,savedReport,p);
    end
    assert(numel(ix.points)>=2,'PeriodicContinuation:Resume','Two accepted initializers are required.');
    if o.InPlace,currentPair=pointIndices(:).';else,currentPair=[numel(ix.points)-1,numel(ix.points)];end
    if isfile(checkpointFile)
        saved=load(checkpointFile,'summary');prior=saved.summary;
        assert(isstruct(prior)&&isscalar(prior)&&isequaln(prior.configuration,config), ...
            'PeriodicContinuation:Checkpoint','Existing run evidence belongs to another configuration.');
        if ~isempty(member(prior,'pending_batch',{}))
            [prior,ix]=reconcileBatch(outputFile,prior,ix,checkpointFile,work,finish);
            summary=prior;summary.status='reconciled_batch_without_solver';
            summary.native_calls=0;summary.persistence_completion_confirmed=left(finish)>0;
            assertMethodEpoch(config.method);saveCheckpoint(checkpointFile,summary,finish);return
        end
        recoveringNative=~isempty(fieldnames(member(prior,'pending_result',struct())));
        assert(~hasNativePending(prior)||recoveringNative,'PeriodicContinuation:Pending', ...
            'Retain a pending outcome without a known returned result for explicit reconciliation.');
        currentPair=prior.current_pair;
        validateattributes(currentPair,{'numeric'},{'vector','numel',2,'integer','positive','finite','<=',numel(ix.points)});
        assert(currentPair(1)~=currentPair(2) ...
            &&strcmp(ix.points{currentPair(1)}.component_identity,o.ComponentIdentity) ...
            &&strcmp(ix.points{currentPair(2)}.component_identity,o.ComponentIdentity), ...
            'PeriodicContinuation:ResumePair','Resume pair must contain two committed points of this owner.');
        owned=any(cellfun(@(edge)edge.from==currentPair(1)&&edge.to==currentPair(2),ix.edges));
        initializer=(o.InPlace&&isequal(currentPair,pointIndices(:).')) ...
            ||(~o.InPlace&&isequal(currentPair,[1,2]));
        assert(owned||initializer, ...
            'PeriodicContinuation:ResumePair','A grown resume pair requires an actual directed committed physical edge.');
    end
    [resident,residentReports]=BranchSolutionFile_v3.loadSolutions(outputFile,currentPair);
    a=resident{1};b=resident{2};ra=residentReports{1};rb=residentReports{2};
    [~,ea]=admitted(a,ra,o.AllowedClasses);[pb,eb]=admitted(b,rb,o.AllowedClasses);
    if exist('prior','var')&&isfield(prior,'current_pair_records')
        assert(isequaln(pairRecords(a,b,ra,rb),prior.current_pair_records),'PeriodicContinuation:PairDataChanged','Committed current pair data or admission/policy changed.');
    end
    pair=MatchingReturnSection_v3(a,b,{ra,rb});
    assert(pair.compatible&&isequaln(ea.configuration,config.policy_configuration)&& ...
        isequaln(eb.configuration,config.policy_configuration), ...
        'PeriodicContinuation:Resume','Actual last-two policy/section changed.');
    if ~exist('recoveringNative','var'),recoveringNative=false;end
    previous=cell(0,1);ledger=cell(0,1);phaseWarm=[];reuseAllowed=true;
    if exist('prior','var')&&~strcmp(member(prior,'kind',''),'source-intake')
        ledger=member(prior,'all_runs_ledger',cell(0,1));
        ledger{end+1,1}=struct('started_utc',prior.started_utc,'status',prior.status, ...
            'new_points',prior.new_points,'current_pair',prior.current_pair, ...
            'next_step',prior.next_step,'next_derivative_index',prior.next_derivative_index);
        if numel(ledger)>16,ledger=ledger(end-15:end);end
    end
    summary=struct('protocol',config.protocol,'output_file',outputFile,'configuration',config, ...
        'started_utc',stamp(),'completed_utc','','attempts',{{}},'failures',{{}},'failed_root_journals',{{}}, ...
        'new_points',0,'new_edges',0,'initial_output_count',numel(ix.points), ...
        'final_output_count',numel(ix.points),'status','running','failure',struct(), ...
        'classical_derivative_claimed',false,'formal_bifurcation_claimed',false, ...
        'persistence_completion_confirmed',false,'derivative_method',o.DerivativeMethod,'integration_profile',integrationProfile, ...
        'corrector_initializer',o.CorrectorInitializer,'controller_context',controllerContext(o,integrationProfile), ...
        'pending_admission',struct(),'pending_batch',{{}},'batch_publications',{{}},'batch_flush_attempted',false, ...
        'qualified_points',0,'isolated_native_admissions',{{}}, ...
        'previous_runs',{previous},'all_runs_ledger',{ledger}, ...
        'original_budget',budget,'run_limit',finish,'work_limit',work,'current_pair',currentPair, ...
        'next_step',o.InitialStep,'next_derivative_index',o.InitialDerivativeIndex, ...
        'service_transaction',struct(),'pending_result',struct(),'native_calls',0,'recovered_returns',0);
    if exist('prior','var'),summary.source_intake=member(prior,'source_intake',struct());end
    if recoveringNative
        summary.pending_result=prior.pending_result;summary.service_transaction=prior.service_transaction;
    end
    summary.apex_height_policy=apexHeightPolicy(b,rb,o.MinimumApexHeightRatio);
    summary.last_stop_requested=exist('prior','var')&&member(prior,'last_stop_requested',false);
    if exist('prior','var'),summary.last_stop_check=member(prior,'last_stop_check',struct());else,summary.last_stop_check=struct();end
    ds=o.InitialStep;method=o.InitialDerivativeIndex;
    controllerResume=struct('restored',false,'reason','new run uses its declared controller settings');
    if exist('prior','var')
        restoreController=true;
        expected=controllerContext(o,integrationProfile);
        if isfield(prior,'controller_context')
            assert(isequaln(prior.controller_context,expected), ...
                'PeriodicContinuation:ControllerResume','Restore a radius only in its declared compatible controller context.');
        else
            assert(strcmp(prior.status,'accepted_point_cap'), ...
                'PeriodicContinuation:ControllerResume','An unbound old controller may not silently restart a failed radius ladder.');
            restoreController=false;
            controllerResume.reason='Committed pair/history adopted; old accepted-cap epoch lacks controller context, so radius/method reset explicitly to this new epoch; no Jacobian reused.';
        end
        if restoreController
            if isfield(prior,'next_step'),ds=prior.next_step;end
            if isfield(prior,'next_derivative_index'),method=prior.next_derivative_index;end
            controllerResume.restored=true;controllerResume.reason='Actual committed pair and exact compatible controller state restored';
        end
        assert(isfinite(ds)&&ds>0&&method>=1&&method<=numel(o.FiniteDifferenceSteps) ...
            &&method==fix(method),'PeriodicContinuation:Checkpoint','Invalid in-place saved step or derivative index.');
    end
    controllerResume.selected_step=ds;controllerResume.selected_derivative_index=method;
    if exist('prior','var')
        controllerResume.previous_saved_step=member(prior,'next_step',[]);
        controllerResume.previous_saved_derivative_index=member(prior,'next_derivative_index',[]);
    end
    summary.current_pair_records=pairRecords(a,b,ra,rb);
    summary.controller_resume=controllerResume;
    summary.next_step=ds;summary.next_derivative_index=method;
    if summary.apex_height_policy.stop||summary.last_stop_requested||member(member(summary,'source_intake',struct()),'stop_requested',false)
        if summary.apex_height_policy.stop,summary.status=summary.apex_height_policy.disposition;else,summary.status='branch_stop_requested';end
        summary.completed_utc=stamp();saveCheckpoint(checkpointFile,summary,finish);
        summary.persistence_completion_confirmed=left(finish)>0;return
    end
    try
        for attempt=1:o.MaxAttempts
            attemptClock=tic;
            currentAdmission=false;orbit=[];rawReport=struct();row=struct();point=struct();accepted=false;
            check(work);assert(~hasNativePending(summary),'PeriodicContinuation:Pending','A pending native result must be resolved before another trial.');
            if summary.qualified_points>=o.MaxAccepted,summary.status='accepted_point_cap';break;end
            if left(work)<=o.TrialSeconds+10,summary.status='whole_child_does_not_fit';break;end
            if ds<o.MinimumStep,summary.status='state_step_resolution';break;end
            child=struct('deadline_unix_seconds',nowUnix()+o.TrialSeconds, ...
                'deadline_monotonic_ns',nano()+o.TrialSeconds*1e9);
            check(child);seed=struct('state',b.initial_state(:),'mode',b.initial_mode(:), ...
                'parameter',b.parameter(:),'return_policy',pb,'occurrence',1, ...
                'provenance',struct('kind','unadmitted native state PAL predictor', ...
                'branch_file',outputFile,'previous_point',currentPair(1), ...
                'source_point',currentPair(2),'attempt',attempt));
            schema=QuadrupedSchema_v3.shared();
            map=PoincareMap_v3(Quadrupedal_Dynamics_v3(), ...
                PoincareSection_v3.apex(schema.PhaseIndex), ...
                HybridSimulator_v3(integration(child,o.IntegrationMaxStep)),pb, ...
                struct('MaxReturnTime',30,'MaxCycleEvents',1000,'MaxSectionCrossings',64));
            family=EnergyFamilyResidual_v3(PeriodicOrbitResidual_v3(map,seed.state), ...
                seed.state,seed.mode,seed.parameter,struct('Symmetry',symmetry));
            ua=family.packState(a.initial_state);ub=family.packState(b.initial_state);
            scale=max([ones(numel(ub),1),abs(ua),abs(ub)],[],2);
            delta=(ub-ua)./scale;distance=norm(delta);
            assert(isfinite(distance)&&distance>1e-10,'PeriodicContinuation:Chord','Last-two states have no resolved direction.');
            tangent=delta/distance;predictor=ub+scale.*(ds*tangent);
            capturePredictor=family.fullState(predictor);seed.state=capturePredictor;
            E=QuadrupedEnergy_v3.evaluate(b.initial_state,b.initial_mode,b.parameter);Einitial=E;initialCoordinates=[predictor;E];baseRoundtripExact=[];
            if strcmp(o.CorrectorInitializer,'predictor-energy')
                % Change only the initial free-energy guess. The PAL base
                % reference below remains the admitted base energy E.
                Einitial=QuadrupedEnergy_v3.evaluate(capturePredictor,b.initial_mode,b.parameter);
                initialCoordinates=[predictor;Einitial];
            end
            if strcmp(o.CorrectorInitializer,'base')
                baseRoundtrip=family.fullState(ub);baseRoundtripExact=isequal(baseRoundtrip,b.initial_state(:));
                assert(baseRoundtripExact,'PeriodicContinuation:BaseRoundtrip', ...
                    'The exact admitted base must roundtrip through the unchanged family chart without projection.');
                seed.state=b.initial_state(:);initialCoordinates=[ub;E];
                seed.provenance.kind='admitted base state for native PAL correction';
            end
            initialization=struct('method',o.CorrectorInitializer,'start_state',seed.state,'start_mode',seed.mode, ...
                'start_coordinates',initialCoordinates,'capture_predictor_state',capturePredictor,'base_roundtrip_exact',baseRoundtripExact);
            if strcmp(o.CorrectorInitializer,'predictor-energy')
                initialization.Ebase=E;initialization.Einitial=Einitial;
            end
            seed.provenance.corrector_initialization=initialization;
            constraint=struct('reference',[ub;E],'normal',[tangent./scale;0],'target',ds);
            native=ConstrainedEnergyResidual_v3(family,1:numel(ub),constraint,ones(numel(ub)+1,1));
            if strcmp(o.DerivativeMethod,'valid-sided')
                jacobian=ValidSidedFiniteDifferenceJacobian_v3(struct( ...
                    'RelativeStep',o.FiniteDifferenceSteps(method), ...
                    'DeadlineUnixSeconds',child.deadline_unix_seconds, ...
                    'DeadlineMonotonicNs',child.deadline_monotonic_ns));
                derivativeName='valid-sided-finite-difference';
            else
                jacobian=FiniteDifferenceJacobian_v3(struct('Method','forward', ...
                    'RelativeStep',o.FiniteDifferenceSteps(method)));
                derivativeName='ordinary-forward';
            end
            solver=struct('Algorithm',o.Algorithm,'MaxIterations',40, ...
                'MaxFunctionEvaluations',3000,'FunctionTolerance',1e-11, ...
                'ResidualAcceptanceTolerance',1e-10,'StepTolerance',1e-13, ...
                'OptimalityTolerance',1e-18,'InitialDamping',1e-12, ...
                'ReuseJacobian',true,'InitialJacobian',[],'UseBroyden',true, ...
                'JacobianRefreshInterval',5,'Jacobian',jacobian);
            settings=struct('Residual',native,'Coordinates',initialCoordinates, ...
                'AugmentedParameter',[seed.parameter;Einitial],'SolverOptions',solver, ...
                'MaxWallSeconds',max(.001,left(child)),'TraceFailure',o.TraceFailure);
            row=struct('attempt',attempt,'source_point',currentPair(2),'step',ds, ...
                'derivative_method',o.DerivativeMethod,'relative_step',o.FiniteDifferenceSteps(method), ...
                'algorithm',o.Algorithm,'predictor_state',capturePredictor,'integration_profile',integrationProfile, ...
                'corrector_initialization',initialization, ...
                'constraint',constraint,'status','not_returned','all_nine',false, ...
                'timely',false,'capture',struct(),'edge_committed',false, ...
                'storage_attempted',false,'storage_timely',[], ...
                'isolated_committed',false,'isolated_storage_timely',[]);
            definition=struct('symmetry',symmetry,'coordinate_indices',family.CoordinateIndices, ...
                'closure_indices',family.ClosureIndices,'energy_pivot',family.EnergyPivot, ...
                'constraint',constraint,'residual_scale',ones(numel(ub)+1,1), ...
                'physical_parameter',seed.parameter,'jacobian_class',class(jacobian),'integration_profile',integrationProfile, ...
                'corrector_initialization',initialization, ...
                'derivative_settings',jacobianDescriptor(jacobian), ...
                'classical_derivative_claimed',false);
            reuse=struct('requested',o.ReusePreviousJacobian,'provided_to_solver',false,'actual_initial_jacobian_used',[],'status','not_requested', ...
                'scope','Approximate acquisition seed only; no derivative certification.');
            if o.ReusePreviousJacobian&&reuseAllowed&&~o.UsePhasePredictor
                residentPoint=struct('index',currentPair(2),'classification',storageLabel(rb.classification));
                [initialJ,reuse]=previousNativeJacobian(b,rb,residentPoint,family,definition, ...
                    config.policy_configuration,o.AllowedClasses);
                settings.SolverOptions.InitialJacobian=initialJ;
            end
            row.previous_jacobian_reuse=reuse;
            check(child);check(work);
            if ~recoveringNative
                summary.service_transaction=struct('phase','prepared','id',char(java.util.UUID.randomUUID), ...
                    'kind','state_PAL_correction','pair',currentPair,'step',ds,'derivative_index',method, ...
                    'coordinates',initialCoordinates,'started_utc',stamp());
                row.transaction_id=summary.service_transaction.id;row.transaction_started_utc=summary.service_transaction.started_utc;
                saveCheckpoint(checkpointFile,summary,finish);
            end
            phaseEvidence=struct();phaseMatrix=[];
            if recoveringNative,phaseEvidence=prior.pending_result.phase_evidence;end
            if o.UsePhasePredictor
                if recoveringNative
                    candidate=member(phaseEvidence,'candidate_state',[]);
                else
                    [candidate,phaseEvidence,phaseMatrix]=o.PredictorFunction(b,predictor,constraint,scale,E,child,o,phaseWarm);
                end
                row.phase_acquisition=phaseEvidence;
                if phaseEvidence.completed
                    nativeFamily=EnergyFamilyResidual_v3(PeriodicOrbitResidual_v3(map,candidate), ...
                        candidate,b.initial_mode,b.parameter,struct('Symmetry',symmetry));
                    assert(isequal(nativeFamily.CoordinateIndices,family.CoordinateIndices) ...
                        &&isequal(nativeFamily.fullState(nativeFamily.packState(candidate)),candidate), ...
                        'PeriodicContinuation:PhaseBinding','Native handoff must preserve the SAME phase candidate and original basis.');
                    native=ConstrainedEnergyResidual_v3(nativeFamily,1:numel(ub),constraint,ones(numel(ub)+1,1));
                    seed.state=candidate;seed.provenance.kind='NEW exact-symmetry phase candidate';
                    seed.provenance.literal_source_state=b.initial_state;
                    seed.provenance.full_source_difference=candidate-b.initial_state;
                    settings.Residual=native;settings.Coordinates=[nativeFamily.packState(candidate);phaseEvidence.energy];
                    settings.AugmentedParameter=[b.parameter;phaseEvidence.energy];
                    settings.SolverOptions.InitialJacobian=[]; % NEVER transfer a phase Jacobian.
                end
            end
            nativeCall=tic;
            if recoveringNative
                orbit=prior.pending_result.orbit;report=prior.pending_result.report;
                savedRow=prior.pending_result.row;
                assert(isequaln(savedRow.constraint,constraint)&&isequal(savedRow.source_point,currentPair(2)), ...
                    'PeriodicContinuation:RecoveryContext','The exact returned problem no longer matches its committed pair.');
                row=savedRow;summary.recovered_returns=summary.recovered_returns+1;
            elseif ~o.UsePhasePredictor||phaseEvidence.completed
                check(child);check(work);settings.MaxWallSeconds=max(.001,left(child));
                summary.native_calls=summary.native_calls+1;
                [orbit,report]=PeriodicSolutionSolver_v3(seed,settings);
            else
                orbit=[];report=struct('status','phase_acquisition_refused','accepted',false, ...
                    'failure_stage','phase_acquisition','primary_failure',phaseEvidence.failure, ...
                    'final_candidate',seed.state,'native_service_called',false);
            end
            row.native_service_seconds=toc(nativeCall);
            nativeReturnedTimely=left(child)>0&&left(work)>0;
            try
                rawReport=compactReport(report);
            catch codecProblem
                summary.pending_result=struct('orbit',orbit,'report',report,'row',row, ...
                    'phase_evidence',phaseEvidence,'original_timely',nativeReturnedTimely);
                summary.service_transaction.phase='returned';
                summary.status='native_return_codec_requires_reconciliation';
                saveCheckpoint(checkpointFile,summary,finish);rethrow(codecProblem)
            end
            if ~recoveringNative
                row.status=report.status;row.timely=nativeReturnedTimely;row.all_nine=nine(report);
                summary.pending_result=struct('orbit',orbit,'report',rawReport,'row',row, ...
                    'phase_evidence',phaseEvidence,'original_timely',nativeReturnedTimely);
                summary.service_transaction.phase='returned';
                saveCheckpoint(checkpointFile,summary,finish);
            end
            nativeOutput=member(member(report,'solver',struct()),'output',struct());
            reuse.actual_initial_jacobian_used=member(nativeOutput,'initialJacobianUsed',[]);
            row.previous_jacobian_reuse=reuse;
            row.status=report.status;
            if recoveringNative,row.timely=prior.pending_result.original_timely&&left(work)>0;else,row.timely=left(child)>0&&left(work)>0;end
            row.all_nine=nine(report);currentAdmission=isa(orbit,'HybridOrbit_v3')&&isscalar(orbit)&&row.all_nine;
            if currentAdmission
                summary.pending_admission=struct('orbit',orbit,'raw_report',rawReport, ...
                    'row',row,'point',struct(),'wrapper_accepted',[],'committed',false, ...
                    'stage','native_return_before_wrapper_or_compaction','failure',struct());
                custody=tic;saveCheckpoint(checkpointFile,summary,finish);row.pending_custody_seconds=toc(custody);
            end
            if o.UsePhasePredictor,report.phase_acquisition=phaseEvidence;end
            report.continuation_acquisition=struct( ...
                'derivative',derivativeName,'relative_step',o.FiniteDifferenceSteps(method), ...
                'algorithm',o.Algorithm,'classical_derivative_claimed',false,'previous_jacobian_reuse',reuse);
            report.delegated_residual_definition=definition;
            report.options.Residual=[];report.options_residual_runtime_object_omitted=true;
            report.options.SolverOptions.Jacobian=jacobianDescriptor(solver.Jacobian);
            accepted=false;failure=struct();
            if ~isempty(orbit)&&row.all_nine&&row.timely
                try
                    [nextPolicy,nextEvidence]=admitted(orbit,report,o.AllowedClasses);
                    match=MatchingReturnSection_v3(b,orbit,{rb,report});
                    uc=family.packState(orbit.initial_state);
                    progress=dot(tangent,(uc-ub)./scale);
                    stateScale=max(ones(13,1),abs(capturePredictor(2:14)));
                    captureError=norm((orbit.initial_state(2:14)-capturePredictor(2:14))./stateScale,Inf);
                    separation=norm((uc-ub)./scale,Inf);
                    correctionRatio=norm((uc-predictor)./scale)/ds;
                    nextDirection=(uc-ub)./scale;
                    turn=acosd(max(-1,min(1,dot(tangent,nextDirection)/norm(nextDirection))));
                    row.capture=struct('full13_scaled_inf',captureError,'radius',o.CaptureRadius, ...
                        'achieved_state_progress',progress,'requested_progress',ds, ...
                        'PAL_error',progress-ds,'distinct_state_distance',separation, ...
                        'section_compatible',match.compatible,'correction_step_ratio',correctionRatio, ...
                        'turn_degrees',turn);
                    phaseConsistent=true;
                    if o.UsePhasePredictor
                        [phaseConsistent,phaseCapture]=o.PredictorCompareFunction(orbit,nextEvidence,phaseEvidence);
                        names=fieldnames(phaseCapture);for kk=1:numel(names),row.capture.(names{kk})=phaseCapture.(names{kk});end
                    end
                    accepted=match.compatible&&isequal(orbit.parameter(:),config.physical_parameter) ...
                        &&isequaln(nextEvidence.configuration,config.policy_configuration) ...
                        &&isequal(logical(orbit.initial_mode(:)),logical(b.initial_mode(:))) ...
                        &&captureError<o.CaptureRadius&&separation>1e-8&&progress>1e-8&&abs(progress-ds)<=1e-8 ...
                        &&correctionRatio<=o.MaximumCorrectionStepRatio&&turn<=o.MaximumTurnDegrees&&phaseConsistent;
                    if accepted&&~isempty(o.PointCheck)
                        [passed,row.point_check]=runAdapter(o.PointCheck,orbit,report,child,'PointCheck');
                        assert(islogical(passed)&&isscalar(passed),'PeriodicContinuation:PointCheck','PointCheck must return one logical and plain evidence.');
                        accepted=passed;
                    end
                    row.stop_requested=false;row.stop_check=struct();
                    if accepted&&~isempty(o.StopCheck)
                        [stop,row.stop_check]=runAdapter(o.StopCheck,orbit,report,child,'StopCheck');
                        assert(islogical(stop)&&isscalar(stop),'PeriodicContinuation:StopCheck','StopCheck must return one logical and plain evidence.');
                        row.stop_requested=stop;
                    end
                catch problem
                    accepted=false;failure=exceptionData(problem);
                    summary.pending_admission.failure=failure;
                    summary.pending_admission.stage='callback_or_capture_refused_after_known_return';
                    summary.pending_admission.row=row;
                    summary.status='known_native_return_requires_review';
                    saveCheckpoint(checkpointFile,summary,finish);break
                end
            end
            if currentAdmission
                summary.pending_admission.wrapper_accepted=accepted;summary.pending_admission.row=row;
                summary.pending_admission.failure=failure;summary.pending_admission.stage='wrapper_evaluated_before_storage';
            end
            if accepted
                check(child);check(work);g=report.classification;
                nextDS=ds;
                if o.AdaptiveStep
                    effort=report.solver;effortScope='native root iterations';
                    if o.UsePhasePredictor,effort=phaseEvidence.root;effortScope='phase acquisition root iterations';end
                    [nextDS,row.step_controller]=adaptiveStep(ds,row.capture.turn_degrees,effort,o);
                    row.step_controller.effort_scope=effortScope;
                    row.step_controller.native_root_iterations=member(member(report.solver,'output',struct()),'iterations',NaN);
                else
                    nextDS=min(o.MaximumStep,ds*o.StepGrowth);
                    row.step_controller=struct('policy','fixed-growth','selected_radius',nextDS);
                end
                row.apex_height_policy=apexHeightPolicy(orbit,report,o.MinimumApexHeightRatio);
                transition=struct('next_step',nextDS,'next_derivative_index',1, ...
                    'apex_height_policy',row.apex_height_policy, ...
                    'stop_requested',member(row,'stop_requested',false), ...
                    'stop_check',member(row,'stop_check',struct()), ...
                    'pair_records',{pairRecords(b,orbit,rb,report)});
                newIndex=numel(ix.points)+numel(summary.pending_batch)+1;
                transition.current_pair=[currentPair(2),newIndex];
                point=struct('component_identity',o.ComponentIdentity, ...
                    'classification',storageLabel(g), ...
                    'nativeE',QuadrupedEnergy_v3.evaluate(orbit.initial_state,orbit.initial_mode,orbit.parameter), ...
                    'signedmeanU',orbit.stride_displacement(1)/orbit.period, ...
                    'provenance',struct('kind','new native captured state PAL correction', ...
                    'source_point',currentPair(2),'attempt',attempt,'capture',row.capture, ...
                    'corrector_initialization',initialization), ...
                    'edge_enabled',true,'edge_from',currentPair(2));
                row.storage_attempted=true;
                stored=compactReport(report);[storedOrbit,stored]=storageCopy(orbit,stored,o.Storage,checkpointFile,1);check(child);check(work);
                summary.pending_admission=struct('orbit',storedOrbit,'raw_report',stored, ...
                    'compacted_report',stored,'row',row,'point',point,'wrapper_accepted',true,'committed',false, ...
                    'stage','compacted_report_before_append','failure',struct(),'controller_transition',transition);
                saveCheckpoint(checkpointFile,summary,finish);
                check(child);check(work);
                currentPair=[currentPair(2),newIndex];summary.current_pair=currentPair;
                ds=nextDS;method=1;
                row.edge_qualified=true;row.edge_committed=false;
                summary.pending_batch{end+1,1}=summary.pending_admission;
                summary.pending_admission=struct();
                % Every accepted object remains recoverable before RAM moves
                % to the next point; the queue is bounded by BatchSize.
                saveCheckpoint(checkpointFile,summary,finish);currentAdmission=false;
                summary.qualified_points=summary.qualified_points+1;
                row.pending_custody_timely=left(work)>0&&left(child)>0;
                row.storage_timely=[]; % Public batch storage has not returned.
                if numel(summary.pending_batch)>=o.BatchSize
                    summary.batch_flush_attempted=true;
                    [summary,ix]=flushBatch(outputFile,summary,ix,checkpointFile,finish);
                    row.edge_committed=true;row.storage_timely=summary.batch_publications{end}.timely;
                end
                a=b;ra=rb;b=orbit;rb=stored;pb=nextPolicy;
                phaseWarm=phaseMatrix;reuseAllowed=true;
                summary.apex_height_policy=row.apex_height_policy;
                summary.last_stop_requested=transition.stop_requested;
            else
                phaseWarm=[];reuseAllowed=false;
                row.wrapper_failure=failure;
                if currentAdmission&&(~row.timely||left(child)<=0||left(work)<=0)
                    summary.pending_admission.row=row;summary.pending_admission.wrapper_accepted=false;
                    summary.pending_admission.stage='native_all_nine_held_after_clock';summary.pending_admission.failure=failure;
                    summary.attempts{end+1,1}=row;summary.status='native_all_nine_pending_after_clock';
                    saveCheckpoint(checkpointFile,summary,finish);break
                end
                stored=compactReport(report);
                if currentAdmission
                    if isempty(o.IsolatedFile)&&~isempty(summary.pending_batch)
                        summary.batch_flush_attempted=true;
                        [summary,ix]=flushBatch(outputFile,summary,ix,checkpointFile,finish);
                    end
                    summary.pending_admission.stage='isolated_append_attempted';
                    saveCheckpoint(checkpointFile,summary,finish);
                    [isolateOrbit,stored]=storageCopy(orbit,stored,o.Storage,checkpointFile,1);
                    [row,isolation]=appendIsolatedNative(isolateOrbit,stored,row,sourceFile,outputFile,pointIndices,config,summary.started_utc,failure,child,work,budget);
                    summary.isolated_native_admissions{end+1,1}=isolation;
                    if strcmp(isolation.file,outputFile),ix=BranchSolutionFile_v3.index(outputFile);end
                    summary.pending_admission.row=row;summary.pending_admission.isolated_reference=isolation;
                    summary.pending_admission.stage='isolated_append_and_readback_confirmed';
                    saveCheckpoint(checkpointFile,summary,finish);
                    row.isolated_storage_timely=row.isolated_storage_timely&&left(child)>0&&left(work)>0;
                    isolation.storage_timely=row.isolated_storage_timely;summary.isolated_native_admissions{end}=isolation;
                    summary.pending_admission.row=row;summary.pending_admission.isolated_reference=isolation;
                    if ~row.isolated_storage_timely
                        summary.pending_admission.stage='isolated_native_storage_late_held';
                        summary.attempts{end+1,1}=row;summary.status='isolated_native_storage_late';
                        saveCheckpoint(checkpointFile,summary,finish);break
                    end
                    summary.pending_admission=struct();
                end
                if strcmp(o.Storage,'compact'),stored=thinFailureReport(report);end
                entry=struct('attempt',attempt,'seed_state',seed.state, ...
                    'final_candidate',report.final_candidate,'report',stored,'wrapper_failure',failure);
                journal=struct('attempt',attempt,'seed_state',seed.state,'final_candidate',report.final_candidate, ...
                    'wrapper_failure',failure,'native_report',struct());
                for key={'status','accepted','failure_stage','primary_failure','replay_failure','finalization_failure', ...
                        'full_closure','acceptance_gates','elapsed_seconds','solver','final_candidate','root_diagnostics', ...
                        'last_finite_state','last_accepted_state','continuation_acquisition','delegated_residual_definition'}
                    if isfield(stored,key{1}),journal.native_report.(key{1})=stored.(key{1});end
                end
                summary.failed_root_journals{end+1,1}=journal;
                if numel(summary.failed_root_journals)>o.MaxSavedFailures,summary.failed_root_journals=summary.failed_root_journals(end-o.MaxSavedFailures+1:end);end
                summary.failures{end+1,1}=entry;
                if numel(summary.failures)>o.MaxSavedFailures,summary.failures(2)=[];end
                if ~o.UsePhasePredictor&&method<numel(o.FiniteDifferenceSteps),method=method+1;
                else,method=1;ds=ds*o.StepShrink;end
            end
            summary.attempts{end+1,1}=row;
            if numel(summary.attempts)>o.MaxSavedAttempts,summary.attempts=summary.attempts(end-o.MaxSavedAttempts+1:end);end
            summary.attempts{end}.attempt_seconds_before_final_checkpoint=toc(attemptClock);
            if accepted&&isequal(row.storage_timely,false),summary.status='committed_data_but_storage_late';end
            if row.isolated_committed&&~row.isolated_storage_timely,summary.status='isolated_native_storage_late';end
            summary.next_step=ds;summary.next_derivative_index=method;
            summary.service_transaction.phase='committed';summary.pending_result=struct();
            recoveredThisAttempt=recoveringNative;recoveringNative=false;
            saveCheckpoint(checkpointFile,summary,finish);
            fprintf('C1 continuation attempt=%d status=%s all9=%d wrapper=%d committed=%d ds=%.9g', ...
                row.attempt,char(row.status),row.all_nine,accepted,summary.new_points,row.step);
            if accepted
                fprintf(' label=%s E=%.12g meanU=%.12g',point.classification,point.nativeE,point.signedmeanU);
            end
            fprintf('\n');
            if recoveredThisAttempt,summary.status='recovered_native_return_without_solver';break;end
            if accepted&&isequal(row.storage_timely,false),break;end
            if row.isolated_committed&&~row.isolated_storage_timely,break;end
            if ~row.timely,summary.status='child_or_work_budget_exhausted';break;end
            if accepted&&(summary.apex_height_policy.stop||member(row,'stop_requested',false))
                check(child);check(work);
                if member(row,'stop_requested',false),summary.status='branch_stop_requested';else,summary.status=summary.apex_height_policy.disposition;end;break
            end
        end
        if strcmp(summary.status,'running'),summary.status='attempt_cap';end
    catch problem
        summary.status='stopped_with_exception';summary.failure=exceptionData(problem);
        if strcmp(member(summary.service_transaction,'phase',''),'prepared'),summary.service_transaction.phase='unknown';end
        if exist('currentAdmission','var')&&currentAdmission&&~row.edge_committed&&~row.isolated_committed
            if ~hasNativePending(summary)
                summary.pending_admission=struct('orbit',orbit,'raw_report',rawReport, ...
                    'row',row,'point',point,'wrapper_accepted',accepted,'committed',false, ...
                    'stage','stopped_with_current_native_admission','failure',summary.failure);
            else
                summary.pending_admission.row=row;summary.pending_admission.failure=summary.failure;
            end
            if isempty(summary.attempts)||summary.attempts{end}.attempt~=row.attempt
                summary.attempts{end+1,1}=row;
            end
        end
    end
    if ~isempty(summary.pending_batch)&&~summary.batch_flush_attempted&&left(finish)>10
        try
            summary.batch_flush_attempted=true;
            [summary,ix]=flushBatch(outputFile,summary,ix,checkpointFile,finish);
        catch problem
            summary.status='batch_pending_reconciliation';summary.failure=exceptionData(problem);
        end
    end
    summary.origin_source_consumed=~ownedResume;
    if ~ownedResume&&isfield(config,'source_reference')&&~o.InPlace
        summary.source_posthash=strcmp(RoundSHA256_v3(sourceFile),config.source_reference.sha256);
        assert(summary.source_posthash,'PeriodicContinuation:SourceChanged','The adopted immutable source changed.');
    end
    summary.current_pair=currentPair;summary.current_pair_records=pairRecords(a,b,ra,rb);summary.next_step=ds;summary.next_derivative_index=method;
    assertMethodEpoch(config.method);
    summary.source_posthash=true;
    summary.completed_utc=stamp();saveCheckpoint(checkpointFile,summary,finish);
    % The stored checkpoint stays provisional; this fact exists only after
    % its readback, publication and original-clock postguard have returned.
    summary.persistence_completion_confirmed=left(finish)>0; % Expired raw-pending durability is not timely completion.
end

function evidence=apexHeightPolicy(orbit,report,fraction)
    evidence=struct('schema','C1-marked-local-COM-apex-height-stop-v1', ...
        'enabled',fraction>0,'fraction',fraction,'supported',true,'stop',false, ...
        'triggered',false,'disposition','continue','height',NaN,'rest_length',NaN, ...
        'threshold',NaN,'ratio',NaN,'vertical_velocity',NaN,'vertical_acceleration',NaN, ...
        'failure',struct(),'scope','Existing admitted BL-marked LOCAL COM apex, not the maximum over the whole cycle; strict inequality only.');
    if fraction==0,return;end
    try
        [~,policyEvidence]=admitted(orbit,report,{}); %#ok<ASGLU>
        schema=QuadrupedSchema_v3.shared();x=schema.validateState(orbit.initial_state);p=schema.validateParameter(orbit.parameter);
        chart=orbit.section_chart;
        assert(isstruct(chart)&&isscalar(chart)&&isfield(chart,'id') ...
            &&strcmp(char(chart.id),'apex-before-BL-TD-local') ...
            &&isfield(chart,'geometry')&&strcmp(char(chart.geometry),'dy=0, ddy<0') ...
            &&isfield(chart,'crossing_orientation')&&isequal(chart.crossing_orientation,-1), ...
            'PeriodicContinuation:ApexHeightChart','The actual complete marked downward-apex chart is required.');
        Lb=p(schema.Parameter.l_l_b);Lf=p(schema.Parameter.l_l_f);
        assert(Lb>0&&Lf>0&&isequal(Lb,Lf), ...
            'PeriodicContinuation:ApexHeightRestLength','Unequal resting leg lengths have no authorized normalization.');
        section=PoincareSection_v3.apex(schema.PhaseIndex);system=Quadrupedal_Dynamics_v3();
        assert(section.isOnSection(x,p),'PeriodicContinuation:ApexHeightSection','The admitted state must lie on its actual apex section.');
        ddy=section.derivative(0,x,orbit.initial_mode,p,system);
        assert(isfinite(ddy)&&ddy<0,'PeriodicContinuation:ApexHeightOrientation','A finite strict downward crossing is required.');
        evidence.height=x(schema.State.y);evidence.rest_length=Lb;evidence.threshold=fraction*Lb;
        evidence.ratio=evidence.height/Lb;evidence.vertical_velocity=x(schema.State.dy);evidence.vertical_acceleration=ddy;
        evidence.triggered=evidence.height<evidence.threshold;evidence.stop=evidence.triggered;
        if evidence.triggered,evidence.disposition='user_apex_height_boundary';end
    catch problem
        evidence.supported=false;evidence.stop=true;evidence.disposition='apex_height_policy_measurement_invalid';
        evidence.failure=exceptionData(problem);
    end
end

function o=defaults(value)
    o=struct('Budget',[],'MaxWallSeconds',600,'TrialSeconds',120,'MaxAccepted',100, ...
        'MaxAttempts',300,'InitialStep',.005,'MinimumStep',1e-7,'MaximumStep',.02, ...
        'StepGrowth',1.3,'StepShrink',.5,'CaptureRadius',.02,'SaveMarginSeconds',30, ...
        'MaxSavedFailures',5,'DerivativeMethod','ordinary','FiniteDifferenceSteps',[1e-5,1e-7], ...
        'ReusePreviousJacobian',false,'Algorithm','root-newton','AllowedClasses',{{}},'ComponentIdentity','', ...
        'IntegrationMaxStep',.001,'CorrectorInitializer','predictor','InPlace',false,'CheckpointFile','', ...
        'InitialDerivativeIndex',1,'MinimumApexHeightRatio',.5,'BatchSize',1,'TraceFailure',false, ...
        'AdaptiveStep',true,'MaximumCorrectionStepRatio',Inf,'MaximumTurnDegrees',180, ...
        'UsePhasePredictor',false,'PhaseSeconds',30,'SourceContext',[], ...
        'Symmetry','none','Storage','compact','DeadlineUTC','', ...
        'PointCheck',[],'StopCheck',[],'PredictorFunction',[],'PredictorCompareFunction',[], ...
        'MaxSavedAttempts',50,'IsolatedFile','','SeedSeconds',120,'AdapterSources',{{}});
    assert(isstruct(value)&&isscalar(value),'PeriodicContinuation:Options','Options must be scalar struct.');
    for key=fieldnames(value).'
        assert(isfield(o,key{1}),'PeriodicContinuation:Options','Unknown option %s.',key{1});o.(key{1})=value.(key{1});
    end
    assert(islogical(o.InPlace)&&isscalar(o.InPlace),'PeriodicContinuation:Options','InPlace must be one logical.');
    assert(islogical(o.TraceFailure)&&isscalar(o.TraceFailure)&&islogical(o.AdaptiveStep)&&isscalar(o.AdaptiveStep) ...
        &&islogical(o.UsePhasePredictor)&&isscalar(o.UsePhasePredictor), ...
        'PeriodicContinuation:Options','TraceFailure and AdaptiveStep must be logical scalars.');
    validateattributes(o.BatchSize,{'numeric'},{'scalar','real','finite','integer','positive','<=',16});
    validateattributes(o.MaximumCorrectionStepRatio,{'numeric'},{'scalar','real','positive'});
    validateattributes(o.MaximumTurnDegrees,{'numeric'},{'scalar','real','finite','positive','<=',180});
    validateattributes(o.PhaseSeconds,{'numeric'},{'scalar','real','finite','positive','<=',120});
    assert(~o.UsePhasePredictor||o.PhaseSeconds<o.TrialSeconds/2, ...
        'PeriodicContinuation:PhaseBudget','Phase allocation must leave the majority of the same child clock for native admission.');
    assert(~o.InPlace||o.BatchSize==1,'PeriodicContinuation:BatchOwner','Batching requires a separate small output branch.');
    assert(ischar(o.CheckpointFile)&&(isempty(o.CheckpointFile)||isrow(o.CheckpointFile)), ...
        'PeriodicContinuation:Options','CheckpointFile must be a char path or empty.');
    assert((ischar(o.DerivativeMethod)&&isrow(o.DerivativeMethod)) ...
        ||(isstring(o.DerivativeMethod)&&isscalar(o.DerivativeMethod)), ...
        'PeriodicContinuation:Derivative','Use ordinary or valid-sided.');
    o.DerivativeMethod=char(o.DerivativeMethod);
    assert(ismember(o.DerivativeMethod,{'ordinary','valid-sided'}), ...
        'PeriodicContinuation:Derivative','Use ordinary or valid-sided.');
    assert((ischar(o.CorrectorInitializer)&&isrow(o.CorrectorInitializer)) ...
        ||(isstring(o.CorrectorInitializer)&&isscalar(o.CorrectorInitializer)), ...
        'PeriodicContinuation:Initializer','Use predictor, base or predictor-energy.');
    o.CorrectorInitializer=char(o.CorrectorInitializer);
    assert(ismember(o.CorrectorInitializer,{'predictor','base','predictor-energy'}), ...
        'PeriodicContinuation:Initializer','Use predictor, base or predictor-energy.');
    assert(islogical(o.ReusePreviousJacobian)&&isscalar(o.ReusePreviousJacobian) ...
        &&(~o.ReusePreviousJacobian||ismember(char(o.Algorithm),{'newton','root-newton'})), ...
        'PeriodicContinuation:JacobianReuse','Previous native acquisition matrices require explicit logical opt-in and Newton.');
    if strcmp(o.DerivativeMethod,'valid-sided')&&~isfield(value,'FiniteDifferenceSteps')
        o.FiniteDifferenceSteps=1e-8;
    end
    validateattributes(o.IntegrationMaxStep,{'double','single'},{'real','scalar','finite','positive','<=',.005},mfilename,'IntegrationMaxStep');
    o.IntegrationMaxStep=double(o.IntegrationMaxStep);
    validateattributes(o.MinimumApexHeightRatio,{'double'},{'scalar','real','finite','>=',0,'<=',1});
    for key={'MaxWallSeconds','TrialSeconds','InitialStep','MinimumStep','MaximumStep','SaveMarginSeconds'}
        v=o.(key{1});assert(isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0,'PeriodicContinuation:Options','Positive finite %s required.',key{1});
    end
    for key={'MaxAccepted','MaxAttempts','MaxSavedFailures'}
        v=o.(key{1});assert(isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>=1&&v==fix(v),'PeriodicContinuation:Options','Positive integer %s required.',key{1});
    end
    assert(o.TrialSeconds<=600&&o.MinimumStep<=o.InitialStep&&o.InitialStep<=o.MaximumStep ...
        &&o.MaximumStep<=.1&&o.StepGrowth>1&&o.StepShrink>0&&o.StepShrink<1 ...
        &&o.CaptureRadius>0&&o.CaptureRadius<=.02&&o.MaxSavedFailures>=2, ...
        'PeriodicContinuation:Options','Child cap, capture and state-step bounds must remain conservative.');
    assert(isnumeric(o.FiniteDifferenceSteps)&&isvector(o.FiniteDifferenceSteps) ...
        &&~isempty(o.FiniteDifferenceSteps)&&all(isfinite(o.FiniteDifferenceSteps)) ...
        &&all(o.FiniteDifferenceSteps>0)&&numel(unique(o.FiniteDifferenceSteps))==numel(o.FiniteDifferenceSteps), ...
        'PeriodicContinuation:Options','Each registered FD method must be positive and distinct.');
    assert(isnumeric(o.InitialDerivativeIndex)&&isscalar(o.InitialDerivativeIndex)&&isfinite(o.InitialDerivativeIndex) ...
        &&o.InitialDerivativeIndex==fix(o.InitialDerivativeIndex)&&o.InitialDerivativeIndex>=1 ...
        &&o.InitialDerivativeIndex<=numel(o.FiniteDifferenceSteps),'PeriodicContinuation:Options','InitialDerivativeIndex must select a registered FD step.');
    assert(strcmp(char(o.Algorithm),'root-newton')&&iscell(o.AllowedClasses) ...
        &&all(cellfun(@(s)ischar(s)&&isrow(s),o.AllowedClasses)), ...
        'PeriodicContinuation:Options','Require literal root-newton and explicit native gait names; no optimization route is used.');
    assert(ismember(char(o.Storage),{'compact','full'}),'PeriodicContinuation:Storage','Storage is compact or full.');
    validateattributes(o.SeedSeconds,{'double'},{'scalar','finite','positive','<=',600});
    validateattributes(o.MaxSavedAttempts,{'double'},{'scalar','finite','integer','positive'});
    assert(~o.UsePhasePredictor||(~isempty(o.PredictorFunction)&&~isempty(o.PredictorCompareFunction)),'PeriodicContinuation:PredictorAdapter','Optional acquisition requires both named predictor adapters.');
    assert(~strcmp(o.DerivativeMethod,'valid-sided')||ismember(char(o.Algorithm),{'newton','root-newton'}), ...
        'PeriodicContinuation:Derivative','Valid-sided acquisition requires Newton; fsolve requires classical reliability.');
end

function [policy,evidence]=admitted(orbit,report,allowed)
    assert(isa(orbit,'HybridOrbit_v3')&&isscalar(orbit)&&nine(report), ...
        'PeriodicContinuation:Admission','Only native all-nine admitted objects can initialize or continue.');
    status=member(report,'status',member(report,'native_status',''));
    if isfield(report,'accepted'),accepted=isequal(report.accepted,true);
    else,accepted=strcmp(status,'accepted');end
    assert(accepted, ...
        'PeriodicContinuation:Admission','Literal successful native admission status is required.');
    g=member(report,'classification',struct());
    assert(strcmp(member(g,'contract_version',''),'quadruped-gait-v3.5') ...
        &&(isempty(allowed)||ismember(member(g,'validated_gait_type',''),allowed)) ...
        &&isequal(member(g,'flight_count_certain',false),true)&&member(g,'flight_count',NaN)==1, ...
        'PeriodicContinuation:Family','Require an allowed actual physical C1 family with certain one flight.');
    [policy,evidence]=RecordedReturnPolicy_v3(report);
    assert(evidence.complete&&isa(policy,'BLMarkedApexReturnPolicy_v3') ...
        &&policy.BLTouchdownsPerReturn==1&&policy.RequireModeClosure, ...
        'PeriodicContinuation:Policy','Preserve the actual complete marked BL1 policy.');
end

function yes=nine(report)
    names={'full_closure','mode_closure','target_energy','trajectory_energy_variation', ...
        'unscaled_family_equations','family_constraint','physical_inequalities', ...
        'primitive_identity','replay_determinism'};
    gates=member(report,'acceptance_gates',struct());
    yes=isstruct(gates)&&isscalar(gates)&&all(isfield(gates,names));
    for k=1:numel(names),yes=yes&&isequal(member(gates,names{k},false),true);end
end

function [J,evidence]=previousNativeJacobian(orbit,report,point,family,definition,policy,allowed)
    J=[];evidence=struct('requested',true,'provided_to_solver',false,'actual_initial_jacobian_used',[],'status','unavailable', ...
        'source_field','report.solver.finalJacobian','source_point',point.index, ...
        'scope','Approximate acquisition seed only; no derivative certification.', ...
        'coordinate_scope','Physical native [u;E] columns, unit residual scale; next Root solve applies its own StateScale.', ...
        'failure',struct());
    try
        [~,recorded]=admitted(orbit,report,allowed);
        assert(isequaln(recorded.configuration,policy) ...
            &&strcmp(report.classification.canonical_point_label,point.classification) ...
            &&isequal(report.classification.canonical_label_qualified,true), ...
            'PeriodicContinuation:JacobianReuse','Previous native class/policy must match its committed point.');
        previous=report.delegated_residual_definition;
        for key={'symmetry','coordinate_indices','closure_indices','energy_pivot','residual_scale','physical_parameter'}
            assert(isfield(previous,key{1})&&isequaln(previous.(key{1}),definition.(key{1})), ...
                'PeriodicContinuation:JacobianReuse','Previous native residual chart/equation ordering differs.');
        end
        assert(isequal(orbit.parameter(:),definition.physical_parameter(:)) ...
            &&isequal(orbit.initial_mode(:),family.Chart.mode(:)) ...
            &&isequal(report.seed.state(family.Chart.fixed_indices),family.Chart.reference_state(family.Chart.fixed_indices)), ...
            'PeriodicContinuation:JacobianReuse','Physical parameters, mode or fixed chart coordinates differ.');
        root=report.solver;u=family.packState(orbit.initial_state);n=numel(u)+1;
        assert(isequal(root.converged,true)&&isequal(root.mode(:),orbit.initial_mode(:)) ...
            &&numel(root.state)==n&&all(isfinite(root.state(:))) ...
            &&norm(root.state(1:end-1)-u,Inf)<=1e-10, ...
            'PeriodicContinuation:JacobianReuse','Chosen native Root result does not match the committed orbit.');
        matrix=root.finalJacobian;
        assert(isfloat(matrix)&&ismatrix(matrix)&&isequal(size(matrix),[n,n])&&all(isfinite(matrix(:))) ...
            &&all(definition.residual_scale==1), ...
            'PeriodicContinuation:JacobianReuse','A finite complete chosen physical-coordinate matrix is required.');
        evidence.previous_selector_row=matrix(end,:);
        matrix(end,:)=definition.constraint.normal(:).';
        evidence.new_selector_row=matrix(end,:);evidence.source_root_state=root.state;
        evidence.selected_attempt=member(root,'selectedAttempt',[]);evidence.matrix_size=size(matrix);
        evidence.provided_to_solver=true;evidence.status='chosen_native_matrix_with_exact_new_PAL_row';J=matrix;
    catch problem
        evidence.failure=exceptionData(problem);evidence.status='refused_and_fresh_derivative_required';
    end
end

function value=compactReport(value)
    % Preserve correction facts while omitting only runtime reconstruction.
    [~,policyEvidence]=RecordedReturnPolicy_v3(value);
    if policyEvidence.complete
        c=policyEvidence.configuration;
        value.correction_return_policy=struct('diagnostic_kind','runtime-object-descriptor', ...
            'source_class',c.source_class,'settings',c.settings);
    end
    if isfield(value,'options')&&isstruct(value.options)
        if isfield(value.options,'Residual')&&~isempty(value.options.Residual)
            value.options.Residual=[];value.options_residual_runtime_object_omitted=true;
        end
        if isfield(value.options,'SolverOptions')&&isstruct(value.options.SolverOptions) ...
                &&isfield(value.options.SolverOptions,'Jacobian')&&isobject(value.options.SolverOptions.Jacobian)
            j=value.options.SolverOptions.Jacobian;
            assert(isa(j,'FiniteDifferenceJacobian_v3'),'PeriodicContinuation:Report','Unexpected Jacobian runtime object.');
            value.options.SolverOptions.Jacobian=jacobianDescriptor(j);
        end
    end
    holder=CompactResearchBranch_v3(struct('report',value));value=holder.report;
end

function out=jacobianDescriptor(j)
    keys={'Method','RelativeStep','MinimumStep','MaximumStep','CheckFinite','FailurePolicy'};
    if strcmp(class(j),'ValidSidedFiniteDifferenceJacobian_v3')
        keys=[keys,{'DeadlineUnixSeconds','DeadlineMonotonicNs','MaximumHalvings'}];
    else
        assert(strcmp(class(j),'FiniteDifferenceJacobian_v3'), ...
            'PeriodicContinuation:Report','Unknown Jacobian runtime class.');
    end
    assert(isscalar(j) ...
        &&isequal(sort(properties(j)),sort(keys(:))), ...
        'PeriodicContinuation:Report','The complete exact known FD settings schema is required.');
    settings=struct();for k=1:numel(keys),settings.(keys{k})=j.(keys{k});end
    out=struct('diagnostic_kind','runtime-object-descriptor', ...
        'source_class',class(j),'settings',settings);
end

function value=integration(limit,maxStep)
    value=struct('RelTol',1e-12,'AbsTol',1e-14,'MaxStep',maxStep, ...
        'ODEOptions',odeset('OutputFcn',@(~,~,~)double(left(limit)<=0)));
end
function [summary,ix]=flushBatch(file,summary,ix,checkpoint,finish)
    queue=summary.pending_batch;count=numel(queue);assert(count>0, ...
        'PeriodicContinuation:Batch','Only a nonempty earned queue may be published.');
    check(finish);before=numel(ix.points);expected=(before+(1:count)).';
    publication=struct('before_count',before,'indices',expected,'attempts',zeros(count,1), ...
        'append_returned',false,'installed_read2_verified',false,'seconds',NaN,'timely',[], ...
        'clock_scope','Batch publication uses the original parent work/finish clocks, separately from each numerical child.');
    orbits=cell(count,1);reports=cell(count,1);points=cell(count,1);
    for k=1:count
        orbits{k}=queue{k}.orbit;reports{k}=queue{k}.compacted_report;points{k}=queue{k}.point;
        publication.attempts(k)=queue{k}.row.attempt;
    end
    summary.batch_publications{end+1,1}=publication;
    saveCheckpoint(checkpoint,summary,finish);
    call=tic;[ix,indices]=BranchSolutionFile_v3.appendBatch(file,orbits,reports,points);
    summary.batch_publications{end}.append_returned=true;
    assert(isequal(indices,expected),'PeriodicContinuation:BatchIndices','Published batch indices differ.');
    for pass=1:2
        [back,backReports,backPoints]=BranchSolutionFile_v3.loadSolutions(file,indices);
        for k=1:count
            assertPendingPublicEqual(orbits{k},back{k},0);
            assert(isequaln(reports{k},backReports{k})&&isequaln(points{k},backPoints{k}), ...
                'PeriodicContinuation:BatchReadback','Installed report/metadata differs.');
            [~,p]=RecordedReturnPolicy_v3(reports{k});[~,q]=RecordedReturnPolicy_v3(backReports{k});
            assert(p.complete&&q.complete&&isequaln(p.configuration,q.configuration) ...
                &&strcmp(OrbitContentIdentity_v3(orbits{k}),OrbitContentIdentity_v3(back{k})), ...
                'PeriodicContinuation:BatchReadback','Installed NativeID or complete policy differs.');
        end
    end
    summary.batch_publications{end}.installed_read2_verified=true;
    summary.batch_publications{end}.seconds=toc(call);
    summary.batch_publications{end}.timely=left(summary.work_limit)>0&&left(finish)>0;
    for k=1:numel(summary.attempts)
        if ismember(summary.attempts{k}.attempt,publication.attempts)
            summary.attempts{k}.edge_committed=true;
            summary.attempts{k}.storage_timely=summary.batch_publications{end}.timely;
        end
    end
    summary.new_points=summary.new_points+count;summary.new_edges=summary.new_edges+count;
    summary.final_output_count=numel(ix.points);
    summary=applyCommittedTransition(summary,queue{end});
    summary.pending_batch={};summary.batch_flush_attempted=false;
    if returnedQueueMatches(summary,queue)
        summary.pending_result=struct();summary.service_transaction.phase='committed';
    end
    % Clear only after two independent installed reads have returned. If this
    % checkpoint fails, its prior queue/transaction remains recoverable.
    saveCheckpoint(checkpoint,summary,finish);
end
function [step,evidence]=adaptiveStep(previous,turn,root,o)
    iterations=member(member(root,'output',struct()),'iterations',NaN);
    numerical=previous;
    if isfinite(iterations)&&iterations>0
        ratio=25/iterations;
        if ratio>=1,numerical=previous*ratio^.25;else,numerical=previous*sqrt(ratio);end
    end
    numerical=min(o.MaximumStep,max(o.MinimumStep,numerical));
    fraction=min(1,max(0,(turn-5)/55));
    geometric=o.MaximumStep-(o.MaximumStep-o.MinimumStep)*fraction;
    step=min(numerical,geometric);
    evidence=struct('target_iterations',25,'iterations',iterations,'turn_degrees',turn, ...
        'numerical_radius',numerical,'turn_radius',geometric,'selected_radius',step, ...
        'hard_floor',o.MinimumStep,'ceiling',o.MaximumStep);
end
function c=controllerContext(o,integration)
    c=struct('capture_radius',o.CaptureRadius,'step_growth',o.StepGrowth,'step_shrink',o.StepShrink, ...
        'method_context',methodContext(o,integration),'policy_version','phase-or-native-effort-radius-v1','target_iterations',25, ...
        'flat_turn_degrees',5,'sharp_turn_degrees',60, ...
        'derivative_method',o.DerivativeMethod,'finite_difference_steps',o.FiniteDifferenceSteps, ...
        'integration_profile',integration,'phase_predictor',o.UsePhasePredictor,'phase_seconds',o.PhaseSeconds, ...
        'adaptive_step',o.AdaptiveStep,'minimum_step',o.MinimumStep,'maximum_step',o.MaximumStep, ...
        'maximum_correction_step_ratio',o.MaximumCorrectionStepRatio,'maximum_turn_degrees',o.MaximumTurnDegrees, ...
        'corrector_initializer',o.CorrectorInitializer,'algorithm',o.Algorithm);
end
function ref=sourceReference(file)
    assert(strcmp(file,char(java.io.File(V3Path_v3(file)).getCanonicalPath())), ...
        'PeriodicContinuation:SourceAlias','Adopt the literal source, not a remapped alias.');
    ref=struct('file',file,'sha256',RoundSHA256_v3(file));
end
function saveCheckpoint(file,summary,limit)
    durablePending=hasNativePending(summary)||~isempty(member(summary,'pending_batch',{})) ...
        ||~isempty(fieldnames(member(summary,'pending_result',struct()))) ...
        ||strcmp(member(member(summary,'service_transaction',struct()),'phase',''),'returned');
    if ~durablePending,check(limit);end
    stage=[file,'.pending.mat'];
    assert(~isfile(stage),'PeriodicContinuation:PendingCheckpointStage', ...
        'A previous failed checkpoint publication left an owned stage; retain it for reconciliation.');
    % Raw pending persistence is custody only, even after a clock expires.
    % Keep its written stage if native/public readback or publication refuses.
    save(stage,'summary','-v7');if ~durablePending,check(limit);end
    saved=load(stage,'summary');[expected,actual]=checkpointComparison(summary,saved.summary,0);
    assert(isequaln(actual,expected),'PeriodicContinuation:Checkpoint','Checkpoint readback differs.');
    if ~durablePending,check(limit);end
    [ok,message]=movefile(stage,file,'f');assert(ok,'PeriodicContinuation:Checkpoint','%s',message);
    if ~durablePending,check(limit);end
end
function [expected,actual]=checkpointComparison(expected,actual,depth)
    assert(depth<=16&&isstruct(expected)&&isscalar(expected)&&isstruct(actual)&&isscalar(actual) ...
        &&isequal(fieldnames(expected),fieldnames(actual)), ...
        'PeriodicContinuation:Checkpoint','Checkpoint summary/history structure differs.');
    if isfield(expected,'pending_result')&&~isempty(fieldnames(expected.pending_result))
        a=expected.pending_result;b=actual.pending_result;
        if isa(a.orbit,'HybridOrbit_v3')
            assertPendingPublicEqual(a.orbit,b.orbit,0);
            a.orbit=[];b.orbit=[];
        end
        expected.pending_result=a;actual.pending_result=b;
    end
    if isfield(expected,'records')
        a=expected.records;b=actual.records;
        assert(iscell(a)&&iscell(b)&&isequal(size(a),size(b)), ...
            'PeriodicContinuation:IntakeReadback','Intake record shape differs.');
        for k=1:numel(a)
            if isa(a{k}.orbit,'HybridOrbit_v3')
                assertPendingPublicEqual(a{k}.orbit,b{k}.orbit,0);
                a{k}.orbit=[];b{k}.orbit=[];
            end
        end
        expected.records=a;actual.records=b;
    end
    if isfield(expected,'pending_admission')
        pending=expected.pending_admission;restored=actual.pending_admission;
        assert(isstruct(pending)&&isscalar(pending)&&isstruct(restored)&&isscalar(restored) ...
            &&isequal(fieldnames(pending),fieldnames(restored)), ...
            'PeriodicContinuation:Checkpoint','Pending admission structure differs.');
        if ~isempty(fieldnames(pending))
            assert(strcmp(class(pending.orbit),'HybridOrbit_v3')&&isscalar(pending.orbit) ...
                &&strcmp(class(restored.orbit),'HybridOrbit_v3')&&isscalar(restored.orbit) ...
                &&isstruct(pending.raw_report)&&isscalar(pending.raw_report) ...
                &&isstruct(restored.raw_report)&&isscalar(restored.raw_report) ...
                &&isequal(fieldnames(restored.raw_report),fieldnames(pending.raw_report)) ...
                &&nine(pending.raw_report)&&nine(restored.raw_report) ...
                &&isequaln(restored.raw_report.acceptance_gates,pending.raw_report.acceptance_gates), ...
                'PeriodicContinuation:Checkpoint','Native pending admission payload did not read back.');
            for key={'status','accepted','native_status'}
                if isfield(pending.raw_report,key{1})
                    assert(isequaln(pending.raw_report.(key{1}),restored.raw_report.(key{1})), ...
                        'PeriodicContinuation:Checkpoint','Pending native status differs.');
                end
            end
            assertPendingPublicEqual(pending.orbit,restored.orbit,0);
            [~,p]=RecordedReturnPolicy_v3(pending.raw_report);[~,q]=RecordedReturnPolicy_v3(restored.raw_report);
            assert(p.complete&&q.complete&&isequaln(p.configuration,q.configuration), ...
                'PeriodicContinuation:Checkpoint','Current pending complete policy differs.');
            % Only comparison copies omit raw runtime handles/functions.
            % The current and historical payloads remain in the saved file.
            expected.pending_admission=rmfield(pending,{'orbit','raw_report'});
            actual.pending_admission=rmfield(restored,{'orbit','raw_report'});
        end
    end
    if isfield(expected,'pending_batch')
        a=expected.pending_batch;b=actual.pending_batch;
        assert(iscell(a)&&iscell(b)&&isequal(size(a),size(b)), ...
            'PeriodicContinuation:Checkpoint','Pending batch shape differs.');
        for k=1:numel(a)
            assertPendingPublicEqual(a{k}.orbit,b{k}.orbit,0);
            assert(nine(a{k}.raw_report)&&nine(b{k}.raw_report) ...
                &&isequaln(a{k}.raw_report.acceptance_gates,b{k}.raw_report.acceptance_gates), ...
                'PeriodicContinuation:Checkpoint','Queued all-nine decisions differ.');
            [~,p]=RecordedReturnPolicy_v3(a{k}.raw_report);[~,q]=RecordedReturnPolicy_v3(b{k}.raw_report);
            assert(p.complete&&q.complete&&isequaln(p.configuration,q.configuration), ...
                'PeriodicContinuation:Checkpoint','Queued complete policy differs.');
            a{k}=rmfield(a{k},{'orbit','raw_report'});b{k}=rmfield(b{k},{'orbit','raw_report'});
        end
        expected.pending_batch=a;actual.pending_batch=b;
    end
    for key={'previous_runs','all_runs_ledger'}
        if ~isfield(expected,key{1}),continue;end
        a=expected.(key{1});b=actual.(key{1});
        assert(iscell(a)&&iscell(b)&&isequal(size(a),size(b)), ...
            'PeriodicContinuation:Checkpoint','Flat run-history shape differs.');
        for k=1:numel(a),[a{k},b{k}]=checkpointComparison(a{k},b{k},depth+1);end
        expected.(key{1})=a;actual.(key{1})=b;
    end
end
function assertPendingPublicEqual(a,b,depth)
    assert(depth<=128&&strcmp(class(a),class(b))&&isequal(size(a),size(b)), ...
        'PeriodicContinuation:Checkpoint','Pending native class, shape or nesting differs.');
    if isnumeric(a)||islogical(a)
        assert(issparse(a)==issparse(b)&&isreal(a)==isreal(b)&&isequaln(a,b), ...
            'PeriodicContinuation:Checkpoint','Pending public numeric values/storage type differ.');
    elseif ischar(a)||isstring(a)
        assert(isequaln(a,b),'PeriodicContinuation:Checkpoint','Pending public values differ.');
    elseif iscell(a)
        for k=1:numel(a),assertPendingPublicEqual(a{k},b{k},depth+1);end
    elseif isstruct(a)
        keys=fieldnames(a);assert(isequal(keys,fieldnames(b)),'PeriodicContinuation:Checkpoint','Pending public fields differ.');
        for k=1:numel(a),for j=1:numel(keys),assertPendingPublicEqual(a(k).(keys{j}),b(k).(keys{j}),depth+1);end,end
    else
        assert(any(strcmp(class(a),{'HybridOrbit_v3','Trajectory_v3'})), ...
            'PeriodicContinuation:Checkpoint','Unsupported pending native public class.');
        keys=sort(properties(a));assert(isequal(keys,sort(properties(b))),'PeriodicContinuation:Checkpoint','Pending public properties differ.');
        for k=1:numel(a),for j=1:numel(keys),assertPendingPublicEqual(a(k).(keys{j}),b(k).(keys{j}),depth+1);end,end
    end
end
function value=member(s,key,fallback)
    value=fallback;if isstruct(s)&&isscalar(s)&&isfield(s,key),value=s.(key);end
end
function value=exceptionData(problem)
    value=struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack);
end
function file=canonical(file)
    assert((ischar(file)&&isrow(file))||(isstring(file)&&isscalar(file)), ...
        'PeriodicContinuation:Path','Use one MAT file path.');
    file=char(java.io.File(char(file)).getCanonicalPath());[~,~,ext]=fileparts(file);
    assert(strcmpi(ext,'.mat'),'PeriodicContinuation:Path','Use a MAT file.');
end
function yes=sameFile(a,b)
    yes=strcmp(canonical(a),canonical(b));
    if ~yes&&isfile(a)&&isfile(b)
        yes=java.nio.file.Files.isSameFile(java.io.File(a).toPath(),java.io.File(b).toPath());
    end
end
function value=left(limit)
    value=min(limit.deadline_unix_seconds-nowUnix(),(limit.deadline_monotonic_ns-nano())/1e9);
end
function check(limit)
    assert(left(limit)>0,'PeriodicContinuation:Budget','Original run/child budget expired.');
end
function value=nowUnix(),value=posixtime(datetime('now','TimeZone','UTC'));end
function value=nano(),value=double(java.lang.System.nanoTime);end
function value=stamp()
    t=datetime('now','TimeZone','UTC');t.Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";value=char(t);
end

function yes=hasNativePending(summary)
    yes=false;if ~isfield(summary,'pending_admission'),return;end
    p=summary.pending_admission;
    assert(isstruct(p)&&isscalar(p),'PeriodicContinuation:Pending','Pending admission metadata must remain a scalar structure.');
    yes=~isempty(fieldnames(p));
end
function out=storageLabel(g)
    out='unclassified';for key={'canonical_point_label','validated_gait_type'}
        value=member(g,key{1},[]);if ischar(value)&&isrow(value)&&~isempty(strtrim(value)),out=strtrim(value);return;end
        if isstring(value)&&isscalar(value)&&~ismissing(value)&&strlength(strtrim(value))>0,out=char(strtrim(value));return;end
    end
end

function budget=runBudget(o,u,m)
    if isempty(o.Budget)
        deadline=u+o.MaxWallSeconds;
        if ~isempty(o.DeadlineUTC)
            requested=posixtime(datetime(o.DeadlineUTC,'TimeZone','UTC'));
            assert(isscalar(requested)&&isfinite(requested),'PeriodicContinuation:Deadline','Use one explicit UTC deadline.');
            deadline=min(deadline,requested);
        end
        budget=struct('schema','periodic-continuation-local-budget-v1', ...
            'start_utc',stamp(),'research_deadline_unix_seconds',deadline, ...
            'research_deadline_monotonic_ns',m+(deadline-u)*1e9, ...
            'deadline_unix_seconds',deadline,'deadline_monotonic_ns',m+(deadline-u)*1e9, ...
            'capture',struct('pid',feature('getpid')));
    else
        budget=o.Budget;
        required={'research_deadline_unix_seconds','research_deadline_monotonic_ns','deadline_unix_seconds','deadline_monotonic_ns'};
        assert(isstruct(budget)&&isscalar(budget)&&all(isfield(budget,required)), ...
            'PeriodicContinuation:Budget','Supply explicit absolute limits or a new finite MaxWallSeconds.');
        for k=1:numel(required),validateattributes(budget.(required{k}),{'numeric'},{'scalar','real','finite'});end
        assert(budget.research_deadline_unix_seconds<=budget.deadline_unix_seconds ...
            &&budget.research_deadline_monotonic_ns<=budget.deadline_monotonic_ns, ...
            'PeriodicContinuation:Budget','Work limits must not exceed their finish limits.');
        if isfield(budget,'capture')
            assert(budget.capture.pid==feature('getpid'),'PeriodicContinuation:Budget','Explicit monotonic limits must belong to this process.');
        end
    end
end

function context=methodContext(o,integrationProfile)
    if isfield(o,'MethodContextSnapshot'),context=o.MethodContextSnapshot;return;end
    % Hash small method files once per invocation, never the branch per seed.
    omitted={'Budget','MaxWallSeconds','TrialSeconds','MaxAccepted','MaxAttempts', ...
        'SaveMarginSeconds','DeadlineUTC','SourceContext','CheckpointFile','SeedSeconds'};
    context=rmfield(o,intersect(fieldnames(o),omitted));
    for key={'PointCheck','StopCheck','PredictorFunction','PredictorCompareFunction'}
        value=o.(key{1});
        if isempty(value),context.(key{1})=[];continue;end
        assert(isa(value,'function_handle'),'PeriodicContinuation:Adapter','Use named adapter functions.');
        details=functions(value);
        assert(ismember(details.type,{'simple','scopedfunction'})&&isfield(details,'file')&&isfile(details.file), ...
            'PeriodicContinuation:Adapter','Use an ordinary named or file-local function, not an anonymous/nested captured workspace.');
        if isfield(details,'workspace')
            assert(all(cellfun(@(w)isempty(w)||(isstruct(w)&&isempty(fieldnames(w))),details.workspace)), ...
                'PeriodicContinuation:Adapter','Adapters may not capture mutable or dense workspace values.');
        end
        context.(key{1})=struct('name',func2str(value),'file',details.file,'sha256',RoundSHA256_v3(details.file));
    end
    names={'ContinuePeriodicBranch_v3','ValidatePeriodicContinuationSeed_v3', ...
        'PeriodicSolutionSolver_v3','EnergyFamilyResidual_v3','ConstrainedEnergyResidual_v3', ...
        'RootSolver_v3','FiniteDifferenceJacobian_v3','ValidSidedFiniteDifferenceJacobian_v3', ...
        'PoincareMap_v3','PoincareSection_v3','HybridSimulator_v3','EventDetector_v3', ...
        'GuardFunctions_v3','ResetMap_v3','ContinuousDynamics_v3','QuadrupedAdmissibility_v3', ...
        'GaitIdentification_v3','PrimitiveCycleCheck_v3','BranchSolutionFile_v3', ...
        'EssentialBranchSolutionFile_v3','RecordedReturnPolicy_v3','CompactResearchBranch_v3', ...
        'Quadrupedal_Dynamics_v3','QuadrupedSchema_v3','QuadrupedEnergy_v3','QuadrupedPhysicalChart_v3', ...
        'PeriodicOrbitResidual_v3','ModeTransition_v3','BLMarkedApexReturnPolicy_v3', ...
        'ReturnPolicyBase_v3','MatchingReturnSection_v3','HybridOrbit_v3','Trajectory_v3', ...
        'HybridCycleData_v3','EventCluster_v3','CircularPhase_v3','GaitSemanticTable_v3'};
    assert(iscell(o.AdapterSources)&&all(cellfun(@(n)ischar(n)&&isrow(n),o.AdapterSources)),'PeriodicContinuation:AdapterSources','Use names of additional adapter method providers.');
    names=unique([names,o.AdapterSources(:).'],'stable');
    context.integration_profile=integrationProfile;context.source_epoch=cell(numel(names),1);
    for k=1:numel(names)
        file=which(names{k});assert(isfile(file),'PeriodicContinuation:Provider','Missing provider %s.',names{k});
        context.source_epoch{k}=struct('name',names{k},'file',file,'sha256',RoundSHA256_v3(file));
    end
end

function [orbits,reports,metadata]=sourceSolutions(file,indices)
    if EssentialBranchSolutionFile_v3.isEssential(file)
        [orbits,reports,metadata]=EssentialBranchSolutionFile_v3.loadSolutions(file,indices);
    else
        [orbits,reports,metadata]=BranchSolutionFile_v3.loadSolutions(file,indices);
    end
end

function index=sourceIndex(file)
    if EssentialBranchSolutionFile_v3.isEssential(file)
        index=EssentialBranchSolutionFile_v3.index(file);
    else
        index=BranchSolutionFile_v3.index(file);
    end
end

function [out,saved]=storageCopy(orbit,report,mode,checkpoint,slot)
    if strcmp(mode,'full'),out=orbit;saved=report;return;end
    % Reuse the reviewed scientific projection, including its explicit
    % omission contract. The source is the actual pending checkpoint
    % generation; it is historical custody, not a permanent trace archive.
    reference=sourceReference(checkpoint);
    metadata=struct('component_identity','native_pending','order',slot,'edge_enabled',false);
    context=struct('role','nonedge-control','occurrence_id',sprintf('pending_%d',slot), ...
        'source_reference',reference,'source_index',slot,'expected_index',slot);
    r=EssentialBranchSolutionFile_v3.project(orbit,report,metadata,context);
    out=HybridOrbit_v3();for key=properties(out).',out.(key{1})=[];end
    for key=fieldnames(r.orbit).',out.(key{1})=r.orbit.(key{1});end
    saved=r.report;for key=fieldnames(r.method).',saved.(key{1})=r.method.(key{1});end
    c=EssentialBranchSolutionFile_v3.contract();
    marker=struct('schema',c.schema,'historical_evidence_only',true, ...
        'trajectory_available',false,'event_state_tapes_available',false,'solver_tapes_available',false, ...
        'requires_fresh_replay',true,'whole_runtime_equality_claimed',false,'omissions',c.omissions, ...
        'receipt_reference_availability',c.receipt_reference_availability, ...
        'cluster_membership_domain',c.cluster_membership_domain,'native_id',r.native_id, ...
        'context',context,'recorded_policy_evidence',r.policy, ...
        'retained_orbit_fields',{fieldnames(r.orbit)},'retained_report_fields',{fieldnames(r.report)}, ...
        'retained_method_fields',{fieldnames(r.method)},'native_id_available',~isempty(r.native_id));
    out.schema_metadata=struct('essential_storage',marker);saved.essential_storage=marker;
    if r.policy.complete
        saved.correction_return_policy=struct('diagnostic_kind','runtime-object-descriptor', ...
            'source_class',r.policy.configuration.source_class,'settings',r.policy.configuration.settings);
    end
    assert(strcmp(OrbitContentIdentity_v3(out),OrbitContentIdentity_v3(orbit)), ...
        'PeriodicContinuation:CompactIdentity','Compact storage changed raw state/mode/parameter/period/full stride.');
    assert(strcmp(C1ScientificDigest_v3(EssentialBranchSolutionFile_v3.project(out,saved,metadata,context)),C1ScientificDigest_v3(r)), ...
        'PeriodicContinuation:CompactProjection','Compact clone must reproject exactly.');
end

function [row,record]=appendIsolatedNative(orbit,report,row,sourceFile,outputFile,indices,config,started,failure,child,work,~)
    file=member(config.method,'IsolatedFile','');if isempty(file),file=outputFile;end
    if ~strcmp(file,outputFile)&&~isfile(file)
        BranchSolutionFile_v3.initialize(file,struct('schema','native-isolated-admissions-v1','edges_claimed',false));
    end
    check(work);check(child);
    point=struct('component_identity',['isolated_',char(java.util.UUID.randomUUID)], ...
        'classification',storageLabel(report.classification), ...
        'nativeE',QuadrupedEnergy_v3.evaluate(orbit.initial_state,orbit.initial_mode,orbit.parameter), ...
        'signedmeanU',orbit.stride_displacement(1)/orbit.period,'edge_enabled',false, ...
        'provenance',struct('kind','native all-nine return outside continuation capture', ...
        'source_file',sourceFile,'source_indices',indices,'run_started_utc',started, ...
        'wrapper_failure',failure,'capture',row.capture, ...
        'point_check',member(row,'point_check',struct()),'edge_claimed',false));
    [~,index]=BranchSolutionFile_v3.append(file,orbit,report,point);
    [back,backReport,backPoint]=BranchSolutionFile_v3.loadSolution(file,index);
    assertPendingPublicEqual(orbit,back,0);
    assert(isequaln(report,backReport)&&isequaln(point,backPoint),'PeriodicContinuation:IsolatedReadback','Isolated result readback differs.');
    row.isolated_committed=true;row.isolated_storage_timely=left(child)>0&&left(work)>0;
    row.isolated_file=file;row.isolated_point=index;
    record=struct('file',file,'point',index,'component_identity',point.component_identity, ...
        'source_point',row.source_point,'attempt',row.attempt,'run_started_utc',started, ...
        'wrapper_accepted',false,'edge_claimed',false,'storage_timely',row.isolated_storage_timely, ...
        'whole_public_data_readback_verified',true);
end

function [orbits,reports,state]=intakePair(orbits,reports,symmetry,o,config,checkpoint,output,work,finish)
    state=struct('kind','source-intake','output_file',output,'configuration',config, ...
        'accepted',false,'status','source_intake','current_pair',[1,2], ...
        'next_step',o.InitialStep,'next_derivative_index',o.InitialDerivativeIndex, ...
        'controller_context',controllerContext(o,config.method.integration_profile), ...
        'started_utc',stamp(),'new_points',0,'service_transaction',struct(), ...
        'records',{{}},'source_intake',struct(),'pending_admission',struct(), ...
        'pending_batch',{{}},'batch_flush_attempted',false);
    if isfile(checkpoint)
        z=load(checkpoint,'summary');state=z.summary;clear z
        assert(strcmp(member(state,'kind',''),'source-intake')&&isequaln(state.configuration,config), ...
            'PeriodicContinuation:IntakeEpoch','An incomplete intake must resume in the exact source/method epoch.');
        if strcmp(state.status,'source_intake_refused'),return;end
    end
    for k=1:2
        if numel(state.records)<k
            if left(work)<=o.SeedSeconds+5,state.status='source_intake_whole_child_does_not_fit';saveCheckpoint(checkpoint,state,finish);return;end
            child=struct('deadline_unix_seconds',nowUnix()+o.SeedSeconds, ...
                'deadline_monotonic_ns',nano()+o.SeedSeconds*1e9,'IntegrationMaxStep',o.IntegrationMaxStep);
            state.service_transaction=struct('phase','prepared','id',char(java.util.UUID.randomUUID), ...
                'kind','literal_fixed_state_intake','source_slot',k,'pair',[1,2], ...
                'started_utc',stamp(),'limit',child);
            saveCheckpoint(checkpoint,state,finish);
            [fresh,report,evidence]=ValidatePeriodicContinuationSeed_v3(orbits{k},reports{k},symmetry,child,[]);
            state.records{k,1}=struct('orbit',fresh,'report',compactReport(report),'evidence',evidence, ...
                'original_timely',left(child)>0&&left(work)>0,'point_check_done',false, ...
                'point_check_pass',false,'point_check',struct());
            state.service_transaction.phase='returned';
            saveCheckpoint(checkpoint,state,finish); % Native return before optional adapter.
        end
        row=state.records{k};
        if row.evidence.accepted&&row.original_timely
            if ~row.point_check_done
                pass=true;proof=struct();
                if ~isempty(o.PointCheck)
                    limit=struct('deadline_unix_seconds',work.deadline_unix_seconds,'deadline_monotonic_ns',work.deadline_monotonic_ns);
                    [pass,proof]=runAdapter(o.PointCheck,row.orbit,row.report,limit,'source PointCheck');
                    assert(islogical(pass)&&isscalar(pass),'PeriodicContinuation:IntakeCheck','PointCheck must return a logical scalar.');
                end
                row.point_check_pass=pass;row.point_check=proof;row.point_check_done=true;
                row.stop_requested=false;row.stop_check=struct();
                if pass&&k==2&&~isempty(o.StopCheck)
                    [row.stop_requested,row.stop_check]=runAdapter(o.StopCheck,row.orbit,row.report,work,'source StopCheck');
                    assert(islogical(row.stop_requested)&&isscalar(row.stop_requested),'PeriodicContinuation:IntakeStop','StopCheck must return one logical.');
                end
                state.records{k}=row;saveCheckpoint(checkpoint,state,finish);
            end
            if row.point_check_pass
                orbits{k}=row.orbit;reports{k}=row.report;
                state.service_transaction.phase='committed';continue
            end
        end
        state.status='source_intake_refused';state.service_transaction.phase='returned';
        saveCheckpoint(checkpoint,state,finish);return
    end
    state.accepted=true;state.status='source_intake_complete';
    state.source_intake=struct('contract','fresh-fixed-state-nonedge-initializers-v1', ...
        'records',{{state.records{1}.evidence,state.records{2}.evidence}}, ...
        'native_service_calls',sum(cellfun(@(r)r.evidence.native_service_called,state.records)), ...
        'original_points_replaced',false,'old_physical_edge_requalified',false, ...
        'stop_requested',member(state.records{2},'stop_requested',false), ...
        'stop_check',member(state.records{2},'stop_check',struct()));
    state.service_transaction.phase='committed';
    saveCheckpoint(checkpoint,state,finish);
end

function cleanup=writerLease(output)
    folder=fileparts(output);if ~isfolder(folder),mkdir(folder);end
    lock=[output,'.continuation.lock'];file=java.io.File(lock);
    assert(file.createNewFile(),'PeriodicContinuation:WriterLease', ...
        'Another writer or an unreconciled stale lease owns %s. Confirm process closure before clearing it.',lock);
    token=sprintf('%d %s',feature('getpid'),char(java.util.UUID.randomUUID));
    fid=fopen(lock,'w');assert(fid>=0,'PeriodicContinuation:WriterLease','Cannot write owned lease.');
    fwrite(fid,token,'char');fclose(fid);
    cleanup=onCleanup(@()releaseWriterLease(lock,token));
end
function releaseWriterLease(lock,token)
    if isfile(lock)&&strcmp(fileread(lock),token),delete(lock);end
end

function [summary,index]=reconcileBatch(file,summary,index,checkpoint,work,finish)
    % A known returned queue can be reconciled without another solver call.
    queue=summary.pending_batch;count=numel(queue);
    if ~summary.batch_flush_attempted
        summary.work_limit=work;
        [summary,index]=flushBatch(file,summary,index,checkpoint,finish);return
    end
    assert(~isempty(summary.batch_publications),'PeriodicContinuation:BatchRecovery','Missing append intent; preserve this checkpoint.');
    publication=summary.batch_publications{end};before=publication.before_count;
    if numel(index.points)==before
        summary.batch_flush_attempted=false;summary.work_limit=work;
        [summary,index]=flushBatch(file,summary,index,checkpoint,finish);return
    end
    assert(numel(index.points)==before+count,'PeriodicContinuation:BatchRecovery', ...
        'Output count is neither the exact pre-append nor exact returned batch; preserve both for reconciliation.');
    ids=(before+(1:count)).';
    for pass=1:2
        [orbits,reports,metadata]=BranchSolutionFile_v3.loadSolutions(file,ids);
        for k=1:count
            assertPendingPublicEqual(queue{k}.orbit,orbits{k},0);
            assert(isequaln(queue{k}.compacted_report,reports{k})&&isequaln(queue{k}.point,metadata{k}), ...
                'PeriodicContinuation:BatchRecovery','Existing append does not match the literal returned queue.');
        end
    end
    summary.batch_publications{end}.installed_read2_verified=true;
    summary.batch_publications{end}.reconciled_without_solver=true;
    summary=applyCommittedTransition(summary,queue{end});
    summary.new_points=summary.new_points+count;summary.new_edges=summary.new_edges+count;
    summary.pending_batch={};summary.batch_flush_attempted=false;
    if returnedQueueMatches(summary,queue)
        summary.pending_admission=struct();summary.pending_result=struct();summary.service_transaction.phase='committed';
    end
    saveCheckpoint(checkpoint,summary,finish);
end

function assertMethodEpoch(context)
    for k=1:numel(context.source_epoch)
        r=context.source_epoch{k};
        assert(strcmp(which(r.name),r.file)&&strcmp(RoundSHA256_v3(r.file),r.sha256), ...
            'PeriodicContinuation:MethodChanged','A method changed during this invocation; preserve its returned data and start a new segment.');
    end
    for key={'PointCheck','StopCheck','PredictorFunction','PredictorCompareFunction'}
        r=context.(key{1});if isempty(r),continue;end
        assert(strcmp(RoundSHA256_v3(r.file),r.sha256),'PeriodicContinuation:AdapterChanged','A named adapter changed during this invocation.');
    end
end

function yes=returnedQueueMatches(summary,queue)
    result=member(summary,'pending_result',struct());
    yes=~isempty(fieldnames(result))&&~isempty(queue) ...
        &&isfield(result.row,'transaction_id')&&isfield(queue{end}.row,'transaction_id') ...
        &&strcmp(result.row.transaction_id,queue{end}.row.transaction_id);
end

function [answer,proof]=runAdapter(callback,orbit,report,limit,label)
    % Numeric arrays use MATLAB copy-on-write. Mutable native handles are
    % cloned; runtime report graphs are transported as existing plain data.
    copy=cloneObservation(orbit);view=compactReport(report);assertPlainTransport(view);
    before=observationCore(copy);[~,policyBefore]=RecordedReturnPolicy_v3(view);
    [answer,proof]=callback(copy,view,limit);
    assert(islogical(answer)&&isscalar(answer),'PeriodicContinuation:AdapterResult','%s must return one logical.',label);
    assert(isequaln(before,observationCore(copy)),'PeriodicContinuation:AdapterMutation','%s changed its read-only orbit view.',label);
    [~,policyAfter]=RecordedReturnPolicy_v3(view);
    assert(isequaln(policyBefore.configuration,policyAfter.configuration),'PeriodicContinuation:AdapterMutation','%s changed the complete policy.',label);
    C1ScientificDigest_v3(proof); % Reject function/model/handle captures.
end

function copy=cloneObservation(value)
    if isa(value,'HybridOrbit_v3')||isa(value,'Trajectory_v3')
        copy=feval(class(value));
        for key=properties(value).',copy.(key{1})=cloneObservation(value.(key{1}));end
    elseif isstruct(value)
        copy=value;keys=fieldnames(value);
        for k=1:numel(value),for j=1:numel(keys),copy(k).(keys{j})=cloneObservation(value(k).(keys{j}));end;end
    elseif iscell(value)
        copy=value;for k=1:numel(value),copy{k}=cloneObservation(value{k});end
    else
        assert(~isobject(value)||isstring(value),'PeriodicContinuation:AdapterObject','Unsupported mutable object in observational view.');
        copy=value;
    end
end

function core=observationCore(orbit)
    % A plain COW snapshot covers actual event batches/history/termination,
    % not just dense state arrays. It computes no trajectory digest.
    core=observationValue(orbit);
end

function out=observationValue(value)
    if isa(value,'HybridOrbit_v3')||isa(value,'Trajectory_v3')
        data=struct();for key=properties(value).',data.(key{1})=observationValue(value.(key{1}));end
        out=struct('source_class',class(value),'properties',data);
    elseif isstruct(value)
        out=value;keys=fieldnames(value);
        for k=1:numel(value),for j=1:numel(keys),out(k).(keys{j})=observationValue(value(k).(keys{j}));end;end
    elseif iscell(value)
        out=value;for k=1:numel(value),out{k}=observationValue(value{k});end
    else,out=value;end
end

function records=pairRecords(a,b,ra,rb)
    records=cell(2,1);orbits={a,b};reports={ra,rb};
    for k=1:2
        orbit=orbits{k};[~,policy]=RecordedReturnPolicy_v3(reports{k});
        records{k}=struct('raw_state14',orbit.initial_state,'parameter',orbit.parameter, ...
            'mode',orbit.initial_mode,'period',orbit.period,'stride',orbit.stride_displacement, ...
            'section',sectionRecord(orbit.section_chart),'classification',classificationRecord(reports{k}.classification), ...
            'policy',policy.configuration, ...
            'all_nine',reports{k}.acceptance_gates);
    end
end

function summary=applyCommittedTransition(summary,entry)
    assert(isfield(entry,'controller_transition'),'PeriodicContinuation:ControllerTransaction', ...
        'A committed point requires its already-computed next controller and stop decision.');
    transition=entry.controller_transition;
    summary.current_pair=transition.current_pair;
    summary.current_pair_records=transition.pair_records;
    summary.next_step=transition.next_step;
    summary.next_derivative_index=transition.next_derivative_index;
    summary.apex_height_policy=transition.apex_height_policy;
    summary.last_stop_requested=transition.stop_requested;
    summary.last_stop_check=transition.stop_check;
end

function out=thinFailureReport(report)
    % Known-negative history is not an archive of map/FD/iteration tapes.
    % The actual returned candidate was durably held before this projection.
    out=struct();keys={'schema_version','status','accepted','failure_stage', ...
        'primary_failure','replay_failure','finalization_failure','full_closure', ...
        'full_closure_residual','final_candidate','final_coordinates','final_residual', ...
        'final_scaled_norm','final_physical_norm','acceptance_gates','elapsed_seconds', ...
        'constraint_residual','last_finite_state','last_accepted_state', ...
        'delegated_residual_definition','continuation_acquisition'};
    for k=1:numel(keys)
        if isfield(report,keys{k}),out.(keys{k})=boundedDiagnostic(report.(keys{k}));end
    end
    if isfield(report,'solver')
        root=report.solver;selected=struct();
        for key={'status','converged','primaryConverged','state','mode','residual', ...
                'residualNorm','exitflag','primaryExitflag','primaryMessage', ...
                'primaryErrorIdentifier','message','lastFiniteEvaluatedBase','lastAcceptedIterate','finalJacobian'}
            if isfield(root,key{1})
                value=root.(key{1});
                if ismember(key{1},{'lastFiniteEvaluatedBase','lastAcceptedIterate'})&&isstruct(value)&&isfield(value,'diagnostic_info'),value=rmfield(value,'diagnostic_info');end
                selected.(key{1})=boundedDiagnostic(value);
            end
        end
        output=member(root,'output',struct());counters=struct();
        for key={'iterations','funcCount','functionEvaluations','invalidEvaluations','initialJacobianUsed'}
            if isfield(output,key{1}),counters.(key{1})=boundedDiagnostic(output.(key{1}));end
        end
        selected.output=counters;out.solver=selected;
    end
    out.diagnostic_storage=struct('schema','bounded-continuation-failure-head-v1', ...
        'dense_map_replay_FD_iteration_and_classifier_tapes_retained',false, ...
        'scope','Final/last-finite states, selected coordinates/residual/J/counters/gates and status only. No physical admission is created.');
end

function out=boundedDiagnostic(value)
    if isnumeric(value)||islogical(value)
        if numel(value)<=1024,out=value;
        else,out=struct('omitted','large diagnostic array','class',class(value),'size',size(value));end
    elseif ischar(value)||isstring(value)
        if numel(value)<=4096,out=value;else,out='[long diagnostic text omitted]';end
    elseif isstruct(value)
        if numel(value)>16
            out=struct('omitted','diagnostic struct tape','count',numel(value));return
        end
        out=value;keys=fieldnames(value);
        for k=1:numel(value),for j=1:numel(keys),out(k).(keys{j})=boundedDiagnostic(value(k).(keys{j}));end;end
    elseif iscell(value)
        if numel(value)>16,out=struct('omitted','diagnostic cell tape','count',numel(value));return;end
        out=value;for k=1:numel(value),out{k}=boundedDiagnostic(value{k});end
    else,out=struct('omitted','runtime diagnostic','class',class(value));end
end

function assertPlainTransport(value)
    if isstruct(value)
        keys=fieldnames(value);
        for k=1:numel(value),for j=1:numel(keys),assertPlainTransport(value(k).(keys{j}));end;end
    elseif iscell(value)
        for k=1:numel(value),assertPlainTransport(value{k});end
    else
        assert(isnumeric(value)||islogical(value)||ischar(value)||isstring(value), ...
            'PeriodicContinuation:AdapterReport','Observational reports must contain plain values, not mutable runtime captures.');
    end
end

function out=sectionRecord(value)
    out=struct();
    for key={'id','geometry','crossing_orientation','boundary_ownership','translational_gauge','BL_touchdowns_per_return'}
        if isfield(value,key{1}),out.(key{1})=value.(key{1});end
    end
end

function out=classificationRecord(value)
    out=struct();
    for key={'contract_version','validated_gait_type','flight_count_certain','flight_count', ...
            'canonical_point_label','canonical_label_qualified'}
        if isfield(value,key{1}),out.(key{1})=value.(key{1});end
    end
end
