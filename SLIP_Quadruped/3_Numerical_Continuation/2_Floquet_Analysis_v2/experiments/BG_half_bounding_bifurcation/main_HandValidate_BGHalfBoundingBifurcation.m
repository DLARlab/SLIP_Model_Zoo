function replay = main_HandValidate_BGHalfBoundingBifurcation(userOptions)
%MAIN_HANDVALIDATE_BGHALFBOUNDINGBIFURCATION Replay the local BG result.

    if nargin < 1 || isempty(userOptions), userOptions = struct(); end
    paths = BGHalfBoundingExperimentPaths();
    addpath(paths.RoadmapCommonRoot);
    options = userOptions;
    options = SetDefault(options,'ResultFile',fullfile( ...
        paths.FinalResultsRoot,'roadmap_bifurcation_robustness_results.mat'));
    options = SetDefault(options,'OutputCsv',fullfile( ...
        paths.FinalResultsRoot,'roadmap_hand_validation_replay.csv'));
    options = SetDefault(options,'LogFile',fullfile(paths.LogRoot, ...
        'roadmap_robustness_hand_validation.log'));
    replay = main_HandValidate_RoadmapBifurcations(options);
end

function options = SetDefault(options,name,value)
    if ~any(strcmpi(fieldnames(options),name)), options.(name) = value; end
end
