function transitions = RoadmapBifurcationCases(paths,transitionIDs)
%ROADMAPBIFURCATIONCASES Registry for six held-out roadmap transitions.
%
%   TRANSITIONS = ROADMAPBIFURCATIONCASES(PATHS,TRANSITIONIDS) returns the
%   explicitly requested transition specifications from the complete
%   registry:
%
%       BG -> HG, BG -> FG
%       BE -> FE, BE -> HE
%       FG -> GG
%       HE -> GE
%
%   TRANSITIONS = ROADMAPBIFURCATIONCASES(PATHS,TRANSITIONIDS) returns only
%   the requested transitions, in the requested order, and validates only
%   their packaged branch files. Parent branches are resolved only from
%   data/parent_branch and daughters only from
%   data/held_out_daughter_branches. Historical combined archives are not
%   runnable data sources and are never selected implicitly.
%
%   Scan windows are fixed before any held-out daughter branch is loaded.
%   Daughter indices and historical coordinates are validation metadata
%   only; AnalyzeRoadmapBifurcationCase does not expose them to Floquet
%   construction, multiplier tracking, critical refinement, or correction.

    if nargin < 1 || isempty(paths)
        error('RoadmapBifurcationCases:PathsRequired', ...
            ['Explicit experiment paths are required; the shared registry ' ...
             'does not select a data package implicitly.']);
    end
    if nargin < 2 || isempty(transitionIDs)
        error('RoadmapBifurcationCases:TransitionIDsRequired', ...
            ['Explicit transition IDs are required; the shared registry ' ...
             'does not infer package ownership from historical data.']);
    end

    rows = { ...
        'bg_to_hg','bg_halfbounds','BG','HG','HG','H','G','hind',37:41,1,2,4.50613886615; ...
        'bg_to_fg','bg_halfbounds','BG','FG','FG','F','G','front',64:68,212,211,5.64580041372; ...
        'be_to_fe','be_halfbounds','BE','FE','FE','F','E','front',25:29,228,227,4.83362543664; ...
        'be_to_he','be_halfbounds','BE','HE','HE','H','E','hind',57:61,180,179,6.04807885265; ...
        'fg_to_gg','fg_to_gg','FG','GG','GG','G','G','hind',143:147,1,2,5.91152210321; ...
        'he_to_ge','he_to_ge','HE','GE','GE','G','E','front',128:132,200,199,6.13594625369};

    transitions = repmat(EmptyTransition(),1,size(rows,1));
    for k = 1:size(rows,1)
        item = EmptyTransition();
        item.ID = rows{k,1};
        item.ParentExperiment = rows{k,2};
        item.ParentCode = rows{k,3};
        item.DaughterCode = rows{k,4};
        item.ExpectedGaitAbbreviation = rows{k,5};
        item.ExpectedGaitClass = rows{k,6};
        item.ExpectedSuspension = rows{k,7};
        item.ExpectedBrokenPair = rows{k,8};
        item.ScanIndices = rows{k,9};
        item.DaughterNearIndex = rows{k,10};
        item.DaughterOutgoingIndex = rows{k,11};
        item.HistoricalDaughterCoordinate = rows{k,12};
        item.ParentFile = BranchFile(paths,item.ParentCode,'parent');
        item.DaughterFile = BranchFile(paths,item.DaughterCode,'daughter');
        item.ParentDescription = GaitDescription(item.ParentCode);
        item.DaughterDescription = GaitDescription(item.DaughterCode);
        item.ExpectedCandidateType = '+1';
        item.ExpectedBifurcationType = 'plus-one';
        item.ExpectedOrientedBranches = 2;
        item.DaughterDataRole = 'held-out-validation-only';
        transitions(k) = item;
    end

    transitions = SelectTransitions(transitions,transitionIDs);
    ValidateRegistry(transitions);
end

function item = EmptyTransition()
    item = struct('ID','','ParentExperiment','','ParentCode','', ...
        'DaughterCode','','ParentFile','','DaughterFile','', ...
        'ParentDescription','','DaughterDescription','', ...
        'ExpectedGaitAbbreviation','','ExpectedGaitClass','', ...
        'ExpectedSuspension','','ExpectedBrokenPair','', ...
        'ExpectedCandidateType','+1', ...
        'ExpectedBifurcationType','plus-one', ...
        'ExpectedOrientedBranches',2,'ScanIndices',[], ...
        'DaughterNearIndex',NaN,'DaughterOutgoingIndex',NaN, ...
        'HistoricalDaughterCoordinate',NaN, ...
        'DaughterDataRole','held-out-validation-only');
end

function filename = BranchFile(paths,code,role)
    basename = sprintf('BD1_20_2_%s.mat',code);
    switch role
        case 'parent'
            roleRoot = RequiredPath(paths,'ParentBranchRoot');
        case 'daughter'
            roleRoot = RequiredPath(paths,'HeldOutDaughterBranchRoot');
        otherwise
            error('RoadmapBifurcationCases:BranchRole', ...
                'Unknown branch-data role %s.',role);
    end
    roleFilename = fullfile(roleRoot,basename);
    filename = roleFilename;
end

function value = RequiredPath(paths,name)
    if ~isstruct(paths) || ~isscalar(paths) || ~isfield(paths,name) || ...
            ~((ischar(paths.(name)) && isrow(paths.(name))) || ...
              (isstring(paths.(name)) && isscalar(paths.(name)) && ...
               ~ismissing(paths.(name))))
        error('RoadmapBifurcationCases:Paths', ...
            'paths.%s must be scalar text.',name);
    end
    value = char(string(paths.(name)));
end

function selected = SelectTransitions(allTransitions,transitionIDs)
    ids = NormalizeTransitionIDs(transitionIDs);
    normalized = lower(string(ids));
    if numel(unique(normalized)) ~= numel(normalized)
        error('RoadmapBifurcationCases:DuplicateTransition', ...
            'Transition IDs must be unique, ignoring letter case.');
    end

    available = {allTransitions.ID};
    selected = repmat(allTransitions(1),1,0);
    for k = 1:numel(ids)
        hit = find(strcmpi(ids{k},available),1);
        if isempty(hit)
            error('RoadmapBifurcationCases:UnknownTransition', ...
                'Unknown transition ID %s.',ids{k});
        end
        selected(end+1) = allTransitions(hit); %#ok<AGROW>
    end
end

function ids = NormalizeTransitionIDs(value)
    if ischar(value) || (isstring(value) && isscalar(value))
        value = cellstr(value);
    elseif isstring(value)
        value = cellstr(value(:));
    end
    if ~iscell(value) || ...
            ~all(cellfun(@(x)(ischar(x)&&isrow(x)) || ...
                (isstring(x)&&isscalar(x)&&~ismissing(x)),value))
        error('RoadmapBifurcationCases:TransitionIDs', ...
            'Transition IDs must be scalar text or a cell array of text.');
    end
    ids = cellfun(@(x)char(string(x)),value,'UniformOutput',false);
end

function value = GaitDescription(code)
    switch code
        case 'BG'
            value = 'Bounding with gathered suspension';
        case 'BE'
            value = 'Bounding with extended suspension';
        case 'FG'
            value = 'Front-spread half-bounding with gathered suspension';
        case 'FE'
            value = 'Front-spread half-bounding with extended suspension';
        case 'HG'
            value = 'Hind-spread half-bounding with gathered suspension';
        case 'HE'
            value = 'Hind-spread half-bounding with extended suspension';
        case 'GG'
            value = 'Galloping with gathered suspension';
        case 'GE'
            value = 'Galloping with extended suspension';
        otherwise
            error('RoadmapBifurcationCases:UnknownGaitCode', ...
                'Unknown gait code %s.',code);
    end
end

function ValidateRegistry(items)
    ids = lower(string({items.ID}));
    if numel(unique(ids)) ~= numel(ids)
        error('RoadmapBifurcationCases:DuplicateID', ...
            'Every transition ID must be unique.');
    end
    for k = 1:numel(items)
        item = items(k);
        if ~isfile(item.ParentFile) || ~isfile(item.DaughterFile)
            error('RoadmapBifurcationCases:MissingBranchData', ...
                'Missing packaged data for %s.',item.ID);
        end
        indices = item.ScanIndices(:).';
        if numel(indices) < 3 || any(diff(indices) ~= 1)
            error('RoadmapBifurcationCases:ScanWindow', ...
                '%s must use at least three consecutive parent columns.',item.ID);
        end
        daughterIndices = [item.DaughterNearIndex, ...
            item.DaughterOutgoingIndex];
        if ~isnumeric(daughterIndices) || ...
                any(~isfinite(daughterIndices)) || ...
                any(daughterIndices < 1) || ...
                any(daughterIndices ~= floor(daughterIndices))
            error('RoadmapBifurcationCases:DaughterIndex', ...
                ['%s daughter near/outgoing indices must be positive ' ...
                 'finite integers.'],item.ID);
        end
        if item.DaughterNearIndex == item.DaughterOutgoingIndex
            error('RoadmapBifurcationCases:DaughterSecant', ...
                '%s daughter near/outgoing indices must be distinct.',item.ID);
        end
        if ~strcmp(item.DaughterDataRole,'held-out-validation-only')
            error('RoadmapBifurcationCases:DaughterRole', ...
                'Daughter data must remain held out for %s.',item.ID);
        end
    end
end
