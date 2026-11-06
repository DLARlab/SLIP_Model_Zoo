function report=HybridEventLifecycleRegression_v3(requirePass)
%HYBRIDEVENTLIFECYCLEREGRESSION_V3 Exact public restart-lifecycle seams.
% Synthetic systems exercise real simulator and PoincareMap workflows.
% No periodic-orbit correction, classification or admission is inferred.
    if nargin<1,requirePass=true;end
    validateattributes(requirePass,{'logical'},{'scalar'});
    specs={ ...
        'PMap_resolved_guard_control',@()mapCase('resolved'); ...
        'PMap_guard_after_leave_stop',@()mapCase('after-leave');
        'PMap_undeclared_guard_continuous_handoff',@()mapCase('after-leave-undeclared'); ...
        'PMap_guard_after_rejected_candidate',@()mapCase('after-candidate'); ...
        'PMap_simultaneous_guard_stop_postreset',@()mapCase('simultaneous'); ...
        'explicit_simulator_section_handoff',@simulatorHandoff; ...
        'wrapped_stop_handle_identity',@wrappedStopIdentity};
    rows=cell(size(specs,1),1);
    for k=1:size(specs,1)
        try,row=specs{k,2}();row.name=specs{k,1};
        catch exception,row=struct('name',specs{k,1},'passed',false,'unexpected_exception', ...
                struct('identifier',exception.identifier,'message',exception.message));end
        rows{k}=row;fprintf('HYBRID_LIFECYCLE_CASE %s\n',jsonencode(row));
    end
    report=struct('schema','hybrid-event-lifecycle-regression-v1','rows',{rows}, ...
        'passed',all(cellfun(@(r)r.passed,rows)), ...
        'scope','Synthetic exact-root lifecycle tests, including actual three-phase PoincareMap and rejected candidates; no saved orbit is requalified.');
    if requirePass
        failed=rows(~cellfun(@(r)r.passed,rows));names=cellfun(@(r)r.name,failed,'UniformOutput',false);
        assert(report.passed,'HybridEventLifecycleRegression_v3:RegressionFailure','Failed lifecycle regressions: %s',strjoin(names,', '));
    end
end

function row=mapCase(kind)
    omega=1e6;T=2*pi/omega;tLeave=asin(.1)/omega;returns=1;declare=true;
    switch kind
        case 'resolved',root=tLeave+5e-7;
        case 'after-leave',root=tLeave+5e-8;
        case 'after-leave-undeclared',root=tLeave+5e-8;declare=false;
        case 'after-candidate',root=T+5e-8;returns=2;
        case 'simultaneous',root=tLeave;
        otherwise,error('HybridEventLifecycleRegression_v3:Case');
    end
    system=HybridSystemBase_v3(struct('StateDimension',3,'ParameterDimension',1, ...
        'FlowFunction',@(~,x,~,p)[x(2);-p(1)^2*x(1);-.01], ...
        'ActiveGuardsFunction',@(t,x,q,p)oscillatorGuard(t,x,q,p,declare),'ResetFunction',@identityReset,'TransitionFunction',@(~,~)true));
    section=PoincareSection_v3(@(x,p)x(1),struct('Name','oscillator-zero', ...
        'DerivativeFunction',@(~,x,~,~,~)x(2),'ProjectionFunction',@(x,p)[0;x(2:end)],'Direction',-1));
    settings=struct('RelTol',1e-10,'AbsTol',1e-12,'MaxStep',1e-8);
    simulator=HybridSimulator_v3(settings);
    if returns==1,policy=FirstReturnPolicy_v3();else,policy=IteratedReturnPolicy_v3(returns);end
    map=PoincareMap_v3(system,section,simulator,policy,struct('ArmTolerance',1e-7, ...
        'MaxReturnTime',2e-5,'MaxSectionCrossings',3,'MaxCycleEvents',8));
    initial=[0;-1;.01*root];[~,info]=map.evaluate(initial,false,omega);
    h=info.event_history;ids=[h.guard_id];times=[h.time];
    rootCorrect=numel(h)==1&&isequal(ids,3)&&abs(times-root)<=2e-10;
    normal=info.success&&info.valid&&info.integration_success&&info.return_policy_accepted&&info.cycle_complete;
    periodCorrect=abs(info.period-returns*T)<=2e-10;
    plain=publicPlain(info);restartPhase=1;if returns==2,restartPhase=3;end
    restartState=info.phase_results{restartPhase}.final_state;
    row=struct('passed',normal&&periodCorrect&&rootCorrect&&plain,'map_completed_normally',normal, ...
        'expected_guard_id',3,'actual_guard_ids',ids,'expected_guard_time',root,'actual_guard_times',times, ...
        'expected_period',returns*T,'actual_period',info.period,'candidate_section_count',info.candidate_section_count, ...
        'expected_candidate_count',returns,'initial_state_exact',isequaln(info.initial_state,initial), ...
        'postreset_final_mode',info.final_mode,'public_restart_results_no_opaque_context',plain,'section_leave_time',tLeave, ...
        'initial_guard_value',initial(3),'actual_guard_value_at_relevant_restart',restartState(3), ...
        'geometry_declaration_supplied',declare,'integration_profile',settings);
    row.default_ArmingTolerance=simulator.Options.ArmingTolerance;
    row.default_SimultaneousTimeTolerance=simulator.Options.SimultaneousTimeTolerance;
    row.passed=row.passed&&row.initial_state_exact&&info.candidate_section_count==returns&&all(info.final_mode);
    if strcmp(kind,'after-candidate'),row.rejected_candidate_count=info.candidate_section_count-1;end
    if strcmp(kind,'simultaneous')
        batches=info.trajectory.event_batches;
        row.simultaneous_guard_processed_before_phase_stop=numel(batches)==1&&all(batches(1).mode_after)&&all(info.final_mode);
        row.passed=row.passed&&row.simultaneous_guard_processed_before_phase_stop;
    end
end

function g=oscillatorGuard(~,x,q,~,declare)
    if q,g=descriptor(x,[],declare);else,g=descriptor(x,3,declare);end
end

function row=simulatorHandoff()
    system=linearSystem();initial=[1e-6;1.05e-8];p=[1;.01];
    simulator=HybridSimulator_v3();options=struct('StopCondition',struct('Function',@firstStop));
    api=ismethod(EventDetector_v3(),'prepareSimulationRestart');context=[];
    if api
        [~,first,context]=simulator.simulate(system,initial,false,p,[0,2e-6],options);
        [secondTrajectory,second]=simulator.simulate(system,first.final_state,first.final_mode,p,[first.final_time,2e-6],struct(),context);
    else
        [~,first]=simulator.simulate(system,initial,false,p,[0,2e-6],options);
        [secondTrajectory,second]=simulator.simulate(system,first.final_state,first.final_mode,p,[first.final_time,2e-6]);
    end
    [freshTrajectory,fresh]=simulator.simulate(system,first.final_state,first.final_mode,p,[first.final_time,2e-6]);
    h=secondTrajectory.event_history;h=h(~[h.is_stop]);fh=freshTrajectory.event_history;fh=fh(~[fh.is_stop]);
    normal=first.success&&first.stop_occurred&&second.success&&strcmp(second.termination_reason,'final_time');
    rootCorrect=numel(h)==1&&isequal([h.guard_id],2)&&abs(h.time-1.05e-6)<=2e-10;
    legacyFresh=fresh.success&&isempty(fh);
    plain=true;try,C1ScientificDigest_v3(first);C1ScientificDigest_v3(second);C1ScientificDigest_v3(secondTrajectory.metadata);catch,plain=false;end
    row=struct('passed',normal&&rootCorrect&&legacyFresh&&plain,'explicit_handoff_API_available',api, ...
        'both_simulations_completed_normally',normal,'actual_guard_ids',[h.guard_id],'actual_guard_times',[h.time], ...
        'expected_guard_id',2,'expected_guard_time',1.05e-6,'legacy_fresh_call_still_independent',legacyFresh, ...
        'public_outputs_plain',plain,'first_stop_time',first.final_time,'guard_value_at_restart',first.final_state(2));
end

function row=wrappedStopIdentity()
    system=HybridSystemBase_v3(struct('StateDimension',2,'ParameterDimension',2, ...
        'FlowFunction',@(~,~,~,p)-p,'ActiveGuardsFunction',@firstGuard, ...
        'ResetFunction',@identityReset,'TransitionFunction',@(~,~)true));
    original=HybridEventStopFixture_v3();clone=HybridEventStopFixture_v3();
    detector=EventDetector_v3();x=[1e-6;1.05e-8];p=[1;.01];q=false;
    wrapper=struct('Function',original,'name','wrapped-object-stop');
    [~,event,context]=detector.integrate(system,x,q,p,[0,2e-6],wrapper);
    [after,mode]=system.resolveEventBatch([event.guard_batch.id],event.time,event.state,q,p);
    ready=detector.prepareRestart(context,after,mode,[event.guard_batch.id],{});
    [~,valid]=detector.integrate(system,after,mode,p,[event.time,2e-6],wrapper,odeset(),ready);
    validControl=valid.stop_occurred&&abs(valid.time-1.05e-6)<=2e-10;
    cloneWrapper=wrapper;cloneWrapper.Function=clone;
    rejected=false;normalClone=false;
    try,[~,other]=detector.integrate(system,after,mode,p,[event.time,2e-6],cloneWrapper,odeset(),ready);normalClone=other.stop_occurred;
    catch exception,rejected=strcmp(exception.identifier,'EventDetector_v3:RestartBinding');end
    changed=wrapper;changed.name='different-wrapper-name';wrapperRejected=false;
    try,detector.integrate(system,after,mode,p,[event.time,2e-6],changed,odeset(),ready);
    catch exception,wrapperRejected=strcmp(exception.identifier,'EventDetector_v3:RestartBinding');end
    row=struct('passed',validControl&&rejected&&wrapperRejected,'same_instance_control_passed',validControl, ...
        'distinct_equal_valued_wrapped_handle_rejected',rejected,'changed_wrapper_metadata_rejected',wrapperRejected, ...
        'unrejected_clone_completed_normally',normalClone,'original_and_clone_distinct',~(original==clone));
end

function system=linearSystem()
    system=HybridSystemBase_v3(struct('StateDimension',2,'ParameterDimension',2, ...
        'FlowFunction',@(~,~,~,p)-p,'ActiveGuardsFunction',@secondGuard, ...
        'ResetFunction',@identityReset,'TransitionFunction',@(~,~)true));
end
function g=secondGuard(~,x,q,~),if q,g=descriptor(x,[]);else,g=descriptor(x,2);end,end
function g=firstGuard(~,x,q,~),if q,g=descriptor(x,[]);else,g=descriptor(x,1);end,end
function d=firstStop(~,x,~,~),d=descriptor(x,1);d.kind="stop";end
function g=descriptor(x,ids,declare)
    if nargin<3,declare=true;end
    prototype=struct('id',0,'name',"",'value',0,'direction',-1,'isterminal',true, ...
        'enabled',true,'interior_sign',1,'kind',"synthetic-contact",'metadata',struct());
    g=repmat(prototype,0,1);
    for id=ids
        d=prototype;d.id=id;d.name="coordinate_"+id;d.value=x(id);
        if declare,d.metadata.restart_arming=struct('schema','state-parameter-guard-geometry-v1', ...
                'definition',sprintf('lifecycle-coordinate-%d-v1',id),'state_dependencies',id,'mode_independent',true);end
        g(end+1,1)=d; %#ok<AGROW>
    end
end
function x=identityReset(~,~,x,~,~),end
function yes=publicPlain(info)
    yes=true;
    try
        projection=struct('phase_results',{info.phase_results}, ...
            'candidate_section_crossings',info.candidate_section_crossings,'trajectory',info.trajectory);
        C1ScientificDigest_v3(projectNativeTrajectories(projection,0));
    catch,yes=false;end
end

function out=projectNativeTrajectories(value,depth)
    assert(depth<=64,'HybridEventLifecycleRegression_v3:ProjectionDepth');
    if isa(value,'Trajectory_v3')&&isscalar(value)
        out=struct('native_class','Trajectory_v3');names=properties(value);
        for k=1:numel(names),out.(names{k})=projectNativeTrajectories(value.(names{k}),depth+1);end
    elseif isstruct(value)
        out=value;names=fieldnames(value);
        for k=1:numel(value),for j=1:numel(names),out(k).(names{j})=projectNativeTrajectories(value(k).(names{j}),depth+1);end,end
    elseif iscell(value)
        out=value;for k=1:numel(value),out{k}=projectNativeTrajectories(value{k},depth+1);end
    else
        assert(isnumeric(value)||islogical(value)||ischar(value)||isstring(value), ...
            'HybridEventLifecycleRegression_v3:OpaquePublicContext','Only the known native trajectory object may be projected; opaque collaborators and callbacks are forbidden.');
        out=value;
    end
end
