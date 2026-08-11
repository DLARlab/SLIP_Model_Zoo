classdef TestSymmetryFloquet_v3 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addFrameworkPaths(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            folders = {'Schema_v3', 'Dynamics_v3', 'Simulation_v3', ...
                'Orbit_v3', 'Numerics_v3', 'Stability_v3', 'Tests_v3'};
            for index = 1:numel(folders)
                addpath(fullfile(root, folders{index}));
            end
        end
    end

    methods (Test)
        function invariantAndComplementBasesAreConstructed(testCase)
            action = [0, 1; 1, 0];
            subspace = SymmetrySubspace_v3(action, ...
                struct('Name', 'exchange-fixed'));

            testCase.verifyEqual(subspace.dimension(), 1);
            testCase.verifyLessThan(norm(action * subspace.Basis - ...
                subspace.Basis), 1e-12);
            testCase.verifyLessThan(norm(subspace.Basis.' * ...
                subspace.ComplementBasis), 1e-12);
            testCase.verifyTrue(subspace.contains([1; 1]));
            testCase.verifyFalse(subspace.contains([1; -1]));
        end

        function symmetryRestrictedMultiplierUsesSuppliedBasis(testCase)
            fixed = SymmetrySubspace_v3([0, 1; 1, 0], ...
                struct('Name', 'exchange-fixed'));
            analyzer = SymmetryRestrictedFloquet_v3(fixed, struct( ...
                'BlockName', 'symmetric'));
            result = analyzer.analyze( ...
                @TestSymmetryFloquet_v3.exchangeEquivariantMap, ...
                zeros(2, 1), 0, 0);

            testCase.verifyTrue(result.reliable);
            testCase.verifyTrue(result.symmetryRestricted);
            testCase.verifyEqual(result.derivativeModel, ...
                'symmetry-restricted-classical');
            testCase.verifyEqual(result.multipliers, 0.8, 'AbsTol', 1e-10);
            testCase.verifyEqual(result.poincareMatrix, 0.8, ...
                'AbsTol', 1e-10);
            testCase.verifyTrue(result.clusterPreserved);
            testCase.verifySize(result.symmetryBasis, [2, 1]);
        end

        function complementaryBlockHasDifferentMultiplier(testCase)
            antisymmetric = SymmetrySubspace_v3.fromBasis([1; -1], ...
                struct('Name', 'exchange-antisymmetric'));
            analyzer = SymmetryRestrictedFloquet_v3(antisymmetric, ...
                struct('BlockName', 'antisymmetric'));
            result = analyzer.analyze( ...
                @TestSymmetryFloquet_v3.exchangeEquivariantMap, ...
                zeros(2, 1), 0, 0);

            testCase.verifyTrue(result.reliable);
            testCase.verifyEqual(result.multipliers, 0.4, 'AbsTol', 1e-10);
            testCase.verifyEqual(result.symmetryBlock, 'antisymmetric');
        end

        function rejectedCoarseClusterTrialsDoNotInvalidateFinePlateau(testCase)
            fixed = SymmetrySubspace_v3([0, 1; 1, 0], ...
                struct('Name', 'exchange-fixed'));
            analyzer = SymmetryRestrictedFloquet_v3(fixed);
            result = analyzer.analyze( ...
                @TestSymmetryFloquet_v3.scaleSensitiveClusterMap, ...
                zeros(2, 1), 0, 0);

            testCase.verifyTrue(result.reliable);
            testCase.verifyTrue(result.clusterPreserved);
            testCase.verifyLessThanOrEqual( ...
                result.finiteDifference.selectedSteps(1), 1e-4);
            exploratorySignatures = arrayfun(@(entry) string( ...
                entry.mapInfo.event_cluster_signature), ...
                result.perturbations);
            testCase.verifyTrue(any(exploratorySignatures == "A>B"));
        end

        function transverseLeakageRejectsFalseSymmetryBlock(testCase)
            fixed = SymmetrySubspace_v3([0, 1; 1, 0], ...
                struct('Name', 'exchange-fixed'));
            analyzer = SymmetryRestrictedFloquet_v3(fixed);
            result = analyzer.analyze( ...
                @TestSymmetryFloquet_v3.nonEquivariantMap, ...
                zeros(2, 1), 0, 0);

            testCase.verifyFalse(result.reliable);
            testCase.verifyFalse(result.subspaceInvariant);
            testCase.verifyGreaterThan( ...
                result.selectedSubspaceLeakage, 1e-2);
            testCase.verifyNotEmpty(result.warning);
        end

        function quadrupedSectionBasisExcludesGaugeAndPhase(testCase)
            schema = QuadrupedSchema_v3.shared();
            subspace = SymmetrySubspace_v3.quadrupedSectionTangent(schema);

            testCase.verifyEqual(subspace.AmbientDimension, 14);
            testCase.verifyEqual(subspace.dimension(), 8);
            testCase.verifyEqual(subspace.Basis(schema.State.x, :), ...
                zeros(1, 8), 'AbsTol', 1e-12);
            testCase.verifyEqual(subspace.Basis(schema.State.dy, :), ...
                zeros(1, 8), 'AbsTol', 1e-12);
            testCase.verifyLessThan(norm( ...
                subspace.Basis(schema.State.alphaBL, :) - ...
                subspace.Basis(schema.State.alphaBR, :)), 1e-12);
            testCase.verifyLessThan(norm( ...
                subspace.Basis(schema.State.alphaFL, :) - ...
                subspace.Basis(schema.State.alphaFR, :)), 1e-12);
        end
    end

    methods (Static, Access = private)
        function [next, metadata] = exchangeEquivariantMap(state, varargin)
            matrix = [0.6, 0.2; 0.2, 0.6];
            next = matrix * state(:);
            metadata = struct( ...
                'integration_success', true, ...
                'discrete_closed', true, ...
                'cycle_complete', true, ...
                'return_policy_accepted', true, ...
                'return_multiplicity', 1, ...
                'cyclic_event_signature', 'A&B', ...
                'section_relative_event_signature', 'A&B', ...
                'event_cluster_signature', '[A&B]', ...
                'guard_transversality_margin', 1, ...
                'section_transversality', 1);
        end


        function [next, metadata] = scaleSensitiveClusterMap(state, varargin)
            [next, metadata] = ...
                TestSymmetryFloquet_v3.exchangeEquivariantMap(state);
            if norm(state(:), 2) > 2e-4
                metadata.event_cluster_signature = 'A>B';
            end
        end

        function [next, metadata] = nonEquivariantMap(state, varargin)
            next = diag([0.8, 0.6]) * state(:);
            [~, metadata] = ...
                TestSymmetryFloquet_v3.exchangeEquivariantMap(state);
        end
    end
end
