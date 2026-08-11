function config = HEParentWorkflowConfig()
%HEPARENTWORKFLOWCONFIG Parent-only full-branch workflow for the HE branch.
%
% The one-sided timing chart is selected from the symmetric parent's event
% topology, independently of any desired daughter gait.

    [experimentRoot, floquetRoot, roadmapRoot] = ProfileRoots();
    addpath(floquetRoot, '-begin');
    parentFile = fullfile(roadmapRoot, 'BD1_20_2_HE.mat');
    expectedHash = 'c3f7bd53f05729cada19cdb8b074e91d6861849d13c0555b2e5a1812a532c892';
    config = floquet.workflow.create(parentFile,experimentRoot,struct( ...
        'ExperimentName','HE_parent', ...
        'AnalysisOptions',struct('CheckpointEvery',5), ...
        'SaveConfig',false));
    if ~strcmp(config.ExpectedParentSHA256,expectedHash)
        error('HEParentWorkflowConfig:ParentHash', ...
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
