function seedReport = main_FindDaughterBranches(config)
%MAIN_FINDDAUGHTERBRANCHES Reproducible wrapper for local seed search.

    if nargin < 1 || isempty(config)
        error('main_FindDaughterBranches:ConfigRequired', ...
            'Pass a config returned by ExperimentConfig(parentBranchFile).');
    end
    AddFloquetWorkflowPath(config);
    seedReport = floquet.workflow.runStage(config, 3);
end
