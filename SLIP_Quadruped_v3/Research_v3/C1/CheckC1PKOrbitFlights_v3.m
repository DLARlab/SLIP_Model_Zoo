function result=CheckC1PKOrbitFlights_v3(source,parameter,options)
%CHECKC1PKORBITFLIGHTS_V3 Bind raw cycle flights to observed reset cohorts.
% This conditional numerical supplement does not admit an orbit. It never
% interpolates, projects a state, or constructs a trajectory across the seam.
required={'SwingPenetrationTolerance','ArithmeticCushion','DerivativeCushion', ...
    'CurvatureCushion','EventTimeTolerance','Limits'};
assert(nargin==3&&isstruct(options)&&isscalar(options)&&all(isfield(options,required)), ...
    'C1OrbitFlights:Options','Supply actual native tolerances, cushions and both parent clocks.');
o=struct('SwingPenetrationTolerance',[],'ArithmeticCushion',[],'DerivativeCushion',[], ...
    'CurvatureCushion',[],'EventTimeTolerance',[],'Limits',struct(), ...
    'MaxWallSeconds',60,'IntervalMaxWallSeconds',30,'MaxCells',262144, ...
    'MaxDepth',24,'MaximumUnresolvedIntervals',64,'RequireOneFlightEventWord',true);
assert(all(ismember(fieldnames(options),fieldnames(o))),'C1OrbitFlights:Options','Unknown option.');
for name=fieldnames(options).',o.(name{1})=options.(name{1});end
for name={'ArithmeticCushion','DerivativeCushion','CurvatureCushion','EventTimeTolerance'}
    validateattributes(o.(name{1}),{'double'},{'real','finite','scalar','positive'});
end
validateattributes(o.MaxWallSeconds,{'double'},{'real','finite','scalar','positive','<=',120});
validateattributes(o.IntervalMaxWallSeconds,{'double'},{'real','finite','scalar','positive','<=',60});
assert(islogical(o.RequireOneFlightEventWord)&&isscalar(o.RequireOneFlightEventWord), ...
    'C1OrbitFlights:Options','RequireOneFlightEventWord must be a scalar logical.');
assert(isstruct(o.Limits)&&isscalar(o.Limits)&&all(isfield(o.Limits, ...
    {'deadline_unix_seconds','deadline_monotonic_ns'})),'C1OrbitFlights:Limits','Both parent clocks are required.');
entry=clockNow();limit=struct('deadline_unix_seconds',min(o.Limits.deadline_unix_seconds,entry.u+o.MaxWallSeconds), ...
    'deadline_monotonic_ns',min(o.Limits.deadline_monotonic_ns,entry.m+o.MaxWallSeconds*1e9));
result=struct('schema','C1-actual-orbit-flight-supplement-v1','status','UNASSESSED', ...
    'reason','','options',o,'intervals',{{}},'cohorts',{{}},'flight_fragment_count',0, ...
    'flight_count_if_periodically_closed',NaN,'boundary_flight_fragments_meet_section',false, ...
    'actual_cyclic_flight_count_claimed',false,'seam_states_glued',false, ...
    'literal_endpoint_lineage_bound',false,'every_positive_duration_flight_assessed',false, ...
    'all_flight_supplements_passed',false,'return_timely',false,'failure',struct(), ...
    'source_state_changes',0,'interpolated_states',0,'ODE_calls',0,'root_calls',0, ...
    'new_admission_claimed',false,'formal_continuous_coverage_claimed',false, ...
    'scope',['Actual batch states/times and retained trajectory rows own all endpoints. ', ...
    'PASS is conditional on the interval checker arithmetic assumptions and native event records. ', ...
    'The one-flight event word is prospective compatibility if periodically closed; open root/FD returns need not close. ', ...
    'It does not establish periodic closure, primitive cyclic count, classification, other physical gates or branch connectivity.']);
try
    check(limit);s=QuadrupedSchema_v3.shared();p=s.validateParameter(parameter);
    assert((isstruct(source)&&isscalar(source))||isa(source,'HybridOrbit_v3'), ...
        'C1OrbitFlights:Source','Use actual NativeMap info or HybridOrbit.');
    trajectory=source.trajectory;
    assert(isa(trajectory,'Trajectory_v3'),'C1OrbitFlights:Trajectory','Full raw trajectory is required.');
    if isstruct(source)&&isfield(source,'initial_time')&&isfield(source,'raw_return_state')
        start=source.initial_time;finish=source.return_time;
        initial=s.validateState(source.initial_state);final=s.validateState(source.raw_return_state);
        qi=s.validateMode(source.initial_mode);qf=s.validateMode(source.final_mode);
        period=source.period;
    else
        assert(isa(source,'HybridOrbit_v3'),'C1OrbitFlights:Source','Unrecognized source contract.');
        assert(isequal(p(:),source.parameter(:)),'C1OrbitFlights:Parameter','Literal orbit parameter mismatch.');
        start=trajectory.time(1);period=source.period;finish=start+period;
        initial=s.validateState(source.initial_state);qi=s.validateMode(source.initial_mode);
        last=find(trajectory.time==finish,1,'last');
        assert(~isempty(last),'C1OrbitFlights:Endpoint','No exact retained final section sample.');
        final=s.validateState(trajectory.state(last,:));qf=modeAt(trajectory,last,s);
    end
    assert(isfinite(start)&&isfinite(finish)&&finish>start&&finish-start==period, ...
        'C1OrbitFlights:Period','Literal section times and period must agree exactly.');
    wrap=struct('trajectory',trajectory,'period',period,'parameter',p,'event_history',source.event_history);
    data=HybridCycleData_v3.unpack(wrap);t=data.time;X=data.state;Q=data.mode;
    assert(t(1)==start&&t(end)==finish,'C1OrbitFlights:Span','Raw trajectory must span exactly the accepted return.');
    bind(t,X,Q,start,initial,qi);bind(t,X,Q,finish,final,qf);
    assert(isequal(qi,qf),'C1OrbitFlights:SectionMode','Discrete section closure is required for cyclic flight counting.');
    batches=trajectory.event_batches;
    assert(~isempty(batches),'C1OrbitFlights:Batches','Actual aggregate physical reset batches are required.');
    assert(all(isfinite([batches.time]))&&all(diff([batches.time])>=0) ...
        &&all([batches.time]>=start)&&all([batches.time]<=finish), ...
        'C1OrbitFlights:BatchTimes','All recorded batches must belong to this accepted cycle.');
    cohorts=makeCohorts(batches,data.history,t,X,Q,s,limit);result.cohorts=cohorts;
    current=struct('time',start,'state',initial,'mode',qi,'kind','apex','cohort',0);
    fragments=cell(0,1);
    for k=1:numel(cohorts)
        check(limit);c=cohorts{k};
        assert(isequal(current.mode,c.mode_before),'C1OrbitFlights:ModeChain','Reset chain has an unexplained mode change.');
        endpoint=struct('time',c.time,'state',c.state_before,'mode',c.mode_before,'kind',c.kind,'cohort',k);
        fragments=appendSpan(fragments,current,endpoint,t,Q,limit);
        current=struct('time',c.time,'state',c.state_after,'mode',c.mode_after,'kind',c.kind,'cohort',k);
    end
    endpoint=struct('time',finish,'state',final,'mode',qf,'kind','apex','cohort',0);
    assert(isequal(current.mode,qf),'C1OrbitFlights:ModeChain','Final mode does not match aggregate reset history.');
    fragments=appendSpan(fragments,current,endpoint,t,Q,limit);
    result.literal_endpoint_lineage_bound=true;result.flight_fragment_count=numel(fragments);
    assert(~isempty(fragments),'C1OrbitFlights:NoFlight','One-flight target has no positive-duration all-flight interval.');
    across=~any(qi)&&fragments{1}.start.time==start&&fragments{end}.finish.time==finish ...
        &&numel(fragments)>1;
    count=numel(fragments)-double(across);
    result.flight_count_if_periodically_closed=count;result.boundary_flight_fragments_meet_section=across;
    assert(~o.RequireOneFlightEventWord||count==1,'C1OrbitFlights:FlightCount', ...
        'Target requires a one-flight event word, conditional on eventual periodic closure.');
    for k=1:numel(fragments)
        check(limit);f=fragments{k};
        assert(any(strcmp(f.start.kind,{'apex','LO'}))&&any(strcmp(f.finish.kind,{'apex','TD'})), ...
            'C1OrbitFlights:EndpointKind','Flight must begin at literal apex/post-LO and end at literal apex/pre-TD.');
        epsilon=o.EventTimeTolerance;
        io=struct('SwingPenetrationTolerance',o.SwingPenetrationTolerance, ...
            'ArithmeticCushion',o.ArithmeticCushion,'DerivativeCushion',o.DerivativeCushion, ...
            'CurvatureCushion',o.CurvatureCushion,'Limits',limit, ...
            'InitialEndpointKind',f.start.kind,'FinalEndpointKind',f.finish.kind, ...
            'EndpointTimeTolerance',epsilon,'ActualFinalState',f.finish.state, ...
            'MaxWallSeconds',min(o.IntervalMaxWallSeconds,remaining(limit)), ...
            'MaxCells',o.MaxCells,'MaxDepth',o.MaxDepth,'MaximumUnresolvedIntervals',o.MaximumUnresolvedIntervals);
        evidence=CheckC1PKFlightInterval_v3(f.start.state,f.start.mode,p,f.duration,io);
        f.supplement=evidence;f.actual_endpoint_lineage_bound=true;result.intervals{end+1,1}=f;
        if strcmp(evidence.status,'VIOLATION')
            result.status='VIOLATION';result.reason='ACTUAL_FLIGHT_HAS_CONDITIONAL_PHYSICAL_VIOLATION';break
        elseif ~strcmp(evidence.status,'PASS')
            result.reason='ACTUAL_FLIGHT_SUPPLEMENT_UNASSESSED';break
        end
    end
    result.every_positive_duration_flight_assessed=numel(result.intervals)==numel(fragments);
    result.all_flight_supplements_passed=result.every_positive_duration_flight_assessed ...
        &&all(cellfun(@(f)strcmp(f.supplement.status,'PASS')&&f.supplement.return_timely,result.intervals));
    if result.all_flight_supplements_passed&&remaining(limit)>0
        result.status='PASS';result.reason='ALL_ACTUAL_FLIGHTS_CONDITIONALLY_PASSED';
    end
catch problem
    result.failure=struct('identifier',problem.identifier,'message',problem.message);
    result.reason='RAW_HISTORY_ENDPOINT_TOPOLOGY_OR_RESOURCE_UNASSESSED';
end
ended=clockNow();result.return_timely=remaining(limit)>0;result.elapsed_seconds=(ended.m-entry.m)/1e9;
if ~result.return_timely&&strcmp(result.status,'PASS')
    result.status='UNASSESSED';result.all_flight_supplements_passed=false;result.reason='LOCAL_OR_PARENT_DEADLINE_EXPIRED';
end
end

function cohorts=makeCohorts(batches,history,t,X,Q,s,limit)
cohorts=cell(0,1);position=1;used=false(numel(history),1);
while position<=numel(batches)
    check(limit);last=position;
    while last<numel(batches)&&batches(last+1).time==batches(position).time,last=last+1;end
    ids=[];first=batches(position);final=batches(last);previous=[];
    for j=position:last
        b=batches(j);assert(isfield(b.batch_info,'atomic')&&isequal(b.batch_info.atomic,true), ...
            'C1OrbitFlights:Atomic','Only actual atomic batch records are supported.');
        before=s.validateState(b.state_before);after=s.validateState(b.state_after);
        qb=s.validateMode(b.mode_before);qa=s.validateMode(b.mode_after);
        bind(t,X,Q,b.time,before,qb);bind(t,X,Q,b.time,after,qa);
        if ~isempty(previous)
            assert(isequal(previous.state_after(:),before)&&isequal(previous.mode_after(:),qb), ...
                'C1OrbitFlights:AtomicChain','Same-time aggregate batches do not chain literally.');
        end
        raw=b.event_ids;if iscell(raw),raw=cell2mat(raw(:));end;raw=raw(:).';
        assert(isnumeric(raw)&&all(ismember(raw,s.Event.IDs)),'C1OrbitFlights:EventIDs','Unknown physical event ID.');
        members=find(arrayfun(@(e)isfield(e.metadata,'event_batch_index') ...
            &&isequal(e.metadata.event_batch_index,j),history));
        assert(numel(members)==numel(raw)&&all([history(members).time]==b.time) ...
            &&isequal(sort([history(members).guard_id]),sort(raw)), ...
            'C1OrbitFlights:HistoryBinding','Physical scalar history does not match its aggregate batch.');
        used(members)=true;ids=[ids,raw];previous=b; %#ok<AGROW>
    end
    assert(numel(ids)==4&&numel(unique(ids))==4&&isequal(sort(s.Event.LegIndices(ids)),1:4) ...
        &&(all(s.Event.IsTouchdown(ids))||all(~s.Event.IsTouchdown(ids))), ...
        'C1OrbitFlights:CompleteCohort','A flight endpoint requires one same-kind event for each of four legs.');
    td=all(s.Event.IsTouchdown(ids));kind='LO';if td,kind='TD';end
    qb=s.validateMode(first.mode_before);qa=s.validateMode(final.mode_after);
    assert(all(qb==~td)&&all(qa==td),'C1OrbitFlights:CohortMode','Complete cohort does not connect all-stance and all-flight.');
    cohorts{end+1,1}=struct('time',first.time,'kind',kind,'batch_indices',position:last, ...
        'event_ids',ids,'state_before',first.state_before(:),'state_after',final.state_after(:), ...
        'mode_before',qb,'mode_after',qa,'history_binding_verified',true); %#ok<AGROW>
    position=last+1;
end
assert(all(used),'C1OrbitFlights:UnownedEvent','Physical history has an event without an owned aggregate batch.');
end

function fragments=appendSpan(fragments,left,right,t,Q,limit)
check(limit);assert(right.time>=left.time,'C1OrbitFlights:Order','Endpoint times are not chronological.');
if right.time==left.time,return;end
% Positive-duration sample spans use their last left-side row. Same-time
% intermediate reset modes have no duration and are never classified as flight.
rows=find(t(1:end-1)>=left.time&t(1:end-1)<right.time&diff(t)>0);
assert(~isempty(rows)&&all(all(Q(rows,:)==left.mode(:).')) ...
    &&isequal(left.mode,right.mode),'C1OrbitFlights:RecordedModes','Recorded positive-duration modes disagree with aggregate cohorts.');
if ~any(left.mode)
    fragments{end+1,1}=struct('start',left,'finish',right,'duration',right.time-left.time); %#ok<AGROW>
else
    assert(all(left.mode),'C1OrbitFlights:MixedMode','This one-flight synchronous target does not support positive-duration mixed contact.');
end
end
function bind(t,X,Q,time,state,mode)
rows=find(t==time);found=false;
for j=rows(:).',if isequal(X(j,:).',state(:))&&isequal(Q(j,:).',logical(mode(:))),found=true;break;end;end
assert(found,'C1OrbitFlights:LiteralEndpoint','Full literal endpoint state/mode is absent at its exact retained time.');
end
function q=modeAt(trajectory,row,s)
raw=trajectory.mode;if iscell(raw),q=s.validateMode(raw{row});else,q=s.validateMode(raw(row,:));end
end
function n=clockNow(),n=struct('u',double(java.time.Instant.now().toEpochMilli())/1000,'m',double(java.lang.System.nanoTime()));end
function v=remaining(l),n=clockNow();v=min(l.deadline_unix_seconds-n.u,(l.deadline_monotonic_ns-n.m)/1e9);end
function check(l),assert(remaining(l)>0,'C1OrbitFlights:Deadline','Local or parent deadline expired.');end
