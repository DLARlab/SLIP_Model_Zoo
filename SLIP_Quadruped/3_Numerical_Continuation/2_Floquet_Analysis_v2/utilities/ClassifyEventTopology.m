function topology = ClassifyEventTopology(eventTimes, options)
%CLASSIFYEVENTTOPOLOGY Describe the labeled event order over one stride.
%
%   TOPOLOGY = CLASSIFYEVENTTOPOLOGY(E, OPTIONS) uses E(9) as the stride
%   period, wraps E(1:8) into [0,E(9)), and includes the terminal apex as
%   event 9 at normalized phase one.  Nominal events separated by no more
%   than TopologyClusterTolerance*max(1,T) form a cluster.

    if nargin < 2
        options = struct();
    end
    options = ResolveFloquetOptions(options);

    labels = {'BL-TD','BL-LO','FL-TD','FL-LO', ...
              'BR-TD','BR-LO','FR-TD','FR-LO','APEX'};
    E = eventTimes(:);

    topology = struct();
    topology.valid = false;
    topology.rejectionReasons = {};
    topology.labels = labels;
    topology.mode = options.TopologyMode;
    topology.rawEventTimes = E;

    if numel(E) ~= 9 || any(~isfinite(E))
        topology.rejectionReasons{end+1} = ...
            'The event vector must contain nine finite values.';
        return;
    end

    period = E(9);
    if ~(isfinite(period) && period > 0)
        topology.rejectionReasons{end+1} = ...
            'The apex return time must be positive and finite.';
        return;
    end

    normalizedTimes = [mod(E(1:8), period); period];
    phases = normalizedTimes ./ period;
    eventNumbers = (1:9).';
    sortedTable = sortrows([normalizedTimes, eventNumbers], [1 2]);
    sortedTimes = sortedTable(:,1);
    sortedEventNumbers = sortedTable(:,2);

    clusterTolerance = options.TopologyClusterTolerance * max(1, period);
    clusterIdSorted = ones(9,1);
    clusterCount = 1;
    for i = 2:9
        if sortedTimes(i) - sortedTimes(i-1) > clusterTolerance
            clusterCount = clusterCount + 1;
        end
        clusterIdSorted(i) = clusterCount;
    end

    clusters = cell(clusterCount,1);
    clusterTimes = cell(clusterCount,1);
    clusterIdByEvent = zeros(9,1);
    for i = 1:clusterCount
        members = sortedEventNumbers(clusterIdSorted == i);
        clusters{i} = members(:).';
        clusterTimes{i} = sortedTimes(clusterIdSorted == i).';
        clusterIdByEvent(members) = i;
    end

    sortedLabels = labels(sortedEventNumbers);
    signatureParts = cell(1, clusterCount);
    for i = 1:clusterCount
        memberLabels = labels(clusters{i});
        signatureParts{i} = strjoin(memberLabels, '+');
    end

    topology.valid = true;
    topology.period = period;
    topology.normalizedEventTimes = normalizedTimes;
    topology.normalizedPhases = phases;
    topology.sortedTimes = sortedTimes;
    topology.sortedPhases = sortedTimes ./ period;
    topology.sortedEventNumbers = sortedEventNumbers;
    topology.sortedLabels = sortedLabels;
    topology.clusterTolerance = clusterTolerance;
    topology.clusterCount = clusterCount;
    topology.clusters = clusters;
    topology.clusterTimes = clusterTimes;
    topology.clusterIdByEvent = clusterIdByEvent;
    topology.signature = strjoin(signatureParts, ' -> ');
end
