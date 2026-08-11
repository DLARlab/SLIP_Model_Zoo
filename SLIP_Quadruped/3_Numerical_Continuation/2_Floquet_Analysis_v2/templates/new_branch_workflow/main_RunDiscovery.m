function analysis = main_RunDiscovery(config)
%MAIN_RUNDISCOVERY Reproducible wrapper for full parent-branch discovery.

    if nargin < 1 || isempty(config)
        error('main_RunDiscovery:ConfigRequired', ...
            'Pass a config returned by ExperimentConfig(parentBranchFile).');
    end
    AddFloquetWorkflowPath(config);
    analysis = floquet.workflow.runStage(config, 1);
end
