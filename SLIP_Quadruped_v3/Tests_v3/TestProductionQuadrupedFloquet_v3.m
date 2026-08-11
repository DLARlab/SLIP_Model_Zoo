classdef TestProductionQuadrupedFloquet_v3 < matlab.unittest.TestCase
    % External step-grid convergence on an executed quadruped orbit.

    properties
        Study
    end

    methods (TestClassSetup)
        function loadExecutedStudy(testCase)
            v3Root = fileparts(fileparts(mfilename('fullpath')));
            artifact = fullfile(v3Root, 'Examples_v3', 'Results_v3', ...
                'Round4_Quadruped_Production_Study_v3.mat');
            testCase.assertTrue(isfile(artifact), ...
                'Executed production Floquet artifact is missing.');
            data = load(artifact, 'study');
            testCase.Study = data.study;
        end
    end

    methods (Test)
        function externalGridsAreReliableAndConverged(testCase)
            floquet = testCase.Study.floquet;
            testCase.verifyTrue(floquet.attempted);
            testCase.verifyEqual(floquet.status, 'passed');
            testCase.verifyTrue(floquet.converged);
            testCase.verifyEqual(floquet.derivative_model, ...
                'left-right-symmetry-restricted-classical');
            testCase.verifyNumElements(floquet.grid_results, 3);
            testCase.verifyTrue(all([floquet.grid_results.reliable]));
            testCase.verifyLessThan(floquet.matrix_differences(2), ...
                floquet.matrix_differences(1));
            testCase.verifyLessThan( ...
                floquet.matched_multiplier_differences(2), ...
                floquet.matched_multiplier_differences(1));
            testCase.verifyLessThan(floquet.matrix_differences(end), 1e-6);
            testCase.verifyLessThan( ...
                floquet.matched_multiplier_differences(end), 1e-8);
        end

        function everyGridStoresFullProductionDiagnostics(testCase)
            grids = testCase.Study.floquet.grid_results;
            expected = { ...
                [3e-3, 1e-3, 3e-4], ...
                [1e-3, 3e-4, 1e-4], ...
                [3e-4, 1e-4, 3e-5]};
            for index = 1:numel(grids)
                grid = grids(index);
                testCase.verifyEqual(grid.step_grid, expected{index}, ...
                    'AbsTol', eps);
                testCase.verifySize(grid.poincare_matrix, [8, 8]);
                testCase.verifyNumElements(grid.multipliers, 8);
                testCase.verifyNumElements(grid.selected_steps, 8);
                testCase.verifyNumElements( ...
                    grid.estimated_column_errors, 8);
                testCase.verifyTrue(all(grid.per_column_reliability));
                testCase.verifyGreaterThan(grid.guard_transversality, 0);
                testCase.verifyGreaterThan(grid.section_transversality, 0);
                testCase.verifyEqual(grid.return_multiplicity, 1);
                testCase.verifyGreaterThan(grid.map_evaluations, 0);
                testCase.verifyTrue(grid.cluster_preserved);
                testCase.verifyFalse(grid.hybrid_chart_boundary);
                testCase.verifyNotEmpty(grid.cyclic_signature);
                testCase.verifyNotEmpty(grid.section_relative_signature);
                testCase.verifyNotEmpty(grid.event_cluster_signature);
                testCase.verifyEqual(grid.ode_tolerances.RelTol, 1e-9);
                testCase.verifyEqual(grid.ode_tolerances.AbsTol, 1e-11);
            end
        end

        function topologyIsIdenticalAcrossExternalGrids(testCase)
            grids = testCase.Study.floquet.grid_results;
            testCase.verifyEqual(numel(unique(string( ...
                {grids.cyclic_signature}))), 1);
            testCase.verifyEqual(numel(unique(string( ...
                {grids.section_relative_signature}))), 1);
            testCase.verifyEqual(numel(unique(string( ...
                {grids.event_cluster_signature}))), 1);
            testCase.verifyTrue(all([grids.return_multiplicity] == 1));
        end

        function artifactDoesNotClaimUnrestrictedFloquetSpectrum(testCase)
            grids = testCase.Study.floquet.grid_results;
            testCase.verifyEqual(testCase.Study.floquet.derivative_model, ...
                'left-right-symmetry-restricted-classical');
            for index = 1:numel(grids)
                testCase.verifyEqual(grids(index).derivative_model, ...
                    'symmetry-restricted-classical');
            end
        end
    end
end
