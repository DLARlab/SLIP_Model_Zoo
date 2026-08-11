function tests = test_floquet_public_api
%TEST_FLOQUET_PUBLIC_API Stable namespace and read-only inspection tests.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    unitRoot = fileparts(mfilename('fullpath'));
    analysisRoot = fileparts(fileparts(unitRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(analysisRoot);
end

function testAllPublicEntryPointsAreResolvable(testCase)
    names = {'floquet.computeFDM', 'floquet.analyzeBranch', ...
        'floquet.detectBifurcations', 'floquet.refineCriticalOrbit', ...
        'floquet.predictBranchDirection', ...
        'floquet.correctBranchSwitch', ...
        'floquet.continueDaughterBranch', ...
        'floquet.validatePeriodicOrbit', 'floquet.inspectAnalysis', ...
        'floquet.io.loadDataset', 'floquet.io.exportDataset', ...
        'floquet.io.trackDisplayMultipliers', 'floquet.gui.launch'};
    for k = 1:numel(names)
        testCase.verifyNotEmpty(which(names{k}), names{k});
    end
end

function testRetiredGlobalAPIsAreNotShipped(testCase)
    % FloquetAnalysisGUI is the one intentional repository-level launcher.
    % Every numerical, workflow, dataset, and plotting operation is
    % package-qualified so stale global files cannot shadow the authority.
    retiredNames = { ...
        'AnalyzeFloquetBranch', 'ApplySectionPerturbation', ...
        'BuildFloquetDatasetFromAnalysis', 'BuildFloquetWorkflowTab', ...
        'BuildPoincareMap', 'ClassifyEventTopology', ...
        'CompareEventTopology', 'ComputeFloquetFDM', ...
        'ContinueDaughterBranch', 'CorrectBranchSwitch', ...
        'CreateFloquetWorkflowConfig', 'DetectBifurcation', ...
        'ExtractSectionState', 'FloquetAnalysisGUIImpl', ...
        'FloquetWorkflowController', 'GenerateFloquetDataset', ...
        'InspectFloquetWorkflowState', 'IsCanonicalFloquetEvaluator', ...
        'LoadFloquetDataset', 'LoadFloquetWorkflowConfig', ...
        'NormalizeFloquetRaySelections', 'PlotUnitCircle', ...
        'PredictBranchDirection', 'RefineCriticalOrbit', ...
        'ResolveFloquetOptions', 'SLIPBranchPlotAdapter', ...
        'ScalePerturbation', 'TrackFloquetMultipliers', ...
        'TrackMultipliers', 'UpdateBranchPlot', ...
        'UpdateFloquetIndicatorPlots', 'UpdateFloquetPlot', ...
        'ValidatePeriodicOrbit', 'AddFloquetNumericalPaths', ...
        'AddFloquetPackagePath', 'ApplyFloquetBranchCorrector', ...
        'ContinueFloquetDaughterStage', ...
        'EnforceFloquetInformationBarrier', ...
        'FindFloquetDaughterSeedsStage', 'FloquetCallbackIdentity', ...
        'FloquetFileSHA256', 'FloquetNumericSHA256', ...
        'FloquetParentIdentity', 'FloquetWorkflowOverwrite', ...
        'InspectFloquetDaughterRays', 'PreflightFloquetArtifacts', ...
        'RefineFloquetCandidateStage', 'ResolveFloquetParentBranch', ...
        'RunFloquetDiscoveryStage', 'ValidateFloquetArtifactChain', ...
        'ValidateFloquetDiscoveryArtifact', ...
        'ValidateFloquetExperimentStage', 'WriteFloquetArtifact', ...
        'WriteFloquetAuditTable'};
    for k = 1:numel(retiredNames)
        testCase.verifyEmpty(which(retiredNames{k}), ...
            sprintf('Retired global API still resolves: %s', ...
            retiredNames{k}));
    end

    unitRoot = fileparts(mfilename('fullpath'));
    analysisRoot = fileparts(fileparts(unitRoot));
    testCase.verifyFalse(isfolder(fullfile(analysisRoot,'compatibility')));
    testCase.verifyFalse(isfolder(fullfile(analysisRoot,'utilities')));
    testCase.verifyFalse(isfile(fullfile(analysisRoot, ...
        'FloquetAnalysisGUI (1).m')));
    testCase.verifyFalse(isfile(fullfile(analysisRoot, ...
        'test_FloquetGUI_pronking.m')));
    testCase.verifyEmpty(which('floquet.io.generateDiagnosticDataset'));
    testCase.verifyEmpty(which( ...
        'floquet.io.internal.GenerateFloquetDataset'));
end

function testDetectorFacadeProducesCanonicalReport(testCase)
    raw = [0.5 0.5 0.5 0.5; 1.5 1.5 1.5 1.5];
    options = struct('PersistencePoints', 1, ...
        'Reliability', true(1, 4), ...
        'IntervalReliability', true(1, 3));
    [candidates, report] = ...
        floquet.detectBifurcations(raw, 0:3, options);

    testCase.verifyEmpty(candidates);
    testCase.verifyEqual(report.Tracks.Multipliers, raw);
    testCase.verifyEqual(report.PointReliability, true(1, 4));
    testCase.verifyEqual(report.IntervalReliability, true(1, 3));
end

function testAnalyzeFacadeUsesQualifiedDefaultDispatcher(testCase)
    % Qualified package code is the sole production evaluator authority.
    testCase.verifyError(@() floquet.analyzeBranch(), ...
        'AnalyzeFloquetBranch:MissingBranch');
    [canonical, identity] = ...
        floquet.internal.provenance.evaluatorIdentity( ...
        @floquet.computeFDM,'floquet.computeFDM');
    testCase.verifyTrue(canonical);
    testCase.verifyEqual(identity.Function, 'floquet.computeFDM');
    [differentEvaluatorIsCanonical, ~] = ...
        floquet.internal.provenance.evaluatorIdentity( ...
        @floquet.validatePeriodicOrbit,'floquet.computeFDM');
    testCase.verifyFalse(differentEvaluatorIsCanonical, ...
        'Only the qualified compute evaluator may gain compute authority.');
end

function testNumericalFacadesDispatchWithoutRecursion(testCase)
    calls = {@() floquet.computeFDM(), ...
        @() floquet.refineCriticalOrbit(), ...
        @() floquet.predictBranchDirection(), ...
        @() floquet.correctBranchSwitch(), ...
        @() floquet.continueDaughterBranch(), ...
        @() floquet.validatePeriodicOrbit()};
    for k = 1:numel(calls)
        exception = [];
        try
            calls{k}();
        catch caught
            exception = caught;
        end
        if ~isempty(exception)
            testCase.verifyNotEqual(exception.identifier, ...
                'MATLAB:recursionLimit');
        end
    end
end

function testInspectCanonicalAnalysisDoesNotRecompute(testCase)
    analysis = FixtureAnalysis();
    [inspection, payload] = floquet.inspectAnalysis(analysis);

    testCase.verifyEqual(inspection.SchemaVersion, ...
        'floquet-inspection-v1');
    testCase.verifyEqual(inspection.SourceType, 'canonical-analysis');
    testCase.verifyEqual(inspection.Source.Kind, 'memory-struct');
    testCase.verifyEqual(inspection.Summary.PointCount, 3);
    testCase.verifyEqual(inspection.Summary.AcceptedCount, 3);
    testCase.verifyEqual(inspection.Summary.CandidateCount, 0);
    testCase.verifyFalse(inspection.Summary.ScientificAuthority);
    testCase.verifyEqual(payload.version, analysis.version);
end

function testInspectCanonicalMatFile(testCase)
    filename = [tempname '.mat'];
    cleanup = onCleanup(@() DeleteIfPresent(filename));
    analysis = FixtureAnalysis();
    save(filename, 'analysis');

    inspection = floquet.inspectAnalysis(filename);

    testCase.verifyEqual(inspection.SourceType, 'canonical-analysis');
    testCase.verifyEqual(inspection.Source.Kind, 'mat-file');
    testCase.verifyEqual(inspection.Source.Variable, 'analysis');
    testCase.verifyEqual(inspection.Source.File, ...
        char(java.io.File(filename).getCanonicalPath()));
end

function testInspectDerivedDatasetUsesDatasetValidator(testCase)
    data = floquet.io.exportDataset(FixtureAnalysis());
    [inspection, payload] = floquet.inspectAnalysis(data);

    testCase.verifyEqual(inspection.SourceType, 'floquet-dataset');
    testCase.verifyEqual(inspection.PayloadSchemaVersion, ...
        '1.1-analysis-view');
    testCase.verifyEqual(inspection.Summary.PointCount, 3);
    testCase.verifyEqual(inspection.Summary.AcceptedCount, 3);
    testCase.verifyFalse(inspection.Summary.ScientificAuthority);
    testCase.verifyEqual(payload.branch_index, 10:12);
end

function testInspectWorkflowConfigAndRevalidateState(testCase)
    config = EmptyWorkflowConfig();
    [configInspection, state] = floquet.inspectAnalysis(config);

    testCase.verifyEqual(configInspection.SourceType, 'workflow-config');
    testCase.verifyEqual(configInspection.Summary.StageCount, 5);
    testCase.verifyEqual(configInspection.Summary.ValidStageCount, 0);
    testCase.verifyEqual(configInspection.Summary.Status, 'not-started');

    % A supplied state is a view, not authority. Reinspection must discard
    % a forged in-memory completion claim and rebuild from config/artifacts.
    state.Stages(1).Status = 'complete';
    state.Stages(1).Valid = true;
    [stateInspection, revalidated] = floquet.inspectAnalysis(state);
    testCase.verifyEqual(stateInspection.SourceType, 'workflow-state');
    testCase.verifyEqual(stateInspection.Summary.ValidStageCount, 0);
    testCase.verifyFalse(revalidated.Stages(1).Valid);
end

function testInspectRejectsAmbiguousWrapper(testCase)
    source = struct('analysis', FixtureAnalysis(), ...
        'FloquetData', floquet.io.exportDataset(FixtureAnalysis()));
    testCase.verifyError(@() floquet.inspectAnalysis(source), ...
        'floquet:inspectAnalysis:AmbiguousStructure');
end

function analysis = FixtureAnalysis()
    count = 3;
    raw = [0.2 0.21 0.22; 1.2 1.1 0.9; ...
        repmat((0.3:0.1:1.2).', 1, count)];
    matrices = NaN(12, 12, count);
    vectors = cell(1, count);
    for k = 1:count
        matrices(:, :, k) = diag(raw(:, k));
        vectors{k} = eye(12);
    end
    [tracks, tracking] = floquet.internal.tracking.trackMultipliers( ...
        raw, vectors, ...
        struct('ComputeAssignmentGap', false));
    states = zeros(13, count);
    states(2, :) = 1;
    eventTimes = repmat([(0.05:0.10:0.75).'; 1], 1, count);
    analysis = struct();
    analysis.version = 'floquet-branch-analysis-v1';
    analysis.algorithmID = ...
        'reduced-poincare-fdm-v2-canonical-branch-scan';
    analysis.status = 'complete';
    analysis.provenance = struct('fixture', true, ...
        'productionEvaluator', false, 'fullParentCoverage', false, ...
        'orderedParentCoverage', false, 'parentDataOnly', true, ...
        'daughterDataLoaded', false, 'scientificAuthority', false);
    analysis.source = struct('file', '', 'stem', 'fixture', ...
        'fullBranchPointCount', 12);
    analysis.parentOnly = true;
    analysis.daughterDataLoaded = false;
    analysis.scientificAuthority = false;
    analysis.fullParentCoverage = false;
    analysis.fullOrderedParentCoverage = false;
    analysis.coverage = struct('fullParentCoverage', false, ...
        'fullOrderedParentCoverage', false);
    analysis.branchIndices = 10:12;
    analysis.continuationCoordinate = [0 1 2];
    analysis.continuationParameterName = 'fixture coordinate';
    analysis.states = states;
    analysis.solvedEventTimes = eventTimes;
    analysis.parameters = repmat([10;20;2;1;0;0.5;1], 1, count);
    analysis.matrices = matrices;
    analysis.rawMultipliers = raw;
    analysis.rawEigenvectors = vectors;
    analysis.accepted = true(1, count);
    analysis.intervalReliability = true(1, count - 1);
    analysis.tracks = tracks;
    analysis.trackingDiagnostics = tracking;
    analysis.candidates = struct([]);
    analysis.detectorReport = struct('Method', 'fixture');
    analysis.quality = struct('fixture', true);
end

function config = EmptyWorkflowConfig()
    outputRoot = fullfile(tempdir, 'floquet_public_api_no_artifacts');
    config = struct();
    config.ExperimentName = 'public-api-fixture';
    config.ExperimentRoot = outputRoot;
    config.ParentBranchFile = fullfile(outputRoot, 'parent.mat');
    config.AnalysisOptions = struct();
    config.Selection = struct('Confirmed', false, 'CandidateIDs', {{}});
    config.Refinement = struct('Options', struct());
    config.BranchSwitch = struct();
    config.Continuation = struct('Confirmed', false, ...
        'RaySelections', struct([]));
    config.Validation = struct( ...
        'ReferenceDaughterBranchFiles', {{}}, 'Function', []);
    artifactRoot = fullfile(outputRoot, 'artifacts');
    config.Files = struct( ...
        'Discovery', fullfile(artifactRoot, '01_discovery.mat'), ...
        'Refinement', fullfile(artifactRoot, '02_refinement.mat'), ...
        'Seeds', fullfile(artifactRoot, '03_seeds.mat'), ...
        'Daughters', fullfile(artifactRoot, '04_daughters.mat'), ...
        'Validation', fullfile(artifactRoot, '05_validation.mat'));
end

function DeleteIfPresent(filename)
    if isfile(filename)
        delete(filename);
    end
end
