function layout = RequireWritableFloquetWorkflowConfig(config)
%REQUIREWRITABLEFLOQUETWORKFLOWCONFIG Reject execution from legacy configs.

    layout = ...
        floquet.workflow.internal.InspectFloquetWorkflowLayout(config);
    if layout.Writable
        return
    end
    if ~isempty(layout.ExistingCheckpointFiles)
        error('FloquetWorkflow:LegacyCheckpointNonResumable', '%s', ...
            layout.Message);
    elseif layout.HasNonemptyChain
        error('FloquetWorkflow:LegacyConfigReadOnly', '%s', ...
            layout.Message);
    else
        error('FloquetWorkflow:LegacyConfigMigrationRequired', '%s', ...
            layout.Message);
    end
end
