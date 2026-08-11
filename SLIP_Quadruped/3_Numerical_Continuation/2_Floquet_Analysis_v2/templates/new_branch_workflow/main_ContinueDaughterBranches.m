function daughterReport = main_ContinueDaughterBranches(config)
%MAIN_CONTINUEDAUGHTERBRANCHES Wrapper for same-ray daughter continuation.

    if nargin < 1 || isempty(config)
        error('main_ContinueDaughterBranches:ConfigRequired', ...
            'Pass a config returned by ExperimentConfig(parentBranchFile).');
    end
    AddFloquetWorkflowPath(config);
    daughterReport = floquet.workflow.runStage(config, 4);
end
