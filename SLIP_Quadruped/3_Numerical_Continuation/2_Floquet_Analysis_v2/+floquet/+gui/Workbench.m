function [fig, ui] = Workbench(datasetSource, varargin)
%WORKBENCH Build the two-tab Floquet analysis workbench.
%
%   FLOQUETANALYSISGUI() opens an empty workflow workbench. A branch or an
%   existing workflow is then selected interactively; no path or options
%   structure is required for normal use.
%
%   FIG = FLOQUETANALYSISGUI(SOURCE) loads SOURCE with
%   LoadFloquetDataset. SOURCE may be a filename or a FloquetData structure.
%
%   The top-level Workflow tab orchestrates the canonical five-stage
%   experiment workflow. The Analysis Viewer tab preserves the existing
%   precomputed-dataset viewer and never becomes a second numerical authority.
%
%   [FIG,UI] = FLOQUETANALYSISGUI(...,OPTIONS) returns stable handles and
%   test/control callbacks. OPTIONS may be a scalar structure or name/value
%   pairs. Supported fields are Visible, DataDirectory, PlaybackPeriod,
%   InitialIndex, FigureName, WorkflowConfig, and InitialMainTab.
%
%   UI.SetIndex(k), UI.SetAxisMode(mode), UI.GetState(),
%   UI.LoadDataset(source), UI.Play(), UI.Stop(), and UI.Reset() provide
%   deterministic programmatic control. MODE is 'unit-circle' or
%   'fit-current'.

    if nargin < 1
        datasetSource = [];
    end
    guiRoot = fileparts(mfilename('fullpath'));
    analysisRoot = fileparts(fileparts(guiRoot));
    floquet.internal.ensureRuntimePaths(true);
    options = ResolveGUIOptions(analysisRoot, varargin{:});

    data = [];
    datasetFile = '';
    currentIndex = 1;
    eigenvalueAxisMode = 'unit-circle';
    playing = false;
    playbackTimer = [];
    branchHandles = struct();
    floquetHandles = struct();
    indicatorHandles = struct();
    availableFiles = struct('name', {}, 'path', {});
    workflowUI = struct();

    screenSize = get(groot, 'ScreenSize');
    figureWidth = min(max(1120, 0.78 * screenSize(3)), ...
        0.95 * screenSize(3));
    figureHeight = min(max(740, 0.82 * screenSize(4)), ...
        0.92 * screenSize(4));
    figurePosition = [ ...
        max(1, 0.5 * (screenSize(3) - figureWidth)), ...
        max(1, 0.5 * (screenSize(4) - figureHeight)), ...
        figureWidth, figureHeight];

    fig = uifigure('Name', options.FigureName, ...
        'Position', figurePosition, 'Visible', options.Visible, ...
        'Scrollable', 'on', 'AutoResizeChildren', 'off', ...
        'Tag', 'FloquetAnalysisFigure');
    fig.CloseRequestFcn = @(~, ~) CloseGUI();
    fig.DeleteFcn = @(~, ~) CleanupGUIResources();

    shellGrid = uigridlayout(fig, [1 1]);
    shellGrid.RowHeight = {'1x'};
    shellGrid.ColumnWidth = {'1x'};
    shellGrid.Padding = [0 0 0 0];
    mainTabs = uitabgroup(shellGrid, 'Tag', 'FloquetMainTabs');
    workflowTab = uitab(mainTabs, 'Title', 'Analyze Workflow', ...
        'Tag', 'FloquetWorkflowMainTab');
    resultsTab = floquet.gui.AnalysisViewerTab(mainTabs);

    mainGrid = uigridlayout(resultsTab, [3, 2]);
    mainGrid.RowHeight = {104, '1x', 76};
    mainGrid.ColumnWidth = {'3.35x', '1.85x'};
    mainGrid.Padding = [12 12 12 12];
    mainGrid.RowSpacing = 10;
    mainGrid.ColumnSpacing = 12;

    dataPanel = uipanel(mainGrid, 'Title', 'Data Info');
    dataPanel.Layout.Row = 1;
    dataPanel.Layout.Column = [1 2];
    dataGrid = uigridlayout(dataPanel, [2, 1]);
    dataGrid.RowHeight = {'fit', '1x'};
    dataGrid.ColumnWidth = {'1x'};
    dataGrid.Padding = [6 6 6 6];
    dataGrid.RowSpacing = 6;

    selectionGrid = uigridlayout(dataGrid, [1, 5]);
    selectionGrid.Layout.Row = 1;
    selectionGrid.ColumnWidth = {'1.45x', 'fit', 92, 72, '1x'};
    selectionGrid.Padding = [0 0 0 0];
    selectionGrid.ColumnSpacing = 10;
    datasetDropdown = uidropdown(selectionGrid, 'Items', {'<none>'}, ...
        'Value', '<none>', 'Tag', 'FloquetDatasetDropdown');
    selectFolderButton = uibutton(selectionGrid, 'Text', 'Select Folder', ...
        'ButtonPushedFcn', @(~, ~) SelectDataFolder(), ...
        'Tag', 'FloquetSelectFolderButton');
    loadButton = uibutton(selectionGrid, 'Text', 'Load Dataset', ...
        'ButtonPushedFcn', @(~, ~) LoadSelectedDataset(), ...
        'Tag', 'FloquetLoadDatasetButton');
    refreshButton = uibutton(selectionGrid, 'Text', 'Refresh', ...
        'ButtonPushedFcn', @(~, ~) RefreshViewer(), ...
        'Tag', 'FloquetRefreshDatasetButton');
    computationStatusLabel = uilabel(selectionGrid, ...
        'Text', 'No Floquet dataset loaded.', 'WordWrap', 'on', ...
        'Tag', 'FloquetComputationStatus');

    branchInfoGrid = uigridlayout(dataGrid, [1, 4]);
    branchInfoGrid.Layout.Row = 2;
    branchInfoGrid.ColumnWidth = {'fit', '1x', 'fit', '1x'};
    branchInfoGrid.Padding = [0 0 0 0];
    branchInfoGrid.ColumnSpacing = 8;
    uilabel(branchInfoGrid, 'Text', 'Selected Branch:');
    branchNameLabel = uilabel(branchInfoGrid, 'Text', '<none>', ...
        'Tag', 'FloquetBranchNameLabel');
    uilabel(branchInfoGrid, 'Text', 'Source:');
    sourceLabel = uilabel(branchInfoGrid, 'Text', '<none>', ...
        'WordWrap', 'on', 'Tag', 'FloquetSourceLabel');

    plottingPanel = uipanel(mainGrid, 'Title', 'Plotting');
    plottingPanel.Layout.Row = 2;
    plottingPanel.Layout.Column = 1;
    plottingGrid = uigridlayout(plottingPanel, [1, 1]);
    plottingGrid.Padding = [6 6 6 6];
    plotTabs = uitabgroup(plottingGrid, 'Tag', 'FloquetPlotTabs');

    floquetTab = uitab(plotTabs, 'Title', 'Floquet Analysis', ...
        'Tag', 'FloquetAnalysisTab');
    floquetGrid = uigridlayout(floquetTab, [2, 1]);
    floquetGrid.RowHeight = {'1x', '1.15x'};
    floquetGrid.ColumnWidth = {'1x'};
    floquetGrid.Padding = [6 6 6 6];
    floquetGrid.RowSpacing = 8;

    branchAxes = uiaxes(floquetGrid, 'Tag', 'FloquetBranchAxes');
    branchAxes.Layout.Row = 1;
    title(branchAxes, 'Solution Branch Plot');
    grid(branchAxes, 'on');
    eigenvalueAxes = uiaxes(floquetGrid, 'Tag', 'FloquetEigenvalueAxes');
    eigenvalueAxes.Layout.Row = 2;
    title(eigenvalueAxes, 'Floquet Eigenvalue Plot');
    try
        axtoolbar(branchAxes, {});
        axtoolbar(eigenvalueAxes, {});
    catch
    end

    indicatorTab = uitab(plotTabs, 'Title', 'Distance Indicators', ...
        'Tag', 'FloquetIndicatorTab');
    indicatorGrid = uigridlayout(indicatorTab, [2, 1]);
    indicatorGrid.RowHeight = {'1x', '1x'};
    indicatorGrid.ColumnWidth = {'1x'};
    indicatorGrid.Padding = [6 6 6 6];
    indicatorGrid.RowSpacing = 8;
    plusDistanceAxes = uiaxes(indicatorGrid, ...
        'Tag', 'FloquetPlusOneDistanceAxes');
    plusDistanceAxes.Layout.Row = 1;
    unitDistanceAxes = uiaxes(indicatorGrid, ...
        'Tag', 'FloquetUnitCircleDistanceAxes');
    unitDistanceAxes.Layout.Row = 2;

    controlContainer = uipanel(mainGrid, 'BorderType', 'none');
    controlContainer.Layout.Row = 2;
    controlContainer.Layout.Column = 2;
    controlMainGrid = uigridlayout(controlContainer, [3, 1]);
    controlMainGrid.RowHeight = {220, '1x', 112};
    controlMainGrid.ColumnWidth = {'1x'};
    controlMainGrid.Padding = [0 0 0 0];
    controlMainGrid.RowSpacing = 8;

    controlPanel = uipanel(controlMainGrid, 'Title', 'Play and Control');
    controlPanel.Layout.Row = 1;
    controlGrid = uigridlayout(controlPanel, [4, 1]);
    controlGrid.RowHeight = {'1x', '1x', '1x', '1x'};
    controlGrid.ColumnWidth = {'1x'};
    controlGrid.Padding = [6 4 6 4];
    controlGrid.RowSpacing = 5;

    indexWrapper = uigridlayout(controlGrid, [3, 1]);
    indexWrapper.Layout.Row = 1;
    indexWrapper.RowHeight = {'0.1x', '0.8x', '0.1x'};
    indexWrapper.ColumnWidth = {'1x'};
    indexWrapper.Padding = [0 0 0 0];
    indexWrapper.RowSpacing = 0;
    indexGrid = uigridlayout(indexWrapper, [1, 4]);
    indexGrid.Layout.Row = 2;
    indexGrid.ColumnWidth = {'fit', '1x', 58, 'fit'};
    indexGrid.Padding = [0 0 0 0];
    indexGrid.ColumnSpacing = 5;
    uilabel(indexGrid, 'Text', 'Index:');
    indexSlider = uislider(indexGrid, 'Limits', [1 2], 'Value', 1, ...
        'MajorTicks', [], 'MinorTicks', [], ...
        'ValueChangingFcn', @(~, event) SetIndex(event.Value), ...
        'ValueChangedFcn', @(source, ~) SetIndex(source.Value), ...
        'Enable', 'off', 'Tag', 'FloquetIndexSlider');
    indexInputGrid = uigridlayout(indexGrid, [3, 1]);
    indexInputGrid.Layout.Column = 3;
    indexInputGrid.RowHeight = {'0.15x', '0.7x', '0.15x'};
    indexInputGrid.ColumnWidth = {'1x'};
    indexInputGrid.Padding = [0 0 0 0];
    indexInputGrid.RowSpacing = 0;
    indexInput = uieditfield(indexInputGrid, 'numeric', ...
        'Value', 1, 'RoundFractionalValues', 'on', ...
        'ValueChangedFcn', @(source, ~) SetIndex(source.Value), ...
        'Enable', 'off', 'Tag', 'FloquetIndexInput');
    indexInput.Layout.Row = 2;
    totalLabel = uilabel(indexGrid, 'Text', '/ 0', ...
        'Tag', 'FloquetIndexTotalLabel');

    speedWrapper = uigridlayout(controlGrid, [3, 1]);
    speedWrapper.Layout.Row = 2;
    speedWrapper.RowHeight = {'0.1x', '0.8x', '0.1x'};
    speedWrapper.ColumnWidth = {'1x'};
    speedWrapper.Padding = [0 0 0 0];
    speedWrapper.RowSpacing = 0;
    speedGrid = uigridlayout(speedWrapper, [1, 4]);
    speedGrid.Layout.Row = 2;
    speedGrid.ColumnWidth = {'fit', 'fit', '1x', 'fit'};
    speedGrid.Padding = [0 0 0 0];
    speedGrid.ColumnSpacing = 4;
    uilabel(speedGrid, 'Text', 'Playing Speed');
    uilabel(speedGrid, 'Text', 'Slow', 'FontSize', 10);
    speedSlider = uislider(speedGrid, 'Limits', [1 3], 'Value', 2, ...
        'MajorTicks', [], 'MinorTicks', [], ...
        'Tag', 'FloquetSpeedSlider');
    uilabel(speedGrid, 'Text', 'Fast', 'FontSize', 10);

    axisModeWrapper = uigridlayout(controlGrid, [3, 1]);
    axisModeWrapper.Layout.Row = 3;
    axisModeWrapper.RowHeight = {'0.1x', '0.8x', '0.1x'};
    axisModeWrapper.ColumnWidth = {'1x'};
    axisModeWrapper.Padding = [0 0 0 0];
    axisModeWrapper.RowSpacing = 0;
    axisModeGrid = uigridlayout(axisModeWrapper, [1, 2]);
    axisModeGrid.Layout.Row = 2;
    axisModeGrid.ColumnWidth = {'fit', '1x'};
    axisModeGrid.Padding = [0 0 0 0];
    axisModeGrid.ColumnSpacing = 5;
    uilabel(axisModeGrid, 'Text', 'Eigenvalue View');
    axisModeDropdown = uidropdown(axisModeGrid, ...
        'Items', {'Unit circle', 'Fit current'}, ...
        'Value', 'Unit circle', ...
        'ValueChangedFcn', @(source, ~) SetAxisMode(source.Value), ...
        'Enable', 'off', 'Tag', 'FloquetAxisModeDropdown');

    buttonWrapper = uigridlayout(controlGrid, [3, 1]);
    buttonWrapper.Layout.Row = 4;
    buttonWrapper.RowHeight = {'0.15x', '0.7x', '0.15x'};
    buttonWrapper.ColumnWidth = {'1x'};
    buttonWrapper.Padding = [0 0 0 0];
    buttonWrapper.RowSpacing = 0;
    buttonGrid = uigridlayout(buttonWrapper, [1, 3]);
    buttonGrid.Layout.Row = 2;
    buttonGrid.ColumnWidth = {'1x', '1x', '1x'};
    buttonGrid.Padding = [0 0 0 0];
    buttonGrid.ColumnSpacing = 5;
    playButton = uibutton(buttonGrid, 'Text', 'Play', ...
        'ButtonPushedFcn', @(~, ~) StartPlayback(), ...
        'Enable', 'off', 'Tag', 'FloquetPlayButton');
    stopButton = uibutton(buttonGrid, 'Text', 'Stop', ...
        'ButtonPushedFcn', @(~, ~) StopPlayback(), ...
        'Enable', 'off', 'Tag', 'FloquetStopButton');
    resetButton = uibutton(buttonGrid, 'Text', 'Reset', ...
        'ButtonPushedFcn', @(~, ~) ResetIndex(), ...
        'Enable', 'off', 'Tag', 'FloquetResetButton');

    pointPanel = uipanel(controlMainGrid, 'Title', 'Selected Point');
    pointPanel.Layout.Row = 2;
    pointGrid = uigridlayout(pointPanel, [1, 1]);
    pointGrid.Padding = [8 8 8 8];
    pointInfoLabel = uilabel(pointGrid, ...
        'Text', 'Load a Floquet dataset to inspect a branch point.', ...
        'WordWrap', 'on', 'VerticalAlignment', 'top', ...
        'Tag', 'FloquetPointInfoLabel');

    interpretationPanel = uipanel(controlMainGrid, ...
        'Title', 'Interpretation');
    interpretationPanel.Layout.Row = 3;
    interpretationGrid = uigridlayout(interpretationPanel, [1, 1]);
    interpretationGrid.Padding = [8 6 8 6];
    uilabel(interpretationGrid, 'WordWrap', 'on', ...
        'VerticalAlignment', 'top', 'Text', [ ...
        '+1 markers are candidate +1 Floquet degeneracies. A multiplier ' ...
        'crossing alone is not a true branch-point test.']);

    statusPanel = uipanel(mainGrid, 'Title', 'Status');
    statusPanel.Layout.Row = 3;
    statusPanel.Layout.Column = [1 2];
    statusGrid = uigridlayout(statusPanel, [1, 1]);
    statusGrid.Padding = [6 6 6 6];
    statusLabel = uilabel(statusGrid, 'Text', 'Ready.', ...
        'WordWrap', 'on', 'VerticalAlignment', 'top', ...
        'Tag', 'FloquetStatusLabel');

    workflowOptions = struct( ...
        'ConfigSource', options.WorkflowConfig, ...
        'OnOpenAnalysis', @OpenWorkflowAnalysis, ...
        'Visible', options.Visible);
    workflowUI = floquet.gui.WorkflowTab( ...
        workflowTab, fig, workflowOptions);

    ui = struct();
    ui.Figure = fig;
    ui.ShellGrid = shellGrid;
    ui.MainTabs = mainTabs;
    ui.WorkflowTab = workflowTab;
    ui.ResultsTab = resultsTab;
    ui.Workflow = workflowUI;
    ui.DatasetDropdown = datasetDropdown;
    ui.SelectFolderButton = selectFolderButton;
    ui.LoadButton = loadButton;
    ui.RefreshButton = refreshButton;
    ui.BranchAxes = branchAxes;
    ui.EigenvalueAxes = eigenvalueAxes;
    ui.PlusDistanceAxes = plusDistanceAxes;
    ui.UnitDistanceAxes = unitDistanceAxes;
    ui.IndexSlider = indexSlider;
    ui.IndexInput = indexInput;
    ui.AxisModeDropdown = axisModeDropdown;
    ui.PlayButton = playButton;
    ui.StopButton = stopButton;
    ui.ResetButton = resetButton;
    ui.PointInfoLabel = pointInfoLabel;
    ui.SetIndex = @SetIndex;
    ui.SetAxisMode = @SetAxisMode;
    ui.GetState = @GetState;
    ui.LoadDataset = @LoadDataset;
    ui.Play = @StartPlayback;
    ui.Stop = @StopPlayback;
    ui.Reset = @ResetIndex;
    ui.Step = @StepOnce;
    ui.Close = @CloseGUI;
    ui.LoadWorkflowConfig = workflowUI.LoadConfig;
    ui.GetWorkflowState = workflowUI.GetState;
    ui.RefreshWorkflow = workflowUI.Refresh;
    ui.RunWorkflowStage = workflowUI.RunStage;
    ui.ConfirmWorkflowCandidates = workflowUI.ConfirmCandidates;
    setappdata(fig, 'FloquetAnalysisUI', ui);

    RefreshDatasetList();
    ClearPlots();
    if ~isempty(datasetSource)
        LoadDataset(datasetSource);
    end
    SelectInitialMainTab();

    function SelectInitialMainTab()
        requested = lower(strtrim(options.InitialMainTab));
        if strcmp(requested, 'auto')
            if isempty(datasetSource) && isempty(options.WorkflowConfig)
                mainTabs.SelectedTab = workflowTab;
            elseif ~isempty(datasetSource)
                mainTabs.SelectedTab = resultsTab;
            else
                mainTabs.SelectedTab = workflowTab;
            end
        elseif strcmp(requested, 'workflow')
            mainTabs.SelectedTab = workflowTab;
        else
            mainTabs.SelectedTab = resultsTab;
        end
    end

    function OpenWorkflowAnalysis(source)
        LoadDataset(source);
        if isgraphics(mainTabs) && isgraphics(resultsTab)
            mainTabs.SelectedTab = resultsTab;
        end
    end

    function RefreshDatasetList()
        directory = options.DataDirectory;
        if ~isfolder(directory)
            availableFiles = struct('name', {}, 'path', {});
            datasetDropdown.Items = {'<none>'};
            datasetDropdown.Value = '<none>';
            return;
        end
        listing = dir(fullfile(directory, '*_floquet.mat'));
        [~, order] = sort(lower({listing.name}));
        listing = listing(order);
        availableFiles = repmat(struct('name', '', 'path', ''), ...
            1, numel(listing));
        for fileIndex = 1:numel(listing)
            availableFiles(fileIndex).name = listing(fileIndex).name;
            availableFiles(fileIndex).path = fullfile( ...
                listing(fileIndex).folder, listing(fileIndex).name);
        end
        if isempty(availableFiles)
            datasetDropdown.Items = {'<none>'};
            datasetDropdown.Value = '<none>';
        else
            datasetDropdown.Items = {availableFiles.name};
            datasetDropdown.Value = availableFiles(1).name;
        end
        SetStatus(sprintf('Dataset folder: %s', directory));
    end

    function RefreshViewer()
        ClearLoadedDataset();
        RefreshDatasetList();
    end

    function ClearLoadedDataset()
        StopPlayback();
        data = [];
        datasetFile = '';
        currentIndex = 1;
        branchHandles = struct();
        floquetHandles = struct();
        indicatorHandles = struct();
        branchNameLabel.Text = '<none>';
        sourceLabel.Text = '<none>';
        computationStatusLabel.Text = 'No Floquet dataset loaded.';
        pointInfoLabel.Text = ...
            'Load a Floquet dataset to inspect a branch point.';
        ClearPlots();
    end

    function SelectDataFolder()
        selected = uigetdir(options.DataDirectory, ...
            'Select Floquet dataset folder');
        if isequal(selected, 0)
            return;
        end
        options.DataDirectory = selected;
        ClearLoadedDataset();
        RefreshDatasetList();
    end

    function LoadSelectedDataset()
        selected = datasetDropdown.Value;
        match = find(strcmp(selected, {availableFiles.name}), 1);
        if isempty(match)
            uialert(fig, 'Select a *_floquet.mat dataset first.', ...
                'No Floquet Dataset');
            return;
        end
        LoadDataset(availableFiles(match).path);
    end

    function LoadDataset(source)
        StopPlayback();
        try
            [loadedData, loadInfo] = floquet.io.loadDataset(source);
        catch exception
            SetStatus(['Dataset load failed: ' exception.message]);
            if isgraphics(fig) && strcmpi(fig.Visible, 'on')
                uialert(fig, exception.message, 'Floquet Dataset Error');
            end
            rethrow(exception);
        end
        data = loadedData;
        if ischar(source) || (isstring(source) && isscalar(source))
            datasetFile = loadInfo.source_file;
        else
            datasetFile = '';
        end
        if ~isempty(datasetFile)
            [~, loadedStem, loadedExtension] = fileparts(datasetFile);
            loadedName = [loadedStem loadedExtension];
            if any(strcmp(datasetDropdown.Items, loadedName))
                datasetDropdown.Value = loadedName;
            end
        end
        branchHandles = struct();
        floquetHandles = struct();
        indicatorHandles = struct();
        currentIndex = min(max(round(options.InitialIndex), 1), ...
            numel(data.branch_index));
        branchNameLabel.Text = ResolveBranchName(data);
        if isempty(datasetFile)
            sourceLabel.Text = '<in-memory FloquetData>';
        else
            sourceLabel.Text = datasetFile;
        end
        computationStatusLabel.Text = sprintf( ...
            '%s | %d/%d points accepted', ...
            loadInfo.status, loadInfo.accepted_count, loadInfo.point_count);
        ConfigureControls();
        UpdateIndexViews();
        SetStatus(sprintf('Loaded %s (%d branch points).', ...
            ResolveBranchName(data), numel(data.branch_index)));
    end

    function SetIndex(value)
        if isempty(data)
            return;
        end
        currentIndex = min(max(round(value), 1), ...
            numel(data.branch_index));
        UpdateIndexViews();
    end

    function SetAxisMode(value)
        normalized = lower(strtrim(char(string(value))));
        switch normalized
            case {'unit circle', 'unit-circle'}
                eigenvalueAxisMode = 'unit-circle';
                axisModeDropdown.Value = 'Unit circle';
            case {'fit current', 'fit-current'}
                eigenvalueAxisMode = 'fit-current';
                axisModeDropdown.Value = 'Fit current';
            otherwise
                error('FloquetAnalysisGUI:InvalidAxisMode', ...
                    'Eigenvalue view must be Unit circle or Fit current.');
        end
        if ~isempty(data)
            UpdateIndexViews();
        end
    end

    function UpdateIndexViews()
        if isempty(data) || ~isgraphics(fig)
            return;
        end
        indexSlider.Value = currentIndex;
        indexInput.Value = currentIndex;
        [branchHandles, branchInfo] = ...
            floquet.gui.plot.updateBranch( ...
            branchAxes, data, currentIndex, branchHandles);
        [floquetHandles, eigenInfo] = ...
            floquet.gui.plot.updateSpectrum( ...
            eigenvalueAxes, data, currentIndex, floquetHandles, ...
            struct('AxisMode', eigenvalueAxisMode));
        indicatorHandles = ...
            floquet.gui.plot.updateIndicators( ...
            plusDistanceAxes, unitDistanceAxes, data, currentIndex, ...
            indicatorHandles);
        pointInfoLabel.Text = FormatPointInfo(branchInfo, eigenInfo);
        drawnow limitrate;
    end

    function ConfigureControls()
        if isempty(data)
            indexSlider.Limits = [1 2];
            indexSlider.Value = 1;
            indexInput.Limits = [1 2];
            indexInput.Value = 1;
            totalLabel.Text = '/ 0';
            SetControlEnabled(false);
            return;
        end
        count = numel(data.branch_index);
        upper = max(2, count);
        indexSlider.Limits = [1 upper];
        indexInput.Limits = [1 upper];
        totalLabel.Text = sprintf('/ %d', count);
        SetControlEnabled(true);
    end

    function SetControlEnabled(hasData)
        editable = hasData && ~playing;
        indexSlider.Enable = OnOff(editable);
        indexInput.Enable = OnOff(editable);
        playButton.Enable = OnOff(editable && numelSafe(data) > 1);
        resetButton.Enable = OnOff(editable);
        stopButton.Enable = OnOff(hasData && playing);
        speedSlider.Enable = OnOff(editable);
        axisModeDropdown.Enable = OnOff(editable);
    end

    function StartPlayback()
        if playing || isempty(data)
            return;
        end
        if currentIndex >= numel(data.branch_index)
            currentIndex = 1;
            UpdateIndexViews();
        end
        playing = true;
        SetControlEnabled(true);
        try
            period = max(0.02, options.PlaybackPeriod * ...
                10^(2 - speedSlider.Value));
            playbackTimer = timer('ExecutionMode', 'fixedSpacing', ...
                'BusyMode', 'drop', 'Period', period, ...
                'TimerFcn', @(~, ~) PlaybackTick(), ...
                'ErrorFcn', @(~, event) PlaybackError(event));
            start(playbackTimer);
            SetStatus('Floquet playback started.');
        catch exception
            StopPlayback();
            if isgraphics(fig) && strcmpi(fig.Visible, 'on')
                uialert(fig, exception.message, 'Floquet Playback Error');
            end
        end
    end

    function PlaybackTick()
        if ~playing || isempty(data) || ~isgraphics(fig)
            StopPlayback();
            return;
        end
        if currentIndex >= numel(data.branch_index)
            StopPlayback();
            return;
        end
        StepOnce();
        if currentIndex >= numel(data.branch_index)
            StopPlayback();
        end
    end

    function StepOnce()
        if isempty(data) || ~isgraphics(fig)
            return;
        end
        if currentIndex >= numel(data.branch_index)
            currentIndex = 1;
        else
            currentIndex = currentIndex + 1;
        end
        UpdateIndexViews();
    end

    function PlaybackError(eventData)
        message = 'Floquet playback stopped unexpectedly.';
        try
            message = eventData.Data.Message;
        catch
        end
        StopPlayback();
        SetStatus(message);
    end

    function StopPlayback()
        playing = false;
        CleanupPlaybackTimer();
        if isgraphics(fig)
            SetControlEnabled(~isempty(data));
        end
    end

    function CleanupPlaybackTimer()
        playing = false;
        if isempty(playbackTimer)
            return;
        end
        try
            stop(playbackTimer);
        catch
        end
        try
            delete(playbackTimer);
        catch
        end
        playbackTimer = [];
    end

    function CleanupGUIResources()
        CleanupPlaybackTimer();
        if isstruct(workflowUI) && isfield(workflowUI, 'Cleanup')
            workflowUI.Cleanup();
        end
    end

    function ResetIndex()
        StopPlayback();
        if isempty(data)
            return;
        end
        currentIndex = 1;
        UpdateIndexViews();
        SetStatus('Floquet index reset to the first branch point.');
    end

    function state = GetState()
        state = struct('Data', data, 'DatasetFile', datasetFile, ...
            'CurrentIndex', currentIndex, 'Playing', playing, ...
            'AxisMode', eigenvalueAxisMode, ...
            'BranchHandles', branchHandles, ...
            'FloquetHandles', floquetHandles, ...
            'IndicatorHandles', indicatorHandles);
    end

    function textOut = FormatPointInfo(branchInfo, eigenInfo)
        labels = branchInfo.candidate_labels;
        if isempty(labels)
            candidateText = '<none>';
        else
            candidateText = strjoin(labels, ', ');
        end
        plusValue = FormatComplex(eigenInfo.closest_plus_one_value);
        minusValue = FormatComplex(eigenInfo.closest_minus_one_value);
        if strcmp(eigenInfo.axis_mode, 'fit-current')
            axisModeText = 'Fit current';
        else
            axisModeText = 'Unit circle';
        end
        textOut = sprintf([ ...
            'Local index: %d of %d\nBranch index: %d\n' ...
            '%s: %.12g\nComputation: %s\n\n' ...
            'd_{+1}: %.6e\nd_{-1}: %.6e\nd_u: %.6e\n' ...
            'Closest to +1: %s\nClosest to -1: %s\n' ...
            'Eigenvalue view: %s\nOff-scale multipliers: %d\n\n' ...
            'Candidates: %s'], ...
            currentIndex, numel(data.branch_index), ...
            branchInfo.branch_index, ContinuationParameterName(data), ...
            branchInfo.continuation_parameter, ...
            AcceptedText(branchInfo.accepted), ...
            data.distance_plus_one(currentIndex), ...
            data.distance_minus_one(currentIndex), ...
            data.unit_circle_distance(currentIndex), ...
            plusValue, minusValue, axisModeText, ...
            eigenInfo.off_scale_count, candidateText);
    end

    function SetStatus(message)
        if isgraphics(statusLabel)
            statusLabel.Text = message;
            drawnow limitrate;
        end
    end

    function ClearPlots()
        cla(branchAxes, 'reset');
        title(branchAxes, 'Solution Branch Plot');
        xlabel(branchAxes, 'Branch index');
        grid(branchAxes, 'on');
        cla(eigenvalueAxes, 'reset');
        title(eigenvalueAxes, 'Floquet Eigenvalue Plot');
        floquet.gui.plot.unitCircle(eigenvalueAxes);
        axis(eigenvalueAxes, 'equal');
        xlim(eigenvalueAxes, [-1.25 1.25]);
        ylim(eigenvalueAxes, [-1.25 1.25]);
        cla(plusDistanceAxes, 'reset');
        title(plusDistanceAxes, '+1 distance');
        cla(unitDistanceAxes, 'reset');
        title(unitDistanceAxes, 'Unit-circle distance');
        ConfigureControls();
    end

    function CloseGUI()
        CleanupGUIResources();
        if isgraphics(fig)
            delete(fig);
        end
    end
end

function options = ResolveGUIOptions(analysisRoot, varargin)
    options = struct('Visible', 'on', ...
        'DataDirectory', fullfile(analysisRoot, 'reference_data', ...
            'viewer_datasets'), ...
        'PlaybackPeriod', 0.15, 'InitialIndex', 1, ...
        'FigureName', 'SLIP Quadruped - Floquet Workbench', ...
        'WorkflowConfig', [], 'InitialMainTab', 'auto');
    if isempty(varargin)
        supplied = struct();
    elseif isscalar(varargin) && isstruct(varargin{1}) && ...
            isscalar(varargin{1})
        supplied = varargin{1};
    elseif mod(numel(varargin), 2) == 0
        supplied = struct();
        for i = 1:2:numel(varargin)
            name = varargin{i};
            if ~(ischar(name) || (isstring(name) && isscalar(name)))
                error('FloquetAnalysisGUI:InvalidOptionName', ...
                    'Name/value option names must be text.');
            end
            supplied.(char(name)) = varargin{i + 1};
        end
    else
        error('FloquetAnalysisGUI:InvalidOptions', ...
            'Use a scalar options structure or name/value pairs.');
    end
    names = fieldnames(supplied);
    allowed = fieldnames(options);
    for i = 1:numel(names)
        match = find(strcmpi(names{i}, allowed), 1);
        if isempty(match)
            error('FloquetAnalysisGUI:UnknownOption', ...
                'Unknown GUI option ''%s''.', names{i});
        end
        options.(allowed{match}) = supplied.(names{i});
    end
    textFields = {'Visible', 'DataDirectory', 'FigureName', ...
        'InitialMainTab'};
    for i = 1:numel(textFields)
        value = options.(textFields{i});
        if isstring(value) && isscalar(value)
            value = char(value);
        end
        if ~ischar(value)
            error('FloquetAnalysisGUI:InvalidTextOption', ...
                '%s must be text.', textFields{i});
        end
        options.(textFields{i}) = value;
    end
    if ~any(strcmpi(options.Visible, {'on', 'off'}))
        error('FloquetAnalysisGUI:InvalidVisibility', ...
            'Visible must be ''on'' or ''off''.');
    end
    options.Visible = lower(options.Visible);
    options.InitialMainTab = lower(strtrim(options.InitialMainTab));
    if ~any(strcmp(options.InitialMainTab, ...
            {'auto', 'workflow', 'analysis', 'viewer'}))
        error('FloquetAnalysisGUI:InvalidInitialMainTab', ...
            'InitialMainTab must be auto, workflow, analysis, or viewer.');
    end
    if strcmp(options.InitialMainTab, 'viewer')
        options.InitialMainTab = 'analysis';
    end
    workflowConfig = options.WorkflowConfig;
    if ~(isempty(workflowConfig) || isstruct(workflowConfig) || ...
            ischar(workflowConfig) || ...
            (isstring(workflowConfig) && isscalar(workflowConfig)))
        error('FloquetAnalysisGUI:InvalidWorkflowConfig', [ ...
            'WorkflowConfig must be empty, a scalar config struct, or a ' ...
            'scalar MAT-file path. Configuration code is not executed.']);
    end
    if ~(isnumeric(options.PlaybackPeriod) && ...
            isscalar(options.PlaybackPeriod) && ...
            isfinite(options.PlaybackPeriod) && options.PlaybackPeriod > 0)
        error('FloquetAnalysisGUI:InvalidPlaybackPeriod', ...
            'PlaybackPeriod must be a positive finite scalar.');
    end
    if ~(isnumeric(options.InitialIndex) && isscalar(options.InitialIndex) && ...
            isfinite(options.InitialIndex))
        error('FloquetAnalysisGUI:InvalidInitialIndex', ...
            'InitialIndex must be a finite numeric scalar.');
    end
end

function name = ResolveBranchName(data)
    if isfield(data, 'branch_name') && ~isempty(data.branch_name)
        name = char(string(data.branch_name));
    else
        name = '<unnamed branch>';
    end
end

function name = ContinuationParameterName(data)
    if isfield(data, 'continuation_parameter_name') && ...
            ~isempty(data.continuation_parameter_name)
        name = char(string(data.continuation_parameter_name));
    else
        name = 'Continuation parameter';
    end
end

function textOut = AcceptedText(value)
    if value
        textOut = 'accepted';
    else
        textOut = 'rejected';
    end
end

function textOut = FormatComplex(value)
    if ~isfinite(real(value)) || ~isfinite(imag(value))
        textOut = '<unavailable>';
    else
        textOut = sprintf('%.8g %+.8gi', real(value), imag(value));
    end
end

function value = numelSafe(data)
    if isempty(data)
        value = 0;
    else
        value = numel(data.branch_index);
    end
end

function textOut = OnOff(value)
    if value
        textOut = 'on';
    else
        textOut = 'off';
    end
end
