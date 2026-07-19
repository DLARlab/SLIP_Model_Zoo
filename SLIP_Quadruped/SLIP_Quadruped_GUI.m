function SLIP_Quadruped_GUI()
    clc

    rootFolder = fileparts(mfilename('fullpath'));
    if ~isempty(rootFolder) && isfolder(rootFolder)
        addpath(genpath(rootFolder));
    end

    screenSize = get(groot, 'ScreenSize');
    screenWidth = screenSize(3);
    screenHeight = screenSize(4);

    figWidth = min(max(1120, 0.78 * screenWidth), 0.95 * screenWidth);
    figHeight = min(max(740, 0.82 * screenHeight), 0.92 * screenHeight);
    figPosX = max(1, screenWidth * 0.5 - figWidth * 0.5);
    figPosY = max(1, screenHeight * 0.5 - figHeight * 0.5);

    parameteroptions = {'$k_{leg}$', '$k_{swing}$', '$J_{pitch}$', '$l_{leg}$', '$\varphi_{neutral}$', '$l_{b}$', '$k_{r,leg}$'};
    parameterkeys = {'kl', 'ks', 'j', 'll', 'osa', 'lb', 'krl'};
    axisOptions = {'$\dot{q}_x$', '$q_y$', '$\dot{q}_y$', '$q_{pitch}$', ...
        '$\dot{q}_{pitch}$', '$q_{BL}$', '$\dot{q}_{BL}$', ...
        '$q_{FL}$', '$\dot{q}_{FL}$', '$q_{BR}$', '$\dot{q}_{BR}$', ...
        '$q_{FR}$', '$\dot{q}_{FR}$'};
    stateEntryNames = {'dx', 'y', 'dy', 'phi', 'dphi', ...
        'alphaBL', 'dalphaBL', 'alphaFL', 'dalphaFL', ...
        'alphaBR', 'dalphaBR', 'alphaFR', 'dalphaFR'};
    timingEntryNames = {'tBL_TD', 'tBL_LO', 'tFL_TD', 'tFL_LO', ...
        'tBR_TD', 'tBR_LO', 'tFR_TD', 'tFR_LO', 'tAPEX'};
    parameterEntryNames = {'k_leg', 'k_swing', 'J_pitch', 'l_leg', ...
        'phi_neutral', 'l_b', 'k_r_leg'};

    global results baseline plottedDatasets selectedDatasetHandle currentfolder parameterValues parameterIndex brightnessValues colorbarHandle;
    results = [];
    baseline = false;
    plottedDatasets = {};
    selectedDatasetHandle = [];
    currentfolder = pwd;
    parameterValues = [];
    parameterIndex = [];
    brightnessValues = [];
    colorbarHandle = [];
    varyingParameterSortedValues = [];
    statusRowHeight = 42;
    activeDataTip = gobjects(0);
    activeDataTipText = gobjects(0);
    seedSourceMode = 'Cursor';
    seedManualIndex = 1;
    continuationRadiusValue = 0.05;
    previewAxesHandles = gobjects(0);
    statusLabelHandles = gobjects(0);
    statusScrollPanel = gobjects(0);
    statusContentPanel = gobjects(0);
    statusContentMinHeight = 120;
    datasetListValueChangedThisClick = false;
    seedNumericalScrollPanel = gobjects(0);
    seedNumericalContentPanel = gobjects(0);
    seedNumericalContentMinHeight = 360;
    cursorHoverScrollPanel = gobjects(0);
    cursorHoverContentPanel = gobjects(0);
    cursorHoverContentMinHeight = 260;
    cursorSelectedScrollPanel = gobjects(0);
    cursorSelectedContentPanel = gobjects(0);
    cursorSelectedContentMinHeight = 300;
    seedNoiseScrollPanel = gobjects(0);
    seedNoiseContentPanel = gobjects(0);
    seedNoiseContentMinHeight = 155;
    seedPredictionScrollPanel = gobjects(0);
    seedPredictionContentPanel = gobjects(0);
    seedPredictionContentMinHeight = 150;
    seedSolveScrollPanel = gobjects(0);
    seedSolveContentPanel = gobjects(0);
    seedSolveContentMinHeight = 205;
    seedModeDropdowns = gobjects(0);
    seedIndexInputs = gobjects(0);
    seedRadiusInputs = gobjects(0);
    seedContextLabels = gobjects(0);
    seedSelectionSummaryLabel = gobjects(0);
    seedSourceField = gobjects(0);
    seedIndexField = gobjects(0);
    sharedStatusLabel = gobjects(0);
    stateSeedTable = gobjects(0);
    timingSeedTable = gobjects(0);
    parameterSeedTable = gobjects(0);
    seedEditorSignature = "";

    cursorSelection = MakeEmptyCursorSelection();
    hoverSelection = MakeEmptyCursorSelection();
    generatedSeedSolutions = struct('name', {}, 'X', {}, 'Para', {}, 'handle', {});
    seedManualSelectionHandle = gobjects(0);
    seedManualSelectionTextHandle = gobjects(0);
    predictionDistanceLabel = gobjects(0);
    predictionStateDistanceLabel = gobjects(0);
    predictionParameterDistanceLabel = gobjects(0);
    solvedSolutionInfoLabel = gobjects(0);
    appliedNoiseState = struct('datasetName', '', 'index', [], 'seedX', [], 'seedPara', [], ...
        'noiseMode', '', 'stateNoise', [], 'parameterNoise', [], 'X', [], 'Para', []);
    predictedSeedCandidate = struct('datasetName', '', 'index', [], 'X', [], 'Para', [], ...
        'handle', gobjects(0), 'textHandle', gobjects(0));
    solvedSeedCandidate = struct('datasetName', '', 'index', [], 'X', [], 'Para', [], ...
        'residualNorm', [], 'residualVector', [], 'gaitType', '', 'gaitAbbr', '', ...
        'seedInfo', struct(), 'predictedInfo', struct(), 'solverSettings', struct(), ...
        'solverOutput', struct(), 'exitflag', [], 'guessMode', '', ...
        'handle', gobjects(0), 'textHandle', gobjects(0));
    manualAspectRatioValue = [4/3, 1, 1];
    aspectRatioDraftDirty = false;
    tempContinuationResults = [];
    tempContinuationHandle = gobjects(0);
    continuationBusy = false;
    continuationPauseRequested = false;
    continuationStopRequested = false;
    continuationPreviewPredictedSolution = [];
    continuationResultNameInput = gobjects(0);
    pauseContinuationButton = gobjects(0);
    stopContinuationButton = gobjects(0);
    continuationActionPanel = gobjects(0);
    continuationActionContentPanel = gobjects(0);
    continuationActionContentMinHeight = 190;
    parameterActionPanel = gobjects(0);
    parameterActionContentPanel = gobjects(0);
    parameterActionContentMinHeight = 250;
    parameterResultNameInput = gobjects(0);
    pauseParameterButton = gobjects(0);
    stopParameterButton = gobjects(0);
    scanActionPanel = gobjects(0);
    scanActionContentPanel = gobjects(0);
    scanActionContentMinHeight = 250;
    pause2DButton = gobjects(0);
    stop2DButton = gobjects(0);
    scanStatusParameterName = '';
    scanStatusParameterIndex = [];
    scanStatusParameterValue = NaN;
    scanValuesDefaultSignature = '';
    parameterResultSuggestedName = '';
    parameterResultNameWasEdited = false;
    continuationControlOwner = '';
    continuationSeedSourceMode = 'Cursor';
    continuationSeedManualIndex = 1;
    continuationSeedPercentValue = 5;
    continuationSeedSourceDropdown = gobjects(0);
    continuationSeedValueLabel = gobjects(0);
    continuationSeedValueInput = gobjects(0);
    continuationSeedContextLabel = gobjects(0);
    continuationRadiusInput = gobjects(0);
    parameterContinuationSeedSourceDropdown = gobjects(0);
    parameterContinuationSeedValueLabel = gobjects(0);
    parameterContinuationSeedValueInput = gobjects(0);
    parameterContinuationSeedContextLabel = gobjects(0);
    parameterContinuationRadiusInput = gobjects(0);
    scanContinuationSeedSourceDropdown = gobjects(0);
    scanContinuationSeedValueLabel = gobjects(0);
    scanContinuationSeedValueInput = gobjects(0);
    scanContinuationSeedContextLabel = gobjects(0);
    scanContinuationRadiusInput = gobjects(0);
    continuationSecondSeed = MakeEmptyContinuationSecondSeed();

    visualizationT = [];
    visualizationY = [];
    visualizationP = [];
    visualizationGRF = [];
    visualizationColor = [0 0 0];
    visualizationObjects = struct('Animation', [], 'Orbit', [], 'Trajectories', [], 'GRF', []);
    visualizationSelectionKey = '';
    visualizationPlaying = false;
    visualizationStopRequested = false;
    visualizationFrameSettings = struct('Torso', false, 'Legs', false, 'GRF', false);
    visualizationRecordSettings = struct('GIF', false, 'Video', false, 'Keyframes', false);
    visualizationRecording = struct('video', [], 'videoOpen', false, 'gifPath', '', 'gifFirst', true);
    visualizationFPS = 25;

    oscillatorPos = 10;
    oscillatorRadius = 4;
    oscillatorLineWidth = 1.5;
    oscillatorHandles = struct();
    oscillatorDatasetName = '';
    oscillatorIndex = 1;
    oscillatorPlaying = false;
    oscillatorTimer = [];
    oscillatorGifEnabled = false;
    oscillatorGifFilename = 'OscillatorAnimation.gif';
    oscillatorGifPath = '';
    oscillatorGifFirstFrame = true;

    numOPTS = optimset('Algorithm', 'levenberg-marquardt', ...
        'ScaleProblem', 'jacobian', ...
        'Display', 'iter', ...
        'MaxFunEvals', 50000, ...
        'MaxIter', 3000, ...
        'UseParallel', false, ...
        'TolFun', 1e-12, ...
        'TolX', 1e-12);
    seedSolveOPTS = optimset('Algorithm', 'levenberg-marquardt', ...
        'ScaleProblem', 'jacobian', ...
        'Display', 'off', ...
        'MaxFunEvals', 15000, ...
        'MaxIter', 3000, ...
        'UseParallel', false, ...
        'TolFun', 1e-9, ...
        'TolX', 1e-12);

    fig = uifigure('Name', 'SLIP Quadruped GUI', ...
        'Position', [figPosX, figPosY, figWidth, figHeight], ...
        'Scrollable', 'on', ...
        'AutoResizeChildren', 'off');
    fig.CloseRequestFcn = @(src, event) CloseMainGUI();

    mainContainer = uipanel(fig, ...
        'BorderType', 'none', ...
        'Position', GetFigureClientPosition());

    mainGrid = uigridlayout(mainContainer, [3, 2]);
    mainGrid.RowHeight = {'fit', '1x', 93};
    mainGrid.ColumnWidth = {'3.35x', '1.85x'};
    mainGrid.Padding = [12 12 12 12];
    mainGrid.RowSpacing = 10;
    mainGrid.ColumnSpacing = 12;
    fig.SizeChangedFcn = @(src, event) FigureResized();
    if isprop(fig, 'WindowButtonDownFcn')
        fig.WindowButtonDownFcn = @(src, event) FigureWindowClicked();
    end
    if isprop(fig, 'WindowButtonMotionFcn')
        fig.WindowButtonMotionFcn = @(src, event) FigureWindowMoved();
    end

    dataInfoPanel = uipanel(mainGrid, 'Title', 'Data Info');
    dataInfoPanel.Layout.Row = 1;
    dataInfoPanel.Layout.Column = 1;
    dataInfoGrid = uigridlayout(dataInfoPanel, [2, 1]);
    dataInfoGrid.RowHeight = {'fit', 'fit'};
    dataInfoGrid.ColumnWidth = {'1x'};
    dataInfoGrid.Padding = [6 6 6 6];
    dataInfoGrid.RowSpacing = 8;

    controlGrid = uigridlayout(dataInfoGrid, [1, 5]);
    controlGrid.Layout.Row = 1;
    controlGrid.Layout.Column = 1;
    controlGrid.RowHeight = {'fit'};
    controlGrid.ColumnWidth = {'1.45x', 'fit', 82, 82, 82};
    controlGrid.Padding = [0 0 0 0];
    controlGrid.ColumnSpacing = 10;

    parameterGrid = uigridlayout(dataInfoGrid, [1, 2]);
    parameterGrid.Layout.Row = 2;
    parameterGrid.Layout.Column = 1;
    parameterGrid.RowHeight = {'fit'};
    parameterGrid.ColumnWidth = {'1x', '1x'};
    parameterGrid.Padding = [0 0 0 0];
    parameterGrid.ColumnSpacing = 12;

    datasetDropdown = uidropdown(controlGrid, 'Items', GetMatFiles());
    datasetDropdown.Layout.Row = 1;
    datasetDropdown.Layout.Column = 1;

    folderButton = uibutton(controlGrid, 'Text', 'Select Folder', ...
        'ButtonPushedFcn', @(src, event) SelectFolder());
    folderButton.Layout.Row = 1;
    folderButton.Layout.Column = 2;

    plotButton = uibutton(controlGrid, 'Text', 'Plot', ...
        'ButtonPushedFcn', @(src, event) PlotSelectedDataset());
    plotButton.Layout.Row = 1;
    plotButton.Layout.Column = 3;

    plotAllButton = uibutton(controlGrid, 'Text', 'Plot All', ...
        'ButtonPushedFcn', @(src, event) PlotAllDatasets());
    plotAllButton.Layout.Row = 1;
    plotAllButton.Layout.Column = 4;

    deleteAllButton = uibutton(controlGrid, 'Text', 'Delete All', ...
        'ButtonPushedFcn', @(src, event) DeleteAllDatasets());
    deleteAllButton.Layout.Row = 1;
    deleteAllButton.Layout.Column = 5;

    fixedParameterGrid = uigridlayout(parameterGrid, [1, 3]);
    fixedParameterGrid.Layout.Row = 1;
    fixedParameterGrid.Layout.Column = 1;
    fixedParameterGrid.RowHeight = {'fit'};
    fixedParameterGrid.ColumnWidth = {'fit', '1x', '1x'};
    fixedParameterGrid.Padding = [0 0 0 0];
    fixedParameterGrid.ColumnSpacing = 8;

    fixedparameterLabel = uilabel(fixedParameterGrid, 'Text', 'Fixed Parameter:', 'Interpreter', 'latex');
    fixedparameterLabel.Layout.Row = 1;
    fixedparameterLabel.Layout.Column = 1;

    fixedparameterDropdown = uidropdown(fixedParameterGrid, ...
        'Items', {'<none>'}, ...
        'ValueChangedFcn', @(src, event) UpdateFixedParameterValues());
    fixedparameterDropdown.Layout.Row = 1;
    fixedparameterDropdown.Layout.Column = 2;

    fixedparametervalueDropdown = uidropdown(fixedParameterGrid, 'Items', {'<none>'});
    fixedparametervalueDropdown.Layout.Row = 1;
    fixedparametervalueDropdown.Layout.Column = 3;

    varyingParameterGrid = uigridlayout(parameterGrid, [1, 3]);
    varyingParameterGrid.Layout.Row = 1;
    varyingParameterGrid.Layout.Column = 2;
    varyingParameterGrid.RowHeight = {'fit'};
    varyingParameterGrid.ColumnWidth = {'fit', '1x', '1x'};
    varyingParameterGrid.Padding = [0 0 0 0];
    varyingParameterGrid.ColumnSpacing = 8;

    varyingParameterLabel = uilabel(varyingParameterGrid, 'Text', 'Varying Parameter:', 'Interpreter', 'latex');
    varyingParameterLabel.Layout.Row = 1;
    varyingParameterLabel.Layout.Column = 1;

    varyingparameterDropdown = uidropdown(varyingParameterGrid, ...
        'Items', {'<none>'}, ...
        'ValueChangedFcn', @(src, event) UpdateParameterValues());
    varyingparameterDropdown.Layout.Row = 1;
    varyingparameterDropdown.Layout.Column = 2;

    varyingparameterValuesDropdown = uidropdown(varyingParameterGrid, ...
        'Items', {'<none>'}, ...
        'ValueChangedFcn', @(src, event) SelectDatasetFromParameter());
    varyingparameterValuesDropdown.Layout.Row = 1;
    varyingparameterValuesDropdown.Layout.Column = 3;

    plottingPanel = uipanel(mainGrid, 'Title', 'Plotting');
    plottingPanel.Layout.Row = 2;
    plottingPanel.Layout.Column = 1;
    plottingGrid = uigridlayout(plottingPanel, [1, 1]);
    plottingGrid.RowHeight = {'1x'};
    plottingGrid.ColumnWidth = {'1x'};
    plottingGrid.Padding = [6 6 6 6];

    plotTabs = uitabgroup(plottingGrid);
    plotTabs.Layout.Row = 1;
    plotTabs.Layout.Column = 1;
    statePlotTab = uitab(plotTabs, 'Title', 'State Plot');
    hildebrandPlotTab = uitab(plotTabs, 'Title', 'Hildebrand Plot'); %#ok<NASGU>

    statePlotGrid = uigridlayout(statePlotTab, [3, 3]);
    statePlotGrid.RowHeight = {'1x', 'fit', 'fit'};
    statePlotGrid.ColumnWidth = {'1x', '1x', '1x'};
    statePlotGrid.Padding = [6 6 6 6];
    statePlotGrid.RowSpacing = 6;
    statePlotGrid.ColumnSpacing = 8;

    ax = uiaxes(statePlotGrid);
    ax.Layout.Row = 1;
    ax.Layout.Column = [1 3];
    ax.Title.String = 'Plottings of Periodic Solutions';
    ax.XLabel.Interpreter = 'latex';
    ax.YLabel.Interpreter = 'latex';
    ax.ZLabel.Interpreter = 'latex';
    ax.View = [0, 90];
    hold(ax, 'on');

    xAxisLabel = uilabel(statePlotGrid, 'Text', '$x$-Axis', 'Interpreter', 'latex');
    xAxisLabel.Layout.Row = 2;
    xAxisLabel.Layout.Column = 1;

    yAxisLabel = uilabel(statePlotGrid, 'Text', '$y$-Axis', 'Interpreter', 'latex');
    yAxisLabel.Layout.Row = 2;
    yAxisLabel.Layout.Column = 2;

    zAxisLabel = uilabel(statePlotGrid, 'Text', '$z$-Axis', 'Interpreter', 'latex');
    zAxisLabel.Layout.Row = 2;
    zAxisLabel.Layout.Column = 3;

    xAxisDropdown = uidropdown(statePlotGrid, ...
        'Items', axisOptions, ...
        'Value', axisOptions{1}, ...
        'ValueChangedFcn', @(src, event) UpdateAxisData());
    xAxisDropdown.Layout.Row = 3;
    xAxisDropdown.Layout.Column = 1;

    yAxisDropdown = uidropdown(statePlotGrid, ...
        'Items', axisOptions, ...
        'Value', axisOptions{5}, ...
        'ValueChangedFcn', @(src, event) UpdateAxisData());
    yAxisDropdown.Layout.Row = 3;
    yAxisDropdown.Layout.Column = 2;

    zAxisDropdown = uidropdown(statePlotGrid, ...
        'Items', axisOptions, ...
        'Value', axisOptions{2}, ...
        'ValueChangedFcn', @(src, event) UpdateAxisData());
    zAxisDropdown.Layout.Row = 3;
    zAxisDropdown.Layout.Column = 3;

    statusPanel = uipanel(mainGrid, 'Title', 'Status');
    statusPanel.Layout.Row = 3;
    statusPanel.Layout.Column = 1;
    statusGrid = uigridlayout(statusPanel, [1, 1]);
    statusGrid.RowHeight = {'1x'};
    statusGrid.ColumnWidth = {'1x'};
    statusGrid.Padding = [6 6 6 6];

    statusScrollPanel = uipanel(statusGrid, ...
        'BorderType', 'none', ...
        'Scrollable', 'on');
    statusScrollPanel.Layout.Row = 1;
    statusScrollPanel.Layout.Column = 1;
    statusContentPanel = uipanel(statusScrollPanel, ...
        'BorderType', 'none', ...
        'Position', [1, 1, 200, statusContentMinHeight]);
    statusContentGrid = uigridlayout(statusContentPanel, [1, 1]);
    statusContentGrid.RowHeight = {'1x'};
    statusContentGrid.ColumnWidth = {'1x'};
    statusContentGrid.Padding = [6 6 6 6];

    sharedStatusLabel = uilabel(statusContentGrid, 'Text', 'Ready.', ...
        'WordWrap', 'on', 'VerticalAlignment', 'top');
    sharedStatusLabel.Layout.Row = 1;
    sharedStatusLabel.Layout.Column = 1;
    statusLabelHandles(end + 1) = sharedStatusLabel;

    sidebarTabs = uitabgroup(mainGrid);
    sidebarTabs.Layout.Row = [1 3];
    sidebarTabs.Layout.Column = 2;

    infoTab = uitab(sidebarTabs, 'Title', 'Info');
    visualizationTab = uitab(sidebarTabs, 'Title', 'Visualization');
    seedTab = uitab(sidebarTabs, 'Title', 'Solve');
    continuationRootTab = uitab(sidebarTabs, 'Title', 'Continuation');
    oscillatorTab = uitab(sidebarTabs, 'Title', 'Oscillator Plot');

    oscillatorMainGrid = uigridlayout(oscillatorTab, [2, 1]);
    oscillatorMainGrid.RowHeight = {180, '1x'};
    oscillatorMainGrid.ColumnWidth = {'1x'};
    oscillatorMainGrid.Padding = [6 6 6 6];
    oscillatorMainGrid.RowSpacing = 8;

    oscillatorControlPanel = uipanel(oscillatorMainGrid, 'Title', 'Play and Control');
    oscillatorControlPanel.Layout.Row = 1;
    oscillatorControlGrid = uigridlayout(oscillatorControlPanel, [3, 1]);
    oscillatorControlGrid.RowHeight = {'1x', '1x', '1x'};
    oscillatorControlGrid.ColumnWidth = {'1x'};
    oscillatorControlGrid.Padding = [6 4 6 4];
    oscillatorControlGrid.RowSpacing = 5;

    oscillatorIndexRowGrid = uigridlayout(oscillatorControlGrid, [3, 1]);
    oscillatorIndexRowGrid.Layout.Row = 1;
    oscillatorIndexRowGrid.RowHeight = {'0.1x', '0.8x', '0.1x'};
    oscillatorIndexRowGrid.ColumnWidth = {'1x'};
    oscillatorIndexRowGrid.Padding = [0 0 0 0];
    oscillatorIndexRowGrid.RowSpacing = 0;
    oscillatorIndexGrid = uigridlayout(oscillatorIndexRowGrid, [1, 4]);
    oscillatorIndexGrid.Layout.Row = 2;
    oscillatorIndexGrid.ColumnWidth = {'fit', '1x', 58, 'fit'};
    oscillatorIndexGrid.Padding = [0 0 0 0];
    oscillatorIndexGrid.ColumnSpacing = 5;
    uilabel(oscillatorIndexGrid, 'Text', 'Current Index');
    oscillatorIndexSlider = uislider(oscillatorIndexGrid, 'Limits', [1 2], ...
        'Value', 1, 'MajorTicks', [], 'MinorTicks', [], ...
        'ValueChangingFcn', @(~, e) OscillatorIndexChanged(e.Value), ...
        'ValueChangedFcn', @(s, ~) OscillatorIndexChanged(s.Value));
    oscillatorIndexInputGrid = uigridlayout(oscillatorIndexGrid, [3, 1]);
    oscillatorIndexInputGrid.Layout.Column = 3;
    oscillatorIndexInputGrid.RowHeight = {'0.15x', '0.7x', '0.15x'};
    oscillatorIndexInputGrid.ColumnWidth = {'1x'};
    oscillatorIndexInputGrid.Padding = [0 0 0 0];
    oscillatorIndexInputGrid.RowSpacing = 0;
    oscillatorIndexInput = uieditfield(oscillatorIndexInputGrid, 'numeric', ...
        'Value', 1, 'RoundFractionalValues', 'on', ...
        'ValueChangedFcn', @(s, ~) OscillatorIndexChanged(s.Value));
    oscillatorIndexInput.Layout.Row = 2;
    oscillatorTotalLabel = uilabel(oscillatorIndexGrid, 'Text', '/ 0');

    oscillatorSpeedRowGrid = uigridlayout(oscillatorControlGrid, [3, 1]);
    oscillatorSpeedRowGrid.Layout.Row = 2;
    oscillatorSpeedRowGrid.RowHeight = {'0.1x', '0.8x', '0.1x'};
    oscillatorSpeedRowGrid.ColumnWidth = {'1x'};
    oscillatorSpeedRowGrid.Padding = [0 0 0 0];
    oscillatorSpeedRowGrid.RowSpacing = 0;
    oscillatorPlaybackGrid = uigridlayout(oscillatorSpeedRowGrid, [1, 4]);
    oscillatorPlaybackGrid.Layout.Row = 2;
    oscillatorPlaybackGrid.ColumnWidth = {'fit', 'fit', '1x', 'fit'};
    oscillatorPlaybackGrid.Padding = [0 0 0 0];
    oscillatorPlaybackGrid.ColumnSpacing = 4;
    uilabel(oscillatorPlaybackGrid, 'Text', 'Playing Speed');
    uilabel(oscillatorPlaybackGrid, 'Text', 'Slow', 'FontSize', 10);
    oscillatorSpeedSlider = uislider(oscillatorPlaybackGrid, 'Limits', [1 3], ...
        'Value', 2, 'MajorTicks', [], 'MinorTicks', []);
    uilabel(oscillatorPlaybackGrid, 'Text', 'Fast', 'FontSize', 10);

    oscillatorButtonRowGrid = uigridlayout(oscillatorControlGrid, [3, 1]);
    oscillatorButtonRowGrid.Layout.Row = 3;
    oscillatorButtonRowGrid.RowHeight = {'0.15x', '0.7x', '0.15x'};
    oscillatorButtonRowGrid.ColumnWidth = {'1x'};
    oscillatorButtonRowGrid.Padding = [0 0 0 0];
    oscillatorButtonRowGrid.RowSpacing = 0;
    oscillatorButtonGrid = uigridlayout(oscillatorButtonRowGrid, [1, 3]);
    oscillatorButtonGrid.Layout.Row = 2;
    oscillatorButtonGrid.ColumnWidth = {'1x', '1x', 42};
    oscillatorButtonGrid.Padding = [0 0 0 0];
    oscillatorButtonGrid.ColumnSpacing = 5;
    oscillatorPlayButton = uibutton(oscillatorButtonGrid, 'Text', 'Play', ...
        'ButtonPushedFcn', @(~, ~) StartOscillatorPlayback());
    oscillatorPauseButton = uibutton(oscillatorButtonGrid, 'Text', 'Pause', ...
        'ButtonPushedFcn', @(~, ~) StopOscillatorPlayback(false));
    oscillatorSettingsButton = uibutton(oscillatorButtonGrid, 'Text', char(9881), ...
        'Tooltip', 'GIF recording settings', ...
        'ButtonPushedFcn', @(~, ~) OpenOscillatorSettings());

    oscillatorAxesPanel = uipanel(oscillatorMainGrid, ...
        'Title', 'Oscillator Plots', 'BorderType', 'line');
    oscillatorAxesPanel.Layout.Row = 2;
    oscillatorAxesGrid = uigridlayout(oscillatorAxesPanel, [1, 1]);
    oscillatorAxesGrid.RowHeight = {'1x'};
    oscillatorAxesGrid.ColumnWidth = {'1x'};
    oscillatorAxesGrid.Padding = [4 4 4 4];
    oscillatorAx = uiaxes(oscillatorAxesGrid);
    oscillatorAx.Layout.Row = 1;
    oscillatorAx.Layout.Column = 1;
    title(oscillatorAx, 'Oscillator Cycles');
    axis(oscillatorAx, [-2*oscillatorPos 2*oscillatorPos -2*oscillatorPos 2*oscillatorPos]);
    pbaspect(oscillatorAx, [1 1 1]);
    oscillatorAx.XTick = [];
    oscillatorAx.YTick = [];
    oscillatorAx.Box = 'on';
    hold(oscillatorAx, 'on');
    DisableVisualizationAxesToolbar(oscillatorAx);
    ClearOscillatorState();

    visualizationGrid = uigridlayout(visualizationTab, [2, 1]);
    visualizationGrid.RowHeight = {130, '1x'};
    visualizationGrid.ColumnWidth = {'1x'};
    visualizationGrid.Padding = [6 6 6 6];
    visualizationGrid.RowSpacing = 6;

    visualizationControls = uipanel(visualizationGrid, 'Title', 'Playback/Record');
    visualizationControls.Layout.Row = 1;
    visualizationControlGrid = uigridlayout(visualizationControls, [2, 1]);
    visualizationControlGrid.RowHeight = {60, 34};
    visualizationControlGrid.ColumnWidth = {'1x'};
    visualizationControlGrid.Padding = [6 4 6 4];
    visualizationControlGrid.RowSpacing = 3;
    visualizationControlGrid.ColumnSpacing = 5;

    visualizationSliderRowGrid = uigridlayout(visualizationControlGrid, [3, 1]);
    visualizationSliderRowGrid.Layout.Row = 1;
    visualizationSliderRowGrid.RowHeight = {'0.1x', '0.8x', '0.1x'};
    visualizationSliderRowGrid.ColumnWidth = {'1x'};
    visualizationSliderRowGrid.Padding = [0 0 0 0];
    visualizationSliderRowGrid.RowSpacing = 0;
    visualizationSliderContentGrid = uigridlayout(visualizationSliderRowGrid, [1, 6]);
    visualizationSliderContentGrid.Layout.Row = 2;
    visualizationSliderContentGrid.RowHeight = {'1x'};
    visualizationSliderContentGrid.ColumnWidth = {'fit', '1x', '1x', '1x', '1x', 64};
    visualizationSliderContentGrid.Padding = [0 0 0 0];
    visualizationSliderContentGrid.ColumnSpacing = 5;

    visualizationButtonRowGrid = uigridlayout(visualizationControlGrid, [3, 1]);
    visualizationButtonRowGrid.Layout.Row = 2;
    visualizationButtonRowGrid.RowHeight = {'0.1x', '0.8x', '0.1x'};
    visualizationButtonRowGrid.ColumnWidth = {'1x'};
    visualizationButtonRowGrid.Padding = [0 0 0 0];
    visualizationButtonRowGrid.RowSpacing = 0;
    visualizationButtonContentGrid = uigridlayout(visualizationButtonRowGrid, [1, 6]);
    visualizationButtonContentGrid.Layout.Row = 2;
    visualizationButtonContentGrid.RowHeight = {'1x'};
    visualizationButtonContentGrid.ColumnWidth = {64, '1x', '1x', '1x', '1x', 'fit'};
    visualizationButtonContentGrid.Padding = [0 0 0 0];
    visualizationButtonContentGrid.ColumnSpacing = 5;

    visualizationStrideLabel = uilabel(visualizationSliderContentGrid, 'Text', 'Normalized stride');
    visualizationStrideLabel.Layout.Column = 1;
    visualizationSlider = uislider(visualizationSliderContentGrid, 'Limits', [0 1], ...
        'MajorTicks', [0 .5 1], 'ValueChangingFcn', @(~, e) VisualizationSliderChanged(e.Value), ...
        'ValueChangedFcn', @(s, ~) VisualizationSliderChanged(s.Value));
    visualizationSlider.Layout.Column = [2 5];
    visualizationTimeInputGrid = uigridlayout(visualizationSliderContentGrid, [3, 1]);
    visualizationTimeInputGrid.Layout.Column = 6;
    visualizationTimeInputGrid.RowHeight = {'0.15x', '0.7x', '0.15x'};
    visualizationTimeInputGrid.ColumnWidth = {'1x'};
    visualizationTimeInputGrid.Padding = [0 0 0 0];
    visualizationTimeInputGrid.RowSpacing = 0;
    visualizationTimeInput = uieditfield(visualizationTimeInputGrid, 'numeric', 'Limits', [0 1], ...
        'ValueDisplayFormat', '%.2f', 'ValueChangedFcn', @(s, ~) VisualizationTimeChanged(s.Value));
    visualizationTimeInput.Layout.Row = 2;
    visualizationRunButton = uibutton(visualizationButtonContentGrid, 'Text', 'Run', ...
        'ButtonPushedFcn', @(~, ~) RunVisualization());
    visualizationRunButton.Layout.Column = [1 2];
    visualizationStopButton = uibutton(visualizationButtonContentGrid, 'Text', 'Stop', ...
        'ButtonPushedFcn', @(~, ~) StopVisualization());
    visualizationStopButton.Layout.Column = [3 4];
    visualizationSettingsButton = uibutton(visualizationButtonContentGrid, 'Text', char(9881), ...
        'Tooltip', 'Frame update and recording settings', ...
        'ButtonPushedFcn', @(~, ~) OpenVisualizationSettings());
    visualizationSettingsButton.Layout.Column = [5 6];
    visualizationStatusLabel = uilabel(visualizationControls, ...
        'Text', 'Select a branch solution to enable visualization.', 'Visible', 'off');

    visualizationTabs = uitabgroup(visualizationGrid);
    visualizationTabs.Layout.Row = 2;
    visualizationTabs.SelectionChangedFcn = @(~, ~) UpdateSolutionVisualizationLayout();
    animationTab = uitab(visualizationTabs, 'Title', 'Animation');
    trajectoriesTab = uitab(visualizationTabs, 'Title', 'Trajectories');

    animationScrollPanel = uipanel(animationTab, 'BorderType', 'none', 'Scrollable', 'on');
    animationScrollPanel.Position = [1 1 100 100];
    animationContentPanel = uipanel(animationScrollPanel, 'BorderType', 'none', 'Position', [1 1 500 720]);
    animationAxesPanels = gobjects(2,1); animationAxesGrids = gobjects(2,1); animationAxes = gobjects(2,1);
    animationPanelTitles = {'Quadruped Animation', 'Periodic Orbit'};
    for visualizationAxisIndex = 1:2
        animationAxesPanels(visualizationAxisIndex) = uipanel(animationContentPanel, ...
            'Title', animationPanelTitles{visualizationAxisIndex});
        animationAxesGrids(visualizationAxisIndex) = uigridlayout(animationAxesPanels(visualizationAxisIndex), [1 1]);
        animationAxesGrids(visualizationAxisIndex).RowHeight = {'1x'};
        animationAxesGrids(visualizationAxisIndex).ColumnWidth = {'1x'};
        animationAxesGrids(visualizationAxisIndex).Padding = [4 4 4 4];
        animationAxes(visualizationAxisIndex) = uiaxes(animationAxesGrids(visualizationAxisIndex));
        DisableVisualizationAxesToolbar(animationAxes(visualizationAxisIndex));
    end

    trajectoryScrollPanel = uipanel(trajectoriesTab, 'BorderType', 'none', 'Scrollable', 'on');
    trajectoryScrollPanel.Position = [1 1 100 100];
    trajectoryContentPanel = uipanel(trajectoryScrollPanel, 'BorderType', 'none', 'Position', [1 1 500 930]);
    torsoTrajectoryPanel = uipanel(trajectoryContentPanel, 'Title', 'Torso Trajectory');
    legTrajectoriesPanel = uipanel(trajectoryContentPanel, 'Title', 'Leg Trajectories');
    grfTrajectoryPanel = uipanel(trajectoryContentPanel, 'Title', 'Ground-Reaction Force');
    trajectoryAxesPanels = gobjects(4,1); trajectoryAxesGrids = gobjects(4,1); trajectoryAxes = gobjects(4,1);
    trajectoryAxesPanels(1) = torsoTrajectoryPanel;
    trajectoryAxesPanels(2) = uipanel(legTrajectoriesPanel, 'Title', 'Back Legs');
    trajectoryAxesPanels(3) = uipanel(legTrajectoriesPanel, 'Title', 'Front Legs');
    trajectoryAxesPanels(4) = grfTrajectoryPanel;
    for visualizationAxisIndex = 1:4
        trajectoryAxesGrids(visualizationAxisIndex) = uigridlayout(trajectoryAxesPanels(visualizationAxisIndex), [1 1]);
        trajectoryAxesGrids(visualizationAxisIndex).RowHeight = {'1x'};
        trajectoryAxesGrids(visualizationAxisIndex).ColumnWidth = {'1x'};
        trajectoryAxesGrids(visualizationAxisIndex).Padding = [4 4 4 4];
        trajectoryAxes(visualizationAxisIndex) = uiaxes(trajectoryAxesGrids(visualizationAxisIndex));
        DisableVisualizationAxesToolbar(trajectoryAxes(visualizationAxisIndex));
    end
    SetVisualizationControlsEnabled(false);

    continuationRootGrid = uigridlayout(continuationRootTab, [1, 1]);
    continuationRootGrid.RowHeight = {'1x'};
    continuationRootGrid.ColumnWidth = {'1x'};
    continuationRootGrid.Padding = [0 0 0 0];

    continuationSubTabs = uitabgroup(continuationRootGrid);
    continuationSubTabs.Layout.Row = 1;
    continuationSubTabs.Layout.Column = 1;
    continuationTab = uitab(continuationSubTabs, 'Title', '1D');
    parameterTab = uitab(continuationSubTabs, 'Title', 'Para');
    scanTab = uitab(continuationSubTabs, 'Title', '2D');
    sidebarTabs.SelectionChangedFcn = @(src, event) RefreshContinuationActionLayout();
    continuationSubTabs.SelectionChangedFcn = @(src, event) RefreshContinuationActionLayout();

    infoGrid = uigridlayout(infoTab, [5, 1]);
    infoGrid.RowHeight = {'1x', 150, 176, 'fit', 'fit'};
    infoGrid.ColumnWidth = {'1x'};
    infoGrid.Padding = [6 6 6 6];
    infoGrid.RowSpacing = 10;

    currentDatasetsPanel = uipanel(infoGrid, 'Title', 'Plotted Datasets');
    currentDatasetsPanel.Layout.Row = 1;
    currentDatasetsPanel.Layout.Column = 1;
    currentDatasetGrid = uigridlayout(currentDatasetsPanel, [2, 1]);
    currentDatasetGrid.RowHeight = {'1x', 'fit'};
    currentDatasetGrid.ColumnWidth = {'1x'};
    currentDatasetGrid.Padding = [6 6 6 6];
    currentDatasetGrid.RowSpacing = 6;
    datasetListBox = uilistbox(currentDatasetGrid, ...
        'Items', {'<None>'}, ...
        'Value', '<None>', ...
        'ValueChangedFcn', @(src, event) HighlightDataset(src, event));
    datasetListBox.Layout.Row = 1;
    datasetListBox.Layout.Column = 1;
    if isprop(datasetListBox, 'ClickedFcn')
        datasetListBox.ClickedFcn = @(src, event) DatasetListBoxClicked(src, event);
    end

    deleteButton = uibutton(currentDatasetGrid, 'Text', 'Delete', ...
        'ButtonPushedFcn', @(src, event) DeleteSelectedDataset());
    deleteButton.Layout.Row = 2;
    deleteButton.Layout.Column = 1;

    cursorInfoPanel = uipanel(infoGrid, 'Title', 'Solution Info');
    cursorInfoPanel.Layout.Row = 2;
    cursorInfoPanel.Layout.Column = 1;
    cursorInfoGrid = uigridlayout(cursorInfoPanel, [2, 2]);
    cursorInfoGrid.RowHeight = {'1x', 'fit'};
    cursorInfoGrid.ColumnWidth = {'1x', '1x'};
    cursorInfoGrid.Padding = [6 6 6 6];
    cursorInfoGrid.RowSpacing = 8;
    cursorInfoGrid.ColumnSpacing = 8;

    cursorHoverScrollPanel = uipanel(cursorInfoGrid, ...
        'Title', 'Cursor Info', ...
        'Scrollable', 'on');
    cursorHoverScrollPanel.Layout.Row = 1;
    cursorHoverScrollPanel.Layout.Column = 1;
    cursorHoverContentPanel = uipanel(cursorHoverScrollPanel, ...
        'BorderType', 'none', ...
        'Position', [1, 1, 200, cursorHoverContentMinHeight]);
    cursorHoverGrid = uigridlayout(cursorHoverContentPanel, [1, 1]);
    cursorHoverGrid.RowHeight = {'1x'};
    cursorHoverGrid.ColumnWidth = {'1x'};
    cursorHoverGrid.Padding = [6 6 6 6];
    cursorHoverGrid.RowSpacing = 6;

    cursorInfoLabel = uilabel(cursorHoverGrid, 'Text', 'Move over a branch point', ...
        'WordWrap', 'on', 'VerticalAlignment', 'top');
    cursorInfoLabel.Layout.Row = 1;
    cursorInfoLabel.Layout.Column = 1;

    cursorSelectedScrollPanel = uipanel(cursorInfoGrid, ...
        'Title', 'Selected Info', ...
        'Scrollable', 'on');
    cursorSelectedScrollPanel.Layout.Row = 1;
    cursorSelectedScrollPanel.Layout.Column = 2;
    cursorSelectedContentPanel = uipanel(cursorSelectedScrollPanel, ...
        'BorderType', 'none', ...
        'Position', [1, 1, 200, cursorSelectedContentMinHeight]);
    cursorSelectedGrid = uigridlayout(cursorSelectedContentPanel, [1, 1]);
    cursorSelectedGrid.RowHeight = {'1x'};
    cursorSelectedGrid.ColumnWidth = {'1x'};
    cursorSelectedGrid.Padding = [6 6 6 6];
    cursorSelectedGrid.RowSpacing = 8;

    selectedCursorInfoLabel = uilabel(cursorSelectedGrid, 'Text', 'Click a branch point to lock selected data info', ...
        'WordWrap', 'on', 'VerticalAlignment', 'top');
    selectedCursorInfoLabel.Layout.Row = 1;
    selectedCursorInfoLabel.Layout.Column = 1;

    clearSelectedCursorButton = uibutton(cursorInfoGrid, 'Text', 'Remove Selected', ...
        'ButtonPushedFcn', @(src, event) ClearCurrentSolutionInfo());
    clearSelectedCursorButton.Layout.Row = 2;
    clearSelectedCursorButton.Layout.Column = [1 2];

    plotSettingsPanel = uipanel(infoGrid, 'Title', 'Axis');
    plotSettingsPanel.Layout.Row = 3;
    plotSettingsPanel.Layout.Column = 1;
    plotSettingsGrid = uigridlayout(plotSettingsPanel, [1, 1]);
    plotSettingsGrid.RowHeight = {'1x'};
    plotSettingsGrid.ColumnWidth = {'1x'};
    plotSettingsGrid.Padding = [6 6 6 6];

    plotSettingTabs = uitabgroup(plotSettingsGrid);
    plotSettingTabs.Layout.Row = 1;
    plotSettingTabs.Layout.Column = 1;
    axisLimitTab = uitab(plotSettingTabs, 'Title', 'Limit');
    aspectRatioTab = uitab(plotSettingTabs, 'Title', 'Ratio');

    axisLimitGrid = uigridlayout(axisLimitTab, [4, 4]);
    axisLimitGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
    axisLimitGrid.ColumnWidth = {'fit', '1x', '1x', 'fit'};
    axisLimitGrid.Padding = [6 6 6 6];
    axisLimitGrid.RowSpacing = 6;
    axisLimitGrid.ColumnSpacing = 6;

    axisHeader1 = uilabel(axisLimitGrid, 'Text', '');
    axisHeader1.Layout.Row = 1;
    axisHeader1.Layout.Column = 1;
    axisHeader2 = uilabel(axisLimitGrid, 'Text', 'Min', 'HorizontalAlignment', 'center');
    axisHeader2.Layout.Row = 1;
    axisHeader2.Layout.Column = 2;
    axisHeader3 = uilabel(axisLimitGrid, 'Text', 'Max', 'HorizontalAlignment', 'center');
    axisHeader3.Layout.Row = 1;
    axisHeader3.Layout.Column = 3;
    axisHeader4 = uilabel(axisLimitGrid, 'Text', '');
    axisHeader4.Layout.Row = 1;
    axisHeader4.Layout.Column = 4;

    xLabel = uilabel(axisLimitGrid, 'Text', 'X');
    xLabel.Layout.Row = 2;
    xLabel.Layout.Column = 1;
    xMinInput = uieditfield(axisLimitGrid, 'numeric', 'Value', ax.XLim(1), 'ValueChangedFcn', @(src, event) ChangeAxisLimits());
    xMinInput.Layout.Row = 2;
    xMinInput.Layout.Column = 2;
    xMaxInput = uieditfield(axisLimitGrid, 'numeric', 'Value', ax.XLim(2), 'ValueChangedFcn', @(src, event) ChangeAxisLimits());
    xMaxInput.Layout.Row = 2;
    xMaxInput.Layout.Column = 3;

    roadmapButton = uibutton(axisLimitGrid, 'Text', 'Roadmap', ...
        'ButtonPushedFcn', @(src, event) SetRoadmapLimits());
    roadmapButton.Layout.Row = 2;
    roadmapButton.Layout.Column = 4;

    yLabel = uilabel(axisLimitGrid, 'Text', 'Y');
    yLabel.Layout.Row = 3;
    yLabel.Layout.Column = 1;
    yMinInput = uieditfield(axisLimitGrid, 'numeric', 'Value', ax.YLim(1), 'ValueChangedFcn', @(src, event) ChangeAxisLimits());
    yMinInput.Layout.Row = 3;
    yMinInput.Layout.Column = 2;
    yMaxInput = uieditfield(axisLimitGrid, 'numeric', 'Value', ax.YLim(2), 'ValueChangedFcn', @(src, event) ChangeAxisLimits());
    yMaxInput.Layout.Row = 3;
    yMaxInput.Layout.Column = 3;

    zLabel = uilabel(axisLimitGrid, 'Text', 'Z');
    zLabel.Layout.Row = 4;
    zLabel.Layout.Column = 1;
    zMinInput = uieditfield(axisLimitGrid, 'numeric', 'Value', ax.ZLim(1), 'ValueChangedFcn', @(src, event) ChangeAxisLimits());
    zMinInput.Layout.Row = 4;
    zMinInput.Layout.Column = 2;
    zMaxInput = uieditfield(axisLimitGrid, 'numeric', 'Value', ax.ZLim(2), 'ValueChangedFcn', @(src, event) ChangeAxisLimits());
    zMaxInput.Layout.Row = 4;
    zMaxInput.Layout.Column = 3;

    aspectRatioGrid = uigridlayout(aspectRatioTab, [4, 5]);
    aspectRatioGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
    aspectRatioGrid.ColumnWidth = {'fit', '1x', '1x', '1x', 'fit'};
    aspectRatioGrid.Padding = [6 6 6 6];
    aspectRatioGrid.RowSpacing = 6;
    aspectRatioGrid.ColumnSpacing = 8;

    aspectRatioInstructionLabel = uilabel(aspectRatioGrid, ...
        'Text', 'Control how wide, tall, and deep the State Plot appears.', ...
        'WordWrap', 'on');
    aspectRatioInstructionLabel.Layout.Row = 1;
    aspectRatioInstructionLabel.Layout.Column = [1 5];

    aspectModeLabel = uilabel(aspectRatioGrid, 'Text', 'Mode');
    aspectModeLabel.Layout.Row = 2;
    aspectModeLabel.Layout.Column = 1;

    aspectModeDropdown = uidropdown(aspectRatioGrid, ...
        'Items', {'Auto', 'Manual'}, ...
        'Value', 'Auto', ...
        'ValueChangedFcn', @(src, event) ChangeAspectRatioMode());
    aspectModeDropdown.Layout.Row = 2;
    aspectModeDropdown.Layout.Column = [2 5];

    aspectRatioLabel = uilabel(aspectRatioGrid, 'Text', 'Manual ratio');
    aspectRatioLabel.Layout.Row = 4;
    aspectRatioLabel.Layout.Column = 1;

    aspectXInput = uieditfield(aspectRatioGrid, 'numeric', ...
        'Value', manualAspectRatioValue(1), ...
        'ValueChangedFcn', @(src, event) MarkAspectRatioDraftDirty());
    aspectXInput.Layout.Row = 4;
    aspectXInput.Layout.Column = 2;

    aspectYInput = uieditfield(aspectRatioGrid, 'numeric', ...
        'Value', manualAspectRatioValue(2), ...
        'ValueChangedFcn', @(src, event) MarkAspectRatioDraftDirty());
    aspectYInput.Layout.Row = 4;
    aspectYInput.Layout.Column = 3;

    aspectZInput = uieditfield(aspectRatioGrid, 'numeric', ...
        'Value', manualAspectRatioValue(3), ...
        'ValueChangedFcn', @(src, event) MarkAspectRatioDraftDirty());
    aspectZInput.Layout.Row = 4;
    aspectZInput.Layout.Column = 4;

    aspectApplyButton = uibutton(aspectRatioGrid, 'Text', 'Apply', ...
        'ButtonPushedFcn', @(src, event) ApplyManualAspectRatio());
    aspectApplyButton.Layout.Row = 4;
    aspectApplyButton.Layout.Column = 5;

    aspectXLabel = uilabel(aspectRatioGrid, 'Text', 'X', 'HorizontalAlignment', 'center');
    aspectXLabel.Layout.Row = 3;
    aspectXLabel.Layout.Column = 2;

    aspectYLabel = uilabel(aspectRatioGrid, 'Text', 'Y', 'HorizontalAlignment', 'center');
    aspectYLabel.Layout.Row = 3;
    aspectYLabel.Layout.Column = 3;

    aspectZLabel = uilabel(aspectRatioGrid, 'Text', 'Z', 'HorizontalAlignment', 'center');
    aspectZLabel.Layout.Row = 3;
    aspectZLabel.Layout.Column = 4;

    viewPanel = uipanel(infoGrid, 'Title', 'View');
    viewPanel.Layout.Row = 4;
    viewPanel.Layout.Column = 1;
    viewGrid = uigridlayout(viewPanel, [1, 4]);
    viewGrid.RowHeight = {'fit'};
    viewGrid.ColumnWidth = {'fit', '1x', '1x', 'fit'};
    viewGrid.Padding = [6 6 6 6];
    viewGrid.ColumnSpacing = 6;

    viewLabel = uilabel(viewGrid, 'Text', 'Angles');
    viewLabel.Layout.Row = 1;
    viewLabel.Layout.Column = 1;

    viewXInput = uieditfield(viewGrid, 'numeric', 'Value', 0, 'ValueChangedFcn', @(src, event) ChangeView());
    viewXInput.Layout.Row = 1;
    viewXInput.Layout.Column = 2;

    viewYInput = uieditfield(viewGrid, 'numeric', 'Value', 90, 'ValueChangedFcn', @(src, event) ChangeView());
    viewYInput.Layout.Row = 1;
    viewYInput.Layout.Column = 3;

    viewDropdown = uidropdown(viewGrid, ...
        'Items', {'Top', 'Side', 'Custom'}, ...
        'Value', 'Top', ...
        'ValueChangedFcn', @(src, event) ChangeView());
    viewDropdown.Layout.Row = 1;
    viewDropdown.Layout.Column = 4;

    savePanel = uipanel(infoGrid, 'Title', 'Save Plot');
    savePanel.Layout.Row = 5;
    savePanel.Layout.Column = 1;
    saveGrid = uigridlayout(savePanel, [2, 2]);
    saveGrid.RowHeight = {'fit', 'fit'};
    saveGrid.ColumnWidth = {'fit', '1x'};
    saveGrid.Padding = [6 6 6 6];
    saveGrid.RowSpacing = 6;
    saveGrid.ColumnSpacing = 8;

    saveLabel = uilabel(saveGrid, 'Text', 'File Name:');
    saveLabel.Layout.Row = 1;
    saveLabel.Layout.Column = 1;

    filenameInput = uieditfield(saveGrid, 'text');
    filenameInput.Layout.Row = 1;
    filenameInput.Layout.Column = 2;

    formatDropdown = uidropdown(saveGrid, 'Items', {'.png', '.pdf'}, 'Value', '.png');
    formatDropdown.Layout.Row = 2;
    formatDropdown.Layout.Column = 1;

    saveButton = uibutton(saveGrid, 'Text', 'Save Plot', ...
        'ButtonPushedFcn', @(src, event) SaveCurrentPlot());
    saveButton.Layout.Row = 2;
    saveButton.Layout.Column = 2;

    seedGrid = uigridlayout(seedTab, [2, 2]);
    seedGrid.RowHeight = {'fit', '1x'};
    seedGrid.ColumnWidth = {'1.18x', '1.05x'};
    seedGrid.Padding = [10 10 10 10];
    seedGrid.RowSpacing = 10;
    seedGrid.ColumnSpacing = 10;

    seedSummaryPanel = uipanel(seedGrid, 'Title', 'Seed Info');
    seedSummaryPanel.Layout.Row = 1;
    seedSummaryPanel.Layout.Column = [1 2];
    seedSummaryGrid = uigridlayout(seedSummaryPanel, [1, 6]);
    seedSummaryGrid.RowHeight = {'fit'};
    seedSummaryGrid.ColumnWidth = {'fit', '2.2x', 'fit', '0.9x', 'fit', '0.8x'};
    seedSummaryGrid.Padding = [6 6 6 6];
    seedSummaryGrid.RowSpacing = 6;
    seedSummaryGrid.ColumnSpacing = 8;

    selectedBranchLabel = uilabel(seedSummaryGrid, 'Text', 'Selected Branch');
    selectedBranchLabel.Layout.Row = 1;
    selectedBranchLabel.Layout.Column = 1;

    seedSelectionSummaryLabel = uieditfield(seedSummaryGrid, 'text', ...
        'Value', '<none>', ...
        'Editable', 'off');
    seedSelectionSummaryLabel.Layout.Row = 1;
    seedSelectionSummaryLabel.Layout.Column = 2;

    seedSourceLabel = uilabel(seedSummaryGrid, 'Text', 'Source');
    seedSourceLabel.Layout.Row = 1;
    seedSourceLabel.Layout.Column = 3;

    seedSourceField = uidropdown(seedSummaryGrid, ...
        'Items', {'Cursor', 'Index input'}, ...
        'Value', seedSourceMode, ...
        'ValueChangedFcn', @(src, event) SeedModeChanged(src));
    seedSourceField.Layout.Row = 1;
    seedSourceField.Layout.Column = 4;

    seedIndexLabel = uilabel(seedSummaryGrid, 'Text', 'Index');
    seedIndexLabel.Layout.Row = 1;
    seedIndexLabel.Layout.Column = 5;

    seedIndexField = uieditfield(seedSummaryGrid, 'text', ...
        'Value', '<none>', ...
        'Editable', 'off', ...
        'ValueChangedFcn', @(src, event) SeedIndexChanged(src));
    seedIndexField.Layout.Row = 1;
    seedIndexField.Layout.Column = 6;

    seedEntriesPanel = uipanel(seedGrid, 'Title', 'Seed Entries');
    seedEntriesPanel.Layout.Row = 2;
    seedEntriesPanel.Layout.Column = 1;
    seedEntriesGrid = uigridlayout(seedEntriesPanel, [3, 1]);
    seedEntriesGrid.RowHeight = {'13x', '9x', '7x'};
    seedEntriesGrid.ColumnWidth = {'1x'};
    seedEntriesGrid.Padding = [6 6 6 6];
    seedEntriesGrid.RowSpacing = 8;

    statePanel = uipanel(seedEntriesGrid, 'Title', 'States (13)');
    statePanel.Layout.Row = 1;
    statePanel.Layout.Column = 1;
    stateSeedTable = CreateSeedEditorTable(statePanel, stateEntryNames);

    timingPanel = uipanel(seedEntriesGrid, 'Title', 'Timing (9)');
    timingPanel.Layout.Row = 2;
    timingPanel.Layout.Column = 1;
    timingSeedTable = CreateSeedEditorTable(timingPanel, timingEntryNames);

    parameterPanel = uipanel(seedEntriesGrid, 'Title', 'Parameters (7)');
    parameterPanel.Layout.Row = 3;
    parameterPanel.Layout.Column = 1;
    parameterSeedTable = CreateSeedEditorTable(parameterPanel, parameterEntryNames);

    seedToolPanel = uipanel(seedGrid, 'BorderType', 'none');
    seedToolPanel.Layout.Row = 2;
    seedToolPanel.Layout.Column = 2;

    seedToolGrid = uigridlayout(seedToolPanel, [4, 1]);
    seedToolGrid.RowHeight = {'1.323x', '0.82x', '0.697x', '0.9x'};
    seedToolGrid.ColumnWidth = {'1x'};
    seedToolGrid.Padding = [0 0 0 0];
    seedToolGrid.RowSpacing = 6;

    seedNumericalScrollPanel = uipanel(seedToolGrid, ...
        'Title', 'Numerical Settings', ...
        'Scrollable', 'on');
    seedNumericalScrollPanel.Layout.Row = 1;
    seedNumericalScrollPanel.Layout.Column = 1;

    seedNumericalContentPanel = uipanel(seedNumericalScrollPanel, 'BorderType', 'none');

    seedNumericalGrid = uigridlayout(seedNumericalContentPanel, [8, 3]);
    seedNumericalGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
    seedNumericalGrid.ColumnWidth = {'fit', '0.8x', '0.2x'};
    seedNumericalGrid.Padding = [6 6 6 6];
    seedNumericalGrid.RowSpacing = 6;
    seedNumericalGrid.ColumnSpacing = 8;

    solverAlgorithmLabel = uilabel(seedNumericalGrid, 'Text', 'Algorithm');
    solverAlgorithmLabel.Layout.Row = 1;
    solverAlgorithmLabel.Layout.Column = 1;

    solverAlgorithmDropdown = uidropdown(seedNumericalGrid, ...
        'Items', {'levenberg-marquardt', 'trust-region-dogleg'}, ...
        'Value', 'levenberg-marquardt', ...
        'ValueChangedFcn', @(src, event) UpdateSeedSolverOptions());
    solverAlgorithmDropdown.Layout.Row = 1;
    solverAlgorithmDropdown.Layout.Column = 2;

    solverDisplayLabel = uilabel(seedNumericalGrid, 'Text', 'Display');
    solverDisplayLabel.Layout.Row = 2;
    solverDisplayLabel.Layout.Column = 1;

    solverDisplayDropdown = uidropdown(seedNumericalGrid, ...
        'Items', {'iter', 'off', 'final'}, ...
        'Value', 'off', ...
        'ValueChangedFcn', @(src, event) UpdateSeedSolverOptions());
    solverDisplayDropdown.Layout.Row = 2;
    solverDisplayDropdown.Layout.Column = 2;

    solverMaxFunEvalsLabel = uilabel(seedNumericalGrid, 'Text', 'MaxFunEvals');
    solverMaxFunEvalsLabel.Layout.Row = 3;
    solverMaxFunEvalsLabel.Layout.Column = 1;

    solverMaxFunEvalsInput = uieditfield(seedNumericalGrid, 'numeric', ...
        'RoundFractionalValues', 'on', 'Value', 15000, 'LowerLimit', 1, ...
        'ValueChangedFcn', @(src, event) UpdateSeedSolverOptions());
    solverMaxFunEvalsInput.Layout.Row = 3;
    solverMaxFunEvalsInput.Layout.Column = 2;

    solverMaxIterLabel = uilabel(seedNumericalGrid, 'Text', 'MaxIter');
    solverMaxIterLabel.Layout.Row = 4;
    solverMaxIterLabel.Layout.Column = 1;

    solverMaxIterInput = uieditfield(seedNumericalGrid, 'numeric', ...
        'RoundFractionalValues', 'on', 'Value', 3000, 'LowerLimit', 1, ...
        'ValueChangedFcn', @(src, event) UpdateSeedSolverOptions());
    solverMaxIterInput.Layout.Row = 4;
    solverMaxIterInput.Layout.Column = 2;

    solverTolFunLabel = uilabel(seedNumericalGrid, 'Text', 'TolFun');
    solverTolFunLabel.Layout.Row = 5;
    solverTolFunLabel.Layout.Column = 1;

    solverTolFunInput = uieditfield(seedNumericalGrid, 'numeric', ...
        'Value', 1e-9, 'LowerLimit', 0, ...
        'ValueChangedFcn', @(src, event) UpdateSeedSolverOptions());
    solverTolFunInput.Layout.Row = 5;
    solverTolFunInput.Layout.Column = 2;

    solverTolXLabel = uilabel(seedNumericalGrid, 'Text', 'TolX');
    solverTolXLabel.Layout.Row = 6;
    solverTolXLabel.Layout.Column = 1;

    solverTolXInput = uieditfield(seedNumericalGrid, 'numeric', ...
        'Value', 1e-12, 'LowerLimit', 0, ...
        'ValueChangedFcn', @(src, event) UpdateSeedSolverOptions());
    solverTolXInput.Layout.Row = 6;
    solverTolXInput.Layout.Column = 2;

    solverScaleProblemLabel = uilabel(seedNumericalGrid, 'Text', 'ScaleProblem');
    solverScaleProblemLabel.Layout.Row = 7;
    solverScaleProblemLabel.Layout.Column = 1;

    solverScaleProblemDropdown = uidropdown(seedNumericalGrid, ...
        'Items', {'jacobian', 'none'}, ...
        'Value', 'jacobian', ...
        'ValueChangedFcn', @(src, event) UpdateSeedSolverOptions());
    solverScaleProblemDropdown.Layout.Row = 7;
    solverScaleProblemDropdown.Layout.Column = 2;

    solverUseParallelLabel = uilabel(seedNumericalGrid, 'Text', 'UseParallel');
    solverUseParallelLabel.Layout.Row = 8;
    solverUseParallelLabel.Layout.Column = 1;

    solverUseParallelDropdown = uidropdown(seedNumericalGrid, ...
        'Items', {'false', 'true'}, ...
        'Value', 'false', ...
        'ValueChangedFcn', @(src, event) UpdateSeedSolverOptions());
    solverUseParallelDropdown.Layout.Row = 8;
    solverUseParallelDropdown.Layout.Column = 2;

    seedNoiseScrollPanel = uipanel(seedToolGrid, ...
        'Title', 'Noise', ...
        'Scrollable', 'on');
    seedNoiseScrollPanel.Layout.Row = 2;
    seedNoiseScrollPanel.Layout.Column = 1;

    seedNoiseContentPanel = uipanel(seedNoiseScrollPanel, 'BorderType', 'none');

    seedNoiseGrid = uigridlayout(seedNoiseContentPanel, [4, 3]);
    seedNoiseGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
    seedNoiseGrid.ColumnWidth = {'fit', '0.8x', '0.2x'};
    seedNoiseGrid.Padding = [6 5 6 5];
    seedNoiseGrid.RowSpacing = 6;
    seedNoiseGrid.ColumnSpacing = 8;

    randomizationModeLabel = uilabel(seedNoiseGrid, 'Text', 'Noise Mode');
    randomizationModeLabel.Layout.Row = 1;
    randomizationModeLabel.Layout.Column = 1;

    randomizationModeDropdown = uidropdown(seedNoiseGrid, ...
        'Items', {'Percent', 'Absolute'}, ...
        'Value', 'Percent', ...
        'ValueChangedFcn', @(src, event) UpdateNoiseApplicationDisplay());
    randomizationModeDropdown.Layout.Row = 1;
    randomizationModeDropdown.Layout.Column = 2;

    stateNoiseLabel = uilabel(seedNoiseGrid, 'Text', 'State Noise');
    stateNoiseLabel.Layout.Row = 2;
    stateNoiseLabel.Layout.Column = 1;

    stateNoiseInput = uieditfield(seedNoiseGrid, 'numeric', 'Value', 0, ...
        'ValueChangedFcn', @(src, event) UpdateNoiseApplicationDisplay());
    stateNoiseInput.Layout.Row = 2;
    stateNoiseInput.Layout.Column = 2;

    parameterNoiseLabel = uilabel(seedNoiseGrid, 'Text', 'Parameter Noise');
    parameterNoiseLabel.Layout.Row = 3;
    parameterNoiseLabel.Layout.Column = 1;

    parameterNoiseInput = uieditfield(seedNoiseGrid, 'numeric', 'Value', 0, ...
        'ValueChangedFcn', @(src, event) UpdateNoiseApplicationDisplay());
    parameterNoiseInput.Layout.Row = 3;
    parameterNoiseInput.Layout.Column = 2;

    applyNoiseButton = uibutton(seedNoiseGrid, 'Text', 'Apply Noise', ...
        'ButtonPushedFcn', @(src, event) ApplySeedNoise());
    applyNoiseButton.Layout.Row = 4;
    applyNoiseButton.Layout.Column = [1 2];

    seedPredictionScrollPanel = uipanel(seedToolGrid, ...
        'Title', 'Prediction', ...
        'Scrollable', 'on');
    seedPredictionScrollPanel.Layout.Row = 3;
    seedPredictionScrollPanel.Layout.Column = 1;

    seedPredictionContentPanel = uipanel(seedPredictionScrollPanel, 'BorderType', 'none');

    seedPredictionGrid = uigridlayout(seedPredictionContentPanel, [4, 2]);
    seedPredictionGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
    seedPredictionGrid.ColumnWidth = {'1x', '1x'};
    seedPredictionGrid.Padding = [6 5 6 5];
    seedPredictionGrid.RowSpacing = 6;
    seedPredictionGrid.ColumnSpacing = 8;

    predictionDistanceLabel = uilabel(seedPredictionGrid, ...
        'Text', 'Prediction distance:', ...
        'WordWrap', 'on', ...
        'VerticalAlignment', 'top');
    predictionDistanceLabel.Layout.Row = 1;
    predictionDistanceLabel.Layout.Column = [1 2];

    predictionStateDistanceLabel = uilabel(seedPredictionGrid, ...
        'Text', 'State: n/a', ...
        'WordWrap', 'on', ...
        'VerticalAlignment', 'top');
    predictionStateDistanceLabel.Layout.Row = 2;
    predictionStateDistanceLabel.Layout.Column = [1 2];

    predictionParameterDistanceLabel = uilabel(seedPredictionGrid, ...
        'Text', 'Para: n/a', ...
        'WordWrap', 'on', ...
        'VerticalAlignment', 'top');
    predictionParameterDistanceLabel.Layout.Row = 3;
    predictionParameterDistanceLabel.Layout.Column = [1 2];

    plotPredictedButton = uibutton(seedPredictionGrid, 'Text', 'Plot Predicted', ...
        'ButtonPushedFcn', @(src, event) PlotPredictedSeedCandidate());
    plotPredictedButton.Layout.Row = 4;
    plotPredictedButton.Layout.Column = 1;

    removePredictedButton = uibutton(seedPredictionGrid, 'Text', 'Remove Predicted', ...
        'ButtonPushedFcn', @(src, event) RemovePredictedSeedCandidate());
    removePredictedButton.Layout.Row = 4;
    removePredictedButton.Layout.Column = 2;

    seedSolveScrollPanel = uipanel(seedToolGrid, ...
        'Title', 'Solve', ...
        'Scrollable', 'on');
    seedSolveScrollPanel.Layout.Row = 4;
    seedSolveScrollPanel.Layout.Column = 1;

    seedSolveContentPanel = uipanel(seedSolveScrollPanel, 'BorderType', 'none');

    seedSolveGrid = uigridlayout(seedSolveContentPanel, [4, 1]);
    seedSolveGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
    seedSolveGrid.ColumnWidth = {'1x'};
    seedSolveGrid.Padding = [6 5 6 5];
    seedSolveGrid.RowSpacing = 4;
    seedSolveGrid.ColumnSpacing = 8;

    solvePredictedButton = uibutton(seedSolveGrid, 'Text', 'Solve For Solution', ...
        'ButtonPushedFcn', @(src, event) SolvePredictedSeedCandidate());
    solvePredictedButton.Layout.Row = 1;
    solvePredictedButton.Layout.Column = 1;

    solvedSolutionInfoLabel = uilabel(seedSolveGrid, ...
        'Text', sprintf('Solved Solution Info:\nResidual: n/a\nGait type: n/a'), ...
        'WordWrap', 'on', ...
        'VerticalAlignment', 'top');
    solvedSolutionInfoLabel.Layout.Row = 2;
    solvedSolutionInfoLabel.Layout.Column = 1;

    solveButtonGrid = uigridlayout(seedSolveGrid, [1, 2]);
    solveButtonGrid.RowHeight = {'fit'};
    solveButtonGrid.ColumnWidth = {'1x', '1x'};
    solveButtonGrid.Padding = [0 0 0 0];
    solveButtonGrid.RowSpacing = 0;
    solveButtonGrid.ColumnSpacing = 8;
    solveButtonGrid.Layout.Row = 3;
    solveButtonGrid.Layout.Column = 1;

    plotSolvedButton = uibutton(solveButtonGrid, 'Text', 'Plot Solved', ...
        'ButtonPushedFcn', @(src, event) PlotSolvedSeedCandidate());
    plotSolvedButton.Layout.Row = 1;
    plotSolvedButton.Layout.Column = 1;

    removeSolvedButton = uibutton(solveButtonGrid, 'Text', 'Remove Solved', ...
        'ButtonPushedFcn', @(src, event) RemoveSolvedSeedCandidate());
    removeSolvedButton.Layout.Row = 1;
    removeSolvedButton.Layout.Column = 2;

    saveSolvedButton = uibutton(seedSolveGrid, 'Text', 'Save Solved Solution', ...
        'ButtonPushedFcn', @(src, event) SaveSolvedSeedSolution());
    saveSolvedButton.Layout.Row = 4;
    saveSolvedButton.Layout.Column = 1;

    continuationGrid = uigridlayout(continuationTab, [4, 1]);
    continuationGrid.RowHeight = {230, 'fit', 'fit', '1x'};
    continuationGrid.ColumnWidth = {'1x'};
    continuationGrid.Padding = [10 10 10 10];
    continuationGrid.RowSpacing = 10;

    BuildPreviewSection(continuationGrid, 1);

    continuationSeedPanel = uipanel(continuationGrid, 'Title', 'Seed Selection');
    continuationSeedPanel.Layout.Row = 2;
    continuationSeedPanel.Layout.Column = 1;
    [continuationSeedSourceDropdown, continuationSeedValueLabel, ...
        continuationSeedValueInput, continuationSeedContextLabel] = ...
        BuildContinuationSeedSelectionSection(continuationSeedPanel);

    continuationSeedSolvePanel = uipanel(continuationGrid, 'Title', 'Seed Solving');
    continuationSeedSolvePanel.Layout.Row = 3;
    continuationSeedSolvePanel.Layout.Column = 1;
    [continuationRadiusInput, solveSecondSeedButton, removeSecondSeedButton, ...
        plotSeedPairButton, removeSeedPairPlotButton] = ...
        BuildContinuationSeedSolvingSection(continuationSeedSolvePanel);

    continuationActionPanel = uipanel(continuationGrid, ...
        'Title', '1D Continuation', ...
        'Scrollable', 'on');
    continuationActionPanel.Layout.Row = 4;
    continuationActionPanel.Layout.Column = 1;
    continuationActionContentPanel = uipanel(continuationActionPanel, ...
        'BorderType', 'none', ...
        'Position', [1, 1, 200, continuationActionContentMinHeight]);
    continuationActionGrid = uigridlayout(continuationActionContentPanel, [4, 1]);
    continuationActionGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
    continuationActionGrid.ColumnWidth = {'1x'};
    continuationActionGrid.Padding = [10 10 10 10];
    continuationActionGrid.RowSpacing = 10;

    continuationInstructionLabel = uilabel(continuationActionGrid, ...
        'Text', 'Choose the first seed, solve a validated second seed at the requested state-only radius, then run 1D continuation.', ...
        'WordWrap', 'on');
    continuationInstructionLabel.Layout.Row = 1;
    continuationInstructionLabel.Layout.Column = 1;

    continuationSummaryLabel = uilabel(continuationActionGrid, ...
        'Text', 'Run a GUI-embedded 1D continuation and keep the preview synchronized across the continuation tabs.', ...
        'WordWrap', 'on');
    continuationSummaryLabel.Layout.Row = 2;
    continuationSummaryLabel.Layout.Column = 1;

    continuationFileGrid = uigridlayout(continuationActionGrid, [1, 3]);
    continuationFileGrid.Layout.Row = 3;
    continuationFileGrid.Layout.Column = 1;
    continuationFileGrid.RowHeight = {'fit'};
    continuationFileGrid.ColumnWidth = {'fit', '1x', 'fit'};
    continuationFileGrid.Padding = [0 0 0 0];
    continuationFileGrid.ColumnSpacing = 8;

    continuationFileLabel = uilabel(continuationFileGrid, 'Text', 'Solution file');
    continuationFileLabel.Layout.Row = 1;
    continuationFileLabel.Layout.Column = 1;

    continuationResultNameInput = uieditfield(continuationFileGrid, 'text', ...
        'Value', 'Continuation1D_Solution', ...
        'Tooltip', 'Final branch filename without the .mat extension. Temporary progress is stored in solution_temp.mat.');
    continuationResultNameInput.Layout.Row = 1;
    continuationResultNameInput.Layout.Column = 2;

    continuationFileExtensionLabel = uilabel(continuationFileGrid, 'Text', '.mat');
    continuationFileExtensionLabel.Layout.Row = 1;
    continuationFileExtensionLabel.Layout.Column = 3;

    continuationButtonGrid = uigridlayout(continuationActionGrid, [1, 3]);
    continuationButtonGrid.Layout.Row = 4;
    continuationButtonGrid.Layout.Column = 1;
    continuationButtonGrid.RowHeight = {'fit'};
    continuationButtonGrid.ColumnWidth = {'1x', '1x', '1x'};
    continuationButtonGrid.Padding = [0 0 0 0];
    continuationButtonGrid.ColumnSpacing = 8;

    runContinuationButton = uibutton(continuationButtonGrid, 'Text', 'Run', ...
        'ButtonPushedFcn', @(src, event) RunNumericalContinuation1D());
    runContinuationButton.Layout.Row = 1;
    runContinuationButton.Layout.Column = 1;

    pauseContinuationButton = uibutton(continuationButtonGrid, 'Text', 'Pause', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(src, event) ToggleContinuationPause('1D'));
    pauseContinuationButton.Layout.Row = 1;
    pauseContinuationButton.Layout.Column = 2;

    stopContinuationButton = uibutton(continuationButtonGrid, 'Text', 'Stop', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(src, event) RequestContinuationStop('1D'));
    stopContinuationButton.Layout.Row = 1;
    stopContinuationButton.Layout.Column = 3;

    parameterTabGrid = uigridlayout(parameterTab, [4, 1]);
    parameterTabGrid.RowHeight = {230, 'fit', 'fit', '1x'};
    parameterTabGrid.ColumnWidth = {'1x'};
    parameterTabGrid.Padding = [10 10 10 10];
    parameterTabGrid.RowSpacing = 10;

    BuildPreviewSection(parameterTabGrid, 1);

    parameterSeedPanel = uipanel(parameterTabGrid, 'Title', 'Seed Selection');
    parameterSeedPanel.Layout.Row = 2;
    parameterSeedPanel.Layout.Column = 1;
    [parameterContinuationSeedSourceDropdown, parameterContinuationSeedValueLabel, ...
        parameterContinuationSeedValueInput, parameterContinuationSeedContextLabel] = ...
        BuildContinuationSeedSelectionSection(parameterSeedPanel);

    parameterSeedSolvePanel = uipanel(parameterTabGrid, 'Title', 'Seed Solving');
    parameterSeedSolvePanel.Layout.Row = 3;
    parameterSeedSolvePanel.Layout.Column = 1;
    [parameterContinuationRadiusInput, parameterSolveSecondSeedButton, ...
        parameterRemoveSecondSeedButton, parameterPlotSeedPairButton, ...
        parameterRemoveSeedPairPlotButton] = ...
        BuildContinuationSeedSolvingSection(parameterSeedSolvePanel);

    parameterActionPanel = uipanel(parameterTabGrid, ...
        'Title', 'Parameter Varying', ...
        'Scrollable', 'on');
    parameterActionPanel.Layout.Row = 4;
    parameterActionPanel.Layout.Column = 1;

    parameterActionContentPanel = uipanel(parameterActionPanel, ...
        'BorderType', 'none', ...
        'Position', [1, 1, 200, parameterActionContentMinHeight]);
    parameterOpGrid = uigridlayout(parameterActionContentPanel, [6, 2]);
    parameterOpGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
    parameterOpGrid.ColumnWidth = {'fit', '1x'};
    parameterOpGrid.Padding = [10 10 10 10];
    parameterOpGrid.RowSpacing = 8;
    parameterOpGrid.ColumnSpacing = 8;

    parameterInstructionLabel = uilabel(parameterOpGrid, ...
        'Text', 'Select one parameter on the active branch, move it to a new target value, and continue from the updated seed pair.', ...
        'WordWrap', 'on');
    parameterInstructionLabel.Layout.Row = 1;
    parameterInstructionLabel.Layout.Column = [1 2];

    parameterVaryingLabel = uilabel(parameterOpGrid, 'Text', 'Parameter', 'Interpreter', 'latex');
    parameterVaryingLabel.Layout.Row = 2;
    parameterVaryingLabel.Layout.Column = 1;

    parameterVaryingDropdown = uidropdown(parameterOpGrid, ...
        'Items', parameteroptions, ...
        'Value', parameteroptions{1}, ...
        'ValueChangedFcn', @(src, event) ParameterVaryingConfigurationChanged());
    parameterVaryingDropdown.Layout.Row = 2;
    parameterVaryingDropdown.Layout.Column = 2;

    currentParameterValueLabel = uilabel(parameterOpGrid, 'Text', 'Current value: n/a', 'WordWrap', 'on');
    currentParameterValueLabel.Layout.Row = 3;
    currentParameterValueLabel.Layout.Column = [1 2];

    targetParameterLabel = uilabel(parameterOpGrid, 'Text', 'Target Value');
    targetParameterLabel.Layout.Row = 4;
    targetParameterLabel.Layout.Column = 1;

    targetParameterInput = uieditfield(parameterOpGrid, 'numeric', ...
        'Value', 0, ...
        'ValueChangedFcn', @(src, event) ParameterVaryingConfigurationChanged());
    targetParameterInput.Layout.Row = 4;
    targetParameterInput.Layout.Column = 2;

    parameterFileGrid = uigridlayout(parameterOpGrid, [1, 3]);
    parameterFileGrid.Layout.Row = 5;
    parameterFileGrid.Layout.Column = [1 2];
    parameterFileGrid.RowHeight = {'fit'};
    parameterFileGrid.ColumnWidth = {'fit', '1x', 'fit'};
    parameterFileGrid.Padding = [0 0 0 0];
    parameterFileGrid.ColumnSpacing = 8;

    parameterFileLabel = uilabel(parameterFileGrid, 'Text', 'Solution file');
    parameterFileLabel.Layout.Row = 1;
    parameterFileLabel.Layout.Column = 1;

    parameterResultNameInput = uieditfield(parameterFileGrid, 'text', ...
        'Value', 'ParameterVarying_kl_0', ...
        'Tooltip', 'Final parameter-varying branch filename without the .mat extension.', ...
        'ValueChangedFcn', @(src, event) ParameterResultNameEdited());
    parameterResultNameInput.Layout.Row = 1;
    parameterResultNameInput.Layout.Column = 2;

    parameterFileExtensionLabel = uilabel(parameterFileGrid, 'Text', '.mat');
    parameterFileExtensionLabel.Layout.Row = 1;
    parameterFileExtensionLabel.Layout.Column = 3;

    parameterButtonGrid = uigridlayout(parameterOpGrid, [1, 3]);
    parameterButtonGrid.Layout.Row = 6;
    parameterButtonGrid.Layout.Column = [1 2];
    parameterButtonGrid.RowHeight = {'fit'};
    parameterButtonGrid.ColumnWidth = {'1x', '1x', '1x'};
    parameterButtonGrid.Padding = [0 0 0 0];
    parameterButtonGrid.ColumnSpacing = 8;

    runParameterButton = uibutton(parameterButtonGrid, 'Text', 'Run', ...
        'ButtonPushedFcn', @(src, event) RunParameterVaryingContinuation());
    runParameterButton.Layout.Row = 1;
    runParameterButton.Layout.Column = 1;

    pauseParameterButton = uibutton(parameterButtonGrid, 'Text', 'Pause', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(src, event) ToggleContinuationPause('Para'));
    pauseParameterButton.Layout.Row = 1;
    pauseParameterButton.Layout.Column = 2;

    stopParameterButton = uibutton(parameterButtonGrid, 'Text', 'Stop', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(src, event) RequestContinuationStop('Para'));
    stopParameterButton.Layout.Row = 1;
    stopParameterButton.Layout.Column = 3;

    scanTabGrid = uigridlayout(scanTab, [4, 1]);
    scanTabGrid.RowHeight = {230, 'fit', 'fit', '1x'};
    scanTabGrid.ColumnWidth = {'1x'};
    scanTabGrid.Padding = [10 10 10 10];
    scanTabGrid.RowSpacing = 10;

    BuildPreviewSection(scanTabGrid, 1);

    scanSeedPanel = uipanel(scanTabGrid, 'Title', 'Seed Selection');
    scanSeedPanel.Layout.Row = 2;
    scanSeedPanel.Layout.Column = 1;
    [scanContinuationSeedSourceDropdown, scanContinuationSeedValueLabel, ...
        scanContinuationSeedValueInput, scanContinuationSeedContextLabel] = ...
        BuildContinuationSeedSelectionSection(scanSeedPanel);

    scanSeedSolvePanel = uipanel(scanTabGrid, 'Title', 'Seed Solving');
    scanSeedSolvePanel.Layout.Row = 3;
    scanSeedSolvePanel.Layout.Column = 1;
    [scanContinuationRadiusInput, scanSolveSecondSeedButton, ...
        scanRemoveSecondSeedButton, scanPlotSeedPairButton, ...
        scanRemoveSeedPairPlotButton] = ...
        BuildContinuationSeedSolvingSection(scanSeedSolvePanel);

    scanActionPanel = uipanel(scanTabGrid, ...
        'Title', '2D Scan', ...
        'Scrollable', 'on');
    scanActionPanel.Layout.Row = 4;
    scanActionPanel.Layout.Column = 1;

    scanActionContentPanel = uipanel(scanActionPanel, ...
        'BorderType', 'none', ...
        'Position', [1, 1, 200, scanActionContentMinHeight]);
    scanGrid = uigridlayout(scanActionContentPanel, [5, 2]);
    scanGrid.RowHeight = {'fit', 'fit', 'fit', 70, 'fit'};
    scanGrid.ColumnWidth = {'fit', '1x'};
    scanGrid.Padding = [10 10 10 10];
    scanGrid.RowSpacing = 8;
    scanGrid.ColumnSpacing = 8;

    scanInstructionLabel = uilabel(scanGrid, ...
        'Text', 'Choose a parameter and provide the target values for a two-directional scan from the validated seed pair.', ...
        'WordWrap', 'on');
    scanInstructionLabel.Layout.Row = 1;
    scanInstructionLabel.Layout.Column = [1 2];

    parameterScanLabel = uilabel(scanGrid, 'Text', 'Parameter', 'Interpreter', 'latex');
    parameterScanLabel.Layout.Row = 2;
    parameterScanLabel.Layout.Column = 1;

    parameterScanDropdown = uidropdown(scanGrid, ...
        'Items', parameteroptions, ...
        'Value', parameteroptions{1}, ...
        'ValueChangedFcn', @(src, event) UpdateParameterOperationLabels());
    parameterScanDropdown.Layout.Row = 2;
    parameterScanDropdown.Layout.Column = 2;

    currentScanValueLabel = uilabel(scanGrid, 'Text', 'Current value: n/a', 'WordWrap', 'on');
    currentScanValueLabel.Layout.Row = 3;
    currentScanValueLabel.Layout.Column = [1 2];

    scanValuesLabel = uilabel(scanGrid, ...
        'Text', 'Value List', ...
        'VerticalAlignment', 'top');
    scanValuesLabel.Layout.Row = 4;
    scanValuesLabel.Layout.Column = 1;

    scanValuesInput = uitextarea(scanGrid, ...
        'Value', {'0.8 0.9 1.0 1.1 1.2'}, ...
        'Tooltip', 'Defaults to 0.8, 0.9, 1.0, 1.1, and 1.2 times the loaded parameter value. Enter custom values separated by spaces, commas, semicolons, or line breaks.');
    scanValuesInput.Layout.Row = 4;
    scanValuesInput.Layout.Column = 2;

    scanButtonGrid = uigridlayout(scanGrid, [1, 3]);
    scanButtonGrid.Layout.Row = 5;
    scanButtonGrid.Layout.Column = [1 2];
    scanButtonGrid.RowHeight = {'fit'};
    scanButtonGrid.ColumnWidth = {'1x', '1x', '1x'};
    scanButtonGrid.Padding = [0 0 0 0];
    scanButtonGrid.ColumnSpacing = 8;

    run2DButton = uibutton(scanButtonGrid, 'Text', 'Run', ...
        'ButtonPushedFcn', @(src, event) Run2DContinuationScan());
    run2DButton.Layout.Row = 1;
    run2DButton.Layout.Column = 1;

    pause2DButton = uibutton(scanButtonGrid, 'Text', 'Pause', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(src, event) ToggleContinuationPause('2D'));
    pause2DButton.Layout.Row = 1;
    pause2DButton.Layout.Column = 2;

    stop2DButton = uibutton(scanButtonGrid, 'Text', 'Stop', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(src, event) RequestContinuationStop('2D'));
    stop2DButton.Layout.Row = 1;
    stop2DButton.Layout.Column = 3;

    addlistener(ax, 'MarkedClean', @(src, event) SyncInfoPanelFromAxes());
    viewXInput.ValueChangedFcn = @(src, event) UpdateViewFromInput();
    viewYInput.ValueChangedFcn = @(src, event) UpdateViewFromInput();

    ApplyLatexDropdownStyle(fixedparameterDropdown);
    ApplyLatexDropdownStyle(fixedparametervalueDropdown);
    ApplyLatexDropdownStyle(varyingparameterDropdown);
    ApplyLatexDropdownStyle(varyingparameterValuesDropdown);
    ApplyLatexDropdownStyle(xAxisDropdown);
    ApplyLatexDropdownStyle(yAxisDropdown);
    ApplyLatexDropdownStyle(zAxisDropdown);
    ApplyLatexDropdownStyle(parameterVaryingDropdown);
    ApplyLatexDropdownStyle(parameterScanDropdown);

    drawnow;
    UpdateStatusSectionLayout();
    UpdateSeedToolSectionLayouts();
    UpdateCursorInfoSectionLayout();
    UpdateContinuationActionLayout();
    UpdateParameterActionLayout();
    UpdateScanActionLayout();
    UpdateSolutionVisualizationLayout();

    parameterValues = GetParameterValues();
    SetDefaultVaryingParameter();
    UpdateSeedSolverOptions();
    UpdateSeedSourceControls();
    UpdateContinuationSeedSourceControls();
    RefreshSeedContextLabel();
    UpdateParameterOperationLabels();
    UpdateAxisData();
    UpdateAxisLimits();
    UpdateAspectRatioInputs();

    function ApplyLatexDropdownStyle(dropdownHandle)
        try
            addStyle(dropdownHandle, uistyle('Interpreter', 'latex'));
        catch
            try
                addStyle(dropdownHandle, uistyle('Interpreter', 'tex'));
            catch
            end
        end
    end

    function BuildPreviewSection(parentGrid, rowIndex)
        previewPanel = uipanel(parentGrid, 'Title', 'Continuation Preview');
        previewPanel.Layout.Row = rowIndex;
        previewPanel.Layout.Column = 1;

        previewGrid = uigridlayout(previewPanel, [2, 1]);
        previewGrid.RowHeight = {'1x', statusRowHeight};
        previewGrid.ColumnWidth = {'1x'};
        previewGrid.Padding = [6 6 6 6];
        previewGrid.RowSpacing = 6;

        previewAxes = uiaxes(previewGrid);
        previewAxes.Layout.Row = 1;
        previewAxes.Layout.Column = 1;
        ConfigurePreviewAxes(previewAxes, 'Orbit Preview');
        previewAxesHandles(end + 1) = previewAxes;

        statusLabel = uilabel(previewGrid, 'Text', 'Ready.', ...
            'WordWrap', 'on', 'VerticalAlignment', 'top');
        statusLabel.Layout.Row = 2;
        statusLabel.Layout.Column = 1;
        statusLabelHandles(end + 1) = statusLabel;
    end

    function ConfigurePreviewAxes(axHandle, titleText)
        cla(axHandle);
        axHandle.Title.String = titleText;
        axHandle.XLabel.String = '$\dot{q}_x$';
        axHandle.YLabel.String = '$\dot{q}_y$';
        axHandle.ZLabel.String = '$\dot{q}_{pitch}$';
        axHandle.XLabel.Interpreter = 'latex';
        axHandle.YLabel.Interpreter = 'latex';
        axHandle.ZLabel.Interpreter = 'latex';
        axHandle.View = [45, 30];
        grid(axHandle, 'on');
        hold(axHandle, 'off');
    end

    function BuildSeedSelectionSection(parentPanel, includeRadius)
        if includeRadius
            seedGrid = uigridlayout(parentPanel, [3, 4]);
            seedGrid.ColumnWidth = {'fit', '1x', 'fit', '1x'};
        else
            seedGrid = uigridlayout(parentPanel, [3, 2]);
            seedGrid.ColumnWidth = {'fit', '1x'};
        end
        seedGrid.RowHeight = {'fit', 'fit', 'fit'};
        seedGrid.Padding = [6 6 6 6];
        seedGrid.RowSpacing = 6;
        seedGrid.ColumnSpacing = 8;

        sourceLabel = uilabel(seedGrid, 'Text', 'Source');
        sourceLabel.Layout.Row = 1;
        sourceLabel.Layout.Column = 1;

        modeDropdown = uidropdown(seedGrid, ...
            'Items', {'Cursor', 'Index input'}, ...
            'Value', seedSourceMode, ...
            'ValueChangedFcn', @(src, event) SeedModeChanged(src));
        modeDropdown.Layout.Row = 1;
        modeDropdown.Layout.Column = 2;
        seedModeDropdowns(end + 1) = modeDropdown;

        if includeRadius
            radiusLabel = uilabel(seedGrid, 'Text', 'Radius');
            radiusLabel.Layout.Row = 1;
            radiusLabel.Layout.Column = 3;

            radiusInput = uieditfield(seedGrid, 'numeric', ...
                'Value', continuationRadiusValue, ...
                'LowerLimit', 1e-6, ...
                'ValueChangedFcn', @(src, event) SeedRadiusChanged(src));
            radiusInput.Layout.Row = 1;
            radiusInput.Layout.Column = 4;
            seedRadiusInputs(end + 1) = radiusInput;
        end

        indexLabel = uilabel(seedGrid, 'Text', 'Index');
        indexLabel.Layout.Row = 2;
        indexLabel.Layout.Column = 1;

        indexInput = uieditfield(seedGrid, 'numeric', ...
            'RoundFractionalValues', 'on', ...
            'Value', seedManualIndex, ...
            'ValueDisplayFormat', '%.0f', ...
            'ValueChangedFcn', @(src, event) SeedIndexChanged(src));
        indexInput.Layout.Row = 2;
        indexInput.Layout.Column = 2;
        seedIndexInputs(end + 1) = indexInput;

        if includeRadius
            pairInfoLabel = uilabel(seedGrid, ...
                'Text', 'Pair', ...
                'HorizontalAlignment', 'right');
            pairInfoLabel.Layout.Row = 2;
            pairInfoLabel.Layout.Column = 3;

            pairInfoValue = uilabel(seedGrid, ...
                'Text', 'Adjacent point auto-selected', ...
                'WordWrap', 'on');
            pairInfoValue.Layout.Row = 2;
            pairInfoValue.Layout.Column = 4;
        end

        contextLabel = uilabel(seedGrid, ...
            'Text', 'Cursor source: click a branch point to seed continuation.', ...
            'WordWrap', 'on');
        contextLabel.Layout.Row = 3;
        contextLabel.Layout.Column = [1 numel(seedGrid.ColumnWidth)];
        seedContextLabels(end + 1) = contextLabel;
    end

    function [sourceDropdown, valueLabel, valueInput, contextLabel] = ...
            BuildContinuationSeedSelectionSection(parentPanel)
        continuationSeedGrid = uigridlayout(parentPanel, [2, 4]);
        continuationSeedGrid.RowHeight = {'fit', 'fit'};
        continuationSeedGrid.ColumnWidth = {'fit', '1x', 'fit', '1x'};
        continuationSeedGrid.Padding = [6 6 6 6];
        continuationSeedGrid.RowSpacing = 6;
        continuationSeedGrid.ColumnSpacing = 8;

        sourceLabel = uilabel(continuationSeedGrid, 'Text', 'Source');
        sourceLabel.Layout.Row = 1;
        sourceLabel.Layout.Column = 1;

        sourceDropdown = uidropdown(continuationSeedGrid, ...
            'Items', {'Cursor', 'Index input', 'Percentage input', 'Solver'}, ...
            'Value', continuationSeedSourceMode, ...
            'ValueChangedFcn', @(src, event) ContinuationSeedSourceChanged(src));
        sourceDropdown.Layout.Row = 1;
        sourceDropdown.Layout.Column = 2;

        valueLabel = uilabel(continuationSeedGrid, 'Text', 'Index');
        valueLabel.Layout.Row = 1;
        valueLabel.Layout.Column = 3;

        valueInput = uieditfield(continuationSeedGrid, 'numeric', ...
            'Value', continuationSeedManualIndex, ...
            'ValueDisplayFormat', '%.0f', ...
            'ValueChangedFcn', @(src, event) ContinuationSeedValueChanged(src));
        valueInput.Layout.Row = 1;
        valueInput.Layout.Column = 4;

        contextLabel = uilabel(continuationSeedGrid, ...
            'Text', 'Cursor source: click a branch point to choose seed 1.', ...
            'WordWrap', 'on');
        contextLabel.Layout.Row = 2;
        contextLabel.Layout.Column = [1 4];
    end

    function [radiusInput, solveButton, removeButton, plotButton, removePlotButton] = ...
            BuildContinuationSeedSolvingSection(parentPanel)
        seedSolveGrid = uigridlayout(parentPanel, [3, 4]);
        seedSolveGrid.RowHeight = {'fit', 'fit', 'fit'};
        seedSolveGrid.ColumnWidth = {'fit', '1x', '1x', '1x'};
        seedSolveGrid.Padding = [6 6 6 6];
        seedSolveGrid.RowSpacing = 6;
        seedSolveGrid.ColumnSpacing = 8;

        radiusLabel = uilabel(seedSolveGrid, 'Text', 'Radius');
        radiusLabel.Layout.Row = 1;
        radiusLabel.Layout.Column = 1;

        radiusInput = uieditfield(seedSolveGrid, 'numeric', ...
            'Value', continuationRadiusValue, ...
            'LowerLimit', 1e-6, ...
            'ValueChangedFcn', @(src, event) ContinuationSeedRadiusChanged(src));
        radiusInput.Layout.Row = 1;
        radiusInput.Layout.Column = 2;

        solveButton = uibutton(seedSolveGrid, 'Text', 'Solve Second Seed', ...
            'ButtonPushedFcn', @(src, event) SolveContinuationSecondSeed(true));
        solveButton.Layout.Row = 1;
        solveButton.Layout.Column = 3;

        removeButton = uibutton(seedSolveGrid, 'Text', 'Remove Solved Second Seed', ...
            'ButtonPushedFcn', @(src, event) ClearContinuationSecondSeed(true));
        removeButton.Layout.Row = 1;
        removeButton.Layout.Column = 4;

        solveInfo = uilabel(seedSolveGrid, ...
            'Text', 'Second seed solver uses periodicity constraints plus a state-only radius constraint.', ...
            'WordWrap', 'on');
        solveInfo.Layout.Row = 2;
        solveInfo.Layout.Column = [1 4];

        seedPlotGrid = uigridlayout(seedSolveGrid, [1, 2]);
        seedPlotGrid.Layout.Row = 3;
        seedPlotGrid.Layout.Column = [1 4];
        seedPlotGrid.RowHeight = {'fit'};
        seedPlotGrid.ColumnWidth = {'1x', '1x'};
        seedPlotGrid.Padding = [0 0 0 0];
        seedPlotGrid.ColumnSpacing = 8;

        plotButton = uibutton(seedPlotGrid, 'Text', 'Plot Sol Pair', ...
            'ButtonPushedFcn', @(src, event) PlotContinuationSeedPair());
        plotButton.Layout.Row = 1;
        plotButton.Layout.Column = 1;

        removePlotButton = uibutton(seedPlotGrid, 'Text', 'Remove Plots', ...
            'ButtonPushedFcn', @(src, event) RemoveContinuationSeedPairPlot());
        removePlotButton.Layout.Row = 1;
        removePlotButton.Layout.Column = 2;
    end

    function tableHandle = CreateSeedEditorTable(parentPanel, entryNames)
        tableGrid = uigridlayout(parentPanel, [1, 1]);
        tableGrid.RowHeight = {'1x'};
        tableGrid.ColumnWidth = {'1x'};
        tableGrid.Padding = [0 0 0 0];

        tableHandle = uitable(tableGrid, ...
            'ColumnName', {'Entry', 'Current', 'Tune'}, ...
            'ColumnEditable', [false false true], ...
            'ColumnFormat', {'char', 'char', 'numeric'}, ...
            'RowName', [], ...
            'CellEditCallback', @(src, event) SeedEditorTableChanged(src, event));
        tableHandle.Layout.Row = 1;
        tableHandle.Layout.Column = 1;
        SetSeedTableData(tableHandle, entryNames, [], []);
    end

    function UpdateSeedSolverOptions()
        solverMaxFunEvalsInput.Value = max(1, round(solverMaxFunEvalsInput.Value));
        solverMaxIterInput.Value = max(1, round(solverMaxIterInput.Value));
        solverTolFunInput.Value = max(0, solverTolFunInput.Value);
        solverTolXInput.Value = max(0, solverTolXInput.Value);

        seedSolveOPTS = optimset('Algorithm', char(solverAlgorithmDropdown.Value), ...
            'ScaleProblem', char(solverScaleProblemDropdown.Value), ...
            'Display', char(solverDisplayDropdown.Value), ...
            'MaxFunEvals', solverMaxFunEvalsInput.Value, ...
            'MaxIter', solverMaxIterInput.Value, ...
            'UseParallel', strcmpi(solverUseParallelDropdown.Value, 'true'), ...
            'TolFun', solverTolFunInput.Value, ...
            'TolX', solverTolXInput.Value);
    end

    function solverSettings = GetSeedSolverSettingsSnapshot()
        solverSettings = struct( ...
            'Algorithm', char(solverAlgorithmDropdown.Value), ...
            'Display', char(solverDisplayDropdown.Value), ...
            'MaxFunEvals', solverMaxFunEvalsInput.Value, ...
            'MaxIter', solverMaxIterInput.Value, ...
            'TolFun', solverTolFunInput.Value, ...
            'TolX', solverTolXInput.Value, ...
            'ScaleProblem', char(solverScaleProblemDropdown.Value), ...
            'UseParallel', strcmpi(solverUseParallelDropdown.Value, 'true'), ...
            'OptionsStruct', seedSolveOPTS);
    end

    function textOut = SafeFilenameComponent(textIn, fallbackText)
        if nargin < 2 || isempty(fallbackText)
            fallbackText = 'solution';
        end
        textOut = regexprep(char(string(textIn)), '[^\w\-]+', '_');
        textOut = regexprep(textOut, '_+', '_');
        textOut = strtrim(textOut);
        textOut = regexprep(textOut, '^_+|_+$', '');
        if isempty(textOut)
            textOut = fallbackText;
        end
    end

    function SetTextLikeControl(controlHandle, textValue)
        if isempty(controlHandle) || ~isgraphics(controlHandle)
            return;
        end

        textValue = char(string(textValue));
        if isprop(controlHandle, 'Value')
            controlHandle.Value = textValue;
        elseif isprop(controlHandle, 'Text')
            controlHandle.Text = textValue;
        end
    end

    function tf = HasGraphicsHandle(handleValue)
        tf = ~isempty(handleValue) && any(isgraphics(handleValue));
    end

    function noiseState = MakeEmptyAppliedNoiseState()
        noiseState = struct('datasetName', '', 'index', [], 'seedX', [], 'seedPara', [], ...
            'noiseMode', '', 'stateNoise', [], 'parameterNoise', [], 'X', [], 'Para', []);
    end

    function secondSeed = MakeEmptyContinuationSecondSeed()
        secondSeed = struct('datasetName', '', ...
            'sourceMode', '', ...
            'index', [], ...
            'percent', [], ...
            'X1', [], ...
            'X2', [], ...
            'Para', [], ...
            'radius', [], ...
            'residualNorm', [], ...
            'distance', [], ...
            'distanceError', [], ...
            'seed1GaitType', '', ...
            'seed1GaitAbbr', '', ...
            'gaitType', '', ...
            'gaitAbbr', '', ...
            'exitflag', [], ...
            'solverOutput', struct(), ...
            'solverAttempt', '', ...
            'seed1Handle', gobjects(0), ...
            'seed2Handle', gobjects(0), ...
            'seed1TextHandle', gobjects(0), ...
            'seed2TextHandle', gobjects(0));
    end

    function seed = GetCurrentTunedSeed(showAlert)
        if nargin < 1
            showAlert = true;
        end

        seed = ResolveSeedTabReference(showAlert);
        if isempty(seed)
            return;
        end
        seed = GetSeedEditorValues(seed);
    end

    function tf = ScalarNoiseSettingMatches(storedValue, currentValue)
        if isempty(storedValue)
            tf = false;
            return;
        end
        tolerance = max(1e-12, 1e-9 * max(1, abs(currentValue)));
        tf = abs(storedValue - currentValue) <= tolerance;
    end

    function tf = AppliedNoiseMatchesSeed(seed)
        tf = false;
        if isempty(seed) || isempty(appliedNoiseState.X)
            return;
        end

        if ~strcmp(appliedNoiseState.datasetName, seed.datasetName) || isempty(appliedNoiseState.index) || ...
                appliedNoiseState.index ~= seed.index
            return;
        end

        if ~strcmp(appliedNoiseState.noiseMode, char(randomizationModeDropdown.Value))
            return;
        end

        if ~ScalarNoiseSettingMatches(appliedNoiseState.stateNoise, stateNoiseInput.Value) || ...
                ~ScalarNoiseSettingMatches(appliedNoiseState.parameterNoise, parameterNoiseInput.Value)
            return;
        end

        if numel(appliedNoiseState.seedX) ~= numel(seed.X) || numel(appliedNoiseState.seedPara) ~= numel(seed.Para)
            return;
        end

        tf = norm(appliedNoiseState.seedX(:) - seed.X(:)) <= 1e-10 && ...
            norm(appliedNoiseState.seedPara(:) - seed.Para(:)) <= 1e-10;
    end

    function UpdateNoiseApplicationDisplay()
        UpdatePredictionDistanceDisplay();
    end

    function statusText = FormatSeedNoiseStatus(seed)
        stateDistanceText = 'n/a';
        paraDistanceText = 'n/a';
        candidate = BuildPredictedSeedCandidate(false);
        if ~isempty(seed) && ~isempty(candidate.X)
            stateDistanceText = sprintf('%.3e', norm(candidate.X(:) - seed.X(:)));
            paraDistanceText = sprintf('%.3e', norm(candidate.Para(:) - seed.Para(:)));
        end

        statusText = sprintf(['Noise added to: %s index %d\n' ...
            'Noise type: %s\n' ...
            'Noise value: state %.4g, para %.4g\n' ...
            'Prediction distance: state %s, para %s'], ...
            seed.datasetName, seed.index, char(string(randomizationModeDropdown.Value)), ...
            stateNoiseInput.Value, parameterNoiseInput.Value, stateDistanceText, paraDistanceText);
    end

    function ApplySeedNoise()
        seed = GetCurrentTunedSeed(true);
        if isempty(seed)
            return;
        end

        stateNoiseValue = stateNoiseInput.Value;
        parameterNoiseValue = parameterNoiseInput.Value;
        if abs(stateNoiseValue) <= eps && abs(parameterNoiseValue) <= eps
            appliedNoiseState = MakeEmptyAppliedNoiseState();
        else
            noisyX = EventTimingRegulation(ApplyRandomization(seed.X, stateNoiseValue, randomizationModeDropdown.Value));
            noisyPara = EnforcePositiveParameters(ApplyRandomization(seed.Para, parameterNoiseValue, randomizationModeDropdown.Value));
            appliedNoiseState = struct('datasetName', seed.datasetName, ...
                'index', seed.index, ...
                'seedX', seed.X(:), ...
                'seedPara', seed.Para(:), ...
                'noiseMode', char(randomizationModeDropdown.Value), ...
                'stateNoise', stateNoiseValue, ...
                'parameterNoise', parameterNoiseValue, ...
                'X', noisyX(:), ...
                'Para', noisyPara(:));
        end

        ClearPredictedSeedCandidateData();
        UpdateNoiseApplicationDisplay();
        SetStatus(FormatSeedNoiseStatus(seed));
    end

    function RefreshSelectedCursorSummary()
        seedSummary = ResolveSeedTabReference(false);
        sourceText = seedSourceMode;

        if isempty(seedSummary)
            branchText = '<none>';
            if strcmp(seedSourceMode, 'Cursor')
                indexText = '<none>';
            else
                indexText = sprintf('%d', seedManualIndex);
            end
        else
            branchText = seedSummary.datasetName;
            indexText = sprintf('%d', seedSummary.index);
        end

        SetTextLikeControl(seedSelectionSummaryLabel, branchText);
        SetTextLikeControl(seedSourceField, sourceText);
        SetTextLikeControl(seedIndexField, indexText);
    end

    function SeedModeChanged(src)
        previousMode = seedSourceMode;
        nextMode = char(src.Value);
        if strcmp(nextMode, 'Index input')
            if ~isempty(cursorSelection.results) && ~isempty(cursorSelection.index)
                seedManualIndex = cursorSelection.index;
                ActivateDatasetSelection(cursorSelection.datasetName);
            end
            seedSourceMode = nextMode;
            ApplyManualSeedIndexToCurrentSolution(false);
        elseif strcmp(previousMode, 'Index input') && strcmp(nextMode, 'Cursor')
            ApplyManualSeedIndexToCurrentSolution(false);
            seedSourceMode = nextMode;
        else
            seedSourceMode = nextMode;
        end
        UpdateSeedSourceControls();
    end

    function indexValue = NormalizeSeedIndexValue(rawValue, fallbackValue)
        if nargin < 2 || isempty(fallbackValue)
            fallbackValue = 1;
        end

        if isnumeric(rawValue)
            parsedValue = rawValue;
        else
            parsedValue = str2double(string(rawValue));
        end

        if ~(isscalar(parsedValue) && isfinite(parsedValue))
            parsedValue = fallbackValue;
        end
        indexValue = max(1, round(parsedValue));
    end

    function SeedIndexChanged(src)
        seedManualIndex = NormalizeSeedIndexValue(src.Value, seedManualIndex);
        if strcmp(seedSourceMode, 'Index input')
            ApplyManualSeedIndexToCurrentSolution(false);
        end
        UpdateSeedSourceControls();
    end

    function applied = ApplyManualSeedIndexToCurrentSolution(showAlert, updateBranchSelection)
        if nargin < 1
            showAlert = true;
        end
        if nargin < 2
            updateBranchSelection = true;
        end

        applied = false;
        dataset = GetActiveOperationDataset();
        if isempty(dataset)
            if showAlert
                uialert(fig, 'Select a plotted dataset before using manual index input.', 'Seed Info');
            end
            return;
        end

        nPts = size(dataset.results, 2);
        if nPts < 1
            return;
        end

        idx = max(1, min(nPts, round(seedManualIndex)));
        seedManualIndex = idx;
        [xCoord, yCoord, zCoord] = GetSolutionCoordinates(dataset.results(1:22, idx));
        cursorSelection = BuildCursorSelection(dataset.filename, dataset.results, idx, ...
            [xCoord, yCoord, zCoord], dataset.handle);
        if updateBranchSelection
            ApplyDatasetSelection(dataset.filename);
        end
        ClearSeedManualSelectionVisualization();
        RefreshSelectedSolutionVisualization();
        RefreshCursorInfoDisplay();
        SetSelectedSolutionStatus();
        applied = true;
    end

    function SeedRadiusChanged(src)
        continuationRadiusValue = max(1e-6, src.Value);
        ClearContinuationSecondSeed(false);
        UpdateSeedSourceControls();
    end

    function ContinuationSeedSourceChanged(src)
        continuationSeedSourceMode = char(string(src.Value));
        if strcmp(continuationSeedSourceMode, 'Index input') && ...
                ~isempty(cursorSelection.results) && ~isempty(cursorSelection.index)
            continuationSeedManualIndex = cursorSelection.index;
        end
        ClearContinuationSecondSeed(false);
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
    end

    function ContinuationSeedValueChanged(src)
        switch continuationSeedSourceMode
            case 'Index input'
                continuationSeedManualIndex = NormalizeSeedIndexValue(src.Value, continuationSeedManualIndex);
            case 'Percentage input'
                continuationSeedPercentValue = max(0, min(100, src.Value));
            otherwise
                UpdateContinuationSeedSourceControls();
                return;
        end
        ClearContinuationSecondSeed(false);
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
    end

    function ContinuationSeedRadiusChanged(src)
        continuationRadiusValue = max(1e-6, src.Value);
        ClearContinuationSecondSeed(false);
        UpdateContinuationSeedSourceControls();
        UpdateSeedSourceControls();
    end

    function SeedEditorTableChanged(src, event)
        if isempty(event.Indices) || event.Indices(2) ~= 3
            return;
        end

        newValue = event.NewData;
        if ~(isnumeric(newValue) && isscalar(newValue) && isfinite(newValue))
            tableData = src.Data;
            tableData{event.Indices(1), event.Indices(2)} = event.PreviousData;
            src.Data = tableData;
            return;
        end

        UpdateParameterOperationLabels();
        UpdatePreviewFromCurrentSeed();
        UpdateNoiseApplicationDisplay();
    end

    function UpdateSeedSourceControls()
        isManual = strcmp(seedSourceMode, 'Index input');

        if isgraphics(seedSourceField) && isprop(seedSourceField, 'Value') && ...
                ~strcmp(seedSourceField.Value, seedSourceMode)
            seedSourceField.Value = seedSourceMode;
        end

        for i = 1:numel(seedModeDropdowns)
            if isgraphics(seedModeDropdowns(i)) && ~strcmp(seedModeDropdowns(i).Value, seedSourceMode)
                seedModeDropdowns(i).Value = seedSourceMode;
            end
        end

        for i = 1:numel(seedIndexInputs)
            if ~isgraphics(seedIndexInputs(i))
                continue;
            end
            seedIndexInputs(i).Value = seedManualIndex;
            if isManual
                seedIndexInputs(i).Editable = 'on';
                seedIndexInputs(i).Enable = 'on';
            else
                seedIndexInputs(i).Editable = 'off';
                seedIndexInputs(i).Enable = 'off';
            end
        end

        if isgraphics(seedIndexField)
            if isManual
                seedIndexField.Editable = 'on';
                seedIndexField.Enable = 'on';
                seedIndexField.Value = sprintf('%d', seedManualIndex);
            else
                seedIndexField.Editable = 'off';
                seedIndexField.Enable = 'on';
            end
        end

        for i = 1:numel(seedRadiusInputs)
            if isgraphics(seedRadiusInputs(i))
                seedRadiusInputs(i).Value = continuationRadiusValue;
            end
        end

        RefreshSeedContextLabel();
        UpdateContinuationSeedSourceControls();
        RefreshSelectedCursorSummary();
        RefreshSeedManualSelectionVisualization();
        UpdateParameterOperationLabels();
        UpdatePredictionDistanceDisplay();
    end

    function UpdateContinuationSeedSourceControls()
        sourceDropdowns = [continuationSeedSourceDropdown, ...
            parameterContinuationSeedSourceDropdown, ...
            scanContinuationSeedSourceDropdown];
        for iControl = 1:numel(sourceDropdowns)
            if isgraphics(sourceDropdowns(iControl)) && ...
                    ~strcmp(sourceDropdowns(iControl).Value, continuationSeedSourceMode)
                sourceDropdowns(iControl).Value = continuationSeedSourceMode;
            end
        end

        UpdateContinuationSeedValueControl(continuationSeedValueLabel, continuationSeedValueInput);
        UpdateContinuationSeedValueControl(parameterContinuationSeedValueLabel, parameterContinuationSeedValueInput);
        UpdateContinuationSeedValueControl(scanContinuationSeedValueLabel, scanContinuationSeedValueInput);

        radiusInputs = [continuationRadiusInput, parameterContinuationRadiusInput, ...
            scanContinuationRadiusInput];
        for iControl = 1:numel(radiusInputs)
            if isgraphics(radiusInputs(iControl))
                radiusInputs(iControl).Value = continuationRadiusValue;
            end
        end

        RefreshContinuationSeedContextLabel();
    end

    function UpdateContinuationSeedValueControl(valueLabel, valueInput)
        if ~(isgraphics(valueLabel) && isgraphics(valueInput))
            return;
        end

        switch continuationSeedSourceMode
            case 'Index input'
                valueLabel.Text = 'Index';
                valueInput.ValueDisplayFormat = '%.0f';
                valueInput.Value = continuationSeedManualIndex;
                valueInput.Editable = 'on';
                valueInput.Enable = 'on';
            case 'Percentage input'
                valueLabel.Text = 'Percentage';
                valueInput.ValueDisplayFormat = '%.3g%%';
                valueInput.Value = continuationSeedPercentValue;
                valueInput.Editable = 'on';
                valueInput.Enable = 'on';
            case 'Cursor'
                valueLabel.Text = 'Cursor Index';
                valueInput.ValueDisplayFormat = '%.0f';
                if ~isempty(cursorSelection.index)
                    valueInput.Value = cursorSelection.index;
                else
                    valueInput.Value = continuationSeedManualIndex;
                end
                valueInput.Editable = 'off';
                valueInput.Enable = 'off';
            otherwise
                valueLabel.Text = 'Solved Index';
                valueInput.ValueDisplayFormat = '%.0f';
                if ~isempty(solvedSeedCandidate.index)
                    valueInput.Value = solvedSeedCandidate.index;
                else
                    valueInput.Value = 0;
                end
                valueInput.Editable = 'off';
                valueInput.Enable = 'off';
        end
    end

    function seed = ResolveSeedReference(showAlert)
        if nargin < 1
            showAlert = true;
        end

        seed = [];
        if strcmp(seedSourceMode, 'Cursor')
            if isempty(cursorSelection.results)
                if showAlert
                    uialert(fig, 'Click a point on a plotted branch to use cursor-based seeding.', 'Seed Info');
                end
                return;
            end

            seed = struct('datasetName', cursorSelection.datasetName, ...
                'index', cursorSelection.index, ...
                'X', cursorSelection.X(:), ...
                'Para', cursorSelection.Para(:), ...
                'results', cursorSelection.results);
            return;
        end

        dataset = GetActiveOperationDataset();
        if isempty(dataset)
            if showAlert
                uialert(fig, 'Select a plotted dataset before using manual index input.', 'Seed Info');
            end
            return;
        end

        nPts = size(dataset.results, 2);
        idx = max(1, min(nPts, round(seedManualIndex)));
        if seedManualIndex ~= idx
            seedManualIndex = idx;
        end

        seed = struct('datasetName', dataset.filename, ...
            'index', idx, ...
            'X', dataset.results(1:22, idx), ...
            'Para', DatasetParameterAtIndex(dataset.results, idx), ...
            'results', dataset.results);
    end

    function seed = ResolveSeedTabReference(showAlert)
        seed = ResolveSeedReference(showAlert);
    end

    function signature = SeedReferenceSignature(seed)
        if isempty(seed)
            signature = "";
        else
            signature = string(sprintf('%s|%d', seed.datasetName, seed.index));
        end
    end

    function SetSeedTableData(tableHandle, entryNames, currentValues, tunedValues)
        rowCount = numel(entryNames);
        data = cell(rowCount, 3);
        for i = 1:rowCount
            data{i, 1} = entryNames{i};
            if isempty(currentValues)
                data{i, 2} = 'n/a';
            else
                data{i, 2} = sprintf('%.6g', currentValues(i));
            end

            if isempty(tunedValues)
                data{i, 3} = NaN;
            else
                data{i, 3} = tunedValues(i);
            end
        end
        tableHandle.Data = data;
    end

    function values = ReadSeedTableValues(tableHandle, fallbackValues)
        values = fallbackValues(:);
        if isempty(tableHandle) || ~isgraphics(tableHandle)
            return;
        end

        tableData = tableHandle.Data;
        if isempty(tableData)
            return;
        end

        for i = 1:min(numel(values), size(tableData, 1))
            candidate = tableData{i, 3};
            if isnumeric(candidate) && isscalar(candidate) && isfinite(candidate)
                values(i) = candidate;
            end
        end
    end

    function seedOut = GetSeedEditorValues(seedIn)
        seedOut = seedIn;
        if isempty(seedIn) || strlength(seedEditorSignature) == 0 || ...
                seedEditorSignature ~= SeedReferenceSignature(seedIn)
            return;
        end

        stateValues = ReadSeedTableValues(stateSeedTable, seedIn.X(1:13));
        timingValues = ReadSeedTableValues(timingSeedTable, seedIn.X(14:22));
        parameterValuesLocal = ReadSeedTableValues(parameterSeedTable, seedIn.Para);

        seedOut.X = EventTimingRegulation([stateValues; timingValues]);
        seedOut.Para = EnforcePositiveParameters(parameterValuesLocal);
    end

    function PopulateSeedEditorTables(forceReset)
        if nargin < 1
            forceReset = false;
        end

        seedBase = ResolveSeedTabReference(false);
        nextSignature = SeedReferenceSignature(seedBase);

        if isempty(seedBase)
            if forceReset || strlength(seedEditorSignature) > 0
                SetSeedTableData(stateSeedTable, stateEntryNames, [], []);
                SetSeedTableData(timingSeedTable, timingEntryNames, [], []);
                SetSeedTableData(parameterSeedTable, parameterEntryNames, [], []);
            end
            seedEditorSignature = "";
            if isempty(tempContinuationResults)
                ResetAllPreviewAxes('Orbit Preview');
            end
            return;
        end

        if forceReset || seedEditorSignature ~= nextSignature
            SetSeedTableData(stateSeedTable, stateEntryNames, seedBase.X(1:13), seedBase.X(1:13));
            SetSeedTableData(timingSeedTable, timingEntryNames, seedBase.X(14:22), seedBase.X(14:22));
            SetSeedTableData(parameterSeedTable, parameterEntryNames, seedBase.Para, seedBase.Para);
            seedEditorSignature = nextSignature;
        end

        UpdatePreviewFromCurrentSeed();
    end

    function [idx1, idx2] = ResolveContinuationIndices(indexValue, pointCount)
        if pointCount < 2
            idx1 = [];
            idx2 = [];
            return;
        end

        idx1 = max(1, min(pointCount, round(indexValue)));
        if idx1 >= pointCount
            idx1 = pointCount - 1;
            idx2 = pointCount;
        else
            idx2 = idx1 + 1;
        end
    end

    function ResetAllPreviewAxes(titleText)
        if nargin < 1
            titleText = 'Orbit Preview';
        end

        for i = 1:numel(previewAxesHandles)
            if isgraphics(previewAxesHandles(i))
                ConfigurePreviewAxes(previewAxesHandles(i), titleText);
                hold(previewAxesHandles(i), 'off');
            end
        end
    end

    function UpdatePreviewFromCurrentSeed(animatePreview)
        if nargin < 1
            animatePreview = true;
        end

        seedBase = ResolveSeedTabReference(false);
        if isempty(seedBase)
            if isempty(tempContinuationResults)
                ResetAllPreviewAxes('Orbit Preview');
            end
            return;
        end

        seedEdited = GetSeedEditorValues(seedBase);
        try
            [~, ~, gaitColor, ~] = Gait_Identification(seedEdited.X);
        catch
            gaitColor = [0 0.4470 0.7410];
        end
        UpdateContinuationPreviewOrbit(seedEdited.X, seedEdited.Para, ...
            sprintf('Seed preview: %s | %d', seedBase.datasetName, seedBase.index), gaitColor, animatePreview);
    end

    function radiusValue = GetContinuationRadius()
        radiusValue = max(1e-6, continuationRadiusValue);
    end

    function [xSolved, fSolved] = ProjectSeedGuessToSolution(xGuess, paraGuess, labelText)
        [xSolved, fSolved, exitflag] = fsolve(@(X) Quadrupedal_ZeroFun_v2(X, paraGuess, 'skipSolve'), ...
            EventTimingRegulation(xGuess(:)), seedSolveOPTS);
        xSolved = EventTimingRegulation(xSolved);
        if exitflag <= 0 || ~SolutionAcceptedGUI(fSolved, xSolved)
            error('Unable to recover a valid periodic solution from the tuned %s.', labelText);
        end
    end

    function cursor = MakeEmptyCursorSelection()
        cursor = struct('datasetName', '', 'results', [], 'index', [], ...
            'position', [], 'handle', [], 'X', [], 'Para', []);
    end

    function idx = ParameterDisplayToIndex(displayValue)
        idx = find(strcmp(parameteroptions, displayValue), 1);
        if isempty(idx)
            idx = [];
        end
    end

    function key = ParameterDisplayToKey(displayValue)
        idx = ParameterDisplayToIndex(displayValue);
        if isempty(idx)
            key = 'param';
        else
            key = parameterkeys{idx};
        end
    end

    function [xIndex, yIndex, zIndex] = GetAxisIndices()
        xIndex = find(strcmp(axisOptions, xAxisDropdown.Value), 1);
        yIndex = find(strcmp(axisOptions, yAxisDropdown.Value), 1);
        zIndex = find(strcmp(axisOptions, zAxisDropdown.Value), 1);
        if isempty(xIndex), xIndex = 1; end
        if isempty(yIndex), yIndex = 5; end
        if isempty(zIndex), zIndex = 2; end
    end

    function files = GetMatFiles()
        matFiles = dir(fullfile(currentfolder, '*.mat'));
        validFiles = {};
        for i = 1:numel(matFiles)
            try
                data = load(fullfile(currentfolder, matFiles(i).name), 'results');
                if isfield(data, 'results')
                    validFiles{end + 1} = matFiles(i).name; %#ok<AGROW>
                end
            catch
            end
        end
        if isempty(validFiles)
            files = {'<none>'};
        else
            files = validFiles;
        end
    end

    function SelectFolder()
        folder = uigetdir(currentfolder);
        BringGUIToFront();
        if isequal(folder, 0)
            return;
        end
        currentfolder = folder;
        datasetDropdown.Items = GetMatFiles();
        if isempty(datasetDropdown.Items)
            datasetDropdown.Items = {'<none>'};
        end
        if ~any(strcmp(datasetDropdown.Items, datasetDropdown.Value))
            datasetDropdown.Value = datasetDropdown.Items{1};
        end
        parameterValues = GetParameterValues();
        SetDefaultVaryingParameter();
        RefreshSeedContextLabel();
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
        SetStatus(['Current folder: ' currentfolder]);
    end

    function BringGUIToFront()
        if ~isgraphics(fig)
            return;
        end

        try
            if isprop(fig, 'WindowState') && strcmpi(fig.WindowState, 'minimized')
                fig.WindowState = 'normal';
            end
        catch
        end

        % Toggling visibility restores focus for uifigure after native file dialogs.
        try
            fig.Visible = 'off';
            drawnow;
            fig.Visible = 'on';
            drawnow;
            return;
        catch
        end

        try
            figure(fig);
        catch
        end
    end

    function PlotSelectedDataset()
        PlotDatasetByName(datasetDropdown.Value);
    end

    function PlotAllDatasets()
        items = datasetDropdown.Items;
        if isempty(items) || any(strcmp(items, '<none>'))
            return;
        end
        for i = 1:numel(items)
            PlotDatasetByName(items{i});
        end
    end

    function plotted = PlotDatasetByName(filename)
        plotted = false;
        if ~isgraphics(fig) || ~isgraphics(ax)
            return;
        end
        if isempty(filename) || strcmp(filename, '<none>')
            return;
        end

        existingIdx = FindPlottedDatasetByName(filename);
        if ~isempty(existingIdx)
            ActivateDatasetSelection(filename);
            plotted = true;
            return;
        end

        dataPath = fullfile(currentfolder, filename);
        if ~isfile(dataPath)
            uialert(fig, ['Cannot find file: ' filename], 'Missing File');
            return;
        end

        data = load(dataPath, 'results');
        if ~isfield(data, 'results')
            uialert(fig, 'Selected file does not contain "results".', 'Error');
            return;
        end

        branchResults = data.results;
        results = branchResults;
        plotHandle = PlotBranchInGUI(ax, branchResults, false);
        plottedDatasets{end + 1} = struct('filename', filename, 'results', branchResults, ...
            'handle', plotHandle, 'origin', 'file'); %#ok<AGROW>

        updateDatasetListBox();
        ActivateDatasetSelection(filename);
        UpdateAxisData();
        UpdateAxisLimits();
        RefreshSeedContextLabel();
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
        SetStatus(['Plotted dataset: ' filename]);
        plotted = true;
    end

    function idx = FindPlottedDatasetByName(name)
        idx = [];
        for i = 1:numel(plottedDatasets)
            if strcmp(plottedDatasets{i}.filename, name)
                idx = i;
                return;
            end
        end
    end

    function idx = FindPlottedDatasetByHandle(handle)
        idx = [];
        for i = 1:numel(plottedDatasets)
            if isequal(plottedDatasets{i}.handle, handle)
                idx = i;
                return;
            end
        end
    end

    function updateDatasetListBox()
        datasetNames = cellfun(@(dataStruct) dataStruct.filename, plottedDatasets, 'UniformOutput', false);
        datasetListBox.Items = [{'<None>'}, datasetNames];
        if ~isempty(selectedDatasetHandle) && any(strcmp(datasetListBox.Items, selectedDatasetHandle))
            datasetListBox.Value = selectedDatasetHandle;
        else
            datasetListBox.Value = '<None>';
        end
    end

    function ApplyDatasetSelection(datasetName)
        if isempty(datasetName) || strcmp(datasetName, '<None>')
            selectedDatasetHandle = [];
            datasetListBox.Value = '<None>';
            for i = 1:numel(plottedDatasets)
                if isgraphics(plottedDatasets{i}.handle)
                    plottedDatasets{i}.handle.LineWidth = 2;
                end
            end
            SyncVaryingValueDropdown([]);
            SyncOscillatorFromMainSelection();
            return;
        end

        selectedDatasetHandle = datasetName;
        if any(strcmp(datasetListBox.Items, datasetName))
            datasetListBox.Value = datasetName;
        end
        for i = 1:numel(plottedDatasets)
            if ~isgraphics(plottedDatasets{i}.handle)
                continue;
            end
            if strcmp(plottedDatasets{i}.filename, datasetName)
                plottedDatasets{i}.handle.LineWidth = 5;
                SyncVaryingValueDropdown(plottedDatasets{i}.results);
            else
                plottedDatasets{i}.handle.LineWidth = 2;
            end
        end
        SyncOscillatorFromMainSelection();
    end

    function textOut = FormatCursorInfoText(selection, emptyText)
        if nargin < 2 || isempty(emptyText)
            emptyText = 'No data available';
        end

        if isempty(selection.results)
            textOut = emptyText;
            return;
        end

        pos = selection.position;
        textOut = sprintf('Dataset: %s\nIndex: %d\nX: %.4f\nY: %.4f\nZ: %.4f', ...
            selection.datasetName, selection.index, pos(1), pos(2), pos(3));
    end

    function RefreshCursorInfoDisplay()
        cursorInfoLabel.Text = FormatCursorInfoText(hoverSelection, 'Move over a branch point');
        selectedCursorInfoLabel.Text = FormatCursorInfoText(cursorSelection, ...
            'Click a branch point to lock selected data info');
        RefreshSelectedCursorSummary();
    end

    function SetSelectedSolutionStatus()
        if isempty(cursorSelection.results)
            SetStatus('Selected solution: <none>');
            return;
        end
        SetStatus(sprintf('Selected solution:\nDataset: %s\nIndex: %d', ...
            cursorSelection.datasetName, cursorSelection.index));
    end

    function selection = BuildCursorSelection(datasetName, datasetResults, index, pos, srcHandle)
        selection = struct('datasetName', datasetName, ...
            'results', datasetResults, ...
            'index', index, ...
            'position', pos, ...
            'handle', srcHandle, ...
            'X', datasetResults(1:22, index), ...
            'Para', DatasetParameterAtIndex(datasetResults, index));
    end

    function [selection, found] = ResolveNearestCursorSelection(point, preferredHandle)
        if nargin < 2
            preferredHandle = [];
        end

        selection = MakeEmptyCursorSelection();
        found = false;
        if isempty(plottedDatasets)
            return;
        end

        xScale = max(diff(ax.XLim), eps);
        yScale = max(diff(ax.YLim), eps);
        zScale = max(diff(ax.ZLim), eps);
        bestDistance = inf;
        bestSelection = selection;

        candidateIndices = 1:numel(plottedDatasets);
        if ~isempty(preferredHandle)
            preferredIdx = FindPlottedDatasetByHandle(preferredHandle);
            if ~isempty(preferredIdx)
                candidateIndices = preferredIdx;
            end
        end

        for idx = candidateIndices
            if ~isgraphics(plottedDatasets{idx}.handle)
                continue;
            end

            xData = plottedDatasets{idx}.handle.XData(:);
            yData = plottedDatasets{idx}.handle.YData(:);
            zData = plottedDatasets{idx}.handle.ZData(:);
            if isempty(xData)
                continue;
            end

            distances = ((xData - point(1)) ./ xScale).^2 + ...
                ((yData - point(2)) ./ yScale).^2 + ...
                ((zData - point(3)) ./ zScale).^2;
            [minDistance, nearestIndex] = min(distances);
            if minDistance < bestDistance
                bestDistance = minDistance;
                bestSelection = BuildCursorSelection(plottedDatasets{idx}.filename, ...
                    plottedDatasets{idx}.results, nearestIndex, ...
                    [xData(nearestIndex), yData(nearestIndex), zData(nearestIndex)], ...
                    plottedDatasets{idx}.handle);
                found = true;
            end
        end

        if found
            selection = bestSelection;
        end
    end

    function tf = IsAxesRelatedObject(graphicsObj)
        tf = false;
        if isempty(graphicsObj) || ~isgraphics(graphicsObj)
            return;
        end

        if isequal(graphicsObj, ax)
            tf = true;
            return;
        end

        try
            parentAxes = ancestor(graphicsObj, 'axes');
            tf = isequal(parentAxes, ax);
        catch
            tf = false;
        end
    end

    function [pointerPoint, ok] = GetPointerLocationInFigure()
        ok = false;
        pointerPoint = [NaN, NaN];
        if ~isgraphics(fig)
            return;
        end

        if isprop(fig, 'CurrentPoint')
            try
                figPoint = fig.CurrentPoint;
                pointerPoint = figPoint(1, 1:2);
                ok = all(isfinite(pointerPoint));
            catch
                ok = false;
            end
        end

        if ok
            return;
        end

        try
            pointerLocation = get(groot, 'PointerLocation');
            pointerPoint = pointerLocation(1, 1:2) - fig.Position(1, 1:2);
            ok = all(isfinite(pointerPoint));
        catch
            ok = false;
        end
    end

    function tf = IsPointerInsideAxes()
        if ~isgraphics(fig) || ~isgraphics(ax)
            tf = false;
            return;
        end

        [pointerPoint, ok] = GetPointerLocationInFigure();
        if ~ok
            tf = false;
            return;
        end

        try
            axPosition = getpixelposition(ax, true);
        catch
            tf = false;
            return;
        end
        tf = pointerPoint(1) >= axPosition(1) && pointerPoint(1) <= axPosition(1) + axPosition(3) && ...
            pointerPoint(2) >= axPosition(2) && pointerPoint(2) <= axPosition(2) + axPosition(4);
    end

    function ClearCursorSelection()
        ClearActiveDataTip();
        cursorSelection = MakeEmptyCursorSelection();
        ClearSolutionVisualization();
        RefreshCursorInfoDisplay();
        SetSelectedSolutionStatus();
        SyncOscillatorFromMainSelection();
    end

    function ClearHoverSelection()
        hoverSelection = MakeEmptyCursorSelection();
        RefreshCursorInfoDisplay();
    end

    function ClearCurrentSolutionInfo()
        hadCurrentSolution = ~isempty(cursorSelection.results) || ...
            HasGraphicsHandle(activeDataTip) || HasGraphicsHandle(activeDataTipText);
        ClearCursorSelection();
        if strcmp(continuationSeedSourceMode, 'Cursor')
            ClearContinuationSecondSeed(false);
        end
        RefreshSeedContextLabel();
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
        SyncOscillatorFromMainSelection();
        if hadCurrentSolution
            SetStatus('Cleared current solution info and marker.');
        else
            SetStatus('No current solution to clear.');
        end
    end

    function ClearSelectedDataInfo()
        ClearCursorSelection();
        ClearDatasetSelection();
    end

    function ClearDatasetSelection()
        ApplyDatasetSelection('<None>');
        RefreshSeedContextLabel();
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
        SyncOscillatorFromMainSelection();
    end

    function ActivateDatasetSelection(datasetName)
        ApplyDatasetSelection(datasetName);
        if strcmp(seedSourceMode, 'Index input')
            ApplyManualSeedIndexToCurrentSolution(false, false);
        end
        RefreshSeedContextLabel();
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
    end

    function ClearActiveDataTip()
        if ~isempty(activeDataTip) && isvalid(activeDataTip)
            delete(activeDataTip);
        end
        if HasGraphicsHandle(activeDataTipText)
            delete(activeDataTipText);
        end
        if isgraphics(fig)
            figureDataTips = findall(fig, 'Type', 'datatip');
            if ~isempty(figureDataTips)
                delete(figureDataTips);
            end
        end
        activeDataTip = gobjects(0);
        activeDataTipText = gobjects(0);
    end

    function ShowBranchDataTip(srcHandle, dataIndex)
        ClearActiveDataTip();
        if nargin < 2 || isempty(dataIndex) || isempty(cursorSelection.results)
            return;
        end

        RefreshSelectedSolutionVisualization();
    end

    function RefreshSelectedSolutionVisualization()
        if ~isgraphics(ax)
            return;
        end
        if isempty(cursorSelection.results)
            ClearActiveDataTip();
            ClearSolutionVisualization();
            return;
        end

        InitializeSolutionVisualization();

        [xCoord, yCoord, zCoord] = GetSolutionCoordinates(cursorSelection.X);
        xOffset = 0.02 * max(diff(ax.XLim), eps);
        yOffset = 0.02 * max(diff(ax.YLim), eps);
        zOffset = 0.02 * max(diff(ax.ZLim), eps);

        if HasGraphicsHandle(activeDataTip)
            activeDataTip.XData = xCoord;
            activeDataTip.YData = yCoord;
            activeDataTip.ZData = zCoord;
        else
            activeDataTip = plot3(ax, xCoord, yCoord, zCoord, 'o', ...
                'LineStyle', 'none', 'MarkerSize', 10, ...
                'MarkerFaceColor', [0 0 0], 'MarkerEdgeColor', [0 0 0], ...
                'LineWidth', 1.2, 'HitTest', 'off');
        end

        if HasGraphicsHandle(activeDataTipText)
            activeDataTipText.Position = [xCoord + xOffset, yCoord + yOffset, zCoord + zOffset];
            activeDataTipText.String = ' Current Solution';
        else
            activeDataTipText = text(ax, xCoord + xOffset, yCoord + yOffset, zCoord + zOffset, ' Current Solution', ...
                'Interpreter', 'none', 'Color', [0 0 0], ...
                'BackgroundColor', [1 1 1], 'Margin', 1, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
                'HitTest', 'off');
        end
    end

    function FigureWindowClicked()
        if ~isgraphics(fig) || ~isgraphics(datasetListBox)
            return;
        end
        datasetListValueChangedThisClick = false;
        if isprop(datasetListBox, 'ClickedFcn')
            return;
        end

        currentObject = [];
        if isprop(fig, 'CurrentObject')
            currentObject = fig.CurrentObject;
        end
        if ~isequal(currentObject, datasetListBox)
            return;
        end

        drawnow limitrate;
        if ~datasetListValueChangedThisClick && strcmp(datasetListBox.Value, '<None>') && ~isempty(selectedDatasetHandle)
            ClearDatasetSelection();
        end
    end

    function FigureWindowMoved()
        if ~isgraphics(fig) || ~isgraphics(ax)
            return;
        end
        currentObject = [];
        if isprop(fig, 'CurrentObject')
            currentObject = fig.CurrentObject;
        end

        hoverAxes = IsPointerInsideAxes() || IsAxesRelatedObject(currentObject);
        if ~hoverAxes || isempty(plottedDatasets)
            if ~isempty(hoverSelection.results)
                ClearHoverSelection();
            end
            return;
        end

        preferredHandle = [];
        hoveredDatasetIdx = FindPlottedDatasetByHandle(currentObject);
        if ~isempty(hoveredDatasetIdx)
            preferredHandle = currentObject;
        end

        point = ax.CurrentPoint;
        [nearestSelection, found] = ResolveNearestCursorSelection(point(1, 1:3), preferredHandle);
        if ~found
            if ~isempty(hoverSelection.results)
                ClearHoverSelection();
            end
            return;
        end

        sameHover = ~isempty(hoverSelection.results) && strcmp(hoverSelection.datasetName, nearestSelection.datasetName) && ...
            hoverSelection.index == nearestSelection.index;
        hoverSelection = nearestSelection;
        if ~sameHover
            RefreshCursorInfoDisplay();
        end
    end

    function DatasetListBoxClicked(src, event)
        if datasetListValueChangedThisClick
            datasetListValueChangedThisClick = false;
            return;
        end

        clickedIndex = [];
        if isprop(event, 'InteractionInformation') && isprop(event.InteractionInformation, 'Item')
            clickedIndex = event.InteractionInformation.Item;
        end
        if isempty(clickedIndex) || clickedIndex < 1 || clickedIndex > numel(src.Items)
            return;
        end

        clickedNames = cellstr(string(src.Items));
        clickedName = clickedNames{clickedIndex};
        if strcmp(clickedName, '<None>')
            ClearDatasetSelection();
            return;
        end

        if strcmp(clickedName, selectedDatasetHandle)
            ClearDatasetSelection();
        else
            ActivateDatasetSelection(clickedName);
        end
    end

    function BranchLineClicked(src, event)
        if isprop(event, 'IntersectionPoint')
            point = event.IntersectionPoint;
        else
            currentPoint = ax.CurrentPoint;
            point = currentPoint(1, 1:3);
        end

        [nearestSelection, found] = ResolveNearestCursorSelection(point, src);
        if ~found
            return;
        end

        ActivateDatasetSelection(nearestSelection.datasetName);
        cursorSelection = nearestSelection;
        seedManualIndex = nearestSelection.index;
        ShowBranchDataTip(nearestSelection.handle, nearestSelection.index);
        hoverSelection = MakeEmptyCursorSelection();
        RefreshCursorInfoDisplay();
        SetSelectedSolutionStatus();
        RefreshSeedContextLabel();
        if strcmp(continuationSeedSourceMode, 'Cursor')
            ClearContinuationSecondSeed(false);
        end
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
        SyncOscillatorFromMainSelection();
    end

    function HighlightDataset(~, ~)
        datasetListValueChangedThisClick = true;
        selectedDataset = datasetListBox.Value;
        if strcmp(selectedDataset, '<None>') || isempty(selectedDataset)
            ClearDatasetSelection();
            return;
        end

        ActivateDatasetSelection(selectedDataset);
    end

    function DeleteAllDatasets()
        for i = 1:numel(plottedDatasets)
            if isgraphics(plottedDatasets{i}.handle)
                delete(plottedDatasets{i}.handle);
            end
        end
        plottedDatasets = {};
        selectedDatasetHandle = [];
        results = [];
        cursorSelection = MakeEmptyCursorSelection();
        hoverSelection = MakeEmptyCursorSelection();
        ClearActiveDataTip();
        ClearSolutionVisualization();
        RefreshCursorInfoDisplay();

        if isgraphics(tempContinuationHandle)
            delete(tempContinuationHandle);
        end
        tempContinuationHandle = gobjects(0);
        tempContinuationResults = [];

        for i = 1:numel(generatedSeedSolutions)
            if isgraphics(generatedSeedSolutions(i).handle)
                delete(generatedSeedSolutions(i).handle);
            end
        end
        generatedSeedSolutions = struct('name', {}, 'X', {}, 'Para', {}, 'handle', {});
        ClearContinuationSecondSeed(false);
        appliedNoiseState = MakeEmptyAppliedNoiseState();
        RemovePredictedSeedCandidate();
        ClearSolvedSeedCandidateData();

        ResetAllPreviewAxes('Orbit Preview');
        updateDatasetListBox();
        SyncOscillatorFromMainSelection();
        RefreshSeedContextLabel();
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
        SetStatus('Cleared all plotted branches and temporary continuation content.');
    end

    function DeleteSelectedDataset()
        selectedDataset = selectedDatasetHandle;
        if strcmp(selectedDataset, '<None>') || isempty(selectedDataset)
            return;
        end

        datasetIdx = FindPlottedDatasetByName(selectedDataset);
        if isempty(datasetIdx)
            return;
        end

        if isgraphics(plottedDatasets{datasetIdx}.handle)
            delete(plottedDatasets{datasetIdx}.handle);
        end
        plottedDatasets(datasetIdx) = [];
        selectedDatasetHandle = [];

        if strcmp(cursorSelection.datasetName, selectedDataset)
            ClearCursorSelection();
        end
        if strcmp(hoverSelection.datasetName, selectedDataset)
            hoverSelection = MakeEmptyCursorSelection();
        end
        if strcmp(predictedSeedCandidate.datasetName, selectedDataset)
            RemovePredictedSeedCandidate();
        end
        if strcmp(solvedSeedCandidate.datasetName, selectedDataset)
            ClearSolvedSeedCandidateData();
        end
        if strcmp(appliedNoiseState.datasetName, selectedDataset)
            appliedNoiseState = MakeEmptyAppliedNoiseState();
        end
        if strcmp(continuationSecondSeed.datasetName, selectedDataset)
            ClearContinuationSecondSeed(false);
        end
        RefreshCursorInfoDisplay();

        updateDatasetListBox();
        SyncOscillatorFromMainSelection();
        SyncVaryingValueDropdown([]);
        RefreshSeedContextLabel();
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
        SetStatus(['Deleted dataset: ' selectedDataset]);
    end

    function plotHandle = PlotBranchInGUI(axHandle, branchResults, baselineFlag)
        [~, ~, color_plot, linetype] = Gait_Identification(branchResults);
        if baselineFlag
            color_plot = [0.5, 0.5, 0.5];
        end

        brightness = 1;
        selectedParamIndex = ParameterDisplayToIndex(varyingparameterDropdown.Value);
        if ~isempty(selectedParamIndex) && ~isempty(varyingParameterSortedValues)
            paramValue = branchResults(22 + selectedParamIndex, 1);
            [minDiff, brightnessIdx] = min(abs(varyingParameterSortedValues - paramValue));
            if ~isempty(brightnessIdx) && minDiff <= max(1e-8, 1e-6 * max(1, abs(paramValue))) ...
                    && numel(brightnessValues) >= brightnessIdx
                brightness = brightnessValues(brightnessIdx);
            end
        end

        adjustedColor = min(1, max(0, color_plot * brightness));
        [xIndex, yIndex, zIndex] = GetAxisIndices();
        plotHandle = plot3(axHandle, branchResults(xIndex, :), branchResults(yIndex, :), branchResults(zIndex, :), ...
            'LineWidth', 2, 'Color', adjustedColor, 'LineStyle', linetype, ...
            'ButtonDownFcn', @(src, event) BranchLineClicked(src, event));
        plotHandle.PickableParts = 'all';
        plotHandle.HitTest = 'on';
    end

    function RefreshTemporaryContinuationHandle(branchResults)
        tempContinuationResults = branchResults;
        if isempty(branchResults)
            if isgraphics(tempContinuationHandle)
                delete(tempContinuationHandle);
            end
            tempContinuationHandle = gobjects(0);
            return;
        end

        [xIndex, yIndex, zIndex] = GetAxisIndices();
        if isempty(tempContinuationHandle) || ~isscalar(tempContinuationHandle) || ~isgraphics(tempContinuationHandle)
            tempContinuationHandle = plot3(ax, branchResults(xIndex, :), branchResults(yIndex, :), branchResults(zIndex, :), ...
                '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5);
        else
            tempContinuationHandle.XData = branchResults(xIndex, :);
            tempContinuationHandle.YData = branchResults(yIndex, :);
            tempContinuationHandle.ZData = branchResults(zIndex, :);
        end
        drawnow limitrate;
    end

    function markerHandle = PlotGeneratedSeedMarker(seedStruct)
        [xCoord, yCoord, zCoord] = GetSolutionCoordinates(seedStruct.X);
        [~, ~, gaitColor, ~] = Gait_Identification(seedStruct.X);
        markerHandle = plot3(ax, xCoord, yCoord, zCoord, 'p', ...
            'LineStyle', 'none', 'MarkerSize', 12, ...
            'MarkerFaceColor', gaitColor, 'MarkerEdgeColor', [0 0 0]);
    end

    function ClearSeedManualSelectionVisualization()
        if HasGraphicsHandle(seedManualSelectionHandle)
            delete(seedManualSelectionHandle);
        end
        if HasGraphicsHandle(seedManualSelectionTextHandle)
            delete(seedManualSelectionTextHandle);
        end
        seedManualSelectionHandle = gobjects(0);
        seedManualSelectionTextHandle = gobjects(0);
    end

    function RefreshSeedManualSelectionVisualization()
        ClearSeedManualSelectionVisualization();
        if strcmp(seedSourceMode, 'Index input')
            RefreshSelectedSolutionVisualization();
        end
    end

    function DeleteSeedCandidateMarkersByTag(markerTag)
        markerHandles = findobj(ax, 'Type', 'line', 'Tag', markerTag);
        if ~isempty(markerHandles)
            delete(markerHandles);
        end
    end

    function DeleteSeedCandidateTextsByTag(textTag)
        textHandles = findobj(ax, 'Type', 'text', 'Tag', textTag);
        if ~isempty(textHandles)
            delete(textHandles);
        end
    end

    function markerHandle = PlotSeedCandidateMarker(solutionVector, markerColor, edgeColor, markerTag)
        if nargin >= 4 && ~isempty(markerTag)
            DeleteSeedCandidateMarkersByTag(markerTag);
        end
        [xCoord, yCoord, zCoord] = GetSolutionCoordinates(solutionVector);
        markerHandle = plot3(ax, xCoord, yCoord, zCoord, 'o', ...
            'LineStyle', 'none', 'MarkerSize', 9, ...
            'MarkerFaceColor', markerColor, 'MarkerEdgeColor', edgeColor, ...
            'LineWidth', 1.2);
        if nargin >= 4 && ~isempty(markerTag)
            markerHandle.Tag = markerTag;
        end
    end

    function RefreshSingleSeedCandidateMarker(candidateName)
        markerGray = [0.55 0.55 0.55];
        switch candidateName
            case 'predicted'
                candidate = predictedSeedCandidate;
                markerColor = 'none';
                edgeColor = markerGray;
                markerTag = 'PredictedSeedCandidateMarker';
                textTag = 'PredictedSeedCandidateText';
                labelText = ' Predicted Solution';
            otherwise
                candidate = solvedSeedCandidate;
                markerColor = markerGray;
                edgeColor = markerGray;
                markerTag = 'SolvedSeedCandidateMarker';
                textTag = 'SolvedSeedCandidateText';
                labelText = ' Solved Solution';
        end

        if isempty(candidate.X)
            return;
        end

        [xCoord, yCoord, zCoord] = GetSolutionCoordinates(candidate.X);
        xOffset = 0.02 * max(diff(ax.XLim), eps);
        yOffset = 0.02 * max(diff(ax.YLim), eps);
        zOffset = 0.02 * max(diff(ax.ZLim), eps);
        if HasGraphicsHandle(candidate.handle)
            candidate.handle.XData = xCoord;
            candidate.handle.YData = yCoord;
            candidate.handle.ZData = zCoord;
            candidate.handle.MarkerFaceColor = markerColor;
            candidate.handle.MarkerEdgeColor = edgeColor;
            candidate.handle.Tag = markerTag;
        else
            candidate.handle = PlotSeedCandidateMarker(candidate.X, markerColor, edgeColor, markerTag);
        end

        if HasGraphicsHandle(candidate.textHandle)
            candidate.textHandle.Position = [xCoord + xOffset, yCoord + yOffset, zCoord + zOffset];
            candidate.textHandle.String = labelText;
            candidate.textHandle.Color = markerGray;
            candidate.textHandle.Tag = textTag;
        else
            DeleteSeedCandidateTextsByTag(textTag);
            candidate.textHandle = text(ax, xCoord + xOffset, yCoord + yOffset, zCoord + zOffset, labelText, ...
                'Interpreter', 'none', 'Color', markerGray, ...
                'BackgroundColor', [1 1 1], 'Margin', 1, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
                'HitTest', 'off', 'Tag', textTag);
        end

        switch candidateName
            case 'predicted'
                predictedSeedCandidate = candidate;
            otherwise
                solvedSeedCandidate = candidate;
        end
    end

    function RefreshSeedCandidateMarkers()
        RefreshSingleSeedCandidateMarker('predicted');
        RefreshSingleSeedCandidateMarker('solved');
    end

    function ClearPredictedSeedCandidateData()
        if HasGraphicsHandle(predictedSeedCandidate.handle)
            delete(predictedSeedCandidate.handle);
        end
        if HasGraphicsHandle(predictedSeedCandidate.textHandle)
            delete(predictedSeedCandidate.textHandle);
        end
        DeleteSeedCandidateMarkersByTag('PredictedSeedCandidateMarker');
        DeleteSeedCandidateTextsByTag('PredictedSeedCandidateText');
        predictedSeedCandidate = struct('datasetName', '', 'index', [], 'X', [], 'Para', [], ...
            'handle', gobjects(0), 'textHandle', gobjects(0));
    end

    function RemovePredictedSeedCandidate()
        hadPredictedMarker = HasGraphicsHandle(predictedSeedCandidate.handle) || ...
            ~isempty(findobj(ax, 'Type', 'line', 'Tag', 'PredictedSeedCandidateMarker')) || ...
            ~isempty(findobj(ax, 'Type', 'text', 'Tag', 'PredictedSeedCandidateText')) || ...
            ~isempty(predictedSeedCandidate.X);
        ClearPredictedSeedCandidateData();
        drawnow limitrate;
        if ~isempty(solvedSeedCandidate.X)
            UpdateContinuationPreviewOrbit(solvedSeedCandidate.X, solvedSeedCandidate.Para, ...
                sprintf('Solved seed: %s | %d', solvedSeedCandidate.datasetName, solvedSeedCandidate.index), [0 0 0], false);
        else
            UpdatePreviewFromCurrentSeed(false);
        end
        if hadPredictedMarker
            SetStatus('Removed the predicted seed marker.');
        else
            SetStatus('No predicted seed marker to remove.');
        end
    end

    function RemoveSolvedSeedCandidate()
        if HasGraphicsHandle(solvedSeedCandidate.handle)
            delete(solvedSeedCandidate.handle);
        end
        if HasGraphicsHandle(solvedSeedCandidate.textHandle)
            delete(solvedSeedCandidate.textHandle);
        end
        DeleteSeedCandidateMarkersByTag('SolvedSeedCandidateMarker');
        DeleteSeedCandidateTextsByTag('SolvedSeedCandidateText');
        solvedSeedCandidate.handle = gobjects(0);
        solvedSeedCandidate.textHandle = gobjects(0);
        if strcmp(continuationSeedSourceMode, 'Solver')
            ClearContinuationSecondSeed(false);
            UpdateContinuationSeedSourceControls();
        end
        if ~isempty(predictedSeedCandidate.X)
            UpdateContinuationPreviewOrbit(predictedSeedCandidate.X, predictedSeedCandidate.Para, ...
                sprintf('Predicted seed: %s | %d', predictedSeedCandidate.datasetName, predictedSeedCandidate.index), [0.65 0.65 0.65], false);
        else
            UpdatePreviewFromCurrentSeed(false);
        end
        SetStatus('Removed the solved solution marker.');
    end

    function ClearSolvedSeedCandidateData()
        if HasGraphicsHandle(solvedSeedCandidate.handle)
            delete(solvedSeedCandidate.handle);
        end
        if HasGraphicsHandle(solvedSeedCandidate.textHandle)
            delete(solvedSeedCandidate.textHandle);
        end
        DeleteSeedCandidateMarkersByTag('SolvedSeedCandidateMarker');
        DeleteSeedCandidateTextsByTag('SolvedSeedCandidateText');
        solvedSeedCandidate = struct('datasetName', '', 'index', [], 'X', [], 'Para', [], ...
            'residualNorm', [], 'residualVector', [], 'gaitType', '', 'gaitAbbr', '', ...
            'seedInfo', struct(), 'predictedInfo', struct(), 'solverSettings', struct(), ...
            'solverOutput', struct(), 'exitflag', [], 'guessMode', '', ...
            'handle', gobjects(0), 'textHandle', gobjects(0));
        if strcmp(continuationSeedSourceMode, 'Solver')
            ClearContinuationSecondSeed(false);
            UpdateContinuationSeedSourceControls();
        end
        UpdateSolvedSolutionDisplay();
    end

    function candidate = BuildPredictedSeedCandidate(showAlert)
        if nargin < 1
            showAlert = true;
        end

        candidate = struct('datasetName', '', 'index', [], 'X', [], 'Para', [], ...
            'handle', gobjects(0), 'textHandle', gobjects(0));
        seed = GetCurrentTunedSeed(showAlert);
        if isempty(seed)
            return;
        end

        candidate.datasetName = seed.datasetName;
        candidate.index = seed.index;
        if AppliedNoiseMatchesSeed(seed)
            candidate.X = appliedNoiseState.X(:);
            candidate.Para = appliedNoiseState.Para(:);
        else
            candidate.X = seed.X(:);
            candidate.Para = seed.Para(:);
        end
    end

    function UpdatePredictionDistanceDisplay()
        stateText = 'State: n/a';
        paraText = 'Para: n/a';
        seed = GetCurrentTunedSeed(false);
        candidate = BuildPredictedSeedCandidate(false);

        if ~isempty(seed) && ~isempty(candidate.X)
            deltaX = candidate.X(:) - seed.X(:);
            deltaPara = candidate.Para(:) - seed.Para(:);
            stateText = sprintf('State: %.3e', norm(deltaX));
            paraText = sprintf('Para: %.3e', norm(deltaPara));
        end

        if isgraphics(predictionDistanceLabel)
            predictionDistanceLabel.Text = 'Prediction distance:';
        end
        if isgraphics(predictionStateDistanceLabel)
            predictionStateDistanceLabel.Text = stateText;
        end
        if isgraphics(predictionParameterDistanceLabel)
            predictionParameterDistanceLabel.Text = paraText;
        end
    end

    function solvedText = UpdateSolvedSolutionDisplay()
        solvedText = sprintf('Solved Solution Info:\nResidual: n/a\nGait type: n/a');
        if ~isempty(solvedSeedCandidate.X)
            residualText = 'n/a';
            gaitText = 'n/a';
            if isfield(solvedSeedCandidate, 'residualNorm') && ~isempty(solvedSeedCandidate.residualNorm) ...
                    && isfinite(solvedSeedCandidate.residualNorm)
                residualText = sprintf('%.3e', solvedSeedCandidate.residualNorm);
            end
            if isfield(solvedSeedCandidate, 'gaitAbbr') && ~isempty(solvedSeedCandidate.gaitAbbr)
                gaitText = char(string(solvedSeedCandidate.gaitAbbr));
            else
                try
                    [~, gaitAbbr, ~, ~] = Gait_Identification(solvedSeedCandidate.X);
                    gaitText = char(string(gaitAbbr));
                catch
                    gaitText = 'n/a';
                end
            end
            solvedText = sprintf('Solved Solution Info:\nResidual: %s\nGait type: %s', residualText, gaitText);
        end
        SetTextLikeControl(solvedSolutionInfoLabel, solvedText);
    end

    function tf = ResidualFiniteAtSeed(Xguess, ParaGuess)
        tf = false;
        try
            residual = Quadrupedal_ZeroFun_v2(EventTimingRegulation(Xguess(:)), EnforcePositiveParameters(ParaGuess(:)), 'skipSolve');
            tf = all(isfinite(residual));
        catch
            tf = false;
        end
    end

    function [Xguess, ParaGuess, guessMode] = PrepareSeedSolveGuess(baseSeed, candidate)
        baseX = EventTimingRegulation(baseSeed.X(:));
        basePara = EnforcePositiveParameters(baseSeed.Para(:));
        Xguess = EventTimingRegulation(candidate.X(:));
        ParaGuess = EnforcePositiveParameters(candidate.Para(:));
        guessMode = "Predicted";

        if ResidualFiniteAtSeed(Xguess, ParaGuess)
            return;
        end

        guessMode = "Selected seed restart";
        ParaGuess = basePara;
        for attempt = 1:12
            Xtry = EventTimingRegulation(baseX + (rand - 0.5) * 0.02);
            if ResidualFiniteAtSeed(Xtry, ParaGuess)
                Xguess = Xtry;
                return;
            end
        end

        if ResidualFiniteAtSeed(baseX, basePara)
            Xguess = baseX;
            return;
        end

        error(['Objective function is undefined at the predicted seed and the selected seed. ' ...
            'Reduce the noise level or retune the seed entries.']);
    end

    function PlotPredictedSeedCandidate()
        candidate = BuildPredictedSeedCandidate();
        if isempty(candidate.X)
            return;
        end

        RemovePredictedSeedCandidate();
        predictedSeedCandidate = candidate;
        RefreshSingleSeedCandidateMarker('predicted');
        UpdateContinuationPreviewOrbit(candidate.X, candidate.Para, ...
            sprintf('Predicted seed: %s | %d', candidate.datasetName, candidate.index), [0.65 0.65 0.65]);
        SetStatus(sprintf('Plotted predicted seed guess from %s index %d.', candidate.datasetName, candidate.index));
    end

    function SolvePredictedSeedCandidate()
        UpdateSeedSolverOptions();
        candidate = BuildPredictedSeedCandidate();
        if isempty(candidate.X)
            return;
        end
        predictedSeedCandidate = candidate;
        RefreshSingleSeedCandidateMarker('predicted');

        setContinuationBusy(true);
        try
            baseSeed = ResolveSeedTabReference(true);
            if isempty(baseSeed)
                setContinuationBusy(false);
                return;
            end
            baseSeed = GetSeedEditorValues(baseSeed);
            solverSettings = GetSeedSolverSettingsSnapshot();
            [Xguess, ParaGuess, guessMode] = PrepareSeedSolveGuess(baseSeed, candidate);
            [xSolved, fSolved, exitflag, output] = fsolve(@(X) Quadrupedal_ZeroFun_v2(X, ParaGuess, 'skipSolve'), ...
                Xguess, seedSolveOPTS);
            xSolved = EventTimingRegulation(xSolved);
            if exitflag <= 0 || ~SolutionAcceptedGUI(fSolved, xSolved)
                error('The predicted seed did not converge to a valid periodic solution.');
            end

            try
                [gaitType, gaitAbbr, ~, ~] = Gait_Identification(xSolved);
            catch
                gaitType = "Unknown";
                gaitAbbr = "n/a";
            end

            seedInfo = struct('sourceMode', seedSourceMode, ...
                'datasetName', baseSeed.datasetName, ...
                'index', baseSeed.index, ...
                'X', baseSeed.X(:), ...
                'Para', baseSeed.Para(:));
            predictedInfo = struct('datasetName', candidate.datasetName, ...
                'index', candidate.index, ...
                'X', candidate.X(:), ...
                'Para', candidate.Para(:), ...
                'noiseApplied', norm(candidate.X(:) - baseSeed.X(:)) > 1e-10 || ...
                    norm(candidate.Para(:) - baseSeed.Para(:)) > 1e-10);

            if HasGraphicsHandle(solvedSeedCandidate.handle)
                delete(solvedSeedCandidate.handle);
            end
            if HasGraphicsHandle(solvedSeedCandidate.textHandle)
                delete(solvedSeedCandidate.textHandle);
            end
            solvedSeedCandidate = struct('datasetName', candidate.datasetName, ...
                'index', candidate.index, ...
                'X', xSolved(:), ...
                'Para', ParaGuess(:), ...
                'residualNorm', SafeResidualNormGUI(fSolved), ...
                'residualVector', fSolved(:), ...
                'gaitType', char(string(gaitType)), ...
                'gaitAbbr', char(string(gaitAbbr)), ...
                'seedInfo', seedInfo, ...
                'predictedInfo', predictedInfo, ...
                'solverSettings', solverSettings, ...
                'solverOutput', output, ...
                'exitflag', exitflag, ...
                'guessMode', char(string(guessMode)), ...
                'handle', gobjects(0), 'textHandle', gobjects(0));
            if strcmp(continuationSeedSourceMode, 'Solver')
                ClearContinuationSecondSeed(false);
                UpdateContinuationSeedSourceControls();
            end
            solvedText = UpdateSolvedSolutionDisplay();
            UpdateContinuationPreviewOrbit(xSolved, ParaGuess, ...
                sprintf('Solved seed: %s | %d', candidate.datasetName, candidate.index), [0 0 0]);
            SetStatus(solvedText);
        catch ME
            uialert(fig, ME.message, 'Seed Solve Error');
            SetStatus(['Seed solve failed: ' ME.message]);
        end
        setContinuationBusy(false);
    end

    function PlotSolvedSeedCandidate()
        if isempty(solvedSeedCandidate.X)
            uialert(fig, 'Solve for a solution first before plotting the solved result.', 'Solved Seed');
            return;
        end

        RefreshSingleSeedCandidateMarker('solved');
        UpdateContinuationPreviewOrbit(solvedSeedCandidate.X, solvedSeedCandidate.Para, ...
            sprintf('Solved seed: %s | %d', solvedSeedCandidate.datasetName, solvedSeedCandidate.index), [0 0 0]);
        SetStatus(sprintf('Plotted solved solution from %s index %d.', solvedSeedCandidate.datasetName, solvedSeedCandidate.index));
    end

    function SaveSolvedSeedSolution()
        if isempty(solvedSeedCandidate.X)
            uialert(fig, 'Solve for a solution first before saving the solved result.', 'Save Solved Solution');
            return;
        end

        datasetText = SafeFilenameComponent(solvedSeedCandidate.datasetName, 'seed');
        gaitText = SafeFilenameComponent(solvedSeedCandidate.gaitAbbr, 'NA');
        defaultFileName = sprintf('Solved_%s_%d_%s.mat', datasetText, solvedSeedCandidate.index, gaitText);
        [fileName, filePath] = uiputfile({'*.mat', 'MAT-files (*.mat)'}, ...
            'Save Solved Solution', fullfile(currentfolder, defaultFileName));
        if isequal(fileName, 0) || isequal(filePath, 0)
            SetStatus('Save solved solution cancelled.');
            return;
        end

        fullPath = fullfile(filePath, fileName);
        if isempty(regexpi(fullPath, '\.mat$'))
            fullPath = [fullPath, '.mat'];
        end

        results = [solvedSeedCandidate.X(:); solvedSeedCandidate.Para(:)]; %#ok<NASGU>
        solvedSolutionInfo = struct( ...
            'datasetName', solvedSeedCandidate.datasetName, ...
            'index', solvedSeedCandidate.index, ...
            'gaitType', solvedSeedCandidate.gaitType, ...
            'gaitAbbr', solvedSeedCandidate.gaitAbbr, ...
            'residualNorm', solvedSeedCandidate.residualNorm, ...
            'residualVector', solvedSeedCandidate.residualVector, ...
            'seedInfo', solvedSeedCandidate.seedInfo, ...
            'predictedInfo', solvedSeedCandidate.predictedInfo, ...
            'solverSettings', solvedSeedCandidate.solverSettings, ...
            'solverOutput', solvedSeedCandidate.solverOutput, ...
            'exitflag', solvedSeedCandidate.exitflag, ...
            'guessMode', solvedSeedCandidate.guessMode, ...
            'savedAt', datestr(now, 31)); %#ok<NASGU>
        save(fullPath, 'results', 'solvedSolutionInfo');
        SetStatus(['Saved solved solution to ' fullPath]);
    end

    function RefreshGeneratedSeedMarkers()
        for i = 1:numel(generatedSeedSolutions)
            [xCoord, yCoord, zCoord] = GetSolutionCoordinates(generatedSeedSolutions(i).X);
            if isgraphics(generatedSeedSolutions(i).handle)
                generatedSeedSolutions(i).handle.XData = xCoord;
                generatedSeedSolutions(i).handle.YData = yCoord;
                generatedSeedSolutions(i).handle.ZData = zCoord;
            else
                generatedSeedSolutions(i).handle = PlotGeneratedSeedMarker(generatedSeedSolutions(i));
            end
        end
    end

    function [xCoord, yCoord, zCoord] = GetSolutionCoordinates(solutionVector)
        [xIndex, yIndex, zIndex] = GetAxisIndices();
        xCoord = solutionVector(xIndex);
        yCoord = solutionVector(yIndex);
        zCoord = solutionVector(zIndex);
    end

    function UpdateAxisData()
        [xIndex, yIndex, zIndex] = GetAxisIndices();
        for i = 1:numel(plottedDatasets)
            data = plottedDatasets{i}.results;
            if ~isgraphics(plottedDatasets{i}.handle)
                continue;
            end
            plottedDatasets{i}.handle.XData = data(xIndex, :);
            plottedDatasets{i}.handle.YData = data(yIndex, :);
            plottedDatasets{i}.handle.ZData = data(zIndex, :);
        end

        RefreshTemporaryContinuationHandle(tempContinuationResults);
        RefreshGeneratedSeedMarkers();
        RefreshSeedManualSelectionVisualization();
        RefreshSeedCandidateMarkers();
        RefreshContinuationSeedPairPlot();
        RefreshSelectedSolutionVisualization();
        UpdatePredictionDistanceDisplay();

        ax.XLabel.String = axisOptions{xIndex};
        ax.YLabel.String = axisOptions{yIndex};
        ax.ZLabel.String = axisOptions{zIndex};
        ax.XLabel.Interpreter = 'latex';
        ax.YLabel.Interpreter = 'latex';
        ax.ZLabel.Interpreter = 'latex';
        ax.XLabel.FontSize = 15;
        ax.YLabel.FontSize = 15;
        ax.ZLabel.FontSize = 15;
    end

    function SetDefaultVaryingParameter()
        if isempty(parameterValues)
            varyingparameterDropdown.Items = {'<none>'};
            varyingparameterDropdown.Value = '<none>';
            varyingparameterValuesDropdown.Items = {'<none>'};
            varyingparameterValuesDropdown.Value = '<none>';
            PopulateNonVaryingDropdowns();
            UpdateParameterOperationLabels();
            return;
        end

        isVarying = false(1, size(parameterValues, 1));
        for i = 1:size(parameterValues, 1)
            isVarying(i) = any(abs(parameterValues(i, :) - parameterValues(i, 1)) > 1e-12);
        end

        varyingItems = parameteroptions(isVarying);
        if isempty(varyingItems)
            varyingparameterDropdown.Items = {'<none>'};
            varyingparameterDropdown.Value = '<none>';
            varyingparameterValuesDropdown.Items = {'<none>'};
            varyingparameterValuesDropdown.Value = '<none>';
            if isgraphics(colorbarHandle)
                delete(colorbarHandle);
            end
            colorbarHandle = [];
            varyingParameterSortedValues = [];
            brightnessValues = [];
        else
            previousValue = varyingparameterDropdown.Value;
            varyingparameterDropdown.Items = varyingItems;
            if any(strcmp(varyingItems, previousValue))
                varyingparameterDropdown.Value = previousValue;
            else
                varyingparameterDropdown.Value = varyingItems{1};
            end
            UpdateParameterValues();
        end

        PopulateNonVaryingDropdowns();
        UpdateParameterOperationLabels();
    end

    function localParameterValues = GetParameterValues()
        matFiles = dir(fullfile(currentfolder, '*.mat'));
        validParameterValues = [];
        for i = 1:numel(matFiles)
            try
                data = load(fullfile(currentfolder, matFiles(i).name), 'results');
                if isfield(data, 'results') && size(data.results, 1) >= 29
                    validParameterValues = [validParameterValues, data.results(23:29, 1)]; %#ok<AGROW>
                end
            catch
            end
        end
        if isempty(validParameterValues)
            localParameterValues = [];
        else
            localParameterValues = validParameterValues;
        end
    end

    function UpdateParameterValues()
        parameterValues = GetParameterValues();
        selectedParamIndex = ParameterDisplayToIndex(varyingparameterDropdown.Value);
        if isempty(selectedParamIndex) || isempty(parameterValues)
            varyingparameterValuesDropdown.Items = {'<none>'};
            varyingparameterValuesDropdown.Value = '<none>';
            varyingParameterSortedValues = [];
            brightnessValues = [];
            if isgraphics(colorbarHandle)
                delete(colorbarHandle);
            end
            colorbarHandle = [];
            PopulateNonVaryingDropdowns();
            UpdateParameterOperationLabels();
            return;
        end

        parameterRowValues = parameterValues(selectedParamIndex, :);
        varyingParameterSortedValues = unique(sort(parameterRowValues));
        parameterIndex = 1:numel(varyingParameterSortedValues);

        medianIdx = max(1, ceil(numel(varyingParameterSortedValues) / 2));
        medianValue = varyingParameterSortedValues(medianIdx);
        medianColor = [0 0.4470 0.7410];
        matFiles = dir(fullfile(currentfolder, '*.mat'));
        for i = 1:numel(matFiles)
            try
                data = load(fullfile(currentfolder, matFiles(i).name), 'results');
                if isfield(data, 'results') && abs(data.results(22 + selectedParamIndex, 1) - medianValue) <= max(1e-8, 1e-6 * max(1, abs(medianValue)))
                    [~, ~, medianColor, ~] = Gait_Identification(data.results);
                    break;
                end
            catch
            end
        end

        maxColor = max(medianColor);
        if maxColor <= 0
            maxColor = 1;
        end
        maxBrightness = 1 / maxColor;
        minBrightness = min(1, 1 / maxBrightness);
        if numel(varyingParameterSortedValues) == 1
            brightnessValues = 1;
        else
            brightnessValues = flip(linspace(minBrightness, maxBrightness, numel(varyingParameterSortedValues)));
        end

        varyingparameterValuesDropdown.Items = arrayfun(@(x) num2str(x), varyingParameterSortedValues, 'UniformOutput', false);
        varyingparameterValuesDropdown.Value = varyingparameterValuesDropdown.Items{1};

        customColormap = min(1, brightnessValues(:) * medianColor);
        if isempty(colorbarHandle) || ~isgraphics(colorbarHandle)
            colorbarHandle = colorbar(ax);
        end
        colormap(ax, customColormap);
        if numel(varyingParameterSortedValues) == 1
            caxis(ax, [varyingParameterSortedValues(1) - 0.5, varyingParameterSortedValues(1) + 0.5]);
        else
            caxis(ax, [min(varyingParameterSortedValues), max(varyingParameterSortedValues)]);
        end
        colorbarHandle.Label.String = varyingparameterDropdown.Value;
        colorbarHandle.Label.Interpreter = 'latex';
        colorbarHandle.Label.FontSize = 15;
        PositionColorbar();

        PopulateNonVaryingDropdowns();
        UpdateAxisData();
        UpdateParameterOperationLabels();
    end

    function PopulateNonVaryingDropdowns()
        if isempty(parameterValues)
            nonVaryingParams = {};
        else
            isVarying = false(1, size(parameterValues, 1));
            for i = 1:size(parameterValues, 1)
                isVarying(i) = any(abs(parameterValues(i, :) - parameterValues(i, 1)) > 1e-12);
            end
            nonVaryingParams = parameteroptions(~isVarying);
        end
        if isempty(nonVaryingParams)
            fixedparameterDropdown.Items = {'<none>'};
            fixedparameterDropdown.Value = '<none>';
            fixedparametervalueDropdown.Items = {'<none>'};
            fixedparametervalueDropdown.Value = '<none>';
            return;
        end
        fixedparameterDropdown.Items = nonVaryingParams;
        if ~any(strcmp(nonVaryingParams, fixedparameterDropdown.Value))
            fixedparameterDropdown.Value = nonVaryingParams{1};
        end
        UpdateFixedParameterValues();
    end

    function UpdateFixedParameterValues()
        selectedParam = fixedparameterDropdown.Value;
        paramIdx = ParameterDisplayToIndex(selectedParam);
        if isempty(paramIdx) || isempty(parameterValues)
            fixedparametervalueDropdown.Items = {'<none>'};
            fixedparametervalueDropdown.Value = '<none>';
            return;
        end
        fixedParamValues = unique(parameterValues(paramIdx, :));
        fixedparametervalueDropdown.Items = arrayfun(@(x) num2str(x), fixedParamValues, 'UniformOutput', false);
        fixedparametervalueDropdown.Value = fixedparametervalueDropdown.Items{1};
    end

    function SyncVaryingValueDropdown(selectedResults)
        selectedParam = varyingparameterDropdown.Value;
        if isempty(selectedResults) || isempty(selectedParam) || strcmp(selectedParam, '<none>')
            return;
        end

        paramIdx = ParameterDisplayToIndex(selectedParam);
        if isempty(paramIdx)
            return;
        end

        selectedValue = num2str(selectedResults(paramIdx + 22, 1));
        if any(strcmp(varyingparameterValuesDropdown.Items, selectedValue))
            varyingparameterValuesDropdown.Value = selectedValue;
        end
    end

    function SelectDatasetFromParameter()
        selectedValue = varyingparameterValuesDropdown.Value;
        paramIdx = ParameterDisplayToIndex(varyingparameterDropdown.Value);
        if isempty(paramIdx) || strcmp(selectedValue, '<none>')
            return;
        end

        targetValue = str2double(selectedValue);
        tolerance = max(1e-8, 1e-6 * max(1, abs(targetValue)));

        for i = 1:numel(plottedDatasets)
            if abs(plottedDatasets{i}.results(22 + paramIdx, 1) - targetValue) <= tolerance
                ActivateDatasetSelection(plottedDatasets{i}.filename);
                SetStatus(['Selected plotted branch for ' ParameterDisplayToKey(varyingparameterDropdown.Value) ' = ' num2str(targetValue)]);
                return;
            end
        end

        matFiles = dir(fullfile(currentfolder, '*.mat'));
        for i = 1:numel(matFiles)
            try
                data = load(fullfile(currentfolder, matFiles(i).name), 'results');
                if isfield(data, 'results') && abs(data.results(22 + paramIdx, 1) - targetValue) <= tolerance
                    datasetDropdown.Value = matFiles(i).name;
                    PlotDatasetByName(matFiles(i).name);
                    SetStatus(['Loaded branch for ' ParameterDisplayToKey(varyingparameterDropdown.Value) ' = ' num2str(targetValue)]);
                    return;
                end
            catch
            end
        end

        SetStatus('No branch in the current folder matches the selected parameter value.');
    end
    function RefreshSeedContextLabel()
        if strcmp(seedSourceMode, 'Cursor')
            if isempty(cursorSelection.results)
                contextText = 'Cursor source: click a branch point to choose the active seed.';
            else
                [idx1, idx2] = ResolveContinuationIndices(cursorSelection.index, size(cursorSelection.results, 2));
                if isempty(idx1)
                    contextText = sprintf('Cursor source: %s | index %d | branch has only one point', ...
                        cursorSelection.datasetName, cursorSelection.index);
                else
                    contextText = sprintf('Cursor source: %s | index %d | continuation pair [%d, %d]', ...
                        cursorSelection.datasetName, cursorSelection.index, idx1, idx2);
                end
            end
        else
            dataset = GetActiveOperationDataset();
            if isempty(dataset)
                contextText = 'Index source: select a plotted dataset, then enter one seed index.';
            else
                pointCount = size(dataset.results, 2);
                idx = max(1, min(pointCount, round(seedManualIndex)));
                if seedManualIndex ~= idx
                    seedManualIndex = idx;
                end
                [idx1, idx2] = ResolveContinuationIndices(idx, pointCount);
                if isempty(idx1)
                    contextText = sprintf('Index source: %s | branch has only one point', dataset.filename);
                else
                    contextText = sprintf('Index source: %s | index %d | continuation pair [%d, %d]', ...
                        dataset.filename, idx, idx1, idx2);
                end
            end
        end

        for i = 1:numel(seedContextLabels)
            if isgraphics(seedContextLabels(i))
                seedContextLabels(i).Text = contextText;
            end
        end

        for i = 1:numel(seedIndexInputs)
            if isgraphics(seedIndexInputs(i))
                seedIndexInputs(i).Value = seedManualIndex;
            end
        end

        RefreshSelectedCursorSummary();
        RefreshSeedManualSelectionVisualization();
        UpdateNoiseApplicationDisplay();
        PopulateSeedEditorTables();
    end

    function UpdateParameterOperationLabels()
        parameterPara = [];
        parameterContextName = '';
        parameterSeed = ResolveContinuationFirstSeed(false);
        if ~isempty(parameterSeed)
            parameterPara = parameterSeed.Para;
            parameterContextName = parameterSeed.datasetName;
        end

        paramIdx = ParameterDisplayToIndex(parameterVaryingDropdown.Value);
        if ~isempty(parameterPara) && ~isempty(paramIdx)
            currentParameterValueLabel.Text = sprintf('Current value (%s): %.6g', ...
                parameterContextName, parameterPara(paramIdx));
        else
            currentParameterValueLabel.Text = 'Current value: n/a';
        end

        scanPara = [];
        scanContextName = '';
        scanSeed = ResolveContinuationFirstSeed(false);
        if ~isempty(scanSeed)
            scanPara = scanSeed.Para;
            scanContextName = scanSeed.datasetName;
        else
            scanDataset = GetActiveOperationDataset();
            if ~isempty(scanDataset)
                scanPara = DatasetParameterAtIndex(scanDataset.results, 1);
                scanContextName = scanDataset.filename;
            end
        end

        scanIdx = ParameterDisplayToIndex(parameterScanDropdown.Value);
        if ~isempty(scanPara) && ~isempty(scanIdx)
            loadedScanValue = scanPara(scanIdx);
            currentScanValueLabel.Text = sprintf('Current value (%s): %.6g', ...
                scanContextName, loadedScanValue);
            scanDefaultSignature = sprintf('%s|%d|%.17g', ...
                scanContextName, scanIdx, loadedScanValue);
            if ~strcmp(scanDefaultSignature, scanValuesDefaultSignature)
                defaultScanValues = loadedScanValue .* [0.8, 0.9, 1.0, 1.1, 1.2];
                scanValuesInput.Value = {strtrim(sprintf('%.12g ', defaultScanValues))};
                scanValuesDefaultSignature = scanDefaultSignature;
            end
        else
            currentScanValueLabel.Text = 'Current value: n/a';
            scanValuesDefaultSignature = '';
        end
        UpdateParameterResultNameSuggestion(parameterContextName);
    end

    function ParameterVaryingConfigurationChanged()
        parameterResultNameWasEdited = false;
        UpdateParameterOperationLabels();
    end

    function ParameterResultNameEdited()
        if ~isgraphics(parameterResultNameInput)
            return;
        end
        parameterResultNameWasEdited = ~isempty(strtrim(char(string(parameterResultNameInput.Value))));
        if ~parameterResultNameWasEdited
            UpdateParameterOperationLabels();
        end
    end

    function UpdateParameterResultNameSuggestion(datasetName)
        if ~isgraphics(parameterResultNameInput)
            return;
        end

        if isempty(strtrim(char(string(datasetName))))
            datasetBase = 'ParameterVarying';
        else
            [~, datasetBase] = fileparts(char(string(datasetName)));
        end
        parameterKey = ParameterDisplayToKey(parameterVaryingDropdown.Value);
        targetToken = ParameterFilenameValueToken(targetParameterInput.Value);
        suggestedName = SafeFilenameComponent( ...
            sprintf('%s_%s_%s', datasetBase, parameterKey, targetToken), ...
            'ParameterVarying');

        currentName = strtrim(char(string(parameterResultNameInput.Value)));
        if ~parameterResultNameWasEdited || isempty(currentName) || ...
                strcmp(currentName, parameterResultSuggestedName)
            parameterResultNameInput.Value = suggestedName;
            parameterResultNameWasEdited = false;
        end
        parameterResultSuggestedName = suggestedName;
    end

    function token = ParameterFilenameValueToken(value)
        if ~(isnumeric(value) && isscalar(value) && isfinite(value))
            token = 'target';
            return;
        end
        token = sprintf('%.12g', value);
        token = strrep(token, '+', '');
        token = strrep(token, '-', 'm');
        token = strrep(token, '.', 'p');
    end

    function dataset = GetActiveOperationDataset()
        dataset = [];
        selectedName = datasetListBox.Value;
        if ~isempty(selectedName) && ~strcmp(selectedName, '<None>')
            idx = FindPlottedDatasetByName(selectedName);
            if ~isempty(idx)
                dataset = plottedDatasets{idx};
                return;
            end
        end

        if ~isempty(selectedDatasetHandle)
            idx = FindPlottedDatasetByName(selectedDatasetHandle);
            if ~isempty(idx)
                dataset = plottedDatasets{idx};
                return;
            end
        end

        if ~isempty(cursorSelection.datasetName)
            idx = FindPlottedDatasetByName(cursorSelection.datasetName);
            if ~isempty(idx)
                dataset = plottedDatasets{idx};
                return;
            end
        end

    end

    function seed = ResolveSingleSeed()
        seed = ResolveSeedReference(true);
        if isempty(seed)
            return;
        end
        seed = GetSeedEditorValues(seed);
    end

    function seed = ResolveContinuationFirstSeed(showAlert)
        if nargin < 1
            showAlert = true;
        end

        seed = [];
        switch continuationSeedSourceMode
            case 'Cursor'
                if isempty(cursorSelection.results)
                    if showAlert
                        uialert(fig, 'Click a branch point before using cursor-based continuation seeding.', 'Continuation Seed Selection');
                    end
                    return;
                end
                seed = struct('datasetName', cursorSelection.datasetName, ...
                    'sourceMode', continuationSeedSourceMode, ...
                    'index', cursorSelection.index, ...
                    'percent', [], ...
                    'X', cursorSelection.X(:), ...
                    'Para', cursorSelection.Para(:), ...
                    'results', cursorSelection.results);

            case 'Index input'
                dataset = GetActiveOperationDataset();
                if isempty(dataset)
                    if showAlert
                        uialert(fig, 'Select a plotted dataset before using manual index input for continuation.', 'Continuation Seed Selection');
                    end
                    return;
                end
                nPts = size(dataset.results, 2);
                idx = max(1, min(nPts, round(continuationSeedManualIndex)));
                continuationSeedManualIndex = idx;
                seed = struct('datasetName', dataset.filename, ...
                    'sourceMode', continuationSeedSourceMode, ...
                    'index', idx, ...
                    'percent', [], ...
                    'X', dataset.results(1:22, idx), ...
                    'Para', DatasetParameterAtIndex(dataset.results, idx), ...
                    'results', dataset.results);

            case 'Percentage input'
                dataset = GetActiveOperationDataset();
                if isempty(dataset)
                    if showAlert
                        uialert(fig, 'Select a plotted dataset before using percentage input for continuation.', 'Continuation Seed Selection');
                    end
                    return;
                end
                nPts = size(dataset.results, 2);
                pct = max(0, min(100, continuationSeedPercentValue));
                continuationSeedPercentValue = pct;
                idx = ContinuationPercentageToIndex(pct, nPts);
                seed = struct('datasetName', dataset.filename, ...
                    'sourceMode', continuationSeedSourceMode, ...
                    'index', idx, ...
                    'percent', pct, ...
                    'X', dataset.results(1:22, idx), ...
                    'Para', DatasetParameterAtIndex(dataset.results, idx), ...
                    'results', dataset.results);

            otherwise
                if isempty(solvedSeedCandidate.X)
                    if showAlert
                        uialert(fig, 'Solve a solution in the Solve tab before using Solver as the continuation seed source.', 'Continuation Seed Selection');
                    end
                    return;
                end
                if isempty(solvedSeedCandidate.datasetName)
                    datasetName = 'Solved solution';
                else
                    datasetName = solvedSeedCandidate.datasetName;
                end
                seed = struct('datasetName', datasetName, ...
                    'sourceMode', continuationSeedSourceMode, ...
                    'index', solvedSeedCandidate.index, ...
                    'percent', [], ...
                    'X', solvedSeedCandidate.X(:), ...
                    'Para', solvedSeedCandidate.Para(:), ...
                    'results', []);
        end
    end

    function Para = DatasetParameterAtIndex(datasetResults, idx)
        if size(datasetResults, 1) <= 22
            Para = [];
            return;
        end
        idx = max(1, min(size(datasetResults, 2), round(idx)));
        Para = datasetResults(23:end, idx);
        if isempty(Para)
            Para = datasetResults(23:end, 1);
        end
    end

    function idx = ContinuationPercentageToIndex(percentValue, pointCount)
        if pointCount < 1
            idx = [];
            return;
        end
        idx = round(pointCount * max(0, min(100, percentValue)) / 100);
        idx = max(1, min(pointCount, idx));
    end

    function RefreshContinuationSeedContextLabel()
        contextLabels = [continuationSeedContextLabel, ...
            parameterContinuationSeedContextLabel, ...
            scanContinuationSeedContextLabel];
        if ~any(isgraphics(contextLabels))
            return;
        end

        seed = ResolveContinuationFirstSeed(false);
        if isempty(seed)
            switch continuationSeedSourceMode
                case 'Cursor'
                    contextText = 'Cursor source: click a branch point to choose seed 1.';
                case 'Index input'
                    contextText = 'Index source: select a plotted dataset and enter seed 1 index.';
                case 'Percentage input'
                    contextText = 'Percentage source: select a plotted dataset and enter branch percentage for seed 1.';
                otherwise
                    contextText = 'Solver source: solve a solution in the Solve tab first.';
            end
        else
            if isempty(seed.index)
                indexText = 'n/a';
            else
                indexText = sprintf('%d', seed.index);
            end
            if isempty(seed.percent)
                percentText = '';
            else
                percentText = sprintf(' | %.3g%%', seed.percent);
            end
            if ContinuationSecondSeedIsCurrent(seed, GetContinuationRadius())
                pairText = sprintf(' | seed 2 solved, distance %.6g', continuationSecondSeed.distance);
            else
                pairText = ' | seed 2 not solved';
            end
            contextText = sprintf('%s source: %s | index %s%s | seed 1 dx %.6g%s', ...
                continuationSeedSourceMode, seed.datasetName, indexText, percentText, seed.X(1), pairText);
        end

        for iControl = 1:numel(contextLabels)
            if isgraphics(contextLabels(iControl))
                contextLabels(iControl).Text = contextText;
            end
        end
    end

    function isCurrent = ContinuationSecondSeedIsCurrent(seed, radiusValue)
        isCurrent = false;
        if isempty(seed) || isempty(continuationSecondSeed.X1) || isempty(continuationSecondSeed.X2)
            return;
        end
        if numel(continuationSecondSeed.Para) ~= numel(seed.Para)
            return;
        end

        tolerance = 1e-9;
        isCurrent = strcmp(continuationSecondSeed.sourceMode, seed.sourceMode) && ...
            strcmp(continuationSecondSeed.datasetName, seed.datasetName) && ...
            isequaln(continuationSecondSeed.index, seed.index) && ...
            abs(continuationSecondSeed.radius - radiusValue) <= max(1e-10, tolerance * max(1, radiusValue)) && ...
            norm(continuationSecondSeed.X1(:) - seed.X(:)) <= 1e-8 && ...
            norm(continuationSecondSeed.Para(:) - seed.Para(:)) <= 1e-8;
    end

    function distanceValue = ContinuationStateDistance(XA, XB)
        distanceValue = norm(XB(1:13) - XA(1:13));
    end

    function gaitInfo = IdentifyContinuationSeedGait(X)
        gaitInfo = struct('valid', false, 'type', 'Unknown', 'abbr', 'Unknown', 'reason', 'unknown gait');
        try
            regulatedX = EventTimingRegulation(X(:));
            [gaitType, gaitAbbr, ~, ~] = Gait_Identification(regulatedX);
            gaitInfo.type = strtrim(char(string(gaitType)));
            gaitInfo.abbr = strtrim(char(string(gaitAbbr)));
            invalidValues = {'', 'unknown', 'n/a', 'na'};
            gaitInfo.valid = ~any(strcmpi(gaitInfo.type, invalidValues)) && ...
                ~any(strcmpi(gaitInfo.abbr, invalidValues));
            if gaitInfo.valid
                gaitInfo.reason = '';
            else
                gaitInfo.reason = sprintf('classifier returned %s', ContinuationGaitInfoText(gaitInfo));
            end
        catch ME
            gaitInfo.reason = strrep(ME.message, sprintf('\n'), ' | ');
        end
    end

    function matches = ContinuationGaitInfoMatches(gait1, gait2)
        matches = gait1.valid && gait2.valid && ...
            strcmpi(gait1.type, gait2.type) && strcmpi(gait1.abbr, gait2.abbr);
    end

    function gaitText = ContinuationGaitInfoText(gaitInfo)
        gaitText = sprintf('%s (%s)', gaitInfo.abbr, gaitInfo.type);
    end

    function [matches, gait1, gait2] = ContinuationSeedGaitsMatch(X1, X2)
        gait1 = IdentifyContinuationSeedGait(X1);
        gait2 = IdentifyContinuationSeedGait(X2);
        matches = ContinuationGaitInfoMatches(gait1, gait2);
    end

    function solved = SolveContinuationSecondSeed(showAlert)
        if nargin < 1
            showAlert = true;
        end
        solved = false;
        if continuationBusy
            return;
        end

        seed = ResolveContinuationFirstSeed(showAlert);
        if isempty(seed)
            return;
        end
        if isempty(seed.Para)
            if showAlert
                uialert(fig, 'The selected seed does not include parameter values.', 'Second Seed Solver');
            end
            return;
        end

        radiusValue = GetContinuationRadius();
        ClearContinuationSecondSeed(false);
        SetStatus(sprintf('Second seed solver starting.\nSeed 1: %s index %s\nTarget state distance: %.6g', ...
            seed.datasetName, ContinuationIndexText(seed.index), radiusValue));

        setContinuationBusy(true);
        try
            solverOPTS = optimset(numOPTS, 'Display', 'off', 'TolFun', 1e-12, 'TolX', 1e-12);
            [xSecond, solveInfo] = FindContinuationSecondSeedAtStateRadius(seed, radiusValue, solverOPTS);
            if solveInfo.periodicResidualNorm >= 1e-9
                error('Second seed periodic residual %.3e is not below 1e-9.', solveInfo.periodicResidualNorm);
            end

            continuationSecondSeed = struct('datasetName', seed.datasetName, ...
                'sourceMode', seed.sourceMode, ...
                'index', seed.index, ...
                'percent', seed.percent, ...
                'X1', seed.X(:), ...
                'X2', xSecond(:), ...
                'Para', seed.Para(:), ...
                'radius', radiusValue, ...
                'residualNorm', solveInfo.periodicResidualNorm, ...
                'distance', solveInfo.distance, ...
                'distanceError', solveInfo.distanceError, ...
                'seed1GaitType', solveInfo.seed1GaitType, ...
                'seed1GaitAbbr', solveInfo.seed1GaitAbbr, ...
                'gaitType', solveInfo.seed2GaitType, ...
                'gaitAbbr', solveInfo.seed2GaitAbbr, ...
                'exitflag', solveInfo.exitflag, ...
                'solverOutput', solveInfo.output, ...
                'solverAttempt', solveInfo.attemptName, ...
                'seed1Handle', gobjects(0), ...
                'seed2Handle', gobjects(0), ...
                'seed1TextHandle', gobjects(0), ...
                'seed2TextHandle', gobjects(0));
            solved = true;
            SetStatus(FormatContinuationSecondSeedStatus('success'));
        catch ME
            continuationSecondSeed = MakeEmptyContinuationSecondSeed();
            if showAlert
                uialert(fig, ME.message, 'Second Seed Solver');
            end
            SetStatus(sprintf('Second seed solver failed.\nSeed 1: %s index %s\nReason: %s', ...
                seed.datasetName, ContinuationIndexText(seed.index), ME.message));
        end
        setContinuationBusy(false);
        RefreshContinuationSeedContextLabel();
    end

    function [xSecond, solveInfo] = FindContinuationSecondSeedAtStateRadius( ...
            seed, radiusValue, solverOPTS, preferredSecondSeed, solverLabel, localDirectionsOnly)
        if nargin < 4
            preferredSecondSeed = [];
        end
        if nargin < 5 || isempty(solverLabel)
            solverLabel = 'Second seed solver';
        end
        if nargin < 6
            localDirectionsOnly = false;
        end

        seed1Gait = IdentifyContinuationSeedGait(seed.X);
        if ~seed1Gait.valid
            error('Seed 1 gait could not be identified: %s', seed1Gait.reason);
        end

        guesses = BuildContinuationSecondSeedGuesses( ...
            seed, radiusValue, preferredSecondSeed, localDirectionsOnly);
        if isempty(guesses)
            error('No second-seed guesses could be generated.');
        end

        rollbackFactors = [1, 0.75, 0.5, 0.25];
        distanceTolerance = max(1e-7, 1e-4 * radiusValue);
        bestResidual = Inf;
        bestDistanceError = Inf;
        bestMessage = '';

        for guessIdx = 1:numel(guesses)
            baseGuess = guesses(guessIdx);
            for factorIdx = 1:numel(rollbackFactors)
                rollbackFactor = rollbackFactors(factorIdx);
                guess = BuildContinuationSecondSeedGuess(seed.X, baseGuess.direction, ...
                    baseGuess.timingSource, radiusValue, rollbackFactor);
                if rollbackFactor < 1
                    SetStatus(sprintf(['%s rollback triggered.\n' ...
                        'Attempt: %s\nRollback factor: %.2f\nTarget state distance: %.6g'], ...
                        solverLabel, baseGuess.name, rollbackFactor, radiusValue));
                else
                    SetStatus(sprintf(['%s in progress.\n' ...
                        'Attempt: %s\nTarget state distance: %.6g'], ...
                        solverLabel, baseGuess.name, radiusValue));
                end

                try
                    [xTry, ~, exitflag, output] = fsolve(@SecondSeedResidual, guess, solverOPTS);
                    xTry = EventTimingRegulation(xTry(:));
                    periodicResidual = Quadrupedal_ZeroFun_v2(xTry, seed.Para, 'skipSolve');
                    periodicResidualNorm = SafeResidualNormGUI(periodicResidual);
                    distanceValue = ContinuationStateDistance(seed.X, xTry);
                    distanceError = abs(distanceValue - radiusValue);
                    if periodicResidualNorm < bestResidual || ...
                            (abs(periodicResidualNorm - bestResidual) < eps && distanceError < bestDistanceError)
                        bestResidual = periodicResidualNorm;
                        bestDistanceError = distanceError;
                        bestMessage = sprintf('best residual %.3e, best distance error %.3e', bestResidual, bestDistanceError);
                    end

                    if exitflag > 0 && periodicResidualNorm < 1e-9 && distanceError <= distanceTolerance
                        seed2Gait = IdentifyContinuationSeedGait(xTry);
                        if ~ContinuationGaitInfoMatches(seed1Gait, seed2Gait)
                            bestMessage = sprintf('gait mismatch: seed 1 %s, candidate %s', ...
                                ContinuationGaitInfoText(seed1Gait), ContinuationGaitInfoText(seed2Gait));
                            continue;
                        end
                        xSecond = xTry;
                        solveInfo = struct('periodicResidualNorm', periodicResidualNorm, ...
                            'distance', distanceValue, ...
                            'distanceError', distanceError, ...
                            'seed1GaitType', seed1Gait.type, ...
                            'seed1GaitAbbr', seed1Gait.abbr, ...
                            'seed2GaitType', seed2Gait.type, ...
                            'seed2GaitAbbr', seed2Gait.abbr, ...
                            'exitflag', exitflag, ...
                            'output', output, ...
                            'attemptName', baseGuess.name);
                        return;
                    end
                catch solverException
                    bestMessage = strrep(solverException.message, sprintf('\n'), ' | ');
                end
            end
        end

        if isempty(bestMessage)
            bestMessage = 'no valid candidate was found';
        end
        error('Could not find a valid second seed at radius %.6g (%s).', radiusValue, bestMessage);

        function residual = SecondSeedResidual(X)
            dynamicsResidual = Quadrupedal_ZeroFun_v2(X, seed.Para, 'skipSolve');
            distanceResidual = (ContinuationStateDistance(seed.X, X(:)) - radiusValue) / max(radiusValue, 1e-9);
            residual = [dynamicsResidual(:); distanceResidual];
        end
    end

    function guesses = BuildContinuationSecondSeedGuesses( ...
            seed, radiusValue, preferredSecondSeed, localDirectionsOnly)
        if nargin < 3
            preferredSecondSeed = [];
        end
        if nargin < 4
            localDirectionsOnly = false;
        end
        guesses = struct('name', {}, 'direction', {}, 'timingSource', {});
        baseX = EventTimingRegulation(seed.X(:));

        if numel(preferredSecondSeed) >= 22
            preferredX = EventTimingRegulation(preferredSecondSeed(:));
            direction = NormalizeContinuationStateDirection(preferredX(1:13) - baseX(1:13));
            if ~isempty(direction)
                guesses(end + 1) = struct('name', 'transported seed pair', ...
                    'direction', direction, ...
                    'timingSource', preferredX);
            end
        end

        if ~isempty(seed.results) && size(seed.results, 2) >= 2 && ~isempty(seed.index)
            pointCount = size(seed.results, 2);
            neighborOrder = unique([min(pointCount, seed.index + 1), max(1, seed.index - 1)], 'stable');
            for iNeighbor = 1:numel(neighborOrder)
                neighborIdx = neighborOrder(iNeighbor);
                if neighborIdx == seed.index
                    continue;
                end
                neighborX = EventTimingRegulation(seed.results(1:22, neighborIdx));
                direction = NormalizeContinuationStateDirection(neighborX(1:13) - baseX(1:13));
                if ~isempty(direction)
                    guesses(end + 1) = struct('name', sprintf('branch neighbor %d', neighborIdx), ... %#ok<AGROW>
                        'direction', direction, ...
                        'timingSource', neighborX);
                    guesses(end + 1) = struct('name', sprintf('opposite branch neighbor %d', neighborIdx), ... %#ok<AGROW>
                        'direction', -direction, ...
                        'timingSource', baseX);
                end
            end
        end

        if localDirectionsOnly
            return;
        end

        preferredStateDirections = [1, 2, 3, 5, 6, 8, 10, 12];
        for iDir = 1:numel(preferredStateDirections)
            direction = zeros(13, 1);
            direction(preferredStateDirections(iDir)) = 1;
            guesses(end + 1) = struct('name', sprintf('state %d positive', preferredStateDirections(iDir)), ... %#ok<AGROW>
                'direction', direction, ...
                'timingSource', baseX);
            guesses(end + 1) = struct('name', sprintf('state %d negative', preferredStateDirections(iDir)), ... %#ok<AGROW>
                'direction', -direction, ...
                'timingSource', baseX);
        end

        for iRandom = 1:8
            direction = NormalizeContinuationStateDirection(randn(13, 1));
            guesses(end + 1) = struct('name', sprintf('random direction %d', iRandom), ... %#ok<AGROW>
                'direction', direction, ...
                'timingSource', baseX);
        end

        if isempty(guesses) && radiusValue > 0
            direction = zeros(13, 1);
            direction(1) = 1;
            guesses = struct('name', 'fallback x velocity', 'direction', direction, 'timingSource', baseX);
        end
    end

    function direction = NormalizeContinuationStateDirection(directionIn)
        direction = directionIn(:);
        normValue = norm(direction);
        if normValue < 1e-12 || ~isfinite(normValue)
            direction = [];
            return;
        end
        direction = direction / normValue;
    end

    function guess = BuildContinuationSecondSeedGuess(seedX, stateDirection, timingSource, radiusValue, rollbackFactor)
        guess = EventTimingRegulation(seedX(:));
        timingSource = EventTimingRegulation(timingSource(:));
        guess(1:13) = seedX(1:13) + rollbackFactor * radiusValue * stateDirection(:);
        guess(14:22) = timingSource(14:22);
        guess = EventTimingRegulation(guess);
    end

    function textOut = ContinuationIndexText(indexValue)
        if isempty(indexValue) || ~isfinite(indexValue)
            textOut = 'n/a';
        else
            textOut = sprintf('%d', round(indexValue));
        end
    end

    function statusText = FormatContinuationSecondSeedStatus(statusKind)
        if strcmp(statusKind, 'success')
            statusText = sprintf(['Second seed solver succeeded.\n' ...
                'Seed 1: %s index %s\n' ...
                'Residual: %.3e\n' ...
                'Gait type: %s (matched)\n' ...
                'x velocity: %.6g\n' ...
                'Distance from seed 1: %.6g'], ...
                continuationSecondSeed.datasetName, ...
                ContinuationIndexText(continuationSecondSeed.index), ...
                continuationSecondSeed.residualNorm, ...
                ContinuationGaitText(continuationSecondSeed), ...
                continuationSecondSeed.X2(1), ...
                continuationSecondSeed.distance);
        else
            statusText = 'Second seed solver status unavailable.';
        end
    end

    function gaitText = ContinuationGaitText(seedStruct)
        if ~isempty(seedStruct.gaitAbbr) && ~strcmpi(seedStruct.gaitAbbr, 'n/a')
            gaitText = char(string(seedStruct.gaitAbbr));
        elseif ~isempty(seedStruct.gaitType)
            gaitText = char(string(seedStruct.gaitType));
        else
            gaitText = 'n/a';
        end
    end

    function ClearContinuationSecondSeed(showStatus)
        if nargin < 1
            showStatus = true;
        end
        RemoveContinuationSeedPairPlot();
        continuationSecondSeed = MakeEmptyContinuationSecondSeed();
        if showStatus
            SetStatus('Cleared the solved continuation second seed.');
        end
        RefreshContinuationSeedContextLabel();
    end

    function RemoveContinuationSeedPairPlot()
        handlesToDelete = [continuationSecondSeed.seed1Handle, continuationSecondSeed.seed2Handle, ...
            continuationSecondSeed.seed1TextHandle, continuationSecondSeed.seed2TextHandle];
        for iHandle = 1:numel(handlesToDelete)
            if isgraphics(handlesToDelete(iHandle))
                delete(handlesToDelete(iHandle));
            end
        end
        continuationSecondSeed.seed1Handle = gobjects(0);
        continuationSecondSeed.seed2Handle = gobjects(0);
        continuationSecondSeed.seed1TextHandle = gobjects(0);
        continuationSecondSeed.seed2TextHandle = gobjects(0);
    end

    function PlotContinuationSeedPair()
        seed = ResolveContinuationFirstSeed(true);
        if isempty(seed)
            return;
        end
        if ~ContinuationSecondSeedIsCurrent(seed, GetContinuationRadius())
            uialert(fig, 'Solve a valid second seed before plotting the continuation seed pair.', 'Seed Displaying');
            return;
        end

        RemoveContinuationSeedPairPlot();
        [continuationSecondSeed.seed1Handle, continuationSecondSeed.seed1TextHandle] = ...
            PlotContinuationSeedPoint(continuationSecondSeed.X1, ' Seed 1');
        [continuationSecondSeed.seed2Handle, continuationSecondSeed.seed2TextHandle] = ...
            PlotContinuationSeedPoint(continuationSecondSeed.X2, ' Seed 2');
        SetStatus(sprintf('Plotted continuation seed pair.\nSeed 1: %s index %s\nSeed 2 distance: %.6g', ...
            continuationSecondSeed.datasetName, ContinuationIndexText(continuationSecondSeed.index), ...
            continuationSecondSeed.distance));
    end

    function [markerHandle, textHandle] = PlotContinuationSeedPoint(solutionVector, labelText)
        [xCoord, yCoord, zCoord] = GetSolutionCoordinates(solutionVector);
        xOffset = 0.02 * max(diff(ax.XLim), eps);
        yOffset = 0.02 * max(diff(ax.YLim), eps);
        zOffset = 0.02 * max(diff(ax.ZLim), eps);
        markerHandle = plot3(ax, xCoord, yCoord, zCoord, 'o', ...
            'LineStyle', 'none', ...
            'MarkerSize', 10, ...
            'MarkerFaceColor', [0 0 0], ...
            'MarkerEdgeColor', [0 0 0], ...
            'LineWidth', 1.2, ...
            'HitTest', 'off', ...
            'Tag', 'ContinuationSeedPairMarker');
        textHandle = text(ax, xCoord + xOffset, yCoord + yOffset, zCoord + zOffset, labelText, ...
            'Interpreter', 'none', ...
            'Color', [0 0 0], ...
            'BackgroundColor', [1 1 1], ...
            'Margin', 1, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', ...
            'HitTest', 'off', ...
            'Tag', 'ContinuationSeedPairText');
    end

    function RefreshContinuationSeedPairPlot()
        if isempty(continuationSecondSeed.X1) || isempty(continuationSecondSeed.X2)
            return;
        end
        if ~HasGraphicsHandle(continuationSecondSeed.seed1Handle) && ...
                ~HasGraphicsHandle(continuationSecondSeed.seed2Handle)
            return;
        end

        [x1, y1, z1] = GetSolutionCoordinates(continuationSecondSeed.X1);
        [x2, y2, z2] = GetSolutionCoordinates(continuationSecondSeed.X2);
        xOffset = 0.02 * max(diff(ax.XLim), eps);
        yOffset = 0.02 * max(diff(ax.YLim), eps);
        zOffset = 0.02 * max(diff(ax.ZLim), eps);

        if HasGraphicsHandle(continuationSecondSeed.seed1Handle)
            continuationSecondSeed.seed1Handle.XData = x1;
            continuationSecondSeed.seed1Handle.YData = y1;
            continuationSecondSeed.seed1Handle.ZData = z1;
        end
        if HasGraphicsHandle(continuationSecondSeed.seed2Handle)
            continuationSecondSeed.seed2Handle.XData = x2;
            continuationSecondSeed.seed2Handle.YData = y2;
            continuationSecondSeed.seed2Handle.ZData = z2;
        end
        if HasGraphicsHandle(continuationSecondSeed.seed1TextHandle)
            continuationSecondSeed.seed1TextHandle.Position = [x1 + xOffset, y1 + yOffset, z1 + zOffset];
            continuationSecondSeed.seed1TextHandle.String = ' Seed 1';
        end
        if HasGraphicsHandle(continuationSecondSeed.seed2TextHandle)
            continuationSecondSeed.seed2TextHandle.Position = [x2 + xOffset, y2 + yOffset, z2 + zOffset];
            continuationSecondSeed.seed2TextHandle.String = ' Seed 2';
        end
    end

    function seedPair = ResolveContinuation1DSeedPair(operationName)
        if nargin < 1
            operationName = '1D Continuation';
        end
        seedPair = [];
        seed = ResolveContinuationFirstSeed(true);
        if isempty(seed)
            return;
        end
        radiusValue = GetContinuationRadius();
        if ~ContinuationSecondSeedIsCurrent(seed, radiusValue)
            uialert(fig, sprintf('Solve the second seed at the current seed source and radius before running %s.', ...
                operationName), operationName);
            SetStatus(sprintf(['%s waiting for a solved second seed.\n' ...
                'Seed 1: %s index %s\nRadius: %.6g'], ...
                operationName, seed.datasetName, ContinuationIndexText(seed.index), radiusValue));
            return;
        end

        [gaitsMatch, seed1Gait, seed2Gait] = ContinuationSeedGaitsMatch( ...
            continuationSecondSeed.X1, continuationSecondSeed.X2);
        if ~gaitsMatch
            mismatchMessage = sprintf(['The continuation seed pair does not have matching identifiable gaits.\n' ...
                'Seed 1: %s\nSeed 2: %s'], ...
                ContinuationGaitInfoText(seed1Gait), ContinuationGaitInfoText(seed2Gait));
            uialert(fig, mismatchMessage, operationName);
            SetStatus(sprintf('%s blocked by seed gait mismatch.\n%s', operationName, mismatchMessage));
            return;
        end

        idxValue = continuationSecondSeed.index;
        if isempty(idxValue)
            idxValue = NaN;
        end
        seedPair = struct('datasetName', continuationSecondSeed.datasetName, ...
            'indices', [idxValue, NaN], ...
            'X1', continuationSecondSeed.X1(:), ...
            'X2', continuationSecondSeed.X2(:), ...
            'Para', continuationSecondSeed.Para(:), ...
            'results', seed.results);
    end

    function seedPair = ResolveSeedPair()
        seedPair = [];
        seedBase = ResolveSeedReference(true);
        if isempty(seedBase)
            return;
        end

        datasetResults = seedBase.results;
        nPts = size(datasetResults, 2);
        if nPts < 2
            uialert(fig, 'The selected branch does not have enough points for a two-seed continuation.', 'Seed Selection');
            return;
        end

        [idx1, idx2] = ResolveContinuationIndices(seedBase.index, nPts);
        seedEdited = GetSeedEditorValues(seedBase);
        editTol = 1e-10;
        hasStateEdits = norm(seedEdited.X(:) - seedBase.X(:)) > editTol;
        hasParameterEdits = norm(seedEdited.Para(:) - seedBase.Para(:)) > editTol;

        X1 = seedEdited.X(:);
        Para = seedEdited.Para(:);
        if hasStateEdits || hasParameterEdits
            [X1, ~] = ProjectSeedGuessToSolution(seedEdited.X(:), Para, 'selected seed');
        end

        X2 = datasetResults(1:22, idx2);
        if hasParameterEdits
            [X2, ~] = ProjectSeedGuessToSolution(X2(:), Para, 'adjacent seed');
        else
            X2 = EventTimingRegulation(X2(:));
        end

        seedPair = struct('datasetName', seedBase.datasetName, ...
            'indices', [idx1, idx2], ...
            'X1', X1(:), ...
            'X2', X2(:), ...
            'Para', Para(:), ...
            'results', datasetResults);
    end

    function [X1Out, X2Out] = EnsureSeedPairSeparation(X1In, X2In, ParaIn, radiusTarget)
        X1Out = X1In(:);
        X2Out = X2In(:);
        scale = LocalScaleVectorGUI(X2Out, X1Out);
        minRequiredDistance = max(0.25 * radiusTarget, 1e-3);
        if norm((X2Out - X1Out) ./ scale) >= minRequiredDistance
            return;
        end

        jitterScale = max(0.05, radiusTarget) * scale;
        for attempt = 1:6
            guess = EventTimingRegulation(X2Out + (0.15 * attempt) * jitterScale .* (2 * rand(size(X2Out)) - 1));
            [xTry, fTry, exitflagTry] = fsolve(@(X) Quadrupedal_ZeroFun_v2(X, ParaIn, 'skipSolve'), guess, numOPTS);
            if exitflagTry > 0 && SolutionAcceptedGUI(fTry, xTry)
                xTry = EventTimingRegulation(xTry);
                if norm((xTry(:) - X1Out) ./ scale) >= minRequiredDistance
                    X2Out = xTry(:);
                    return;
                end
            end
        end
    end

    function out = ApplyRandomization(baseVector, noiseLevel, modeName)
        out = baseVector(:);
        if isempty(noiseLevel) || noiseLevel == 0
            return;
        end
        switch modeName
            case 'Percent'
                scale = max(abs(out), 1);
                out = out + (noiseLevel / 100) * scale .* (2 * rand(size(out)) - 1);
            otherwise
                out = out + noiseLevel * (2 * rand(size(out)) - 1);
        end
    end

    function ParaOut = EnforcePositiveParameters(ParaIn)
        ParaOut = ParaIn(:);
        positiveIdx = [1, 2, 3, 4, 6, 7];
        ParaOut(positiveIdx) = max(ParaOut(positiveIdx), 1e-6);
    end

    function FindNewInitialSolution()
        if continuationBusy
            return;
        end

        seed = ResolveSingleSeed();
        if isempty(seed)
            return;
        end

        setContinuationBusy(true);
        try
            Xguess = EventTimingRegulation(ApplyRandomization(seed.X, stateNoiseInput.Value, randomizationModeDropdown.Value));
            ParaTrial = EnforcePositiveParameters(ApplyRandomization(seed.Para, parameterNoiseInput.Value, randomizationModeDropdown.Value));
            [xNew, fval, exitflag] = fsolve(@(X) Quadrupedal_ZeroFun_v2(X, ParaTrial, 'skipSolve'), Xguess, seedSolveOPTS);
            xNew = EventTimingRegulation(xNew);
            if exitflag <= 0 || ~SolutionAcceptedGUI(fval, xNew)
                error('The randomized initial guess did not converge to a valid periodic solution.');
            end

            seedName = ComposeBranchName('seed');
            generatedSeedSolutions(end + 1) = struct('name', seedName, 'X', xNew, 'Para', ParaTrial, 'handle', []); %#ok<AGROW>
            generatedSeedSolutions(end).handle = PlotGeneratedSeedMarker(generatedSeedSolutions(end));
            [~, ~, gaitColor, ~] = Gait_Identification(xNew);
            UpdateContinuationPreviewOrbit(xNew, ParaTrial, ['Seed preview: ' seedName], gaitColor);
            UpdateAxisLimits();
            SetStatus(sprintf('Found a new solution from %s index %d.', seed.datasetName, seed.index));
        catch ME
            uialert(fig, ME.message, 'Seed Search Error');
            SetStatus(['Seed search failed: ' ME.message]);
        end
        setContinuationBusy(false);
    end

    function SetStatus(message)
        statusText = char(string(message));
        statusLineCount = max(1, numel(strsplit(statusText, sprintf('\n'))));
        statusContentMinHeight = max(120, 24 * statusLineCount + 24);
        for i = 1:numel(statusLabelHandles)
            if isgraphics(statusLabelHandles(i))
                statusLabelHandles(i).Text = statusText;
                if isprop(statusLabelHandles(i), 'Tooltip')
                    statusLabelHandles(i).Tooltip = statusText;
                end
            end
        end
        UpdateStatusSectionLayout();
        drawnow limitrate;
    end

    function setContinuationBusy(isBusy, controlOwner)
        if nargin < 2
            controlOwner = '';
        end
        continuationBusy = isBusy;
        if isBusy
            fig.Pointer = 'watch';
            state = 'off';
            continuationPauseRequested = false;
            continuationStopRequested = false;
            continuationControlOwner = char(string(controlOwner));
        else
            fig.Pointer = 'arrow';
            state = 'on';
            continuationPauseRequested = false;
            continuationStopRequested = false;
            continuationControlOwner = '';
        end
        findSeedButton.Enable = state;
        runContinuationButton.Enable = state;
        runParameterButton.Enable = state;
        run2DButton.Enable = state;
        seedActionButtons = [solveSecondSeedButton, removeSecondSeedButton, ...
            plotSeedPairButton, removeSeedPairPlotButton, ...
            parameterSolveSecondSeedButton, parameterRemoveSecondSeedButton, ...
            parameterPlotSeedPairButton, parameterRemoveSeedPairPlotButton, ...
            scanSolveSecondSeedButton, scanRemoveSecondSeedButton, ...
            scanPlotSeedPairButton, scanRemoveSeedPairPlotButton];
        for iControl = 1:numel(seedActionButtons)
            if isgraphics(seedActionButtons(iControl))
                seedActionButtons(iControl).Enable = state;
            end
        end
        if isgraphics(continuationResultNameInput)
            continuationResultNameInput.Enable = state;
        end
        if isgraphics(parameterResultNameInput)
            parameterResultNameInput.Enable = state;
        end
        if exist('parameterVaryingDropdown', 'var') && isgraphics(parameterVaryingDropdown)
            parameterVaryingDropdown.Enable = state;
        end
        if exist('targetParameterInput', 'var') && isgraphics(targetParameterInput)
            targetParameterInput.Enable = state;
        end
        if exist('parameterScanDropdown', 'var') && isgraphics(parameterScanDropdown)
            parameterScanDropdown.Enable = state;
        end
        if exist('scanValuesInput', 'var') && isgraphics(scanValuesInput)
            scanValuesInput.Enable = state;
        end
        if isgraphics(pauseContinuationButton)
            pauseContinuationButton.Enable = OnOffState(isBusy && strcmp(continuationControlOwner, '1D'));
            pauseContinuationButton.Text = 'Pause';
        end
        if isgraphics(stopContinuationButton)
            stopContinuationButton.Enable = OnOffState(isBusy && strcmp(continuationControlOwner, '1D'));
        end
        if isgraphics(pauseParameterButton)
            pauseParameterButton.Enable = OnOffState(isBusy && strcmp(continuationControlOwner, 'Para'));
            pauseParameterButton.Text = 'Pause';
        end
        if isgraphics(stopParameterButton)
            stopParameterButton.Enable = OnOffState(isBusy && strcmp(continuationControlOwner, 'Para'));
        end
        if isgraphics(pause2DButton)
            pause2DButton.Enable = OnOffState(isBusy && strcmp(continuationControlOwner, '2D'));
            pause2DButton.Text = 'Pause';
        end
        if isgraphics(stop2DButton)
            stop2DButton.Enable = OnOffState(isBusy && strcmp(continuationControlOwner, '2D'));
        end
        drawnow limitrate;
    end

    function state = OnOffState(isOn)
        if isOn
            state = 'on';
        else
            state = 'off';
        end
    end

    function state = YesNoState(isYes)
        if isYes
            state = 'Yes';
        else
            state = 'No';
        end
    end

    function ToggleContinuationPause(controlOwner)
        if nargin < 1
            controlOwner = '1D';
        end
        if ~continuationBusy || continuationStopRequested || ...
                ~strcmp(continuationControlOwner, controlOwner)
            return;
        end

        [pauseButton, ~, operationName] = ContinuationControlHandles(controlOwner);
        continuationPauseRequested = ~continuationPauseRequested;
        if continuationPauseRequested
            pauseButton.Text = 'Resume';
            SetStatus(sprintf('%s paused. Press Resume to continue or Stop to end the operation.', operationName));
        else
            pauseButton.Text = 'Pause';
            SetStatus(sprintf('%s resuming.', operationName));
        end
    end

    function RequestContinuationStop(controlOwner)
        if nargin < 1
            controlOwner = '1D';
        end
        if ~continuationBusy || ~strcmp(continuationControlOwner, controlOwner)
            return;
        end

        [pauseButton, activeStopButton, operationName] = ContinuationControlHandles(controlOwner);
        continuationStopRequested = true;
        continuationPauseRequested = false;
        if isgraphics(pauseButton)
            pauseButton.Text = 'Pause';
            pauseButton.Enable = 'off';
        end
        if isgraphics(activeStopButton)
            activeStopButton.Enable = 'off';
        end
        SetStatus(sprintf('%s stop requested. Finishing the active solver callback safely.', operationName));
    end

    function [pauseButton, activeStopButton, operationName] = ContinuationControlHandles(controlOwner)
        switch controlOwner
            case 'Para'
                pauseButton = pauseParameterButton;
                activeStopButton = stopParameterButton;
                operationName = 'Parameter Varying';
            case '2D'
                pauseButton = pause2DButton;
                activeStopButton = stop2DButton;
                operationName = '2D Scan';
            otherwise
                pauseButton = pauseContinuationButton;
                activeStopButton = stopContinuationButton;
                operationName = '1D Continuation';
        end
    end

    function control = PollGUIContinuationControl()
        if ~isgraphics(fig)
            control = struct('pauseRequested', false, 'stopRequested', true);
            return;
        end
        control = struct( ...
            'pauseRequested', continuationPauseRequested, ...
            'stopRequested', continuationStopRequested);
    end

    function solverOptions = BuildGUIControlledSolverOptions(baseOptions)
        existingOutputFcn = optimget(baseOptions, 'OutputFcn', []);
        solverOptions = optimset(baseOptions, 'OutputFcn', ...
            @(X, optimValues, solverState) GUIControlledSolverOutput( ...
            existingOutputFcn, X, optimValues, solverState));
    end

    function stop = GUIControlledSolverOutput(existingOutputFcn, X, optimValues, solverState)
        stop = RunExistingGUIOutputFcn(existingOutputFcn, X, optimValues, solverState);
        if ~stop
            stop = WaitForGUIContinuationControl();
        end
    end

    function stop = RunExistingGUIOutputFcn(outputFcn, X, optimValues, solverState)
        stop = false;
        if isempty(outputFcn)
            return;
        end
        try
            if isa(outputFcn, 'function_handle')
                callbackStop = outputFcn(X, optimValues, solverState);
                if ~isempty(callbackStop)
                    stop = any(logical(callbackStop(:)));
                end
            elseif iscell(outputFcn)
                for callbackIdx = 1:numel(outputFcn)
                    if isa(outputFcn{callbackIdx}, 'function_handle')
                        callbackStop = outputFcn{callbackIdx}(X, optimValues, solverState);
                        if ~isempty(callbackStop)
                            stop = stop || any(logical(callbackStop(:)));
                        end
                    end
                end
            end
        catch ME
            warning('SLIP_Quadruped_GUI:OutputCallbackError', ...
                'Existing fsolve output callback failed: %s', ME.message);
        end
    end

    function stopRequested = WaitForGUIContinuationControl()
        stopRequested = false;
        while true
            drawnow;
            control = PollGUIContinuationControl();
            if control.stopRequested
                stopRequested = true;
                return;
            end
            if ~control.pauseRequested
                return;
            end
            pause(0.05);
        end
    end

    function ThrowIfGUIContinuationStopped(operationName)
        if WaitForGUIContinuationControl()
            error('SLIP_Quadruped_GUI:OperationStopped', ...
                '%s stopped by the user.', operationName);
        end
    end

    function UpdateContinuationPreviewOrbit(X, Para, titleText, gaitColor, animatePreview)
        if nargin < 4 || isempty(gaitColor)
            gaitColor = [0 0.4470 0.7410];
        end
        if nargin < 5
            animatePreview = true;
        end
        try
            [~, ~, Y] = Quadrupedal_ZeroFun_v2(X, Para, 'skipSolve');
        catch
            ResetAllPreviewAxes('Orbit Preview');
            return;
        end

        if isempty(Y) || size(Y, 2) < 6
            ResetAllPreviewAxes('Orbit Preview');
            return;
        end

        xVals = Y(:, 2);
        yVals = Y(:, 4);
        zVals = Y(:, 6);

        xlo = min(xVals); xhi = max(xVals);
        ylo = min(yVals); yhi = max(yVals);
        zlo = min(zVals); zhi = max(zVals);
        xpad = max(0.1 * max(xhi - xlo, eps), 0.01);
        ypad = max(0.1 * max(yhi - ylo, eps), 0.01);
        zpad = max(0.1 * max(zhi - zlo, eps), 0.02);

        movingPoints = gobjects(0);
        for i = 1:numel(previewAxesHandles)
            if ~isgraphics(previewAxesHandles(i))
                continue;
            end

            ConfigurePreviewAxes(previewAxesHandles(i), titleText);
            hold(previewAxesHandles(i), 'on');
            plot3(previewAxesHandles(i), xVals, yVals, zVals, 'k-', 'LineWidth', 1.5);
            fill3(previewAxesHandles(i), ...
                [xlo - xpad, xhi + xpad, xhi + xpad, xlo - xpad], ...
                [0, 0, 0, 0], ...
                [zlo - zpad, zlo - zpad, zhi + zpad, zhi + zpad], ...
                [0.7 0.7 0.7], 'FaceAlpha', 0.2, 'EdgeColor', 'none');

            movingPoints(end + 1) = scatter3(previewAxesHandles(i), xVals(1), yVals(1), zVals(1), 100, ... %#ok<AGROW>
                'filled', 'MarkerEdgeColor', [0 0 0], 'MarkerFaceColor', gaitColor);
            previewAxesHandles(i).XLim = [xlo - xpad, xhi + xpad];
            previewAxesHandles(i).YLim = [ylo - ypad, yhi + ypad];
            previewAxesHandles(i).ZLim = [zlo - zpad, zhi + zpad];
            hold(previewAxesHandles(i), 'off');
        end

        if animatePreview
            animateIdx = unique(round(linspace(1, numel(xVals), min(numel(xVals), 60))));
            for k = 1:numel(animateIdx)
                for i = 1:numel(movingPoints)
                    if isgraphics(movingPoints(i))
                        movingPoints(i).XData = xVals(animateIdx(k));
                        movingPoints(i).YData = yVals(animateIdx(k));
                        movingPoints(i).ZData = zVals(animateIdx(k));
                    end
                end
                drawnow limitrate;
            end
        else
            finalIdx = numel(xVals);
            for i = 1:numel(movingPoints)
                if isgraphics(movingPoints(i))
                    movingPoints(i).XData = xVals(finalIdx);
                    movingPoints(i).YData = yVals(finalIdx);
                    movingPoints(i).ZData = zVals(finalIdx);
                end
            end
            drawnow limitrate;
        end
    end

    function continuationOptions = BuildGUIContinuationOptions(branchTitle, temporaryFile)
        callbacks = struct();
        callbacks.onAcceptedPoint = [];
        callbacks.onStatus = @(state) HandleGUIContinuationStatus(state, branchTitle);
        callbacks.onFinish = @(state) HandleGUIContinuationFinish(state, branchTitle);
        callbacks.onControl = @() PollGUIContinuationControl();

        continuationOptions = struct();
        continuationOptions.ResetFigureOnStart = false;
        continuationOptions.ClearCommandWindow = false;
        continuationOptions.SaveTempSol = true;
        continuationOptions.TemporarySolutionFile = temporaryFile;
        continuationOptions.DeleteTempSolOnFinish = true;
        continuationOptions.RequireTemporarySave = true;
        continuationOptions.IlluSols = false;
        continuationOptions.DisplayCommandStatus = false;
        continuationOptions.DirectionPauseSeconds = 0;
        continuationOptions.FailurePauseSeconds = 0;
        continuationOptions.RadiusReductionPauseSeconds = 0;
        continuationOptions.PromptVelocityZeroCrossing = false;
        continuationOptions.BranchTitle = branchTitle;
        continuationOptions.Callbacks = callbacks;
    end

    function HandleGUIContinuationStatus(state, branchTitle)
        updateStatusDisplay = true;
        if isfield(state, 'phase')
            switch state.phase
                case 'start'
                    ClearContinuationPreviewPredictor();
                    if isfield(state, 'results') && ~isempty(state.results)
                        UpdateContinuationPreviewBranch(state.results, [branchTitle ' | seed pair']);
                    end
                case {'corrector-start', 'backtrack'}
                    UpdateContinuationPreviewPredictor(state, branchTitle);
                    updateStatusDisplay = false;
            end
        end
        if updateStatusDisplay
            statusText = FormatGUIContinuationStatus(state, branchTitle);
            if strcmp(branchTitle, '2D Scan')
                UpdateGUI2DScanParameterFromState(state);
                statusText = FormatGUI2DScanStatus(statusText);
            end
            SetStatus(statusText);
        end
    end

    function HandleGUIContinuationFinish(state, branchTitle)
        if isfield(state, 'results') && ~isempty(state.results)
            UpdateContinuationPreviewBranch(state.results, [branchTitle ' | finished'], ...
                continuationPreviewPredictedSolution);
        end
        statusText = FormatGUIContinuationStatus(state, branchTitle);
        if strcmp(branchTitle, '2D Scan')
            UpdateGUI2DScanParameterFromState(state);
            statusText = FormatGUI2DScanStatus(statusText);
        end
        SetStatus(statusText);
    end

    function titleText = ContinuationPreviewTitle(state, branchTitle)
        directionIndex = ContinuationStateField(state, 'directionIndex', NaN);
        pointIndex = ContinuationStateField(state, 'pointIndex', NaN);
        if isnumeric(directionIndex) && isfinite(directionIndex) ...
                && isnumeric(pointIndex) && isfinite(pointIndex)
            titleText = sprintf('%s | dir %d | point %d', branchTitle, directionIndex, pointIndex);
        elseif isnumeric(pointIndex) && isfinite(pointIndex)
            titleText = sprintf('%s | point %d', branchTitle, pointIndex);
        else
            titleText = branchTitle;
        end
    end

    function UpdateContinuationPreviewBranch(branchResults, titleText, extraSolution)
        if isempty(branchResults) || size(branchResults, 1) < 5
            return;
        end
        if nargin < 3
            extraSolution = [];
        end

        xValues = branchResults(1, :);
        yValues = branchResults(3, :);
        zValues = branchResults(5, :);
        limitXValues = xValues;
        limitYValues = yValues;
        limitZValues = zValues;
        hasExtraSolution = isnumeric(extraSolution) && numel(extraSolution) >= 5;
        if hasExtraSolution
            extraSolution = extraSolution(:);
            limitXValues(end + 1) = extraSolution(1);
            limitYValues(end + 1) = extraSolution(3);
            limitZValues(end + 1) = extraSolution(5);
        end
        markerColors = ContinuationPreviewMarkerColors(branchResults);

        for i = 1:numel(previewAxesHandles)
            previewAxes = previewAxesHandles(i);
            if ~isgraphics(previewAxes)
                continue;
            end

            branchLine = findobj(previewAxes, 'Tag', 'ContinuationPreviewBranchLine');
            solutionMarkers = findobj(previewAxes, 'Tag', 'ContinuationPreviewSolutionMarkers');
            if isempty(branchLine) || isempty(solutionMarkers)
                ConfigurePreviewAxes(previewAxes, titleText);
                hold(previewAxes, 'on');
                branchLine = plot3(previewAxes, xValues, yValues, zValues, '-', ...
                    'Color', [0.25 0.25 0.25], 'LineWidth', 1.5, ...
                    'Tag', 'ContinuationPreviewBranchLine');
                solutionMarkers = scatter3(previewAxes, xValues, yValues, zValues, 42, markerColors, ...
                    'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], ...
                    'Tag', 'ContinuationPreviewSolutionMarkers');
                hold(previewAxes, 'off');
            else
                branchLine = branchLine(1);
                solutionMarkers = solutionMarkers(1);
                branchLine.XData = xValues;
                branchLine.YData = yValues;
                branchLine.ZData = zValues;
                solutionMarkers.XData = xValues;
                solutionMarkers.YData = yValues;
                solutionMarkers.ZData = zValues;
                solutionMarkers.CData = markerColors;
            end

            previewAxes.XLim = ExpandedContinuationPreviewLimits(limitXValues);
            previewAxes.YLim = ExpandedContinuationPreviewLimits(limitYValues, 0);
            previewAxes.ZLim = ExpandedContinuationPreviewLimits(limitZValues, NaN, 0.15);
            previewAxes.Title.String = titleText;
            view(previewAxes, [0 0]);
            if hasExtraSolution
                UpdateContinuationPreviewPredictorGraphics(previewAxes, extraSolution);
            end
        end
        drawnow limitrate;
    end

    function UpdateContinuationPreviewPredictor(state, branchTitle)
        predictedSolution = ContinuationStateField(state, 'predictedSolution', []);
        branchResults = ContinuationStateField(state, 'results', []);
        if ~isnumeric(predictedSolution) || numel(predictedSolution) < 5 || isempty(branchResults)
            return;
        end
        continuationPreviewPredictedSolution = predictedSolution(:);
        UpdateContinuationPreviewBranch(branchResults, ...
            [ContinuationPreviewTitle(state, branchTitle) ' | predicted'], ...
            continuationPreviewPredictedSolution);
    end

    function UpdateContinuationPreviewPredictorGraphics(previewAxes, predictedSolution)
        predictorMarker = findobj(previewAxes, 'Tag', 'ContinuationPreviewPredictorMarker');
        predictorText = findobj(previewAxes, 'Tag', 'ContinuationPreviewPredictorText');
        if isempty(predictorMarker)
            hold(previewAxes, 'on');
            predictorMarker = scatter3(previewAxes, predictedSolution(1), ...
                predictedSolution(3), predictedSolution(5), 42, ...
                'MarkerEdgeColor', [0 0 0], ...
                'MarkerFaceColor', 'none', ...
                'LineWidth', 1.25, ...
                'Tag', 'ContinuationPreviewPredictorMarker');
            hold(previewAxes, 'off');
        else
            predictorMarker = predictorMarker(1);
            predictorMarker.XData = predictedSolution(1);
            predictorMarker.YData = predictedSolution(3);
            predictorMarker.ZData = predictedSolution(5);
        end

        labelPosition = ContinuationPreviewPredictorTextPosition(predictedSolution, previewAxes);
        if isempty(predictorText)
            predictorText = text(previewAxes, labelPosition(1), labelPosition(2), ...
                labelPosition(3), 'Predicted Solution', ...
                'Color', [0 0 0], ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'bottom', ...
                'Clipping', 'off', ...
                'Tag', 'ContinuationPreviewPredictorText');
        else
            predictorText = predictorText(1);
            predictorText.Position = labelPosition;
        end
        try
            uistack(predictorMarker, 'top');
        catch
        end
    end

    function labelPosition = ContinuationPreviewPredictorTextPosition(predictedSolution, previewAxes)
        xSpan = diff(previewAxes.XLim);
        zSpan = diff(previewAxes.ZLim);
        if ~(isfinite(xSpan) && xSpan > 0)
            xSpan = 1;
        end
        if ~(isfinite(zSpan) && zSpan > 0)
            zSpan = 1;
        end
        labelPosition = [predictedSolution(1) + 0.02 * xSpan, ...
            predictedSolution(3), predictedSolution(5) + 0.03 * zSpan];
    end

    function ClearContinuationPreviewPredictor()
        continuationPreviewPredictedSolution = [];
        for i = 1:numel(previewAxesHandles)
            if ~isgraphics(previewAxesHandles(i))
                continue;
            end
            delete(findobj(previewAxesHandles(i), 'Tag', 'ContinuationPreviewPredictorMarker'));
            delete(findobj(previewAxesHandles(i), 'Tag', 'ContinuationPreviewPredictorText'));
        end
    end

    function markerColors = ContinuationPreviewMarkerColors(branchResults)
        markerColors = repmat([0 0.4470 0.7410], size(branchResults, 2), 1);
        for idx = 1:size(branchResults, 2)
            try
                [~, ~, markerColor, ~] = Gait_Identification(branchResults(1:22, idx));
                markerColors(idx, :) = markerColor;
            catch
            end
        end
    end

    function limits = ExpandedContinuationPreviewLimits(values, referenceValue, paddingFraction)
        values = values(isfinite(values));
        if nargin < 3 || ~isfinite(paddingFraction) || paddingFraction <= 0
            paddingFraction = 0.1;
        end
        includeReference = nargin >= 2 && isfinite(referenceValue);
        if includeReference
            values = [values(:); referenceValue];
        end
        if isempty(values)
            limits = [-1 1];
            return;
        end

        minValue = min(values);
        maxValue = max(values);
        span = maxValue - minValue;
        if span < eps
            padding = max(0.1, paddingFraction * max(abs(minValue), 1));
        else
            padding = max(paddingFraction * span, 1e-6);
        end
        limits = [minValue - padding, maxValue + padding];
    end

    function statusText = FormatGUIContinuationStatus(state, branchTitle)
        phase = char(string(ContinuationStateField(state, 'phase', 'status')));
        direction = char(string(ContinuationStateField(state, 'directionName', '')));
        message = char(string(ContinuationStateField(state, 'message', '')));
        logFile = char(string(ContinuationStateField(state, 'logFile', '')));

        switch phase
            case 'accepted-point'
                statusText = sprintf([ ...
                    '%s\n' ...
                    'New solution solved: Yes\n' ...
                    'Direction: %s | Point: %s\n' ...
                    'Continuation iteration: %s | Solver iterations: %s\n' ...
                    'd_x: %s | Gait: %s\n' ...
                    'State distance: %s | Residual: %s\n' ...
                    'Predictor radius: %s | Numerical radius: %s'], ...
                    branchTitle, ContinuationTextOrDefault(direction, '<none>'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'pointIndex', NaN), '%.0f'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'iteration', NaN), '%.0f'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'solverIterations', NaN), '%.0f'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'currentDx', NaN), '%.6g'), ...
                    ContinuationTextOrDefault(ContinuationStateField(state, 'gaitAbbr', ''), 'Unknown'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'distanceFromPreviousState', NaN), '%.6g'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'residualNorm', NaN), '%.3e'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'predictorRadius', NaN), '%.6g'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'numericalRadius', NaN), '%.6g'));

            case 'corrector-start'
                statusText = sprintf([ ...
                    '%s\nNew solution solved: Pending\nStatus: Solving predicted solution\n' ...
                    'Direction: %s | Continuation iteration: %s\n' ...
                    'Current d_x: %s | Current gait: %s\nPredictor radius: %s'], ...
                    branchTitle, ContinuationTextOrDefault(direction, '<none>'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'iteration', NaN), '%.0f'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'currentDx', NaN), '%.6g'), ...
                    ContinuationTextOrDefault(ContinuationStateField(state, 'gaitAbbr', ''), 'Unknown'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'predictorRadius', NaN), '%.6g'));

            case 'backtrack'
                statusText = sprintf([ ...
                    '%s\nNew solution solved: Pending\nStatus: Corrector rollback in progress\n' ...
                    'Direction: %s | Continuation iteration: %s\n' ...
                    'Backtrack attempt: %s | Trial radius: %s'], ...
                    branchTitle, ContinuationTextOrDefault(direction, '<none>'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'iteration', NaN), '%.0f'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'correctorAttempt', NaN), '%.0f'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'predictorRadius', NaN), '%.6g'));

            case 'retry'
                statusText = sprintf([ ...
                    '%s\nNew solution solved: No\nStatus: Retrying with a smaller radius\n' ...
                    'Direction: %s | Continuation iteration: %s\nReason: %s\nNext numerical radius: %s'], ...
                    branchTitle, ContinuationTextOrDefault(direction, '<none>'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'iteration', NaN), '%.0f'), ...
                    ContinuationTextOrDefault(ContinuationStateField(state, 'flag', ''), message), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'numericalRadius', NaN), '%.6g'));

            case {'stop', 'direction-stop'}
                statusText = sprintf([ ...
                    '%s\nContinuation direction terminated\nDirection: %s\n' ...
                    'Last iteration: %s | Last point: %s\nLast d_x: %s | Last gait: %s\nReason: %s'], ...
                    branchTitle, ContinuationTextOrDefault(direction, '<none>'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'iteration', NaN), '%.0f'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'pointIndex', NaN), '%.0f'), ...
                    FormatContinuationScalar(ContinuationStateField(state, 'currentDx', NaN), '%.6g'), ...
                    ContinuationTextOrDefault(ContinuationStateField(state, 'gaitAbbr', ''), 'Unknown'), ...
                    ContinuationTextOrDefault(ContinuationStateField(state, 'terminationReason', ''), ...
                    ContinuationTextOrDefault(ContinuationStateField(state, 'flag', ''), message)));

            case 'finish'
                reasons = ContinuationStateField(state, 'terminationReasons', {});
                statusText = sprintf( ...
                    '%s finished\nPoints found: %s\nTermination: %s\nLog: %s', ...
                    branchTitle, ...
                    FormatContinuationScalar(ContinuationStateField(state, 'pointIndex', NaN), '%.0f'), ...
                    FormatContinuationReasons(reasons), ...
                    ContinuationTextOrDefault(logFile, '<not available>'));

            case 'start'
                statusText = sprintf('%s started.\nLog: %s', branchTitle, ...
                    ContinuationTextOrDefault(logFile, '<not available>'));

            otherwise
                statusText = sprintf('%s | %s', branchTitle, ...
                    ContinuationTextOrDefault(message, phase));
        end
    end

    function value = ContinuationStateField(state, fieldName, defaultValue)
        value = defaultValue;
        if isstruct(state) && isfield(state, fieldName) && ~isempty(state.(fieldName))
            value = state.(fieldName);
        end
    end

    function textValue = ContinuationTextOrDefault(value, defaultText)
        textValue = char(string(value));
        if isempty(strtrim(textValue))
            textValue = char(string(defaultText));
        end
    end

    function textValue = FormatContinuationScalar(value, formatSpec)
        textValue = '<unknown>';
        if isnumeric(value) && ~isempty(value) && isfinite(value(1))
            textValue = sprintf(formatSpec, value(1));
        end
    end

    function textValue = FormatContinuationReasons(reasons)
        if isempty(reasons)
            textValue = '<not available>';
            return;
        end

        reasonStrings = string(reasons);
        textValue = strjoin(cellstr(reasonStrings(:).'), ' | ');
    end

    function [resultFile, temporaryFile, fileName] = ResolveContinuationOutputFiles()
        resultFile = '';
        temporaryFile = '';
        fileName = '';
        rawName = strtrim(char(string(continuationResultNameInput.Value)));
        [folderPart, baseName, extension] = fileparts(rawName);
        if ~isempty(folderPart)
            uialert(fig, 'Enter a filename only. The selected Data Info folder is used automatically.', ...
                '1D Continuation File');
            return;
        end
        if isempty(baseName)
            uialert(fig, 'Enter a name for the continuation solution file.', '1D Continuation File');
            return;
        end
        if ~isempty(extension) && ~strcmpi(extension, '.mat')
            uialert(fig, 'The continuation solution filename must use the .mat extension.', ...
                '1D Continuation File');
            return;
        end

        baseName = SafeFilenameComponent(baseName, 'Continuation1D_Solution');
        fileName = [baseName '.mat'];
        continuationResultNameInput.Value = baseName;
        resultFile = fullfile(currentfolder, fileName);
        temporaryFile = fullfile(currentfolder, 'solution_temp.mat');

        if isfile(resultFile)
            choice = uiconfirm(fig, sprintf('Overwrite the existing file "%s"?', fileName), ...
                '1D Continuation File', ...
                'Options', {'Overwrite', 'Cancel'}, ...
                'DefaultOption', 'Cancel', ...
                'CancelOption', 'Cancel');
            if ~strcmp(choice, 'Overwrite')
                resultFile = '';
                temporaryFile = '';
                fileName = '';
            end
        end
    end

    function [resultFile, temporaryFile, fileName] = ResolveParameterOutputFiles()
        resultFile = '';
        temporaryFile = '';
        fileName = '';
        rawName = strtrim(char(string(parameterResultNameInput.Value)));
        [folderPart, baseName, extension] = fileparts(rawName);
        if ~isempty(folderPart)
            uialert(fig, 'Enter a filename only. The selected Data Info folder is used automatically.', ...
                'Parameter Varying File');
            return;
        end
        if isempty(baseName)
            uialert(fig, 'Enter a name for the parameter-varying solution file.', ...
                'Parameter Varying File');
            return;
        end
        if ~isempty(extension) && ~strcmpi(extension, '.mat')
            uialert(fig, 'The parameter-varying filename must use the .mat extension.', ...
                'Parameter Varying File');
            return;
        end

        baseName = SafeFilenameComponent(baseName, 'ParameterVarying');
        fileName = [baseName '.mat'];
        parameterResultNameInput.Value = baseName;
        resultFile = fullfile(currentfolder, fileName);
        temporaryFile = fullfile(currentfolder, 'solution_temp.mat');

        if isfile(resultFile)
            choice = uiconfirm(fig, sprintf('Overwrite the existing file "%s"?', fileName), ...
                'Parameter Varying File', ...
                'Options', {'Overwrite', 'Cancel'}, ...
                'DefaultOption', 'Cancel', ...
                'CancelOption', 'Cancel');
            if ~strcmp(choice, 'Overwrite')
                resultFile = '';
                temporaryFile = '';
                fileName = '';
            end
        end
    end

    function SaveContinuationResult(resultFile, branchResults, flags, continuationInfo, ...
            seedPair, radiusValue, numericalOptions)
        seedInformation = seedPair;
        if isfield(seedInformation, 'results')
            seedInformation = rmfield(seedInformation, 'results');
        end
        savedSolution = struct();
        savedSolution.results = branchResults;
        savedSolution.flags = flags;
        savedSolution.info = continuationInfo;
        savedSolution.seed_information = seedInformation;
        savedSolution.radius = radiusValue;
        savedSolution.numerical_options = numericalOptions;
        savedSolution.saved_at = datetime('now');
        save(resultFile, '-struct', 'savedSolution');
    end

    function RunNumericalContinuation1D()
        if continuationBusy
            return;
        end

        seedPair = ResolveContinuation1DSeedPair();
        if isempty(seedPair)
            return;
        end

        [resultFile, temporaryFile, ~] = ResolveContinuationOutputFiles();
        if isempty(resultFile)
            return;
        end

        setContinuationBusy(true, '1D');
        try
            radiusValue = GetContinuationRadius();
            continuationSolverOptions = optimset(numOPTS, 'Display', 'off');
            continuationOptions = BuildGUIContinuationOptions('1D Continuation', temporaryFile);
            [branchResults, flags, continuationInfo] = NumericalContinuation1D_Quadruped_v2( ...
                seedPair.X1, seedPair.X2, seedPair.Para, radiusValue, ...
                continuationSolverOptions, continuationOptions);
            SaveContinuationResult(resultFile, branchResults, flags, continuationInfo, ...
                seedPair, radiusValue, continuationSolverOptions);
            SetStatus(sprintf([ ...
                '1D Continuation finished and saved\nFile: %s\nPoints found: %d\n' ...
                'Termination: %s | %s\nTemporary file removed: %s\nLog: %s'], ...
                resultFile, size(branchResults, 2), char(flags(1)), char(flags(2)), ...
                YesNoState(~isfile(temporaryFile)), continuationInfo.log_file));
        catch ME
            uialert(fig, ME.message, 'Continuation Error');
            SetStatus(['1D continuation failed: ' ME.message]);
        end
        setContinuationBusy(false);
    end

    function RunParameterVaryingContinuation()
        if continuationBusy
            return;
        end

        seedPair = ResolveContinuation1DSeedPair('Parameter Varying');
        if isempty(seedPair)
            return;
        end

        paramIdx = ParameterDisplayToIndex(parameterVaryingDropdown.Value);
        if isempty(paramIdx)
            uialert(fig, 'Select a valid parameter to vary.', 'Parameter Varying');
            return;
        end

        [resultFile, temporaryFile, ~] = ResolveParameterOutputFiles();
        if isempty(resultFile)
            return;
        end

        setContinuationBusy(true, 'Para');
        try
            targetValue = targetParameterInput.Value;
            initialValue = seedPair.Para(paramIdx);
            parameterKey = ParameterDisplayToKey(parameterVaryingDropdown.Value);
            parameterSolverOptions = optimset(numOPTS, ...
                'Display', 'off', ...
                'TolFun', 1e-9, ...
                'TolX', 1e-12);
            controlledSolverOptions = BuildGUIControlledSolverOptions(parameterSolverOptions);
            ClearContinuationPreviewPredictor();
            SetStatus(sprintf([ ...
                'Parameter Varying started.\nDataset: %s\nParameter: %s\n' ...
                'Initial value: %.6g\nTarget value: %.6g'], ...
                seedPair.datasetName, parameterKey, initialValue, targetValue));

            [X1, X2, ParaOut] = GUIParameterInterimSearch(targetValue, initialValue, ...
                paramIdx, seedPair.X1, seedPair.X2, seedPair.Para, ...
                controlledSolverOptions, seedPair.datasetName);
            radiusValue = GetContinuationRadius();
            finalPairSolverOptions = optimset(parameterSolverOptions, 'TolFun', 1e-12, 'TolX', 1e-12);
            controlledFinalPairOptions = BuildGUIControlledSolverOptions(finalPairSolverOptions);
            [X1, X2, finalSeedInfo] = ReconditionParameterSeedPairAtRadius( ...
                X1, X2, ParaOut, radiusValue, controlledFinalPairOptions, seedPair.datasetName);
            ThrowIfGUIContinuationStopped('Parameter Varying');

            variedSeedPair = seedPair;
            variedSeedPair.X1 = X1(:);
            variedSeedPair.X2 = X2(:);
            variedSeedPair.Para = ParaOut(:);
            continuationOptions = BuildGUIContinuationOptions('Parameter Varying', temporaryFile);
            [branchResults, flags, continuationInfo] = NumericalContinuation1D_Quadruped_v2( ...
                X1, X2, ParaOut, radiusValue, parameterSolverOptions, continuationOptions);
            continuationInfo.parameter_varying = struct( ...
                'source_dataset', seedPair.datasetName, ...
                'parameter_key', parameterKey, ...
                'parameter_index', paramIdx, ...
                'initial_value', initialValue, ...
                'target_value', targetValue, ...
                'final_seed_state_distance', finalSeedInfo.distance, ...
                'final_seed_distance_error', finalSeedInfo.distanceError, ...
                'final_seed_residuals', [finalSeedInfo.seed1ResidualNorm, finalSeedInfo.periodicResidualNorm], ...
                'final_seed_gait', finalSeedInfo.seed1GaitAbbr);
            SaveContinuationResult(resultFile, branchResults, flags, continuationInfo, ...
                variedSeedPair, radiusValue, parameterSolverOptions);
            UpdateParameterOperationLabels();
            SetStatus(sprintf([ ...
                'Parameter Varying finished and saved\nFile: %s\nDataset: %s\n' ...
                '%s: %.6g -> %.6g\nPoints found: %d\nTermination: %s | %s\n' ...
                'Temporary file removed: %s\nLog: %s'], ...
                resultFile, seedPair.datasetName, parameterKey, initialValue, ParaOut(paramIdx), ...
                size(branchResults, 2), char(flags(1)), char(flags(2)), ...
                YesNoState(~isfile(temporaryFile)), continuationInfo.log_file));
        catch ME
            if strcmp(ME.identifier, 'SLIP_Quadruped_GUI:OperationStopped')
                SetStatus('Parameter Varying stopped before continuation completed. No result file was saved.');
            else
                uialert(fig, ME.message, 'Parameter Varying Error');
                SetStatus(['Parameter Varying failed: ' ME.message]);
            end
        end
        setContinuationBusy(false);
    end

    function [X1Out, X2Out, ParaOut] = GUIParameterInterimSearch( ...
            targetValue, initialValue, paramIdx, X1In, X2In, ParaIn, solverOptions, datasetName)
        X1Out = EventTimingRegulation(X1In(:));
        X2Out = EventTimingRegulation(X2In(:));
        ParaOut = ParaIn(:);
        parameterKey = parameterkeys{paramIdx};
        parameterSteps = linspace(initialValue, targetValue, 11);

        for stepIdx = 2:numel(parameterSteps)
            ThrowIfGUIContinuationStopped('Parameter Varying');
            ParaOut(paramIdx) = parameterSteps(stepIdx);
            ParaOut = EnforcePositiveParameters(ParaOut);

            [xTry1, f1, exitflag1] = fsolve( ...
                @(X) Quadrupedal_ZeroFun_v2(X, ParaOut, 'skipSolve'), X1Out, solverOptions);
            ThrowIfGUIContinuationStopped('Parameter Varying');
            [xTry2, f2, exitflag2] = fsolve( ...
                @(X) Quadrupedal_ZeroFun_v2(X, ParaOut, 'skipSolve'), X2Out, solverOptions);
            ThrowIfGUIContinuationStopped('Parameter Varying');

            if exitflag1 <= 0 || ~SolutionAcceptedGUI(f1, xTry1)
                error('Interim search failed for seed 1 at %s = %.6g.', ...
                    parameterKey, ParaOut(paramIdx));
            end
            if exitflag2 <= 0 || ~SolutionAcceptedGUI(f2, xTry2)
                error('Interim search failed for seed 2 at %s = %.6g.', ...
                    parameterKey, ParaOut(paramIdx));
            end

            [gaitsMatch, gait1, gait2] = ContinuationSeedGaitsMatch(xTry1, xTry2);
            if ~gaitsMatch
                error(['Parameter-varying seeds have mismatched gaits at %s = %.6g. ' ...
                    'Seed 1: %s; Seed 2: %s.'], ...
                    parameterKey, ParaOut(paramIdx), ...
                    ContinuationGaitInfoText(gait1), ContinuationGaitInfoText(gait2));
            end

            X1Out = EventTimingRegulation(xTry1);
            X2Out = EventTimingRegulation(xTry2);
            interimResults = [[X1Out; ParaOut], [X2Out; ParaOut]];
            UpdateContinuationPreviewBranch(interimResults, sprintf( ...
                'Parameter Varying | %s | %s = %.6g | %d/10', ...
                datasetName, parameterKey, ParaOut(paramIdx), stepIdx - 1));
            SetStatus(sprintf([ ...
                'Parameter Varying interim search\nDataset: %s\n' ...
                '%s = %.6g\nStep: %d/10'], ...
                datasetName, parameterKey, ParaOut(paramIdx), stepIdx - 1));
        end
    end

    function [X1Out, X2Out, solveInfo] = ReconditionParameterSeedPairAtRadius( ...
            X1In, X2In, ParaIn, radiusTarget, solverOptions, datasetName)
        X1Out = EventTimingRegulation(X1In(:));
        X2Out = EventTimingRegulation(X2In(:));
        ParaIn = EnforcePositiveParameters(ParaIn(:));

        seed1Residual = Quadrupedal_ZeroFun_v2(X1Out, ParaIn, 'skipSolve');
        seed1ResidualNorm = SafeResidualNormGUI(seed1Residual);
        if seed1ResidualNorm >= 1e-9
            ThrowIfGUIContinuationStopped('Parameter Varying');
            SetStatus(sprintf([ ...
                'Parameter Varying final seed refinement\nDataset: %s\n' ...
                'Seed 1 residual: %.3e\nTarget state distance: %.6g'], ...
                datasetName, seed1ResidualNorm, radiusTarget));
            [xRefined, ~, exitflagRefined] = fsolve( ...
                @(X) Quadrupedal_ZeroFun_v2(X, ParaIn, 'skipSolve'), X1Out, solverOptions);
            ThrowIfGUIContinuationStopped('Parameter Varying');
            X1Out = EventTimingRegulation(xRefined);
            seed1Residual = Quadrupedal_ZeroFun_v2(X1Out, ParaIn, 'skipSolve');
            seed1ResidualNorm = SafeResidualNormGUI(seed1Residual);
            if exitflagRefined <= 0 || seed1ResidualNorm >= 1e-9
                error('Final parameter-varying Seed 1 residual %.3e is not below 1e-9.', ...
                    seed1ResidualNorm);
            end
        end

        transportedSeed = struct('datasetName', datasetName, ...
            'sourceMode', 'Parameter Varying', ...
            'index', 1, ...
            'percent', [], ...
            'X', X1Out, ...
            'Para', ParaIn, ...
            'results', [X1Out, X2Out]);
        SetStatus(sprintf([ ...
            'Parameter Varying final radius correction\nDataset: %s\n' ...
            'Transported state distance: %.6g\nTarget state distance: %.6g'], ...
            datasetName, ContinuationStateDistance(X1Out, X2Out), radiusTarget));
        [X2Out, solveInfo] = FindContinuationSecondSeedAtStateRadius( ...
            transportedSeed, radiusTarget, solverOptions, X2Out, ...
            'Parameter Varying final radius correction', true);

        distanceTolerance = max(1e-7, 1e-4 * radiusTarget);
        finalDistance = ContinuationStateDistance(X1Out, X2Out);
        finalDistanceError = abs(finalDistance - radiusTarget);
        [gaitsMatch, gait1, gait2] = ContinuationSeedGaitsMatch(X1Out, X2Out);
        if finalDistanceError > distanceTolerance
            error('Final seed state-distance error %.3e exceeds tolerance %.3e.', ...
                finalDistanceError, distanceTolerance);
        end
        if ~gaitsMatch
            error('Final parameter-varying seed gait mismatch: Seed 1 %s; Seed 2 %s.', ...
                ContinuationGaitInfoText(gait1), ContinuationGaitInfoText(gait2));
        end

        solveInfo.seed1ResidualNorm = seed1ResidualNorm;
        solveInfo.distance = finalDistance;
        solveInfo.distanceError = finalDistanceError;
        UpdateContinuationPreviewBranch([[X1Out; ParaIn], [X2Out; ParaIn]], sprintf( ...
            'Parameter Varying | final seed pair | radius %.6g', radiusTarget));
        SetStatus(sprintf([ ...
            'Parameter Varying seed pair validated\nDataset: %s\n' ...
            'Gait: %s\nSeed residuals: %.3e, %.3e\n' ...
            'State distance: %.6g\nDistance error: %.3e'], ...
            datasetName, gait1.abbr, seed1ResidualNorm, solveInfo.periodicResidualNorm, ...
            finalDistance, finalDistanceError));
    end

    function values = ParseScanValues(rawText)
        if iscell(rawText)
            rawText = strjoin(rawText, ' ');
        end
        cleaned = regexprep(rawText, '[\[\],;]', ' ');
        values = sscanf(cleaned, '%f').';
    end

    function Run2DContinuationScan()
        if continuationBusy
            return;
        end

        seedPair = ResolveContinuation1DSeedPair('2D Scan');
        if isempty(seedPair)
            return;
        end

        paramIdx = ParameterDisplayToIndex(parameterScanDropdown.Value);
        if isempty(paramIdx)
            uialert(fig, 'Select a valid parameter to scan.', '2D Scan');
            return;
        end

        scanValues = ParseScanValues(scanValuesInput.Value);
        if isempty(scanValues) || any(~isfinite(scanValues)) || any(scanValues <= 0)
            uialert(fig, 'Enter one or more finite positive parameter values for the scan.', '2D Scan');
            return;
        end

        sourceFolder = currentfolder;
        parameterKey = ParameterDisplayToKey(parameterScanDropdown.Value);
        scanStatusParameterName = parameterKey;
        scanStatusParameterIndex = paramIdx;
        scanStatusParameterValue = seedPair.Para(paramIdx);
        radiusValue = GetContinuationRadius();
        source = BuildGUI2DScanSource(seedPair, sourceFolder);
        scanSolverOptions = BuildGUIControlledSolverOptions(optimset( ...
            numOPTS, 'Display', 'off', 'TolFun', 1e-12, 'TolX', 1e-12));
        continuationOptions = BuildGUIContinuationOptions( ...
            '2D Scan', fullfile(sourceFolder, 'solution_tempo.mat'));
        continuationOptions.MaxIterationsPerDirection = 5000;
        continuationOptions.MinimumTimingBoundaryMargin = max(1e-6, ...
            1e-5 * max([abs(seedPair.X1(22)), abs(seedPair.X2(22)), 1]));
        scanOptions = struct( ...
            'OutputRoot', sourceFolder, ...
            'RunName', '', ...
            'ResumeExisting', true, ...
            'CopySourceBranch', true, ...
            'ChangeToOutputFolder', true, ...
            'ContinueOnFailure', true, ...
            'StatusFcn', @(message) HandleGUI2DScanStatus(message), ...
            'ControlFcn', @() PollGUIContinuationControl(), ...
            'ContinuationRunOptions', continuationOptions);

        setContinuationBusy(true, '2D');
        try
            ClearContinuationPreviewPredictor();
            UpdateContinuationPreviewBranch( ...
                [[seedPair.X1; seedPair.Para], [seedPair.X2; seedPair.Para]], ...
                sprintf('2D Scan | initial seed pair | radius %.6g', radiusValue));
            SetStatus(FormatGUI2DScanStatus(sprintf([ ...
                '2D Scan started\nDataset: %s\nParameter: %s\n' ...
                'Targets: %s\nState radius: %.6g'], ...
                seedPair.datasetName, parameterKey, mat2str(scanValues), radiusValue)));

            scanReport = NumericalContinuation2D_Quadruped_v2( ...
                source, scanValues, parameterKey, radiusValue, [], ...
                scanSolverOptions, scanOptions);
            failureSummary = FormatGUI2DScanFailures(scanReport.failures);
            SetStatus(FormatGUI2DScanStatus(sprintf([ ...
                '2D Scan finished\nParameter: %s\nCompleted: %d\n' ...
                'Resumed/skipped: %d\nFailed: %d\nBlocked: %d\n' ...
                'Failure detail: %s\nOutput: %s'], ...
                parameterKey, numel(scanReport.completed_targets), ...
                numel(scanReport.skipped_targets), numel(scanReport.failures), ...
                numel(scanReport.blocked_targets), failureSummary, ...
                scanReport.output_folder)));
        catch ME
            if continuationStopRequested || ...
                    strcmp(ME.identifier, 'NumericalContinuation2D:OperationStopped')
                SetStatus(FormatGUI2DScanStatus( ...
                    '2D Scan stopped. The active temporary 1D solution file was removed.'));
            else
                uialert(fig, ME.message, '2D Scan Error');
                SetStatus(FormatGUI2DScanStatus(['2D scan failed: ' ME.message]));
            end
        end
        setContinuationBusy(false);
    end

    function source = BuildGUI2DScanSource(seedPair, sourceFolder)
        source = struct( ...
            'Name', seedPair.datasetName, ...
            'X1', seedPair.X1(:), ...
            'X2', seedPair.X2(:), ...
            'Para', seedPair.Para(:), ...
            'SeedIndices', seedPair.indices);
        if isfield(seedPair, 'results') && ~isempty(seedPair.results)
            source.Results = seedPair.results;
        end

        sourceFile = fullfile(sourceFolder, seedPair.datasetName);
        if isfile(sourceFile)
            source.BranchFile = sourceFile;
        end
    end

    function HandleGUI2DScanStatus(message)
        UpdateGUI2DScanParameterFromMessage(message);
        SetStatus(FormatGUI2DScanStatus(message));
    end

    function UpdateGUI2DScanParameterFromState(state)
        if isempty(scanStatusParameterIndex)
            return;
        end

        para = ContinuationStateField(state, 'Para', []);
        if isnumeric(para) && numel(para) >= scanStatusParameterIndex
            candidateValue = para(scanStatusParameterIndex);
            if isfinite(candidateValue)
                scanStatusParameterValue = candidateValue;
            end
        end
    end

    function UpdateGUI2DScanParameterFromMessage(message)
        if isempty(scanStatusParameterName)
            return;
        end

        messageText = char(string(message));
        numberPattern = '[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?';
        keyPattern = regexptranslate('escape', scanStatusParameterName);
        patterns = { ...
            ['(?m)^\s*Current target:\s*' keyPattern '\s*=\s*(' numberPattern ')'], ...
            ['(?m)^\s*' keyPattern '\s*:\s*' numberPattern '\s*->\s*(' numberPattern ')'], ...
            ['(?m)^\s*' keyPattern '\s*=\s*(' numberPattern ')'], ...
            ['(?m)^\s*Failed\s+' keyPattern '\s*=\s*(' numberPattern ')']};

        for patternIdx = 1:numel(patterns)
            token = regexp(messageText, patterns{patternIdx}, 'tokens', 'once');
            if isempty(token)
                continue;
            end
            candidateValue = str2double(token{1});
            if isfinite(candidateValue)
                scanStatusParameterValue = candidateValue;
                return;
            end
        end
    end

    function statusText = FormatGUI2DScanStatus(message)
        messageText = char(string(message));
        messageText = regexprep(messageText, '^2D Scan(?:\r\n|\n|\r)?', '', 'once');
        if isfinite(scanStatusParameterValue)
            parameterText = sprintf('Scanning Parameter: %s = %.12g', ...
                scanStatusParameterName, scanStatusParameterValue);
        else
            parameterText = sprintf('Scanning Parameter: %s', ...
                ContinuationTextOrDefault(scanStatusParameterName, '<pending>'));
        end

        if isempty(strtrim(messageText))
            statusText = sprintf('2D Scan\n%s', parameterText);
        else
            statusText = sprintf('2D Scan\n%s\n%s', parameterText, messageText);
        end
    end

    function summary = FormatGUI2DScanFailures(failures)
        if isempty(failures)
            summary = 'none';
            return;
        end

        parts = cell(1, numel(failures));
        for failureIdx = 1:numel(failures)
            parts{failureIdx} = sprintf('%.12g: %s', ...
                failures(failureIdx).target, failures(failureIdx).message);
        end
        summary = strjoin(parts, ' | ');
    end

    function [X1Out, X2Out, ParaOut] = GUIInterimSearch(targetPara, currentPara, pindex, X1In, X2In, ParaIn, OPTS, labelText)
        X1Out = EventTimingRegulation(X1In(:));
        X2Out = EventTimingRegulation(X2In(:));
        ParaOut = ParaIn(:);
        if abs(targetPara - currentPara) <= max(1e-10, 1e-8 * max(1, abs(targetPara)))
            return;
        end

        stepCount = max(3, min(20, ceil(10 * abs(targetPara - currentPara) / max(abs(currentPara), 1))));
        paraSteps = linspace(currentPara, targetPara, stepCount + 1);
        for k = 2:numel(paraSteps)
            ParaOut(pindex) = paraSteps(k);
            ParaOut = EnforcePositiveParameters(ParaOut);
            [xTry1, f1, exitflag1] = fsolve(@(X) Quadrupedal_ZeroFun_v2(X, ParaOut, 'skipSolve'), X1Out, OPTS);
            [xTry2, f2, exitflag2] = fsolve(@(X) Quadrupedal_ZeroFun_v2(X, ParaOut, 'skipSolve'), X2Out, OPTS);
            if exitflag1 <= 0 || ~SolutionAcceptedGUI(f1, xTry1)
                error('Interim search failed while updating the first seed.');
            end
            if exitflag2 <= 0 || ~SolutionAcceptedGUI(f2, xTry2)
                error('Interim search failed while updating the second seed.');
            end
            X1Out = EventTimingRegulation(xTry1);
            X2Out = EventTimingRegulation(xTry2);
            [~, ~, gaitColor, ~] = Gait_Identification(X1Out);
            UpdateContinuationPreviewOrbit(X1Out, ParaOut, sprintf('%s | %s = %.6g', labelText, parameterkeys{pindex}, ParaOut(pindex)), gaitColor);
            SetStatus(sprintf('%s: %s = %.6g (%d/%d)', labelText, parameterkeys{pindex}, ParaOut(pindex), k - 1, stepCount));
        end
    end

    function name = ComposeBranchName(prefix)
        prefix = regexprep(char(prefix), '[^A-Za-z0-9_]+', '_');
        name = sprintf('GUI_%s_%s', prefix, datestr(now, 'yyyymmdd_HHMMSSFFF'));
    end

    function AddContinuationBranchToPlot(branchResults, branchName)
        if isempty(branchResults)
            return;
        end
        plotHandle = PlotBranchInGUI(ax, branchResults, false);
        plottedDatasets{end + 1} = struct('filename', branchName, 'results', branchResults, ...
            'handle', plotHandle, 'origin', 'gui'); %#ok<AGROW>
        updateDatasetListBox();
        ActivateDatasetSelection(branchName);
        UpdateAxisData();
        UpdateAxisLimits();
        RefreshSeedContextLabel();
        UpdateParameterOperationLabels();
    end
    function ChangeView()
        switch viewDropdown.Value
            case 'Top'
                ax.View = [0, 90];
            case 'Side'
                ax.View = [0, 0];
            case 'Custom'
                ax.View = [viewXInput.Value, viewYInput.Value];
        end
    end

    function UpdateViewFromInput()
        ax.View = [viewXInput.Value, viewYInput.Value];
        viewDropdown.Value = 'Custom';
    end

    function UpdateViewInputs()
        viewAngles = ax.View;
        viewXInput.Value = viewAngles(1);
        viewYInput.Value = viewAngles(2);
        if isequal(viewAngles, [0, 90])
            viewDropdown.Value = 'Top';
        elseif isequal(viewAngles, [0, 0])
            viewDropdown.Value = 'Side';
        else
            viewDropdown.Value = 'Custom';
        end
    end

    function SyncInfoPanelFromAxes()
        UpdateViewInputs();
        UpdateAxisLimits();
        UpdateAspectRatioInputs();
        RefreshSeedManualSelectionVisualization();
    end

    function ChangeAxisLimits()
        ax.XLim = [xMinInput.Value, xMaxInput.Value];
        ax.YLim = [yMinInput.Value, yMaxInput.Value];
        ax.ZLim = [zMinInput.Value, zMaxInput.Value];
    end

    function ChangeAspectRatioMode()
        if strcmp(aspectModeDropdown.Value, 'Auto')
            SaveManualAspectRatioDraft();
            ax.PlotBoxAspectRatioMode = 'auto';
            aspectRatioDraftDirty = false;
            UpdateAspectRatioInputs();
            SetStatus('State Plot aspect ratio is now automatic.');
            return;
        end

        pbaspect(ax, manualAspectRatioValue);
        SetAspectRatioInputValues(manualAspectRatioValue);
        aspectRatioDraftDirty = false;
        UpdateAspectRatioControlState();
        SetStatus(sprintf('Manual aspect ratio applied: [%.4g %.4g %.4g].', manualAspectRatioValue));
    end

    function MarkAspectRatioDraftDirty()
        aspectRatioDraftDirty = true;
        SaveManualAspectRatioDraft();
    end

    function ApplyManualAspectRatio()
        ratioValues = GetAspectRatioInputValues();
        if any(~isfinite(ratioValues)) || any(ratioValues <= 0)
            SetStatus('Aspect ratio values must be finite positive numbers.');
            return;
        end
        pbaspect(ax, ratioValues);
        manualAspectRatioValue = ratioValues;
        aspectModeDropdown.Value = 'Manual';
        aspectRatioDraftDirty = false;
        UpdateAspectRatioInputs();
        SetStatus(sprintf('Updated State Plot aspect ratio to [%.4g %.4g %.4g].', ratioValues));
    end

    function UpdateAspectRatioInputs()
        if ~isgraphics(aspectModeDropdown) || ~isgraphics(aspectXInput) || ...
                ~isgraphics(aspectYInput) || ~isgraphics(aspectZInput)
            return;
        end
        currentRatio = pbaspect(ax);
        if strcmpi(ax.PlotBoxAspectRatioMode, 'manual')
            aspectModeDropdown.Value = 'Manual';
            if ~aspectRatioDraftDirty
                manualAspectRatioValue = currentRatio;
            end
        else
            aspectModeDropdown.Value = 'Auto';
            aspectRatioDraftDirty = false;
        end
        if ~aspectRatioDraftDirty
            SetAspectRatioInputValues(currentRatio);
        end
        UpdateAspectRatioControlState();
    end

    function ratioValues = GetAspectRatioInputValues()
        ratioValues = [aspectXInput.Value, aspectYInput.Value, aspectZInput.Value];
    end

    function SaveManualAspectRatioDraft()
        ratioValues = GetAspectRatioInputValues();
        if all(isfinite(ratioValues)) && all(ratioValues > 0)
            manualAspectRatioValue = ratioValues;
        end
    end

    function SetAspectRatioInputValues(ratioValues)
        aspectXInput.Value = ratioValues(1);
        aspectYInput.Value = ratioValues(2);
        aspectZInput.Value = ratioValues(3);
    end

    function UpdateAspectRatioControlState()
        if ~isgraphics(aspectModeDropdown) || ~isgraphics(aspectApplyButton)
            return;
        end
        if strcmp(aspectModeDropdown.Value, 'Manual')
            controlState = 'on';
            aspectRatioLabel.Text = 'Manual ratio';
        else
            controlState = 'off';
            aspectRatioLabel.Text = 'Current ratio';
        end
        aspectXInput.Enable = controlState;
        aspectYInput.Enable = controlState;
        aspectZInput.Enable = controlState;
        aspectApplyButton.Enable = controlState;
    end

    function UpdateAxisLimits()
        if isgraphics(xMinInput)
            xMinInput.Value = ax.XLim(1);
        end
        if isgraphics(xMaxInput)
            xMaxInput.Value = ax.XLim(2);
        end
        if isgraphics(yMinInput)
            yMinInput.Value = ax.YLim(1);
        end
        if isgraphics(yMaxInput)
            yMaxInput.Value = ax.YLim(2);
        end
        if isgraphics(zMinInput)
            zMinInput.Value = ax.ZLim(1);
        end
        if isgraphics(zMaxInput)
            zMaxInput.Value = ax.ZLim(2);
        end
    end

    function SetRoadmapLimits()
        ax.XLim = [0 10];
        ax.YLim = [-0.05 0.15];
        ax.ZLim = [0.6 1.2];
        UpdateAxisLimits();
    end

    function SaveCurrentPlot()
        fname = filenameInput.Value;
        ext = formatDropdown.Value;
        if isempty(fname)
            uialert(fig, 'Please enter a file name.', 'Missing File Name');
            return;
        end

        fullPath = fullfile(currentfolder, [fname, ext]);
        exportFigure = BuildExportFigure();
        cleanupExportFigure = onCleanup(@() deleteValidGraphicsObject(exportFigure));
        if strcmp(ext, '.pdf')
            exportgraphics(exportFigure, fullPath, 'ContentType', 'vector');
        else
            exportgraphics(exportFigure, fullPath);
        end
        msg = msgbox(['Plot saved to: ', fullPath], 'Save Successful', 'help');
        pause(1.5);
        if isvalid(msg)
            delete(msg);
        end
        SetStatus(['Saved branch plot to ' fullPath]);
    end

    function exportFigure = BuildExportFigure()
        exportFigure = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1200, 900]);
        exportAx = axes(exportFigure, 'Position', [0.10, 0.12, 0.72, 0.58]);
        hold(exportAx, 'on');
        grid(exportAx, 'on');
        view(exportAx, ax.View);
        exportAx.Box = 'on';
        exportAx.FontSize = 13;

        copiedChildren = copyobj(allchild(ax), exportAx);
        set(copiedChildren, 'HitTest', 'off');

        xlim(exportAx, ax.XLim);
        ylim(exportAx, ax.YLim);
        zlim(exportAx, ax.ZLim);
        title(exportAx, ax.Title.String, 'Interpreter', 'none', 'FontSize', 16);
        xlabel(exportAx, axisOptions{GetAxisSelectionIndex(xAxisDropdown)}, 'Interpreter', 'latex', 'FontSize', 15);
        ylabel(exportAx, axisOptions{GetAxisSelectionIndex(yAxisDropdown)}, 'Interpreter', 'latex', 'FontSize', 15);
        zlabel(exportAx, axisOptions{GetAxisSelectionIndex(zAxisDropdown)}, 'Interpreter', 'latex', 'FontSize', 15);

        if ~isempty(colorbarHandle) && isgraphics(colorbarHandle)
            exportCb = colorbar(exportAx);
            exportCb.Label.String = colorbarHandle.Label.String;
            exportCb.Label.Interpreter = 'latex';
            exportCb.Label.FontSize = colorbarHandle.Label.FontSize;
            colormap(exportAx, colormap(ax));
            caxis(exportAx, caxis(ax));
        end

        AddExportControlPanel(exportFigure);
    end

    function AddExportControlPanel(exportFigure)
        AddLabeledExportBox(exportFigure, [0.10, 0.83, 0.18, 0.08], 'X-axis dropdown', axisOptions{GetAxisSelectionIndex(xAxisDropdown)});
        AddLabeledExportBox(exportFigure, [0.31, 0.83, 0.18, 0.08], 'Y-axis dropdown', axisOptions{GetAxisSelectionIndex(yAxisDropdown)});
        AddLabeledExportBox(exportFigure, [0.52, 0.83, 0.18, 0.08], 'Z-axis dropdown', axisOptions{GetAxisSelectionIndex(zAxisDropdown)});

        AddLabeledExportBox(exportFigure, [0.10, 0.71, 0.18, 0.08], 'Fixed parameter', GetParameterLatexFromDisplay(fixedparameterDropdown.Value));
        AddLabeledExportBox(exportFigure, [0.31, 0.71, 0.18, 0.08], 'Fixed value', FormatValueForLatex(fixedparametervalueDropdown.Value));
        AddLabeledExportBox(exportFigure, [0.52, 0.71, 0.18, 0.08], 'Varying parameter', GetParameterLatexFromDisplay(varyingparameterDropdown.Value));
        AddLabeledExportBox(exportFigure, [0.73, 0.71, 0.18, 0.08], 'Varying value', FormatValueForLatex(varyingparameterValuesDropdown.Value));

        annotation(exportFigure, 'textbox', [0.10, 0.93, 0.50, 0.04], ...
            'String', 'Exported Branch Plot Controls', ...
            'Interpreter', 'none', ...
            'EdgeColor', 'none', ...
            'FontWeight', 'bold', ...
            'FontSize', 14);
    end

    function AddLabeledExportBox(exportFigure, boxPosition, labelText, latexValue)
        annotation(exportFigure, 'textbox', [boxPosition(1), boxPosition(2) + 0.045, boxPosition(3), 0.03], ...
            'String', labelText, ...
            'Interpreter', 'none', ...
            'EdgeColor', 'none', ...
            'FontSize', 11, ...
            'HorizontalAlignment', 'left');

        annotation(exportFigure, 'textbox', boxPosition, ...
            'String', ['$' StripLatexDelimiters(latexValue) '$'], ...
            'Interpreter', 'latex', ...
            'BackgroundColor', [1, 1, 1], ...
            'EdgeColor', [0.35, 0.35, 0.35], ...
            'LineWidth', 0.8, ...
            'FontSize', 13, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle');
    end

    function latexText = GetParameterLatexFromDisplay(selectedParam)
        if isempty(selectedParam) || strcmp(selectedParam, '<none>')
            latexText = '\mathrm{none}';
            return;
        end

        paramIdx = ParameterDisplayToIndex(selectedParam);
        if isempty(paramIdx)
            latexText = EscapeLatexText(selectedParam);
            return;
        end

        latexText = StripLatexDelimiters(parameteroptions{paramIdx});
    end

    function latexText = FormatValueForLatex(selectedValue)
        if isempty(selectedValue) || strcmp(selectedValue, '<none>')
            latexText = '\mathrm{none}';
        else
            latexText = EscapeLatexText(selectedValue);
        end
    end

    function axisIndex = GetAxisSelectionIndex(axisDropdown)
        axisIndex = find(strcmp(axisOptions, axisDropdown.Value), 1);
        if isempty(axisIndex)
            axisIndex = 1;
        end
    end

    function textOut = StripLatexDelimiters(textIn)
        textOut = strrep(char(string(textIn)), '$', '');
    end

    function textOut = EscapeLatexText(textIn)
        textOut = strrep(char(string(textIn)), '\', '\textbackslash{}');
        textOut = strrep(textOut, '_', '\_');
    end

    function deleteValidGraphicsObject(graphicsObj)
        if ~isempty(graphicsObj) && isvalid(graphicsObj)
            delete(graphicsObj);
        end
    end

    function PositionColorbar()
        if isempty(colorbarHandle) || ~isgraphics(colorbarHandle)
            return;
        end

        drawnow limitrate;
        cbWidth = max(14, 0.012 * fig.Position(3));
        cbGap = max(10, 0.008 * fig.Position(3));
        cbLeft = min(fig.Position(3) - cbWidth - 10, ax.Position(1) + ax.Position(3) + cbGap);
        cbBottom = ax.Position(2) + 0.08 * ax.Position(4);
        cbHeight = 0.84 * ax.Position(4);

        colorbarHandle.Location = 'manual';
        colorbarHandle.Position = [cbLeft, cbBottom, cbWidth, cbHeight];
    end

    function position = GetFigureClientPosition()
        if isprop(fig, 'InnerPosition')
            innerPos = fig.InnerPosition;
            position = [1, 1, innerPos(3), innerPos(4)];
        else
            position = [1, 1, fig.Position(3), fig.Position(4)];
        end
    end

    function UpdateSeedSectionScrollLayout(scrollPanelHandle, contentPanelHandle, minHeight)
        if ~(isgraphics(scrollPanelHandle) && isgraphics(contentPanelHandle))
            return;
        end

        if isprop(scrollPanelHandle, 'InnerPosition')
            outerPos = scrollPanelHandle.InnerPosition;
        else
            outerPos = scrollPanelHandle.Position;
        end

        contentWidth = max(1, outerPos(3) - 16);
        contentHeight = max(minHeight, outerPos(4) + 1);
        contentPanelHandle.Position = [1, 1, contentWidth, contentHeight];
    end

    function UpdateCursorInfoSectionLayout()
        UpdateSeedSectionScrollLayout(cursorHoverScrollPanel, cursorHoverContentPanel, cursorHoverContentMinHeight);
        UpdateSeedSectionScrollLayout(cursorSelectedScrollPanel, cursorSelectedContentPanel, cursorSelectedContentMinHeight);
    end

    function UpdateStatusSectionLayout()
        UpdateSeedSectionScrollLayout(statusScrollPanel, statusContentPanel, statusContentMinHeight);
    end

    function UpdateSeedToolSectionLayouts()
        UpdateSeedSectionScrollLayout(seedNumericalScrollPanel, seedNumericalContentPanel, seedNumericalContentMinHeight);
        UpdateSeedSectionScrollLayout(seedNoiseScrollPanel, seedNoiseContentPanel, seedNoiseContentMinHeight);
        UpdateSeedSectionScrollLayout(seedPredictionScrollPanel, seedPredictionContentPanel, seedPredictionContentMinHeight);
        UpdateSeedSectionScrollLayout(seedSolveScrollPanel, seedSolveContentPanel, seedSolveContentMinHeight);
    end

    function UpdateContinuationActionLayout()
        if ~(isgraphics(continuationActionPanel) && isgraphics(continuationActionContentPanel))
            return;
        end

        if isprop(continuationActionPanel, 'InnerPosition')
            panelPosition = continuationActionPanel.InnerPosition;
        else
            panelPosition = continuationActionPanel.Position;
        end
        if panelPosition(3) <= 1 || panelPosition(4) <= 1
            return;
        end

        contentWidth = max(1, panelPosition(3) - 4);
        contentHeight = max(continuationActionContentMinHeight, panelPosition(4) + 1);
        continuationActionContentPanel.Position = [1, 1, contentWidth, contentHeight];
    end

    function UpdateParameterActionLayout()
        if ~(isgraphics(parameterActionPanel) && isgraphics(parameterActionContentPanel))
            return;
        end

        if isprop(parameterActionPanel, 'InnerPosition')
            panelPosition = parameterActionPanel.InnerPosition;
        else
            panelPosition = parameterActionPanel.Position;
        end
        if panelPosition(3) <= 1 || panelPosition(4) <= 1
            return;
        end

        contentWidth = max(1, panelPosition(3) - 4);
        contentHeight = max(parameterActionContentMinHeight, panelPosition(4) + 1);
        parameterActionContentPanel.Position = [1, 1, contentWidth, contentHeight];
    end

    function UpdateScanActionLayout()
        if ~(isgraphics(scanActionPanel) && isgraphics(scanActionContentPanel))
            return;
        end

        if isprop(scanActionPanel, 'InnerPosition')
            panelPosition = scanActionPanel.InnerPosition;
        else
            panelPosition = scanActionPanel.Position;
        end
        if panelPosition(3) <= 1 || panelPosition(4) <= 1
            return;
        end

        contentWidth = max(1, panelPosition(3) - 4);
        contentHeight = max(scanActionContentMinHeight, panelPosition(4) + 1);
        scanActionContentPanel.Position = [1, 1, contentWidth, contentHeight];
    end

    function RefreshContinuationActionLayout()
        % SelectionChanged fires before a newly selected tab has necessarily
        % completed its first layout pass.  Force that pass before measuring
        % the visualization tab's pixel extent.
        drawnow;
        UpdateContinuationActionLayout();
        UpdateParameterActionLayout();
        UpdateScanActionLayout();
        UpdateSolutionVisualizationLayout();
    end

    function FigureResized()
        if ~exist('mainContainer', 'var') || ~isgraphics(mainContainer)
            return;
        end
        mainContainer.Position = GetFigureClientPosition();
        UpdateStatusSectionLayout();
        UpdateSeedToolSectionLayouts();
        UpdateCursorInfoSectionLayout();
        UpdateContinuationActionLayout();
        UpdateParameterActionLayout();
        UpdateScanActionLayout();
        UpdateSolutionVisualizationLayout();
        PositionColorbar();
    end

    function InitializeSolutionVisualization()
        if isempty(cursorSelection.results) || isempty(cursorSelection.index)
            ClearSolutionVisualization();
            return;
        end
        signatureWeights = (1:numel(cursorSelection.X))';
        selectionKey = sprintf('%s:%d:%.15g', cursorSelection.datasetName, cursorSelection.index, ...
            sum(cursorSelection.X(:) .* signatureWeights));
        if strcmp(selectionKey, visualizationSelectionKey) && ~isempty(visualizationT)
            return;
        end
        StopVisualization();
        try
            X = cursorSelection.X(:);
            Para = cursorSelection.Para(:);
            [~, visualizationT, visualizationY, visualizationP, visualizationGRF, ~] = ...
                Quadrupedal_ZeroFun_v2(X, Para);
            [~, ~, visualizationColor, ~] = Gait_Identification(cursorSelection.results(:, cursorSelection.index));
            cla(animationAxes(1), 'reset'); cla(animationAxes(2), 'reset');
            for iAxis = 1:numel(trajectoryAxes), cla(trajectoryAxes(iAxis), 'reset'); end
            options = VisualizationDefaultOptions(struct('AnimationMode', 'Detailed'));
            visualizationObjects.Animation = SLIP_Animation_Quad(visualizationP, animationAxes(1).Position, animationAxes(1), options);
            visualizationObjects.Orbit = SLIP_PeriodicOrbit_Quad(visualizationY, animationAxes(2).Position, animationAxes(2), visualizationColor);
            visualizationObjects.Trajectories = SLIP_Trajectories_Quad(visualizationT, visualizationY, trajectoryAxes(1:3));
            visualizationObjects.GRF = SLIP_GRF_Quad(visualizationT, visualizationGRF, trajectoryAxes(4));
            visualizationSelectionKey = selectionKey;
            visualizationSlider.Value = 0;
            visualizationTimeInput.Value = 0;
            SetVisualizationControlsEnabled(true);
            visualizationStatusLabel.Text = sprintf('%s, solution %d', cursorSelection.datasetName, cursorSelection.index);
            UpdateSolutionVisualizationLayout();
            UpdateSolutionVisualizationFrame(0);
        catch ME
            ClearSolutionVisualization();
            visualizationStatusLabel.Text = ['Unable to initialize visualization: ' ME.message];
        end
    end

    function ClearSolutionVisualization()
        StopVisualization();
        CloseVisualizationRecording();
        visualizationT = []; visualizationY = []; visualizationP = []; visualizationGRF = [];
        visualizationSelectionKey = '';
        visualizationObjects = struct('Animation', [], 'Orbit', [], 'Trajectories', [], 'GRF', []);
        if exist('animationAxes', 'var')
            for iAxis = 1:numel(animationAxes)
                if isgraphics(animationAxes(iAxis)), cla(animationAxes(iAxis), 'reset'); end
            end
        end
        if exist('trajectoryAxes', 'var')
            for iAxis = 1:numel(trajectoryAxes)
                if isgraphics(trajectoryAxes(iAxis)), cla(trajectoryAxes(iAxis), 'reset'); end
            end
        end
        if exist('visualizationSlider', 'var') && isgraphics(visualizationSlider)
            visualizationSlider.Value = 0; visualizationTimeInput.Value = 0;
            visualizationStatusLabel.Text = 'Select a branch solution to enable visualization.';
            SetVisualizationControlsEnabled(false);
        end
    end

    function SetVisualizationControlsEnabled(enabled)
        state = VisualizationOnOff(enabled);
        visualizationRunButton.Enable = state;
        visualizationSettingsButton.Enable = state;
        anyRecording = visualizationRecordSettings.GIF || visualizationRecordSettings.Video || visualizationRecordSettings.Keyframes;
        visualizationStopButton.Enable = VisualizationOnOff(enabled && (visualizationPlaying || anyRecording));
        visualizationSlider.Enable = VisualizationOnOff(enabled && ~anyRecording && ~visualizationPlaying);
        visualizationTimeInput.Enable = visualizationSlider.Enable;
    end

    function VisualizationSliderChanged(value)
        if isempty(visualizationT), return; end
        value = round(min(max(value, 0), 1), 2);
        visualizationSlider.Value = value; visualizationTimeInput.Value = value;
        UpdateSolutionVisualizationFrame(value * visualizationT(end));
    end

    function VisualizationTimeChanged(value)
        VisualizationSliderChanged(value);
    end

    function UpdateSolutionVisualizationFrame(t)
        if isempty(visualizationT), return; end
        t = min(max(t, 0), visualizationT(end));
        y = interp1(visualizationT' + linspace(0, 1e-5, numel(visualizationT)), visualizationY, t, 'linear', 'extrap');
        mask = visualizationT <= t; if ~any(mask), mask(1) = true; end
        try
            visualizationObjects.Animation.update(t, y, visualizationP);
            visualizationObjects.Orbit.update(y);
            if visualizationFrameSettings.Torso || visualizationFrameSettings.Legs
                visualizationObjects.Trajectories.update(visualizationT(mask), visualizationY(mask,:), ...
                    visualizationFrameSettings.Torso, visualizationFrameSettings.Legs);
            end
            if visualizationFrameSettings.GRF
                visualizationObjects.GRF.update(visualizationT(mask), visualizationGRF(mask,:));
            end
        catch ME
            if ~visualizationStopRequested, visualizationStatusLabel.Text = ['Frame update stopped: ' ME.message]; end
            visualizationStopRequested = true;
        end
    end

    function RunVisualization()
        if isempty(visualizationT) || visualizationPlaying, return; end
        CloseVisualizationRecording();
        visualizationPlaying = true; visualizationStopRequested = false;
        SetVisualizationControlsEnabled(true);
        startNorm = visualizationSlider.Value;
        if startNorm >= 1, startNorm = 0; visualizationSlider.Value = 0; visualizationTimeInput.Value = 0; end
        PrepareVisualizationRecording();
        norms = linspace(startNorm, 1, max(2, round((1-startNorm)*120)));
        try
            for iFrame = 1:numel(norms)
                frameStart = tic;
                if visualizationStopRequested || ~isgraphics(fig), break; end
                visualizationSlider.Value = norms(iFrame);
                visualizationTimeInput.Value = round(norms(iFrame), 2);
                UpdateSolutionVisualizationFrame(norms(iFrame) * visualizationT(end));
                drawnow limitrate;
                CaptureVisualizationFrame();
                remaining = 1/visualizationFPS - toc(frameStart); if remaining > 0, pause(remaining); end
            end
            if visualizationRecordSettings.Keyframes && ~visualizationStopRequested
                RecordVisualizationKeyframes();
            end
        catch ME
            if isgraphics(fig), visualizationStatusLabel.Text = ['Playback stopped: ' ME.message]; end
        end
        visualizationPlaying = false;
        CloseVisualizationRecording();
        if isgraphics(fig), SetVisualizationControlsEnabled(~isempty(visualizationT)); end
    end

    function StopVisualization()
        visualizationStopRequested = true;
        visualizationPlaying = false;
        CloseVisualizationRecording();
        if exist('visualizationRunButton', 'var') && isgraphics(visualizationRunButton)
            SetVisualizationControlsEnabled(~isempty(visualizationT));
        end
    end

    function OpenVisualizationSettings()
        if isempty(visualizationT), return; end
        dlg = uifigure('Name', 'Visualization Settings', 'Position', ...
            [fig.Position(1)+80 fig.Position(2)+100 430 310], 'WindowStyle', 'modal', 'Resize', 'off');
        grid = uigridlayout(dlg, [8 2]); grid.RowHeight = repmat({'fit'}, 1, 8);
        uilabel(grid, 'Text', 'Frame-by-frame updates', 'FontWeight', 'bold'); uilabel(grid, 'Text', 'Recording', 'FontWeight', 'bold');
        cbTorso = uicheckbox(grid, 'Text', 'Torso trajectories', 'Value', visualizationFrameSettings.Torso);
        cbGIF = uicheckbox(grid, 'Text', 'GIF', 'Value', visualizationRecordSettings.GIF);
        cbLegs = uicheckbox(grid, 'Text', 'Leg trajectories', 'Value', visualizationFrameSettings.Legs);
        cbVideo = uicheckbox(grid, 'Text', 'Video (.mp4)', 'Value', visualizationRecordSettings.Video);
        cbGRF = uicheckbox(grid, 'Text', 'Ground reaction force', 'Value', visualizationFrameSettings.GRF);
        cbKeys = uicheckbox(grid, 'Text', 'Animation keyframes (.pdf)', 'Value', visualizationRecordSettings.Keyframes);
        note = uilabel(grid, 'Text', 'Animation and periodic orbit always update. Recording locks direct time controls.', 'WordWrap', 'on');
        note.Layout.Row = [5 7]; note.Layout.Column = [1 2];
        ok = uibutton(grid, 'Text', 'OK', 'ButtonPushedFcn', @(~,~) ApplySettings()); ok.Layout.Row = 8; ok.Layout.Column = [1 2];
        function ApplySettings()
            previous = visualizationFrameSettings;
            visualizationFrameSettings = struct('Torso', cbTorso.Value, 'Legs', cbLegs.Value, 'GRF', cbGRF.Value);
            visualizationRecordSettings = struct('GIF', cbGIF.Value, 'Video', cbVideo.Value, 'Keyframes', cbKeys.Value);
            tNow = visualizationSlider.Value * visualizationT(end); mask = visualizationT <= tNow; if ~any(mask), mask(1)=true; end
            if previous.Torso && ~visualizationFrameSettings.Torso, visualizationObjects.Trajectories.update(visualizationT, visualizationY, true, false); end
            if previous.Legs && ~visualizationFrameSettings.Legs, visualizationObjects.Trajectories.update(visualizationT, visualizationY, false, true); end
            if previous.GRF && ~visualizationFrameSettings.GRF, visualizationObjects.GRF.update(visualizationT, visualizationGRF); end
            if ~previous.Torso && visualizationFrameSettings.Torso, visualizationObjects.Trajectories.update(visualizationT(mask), visualizationY(mask,:), true, false); end
            if ~previous.Legs && visualizationFrameSettings.Legs, visualizationObjects.Trajectories.update(visualizationT(mask), visualizationY(mask,:), false, true); end
            if ~previous.GRF && visualizationFrameSettings.GRF, visualizationObjects.GRF.update(visualizationT(mask), visualizationGRF(mask,:)); end
            SetVisualizationControlsEnabled(true); delete(dlg);
        end
    end

    function PrepareVisualizationRecording()
        anyCapture = visualizationRecordSettings.GIF || visualizationRecordSettings.Video;
        if ~anyCapture, return; end
        stem = regexprep(sprintf('%s_sol%d', cursorSelection.datasetName, cursorSelection.index), '[^a-zA-Z0-9_-]', '_');
        if visualizationRecordSettings.GIF
            outDir = fullfile(currentfolder, 'GIF'); if ~isfolder(outDir), mkdir(outDir); end
            visualizationRecording.gifPath = fullfile(outDir, [stem '_visualization.gif']);
            if isfile(visualizationRecording.gifPath), delete(visualizationRecording.gifPath); end
            visualizationRecording.gifFirst = true;
        end
        if visualizationRecordSettings.Video
            outDir = fullfile(currentfolder, 'Video'); if ~isfolder(outDir), mkdir(outDir); end
            visualizationRecording.video = VideoWriter(fullfile(outDir, [stem '_visualization.mp4']), 'MPEG-4');
            visualizationRecording.video.FrameRate = visualizationFPS; open(visualizationRecording.video);
            visualizationRecording.videoOpen = true;
        end
    end

    function CaptureVisualizationFrame()
        if ~(visualizationRecordSettings.GIF || visualizationRecordSettings.Video), return; end
        frame = getframe(fig); imageData = frame2im(frame);
        imageData = imageData(1:end-mod(size(imageData,1),2), 1:end-mod(size(imageData,2),2), :);
        if visualizationRecordSettings.GIF
            [indexed, map] = rgb2ind(imageData, 256);
            if visualizationRecording.gifFirst
                imwrite(indexed, map, visualizationRecording.gifPath, 'gif', 'LoopCount', inf, 'DelayTime', 1/visualizationFPS);
                visualizationRecording.gifFirst = false;
            else
                imwrite(indexed, map, visualizationRecording.gifPath, 'gif', 'WriteMode', 'append', 'DelayTime', 1/visualizationFPS);
            end
        end
        if visualizationRecording.videoOpen, writeVideo(visualizationRecording.video, imageData); end
    end

    function RecordVisualizationKeyframes()
        outDir = fullfile(currentfolder, 'Keyframes'); if ~isfolder(outDir), mkdir(outDir); end
        stem = regexprep(sprintf('%s_sol%d', cursorSelection.datasetName, cursorSelection.index), '[^a-zA-Z0-9_-]', '_');
        times = unique(sort([visualizationP(1:min(9,numel(visualizationP))); visualizationT(round(end/2))]));
        for iFrame = 1:numel(times)
            if visualizationStopRequested, break; end
            y = interp1(visualizationT' + linspace(0,1e-5,numel(visualizationT)), visualizationY, times(iFrame), 'linear', 'extrap');
            visualizationObjects.Animation.update(times(iFrame)+.001, y, visualizationP);
            exportgraphics(animationAxes(1), fullfile(outDir, sprintf('%s_f%d.pdf', stem, iFrame)), 'ContentType', 'vector');
        end
    end

    function CloseVisualizationRecording()
        if visualizationRecording.videoOpen
            try, close(visualizationRecording.video); catch, end
        end
        visualizationRecording = struct('video', [], 'videoOpen', false, 'gifPath', '', 'gifFirst', true);
    end

    function UpdateSolutionVisualizationLayout()
        if ~exist('visualizationTabs', 'var') || ~isgraphics(visualizationTabs), return; end
        % A throttled draw can leave the tab group at its construction-time
        % size.  Full drawnow is required here because these dimensions drive
        % the fixed-aspect plot containers and scroll extents.
        drawnow;
        tabPos = getpixelposition(visualizationTabs, true);
        width = max(260, tabPos(3)-12); height = max(180, tabPos(4)-42);
        animationScrollPanel.Position = [1 1 width height]; trajectoryScrollPanel.Position = [1 1 width height];
        margin = 2; gap = 12; axisWidth = max(240, width-2*margin);
        plotWidth = max(1, axisWidth-10);
        animationHeight = round(plotWidth * 3/4) + 30;
        animationContentHeight = max(height+1, 2*animationHeight+3*gap);
        animationContentPanel.Position = [1 1 width animationContentHeight];
        for iAxis = 1:2
            y = animationContentHeight-gap-iAxis*animationHeight-(iAxis-1)*gap;
            animationAxesPanels(iAxis).Position = [margin y axisWidth animationHeight];
        end
        fullPlotHeight = round(plotWidth * 3/4) + 30;
        legPlotHeight = round(plotWidth * 3/8) + 30;
        legSectionHeight = 2*legPlotHeight + gap + 28;
        trajectoryContentHeight = max(height, 2*fullPlotHeight+legSectionHeight+4*gap);
        trajectoryContentPanel.Position = [1 1 width trajectoryContentHeight];
        y = trajectoryContentHeight-gap-fullPlotHeight;
        torsoTrajectoryPanel.Position = [margin y axisWidth fullPlotHeight];
        y = y-gap-legSectionHeight;
        legTrajectoriesPanel.Position = [margin y axisWidth legSectionHeight];
        legInnerHeight = legSectionHeight-28;
        trajectoryAxesPanels(2).Position = [4 legInnerHeight-legPlotHeight axisWidth-8 legPlotHeight];
        trajectoryAxesPanels(3).Position = [4 0 axisWidth-8 legPlotHeight];
        y = y-gap-fullPlotHeight;
        grfTrajectoryPanel.Position = [margin y axisWidth fullPlotHeight];
    end

    function DisableVisualizationAxesToolbar(axisHandle)
        try, axtoolbar(axisHandle, {}); catch, end
        if isprop(axisHandle, 'Toolbar') && ~isempty(axisHandle.Toolbar), axisHandle.Toolbar.Visible = 'off'; end
    end

    function dataset = ResolveActiveOscillatorDataset()
        dataset = [];
        if isempty(selectedDatasetHandle)
            return;
        end
        datasetIndex = FindPlottedDatasetByName(selectedDatasetHandle);
        if isempty(datasetIndex)
            return;
        end
        candidate = plottedDatasets{datasetIndex};
        if ~isfield(candidate, 'results') || ~isnumeric(candidate.results) || ...
                size(candidate.results, 1) < 22 || isempty(candidate.results)
            return;
        end
        dataset = candidate;
    end

    function SyncOscillatorFromMainSelection()
        dataset = ResolveActiveOscillatorDataset();
        if isempty(dataset)
            ClearOscillatorState();
            return;
        end
        if oscillatorPlaying && ~strcmp(oscillatorDatasetName, dataset.filename)
            StopOscillatorPlayback(false);
        end
        index = 1;
        if strcmp(cursorSelection.datasetName, dataset.filename) && ...
                ~isempty(cursorSelection.index)
            index = cursorSelection.index;
        elseif strcmp(oscillatorDatasetName, dataset.filename)
            index = oscillatorIndex;
        end
        index = min(max(round(index), 1), size(dataset.results, 2));
        oscillatorDatasetName = dataset.filename;
        UpdateOscillatorCycles(dataset.results, index);
    end

    function ClearOscillatorState()
        StopOscillatorPlayback(false);
        oscillatorDatasetName = '';
        oscillatorIndex = 1;
        oscillatorHandles = struct();
        if isgraphics(oscillatorAx)
            cla(oscillatorAx);
            title(oscillatorAx, 'Oscillator Cycles');
            xlim(oscillatorAx, [-2*oscillatorPos 2*oscillatorPos]);
            ylim(oscillatorAx, [-2*oscillatorPos 2*oscillatorPos]);
            pbaspect(oscillatorAx, [1 1 1]);
            oscillatorAx.XTick = [];
            oscillatorAx.YTick = [];
            oscillatorAx.Box = 'on';
            hold(oscillatorAx, 'on');
        end
        if isgraphics(oscillatorIndexSlider)
            oscillatorIndexSlider.Limits = [1 2];
            oscillatorIndexSlider.Value = 1;
            oscillatorIndexInput.Value = 1;
            oscillatorTotalLabel.Text = '/ 0';
        end
        RefreshOscillatorControls(false);
    end

    function InitializeOscillatorGraphics()
        cla(oscillatorAx);
        title(oscillatorAx, 'Oscillator Cycles');
        xlim(oscillatorAx, [-2*oscillatorPos 2*oscillatorPos]);
        ylim(oscillatorAx, [-2*oscillatorPos 2*oscillatorPos]);
        pbaspect(oscillatorAx, [1 1 1]);
        oscillatorAx.XTick = [];
        oscillatorAx.YTick = [];
        oscillatorAx.Box = 'on';
        hold(oscillatorAx, 'on');
        plot(oscillatorAx, [0 0], [-2*oscillatorPos 2*oscillatorPos], ...
            '-', 'LineWidth', 0.5*oscillatorLineWidth, 'Color', [0 0 0], 'HitTest', 'off');
        plot(oscillatorAx, [-2*oscillatorPos 2*oscillatorPos], [0 0], ...
            '-', 'LineWidth', 0.5*oscillatorLineWidth, 'Color', [0 0 0], 'HitTest', 'off');
        oscillatorHandles.FR = CreateEmbeddedOscillator('FR');
        oscillatorHandles.FL = CreateEmbeddedOscillator('FL');
        oscillatorHandles.BL = CreateEmbeddedOscillator('BL');
        oscillatorHandles.BR = CreateEmbeddedOscillator('BR');
        legNames = {'FL', 'FR', 'BL', 'BR'};
        for legNameIndex = 1:numel(legNames)
            legCenter = OscillatorLegCenter(legNames{legNameIndex});
            text(oscillatorAx, legCenter(1), legCenter(2)+1.35*oscillatorRadius, ...
                legNames{legNameIndex}, 'HorizontalAlignment', 'center', ...
                'FontSize', oscillatorAx.Title.FontSize, 'FontWeight', 'bold', ...
                'HitTest', 'off');
        end
    end

    function oscillator = CreateEmbeddedOscillator(leg)
        center = OscillatorLegCenter(leg);
        theta = linspace(0, 2*pi, 500);
        oscillator.Cycle = plot(oscillatorAx, ...
            oscillatorRadius*cos(theta)+center(1), oscillatorRadius*sin(theta)+center(2), ...
            'Color', [0 0 0], 'LineWidth', oscillatorLineWidth, 'HitTest', 'off');
        oscillator.Base = plot(oscillatorAx, [center(1) center(1)], ...
            [center(2) center(2)+oscillatorRadius], '--', 'Color', [0.8 0.8 0.8], ...
            'LineWidth', oscillatorLineWidth, 'HitTest', 'off');
        oscillator.Stance = patch(oscillatorAx, NaN, NaN, [0.8 0.8 0.8], ...
            'EdgeColor', 'none', 'HitTest', 'off');
        oscillator.TD = plot(oscillatorAx, center(1), center(2), 'r-', ...
            'LineWidth', oscillatorLineWidth, 'HitTest', 'off');
        oscillator.LO = plot(oscillatorAx, center(1), center(2), 'b-', ...
            'LineWidth', oscillatorLineWidth, 'HitTest', 'off');
        oscillator.TextTD = text(oscillatorAx, center(1)-0.8*oscillatorRadius, ...
            center(2)-1.5*oscillatorRadius, '', 'FontSize', 10, 'HitTest', 'off');
        oscillator.TextLO = text(oscillatorAx, center(1)-0.8*oscillatorRadius, ...
            center(2)-2.2*oscillatorRadius, '', 'FontSize', 10, 'HitTest', 'off');
    end

    function center = OscillatorLegCenter(leg)
        switch leg
            case 'FR', center = [oscillatorPos oscillatorPos];
            case 'FL', center = [-oscillatorPos oscillatorPos];
            case 'BL', center = [-oscillatorPos -oscillatorPos];
            otherwise, center = [oscillatorPos -oscillatorPos];
        end
    end

    function UpdateOscillatorCycles(branchResults, index)
        count = size(branchResults, 2);
        if count < 1 || index < 1 || index > count || ...
                any(~isfinite(branchResults(14:22, index))) || branchResults(22, index) <= 0
            ClearOscillatorState();
            return;
        end
        if ~isfield(oscillatorHandles, 'FR') || ~isgraphics(oscillatorHandles.FR.Cycle)
            InitializeOscillatorGraphics();
        end
        oscillatorIndex = min(max(round(index), 1), count);
        oscillatorIndexSlider.Limits = [1 max(2, count)];
        oscillatorIndexSlider.Value = oscillatorIndex;
        oscillatorIndexInput.Limits = [1 max(2, count)];
        oscillatorIndexInput.Value = oscillatorIndex;
        oscillatorTotalLabel.Text = sprintf('/ %d', count);
        [cFR, cFL, cBL, cBR] = EmbeddedOscillatorColors(branchResults, oscillatorIndex);
        SetEmbeddedOscillator(oscillatorHandles.FR, 'FR', branchResults(:, oscillatorIndex), cFR);
        SetEmbeddedOscillator(oscillatorHandles.FL, 'FL', branchResults(:, oscillatorIndex), cFL);
        SetEmbeddedOscillator(oscillatorHandles.BL, 'BL', branchResults(:, oscillatorIndex), cBL);
        SetEmbeddedOscillator(oscillatorHandles.BR, 'BR', branchResults(:, oscillatorIndex), cBR);
        RefreshOscillatorControls(true);
    end

    function SetEmbeddedOscillator(oscillator, leg, solution, color)
        switch leg
            case 'FR', timingIndices = [20 21];
            case 'FL', timingIndices = [16 17];
            case 'BL', timingIndices = [14 15];
            otherwise, timingIndices = [18 19];
        end
        center = OscillatorLegCenter(leg);
        phaseOffset = 2*pi*solution(20)/solution(22);
        alphaTD = 2*pi*solution(timingIndices(1))/solution(22) + phaseOffset;
        alphaLO = 2*pi*solution(timingIndices(2))/solution(22) + phaseOffset;
        oscillator.Cycle.Color = color;
        oscillator.TD.XData = [center(1), center(1)+oscillatorRadius*cos(alphaTD)];
        oscillator.TD.YData = [center(2), center(2)+oscillatorRadius*sin(alphaTD)];
        oscillator.LO.XData = [center(1), center(1)+oscillatorRadius*cos(alphaLO)];
        oscillator.LO.YData = [center(2), center(2)+oscillatorRadius*sin(alphaLO)];
        arcStart = mod(alphaTD, 2*pi);
        arcEnd = mod(alphaLO, 2*pi);
        if arcEnd < arcStart, arcEnd = arcEnd + 2*pi; end
        arc = linspace(arcStart, arcEnd, 100);
        oscillator.Stance.XData = [center(1), center(1)+oscillatorRadius*cos(arc), center(1)];
        oscillator.Stance.YData = [center(2), center(2)+oscillatorRadius*sin(arc), center(2)];
        oscillator.TextTD.String = sprintf('%s TD: %.2f', leg, solution(timingIndices(1))/solution(22));
        oscillator.TextLO.String = sprintf('%s LO: %.2f', leg, solution(timingIndices(2))/solution(22));
    end

    function [cFR, cFL, cBL, cBR] = EmbeddedOscillatorColors(branchResults, index)
        cFR=[0 0 0]; cFL=[0 0 0]; cBL=[0 0 0]; cBR=[0 0 0];
        if abs(branchResults(20,index)-branchResults(16,index))<.02 && abs(branchResults(21,index)-branchResults(17,index))<.02, cFL=[.929 .694 .125]; cFR=cFL; end
        if abs(branchResults(14,index)-branchResults(18,index))<.02 && abs(branchResults(15,index)-branchResults(19,index))<.02, cBR=[.85 .325 .098]; cBL=cBR; end
        if abs(branchResults(20,index)-branchResults(14,index))<.02 && abs(branchResults(21,index)-branchResults(15,index))<.02, cFR=[1 1 0]; cBL=cFR; end
        if abs(branchResults(20,index)-branchResults(18,index))<.02 && abs(branchResults(21,index)-branchResults(19,index))<.02, cFR=[1 1 0]; cBR=cFR; end
        if abs(branchResults(16,index)-branchResults(14,index))<.02 && abs(branchResults(17,index)-branchResults(15,index))<.02, cFL=[1 1 0]; cBL=cFL; end
        if abs(branchResults(16,index)-branchResults(18,index))<.02 && abs(branchResults(17,index)-branchResults(19,index))<.02, cFL=[1 1 0]; cBR=cFL; end
    end

    function OscillatorIndexChanged(value)
        dataset = ResolveActiveOscillatorDataset();
        if isempty(dataset), ClearOscillatorState(); return; end
        SelectOscillatorSolution(min(max(round(value), 1), size(dataset.results, 2)));
    end

    function SelectOscillatorSolution(index)
        dataset = ResolveActiveOscillatorDataset();
        if isempty(dataset), ClearOscillatorState(); return; end
        index = min(max(round(index), 1), size(dataset.results, 2));
        [xCoord, yCoord, zCoord] = GetSolutionCoordinates(dataset.results(1:22, index));
        position = [xCoord yCoord zCoord];
        cursorSelection = BuildCursorSelection(dataset.filename, dataset.results, index, position, dataset.handle);
        seedManualIndex = index;
        UpdateOscillatorCycles(dataset.results, index);
        RefreshSelectedSolutionVisualization();
        hoverSelection = MakeEmptyCursorSelection();
        RefreshCursorInfoDisplay();
        RefreshSeedContextLabel();
        UpdateContinuationSeedSourceControls();
        UpdateParameterOperationLabels();
    end

    function StartOscillatorPlayback()
        if oscillatorPlaying, return; end
        dataset = ResolveActiveOscillatorDataset();
        if isempty(dataset), ClearOscillatorState(); return; end
        oscillatorPlaying = true;
        oscillatorGifFirstFrame = true;
        oscillatorGifPath = '';
        if oscillatorGifEnabled
            oscillatorGifPath = fullfile(currentfolder, oscillatorGifFilename);
        end
        RefreshOscillatorControls(true);
        SelectOscillatorSolution(oscillatorIndex);
        try
            AppendOscillatorGifFrame();
            period = max(0.02, 10^-oscillatorSpeedSlider.Value);
            oscillatorTimer = timer('ExecutionMode', 'fixedSpacing', 'BusyMode', 'drop', ...
                'Period', period, 'TimerFcn', @(~, ~) OscillatorPlaybackTick(), ...
                'ErrorFcn', @(~, e) OscillatorPlaybackError(e));
            start(oscillatorTimer);
        catch ME
            StopOscillatorPlayback(false);
            uialert(fig, ME.message, 'Oscillator Playback Error');
        end
    end

    function OscillatorPlaybackTick()
        if ~oscillatorPlaying || ~isgraphics(fig), StopOscillatorPlayback(false); return; end
        dataset = ResolveActiveOscillatorDataset();
        if isempty(dataset) || ~strcmp(dataset.filename, oscillatorDatasetName)
            StopOscillatorPlayback(false); return;
        end
        if oscillatorIndex >= size(dataset.results, 2)
            StopOscillatorPlayback(true); return;
        end
        SelectOscillatorSolution(oscillatorIndex + 1);
        drawnow limitrate;
        AppendOscillatorGifFrame();
        if oscillatorIndex >= size(dataset.results, 2), StopOscillatorPlayback(true); end
    end

    function OscillatorPlaybackError(eventData)
        message = 'Oscillator playback stopped unexpectedly.';
        try, message = eventData.Data.Message; catch, end
        StopOscillatorPlayback(false);
        if isgraphics(fig), uialert(fig, message, 'Oscillator Playback Error'); end
    end

    function StopOscillatorPlayback(completed)
        if nargin < 1, completed = false; end
        wasRecording = oscillatorPlaying && oscillatorGifEnabled && ~isempty(oscillatorGifPath);
        oscillatorPlaying = false;
        if ~isempty(oscillatorTimer)
            try, stop(oscillatorTimer); catch, end
            try, delete(oscillatorTimer); catch, end
            oscillatorTimer = [];
        end
        RefreshOscillatorControls(~isempty(ResolveActiveOscillatorDataset()));
        if wasRecording && isfile(oscillatorGifPath)
            if completed, SetStatus(['Oscillator GIF saved: ' oscillatorGifPath]);
            else, SetStatus(['Partial oscillator GIF saved: ' oscillatorGifPath]); end
        end
    end

    function RefreshOscillatorControls(hasData)
        state = VisualizationOnOff(hasData && ~oscillatorPlaying);
        oscillatorIndexSlider.Enable = state;
        oscillatorIndexInput.Enable = state;
        oscillatorPlayButton.Enable = state;
        oscillatorPauseButton.Enable = VisualizationOnOff(hasData && oscillatorPlaying);
        oscillatorSettingsButton.Enable = VisualizationOnOff(~oscillatorPlaying);
    end

    function AppendOscillatorGifFrame()
        if ~oscillatorGifEnabled || isempty(oscillatorGifPath), return; end
        frame = getframe(oscillatorAx);
        [imageData, map] = rgb2ind(frame2im(frame), 256);
        delay = max(0.02, 10^-oscillatorSpeedSlider.Value);
        if oscillatorGifFirstFrame
            imwrite(imageData, map, oscillatorGifPath, 'gif', 'LoopCount', inf, 'DelayTime', delay);
            oscillatorGifFirstFrame = false;
        else
            imwrite(imageData, map, oscillatorGifPath, 'gif', 'WriteMode', 'append', 'DelayTime', delay);
        end
    end

    function OpenOscillatorSettings()
        settingsDialog = uifigure('Name', 'Oscillator GIF Settings', 'Position', [fig.Position(1)+80 fig.Position(2)+80 360 170], ...
            'WindowStyle', 'modal', 'Resize', 'off');
        settingsGrid = uigridlayout(settingsDialog, [3, 2]);
        settingsGrid.RowHeight = {'fit', 'fit', '1x'};
        settingsGrid.ColumnWidth = {'fit', '1x'};
        enabledBox = uicheckbox(settingsGrid, 'Text', 'Record GIF during playback', 'Value', oscillatorGifEnabled);
        enabledBox.Layout.Column = [1 2];
        uilabel(settingsGrid, 'Text', 'Filename');
        filenameField = uieditfield(settingsGrid, 'text', 'Value', oscillatorGifFilename);
        buttonGrid = uigridlayout(settingsGrid, [1, 2]);
        buttonGrid.Layout.Row = 3; buttonGrid.Layout.Column = [1 2];
        buttonGrid.ColumnWidth = {'1x', '1x'}; buttonGrid.Padding = [0 8 0 0];
        uibutton(buttonGrid, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) delete(settingsDialog));
        uibutton(buttonGrid, 'Text', 'OK', 'ButtonPushedFcn', ...
            @(~, ~) ApplyOscillatorSettings(settingsDialog, enabledBox.Value, filenameField.Value));
    end

    function ApplyOscillatorSettings(settingsDialog, enabled, filename)
        filename = strtrim(char(string(filename)));
        [pathPart, stem, extension] = fileparts(filename);
        if ~isempty(pathPart) || isempty(stem) || ~any(strcmpi(extension, {'', '.gif'})) || ...
                isempty(regexp(stem, '^[A-Za-z0-9][A-Za-z0-9 _.-]*$', 'once'))
            uialert(settingsDialog, 'Enter a GIF filename without folders or path traversal.', 'Invalid Filename');
            return;
        end
        oscillatorGifEnabled = logical(enabled);
        oscillatorGifFilename = [stem '.gif'];
        delete(settingsDialog);
    end

    function options = VisualizationDefaultOptions(options)
        defaults = struct('ShowAnimation','On','ShowTrajectories','On','ShowPeriodicOrbit','On', ...
            'ShowGRF','On','ShowPhaseDiagram','Off','SaveAnimation','Off','SaveTrajectories','Off', ...
            'SavePeriodicOrbit','Off','SaveGRF','Off','AnimationRepeatTime','1');
        names = fieldnames(defaults);
        for iName = 1:numel(names), if ~isfield(options,names{iName}) || isempty(options.(names{iName})), options.(names{iName})=defaults.(names{iName}); end, end
    end

    function state = VisualizationOnOff(value)
        if value, state = 'on'; else, state = 'off'; end
    end

    function CloseMainGUI()
        StopOscillatorPlayback(false);
        visualizationStopRequested = true; visualizationPlaying = false;
        CloseVisualizationRecording();
        if isgraphics(fig), delete(fig); end
    end

    function [branchResults, flags, info] = GUINumericalContinuation1D(X1, X2, Para, Radius, branchTitle)
        X1 = EventTimingRegulation(X1(:));
        X2 = EventTimingRegulation(X2(:));
        Para = EnforcePositiveParameters(Para(:));

        branchResults(:, 1) = [X1; Para]; %#ok<AGROW>
        branchResults(:, 2) = [X2; Para]; %#ok<AGROW>
        branchResults = sortrows(branchResults.', 1).';
        liftedResults = ReliftSequenceGUI(branchResults(1:22, :));
        flags = strings(1, 2);
        RefreshTemporaryContinuationHandle(branchResults);

        for directionId = 1:2
            [branchResults, liftedResults, flag] = GUIUniDirectionSearch(branchResults, liftedResults, Radius, numOPTS, branchTitle, directionId);
            flags(directionId) = string(flag);
            if directionId == 1
                branchResults = flip(branchResults, 2);
                liftedResults = ReliftSequenceGUI(branchResults(1:22, :));
            end
        end

        info = struct();
        info.results_lifted = [liftedResults; repmat(Para, 1, size(liftedResults, 2))];
        if size(liftedResults, 2) > 1
            info.scale = LocalScaleVectorGUI(liftedResults(:, end), liftedResults(:, end - 1));
        else
            info.scale = LocalScaleVectorGUI(liftedResults(:, 1), liftedResults(:, 1));
        end
    end

    function [branchResults, liftedResults, flag] = GUIUniDirectionSearch(branchResults, liftedResults, Radius, OPTS, branchTitle, directionId)
        Para = branchResults(23:end, 1);
        radiusCurrent = Radius;
        radiusMin = max(1e-4, 0.1 * Radius);
        radiusMax = max(4 * Radius, Radius);
        stagnationTol = 0.05 * radiusMin;
        stagnationCount = 0;
        stagnationLimit = 8;
        targetIterations = 8;
        failedStepCount = 0;
        failedStepLimit = 12;
        flag = 'Maximum iteration count reached.';

        for k = 1:250
            scale = LocalScaleVectorGUI(liftedResults(:, end), liftedResults(:, end - 1));
            secant = liftedResults(:, end) - liftedResults(:, end - 1);
            secantNorm = norm(secant ./ scale);
            if secantNorm < 1e-10
                flag = 'Algorithm stopped: lifted secant collapsed.';
                break;
            end

            tangent = secant / secantNorm;
            [radiusDirection, thetaTurn] = DirectionAdaptiveRadiusGUI(liftedResults, radiusMin, radiusMax);
            radiusStep = min(radiusCurrent, radiusDirection);
            XAnchor = liftedResults(:, end) + radiusStep * tangent;
            X0 = EventTimingRegulation(XAnchor);
            tangentScaled = tangent ./ scale;

            [xFinal, fval, exitflag, output] = GUIContinuationCorrector(X0, Para, XAnchor, tangentScaled, OPTS);
            accepted = exitflag > 0 && SolutionAcceptedGUI(fval, xFinal);

            if ~accepted
                for attempt = 1:5
                    radiusTry = radiusStep / (2 ^ attempt);
                    XAnchorTry = liftedResults(:, end) + radiusTry * tangent;
                    [xTry, fTry, exitflagTry, outputTry] = GUIContinuationCorrector(XAnchorTry, Para, XAnchorTry, tangentScaled, OPTS);
                    if exitflagTry > 0 && SolutionAcceptedGUI(fTry, xTry)
                        xFinal = xTry;
                        fval = fTry;
                        output = outputTry;
                        radiusCurrent = radiusTry;
                        accepted = true;
                        break;
                    end
                end
            end

            if accepted
                XWrapped = EventTimingRegulation(xFinal);
                XLifted = LiftTimingStateToReferenceGUI(XWrapped, liftedResults(:, end));
                if ~CandidateIsNewGUI(XLifted, liftedResults, scale, radiusCurrent)
                    accepted = false;
                    failureReason = 'Algorithm stopped: duplicate solution detected near the current point.';
                end
            else
                failureReason = 'Algorithm stopped because the corrector failed to converge.';
            end

            if accepted
                liftedResults(:, end + 1) = XLifted; %#ok<AGROW>
                branchResults(:, end + 1) = [XWrapped; Para]; %#ok<AGROW>
                failedStepCount = 0;

                iterCount = SafeIterationCountGUI(output);
                if isfinite(iterCount) && iterCount > 0
                    ratio = targetIterations / iterCount;
                    radiusCurrent = min(radiusMax, max(radiusMin, radiusStep * sqrt(ratio)));
                end
                [radiusDirectionNext, ~] = DirectionAdaptiveRadiusGUI([liftedResults, XLifted], radiusMin, radiusMax);
                radiusCurrent = min(radiusCurrent, radiusDirectionNext);

                RefreshTemporaryContinuationHandle(branchResults);
                [~, ~, gaitColor, ~] = Gait_Identification(XWrapped);
                UpdateContinuationPreviewOrbit(XWrapped, Para, sprintf('%s | dir %d | point %d', branchTitle, directionId, size(branchResults, 2)), gaitColor);
                SetStatus(sprintf('%s | dir %d | point %d | speed %.4f | residual %.3e | radius %.4g | turn %.3f', ...
                    branchTitle, directionId, size(branchResults, 2), XWrapped(1), SafeResidualNormGUI(fval), radiusCurrent, thetaTurn));
            else
                failedStepCount = failedStepCount + 1;
                if radiusCurrent > radiusMin * (1 + 1e-8) && failedStepCount < failedStepLimit
                    radiusCurrent = max(radiusMin, 0.5 * radiusStep);
                    continue;
                end
                flag = failureReason;
                break;
            end

            if size(liftedResults, 2) > 3 && ThetaDiffLiftedGUI(liftedResults) > (3 / 4) * pi
                flag = 'Algorithm stopped: irregular branch direction detected.';
                break;
            end
            if size(liftedResults, 2) > 4 && ...
                    norm((liftedResults(:, end) - liftedResults(:, 1)) ./ LocalScaleVectorGUI(liftedResults(:, end), liftedResults(:, 1))) < radiusMin
                flag = 'Algorithm stopped: solution circle found.';
                break;
            end
            if CoupletGUI(branchResults(1:22, end)) ~= CoupletGUI(branchResults(1:22, end - 1))
                flag = 'Algorithm stopped: reaching a bifurcation point.';
                break;
            end
            if branchResults(1, end) > 25
                flag = 'Algorithm stopped: torso speed faster than 25.';
                break;
            end
            if branchResults(2, end) < 0.3 * Para(4)
                flag = 'Algorithm stopped: torso height smaller than 30% of leg length.';
                break;
            end
            if norm((liftedResults(:, end) - liftedResults(:, end - 1)) ./ scale) < stagnationTol
                stagnationCount = stagnationCount + 1;
                if stagnationCount >= stagnationLimit
                    flag = 'Algorithm stopped: stagnation detected in the lifted chart.';
                    break;
                end
            else
                stagnationCount = 0;
            end
        end
    end

    function [xFinal, fval, exitflag, output] = GUIContinuationCorrector(X0, Para, XAnchor, tangentScaled, OPTS)
        [xFinal, fval, exitflag, output] = fsolve(@Residual, X0, OPTS);
        function residual = Residual(X)
            residual = Quadrupedal_ZeroFun_v2(X, Para, 'skipSolve');
            residual(end + 1) = dot(X(1:22) - XAnchor(1:22), tangentScaled);
        end
    end

    function noc = CoupletGUI(X)
        noc = 0;
        if abs(WrappedTimeDifferenceGUI(X(14), X(18), X(22))) < 0.01 * X(22) && ...
                abs(WrappedTimeDifferenceGUI(X(15), X(19), X(22))) < 0.01 * X(22)
            noc = noc + 1;
        end
        if abs(WrappedTimeDifferenceGUI(X(16), X(20), X(22))) < 0.01 * X(22) && ...
                abs(WrappedTimeDifferenceGUI(X(17), X(21), X(22))) < 0.01 * X(22)
            noc = noc + 1;
        end
        if abs(WrappedTimeDifferenceGUI(X(14), X(16), X(22))) < 0.01 * X(22) && ...
                abs(WrappedTimeDifferenceGUI(X(14), X(17), X(22))) < 0.01 * X(22)
            noc = noc + 1;
        end
    end

    function thetadiff = ThetaDiffLiftedGUI(liftedResults)
        if size(liftedResults, 2) < 3
            thetadiff = 0;
            return;
        end
        thetadiff = ThetaScaledGUI(liftedResults(:, end - 2), liftedResults(:, end - 1), liftedResults(:, end));
    end

    function theta = ThetaScaledGUI(X1, X2, X3)
        scale = LocalScaleVectorGUI(X3, X2);
        d1 = (X3 - X2) ./ scale;
        d2 = (X2 - X1) ./ scale;
        n1 = norm(d1);
        n2 = norm(d2);
        if n1 < 1e-12 || n2 < 1e-12
            theta = 0;
            return;
        end
        cosTheta = dot(d1, d2) / (n1 * n2);
        cosTheta = max(-1, min(1, cosTheta));
        theta = acos(cosTheta);
    end
    function seqLifted = ReliftSequenceGUI(seqWrapped)
        seqLifted = zeros(size(seqWrapped));
        seqLifted(:, 1) = EventTimingRegulation(seqWrapped(:, 1));
        for i = 2:size(seqWrapped, 2)
            XHere = EventTimingRegulation(seqWrapped(:, i));
            seqLifted(:, i) = LiftTimingStateToReferenceGUI(XHere, seqLifted(:, i - 1));
        end
    end

    function XLift = LiftTimingStateToReferenceGUI(XIn, XRef)
        XIn = XIn(:);
        XRef = XRef(:);
        XLift = XIn;
        Tref = XIn(22);
        if ~(isfinite(Tref) && Tref > 0)
            Tref = XRef(22);
        end
        if ~(isfinite(Tref) && Tref > 0)
            return;
        end
        dt = WrappedTimeDifferenceGUI(XIn(14:21), XRef(14:21), Tref);
        XLift(14:21) = XRef(14:21) + dt;
    end

    function dt = WrappedTimeDifferenceGUI(t1, t2, T)
        if ~(isscalar(T) && isfinite(T) && T > 0)
            dt = t1 - t2;
            return;
        end
        dt = mod((t1 - t2) + 0.5 * T, T) - 0.5 * T;
    end

    function ok = SolutionAcceptedGUI(fval, X)
        if X(1) < 15
            ok = norm(fval) < 1e-9;
        else
            ok = norm(fval) < 1e-6;
        end
    end

    function ok = CandidateIsNewGUI(XCandidate, liftedResults, scale, radiusCurrent)
        stepLast = norm((XCandidate - liftedResults(:, end)) ./ scale);
        noveltyTol = max(1e-8, 1e-3 * radiusCurrent);
        ok = stepLast > noveltyTol;
    end

    function [radiusOut, thetaTurn] = DirectionAdaptiveRadiusGUI(liftedResults, radiusMin, radiusMax)
        if size(liftedResults, 2) < 3
            radiusOut = radiusMax;
            thetaTurn = 0;
            return;
        end
        thetaTurn = ThetaDiffLiftedGUI(liftedResults);
        thetaFlat = pi / 36;
        thetaSharp = pi / 3;
        if thetaTurn <= thetaFlat
            radiusOut = radiusMax;
            return;
        end
        if thetaTurn >= thetaSharp
            radiusOut = radiusMin;
            return;
        end
        turnRatio = (thetaTurn - thetaFlat) / (thetaSharp - thetaFlat);
        radiusOut = radiusMax - (radiusMax - radiusMin) * turnRatio;
    end

    function scale = LocalScaleVectorGUI(X1, X2)
        Tpair = [X1(22), X2(22)];
        Tpair = Tpair(isfinite(Tpair) & Tpair > 0);
        if isempty(Tpair)
            Tref = 1;
        else
            Tref = mean(Tpair);
        end
        timingScale = max(0.05, 0.25 * Tref);
        Tscale = max(0.1, 0.50 * Tref);
        scale = [10; 1; 1; 0.5; 0.5; ...
                 0.3; 0.3; 0.3; 0.3; ...
                 0.3; 0.3; 0.3; 0.3; ...
                 timingScale * ones(8, 1); ...
                 Tscale];
    end

    function nIter = SafeIterationCountGUI(output)
        nIter = NaN;
        if isstruct(output) && isfield(output, 'iterations')
            nIter = output.iterations;
        end
    end

    function minGap = MinimumTimingGapGUI(X)
        T = X(22);
        if ~(isfinite(T) && T > 0)
            minGap = 0;
            return;
        end
        timings = sort(mod(X(14:21), T));
        if isempty(timings)
            minGap = 0;
            return;
        end
        timings = [timings(:); timings(1) + T];
        minGap = min(diff(timings));
    end

    function resNorm = SafeResidualNormGUI(fval)
        if isempty(fval)
            resNorm = Inf;
            return;
        end
        resNorm = norm(fval);
        if ~isfinite(resNorm)
            resNorm = Inf;
        end
    end
end
