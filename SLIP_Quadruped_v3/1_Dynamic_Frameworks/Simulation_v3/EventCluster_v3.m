classdef EventCluster_v3
    %EVENTCLUSTER_V3 Topology-aware grouping of near-simultaneous events.
    %   A cluster is formed when all of its physical event times fit inside
    %   an adaptive tolerance.  Intra-cluster spread is reported separately
    %   from the distance between cluster centers, so a structural
    %   simultaneous reset is not mistaken for a collision of distinct
    %   event clusters.

    properties
        AbsoluteTimeTolerance = 1e-10
        RelativeTimeTolerance = 128 * eps
        CollisionTimeTolerance = 1e-5
        SectionCoincidenceTolerance = []
    end

    methods
        function obj = EventCluster_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            obj.validateOptions();
        end

        function report = analyze(obj, history, context)
            %ANALYZE Build an event-cluster report for one hybrid cycle.
            %   CONTEXT may contain InitialTime, Period, SectionTimes, and
            %   SectionNames.  Only physical events are clustered.
            if nargin < 3 || isempty(context)
                context = struct();
            elseif isnumeric(context) && isscalar(context)
                context = struct('Period', context);
            end
            if ~isstruct(context) || ~isscalar(context)
                error('EventCluster_v3:Context', ...
                    'Context must be a scalar structure or scalar period.');
            end

            history = obj.physicalHistory(history);
            initialTime = obj.member(context, ...
                {'InitialTime', 'initial_time'}, 0);
            period = obj.member(context, {'Period', 'period'}, NaN);
            sectionTimes = obj.member(context, ...
                {'SectionTimes', 'section_times'}, zeros(0, 1));
            sectionNames = string(obj.member(context, ...
                {'SectionNames', 'section_names'}, strings(0, 1)));
            sectionTimes = sectionTimes(:);
            if isempty(sectionNames)
                sectionNames = "section-" + string((1:numel(sectionTimes)).');
            else
                sectionNames = sectionNames(:);
            end
            if numel(sectionNames) ~= numel(sectionTimes)
                error('EventCluster_v3:SectionNames', ...
                    'SectionNames and SectionTimes must have equal lengths.');
            end

            report = obj.emptyReport();
            report.initial_time = initialTime;
            report.period = period;
            report.section_times = sectionTimes;
            report.section_names = sectionNames;
            report.active_tolerances = struct( ...
                'absolute_time', obj.AbsoluteTimeTolerance, ...
                'relative_time', obj.RelativeTimeTolerance, ...
                'collision_time', obj.CollisionTimeTolerance, ...
                'section_coincidence', obj.sectionTolerance());
            if isempty(history)
                return
            end

            times = obj.eventTimes(history);
            if any(~isfinite(times))
                error('EventCluster_v3:EventTimes', ...
                    'Physical event times must be finite.');
            end
            [times, order] = sort(times, 'ascend');
            history = history(order);
            originalIndices = reshape(order, [], 1);

            ranges = zeros(numel(times), 2);
            rangeCount = 0;
            first = 1;
            for index = 2:numel(times)
                tolerance = obj.adaptiveTolerance(times(first), times(index));
                if times(index) - times(first) > tolerance
                    rangeCount = rangeCount + 1;
                    ranges(rangeCount, :) = [first, index - 1];
                    first = index;
                end
            end
            rangeCount = rangeCount + 1;
            ranges(rangeCount, :) = [first, numel(times)];
            ranges = ranges(1:rangeCount, :);

            clusters = repmat(obj.emptyCluster(), rangeCount, 1);
            for clusterIndex = 1:rangeCount
                selected = ranges(clusterIndex, 1):ranges(clusterIndex, 2);
                clusterTimes = times(selected);
                names = obj.eventNames(history(selected));
                sortedNames = sort(names);
                center = mean(clusterTimes);
                spread = max(clusterTimes) - min(clusterTimes);
                sectionDistance = abs(center - sectionTimes);
                if isempty(sectionDistance)
                    coincidentSectionIndices = zeros(0, 1);
                else
                    eventSectionDistance = abs( ...
                        clusterTimes(:) - sectionTimes(:).');
                    coincidentSectionIndices = find(any( ...
                        eventSectionDistance <= obj.sectionTolerance(), 1));
                end

                clusters(clusterIndex).index = clusterIndex;
                clusters(clusterIndex).member_indices = ...
                    originalIndices(selected);
                clusters(clusterIndex).sorted_member_indices = selected(:);
                clusters(clusterIndex).members = history(selected);
                clusters(clusterIndex).names = names;
                clusters(clusterIndex).sorted_names = sortedNames;
                clusters(clusterIndex).center_time = center;
                clusters(clusterIndex).maximum_intra_cluster_spread = spread;
                clusters(clusterIndex).adaptive_time_tolerance = ...
                    obj.adaptiveTolerance(clusterTimes(1), clusterTimes(end));
                clusters(clusterIndex).relative_phase = ...
                    obj.relativePhase(center, initialTime, period);
                clusters(clusterIndex).token = strjoin(sortedNames, "&");
                clusters(clusterIndex).section_coincident = ...
                    ~isempty(coincidentSectionIndices);
                clusters(clusterIndex).section_indices = ...
                    coincidentSectionIndices(:);
                clusters(clusterIndex).section_names = ...
                    sectionNames(coincidentSectionIndices);
                if isempty(sectionDistance)
                    clusters(clusterIndex).minimum_section_distance = Inf;
                else
                    clusters(clusterIndex).minimum_section_distance = ...
                        min(sectionDistance);
                end
            end

            centers = reshape([clusters.center_time], [], 1);
            tokens = reshape(string({clusters.token}), [], 1);
            report.clusters = clusters;
            report.cluster_count = rangeCount;
            report.members = {clusters.member_indices};
            report.cluster_names = {clusters.names};
            report.cluster_center_times = centers;
            report.maximum_intra_cluster_spreads = reshape( ...
                [clusters.maximum_intra_cluster_spread], [], 1);
            report.maximum_intra_cluster_spread = max( ...
                report.maximum_intra_cluster_spreads);
            report.minimum_intercluster_gap = obj.minimumCenterGap( ...
                centers, initialTime, period);
            report.cluster_relative_phase = reshape( ...
                [clusters.relative_phase], [], 1);
            report.cluster_signature = strjoin(tokens, ">");
            report.cyclic_cluster_signature = obj.canonicalSignature(tokens);
            report.section_coincident_cluster_indices = find( ...
                [clusters.section_coincident]).';
            report.section_cluster_coincidence = ...
                ~isempty(report.section_coincident_cluster_indices);
            if isempty(clusters)
                report.minimum_section_cluster_gap = Inf;
            else
                report.minimum_section_cluster_gap = min(reshape( ...
                    [clusters.minimum_section_distance], [], 1));
            end
        end

        function report = cluster(obj, history, context)
            %CLUSTER Compatibility alias for ANALYZE.
            if nargin < 3
                context = struct();
            end
            report = obj.analyze(history, context);
        end

        function diagnostics = compare(obj, left, right)
            %COMPARE Diagnose persistence, splitting, and merging.
            left = obj.normalizeReport(left);
            right = obj.normalizeReport(right);
            persistentClusters = obj.exactPersistentClusters(left, right);
            splits = obj.partitionChanges(left, right);
            merges = obj.partitionChanges(right, left);

            diagnostics = struct();
            diagnostics.reference_supplied = true;
            diagnostics.left_cluster_signature = left.cluster_signature;
            diagnostics.right_cluster_signature = right.cluster_signature;
            diagnostics.left_cyclic_cluster_signature = ...
                left.cyclic_cluster_signature;
            diagnostics.right_cyclic_cluster_signature = ...
                right.cyclic_cluster_signature;
            diagnostics.persistent_simultaneous_clusters = ...
                persistentClusters;
            diagnostics.event_cluster_splits = splits;
            diagnostics.event_cluster_merges = merges;
            diagnostics.has_persistent_simultaneous_cluster = ...
                ~isempty(persistentClusters);
            diagnostics.has_split = ~isempty(splits);
            diagnostics.has_merge = ~isempty(merges);
            if isempty(merges)
                diagnostics.has_collision = false;
            else
                diagnostics.has_collision = any( ...
                    [merges.center_partition_evidence]);
            end
            diagnostics.minimum_intercluster_gap_left = ...
                left.minimum_intercluster_gap;
            diagnostics.minimum_intercluster_gap_right = ...
                right.minimum_intercluster_gap;
            diagnostics.cluster_signature_changed = ...
                ~strcmp(string(left.cluster_signature), ...
                    string(right.cluster_signature));
            diagnostics.compatible = ...
                ~diagnostics.has_split && ~diagnostics.has_merge && ...
                ~diagnostics.cluster_signature_changed;
        end
    end

    methods (Access = private)
        function report = normalizeReport(obj, value)
            if isempty(value)
                report = obj.emptyReport();
            elseif isstruct(value) && isscalar(value) && ...
                    isfield(value, 'clusters') && ...
                    isfield(value, 'cluster_signature')
                report = value;
            elseif isstruct(value)
                report = obj.analyze(value);
            else
                error('EventCluster_v3:ComparisonInput', ...
                    'Comparison inputs must be reports or event histories.');
            end
        end

        function persistentClusters = exactPersistentClusters(~, left, right)
            persistentClusters = repmat(struct('left_index', 0, ...
                'right_index', 0, ...
                'token', "", 'names', strings(0, 1)), 0, 1);
            for leftIndex = 1:left.cluster_count
                leftNames = left.clusters(leftIndex).sorted_names;
                if numel(leftNames) < 2
                    continue
                end
                for rightIndex = 1:right.cluster_count
                    rightNames = right.clusters(rightIndex).sorted_names;
                    if isequal(leftNames(:), rightNames(:))
                        entry = struct('left_index', leftIndex, ...
                            'right_index', rightIndex, ...
                            'token', left.clusters(leftIndex).token, ...
                            'names', leftNames);
                        persistentClusters(end + 1, 1) = entry; %#ok<AGROW>
                        break
                    end
                end
            end
        end

        function changes = partitionChanges(obj, source, target)
            % One source cluster represented by multiple contiguous target
            % clusters is a split.  Reversing the arguments finds merges.
            changes = repmat(struct('source_index', 0, ...
                'target_indices', zeros(0, 1), 'names', strings(0, 1), ...
                'source_token', "", 'target_tokens', strings(0, 1), ...
                'source_center', NaN, 'target_centers', zeros(0, 1), ...
                'minimum_target_center_gap', Inf, ...
                'source_spread', NaN, ...
                'center_partition_evidence', false), 0, 1);
            for sourceIndex = 1:source.cluster_count
                sourceNames = source.clusters(sourceIndex).sorted_names(:);
                if numel(sourceNames) < 2
                    continue
                end
                found = false;
                for first = 1:target.cluster_count
                    combined = strings(0, 1);
                    for last = first:target.cluster_count
                        combined = [combined; ...
                            target.clusters(last).sorted_names(:)]; %#ok<AGROW>
                        if last > first && ...
                                isequal(sort(combined), sourceNames)
                            indices = (first:last).';
                            targetCenters = reshape([ ...
                                target.clusters(indices).center_time], [], 1);
                            targetCenterGap = min(diff(targetCenters));
                            sourceSpread = source.clusters(sourceIndex). ...
                                maximum_intra_cluster_spread;
                            centerEvidence = numel(targetCenters) >= 2 && ...
                                isfinite(targetCenterGap) && ...
                                targetCenterGap > 0 && ...
                                targetCenterGap <= ...
                                    obj.collisionTolerance(targetCenters) && ...
                                isfinite(sourceSpread) && ...
                                sourceSpread <= source.clusters( ...
                                    sourceIndex).adaptive_time_tolerance;
                            entry = struct('source_index', sourceIndex, ...
                                'target_indices', indices, ...
                                'names', sourceNames, ...
                                'source_token', ...
                                    source.clusters(sourceIndex).token, ...
                                'target_tokens', reshape(string( ...
                                    {target.clusters(indices).token}), [], 1), ...
                                'source_center', source.clusters( ...
                                    sourceIndex).center_time, ...
                                'target_centers', targetCenters, ...
                                'minimum_target_center_gap', ...
                                    targetCenterGap, ...
                                'source_spread', sourceSpread, ...
                                'center_partition_evidence', ...
                                    centerEvidence);
                            changes(end + 1, 1) = entry; %#ok<AGROW>
                            found = true;
                            break
                        end
                        if numel(combined) >= numel(sourceNames)
                            break
                        end
                    end
                    if found
                        break
                    end
                end
            end
        end

        function tolerance = adaptiveTolerance(obj, firstTime, lastTime)
            scale = max([1, abs(firstTime), abs(lastTime)]);
            tolerance = max(obj.AbsoluteTimeTolerance, ...
                obj.RelativeTimeTolerance * scale);
            tolerance = max(tolerance, 128 * eps(scale));
        end

        function tolerance = sectionTolerance(obj)
            tolerance = obj.SectionCoincidenceTolerance;
            if isempty(tolerance)
                tolerance = obj.AbsoluteTimeTolerance;
            end
        end

        function tolerance = collisionTolerance(obj, times)
            scale = max([1; abs(times(:))]);
            tolerance = max(obj.CollisionTimeTolerance, ...
                obj.RelativeTimeTolerance * scale);
        end

        function phase = relativePhase(~, time, initialTime, period)
            if isfinite(period) && period > 0
                phase = mod(time - initialTime, period) / period;
            else
                phase = NaN;
            end
        end

        function gap = minimumCenterGap(~, centers, initialTime, period)
            if numel(centers) < 2
                gap = Inf;
                return
            end
            gaps = diff(centers);
            if isfinite(period) && period > 0
                wrapGap = period - (centers(end) - centers(1));
                if wrapGap >= -128 * eps(max(1, abs(initialTime) + period))
                    gaps = [gaps; max(0, wrapGap)];
                end
            end
            gap = min(gaps);
        end

        function signature = canonicalSignature(~, tokens)
            if isempty(tokens)
                signature = "";
                return
            end
            if isscalar(tokens)
                signature = tokens(1);
                return
            end
            rotations = strings(numel(tokens), 1);
            for index = 1:numel(tokens)
                rotation = [tokens(index:end); tokens(1:index-1)];
                rotations(index) = strjoin(rotation, ">");
            end
            [~, order] = sort(lower(rotations));
            signature = rotations(order(1));
        end

        function times = eventTimes(~, history)
            if isfield(history, 'time')
                times = reshape([history.time], [], 1);
            elseif isfield(history, 'event_time')
                times = reshape([history.event_time], [], 1);
            else
                error('EventCluster_v3:MissingTime', ...
                    'Event history has neither time nor event_time.');
            end
        end

        function names = eventNames(~, history)
            names = strings(numel(history), 1);
            for index = 1:numel(history)
                if isfield(history, 'guard_name') && ...
                        ~isempty(history(index).guard_name)
                    names(index) = string(history(index).guard_name);
                elseif isfield(history, 'type') && ...
                        ~isempty(history(index).type)
                    names(index) = string(history(index).type);
                else
                    names(index) = "unnamed-event";
                end
            end
        end

        function history = physicalHistory(~, history)
            if isempty(history)
                history = struct([]);
                return
            end
            if ~isstruct(history)
                error('EventCluster_v3:History', ...
                    'Event history must be a structure array.');
            end
            if isfield(history, 'is_stop')
                history = history(~reshape([history.is_stop], [], 1));
            end
        end

        function report = emptyReport(~)
            report = struct( ...
                'clusters', struct([]), ...
                'cluster_count', 0, ...
                'members', {{}}, ...
                'cluster_names', {{}}, ...
                'cluster_center_times', zeros(0, 1), ...
                'maximum_intra_cluster_spreads', zeros(0, 1), ...
                'maximum_intra_cluster_spread', 0, ...
                'minimum_intercluster_gap', Inf, ...
                'cluster_relative_phase', zeros(0, 1), ...
                'cluster_signature', "", ...
                'cyclic_cluster_signature', "", ...
                'section_cluster_coincidence', false, ...
                'section_coincident_cluster_indices', zeros(0, 1), ...
                'minimum_section_cluster_gap', Inf, ...
                'cluster_split_merge_diagnostics', struct( ...
                    'reference_supplied', false, ...
                    'has_split', false, 'has_merge', false, ...
                    'has_collision', false, ...
                    'has_persistent_simultaneous_cluster', false), ...
                'section_times', zeros(0, 1), ...
                'section_names', strings(0, 1), ...
                'initial_time', 0, 'period', NaN, ...
                'active_tolerances', struct());
        end

        function cluster = emptyCluster(~)
            cluster = struct( ...
                'index', 0, ...
                'member_indices', zeros(0, 1), ...
                'sorted_member_indices', zeros(0, 1), ...
                'members', struct([]), ...
                'names', strings(0, 1), ...
                'sorted_names', strings(0, 1), ...
                'center_time', NaN, ...
                'maximum_intra_cluster_spread', NaN, ...
                'adaptive_time_tolerance', NaN, ...
                'relative_phase', NaN, ...
                'token', "", ...
                'section_coincident', false, ...
                'section_indices', zeros(0, 1), ...
                'section_names', strings(0, 1), ...
                'minimum_section_distance', Inf);
        end

        function value = member(~, source, names, fallback)
            value = fallback;
            for index = 1:numel(names)
                if isfield(source, names{index})
                    value = source.(names{index});
                    return
                end
            end
        end

        function obj = applyOptions(obj, options)
            names = fieldnames(options);
            for index = 1:numel(names)
                obj = obj.setOption(names{index}, options.(names{index}));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin), 2) ~= 0
                error('EventCluster_v3:NameValue', ...
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
                error('EventCluster_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(list{match}) = value;
        end

        function validateOptions(obj)
            validateattributes(obj.AbsoluteTimeTolerance, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'nonnegative'});
            validateattributes(obj.RelativeTimeTolerance, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'nonnegative'});
            validateattributes(obj.CollisionTimeTolerance, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'nonnegative'});
            if ~isempty(obj.SectionCoincidenceTolerance)
                validateattributes(obj.SectionCoincidenceTolerance, ...
                    {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
            end
        end
    end
end
