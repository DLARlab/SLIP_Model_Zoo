classdef TestProductionQuadrupedContinuation_v3 < matlab.unittest.TestCase
    % Executed production evidence; the long study is not rerun in CI.

    properties (ClassSetupParameter)
        ArtifactName = {'Round4_Quadruped_Production_Study_v3.mat'}
    end

    properties
        Study
        ArtifactPath
    end

    methods (TestClassSetup)
        function loadExecutedStudy(testCase, ArtifactName)
            v3Root = fileparts(fileparts(mfilename('fullpath')));
            folders = {'Schema_v3', 'Dynamics_v3', 'Simulation_v3', ...
                'Orbit_v3', 'Numerics_v3', 'Stability_v3', 'Examples_v3'};
            for index = 1:numel(folders)
                addpath(fullfile(v3Root, folders{index}));
            end
            testCase.ArtifactPath = fullfile(v3Root, 'Examples_v3', ...
                'Results_v3', ArtifactName);
            testCase.assertTrue(isfile(testCase.ArtifactPath), ...
                ['The executed production MAT artifact is missing. Run ', ...
                 'QuadrupedalContinuationStudy_v3 explicitly.']);
            data = load(testCase.ArtifactPath, 'study');
            testCase.assertTrue(isfield(data, 'study'));
            testCase.Study = data.study;
        end
    end

    methods (Test)
        function artifactRecordsActualExecutionEnvironment(testCase)
            study = testCase.Study;
            testCase.verifyTrue(study.completed);
            testCase.verifyNotEmpty(study.executed_at);
            testCase.verifyNotEmpty(study.matlab_version);
            testCase.verifyNotEmpty(study.platform);
            testCase.verifyGreaterThan(study.total_elapsed_seconds, 0);
            testCase.verifyEqual(study.model, 'Quadrupedal_Dynamics_v3');
            testCase.verifyEqual(study.return_policy, ...
                'EventCycleReturnPolicy_v3');
            testCase.verifyFalse(study.prescribed_event_times);
            testCase.verifyFalse(study.prescribed_gait_label);
        end

        function secantPreparationIsNotCountedAsValidation(testCase)
            preparation = testCase.Study.asymmetric_seed_preparation;
            testCase.verifyEqual(preparation.status, 'prepared');
            testCase.verifyEqual(preparation.accepted_count, 9);
            testCase.verifyFalse( ...
                preparation.counted_as_validated_continuation);
            testCase.verifyEqual(preparation.derivative_model, ...
                'forward-secant-seed-preparation-only');
        end

        function topologyAwareSimpleContinuationHasTwentyPoints(testCase)
            branch = testCase.Study.simple_continuation;
            testCase.verifyEqual(branch.status, 'passed');
            testCase.verifyEqual(branch.accepted_count, 20);
            testCase.verifyEqual(branch.failure_count, 0);
            testCase.verifyTrue(branch.topology_compatible);
            testCase.verifyEqual(branch.derivative_model, ...
                'left-right-symmetry-restricted-hybrid-classical');
            testCase.verifyEqual(branch.points(1).parameter(2), 10.16, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(branch.points(end).parameter(2), 10.14, ...
                'AbsTol', 1e-12);
            testCase.verifyLessThan( ...
                max([branch.points.residual_norm]), 1e-7);
            testCase.verifyGreaterThanOrEqual( ...
                min([branch.points.minimum_physical_margin]), 0);
            testCase.verifyLessThan( ...
                max([branch.points.mode_candidates]), 16);
            testCase.verifyTrue(all( ...
                [branch.points.return_multiplicity] == 1));
            testCase.verifyEqual(numel(unique(string( ...
                {branch.points.cyclic_signature}))), 1);
            testCase.verifyEqual(numel(unique(string( ...
                {branch.points.section_relative_signature}))), 1);
            testCase.verifyEqual(numel(unique(string( ...
                {branch.points.event_cluster_signature}))), 1);
            testCase.verifyFalse(any( ...
                [branch.points.section_cluster_coincidence]));
        end

        function topologyAwarePseudoArclengthHasTwentyPoints(testCase)
            branch = testCase.Study.pseudo_arclength;
            testCase.verifyEqual(branch.status, 'passed');
            testCase.verifyEqual(branch.accepted_count, 20);
            testCase.verifyEqual(branch.failure_count, 0);
            testCase.verifyTrue(branch.topology_compatible);
            testCase.verifyEqual(branch.derivative_model, ...
                'left-right-symmetry-restricted-hybrid-classical');
            testCase.verifyLessThan( ...
                max([branch.points.residual_norm]), 1e-7);
            testCase.verifyGreaterThanOrEqual( ...
                min([branch.points.minimum_physical_margin]), 0);
            testCase.verifyGreaterThan(abs( ...
                branch.points(end).parameter(2) - ...
                branch.points(1).parameter(2)), 0.1);
            testCase.verifyEqual(numel(unique(string( ...
                {branch.points.event_cluster_signature}))), 1);
            testCase.verifyFalse(any( ...
                [branch.points.section_cluster_coincidence]));
        end

        function defaultHybridRootMakesMandatoryCorrection(testCase)
            root = testCase.Study.default_hybrid_root;
            testCase.verifyTrue(root.constructed_without_jacobian_override);
            testCase.verifyEqual(root.jacobian_class, ...
                'HybridFiniteDifferenceJacobian_v3');
            testCase.verifyEqual(root.status, 'passed');
            testCase.verifyTrue(root.converged);
            testCase.verifyGreaterThan(root.initial_residual_norm, 1e-7);
            testCase.verifyLessThan(root.final_residual_norm, 1e-7);
            testCase.verifyGreaterThanOrEqual(root.jacobian_evaluations, 1);
            testCase.verifyGreaterThanOrEqual( ...
                root.accepted_newton_iterations, 1);
            testCase.verifyGreaterThan(root.map_evaluations, 0);
            testCase.verifyGreaterThanOrEqual( ...
                root.function_evaluations, root.map_evaluations);
            testCase.verifyGreaterThanOrEqual(root.cache_hits, 0);
            testCase.verifyTrue(all(root.per_column_reliability));
            testCase.verifyNumElements(root.selected_steps, 9);
            testCase.verifyNumElements(root.mode_candidates, 1);
            testCase.verifyNotEmpty(root.cyclic_signature);
            testCase.verifyNotEmpty(root.section_relative_signature);
            testCase.verifyNotEmpty(root.event_cluster_signature);
        end

        function physicalCasesAreNotInferredFromDisabledSearch(testCase)
            search = testCase.Study.physical_search;
            if ~search.attempted
                testCase.verifyEqual(search.status, 'not-run');
                testCase.verifyFalse(search.found_grounded_apex);
                testCase.verifyFalse(search.found_multiple_apex);
                testCase.verifyFalse(search.found_section_mode_transition);
                return
            end
            testCase.verifyNotEmpty(search.parameter_ranges);
            testCase.verifyTrue( ...
                search.non_simultaneous_orbit_search.attempted);
            if ~search.found_non_simultaneous_orbit
                attempts = search.non_simultaneous_orbit_search.attempts;
                testCase.verifyGreaterThanOrEqual(numel(attempts), 1);
                testCase.verifyFalse(any( ...
                    [attempts.all_event_clusters_singleton]));
            end
            if search.found_multiple_apex
                testCase.verifyTrue( ...
                    search.multiple_apex_policy_comparison.validated);
            end
            if isfield(search, 'refined_section_coincidence') && ...
                    search.refined_section_coincidence
                testCase.verifyTrue( ...
                    search.section_mode_transition.exact_coincidence);
            end
        end
    end
end
