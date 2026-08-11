function validationReport = main_ValidateExperiment(config)
%MAIN_VALIDATEEXPERIMENT Wrapper for generic and held-out validation.

    if nargin < 1 || isempty(config)
        error('main_ValidateExperiment:ConfigRequired', ...
            'Pass a config returned by ExperimentConfig(parentBranchFile).');
    end
    AddFloquetWorkflowPath(config);
    validationReport = floquet.workflow.runStage(config, 5);
end
