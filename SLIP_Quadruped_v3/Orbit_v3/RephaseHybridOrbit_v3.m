function [rephased, report] = RephaseHybridOrbit_v3(source, phaseTime)
%REPHASEHYBRIDORBIT_V3 Data overlap map preserving jumps and relative drift.
% This numerical interpolation is a rephasing predictor. Correction and
% independent replay are still required before using it as a solved orbit.
% No leg permutation is applied; symmetry transport must relabel then
% rephase the complete state, contacts and events onto the selected chart.
data=HybridCycleData_v3.unpack(source);
primitive=PrimitiveCycleCheck_v3(source);
if primitive.status=="unknown"
    error('RephaseHybridOrbit_v3:NotClosed','A closed relative cycle is required.');
end
validateattributes(phaseTime,{'numeric'},{'scalar','finite','real'});
T=data.period;t0=data.start_time;s=data.schema;
tau=mod(phaseTime,T);cut=t0+tau;drift=primitive.drift;
[initial,initialMode]=HybridCycleData_v3.sample(data,cut);
origin=initial(s.TranslationIndex);new=Trajectory_v3();
% Include both event sides at each source knot. At the cutting event use
% right ownership initially and finish with its pre and post states at T.
new.appendSample(0,localTranslate(initial,-origin,s),initialMode);
for part=1:2
    if part==1
        indices=find(data.time>cut+data.time_tolerance & data.time<=t0+T+data.time_tolerance);
        timeShift=-cut;spaceShift=-origin;
    else
        indices=find(data.time>t0+data.time_tolerance & data.time<cut-data.time_tolerance);
        timeShift=T-cut;spaceShift=drift-origin;
    end
    for k=indices.'
        new.appendSample(data.time(k)+timeShift,localTranslate(data.state(k,:),spaceShift,s),data.mode(k,:));
    end
end
if tau<=data.time_tolerance
    [left,leftMode]=HybridCycleData_v3.sample(data,t0+T,'left');
    left=localTranslate(left,-drift,s);
else
    [left,leftMode]=HybridCycleData_v3.sample(data,cut,'left');
end
new.appendSample(T,localTranslate(left,drift-origin,s),leftMode);
new.appendSample(T,localTranslate(initial,drift-origin,s),initialMode);
batches=data.trajectory.event_batches;
batchMap=zeros(numel(batches),1);
if ~isempty(batches)
    shifted=batches;
    for k=1:numel(batches)
        if batches(k).time>cut+data.time_tolerance
            shift=-origin;shifted(k).time=batches(k).time-cut;
        else
            shift=drift-origin;shifted(k).time=batches(k).time-cut+T;
        end
        shifted(k).state_before=localTranslate(batches(k).state_before,shift,s);
        shifted(k).state_after=localTranslate(batches(k).state_after,shift,s);
    end
    [~,order]=sort([shifted.time]);
    for k=order
        batchMap(k)=new.recordEventBatch(shifted(k));
    end
end
history=data.history;
for k=1:numel(history)
    e=history(k);
    if e.time<=t0+data.time_tolerance || e.time>t0+T+data.time_tolerance,continue;end
    if e.time>cut+data.time_tolerance,shift=-origin;time=e.time-cut;
    else,shift=drift-origin;time=e.time-cut+T;end
    e.time=time;e.index=0;
    if isfield(e.metadata,'event_batch_index') && ~isempty(e.metadata.event_batch_index)
        old=e.metadata.event_batch_index;
        if old>=1 && old<=numel(batchMap)
            e.metadata.event_batch_index=batchMap(old);
        else
            error('RephaseHybridOrbit_v3:MissingEventBatch','An event references an absent physical batch.');
        end
    end
    if ~isempty(e.state_before),e.state_before=localTranslate(e.state_before,shift,s);end
    if ~isempty(e.state_after),e.state_after=localTranslate(e.state_after,shift,s);end
    new.recordEvent(e);
end
if ~isempty(new.event_history)
    [~,order]=sort([new.event_history.time]);history=new.event_history(order);
    new.event_history=Trajectory_v3.emptyEventHistory();new.event_time=[];new.event_type=strings(0,1);
    for k=1:numel(history),new.recordEvent(history(k));end
end
new.metadata=struct('rephase_source_time',cut,'replay_required',true, ...
    'interpolation_contract',"one-sided piecewise linear");
[final,~]=HybridCycleData_v3.sample(HybridCycleData_v3.unpack(new),T);
rephased=HybridOrbit_v3(struct('trajectory',new,'initial_state',localTranslate(initial,-origin,s).', ...
    'initial_mode',initialMode.','period',T,'parameter',data.parameter, ...
    'event_history',new.event_history,'poincare_state',localTranslate(final,-drift,s).', ...
    'stride_displacement',(final-localTranslate(initial,-origin,s)).', ...
    'schema_metadata',s.metadata(),'section_chart',struct('id',"rephasing-predictor", ...
    'time_translation',tau,'translational_gauge',"x=0", ...
    'boundary_ownership',"post-reset/right-continuous",'replay_required',true)));
report=struct('time_translation',tau,'horizontal_translation',-origin, ...
    'drift_per_recorded_period',drift,'right_continuous',true,'replay_required',true, ...
    'accepted_as_solved_orbit',false,'event_count_before',numel(data.history), ...
    'event_count_after',numel(new.event_history));
end
function translated=localTranslate(state,shift,schema)
translated=state;
if isempty(state),return;end
translated(schema.TranslationIndex)=translated(schema.TranslationIndex)+shift;
end
