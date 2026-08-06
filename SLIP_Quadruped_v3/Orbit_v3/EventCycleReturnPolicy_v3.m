classdef EventCycleReturnPolicy_v3 < ReturnPolicyBase_v3
    %EVENTCYCLERETURNPOLICY_V3 Close a contact cycle at a section crossing.
    %   The first candidate with the initial right-continuous mode and at
    %   least one touchdown and one liftoff for every leg is accepted. Event
    %   order is unrestricted. Event metadata should provide leg_index and
    %   event_kind; event-name parsing is retained as a diagnostic fallback.

    properties
        LegCount = []
        LegNames = {}
        RequireModeClosure = true
        EventClassifier = []
    end

    methods
        function obj = EventCycleReturnPolicy_v3(options)
            obj.Name = 'event-cycle-return';
            if nargin >= 1
                obj = obj.applyOptions(options);
            end
            if ~isempty(obj.LegCount)
                validateattributes(obj.LegCount, {'numeric'}, ...
                    {'scalar', 'integer', 'positive'});
                obj.LegCount = double(obj.LegCount);
            end
            if ~(isempty(obj.EventClassifier) || ...
                    isa(obj.EventClassifier, 'function_handle'))
                error('EventCycleReturnPolicy_v3:InvalidClassifier', ...
                    'EventClassifier must be empty or a function handle.');
            end
        end

        function state = initialize(obj, initialMode, context)
            state = initialize@ReturnPolicyBase_v3( ...
                obj, initialMode, context);
            state.leg_count = obj.resolveLegCount(initialMode);
        end
    end

    methods (Access = protected)
        function [accepted, diagnostics] = acceptCandidate( ...
                obj, candidate, state)
            nLegs = state.leg_count;
            [touchdown, liftoff, names, unclassified] = ...
                obj.countEvents(candidate.event_history, nLegs);
            modeClosed = ~obj.RequireModeClosure || ...
                EventCycleReturnPolicy_v3.modeEquals( ...
                    candidate.initial_mode, candidate.mode);
            touchdownComplete = all(touchdown >= 1);
            liftoffComplete = all(liftoff >= 1);
            accepted = modeClosed && touchdownComplete && liftoffComplete;

            if ~modeClosed
                reason = 'right-continuous section mode has not closed';
            elseif ~touchdownComplete
                reason = 'at least one leg has no touchdown';
            elseif ~liftoffComplete
                reason = 'at least one leg has no liftoff';
            else
                reason = 'mode closure and per-leg TD/LO counts are complete';
            end

            perLeg = repmat(struct( ...
                'leg_index', 0, 'leg_name', '', ...
                'touchdown_count', 0, 'liftoff_count', 0), nLegs, 1);
            for i = 1:nLegs
                perLeg(i).leg_index = i;
                perLeg(i).leg_name = names{i};
                perLeg(i).touchdown_count = touchdown(i);
                perLeg(i).liftoff_count = liftoff(i);
            end

            diagnostics = struct( ...
                'complete', accepted, ...
                'reason', reason, ...
                'mode_closed', modeClosed, ...
                'initial_mode', candidate.initial_mode, ...
                'return_mode', candidate.mode, ...
                'touchdown_counts', touchdown, ...
                'liftoff_counts', liftoff, ...
                'event_counts_per_leg', perLeg, ...
                'touchdown_complete', touchdownComplete, ...
                'liftoff_complete', liftoffComplete, ...
                'unclassified_events', {unclassified}, ...
                'return_multiplicity', candidate.index);
        end
    end

    methods (Access = private)
        function nLegs = resolveLegCount(obj, initialMode)
            if ~isempty(obj.LegCount)
                nLegs = obj.LegCount;
                return
            end
            if (isnumeric(initialMode) || islogical(initialMode)) ...
                    && isvector(initialMode) && ~isempty(initialMode)
                nLegs = numel(initialMode);
                return
            end
            error('EventCycleReturnPolicy_v3:UnknownLegCount', ...
                ['Set LegCount when the discrete mode is not a nonempty ', ...
                 'numeric/logical contact vector.']);
        end

        function [touchdown, liftoff, names, unclassified] = ...
                countEvents(obj, history, nLegs)
            touchdown = zeros(nLegs, 1);
            liftoff = zeros(nLegs, 1);
            names = arrayfun(@(i) sprintf('leg_%d', i), 1:nLegs, ...
                'UniformOutput', false).';
            if ~isempty(obj.LegNames)
                if numel(obj.LegNames) ~= nLegs
                    error('EventCycleReturnPolicy_v3:LegNameCount', ...
                        'LegNames must have one entry per leg.');
                end
                names = cellstr(string(obj.LegNames(:)));
            end
            unclassified = strings(0, 1);

            for i = 1:numel(history)
                event = history(i);
                if isfield(event, 'is_stop') && event.is_stop
                    continue
                end
                [legIndex, kind, legName] = obj.classifyEvent(event, nLegs);
                if isempty(legIndex) || isempty(kind) ...
                        || legIndex < 1 || legIndex > nLegs
                    unclassified(end + 1, 1) = ...
                        EventCycleReturnPolicy_v3.eventName(event); %#ok<AGROW>
                    continue
                end
                if strlength(legName) > 0
                    names{legIndex} = char(legName);
                end
                if kind == "touchdown"
                    touchdown(legIndex) = touchdown(legIndex) + 1;
                elseif kind == "liftoff"
                    liftoff(legIndex) = liftoff(legIndex) + 1;
                else
                    unclassified(end + 1, 1) = ...
                        EventCycleReturnPolicy_v3.eventName(event); %#ok<AGROW>
                end
            end
        end

        function [legIndex, kind, legName] = ...
                classifyEvent(obj, event, nLegs)
            legIndex = [];
            kind = "";
            legName = "";
            if ~isempty(obj.EventClassifier)
                [legIndex, kind, legName] = obj.EventClassifier(event);
                kind = EventCycleReturnPolicy_v3.normalizeKind(kind);
                legName = string(legName);
                return
            end

            if isfield(event, 'leg_index') && ~isempty(event.leg_index)
                legIndex = double(event.leg_index);
            end
            if isfield(event, 'kind') && ~isempty(event.kind)
                kind = EventCycleReturnPolicy_v3.normalizeKind(event.kind);
            end
            metadata = struct();
            if isfield(event, 'metadata') && isstruct(event.metadata)
                metadata = event.metadata;
            end
            if isempty(legIndex) && isfield(metadata, 'leg_index')
                legIndex = double(metadata.leg_index);
            end
            if strlength(kind) == 0
                if isfield(metadata, 'event_kind')
                    kind = EventCycleReturnPolicy_v3.normalizeKind( ...
                        metadata.event_kind);
                elseif isfield(metadata, 'kind')
                    kind = EventCycleReturnPolicy_v3.normalizeKind( ...
                        metadata.kind);
                end
            end
            if isfield(metadata, 'leg_name')
                legName = string(metadata.leg_name);
            elseif isfield(event, 'leg_name')
                legName = string(event.leg_name);
            end

            name = upper(EventCycleReturnPolicy_v3.eventName(event));
            if strlength(kind) == 0
                if contains(name, "TD") || contains(name, "TOUCHDOWN")
                    kind = "touchdown";
                elseif contains(name, "LO") || contains(name, "LIFTOFF")
                    kind = "liftoff";
                end
            end
            if isempty(legIndex) && nLegs == 1 && strlength(kind) > 0
                legIndex = 1;
            end
            if strlength(legName) == 0 && strlength(name) > 0
                legName = erase(erase(erase(erase(name, "TOUCHDOWN"), ...
                    "LIFTOFF"), "TD"), "LO");
                legName = strip(legName, 'both', '_- ');
            end
        end
    end

    methods (Static, Access = private)
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
            elseif isfield(event, 'name') && ~isempty(event.name)
                name = string(event.name);
            else
                name = "unnamed-event";
            end
        end

        function kind = normalizeKind(value)
            value = lower(string(value));
            if ismember(value, ["td", "touchdown"])
                kind = "touchdown";
            elseif ismember(value, ["lo", "liftoff"])
                kind = "liftoff";
            else
                kind = "";
            end
        end
    end
end
