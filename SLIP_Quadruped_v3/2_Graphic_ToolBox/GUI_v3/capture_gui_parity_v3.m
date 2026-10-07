function evidence = capture_gui_parity_v3()
%CAPTURE_GUI_PARITY_V3 Export native v3 UI at the measured legacy canvas size.
% Run run_gui_workflow_v3 first. This driver loads that accepted solution,
% independently replays it, prepares shared graphics, and exports four views.
    root = V3Root_v3(mfilename('fullpath')); originalPath = path;
    cleanupPath = onCleanup(@() path(originalPath));
    V3LegacyAddPath_v3(root); output = fullfile(root, 'GUI_v3', 'Outputs_v3');
    fixture = fullfile(output, 'workflow-accepted-solution.mat');
    if ~isfile(V3Path_v3(fixture)), error('capture_gui_parity_v3:WorkflowGate', 'Run run_gui_workflow_v3 first.'); end
    [fig, controller, h] = SLIP_Quadruped_GUI_v3(struct('Visible', 'off', 'StartTimers', false, ...
        'DatasetFile', fixture, 'Position', [80 80 1120 740]));
    cleanupGUI = onCleanup(@() h.Callbacks.Close());
    h.Scope.Value = 'pronk'; controller.CorrectionSymmetry = 'pronk';
    h.Callbacks.Inspect(); h.Callbacks.Animate(); h.Callbacks.Scrub(.5);
    titles = {'Info', 'Visualization', 'Solve', 'Continuation'};
    evidence = struct('executed_at', char(datetime('now')), 'matlab_version', version, ...
        'canvas_size', [1120 740], 'files', repmat(struct('tab', '', 'v3', '', ...
        'legacy', '', 'width', 0, 'height', 0), 1, numel(titles)));
    for k = 1:numel(titles)
        tab = findall(fig, 'Type', 'uitab', 'Title', titles{k}); tab(1).Parent.SelectedTab = tab(1); drawnow;
        v3File = fullfile(output, ['GUI_v3_', titles{k}, '_1120x740.png']); exportapp(fig, v3File);
        legacyFile = fullfile(output, ['GUI_Legacy_', titles{k}, '_1120x740.png']);
        current = imfinfo(v3File); reference = imfinfo(legacyFile);
        assert(current.Width == reference.Width && current.Height == reference.Height, 'Canvas sizes differ.');
        evidence.files(k) = struct('tab', titles{k}, 'v3', v3File, 'legacy', legacyFile, ...
            'width', current.Width, 'height', current.Height);
    end
    save(V3Path_v3(fullfile(output, 'GUI_Parity_Screenshots_v3.mat')), 'evidence');
end
