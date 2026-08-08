function paths = FGGGExperimentPaths()
%FGGGEXPERIMENTPATHS Resolve local FG-to-GG experiment paths.

    paths = CommonPaths(fileparts(mfilename('fullpath')));
    paths.TransitionIDs = {'fg_to_gg'};
    paths.ParentBranchFile = fullfile(paths.ParentBranchRoot, ...
        'BD1_20_2_FG.mat');
    paths.DaughterBranchFiles = {fullfile(paths.DaughterBranchRoot, ...
        'BD1_20_2_GG.mat')};
end

function paths = CommonPaths(experimentRoot)
    paths = struct();
    paths.ExperimentRoot = experimentRoot;
    paths.ExperimentsRoot = fileparts(experimentRoot);
    paths.FloquetRoot = fileparts(paths.ExperimentsRoot);
    paths.ContinuationRoot = fileparts(paths.FloquetRoot);
    paths.SlipRoot = fileparts(paths.ContinuationRoot);
    paths.RepositoryRoot = fileparts(paths.SlipRoot);
    paths.RoadmapCommonRoot = fullfile(paths.ExperimentsRoot, ...
        'roadmap_bifurcation_robustness');
    paths.DataRoot = fullfile(experimentRoot,'data');
    paths.ParentBranchRoot = fullfile(paths.DataRoot,'parent_branch');
    paths.DaughterBranchRoot = fullfile(paths.DataRoot, ...
        'held_out_daughter_branches');
    paths.ResultsRoot = fullfile(experimentRoot,'results');
    paths.FinalResultsRoot = fullfile(paths.ResultsRoot,'final');
    paths.IntermediateResultsRoot = fullfile(paths.ResultsRoot,'intermediate');
    paths.LogRoot = fullfile(experimentRoot,'logs');
    paths.TestRoot = fullfile(experimentRoot,'tests');
end
