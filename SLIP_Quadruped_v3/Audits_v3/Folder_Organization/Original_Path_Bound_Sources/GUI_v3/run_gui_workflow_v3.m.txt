function evidence = run_gui_workflow_v3()
%RUN_GUI_WORKFLOW_V3 Actual v3-only callback workflow and persistent screenshots.
% All numerical model parameters are fixed; continuation is a pronk-restricted
% energy family and the Floquet matrix is explicitly that restricted block.
    root = fileparts(fileparts(mfilename('fullpath')));
    oldPath = path; cleanupPath = onCleanup(@() path(oldPath));
    addpath(root);
    output = fullfile(root, 'GUI_v3', 'Outputs_v3');
    x = zeros(14, 1); x(3) = 1.2;
    solution = struct('initial_state', x, 'initial_mode', false(4, 1), ...
        'parameter', [10;10;20;20;1;1;0;0;2;.5], ...
        'provenance', struct('seed_kind', 'analytic-vertical-PIP'));
    fixture = fullfile(output, 'workflow-seed.mat'); save(fixture, 'solution');
    [fig, controller, h] = SLIP_Quadruped_GUI_v3(struct('Visible', 'off', ...
        'StartTimers', false, 'DatasetFile', fixture, 'Position', [80 80 1280 840]));
    closeGUI = onCleanup(@() h.Callbacks.Close());
    h.Scope.Value = 'pronk'; controller.CorrectionSymmetry = 'pronk';
    h.SavePath.Value = fullfile(output, 'workflow-accepted-solution.mat');
    h.CheckpointPath.Value = fullfile(output, 'workflow-partial.mat');
    h.Points.Value = 1; h.Step.Value = .002;
    h.Callbacks.Inspect(); before = controller.selected();
    h.Callbacks.Correct(); corrected = controller.Candidate;
    h.Callbacks.Continue(); h.Callbacks.Tick();
    assert(numel(controller.Run.accepted) == 1, 'The workflow continuation point was not accepted.');
    continued = controller.Run.accepted{1}; h.Callbacks.Tick();
    h.Callbacks.Floquet(); floquet = controller.Candidate.stability;
    h.Callbacks.Animate(); h.Callbacks.Scrub(.5); h.Callbacks.Save();
    assert(before.accepted && corrected.accepted && continued.accepted);
    evidence = struct('executed_at', char(datetime('now')), 'matlab_version', version, ...
        'position', fig.Position, 'seed', before.initial_state, 'parameter', before.parameter, ...
        'load_inspect_residual', before.residual_norm, 'correct_residual', corrected.residual_norm, ...
        'continuation_residual', continued.residual_norm, 'accepted_continuation_points', numel(controller.Run.accepted), ...
        'floquet_scope', 'pronk-invariant-section', 'floquet_reliable', floquet.reliable, ...
        'multipliers', floquet.multipliers, 'saved_solution', h.SavePath.Value);
    h.Sidebar.SelectedTab = h.Sidebar.Children(1); drawnow;
    exportapp(fig, fullfile(output, 'GUI_v3_Info_1280x840.png'));
    h.Sidebar.SelectedTab = h.Sidebar.Children(2); drawnow;
    exportapp(fig, fullfile(output, 'GUI_v3_Visualization_1280x840.png'));
    h.Sidebar.SelectedTab = h.Sidebar.Children(3); drawnow;
    exportapp(fig, fullfile(output, 'GUI_v3_Solve_1280x840.png'));
    h.Sidebar.SelectedTab = h.Sidebar.Children(4); drawnow;
    exportapp(fig, fullfile(output, 'GUI_v3_Continuation_1280x840.png'));
    save(fullfile(output, 'GUI_Workflow_Evidence_v3.mat'), 'evidence');
    disp(evidence);
end
