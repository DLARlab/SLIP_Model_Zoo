function tests = test_floquet_workflow_gui
%TEST_FLOQUETWORKFLOWGUI Fast layout and orchestration-interface tests.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    floquetRoot = fileparts(fileparts(testRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(floquetRoot, '-begin');
    testCase.TestData.FloquetRoot = floquetRoot;
end

function testTwoTabsPreserveViewerAndExposeOrderedWorkflow(testCase)
    [config, cleanup] = FixtureConfig(testCase); %#ok<ASGLU>
    [fig, ui] = FloquetAnalysisGUI([], struct('Visible', 'off', ...
        'WorkflowConfig', config, 'InitialMainTab', 'workflow'));
    figureCleanup = onCleanup(@() DeleteFigure(fig));
    drawnow;

    verifyEqual(testCase, numel(ui.MainTabs.Children), 2);
    verifyEqual(testCase, ui.MainTabs.SelectedTab, ui.WorkflowTab);
    verifyEqual(testCase, ui.WorkflowTab.Title, 'Analyze Workflow');
    verifyEqual(testCase, ui.ResultsTab.Title, 'Analysis Viewer');
    verifyEqual(testCase, numel(ui.Workflow.StagePanels), 5);
    verifyEqual(testCase, {ui.Workflow.StagePanels.Title}, { ...
        'Stage 1 - Full-Branch Floquet Discovery', ...
        'Stage 2 - Review and Refine Candidates', ...
        'Stage 3 - Search and Correct Daughter Seeds', ...
        'Stage 4 - Review Rays and Continue Daughters', ...
        'Stage 5 - Independent Daughter Validation'});

    state = ui.GetWorkflowState();
    verifyTrue(testCase, state.Loaded);
    verifyEqual(testCase, state.BranchPointCount, 5);
    verifyTrue(testCase, state.Stages(1).CanRun);
    verifyFalse(testCase, any([state.Stages(2:5).CanRun]));
end

function testBranchViewMatchesSlipGUIAndSelectionIsInspectionOnly(testCase)
    [config, cleanup] = FixtureConfig(testCase); %#ok<ASGLU>
    [fig, ui] = FloquetAnalysisGUI([], struct('Visible', 'off', ...
        'WorkflowConfig', config, 'InitialMainTab', 'workflow'));
    figureCleanup = onCleanup(@() DeleteFigure(fig));

    verifyEqual(testCase, ...
        ui.Workflow.BranchPlotAdapter.AxisIndices, [1 5 2]);
    verifyEqual(testCase, ui.Workflow.BranchAxes.View, [0 90]);
    verifyEqual(testCase, ui.Workflow.XAxisDropdown.Value, ...
        ui.Workflow.BranchPlotAdapter.AxisOptions{1});
    verifyEqual(testCase, ui.Workflow.YAxisDropdown.Value, ...
        ui.Workflow.BranchPlotAdapter.AxisOptions{5});
    verifyEqual(testCase, ui.Workflow.ZAxisDropdown.Value, ...
        ui.Workflow.BranchPlotAdapter.AxisOptions{2});

    ui.Workflow.SelectIndex(4);
    state = ui.GetWorkflowState();
    fixture = load(config.ParentBranchFile, 'results');
    verifyEqual(testCase, state.SelectedIndex, 4);
    verifyEqual(testCase, state.SelectedSolution.X, ...
        fixture.results(1:13, 4));
    verifyTrue(testCase, state.Stages(1).CanRun, ...
        'Moving the inspection cursor must not alter Stage-1 readiness.');
end

function testProgrammaticInitializationWritesPinnedConfig(testCase)
    [~, cleanup, parentFile, workspace] = FixtureConfig(testCase); %#ok<ASGLU>
    [fig, ui] = FloquetAnalysisGUI([], struct('Visible', 'off', ...
        'InitialMainTab', 'workflow'));
    figureCleanup = onCleanup(@() DeleteFigure(fig));
    ui.Workflow.LoadBranch(parentFile);
    experimentRoot = fullfile(workspace, 'new_workflow');
    [config, configFile] = ui.Workflow.InitializeWorkflow( ...
        parentFile, experimentRoot, struct());

    verifyTrue(testCase, isfile(configFile));
    verifyEqual(testCase, config.ParentBranchFile, parentFile);
    verifyEqual(testCase, numel(config.ExpectedParentSHA256), 64);
    verifyFalse(testCase, config.Selection.Confirmed);
    verifyFalse(testCase, config.Continuation.Confirmed);
    state = ui.GetWorkflowState();
    verifyTrue(testCase, state.Loaded);
    verifyEqual(testCase, state.Stages(1).Status, 'ready');
    verifyEqual(testCase, string(ui.Workflow.SaveConfigButton.Enable), "on");
    verifyTrue(testCase, ...
        ui.Workflow.SaveWorkflowConfig('test-manual-save'));
    saved = load(configFile, 'config', 'workflowConfigMetadata');
    verifyEqual(testCase, saved.config.ParentBranchFile, parentFile);
    verifyEqual(testCase, ...
        saved.workflowConfigMetadata.LastGUIChange, 'test-manual-save');
end

function testIndependentOutputFolderAndSessionReset(testCase)
    [~, cleanup, parentFile, workspace] = FixtureConfig(testCase); %#ok<ASGLU>
    outputParent = fullfile(workspace, 'analysis_output');
    mkdir(outputParent);
    [fig, ui] = FloquetAnalysisGUI([], struct('Visible', 'off'));
    figureCleanup = onCleanup(@() DeleteFigure(fig));

    ui.Workflow.LoadBranch(parentFile);
    ui.Workflow.SelectAnalysisOutputFolder(outputParent);
    experimentRoot = fullfile(outputParent, 'independent_workflow');
    [config, configFile] = ui.Workflow.InitializeWorkflow( ...
        parentFile, experimentRoot, struct());

    verifyEqual(testCase, config.ParentBranchFile, parentFile);
    verifyTrue(testCase, startsWith(configFile, experimentRoot));
    verifyEqual(testCase, ...
        ui.GetWorkflowState().AnalysisOutputParent, outputParent);
    verifyTrue(testCase, isfile(parentFile));

    state = ui.Workflow.ResetWorkflow();
    verifyFalse(testCase, state.Loaded);
    verifyTrue(testCase, isfile(configFile), ...
        'Starting a new parent session must preserve saved analysis files.');
end

function testCompactStageColumnScrollsWithoutStageOneClipping(testCase)
    [config, cleanup] = FixtureConfig(testCase); %#ok<ASGLU>
    [fig, ui] = FloquetAnalysisGUI([], struct('Visible', 'off', ...
        'WorkflowConfig', config, 'InitialMainTab', 'workflow'));
    figureCleanup = onCleanup(@() DeleteFigure(fig));
    fig.Position(3:4) = [900 650];
    drawnow;

    verifyEqual(testCase, string(ui.Workflow.StageScrollPanel.Scrollable), ...
        "on");
    viewport = getpixelposition(ui.Workflow.StageScrollPanel, true);
    content = getpixelposition(ui.Workflow.StageContentPanel, true);
    verifyGreaterThan(testCase, content(4), viewport(4));
    verifyEqual(testCase, ui.Workflow.StageGrid.RowHeight{2}, 250);
    verifyEqual(testCase, ui.Workflow.Stage1Grid.RowHeight{3}, 64);
    verifyEqual(testCase, ...
        cell2mat(ui.Workflow.Stage1ProgressGrid.RowHeight), [38 20]);
    verifyEqual(testCase, ui.Workflow.Stage1ProgressGrid.RowSpacing, 2);
end

function [config, cleanup, parentFile, workspace] = FixtureConfig(~)
    workspace = tempname;
    mkdir(workspace);
    cleanup = onCleanup(@() RemoveFolder(workspace));
    parentFile = fullfile(workspace, 'synthetic_parent.mat');
    results = zeros(29, 5);
    results(1, :) = linspace(0, 1, 5);
    results(2, :) = 1 + linspace(0, 0.1, 5);
    results(5, :) = linspace(-0.2, 0.2, 5);
    results(14:21, :) = repmat((0.1:0.1:0.8).', 1, 5);
    results(22, :) = 1;
    results(23:29, :) = repmat([10;20;2;1;0;0.5;1], 1, 5);
    save(parentFile, 'results');
    [config, ~] = floquet.workflow.create(parentFile, ...
        fullfile(workspace, 'configured_workflow'), ...
        struct('SaveConfig', false));

end

function DeleteFigure(fig)
    if isgraphics(fig)
        delete(fig);
    end
end

function RemoveFolder(folder)
    if isfolder(folder)
        rmdir(folder, 's');
    end
end
