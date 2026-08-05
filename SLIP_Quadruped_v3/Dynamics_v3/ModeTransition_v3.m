classdef ModeTransition_v3
    %MODETRANSITION_V3 Four-leg binary contact-mode transitions.
    % Mode ordering is always q = [BL; FL; BR; FR].

    properties (Constant)
        LegNames = {'BL', 'FL', 'BR', 'FR'}
        EventNames = { ...
            'BL_TD', 'BL_LO', 'FL_TD', 'FL_LO', ...
            'BR_TD', 'BR_LO', 'FR_TD', 'FR_LO'}
    end

    methods
        function qplus = apply(~, eventId, qminus)
            qminus = ModeTransition_v3.validateModeVector(qminus);
            eventId = ModeTransition_v3.normalizeEventId(eventId);
            [legIndex, isTouchdown] = ModeTransition_v3.eventLegKind(eventId);

            expectedContact = ~isTouchdown;
            if qminus(legIndex) ~= expectedContact
                error('ModeTransition_v3:EventModeMismatch', ...
                    '%s is not enabled in mode [%s].', ...
                    ModeTransition_v3.EventNames{eventId}, ...
                    sprintf('%d ', qminus));
            end

            qplus = qminus;
            qplus(legIndex) = isTouchdown;
        end

        function qplus = applyBatch(obj, eventIds, qminus)
            % Independent simultaneous leg events commute.  Sorting only makes
            % the numerical result deterministic and does not prescribe a gait.
            qplus = ModeTransition_v3.validateModeVector(qminus);
            rawIds = eventIds(:);
            ids = zeros(size(rawIds));
            for i = 1:numel(rawIds)
                ids(i) = ModeTransition_v3.normalizeEventId(rawIds(i));
            end
            if numel(unique(ceil(ids / 2))) ~= numel(ids)
                error('ModeTransition_v3:ConflictingBatch', ...
                    'A simultaneous batch may contain at most one event per leg.');
            end
            ids = sort(ids);
            for i = 1:numel(ids)
                qplus = obj.apply(ids(i), qplus);
            end
        end

        function ids = enabledEventIds(~, q)
            q = ModeTransition_v3.validateModeVector(q);
            ids = (2 * (0:3).' + 1) + double(q);
        end

        function modes = candidates(~)
            matrix = ModeTransition_v3.modeMatrix();
            modes = arrayfun(@(i) logical(matrix(i, :).'), ...
                (1:size(matrix, 1)).', 'UniformOutput', false);
        end

        function modes = successors(obj, q)
            q = ModeTransition_v3.validateModeVector(q);
            ids = obj.enabledEventIds(q);
            modes = cell(numel(ids), 1);
            for i = 1:numel(ids)
                modes{i} = obj.apply(ids(i), q);
            end
        end

        function catalog = eventCatalog(~)
            catalog = repmat(struct( ...
                'id', 0, 'name', '', 'leg_index', 0, 'leg_name', '', ...
                'kind', '', 'direction', 0, 'priority', 0), 8, 1);
            for id = 1:8
                [legIndex, isTouchdown] = ...
                    ModeTransition_v3.eventLegKind(id);
                catalog(id).id = id;
                catalog(id).name = ModeTransition_v3.EventNames{id};
                catalog(id).leg_index = legIndex;
                catalog(id).leg_name = ModeTransition_v3.LegNames{legIndex};
                if isTouchdown
                    catalog(id).kind = 'touchdown';
                    catalog(id).direction = -1;
                else
                    catalog(id).kind = 'liftoff';
                    catalog(id).direction = 1;
                end
                catalog(id).priority = id;
            end
        end
    end

    methods (Static)
        function q = validateModeVector(q)
            if ~(isnumeric(q) || islogical(q)) || ~isreal(q) ...
                    || numel(q) ~= 4 || any(~isfinite(double(q(:)))) ...
                    || any((double(q(:)) ~= 0) & (double(q(:)) ~= 1))
                error('ModeTransition_v3:InvalidMode', ...
                    'Quadruped mode must contain four binary entries [BL FL BR FR].');
            end
            q = logical(q(:));
        end

        function id = normalizeEventId(eventId)
            if ischar(eventId) || (isstring(eventId) && isscalar(eventId))
                id = find(strcmpi(char(eventId), ModeTransition_v3.EventNames), 1);
                if isempty(id)
                    error('ModeTransition_v3:InvalidEvent', ...
                        'Unknown quadruped event name "%s".', char(eventId));
                end
                return;
            end
            if ~(isnumeric(eventId) && isreal(eventId) && isscalar(eventId) ...
                    && isfinite(eventId) && eventId == fix(eventId) ...
                    && eventId >= 1 && eventId <= 8)
                error('ModeTransition_v3:InvalidEvent', ...
                    'Quadruped event ID must be an integer from 1 through 8.');
            end
            id = double(eventId);
        end

        function [legIndex, isTouchdown] = eventLegKind(eventId)
            eventId = ModeTransition_v3.normalizeEventId(eventId);
            legIndex = ceil(eventId / 2);
            isTouchdown = mod(eventId, 2) == 1;
        end

        function modes = modeMatrix()
            % Rows are binary 0000 through 1111; BL is the first column.
            values = (0:15).';
            modes = false(16, 4);
            for column = 1:4
                modes(:, column) = logical(bitget(values, 5 - column));
            end
        end
    end
end
