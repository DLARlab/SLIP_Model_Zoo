function V3AddPaths_v3(root)
%V3ADDPATHS_V3 Add the live dynamics, graphics, numerical and solution modules.
    if nargin == 0, root = V3Root_v3(); end
    root = char(root);
    % A previous genpath call must not activate historical research drivers.
    existing = strsplit(path, pathsep);
    researchRoot = fullfile(root, 'Research_v3');
    remove = existing(strcmp(existing,researchRoot) | startsWith(existing,[researchRoot,filesep]));
    if ~isempty(remove), rmpath(remove{:}); end
    addpath(root);
    groups = {'1_Dynamic_Frameworks', '2_Graphic_ToolBox', ...
        '3_Numerical_Continuation', '4_Solution_Management'};
    for k = 1:numel(groups), addpath(genpath(fullfile(root, groups{k}))); end
end
