function root = V3Root_v3(startPath)
%V3ROOT_V3 Find this checkout's v3 root after module relocation.
    if nargin == 0, startPath = mfilename('fullpath'); end
    root = char(startPath);
    if ~isfolder(root), root = fileparts(root); end
    while ~isempty(root)
        if isfile(fullfile(root, 'RunResearchRound_v3.m')) && ...
                isfile(fullfile(root, 'README_v3.md'))
            return;
        end
        parent = fileparts(root);
        if strcmp(parent, root), break; end
        root = parent;
    end
    error('V3Root_v3:MissingRoot', 'Could not locate the SLIP_Quadruped_v3 root.');
end
