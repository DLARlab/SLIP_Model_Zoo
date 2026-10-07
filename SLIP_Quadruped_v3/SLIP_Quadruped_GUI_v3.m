function [fig, controller, handles] = SLIP_Quadruped_GUI_v3(options)
%SLIP_QUADRUPED_GUI_V3 Familiar quadruped workflow on independent v3 services.
%   [FIG,CONTROLLER,HANDLES] permits callback-level checks. Options: Visible
%   ('on'/'off'), Position ([x y width height]), DatasetFile (in-v3 MAT),
%   StartTimers (true/false). Numerical data, checkpoints and exports are
%   confined to v3. Paths are restored when the window closes.
    if nargin < 1, options = struct(); end
    settings = struct('Visible', 'on', 'Position', [80 80 1280 840], ...
        'DatasetFile', '', 'StartTimers', true);
    names = fieldnames(options);
    for optionIndex = 1:numel(names)
        if ~isfield(settings, names{optionIndex}), error('SLIP_Quadruped_GUI_v3:Option', 'Unknown option %s.', names{optionIndex}); end
        settings.(names{optionIndex}) = options.(names{optionIndex});
    end
    root = fileparts(mfilename('fullpath'));
    originalPath = path;
    folders = {'Schema_v3', 'Adapters_v3', 'Dynamics_v3', 'Simulation_v3', ...
        'Orbit_v3', 'Numerics_v3', 'Stability_v3', 'Graphics_v3', 'GUI_v3'};
    for pathIndex = 1:numel(folders), addpath(fullfile(root, folders{pathIndex})); end
    try
    controller = QuadrupedGUIController_v3(root);
    schema = controller.Schema;
    fig = uifigure('Name', 'SLIP Quadruped GUI v3', 'Position', settings.Position, ...
        'Visible', settings.Visible, 'Scrollable', 'on');
    fig.CloseRequestFcn = @(~, ~) CloseGUI();
    runTimer = []; playTimer = [];
    handles = struct(); visualization = struct(); frames = []; frameIndex = 1;
    playRequested = false; lastSelection = ''; busy = false; playbackWallTimer = []; playbackStartTime = 0;
    mainGrid = uigridlayout(fig, [3, 2]);
    mainGrid.RowHeight = {118, '1x', 93}; mainGrid.ColumnWidth = {'3.35x', '1.85x'};
    mainGrid.Padding = [12 12 12 12]; mainGrid.RowSpacing = 10; mainGrid.ColumnSpacing = 12;
    dataPanel = uipanel(mainGrid, 'Title', 'Data Info'); dataPanel.Layout.Row = 1; dataPanel.Layout.Column = 1;
    dataGrid = uigridlayout(dataPanel, [2, 1]); dataGrid.RowHeight = {32, 32};
    top = uigridlayout(dataGrid, [1, 5]); top.ColumnWidth = {'1.45x', 106, 70, 76, 84}; top.Padding = [0 0 0 0];
    handles.File = uidropdown(top, 'Items', {'<none>'});
    Button(top, 'Select Folder', @SelectFolder);
    Button(top, 'Plot', @LoadSelected); Button(top, 'Plot All', @LoadAll); Button(top, 'Delete All', @RemoveAll);
    filterGrid = uigridlayout(dataGrid, [1, 6]); filterGrid.ColumnWidth = {80, '1x', 80, 65, '1x', 80}; filterGrid.Padding = [0 0 0 0];
    uilabel(filterGrid, 'Text', 'Fixed filter');
    handles.FilterParameter = uidropdown(filterGrid, 'Items', [{'<none>'}, schema.ParameterNames], 'ValueChangedFcn', @(~, ~) RefreshPlot());
    handles.FilterValue = uieditfield(filterGrid, 'numeric', 'ValueChangedFcn', @(~, ~) RefreshPlot());
    uilabel(filterGrid, 'Text', 'Color by');
    handles.ColorParameter = uidropdown(filterGrid, 'Items', schema.ParameterNames, 'ValueChangedFcn', @(~, ~) RefreshPlot());
    handles.FilterTolerance = uieditfield(filterGrid, 'numeric', 'Value', 1e-10, 'Limits', [0 Inf], 'Tooltip', 'Relative parameter filter tolerance');
    plotPanel = uipanel(mainGrid, 'Title', 'Plotting'); plotPanel.Layout.Row = 2; plotPanel.Layout.Column = 1;
    plotGrid = uigridlayout(plotPanel, [1, 1]);
    handles.PlotTabs = uitabgroup(plotGrid);
    stateTab = uitab(handles.PlotTabs, 'Title', 'State Plot');
    hildebrandTab = uitab(handles.PlotTabs, 'Title', 'Hildebrand Plot');
    sg = uigridlayout(stateTab, [2, 3]); sg.RowHeight = {'1x', 32};
    handles.StateAxes = uiaxes(sg); handles.StateAxes.Layout.Row = 1; handles.StateAxes.Layout.Column = [1 3];
    for axisIndex = 1:3
        field = {'XState', 'YState', 'ZState'}; initial = [schema.State.dx, schema.State.dphi, schema.State.y];
        handles.(field{axisIndex}) = uidropdown(sg, 'Items', schema.StateNames, 'Value', schema.StateNames{initial(axisIndex)}, 'ValueChangedFcn', @(~, ~) RefreshPlot());
        handles.(field{axisIndex}).Layout.Row = 2; handles.(field{axisIndex}).Layout.Column = axisIndex;
    end
    hg = uigridlayout(hildebrandTab, [1, 1]); handles.ContactAxes = uiaxes(hg);
    statusPanel = uipanel(mainGrid, 'Title', 'Status'); statusPanel.Layout.Row = 3; statusPanel.Layout.Column = 1;
    statusGrid = uigridlayout(statusPanel, [1, 1]);
    handles.Status = uitextarea(statusGrid, 'Editable', 'off', 'Value', {'Ready. All data and outputs must be inside v3.'});
    handles.Sidebar = uitabgroup(mainGrid); handles.Sidebar.Layout.Row = [1 3]; handles.Sidebar.Layout.Column = 2;
    infoTab = uitab(handles.Sidebar, 'Title', 'Info');
    visualTab = uitab(handles.Sidebar, 'Title', 'Visualization');
    solveTab = uitab(handles.Sidebar, 'Title', 'Solve');
    continuationTab = uitab(handles.Sidebar, 'Title', 'Continuation');
    oscillatorTab = uitab(handles.Sidebar, 'Title', 'Oscillator Plot');
    ig = uigridlayout(infoTab, [9, 1]); ig.RowHeight = {120, 32, '1x', 32, 32, 32, 32, 32, 64};
    dp = uipanel(ig, 'Title', 'Plotted Datasets'); dg = uigridlayout(dp, [1, 2]); dg.ColumnWidth = {'1x', 74};
    handles.DatasetList = uilistbox(dg, 'Items', {'<none>'}, 'ValueChangedFcn', @(~, ~) SelectDataset());
    Button(dg, 'Delete', @RemoveSelected);
    sr = uigridlayout(ig, [1, 5]); sr.ColumnWidth = {52, '1x', 42, 70, 70}; sr.Padding = [0 0 0 0];
    uilabel(sr, 'Text', 'Source'); handles.SeedSource = uidropdown(sr, 'Items', {'Cursor', 'Index input'}, 'ValueChangedFcn', @(~, ~) SeedSourceChanged());
    uilabel(sr, 'Text', 'Index'); handles.Index = uieditfield(sr, 'numeric', 'Value', 1, 'Limits', [1 Inf], 'RoundFractionalValues', 'on', 'Enable', 'off', 'ValueChangedFcn', @(~, ~) SelectIndex());
    Button(sr, 'Inspect', @InspectSelection);
    inspectionGrid = uigridlayout(ig, [2, 1]); inspectionGrid.RowHeight = {40, '1x'};
    handles.CursorInfo = uilabel(inspectionGrid, 'Text', 'Move over a plotted point for cursor information.', 'WordWrap', 'on');
    handles.Info = uitextarea(inspectionGrid, 'Editable', 'off', 'Value', {'Select a solution to inspect its physical mode and return chart.'});
    policyGrid = uigridlayout(ig, [1, 2]); policyGrid.ColumnWidth = {'1x', 60}; policyGrid.Padding = [0 0 0 0];
    handles.Policy = uidropdown(policyGrid, 'Items', {'stored', 'event-cycle-return', 'BL-marked-apex-return'}, ...
        'Tooltip', 'Stored preserves imported return identity; explicit selection changes the local chart.', 'ValueChangedFcn', @(~, ~) SetPolicy());
    handles.BLOccurrences = uieditfield(policyGrid, 'numeric', 'Value', 1, 'Limits', [1 100], 'RoundFractionalValues', 'on', ...
        'Tooltip', 'Number of BL touchdowns per explicitly BL-marked return', 'ValueChangedFcn', @(~, ~) SetPolicy());
    fr = uigridlayout(ig, [1, 3]); fr.ColumnWidth = {'1x', 80, 106}; fr.Padding = [0 0 0 0];
    handles.Scope = uidropdown(fr, 'Items', {'full', 'left/right', 'pronk'}, 'Tooltip', 'Left/right analysis is an explicitly restricted invariant block.', 'ValueChangedFcn', @(~, ~) SetScope());
    Button(fr, 'Floquet', @Floquet); Button(fr, 'Bifurcations', @Bifurcations);
    vr = uigridlayout(ig, [1, 3]); vr.ColumnWidth = {72, '1x', 76}; vr.Padding = [0 0 0 0];
    uilabel(vr, 'Text', 'Axis limits'); handles.Limits = uieditfield(vr, 'text', 'Placeholder', 'xmin xmax ymin ymax zmin zmax'); Button(vr, 'Apply', @ApplyView);
    ar = uigridlayout(ig, [1, 4]); ar.ColumnWidth = {52, '1x', 40, '1x'}; ar.Padding = [0 0 0 0];
    uilabel(ar, 'Text', 'Aspect'); handles.Aspect = uieditfield(ar, 'text', 'Value', '1.333 1 1');
    uilabel(ar, 'Text', 'View'); handles.View = uieditfield(ar, 'text', 'Value', '0 90');
    handles.ExportPath = uieditfield(ig, 'text', 'Value', fullfile(root, 'GUI_v3', 'Outputs_v3', 'state-plot.png'));
    er = uigridlayout(ig, [1, 2]); er.ColumnWidth = {'1x', '1x'}; Button(er, 'Export current plot', @ExportPlot); Button(er, 'Save accepted solution', @SaveSolution);
    % Visualization keeps Animation and Trajectories within the familiar tab.
    vg = uigridlayout(visualTab, [4, 1]); vg.RowHeight = {40, 40, 32, '1x'};
    playback = uigridlayout(vg, [1, 4]); playback.ColumnWidth = {52, '1x', 60, 68}; playback.Padding = [0 0 0 0];
    uilabel(playback, 'Text', 'Stride'); handles.Scrubber = uislider(playback, 'Limits', [0 1], 'MajorTicks', [0 .5 1], ...
        'ValueChangingFcn', @(~, e) Guard(@() Scrub(e.Value)), 'ValueChangedFcn', @(s, ~) Guard(@() Scrub(s.Value)));
    handles.Strides = uieditfield(playback, 'numeric', 'Value', 1, 'Limits', [1 20], 'RoundFractionalValues', 'on');
    Button(playback, 'Prepare', @PrepareVisualization);
    pr = uigridlayout(vg, [1, 5]); pr.Padding = [0 0 0 0];
    Button(pr, 'Run', @Play); Button(pr, 'Stop', @StopPlayback); Button(pr, 'Keyframe', @ExportKeyframe); Button(pr, 'GIF', @RecordGIF); Button(pr, 'MP4', @RecordVideo);
    recordingSettings = uigridlayout(vg, [1, 3]); recordingSettings.ColumnWidth = {42, 54, '1x'}; recordingSettings.Padding = [0 0 0 0];
    uilabel(recordingSettings, 'Text', 'Speed');
    handles.PlaybackSpeed = uieditfield(recordingSettings, 'numeric', 'Value', 1, 'Limits', [.1 10], 'ValueChangedFcn', @(~, ~) SpeedChanged(false));
    handles.MediaPath = uieditfield(recordingSettings, 'text', 'Value', fullfile(root, 'GUI_v3', 'Outputs_v3', 'animation'), 'Tooltip', 'Animation export path base inside v3; .gif/.mp4 is appended.');
    handles.VisualTabs = uitabgroup(vg); at = uitab(handles.VisualTabs, 'Title', 'Animation'); tt = uitab(handles.VisualTabs, 'Title', 'Trajectories');
    ag = uigridlayout(at, [2, 1]); handles.AnimationAxes = uiaxes(ag); handles.OrbitAxes = uiaxes(ag);
    tg = uigridlayout(tt, [4, 1]); handles.TrajectoryAxes = gobjects(3, 1);
    for trajectoryIndex = 1:3, handles.TrajectoryAxes(trajectoryIndex) = uiaxes(tg); end
    handles.GRFAxes = uiaxes(tg);
    % Seed editor: state/timing/parameter left, tools right as in legacy.
    qg = uigridlayout(solveTab, [2, 2]); qg.RowHeight = {28, '1x'}; qg.ColumnWidth = {'1.4x', '1x'};
    seedSummary = uilabel(qg, 'Text', 'Schema states and ten physical parameters; detected times are read-only.', 'WordWrap', 'on'); seedSummary.Layout.Column = [1 2];
    editors = uigridlayout(qg, [3, 1]); editors.Layout.Row = 2; editors.Layout.Column = 1; editors.RowHeight = {'14x', '6x', '10x'};
    handles.StateTable = uitable(editors, 'Data', [schema.StateNames.', num2cell(zeros(14, 1))], 'ColumnName', {'State', 'Value'}, 'ColumnEditable', [false true], 'RowName', [], 'ColumnWidth', {92, 70});
    handles.TimingTable = uitable(editors, 'ColumnName', {'Detected event', 'Time'}, 'ColumnEditable', [false false], 'RowName', [], 'ColumnWidth', {92, 70});
    handles.ParameterTable = uitable(editors, 'Data', [schema.ParameterNames.', num2cell(zeros(10, 1))], 'ColumnName', {'Parameter', 'Value'}, 'ColumnEditable', [false true], 'RowName', [], 'ColumnWidth', {92, 70});
    tools = uigridlayout(qg, [18, 1]); tools.Layout.Row = 2; tools.Layout.Column = 2; tools.RowSpacing = 4; tools.Padding = [0 0 0 0]; tools.RowHeight = {22, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, '1x'};
    uilabel(tools, 'Text', 'Mode [BL BR FL FR]'); handles.Mode = uieditfield(tools, 'text', 'Value', '0 0 0 0'); Button(tools, 'Apply edited seed', @ApplySeed);
    handles.Noise = NumberRow(tools, 'State noise', 1e-4, [0 Inf]);
    handles.ParameterNoise = NumberRow(tools, 'Para noise', 0, [0 Inf]);
    handles.RNG = NumberRow(tools, 'RNG seed', 0, [0 Inf]); handles.RNG.RoundFractionalValues = 'on';
    Button(tools, 'Apply perturbation', @Perturb);
    handles.Prediction = NumberRow(tools, 'Predict factor', 1.1, [-Inf Inf]);
    Button(tools, 'Predict', @Predict); Button(tools, 'Correct', @Correct); Button(tools, 'Plot solved seed', @PlotCandidate); Button(tools, 'Save solved seed', @SaveSolution);
    handles.SavePath = uieditfield(tools, 'text', 'Value', fullfile(root, 'GUI_v3', 'Outputs_v3', 'gui-solution.mat'), 'Tooltip', 'Accepted-solution save path inside v3');
    handles.Algorithm = uidropdown(tools, 'Items', {'newton', 'fsolve', 'auto'}, 'Tooltip', 'Shared RootSolver algorithm');
    handles.MaxIterations = NumberRow(tools, 'Max iterations', 40, [1 1000]); handles.MaxIterations.RoundFractionalValues = 'on';
    handles.MaxEvaluations = NumberRow(tools, 'Max evaluations', 1200, [1 50000]); handles.MaxEvaluations.RoundFractionalValues = 'on';
    handles.RootTolerance = NumberRow(tools, 'Root tolerance', 1e-10, [eps 1e-8]);
    handles.SolveInfo = uitextarea(tools, 'Editable', 'off', 'Value', {'Correction uses independent physical energy coordinates. Events are redetected.'});
    % Continuation tabs preserve familiar 1D/Para/2D names with correct semantics.
    cg = uigridlayout(continuationTab, [1, 1]); handles.ContinuationTabs = uitabgroup(cg);
    fixedTab = uitab(handles.ContinuationTabs, 'Title', '1D'); paraTab = uitab(handles.ContinuationTabs, 'Title', 'Para'); scanTab = uitab(handles.ContinuationTabs, 'Title', '2D');
    fixedGrid = uigridlayout(fixedTab, [10, 1]); fixedGrid.RowHeight = {30, 30, 30, 30, 30, 30, 30, 30, '1x', 50};
    uilabel(fixedGrid, 'Text', 'Fixed physical parameters; energy-family continuation.');
    handles.Radius = NumberRow(fixedGrid, 'Seed radius', .01, [eps Inf]); handles.Radius.Tooltip = 'Second seed distance in scaled independent physical coordinates';
    Button(fixedGrid, 'Validate second seed at radius', @SecondSeed);
    handles.Step = NumberRow(fixedGrid, 'Arc step', .01, [eps Inf]); handles.Step.Tooltip = 'Pseudo-arclength step';
    handles.Points = NumberRow(fixedGrid, 'Point budget', 5, [1 1000]); handles.Points.RoundFractionalValues = 'on';
    Button(fixedGrid, 'Run fixed-parameter continuation', @StartFixed);
    BuildRunControls(fixedGrid);
    handles.CheckpointPath = uieditfield(fixedGrid, 'text', 'Value', fullfile(root, 'GUI_v3', 'Outputs_v3', 'gui-partial.mat'), 'Tooltip', 'Resumable run save path inside v3');
    handles.PreviewAxes = uiaxes(fixedGrid);
    uilabel(fixedGrid, 'Text', 'Pause/stop take effect at point boundaries; every point is checkpointed.', 'WordWrap', 'on');
    pg = uigridlayout(paraTab, [7, 1]); pg.RowHeight = {30, 30, 30, 30, 30, '1x', 50};
    uilabel(pg, 'Text', 'Parameter grid at fixed declared family energy.');
    handles.Parameter1 = uidropdown(pg, 'Items', schema.ParameterNames);
    handles.Values1 = uieditfield(pg, 'text', 'Value', '10 10.01 10.02', 'Tooltip', 'Explicit values, separated by spaces or commas');
    Button(pg, 'Run parameter variation', @StartParameter); BuildRunControls(pg); handles.ParameterPreviewAxes = uiaxes(pg);
    uilabel(pg, 'Text', 'Failed points remain rejected and are saved with their reasons.', 'WordWrap', 'on');
    gg = uigridlayout(scanTab, [9, 1]); gg.RowHeight = {44, 30, 30, 30, 30, 30, 30, '1x', 50};
    uilabel(gg, 'Text', '2D parameter scan. Each grid point is corrected; this is not a certified 2D solution manifold.', 'WordWrap', 'on');
    handles.ScanParameter1 = uidropdown(gg, 'Items', schema.ParameterNames, 'Value', schema.ParameterNames{1});
    handles.ScanValues1 = uieditfield(gg, 'text', 'Value', '10 10.01');
    handles.ScanParameter2 = uidropdown(gg, 'Items', schema.ParameterNames, 'Value', schema.ParameterNames{2});
    handles.ScanValues2 = uieditfield(gg, 'text', 'Value', '10 10.01');
    Button(gg, 'Run 2D parameter scan', @StartScan); BuildRunControls(gg); handles.ScanAxes = uiaxes(gg);
    uilabel(gg, 'Text', 'An independently found orbit does not certify a branch connection.', 'WordWrap', 'on');
    og = uigridlayout(oscillatorTab, [2, 1]); og.RowHeight = {34, '1x'};
    obr = uigridlayout(og, [1, 5]); obr.ColumnWidth = {'1x', '1x', '1x', 58, '1x'};
    Button(obr, 'Prepare', @PrepareVisualization); Button(obr, 'Play', @Play); Button(obr, 'Pause', @StopPlayback);
    handles.OscillatorSpeed = uieditfield(obr, 'numeric', 'Value', 1, 'Limits', [.1 10], 'Tooltip', 'Oscillator playback speed multiplier', 'ValueChangedFcn', @(~, ~) SpeedChanged(true));
    Button(obr, 'GIF', @RecordOscillatorGIF);
    oscgrid = uigridlayout(og, [2, 2]); handles.OscillatorAxes = gobjects(4, 1);
    for oscillatorIndex = 1:4, handles.OscillatorAxes(oscillatorIndex) = uiaxes(oscgrid); title(handles.OscillatorAxes(oscillatorIndex), schema.LegNames{oscillatorIndex}); end
    runTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', .2, 'BusyMode', 'drop', 'TimerFcn', @(~, ~) Guard(@Tick));
    playTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', .04, 'BusyMode', 'drop', 'TimerFcn', @(~, ~) Guard(@PlayTick));
    if settings.StartTimers, start(runTimer); start(playTimer); end
    RefreshFiles();
    if ~isempty(settings.DatasetFile)
        controller.loadDataset(settings.DatasetFile);
        controller.setFolder(fileparts(controller.confinedPath(settings.DatasetFile, true))); RefreshFiles();
        [~, sourceName, sourceExtension] = fileparts(settings.DatasetFile); handles.File.Value = [sourceName, sourceExtension];
        RefreshAll();
    end
    fig.WindowButtonMotionFcn = @(~, ~) HoverSelection();
    handles.Sidebar.SelectionChangedFcn = @(~, ~) Guard(@TabChanged);
    handles.Callbacks = struct('Refresh', @RefreshAll, 'Inspect', @InspectSelection, 'Correct', @Correct, ...
        'SecondSeed', @SecondSeed, 'Continue', @StartFixed, 'Floquet', @Floquet, 'Animate', @PrepareVisualization, ...
        'Save', @SaveSolution, 'Tick', @Tick, 'Scrub', @Scrub, 'Close', @CloseGUI, ...
        'RecordMP4', @RecordVideo, 'RecordGIF', @RecordGIF, 'RecordOscillatorGIF', @RecordOscillatorGIF, 'Play', @Play, 'PlayTick', @PlayTick);
    fig.UserData = struct('controller', controller, 'handles', handles);
    catch startupException
        if exist('runTimer', 'var') && ~isempty(runTimer) && isvalid(runTimer), stop(runTimer); delete(runTimer); end
        if exist('playTimer', 'var') && ~isempty(playTimer) && isvalid(playTimer), stop(playTimer); delete(playTimer); end
        if exist('fig', 'var') && isvalid(fig), delete(fig); end
        path(originalPath); rethrow(startupException);
    end


    function b = Button(parent, text, callback)
        b = uibutton(parent, 'Text', text, 'ButtonPushedFcn', @(~, ~) Guard(callback));
    end
    function control = NumberRow(parent, label, value, limits)
        row = uigridlayout(parent, [1, 2]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x', '1x'};
        uilabel(row, 'Text', label, 'FontSize', 10, 'Tooltip', label); control = uieditfield(row, 'numeric', 'Value', value, 'Limits', limits);
    end
    function BuildRunControls(parent)
        r = uigridlayout(parent, [1, 5]); r.Padding = [0 0 0 0];
        Button(r, 'Pause', @() controller.pauseRun()); Button(r, 'Resume', @Resume); Button(r, 'Stop', @() controller.stopRun());
        Button(r, 'Plot partial', @PlotPartial); Button(r, 'Load partial', @LoadPartial);
    end
    function Guard(action)
        if ~isvalid(fig), return; end
        try, action(); UpdateStatus();
        catch exception
            handles.Status.Value = {sprintf('%s: %s', exception.identifier, exception.message)};
        end
    end
    function UpdateStatus()
        if isvalid(fig), handles.Status.Value = {controller.Status}; end
    end
    function RefreshFiles()
        files = controller.setFolder(controller.Folder);
        if isempty(files), files = {'<none>'}; end
        handles.File.Items = files; handles.File.Value = files{1};
    end
    function SelectFolder()
        folder = uigetdir(controller.Folder, 'Select a data folder inside SLIP_Quadruped_v3');
        if isequal(folder, 0), return; end
        controller.setFolder(folder); RefreshFiles();
    end
    function LoadSelected()
        if strcmp(handles.File.Value, '<none>'), return; end
        controller.loadDataset(fullfile(controller.Folder, handles.File.Value)); RefreshAll();
    end
    function LoadAll()
        files = handles.File.Items;
        for j = 1:numel(files)
            if ~strcmp(files{j}, '<none>'), controller.loadDataset(fullfile(controller.Folder, files{j})); end
        end
        RefreshAll();
    end
    function RemoveAll(), controller.removeAll(); RefreshAll(); end
    function RemoveSelected(), controller.remove(); RefreshAll(); end
    function SelectDataset()
        index = find(strcmp({controller.Datasets.name}, handles.DatasetList.Value), 1);
        if ~isempty(index), controller.select(index, 1); RefreshAll(); end
    end
    function SeedSourceChanged()
        if strcmp(handles.SeedSource.Value, 'Index input'), handles.Index.Enable = 'on';
        else, handles.Index.Enable = 'off'; end
    end
    function SelectIndex()
        if controller.SelectedDataset ~= 0
            controller.select(controller.SelectedDataset, handles.Index.Value); RefreshAll();
        end
    end
    function SetPolicy()
        controller.ReturnPolicyOverride = handles.Policy.Value; controller.ReturnOccurrences = handles.BLOccurrences.Value;
    end
    function SetScope()
        if strcmp(handles.Scope.Value, 'pronk'), controller.CorrectionSymmetry = 'pronk';
        elseif strcmp(handles.Scope.Value, 'left/right'), controller.CorrectionSymmetry = 'left-right';
        else, controller.CorrectionSymmetry = 'none'; end
    end
    function RefreshAll()
        if isempty(controller.Datasets)
            handles.DatasetList.Items = {'<none>'}; handles.DatasetList.Value = '<none>';
            cla(handles.StateAxes); cla(handles.ContactAxes); return
        end
        handles.DatasetList.Items = {controller.Datasets.name};
        handles.DatasetList.Value = controller.Datasets(controller.SelectedDataset).name;
        handles.Index.Value = controller.SelectedIndex;
        record = controller.selected(); PopulateSeed(record); RefreshPlot(); ShowInfo(record); UpdateStatus();
    end
    function PopulateSeed(record)
        handles.StateTable.Data = [schema.StateNames.', num2cell(record.initial_state)];
        handles.ParameterTable.Data = [schema.ParameterNames.', num2cell(record.parameter)];
        handles.Mode.Value = strtrim(sprintf('%d ', record.initial_mode));
        if ~isempty(record.orbit)
            phase = ComputePhaseDiagram_v3(record.orbit);
            handles.TimingTable.Data = [cellstr(phase.event_names), num2cell(phase.event_times)];
        else, handles.TimingTable.Data = cell(0, 2); end
    end
    function RefreshPlot()
        ax = handles.StateAxes; cla(ax); hold(ax, 'on');
        indices = [find(strcmp(schema.StateNames, handles.XState.Value)), ...
            find(strcmp(schema.StateNames, handles.YState.Value)), find(strcmp(schema.StateNames, handles.ZState.Value))];
        colors = lines(max(1, numel(controller.Datasets)));
        for d = 1:numel(controller.Datasets)
            records = controller.Datasets(d).solutions;
            mask = controller.filter(d, handles.FilterParameter.Value, handles.FilterValue.Value, handles.FilterTolerance.Value);
            selected = find(mask); if isempty(selected), continue; end
            x = zeros(14, numel(selected)); value = zeros(1, numel(selected));
            parameterIndex = schema.parameterIndex(handles.ColorParameter.Value);
            for j = 1:numel(selected), x(:, j) = records{selected(j)}.initial_state; value(j) = records{selected(j)}.parameter(parameterIndex); end
            plot3(ax, x(indices(1), :), x(indices(2), :), x(indices(3), :), '-', ...
                'Color', colors(d, :), 'HandleVisibility', 'off');
            if all(isfinite(value))
                h = scatter3(ax, x(indices(1), :), x(indices(2), :), x(indices(3), :), 35, value, 'filled', 'DisplayName', controller.Datasets(d).name);
                cb = colorbar(ax); cb.Label.String = handles.ColorParameter.Value;
            else
                h = scatter3(ax, x(indices(1), :), x(indices(2), :), x(indices(3), :), 35, colors(d, :), 'filled', 'DisplayName', controller.Datasets(d).name);
            end
            h.ButtonDownFcn = @(~, event) Guard(@() SelectNearest(d, selected, indices, event.IntersectionPoint));
            h.UserData = struct('dataset', d, 'indices', selected, 'parameter_values', value);
        end
        xlabel(ax, handles.XState.Value); ylabel(ax, handles.YState.Value); zlabel(ax, handles.ZState.Value);
        title(ax, 'Periodic solution states (select a point to inspect)'); grid(ax, 'on'); view(ax, 0, 90);
        if ~isempty(controller.Datasets), legend(ax, 'Location', 'best', 'Interpreter', 'none'); end
    end
    function SelectNearest(dataset, available, indices, point)
        if strcmp(handles.SeedSource.Value, 'Index input'), return; end
        records = controller.Datasets(dataset).solutions;
        state = cell2mat(cellfun(@(r) r.initial_state(indices), records(available), 'UniformOutput', false));
        spread = max(max(state, [], 2)-min(state, [], 2), 1e-6);
        [~, j] = min(sum(((state-point(:))./spread).^2, 1));
        controller.select(dataset, available(j)); RefreshAll(); InspectSelection();
    end
    function HoverSelection()
        if ~isvalid(fig) || isempty(controller.Datasets) || ~strcmp(handles.PlotTabs.SelectedTab.Title, 'State Plot'), return; end
        pointer = fig.CurrentPoint; bounds = getpixelposition(handles.StateAxes, true);
        if pointer(1) < bounds(1) || pointer(1) > bounds(1)+bounds(3) || pointer(2) < bounds(2) || pointer(2) > bounds(2)+bounds(4), return; end
        point = handles.StateAxes.CurrentPoint; nearest = Inf; description = '';
        lines = findall(handles.StateAxes, 'Type', 'scatter');
        for plotIndex = 1:numel(lines)
            h = lines(plotIndex); data = h.UserData;
            if ~isstruct(data) || ~isfield(data, 'dataset'), continue; end
            coordinates = [h.XData(:), h.YData(:), h.ZData(:)];
            if abs(handles.StateAxes.View(2)) == 90, dimensions = 1:2; else, dimensions = 1:3; end
            spread = max(max(coordinates(:, dimensions), [], 1)-min(coordinates(:, dimensions), [], 1), 1e-6);
            [distance, pointIndex] = min(sum(((coordinates(:, dimensions)-point(1, dimensions))./spread).^2, 2));
            if distance < nearest
                nearest = distance; index = data.indices(pointIndex); record = controller.Datasets(data.dataset).solutions{index};
                description = sprintf('%s, point %d; mode %s; y %.6g; dx %.6g', controller.Datasets(data.dataset).name, index, ...
                    mat2str(double(record.initial_mode(:).')), record.initial_state(schema.State.y), record.initial_state(schema.State.dx));
            end
        end
        if ~isempty(description), handles.CursorInfo.Text = description; end
    end
    function InspectSelection()
        record = controller.inspect(); PopulateSeed(record); ShowInfo(record); ComputePhaseDiagram_v3(record.orbit, handles.ContactAxes);
    end
    function ShowInfo(record)
        summary = {sprintf('Dataset %d, solution %d', controller.SelectedDataset, controller.SelectedIndex), ...
            ['Mode [BL BR FL FR]: ', mat2str(double(record.initial_mode(:).'))], record.status, ...
            sprintf('Scaled closure residual: %.3e; accepted=%d', record.residual_norm, record.accepted)};
        if ~isempty(record.orbit)
            orbit = record.orbit;
            summary = [summary, {sprintf('Period %.8g; mean speed %.8g', orbit.period, orbit.stride_displacement(schema.TranslationIndex)/orbit.period), ...
                ['Return: ', char(orbit.return_policy_name)], sprintf('Selected apex %g; return multiplicity %g', orbit.accepted_apex_index, orbit.return_multiplicity), ...
                ['Contact word: ', char(orbit.cyclic_event_signature)], sprintf('Minimum physical margin: %.3e', orbit.minimum_physical_margin)}];
        end
        if isstruct(record.classification) && isfield(record.classification, 'label')
            summary{end + 1} = ['State/event classification: ', char(string(record.classification.label))];
        end
        if isstruct(record.stability) && isfield(record.stability, 'reliable')
            summary{end + 1} = sprintf('Floquet reliable=%d; %s', record.stability.reliable, char(string(record.stability.stability)));
            summary{end + 1} = ['Multipliers: ', mat2str(record.stability.multipliers, 5)];
        end
        handles.Info.Value = summary;
    end
    function ApplySeed()
        state = cell2mat(handles.StateTable.Data(:, 2)); parameter = cell2mat(handles.ParameterTable.Data(:, 2));
        mode = ParseValues(handles.Mode.Value); record = controller.editSeed(state, parameter, mode); PopulateSeed(record); ShowInfo(record);
    end
    function Perturb(), ApplySeed(); record = controller.perturb(handles.Noise.Value, handles.ParameterNoise.Value, handles.RNG.Value); PopulateSeed(record); ShowInfo(record); end
    function Predict(), record = controller.predict(handles.Prediction.Value); PopulateSeed(record); ShowInfo(record); end
    function Correct()
        ConfigureSolver(); ApplySeed(); record = controller.correct(); PopulateSeed(record); ShowInfo(record);
        handles.SolveInfo.Value = {record.status, sprintf('Independent forward residual: %.3e', record.residual_norm)};
    end
    function PlotCandidate(), controller.plotCandidate(); RefreshAll(); end
    function ConfigureSolver()
        controller.SolverOptions.Algorithm = handles.Algorithm.Value;
        controller.SolverOptions.MaxIterations = handles.MaxIterations.Value;
        controller.SolverOptions.MaxFunctionEvaluations = handles.MaxEvaluations.Value;
        controller.SolverOptions.FunctionTolerance = handles.RootTolerance.Value;
    end
    function SecondSeed(), ConfigureSolver(); record = controller.secondSeed(handles.Radius.Value, handles.Scope.Value); handles.SolveInfo.Value = {record.status, controller.Status}; end
    function Floquet(), record = controller.analyzeFloquet(handles.Scope.Value); ShowInfo(record); end
    function Bifurcations()
        events = controller.bifurcationDiagnostics();
        handles.Info.Value = {sprintf('%d numerical bifurcation candidates; attachment and theorem conditions require independent evidence.', numel(events)), jsonencode(events)};
    end
    function values = ParseValues(text)
        values = sscanf(strrep(char(text), ',', ' '), '%f').';
        if isempty(values) || any(~isfinite(values)), error('SLIP_Quadruped_GUI_v3:Values', 'Enter explicit finite numeric values.'); end
    end
    function ApplyView()
        if ~isempty(handles.Limits.Value)
            bounds = ParseValues(handles.Limits.Value);
            if numel(bounds) ~= 6 || any(bounds([1 3 5]) >= bounds([2 4 6])), error('SLIP_Quadruped_GUI_v3:Limits', 'Provide six increasing axis bounds.'); end
            xlim(handles.StateAxes, bounds(1:2)); ylim(handles.StateAxes, bounds(3:4)); zlim(handles.StateAxes, bounds(5:6));
        end
        aspect = ParseValues(handles.Aspect.Value); direction = ParseValues(handles.View.Value);
        if numel(aspect) ~= 3 || any(aspect <= 0) || numel(direction) ~= 2, error('SLIP_Quadruped_GUI_v3:View', 'Aspect needs three positive values and view two angles.'); end
        pbaspect(handles.StateAxes, aspect); view(handles.StateAxes, direction(1), direction(2));
    end
    function ExportPlot()
        file = controller.prepareOutput(handles.ExportPath.Value);
        if strcmp(handles.PlotTabs.SelectedTab.Title, 'Hildebrand Plot'), target = handles.ContactAxes; else, target = handles.StateAxes; end
        exportgraphics(target, file, 'Resolution', 180);
    end
    function SaveSolution()
        controller.saveSolution(handles.SavePath.Value);
    end
    function StartFixed()
        ConfigureSolver(); controller.startRun('fixed', '', [], '', [], struct('MaxPoints', handles.Points.Value, 'StepSize', handles.Step.Value, 'Scope', handles.Scope.Value, 'Checkpoint', handles.CheckpointPath.Value));
    end
    function StartParameter(), ConfigureSolver(); controller.startRun('parameter', handles.Parameter1.Value, ParseValues(handles.Values1.Value), '', [], struct('Scope', handles.Scope.Value, 'Checkpoint', handles.CheckpointPath.Value)); end
    function StartScan(), ConfigureSolver(); controller.startRun('scan', handles.ScanParameter1.Value, ParseValues(handles.ScanValues1.Value), handles.ScanParameter2.Value, ParseValues(handles.ScanValues2.Value), struct('Scope', handles.Scope.Value, 'Checkpoint', handles.CheckpointPath.Value)); end
    function Resume(), controller.resumeRun(); end
    function LoadPartial()
        [name, folder] = uigetfile(fullfile(root, 'GUI_v3', 'Outputs_v3', '*.mat'), 'Load a v3 GUI checkpoint');
        if isequal(name, 0), return; end
        controller.resumeRun(fullfile(folder, name));
    end
    function PlotPartial(), controller.plotRun(); RefreshAll(); end
    function Tick()
        if busy, return; end
        busy = true; cleanup = onCleanup(@() ReleaseBusy());
        controller.stepRun();
        if ~isempty(fieldnames(controller.Run)) && ~isempty(controller.Run.accepted)
            points = controller.Run.accepted; states = cell2mat(cellfun(@(r) r.initial_state, points, 'UniformOutput', false));
            previewTargets = [handles.PreviewAxes, handles.ParameterPreviewAxes];
            for target = previewTargets
                plot(target, states(schema.State.dx, :), states(schema.State.y, :), '.-'); xlabel(target, 'dx'); ylabel(target, 'y');
                title(target, sprintf('%d accepted; %d rejected', numel(points), numel(controller.Run.rejected)));
            end
            ShowInfo(points{end});
            if strcmp(controller.Run.kind, 'scan')
                values = cell2mat(cellfun(@(r) r.provenance.gui_queue_values, points.', 'UniformOutput', false));
                scatter(handles.ScanAxes, values(:, 1), values(:, 2), 40, [0 .55 .25], 'filled'); hold(handles.ScanAxes, 'on');
                failures = controller.Run.rejected;
                if ~isempty(failures)
                    rejectedValues = cell2mat(cellfun(@(r) r.values, failures.', 'UniformOutput', false));
                    scatter(handles.ScanAxes, rejectedValues(:, 1), rejectedValues(:, 2), 45, [.8 .1 .1], 'x');
                end
                hold(handles.ScanAxes, 'off');
                xlabel(handles.ScanAxes, controller.Run.parameter1); ylabel(handles.ScanAxes, controller.Run.parameter2);
            end
        end
        UpdateStatus();
    end
    function ReleaseBusy(), busy = false; end
    function PrepareVisualization()
        record = controller.replay(); frames = controller.frames(handles.Strides.Value);
        visualization.Animation = SLIP_Animation_Quad_v3(record.orbit, [], handles.AnimationAxes, struct('AnimationMode', 'Simple'));
        visualization.Orbit = SLIP_PeriodicOrbit_Quad_v3(record.orbit, handles.OrbitAxes);
        visualization.Trajectories = SLIP_Trajectories_Quad_v3(record.orbit, handles.TrajectoryAxes);
        visualization.GRF = SLIP_GRF_Quad_v3(record.orbit, [], handles.GRFAxes);
        for leg = 1:4
            a = schema.Leg.AngleIndices(leg); r = schema.Leg.RateIndices(leg); ax = handles.OscillatorAxes(leg);
            plot(ax, record.orbit.trajectory.state(:, a), record.orbit.trajectory.state(:, r), 'LineWidth', 1.25); hold(ax, 'on');
            visualization.Oscillator(leg) = scatter(ax, frames.state(1, a), frames.state(1, r), 35, 'filled'); hold(ax, 'off');
            xlabel(ax, schema.StateNames{a}); ylabel(ax, schema.StateNames{r}); title(ax, schema.LegNames{leg}); grid(ax, 'on');
        end
        frameIndex = 1; lastSelection = VisualizationIdentity(); Scrub(0);
    end
    function Scrub(normalizedTime)
        if isempty(frames), PrepareVisualization(); end
        target = frames.time(1)+normalizedTime*(frames.time(end)-frames.time(1));
        [~, frameIndex] = min(abs(frames.time-target));
        UpdateFrame(); handles.Scrubber.Value = normalizedTime;
    end
    function UpdateFrame()
        sampleIndex = frameIndex; x = frames.state(sampleIndex, :).'; q = frames.mode(sampleIndex, :).';
        visualization.Animation.update(frames.time(sampleIndex), x, q, false); visualization.Orbit.update(x);
        for leg = 1:4
            visualization.Oscillator(leg).XData = x(schema.Leg.AngleIndices(leg)); visualization.Oscillator(leg).YData = x(schema.Leg.RateIndices(leg));
        end
        drawnow limitrate;
    end
    function Play()
        signature = VisualizationIdentity();
        if isempty(frames) || ~strcmp(lastSelection, signature), PrepareVisualization(); end
        if frameIndex >= numel(frames.time), frameIndex = 1; end
        playbackStartTime = frames.time(frameIndex); playbackWallTimer = tic; playRequested = true;
    end
    function identity = VisualizationIdentity()
        if isempty(controller.Candidate), record = controller.selected(); else, record = controller.Candidate; end
        identity = [mat2str(record.initial_state, 16), mat2str(record.parameter, 16), mat2str(record.initial_mode)];
    end
    function TabChanged()
        if strcmp(handles.Sidebar.SelectedTab.Title, 'Visualization') || strcmp(handles.Sidebar.SelectedTab.Title, 'Oscillator Plot')
            if controller.SelectedDataset > 0 && (isempty(frames) || ~strcmp(lastSelection, VisualizationIdentity()))
                PrepareVisualization();
            end
        end
    end
    function SpeedChanged(fromOscillator)
        if fromOscillator, handles.PlaybackSpeed.Value = handles.OscillatorSpeed.Value;
        else, handles.OscillatorSpeed.Value = handles.PlaybackSpeed.Value; end
        if playRequested, playbackStartTime = frames.time(frameIndex); playbackWallTimer = tic; end
    end
    function StopPlayback(), playRequested = false; end
    function PlayTick()
        if ~playRequested || isempty(frames), return; end
        targetTime = min(frames.time(end), playbackStartTime+toc(playbackWallTimer)*handles.PlaybackSpeed.Value);
        [~, frameIndex] = min(abs(frames.time-targetTime)); UpdateFrame();
        handles.Scrubber.Value = (frames.time(frameIndex)-frames.time(1))/(frames.time(end)-frames.time(1));
        if frameIndex == numel(frames.time), playRequested = false; end
    end
    function ExportKeyframe()
        if isempty(frames), PrepareVisualization(); end
        file = controller.prepareOutput(fullfile(root, 'GUI_v3', 'Outputs_v3', 'animation-keyframe.png'));
        exportgraphics(handles.AnimationAxes, file, 'Resolution', 180);
    end
    function file = RecordVideo(frameLimit)
        if nargin < 1, frameLimit = Inf; end
        if isempty(frames), PrepareVisualization(); end
        file = controller.prepareOutput([handles.MediaPath.Value, '.mp4']);
        record = controller.replay();
        movieFigure = figure('Name', 'v3 animation recording', 'Color', 'w');
        cleanup = onCleanup(@() close(movieFigure));
        movie = SLIP_Animation_Quad_v3(record.orbit, [], movieFigure, struct('AnimationMode', 'Simple'));
        videoFrames = controller.frames(handles.Strides.Value, false);
        writer = VideoWriter(file, 'MPEG-4'); writer.FrameRate = 25*handles.PlaybackSpeed.Value; open(writer);
        writerCleanup = onCleanup(@() close(writer));
        for j = 1:min(numel(videoFrames.time), frameLimit)
            movie.update(videoFrames.time(j), videoFrames.state(j, :).', videoFrames.mode(j, :).', false); drawnow;
            writeVideo(writer, getframe(movieFigure));
        end
    end
    function file = RecordGIF(frameLimit)
        if nargin < 1, frameLimit = Inf; end
        file = RecordGIFViews(false, frameLimit);
    end
    function file = RecordOscillatorGIF(frameLimit)
        if nargin < 1, frameLimit = Inf; end
        file = RecordGIFViews(true, frameLimit);
    end
    function file = RecordGIFViews(oscillators, frameLimit)
        if isempty(frames), PrepareVisualization(); end
        record = controller.replay();
        if oscillators, suffix = '-oscillators.gif'; else, suffix = '.gif'; end
        file = controller.prepareOutput([handles.MediaPath.Value, suffix]);
        movieFigure = figure('Name', 'v3 GIF recording', 'Color', 'w', 'Position', [80 80 640 480]);
        movieCleanup = onCleanup(@() close(movieFigure));
        if oscillators
            markers = gobjects(4, 1);
            for leg = 1:4
                target = subplot(2, 2, leg, 'Parent', movieFigure);
                angle = schema.Leg.AngleIndices(leg); rate = schema.Leg.RateIndices(leg);
                plot(target, record.orbit.trajectory.state(:, angle), record.orbit.trajectory.state(:, rate)); hold(target, 'on');
                markers(leg) = scatter(target, frames.state(1, angle), frames.state(1, rate), 35, 'filled');
                title(target, schema.LegNames{leg}); xlabel(target, schema.StateNames{angle}); ylabel(target, schema.StateNames{rate}); grid(target, 'on');
            end
        else
            movie = SLIP_Animation_Quad_v3(record.orbit, [], movieFigure, struct('AnimationMode', 'Simple'));
        end
        palette = [];
        for exportIndex = 1:min(numel(frames.time), frameLimit)
            if oscillators
                for leg = 1:4
                    markers(leg).XData = frames.state(exportIndex, schema.Leg.AngleIndices(leg));
                    markers(leg).YData = frames.state(exportIndex, schema.Leg.RateIndices(leg));
                end
            else
                movie.update(frames.time(exportIndex), frames.state(exportIndex, :).', frames.mode(exportIndex, :).', false);
            end
            drawnow; rgb = frame2im(getframe(movieFigure));
            if isempty(palette), [indexed, palette] = rgb2ind(rgb, 256);
            else, indexed = rgb2ind(rgb, palette); end
            nextIndex = min(numel(frames.time), exportIndex+1);
            delay = max(.02, (frames.time(nextIndex)-frames.time(exportIndex))/handles.PlaybackSpeed.Value);
            if exportIndex == 1, imwrite(indexed, palette, file, 'gif', 'LoopCount', Inf, 'DelayTime', delay);
            else, imwrite(indexed, palette, file, 'gif', 'WriteMode', 'append', 'DelayTime', delay); end
        end
    end
    function CloseGUI()
        if ~isempty(runTimer) && isvalid(runTimer), stop(runTimer); delete(runTimer); end
        if ~isempty(playTimer) && isvalid(playTimer), stop(playTimer); delete(playTimer); end
        controller.stopRun(); delete(fig); path(originalPath);
    end
end
