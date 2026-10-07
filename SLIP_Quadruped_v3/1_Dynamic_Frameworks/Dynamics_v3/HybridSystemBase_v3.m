classdef HybridSystemBase_v3 < handle
    %HYBRIDSYSTEMBASE_V3 Configurable interface for a hybrid dynamical system.
    %
    % A system supplies the four component maps
    %
    %   xdot  = flow(t,x,q,p)
    %   guards = activeGuards(t,x,q,p)
    %   xplus = reset(eventId,t,xminus,qminus,p)
    %   qplus = transition(eventId,qminus)
    %
    % Subclasses may override these methods.  The base class is also directly
    % constructible for tests and small synthetic systems by providing function
    % handles in a configuration structure.  Function handles use the argument
    % lists shown above and do not receive the system object.

    properties (SetAccess = protected)
        StateDimension = 0
        ParameterDimension = 0
        ModeSet = []

        StateNames = {}
        ParameterNames = {}

        TranslationIndex = []
        PhaseIndex = []
        DefaultUnknownIndices = []
        DefaultPeriodicIndices = []
        DefaultTangentIndices = []
    end

    properties (Access = protected)
        FlowFunction = []
        ActiveGuardsFunction = []
        ResetFunction = []
        TransitionFunction = []
        CanonicalizeFunction = []
        StateValidator = []
        ParameterValidator = []
        ModeValidator = []
        ModeCandidatesFunction = []
    end

    methods
        function obj = HybridSystemBase_v3(varargin)
            % Supported forms:
            %   HybridSystemBase_v3(configStruct)
            %   HybridSystemBase_v3(nState,nParameter,components,options)
            %   HybridSystemBase_v3('StateDimension',nState,...)
            if nargin > 0
                obj.configure(HybridSystemBase_v3.parseConfiguration(varargin{:}));
            end
        end

        function obj = configure(obj, config)
            %CONFIGURE Set dimensions, metadata, and optional component maps.
            if ~isstruct(config) || ~isscalar(config)
                error('HybridSystemBase_v3:InvalidConfiguration', ...
                    'Configuration must be a scalar structure.');
            end

            config = HybridSystemBase_v3.applyAliases(config);
            oldStateDimension = obj.StateDimension;
            oldParameterDimension = obj.ParameterDimension;

            if isfield(config, 'StateDimension')
                obj.StateDimension = HybridSystemBase_v3.validateDimension( ...
                    config.StateDimension, 'StateDimension');
            end
            if isfield(config, 'ParameterDimension')
                obj.ParameterDimension = HybridSystemBase_v3.validateDimension( ...
                    config.ParameterDimension, 'ParameterDimension');
            end

            if isfield(config, 'ModeSet')
                modes = config.ModeSet;
                if iscell(modes)
                    modes = modes(:);
                elseif ~(isnumeric(modes) || islogical(modes)) ...
                        || ~isreal(modes) || any(~isfinite(double(modes(:))))
                    error('HybridSystemBase_v3:InvalidModeSet', ...
                        ['ModeSet must be a cell array or a finite real ', ...
                        'numeric/logical matrix.']);
                end
                obj.ModeSet = modes;
            end

            if isfield(config, 'TranslationIndex')
                obj.TranslationIndex = HybridSystemBase_v3.validateIndices( ...
                    config.TranslationIndex, obj.StateDimension, ...
                    'TranslationIndex', true);
            elseif oldStateDimension ~= obj.StateDimension
                obj.TranslationIndex = [];
            end
            if isfield(config, 'PhaseIndex')
                obj.PhaseIndex = HybridSystemBase_v3.validateIndices( ...
                    config.PhaseIndex, obj.StateDimension, 'PhaseIndex', true);
            elseif oldStateDimension ~= obj.StateDimension
                obj.PhaseIndex = [];
            end

            obj.DefaultUnknownIndices = obj.configureIndexSet( ...
                config, 'DefaultUnknownIndices', oldStateDimension);
            obj.DefaultPeriodicIndices = obj.configureIndexSet( ...
                config, 'DefaultPeriodicIndices', oldStateDimension);
            obj.DefaultTangentIndices = obj.configureIndexSet( ...
                config, 'DefaultTangentIndices', oldStateDimension);

            if isfield(config, 'StateNames')
                obj.StateNames = HybridSystemBase_v3.validateNames( ...
                    config.StateNames, obj.StateDimension, 'StateNames');
            elseif oldStateDimension ~= obj.StateDimension
                obj.StateNames = arrayfun(@(i) sprintf('x%d', i), ...
                    1:obj.StateDimension, 'UniformOutput', false);
            end
            if isfield(config, 'ParameterNames')
                obj.ParameterNames = HybridSystemBase_v3.validateNames( ...
                    config.ParameterNames, obj.ParameterDimension, ...
                    'ParameterNames');
            elseif oldParameterDimension ~= obj.ParameterDimension ...
                    || isempty(obj.ParameterNames)
                obj.ParameterNames = arrayfun(@(i) sprintf('p%d', i), ...
                    1:obj.ParameterDimension, 'UniformOutput', false);
            end

            functionFields = { ...
                'FlowFunction', 'ActiveGuardsFunction', 'ResetFunction', ...
                'TransitionFunction', 'CanonicalizeFunction', ...
                'StateValidator', 'ParameterValidator', 'ModeValidator', ...
                'ModeCandidatesFunction'};
            for i = 1:numel(functionFields)
                fieldName = functionFields{i};
                if isfield(config, fieldName)
                    value = config.(fieldName);
                    if ~(isempty(value) || isa(value, 'function_handle'))
                        error('HybridSystemBase_v3:InvalidComponent', ...
                            '%s must be empty or a function handle.', fieldName);
                    end
                    obj.(fieldName) = value;
                end
            end
        end

        function dx = flow(obj, t, x, q, p)
            if isempty(obj.FlowFunction)
                error('HybridSystemBase_v3:MissingFlow', ...
                    'No flow component is configured.');
            end
            x = obj.validateState(x);
            p = obj.validateParameter(p);
            q = obj.validateMode(q);
            dx = obj.FlowFunction(t, x, q, p);
            dx = HybridSystemBase_v3.validateVectorResult( ...
                dx, obj.StateDimension, 'flow');
        end

        function guards = activeGuards(obj, t, x, q, p)
            if isempty(obj.ActiveGuardsFunction)
                error('HybridSystemBase_v3:MissingGuards', ...
                    'No active-guard component is configured.');
            end
            x = obj.validateState(x);
            p = obj.validateParameter(p);
            q = obj.validateMode(q);
            guards = obj.ActiveGuardsFunction(t, x, q, p);
            if ~isstruct(guards)
                error('HybridSystemBase_v3:InvalidGuards', ...
                    'activeGuards must return a structure array.');
            end
        end

        function xplus = reset(obj, eventId, t, xminus, qminus, p)
            if isempty(obj.ResetFunction)
                error('HybridSystemBase_v3:MissingReset', ...
                    'No reset component is configured.');
            end
            xminus = obj.validateState(xminus);
            p = obj.validateParameter(p);
            qminus = obj.validateMode(qminus);
            xplus = obj.ResetFunction(eventId, t, xminus, qminus, p);
            xplus = obj.validateState(xplus);
        end

        function qplus = transition(obj, eventId, qminus)
            if isempty(obj.TransitionFunction)
                error('HybridSystemBase_v3:MissingTransition', ...
                    'No mode-transition component is configured.');
            end
            qminus = obj.validateMode(qminus);
            qplus = obj.TransitionFunction(eventId, qminus);
            qplus = obj.validateMode(qplus);
        end

        function [xplus, qplus, batchInfo] = resolveEventBatch(obj, ...
                eventIds, t, xminus, qminus, p)
            %RESOLVEEVENTBATCH Resolve one simultaneous physical-event batch.
            %
            % The generic contract deliberately makes no commutativity
            % assumption.  Its backward-compatible fallback applies scalar
            % reset/transition pairs in the supplied order and labels that
            % choice explicitly.  Models with independent resets or coupled
            % impacts should override this method with their physical batch
            % semantics.
            xminus = obj.validateState(xminus);
            qminus = obj.validateMode(qminus);
            p = obj.validateParameter(p);
            sequence = HybridSystemBase_v3.eventSequence(eventIds);
            if isempty(sequence)
                error('HybridSystemBase_v3:EmptyEventBatch', ...
                    'A physical event batch must contain at least one event.');
            end

            count = numel(sequence);
            statesBefore = cell(count, 1);
            statesAfter = cell(count, 1);
            modesBefore = cell(count, 1);
            modesAfter = cell(count, 1);
            xwork = xminus;
            qwork = qminus;
            for index = 1:count
                statesBefore{index} = xwork;
                modesBefore{index} = qwork;
                xwork = obj.reset(sequence{index}, t, xwork, qwork, p);
                qwork = obj.transition(sequence{index}, qwork);
                statesAfter{index} = xwork;
                modesAfter{index} = qwork;
            end

            xplus = obj.validateState(xwork);
            qplus = obj.validateMode(qwork);
            batchInfo = struct( ...
                'semantics', "ordered-sequential-fallback", ...
                'atomic', false, ...
                'fallback', true, ...
                'event_ids', {sequence}, ...
                'event_count', count, ...
                'state_before', xminus, ...
                'state_after', xplus, ...
                'mode_before', qminus, ...
                'mode_after', qplus, ...
                'event_states_before', {statesBefore}, ...
                'event_states_after', {statesAfter}, ...
                'event_modes_before', {modesBefore}, ...
                'event_modes_after', {modesAfter}, ...
                'commutativity_checked', false, ...
                'reset_order_commutes', NaN, ...
                'transition_order_commutes', NaN, ...
                'commutativity_error', NaN);
        end

        function qAdjacent = adjacentMode(obj, eventId, q)
            %ADJACENTMODE Return the local chart across a guard surface.
            % The generic fallback is the forward transition. Models whose
            % section state can lie on the post-event side should override
            % this method to provide the inverse local adjacency as well.
            qAdjacent = obj.transition(eventId, q);
        end

        function x = canonicalizeState(obj, x, p)
            %CANONICALIZESTATE Remove continuous translation gauge(s).
            x = obj.validateState(x);
            if nargin < 3
                p = [];
            elseif ~isempty(p) || obj.ParameterDimension == 0
                p = obj.validateParameter(p);
            end

            if ~isempty(obj.CanonicalizeFunction)
                componentNargin = nargin(obj.CanonicalizeFunction);
                if componentNargin < 0 || componentNargin >= 2
                    x = obj.CanonicalizeFunction(x, p);
                else
                    x = obj.CanonicalizeFunction(x);
                end
                x = obj.validateState(x);
            elseif ~isempty(obj.TranslationIndex)
                x(obj.TranslationIndex) = 0;
            end
        end

        function x = validateState(obj, x)
            if ~isempty(obj.StateValidator)
                x = obj.StateValidator(x);
                return;
            end
            x = HybridSystemBase_v3.validateVectorResult( ...
                x, obj.StateDimension, 'state');
        end

        function p = validateParameter(obj, p)
            if ~isempty(obj.ParameterValidator)
                p = obj.ParameterValidator(p);
                return;
            end
            p = HybridSystemBase_v3.validateVectorResult( ...
                p, obj.ParameterDimension, 'parameter');
        end

        function p = validateParameters(obj, p)
            % Plural alias retained for callers that use vector terminology.
            p = obj.validateParameter(p);
        end

        function q = validateMode(obj, q)
            if ~isempty(obj.ModeValidator)
                q = obj.ModeValidator(q);
                return;
            end
            if iscell(obj.ModeSet)
                matches = cellfun(@(candidate) ...
                    HybridSystemBase_v3.modeEquals(candidate, q), obj.ModeSet);
                if ~any(matches)
                    error('HybridSystemBase_v3:InvalidMode', ...
                        'Mode is not a member of ModeSet.');
                end
                if isnumeric(q) || islogical(q)
                    q = q(:);
                end
                return;
            end
            if ~(isnumeric(q) || islogical(q)) || ~isreal(q) ...
                    || any(~isfinite(double(q(:))))
                error('HybridSystemBase_v3:InvalidMode', ...
                    'Mode must be finite, real, numeric, or logical.');
            end
            qRow = q(:).';
            if ~isempty(obj.ModeSet)
                if size(obj.ModeSet, 2) ~= numel(qRow) ...
                        || ~any(all(double(obj.ModeSet) == double(qRow), 2))
                    error('HybridSystemBase_v3:InvalidMode', ...
                        'Mode is not a member of ModeSet.');
                end
            end
            q = qRow(:);
        end

        function diagnostics = assertAdmissible(obj, x, q, p)
            %ASSERTADMISSIBLE Validate an accepted hybrid state.
            % Generic systems are admissible after their ordinary state,
            % mode, and parameter validators succeed. Models with unilateral
            % or other physical constraints override this hook. It is not
            % called at transient ODE solver stages.
            obj.validateState(x);
            obj.validateMode(q);
            obj.validateParameter(p);
            diagnostics = struct('admissible', true, ...
                'admissibility_margins', Inf);
        end

        function modes = modeCandidates(obj, varargin)
            %MODECANDIDATES Enumerate admissible discrete modes.
            % Canonical call: modeCandidates(x,q,p).  Shortened calls are
            % accepted for state-independent finite mode sets.
            [x, q, p] = obj.parseModeCandidateInputs(varargin{:});
            if ~isempty(obj.ModeCandidatesFunction)
                componentNargin = nargin(obj.ModeCandidatesFunction);
                if componentNargin < 0 || componentNargin >= 3
                    modes = obj.ModeCandidatesFunction(x, q, p);
                elseif componentNargin == 2
                    modes = obj.ModeCandidatesFunction(x, q);
                elseif componentNargin == 1
                    modes = obj.ModeCandidatesFunction(x);
                else
                    modes = obj.ModeCandidatesFunction();
                end
            else
                modes = obj.ModeSet;
            end
            modes = HybridSystemBase_v3.asModeCellArray(modes);
        end

        function u = unknownCoordinates(obj, x)
            x = obj.validateState(x);
            u = x(obj.DefaultUnknownIndices);
        end

        function r = periodicDifference(obj, xnext, x0)
            xnext = obj.validateState(xnext);
            x0 = obj.validateState(x0);
            r = xnext(obj.DefaultPeriodicIndices) ...
                - x0(obj.DefaultPeriodicIndices);
        end

        function z = tangentCoordinates(obj, x)
            x = obj.validateState(x);
            z = x(obj.DefaultTangentIndices);
        end

        % Descriptive aliases used by component-oriented callers.
        function dx = continuousDynamics(obj, t, x, q, p)
            dx = obj.flow(t, x, q, p);
        end

        function guards = guardFunctions(obj, t, x, q, p)
            guards = obj.activeGuards(t, x, q, p);
        end

        function xplus = resetMap(obj, eventId, t, xminus, qminus, p)
            xplus = obj.reset(eventId, t, xminus, qminus, p);
        end

        function qplus = modeTransition(obj, eventId, qminus)
            qplus = obj.transition(eventId, qminus);
        end

        function x = canonicalizeTranslation(obj, x, p)
            if nargin < 3
                x = obj.canonicalizeState(x);
            else
                x = obj.canonicalizeState(x, p);
            end
        end
    end

    methods (Access = private)
        function indices = configureIndexSet(obj, config, fieldName, oldDimension)
            if isfield(config, fieldName)
                indices = HybridSystemBase_v3.validateIndices( ...
                    config.(fieldName), obj.StateDimension, fieldName, false);
            elseif oldDimension ~= obj.StateDimension || isempty(obj.(fieldName))
                indices = 1:obj.StateDimension;
            else
                indices = obj.(fieldName);
            end
        end

        function [x, q, p] = parseModeCandidateInputs(obj, varargin)
            x = [];
            q = [];
            p = [];
            if numel(varargin) > 3
                error('HybridSystemBase_v3:InvalidCandidateInput', ...
                    'modeCandidates accepts at most x, q, and p.');
            elseif numel(varargin) == 3
                x = obj.validateState(varargin{1});
                q = obj.validateMode(varargin{2});
                p = obj.validateParameter(varargin{3});
            elseif numel(varargin) == 2
                x = obj.validateState(varargin{1});
                q = obj.validateMode(varargin{2});
            elseif isscalar(varargin) && ~isempty(varargin{1})
                value = varargin{1};
                if isnumeric(value) || islogical(value)
                    if numel(value) == obj.StateDimension
                        x = obj.validateState(value);
                    else
                        q = obj.validateMode(value);
                    end
                else
                    q = obj.validateMode(value);
                end
            end
        end
    end

    methods (Static, Access = private)
        function sequence = eventSequence(eventIds)
            % Return a cell column without imposing an event-ID type.
            if ischar(eventIds) || ...
                    (isstring(eventIds) && isscalar(eventIds))
                sequence = {eventIds};
            elseif iscell(eventIds)
                sequence = eventIds(:);
            elseif isstring(eventIds)
                sequence = num2cell(eventIds(:));
            elseif isnumeric(eventIds) || islogical(eventIds)
                sequence = num2cell(eventIds(:));
            elseif isscalar(eventIds)
                sequence = {eventIds};
            else
                error('HybridSystemBase_v3:InvalidEventBatch', ...
                    ['EVENTIDS must be a scalar event identifier or a ', ...
                     'vector/cell array of event identifiers.']);
            end
        end

        function config = parseConfiguration(varargin)
            config = struct();
            if isempty(varargin)
                return;
            end

            next = 1;
            if numel(varargin) >= 2 && isnumeric(varargin{1}) ...
                    && isscalar(varargin{1}) && isnumeric(varargin{2}) ...
                    && isscalar(varargin{2})
                config.StateDimension = varargin{1};
                config.ParameterDimension = varargin{2};
                next = 3;
                while next <= numel(varargin) && isstruct(varargin{next})
                    config = HybridSystemBase_v3.mergeStructures( ...
                        config, varargin{next});
                    next = next + 1;
                end
            elseif isstruct(varargin{1})
                config = varargin{1};
                next = 2;
                while next <= numel(varargin) && isstruct(varargin{next})
                    config = HybridSystemBase_v3.mergeStructures( ...
                        config, varargin{next});
                    next = next + 1;
                end
            end

            remaining = varargin(next:end);
            if isempty(remaining)
                return;
            end
            if mod(numel(remaining), 2) ~= 0
                error('HybridSystemBase_v3:InvalidConfiguration', ...
                    'Name/value configuration requires an even number of inputs.');
            end
            for i = 1:2:numel(remaining)
                name = remaining{i};
                if ~(ischar(name) || (isstring(name) && isscalar(name)))
                    error('HybridSystemBase_v3:InvalidConfiguration', ...
                        'Configuration names must be text scalars.');
                end
                config.(char(name)) = remaining{i + 1};
            end
        end

        function output = mergeStructures(output, input)
            if ~isstruct(input) || ~isscalar(input)
                error('HybridSystemBase_v3:InvalidConfiguration', ...
                    'Component and option inputs must be scalar structures.');
            end
            names = fieldnames(input);
            for i = 1:numel(names)
                output.(names{i}) = input.(names{i});
            end
        end

        function config = applyAliases(config)
            aliases = { ...
                'stateDimension', 'StateDimension'; ...
                'parameterDimension', 'ParameterDimension'; ...
                'modeSet', 'ModeSet'; ...
                'translationIndex', 'TranslationIndex'; ...
                'phaseIndex', 'PhaseIndex'; ...
                'defaultUnknownIndices', 'DefaultUnknownIndices'; ...
                'defaultPeriodicIndices', 'DefaultPeriodicIndices'; ...
                'defaultTangentIndices', 'DefaultTangentIndices'; ...
                'flow', 'FlowFunction'; ...
                'Flow', 'FlowFunction'; ...
                'ContinuousDynamics', 'FlowFunction'; ...
                'activeGuards', 'ActiveGuardsFunction'; ...
                'ActiveGuards', 'ActiveGuardsFunction'; ...
                'guards', 'ActiveGuardsFunction'; ...
                'GuardFunctions', 'ActiveGuardsFunction'; ...
                'reset', 'ResetFunction'; ...
                'ResetMap', 'ResetFunction'; ...
                'transition', 'TransitionFunction'; ...
                'ModeTransition', 'TransitionFunction'; ...
                'canonicalizeState', 'CanonicalizeFunction'; ...
                'CanonicalizeState', 'CanonicalizeFunction'; ...
                'validateState', 'StateValidator'; ...
                'ValidateState', 'StateValidator'; ...
                'validateParameter', 'ParameterValidator'; ...
                'ValidateParameter', 'ParameterValidator'; ...
                'validateMode', 'ModeValidator'; ...
                'ValidateMode', 'ModeValidator'; ...
                'modeCandidates', 'ModeCandidatesFunction'; ...
                'ModeCandidates', 'ModeCandidatesFunction'};
            for i = 1:size(aliases, 1)
                alias = aliases{i, 1};
                target = aliases{i, 2};
                if isfield(config, alias) && ~isfield(config, target)
                    config.(target) = config.(alias);
                end
            end
        end

        function n = validateDimension(n, name)
            if ~(isnumeric(n) && isreal(n) && isscalar(n) && isfinite(n) ...
                    && n >= 0 && n == fix(n))
                error('HybridSystemBase_v3:InvalidDimension', ...
                    '%s must be a nonnegative integer scalar.', name);
            end
            n = double(n);
        end

        function indices = validateIndices(indices, n, name, allowEmpty)
            if isempty(indices)
                if allowEmpty
                    indices = [];
                    return;
                end
                indices = [];
                return;
            end
            if ~(isnumeric(indices) && isreal(indices) && isvector(indices)) ...
                    || any(~isfinite(indices(:))) || any(indices(:) ~= fix(indices(:))) ...
                    || any(indices(:) < 1) || any(indices(:) > n) ...
                    || numel(unique(indices(:))) ~= numel(indices)
                error('HybridSystemBase_v3:InvalidIndices', ...
                    '%s must contain unique state indices between 1 and %d.', ...
                    name, n);
            end
            indices = double(indices(:).');
        end

        function names = validateNames(names, n, fieldName)
            if isstring(names)
                names = cellstr(names(:).');
            end
            if ~iscellstr(names) || numel(names) ~= n
                error('HybridSystemBase_v3:InvalidNames', ...
                    '%s must contain exactly %d character vectors.', fieldName, n);
            end
            names = names(:).';
        end

        function value = validateVectorResult(value, n, label)
            isExpectedEmpty = n == 0 && isnumeric(value) && isempty(value);
            isExpectedVector = isnumeric(value) && isreal(value) ...
                && isvector(value) && numel(value) == n ...
                && all(isfinite(value(:)));
            if ~(isExpectedEmpty || isExpectedVector)
                error('HybridSystemBase_v3:InvalidVector', ...
                    '%s must be a finite real numeric vector with %d elements.', ...
                    label, n);
            end
            value = double(value(:));
        end


        function modes = asModeCellArray(modes)
            if iscell(modes)
                modes = modes(:);
                return;
            end
            if isempty(modes)
                modes = cell(0, 1);
                return;
            end
            if ~(isnumeric(modes) || islogical(modes)) || ~ismatrix(modes)
                error('HybridSystemBase_v3:InvalidModeCandidates', ...
                    'Mode candidates must be a cell array or numeric matrix.');
            end
            matrix = modes;
            modes = arrayfun(@(i) matrix(i, :).', ...
                (1:size(matrix, 1)).', 'UniformOutput', false);
        end

        function tf = modeEquals(left, right)
            if (isnumeric(left) || islogical(left)) ...
                    && (isnumeric(right) || islogical(right))
                tf = isequal(size(left(:)), size(right(:))) ...
                    && all(double(left(:)) == double(right(:)));
            else
                tf = isequal(left, right);
            end
        end
    end
end
