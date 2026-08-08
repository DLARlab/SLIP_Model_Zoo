function report = main_Test_BGHalfBoundingBifurcation(userOptions)
%MAIN_TEST_BGHALFBOUNDINGBIFURCATION Reproduce BG->HG and BG->FG.

    if nargin < 1 || isempty(userOptions), userOptions = struct(); end
    paths = BGHalfBoundingExperimentPaths();
    addpath(paths.RoadmapCommonRoot);
    options = userOptions;
    options = SetPinned(options,'ExperimentRoot',paths.ExperimentRoot);
    options = SetPinned(options,'TransitionIDs',paths.TransitionIDs);
    options = SetDefault(options,'OutputDirectory',paths.FinalResultsRoot);
    options = SetDefault(options,'IntermediateDirectory', ...
        paths.IntermediateResultsRoot);
    options = SetDefault(options,'LogFile',fullfile(paths.LogRoot, ...
        'roadmap_robustness_full_experiment.log'));
    report = main_Test_RoadmapBifurcationRobustness(options);
end

function options = SetDefault(options,name,value)
    if ~any(strcmpi(fieldnames(options),name)), options.(name) = value; end
end

function options = SetPinned(options,name,value)
    names = fieldnames(options);
    hits = names(strcmpi(names,name));
    if ~isempty(hits), options = rmfield(options,hits); end
    options.(name) = value;
end
