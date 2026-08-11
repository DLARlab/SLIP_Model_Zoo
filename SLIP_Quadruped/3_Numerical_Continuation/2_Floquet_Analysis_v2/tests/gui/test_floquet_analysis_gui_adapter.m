function tests = test_floquet_analysis_gui_adapter
%TEST_FLOQUET_ANALYSIS_GUI_ADAPTER Canonical-analysis to GUI-view tests.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(testRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(root);
    testCase.TestData.Root = root;
end

function testBuildAndLoadWithoutFDMRecomputation(testCase)
    analysis = FixtureAnalysis();
    data = floquet.io.exportDataset(analysis);
    [loaded, info] = floquet.io.loadDataset(data);
    testCase.verifyEqual(info.point_count, 3);
    testCase.verifyEqual(loaded.floquet_matrix, analysis.matrices);
    testCase.verifyEqual(loaded.event_time, analysis.solvedEventTimes);
    testCase.verifyEqual(loaded.computation_info.authoritative_candidates, ...
        analysis.candidates);
    testCase.verifyEqual(loaded.computation_info.dataset_role, ...
        'lossless GUI view derived from canonical AnalyzeFloquetBranch result');
end

function testNamespacedExportAndLoadMatchCompatibilityAPI(testCase)
    analysis = FixtureAnalysis();
    expected = floquet.io.exportDataset(analysis);
    actual = floquet.io.exportDataset(analysis);
    testCase.verifyEqual(actual, expected);

    [expectedLoaded, expectedInfo] = floquet.io.loadDataset(expected);
    [actualLoaded, actualInfo] = floquet.io.loadDataset(actual);
    testCase.verifyEqual(actualLoaded, expectedLoaded);
    testCase.verifyEqual(actualInfo, expectedInfo);
end

function testNonProductionAuthorityIsPreserved(testCase)
    analysis = FixtureAnalysis();
    data = floquet.io.exportDataset(analysis);
    testCase.verifyEqual(data.computation_info.algorithm_id, ...
        'nonproduction-evaluator');
    testCase.verifyFalse(data.computation_info.production_evaluator);
    testCase.verifyFalse(data.computation_info.scientific_authority);
    testCase.verifyFalse( ...
        data.computation_info.source_analysis_production_evaluator);
    testCase.verifyFalse( ...
        data.computation_info.source_analysis_scientific_authority);
    testCase.verifyWarningFree(@() floquet.io.loadDataset(data));
end

function testProductionAuthorityRequiresFullParentAnalysis(testCase)
    analysis = FullProductionAnalysis();
    data = floquet.io.exportDataset(analysis);
    testCase.verifyEqual(data.computation_info.algorithm_id, ...
        'reduced-poincare-fdm-v2');
    testCase.verifyTrue(data.computation_info.production_evaluator);
    testCase.verifyTrue(data.computation_info.scientific_authority);
    testCase.verifyTrue( ...
        data.computation_info.source_analysis_full_parent_coverage);
    testCase.verifyTrue( ...
        data.computation_info.source_analysis_ordered_parent_coverage);
    testCase.verifyTrue( ...
        data.computation_info.source_analysis_parent_only);
end

function testProductionSubsetRemainsDiagnostic(testCase)
    analysis = FixtureAnalysis();
    analysis.provenance.productionEvaluator = true;
    data = floquet.io.exportDataset(analysis);
    testCase.verifyEqual(data.computation_info.algorithm_id, ...
        'reduced-poincare-fdm-v2');
    testCase.verifyTrue(data.computation_info.production_evaluator);
    testCase.verifyFalse(data.computation_info.scientific_authority);
    testCase.verifyEqual(data.computation_info.analysis_authority_role, ...
        'diagnostic-production-analysis-view');
end

function testFalseFullCoverageDeclarationIsRejected(testCase)
    analysis = FixtureAnalysis();
    analysis.provenance.productionEvaluator = true;
    analysis.provenance.fullParentCoverage = true;
    analysis.provenance.orderedParentCoverage = true;
    analysis.provenance.scientificAuthority = true;
    analysis.scientificAuthority = true;
    testCase.verifyError(@() floquet.io.exportDataset(analysis), ...
        'BuildFloquetDatasetFromAnalysis:InconsistentCoverage');
end

function testLegacySchemaOneAuthorityIsDowngraded(testCase)
    data = floquet.io.exportDataset(FullProductionAnalysis());
    data.schema_version = '1.0';
    data.computation_info.schema_version = '1.0';
    [loaded,info] = floquet.io.loadDataset(data);
    testCase.verifyTrue(info.authority_downgraded);
    testCase.verifyFalse(loaded.computation_info.scientific_authority);
    testCase.verifyEqual(loaded.computation_info.dataset_role, ...
        'diagnostic-gui-cache');
end

function testLoaderReadsCanonicalAnalysisMatDirectly(testCase)
    analysis = FixtureAnalysis();
    folder = tempname;
    mkdir(folder);
    cleanup = onCleanup(@() rmdir(folder, 's'));
    filename = fullfile(folder, 'analysis.mat');
    save(filename, 'analysis');
    [loaded, info] = floquet.io.loadDataset(filename);
    testCase.verifyEqual(loaded.branch_index, 10:12);
    testCase.verifyTrue(info.converted_from_analysis);
end

function testDisplayTrackingRestartsAtCanonicalIntervalGap(testCase)
    analysis = FixtureAnalysis();
    analysis.intervalReliability = [false true];
    data = floquet.io.exportDataset(analysis);
    tracking = data.computation_info.visualization_tracking;
    testCase.verifyEqual(tracking.IntervalReliability, [false true]);
    testCase.verifyTrue(tracking.Restart(2));
    testCase.verifyTrue(tracking.SegmentStart(2));
    summary = data.computation_info.candidate_summary;
    testCase.verifyFalse( ...
        summary.branch_tangent_classification_available);
end

function testAnalysisViewRequiresCanonicalIntervalMask(testCase)
    data = floquet.io.exportDataset(FixtureAnalysis());
    data.computation_info = rmfield( ...
        data.computation_info, 'interval_reliability');
    testCase.verifyError(@() floquet.io.loadDataset(data), ...
        'LoadFloquetDataset:MissingIntervalReliability');
end

function testReliableIntervalCannotContradictTopology(testCase)
    data = floquet.io.exportDataset(FixtureAnalysis());
    data.computation_info.adjacent_event_topology_consistent = ...
        [false true];
    testCase.verifyError(@() floquet.io.loadDataset(data), ...
        'LoadFloquetDataset:ReliabilityTopologyMismatch');
end

function testDerivedDatasetCannotOverwriteAnalysisSource(testCase)
    folder = tempname;
    mkdir(folder);
    cleanup = onCleanup(@() rmdir(folder, 's'));
    filename = fullfile(folder, 'analysis.mat');
    analysis = FixtureAnalysis();
    analysis.source.file = filename;
    save(filename, 'analysis');
    options = struct('SaveDataset', true, 'OutputFile', filename, ...
        'Overwrite', true);
    testCase.verifyError(@() floquet.io.exportDataset( ...
        analysis, options), ...
        'BuildFloquetDatasetFromAnalysis:OutputIsSource');
    testCase.verifyTrue(isfile(filename));
end

function testDerivedDatasetCannotOverwriteCanonicalAnalysis(testCase)
    folder = tempname;
    mkdir(folder);
    cleanup = onCleanup(@() rmdir(folder, 's'));
    parentFile = fullfile(folder, 'parent_branch.mat');
    analysisFile = fullfile(folder, 'canonical_analysis.mat');
    branch = zeros(29, 2);
    save(parentFile, 'branch');
    analysis = FixtureAnalysis();
    analysis.source.file = parentFile;
    analysis.outputFile = analysisFile;
    save(analysisFile, 'analysis');
    options = struct('SaveDataset', true, 'OutputFile', analysisFile, ...
        'Overwrite', true);
    testCase.verifyError(@() floquet.io.exportDataset( ...
        analysis, options), ...
        'BuildFloquetDatasetFromAnalysis:OutputIsAnalysis');
    contents = whos('-file', analysisFile);
    testCase.verifyTrue(any(strcmp({contents.name}, 'analysis')));
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
    [tracks, tracking] = ...
        floquet.internal.tracking.trackMultipliers(raw, vectors, ...
        struct('ComputeAssignmentGap', false));
    states = zeros(13, count);
    states(2, :) = 1;
    eventTimes = repmat([(0.05:0.10:0.75).'; 1], 1, count);
    analysis = struct();
    analysis.version = 'floquet-branch-analysis-v1';
    analysis.algorithmID = 'reduced-poincare-fdm-v2-canonical-branch-scan';
    analysis.provenance = struct('fixture', true, ...
        'productionEvaluator', false, ...
        'fullParentCoverage', false, ...
        'orderedParentCoverage', false, ...
        'parentDataOnly', true, 'daughterDataLoaded', false, ...
        'scientificAuthority', false);
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

function analysis = FullProductionAnalysis()
    analysis = FixtureAnalysis();
    analysis.branchIndices = 1:3;
    analysis.source.fullBranchPointCount = 3;
    analysis.coverage.fullParentCoverage = true;
    analysis.coverage.fullOrderedParentCoverage = true;
    analysis.fullParentCoverage = true;
    analysis.fullOrderedParentCoverage = true;
    analysis.provenance.productionEvaluator = true;
    analysis.provenance.fullParentCoverage = true;
    analysis.provenance.orderedParentCoverage = true;
    analysis.provenance.scientificAuthority = true;
    analysis.scientificAuthority = true;
end
