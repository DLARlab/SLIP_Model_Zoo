classdef EventDetector_v3
    %EVENTDETECTOR_V3 Integrate one mode and locate its earliest event.
    %
    % The detector freezes the active-guard set over a smooth integration
    % segment, as required by a fixed discrete mode.  Guards that start on
    % zero are initially unarmed. Pure event callbacks locate auxiliary
    % interior-entry roots; arming is committed BETWEEN solver calls.
    % Speculative or backtracked callback evaluations cannot alter arming.
    % These restarts follow the same smooth flow without physical resets.

    properties (SetAccess = private)
        Options
    end

    methods
        function obj = EventDetector_v3(options)
            if nargin < 1
                options = struct();
            end
            obj.Options = EventDetector_v3.mergeOptions( ...
                EventDetector_v3.defaultOptions(), options);
        end

        function [segment, event, armingContext] = integrate(obj, system, x0, q, p, ...
                tspan, stopCondition, odeOptions, restartContext)
            %INTEGRATE Propagate one continuous-mode segment.
            if nargin < 7 || isempty(stopCondition)
                stopCondition = [];
            end
            if nargin < 8 || isempty(odeOptions)
                odeOptions = odeset();
            end
            if nargin < 9, restartContext = []; end
            validateattributes(tspan, {'numeric'}, ...
                {'vector', 'numel', 2, 'real', 'finite'});
            tspan = tspan(:).';
            if tspan(2) <= tspan(1)
                error('EventDetector_v3:InvalidTimeSpan', ...
                    'TSPAN must contain increasing start and final times.');
            end
            x0 = x0(:);

            guardTemplate = obj.guardDescriptors(system, ...
                tspan(1), x0, q, p);
            stopTemplate = obj.stopDescriptors(stopCondition, ...
                tspan(1), x0, q, p);
            guardCount = numel(guardTemplate);
            stopCount = numel(stopTemplate);

            guardArmed = obj.initialArming(guardTemplate);
            stopArmed = obj.initialArming(stopTemplate);
            if ~isempty(restartContext)
                [guardArmed,stopArmed]=obj.restoreRestart(restartContext, ...
                    system,stopCondition,tspan(1),x0,q,p,guardTemplate,stopTemplate);
            end
            guardInterior = obj.interiorSigns(guardTemplate);
            stopInterior = obj.interiorSigns(stopTemplate);

            odeOptions = obj.configureOdeOptions(odeOptions);
            if guardCount + stopCount > 0
                odeOptions = odeset(odeOptions, 'Events', @eventFunction);
            end

            solver = obj.Options.ODESolver;
            if ischar(solver) || isstring(solver)
                solver = str2func(char(solver));
            end
            flow = @(t, x) obj.evaluateFlow(system, t, x, q, p);
            currentTime=tspan(1); currentState=x0;
            accumulatedTime=zeros(0,1); accumulatedState=zeros(0,numel(x0));
            armingRestarts=0;
            channelCount=guardCount+stopCount;
            settings=struct('RelTol',odeget(odeOptions,'RelTol'), ...
                'AbsTol',odeget(odeOptions,'AbsTol'), ...
                'MaxStep',odeget(odeOptions,'MaxStep'), ...
                'ArmingTolerance',obj.Options.ArmingTolerance, ...
                'ArmingMethod','located-interior-entry-between-solver-calls');
            while true
                % These masks are immutable throughout THIS solver call.
                % Event values are consequently functions of (t,x) alone.
                frozenArmed=[guardArmed;stopArmed];
                try
                    if channelCount > 0
                        [time,state,eventTime,eventState,eventIndex]= ...
                            solver(flow,[currentTime,tspan(2)],currentState,odeOptions);
                    else
                        [time,state]=solver(flow,[currentTime,tspan(2)],currentState,odeOptions);
                        eventTime=[];eventState=[];eventIndex=[];
                    end
                catch exception
                    wrapped=MException('EventDetector_v3:IntegrationFailed', ...
                        'Continuous integration failed in the active mode.');
                    wrapped=addCause(wrapped,exception);throwAsCaller(wrapped);
                end
                if isempty(eventTime)
                    [accumulatedTime,accumulatedState]=appendSmooth( ...
                        accumulatedTime,accumulatedState,time(:),state);
                    segment=struct('time',accumulatedTime,'state',accumulatedState, ...
                        'integration_settings',settings,'arming_restart_count',armingRestarts);
                    event=obj.noEvent(time(end),state(end,:).');
                    armingContext=obj.returnContext(system,stopCondition,event,q,p, ...
                        guardTemplate,stopTemplate,frozenArmed);return;
                end
                [firstTime,firstRow]=min(eventTime);
                % Only solver roots at the actual earliest instant own this
                % accepted boundary. EventTimeTolerance cannot select its
                % state or credit future physical/auxiliary root reports.
                rootRoundoff=64*eps(max(realmin,abs(firstTime)));
                earliestRows=find(abs(eventTime-firstTime)<=rootRoundoff);
                eventStateVector=eventState(firstRow,:).';
                % Keep chronological truncation even for MATLAB's first-step
                % terminal-event behavior, which can return later samples.
                if firstTime<currentTime
                    error('EventDetector_v3:EventBeforeSpan', ...
                        'The solver reported an event before the integration span.');
                end
                before=time(:)<firstTime;
                [accumulatedTime,accumulatedState]=appendSmooth( ...
                    accumulatedTime,accumulatedState,[time(before);firstTime], ...
                    [state(before,:);eventStateVector.']);
                reportedChannels=unique(eventIndex(earliestRows));
                triggeredChannels=reportedChannels(reportedChannels<=channelCount);
                entry=reportedChannels(reportedChannels>channelCount)-channelCount;
                % Legitimate simultaneous physical clustering needs an
                % actual physical/stop root anchor. An interior-entry root
                % alone must never manufacture a nearby physical event.
                if ~isempty(triggeredChannels)
                    [guardBatch,stopBatch]=obj.clusterAtEvent( ...
                        system,stopCondition,firstTime,eventStateVector,q,p, ...
                        guardTemplate,stopTemplate,triggeredChannels,frozenArmed);
                    segment=struct('time',accumulatedTime,'state',accumulatedState, ...
                        'integration_settings',settings,'arming_restart_count',armingRestarts);
                    event=struct('occurred',true,'time',firstTime, ...
                        'state',eventStateVector,'guard_batch',guardBatch, ...
                        'stop_batch',stopBatch,'stop_occurred',~isempty(stopBatch), ...
                        'triggered_channels',triggeredChannels(:), ...
                        'raw_event_times',eventTime(:),'raw_event_indices',eventIndex(:));
                    % The same accepted exact-entry set is used both here
                    % and in the auxiliary-only continuation branch below.
                    returnedArmed=frozenArmed;returnedArmed(entry)=true;
                    armingContext=obj.returnContext(system,stopCondition,event,q,p, ...
                        guardTemplate,stopTemplate,returnedArmed,entry);
                    return;
                end
                newlyArmed=entry;
                if isempty(newlyArmed)||firstTime<=currentTime
                    error('EventDetector_v3:UnresolvedArming', ...
                        'Interior-entry arming did not produce a positive-time restart.');
                end
                armed=frozenArmed;armed(newlyArmed)=true;
                guardArmed=armed(1:guardCount);stopArmed=armed(guardCount+1:end);
                armingRestarts=armingRestarts+1;
                if armingRestarts>channelCount
                    error('EventDetector_v3:ArmingRestartLimit', ...
                        'Every channel can be armed at most once per smooth mode.');
                end
                currentTime=firstTime;currentState=eventStateVector;
                if currentTime>=tspan(2)
                    segment=struct('time',accumulatedTime,'state',accumulatedState, ...
                        'integration_settings',settings,'arming_restart_count',armingRestarts);
                    event=obj.noEvent(currentTime,currentState);
                    armingContext=obj.returnContext(system,stopCondition,event,q,p, ...
                        guardTemplate,stopTemplate,armed);return;
                end
            end

            function [value, isterminal, direction] = eventFunction(t, x)
                guards = obj.guardDescriptors(system, t, x, q, p);
                guardValues = obj.valuesInTemplateOrder( ...
                    guardTemplate, guards);
                stops = obj.stopDescriptors(stopCondition, t, x, q, p);
                stopValues = obj.stopValuesInTemplateOrder( ...
                    stopTemplate, stops);

                rawValues=[guardValues;stopValues];
                interiors=[guardInterior;stopInterior];
                physicalValues=rawValues;
                physicalValues(~frozenArmed)= ...
                    interiors(~frozenArmed)*obj.Options.InteriorBias;
                % Auxiliary roots locate entry into the directional interior.
                % They never appear in the physical event/reset history.
                armingValues=ones(channelCount,1);
                armingValues(~frozenArmed)= ...
                    interiors(~frozenArmed).*rawValues(~frozenArmed) ...
                    -obj.Options.ArmingTolerance;
                value=[physicalValues;armingValues];
                % Every system guard is terminal for the current smooth
                % segment; the simulator applies its reset and restarts.
                isterminal = ones(size(value));
                direction = [obj.descriptorDirections(guardTemplate); ...
                    obj.descriptorDirections(stopTemplate);ones(channelCount,1)];
            end

            function [joinedTime,joinedState]=appendSmooth(oldTime,oldState,newTime,newState)
                if ~isempty(oldTime)
                    keep=newTime>oldTime(end);newTime=newTime(keep);newState=newState(keep,:);
                end
                joinedTime=[oldTime;newTime];joinedState=[oldState;newState];
            end
        end

        function [ready,diagnostics]=prepareRestart(obj,context,stateAfter,modeAfter, ...
                processedGuardIds,processedStopIds)
            %PREPARERESTART Commit arming ownership after model-owned resets.
            % Context is ephemeral: it contains runtime collaborators and must
            % not be embedded in trajectories, solver reports or checkpoints.
            % The caller supplies ONLY physical/stop channels actually consumed.
            if nargin<6,processedStopIds={};end
            obj.requireContext(context,'returned');
            stateAfter=stateAfter(:);
            assert(isequal(size(stateAfter),size(context.state))&&all(isfinite(stateAfter)), ...
                'EventDetector_v3:RestartState','A restart preserves the finite state dimension.');
            guardIds=EventDetector_v3.idList(processedGuardIds);
            stopIds=EventDetector_v3.idList(processedStopIds);
            EventDetector_v3.requireOffered(guardIds,context.offered_guard_ids,'guard');
            EventDetector_v3.requireOffered(stopIds,context.offered_stop_ids,'stop');
            guards=obj.guardDescriptors(context.system_reference,context.time, ...
                stateAfter,modeAfter,context.parameter);
            stops=obj.stopDescriptors(context.stop_condition_reference,context.time, ...
                stateAfter,modeAfter,context.parameter);
            [guardRows,guardReports]=obj.restartRows(context.guard_rows,guards,guardIds, ...
                context.state,stateAfter,context.time,'guard',context.accepted_auxiliary_guard_ids);
            [stopRows,stopReports]=obj.restartRows(context.stop_rows,stops,stopIds, ...
                context.state,stateAfter,context.time,'stop',context.accepted_auxiliary_stop_ids);
            ready=context;ready.phase='ready';ready.state=stateAfter;ready.mode=modeAfter;
            ready.guard_rows=guardRows;ready.stop_rows=stopRows;
            ready.offered_guard_ids={};ready.offered_stop_ids={};
            ready.accepted_auxiliary_guard_ids={};ready.accepted_auxiliary_stop_ids={};
            diagnostics=[guardReports;stopReports];
        end

        function [ready,diagnostics]=prepareContinuousRestart(obj,context,state,mode)
            %PREPARECONTINUOUSRESTART No physical reset or transition occurred.
            % Exact continuous endpoints preserve guard geometry, even without
            % a model reset-geometry declaration. A caller that processed ANY
            % physical guard must instead call prepareRestart, even if that
            % reset left the numerical state/mode unchanged.
            obj.requireContext(context,'returned');
            assert(isequaln(context.state,state(:))&&isequaln(context.mode,mode), ...
                'EventDetector_v3:RestartBinding','A no-reset handoff preserves the exact accepted state and mode.');
            ready=context;ready.phase='ready';diagnostics=cell(numel(context.guard_rows),1);
            for k=1:numel(context.guard_rows)
                row=context.guard_rows{k};d=row.descriptor;
                diagnostics{k}=struct('time',context.time,'channel_kind','guard','id',d.id, ...
                    'action','continuous-handoff-no-physical-reset','prior_armed',row.armed,'armed',row.armed, ...
                    'geometry_declared',~isempty(EventDetector_v3.geometry(d,numel(state))), ...
                    'geometry_continuous',true,'accepted_auxiliary_entry', ...
                    EventDetector_v3.hasId(context.accepted_auxiliary_guard_ids,d.id));
            end
            % A stop actually reported at this endpoint is consumed. The
            % explicit simulation rebind will replace the entire stop set,
            % but a direct ready-context user must not repeat that stop at 0.
            for k=1:numel(ready.stop_rows)
                d=ready.stop_rows{k}.descriptor;
                if EventDetector_v3.hasId(context.offered_stop_ids,d.id)
                    ready.stop_rows{k}.armed=EventDetector_v3.interiorSign(d)*d.value>obj.Options.ArmingTolerance;
                end
            end
            ready.offered_guard_ids={};ready.offered_stop_ids={};
            ready.accepted_auxiliary_guard_ids={};ready.accepted_auxiliary_stop_ids={};
        end

        function ready=prepareSimulationRestart(obj,context,system,condition,time,state,mode,p)
            %PREPARESIMULATIONRESTART Explicit physical-only cross-call handoff.
            % Binds an exact endpoint, retains only physical arming ownership,
            % and initializes the newly declared stop namespace independently.
            % Arbitrary stop mismatch remains forbidden by integrate itself.
            obj.requireContext(context,'ready');state=state(:);
            assert(EventDetector_v3.sameCollaborator(context.system_reference,system) ...
                &&isequaln(context.time,time)&&isequaln(context.state,state) ...
                &&isequaln(context.mode,mode)&&isequaln(context.parameter,p), ...
                'EventDetector_v3:RestartBinding','A simulation handoff requires the exact system/time/state/mode/parameter endpoint.');
            guards=obj.guardDescriptors(system,time,state,mode,p);
            obj.restoreRows(context.guard_rows,guards,numel(state));
            stops=obj.stopDescriptors(condition,time,state,mode,p);
            ready=context;ready.stop_condition_reference=condition;
            ready.stop_rows=obj.contextRows(stops,stops,obj.initialArming(stops));
            ready.offered_guard_ids={};ready.offered_stop_ids={};
            ready.accepted_auxiliary_guard_ids={};ready.accepted_auxiliary_stop_ids={};
        end
    end

    methods (Access = private)
        function context=returnContext(obj,system,condition,event,q,p,guardTemplate,stopTemplate,armed,acceptedEntries)
            if nargin<10,acceptedEntries=[];end
            guards=obj.guardDescriptors(system,event.time,event.state,q,p);
            stops=obj.stopDescriptors(condition,event.time,event.state,q,p);
            guardEntries=acceptedEntries(acceptedEntries<=numel(guardTemplate));
            stopEntries=acceptedEntries(acceptedEntries>numel(guardTemplate))-numel(guardTemplate);
            context=struct('schema','event-detector-arming-context-v1','phase','returned', ...
                'system_reference',system,'stop_condition_reference',condition, ...
                'detector_options_snapshot',obj.Options, ...
                'time',event.time,'state',event.state(:),'mode',q,'parameter',p, ...
                'guard_rows',{obj.contextRows(guardTemplate,guards,armed(1:numel(guardTemplate)))}, ...
                'stop_rows',{obj.contextRows(stopTemplate,stops,armed(numel(guardTemplate)+1:end))}, ...
                'offered_guard_ids',{EventDetector_v3.descriptorIds(event.guard_batch)}, ...
                'offered_stop_ids',{EventDetector_v3.descriptorIds(event.stop_batch)}, ...
                'accepted_auxiliary_guard_ids',{EventDetector_v3.descriptorIds(guardTemplate(guardEntries))}, ...
                'accepted_auxiliary_stop_ids',{EventDetector_v3.descriptorIds(stopTemplate(stopEntries))});
        end

        function rows=contextRows(~,template,current,armed)
            assert(numel(template)==numel(current),'EventDetector_v3:ChangingGuardSet', ...
                'Enabled channel identities must stay fixed within one continuous mode.');
            rows=cell(numel(current),1);
            for k=1:numel(current)
                at=EventDetector_v3.findDescriptor(template,current(k).id);
                assert(isscalar(at),'EventDetector_v3:ChangingGuardSet', ...
                    'An enabled channel changed identity within a continuous mode.');
                rows{k}=struct('descriptor',current(k),'armed',logical(armed(at)));
            end
        end

        function [guards,stops]=restoreRestart(obj,context,system,condition,time,state,q,p,guardTemplate,stopTemplate)
            obj.requireContext(context,'ready');
            assert(EventDetector_v3.sameCollaborator(context.system_reference,system) ...
                &&EventDetector_v3.sameStopCondition(context.stop_condition_reference,condition) ...
                &&isequaln(context.time,time)&&isequaln(context.state,state)&&isequaln(context.mode,q)&&isequaln(context.parameter,p), ...
                'EventDetector_v3:RestartBinding','Reuse context only at its exact model/state/mode/parameter/time and stopping condition.');
            guards=obj.restoreRows(context.guard_rows,guardTemplate,numel(state));
            stops=obj.restoreRows(context.stop_rows,stopTemplate,numel(state));
        end

        function armed=restoreRows(~,rows,descriptors,stateCount)
            assert(numel(rows)==numel(descriptors),'EventDetector_v3:RestartActivation', ...
                'The enabled channel set changed after restart preparation.');
            armed=false(numel(descriptors),1);
            for k=1:numel(descriptors)
                at=EventDetector_v3.findRow(rows,descriptors(k).id);
                assert(isscalar(at)&&EventDetector_v3.sameChannel(rows{at}.descriptor,descriptors(k)) ...
                    &&isequaln(rows{at}.descriptor.value,descriptors(k).value) ...
                    &&isequaln(EventDetector_v3.geometry(rows{at}.descriptor,stateCount), ...
                        EventDetector_v3.geometry(descriptors(k),stateCount)), ...
                    'EventDetector_v3:RestartActivation','Channel geometry/activation changed after restart preparation.');
                armed(k)=rows{at}.armed;
            end
        end

        function [rows,reports]=restartRows(obj,previous,current,consumed,before,after,time,channelKind,acceptedEntries)
            rows=cell(numel(current),1);reports=cell(numel(current),1);
            for k=1:numel(current)
                d=current(k);at=EventDetector_v3.findRow(previous,d.id);
                armed=abs(d.value)>obj.Options.ArmingTolerance;action='new-channel-initial-protection';
                priorArmed=false;continuous=false;declared=false;
                if EventDetector_v3.hasId(consumed,d.id)
                    armed=EventDetector_v3.interiorSign(d)*d.value>obj.Options.ArmingTolerance;
                    action='consumed-channel-reentry-protection';
                elseif ~isempty(at)
                    old=previous{at};priorArmed=old.armed;
                    oldGeometry=EventDetector_v3.geometry(old.descriptor,numel(before));
                    newGeometry=EventDetector_v3.geometry(d,numel(after));
                    declared=~isempty(oldGeometry)&&~isempty(newGeometry);
                    sameGeometry=declared&&isequaln(oldGeometry,newGeometry) ...
                        &&EventDetector_v3.sameChannel(old.descriptor,d);
                    if sameGeometry
                        dependencies=newGeometry.state_dependencies;
                        continuous=isequaln(before(dependencies),after(dependencies)) ...
                            &&isfinite(old.descriptor.value)&&isfinite(d.value) ...
                            &&isequaln(old.descriptor.value,d.value);
                    end
                    if continuous
                        armed=priorArmed||EventDetector_v3.interiorSign(d)*d.value>obj.Options.ArmingTolerance;
                        if priorArmed,action='carried-armed';else,action='carried-reentry-protection';end
                    else
                        jump=priorArmed&&EventDetector_v3.directedJump(old.descriptor.value,d.value,d.direction);
                        near=priorArmed&&isfinite(d.value)&&abs(d.value)<=obj.Options.ArmingTolerance;
                        if jump||near
                            error('EventDetector_v3:UnsupportedRestartGeometry', ...
                                ['Unconsumed %s %s has undeclared/reset-affected geometry near or across its surface ', ...
                                 'at t=%.17g (g_before=%.17g,g_after=%.17g). ', ...
                                 'The model must resolve reset-induced/atomic contacts or declare unchanged geometry.'], ...
                                channelKind,char(string(d.id)),time,old.descriptor.value,d.value);
                        end
                        action='reset-affected-channel-reinitialized';
                    end
                end
                rows{k}=struct('descriptor',d,'armed',logical(armed));
                reports{k}=struct('time',time,'channel_kind',channelKind,'id',d.id, ...
                    'action',action,'prior_armed',priorArmed,'armed',logical(armed), ...
                    'geometry_declared',declared,'geometry_continuous',continuous, ...
                    'accepted_auxiliary_entry',EventDetector_v3.hasId(acceptedEntries,d.id));
            end
        end

        function requireContext(obj,context,phase)
            required={'schema','phase','detector_options_snapshot','system_reference','stop_condition_reference','time','state','mode','parameter', ...
                'guard_rows','stop_rows','offered_guard_ids','offered_stop_ids', ...
                'accepted_auxiliary_guard_ids','accepted_auxiliary_stop_ids'};
            assert(isstruct(context)&&isscalar(context)&&all(isfield(context,required)) ...
                &&strcmp(context.schema,'event-detector-arming-context-v1')&&strcmp(context.phase,phase), ...
                'EventDetector_v3:RestartContext','Use the detector-produced context through prepareRestart.');
            % This binds the normalized detector configuration, not separate
            % per-call nested ODEOptions. Those remain explicit integration
            % inputs and are reported by segment.integration_settings.
            assert(isequaln(context.detector_options_snapshot,obj.Options), ...
                'EventDetector_v3:RestartBinding','Opaque arming ownership requires the exact producing detector configuration.');
        end

        function options = configureOdeOptions(obj, options)
            if ~isempty(obj.Options.RelTol)
                nested=odeget(options,'RelTol');value=obj.Options.RelTol;
                if ~isempty(nested),value=min(value,nested);end
                options = odeset(options, 'RelTol', value);
            end
            if ~isempty(obj.Options.AbsTol)
                nested=odeget(options,'AbsTol');value=obj.Options.AbsTol;
                if ~isempty(nested)
                    if ~isscalar(value)&&~isscalar(nested)&&numel(value)~=numel(nested)
                        error('EventDetector_v3:AbsoluteToleranceDimension', ...
                            'Top-level and nested absolute tolerance vectors must agree in length.');
                    end
                    value=min(value(:),nested(:));
                end
                options = odeset(options, 'AbsTol', value);
            end
            if ~isempty(obj.Options.MaxStep) && isfinite(obj.Options.MaxStep)
                nested=odeget(options,'MaxStep');value=obj.Options.MaxStep;
                if ~isempty(nested),value=min(value,nested);end
                options = odeset(options, 'MaxStep', value);
            end
        end

        function flow = evaluateFlow(~, system, t, x, q, p)
            flow = system.flow(t, x, q, p);
            flow = flow(:);
            if numel(flow) ~= numel(x) || any(~isfinite(flow))
                error('EventDetector_v3:InvalidFlow', ...
                    'SYSTEM.FLOW must return one finite derivative per state.');
            end
        end

        function descriptors = guardDescriptors(~, system, t, x, q, p)
            descriptors = system.activeGuards(t, x, q, p);
            descriptors = EventDetector_v3.normalizeDescriptors( ...
                descriptors, "guard");
        end

        function descriptors = stopDescriptors(obj, condition, t, x, q, p)
            if isempty(condition)
                descriptors = EventDetector_v3.emptyDescriptors();
                return;
            end

            wrapper = struct();
            if isstruct(condition) && isscalar(condition) && ...
                    isfield(condition, 'Function')
                wrapper = condition;
                condition = condition.Function;
            end
            if isa(condition, 'function_handle')
                [raw, terminal, direction, metadata] = ...
                    obj.callStopFunction(condition, t, x, q, p);
            elseif isobject(condition) && ismethod(condition, 'evaluate')
                raw = condition.evaluate(t, x, q, p);
                terminal = [];
                direction = [];
                metadata = struct();
            elseif isstruct(condition)
                raw = condition;
                terminal = [];
                direction = [];
                metadata = struct();
            else
                error('EventDetector_v3:InvalidStopCondition', ...
                    ['StopCondition must be a function handle, descriptor ', ...
                     'structure, or object with an evaluate method.']);
            end

            if isstruct(raw)
                descriptors = EventDetector_v3.normalizeDescriptors( ...
                    raw, "stop");
            else
                values = raw(:);
                if isempty(terminal)
                    terminal = true(size(values));
                end
                if isempty(direction)
                    direction = zeros(size(values));
                end
                terminal = EventDetector_v3.expandToSize(terminal, numel(values));
                direction = EventDetector_v3.expandToSize(direction, numel(values));
                descriptors = repmat(EventDetector_v3.descriptorPrototype(), ...
                    numel(values), 1);
                for k = 1:numel(values)
                    descriptors(k).id = k;
                    descriptors(k).name = "stop_" + k;
                    descriptors(k).value = values(k);
                    descriptors(k).direction = direction(k);
                    descriptors(k).isterminal = logical(terminal(k));
                    descriptors(k).priority = -Inf;
                    descriptors(k).kind = "stop";
                    descriptors(k).enabled = logical(terminal(k));
                    if isstruct(metadata)
                        descriptors(k).metadata = metadata;
                    else
                        descriptors(k).metadata = struct('value', metadata);
                    end
                end
            end
            if ~isempty(fieldnames(wrapper))
                descriptors = EventDetector_v3.applyStopWrapper( ...
                    descriptors, wrapper);
            end
            if ~isempty(descriptors)
                descriptors = descriptors([descriptors.enabled]);
            end
        end

        function [value, terminal, direction, metadata] = ...
                callStopFunction(~, callback, t, x, q, p)
            argumentCount = nargin(callback);
            if argumentCount < 0 || argumentCount >= 4
                arguments = {t, x, q, p};
            elseif argumentCount == 3
                arguments = {t, x, q};
            elseif argumentCount == 2
                arguments = {t, x};
            elseif argumentCount == 1
                arguments = {x};
            else
                arguments = {};
            end

            outputCount = nargout(callback);
            metadata = struct();
            if outputCount == 1
                value = callback(arguments{:});
                terminal = [];
                direction = [];
            elseif outputCount == 2
                [value, terminal] = callback(arguments{:});
                direction = [];
            elseif outputCount == 3
                [value, terminal, direction] = callback(arguments{:});
            else
                try
                    [value, terminal, direction, metadata] = ...
                        callback(arguments{:});
                catch exception
                    if ~EventDetector_v3.isTooManyOutputs(exception)
                        rethrow(exception);
                    end
                    try
                        [value, terminal, direction] = callback(arguments{:});
                    catch exception
                        if ~EventDetector_v3.isTooManyOutputs(exception)
                            rethrow(exception);
                        end
                        try
                            [value, terminal] = callback(arguments{:});
                            direction = [];
                        catch exception
                            if ~EventDetector_v3.isTooManyOutputs(exception)
                                rethrow(exception);
                            end
                            value = callback(arguments{:});
                            terminal = [];
                            direction = [];
                        end
                    end
                end
            end
        end

        function values = valuesInTemplateOrder(~, template, current)
            values = zeros(numel(template), 1);
            for k = 1:numel(template)
                index = EventDetector_v3.findDescriptor(current, template(k).id);
                if isempty(index)
                    % A guard set must remain fixed while q is fixed.  A
                    % missing entry is kept away from zero defensively.
                    values(k) = EventDetector_v3.interiorSign(template(k));
                else
                    values(k) = current(index).value;
                end
            end
        end

        function values = stopValuesInTemplateOrder(~, template, current)
            if numel(current) ~= numel(template)
                error('EventDetector_v3:ChangingStopDimension', ...
                    'StopCondition output size changed during integration.');
            end
            values = zeros(numel(template), 1);
            for k = 1:numel(template)
                index = EventDetector_v3.findDescriptor(current, template(k).id);
                if isempty(index)
                    values(k) = EventDetector_v3.interiorSign(template(k));
                else
                    values(k) = current(index).value;
                end
            end
        end

        function armed = initialArming(obj, descriptors)
            if isempty(descriptors)
                armed = false(0, 1);
                return;
            end
            values = [descriptors.value].';
            armed = abs(values) > obj.Options.ArmingTolerance;
        end

        function signs = interiorSigns(~, descriptors)
            signs = zeros(numel(descriptors), 1);
            for k = 1:numel(descriptors)
                signs(k) = EventDetector_v3.interiorSign(descriptors(k));
            end
        end

        function [guards, stops] = clusterAtEvent(obj, system, condition, ...
                t, x, q, p, guardTemplate, stopTemplate, triggeredChannels,armed)
            currentGuards = obj.guardDescriptors(system, t, x, q, p);
            guards = EventDetector_v3.emptyDescriptors();
            for k = 1:numel(guardTemplate)
                if ~armed(k),continue;end
                index = EventDetector_v3.findDescriptor( ...
                    currentGuards, guardTemplate(k).id);
                if isempty(index)
                    descriptor = guardTemplate(k);
                    descriptor.value = NaN;
                else
                    descriptor = currentGuards(index);
                end
                descriptor.directional_derivative = ...
                    obj.guardDirectionalDerivative( ...
                        system, descriptor.id, t, x, q, p);
                wasTriggered = any(triggeredChannels == k);
                eligible = obj.isSimultaneous(descriptor);
                if wasTriggered && ~eligible
                    error('EventDetector_v3:IneligibleTriggeredGuard', ...
                        ['ODE-reported guard %s at t=%.17g fails the ', ...
                         'directed transverse-root contract (g=%.17g, DgF=%.17g).'], ...
                        char(string(descriptor.name)), t, descriptor.value, ...
                        descriptor.directional_derivative);
                end
                if eligible
                    guards(end + 1, 1) = descriptor; %#ok<AGROW>
                end
            end
            guards = EventDetector_v3.sortDescriptors(guards);

            currentStops = obj.stopDescriptors(condition, t, x, q, p);
            stops = EventDetector_v3.emptyDescriptors();
            for k = 1:numel(stopTemplate)
                if ~armed(numel(guardTemplate)+k),continue;end
                index = EventDetector_v3.findDescriptor( ...
                    currentStops, stopTemplate(k).id);
                if isempty(index)
                    descriptor = stopTemplate(k);
                    descriptor.value = NaN;
                else
                    descriptor = currentStops(index);
                end
                descriptor.directional_derivative = ...
                    obj.stopDirectionalDerivative( ...
                        system, condition, descriptor.id, t, x, q, p);
                channel = numel(guardTemplate) + k;
                wasTriggered = any(triggeredChannels == channel);
                eligible = obj.isSimultaneous(descriptor);
                if wasTriggered && ~eligible
                    error('EventDetector_v3:IneligibleTriggeredSection', ...
                        ['ODE-reported section %s at t=%.17g fails the ', ...
                         'directed transverse-root contract (h=%.17g, DhF=%.17g).'], ...
                        char(string(descriptor.name)), t, descriptor.value, ...
                        descriptor.directional_derivative);
                end
                if eligible
                    stops(end + 1, 1) = descriptor; %#ok<AGROW>
                end
            end
            stops = EventDetector_v3.sortDescriptors(stops);
        end

        function tf = isSimultaneous(obj, descriptor)
            value = descriptor.value;
            derivative = descriptor.directional_derivative;
            if ~isfinite(value)
                tf = false;
                return;
            end
            % A small guard value alone can be far from its next root
            % when the normal velocity is small. In particular, an apex
            % arming stop must not manufacture an early touchdown. Keep
            % the surface and estimated root-time tests independent.
            valueClose = abs(value) <= obj.Options.EventValueTolerance;
            if isfinite(derivative) && derivative ~= 0
                timeClose = abs(value / derivative) <= ...
                    obj.Options.SimultaneousTimeTolerance;
            else
                % The orientation test below excludes directed grazing.
                % An explicitly nondirectional zero-speed guard has no
                % linear root-time estimate and keeps its value contract.
                timeClose = true;
            end

            direction = descriptor.direction;
            derivativeTolerance = obj.Options.DirectionalDerivativeTolerance;
            directionConsistent = direction == 0 || ...
                (isfinite(derivative) && ...
                 direction * derivative > derivativeTolerance);
            tf = valueClose && timeClose && directionConsistent;
        end

        function derivative = guardDirectionalDerivative(obj, system, id, ...
                t, x, q, p)
            flow = obj.evaluateFlow(system, t, x, q, p);
            step = obj.derivativeStep(t, x, flow);
            plus = obj.guardDescriptors(system, t + step, ...
                x + step * flow, q, p);
            minus = obj.guardDescriptors(system, t - step, ...
                x - step * flow, q, p);
            plusIndex = EventDetector_v3.findDescriptor(plus, id);
            minusIndex = EventDetector_v3.findDescriptor(minus, id);
            if isempty(plusIndex) || isempty(minusIndex)
                derivative = NaN;
            else
                derivative = (plus(plusIndex).value - ...
                    minus(minusIndex).value) / (2 * step);
            end
        end

        function derivative = stopDirectionalDerivative(obj, system, ...
                condition, id, t, x, q, p)
            flow = obj.evaluateFlow(system, t, x, q, p);
            step = obj.derivativeStep(t, x, flow);
            plus = obj.stopDescriptors(condition, t + step, ...
                x + step * flow, q, p);
            minus = obj.stopDescriptors(condition, t - step, ...
                x - step * flow, q, p);
            plusIndex = EventDetector_v3.findDescriptor(plus, id);
            minusIndex = EventDetector_v3.findDescriptor(minus, id);
            if isempty(plusIndex) || isempty(minusIndex)
                derivative = NaN;
            else
                derivative = (plus(plusIndex).value - ...
                    minus(minusIndex).value) / (2 * step);
            end
        end

        function step = derivativeStep(obj, t, x, flow)
            scale = (1 + abs(t) + norm(x, Inf)) / ...
                max(1, norm(flow, Inf));
            step = max(obj.Options.DerivativeStep * scale, ...
                sqrt(eps) * scale);
        end

        function tolerance = timeTolerance(obj, time)
            tolerance = max(obj.Options.EventTimeTolerance, ...
                64 * eps(max(1, abs(time))));
        end
    end

    methods (Static, Access = private)
        function options = defaultOptions()
            options = struct( ...
                'ODESolver', @ode45, ...
                'RelTol', 1e-9, ...
                'AbsTol', 1e-11, ...
                'MaxStep', [], ...
                'EventValueTolerance', 1e-8, ...
                'EventTimeTolerance', 1e-10, ...
                'SimultaneousTimeTolerance', 1e-8, ...
                'DirectionalDerivativeTolerance', 1e-10, ...
                'DerivativeStep', 1e-7, ...
                'ArmingTolerance', 1e-9, ...
                'InteriorBias', 1e-9);
        end

        function output = mergeOptions(defaults, supplied)
            output = defaults;
            if isempty(supplied)
                return;
            end
            if ~isstruct(supplied) || ~isscalar(supplied)
                error('EventDetector_v3:InvalidOptions', ...
                    'Options must be a scalar structure.');
            end
            aliases = struct( ...
                'GuardTolerance', 'EventValueTolerance', ...
                'EventTolerance', 'EventValueTolerance', ...
                'SimultaneousTolerance', 'SimultaneousTimeTolerance');
            names = fieldnames(supplied);
            for k = 1:numel(names)
                name = names{k};
                target = name;
                if isfield(aliases, name)
                    target = aliases.(name);
                end
                if isfield(output, target)
                    output.(target) = supplied.(name);
                end
            end
        end

        function descriptors = normalizeDescriptors(raw, kind)
            if isempty(raw)
                descriptors = EventDetector_v3.emptyDescriptors();
                return;
            end
            if ~isstruct(raw)
                error('EventDetector_v3:InvalidDescriptors', ...
                    'Guard and stop callbacks must return structure arrays.');
            end
            prototype = EventDetector_v3.descriptorPrototype();
            descriptors = repmat(prototype, numel(raw), 1);
            fields = fieldnames(prototype);
            for k = 1:numel(raw)
                for j = 1:numel(fields)
                    field = fields{j};
                    if isfield(raw, field)
                        descriptors(k).(field) = raw(k).(field);
                    end
                end
                if isempty(descriptors(k).id)
                    descriptors(k).id = k;
                end
                if strlength(string(descriptors(k).name)) == 0
                    descriptors(k).name = kind + "_" + k;
                end
                if ~isfinite(descriptors(k).priority)
                    if isnumeric(descriptors(k).id) && isscalar(descriptors(k).id)
                        descriptors(k).priority = double(descriptors(k).id);
                    else
                        descriptors(k).priority = k;
                    end
                end
                descriptors(k).name = string(descriptors(k).name);
                descriptors(k).kind = string(descriptors(k).kind);
                if strlength(descriptors(k).kind) == 0
                    descriptors(k).kind = kind;
                end
                descriptors(k).enabled = logical(descriptors(k).enabled);
                descriptors(k).isterminal = logical(descriptors(k).isterminal);
                if ~isscalar(descriptors(k).value) || ...
                        ~isreal(descriptors(k).value)
                    error('EventDetector_v3:InvalidGuardValue', ...
                        'Each guard value must be a real scalar.');
                end
                if ~ismember(descriptors(k).direction, [-1, 0, 1])
                    error('EventDetector_v3:InvalidDirection', ...
                        'Guard directions must be -1, 0, or +1.');
                end
            end
            descriptors = descriptors([descriptors.enabled]);
            for k=1:numel(descriptors)
                for j=1:k-1
                    assert(~isequaln(descriptors(k).id,descriptors(j).id), ...
                        'EventDetector_v3:DuplicateIdentity','Enabled channels require distinct stable IDs within their guard/stop namespace.');
                end
            end
        end

        function ids=descriptorIds(descriptors)
            ids=cell(numel(descriptors),1);
            for k=1:numel(descriptors),ids{k}=descriptors(k).id;end
        end

        function ids=idList(value)
            if isempty(value),ids=cell(0,1);
            elseif iscell(value),ids=value(:);
            elseif ischar(value)||(isstring(value)&&isscalar(value)),ids={value};
            elseif isnumeric(value)||islogical(value)||isstring(value),ids=num2cell(value(:));
            else,ids={value};end
            for k=1:numel(ids)
                for j=1:k-1
                    assert(~isequaln(ids{k},ids{j}),'EventDetector_v3:DuplicateConsumedIdentity','A channel can be consumed only once in a restart.');
                end
            end
        end

        function requireOffered(ids,offered,kind)
            for k=1:numel(ids)
                assert(EventDetector_v3.hasId(offered,ids{k}), ...
                    'EventDetector_v3:UnreportedConsumedIdentity', ...
                    'Only actually reported %s channels may be marked consumed.',kind);
            end
        end

        function yes=hasId(ids,id)
            yes=false;
            for k=1:numel(ids),if isequaln(ids{k},id),yes=true;return;end,end
        end

        function at=findRow(rows,id)
            at=[];
            for k=1:numel(rows),if isequaln(rows{k}.descriptor.id,id),at=k;return;end,end
        end

        function same=sameStopCondition(left,right)
            % The supported scalar Function wrapper can hold an evaluate
            % object. Its handle must bind by identity, while the remaining
            % wrapper fields retain their existing exact structural contract.
            wrappedLeft=isstruct(left)&&isscalar(left)&&isfield(left,'Function');
            wrappedRight=isstruct(right)&&isscalar(right)&&isfield(right,'Function');
            if wrappedLeft&&wrappedRight
                same=EventDetector_v3.sameCollaborator(left.Function,right.Function) ...
                    &&isequaln(rmfield(left,'Function'),rmfield(right,'Function'));
            else
                same=EventDetector_v3.sameCollaborator(left,right);
            end
        end

        function same=sameCollaborator(left,right)
            % ISEQUALN compares handle property values, not object identity.
            % Direct struct/value-system users retain structural bindings.
            if isa(left,'handle')||isa(right,'handle')
                same=isa(left,'handle')&&isa(right,'handle') ...
                    &&isscalar(left)&&isscalar(right)&&strcmp(class(left),class(right));
                if same
                    same=left==right;
                    same=islogical(same)&&isscalar(same)&&same;
                end
            else
                same=isequaln(left,right);
            end
        end

        function same=sameChannel(left,right)
            same=isequaln(left.id,right.id)&&isequaln(left.direction,right.direction) ...
                &&isequaln(EventDetector_v3.interiorSign(left),EventDetector_v3.interiorSign(right)) ...
                &&isequaln(left.kind,right.kind)&&isequaln(left.isterminal,right.isterminal);
        end

        function declaration=geometry(descriptor,stateCount)
            declaration=[];
            if ~isstruct(descriptor.metadata)||~isscalar(descriptor.metadata) ...
                    ||~isfield(descriptor.metadata,'restart_arming'),return;end
            declaration=descriptor.metadata.restart_arming;
            fields={'schema';'definition';'state_dependencies';'mode_independent'};
            assert(isstruct(declaration)&&isscalar(declaration)&&isequal(sort(fieldnames(declaration)),sort(fields)) ...
                &&strcmp(declaration.schema,'state-parameter-guard-geometry-v1') ...
                &&ischar(declaration.definition)&&isrow(declaration.definition)&&~isempty(declaration.definition) ...
                &&isequal(declaration.mode_independent,true), ...
                'EventDetector_v3:GeometryDeclaration','A restart geometry declaration must identify a mode-independent state/parameter guard.');
            indices=declaration.state_dependencies;
            assert(isnumeric(indices)&&isreal(indices)&&~issparse(indices)&&(isvector(indices)||isempty(indices)) ...
                &&all(isfinite(indices))&&all(indices==fix(indices))&&all(indices>=1&indices<=stateCount) ...
                &&numel(unique(indices))==numel(indices), ...
                'EventDetector_v3:GeometryDependencies','Declare the complete finite state dependency index set.');
        end

        function yes=directedJump(before,after,direction)
            yes=false;if ~isfinite(before)||~isfinite(after),return;end
            if direction<0,yes=before>0&&after<=0;
            elseif direction>0,yes=before<0&&after>=0;
            else,yes=(before<0&&after>=0)||(before>0&&after<=0);end
        end

        function prototype = descriptorPrototype()
            prototype = struct( ...
                'id', [], ...
                'name', "", ...
                'value', NaN, ...
                'direction', 0, ...
                'isterminal', true, ...
                'priority', NaN, ...
                'enabled', true, ...
                'kind', "", ...
                'leg_index', [], ...
                'interior_sign', [], ...
                'directional_derivative', NaN, ...
                'metadata', struct());
        end

        function descriptors = emptyDescriptors()
            descriptors = repmat( ...
                EventDetector_v3.descriptorPrototype(), 0, 1);
        end

        function signs = descriptorDirections(descriptors)
            if isempty(descriptors)
                signs = zeros(0, 1);
            else
                signs = [descriptors.direction].';
            end
        end

        function signValue = interiorSign(descriptor)
            if ~isempty(descriptor.interior_sign) && ...
                    isfinite(descriptor.interior_sign) && ...
                    descriptor.interior_sign ~= 0
                signValue = sign(descriptor.interior_sign);
            elseif descriptor.direction ~= 0
                signValue = -sign(descriptor.direction);
            else
                signValue = 1;
            end
        end

        function index = findDescriptor(descriptors, id)
            index = [];
            for k = 1:numel(descriptors)
                if isequaln(descriptors(k).id, id)
                    index = k;
                    return;
                end
            end
        end

        function descriptors = sortDescriptors(descriptors)
            if numel(descriptors) < 2
                return;
            end
            priorities = [descriptors.priority].';
            orderIndex = (1:numel(descriptors)).';
            [~, order] = sortrows([priorities, orderIndex], [1, 2]);
            descriptors = descriptors(order);
        end

        function expanded = expandToSize(value, count)
            value = value(:);
            if isscalar(value)
                expanded = repmat(value, count, 1);
            elseif numel(value) == count
                expanded = value;
            else
                error('EventDetector_v3:StopOutputSizeMismatch', ...
                    'StopCondition outputs must have compatible sizes.');
            end
        end

        function descriptors = applyStopWrapper(descriptors, wrapper)
            for k = 1:numel(descriptors)
                if isfield(wrapper, 'name')
                    descriptors(k).name = string(wrapper.name);
                elseif isfield(wrapper, 'Name')
                    descriptors(k).name = string(wrapper.Name);
                end
                if isfield(wrapper, 'priority')
                    descriptors(k).priority = wrapper.priority;
                elseif isfield(wrapper, 'Priority')
                    descriptors(k).priority = wrapper.Priority;
                end
                if isfield(wrapper, 'id')
                    descriptors(k).id = wrapper.id;
                elseif isfield(wrapper, 'Id')
                    descriptors(k).id = wrapper.Id;
                end
            end
        end

        function tf = isTooManyOutputs(exception)
            tf = strcmp(exception.identifier, 'MATLAB:maxlhs') || ...
                contains(exception.message, 'Too many output arguments');
        end

        function event = noEvent(time, state)
            event = struct( ...
                'occurred', false, ...
                'time', time, ...
                'state', state, ...
                'guard_batch', EventDetector_v3.emptyDescriptors(), ...
                'stop_batch', EventDetector_v3.emptyDescriptors(), ...
                'stop_occurred', false, ...
                'triggered_channels', zeros(0, 1), ...
                'raw_event_times', zeros(0, 1), ...
                'raw_event_indices', zeros(0, 1));
        end
    end
end
