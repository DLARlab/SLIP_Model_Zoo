% *************************************************************************
% Quadruped state-trajectory graphics for SLIP Model Zoo v3.
% Adapted from SLIP_Trajectories_Quad.m in the v2 graphics toolbox.
% *************************************************************************
classdef SLIP_Trajectories_Quad_v3 < OutputCLASS_v3
    properties (SetAccess = private)
        figs
        axes
        Lines
        Legends
        trajectory
    end

    methods
        function obj = SLIP_Trajectories_Quad_v3(source, plotTarget, varargin)
            if nargin < 2
                plotTarget = [];
            end
            parser = inputParser;
            addParameter(parser, 'Visible', 'on', ...
                @(v) any(strcmpi(string(v), ["on", "off"])));
            parse(parser, varargin{:});
            [obj.trajectory, ~] = GraphicsDataAdapter_v3.unpack(source, []);
            [obj.axes, obj.figs] = GraphicsDataAdapter_v3.axesFromTarget( ...
                plotTarget, 3, char(parser.Results.Visible));
            obj.initializePlots();
        end

        function update(obj, source, updateTorso, updateLegs)
            if nargin < 3
                updateTorso = true;
            end
            if nargin < 4
                updateLegs = true;
            end
            [newTrajectory, ~] = GraphicsDataAdapter_v3.unpack(source, []);
            obj.trajectory = newTrajectory;
            schema = QuadrupedSchema_v3();
            time = newTrajectory.time - newTrajectory.time(1);
            state = newTrajectory.state;
            torsoIndices = [schema.State.dx, schema.State.y, ...
                schema.State.dy, schema.State.phi, schema.State.dphi];
            backIndices = localLegIndices(schema, schema.Leg.BackMask);
            frontIndices = localLegIndices(schema, schema.Leg.FrontMask);
            if updateTorso
                localSetLines(obj.Lines{1}, time, state(:, torsoIndices));
            end
            if updateLegs
                localSetLines(obj.Lines{2}, time, state(:, backIndices));
                localSetLines(obj.Lines{3}, time, state(:, frontIndices));
            end
            for k = 1:3
                xlim(obj.axes(k), [0, max(time(end), eps)]);
            end
        end
    end

    methods (Access = private)
        function initializePlots(obj)
            schema = QuadrupedSchema_v3();
            time = obj.trajectory.time - obj.trajectory.time(1);
            state = obj.trajectory.state;
            torsoIndices = [schema.State.dx, schema.State.y, ...
                schema.State.dy, schema.State.phi, schema.State.dphi];
            backLegs = find(schema.Leg.BackMask);
            frontLegs = find(schema.Leg.FrontMask);
            backIndices = localLegIndices(schema, schema.Leg.BackMask);
            frontIndices = localLegIndices(schema, schema.Leg.FrontMask);

            for k = 1:3
                cla(obj.axes(k));
                hold(obj.axes(k), 'on');
                grid(obj.axes(k), 'on');
                box(obj.axes(k), 'on');
            end
            obj.Lines = cell(3, 1);
            obj.Legends = gobjects(3, 1);
            obj.Lines{1} = plot(obj.axes(1), time, state(:, torsoIndices), ...
                'LineWidth', 1.25);
            obj.Legends(1) = legend(obj.axes(1), ...
                schema.State.Names(torsoIndices), ...
                'Location', 'best', 'AutoUpdate', 'off');
            title(obj.axes(1), 'Torso trajectories');

            obj.Lines{2} = plot(obj.axes(2), time, state(:, backIndices), ...
                'LineWidth', 1.25);
            obj.Legends(2) = legend(obj.axes(2), ...
                localLegLabels(schema, backLegs), ...
                'Location', 'best', 'AutoUpdate', 'off');
            title(obj.axes(2), 'Back-leg trajectories');

            obj.Lines{3} = plot(obj.axes(3), time, state(:, frontIndices), ...
                'LineWidth', 1.25);
            obj.Legends(3) = legend(obj.axes(3), ...
                localLegLabels(schema, frontLegs), ...
                'Location', 'best', 'AutoUpdate', 'off');
            title(obj.axes(3), 'Front-leg trajectories');

            for k = 1:3
                xlabel(obj.axes(k), 'Cycle time');
                xlim(obj.axes(k), [0, max(time(end), eps)]);
                localPaddedLimits(obj.axes(k));
            end
        end
    end
end

function indices = localLegIndices(schema, mask)
legs = find(mask);
indices = zeros(1, 2 * numel(legs));
for k = 1:numel(legs)
    indices(2*k-1:2*k) = [schema.Leg.AngleIndices(legs(k)), ...
        schema.Leg.RateIndices(legs(k))];
end
end

function labels = localLegLabels(schema, legs)
labels = cell(1, 2 * numel(legs));
for k = 1:numel(legs)
    name = schema.Leg.Names{legs(k)};
    labels{2*k-1} = ['alpha', name];
    labels{2*k} = ['dalpha', name];
end
end

function localSetLines(linesHandle, time, values)
for k = 1:numel(linesHandle)
    set(linesHandle(k), 'XData', time, 'YData', values(:, k));
end
end

function localPaddedLimits(ax)
linesHandle = findall(ax, 'Type', 'line');
allValues = zeros(0, 1);
for k = 1:numel(linesHandle)
    values = linesHandle(k).YData;
    allValues = [allValues; values(:)]; %#ok<AGROW>
end
allValues = allValues(isfinite(allValues));
if isempty(allValues)
    return
end
minimum = min(allValues);
maximum = max(allValues);
padding = max(0.05 * (maximum - minimum), 1e-4);
ylim(ax, [minimum-padding, maximum+padding]);
end
