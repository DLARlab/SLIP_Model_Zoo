function [config, state] = confirmCandidates(input, candidateIDs)
%CONFIRMCANDIDATES Confirm Stage-1 candidates for critical-orbit refinement.
%
%   [CONFIG,STATE] = FLOQUET.WORKFLOW.CONFIRMCANDIDATES(INPUT, IDS)
%   validates IDS against the canonical Stage-1 inventory and returns an
%   updated in-memory configuration. It does not overwrite an input config
%   MAT file. Selection is rejected after a Stage-2 artifact exists.

    controller = floquet.workflow.Session();
    controller.LoadConfig(input);
    state = controller.ConfirmCandidates(candidateIDs);
    config = controller.Config;
end
