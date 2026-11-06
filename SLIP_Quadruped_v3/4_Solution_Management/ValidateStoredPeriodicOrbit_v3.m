function [solution,report,evidence]=ValidateStoredPeriodicOrbit_v3(sourceOrbit,sourceReport,configuration,B)
%VALIDATESTOREDPERIODICORBIT_V3 New fixed-energy point admission, zero correction.
% Literal state/p/q, saved complete BL policy and retained solved E are used.
% Old PAL planes/P edges are neither reconstructed nor requalified. The exact
% pinned PSS post-root acceptance block/helpers below retain all nine gates.
    assert(nargin==4&&isa(sourceOrbit,'HybridOrbit_v3')&&isstruct(sourceReport)&&isscalar(sourceReport) ...
        &&isstruct(configuration)&&isscalar(configuration),'StoredAdmission:Inputs','Use one literal source orbit/report and explicit configuration.');
    keys={'Energy';'Symmetry';'ActiveCoordinateIndices';'FamilyConstraint';'Constraint';'ResidualScale';'Integration'; ...
        'ReplayIntegration';'Acceptance';'MaxReturnTime';'MaxCycleEvents';'MaxSectionCrossings';'MaxWallSeconds'};
    assert(isequal(sort(fieldnames(configuration)),sort(keys))&&strcmp(configuration.Symmetry,'none') ...
        &&strcmp(configuration.FamilyConstraint,'fixed-energy')&&isempty(configuration.Constraint), ...
        'StoredAdmission:Contract','Use the NEW fixed-energy/Symmetry none point contract, without inferring an old PAL plane.');
    donor=which('PeriodicSolutionSolver_v3');donorSHA='9736edd09857c2f67ad0c2b61a5099ab82a221b81d36932866577b80de2492d0';
    assert(~isempty(donor)&&strcmp(RoundSHA256_v3(donor),donorSHA),'StoredAdmission:DonorEpoch','Exact PSS donor semantics must remain unchanged.');
    assert(isstruct(B)&&isscalar(B)&&isfield(B,'capture')&&B.capture.pid==feature('getpid'), ...
        'StoredAdmission:BudgetPID','Use current-process calibration of the same original grant.');
    validateattributes(configuration.MaxWallSeconds,{'double'},{'real','finite','scalar','positive'});
    nowUTC=admissionUTC();nowMono=admissionNano();
    assert(min(B.research_deadline_unix_seconds-nowUTC,(B.research_deadline_monotonic_ns-nowMono)/1e9)>configuration.MaxWallSeconds+2, ...
        'StoredAdmission:WholeFit','Require the whole declared root-free admission to fit the unchanged science clocks.');
    limits=struct('deadline_unix_seconds',nowUTC+configuration.MaxWallSeconds,'deadline_monotonic_ns',nowMono+configuration.MaxWallSeconds*1e9);
    options=configuration;acceptance=configuration.Acceptance;
    akeys={'FullClosureTolerance';'EnergyTolerance';'ConstraintTolerance';'FamilyTolerance';'StanceTolerance'; ...
        'PrimitiveStateTolerance';'PrimitiveEventTolerance';'MaxCover';'RequirePrimitive'};
    assert(isstruct(acceptance)&&isscalar(acceptance)&&isequal(sort(fieldnames(acceptance)),sort(akeys)) ...
        &&isfield(sourceReport,'acceptance')&&isequaln(acceptance,sourceReport.acceptance), ...
        'StoredAdmission:Acceptance','Keep exact recorded acceptance fields and values, without inventing or loosening a gate.');
    assert(isfield(sourceReport,'options')&&isstruct(sourceReport.options)&&isscalar(sourceReport.options) ...
        &&isfield(sourceReport.options,'AugmentedParameter'),'StoredAdmission:EnergyOrigin','Retained augmented p/E authority is required.');
    augmented=sourceReport.options.AugmentedParameter;
    assert(isa(augmented,'double')&&isreal(augmented)&&numel(augmented)==11&&all(isfinite(augmented(:))) ...
        &&isequaln(augmented(1:10),sourceOrbit.parameter(:)), ...
        'StoredAdmission:PhysicalBinding','Keep exact retained physical p10; entry11 remains the historical initial free-energy guess.');
    assert(isfield(sourceReport,'family_conditions')&&isstruct(sourceReport.family_conditions)&&isscalar(sourceReport.family_conditions) ...
        &&isfield(sourceReport.family_conditions,'requested_energy')&&isfield(sourceReport,'final_coordinates'), ...
        'StoredAdmission:SolvedEnergyOrigin','Require the retained actual requested energy and solved coordinates.');
    solvedEnergy=sourceReport.family_conditions.requested_energy;solvedCoordinates=sourceReport.final_coordinates;
    assert(isa(solvedEnergy,'double')&&isreal(solvedEnergy)&&isscalar(solvedEnergy)&&isfinite(solvedEnergy) ...
        &&isa(solvedCoordinates,'double')&&isreal(solvedCoordinates)&&isvector(solvedCoordinates)&&numel(solvedCoordinates)>1 ...
        &&all(isfinite(solvedCoordinates(:)))&&isequaln(solvedCoordinates(end),solvedEnergy)&&isequaln(configuration.Energy,solvedEnergy), ...
        'StoredAdmission:EnergyBinding','Bind exact retained family_conditions.requested_energy and solved final_coordinates(end), never the initial p11 guess or recomputed convenient energy.');
    original=struct('state',sourceOrbit.initial_state,'mode',sourceOrbit.initial_mode,'parameter',sourceOrbit.parameter, ...
        'period',sourceOrbit.period,'stride',sourceOrbit.stride_displacement,'native_id',OrbitContentIdentity_v3(sourceOrbit));
    [policy,policyEvidence]=RecordedReturnPolicy_v3(sourceReport);
    assert(policyEvidence.complete&&isa(policy,'BLMarkedApexReturnPolicy_v3')&&strcmp(sourceOrbit.return_policy_name,policy.Name) ...
        &&isequal(sourceOrbit.return_multiplicity,policy.BLTouchdownsPerReturn), ...
        'StoredAdmission:Policy','Require actual complete saved BL policy/name/multiplicity, without name-only fallback.');
    seed=normalize(sourceOrbit);seed.return_policy=policy;seed.occurrence=policy.BLTouchdownsPerReturn;
    assert(isequaln(seed.state,original.state)&&isequaln(seed.mode,original.mode)&&isequaln(seed.parameter,original.parameter), ...
        'StoredAdmission:LiteralSeed','Reject source state/p/q normalization or shape/type changes.');
    [integration,correctionRuntime]=admissionClocked(configuration.Integration,limits);
    [replayIntegration,replayRuntime]=admissionClocked(configuration.ReplayIntegration,limits);
    solution=[];clock=tic;phase='fixed-state-acquisition';phaseClock=tic;
    report=struct('schema_version','root-free-fixed-energy-admission-v1','status','running','accepted',false, ...
        'seed',seed,'options',options,'acceptance',acceptance,'integration',integration,'replay_integration',replayIntegration, ...
        'correction_return_policy',policy,'effective_correction_ode',effectiveODE(integration),'effective_replay_ode',effectiveODE(replayIntegration), ...
        'full_closure',Inf,'full_closure_residual',[],'family_conditions',struct(),'classification',struct(),'primitive',struct(), ...
        'physical_inequalities',struct(),'independent_replay',struct(),'acceptance_gates',struct(),'replay_failure',struct(), ...
        'failure_stage','fixed-state-acquisition','retryable',false,'elapsed_seconds',0,'phase_timing',struct(), ...
        'solver',struct('root_solver_calls',0,'correction_performed',false,'coordinates_changed',false));
    evidence=struct('schema','root-free-stored-point-admission-evidence-v1','original_record',original, ...
        'donor_reference',struct('file',donor,'sha256',donorSHA),'configuration',configuration, ...
        'historical_options',sourceReport.options,'historical_family_conditions',member(sourceReport,'family_conditions',struct()), ...
        'historical_acceptance',sourceReport.acceptance,'historical_gates',member(sourceReport,'acceptance_gates',struct()), ...
        'complete_saved_policy',policyEvidence,'energy_origin',struct('path','sourceReport.family_conditions.requested_energy','value',solvedEnergy, ...
        'crosscheck_path','sourceReport.final_coordinates','crosscheck_index',numel(solvedCoordinates),'literal_solved_coordinates',solvedCoordinates, ...
        'historical_initial_augmented_parameter',augmented,'initial_free_E_guess_index',11,'initial_free_E_guess_is_fixed_target',false), ...
        'correction_runtime_registration',correctionRuntime,'replay_runtime_registration',replayRuntime, ...
        'root_solver_calls',0,'correction_performed',false,'historical_P_edges_requalified',false,'new_physical_edges_created',0, ...
        'old_PAL_plane_reconstructed',false,'point_contract','NEW fixed-energy point admission; historical PAL and P evidence remain literal.', ...
        'fresh_current_all9_PK',false,'fresh_record_bitwise_equal',false,'fresh_native_id','','source_posthash',false, ...
        'source_posthash_scope','Source object identity-bearing fields and pinned donor file only; the caller owns original FILE/SHA pre/post guards.', ...
        'completed',false,'failure',struct());
    try
        validateReplaySettings(report.effective_correction_ode,report.effective_replay_ode);admissionCheck(limits);
        map=makeMap(seed,integration,options);base=PeriodicOrbitResidual_v3(map,seed.state);
        family=EnergyFamilyResidual_v3(base,seed.state,seed.mode,seed.parameter, ...
            struct('Symmetry',options.Symmetry,'ClosureTolerance',acceptance.FullClosureTolerance));
        active=options.ActiveCoordinateIndices;if isempty(active),active=family.CoordinateIndices;end
        [found,positions]=ismember(active,family.CoordinateIndices);assert(all(found),'StoredAdmission:Coordinates','Use actual family coordinates only.');
        residual=ConstrainedEnergyResidual_v3(family,positions,options.Constraint,options.ResidualScale);
        u=family.packState(seed.state);candidate=u(positions);p=[seed.parameter;options.Energy];
        assert(isequaln(residual.fullState(candidate,p,seed.mode),seed.state), ...
            'StoredAdmission:NoProjection','Exact pack/lift roundtrip is required; no snapping, wrapping or symmetry projection.');
        [raw,finalInfo]=residual.evaluateWithInfo(candidate,p,seed.mode);admissionCheck(limits);
        report.initial_residual=raw;report.initial_evaluation=finalInfo;report.final_coordinates=candidate;report.augmented_parameter=p;
        report.final_candidate=seed.state;report.final_residual=raw;report.final_scaled_norm=physicalNorm(raw);
        report.final_physical_norm=physicalNorm(member(finalInfo,'physical_residual',raw));
        root=struct('residual',raw); % Plain donor gate input. No RootSolver is instantiated or called.
        candidateOrbit=residual.createOrbit(candidate,p,seed.mode,finalInfo);
        assert(isequaln(candidateOrbit.initial_state,original.state)&&isequaln(candidateOrbit.initial_mode,original.mode) ...
            &&isequaln(candidateOrbit.parameter,original.parameter),'StoredAdmission:CandidateLiteral','Fresh metadata may change T/stride, never source state/p/q.');
        report.phase_timing.fixed_state_acquisition_seconds=toc(phaseClock);
        phase='root_finalization';phaseClock=tic; % Literal donor label only; zero numerical root phases.
        replaySeed=normalize(candidateOrbit);replaySeed.provenance=seed.provenance;
        % Orbit metadata stores a policy name, not its configuration. Keep
        % the declared correction policy and occurrence for fresh replay.
        replaySeed.return_policy=map.ReturnPolicy;
        if isa(map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3')
            replaySeed.occurrence=map.ReturnPolicy.BLTouchdownsPerReturn;
        end
        % New map and simulator: no RootSolver objective cache or residual
        % evaluation is reused for acceptance.
        replayMap=makeMap(replaySeed,replayIntegration,options);
        report.failure_stage='independent-replay';
        report.replay_integration=replayMap.Simulator.Options;
        report.effective_replay_ode=effectiveODE(report.replay_integration);
        report.phase_timing.root_finalization_seconds=toc(phaseClock);
        phase='first_fresh_replay';phaseClock=tic;
        [next,replay]=replayMap.evaluate(candidateOrbit.initial_state, ...
            candidateOrbit.initial_mode,candidateOrbit.parameter);
        report.phase_timing.first_fresh_replay_seconds=toc(phaseClock);
        delta=next-candidateOrbit.initial_state;delta(1)=0;
        report.full_closure=norm(delta,inf);report.full_closure_residual=delta;
        replayProblem=PeriodicOrbitResidual_v3(replayMap,candidateOrbit.initial_state);
        phase='second_fresh_replay';phaseClock=tic;
        [~,details]=replayProblem.evaluateWithInfo(replayProblem.packState(candidateOrbit.initial_state), ...
            candidateOrbit.parameter,candidateOrbit.initial_mode);
        report.phase_timing.second_fresh_replay_seconds=toc(phaseClock);
        % createOrbit uses the second fresh return; retain both returns and
        % their difference to expose deterministic integration ownership.
        acceptedOrbit=replayProblem.createOrbit(replayProblem.packState(candidateOrbit.initial_state), ...
            candidateOrbit.parameter,candidateOrbit.initial_mode,details);
        report.independent_replay=details;
        report.independent_replay.first_replay_next_state=next;
        report.independent_replay.repeated_replay_difference=norm(details.next_state-next,inf);
        report.full_closure=max(report.full_closure,norm(details.next_state(2:end)-candidateOrbit.initial_state(2:end),inf));
        phase='physical_audit';phaseClock=tic;
        report.physical_inequalities=physicalAudit(acceptedOrbit);
        report.phase_timing.physical_audit_seconds=toc(phaseClock);
        phase='primitive_audit';phaseClock=tic;
        report.primitive=PrimitiveCycleCheck_v3(acceptedOrbit,struct('MaxCover',acceptance.MaxCover, ...
            'StateTolerance',acceptance.PrimitiveStateTolerance, ...
            'EventPhaseTolerance',acceptance.PrimitiveEventTolerance));
        report.primitive=properApexAudit(report.primitive,details.map_info,acceptedOrbit, ...
            replayIntegration,options,acceptance);
        report.phase_timing.primitive_audit_seconds=toc(phaseClock);
        phase='classification';phaseClock=tic;
        report.classification=GaitIdentification_v3(acceptedOrbit,struct('PrimitiveOptions', ...
            struct('MaxCover',acceptance.MaxCover,'StateTolerance',acceptance.PrimitiveStateTolerance, ...
            'EventPhaseTolerance',acceptance.PrimitiveEventTolerance)));
        report.phase_timing.classification_seconds=toc(phaseClock);
        phase='family_and_gates';phaseClock=tic;
        report.period=acceptedOrbit.period;report.drift=acceptedOrbit.stride_displacement;
        report.chart_signature=member(replay,'section_chart',struct());
        report.event_signature=replay.section_relative_event_signature;
        report.family_conditions=familyConditions(residual,candidate,p,finalInfo,root.residual, ...
            acceptedOrbit,options,acceptance);
        report.acceptance_gates=struct( ...
            'full_closure',finiteWithin(report.full_closure,acceptance.FullClosureTolerance), ...
            'mode_closure',logical(replay.discrete_closed), ...
            'target_energy',report.family_conditions.target_energy_passed, ...
            'trajectory_energy_variation',finiteWithin(report.physical_inequalities.maximum_energy_error,acceptance.EnergyTolerance), ...
            'unscaled_family_equations',report.family_conditions.unscaled_equations_passed, ...
            'family_constraint',report.family_conditions.constraint_passed, ...
            'physical_inequalities',logical(replay.admissible)&&finiteWithin(report.physical_inequalities.maximum_stance_constraint,acceptance.StanceTolerance), ...
            'primitive_identity',~acceptance.RequirePrimitive||report.primitive.status=="primitive_within_checked_bound", ...
            'replay_determinism',finiteWithin(report.independent_replay.repeated_replay_difference,acceptance.FullClosureTolerance));
        valid=all(structfun(@(value)logical(value),report.acceptance_gates));
        if valid
            solution=acceptedOrbit;report.accepted=true;report.status='accepted';
            report.failure_stage='';report.retryable=false;
        else
            if ~report.acceptance_gates.full_closure
                report.status='failed_full_closure';
            else
                report.status='failed_replay';
            end
            report.replay_failure=struct('identifier','PeriodicSolutionSolver_v3:Acceptance', ...
                'message','Fresh closure, unscaled family equations, requested energy, energy variation, stance, constraint, determinism or primitive-period gate failed.');
        end
        report.phase_timing.family_and_gates_seconds=toc(phaseClock);
        admissionCheck(limits);evidence.fresh_current_all9_PK=admissionPK(report);
        if ~isempty(solution)
            assert(isequaln(solution.initial_state,original.state)&&isequaln(solution.initial_mode,original.mode)&&isequaln(solution.parameter,original.parameter), ...
                'StoredAdmission:AcceptedLiteral','Accepted replay must preserve literal source state/p/q.');
            evidence.fresh_native_id=OrbitContentIdentity_v3(solution);
            evidence.fresh_record_bitwise_equal=isequaln(solution.period,original.period)&&isequaln(solution.stride_displacement,original.stride) ...
                &&strcmp(evidence.fresh_native_id,original.native_id);
            evidence.fresh_period=solution.period;evidence.fresh_stride=solution.stride_displacement;
            evidence.period_difference=solution.period-original.period;evidence.stride_difference=solution.stride_displacement-original.stride;
        end
        evidence.completed=true;
    catch exception
        solution=[];report.accepted=false;report.status='root_free_admission_failed';report.replay_failure=failureDetails(exception);
        report.phase_timing.interrupted_phase=phase;evidence.failure=report.replay_failure;
    end
    assert(strcmp(RoundSHA256_v3(donor),donorSHA),'StoredAdmission:DonorPost','The exact donor changed during admission.');
    assert(isequaln(sourceOrbit.initial_state,original.state)&&isequaln(sourceOrbit.initial_mode,original.mode) ...
        &&isequaln(sourceOrbit.parameter,original.parameter)&&isequaln(sourceOrbit.period,original.period) ...
        &&isequaln(sourceOrbit.stride_displacement,original.stride)&&strcmp(OrbitContentIdentity_v3(sourceOrbit),original.native_id), ...
        'StoredAdmission:SourcePost','The source identity-bearing record must remain unchanged.');
    evidence.source_posthash=true;report.elapsed_seconds=toc(clock);
end
function [profile,observation]=admissionClocked(profile,limits)
    assert(isstruct(profile)&&isscalar(profile)&&isfield(profile,'ODEOptions')&&isstruct(profile.ODEOptions)&&isscalar(profile.ODEOptions), ...
        'StoredAdmission:ExplicitIntegration','Use explicit integration settings with nested ODE options.');
    old=member(profile.ODEOptions,'OutputFcn',[]);
    supported=isempty(old)||(isstruct(old)&&isscalar(old)&&isfield(old,'diagnostic_kind') ...
        &&strcmp(old.diagnostic_kind,'runtime-function-descriptor')&&isfield(old,'requires_runtime_reconstruction')&&isequal(old.requires_runtime_reconstruction,true));
    assert(supported,'StoredAdmission:RuntimeCallback','Only empty or declared runtime descriptors may be replaced by the fresh owned deadline callback.');
    assert(isfield(profile,'ODESolver'),'StoredAdmission:ExplicitODESolver','Use the actual declared ODE solver.');
    solverDescriptor=profile.ODESolver;
    if isstruct(solverDescriptor)
        assert(isscalar(solverDescriptor)&&all(isfield(solverDescriptor,{'diagnostic_kind','signature','requires_runtime_reconstruction'})) ...
            &&strcmp(solverDescriptor.diagnostic_kind,'runtime-function-descriptor')&&strcmp(solverDescriptor.signature,'ode45') ...
            &&isequal(solverDescriptor.requires_runtime_reconstruction,true), ...
            'StoredAdmission:SolverDescriptor','Only the exact recorded ode45 descriptor has a registered runtime reconstruction.');
        profile.ODESolver=@ode45;
    else
        assert(isa(solverDescriptor,'function_handle')&&isequal(solverDescriptor,@ode45), ...
            'StoredAdmission:RegisteredSolver','This immediate validation registers ode45 only, without a fallback solver.');
        solverDescriptor=struct('diagnostic_kind','runtime-function-descriptor','signature','ode45','requires_runtime_reconstruction',true);
    end
    observation=struct('replaced_output_descriptor',old,'registered_solver_descriptor',solverDescriptor,'fresh_clock_limits',limits, ...
        'scope','Only known ode45 and the runtime OutputFcn are reconstructed; explicit physical integration/event values stay unchanged.');
    profile.ODEOptions=odeset(profile.ODEOptions,'OutputFcn',@(t,y,flag)admissionOutput(t,y,flag,limits));
end
function value=admissionOutput(~,~,~,limits)
    value=double(min(limits.deadline_unix_seconds-admissionUTC(),(limits.deadline_monotonic_ns-admissionNano())/1e9)<=0);
end
function admissionCheck(limits)
    assert(min(limits.deadline_unix_seconds-admissionUTC(),(limits.deadline_monotonic_ns-admissionNano())/1e9)>0, ...
        'StoredAdmission:Budget','The declared root-free admission clocks expired.');
end
function value=admissionUTC(),value=double(java.time.Instant.now().toEpochMilli())/1000;end
function value=admissionNano(),value=double(java.lang.System.nanoTime());end
function yes=admissionPK(r)
    keys={'full_closure','mode_closure','target_energy','trajectory_energy_variation','unscaled_family_equations','family_constraint','physical_inequalities','primitive_identity','replay_determinism'};
    gates=member(r,'acceptance_gates',struct());g=member(r,'classification',struct());[~,version]=GaitSemanticTable_v3();
    yes=isequal(member(r,'accepted',false),true)&&all(isfield(gates,keys))&&strcmp(member(g,'contract_version',''),version) ...
        &&strcmp(member(g,'validated_gait_type',''),'PK')&&strcmp(member(g,'canonical_point_label',''),'PK') ...
        &&isequal(member(g,'canonical_label_qualified',false),true)&&isequal(member(g,'flight_count_certain',false),true)&&isequal(member(g,'flight_count',NaN),1);
    for k=1:numel(keys),yes=yes&&isequal(member(gates,keys{k},false),true);end
end

function out=failureDetails(exception)
    % Retain the ORIGINAL call's stack/causes before an optional diagnostic.
    % A later plain-horizon trace is not the same BL stop/rearm execution.
    causes=cell(numel(exception.cause),1);
    for k=1:numel(causes),causes{k}=failureDetails(exception.cause{k});end
    out=struct('identifier',exception.identifier,'message',exception.message, ...
        'stack',exception.stack,'extended_report',getReport(exception,'extended','hyperlinks','off'), ...
        'causes',{causes});
end

function validateReplaySettings(correction,replay)
    % The delegated map, not an unused service default, defines correction.
    incompatible=~isscalar(correction.AbsTol)&&~isscalar(replay.AbsTol) ...
        &&numel(correction.AbsTol)~=numel(replay.AbsTol);
    if incompatible||replay.RelTol>=correction.RelTol||any(replay.AbsTol(:)>=correction.AbsTol(:))
        error('PeriodicSolutionSolver_v3:ReplayTolerances', ...
            'Independent replay must use tighter ODE tolerances than the effective correction map.');
    end
end

function effective=effectiveODE(settings)
    % Match EventDetector.configureOdeOptions: nested/top-level minima.
    nested=member(settings,'ODEOptions',odeset());
    rel=odeget(nested,'RelTol');absolute=odeget(nested,'AbsTol');step=odeget(nested,'MaxStep');
    if isfield(settings,'RelTol')&&~isempty(settings.RelTol)
        if isempty(rel),rel=settings.RelTol;else,rel=min(rel,settings.RelTol);end
    end
    if isfield(settings,'AbsTol')&&~isempty(settings.AbsTol)
        if ~isempty(absolute)&&~isscalar(absolute)&&~isscalar(settings.AbsTol)&&numel(absolute)~=numel(settings.AbsTol)
            error('PeriodicSolutionSolver_v3:IntegrationTolerance','Absolute tolerance vectors must agree in length.');
        end
        if isempty(absolute),absolute=settings.AbsTol(:);else,absolute=min(absolute(:),settings.AbsTol(:));end
    end
    if isempty(rel),rel=1e-3;end
    if isempty(absolute),absolute=1e-6;end
    if ~isscalar(rel)||~isfinite(rel)||rel<=0||any(~isfinite(absolute(:))|absolute(:)<=0)
        error('PeriodicSolutionSolver_v3:IntegrationTolerance','ODE tolerances must be finite and positive.');
    end
    if isfield(settings,'MaxStep')&&~isempty(settings.MaxStep)&&isfinite(settings.MaxStep)
        if isempty(step),step=settings.MaxStep;else,step=min(step,settings.MaxStep);end
    end
    solver=member(settings,'ODESolver',@ode45);
    if isa(solver,'function_handle'),name=func2str(solver);else,name=char(solver);end
    floor=0;if strcmp(name,'ode45'),floor=100*eps;end
    effective=struct('RelTol',max(rel,floor),'AbsTol',absolute,'MaxStep',step, ...
        'ODESolver',name,'configured_minimum_RelTol',rel,'RelTol_lower_bound',floor);
end

function conditions=familyConditions(residual,w,p,info,raw,orbit,options,acceptance)
    % This is the actual residual contract, before numerical root scaling.
    if isfield(info,'physical_residual')
        equations=info.physical_residual;
    elseif isa(residual,'EnergyFamilyResidual_v3')||isa(residual,'PeriodicOrbitResidual_v3')
        equations=raw;
    else
        error('PeriodicSolutionSolver_v3:PhysicalFamilyContract', ...
            'A delegated residual must expose finite unscaled physical_residual equations.');
    end
    requested=[];origins={};
    if isfield(info,'requested_energy')
        requested=info.requested_energy(:);origins={'residual.requested_energy'};
    elseif isfield(info,'augmented_energy')
        requested=info.augmented_energy(:);origins={'residual.augmented_energy'};
    elseif isa(residual,'EnergyFamilyResidual_v3')
        requested=p(11);origins={'energy-family parameter'};
    end
    % In the native augmented formulation Energy initializes the free E
    % unknown. Its corrected value is the residual's actual target, rather
    % than an additional fixed-energy equation outside that square system.
    energyIsInitialGuess=isa(residual,'ConstrainedEnergyResidual_v3')&&residual.Augmented;
    if ~isempty(options.Energy)&&~energyIsInitialGuess
        requested=[requested;options.Energy(:)];origins{end+1}='service Energy option';
    end
    actual=QuadrupedEnergy_v3.evaluate(orbit.initial_state,orbit.initial_mode,orbit.parameter);
    errorAtTarget=actual-requested;
    constraint=member(info,'constraint_residual',0);
    conditions=struct('residual_class',class(residual),'coordinates',w(:), ...
        'unscaled_family_equations',equations(:),'unscaled_family_norm',physicalNorm(equations), ...
        'unscaled_family_tolerance',acceptance.FamilyTolerance, ...
        'unscaled_equations_passed',~isempty(equations)&&finiteWithin(equations,acceptance.FamilyTolerance), ...
        'requested_energy',requested,'requested_energy_origin',{origins}, ...
        'target_energy_applicable',~isempty(requested),'actual_energy',actual, ...
        'target_energy_error',errorAtTarget,'target_energy_tolerance',acceptance.EnergyTolerance, ...
        'target_energy_passed',isfinite(actual)&&(isempty(requested)||finiteWithin(errorAtTarget,acceptance.EnergyTolerance)), ...
        'constraint_residual',constraint,'constraint_tolerance',acceptance.ConstraintTolerance, ...
        'constraint_passed',finiteWithin(constraint,acceptance.ConstraintTolerance));
end

function passed=finiteWithin(value,tolerance)
    passed=~isempty(value)&&all(isfinite(value(:)))&&isscalar(tolerance)&& ...
        isfinite(tolerance)&&tolerance>0&&max(abs(value(:)))<=tolerance;
end

function seed=normalize(input)
    if isa(input,'HybridOrbit_v3')
        seed=struct('state',input.initial_state,'mode',input.initial_mode,'parameter',input.parameter, ...
            'return_policy',input.return_policy,'occurrence',1,'provenance',struct('kind','saved-v3-orbit'));
        if ~isa(seed.return_policy,'ReturnPolicyBase_v3'),seed.return_policy=input.return_policy_name;end
        if isstruct(input.section_chart)&&isfield(input.section_chart,'BL_touchdowns_per_return')
            seed.occurrence=input.section_chart.BL_touchdowns_per_return;
        elseif strcmp(input.return_policy_name,'iterated-section-return')
            seed.occurrence=input.return_multiplicity;
        end
    elseif isstruct(input)
        seed=input;
        if ~isfield(seed,'state')&&isfield(seed,'initial_state'),seed.state=seed.initial_state;end
        if ~isfield(seed,'mode')&&isfield(seed,'initial_mode'),seed.mode=seed.initial_mode;end
        if ~isfield(seed,'parameter')&&isfield(seed,'physical_parameter'),seed.parameter=seed.physical_parameter;end
        if ~isfield(seed,'return_policy'),seed.return_policy='BL-marked-apex-return';end
        if ~isfield(seed,'occurrence'),seed.occurrence=1;end
        if isa(seed.return_policy,'BLMarkedApexReturnPolicy_v3')
            if isfield(input,'occurrence')&&seed.occurrence~=seed.return_policy.BLTouchdownsPerReturn
                error('PeriodicSolutionSolver_v3:Occurrence','Seed occurrence disagrees with the explicit BL return policy.');
            end
            seed.occurrence=seed.return_policy.BLTouchdownsPerReturn;
        end
        if ~isfield(seed,'provenance')
            seed.provenance=struct('kind','explicit-v3-state');
            if isfield(seed,'source'),seed.provenance.source=seed.source;end
            if isfield(seed,'column'),seed.provenance.column=seed.column;end
        end
    else,error('PeriodicSolutionSolver_v3:Seed','Seed must be a v3 orbit or struct.');end
    schema=QuadrupedSchema_v3.shared();seed.state=schema.validateState(seed.state);
    seed.mode=schema.validateMode(seed.mode);seed.parameter=schema.validateParameter(seed.parameter);
    validateattributes(seed.occurrence,{'numeric'},{'scalar','integer','positive'});
end
function map=makeMap(seed,integration,options)
    policy=seed.return_policy;
    if ~isa(policy,'ReturnPolicyBase_v3')
        switch char(policy)
            case {'BL-marked-apex-return','BLMarkedApexReturnPolicy_v3'}
                policy=BLMarkedApexReturnPolicy_v3(struct('BLTouchdownsPerReturn',seed.occurrence));
            case {'event-cycle-return','EventCycleReturnPolicy_v3','event-cycle'}
                policy=EventCycleReturnPolicy_v3();
                if seed.occurrence>1
                    error('PeriodicSolutionSolver_v3:Occurrence','Event-cycle occurrence greater than one requires an explicit policy object.');
                end
            case {'iterated-section-return','IteratedReturnPolicy_v3'}
                policy=IteratedReturnPolicy_v3(seed.occurrence);
            otherwise,error('PeriodicSolutionSolver_v3:ReturnPolicy','Provide an explicit supported policy object or name.');
        end
    end
    map=PoincareMap_v3(Quadrupedal_Dynamics_v3(),PoincareSection_v3.apex(4), ...
        HybridSimulator_v3(integration),policy,struct('MaxReturnTime',options.MaxReturnTime, ...
        'MaxCycleEvents',options.MaxCycleEvents,'MaxSectionCrossings',options.MaxSectionCrossings));
end
function primitive=properApexAudit(primitive,mapInfo,orbit,integration,options,acceptance)
    % Every shorter recurrence must also cross this transverse apex section.
    % Exact event-located intermediate apices avoid interpolation missing a
    % multiple cover. A close witness receives a separate fresh return.
    crossings=mapInfo.candidate_section_crossings;
    evidence=struct('index',{},'period',{},'recorded_closure',{}, ...
        'mode_closed',{},'independent_closure',{},'repeated_cycle',{});
    for k=1:max(0,numel(crossings)-1)
        crossing=crossings(k);delta=crossing.state-orbit.initial_state;delta(1)=0;
        item=struct('index',k,'period',crossing.period,'recorded_closure',norm(delta,inf), ...
            'mode_closed',crossing.discrete_closed,'independent_closure',NaN,'repeated_cycle',false);
        if crossing.discrete_closed && item.recorded_closure<=acceptance.PrimitiveStateTolerance
            shortSeed=struct('state',orbit.initial_state,'mode',orbit.initial_mode, ...
                'parameter',orbit.parameter,'return_policy',IteratedReturnPolicy_v3(k), ...
                'occurrence',k,'provenance',struct('kind','proper-apex-primitive-audit'));
            shortMap=makeMap(shortSeed,integration,options);
            [next,info]=shortMap.evaluate(orbit.initial_state,orbit.initial_mode,orbit.parameter);
            shorter=next-orbit.initial_state;shorter(1)=0;
            item.independent_closure=norm(shorter,inf);
            item.repeated_cycle=info.discrete_closed&&info.admissible ...
                &&item.independent_closure<=acceptance.FullClosureTolerance;
            if item.repeated_cycle
                primitive.status="multiple_cover_detected";
                primitive.reason="a proper event-located apex independently closes the full physical state and mode";
                primitive.primitive_period=info.period;
                primitive.cover_count=round(orbit.period/info.period);
            elseif item.recorded_closure<=acceptance.PrimitiveStateTolerance
                primitive.status="unknown";
                primitive.reason="a near closed proper apex failed tighter independent closure; primitive identity is unresolved";
            end
        end
        evidence(end+1)=item; %#ok<AGROW>
        if item.repeated_cycle,break;end
    end
    primitive.proper_apex_replays=evidence;
    primitive.proper_apex_count=numel(crossings)-1;
end
function audit=physicalAudit(orbit)
    data=HybridCycleData_v3.unpack(orbit);[~,first]=unique(data.time,'stable');
    [~,last]=unique(data.time,'last');rows=unique([first;last]);
    energies=zeros(numel(rows),1);constraint=0;minimum=Inf;
    system=Quadrupedal_Dynamics_v3();
    for k=1:numel(rows)
        j=rows(k);[energies(k),info]=QuadrupedEnergy_v3.evaluate(data.state(j,:).',data.mode(j,:).',orbit.parameter);
        constraint=max(constraint,info.physical_mode_report.maximum_constraint_residual);
        physical=system.assertAdmissible(data.state(j,:).',data.mode(j,:).',orbit.parameter);
        if isfield(physical,'minimum_physical_margin'),minimum=min(minimum,physical.minimum_physical_margin);end
    end
    audit=struct('energy_at_section',energies(1),'maximum_energy_error',max(abs(energies-energies(1))), ...
        'maximum_stance_constraint',constraint,'minimum_physical_margin',minimum, ...
        'sample_count',numel(rows),'virtual_same_time_rows_omitted',numel(data.time)-numel(rows));
end
function value=member(object,name,fallback)
    value=fallback;if isstruct(object)&&isfield(object,name),value=object.(name);end
end
function value=physicalNorm(residual)
    value=Inf;if ~isempty(residual)&&all(isfinite(residual(:))),value=norm(residual,inf);end
end
