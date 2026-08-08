function report = main_Refresh_FGGGReferenceArtifacts(userOptions)
%MAIN_REFRESH_FGGGREFERENCEARTIFACTS Refresh derived FG->GG outputs.

    if nargin < 1 || isempty(userOptions), userOptions = struct(); end
    paths = FGGGExperimentPaths();
    addpath(paths.RoadmapCommonRoot);
    options = userOptions;
    options = SetDefault(options,'ResultFile',fullfile( ...
        paths.FinalResultsRoot,'roadmap_bifurcation_robustness_results.mat'));
    options = SetDefault(options,'OutputDirectory',paths.FinalResultsRoot);
    options = SetDefault(options,'IntermediateDirectory', ...
        paths.IntermediateResultsRoot);
    report = main_Refresh_RoadmapReferenceArtifacts(options);
end

function options = SetDefault(options,name,value)
    if ~any(strcmpi(fieldnames(options),name)), options.(name) = value; end
end
