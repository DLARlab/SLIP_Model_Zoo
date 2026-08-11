classdef TestQuadrupedDynamicsContracts_v3 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addV3Paths(testCase)
            v3Root = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(v3Root, 'Schema_v3'));
            addpath(fullfile(v3Root, 'Dynamics_v3'));
            addpath(fullfile(v3Root, 'Simulation_v3'));
            testCase.addTeardown(@() rmpath( ...
                fullfile(v3Root, 'Simulation_v3'), ...
                fullfile(v3Root, 'Dynamics_v3'), ...
                fullfile(v3Root, 'Schema_v3')));
        end
    end

    methods (Test)
        function bodyDynamicsMatchIndependentCalculation(testCase)
            schema = QuadrupedSchema_v3();
            dynamics = ContinuousDynamics_v3(schema);
            previousRng = rng;
            cleanup = onCleanup(@() rng(previousRng));
            rng(817, 'twister');
            for sample = 1:12
                x = [ ...
                    0; 0.6 * randn; 0.78 + 0.08 * rand; ...
                    0.2 * randn; 0.12 * randn; 0.3 * randn; ...
                    reshape([0.15 * randn(4, 1), ...
                        0.2 * randn(4, 1)].', [], 1)];
                p = [ ...
                    70 + 40 * rand; 60 + 30 * rand; ...
                    2 + 3 * rand; 4 + 2 * rand; ...
                    1.05 + 0.1 * rand; 1.10 + 0.1 * rand; ...
                    0.2 * randn; 0.2 * randn; ...
                    1.5 + rand; 0.35 + 0.3 * rand];
                q = logical(randi([0, 1], 4, 1));
                [dxdt, diagnostics] = dynamics.evaluate(0, x, q, p);
                expanded = schema.expandParameters(p);

                phi = x(schema.State.phi);
                alpha = x(schema.Leg.AngleIndices);
                theta = phi + alpha;
                hipHeight = x(schema.State.y) + expanded.s .* sin(phi);
                length = expanded.l_0;
                compression = zeros(4, 1);
                length(q) = hipHeight(q) ./ cos(theta(q));
                compression(q) = expanded.l_0(q) - length(q);
                axial = zeros(4, 1);
                axial(q) = expanded.k_l(q) .* compression(q);
                perLegForce = ...
                    [-axial .* sin(theta), axial .* cos(theta)].';
                totalForce = sum(perLegForce, 2);
                torque = sum(expanded.s .* axial .* cos(alpha));

                testCase.verifyEqual(diagnostics.leg_lengths, length, ...
                    'AbsTol', 1e-13);
                testCase.verifyEqual(diagnostics.compression, compression, ...
                    'AbsTol', 1e-13);
                testCase.verifyEqual(diagnostics.axial_leg_forces, axial, ...
                    'AbsTol', 1e-12);
                testCase.verifyEqual(diagnostics.per_leg_force_vectors, ...
                    perLegForce, 'AbsTol', 1e-12);
                testCase.verifyEqual(diagnostics.pitch_torque, torque, ...
                    'AbsTol', 1e-12);
                testCase.verifyEqual(dxdt(schema.State.dx), totalForce(1), ...
                    'AbsTol', 1e-12);
                testCase.verifyEqual(dxdt(schema.State.dy), ...
                    totalForce(2) - 1, 'AbsTol', 1e-12);
                testCase.verifyEqual(dxdt(schema.State.dphi), ...
                    torque / p(schema.Parameter.j_pitch), 'AbsTol', 1e-12);
            end
        end

        function infinitePitchInertiaIsRobust(testCase)
            [x, p] = TestQuadrupedDynamicsContracts_v3.fixture();
            schema = QuadrupedSchema_v3();
            p(schema.Parameter.j_pitch) = Inf;
            dynamics = ContinuousDynamics_v3(schema);
            dxdt = dynamics.evaluate(0, x, logical([1; 0; 1; 0]), p);
            testCase.verifyEqual(dxdt(schema.State.dphi), 0);
        end

        function swingEquationRecoversZeroRslaEquation(testCase)
            dynamics = ContinuousDynamics_v3();
            forceX = 0.3;
            forceY = 1.2;
            phi = 0.1;
            dphi = 0.4;
            ddphi = -0.2;
            alpha = 0.15;
            legLength = 0.9;
            stiffness = 3.0;
            for hipOffset = [-0.4, 0.6]
                actual = dynamics.swingLegAcceleration( ...
                    forceX, forceY, phi, dphi, ddphi, alpha, ...
                    hipOffset, legLength, stiffness, 0);
                expected = -ddphi ...
                    - (forceX * cos(phi + alpha) ...
                        + forceY * sin(phi + alpha)) / legLength ...
                    - hipOffset * ddphi * sin(alpha) / legLength ...
                    + hipOffset * dphi^2 * cos(alpha) / legLength ...
                    - stiffness * alpha / legLength^2;
                testCase.verifyEqual(actual, expected, 'AbsTol', 1e-14);
            end
        end

        function torsionalSpringAndBipedLimits(testCase)
            dynamics = ContinuousDynamics_v3();
            restAngle = 0.25;
            zeroSpring = dynamics.swingLegAcceleration( ...
                0, 0, 0, 0, 0, restAngle, 0, 1, 4, restAngle);
            testCase.verifyEqual(zeroSpring, 0, 'AbsTol', 1e-15);

            forceX = 0.4;
            forceY = 0.7;
            alpha = -0.2;
            omega = 3;
            actual = dynamics.swingLegAcceleration( ...
                forceX, forceY, 0, 0, 0, alpha, 0, 1, ...
                omega^2, restAngle);
            expected = -forceX * cos(alpha) - forceY * sin(alpha) ...
                - omega^2 * (alpha - restAngle);
            testCase.verifyEqual(actual, expected, 'AbsTol', 1e-14);
        end

        function familyParametersAndRslaShiftAreCorrect(testCase)
            schema = QuadrupedSchema_v3();
            dynamics = ContinuousDynamics_v3(schema);
            [x, p] = TestQuadrupedDynamicsContracts_v3.fixture();
            x(schema.State.phi) = 0;
            x(schema.State.dphi) = 0;
            x(schema.Leg.AngleIndices) = 0.3;
            x(schema.Leg.RateIndices) = 0;
            q = false(4, 1);
            dxdt = dynamics.evaluate(0, x, q, p);
            expanded = schema.expandParameters(p);
            expected = -expanded.k_s ./ expanded.l_0.^2 ...
                .* (0.3 - expanded.rsla);
            testCase.verifyEqual(dxdt(schema.Leg.RateIndices), expected, ...
                'AbsTol', 1e-13);

            deltaRsla = 0.07;
            baseline = dynamics.swingLegAcceleration( ...
                0.2, 0.5, 0.1, 0.3, -0.1, 0.2, -0.4, 0.9, 3, -0.1);
            shifted = dynamics.swingLegAcceleration( ...
                0.2, 0.5, 0.1, 0.3, -0.1, 0.2, -0.4, 0.9, 3, ...
                -0.1 + deltaRsla);
            testCase.verifyEqual(shifted - baseline, ...
                3 / 0.9^2 * deltaRsla, 'AbsTol', 1e-14);
        end

        function guardsUseFamilyLengthsAndNewEventOrder(testCase)
            schema = QuadrupedSchema_v3();
            [x, p] = TestQuadrupedDynamicsContracts_v3.fixture();
            q = logical([0; 1; 0; 1]);
            guards = GuardFunctions_v3(schema);
            values = guards.legValues(x, p);
            expanded = schema.expandParameters(p);
            alpha = x(schema.Leg.AngleIndices);
            expected = x(schema.State.y) ...
                + expanded.s .* sin(x(schema.State.phi)) ...
                - expanded.l_0 .* cos(x(schema.State.phi) + alpha);
            testCase.verifyEqual(values, expected, 'AbsTol', 1e-14);

            descriptors = guards.descriptors(0, x, q, p);
            testCase.verifyEqual({descriptors.name}, schema.Event.Names);
            testCase.verifyEqual([descriptors.direction], ...
                schema.Event.Directions);
            testCase.verifyEqual([descriptors.enabled], ...
                logical([1, 0, 0, 1, 1, 0, 0, 1]));
        end

        function guardMetadataUsesTrueStanceLieDerivative(testCase)
            schema = QuadrupedSchema_v3.shared();
            [x, p] = TestQuadrupedDynamicsContracts_v3.fixture();
            q = logical([1; 0; 0; 0]);
            system = Quadrupedal_Dynamics_v3();
            flow = system.flow(0, x, q, p);
            guards = system.guardFunctions(0, x, q, p);
            step = 1e-7 / max(1, norm(flow, inf));
            component = GuardFunctions_v3(schema);
            plus = component.legValues(x + step * flow, p);
            minus = component.legValues(x - step * flow, p);
            numerical = (plus - minus) / (2 * step);
            blLiftoff = schema.eventId('BL_LO');

            testCase.verifyEqual( ...
                guards(blLiftoff).directional_derivative, ...
                numerical(1), 'RelTol', 2e-7, 'AbsTol', 2e-9);
        end

        function resetProjectsHorizontalFootVelocity(testCase)
            schema = QuadrupedSchema_v3();
            [x, p] = TestQuadrupedDynamicsContracts_v3.fixture();
            q = false(4, 1);
            reset = ResetMap_v3(schema);
            legIndex = 2; % BR in the canonical schema
            xplus = reset.apply('BR_TD', 0, x, q, p);
            horizontalFootVelocity = ...
                TestQuadrupedDynamicsContracts_v3.footVelocityX( ...
                xplus, legIndex, p, schema);
            testCase.verifyEqual(horizontalFootVelocity, 0, ...
                'AbsTol', 2e-14);

            batch = reset.applyBatch( ...
                {'BL_TD', 'FR_TD'}, 0, x, q, p);
            testCase.verifyEqual( ...
                TestQuadrupedDynamicsContracts_v3.footVelocityX( ...
                batch, 1, p, schema), 0, 'AbsTol', 2e-14);
            testCase.verifyEqual( ...
                TestQuadrupedDynamicsContracts_v3.footVelocityX( ...
                batch, 4, p, schema), 0, 'AbsTol', 2e-14);
        end

        function stanceFlowPreservesFixedFootConstraint(testCase)
            schema = QuadrupedSchema_v3.shared();
            [baseState, p] = TestQuadrupedDynamicsContracts_v3.fixture();
            system = Quadrupedal_Dynamics_v3();
            reset = ResetMap_v3(schema);
            for legIndex = schema.Leg.Indices
                x = baseState;
                rateIndex = schema.Leg.RateIndices(legIndex);
                x(rateIndex) = reset.projectedAngularRate(x, legIndex, p);
                q = false(schema.Leg.Count, 1);
                q(legIndex) = true;
                flow = system.flow(0, x, q, p);
                step = 2e-6 / max(1, norm(flow, inf));
                projectedPlus = reset.projectedAngularRate( ...
                    x + step * flow, legIndex, p);
                projectedMinus = reset.projectedAngularRate( ...
                    x - step * flow, legIndex, p);
                numericalAcceleration = ...
                    (projectedPlus - projectedMinus) / (2 * step);

                testCase.verifyEqual( ...
                    flow(schema.Leg.AngleIndices(legIndex)), ...
                    x(rateIndex), 'AbsTol', 2e-13);
                testCase.verifyEqual(flow(rateIndex), ...
                    numericalAcceleration, 'RelTol', 4e-5, ...
                    'AbsTol', 2e-6);
            end
        end

        function resetDetectsSingularity(testCase)
            schema = QuadrupedSchema_v3();
            [x, p] = TestQuadrupedDynamicsContracts_v3.fixture();
            x(schema.State.y) = 0;
            x(schema.State.phi) = 0;
            x(schema.State.alphaBL) = 0;
            reset = ResetMap_v3(schema);
            testCase.verifyError(@() reset.apply( ...
                'BL_TD', 0, x, false(4, 1), p), ...
                'ResetMap_v3:SingularProjection');
        end

        function tensileStanceIsReportedWithoutClamping(testCase)
            schema = QuadrupedSchema_v3();
            [x, p] = TestQuadrupedDynamicsContracts_v3.fixture();
            x(schema.State.y) = 2;
            q = logical([1; 0; 0; 0]);
            dynamics = ContinuousDynamics_v3(schema);
            [~, diagnostics] = dynamics.evaluate(0, x, q, p);
            testCase.verifyFalse(diagnostics.admissible);
            testCase.verifyLessThan(diagnostics.compression(1), 0);
            testCase.verifyLessThan(diagnostics.axial_leg_forces(1), 0);
            testCase.verifyError(@() dynamics.assertAdmissible(x, q, p), ...
                'ContinuousDynamics_v3:TensileStance');
        end

        function simulatorRejectsAcceptedTensileStance(testCase)
            schema = QuadrupedSchema_v3();
            [x, p] = TestQuadrupedDynamicsContracts_v3.fixture();
            x(schema.State.y) = 2;
            q = logical([1; 0; 0; 0]);
            simulator = HybridSimulator_v3();
            testCase.verifyError(@() simulator.simulate( ...
                Quadrupedal_Dynamics_v3(), x, q, p, [0, 0.01]), ...
                'ContinuousDynamics_v3:TensileStance');
        end
    end

    methods (Static, Access = private)
        function [x, p] = fixture()
            x = [ ...
                0; 0.45; 0.90; -0.05; 0.08; 0.20; ...
                -0.10; 0.03; -0.10; 0.03; ...
                 0.02; -0.04; 0.02; -0.04];
            p = [100; 80; 4; 9; 1.0; 1.1; 0.1; -0.2; 2; 0.45];
        end

        function velocity = footVelocityX(x, legIndex, p, schema)
            expanded = schema.expandParameters(p);
            state = schema.State;
            angleIndex = schema.Leg.AngleIndices(legIndex);
            rateIndex = schema.Leg.RateIndices(legIndex);
            hipOffset = expanded.s(legIndex);
            phi = x(state.phi);
            dphi = x(state.dphi);
            theta = phi + x(angleIndex);
            hipHeight = x(state.y) + hipOffset * sin(phi);
            velocity = x(state.dx) - hipOffset * sin(phi) * dphi ...
                + (x(state.dy) + hipOffset * cos(phi) * dphi) * tan(theta) ...
                + hipHeight / cos(theta)^2 * (dphi + x(rateIndex));
        end
    end
end
