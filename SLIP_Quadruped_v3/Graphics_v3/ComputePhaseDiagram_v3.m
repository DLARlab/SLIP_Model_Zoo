function phase = ComputePhaseDiagram_v3(source, target, varargin)
%COMPUTEPHASEDIAGRAM_V3 Event-derived stance intervals for one full cycle.
%   PHASE = COMPUTEPHASEDIAGRAM_V3(SOURCE) consumes the recorded physical
%   EVENT_HISTORY and accepted full-cycle period.  Supplying an Axes/UIAxes
%   in TARGET additionally draws the diagram.  No event-time parameter
%   vector or gait label is accepted.
%
%   Adapted from ComputePhaseDiagram.m in the v2 graphics toolbox.

if nargin < 2
    target = [];
end
parser = inputParser;
addParameter(parser, 'ClearAxes', true, ...
    @(v) islogical(v) && isscalar(v));
parse(parser, varargin{:});

schema = QuadrupedSchema_v3();
[history, startTime, period, initialMode] = ...
    GraphicsDataAdapter_v3.cycleData(source);
intervals = cell(schema.Leg.Count, 1);
active = logical(initialMode(:));
activeStart = zeros(schema.Leg.Count, 1);

eventNames = strings(0, 1);
eventTimes = zeros(0, 1);
eventLegs = zeros(0, 1);
eventIsTouchdown = false(0, 1);
for k = 1:numel(history)
    name = localEventName(history(k), schema);
    catalogIndex = find(strcmp(schema.Event.Names, char(name)), 1);
    if isempty(catalogIndex)
        continue
    end
    relativeTime = history(k).time - startTime;
    tolerance = 1e-10 * max(1, period);
    if relativeTime < -tolerance || relativeTime > period + tolerance
        continue
    end
    relativeTime = min(period, max(0, relativeTime));
    eventNames(end + 1, 1) = name; %#ok<AGROW>
    eventTimes(end + 1, 1) = relativeTime; %#ok<AGROW>
    eventLegs(end + 1, 1) = schema.Event.LegIndices(catalogIndex); %#ok<AGROW>
    eventIsTouchdown(end + 1, 1) = ...
        schema.Event.IsTouchdown(catalogIndex); %#ok<AGROW>
end

if ~isempty(eventTimes)
    [~, order] = sortrows([eventTimes, (1:numel(eventTimes)).'], [1, 2]);
    eventNames = eventNames(order);
    eventTimes = eventTimes(order);
    eventLegs = eventLegs(order);
    eventIsTouchdown = eventIsTouchdown(order);
end
for k = 1:numel(eventTimes)
    leg = eventLegs(k);
    if eventIsTouchdown(k)
        if ~active(leg)
            active(leg) = true;
            activeStart(leg) = eventTimes(k);
        end
    elseif active(leg)
        intervals{leg}(end + 1, :) = [activeStart(leg), eventTimes(k)];
        active(leg) = false;
    end
end
for leg = 1:schema.Leg.Count
    if active(leg)
        intervals{leg}(end + 1, :) = [activeStart(leg), period];
    end
end

phase = struct( ...
    'source', "event_history", ...
    'period', period, ...
    'start_time', startTime, ...
    'leg_names', {schema.Leg.Names}, ...
    'initial_mode', logical(initialMode(:)), ...
    'stance_intervals', {intervals}, ...
    'event_names', eventNames, ...
    'event_times', eventTimes, ...
    'event_leg_indices', eventLegs, ...
    'event_is_touchdown', eventIsTouchdown, ...
    'handles', struct());

if ~isempty(target)
    if ~(isscalar(target) && isgraphics(target) && strcmp(target.Type, 'axes'))
        error('ComputePhaseDiagram_v3:InvalidTarget', ...
            'TARGET must be an Axes or UIAxes.');
    end
    if parser.Results.ClearAxes
        cla(target);
    end
    hold(target, 'on');
    base = gobjects(schema.Leg.Count, 1);
    bars = cell(schema.Leg.Count, 1);
    colors = lines(schema.Leg.Count);
    for leg = 1:schema.Leg.Count
        y = schema.Leg.Count - leg + 1;
        base(leg) = patch(target, [0, period, period, 0], ...
            [y-0.35, y-0.35, y+0.35, y+0.35], [0.94, 0.94, 0.94], ...
            'EdgeColor', [0.65, 0.65, 0.65]);
        bars{leg} = gobjects(size(intervals{leg}, 1), 1);
        for interval = 1:size(intervals{leg}, 1)
            bounds = intervals{leg}(interval, :);
            bars{leg}(interval) = patch(target, ...
                bounds([1, 2, 2, 1]), ...
                [y-0.35, y-0.35, y+0.35, y+0.35], colors(leg, :), ...
                'EdgeColor', 'none');
        end
    end
    target.YTick = 1:schema.Leg.Count;
    target.YTickLabel = schema.Leg.Names(end:-1:1);
    target.YLim = [0.4, schema.Leg.Count + 0.6];
    target.XLim = [0, period];
    xlabel(target, 'Cycle time');
    ylabel(target, 'Leg');
    title(target, 'Event-derived contact phases');
    grid(target, 'on');
    box(target, 'on');
    phase.handles = struct('base', base, 'stance', {bars});
end
end

function name = localEventName(entry, schema)
name = "";
if isfield(entry, 'guard_name') && ...
        any(strcmp(schema.Event.Names, char(string(entry.guard_name))))
    name = string(entry.guard_name);
elseif isfield(entry, 'type') && ...
        any(strcmp(schema.Event.Names, char(string(entry.type))))
    name = string(entry.type);
end
end
