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
    paths.DynamicsRoot = fullfile(paths.SlipRoot,'1_Dynamic_Frameworks','v2');
    paths.ContinuationAlgorithmRoot = fullfile(paths.ContinuationRoot, ...
        '1_Continuation_Algorithm');
    paths.SolutionManagementRoot = fullfile(paths.SlipRoot, ...
        '4_Solution_Management');
    paths.PronkingBranchFile = fullfile(paths.ExperimentRoot, ...
        'data','parent_branch','PK_20_2.mat');
    paths.DaughterBranchRoot = fullfile(paths.ExperimentRoot, ...
        'data','held_out_daughter_branches');
    paths.ArtifactsRoot = fullfile(paths.ExperimentRoot,'artifacts');
    paths.DiscoveryRoot = fullfile(paths.ArtifactsRoot,'01_discovery');
    paths.RefinementRoot = fullfile(paths.ArtifactsRoot,'02_refinement');
    paths.SeedSearchRoot = fullfile(paths.ArtifactsRoot,'03_seed_search');
    paths.DaughterBranchesRoot = fullfile(paths.ArtifactsRoot, ...
        '04_daughter_branches');
    paths.ValidationRoot = fullfile(paths.ArtifactsRoot,'05_validation');
    paths.CheckpointsRoot = fullfile(paths.ExperimentRoot,'checkpoints');
    paths.ViewsRoot = fullfile(paths.ExperimentRoot,'views');
    paths.ResultsRoot = paths.ValidationRoot;
    paths.IntermediateResultsRoot = paths.SeedSearchRoot;
    paths.ReferenceConfigFile = fullfile(paths.ExperimentRoot, ...
        'reference_experiment_config.mat');
    paths.LogRoot = fullfile(paths.ExperimentRoot,'logs');
    paths.TestRoot = fullfile(paths.FloquetRoot,'tests','production');
end
