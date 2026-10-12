function h = BuildQuadrupedGUILayout_v3(fig,schema,root,cb)
%BUILDQUADRUPEDGUILAYOUT_V3 V2 panel arrangement with native v3 controls.
% Adapted from SLIP_Quadruped_GUI.m in the protected v2 implementation.
% Numerical actions are callbacks into the independent v3 controller.
    h=struct();
    fig.AutoResizeChildren='off';
    mainContainer=uipanel(fig,'BorderType','none','Position',ClientPosition());
    main=uigridlayout(mainContainer,[3 2]);main.RowHeight={'fit','1x',93};
    main.ColumnWidth={'3.35x','1.85x'};main.Padding=[12 12 12 12];
    main.RowSpacing=10;main.ColumnSpacing=12;
    data=uipanel(main,'Title','Data Info');data.Layout.Row=1;data.Layout.Column=1;
    dg=grid(data,[2 1],{'fit','fit'},{'1x'});
    top=grid(dg,[1 5],{'fit'},{'1.45x','fit',82,82,82});
    h.File=uidropdown(top,'Items',{'<none>'});
    h.SelectFolder=button(top,'Select Folder',cb.SelectFolder);
    button(top,'Plot',cb.LoadSelected);button(top,'Plot All',cb.LoadAll);button(top,'Delete All',cb.RemoveAll);
    params=grid(dg,[1 2],{'fit'},{'1x','1x'});
    fixed=grid(params,[1 3],{'fit'},{'fit','1x','1x'});
    uilabel(fixed,'Text','Fixed Parameter:');
    h.FilterParameter=uidropdown(fixed,'Items',[{'<none>'},schema.ParameterNames],'ValueChangedFcn',cb.FilterChanged);
    h.FilterValue=uidropdown(fixed,'Items',{'<none>'},'ValueChangedFcn',cb.RefreshPlot);
    varying=grid(params,[1 3],{'fit'},{'fit','1x','1x'});
    uilabel(varying,'Text','Varying Parameter:');
    h.ColorParameter=uidropdown(varying,'Items',[{'<none>'},schema.ParameterNames],'ValueChangedFcn',cb.VaryingChanged);
    h.VaryingValue=uidropdown(varying,'Items',{'<none>'},'ValueChangedFcn',cb.SelectVarying);
    h.OpenDataset=h.SelectFolder; % Retain the historical handle alias.
    plotting=uipanel(main,'Title','Plotting');plotting.Layout.Row=2;plotting.Layout.Column=1;
    pg=grid(plotting,[1 1],{'1x'},{'1x'});h.PlotTabs=uitabgroup(pg);
    state=uitab(h.PlotTabs,'Title','State Plot');contact=uitab(h.PlotTabs,'Title','Hildebrand Plot');
    sg=grid(state,[3 3],{'1x','fit','fit'},{'1x','1x','1x'});
    h.StateAxes=uiaxes(sg);h.StateAxes.Layout.Column=[1 3];view(h.StateAxes,0,90);
    % Match v2: inherit box/grid/automatic-limit defaults and retain plotted
    % data when adding branches. A redraw must not impose new axis styling.
    hold(h.StateAxes,'on');
    names={'XState','YState','ZState'};initial=[schema.State.dx,schema.State.dphi,schema.State.y];
    for k=1:3
        label=uilabel(sg,'Text',sprintf('%c-Axis','X'+k-1));label.Layout.Row=2;label.Layout.Column=k;
        h.(names{k})=uidropdown(sg,'Items',schema.StateNames,'Value',schema.StateNames{initial(k)},'ValueChangedFcn',cb.AxesChanged);
        h.(names{k}).Layout.Row=3;h.(names{k}).Layout.Column=k;
    end
    hg=grid(contact,[1 1],{'1x'},{'1x'});h.ContactAxes=uiaxes(hg);
    status=uipanel(main,'Title','Status');status.Layout.Row=3;status.Layout.Column=1;
    st=grid(status,[1 1],{'1x'},{'1x'});h.Status=uitextarea(st,'Editable','off','Value',{'Select Folder lists the available solution datasets. Select a file and click Plot.'});
    h.Sidebar=uitabgroup(main);h.Sidebar.Layout.Row=[1 3];h.Sidebar.Layout.Column=2;
    info=uitab(h.Sidebar,'Title','Info');visual=uitab(h.Sidebar,'Title','Visualization');
    solve=uitab(h.Sidebar,'Title','Solve');continuation=uitab(h.Sidebar,'Title','Continuation');
    oscillator=uitab(h.Sidebar,'Title','Oscillator Plot');native=uitab(h.Sidebar,'Title','v3 Analysis');
    % V2 Info: plotted datasets, two information columns, axis, view, save.
    ig=grid(info,[5 1],{'1x',150,176,'fit','fit'},{'1x'});
    list=uipanel(ig,'Title','Plotted Datasets');lg=grid(list,[2 1],{'1x','fit'},{'1x'});
    h.DatasetList=uilistbox(lg,'Items',{'<none>'},'ValueChangedFcn',cb.SelectDataset);
    button(lg,'Delete',cb.RemoveSelected);
    solution=uipanel(ig,'Title','Solution Info');si=grid(solution,[2 2],{'1x','fit'},{'1x','1x'});
    cp=uipanel(si,'Title','Cursor Info','Scrollable','on');cg=grid(cp,[1 1],{'1x'},{'1x'});
    h.CursorInfo=uilabel(cg,'Text','Move over a branch point','WordWrap','on','VerticalAlignment','top');
    selected=uipanel(si,'Title','Selected Info','Scrollable','on');sel=grid(selected,[1 1],{'1x'},{'1x'});
    h.Info=uitextarea(sel,'Editable','off','Value',{'Click a branch point to lock selected data info.'});
    clear=button(si,'Remove Selected',cb.ClearSelection);clear.Layout.Row=2;clear.Layout.Column=[1 2];
    axisPanel=uipanel(ig,'Title','Axis');axisGrid=grid(axisPanel,[1 1],{'1x'},{'1x'});
    axisTabs=uitabgroup(axisGrid);limitTab=uitab(axisTabs,'Title','Limit');ratioTab=uitab(axisTabs,'Title','Ratio');
    limits=grid(limitTab,[4 4],{'fit','fit','fit','fit'},{'fit','1x','1x','fit'});
    uilabel(limits,'Text','');uilabel(limits,'Text','Min','HorizontalAlignment','center');uilabel(limits,'Text','Max','HorizontalAlignment','center');uilabel(limits,'Text','');
    axesNames={'X','Y','Z'};
    for k=1:3
        lab=uilabel(limits,'Text',axesNames{k});lab.Layout.Row=k+1;lab.Layout.Column=1;
        for j=1:2
            suffix={'Min','Max'};field=[axesNames{k},suffix{j}];
            currentLimits=h.StateAxes.([axesNames{k},'Lim']);
            h.(field)=uieditfield(limits,'numeric','Value',currentLimits(j),'ValueChangedFcn',cb.ApplyLimits);
            h.(field).Layout.Row=k+1;h.(field).Layout.Column=j+1;
        end
    end
    roadmap=button(limits,'Roadmap',cb.Roadmap);roadmap.Layout.Row=2;roadmap.Layout.Column=4;
    ratio=grid(ratioTab,[4 5],{'fit','fit','fit','fit'},{'fit','1x','1x','1x','fit'});
    lab=uilabel(ratio,'Text','Control how wide, tall, and deep the State Plot appears.','WordWrap','on');lab.Layout.Column=[1 5];
    lab=uilabel(ratio,'Text','Mode');lab.Layout.Row=2;lab.Layout.Column=1;
    h.AspectMode=uidropdown(ratio,'Items',{'Auto','Manual'},'ValueChangedFcn',cb.ApplyAspect);h.AspectMode.Layout.Row=2;h.AspectMode.Layout.Column=[2 5];
    lab=uilabel(ratio,'Text','Manual ratio');lab.Layout.Row=4;lab.Layout.Column=1;
    values=[4/3 1 1];
    for k=1:3
        lab=uilabel(ratio,'Text',axesNames{k},'HorizontalAlignment','center');lab.Layout.Row=3;lab.Layout.Column=k+1;
        h.(['Aspect',axesNames{k}])=uieditfield(ratio,'numeric','Value',values(k),'Limits',[eps Inf]);h.(['Aspect',axesNames{k}]).Layout.Row=4;h.(['Aspect',axesNames{k}]).Layout.Column=k+1;
    end
    apply=button(ratio,'Apply',cb.ApplyAspect);apply.Layout.Row=4;apply.Layout.Column=5;
    vp=uipanel(ig,'Title','View');vg=grid(vp,[1 4],{'fit'},{'fit','1x','1x','fit'});
    uilabel(vg,'Text','Angles');h.ViewAzimuth=uieditfield(vg,'numeric','Value',0,'ValueChangedFcn',cb.CustomView);
    h.ViewElevation=uieditfield(vg,'numeric','Value',90,'ValueChangedFcn',cb.CustomView);
    h.ViewPreset=uidropdown(vg,'Items',{'Top','Side','Custom'},'ValueChangedFcn',cb.ApplyView);
    save=uipanel(ig,'Title','Save Plot');saveGrid=grid(save,[2 2],{'fit','fit'},{'fit','1x'});
    uilabel(saveGrid,'Text','File Name:');h.ExportPath=uieditfield(saveGrid,'text','Value',fullfile(root,'2_Graphic_ToolBox','GUI_v3','Outputs_v3','state-plot.png'));
    h.ExportFormat=uidropdown(saveGrid,'Items',{'.png','.pdf'});button(saveGrid,'Save Plot',cb.ExportPlot);
    % V2 Visualization: two playback rows and fixed-aspect scrolling plots.
    vis=grid(visual,[2 1],{130,'1x'},{'1x'});vis.RowSpacing=6;
    playback=uipanel(vis,'Title','Playback/Record');pr=grid(playback,[2 1],{60,34},{'1x'});
    pr.Padding=[6 4 6 4];pr.RowSpacing=3;pr.ColumnSpacing=5;
    sliderRow=grid(pr,[3 1],{'0.1x','0.8x','0.1x'},{'1x'});sliderRow.Padding=[0 0 0 0];sliderRow.RowSpacing=0;
    slider=grid(sliderRow,[1 6],{'1x'},{'fit','1x','1x','1x','1x',64});slider.Layout.Row=2;slider.Padding=[0 0 0 0];slider.ColumnSpacing=5;
    uilabel(slider,'Text','Normalized stride');
    h.Scrubber=uislider(slider,'Limits',[0 1],'MajorTicks',[0 .5 1],'ValueChangingFcn',cb.ScrubChanging,'ValueChangedFcn',cb.ScrubChanged);h.Scrubber.Layout.Column=[2 5];
    timeGrid=grid(slider,[3 1],{'0.15x','0.7x','0.15x'},{'1x'});timeGrid.Layout.Column=6;timeGrid.Padding=[0 0 0 0];timeGrid.RowSpacing=0;
    h.Time=uieditfield(timeGrid,'numeric','Limits',[0 1],'ValueDisplayFormat','%.2f','ValueChangedFcn',cb.TimeChanged);h.Time.Layout.Row=2;
    buttonRow=grid(pr,[3 1],{'0.1x','0.8x','0.1x'},{'1x'});buttonRow.Padding=[0 0 0 0];buttonRow.RowSpacing=0;
    buttons=grid(buttonRow,[1 6],{'1x'},{64,'1x','1x','1x','1x','fit'});buttons.Layout.Row=2;buttons.Padding=[0 0 0 0];buttons.ColumnSpacing=5;
    run=button(buttons,'Run',cb.Play);run.Layout.Column=[1 2];stop=button(buttons,'Stop',cb.StopPlayback);stop.Layout.Column=[3 4];
    settings=button(buttons,char(9881),cb.VisualSettings);settings.Layout.Column=[5 6];settings.Tooltip='Frame update and recording settings';
    h.VisualTabs=uitabgroup(vis);animation=uitab(h.VisualTabs,'Title','Animation');trajectory=uitab(h.VisualTabs,'Title','Trajectories');
    animationScroll=uipanel(animation,'Scrollable','on','BorderType','none','AutoResizeChildren','off','Position',[1 1 100 100]);
    animationContent=uipanel(animationScroll,'BorderType','none','AutoResizeChildren','off','Position',[1 1 500 720]);
    animationPanels=gobjects(2,1);animationNames={'Quadruped Animation','Periodic Orbit'};
    for k=1:2
        animationPanels(k)=uipanel(animationContent,'Title',animationNames{k});g=grid(animationPanels(k),[1 1],{'1x'},{'1x'});g.Padding=[4 4 4 4];ax=uiaxes(g);disableToolbar(ax);
        if k==1,h.AnimationAxes=ax;else,h.OrbitAxes=ax;end
    end
    trajectoryScroll=uipanel(trajectory,'Scrollable','on','BorderType','none','AutoResizeChildren','off','Position',[1 1 100 100]);
    trajectoryContent=uipanel(trajectoryScroll,'BorderType','none','AutoResizeChildren','off','Position',[1 1 500 930]);
    torsoPanel=uipanel(trajectoryContent,'Title','Torso Trajectory');legsPanel=uipanel(trajectoryContent,'Title','Leg Trajectories','AutoResizeChildren','off');
    grfPanel=uipanel(trajectoryContent,'Title','Ground-Reaction Force');trajectoryPanels=gobjects(4,1);
    trajectoryPanels(1)=torsoPanel;trajectoryPanels(2)=uipanel(legsPanel,'Title','Back Legs');trajectoryPanels(3)=uipanel(legsPanel,'Title','Front Legs');trajectoryPanels(4)=grfPanel;
    h.TrajectoryAxes=gobjects(3,1);
    for k=1:4
        g=grid(trajectoryPanels(k),[1 1],{'1x'},{'1x'});g.Padding=[4 4 4 4];ax=uiaxes(g);disableToolbar(ax);
        if k<4,h.TrajectoryAxes(k)=ax;else,h.GRFAxes=ax;end
    end
    h.AnimationScroll=animationScroll;h.AnimationContent=animationContent;h.AnimationPanels=animationPanels;
    h.TrajectoryScroll=trajectoryScroll;h.TrajectoryContent=trajectoryContent;h.TrajectoryPanels=trajectoryPanels;h.LegTrajectoriesPanel=legsPanel;
    % V2 Solve: Seed Info, three entry tables, four tool panels.
    qg=grid(solve,[2 2],{'fit','1x'},{'1.18x','1.05x'});
    seed=uipanel(qg,'Title','Seed Info');seed.Layout.Column=[1 2];ss=grid(seed,[2 4],{'fit','fit'},{'fit','1x','fit','1x'});
    uilabel(ss,'Text','Selected Branch');h.SelectedBranch=uieditfield(ss,'text','Editable','off');h.SelectedBranch.Layout.Column=[2 4];
    uilabel(ss,'Text','Source');h.SeedSource=uidropdown(ss,'Items',{'Cursor','Index input'},'ValueChangedFcn',cb.SeedSourceChanged);
    uilabel(ss,'Text','Index');h.Index=uieditfield(ss,'numeric','Value',1,'Limits',[1 Inf],'RoundFractionalValues','on','Enable','off','ValueChangedFcn',cb.SelectIndex);
    entries=uipanel(qg,'Title','Seed Entries');entries.Layout.Row=2;entries.Layout.Column=1;eg=grid(entries,[3 1],{'14x','6x','10x'},{'1x'});
    h.StateTable=entryTable(eg,'States',[schema.StateNames.',num2cell(zeros(14,2))],true);
    h.TimingTable=entryTable(eg,'Timing',cell(0,3),false);
    h.ParameterTable=entryTable(eg,'Parameters',[schema.ParameterNames.',num2cell(zeros(10,2))],true);
    tools=uipanel(qg,'BorderType','none','Scrollable','on');tools.Layout.Row=2;tools.Layout.Column=2;
    toolGrid=grid(tools,[4 1],{'2.4x','1.2x','1.1x','1.3x'},{'1x'});
    numerical=uipanel(toolGrid,'Title','Numerical Settings','Scrollable','on','AutoResizeChildren','off');numericalContent=uipanel(numerical,'BorderType','none');ng=grid(numericalContent,[8 2],repmat({26},1,8),{'fit','1x'});
    uilabel(ng,'Text','Algorithm');h.Algorithm=uidropdown(ng,'Items',{'newton','fsolve','auto','levenberg-marquardt','trust-region-dogleg'},'ValueChangedFcn',@(~,~)cb.SolverAlgorithmChanged());
    uilabel(ng,'Text','Display');h.SolverDisplay=uidropdown(ng,'Items',{'off','iter','final'});
    h.MaxEvaluations=number(ng,'MaxFunEvals',1200,[1 50000]);h.MaxIterations=number(ng,'MaxIter',40,[1 3000]);
    h.RootTolerance=number(ng,'TolFun',1e-10,[eps 1e-8]);h.StepTolerance=number(ng,'TolX',1e-12,[eps 1]);
    h.MaxWallSeconds=number(ng,'Wall seconds',120,[1 Inf]);
    uilabel(ng,'Text','ScaleProblem');h.ScaleProblem=uidropdown(ng,'Items',{'jacobian','none'},'Value','none','Enable','off');
    set(findall(ng,'Type','uilabel'),'FontSize',11);h.Algorithm.FontSize=11;h.ScaleProblem.FontSize=11;
    noise=uipanel(toolGrid,'Title','Noise','Scrollable','on','AutoResizeChildren','off');noiseContent=uipanel(noise,'BorderType','none');no=grid(noiseContent,[4 2],repmat({26},1,4),{'fit','1x'});
    h.Noise=number(no,'State noise',1e-4,[0 Inf]);h.ParameterNoise=number(no,'Para noise',0,[0 Inf]);h.RNG=number(no,'RNG seed',0,[0 Inf]);
    apply=button(no,'Apply',cb.Perturb);apply.Layout.Column=[1 2];
    prediction=uipanel(toolGrid,'Title','Prediction','Scrollable','on','AutoResizeChildren','off');predictionContent=uipanel(prediction,'BorderType','none');pred=grid(predictionContent,[7 2],repmat({26},1,7),{'fit','1x'});
    distance=uilabel(pred,'Text','Prediction distance:');distance.Layout.Column=[1 2];
    h.PredictionStateDistance=uilabel(pred,'Text','State: n/a');h.PredictionStateDistance.Layout.Column=[1 2];
    h.PredictionParameterDistance=uilabel(pred,'Text','Para: n/a');h.PredictionParameterDistance.Layout.Column=[1 2];
    h.Prediction=number(pred,'Secant factor',1.1,[-Inf Inf]);predict=button(pred,'Predict',cb.Predict);predict.Layout.Column=[1 2];plotPredicted=button(pred,'Plot Predicted',cb.PlotPredicted);plotPredicted.Layout.Column=[1 2];
    remove=button(pred,'Remove Predicted',cb.RemovePredicted);remove.Layout.Column=[1 2];
    solved=uipanel(toolGrid,'Title','Solve','Scrollable','on','AutoResizeChildren','off');solveContent=uipanel(solved,'BorderType','none');sol=grid(solveContent,[7 1],{26,26,52,26,26,26,26},{'1x'});
    button(sol,'Solve',cb.Correct);button(sol,'Replay / Inspect',cb.InspectSelection);
    h.SolveInfo=uitextarea(sol,'Editable','off','Value',{'Residual: n/a','Gait type: n/a'});
    button(sol,'Plot Solved',cb.PlotSolved);button(sol,'Remove Solved',cb.RemoveSolved);button(sol,'Save',cb.SaveSolution);
    h.SavePath=uieditfield(sol,'text','Value',fullfile(root,'2_Graphic_ToolBox','GUI_v3','Outputs_v3','gui-solution.mat'));
    h.SeedToolScrollPanels=[numerical;noise;prediction;solved];h.SeedToolContentPanels=[numericalContent;noiseContent;predictionContent;solveContent];
    % The continuation panels share the legacy Preview/Seed/Action order.
    cont=grid(continuation,[1 1],{'1x'},{'1x'});h.ContinuationTabs=uitabgroup(cont);
    tabNames={'1D','Para','2D'};h.ContinuationSource=cell(1,3);h.ContinuationIndex=cell(1,3);h.ContinuationRadius=cell(1,3);
    h.ContinuationActionPanels=gobjects(3,1);h.ContinuationActionContentPanels=gobjects(3,1);
    for k=1:3
        tab=uitab(h.ContinuationTabs,'Title',tabNames{k});cg=grid(tab,[4 1],{230,'fit','fit','1x'},{'1x'});
        preview=uipanel(cg,'Title','Preview');pa=grid(preview,[1 1],{'1x'},{'1x'});ax=uiaxes(pa);
        if k==1,h.PreviewAxes=ax;elseif k==2,h.ParameterPreviewAxes=ax;else,h.ScanAxes=ax;end
        selection=uipanel(cg,'Title','Seed Selection');se=grid(selection,[1 4],{'fit'},{'fit','1x','fit','1x'});
        uilabel(se,'Text','Source');h.ContinuationSource{k}=uidropdown(se,'Items',{'Cursor','Index input','Percentage input','Solver'});
        uilabel(se,'Text','Value');h.ContinuationIndex{k}=uieditfield(se,'numeric','Value',1,'Limits',[0 Inf]);
        solving=uipanel(cg,'Title','Seed Solving');so=grid(solving,[2 3],{'fit','fit'},{'fit','1x','1x'});
        uilabel(so,'Text','Radius');h.ContinuationRadius{k}=uieditfield(so,'numeric','Value',.01,'Limits',[eps Inf]);
        button(so,'Solve',@()cb.ContinuationSecond(k));button(so,'Remove Seed Pair',cb.RemoveSecondSeed);button(so,'Plot Seed Pair',cb.PlotSeedPair);
        action=uipanel(cg,'Title','Action','Scrollable','on','AutoResizeChildren','off');content=uipanel(action,'BorderType','none');
        rows=7;if k==3,rows=9;end
        ac=grid(content,[rows 2],[{36},repmat({26},1,rows-1)],{'1x','1x'});
        h.ContinuationActionPanels(k)=action;h.ContinuationActionContentPanels(k)=content;
        if k==1
            lab=uilabel(ac,'Text','Fixed parameters; energy-family continuation.','WordWrap','on');lab.Layout.Column=[1 2];
            h.Step=number(ac,'Arc step',.01,[eps Inf]);h.Points=number(ac,'Points / direction',5,[2 1000]);h.Points.RoundFractionalValues='on';
            run=button(ac,'Run',cb.StartFixed);run.Layout.Column=[1 2];
        elseif k==2
            lab=uilabel(ac,'Text','Transport the seed pair; continue a family at the target.','WordWrap','on');lab.Layout.Column=[1 2];
            uilabel(ac,'Text','Parameter');h.Parameter1=uidropdown(ac,'Items',schema.ParameterNames);
            uilabel(ac,'Text','Target');h.Values1=uieditfield(ac,'text','Value','10.01');
            run=button(ac,'Run',cb.StartParameter);run.Layout.Column=[1 2];
        else
            lab=uilabel(ac,'Text','One parameter target list; a continued family at every target.','WordWrap','on');lab.Layout.Column=[1 2];
            uilabel(ac,'Text','Parameter');h.ScanParameter1=uidropdown(ac,'Items',schema.ParameterNames);
            uilabel(ac,'Text','Targets');h.ScanValues1=uieditfield(ac,'text','Value','10 10.01');
            h.ScanPoints=number(ac,'Points / direction',5,[2 1000]);h.ScanPoints.RoundFractionalValues='on';
            h.ScanStep=number(ac,'Arc step',.01,[eps Inf]);
            run=button(ac,'Run',cb.StartScan);run.Layout.Column=[1 2];
        end
        button(ac,'Pause',cb.PauseRun);button(ac,'Stop',cb.StopRun);button(ac,'Resume',cb.Resume);button(ac,'Plot partial',cb.PlotPartial);
        if k==1,h.CheckpointPath=uieditfield(ac,'text','Value',fullfile(root,'2_Graphic_ToolBox','GUI_v3','Outputs_v3','gui-partial.mat'));h.CheckpointPath.Layout.Column=[1 2];
        else,button(ac,'Load partial',cb.LoadPartial);end
    end
    h.Radius=h.ContinuationRadius{1};
    % Oscillator index controls and one legacy-style embedded phase portrait.
    osc=grid(oscillator,[2 1],{180,'1x'},{'1x'});control=uipanel(osc,'Title','Play and Control');oc=grid(control,[3 4],{'fit','fit','fit'},{'fit','1x',65,50});
    uilabel(oc,'Text','Current Index');h.OscillatorIndexSlider=uislider(oc,'Limits',[1 2],'Value',1,'MajorTicks',[],'ValueChangedFcn',cb.OscillatorIndexChanged);
    h.OscillatorIndex=uieditfield(oc,'numeric','Value',1,'Limits',[1 Inf],'RoundFractionalValues','on','ValueChangedFcn',cb.OscillatorIndexEntered);h.OscillatorCount=uilabel(oc,'Text','/ 0');
    uilabel(oc,'Text','Slow');h.OscillatorSpeed=uislider(oc,'Limits',[.1 10],'Value',1,'ValueChangedFcn',cb.OscillatorSpeedChanged);uilabel(oc,'Text','Fast');uilabel(oc,'Text','');
    button(oc,'Play',cb.Play);button(oc,'Pause',cb.StopPlayback);button(oc,'Settings',cb.VisualSettings);button(oc,'GIF',cb.RecordOscillatorGIF);
    oscPanel=uipanel(osc,'Title','Oscillator Plots');osg=grid(oscPanel,[1 1],{'1x'},{'1x'});h.OscillatorAxes=uiaxes(osg);
    % Explicit v3 additions do not displace the original Info controls.
    na=grid(native,[16 2],[repmat({26},1,15),{'1x'}],{'1x','1x'});
    lab=uilabel(na,'Text','Native 14-state model; detected timing is read-only.','WordWrap','on');lab.Layout.Column=[1 2];
    uilabel(na,'Text','Mode [BL BR FL FR]');h.Mode=uieditfield(na,'text','Value','0 0 0 0');
    apply=button(na,'Apply edited seed',cb.ApplySeed);apply.Layout.Column=[1 2];
    h.Policy=uidropdown(na,'Items',{'stored','event-cycle-return','BL-marked-apex-return'},'ValueChangedFcn',cb.SetPolicy);
    h.BLOccurrences=uieditfield(na,'numeric','Value',1,'Limits',[1 100],'RoundFractionalValues','on','ValueChangedFcn',cb.SetPolicy);
    h.Scope=uidropdown(na,'Items',{'full','left/right','pronk'},'ValueChangedFcn',cb.SetScope);button(na,'Floquet',cb.Floquet);
    bif=button(na,'Bifurcations',cb.Bifurcations);bif.Layout.Column=[1 2];
    h.FilterTolerance=number(na,'Filter tolerance',1e-10,[0 Inf]);
    uilabel(na,'Text','Media path');h.MediaPath=uieditfield(na,'text','Value',fullfile(root,'2_Graphic_ToolBox','GUI_v3','Outputs_v3','animation'));
    button(na,'Export GIF',cb.RecordGIF);button(na,'Export MP4',cb.RecordVideo);
    h.GraphicsParts=uicheckbox(na,'Text','Torso frames','Value',false,'ValueChangedFcn',@(~,~)cb.GraphicsSettingsChanged());h.GraphicsLegs=uicheckbox(na,'Text','Leg frames','Value',false,'ValueChangedFcn',@(~,~)cb.GraphicsSettingsChanged());
    h.GraphicsGRF=uicheckbox(na,'Text','GRF frames','Value',false,'ValueChangedFcn',@(~,~)cb.GraphicsSettingsChanged());
    h.RecordGIF=uicheckbox(na,'Text','Record GIF','Value',false);h.RecordVideo=uicheckbox(na,'Text','Record Video','Value',false);h.RecordKeyframes=uicheckbox(na,'Text','Record Keyframes','Value',false);
    h.Strides=number(na,'Strides',1,[1 20]);h.Strides.RoundFractionalValues='on';
    uilabel(na,'Text','Playing speed');h.PlaybackSpeed=uieditfield(na,'numeric','Value',1,'Limits',[.1 10],'ValueChangedFcn',cb.SpeedChanged);
    button(na,'Prepare visualization',cb.PrepareVisualization);button(na,'Export keyframe',cb.ExportKeyframe);
    layoutBusy=false;
    h.LayoutVisualization=@LayoutVisualization;
    h.VisualTabs.SelectionChangedFcn=@(~,~)LayoutVisualization();
    h.ContinuationTabs.SelectionChangedFcn=@(~,~)LayoutVisualization();
    fig.SizeChangedFcn=@(~,~)FigureResized();
    LayoutVisualization();

    function LayoutVisualization()
        if layoutBusy||~isvalid(fig)||~isvalid(h.VisualTabs),return;end
        layoutBusy=true;cleanup=onCleanup(@ReleaseLayout); %#ok<NASGU>
        % Full layout flush is necessary before measuring hidden tab groups;
        % this follows the v2 panel-sizing routine.
        drawnow;
        if ~isvalid(fig)||~isvalid(h.VisualTabs),return;end
        LayoutSeedTools();
        position=getpixelposition(h.VisualTabs,true);
        width=max(260,position(3)-12);height=max(180,position(4)-42);
        animationScroll.Position=[1 1 width height];trajectoryScroll.Position=[1 1 width height];
        margin=2;gap=12;axisWidth=max(240,width-2*margin);plotWidth=max(1,axisWidth-10);
        animationHeight=round(plotWidth*3/4)+30;animationContentHeight=max(height+1,2*animationHeight+3*gap);
        animationContent.Position=[1 1 width animationContentHeight];
        for axisIndex=1:2
            y=animationContentHeight-gap-axisIndex*animationHeight-(axisIndex-1)*gap;
            animationPanels(axisIndex).Position=[margin y axisWidth animationHeight];
        end
        fullPlotHeight=round(plotWidth*3/4)+30;legPlotHeight=round(plotWidth*3/8)+30;
        legSectionHeight=2*legPlotHeight+gap+28;trajectoryContentHeight=max(height,2*fullPlotHeight+legSectionHeight+4*gap);
        trajectoryContent.Position=[1 1 width trajectoryContentHeight];
        y=trajectoryContentHeight-gap-fullPlotHeight;torsoPanel.Position=[margin y axisWidth fullPlotHeight];
        y=y-gap-legSectionHeight;legsPanel.Position=[margin y axisWidth legSectionHeight];
        legInnerHeight=legSectionHeight-28;
        trajectoryPanels(2).Position=[4 legInnerHeight-legPlotHeight axisWidth-8 legPlotHeight];
        trajectoryPanels(3).Position=[4 0 axisWidth-8 legPlotHeight];
        y=y-gap-fullPlotHeight;grfPanel.Position=[margin y axisWidth fullPlotHeight];
    end
    function ReleaseLayout(),layoutBusy=false;end
    function LayoutSeedTools()
        minHeight=[360 155 230 260];
        for toolIndex=1:4
            panel=h.SeedToolScrollPanels(toolIndex);inner=panel.InnerPosition;
            h.SeedToolContentPanels(toolIndex).Position=[1 1 max(1,inner(3)-16) max(minHeight(toolIndex),inner(4)+1)];
        end
        minimum=[246 246 310];
        for continuationIndex=1:3
            panel=h.ContinuationActionPanels(continuationIndex);inner=panel.InnerPosition;
            h.ContinuationActionContentPanels(continuationIndex).Position=[1 1 max(1,inner(3)-4) max(minimum(continuationIndex),inner(4)+1)];
        end
    end
    function FigureResized()
        if ~isvalid(fig)||~isvalid(mainContainer),return;end
        mainContainer.Position=ClientPosition();
        LayoutVisualization();
    end
    function position=ClientPosition()
        if isprop(fig,'InnerPosition'),inner=fig.InnerPosition;else,inner=fig.Position;end
        position=[1 1 inner(3) inner(4)];
    end
end
function disableToolbar(axisHandle)
    try,axtoolbar(axisHandle,{});catch,end
    if isprop(axisHandle,'Toolbar')&&~isempty(axisHandle.Toolbar),axisHandle.Toolbar.Visible='off';end
end
function g=grid(parent,size,rows,columns)
    g=uigridlayout(parent,size);g.RowHeight=rows;g.ColumnWidth=columns;g.Padding=[6 6 6 6];g.RowSpacing=6;g.ColumnSpacing=8;
end
function b=button(parent,label,callback)
    b=uibutton(parent,'Text',label,'ButtonPushedFcn',@(~,~)callback());
end
function e=number(parent,label,value,limits)
    uilabel(parent,'Text',label);e=uieditfield(parent,'numeric','Value',value,'Limits',limits);
end
function t=entryTable(parent,title,data,editable)
    p=uipanel(parent,'Title',title);g=grid(p,[1 1],{'1x'},{'1x'});g.Padding=[0 0 0 0];
    t=uitable(g,'Data',data,'ColumnName',{'Entry','Current','Tune'},'ColumnEditable',[false false editable],'RowName',[],'ColumnWidth',{55,65,'1x'},'FontSize',10);
end
