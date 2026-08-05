classdef PoincareMap_v3 < handle
    %POINCAREMAP_V3 First-return map of an event-driven hybrid system.
    %   The map is evaluated by replaying all state-triggered guards and
    %   resets.  No gait or event ordering is prescribed.

    properties
        System
        Section
        Simulator
        MaxReturnTime = 20
        ArmTolerance = 1e-7
        InitialTime = 0
    end

    methods
        function obj = PoincareMap_v3(system, section, simulator, options)
            if nargin < 3 || isempty(simulator)
                simulator = HybridSimulator_v3();
            end
            if nargin < 2 || isempty(section)
                error('PoincareMap_v3:MissingSection', ...
                    'A PoincareSection_v3 object is required.');
            end
            if nargin < 1 || isempty(system)
                error('PoincareMap_v3:MissingSystem', ...
                    'A HybridSystemBase_v3 object is required.');
            end
            obj.System = system;
            obj.Section = section;
            obj.Simulator = simulator;
            if nargin >= 4 && ~isempty(options)
                names = fieldnames(options);
                for i = 1:numel(names)
                    if ~isprop(obj, names{i})
                        error('PoincareMap_v3:UnknownOption', ...
                            'Unknown map option "%s".', names{i});
                    end
                    obj.(names{i}) = options.(names{i});
                end
            end
        end

        function [xNext, info] = evaluate(obj, x0, q0, p)
            %EVALUATE Return the next directional section crossing.
            x0 = x0(:);
            p = p(:);
            obj.System.validateState(x0);
            obj.System.validateParameter(p);
            obj.System.validateMode(q0);

            sectionState = obj.Section.project(x0, p);
            t0 = obj.InitialTime;
            if ~obj.Section.isValidCrossing( ...
                    t0, sectionState, q0, p, obj.System)
                error('PoincareMap_v3:InvalidInitialSection', ...
                    ['The initial state is not a transverse section point ', ...
                     'with the requested crossing direction.']);
            end

            direction = obj.Section.Direction;
            levels = [direction * obj.ArmTolerance, ...
                -direction * obj.ArmTolerance, 0];
            directions = [direction, -direction, direction];
            phaseNames = {'leave-initial-section', 'rearm-section', ...
                'return-to-section'};

            currentState = sectionState;
            currentMode = q0;
            currentTime = t0;
            combinedTrajectory = [];
            phaseResults = cell(1, 3);

            for phase = 1:3
                stop = obj.Section.stopCondition( ...
                    levels(phase), directions(phase));
                stop.name = phaseNames{phase};
                simulationOptions = struct( ...
                    'StopCondition', stop, ...
                    'ProcessGuardsAtStop', true);
                [part, result] = obj.Simulator.simulate( ...
                    obj.System, currentState, currentMode, p, ...
                    [currentTime, t0 + obj.MaxReturnTime], ...
                    simulationOptions);
                if isempty(combinedTrajectory)
                    combinedTrajectory = part;
                else
                    combinedTrajectory.appendTrajectory(part);
                end
                phaseResults{phase} = result;
                if ~result.stop_occurred
                    error('PoincareMap_v3:NoReturn', ...
                        'No %s crossing occurred before MaxReturnTime.', ...
                        phaseNames{phase});
                end
                currentTime = result.final_time;
                currentState = result.final_state(:);
                currentMode = result.final_mode;
            end

            if currentTime <= t0
                error('PoincareMap_v3:ZeroReturnTime', ...
                    'The section return time must be strictly positive.');
            end
            if ~obj.Section.isValidCrossing( ...
                    currentTime, currentState, currentMode, p, obj.System)
                error('PoincareMap_v3:InvalidReturnCrossing', ...
                    ['The returned state does not satisfy h(x,p)=0 with ', ...
                     'the requested transverse crossing direction.']);
            end

            rawReturnState = currentState;
            xNext = obj.System.canonicalizeState(rawReturnState, p);
            canonicalInitial = obj.System.canonicalizeState(sectionState, p);

            info = struct();
            info.period = currentTime - t0;
            info.initial_time = t0;
            info.return_time = currentTime;
            info.initial_state = sectionState;
            info.raw_return_state = rawReturnState;
            info.poincare_state = xNext;
            info.initial_mode = q0;
            info.final_mode = currentMode;
            info.discrete_closed = isequal(q0, currentMode);
            info.trajectory = combinedTrajectory;
            hybridHistory = combinedTrajectory.event_history;
            if ~isempty(hybridHistory) && isfield(hybridHistory, 'is_stop')
                hybridHistory = hybridHistory(~[hybridHistory.is_stop]);
            end
            info.event_history = hybridHistory;
            info.event_sequence = reshape(string({hybridHistory.type}), [], 1);
            info.event_times = reshape([hybridHistory.time], [], 1) - t0;
            info.mode_sequence = obj.buildModeSequence( ...
                q0, hybridHistory);
            info.phase_results = phaseResults;
            info.stride_displacement = rawReturnState - sectionState;
            info.canonical_displacement = xNext - canonicalInitial;
        end

        function [coordinatesNext, info] = evaluateCoordinates( ...
                obj, coordinates, templateState, coordinateIndices, q, p)
            %EVALUATECOORDINATES Evaluate the map in a section chart.
            state = templateState(:);
            coordinates = coordinates(:);
            if numel(coordinates) ~= numel(coordinateIndices)
                error('PoincareMap_v3:CoordinateDimension', ...
                    'Coordinate vector and coordinate index count differ.');
            end
            state(coordinateIndices) = coordinates;
            state = obj.Section.project(state, p);
            [nextState, info] = obj.evaluate(state, q, p);
            coordinatesNext = nextState(coordinateIndices);
        end
    end

    methods (Static, Access = private)
        function modes = buildModeSequence(initialMode, history)
            modes = {initialMode};
            for i = 1:numel(history)
                if isfield(history, 'mode_after')
                    modes{end + 1, 1} = history(i).mode_after; %#ok<AGROW>
                end
            end
        end
    end
end
