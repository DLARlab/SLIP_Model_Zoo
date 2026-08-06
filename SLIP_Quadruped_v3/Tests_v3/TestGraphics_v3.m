classdef TestGraphics_v3 < matlab.unittest.TestCase
    %TESTGRAPHICS_V3 Headless tests for the event-driven v3 graphics layer.

    methods (TestClassSetup)
        function addV3Path(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            previousPath = path;
            addpath(genpath(root));
            testCase.addTeardown(@() path(previousPath));
        end
    end

    methods (Test)
        function jointGeometryUsesSchemaLegOrderAndFamilyLengths(testCase)
            [~, p, state] = localGraphicsFixture();
            schema = QuadrupedSchema_v3();
            q = false(schema.Leg.Count, 1);
            geometry = ComputeJointLegGeometry_v3(0, state, q, p);
            testCase.verifyEqual(geometry.leg_names, ...
                {'BL', 'BR', 'FL', 'FR'});
            testCase.verifyEqual(geometry.leg_lengths, ...
                [p(schema.Parameter.l_l_b); p(schema.Parameter.l_l_b); ...
                 p(schema.Parameter.l_l_f); p(schema.Parameter.l_l_f)], ...
                'AbsTol', 1e-14);
            testCase.verifyEqual(geometry.mode, q);
            testCase.verifyTrue(all(isfinite(geometry.foot_positions(:))));
        end

        function stanceLengthUsesActualRecordedMode(testCase)
            [~, p, state] = localGraphicsFixture();
            schema = QuadrupedSchema_v3();
            q = logical([1; 0; 0; 1]);
            geometry = ComputeJointLegGeometry_v3(0, state, q, p);
            expectedBL = geometry.hip_positions(2, 1) / ...
                cos(geometry.absolute_leg_angles(1));
            expectedFR = geometry.hip_positions(2, 4) / ...
                cos(geometry.absolute_leg_angles(4));
            testCase.verifyEqual(geometry.leg_lengths([1, 4]), ...
                [expectedBL; expectedFR], 'AbsTol', 1e-13);
            testCase.verifyEqual(geometry.leg_lengths(2), ...
                p(schema.Parameter.l_l_b));
            testCase.verifyEqual(geometry.leg_lengths(3), ...
                p(schema.Parameter.l_l_f));
        end

        function resamplingIsRightContinuousAndResetSafe(testCase)
            schema = QuadrupedSchema_v3();
            state0 = zeros(1, schema.State.Dimension);
            state0(schema.State.y) = 1;
            stateMinus = state0;
            stateMinus(schema.State.dx) = 1;
            statePlus = stateMinus;
            statePlus(schema.State.dx) = 3;
            stateEnd = statePlus;
            stateEnd(schema.State.dx) = 4;
            q0 = false(schema.Leg.Count, 1);
            q1 = q0;
            q1(1) = true;
            trajectory = Trajectory_v3();
            trajectory.appendSample(0, state0, q0);
            trajectory.appendSample(0.5, stateMinus, q0);
            trajectory.appendSample(0.5, statePlus, q1);
            trajectory.appendSample(1, stateEnd, q1);
            trajectory.recordEvent(struct( ...
                'type', "guard", 'guard_name', "BL_TD", 'time', 0.5, ...
                'mode_before', q0, 'mode_after', q1));

            frames = ResampleHybridTrajectory_v3(trajectory, ...
                'TimeStep', 0.25, 'PreserveEventFrames', true);
            atEvent = find(frames.time == 0.5, 1);
            testCase.verifyEqual(frames.state(atEvent, schema.State.dx), 3);
            testCase.verifyTrue(frames.mode(atEvent, 1));
            before = find(frames.time == 0.25, 1);
            after = find(frames.time == 0.75, 1);
            testCase.verifyEqual(frames.state(before, schema.State.dx), 0.5, ...
                'AbsTol', 1e-14);
            testCase.verifyEqual(frames.state(after, schema.State.dx), 3.5, ...
                'AbsTol', 1e-14);
            testCase.verifyTrue(frames.is_event_frame(atEvent));
            testCase.verifyTrue(frames.right_continuous);
        end

        function phaseDiagramComesFromEventHistory(testCase)
            [orbit, ~] = localGraphicsFixture();
            phase = ComputePhaseDiagram_v3(orbit);
            testCase.verifyEqual(phase.source, "event_history");
            testCase.verifyEqual(phase.leg_names, {'BL', 'BR', 'FL', 'FR'});
            testCase.verifyEqual(phase.event_names, [ ...
                "BL_TD"; "BR_TD"; "FL_TD"; "FR_TD"; ...
                "BL_LO"; "BR_LO"; "FL_LO"; "FR_LO"]);
            for leg = 1:4
                testCase.verifySize(phase.stance_intervals{leg}, [1, 2]);
            end
            testCase.verifyEqual(phase.stance_intervals{1}, [0.1, 0.6], ...
                'AbsTol', 1e-14);
            testCase.verifyEqual(phase.stance_intervals{4}, [0.4, 0.9], ...
                'AbsTol', 1e-14);
        end

        function allGraphicsConstructAndUpdateHeadlessly(testCase)
            [orbit, p] = localGraphicsFixture();
            figures = gobjects(5, 1);
            for k = 1:5
                figures(k) = figure('Visible', 'off');
            end
            testCase.addTeardown(@() delete(figures(isgraphics(figures))));

            animationOptions = struct( ...
                'AnimationMode', 'Detailed', 'Visible', 'off', ...
                'FrameRate', 10, 'SlowDown', 0, ...
                'PreserveEventFrames', true, 'VideoFile', '');
            animation = SLIP_Animation_Quad_v3( ...
                orbit, [], figures(1), animationOptions);
            trajectories = SLIP_Trajectories_Quad_v3(orbit, figures(2));
            grf = SLIP_GRF_Quad_v3( ...
                orbit, [], figures(3), Quadrupedal_Dynamics_v3());
            periodic = SLIP_PeriodicOrbit_Quad_v3(orbit, figures(4));
            phaseAxes = axes('Parent', figures(5));
            phase = ComputePhaseDiagram_v3(orbit, phaseAxes);

            trajectory = orbit.trajectory;
            modes = GraphicsDataAdapter_v3.modeMatrix(trajectory);
            for k = [1, round(numel(trajectory.time)/2), numel(trajectory.time)]
                animation.update(trajectory.time(k), ...
                    trajectory.state(k, :).', modes(k, :).', false);
                periodic.update(trajectory.state(k, :).');
            end
            trajectories.update(orbit);
            grf.update(orbit, p);

            testCase.verifyTrue(all(isfinite(animation.Body.background.XData)));
            testCase.verifyTrue(all(isfinite(animation.Body.background.YData)));
            for leg = 1:4
                vertices = animation.LegHandles{leg}.shaft.Vertices;
                testCase.verifyTrue(all(isfinite(vertices(:))));
            end
            testCase.verifyEqual(string(grf.Legend.String), ...
                ["BL", "BR", "FL", "FR"]);
            testCase.verifyEqual(phase.source, "event_history");
            testCase.verifyNumElements(trajectories.Lines{1}, 5);
            testCase.verifyNumElements(trajectories.Lines{2}, 4);
            testCase.verifyNumElements(trajectories.Lines{3}, 4);
        end

        function uiAxesTargetsAreSupported(testCase)
            [orbit, ~] = localGraphicsFixture();
            uiFigure = uifigure('Visible', 'off');
            directUIFigure = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete([uiFigure, directUIFigure]));
            gridLayout = uigridlayout(uiFigure, [3, 3]);
            uiAxes = gobjects(7, 1);
            for k = 1:numel(uiAxes)
                uiAxes(k) = uiaxes(gridLayout);
            end
            animationOptions = struct( ...
                'AnimationMode', 'Simple', 'Visible', 'off', ...
                'FrameRate', 10, 'SlowDown', 0, ...
                'PreserveEventFrames', true, 'VideoFile', '');
            animation = SLIP_Animation_Quad_v3( ...
                orbit, [], uiAxes(1), animationOptions);
            trajectories = SLIP_Trajectories_Quad_v3(orbit, uiAxes(2:4));
            grf = SLIP_GRF_Quad_v3( ...
                orbit, [], uiAxes(5), Quadrupedal_Dynamics_v3());
            periodic = SLIP_PeriodicOrbit_Quad_v3(orbit, uiAxes(6));
            phase = ComputePhaseDiagram_v3(orbit, uiAxes(7));
            directFigureGraphic = SLIP_PeriodicOrbit_Quad_v3( ...
                orbit, directUIFigure);

            testCase.verifyClass(animation.axes, 'matlab.ui.control.UIAxes');
            testCase.verifyClass(trajectories.axes(1), ...
                'matlab.ui.control.UIAxes');
            testCase.verifyClass(grf.ax, 'matlab.ui.control.UIAxes');
            testCase.verifyClass(periodic.axes, 'matlab.ui.control.UIAxes');
            testCase.verifyTrue(all(isgraphics(phase.handles.base)));
            testCase.verifyEqual(ancestor(directFigureGraphic.axes, 'figure'), ...
                directUIFigure);
        end

        function graphicsExampleRunsWithoutInteraction(testCase)
            [orbit, ~] = localGraphicsFixture();
            output = QuadrupedalGraphicsExample_v3(orbit, ...
                'Visible', 'off', 'PlayAnimation', false);
            figureHandles = struct2array(output.figures);
            testCase.addTeardown(@() delete(figureHandles(isgraphics(figureHandles))));
            testCase.verifyTrue(all(isgraphics(figureHandles)));
            testCase.verifyClass(output.animation, 'SLIP_Animation_Quad_v3');
            testCase.verifyClass(output.trajectories, ...
                'SLIP_Trajectories_Quad_v3');
            testCase.verifyClass(output.grf, 'SLIP_GRF_Quad_v3');
            testCase.verifyClass(output.periodic_orbit, ...
                'SLIP_PeriodicOrbit_Quad_v3');
            testCase.verifyEqual(output.phase.source, "event_history");
        end

        function packedLegacyParameterIsRejected(testCase)
            [~, ~, state] = localGraphicsFixture();
            testCase.verifyError(@() ComputeJointLegGeometry_v3( ...
                0, state, false(4, 1), ones(7, 1)), ...
                'GraphicsDataAdapter_v3:ParameterDimension');
        end
    end
end

function [orbit, p, nominalState] = localGraphicsFixture()
schema = QuadrupedSchema_v3();
p = zeros(schema.Parameter.Dimension, 1);
p(schema.Parameter.k_l_b) = 12;
p(schema.Parameter.k_l_f) = 15;
p(schema.Parameter.k_s_b) = 0.8;
p(schema.Parameter.k_s_f) = 1.1;
p(schema.Parameter.l_l_b) = 1.0;
p(schema.Parameter.l_l_f) = 1.2;
p(schema.Parameter.rsla_b) = 0.05;
p(schema.Parameter.rsla_f) = -0.04;
p(schema.Parameter.j_pitch) = 1.5;
p(schema.Parameter.l_com) = 0.45;

nominalState = zeros(schema.State.Dimension, 1);
nominalState(schema.State.dx) = 0.35;
nominalState(schema.State.y) = 0.82;
nominalState(schema.State.phi) = 0.04;
nominalState(schema.Leg.AngleIndices) = [0.08; 0.06; -0.03; -0.05];

eventTimes = [0.1, 0.2, 0.3, 0.4, 0.6, 0.7, 0.8, 0.9];
eventNames = ["BL_TD", "BR_TD", "FL_TD", "FR_TD", ...
              "BL_LO", "BR_LO", "FL_LO", "FR_LO"];
eventLegs = [1, 2, 3, 4, 1, 2, 3, 4];
isTouchdown = [true(1, 4), false(1, 4)];
trajectory = Trajectory_v3();
q = false(schema.Leg.Count, 1);
stateAt = @(time) localState(nominalState, schema, time);
trajectory.appendSample(0, stateAt(0), q);
for k = 1:numel(eventTimes)
    currentState = stateAt(eventTimes(k));
    trajectory.appendSample(eventTimes(k), currentState, q);
    qBefore = q;
    q(eventLegs(k)) = isTouchdown(k);
    trajectory.appendSample(eventTimes(k), currentState, q);
    trajectory.recordEvent(struct( ...
        'type', "guard", 'guard_name', eventNames(k), ...
        'time', eventTimes(k), 'mode_before', qBefore, ...
        'mode_after', q, 'state_before', currentState, ...
        'state_after', currentState, 'is_stop', false));
end
trajectory.appendSample(1, stateAt(1), q);
trajectory.setTermination("fixture", 1, stateAt(1), q, struct());

values = struct( ...
    'initial_state', stateAt(0), ...
    'initial_mode', false(schema.Leg.Count, 1), ...
    'period', 1, ...
    'parameter', p, ...
    'event_history', trajectory.event_history, ...
    'mode_history', GraphicsDataAdapter_v3.modeMatrix(trajectory), ...
    'poincare_state', stateAt(1), ...
    'trajectory', trajectory);
orbit = HybridOrbit_v3(values);
end

function state = localState(nominalState, schema, time)
state = nominalState;
state(schema.State.x) = 0.35 * time;
state(schema.State.y) = nominalState(schema.State.y) + ...
    0.03 * cos(2*pi*time);
state(schema.State.dy) = -0.06*pi * sin(2*pi*time);
state(schema.State.phi) = nominalState(schema.State.phi) + ...
    0.015 * sin(2*pi*time);
state(schema.State.dphi) = 0.03*pi * cos(2*pi*time);
end
