classdef HybridCycleData_v3
    %HYBRIDCYCLEDATA_V3 Read full-state quadruped cycles without graphics.
    % This is a data contract, not an orbit-validity or dynamics certificate.
    methods (Static)
        function data = unpack(source)
            schema = QuadrupedSchema_v3.shared();
            if isa(source, 'Trajectory_v3')
                trajectory = source;
                period = trajectory.time(end)-trajectory.time(1);
                parameter = [];
            elseif isa(source, 'HybridOrbit_v3') || isstruct(source)
                trajectory = source.trajectory;
                period = source.period;
                parameter = source.parameter;
            else
                error('HybridCycleData_v3:InvalidSource', ...
                    'Supply a full Trajectory_v3 or an orbit containing one.');
            end
            if ~isa(trajectory, 'Trajectory_v3') || numel(trajectory.time)<2
                error('HybridCycleData_v3:MissingTrajectory', ...
                    'At least two full trajectory samples are required.');
            end
            time = trajectory.time(:);
            state = trajectory.state;
            if size(state,1)~=numel(time) || size(state,2)~=schema.StateDimension ...
                    || any(~isfinite(state(:))) || any(diff(time)<0)
                error('HybridCycleData_v3:InvalidStateHistory', ...
                    'A finite chronological v3 state history is required.');
            end
            validateattributes(period, {'numeric'}, {'scalar','finite','positive'});
            tolerance = 128*eps(max(1,max(abs(time))));
            if time(end)<time(1)+period-tolerance
                error('HybridCycleData_v3:IncompleteCycle','Trajectory does not span its period.');
            end
            raw = trajectory.mode;
            if iscell(raw)
                mode = zeros(numel(time),schema.Leg.Count);
                for k=1:numel(time)
                    mode(k,:) = schema.validateMode(raw{k}).';
                end
            else
                mode = double(raw);
            end
            if ~isequal(size(mode),[numel(time),schema.Leg.Count]) ...
                    || any(~ismember(mode(:),[0,1]))
                error('HybridCycleData_v3:InvalidModeHistory','Full four-leg contact history is required.');
            end
            history = trajectory.event_history;
            if ~isa(source,'Trajectory_v3') && ...
                    ((isstruct(source) && isfield(source,'event_history')) || ...
                    (isobject(source) && isprop(source,'event_history'))) && ...
                    ~isempty(source.event_history)
                history = source.event_history;
            end
            if ~isempty(history)
                history = history(~[history.is_stop]);
                history = history([history.time]>=time(1)-tolerance & ...
                    [history.time]<=time(1)+period+tolerance);
            end
            data = struct('trajectory',trajectory,'time',time,'state',state, ...
                'mode',logical(mode),'history',history,'start_time',time(1), ...
                'period',period,'parameter',parameter,'schema',schema, ...
                'time_tolerance',tolerance);
        end

        function [state,mode] = sample(data, queryTime, side)
            % Linear interpolation stays within the smooth one-sided span.
            if nargin<3, side='right'; end
            queryTime = queryTime(:);
            [knots,first] = unique(data.time,'stable');
            [~,last] = unique(data.time,'last');
            state = zeros(numel(queryTime),size(data.state,2));
            mode = false(numel(queryTime),size(data.mode,2));
            indexed = isa(knots,'double') && isreal(knots) && all(isfinite(knots(:))) ...
                && all(diff(knots)>0) && isa(data.time_tolerance,'double') ...
                && isscalar(data.time_tolerance) && isreal(data.time_tolerance) ...
                && isfinite(data.time_tolerance) && data.time_tolerance>=0;
            for k=1:numel(queryTime)
                time = queryTime(k);
                useIndex = indexed && isa(time,'double') && isreal(time) && isfinite(time);
                if useIndex
                    exact = lastDifferenceAtMost(knots,time,data.time_tolerance);
                    if exact==0 || ~(abs(knots(exact)-time)<=data.time_tolerance),exact=[];end
                else
                    exact = find(abs(knots-time)<=data.time_tolerance,1,'last');
                end
                if ~isempty(exact)
                    if strcmp(side,'left'), row=first(exact); else, row=last(exact); end
                    state(k,:) = data.state(row,:); mode(k,:) = data.mode(row,:);
                else
                    if useIndex
                        left = lastStrictlyLess(knots,time);right=left+1;
                        if left==0,left=[];end
                        if right>numel(knots),right=[];end
                    else
                        left = find(knots<time,1,'last');
                        right = find(knots>time,1,'first');
                    end
                    if isempty(left) || isempty(right)
                        error('HybridCycleData_v3:OutsideHistory','Sample is outside the recorded history.');
                    end
                    a=last(left); b=first(right);
                    weight=(time-knots(left))/(knots(right)-knots(left));
                    state(k,:)=(1-weight)*data.state(a,:)+weight*data.state(b,:);
                    mode(k,:)=data.mode(a,:);
                end
            end
        end

        function [leg,kind] = eventIdentity(event,schema)
            leg=[]; kind="";
            if isfield(event,'metadata') && isstruct(event.metadata) ...
                    && isfield(event.metadata,'leg_index') ...
                    && isfield(event.metadata,'event_kind')
                leg=event.metadata.leg_index;
                kind=lower(string(event.metadata.event_kind));
            else
                name=string(event.guard_name);
                if strlength(name)==0, name=string(event.type); end
                id=find(strcmpi(name,schema.Event.Names),1);
                if ~isempty(id)
                    leg=schema.Event.LegIndices(id);
                    if schema.Event.IsTouchdown(id), kind="touchdown"; else, kind="liftoff"; end
                end
            end
            if kind=="td", kind="touchdown"; end
            if kind=="lo", kind="liftoff"; end
            if isempty(leg) || ~isscalar(leg) || ~ismember(leg,schema.Leg.Indices) ...
                    || ~ismember(kind,["touchdown","liftoff"])
                leg=[]; kind="";
            end
        end

        function events = physicalEvents(data, period, timeTolerance)
            % One physical multiset on (0,T], with 0/T storage deduplicated.
            % Repeated events away from the boundary retain multiplicity.
            if nargin<2, period=data.period; end
            if nargin<3, timeTolerance=data.time_tolerance; end
            prototype=struct('leg_index',0,'kind',"",'time',NaN, ...
                'cycle_time',NaN,'phase',NaN,'source_index',0,'history_index',0);
            events=repmat(prototype,0,1); starts=events; ends=events;
            for k=1:numel(data.history)
                e=data.history(k); relative=e.time-data.start_time;
                if relative < -timeTolerance || relative > period+timeTolerance,continue;end
                if isfield(e,'is_stop') && e.is_stop,continue;end
                if isfield(e,'metadata') && isstruct(e.metadata)
                    m=e.metadata;
                    if (isfield(m,'is_physical') && ~m.is_physical) || ...
                            (isfield(m,'is_arming') && m.is_arming) || ...
                            (isfield(m,'diagnostic_only') && m.diagnostic_only),continue;end
                end
                [leg,kind]=HybridCycleData_v3.eventIdentity(e,data.schema);
                if isempty(leg),continue;end
                index=k;if isfield(e,'index'),index=e.index;end
                entry=struct('leg_index',leg,'kind',kind,'time',e.time, ...
                    'cycle_time',relative,'phase',mod(relative/period,1), ...
                    'source_index',index,'history_index',k);
                if abs(relative)<=timeTolerance
                    entry.cycle_time=period;entry.phase=0;starts(end+1,1)=entry; %#ok<AGROW>
                elseif abs(relative-period)<=timeTolerance
                    entry.cycle_time=period;entry.phase=0;ends(end+1,1)=entry; %#ok<AGROW>
                else
                    events(end+1,1)=entry; %#ok<AGROW>
                end
            end
            % Pair only equivalent *boundary storage*; never erase an
            % interior duplicate or a repeated TD/LO occurrence.
            used=false(numel(ends),1);
            for k=1:numel(starts)
                peers=find(~used & [ends.leg_index].'==starts(k).leg_index & ...
                    string({ends.kind}).'==starts(k).kind,1);
                if isempty(peers),ends(end+1,1)=starts(k);used(end+1,1)=true;
                else,used(peers)=true;end
            end
            events=[events;ends];
            if ~isempty(events)
                [~,order]=sortrows([[events.cycle_time].',[events.source_index].'],[1 2]);
                events=events(order);
            end
        end

        function report = reconstructContact(data, period, timeTolerance)
            % Reconstruct right-continuous modes from atomic TD/LO cohorts.
            % Intermediate modes at one cohort have zero physical duration.
            if nargin<2,period=data.period;end
            if nargin<3,timeTolerance=data.time_tolerance;end
            events=HybridCycleData_v3.physicalEvents(data,period,timeTolerance);
            [~,initial]=HybridCycleData_v3.sample(data,data.start_time);
            q=initial;breaks=0;modes=false(0,4);cohorts=cell(0,1);
            valid=~isempty(events);reasons=strings(0,1);position=1;
            if isempty(events),reasons(end+1)="empty physical event history";end
            while position<=numel(events)
                last=position;
                while last<numel(events) && ...
                        events(last+1).cycle_time-events(position).cycle_time<=timeTolerance
                    last=last+1;
                end
                members=position:last;
                time=mean([events(members).cycle_time]);
                if abs(time-period)<=timeTolerance,time=period;end
                if time>breaks(end)
                    modes(end+1,:)=q;breaks(end+1,1)=time; %#ok<AGROW>
                end
                for j=members
                    leg=events(j).leg_index;next=events(j).kind=="touchdown";
                    if q(leg)==next
                        valid=false;reasons(end+1)="event does not change its declared leg mode"; %#ok<AGROW>
                    end
                    q(leg)=next;
                end
                cohorts{end+1,1}=members; %#ok<AGROW>
                position=last+1;
            end
            if breaks(end)<period
                modes(end+1,:)=q;breaks(end+1,1)=period;
            end
            if ~isequal(q,initial)
                valid=false;reasons(end+1)="reconstructed contact cycle is not closed";
            end
            % Compare every recorded positive-duration span. Same-time
            % reset intermediates have no contact-time measure.
            recorded=unique([data.start_time;data.time(data.time>data.start_time & ...
                data.time<data.start_time+period);data.start_time+period]);
            query=(recorded(1:end-1)+recorded(2:end))/2-data.start_time;
            [~,saved]=HybridCycleData_v3.sample(data,data.start_time+query);
            mismatch=false(numel(query),1);
            for k=1:numel(query)
                if ~isempty(events) && any(abs([events.cycle_time]-query(k))<=timeTolerance)
                    continue
                end
                span=find(breaks<=query(k),1,'last');span=min(span,size(modes,1));
                if isempty(span) || span<1,mismatch(k)=true;
                else,mismatch(k)=any(saved(k,:)~=modes(span,:));end
            end
            if any(mismatch)
                valid=false;reasons(end+1)="saved positive-duration modes disagree with physical events";
            end
            report=struct('complete',valid,'reason',strjoin(unique(reasons),"; "), ...
                'events',events,'knots',breaks,'modes',modes,'initial_mode',initial, ...
                'final_mode',q,'cohorts',{cohorts},'saved_mode_mismatch',mismatch, ...
                'event_time_tolerance',timeTolerance,'atomic_cohorts',true);
        end

        function report = eventPermutationMatch(events, period, permutation, shift, timeTolerance)
            % Bijective matching of full event multisets AND atomic cohorts.
            % SHIFT is in cycles; times and tolerance are in native time.
            n=numel(events);match=zeros(n,1);worst=0;ok=n>0;
            phase=reshape([events.phase],[],1);leg=reshape([events.leg_index],[],1);
            kind=reshape(string({events.kind}),[],1);tol=timeTolerance/period;
            for i=1:4
                for type=["touchdown","liftoff"]
                    a=find(leg==i & kind==type);b=find(leg==permutation(i) & kind==type);
                    if numel(a)~=numel(b),ok=false;continue;end
                    if isempty(a),continue;end
                    [target,orderA]=sort(mod(phase(a)+shift,1));a=a(orderA);
                    [~,orderB]=sort(phase(b));b=b(orderB);
                    best=Inf;bestB=b;
                    for rotation=0:numel(b)-1
                        rotated=circshift(b,-rotation);
                        error=max(abs(CircularPhase_v3.difference(phase(rotated),target)));
                        if error<best,best=error;bestB=rotated;end
                    end
                    if best>tol,ok=false;end
                    match(a)=bestB;worst=max(worst,best*period);
                end
            end
            cohort=HybridCycleData_v3.circularCohorts(phase,tol);
            cohortOK=ok && all(match>0) && numel(unique(match))==n;
            if cohortOK
                for c=unique(cohort).'
                    selected=find(cohort==c);mapped=match(selected);
                    targets=unique(cohort(mapped));
                    if numel(targets)~=1 || nnz(cohort==targets(1))~=numel(selected)
                        cohortOK=false;break
                    end
                end
            end
            report=struct('matched',ok && cohortOK,'event_bijection',match, ...
                'maximum_circular_time_error',worst,'cohort_bijection',cohortOK, ...
                'cohort_ids',cohort,'event_count',n,'shift_fraction',shift, ...
                'leg_permutation',permutation,'circular_time_tolerance',timeTolerance);
        end

        function ids = circularCohorts(phase,tolerance)
            ids=zeros(numel(phase),1);
            if isempty(phase),return;end
            [p,order]=sort(phase);cluster=1;first=1;ids(order(1))=cluster;
            for k=2:numel(p)
                if p(k)-p(first)>tolerance,cluster=cluster+1;first=k;end
                ids(order(k))=cluster;
            end
            if cluster>1
                firstMembers=find(ids==1);lastMembers=find(ids==cluster);
                if max(phase(firstMembers))+1-min(phase(lastMembers))<=tolerance
                    ids(lastMembers)=1;
                end
            end
        end
    end
end

function index=lastDifferenceAtMost(knots,time,tolerance)
    % Subtract exactly as the original vector predicate; time+tolerance
    % could round differently at a tolerance boundary.
    lo=1;hi=numel(knots);index=0;
    while lo<=hi
        middle=floor((lo+hi)/2);
        if knots(middle)-time<=tolerance,index=middle;lo=middle+1;
        else,hi=middle-1;end
    end
end
function index=lastStrictlyLess(knots,time)
    lo=1;hi=numel(knots);index=0;
    while lo<=hi
        middle=floor((lo+hi)/2);
        if knots(middle)<time,index=middle;lo=middle+1;
        else,hi=middle-1;end
    end
end
