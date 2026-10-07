classdef GuardFunctions_v3
    %GUARDFUNCTIONS_V3 Directional touchdown/liftoff guards.
    %
    % Touchdown and liftoff share the uncompressed-leg surface.  The mode
    % and directional crossing select the enabled event.  All leg-valued
    % outputs use [BL BR FL FR] order from QuadrupedSchema_v3.

    properties (SetAccess = private)
        Schema
    end

    methods
        function obj = GuardFunctions_v3(schema)
            if nargin < 1 || isempty(schema)
                schema = QuadrupedSchema_v3.shared();
            end
            if ~isa(schema, 'QuadrupedSchema_v3')
                error('GuardFunctions_v3:InvalidSchema', ...
                    'Schema must be a QuadrupedSchema_v3 instance.');
            end
            obj.Schema = schema;
        end

        function guards = descriptors(obj, t, x, q, p) %#ok<INUSD>
            [x, q, p] = obj.validateInputs(x, q, p);
            legValues = obj.legValues(x, p);
            legDerivatives = obj.legDirectionalDerivatives(x, p);
            catalog = obj.Schema.eventCatalog();

            template = struct( ...
                'id', 0, ...
                'name', '', ...
                'value', 0, ...
                'direction', 0, ...
                'isterminal', true, ...
                'terminal', true, ...
                'enabled', false, ...
                'leg_index', 0, ...
                'leg_name', '', ...
                'kind', '', ...
                'priority', 0, ...
                'source', 'contact', ...
                'interior_sign', 0, ...
                'directional_derivative', NaN, ...
                'metadata', struct());
            guards = repmat(template, obj.Schema.Event.Count, 1);

            for id = obj.Schema.Event.IDs
                legIndex = catalog(id).leg_index;
                isTouchdown = obj.Schema.Event.IsTouchdown(id);
                guards(id).id = id;
                guards(id).name = catalog(id).name;
                guards(id).value = legValues(legIndex);
                guards(id).direction = catalog(id).direction;
                guards(id).enabled = (isTouchdown && ~q(legIndex)) ...
                    || (~isTouchdown && q(legIndex));
                guards(id).leg_index = legIndex;
                guards(id).leg_name = catalog(id).leg_name;
                guards(id).kind = catalog(id).kind;
                guards(id).priority = catalog(id).priority;
                guards(id).interior_sign = -catalog(id).direction;
                guards(id).directional_derivative = ...
                    legDerivatives(legIndex);
                guards(id).metadata = struct( ...
                    'leg_index', legIndex, ...
                    'leg_name', catalog(id).leg_name, ...
                    'event_kind', catalog(id).kind, ...
                    'source', 'contact');
            end
        end

        function guards = active(obj, t, x, q, p)
            guards = obj.descriptors(t, x, q, p);
            guards = guards([guards.enabled]);
        end

        function guards = attachFlowDerivatives(obj, guards, x, dxdt, p)
            %ATTACHFLOWDERIVATIVES Store the true Lie derivative Dg*F.
            % Stance flow can project a stored leg rate onto the fixed-foot
            % constraint, so the state derivative—not necessarily the raw
            % rate coordinate—must be used for guard transversality.
            derivatives = obj.legLieDerivatives(x, dxdt, p);
            for id = obj.Schema.Event.IDs
                legIndex = obj.Schema.Event.LegIndices(id);
                guards(id).directional_derivative = ...
                    derivatives(legIndex);
            end
        end

        function [value, isterminal, direction, enabled, guards] = ...
                evaluate(obj, t, x, q, p)
            guards = obj.descriptors(t, x, q, p);
            value = reshape([guards.value], [], 1);
            isterminal = reshape([guards.isterminal], [], 1);
            direction = reshape([guards.direction], [], 1);
            enabled = reshape([guards.enabled], [], 1);
        end

        function values = legValues(obj, x, p)
            [x, ~, p] = obj.validateInputs( ...
                x, false(obj.Schema.Leg.Count, 1), p);
            expanded = obj.Schema.expandParameters(p);
            state = obj.Schema.State;
            alpha = x(obj.Schema.Leg.AngleIndices);
            values = x(state.y) + expanded.s .* sin(x(state.phi)) ...
                - expanded.l_0 .* cos(x(state.phi) + alpha);
        end

        function derivatives = legDirectionalDerivatives(obj, x, p)
            [x, ~, p] = obj.validateInputs( ...
                x, false(obj.Schema.Leg.Count, 1), p);
            expanded = obj.Schema.expandParameters(p);
            state = obj.Schema.State;
            alpha = x(obj.Schema.Leg.AngleIndices);
            dalpha = x(obj.Schema.Leg.RateIndices);
            phi = x(state.phi);
            dphi = x(state.dphi);
            derivatives = x(state.dy) ...
                + expanded.s .* cos(phi) .* dphi ...
                + expanded.l_0 .* sin(phi + alpha) ...
                    .* (dphi + dalpha);
        end


        function derivatives = legLieDerivatives(obj, x, dxdt, p)
            [x, ~, p] = obj.validateInputs( ...
                x, false(obj.Schema.Leg.Count, 1), p);
            dxdt = obj.Schema.validateState(dxdt);
            expanded = obj.Schema.expandParameters(p);
            state = obj.Schema.State;
            alpha = x(obj.Schema.Leg.AngleIndices);
            phi = x(state.phi);
            derivatives = dxdt(state.y) ...
                + expanded.s .* cos(phi) .* dxdt(state.phi) ...
                + expanded.l_0 .* sin(phi + alpha) ...
                    .* (dxdt(state.phi) ...
                        + dxdt(obj.Schema.Leg.AngleIndices));
        end
    end

    methods (Access = private)
        function [x, q, p] = validateInputs(obj, x, q, p)
            x = obj.Schema.validateState(x);
            q = obj.Schema.validateMode(q);
            p = obj.Schema.validateParameter(p);
        end
    end
end
