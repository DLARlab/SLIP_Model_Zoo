function varargout = FloquetAnalysisGUI(varargin)
%FLOQUETANALYSISGUI Launch the SLIP Quadruped Floquet workbench.
%
%   FLOQUETANALYSISGUI() opens the empty workflow workbench. Use Select
%   Folder and Load Branch to start from any continuation branch, or Load
%   Workflow to resume a saved analysis. New Workflow asks where its
%   configuration, checkpoints, numerical results, plots, and logs should
%   be stored.
%
%   This repository-root entry point adds only the reusable Floquet-v2 code
%   needed by the workbench. The implementation remains beside the
%   numerical analysis code under SLIP_Quadruped.

    repositoryRoot = fileparts(mfilename('fullpath'));
    analysisRoot = fullfile(repositoryRoot, 'SLIP_Quadruped', ...
        '3_Numerical_Continuation', '2_Floquet_Analysis_v2');
    packageEntry = fullfile(analysisRoot, '+floquet', '+gui', 'launch.m');
    if ~isfile(packageEntry)
        error('FloquetAnalysisGUI:ImplementationMissing', ...
            'Floquet GUI package not found: %s', packageEntry);
    end
    addpath(analysisRoot, '-begin');
    if nargout > 0
        [varargout{1:nargout}] = floquet.gui.launch(varargin{:});
    else
        floquet.gui.launch(varargin{:});
    end
end
