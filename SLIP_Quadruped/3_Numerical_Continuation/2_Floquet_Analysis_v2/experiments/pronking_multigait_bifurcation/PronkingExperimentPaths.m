function paths = PronkingExperimentPaths()
%PRONKINGEXPERIMENTPATHS Resolve packaged experiment and shared-code paths.
%
%   This experiment-local helper is the single source of truth for package
%   inputs and outputs. Shared Floquet-v2 functions remain in FloquetRoot
%   and are deliberately not duplicated inside the experiment package.

    paths = struct();
    paths.ExperimentRoot = fileparts(mfilename('fullpath'));
    paths.ExperimentsRoot = fileparts(paths.ExperimentRoot);
    paths.FloquetRoot = fileparts(paths.ExperimentsRoot);
    paths.ContinuationRoot = fileparts(paths.FloquetRoot);
    paths.SlipRoot = fileparts(paths.ContinuationRoot);
    paths.RepositoryRoot = fileparts(paths.SlipRoot);
    paths.UtilitiesRoot = fullfile(paths.FloquetRoot,'utilities');
    paths.DynamicsRoot = fullfile(paths.SlipRoot,'1_Dynamic_Frameworks','v2');
    paths.ContinuationAlgorithmRoot = fullfile(paths.ContinuationRoot, ...
        '1_Continuation_Algorithm');
    paths.SolutionManagementRoot = fullfile(paths.SlipRoot, ...
        '4_Solution_Management');
    paths.PronkingBranchFile = fullfile(paths.ExperimentRoot, ...
        'data','pronking_branch','PK_20_2.mat');
    paths.DaughterBranchRoot = fullfile(paths.ExperimentRoot, ...
        'data','held_out_daughter_branches');
    paths.ResultsRoot = fullfile(paths.ExperimentRoot,'results','final');
    paths.IntermediateResultsRoot = fullfile(paths.ExperimentRoot, ...
        'results','intermediate');
    paths.LogRoot = fullfile(paths.ExperimentRoot,'logs');
    paths.TestRoot = fullfile(paths.ExperimentRoot,'tests');
end
