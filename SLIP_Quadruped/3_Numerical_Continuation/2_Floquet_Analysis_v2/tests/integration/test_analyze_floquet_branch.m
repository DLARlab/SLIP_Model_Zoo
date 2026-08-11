function tests = test_analyze_floquet_branch
%TEST_ANALYZE_FLOQUET_BRANCH Focused canonical branch-workflow tests.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    analysisRoot = fileparts(fileparts(testRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(analysisRoot);
    testCase.TestData.AnalysisRoot = analysisRoot;
end

function testFullBranchDetectsPersistentAdditionalPlusOne(testCase)
    branch = SyntheticBranch(6);
    options = MockOptions();
    analysis = floquet.analyzeBranch(branch,[],options);

    testCase.verifyEqual(analysis.branchIndices,1:6);
    testCase.verifyEqual(analysis.sampleIndices,analysis.branchIndices);
    testCase.verifyTrue(all(analysis.accepted));
    testCase.verifyEqual(numel(analysis.segments),1);
    testCase.verifyTrue(all(analysis.intervalReliability));
    testCase.verifyFalse(analysis.provenance.productionEvaluator);
    testCase.verifyTrue(analysis.coverage.fullOrderedParentCoverage);
    testCase.verifyFalse(analysis.scientificAuthority);
    testCase.verifyEqual(analysis.analysisRole, ...
        'diagnostic-nonproduction-scan');
    testCase.verifyTrue(analysis.provenance.implementation.allAvailable);
    testCase.verifyTrue(analysis.fixedPhysicalParameterSegment);
    testCase.verifyTrue(analysis.parentOnly);
    testCase.verifyFalse(analysis.daughterDataLoaded);

    plusOne = analysis.candidates(strcmp({analysis.candidates.Type},'+1'));
    testCase.verifyNumElements(plusOne,1);
    testCase.verifyEqual(plusOne.CandidateID,'plus1_c0003_c0004');
    testCase.verifyEqual(plusOne.LeftBranchIndex,3);
    testCase.verifyEqual(plusOne.RightBranchIndex,4);
    testCase.verifyEqual(plusOne.NullDirectionClassification, ...
        'additional-null-direction');
    testCase.verifyTrue(plusOne.IsAdditionalNullDirection);
    testCase.verifyEqual(plusOne.ParameterVector(3),Inf);
    testCase.verifyEqual(analysis.solvedEventTimes(9,:),ones(1,6));
end

function testVaryingPhysicalParameterLeavesPlusOneUnresolved(testCase)
    branch = SyntheticBranch(6);
    branch(23,:) = 1:6;
    options = MockOptions();
    analysis = floquet.analyzeBranch(branch,[],options);

    testCase.verifyFalse(analysis.fixedPhysicalParameterSegment);
    testCase.verifyEqual(analysis.parameterConstancy.VaryingParameterRows,1);
    testCase.verifyTrue(all(isnan(analysis.branchTangents(:))));
    plusOne = analysis.candidates(strcmp({analysis.candidates.Type},'+1'));
    testCase.verifyEmpty(plusOne);
    reasons = {analysis.detectorReport.Rejected.Reason};
    testCase.verifyTrue(any(strcmp(reasons, ...
        'plus-one-null-direction-could-not-be-distinguished')));
end

function testRejectedPointsAndTopologyChangesSplitTracks(testCase)
    branch = SyntheticBranch(7);
    branch(13,3) = 999; % Explicit mock rejection with valid base metadata.
    branch(12,6) = 777; % Different labeled base-event order.
    options = MockOptions();
    analysis = floquet.analyzeBranch(branch,[],options);

    testCase.verifyEqual(analysis.accepted, ...
        logical([1 1 0 1 1 1 1]));
    testCase.verifyEqual([analysis.segments.PointCount],[2 2 1 1]);
    testCase.verifyTrue(isnan(analysis.tracks.Multipliers(1,3)));
    testCase.verifyFalse(analysis.adjacentTopologyConsistent(5));
    testCase.verifyFalse(analysis.adjacentTopologyConsistent(6));
    testCase.verifyEqual(analysis.rejectedReport.pointCount,1);
    testCase.verifyEqual(analysis.rejectedReport.points.BranchIndex,3);
    testCase.verifyGreaterThanOrEqual( ...
        analysis.rejectedReport.intervalCount,4);

    % Accepted is deliberately distinct from adjacent topology consistency.
    testCase.verifyTrue(analysis.accepted(5) && analysis.accepted(6));
    testCase.verifyFalse(analysis.intervalReliability(5));
end

function testSparseSelectionPreservesExplicitSourceGap(testCase)
    branch = SyntheticBranch(6);
    options = MockOptions();
    analysis = floquet.analyzeBranch(branch,[1 2 4 5],options);

    testCase.verifyEqual(analysis.branchIndices,[1 2 4 5]);
    testCase.verifyEqual(analysis.sourceColumnsConsecutive, ...
        logical([1 0 1]));
    testCase.verifyEqual([analysis.segments.PointCount],[2 2]);
    testCase.verifyFalse(analysis.intervalReliability(2));
    testCase.verifyFalse(analysis.coverage.fullParentCoverage);
    testCase.verifyFalse(analysis.coverage.fullOrderedParentCoverage);
    testCase.verifyFalse(analysis.scientificAuthority);
    reasons = analysis.rejectedReport.intervals(1).Reasons;
    testCase.verifyTrue(any(strcmp(reasons,'nonconsecutive-source-columns')));
end

function testMatSourceFingerprintAndAtomicSave(testCase)
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@() RemoveTestFolder(temporaryRoot));
    branchFile = fullfile(temporaryRoot,'synthetic_parent.mat');
    outputFile = fullfile(temporaryRoot,'synthetic_analysis.mat');
    results = SyntheticBranch(6);
    save(branchFile,'results');

    options = MockOptions();
    options.SaveAnalysis = true;
    options.OutputFile = outputFile;
    [analysis,savedFile] = floquet.analyzeBranch(branchFile,[],options);

    testCase.verifyTrue(isfile(savedFile));
    testCase.verifyEqual(savedFile,outputFile);
    testCase.verifyEqual(analysis.source.kind,'mat-file');
    testCase.verifyEqual(analysis.source.variable,'results');
    testCase.verifyEqual(analysis.source.fingerprintStatus,'computed');
    testCase.verifyEqual(numel(analysis.source.fileSHA256),64);
    loaded = load(savedFile,'analysis');
    testCase.verifyEqual(loaded.analysis.source.fileSHA256, ...
        analysis.source.fileSHA256);
    testCase.verifyEqual(loaded.analysis.outputFile,savedFile);
end

function testNonProductionEvaluatorRequiresExplicitFlag(testCase)
    branch = SyntheticBranch(4);
    options = MockOptions();
    options.AllowNonProductionComputeFunction = false;
    testCase.verifyError(@() floquet.analyzeBranch(branch,[],options), ...
        'AnalyzeFloquetBranch:NonProductionEvaluator');
end

function testPositiveInfinitePitchInertiaIsAllowed(testCase)
    branch = SyntheticBranch(4);
    options = MockOptions();
    analysis = floquet.analyzeBranch(branch,[],options);
    testCase.verifyTrue(all(isinf(analysis.parameters(3,:))));

    branch(25,2) = -Inf;
    testCase.verifyError(@() floquet.analyzeBranch(branch,[],options), ...
        'AnalyzeFloquetBranch:ParameterData');
end

function testCheckpointResumeSkipsCompletedEvaluations(testCase)
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@() RemoveInterruptibleFixture(temporaryRoot));
    checkpointFile = fullfile(temporaryRoot,'scan_checkpoint.mat');
    branch = SyntheticBranch(6);
    options = InterruptibleOptions(checkpointFile);

    InterruptControl('reset',3);
    testCase.verifyError(@() floquet.analyzeBranch(branch,[],options), ...
        'MockFloquet:Interrupted');
    testCase.verifyEqual(InterruptControl('count'),3);
    testCase.verifyTrue(isfile(checkpointFile));
    stored = load(checkpointFile,'checkpoint');
    testCase.verifyEqual(stored.checkpoint.state.completed, ...
        logical([1 1 0 0 0 0]));
    testCase.verifyFalse(stored.checkpoint.isFinalAnalysis);

    InterruptControl('reset',0);
    options.ResumeFromCheckpoint = true;
    analysis = floquet.analyzeBranch(branch,[],options);
    testCase.verifyEqual(InterruptControl('count'),4);
    testCase.verifyTrue(all(analysis.accepted));
    testCase.verifyTrue(analysis.provenance.checkpoint.resumed);
    testCase.verifyEqual( ...
        analysis.provenance.checkpoint.loadedCompletedCount,2);
    testCase.verifyFalse( ...
        analysis.provenance.checkpoint.partialCheckpointUsedAsFinalAnalysis);
end

function testIncompatibleCheckpointIsRejectedBeforeEvaluation(testCase)
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@() RemoveInterruptibleFixture(temporaryRoot));
    checkpointFile = fullfile(temporaryRoot,'scan_checkpoint.mat');
    branch = SyntheticBranch(6);
    options = InterruptibleOptions(checkpointFile);

    InterruptControl('reset',3);
    testCase.verifyError(@() floquet.analyzeBranch(branch,[],options), ...
        'MockFloquet:Interrupted');

    changedOptions = options;
    changedOptions.ResumeFromCheckpoint = true;
    changedOptions.FloquetOptions = struct('PerturbationMagnitude',2e-6);
    InterruptControl('reset',0);
    testCase.verifyError( ...
        @() floquet.analyzeBranch(branch,[],changedOptions), ...
        'AnalyzeFloquetBranch:CheckpointIncompatible');
    testCase.verifyEqual(InterruptControl('count'),0);

    changedBranch = branch;
    changedBranch(2,1) = changedBranch(2,1) + 1e-3;
    InterruptControl('reset',0);
    options.ResumeFromCheckpoint = true;
    testCase.verifyError( ...
        @() floquet.analyzeBranch(changedBranch,[],options), ...
        'AnalyzeFloquetBranch:CheckpointIncompatible');
    testCase.verifyEqual(InterruptControl('count'),0);
end

function testCheckpointAndFinalOutputMustBeDifferentFiles(testCase)
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@() RemoveInterruptibleFixture(temporaryRoot));
    sharedFile = fullfile(temporaryRoot,'not_both_checkpoint_and_output.mat');
    options = InterruptibleOptions(sharedFile);
    options.SaveAnalysis = true;
    options.OutputFile = sharedFile;
    InterruptControl('reset',0);

    testCase.verifyError( ...
        @() floquet.analyzeBranch(SyntheticBranch(4),[],options), ...
        'AnalyzeFloquetBranch:OutputIsCheckpoint');
    testCase.verifyEqual(InterruptControl('count'),0);
    testCase.verifyFalse(isfile(sharedFile));
end

function testDeleteCheckpointOnSuccessfulAnalysis(testCase)
    temporaryRoot = tempname;
    mkdir(temporaryRoot);
    cleanup = onCleanup(@() RemoveInterruptibleFixture(temporaryRoot));
    checkpointFile = fullfile(temporaryRoot,'delete_after_success.mat');
    outputFile = fullfile(temporaryRoot,'final_analysis.mat');
    options = InterruptibleOptions(checkpointFile);
    options.DeleteCheckpointOnSuccess = true;
    options.SaveAnalysis = true;
    options.OutputFile = outputFile;
    InterruptControl('reset',0);

    analysis = floquet.analyzeBranch(SyntheticBranch(4),[],options);

    testCase.verifyEqual(InterruptControl('count'),4);
    testCase.verifyFalse(isfile(checkpointFile));
    testCase.verifyTrue( ...
        analysis.provenance.checkpoint.deleteOnSuccessRequested);
    testCase.verifyTrue(analysis.provenance.checkpoint.deletedOnSuccess);
    testCase.verifyFalse(analysis.provenance.checkpoint.retained);
    saved = load(outputFile,'analysis');
    testCase.verifyTrue( ...
        saved.analysis.provenance.checkpoint.deletedOnSuccess);
    testCase.verifyFalse(saved.analysis.provenance.checkpoint.retained);
    testCase.verifyFalse( ...
        saved.analysis.provenance.checkpoint.deletionPending);
end

function testProductionPronkingSmoke(testCase)
    testCase.assumeEqual(getenv('SLIP_RUN_LONG_FLOQUET_TESTS'),'1', ...
        'Set SLIP_RUN_LONG_FLOQUET_TESTS=1 for the production FDM smoke test.');
    branchFile = fullfile(testCase.TestData.AnalysisRoot, ...
        'reference_experiments', ...
        'PK_multigait_bifurcation','data','parent_branch','PK_20_2.mat');
    options = struct();
    options.Verbose = false;
    options.FloquetOptions = struct( ...
        'PerturbationMagnitude',5e-7, ...
        'PerturbationFactors',[8 4 2 1]);
    analysis = floquet.analyzeBranch(branchFile,38:41,options);

    testCase.verifyTrue(all(analysis.accepted));
    testCase.verifyEqual(analysis.branchIndices,38:41);
    testCase.verifyTrue(analysis.provenance.productionEvaluator);
    testCase.verifyFalse(analysis.provenance.fullParentCoverage);
    testCase.verifyFalse(analysis.scientificAuthority);
    testCase.verifyEqual(analysis.analysisRole, ...
        'diagnostic-production-subset-scan');
    testCase.verifyEqual(size(analysis.matrices),[12 12 4]);
    testCase.verifyTrue(all(isfinite(analysis.solvedEventTimes(:))));
    testCase.verifyTrue(all(analysis.fixedPhysicalParameterSegment));
end

function options = MockOptions()
    options = struct();
    options.Verbose = false;
    options.ComputeFunction = @MockFloquetEvaluator;
    options.AllowNonProductionComputeFunction = true;
    options.ContinuationParameterRow = 4;
    options.ContinuationParameterName = 'synthetic parameter';
end

function options = InterruptibleOptions(checkpointFile)
    options = MockOptions();
    options.ComputeFunction = @InterruptibleMockFloquetEvaluator;
    options.CatchComputeExceptions = false;
    options.CheckpointFile = checkpointFile;
    options.CheckpointEvery = 1;
    options.DeleteCheckpointOnSuccess = false;
end

function branch = SyntheticBranch(pointCount)
    coordinate = 1:pointCount;
    branch = zeros(29,pointCount);
    branch(1,:) = 2;
    branch(2,:) = coordinate; % Branch tangent is reduced coordinate 2.
    branch(3,:) = 0;
    branch(4:13,:) = repmat((0.04:0.01:0.13).',1,pointCount);
    branch(4,:) = coordinate;
    events = (0.05:0.10:0.75).';
    branch(14:21,:) = repmat(events,1,pointCount);
    branch(22,:) = 1;
    branch(23,:) = 1;
    branch(24,:) = 1;
    branch(25,:) = Inf; % Para(3): pitch inertia.
    branch(26:29,:) = 1;
end

function [M,lambda,V,detail] = MockFloquetEvaluator(solution,~,options)
    eventTimes = [(0.05:0.10:0.75).'; 1];
    if solution(12) == 777
        eventTimes([1 5]) = eventTimes([5 1]);
    end
    topology = floquet.internal.events.classifyTopology(eventTimes,options);
    critical = 0.65 + 0.10*solution(4);
    lambda = [critical; linspace(-0.8,0.4,11).'];
    M = diag(lambda);
    V = eye(12);
    detail = struct();
    detail.accepted = true;
    detail.valid = true;
    detail.status = 'accepted';
    detail.rejectionReasons = {};
    detail.mapDefinition = 'reduced apex-to-apex Poincare return map';
    detail.reducedStateIndices = [1 2 4:13];
    detail.baseSolvedEventTimes = eventTimes;
    detail.referenceTopology = topology;
    detail.derivativeConvergence = struct('finestRelativeError',1e-8);
    detail.maximumFinestForwardBackwardError = 2e-8;
    detail.selectedPerturbationMagnitude = 1e-6;
    detail.baseValidation = struct( ...
        'periodicResidualNormInf',1e-12, ...
        'timingRepeatability',struct('eventTimingErrorNormInf',1e-13), ...
        'mapInfo',struct('solvedEventTimes',eventTimes, ...
            'eventTopology',topology,'timingResidualNormInf',1e-12));
    if solution(13) == 999
        M = [];
        lambda = [];
        V = [];
        detail.accepted = false;
        detail.valid = false;
        detail.status = 'rejected';
        detail.rejectionReasons = {'synthetic rejected point'};
    end
end

function [M,lambda,V,detail] = ...
        InterruptibleMockFloquetEvaluator(solution,parameters,options)
    [callCount,failOnCall] = InterruptControl('increment');
    if failOnCall > 0 && callCount == failOnCall
        error('MockFloquet:Interrupted','Synthetic interruption.');
    end
    [M,lambda,V,detail] = MockFloquetEvaluator( ...
        solution,parameters,options);
end

function RemoveTestFolder(folder)
    if isfolder(folder)
        rmdir(folder,'s');
    end
end

function RemoveInterruptibleFixture(folder)
    InterruptControl('reset',0);
    RemoveTestFolder(folder);
end

function [count,failOnCall] = InterruptControl(action,value)
    persistent storedCount storedFailure
    if nargin < 2
        value = 0;
    end
    if isempty(storedCount)
        storedCount = 0;
        storedFailure = 0;
    end
    switch action
        case 'reset'
            storedCount = 0;
            storedFailure = value;
        case 'increment'
            storedCount = storedCount + 1;
        case 'count'
            % Read only.
        otherwise
            error('TestFixture:InterruptControl','Unknown action.');
    end
    count = storedCount;
    failOnCall = storedFailure;
end
