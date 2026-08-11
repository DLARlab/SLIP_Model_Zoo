function [config, configFile, metadata] = create( ...
        parentBranchFile, outputRoot, options)
%CREATE Create a fail-closed parent-only Floquet workflow configuration.
%
%   CONFIG = FLOQUET.WORKFLOW.CREATE(PARENT, OUTPUTROOT) fingerprints the
%   complete parent branch and creates the canonical five-stage artifact
%   layout. By default the configuration is saved to
%   OUTPUTROOT/workflow_config.mat.
%
%   See also floquet.workflow.load.

    if nargin < 3
        options = struct();
    end
    [config, configFile, metadata] = ...
        floquet.workflow.internal.CreateFloquetWorkflowConfig( ...
        parentBranchFile, outputRoot, options);
end
