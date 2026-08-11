function config = BEParentWorkflowConfig()
%BEPARENTWORKFLOWCONFIG Parent-only full-branch workflow for the BE branch.
%
% The one-sided timing chart is selected from the symmetric parent's event
% topology, independently of any desired daughter gait.

    [experimentRoot, floquetRoot, roadmapRoot] = ProfileRoots();
    addpath(floquetRoot, '-begin');
    parentFile = fullfile(roadmapRoot, 'BD1_20_2_BE.mat');
    expectedHash = '3ab8e1f47ea788a95faa541bed9bf02ad53b5e4107f5601a19f96f5464b87d0c';
    config = floquet.workflow.create(parentFile,experimentRoot,struct( ...
        'ExperimentName','BE_parent', ...
        'AnalysisOptions',struct('CheckpointEvery',5), ...
        'SaveConfig',false));
    if ~strcmp(config.ExpectedParentSHA256,expectedHash)
        error('BEParentWorkflowConfig:ParentHash', ...
            'The parent branch does not match the frozen profile hash.');
    end
    config.BranchSwitch.PredictorOptions = struct( ...
        'TimingLiftMode', 'one-sided-sector');
    config.BranchSwitch.CorrectorOptions = struct( ...
        'ConstraintMode', 'oriented-amplitude');
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
