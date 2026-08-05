classdef TestHybridFramework_v3 < matlab.unittest.TestCase
    properties
        RepositoryRoot
        QuadrupedOrbit
        QuadrupedReport
    end

    methods (TestClassSetup)
        function configurePathsAndFixture(testCase)
            testCase.RepositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            folders = {'Dynamics_v3', 'Simulation_v3', 'Orbit_v3', ...
                'Numerics_v3', 'Stability_v3', 'Examples_v3', 'Tests_v3'};
            for i = 1:numel(folders)
                addpath(fullfile(testCase.RepositoryRoot, folders{i}));
            end
            [testCase.QuadrupedOrbit, testCase.QuadrupedReport] = ...
                QuadrupedalExample_v3(struct( ...
                    'FixtureFile', 'PK_20_2.mat', ...
                    'FixtureColumn', 1, ...
                    'ResidualTolerance', 5e-5));
        end
    end

    methods (Test)
        function recoverExistingPeriodicQuadrupedSolution(testCase)
            % Test 1: a stored solution is replayed without event-time inputs.
            testCase.verifyTrue(testCase.QuadrupedReport.recovered, ...
                sprintf('Residual infinity norm is %.3e.', ...
                testCase.QuadrupedReport.residual_norm));
            testCase.verifyLessThan( ...
                testCase.QuadrupedReport.residual_norm, 5e-5);
            testCase.verifyEqual(testCase.QuadrupedOrbit.period, ...
                1.564520214497, 'AbsTol', 2e-4);
            testCase.verifyGreaterThan( ...
                abs(testCase.QuadrupedReport.stride_displacement), 1e-4);
            testCase.verifyTrue(isequal( ...
                testCase.QuadrupedOrbit.initial_mode, false(4, 1)));
        end

        function continuationAllowsLiftoffToPassApex(testCase)
            % Test 2: LO_FR changes sides of apex and q_apex changes with it.
            [problem, ~] = testCase.orderingProblem();
            solver = RootSolver_v3(struct( ...
                'Algorithm', 'newton', ...
                'FunctionTolerance', 1e-9, ...
                'ResidualAcceptanceTolerance', 1e-7));
            continuation = NumericalContinuation1D_v3(struct( ...
                'RootSolver', solver, ...
                'ActiveParameterIndex', 1, ...
                'StopOnFailure', true));
            parameterValues = [-0.10, -0.05, 0.05, 0.10];
            branch = continuation.run( ...
                problem, [1; 0], -0.10, 0, parameterValues);

            testCase.verifyEqual(branch.count, numel(parameterValues));
            testCase.verifyTrue(branch.success);
            modes = cellfun(@double, branch.mode);
            testCase.verifyEqual(modes, [0, 0, 1, 1]);
            testCase.verifyEqual(branch.period, ones(1, 4), ...
                'AbsTol', 2e-6);
            testCase.verifyLessThan(max(abs([branch.points.residualNorm])), 1e-7);

            beforeNames = string({branch.event_history{1}.type});
            afterNames = string({branch.event_history{end}.type});
            testCase.verifyEqual(beforeNames, ["TD_FR", "LO_FR"]);
            testCase.verifyEqual(afterNames, ["LO_FR", "TD_FR"]);
        end

        function computesHybridFloquetMultiplier(testCase)
            % Test 3: radial variational exponent -2 gives exp(-2) per return.
            system = createSyntheticHybridSystem_v3('radial');
            simulator = HybridSimulator_v3(struct( ...
                'RelTol', 1e-11, 'AbsTol', 1e-13));
            section = PoincareSection_v3.apex(2);
            map = PoincareMap_v3(system, section, simulator, struct( ...
                'MaxReturnTime', 1.5, 'ArmTolerance', 1e-7));
            analysis = FloquetAnalysis_v3(struct( ...
                'TangentIndices', 1, ...
                'Differencing', 'central', ...
                'RelativeStep', 1e-4));
            result = analysis.analyze(map, [1; 0], 0, 1);

            testCase.verifySize(result.poincareMatrix, [1, 1]);
            testCase.verifySize(result.ambientPoincareMatrix, [2, 2]);
            testCase.verifyEqual(result.multipliers, exp(-2), ...
                'AbsTol', 3e-4);
            testCase.verifyEqual(result.stabilityMargin, 1 - exp(-2), ...
                'AbsTol', 3e-4);
            testCase.verifyTrue(result.stable);
            testCase.verifyTrue(result.reliable);
        end

        function detectsSyntheticBifurcations(testCase)
            % Test 4: crossings are bracketed, not tested by exact equality.
            angle = 0.4;
            multipliers = [ ...
                 0.8,  1.2; ...
                -0.8, -1.2; ...
                 0.9 * exp(1i * angle), 1.1 * exp(1i * angle); ...
                 0.9 * exp(-1i * angle), 1.1 * exp(-1i * angle)];
            detector = BifurcationDetector_v3();
            [events, tracks] = detector.detect(multipliers, [0, 1]);

            types = string({events.type});
            testCase.verifyTrue(any(types == "saddle-node"));
            testCase.verifyTrue(any(types == "period-doubling"));
            testCase.verifyTrue(any(types == "Neimark-Sacker"));
            testCase.verifyEqual(size(tracks.multipliers), [4, 2]);
            testCase.verifyEqual([events.location], ...
                0.5 * ones(1, numel(events)), 'AbsTol', 1e-12);
        end

        function eventSequenceIsGeneratedAutomatically(testCase)
            % Test 5: no event timing or gait label was passed to v3.
            expected = ["BL_TD"; "FL_TD"; "BR_TD"; "FR_TD"; ...
                        "BL_LO"; "FL_LO"; "BR_LO"; "FR_LO"];
            actual = reshape(string( ...
                {testCase.QuadrupedOrbit.event_history.type}), [], 1);
            testCase.verifyEqual(actual, expected);
            testCase.verifyNumElements( ...
                testCase.QuadrupedOrbit.mode_history, 9);
            testCase.verifyFalse(isprop( ...
                testCase.QuadrupedOrbit, 'gait_type'));
            touchdownTimes = [testCase.QuadrupedOrbit.event_history(1:4).time];
            liftoffTimes = [testCase.QuadrupedOrbit.event_history(5:8).time];
            testCase.verifyLessThan(max(touchdownTimes) - min(touchdownTimes), 1e-7);
            testCase.verifyLessThan(max(liftoffTimes) - min(liftoffTimes), 1e-7);
        end

        function pseudoArclengthCorrectsStateAndParameter(testCase)
            % Exercise the second continuation mode on the line u-mu=0.
            residual = @(u, p, q) u - p(1);
            solver = RootSolver_v3(struct('Algorithm', 'newton'));
            continuation = PseudoArclengthContinuation_v3(struct( ...
                'RootSolver', solver, ...
                'ActiveParameterIndex', 1, ...
                'StepSize', 0.1, ...
                'MaxPoints', 4, ...
                'InitialDirection', 1));
            branch = continuation.run(residual, 0, 0, []);
            testCase.verifyEqual(branch.count, 4);
            testCase.verifyLessThan(max(abs(branch.x - branch.p)), 1e-8);
        end

        function finiteDifferenceUsesAdaptiveScale(testCase)
            finiteDifference = FiniteDifferenceJacobian_v3();
            x = [0; 3];
            [jacobian, ~, info] = finiteDifference.compute( ...
                @(z) [z(1)^2; sin(z(2))], x);
            expectedSteps = sqrt(eps) * (1 + abs(x));
            testCase.verifyEqual(info.steps, expectedSteps, ...
                'AbsTol', 10 * eps);
            testCase.verifyEqual(jacobian(2, 2), cos(3), ...
                'AbsTol', 2e-7);
        end
    end

    methods (Access = private)
        function [problem, map] = orderingProblem(~)
            system = createSyntheticHybridSystem_v3('ordering');
            simulator = HybridSimulator_v3(struct( ...
                'RelTol', 1e-10, 'AbsTol', 1e-12));
            section = PoincareSection_v3.apex(2);
            map = PoincareMap_v3(system, section, simulator, struct( ...
                'MaxReturnTime', 1.5, 'ArmTolerance', 1e-7));
            problem = PeriodicOrbitResidual_v3(map, [1; 0]);
        end
    end
end
