classdef ModeTransition_v3
    %MODETRANSITION_V3 Binary contact transitions in [BL BR FL FR] order.

    properties (SetAccess = private)
        Schema
    end

    properties (Dependent, SetAccess = private)
        LegNames
        EventNames
    end

    methods
        function obj = ModeTransition_v3(schema)
            if nargin < 1 || isempty(schema)
                schema = QuadrupedSchema_v3.shared();
            end
            if ~isa(schema, 'QuadrupedSchema_v3')
                error('ModeTransition_v3:InvalidSchema', ...
                    'Schema must be a QuadrupedSchema_v3 instance.');
            end
            obj.Schema = schema;
        end

        function names = get.LegNames(obj)
            names = obj.Schema.Leg.Names;
        end

        function names = get.EventNames(obj)
            names = obj.Schema.Event.Names;
        end

        function qplus = apply(obj, eventId, qminus)
            qminus = obj.Schema.validateMode(qminus);
            eventId = obj.Schema.eventId(eventId);
            [legIndex, isTouchdown] = obj.Schema.eventLegKind(eventId);

            expectedContact = ~isTouchdown;
            if qminus(legIndex) ~= expectedContact
                error('ModeTransition_v3:EventModeMismatch', ...
                    '%s is not enabled in mode [%s].', ...
                    obj.Schema.Event.Names{eventId}, sprintf('%d ', qminus));
            end

            qplus = qminus;
            qplus(legIndex) = isTouchdown;
        end

        function qplus = applyBatch(obj, eventIds, qminus)
            % Independent simultaneous leg events commute.  Sorting event IDs
            % only makes the numerical operation deterministic.
            qplus = obj.Schema.validateMode(qminus);
            ids = obj.normalizeEventVector(eventIds);
            legIndices = obj.Schema.Event.LegIndices(ids);
            if numel(unique(legIndices)) ~= numel(ids)
                error('ModeTransition_v3:ConflictingBatch', ...
                    'A simultaneous batch may contain at most one event per leg.');
            end
            ids = sort(ids);
            for i = 1:numel(ids)
                qplus = obj.apply(ids(i), qplus);
            end
        end

        function ids = enabledEventIds(obj, q)
            q = obj.Schema.validateMode(q);
            ids = zeros(obj.Schema.Leg.Count, 1);
            for legIndex = obj.Schema.Leg.Indices
                eventMask = obj.Schema.Event.LegIndices == legIndex ...
                    & obj.Schema.Event.IsTouchdown == ~q(legIndex);
                ids(legIndex) = obj.Schema.Event.IDs(eventMask);
            end
        end

        function modes = candidates(obj)
            % Compatibility alias for explicit exhaustive search.
            modes = obj.allModes();
        end

        function modes = allModes(~)
            matrix = ModeTransition_v3.modeMatrix();
            modes = arrayfun(@(i) logical(matrix(i, :).'), ...
                (1:size(matrix, 1)).', 'UniformOutput', false);
        end

        function modes = successors(obj, q)
            q = obj.Schema.validateMode(q);
            ids = obj.enabledEventIds(q);
            modes = cell(numel(ids), 1);
            for i = 1:numel(ids)
                modes{i} = obj.apply(ids(i), q);
            end
        end

        function catalog = eventCatalog(obj)
            catalog = obj.Schema.eventCatalog();
        end
    end

    methods (Access = private)
        function ids = normalizeEventVector(obj, events)
            if ischar(events) || (isstring(events) && isscalar(events))
                ids = obj.Schema.eventId(events);
                return;
            end
            if iscell(events) || isstring(events)
                ids = zeros(numel(events), 1);
                for i = 1:numel(events)
                    if iscell(events)
                        event = events{i};
                    else
                        event = events(i);
                    end
                    ids(i) = obj.Schema.eventId(event);
                end
                return;
            end
            if ~isnumeric(events) || ~isreal(events)
                error('ModeTransition_v3:InvalidEvent', ...
                    'Events must be IDs or event names.');
            end
            ids = zeros(numel(events), 1);
            for i = 1:numel(events)
                ids(i) = obj.Schema.eventId(events(i));
            end
        end
    end

    methods (Static)
        function q = validateModeVector(q)
            schema = QuadrupedSchema_v3.shared();
            q = schema.validateMode(q);
        end

        function id = normalizeEventId(eventId)
            schema = QuadrupedSchema_v3.shared();
            id = schema.eventId(eventId);
        end

        function [legIndex, isTouchdown] = eventLegKind(eventId)
            schema = QuadrupedSchema_v3.shared();
            [legIndex, isTouchdown] = schema.eventLegKind(eventId);
        end

        function modes = modeMatrix()
            % Rows are binary 0000 through 1111; BL is the first column.
            schema = QuadrupedSchema_v3.shared();
            legCount = schema.Leg.Count;
            values = (0:(2^legCount - 1)).';
            modes = false(numel(values), legCount);
            for column = 1:legCount
                modes(:, column) = logical(bitget( ...
                    values, legCount + 1 - column));
            end
        end
    end
end
