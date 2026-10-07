function output = V3Path_v3(input)
%V3PATH_V3 Resolve recorded v3 locations without rewriting scientific records.
% Paths outside this checkout and unrecognized MATLAB path names are unchanged.
% The immutable location map also routes new output at a historical location
% into its current directory. Numeric file/graphics handles pass through.
    output = input;
    if iscell(input)
        output = cellfun(@V3Path_v3, input, 'UniformOutput', false); return;
    end
    if isstring(input) && ~isscalar(input)
        output = arrayfun(@V3Path_v3, input); return;
    end
    if ~(ischar(input) || (isstring(input) && isscalar(input))) || isempty(input)
        return;
    end
    root = fileparts(mfilename('fullpath'));
    persistent storedRoot locations
    if isempty(locations) || ~strcmp(storedRoot, root)
        mapFile = fullfile(root, 'Audits_v3', 'Folder_Organization', 'locations.json');
        if ~isfile(mapFile), return; end
        locations = jsondecode(fileread(mapFile)); storedRoot = root;
    end
    supplied = strrep(char(input), '\', '/');
    prefix = [strrep(root, '\', '/'), '/'];
    absolute = startsWith(supplied, '/');
    if absolute
        if ~startsWith(supplied, prefix), return; end
        relative = supplied(numel(prefix)+1:end);
    else
        relative = supplied;
    end
    target = relative;
    found = false;
    for k = 1:numel(locations.files)
        record = locations.files(k);
        if strcmp(relative, record.old_path) || ...
                (isfield(record, 'aliases') && any(strcmp(relative, record.aliases)))
            target = record.new_path; found = true; break;
        end
    end
    if ~found
        % Directory entries are ordered longest first; specific tasks win.
        for k = 1:numel(locations.directories)
            record = locations.directories(k);
            if strcmp(relative, record.old_path) || startsWith(relative, [record.old_path, '/'])
                target = [record.new_path, relative(numel(record.old_path)+1:end)];
                found = true; break;
            end
        end
    end
    if absolute || found, output = fullfile(root, target); end
    if isstring(input), output = string(output); end
end
