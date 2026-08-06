classdef GraphicsDataAdapter_v3
    %GRAPHICSDATAADAPTER_V3 Normalize orbit/trajectory graphics inputs.
    %   This class is intentionally a data adapter, not a legacy packed-P
    %   adapter.  Contact is read from recorded MODE samples and events from
    %   EVENT_HISTORY.

    methods (Static)
        function [trajectory, parameter, orbit] = unpack(source, parameter)
            if nargin < 2
                parameter = [];
            end
            orbit = [];
            if isa(source, 'HybridOrbit_v3')
                orbit = source;
                trajectory = source.trajectory;
                if isempty(parameter)
                    parameter = source.parameter;
                end
            elseif isa(source, 'Trajectory_v3')
                trajectory = source;
            else
                error('GraphicsDataAdapter_v3:InvalidSource', ...
                    'Source must be a HybridOrbit_v3 or Trajectory_v3.');
            end
            if ~isa(trajectory, 'Trajectory_v3')
                error('GraphicsDataAdapter_v3:MissingTrajectory', ...
                    'The supplied orbit does not contain a Trajectory_v3.');
            end
            if isempty(trajectory.time) || isempty(trajectory.state)
                error('GraphicsDataAdapter_v3:EmptyTrajectory', ...
                    'The trajectory must contain time and state samples.');
            end
            if size(trajectory.state, 2) ~= QuadrupedSchema_v3().State.Dimension
                error('GraphicsDataAdapter_v3:StateDimension', ...
                    'Graphics require the v3 quadruped state dimension.');
            end
            if ~isempty(parameter)
                parameter = GraphicsDataAdapter_v3.parameterVector(parameter);
            end
        end

        function p = parameterVector(parameter)
            if isnumeric(parameter)
                p = double(parameter(:));
            elseif ismethod(parameter, 'toVector')
                p = double(parameter.toVector());
                p = p(:);
            else
                candidates = {'Vector', 'vector', 'Values', 'values'};
                p = [];
                for k = 1:numel(candidates)
                    if isprop(parameter, candidates{k})
                        p = double(parameter.(candidates{k}));
                        p = p(:);
                        break
                    end
                end
                if isempty(p)
                    error('GraphicsDataAdapter_v3:InvalidParameterSet', ...
                        ['Parameter input must be a numeric vector or expose ' ...
                         'toVector(), Vector, or Values.']);
                end
            end
            schema = QuadrupedSchema_v3();
            if numel(p) ~= schema.Parameter.Dimension
                error('GraphicsDataAdapter_v3:ParameterDimension', ...
                    'Expected the ten-parameter v3 quadruped schema.');
            end
        end

        function modes = modeMatrix(trajectory)
            n = numel(trajectory.time);
            raw = trajectory.mode;
            schema = QuadrupedSchema_v3();
            if isnumeric(raw) || islogical(raw)
                modes = double(raw);
                if isvector(modes) && n == 1
                    modes = reshape(modes, 1, []);
                elseif size(modes, 1) ~= n && size(modes, 2) == n
                    modes = modes.';
                end
            elseif iscell(raw)
                modes = zeros(n, schema.Leg.Count);
                if numel(raw) ~= n
                    error('GraphicsDataAdapter_v3:ModeCount', ...
                        'Trajectory mode count does not match its samples.');
                end
                for k = 1:n
                    q = raw{k};
                    modes(k, :) = reshape(double(q), 1, []);
                end
            else
                error('GraphicsDataAdapter_v3:ModeType', ...
                    'Quadruped graphics require numeric or logical modes.');
            end
            if ~isequal(size(modes), [n, schema.Leg.Count]) || ...
                    any(~ismember(modes(:), [0, 1]))
                error('GraphicsDataAdapter_v3:InvalidModes', ...
                    ['Mode history must have one binary column per leg ', ...
                     'in schema order.']);
            end
        end

        function q = rightContinuousModeAt(trajectory, time)
            modes = GraphicsDataAdapter_v3.modeMatrix(trajectory);
            tolerance = 64 * eps(max(1, max(abs(trajectory.time))));
            index = find(trajectory.time <= time + tolerance, 1, 'last');
            if isempty(index)
                index = 1;
            end
            q = modes(index, :).';
        end

        function [eventHistory, startTime, period, initialMode] = ...
                cycleData(source)
            [trajectory, ~, orbit] = GraphicsDataAdapter_v3.unpack(source, []);
            if ~isempty(orbit) && ~isempty(orbit.event_history)
                eventHistory = orbit.event_history;
            else
                eventHistory = trajectory.event_history;
            end
            if ~isempty(eventHistory) && isfield(eventHistory, 'is_stop')
                eventHistory = eventHistory(~[eventHistory.is_stop]);
            end
            startTime = trajectory.time(1);
            if ~isempty(orbit) && isfinite(orbit.period) && orbit.period > 0
                period = orbit.period;
            else
                period = trajectory.time(end) - startTime;
            end
            if ~(isfinite(period) && period > 0)
                error('GraphicsDataAdapter_v3:InvalidPeriod', ...
                    'A positive accepted-cycle period is required.');
            end
            if ~isempty(orbit) && ~isempty(orbit.initial_mode)
                initialMode = double(orbit.initial_mode(:));
            else
                initialMode = GraphicsDataAdapter_v3.rightContinuousModeAt( ...
                    trajectory, startTime);
            end
        end

        function [axesHandles, figures] = axesFromTarget(target, count, visible)
            if nargin < 3 || isempty(visible)
                visible = 'on';
            end
            if nargin < 2
                count = 1;
            end
            if isempty(target)
                figures = figure('Visible', visible, 'Color', 'w');
                axesHandles = GraphicsDataAdapter_v3.createAxes(figures, count);
                return
            end
            if numel(target) == count && all(isgraphics(target)) && ...
                    all(arrayfun(@(h) strcmp(h.Type, 'axes'), target(:)))
                axesHandles = target(:);
                figures = ancestor(axesHandles(1), 'figure');
                return
            end
            if isscalar(target) && isgraphics(target, 'figure')
                figures = target;
                axesHandles = GraphicsDataAdapter_v3.createAxes(figures, count);
                return
            end
            if count == 1 && isscalar(target) && isgraphics(target) && ...
                    strcmp(target.Type, 'axes')
                axesHandles = target;
                figures = ancestor(target, 'figure');
                return
            end
            error('GraphicsDataAdapter_v3:InvalidTarget', ...
                'Target must be a Figure/UIFigure or the required Axes/UIAxes.');
        end
    end

    methods (Static, Access = private)
        function axesHandles = createAxes(fig, count)
            delete(findall(fig, 'Type', 'axes'));
            axesHandles = gobjects(count, 1);
            margin = 0.08;
            gap = 0.05;
            height = (1 - 2 * margin - (count - 1) * gap) / count;
            for k = 1:count
                bottom = 1 - margin - k * height - (k - 1) * gap;
                position = [0.10, bottom, 0.85, height];
                try
                    axesHandles(k) = axes('Parent', fig, 'Position', position);
                catch
                    axesHandles(k) = uiaxes('Parent', fig, 'Position', position);
                end
            end
        end
    end
end
