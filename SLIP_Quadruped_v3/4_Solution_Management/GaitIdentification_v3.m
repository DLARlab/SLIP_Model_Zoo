function result = GaitIdentification_v3(source, options)
%GAITIDENTIFICATION_V3 Versioned primitive-cycle gait classification contract.
% Native legs are [BL BR FL FR]. Legacy LABEL is retained for GUI/import
% compatibility; VALIDATED_GAIT_TYPE and CANONICAL_POINT_LABEL are versioned.
% Classification never changes the source state, guards, or return policy.
if nargin<2,options=struct();end
options=localOptions(options);
data=HybridCycleData_v3.unpack(source);s=data.schema;t0=data.start_time;
primitive=PrimitiveCycleCheck_v3(source,options.PrimitiveOptions);
primitiveKnown=isfinite(primitive.primitive_period) && primitive.status~="unknown";
T=primitive.primitive_period;if ~primitiveKnown,T=data.period;end
absoluteEventTolerance=max(data.time_tolerance,options.EventTimeTolerance*T);
contactAudit=HybridCycleData_v3.reconstructContact(data,T,absoluteEventTolerance);
events=contactAudit.events;
intervals=localIntervals(contactAudit.knots,~any(contactAudit.modes,2),T);
flightDurations=diff(intervals,1,2);
threshold=options.FlightDurationTolerance*T;levels=threshold*[.1 1 10];
counts=arrayfun(@(tol)sum(flightDurations>tol),levels);
resolutionCounts=zeros(1,3);
for k=1:3
    audit=HybridCycleData_v3.reconstructContact(data,T,absoluteEventTolerance*10^(k-2));
    arcs=localIntervals(audit.knots,~any(audit.modes,2),T);
    resolutionCounts(k)=sum(diff(arcs,1,2)>threshold);
end
countCertain=primitiveKnown && contactAudit.complete && all(counts==counts(2)) ...
    && all(resolutionCounts==counts(2));
flightCount=counts(2);if ~primitiveKnown || ~contactAudit.complete,flightCount=NaN;end
resolvedIntervals=intervals(flightDurations>threshold,:);
half=localHalfShift(events,T,absoluteEventTolerance,primitiveKnown && contactAudit.complete);
% Audit all saved values, both event limits, and a registered phase grid.
phase=(0:options.SampleCount-1).'/options.SampleCount;
query=unique([t0+phase*T;data.time(data.time>=t0 & data.time<=t0+T); ...
    t0+[events.cycle_time].']);
[xr,qr]=HybridCycleData_v3.sample(data,query,'right');
[xl,ql]=HybridCycleData_v3.sample(data,query,'left');
state=[xr;xl];mode=[qr;ql];
for k=1:numel(contactAudit.cohorts)
    members=contactAudit.cohorts{k};
    % A simultaneous cohort has only external physical one-sided limits.
    % Serial reset-storage intermediates are zero-duration implementation
    % states, and cannot break a paired physical gait.
    before=data.history(events(members(1)).history_index);
    after=data.history(events(members(end)).history_index);
    if numel(before.state_before)==s.StateDimension && numel(before.mode_before)==4
        state(end+1,:)=before.state_before(:).';mode(end+1,:)=s.validateMode(before.mode_before).'; %#ok<AGROW>
    end
    if numel(after.state_after)==s.StateDimension && numel(after.mode_after)==4
        state(end+1,:)=after.state_after(:).';mode(end+1,:)=s.validateMode(after.mode_after).'; %#ok<AGROW>
    end
end
[x0,q0]=HybridCycleData_v3.sample(data,t0,'right');
initial=localSynchrony(x0,q0,s,options);
cycle=localSynchrony(state,mode,s,options);
initial.type=localType(initial);
cycle.physical_chart=localPhysicalChartAudit(data,T,events,options);
cycle.required_sync_consistent=localRequiredSync(initial.type,cycle);
cycle.all_four_invariance=localAllFourInvariance(data,T,state,mode,cycle,options);
cycle.numerical_scope="all saved samples, both physical event limits, and registered phase grid";
cycle.sample_count=size(state,1);
cycle.invariant_pair_conditions="bilateral leg parameters and hip offsets coincide by native schema; equal mode/alpha/rate has identical flow, guard, and reset under bilateral permutation";
% Symmetric-gait route is retained outside the asymmetric contract.
halfContact=localShiftedPair(data,T,.5,[1 2;3 4]);
halfMotion=localMotionShift(data,T,.5,[1 2;3 4],options.SampleCount);
paceContact=localShiftedPair(data,T,0,[1 3;2 4]);
paceMotion=localMotionShift(data,T,0,[1 3;2 4],options.SampleCount);
trotContact=localShiftedPair(data,T,0,[1 4;2 3]);
trotMotion=localMotionShift(data,T,0,[1 4;2 3],options.SampleCount);
pace=all(paceContact==0) && all(paceMotion.angle<=options.AngleTolerance) ...
    && all(paceMotion.rate<=options.RateTolerance);
trot=all(trotContact==0) && all(trotMotion.angle<=options.AngleTolerance) ...
    && all(trotMotion.rate<=options.RateTolerance);
fullHalf=all(halfContact==0) && all(halfMotion.angle<=options.AngleTolerance) ...
    && all(halfMotion.rate<=options.RateTolerance);
base="UNDETERMINED";label="unclassified";status="undetermined";reason="";
pipSubtype="not_applicable";
if ~primitiveKnown
    status="unvalidated_cycle";reason=primitive.reason;
elseif ~contactAudit.complete
    reason=contactAudit.reason;
elseif half.status=="UNDETERMINED"
    reason="half-period physical-event matching is unresolved";
elseif half.status=="MATCHED"
    if fullHalf
        if pace,base="PC";elseif trot,base="TR";else,base="TL";end
        label=base;status="symmetric_route";
        reason="matched half-period event multiset; existing symmetric leg-trajectory route retained";
    else
        status="excluded_event_pattern";
        reason="matched half-period event multiset is outside the asymmetric classifier; no stronger state symmetry established";
    end
elseif initial.ambiguous
    status="borderline";reason="initial leg-state comparison is near a declared angle/rate boundary";
elseif ~cycle.physical_chart.verified
    reason="dependent stance rates are not verified on the saved physical chart";
elseif ~cycle.required_sync_consistent
    status="inconsistent_initial_pattern";reason="initial synchronized leg pattern does not persist over the complete saved cycle";
elseif initial.type=="PK" && ~cycle.all_four_invariance.verified
    status="inconsistent_initial_pattern";reason="all-four initial equality fails compatible body/parameter or numerical flow conditions";
else
    base=initial.type;status="classified";reason="initial leg-state hierarchy validated over the complete saved primitive cycle";
    switch base
        case "B",label="BD";
        case "H",label="HB_hind";
        case "F",label="HB_front";
        case "G",label="GP";
        case "PK"
            vertical=max(abs(state(:,[s.State.dx,s.State.phi,s.State.dphi, ...
                s.Leg.AngleIndices,s.Leg.RateIndices])),[],'all');
            if abs(primitive.primitive_drift)<=options.MotionTolerance && vertical<=options.MotionTolerance
                base="PIP";label="PIP";pipSubtype="vertical_in_place";
            else
                label="PK";pipSubtype="synchronized_nonvertical";
            end
    end
end
geometry=localGeometry(data,T,resolvedIntervals,base,options);
posture=geometry.reference_posture;
compact="";
if ismember(base,["PK","PIP"]),compact=base;
elseif ismember(base,["B","H","F","G"]) && isfinite(flightCount)
    compact=base+posture+string(flightCount);
elseif ismember(base,["PC","TR","TL"]),compact=base;end
qualified=status=="classified" && countCertain && ismember(base,["B","H","F","G","PK","PIP"]);
if ismember(base,["B","H","F","G"])
    qualified=qualified && ismember(posture,["G","E"]) && geometry.canonical_apex_verified;
end
borderline=initial.ambiguous || ~countCertain || half.status=="UNDETERMINED";
if status=="classified" && ~countCertain,status="borderline";reason="physical flight count changes near event/duration resolution or is incomplete";end
[mapping,contractVersion]=GaitSemanticTable_v3();row=find(mapping.label==label,1);
[td,lo,eventReport]=localEvents(events);lead=nan(2,1);
for pair=1:2
    i=2*pair-1;j=i+1;
    if numel(td{i})==1 && numel(td{j})==1,lead(pair)=CircularPhase_v3.difference(td{j},td{i});end
end
durations=diff(contactAudit.knots);duty=sum(double(contactAudit.modes).*durations,1)/T;
[displayState,displayMode]=HybridCycleData_v3.sample(data,t0+phase*T);
contactError=localContactErrors(contactAudit.modes,durations,T);
result=struct('contract_version',contractVersion, ...
    'synchrony_predicate_version','componentwise-decisive-unequal-v1-20261022', ...
    'label',label,'alias',mapping.alias(row),'abbreviation',compact,'color',mapping.color(row,:), ...
    'status',status,'reason',reason,'validated_gait_type',base, ...
    'initial_state_pattern',initial,'cycle_synchronization',cycle,'pip_subtype',pipSubtype, ...
    'event_half_shift_exclusion',half,'canonical_point_label',compact, ...
    'canonical_label_qualified',qualified,'suspension_reference_posture',posture, ...
    'all_per_flight_postures',geometry.postures,'primitive_flight_count',flightCount, ...
    'flight_count_certain',countCertain,'historical_labels',localHistorical(source), ...
    'ambiguity',struct('initial_comparison',initial.ambiguous, ...
        'event_half_shift',half.status=="UNDETERMINED",'flight_count',~countCertain, ...
        'posture',posture=="U",'inconsistency',~cycle.required_sync_consistent), ...
    'descriptive_only',true,'isotropy_proved',false,'primitive',primitive, ...
    'period_used',T,'flight_count',flightCount,'raw_positive_flight_count',sum(flightDurations>0), ...
    'flight_count_over_recorded_period',localRecordedFlights(data,options), ...
    'flight_intervals_on_circle',intervals,'flight_durations',flightDurations, ...
    'flight_count_sensitivity',struct('duration_thresholds',levels,'counts',counts, ...
        'event_time_thresholds',absoluteEventTolerance*[.1 1 10],'event_resolution_counts',resolutionCounts), ...
    'contact_reconstruction',rmfield(contactAudit,{'events'}), ...
    'duty_factors',duty,'contact_time',t0+phase*T,'contact_functions',displayMode, ...
    'touchdown_phases',{td},'liftoff_phases',{lo},'event_occurrences',eventReport, ...
    'event_clusters',localClusters(data,T),'contact_sync_errors',contactError, ...
    'motion_sync_errors',max(cycle.angle_errors,cycle.rate_errors), ...
    'angle_sync_errors',cycle.angle_errors,'rate_sync_errors',cycle.rate_errors, ...
    'hind_pair_asymmetry',cycle.hind_pair_asymmetry,'fore_pair_asymmetry',cycle.fore_pair_asymmetry, ...
    'hind_pair_synchronized',cycle.hind_pair_synchronized, ...
    'front_pair_synchronized',cycle.fore_pair_synchronized, ...
    'fore_pair_synchronized',cycle.fore_pair_synchronized, ...
    'left_right_half_phase_contact_errors',halfContact, ...
    'left_right_half_phase_motion_errors',max(halfMotion.angle,halfMotion.rate), ...
    'left_right_lead',lead,'lead_pair_names',{{'hind','front'}}, ...
    'leg_trajectories',struct('phase',phase,'angle',displayState(:,s.Leg.AngleIndices), ...
        'rate',displayState(:,s.Leg.RateIndices)), ...
    'suspension_geometry',geometry,'tolerances',options,'borderline',borderline, ...
    'schema_metadata',s.metadata(),'legacy_original_suffix_verified_flight_count',false, ...
    'v3_abbreviation_suffix2_measured',true);
end

function report=localSynchrony(state,mode,s,o)
a=state(:,s.Leg.AngleIndices);r=state(:,s.Leg.RateIndices);
angle=zeros(4);rate=zeros(4);modeEqual=true(4);pair=strings(4);
for i=1:4
    for j=i:4
        angle(i,j)=max(abs(a(:,i)-a(:,j)));rate(i,j)=max(abs(r(:,i)-r(:,j)));
        modeEqual(i,j)=all(mode(:,i)==mode(:,j));
        if ~modeEqual(i,j),value="UNEQUAL";
        elseif angle(i,j)>2*o.AngleTolerance || rate(i,j)>2*o.RateTolerance,value="UNEQUAL";
        elseif localBorderline(angle(i,j),o.AngleTolerance) || localBorderline(rate(i,j),o.RateTolerance)
            value="BOUNDARY";
        elseif angle(i,j)<=o.AngleTolerance && rate(i,j)<=o.RateTolerance,value="EQUAL";
        else,value="UNEQUAL";end
        angle(j,i)=angle(i,j);rate(j,i)=rate(i,j);modeEqual(j,i)=modeEqual(i,j);
        pair(i,j)=value;pair(j,i)=value;
    end
end
report=struct('angle_errors',angle,'rate_errors',rate,'mode_equal',modeEqual, ...
    'pair_status',pair,'hind_pair_synchronized',pair(1,2)=="EQUAL", ...
    'fore_pair_synchronized',pair(3,4)=="EQUAL",'all_four_synchronized',all(pair=="EQUAL",'all'), ...
    'all_four_max_angle_spread',max(angle,[],'all'),'all_four_max_rate_spread',max(rate,[],'all'), ...
    'hind_pair_asymmetry',angle(1,2),'fore_pair_asymmetry',angle(3,4), ...
    'hind_pair_rate_asymmetry',rate(1,2),'fore_pair_rate_asymmetry',rate(3,4), ...
    'hind_pair_mode_mismatch',~modeEqual(1,2),'fore_pair_mode_mismatch',~modeEqual(3,4), ...
    'ambiguous',pair(1,2)=="BOUNDARY" || pair(3,4)=="BOUNDARY" || ...
        (pair(1,2)=="EQUAL" && pair(3,4)=="EQUAL" && any(pair=="BOUNDARY",'all')));
end
function type=localType(r)
if r.ambiguous,type="UNDETERMINED";
elseif r.all_four_synchronized,type="PK";
elseif r.hind_pair_synchronized && r.fore_pair_synchronized,type="B";
elseif r.fore_pair_synchronized,type="H";
elseif r.hind_pair_synchronized,type="F";
else,type="G";end
end
function tf=localRequiredSync(type,r)
switch type
    case "PK",tf=r.all_four_synchronized;
    case "B",tf=r.hind_pair_synchronized && r.fore_pair_synchronized;
    case "H",tf=r.fore_pair_synchronized;
    case "F",tf=r.hind_pair_synchronized;
    case "G",tf=true;
    otherwise,tf=false;
end
end
function report=localPhysicalChartAudit(data,T,events,o)
report=struct('verified',false,'maximum_stance_rate_residual',NaN, ...
    'saved_and_event_state_count',0,'source_modified',false,'failure',"");
if isempty(data.parameter),report.failure="parameters missing";return;end
selected=data.time>=data.start_time & data.time<=data.start_time+T;
x=data.state(selected,:);q=data.mode(selected,:);
for k=1:numel(events)
    e=data.history(events(k).history_index);
    for side=["before","after"]
        state=e.("state_"+side);mode=e.("mode_"+side);
        if numel(state)==14 && numel(mode)==4,x(end+1,:)=state(:).';q(end+1,:)=mode(:).';end %#ok<AGROW>
    end
end
worst=0;
try
    for k=1:size(x,1)
        check=QuadrupedPhysicalChart_v3.report(x(k,:),q(k,:),data.parameter);
        worst=max(worst,check.maximum_constraint_residual);
    end
    report.maximum_stance_rate_residual=worst;report.verified=worst<=o.StanceRateTolerance;
catch err,report.failure=string(err.identifier)+": "+string(err.message);end
report.saved_and_event_state_count=size(x,1);
end
function report=localAllFourInvariance(data,T,x,q,cycle,o) %#ok<INUSD>
s=data.schema;
report=struct('verified',false,'sufficient_analytic_conditions',false, ...
    'body_pitch_compatible',false,'fore_hind_parameters_equal',false, ...
    'centered_com',false,'maximum_flow_pair_error',NaN,'flow_check_failure',"", ...
    'claim',"numerical consistency, not a general isotropy proof");
if isempty(data.parameter) || ~cycle.all_four_synchronized,return;end
p=data.parameter(:);idx=s.Parameter;
report.body_pitch_compatible=max(abs(x(:,[s.State.phi,s.State.dphi])),[],'all')<=o.MotionTolerance;
report.fore_hind_parameters_equal=max(abs(p([idx.k_l_b idx.k_s_b idx.l_l_b idx.rsla_b])- ...
    p([idx.k_l_f idx.k_s_f idx.l_l_f idx.rsla_f])))<=o.ParameterTolerance;
report.centered_com=abs(p(idx.l_com)-.5)<=o.ParameterTolerance;
report.sufficient_analytic_conditions=report.body_pitch_compatible && ...
    report.fore_hind_parameters_equal && report.centered_com;
if report.sufficient_analytic_conditions,report.verified=true;return;end
% Without the sufficient subspace assumptions, check native flow tangency
% at every audited cycle sample and retain incompatible-body flags.
worst=0;dynamics=ContinuousDynamics_v3(s);
try
    for k=1:size(x,1)
        f=dynamics.evaluate(0,x(k,:),q(k,:),p);
        fa=f(s.Leg.AngleIndices);fr=f(s.Leg.RateIndices);
        worst=max([worst;max(fa)-min(fa);max(fr)-min(fr)]);
    end
    report.maximum_flow_pair_error=worst;
    report.verified=worst<=o.SyncFlowTolerance;
catch err,report.flow_check_failure=string(err.identifier)+": "+string(err.message);end
end
function half=localHalfShift(events,T,tolerance,complete)
checks=cell(3,1);matched=false(3,1);
for k=1:3
    checks{k}=HybridCycleData_v3.eventPermutationMatch(events,T,[2 1 4 3],.5,tolerance*2^(k-2));
    matched(k)=checks{k}.matched;
end
half=checks{2};half.status="UNDETERMINED";
if complete && ~isempty(events) && all(matched==matched(2))
    if matched(2),half.status="MATCHED";else,half.status="NOT_MATCHED";end
end
half.tolerance_sensitivity=struct('time_tolerances',tolerance*[.5 1 2],'matched',matched);
half.excluded_from_asymmetric_classifier=half.status=="MATCHED";
half.full_state_symmetry_proved=false;
end
function intervals=localIntervals(knots,active,T)
intervals=zeros(0,2);
for k=1:numel(active)
    if ~active(k) || knots(k+1)<=knots(k),continue;end
    if ~isempty(intervals) && intervals(end,2)==knots(k),intervals(end,2)=knots(k+1);
    else,intervals(end+1,:)=[knots(k),knots(k+1)];end %#ok<AGROW>
end
if size(intervals,1)>1 && intervals(1,1)==0 && intervals(end,2)==T
    intervals=[intervals(2:end-1,:);intervals(end,1),intervals(1,2)+T];
end
end
function n=localRecordedFlights(data,o)
a=HybridCycleData_v3.reconstructContact(data,data.period,max(data.time_tolerance,o.EventTimeTolerance*data.period));
i=localIntervals(a.knots,~any(a.modes,2),data.period);
n=sum(diff(i,1,2)>o.FlightDurationTolerance*data.period);
if ~a.complete,n=NaN;end
end
function report=localGeometry(data,T,intervals,base,o)
s=data.schema;
prototype=struct('flight_index',0,'interval',[],'duration',NaN,'phase_identity',"", ...
    'observation_cycle_time',NaN,'observation_phase',NaN,'maximum_kind',"unresolved", ...
    'alpha',nan(1,4),'torso_projection',nan(1,4),'posture',"U", ...
    'principal_chart_valid',false,'gravity',NaN,'observation_mode',false(1,4), ...
    'observation_evaluation',struct());
flights=repmat(prototype,size(intervals,1),1);
report=struct('status',"unresolved",'description',"unresolved",'reference_posture',"U", ...
    'postures',strings(0,1),'flights',flights,'reference_flight_index',NaN, ...
    'reference_choice',"none",'canonical_apex_verified',false, ...
    'chart',"raw body-relative -pi < alpha < pi; no wrapping", ...
    'observation_rule',"maximum COM height on each closed flight interval using flight-side limit", ...
    'geometry_identity',"dot(foot-minus-hip, torso-forward-axis) = leg_length*sin(alpha)", ...
    'front_hind_foot_spread_relative_to_hips',[]);
[x0,q0]=HybridCycleData_v3.sample(data,data.start_time);
try
    if ~isempty(data.parameter)
        f=ContinuousDynamics_v3(s);flow=f.evaluate(0,x0,q0,data.parameter);
        report.canonical_apex_verified=abs(x0(s.State.dy))<=o.ApexTolerance && flow(s.State.dy)<-o.ApexTolerance;
    end
catch,end
if ismember(base,["PK","PIP"])
    report.status="not_applicable";report.description="not_applicable";report.reference_posture="NA";
    report.postures=repmat("NA",size(intervals,1),1);return
end
if isempty(intervals) || isempty(data.parameter),return;end
expanded=s.expandParameters(data.parameter);
for k=1:size(intervals,1)
    a=intervals(k,1);D=diff(intervals(k,:));
    [start,~]=localCircleSample(data,T,a,'right');
    dynamics=ContinuousDynamics_v3(s);flow=dynamics.evaluate(0,start,false(1,4),data.parameter);
    gravity=-flow(s.State.dy);dt=min(D,max(0,start(s.State.dy)/gravity));
    time=a+dt;kind="boundary_maximum";side='right';
    if dt>0 && dt<D,kind="interior_apex";
    elseif dt==D,side='left';end
    [state,mode,evaluation]=localNativeFlightSample(data,T,time,side,o);
    alpha=state(s.Leg.AngleIndices);uncertainty=evaluation.angle_uncertainty;
    chart=evaluation.resolved && all(alpha-uncertainty>-pi & alpha+uncertainty<pi);
    posture="U";
    if chart && all(abs(alpha)>o.GeometryTolerance+uncertainty)
        if all(alpha(1:2)>o.GeometryTolerance+uncertainty(1:2)) && ...
                all(alpha(3:4)<-o.GeometryTolerance-uncertainty(3:4)),posture="G";
        elseif all(alpha(1:2)<-o.GeometryTolerance-uncertainty(1:2)) && ...
                all(alpha(3:4)>o.GeometryTolerance+uncertainty(3:4)),posture="E";
        else,posture="M";end
    end
    flights(k)=struct('flight_index',k,'interval',intervals(k,:),'duration',D, ...
        'phase_identity',"flight_"+string(k), 'observation_cycle_time',time, ...
        'observation_phase',mod(time/T,1),'maximum_kind',kind,'alpha',alpha, ...
        'torso_projection',expanded.l_0.'.*sin(alpha),'posture',posture, ...
        'principal_chart_valid',chart,'gravity',gravity,'observation_mode',mode, ...
        'observation_evaluation',evaluation);
end
if ~any(q0)
    reference=find(intervals(:,1)==0 | intervals(:,2)>T,1);
    report.reference_choice="flight_containing_canonical_marked_apex";
else
    [~,reference]=min(intervals(:,1));report.reference_choice="first_subsequent_flight_after_grounded_section";
end
if isempty(reference),reference=1;report.reference_choice="unresolved_reference_fallback";end
report.flights=flights;report.postures=reshape(string({flights.posture}),[],1);
report.reference_flight_index=reference;report.reference_posture=flights(reference).posture;
report.status="individual_body_relative_signs";
switch report.reference_posture
    case "G",report.description="gathered";
    case "E",report.description="extended";
    case "M",report.description="mixed_individual_signs";
    otherwise,report.description="unresolved";
end
end
function [x,q]=localCircleSample(data,T,relative,side)
phase=mod(relative,T);
if abs(phase)<=data.time_tolerance && strcmp(side,'left') && relative>0,phase=T;end
[x,q]=HybridCycleData_v3.sample(data,data.start_time+phase,side);
end
function [state,mode,report]=localNativeFlightSample(data,T,relative,side,o)
% Saved exact limits retain their original values. Between saved samples,
% use the native all-swing flow and compare forward/backward reconstructions
% plus step halving; do not certify signs from unqualified interpolation.
phase=mod(relative,T);
if abs(phase)<=data.time_tolerance && strcmp(side,'left') && relative>0,phase=T;end
query=data.start_time+phase;
[state,mode]=HybridCycleData_v3.sample(data,query,side);
report=struct('method',"saved exact flight-side state",'resolved',true, ...
    'source_bracket',[query query],'angle_uncertainty',zeros(1,4), ...
    'forward_backward_angle_difference',zeros(1,4),'step_halving_angle_difference',zeros(1,4), ...
    'RelTol',o.ObservationRelTol,'AbsTol',o.ObservationAbsTol, ...
    'MaxStep',NaN,'safety_factor',o.ObservationSafetyFactor,'failure',"");
if any(abs(data.time-query)<=data.time_tolerance),return;end
left=max(data.time(data.time<query));right=min(data.time(data.time>query));
[xa,qa]=HybridCycleData_v3.sample(data,left,'right');
[xb,qb]=HybridCycleData_v3.sample(data,right,'left');
report.method="native all-swing flow with bidirectional and step-halving check";
report.source_bracket=[left right];
if any(qa) || any(qb)
    report.resolved=false;report.angle_uncertainty(:)=Inf;
    report.failure="observation bracket does not stay in one flight-side smooth span";return
end
try
    dynamics=ContinuousDynamics_v3(data.schema);
    h=min(o.ObservationMaxStep,(right-left)/4);report.MaxStep=h/2;
    coarse=odeset('RelTol',o.ObservationRelTol,'AbsTol',o.ObservationAbsTol,'MaxStep',h);
    fine=odeset(coarse,'MaxStep',h/2,'RelTol',o.ObservationRelTol/10,'AbsTol',o.ObservationAbsTol/10);
    flow=@(t,x)dynamics.evaluate(t,x,false(4,1),data.parameter);
    [~,forwardCoarse]=ode45(flow,[left query],xa(:),coarse);
    [~,forwardFine]=ode45(flow,[left query],xa(:),fine);
    [~,backwardFine]=ode45(flow,[right query],xb(:),fine);
    state=forwardFine(end,:);mode=false(1,4);angles=data.schema.Leg.AngleIndices;
    pairDifference=abs(state(angles)-backwardFine(end,angles));
    halvingDifference=abs(state(angles)-forwardCoarse(end,angles));
    roundoff=256*eps(max(1,abs(state(angles))));
    report.angle_uncertainty=o.ObservationSafetyFactor*max([pairDifference;halvingDifference;roundoff],[],1);
    report.forward_backward_angle_difference=pairDifference;
    report.step_halving_angle_difference=halvingDifference;
    report.resolved=all(isfinite(report.angle_uncertainty));
catch err
    report.resolved=false;report.angle_uncertainty(:)=Inf;
    report.failure=string(err.identifier)+": "+string(err.message);
end
end
function errors=localContactErrors(modes,durations,T)
errors=zeros(4);
for i=1:4
    for j=i+1:4,errors(i,j)=sum(durations(modes(:,i)~=modes(:,j)))/T;errors(j,i)=errors(i,j);end
end
end
function errors=localShiftedPair(data,T,shift,pairs)
t0=data.start_time;breaks=mod((data.time-t0)/T,1);
breaks=unique([0;1;breaks;mod(breaks-shift,1)]);phase=(breaks(1:end-1)+breaks(2:end))/2;
[~,qa]=HybridCycleData_v3.sample(data,t0+phase*T);
[~,qb]=HybridCycleData_v3.sample(data,t0+mod(phase+shift,1)*T);errors=zeros(size(pairs,1),1);
for k=1:size(pairs,1),errors(k)=sum(diff(breaks).*(qa(:,pairs(k,1))~=qb(:,pairs(k,2))));end
end
function errors=localMotionShift(data,T,shift,pairs,n)
phase=(0:n-1).'/n;t0=data.start_time;s=data.schema;
[xa,~]=HybridCycleData_v3.sample(data,t0+phase*T);
[xb,~]=HybridCycleData_v3.sample(data,t0+mod(phase+shift,1)*T);
errors=struct('angle',zeros(size(pairs,1),1),'rate',zeros(size(pairs,1),1));
for k=1:size(pairs,1)
    i=pairs(k,1);j=pairs(k,2);
    errors.angle(k)=max(abs(xa(:,s.Leg.AngleIndices(i))-xb(:,s.Leg.AngleIndices(j))));
    errors.rate(k)=max(abs(xa(:,s.Leg.RateIndices(i))-xb(:,s.Leg.RateIndices(j))));
end
end
function [td,lo,report]=localEvents(events)
td=cell(4,1);lo=cell(4,1);report=events;count=zeros(4,2);
for k=1:numel(events)
    leg=events(k).leg_index;
    if events(k).kind=="touchdown",j=1;td{leg}(end+1,1)=events(k).phase;
    else,j=2;lo{leg}(end+1,1)=events(k).phase;end
    count(leg,j)=count(leg,j)+1;report(k).occurrence=count(leg,j);
end
end
function clusters=localClusters(data,T)
events=HybridCycleData_v3.physicalEvents(data,T,data.time_tolerance);
if isempty(events),clusters=struct([]);return;end
history=data.history([events.history_index]);clusterer=EventCluster_v3();
report=clusterer.analyze(history,struct('InitialTime',data.start_time,'Period',T));clusters=report.clusters;
end
function historical=localHistorical(source)
historical=struct('label',"",'abbreviation',"",'contract_version',"");
if isa(source,'Trajectory_v3'),return;end
if (isstruct(source) && isfield(source,'gait_identification')) || ...
        (isobject(source) && isprop(source,'gait_identification'))
    previous=source.gait_identification;
    if isstruct(previous)
        for name=fieldnames(historical).'
            if isfield(previous,name{1}),historical.(name{1})=string(previous.(name{1}));end
        end
    end
end
end
function tf=localBorderline(error,tolerance)
tf=error>=.5*tolerance && error<=2*tolerance;
end
function o=localOptions(input)
o=struct('ContactTolerance',1e-7,'MotionTolerance',1e-5, ...
    'AngleTolerance',1e-5,'RateTolerance',1e-5,'StanceRateTolerance',1e-8, ...
    'SyncFlowTolerance',1e-5,'ParameterTolerance',1e-10,'ApexTolerance',1e-8, ...
    'EventTimeTolerance',1e-7,'FlightDurationTolerance',1e-8, ...
    'ObservationRelTol',1e-11,'ObservationAbsTol',1e-13, ...
    'ObservationMaxStep',.001,'ObservationSafetyFactor',10, ...
    'GeometryTolerance',1e-5,'SampleCount',257,'PrimitiveOptions',struct());
for name=fieldnames(input).'
    if ~isfield(o,name{1}),error('GaitIdentification_v3:UnknownOption','Unknown option %s.',name{1});end
    o.(name{1})=input.(name{1});
end
% Preserve the old single motion tolerance as an explicit compatibility
% alias only when separate angle/rate tolerances were not supplied.
if isfield(input,'MotionTolerance')
    if ~isfield(input,'AngleTolerance'),o.AngleTolerance=input.MotionTolerance;end
    if ~isfield(input,'RateTolerance'),o.RateTolerance=input.MotionTolerance;end
end
names=setdiff(fieldnames(o),{'SampleCount','PrimitiveOptions'});
for k=1:numel(names),validateattributes(o.(names{k}),{'numeric'},{'scalar','finite','positive'});end
validateattributes(o.SampleCount,{'numeric'},{'scalar','integer','>=',3});
end
