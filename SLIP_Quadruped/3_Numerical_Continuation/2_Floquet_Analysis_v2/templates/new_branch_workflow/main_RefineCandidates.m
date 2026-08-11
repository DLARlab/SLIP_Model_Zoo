function refinementReport = main_RefineCandidates(config)
%MAIN_REFINECANDIDATES Reproducible wrapper for candidate refinement.

    if nargin < 1 || isempty(config)
        error('main_RefineCandidates:ConfigRequired', ...
            'Pass a config returned by ExperimentConfig(parentBranchFile).');
    end
    AddFloquetWorkflowPath(config);
    refinementReport = floquet.workflow.runStage(config, 2);
end
