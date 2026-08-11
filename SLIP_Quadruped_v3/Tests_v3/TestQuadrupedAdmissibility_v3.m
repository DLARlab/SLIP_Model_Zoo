classdef TestQuadrupedAdmissibility_v3 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addV3Paths(testCase)
            v3Root = fileparts(fileparts(mfilename('fullpath')));
            schemaPath = fullfile(v3Root, 'Schema_v3');
            dynamicsPath = fullfile(v3Root, 'Dynamics_v3');
            simulationPath = fullfile(v3Root, 'Simulation_v3');
            stabilityPath = fullfile(v3Root, 'Stability_v3');
            addpath(schemaPath, dynamicsPath, simulationPath, stabilityPath);
            testCase.addTeardown(@() rmpath( ...
                stabilityPath, simulationPath, dynamicsPath, schemaPath));
        end
    end

    methods (Test)
        function swingFootPenetrationIsRejectedAtAcceptedState(testCase)
            [x, p, schema] = ...
                TestQuadrupedAdmissibility_v3.fixture();
            x(schema.State.y) = 1.1 - 2e-4;
            q = false(schema.Leg.Count, 1);
            checker = QuadrupedAdmissibility_v3(schema);

            report = checker.evaluate(x, q, p, 'accepted-state');

            testCase.verifyFalse(report.global_validity);
            testCase.verifyLessThan(report.swing_foot_clearances(3), 0);
            testCase.verifyTrue(any(startsWith(string( ...
                report.failure_reasons), 'swing_foot_penetration:')));
            testCase.verifyEqual(report.active_tolerances. ...
                swing_penetration, checker.SwingPenetrationTolerance);
            testCase.verifyError(@() checker.assertAdmissible( ...
                x, q, p, 'accepted-state'), ...
                'QuadrupedAdmissibility_v3:PhysicallyInadmissible');
        end

        function hipAndTorsoGroundClearanceAreReported(testCase)
            [x, p, schema] = ...
                TestQuadrupedAdmissibility_v3.fixture();
            x(schema.State.y) = 0.05;
            x(schema.State.phi) = 0.30;
            q = false(schema.Leg.Count, 1);
            checker = QuadrupedAdmissibility_v3(schema);

            report = checker.evaluate(x, q, p, 'section-return');

            testCase.verifyLessThan(report.hip_clearances(1), 0);
            testCase.verifyGreaterThan(report.hip_clearances(3), 0);
            testCase.verifyEqual(report.torso_clearance, ...
                min(report.torso_endpoint_heights), 'AbsTol', 1e-14);
            testCase.verifyLessThan(report.torso_clearance_margin, 0);
            reasons = string(report.failure_reasons);
            testCase.verifyTrue(any(startsWith( ...
                reasons, 'back_hip_ground_contact:')));
            testCase.verifyTrue(any(reasons == 'torso_ground_contact'));
            testCase.verifyEqual(report.context, 'section-return');
        end

        function invalidLegGeometryAndComplementarityAreSeparated(testCase)
            [x, p, schema] = ...
                TestQuadrupedAdmissibility_v3.fixture();
            checker = QuadrupedAdmissibility_v3(schema);

            qStance = logical([1; 0; 0; 0]);
            x(schema.State.alphaBL) = pi / 2;
            invalidGeometry = checker.evaluate( ...
                x, qStance, p, 'accepted-state');
            testCase.verifyFalse(invalidGeometry.global_validity);
            testCase.verifyFalse( ...
                invalidGeometry.finite_geometry_per_leg(1));
            testCase.verifyTrue(any(startsWith(string( ...
                invalidGeometry.failure_reasons), ...
                'invalid_leg_geometry:BL')));

            [x, p, schema] = ...
                TestQuadrupedAdmissibility_v3.fixture();
            x(schema.State.y) = 1.1 - 5e-4;
            qSwing = false(schema.Leg.Count, 1);
            complementarity = checker.evaluate( ...
                x, qSwing, p, 'accepted-state');
            testCase.verifyGreaterThan( ...
                complementarity.complementarity_residuals(3), ...
                checker.ComplementarityTolerance);
            testCase.verifyTrue(any(startsWith(string( ...
                complementarity.failure_reasons), ...
                'contact_complementarity_loss:FL')));
        end

        function nonfiniteGeometryProducesStructuredFailure(testCase)
            [x, p, schema] = ...
                TestQuadrupedAdmissibility_v3.fixture();
            x(schema.State.alphaBL) = NaN;
            checker = QuadrupedAdmissibility_v3(schema);

            report = checker.evaluate( ...
                x, false(schema.Leg.Count, 1), p, 'accepted-state');

            testCase.verifyFalse(report.global_validity);
            testCase.verifyFalse(report.finite_geometry_per_leg(1));
            testCase.verifyTrue(any(string(report.failure_reasons) ...
                == 'invalid_nonfinite_geometry'));
        end

        function odeStageAllowsOnlyConfiguredSmallSurfaceExcursion(testCase)
            [x, p, schema] = ...
                TestQuadrupedAdmissibility_v3.fixture();
            x(schema.State.y) = 1.1 - 1e-6;
            q = false(schema.Leg.Count, 1);
            checker = QuadrupedAdmissibility_v3(schema, struct( ...
                'ODEStageSurfaceTolerance', 1e-5));

            stage = checker.evaluate(x, q, p, 'ode-stage');
            accepted = checker.evaluate(x, q, p, 'accepted-state');

            testCase.verifyTrue(stage.global_validity);
            testCase.verifyFalse(stage.strict_global_validity);
            testCase.verifyFalse(accepted.global_validity);
            testCase.verifyTrue(stage.context_policy. ...
                allows_transient_event_surface_overshoot);
            testCase.verifyFalse(accepted.context_policy. ...
                allows_transient_event_surface_overshoot);
            testCase.verifyGreaterThan( ...
                stage.active_tolerances.swing_penetration, ...
                accepted.active_tolerances.swing_penetration);
        end

        function postResetAndSystemOwnedAPIsReportContext(testCase)
            [x, p, schema] = ...
                TestQuadrupedAdmissibility_v3.fixture();
            x(schema.State.y) = 1;
            x(schema.State.alphaBR) = 0.2;
            x(schema.State.alphaFL) = 0.5;
            x(schema.State.alphaFR) = 0.5;
            q = logical([1; 0; 0; 0]);
            system = Quadrupedal_Dynamics_v3();

            report = system.admissibilityReport(x, q, p, ...
                'post-reset', struct('event_ids', ...
                schema.eventId('BL_TD')));

            testCase.verifyTrue(report.global_validity);
            testCase.verifyTrue( ...
                report.post_reset_consistency_evaluated);
            testCase.verifyTrue(all(report.post_reset_guard_consistent));
            testCase.verifyTrue(all(report.post_reset_mode_consistent));
            testCase.verifyEqual(report.context, 'post-reset');
            components = system.components();
            testCase.verifyClass(components.admissibility, ...
                'QuadrupedAdmissibility_v3');
        end

        function simulatorPropagatesMinimumPhysicalMargins(testCase)
            [x, p, schema] = ...
                TestQuadrupedAdmissibility_v3.fixture();
            simulator = HybridSimulator_v3(struct( ...
                'RelTol', 1e-10, 'AbsTol', 1e-12));
            [trajectory, result] = simulator.simulate( ...
                Quadrupedal_Dynamics_v3(), x, ...
                false(schema.Leg.Count, 1), p, [0, 1e-3]);

            testCase.verifyTrue(result.success);
            testCase.verifyTrue(isfield(result, ...
                'minimum_physical_margins'));
            testCase.verifyTrue(isfinite( ...
                result.minimum_physical_margins.global));
            testCase.verifyGreaterThan( ...
                result.minimum_physical_margins.swing_foot_clearance, 0);
            testCase.verifyEqual( ...
                trajectory.metadata.minimum_physical_margins.global, ...
                result.minimum_physical_margins.global);
        end

        function physicalBoundariesAreNeverSmoothBifurcations(testCase)
            point = struct( ...
                'continuationCoordinate', 0, ...
                'event_history', struct([]), ...
                'event_counts', [], 'guard_transversality', Inf, ...
                'topology_margins', struct(), ...
                'minimum_physical_margins', struct( ...
                    'global', -1e-9, ...
                    'swing_foot_clearance', -1e-9, ...
                    'stance_compression', 1, ...
                    'leg_length', -Inf, ...
                    'hip_clearance', 1, ...
                    'torso_clearance', -1e-9, ...
                    'complementarity_margin', -1e-9));
            events = HybridBoundaryDetector_v3().detect(point);
            types = string({events.type});

            testCase.verifyTrue(any(types == "swing_foot_penetration"));
            testCase.verifyTrue(any(types == "torso_ground_contact"));
            testCase.verifyTrue(any(types == "invalid_leg_geometry"));
            testCase.verifyTrue(any(types == ...
                "contact_complementarity_loss"));
            testCase.verifyFalse(any([events.reliableSmoothBifurcation]));
        end
    end

    methods (Static, Access = private)
        function [x, p, schema] = fixture()
            schema = QuadrupedSchema_v3();
            x = zeros(schema.State.Dimension, 1);
            x(schema.State.y) = 1.2;
            p = [100; 80; 4; 9; 1.0; 1.1; 0.1; -0.2; 2; 0.45];
        end
    end
end
