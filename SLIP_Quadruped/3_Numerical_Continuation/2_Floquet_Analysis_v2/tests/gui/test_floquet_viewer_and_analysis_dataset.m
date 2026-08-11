function tests = test_floquet_viewer_and_analysis_dataset
%TEST_FLOQUET_VIEWER_AND_ANALYSIS_DATASET Viewer/dataset regression tests.
%
%   The bounded tests use the corrected, previously computed Poincare-map
%   matrices stored in the authoritative pronking validation report. They
%   exercise the canonical analyzeBranch -> exportDataset -> loadDataset
%   path end to end: analysis, schema projection, atomic save, validation,
%   and GUI updates.
%
%   Set SLIP_RUN_LONG_FLOQUET_GUI_TESTS=1 to recompute columns 194:198 with
%   ComputeFloquetFDM. That production test is intentionally opt-in because
%   every point requires many nonlinear event-timing solves.

    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    analysisRoot = fileparts(fileparts(testRoot));
    slipRoot = fileparts(fileparts(analysisRoot));
    dynamicsRoot = fullfile(slipRoot, '1_Dynamic_Frameworks', 'v2');
    managementRoot = fullfile(slipRoot, '4_Solution_Management');
    experimentRoot = fullfile(analysisRoot, 'reference_experiments', ...
        'PK_multigait_bifurcation');
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(slipRoot, analysisRoot, dynamicsRoot, managementRoot, ...
        experimentRoot);

    branchFile = fullfile(experimentRoot, 'data', ...
        'parent_branch', 'PK_20_2.mat');
    reportFile = fullfile(experimentRoot, 'artifacts', '05_validation', ...
        'pronking_multigait_validation_results.mat');
    branchPayload = load(branchFile, 'results');
    reportPayload = load(reportFile, 'report');
    assert(isfield(reportPayload, 'report') && ...
        isfield(reportPayload.report, 'floquetExperiment'), ...
        'Authoritative report does not contain report.floquetExperiment.');
    fixture = reportPayload.report.floquetExperiment;
    assert(isequal(fixture.sampleIndices(:).', 194:198), ...
        'Authoritative GUI fixture must cover pronking columns 194:198.');

    temporaryDirectory = tempname;
    mkdir(temporaryDirectory);
    testCase.addTeardown(@() CleanupTemporaryDirectory(temporaryDirectory));
    testCase.addTeardown(@() close(findall(groot, ...
        'Type', 'figure', 'Tag', 'FloquetAnalysisFigure')));

    computeFunction = @(solution, parameters, options) ...
        CachedFloquetComputation(solution, parameters, options, fixture);
    analysisOptions = struct( ...
        'BranchName', 'pronking_gui_test', ...
        'Verbose', false, ...
        'ComputeFunction', computeFunction, ...
        'AllowNonProductionComputeFunction', true, ...
        'DetectorOptions', CanonicalDetectorOptions());
    analysis = floquet.analyzeBranch( ...
        branchFile, 194:198, analysisOptions);
    datasetFile = fullfile(temporaryDirectory, ...
        'pronking_gui_test_floquet.mat');
    exportOptions = struct('SaveDataset', true, ...
        'OutputFile', datasetFile, 'Overwrite', true, ...
        'BranchName', 'pronking_gui_test');
    [generated, datasetFile] = ...
        floquet.io.exportDataset(analysis, exportOptions);

    testCase.TestData.AnalysisRoot = analysisRoot;
    testCase.TestData.BranchFile = branchFile;
    testCase.TestData.Branch = branchPayload.results;
    testCase.TestData.Fixture = fixture;
    testCase.TestData.TemporaryDirectory = temporaryDirectory;
    testCase.TestData.DatasetFile = datasetFile;
    testCase.TestData.Generated = generated;
    testCase.TestData.Analysis = analysis;
end

function testAnalyzeExportAndLoadDataset(testCase)
    data = testCase.TestData.Generated;
    testCase.verifyEqual(data.branch_index, 194:198);
    testCase.verifySize(data.solution_state, [13 5]);
    testCase.verifySize(data.event_time, [9 5]);
    testCase.verifySize(data.floquet_matrix, [12 12 5]);
    testCase.verifySize(data.eigenvalues, [12 5]);
    testCase.verifySize(data.eigenvectors, [12 12 5]);
    testCase.verifyTrue(all(data.computation_info.accepted));
    testCase.verifyTrue(all(data.computation_info.base_event_time_valid));
    testCase.verifyTrue(all(isfinite(data.event_time), 'all'));
    testCase.verifyEqual(data.computation_info.section_normal_state_index, 3);
    testCase.verifyFalse( ...
        data.computation_info.branch_point_test_available);
    testCase.verifyEqual(data.computation_info.plus_one_label_policy, ...
        'candidate +1 Floquet degeneracy');
    testCase.verifyFalse(data.computation_info.scientific_authority);
    testCase.verifyEqual(data.computation_info.dataset_role, ...
        'lossless GUI view derived from canonical AnalyzeFloquetBranch result');
    testCase.verifyEqual(data.schema_version, '1.1-analysis-view');

    [loaded, info] = ...
        floquet.io.loadDataset(testCase.TestData.DatasetFile);
    testCase.verifyEqual(loaded.eigenvalues, data.eigenvalues, ...
        'AbsTol', 1e-13);
    testCase.verifyEqual(info.point_count, 5);
    testCase.verifyEqual(info.accepted_count, 5);
end

function testAnalysisExportUsesCanonicalDetector(testCase)
    info = testCase.TestData.Generated.computation_info;
    testCase.verifyFalse(info.scientific_authority);
    testCase.verifyEqual(info.authoritative_detector, 'DetectBifurcation');
    testCase.verifyFalse( ...
        info.candidate_summary.visualization_tracking_used_for_detection);
    testCase.verifySubstring(info.visualization_tracking_role, ...
        'GUI ordering/color continuity only');
    testCase.verifyEqual(info.candidate_summary.authority, ...
        'AnalyzeFloquetBranch');
    testCase.verifyEqual(info.authoritative_candidates, ...
        info.detector_report.Candidates);
    testCase.verifyEqual( ...
        info.detector_report.Options.CrossingTolerance, 1e-8, ...
        'AbsTol', 0);
    testCase.verifyEqual( ...
        info.detector_report.Options.ImaginaryTolerance, 1e-7, ...
        'AbsTol', 0);
    testCase.verifyTrue( ...
        info.detector_report.Options.RequireBranchTangentForPlusOne);

    testCase.verifyEqual(numel(info.base_event_topology), 5);
    testCase.verifyTrue(all(cellfun(@(value) ...
        isstruct(value) && ~isempty(value), info.base_event_topology)));
    testCase.verifyTrue(all(info.adjacent_event_topology_consistent));
    testCase.verifyTrue(all(info.interval_reliability));
    for k = 1:numel(info.adjacent_event_topology_comparison)
        comparison = info.adjacent_event_topology_comparison(k);
        testCase.verifyTrue(comparison.Compared && comparison.Consistent);
        testCase.verifyTrue(comparison.Forward.consistent);
        testCase.verifyTrue(comparison.Reverse.consistent);
    end

    candidates = info.authoritative_candidates;
    plusMask = strcmp({candidates.Type}, '+1');
    testCase.verifyTrue(any(plusMask));
    testCase.verifyTrue(all(strcmp( ...
        {candidates(plusMask).NullDirectionClassification}, ...
        'unresolved-repeated-plus-one-cluster')));
    testCase.verifyTrue(all( ...
        [candidates(plusMask).RepeatedNullCluster]));
    testCase.verifyTrue(all( ...
        [candidates(plusMask).RequiresInvariantSubspaceRefinement]));
    testCase.verifyFalse(any( ...
        [candidates(plusMask).BranchSwitchReady]));
end

function testSparseSelectionCreatesCanonicalTrackingGap(testCase)
    fixture = testCase.TestData.Fixture;
    compute = @(solution, parameters, options) ...
        CachedFloquetComputation(solution, parameters, options, fixture);
    options = struct('Verbose', false, ...
        'ComputeFunction', compute, ...
        'AllowNonProductionComputeFunction', true, ...
        'TrackOptions', struct('ComputeAssignmentGap', false), ...
        'DetectorOptions', CanonicalDetectorOptions());

    analysis = floquet.analyzeBranch( ...
        testCase.TestData.Branch(:, 194:198), [1 2 4 5], options);
    data = floquet.io.exportDataset(analysis);
    info = data.computation_info;
    expectedIntervals = [true false true];

    testCase.verifyEqual(info.detector_report.IntervalReliability, ...
        expectedIntervals);
    testCase.verifyEqual( ...
        info.authoritative_tracking.IntervalReliability, expectedIntervals);
    testCase.verifyTrue(info.authoritative_tracking.Restart(3));
    candidates = info.authoritative_candidates;
    if ~isempty(candidates)
        testCase.verifyFalse(any( ...
            [candidates.LeftIndex] == 2 & [candidates.RightIndex] == 3));
    end
end

function testAnalysisEvaluatorRequiresExplicitNonproductionOptIn(testCase)
    options = struct('Verbose', false, ...
        'ComputeFunction', @RejectedDerivativeWithValidBaseTiming);
    testCase.verifyError(@() floquet.analyzeBranch( ...
        testCase.TestData.Branch(:, 194), [], options), ...
        'AnalyzeFloquetBranch:NonProductionEvaluator');
end

function testAnalysisViewCannotOverwriteParentBranchSource(testCase)
    options = struct('OutputFile', testCase.TestData.BranchFile, ...
        'SaveDataset', true, 'Overwrite', true);
    testCase.verifyError(@() floquet.io.exportDataset( ...
        testCase.TestData.Analysis, options), ...
        'BuildFloquetDatasetFromAnalysis:OutputIsSource');
end

function testVaryingParametersDisableStateSecantPlusOneClassification(testCase)
    branch = testCase.TestData.Branch(:, 194:198);
    branch(23, :) = branch(23, :) + (0:4) * 1e-3;
    fixture = testCase.TestData.Fixture;
    compute = @(solution, parameters, options) ...
        CachedFloquetComputation(solution, parameters, options, fixture);
    options = struct('Verbose', false, ...
        'ComputeFunction', compute, ...
        'AllowNonProductionComputeFunction', true, ...
        'DetectorOptions', CanonicalDetectorOptions());
    analysis = floquet.analyzeBranch(branch, [], options);
    data = floquet.io.exportDataset(analysis);
    info = data.computation_info;
    testCase.verifyFalse(info.branch_tangent_classification_available);
    candidates = info.authoritative_candidates;
    if ~isempty(candidates)
        testCase.verifyFalse(any(strcmp({candidates.Type}, '+1')));
    end
end

function testRejectedPointRemainsExplicit(testCase)
    data = testCase.TestData.Generated;
    % Reject an endpoint that is not part of the saved authoritative
    % crossing bracket.  A dataset that merely flips an endpoint of an
    % authoritative candidate to rejected is intentionally invalid: the
    % detector inventory must be regenerated as well.
    rejectedIndex = 1;
    data.computation_info.accepted(rejectedIndex) = false;
    data.computation_info.accepted_count = 4;
    data.computation_info.rejected_count = 1;
    data.computation_info.status = 'partial';
    data.computation_info.base_event_time_valid(rejectedIndex) = false;
    data.computation_info.interval_reliability(rejectedIndex) = false;
    data.computation_info.adjacent_event_topology_consistent( ...
        rejectedIndex) = false;
    data.event_time(:, rejectedIndex) = NaN;
    data.floquet_matrix(:, :, rejectedIndex) = NaN;
    data.eigenvalues(:, rejectedIndex) = complex(NaN, NaN);
    data.eigenvectors(:, :, rejectedIndex) = complex(NaN, NaN);
    data.distance_plus_one(rejectedIndex) = NaN;
    data.distance_minus_one(rejectedIndex) = NaN;
    data.unit_circle_distance(rejectedIndex) = NaN;
    data.bifurcation_indicator(rejectedIndex).is_candidate = false;
    data.bifurcation_indicator(rejectedIndex).candidate_plus_one = false;
    data.bifurcation_indicator(rejectedIndex).candidate_minus_one = false;
    data.bifurcation_indicator(rejectedIndex).candidate_unit_circle = false;
    data.bifurcation_indicator(rejectedIndex).candidate_torus = false;
    data.bifurcation_indicator(rejectedIndex).labels = {};
    details = data.bifurcation_indicator(rejectedIndex).details;
    data.bifurcation_indicator(rejectedIndex).details = details([]);
    [loaded, info] = floquet.io.loadDataset(data);
    testCase.verifyFalse(loaded.computation_info.accepted(rejectedIndex));
    testCase.verifyEqual(info.accepted_count, 4);
    testCase.verifyTrue(all(isnan( ...
        loaded.floquet_matrix(:, :, rejectedIndex)), 'all'));

    legacy = data;
    legacy.computation_info.floquet_method = 'legacy FDM_v2';
    testCase.verifyError(@() floquet.io.loadDataset(legacy), ...
        'LoadFloquetDataset:LegacyMethodRejected');
end

function testMinimumCostConjugateTracking(testCase)
    first = [0.2 + 0.9i; 0.2 - 0.9i; 0.75; 1.15];
    nextOrdered = [0.21 + 0.88i; 0.21 - 0.88i; 0.78; 1.10];
    permutation = [3 2 4 1];
    raw = [first, nextOrdered(permutation)];
    [tracked, ~, info] = ...
        floquet.io.trackDisplayMultipliers(raw, [], struct( ...
        'PreserveConjugatePairs', true));
    testCase.verifyEqual(tracked(:, 2), nextOrdered, 'AbsTol', 1e-13);
    expectedCost = abs(first - raw(:, 2).');
    testCase.verifyEqual(info.cost_matrices{2}, expectedCost, ...
        'AbsTol', 1e-14);
    testCase.verifyTrue(info.pair_constraint_applied(2));

    permutations = perms(1:4);
    totals = zeros(size(permutations, 1), 1);
    for k = 1:size(permutations, 1)
        linear = sub2ind([4 4], (1:4).', permutations(k, :).');
        totals(k) = sum(expectedCost(linear));
    end
    testCase.verifyEqual(info.total_assignment_cost(2), min(totals), ...
        'AbsTol', 1e-13);
end

function testRepeatedEigenvectorTieUsesOverlap(testCase)
    values = [0.5 0.5; 0.5 0.5; 0.8 0.81; 1.2 1.19];
    vectors = zeros(4, 4, 2);
    vectors(:, :, 1) = eye(4);
    vectors(:, :, 2) = eye(4);
    vectors(:, 1:2, 2) = vectors(:, [2 1], 2);
    [~, trackedVectors, info] = ...
        floquet.io.trackDisplayMultipliers(values, vectors);
    overlap = abs(diag(trackedVectors(:, :, 1)' * ...
        trackedVectors(:, :, 2)));
    testCase.verifyEqual(overlap, ones(4, 1), 'AbsTol', 1e-12);
    testCase.verifyTrue(info.overlap_tie_break_applied(2));
end

function testRepeatedComplexPairSubspaceIsAligned(testCase)
    z = 0.35 + 0.82i;
    values = repmat([z; z; conj(z); conj(z)], 1, 2);
    p1 = [1; 1i; 0; 0] / sqrt(2);
    p2 = [0; 0; 1; 1i] / sqrt(2);
    positive = [p1 p2];
    angle = 0.63;
    rotation = [cos(angle) sin(angle); -sin(angle) cos(angle)];
    vectors = zeros(4, 4, 2);
    vectors(:, :, 1) = [positive conj(positive)];
    rotated = positive * rotation;
    vectors(:, :, 2) = [rotated conj(rotated)];
    [~, tracked, ~] = ...
        floquet.io.trackDisplayMultipliers(values, vectors);
    overlap = abs(diag(tracked(:, :, 1)' * tracked(:, :, 2)));
    testCase.verifyEqual(overlap, ones(4, 1), 'AbsTol', 1e-12);
end

function testBranchUsesGaitStyleAndBlackCurrentPoint(testCase)
    data = testCase.TestData.Generated;
    gaitInput = [data.solution_state; data.event_time];
    [expectedGait, expectedAbbreviation, expectedColor, ...
        expectedLineStyle] = Gait_Identification(gaitInput);

    fig = figure('Visible', 'off');
    testCase.addTeardown(@() DeleteIfGraphics(fig));
    ax = axes('Parent', fig);
    [handles, plotInfo] = floquet.gui.plot.updateBranch(ax, data, 3);

    testCase.verifyEqual(handles.branch.Color, expectedColor, ...
        'AbsTol', 1e-12);
    testCase.verifyEqual(handles.branch.LineStyle, ...
        char(string(expectedLineStyle)));
    testCase.verifySubstring(handles.branch.DisplayName, ...
        char(string(expectedGait)));
    testCase.verifyEqual(plotInfo.gait, char(string(expectedGait)));
    testCase.verifyEqual(plotInfo.gait_abbreviation, ...
        char(string(expectedAbbreviation)));
    testCase.verifyEqual(plotInfo.gait_color, expectedColor, ...
        'AbsTol', 1e-12);
    testCase.verifyEqual(handles.current.Marker, '.');
    testCase.verifyEqual(handles.current.LineStyle, 'none');
    testCase.verifyEqual(handles.current.Color, [0 0 0], ...
        'AbsTol', 1e-12);
    testCase.verifyEqual(handles.current.XData, data.branch_index(3));

    handles = floquet.gui.plot.updateBranch(ax, data, 5, handles);
    testCase.verifyEqual(handles.current.Color, [0 0 0], ...
        'AbsTol', 1e-12);
    testCase.verifyEqual(handles.current.XData, data.branch_index(5));
end

function testTrackedModeColorsRemainStableAcrossRawEigPermutation(testCase)
    first = [0.2 + 0.9i; 0.2 - 0.9i; 0.75; 1.15];
    nextOrdered = [0.21 + 0.88i; 0.21 - 0.88i; 0.78; 1.10];
    rawPermutation = [3 2 4 1];
    raw = [first, nextOrdered(rawPermutation)];
    [tracked, ~, tracking] = ...
        floquet.io.trackDisplayMultipliers(raw, [], ...
        struct('PreserveConjugatePairs', true));
    data = struct('branch_index', [1 2], ...
        'continuation_parameter', [0 1], 'eigenvalues', tracked, ...
        'computation_info', struct('accepted', [true true], ...
        'tracking', tracking));

    fig = figure('Visible', 'off');
    testCase.addTeardown(@() DeleteIfGraphics(fig));
    ax = axes('Parent', fig);
    [handles, firstInfo] = floquet.gui.plot.updateSpectrum(ax, data, 1);
    firstColors = handles.multipliers.CData;
    [handles, secondInfo] = ...
        floquet.gui.plot.updateSpectrum(ax, data, 2, handles);
    secondColors = handles.multipliers.CData;

    testCase.verifyEqual(size(unique(handles.mode_palette, 'rows'), 1), 4);
    testCase.verifyEqual(firstInfo.mode_indices, (1:4).');
    testCase.verifyEqual(secondInfo.mode_indices, (1:4).');
    testCase.verifyEqual(firstInfo.mode_color_keys, ...
        secondInfo.mode_color_keys);
    testCase.verifyEqual(firstColors, secondColors, 'AbsTol', 1e-12);
    testCase.verifyEqual(secondColors, ...
        handles.mode_palette(secondInfo.mode_color_keys, :), ...
        'AbsTol', 1e-12);
    testCase.verifyEqual(size(unique(secondColors, 'rows'), 1), 3);

    pairs = secondInfo.conjugate_pairs;
    testCase.assertSize(pairs, [1 2]);
    testCase.verifyEqual(secondColors(pairs(1), :), ...
        secondColors(pairs(2), :), 'AbsTol', 1e-12);

    [handles, revisitInfo] = ...
        floquet.gui.plot.updateSpectrum(ax, data, 1, handles);
    testCase.verifyEqual(revisitInfo.mode_color_keys, ...
        firstInfo.mode_color_keys);
    testCase.verifyEqual(handles.multipliers.CData, firstColors, ...
        'AbsTol', 1e-12);
end

function testSliderAndIndexInputUpdateBothPlots(testCase)
    [fig, ui] = FloquetAnalysisGUI(testCase.TestData.DatasetFile, ...
        'Visible', 'off');
    testCase.addTeardown(@() DeleteIfGraphics(fig));

    ui.SetIndex(3);
    drawnow;
    state = ui.GetState();
    testCase.verifyEqual(state.CurrentIndex, 3);
    testCase.verifyEqual(size(unique( ...
        state.FloquetHandles.mode_palette, 'rows'), 1), ...
        size(state.Data.eigenvalues, 1));
    testCase.verifyEqual(ui.IndexSlider.Value, 3);
    testCase.verifyEqual(ui.IndexInput.Value, 3);
    testCase.verifyEqual(state.BranchHandles.current.XData, ...
        state.Data.branch_index(3));
    testCase.verifyEqual(state.BranchHandles.current.YData, ...
        state.Data.continuation_parameter(3), 'AbsTol', 1e-13);
    VerifyMultiplierScatter(testCase, state, 3);
    VerifyClosestMarkers(testCase, state, 3);

    ui.IndexInput.Value = 4;
    callback = ui.IndexInput.ValueChangedFcn;
    callback(ui.IndexInput, []);
    drawnow;
    state = ui.GetState();
    testCase.verifyEqual(state.CurrentIndex, 4);
    testCase.verifyEqual(ui.IndexSlider.Value, 4);
    VerifyMultiplierScatter(testCase, state, 4);

    ui.IndexSlider.Value = 2;
    callback = ui.IndexSlider.ValueChangedFcn;
    callback(ui.IndexSlider, []);
    drawnow;
    state = ui.GetState();
    testCase.verifyEqual(state.CurrentIndex, 2);
    testCase.verifyEqual(ui.IndexInput.Value, 2);
    VerifyMultiplierScatter(testCase, state, 2);
end

function testUnitCircleAndCandidateVisualization(testCase)
    [fig, ui] = FloquetAnalysisGUI(testCase.TestData.DatasetFile, ...
        struct('Visible', 'off'));
    testCase.addTeardown(@() DeleteIfGraphics(fig));
    state = ui.GetState();

    circle = findobj(ui.EigenvalueAxes, 'Tag', 'FloquetUnitCircle');
    testCase.assertNotEmpty(circle);
    radii = hypot(circle.XData, circle.YData);
    testCase.verifyLessThan(max(abs(radii - 1)), 5e-13);

    candidate = findobj(ui.BranchAxes, ...
        'Tag', 'FloquetPlusOneCandidateMarkers');
    testCase.assertNotEmpty(candidate);
    testCase.verifyTrue(any(ismember(candidate.XData, [195 196])));
    testCase.verifyEqual(candidate.DisplayName, ...
        'candidate +1 Floquet degeneracy');
    plusIndicators = [state.Data.bifurcation_indicator.candidate_plus_one];
    testCase.verifyTrue(any(plusIndicators));
    labels = {state.Data.bifurcation_indicator(plusIndicators).labels};
    flatLabels = [labels{:}];
    testCase.verifyTrue(any(strcmp(flatLabels, ...
        'candidate +1 Floquet degeneracy')));
    testCase.verifyFalse( ...
        state.Data.computation_info.branch_point_test_available);

    unitCandidates = ...
        state.Data.computation_info.candidate_summary.unit_circle_indices;
    testCase.verifyTrue(any(ismember(unitCandidates, [195 196])));
end

function testEigenvalueAxesDefaultToUnitCircleFocus(testCase)
    data = testCase.TestData.Generated;
    data.eigenvalues(:, 1) = [1; -1; 0.2 + 0.9i; ...
        0.2 - 0.9i; zeros(8, 1)];
    data.eigenvalues(:, 5) = [1e4; zeros(11, 1)];

    fig = figure('Visible', 'off', 'Position', [100 100 420 420]);
    testCase.addTeardown(@() DeleteIfGraphics(fig));
    ax = axes('Parent', fig);
    [handles, plotInfo] = floquet.gui.plot.updateSpectrum(ax, data, 1);
    testCase.verifyEqual(ax.XLim, [-1.25 1.25], 'AbsTol', 1e-12);
    testCase.verifyEqual(ax.YLim, [-1.25 1.25], 'AbsTol', 1e-12);
    testCase.verifyEqual(handles.guides.real_axis.XData, ...
        [-1.25 1.25], 'AbsTol', 1e-12);
    testCase.verifyEqual(plotInfo.axis_mode, 'unit-circle');
    testCase.verifyEqual(plotInfo.off_scale_count, 0);

    [handles, plotInfo] = ...
        floquet.gui.plot.updateSpectrum(ax, data, 5, handles);
    testCase.verifyEqual(ax.XLim, [-1.25 1.25], 'AbsTol', 1e-12);
    testCase.verifyEqual(plotInfo.off_scale_count, 1);
    testCase.verifyEqual(plotInfo.maximum_modulus, 1e4);
    testCase.verifySubstring(ax.Title.String, '1 off-scale');

    [handles, plotInfo] = ...
        floquet.gui.plot.updateSpectrum(ax, data, 5, handles, ...
        struct('AxisMode', 'fit-current'));
    expandedLimit = 1.15e4;
    testCase.verifyEqual(ax.XLim, ...
        [-expandedLimit expandedLimit], 'AbsTol', 1e-9);
    testCase.verifyEqual(handles.guides.real_axis.XData, ...
        [-expandedLimit expandedLimit], 'AbsTol', 1e-9);
    testCase.verifyEqual(plotInfo.axis_mode, 'fit-current');
    testCase.verifyEqual(plotInfo.off_scale_count, 0);

    data.eigenvalues(:, 3) = complex(NaN(12, 1), NaN(12, 1));
    [handles, plotInfo] = ...
        floquet.gui.plot.updateSpectrum(ax, data, 3, handles);
    testCase.verifyEqual(ax.XLim, [-1.25 1.25], 'AbsTol', 1e-12);
    testCase.verifyEqual(handles.guides.imaginary_axis.YData, ...
        [-1.25 1.25], 'AbsTol', 1e-12);
    testCase.verifyEqual(plotInfo.off_scale_count, 0);
end

function testEigenvalueAxisModeControl(testCase)
    [fig, ui] = FloquetAnalysisGUI(testCase.TestData.DatasetFile, ...
        'Visible', 'off');
    testCase.addTeardown(@() DeleteIfGraphics(fig));
    state = ui.GetState();
    testCase.verifyEqual(state.AxisMode, 'unit-circle');
    testCase.verifyEqual(ui.AxisModeDropdown.Value, 'Unit circle');
    testCase.verifyEqual(ui.EigenvalueAxes.XLim, ...
        [-1.25 1.25], 'AbsTol', 1e-12);

    ui.SetAxisMode('fit-current');
    state = ui.GetState();
    testCase.verifyEqual(state.AxisMode, 'fit-current');
    testCase.verifyEqual(ui.AxisModeDropdown.Value, 'Fit current');

    ui.AxisModeDropdown.Value = 'Unit circle';
    callback = ui.AxisModeDropdown.ValueChangedFcn;
    callback(ui.AxisModeDropdown, []);
    state = ui.GetState();
    testCase.verifyEqual(state.AxisMode, 'unit-circle');
    testCase.verifyEqual(ui.EigenvalueAxes.XLim, ...
        [-1.25 1.25], 'AbsTol', 1e-12);
end

function testRefreshClearsDatasetAndAllDataLayers(testCase)
    [fig, ui] = FloquetAnalysisGUI(testCase.TestData.DatasetFile, ...
        'Visible', 'off');
    testCase.addTeardown(@() DeleteIfGraphics(fig));
    state = ui.GetState();
    testCase.verifyNotEmpty(state.Data);
    testCase.verifyNotEmpty(findobj(ui.BranchAxes, ...
        'Tag', 'FloquetSolutionBranch'));
    testCase.verifyNotEmpty(findobj(ui.EigenvalueAxes, ...
        'Tag', 'FloquetMultiplierScatter'));

    callback = ui.RefreshButton.ButtonPushedFcn;
    callback(ui.RefreshButton, []);
    drawnow;

    state = ui.GetState();
    testCase.verifyEmpty(state.Data);
    testCase.verifyEmpty(state.DatasetFile);
    testCase.verifyEqual(state.CurrentIndex, 1);
    testCase.verifyEmpty(ui.BranchAxes.Children);
    testCase.verifyEmpty(ui.PlusDistanceAxes.Children);
    testCase.verifyEmpty(ui.UnitDistanceAxes.Children);
    testCase.verifyEmpty(findobj(ui.EigenvalueAxes, ...
        'Tag', 'FloquetMultiplierScatter'));
    testCase.verifyNotEmpty(findobj(ui.EigenvalueAxes, ...
        'Tag', 'FloquetUnitCircle'));
    testCase.verifyEqual(ui.EigenvalueAxes.XLim, ...
        [-1.25 1.25], 'AbsTol', 1e-12);
    testCase.verifyEqual(ui.EigenvalueAxes.YLim, ...
        [-1.25 1.25], 'AbsTol', 1e-12);
    testCase.verifyEqual(char(ui.IndexSlider.Enable), 'off');
    testCase.verifyEqual(char(ui.IndexInput.Enable), 'off');
    testCase.verifyEqual(char(ui.AxisModeDropdown.Enable), 'off');
    computationStatus = findobj(fig, ...
        'Tag', 'FloquetComputationStatus');
    testCase.verifyEqual(computationStatus.Text, ...
        'No Floquet dataset loaded.');
end

function testNumericBooleanIndicatorsRemainPlottable(testCase)
    data = testCase.TestData.Generated;
    fields = {'is_candidate', 'candidate_plus_one', ...
        'candidate_minus_one', 'candidate_unit_circle'};
    for k = 1:numel(data.bifurcation_indicator)
        for fieldIndex = 1:numel(fields)
            name = fields{fieldIndex};
            data.bifurcation_indicator(k).(name) = ...
                double(data.bifurcation_indicator(k).(name));
        end
    end
    loaded = floquet.io.loadDataset(data);
    [fig, ui] = FloquetAnalysisGUI(loaded, 'Visible', 'off');
    testCase.addTeardown(@() DeleteIfGraphics(fig));
    candidate = findobj(ui.BranchAxes, ...
        'Tag', 'FloquetPlusOneCandidateMarkers');
    testCase.verifyNotEmpty(candidate);
    testCase.verifyTrue(any(ismember(candidate.XData, [195 196])));
end

function testSparseSelectionsAreNotJoinedAcrossGaps(testCase)
    data = testCase.TestData.Generated;
    keep = [1 2 3 4];
    data.branch_index = [1 4 5 9];
    data.continuation_parameter = data.continuation_parameter(keep);
    data.distance_plus_one = data.distance_plus_one(keep);
    data.unit_circle_distance = data.unit_circle_distance(keep);
    data.bifurcation_indicator = data.bifurcation_indicator(keep);
    data.computation_info.accepted = true(1, numel(keep));

    fig = figure('Visible', 'off');
    testCase.addTeardown(@() DeleteIfGraphics(fig));
    branchAxes = axes('Parent', fig);
    plusAxes = axes('Parent', fig);
    unitAxes = axes('Parent', fig);
    branchHandles = floquet.gui.plot.updateBranch(branchAxes, data, 1);
    indicatorHandles = floquet.gui.plot.updateIndicators( ...
        plusAxes, unitAxes, data, 1, struct());

    expectedX = [1 NaN 4 5 NaN 9];
    testCase.verifyEqual(branchHandles.branch.XData, expectedX);
    testCase.verifyEqual(indicatorHandles.plus_line.XData, expectedX);
    testCase.verifyEqual(indicatorHandles.unit_line.XData, expectedX);
    testCase.verifyEqual(branchHandles.branch.Marker, '.');
    testCase.verifyEqual(indicatorHandles.plus_line.Marker, '.');
    testCase.verifyEqual(indicatorHandles.unit_line.Marker, '.');
end

function testResetReturnsToFirstPoint(testCase)
    [fig, ui] = FloquetAnalysisGUI(testCase.TestData.DatasetFile, ...
        struct('Visible', 'off', 'PlaybackPeriod', 0.03));
    testCase.addTeardown(@() DeleteIfGraphics(fig));
    ui.SetIndex(5);
    ui.Reset();
    state = ui.GetState();
    testCase.verifyEqual(state.CurrentIndex, 1);
    testCase.verifyEqual(ui.IndexSlider.Value, 1);
    testCase.verifyEqual(ui.IndexInput.Value, 1);

    ui.Step();
    state = ui.GetState();
    testCase.verifyEqual(state.CurrentIndex, 2);
    VerifyMultiplierScatter(testCase, state, 2);

    ui.Reset();
    ui.Play();
    advanced = WaitForCondition(@() ...
        CurrentFloquetIndex(ui) > 1, 1.0);
    testCase.verifyTrue(advanced, ...
        'Playback timer did not advance the selected branch point.');
    % Stop before taking a multi-field snapshot. Otherwise the timer can
    % advance between reading CurrentIndex and reading the live graphics
    % handle, producing a race in the test rather than a GUI inconsistency.
    ui.Stop();
    state = ui.GetState();
    testCase.verifyGreaterThan(state.CurrentIndex, 1);
    VerifyMultiplierScatter(testCase, state, state.CurrentIndex);
    testCase.verifyEqual(state.BranchHandles.current.XData, ...
        state.Data.branch_index(state.CurrentIndex));
    ui.Play();
    completed = WaitForCondition(@() ~FloquetIsPlaying(ui), 1.5);
    testCase.verifyTrue(completed, ...
        'Playback timer did not stop at the last branch point.');
    state = ui.GetState();
    testCase.verifyEqual(state.CurrentIndex, ...
        numel(state.Data.branch_index));
end

function testMalformedBranchAndNullEigenvectorsAreRejected(testCase)
    malformed = testCase.TestData.Branch(:, 1:40).';
    testCase.verifyError(@() floquet.analyzeBranch( ...
        malformed, [], struct('Verbose', false)), ...
        'AnalyzeFloquetBranch:BranchShape');

    data = testCase.TestData.Generated;
    data.eigenvectors(:, :, 1) = 0;
    testCase.verifyError(@() floquet.io.loadDataset(data), ...
        'LoadFloquetDataset:NullEigenvector');
end

function testRejectedDerivativeRetainsValidBaseEventTimes(testCase)
    options = struct('Verbose', false, ...
        'ComputeFunction', @RejectedDerivativeWithValidBaseTiming, ...
        'AllowNonProductionComputeFunction', true);
    analysis = floquet.analyzeBranch( ...
        testCase.TestData.Branch(:, 194), [], options);
    data = floquet.io.exportDataset(analysis);
    testCase.verifyFalse(data.computation_info.accepted);
    testCase.verifyTrue(data.computation_info.base_event_time_valid);
    testCase.verifyEqual(data.event_time, (0.1:0.1:0.9).', ...
        'AbsTol', 1e-14);
    testCase.verifyTrue(all(isnan(data.floquet_matrix), 'all'));
    [loaded, info] = floquet.io.loadDataset(data);
    testCase.verifyEqual(info.status, 'failed');
    testCase.verifyEqual(loaded.event_time, data.event_time);
end

function testProductionPoincareGenerationOptIn(testCase)
    testCase.assumeTrue(strcmp(getenv( ...
        'SLIP_RUN_LONG_FLOQUET_GUI_TESTS'), '1'), ...
        ['Set SLIP_RUN_LONG_FLOQUET_GUI_TESTS=1 to run the five-point ' ...
         'production Poincare-map computation.']);
    outputDirectory = fullfile( ...
        testCase.TestData.TemporaryDirectory, 'production');
    mkdir(outputDirectory);
    options = struct('BranchName', 'pronking_production_test', ...
        'Verbose', false, 'FloquetOptions', struct( ...
            'PerturbationMagnitude', 5e-7, ...
            'PerturbationFactors', [8 4 2 1], ...
            'TopologyMode', 'clustered', ...
            'RejectOnDerivativeNonconvergence', true, ...
            'RejectOnForwardBackwardMismatch', true, ...
            'ErrorOnFailure', false));
    analysis = floquet.analyzeBranch( ...
        testCase.TestData.BranchFile, 194:198, options);
    filename = fullfile(outputDirectory, ...
        'pronking_production_test_floquet.mat');
    exportOptions = struct('SaveDataset', true, ...
        'OutputFile', filename, 'Overwrite', true, ...
        'BranchName', 'pronking_production_test');
    [data, filename] = floquet.io.exportDataset( ...
        analysis, exportOptions);
    testCase.verifyTrue(isfile(filename));
    testCase.verifyTrue(all(data.computation_info.accepted));
    testCase.verifyTrue(any( ...
        [data.bifurcation_indicator.candidate_plus_one]));
end

function VerifyMultiplierScatter(testCase, state, index)
    actual = state.FloquetHandles.multipliers.XData(:) + ...
        1i * state.FloquetHandles.multipliers.YData(:);
    expected = state.Data.eigenvalues(:, index);
    finite = isfinite(real(expected)) & isfinite(imag(expected));
    expected = expected(finite);
    actualRows = sortrows([real(actual), imag(actual)], [1 2]);
    expectedRows = sortrows([real(expected), imag(expected)], [1 2]);
    testCase.verifyEqual(actualRows, expectedRows, 'AbsTol', 1e-12);

    pairInfo = state.Data.computation_info.tracking.ConjugateInfo{index};
    colorKeys = (1:size(state.Data.eigenvalues, 1)).';
    for pairIndex = 1:size(pairInfo.Pairs, 1)
        pair = pairInfo.Pairs(pairIndex, :);
        colorKeys(pair) = min(pair);
    end
    expectedColors = state.FloquetHandles.mode_palette( ...
        colorKeys(finite), :);
    actualColors = state.FloquetHandles.multipliers.CData;
    testCase.verifyEqual(actualColors, expectedColors, 'AbsTol', 1e-12);
    for pairIndex = 1:size(pairInfo.Pairs, 1)
        pair = pairInfo.Pairs(pairIndex, :);
        visibleRows = find(finite);
        first = find(visibleRows == pair(1), 1);
        second = find(visibleRows == pair(2), 1);
        if ~isempty(first) && ~isempty(second)
            testCase.verifyEqual(actualColors(first, :), ...
                actualColors(second, :), 'AbsTol', 1e-12);
        end
    end
end

function VerifyClosestMarkers(testCase, state, index)
    values = state.Data.eigenvalues(:, index);
    [~, plusIndex] = min(abs(values - 1));
    [~, minusIndex] = min(abs(values + 1));
    plusMarker = state.FloquetHandles.closest_plus_one.XData + ...
        1i * state.FloquetHandles.closest_plus_one.YData;
    minusMarker = state.FloquetHandles.closest_minus_one.XData + ...
        1i * state.FloquetHandles.closest_minus_one.YData;
    testCase.verifyEqual(plusMarker, values(plusIndex), 'AbsTol', 1e-12);
    testCase.verifyEqual(minusMarker, values(minusIndex), 'AbsTol', 1e-12);
end

function [M, lambda, V, detail] = CachedFloquetComputation( ...
        solution, ~, ~, fixture)
    [distance, index] = min(abs( ...
        fixture.continuationCoordinate(:) - solution(1)));
    if isempty(index) || distance > 1e-10
        error('test_floquet_viewer_and_analysis_dataset:FixtureMismatch', ...
            'No corrected cached Floquet point matches dx=%.16g.', solution(1));
    end
    M = fixture.matrices{index};
    lambda = fixture.multipliers(:, index);
    V = fixture.eigenvectors{index};
    detail = fixture.diagnostics{index};
end

function [M, lambda, V, detail] = ...
        RejectedDerivativeWithValidBaseTiming(~, ~, ~)
    M = [];
    lambda = [];
    V = [];
    detail = struct('accepted', false, 'valid', false, ...
        'status', 'rejected-perturbed-map', ...
        'rejectionReasons', {{'synthetic perturbed map rejection'}}, ...
        'mapDefinition', 'reduced apex-to-apex Poincare return map', ...
        'reducedStateIndices', [1 2 4:13], ...
        'baseSolvedEventTimes', (0.1:0.1:0.9).');
end

function options = CanonicalDetectorOptions()
    options = struct('PersistencePoints', 1, ...
        'RequireBranchTangentForPlusOne', true, ...
        'RejectTrivialBranchTangent', true, ...
        'RejectAmbiguousBranchTangent', true, ...
        'CrossingTolerance', 1e-8, ...
        'ImaginaryTolerance', 1e-7);
end

function CleanupTemporaryDirectory(directory)
    if isfolder(directory)
        rmdir(directory, 's');
    end
end

function DeleteIfGraphics(handle)
    if isgraphics(handle)
        delete(handle);
    end
end

function satisfied = WaitForCondition(predicate, timeout)
    start = tic;
    satisfied = predicate();
    while ~satisfied && toc(start) < timeout
        pause(0.02);
        drawnow;
        satisfied = predicate();
    end
end

function index = CurrentFloquetIndex(ui)
    state = ui.GetState();
    index = state.CurrentIndex;
end

function playing = FloquetIsPlaying(ui)
    state = ui.GetState();
    playing = state.Playing;
end
