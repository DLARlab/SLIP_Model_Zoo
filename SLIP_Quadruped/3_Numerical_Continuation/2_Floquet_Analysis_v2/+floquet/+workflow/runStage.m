function [result, state, config] = runStage(input, stage, statusFcn)
%RUNSTAGE Run one ready stage of the canonical five-stage workflow.
%
%   RESULT = FLOQUET.WORKFLOW.RUNSTAGE(CONFIGORFILE, STAGE) validates the
%   workflow state, executes exactly one stage, then reloads and validates
%   the artifact state. STAGE is 1--5 or a supported stage name.
%
%   [...]=RUNSTAGE(..., STATUSFCN) forwards progress events through the
%   graphics-free workflow controller. The returned CONFIG contains the
%   in-memory configuration used for the run; input MAT files are not
%   silently rewritten.

    if nargin < 3
        statusFcn = [];
    end
    controller = floquet.workflow.Session();
    controller.LoadConfig(input);
    [result, state] = controller.RunStage(stage, statusFcn);
    config = controller.Config;
end
