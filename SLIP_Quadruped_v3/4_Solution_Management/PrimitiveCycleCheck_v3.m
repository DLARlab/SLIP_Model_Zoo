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
result.event_history_complete=localEventCompleteness(data);
if ~result.event_history_complete
    result.reason="contact-mode changes are missing from the physical event log";
    return
end
if closureError>options.StateTolerance || ~result.mode_closed, return; end
candidates=repmat(struct('cover',0,'period',NaN,'state_error',Inf, ...
    'mode_match',false,'event_match',false,'accepted',false, ...
    'initial_state_return_error',Inf,'witness_is_recorded_sample',false, ...
    'cover_candidate_requires_replay',false),options.MaxCover-1,1);
acceptedCover=1;
for cover=2:options.MaxCover
    tau=period/cover;
    sample=linspace(t0,t0+period-tau,options.SampleCount).';
    % Add both one-sided event states to the continuous samples.
    events=data.history;
    eventTimes=[events.time].';
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
    eventMatch=localEventRepeat(events,t0,period,cover,schema,options.EventPhaseTolerance);
    accepted=worst<=options.StateTolerance && modeMatch && eventMatch;
    [witness,witnessMode]=HybridCycleData_v3.sample(data,t0+tau);
    witnessDifference=witness-x0;
    witnessDifference(schema.TranslationIndex)= ...
        witnessDifference(schema.TranslationIndex)-drift/cover;
    witnessError=max(abs(witnessDifference)./scale);
    witnessRecorded=any(abs(data.time-(t0+tau))<=data.time_tolerance);
    uncertain=witnessRecorded && witnessError<=options.StateTolerance ...
        && isequal(q0,witnessMode) && eventMatch && ~accepted;
    candidates(cover-1)=struct('cover',cover,'period',tau,'state_error',worst, ...
        'mode_match',modeMatch,'event_match',eventMatch,'accepted',accepted, ...
        'initial_state_return_error',witnessError,'witness_is_recorded_sample',witnessRecorded, ...
        'cover_candidate_requires_replay',uncertain);
    if accepted, acceptedCover=cover; end
end
result.candidates=candidates;
if any([candidates.cover_candidate_requires_replay] & [candidates.cover]>acceptedCover)
    result.status="unknown";
    result.reason="an exact intermediate full-state return conflicts with sampled history; cover candidate requires independent replay";
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
function complete=localEventCompleteness(data)
complete=true;
for k=2:numel(data.time)
    changed=find(data.mode(k,:)~=data.mode(k-1,:));
    if isempty(changed) || data.time(k)<=data.start_time+data.time_tolerance,continue;end
    at=find(abs([data.history.time]-data.time(k))<=data.time_tolerance);
    for leg=changed
        expected="liftoff";
        if data.mode(k,leg),expected="touchdown";end
        found=false;
        for j=at
            [eventLeg,kind]=HybridCycleData_v3.eventIdentity(data.history(j),data.schema);
            found=found || (isequal(eventLeg,leg) && kind==expected);
        end
        if ~found,complete=false;return;end
    end
end
end
function match=localEventRepeat(history,t0,T,k,schema,tolerance)
% Use half-open periods, retaining simultaneous event multiplicity.
phase=mod(([history.time].'-t0)/T,1);
names=strings(numel(history),1);
keep=([history.time].'>t0+128*eps(max(1,abs(t0)))) & ([history.time].'<=t0+T+128*eps(max(1,abs(t0+T))));
phase=phase(keep); history=history(keep);
for j=1:numel(history)
    [leg,kind]=HybridCycleData_v3.eventIdentity(history(j),schema);
    if isempty(leg), match=false; return; end
    names(j)=string(leg)+"_"+kind;
end
names=names(1:numel(history));
match=true;
for j=1:numel(phase)
    target=mod(phase(j)+1/k,1);
    peers=names==names(j);
    if ~any(abs(CircularPhase_v3.difference(phase(peers),target))<=tolerance)
        match=false; return;
    end
end
% Presence alone is insufficient if copies have unequal multiplicities.
for name=unique(names).'
    counts=zeros(k,1);
    p=phase(names==name);
    for j=1:k
        counts(j)=sum(p>=(j-1)/k-tolerance & p<j/k-tolerance);
    end
    if any(counts~=counts(1)), match=false; return; end
end
end
function result=localOptions(options,defaults)
result=defaults;
for name=fieldnames(options).'
    if ~isfield(defaults,name{1}), error('PrimitiveCycleCheck_v3:UnknownOption','Unknown option %s.',name{1}); end
    result.(name{1})=options.(name{1});
end
end
