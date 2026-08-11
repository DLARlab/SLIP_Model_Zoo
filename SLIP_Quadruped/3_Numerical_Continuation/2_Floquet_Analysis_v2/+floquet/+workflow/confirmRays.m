function [config, state] = confirmRays(input, selections)
%CONFIRMRAYS Confirm two accepted seeds for each signed continuation ray.
%
%   [CONFIG,STATE] = FLOQUET.WORKFLOW.CONFIRMRAYS(INPUT, SELECTIONS)
%   validates every RayID, seed pair, amplitude, and source-artifact digest,
%   then returns an updated in-memory configuration. It does not overwrite
%   an input config MAT file. Selection is frozen after Stage 4 exists.

    controller = floquet.workflow.Session();
    controller.LoadConfig(input);
    state = controller.SetContinuationSelections(selections);
    config = controller.Config;
end
