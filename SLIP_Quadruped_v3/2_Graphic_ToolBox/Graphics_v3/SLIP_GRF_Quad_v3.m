% *************************************************************************
% Quadruped ground-reaction-force graphics for SLIP Model Zoo v3.
% Adapted from SLIP_GRF_Quad.m in the v2 graphics toolbox.
% *************************************************************************
classdef SLIP_GRF_Quad_v3 < OutputCLASS_v3
    properties (SetAccess = private)
        fig
        ax
        Lines
        Legend
        Time
        GRF
        Diagnostics
        trajectory
        parameter
        system
    end

    methods
        function obj = SLIP_GRF_Quad_v3(source, parameter, plotTarget, system, varargin)
            if nargin < 2
                parameter = [];
            end
            if nargin < 3
                plotTarget = [];
            end
            if nargin < 4 || isempty(system)
                system = Quadrupedal_Dynamics_v3();
            end
            parser = inputParser;
            addParameter(parser, 'Visible', 'on', ...
                @(v) any(strcmpi(string(v), ["on", "off"])));
            parse(parser, varargin{:});
            [obj.trajectory, obj.parameter] = ...
                GraphicsDataAdapter_v3.unpack(source, parameter);
            if isempty(obj.parameter)
                error('SLIP_GRF_Quad_v3:MissingParameter', ...
                    'A v3 parameter vector or parameter set is required.');
            end
            obj.system = system;
            [axesHandle, obj.fig] = GraphicsDataAdapter_v3.axesFromTarget( ...
                plotTarget, 1, char(parser.Results.Visible));
            obj.ax = axesHandle(1);
            obj.computeGRF();
            obj.initializePlots();
        end

        function update(obj, source, parameter)
            if nargin < 3
                parameter = obj.parameter;
            end
            [obj.trajectory, obj.parameter] = ...
                GraphicsDataAdapter_v3.unpack(source, parameter);
            obj.computeGRF();
            for leg = 1:numel(obj.Lines)
                set(obj.Lines(leg), 'XData', obj.Time, ...
                    'YData', obj.GRF(:, leg));
            end
            xlim(obj.ax, [0, max(obj.Time(end), eps)]);
            localForceLimits(obj.ax, obj.GRF);
        end
    end

    methods (Access = private)
        function computeGRF(obj)
            modes = GraphicsDataAdapter_v3.modeMatrix(obj.trajectory);
            count = numel(obj.trajectory.time);
            schema = QuadrupedSchema_v3();
            obj.Time = obj.trajectory.time - obj.trajectory.time(1);
            obj.GRF = zeros(count, schema.Leg.Count);
            diagnostics = cell(count, 1);
            for k = 1:count
                [~, diagnostic] = obj.system.flow( ...
                    obj.trajectory.time(k), obj.trajectory.state(k, :).', ...
                    modes(k, :).', obj.parameter);
                if ~isfield(diagnostic, 'per_leg_force_vectors')
                    error('SLIP_GRF_Quad_v3:MissingDiagnostics', ...
                        ['Dynamics diagnostics must contain ' ...
                         'per_leg_force_vectors.']);
                end
                forceVectors = diagnostic.per_leg_force_vectors;
                if ~isequal(size(forceVectors), [2, schema.Leg.Count])
                    error('SLIP_GRF_Quad_v3:InvalidDiagnostics', ...
                        ['per_leg_force_vectors must have two rows and ', ...
                         'one column per schema leg.']);
                end
                obj.GRF(k, :) = forceVectors(2, :);
                diagnostics{k} = diagnostic;
            end
            obj.Diagnostics = diagnostics;
        end

        function initializePlots(obj)
            schema = QuadrupedSchema_v3();
            cla(obj.ax);
            hold(obj.ax, 'on');
            grid(obj.ax, 'on');
            colors = lines(schema.Leg.Count);
            styles = repmat({'-'}, 1, schema.Leg.Count);
            styles(endsWith(schema.Leg.Names, 'R')) = {'--'};
            obj.Lines = gobjects(schema.Leg.Count, 1);
            for leg = 1:schema.Leg.Count
                obj.Lines(leg) = plot(obj.ax, obj.Time, obj.GRF(:, leg), ...
                    'LineStyle', styles{leg}, 'Color', colors(leg, :), ...
                    'LineWidth', 1.8);
            end
            obj.Legend = legend(obj.ax, schema.Leg.Names, ...
                'Location', 'best', 'AutoUpdate', 'off');
            xlabel(obj.ax, 'Cycle time');
            ylabel(obj.ax, 'Vertical ground-reaction force');
            title(obj.ax, sprintf('Ground-reaction forces [%s]', ...
                strjoin(schema.Leg.Names, ', ')));
            box(obj.ax, 'on');
            xlim(obj.ax, [0, max(obj.Time(end), eps)]);
            localForceLimits(obj.ax, obj.GRF);
        end
    end
end

function localForceLimits(ax, force)
values = force(isfinite(force));
if isempty(values)
    return
end
minimum = min(values);
maximum = max(values);
padding = max(0.08 * (maximum - minimum), 1e-4);
ylim(ax, [minimum-padding, maximum+padding]);
end
