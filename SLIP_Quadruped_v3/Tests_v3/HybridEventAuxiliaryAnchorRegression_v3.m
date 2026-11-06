function report=HybridEventAuxiliaryAnchorRegression_v3(requirePass)
%HYBRIDEVENTAUXILIARYANCHORREGRESSION_V3 True earliest-root ownership.
% All physical roots are independent linear guards with known exact times.
% An auxiliary interior-entry root is never a physical/section batch anchor.
    if nargin<1,requirePass=true;end
    validateattributes(requirePass,{'logical'},{'scalar'});
    specs={ ...
        'physical_no_auxiliary_control',@()physicalCase(11e-9,0,false,false); ...
        'auxiliary_only_cannot_anchor_physical_B',@()physicalCase(11e-9,1/3,false,false); ...
        'auxiliary_only_cannot_anchor_section_B',@()physicalCase(11e-9,1/3,true,false); ...
        'later_physical_row_and_unsorted_state',@()physicalCase(20.05e-9,.05,false,true); ...
        'auxiliary_only_exact_entry_ownership',@()entryCase(5e-11); ...
        'simultaneous_auxiliary_entries_control',@()entryCase(0)};
    rows=cell(size(specs,1),1);
    for k=1:size(specs,1)
        try,row=specs{k,2}();row.name=specs{k,1};
        catch exception,row=struct('name',specs{k,1},'passed',false,'unexpected_exception', ...
                struct('identifier',exception.identifier,'message',exception.message));end
        rows{k}=row;fprintf('HYBRID_AUXILIARY_ANCHOR_CASE %s\n',jsonencode(row));
    end
    report=struct('schema','hybrid-auxiliary-earliest-root-regression-v1','rows',{rows}, ...
        'passed',all(cellfun(@(r)r.passed,rows)), ...
        'scope','Real simulator/detector linear-root seams. Explicit native ode45 report adapters are labelled; no stored orbit is admitted or historically requalified.');
    if requirePass
        failed=rows(~cellfun(@(r)r.passed,rows));names=cellfun(@(r)r.name,failed,'UniformOutput',false);
        assert(report.passed,'HybridEventAuxiliaryAnchorRegression_v3:RegressionFailure','Failed earliest-root regressions: %s',strjoin(names,', '));
    end
end

function row=physicalCase(gap,rate,section,reverse)
    tA=1e-6;tB=tA+gap;
    system=HybridSystemBase_v3(struct('StateDimension',3,'ParameterDimension',0, ...
        'FlowFunction',@(~,~,q,~)[-1;-.01;-rate*double(q(1))], ...
        'ActiveGuardsFunction',@(t,x,q,p)activeGuards(t,x,q,p,section), ...
        'ResetFunction',@identityReset,'TransitionFunction',@consume));
    options=struct('FailurePolicy','return','ODEOptions',odeset('InitialStep',2e-6,'MaxStep',2e-6));
    if section,options.StopCondition=struct('Function',@sectionB);end
    if reverse,options.ODESolver=@reverseNativeRows;end
    simulator=HybridSimulator_v3(options);[tr,result]=simulator.simulate(system,[tA;.01*tB;0],false(3,1),[],[0,2e-6]);
    h=tr.event_history;physical=h(~[h.is_stop]);stops=h([h.is_stop]);ids=[physical.guard_id];
    normal=result.success;firstCorrect=~isempty(physical)&&physical(1).guard_id==1&&abs(physical(1).time-tA)<=1e-16;
    actualB=NaN;valueB=NaN;stateMismatch=NaN;rightRoot=false;
    if section
        normal=normal&&result.stop_occurred&&strcmp(result.termination_reason,'stop_condition');
        if numel(stops)==1,actualB=stops.time;valueB=stops.state_before(2);end
        countCorrect=isequal(ids,1)&&numel(stops)==1&&stops.guard_id==2;
    else
        normal=normal&&strcmp(result.termination_reason,'final_time');
        at=find([physical.guard_id]==2);
        if isscalar(at)
            actualB=physical(at).time;valueB=physical(at).state_before(2);
            stateMismatch=max(abs([physical(at).state_before(2)-.01*(tB-actualB); ...
                physical(at).state_before(3)+rate*(actualB-physical(1).time)]));
        end
        countCorrect=isequal(ids,[1,2])&&isempty(stops)&&numel(tr.event_batches)==2;
    end
    rightRoot=isfinite(actualB)&&abs(actualB-tB)<=1e-16&&abs(valueB)<=1e-18;
    stateConsistent=section||(isfinite(stateMismatch)&&stateMismatch<=1e-18);
    entry=NaN;if rate>0,entry=tA+simulator.Options.ArmingTolerance/rate;end
    plain=true;try,C1ScientificDigest_v3(result);C1ScientificDigest_v3(tr.metadata);catch,plain=false;end
    row=struct('passed',normal&&firstCorrect&&countCorrect&&rightRoot&&stateConsistent&&plain, ...
        'simulation_completed_normally',normal,'first_A_root_exact',firstCorrect,'individual_record_counts_correct',countCorrect, ...
        'expected_B_root_time',tB,'actual_B_time',actualB,'B_time_error',actualB-tB,'B_value_at_reported_time',valueB, ...
        'actual_guard_ids',ids,'actual_guard_times',[physical.time],'stop_count',numel(stops), ...
        'physical_state_time_mismatch',stateMismatch,'physical_state_time_consistent',stateConsistent, ...
        'new_opposite_C_interior_entry_time',entry,'C_interior_speed',rate,'public_outputs_plain',plain, ...
        'event_time_assertion_tolerance',1e-16,'unchanged_ArmingTolerance',simulator.Options.ArmingTolerance, ...
        'unchanged_EventTimeTolerance',simulator.Options.EventTimeTolerance,'unchanged_SimultaneousTimeTolerance',simulator.Options.SimultaneousTimeTolerance);
    if reverse,row.solver_scope='Native ode45 changes only terminal flags to report genuine roots; raw event-row order is then reversed, preserving each time/state/index tuple. All callback residuals and directions are checked.';
    else,row.solver_scope='Native default ode45; default event/arming tolerances.';end
end

function g=activeGuards(~,x,q,~,section)
    ids=[];if ~q(1),ids(end+1)=1;end
    if ~section&&~q(2),ids(end+1)=2;end
    if q(1)&&~q(3),ids(end+1)=3;end
    g=descriptors(x,ids);
end
function d=sectionB(~,x,~,~),d=descriptors(x,2);d.kind="stop";end

function row=entryCase(gap)
    tA=1e-6;tB=tA+gap;slopes=[1e-9/tA;1e-9/tB];
    system=HybridSystemBase_v3(struct('StateDimension',2,'ParameterDimension',2, ...
        'FlowFunction',@(~,~,~,p)p,'ActiveGuardsFunction',@entryGuards, ...
        'ResetFunction',@identityReset,'TransitionFunction',@consume));
    detector=EventDetector_v3(struct('ODESolver',@allNativeRows));
    [segment,event,context]=detector.integrate(system,[0;0],false(2,1),slopes,[0,3e-6],[],odeset('InitialStep',3e-6,'MaxStep',3e-6));
    expected=1+double(gap>0);locatedA=any(abs(segment.time-tA)<=1e-16);locatedB=any(abs(segment.time-tB)<=1e-16);
    atA=find(abs(segment.time-tA)<=1e-16);stateA=segment.state(atA(1),:).';
    stateAtFirstExact=abs(stateA(1)-1e-9)<=1e-18&&abs(stateA(2)-slopes(2)*tA)<=1e-18;
    normal=~event.occurred&&segment.time(end)==3e-6&&context.time==3e-6;
    row=struct('passed',normal&&segment.arming_restart_count==expected&&locatedA&&locatedB&&stateAtFirstExact, ...
        'integration_completed_normally',normal,'expected_arming_restart_count',expected, ...
        'actual_arming_restart_count',segment.arming_restart_count,'accepted_first_entry_time_present',locatedA, ...
        'accepted_second_entry_time_present',locatedB,'accepted_first_state_exact',stateAtFirstExact, ...
        'first_entry_time',tA,'second_entry_time',tB,'entry_gap',gap, ...
        'solver_scope','Explicit native ode45 nonterminal-report adapter, genuine unchanged callback roots only; not a default-solver multirow premise.');
end
function g=entryGuards(~,x,~,~),g=descriptors(x,[1,2]);end

function [time,state,te,ye,ie]=allNativeRows(flow,tspan,x0,options)
    [time,state,te,ye,ie]=nativeRows(flow,tspan,x0,options,false);
end
function [time,state,te,ye,ie]=reverseNativeRows(flow,tspan,x0,options)
    [time,state,te,ye,ie]=nativeRows(flow,tspan,x0,options,true);
end
function [time,state,te,ye,ie]=nativeRows(flow,tspan,x0,options,reverse)
    original=odeget(options,'Events');assert(isa(original,'function_handle'));
    options=odeset(options,'Events',@nonterminal);[time,state,te,ye,ie]=ode45(flow,tspan,x0,options);
    for k=1:numel(te)
        point=ye(k,:).';[values,~,directions]=original(te(k),point);index=ie(k);
        assert(abs(values(index))<=1e-18,'HybridEventAuxiliaryAnchorRegression_v3:AdapterRoot');
        step=1e-10;velocity=flow(te(k),point);plus=original(te(k)+step,point+step*velocity);minus=original(te(k)-step,point-step*velocity);
        derivative=(plus(index)-minus(index))/(2*step);
        assert(directions(index)==0||directions(index)*derivative>1e-10,'HybridEventAuxiliaryAnchorRegression_v3:AdapterDirection');
    end
    if reverse,te=flipud(te);ye=flipud(ye);ie=flipud(ie);end
    function [values,terminal,directions]=nonterminal(t,x)
        [values,terminal,directions]=original(t,x);terminal=zeros(size(terminal));
    end
end
function g=descriptors(x,ids)
    prototype=struct('id',0,'name',"",'value',0,'direction',-1,'isterminal',true, ...
        'enabled',true,'interior_sign',1,'kind',"synthetic-contact",'metadata',struct());g=repmat(prototype,0,1);
    for id=ids
        d=prototype;d.id=id;d.name="auxiliary_coordinate_"+id;d.value=x(id);
        if id==3,d.direction=1;d.interior_sign=-1;d.kind="synthetic-opposite";end
        d.metadata.restart_arming=struct('schema','state-parameter-guard-geometry-v1', ...
            'definition',sprintf('auxiliary-coordinate-%d-v1',id),'state_dependencies',id,'mode_independent',true);
        g(end+1,1)=d; %#ok<AGROW>
    end
end
function x=identityReset(~,~,x,~,~),end
function q=consume(id,q),q(id)=true;end
