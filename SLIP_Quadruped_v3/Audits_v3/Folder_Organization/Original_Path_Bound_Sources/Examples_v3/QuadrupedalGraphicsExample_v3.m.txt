function output = QuadrupedalGraphicsExample_v3(source, varargin)
%QUADRUPEDALGRAPHICSEXAMPLE_V3 Display every v3 quadruped graphic.
%   OUTPUT = QUADRUPEDALGRAPHICSEXAMPLE_V3(ORBIT) opens an animation,
%   torso/leg trajectories, ground-reaction forces, the reduced periodic
%   orbit, and an event-derived phase diagram.  SOURCE may alternatively be
%   a Trajectory_v3 when 'Parameter' is supplied.
%
%   No interactive dialogs are used.  Set 'Visible','off' and
%   'PlayAnimation',false for batch or headless execution.

parser = inputParser;
addParameter(parser, 'Parameter', [], @(v) true);
addParameter(parser, 'Visible', 'on', ...
    @(v) any(strcmpi(string(v), ["on", "off"])));
addParameter(parser, 'PlayAnimation', true, ...
    @(v) islogical(v) && isscalar(v));
addParameter(parser, 'AnimationMode', 'Detailed', ...
    @(v) any(strcmpi(string(v), ["Simple", "Detailed"])));
addParameter(parser, 'FrameRate', 30, ...
    @(v) isscalar(v) && isfinite(v) && v > 0);
addParameter(parser, 'VideoFile', '', ...
    @(v) ischar(v) || isstring(v));
parse(parser, varargin{:});
options = parser.Results;

graphicsRoot = fileparts(fileparts(mfilename('fullpath')));
originalPath=path;restorePath=onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(genpath(graphicsRoot));
[~, parameter] = GraphicsDataAdapter_v3.unpack(source, options.Parameter);
if isempty(parameter)
    error('QuadrupedalGraphicsExample_v3:MissingParameter', ...
        'SOURCE must be an orbit with parameters or Parameter must be supplied.');
end

visible = char(options.Visible);
output.figures.animation = figure('Visible', visible, 'Color', 'w', ...
    'Name', 'v3 quadruped animation');
animationOptions = struct( ...
    'AnimationMode', char(options.AnimationMode), ...
    'Visible', visible, ...
    'FrameRate', options.FrameRate, ...
    'SlowDown', double(strcmpi(visible, 'on')), ...
    'PreserveEventFrames', true, ...
    'VideoFile', char(options.VideoFile));
output.animation = SLIP_Animation_Quad_v3( ...
    source, parameter, output.figures.animation, animationOptions);

output.figures.trajectories = figure('Visible', visible, 'Color', 'w', ...
    'Name', 'v3 torso and leg trajectories');
output.trajectories = SLIP_Trajectories_Quad_v3( ...
    source, output.figures.trajectories);

output.figures.grf = figure('Visible', visible, 'Color', 'w', ...
    'Name', 'v3 ground-reaction forces');
output.grf = SLIP_GRF_Quad_v3( ...
    source, parameter, output.figures.grf, Quadrupedal_Dynamics_v3());

output.figures.orbit = figure('Visible', visible, 'Color', 'w', ...
    'Name', 'v3 periodic orbit');
output.periodic_orbit = SLIP_PeriodicOrbit_Quad_v3( ...
    source, output.figures.orbit);

output.figures.phase = figure('Visible', visible, 'Color', 'w', ...
    'Name', 'v3 event-based phase diagram');
phaseAxes = axes('Parent', output.figures.phase);
output.phase = ComputePhaseDiagram_v3(source, phaseAxes);

output.animation_frames = struct();
output.animation_report = struct();
if options.PlayAnimation
    [output.animation_frames, output.animation_report] = ...
        output.animation.play('VideoFile', options.VideoFile);
end
end
