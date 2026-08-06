classdef PoincareMap_v3 < handle
    %POINCAREMAP_V3 Policy-selected return map of a hybrid system.
    %   The geometric section, detection of its directional crossings, and
    %   acceptance of a completed return are deliberately separate. Contact
    %   guards are replayed by HybridSimulator_v3; no gait, event order, leg
    %   count, or required section mode is encoded in this class.

    properties
        System
        Section
        Simulator
        ReturnPolicy
        ModeResolver
        MaxReturnTime = 20
        MaxSectionCrossings = 32
        MaxCycleEvents = 1000
        ArmTolerance = 1e-7
        InitialTime = 0
    end

    properties (SetAccess = private)
        ReturnPolicyWasExplicit = false
    end

    methods
        function obj = PoincareMap_v3( ...
                system, section, simulator, returnPolicyOrOptions, options)
            % Supported forms:
            %   PoincareMap_v3(system,section,simulator)
            %   PoincareMap_v3(system,section,simulator,options)
            %   PoincareMap_v3(system,section,simulator,returnPolicy)
            %   PoincareMap_v3(system,section,simulator,returnPolicy,options)
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
            obj.ReturnPolicy = FirstReturnPolicy_v3();
            obj.ModeResolver = SectionModeResolver_v3();

            suppliedOptions = struct();
            if nargin >= 4 && ~isempty(returnPolicyOrOptions)
                if isa(returnPolicyOrOptions, 'ReturnPolicyBase_v3')
                    obj.ReturnPolicy = returnPolicyOrOptions;
                    obj.ReturnPolicyWasExplicit = true;
                elseif isstruct(returnPolicyOrOptions)
                    suppliedOptions = returnPolicyOrOptions;
                else
                    error('PoincareMap_v3:InvalidFourthInput', ...
                        ['The fourth input must be a ReturnPolicyBase_v3 ', ...
                         'object or an options structure.']);
                end
            end
            if nargin >= 5 && ~isempty(options)
                suppliedOptions = PoincareMap_v3.mergeStructs( ...
                    suppliedOptions, options);
            end
            obj.applyOptions(suppliedOptions);
            obj.validateConfiguration();
        end

        function [xNext, info] = evaluate(obj, x0, q0, p, evaluationOptions)
            %EVALUATE Integrate until ReturnPolicy accepts a section crossing.
            if nargin < 5 || isempty(evaluationOptions)
                evaluationOptions = struct();
            end
            simulationOverrides = obj.evaluationSimulationOptions( ...
                evaluationOptions);
            x0 = obj.System.validateState(x0(:));
            p = obj.System.validateParameter(p(:));
            q0 = obj.System.validateMode(q0);

            sectionState = obj.Section.project(x0, p);
            t0 = obj.InitialTime;
            if ~obj.Section.isValidCrossing( ...
                    t0, sectionState, q0, p, obj.System)
                error('PoincareMap_v3:InvalidInitialSection', ...
                    ['The initial state is not a transverse section point ', ...
                     'with the requested crossing direction.']);
            end

            context = struct('initial_time', t0, ...
                'initial_state', sectionState, 'parameter', p, ...
                'section_name', obj.Section.Name);
            policyState = obj.ReturnPolicy.initialize(q0, context);
            deadline = t0 + obj.MaxReturnTime;
            currentState = sectionState;
            currentMode = q0;
            currentTime = t0;
            combinedTrajectory = [];
            crossings = repmat(PoincareMap_v3.crossingPrototype(), 0, 1);
            phaseResultBuffer = cell(3 * obj.MaxSectionCrossings, 1);
            phaseResultCount = 0;
            accepted = false;
            acceptedDiagnostics = struct();

            for crossingIndex = 1:obj.MaxSectionCrossings
                physicalSoFar = PoincareMap_v3.physicalHistory( ...
                    PoincareMap_v3.historyOf(combinedTrajectory));
                remainingEvents = obj.MaxCycleEvents - numel(physicalSoFar);
                if remainingEvents <= 0
                    error('PoincareMap_v3:MaxCycleEvents', ...
                        ['Return policy was not satisfied before ', ...
                         'MaxCycleEvents=%d.'], obj.MaxCycleEvents);
                end

                [part, crossing] = obj.nextSectionCrossing( ...
                    currentState, currentMode, currentTime, p, deadline, ...
                    remainingEvents, crossingIndex, simulationOverrides);
                if isempty(combinedTrajectory)
                    combinedTrajectory = part;
                else
                    combinedTrajectory.appendTrajectory(part);
                end
                phaseIndices = phaseResultCount + (1:3);
                phaseResultBuffer(phaseIndices) = crossing.phase_results(:);
                phaseResultCount = phaseResultCount + 3;

                cumulativeHistory = PoincareMap_v3.physicalHistory( ...
                    combinedTrajectory.event_history);
                if numel(cumulativeHistory) > obj.MaxCycleEvents
                    error('PoincareMap_v3:MaxCycleEvents', ...
                        'A return trial exceeded MaxCycleEvents=%d.', ...
                        obj.MaxCycleEvents);
                end
                incrementalHistory = PoincareMap_v3.physicalHistory( ...
                    part.event_history);
                sectionDerivative = obj.Section.derivative( ...
                    crossing.time, crossing.state, crossing.mode, p, obj.System);
                sectionCoincident = obj.eventsAtTime( ...
                    incrementalHistory, crossing.time);
                sectionSignature = obj.eventSignature(cumulativeHistory, false);
                cyclicSignature = obj.eventSignature(cumulativeHistory, true);

                candidate = PoincareMap_v3.crossingPrototype();
                candidate.index = crossingIndex;
                candidate.time = crossing.time;
                candidate.period = crossing.time - t0;
                candidate.initial_mode = q0;
                candidate.state = crossing.state;
                candidate.canonical_state = obj.System.canonicalizeState( ...
                    crossing.state, p);
                candidate.mode = crossing.mode;
                candidate.discrete_closed = PoincareMap_v3.modeEquals( ...
                    q0, crossing.mode);
                candidate.section_derivative = sectionDerivative;
                candidate.section_transversality = abs(sectionDerivative);
                candidate.incremental_event_history = incrementalHistory;
                candidate.event_history = cumulativeHistory;
                candidate.incremental_event_count = numel(incrementalHistory);
                candidate.event_count = numel(cumulativeHistory);
                candidate.section_relative_event_signature = sectionSignature;
                candidate.cyclic_event_signature = cyclicSignature;
                candidate.section_coincident_events = sectionCoincident;
                candidate.guard_transversality_margins = ...
                    PoincareMap_v3.guardMargins(cumulativeHistory);
                candidate.phase_results = crossing.phase_results;
                candidate.incremental_trajectory = part;

                [accepted, policyState, policyDiagnostics] = ...
                    obj.ReturnPolicy.assess(candidate, policyState);
                candidate.accepted = accepted;
                candidate.policy_diagnostics = policyDiagnostics;
                crossings(end + 1, 1) = candidate; %#ok<AGROW>

                if accepted
                    acceptedDiagnostics = policyDiagnostics;
                    break
                end
                currentState = crossing.state;
                currentMode = crossing.mode;
                currentTime = crossing.time;
            end

            if ~accepted
                reason = 'policy did not accept any candidate';
                if ~isempty(crossings) && ...
                        isfield(crossings(end).policy_diagnostics, 'reason')
                    reason = crossings(end).policy_diagnostics.reason;
                end
                error('PoincareMap_v3:MaxSectionCrossings', ...
                    ['Return policy "%s" was not satisfied within %d ', ...
                     'section crossings: %s.'], obj.ReturnPolicy.Name, ...
                    obj.MaxSectionCrossings, reason);
            end

            acceptedCrossing = crossings(end);
            rawReturnState = acceptedCrossing.state;
            xNext = acceptedCrossing.canonical_state;
            canonicalInitial = obj.System.canonicalizeState(sectionState, p);
            hybridHistory = acceptedCrossing.event_history;
            returnMultiplicity = acceptedCrossing.index;
            if isfield(acceptedDiagnostics, 'return_multiplicity')
                returnMultiplicity = acceptedDiagnostics.return_multiplicity;
            end

            info = struct();
            info.period = acceptedCrossing.period;
            info.accepted_period = acceptedCrossing.period;
            info.return_multiplicity = returnMultiplicity;
            info.initial_time = t0;
            info.return_time = acceptedCrossing.time;
            info.initial_state = sectionState;
            info.raw_return_state = rawReturnState;
            info.poincare_state = xNext;
            info.initial_mode = q0;
            info.final_mode = acceptedCrossing.mode;
            info.discrete_closed = acceptedCrossing.discrete_closed;
            info.trajectory = combinedTrajectory;
            info.event_history = hybridHistory;
            info.event_sequence = reshape(string({hybridHistory.type}), [], 1);
            info.event_times = reshape([hybridHistory.time], [], 1) - t0;
            info.mode_sequence = PoincareMap_v3.buildModeSequence( ...
                q0, hybridHistory);
            info.phase_results = phaseResultBuffer(1:phaseResultCount);
            info.minimum_stance_admissibility_margin = ...
                PoincareMap_v3.minimumAdmissibilityMargin( ...
                    info.phase_results);
            info.stance_force_admissibility_margin = ...
                info.minimum_stance_admissibility_margin;
            info.stride_displacement = rawReturnState - sectionState;
            info.canonical_displacement = xNext - canonicalInitial;
            info.return_policy = class(obj.ReturnPolicy);
            info.return_policy_name = obj.ReturnPolicy.Name;
            info.return_policy_was_explicit = obj.ReturnPolicyWasExplicit;
            info.candidate_section_crossings = crossings;
            info.all_candidate_section_crossings = crossings;
            info.accepted_crossing_index = acceptedCrossing.index;
            info.section_relative_event_signature = ...
                acceptedCrossing.section_relative_event_signature;
            info.cyclic_event_signature = ...
                acceptedCrossing.cyclic_event_signature;
            info.cyclically_canonical_event_signature = ...
                acceptedCrossing.cyclic_event_signature;
            info.section_coincident_events = ...
                acceptedCrossing.section_coincident_events;
            info.cycle_completion_diagnostics = acceptedDiagnostics;
            info.policy_state = policyState;
            info.event_counts_per_leg = struct([]);
            if isfield(acceptedDiagnostics, 'event_counts_per_leg')
                info.event_counts_per_leg = ...
                    acceptedDiagnostics.event_counts_per_leg;
            end
            info.guard_transversality_margins = ...
                acceptedCrossing.guard_transversality_margins;
            info.minimum_guard_transversality = ...
                PoincareMap_v3.minimumGuardMargin( ...
                    acceptedCrossing.guard_transversality_margins);
            info.section_transversality = ...
                acceptedCrossing.section_transversality;
            info.success = true;
            info.valid = true;
            info.admissible = true;
            info.integration_success = true;
            info.return_policy_accepted = true;
            info.cycle_complete = logical(PoincareMap_v3.memberOr( ...
                acceptedDiagnostics, 'complete', true));
            info.evaluation_options = evaluationOptions;
            info.integration_overrides = simulationOverrides;
            info.minimum_event_time_separation = ...
                PoincareMap_v3.minimumEventSeparation(hybridHistory);
            info.minimum_section_event_time_separation = ...
                PoincareMap_v3.minimumSectionEventSeparation( ...
                    hybridHistory, t0, acceptedCrossing.time);
            info.topology_margins = struct( ...
                'guard_transversality', ...
                    info.minimum_guard_transversality, ...
                'section_transversality', info.section_transversality, ...
                'event_time_separation', ...
                    info.minimum_event_time_separation, ...
                'section_event_separation', ...
                    info.minimum_section_event_time_separation, ...
                'stance_force', ...
                    info.minimum_stance_admissibility_margin, ...
                'stance_force_admissibility', ...
                    info.minimum_stance_admissibility_margin, ...
                'section_event_coincidence_count', ...
                    numel(info.section_coincident_events));
            info.event_counts = info.event_counts_per_leg;
            info.schema_metadata = obj.systemSchemaMetadata();
        end

        function [xNext, info] = evaluateWithOptions( ...
                obj, x0, q0, p, evaluationOptions)
            %EVALUATEWITHOPTIONS Explicit context-aware evaluation alias.
            [xNext, info] = obj.evaluate(x0, q0, p, evaluationOptions);
        end

        function [coordinatesNext, info] = evaluateCoordinates( ...
                obj, coordinates, templateState, coordinateIndices, q, p)
            %EVALUATECOORDINATES Evaluate the accepted map in a section chart.
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

        function [modes, diagnostics] = modeCandidates(obj, x, q, p)
            %MODECANDIDATES Resolve only local section-adjacent charts.
            x = obj.Section.project(x, p);
            [modes, diagnostics] = obj.ModeResolver.resolve( ...
                obj.System, obj.Section, x, q, p, obj.InitialTime);
        end

        function [modes, diagnostics] = resolveSectionModes(obj, x, q, p)
            [modes, diagnostics] = obj.modeCandidates(x, q, p);
        end

        function [modes, diagnostics] = allModes(obj, x, q, p)
            %ALLMODES Explicit exhaustive/debugging search, never the default.
            x = obj.Section.project(x, p);
            [modes, diagnostics] = obj.ModeResolver.allModes( ...
                obj.System, x, q, p);
        end
    end

    methods (Access = private)
        function [trajectory, crossing] = nextSectionCrossing( ...
                obj, startState, startMode, startTime, p, deadline, ...
                remainingEvents, crossingIndex, simulationOverrides)
            %NEXTSECTIONCROSSING Leave, rearm, and return to the section.
            if startTime >= deadline
                error('PoincareMap_v3:MaxReturnTime', ...
                    'MaxReturnTime was reached before a new section crossing.');
            end
            direction = obj.Section.Direction;
            levels = [direction * obj.ArmTolerance, ...
                -direction * obj.ArmTolerance, 0];
            directions = [direction, -direction, direction];
            phaseNames = {'leave-initial-section', 'rearm-section', ...
                'return-to-section'};

            currentState = startState;
            currentMode = startMode;
            currentTime = startTime;
            trajectory = [];
            phaseResults = cell(3, 1);
            eventsUsed = 0;

            for phase = 1:3
                stop = obj.Section.stopCondition( ...
                    levels(phase), directions(phase));
                stop.name = sprintf('%s-%d', phaseNames{phase}, crossingIndex);
                % One spare event lets a guard at the accepted section be
                % processed before the stop record when the global count is
                % exactly MaxCycleEvents. The global count is checked below.
                localLimit = max(1, remainingEvents - eventsUsed + 1);
                simulationOptions = simulationOverrides;
                simulationOptions.StopCondition = stop;
                simulationOptions.ProcessGuardsAtStop = true;
                simulationOptions.MaxEvents = localLimit;
                [part, result] = obj.Simulator.simulate( ...
                    obj.System, currentState, currentMode, p, ...
                    [currentTime, deadline], simulationOptions);
                if isempty(trajectory)
                    trajectory = part;
                else
                    trajectory.appendTrajectory(part);
                end
                phaseResults{phase} = result;
                eventsUsed = numel(PoincareMap_v3.physicalHistory( ...
                    trajectory.event_history));
                if eventsUsed > remainingEvents
                    error('PoincareMap_v3:MaxCycleEvents', ...
                        'A return trial exceeded MaxCycleEvents.');
                end
                if ~result.stop_occurred
                    if result.termination_reason == "maximum_events"
                        error('PoincareMap_v3:MaxCycleEvents', ...
                            ['No %s crossing occurred before the remaining ', ...
                             'cycle-event budget was exhausted.'], ...
                            phaseNames{phase});
                    end
                    error('PoincareMap_v3:NoReturn', ...
                        ['No %s crossing for candidate %d occurred before ', ...
                         'MaxReturnTime.'], phaseNames{phase}, crossingIndex);
                end
                currentTime = result.final_time;
                currentState = result.final_state(:);
                currentMode = result.final_mode;
            end

            if currentTime <= startTime
                error('PoincareMap_v3:ZeroReturnTime', ...
                    'The next section-crossing time must be strictly positive.');
            end
            if ~obj.Section.isValidCrossing( ...
                    currentTime, currentState, currentMode, p, obj.System)
                error('PoincareMap_v3:InvalidReturnCrossing', ...
                    ['The returned right-continuous state does not satisfy ', ...
                     'the requested transverse section crossing.']);
            end
            crossing = struct('time', currentTime, ...
                'state', currentState, 'mode', currentMode, ...
                'phase_results', {phaseResults});
        end

        function applyOptions(obj, options)
            if isempty(options)
                return
            end
            if ~isstruct(options) || ~isscalar(options)
                error('PoincareMap_v3:InvalidOptions', ...
                    'Map options must be a scalar structure.');
            end
            names = fieldnames(options);
            for i = 1:numel(names)
                name = names{i};
                if ~isprop(obj, name)
                    error('PoincareMap_v3:UnknownOption', ...
                        'Unknown map option "%s".', name);
                end
                if strcmp(name, 'ReturnPolicy')
                    obj.ReturnPolicyWasExplicit = true;
                end
                obj.(name) = options.(name);
            end
        end

        function validateConfiguration(obj)
            if ~isa(obj.ReturnPolicy, 'ReturnPolicyBase_v3')
                error('PoincareMap_v3:InvalidReturnPolicy', ...
                    'ReturnPolicy must derive from ReturnPolicyBase_v3.');
            end
            if ~isa(obj.ModeResolver, 'SectionModeResolver_v3')
                error('PoincareMap_v3:InvalidModeResolver', ...
                    'ModeResolver must be a SectionModeResolver_v3 object.');
            end
            validateattributes(obj.MaxReturnTime, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'positive'});
            validateattributes(obj.MaxSectionCrossings, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            validateattributes(obj.MaxCycleEvents, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            validateattributes(obj.ArmTolerance, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'positive'});
            validateattributes(obj.InitialTime, {'numeric'}, ...
                {'scalar', 'real', 'finite'});
        end

        function overrides = evaluationSimulationOptions(obj, context)
            if ~isstruct(context) || ~isscalar(context)
                error('PoincareMap_v3:InvalidEvaluationOptions', ...
                    'Evaluation options/context must be a scalar structure.');
            end
            overrides = struct();
            if isfield(context, 'SimulationOptions')
                if ~isstruct(context.SimulationOptions) ...
                        || ~isscalar(context.SimulationOptions)
                    error('PoincareMap_v3:InvalidEvaluationOptions', ...
                        'SimulationOptions must be a scalar structure.');
                end
                overrides = context.SimulationOptions;
            end
            copied = {'RelTol', 'AbsTol', 'ODEOptions', 'MaxStep'};
            for i = 1:numel(copied)
                if isfield(context, copied{i})
                    overrides.(copied{i}) = context.(copied{i});
                end
            end
            if isfield(context, 'suggestedRelativeTolerance') ...
                    && ~isempty(context.suggestedRelativeTolerance)
                suggested = context.suggestedRelativeTolerance;
                isBaselineMarker = isnumeric(suggested) ...
                    && isreal(suggested) && isscalar(suggested) ...
                    && isnan(suggested);
                if ~isBaselineMarker
                    validateattributes(suggested, {'numeric'}, ...
                        {'scalar', 'real', 'finite', 'positive'});
                    baseRelTol = obj.Simulator.Options.RelTol;
                    baseAbsTol = obj.Simulator.Options.AbsTol;
                    if isfield(overrides, 'RelTol')
                        baseRelTol = overrides.RelTol;
                    end
                    if isfield(overrides, 'AbsTol')
                        baseAbsTol = overrides.AbsTol;
                    end
                    overrides.RelTol = min( ...
                        baseRelTol, max(1e-13, suggested));
                    overrides.AbsTol = min(baseAbsTol, ...
                        max(1e-15, 0.1 * overrides.RelTol));
                end
            end
            if isfield(overrides, 'RelTol')
                validateattributes(overrides.RelTol, {'numeric'}, ...
                    {'scalar', 'real', 'finite', 'positive'});
            end
            if isfield(overrides, 'AbsTol')
                validateattributes(overrides.AbsTol, {'numeric'}, ...
                    {'real', 'finite', 'positive'});
            end
        end

        function metadata = systemSchemaMetadata(obj)
            metadata = struct();
            if ismethod(obj.System, 'schemaMetadata')
                metadata = obj.System.schemaMetadata();
            elseif isprop(obj.System, 'Schema') ...
                    && isobject(obj.System.Schema) ...
                    && ismethod(obj.System.Schema, 'metadata')
                metadata = obj.System.Schema.metadata();
            end
        end

        function events = eventsAtTime(obj, history, time)
            if isempty(history)
                events = history;
                return
            end
            tolerance = obj.eventTimeTolerance(time);
            events = history(abs([history.time] - time) <= tolerance);
        end

        function signature = eventSignature(obj, history, cyclic)
            if isempty(history)
                signature = "";
                return
            end
            tokenBuffer = strings(numel(history), 1);
            tokenCount = 0;
            group = strings(0, 1);
            groupTime = NaN;
            for i = 1:numel(history)
                name = PoincareMap_v3.eventName(history(i));
                if isempty(group) || abs(history(i).time - groupTime) ...
                        <= obj.eventTimeTolerance(history(i).time)
                    group(end + 1, 1) = name; %#ok<AGROW>
                    if isnan(groupTime)
                        groupTime = history(i).time;
                    end
                else
                    tokenCount = tokenCount + 1;
                    tokenBuffer(tokenCount) = strjoin(sort(group), "&");
                    group = name;
                    groupTime = history(i).time;
                end
            end
            tokenCount = tokenCount + 1;
            tokenBuffer(tokenCount) = strjoin(sort(group), "&");
            tokens = tokenBuffer(1:tokenCount);
            if ~cyclic || numel(tokens) <= 1
                signature = strjoin(tokens, ">");
                return
            end
            rotations = strings(numel(tokens), 1);
            for i = 1:numel(tokens)
                rotation = [tokens(i:end); tokens(1:i-1)];
                rotations(i) = strjoin(rotation, ">");
            end
            [~, order] = sort(lower(rotations));
            signature = rotations(order(1));
        end

        function tolerance = eventTimeTolerance(obj, time)
            tolerance = 1e-10;
            if isprop(obj.Simulator, 'Options') ...
                    && isfield(obj.Simulator.Options, 'EventTimeTolerance')
                tolerance = obj.Simulator.Options.EventTimeTolerance;
            end
            tolerance = max(tolerance, 128 * eps(max(1, abs(time))));
        end
    end

    methods (Static, Access = private)
        function history = historyOf(trajectory)
            if isempty(trajectory)
                history = struct([]);
            else
                history = trajectory.event_history;
            end
        end

        function history = physicalHistory(history)
            if ~isempty(history) && isfield(history, 'is_stop')
                history = history(~[history.is_stop]);
            end
        end

        function margins = guardMargins(history)
            if isempty(history) || ~isfield(history, 'directional_derivative')
                margins = zeros(0, 1);
                return
            end
            margins = abs(reshape([history.directional_derivative], [], 1));
        end

        function value = minimumGuardMargin(values)
            if isempty(values)
                value = Inf;
            elseif any(~isfinite(values))
                value = NaN;
            else
                value = min(values);
            end
        end

        function margin = minimumAdmissibilityMargin(results)
            margin = Inf;
            for index = 1:numel(results)
                result = results{index};
                if isstruct(result) && isfield(result, ...
                        'minimum_stance_admissibility_margin')
                    margin = min(margin, ...
                        result.minimum_stance_admissibility_margin);
                end
            end
        end

        function value = minimumEventSeparation(history)
            if numel(history) < 2
                value = Inf;
                return
            end
            differences = abs(diff(reshape([history.time], [], 1)));
            value = min(differences);
        end

        function value = minimumSectionEventSeparation(history, ...
                initialTime, returnTime)
            if isempty(history)
                value = Inf;
                return
            end
            times = reshape([history.time], [], 1);
            value = min([abs(times - initialTime); ...
                abs(times - returnTime)]);
        end

        function value = memberOr(source, name, fallback)
            if isstruct(source) && isfield(source, name)
                value = source.(name);
            else
                value = fallback;
            end
        end

        function modes = buildModeSequence(initialMode, history)
            modes = {initialMode};
            for i = 1:numel(history)
                if isfield(history, 'mode_after')
                    modes{end + 1, 1} = history(i).mode_after; %#ok<AGROW>
                end
            end
        end

        function tf = modeEquals(left, right)
            if isnumeric(left) || islogical(left)
                tf = (isnumeric(right) || islogical(right)) ...
                    && isequal(double(left(:)), double(right(:)));
            else
                tf = isequal(left, right);
            end
        end

        function name = eventName(event)
            if isfield(event, 'guard_name') && ~isempty(event.guard_name)
                name = string(event.guard_name);
            elseif isfield(event, 'type') && ~isempty(event.type)
                name = string(event.type);
            else
                name = "unnamed-event";
            end
        end

        function output = mergeStructs(left, right)
            output = left;
            if isempty(right)
                return
            end
            if ~isstruct(right) || ~isscalar(right)
                error('PoincareMap_v3:InvalidOptions', ...
                    'Map options must be scalar structures.');
            end
            names = fieldnames(right);
            for i = 1:numel(names)
                output.(names{i}) = right.(names{i});
            end
        end

        function value = crossingPrototype()
            value = struct( ...
                'index', 0, 'time', NaN, 'period', NaN, ...
                'initial_mode', [], 'state', [], 'canonical_state', [], ...
                'mode', [], 'discrete_closed', false, ...
                'section_derivative', NaN, 'section_transversality', NaN, ...
                'incremental_event_history', struct([]), ...
                'event_history', struct([]), ...
                'incremental_event_count', 0, 'event_count', 0, ...
                'section_relative_event_signature', "", ...
                'cyclic_event_signature', "", ...
                'section_coincident_events', struct([]), ...
                'guard_transversality_margins', zeros(0, 1), ...
                'phase_results', {cell(0, 1)}, ...
                'incremental_trajectory', [], ...
                'accepted', false, 'policy_diagnostics', struct());
        end
    end
end
