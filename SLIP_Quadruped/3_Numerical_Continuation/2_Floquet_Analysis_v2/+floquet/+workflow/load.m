function [config, source] = load(input)
%LOAD Load workflow configuration data without executing a MATLAB script.
%
%   CONFIG = FLOQUET.WORKFLOW.LOAD(INPUT) accepts a scalar configuration
%   struct or a MAT file containing the scalar variable `config`. Script and
%   function files are deliberately rejected.
%
%   See also floquet.workflow.create.

    [config, source] = ...
        floquet.workflow.internal.LoadFloquetWorkflowConfig(input);
end
