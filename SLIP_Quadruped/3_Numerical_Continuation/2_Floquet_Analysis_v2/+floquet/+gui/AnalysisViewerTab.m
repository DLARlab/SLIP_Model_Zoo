function tab = AnalysisViewerTab(parentTabs)
%ANALYSISVIEWERTAB Create the read-only analysis-viewer tab shell.
%
% The workbench owns shared selection state and populates this tab. Keeping
% tab creation here makes the viewer an explicit GUI component while
% preserving one state owner and one numerical authority.

    if ~isgraphics(parentTabs, 'uitabgroup')
        error('floquet:gui:AnalysisViewerTab:InvalidParent', ...
            'parentTabs must be a live uitabgroup.');
    end
    tab = uitab(parentTabs, 'Title', 'Analysis Viewer', ...
        'Tag', 'FloquetVisualizationMainTab');
end
