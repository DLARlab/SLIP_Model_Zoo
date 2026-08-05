classdef HybridSimulator_v3
    %HYBRIDSIMULATOR_V3 Event-driven simulator for general hybrid systems.
    %
    % [TRAJECTORY, RESULT] = SIMULATE(OBJ, SYSTEM, X0, Q0, P, TSPAN,
    % OPTIONS) repeatedly integrates SYSTEM.FLOW in the current mode,
    % locates the earliest active guard, applies simultaneous resets and
    % transitions in priority order, and restarts in the new mode.

    properties (SetAccess = private)
        Options
    end

    methods
        function obj = HybridSimulator_v3(options)
            if nargin < 1
                options = struct();
            end
            obj.Options = HybridSimulator_v3.mergeOptions( ...
                HybridSimulator_v3.defaultOptions(), options);
        end

        function [trajectory, result] = simulate(obj, system, x0, q0, p, ...
                tspan, options)
            if nargin < 7 || isempty(options)
                options = struct();
            end
            simulationOptions = HybridSimulator_v3.mergeOptions( ...
                obj.Options, options);
            HybridSimulator_v3.validateSystem(system);
            validateattributes(tspan, {'numeric'}, ...
                {'vector', 'numel', 2, 'real', 'finite'});
            tspan = tspan(:).';
            if tspan(2) <= tspan(1)
                error('HybridSimulator_v3:InvalidTimeSpan', ...
                    'TSPAN must contain increasing start and final times.');
            end
            x0 = x0(:);
            if isempty(x0) || any(~isfinite(x0))
                error('HybridSimulator_v3:InvalidInitialState', ...
                    'X0 must be a nonempty finite state vector.');
            end

            detector = EventDetector_v3(simulationOptions);
            stopCondition = simulationOptions.StopCondition;
            odeOptions = simulationOptions.ODEOptions;

            currentTime = tspan(1);
            finalTime = tspan(2);
            currentState = x0;
            currentMode = q0;
            trajectory = Trajectory_v3(currentTime, currentState.', currentMode);

            eventCount = 0;
            batchCount = 0;
            zeroAdvanceCount = 0;
            stopOccurred = false;
            stopRecord = struct();
            reason = "not_terminated";
            message = "";

            while currentTime < finalTime - ...
                    HybridSimulator_v3.timeTolerance(currentTime, ...
                        simulationOptions)
                [segment, event] = detector.integrate(system, currentState, ...
                    currentMode, p, [currentTime, finalTime], ...
                    stopCondition, odeOptions);
                trajectory.appendSegment(segment.time, segment.state, currentMode);

                if ~event.occurred
                    currentTime = segment.time(end);
                    currentState = segment.state(end, :).';
                    reason = "final_time";
                    message = "The requested final time was reached.";
                    break;
                end

                batchCount = batchCount + 1;
                eventState = event.state(:);
                eventTime = event.time;
                advanceTolerance = HybridSimulator_v3.timeTolerance( ...
                    currentTime, simulationOptions);
                if eventTime <= currentTime + advanceTolerance
                    zeroAdvanceCount = zeroAdvanceCount + 1;
                else
                    zeroAdvanceCount = 0;
                end

                if batchCount > simulationOptions.MaxEventBatches
                    currentTime = eventTime;
                    currentState = eventState;
                    reason = "maximum_event_batches";
                    message = "Maximum number of hybrid event batches exceeded.";
                    break;
                end
                if zeroAdvanceCount > simulationOptions.MaxZeroTimeEvents
                    currentTime = eventTime;
                    currentState = eventState;
                    reason = "zeno_detected";
                    message = ["Too many consecutive events occurred without ", ...
                        "a resolved positive time advance."];
                    break;
                end

                currentTime = eventTime;
                currentState = eventState;

                stopFirst = event.stop_occurred && ...
                    ~simulationOptions.ProcessGuardsAtStop;
                if ~stopFirst
                    guardBatch = event.guard_batch;
                    for k = 1:numel(guardBatch)
                        descriptor = guardBatch(k);
                        stateBefore = currentState;
                        modeBefore = currentMode;
                        stateAfter = system.reset(descriptor.id, currentTime, ...
                            stateBefore, modeBefore, p);
                        stateAfter = stateAfter(:);
                        if numel(stateAfter) ~= numel(stateBefore) || ...
                                any(~isfinite(stateAfter))
                            error('HybridSimulator_v3:InvalidReset', ...
                                ['SYSTEM.RESET must return a finite state ', ...
                                 'with unchanged dimension.']);
                        end
                        modeAfter = system.transition(descriptor.id, modeBefore);

                        entry = HybridSimulator_v3.makeEventEntry( ...
                            descriptor, currentTime, stateBefore, stateAfter, ...
                            modeBefore, modeAfter, false);
                        trajectory.recordEvent(entry);
                        trajectory.appendSample(currentTime, stateAfter.', modeAfter);

                        currentState = stateAfter;
                        currentMode = modeAfter;
                        eventCount = eventCount + 1;
                        if eventCount >= simulationOptions.MaxEvents
                            reason = "maximum_events";
                            message = "Maximum number of hybrid events reached.";
                            break;
                        end
                    end
                    if reason == "maximum_events"
                        break;
                    end
                end

                if event.stop_occurred
                    stopOccurred = true;
                    stopBatch = event.stop_batch;
                    if isempty(stopBatch)
                        stopBatch = HybridSimulator_v3.defaultStopDescriptor();
                    end
                    for k = 1:numel(stopBatch)
                        descriptor = stopBatch(k);
                        entry = HybridSimulator_v3.makeEventEntry( ...
                            descriptor, currentTime, currentState, currentState, ...
                            currentMode, currentMode, true);
                        if simulationOptions.RecordStopEvent
                            trajectory.recordEvent(entry);
                        end
                        if k == 1
                            stopRecord = entry;
                        end
                    end
                    reason = "stop_condition";
                    message = "The requested stopping condition was reached.";
                    break;
                end

                if isempty(event.guard_batch)
                    reason = "unresolved_event";
                    message = ["The ODE solver reported an event, but no active ", ...
                        "guard passed clustering checks."];
                    break;
                end
            end

            if reason == "not_terminated"
                if currentTime >= finalTime - ...
                        HybridSimulator_v3.timeTolerance(finalTime, ...
                            simulationOptions)
                    reason = "final_time";
                    message = "The requested final time was reached.";
                else
                    reason = "terminated";
                end
            end

            success = ismember(reason, ["final_time", "stop_condition"]);
            terminationMetadata = struct( ...
                'success', success, ...
                'message', message, ...
                'stop_occurred', stopOccurred, ...
                'event_count', eventCount, ...
                'event_batch_count', batchCount, ...
                'zero_advance_count', zeroAdvanceCount);
            trajectory.setTermination(reason, currentTime, currentState, ...
                currentMode, terminationMetadata);
            trajectory.metadata.event_count = eventCount;
            trajectory.metadata.event_batch_count = batchCount;

            result = struct( ...
                'success', success, ...
                'termination_reason', reason, ...
                'message', message, ...
                'stop_occurred', stopOccurred, ...
                'stop_event', stopRecord, ...
                'reached_final_time', reason == "final_time", ...
                'final_time', currentTime, ...
                'final_state', currentState, ...
                'final_mode', currentMode, ...
                'event_count', eventCount, ...
                'event_batch_count', batchCount, ...
                'event_history', trajectory.event_history);
        end
    end

    methods (Static, Access = private)
        function options = defaultOptions()
            options = struct( ...
                'StopCondition', [], ...
                'ProcessGuardsAtStop', false, ...
                'RecordStopEvent', true, ...
                'MaxEvents', 1000, ...
                'MaxEventBatches', 1000, ...
                'MaxZeroTimeEvents', 32, ...
                'ODEOptions', odeset(), ...
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
                error('HybridSimulator_v3:InvalidOptions', ...
                    'OPTIONS must be a scalar structure.');
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
                % Unknown extension fields are intentionally preserved for
                % detector and stopping-condition collaborators.
                output.(target) = supplied.(name);
            end
            validateattributes(output.MaxEvents, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            validateattributes(output.MaxEventBatches, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            validateattributes(output.MaxZeroTimeEvents, {'numeric'}, ...
                {'scalar', 'integer', 'nonnegative'});
        end

        function validateSystem(system)
            required = {'flow', 'activeGuards', 'reset', 'transition'};
            for k = 1:numel(required)
                if ~ismethod(system, required{k})
                    error('HybridSimulator_v3:InvalidSystem', ...
                        'SYSTEM must implement the %s method.', required{k});
                end
            end
        end

        function entry = makeEventEntry(descriptor, time, stateBefore, ...
                stateAfter, modeBefore, modeAfter, isStop)
            metadata = struct();
            if isfield(descriptor, 'metadata')
                metadata = descriptor.metadata;
            end
            guardName = string(descriptor.name);
            entry = struct( ...
                'index', 0, ...
                'type', guardName, ...
                'time', time, ...
                'guard_id', descriptor.id, ...
                'guard_name', guardName, ...
                'state_before', stateBefore, ...
                'state_after', stateAfter, ...
                'mode_before', modeBefore, ...
                'mode_after', modeAfter, ...
                'value', descriptor.value, ...
                'directional_derivative', ...
                    descriptor.directional_derivative, ...
                'priority', descriptor.priority, ...
                'is_stop', logical(isStop), ...
                'metadata', metadata);
        end

        function descriptor = defaultStopDescriptor()
            descriptor = struct( ...
                'id', 1, 'name', "stop", 'value', 0, ...
                'direction', 0, 'isterminal', true, ...
                'priority', -Inf, 'enabled', true, 'kind', "stop", ...
                'leg_index', [], 'interior_sign', [], ...
                'directional_derivative', NaN, 'metadata', struct());
        end

        function tolerance = timeTolerance(time, options)
            tolerance = max(options.EventTimeTolerance, ...
                64 * eps(max(1, abs(time))));
        end
    end
end
