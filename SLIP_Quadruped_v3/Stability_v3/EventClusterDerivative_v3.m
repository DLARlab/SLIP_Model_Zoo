classdef EventClusterDerivative_v3
    %EVENTCLUSTERDERIVATIVE_V3 Bouligand set from nearby event orderings.
    %   Each ordering callback represents one admissible smooth limit of a
    %   split simultaneous-event cluster. Incompatible matrices are retained
    %   as a set and are never averaged.

    properties
        Jacobian = []
        AgreementTolerance = 1e-6
        MaximumOrderings = 120
        RequireResolvedGuardCone = true
    end

    methods
        function obj = EventClusterDerivative_v3(options)
            if nargin < 1 || isempty(options)
                options = struct();
            end
            names = fieldnames(options);
            for index = 1:numel(names)
                if ~isprop(obj, names{index})
                    error('EventClusterDerivative_v3:Option', ...
                        'Unknown option "%s".', names{index});
                end
                obj.(names{index}) = options.(names{index});
            end
            if isempty(obj.Jacobian)
                obj.Jacobian = HybridFiniteDifferenceJacobian_v3();
            end
            if ~(isnumeric(obj.AgreementTolerance) && ...
                    isscalar(obj.AgreementTolerance) && ...
                    isfinite(obj.AgreementTolerance) && ...
                    obj.AgreementTolerance > 0)
                error('EventClusterDerivative_v3:Tolerance', ...
                    'AgreementTolerance must be positive and finite.');
            end
            if ~(isnumeric(obj.MaximumOrderings) && ...
                    isscalar(obj.MaximumOrderings) && ...
                    obj.MaximumOrderings >= 1 && ...
                    obj.MaximumOrderings == floor(obj.MaximumOrderings))
                error('EventClusterDerivative_v3:MaximumOrderings', ...
                    'MaximumOrderings must be a positive integer.');
            end
            if ~(islogical(obj.RequireResolvedGuardCone) && ...
                    isscalar(obj.RequireResolvedGuardCone))
                error('EventClusterDerivative_v3:GuardConeOption', ...
                    'RequireResolvedGuardCone must be a logical scalar.');
            end
        end

        function orderings = enumerateOrderings(obj, eventIds, ...
                callbackFactory, admissibilityPredicate)
            %ENUMERATEORDERINGS Build all admissible local split sequences.
            % CALLBACKFACTORY receives one ordered event-ID cell vector and
            % must return the corresponding one-sided return-map callback.
            % ADMISSIBILITYPREDICATE may reject mode-inconsistent sequences.
            if nargin < 4 || isempty(admissibilityPredicate)
                admissibilityPredicate = @(~) true;
            end
            if ~isa(callbackFactory, 'function_handle') || ...
                    ~isa(admissibilityPredicate, 'function_handle')
                error('EventClusterDerivative_v3:OrderingFactory', ...
                    'Callback factory and admissibility predicate must be functions.');
            end
            ids = obj.eventSequence(eventIds);
            count = numel(ids);
            if count < 1
                error('EventClusterDerivative_v3:EmptyCluster', ...
                    'A simultaneous event cluster cannot be empty.');
            end
            orderingCount = factorial(count);
            if orderingCount > obj.MaximumOrderings
                error('EventClusterDerivative_v3:OrderingLimit', ...
                    ['The cluster has %d permutations, exceeding ', ...
                     'MaximumOrderings=%d.'], orderingCount, ...
                    obj.MaximumOrderings);
            end
            indices = perms(1:count);
            orderings = repmat(struct('name', '', 'signature', '', ...
                'event_ids', {{}}, 'callback', []), 0, 1);
            for row = 1:size(indices, 1)
                sequence = ids(indices(row, :));
                if ~logical(admissibilityPredicate(sequence))
                    continue
                end
                callback = callbackFactory(sequence);
                if ~isa(callback, 'function_handle')
                    error('EventClusterDerivative_v3:OrderingFactory', ...
                        'Callback factory must return a function handle.');
                end
                labels = cellfun(@(value) obj.eventText(value), ...
                    sequence, 'UniformOutput', false);
                signature = strjoin(labels, '>');
                orderings(end + 1, 1) = struct( ... %#ok<AGROW>
                    'name', signature, ...
                    'signature', signature, ...
                    'event_ids', {sequence}, ...
                    'callback', callback);
            end
            if isempty(orderings)
                error('EventClusterDerivative_v3:NoAdmissibleOrdering', ...
                    'No event ordering passed the admissibility predicate.');
            end
        end

        function [orderings, diagnostics] = enumerateModelOrderings(obj, ...
                system, eventIds, t, xminus, qminus, p, ...
                callbackFactory, conePredicate)
            %ENUMERATEMODELORDERINGS Enumerate mode-feasible split limits.
            %   Unlike the callback-only convenience API, this method walks
            %   every scalar reset and transition on the supplied hybrid
            %   model.  CONEPREDICATE(sequence,trace) can impose the local
            %   one-sided guard cone obtained from an external saltation or
            %   guard-time analysis.  Rejected reset/mode sequences are
            %   retained in DIAGNOSTICS rather than silently discarded.
            conePredicateSupplied = nargin >= 9 && ~isempty(conePredicate);
            if ~conePredicateSupplied
                conePredicate = @(sequence, trace) true; %#ok<INUSD>
            end
            if ~isa(callbackFactory, 'function_handle') || ...
                    ~isa(conePredicate, 'function_handle')
                error('EventClusterDerivative_v3:ModelOrderingFactory', ...
                    'Callback factory and cone predicate must be functions.');
            end
            required = {'reset', 'transition', 'resolveEventBatch'};
            for index = 1:numel(required)
                if ~ismethod(system, required{index})
                    error('EventClusterDerivative_v3:HybridSystem', ...
                        'The model must implement %s.', required{index});
                end
            end

            ids = obj.eventSequence(eventIds);
            count = numel(ids);
            if count < 1
                error('EventClusterDerivative_v3:EmptyCluster', ...
                    'A simultaneous event cluster cannot be empty.');
            end
            orderingCount = factorial(count);
            if orderingCount > obj.MaximumOrderings
                error('EventClusterDerivative_v3:OrderingLimit', ...
                    ['The cluster has %d permutations, exceeding ', ...
                     'MaximumOrderings=%d.'], orderingCount, ...
                    obj.MaximumOrderings);
            end

            [batchState, batchMode, batchInfo] = system.resolveEventBatch( ...
                ids, t, xminus, qminus, p);
            indices = perms(1:count);
            orderings = repmat(struct('name', '', 'signature', '', ...
                'event_ids', {{}}, 'callback', [], 'trace', struct(), ...
                'cone_info', struct()), 0, 1);
            rejected = repmat(struct('event_ids', {{}}, ...
                'signature', '', 'reason', '', 'cone_info', struct()), 0, 1);
            terminalStates = cell(0, 1);
            terminalModes = cell(0, 1);
            coneResolution = false(0, 1);
            for row = 1:size(indices, 1)
                sequence = ids(indices(row, :));
                labels = cellfun(@(value) obj.eventText(value), ...
                    sequence, 'UniformOutput', false);
                signature = strjoin(labels, '>');
                try
                    trace = obj.applyModelOrder( ...
                        system, sequence, t, xminus, qminus, p);
                    [coneAccepted, coneInfo] = obj.evaluateConePredicate( ...
                        conePredicate, sequence, trace, ...
                        conePredicateSupplied);
                    coneResolution(end + 1, 1) = ... %#ok<AGROW>
                        coneInfo.resolved;
                    if ~(isscalar(coneAccepted) && logical(coneAccepted))
                        rejected(end + 1, 1) = struct( ... %#ok<AGROW>
                            'event_ids', {sequence}, ...
                            'signature', signature, ...
                            'reason', 'outside supplied one-sided guard cone', ...
                            'cone_info', coneInfo);
                        continue
                    end
                    callback = obj.makeOrderingCallback( ...
                        callbackFactory, sequence, trace);
                    orderings(end + 1, 1) = struct( ... %#ok<AGROW>
                        'name', signature, 'signature', signature, ...
                        'event_ids', {sequence}, 'callback', callback, ...
                        'trace', trace, 'cone_info', coneInfo);
                    terminalStates{end + 1, 1} = trace.state_after; %#ok<AGROW>
                    terminalModes{end + 1, 1} = trace.mode_after; %#ok<AGROW>
                catch exception
                    rejected(end + 1, 1) = struct( ... %#ok<AGROW>
                        'event_ids', {sequence}, 'signature', signature, ...
                        'reason', sprintf('%s: %s', ...
                            exception.identifier, exception.message), ...
                        'cone_info', struct());
                end
            end
            if isempty(orderings)
                detail = '';
                if ~isempty(rejected)
                    detail = sprintf(' First rejection: %s', ...
                        rejected(1).reason);
                end
                error('EventClusterDerivative_v3:NoAdmissibleOrdering', ...
                    'No model-feasible event ordering remained.%s', detail);
            end

            stateDifferences = zeros(numel(orderings));
            modeAgreement = true(numel(orderings));
            for left = 1:numel(orderings)
                for right = left + 1:numel(orderings)
                    stateDifferences(left, right) = norm( ...
                        terminalStates{left} - terminalStates{right}, Inf);
                    stateDifferences(right, left) = ...
                        stateDifferences(left, right);
                    modeAgreement(left, right) = isequal( ...
                        terminalModes{left}, terminalModes{right});
                    modeAgreement(right, left) = modeAgreement(left, right);
                end
            end
            diagnostics = struct( ...
                'event_ids', {ids}, ...
                'permutation_count', size(indices, 1), ...
                'admissible_count', numel(orderings), ...
                'rejected_count', numel(rejected), ...
                'rejected_orderings', rejected, ...
                'batch_state', batchState, ...
                'batch_mode', batchMode, ...
                'batch_info', batchInfo, ...
                'terminal_states', {terminalStates}, ...
                'terminal_modes', {terminalModes}, ...
                'pairwise_reset_state_differences', stateDifferences, ...
                'all_modes_agree', all(modeAgreement, 'all'), ...
                'maximum_reset_order_difference', ...
                    max(stateDifferences, [], 'all'), ...
                'reset_orders_commute', ...
                    all(modeAgreement, 'all') && ...
                    max(stateDifferences, [], 'all') <= ...
                        obj.AgreementTolerance, ...
                'cone_predicate_supplied', conePredicateSupplied, ...
                'cone_resolution_flags', coneResolution, ...
                'guard_cone_resolved', conePredicateSupplied && ...
                    ~isempty(coneResolution) && all(coneResolution));
        end

        function result = computeModelCluster(obj, system, eventIds, t, ...
                xminus, qminus, p, callbackFactory, point, conePredicate)
            %COMPUTEMODELCLUSTER Model-feasible Bouligand ordering set.
            if nargin < 10
                conePredicate = [];
            end
            [orderings, modelDiagnostics] = obj.enumerateModelOrderings( ...
                system, eventIds, t, xminus, qminus, p, ...
                callbackFactory, conePredicate);
            result = obj.compute(orderings, point);
            result.modelOrderingDiagnostics = modelDiagnostics;
            result.model_ordering_diagnostics = modelDiagnostics;
            result.resetOrdersCommute = ...
                modelDiagnostics.reset_orders_commute;
            result.reset_orders_commute = result.resetOrdersCommute;
            result.guardConeResolved = ...
                modelDiagnostics.guard_cone_resolved;
            result.guard_cone_resolved = result.guardConeResolved;
            result.conePredicateSupplied = ...
                modelDiagnostics.cone_predicate_supplied;
            result.resetOnlyClassicalUnique = result.classicalUnique;
            if obj.RequireResolvedGuardCone && ~result.guardConeResolved
                result.classicalUnique = false;
                result.reliable = false;
                result.uniqueClassicalMatrix = [];
                result.multipliers = [];
                result.derivativeScope = ...
                    'ordering diagnostic with unresolved guard-time cones';
                result.derivative_scope = result.derivativeScope;
                result.warning = ['Reset-order limits were computed, but ', ...
                    'the admissible guard-time cones were not supplied ', ...
                    'with affirmative resolution evidence. No unique ', ...
                    'full-cycle classical derivative is claimed.'];
            else
                result.derivativeScope = 'resolved full-return ordering limits';
                result.derivative_scope = result.derivativeScope;
            end
        end

        function result = compute(obj, orderings, point, varargin)
            orderings = obj.validateOrderings(orderings);
            point = point(:);
            limits = repmat(struct('name', '', 'signature', '', ...
                'matrix', [], 'baseValue', [], 'finiteDifference', struct(), ...
                'multipliers', [], 'reliable', false, 'error', ''), ...
                1, numel(orderings));
            for index = 1:numel(orderings)
                limits(index).name = char(orderings(index).name);
                limits(index).signature = char(orderings(index).signature);
                try
                    [matrix, baseValue, fdInfo] = obj.Jacobian.compute( ...
                        orderings(index).callback, point, varargin{:});
                    limits(index).matrix = matrix;
                    limits(index).baseValue = baseValue;
                    limits(index).finiteDifference = fdInfo;
                    limits(index).reliable = fdInfo.allReliable && ...
                        fdInfo.classicalDerivative && ...
                        all(isfinite(matrix(:)));
                    if size(matrix, 1) == size(matrix, 2) && ...
                            all(isfinite(matrix(:)))
                        limits(index).multipliers = eig(matrix);
                    end
                catch exception
                    limits(index).error = sprintf('%s: %s', ...
                        exception.identifier, exception.message);
                end
            end

            count = numel(limits);
            differences = zeros(count);
            for left = 1:count
                for right = left + 1:count
                    if isempty(limits(left).matrix) || ...
                            isempty(limits(right).matrix) || ...
                            ~isequal(size(limits(left).matrix), ...
                                size(limits(right).matrix))
                        difference = Inf;
                    else
                        difference = norm(limits(left).matrix - ...
                            limits(right).matrix, 2);
                    end
                    differences(left, right) = difference;
                    differences(right, left) = difference;
                end
            end
            if count <= 1
                maximumDifference = 0;
            else
                maximumDifference = max(differences, [], 'all');
            end
            allReliable = all([limits.reliable]);
            uniqueClassical = allReliable && ...
                maximumDifference <= obj.AgreementTolerance;

            result = struct();
            result.derivativeModel = 'bouligand-event-order-set';
            result.derivative_model = result.derivativeModel;
            result.orderingLimits = limits;
            result.ordering_limits = limits;
            result.admissibleOrderings = {limits.name};
            result.orderingSignatures = {limits.signature};
            result.pairwiseMatrixDifferences = differences;
            result.maximumOrderingDifference = maximumDifference;
            result.agreementTolerance = obj.AgreementTolerance;
            result.allLimitsReliable = allReliable;
            result.classicalUnique = uniqueClassical;
            result.reliable = uniqueClassical;
            if uniqueClassical
                % Every limit agrees within tolerance. Select one actual
                % limit; never average event-order matrices.
                result.uniqueClassicalMatrix = limits(1).matrix;
                result.multipliers = limits(1).multipliers;
                result.warning = '';
            else
                result.uniqueClassicalMatrix = [];
                result.multipliers = [];
                result.warning = ['Admissible event-order limits do not ', ...
                    'define one unique classical return-map derivative.'];
            end
        end
    end

    methods (Access = private)
        function [accepted, info] = evaluateConePredicate(obj, predicate, ...
                sequence, trace, supplied)
            info = struct('resolved', false, 'details', struct(), ...
                'source', 'none');
            if ~supplied
                accepted = true;
                return
            end
            outputCount = nargout(predicate);
            if outputCount == 1
                accepted = predicate(sequence, trace);
                info.source = 'single-output-predicate';
                accepted = obj.validateConeAcceptance(accepted);
                return
            end
            try
                [accepted, details] = predicate(sequence, trace);
                info.source = 'explicit-two-output-predicate';
                if isstruct(details)
                    info.details = details;
                    if isfield(details, 'resolved') && ...
                            isscalar(details.resolved)
                        info.resolved = logical(details.resolved);
                    elseif isfield(details, 'guard_cone_resolved') && ...
                            isscalar(details.guard_cone_resolved)
                        info.resolved = logical( ...
                            details.guard_cone_resolved);
                    end
                end
            catch exception
                tooManyOutputs = any(strcmp(exception.identifier, { ...
                    'MATLAB:maxlhs', 'MATLAB:TooManyOutputs', ...
                    'MATLAB:unassignedOutputs', ...
                    'MATLAB:needMoreRhsOutputs'}));
                if ~tooManyOutputs
                    rethrow(exception)
                end
                accepted = predicate(sequence, trace);
                info.source = 'single-output-predicate';
            end
            accepted = obj.validateConeAcceptance(accepted);
        end

        function accepted = validateConeAcceptance(~, accepted)
            if ~(isscalar(accepted) && ...
                    (islogical(accepted) || isnumeric(accepted)) && ...
                    isfinite(double(accepted)))
                error('EventClusterDerivative_v3:GuardConePredicate', ...
                    'Guard-cone acceptance must be a finite logical scalar.');
            end
            accepted = logical(accepted);
        end

        function trace = applyModelOrder(~, system, sequence, t, ...
                xminus, qminus, p)
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
                xwork = system.reset( ...
                    sequence{index}, t, xwork, qwork, p);
                qwork = system.transition(sequence{index}, qwork);
                statesAfter{index} = xwork;
                modesAfter{index} = qwork;
            end
            trace = struct('state_before', xminus, ...
                'state_after', xwork, 'mode_before', qminus, ...
                'mode_after', qwork, ...
                'states_before', {statesBefore}, ...
                'states_after', {statesAfter}, ...
                'modes_before', {modesBefore}, ...
                'modes_after', {modesAfter});
        end

        function callback = makeOrderingCallback(~, factory, sequence, trace)
            count = nargin(factory);
            if count < 0 || count >= 2
                callback = factory(sequence, trace);
            else
                callback = factory(sequence);
            end
            if ~isa(callback, 'function_handle')
                error('EventClusterDerivative_v3:OrderingFactory', ...
                    'Callback factory must return a function handle.');
            end
        end

        function sequence = eventSequence(~, eventIds)
            if iscell(eventIds)
                sequence = eventIds(:).';
            elseif isstring(eventIds)
                sequence = cellstr(eventIds(:).');
            elseif isnumeric(eventIds) || islogical(eventIds)
                sequence = num2cell(eventIds(:).');
            elseif ischar(eventIds)
                sequence = {eventIds};
            else
                error('EventClusterDerivative_v3:EventIds', ...
                    'Event IDs must be a vector, string array, or cell array.');
            end
        end

        function label = eventText(~, value)
            if ischar(value)
                label = value;
            elseif isstring(value) && isscalar(value)
                label = char(value);
            elseif isnumeric(value) || islogical(value)
                label = mat2str(value);
            else
                label = char(string(value));
            end
        end

        function orderings = validateOrderings(~, orderings)
            if ~isstruct(orderings) || isempty(orderings) || ...
                    ~all(isfield(orderings, {'name', 'callback'}))
                error('EventClusterDerivative_v3:Orderings', ...
                    ['orderings must be a nonempty structure array with ', ...
                     'name and callback fields.']);
            end
            if ~isfield(orderings, 'signature')
                [orderings.signature] = deal('');
            end
            for index = 1:numel(orderings)
                if ~isa(orderings(index).callback, 'function_handle')
                    error('EventClusterDerivative_v3:Callback', ...
                        'Every ordering callback must be a function handle.');
                end
                if ~(ischar(orderings(index).name) || ...
                        (isstring(orderings(index).name) && ...
                         isscalar(orderings(index).name)))
                    error('EventClusterDerivative_v3:Name', ...
                        'Every ordering must have a scalar text name.');
                end
            end
        end
    end
end
