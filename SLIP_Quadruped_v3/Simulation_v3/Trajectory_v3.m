classdef Trajectory_v3 < handle
    %TRAJECTORY_V3 Piecewise-smooth trajectory and hybrid-event record.
    %
    % Time samples immediately before and after a reset are both retained.
    % Consequently, TIME may contain repeated entries at jump times.  MODE
    % is numeric when the supplied modes have a fixed numeric shape and is
    % otherwise a cell array, which keeps the container usable for general
    % discrete state spaces.

    properties
        time = zeros(0, 1)
        state = zeros(0, 0)
        mode = cell(0, 1)

        event_type = strings(0, 1)
        event_time = zeros(0, 1)
        event_history

        termination_reason = "not_terminated"
        termination_time = NaN
        termination_state = []
        termination_mode = []
        termination_metadata = struct()
        termination = struct()
        metadata = struct()
    end

    methods
        function obj = Trajectory_v3(time, state, mode)
            obj.event_history = Trajectory_v3.emptyEventHistory();
            obj.termination = Trajectory_v3.makeTermination( ...
                "not_terminated", NaN, [], [], struct());

            if nargin > 0 && ~isempty(time)
                if nargin < 3
                    error('Trajectory_v3:MissingMode', ...
                        'TIME, STATE, and MODE must be supplied together.');
                end
                obj.appendSegment(time, state, mode);
            end
        end

        function appendSegment(obj, time, state, mode)
            %APPENDSEGMENT Append a continuous segment with constant mode.
            [time, state] = Trajectory_v3.normalizeSamples(time, state);
            if isempty(time)
                return;
            end
            modeRows = Trajectory_v3.repeatMode(mode, numel(time));
            obj.appendRaw(time, state, modeRows);
        end

        function appendSample(obj, time, state, mode)
            %APPENDSAMPLE Append one sample, including a same-time jump.
            obj.appendSegment(time, reshape(state, 1, []), mode);
        end

        function recordEvent(obj, entry)
            %RECORDEVENT Add one guard or stopping-section occurrence.
            entry = Trajectory_v3.normalizeEvent(entry, ...
                numel(obj.event_history) + 1);
            obj.event_history(end + 1, 1) = entry;
            obj.event_type(end + 1, 1) = string(entry.type);
            obj.event_time(end + 1, 1) = entry.time;
        end

        function setTermination(obj, reason, time, state, mode, metadata)
            if nargin < 6 || isempty(metadata)
                metadata = struct();
            end
            obj.termination_reason = string(reason);
            obj.termination_time = time;
            obj.termination_state = state;
            obj.termination_mode = mode;
            obj.termination_metadata = metadata;
            obj.termination = Trajectory_v3.makeTermination( ...
                reason, time, state, mode, metadata);
        end

        function obj = appendTrajectory(obj, other)
            %APPENDTRAJECTORY Concatenate another trajectory in place.
            % Duplicate continuous boundary samples are removed, while
            % same-time samples that encode a reset or mode jump remain.
            if ~isa(other, 'Trajectory_v3')
                error('Trajectory_v3:InvalidTrajectory', ...
                    'OTHER must be a Trajectory_v3 object.');
            end

            if ~isempty(other.time)
                obj.appendRaw(other.time, other.state, other.mode);
            end
            for k = 1:numel(other.event_history)
                entry = other.event_history(k);
                entry.index = numel(obj.event_history) + 1;
                obj.recordEvent(entry);
            end

            if ~isempty(fieldnames(other.metadata))
                obj.metadata = Trajectory_v3.mergeStructs( ...
                    obj.metadata, other.metadata);
            end
            if other.termination_reason ~= "not_terminated"
                obj.setTermination(other.termination_reason, ...
                    other.termination_time, other.termination_state, ...
                    other.termination_mode, other.termination_metadata);
            end
        end
    end

    methods (Static)
        function trajectory = concatenate(varargin)
            %CONCATENATE Return the concatenation of supplied trajectories.
            trajectory = Trajectory_v3();
            for k = 1:nargin
                trajectory.appendTrajectory(varargin{k});
            end
        end

        function history = emptyEventHistory()
            prototype = struct( ...
                'index', 0, ...
                'type', "", ...
                'time', NaN, ...
                'guard_id', [], ...
                'guard_name', "", ...
                'state_before', [], ...
                'state_after', [], ...
                'mode_before', [], ...
                'mode_after', [], ...
                'value', NaN, ...
                'directional_derivative', NaN, ...
                'priority', NaN, ...
                'is_stop', false, ...
                'metadata', struct());
            history = repmat(prototype, 0, 1);
        end
    end

    methods (Access = private)
        function appendRaw(obj, time, state, modeRows)
            [time, state] = Trajectory_v3.normalizeSamples(time, state);
            modeRows = Trajectory_v3.normalizeModeRows(modeRows, numel(time));
            if isempty(time)
                return;
            end

            first = 1;
            if ~isempty(obj.time) && ...
                    Trajectory_v3.sameTime(obj.time(end), time(1)) && ...
                    Trajectory_v3.sameState(obj.state(end, :), state(1, :)) && ...
                    Trajectory_v3.sameMode( ...
                        Trajectory_v3.modeAt(obj.mode, size(obj.state, 1)), ...
                        Trajectory_v3.modeAt(modeRows, 1))
                first = 2;
            end
            if first > numel(time)
                return;
            end

            if isempty(obj.state)
                obj.state = state(first:end, :);
            else
                if size(obj.state, 2) ~= size(state, 2)
                    error('Trajectory_v3:StateDimensionMismatch', ...
                        'Appended state dimension does not match trajectory.');
                end
                obj.state = [obj.state; state(first:end, :)];
            end
            obj.time = [obj.time; time(first:end)];
            obj.mode = Trajectory_v3.concatenateModes( ...
                obj.mode, Trajectory_v3.sliceModes(modeRows, first:numel(time)));
        end
    end

    methods (Static, Access = private)
        function [time, state] = normalizeSamples(time, state)
            time = time(:);
            if isempty(time)
                state = zeros(0, 0);
                return;
            end
            if isvector(state) && isscalar(time)
                state = reshape(state, 1, []);
            elseif size(state, 1) ~= numel(time) && ...
                    size(state, 2) == numel(time)
                state = state.';
            end
            if size(state, 1) ~= numel(time)
                error('Trajectory_v3:SampleCountMismatch', ...
                    'STATE must have one row for each TIME sample.');
            end
            if any(~isfinite(time)) || any(diff(time) < 0)
                error('Trajectory_v3:InvalidTime', ...
                    'TIME must be finite and nondecreasing.');
            end
        end

        function rows = repeatMode(mode, count)
            if isnumeric(mode) || islogical(mode) || isstring(mode) || ischar(mode)
                if ischar(mode)
                    rows = repmat({mode}, count, 1);
                elseif isstring(mode)
                    rows = repmat(reshape(mode, 1, []), count, 1);
                else
                    rows = repmat(reshape(mode, 1, []), count, 1);
                end
            else
                rows = repmat({mode}, count, 1);
            end
        end

        function rows = normalizeModeRows(rows, count)
            if iscell(rows)
                if isscalar(rows) && count > 1
                    rows = repmat(rows, count, 1);
                else
                    rows = rows(:);
                end
            elseif ischar(rows)
                rows = repmat({rows}, count, 1);
            elseif isvector(rows) && count > 1 && size(rows, 1) ~= count
                rows = repmat(reshape(rows, 1, []), count, 1);
            elseif size(rows, 1) ~= count && size(rows, 2) == count
                rows = rows.';
            end
            if size(rows, 1) ~= count
                error('Trajectory_v3:ModeCountMismatch', ...
                    'MODE must have one row or cell for each TIME sample.');
            end
        end

        function modes = concatenateModes(left, right)
            if isempty(left)
                modes = right;
                return;
            end
            if isempty(right)
                modes = left;
                return;
            end
            if isnumeric(left) && isnumeric(right) && ...
                    size(left, 2) == size(right, 2)
                modes = [left; right];
            elseif islogical(left) && islogical(right) && ...
                    size(left, 2) == size(right, 2)
                modes = [left; right];
            elseif isstring(left) && isstring(right) && ...
                    size(left, 2) == size(right, 2)
                modes = [left; right];
            else
                modes = [Trajectory_v3.modesToCells(left); ...
                    Trajectory_v3.modesToCells(right)];
            end
        end

        function cells = modesToCells(modes)
            if iscell(modes)
                cells = modes(:);
                return;
            end
            cells = cell(size(modes, 1), 1);
            for k = 1:size(modes, 1)
                cells{k} = modes(k, :);
            end
        end

        function value = modeAt(modes, index)
            if iscell(modes)
                value = modes{index};
            else
                value = modes(index, :);
            end
        end

        function modes = sliceModes(modes, indices)
            if iscell(modes)
                modes = modes(indices);
            else
                modes = modes(indices, :);
            end
        end

        function tf = sameTime(a, b)
            tolerance = 64 * eps(max(1, max(abs([a, b]))));
            tf = abs(a - b) <= tolerance;
        end

        function tf = sameState(a, b)
            if numel(a) ~= numel(b)
                tf = false;
                return;
            end
            scale = max(1, max(abs([a(:); b(:)])));
            tf = all(abs(a(:) - b(:)) <= 64 * eps(scale));
        end

        function tf = sameMode(a, b)
            tf = isequaln(a, b);
        end

        function entry = normalizeEvent(entry, index)
            if ~isstruct(entry) || ~isscalar(entry)
                error('Trajectory_v3:InvalidEvent', ...
                    'Event history entries must be scalar structures.');
            end
            defaults = struct( ...
                'index', index, 'type', "", 'time', NaN, ...
                'guard_id', [], 'guard_name', "", ...
                'state_before', [], 'state_after', [], ...
                'mode_before', [], 'mode_after', [], ...
                'value', NaN, 'directional_derivative', NaN, ...
                'priority', NaN, 'is_stop', false, ...
                'metadata', struct());
            names = fieldnames(defaults);
            normalized = defaults;
            for k = 1:numel(names)
                name = names{k};
                if isfield(entry, name)
                    normalized.(name) = entry.(name);
                end
            end
            normalized.index = index;
            if strlength(string(normalized.type)) == 0
                normalized.type = normalized.guard_name;
            end
            normalized.type = string(normalized.type);
            normalized.guard_name = string(normalized.guard_name);
            entry = normalized;
        end

        function termination = makeTermination(reason, time, state, mode, metadata)
            termination = struct( ...
                'reason', string(reason), ...
                'time', time, ...
                'state', state, ...
                'mode', mode, ...
                'metadata', metadata);
        end

        function output = mergeStructs(left, right)
            output = left;
            names = fieldnames(right);
            for k = 1:numel(names)
                output.(names{k}) = right.(names{k});
            end
        end
    end
end
