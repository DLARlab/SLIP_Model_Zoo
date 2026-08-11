function tests = test_slip_branch_plot_adapter
%TEST_SLIP_BRANCH_PLOT_ADAPTER Reusable quadruped branch-view tests.
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

function testDefaultViewMatchesQuadrupedGUI(testCase)
    axesHandle = NewAxes(testCase);
    adapter = floquet.gui.plot.BranchPlotAdapter(axesHandle);
    testCase.addTeardown(@() delete(adapter));

    testCase.verifyEqual(adapter.AxisIndices, [1 5 2]);
    [azimuth, elevation] = view(axesHandle);
    testCase.verifyEqual([azimuth elevation], [0 90]);
    testCase.verifyEqual(axesHandle.XLabel.String, '$\dot{q}_x$');
    testCase.verifyEqual(axesHandle.YLabel.String, '$\dot{q}_{pitch}$');
    testCase.verifyEqual(axesHandle.ZLabel.String, '$q_y$');
    testCase.verifyEqual(axesHandle.Title.String, ...
        'Plottings of Periodic Solutions');
end

function testBranchCoordinatesAndSelectionPayload(testCase)
    axesHandle = NewAxes(testCase);
    callbackSelections = {};
    adapter = floquet.gui.plot.BranchPlotAdapter(axesHandle, ...
        'SelectionChangedFcn', @CaptureSelection);
    testCase.addTeardown(@() delete(adapter));
    results = FixtureResults(3, 0);

    lineHandle = adapter.AddBranch('parent.mat', results, ...
        'Color', [0.2 0.3 0.4], 'LineStyle', '--');
    testCase.verifyEqual(lineHandle.XData, results(1, :));
    testCase.verifyEqual(lineHandle.YData, results(5, :));
    testCase.verifyEqual(lineHandle.ZData, results(2, :));
    testCase.verifyEqual(lineHandle.LineWidth, 5);
    testCase.verifyEqual(lineHandle.Color, [0.2 0.3 0.4]);
    testCase.verifyEqual(lineHandle.LineStyle, '--');

    selection = adapter.SelectIndex('parent.mat', 2);
    testCase.verifyEqual(selection.Index, 2);
    testCase.verifyEqual(selection.Position, ...
        results([1 5 2], 2).');
    testCase.verifyEqual(selection.X, results(1:22, 2));
    testCase.verifyEqual(selection.Para, results(23:end, 2));
    testCase.verifyEqual(numel(callbackSelections), 1);
    testCase.verifyEqual(callbackSelections{1}.Index, 2);

    marker = findobj(axesHandle, 'Tag', ...
        'SLIPQuadrupedCurrentSolutionMarker');
    label = findobj(axesHandle, 'Tag', ...
        'SLIPQuadrupedCurrentSolutionLabel');
    testCase.verifyNumElements(marker, 1);
    testCase.verifyNumElements(label, 1);
    testCase.verifyEqual([marker.XData marker.YData marker.ZData], ...
        selection.Position);
    testCase.verifyEqual(label.String, ' Current Solution');

    function CaptureSelection(~, value)
        callbackSelections{end + 1} = value;
    end
end

function testAxisChangeUpdatesBranchAndLockedMarker(testCase)
    axesHandle = NewAxes(testCase);
    adapter = floquet.gui.plot.BranchPlotAdapter(axesHandle);
    testCase.addTeardown(@() delete(adapter));
    results = FixtureResults(4, 0);
    lineHandle = adapter.AddBranch('parent.mat', results);
    adapter.SelectIndex('parent.mat', 3);

    adapter.SetAxisIndices([3 4 13]);
    testCase.verifyEqual(lineHandle.XData, results(3, :));
    testCase.verifyEqual(lineHandle.YData, results(4, :));
    testCase.verifyEqual(lineHandle.ZData, results(13, :));
    testCase.verifyEqual(adapter.Selection.Position, ...
        results([3 4 13], 3).');
    marker = findobj(axesHandle, 'Tag', ...
        'SLIPQuadrupedCurrentSolutionMarker');
    testCase.verifyEqual([marker.XData marker.YData marker.ZData], ...
        results([3 4 13], 3).');
end

function testNearestPointUsesAxisSpanNormalizationAndPreferredBranch(testCase)
    axesHandle = NewAxes(testCase);
    adapter = floquet.gui.plot.BranchPlotAdapter(axesHandle);
    testCase.addTeardown(@() delete(adapter));
    first = FixtureResults(3, 0);
    second = FixtureResults(3, 1000);
    firstHandle = adapter.AddBranch('first.mat', first);
    adapter.AddBranch('second.mat', second);
    axesHandle.XLim = [0 100];
    axesHandle.YLim = [0 1000];
    axesHandle.ZLim = [0 1000];

    point = first([1 5 2], 2).' + [0.2 2 2];
    [selection, found] = adapter.ResolveNearest(point, firstHandle);
    testCase.verifyTrue(found);
    testCase.verifyEqual(selection.DatasetName, 'first.mat');
    testCase.verifyEqual(selection.Index, 2);

    locked = adapter.SelectNearest(point, firstHandle);
    testCase.verifyEqual(locked.DatasetName, 'first.mat');
    testCase.verifyEqual(adapter.Branch('first.mat').Handle.LineWidth, 5);
    testCase.verifyEqual(adapter.Branch('second.mat').Handle.LineWidth, 2);
end

function testIndexClampsAndClearRemovesOwnedGraphics(testCase)
    axesHandle = NewAxes(testCase);
    adapter = floquet.gui.plot.BranchPlotAdapter(axesHandle);
    testCase.addTeardown(@() delete(adapter));
    adapter.AddBranch('parent.mat', FixtureResults(3, 0));
    selection = adapter.SelectIndex('parent.mat', 99);
    testCase.verifyEqual(selection.Index, 3);

    adapter.ClearBranches();
    testCase.verifyEmpty(adapter.BranchNames());
    testCase.verifyEmpty(adapter.Selection.Results);
    testCase.verifyEmpty(findobj(axesHandle, 'Tag', ...
        'SLIPQuadrupedSolutionBranch'));
    testCase.verifyEmpty(findobj(axesHandle, 'Tag', ...
        'SLIPQuadrupedCurrentSolutionMarker'));
end

function testUIAxesLineClickLocksNearestPoint(testCase)
    figureHandle = uifigure('Visible', 'off');
    testCase.addTeardown(@() delete(figureHandle));
    axesHandle = uiaxes(figureHandle);
    adapter = floquet.gui.plot.BranchPlotAdapter(axesHandle);
    testCase.addTeardown(@() delete(adapter));
    results = FixtureResults(3, 0);
    lineHandle = adapter.AddBranch('parent.mat', results);

    clickPoint = results([1 5 2], 2).';
    callback = lineHandle.ButtonDownFcn;
    callback(lineHandle, struct('IntersectionPoint', clickPoint));

    testCase.verifyEqual(adapter.Selection.DatasetName, 'parent.mat');
    testCase.verifyEqual(adapter.Selection.Index, 2);
    testCase.verifyEqual(adapter.Selection.Position, clickPoint);
end

function testInputContracts(testCase)
    axesHandle = NewAxes(testCase);
    adapter = floquet.gui.plot.BranchPlotAdapter(axesHandle);
    testCase.addTeardown(@() delete(adapter));
    testCase.verifyError(@() adapter.AddBranch('bad', zeros(21, 2)), ...
        'SLIPBranchPlotAdapter:InvalidResults');
    testCase.verifyError(@() adapter.SetAxisIndices([1 2 14]), ...
        'SLIPBranchPlotAdapter:InvalidAxisIndices');
    testCase.verifyError(@() adapter.SelectIndex('missing', 1), ...
        'SLIPBranchPlotAdapter:UnknownDataset');
end

function results = FixtureResults(count, offset)
    results = zeros(29, count);
    index = 1:count;
    for row = 1:29
        results(row, :) = offset + row .* 100 + index;
    end
end

function axesHandle = NewAxes(testCase)
    figureHandle = figure('Visible', 'off');
    testCase.addTeardown(@() delete(figureHandle));
    axesHandle = axes(figureHandle);
end
