function paths = RoadmapRobustnessPaths(experimentRoot)
%ROADMAPROBUSTNESSPATHS Resolve the self-contained robustness experiment.
%
%   PATHS = ROADMAPROBUSTNESSPATHS() resolves the canonical combined
%   roadmap experiment.
%
%   PATHS = ROADMAPROBUSTNESSPATHS(EXPERIMENTROOT) keeps reusable MATLAB
%   implementation and dynamics paths anchored at the canonical roadmap
%   package, while routing experiment-owned data, results, logs, and tests
%   beneath EXPERIMENTROOT. This supports independent, reproducible sibling
%   experiment packages without duplicating numerical-analysis functions.
%
%   The experiment owns only configuration, copied input data, tests, logs,
%   and generated artifacts.  The reduced Floquet map, critical-orbit
%   refiner, predictor, corrector, and dynamics remain shared code.

    sharedImplementationRoot = fileparts(mfilename('fullpath'));
    if nargin < 1 || isempty(experimentRoot)
        experimentRoot = sharedImplementationRoot;
    end
    experimentRoot = ValidateExperimentRoot(experimentRoot);

    paths = struct();
    paths.SharedImplementationRoot = sharedImplementationRoot;
    paths.ExperimentRoot = experimentRoot;
    paths.ExperimentsRoot = fileparts(sharedImplementationRoot);
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

    paths.DataRoot = fullfile(paths.ExperimentRoot,'data');
    paths.ParentBranchRoot = fullfile(paths.DataRoot,'parent_branch');
    paths.HeldOutDaughterBranchRoot = fullfile(paths.DataRoot, ...
        'held_out_daughter_branches');
    paths.BranchLibraryRoot = fullfile(paths.DataRoot,'branch_library');
    paths.ResultsRoot = fullfile(paths.ExperimentRoot,'results');
    paths.FinalResultsRoot = fullfile(paths.ResultsRoot,'final');
    paths.IntermediateResultsRoot = fullfile(paths.ResultsRoot,'intermediate');
    paths.CaseResultsRoot = fullfile(paths.FinalResultsRoot,'cases');
    paths.LogRoot = fullfile(paths.ExperimentRoot,'logs');
    paths.TestRoot = fullfile(paths.ExperimentRoot,'tests');
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
