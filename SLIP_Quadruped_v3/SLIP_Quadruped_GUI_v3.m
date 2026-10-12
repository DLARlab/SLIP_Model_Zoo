function [fig, controller, handles] = SLIP_Quadruped_GUI_v3(options)
%SLIP_QUADRUPED_GUI_V3 Familiar quadruped workflow on independent v3 services.
%   [FIG,CONTROLLER,HANDLES] permits callback-level checks. Options: Visible
%   ('on'/'off'), Position ([x y width height]), DatasetFile (in-v3 MAT),
%   StartTimers (true/false). Numerical data, checkpoints and exports are
%   confined to v3. Paths are restored when the window closes.
    if nargin < 1, options = struct(); end
    screen=get(groot,'ScreenSize');width=min(max(1120,.78*screen(3)),.95*screen(3));height=min(max(740,.82*screen(4)),.92*screen(4));
    defaultPosition=[max(1,(screen(3)-width)/2),max(1,(screen(4)-height)/2),width,height];
    settings = struct('Visible', 'on', 'Position', defaultPosition, ...
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
    for pathIndex = 1:numel(folders), V3LegacyAddPath_v3(fullfile(root, folders{pathIndex})); end
    V3LegacyAddPath_v3(fullfile(root,'4_Solution_Management'));
    try
    controller = QuadrupedGUIController_v3(root);
    schema = controller.Schema;
    fig = uifigure('Name', 'SLIP Quadruped GUI v3', 'Position', settings.Position, ...
        'Visible', settings.Visible, 'Scrollable', 'on');
    runTimer = []; playTimer = []; closing = false; cleaning = false;
    visualization = struct(); frames = []; frameIndex = 1; selectionVisible = false;
    playRequested = false; lastSelection = ''; busy = false; playbackWallTimer = []; playbackStartTime = 0;
    seedBaseline = []; manualLimits = false; savedLimits = []; recordingFigure = [];
    oscillatorPlaying=false;oscillatorWallTimer=[];presentationOrbit=[];activeContinuationTab=1;
    cb = struct();
    cb.SelectFolder = @(varargin) Guard(@SelectFolder);
    cb.LoadSelected = @(varargin) Guard(@LoadSelected);
    cb.LoadAll = @(varargin) Guard(@LoadAll);
    cb.RemoveAll = @(varargin) Guard(@RemoveAll);
    cb.SelectDataset = @(varargin) Guard(@SelectDataset);
    cb.RemoveSelected = @(varargin) Guard(@RemoveSelected);
    cb.FilterChanged = @(varargin) Guard(@FilterChanged);
    cb.VaryingChanged = @(varargin) Guard(@VaryingChanged);
    cb.SelectVarying = @(varargin) Guard(@SelectVarying);
    cb.RefreshPlot = @(varargin) Guard(@RefreshPlot);
    cb.AxesChanged = @(varargin) Guard(@AxesChanged);
    cb.ClearSelection = @(varargin) Guard(@ClearSelection);
    cb.ApplyLimits = @(varargin) Guard(@ApplyLimits);
    cb.Roadmap = @(varargin) Guard(@Roadmap);
    cb.ApplyAspect = @(varargin) Guard(@ApplyAspect);
    cb.CustomView = @(varargin) Guard(@CustomView);
    cb.ApplyView = @(varargin) Guard(@ApplyView);
    cb.ExportPlot = @(varargin) Guard(@ExportPlot);
    cb.Play = @(varargin) Guard(@Play);
    cb.StopPlayback = @(varargin) Guard(@StopPlayback);
    cb.VisualSettings = @(varargin) Guard(@VisualSettings);
    cb.PrepareVisualization = @(varargin) Guard(@PrepareVisualization);
    cb.ExportKeyframe = @(varargin) Guard(@ExportKeyframe);
    cb.SeedSourceChanged = @(varargin) Guard(@SeedSourceChanged);
    cb.SelectIndex = @(varargin) Guard(@SelectIndex);
    cb.Perturb = @(varargin) Guard(@Perturb);
    cb.Predict = @(varargin) Guard(@Predict);
    cb.PlotCandidate = @(varargin) Guard(@PlotCandidate);
    cb.RemoveCandidate = @(varargin) Guard(@RemoveCandidate);
    cb.PlotPredicted = @(varargin) Guard(@() PlotCandidate('predicted'));
    cb.RemovePredicted = @(varargin) Guard(@() RemoveCandidate('predicted'));
    cb.PlotSolved = @(varargin) Guard(@() PlotCandidate('solved'));
    cb.RemoveSolved = @(varargin) Guard(@() RemoveCandidate('solved'));
    cb.Correct = @(varargin) Guard(@Correct);
    cb.InspectSelection = @(varargin) Guard(@InspectSelection);
    cb.SaveSolution = @(varargin) Guard(@SaveSolution);
    cb.RemoveSecondSeed = @(varargin) Guard(@RemoveSecondSeed);
    cb.PlotSeedPair = @(varargin) Guard(@PlotSeedPair);
    cb.StartFixed = @(varargin) Guard(@StartFixed);
    cb.StartParameter = @(varargin) Guard(@StartParameter);
    cb.StartScan = @(varargin) Guard(@StartScan);
    cb.PauseRun = @(varargin) PauseRun();
    cb.StopRun = @(varargin) StopRun();
    cb.Resume = @(varargin) Guard(@Resume);
    cb.PlotPartial = @(varargin) Guard(@PlotPartial);
    cb.LoadPartial = @(varargin) Guard(@LoadPartial);
    cb.OscillatorIndexChanged = @(varargin) Guard(@OscillatorIndexChanged);
    cb.OscillatorIndexEntered = @(varargin) Guard(@OscillatorIndexEntered);
    cb.RecordOscillatorGIF = @(varargin) Guard(@RecordOscillatorGIF);
    cb.ApplySeed = @(varargin) Guard(@ApplySeed);
    cb.SolverAlgorithmChanged = @(varargin) Guard(@SolverAlgorithmChanged);
    cb.SetPolicy = @(varargin) Guard(@SetPolicy);
    cb.SetScope = @(varargin) Guard(@SetScope);
    cb.Floquet = @(varargin) Guard(@Floquet);
    cb.Bifurcations = @(varargin) Guard(@Bifurcations);
    cb.RecordGIF = @(varargin) Guard(@RecordGIF);
    cb.RecordVideo = @(varargin) Guard(@RecordVideo);
    cb.GraphicsSettingsChanged=@(varargin)Guard(@ApplyGraphicsSettings);
    cb.ContinuationSecond = @(k) Guard(@() ContinuationSecond(k));
    cb.ScrubChanging = @(~,e) Guard(@() Scrub(e.Value));
    cb.ScrubChanged = @(s,~) Guard(@() Scrub(s.Value));
    cb.TimeChanged = @(s,~) Guard(@() Scrub(s.Value));
    cb.SpeedChanged = @(varargin) Guard(@() SpeedChanged(false));
    cb.OscillatorSpeedChanged = @(varargin) Guard(@() SpeedChanged(true));
    handles = BuildQuadrupedGUILayout_v3(fig,schema,root,cb);
    fig.CloseRequestFcn = @(~,~) CloseGUI();
    fig.DeleteFcn = @(~,~) DisposeGUI();
    runTimer = timer('Name', 'SLIP_v3_continuation', 'ExecutionMode', 'fixedSpacing', 'Period', .2, ...
        'BusyMode', 'drop', 'TimerFcn', @(~,~) Guard(@Tick));
    playTimer = timer('Name', 'SLIP_v3_playback', 'ExecutionMode', 'fixedSpacing', 'Period', .04, ...
        'BusyMode', 'drop', 'TimerFcn', @(~,~) Guard(@PlayTick));
    RefreshFiles();
    if ~isempty(settings.DatasetFile)
        OpenFile(settings.DatasetFile);
    end
    fig.WindowButtonMotionFcn = @(~, ~) HoverSelection();
    fig.WindowButtonDownFcn = @(~, ~) Guard(@SelectAtPointer);
    fig.WindowKeyPressFcn = @(~,e) KeyPressed(e);
    handles.StateTable.CellEditCallback=@(~,~)Guard(@ApplySeed);
    handles.ParameterTable.CellEditCallback=@(~,~)Guard(@ApplySeed);
    handles.AxisListener=addlistener(handles.StateAxes,'MarkedClean',@(~,~)SyncAxisFields());
    handles.Sidebar.SelectionChangedFcn = @(~, ~) Guard(@TabChanged);
    handles.Callbacks = struct('Refresh', @RefreshAll, 'Inspect', @InspectSelection, 'Correct', @Correct, ...
        'SecondSeed', @SecondSeed, 'Continue', @StartFixed, 'Floquet', @Floquet, 'Animate', @PrepareVisualization, ...
        'Save', @SaveSolution, 'Tick', @Tick, 'Scrub', @Scrub, 'Close', @CloseGUI, ...
        'RecordMP4', @RecordVideo, 'RecordGIF', @RecordGIF, 'RecordOscillatorGIF', @RecordOscillatorGIF, 'Play', @Play, 'PlayTick', @PlayTick, ...
        'OpenDataset', @OpenDataset, 'LoadDataset', @OpenFile, 'SelectFolder', @SelectFolder, 'RefreshFiles', @RefreshFiles, ...
        'LoadSelected', @LoadSelected, 'LoadAll', @LoadAll, 'SelectIndex', @SelectIndex, ...
        'SelectPoint', @SelectNearest, 'ApplyLimits', @ApplyLimits, 'ApplyView', @ApplyView, ...
        'ApplyAspect', @ApplyAspect, 'FilterChanged', @FilterChanged, 'VaryingChanged', @VaryingChanged, ...
        'PlotCandidate', @PlotCandidate, 'RemoveCandidate', @RemoveCandidate, ...
        'PlotPredicted', @() PlotCandidate('predicted'), 'RemovePredicted', @() RemoveCandidate('predicted'), ...
        'PlotSolved', @() PlotCandidate('solved'), 'RemoveSolved', @() RemoveCandidate('solved'), ...
        'StartFixed', @StartFixed, 'StartParameter', @StartParameter, 'StartScan', @StartScan, ...
        'PauseRun', @PauseRun, 'StopRun', @StopRun, 'ResumeRun', @Resume, 'SetFrame', @Scrub);
    fig.UserData = struct('controller', controller, 'handles', handles);
    catch startupException
        if exist(V3Path_v3('runTimer'), 'var') && ~isempty(runTimer) && isvalid(runTimer), stop(runTimer); delete(V3Path_v3(runTimer)); end
        if exist(V3Path_v3('playTimer'), 'var') && ~isempty(playTimer) && isvalid(playTimer), stop(playTimer); delete(V3Path_v3(playTimer)); end
        if exist(V3Path_v3('fig'), 'var') && isvalid(fig), delete(V3Path_v3(fig)); end
        path(originalPath); rethrow(startupException);
    end


    function Guard(action)
        if busy || closing || ~isvalid(fig), return; end
        busy=true;release=onCleanup(@ReleaseBusy);
        try, action(); if ~closing, UpdateStatus(); end
        catch exception
            if ~closing && isvalid(fig), handles.Status.Value = {sprintf('%s: %s', exception.identifier, exception.message)}; end
        end
    end
    function UpdateStatus()
        if ~isvalid(fig),return;end
        messages={controller.Status};
        if ~isempty(fieldnames(controller.Run))&&any(strcmp(controller.Run.status,{'paused','stopped'}))
            state=controller.Run.status;state(1)=upper(state(1));
            messages=[{[state,'; accepted partial results are retained.']},messages];
        end
        handles.Status.Value=messages;
    end
    function RefreshFiles()
        files = controller.setFolder(controller.Folder);
        if isempty(files), files = {'<none>'}; end
        handles.File.Items = files; handles.File.Value = files{1};
    end
    function OpenDataset()
        [name, folder] = uigetfile({'*.mat', 'Solution datasets (*.mat)'}, ...
            'Open a solution dataset inside SLIP_Quadruped_v3', fullfile(controller.Folder, '*.mat'));
        if isequal(name, 0), return; end
        OpenFile(fullfile(folder, name));
    end
    function OpenFile(file)
        file = controller.confinedPath(file, true);
        controller.setFolder(fileparts(file)); RefreshFiles();
        controller.loadDataset(file);
        [~, name, extension] = fileparts(file);
        handles.File.Value = [name, extension];
        RefreshAll();
    end
    function SelectFolder(folder)
        % Native macOS folder dialogs can leave MATLAB's desktop in front.
        % Restore this window immediately, including when the user cancels.
        if nargin < 1
            folder = uigetdir(controller.Folder, 'Select a data folder inside SLIP_Quadruped_v3');
        end
        BringGUIToFront();
        if isequal(folder, 0), return; end
        controller.setFolder(folder); RefreshFiles();
        handles.Status.Value = {sprintf('Found %d solution datasets. Select a file and click Plot, or click Plot All.', ...
            sum(~strcmp(handles.File.Items, '<none>')))};
    end
    function BringGUIToFront()
        if closing||~isvalid(fig)||strcmp(fig.Visible,'off'),return;end
        if strcmpi(fig.WindowState,'minimized'),fig.WindowState='normal';end
        % This is the same visibility/focus restoration used by v2. Hidden
        % programmatic GUI sessions stay hidden.
        fig.Visible='off';drawnow;
        if closing||~isvalid(fig),return;end
        fig.Visible='on';drawnow;figure(fig);
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
    function RemoveAll(), StopPlayback(); controller.removeAll(); frames=[]; selectionVisible=false; RefreshAll(); end
    function RemoveSelected(), StopPlayback(); controller.remove(); frames=[]; selectionVisible=false; RefreshAll(); end
    function SelectDataset()
        index = find(strcmp({controller.Datasets.name}, handles.DatasetList.Value), 1);
        if ~isempty(index), StopPlayback(); controller.select(index, 1); selectionVisible=true; RefreshAll(); end
    end
    function SeedSourceChanged()
        if strcmp(handles.SeedSource.Value, 'Index input'), handles.Index.Enable = 'on';
        else, handles.Index.Enable = 'off'; end
    end
    function SelectIndex()
        if controller.SelectedDataset ~= 0
            StopPlayback(); controller.select(controller.SelectedDataset, handles.Index.Value); selectionVisible=true; RefreshAll();
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
            handles.SelectedBranch.Value='';seedBaseline=[];
            ClearStatePlot(); cla(handles.ContactAxes); UpdateParameterChoices(); return
        end
        handles.DatasetList.Items = {controller.Datasets.name};
        handles.DatasetList.Value = controller.Datasets(controller.SelectedDataset).name;
        handles.Index.Value = controller.SelectedIndex;
        record = controller.selected();
        preserveTune=~isempty(seedBaseline)&&isequal(record.initial_state,seedBaseline.initial_state)&& ...
            isequal(record.parameter,seedBaseline.parameter)&&isequal(record.initial_mode,seedBaseline.initial_mode);
        seedBaseline=record;PopulateSeed(record,preserveTune);
        if ~isempty(frames)&&~strcmp(lastSelection,VisualizationIdentity()),frames=[];lastSelection='';end
        handles.SelectedBranch.Value = controller.Datasets(controller.SelectedDataset).name;
        UpdateParameterChoices(); RefreshPlot(); ShowInfo(record); UpdateStatus();
        count = numel(controller.Datasets(controller.SelectedDataset).solutions);
        handles.OscillatorIndexSlider.Limits = [1 max(2,count)]; handles.OscillatorIndexSlider.Value = controller.SelectedIndex;
        handles.OscillatorIndex.Value = controller.SelectedIndex; handles.OscillatorCount.Text = sprintf('/ %d',count);
        if ~isempty(record.orbit), ComputePhaseDiagram_v3(record.orbit,handles.ContactAxes); end
    end
    function RefreshSelection()
        record=controller.selected();seedBaseline=record;PopulateSeed(record);ShowInfo(record);
        handles.Index.Value=controller.SelectedIndex;
        handles.OscillatorIndexSlider.Value=controller.SelectedIndex;
        handles.OscillatorIndex.Value=controller.SelectedIndex;
        if ~isempty(frames)&&~strcmp(lastSelection,VisualizationIdentity()),frames=[];lastSelection='';end
        delete(findall(handles.StateAxes,'Tag','SelectedSolution'));DrawSelection();
        if ~isempty(record.orbit),ComputePhaseDiagram_v3(record.orbit,handles.ContactAxes);end
        UpdateStatus();
    end
    function PopulateSeed(record,preserveTune)
        if nargin<2,preserveTune=false;end
        if isempty(seedBaseline),seedBaseline=record;end
        if preserveTune
            stateTune=handles.StateTable.Data(:,3);parameterTune=handles.ParameterTable.Data(:,3);
        else
            stateTune=num2cell(record.initial_state);parameterTune=num2cell(record.parameter);
        end
        handles.StateTable.Data=[schema.StateNames.',num2cell(seedBaseline.initial_state),stateTune];
        handles.ParameterTable.Data=[schema.ParameterNames.',num2cell(seedBaseline.parameter),parameterTune];
        handles.Mode.Value = strtrim(sprintf('%d ', record.initial_mode));
        if isfield(handles,'PredictionStateDistance')&&controller.SelectedDataset>0
            baseline=controller.selected();
            handles.PredictionStateDistance.Text=sprintf('State: %.3e',norm(cell2mat(stateTune)-baseline.initial_state));
            handles.PredictionParameterDistance.Text=sprintf('Para: %.3e',norm(cell2mat(parameterTune)-baseline.parameter));
        end
        if ~isempty(record.orbit)
            phase = ComputePhaseDiagram_v3(record.orbit);
            handles.TimingTable.Data = [cellstr(phase.event_names), num2cell(phase.event_times), num2cell(phase.event_times)];
        else, handles.TimingTable.Data = cell(0, 3); end
    end
    function ClearStatePlot()
        % cla preserves HandleVisibility=off objects. Remove our hidden
        % component lines explicitly while retaining the axes' view settings.
        delete(findall(handles.StateAxes, 'Type', 'line', 'Tag', 'OrderedContinuationComponent'));
        delete(findall(handles.StateAxes, 'Type', 'line', 'Tag', 'SelectedSolution'));
        delete(findall(handles.StateAxes, 'Type', 'line', 'Tag', 'SeedPair'));
        delete(findall(handles.StateAxes,'Tag','SeedCandidateLabel'));
        cla(handles.StateAxes);
    end
    function UpdateParameterChoices()
        FillParameterValues(handles.FilterParameter,handles.FilterValue);
        FillParameterValues(handles.ColorParameter,handles.VaryingValue);
    end
    function FillParameterValues(parameter,dropdown)
        previous=dropdown.Value; values=[];
        if ~strcmp(parameter.Value,'<none>')
            index=schema.parameterIndex(parameter.Value);
            for d=1:numel(controller.Datasets)
                values=[values,cellfun(@(r)r.parameter(index),controller.Datasets(d).solutions)]; %#ok<AGROW>
            end
        end
        values=unique(values(isfinite(values)));
        items=arrayfun(@(v)sprintf('%.15g',v),values,'UniformOutput',false);
        if isempty(items),items={'<none>'};end
        dropdown.Items=items;
        if ismember(previous,items),dropdown.Value=previous;else,dropdown.Value=items{1};end
    end
    function FilterChanged(),UpdateParameterChoices();RefreshPlot();end
    function VaryingChanged(),UpdateParameterChoices();RefreshPlot();end
    function SelectVarying()
        if strcmp(handles.ColorParameter.Value,'<none>') || strcmp(handles.VaryingValue.Value,'<none>'),return;end
        parameter=schema.parameterIndex(handles.ColorParameter.Value);value=str2double(handles.VaryingValue.Value);
        for d=1:numel(controller.Datasets)
            records=controller.Datasets(d).solutions;
            point=find(cellfun(@(r)abs(r.parameter(parameter)-value)<=handles.FilterTolerance.Value*max(1,abs(value)),records),1);
            if ~isempty(point),controller.select(d,point);selectionVisible=true;RefreshAll();return;end
        end
    end
    function indices=PlotIndices()
        indices=[find(strcmp(schema.StateNames,handles.XState.Value)), ...
            find(strcmp(schema.StateNames,handles.YState.Value)),find(strcmp(schema.StateNames,handles.ZState.Value))];
    end
    function RefreshPlot()
        ax=handles.StateAxes;direction=ax.View;ClearStatePlot();hold(ax,'on');indices=PlotIndices();
        colorbar(ax,'off');
        for d = 1:numel(controller.Datasets)
            records = controller.Datasets(d).solutions;
            mask=controller.filter(d,handles.FilterParameter.Value,str2double(handles.FilterValue.Value),handles.FilterTolerance.Value);
            if strcmp(handles.FilterValue.Value,'<none>'),mask=true(1,numel(records));end
            selected = find(mask); if isempty(selected), continue; end
            x=cell2mat(cellfun(@(r)r.initial_state,records(selected),'UniformOutput',false));
            colors=controller.gaitColors(d);pointColors=colors(selected,:);value=NaN(1,numel(selected));
            if ~strcmp(handles.ColorParameter.Value,'<none>')
                parameterIndex=schema.parameterIndex(handles.ColorParameter.Value);
                value=cellfun(@(r)r.parameter(parameterIndex),records(selected));
                finite=isfinite(value);span=max(value(finite))-min(value(finite));
                if any(finite)&&span>0
                    brightness=.4+.6*(value(finite)-min(value(finite)))/span;
                    pointColors(finite,:)=pointColors(finite,:).*brightness(:);
                end
            end
            for component = controller.lineSegments(d, mask)
                componentStates = cell2mat(cellfun(@(r) r.initial_state, records(component.record_indices), 'UniformOutput', false));
                lineHandle = plot3(ax, componentStates(indices(1), :), componentStates(indices(2), :), componentStates(indices(3), :), '-', ...
                    'Color', colors(component.record_indices(1),:), 'HandleVisibility', 'off', 'HitTest', 'on', 'PickableParts', 'visible', ...
                    'Tag', 'OrderedContinuationComponent');
                lineHandle.UserData = struct('dataset', d, 'component', component.component_index, 'indices', component.record_indices);
                available=component.record_indices;
                lineHandle.ButtonDownFcn=@(~,event)Guard(@()SelectNearest(d,available,indices,event.IntersectionPoint));
            end
            h=scatter3(ax,x(indices(1),:),x(indices(2),:),x(indices(3),:),35,pointColors,'filled','DisplayName',controller.Datasets(d).name);
            if numel(records)==1&&isfield(records{1}.provenance,'gui_candidate_kind')
                kind=records{1}.provenance.gui_candidate_kind;
                if any(strcmp(kind,{'predicted','solved'}))
                    h.CData=[.55 .55 .55];h.MarkerEdgeColor=[.55 .55 .55];h.SizeData=81;h.LineWidth=1.2;
                    if strcmp(kind,'predicted'),h.MarkerFaceColor='none';else,h.MarkerFaceColor=[.55 .55 .55];end
                    offset=.02*[diff(ax.XLim),diff(ax.YLim),diff(ax.ZLim)];
                    position=x(indices,1).'+offset;
                    text(ax,position(1),position(2),position(3),[' ',controller.Datasets(d).name], ...
                        'Interpreter','none','Color',[.55 .55 .55],'BackgroundColor',[1 1 1], ...
                        'Margin',1,'HitTest','off','Tag','SeedCandidateLabel','HandleVisibility','off');
                end
            end
            h.ButtonDownFcn = @(~, event) Guard(@() SelectNearest(d, selected, indices, event.IntersectionPoint));
            h.UserData = struct('dataset', d, 'indices', selected, 'parameter_values', value,'gait_colors',colors(selected,:));
        end
        xlabel(ax, handles.XState.Value); ylabel(ax, handles.YState.Value); zlabel(ax, handles.ZState.Value);
        title(ax,'Plottings of Periodic Solutions');view(ax,direction);
        if manualLimits,xlim(ax,savedLimits(1:2));ylim(ax,savedLimits(3:4));zlim(ax,savedLimits(5:6));end
        if ~isempty(controller.Datasets),legend(ax,'Location','best','Interpreter','none');end
        DrawSelection();drawnow;SyncAxisFields();
    end
    function SelectNearest(dataset, available, indices, point)
        if strcmp(handles.SeedSource.Value, 'Index input'), return; end
        records = controller.Datasets(dataset).solutions;
        state = cell2mat(cellfun(@(r) r.initial_state(indices), records(available), 'UniformOutput', false));
        dimensions=VisibleDimensions();spread=max(max(state(dimensions,:),[],2)-min(state(dimensions,:),[],2),1e-6);
        [~,j]=min(sum(((state(dimensions,:)-reshape(point(dimensions),[],1))./spread).^2,1));
        StopPlayback();controller.select(dataset,available(j));selectionVisible=true;RefreshAll();
    end
    function dimensions=VisibleDimensions()
        direction=handles.StateAxes.View;
        if abs(abs(direction(2))-90)<1e-8,dimensions=[1 2];
        elseif abs(direction(2))<1e-8&&abs(sind(direction(1)))<1e-8,dimensions=[1 3];
        else,dimensions=1:3;end
    end
    function DrawSelection()
        if ~selectionVisible||controller.SelectedDataset==0,return;end
        record=controller.selected();indices=PlotIndices();x=record.initial_state(indices);
        mark=plot3(handles.StateAxes,x(1),x(2),x(3),'ko','MarkerSize',10,'LineWidth',1.5, ...
            'Tag','SelectedSolution','HandleVisibility','off','HitTest','off','PickableParts','none');
        mark.UserData=struct('dataset',controller.SelectedDataset,'index',controller.SelectedIndex);
    end
    function ClearSelection(),selectionVisible=false;delete(findall(handles.StateAxes,'Tag','SelectedSolution'));handles.Info.Value={'Click a branch point to lock selected data info.'};end
    function SelectAtPointer()
        if ~PointerOnStateAxes()||isempty(controller.Datasets),return;end
        target=hittest(fig);
        if isgraphics(target)&&isstruct(target.UserData)&&isfield(target.UserData,'dataset'),return;end
        point=handles.StateAxes.CurrentPoint;best=Inf;chosen=[];dimensions=VisibleDimensions();
        for scatterHandle=findall(handles.StateAxes,'Type','scatter').'
            data=scatterHandle.UserData;if ~isstruct(data)||~isfield(data,'dataset'),continue;end
            states=[scatterHandle.XData(:),scatterHandle.YData(:),scatterHandle.ZData(:)];
            limits=[diff(handles.StateAxes.XLim),diff(handles.StateAxes.YLim),diff(handles.StateAxes.ZLim)];
            distance=sum(((states(:,dimensions)-point(1,dimensions))./max(limits(dimensions),eps)).^2,2);
            [value,index]=min(distance);
            if value<best,best=value;chosen=[data.dataset,data.indices(index)];end
        end
        if best<.0016&&~isempty(chosen)
            StopPlayback();controller.select(chosen(1),chosen(2));selectionVisible=true;RefreshAll();
        end
    end
    function inside=PointerOnStateAxes()
        inside=false;if closing||~isvalid(fig)||~strcmp(handles.PlotTabs.SelectedTab.Title,'State Plot'),return;end
        pointer=fig.CurrentPoint;bounds=getpixelposition(handles.StateAxes,true);
        inside=pointer(1)>=bounds(1)&&pointer(1)<=bounds(1)+bounds(3)&&pointer(2)>=bounds(2)&&pointer(2)<=bounds(2)+bounds(4);
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
        state = cell2mat(handles.StateTable.Data(:, 3)); parameter = cell2mat(handles.ParameterTable.Data(:, 3));
        mode = ParseValues(handles.Mode.Value); record = controller.editSeed(state, parameter, mode); PopulateSeed(record); ShowInfo(record);
    end
    function Perturb(), ApplySeed(); record = controller.perturb(handles.Noise.Value, handles.ParameterNoise.Value, handles.RNG.Value); PopulateSeed(record); ShowInfo(record); end
    function Predict(), record = controller.predict(handles.Prediction.Value); PopulateSeed(record); ShowInfo(record); end
    function Correct()
        ConfigureSolver(); ApplySeed(); record = controller.correct(); ShowInfo(record);
        handles.SolveInfo.Value = {record.status, sprintf('Independent forward residual: %.3e', record.residual_norm)};
    end
    function PlotCandidate(kind)
        if nargin<1
            if isempty(controller.Candidate),error('SLIP_Quadruped_GUI_v3:Candidate','Predict or solve a seed before plotting it.');end
            if controller.Candidate.accepted,kind='solved';else,kind='predicted';end
        end
        if strcmp(kind,'predicted')&&isempty(controller.Candidate),ApplySeed();end
        if strcmp(kind,'solved'),name='Solved seed';else,name='Predicted seed';end
        controller.plotCandidate(name,kind);selectionVisible=true;RefreshAll();
    end
    function ConfigureSolver()
        algorithm=handles.Algorithm.Value;
        if any(strcmp(algorithm,{'levenberg-marquardt','trust-region-dogleg'}))
            controller.SolverOptions.Algorithm='fsolve';
            controller.SolverOptions.FsolveAlgorithm=algorithm;
        else
            controller.SolverOptions.Algorithm=algorithm;
            controller.SolverOptions.FsolveAlgorithm='';
        end
        if strcmp(algorithm,'levenberg-marquardt')
            controller.SolverOptions.FsolveScaleProblem=handles.ScaleProblem.Value;
        else
            controller.SolverOptions.FsolveScaleProblem='';
        end
        controller.SolverOptions.FsolveInitialDamping=[];
        controller.SolverOptions.Display = handles.SolverDisplay.Value;
        controller.SolverOptions.StepTolerance = handles.StepTolerance.Value;
        controller.SolverOptions.MaxWallSeconds = handles.MaxWallSeconds.Value;
        controller.SolverOptions.MaxIterations = handles.MaxIterations.Value;
        controller.SolverOptions.MaxFunctionEvaluations = handles.MaxEvaluations.Value;
        controller.SolverOptions.FunctionTolerance = handles.RootTolerance.Value;
    end
    function SolverAlgorithmChanged()
        if strcmp(handles.Algorithm.Value,'levenberg-marquardt')
            handles.ScaleProblem.Enable='on';handles.ScaleProblem.Value='jacobian';
        else
            handles.ScaleProblem.Value='none';handles.ScaleProblem.Enable='off';
        end
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
        switch handles.ViewPreset.Value
            case 'Top',handles.ViewAzimuth.Value=0;handles.ViewElevation.Value=90;
            case 'Side',handles.ViewAzimuth.Value=0;handles.ViewElevation.Value=0;
        end
        view(handles.StateAxes,handles.ViewAzimuth.Value,handles.ViewElevation.Value);
    end
    function CustomView(),handles.ViewPreset.Value='Custom';ApplyView();end
    function ApplyAspect()
        if strcmp(handles.AspectMode.Value,'Auto'),pbaspect(handles.StateAxes,'auto');
        else,pbaspect(handles.StateAxes,[handles.AspectX.Value,handles.AspectY.Value,handles.AspectZ.Value]);end
    end
    function ApplyLimits()
        bounds=[handles.XMin.Value,handles.XMax.Value,handles.YMin.Value,handles.YMax.Value,handles.ZMin.Value,handles.ZMax.Value];
        if any(bounds([1 3 5])>=bounds([2 4 6])),error('SLIP_Quadruped_GUI_v3:Limits','Each minimum must be smaller than its maximum.');end
        savedLimits=bounds;manualLimits=true;
        xlim(handles.StateAxes,bounds(1:2));ylim(handles.StateAxes,bounds(3:4));zlim(handles.StateAxes,bounds(5:6));
    end
    function SyncAxisFields()
        if closing||~isvalid(fig),return;end
        bounds=[handles.StateAxes.XLim,handles.StateAxes.YLim,handles.StateAxes.ZLim];
        fields={'XMin','XMax','YMin','YMax','ZMin','ZMax'};
        for k=1:6,if handles.(fields{k}).Value~=bounds(k),handles.(fields{k}).Value=bounds(k);end;end
        direction=handles.StateAxes.View;
        handles.ViewAzimuth.Value=direction(1);handles.ViewElevation.Value=direction(2);
        if isequal(direction,[0 90]),handles.ViewPreset.Value='Top';
        elseif isequal(direction,[0 0]),handles.ViewPreset.Value='Side';else,handles.ViewPreset.Value='Custom';end
        if manualLimits,savedLimits=bounds;end
    end
    function Roadmap()
        handles.XMin.Value=0;handles.XMax.Value=10;handles.YMin.Value=-.05;handles.YMax.Value=.15;handles.ZMin.Value=.6;handles.ZMax.Value=1.2;ApplyLimits();
    end
    function AxesChanged()
        % v2 changes the plotted coordinate while retaining limits selected
        % in the six numeric fields or the axes toolbar.
        RefreshPlot();
    end
    function ExportPlot()
        [folder,name]=fileparts(handles.ExportPath.Value);
        file=controller.prepareOutput(fullfile(folder,[name,handles.ExportFormat.Value]));
        if strcmp(handles.PlotTabs.SelectedTab.Title, 'Hildebrand Plot'), target = handles.ContactAxes; else, target = handles.StateAxes; end
        exportgraphics(V3Path_v3(target), file, 'Resolution', 180);
    end
    function SaveSolution()
        controller.saveSolution(handles.SavePath.Value,'solved');
    end
    function RemoveCandidate(kind)
        if nargin<1
            if ~isempty(controller.Candidate)&&controller.Candidate.accepted,kind='solved';else,kind='predicted';end
        end
        controller.removeCandidate(kind);frames=[];lastSelection='';RefreshAll();
    end
    function RemoveSecondSeed(),controller.removeSecondSeed();delete(findall(handles.StateAxes,'Tag','SeedPair'));end
    function PlotSeedPair()
        [first,second]=controller.seedPair();
        if isempty(second),error('SLIP_Quadruped_GUI_v3:SecondSeed','Solve a second seed before plotting the seed pair.');end
        indices=PlotIndices();states=[first.initial_state(indices),second.initial_state(indices)];
        hold(handles.StateAxes,'on');delete(findall(handles.StateAxes,'Tag','SeedPair'));
        plot3(handles.StateAxes,states(1,:),states(2,:),states(3,:),'ms-','Tag','SeedPair','HandleVisibility','off');
    end
    function ContinuationSeed(tab)
        controller.selectSeed(handles.ContinuationSource{tab}.Value,handles.ContinuationIndex{tab}.Value);
    end
    function ContinuationSecond(tab)
        ConfigureSolver();ContinuationSeed(tab);record=controller.secondSeed(handles.ContinuationRadius{tab}.Value,handles.Scope.Value);
        handles.SolveInfo.Value={record.status,controller.Status};PlotSeedPair();
    end
    function StartRunTimer()
        if settings.StartTimers&&~closing&&strcmp(runTimer.Running,'off'),start(runTimer);end
    end
    function StartFixed()
        ConfigureSolver();ContinuationSeed(1);[first,~]=controller.seedPair();
        options=FamilyOptions(1,handles.Points.Value,handles.Step.Value);
        controller.startRun('family-scan','j_pitch',first.parameter(schema.parameterIndex('j_pitch')),'',[],options);
        activeContinuationTab=1;StartRunTimer();
    end
    function StartParameter()
        ConfigureSolver();ContinuationSeed(2);
        controller.startRun('family-scan',handles.Parameter1.Value,ParseValues(handles.Values1.Value),'',[], ...
            FamilyOptions(2,handles.Points.Value,handles.Step.Value));
        activeContinuationTab=2;StartRunTimer();
    end
    function options=FamilyOptions(tab,points,step)
        options=struct('Scope',handles.Scope.Value,'Checkpoint',handles.CheckpointPath.Value, ...
            'MaxPoints',points,'StepSize',step,'Radius',handles.ContinuationRadius{tab}.Value);
    end
    function StartScan()
        ConfigureSolver();ContinuationSeed(3);
        options=FamilyOptions(3,handles.ScanPoints.Value,handles.ScanStep.Value);
        controller.startRun('family-scan',handles.ScanParameter1.Value, ...
            ParseValues(handles.ScanValues1.Value),'',[],options);
        activeContinuationTab=3;StartRunTimer();
    end
    function PauseRun()
        if closing,return;end
        controller.pauseRun();if isvalid(runTimer)&&strcmp(runTimer.Running,'on'),stop(runTimer);end
        handles.Status.Value={'Paused; the current numerical step finishes before further work stops.'};
    end
    function StopRun()
        if closing,return;end
        controller.stopRun();if isvalid(runTimer)&&strcmp(runTimer.Running,'on'),stop(runTimer);end
        handles.Status.Value={'Stopped; the current numerical step finishes and retains accepted partial results.'};
    end
    function Resume(),controller.resumeRun();activeContinuationTab=SelectedContinuationTab();StartRunTimer();end
    function tab=SelectedContinuationTab()
        tab=find(strcmp(handles.ContinuationTabs.SelectedTab.Title,{'1D','Para','2D'}),1);
    end
    function LoadPartial()
        [name, folder] = uigetfile(V3Path_v3(fullfile(root, '2_Graphic_ToolBox', 'GUI_v3', 'Outputs_v3', '*.mat')), 'Load a v3 GUI checkpoint');
        if isequal(name, 0), return; end
        controller.resumeRun(fullfile(folder, name));activeContinuationTab=SelectedContinuationTab();StartRunTimer();
    end
    function PlotPartial(), controller.plotRun(); RefreshAll(); end
    function Tick()
        if closing,return;end
        controller.stepRun();
        if closing||~isvalid(fig),return;end
        if isempty(fieldnames(controller.Run))||~strcmp(controller.Run.status,'running')
            if isvalid(runTimer)&&strcmp(runTimer.Running,'on'),stop(runTimer);end
        end
        if ~isempty(fieldnames(controller.Run)) && ~isempty(controller.Run.accepted)
            points = controller.Run.accepted; states = cell2mat(cellfun(@(r) r.initial_state, points, 'UniformOutput', false));
            if strcmp(controller.Run.kind,'family-scan')
                previewTargets=[handles.PreviewAxes,handles.ParameterPreviewAxes,handles.ScanAxes];
                target=previewTargets(activeContinuationTab);cla(target);hold(target,'on');
                branches=controller.Run.branches;
                for branchIndex=1:numel(branches)
                    component=points(branches(branchIndex).record_indices);
                    if isempty(component),continue;end
                    componentStates=cell2mat(cellfun(@(r)r.initial_state,component,'UniformOutput',false));
                    for pointIndex=1:numel(component)
                        color=controller.gaitColor(component{pointIndex});
                        scatter3(target,componentStates(schema.State.dx,pointIndex),componentStates(schema.State.dphi,pointIndex), ...
                            componentStates(schema.State.y,pointIndex),24,color,'filled','HandleVisibility','off');
                    end
                    color=controller.gaitColor(component{1});
                    plot3(target,componentStates(schema.State.dx,:),componentStates(schema.State.dphi,:),componentStates(schema.State.y,:),'-', ...
                        'Color',color,'DisplayName',sprintf('%s=%g, direction %+d',branches(branchIndex).parameter, ...
                        branches(branchIndex).target_value,branches(branchIndex).direction));
                end
                hold(target,'off');xlabel(target,'dx');ylabel(target,'dphi');zlabel(target,'y');view(target,3);grid(target,'on');
                title(target,sprintf('%d branch components; %d accepted; %d rejected', ...
                    numel(branches),numel(points),numel(controller.Run.rejected)));
            else
                previewTargets = [handles.PreviewAxes, handles.ParameterPreviewAxes];
                for target = previewTargets
                    plot(target, states(schema.State.dx, :), states(schema.State.y, :), '.-'); xlabel(target, 'dx'); ylabel(target, 'y');
                    title(target, sprintf('%d accepted; %d rejected', numel(points), numel(controller.Run.rejected)));
                end
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
        StopPlayback(); record = controller.presentationRecord(); frames = controller.frames(handles.Strides.Value,true,record);
        if closing, return; end
        handles.LayoutVisualization();
        presentationOrbit=record.orbit;
        visualization.Animation = SLIP_Animation_Quad_v3(record.orbit, [], handles.AnimationAxes, struct('AnimationMode', 'Simple'));
        visualization.Orbit=SLIP_PeriodicOrbit_Quad_v3(record.orbit,handles.OrbitAxes,'Color',controller.gaitColor(record));
        visualization.Trajectories = SLIP_Trajectories_Quad_v3(record.orbit, handles.TrajectoryAxes);
        visualization.GRF = SLIP_GRF_Quad_v3(record.orbit, [], handles.GRFAxes);
        PrepareOscillators(record);
        frameIndex = 1; lastSelection = VisualizationIdentity(); Scrub(0);
    end
    function PrepareOscillators(record)
        visualization.OscillatorPlot=DrawQuadrupedOscillators_v3(record.orbit,handles.OscillatorAxes);
        visualization.Oscillator=visualization.OscillatorPlot.Markers;
    end
    function OscillatorIndexChanged()
        handles.Index.Value=round(handles.OscillatorIndexSlider.Value);SelectIndex();PrepareOscillators(controller.presentationRecord());
    end
    function OscillatorIndexEntered()
        handles.Index.Value=handles.OscillatorIndex.Value;SelectIndex();PrepareOscillators(controller.presentationRecord());
    end
    function VisualSettings()
        dialog=uifigure('Name','Visualization Settings','Position',[200 200 370 320]);
        g=uigridlayout(dialog,[8 2]);g.RowHeight={28,28,28,28,28,28,28,28};
        targets={handles.GraphicsParts,handles.GraphicsLegs,handles.GraphicsGRF,handles.RecordGIF,handles.RecordVideo,handles.RecordKeyframes};
        for k=1:numel(targets)
            original=targets{k};checkbox=uicheckbox(g,'Text',original.Text,'Value',original.Value,'ValueChangedFcn',@(s,~)SetCheckbox(original,s.Value));
            checkbox.Layout.Column=[1 2];
        end
        uibutton(g,'Text','Export GIF','ButtonPushedFcn',@(~,~)Guard(@RecordGIF));uibutton(g,'Text','Export MP4','ButtonPushedFcn',@(~,~)Guard(@RecordVideo));
        done=uibutton(g,'Text','Done','ButtonPushedFcn',@(~,~)delete(dialog));done.Layout.Column=[1 2];
        setappdata(dialog,'SLIP_v3_owner',fig);
    end
    function SetCheckbox(control,value)
        if ~isvalid(control),return;end
        control.Value=value;
        ApplyGraphicsSettings();
    end
    function ApplyGraphicsSettings()
        if ~isempty(presentationOrbit)&&isfield(visualization,'Trajectories')
            visualization.Trajectories.update(presentationOrbit,true,true);visualization.GRF.update(presentationOrbit);
            UpdateFrame();
        end
    end
    function Scrub(normalizedTime)
        if isempty(frames)||~strcmp(lastSelection,VisualizationIdentity()),PrepareVisualization();end
        target = frames.time(1)+normalizedTime*(frames.time(end)-frames.time(1));
        [~, frameIndex] = min(abs(frames.time-target));
        UpdateFrame(); handles.Scrubber.Value = normalizedTime; handles.Time.Value = normalizedTime;
    end
    function UpdateFrame()
        if closing || ~isvalid(fig), return; end
        sampleIndex = frameIndex; x = frames.state(sampleIndex, :).'; q = frames.mode(sampleIndex, :).';
        visualization.Animation.update(frames.time(sampleIndex), x, q, false); visualization.Orbit.update(x);
        if handles.GraphicsParts.Value||handles.GraphicsLegs.Value||handles.GraphicsGRF.Value
            history=Trajectory_v3();history.time=frames.time(1:sampleIndex);history.state=frames.state(1:sampleIndex,:);history.mode=frames.mode(1:sampleIndex,:);
            if handles.GraphicsParts.Value||handles.GraphicsLegs.Value
                visualization.Trajectories.update(history,handles.GraphicsParts.Value,handles.GraphicsLegs.Value);
            end
            if handles.GraphicsGRF.Value,visualization.GRF.update(history,presentationOrbit.parameter);end
        end
        UpdateQuadrupedOscillators_v3(visualization.OscillatorPlot,frames.time(sampleIndex));
        drawnow limitrate nocallbacks;
    end
    function Play()
        if strcmp(handles.Sidebar.SelectedTab.Title,'Oscillator Plot')
            if controller.SelectedDataset==0,return;end
            PrepareOscillators(controller.presentationRecord());oscillatorPlaying=true;oscillatorWallTimer=tic;
            if settings.StartTimers&&strcmp(playTimer.Running,'off'),start(playTimer);end
            return;
        end
        signature = VisualizationIdentity();
        if isempty(frames) || ~strcmp(lastSelection, signature), PrepareVisualization(); end
        if handles.RecordGIF.Value,RecordGIF();end
        if closing,return;end
        if handles.RecordVideo.Value,RecordVideo();end
        if closing,return;end
        if handles.RecordKeyframes.Value,RecordKeyframes();end
        if closing,return;end
        if frameIndex >= numel(frames.time), frameIndex = 1; end
        playbackStartTime = frames.time(frameIndex); playbackWallTimer = tic; playRequested = true;
        if settings.StartTimers && strcmp(playTimer.Running,'off'), start(playTimer); end
    end
    function identity = VisualizationIdentity()
        if isempty(controller.Candidate), record = controller.selected(); else, record = controller.Candidate; end
        period=NaN;if ~isempty(record.orbit),period=record.orbit.period;end
        identity=[mat2str(record.initial_state,16),mat2str(record.parameter,16),mat2str(record.initial_mode), ...
            record.return_policy_name,controller.ReturnPolicyOverride,mat2str([controller.SelectedDataset,controller.SelectedIndex,period,handles.Strides.Value],16)];
    end
    function TabChanged()
        StopPlayback();
        handles.LayoutVisualization();
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
    function StopPlayback()
        playRequested=false;oscillatorPlaying=false;
        if ~isempty(playTimer) && isvalid(playTimer) && strcmp(playTimer.Running,'on'), stop(playTimer); end
    end
    function PlayTick()
        if oscillatorPlaying
            if toc(oscillatorWallTimer)<.2/handles.OscillatorSpeed.Value,return;end
            count=numel(controller.Datasets(controller.SelectedDataset).solutions);
            if controller.SelectedIndex>=count,StopPlayback();return;end
            controller.select(controller.SelectedDataset,controller.SelectedIndex+1);selectionVisible=true;
            RefreshSelection();PrepareOscillators(controller.presentationRecord());oscillatorWallTimer=tic;return;
        end
        if ~playRequested || isempty(frames), return; end
        targetTime = min(frames.time(end), playbackStartTime+toc(playbackWallTimer)*handles.PlaybackSpeed.Value);
        [~, frameIndex] = min(abs(frames.time-targetTime)); UpdateFrame();
        handles.Scrubber.Value = (frames.time(frameIndex)-frames.time(1))/(frames.time(end)-frames.time(1));
        handles.Time.Value = handles.Scrubber.Value;
        if frameIndex == numel(frames.time), StopPlayback(); end
    end
    function ExportKeyframe()
        if isempty(frames)||~strcmp(lastSelection,VisualizationIdentity()),PrepareVisualization();end
        file = controller.prepareOutput(fullfile(root, '2_Graphic_ToolBox', 'GUI_v3', 'Outputs_v3', 'animation-keyframe.png'));
        exportgraphics(V3Path_v3(handles.AnimationAxes), file, 'Resolution', 180);
    end
    function RecordKeyframes()
        directory=controller.prepareOutput([handles.MediaPath.Value,'-keyframes',filesep,'frame.png']);directory=fileparts(directory);
        indices=unique([1;find([false;any(diff(frames.mode,1,1)~=0,2)]);round(numel(frames.time)/2);numel(frames.time)]);
        for k=1:numel(indices)
            if closing,return;end
            frameIndex=indices(k);UpdateFrame();drawnow;
            if closing,return;end
            exportgraphics(handles.AnimationAxes,fullfile(directory,sprintf('frame_%03d.png',k)),'Resolution',180);
        end
    end
    function file = RecordVideo(frameLimit)
        if nargin < 1, frameLimit = Inf; end
        if isempty(frames)||~strcmp(lastSelection,VisualizationIdentity()),PrepareVisualization();end
        file = controller.prepareOutput([handles.MediaPath.Value, '.mp4']);
        record=controller.presentationRecord();
        movieFigure = figure('Name', 'v3 animation recording', 'Color', 'w');
        recordingFigure=movieFigure;setappdata(movieFigure,'SLIP_v3_owner',fig);
        cleanup=onCleanup(@()DeleteRecording(movieFigure));
        movie = SLIP_Animation_Quad_v3(record.orbit, [], movieFigure, struct('AnimationMode', 'Simple'));
        videoFrames=controller.frames(handles.Strides.Value,false,record);
        writer = VideoWriter(V3Path_v3(file), 'MPEG-4'); writer.FrameRate = 25*handles.PlaybackSpeed.Value; open(writer);
        writerCleanup = onCleanup(@() close(writer));
        for j = 1:min(numel(videoFrames.time), frameLimit)
            if closing||~isgraphics(movieFigure),break;end
            movie.update(videoFrames.time(j), videoFrames.state(j, :).', videoFrames.mode(j, :).', false); drawnow;
            if closing||~isgraphics(movieFigure),break;end
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
        if isempty(frames)||~strcmp(lastSelection,VisualizationIdentity()),PrepareVisualization();end
        record=controller.presentationRecord();
        if oscillators, suffix = '-oscillators.gif'; else, suffix = '.gif'; end
        file = controller.prepareOutput([handles.MediaPath.Value, suffix]);
        movieFigure = figure('Name', 'v3 GIF recording', 'Color', 'w', 'Position', [80 80 640 480]);
        recordingFigure=movieFigure;setappdata(movieFigure,'SLIP_v3_owner',fig);
        movieCleanup=onCleanup(@()DeleteRecording(movieFigure));
        if oscillators
            target=axes(movieFigure);count=numel(controller.Datasets(controller.SelectedDataset).solutions);
        else
            movie = SLIP_Animation_Quad_v3(record.orbit, [], movieFigure, struct('AnimationMode', 'Simple'));
            count=numel(frames.time);
        end
        palette = [];
        for exportIndex=1:min(count,frameLimit)
            if closing||~isgraphics(movieFigure),break;end
            if oscillators
                source=controller.Datasets(controller.SelectedDataset).solutions{exportIndex};
                stored=controller.presentationRecord(source);DrawQuadrupedOscillators_v3(stored.orbit,target);
            else
                movie.update(frames.time(exportIndex), frames.state(exportIndex, :).', frames.mode(exportIndex, :).', false);
            end
            drawnow;
            if closing||~isgraphics(movieFigure),break;end
            rgb=frame2im(getframe(movieFigure));
            if isempty(palette), [indexed, palette] = rgb2ind(rgb, 256);
            else, indexed = rgb2ind(rgb, palette); end
            if oscillators,delay=.2/handles.OscillatorSpeed.Value;
            else,nextIndex=min(numel(frames.time),exportIndex+1);delay=max(.02,(frames.time(nextIndex)-frames.time(exportIndex))/handles.PlaybackSpeed.Value);end
            if exportIndex == 1, imwrite(V3Path_v3(indexed), palette, file, 'gif', 'LoopCount', Inf, 'DelayTime', delay);
            else, imwrite(V3Path_v3(indexed), palette, file, 'gif', 'WriteMode', 'append', 'DelayTime', delay); end
        end
    end
    function DeleteRecording(target),if isgraphics(target),delete(target);end;end
    function CloseGUI()
        if closing,return;end
        closing=true;playRequested=false;
        controller.requestClose();
        DisposeGUI();
        if isvalid(fig), delete(fig); end
    end
    function DisposeGUI()
        if cleaning,return;end
        cleaning=true;closing=true;playRequested=false;controller.requestClose();
        timers={runTimer,playTimer};
        for k=1:numel(timers)
            timerHandle=timers{k};
            if ~isempty(timerHandle)&&isvalid(timerHandle)
                try,stop(timerHandle);catch,end
                try,delete(timerHandle);catch,end
            end
        end
        for owned=findall(groot,'Type','figure').'
            if isappdata(owned,'SLIP_v3_owner')&&isequal(getappdata(owned,'SLIP_v3_owner'),fig)
                delete(owned);
            end
        end
        if ~isempty(recordingFigure)&&isgraphics(recordingFigure),delete(recordingFigure);end
        path(originalPath);
    end
    function KeyPressed(event)
        if strcmp(event.Key,'escape'),CloseGUI();end
    end
end
