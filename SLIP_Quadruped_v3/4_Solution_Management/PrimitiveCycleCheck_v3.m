function result = PrimitiveCycleCheck_v3(source, options)
%PRIMITIVECYCLECHECK_V3 Detect numerical multiple covers of full hybrid data.
% Tests complete translated state, discrete mode, and every event occurrence.
% No leg permutation is used. A finite sampling test is evidence within its
% stated integer-cover bound, and is never a proof of global primitivity.
if nargin<2, options=struct(); end
options=localOptions(options,struct('MaxCover',8,'SampleCount',257, ...
    'StateTolerance',1e-7,'EventPhaseTolerance',1e-7,'StateScale',ones(14,1)));
data=HybridCycleData_v3.unpack(source); schema=data.schema;
scale=options.StateScale(:).';
if numel(scale)~=schema.StateDimension || any(~isfinite(scale)) || any(scale<=0)
    error('PrimitiveCycleCheck_v3:InvalidScale','Supply fourteen positive state scales.');
end
validateattributes(options.MaxCover,{'numeric'},{'scalar','integer','>=',1});
validateattributes(options.SampleCount,{'numeric'},{'scalar','integer','>=',3});
validateattributes(options.StateTolerance,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(options.EventPhaseTolerance,{'numeric'},{'scalar','real','finite','positive'});
t0=data.start_time; period=data.period;
[x0,q0]=HybridCycleData_v3.sample(data,t0);
[xT,qT]=HybridCycleData_v3.sample(data,t0+period);
drift=xT(schema.TranslationIndex)-x0(schema.TranslationIndex);
closure=xT-x0; closure(schema.TranslationIndex)=0;
closureError=max(abs(closure)./scale);
result=struct('status',"unknown",'reason',"recorded trajectory is not closed", ...
    'recorded_period',period,'primitive_period',NaN,'cover_count',NaN, ...
    'drift',drift,'primitive_drift',NaN,'closure_error',closureError, ...
    'mode_closed',isequal(q0,qT),'checked_cover_bound',options.MaxCover, ...
    'state_tolerance',options.StateTolerance,'event_phase_tolerance',options.EventPhaseTolerance, ...
    'candidates',struct([]),'evidence_level',"sampled full hybrid trajectory", ...
    'global_primitivity_proved',false);
contactAudit=HybridCycleData_v3.reconstructContact(data,period,data.time_tolerance);
result.event_history_complete=contactAudit.complete;
result.contact_history_audit=rmfield(contactAudit,{'events','cohorts'});
if ~result.event_history_complete
    result.reason=contactAudit.reason;
    if strlength(result.reason)==0,result.reason="physical contact-event history is incomplete";end
    return
end
if closureError>options.StateTolerance || ~result.mode_closed, return; end
candidates=repmat(struct('cover',0,'period',NaN,'state_error',Inf, ...
    'mode_match',false,'event_match',false,'accepted',false, ...
    'initial_state_return_error',Inf,'witness_is_recorded_sample',false, ...
    'recorded_pair_state_error',Inf,'recorded_pair_mode_match',false,'recorded_pair_count',0, ...
    'event_state_evidence',struct(),'cover_candidate_requires_replay',false),options.MaxCover-1,1);
acceptedCover=1;
for cover=2:options.MaxCover
    tau=period/cover;
    sample=linspace(t0,t0+period-tau,options.SampleCount).';
    % Add both one-sided event states to the continuous samples.
    events=HybridCycleData_v3.physicalEvents(data,period,data.time_tolerance);
    eventTimes=data.start_time+[events.cycle_time].';
    eventTimes=eventTimes(eventTimes>=t0 & eventTimes<=t0+period-tau);
    sample=unique([sample;eventTimes]);
    worst=0; modeMatch=true;
    for side=["left","right"]
        [xa,qa]=HybridCycleData_v3.sample(data,sample,char(side));
        [xb,qb]=HybridCycleData_v3.sample(data,sample+tau,char(side));
        delta=xb-xa; delta(:,schema.TranslationIndex)= ...
            delta(:,schema.TranslationIndex)-drift/cover;
        worst=max(worst,max(abs(delta)./scale,[],'all'));
        modeMatch=modeMatch && isequal(qa,qb);
    end
    repeat=HybridCycleData_v3.eventPermutationMatch(events,period,1:4,1/cover, ...
        options.EventPhaseTolerance*period);
    eventMatch=repeat.matched;
    accepted=worst<=options.StateTolerance && modeMatch && eventMatch;
    [witness,witnessMode]=HybridCycleData_v3.sample(data,t0+tau);
    witnessDifference=witness-x0;
    witnessDifference(schema.TranslationIndex)= ...
        witnessDifference(schema.TranslationIndex)-drift/cover;
    witnessError=max(abs(witnessDifference)./scale);
    witnessRecorded=any(abs(data.time-(t0+tau))<=data.time_tolerance);
    % Unequal output meshes can make interpolated samples disagree on a
    % literal multiple cover. Exact event limits and exact saved-knot pairs
    % distinguish that uncertainty from a genuine state-level disagreement.
    [recordedError,recordedModes,recordedCount]=localRecordedPairs(data,tau,drift/cover,scale);
    eventStates=localEventStates(data,contactAudit,repeat,tau,drift,cover,scale);
    exactReturn=witnessRecorded && witnessError<=options.StateTolerance && isequal(q0,witnessMode);
    recordedDisagreement=recordedCount>0 && (recordedError>options.StateTolerance || ~recordedModes);
    eventDisagreement=eventStates.complete && ...
        (eventStates.state_error>options.StateTolerance || ~eventStates.mode_match);
    accepted=accepted && ~recordedDisagreement && ~eventDisagreement;
    interpolationUnresolved=~witnessRecorded && ~recordedDisagreement && ~eventDisagreement;
    uncertain=eventMatch && ~accepted && (exactReturn || interpolationUnresolved);
    candidates(cover-1)=struct('cover',cover,'period',tau,'state_error',worst, ...
        'mode_match',modeMatch,'event_match',eventMatch,'accepted',accepted, ...
        'initial_state_return_error',witnessError,'witness_is_recorded_sample',witnessRecorded, ...
        'recorded_pair_state_error',recordedError,'recorded_pair_mode_match',recordedModes, ...
        'recorded_pair_count',recordedCount,'event_state_evidence',eventStates, ...
        'cover_candidate_requires_replay',uncertain);
    if accepted, acceptedCover=cover; end
end
result.candidates=candidates;
if any([candidates.cover_candidate_requires_replay] & [candidates.cover]>acceptedCover)
    result.status="unknown";
    result.reason="sampled cycle evidence conflicts or leaves a repeating-event cover unresolved; independent replay required";
    return
end
result.cover_count=acceptedCover;
result.primitive_period=period/acceptedCover; result.primitive_drift=drift/acceptedCover;
if acceptedCover>1
    result.status="multiple_cover_detected";
    result.reason="complete state, contact modes and event occurrences repeat within tolerances";
else
    result.status="primitive_within_checked_bound";
    result.reason="no integer multiple cover detected within stated bound and sampling tolerance";
end
end
function [worst,modes,count]=localRecordedPairs(data,tau,expectedDrift,scale)
% Compare both external limits only where both shifted times are recorded.
[knots,first]=unique(data.time,'stable');[~,last]=unique(data.time,'last');
worst=0;modes=true;count=0;right=1;
for left=1:numel(knots)
    target=knots(left)+tau;
    if target>data.start_time+data.period+data.time_tolerance,break;end
    while right<numel(knots) && knots(right)<target-data.time_tolerance,right=right+1;end
    if abs(knots(right)-target)>data.time_tolerance,continue;end
    count=count+1;
    for indices={[first(left),first(right)],[last(left),last(right)]}
        rows=indices{1};delta=data.state(rows(2),:)-data.state(rows(1),:);
        delta(data.schema.TranslationIndex)=delta(data.schema.TranslationIndex)-expectedDrift;
        worst=max(worst,max(abs(delta)./scale));
        modes=modes && isequal(data.mode(rows(1),:),data.mode(rows(2),:));
    end
end
end
function report=localEventStates(data,audit,repeat,tau,drift,cover,scale)
% Match exact external cohort states; serial reset intermediates are not
% physical one-sided limits. No leg permutation is used for a shorter cycle.
report=struct('complete',false,'state_error',Inf,'mode_match',false,'cohort_count',0, ...
    'scope',"exact external physical-event cohort limits, without interpolation or leg permutation");
if ~repeat.matched,return;end
events=audit.events;cohorts=audit.cohorts;ids=zeros(numel(events),1);
for k=1:numel(cohorts),ids(cohorts{k})=k;end
worst=0;modes=true;
for k=1:numel(cohorts)
    members=cohorts{k};mapped=repeat.event_bijection(members);target=unique(ids(mapped));
    if numel(target)~=1 || numel(cohorts{target})~=numel(members),return;end
    peers=cohorts{target};
    wrap=round((mean([events(members).cycle_time])+tau-mean([events(peers).cycle_time]))/data.period);
    expected=drift/cover-wrap*drift;
    sourceRows=[events(members(1)).history_index,events(members(end)).history_index];
    targetRows=[events(peers(1)).history_index,events(peers(end)).history_index];
    for side=1:2
        stateName='state_before';modeName='mode_before';
        if side==2,stateName='state_after';modeName='mode_after';end
        a=data.history(sourceRows(side));b=data.history(targetRows(side));
        xa=a.(stateName);xb=b.(stateName);qa=a.(modeName);qb=b.(modeName);
        if numel(xa)~=data.schema.StateDimension || numel(xb)~=data.schema.StateDimension ...
                || any(~isfinite([xa(:);xb(:)])) || numel(qa)~=4 || numel(qb)~=4 ...
                || ~all(ismember([qa(:);qb(:)],[0 1])),return;end
        delta=xb(:).'-xa(:).';delta(data.schema.TranslationIndex)=delta(data.schema.TranslationIndex)-expected;
        worst=max(worst,max(abs(delta)./scale));modes=modes && isequal(logical(qa(:)),logical(qb(:)));
    end
end
report.complete=true;report.state_error=worst;report.mode_match=modes;report.cohort_count=numel(cohorts);
end
function result=localOptions(options,defaults)
result=defaults;
for name=fieldnames(options).'
    if ~isfield(defaults,name{1}), error('PrimitiveCycleCheck_v3:UnknownOption','Unknown option %s.',name{1}); end
    result.(name{1})=options.(name{1});
end
end
