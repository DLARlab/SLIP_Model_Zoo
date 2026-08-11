function paths = RoadmapRobustnessPaths(experimentRoot)
%ROADMAPROBUSTNESSPATHS Resolve shared code and experiment-owned artifacts.
%
%   PATHS = ROADMAPROBUSTNESSPATHS(EXPERIMENTROOT) keeps reusable MATLAB
%   implementation and dynamics paths anchored at this shared engine, while
%   routing experiment-owned data, numbered artifacts, logs, and tests
%   beneath EXPERIMENTROOT. This supports independent, reproducible sibling
%   experiment packages without duplicating numerical-analysis functions.
%
%   The experiment owns only configuration, copied input data, tests, logs,
%   and generated artifacts.  The reduced Floquet map, critical-orbit
%   refiner, predictor, corrector, and dynamics remain shared code.

    sharedImplementationRoot = fileparts(mfilename('fullpath'));
    referenceExperimentsRoot = fileparts(sharedImplementationRoot);
    if nargin < 1 || isempty(experimentRoot)
        error('RoadmapRobustnessPaths:ExperimentRootRequired', ...
            ['An explicit experimentRoot is required. Shared code does not ' ...
             'select an experiment package or historical archive implicitly.']);
    end
    experimentRoot = ValidateExperimentRoot(experimentRoot);

    paths = struct();
    paths.SharedImplementationRoot = sharedImplementationRoot;
    paths.ExperimentRoot = experimentRoot;
    paths.ReferenceExperimentsRoot = referenceExperimentsRoot;
    paths.SharedExperimentsRoot = referenceExperimentsRoot;
    paths.ExperimentsRoot = referenceExperimentsRoot;
    paths.FloquetRoot = fileparts(paths.ReferenceExperimentsRoot);
    paths.ContinuationRoot = fileparts(paths.FloquetRoot);
    paths.SlipRoot = fileparts(paths.ContinuationRoot);
    paths.RepositoryRoot = fileparts(paths.SlipRoot);

    paths.DynamicsRoot = fullfile(paths.SlipRoot,'1_Dynamic_Frameworks','v2');
    paths.ContinuationAlgorithmRoot = fullfile(paths.ContinuationRoot, ...
        '1_Continuation_Algorithm');
    paths.SolutionManagementRoot = fullfile(paths.SlipRoot, ...
        '4_Solution_Management');

    paths.DataRoot = fullfile(paths.ExperimentRoot,'data');
    paths.ParentBranchRoot = fullfile(paths.DataRoot,'parent_branch');
    paths.HeldOutDaughterBranchRoot = fullfile(paths.DataRoot, ...
        'held_out_daughter_branches');
    paths.ArtifactsRoot = fullfile(paths.ExperimentRoot,'artifacts');
    paths.DiscoveryRoot = fullfile(paths.ArtifactsRoot,'01_discovery');
    paths.RefinementRoot = fullfile(paths.ArtifactsRoot,'02_refinement');
    paths.SeedSearchRoot = fullfile(paths.ArtifactsRoot,'03_seed_search');
    paths.DaughterBranchesRoot = fullfile(paths.ArtifactsRoot, ...
        '04_daughter_branches');
    paths.ValidationRoot = fullfile(paths.ArtifactsRoot,'05_validation');
    paths.CheckpointsRoot = fullfile(paths.ExperimentRoot,'checkpoints');
    paths.ViewsRoot = fullfile(paths.ExperimentRoot,'views');
    paths.ResultsRoot = paths.ArtifactsRoot;
    paths.FinalResultsRoot = paths.ValidationRoot;
    paths.IntermediateResultsRoot = paths.SeedSearchRoot;
    paths.CaseResultsRoot = paths.DaughterBranchesRoot;
    paths.ReferenceConfigFile = fullfile(paths.ExperimentRoot, ...
        'reference_experiment_config.mat');
    paths.LogRoot = fullfile(paths.ExperimentRoot,'logs');
    paths.TestRoot = fullfile(paths.FloquetRoot,'tests','production');
end

function value = ValidateExperimentRoot(value)
    if ~(ischar(value) && isrow(value)) && ...
            ~(isstring(value) && isscalar(value) && ~ismissing(value))
        error('RoadmapRobustnessPaths:ExperimentRoot', ...
            'ExperimentRoot must be nonempty scalar text.');
    end
    value = char(string(value));
    if isempty(strtrim(value))
        error('RoadmapRobustnessPaths:ExperimentRoot', ...
            'ExperimentRoot must be nonempty scalar text.');
    end
end
