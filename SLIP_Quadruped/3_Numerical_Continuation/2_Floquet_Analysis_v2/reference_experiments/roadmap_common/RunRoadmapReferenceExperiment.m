function result = RunRoadmapReferenceExperiment(definition,action,userOptions)
%RUNROADMAPREFERENCEEXPERIMENT Execute one declared roadmap experiment.
%
%   REPORT = RUNROADMAPREFERENCEEXPERIMENT(DEFINITION,'run') performs the
%   parent-only Floquet calculation and held-out daughter validation for all
%   transition IDs declared by DEFINITION.
%
%   REPLAY = RUNROADMAPREFERENCEEXPERIMENT(DEFINITION,'replay') rechecks the
%   saved result without recomputing its Floquet matrices.
%
%   REPORT = RUNROADMAPREFERENCEEXPERIMENT(DEFINITION,'refresh') rebuilds
%   derived reference artifacts from the saved authoritative report.
%
%   A third scalar-structure argument overrides action-specific options.
%   ExperimentRoot and (for 'run') TransitionIDs always come from the
%   definition. Logging is opt-in: 'run' and 'replay' default LogFile to ''.

    if nargin < 2
        error('RunRoadmapReferenceExperiment:Arguments', ...
            'A definition and one action (run, replay, or refresh) are required.');
    end
    if nargin < 3 || isempty(userOptions)
        userOptions = struct();
    end
    definition = ValidateDefinition(definition);
    action = ValidateAction(action);
    userOptions = ValidateOptions(userOptions);

    paths = RoadmapRobustnessPaths(definition.ExperimentRoot);
    switch action
        case 'run'
            options = SetPinned(userOptions,'ExperimentRoot', ...
                definition.ExperimentRoot);
            options = SetPinned(options,'TransitionIDs', ...
                definition.TransitionIDs);
            options = SetDefault(options,'OutputDirectory', ...
                paths.FinalResultsRoot);
            options = SetDefault(options,'IntermediateDirectory', ...
                paths.IntermediateResultsRoot);
            options = SetDefault(options,'LogFile','');
            result = main_Test_RoadmapBifurcationRobustness(options);

        case 'replay'
            options = SetPinned(userOptions,'ExperimentRoot', ...
                definition.ExperimentRoot);
            options = SetDefault(options,'ResultFile',fullfile( ...
                paths.FinalResultsRoot, ...
                'roadmap_bifurcation_robustness_results.mat'));
            options = SetDefault(options,'OutputCsv',fullfile( ...
                paths.FinalResultsRoot,'roadmap_hand_validation_replay.csv'));
            options = SetDefault(options,'LogFile','');
            result = main_HandValidate_RoadmapBifurcations(options);

        case 'refresh'
            options = SetPinned(userOptions,'ExperimentRoot', ...
                definition.ExperimentRoot);
            options = SetDefault(options,'ResultFile',fullfile( ...
                paths.FinalResultsRoot, ...
                'roadmap_bifurcation_robustness_results.mat'));
            options = SetDefault(options,'OutputDirectory', ...
                paths.FinalResultsRoot);
            options = SetDefault(options,'IntermediateDirectory', ...
                paths.IntermediateResultsRoot);
            result = main_Refresh_RoadmapReferenceArtifacts(options);
    end
end

function definition = ValidateDefinition(definition)
    if ~isstruct(definition) || ~isscalar(definition)
        error('RunRoadmapReferenceExperiment:Definition', ...
            'Definition must be one scalar structure.');
    end
    required = {'SchemaVersion','ID','Code','ExperimentRoot','TransitionIDs'};
    for k = 1:numel(required)
        if ~isfield(definition,required{k})
            error('RunRoadmapReferenceExperiment:Definition', ...
                'Definition lacks required field %s.',required{k});
        end
    end
    schema = ScalarText(definition.SchemaVersion,'SchemaVersion');
    if ~strcmp(schema,'floquet-roadmap-reference-definition-v1')
        error('RunRoadmapReferenceExperiment:DefinitionSchema', ...
            'Unsupported definition schema %s.',schema);
    end
    definition.SchemaVersion = schema;
    definition.ID = ScalarText(definition.ID,'ID');
    definition.Code = ScalarText(definition.Code,'Code');
    definition.ExperimentRoot = ScalarText( ...
        definition.ExperimentRoot,'ExperimentRoot');
    if ~isfolder(definition.ExperimentRoot)
        error('RunRoadmapReferenceExperiment:ExperimentRoot', ...
            'Experiment root does not exist: %s',definition.ExperimentRoot);
    end

    ids = definition.TransitionIDs;
    if ischar(ids) || (isstring(ids) && isscalar(ids))
        ids = cellstr(ids);
    elseif isstring(ids)
        ids = cellstr(ids(:));
    end
    if ~iscell(ids) || isempty(ids) || ...
            ~all(cellfun(@IsScalarText,ids))
        error('RunRoadmapReferenceExperiment:TransitionIDs', ...
            'TransitionIDs must be a nonempty cell array of scalar text IDs.');
    end
    ids = cellfun(@(value)ScalarText(value,'TransitionIDs'),ids, ...
        'UniformOutput',false);
    if numel(unique(lower(string(ids)))) ~= numel(ids)
        error('RunRoadmapReferenceExperiment:TransitionIDs', ...
            'TransitionIDs must be unique, ignoring letter case.');
    end
    definition.TransitionIDs = reshape(ids,1,[]);
end

function action = ValidateAction(action)
    action = lower(ScalarText(action,'action'));
    allowed = {'run','replay','refresh'};
    if ~any(strcmp(action,allowed))
        error('RunRoadmapReferenceExperiment:Action', ...
            'Action must be run, replay, or refresh.');
    end
end

function options = ValidateOptions(options)
    if ~isstruct(options) || ~isscalar(options)
        error('RunRoadmapReferenceExperiment:Options', ...
            'Options must be one scalar structure.');
    end
end

function options = SetDefault(options,name,value)
    names = fieldnames(options);
    hits = find(strcmpi(names,name));
    if numel(hits) > 1
        error('RunRoadmapReferenceExperiment:DuplicateOption', ...
            'Option %s is present more than once, ignoring case.',name);
    end
    if isempty(hits)
        options.(name) = value;
    end
end

function options = SetPinned(options,name,value)
    names = fieldnames(options);
    hits = names(strcmpi(names,name));
    if ~isempty(hits)
        options = rmfield(options,hits);
    end
    options.(name) = value;
end

function value = ScalarText(value,label)
    if ~IsScalarText(value)
        error('RunRoadmapReferenceExperiment:Text', ...
            '%s must be nonempty scalar text.',label);
    end
    value = char(string(value));
    if isempty(strtrim(value))
        error('RunRoadmapReferenceExperiment:Text', ...
            '%s must be nonempty scalar text.',label);
    end
end

function tf = IsScalarText(value)
    tf = (ischar(value) && isrow(value)) || ...
        (isstring(value) && isscalar(value) && ~ismissing(value));
end
