function varargout = trackDisplayMultipliers(varargin)
%TRACKDISPLAYMULTIPLIERS Track eigenpairs for stable GUI ordering/colors.
%
%   [LAMBDA,V,INFO] = floquet.io.trackDisplayMultipliers(LAMBDA0,V0,OPTS)
%   provides visualization continuity only. It is not the scientific
%   TrackMultipliers result used for bifurcation detection.

    if nargout == 0
        floquet.io.internal.TrackFloquetMultipliers(varargin{:});
    else
        [varargout{1:nargout}] = ...
            floquet.io.internal.TrackFloquetMultipliers(varargin{:});
    end
end
