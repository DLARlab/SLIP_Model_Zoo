function [analysis, outputFile] = analyzeBranch( ...
        branchData, branchSelection, userOptions)
%ANALYZEFLOQUETBRANCH Canonical parent-only Floquet branch analysis.
%
%   ANALYSIS = ANALYZEFLOQUETBRANCH(BRANCH, SELECTION, OPTIONS) accepts a
%   real 29-by-N v2 continuation branch, a scalar structure containing that
%   array, or a MAT file containing it.  [] selects every branch column in
%   its original continuation order.  Selected columns are never compacted
%   after a failed calculation: rejected points remain explicit gaps.
%
%   At every selected point this routine calls floquet.computeFDM, retains
%   only validated derivatives of the reduced apex-to-apex Poincare map,
%   and records the event times solved by the production timing solver.
%   Base-orbit event topologies are compared independently at adjacent
%   source columns.  Multiplier tracking restarts after a rejected point, a
%   skipped source column, or a topology change.  floquet.detectBifurcations is then
%   applied to those reliable segments with neighboring-point persistence
%   and branch-tangent classification of +1 crossings.
%
%   A state secant is a valid trivial +1 branch tangent only for a family at
%   fixed physical parameters.  Therefore rows 23:29 are checked on every
%   reliable segment with a scale-aware tolerance.  Tangents are withheld
%   on varying-parameter segments, so the default required-tangent policy
%   rejects rather than misclassifies their +1 crossings.
%
%   Optional checkpoints contain raw per-point computation state, never a
%   final analysis.  Resume requires exact schema, source/branch SHA-256,
%   selected-column, dimension, evaluator, resolved FDM-option, MATLAB, and
%   implementation-fingerprint compatibility.  Tracking and bifurcation
%   detection are always rerun after the point scan is complete.
%
%   No daughter branch, expected gait label, expected bifurcation type, or
%   preselected historical window is accepted by this interface.
%
%   Important OPTIONS fields are:
%       FloquetOptions              passed to floquet.computeFDM
%       TrackOptions                passed to the internal multiplier tracker
%       DetectorOptions             numerical DetectBifurcation options
%       ContinuationParameter       full-branch or selected-point vector
%       ContinuationParameterRow    branch row used by default (1)
%       ContinuationParameterName   descriptive label
%       ParameterConstancyTolerance scale-wise tangent guard (1e-10)
%       ContinueOnFailure           preserve rejected gaps (true)
%       CatchComputeExceptions      convert point exceptions to gaps (true)
%       StoreFullDiagnostics        retain all FDM diagnostics (false)
%       CheckpointFile              optional explicit .mat path ('')
%       CheckpointEvery             save every N completed points (1)
%       ResumeFromCheckpoint        require and resume that checkpoint (false)
%       DeleteCheckpointOnSuccess   delete verified owned checkpoint (false)
%       OverwriteCheckpoint         replace an existing new-run file (false)
%       SaveAnalysis                save scalar variable `analysis` (false)
%       OutputFile                  required when SaveAnalysis is true
%       Overwrite                   permit replacing OutputFile (false)
%       Verbose                     print point progress (true)
%
%   ComputeFunction and AllowNonProductionComputeFunction form an explicit
%   test/integration hook.  Production analyses should leave them at
%   @floquet.computeFDM and false; provenance records the actual evaluator.
%
%   [ANALYSIS, FILE] also returns the absolute saved filename, or '' when
%   SaveAnalysis is false.

    if nargin < 1
        error('AnalyzeFloquetBranch:MissingBranch', ...
            'A v2 continuation branch is required.');
    end
    if nargin < 2
        branchSelection = [];
    end
    if nargin < 3 || isempty(userOptions)
        userOptions = struct();
    end

    analysisRoot = fileparts(fileparts(mfilename('fullpath')));
    AddRequiredPaths(analysisRoot);
    opts = ResolveAnalysisOptions(userOptions);
    [branch, source] = ResolveBranchData(branchData);
    ValidateBranch(branch);
    indices = ResolveSelection(branchSelection, size(branch,2));
    coordinate = ResolveContinuationCoordinate(opts, branch, indices);
    source = CompleteSource(source, branch, indices, opts);
    [source.branchSHA256,source.branchFingerprintStatus] = ...
        NumericArraySHA256(branch);

    pointCount = numel(indices);
    stateDimension = 12;
    matrices = NaN(stateDimension,stateDimension,pointCount);
    rawMultipliers = complex(NaN(stateDimension,pointCount), ...
        NaN(stateDimension,pointCount));
    rawEigenvectors = cell(1,pointCount);
    solvedEventTimes = NaN(9,pointCount);
    baseTopologies = cell(1,pointCount);
    topologySignatures = repmat({''},1,pointCount);
    diagnostics = cell(1,pointCount);
    accepted = false(1,pointCount);
    quality = repmat(EmptyPointQuality(),1,pointCount);
    completed = false(1,pointCount);

    checkpointFile = '';
    checkpointCompatibility = struct();
    checkpointInfo = EmptyCheckpointInfo();
    if ~isempty(strtrim(opts.CheckpointFile))
        checkpointFile = CanonicalMatFile(opts.CheckpointFile, ...
            'AnalyzeFloquetBranch:CheckpointExtension','CheckpointFile');
        opts.CheckpointFile = checkpointFile;
        if ~isempty(source.file) && SameFilePath(checkpointFile,source.file)
            error('AnalyzeFloquetBranch:CheckpointIsSource', ...
                'CheckpointFile must not overwrite the source branch MAT file.');
        end
        checkpointCompatibility = BuildCheckpointCompatibility( ...
            source,indices,opts,analysisRoot,stateDimension);
        [checkpointState,checkpointInfo] = PrepareCheckpoint( ...
            checkpointFile,checkpointCompatibility,opts,pointCount, ...
            stateDimension);
        if checkpointInfo.resumed
            matrices = checkpointState.matrices;
            rawMultipliers = checkpointState.rawMultipliers;
            rawEigenvectors = checkpointState.rawEigenvectors;
            solvedEventTimes = checkpointState.solvedEventTimes;
            baseTopologies = checkpointState.baseTopologies;
            topologySignatures = checkpointState.topologySignatures;
            diagnostics = checkpointState.diagnostics;
            accepted = checkpointState.accepted;
            quality = checkpointState.quality;
            completed = checkpointState.completed;
            NotifyStatus(opts,'resumed',nnz(completed),pointCount, ...
                indices(max(1,nnz(completed))), ...
                sprintf('Resumed %d completed points from %s.', ...
                    nnz(completed),checkpointFile));
            if opts.Verbose
                fprintf('Resumed %d/%d completed branch points from %s\n', ...
                    nnz(completed),pointCount,checkpointFile);
            end
        end
    end

    outputFile = '';
    if opts.SaveAnalysis
        outputFile = CanonicalOutputFile(opts.OutputFile);
        if ~isempty(source.file) && SameFilePath(outputFile,source.file)
            error('AnalyzeFloquetBranch:OutputIsSource', ...
                'OutputFile must not overwrite the source branch MAT file.');
        end
        if ~isempty(checkpointFile) && SameFilePath(outputFile,checkpointFile)
            error('AnalyzeFloquetBranch:OutputIsCheckpoint', ...
                'OutputFile and CheckpointFile must be different files.');
        end
        if isfile(outputFile) && ~opts.Overwrite
            error('AnalyzeFloquetBranch:OutputExists', ...
                'Output file already exists: %s',outputFile);
        end
    end

    startTime = tic;
    for localIndex = 1:pointCount
        if completed(localIndex)
            continue
        end
        branchIndex = indices(localIndex);
        NotifyStatus(opts,'computing',localIndex,pointCount,branchIndex, ...
            'Evaluating the validated reduced Poincare-map derivative.');
        if opts.Verbose
            fprintf('Floquet branch [%d/%d], column %d, %s=%.12g ... ', ...
                localIndex,pointCount,branchIndex, ...
                opts.ContinuationParameterName,coordinate(localIndex));
        end

        try
            [M,lambda,V,detail] = opts.ComputeFunction( ...
                branch(1:22,branchIndex),branch(23:29,branchIndex), ...
                opts.FloquetOptions);
        catch exception
            if ~opts.CatchComputeExceptions
                rethrow(exception);
            end
            M = [];
            lambda = [];
            V = [];
            detail = ExceptionDiagnostics(exception);
        end

        [times,topology] = ExtractBaseMapMetadata(detail);
        if ~isempty(times)
            solvedEventTimes(:,localIndex) = times;
        end
        if ~isempty(topology)
            baseTopologies{localIndex} = topology;
            topologySignatures{localIndex} = topology.signature;
        end

        [pointAccepted,validationReason] = ValidateFloquetResult( ...
            M,lambda,V,detail,times,topology,stateDimension);
        accepted(localIndex) = pointAccepted;
        if pointAccepted
            matrices(:,:,localIndex) = M;
            rawMultipliers(:,localIndex) = lambda(:);
            rawEigenvectors{localIndex} = V;
        end
        quality(localIndex) = SummarizePoint( ...
            localIndex,branchIndex,detail,pointAccepted,validationReason, ...
            times,topology);
        % A checkpoint always carries the complete point diagnostics, even
        % when the final compact analysis omits them.
        diagnostics{localIndex} = detail;
        completed(localIndex) = true;

        if opts.Verbose
            if pointAccepted
                fprintf('accepted (FD %.3e, FB %.3e)\n', ...
                    quality(localIndex).DerivativeRelativeError, ...
                    quality(localIndex).ForwardBackwardRelativeError);
            else
                fprintf('rejected: %s\n',quality(localIndex).Message);
            end
        end
        forceCheckpoint = ~pointAccepted && ~opts.ContinueOnFailure;
        if ~isempty(checkpointFile) && (forceCheckpoint || ...
                mod(nnz(completed),opts.CheckpointEvery) == 0 || ...
                all(completed))
            checkpointState = CaptureCheckpointState(completed,matrices, ...
                rawMultipliers,rawEigenvectors,solvedEventTimes, ...
                baseTopologies,topologySignatures,diagnostics,accepted,quality);
            WriteCheckpointFile(checkpointFile,checkpointCompatibility, ...
                checkpointState,opts,checkpointInfo.createdAt);
            checkpointInfo.writeCount = checkpointInfo.writeCount + 1;
            checkpointInfo.lastSavedCompletedCount = nnz(completed);
        end

        if ~pointAccepted
            NotifyStatus(opts,'rejected',localIndex,pointCount,branchIndex, ...
                quality(localIndex).Message);
        end

        if forceCheckpoint
            error('AnalyzeFloquetBranch:PointRejected', ...
                'Branch column %d was rejected: %s', ...
                branchIndex,quality(localIndex).Message);
        end
    end

    [topologyComparison,topologyConsistent] = CompareAdjacentTopologies( ...
        baseTopologies,indices,opts.FloquetOptions);
    sourceConsecutive = diff(indices) == 1;
    intervalReliability = sourceConsecutive & topologyConsistent & ...
        accepted(1:end-1) & accepted(2:end);
    [segments,segmentId] = BuildReliableSegments( ...
        accepted,intervalReliability,indices,topologySignatures);
    [segments,fixedParameterSegment,parameterConstancy] = ...
        AssessSegmentParameterConstancy(segments, ...
            branch(23:29,indices),opts.ParameterConstancyTolerance);

    sectionStates = branch([1 2 4:13],indices);
    branchTangents = SegmentTangents( ...
        sectionStates,segments,fixedParameterSegment);
    [tracks,trackingDiagnostics] = TrackReliableSegments( ...
        rawMultipliers,rawEigenvectors,segments,accepted, ...
        intervalReliability,opts.TrackOptions);

    detectorOptions = opts.DetectorOptions;
    detectorOptions.Reliability = accepted;
    detectorOptions.IntervalReliability = intervalReliability;
    detectorOptions.EventTopologyConsistent = topologyConsistent;
    detectorOptions.BranchTangents = branchTangents;
    if ~HasCaseInsensitiveField(detectorOptions,'StateScale')
        scaleFloor = [1;1;0.5*ones(10,1)];
        detectorOptions.StateScale = max( ...
            abs(sectionStates),repmat(scaleFloor,1,pointCount));
    end
    detectorOptions.ParameterValues = branch(23:29,indices);
    [candidates,detectorReport] = floquet.detectBifurcations( ...
        tracks,coordinate,detectorOptions);
    candidates = AnnotateCandidates( ...
        candidates,indices,branch(23:29,indices),size(branch,2));
    detectorReport.Candidates = candidates;
    detectorReport.Rejected = AnnotateDetectorRejections( ...
        detectorReport.Rejected,indices);
    detectorReport.RejectedDiagnostics = detectorReport.Rejected;

    rejectedPoints = BuildRejectedPointReport(quality);
    rejectedIntervals = BuildRejectedIntervalReport( ...
        accepted,sourceConsecutive,topologyConsistent, ...
        topologyComparison,indices);
    convergence = CollectConvergence(quality);

    coverage = BuildCoverage(indices,size(branch,2));
    scientificAuthority = opts.ProductionEvaluator && ...
        coverage.fullOrderedParentCoverage;

    analysis = struct();
    analysis.version = 'floquet-branch-analysis-v2';
    analysis.algorithmID = 'reduced-poincare-fdm-v2-canonical-branch-scan';
    analysis.generatedAt = Timestamp();
    analysis.elapsedSeconds = toc(startTime);
    analysis.status = AnalysisStatus(accepted);
    analysis.parentOnly = true;
    analysis.daughterDataLoaded = false;
    analysis.coverage = coverage;
    analysis.fullParentCoverage = coverage.fullParentCoverage;
    analysis.fullOrderedParentCoverage = ...
        coverage.fullOrderedParentCoverage;
    analysis.scientificAuthority = scientificAuthority;
    if scientificAuthority
        analysis.analysisRole = ...
            'canonical-full-parent-production-discovery';
    elseif opts.ProductionEvaluator
        analysis.analysisRole = 'diagnostic-production-subset-scan';
    else
        analysis.analysisRole = 'diagnostic-nonproduction-scan';
    end
    analysis.source = source;
    analysis.provenance = BuildProvenance( ...
        source,opts,coverage,scientificAuthority,analysis.analysisRole);
    checkpointInfo.enabled = ~isempty(checkpointFile);
    checkpointInfo.file = checkpointFile;
    checkpointInfo.compatibilitySchema = NestedValue( ...
        checkpointCompatibility,{'schemaVersion'},'');
    checkpointInfo.finalCompletedCount = nnz(completed);
    checkpointInfo.partialCheckpointUsedAsFinalAnalysis = false;
    checkpointInfo.deleteOnSuccessRequested = opts.DeleteCheckpointOnSuccess;
    checkpointInfo.deletedOnSuccess = false;
    checkpointInfo.retained = ~isempty(checkpointFile) && ...
        isfile(checkpointFile);
    checkpointInfo.deletionPending = ~isempty(checkpointFile) && ...
        opts.DeleteCheckpointOnSuccess;
    checkpointInfo.savedMetadataMoment = ...
        'immediately before optional post-save checkpoint deletion';
    analysis.provenance.checkpoint = checkpointInfo;
    analysis.provenance.branchTangentPolicy = [ ...
        'state secants classify +1 modes only on reliable segments whose ' ...
        'seven physical parameter rows are scale-wise constant'];
    analysis.options = SerializableAnalysisOptions(opts);
    analysis.branchIndices = indices;
    analysis.sampleIndices = indices; % Backward-friendly experiment alias.
    analysis.continuationCoordinate = coordinate;
    analysis.continuationParameter = coordinate;
    analysis.continuationParameterName = opts.ContinuationParameterName;
    analysis.solutions = branch(1:22,indices);
    analysis.states = branch(1:13,indices);
    analysis.sectionStates = sectionStates;
    analysis.inputEventTimeGuesses = branch(14:22,indices);
    analysis.solvedEventTimes = solvedEventTimes;
    analysis.parameters = branch(23:29,indices);
    analysis.matrices = matrices;
    analysis.floquetMatrices = matrices;
    analysis.rawMultipliers = rawMultipliers;
    analysis.rawEigenvalues = rawMultipliers;
    analysis.rawEigenvectors = rawEigenvectors;
    analysis.accepted = accepted;
    analysis.pointQuality = quality;
    analysis.convergence = convergence;
    analysis.baseEventTopologies = baseTopologies;
    analysis.eventTopologySignatures = topologySignatures;
    analysis.eventTopologyPolicy = [ ...
        'adjacent source columns must pass CompareEventTopology in both ' ...
        'directions; accepted point status alone is insufficient'];
    analysis.adjacentTopologyComparisons = topologyComparison;
    analysis.adjacentTopologyConsistent = topologyConsistent;
    analysis.sourceColumnsConsecutive = sourceConsecutive;
    analysis.intervalReliability = intervalReliability;
    analysis.segments = segments;
    analysis.segmentIdByPoint = segmentId;
    analysis.fixedPhysicalParameterSegment = fixedParameterSegment;
    analysis.parameterConstancy = parameterConstancy;
    analysis.branchTangents = branchTangents;
    analysis.tracks = tracks;
    analysis.trackingDiagnostics = trackingDiagnostics;
    analysis.candidates = candidates;
    analysis.detectorReport = detectorReport;
    analysis.rejectedReport = struct( ...
        'points',rejectedPoints, ...
        'intervals',rejectedIntervals, ...
        'pointCount',numel(rejectedPoints), ...
        'intervalCount',numel(rejectedIntervals));
    analysis.quality = BuildQualitySummary( ...
        accepted,topologyConsistent,intervalReliability,segments,quality);
    analysis.quality.fixedPhysicalParameterSegmentCount = ...
        nnz(fixedParameterSegment);
    analysis.quality.variablePhysicalParameterSegmentCount = ...
        nnz(~fixedParameterSegment);
    analysis.limitations = KnownLimitations(opts);
    if opts.StoreFullDiagnostics
        analysis.pointDiagnostics = diagnostics;
    else
        analysis.pointDiagnostics = {};
    end

    if opts.SaveAnalysis
        analysis.outputFile = outputFile;
        WriteAnalysisFile(outputFile,analysis,opts.Overwrite);
        NotifyStatus(opts,'saved',pointCount,pointCount,indices(end), ...
            ['Saved canonical branch analysis: ' outputFile]);
    else
        analysis.outputFile = '';
    end

    if ~isempty(checkpointFile) && opts.DeleteCheckpointOnSuccess
        DeleteOwnedCheckpoint(checkpointFile,checkpointCompatibility);
        analysis.provenance.checkpoint.deletedOnSuccess = true;
        analysis.provenance.checkpoint.retained = false;
        analysis.provenance.checkpoint.deletionPending = false;
    elseif ~isempty(checkpointFile)
        analysis.provenance.checkpoint.deletedOnSuccess = false;
        analysis.provenance.checkpoint.retained = isfile(checkpointFile);
        analysis.provenance.checkpoint.deletionPending = false;
    else
        analysis.provenance.checkpoint.deletedOnSuccess = false;
        analysis.provenance.checkpoint.retained = false;
        analysis.provenance.checkpoint.deletionPending = false;
    end
    analysis.provenance.checkpoint.savedMetadataMoment = ...
        'final checkpoint disposition after optional cleanup';

    % The first atomic save above is deliberately installed before checkpoint
    % deletion, so an interrupted cleanup can never destroy the only complete
    % numerical artifact.  Once cleanup succeeds, install the final provenance
    % state atomically as well.  Direct AnalyzeFloquetBranch callers therefore
    % see the same checkpoint disposition on disk and in the returned struct.
    if opts.SaveAnalysis
        WriteAnalysisFile(outputFile,analysis,true);
    end
end

function AddRequiredPaths(analysisRoot)
    slipRoot = fileparts(fileparts(analysisRoot));
    addpath(analysisRoot);
    addpath(fullfile(slipRoot,'1_Dynamic_Frameworks','v2'));
    addpath(fullfile(slipRoot,'4_Solution_Management'));
end

function opts = ResolveAnalysisOptions(userOptions)
    if ~isstruct(userOptions) || ~isscalar(userOptions)
        error('AnalyzeFloquetBranch:InvalidOptions', ...
            'Options must be a scalar structure.');
    end
    defaults = struct();
    defaults.BranchName = '';
    defaults.FloquetOptions = struct();
    defaults.TrackOptions = struct( ...
        'MultiplierWeight',1,'EigenvectorWeight',0.25, ...
        'ComputeAssignmentGap',true);
    defaults.DetectorOptions = struct( ...
        'PersistencePoints',1, ...
        'RequireBranchTangentForPlusOne',true, ...
        'RejectTrivialBranchTangent',true, ...
        'RejectAmbiguousBranchTangent',true);
    defaults.ContinuationParameter = [];
    defaults.ContinuationParameterRow = 1;
    defaults.ContinuationParameterName = 'initial horizontal speed dx';
    defaults.ParameterConstancyTolerance = 1e-10;
    defaults.ContinueOnFailure = true;
    defaults.CatchComputeExceptions = true;
    defaults.StoreFullDiagnostics = false;
    defaults.CheckpointFile = '';
    defaults.CheckpointEvery = 1;
    defaults.ResumeFromCheckpoint = false;
    defaults.DeleteCheckpointOnSuccess = false;
    defaults.OverwriteCheckpoint = false;
    defaults.SaveAnalysis = false;
    defaults.OutputFile = '';
    defaults.Overwrite = false;
    defaults.Verbose = true;
    defaults.StatusFcn = [];
    defaults.ComputeFunction = @floquet.computeFDM;
    defaults.AllowNonProductionComputeFunction = false;

    opts = defaults;
    supplied = fieldnames(userOptions);
    allowed = fieldnames(defaults);
    for k = 1:numel(supplied)
        hit = find(strcmpi(supplied{k},allowed),1);
        if isempty(hit)
            error('AnalyzeFloquetBranch:UnknownOption', ...
                'Unknown analysis option ''%s''.',supplied{k});
        end
        opts.(allowed{hit}) = userOptions.(supplied{k});
    end

    nested = {'FloquetOptions','TrackOptions','DetectorOptions'};
    for k = 1:numel(nested)
        if ~isstruct(opts.(nested{k})) || ~isscalar(opts.(nested{k}))
            error('AnalyzeFloquetBranch:NestedOptions', ...
                '%s must be a scalar structure.',nested{k});
        end
    end
    managedTrack = {'Reliability','IntervalReliability'};
    for k = 1:numel(managedTrack)
        if ~isempty(FindField(opts.TrackOptions,managedTrack{k}))
            error('AnalyzeFloquetBranch:ManagedTrackOption', ...
                ['TrackOptions.%s is managed from validated points and ' ...
                 'reliable intervals.'],managedTrack{k});
        end
    end
    managedDetector = {'Reliability','IntervalReliability', ...
        'EventTopologyConsistent','BranchStates','BranchTangents', ...
        'ParameterValues','Eigenvectors','TrackOptions'};
    for k = 1:numel(managedDetector)
        if ~isempty(FindField(opts.DetectorOptions,managedDetector{k}))
            error('AnalyzeFloquetBranch:ManagedDetectorOption', ...
                ['DetectorOptions.%s is managed by the canonical parent ' ...
                 'branch analysis.'],managedDetector{k});
        end
    end

    logicalNames = {'ContinueOnFailure','CatchComputeExceptions', ...
        'StoreFullDiagnostics','ResumeFromCheckpoint', ...
        'DeleteCheckpointOnSuccess','OverwriteCheckpoint', ...
        'SaveAnalysis','Overwrite','Verbose', ...
        'AllowNonProductionComputeFunction'};
    for k = 1:numel(logicalNames)
        opts.(logicalNames{k}) = ValidateLogical( ...
            opts.(logicalNames{k}),logicalNames{k});
    end
    textNames = {'BranchName','ContinuationParameterName','OutputFile', ...
        'CheckpointFile'};
    for k = 1:numel(textNames)
        value = opts.(textNames{k});
        if isstring(value) && isscalar(value)
            value = char(value);
        end
        if ~ischar(value)
            error('AnalyzeFloquetBranch:TextOption', ...
                '%s must be text.',textNames{k});
        end
        opts.(textNames{k}) = value;
    end
    if ~isnumeric(opts.ContinuationParameterRow) || ...
            ~isscalar(opts.ContinuationParameterRow) || ...
            ~isfinite(opts.ContinuationParameterRow) || ...
            opts.ContinuationParameterRow < 1 || ...
            opts.ContinuationParameterRow ~= floor(opts.ContinuationParameterRow)
        error('AnalyzeFloquetBranch:ContinuationParameterRow', ...
            'ContinuationParameterRow must be a positive integer.');
    end
    if ~isnumeric(opts.CheckpointEvery) || ...
            ~isscalar(opts.CheckpointEvery) || ...
            ~isfinite(opts.CheckpointEvery) || opts.CheckpointEvery < 1 || ...
            opts.CheckpointEvery ~= floor(opts.CheckpointEvery)
        error('AnalyzeFloquetBranch:CheckpointEvery', ...
            'CheckpointEvery must be a positive integer.');
    end
    if ~isnumeric(opts.ParameterConstancyTolerance) || ...
            ~isscalar(opts.ParameterConstancyTolerance) || ...
            ~isfinite(opts.ParameterConstancyTolerance) || ...
            opts.ParameterConstancyTolerance < 0
        error('AnalyzeFloquetBranch:ParameterConstancyTolerance', ...
            'ParameterConstancyTolerance must be a finite nonnegative scalar.');
    end
    if ~isa(opts.ComputeFunction,'function_handle')
        error('AnalyzeFloquetBranch:ComputeFunction', ...
            'ComputeFunction must be a function handle.');
    end
    [productionEvaluator,evaluatorIdentity] = ...
        floquet.internal.provenance.evaluatorIdentity( ...
            opts.ComputeFunction, 'floquet.computeFDM');
    if ~productionEvaluator && ~opts.AllowNonProductionComputeFunction
        error('AnalyzeFloquetBranch:NonProductionEvaluator', ...
            ['A nonproduction ComputeFunction requires the explicit ' ...
             'AllowNonProductionComputeFunction=true test/integration flag.']);
    end
    if ~(isempty(opts.StatusFcn) || isa(opts.StatusFcn,'function_handle'))
        error('AnalyzeFloquetBranch:StatusFcn', ...
            'StatusFcn must be empty or a function handle.');
    end
    if opts.SaveAnalysis && isempty(strtrim(opts.OutputFile))
        error('AnalyzeFloquetBranch:OutputFileRequired', ...
            'OutputFile is required when SaveAnalysis is true.');
    end
    if (opts.ResumeFromCheckpoint || opts.DeleteCheckpointOnSuccess || ...
            opts.OverwriteCheckpoint) && isempty(strtrim(opts.CheckpointFile))
        error('AnalyzeFloquetBranch:CheckpointFileRequired', ...
            ['CheckpointFile is required when resume, delete-on-success, ' ...
             'or checkpoint overwrite is requested.']);
    end

    opts.FloquetOptions = ...
        floquet.internal.options.resolve(opts.FloquetOptions);
    % A branch scan must retain rejected points rather than converting them
    % into thrown errors inside ComputeFloquetFDM.
    opts.FloquetOptions.ErrorOnFailure = false;
    opts.ProductionEvaluator = productionEvaluator;
    opts.EvaluatorIdentity = evaluatorIdentity;
end

function name = FindField(source,name)
    fields = fieldnames(source);
    hit = find(strcmpi(name,fields),1);
    if isempty(hit)
        name = '';
    else
        name = fields{hit};
    end
end

function value = ValidateLogical(value,name)
    valid = isscalar(value) && (islogical(value) || ...
        (isnumeric(value) && isreal(value) && isfinite(value) && ...
         any(value == [0 1])));
    if ~valid
        error('AnalyzeFloquetBranch:LogicalOption', ...
            '%s must be scalar logical.',name);
    end
    value = logical(value);
end

function [branch,source] = ResolveBranchData(branchData)
    source = struct('kind','','file','','stem','','variable','', ...
        'fileBytes',NaN,'fileModified','','fileSHA256','', ...
        'fingerprintStatus','not-applicable');
    if ischar(branchData) || (isstring(branchData) && isscalar(branchData))
        filename = char(branchData);
        if ~isfile(filename)
            error('AnalyzeFloquetBranch:MissingBranchFile', ...
                'Continuation branch file does not exist: %s',filename);
        end
        loaded = load(filename);
        [branch,variable] = ExtractBranchField(loaded);
        filename = CanonicalFile(filename);
        [~,stem] = fileparts(filename);
        listing = dir(filename);
        source.kind = 'mat-file';
        source.file = filename;
        source.stem = stem;
        source.variable = variable;
        if ~isempty(listing)
            source.fileBytes = listing(1).bytes;
            source.fileModified = listing(1).date;
        end
        [source.fileSHA256,source.fingerprintStatus] = FileSHA256(filename);
    elseif isnumeric(branchData)
        branch = branchData;
        source.kind = 'numeric-input';
        source.variable = '<numeric-input>';
    elseif isstruct(branchData) && isscalar(branchData)
        [branch,variable] = ExtractBranchField(branchData);
        source.kind = 'struct-input';
        source.variable = variable;
        if isfield(branchData,'source_file') && IsScalarText(branchData.source_file)
            source.file = char(branchData.source_file);
            [~,source.stem] = fileparts(source.file);
        end
    else
        error('AnalyzeFloquetBranch:InvalidBranchInput', ...
            ['Branch input must be numeric, a scalar structure, or a ' ...
             'MAT-file name.']);
    end
end

function [branch,variable] = ExtractBranchField(container)
    names = {'results','branch','continuation_branch','ContinuationBranch'};
    for k = 1:numel(names)
        if isfield(container,names{k}) && isnumeric(container.(names{k}))
            branch = container.(names{k});
            variable = names{k};
            return
        end
    end
    error('AnalyzeFloquetBranch:MissingBranchVariable', ...
        ['A branch structure or MAT file must contain numeric results, ' ...
         'branch, continuation_branch, or ContinuationBranch data.']);
end

function ValidateBranch(branch)
    if ~isnumeric(branch) || ~isreal(branch) || ~ismatrix(branch) || ...
            size(branch,1) ~= 29 || isempty(branch)
        error('AnalyzeFloquetBranch:BranchShape', ...
            'The v2 continuation branch must be a real numeric 29-by-N array.');
    end
    if any(~isfinite(branch(1:22,:)),'all')
        error('AnalyzeFloquetBranch:SolutionData', ...
            'State and input event-time rows 1:22 must be finite.');
    end
    parameters = branch(23:29,:);
    invalid = ~isfinite(parameters);
    % Para(3), branch row 25, is pitch inertia and legitimately uses +Inf.
    invalid(3,:) = isnan(parameters(3,:)) | ...
        (isinf(parameters(3,:)) & parameters(3,:) < 0);
    if any(invalid,'all')
        error('AnalyzeFloquetBranch:ParameterData', ...
            ['Parameters must be finite except that Para(3), pitch ' ...
             'inertia, may be positive Inf.']);
    end
end

function indices = ResolveSelection(selection,count)
    if isempty(selection) || ...
            (IsScalarText(selection) && strcmp(char(selection),':'))
        indices = 1:count;
    elseif islogical(selection)
        if numel(selection) ~= count
            error('AnalyzeFloquetBranch:SelectionMask', ...
                'A logical selection must contain %d entries.',count);
        end
        indices = find(selection(:).');
    elseif isnumeric(selection) && isreal(selection) && isvector(selection)
        indices = selection(:).';
    else
        error('AnalyzeFloquetBranch:Selection', ...
            'Selection must be empty, colon, a logical mask, or numeric indices.');
    end
    if isempty(indices) || any(~isfinite(indices)) || ...
            any(indices ~= floor(indices)) || any(indices < 1) || ...
            any(indices > count) || any(diff(indices) <= 0)
        error('AnalyzeFloquetBranch:SelectionIndices', ...
            ['Selected columns must be strictly increasing unique integers ' ...
             'from 1 through %d.'],count);
    end
end

function coordinate = ResolveContinuationCoordinate(opts,branch,indices)
    supplied = opts.ContinuationParameter;
    if isempty(supplied)
        if opts.ContinuationParameterRow > size(branch,1)
            error('AnalyzeFloquetBranch:ContinuationRowOutOfRange', ...
                'ContinuationParameterRow exceeds the branch row count.');
        end
        coordinate = branch(opts.ContinuationParameterRow,indices);
    else
        if ~isnumeric(supplied) || ~isreal(supplied) || ...
                ~isvector(supplied) || any(~isfinite(supplied))
            error('AnalyzeFloquetBranch:ContinuationParameter', ...
                'ContinuationParameter must be a finite real vector.');
        end
        supplied = supplied(:).';
        if numel(supplied) == size(branch,2)
            coordinate = supplied(indices);
        elseif numel(supplied) == numel(indices)
            coordinate = supplied;
        else
            error('AnalyzeFloquetBranch:ContinuationParameterSize', ...
                ['ContinuationParameter must contain one value per full ' ...
                 'branch column or one per selected column.']);
        end
    end
    if any(~isfinite(coordinate))
        error('AnalyzeFloquetBranch:NonfiniteCoordinate', ...
            'The selected continuation coordinate must be finite.');
    end
end

function source = CompleteSource(source,branch,indices,opts)
    source.fullBranchPointCount = size(branch,2);
    source.selectedPointCount = numel(indices);
    source.selectedColumns = indices;
    if isempty(strtrim(opts.BranchName))
        if ~isempty(source.stem)
            source.branchName = source.stem;
        else
            source.branchName = 'continuation_branch';
        end
    else
        source.branchName = strtrim(opts.BranchName);
    end
end

function coverage = BuildCoverage(indices,fullPointCount)
%BUILDCOVERAGE Separate implementation identity from discovery authority.
% A subset still uses the canonical numerical implementation, but it is a
% diagnostic scan and cannot claim that the entire ordered parent branch
% was searched.  The exact 1:N test prevents a sparse or windowed scan from
% acquiring full-parent authority merely because its columns are ordered.
    fullCoverage = isequal(indices,1:fullPointCount);
    coverage = struct();
    coverage.fullParentPointCount = fullPointCount;
    coverage.selectedPointCount = numel(indices);
    coverage.selectedColumns = indices;
    coverage.selectionPreservesContinuationOrder = ...
        all(diff(indices) > 0);
    coverage.fullParentCoverage = fullCoverage;
    coverage.fullOrderedParentCoverage = fullCoverage && ...
        coverage.selectionPreservesContinuationOrder;
    coverage.coverageFraction = numel(indices) / fullPointCount;
    if coverage.fullOrderedParentCoverage
        coverage.role = 'full-ordered-parent-branch';
    else
        coverage.role = 'selected-parent-branch-subset';
    end
end

function [accepted,reason] = ValidateFloquetResult( ...
        M,lambda,V,detail,times,topology,n)
    accepted = IsTrueScalar(NestedValue(detail,{'accepted'},false));
    reason = '';
    if ~accepted
        reason = RejectionMessage(detail);
        return
    end
    mapDefinition = NestedValue(detail,{'mapDefinition'},'');
    reducedIndices = NestedValue(detail,{'reducedStateIndices'},[]);
    correctedMap = IsScalarText(mapDefinition) && ...
        contains(lower(char(mapDefinition)),'poincare') && ...
        isequal(reducedIndices(:).',[1 2 4:13]);
    if ~correctedMap
        accepted = false;
        reason = ['Diagnostics do not identify the corrected ' ...
            '12-coordinate reduced Poincare map.'];
        return
    end
    validShape = isnumeric(M) && isreal(M) && isequal(size(M),[n n]) && ...
        isnumeric(lambda) && numel(lambda) == n && ...
        isnumeric(V) && isequal(size(V),[n n]);
    finiteOutput = validShape && all(isfinite(M(:))) && ...
        all(isfinite(real(lambda(:)))) && all(isfinite(imag(lambda(:)))) && ...
        all(isfinite(real(V(:)))) && all(isfinite(imag(V(:))));
    if ~finiteOutput
        accepted = false;
        reason = 'Accepted Floquet output has malformed or nonfinite eigendata.';
        return
    end
    if any(vecnorm(V,2,1) <= 100*eps(max(1,norm(V,'fro'))))
        accepted = false;
        reason = 'Floquet eigendata contain a numerically null eigenvector.';
        return
    end
    eigenpairResidual = norm(M*V - V*diag(lambda(:)),'fro') / ...
        max(1,norm(M,'fro')*norm(V,'fro'));
    if ~isfinite(eigenpairResidual) || eigenpairResidual > 1e-6
        accepted = false;
        reason = sprintf('Floquet eigenpair residual %.3e exceeds 1e-6.', ...
            eigenpairResidual);
        return
    end
    if isempty(times)
        accepted = false;
        reason = ['Accepted computation did not expose nine authoritative ' ...
            'event times solved by the timing solver.'];
        return
    end
    if isempty(topology)
        accepted = false;
        reason = 'Accepted computation did not expose a valid base topology.';
    end
end

function [times,topology] = ExtractBaseMapMetadata(detail)
    times = [];
    topology = [];
    candidateTimes = NestedValue(detail,{'baseSolvedEventTimes'},[]);
    if isempty(candidateTimes)
        candidateTimes = NestedValue(detail, ...
            {'baseValidation','mapInfo','solvedEventTimes'},[]);
    end
    if isnumeric(candidateTimes) && isreal(candidateTimes) && ...
            numel(candidateTimes) == 9 && all(isfinite(candidateTimes(:))) && ...
            candidateTimes(9) > 0
        times = candidateTimes(:);
    end
    candidateTopology = NestedValue(detail,{'referenceTopology'},[]);
    if isempty(candidateTopology)
        candidateTopology = NestedValue(detail, ...
            {'baseValidation','mapInfo','eventTopology'},[]);
    end
    if isstruct(candidateTopology) && isscalar(candidateTopology) && ...
            IsTrueScalar(NestedValue(candidateTopology,{'valid'},false)) && ...
            isfield(candidateTopology,'signature')
        topology = candidateTopology;
    end
end

function point = EmptyPointQuality()
    point = struct('LocalIndex',NaN,'BranchIndex',NaN, ...
        'Accepted',false,'Status','not-evaluated','Message','', ...
        'RejectionReasons',{{}},'SolvedEventTimesAvailable',false, ...
        'BaseTopologyValid',false,'BaseTopologySignature','', ...
        'DerivativeRelativeError',NaN, ...
        'ForwardBackwardRelativeError',NaN, ...
        'PeriodicResidual',NaN,'TimingResidual',NaN, ...
        'TimingRepeatabilityError',NaN,'SelectedPerturbationMagnitude',NaN);
end

function point = SummarizePoint(localIndex,branchIndex,detail,accepted, ...
        validationReason,times,topology)
    point = EmptyPointQuality();
    point.LocalIndex = localIndex;
    point.BranchIndex = branchIndex;
    point.Accepted = accepted;
    point.SolvedEventTimesAvailable = ~isempty(times);
    point.BaseTopologyValid = ~isempty(topology);
    if ~isempty(topology)
        point.BaseTopologySignature = topology.signature;
    end
    point.DerivativeRelativeError = NestedNumber(detail, ...
        {'derivativeConvergence','finestRelativeError'});
    point.ForwardBackwardRelativeError = NestedNumber(detail, ...
        {'maximumFinestForwardBackwardError'});
    point.PeriodicResidual = NestedNumber(detail, ...
        {'baseValidation','periodicResidualNormInf'});
    point.TimingResidual = NestedNumber(detail, ...
        {'baseValidation','mapInfo','timingResidualNormInf'});
    point.TimingRepeatabilityError = NestedNumber(detail, ...
        {'baseValidation','timingRepeatability','eventTimingErrorNormInf'});
    point.SelectedPerturbationMagnitude = NestedNumber(detail, ...
        {'selectedPerturbationMagnitude'});
    reasons = NestedValue(detail,{'rejectionReasons'},{});
    if ischar(reasons)
        reasons = {reasons};
    end
    if ~iscell(reasons)
        reasons = {};
    end
    if accepted
        point.Status = 'accepted';
        point.Message = 'accepted reduced Poincare-map derivative';
    else
        point.Status = char(NestedValue(detail,{'status'},'rejected'));
        if isempty(validationReason)
            validationReason = RejectionMessage(detail);
        end
        point.Message = validationReason;
        if isempty(reasons) || ~any(strcmp(reasons,validationReason))
            reasons{end+1} = validationReason;
        end
    end
    point.RejectionReasons = reasons;
end

function [comparisons,consistent] = CompareAdjacentTopologies( ...
        topologies,indices,floquetOptions)
    count = max(0,numel(topologies)-1);
    comparisons = repmat(EmptyTopologyComparison(),1,count);
    consistent = false(1,count);
    for k = 1:count
        item = EmptyTopologyComparison();
        item.LocalLeft = k;
        item.LocalRight = k+1;
        item.BranchLeft = indices(k);
        item.BranchRight = indices(k+1);
        item.SourceColumnsConsecutive = indices(k+1) == indices(k)+1;
        if ~item.SourceColumnsConsecutive
            item.Status = 'not-compared-skipped-source-columns';
            item.Reasons = {'Selected columns are not adjacent in the source branch.'};
        elseif isempty(topologies{k}) || isempty(topologies{k+1})
            item.Status = 'not-compared-missing-base-topology';
            item.Reasons = {'One or both base event topologies are unavailable.'};
        else
            item.Compared = true;
            item.Forward = floquet.internal.events.compareTopology( ...
                topologies{k},topologies{k+1},floquetOptions);
            item.Reverse = floquet.internal.events.compareTopology( ...
                topologies{k+1},topologies{k},floquetOptions);
            item.Consistent = item.Forward.consistent && item.Reverse.consistent;
            if item.Consistent
                item.Status = 'consistent';
            else
                item.Status = 'topology-change-or-ambiguity';
                item.Reasons = [PrefixReasons( ...
                    item.Forward.rejectionReasons,'forward: '), ...
                    PrefixReasons(item.Reverse.rejectionReasons,'reverse: ')];
            end
        end
        comparisons(k) = item;
        consistent(k) = item.Consistent;
    end
end

function item = EmptyTopologyComparison()
    item = struct('LocalLeft',NaN,'LocalRight',NaN, ...
        'BranchLeft',NaN,'BranchRight',NaN, ...
        'SourceColumnsConsecutive',false,'Compared',false, ...
        'Consistent',false,'Status','not-evaluated','Reasons',{{}}, ...
        'Forward',struct(),'Reverse',struct());
end

function [segments,segmentId] = BuildReliableSegments( ...
        accepted,intervalReliability,indices,signatures)
    template = struct('SegmentIndex',NaN,'LocalIndices',[], ...
        'BranchIndices',[],'PointCount',0,'FirstBranchIndex',NaN, ...
        'LastBranchIndex',NaN,'FirstTopologySignature','', ...
        'LastTopologySignature','','FixedPhysicalParameters',false, ...
        'MaximumScaledParameterVariation',NaN,'VaryingParameterRows',[]);
    segments = repmat(template,1,0);
    segmentId = NaN(1,numel(accepted));
    k = 1;
    while k <= numel(accepted)
        if ~accepted(k)
            k = k+1;
            continue
        end
        first = k;
        while k < numel(accepted) && intervalReliability(k)
            k = k+1;
        end
        local = first:k;
        item = template;
        item.SegmentIndex = numel(segments)+1;
        item.LocalIndices = local;
        item.BranchIndices = indices(local);
        item.PointCount = numel(local);
        item.FirstBranchIndex = indices(first);
        item.LastBranchIndex = indices(k);
        item.FirstTopologySignature = signatures{first};
        item.LastTopologySignature = signatures{k};
        segments(end+1) = item; %#ok<AGROW>
        segmentId(local) = item.SegmentIndex;
        k = k+1;
    end
end

function [segments,fixedMask,diagnostics] = ...
        AssessSegmentParameterConstancy(segments,parameters,tolerance)
    fixedMask = false(1,numel(segments));
    template = struct('SegmentIndex',NaN,'LocalIndices',[], ...
        'BranchIndices',[],'FixedPhysicalParameters',false, ...
        'Tolerance',tolerance,'MaximumScaledVariation',NaN, ...
        'ScaledVariationByParameter',NaN(7,1), ...
        'VaryingParameterRows',[]);
    diagnostics = repmat(template,1,numel(segments));
    for s = 1:numel(segments)
        local = segments(s).LocalIndices;
        values = parameters(:,local);
        scaled = zeros(size(values));
        reference = values(:,1);
        for row = 1:size(values,1)
            for column = 1:size(values,2)
                left = reference(row);
                right = values(row,column);
                if isequaln(left,right)
                    scaled(row,column) = 0;
                elseif isfinite(left) && isfinite(right)
                    scale = max([1,abs(left),abs(right)]);
                    scaled(row,column) = abs(right-left)/scale;
                else
                    scaled(row,column) = Inf;
                end
            end
        end
        byRow = max(scaled,[],2);
        varyingRows = find(byRow > tolerance).';
        fixedMask(s) = isempty(varyingRows);
        diagnostics(s).SegmentIndex = segments(s).SegmentIndex;
        diagnostics(s).LocalIndices = local;
        diagnostics(s).BranchIndices = segments(s).BranchIndices;
        diagnostics(s).FixedPhysicalParameters = fixedMask(s);
        diagnostics(s).MaximumScaledVariation = max(byRow);
        diagnostics(s).ScaledVariationByParameter = byRow;
        diagnostics(s).VaryingParameterRows = varyingRows;
        segments(s).FixedPhysicalParameters = fixedMask(s);
        segments(s).MaximumScaledParameterVariation = max(byRow);
        segments(s).VaryingParameterRows = varyingRows;
    end
end

function tangents = SegmentTangents(states,segments,fixedParameterSegment)
    tangents = NaN(size(states));
    for s = 1:numel(segments)
        if ~fixedParameterSegment(s)
            continue
        end
        local = segments(s).LocalIndices;
        for j = 1:numel(local)
            if isscalar(local)
                continue
            elseif j == 1
                difference = states(:,local(2)) - states(:,local(1));
            elseif j == numel(local)
                difference = states(:,local(end)) - states(:,local(end-1));
            else
                difference = states(:,local(j+1)) - states(:,local(j-1));
            end
            magnitude = norm(difference,2);
            if isfinite(magnitude) && magnitude > 0
                tangents(:,local(j)) = difference ./ magnitude;
            end
        end
    end
end

function [tracks,diagnostics] = TrackReliableSegments( ...
        rawMultipliers,rawEigenvectors,segments,accepted, ...
        intervalReliability,trackOptions)
    trackOptions.Reliability = accepted;
    trackOptions.IntervalReliability = intervalReliability;
    [tracks,diagnostics] = floquet.internal.tracking.trackMultipliers( ...
        rawMultipliers,rawEigenvectors,trackOptions);
    diagnostics.Segments = segments;
    diagnostics.Policy = [ ...
        'One canonical TrackMultipliers pass with explicit point and ' ...
        'interval reliability; assignments restart after rejected, skipped, ' ...
        'or topology-changing gaps.'];
    tracks.Diagnostics = diagnostics;
end

function candidates = AnnotateCandidates( ...
        candidates,indices,parameters,fullBranchLength)
    width = max(4,numel(num2str(fullBranchLength)));
    if isempty(candidates)
        candidates(1).CandidateID = '';
        candidates(1).LeftBranchIndex = NaN;
        candidates(1).RightBranchIndex = NaN;
        candidates = candidates([]);
        return
    end
    for k = 1:numel(candidates)
        left = candidates(k).LeftIndex;
        right = candidates(k).RightIndex;
        leftBranch = indices(left);
        rightBranch = indices(right);
        candidates(k).LeftBranchIndex = leftBranch;
        candidates(k).RightBranchIndex = rightBranch;
        candidates(k).CandidateID = sprintf('%s_c%0*d_c%0*d', ...
            NormalizeCandidateType(candidates(k).Type), ...
            width,leftBranch,width,rightBranch);
        candidates(k).ParameterVector = SafeParameterInterpolation( ...
            parameters(:,left),parameters(:,right),candidates(k).Fraction);
    end
end

function name = NormalizeCandidateType(type)
    switch lower(strtrim(type))
        case {'+1','plus-one','plus1'}
            name = 'plus1';
        case {'-1','minus-one','minus1','period-doubling'}
            name = 'minus1';
        case {'complex-unit-circle','neimark-sacker'}
            name = 'complex_unit_circle';
        otherwise
            name = regexprep(lower(strtrim(type)),'[^a-z0-9]+','_');
            name = regexprep(name,'^_+|_+$','');
    end
end

function value = SafeParameterInterpolation(left,right,fraction)
    value = NaN(size(left));
    for k = 1:numel(left)
        if isequal(left(k),right(k))
            value(k) = left(k);
        elseif fraction == 0
            value(k) = left(k);
        elseif fraction == 1
            value(k) = right(k);
        else
            value(k) = (1-fraction)*left(k) + fraction*right(k);
        end
    end
end

function rejected = AnnotateDetectorRejections(rejected,indices)
    if isempty(rejected)
        rejected(1).LeftBranchIndex = NaN;
        rejected(1).RightBranchIndex = NaN;
        rejected = rejected([]);
        return
    end
    for k = 1:numel(rejected)
        left = rejected(k).LeftIndex;
        right = rejected(k).RightIndex;
        if isfinite(left) && isfinite(right) && left >= 1 && ...
                right <= numel(indices)
            rejected(k).LeftBranchIndex = indices(left);
            rejected(k).RightBranchIndex = indices(right);
        else
            rejected(k).LeftBranchIndex = NaN;
            rejected(k).RightBranchIndex = NaN;
        end
    end
end

function report = BuildRejectedPointReport(quality)
    template = struct('LocalIndex',NaN,'BranchIndex',NaN, ...
        'Status','','Message','','Reasons',{{}});
    report = repmat(template,1,0);
    for k = 1:numel(quality)
        if quality(k).Accepted
            continue
        end
        item = template;
        item.LocalIndex = quality(k).LocalIndex;
        item.BranchIndex = quality(k).BranchIndex;
        item.Status = quality(k).Status;
        item.Message = quality(k).Message;
        item.Reasons = quality(k).RejectionReasons;
        report(end+1) = item; %#ok<AGROW>
    end
end

function report = BuildRejectedIntervalReport(accepted,sourceConsecutive, ...
        topologyConsistent,topologyComparison,indices)
    template = struct('LocalLeft',NaN,'LocalRight',NaN, ...
        'BranchLeft',NaN,'BranchRight',NaN,'Reasons',{{}}, ...
        'TopologyComparison',struct());
    report = repmat(template,1,0);
    for k = 1:numel(sourceConsecutive)
        reliable = accepted(k) && accepted(k+1) && ...
            sourceConsecutive(k) && topologyConsistent(k);
        if reliable
            continue
        end
        reasons = {};
        if ~sourceConsecutive(k)
            reasons{end+1} = 'nonconsecutive-source-columns'; %#ok<AGROW>
        end
        if ~accepted(k)
            reasons{end+1} = 'left-point-rejected'; %#ok<AGROW>
        end
        if ~accepted(k+1)
            reasons{end+1} = 'right-point-rejected'; %#ok<AGROW>
        end
        if ~topologyConsistent(k)
            reasons{end+1} = 'adjacent-base-topology-not-consistent'; %#ok<AGROW>
        end
        item = template;
        item.LocalLeft = k;
        item.LocalRight = k+1;
        item.BranchLeft = indices(k);
        item.BranchRight = indices(k+1);
        item.Reasons = reasons;
        item.TopologyComparison = topologyComparison(k);
        report(end+1) = item; %#ok<AGROW>
    end
end

function convergence = CollectConvergence(quality)
    convergence = struct();
    convergence.derivativeRelativeError = ...
        [quality.DerivativeRelativeError];
    convergence.forwardBackwardRelativeError = ...
        [quality.ForwardBackwardRelativeError];
    convergence.periodicResidual = [quality.PeriodicResidual];
    convergence.timingResidual = [quality.TimingResidual];
    convergence.timingRepeatabilityError = ...
        [quality.TimingRepeatabilityError];
    convergence.selectedPerturbationMagnitude = ...
        [quality.SelectedPerturbationMagnitude];
end

function summary = BuildQualitySummary(accepted,topologyConsistent, ...
        intervalReliability,segments,quality)
    summary = struct();
    summary.selectedPointCount = numel(accepted);
    summary.acceptedPointCount = nnz(accepted);
    summary.rejectedPointCount = nnz(~accepted);
    summary.acceptedFraction = nnz(accepted)/numel(accepted);
    summary.adjacentTopologyComparisonCount = numel(topologyConsistent);
    summary.adjacentTopologyConsistentCount = nnz(topologyConsistent);
    summary.reliableIntervalCount = nnz(intervalReliability);
    summary.segmentCount = numel(segments);
    if isempty(segments)
        summary.longestReliableSegment = 0;
    else
        summary.longestReliableSegment = max([segments.PointCount]);
    end
    summary.maximumAcceptedDerivativeRelativeError = ...
        MaximumAccepted([quality.DerivativeRelativeError],accepted);
    summary.maximumAcceptedForwardBackwardRelativeError = ...
        MaximumAccepted([quality.ForwardBackwardRelativeError],accepted);
    summary.maximumAcceptedPeriodicResidual = ...
        MaximumAccepted([quality.PeriodicResidual],accepted);
    summary.maximumAcceptedTimingResidual = ...
        MaximumAccepted([quality.TimingResidual],accepted);
end

function value = MaximumAccepted(values,accepted)
    values = values(accepted & isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = max(values);
    end
end

function info = EmptyCheckpointInfo()
    info = struct('enabled',false,'file','','resumed',false, ...
        'loadedCompletedCount',0,'lastSavedCompletedCount',0, ...
        'finalCompletedCount',0,'writeCount',0,'createdAt',Timestamp(), ...
        'compatibilitySchema','','deleteOnSuccessRequested',false, ...
        'deletedOnSuccess',false,'retained',false, ...
        'partialCheckpointUsedAsFinalAnalysis',false);
end

function compatibility = BuildCheckpointCompatibility( ...
        source,indices,opts,analysisRoot,stateDimension)
    if ~strcmp(source.branchFingerprintStatus,'computed') || ...
            isempty(source.branchSHA256)
        error('AnalyzeFloquetBranch:CheckpointFingerprintUnavailable', ...
            ['Checkpointing requires a SHA-256 fingerprint of the complete ' ...
             '29-by-N source branch.']);
    end
    compatibility = struct();
    compatibility.schemaVersion = 'floquet-branch-checkpoint-compatibility-v2';
    compatibility.analysisVersion = 'floquet-branch-analysis-v2';
    compatibility.evaluatorAuthoritySchema = ...
        'floquet-evaluator-identity-v2';
    compatibility.sourceIdentity = struct( ...
        'kind',source.kind,'file',source.file, ...
        'variable',source.variable,'fileSHA256',source.fileSHA256, ...
        'branchSHA256',source.branchSHA256);
    compatibility.selectedOriginalIndices = indices;
    compatibility.dimensions = struct('branchRows',29,'solutionRows',22, ...
        'parameterRows',7,'reducedStateDimension',stateDimension, ...
        'eventTimeDimension',9,'selectedPointCount',numel(indices));
    compatibility.computeEvaluator = EvaluatorCompatibility( ...
        opts.ComputeFunction);
    compatibility.resolvedFloquetOptions = ...
        NormalizeCompatibilityValue(opts.FloquetOptions);
    compatibility.computePolicy = struct( ...
        'CatchComputeExceptions',opts.CatchComputeExceptions, ...
        'ContinueOnFailure',opts.ContinueOnFailure);
    compatibility.matlabVersion = version;
    compatibility.computerArchitecture = computer;
    compatibility.implementation = BuildImplementationManifest(analysisRoot);
end

function output = NormalizeCompatibilityValue(value)
    if isa(value,'function_handle')
        output = struct('kind','function-handle', ...
            'record',EvaluatorCompatibility(value));
    elseif isstruct(value)
        if ~isscalar(value) && ~isempty(value)
            output = arrayfun(@NormalizeCompatibilityValue,value);
            return
        end
        output = value;
        names = fieldnames(value);
        for k = 1:numel(names)
            output.(names{k}) = NormalizeCompatibilityValue(value.(names{k}));
        end
    elseif iscell(value)
        output = cell(size(value));
        for k = 1:numel(value)
            output{k} = NormalizeCompatibilityValue(value{k});
        end
    elseif isstring(value)
        output = cellstr(value);
    elseif isnumeric(value) || islogical(value) || ischar(value) || ...
            isempty(value)
        output = value;
    else
        error('AnalyzeFloquetBranch:CheckpointUnsupportedOptionValue', ...
            ['Strict checkpoint compatibility does not support option ' ...
             'values of class %s.'],class(value));
    end
end

function record = EvaluatorCompatibility(handle)
    details = functions(handle);
    record = struct('name',func2str(handle),'type','', ...
        'file','','fileSHA256','','fileFingerprintStatus','not-applicable', ...
        'workspaceSHA256','','workspaceFingerprintStatus','not-applicable');
    if isfield(details,'type')
        record.type = details.type;
    end
    if isfield(details,'file') && ~isempty(details.file)
        record.file = CanonicalFile(details.file);
        [record.fileSHA256,record.fileFingerprintStatus] = ...
            FileSHA256(record.file);
        if ~strcmp(record.fileFingerprintStatus,'computed')
            error('AnalyzeFloquetBranch:EvaluatorFingerprintUnavailable', ...
                'Could not fingerprint evaluator source %s.',record.file);
        end
    end
    if isfield(details,'workspace') && ~isempty(details.workspace)
        [record.workspaceSHA256,record.workspaceFingerprintStatus] = ...
            SerializableSHA256(details.workspace);
        if ~strcmp(record.workspaceFingerprintStatus,'computed')
            error('AnalyzeFloquetBranch:EvaluatorWorkspaceFingerprint', ...
                ['Could not fingerprint captured workspace for evaluator ' ...
                 '%s. Use a named function for resumable analysis.'], ...
                record.name);
        end
    end
end

function manifest = BuildImplementationManifest(analysisRoot)
    packageRoot = fullfile(analysisRoot,'+floquet');
    names = {'floquet.analyzeBranch','floquet.computeFDM', ...
        'floquet.internal.poincare.buildMap', ...
        'floquet.detectBifurcations', ...
        'floquet.internal.tracking.trackMultipliers', ...
        'floquet.internal.provenance.evaluatorIdentity'};
    files = {fullfile(packageRoot,'analyzeBranch.m'), ...
        fullfile(packageRoot,'computeFDM.m'), ...
        fullfile(packageRoot,'+internal','+poincare','buildMap.m'), ...
        fullfile(packageRoot,'detectBifurcations.m'), ...
        fullfile(packageRoot,'+internal','+tracking','trackMultipliers.m'), ...
        fullfile(packageRoot,'+internal','+provenance', ...
            'evaluatorIdentity.m')};
    item = struct('name','','file','','sha256','','status','unavailable');
    entries = repmat(item,1,numel(files));
    for k = 1:numel(files)
        entries(k).name = names{k};
        entries(k).file = CanonicalFile(files{k});
        [entries(k).sha256,entries(k).status] = FileSHA256(files{k});
    end
    manifest = struct('schemaVersion', ...
        'floquet-implementation-manifest-v2', ...
        'algorithm','SHA-256','entries',entries, ...
        'allAvailable',all(strcmp({entries.status},'computed')));
end

function [state,info] = PrepareCheckpoint(filename,compatibility,opts, ...
        pointCount,stateDimension)
    state = struct();
    info = EmptyCheckpointInfo();
    info.enabled = true;
    info.file = filename;
    info.deleteOnSuccessRequested = opts.DeleteCheckpointOnSuccess;
    if opts.ResumeFromCheckpoint
        if ~isfile(filename)
            error('AnalyzeFloquetBranch:CheckpointMissing', ...
                'Resume checkpoint does not exist: %s',filename);
        end
        checkpoint = LoadCheckpointEnvelope(filename);
        ValidateCheckpointCompatibility(checkpoint,compatibility);
        ValidateCheckpointState(checkpoint.state,pointCount,stateDimension);
        state = checkpoint.state;
        info.resumed = true;
        info.loadedCompletedCount = nnz(state.completed);
        info.lastSavedCompletedCount = info.loadedCompletedCount;
        info.createdAt = checkpoint.createdAt;
    elseif isfile(filename) && ~opts.OverwriteCheckpoint
        error('AnalyzeFloquetBranch:CheckpointExists', ...
            ['CheckpointFile already exists. Resume it or set ' ...
             'OverwriteCheckpoint=true explicitly: %s'],filename);
    end
end

function checkpoint = LoadCheckpointEnvelope(filename)
    try
        loaded = load(filename,'checkpoint');
    catch exception
        error('AnalyzeFloquetBranch:CheckpointRead', ...
            'Could not read checkpoint %s: %s',filename,exception.message);
    end
    if ~isfield(loaded,'checkpoint') || ~isstruct(loaded.checkpoint) || ...
            ~isscalar(loaded.checkpoint)
        error('AnalyzeFloquetBranch:CheckpointFormat', ...
            'File is not an AnalyzeFloquetBranch checkpoint: %s',filename);
    end
    checkpoint = loaded.checkpoint;
    required = {'schemaVersion','compatibility','state','createdAt', ...
        'isFinalAnalysis'};
    if all(isfield(checkpoint,required)) && ...
            strcmp(checkpoint.schemaVersion,'floquet-branch-checkpoint-v1')
        error('AnalyzeFloquetBranch:LegacyCheckpointNonresumable', [ ...
            'This is a v1 checkpoint tied to relocated global evaluator ' ...
            'files. It is read-only provenance and cannot be resumed by ' ...
            'clean-root v2. Start a new v2 scan; completed v1 analysis ' ...
            'artifacts remain inspectable.']);
    end
    if ~all(isfield(checkpoint,required)) || ...
            ~strcmp(checkpoint.schemaVersion,'floquet-branch-checkpoint-v2') || ...
            checkpoint.isFinalAnalysis
        error('AnalyzeFloquetBranch:CheckpointFormat', ...
            'Checkpoint envelope schema is invalid or marked as final analysis.');
    end
end

function ValidateCheckpointCompatibility(checkpoint,expected)
    if ~isequaln(checkpoint.compatibility,expected)
        mismatch = FirstCompatibilityMismatch( ...
            checkpoint.compatibility,expected);
        error('AnalyzeFloquetBranch:CheckpointIncompatible', ...
            'Checkpoint is incompatible with this run (%s).',mismatch);
    end
end

function mismatch = FirstCompatibilityMismatch(actual,expected)
    mismatch = 'strict compatibility record differs';
    if ~isstruct(actual) || ~isscalar(actual)
        mismatch = 'compatibility record is malformed';
        return
    end
    names = fieldnames(expected);
    for k = 1:numel(names)
        if ~isfield(actual,names{k}) || ...
                ~isequaln(actual.(names{k}),expected.(names{k}))
            mismatch = names{k};
            return
        end
    end
    extra = setdiff(fieldnames(actual),names);
    if ~isempty(extra)
        mismatch = ['unexpected field ',extra{1}];
    end
end

function ValidateCheckpointState(state,pointCount,stateDimension)
    required = {'stateSchema','completed','matrices','rawMultipliers', ...
        'rawEigenvectors','solvedEventTimes','baseTopologies', ...
        'topologySignatures','diagnostics','accepted','quality'};
    if ~isstruct(state) || ~isscalar(state) || ~all(isfield(state,required)) || ...
            ~strcmp(state.stateSchema,'floquet-branch-point-state-v2')
        error('AnalyzeFloquetBranch:CheckpointState', ...
            'Checkpoint point-state schema is invalid.');
    end
    completed = state.completed;
    accepted = state.accepted;
    shapesValid = islogical(completed) && isequal(size(completed),[1 pointCount]) && ...
        islogical(accepted) && isequal(size(accepted),[1 pointCount]) && ...
        isequal(size(state.matrices),[stateDimension stateDimension pointCount]) && ...
        isequal(size(state.rawMultipliers),[stateDimension pointCount]) && ...
        iscell(state.rawEigenvectors) && numel(state.rawEigenvectors) == pointCount && ...
        isequal(size(state.solvedEventTimes),[9 pointCount]) && ...
        iscell(state.baseTopologies) && numel(state.baseTopologies) == pointCount && ...
        iscell(state.topologySignatures) && numel(state.topologySignatures) == pointCount && ...
        iscell(state.diagnostics) && numel(state.diagnostics) == pointCount && ...
        isstruct(state.quality) && numel(state.quality) == pointCount;
    if ~shapesValid
        error('AnalyzeFloquetBranch:CheckpointState', ...
            'Checkpoint point-state arrays have incompatible dimensions.');
    end
    if any(diff(double(completed)) > 0)
        error('AnalyzeFloquetBranch:CheckpointState', ...
            'Completed checkpoint points must form one contiguous prefix.');
    end
    if any(accepted & ~completed)
        error('AnalyzeFloquetBranch:CheckpointState', ...
            'An uncompleted checkpoint point cannot be accepted.');
    end
    for k = find(completed)
        if ~isstruct(state.diagnostics{k}) || isempty(state.diagnostics{k})
            error('AnalyzeFloquetBranch:CheckpointState', ...
                'Completed checkpoint point %d lacks diagnostics.',k);
        end
        if accepted(k)
            valid = all(isfinite(state.matrices(:,:,k)),'all') && ...
                all(isfinite(real(state.rawMultipliers(:,k)))) && ...
                all(isfinite(imag(state.rawMultipliers(:,k)))) && ...
                isequal(size(state.rawEigenvectors{k}), ...
                    [stateDimension stateDimension]) && ...
                all(isfinite(real(state.rawEigenvectors{k}(:)))) && ...
                all(isfinite(imag(state.rawEigenvectors{k}(:)))) && ...
                all(isfinite(state.solvedEventTimes(:,k))) && ...
                ~isempty(state.baseTopologies{k});
            if ~valid
                error('AnalyzeFloquetBranch:CheckpointState', ...
                    'Accepted checkpoint point %d has invalid Floquet data.',k);
            end
        elseif any(~isnan(state.matrices(:,:,k)),'all') || ...
                any(~isnan(real(state.rawMultipliers(:,k)))) || ...
                any(~isnan(imag(state.rawMultipliers(:,k)))) || ...
                ~isempty(state.rawEigenvectors{k})
            error('AnalyzeFloquetBranch:CheckpointState', ...
                'Rejected checkpoint point %d contains retained Floquet data.',k);
        end
    end
    for k = find(~completed)
        untouched = all(isnan(state.matrices(:,:,k)),'all') && ...
            all(isnan(real(state.rawMultipliers(:,k)))) && ...
            all(isnan(imag(state.rawMultipliers(:,k)))) && ...
            isempty(state.rawEigenvectors{k}) && ...
            isempty(state.diagnostics{k});
        if ~untouched
            error('AnalyzeFloquetBranch:CheckpointState', ...
                'Uncompleted checkpoint point %d contains partial result data.',k);
        end
    end
end

function state = CaptureCheckpointState(completed,matrices,rawMultipliers, ...
        rawEigenvectors,solvedEventTimes,baseTopologies, ...
        topologySignatures,diagnostics,accepted,quality)
    state = struct('stateSchema','floquet-branch-point-state-v2', ...
        'completed',completed,'matrices',matrices, ...
        'rawMultipliers',rawMultipliers, ...
        'rawEigenvectors',{rawEigenvectors}, ...
        'solvedEventTimes',solvedEventTimes, ...
        'baseTopologies',{baseTopologies}, ...
        'topologySignatures',{topologySignatures}, ...
        'diagnostics',{diagnostics},'accepted',accepted,'quality',quality);
end

function WriteCheckpointFile(filename,compatibility,state,opts,createdAt)
    checkpoint = struct();
    checkpoint.schemaVersion = 'floquet-branch-checkpoint-v2';
    checkpoint.compatibility = compatibility;
    checkpoint.state = state;
    checkpoint.createdAt = createdAt;
    checkpoint.updatedAt = Timestamp();
    checkpoint.completedPointCount = nnz(state.completed);
    checkpoint.completePointScan = all(state.completed);
    checkpoint.isFinalAnalysis = false;
    checkpoint.notice = [ ...
        'Raw resumable point state only; run AnalyzeFloquetBranch to produce ' ...
        'tracking, detection, and a final analysis.'];

    if isfile(filename)
        try
            existing = LoadCheckpointEnvelope(filename);
            owned = isequaln(existing.compatibility,compatibility);
        catch
            owned = false;
        end
        if ~owned && ~opts.OverwriteCheckpoint
            error('AnalyzeFloquetBranch:CheckpointOwnership', ...
                'Refusing to overwrite an unrelated checkpoint file: %s',filename);
        end
    end
    AtomicSaveVariable(filename,'checkpoint',checkpoint,true);
end

function DeleteOwnedCheckpoint(filename,compatibility)
    if ~isfile(filename)
        error('AnalyzeFloquetBranch:CheckpointDeleteMissing', ...
            'Checkpoint disappeared before delete-on-success: %s',filename);
    end
    checkpoint = LoadCheckpointEnvelope(filename);
    ValidateCheckpointCompatibility(checkpoint,compatibility);
    delete(filename);
end

function provenance = BuildProvenance( ...
        source,opts,coverage,scientificAuthority,analysisRole)
    analysisRoot = fileparts(fileparts(mfilename('fullpath')));
    provenance = struct();
    provenance.schemaVersion = 'floquet-provenance-v2';
    provenance.source = source;
    provenance.generatedAt = Timestamp();
    provenance.matlabVersion = version;
    provenance.computeFunction = func2str(opts.ComputeFunction);
    provenance.productionEvaluator = opts.ProductionEvaluator;
    provenance.computeEvaluatorIdentity = opts.EvaluatorIdentity;
    provenance.fullParentCoverage = coverage.fullParentCoverage;
    provenance.orderedParentCoverage = ...
        coverage.fullOrderedParentCoverage;
    provenance.coverage = coverage;
    provenance.scientificAuthority = scientificAuthority;
    provenance.analysisRole = analysisRole;
    provenance.authorityPolicy = [ ...
        'scientific authority requires the canonical algorithm, the ' ...
        'production evaluator, parent-only provenance, and exact ordered ' ...
        'coverage of every source branch column'];
    provenance.mapDefinition = ...
        'derivative of the 12-coordinate reduced apex Poincare return map';
    provenance.reducedStateIndices = [1 2 4:13];
    provenance.sectionNormalStateIndex = 3;
    provenance.eventTimePolicy = ...
        'solved internally at each map evaluation; never a Floquet state';
    provenance.parentDataOnly = true;
    provenance.daughterDataLoaded = false;
    provenance.legacyV1ReadPolicy = [ ...
        'Completed floquet-branch-analysis-v1 artifacts may be inspected ' ...
        'as read-only historical evidence. V1 checkpoints are intentionally ' ...
        'nonresumable after the clean-root implementation migration.'];
    provenance.implementation = BuildImplementationManifest(analysisRoot);
    if isempty(opts.CheckpointFile)
        provenance.executionModel = [ ...
            'single-call point computation with optional atomic final save; ' ...
            'checkpointing disabled for this run'];
    else
        provenance.executionModel = [ ...
            'atomically checkpointed per-point raw state with strict ' ...
            'compatibility validation before resume'];
    end
end

function output = SerializableAnalysisOptions(opts)
    output = opts;
    output.ComputeFunction = func2str(opts.ComputeFunction);
    if isempty(opts.StatusFcn)
        output.StatusFcn = '';
    else
        output.StatusFcn = func2str(opts.StatusFcn);
    end
end

function limitations = KnownLimitations(opts)
    limitations = { ...
        ['This function detects and brackets candidates; it does not refine ' ...
         'a critical orbit or continue a daughter branch.'], ...
        ['Generic local branch switching is presently available only for an ' ...
         'additional real +1 direction. A -1 crossing needs a two-stride ' ...
         'corrector and a complex crossing needs invariant-circle methods.'], ...
        ['Rejected points, skipped branch columns, and base-topology changes ' ...
         'split multiplier tracks; no claim is made across those gaps.'], ...
        ['Grazing, simultaneous-event degeneracy, and topology changes can ' ...
         'make the Poincare map nondifferentiable.'], ...
        ['The reported continuation-coordinate crossing is a bracket ' ...
         'interpolation, not a converged critical-orbit refinement.'], ...
        ['A state-space branch secant is used as the trivial +1 tangent only ' ...
         'when all seven physical parameters are constant on that reliable ' ...
         'segment; otherwise +1 classification is deliberately unresolved.']};
    if isempty(opts.CheckpointFile)
        limitations{end+1} = ...
            'Checkpointing was disabled; an interrupted point scan must be rerun.';
    else
        limitations{end+1} = [ ...
            'Checkpoint files contain raw point state only and cannot be used ' ...
            'as final analyses without rerunning tracking and detection.'];
        limitations{end+1} = [ ...
            'A checkpoint path is owned by one analysis process; concurrent ' ...
            'writers to the same file are not supported.'];
    end
end

function status = AnalysisStatus(accepted)
    if all(accepted)
        status = 'complete';
    elseif any(accepted)
        status = 'partial-with-rejected-gaps';
    else
        status = 'all-points-rejected';
    end
end

function detail = ExceptionDiagnostics(exception)
    detail = struct('accepted',false,'valid',false, ...
        'status','unexpected-exception', ...
        'rejectionReasons',{{sprintf('%s: %s', ...
            exception.identifier,exception.message)}}, ...
        'exceptionIdentifier',exception.identifier, ...
        'exceptionMessage',exception.message);
end

function message = RejectionMessage(detail)
    reasons = NestedValue(detail,{'rejectionReasons'},{});
    if iscell(reasons) && ~isempty(reasons)
        message = strjoin(reasons,' | ');
    else
        status = NestedValue(detail,{'status'},'rejected computation');
        if IsScalarText(status)
            message = char(status);
        else
            message = 'rejected computation';
        end
    end
end

function value = NestedNumber(source,path)
    value = NestedValue(source,path,NaN);
    if ~(isnumeric(value) && isreal(value) && isscalar(value))
        value = NaN;
    end
end

function value = NestedValue(source,path,fallback)
    value = source;
    for k = 1:numel(path)
        if ~isstruct(value) || ~isfield(value,path{k})
            value = fallback;
            return
        end
        value = value.(path{k});
    end
end

function tf = IsTrueScalar(value)
    tf = isscalar(value) && ( ...
        (islogical(value) && value) || ...
        (isnumeric(value) && isreal(value) && isfinite(value) && value == 1));
end

function tf = IsScalarText(value)
    tf = ischar(value) || (isstring(value) && isscalar(value));
end

function tf = HasCaseInsensitiveField(source,name)
    tf = isstruct(source) && isscalar(source) && ...
        any(strcmpi(fieldnames(source),name));
end

function prefixed = PrefixReasons(reasons,prefix)
    prefixed = cell(size(reasons));
    for k = 1:numel(reasons)
        prefixed{k} = [prefix,reasons{k}];
    end
end

function NotifyStatus(opts,stage,localIndex,total,branchIndex,message)
    if isempty(opts.StatusFcn)
        return
    end
    status = struct('stage',stage,'localIndex',localIndex, ...
        'total',total,'branchIndex',branchIndex,'message',message);
    opts.StatusFcn(status);
end

function filename = CanonicalFile(filename)
    [status,attributes] = fileattrib(filename);
    if status
        filename = attributes.Name;
    end
end

function same = SameFilePath(left,right)
    left = CanonicalFile(left);
    right = CanonicalFile(right);
    if ispc || ismac
        same = strcmpi(left,right);
    else
        same = strcmp(left,right);
    end
end

function [fingerprint,status] = FileSHA256(filename)
    fingerprint = '';
    status = 'unavailable';
    fileID = fopen(filename,'rb');
    if fileID < 0
        return
    end
    cleanup = onCleanup(@() fclose(fileID));
    try
        digest = java.security.MessageDigest.getInstance('SHA-256');
        while true
            bytes = fread(fileID,1024*1024,'*uint8');
            if isempty(bytes)
                break
            end
            digest.update(typecast(bytes(:),'int8'));
        end
        raw = typecast(digest.digest(),'uint8');
        fingerprint = lower(reshape(dec2hex(raw,2).',1,[]));
        status = 'computed';
    catch exception
        status = ['unavailable: ',exception.identifier];
    end
end

function [fingerprint,status] = NumericArraySHA256(value)
    fingerprint = '';
    try
        digest = java.security.MessageDigest.getInstance('SHA-256');
        header = uint8(sprintf('%s|%s|',class(value),mat2str(size(value))));
        digest.update(typecast(header(:),'int8'));
        bytes = typecast(value(:),'uint8');
        digest.update(typecast(bytes(:),'int8'));
        raw = typecast(digest.digest(),'uint8');
        fingerprint = lower(reshape(dec2hex(raw,2).',1,[]));
        status = 'computed';
    catch exception
        status = ['unavailable: ',exception.identifier];
    end
end

function [fingerprint,status] = SerializableSHA256(value)
    fingerprint = '';
    try
        bytes = getByteStreamFromArray(value);
        digest = java.security.MessageDigest.getInstance('SHA-256');
        digest.update(typecast(uint8(bytes(:)),'int8'));
        raw = typecast(digest.digest(),'uint8');
        fingerprint = lower(reshape(dec2hex(raw,2).',1,[]));
        status = 'computed';
    catch exception
        status = ['unavailable: ',exception.identifier];
    end
end

function filename = CanonicalMatFile(filename,extensionIdentifier,label)
    filename = char(filename);
    [folder,name,extension] = fileparts(filename);
    if isempty(extension)
        extension = '.mat';
    elseif ~strcmpi(extension,'.mat')
        error(extensionIdentifier,'%s must use the .mat extension.',label);
    end
    if isempty(folder)
        folder = pwd;
    end
    if ~isfolder(folder)
        error('AnalyzeFloquetBranch:MatFileDirectory', ...
            '%s directory does not exist: %s',label,folder);
    end
    filename = fullfile(CanonicalFile(folder),[name extension]);
end

function filename = CanonicalOutputFile(filename)
    filename = CanonicalMatFile(filename, ...
        'AnalyzeFloquetBranch:OutputExtension','OutputFile');
end

function WriteAnalysisFile(filename,analysis,overwrite)
    if isfile(filename) && ~overwrite
        error('AnalyzeFloquetBranch:OutputExists', ...
            'Output file already exists: %s',filename);
    end
    AtomicSaveVariable(filename,'analysis',analysis,overwrite);
end

function AtomicSaveVariable(filename,variableName,value,overwrite)
    folder = fileparts(filename);
    temporary = [tempname(folder),'.mat'];
    cleanup = onCleanup(@() DeleteIfPresent(temporary));
    container = struct();
    container.(variableName) = value;
    save(temporary,'-struct','container','-v7.3');
    if overwrite
        [ok,message] = movefile(temporary,filename,'f');
    else
        [ok,message] = movefile(temporary,filename);
    end
    if ~ok
        error('AnalyzeFloquetBranch:SaveFailed', ...
            'Could not atomically install %s: %s',filename,message);
    end
end

function DeleteIfPresent(filename)
    if isfile(filename)
        delete(filename);
    end
end

function value = Timestamp()
    value = char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
end
