function previous = V3LegacyAddPath_v3(varargin)
%V3LEGACYADDPATH_V3 Resolve historical module names to the live core modules.
    entries = varargin;
    root = V3Root_v3();
    for k = 1:numel(entries)
        entries{k} = V3Path_v3(entries{k});
        if isfolder(entries{k}) && ~strcmp(char(entries{k}), root)
            entries{k} = genpath(entries{k});
        end
    end
    previous = path;
    if any(cellfun(@(entry) strcmp(char(entry), root), entries))
        V3AddPaths_v3(root);
    end
    addpath(entries{:});
end
