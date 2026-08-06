classdef HybridBoundaryDetector_v3
    %HYBRIDBOUNDARYDETECTOR_V3 Detect nonsmooth continuation boundaries.
    %   These diagnostics are deliberately separate from smooth Floquet
    %   bifurcations.  A reported boundary is a bracket requiring local hybrid
    %   analysis; it is not automatically a saddle-node or other smooth event.

    properties
        GrazingTolerance = 1e-5
        EventCollisionTolerance = 1e-5
        SectionCoincidenceTolerance = 1e-6
        AdmissibilityTolerance = 1e-8
    end

    methods
        function obj = HybridBoundaryDetector_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
        end

        function events = detect(obj, branch)
            points = obj.points(branch);
            events = repmat(obj.emptyEvent(), 1, 0);
            if isempty(points)
                return
            end

            for index = 1:numel(points)
                guardMargin = obj.guardMargin(points(index));
                if isfinite(guardMargin) && guardMargin <= obj.GrazingTolerance
                    events = obj.append(events, obj.makePointEvent( ...
                        'guard_grazing', index, points, ...
                        struct('guardTransversality', guardMargin)));
                end

                collisionMargin = obj.eventCollisionMargin(points(index));
                if isfinite(collisionMargin) && ...
                        collisionMargin <= obj.EventCollisionTolerance
                    events = obj.append(events, obj.makePointEvent( ...
                        'event_collision', index, points, ...
                        struct('eventTimeSeparation', collisionMargin)));
                end

                coincident = obj.sectionCoincident(points(index));
                coincidenceMargin = obj.sectionCoincidenceMargin( ...
                    points(index));
                hasCoincidence = ~isempty(coincident) && ...
                    (~islogical(coincident) || any(coincident(:)));
                if hasCoincidence || (isfinite(coincidenceMargin) && ...
                        coincidenceMargin <= obj.SectionCoincidenceTolerance)
                    events = obj.append(events, obj.makePointEvent( ...
                        'section_event_coincidence', index, points, ...
                        struct('sectionCoincidentEvents', coincident, ...
                        'sectionEventTimeSeparation', coincidenceMargin)));
                end

                admissibility = obj.admissibilityMargin(points(index));
                if isfinite(admissibility) && ...
                        admissibility <= obj.AdmissibilityTolerance
                    events = obj.append(events, obj.makePointEvent( ...
                        'stance_force_admissibility_loss', index, points, ...
                        struct('admissibilityMargin', admissibility)));
                end
            end

            for index = 1:numel(points) - 1
                left = points(index);
                right = points(index + 1);
                leftEvents = obj.eventCount(left);
                rightEvents = obj.eventCount(right);
                if leftEvents ~= rightEvents
                    events = obj.append(events, obj.makeIntervalEvent( ...
                        'event_insertion_or_deletion', index, points, ...
                        struct('leftEventCount', leftEvents, ...
                               'rightEventCount', rightEvents)));
                end

                leftMode = obj.member(left, {'mode', 'section_mode'}, []);
                rightMode = obj.member(right, {'mode', 'section_mode'}, []);
                if ~isempty(leftMode) && ~isempty(rightMode) && ...
                        ~isequal(leftMode, rightMode)
                    events = obj.append(events, obj.makeIntervalEvent( ...
                        'section_mode_change', index, points, ...
                        struct('leftMode', leftMode, 'rightMode', rightMode)));
                end

                leftMultiplicity = obj.member(left, ...
                    {'return_multiplicity', 'returnMultiplicity'}, 1);
                rightMultiplicity = obj.member(right, ...
                    {'return_multiplicity', 'returnMultiplicity'}, 1);
                if ~isequal(leftMultiplicity, rightMultiplicity)
                    events = obj.append(events, obj.makeIntervalEvent( ...
                        'return_multiplicity_change', index, points, ...
                        struct('leftMultiplicity', leftMultiplicity, ...
                               'rightMultiplicity', rightMultiplicity)));
                end

                leftSignature = obj.signature(left);
                rightSignature = obj.signature(right);
                if ~isempty(leftSignature) && ~isempty(rightSignature) && ...
                        ~strcmp(leftSignature, rightSignature)
                    events = obj.append(events, obj.makeIntervalEvent( ...
                        'cyclic_event_signature_change', index, points, ...
                        struct('leftSignature', leftSignature, ...
                               'rightSignature', rightSignature)));
                end
            end
        end
    end

    methods (Access = private)
        function points = points(~, branch)
            if isempty(branch)
                points = struct([]);
            elseif isstruct(branch) && isscalar(branch) && ...
                    isfield(branch, 'points')
                points = branch.points;
            elseif isstruct(branch)
                points = branch;
            else
                error('HybridBoundaryDetector_v3:Input', ...
                    'Input must be a continuation branch or point structure.');
            end
        end

        function margin = guardMargin(obj, point)
            value = obj.member(point, ...
                {'guard_transversality', 'guardTransversality', ...
                 'guard_transversality_margin'}, Inf);
            if isempty(value)
                margin = Inf;
            else
                margin = min(abs(value(:)));
            end
        end

        function margin = eventCollisionMargin(obj, point)
            history = obj.member(point, {'event_history', 'eventHistory'}, []);
            if isempty(history) || ~isstruct(history)
                margin = Inf;
                return
            end
            if isfield(history, 'time')
                times = sort([history.time]);
            elseif isfield(history, 'event_time')
                times = sort([history.event_time]);
            else
                margin = Inf;
                return
            end
            if numel(times) < 2
                margin = Inf;
                return
            end
            separation = diff(times);
            period = obj.member(point, {'period'}, NaN);
            if isfinite(period) && period > 0
                relative = times - times(1);
                separation(end + 1) = period - relative(end); %#ok<AGROW>
            end
            margin = min(abs(separation));
        end

        function value = sectionCoincident(obj, point)
            value = obj.member(point, ...
                {'section_coincident_events', 'sectionCoincidentEvents'}, []);
            if ~isempty(value)
                return
            end
            info = obj.member(point, {'map_info', 'mapInfo'}, struct());
            value = obj.member(info, ...
                {'section_coincident_events', 'sectionCoincidentEvents'}, []);
            if isempty(value)
                value = false;
            end
        end

        function margin = sectionCoincidenceMargin(obj, point)
            topology = obj.member(point, ...
                {'topology_margins', 'topologyMargins'}, struct());
            margin = obj.member(topology, ...
                {'section_event_separation', ...
                 'sectionEventSeparation'}, Inf);
            if isempty(margin)
                margin = Inf;
            end
        end

        function margin = admissibilityMargin(obj, point)
            value = obj.member(point, ...
                {'stance_force_admissibility_margin', ...
                 'admissibility_margin', 'admissibilityMargin'}, []);
            if isempty(value)
                topology = obj.member(point, ...
                    {'topology_margins', 'topologyMargins'}, struct());
                value = obj.member(topology, ...
                    {'stance_force', 'stanceForce', 'admissibility'}, Inf);
            end
            if isempty(value)
                margin = Inf;
            else
                margin = min(value(:));
            end
        end

        function count = eventCount(obj, point)
            counts = obj.member(point, {'event_counts', 'eventCounts'}, []);
            if ~isempty(counts)
                if isnumeric(counts) || islogical(counts)
                    count = sum(counts(:));
                elseif isstruct(counts)
                    count = 0;
                    fields = {'touchdown_count', 'liftoff_count'};
                    found = false;
                    for fieldIndex = 1:numel(fields)
                        if isfield(counts, fields{fieldIndex})
                            count = count + sum( ...
                                [counts.(fields{fieldIndex})]);
                            found = true;
                        end
                    end
                    if ~found
                        count = numel(counts);
                    end
                else
                    count = numel(counts);
                end
                return
            end
            history = obj.member(point, {'event_history', 'eventHistory'}, []);
            count = numel(history);
        end

        function signature = signature(obj, point)
            value = obj.member(point, ...
                {'cyclic_signature', 'cyclic_event_signature', ...
                 'cyclicEventSignature'}, '');
            if ischar(value)
                signature = value;
            else
                signature = char(strjoin(string(value(:)), '>'));
            end
        end

        function event = makePointEvent(obj, type, index, points, details)
            event = obj.emptyEvent();
            event.type = type;
            event.leftIndex = index;
            event.rightIndex = index;
            event.location = obj.coordinate(points(index), index);
            event.leftCoordinate = event.location;
            event.rightCoordinate = event.location;
            event.details = details;
        end

        function event = makeIntervalEvent(obj, type, index, points, details)
            event = obj.emptyEvent();
            event.type = type;
            event.leftIndex = index;
            event.rightIndex = index + 1;
            event.leftCoordinate = obj.coordinate(points(index), index);
            event.rightCoordinate = obj.coordinate(points(index + 1), index + 1);
            event.location = 0.5 * ...
                (event.leftCoordinate + event.rightCoordinate);
            event.details = details;
        end

        function coordinate = coordinate(obj, point, fallback)
            coordinate = obj.member(point, ...
                {'arclength', 'continuationCoordinate'}, fallback);
            if isempty(coordinate) || ~isscalar(coordinate) || ...
                    ~isfinite(coordinate)
                coordinate = fallback;
            end
        end

        function events = append(~, events, event)
            events(end + 1) = event;
        end

        function value = member(~, source, names, default)
            value = default;
            if isempty(source) || ~isstruct(source)
                return
            end
            for index = 1:numel(names)
                if isfield(source, names{index})
                    value = source.(names{index});
                    return
                end
            end
        end

        function event = emptyEvent(~)
            event = struct('type', '', 'leftIndex', [], 'rightIndex', [], ...
                'leftCoordinate', NaN, 'rightCoordinate', NaN, ...
                'location', NaN, 'reliableSmoothBifurcation', false, ...
                'details', struct());
        end

        function obj = applyOptions(obj, options)
            names = fieldnames(options);
            for index = 1:numel(names)
                obj = obj.setOption(names{index}, options.(names{index}));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin), 2) ~= 0
                error('HybridBoundaryDetector_v3:NameValue', ...
                    'Options must be supplied as name/value pairs.');
            end
            for index = 1:2:numel(varargin)
                obj = obj.setOption(varargin{index}, varargin{index + 1});
            end
        end

        function obj = setOption(obj, name, value)
            list = properties(obj);
            match = find(strcmpi(char(name), list), 1);
            if isempty(match)
                error('HybridBoundaryDetector_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(list{match}) = value;
        end
    end
end
