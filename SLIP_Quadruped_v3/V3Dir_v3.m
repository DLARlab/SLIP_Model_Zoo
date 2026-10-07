function entries = V3Dir_v3(pattern)
%V3DIR_V3 List current files, including historical wildcard locations.
% Saved-data readers can keep their frozen task glob while files live in the
% study audit folders. Returned folder/name fields always identify real files.
    if nargin == 0, entries = dir; return; end
    entries = dir(V3Path_v3(pattern));
    if ~(ischar(pattern) || (isstring(pattern) && isscalar(pattern))) || ...
            ~contains(char(pattern), '*'), return; end
    root = fileparts(mfilename('fullpath'));
    pattern = strrep(char(pattern), '\', '/');
    prefix = [strrep(root, '\', '/'), '/'];
    if startsWith(pattern, prefix), pattern = pattern(numel(prefix)+1:end);
    elseif startsWith(pattern, '/'), return; end
    map = jsondecode(fileread(fullfile(root, 'Audits_v3', 'Folder_Organization', 'locations.json')));
    expression = globExpression(pattern);
    existing = arrayfun(@(r) fullfile(r.folder, r.name), entries, 'UniformOutput', false);
    % Scan live mapped directories too: later continuation output is not part
    % of the immutable before-manifest, but must be visible to saved readers.
    cuts = strfind(pattern, '/');
    for k = 1:numel(map.directories)
        record = map.directories(k);
        for cut = cuts
            head = pattern(1:cut-1);
            if isempty(regexp(record.old_path, ['^', globExpression(head), '$'], 'once')), continue; end
            tail = pattern(cut+1:end);
            if endsWith(head, '**'), tail = ['**/', tail]; end
            live = dir(fullfile(root, record.new_path, tail));
            appendUnique(live);
        end
    end
    for k = 1:numel(map.files)
        record = map.files(k);
        if isempty(regexp(record.old_path, ['^', expression, '$'], 'once')), continue; end
        target = fullfile(root, record.new_path);
        if any(strcmp(existing, target)), continue; end
        item = dir(target);
        if isempty(item), continue; end
        appendUnique(item);
    end

    function appendUnique(items)
        for index = 1:numel(items)
            current = fullfile(items(index).folder, items(index).name);
            if any(strcmp(existing, current)), continue; end
            entries = [entries; items(index)]; %#ok<AGROW>
            existing{end+1} = current; %#ok<AGROW>
        end
    end
end

function expression = globExpression(pattern)
    token = '__V3_RECURSIVE_GLOB__';
    pattern = strrep(pattern, '**', token);
    expression = regexptranslate('wildcard', pattern);
    expression = strrep(expression, '.*', '[^/]*');
    expression = strrep(expression, token, '.*');
end
