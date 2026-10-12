function [orbit, report] = ReplayPrescribedContactCycle_v3(x0, p, cycle, options)
%REPLAYPRESCRIBEDCONTACTCYCLE_V3 Native v3 flow with a declared contact cycle.
% This is the v2 prescribed-contact model, not the autonomous first-root
% model. The eight native-order contact times and period are part of the
% problem. It uses v3 equations, resets, schema and trajectory containers;
% no protected legacy executable or hidden timing solve is called.
% Numerical closure of this model never establishes unilateral admission.
    if nargin < 4, options = struct(); end
    defaults = struct('RelTol',1e-12,'AbsTol',1e-12, ...
        'ClosureTolerance',1e-8,'GuardTolerance',1e-8, ...
        'EnergyTolerance',1e-8,'OutputFcn',[],'SampleCount',257);
    names = fieldnames(options);
    assert(all(ismember(names,fieldnames(defaults))), ...
        'ReplayPrescribedContactCycle_v3:Option','Unknown replay option.');
    for k=1:numel(names), defaults.(names{k})=options.(names{k}); end
    options=defaults;
    for name={'RelTol','AbsTol','ClosureTolerance','GuardTolerance','EnergyTolerance'}
        validateattributes(options.(name{1}),{'numeric'},{'scalar','real','finite','positive'});
    end
    validateattributes(options.SampleCount,{'numeric'},{'scalar','real','finite','integer','>=',2});
    assert(isempty(options.OutputFcn)||isa(options.OutputFcn,'function_handle'), ...
        'ReplayPrescribedContactCycle_v3:OutputFcn','OutputFcn must be empty or a function handle.');
    schema=QuadrupedSchema_v3.shared();
    x0=schema.validateState(x0);p=schema.validateParameter(p);
    assert(isstruct(cycle)&&isscalar(cycle)&&all(isfield(cycle,{'event_times','period'})), ...
        'ReplayPrescribedContactCycle_v3:Cycle','Supply native-order event_times and period.');
    T=cycle.period; times=cycle.event_times(:);
    validateattributes(T,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(times,{'numeric'},{'vector','numel',8,'real','finite','nonnegative','<',T});
    assert(all(times(1:2:8)~=times(2:2:8)), ...
        'ReplayPrescribedContactCycle_v3:DegenerateContact','Same-leg TD and LO must differ.');
    % The state at t=0 is right-continuous. An event exactly at zero belongs
    % to the previous period; its reset is included at t=T for closure.
    q0=times(2:2:8)<times(1:2:8);
    q0(times(1:2:8)==0)=true;q0(times(2:2:8)==0)=false;
    positiveTimes=times;positiveTimes(positiveTimes==0)=T;
    [orderedTimes,ids]=sort(positiveTimes);
    dynamics=ContinuousDynamics_v3(schema);reset=ResetMap_v3(schema);
    transition=ModeTransition_v3(schema);guards=GuardFunctions_v3(schema);
    trajectory=Trajectory_v3();q=q0;x=x0;t=0;
    eventGuard=zeros(8,1);incoming=zeros(8,1);outgoing=zeros(8,1);
    minimumCompression=Inf;minimumSwingClearance=Inf;minimumCosine=Inf;
    maximumEnergyError=0;H0=QuadrupedEnergy_v3.evaluate(x0,q0,p);
    conservationApplicable=isfinite(p(9))||x0(6)==0;
    odeOptions=odeset('RelTol',options.RelTol,'AbsTol',options.AbsTol, ...
        'OutputFcn',options.OutputFcn);
    % Near-coincident distinct-leg events retain their literal source times.
    % No tolerance-based clustering changes the source contact schedule.
    for j=1:9
        if j<=8, target=orderedTimes(j);else, target=T;end
        if target>t
            sol=ode45(@(tt,xx)dynamics.evaluate(tt,xx,q,p),[t,target],x,odeOptions);
            assert(sol.x(end)==target,'ReplayPrescribedContactCycle_v3:Incomplete','Integration did not reach its prescribed endpoint.');
            % Physical margins are measured on the accepted solver mesh,
            % not asserted under the distinct prescribed-contact model.
            expanded=schema.expandParameters(p);
            theta=sol.y(schema.Leg.AngleIndices,:)+sol.y(schema.State.phi,:);
            height=sol.y(schema.State.y,:)+expanded.s.*sin(sol.y(schema.State.phi,:));
            if any(q)
                compression=expanded.l_0(q)-height(q,:)./cos(theta(q,:));
                minimumCompression=min(minimumCompression,min(compression,[],'all'));
            end
            if any(~q)
                clearance=height(~q,:)-expanded.l_0(~q).*cos(theta(~q,:));
                minimumSwingClearance=min(minimumSwingClearance,min(clearance,[],'all'));
            end
            minimumCosine=min(minimumCosine,min(cos(theta),[],'all'));
            energy=.5*sum(sol.y([2,4],:).^2,1)+sol.y(3,:);
            if isfinite(p(9)),energy=energy+.5*p(9)*sol.y(6,:).^2;end
            if any(q),energy=energy+.5*sum(expanded.k_l(q).*compression.^2,1);end
            maximumEnergyError=max(maximumEnergyError,max(abs(energy-H0)));
            sampleTimes=unique([t,target,linspace(t,target,max(2,ceil(options.SampleCount*(target-t)/T)))]);
            trajectory.appendSegment(sampleTimes,deval(sol,sampleTimes).',q);
            x=sol.y(:,end);t=target;
        elseif isempty(trajectory.time)
            trajectory.appendSample(t,x,q);
        end
        if j<=8
            id=ids(j);leg=schema.Event.LegIndices(id);
            before=x;qbefore=q;
            values=guards.legValues(before,p);eventGuard(id)=values(leg);
            flow=dynamics.evaluate(t,before,q,p);
            derivative=guards.legLieDerivatives(before,flow,p);incoming(id)=derivative(leg);
            x=reset.apply(id,t,before,q,p);q=transition.apply(id,q);
            maximumEnergyError=max(maximumEnergyError,abs(QuadrupedEnergy_v3.evaluate(x,q,p)-H0));
            flow=dynamics.evaluate(t,x,q,p);
            derivative=guards.legLieDerivatives(x,flow,p);outgoing(id)=derivative(leg);
            trajectory.appendSample(t,x,q);
            trajectory.recordEvent(struct('type',schema.Event.Names{id},'time',t, ...
                'guard_id',id,'guard_name',schema.Event.Names{id}, ...
                'state_before',before,'state_after',x,'mode_before',qbefore,'mode_after',q, ...
                'value',eventGuard(id),'directional_derivative',incoming(id), ...
                'metadata',struct('contact_policy','prescribed-contact-cycle','scheduled',true)));
        end
    end
    rawClosure=x-x0;drift=rawClosure(1);rawClosure(1)=0;
    relativeClosure=norm(rawClosure./max(1,abs(x0)),Inf);
    absoluteClosure=norm(rawClosure,Inf);
    targetApex=abs(x(schema.PhaseIndex));
    energyError=maximumEnergyError/max(1,abs(H0));
    validated=relativeClosure<=options.ClosureTolerance && absoluteClosure<=options.ClosureTolerance ...
        && max(abs(eventGuard))<=options.GuardTolerance ...
        && targetApex<=options.ClosureTolerance && isequal(q,q0) ...
        && energyError<=options.EnergyTolerance && conservationApplicable;
    model='v3-prescribed-contact-cycle-v2-compatible';
    report=struct('model_identity',model,'validated',validated, ...
        'validation_scope','prescribed-contact closure, event surfaces, apex, mode and energy', ...
        'principal_model_admitted',false,'raw_closure',rawClosure, ...
        'raw_closure_norm',absoluteClosure,'scaled_closure_norm',relativeClosure,'event_guard_residuals',eventGuard, ...
        'maximum_guard_residual',max(abs(eventGuard)),'terminal_apex_residual',targetApex, ...
        'mode_closed',isequal(q,q0),'energy_initial',H0, ...
        'maximum_sampled_energy_error',maximumEnergyError,'relative_sampled_energy_error',energyError, ...
        'energy_conservation_applicable',conservationApplicable, ...
        'minimum_sampled_stance_compression',minimumCompression, ...
        'minimum_sampled_swing_clearance',minimumSwingClearance, ...
        'minimum_sampled_downward_cosine',minimumCosine, ...
        'incoming_event_lie_derivatives',incoming,'outgoing_event_lie_derivatives',outgoing, ...
        'cycle',cycle,'options',rmfield(options,'OutputFcn'), ...
        'new_nonlinear_solves',0,'source_state_changed',false);
    trajectory.metadata=struct('model_identity',model,'contact_cycle',cycle, ...
        'strict_principal_model_admitted',false);
    trajectory.setTermination('prescribed-cycle-complete',T,x,q,report);
    orbit=HybridOrbit_v3(struct('initial_state',x0,'initial_mode',q0, ...
        'parameter',p,'period',T,'trajectory',trajectory, ...
        'event_history',trajectory.event_history,'mode_history',trajectory.mode, ...
        'poincare_state',x,'stride_displacement',drift, ...
        'return_policy_name','prescribed-contact-cycle','return_policy','prescribed-contact-cycle', ...
        'schema_metadata',schema.metadata(), ...
        'section_chart',struct('name','prescribed-contact-cycle','model_identity',model, ...
            'contact_cycle',cycle,'principal_model_admitted',false), ...
        'cycle_completion_diagnostics',report));
end
