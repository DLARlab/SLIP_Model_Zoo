function V3AddPaths_v3(root)
%V3ADDPATHS_V3 Add functional v3 modules and native research drivers.
    if nargin == 0, root = V3Root_v3(); end
    addpath(root);
    groups = {'1_Dynamic_Frameworks', '2_Graphic_ToolBox', ...
        '3_Numerical_Continuation', '4_Solution_Management'};
    for k = 1:numel(groups), addpath(genpath(fullfile(root, groups{k}))); end
    addpath(fullfile(root, 'Research_v3', 'Drivers_v3'));
    addpath(fullfile(root, 'Research_v3', 'next_round', 'solver'));
    addpath(fullfile(root, 'Research_v3', 'next_round', 'theory'));
end
