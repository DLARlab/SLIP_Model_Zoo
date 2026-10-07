function result = GaitIdentification_v3(source, options)
%GAITIDENTIFICATION_V3 Descriptive classification from complete hybrid data.
% Accepts a Trajectory_v3 or HybridOrbit_v3/struct containing one. Diagnostics
% do not prescribe guards, event order, solver restrictions, or isotropy.
% Physical flight count is measured on the time circle, separate from any
% legacy label suffix. Numerical primitive-period checks precede counting.
if nargin<2, options=struct(); end
options=localOptions(options,struct('ContactTolerance',1e-7, ...
    'MotionTolerance',1e-5,'FlightDurationTolerance',1e-8, ...
    'GeometryTolerance',1e-5,'SampleCount',257,'PrimitiveOptions',struct()));
data=HybridCycleData_v3.unpack(source); schema=data.schema;
primitive=PrimitiveCycleCheck_v3(source,options.PrimitiveOptions);
T=primitive.primitive_period;
if ~isfinite(T), T=data.period; end
t0=data.start_time;
knots=unique([t0;t0+T;data.time(data.time>t0 & data.time<t0+T)]);
mid=(knots(1:end-1)+knots(2:end))/2;
[~,modes]=HybridCycleData_v3.sample(data,mid);
durations=diff(knots);
duty=sum(double(modes).*durations,1)/T;
intervals=localIntervals(knots-t0,~any(modes,2));
% Connected flight crossing the section boundary is a single circle arc.
if size(intervals,1)>1 && intervals(1,1)==0 && intervals(end,2)==T
    intervals=[intervals(2:end-1,:);intervals(end,1),intervals(1,2)+T];
end
flightDurations=diff(intervals,1,2);
threshold=options.FlightDurationTolerance*T;
levels=threshold*[.1 1 10];
counts=arrayfun(@(tol)sum(flightDurations>tol),levels);
rawCount=sum(flightDurations>0);
physicalCount=counts(2);
if ~isfinite(primitive.primitive_period), physicalCount=NaN; end
phase=linspace(0,1,options.SampleCount+1).'; phase(end)=[];
[state,contact]=HybridCycleData_v3.sample(data,t0+phase*T);
angle=state(:,schema.Leg.AngleIndices); rate=state(:,schema.Leg.RateIndices);
contactError=zeros(4); motionError=zeros(4);
for i=1:4
    for j=i+1:4
        contactError(i,j)=sum(durations(modes(:,i)~=modes(:,j)))/T;
        delta=atan2(sin(angle(:,i)-angle(:,j)),cos(angle(:,i)-angle(:,j)));
        motionError(i,j)=max([abs(delta);abs(rate(:,i)-rate(:,j))]);
        contactError(j,i)=contactError(i,j); motionError(j,i)=motionError(i,j);
    end
end
sync=contactError<=options.ContactTolerance & motionError<=options.MotionTolerance;
hind=sync(1,2); front=sync(3,4); allSync=all(sync,'all');
halfContact=localShiftedPair(data,T,.5,[1 2;3 4]);
halfMotion=localMotionShift(data,T,.5,[1 2;3 4],options.SampleCount);
halfSync=all(halfContact<=options.ContactTolerance) && all(halfMotion<=options.MotionTolerance);
paceContact=localShiftedPair(data,T,0,[1 3;2 4]);
paceMotion=localMotionShift(data,T,0,[1 3;2 4],options.SampleCount);
trotContact=localShiftedPair(data,T,0,[1 4;2 3]);
trotMotion=localMotionShift(data,T,0,[1 4;2 3],options.SampleCount);
pace=all(paceContact<=options.ContactTolerance) && all(paceMotion<=options.MotionTolerance);
trot=all(trotContact<=options.ContactTolerance) && all(trotMotion<=options.MotionTolerance);
vertical=max(abs(state(:,[schema.State.dx,schema.State.phi,schema.State.dphi, ...
    schema.Leg.AngleIndices,schema.Leg.RateIndices])),[],'all');
label="unclassified"; status="classified"; reason="contact and leg-motion pattern";
if any(duty<=options.ContactTolerance | duty>=1-options.ContactTolerance)
    status="unclassified"; reason="a leg lacks a resolved stance or swing interval";
elseif allSync
    if abs(primitive.drift)<=options.MotionTolerance && vertical<=options.MotionTolerance
        label="PIP";
    elseif abs(primitive.drift)>options.MotionTolerance
        label="PK";
    else
        status="ambiguous";reason="zero-drift synchronized cycle fails the vertical PIP conditions";
    end
elseif halfSync
    if pace, label="PC"; elseif trot, label="TR"; else, label="TL"; end
elseif hind && front
    label="BD";
elseif hind
    label="HB_front";
elseif front
    label="HB_hind";
else
    label="GP";
end
% Contact equality with unequal leg motion does not establish a paired gait.
contactSync=contactError<=options.ContactTolerance;
if (contactSync(1,2) && ~hind) || (contactSync(3,4) && ~front) ...
        || (all(contactSync,'all') && ~allSync)
    label="unclassified"; status="ambiguous";
    reason="synchronized contacts conflict with leg-motion synchronization";
end
borderline=any(localBorderline(contactError(triu(true(4),1)),options.ContactTolerance)) ...
    || any(localBorderline(motionError(triu(true(4),1)),options.MotionTolerance)) ...
    || any(counts~=counts(2));
if borderline && status=="classified"
    status="borderline"; reason="classification changes near declared numerical tolerances";
end
if primitive.status=="unknown"
    status="unvalidated_cycle"; reason=primitive.reason;
end
[td,lo,eventReport]=localEvents(data,T);
lead=nan(2,1);
for pair=1:2
    i=2*pair-1;j=i+1;
    if numel(td{i})==1 && numel(td{j})==1
        lead(pair)=CircularPhase_v3.difference(td{j},td{i});
    end
end
mapping=GaitSemanticTable_v3(); row=find(mapping.label==label,1);
abbr=mapping.legacy_base_abbreviation(row);
if physicalCount==2 && ismember(label,["PK","BD","HB_front","HB_hind","GP"])
    abbr=abbr+"2";
end
geometry=localGeometry(data,T,intervals,options.GeometryTolerance);
result=struct('label',label,'alias',mapping.alias(row),'abbreviation',abbr, ...
    'color',mapping.color(row,:),'status',status,'reason',reason, ...
    'descriptive_only',true,'isotropy_proved',false,'primitive',primitive, ...
    'period_used',T,'flight_count',physicalCount,'raw_positive_flight_count',rawCount, ...
    'flight_count_over_recorded_period',localRecordedFlights(data,options.FlightDurationTolerance), ...
    'flight_intervals_on_circle',intervals,'flight_durations',flightDurations, ...
    'flight_count_sensitivity',struct('duration_thresholds',levels,'counts',counts), ...
    'duty_factors',duty,'contact_time',t0+phase*T,'contact_functions',contact, ...
    'touchdown_phases',{td},'liftoff_phases',{lo},'event_occurrences',eventReport, ...
    'event_clusters',localClusters(data,T),'contact_sync_errors',contactError, ...
    'motion_sync_errors',motionError,'hind_pair_synchronized',hind, ...
    'front_pair_synchronized',front,'left_right_half_phase_contact_errors',halfContact, ...
    'left_right_half_phase_motion_errors',halfMotion,'left_right_lead',lead, ...
    'lead_pair_names',{{'hind','front'}}, ...
    'leg_trajectories',struct('phase',phase,'angle',angle,'rate',rate), ...
    'suspension_geometry',geometry,'tolerances',options,'borderline',borderline, ...
    'schema_metadata',schema.metadata(),'legacy_original_suffix_verified_flight_count',false, ...
    'v3_abbreviation_suffix2_measured',true);
end
function intervals=localIntervals(knots,active)
intervals=zeros(0,2);
for k=1:numel(active)
    if ~active(k) || knots(k+1)<=knots(k),continue;end
    if ~isempty(intervals) && intervals(end,2)==knots(k)
        intervals(end,2)=knots(k+1);
    else
        intervals(end+1,:)=[knots(k),knots(k+1)]; %#ok<AGROW>
    end
end
end
function count=localRecordedFlights(data,tolerance)
T=data.period;t0=data.start_time;
knots=unique([t0;t0+T;data.time(data.time>t0 & data.time<t0+T)]);
[~,q]=HybridCycleData_v3.sample(data,(knots(1:end-1)+knots(2:end))/2);
intervals=localIntervals(knots-t0,~any(q,2));
if size(intervals,1)>1 && intervals(1,1)==0 && intervals(end,2)==T
    intervals=[intervals(2:end-1,:);intervals(end,1),intervals(1,2)+T];
end
count=sum(diff(intervals,1,2)>tolerance*T);
end
function errors=localShiftedPair(data,T,shift,pairs)
t0=data.start_time;
breaks=mod((data.time-t0)/T,1);breaks=unique([0;1;breaks;mod(breaks-shift,1)]);
phase=(breaks(1:end-1)+breaks(2:end))/2;
[~,qa]=HybridCycleData_v3.sample(data,t0+phase*T);
[~,qb]=HybridCycleData_v3.sample(data,t0+mod(phase+shift,1)*T);
errors=zeros(size(pairs,1),1);
for k=1:size(pairs,1)
    errors(k)=sum(diff(breaks).*(qa(:,pairs(k,1))~=qb(:,pairs(k,2))));
end
end
function errors=localMotionShift(data,T,shift,pairs,n)
phase=(0:n-1).'/n;t0=data.start_time;s=data.schema;
[xa,~]=HybridCycleData_v3.sample(data,t0+phase*T);
[xb,~]=HybridCycleData_v3.sample(data,t0+mod(phase+shift,1)*T);
errors=zeros(size(pairs,1),1);
for k=1:size(pairs,1)
    i=pairs(k,1);j=pairs(k,2);
    delta=xa(:,s.Leg.AngleIndices(i))-xb(:,s.Leg.AngleIndices(j));
    errors(k)=max([abs(atan2(sin(delta),cos(delta))); ...
        abs(xa(:,s.Leg.RateIndices(i))-xb(:,s.Leg.RateIndices(j)))]);
end
end
function [td,lo,report]=localEvents(data,T)
td=cell(4,1);lo=cell(4,1);
report=repmat(struct('leg_index',0,'kind',"",'time',NaN,'phase',NaN, ...
    'occurrence',0,'source_index',0),0,1);
counts=zeros(4,2);t0=data.start_time;
for k=1:numel(data.history)
    e=data.history(k);
    if e.time<=t0+data.time_tolerance || e.time>t0+T+data.time_tolerance,continue;end
    [leg,kind]=HybridCycleData_v3.eventIdentity(e,data.schema);
    if isempty(leg),continue;end
    phase=mod((e.time-t0)/T,1);
    if kind=="touchdown",j=1;td{leg}(end+1,1)=phase;else,j=2;lo{leg}(end+1,1)=phase;end
    counts(leg,j)=counts(leg,j)+1;
    report(end+1,1)=struct('leg_index',leg,'kind',kind,'time',e.time, ...
        'phase',phase,'occurrence',counts(leg,j),'source_index',e.index); %#ok<AGROW>
end
end
function clusters=localClusters(data,T)
history=data.history;
if isempty(history),clusters=struct([]);return;end
history=history([history.time]>data.start_time+data.time_tolerance & ...
    [history.time]<=data.start_time+T+data.time_tolerance);
clusterer=EventCluster_v3();
report=clusterer.analyze(history,struct('InitialTime',data.start_time,'Period',T));
clusters=report.clusters;
end
function geometry=localGeometry(data,T,intervals,tolerance)
geometry=struct('status',"unresolved",'description',"",'front_hind_foot_spread_relative_to_hips',[]);
if isempty(data.parameter) || isempty(intervals),return;end
s=data.schema; expanded=s.expandParameters(data.parameter);values=[];
for k=1:size(intervals,1)
    phase=mod(intervals(k,1)+[.25 .5 .75]*diff(intervals(k,:)),T);
    [x,~]=HybridCycleData_v3.sample(data,data.start_time+phase);
    hip=cos(x(:,s.State.phi))*expanded.s.';
    foot=hip+sin(x(:,s.State.phi)+x(:,s.Leg.AngleIndices)).*expanded.l_0.';
    values=[values;(mean(foot(:,3:4),2)-mean(foot(:,1:2),2))- ...
        (mean(hip(:,3:4),2)-mean(hip(:,1:2),2))]; %#ok<AGROW>
end
geometry.front_hind_foot_spread_relative_to_hips=values;
geometry.status="sampled_geometry";
if all(values<-tolerance),geometry.description="gathered";
elseif all(values>tolerance),geometry.description="extended";
else,geometry.description="mixed_or_borderline";end
end
function tf=localBorderline(value,tolerance)
tf=value>=.5*tolerance & value<=2*tolerance;
end
function result=localOptions(options,defaults)
result=defaults;
for name=fieldnames(options).'
    if ~isfield(defaults,name{1}),error('GaitIdentification_v3:UnknownOption','Unknown option %s.',name{1});end
    result.(name{1})=options.(name{1});
end
names={'ContactTolerance','MotionTolerance','FlightDurationTolerance','GeometryTolerance'};
for k=1:numel(names),validateattributes(result.(names{k}),{'numeric'},{'scalar','finite','positive'});end
validateattributes(result.SampleCount,{'numeric'},{'scalar','integer','>=',3});
end
