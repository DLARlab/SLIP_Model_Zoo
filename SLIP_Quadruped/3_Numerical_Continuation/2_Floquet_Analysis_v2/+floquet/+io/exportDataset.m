function varargout = exportDataset(varargin)
%EXPORTDATASET Export a canonical branch analysis as a GUI dataset view.
%
%   DATA = floquet.io.exportDataset(ANALYSIS) copies canonical matrices,
%   multipliers, event times, acceptance, and candidates into the derived
%   FloquetData schema. It does not recompute the Floquet map.

    if nargout == 0
        floquet.io.internal.BuildFloquetDatasetFromAnalysis(varargin{:});
    else
        [varargout{1:nargout}] = ...
            floquet.io.internal.BuildFloquetDatasetFromAnalysis( ...
                varargin{:});
    end
end
