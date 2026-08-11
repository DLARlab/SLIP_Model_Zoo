classdef Session < handle
%SESSION Graphics-free controller for one five-stage workflow.
%
% The controller is intentionally thin: canonical package-owned stage
% functions do all numerical work, while the package-owned state inspector
% reconstructs GUI state from validated files. No numerical result is held
% only in memory.

    properties (SetAccess = private)
        Config = struct()
        ConfigSource = struct()
        State = struct()
        IsBusy = false
        ActiveStage = 0
        LastRun = struct()
        LastNotificationError = struct()
    end

    properties (Access = private)
        StageFunctions = {}
        RunnerIdentities = struct([])
        UsesTestHooks = false
    end

    methods
        function obj = Session(varargin)
            hooks = ParseConstructorInputs(varargin{:});
            [canonicalFunctions, identities] = CanonicalStageFunctions();
            if isempty(hooks)
                obj.StageFunctions = canonicalFunctions;
                obj.RunnerIdentities = identities;
            else
                obj.StageFunctions = ValidateTestHooks(hooks);
                obj.RunnerIdentities = FunctionIdentities( ...
                    obj.StageFunctions, true);
                obj.UsesTestHooks = true;
            end
            obj.LastRun = EmptyLastRun();
            obj.LastNotificationError = EmptyNotificationError();
        end

        function state = LoadConfig(obj, input)
            obj.RequireNotBusy('load a configuration');
            [config, source] = ...
                floquet.workflow.internal.LoadFloquetWorkflowConfig(input);
            obj.RequireTestHookPermission(config);
            nextState = ...
                floquet.workflow.internal.InspectFloquetWorkflowState(config);
            obj.Config = config;
            obj.ConfigSource = source;
            obj.State = nextState;
            obj.LastRun = EmptyLastRun();
            obj.LastNotificationError = EmptyNotificationError();
            state = obj.GetState();
        end

        function state = Reset(obj)
            %RESET Detach the GUI session without deleting any artifacts.
            obj.RequireNotBusy('start a new parent workflow');
            obj.Config = struct();
            obj.ConfigSource = struct();
            obj.State = struct();
            obj.ActiveStage = 0;
            obj.LastRun = EmptyLastRun();
            obj.LastNotificationError = EmptyNotificationError();
            state = obj.GetState();
        end

        function state = Refresh(obj)
            obj.RequireNotBusy('refresh workflow state');
            obj.RequireLoaded();
            obj.State = ...
                floquet.workflow.internal.InspectFloquetWorkflowState( ...
                obj.Config);
            state = obj.GetState();
        end

        function state = GetState(obj)
            if isempty(fieldnames(obj.State))
                state = struct('Loaded', false, 'IsBusy', obj.IsBusy, ...
                    'ActiveStage', obj.ActiveStage, ...
                    'LastRun', obj.LastRun, ...
                    'LastNotificationError', obj.LastNotificationError, ...
                    'RunnerIdentities', obj.RunnerIdentities);
                return
            end
            state = obj.State;
            state.Loaded = true;
            state.Config = obj.Config;
            state.ConfigSource = obj.ConfigSource;
            state.IsBusy = obj.IsBusy;
            state.ActiveStage = obj.ActiveStage;
            state.LastRun = obj.LastRun;
            state.LastNotificationError = obj.LastNotificationError;
            state.RunnerIdentities = obj.RunnerIdentities;
        end

        function state = ConfirmCandidates(obj, candidateIDs)
            obj.RequireNotBusy('confirm candidates');
            obj.RequireLoaded();
            current = obj.GetState();
            if ~current.Stages(1).Valid
                error('FloquetWorkflow:DiscoveryRequired', ...
                    'A valid Stage-1 discovery artifact is required.');
            end
            if current.Stages(2).ArtifactExists
                error('FloquetWorkflow:CandidateSelectionFrozen', [ ...
                    'Candidate selection is frozen once a Stage-2 artifact ' ...
                    'exists. Start an intentional new artifact set to revise it.']);
            end
            candidateIDs = NormalizeCandidateIDs(candidateIDs);
            available = unique(cellstr( ...
                current.CandidateTable.CandidateID), 'stable');
            available(cellfun(@isempty, available)) = [];
            unknown = setdiff(candidateIDs, available, 'stable');
            if ~isempty(unknown)
                error('FloquetWorkflow:UnknownCandidateID', ...
                    'Unknown Stage-1 candidate ID(s): %s.', ...
                    strjoin(unknown, ', '));
            end
            nextConfig = obj.Config;
            nextConfig.Selection.CandidateIDs = candidateIDs;
            nextConfig.Selection.Confirmed = true;
            nextState = ...
                floquet.workflow.internal.InspectFloquetWorkflowState( ...
                nextConfig);
            obj.Config = nextConfig;
            obj.State = nextState;
            state = obj.GetState();
        end

        function state = SetContinuationSelections(obj, selections)
            obj.RequireNotBusy('confirm continuation rays');
            obj.RequireLoaded();
            current = obj.GetState();
            if ~current.Stages(3).Valid
                error('FloquetWorkflow:SeedSearchRequired', ...
                    'A valid Stage-3 seed-search artifact is required.');
            end
            if current.Stages(4).ArtifactExists
                error('FloquetWorkflow:ContinuationSelectionFrozen', [ ...
                    'Continuation ray selection is frozen once a Stage-4 ' ...
                    'artifact exists. Start a new artifact set to revise it.']);
            end
            normalized = ...
                floquet.workflow.internal.NormalizeFloquetRaySelections( ...
                selections, ...
                current.Reports.Seeds, current.Stages(3).SHA256);
            nextConfig = obj.Config;
            nextConfig.Continuation.Enabled = true;
            nextConfig.Continuation.Confirmed = true;
            nextConfig.Continuation.RaySelections = normalized;
            nextConfig.Continuation.SourceSeedSHA256 = ...
                current.Stages(3).SHA256;
            nextState = ...
                floquet.workflow.internal.InspectFloquetWorkflowState( ...
                nextConfig);
            obj.Config = nextConfig;
            obj.State = nextState;
            state = obj.GetState();
        end

        function [result, state] = RunStage(obj, stage, statusFcn)
            if nargin < 3
                statusFcn = [];
            end
            if ~(isempty(statusFcn) || isa(statusFcn, 'function_handle'))
                error('FloquetWorkflow:StatusFunction', ...
                    'RunStage statusFcn must be empty or a function handle.');
            end
            obj.RequireNotBusy('run a workflow stage');
            obj.RequireLoaded();
            floquet.workflow.internal.RequireWritableFloquetWorkflowConfig( ...
                obj.Config);
            stageNumber = ResolveStage(stage);
            current = obj.GetState();
            if ~current.Stages(stageNumber).CanRun
                error('FloquetWorkflow:StageNotReady', ...
                    'Stage %d (%s) is locked: %s', stageNumber, ...
                    current.Stages(stageNumber).Name, ...
                    current.Stages(stageNumber).Message);
            end

            runConfig = obj.Config;
            if stageNumber <= 4
                floquet.workflow.internal.EnforceFloquetInformationBarrier( ...
                    runConfig, ...
                    current.Stages(stageNumber).Name);
            end
            if stageNumber == 1 && ~isempty(statusFcn)
                priorStatusFcn = [];
                if isfield(runConfig.AnalysisOptions, 'StatusFcn')
                    priorStatusFcn = runConfig.AnalysisOptions.StatusFcn;
                end
                runConfig.AnalysisOptions.StatusFcn = @(detail) ...
                    obj.ForwardAnalysisStatus( ...
                        detail, priorStatusFcn, statusFcn);
            elseif stageNumber == 4 && ~isempty(statusFcn)
                priorStatusFcn = [];
                if isfield(runConfig.Continuation, 'StatusFcn')
                    priorStatusFcn = runConfig.Continuation.StatusFcn;
                end
                runConfig.Continuation.StatusFcn = @(detail) ...
                    obj.ForwardStageStatus( ...
                        4, detail, priorStatusFcn, statusFcn);
            end

            obj.IsBusy = true;
            obj.ActiveStage = stageNumber;
            obj.LastRun = RunningRecord(stageNumber, ...
                current.Stages(stageNumber));
            cleanup = onCleanup(@() obj.ReleaseBusy());
            obj.Notify(statusFcn, stageNumber, 'started', ...
                sprintf('Started Stage %d: %s.', stageNumber, ...
                    current.Stages(stageNumber).Name), struct());
            try
                result = obj.StageFunctions{stageNumber}(runConfig);
            catch exception
                obj.LastRun.Status = 'failed';
                obj.LastRun.CompletedAt = Timestamp();
                obj.LastRun.ErrorIdentifier = exception.identifier;
                obj.LastRun.Message = exception.message;
                obj.RefreshAfterRun();
                obj.Notify(statusFcn, stageNumber, 'failed', ...
                    exception.message, struct('Exception', exception));
                obj.ReleaseBusy();
                delete(cleanup);
                rethrow(exception);
            end
            [completionStatus, completionPhase, completionMessage] = ...
                StageResultDisposition(stageNumber, result);
            obj.LastRun.Status = completionStatus;
            obj.LastRun.CompletedAt = Timestamp();
            obj.LastRun.Message = completionMessage;
            obj.LastRun.ResultClass = class(result);
            obj.RefreshAfterRun();
            obj.Notify(statusFcn, stageNumber, completionPhase, ...
                obj.LastRun.Message, struct());
            obj.ReleaseBusy();
            delete(cleanup);
            state = obj.GetState();
        end
    end

    methods (Access = private)
        function RequireLoaded(obj)
            if isempty(fieldnames(obj.Config))
                error('FloquetWorkflow:ConfigNotLoaded', ...
                    'Load a workflow configuration first.');
            end
        end

        function RequireNotBusy(obj, action)
            if obj.IsBusy
                error('FloquetWorkflow:Busy', ...
                    'Cannot %s while Stage %d is running.', ...
                    action, obj.ActiveStage);
            end
        end

        function RequireTestHookPermission(obj, config)
            if ~obj.UsesTestHooks
                return
            end
            allowed = isfield(config, 'Testing') && ...
                isstruct(config.Testing) && isscalar(config.Testing) && ...
                isfield(config.Testing, ...
                    'AllowWorkflowControllerInjection') && ...
                islogical(config.Testing.AllowWorkflowControllerInjection) && ...
                isscalar(config.Testing.AllowWorkflowControllerInjection) && ...
                config.Testing.AllowWorkflowControllerInjection;
            if ~allowed
                error('FloquetWorkflow:TestInjectionNotAuthorized', [ ...
                    'Injected workflow runners require explicit logical ' ...
                    'config.Testing.AllowWorkflowControllerInjection=true.']);
            end
        end

        function ReleaseBusy(obj)
            obj.IsBusy = false;
            obj.ActiveStage = 0;
        end

        function RefreshAfterRun(obj)
            try
                obj.State = ...
                    floquet.workflow.internal.InspectFloquetWorkflowState( ...
                    obj.Config);
            catch exception
                obj.LastRun.StateRefreshErrorIdentifier = ...
                    exception.identifier;
                obj.LastRun.StateRefreshMessage = exception.message;
            end
        end

        function ForwardAnalysisStatus(obj, detail, priorFcn, guiFcn)
            obj.ForwardStageStatus(1, detail, priorFcn, guiFcn);
        end

        function ForwardStageStatus(obj, stageNumber, detail, priorFcn, guiFcn)
            if ~isempty(priorFcn)
                priorFcn(detail);
            end
            message = sprintf('Stage-%d progress updated.', stageNumber);
            if isstruct(detail) && isscalar(detail) && ...
                    isfield(detail, 'message') && ...
                    (ischar(detail.message) || ...
                     (isstring(detail.message) && isscalar(detail.message)))
                message = char(string(detail.message));
            end
            obj.Notify(guiFcn, stageNumber, 'progress', message, detail);
        end

        function Notify(obj, callback, stageNumber, phase, message, detail)
            if isempty(callback)
                return
            end
            event = struct('StageNumber', stageNumber, ...
                'StageID', StageID(stageNumber), 'Phase', phase, ...
                'Message', message, 'Timestamp', Timestamp(), ...
                'Detail', detail);
            try
                callback(event);
            catch exception
                obj.LastNotificationError = struct( ...
                    'Occurred', true, 'Identifier', exception.identifier, ...
                    'Message', exception.message, 'Timestamp', Timestamp());
            end
        end
    end
end

function hooks = ParseConstructorInputs(varargin)
    hooks = [];
    if isempty(varargin)
        return
    end
    firstIsText = numel(varargin) >= 1 && ...
        (ischar(varargin{1}) || ...
         (isstring(varargin{1}) && isscalar(varargin{1})));
    if numel(varargin) ~= 2 || ~firstIsText || ...
            ~strcmpi(char(string(varargin{1})), 'TestHooks')
        error('FloquetWorkflow:Constructor', ...
            ['Use floquet.workflow.Session() or ' ...
             'floquet.workflow.Session(''TestHooks'', hooks).']);
    end
    hooks = varargin{2};
    if ~isstruct(hooks) || ~isscalar(hooks)
        error('FloquetWorkflow:TestHookContract', ...
            'TestHooks must be one scalar struct.');
    end
end

function functionsOut = ValidateTestHooks(hooks)
    if ~isfield(hooks, 'StageFunctions') || ...
            ~iscell(hooks.StageFunctions) || ...
            numel(hooks.StageFunctions) ~= 5 || ...
            ~all(cellfun(@(f) isa(f, 'function_handle'), ...
                hooks.StageFunctions))
        error('FloquetWorkflow:TestHookContract', [ ...
            'TestHooks.StageFunctions must contain exactly five function ' ...
            'handles.']);
    end
    functionsOut = reshape(hooks.StageFunctions, 1, []);
end

function [stageFunctions, identities] = CanonicalStageFunctions()
    workflowRoot = fullfile(fileparts(mfilename('fullpath')), '+internal');
    names = {'discoveryStage', 'refinementStage', 'seedSearchStage', ...
        'continuationStage', 'validationStage'};
    qualifiedNames = strcat('floquet.workflow.internal.', names);
    stageFunctions = { ...
        @floquet.workflow.internal.discoveryStage, ...
        @floquet.workflow.internal.refinementStage, ...
        @floquet.workflow.internal.seedSearchStage, ...
        @floquet.workflow.internal.continuationStage, ...
        @floquet.workflow.internal.validationStage};
    for k = 1:5
        expected = char(java.io.File(fullfile( ...
            workflowRoot, [names{k} '.m'])).getCanonicalPath());
        actual = which(qualifiedNames{k});
        if isempty(actual)
            error('FloquetWorkflow:MissingCanonicalRunner', ...
                'Canonical workflow runner is missing: %s', expected);
        end
        actual = char(java.io.File(actual).getCanonicalPath());
        if ~SamePath(actual, expected)
            error('FloquetWorkflow:ShadowedCanonicalRunner', ...
                '%s resolves to %s instead of canonical implementation %s.', ...
                qualifiedNames{k}, actual, expected);
        end
    end
    identities = FunctionIdentities(stageFunctions, false);
end

function identities = FunctionIdentities(stageFunctions, testInjected)
    names = {'discoveryStage', 'refinementStage', 'seedSearchStage', ...
        'continuationStage', 'validationStage'};
    identities = repmat(struct('StageNumber', NaN, 'CanonicalName', '', ...
        'Function', '', 'ImplementationFile', '', ...
        'TestInjected', false), 1, 5);
    for k = 1:5
        metadata = functions(stageFunctions{k});
        functionName = func2str(stageFunctions{k});
        filename = '';
        if isfield(metadata, 'file') && ~isempty(metadata.file)
            filename = char(java.io.File( ...
                metadata.file).getCanonicalPath());
        else
            located = which(functionName);
            if ~isempty(located) && isfile(located)
                filename = char(java.io.File(located).getCanonicalPath());
            end
        end
        identities(k) = struct('StageNumber', k, ...
            'CanonicalName', names{k}, ...
            'Function', functionName, ...
            'ImplementationFile', filename, ...
            'TestInjected', logical(testInjected));
    end
end

function stageNumber = ResolveStage(stage)
    if isnumeric(stage) && isreal(stage) && isscalar(stage) && ...
            isfinite(stage) && stage == floor(stage) && ...
            stage >= 1 && stage <= 5
        stageNumber = stage;
        return
    end
    if ~(ischar(stage) || (isstring(stage) && isscalar(stage)))
        error('FloquetWorkflow:Stage', ...
            'Stage must be an integer 1--5 or a stage name.');
    end
    value = lower(strtrim(char(string(stage))));
    names = {{'1', 'discovery', 'fdm', 'analysis'}, ...
        {'2', 'refinement', 'refine'}, ...
        {'3', 'seeds', 'seed-search', 'branch-switch'}, ...
        {'4', 'continuation', 'daughters'}, ...
        {'5', 'validation', 'validate'}};
    stageNumber = find(cellfun(@(items) any(strcmp(value, items)), ...
        names), 1);
    if isempty(stageNumber)
        error('FloquetWorkflow:Stage', 'Unknown workflow stage: %s', value);
    end
end

function ids = NormalizeCandidateIDs(ids)
    if isempty(ids)
        ids = {};
        return
    end
    if ischar(ids) || (isstring(ids) && isscalar(ids))
        ids = {char(string(ids))};
    elseif isstring(ids) || iscellstr(ids)
        ids = cellstr(ids(:).');
    else
        error('FloquetWorkflow:CandidateIDs', ...
            'Candidate IDs must be text or a cell/string vector.');
    end
    ids = cellfun(@strtrim, ids, 'UniformOutput', false);
    if any(cellfun(@isempty, ids)) || ...
            numel(unique(ids, 'stable')) ~= numel(ids)
        error('FloquetWorkflow:CandidateIDs', ...
            'Candidate IDs must be unique and nonempty.');
    end
end

function record = EmptyLastRun()
    record = struct('StageNumber', NaN, 'StageID', '', 'Status', ...
        'not-run', 'StartedAt', '', 'CompletedAt', '', 'Message', '', ...
        'ErrorIdentifier', '', 'ResultClass', '', ...
        'StateRefreshErrorIdentifier', '', 'StateRefreshMessage', '');
end

function record = RunningRecord(stageNumber, stage)
    record = EmptyLastRun();
    record.StageNumber = stageNumber;
    record.StageID = stage.ID;
    record.Status = 'running';
    record.StartedAt = Timestamp();
    record.Message = sprintf('Running Stage %d: %s.', ...
        stageNumber, stage.Name);
end

function [status, phase, message] = StageResultDisposition( ...
        stageNumber, result)
    status = 'completed';
    phase = 'completed';
    message = sprintf('Stage %d completed.', stageNumber);
    if stageNumber == 4 && isstruct(result) && isscalar(result) && ...
            isfield(result, 'FinalArtifactWritten') && ...
            isscalar(result.FinalArtifactWritten) && ...
            (islogical(result.FinalArtifactWritten) || ...
             (isnumeric(result.FinalArtifactWritten) && ...
              isreal(result.FinalArtifactWritten) && ...
              isfinite(result.FinalArtifactWritten) && ...
              any(result.FinalArtifactWritten == [0 1]))) && ...
            ~logical(result.FinalArtifactWritten)
        status = 'paused';
        phase = 'paused';
        message = ['Stage 4 paused safely between rays; resume from its ' ...
            'validated checkpoint to finish the daughter inventory.'];
    end
end

function record = EmptyNotificationError()
    record = struct('Occurred', false, 'Identifier', '', ...
        'Message', '', 'Timestamp', '');
end

function id = StageID(stageNumber)
    ids = {'discovery', 'refinement', 'seeds', ...
        'continuation', 'validation'};
    id = ids{stageNumber};
end

function tf = SamePath(first, second)
    if ispc
        tf = strcmpi(first, second);
    else
        tf = strcmp(first, second);
    end
end

function value = Timestamp()
    value = char(datetime('now', 'TimeZone', 'local', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end
