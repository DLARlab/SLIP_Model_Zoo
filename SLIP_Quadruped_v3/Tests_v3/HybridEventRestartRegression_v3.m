function report=HybridEventRestartRegression_v3(requirePass)
%HYBRIDEVENTRESTARTREGRESSION_V3 End-to-end arming ownership regressions.
% Uses the actual simulator/detector lifecycle, default event tolerances and
% existing configurable generic system. No root solver or mechanical model
% is substituted for a periodic-orbit replay.
    if nargin<1,requirePass=true;end
    validateattributes(requirePass,{'logical'},{'scalar'});
    specs=struct('name',{'simultaneous_two','batched_close_TD','distinct_fast_TD', ...
        'distinct_slow_TD','distinct_slow_LO','inside_batch_threshold','outside_batch_threshold', ...
        'below_arming_threshold','above_arming_threshold'}, ...
        'slope',{.01,.01,1,.01,.01,.01,.01,.01,.01}, ...
        'gap',{0,5e-9,5e-8,5e-8,5e-8,9e-9,11e-9,9e-8,11e-8}, ...
        'direction',{-1,-1,-1,-1,1,-1,-1,-1,-1}, ...
        'batches',{[2],[2],[1,1],[1,1],[1,1],[2],[1,1],[1,1],[1,1]});
    rows=cell(0,1);
    for k=1:numel(specs)
        c=specs(k);rows{end+1,1}=checkedCase(c.name,@()twoGuardCase(c)); %#ok<AGROW>
    end
    extra={ ...
        'simultaneous_four',@simultaneousFour; ...
        'consumed_zero_then_legitimate_reentry',@consumedReentry; ...
        'descriptor_reorder_preserves_ID_masks',@reorderedGuards; ...
        'disable_reenable_drops_old_ownership',@disableReenable; ...
        'guard_stop_ID_namespace_collision',@guardAndStop; ...
        'simultaneous_guard_stop_postreset_ownership',@simultaneousGuardStop; ...
        'physical_A_at_B_auxiliary_entry',@auxiliaryCoincidence; ...
        'native_default_later_auxiliary_not_credited',@nativeLaterAuxiliary;
        'later_auxiliary_root_is_not_credited',@laterAuxiliary; ...
        'consumed_stop_requires_reentry',@consumedStop; ...
        'unrelated_coordinate_reset_carries_B',@unrelatedReset; ...
        'reset_geometry_jump_diagnosed',@()unsupportedGeometry('jump'); ...
        'same_value_new_geometry_diagnosed',@()unsupportedGeometry('new-geometry'); ...
        'unknown_geometry_nearzero_diagnosed',@()unsupportedGeometry('unknown'); ...
        'state_jump_crossing_diagnosed',@()unsupportedGeometry('state-jump'); ...
        'restart_binding_rejects_stale_context',@bindingChecks; ...
        'apex_value_override_loses_dy_certificate',@apexCertificates; ...
        'native_independent_leg_reset_commutes',@nativeCommutativity; ...
        'legacy_direct_two_output_API',@legacyDirectAPI};
    extra(end+1,:)={'adapted_original_direct_detector_probe',@adaptedOriginalProbe};
    for k=1:size(extra,1),rows{end+1,1}=checkedCase(extra{k,1},extra{k,2});end %#ok<AGROW>
    report=struct('schema','hybrid-event-restart-regression-v2','rows',{rows}, ...
        'passed',all(cellfun(@(r)r.passed,rows)), ...
        'scope','Real simulator restarts and supported direct lifecycle; default tolerances. Synthetic event tests do not establish historical quadruped admission.');
    if requirePass
        failed=cellfun(@(r)r.name,rows(~cellfun(@(r)r.passed,rows)),'UniformOutput',false);
        assert(report.passed,'HybridEventRestartRegression_v3:RegressionFailure','Failed restart regressions: %s',strjoin(failed,', '));
    end
end

function row=checkedCase(name,run)
    try
        row=run();row.name=name;
    catch exception
        row=struct('name',name,'passed',false,'unexpected_exception', ...
            struct('identifier',exception.identifier,'message',exception.message));
    end
    fprintf('HYBRID_RESTART_CASE %s\n',jsonencode(row));
end

function row=twoGuardCase(c)
    tA=1e-6;p=[1;c.slope];x0=-c.direction.*[tA;c.slope*(tA+c.gap)];
    system=makeSystem(2,2,@(~,~,~,p)c.direction*p, ...
        @(t,x,q,p)linearGuards(t,x,q,p,c.direction,false,true),@identityReset,@consume);
    times=[tA,tA+c.gap];if isequal(c.batches,[2]),times=[tA,tA];end
    [row,tr,result]=simulationRow(system,x0,false(2,1),p,[0,2e-6],[1,2],times,c.batches,struct());
    mode=modeMatrix(tr);
    noPastA=~any(tr.time>tA+2e-10&~mode(:,1));
    row.first_step_earliest_truncation=noPastA;
    row.passed=row.passed&&noPastA;
    row.normal_final_mode=all(result.final_mode);
    row.passed=row.passed&&row.normal_final_mode;
end

function row=simultaneousFour()
    system=makeSystem(4,4,@(~,~,~,p)-p, ...
        @(t,x,q,p)linearGuards(t,x,q,p,-1,false,true),@identityReset,@consume);
    [row,~,result]=simulationRow(system,ones(4,1)*1e-6,false(4,1),ones(4,1),[0,2e-6],1:4,ones(1,4)*1e-6,4,struct());
    row.all_four_consumed=all(result.final_mode);row.passed=row.passed&&row.all_four_consumed;
end

function row=consumedReentry()
    system=makeSystem(1,0,@reentryFlow,@reentryGuards,@identityReset,@(~,q)q+1);
    resolved=struct('ODEOptions',odeset('InitialStep',1e-7,'MaxStep',1e-7));
    [row,tr,result]=simulationRow(system,1e-6,0,[],[0,3e-6],[1,1],[1e-6,2e-6],[1,1],resolved);
    d=result.arming_restart_diagnostics;
    protected=any(cellfun(@(v)strcmp(v.action,'consumed-channel-reentry-protection')&&~v.armed,d));
    row.consumed_zero_protected=protected;
    h=tr.event_history;first=h(find(~[h.is_stop],1));
    proof=resolvedEntryProof(system,first,1,[],3e-6);
    row.resolved_positive_time_auxiliary_entry=proof;row.test_MaxStep=1e-7;
    row.coarse_fixture_limitation='The retained Broad01 MaxStep2e-6 run skipped both roots of the narrow nonmonotone excursion; this resolved fixture changes no event tolerance or physical root.';
    row.passed=row.passed&&protected&&proof.passed;
end

function dx=reentryFlow(t,~,q,~)
    if q==0,dx=-1;elseif q==1,dx=.01-2e4*(t-1e-6);else,dx=0;end
end

function g=reentryGuards(~,x,q,~)
    if q<2,g=descriptors(x,1,-1,true);else,g=descriptors(x,[],-1,true);end
end

function row=reorderedGuards()
    system=makeSystem(3,3,@(~,~,~,p)-p, ...
        @(t,x,q,p)linearGuards(t,x,q,p,-1,true,true),@identityReset,@consume);
    [row,~,result]=simulationRow(system,[1e-6;1.05e-8;0],false(3,1),[1;.01;0],[0,2e-6],[1,2],[1e-6,1.05e-6],[1,1],struct());
    d=result.arming_restart_diagnostics;
    zeroUnarmed=any(cellfun(@(v)isequal(v.id,3)&&~v.armed,d));
    row.zero_channel_remains_unarmed=zeroUnarmed;row.passed=row.passed&&zeroUnarmed;
end

function row=disableReenable()
    system=makeSystem(3,0,@disableFlow,@disableGuards,@disableReset,@consume);
    resolved=struct('ODEOptions',odeset('InitialStep',1e-7,'MaxStep',1e-7));
    [row,tr,result]=simulationRow(system,[1e-6;1e-8;2e-6],false(3,1),[],[0,4e-6],[1,3,2],[1e-6,2e-6,3e-6],[1,1,1],resolved);
    d=result.arming_restart_diagnostics;
    fresh=any(cellfun(@(v)isequal(v.id,2)&&abs(v.time-2e-6)<2e-10 ...
        &&strcmp(v.action,'new-channel-initial-protection')&&~v.armed,d));
    row.reenabled_is_fresh=fresh;
    h=tr.event_history;reenabling=h(find(~[h.is_stop]&[h.guard_id]==3,1));
    proof=resolvedEntryProof(system,reenabling,2,[],4e-6);
    row.resolved_positive_time_auxiliary_entry=proof;row.test_MaxStep=1e-7;
    row.coarse_fixture_limitation='Broad01 MaxStep2e-6 missed the narrow nonmonotone interior excursion; the original failed evidence remains retained.';
    row.passed=row.passed&&fresh&&proof.passed;
end

function dx=disableFlow(t,~,q,~)
    b=0;if q(3)&&~q(2),b=.01-2e4*(t-2e-6);end
    dx=[-1;b;-1];
end

function g=disableGuards(~,x,q,~)
    enabled=[~q(1);~q(2)&&(~q(1)||q(3));~q(3)];
    g=descriptors(x,find(enabled).',-1,true);
end

function x=disableReset(id,~,x,~,~)
    if id==1,x(2)=0;end
end

function row=guardAndStop()
    system=makeSystem(2,2,@(~,~,~,p)-p,@firstGuard,@identityReset,@consume);
    stop=struct('Function',@secondStop);
    [row,tr,result]=simulationRow(system,[1e-6;1.05e-8],false(1,1),[1;.01],[0,2e-6],1,1e-6,1,struct('StopCondition',stop));
    history=tr.event_history;stops=history([history.is_stop]);
    row.stop_detected=result.stop_occurred&&numel(stops)==1&&stops.guard_id==1&&abs(stops.time-1.05e-6)<2e-10;
    row.passed=row.passed&&row.stop_detected;
end

function g=firstGuard(~,x,q,~)
    ids=[];if ~q,ids=1;end;g=descriptors(x,ids,-1,true);
end

function d=secondStop(~,x,~,~)
    d=descriptors(x,2,-1,true);d.id=1;d.name="stop_same_id";d.kind="stop";
end

function row=auxiliaryCoincidence()
    system=makeSystem(2,0,@(~,~,q,~)[-1;.001*(1-2*double(q(1)))], ...
        @(t,x,q,p)linearGuards(t,x,q,p,-1,false,true),@identityReset,@consume);
    [row,~,result]=simulationRow(system,[1e-6;0],false(2,1),[],[0,3e-6],[1,2],[1e-6,2e-6],[1,1],struct());
    d=result.arming_restart_diagnostics;
    retained=any(cellfun(@(v)isequal(v.id,2)&&v.accepted_auxiliary_entry&&v.prior_armed&&v.armed,d));
    row.accepted_auxiliary_ownership_retained=retained;row.passed=row.passed&&retained;
end

function row=simultaneousGuardStop()
    system=makeSystem(1,1,@(~,~,~,p)-p,@firstGuard,@identityReset,@consume);
    options=struct('StopCondition',struct('Function',@firstStop),'ProcessGuardsAtStop',true);
    [row,tr,result]=simulationRow(system,1e-6,false(1,1),1,[0,2e-6],1,1e-6,1,options);
    h=tr.event_history;stops=h([h.is_stop]);
    right=result.stop_occurred&&numel(stops)==1&&all(stops.mode_after)&&all(result.final_mode);
    row.stop_owned_by_postreset_mode=right;row.passed=row.passed&&right;
end

function d=firstStop(~,x,~,~)
    d=descriptors(x,1,-1,true);d.kind="stop";d.name="coordinate_stop";
end

function row=nativeLaterAuxiliary()
    [system,tA]=laterAuxiliarySystem();
    [row,~,result]=simulationRow(system,[tA;0],false(2,1),[],[0,3e-6],1,tA,1,struct());
    d=result.arming_restart_diagnostics;
    notCredited=any(cellfun(@(v)isequal(v.id,2)&&~v.accepted_auxiliary_entry&&~v.prior_armed&&~v.armed,d));
    detector=EventDetector_v3();[~,event,context]=detector.integrate(system,[tA;0],false(2,1),[],[0,3e-6],[],odeset('InitialStep',3e-6,'MaxStep',3e-6));
    row.native_default_future_row_observed=any(event.raw_event_indices>2&event.raw_event_times>event.time ...
        &event.raw_event_times-event.time<=1e-10);
    row.later_auxiliary_not_credited=notCredited&&isempty(context.accepted_auxiliary_guard_ids);
    row.scope='Native default ode45 lifecycle; later-row observation is reported, not presumed. Broad01 default later-row premise was false.';
    row.passed=row.passed&&row.later_auxiliary_not_credited;
end

function row=laterAuxiliary()
    [system,tA]=laterAuxiliarySystem();
    options=struct('ODESolver',@allNativeEventRows);
    [row,~,result]=simulationRow(system,[tA;0],false(2,1),[],[0,3e-6],1,tA,1,options);
    d=result.arming_restart_diagnostics;
    notCredited=any(cellfun(@(v)isequal(v.id,2)&&~v.accepted_auxiliary_entry&&~v.prior_armed&&~v.armed,d));
    detector=EventDetector_v3(options);[segment,event,context]=detector.integrate(system,[tA;0],false(2,1),[],[0,3e-6],[],odeset('InitialStep',3e-6,'MaxStep',3e-6));
    rawFuture=event.raw_event_indices==4&event.raw_event_times>event.time ...
        &event.raw_event_times-event.time<=1e-10;
    exercised=any(rawFuture);
    trueRoot=exercised&&all(abs(event.raw_event_times(rawFuture)-1e-6)<1e-15);
    truncated=segment.time(end)==event.time&&max(segment.time)<=tA+1e-15;
    row.later_auxiliary_reported_within_coarse_group=exercised;
    row.later_auxiliary_not_credited=notCredited&&isempty(context.accepted_auxiliary_guard_ids);
    row.future_auxiliary_true_root_time=trueRoot;row.expected_future_auxiliary_derivative=.001;
    row.adapter_each_root_direction_validated=true;
    row.earliest_state_truncated_before_future_root=truncated;
    row.callback_root_residual_cap=1e-18;
    row.scope='Explicit native-ode45 nonterminal-report adapter; only solver callback terminal flags change. Values/directions are unchanged and every returned raw root is checked in the adapter. Native-default behavior is a separate case.';
    row.passed=row.passed&&exercised&&trueRoot&&truncated&&row.later_auxiliary_not_credited;
end

function [system,tA]=laterAuxiliarySystem()
    tA=1e-6-5e-11;
    system=makeSystem(2,0,@(~,~,q,~)[-1;.001*(1-2*double(q(1)))], ...
        @(t,x,q,p)linearGuards(t,x,q,p,-1,false,true),@identityReset,@consume);
end

function [time,state,eventTime,eventState,eventIndex]=allNativeEventRows(flow,tspan,x0,options)
    % A deterministic solver-return seam: native ODE45 locates all genuine
    % roots while this adapter changes terminal flags only. The detector must
    % truncate the accepted trajectory and arming at the earliest event.
    original=odeget(options,'Events');assert(isa(original,'function_handle'));
    options=odeset(options,'Events',@nonterminal);
    [time,state,eventTime,eventState,eventIndex]=ode45(flow,tspan,x0,options);
    for k=1:numel(eventTime)
        [values,~,directions]=original(eventTime(k),eventState(k,:).');
        assert(abs(values(eventIndex(k)))<=1e-18,'HybridEventRestartRegression_v3:AdapterRootResidual', ...
            'Every adapter-reported raw event must satisfy the unchanged native callback root.');
        index=eventIndex(k);assert(ismember(directions(index),[-1,0,1]),'HybridEventRestartRegression_v3:AdapterDirection');
        step=1e-10;point=eventState(k,:).';velocity=flow(eventTime(k),point);
        plus=original(eventTime(k)+step,point+step*velocity);
        minus=original(eventTime(k)-step,point-step*velocity);
        derivative=(plus(index)-minus(index))/(2*step);
        assert(directions(index)==0||directions(index)*derivative>1e-10, ...
            'HybridEventRestartRegression_v3:AdapterTransversality','Every reported raw root must have the unchanged callback direction.');
    end
    function [values,terminal,directions]=nonterminal(t,x)
        [values,terminal,directions]=original(t,x);terminal=zeros(size(terminal));
    end
end

function proof=resolvedEntryProof(system,processed,id,p,finalTime)
    detector=EventDetector_v3();start=processed.time;
    [segment,event]=detector.integrate(system,processed.state_after,processed.mode_after,p, ...
        [start,finalTime],[],odeset('InitialStep',1e-7,'MaxStep',1e-7));
    at=segment.time>start&abs(segment.state(:,id)-detector.Options.ArmingTolerance)<=1e-18;
    times=segment.time(at);
    crossing=event.occurred&&any([event.guard_batch.id]==id)&&event.time>start;
    passed=segment.arming_restart_count>=1&&~isempty(times)&&crossing;
    proof=struct('passed',passed,'located_arming_restarts',segment.arming_restart_count, ...
        'positive_time_interior_entry_times',times,'physical_root_after_entry',event.time, ...
        'maximum_accepted_interior_value',max(segment.state(:,id)), ...
        'ArmingTolerance',detector.Options.ArmingTolerance,'MaxStep',1e-7);
end

function row=consumedStop()
    system=makeSystem(1,0,@(t,~,~,~)-pi*sin(pi*t/1e-6), ...
        @(t,x,q,p)descriptors(x,[],-1,true),@identityReset,@consume);
    detector=EventDetector_v3();condition=struct('Function',@firstStop);ode=odeset('MaxStep',1e-7);
    [~,first,context]=detector.integrate(system,1e-6,false(1,1),[],[0,1e-6],condition,ode);
    ready=detector.prepareRestart(context,first.state,false(1,1),{},1);
    [~,second]=detector.integrate(system,first.state,false(1,1),[],[first.time,3e-6],condition,ode,ready);
    passed=first.stop_occurred&&second.stop_occurred&&abs(first.time-.5e-6)<2e-10&&abs(second.time-2.5e-6)<2e-10;
    row=struct('passed',passed,'first_stop_time',first.time,'second_stop_time',second.time,'no_immediate_repeat',second.time-first.time>1e-6);
end

function row=unrelatedReset()
    system=makeSystem(3,3,@(~,~,~,p)-p,@twoOfThree,@resetThird,@consume);
    row=simulationRow(system,[1e-6;1.05e-8;0],false(2,1),[1;.01;0],[0,2e-6],[1,2],[1e-6,1.05e-6],[1,1],struct());
end

function g=twoOfThree(~,x,q,~)
    g=descriptors(x,find(~q(:)).',-1,true);
end

function x=resetThird(id,~,x,~,~)
    if id==1,x(3)=x(3)+5;end
end

function row=unsupportedGeometry(kind)
    system=makeSystem(2,2,@(~,~,~,p)-p,@(t,x,q,p)changedGuards(t,x,q,p,kind), ...
        @(id,t,x,q,p)changedReset(id,t,x,q,p,kind),@consume);
    simulator=HybridSimulator_v3(struct('FailurePolicy','return','ODEOptions',odeset('InitialStep',2e-6,'MaxStep',2e-6)));
    [tr,result]=simulator.simulate(system,[1e-6;1.05e-8],false(2,1),[1;.01],[0,2e-6]);
    history=tr.event_history;physical=history(~[history.is_stop]);
    diagnosed=~result.success&&isfield(result,'failure')&&strcmp(result.failure.identifier,'EventDetector_v3:UnsupportedRestartGeometry');
    noFabricatedB=numel(physical)==1&&physical.guard_id==1;
    row=struct('passed',diagnosed&&noFabricatedB,'expected_outcome','unsupported reset geometry diagnostic', ...
        'diagnostic_observed',diagnosed,'no_fabricated_B',noFabricatedB);
    plain=true;try,C1ScientificDigest_v3(result);C1ScientificDigest_v3(tr.metadata);catch,plain=false;end
    row.public_outputs_plain=plain;row.passed=row.passed&&plain;
    if isfield(result,'failure'),row.failure_identifier=result.failure.identifier;row.failure_stage=result.failure.stage;end
    if strcmp(kind,'new-geometry')&&isfield(result,'failure')
        reset=result.failure.pending_reset;
        sameValue=isequaln(reset.state_before(2),reset.state_after(2)+reset.state_after(1));
        row.same_value_at_reset=sameValue;row.passed=row.passed&&sameValue;
    end
end

function g=changedGuards(t,x,q,~,kind)
    declare=~strcmp(kind,'unknown');g=descriptors(x,find(~q(:)).',-1,declare);
    if q(1)
        at=find([g.id]==2,1);
        if ~isempty(at)
            if strcmp(kind,'jump'),g(at).value=x(2)-1e-9;
            elseif strcmp(kind,'new-geometry')
                g(at).value=x(2)+x(1);g(at).metadata.restart_arming.definition='changed-coordinate-surface-v1';
                g(at).metadata.restart_arming.state_dependencies=[1,2];
            end
        end
    end
end

function x=changedReset(id,~,x,~,~,kind)
    if id==1&&strcmp(kind,'state-jump'),x(2)=-1e-6;end
    if id==1&&strcmp(kind,'new-geometry'),x(1)=0;end
end

function row=bindingChecks()
    flow=@(~,~,~,p)-p;guards=@(t,x,q,p)linearGuards(t,x,q,p,-1,false,true);
    system=makeSystem(2,2,flow,guards,@identityReset,@consume);
    detector=EventDetector_v3();p=[1;.01];q=false(2,1);x=[1e-6;1.05e-8];
    [~,event,context]=detector.integrate(system,x,q,p,[0,2e-6]);
    ids=[event.guard_batch.id];[after,next]=system.resolveEventBatch(ids,event.time,event.state,q,p);
    ready=detector.prepareRestart(context,after,next,ids,{});
    timeReject=rejected(@()detector.integrate(system,after,next,p,[event.time+1e-8,2e-6],[],odeset(),ready));
    altered=after;altered(2)=altered(2)+1e-6;
    stateReject=rejected(@()detector.integrate(system,altered,next,p,[event.time,2e-6],[],odeset(),ready));
    pReject=rejected(@()detector.integrate(system,after,next,p+[0;.001],[event.time,2e-6],[],odeset(),ready));
    modeReject=rejected(@()detector.integrate(system,after,~next,p,[event.time,2e-6],[],odeset(),ready));
    stopReject=rejected(@()detector.integrate(system,after,next,p,[event.time,2e-6],struct('Function',@secondStop),odeset(),ready));
    clone=makeSystem(2,2,flow,guards,@identityReset,@consume);
    systemReject=rejected(@()detector.integrate(clone,after,next,p,[event.time,2e-6],[],odeset(),ready));
    condition=struct('Function',@secondStop);[~,sectionEvent,sectionContext]=detector.integrate(system,x,q,p,[0,2e-6],condition);
    sectionIds=[sectionEvent.guard_batch.id];[sectionAfter,sectionMode]=system.resolveEventBatch(sectionIds,sectionEvent.time,sectionEvent.state,q,p);
    sectionReady=detector.prepareRestart(sectionContext,sectionAfter,sectionMode,sectionIds,{});
    callbackReject=rejected(@()detector.integrate(system,sectionAfter,sectionMode,p,[sectionEvent.time,2e-6],struct('Function',@sameSecondStop),odeset(),sectionReady));
    valueSystem=struct('flow',flow,'activeGuards',guards);
    [~,valueEvent,valueContext]=detector.integrate(valueSystem,x,q,p,[0,2e-6]);valueNext=q;valueIds=[valueEvent.guard_batch.id];valueNext(valueIds)=true;
    valueReady=detector.prepareRestart(valueContext,valueEvent.state,valueNext,valueIds,{});valueCopy=valueSystem;
    [~,valueReturn]=detector.integrate(valueCopy,valueEvent.state,valueNext,p,[valueEvent.time,2e-6],[],odeset(),valueReady);
    valueCompatible=valueReturn.occurred&&isequal([valueReturn.guard_batch.id],2);
    row=struct('passed',timeReject&&stateReject&&pReject&&modeReject&&stopReject&&systemReject&&callbackReject&&valueCompatible, ...
        'time_rejected',timeReject,'state_rejected',stateReject,'parameter_rejected',pReject, ...
        'mode_rejected',modeReject,'stop_activation_rejected',stopReject,'system_identity_rejected',systemReject, ...
        'same_value_different_stop_callback_rejected',callbackReject,'struct_system_structural_binding_preserved',valueCompatible);
end

function d=sameSecondStop(t,x,q,p)
    d=secondStop(t,x,q,p);
end

function yes=rejected(run)
    yes=false;try,run();catch exception,yes=strcmp(exception.identifier,'EventDetector_v3:RestartBinding');end
end

function row=apexCertificates()
    x=zeros(14,1);p=[10;10;20;20;1;1;0;0;2;.5];
    native=PoincareSection_v3.apex(4);stop=native.stopCondition(0,-1);[~,~,~,meta]=stop.Function(0,x,false(4,1),p);
    exact=isequal(meta.restart_arming.state_dependencies,4);
    changed=native;changed.ValueFunction=@(x,p)x(7);stop=changed.stopCondition(0,-1);[~,~,~,changedMeta]=stop.Function(0,x,false(4,1),p);
    publicOverride=isequal(changedMeta.restart_arming.state_dependencies,1:14);
    options=PoincareSection_v3.apex(4,struct('ValueFunction',@(x,p)x(7)));stop=options.stopCondition(0,-1);[~,~,~,optionMeta]=stop.Function(0,x,false(4,1),p);
    constructorOverride=isequal(optionMeta.restart_arming.state_dependencies,1:14);
    row=struct('passed',exact&&publicOverride&&constructorOverride,'builtin_dy_only',exact,'public_override_all_state',publicOverride,'constructor_override_all_state',constructorOverride);
end

function row=nativeCommutativity()
    model=Quadrupedal_Dynamics_v3();schema=model.Schema;p=[10;10;20;20;1;1;0;0;2;.5];
    x=zeros(14,1);x(schema.State.y)=1;x(schema.State.dy)=-.3;x(schema.State.dx)=.2;
    ids=schema.Event.IDs(schema.Event.IsTouchdown);
    [~,q,info]=model.resolveEventBatch(ids,0,x,false(4,1),p);
    g=model.activeGuards(0,x,false(4,1),p);geometry=true;
    for k=1:numel(g)
        leg=g(k).leg_index;
        geometry=geometry&&isequal(g(k).metadata.restart_arming.state_dependencies,[schema.State.y,schema.State.phi,schema.Leg.AngleIndices(leg)]);
    end
    passed=info.commutativity_checked&&info.reset_order_commutes&&info.transition_order_commutes&&info.independent_rate_projection_verified&&all(q)&&geometry;
    row=struct('passed',passed,'event_ids',ids,'reset_error',info.commutativity_error,'native_batch_semantics',info.semantics, ...
        'reset_order_commutes',info.reset_order_commutes,'transition_order_commutes',info.transition_order_commutes, ...
        'independent_rate_projection_verified',info.independent_rate_projection_verified,'native_geometry_dependencies',geometry);
end

function row=legacyDirectAPI()
    system=makeSystem(2,2,@(~,~,~,p)-p,@(t,x,q,p)linearGuards(t,x,q,p,-1,false,true),@identityReset,@consume);
    detector=EventDetector_v3();[segment,event]=detector.integrate(system,[1e-6;1.05e-8],false(2,1),[1;.01],[0,2e-6],[],odeset());
    row=struct('passed',event.occurred&&event.guard_batch(1).id==1&&abs(event.time-1e-6)<2e-10&&segment.time(end)==event.time, ...
        'old_two_output_call_supported',true,'first_event_time',event.time);
end

function row=adaptedOriginalProbe()
    specs=struct('name',{'simultaneous','batched_close','distinct_fast','distinct_slow'}, ...
        'slope',{.01,.01,1,.01},'gap',{0,5e-9,5e-8,5e-8});
    results=cell(numel(specs),1);
    system=struct('flow',@(~,~,~,p)-p, ...
        'activeGuards',@(t,x,q,p)linearGuards(t,x,q,p,-1,false,true));
    for k=1:numel(specs)
        c=specs(k);p=[1;c.slope];x=[1e-6;c.slope*(1e-6+c.gap)];q=false(2,1);detector=EventDetector_v3();
        [~,first,context]=detector.integrate(system,x,q,p,[0,2e-6]);ids=[first.guard_batch.id];q(ids)=true;count=numel(ids);times=first.time;
        if ~all(q)
            ready=detector.prepareRestart(context,first.state,q,ids,{});
            [~,second]=detector.integrate(system,first.state,q,p,[first.time,2e-6],[],odeset(),ready);
            count=count+numel(second.guard_batch);times=[times,second.time];
        end
        results{k}=struct('name',c.name,'physical_count',count,'times',times,'passed',count==2);
    end
    row=struct('passed',all(cellfun(@(r)r.passed,results)),'cases',{results}, ...
        'scope','Original supplied two-detector-call trajectories with truthful geometry metadata and supported prepareRestart handoff; no slope/gap/tolerance change.');
end

function [row,tr,result]=simulationRow(system,x,q,p,tspan,ids,times,batchSizes,options)
    options.FailurePolicy='return';
    if ~isfield(options,'ODEOptions'),options.ODEOptions=odeset('InitialStep',diff(tspan),'MaxStep',diff(tspan));end
    simulator=HybridSimulator_v3(options);[tr,result]=simulator.simulate(system,x,q,p,tspan);
    history=tr.event_history;physical=history(~[history.is_stop]);actualIds=[physical.guard_id];actualTimes=[physical.time];
    sizes=reshape(arrayfun(@(b)numel(b.event_ids),tr.event_batches),1,[]);
    countOK=numel(actualIds)==numel(ids);idOK=isequal(actualIds,ids);
    timeOK=countOK&&max(abs(actualTimes-times),[],'all')<=2e-10;
    batchOK=isequal(sizes,reshape(batchSizes,1,[]));
    entriesComplete=all(arrayfun(@(e)all(isfield(e,{'state_before','state_after','mode_before','mode_after','metadata'}))&&isfield(e.metadata,'event_batch_index'),physical));
    monotone=all(diff(tr.time)>=0);plain=true;
    try,C1ScientificDigest_v3(result);C1ScientificDigest_v3(tr.metadata);catch,plain=false;end
    row=struct('passed',result.success&&countOK&&idOK&&timeOK&&batchOK&&entriesComplete&&monotone&&plain, ...
        'simulation_success',result.success,'termination_reason',result.termination_reason,'expected_ids',ids,'actual_ids',actualIds, ...
        'expected_times',times,'actual_times',actualTimes,'expected_batch_sizes',batchSizes,'actual_batch_sizes',sizes, ...
        'complete_individual_records',entriesComplete,'monotone_accepted_times',monotone,'public_outputs_plain',plain);
    if isfield(result,'failure'),row.failure_identifier=result.failure.identifier;row.failure_stage=result.failure.stage;end
end

function system=makeSystem(n,m,flow,guards,reset,transition)
    system=HybridSystemBase_v3(struct('StateDimension',n,'ParameterDimension',m, ...
        'FlowFunction',flow,'ActiveGuardsFunction',guards,'ResetFunction',reset,'TransitionFunction',transition));
end

function g=linearGuards(~,x,q,~,direction,reorder,declare)
    ids=find(~q(:)).';if reorder&&q(1),ids=fliplr(ids);end;g=descriptors(x,ids,direction,declare);
end

function g=descriptors(x,ids,direction,declare)
    prototype=struct('id',0,'name',"",'value',0,'direction',direction,'isterminal',true, ...
        'enabled',true,'interior_sign',-direction,'kind',"synthetic-contact",'metadata',struct());
    g=repmat(prototype,0,1);
    for id=ids(:).'
        d=prototype;d.id=id;d.name="linear_"+id;d.value=x(id);
        if declare,d.metadata.restart_arming=struct('schema','state-parameter-guard-geometry-v1', ...
            'definition',sprintf('synthetic-linear-coordinate-%d-v1',id),'state_dependencies',id,'mode_independent',true);end
        g(end+1,1)=d; %#ok<AGROW>
    end
end

function x=identityReset(~,~,x,~,~)
end

function q=consume(id,q)
    q(id)=true;
end

function matrix=modeMatrix(tr)
    if iscell(tr.mode),matrix=cell2mat(cellfun(@(v)v(:).',tr.mode,'UniformOutput',false));else,matrix=tr.mode;end
end
