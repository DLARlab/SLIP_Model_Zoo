function handles = DrawQuadrupedOscillators_v3(source, target)
%DRAWQUADRUPEDOSCILLATORS_V3 v2 GUI phase circles from native contact events.
% One circle per leg in the v2 GUI quadrants, with touchdown/liftoff rays and
% every recorded stance interval. Angles represent cycle time, not leg angle.
% The v2 GUI's FR-touchdown phase offset is retained; unlike its packed
% single-event format, all events of a multi-contact primitive cycle are shown.
    if nargin < 2, target = []; end
    schema = QuadrupedSchema_v3();
    phase = ComputePhaseDiagram_v3(source);
    [axesHandles, fig] = GraphicsDataAdapter_v3.axesFromTarget(target, 1, 'on');
    ax = axesHandles(1); cla(ax); hold(ax, 'on');
    pos = 10; radius = 4; width = 1.5;
    centers = zeros(schema.Leg.Count, 2);
    for leg = 1:schema.Leg.Count
        centers(leg, 1) = pos * (2*endsWith(schema.Leg.Names{leg}, 'R')-1);
        centers(leg, 2) = pos * (2*schema.Leg.FrontMask(leg)-1);
    end
    firstFR = find(phase.event_leg_indices == find(strcmp(schema.Leg.Names, 'FR')) & phase.event_is_touchdown, 1);
    offset = 0;
    if ~isempty(firstFR), offset = 2*pi*phase.event_times(firstFR)/phase.period; end
    colors = contactColors(phase, schema);
    handles = struct('Axes', ax, 'Figure', fig, 'Center', centers, 'Radius', radius, ...
        'PhaseOffset', offset, 'Period', phase.period, 'StartTime', phase.start_time, ...
        'Phase', phase, 'Colors', colors, 'Cycle', gobjects(4, 1), ...
        'Base', gobjects(4, 1), 'TD', {cell(4, 1)}, 'LO', {cell(4, 1)}, ...
        'Stance', {cell(4, 1)}, 'TextTD', gobjects(4, 1), 'TextLO', gobjects(4, 1), ...
        'Labels', gobjects(4, 1), 'Markers', gobjects(4, 1));
    plot(ax, [0, 0], [-2*pos, 2*pos], 'k-', 'LineWidth', 0.5*width, 'HitTest', 'off');
    plot(ax, [-2*pos, 2*pos], [0, 0], 'k-', 'LineWidth', 0.5*width, 'HitTest', 'off');
    theta = linspace(0, 2*pi, 500);
    for leg = 1:schema.Leg.Count
        center = centers(leg, :); name = schema.Leg.Names{leg};
        handles.Cycle(leg) = plot(ax, center(1)+radius*cos(theta), center(2)+radius*sin(theta), ...
            'Color', colors(leg, :), 'LineWidth', width, 'HitTest', 'off');
        handles.Base(leg) = plot(ax, [center(1), center(1)], [center(2), center(2)+radius], ...
            '--', 'Color', [0.8, 0.8, 0.8], 'LineWidth', width, 'HitTest', 'off');
        intervals = phase.stance_intervals{leg};
        handles.Stance{leg} = gobjects(size(intervals, 1), 1);
        for k = 1:size(intervals, 1)
            arc = linspace(2*pi*intervals(k, 1)/phase.period+offset, ...
                2*pi*intervals(k, 2)/phase.period+offset, 100);
            handles.Stance{leg}(k) = patch(ax, [center(1), center(1)+radius*cos(arc), center(1)], ...
                [center(2), center(2)+radius*sin(arc), center(2)], [0.8, 0.8, 0.8], ...
                'EdgeColor', 'none', 'HitTest', 'off');
        end
        touchdown = phase.event_times(phase.event_leg_indices == leg & phase.event_is_touchdown);
        liftoff = phase.event_times(phase.event_leg_indices == leg & ~phase.event_is_touchdown);
        handles.TD{leg} = eventRays(ax, center, radius, touchdown, phase.period, offset, 'r', width);
        handles.LO{leg} = eventRays(ax, center, radius, liftoff, phase.period, offset, 'b', width);
        handles.TextTD(leg) = text(ax, center(1)-0.8*radius, center(2)-1.5*radius, ...
            sprintf('%s TD: %s', name, timeList(touchdown/phase.period)), 'FontSize', 10, 'HitTest', 'off');
        handles.TextLO(leg) = text(ax, center(1)-0.8*radius, center(2)-2.2*radius, ...
            sprintf('%s LO: %s', name, timeList(liftoff/phase.period)), 'FontSize', 10, 'HitTest', 'off');
        handles.Labels(leg) = text(ax, center(1), center(2)+1.35*radius, name, ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'HitTest', 'off');
        handles.Markers(leg) = scatter(ax, center(1)+radius*cos(offset), center(2)+radius*sin(offset), ...
            35, colors(leg, :), 'filled', 'HitTest', 'off');
    end
    title(ax, 'Oscillator Cycles');
    xlim(ax, [-2*pos, 2*pos]); ylim(ax, [-2*pos, 2*pos]);
    pbaspect(ax, [1, 1, 1]); ax.XTick = []; ax.YTick = []; ax.Box = 'on';
end
function rays = eventRays(ax, center, radius, times, period, offset, color, width)
    rays = gobjects(numel(times), 1);
    for k = 1:numel(times)
        angle = 2*pi*times(k)/period+offset;
        rays(k) = plot(ax, [center(1), center(1)+radius*cos(angle)], ...
            [center(2), center(2)+radius*sin(angle)], [color, '-'], 'LineWidth', width, 'HitTest', 'off');
    end
end
function value = timeList(times)
    if isempty(times), value = 'none'; else, value = strjoin(compose('%.2f', times), ', '); end
end
function colors = contactColors(phase, schema)
    colors = zeros(4, 3);
    pairs = {'FR', 'FL', [0.929, 0.694, 0.125]; 'BL', 'BR', [0.85, 0.325, 0.098]; ...
        'FR', 'BL', [1, 1, 0]; 'FR', 'BR', [1, 1, 0]; 'FL', 'BL', [1, 1, 0]; 'FL', 'BR', [1, 1, 0]};
    for k = 1:size(pairs, 1)
        a = find(strcmp(schema.Leg.Names, pairs{k, 1})); b = find(strcmp(schema.Leg.Names, pairs{k, 2}));
        ta = phase.event_times(phase.event_leg_indices == a); tb = phase.event_times(phase.event_leg_indices == b);
        ka = phase.event_is_touchdown(phase.event_leg_indices == a); kb = phase.event_is_touchdown(phase.event_leg_indices == b);
        if ~isempty(ta) && isequal(size(ta), size(tb)) && isequal(ka, kb) && all(abs(ta-tb) < 0.02)
            colors([a, b], :) = repmat(pairs{k, 3}, 2, 1);
        end
    end
end
