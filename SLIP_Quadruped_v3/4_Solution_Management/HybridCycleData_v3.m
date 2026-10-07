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
            if ~isa(source,'Trajectory_v3') && ~isempty(source.event_history)
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
            for k=1:numel(queryTime)
                time = queryTime(k);
                exact = find(abs(knots-time)<=data.time_tolerance,1,'last');
                if ~isempty(exact)
                    if strcmp(side,'left'), row=first(exact); else, row=last(exact); end
                    state(k,:) = data.state(row,:); mode(k,:) = data.mode(row,:);
                else
                    left = find(knots<time,1,'last');
                    right = find(knots>time,1,'first');
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
    end
end
