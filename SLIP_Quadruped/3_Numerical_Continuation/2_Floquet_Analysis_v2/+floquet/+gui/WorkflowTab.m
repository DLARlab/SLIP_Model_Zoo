function ui = WorkflowTab(parentTab, hostFigure, options)
%BUILDFLOQUETWORKFLOWTAB Build the staged branch-to-daughter GUI tab.
%
%   UI = FLOQUET.GUI.WORKFLOWTAB(TAB,FIG,OPTIONS) installs a
%   two-column workflow view. The left column reproduces the state-space
%   branch plot from SLIP_Quadruped_GUI and shows the selected reduced-map
%   Floquet spectrum. The right column contains the five canonical workflow
%   stages in order. A selected branch point is an inspection cursor only;
%   Stage 1 always scans the complete ordered parent branch.

    if nargin < 3 || isempty(options)
        options = struct();
    end
    options = ResolveOptions(options);
    if ~isgraphics(parentTab) || ~strcmp(parentTab.Type, 'uitab')
        error('BuildFloquetWorkflowTab:InvalidParent', ...
            'parentTab must be a live uitab.');
    end
    if ~isgraphics(hostFigure, 'figure')
        error('BuildFloquetWorkflowTab:InvalidFigure', ...
            'hostFigure must be a live uifigure.');
    end

    floquet.internal.ensureRuntimePaths(true);

    controller = floquet.workflow.Session();
    adapter = [];
    branchResults = [];
    branchFile = '';
    branchName = '';
    branchFolder = pwd;
    analysisOutputParent = pwd;
    analysisOutputExplicit = false;
    availableBranches = struct('Name', {}, 'File', {});
    selectedIndex = 1;
    analysis = [];
    analysisView = [];
    selectedDiagnostic = struct();
    eigenHandles = struct();
    candidateMarkerHandles = gobjects(0);
    controllerState = struct();
    runningStage = NaN;
    computingPoint = false;
    closed = false;

    rootGrid = uigridlayout(parentTab, [3 2]);
    rootGrid.RowHeight = {164, '1x', 76};
    rootGrid.ColumnWidth = {'3.35x', '1.85x'};
    rootGrid.Padding = [12 12 12 12];
    rootGrid.RowSpacing = 10;
    rootGrid.ColumnSpacing = 12;
    rootGrid.Tag = 'FloquetWorkflowRootGrid';

    sourcePanel = uipanel(rootGrid, 'Title', 'Parent Branch and Workflow');
    sourcePanel.Layout.Row = 1;
    sourcePanel.Layout.Column = 1;
    sourcePanel.Tag = 'FloquetWorkflowSourcePanel';
    sourceGrid = uigridlayout(sourcePanel, [4 4]);
    sourceGrid.RowHeight = {'1x', '1x', '1x', '1x'};
    sourceGrid.ColumnWidth = {'fit', '1x', 110, 112};
    sourceGrid.Padding = [6 5 6 5];
    sourceGrid.RowSpacing = 5;
    sourceGrid.ColumnSpacing = 7;

    folderLabel = uilabel(sourceGrid, 'Text', 'Folder:');
    folderLabel.Layout.Row = 1;
    folderLabel.Layout.Column = 1;
    folderField = uieditfield(sourceGrid, 'text', ...
        'Editable', 'off', 'Value', branchFolder, ...
        'Tag', 'FloquetWorkflowFolderField');
    folderField.Layout.Row = 1;
    folderField.Layout.Column = 2;
    selectFolderButton = uibutton(sourceGrid, 'Text', 'Select Folder', ...
        'ButtonPushedFcn', @(~, ~) SelectBranchFolderDialog(), ...
        'Tag', 'FloquetWorkflowSelectFolderButton');
    selectFolderButton.Layout.Row = 1;
    selectFolderButton.Layout.Column = 3;
    loadConfigButton = uibutton(sourceGrid, 'Text', 'Load Workflow', ...
        'ButtonPushedFcn', @(~, ~) LoadConfigDialog(), ...
        'Tag', 'FloquetWorkflowLoadConfigButton');
    loadConfigButton.Layout.Row = 1;
    loadConfigButton.Layout.Column = 4;

    branchLabel = uilabel(sourceGrid, 'Text', 'Branch:');
    branchLabel.Layout.Row = 2;
    branchLabel.Layout.Column = 1;
    branchDropdown = uidropdown(sourceGrid, 'Items', {'<none>'}, ...
        'Value', '<none>', 'Tag', 'FloquetWorkflowBranchDropdown');
    branchDropdown.Layout.Row = 2;
    branchDropdown.Layout.Column = 2;
    loadBranchButton = uibutton(sourceGrid, 'Text', 'Load Branch', ...
        'ButtonPushedFcn', @(~, ~) LoadSelectedBranch(), ...
        'Tag', 'FloquetWorkflowLoadBranchButton');
    loadBranchButton.Layout.Row = 2;
    loadBranchButton.Layout.Column = 3;
    initializeButton = uibutton(sourceGrid, 'Text', 'New Workflow', ...
        'ButtonPushedFcn', @(~, ~) InitializeWorkflowDialog(), ...
        'Tag', 'FloquetWorkflowInitializeButton');
    initializeButton.Layout.Row = 2;
    initializeButton.Layout.Column = 4;

    outputLabel = uilabel(sourceGrid, 'Text', 'Output:');
    outputLabel.Layout.Row = 3;
    outputLabel.Layout.Column = 1;
    outputField = uieditfield(sourceGrid, 'text', ...
        'Editable', 'off', 'Value', analysisOutputParent, ...
        'Tag', 'FloquetWorkflowOutputField');
    outputField.Layout.Row = 3;
    outputField.Layout.Column = 2;
    selectOutputButton = uibutton(sourceGrid, 'Text', 'Select Output', ...
        'ButtonPushedFcn', @(~, ~) SelectAnalysisOutputFolderDialog(), ...
        'Tag', 'FloquetWorkflowSelectOutputButton');
    selectOutputButton.Layout.Row = 3;
    selectOutputButton.Layout.Column = 3;
    useBranchOutputButton = uibutton(sourceGrid, ...
        'Text', 'Use Branch Folder', ...
        'ButtonPushedFcn', @(~, ~) UseBranchFolderForOutput(), ...
        'Tag', 'FloquetWorkflowUseBranchOutputButton');
    useBranchOutputButton.Layout.Row = 3;
    useBranchOutputButton.Layout.Column = 4;

    configLabel = uilabel(sourceGrid, 'Text', 'Config:');
    configLabel.Layout.Row = 4;
    configLabel.Layout.Column = 1;
    configField = uieditfield(sourceGrid, 'text', ...
        'Editable', 'off', 'Value', '<not loaded>', ...
        'Tag', 'FloquetWorkflowConfigField');
    configField.Layout.Row = 4;
    configField.Layout.Column = 2;
    saveConfigButton = uibutton(sourceGrid, 'Text', 'Save Config', ...
        'ButtonPushedFcn', @(~, ~) SaveConfigFromButton(), ...
        'Enable', 'off', 'Tag', 'FloquetWorkflowSaveConfigButton');
    saveConfigButton.Layout.Row = 4;
    saveConfigButton.Layout.Column = 3;
    refreshButton = uibutton(sourceGrid, 'Text', 'Refresh State', ...
        'ButtonPushedFcn', @(~, ~) RefreshFromButton(), ...
        'Tag', 'FloquetWorkflowRefreshButton');
    refreshButton.Layout.Row = 4;
    refreshButton.Layout.Column = 4;

    plottingPanel = uipanel(rootGrid, 'Title', 'Branch and Floquet Analysis');
    plottingPanel.Layout.Row = 2;
    plottingPanel.Layout.Column = 1;
    plottingPanel.Tag = 'FloquetWorkflowPlottingPanel';
    plottingGrid = uigridlayout(plottingPanel, [2 1]);
    plottingGrid.RowHeight = {'1.1x', '0.9x'};
    plottingGrid.ColumnWidth = {'1x'};
    plottingGrid.Padding = [6 6 6 6];
    plottingGrid.RowSpacing = 8;

    statePanel = uipanel(plottingGrid, 'Title', 'Parent Branch State View');
    statePanel.Layout.Row = 1;
    stateGrid = uigridlayout(statePanel, [3 3]);
    stateGrid.RowHeight = {'1x', 'fit', 'fit'};
    stateGrid.ColumnWidth = {'1x', '1x', '1x'};
    stateGrid.Padding = [6 6 6 6];
    stateGrid.RowSpacing = 6;
    stateGrid.ColumnSpacing = 8;
    branchAxes = uiaxes(stateGrid, 'Tag', 'FloquetWorkflowBranchAxes');
    branchAxes.Layout.Row = 1;
    branchAxes.Layout.Column = [1 3];
    adapter = floquet.gui.plot.BranchPlotAdapter(branchAxes, ...
        'SelectionChangedFcn', @(~, selection) BranchSelectionChanged(selection));
    xAxisLabel = uilabel(stateGrid, 'Text', '$x$-Axis', ...
        'Interpreter', 'latex');
    xAxisLabel.Layout.Row = 2;
    xAxisLabel.Layout.Column = 1;
    yAxisLabel = uilabel(stateGrid, 'Text', '$y$-Axis', ...
        'Interpreter', 'latex');
    yAxisLabel.Layout.Row = 2;
    yAxisLabel.Layout.Column = 2;
    zAxisLabel = uilabel(stateGrid, 'Text', '$z$-Axis', ...
        'Interpreter', 'latex');
    zAxisLabel.Layout.Row = 2;
    zAxisLabel.Layout.Column = 3;
    xAxisDropdown = uidropdown(stateGrid, 'Items', adapter.AxisOptions, ...
        'Value', adapter.AxisOptions{1}, ...
        'ValueChangedFcn', @(~, ~) AxisSelectionChanged(), ...
        'Tag', 'FloquetWorkflowXAxisDropdown');
    xAxisDropdown.Layout.Row = 3;
    xAxisDropdown.Layout.Column = 1;
    yAxisDropdown = uidropdown(stateGrid, 'Items', adapter.AxisOptions, ...
        'Value', adapter.AxisOptions{5}, ...
        'ValueChangedFcn', @(~, ~) AxisSelectionChanged(), ...
        'Tag', 'FloquetWorkflowYAxisDropdown');
    yAxisDropdown.Layout.Row = 3;
    yAxisDropdown.Layout.Column = 2;
    zAxisDropdown = uidropdown(stateGrid, 'Items', adapter.AxisOptions, ...
        'Value', adapter.AxisOptions{2}, ...
        'ValueChangedFcn', @(~, ~) AxisSelectionChanged(), ...
        'Tag', 'FloquetWorkflowZAxisDropdown');
    zAxisDropdown.Layout.Row = 3;
    zAxisDropdown.Layout.Column = 3;
    ApplyDropdownStyle(xAxisDropdown);
    ApplyDropdownStyle(yAxisDropdown);
    ApplyDropdownStyle(zAxisDropdown);

    eigenPanel = uipanel(plottingGrid, 'Title', ...
        'Selected Solution: Reduced Poincare-map Multipliers');
    eigenPanel.Layout.Row = 2;
    eigenGrid = uigridlayout(eigenPanel, [2 1]);
    eigenGrid.RowHeight = {'fit', '1x'};
    eigenGrid.ColumnWidth = {'1x'};
    eigenGrid.Padding = [6 4 6 6];
    eigenGrid.RowSpacing = 4;
    eigenControlGrid = uigridlayout(eigenGrid, [1 3]);
    eigenControlGrid.Layout.Row = 1;
    eigenControlGrid.ColumnWidth = {'fit', 120, '1x'};
    eigenControlGrid.Padding = [0 0 0 0];
    eigenControlGrid.ColumnSpacing = 6;
    uilabel(eigenControlGrid, 'Text', 'View:');
    eigenModeDropdown = uidropdown(eigenControlGrid, ...
        'Items', {'Unit circle', 'Fit current'}, 'Value', 'Unit circle', ...
        'ValueChangedFcn', @(~, ~) UpdateSelectedPoint(), ...
        'Tag', 'FloquetWorkflowEigenModeDropdown');
    eigenHintLabel = uilabel(eigenControlGrid, ...
        'Text', 'Run Stage 1 to compute the full-branch spectrum.', ...
        'WordWrap', 'on', 'Tag', 'FloquetWorkflowEigenHintLabel');
    eigenvalueAxes = uiaxes(eigenGrid, ...
        'Tag', 'FloquetWorkflowEigenvalueAxes');
    eigenvalueAxes.Layout.Row = 2;
    ClearEigenvalueAxes();

    workflowScrollPanel = uipanel(rootGrid, 'BorderType', 'none', ...
        'Scrollable', 'on', 'AutoResizeChildren', 'off', ...
        'Tag', 'FloquetWorkflowStageScrollPanel');
    workflowScrollPanel.Layout.Row = [1 2];
    workflowScrollPanel.Layout.Column = 2;
    workflowScrollPanel.SizeChangedFcn = @(~, ~) ResizeStageContent();
    stageContentPanel = uipanel(workflowScrollPanel, ...
        'BorderType', 'none', 'Units', 'pixels', ...
        'Position', [1 1 500 1580], ...
        'Tag', 'FloquetWorkflowStageContentPanel');
    stageRowHeights = [235 250 325 175 335 175];
    stageGrid = uigridlayout(stageContentPanel, [6 1]);
    stageGrid.RowHeight = num2cell(stageRowHeights);
    stageGrid.ColumnWidth = {'1x'};
    stageGrid.Padding = [4 4 4 4];
    stageGrid.RowSpacing = 8;
    stageGrid.Tag = 'FloquetWorkflowStageGrid';
    minimumStageContentHeight = sum(stageRowHeights) + ...
        stageGrid.RowSpacing * (numel(stageRowHeights) - 1) + ...
        stageGrid.Padding(2) + stageGrid.Padding(4) + 2;

    [~, solutionGrid] = MakePanel(stageGrid, 1, ...
        'Selected Solution (inspection only)', 'FloquetWorkflowSolutionPanel', ...
        [4 1], {38, 28, '1x', 32});
    indexGrid = uigridlayout(solutionGrid, [1 4]);
    indexGrid.Layout.Row = 1;
    indexGrid.ColumnWidth = {'fit', '1x', 62, 'fit'};
    indexGrid.Padding = [0 0 0 0];
    indexGrid.ColumnSpacing = 5;
    uilabel(indexGrid, 'Text', 'Index:');
    indexSlider = uislider(indexGrid, 'Limits', [1 2], 'Value', 1, ...
        'MajorTicks', [], 'MinorTicks', [], 'Enable', 'off', ...
        'ValueChangingFcn', @(~, event) SelectIndex(event.Value), ...
        'ValueChangedFcn', @(source, ~) SelectIndex(source.Value), ...
        'Tag', 'FloquetWorkflowIndexSlider');
    indexInput = uieditfield(indexGrid, 'numeric', ...
        'Value', 1, 'Limits', [1 2], 'RoundFractionalValues', 'on', ...
        'Enable', 'off', ...
        'ValueChangedFcn', @(source, ~) SelectIndex(source.Value), ...
        'Tag', 'FloquetWorkflowIndexInput');
    indexTotalLabel = uilabel(indexGrid, 'Text', '/ 0', ...
        'Tag', 'FloquetWorkflowIndexTotalLabel');
    inspectionNote = uilabel(solutionGrid, 'Text', [ ...
        'This cursor inspects one solution. It never limits Stage 1, which ' ...
        'always analyzes every ordered parent-branch column.'], ...
        'WordWrap', 'on', 'FontAngle', 'italic', ...
        'Tag', 'FloquetWorkflowInspectionNote');
    inspectionNote.Layout.Row = 2;
    pointInfoLabel = uilabel(solutionGrid, ...
        'Text', 'Load a parent branch to inspect a solution.', ...
        'WordWrap', 'on', 'VerticalAlignment', 'top', ...
        'Tag', 'FloquetWorkflowPointInfoLabel');
    pointInfoLabel.Layout.Row = 3;
    solutionButtonGrid = uigridlayout(solutionGrid, [1 2]);
    solutionButtonGrid.Layout.Row = 4;
    solutionButtonGrid.ColumnWidth = {'1x', '1x'};
    solutionButtonGrid.Padding = [0 0 0 0];
    solutionButtonGrid.ColumnSpacing = 6;
    computePointButton = uibutton(solutionButtonGrid, ...
        'Text', 'Compute Selected Diagnostic', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~, ~) ComputeSelectedFromButton(), ...
        'Tag', 'FloquetWorkflowComputeSelectedButton');
    openAnalysisButton = uibutton(solutionButtonGrid, ...
        'Text', 'Open Full Analysis in Viewer', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~, ~) OpenAnalysisViewer(), ...
        'Tag', 'FloquetWorkflowOpenAnalysisButton');

    [stage1Panel, stage1Grid] = MakePanel(stageGrid, 2, ...
        'Stage 1 - Full-Branch Floquet Discovery', ...
        'FloquetWorkflowStage1Panel', [4 1], {'fit', 'fit', 64, 34});
    stage1Grid.Tag = 'FloquetWorkflowStage1Grid';
    stage1Header = MakeStageHeader(stage1Grid, 1, 1);
    stage1Description = uilabel(stage1Grid, 'Text', [ ...
        'Compute validated 12-by-12 apex return-map derivatives at every ' ...
        'branch point, track multipliers, and detect persistent crossings.'], ...
        'WordWrap', 'on');
    stage1Description.Layout.Row = 2;
    stage1ProgressGrid = uigridlayout(stage1Grid, [2 1]);
    stage1ProgressGrid.Layout.Row = 3;
    stage1ProgressGrid.RowHeight = {38, 20};
    stage1ProgressGrid.ColumnWidth = {'1x'};
    stage1ProgressGrid.Padding = [0 0 0 0];
    stage1ProgressGrid.RowSpacing = 2;
    stage1ProgressGrid.Tag = 'FloquetWorkflowStage1ProgressGrid';
    stage1ProgressGauge = uigauge(stage1ProgressGrid, 'linear', ...
        'Limits', [0 100], 'Value', 0, ...
        'MajorTicks', [0 25 50 75 100], 'MinorTicks', [], ...
        'Tag', 'FloquetWorkflowStage1ProgressGauge');
    stage1ProgressLabel = uilabel(stage1ProgressGrid, ...
        'Text', 'Not started.', 'Tag', 'FloquetWorkflowStage1ProgressLabel');
    stage1RunButton = uibutton(stage1Grid, ...
        'Text', 'Run / Resume Stage 1', ...
        'ButtonPushedFcn', @(~, ~) RunStageFromButton(1), ...
        'Enable', 'off', 'Tag', 'FloquetWorkflowStage1RunButton');
    stage1RunButton.Layout.Row = 4;

    [stage2Panel, stage2Grid] = MakePanel(stageGrid, 3, ...
        'Stage 2 - Review and Refine Candidates', ...
        'FloquetWorkflowStage2Panel', [4 1], {'fit', 'fit', '1x', 34});
    stage2Header = MakeStageHeader(stage2Grid, 2, 1);
    stage2Description = uilabel(stage2Grid, 'Text', [ ...
        'Review persistent crossings from the complete scan. Select ' ...
        'candidate groups, confirm the choice, then refine critical orbits.'], ...
        'WordWrap', 'on');
    stage2Description.Layout.Row = 2;
    candidateTable = uitable(stage2Grid, 'Data', EmptyCandidateTable(), ...
        'ColumnEditable', [true false false false false false], ...
        'Tag', 'FloquetWorkflowCandidateTable');
    candidateTable.Layout.Row = 3;
    candidateTable.ColumnWidth = {42, 155, 88, 78, 78, 86};
    stage2ButtonGrid = uigridlayout(stage2Grid, [1 2]);
    stage2ButtonGrid.Layout.Row = 4;
    stage2ButtonGrid.ColumnWidth = {'1x', '1x'};
    stage2ButtonGrid.Padding = [0 0 0 0];
    stage2ButtonGrid.ColumnSpacing = 6;
    confirmCandidatesButton = uibutton(stage2ButtonGrid, ...
        'Text', 'Confirm Selection', ...
        'ButtonPushedFcn', @(~, ~) ConfirmCandidatesFromTable(), ...
        'Enable', 'off', 'Tag', 'FloquetWorkflowConfirmCandidatesButton');
    stage2RunButton = uibutton(stage2ButtonGrid, ...
        'Text', 'Run Stage 2', ...
        'ButtonPushedFcn', @(~, ~) RunStageFromButton(2), ...
        'Enable', 'off', 'Tag', 'FloquetWorkflowStage2RunButton');

    [stage3Panel, stage3Grid] = MakePanel(stageGrid, 4, ...
        'Stage 3 - Search and Correct Daughter Seeds', ...
        'FloquetWorkflowStage3Panel', [3 1], {'fit', '1x', 34});
    stage3Header = MakeStageHeader(stage3Grid, 3, 1);
    stage3Description = uilabel(stage3Grid, 'Text', [ ...
        'Lift each critical state eigenvector through the production event-' ...
        'timing solver, try both signs and configured amplitudes, and ' ...
        'nonlinearly correct periodic daughter seeds.'], ...
        'WordWrap', 'on', 'VerticalAlignment', 'top');
    stage3Description.Layout.Row = 2;
    stage3RunButton = uibutton(stage3Grid, 'Text', 'Run Stage 3', ...
        'ButtonPushedFcn', @(~, ~) RunStageFromButton(3), ...
        'Enable', 'off', 'Tag', 'FloquetWorkflowStage3RunButton');
    stage3RunButton.Layout.Row = 3;

    [stage4Panel, stage4Grid] = MakePanel(stageGrid, 5, ...
        'Stage 4 - Review Rays and Continue Daughters', ...
        'FloquetWorkflowStage4Panel', [4 1], {'fit', 'fit', '1x', 34});
    stage4Header = MakeStageHeader(stage4Grid, 4, 1);
    stage4Description = uilabel(stage4Grid, 'Text', [ ...
        'For each signed ray, explicitly choose two accepted seeds at ' ...
        'distinct amplitudes. Confirmation binds the plan to the Stage-3 ' ...
        'artifact SHA-256 before continuation.'], ...
        'WordWrap', 'on');
    stage4Description.Layout.Row = 2;
    rayTable = uitable(stage4Grid, 'Data', EmptyRayTable(), ...
        'ColumnEditable', [true false false false false true true false], ...
        'Tag', 'FloquetWorkflowRayTable');
    rayTable.Layout.Row = 3;
    rayTable.ColumnWidth = {42, 170, 110, 82, 42, 62, 62, 62};
    stage4ButtonGrid = uigridlayout(stage4Grid, [1 2]);
    stage4ButtonGrid.Layout.Row = 4;
    stage4ButtonGrid.ColumnWidth = {'1x', '1x'};
    stage4ButtonGrid.Padding = [0 0 0 0];
    stage4ButtonGrid.ColumnSpacing = 6;
    confirmRaysButton = uibutton(stage4ButtonGrid, ...
        'Text', 'Confirm Rays', ...
        'ButtonPushedFcn', @(~, ~) ConfirmRaysFromTable(), ...
        'Enable', 'off', 'Tag', 'FloquetWorkflowConfirmRaysButton');
    stage4RunButton = uibutton(stage4ButtonGrid, ...
        'Text', 'Run / Resume Stage 4', ...
        'ButtonPushedFcn', @(~, ~) RunStageFromButton(4), ...
        'Enable', 'off', 'Tag', 'FloquetWorkflowStage4RunButton');

    [stage5Panel, stage5Grid] = MakePanel(stageGrid, 6, ...
        'Stage 5 - Independent Daughter Validation', ...
        'FloquetWorkflowStage5Panel', [3 1], {'fit', '1x', 34});
    stage5Header = MakeStageHeader(stage5Grid, 5, 1);
    stage5Description = uilabel(stage5Grid, 'Text', [ ...
        'Validate computed daughter branches against configured independent ' ...
        'checks or held-out references. Validation data are not available to ' ...
        'Stages 1-4.'], 'WordWrap', 'on', 'VerticalAlignment', 'top');
    stage5Description.Layout.Row = 2;
    stage5RunButton = uibutton(stage5Grid, 'Text', 'Run Stage 5', ...
        'ButtonPushedFcn', @(~, ~) RunStageFromButton(5), ...
        'Enable', 'off', 'Tag', 'FloquetWorkflowStage5RunButton');
    stage5RunButton.Layout.Row = 3;

    statusPanel = uipanel(rootGrid, 'Title', 'Workflow Status');
    statusPanel.Layout.Row = 3;
    statusPanel.Layout.Column = [1 2];
    statusGrid = uigridlayout(statusPanel, [2 1]);
    statusGrid.RowHeight = {'1x', 'fit'};
    statusGrid.ColumnWidth = {'1x'};
    statusGrid.Padding = [6 5 6 5];
    workflowStatusLabel = uilabel(statusGrid, 'Text', ...
        'Select a parent branch or load a workflow configuration.', ...
        'WordWrap', 'on', 'VerticalAlignment', 'top', ...
        'Tag', 'FloquetWorkflowStatusLabel');
    authorityLabel = uilabel(statusGrid, 'Text', ...
        'Authority: no canonical full-parent analysis loaded.', ...
        'FontAngle', 'italic', 'Tag', 'FloquetWorkflowAuthorityLabel');
    authorityLabel.Layout.Row = 2;

    stageHeaders = [stage1Header stage2Header stage3Header ...
        stage4Header stage5Header];
    stageButtons = [stage1RunButton stage2RunButton stage3RunButton ...
        stage4RunButton stage5RunButton];

    ui = struct();
    ui.Controller = controller;
    ui.RootGrid = rootGrid;
    ui.SourcePanel = sourcePanel;
    ui.FolderField = folderField;
    ui.BranchDropdown = branchDropdown;
    ui.AnalysisOutputField = outputField;
    ui.ConfigField = configField;
    ui.SaveConfigButton = saveConfigButton;
    ui.BranchAxes = branchAxes;
    ui.BranchPlotAdapter = adapter;
    ui.EigenvalueAxes = eigenvalueAxes;
    ui.XAxisDropdown = xAxisDropdown;
    ui.YAxisDropdown = yAxisDropdown;
    ui.ZAxisDropdown = zAxisDropdown;
    ui.IndexSlider = indexSlider;
    ui.IndexInput = indexInput;
    ui.PointInfoLabel = pointInfoLabel;
    ui.ComputeSelectedButton = computePointButton;
    ui.StageScrollPanel = workflowScrollPanel;
    ui.StageContentPanel = stageContentPanel;
    ui.StageGrid = stageGrid;
    ui.Stage1Grid = stage1Grid;
    ui.Stage1ProgressGrid = stage1ProgressGrid;
    ui.StagePanels = [stage1Panel stage2Panel stage3Panel ...
        stage4Panel stage5Panel];
    ui.StageHeaders = stageHeaders;
    ui.StageButtons = stageButtons;
    ui.CandidateTable = candidateTable;
    ui.RayTable = rayTable;
    ui.StatusLabel = workflowStatusLabel;
    ui.SelectBranchFolder = @SelectBranchFolder;
    ui.SelectAnalysisOutputFolder = @SetAnalysisOutputFolder;
    ui.LoadBranch = @LoadBranch;
    ui.ResetWorkflow = @ResetWorkflowSession;
    ui.InitializeWorkflow = @InitializeWorkflow;
    ui.LoadConfig = @LoadConfig;
    ui.SaveWorkflowConfig = @PersistCurrentConfiguration;
    ui.GetState = @GetState;
    ui.Refresh = @Refresh;
    ui.RunStage = @RunStage;
    ui.ConfirmCandidates = @ConfirmCandidates;
    ui.ConfirmRays = @ConfirmRays;
    ui.SelectIndex = @SelectIndex;
    ui.ComputeSelectedDiagnostic = @ComputeSelectedDiagnostic;
    ui.Cleanup = @Cleanup;

    SelectBranchFolder(branchFolder);
    RefreshControls();
    drawnow limitrate;
    ResizeStageContent();
    if ~isempty(options.ConfigSource)
        LoadConfig(options.ConfigSource);
    end

    function [panel, grid] = MakePanel(parent, row, titleText, tag, ...
            gridSize, rowHeights)
        panel = uipanel(parent, 'Title', titleText, 'Tag', tag);
        panel.Layout.Row = row;
        panel.Layout.Column = 1;
        grid = uigridlayout(panel, gridSize);
        grid.RowHeight = rowHeights;
        grid.ColumnWidth = repmat({'1x'}, 1, gridSize(2));
        grid.Padding = [6 5 6 5];
        grid.RowSpacing = 5;
        grid.ColumnSpacing = 6;
    end

    function header = MakeStageHeader(parent, number, row)
        header = uigridlayout(parent, [1 3]);
        header.Layout.Row = row;
        header.ColumnWidth = {18, 76, '1x'};
        header.Padding = [0 0 0 0];
        header.ColumnSpacing = 5;
        lamp = uilamp(header, 'Color', [0.65 0.65 0.65], ...
            'Tag', sprintf('FloquetWorkflowStage%dLamp', number));
        lamp.Layout.Column = 1;
        label = uilabel(header, 'Text', 'not loaded', ...
            'FontWeight', 'bold', ...
            'Tag', sprintf('FloquetWorkflowStage%dStatus', number));
        label.Layout.Column = 2;
        message = uilabel(header, 'Text', 'Configuration required.', ...
            'WordWrap', 'on', ...
            'Tag', sprintf('FloquetWorkflowStage%dMessage', number));
        message.Layout.Column = 3;
        header.UserData = struct('Lamp', lamp, 'Label', label, ...
            'Message', message);
    end

    function files = SelectBranchFolder(folder)
        if nargin < 1 || isempty(folder)
            folder = branchFolder;
        end
        if ~(ischar(folder) || (isstring(folder) && isscalar(folder)))
            error('BuildFloquetWorkflowTab:BranchFolder', ...
                'The branch folder must be scalar text.');
        end
        folder = char(string(folder));
        if ~isfolder(folder)
            error('BuildFloquetWorkflowTab:BranchFolder', ...
                'Branch folder does not exist: %s', folder);
        end
        folder = CanonicalPath(folder);
        listing = dir(fullfile(folder, '*.mat'));
        [~, order] = sort(lower({listing.name}));
        listing = listing(order);
        valid = false(1, numel(listing));
        for k = 1:numel(listing)
            filename = fullfile(listing(k).folder, listing(k).name);
            valid(k) = IsContinuationBranchFile(filename);
        end
        validListing = listing(valid);
        entries = repmat(struct('Name', '', 'File', ''), ...
            1, numel(validListing));
        for k = 1:numel(validListing)
            entries(k) = struct('Name', validListing(k).name, ...
                'File', fullfile(validListing(k).folder, ...
                validListing(k).name));
        end
        branchFolder = folder;
        availableBranches = entries;
        folderField.Value = folder;
        if isempty(entries)
            branchDropdown.Items = {'<none>'};
            branchDropdown.Value = '<none>';
        else
            branchDropdown.Items = {entries.Name};
            currentName = [branchName '.mat'];
            if any(strcmp(currentName, branchDropdown.Items))
                branchDropdown.Value = currentName;
            else
                branchDropdown.Value = entries(1).Name;
            end
        end
        files = {entries.File};
        SetStatus(sprintf('Found %d continuation branch file(s) in %s.', ...
            numel(entries), folder));
    end

    function SelectBranchFolderDialog()
        selected = uigetdir(branchFolder, ...
            'Select folder containing continuation branches');
        BringFigureForward();
        if isequal(selected, 0)
            return
        end
        try
            SelectBranchFolder(selected);
        catch exception
            ReportError(exception, 'Branch Folder Error');
        end
    end

    function SelectAnalysisOutputFolderDialog()
        selected = uigetdir(analysisOutputParent, ...
            'Select parent folder for the new Floquet workflow');
        BringFigureForward();
        if isequal(selected, 0)
            return
        end
        try
            SetAnalysisOutputFolder(selected);
        catch exception
            ReportError(exception, 'Analysis Output Error');
        end
    end

    function folder = SetAnalysisOutputFolder(folder, markExplicit)
        if nargin < 2
            markExplicit = true;
        end
        if ~(ischar(folder) || (isstring(folder) && isscalar(folder)))
            error('BuildFloquetWorkflowTab:AnalysisOutputFolder', ...
                'The analysis output parent must be a character vector or scalar string.');
        end
        folder = char(string(folder));
        if ~isfolder(folder)
            error('BuildFloquetWorkflowTab:AnalysisOutputFolder', ...
                'Analysis output parent folder not found: %s', folder);
        end
        previous = pwd;
        cleanup = onCleanup(@() cd(previous));
        cd(folder);
        folder = pwd;
        analysisOutputParent = folder;
        analysisOutputExplicit = logical(markExplicit);
        outputField.Value = folder;
        if isempty(branchName)
            SetStatus(sprintf('New workflow output parent: %s.', folder));
        else
            SetStatus(sprintf('New workflow target: %s.', fullfile( ...
                folder, [branchName '_floquet_workflow'])));
        end
        clear cleanup
    end

    function UseBranchFolderForOutput()
        try
            SetAnalysisOutputFolder(branchFolder);
        catch exception
            ReportError(exception, 'Analysis Output Error');
        end
    end

    function LoadSelectedBranch()
        selected = branchDropdown.Value;
        hit = find(strcmp(selected, {availableBranches.Name}), 1);
        if isempty(hit)
            ReportError(MException( ...
                'BuildFloquetWorkflowTab:NoBranchSelected', ...
                'Select a valid 29-by-N continuation branch first.'), ...
                'No Parent Branch');
            return
        end
        selectedFile = availableBranches(hit).File;
        try
            if HasConfiguration()
                configured = ...
                    floquet.workflow.internal.ResolveFloquetParentBranch( ...
                    controllerState.Config);
                if ~SamePath(selectedFile, configured)
                    choice = uiconfirm(hostFigure, [ ...
                        'The loaded workflow is pinned to a different parent. ' ...
                        'Start a new parent session? Existing files will not ' ...
                        'be changed or deleted.'], 'Start New Parent', ...
                        'Options', {'Start New Parent', 'Cancel'}, ...
                        'DefaultOption', 2, 'CancelOption', 2);
                    if ~strcmp(choice, 'Start New Parent')
                        return
                    end
                    ResetWorkflowSession();
                end
            end
            LoadBranch(selectedFile);
        catch exception
            ReportError(exception, 'Parent Branch Error');
        end
    end

    function results = LoadBranch(source)
        [results, filename, name] = ResolveBranch(source);
        if HasConfiguration() && ~isempty(filename)
            configured = ...
                floquet.workflow.internal.ResolveFloquetParentBranch( ...
                controllerState.Config);
            if ~SamePath(filename, configured)
                error('BuildFloquetWorkflowTab:BranchConfigurationMismatch', [ ...
                    'The loaded workflow is pinned to %s. Create or load a ' ...
                    'different workflow before viewing %s in this tab.'], ...
                    configured, filename);
            end
        end
        branchResults = results;
        branchFile = filename;
        branchName = name;
        selectedDiagnostic = struct();
        adapter.ClearBranches();
        adapter.AddBranch(branchName, branchResults);
        ConfigureIndexControls();
        selectedIndex = min(max(1, selectedIndex), size(branchResults, 2));
        adapter.SelectIndex(branchName, selectedIndex);
        if ~isempty(filename)
            branchFolder = fileparts(filename);
            folderField.Value = branchFolder;
            if ~analysisOutputExplicit
                SetAnalysisOutputFolder(branchFolder, false);
            end
            matching = find(strcmp([name '.mat'], ...
                branchDropdown.Items), 1);
            if ~isempty(matching)
                branchDropdown.Value = branchDropdown.Items{matching};
            end
        end
        UpdateCandidateMarkers();
        SetStatus(sprintf('Loaded parent branch %s (%d points).', ...
            branchName, size(branchResults, 2)));
    end

    function InitializeWorkflowDialog()
        if isempty(branchFile)
            ReportError(MException( ...
                'BuildFloquetWorkflowTab:BranchFileRequired', ...
                ['Load a branch MAT file before creating a reproducible ' ...
                 'workflow.']), 'Parent Branch Required');
            return
        end
        experimentRoot = fullfile(analysisOutputParent, ...
            [branchName '_floquet_workflow']);
        if isfolder(experimentRoot) || isfile(experimentRoot)
            ReportError(MException( ...
                'BuildFloquetWorkflowTab:WorkflowFolderExists', ...
                ['The target already exists: %s. Load its workflow_config.mat ' ...
                 'or choose another parent folder.'], experimentRoot), ...
                'Workflow Already Exists');
            return
        end
        try
            InitializeWorkflow(branchFile, experimentRoot, struct());
        catch exception
            ReportError(exception, 'Workflow Initialization Error');
        end
    end

    function [config, configFile] = InitializeWorkflow( ...
            parentSource, experimentRoot, creationOptions)
        if nargin < 1 || isempty(parentSource)
            parentSource = branchFile;
        end
        if nargin < 2 || isempty(experimentRoot)
            error('BuildFloquetWorkflowTab:ExperimentRoot', ...
                'An explicit experiment output folder is required.');
        end
        if nargin < 3 || isempty(creationOptions)
            creationOptions = struct();
        end
        [config, configFile] = ...
            floquet.workflow.internal.CreateFloquetWorkflowConfig( ...
            parentSource, experimentRoot, creationOptions);
        LoadConfig(configFile);
        SetStatus(sprintf('Created workflow configuration: %s', configFile));
    end

    function LoadConfigDialog()
        startFolder = branchFolder;
        if HasConfiguration()
            startFolder = controllerState.Config.ExperimentRoot;
        end
        [filename, folder] = uigetfile( ...
            {'*.mat', 'Workflow configuration (*.mat)'}, ...
            'Load Floquet workflow configuration', startFolder);
        BringFigureForward();
        if isequal(filename, 0)
            return
        end
        try
            LoadConfig(fullfile(folder, filename));
        catch exception
            ReportError(exception, 'Workflow Configuration Error');
        end
    end

    function state = LoadConfig(source)
        controllerState = controller.LoadConfig(source);
        if strcmp(controllerState.ConfigSource.Kind, 'mat-file')
            configField.Value = ...
                controllerState.ConfigSource.CanonicalFile;
        else
            configField.Value = '<in-memory workflow config>';
        end
        parentFile = ...
            floquet.workflow.internal.ResolveFloquetParentBranch( ...
            controllerState.Config);
        [results, filename, name] = ResolveBranch(parentFile);
        branchResults = results;
        branchFile = filename;
        branchName = name;
        selectedDiagnostic = struct();
        branchFolder = fileparts(filename);
        folderField.Value = branchFolder;
        SetAnalysisOutputFolder( ...
            fileparts(controllerState.Config.ExperimentRoot), true);
        availableBranches = struct('Name', [name '.mat'], 'File', filename);
        branchDropdown.Items = {availableBranches.Name};
        branchDropdown.Value = availableBranches.Name;
        adapter.ClearBranches();
        adapter.AddBranch(branchName, branchResults);
        ConfigureIndexControls();
        selectedIndex = min(max(1, selectedIndex), size(branchResults, 2));
        adapter.SelectIndex(branchName, selectedIndex);
        RefreshArtifactsFromState();
        RefreshControls();
        state = GetState();
        SetStatus(sprintf('Loaded workflow %s for %s.', ...
            controllerState.Config.ExperimentName, branchName));
    end

    function state = ResetWorkflowSession()
        controllerState = controller.Reset();
        configField.Value = '<not loaded>';
        analysis = [];
        analysisView = [];
        selectedDiagnostic = struct();
        RefreshArtifactsFromState();
        RefreshControls();
        state = GetState();
        SetStatus(['Started a new parent session. Existing workflow files ' ...
            'were left unchanged.']);
    end

    function state = Refresh()
        if HasConfiguration()
            controllerState = controller.Refresh();
            RefreshArtifactsFromState();
        end
        RefreshControls();
        UpdateSelectedPoint();
        state = GetState();
    end

    function RefreshFromButton()
        try
            Refresh();
            SetStatus('Workflow state refreshed from canonical artifacts.');
        catch exception
            ReportError(exception, 'Workflow Refresh Error');
        end
    end

    function [result, state] = RunStage(stage)
        if ~HasConfiguration()
            error('BuildFloquetWorkflowTab:NoWorkflow', ...
                'Create or load a workflow before running a stage.');
        end
        if isfinite(runningStage)
            error('BuildFloquetWorkflowTab:StageBusy', ...
                'Workflow Stage %d is already running.', runningStage);
        end
        stageNumber = ResolveStageNumber(stage);
        PrepareResumeConfiguration(stageNumber);
        runningStage = stageNumber;
        SetRunningState(stageNumber, true);
        cleanup = onCleanup(@() FinishStageRun());
        SetStatus(sprintf('Running Stage %d...', stageNumber));
        [result, controllerState] = controller.RunStage( ...
            stageNumber, @WorkflowProgress);
        RefreshArtifactsFromState();
        RefreshControls();
        UpdateSelectedPoint();
        SetStatus(sprintf('Stage %d completed and canonical state refreshed.', ...
            stageNumber));
        state = GetState();
        clear cleanup
    end

    function PrepareResumeConfiguration(stageNumber)
        config = controllerState.Config;
        changed = false;
        if stageNumber == 1 && isfield(config, 'AnalysisOptions') && ...
                isfield(config.AnalysisOptions, 'CheckpointFile')
            checkpoint = config.AnalysisOptions.CheckpointFile;
            resume = IsExistingTextFile(checkpoint);
            current = false;
            if isfield(config.AnalysisOptions, 'ResumeFromCheckpoint')
                current = IsTrue(config.AnalysisOptions.ResumeFromCheckpoint);
            end
            if resume ~= current
                config.AnalysisOptions.ResumeFromCheckpoint = resume;
                changed = true;
            end
        elseif stageNumber == 4 && isfield(config, 'Continuation')
            checkpoint = '';
            if isfield(config.Continuation, 'CheckpointFile')
                checkpoint = config.Continuation.CheckpointFile;
            elseif isfield(config, 'Files') && ...
                    isfield(config.Files, 'DaughterCheckpoint')
                checkpoint = config.Files.DaughterCheckpoint;
            end
            resume = IsExistingTextFile(checkpoint);
            current = false;
            if isfield(config.Continuation, 'ResumeFromCheckpoint')
                current = IsTrue( ...
                    config.Continuation.ResumeFromCheckpoint);
            end
            if resume ~= current
                config.Continuation.ResumeFromCheckpoint = resume;
                changed = true;
            end
        end
        if changed
            controllerState = controller.LoadConfig(config);
            RefreshControls();
        end
    end

    function RunStageFromButton(stage)
        try
            RunStage(stage);
        catch exception
            ReportError(exception, sprintf('Stage %d Error', stage));
        end
    end

    function FinishStageRun()
        runningStage = NaN;
        if ~closed
            RefreshControls();
        end
    end

    function state = ConfirmCandidates(candidateIDs)
        candidateIDs = NormalizeIDs(candidateIDs, 'candidate');
        if isempty(candidateIDs)
            error('BuildFloquetWorkflowTab:EmptyCandidateSelection', [ ...
                'Select at least one discovered candidate group. An empty ' ...
                'selection is not treated as implicit scientific consent.']);
        end
        previousState = controllerState;
        controllerState = controller.ConfirmCandidates(candidateIDs);
        try
            persisted = PersistCurrentConfiguration( ...
                'candidate-selection-confirmed');
        catch exception
            RestoreControllerState(previousState);
            rethrow(exception)
        end
        PopulateCandidateTable();
        RefreshControls();
        state = GetState();
        if persisted
            suffix = ' Saved to workflow_config.mat.';
        else
            suffix = ' In-memory config: confirmation is session-only.';
        end
        SetStatus(sprintf( ...
            'Confirmed %d candidate group(s) for Stage 2.%s', ...
            numel(candidateIDs), suffix));
    end

    function ConfirmCandidatesFromTable()
        try
            tableData = candidateTable.Data;
            if isempty(tableData)
                ids = {};
            else
                mask = logical(tableData.Use);
                ids = cellstr(string(tableData.CandidateID(mask)));
            end
            ConfirmCandidates(ids);
        catch exception
            ReportError(exception, 'Candidate Selection Error');
        end
    end

    function state = ConfirmRays(selections)
        if isempty(selections)
            error('BuildFloquetWorkflowTab:EmptyRaySelection', ...
                'Select at least one eligible signed daughter ray.');
        end
        previousState = controllerState;
        controllerState = controller.SetContinuationSelections(selections);
        try
            persisted = PersistCurrentConfiguration( ...
                'daughter-ray-selection-confirmed');
        catch exception
            RestoreControllerState(previousState);
            rethrow(exception)
        end
        PopulateRayTable();
        RefreshControls();
        state = GetState();
        if persisted
            suffix = ' Saved to workflow_config.mat.';
        else
            suffix = ' In-memory config: confirmation is session-only.';
        end
        SetStatus(sprintf('Confirmed %d signed ray(s) for Stage 4.%s', ...
            heightOrNumel(selections), suffix));
    end

    function ConfirmRaysFromTable()
        try
            data = rayTable.Data;
            if isempty(data)
                ConfirmRays(struct([]));
                return
            end
            selected = find(logical(data.Use));
            if isempty(selected)
                ConfirmRays(struct([]));
                return
            end
            catalog = ...
                floquet.workflow.internal.InspectFloquetDaughterRays( ...
                controllerState.Config);
            loadedSeeds = load(controllerState.Config.Files.Seeds, ...
                'seedReport');
            attempts = loadedSeeds.seedReport.Attempts;
            template = struct('RayID', '', 'SeedAttemptIndices', [], ...
                'SeedAmplitudes', [], 'SourceSeedSHA256', '');
            selections = repmat(template, 1, numel(selected));
            for k = 1:numel(selected)
                row = selected(k);
                indices = [data.AttemptA(row), data.AttemptB(row)];
                if any(~isfinite(indices)) || any(indices ~= round(indices))
                    error('BuildFloquetWorkflowTab:RayAttemptIndex', ...
                        'Ray attempt indices must be finite integers.');
                end
                indices = round(indices);
                if any(indices < 1) || any(indices > numel(attempts))
                    error('BuildFloquetWorkflowTab:RayAttemptIndex', ...
                        'A selected ray attempt index is out of range.');
                end
                selections(k).RayID = char(string(data.RayID(row)));
                selections(k).SeedAttemptIndices = indices;
                selections(k).SeedAmplitudes = [attempts(indices).Amplitude];
                selections(k).SourceSeedSHA256 = catalog.SourceSeedSHA256;
            end
            ConfirmRays(selections);
        catch exception
            ReportError(exception, 'Daughter Ray Selection Error');
        end
    end

    function persisted = PersistCurrentConfiguration(reason)
        if nargin < 1 || isempty(reason)
            reason = 'manual-gui-save';
        end
        persisted = false;
        if ~HasConfiguration() || ...
                ~isfield(controllerState, 'ConfigSource') || ...
                ~strcmp(controllerState.ConfigSource.Kind, 'mat-file')
            return
        end
        filename = controllerState.ConfigSource.CanonicalFile;
        if ~isfile(filename)
            error('BuildFloquetWorkflowTab:ConfigSourceMissing', ...
                'Workflow configuration file no longer exists: %s', filename);
        end
        payload = load(filename);
        payload.config = controllerState.Config;
        if isfield(payload, 'workflowConfigMetadata') && ...
                isstruct(payload.workflowConfigMetadata) && ...
                isscalar(payload.workflowConfigMetadata)
            payload.workflowConfigMetadata.UpdatedAt = Timestamp();
            payload.workflowConfigMetadata.LastGUIChange = ...
                char(string(reason));
        end
        floquet.workflow.internal.WriteFloquetArtifact( ...
            filename, payload, true);
        controllerState = controller.LoadConfig(filename);
        configField.Value = filename;
        persisted = true;
    end

    function SaveConfigFromButton()
        try
            if PersistCurrentConfiguration('manual-gui-save')
                RefreshControls();
                SetStatus(sprintf('Saved workflow configuration: %s', ...
                    controllerState.ConfigSource.CanonicalFile));
            else
                error('BuildFloquetWorkflowTab:InMemoryConfig', [ ...
                    'This workflow was loaded from an in-memory struct. ' ...
                    'Use New Workflow to create a persistent configuration.']);
            end
        catch exception
            ReportError(exception, 'Workflow Save Error');
        end
    end

    function RestoreControllerState(previousState)
        if isfield(previousState, 'ConfigSource') && ...
                isstruct(previousState.ConfigSource) && ...
                isfield(previousState.ConfigSource, 'Kind') && ...
                strcmp(previousState.ConfigSource.Kind, 'mat-file') && ...
                isfile(previousState.ConfigSource.CanonicalFile)
            controllerState = controller.LoadConfig( ...
                previousState.ConfigSource.CanonicalFile);
        else
            controllerState = controller.LoadConfig(previousState.Config);
        end
    end

    function state = GetState()
        controllerState = controller.GetState();
        state = controllerState;
        state.BranchFile = branchFile;
        state.BranchName = branchName;
        state.BranchPointCount = size(branchResults, 2);
        state.SelectedIndex = selectedIndex;
        state.SelectedSolution = SelectedSolution();
        state.Analysis = analysis;
        state.AnalysisView = analysisView;
        state.SelectedDiagnostic = selectedDiagnostic;
        state.CandidateTable = candidateTable.Data;
        state.RayTable = rayTable.Data;
        state.RunningStage = runningStage;
        state.ComputingSelectedPoint = computingPoint;
        state.AnalysisOutputParent = analysisOutputParent;
    end

    function RefreshArtifactsFromState()
        analysis = ExtractAnalysis(controllerState);
        if isempty(analysis)
            analysisView = [];
            eigenHandles = struct();
            ClearEigenvalueAxes();
        else
            analysisView = floquet.io.exportDataset(analysis);
            eigenHandles = struct();
        end
        PopulateCandidateTable();
        PopulateRayTable();
        UpdateCandidateMarkers();
        UpdateSelectedPoint();
    end

    function value = ExtractAnalysis(state)
        value = [];
        if isstruct(state) && isfield(state, 'Discovery') && ...
                isstruct(state.Discovery) && ...
                isfield(state.Discovery, 'Analysis') && ...
                ~isempty(state.Discovery.Analysis)
            value = state.Discovery.Analysis;
            return
        end
        if ~HasConfiguration() || ...
                ~isfield(controllerState.Config, 'Files') || ...
                ~isfield(controllerState.Config.Files, 'Discovery')
            return
        end
        filename = controllerState.Config.Files.Discovery;
        if ~isfile(filename) || ~StageArtifactValid(1)
            return
        end
        loaded = load(filename, 'analysis');
        if isfield(loaded, 'analysis')
            value = loaded.analysis;
        end
    end

    function PopulateCandidateTable()
        rows = EmptyCandidateTable();
        if ~isempty(analysis) && isfield(analysis, 'candidates') && ...
                ~isempty(analysis.candidates)
            candidates = analysis.candidates;
            ids = strings(1, numel(candidates));
            for k = 1:numel(candidates)
                ids(k) = string(ValueField(candidates(k), ...
                    {'CandidateID'}, sprintf('candidate_%04d', k)));
            end
            uniqueIDs = unique(ids, 'stable');
            count = numel(uniqueIDs);
            use = false(count, 1);
            candidateID = strings(count, 1);
            type = strings(count, 1);
            coordinate = NaN(count, 1);
            confidence = NaN(count, 1);
            multiplicity = NaN(count, 1);
            confirmed = ConfiguredCandidateIDs();
            for k = 1:count
                members = find(ids == uniqueIDs(k));
                candidate = candidates(members(1));
                candidateID(k) = uniqueIDs(k);
                type(k) = string(ValueField(candidate, ...
                    {'Type', 'type', 'BifurcationType'}, 'unknown'));
                coordinate(k) = NumericField(candidate, ...
                    {'ContinuationCoordinate', 'ContinuationParameter', ...
                     'Parameter'});
                confidence(k) = NumericField(candidate, ...
                    {'ConfidenceScore'});
                nullMultiplicity = NumericField(candidate, ...
                    {'NullMultiplicity'});
                if isfinite(nullMultiplicity)
                    multiplicity(k) = nullMultiplicity;
                else
                    multiplicity(k) = numel(members);
                end
                use(k) = any(strcmp(char(uniqueIDs(k)), confirmed));
            end
            rows = table(use, candidateID, type, coordinate, confidence, ...
                multiplicity, 'VariableNames', ...
                {'Use','CandidateID','Type','Coordinate','Confidence', ...
                 'Multiplicity'});
        end
        candidateTable.Data = rows;
    end

    function PopulateRayTable()
        rows = EmptyRayTable();
        if ~HasConfiguration() || ~StageArtifactValid(3)
            rayTable.Data = rows;
            return
        end
        try
            catalog = ...
                floquet.workflow.internal.InspectFloquetDaughterRays( ...
                controllerState.Config);
        catch
            rayTable.Data = rows;
            return
        end
        catalogRows = catalog.Rows;
        if isempty(catalogRows)
            rayTable.Data = rows;
            return
        end
        count = numel(catalogRows);
        use = false(count, 1);
        rayID = strings(count, 1);
        candidate = strings(count, 1);
        direction = strings(count, 1);
        signValue = NaN(count, 1);
        attemptA = NaN(count, 1);
        attemptB = NaN(count, 1);
        eligible = false(count, 1);
        configured = ConfiguredRaySelections();
        for k = 1:count
            item = catalogRows(k);
            rayID(k) = string(item.RayID);
            candidate(k) = string(item.CandidateID);
            direction(k) = string(item.DirectionID);
            signValue(k) = item.Sign;
            eligible(k) = logical(item.Eligible);
            if numel(item.DistinctAttemptIndices) >= 2
                attemptA(k) = item.DistinctAttemptIndices(1);
                attemptB(k) = item.DistinctAttemptIndices(2);
            end
            configuredHit = FindRaySelection(configured, item.RayID);
            if ~isempty(configuredHit)
                indices = configured(configuredHit).SeedAttemptIndices;
                if numel(indices) == 2
                    attemptA(k) = indices(1);
                    attemptB(k) = indices(2);
                    use(k) = true;
                end
            end
        end
        rows = table(use, rayID, candidate, direction, signValue, ...
            attemptA, attemptB, eligible, 'VariableNames', ...
            {'Use','RayID','Candidate','Direction','Sign','AttemptA', ...
             'AttemptB','Eligible'});
        rayTable.Data = rows;
    end

    function ids = ConfiguredCandidateIDs()
        ids = {};
        if ~HasConfiguration() || ...
                ~isfield(controllerState.Config, 'Selection') || ...
                ~isfield(controllerState.Config.Selection, 'Confirmed') || ...
                ~IsTrue(controllerState.Config.Selection.Confirmed) || ...
                ~isfield(controllerState.Config.Selection, 'CandidateIDs')
            return
        end
        ids = NormalizeIDs(controllerState.Config.Selection.CandidateIDs, ...
            'candidate');
    end

    function selections = ConfiguredRaySelections()
        selections = struct([]);
        if HasConfiguration() && ...
                isfield(controllerState.Config, 'Continuation') && ...
                isfield(controllerState.Config.Continuation, ...
                    'RaySelections')
            selections = controllerState.Config.Continuation.RaySelections;
        end
    end

    function hit = FindRaySelection(selections, rayID)
        hit = [];
        if isempty(selections) || ~isstruct(selections) || ...
                ~isfield(selections, 'RayID')
            return
        end
        hit = find(strcmp({selections.RayID}, rayID), 1);
    end

    function RefreshControls()
        configured = HasConfiguration();
        hasBranch = ~isempty(branchResults);
        ConfigureIndexControls();
        busy = isfinite(runningStage) || computingPoint;
        selectFolderButton.Enable = OnOff(~busy);
        selectOutputButton.Enable = OnOff(~busy);
        useBranchOutputButton.Enable = OnOff(~busy && isfolder(branchFolder));
        loadConfigButton.Enable = OnOff(~busy);
        saveConfigButton.Enable = OnOff(~busy && configured && ...
            isfield(controllerState, 'ConfigSource') && ...
            strcmp(controllerState.ConfigSource.Kind, 'mat-file'));
        branchDropdown.Enable = OnOff(~busy && ~isempty(availableBranches));
        loadBranchButton.Enable = OnOff(~busy && ...
            ~isempty(availableBranches));
        initializeButton.Enable = OnOff(~busy && ~isempty(branchFile) && ...
            isfolder(analysisOutputParent));
        openAnalysisButton.Enable = OnOff(~isempty(analysis) && ~busy);
        computePointButton.Enable = OnOff(hasBranch && ~busy);
        eigenModeDropdown.Enable = OnOff((~isempty(analysis) || ...
            (HasSelectedDiagnostic() && selectedDiagnostic.Accepted)) && ...
            ~busy);
        refreshButton.Enable = OnOff(configured && ~busy);
        confirmCandidatesButton.Enable = OnOff(configured && ...
            StageArtifactValid(1) && height(candidateTable.Data) > 0 && ...
            ~busy);
        confirmRaysButton.Enable = OnOff(configured && ...
            StageArtifactValid(3) && height(rayTable.Data) > 0 && ...
            ~busy);
        candidateTable.Enable = OnOff(configured && ...
            StageArtifactValid(1) && ~busy);
        rayTable.Enable = OnOff(configured && ...
            StageArtifactValid(3) && ~busy);

        if configured && isfield(controllerState, 'Stages') && ...
                numel(controllerState.Stages) == 5
            for k = 1:5
                UpdateStageHeader(k, controllerState.Stages(k));
                stageButtons(k).Enable = OnOff( ...
                    IsTrue(controllerState.Stages(k).CanRun) && ...
                    ~busy);
            end
        else
            for k = 1:5
                UpdateEmptyStageHeader(k);
                stageButtons(k).Enable = 'off';
            end
        end
        if isfinite(runningStage)
            SetRunningState(runningStage, true);
        end

        if StageArtifactValid(1) && ~isempty(analysis)
            stage1ProgressGauge.Value = 100;
            stage1ProgressLabel.Text = sprintf( ...
                'Complete: %d/%d parent points recorded.', ...
                numel(analysis.accepted), numel(analysis.accepted));
        elseif ~isfinite(runningStage)
            stage1ProgressGauge.Value = 0;
            stage1ProgressLabel.Text = 'Not completed.';
        end

        if ~isempty(analysis)
            authority = false;
            if isfield(analysis, 'scientificAuthority')
                authority = IsTrue(analysis.scientificAuthority);
            elseif isfield(analysis, 'provenance') && ...
                    isfield(analysis.provenance, 'scientificAuthority')
                authority = IsTrue(analysis.provenance.scientificAuthority);
            end
            acceptedCount = nnz(logical(analysis.accepted));
            if authority
                role = 'canonical scientific authority';
            else
                role = 'diagnostic / non-authoritative analysis';
            end
            authorityLabel.Text = sprintf( ...
                'Authority: %s | %d/%d validated Floquet matrices.', ...
                role, acceptedCount, numel(analysis.accepted));
        elseif configured
            authorityLabel.Text = ...
                'Authority: no completed canonical full-parent analysis.';
        else
            authorityLabel.Text = ...
                'Authority: no workflow configuration loaded.';
        end
        if ~hasBranch && isempty(availableBranches)
            loadBranchButton.Enable = 'off';
        end
    end

    function UpdateStageHeader(index, stage)
        parts = stageHeaders(index).UserData;
        status = lower(char(string(stage.Status)));
        parts.Label.Text = status;
        parts.Message.Text = char(string(stage.Message));
        switch status
            case 'complete'
                parts.Lamp.Color = [0.20 0.64 0.30];
            case 'ready'
                parts.Lamp.Color = [0.20 0.46 0.78];
            case 'invalid'
                parts.Lamp.Color = [0.82 0.22 0.20];
            otherwise
                parts.Lamp.Color = [0.65 0.65 0.65];
        end
    end

    function UpdateEmptyStageHeader(index)
        parts = stageHeaders(index).UserData;
        parts.Label.Text = 'not loaded';
        parts.Message.Text = 'Configuration required.';
        parts.Lamp.Color = [0.65 0.65 0.65];
    end

    function SetRunningState(stage, running)
        if ~running || closed
            return
        end
        for k = 1:numel(stageButtons)
            stageButtons(k).Enable = 'off';
        end
        refreshButton.Enable = 'off';
        confirmCandidatesButton.Enable = 'off';
        confirmRaysButton.Enable = 'off';
        candidateTable.Enable = 'off';
        rayTable.Enable = 'off';
        parts = stageHeaders(stage).UserData;
        parts.Label.Text = 'running';
        parts.Message.Text = 'Numerical stage is running...';
        parts.Lamp.Color = [0.95 0.60 0.12];
    end

    function WorkflowProgress(event)
        if closed || ~isstruct(event)
            return
        end
        detail = ValueField(event, {'Detail'}, event);
        if ~isstruct(detail) || ~isscalar(detail)
            detail = event;
        end
        localIndex = NumericField(detail, {'localIndex', 'index'});
        total = NumericField(detail, {'total', 'count'});
        message = ValueField(event, {'Message'}, '');
        if isempty(message)
            message = ValueField(detail, {'message'}, ...
                'Numerical work in progress.');
        end
        message = char(string(message));
        if runningStage == 1 && isfinite(localIndex) && ...
                isfinite(total) && total > 0
            progress = min(100, max(0, 100 * localIndex / total));
            stage1ProgressGauge.Value = progress;
            branchIndex = NumericField(detail, {'branchIndex'});
            if isfinite(branchIndex)
                stage1ProgressLabel.Text = sprintf( ...
                    '%d/%d points | branch column %d', ...
                    round(localIndex), round(total), round(branchIndex));
            else
                stage1ProgressLabel.Text = sprintf('%d/%d points', ...
                    round(localIndex), round(total));
            end
        end
        if isfinite(runningStage)
            parts = stageHeaders(runningStage).UserData;
            parts.Message.Text = message;
        end
        SetStatus(message);
        drawnow limitrate;
    end

    function tf = StageArtifactValid(number)
        tf = false;
        if ~HasConfiguration() || ~isfield(controllerState, 'Stages') || ...
                numel(controllerState.Stages) < number
            return
        end
        stage = controllerState.Stages(number);
        tf = isfield(stage, 'Valid') && IsTrue(stage.Valid) && ...
            isfield(stage, 'Status') && strcmp(stage.Status, 'complete');
    end

    function ConfigureIndexControls()
        count = size(branchResults, 2);
        if count < 1
            indexSlider.Limits = [1 2];
            indexSlider.Value = 1;
            indexInput.Limits = [1 2];
            indexInput.Value = 1;
            indexTotalLabel.Text = '/ 0';
            indexSlider.Enable = 'off';
            indexInput.Enable = 'off';
            return
        end
        upper = max(2, count);
        selectedIndex = min(max(round(selectedIndex), 1), count);
        indexSlider.Limits = [1 upper];
        indexSlider.Value = selectedIndex;
        indexInput.Limits = [1 upper];
        indexInput.Value = selectedIndex;
        indexTotalLabel.Text = sprintf('/ %d', count);
        enabled = ~isfinite(runningStage) && ~computingPoint;
        indexSlider.Enable = OnOff(enabled);
        indexInput.Enable = OnOff(enabled);
    end

    function selection = SelectIndex(index)
        selection = struct();
        if isempty(branchResults)
            return
        end
        selectedIndex = min(max(round(index), 1), size(branchResults, 2));
        selection = adapter.SelectIndex(branchName, selectedIndex);
    end

    function BranchSelectionChanged(selection)
        if isempty(selection) || ~isstruct(selection) || ...
                ~isfield(selection, 'Index') || isempty(selection.Index)
            return
        end
        selectedIndex = selection.Index;
        if ~isempty(branchResults)
            indexSlider.Value = selectedIndex;
            indexInput.Value = selectedIndex;
        end
        UpdateSelectedPoint();
    end

    function AxisSelectionChanged()
        indices = [FindAxisIndex(xAxisDropdown.Value, 1), ...
            FindAxisIndex(yAxisDropdown.Value, 5), ...
            FindAxisIndex(zAxisDropdown.Value, 2)];
        adapter.SetAxisIndices(indices);
        UpdateCandidateMarkers();
    end

    function index = FindAxisIndex(value, fallback)
        index = find(strcmp(adapter.AxisOptions, value), 1);
        if isempty(index)
            index = fallback;
        end
    end

    function UpdateSelectedPoint()
        if closed || isempty(branchResults)
            pointInfoLabel.Text = ...
                'Load a parent branch to inspect a solution.';
            return
        end
        selectedIndex = min(max(round(selectedIndex), 1), ...
            size(branchResults, 2));
        state = branchResults(1:13, selectedIndex);
        baseText = sprintf([ ...
            'Branch index %d of %d | dx %.10g | y %.10g | ' ...
            'dy %.3e | pitch %.6g'], selectedIndex, ...
            size(branchResults, 2), state(1), state(2), state(3), state(4));

        localIndex = [];
        if ~isempty(analysis) && isfield(analysis, 'branchIndices')
            localIndex = find(analysis.branchIndices == selectedIndex, 1);
        end
        if isempty(localIndex) || isempty(analysisView)
            if HasSelectedDiagnostic()
                ShowSelectedDiagnostic(baseText);
                return
            end
            eigenHandles = struct();
            ClearEigenvalueAxes();
            eigenHintLabel.Text = ...
                'No validated Floquet result is available at this point.';
            pointInfoLabel.Text = sprintf('%s\n\nFDM/Floquet: not computed.', ...
                baseText);
            return
        end

        if strcmp(eigenModeDropdown.Value, 'Fit current')
            axisMode = 'fit-current';
        else
            axisMode = 'unit-circle';
        end
        [eigenHandles, eigenInfo] = ...
            floquet.gui.plot.updateSpectrum( ...
            eigenvalueAxes, analysisView, localIndex, eigenHandles, ...
            struct('AxisMode', axisMode));
        accepted = logical(analysis.accepted(localIndex));
        if accepted
            values = analysisView.eigenvalues(:, localIndex);
            finite = isfinite(real(values)) & isfinite(imag(values));
            spectralRadius = max(abs(values(finite)), [], 'omitnan');
            if isempty(spectralRadius)
                spectralRadius = NaN;
            end
            quality = analysis.pointQuality(localIndex);
            topology = char(string(ValueField(quality, ...
                {'BaseTopologySignature'}, '<unavailable>')));
            pointInfoLabel.Text = sprintf([ ...
                '%s\n\nFDM/Floquet: accepted | spectral radius %.8g\n' ...
                'closest +1 %s | closest -1 %s\n' ...
                'FD convergence %.3e | one-sided mismatch %.3e\n' ...
                'periodic residual %.3e | timing residual %.3e\n' ...
                'topology %s'], baseText, spectralRadius, ...
                FormatComplex(eigenInfo.closest_plus_one_value), ...
                FormatComplex(eigenInfo.closest_minus_one_value), ...
                quality.DerivativeRelativeError, ...
                quality.ForwardBackwardRelativeError, ...
                quality.PeriodicResidual, quality.TimingResidual, topology);
            eigenHintLabel.Text = sprintf( ...
                'Validated branch point %d | max |lambda| %.6g', ...
                selectedIndex, spectralRadius);
        else
            quality = analysis.pointQuality(localIndex);
            reasons = ValueField(quality, {'RejectionReasons'}, {});
            if iscell(reasons) && ~isempty(reasons)
                reasonText = strjoin(cellfun(@char, reasons, ...
                    'UniformOutput', false), '; ');
            else
                reasonText = char(string(ValueField(quality, ...
                    {'Message'}, 'rejected')));
            end
            pointInfoLabel.Text = sprintf( ...
                '%s\n\nFDM/Floquet: rejected\n%s', ...
                baseText, reasonText);
            eigenHintLabel.Text = sprintf( ...
                'Branch point %d was rejected by numerical validation.', ...
                selectedIndex);
        end
    end

    function diagnostic = ComputeSelectedDiagnostic()
        if isempty(branchResults)
            error('BuildFloquetWorkflowTab:NoSelectedSolution', ...
                'Load a parent branch and select one solution first.');
        end
        if computingPoint || isfinite(runningStage)
            error('BuildFloquetWorkflowTab:NumericalWorkBusy', ...
                'Another numerical calculation is already running.');
        end
        computingPoint = true;
        RefreshControls();
        cleanup = onCleanup(@() FinishPointDiagnostic());
        SetStatus(sprintf([ ...
            'Computing selected branch point %d as an in-memory diagnostic. ' ...
            'This does not replace Stage 1.'], selectedIndex));
        fdOptions = struct();
        if HasConfiguration() && ...
                isfield(controllerState.Config, 'AnalysisOptions') && ...
                isfield(controllerState.Config.AnalysisOptions, ...
                    'FloquetOptions')
            fdOptions = controllerState.Config.AnalysisOptions.FloquetOptions;
        end
        [matrix, multipliers, eigenvectors, details] = floquet.computeFDM( ...
            branchResults(1:22, selectedIndex), ...
            branchResults(23:29, selectedIndex), fdOptions);
        accepted = ~isempty(matrix) && ~isempty(multipliers) && ...
            isfield(details, 'accepted') && IsTrue(details.accepted);
        view = [];
        if accepted
            view = struct();
            view.branch_index = selectedIndex;
            view.continuation_parameter = branchResults(1, selectedIndex);
            view.eigenvalues = multipliers(:);
            view.computation_info = struct('accepted', true);
        end
        selectedDiagnostic = struct( ...
            'Index', selectedIndex, ...
            'Accepted', accepted, ...
            'Matrix', matrix, ...
            'Multipliers', multipliers, ...
            'Eigenvectors', eigenvectors, ...
            'Diagnostics', details, ...
            'View', view, ...
            'Role', ...
                'in-memory selected-point diagnostic; not Stage-1 authority');
        diagnostic = selectedDiagnostic;
        UpdateSelectedPoint();
        if accepted
            SetStatus(sprintf([ ...
                'Selected point %d accepted as an in-memory diagnostic. ' ...
                'Run Stage 1 for branch-wide tracking and detection.'], ...
                selectedIndex));
        else
            SetStatus(sprintf('Selected point %d diagnostic was rejected.', ...
                selectedIndex));
        end
        clear cleanup
    end

    function ComputeSelectedFromButton()
        try
            ComputeSelectedDiagnostic();
        catch exception
            ReportError(exception, 'Selected-Point Floquet Error');
        end
    end

    function FinishPointDiagnostic()
        computingPoint = false;
        if ~closed
            RefreshControls();
        end
    end

    function tf = HasSelectedDiagnostic()
        tf = isstruct(selectedDiagnostic) && ...
            isfield(selectedDiagnostic, 'Index') && ...
            isequal(selectedDiagnostic.Index, selectedIndex) && ...
            isfield(selectedDiagnostic, 'Accepted');
    end

    function ShowSelectedDiagnostic(baseText)
        details = selectedDiagnostic.Diagnostics;
        if selectedDiagnostic.Accepted
            if strcmp(eigenModeDropdown.Value, 'Fit current')
                axisMode = 'fit-current';
            else
                axisMode = 'unit-circle';
            end
            [eigenHandles, eigenInfo] = ...
                floquet.gui.plot.updateSpectrum( ...
                eigenvalueAxes, selectedDiagnostic.View, 1, ...
                eigenHandles, struct('AxisMode', axisMode));
            values = selectedDiagnostic.Multipliers(:);
            spectralRadius = max(abs(values), [], 'omitnan');
            fdError = NestedNumeric(details, ...
                {'derivativeConvergence','finestRelativeError'});
            mismatch = NumericField(details, ...
                {'maximumFinestForwardBackwardError'});
            periodicResidual = NestedNumeric(details, ...
                {'baseValidation','periodicResidualNormInf'});
            timingResidual = NestedNumeric(details, ...
                {'baseValidation','mapInfo','timingResidualNormInf'});
            topology = NestedValue(details, ...
                {'referenceTopology','signature'}, '<unavailable>');
            pointInfoLabel.Text = sprintf([ ...
                '%s\n\nSelected-point diagnostic: accepted (not Stage-1 ' ...
                'authority)\nspectral radius %.8g\nclosest +1 %s | ' ...
                'closest -1 %s\nFD convergence %.3e | one-sided mismatch ' ...
                '%.3e\nperiodic residual %.3e | timing residual %.3e\n' ...
                'topology %s'], baseText, spectralRadius, ...
                FormatComplex(eigenInfo.closest_plus_one_value), ...
                FormatComplex(eigenInfo.closest_minus_one_value), ...
                fdError, mismatch, periodicResidual, timingResidual, ...
                char(string(topology)));
            eigenHintLabel.Text = ...
                'Selected-point diagnostic only; run Stage 1 for tracking.';
        else
            eigenHandles = struct();
            ClearEigenvalueAxes();
            reasons = ValueField(details, {'rejectionReasons'}, {});
            if iscell(reasons) && ~isempty(reasons)
                reasonText = strjoin(cellfun(@char, reasons, ...
                    'UniformOutput', false), '; ');
            else
                reasonText = char(string(ValueField(details, ...
                    {'message', 'status'}, 'rejected')));
            end
            pointInfoLabel.Text = sprintf( ...
                '%s\n\nSelected-point diagnostic: rejected\n%s', ...
                baseText, reasonText);
            eigenHintLabel.Text = ...
                'Selected-point reduced-map derivative was rejected.';
        end
    end

    function selected = SelectedSolution()
        selected = struct('Index', [], 'X', [], 'E', [], ...
            'Parameters', []);
        if isempty(branchResults)
            return
        end
        selected.Index = selectedIndex;
        selected.X = branchResults(1:13, selectedIndex);
        selected.E = branchResults(14:22, selectedIndex);
        selected.Parameters = branchResults(23:29, selectedIndex);
    end

    function UpdateCandidateMarkers()
        DeleteGraphics(candidateMarkerHandles);
        candidateMarkerHandles = gobjects(0);
        if isempty(analysis) || isempty(branchResults) || ...
                ~isfield(analysis, 'candidates') || ...
                isempty(analysis.candidates)
            return
        end
        candidates = analysis.candidates;
        ids = strings(1, numel(candidates));
        for k = 1:numel(candidates)
            ids(k) = string(ValueField(candidates(k), {'CandidateID'}, ...
                sprintf('candidate_%d', k)));
        end
        [~, uniqueIndices] = unique(ids, 'stable');
        axisIndices = adapter.AxisIndices;
        hold(branchAxes, 'on');
        for k = reshape(uniqueIndices, 1, [])
            candidate = candidates(k);
            left = NumericField(candidate, {'LeftIndex'});
            right = NumericField(candidate, {'RightIndex'});
            fraction = NumericField(candidate, {'Fraction'});
            if ~(isfinite(left) && isfinite(right) && ...
                    left >= 1 && right >= 1 && ...
                    left <= numel(analysis.branchIndices) && ...
                    right <= numel(analysis.branchIndices))
                continue
            end
            if ~isfinite(fraction)
                fraction = 0.5;
            end
            fraction = min(1, max(0, fraction));
            leftColumn = analysis.branchIndices(round(left));
            rightColumn = analysis.branchIndices(round(right));
            point = (1 - fraction) * branchResults(:, leftColumn) + ...
                fraction * branchResults(:, rightColumn);
            handle = plot3(branchAxes, point(axisIndices(1)), ...
                point(axisIndices(2)), point(axisIndices(3)), 'd', ...
                'MarkerSize', 8, 'LineWidth', 1.5, ...
                'MarkerEdgeColor', [0.75 0.10 0.10], ...
                'MarkerFaceColor', [1.00 0.82 0.20], ...
                'HitTest', 'off', 'PickableParts', 'none', ...
                'Tag', 'FloquetWorkflowCandidateMarker', ...
                'DisplayName', char(ids(k)));
            candidateMarkerHandles(end + 1) = handle; %#ok<AGROW>
        end
    end

    function ClearEigenvalueAxes()
        if ~isgraphics(eigenvalueAxes, 'axes')
            return
        end
        cla(eigenvalueAxes, 'reset');
        floquet.gui.plot.unitCircle(eigenvalueAxes);
        axis(eigenvalueAxes, 'equal');
        xlim(eigenvalueAxes, [-1.25 1.25]);
        ylim(eigenvalueAxes, [-1.25 1.25]);
        title(eigenvalueAxes, 'Floquet result unavailable', ...
            'Interpreter', 'none');
        try
            axtoolbar(eigenvalueAxes, {});
        catch
        end
    end

    function OpenAnalysisViewer()
        if isempty(analysis)
            return
        end
        source = analysis;
        if HasConfiguration() && ...
                isfile(controllerState.Config.Files.Discovery)
            source = controllerState.Config.Files.Discovery;
        end
        options.OnOpenAnalysis(source);
    end

    function ResizeStageContent()
        if closed || ~isgraphics(workflowScrollPanel) || ...
                ~isgraphics(stageContentPanel)
            return
        end
        position = getpixelposition(workflowScrollPanel, true);
        width = max(380, position(3) - 18);
        contentHeight = max(minimumStageContentHeight, position(4) - 2);
        stageContentPanel.Position = [1 1 width contentHeight];
    end

    function SetStatus(message)
        if closed || ~isgraphics(workflowStatusLabel)
            return
        end
        workflowStatusLabel.Text = char(string(message));
        drawnow limitrate;
    end

    function ReportError(exception, titleText)
        SetStatus(['Error: ' exception.message]);
        if isgraphics(hostFigure) && strcmpi(hostFigure.Visible, 'on')
            uialert(hostFigure, exception.message, titleText);
        end
    end

    function BringFigureForward()
        if isgraphics(hostFigure) && strcmpi(hostFigure.Visible, 'on')
            try
                figure(hostFigure);
            catch
            end
        end
    end

    function tf = HasConfiguration()
        tf = isstruct(controllerState) && ...
            isfield(controllerState, 'Config') && ...
            isstruct(controllerState.Config) && ...
            isscalar(controllerState.Config) && ...
            ~isempty(fieldnames(controllerState.Config));
    end

    function Cleanup()
        if closed
            return
        end
        closed = true;
        DeleteGraphics(candidateMarkerHandles);
        try
            if isa(controller, 'handle') && isvalid(controller)
                delete(controller);
            end
        catch
        end
    end
end

function options = ResolveOptions(supplied)
    defaults = struct('ConfigSource', [], 'OnOpenAnalysis', @(~) [], ...
        'Visible', 'on');
    if ~isstruct(supplied) || ~isscalar(supplied)
        error('BuildFloquetWorkflowTab:InvalidOptions', ...
            'options must be one scalar structure.');
    end
    options = defaults;
    names = fieldnames(supplied);
    allowed = fieldnames(defaults);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k}, allowed), 1);
        if isempty(hit)
            error('BuildFloquetWorkflowTab:UnknownOption', ...
                'Unknown option %s.', names{k});
        end
        options.(allowed{hit}) = supplied.(names{k});
    end
    if ~isa(options.OnOpenAnalysis, 'function_handle')
        error('BuildFloquetWorkflowTab:OpenAnalysisCallback', ...
            'OnOpenAnalysis must be a function handle.');
    end
end

function tableValue = EmptyCandidateTable()
    tableValue = table(false(0,1), strings(0,1), strings(0,1), ...
        NaN(0,1), NaN(0,1), NaN(0,1), 'VariableNames', ...
        {'Use','CandidateID','Type','Coordinate','Confidence', ...
         'Multiplicity'});
end

function tableValue = EmptyRayTable()
    tableValue = table(false(0,1), strings(0,1), strings(0,1), ...
        strings(0,1), NaN(0,1), NaN(0,1), NaN(0,1), false(0,1), ...
        'VariableNames', {'Use','RayID','Candidate','Direction','Sign', ...
        'AttemptA','AttemptB','Eligible'});
end

function [results, filename, name] = ResolveBranch(source)
    filename = '';
    name = 'in_memory_parent';
    if isnumeric(source)
        results = source;
    elseif isstruct(source) && isscalar(source) && ...
            isfield(source, 'results')
        results = source.results;
    elseif ischar(source) || (isstring(source) && isscalar(source))
        filename = char(string(source));
        if ~isfile(filename)
            error('BuildFloquetWorkflowTab:BranchMissing', ...
                'Parent branch file does not exist: %s', filename);
        end
        filename = CanonicalPath(filename);
        [~, name] = fileparts(filename);
        variables = whos('-file', filename);
        hit = find(strcmp({variables.name}, 'results'), 1);
        if isempty(hit)
            numeric = find(arrayfun(@(item) ...
                IsNumericClass(item.class) && numel(item.size) == 2 && ...
                item.size(1) == 29 && item.size(2) >= 1, variables));
            if numel(numeric) ~= 1
                error('BuildFloquetWorkflowTab:BranchVariable', [ ...
                    'MAT file must contain variable results or exactly one ' ...
                    'numeric 29-by-N continuation branch.']);
            end
            variableName = variables(numeric).name;
        else
            variableName = 'results';
        end
        loaded = load(filename, variableName);
        results = loaded.(variableName);
    else
        error('BuildFloquetWorkflowTab:BranchSource', [ ...
            'Branch source must be a 29-by-N numeric array, a scalar struct ' ...
            'with results, or a MAT filename.']);
    end
    if ~(isnumeric(results) && isreal(results) && ismatrix(results) && ...
            size(results, 1) == 29 && size(results, 2) >= 1 && ...
            all(isfinite(results(1:22, :)), 'all') && ...
            all(isfinite(results([23 24 26:29], :)), 'all') && ...
            all(~isnan(results(25, :))) && ...
            all(~(isinf(results(25, :)) & results(25, :) < 0)))
        error('BuildFloquetWorkflowTab:BranchShape', ...
            ['The parent branch must be a real 29-by-N numeric array. ' ...
             'Rows 1:22 and finite-parameter rows must be finite; row 25 ' ...
             '(pitch inertia) may contain positive Inf.']);
    end
end

function tf = IsContinuationBranchFile(filename)
    tf = false;
    try
        variables = whos('-file', filename);
    catch
        return
    end
    for k = 1:numel(variables)
        item = variables(k);
        if IsNumericClass(item.class) && numel(item.size) == 2 && ...
                item.size(1) == 29 && item.size(2) >= 1
            tf = true;
            return
        end
    end
end

function tf = IsNumericClass(className)
    tf = any(strcmp(className, {'double','single','int8','uint8','int16', ...
        'uint16','int32','uint32','int64','uint64'}));
end

function path = CanonicalPath(path)
    path = char(java.io.File(path).getCanonicalPath());
end

function tf = SamePath(left, right)
    left = CanonicalPath(left);
    right = CanonicalPath(right);
    if ispc || ismac
        tf = strcmpi(left, right);
    else
        tf = strcmp(left, right);
    end
end

function ids = NormalizeIDs(value, noun)
    if isempty(value)
        ids = {};
        return
    end
    if ischar(value)
        ids = {value};
    elseif isstring(value)
        ids = cellstr(value(:));
    elseif iscell(value)
        ids = cell(size(value));
        for k = 1:numel(value)
            item = value{k};
            if ~(ischar(item) || (isstring(item) && isscalar(item)))
                error('BuildFloquetWorkflowTab:IdentifierType', ...
                    'Every %s ID must be scalar text.', noun);
            end
            ids{k} = char(string(item));
        end
        ids = ids(:).';
    else
        error('BuildFloquetWorkflowTab:IdentifierType', ...
            '%s IDs must be text, a string array, or a cell array.', noun);
    end
    ids = cellfun(@strtrim, ids, 'UniformOutput', false);
    if any(cellfun(@isempty, ids))
        error('BuildFloquetWorkflowTab:EmptyIdentifier', ...
            '%s IDs cannot be empty.', noun);
    end
    ids = unique(ids, 'stable');
end

function number = ResolveStageNumber(stage)
    if isnumeric(stage) && isscalar(stage) && isfinite(stage) && ...
            stage == round(stage) && stage >= 1 && stage <= 5
        number = round(stage);
        return
    end
    if ~(ischar(stage) || (isstring(stage) && isscalar(stage)))
        error('BuildFloquetWorkflowTab:Stage', ...
            'Stage must be 1..5 or a canonical stage name.');
    end
    key = lower(strtrim(char(string(stage))));
    names = {'discovery','refinement','seeds','continuation','validation'};
    number = find(strcmp(key, names), 1);
    if isempty(number)
        error('BuildFloquetWorkflowTab:Stage', ...
            'Unknown workflow stage: %s', key);
    end
end

function value = ValueField(source, names, fallback)
    value = fallback;
    if ~isstruct(source) || ~isscalar(source)
        return
    end
    available = fieldnames(source);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k}, available), 1);
        if ~isempty(hit)
            value = source.(available{hit});
            return
        end
    end
end

function value = NumericField(source, names)
    value = ValueField(source, names, NaN);
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && ...
            isfinite(value))
        value = NaN;
    end
end

function value = NestedValue(source, path, fallback)
    value = source;
    for k = 1:numel(path)
        if ~isstruct(value) || ~isscalar(value)
            value = fallback;
            return
        end
        names = fieldnames(value);
        hit = find(strcmpi(path{k}, names), 1);
        if isempty(hit)
            value = fallback;
            return
        end
        value = value.(names{hit});
    end
end

function value = NestedNumeric(source, path)
    value = NestedValue(source, path, NaN);
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && ...
            isfinite(value))
        value = NaN;
    end
end

function tf = IsTrue(value)
    tf = isscalar(value) && isreal(value) && ...
        ((islogical(value) && value) || ...
         (isnumeric(value) && isfinite(value) && value == 1));
end

function tf = IsExistingTextFile(value)
    tf = (ischar(value) || (isstring(value) && isscalar(value))) && ...
        strlength(string(value)) > 0 && isfile(char(string(value)));
end

function value = OnOff(tf)
    if tf
        value = 'on';
    else
        value = 'off';
    end
end

function textValue = FormatComplex(value)
    if ~(isnumeric(value) && isscalar(value) && ...
            isfinite(real(value)) && isfinite(imag(value)))
        textValue = '<unavailable>';
    else
        textValue = sprintf('%.7g%+.7gi', real(value), imag(value));
    end
end

function DeleteGraphics(handles)
    if isempty(handles)
        return
    end
    handles = handles(isgraphics(handles));
    if ~isempty(handles)
        delete(handles);
    end
end

function ApplyDropdownStyle(dropdown)
    try
        addStyle(dropdown, uistyle('Interpreter', 'latex'));
    catch
        try
            addStyle(dropdown, uistyle('Interpreter', 'tex'));
        catch
        end
    end
end

function count = heightOrNumel(value)
    if istable(value)
        count = height(value);
    else
        count = numel(value);
    end
end

function value = Timestamp()
    value = char(datetime('now', 'TimeZone', 'local', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end
