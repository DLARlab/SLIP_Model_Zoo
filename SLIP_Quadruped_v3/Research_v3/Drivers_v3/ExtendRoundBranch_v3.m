function result=ExtendRoundBranch_v3(seedKind,seedIndex,direction,cfg,outputDirectory,maxWallSeconds,seedDescriptor)
%EXTENDROUNDBRANCH_V3 Append physical arclength batches, never call caps endpoints.
% A saved endpoint and tangent are reused and its shared seam is discarded.
% Historical checkpoints are read-only; the new branch is versioned here.
    v3=V3Root_v3(mfilename('fullpath'));outputDirectory=V3OutputPath_v3(outputDirectory);
    if nargin<7,seedDescriptor=struct('artifact','','variable','solution','node','','symmetry','pronk');end
    symmetry=seedDescriptor.symmetry;
    if isempty(symmetry),symmetry='pronk';end
    if ~isfolder(V3Path_v3(outputDirectory)),mkdir(V3Path_v3(outputDirectory));end
    fdRegistration=fullfile(v3,'Research_v3','next_round','restricted_continuation_fd_registration.json');
    if ~isfile(V3Path_v3(fdRegistration))
        fdPolicy=struct('schema_version','prospective-restricted-FD-repair-v3-1', ...
            'registered_utc',char(datetime('now','TimeZone','UTC')), ...
            'measured_problem','First240-second continuation slice retained20old points but appendedzero; repeated multi-grid tangent/corrector derivatives dominated work.', ...
            'repair','One h=1e-4 candidate with internal h/2 check, same operator for corrector and tangent, Broyden reuse/refresh5.', ...
            'relative_candidate_steps',1e-4,'maximum_relative_error',.001, ...
            'independent_full_closure_tolerance',cfg.acceptance.full_closure,'acceptance_tolerances_changed',false, ...
            'scope','Synchronized-pronk continuation only; not a full-space derivative or stability certificate.', ...
            'evidence_folder','Research_v3/next_round/workflow');
        RoundJSON_v3(fdRegistration,fdPolicy);
    end
    policyFile=fullfile(v3,'Research_v3','next_round','adaptive_continuation_registration.json');
    if ~isfile(V3Path_v3(policyFile))
        policy=struct('schema_version','prospective-adaptive-continuation-v3-1', ...
            'registered_utc',char(datetime('now','TimeZone','UTC')), ...
            'validation_initial_step',.003,'validation_maximum_step',.02, ...
            'first_full_step_after_validated_resume',.02,'first_full_maximum_step',.05, ...
            'subsequent_batch_growth',1.5,'full_maximum_step',.1,'minimum_recovery_step',1e-6, ...
            'acceptance_tolerances_changed',false, ...
            'semantics','Larger prospective arc steps after checked resume; failed corrections replay/chart/tangent shrink inside production recovery.');
        RoundJSON_v3(policyFile,policy);
    end
    file=fullfile(outputDirectory,'branch.mat');historical=fullfile(v3,'Research_v3','runs','full');
    previous=struct('points',[]);origin='';
    if isfile(V3Path_v3(file)),loaded=load(V3Path_v3(file),'branch');previous=loaded.branch;
    elseif strcmp(seedKind,'imported_PK')
        origin=fullfile(historical,sprintf('family_%+d.mat',direction));loaded=load(V3Path_v3(origin),'branch');previous=loaded.branch;
    end
    if ~isempty(previous.points),seed=previous.points(end).orbit;
    else
        if strcmp(seedKind,'recovered_source')
            origin=fullfile(v3,seedDescriptor.artifact);loaded=load(V3Path_v3(origin),seedDescriptor.variable);
            seed=loaded.(seedDescriptor.variable);
        elseif strcmp(seedKind,'restricted_PIP_daughter')
            origin=fullfile(historical,sprintf('pronk_daughter_v2_%d_%+.6g.mat',seedIndex,.01));
            loaded=load(V3Path_v3(origin),'replayOrbit','orbit');seed=loaded.replayOrbit;if isempty(seed),seed=loaded.orbit;end
        else,error('ExtendRoundBranch_v3:Seed','Unknown seed kind.');end
        if isempty(seed),error('ExtendRoundBranch_v3:Seed','Saved daughter was not accepted.');end
    end
    p=seed.parameter;q=seed.initial_mode;
    if norm(p-cfg.baseline_v3_parameters(:),inf)>cfg.acceptance.parameter
        error('ExtendRoundBranch_v3:Parameters','A parameter homotopy point cannot enter the target-model network.');
    end
    simulator=HybridSimulator_v3(struct('RelTol',cfg.integration.relative_tolerance,'AbsTol',cfg.integration.absolute_tolerance));
    policy=seed.return_policy;
    if ~isa(policy,'ReturnPolicyBase_v3')
        occurrence=1;
        if isstruct(seed.section_chart)&&isfield(seed.section_chart,'BL_touchdowns_per_return'),occurrence=seed.section_chart.BL_touchdowns_per_return;end
        policy=BLMarkedApexReturnPolicy_v3(struct('BLTouchdownsPerReturn',occurrence));
    end
    system=Quadrupedal_Dynamics_v3();map=PoincareMap_v3(system,PoincareSection_v3.apex(4), ...
        simulator,policy,struct('MaxReturnTime',cfg.domain.primitive_period_max, ...
        'MaxCycleEvents',cfg.domain.event_count_max,'MaxSectionCrossings',64));
    problem=PeriodicOrbitResidual_v3(map,seed.initial_state);
    [replayed,gate]=PeriodicSolutionSolver_v3(seed,struct('Symmetry',symmetry, ...
        'Integration',struct('RelTol',cfg.integration.relative_tolerance,'AbsTol',cfg.integration.absolute_tolerance), ...
        'ReplayIntegration',struct('RelTol',cfg.integration.replay_relative_tolerance,'AbsTol',cfg.integration.replay_absolute_tolerance), ...
        'Acceptance',struct('FullClosureTolerance',cfg.acceptance.full_closure), ...
        'MaxReturnTime',cfg.domain.primitive_period_max,'MaxCycleEvents',cfg.domain.event_count_max, ...
        'MaxWallSeconds',maxWallSeconds));
    if isempty(replayed)
        result=struct('state','retryable_failure','scientific_status','restart_independent_replay_failed', ...
            'new_points',0,'function_evaluations',0,'restart_gate',gate,'message','Restart failed the shared periodic-solution service.');
        RoundSave_v3(fullfile(outputDirectory,'restart_failure.mat'),struct('result',result));return
    end
    countBefore=numel(previous.points);timer=tic;
    if strcmp(symmetry,'pronk')
        derivative=HybridFiniteDifferenceJacobian_v3(struct('RelativeCandidateSteps',1e-4, ...
            'MaximumRelativeError',.001,'FailurePolicy','nan'));
    else
        derivative=HybridFiniteDifferenceJacobian_v3(struct('FailurePolicy','nan'));
    end
    solver=RootSolver_v3(struct('MaxIterations',cfg.budgets.root_max_iterations, ...
        'MaxFunctionEvaluations',cfg.budgets.root_max_function_evaluations,'FunctionTolerance',1e-12, ...
        'ResidualAcceptanceTolerance',cfg.acceptance.reduced_residual,'UseBroyden',true,'JacobianRefreshInterval',5,'Jacobian',derivative));
    step=.003;maximumStep=.02;
    if strcmp(cfg.profile,'full')
        validationRun=fullfile(v3,'Research_v3','next_round','tasks','validation','PK_continuation_m1','continuation.json');
        if isfile(V3Path_v3(validationRun))
            verified=jsondecode(fileread(V3Path_v3(validationRun)));
            if isfield(verified,'new_points')&&verified.new_points>0 ...
                    &&verified.shared_seam_deduplicated&&verified.max_full_closure<=cfg.acceptance.full_closure
                step=.02;maximumStep=.05;
            end
        end
        resumeAudit=fullfile(v3,'Research_v3','next_round','workflow_02','workflow_audit.json');
        if isfile(V3Path_v3(resumeAudit))
            verified=jsondecode(fileread(V3Path_v3(resumeAudit)));
            if verified.all_passed&&verified.resume.first_new_points>0&&verified.resume.second_new_points>0 ...
                    &&verified.resume.seam_deduplicated&&verified.resume.tangent_reused ...
                    &&verified.resume.full_closure<=cfg.acceptance.full_closure
                step=.02;maximumStep=.05;
            end
        end
        priorRun=fullfile(outputDirectory,'continuation.json');
        if isfile(V3Path_v3(priorRun))
            last=jsondecode(fileread(V3Path_v3(priorRun)));
            if isfield(last,'new_points')&&last.new_points>0&&isfield(last,'requested_step')
                step=max(.02,min(.1,1.5*last.requested_step));maximumStep=.1;
            end
        end
    end
    options=struct('Symmetry',symmetry,'RootSolver',solver,'Jacobian',derivative,'ReuseCorrectorJacobian',true,'StepSize',step, ...
        'MinimumStepSize',1e-6,'MaximumStepSize',maximumStep,'MaxPoints',cfg.budgets.continuation_batch_points, ...
        'InitialDirection',direction,'ParameterBounds',cfg.domain.energy.', ...
        'MaxWallSeconds',max(1,maxWallSeconds-gate.elapsed_seconds), ...
        'CheckpointFunction',@(new)checkpoint(new));
    if ~isempty(previous.points),options.InitialTangent=previous.points(end).tangent;end
    [new,family]=FixedParameterContinuation_v3.run(problem,problem.packState(replayed.initial_state),p,q,options); %#ok<ASGLU>
    branch=merge(previous,new);branch=CompactResearchBranch_v3(branch);
    classifications=cell(1,numel(branch.points));for k=1:numel(branch.points),classifications{k}=GaitIdentification_v3(branch.points(k).orbit);end
    RoundSave_v3(file,struct('branch',branch,'classifications',{classifications},'restart_gate',gate));
    countAfter=numel(branch.points);newCount=max(0,countAfter-max(1,countBefore));
    result=struct('state','partial_checkpoint','scientific_status','continued_branch_attachment_unresolved', ...
        'seed_kind',seedKind,'seed_index',seedIndex,'direction',direction,'source_checkpoint',origin, ...
        'seed_artifact',seedDescriptor.artifact,'seed_node',seedDescriptor.node,'symmetry',symmetry, ...
        'previous_count',countBefore,'accepted_count',countAfter,'new_points',newCount, ...
        'fresh_seed_records',double(countBefore==0&&countAfter>0), ...
        'shared_seam_deduplicated',countBefore>0,'restart_tangent_reused',countBefore>0, ...
        'requested_step',step,'maximum_step',maximumStep, ...
        'energy',arrayfun(@(point)point.p(11),branch.points),'termination_reason',char(branch.terminationReason), ...
        'arclength_start',branch.points(1).arclength,'arclength_end',branch.points(end).arclength, ...
        'max_full_closure',max(arrayfun(@(point)norm(point.orbit.poincare_state(2:end)-point.orbit.initial_state(2:end),inf),branch.points)), ...
        'function_evaluations',sum(arrayfun(@pointEvaluations,new.points))+sum(arrayfun(@pointEvaluations,new.failures))+gateEvaluations(gate), ...
        'wall_seconds',toc(timer)+gate.elapsed_seconds,'batch_limit_is_branch_endpoint',false, ...
        'primitive_period',arrayfun(@(point)point.orbit.period,branch.points), ...
        'mean_speed',arrayfun(@(point)point.orbit.stride_displacement(1)/point.orbit.period,branch.points), ...
        'gait_labels',{cellfun(@(item)char(item.label),classifications,'UniformOutput',false)}, ...
        'ancestry_claimed',false,'branch_artifact','branch.mat');
    if newCount==0,result.state='retryable_failure';result.scientific_status='continuation_batch_needs_diagnosed_recovery';end
    RoundJSON_v3(fullfile(outputDirectory,'continuation.json'),result);
    function checkpoint(newer)
        merged=merge(previous,newer);merged=CompactResearchBranch_v3(merged);
        RoundSave_v3(file,struct('branch',merged));
    end
end
function branch=merge(previous,newer)
    branch=newer;if isempty(previous.points),return;end
    if isempty(newer.points),branch=previous;return;end
    delta=norm(newer.points(1).orbit.initial_state(2:end)-previous.points(end).orbit.initial_state(2:end),inf);
    if delta>1e-7,error('ExtendRoundBranch_v3:Seam','Restart correction moved the seam; an overlap transport is required before appending.');end
    next=newer.points;
    for k=2:numel(next)
        next(k).index=numel(previous.points)+k-1;next(k).arclength=previous.points(end).arclength+next(k).arclength;
    end
    branch.points=[previous.points,next(2:end)];branch.count=numel(branch.points);
    if isfield(previous,'failures'),branch.failures=[previous.failures,newer.failures];end
    branch=PseudoArclengthContinuation_v3().refreshBranchSummary(branch);
    branch.resume_note='Accepted endpoint/tangent reused, chronological arclength appended, one shared seam deduplicated.';
end
function value=pointEvaluations(point)
    value=0;
    if isfield(point,'solverInfo')
        info=point.solverInfo;
        if isfield(info,'functionEvaluationCount'),value=info.functionEvaluationCount;
        elseif isfield(info,'solver')&&isfield(info.solver,'functionEvaluationCount'),value=info.solver.functionEvaluationCount;end
    end
end
function value=gateEvaluations(gate)
    value=0;if isfield(gate,'solver')&&isfield(gate.solver,'functionEvaluationCount'),value=gate.solver.functionEvaluationCount;end
end
