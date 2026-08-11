function config = PKParentWorkflowConfig()
%PKPARENTWORKFLOWCONFIG Parent-only full-branch workflow for the PK branch.
%
% The repeated-kernel callbacks remain unset so the workflow fails closed
% instead of selecting arbitrary eigensolver columns.

    [experimentRoot, floquetRoot, roadmapRoot] = ProfileRoots();
    addpath(floquetRoot, '-begin');
    parentFile = fullfile(roadmapRoot, 'PK_20_2.mat');
    expectedHash = '45835bb5024b1dc9b875c7b8f7b205769f537a4ff4144c763058537f44dbf401';
    config = floquet.workflow.create(parentFile,experimentRoot,struct( ...
        'ExperimentName','PK_parent', ...
        'AnalysisOptions',struct('CheckpointEvery',5), ...
        'SaveConfig',false));
    if ~strcmp(config.ExpectedParentSHA256,expectedHash)
        error('PKParentWorkflowConfig:ParentHash', ...
            'The parent branch does not match the frozen profile hash.');
    end
end

function [experimentRoot, floquetRoot, roadmapRoot] = ProfileRoots()
    experimentRoot = fileparts(mfilename('fullpath'));
    examplesRoot = fileparts(fileparts(experimentRoot));
    floquetRoot = fileparts(examplesRoot);
    slipRoot = fileparts(fileparts(floquetRoot));
    roadmapRoot = fullfile(slipRoot, ...
        'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits', ...
        '1_Roadmap');
end
