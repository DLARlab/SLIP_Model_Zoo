classdef ArmingAuditSystem_v3
    % Focused event-callback audit model; never used as quadruped evidence.
    properties
        Duration=Inf
    end
    methods
        function obj=ArmingAuditSystem_v3(duration)
            if nargin>0,obj.Duration=duration;end
        end
        function f = flow(obj, t, x, ~, ~)
            if isfinite(obj.Duration)
                f=(2*t-obj.Duration)*ones(size(x));
            else
                f = -ones(size(x));
            end
        end
        function g = activeGuards(~, ~, x, ~, ~)
            g = struct('id', 1, 'name', 'audit-zero', 'value', x(1), ...
                'direction', 1, 'isterminal', true, 'enabled', true);
        end
    end
end
