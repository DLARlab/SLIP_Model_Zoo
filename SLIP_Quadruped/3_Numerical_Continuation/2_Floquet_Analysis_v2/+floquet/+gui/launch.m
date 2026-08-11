function varargout = launch(varargin)
%LAUNCH Open the Floquet analysis workbench.
%
%   floquet.gui.launch() opens a new workflow/viewer workbench.
%   floquet.gui.launch(SOURCE,...) preserves every input and output accepted
%   by FloquetAnalysisGUI. This function does not create a second GUI
%   implementation or numerical authority.

    ensureGUIPath();
    if nargout == 0
        floquet.gui.Workbench(varargin{:});
    else
        [varargout{1:nargout}] = ...
            floquet.gui.Workbench(varargin{:});
    end
end

function ensureGUIPath()
    guiPackage = fileparts(mfilename('fullpath'));
    floquetPackage = fileparts(guiPackage);
    root = fileparts(floquetPackage);
    required = {root};
    currentPath = [path pathsep];
    for k = 1:numel(required)
        entry = [required{k} pathsep];
        if ~contains(currentPath, entry)
            addpath(required{k}, '-begin');
            currentPath = [path pathsep];
        end
    end
end
