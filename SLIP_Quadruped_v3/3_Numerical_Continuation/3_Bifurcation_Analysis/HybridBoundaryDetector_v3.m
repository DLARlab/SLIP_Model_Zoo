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
        ClusterTimeTolerance = 1e-10
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
                clusterReport = obj.clusterReport(points(index));
                guardMargin = obj.guardMargin(points(index));
                if isfinite(guardMargin) && guardMargin <= obj.GrazingTolerance
                    events = obj.append(events, obj.makePointEvent( ...
                        'guard_grazing', index, points, ...
                        struct('guardTransversality', guardMargin)));
                end

                collisionMargin = clusterReport.minimum_intercluster_gap;
                if isfinite(collisionMargin) && ...
                        collisionMargin <= obj.EventCollisionTolerance
                    events = obj.append(events, obj.makePointEvent( ...
                        'event_cluster_approach', index, points, ...
                        struct('minimumInterclusterGap', collisionMargin, ...
                        'clusterSignature', ...
                            clusterReport.cluster_signature, ...
                        'semantics', ...
                            'distinct-clusters-close-but-not-yet-merged')));
                end

                coincident = obj.sectionCoincident(points(index));
                coincidenceMargin = obj.sectionCoincidenceMargin( ...
                    points(index));
                hasCoincidence = ~isempty(coincident) && ...
                    (~islogical(coincident) || any(coincident(:)));
                if hasCoincidence || (isfinite(coincidenceMargin) && ...
                        coincidenceMargin <= obj.SectionCoincidenceTolerance)
                    events = obj.append(events, obj.makePointEvent( ...
                        'section_cluster_coincidence', index, points, ...
                        struct('sectionCoincidentClusterIndices', ...
                            clusterReport.section_coincident_cluster_indices, ...
                        'sectionClusterSeparation', coincidenceMargin)));
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

                physical = obj.physicalMargins(points(index));
                if isfinite(physical.swing_foot_clearance) && ...
                        physical.swing_foot_clearance <= ...
                        obj.AdmissibilityTolerance
                    events = obj.append(events, obj.makePointEvent( ...
                        'swing_foot_penetration', index, points, ...
                        struct('clearance', ...
                            physical.swing_foot_clearance, ...
                        'semantics', 'unilateral-geometry-boundary')));
                end
                if isfinite(physical.torso_clearance) && ...
                        physical.torso_clearance <= obj.AdmissibilityTolerance
                    events = obj.append(events, obj.makePointEvent( ...
                        'torso_ground_contact', index, points, ...
                        struct('clearance', physical.torso_clearance, ...
                        'semantics', 'physical-contact-boundary')));
                end
                if isnan(physical.leg_length) || ...
                        physical.leg_length == -Inf || ...
                        physical.leg_length <= obj.AdmissibilityTolerance
                    events = obj.append(events, obj.makePointEvent( ...
                        'invalid_leg_geometry', index, points, ...
                        struct('legLengthMargin', physical.leg_length, ...
                        'semantics', 'geometry-domain-boundary')));
                end
                if isfinite(physical.complementarity_margin) && ...
                        physical.complementarity_margin <= ...
                        obj.AdmissibilityTolerance
                    events = obj.append(events, obj.makePointEvent( ...
                        'contact_complementarity_loss', index, points, ...
                        struct('complementarityMargin', ...
                            physical.complementarity_margin, ...
                        'semantics', 'contact-mode-boundary')));
                end
            end

            for index = 1:numel(points) - 1
                left = points(index);
                right = points(index + 1);
                leftClusters = obj.clusterReport(left);
                rightClusters = obj.clusterReport(right);
                transition = EventCluster_v3(struct( ...
                    'AbsoluteTimeTolerance', ...
                        obj.ClusterTimeTolerance, ...
                    'CollisionTimeTolerance', ...
                        obj.EventCollisionTolerance)).compare( ...
                            leftClusters, rightClusters);
                if transition.has_persistent_simultaneous_cluster
                    events = obj.append(events, obj.makeIntervalEvent( ...
                        'persistent_simultaneous_cluster', index, points, ...
                        struct('clusters', ...
                            transition.persistent_simultaneous_clusters, ...
                        'leftSignature', leftClusters.cluster_signature, ...
                        'rightSignature', rightClusters.cluster_signature)));
                end
                if transition.has_split
                    events = obj.append(events, obj.makeIntervalEvent( ...
                        'event_cluster_split', index, points, ...
                        struct('splits', transition.event_cluster_splits, ...
                        'leftSignature', leftClusters.cluster_signature, ...
                        'rightSignature', rightClusters.cluster_signature)));
                end
                if transition.has_merge
                    mergeDetails = struct('merges', ...
                        transition.event_cluster_merges, ...
                        'leftSignature', leftClusters.cluster_signature, ...
                        'rightSignature', rightClusters.cluster_signature);
                    events = obj.append(events, obj.makeIntervalEvent( ...
                        'event_cluster_merge', index, points, mergeDetails));
                    if transition.has_collision
                        events = obj.append(events, obj.makeIntervalEvent( ...
                            'event_cluster_collision', index, points, ...
                            obj.withField(mergeDetails, 'mechanism', ...
                                'distinct-cluster-center-merge')));
                        events = obj.append(events, obj.makeIntervalEvent( ...
                            'event_collision', index, points, ...
                            obj.withField(mergeDetails, 'semantics', ...
                                'distinct-cluster-center-merge')));
                    end
                end
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

                leftSectionSignature = obj.sectionSignature(left);
                rightSectionSignature = obj.sectionSignature(right);
                if ~isempty(leftSectionSignature) && ...
                        ~isempty(rightSectionSignature) && ...
                        ~strcmp(leftSectionSignature, rightSectionSignature)
                    events = obj.append(events, obj.makeIntervalEvent( ...
                        'section_relative_signature_change', index, points, ...
                        struct('leftSignature', leftSectionSignature, ...
                               'rightSignature', rightSectionSignature, ...
                               'semantics', 'hybrid-section-chart-boundary')));
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

        function report = clusterReport(obj, point)
            report = obj.member(point, ...
                {'event_cluster_report', 'eventClusterReport'}, struct());
            if ~isempty(report) && isstruct(report) && isscalar(report) && ...
                    isfield(report, 'clusters') && ...
                    isfield(report, 'minimum_intercluster_gap')
                return
            end
            info = obj.member(point, {'map_info', 'mapInfo'}, struct());
            report = obj.member(info, ...
                {'event_cluster_report', 'eventClusterReport'}, struct());
            if ~isempty(report) && isstruct(report) && isscalar(report) && ...
                    isfield(report, 'clusters') && ...
                    isfield(report, 'minimum_intercluster_gap')
                return
            end
            history = obj.member(point, {'event_history', 'eventHistory'}, []);
            if iscell(history)
                if isscalar(history)
                    history = history{1};
                elseif isempty(history)
                    history = struct([]);
                else
                    history = struct([]);
                end
            end
            if ~isempty(history) && ~isstruct(history)
                history = struct([]);
            end
            period = obj.member(point, {'period'}, NaN);
            context = struct('InitialTime', 0, 'Period', period);
            report = EventCluster_v3(struct( ...
                'AbsoluteTimeTolerance', obj.ClusterTimeTolerance, ...
                'SectionCoincidenceTolerance', ...
                    obj.SectionCoincidenceTolerance)).analyze( ...
                        history, context);
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
                report = obj.clusterReport(point);
                value = report.section_cluster_coincidence;
            end
        end

        function margin = sectionCoincidenceMargin(obj, point)
            topology = obj.member(point, ...
                {'topology_margins', 'topologyMargins'}, struct());
            margin = obj.member(topology, ...
                {'section_cluster_separation', ...
                 'minimum_section_cluster_gap', ...
                 'section_event_separation', ...
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

        function margins = physicalMargins(obj, point)
            defaults = struct( ...
                'global', Inf, 'swing_foot_clearance', Inf, ...
                'stance_compression', Inf, 'leg_length', Inf, ...
                'hip_clearance', Inf, 'torso_clearance', Inf, ...
                'complementarity_margin', Inf);
            margins = obj.member(point, ...
                {'minimum_physical_margins', ...
                 'minimumPhysicalMargins'}, struct());
            if isempty(margins) || ~isstruct(margins)
                topology = obj.member(point, ...
                    {'topology_margins', 'topologyMargins'}, struct());
                margins = struct( ...
                    'global', obj.member(topology, {'physical'}, Inf), ...
                    'swing_foot_clearance', obj.member(topology, ...
                        {'swing_foot_clearance'}, Inf), ...
                    'stance_compression', obj.member(topology, ...
                        {'stance_compression'}, Inf), ...
                    'leg_length', obj.member(topology, ...
                        {'leg_length'}, Inf), ...
                    'hip_clearance', obj.member(topology, ...
                        {'hip_clearance'}, Inf), ...
                    'torso_clearance', obj.member(topology, ...
                        {'torso_clearance'}, Inf), ...
                    'complementarity_margin', obj.member(topology, ...
                        {'contact_complementarity'}, Inf));
            end
            names = fieldnames(defaults);
            for index = 1:numel(names)
                name = names{index};
                if ~isfield(margins, name) || isempty(margins.(name))
                    margins.(name) = defaults.(name);
                end
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

        function signature = sectionSignature(obj, point)
            value = obj.member(point, ...
                {'section_relative_signature', ...
                 'section_relative_event_signature', ...
                 'sectionRelativeEventSignature'}, '');
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

        function output = withField(~, input, name, value)
            output = input;
            output.(name) = value;
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
