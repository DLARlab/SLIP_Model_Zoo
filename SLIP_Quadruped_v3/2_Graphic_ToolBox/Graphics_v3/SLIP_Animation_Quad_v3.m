% *************************************************************************
% Two-dimensional quadruped SLIP animation for SLIP Model Zoo v3.
%
% Original attribution retained from SLIP_Animation_Quad.m:
% Created by C. David Remy on 07/10/2011, MATLAB 2010a (Windows, 64 bit).
% Documentation: "A MATLAB Framework For Gait Creation", C. David Remy,
% Keith Buffinton, and Roland Siegwart, IEEE/RSJ IROS, 2011.
% Autonomous Systems Lab, ETH Zurich; Department of Mechanical
% Engineering, Bucknell University.
%
% Adapted for the DLARlab SLIP Model Zoo v3. Contact is taken from the
% recorded hybrid mode; the legacy packed event/parameter vector is not
% supported.
% *************************************************************************
classdef SLIP_Animation_Quad_v3 < OutputCLASS_v3
    properties (SetAccess = private)
        fig
        axes
        Body
        LegHandles
        Leg_BL
        Leg_BR
        Leg_FL
        Leg_FR
        COM
        Ground
        PhaseDiagram
        Title
        options
        trajectory
        parameter
        phaseData
    end

    methods
        function obj = SLIP_Animation_Quad_v3( ...
                source, parameter, plotTarget, options)
            if nargin < 2
                parameter = [];
            end
            if nargin < 3
                plotTarget = [];
            end
            if nargin < 4 || isempty(options)
                options = struct();
            end
            obj.options = localOptions(options);
            obj.rate = 1 / obj.options.FrameRate;
            obj.slowDown = obj.options.SlowDown;
            [obj.trajectory, obj.parameter] = ...
                GraphicsDataAdapter_v3.unpack(source, parameter);
            if isempty(obj.parameter)
                error('SLIP_Animation_Quad_v3:MissingParameter', ...
                    'Animation requires the v3 quadruped parameters.');
            end
            [axesHandle, obj.fig] = GraphicsDataAdapter_v3.axesFromTarget( ...
                plotTarget, 1, obj.options.Visible);
            obj.axes = axesHandle(1);
            if strcmpi(obj.options.AnimationMode, 'Detailed')
                obj.phaseData = ComputePhaseDiagram_v3(source);
            else
                obj.phaseData = struct();
            end
            obj.initializePlots();
        end

        function update(obj, t, x, q, doDraw)
            if nargin < 5
                doDraw = true;
            end
            if ~isgraphics(obj.fig) || ~isgraphics(obj.axes), return; end
            schema = QuadrupedSchema_v3();
            expanded = schema.expandParameters(obj.parameter);
            geometry = ComputeJointLegGeometry_v3(t, x, q, obj.parameter);
            localSetBody(obj.Body, geometry.body_pose, expanded.l_com);
            if ~isempty(obj.COM), localSetCOM(obj.COM, geometry.body_pose); end
            for leg = 1:schema.Leg.Count
                localSetLeg(obj.LegHandles{leg}, ...
                    geometry.hip_positions(:, leg), ...
                    geometry.leg_lengths(leg), ...
                    geometry.rest_lengths(leg), ...
                    geometry.absolute_leg_angles(leg));
            end
            bodyX = geometry.body_position(1);
            bodyY = geometry.body_position(2);
            if strcmpi(obj.options.AnimationMode, 'Detailed')
                localSetPhasePosition(obj.PhaseDiagram, obj.phaseData, ...
                    bodyX, t - obj.trajectory.time(1));
                set(obj.Title, 'Position', [bodyX, bodyY + 0.75, 0]);
            end
            xlim(obj.axes, bodyX + [-1.5, 1.5]);
            ylim(obj.axes, [-0.12, max(2.0, bodyY + 0.9)]);
            if doDraw
                drawnow limitrate nocallbacks;
            end
        end

        function [frames, report] = play(obj, varargin)
            parser = inputParser;
            addParameter(parser, 'VideoFile', obj.options.VideoFile, ...
                @(v) ischar(v) || isstring(v));
            addParameter(parser, 'PreserveEventFrames', ...
                obj.options.PreserveEventFrames, ...
                @(v) islogical(v) && isscalar(v));
            parse(parser, varargin{:});
            [frames, report] = ResampleHybridTrajectory_v3(obj.trajectory, ...
                'FrameRate', obj.options.FrameRate, ...
                'PreserveEventFrames', parser.Results.PreserveEventFrames);

            videoFile = string(parser.Results.VideoFile);
            writer = [];
            if strlength(videoFile) > 0
                videoFile=string(V3OutputPath_v3(videoFile));
                writer = VideoWriter(char(videoFile), 'MPEG-4');
                writer.FrameRate = obj.options.FrameRate;
                open(writer);
                cleanup = onCleanup(@() close(writer));
            end
            wallStart = tic;
            simulationStart = frames.time(1);
            report.played_frame_count = 0;
            report.cancelled = false;
            for k = 1:numel(frames.time)
                if ~isgraphics(obj.fig) || ~isgraphics(obj.axes)
                    report.cancelled = true; break
                end
                obj.update(frames.time(k), frames.state(k, :).', ...
                    frames.mode(k, :).', false);
                drawnow;
                if ~isgraphics(obj.fig) || ~isgraphics(obj.axes)
                    report.cancelled = true; break
                end
                report.played_frame_count = k;
                if ~isempty(writer)
                    writeVideo(writer, getframe(obj.fig));
                end
                if obj.slowDown > 0 && isempty(writer)
                    desired = (frames.time(k)-simulationStart) * obj.slowDown;
                    remaining = desired - toc(wallStart);
                    while remaining > 0 && isgraphics(obj.fig) && isgraphics(obj.axes)
                        pause(min(remaining, 0.05));
                        remaining = desired - toc(wallStart);
                    end
                end
            end
            if ~isgraphics(obj.fig) || ~isgraphics(obj.axes), report.cancelled = true; end
        end
    end

    methods (Access = private)
        function initializePlots(obj)
            schema = QuadrupedSchema_v3();
            expanded = schema.expandParameters(obj.parameter);
            modes = GraphicsDataAdapter_v3.modeMatrix(obj.trajectory);
            geometry = ComputeJointLegGeometry_v3( ...
                obj.trajectory.time(1), obj.trajectory.state(1, :).', ...
                modes(1, :).', obj.parameter);

            cla(obj.axes);
            hold(obj.axes, 'on');
            axis(obj.axes, 'equal');
            axis(obj.axes, 'off');
            obj.LegHandles = cell(schema.Leg.Count, 1);
            % Preserve v2 depth: left legs behind the torso, right legs in
            % front. The numerical state and mode order remains BL BR FL FR.
            leftLegs = find(endsWith(schema.Leg.Names, 'L'));
            rightLegs = find(endsWith(schema.Leg.Names, 'R'));
            for leg = leftLegs
                obj.LegHandles{leg} = localDrawLeg(obj.axes, ...
                    geometry.hip_positions(:, leg), ...
                    geometry.leg_lengths(leg), ...
                    geometry.rest_lengths(leg), ...
                    geometry.absolute_leg_angles(leg));
            end
            obj.Ground = localDrawGround(obj.axes);
            obj.Body = localDrawBody(obj.axes, geometry.body_pose, expanded.l_com);
            if expanded.l_com ~= 0.5
                obj.COM = localDrawCOM(obj.axes, geometry.body_pose);
            else
                obj.COM = [];
            end
            for leg = rightLegs
                obj.LegHandles{leg} = localDrawLeg(obj.axes, ...
                    geometry.hip_positions(:, leg), ...
                    geometry.leg_lengths(leg), ...
                    geometry.rest_lengths(leg), ...
                    geometry.absolute_leg_angles(leg));
            end
            obj.Leg_BL = obj.LegHandles{find( ...
                strcmp('BL', schema.Leg.Names), 1)};
            obj.Leg_BR = obj.LegHandles{find( ...
                strcmp('BR', schema.Leg.Names), 1)};
            obj.Leg_FL = obj.LegHandles{find( ...
                strcmp('FL', schema.Leg.Names), 1)};
            obj.Leg_FR = obj.LegHandles{find( ...
                strcmp('FR', schema.Leg.Names), 1)};
            if strcmpi(obj.options.AnimationMode, 'Detailed')
                obj.Title = text(obj.axes, geometry.body_position(1), ...
                    geometry.body_position(2)+0.75, 'SLIP quadruped', ...
                    'FontWeight', 'bold', 'HorizontalAlignment', 'center');
                obj.PhaseDiagram = localDrawPhase(obj.axes, obj.phaseData, ...
                    geometry.body_position(1));
            else
                obj.Title = gobjects(0);
                obj.PhaseDiagram = struct();
            end
            xlim(obj.axes, geometry.body_position(1)+[-1.5, 1.5]);
            ylim(obj.axes, [-0.12, max(2.0, geometry.body_position(2)+0.9)]);
        end
    end
end

function options = localOptions(input)
defaults = struct( ...
    'AnimationMode', 'Simple', ...
    'Visible', 'on', ...
    'FrameRate', 30, ...
    'SlowDown', 0, ...
    'PreserveEventFrames', true, ...
    'VideoFile', '');
if ~isstruct(input) || ~isscalar(input)
    error('SLIP_Animation_Quad_v3:InvalidOptions', ...
        'Options must be a scalar structure.');
end
options = defaults;
names = fieldnames(input);
for k = 1:numel(names)
    if ~isfield(defaults, names{k})
        error('SLIP_Animation_Quad_v3:UnknownOption', ...
            'Unknown animation option "%s".', names{k});
    end
    options.(names{k}) = input.(names{k});
end
if ~any(strcmpi(string(options.AnimationMode), ["Simple", "Detailed"]))
    error('SLIP_Animation_Quad_v3:AnimationMode', ...
        'AnimationMode must be Simple or Detailed.');
end
if ~any(strcmpi(string(options.Visible), ["on", "off"]))
    error('SLIP_Animation_Quad_v3:Visible', ...
        'Visible must be on or off.');
end
if ~(isscalar(options.FrameRate) && isfinite(options.FrameRate) && ...
        options.FrameRate > 0)
    error('SLIP_Animation_Quad_v3:FrameRate', ...
        'FrameRate must be positive and finite.');
end
if ~(isscalar(options.SlowDown) && isfinite(options.SlowDown) && ...
        options.SlowDown >= 0)
    error('SLIP_Animation_Quad_v3:SlowDown', ...
        'SlowDown must be finite and nonnegative.');
end
options.AnimationMode = char(options.AnimationMode);
options.Visible = char(options.Visible);
end

function body = localDrawBody(ax, pose, lCom)
[xData, yData, faces, vertices] = ComputeBodyGraphics_v3(pose, lCom);
body.B_bg = patch(ax, 'XData', xData, 'YData', yData, ...
    'LineStyle', 'none', 'FaceColor', [1, 1, 1]);
body.B_sha = patch(ax, 'Faces', faces, 'Vertices', vertices, ...
    'FaceColor', [1, 1, 1], 'EdgeColor', [0.8, 0.8, 0.8], 'LineWidth', 3);
body.B_out = patch(ax, 'XData', xData, 'YData', yData, ...
    'LineWidth', 4, 'FaceColor', 'none', 'EdgeColor', [0, 0, 0]);
body.background = body.B_bg;
body.stripes = body.B_sha;
body.outline = body.B_out;
end

function localSetBody(body, pose, lCom)
[xData, yData, faces, vertices] = ComputeBodyGraphics_v3(pose, lCom);
set(body.B_bg, 'XData', xData, 'YData', yData);
set(body.B_sha, 'Faces', faces, 'Vertices', vertices);
set(body.B_out, 'XData', xData, 'YData', yData);
end

function leg = localDrawLeg(ax, hip, length, restLength, angle)
[vertices, faces] = ComputeLegGraphics_v3(hip, length, restLength, angle);
springColor = [245, 131, 58] / 256;
leg.L_Sp1 = patch(ax, 'Faces', faces.L_Sp1, 'Vertices', vertices.L_Sp1, ...
    'EdgeColor', springColor, 'LineWidth', 5);
leg.L_UpB = patch(ax, 'Faces', faces.L_UpBO, 'Vertices', vertices.L_UpBO, ...
    'LineStyle', 'none', 'FaceColor', [1, 1, 1]);
leg.L_Ups = patch(ax, 'Faces', faces.L_Ups, 'Vertices', vertices.L_Ups, ...
    'LineWidth', 3, 'FaceColor', 'none', 'EdgeColor', [0.8, 0.8, 0.8]);
leg.L_Upo = patch(ax, 'Faces', faces.L_UpBO, 'Vertices', vertices.L_UpBO, ...
    'LineWidth', 3, 'FaceColor', 'none', 'EdgeColor', [0, 0, 0]);
leg.L_low = patch(ax, 'Faces', faces.L_low, 'Vertices', vertices.L_low, ...
    'LineWidth', 3, 'FaceColor', [1, 1, 1], 'EdgeColor', [0, 0, 0]);
leg.L_Sp2 = patch(ax, 'Faces', faces.L_Sp2, 'Vertices', vertices.L_Sp1, ...
    'EdgeColor', springColor, 'LineWidth', 5);
leg.spring = leg.L_Sp1;
leg.shaft = leg.L_low;
leg.foot = leg.L_low;
end

function localSetLeg(leg, hip, length, restLength, angle)
[vertices, faces] = ComputeLegGraphics_v3(hip, length, restLength, angle);
set(leg.L_Sp1, 'Faces', faces.L_Sp1, 'Vertices', vertices.L_Sp1);
set(leg.L_UpB, 'Faces', faces.L_UpBO, 'Vertices', vertices.L_UpBO);
set(leg.L_Ups, 'Faces', faces.L_Ups, 'Vertices', vertices.L_Ups);
set(leg.L_Upo, 'Faces', faces.L_UpBO, 'Vertices', vertices.L_UpBO);
set(leg.L_low, 'Faces', faces.L_low, 'Vertices', vertices.L_low);
set(leg.L_Sp2, 'Faces', faces.L_Sp2, 'Vertices', vertices.L_Sp1);
end

function com = localDrawCOM(ax, pose)
[outer, innerX, innerY] = localCOMGeometry(pose);
com.B_COMOuter = patch(ax, outer(1, :), outer(2, :), 'white', 'LineWidth', 5);
colors = cat(3, [1, 0, 1, 0], [1, 0, 1, 0], [1, 0, 1, 0]);
com.B_COMInner = patch(ax, innerX, innerY, colors, 'LineWidth', 3);
end

function localSetCOM(com, pose)
[outer, innerX, innerY] = localCOMGeometry(pose);
set(com.B_COMOuter, 'XData', outer(1, :), 'YData', outer(2, :));
set(com.B_COMInner, 'XData', innerX, 'YData', innerY);
end

function [outer, innerX, innerY] = localCOMGeometry(pose)
radius = 0.15;
rotation = [cos(pose(3)), -sin(pose(3)); sin(pose(3)), cos(pose(3))];
alpha = linspace(0, 2*pi, 40);
outer = rotation * [sin(alpha); cos(alpha)] * (radius*0.5) + pose(1:2);
alpha = linspace(0, pi/2, 10);
quarter = [0, sin(alpha)*radius*0.75, 0; 0, cos(alpha)*radius*0.75, 0];
signs = [1, 1; 1, -1; -1, -1; -1, 1];
innerX = zeros(size(quarter, 2), 4); innerY = innerX;
for k = 1:4
    vertices = rotation * (quarter .* signs(k, :).') + pose(1:2);
    innerX(:, k) = vertices(1, :).'; innerY(:, k) = vertices(2, :).';
end
end

function ground = localDrawGround(ax)
% Retain the v2 hatched ground as two reusable patches.
h = 0.01; n = 5000; s = 0.05; w = 0.01; ext = 0.1;
offset = [-50+linspace(0, s*n, n).', zeros(n, 1)];
vertices = [-50, 0; repmat([0, -h], n, 1)+offset; ...
    repmat([-ext, -ext-h], n, 1)+offset; ...
    repmat([-ext+w, -ext-h], n, 1)+offset; ...
    repmat([w, -h], n, 1)+offset; -50+s*n+w, 0];
faces = [1, 2, 4*n+1, 4*n+2; ...
    repmat([0, n, 2*n, 3*n], n, 1)+repmat((1:n).', 1, 4)+1];
ground.ground = patch(ax, [-15, 100, 100, -15], [0, 0, -20, -20], 'white');
ground.lines = patch(ax, 'Faces', faces, 'Vertices', vertices);
end

function handles = localDrawPhase(ax, phase, bodyX)
schema = QuadrupedSchema_v3();
width = 1.2;
origin = bodyX - width/2;
yTop = 1.82;
rowHeight = 0.055;
rowGap = 0.022;
handles.base = gobjects(schema.Leg.Count, 1);
handles.stance = cell(schema.Leg.Count, 1);
handles.text = gobjects(schema.Leg.Count, 1);
for leg = 1:schema.Leg.Count
    y = yTop - (leg-1)*(rowHeight+rowGap);
    localX = [-width/2, width/2, width/2, -width/2];
    handles.base(leg) = patch(ax, bodyX+localX, ...
        [y, y, y+rowHeight, y+rowHeight], [1, 1, 1], ...
        'EdgeColor', [0.4, 0.4, 0.4], 'UserData', localX);
    intervals = phase.stance_intervals{leg};
    handles.stance{leg} = gobjects(size(intervals, 1), 1);
    for k = 1:size(intervals, 1)
        bounds = origin + width * intervals(k, :) / phase.period;
        localBounds = bounds - bodyX;
        localPatchX = localBounds([1, 2, 2, 1]);
        handles.stance{leg}(k) = patch(ax, bodyX+localPatchX, ...
            [y, y, y+rowHeight, y+rowHeight], [0.15, 0.15, 0.15], ...
            'EdgeColor', 'none', 'UserData', localPatchX);
    end
    textOffset = -width/2-0.06;
    handles.text(leg) = text(ax, bodyX+textOffset, y+rowHeight/2, ...
        schema.Leg.Names{leg}, 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle', 'FontSize', 8, ...
        'UserData', textOffset);
end
handles.indicator = line(ax, [bodyX-width/2, bodyX-width/2], ...
    [yTop-3*(rowHeight+rowGap), yTop+rowHeight], ...
    'Color', [0.85, 0.1, 0.1], 'LineWidth', 1.2);
handles.width = width;
end

function localSetPhasePosition(handles, phase, bodyX, relativeTime)
for leg = 1:numel(handles.base)
    set(handles.base(leg), 'XData', bodyX+handles.base(leg).UserData);
    for k = 1:numel(handles.stance{leg})
        patchHandle = handles.stance{leg}(k);
        set(patchHandle, 'XData', bodyX+patchHandle.UserData);
    end
    set(handles.text(leg), 'Position', ...
        [bodyX+handles.text(leg).UserData, handles.text(leg).Position(2), 0]);
end
fraction = mod(max(relativeTime, 0), phase.period) / phase.period;
indicatorX = bodyX - handles.width/2 + handles.width*fraction;
set(handles.indicator, 'XData', [indicatorX, indicatorX]);
end
