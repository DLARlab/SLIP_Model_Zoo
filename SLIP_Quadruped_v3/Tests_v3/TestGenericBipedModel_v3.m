classdef TestGenericBipedModel_v3 < matlab.unittest.TestCase
    %TESTGENERICBIPEDMODEL_V3 Second-model generic-pipeline regression.

    properties
        V3Root
        Orbit
        Report
        Framework
    end

    methods (TestClassSetup)
        function configureAndSolve(testCase)
            testCase.V3Root = fileparts(fileparts(mfilename('fullpath')));
            folders = {'Dynamics_v3', 'Simulation_v3', 'Orbit_v3', ...
                'Numerics_v3', 'Stability_v3', 'Examples_v3', ...
                fullfile('Examples_v3', 'Models'), 'Tests_v3'};
            for index = 1:numel(folders)
                addpath(fullfile(testCase.V3Root, folders{index}));
            end
            [testCase.Orbit, testCase.Report, testCase.Framework] = ...
                BipedalHybridExample_v3();
        end
    end

    methods (Test)
        function modelUsesIndependentDimensionsAndMetadata(testCase)
            model = testCase.Framework.system;
            testCase.verifyTrue(isa(model, 'HybridSystemBase_v3'));
            testCase.verifyEqual(model.StateDimension, 2);
            testCase.verifyEqual(model.ParameterDimension, 5);
            testCase.verifyNotEqual(model.StateDimension, 14);
            testCase.verifyNotEqual(model.ParameterDimension, 10);
            testCase.verifyEqual(model.StateNames, {'y', 'dy'});
            testCase.verifyEqual(model.ParameterNames{5}, ...
                'liftoff_impulse');
            testCase.verifyFalse(isprop(model, 'Schema'));
            source = fileread(which('BipedalHybridModel_v3'));
            testCase.verifyFalse(contains(source, 'QuadrupedSchema_v3'));
        end

        function fullStrideIsDiscoveredFromPhysicalEvents(testCase)
            orbit = testCase.Orbit;
            report = testCase.Report;
            testCase.verifyEqual(report.event_sequence, ...
                ["L_TD"; "L_LO"; "R_TD"; "R_LO"]);
            testCase.verifyEqual(orbit.initial_mode, ...
                BipedalHybridModel_v3.LEFT_FLIGHT);
            testCase.verifyEqual(orbit.return_multiplicity, 2);
            testCase.verifyEqual(report.candidate_apex_count, 2);
            testCase.verifyEqual(report.accepted_apex_index, 2);
            testCase.verifyClass(testCase.Framework.return_policy, ...
                'BipedStrideReturnPolicy_v3');
            testCase.verifyEqual(orbit.return_policy_name, ...
                'alternating-biped-stride-return');
            testCase.verifyEqual(numel(orbit.event_history), 4);
            for index = 1:numel(orbit.event_history)
                metadata = orbit.event_history(index).metadata;
                testCase.verifyTrue(isfield(metadata, 'leg_index'));
                testCase.verifyTrue(isfield(metadata, 'event_kind'));
                testCase.verifyEqual(metadata.source, 'biped-contact');
            end
            testCase.verifyEqual(orbit.initial_mode, ...
                orbit.mode_history{end});
        end

        function modelContainsDissipationAndActiveEnergyInput(testCase)
            model = testCase.Framework.system;
            p = BipedalHybridModel_v3.defaultParameters();
            touchdown = model.reset(model.LEFT_TOUCHDOWN, 0, ...
                [0; -2], model.LEFT_FLIGHT, p);
            liftoff = model.reset(model.LEFT_LIFTOFF, 0, ...
                [0; 1], model.LEFT_STANCE, p);
            testCase.verifyEqual(touchdown(2), -2 * p(4), ...
                'AbsTol', 1e-14);
            testCase.verifyLessThan(abs(touchdown(2)), 2);
            testCase.verifyEqual(liftoff(2), 1 + p(5), ...
                'AbsTol', 1e-14);
            stanceFlow = model.flow(0, [-0.01; 1], ...
                model.LEFT_STANCE, p);
            undampedAcceleration = -p(1) - p(2) * (-0.01);
            testCase.verifyEqual(stanceFlow(2), ...
                undampedAcceleration - p(3), 'AbsTol', 1e-14);
        end

        function rootSolveRequiresAndAcceptsCorrections(testCase)
            report = testCase.Report;
            testCase.verifyTrue(report.converged);
            testCase.verifyGreaterThan(report.initial_residual_norm, 1e-3);
            testCase.verifyLessThan(report.residual_norm, 1e-8);
            testCase.verifyGreaterThanOrEqual( ...
                report.solve_info.output.acceptedIterations, 1);
            testCase.verifyGreaterThanOrEqual( ...
                report.solve_info.jacobianEvaluationCount, 1);
            testCase.verifyGreaterThan( ...
                norm(report.solve_info.state - ...
                    report.solve_info.initialGuess, inf), 1e-3);
            testCase.verifyTrue(report.solve_info.evaluationInfo.cycle_complete);
            testCase.verifyTrue( ...
                report.solve_info.evaluationInfo.discrete_closed);
        end

        function continuationAndFloquetUseGenericPipeline(testCase)
            branch = testCase.Report.branch;
            floquet = testCase.Report.floquet;
            testCase.verifyTrue(branch.success);
            testCase.verifyEqual(branch.count, 3);
            testCase.verifyEqual(branch.activeParameter, ...
                'liftoff_impulse');
            testCase.verifyLessThan( ...
                max([branch.points.residualNorm]), 1e-8);
            testCase.verifyEqual(branch.return_multiplicity, [2, 2, 2]);
            testCase.verifyTrue(all(cellfun(@(history) ...
                numel(history) == 4, branch.event_history)));
            testCase.verifySize(floquet.poincareMatrix, [1, 1]);
            testCase.verifyTrue(floquet.reliable);
            testCase.verifyTrue(isfinite(floquet.multipliers));
            testCase.verifyLessThan(abs(floquet.multipliers), 1);
            testCase.verifyEqual(floquet.return_multiplicity, 2);
        end

        function genericNumericsDoNotInspectQuadrupedSchema(testCase)
            directories = { ...
                fullfile(testCase.V3Root, 'Numerics_v3')};
            files = strings(0, 1);
            for directoryIndex = 1:numel(directories)
                listing = dir(fullfile(directories{directoryIndex}, '*.m'));
                for fileIndex = 1:numel(listing)
                    files(end + 1, 1) = fullfile( ...
                        listing(fileIndex).folder, ...
                        listing(fileIndex).name); %#ok<AGROW>
                end
            end
            explicitGenericFiles = { ...
                fullfile(testCase.V3Root, 'Dynamics_v3', ...
                    'HybridSystemBase_v3.m'), ...
                fullfile(testCase.V3Root, 'Simulation_v3', ...
                    'HybridSimulator_v3.m'), ...
                fullfile(testCase.V3Root, 'Orbit_v3', ...
                    'PoincareMap_v3.m'), ...
                fullfile(testCase.V3Root, 'Stability_v3', ...
                    'FloquetAnalysis_v3.m')};
            files = [files; string(explicitGenericFiles(:))];
            offenders = strings(0, 1);
            for index = 1:numel(files)
                if contains(fileread(files(index)), 'QuadrupedSchema_v3')
                    offenders(end + 1, 1) = files(index); %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(offenders, sprintf( ...
                'Generic pipeline source inspected QuadrupedSchema_v3:\n%s', ...
                strjoin(cellstr(offenders), newline)));
        end
    end
end
