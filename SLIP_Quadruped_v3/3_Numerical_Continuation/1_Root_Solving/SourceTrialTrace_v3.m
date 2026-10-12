function report=SourceTrialTrace_v3(seed,options)
%SOURCETRIALTRACE_V3 Quantitative failure evidence from the production engine.
% The completed physical trajectory and rejected raw segment are separate.
% This diagnostic never supplies a substitute periodic residual or orbit.
    if nargin<2,options=struct();end
    root=V3Root_v3(mfilename('fullpath'));
    oldPath=path;cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
    folders={'Schema_v3','Dynamics_v3','Simulation_v3','Orbit_v3'};
    for k=1:numel(folders),V3LegacyAddPath_v3(fullfile(root,folders{k}));end
    x=member(seed,{'initial_state','state'},[]);
    q=member(seed,{'initial_mode','mode'},[]);
    p=member(seed,{'physical_parameter','parameter'},[]);
    schema=QuadrupedSchema_v3.shared();
    x=schema.validateState(x);q=schema.validateMode(q);p=schema.validateParameter(p);
    horizon=member(options,{'Horizon'},max(1,1.1*member(seed,{'legacy_period','period'},1)));
    integration=member(options,{'Integration'},struct('RelTol',1e-10,'AbsTol',1e-12));
    integration.FailurePolicy='return';
    system=Quadrupedal_Dynamics_v3();simulator=HybridSimulator_v3(integration);
    [trajectory,execution]=simulator.simulate(system,x,q,p,[0,horizon]);
    report=struct('schema_version','source-trial-trace-v3-1', ...
        'diagnostic_only',true,'accepted_periodic_solution',false, ...
        'initial_state',x,'initial_mode',q,'physical_parameter',p, ...
        'effective_integration_settings',simulator.Options, ...
        'horizon',horizon,'trajectory',trajectory,'execution',execution, ...
        'scheduled_events',member(seed,{'scheduled_events_diagnostic_only','scheduled_events'},struct([])), ...
        'first_physical_failure',struct(),'first_event_discrepancy',struct(), ...
        'sample_diagnostics',struct([]));
    time=trajectory.time;states=trajectory.state;modes=trajectory.mode;
    sampleSource=repmat({'completed-physical-segment'},numel(time),1);
    if ~execution.success && isfield(execution,'failure')
        segment=execution.failure.raw_segment;
        if ~isempty(segment.time)
            time=[time;segment.time(:)];states=[states;segment.state];
            mode=execution.failure.candidate_mode(:).';
            modes=[modes;repmat(mode,numel(segment.time),1)];
            sampleSource=[sampleSource;repmat({'rejected-raw-segment'},numel(segment.time),1)];
        end
    end
    evidence=repmat(struct('time',NaN,'source','','state',[], ...
        'mode',[],'guard_values',[],'guard_directions',[], ...
        'guard_derivatives',[],'guard_enabled',[],'physical_admissibility',struct(), ...
        'axial_forces',[],'energy',NaN,'diagnostic_error',''),numel(time),1);
    for k=1:numel(time)
        state=states(k,:).';mode=modes(k,:).';
        evidence(k).time=time(k);evidence(k).source=sampleSource{k};
        evidence(k).state=state;evidence(k).mode=mode;
        try
            physical=system.admissibilityReport(state,mode,p);
            evidence(k).physical_admissibility=physical;
            if ~physical.global_validity && isempty(fieldnames(report.first_physical_failure))
                report.first_physical_failure=struct('time',time(k),'sample',k, ...
                    'state',state,'mode',mode,'source',sampleSource{k}, ...
                    'diagnostics',physical,'guard_values',[],'axial_forces',[]);
            end
            guards=system.guardFunctions(time(k),state,mode,p);
            evidence(k).guard_values=[guards.value].';
            evidence(k).guard_directions=[guards.direction].';
            evidence(k).guard_derivatives=[guards.directional_derivative].';
            evidence(k).guard_enabled=[guards.enabled].';
            [~,flow]=system.flow(time(k),state,mode,p);
            evidence(k).axial_forces=flow.axial_leg_forces;
            evidence(k).energy=QuadrupedEnergy_v3.evaluate(state,mode,p);
            if isfield(report.first_physical_failure,'sample') && report.first_physical_failure.sample==k
                report.first_physical_failure.guard_values=evidence(k).guard_values;
                report.first_physical_failure.axial_forces=evidence(k).axial_forces;
            end
        catch exception
            evidence(k).diagnostic_error=sprintf('%s: %s',exception.identifier,exception.message);
        end
    end
    report.sample_diagnostics=evidence;
    actual=struct('type',{},'time',{});
    for k=1:numel(trajectory.event_history)
        event=trajectory.event_history(k);
        if ~event.is_stop
            actual(end+1)=struct('type',char(event.type),'time',event.time); %#ok<AGROW>
        end
    end
    if ~execution.success && isfield(execution,'failure')
        pending=execution.failure.pending_event;
        if isfield(pending,'guard_batch')
            for k=1:numel(pending.guard_batch)
                guard=pending.guard_batch(k);
                actual(end+1)=struct('type',char(guard.name),'time',pending.time); %#ok<AGROW>
            end
        end
    end
    report.actual_events=actual;
    if ~isempty(report.scheduled_events)
        report.first_event_discrepancy=firstDifference(report.scheduled_events,actual,1e-6);
    end
end

function value=member(source,names,fallback)
    value=fallback;
    for k=1:numel(names)
        if isstruct(source)&&isfield(source,names{k})
            value=source.(names{k});return
        elseif isobject(source)&&isprop(source,names{k})
            value=source.(names{k});return
        end
    end
end

function result=firstDifference(scheduled,actual,tolerance)
    expected=clusters(scheduled,tolerance);observed=clusters(actual,tolerance);
    result=struct('found',false,'cluster_index',NaN,'scheduled',struct(), ...
        'actual',struct(),'time_difference',NaN,'reason','');
    for k=1:max(numel(expected),numel(observed))
        if k>numel(expected)||k>numel(observed)
            result.found=true;result.cluster_index=k;
            result.reason='available autonomous and source event histories have different cluster counts';
            if k<=numel(expected),result.scheduled=expected(k);end
            if k<=numel(observed),result.actual=observed(k);end
            return
        end
        if ~strcmp(expected(k).types,observed(k).types)||abs(expected(k).time-observed(k).time)>tolerance
            result.found=true;result.cluster_index=k;result.scheduled=expected(k);
            result.actual=observed(k);result.time_difference=observed(k).time-expected(k).time;
            result.reason='first autonomous directed event differs in time or contact identity';return
        end
    end
end

function result=clusters(events,tolerance)
    result=struct('time',{},'types',{});
    if isempty(events),return;end
    [~,order]=sort([events.time]);events=events(order);k=1;
    while k<=numel(events)
        last=k;
        while last<numel(events)&&abs(events(last+1).time-events(k).time)<=tolerance,last=last+1;end
        names=sort(string({events(k:last).type}));
        result(end+1)=struct('time',events(k).time,'types',char(strjoin(names,'+'))); %#ok<AGROW>
        k=last+1;
    end
end
