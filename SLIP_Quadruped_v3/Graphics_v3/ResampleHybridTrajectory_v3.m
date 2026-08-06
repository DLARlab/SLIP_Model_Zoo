function [frames, report] = ResampleHybridTrajectory_v3(source, varargin)
%RESAMPLEHYBRIDTRAJECTORY_V3 Uniform right-continuous animation samples.
%   FRAMES = RESAMPLEHYBRIDTRAJECTORY_V3(SOURCE) accepts HybridOrbit_v3 or
%   Trajectory_v3.  Duplicate reset times are retained semantically: an
%   exact frame uses the final (right-continuous) sample, whereas intervals
%   adjacent to the event interpolate only along their own smooth segment.
%
%   Name-value options:
%     FrameRate            positive frames per unit time (default 30)
%     TimeStep             overrides 1/FrameRate when nonempty
%     PreserveEventFrames  include exact physical-event times (default true)

parser = inputParser;
parser.FunctionName = 'ResampleHybridTrajectory_v3';
addParameter(parser, 'FrameRate', 30, ...
    @(v) isscalar(v) && isfinite(v) && v > 0);
addParameter(parser, 'TimeStep', [], ...
    @(v) isempty(v) || (isscalar(v) && isfinite(v) && v > 0));
addParameter(parser, 'PreserveEventFrames', true, ...
    @(v) islogical(v) && isscalar(v));
parse(parser, varargin{:});
options = parser.Results;

[trajectory, ~] = GraphicsDataAdapter_v3.unpack(source, []);
sourceTime = trajectory.time(:);
sourceState = trajectory.state;
sourceMode = GraphicsDataAdapter_v3.modeMatrix(trajectory);
if isempty(options.TimeStep)
    dt = 1 / options.FrameRate;
else
    dt = options.TimeStep;
end
t0 = sourceTime(1);
tf = sourceTime(end);
frameTime = (t0:dt:tf).';
if isempty(frameTime) || frameTime(end) < tf
    frameTime(end + 1, 1) = tf;
end

eventTimes = zeros(0, 1);
if options.PreserveEventFrames && ~isempty(trajectory.event_history)
    history = trajectory.event_history;
    if isfield(history, 'is_stop')
        history = history(~[history.is_stop]);
    end
    eventTimes = [history.time].';
    tolerance = 64 * eps(max(1, max(abs(sourceTime))));
    eventTimes = eventTimes(eventTimes >= t0-tolerance & ...
                            eventTimes <= tf+tolerance);
    frameTime = sort([frameTime; eventTimes]);
end
timeTolerance = 64 * eps(max(1, max(abs(frameTime))));
frameTime = localUniqueTolerance(frameTime, timeTolerance);

uniqueTime = unique(sourceTime, 'stable');
firstIndex = zeros(numel(uniqueTime), 1);
lastIndex = zeros(numel(uniqueTime), 1);
for k = 1:numel(uniqueTime)
    atTime = find(abs(sourceTime - uniqueTime(k)) <= timeTolerance);
    firstIndex(k) = atTime(1);
    lastIndex(k) = atTime(end);
end

nFrames = numel(frameTime);
frameState = zeros(nFrames, size(sourceState, 2));
frameMode = zeros(nFrames, size(sourceMode, 2));
sourceBrackets = zeros(nFrames, 2);
for k = 1:nFrames
    currentTime = frameTime(k);
    exact = find(abs(uniqueTime - currentTime) <= timeTolerance, 1, 'last');
    if ~isempty(exact)
        index = lastIndex(exact); % right-continuous reset convention
        frameState(k, :) = sourceState(index, :);
        frameMode(k, :) = sourceMode(index, :);
        sourceBrackets(k, :) = [index, index];
        continue
    end
    left = find(uniqueTime < currentTime, 1, 'last');
    right = find(uniqueTime > currentTime, 1, 'first');
    if isempty(left)
        left = 1;
    end
    if isempty(right)
        right = numel(uniqueTime);
    end
    leftIndex = lastIndex(left);     % post-reset state at left boundary
    rightIndex = firstIndex(right);  % pre-reset state at right boundary
    denominator = uniqueTime(right) - uniqueTime(left);
    if denominator <= 0
        weight = 0;
    else
        weight = (currentTime - uniqueTime(left)) / denominator;
    end
    frameState(k, :) = (1-weight) * sourceState(leftIndex, :) + ...
        weight * sourceState(rightIndex, :);
    frameMode(k, :) = sourceMode(leftIndex, :);
    sourceBrackets(k, :) = [leftIndex, rightIndex];
end

eventMask = false(nFrames, 1);
for k = 1:numel(eventTimes)
    eventMask = eventMask | abs(frameTime - eventTimes(k)) <= timeTolerance;
end
frames = struct( ...
    'time', frameTime, ...
    'state', frameState, ...
    'mode', logical(frameMode), ...
    'is_event_frame', eventMask, ...
    'source_brackets', sourceBrackets, ...
    'right_continuous', true);
report = struct( ...
    'frame_rate', 1 / dt, ...
    'time_step', dt, ...
    'source_sample_count', numel(sourceTime), ...
    'frame_count', nFrames, ...
    'duplicate_source_times', numel(sourceTime) - numel(uniqueTime), ...
    'preserved_event_times', eventTimes, ...
    'interpolates_across_resets', false);
end

function values = localUniqueTolerance(values, tolerance)
values = sort(values(:));
if isempty(values)
    return
end
keep = true(size(values));
for k = 2:numel(values)
    if abs(values(k) - values(find(keep(1:k-1), 1, 'last'))) <= tolerance
        keep(k) = false;
    end
end
values = values(keep);
end
