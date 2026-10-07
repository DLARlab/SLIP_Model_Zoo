classdef BipedalHybridModel_v3 < HybridSystemBase_v3
    %BIPEDALHYBRIDMODEL_V3 Minimal dissipative alternating-leg hopper.
    %
    % The model is deliberately small, but it is a genuine event-driven
    % hybrid system rather than a quadruped adapter.  Its state is
    %
    %   x = [y; dy]
    %
    % and its parameter vector is
    %
    %   p = [g; k; c; e_td; J_lo].
    %
    % Modes 0/2 are flight with the left/right leg next, and modes 1/3 are
    % left/right stance.  Touchdown dissipates vertical speed by e_td,
    % stance contains viscous damping c, and liftoff supplies impulse J_lo.
    % Thus the periodic orbit is non-energy-conservative.  A complete
    % biped stride contains one touchdown and liftoff of each leg.

    properties (Constant)
        LEFT_FLIGHT = 0
        LEFT_STANCE = 1
        RIGHT_FLIGHT = 2
        RIGHT_STANCE = 3

        LEFT_TOUCHDOWN = 1
        LEFT_LIFTOFF = 2
        RIGHT_TOUCHDOWN = 3
        RIGHT_LIFTOFF = 4
    end

    methods
        function obj = BipedalHybridModel_v3()
            metadata = struct( ...
                'StateDimension', 2, ...
                'ParameterDimension', 5, ...
                'ModeSet', (0:3).', ...
                'StateNames', {{'y', 'dy'}}, ...
                'ParameterNames', {{ ...
                    'gravity', 'stance_stiffness', 'stance_damping', ...
                    'touchdown_velocity_factor', 'liftoff_impulse'}}, ...
                'PhaseIndex', 2, ...
                'DefaultUnknownIndices', [1, 2], ...
                'DefaultPeriodicIndices', 1, ...
                'DefaultTangentIndices', 1);
            obj@HybridSystemBase_v3(metadata);
        end

        function dx = flow(obj, t, x, q, p) %#ok<INUSD>
            x = obj.validateState(x);
            obj.validateMode(q);
            p = obj.validateParameter(p);
            if obj.isFlight(q)
                acceleration = -p(1);
            else
                acceleration = -p(1) - p(2) * x(1) - p(3) * x(2);
            end
            dx = [x(2); acceleration];
        end

        function guards = activeGuards(obj, t, x, q, p) %#ok<INUSD>
            x = obj.validateState(x);
            q = obj.validateMode(q);
            obj.validateParameter(p);
            [eventId, name, direction, legIndex, kind] = ...
                obj.activeEvent(q);
            legName = BipedalHybridModel_v3.legName(legIndex);
            guards = struct( ...
                'id', eventId, ...
                'name', name, ...
                'value', x(1), ...
                'direction', direction, ...
                'isterminal', true, ...
                'terminal', true, ...
                'enabled', true, ...
                'leg_index', legIndex, ...
                'leg_name', legName, ...
                'kind', kind, ...
                'priority', eventId, ...
                'source', 'biped-contact', ...
                'interior_sign', -direction, ...
                'directional_derivative', x(2), ...
                'metadata', struct( ...
                    'leg_index', legIndex, ...
                    'leg_name', legName, ...
                    'event_kind', kind, ...
                    'source', 'biped-contact'));
        end

        function guards = guardFunctions(obj, t, x, q, p)
            % One guard is enabled in every mode; expose it to local chart
            % resolution without importing a quadruped guard catalog.
            guards = obj.activeGuards(t, x, q, p);
        end

        function xplus = reset(obj, eventId, t, xminus, qminus, p) %#ok<INUSD>
            xminus = obj.validateState(xminus);
            qminus = obj.validateMode(qminus);
            p = obj.validateParameter(p);
            obj.requireActiveEvent(eventId, qminus);
            xplus = xminus;
            xplus(1) = 0;
            if eventId == obj.LEFT_TOUCHDOWN || ...
                    eventId == obj.RIGHT_TOUCHDOWN
                xplus(2) = p(4) * xminus(2);
            else
                xplus(2) = xminus(2) + p(5);
            end
            xplus = obj.validateState(xplus);
        end

        function qplus = transition(obj, eventId, qminus)
            qminus = obj.validateMode(qminus);
            obj.requireActiveEvent(eventId, qminus);
            switch eventId
                case obj.LEFT_TOUCHDOWN
                    qplus = obj.LEFT_STANCE;
                case obj.LEFT_LIFTOFF
                    qplus = obj.RIGHT_FLIGHT;
                case obj.RIGHT_TOUCHDOWN
                    qplus = obj.RIGHT_STANCE;
                case obj.RIGHT_LIFTOFF
                    qplus = obj.LEFT_FLIGHT;
                otherwise
                    error('BipedalHybridModel_v3:UnknownEvent', ...
                        'Unknown event identifier %g.', double(eventId));
            end
            qplus = obj.validateMode(qplus);
        end

        function qAdjacent = adjacentMode(obj, eventId, q)
            % Section-near chart resolution may cross a contact guard in
            % either direction, so return the opposite chart of that leg.
            obj.validateMode(q);
            switch eventId
                case obj.LEFT_TOUCHDOWN
                    qAdjacent = obj.LEFT_STANCE;
                case obj.LEFT_LIFTOFF
                    qAdjacent = obj.RIGHT_FLIGHT;
                case obj.RIGHT_TOUCHDOWN
                    qAdjacent = obj.RIGHT_STANCE;
                case obj.RIGHT_LIFTOFF
                    qAdjacent = obj.LEFT_FLIGHT;
                otherwise
                    error('BipedalHybridModel_v3:UnknownEvent', ...
                        'Unknown event identifier %g.', double(eventId));
            end
            qAdjacent = obj.validateMode(qAdjacent);
        end

        function p = validateParameter(obj, p)
            p = validateParameter@HybridSystemBase_v3(obj, p);
            if p(1) <= 0 || p(2) <= 0 || p(3) < 0 || ...
                    p(4) <= 0 || p(4) > 1 || p(5) < 0
                error('BipedalHybridModel_v3:InvalidParameter', ...
                    ['Require g>0, k>0, c>=0, 0<e_td<=1, and ', ...
                     'J_lo>=0.']);
            end
        end

        function section = apexSection(~)
            section = PoincareSection_v3.apex(2, struct( ...
                'Name', 'Apex', ...
                'ValueTolerance', 1e-10, ...
                'DerivativeTolerance', 1e-10));
        end

        function policy = strideReturnPolicy(~)
            policy = BipedStrideReturnPolicy_v3();
        end

        function metadata = schemaMetadata(obj)
            metadata = struct( ...
                'model', class(obj), ...
                'state_dimension', obj.StateDimension, ...
                'parameter_dimension', obj.ParameterDimension, ...
                'state_names', {obj.StateNames}, ...
                'parameter_names', {obj.ParameterNames}, ...
                'mode_meaning', {{ ...
                    'left-flight', 'left-stance', ...
                    'right-flight', 'right-stance'}}, ...
                'leg_order', {{'L', 'R'}}, ...
                'nonconservative_mechanisms', {{ ...
                    'touchdown velocity loss', ...
                    'viscous stance damping', ...
                    'liftoff push impulse'}});
        end
    end

    methods (Static)
        function p = defaultParameters()
            p = [9.81; 400; 3; 0.85; 0.8];
        end

        function x = defaultApexGuess()
            x = [0.12; 0];
        end
    end

    methods (Access = private)
        function tf = isFlight(obj, q)
            tf = q == obj.LEFT_FLIGHT || q == obj.RIGHT_FLIGHT;
        end

        function [eventId, name, direction, legIndex, kind] = ...
                activeEvent(obj, q)
            switch double(q)
                case obj.LEFT_FLIGHT
                    eventId = obj.LEFT_TOUCHDOWN;
                    name = 'L_TD';
                    direction = -1;
                    legIndex = 1;
                    kind = 'touchdown';
                case obj.LEFT_STANCE
                    eventId = obj.LEFT_LIFTOFF;
                    name = 'L_LO';
                    direction = 1;
                    legIndex = 1;
                    kind = 'liftoff';
                case obj.RIGHT_FLIGHT
                    eventId = obj.RIGHT_TOUCHDOWN;
                    name = 'R_TD';
                    direction = -1;
                    legIndex = 2;
                    kind = 'touchdown';
                case obj.RIGHT_STANCE
                    eventId = obj.RIGHT_LIFTOFF;
                    name = 'R_LO';
                    direction = 1;
                    legIndex = 2;
                    kind = 'liftoff';
                otherwise
                    error('BipedalHybridModel_v3:InvalidMode', ...
                        'Unknown discrete mode.');
            end
        end

        function requireActiveEvent(obj, eventId, q)
            [expected, ~, ~, ~, ~] = obj.activeEvent(q);
            if ~(isnumeric(eventId) && isscalar(eventId) ...
                    && isfinite(eventId) && eventId == expected)
                error('BipedalHybridModel_v3:InconsistentEvent', ...
                    'Event is inconsistent with the active biped mode.');
            end
        end
    end

    methods (Static, Access = private)
        function name = legName(index)
            if index == 1
                name = 'L';
            else
                name = 'R';
            end
        end
    end
end
