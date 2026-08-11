function state = inspect(input)
%INSPECT Validate artifacts and reconstruct the current workflow state.
%
%   STATE = FLOQUET.WORKFLOW.INSPECT(CONFIGORFILE) never performs Floquet
%   integration or writes artifacts. It validates the existing artifact
%   chain and reports which stage can run next.

    config = floquet.workflow.load(input);
    state = floquet.workflow.internal.InspectFloquetWorkflowState(config);
end
