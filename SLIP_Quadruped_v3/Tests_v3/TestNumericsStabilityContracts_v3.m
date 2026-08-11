classdef TestNumericsStabilityContracts_v3 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addFrameworkPaths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            folders = {'Dynamics_v3', 'Schema_v3', 'Simulation_v3', ...
                'Orbit_v3', 'Numerics_v3', 'Stability_v3', 'Tests_v3'};
            for index = 1:numel(folders)
                addpath(fullfile(root, folders{index}));
            end
        end
    end

    methods (Test)
        function hybridFiniteDifferenceSelectsRefinedPlateau(testCase)
            finiteDifference = HybridFiniteDifferenceJacobian_v3(struct( ...
                'RelativeCandidateSteps', [1e-3, 3e-4, 1e-4], ...
                'MaximumRelativeError', 1e-3));
            [jacobian, ~, report] = finiteDifference.compute( ...
                @TestNumericsStabilityContracts_v3.cubicHybridMap, 2);

            testCase.verifyEqual(jacobian, 12, 'AbsTol', 1e-8);
            testCase.verifyTrue(report.allReliable);
            testCase.verifyGreaterThan(report.selectedSteps(1), sqrt(eps));
            testCase.verifyEqual(report.columns(1).differenceType, ...
                'central-richardson');
            testCase.verifyGreaterThan(report.mapEvaluations, 1);
        end

        function hybridFiniteDifferenceLabelsOneSidedTopology(testCase)
            finiteDifference = HybridFiniteDifferenceJacobian_v3(struct( ...
                'RelativeCandidateSteps', [1e-3, 1e-4], ...
                'AllowOneSided', true));
            [jacobian, ~, report] = finiteDifference.compute( ...
                @TestNumericsStabilityContracts_v3.piecewiseSignatureMap, 0);

            testCase.verifyEqual(jacobian, 1, 'AbsTol', 1e-10);
            testCase.verifyTrue(report.columns(1).oneSided);
            testCase.verifyEqual(report.columns(1).differenceType, ...
                'one-sided-backward');
            testCase.verifyFalse(report.columns(1).reliable);
            testCase.verifyFalse(report.classicalDerivative);
        end

        function hybridFiniteDifferenceTracksReturnMultiplicity(testCase)
            finiteDifference = HybridFiniteDifferenceJacobian_v3(struct( ...
                'RelativeCandidateSteps', [1e-3, 1e-4], ...
                'AllowOneSided', true));
            [~, ~, report] = finiteDifference.compute( ...
                @TestNumericsStabilityContracts_v3.multiplicityBoundaryMap, 0);

            testCase.verifyFalse(report.returnMultiplicityPreserved);
            testCase.verifyFalse( ...
                report.columns(1).returnMultiplicityPreserved);
            testCase.verifyEqual( ...
                report.columns(1).returnMultiplicities, [2, 1, 2, 1]);
            testCase.verifyFalse(report.classicalDerivative);
        end

        function floquetDerivativeConvergesUnderExternalStepRefinement(testCase)
            % Requirement G: refine the complete accepted-cycle map from
            % outside the h/h/2 estimator and verify derivative convergence.
            gamma = 0.3;
            system = createSyntheticReturnPolicySystem_v3( ...
                'two-apex-radial');
            simulator = HybridSimulator_v3(struct( ...
                'RelTol', 1e-11, 'AbsTol', 1e-13));
            section = PoincareSection_v3.apex(2);
            mapOptions = struct('MaxReturnTime', 2.5, ...
                'MaxSectionCrossings', 4, 'MaxCycleEvents', 8, ...
                'ArmTolerance', 1e-7);
            map = PoincareMap_v3(system, section, simulator, ...
                EventCycleReturnPolicy_v3(), mapOptions);

            relativeSteps = [4e-2, 2e-2, 1e-2];
            expected = exp(-4 * gamma);
            errors = zeros(size(relativeSteps));
            selectedSteps = zeros(size(relativeSteps));

            for index = 1:numel(relativeSteps)
                result = FloquetAnalysis_v3(struct( ...
                    'TangentIndices', 1, ...
                    'RelativeStep', relativeSteps(index))).analyze( ...
                        map, [1; 0], 0, gamma);
                errors(index) = abs(result.multipliers(1) - expected);
                selectedSteps(index) = ...
                    result.finiteDifference.selectedSteps(1);

                testCase.verifyTrue(result.reliable);
                testCase.verifyTrue(result.finiteDifference.allReliable);
                testCase.verifyEqual(result.return_multiplicity, 2);
                testCase.verifyEqual(result.baseMapInfo.period, 2, ...
                    'AbsTol', 3e-7);
                testCase.verifyEqual(string(result.finiteDifference. ...
                    columns(1).differenceType), "central-richardson");
                testCase.verifyFalse(result.finiteDifference. ...
                    columns(1).oneSided);
            end

            testCase.verifyLessThan(diff(selectedSteps), zeros(1, 2));
            testCase.verifyLessThan(diff(errors), zeros(1, 2));
            testCase.verifyGreaterThan( ...
                errors(1:end-1) ./ errors(2:end), 8 * ones(1, 2));
            testCase.verifyLessThan(errors(end), 1e-8);
        end

        function floquetRejectsMissingHybridTopologyEvidence(testCase)
            analyzer = FloquetAnalysis_v3(struct('TangentIndices', 1));
            testCase.verifyError(@() analyzer.analyze( ...
                @TestNumericsStabilityContracts_v3.metadataFreeMap, ...
                1, 0, 0), ...
                'HybridFiniteDifferenceJacobian_v3:InvalidBase');
        end

        function floquetRejectsMissingSectionSignatureEvidence(testCase)
            analyzer = FloquetAnalysis_v3(struct('TangentIndices', 1));
            testCase.verifyError(@() analyzer.analyze( ...
                @TestNumericsStabilityContracts_v3.missingSectionMap, ...
                1, 0, 0), ...
                'HybridFiniteDifferenceJacobian_v3:InvalidBase');
        end

        function floquetReadsCanonicalTrajectoryEventTypes(testCase)
            result = FloquetAnalysis_v3(struct( ...
                'TangentIndices', 1)).analyze( ...
                    @TestNumericsStabilityContracts_v3.trajectoryHistoryMap, ...
                    1, 0, 0);

            testCase.verifyTrue(result.reliable);
            testCase.verifyEqual(result.eventSignature, 'A>B');
            testCase.verifyTrue(result.eventSignaturesMatch);
        end

        function sectionChartChangeRejectsClassicalFloquet(testCase)
            analyzer = FloquetAnalysis_v3(struct('TangentIndices', 1));
            result = analyzer.analyze( ...
                @TestNumericsStabilityContracts_v3.sectionChartBoundaryMap, ...
                0, 0, 0);

            testCase.verifyFalse(result.reliable);
            testCase.verifyTrue(result.eventSignaturesMatch);
            testCase.verifyFalse(result.sectionSignaturesMatch);
            testCase.verifyTrue(result.hybridChartBoundary);
            testCase.verifyEqual(result.eventSignature, 'FR_LO');
            testCase.verifyEqual(sort(string( ...
                result.adjacentSectionSignatures)), ...
                sort(["Apex<FR_LO", "FR_LO<Apex"]));
            testCase.verifyFalse(result.finiteDifference.classicalDerivative);
            testCase.verifyTrue(result.finiteDifference.columns(1).oneSided);
            testCase.verifyTrue(isfinite(result.poincareMatrix));
            testCase.verifyTrue(result.forwardOneSidedAvailable);
            testCase.verifyTrue(result.backwardOneSidedAvailable);
            testCase.verifyEqual(result.forwardOneSidedPoincareMatrix, 1, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(result.backwardOneSidedPoincareMatrix, 1, ...
                'AbsTol', 1e-12);
            selected = result.finiteDifference.columns(1).candidates( ...
                result.finiteDifference.columns(1).selectedCandidate);
            testCase.verifyEqual( ...
                selected.forwardOneSided.sectionSignature, 'Apex<FR_LO');
            testCase.verifyEqual( ...
                selected.backwardOneSided.sectionSignature, 'FR_LO<Apex');
        end

        function rootSolverReportsCacheAndMapCounts(testCase)
            solver = RootSolver_v3(struct( ...
                'Algorithm', 'newton', 'FunctionTolerance', 1e-11, ...
                'ResidualAcceptanceTolerance', 1e-9));
            [root, result] = solver.solve(@(u, p, q) u.^2 - 1, ...
                1.2, zeros(0, 1), []);

            testCase.verifyTrue(result.converged);
            testCase.verifyEqual(root, 1, 'AbsTol', 1e-8);
            testCase.verifyGreaterThan(result.mapEvaluationCount, 0);
            testCase.verifyGreaterThan(result.cacheHitCount, 0);
            testCase.verifyGreaterThanOrEqual(result.functionEvaluationCount, ...
                result.mapEvaluationCount);
            testCase.verifyEqual(result.derivativeModel, ...
                'hybrid-topology-compatible-finite-difference');
            testCase.verifyGreaterThan(result.jacobianEvaluationCount, 0);
            testCase.verifyGreaterThan(result.acceptedNewtonIterations, 0);
            testCase.verifyNotEmpty(result.selectedFiniteDifferenceSteps);
            testCase.verifyTrue(all(result.perColumnReliability));
        end

        function fourArgumentResidualReceivesDefaultContext(testCase)
            residual = @(u, p, q, context) ...
                u - 1 + 0 * numel(fieldnames(context));
            solver = RootSolver_v3(struct( ...
                'Algorithm', 'newton', 'FunctionTolerance', 1e-10));
            [root, result] = solver.solve(residual, 1.1, [], []);
            testCase.verifyTrue(result.converged);
            testCase.verifyEqual(root, 1, 'AbsTol', 1e-8);
        end

        function continuationAcceptsParameterName(testCase)
            residual = struct();
            residual.Map = struct('System', struct( ...
                'ParameterNames', {{'first', 'second'}}));
            residual.evaluate = @(u, p, q) u - p(2);
            residual.fullState = @(u, varargin) u;
            solver = RootSolver_v3(struct('Algorithm', 'newton'));
            continuation = NumericalContinuation1D_v3(struct( ...
                'RootSolver', solver, 'ActiveParameter', 'second'));
            branch = continuation.run( ...
                residual, 0, [0; 0], [], [0, 0.1, 0.2]);

            testCase.verifyEqual(branch.activeParameter, 'second');
            testCase.verifyEqual(branch.activeParameterIndex, 2);
            testCase.verifyEqual(branch.x, [0, 0.1, 0.2], 'AbsTol', 1e-8);
        end

        function pseudoArclengthRejectsInitialHybridChartBoundary(testCase)
            metadata = TestNumericsStabilityContracts_v3.validMetadata('A');
            metadata.section_cluster_coincidence = true;
            metadata.return_policy_accepted = true;
            residual = @(u, p, q, context) deal( ...
                u - p(1) + 0 * numel(fieldnames(context)), metadata);
            continuation = PseudoArclengthContinuation_v3(struct( ...
                'RootSolver', RootSolver_v3(struct('Algorithm', 'newton')), ...
                'ActiveParameterIndex', 1, 'MaxPoints', 2));

            testCase.verifyError(@() continuation.run( ...
                residual, 0, 0, []), ...
                'PseudoArclengthContinuation_v3:InitialTopologyBoundary');
        end

        function bifurcationNamesAreCandidates(testCase)
            angle = 0.4;
            multipliers = [ ...
                 0.8,  1.2; ...
                -0.8, -1.2; ...
                 0.9 * exp(1i * angle), 1.1 * exp(1i * angle); ...
                 0.9 * exp(-1i * angle), 1.1 * exp(-1i * angle)];
            detector = BifurcationDetector_v3();
            events = detector.detect(multipliers, [0, 1]);
            types = string({events.type});

            testCase.verifyTrue(any(types == "unit_multiplier_candidate"));
            testCase.verifyTrue(any(types == "period_doubling_candidate"));
            testCase.verifyTrue(any(types == "Neimark_Sacker_candidate"));
            testCase.verifyFalse(any(types == "saddle-node"));
        end

        function bifurcationBracketRejectsSectionChartMismatch(testCase)
            branch = struct( ...
                'stability', {{ ...
                    struct('multipliers', 0.8, 'eigenvectors', 1, ...
                        'reliable', true), ...
                    struct('multipliers', 1.2, 'eigenvectors', 1, ...
                        'reliable', true)}}, ...
                'continuationCoordinate', [0, 1], ...
                'cyclic_signature', {{'FR_LO', 'FR_LO'}}, ...
                'section_relative_signature', ...
                    {{'FR_LO<Apex', 'Apex<FR_LO'}}, ...
                'event_cluster_signature', {{'{FR_LO}', '{FR_LO}'}}, ...
                'return_multiplicity', [1, 1], ...
                'topology_boundary', [false, false]);

            [events, tracks] = BifurcationDetector_v3().detect(branch);

            testCase.verifyEmpty(events);
            testCase.verifyFalse(tracks.topologyCompatible);
        end

        function bifurcationBracketRejectsEitherBoundaryEndpoint(testCase)
            branch = TestNumericsStabilityContracts_v3.validBranch( ...
                [0.8, 1.2]);
            branch.topology_boundary = [true, false];

            [events, tracks] = BifurcationDetector_v3().detect(branch);

            testCase.verifyEmpty(events);
            testCase.verifyFalse(tracks.topologyCompatible);
            testCase.verifyTrue(tracks.topologyEvidenceComplete);
        end

        function structuredBifurcationDataFailClosedWithoutEvidence(testCase)
            branch = TestNumericsStabilityContracts_v3.validBranch( ...
                [0.8, 1.2]);
            branch = rmfield(branch, 'event_cluster_signature');
            [events, tracks] = BifurcationDetector_v3().detect(branch);
            testCase.verifyEmpty(events);
            testCase.verifyFalse(tracks.topologyEvidenceComplete);
            testCase.verifyFalse(tracks.topologyCompatible);

            branch = TestNumericsStabilityContracts_v3.validBranch( ...
                [0.8, 1.2]);
            branch.stability{2} = rmfield( ...
                branch.stability{2}, 'reliable');
            [events, tracks] = BifurcationDetector_v3().detect(branch);
            testCase.verifyEmpty(events);
            testCase.verifyEqual(tracks.reliable, [true, false]);
        end

        function hybridBoundariesRemainSeparateFromSmoothBifurcations(testCase)
            history1 = struct('time', {0.2, 0.200001}, ...
                'type', {'A', 'B'});
            history2 = struct('time', {0.2, 0.4, 0.8}, ...
                'type', {'A', 'C', 'B'});
            points(1) = struct('mode', 0, 'period', 1, ...
                'event_history', history1, 'cyclic_signature', 'A>B', ...
                'return_multiplicity', 1, 'guard_transversality', 1e-8, ...
                'continuationCoordinate', 0, 'event_counts', [], ...
                'topology_margins', struct('stance_force', 1));
            points(2) = struct('mode', 1, 'period', 1, ...
                'event_history', history2, 'cyclic_signature', 'A>C>B', ...
                'return_multiplicity', 2, 'guard_transversality', 1, ...
                'continuationCoordinate', 1, 'event_counts', [], ...
                'topology_margins', struct('stance_force', -1e-9));
            points(1).event_counts = struct( ...
                'touchdown_count', 1, 'liftoff_count', 1);
            points(2).event_counts = repmat(struct( ...
                'touchdown_count', 1, 'liftoff_count', 1), 2, 1);
            detector = HybridBoundaryDetector_v3();
            events = detector.detect(struct('points', points));
            types = string({events.type});

            testCase.verifyTrue(any(types == "guard_grazing"));
            testCase.verifyTrue(any(types == "event_cluster_approach"));
            testCase.verifyFalse(any(types == "event_collision"));
            testCase.verifyTrue(any(types == "event_insertion_or_deletion"));
            testCase.verifyTrue(any(types == "section_mode_change"));
            testCase.verifyTrue(any(types == "return_multiplicity_change"));
            testCase.verifyTrue(any(types == "cyclic_event_signature_change"));
            testCase.verifyTrue(any(types == ...
                "stance_force_admissibility_loss"));
            testCase.verifyFalse(any([events.reliableSmoothBifurcation]));
        end
    end

    methods (Static, Access = private)
        function [value, metadata] = cubicHybridMap(point, varargin)
            value = point.^3;
            metadata = TestNumericsStabilityContracts_v3.validMetadata('A>B');
        end

        function [value, metadata] = piecewiseSignatureMap(point, varargin)
            value = point;
            if point > 0
                signature = 'right';
            else
                signature = 'left';
            end
            metadata = TestNumericsStabilityContracts_v3.validMetadata(signature);
        end

        function value = metadataFreeMap(point, varargin)
            value = point;
        end

        function [value, metadata] = missingSectionMap(point, varargin)
            value = point;
            metadata = TestNumericsStabilityContracts_v3.validMetadata('A>B');
            metadata = rmfield(metadata, ...
                'section_relative_event_signature');
        end

        function [value, metadata] = trajectoryHistoryMap(point, varargin)
            value = point;
            metadata = TestNumericsStabilityContracts_v3.validMetadata('A>B');
            metadata = rmfield(metadata, 'cyclic_event_signature');
            metadata.event_history = struct('type', {'A', 'B'});
        end

        function [value, metadata] = sectionChartBoundaryMap(point, varargin)
            value = point;
            metadata = TestNumericsStabilityContracts_v3.validMetadata( ...
                'FR_LO');
            if point > 0
                metadata.section_relative_event_signature = 'Apex<FR_LO';
            else
                metadata.section_relative_event_signature = 'FR_LO<Apex';
            end
        end

        function [value, metadata] = multiplicityBoundaryMap(point, varargin)
            value = point;
            metadata = TestNumericsStabilityContracts_v3.validMetadata('A');
            if point > 0
                metadata.return_multiplicity = 2;
            end
        end

        function metadata = validMetadata(signature)
            metadata = struct('integration_success', true, ...
                'discrete_closed', true, 'cycle_complete', true, ...
                'return_multiplicity', 1, ...
                'cyclic_event_signature', signature, ...
                'section_relative_event_signature', signature, ...
                'event_cluster_signature', signature, ...
                'guard_transversality_margin', 1, ...
                'section_transversality', 1);
        end


        function branch = validBranch(multipliers)
            branch = struct();
            branch.stability = arrayfun(@(value) struct( ...
                'multipliers', value, 'eigenvectors', 1, ...
                'reliable', true), multipliers, 'UniformOutput', false);
            branch.continuationCoordinate = 0:numel(multipliers) - 1;
            branch.cyclic_signature = repmat({'A'}, 1, numel(multipliers));
            branch.section_relative_signature = ...
                repmat({'A'}, 1, numel(multipliers));
            branch.event_cluster_signature = ...
                repmat({'{A}'}, 1, numel(multipliers));
            branch.return_multiplicity = ones(1, numel(multipliers));
            branch.topology_boundary = false(1, numel(multipliers));
        end
    end
end
