function comparison = CompareEventTopology(reference, candidate, options)
%COMPAREEVENTTOPOLOGY Test event-order consistency against a reference.
%
%   In strict mode the complete stable ordering of all nine labels must be
%   identical.  In clustered mode labels may permute within a reference
%   simultaneous-event cluster, while different reference clusters must
%   remain noninterleaved and strictly ordered.

    if nargin < 3
        options = struct();
    end
    options = ResolveFloquetOptions(options);

    comparison = struct();
    comparison.valid = false;
    comparison.consistent = false;
    comparison.mode = options.TopologyMode;
    comparison.rejectionReasons = {};
    comparison.referenceSignature = '';
    comparison.candidateSignature = '';
    comparison.minimumInterclusterPhaseGap = NaN;
    comparison.maximumReferenceClusterPhaseSpread = NaN;
    comparison.referenceClusterSplitSensitivity = [];

    if ~isstruct(reference) || ~isfield(reference, 'valid') || ~reference.valid
        comparison.rejectionReasons{end+1} = ...
            'The reference event topology is absent or invalid.';
        return;
    end
    if ~isstruct(candidate) || ~isfield(candidate, 'valid') || ~candidate.valid
        comparison.rejectionReasons{end+1} = ...
            'The candidate event topology is absent or invalid.';
        return;
    end
    required = {'sortedEventNumbers','clusters','normalizedPhases','signature'};
    for i = 1:numel(required)
        if ~isfield(reference, required{i}) || ~isfield(candidate, required{i})
            comparison.rejectionReasons{end+1} = ...
                'A topology structure is missing required fields.';
            return;
        end
    end

    comparison.valid = true;
    comparison.referenceSignature = reference.signature;
    comparison.candidateSignature = candidate.signature;

    if strcmp(options.TopologyMode, 'strict')
        sameOrder = isequal(reference.sortedEventNumbers(:), ...
            candidate.sortedEventNumbers(:));
        samePartition = SameClusterPartition(reference.clusters, candidate.clusters);
        comparison.consistent = sameOrder && samePartition;
        if ~comparison.consistent
            if ~sameOrder
                comparison.rejectionReasons{end+1} = sprintf( ...
                    'Strict event order changed from [%s] to [%s].', ...
                    reference.signature, candidate.signature);
            end
            if ~samePartition
                comparison.rejectionReasons{end+1} = sprintf( ...
                    ['Strict event clusters changed from [%s] to [%s]; ' ...
                     'simultaneous-event membership must be preserved.'], ...
                    reference.signature, candidate.signature);
            end
        end
        return;
    end

    candidatePhases = candidate.normalizedPhases(:);
    clusters = reference.clusters;
    orderTolerance = options.TopologyOrderTolerance;
    minimumGap = Inf;
    splitSensitivity = zeros(numel(clusters),1);

    for i = 1:numel(clusters)
        memberPhases = candidatePhases(clusters{i});
        splitSensitivity(i) = max(memberPhases) - min(memberPhases);
    end
    comparison.referenceClusterSplitSensitivity = splitSensitivity;
    comparison.maximumReferenceClusterPhaseSpread = max(splitSensitivity);

    for i = 1:(numel(clusters)-1)
        leftMembers = clusters{i};
        rightMembers = clusters{i+1};
        leftMaximum = max(candidatePhases(leftMembers));
        rightMinimum = min(candidatePhases(rightMembers));
        gap = rightMinimum - leftMaximum;
        minimumGap = min(minimumGap, gap);
        if ~(isfinite(gap) && gap > orderTolerance)
            comparison.rejectionReasons{end+1} = sprintf( ...
                ['Reference event clusters %d and %d merged, crossed, or ' ...
                 'interleaved (normalized phase gap %.3e).'], i, i+1, gap);
        end
    end

    if isinf(minimumGap)
        minimumGap = NaN;
    end
    comparison.minimumInterclusterPhaseGap = minimumGap;
    comparison.consistent = isempty(comparison.rejectionReasons);
end

function same = SameClusterPartition(referenceClusters, candidateClusters)
    if numel(referenceClusters) ~= numel(candidateClusters)
        same = false;
        return;
    end
    same = true;
    for i = 1:numel(referenceClusters)
        if ~isequal(sort(referenceClusters{i}(:)), ...
                sort(candidateClusters{i}(:)))
            same = false;
            return;
        end
    end
end
