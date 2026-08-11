classdef TestEventClusterDerivative_v3 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addFrameworkPaths(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            folders = {'Schema_v3', 'Dynamics_v3', 'Numerics_v3', ...
                'Stability_v3', 'Tests_v3'};
            for index = 1:numel(folders)
                addpath(fullfile(root, folders{index}));
            end
        end
    end

    methods (Test)
        function incompatibleOrderingLimitsRemainASet(testCase)
            orderings(1) = struct('name', 'A-then-B', ...
                'signature', 'A>B', ...
                'callback', @TestEventClusterDerivative_v3.orderAB);
            orderings(2) = struct('name', 'B-then-A', ...
                'signature', 'B>A', ...
                'callback', @TestEventClusterDerivative_v3.orderBA);
            derivative = EventClusterDerivative_v3(struct( ...
                'AgreementTolerance', 1e-8));
            result = derivative.compute(orderings, zeros(2, 1));

            testCase.verifyTrue(result.allLimitsReliable);
            testCase.verifyFalse(result.classicalUnique);
            testCase.verifyFalse(result.reliable);
            testCase.verifyEmpty(result.uniqueClassicalMatrix);
            testCase.verifyEmpty(result.multipliers);
            testCase.verifyGreaterThan( ...
                result.maximumOrderingDifference, 0.5);
            testCase.verifyEqual(numel(result.orderingLimits), 2);
        end

        function commutingOrderingLimitsDefineOneMatrix(testCase)
            orderings(1) = struct('name', 'A-then-B', ...
                'signature', 'A>B', ...
                'callback', @TestEventClusterDerivative_v3.commutingAB);
            orderings(2) = struct('name', 'B-then-A', ...
                'signature', 'B>A', ...
                'callback', @TestEventClusterDerivative_v3.commutingBA);
            result = EventClusterDerivative_v3().compute( ...
                orderings, zeros(2, 1));

            expected = diag([0.8, 0.6]);
            testCase.verifyTrue(result.classicalUnique);
            testCase.verifyTrue(result.reliable);
            testCase.verifyEqual(result.uniqueClassicalMatrix, expected, ...
                'AbsTol', 1e-10);
            testCase.verifyEqual(sort(result.multipliers), [0.6; 0.8], ...
                'AbsTol', 1e-10);
        end

        function enumeratesAllAdmissibleNearbyOrderings(testCase)
            derivative = EventClusterDerivative_v3();
            orderings = derivative.enumerateOrderings( ...
                ["A", "B"], ...
                @TestEventClusterDerivative_v3.orderingFactory);

            testCase.verifyNumElements(orderings, 2);
            testCase.verifyEqual(sort(string({orderings.signature})), ...
                sort(["A>B", "B>A"]));
            result = derivative.compute(orderings, zeros(2, 1));
            testCase.verifyFalse(result.classicalUnique);
            testCase.verifyEqual(sort(string( ...
                result.admissibleOrderings)), sort(["A>B", "B>A"]));
        end

        function quadrupedModelEnumerationVerifiesResetLimits(testCase)
            system = Quadrupedal_Dynamics_v3();
            [state, parameter] = ...
                TestEventClusterDerivative_v3.quadrupedFixture();
            mode = false(4, 1);
            factory = @(sequence, trace) @(point, varargin) ...
                TestEventClusterDerivative_v3.quadrupedResetLimit( ...
                    point, system, sequence, mode, parameter); %#ok<INUSD>
            cone = @(sequence, trace) true; %#ok<NASGU,INUSD>
            derivative = EventClusterDerivative_v3(struct( ...
                'AgreementTolerance', 1e-6));
            result = derivative.computeModelCluster(system, ...
                {'BL_TD', 'FR_TD'}, 0, state, mode, parameter, ...
                factory, state, cone);

            testCase.verifyNumElements(result.orderingLimits, 2);
            testCase.verifyTrue(result.resetOrdersCommute);
            testCase.verifyFalse(result.guardConeResolved);
            testCase.verifyTrue(result.conePredicateSupplied);
            testCase.verifyTrue(result.resetOnlyClassicalUnique);
            testCase.verifyFalse(result.classicalUnique);
            testCase.verifyFalse(result.reliable);
            testCase.verifyEmpty(result.uniqueClassicalMatrix);
            testCase.verifyLessThanOrEqual(result. ...
                modelOrderingDiagnostics.maximum_reset_order_difference, ...
                1e-13);
            testCase.verifyEqual(result.modelOrderingDiagnostics. ...
                batch_info.semantics, ...
                "commuting-independent-leg-resets");
        end

        function explicitGuardConeResolutionAllowsUniqueLimit(testCase)
            system = Quadrupedal_Dynamics_v3();
            [state, parameter] = ...
                TestEventClusterDerivative_v3.quadrupedFixture();
            mode = false(4, 1);
            factory = @(sequence, trace) @(point, varargin) ...
                TestEventClusterDerivative_v3.quadrupedResetLimit( ...
                    point, system, sequence, mode, parameter); %#ok<INUSD>
            derivative = EventClusterDerivative_v3(struct( ...
                'AgreementTolerance', 1e-6));
            result = derivative.computeModelCluster(system, ...
                {'BL_TD', 'FR_TD'}, 0, state, mode, parameter, ...
                factory, state, ...
                @TestEventClusterDerivative_v3.resolvedCone);

            testCase.verifyTrue(result.guardConeResolved);
            testCase.verifyTrue(result.classicalUnique);
            testCase.verifyTrue(result.reliable);
            testCase.verifyNotEmpty(result.uniqueClassicalMatrix);
        end
    end

    methods (Static, Access = private)
        function [value, metadata] = orderAB(point, varargin)
            value = [1, 1; 0, 1] * point(:);
            metadata = TestEventClusterDerivative_v3.metadata('A>B');
        end

        function [value, metadata] = orderBA(point, varargin)
            value = [1, 0; 1, 1] * point(:);
            metadata = TestEventClusterDerivative_v3.metadata('B>A');
        end

        function [value, metadata] = commutingAB(point, varargin)
            value = diag([0.8, 0.6]) * point(:);
            metadata = TestEventClusterDerivative_v3.metadata('A>B');
        end

        function [value, metadata] = commutingBA(point, varargin)
            value = diag([0.8, 0.6]) * point(:);
            metadata = TestEventClusterDerivative_v3.metadata('B>A');
        end

        function callback = orderingFactory(sequence)
            if string(sequence{1}) == "A"
                callback = @TestEventClusterDerivative_v3.orderAB;
            else
                callback = @TestEventClusterDerivative_v3.orderBA;
            end
        end

        function metadata = metadata(signature)
            metadata = struct( ...
                'integration_success', true, ...
                'discrete_closed', true, ...
                'cycle_complete', true, ...
                'return_policy_accepted', true, ...
                'return_multiplicity', 1, ...
                'cyclic_event_signature', signature, ...
                'section_relative_event_signature', signature, ...
                'event_cluster_signature', 'A&B', ...
                'guard_transversality_margin', 1, ...
                'section_transversality', 1);
        end


        function [value, metadata] = quadrupedResetLimit( ...
                point, system, sequence, mode, parameter)
            value = point(:);
            qwork = mode;
            for index = 1:numel(sequence)
                value = system.reset( ...
                    sequence{index}, 0, value, qwork, parameter);
                qwork = system.transition(sequence{index}, qwork);
            end
            signature = strjoin(string(sequence), '>');
            metadata = TestEventClusterDerivative_v3.metadata( ...
                char(signature));
            metadata.event_cluster_signature = 'BL_TD&FR_TD';
        end

        function [accepted, info] = resolvedCone(sequence, trace) %#ok<INUSD>
            accepted = true;
            info = struct('resolved', true, ...
                'method', 'analytic synthetic cone certificate');
        end

        function [state, parameter] = quadrupedFixture()
            state = [ ...
                0; 0.45; 0.90; -0.05; 0.08; 0.20; ...
                -0.10; 0.03; 0.02; -0.04; ...
                -0.10; 0.03; 0.02; -0.04];
            parameter = [100; 80; 4; 9; 1.0; 1.1; ...
                0.1; -0.2; 2; 0.45];
        end
    end
end
