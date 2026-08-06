% *************************************************************************
% Reduced periodic-orbit graphics for SLIP Model Zoo v3.
% Adapted from SLIP_PeriodicOrbit_Quad.m in the v2 graphics toolbox.
% *************************************************************************
classdef SLIP_PeriodicOrbit_Quad_v3 < OutputCLASS_v3
    properties (SetAccess = private)
        fig
        axes
        Orbit
        Poincare_Section
        Current_Position
        Text
        trajectory
    end

    methods
        function obj = SLIP_PeriodicOrbit_Quad_v3(source, plotTarget, varargin)
            if nargin < 2
                plotTarget = [];
            end
            parser = inputParser;
            addParameter(parser, 'Color', [0.85, 0.33, 0.10], ...
                @(v) isnumeric(v) && numel(v) == 3 && all(isfinite(v)));
            addParameter(parser, 'Visible', 'on', ...
                @(v) any(strcmpi(string(v), ["on", "off"])));
            parse(parser, varargin{:});
            [obj.trajectory, ~] = GraphicsDataAdapter_v3.unpack(source, []);
            [axesHandle, obj.fig] = GraphicsDataAdapter_v3.axesFromTarget( ...
                plotTarget, 1, char(parser.Results.Visible));
            obj.axes = axesHandle(1);
            obj.initializePlots(parser.Results.Color);
        end

        function update(obj, state)
            schema = QuadrupedSchema_v3();
            state = state(:);
            set(obj.Current_Position, ...
                'XData', state(schema.State.dx), ...
                'YData', state(schema.State.dy), ...
                'ZData', state(schema.State.dphi));
        end
    end

    methods (Access = private)
        function initializePlots(obj, markerColor)
            schema = QuadrupedSchema_v3();
            state = obj.trajectory.state;
            dx = state(:, schema.State.dx);
            dy = state(:, schema.State.dy);
            dphi = state(:, schema.State.dphi);
            [dxLimits, dyLimits, dphiLimits] = deal( ...
                localLimits(dx), localLimits(dy), localLimits(dphi));

            cla(obj.axes);
            hold(obj.axes, 'on');
            obj.Orbit = plot3(obj.axes, dx, dy, dphi, ...
                'LineWidth', 1.8, 'Color', [0, 0, 0]);
            obj.Poincare_Section = patch(obj.axes, ...
                'XData', dxLimits([1, 2, 2, 1]), ...
                'YData', [0, 0, 0, 0], ...
                'ZData', dphiLimits([1, 1, 2, 2]), ...
                'FaceColor', [0.7, 0.7, 0.7], ...
                'FaceAlpha', 0.25, 'EdgeColor', 'none');
            obj.Current_Position = scatter3(obj.axes, dx(1), dy(1), ...
                dphi(1), 80, markerColor, 'filled');
            obj.Text = text(obj.axes, dxLimits(1), 0, dphiLimits(2), ...
                'Poincare section: dy=0', 'VerticalAlignment', 'top');
            xlabel(obj.axes, 'dx');
            ylabel(obj.axes, 'dy');
            zlabel(obj.axes, 'dphi');
            title(obj.axes, 'Hybrid periodic orbit');
            xlim(obj.axes, dxLimits);
            ylim(obj.axes, dyLimits);
            zlim(obj.axes, dphiLimits);
            grid(obj.axes, 'on');
            box(obj.axes, 'on');
            view(obj.axes, 45, 30);
        end
    end
end

function limits = localLimits(values)
minimum = min(values);
maximum = max(values);
padding = max(0.1 * (maximum - minimum), 1e-3);
limits = [minimum-padding, maximum+padding];
end
