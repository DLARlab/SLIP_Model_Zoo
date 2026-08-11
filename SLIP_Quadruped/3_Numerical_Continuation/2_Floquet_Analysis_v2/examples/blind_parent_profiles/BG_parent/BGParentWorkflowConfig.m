function config = BGParentWorkflowConfig()
%BGPARENTWORKFLOWCONFIG Parent-only full-branch workflow for the BG branch.
%
% The one-sided timing chart is selected from the symmetric parent's event
% topology, independently of any desired daughter gait.

    [experimentRoot, floquetRoot, roadmapRoot] = ProfileRoots();
    addpath(floquetRoot, '-begin');
    parentFile = fullfile(roadmapRoot, 'BD1_20_2_BG.mat');
    expectedHash = 'ccff690f6a6b468ee623259f68dfe71dc077dcf552e35869324bc39c132b2be0';
    config = floquet.workflow.create(parentFile,experimentRoot,struct( ...
        'ExperimentName','BG_parent', ...
        'AnalysisOptions',struct('CheckpointEvery',5), ...
        'SaveConfig',false));
    if ~strcmp(config.ExpectedParentSHA256,expectedHash)
        error('BGParentWorkflowConfig:ParentHash', ...
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
