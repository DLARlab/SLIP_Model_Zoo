classdef Quadrupedal_Dynamics_v3 < HybridSystemBase_v3
    %QUADRUPEDAL_DYNAMICS_V3 Component assembly for the v3 SLIP quadruped.
    %
    % State, parameter, leg, mode, and event ordering are owned exclusively
    % by QuadrupedSchema_v3.  This class prescribes no gait, event order, or
    % contact mode at the Poincare section.

    properties (SetAccess = private)
        Schema
        ContinuousDynamicsComponent
        GuardFunctionsComponent
        ResetMapComponent
        ModeTransitionComponent
    end

    methods
        function obj = Quadrupedal_Dynamics_v3(components)
            schema = QuadrupedSchema_v3.shared();
            transition = ModeTransition_v3(schema);
            metadata = struct( ...
                'StateDimension', schema.State.Dimension, ...
                'ParameterDimension', schema.Parameter.Dimension, ...
                'ModeSet', transition.modeMatrix(), ...
                'StateNames', {schema.State.Names}, ...
                'ParameterNames', {schema.Parameter.Names}, ...
                'TranslationIndex', schema.Root.TranslationIndex, ...
                'PhaseIndex', schema.Root.PhaseIndex, ...
                'DefaultUnknownIndices', schema.Root.UnknownIndices, ...
                'DefaultPeriodicIndices', schema.Root.PeriodicIndices, ...
                'DefaultTangentIndices', schema.Root.TangentIndices);
            obj@HybridSystemBase_v3(metadata);

            obj.Schema = schema;
            obj.ContinuousDynamicsComponent = ContinuousDynamics_v3(schema);
            obj.GuardFunctionsComponent = GuardFunctions_v3(schema);
            obj.ResetMapComponent = ResetMap_v3(schema);
            obj.ModeTransitionComponent = transition;

            if nargin > 0 && ~isempty(components)
                obj.installComponents(components);
            end
        end

        function [dxdt, diagnostics] = flow(obj, t, x, q, p)
            x = obj.validateState(x);
            q = obj.validateMode(q);
            p = obj.validateParameter(p);
            if nargout > 1
                [dxdt, diagnostics] = ...
                    obj.ContinuousDynamicsComponent.evaluate(t, x, q, p);
            else
                dxdt = obj.ContinuousDynamicsComponent.evaluate(t, x, q, p);
            end
            dxdt = obj.validateState(dxdt);
        end

        function guards = activeGuards(obj, t, x, q, p)
            guards = obj.guardFunctions(t, x, q, p);
            guards = guards([guards.enabled]);
        end

        function guards = guardFunctions(obj, t, x, q, p)
            % Return all eight guards; inactive entries retain true values.
            x = obj.validateState(x);
            q = obj.validateMode(q);
            p = obj.validateParameter(p);
            guards = obj.GuardFunctionsComponent.descriptors(t, x, q, p);
            dxdt = obj.ContinuousDynamicsComponent.evaluate(t, x, q, p);
            guards = obj.GuardFunctionsComponent.attachFlowDerivatives( ...
                guards, x, dxdt, p);
        end

        function xplus = reset(obj, eventId, t, xminus, qminus, p)
            xminus = obj.validateState(xminus);
            qminus = obj.validateMode(qminus);
            p = obj.validateParameter(p);
            xplus = obj.ResetMapComponent.apply( ...
                eventId, t, xminus, qminus, p);
            xplus = obj.validateState(xplus);
        end

        function qplus = transition(obj, eventId, qminus)
            qminus = obj.validateMode(qminus);
            qplus = obj.ModeTransitionComponent.apply(eventId, qminus);
            qplus = obj.validateMode(qplus);
        end

        function [xplus, qplus, batchInfo] = resolveEventBatch(obj, ...
                eventIds, t, xminus, qminus, p)
            %RESOLVEEVENTBATCH Resolve independent massless-leg resets.
            % Distinct legs project distinct angular-rate coordinates.  The
            % implementation verifies the two extreme scalar orders against
            % the component batch maps before declaring them commuting.
            xminus = obj.validateState(xminus);
            qminus = obj.validateMode(qminus);
            p = obj.validateParameter(p);
            ids = obj.normalizeEventIds(eventIds);
            if isempty(ids)
                error('Quadrupedal_Dynamics_v3:EmptyEventBatch', ...
                    'A physical event batch must contain at least one event.');
            end
            legIndices = obj.Schema.Event.LegIndices(ids).';
            if numel(unique(legIndices)) ~= numel(ids)
                error('Quadrupedal_Dynamics_v3:ConflictingEventBatch', ...
                    ['Independent-leg batch semantics permit at most one ', ...
                     'event per leg.']);
            end

            [xForward, qForward, trace] = obj.applySequentialBatch( ...
                ids, t, xminus, qminus, p);
            reverseIds = flipud(ids);
            [xReverse, qReverse] = obj.applySequentialBatch( ...
                reverseIds, t, xminus, qminus, p);
            xBatch = obj.ResetMapComponent.applyBatch( ...
                ids, t, xminus, qminus, p);
            qBatch = obj.ModeTransitionComponent.applyBatch(ids, qminus);

            scale = max(1, norm([xminus; xForward; xReverse; xBatch], inf));
            tolerance = 256 * eps(scale);
            forwardReverseError = norm(xForward - xReverse, inf);
            batchAgreementError = max(norm(xBatch - xForward, inf), ...
                norm(xBatch - xReverse, inf));
            resetError = max(forwardReverseError, batchAgreementError);
            transitionCommutes = isequal(qForward, qReverse) ...
                && isequal(qForward, qBatch);

            projectedRateIndices = ...
                obj.Schema.Leg.RateIndices(legIndices);
            untouched = setdiff(1:obj.Schema.State.Dimension, ...
                projectedRateIndices);
            projectionIsolationError = ...
                Quadrupedal_Dynamics_v3.maxAbs( ...
                    xBatch(untouched) - xminus(untouched));
            perEventIsolationError = zeros(numel(ids), 1);
            for index = 1:numel(ids)
                allowed = obj.Schema.Leg.RateIndices(legIndices(index));
                other = setdiff(1:obj.Schema.State.Dimension, allowed);
                perEventIsolationError(index) = ...
                    Quadrupedal_Dynamics_v3.maxAbs( ...
                        trace.states_after{index}(other) ...
                        - trace.states_before{index}(other));
            end
            projectionVerified = projectionIsolationError <= tolerance ...
                && all(perEventIsolationError <= tolerance);
            resetCommutes = resetError <= tolerance;
            if ~(resetCommutes && transitionCommutes && projectionVerified)
                error('Quadrupedal_Dynamics_v3:NoncommutingIndependentResets', ...
                    ['Distinct-leg reset projections failed their commuting ', ...
                     'independence check.']);
            end

            xplus = obj.validateState(xBatch);
            qplus = obj.validateMode(qBatch);
            batchInfo = struct( ...
                'semantics', "commuting-independent-leg-resets", ...
                'atomic', true, ...
                'fallback', false, ...
                'event_ids', ids, ...
                'event_names', string(obj.Schema.Event.Names(ids)).', ...
                'event_count', numel(ids), ...
                'leg_indices', legIndices, ...
                'state_before', xminus, ...
                'state_after', xplus, ...
                'mode_before', qminus, ...
                'mode_after', qplus, ...
                'event_states_before', {trace.states_before}, ...
                'event_states_after', {trace.states_after}, ...
                'event_modes_before', {trace.modes_before}, ...
                'event_modes_after', {trace.modes_after}, ...
                'commutativity_checked', true, ...
                'tested_event_orders', {{ids, reverseIds}}, ...
                'reset_order_commutes', resetCommutes, ...
                'transition_order_commutes', transitionCommutes, ...
                'commutativity_error', resetError, ...
                'commutativity_tolerance', tolerance, ...
                'forward_reverse_error', forwardReverseError, ...
                'batch_map_agreement_error', batchAgreementError, ...
                'projected_rate_indices', projectedRateIndices(:), ...
                'projection_isolation_error', projectionIsolationError, ...
                'per_event_projection_isolation_error', ...
                    perEventIsolationError, ...
                'independent_rate_projection_verified', ...
                    projectionVerified);
        end

        function qAdjacent = adjacentMode(obj, eventId, q)
            % The contact charts adjacent across either TD or LO differ only
            % in the event leg. This model-owned inverse/forward adjacency
            % lets a contact event cross the section without all-mode search.
            qAdjacent = obj.validateMode(q);
            [legIndex, ~] = obj.Schema.eventLegKind(eventId);
            qAdjacent(legIndex) = ~qAdjacent(legIndex);
            qAdjacent = obj.validateMode(qAdjacent);
        end

        function diagnostics = admissibilityReport(obj, x, q, p, ...
                context, contextData)
            %ADMISSIBILITYREPORT Return model-owned physical margins.
            if nargin < 5 || isempty(context)
                context = 'accepted-state';
            end
            if nargin < 6
                contextData = struct();
            end
            diagnostics = obj.ContinuousDynamicsComponent.admissibilityReport( ...
                x, q, p, context, contextData);
        end

        function diagnostics = assertAdmissible(obj, x, q, p, ...
                context, contextData)
            if nargin < 5 || isempty(context)
                context = 'accepted-state';
            end
            if nargin < 6
                contextData = struct();
            end
            diagnostics = obj.ContinuousDynamicsComponent.assertAdmissible( ...
                x, q, p, context, contextData);
        end

        function modes = modeCandidates(obj, varargin)
            % Compatibility method for explicit exhaustive mode searches.
            % Production root solving should use a local section-mode resolver.
            if numel(varargin) > 3
                error('Quadrupedal_Dynamics_v3:InvalidCandidateInput', ...
                    'modeCandidates accepts at most x, q, and p.');
            elseif numel(varargin) == 3
                obj.validateState(varargin{1});
                obj.validateMode(varargin{2});
                obj.validateParameter(varargin{3});
            elseif numel(varargin) == 2
                obj.validateState(varargin{1});
                obj.validateMode(varargin{2});
            elseif isscalar(varargin) && ~isempty(varargin{1})
                value = varargin{1};
                if isnumeric(value) || islogical(value)
                    if numel(value) == obj.Schema.State.Dimension
                        obj.validateState(value);
                    elseif numel(value) == obj.Schema.Leg.Count
                        obj.validateMode(value);
                    else
                        error('Quadrupedal_Dynamics_v3:InvalidCandidateInput', ...
                            ['Single input must match the schema state ', ...
                             'dimension or leg-count mode dimension.']);
                    end
                end
            end
            modes = obj.ModeTransitionComponent.allModes();
        end

        function x = validateState(obj, x)
            x = obj.Schema.validateState(x);
        end

        function p = validateParameter(obj, p)
            p = obj.Schema.validateParameter(p);
        end

        function q = validateMode(obj, q)
            q = obj.Schema.validateMode(q);
        end

        function catalog = eventCatalog(obj)
            catalog = obj.Schema.eventCatalog();
        end

        function metadata = schemaMetadata(obj)
            metadata = obj.Schema.metadata();
        end

        function components = components(obj)
            components = struct( ...
                'continuous_dynamics', obj.ContinuousDynamicsComponent, ...
                'admissibility', ...
                    obj.ContinuousDynamicsComponent.AdmissibilityComponent, ...
                'guards', obj.GuardFunctionsComponent, ...
                'reset_map', obj.ResetMapComponent, ...
                'mode_transition', obj.ModeTransitionComponent);
        end
    end

    methods (Access = private)
        function ids = normalizeEventIds(obj, eventIds)
            if ischar(eventIds) || ...
                    (isstring(eventIds) && isscalar(eventIds))
                raw = {eventIds};
            elseif iscell(eventIds)
                raw = eventIds(:);
            elseif isstring(eventIds)
                raw = num2cell(eventIds(:));
            elseif isnumeric(eventIds) || islogical(eventIds)
                raw = num2cell(eventIds(:));
            else
                error('Quadrupedal_Dynamics_v3:InvalidEventBatch', ...
                    'Event IDs must be supplied as IDs or event names.');
            end
            ids = zeros(numel(raw), 1);
            for index = 1:numel(raw)
                ids(index) = obj.Schema.eventId(raw{index});
            end
        end

        function [xwork, qwork, trace] = applySequentialBatch(obj, ids, ...
                t, xminus, qminus, p)
            count = numel(ids);
            trace = struct( ...
                'states_before', {cell(count, 1)}, ...
                'states_after', {cell(count, 1)}, ...
                'modes_before', {cell(count, 1)}, ...
                'modes_after', {cell(count, 1)});
            xwork = xminus;
            qwork = qminus;
            for index = 1:count
                trace.states_before{index} = xwork;
                trace.modes_before{index} = qwork;
                xwork = obj.reset(ids(index), t, xwork, qwork, p);
                qwork = obj.transition(ids(index), qwork);
                trace.states_after{index} = xwork;
                trace.modes_after{index} = qwork;
            end
        end

        function installComponents(obj, components)
            if ~isstruct(components) || ~isscalar(components)
                error('Quadrupedal_Dynamics_v3:InvalidComponents', ...
                    'Components must be supplied as a scalar structure.');
            end
            fields = { ...
                'ContinuousDynamicsComponent', ...
                'GuardFunctionsComponent', ...
                'ResetMapComponent', ...
                'ModeTransitionComponent'};
            aliases = { ...
                'continuous_dynamics', ...
                'guards', ...
                'reset_map', ...
                'mode_transition'};
            requiredMethods = { ...
                {'evaluate', 'assertAdmissible'}, ...
                {'descriptors', 'attachFlowDerivatives'}, ...
                {'apply'}, ...
                {'apply', 'allModes'}};

            for i = 1:numel(fields)
                if isfield(components, fields{i})
                    component = components.(fields{i});
                elseif isfield(components, aliases{i})
                    component = components.(aliases{i});
                else
                    continue;
                end
                methodsForRuntime = requiredMethods{i};
                missing = methodsForRuntime(~cellfun( ...
                    @(name) ismethod(component, name), methodsForRuntime));
                if ~isempty(missing)
                    error('Quadrupedal_Dynamics_v3:InvalidComponents', ...
                        '%s must provide runtime method(s): %s.', ...
                        fields{i}, strjoin(missing, ', '));
                end
                obj.(fields{i}) = component;
            end
        end
    end

    methods (Static, Access = private)
        function value = maxAbs(values)
            if isempty(values)
                value = 0;
            else
                value = max(abs(values(:)));
            end
        end
    end
end
