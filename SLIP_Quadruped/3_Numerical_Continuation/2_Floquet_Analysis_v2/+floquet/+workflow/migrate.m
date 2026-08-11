function [config, configFile, metadata] = migrate(input, options)
%MIGRATE Explicitly convert an empty legacy v1 workflow config to v2.
%
%   CONFIG = FLOQUET.WORKFLOW.MIGRATE(INPUT) returns a v2 configuration in
%   memory. INPUT may be a legacy scalar config or workflow MAT file. The
%   conversion is rejected when any configured artifact or checkpoint
%   exists; completed v1 chains remain read-only scientific records.
%
%   [...]=MIGRATE(INPUT,OPTIONS) accepts SaveConfig (default false),
%   ConfigFile, and Overwrite. Saving over a legacy workflow_config.mat
%   therefore requires both SaveConfig=true and Overwrite=true.

    if nargin < 2
        options = struct();
    end
    [config, configFile, metadata] = ...
        floquet.workflow.internal.MigrateFloquetWorkflowConfig( ...
        input, options);
end
