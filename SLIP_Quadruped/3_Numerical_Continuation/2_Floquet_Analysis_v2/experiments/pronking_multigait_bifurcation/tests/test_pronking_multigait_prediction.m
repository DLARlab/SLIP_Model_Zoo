function tests = test_pronking_multigait_prediction
%TEST_PRONKINGMULTIGAITPREDICTION Tests for symmetry-resolved branch prediction.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    experimentRoot = fileparts(testRoot);
    addpath(experimentRoot);
    paths = PronkingExperimentPaths();
    addpath(paths.FloquetRoot);
    addpath(paths.UtilitiesRoot);
    addpath(paths.DynamicsRoot);
    addpath(paths.ContinuationAlgorithmRoot);
    addpath(paths.SolutionManagementRoot);
    testCase.TestData.AnalysisRoot = paths.FloquetRoot;
    testCase.TestData.SlipRoot = paths.SlipRoot;
    testCase.TestData.Roadmap = paths.DaughterBranchRoot;
end

function testNewEntryPointsResolve(testCase)
    names = {'ResolvePronkingCriticalSubspace', ...
        'ValidatePronkingDaughterBranches','ExplorePronkingBranchSwitch', ...
        'CorrectPronkingGaitBranch', ...
        'main_Test_PronkingMultiGaitBifurcation', ...
        'main_HandValidate_PronkingBifurcation'};
    for k = 1:numel(names)
        testCase.verifyNotEmpty(which(names{k}),names{k});
    end
end

function testPronkingGaitCorrectorRejectsInvalidRequests(testCase)
    [X,E,parameters,predictor,directions] = DummyCorrectorInputs();
    testCase.verifyError(@() CorrectPronkingGaitBranch( ...
        X,E,parameters,predictor,directions,'invalid',struct()), ...
        'CorrectPronkingGaitBranch:InvalidGaitClass');

    testCase.verifyError(@() CorrectPronkingGaitBranch( ...
        X,E,parameters,[X;E],directions,'B',struct()), ...
        'CorrectPronkingGaitBranch:DegenerateTargetAmplitude');

    malformed = directions;
    malformed.Matrix = zeros(11,3);
    testCase.verifyError(@() CorrectPronkingGaitBranch( ...
        X,E,parameters,predictor,malformed,'B',struct()), ...
        'CorrectPronkingGaitBranch:DirectionShape');

    nonorthogonal = directions;
    nonorthogonal.Matrix(:,3) = nonorthogonal.Matrix(:,2);
    testCase.verifyError(@() CorrectPronkingGaitBranch( ...
        X,E,parameters,predictor,nonorthogonal,'B',struct()), ...
        'CorrectPronkingGaitBranch:NonorthogonalDirections');

    invalidBand = struct('PairSymmetryTolerance',1e-4, ...
        'BrokenSymmetryTolerance',1e-4);
    testCase.verifyError(@() CorrectPronkingGaitBranch( ...
        X,E,parameters,predictor,directions,'B',invalidBand), ...
        'CorrectPronkingGaitBranch:InvalidClassificationBand');

    testCase.verifyError(@() CorrectPronkingGaitBranch( ...
        X,E,parameters,struct(),directions,'B',struct()), ...
        'CorrectPronkingGaitBranch:MissingPredictorState');

    trustRegion = struct('FsolveOptions',optimset( ...
        'Algorithm','trust-region-dogleg'));
    testCase.verifyError(@() CorrectPronkingGaitBranch( ...
        X,E,parameters,predictor,directions,'B',trustRegion), ...
        'CorrectPronkingGaitBranch:OverdeterminedRequiresLM');
end

function testSyntheticPronkingKernelResolvesThreeSymmetryDirections(testCase)
    tangent = UnitVector(12,1);
    bounding = UnitVector(12,2);
    frontSpread = (UnitVector(12,7)-UnitVector(12,11))/sqrt(2);
    hindSpread = (UnitVector(12,5)-UnitVector(12,9))/sqrt(2);
    nullBasis = [tangent,bounding,frontSpread,hindSpread];
    M = 0.5*eye(12) + 0.5*(nullBasis*nullBasis');
    refinement = struct('accepted',true,'floquetMatrix',M, ...
        'localBranchTangent',tangent,'X',zeros(13,1), ...
        'richardsonFrobeniusMatrixErrorEstimate',1e-14);
    options = struct('StateScale',ones(12,1), ...
        'MatrixUncertainty',1e-12,'NullityTolerance',1e-8, ...
        'SectorRankTolerance',1e-7,'ThrowOnFailure',true);

    [directions,diagnostics] = ...
        ResolvePronkingCriticalSubspace(refinement,options);

    testCase.verifyTrue(diagnostics.accepted);
    testCase.verifyEqual(diagnostics.numericalNullity,4);
    testCase.verifyEqual(diagnostics.additionalDimension,3);
    testCase.verifyEqual(diagnostics.fullSectorRanks,[2 1 1 0]);
    testCase.verifyEqual(diagnostics.additionalSectorRanks,[1 1 1 0]);
    testCase.verifySize(directions.Matrix,[12 3]);
    testCase.verifyEqual(directions.Matrix'*directions.Matrix,eye(3), ...
        'AbsTol',1e-12);
    testCase.verifyLessThan(norm((M-eye(12))*directions.Matrix,'fro'),1e-12);
end

function testOneSidedSectorLiftAcceptsOppositeEventOrdering(testCase)
    X = zeros(13,1);
    E = [0.2;0.6;0.2;0.6;0.2;0.6;0.2;0.6;1];
    parameters = ones(7,1);
    direction = UnitVector(12,1);
    eigenData = struct('Type','+1','Multiplier',1, ...
        'Eigenvector',direction,'IsAdditionalNullDirection',true, ...
        'IsTrivialBranchTangent',false, ...
        'BranchTangent',UnitVector(12,2));
    mapOptions = struct('DynamicsFunction',@MockSectorDynamics, ...
        'TopologyMode','clustered','TopologyClusterTolerance',1e-5, ...
        'ErrorOnFailure',true,'SuppressDynamicsOutput',true);
    common = struct('Amplitude',1e-3,'TimingProbeFactor',1, ...
        'StateScale',ones(12,1),'MapOptions',mapOptions, ...
        'RequireAdditionalNullDirection',true);

    central = common;
    central.TimingLiftMode = 'central';
    testCase.verifyError(@() PredictBranchDirection( ...
        X,E,parameters,eigenData,central), ...
        'PredictBranchDirection:EventTopologyChanged');

    oneSided = common;
    oneSided.TimingLiftMode = 'one-sided-sector';
    [deltaZ,~,info] = PredictBranchDirection( ...
        X,E,parameters,eigenData,oneSided);
    testCase.verifyTrue(info.success);
    testCase.verifyEqual(info.method,'one-sided-sector-event-timing-lift');
    testCase.verifyEqual(deltaZ(3),0,'AbsTol',0);
    testCase.verifyEqual(info.eventTimesMinus,[]);
    testCase.verifyTrue(info.topologyConsistent);
    testCase.verifyGreaterThan(norm(deltaZ(14:21)),0);

    opposite = oneSided;
    opposite.PerturbationSign = -1;
    [~,~,oppositeInfo] = PredictBranchDirection( ...
        X,E,parameters,eigenData,opposite);
    comparison = CompareEventTopology(info.sectorTopology, ...
        oppositeInfo.sectorTopology,struct('TopologyMode','strict'));
    testCase.verifyFalse(comparison.consistent);
end

function testPredictorRejectsInvalidSectorOptions(testCase)
    X = zeros(13,1);
    E = [0.1:0.1:0.8 1].';
    parameters = ones(7,1);
    eigenData = struct('Type','+1','Multiplier',1, ...
        'Eigenvector',UnitVector(12,1), ...
        'IsAdditionalNullDirection',true);
    testCase.verifyError(@() PredictBranchDirection(X,E,parameters, ...
        eigenData,struct('TimingLiftMode','two-sided-sector')), ...
        'PredictBranchDirection:InvalidTimingLiftMode');
    testCase.verifyError(@() PredictBranchDirection(X,E,parameters, ...
        eigenData,struct('PerturbationSign',0)), ...
        'PredictBranchDirection:InvalidPerturbationSign');
end

function testSavedDaughterTimingSymmetries(testCase)
    codes = {'BE','BG','FE','FG','HE','HG'};
    indices = [1 1 1 2 1 538];
    expected = {'B','B','F','F','H','H'};
    for k = 1:numel(codes)
        loaded = load(fullfile(testCase.TestData.Roadmap, ...
            sprintf('BD1_20_2_%s.mat',codes{k})),'results');
        solution = loaded.results(1:22,indices(k));
        [hindError,frontError] = PairErrors(solution(14:22));
        switch expected{k}
            case 'B'
                testCase.verifyLessThan(hindError,5e-8);
                testCase.verifyLessThan(frontError,5e-8);
            case 'F'
                testCase.verifyLessThan(hindError,1e-7);
                testCase.verifyGreaterThan(frontError,1e-4);
            case 'H'
                testCase.verifyLessThan(frontError,1e-7);
                testCase.verifyGreaterThan(hindError,1e-4);
        end
        [~,abbreviation] = Gait_Identification(solution);
        testCase.verifyTrue(startsWith(char(abbreviation),expected{k}));
    end
end

function testProductionMultiGaitExperimentWhenEnabled(testCase)
    if ~strcmp(getenv('SLIP_RUN_BRANCH_SWITCH_TESTS'),'1')
        testCase.log(1,[ ...
            'Set SLIP_RUN_BRANCH_SWITCH_TESTS=1 to run the expensive ' ...
            'critical-orbit and held-out daughter validation.']);
        return
    end
    output = tempname;
    cleanup = onCleanup(@() CleanupDirectory(output));
    options = struct('OutputDirectory',output,'MakePlots',false, ...
        'RunNonlinearSearch',false,'Verbose',false,'ThrowOnFailure',true);
    report = main_Test_PronkingMultiGaitBifurcation(options);
    testCase.verifyEqual(report.status,'linear-validated');
    testCase.verifyTrue(report.conclusion.linearPredictionValidated);
    testCase.verifyTrue(report.conclusion.threeGaitClassesIdentified);
    testCase.verifyEqual(report.symmetry.diagnostics.numericalNullity,4);
    testCase.verifyGreaterThan( ...
        min(report.daughterValidation.principalCosines),0.98);
    clear cleanup
    CleanupDirectory(output);
end

function testProductionPronkingGaitCorrectorWhenEnabled(testCase)
    if ~strcmp(getenv('SLIP_RUN_PRONKING_GAIT_CORRECTOR_TESTS'),'1')
        testCase.log(1,[ ...
            'Set SLIP_RUN_PRONKING_GAIT_CORRECTOR_TESTS=1 to run the ' ...
            'two-radius six-arm nonlinear correction test.']);
        return
    end
    output = tempname;
    cleanup = onCleanup(@() CleanupDirectory(output));
    options = struct('OutputDirectory',output,'MakePlots',false, ...
        'RunNonlinearSearch',true,'Verbose',false,'ThrowOnFailure',true);
    report = main_Test_PronkingMultiGaitBifurcation(options);
    search = report.nonlinearSearch;
    testCase.verifyEqual(report.status,'verified');
    testCase.verifyTrue(search.blindSixArmDiscoveryValidated);
    testCase.verifyEqual(search.persistentClassCounts,[2 2 2]);
    testCase.verifyEqual(search.persistentClusterCount,6);
    accepted = search.attempts([search.attempts.nonParentAccepted]);
    testCase.verifyEqual(numel(accepted),12);
    for k = 1:numel(accepted)
        attempt = accepted(k);
        info = attempt.correctorInfo;
        testCase.verifyEqual(attempt.correctorMethod, ...
            'pronking-symmetry-amplitude-corrector');
        testCase.verifyEqual(attempt.requestedGaitClass,attempt.gaitClass);
        testCase.verifyEqual(info.gaitClass,attempt.gaitClass);
        testCase.verifyTrue(all(struct2array(info.validation)));
        testCase.verifyLessThanOrEqual(info.canonicalResidualNormInf,1e-8);
        testCase.verifyLessThanOrEqual(info.symmetryResidualNormInf,1e-7);
        testCase.verifyLessThanOrEqual(abs(info.amplitudeResidual),1e-7);
        testCase.verifyLessThanOrEqual(info.returnResidualNorm,1e-7);
        testCase.verifyLessThanOrEqual(info.eventTimeError,1e-6);
        testCase.verifyTrue(info.periodicValidation.accepted);
        testCase.verifyGreaterThan(attempt.transverseFraction,0.2);
    end
    testCase.verifyTrue(isfile(report.artifacts.searchAttemptsCsv));
    testCase.verifyTrue(isfile(report.artifacts.searchClustersCsv));
    testCase.verifyTrue(isfile(report.artifacts.correctedOrbitsCsv));
    testCase.verifyEqual(height(readtable( ...
        report.artifacts.searchClustersCsv)),6);
    testCase.verifyEqual(height(readtable( ...
        report.artifacts.correctedOrbitsCsv)),12);
    audit = main_HandValidate_PronkingBifurcation(struct( ...
        'ResultsFile',report.artifacts.mat, ...
        'OutputCsv',fullfile(output,'replay.csv'), ...
        'Verbose',false,'ThrowOnFailure',true));
    testCase.verifyTrue(audit.accepted);
    testCase.verifyEqual(audit.acceptedOrbitCount,12);
    clear cleanup
    CleanupDirectory(output);
end

function [X,E,parameters,predictor,directions] = DummyCorrectorInputs()
    X = zeros(13,1);
    E = [0.2;0.6;0.2;0.6;0.2;0.6;0.2;0.6;1];
    parameters = ones(7,1);
    predictor = [X;E];
    predictor(1) = 1e-3;
    directions = struct('Matrix',[UnitVector(12,1), ...
        UnitVector(12,2),UnitVector(12,3)], ...
        'StateScale',ones(12,1));
end

function [residual,T,Y,P,GRFs,Y_EVENT] = ...
        MockSectorDynamics(X,E,~,~)
    X = X(:);
    E = E(:);
    signValue = sign(X(1));
    if signValue == 0
        offsets = zeros(4,1);
    else
        offsets = signValue * [-1.5;-0.5;0.5;1.5] * 1e-4;
    end
    solved = E;
    solved([1 3 5 7]) = 0.2 + offsets;
    solved([2 4 6 8]) = 0.6 + offsets;
    solved(9) = 1;
    residual = zeros(22,1);
    T = [0;1];
    Y = zeros(2,14);
    Y(:,2:14) = repmat(X.',2,1);
    P = [solved;zeros(7,1)];
    GRFs = zeros(2,12);
    Y_EVENT = repmat(Y(2,:),9,1);
end

function vector = UnitVector(count,index)
    vector = zeros(count,1);
    vector(index) = 1;
end

function [hindError,frontError] = PairErrors(E)
    E = E(:);
    T = E(9);
    difference = @(a,b) mod((a-b)/T+0.5,1)-0.5;
    hindError = max(abs([difference(E(1),E(5)), ...
        difference(E(2),E(6))]));
    frontError = max(abs([difference(E(3),E(7)), ...
        difference(E(4),E(8))]));
end

function CleanupDirectory(directory)
    if isfolder(directory)
        rmdir(directory,'s');
    end
end
