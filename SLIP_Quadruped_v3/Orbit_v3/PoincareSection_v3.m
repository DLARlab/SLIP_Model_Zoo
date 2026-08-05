classdef PoincareSection_v3
    %POINCARESECTION_V3 Directional section h(x,p)=0 for hybrid flows.
    %   A section is independent of the discrete contact mode.  Crossing
    %   validity is determined from the Lie derivative of h along the
    %   active continuous vector field.

    properties
        Name = 'section'
        ValueFunction
        DerivativeFunction = []
        ProjectionFunction = []
        Direction = -1
        ValueTolerance = 1e-9
        DerivativeTolerance = 1e-10
        MaxProjectionIterations = 10
    end

    methods
        function obj = PoincareSection_v3(valueFunction, options)
            if nargin < 1 || isempty(valueFunction)
                error('PoincareSection_v3:MissingFunction', ...
                    'A section value function h(x,p) is required.');
            end
            obj.ValueFunction = valueFunction;
            if nargin >= 2 && ~isempty(options)
                obj = obj.applyOptions(options);
            end
            if ~ismember(obj.Direction, [-1, 1])
                error('PoincareSection_v3:InvalidDirection', ...
                    'A first-return section must have Direction -1 or +1.');
            end
        end

        function value = value(obj, x, p)
            value = obj.ValueFunction(x(:), p(:));
            if ~isscalar(value) || ~isfinite(value)
                error('PoincareSection_v3:InvalidValue', ...
                    'The section function must return one finite scalar.');
            end
        end

        function dhdt = derivative(obj, t, x, q, p, system)
            if ~isempty(obj.DerivativeFunction)
                dhdt = obj.DerivativeFunction(t, x(:), q, p(:), system);
            else
                x = x(:);
                gradient = zeros(1, numel(x));
                for i = 1:numel(x)
                    step = sqrt(eps) * (1 + abs(x(i)));
                    xp = x;
                    xm = x;
                    xp(i) = xp(i) + step;
                    xm(i) = xm(i) - step;
                    gradient(i) = (obj.value(xp, p) - obj.value(xm, p)) / ...
                        (2 * step);
                end
                dhdt = gradient * system.flow(t, x, q, p);
            end
            if ~isscalar(dhdt) || ~isfinite(dhdt)
                error('PoincareSection_v3:InvalidDerivative', ...
                    'The section Lie derivative must be one finite scalar.');
            end
        end

        function tf = isOnSection(obj, x, p)
            tf = abs(obj.value(x, p)) <= obj.ValueTolerance;
        end

        function tf = isValidCrossing(obj, t, x, q, p, system)
            dhdt = obj.derivative(t, x, q, p, system);
            tf = obj.isOnSection(x, p) && ...
                obj.Direction * dhdt > obj.DerivativeTolerance;
        end

        function projected = project(obj, x, p)
            %PROJECT Retract an ambient state onto h(x,p)=0.
            x = x(:);
            if ~isempty(obj.ProjectionFunction)
                projected = obj.ProjectionFunction(x, p(:));
                projected = projected(:);
                if numel(projected) ~= numel(x)
                    error('PoincareSection_v3:ProjectionDimension', ...
                        'ProjectionFunction changed the state dimension.');
                end
                return
            end

            projected = x;
            for iteration = 1:obj.MaxProjectionIterations
                sectionValue = obj.value(projected, p);
                if abs(sectionValue) <= obj.ValueTolerance
                    return
                end
                gradient = zeros(numel(projected), 1);
                for i = 1:numel(projected)
                    step = sqrt(eps) * (1 + abs(projected(i)));
                    xp = projected;
                    xm = projected;
                    xp(i) = xp(i) + step;
                    xm(i) = xm(i) - step;
                    gradient(i) = (obj.value(xp, p) - obj.value(xm, p)) / ...
                        (2 * step);
                end
                denominator = gradient.' * gradient;
                if denominator <= eps
                    error('PoincareSection_v3:SingularProjection', ...
                        'The section gradient is numerically singular.');
                end
                projected = projected - sectionValue * gradient / denominator;
            end
            if ~obj.isOnSection(projected, p)
                error('PoincareSection_v3:ProjectionFailed', ...
                    'Could not retract the state onto the section.');
            end
        end

        function stop = stopCondition(obj, level, direction)
            %STOPCONDITION Build a simulator-neutral scalar stopping event.
            if nargin < 3 || isempty(direction)
                direction = obj.Direction;
            end
            stop = struct('Function', @(t, x, q, p) ...
                obj.stopOutputs(t, x, q, p, level, direction));
        end
    end

    methods (Static)
        function obj = apex(verticalVelocityIndex, options)
            %APEX Section vy=0 with a downward (ay<0) crossing.
            if nargin < 1 || isempty(verticalVelocityIndex)
                verticalVelocityIndex = 4;
            end
            if nargin < 2
                options = struct();
            end
            defaults = struct( ...
                'Name', 'Apex', ...
                'Direction', -1, ...
                'DerivativeFunction', @(t, x, q, p, system) ...
                    PoincareSection_v3.flowComponent( ...
                        system, t, x, q, p, verticalVelocityIndex), ...
                'ProjectionFunction', @(x, p) ...
                    PoincareSection_v3.setComponent( ...
                        x, verticalVelocityIndex, 0));
            options = PoincareSection_v3.mergeStructs(defaults, options);
            obj = PoincareSection_v3( ...
                @(x, p) x(verticalVelocityIndex), options);
        end
    end

    methods (Access = private)
        function [value, isterminal, direction, metadata] = stopOutputs( ...
                obj, t, x, q, p, level, crossingDirection) %#ok<INUSD>
            value = obj.value(x, p) - level;
            isterminal = true;
            direction = crossingDirection;
            metadata = struct('name', obj.Name, 'level', level);
        end

        function obj = applyOptions(obj, options)
            if ~isstruct(options)
                error('PoincareSection_v3:InvalidOptions', ...
                    'Options must be a structure.');
            end
            fields = fieldnames(options);
            for i = 1:numel(fields)
                name = fields{i};
                if ~isprop(obj, name)
                    error('PoincareSection_v3:UnknownOption', ...
                        'Unknown section option "%s".', name);
                end
                obj.(name) = options.(name);
            end
        end
    end

    methods (Static, Access = private)
        function value = flowComponent(system, t, x, q, p, index)
            flow = system.flow(t, x, q, p);
            value = flow(index);
        end

        function x = setComponent(x, index, value)
            x = x(:);
            x(index) = value;
        end

        function result = mergeStructs(defaults, overrides)
            result = defaults;
            if isempty(overrides)
                return
            end
            names = fieldnames(overrides);
            for i = 1:numel(names)
                result.(names{i}) = overrides.(names{i});
            end
        end
    end
end
