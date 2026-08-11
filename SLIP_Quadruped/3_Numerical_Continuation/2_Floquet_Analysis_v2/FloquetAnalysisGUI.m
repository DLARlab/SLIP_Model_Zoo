function varargout = FloquetAnalysisGUI(varargin)
%FLOQUETANALYSISGUI Public one-line launcher for the Floquet workbench.
%
%   FLOQUETANALYSISGUI() opens an empty Analyze Workflow tab. Existing
%   source and option arguments remain supported. Numerical work is owned
%   by the qualified floquet.* package; this file is only the convenient
%   repository-level GUI entry point.

    if nargout > 0
        [varargout{1:nargout}] = floquet.gui.launch(varargin{:});
    else
        floquet.gui.launch(varargin{:});
    end
end
