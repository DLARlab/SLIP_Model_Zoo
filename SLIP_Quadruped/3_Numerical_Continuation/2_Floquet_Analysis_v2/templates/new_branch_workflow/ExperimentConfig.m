function config = ExperimentConfig(parentBranchFile)
%EXPERIMENTCONFIG Configure a copied blind bifurcation experiment package.
%
% Copy this template directory and pass the selected parent MAT file. The
% public workflow factory fingerprints it immediately and supplies the
% canonical fail-closed stage schema. Daughter references belong only in a
% separate Stage-5 configuration.

    if nargin < 1 || isempty(parentBranchFile)
        error('ExperimentConfig:ParentBranchRequired', ...
            'Pass the authoritative parent branch MAT file.');
    end

    experimentRoot = fileparts(mfilename('fullpath'));

    % Leave empty while this workflow is below the Floquet-v2 tree. If the
    % template is copied elsewhere, set this to the absolute directory that
    % contains +floquet/ before running any stage.
    configuredFloquetRoot = '';
    AddFloquetWorkflowPath(struct('FloquetRoot', configuredFloquetRoot));
    config = floquet.workflow.create(parentBranchFile,experimentRoot, ...
        struct('ExperimentName','REPLACE_WITH_EXPERIMENT_NAME', ...
        'SaveConfig',false));

    % Add declared FloquetOptions, TrackOptions, or DetectorOptions only
    % when they are chosen without knowledge of a desired bifurcation.
    % Selection and continuation remain explicitly unconfirmed by default.
    % The five numbered stage MAT files are the sole numerical authority;
    % do not create a parallel monolithic experiment-result MAT.
end
