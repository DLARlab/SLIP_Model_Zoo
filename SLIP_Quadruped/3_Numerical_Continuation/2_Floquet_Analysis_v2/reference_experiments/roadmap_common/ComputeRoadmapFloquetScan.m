function scan = ComputeRoadmapFloquetScan(branchFile, sampleIndices, options)
%COMPUTEROADMAPFLOQUETSCAN Scan one parent-only roadmap window.
%
%   SCAN = COMPUTEROADMAPFLOQUETSCAN(BRANCHFILE,INDICES,OPTIONS) computes
%   validated 12-by-12 reduced Poincare-map derivatives, tracks their
%   multipliers, and runs DetectBifurcation.  This function accepts only a
%   parent file and parent indices.  No daughter branch is loaded or used.

    if nargin < 3 || isempty(options)
        options = struct();
    end
    opts = ParseOptions(options);
    [branchFile,branch,indices] = LoadInputs(branchFile,sampleIndices);
    count = numel(indices);
    coordinate = branch(1,indices);
    sectionStates = branch([1 2 4:13],indices);

    multipliers = complex(NaN(12,count),NaN(12,count));
    eigenvectors = cell(1,count);
    matrices = cell(1,count);
    diagnostics = cell(1,count);
    accepted = false(1,count);

    if opts.Verbose
        fprintf('  parent-only scan: %s, columns %s\n', ...
            branchFile,mat2str(indices));
    end
    for k = 1:count
        column = indices(k);
        if opts.Verbose
            fprintf('    [%d/%d] column %d, dx=%.12g ... ', ...
                k,count,column,coordinate(k));
        end
        try
            [M,lambda,V,detail] = floquet.computeFDM( ...
                branch(1:22,column),branch(23:29,column), ...
                opts.FloquetOptions);
        catch exception
            M = [];
            lambda = [];
            V = [];
            detail = FailureDiagnostics(exception);
        end
        matrices{k} = M;
        diagnostics{k} = detail;
        accepted(k) = IsAccepted(M,lambda,V,detail);
        if accepted(k)
            multipliers(:,k) = lambda(:);
            eigenvectors{k} = V;
            if opts.Verbose
                fprintf('accepted (FD %.3e, FB %.3e)\n', ...
                    NestedNumber(detail,{'derivativeConvergence', ...
                        'finestRelativeError'},NaN), ...
                    FieldNumber(detail,'maximumFinestForwardBackwardError',NaN));
            end
        elseif opts.Verbose
            fprintf('rejected: %s\n',RejectionMessage(detail));
        end
    end

    [eventTopologies,topologyValid,intervalTopologyConsistent, ...
        topologyComparisons] = CollectBaseTopology( ...
        diagnostics,accepted,indices,opts.FloquetOptions);

    trackOptions = opts.TrackOptions;
    trackOptions.Reliability = accepted;
    trackOptions.IntervalReliability = ...
        diff(indices) == 1 & intervalTopologyConsistent;
    [tracks,trackingDiagnostics] = ...
        floquet.internal.tracking.trackMultipliers( ...
        multipliers,eigenvectors,trackOptions);

    detectorOptions = opts.DetectorOptions;
    detectorOptions.Reliability = accepted & topologyValid;
    detectorOptions.EventTopologyConsistent = topologyValid;
    detectorOptions.IntervalReliability = ...
        diff(indices) == 1 & intervalTopologyConsistent;
    detectorOptions.BranchStates = sectionStates;
    detectorOptions.ParameterValues = branch(23:29,indices);
    [candidates,detectorReport] = floquet.detectBifurcations( ...
        tracks,coordinate,detectorOptions);

    scan = struct();
    scan.version = 'roadmap-parent-scan-v1';
    scan.generatedAt = Timestamp();
    scan.branchFile = branchFile;
    scan.sampleIndices = indices;
    scan.continuationCoordinate = coordinate;
    scan.sectionStates = sectionStates;
    scan.parameters = branch(23:29,indices);
    scan.accepted = accepted;
    scan.matrices = matrices;
    scan.multipliers = multipliers;
    scan.eigenvectors = eigenvectors;
    scan.diagnostics = diagnostics;
    scan.eventTopologies = eventTopologies;
    scan.topologyValid = topologyValid;
    scan.intervalTopologyConsistent = intervalTopologyConsistent;
    scan.topologyComparisons = topologyComparisons;
    scan.tracks = tracks;
    scan.trackingDiagnostics = trackingDiagnostics;
    scan.candidates = candidates;
    scan.detectorReport = detectorReport;
    scan.convergence = CollectConvergence(diagnostics);
    scan.options = opts;
    scan.parentOnly = true;
    scan.daughterDataLoaded = false;
end

function opts = ParseOptions(options)
    if ~isstruct(options) || ~isscalar(options)
        error('ComputeRoadmapFloquetScan:InvalidOptions', ...
            'options must be a scalar structure.');
    end
    defaults = struct();
    defaults.FloquetOptions = struct( ...
        'PerturbationMagnitude',5e-7, ...
        'PerturbationFactors',[8 4 2 1], ...
        'TopologyMode','clustered', ...
        'RejectOnDerivativeNonconvergence',true, ...
        'RejectOnForwardBackwardMismatch',true, ...
        'ErrorOnFailure',false);
    defaults.TrackOptions = struct( ...
        'MultiplierWeight',1,'EigenvectorWeight',0.25, ...
        'ComputeAssignmentGap',true);
    defaults.DetectorOptions = struct( ...
        'PersistencePoints',1, ...
        'RequireBranchTangentForPlusOne',true, ...
        'RejectTrivialBranchTangent',true, ...
        'RejectAmbiguousBranchTangent',true);
    defaults.Verbose = true;

    opts = defaults;
    names = fieldnames(options);
    allowed = fieldnames(defaults);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k},allowed),1);
        if isempty(hit)
            error('ComputeRoadmapFloquetScan:UnknownOption', ...
                'Unknown option %s.',names{k});
        end
        opts.(allowed{hit}) = options.(names{k});
    end
    nested = {'FloquetOptions','TrackOptions','DetectorOptions'};
    for k = 1:numel(nested)
        if ~isstruct(opts.(nested{k})) || ~isscalar(opts.(nested{k}))
            error('ComputeRoadmapFloquetScan:NestedOptions', ...
                '%s must be a scalar structure.',nested{k});
        end
    end
    opts.Verbose = ValidateLogical(opts.Verbose,'Verbose');
end

function [filename,branch,indices] = LoadInputs(filename,indices)
    if ~(ischar(filename) || (isstring(filename) && isscalar(filename)))
        error('ComputeRoadmapFloquetScan:BranchFile', ...
            'branchFile must be text.');
    end
    filename = char(filename);
    if ~isfile(filename)
        error('ComputeRoadmapFloquetScan:MissingBranch', ...
            'Parent branch does not exist: %s',filename);
    end
    loaded = load(filename,'results');
    validResults = isfield(loaded,'results') && isnumeric(loaded.results) && ...
        isreal(loaded.results) && size(loaded.results,1) == 29 && ...
        ~isempty(loaded.results) && all(isfinite(loaded.results(1:22,:)),'all');
    if validResults
        parameters = loaded.results(23:29,:);
        allowedInfinity = false(size(parameters));
        allowedInfinity(3,:) = isinf(parameters(3,:)) & parameters(3,:) > 0;
        validResults = all(isfinite(parameters) | allowedInfinity,'all');
    end
    if ~validResults
        error('ComputeRoadmapFloquetScan:BranchShape', ...
            ['Parent file must contain a real numeric 29-by-N results array; ' ...
             'only parameter row 25 (Para(3)) may be positive Inf.']);
    end
    branch = loaded.results;
    indices = indices(:).';
    if numel(indices) < 3 || any(~isfinite(indices)) || ...
            any(indices ~= floor(indices)) || any(indices < 1) || ...
            any(indices > size(branch,2)) || any(diff(indices) ~= 1)
        error('ComputeRoadmapFloquetScan:SampleIndices', ...
            'Use at least three consecutive valid parent branch columns.');
    end
end

function [topologies,valid,intervalConsistent,comparisons] = ...
        CollectBaseTopology(diagnostics,accepted,indices,floquetOptions)
    count = numel(diagnostics);
    topologies = cell(1,count);
    valid = false(1,count);
    intervalConsistent = false(1,max(0,count-1));
    comparisons = cell(1,max(0,count-1));
    for k = 1:count
        if ~accepted(k)
            continue
        end
        topology = NestedValue(diagnostics{k}, ...
            {'baseValidation','mapInfo','eventTopology'},[]);
        if isstruct(topology) && isfield(topology,'valid') && ...
                isscalar(topology.valid) && logical(topology.valid)
            topologies{k} = topology;
            valid(k) = true;
        end
    end
    for k = 1:numel(intervalConsistent)
        comparison = struct('consistent',false,'forward',struct(), ...
            'reverse',struct(),'reason','unavailable');
        if indices(k+1) == indices(k)+1 && valid(k) && valid(k+1)
            forward = floquet.internal.events.compareTopology( ...
                topologies{k},topologies{k+1},floquetOptions);
            reverse = floquet.internal.events.compareTopology( ...
                topologies{k+1},topologies{k},floquetOptions);
            comparison.forward = forward;
            comparison.reverse = reverse;
            comparison.consistent = forward.consistent && reverse.consistent;
            if comparison.consistent
                comparison.reason = 'bidirectionally-consistent';
            else
                comparison.reason = 'base-event-topology-changed';
            end
        elseif indices(k+1) ~= indices(k)+1
            comparison.reason = 'nonadjacent-source-columns';
        elseif ~(valid(k) && valid(k+1))
            comparison.reason = 'invalid-endpoint-topology';
        end
        intervalConsistent(k) = comparison.consistent;
        comparisons{k} = comparison;
    end
end

function value = ValidateLogical(value,name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
        error('ComputeRoadmapFloquetScan:LogicalOption', ...
            '%s must be scalar logical.',name);
    end
    value = logical(value);
end

function tf = IsAccepted(M,lambda,V,detail)
    tf = isstruct(detail) && isfield(detail,'accepted') && ...
        isscalar(detail.accepted) && logical(detail.accepted) && ...
        isequal(size(M),[12 12]) && numel(lambda) == 12 && ...
        isequal(size(V),[12 12]);
end

function detail = FailureDiagnostics(exception)
    detail = struct('accepted',false,'valid',false, ...
        'status','unexpected-exception', ...
        'rejectionReasons',{{sprintf('%s: %s', ...
            exception.identifier,exception.message)}}, ...
        'exceptionIdentifier',exception.identifier, ...
        'exceptionMessage',exception.message);
end

function message = RejectionMessage(detail)
    if isstruct(detail) && isfield(detail,'rejectionReasons') && ...
            ~isempty(detail.rejectionReasons)
        message = strjoin(detail.rejectionReasons,' | ');
    else
        message = 'no accepted reduced Floquet matrix';
    end
end

function convergence = CollectConvergence(diagnostics)
    count = numel(diagnostics);
    convergence = struct( ...
        'derivativeRelativeError',NaN(1,count), ...
        'forwardBackwardRelativeError',NaN(1,count), ...
        'periodicResidual',NaN(1,count), ...
        'timingResidual',NaN(1,count));
    for k = 1:count
        detail = diagnostics{k};
        convergence.derivativeRelativeError(k) = NestedNumber( ...
            detail,{'derivativeConvergence','finestRelativeError'},NaN);
        convergence.forwardBackwardRelativeError(k) = FieldNumber( ...
            detail,'maximumFinestForwardBackwardError',NaN);
        convergence.periodicResidual(k) = NestedNumber( ...
            detail,{'baseValidation','periodicResidualNormInf'},NaN);
        timingResidual = NestedNumber(detail, ...
            {'baseValidation','mapInfo','timingResidualNormInf'},NaN);
        if ~isfinite(timingResidual)
            % Compatibility with early saved diagnostics that placed the
            % timing residual directly on baseValidation.
            timingResidual = NestedNumber(detail, ...
                {'baseValidation','eventTimeResidualNormInf'},NaN);
        end
        convergence.timingResidual(k) = timingResidual;
    end
end

function value = NestedNumber(input,names,default)
    value = input;
    for k = 1:numel(names)
        if ~isstruct(value) || ~isfield(value,names{k})
            value = default;
            return
        end
        value = value.(names{k});
    end
    if ~(isnumeric(value) && isscalar(value))
        value = default;
    end
end

function value = NestedValue(input,names,default)
    value = input;
    for k = 1:numel(names)
        if ~isstruct(value) || ~isfield(value,names{k})
            value = default;
            return
        end
        value = value.(names{k});
    end
end

function value = FieldNumber(input,name,default)
    if isstruct(input) && isfield(input,name) && ...
            isnumeric(input.(name)) && isscalar(input.(name))
        value = input.(name);
    else
        value = default;
    end
end

function value = Timestamp()
    value = char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
end
