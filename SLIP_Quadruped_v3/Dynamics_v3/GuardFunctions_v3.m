classdef GuardFunctions_v3
    %GUARDFUNCTIONS_V3 Directional quadruped touchdown/liftoff guards.
    %
    % Touchdown and liftoff for a leg share the zero-compression surface.
    % Discrete mode and crossing direction determine which event is enabled.

    methods
        function guards = descriptors(obj, t, x, q, p) %#ok<INUSD>
            [x, q, p] = GuardFunctions_v3.validateInputs(x, q, p);
            legValues = obj.legValues(x, p);
            transition = ModeTransition_v3();
            catalog = transition.eventCatalog();

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
            guards = repmat(template, 8, 1);

            for id = 1:8
                legIndex = catalog(id).leg_index;
                isTouchdown = strcmp(catalog(id).kind, 'touchdown');
                guards(id).id = id;
                guards(id).name = catalog(id).name;
                guards(id).value = legValues(legIndex);
                guards(id).direction = catalog(id).direction;
                guards(id).isterminal = true;
                guards(id).terminal = true;
                guards(id).enabled = (isTouchdown && ~q(legIndex)) ...
                    || (~isTouchdown && q(legIndex));
                guards(id).leg_index = legIndex;
                guards(id).leg_name = catalog(id).leg_name;
                guards(id).kind = catalog(id).kind;
                guards(id).priority = catalog(id).priority;
                guards(id).interior_sign = -catalog(id).direction;
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

        function [value, isterminal, direction, enabled, guards] = ...
                evaluate(obj, t, x, q, p)
            guards = obj.descriptors(t, x, q, p);
            value = reshape([guards.value], [], 1);
            isterminal = reshape([guards.isterminal], [], 1);
            direction = reshape([guards.direction], [], 1);
            enabled = reshape([guards.enabled], [], 1);
        end

        function values = legValues(~, x, p)
            [x, ~, p] = GuardFunctions_v3.validateInputs( ...
                x, false(4, 1), p);
            restLength = p(4);
            lb = p(6);
            y = x(3);
            phi = x(5);
            alpha = x([7, 9, 11, 13]);
            offsets = [-lb; 1 - lb; -lb; 1 - lb];
            values = y + offsets .* sin(phi) ...
                - restLength .* cos(phi + alpha);
        end

        function derivatives = legDirectionalDerivatives(~, x, p)
            [x, ~, p] = GuardFunctions_v3.validateInputs( ...
                x, false(4, 1), p);
            restLength = p(4);
            lb = p(6);
            dy = x(4);
            phi = x(5);
            dphi = x(6);
            alpha = x([7, 9, 11, 13]);
            dalpha = x([8, 10, 12, 14]);
            offsets = [-lb; 1 - lb; -lb; 1 - lb];
            derivatives = dy + offsets .* cos(phi) .* dphi ...
                + restLength .* sin(phi + alpha) .* (dphi + dalpha);
        end
    end

    methods (Static, Access = private)
        function [x, q, p] = validateInputs(x, q, p)
            if ~(isnumeric(x) && isreal(x) && isvector(x) ...
                    && numel(x) == 14 && all(isfinite(x(:))))
                error('GuardFunctions_v3:InvalidState', ...
                    'Quadruped state must be a finite real 14-vector.');
            end
            if ~(isnumeric(p) && isreal(p) && isvector(p) && numel(p) == 7 ...
                    && all(isfinite(p([1, 2, 4, 5, 6, 7]))) ...
                    && (isfinite(p(3)) || isinf(p(3))))
                error('GuardFunctions_v3:InvalidParameter', ...
                    'Quadruped parameter must be a real 7-vector.');
            end
            x = double(x(:));
            p = double(p(:));
            q = ModeTransition_v3.validateModeVector(q);
        end
    end
end
