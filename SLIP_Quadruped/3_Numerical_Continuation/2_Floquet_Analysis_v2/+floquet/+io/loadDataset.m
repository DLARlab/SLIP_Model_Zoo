function varargout = loadDataset(varargin)
%LOADDATASET Load and validate a saved Floquet dataset or analysis view.
%
%   DATA = floquet.io.loadDataset(SOURCE) accepts a FloquetData structure,
%   a canonical analysis structure, or a MAT file containing either one.
%   Loading never evaluates the Poincare map or recomputes FDM data.

    if nargout == 0
        floquet.io.internal.LoadFloquetDataset(varargin{:});
    else
        [varargout{1:nargout}] = ...
            floquet.io.internal.LoadFloquetDataset(varargin{:});
    end
end
