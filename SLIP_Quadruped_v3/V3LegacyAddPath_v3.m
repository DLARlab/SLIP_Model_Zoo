function previous = V3LegacyAddPath_v3(varargin)
%V3LEGACYADDPATH_V3 Resolve historical module paths for saved research drivers.
% The numerical group now has three subdirectories; include their functions.
    entries = varargin;
    for k = 1:numel(entries)
        entries{k} = V3Path_v3(entries{k});
        if isfolder(entries{k}), entries{k} = genpath(entries{k}); end
    end
    previous = addpath(entries{:});
end
