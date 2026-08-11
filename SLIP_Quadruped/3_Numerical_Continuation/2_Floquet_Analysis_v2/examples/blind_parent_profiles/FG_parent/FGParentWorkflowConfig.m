function config = FGParentWorkflowConfig()
%FGPARENTWORKFLOWCONFIG Parent-only full-branch workflow for the FG branch.
%
% The one-sided timing chart is selected from the symmetric parent's event
% topology, independently of any desired daughter gait.

    [experimentRoot, floquetRoot, roadmapRoot] = ProfileRoots();
    addpath(floquetRoot, '-begin');
    parentFile = fullfile(roadmapRoot, 'BD1_20_2_FG.mat');
    expectedHash = '231895dbb454f914a6f9bd269d2108e761728f3e1cc7a5548be7f0b6a1b6cbf3';
    config = floquet.workflow.create(parentFile,experimentRoot,struct( ...
        'ExperimentName','FG_parent', ...
        'AnalysisOptions',struct('CheckpointEvery',5), ...
        'SaveConfig',false));
    if ~strcmp(config.ExpectedParentSHA256,expectedHash)
        error('FGParentWorkflowConfig:ParentHash', ...
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
