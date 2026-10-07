function [solution,report]=PeriodicSolutionSolver_v3(seed,options)
%PERIODICSOLUTIONSOLVER_V3 Correct, independently replay, then accept an orbit.
% SEED: state(14), mode(4), parameter(10), return_policy (object/name),
% occurrence (positive integer), provenance. A HybridOrbit_v3 is also valid.
% OPTIONS: Energy, Symmetry, ActiveCoordinateIndices, FamilyConstraint,
% Constraint(reference,normal,target), Integration, ReplayIntegration,
% SolverOptions, Acceptance; see Docs_v3/Periodic_Solution_Solver_v3.md.
% Existing square residuals can be delegated with Residual, Coordinates,
% AugmentedParameter; their fullState/createOrbit provide the physical lift.
    if nargin<2,options=struct();end
    defaults=struct('Energy',[],'Symmetry','none','ActiveCoordinateIndices',[], ...
        'FamilyConstraint','fixed-energy','Constraint',[], ...
        'ResidualScale',[],'CoordinateScale',[],'Integration',struct(), ...
        'ReplayIntegration',struct(),'SolverOptions',struct(), ...
        'Acceptance',struct(),'MaxReturnTime',30,'MaxCycleEvents',1000, ...
        'MaxSectionCrossings',64,'MaxWallSeconds',240, ...
        'Residual',[],'Coordinates',[],'AugmentedParameter',[]);
    options=merge(defaults,options,'option');solution=[];clock=tic;
    acceptance=merge(struct('FullClosureTolerance',1e-8,'EnergyTolerance',1e-8, ...
        'ConstraintTolerance',1e-8,'StanceTolerance',1e-8, ...
        'PrimitiveStateTolerance',1e-7,'PrimitiveEventTolerance',1e-7, ...
        'MaxCover',8,'RequirePrimitive',true),options.Acceptance,'acceptance');
    integration=merge(struct('RelTol',1e-9,'AbsTol',1e-11, ...
        'EventValueTolerance',1e-8,'EventTimeTolerance',1e-10, ...
        'SimultaneousTimeTolerance',1e-8,'MaxStep',.05),options.Integration,'integration');
    replayIntegration=integration;
    replayIntegration.RelTol=integration.RelTol/10;replayIntegration.AbsTol=integration.AbsTol/10;
    replayIntegration.EventValueTolerance=integration.EventValueTolerance/10;
    replayIntegration.EventTimeTolerance=integration.EventTimeTolerance/10;
    replayIntegration.SimultaneousTimeTolerance=integration.SimultaneousTimeTolerance/10;
    replayIntegration.MaxStep=integration.MaxStep/2;
    replayIntegration=merge(replayIntegration,options.ReplayIntegration,'replay integration');
    if replayIntegration.RelTol>=integration.RelTol || replayIntegration.AbsTol>=integration.AbsTol
        error('PeriodicSolutionSolver_v3:ReplayTolerances','Independent replay must use tighter top-level ODE tolerances.');
    end
    report=struct('schema_version','periodic-solution-solver-v3-1','status','running', ...
        'accepted',false,'seed',[],'options',options,'acceptance',acceptance, ...
        'integration',integration,'replay_integration',replayIntegration, ...
        'initial_residual',[],'initial_scaled_norm',Inf,'initial_physical_norm',Inf, ...
        'final_residual',[],'final_scaled_norm',Inf,'final_physical_norm',Inf, ...
        'full_closure',Inf,'final_candidate',[],'solver',struct(), ...
        'primary_failure',struct(),'finalization_failure',struct(), ...
        'replay_failure',struct(),'partial_evidence',struct(), ...
        'independent_replay',struct(),'physical_inequalities',struct(), ...
        'primitive',struct(),'classification',struct(),'constraint_residual',NaN, ...
        'provenance',struct(),'elapsed_seconds',0);
    try
        seed=normalize(seed);report.seed=seed;report.provenance=seed.provenance;
        report.final_candidate=seed.state;
        report.partial_evidence.initial_physical_chart=QuadrupedPhysicalChart_v3.report(seed.state,seed.mode,seed.parameter);
        if isempty(options.Residual)
            map=makeMap(seed,integration,options);
            base=PeriodicOrbitResidual_v3(map,seed.state);
            family=EnergyFamilyResidual_v3(base,seed.state,seed.mode,seed.parameter, ...
                struct('Symmetry',options.Symmetry,'ClosureTolerance',acceptance.FullClosureTolerance));
            energy=options.Energy;
            if isempty(energy),energy=QuadrupedEnergy_v3.evaluate(seed.state,seed.mode,seed.parameter);end
            p=[seed.parameter;energy];active=options.ActiveCoordinateIndices;
            if isempty(active),active=family.CoordinateIndices;end
            [found,positions]=ismember(active,family.CoordinateIndices);
            if ~all(found),error('PeriodicSolutionSolver_v3:ActiveCoordinates','Use independent state indices of the declared symmetry chart.');end
            constraint=options.Constraint;
            switch char(options.FamilyConstraint)
                case 'fixed-energy'
                    if ~isempty(constraint),error('PeriodicSolutionSolver_v3:Constraint','Fixed-energy correction has no extra unknown for another constraint.');end
                case {'arclength','amplitude','fixed-observable'}
                    if isempty(constraint),error('PeriodicSolutionSolver_v3:Constraint','Augmented correction needs reference, normal and target in (active u,E).');end
                otherwise,error('PeriodicSolutionSolver_v3:Family','Unknown FamilyConstraint.');
            end
            residual=ConstrainedEnergyResidual_v3(family,positions,constraint,options.ResidualScale);
            u=family.packState(seed.state);coordinates=u(positions);
            if ~isempty(constraint),coordinates=[coordinates;energy];end
            report.chart=family.Chart;report.energy_pivot=family.CoordinateIndices(family.EnergyPivot);
            report.active_coordinate_indices=active;
        else
            residual=options.Residual;coordinates=options.Coordinates(:);p=options.AugmentedParameter(:);
            if isempty(coordinates)||isempty(p)
                error('PeriodicSolutionSolver_v3:DelegatedResidual','Coordinates and AugmentedParameter are required with Residual.');
            end
            map=residual.Map;
            integration=map.Simulator.Options;
            report.integration=integration;
            replayIntegration=integration;
            replayIntegration.RelTol=integration.RelTol/10;replayIntegration.AbsTol=integration.AbsTol/10;
            replayIntegration.EventValueTolerance=integration.EventValueTolerance/10;
            replayIntegration.EventTimeTolerance=integration.EventTimeTolerance/10;
            replayIntegration.SimultaneousTimeTolerance=integration.SimultaneousTimeTolerance/10;
            if isempty(integration.MaxStep),replayIntegration.MaxStep=.025;
            else,replayIntegration.MaxStep=integration.MaxStep/2;end
            replayIntegration=merge(replayIntegration,options.ReplayIntegration,'replay integration');
            report.replay_integration=replayIntegration;
        end
        [initial,initialInfo]=residual.evaluateWithInfo(coordinates,p,seed.mode);
        report.initial_residual=initial;report.initial_scaled_norm=norm(initial,inf);
        report.initial_physical_norm=norm(member(initialInfo,'physical_residual',initial),inf);
        report.initial_evaluation=initialInfo;
        solverOptions=options.SolverOptions;
        % A reduced threshold looser than closure can stop without attempting
        % a correction. Use a stricter registered default; preserve requested
        % tighter settings. Full omitted closure remains an independent gate.
        solverOptions.ResidualAcceptanceTolerance=min(member(solverOptions,'ResidualAcceptanceTolerance',1e-10), ...
            min(acceptance.FullClosureTolerance,acceptance.EnergyTolerance)/100);
        solverOptions.FunctionTolerance=min(member(solverOptions,'FunctionTolerance',1e-11), ...
            solverOptions.ResidualAcceptanceTolerance/10);
        solverOptions.OptimalityTolerance=member(solverOptions,'OptimalityTolerance',1e-14);
        solverOptions.Algorithm=member(solverOptions,'Algorithm','newton');
        solverOptions.UseBroyden=member(solverOptions,'UseBroyden',true);
        solverOptions.JacobianRefreshInterval=member(solverOptions,'JacobianRefreshInterval',5);
        solverOptions.MaxWallSeconds=max(.001,options.MaxWallSeconds-toc(clock));
        if ~isempty(options.CoordinateScale),solverOptions.StateScale=options.CoordinateScale;end
        solver=RootSolver_v3(solverOptions);
        [candidate,root]=solver.solve(residual,coordinates,p,seed.mode);report.solver=root;
        report.final_coordinates=candidate;report.augmented_parameter=p;
        report.final_candidate=residual.fullState(candidate,p,seed.mode);
        report.final_residual=root.residual;report.final_scaled_norm=root.residualNorm;
        finalInfo=root.evaluationInfo;
        report.final_physical_norm=physicalNorm(member(finalInfo,'physical_residual',root.residual));
        report.full_closure=member(finalInfo,'full_physical_closure_norm',Inf);
        report.constraint_residual=member(finalInfo,'constraint_residual',0);
        if ~root.primaryConverged
            report.primary_failure=struct('identifier',root.primaryErrorIdentifier, ...
                'message',root.primaryMessage,'exitflag',root.primaryExitflag);
        end
        if ~isempty(root.finalizationMessage)
            report.finalization_failure=struct('identifier',root.finalizationErrorIdentifier,'message',root.finalizationMessage);
        end
        if ~root.converged
            report.status='retryable_failure';
            report.partial_evidence=traceFailure(report.seed,integration,options,report.partial_evidence);
            report.elapsed_seconds=toc(clock);
            return
        end
        candidateOrbit=root.orbit;
        if isempty(candidateOrbit),candidateOrbit=residual.createOrbit(candidate,p,seed.mode,finalInfo);end
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
        [next,replay]=replayMap.evaluate(candidateOrbit.initial_state, ...
            candidateOrbit.initial_mode,candidateOrbit.parameter);
        delta=next-candidateOrbit.initial_state;delta(1)=0;
        report.full_closure=norm(delta,inf);report.full_closure_residual=delta;
        replayProblem=PeriodicOrbitResidual_v3(replayMap,candidateOrbit.initial_state);
        [~,details]=replayProblem.evaluateWithInfo(replayProblem.packState(candidateOrbit.initial_state), ...
            candidateOrbit.parameter,candidateOrbit.initial_mode);
        % createOrbit uses the second fresh return; retain both returns and
        % their difference to expose deterministic integration ownership.
        acceptedOrbit=replayProblem.createOrbit(replayProblem.packState(candidateOrbit.initial_state), ...
            candidateOrbit.parameter,candidateOrbit.initial_mode,details);
        report.independent_replay=details;
        report.independent_replay.first_replay_next_state=next;
        report.independent_replay.repeated_replay_difference=norm(details.next_state-next,inf);
        report.full_closure=max(report.full_closure,norm(details.next_state(2:end)-candidateOrbit.initial_state(2:end),inf));
        report.physical_inequalities=physicalAudit(acceptedOrbit);
        report.primitive=PrimitiveCycleCheck_v3(acceptedOrbit,struct('MaxCover',acceptance.MaxCover, ...
            'StateTolerance',acceptance.PrimitiveStateTolerance, ...
            'EventPhaseTolerance',acceptance.PrimitiveEventTolerance));
        report.primitive=properApexAudit(report.primitive,details.map_info,acceptedOrbit, ...
            replayIntegration,options,acceptance);
        report.classification=GaitIdentification_v3(acceptedOrbit,struct('PrimitiveOptions', ...
            struct('MaxCover',acceptance.MaxCover,'StateTolerance',acceptance.PrimitiveStateTolerance, ...
            'EventPhaseTolerance',acceptance.PrimitiveEventTolerance)));
        report.period=acceptedOrbit.period;report.drift=acceptedOrbit.stride_displacement;
        report.chart_signature=member(replay,'section_chart',struct());
        report.event_signature=replay.section_relative_event_signature;
        valid=report.full_closure<=acceptance.FullClosureTolerance && replay.discrete_closed ...
            && replay.admissible && report.physical_inequalities.maximum_stance_constraint<=acceptance.StanceTolerance ...
            && report.physical_inequalities.maximum_energy_error<=acceptance.EnergyTolerance ...
            && abs(report.constraint_residual)<=acceptance.ConstraintTolerance ...
            && report.independent_replay.repeated_replay_difference<=acceptance.FullClosureTolerance;
        if acceptance.RequirePrimitive
            valid=valid && report.primitive.status=="primitive_within_checked_bound";
        end
        if valid
            solution=acceptedOrbit;report.accepted=true;report.status='accepted';
        else
            report.status='retryable_failure';
            report.replay_failure=struct('identifier','PeriodicSolutionSolver_v3:Acceptance', ...
                'message','Fresh full closure, energy, stance, constraint, determinism or primitive-period gate failed.');
        end
    catch exception
        failure=struct('identifier',exception.identifier,'message',exception.message);
        if isempty(fieldnames(report.solver)),report.primary_failure=failure;
        else,report.replay_failure=failure;end
        report.status='retryable_failure';
        if exist('SourceTrialTrace_v3','file')==2 && ~isempty(report.seed)
            report.partial_evidence=traceFailure(report.seed,integration,options,report.partial_evidence);
        end
    end
    report.elapsed_seconds=toc(clock);
end

function evidence=traceFailure(seed,integration,options,evidence)
    if exist('SourceTrialTrace_v3','file')~=2,return;end
    candidate=struct('initial_state',seed.state,'initial_mode',seed.mode, ...
        'parameter',seed.parameter,'provenance',seed.provenance);
    if isfield(seed,'scheduled_events_diagnostic_only')
        candidate.scheduled_events_diagnostic_only=seed.scheduled_events_diagnostic_only;
    end
    try
        evidence.failure_trace=SourceTrialTrace_v3(candidate,struct('Horizon',min(options.MaxReturnTime,3), ...
            'Integration',integration));
    catch exception
        evidence.trace_failure=struct('identifier',exception.identifier,'message',exception.message);
    end
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
function result=merge(defaults,overrides,kind)
    if ~isstruct(overrides)||~isscalar(overrides),error('PeriodicSolutionSolver_v3:Options','%s must be a scalar struct.',kind);end
    result=defaults;
    for field=fieldnames(overrides).'
        name=field{1};if ~isfield(defaults,name),error('PeriodicSolutionSolver_v3:Option','Unknown %s %s.',kind,name);end
        result.(name)=overrides.(name);
    end
end
