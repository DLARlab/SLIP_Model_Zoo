classdef TestBifurcationRefiner_v3 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addFrameworkPaths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(genpath(root));
            testCase.addTeardown(@() rmpath(genpath(root)));
        end
    end

    methods (Test)
        function refinesMooreSpenceFoldAndCoefficients(testCase)
            residual = @(u, p) u.^2 + p(1);
            refiner = BifurcationRefiner_v3( ...
                'ActiveParameterIndex', 1, ...
                'ResidualAcceptanceTolerance', 1e-7, ...
                'NondegeneracyTolerance', 1e-4, ...
                'AssumeSmoothCallbacks', true);

            result = refiner.refineUnitMultiplier( ...
                residual, 0.08, -0.006, [], ...
                TestBifurcationRefiner_v3.smoothEvidence());

            testCase.verifyTrue(result.converged, result.message);
            testCase.verifyEqual(result.classification, 'fold');
            testCase.verifyLessThan(abs(result.state), 1e-5);
            testCase.verifyLessThan(abs(result.parameter), 1e-5);
            testCase.verifyEqual(result.nondegeneracy.a, 1, 'AbsTol', 2e-4);
            testCase.verifyEqual(result.nondegeneracy.b, 1, 'AbsTol', 2e-3);
            testCase.verifyEqual(result.biorthogonalProduct, 1, 'AbsTol', 1e-8);
        end

        function zeroParameterCoefficientIsNotCalledFold(testCase)
            residual = @(u, p) u.^2 + 0 .* p(1);
            refiner = BifurcationRefiner_v3( ...
                'ResidualAcceptanceTolerance', 1e-7, ...
                'NondegeneracyTolerance', 1e-4, ...
                'AssumeSmoothCallbacks', true);

            result = refiner.refineUnitMultiplier( ...
                residual, 0, 0.03, [], ...
                TestBifurcationRefiner_v3.smoothEvidence());

            testCase.verifyTrue(result.converged, result.message);
            testCase.verifyEqual(result.classification, ...
                'unit_multiplier_degeneracy_unresolved');
            testCase.verifyLessThan(abs(result.nondegeneracy.a), 1e-4);
            testCase.verifyNotEqual(result.classification, 'fold');
        end

        function refinesPeriodDoublingMultiplier(testCase)
            map = @(u, p) -(1 + p(1)) .* u;
            residual = @(u, p) map(u, p) - u;
            refiner = BifurcationRefiner_v3( ...
                'ResidualAcceptanceTolerance', 1e-7, ...
                'MultiplierTolerance', 1e-5, ...
                'AssumeSmoothCallbacks', true);

            evidence = TestBifurcationRefiner_v3.smoothEvidence();
            evidence.multiplierEstimate = -1;
            result = refiner.refinePeriodDoubling( ...
                residual, map, 0.02, 0.04, [], evidence);

            testCase.verifyTrue(result.converged, result.message);
            testCase.verifyEqual(result.classification, 'period_doubling');
            testCase.verifyLessThan(abs(result.state), 1e-5);
            testCase.verifyLessThan(abs(result.parameter), 1e-5);
            testCase.verifyEqual(result.criticalMultiplier, -1, 'AbsTol', 1e-5);
        end

        function refinesNeimarkSackerPairAndAngle(testCase)
            angle = 0.47;
            rotation = [cos(angle), -sin(angle); ...
                sin(angle), cos(angle)];
            map = @(u, p) (1 + p(1)) .* rotation * u;
            residual = @(u, p) map(u, p) - u;
            refiner = BifurcationRefiner_v3( ...
                'ResidualAcceptanceTolerance', 1e-7, ...
                'MultiplierTolerance', 2e-5, ...
                'AssumeSmoothCallbacks', true);

            evidence = TestBifurcationRefiner_v3.smoothEvidence();
            evidence.multiplierEstimate = exp(1i * angle);
            result = refiner.refineNeimarkSacker( ...
                residual, map, [0; 0], 0.03, [], evidence);

            testCase.verifyTrue(result.converged, result.message);
            testCase.verifyEqual(result.classification, 'Neimark_Sacker');
            testCase.verifyLessThan(abs(result.parameter), 1e-5);
            testCase.verifyEqual(abs(result.criticalMultiplier), 1, ...
                'AbsTol', 2e-5);
            testCase.verifyEqual(abs(result.criticalAngle), angle, ...
                'AbsTol', 2e-5);
            testCase.verifyGreaterThan( ...
                abs(imag(result.criticalMultiplier)), 0.1);
            testCase.verifyLessThan(result.conjugacyResidual, 2e-5);
            testCase.verifyEqual(result.biorthogonalProduct, 1, ...
                'AbsTol', 2e-5);
            testCase.verifyNotEmpty(result.leftVector);
        end

        function neimarkSackerSelectsCandidateDirectedPair(testCase)
            firstAngle = 0.19;
            targetAngle = 0.73;
            firstBlock = 0.8 .* [cos(firstAngle), -sin(firstAngle); ...
                sin(firstAngle), cos(firstAngle)];
            targetBlock = [cos(targetAngle), -sin(targetAngle); ...
                sin(targetAngle), cos(targetAngle)];
            map = @(u, p) blkdiag(firstBlock, ...
                (1 + p(1)) .* targetBlock) * u;
            residual = @(u, p) map(u, p) - u;
            refiner = BifurcationRefiner_v3( ...
                'ResidualAcceptanceTolerance', 1e-7, ...
                'MultiplierTolerance', 2e-5, ...
                'AssumeSmoothCallbacks', true);
            evidence = TestBifurcationRefiner_v3.smoothEvidence();
            evidence.multiplierEstimate = 1.03 * exp(1i * targetAngle);
            evidence.rightVector = [0; 0; 1; -1i];

            result = refiner.refineNeimarkSacker( ...
                residual, map, zeros(4, 1), 0.03, [], evidence);

            testCase.verifyTrue(result.converged, result.message);
            testCase.verifyEqual(result.classification, 'Neimark_Sacker');
            testCase.verifyEqual(abs(result.criticalAngle), targetAngle, ...
                'AbsTol', 2e-5);
            testCase.verifyLessThan(result.candidateSelectionDistance, 1e-10);
            testCase.verifyGreaterThan(result.candidateVectorOverlap, 0.99);
            testCase.verifyGreaterThan(abs(result.criticalAngle - firstAngle), 0.4);
        end

        function neimarkSackerRejectsMissingOrIncompatibleCandidate(testCase)
            angle = 0.47;
            rotation = [cos(angle), -sin(angle); sin(angle), cos(angle)];
            map = @(u, p) (1 + p(1)) .* rotation * u;
            residual = @(u, p) map(u, p) - u;
            refiner = BifurcationRefiner_v3( ...
                'AssumeSmoothCallbacks', true);

            missingEvidence = TestBifurcationRefiner_v3.smoothEvidence();
            missingEvidence = rmfield( ...
                missingEvidence, 'multiplierEstimate');
            missing = refiner.refineNeimarkSacker(residual, map, ...
                zeros(2, 1), 0, [], missingEvidence);
            testCase.verifyFalse(missing.converged);
            testCase.verifyEqual(missing.classification, 'refinement_rejected');
            testCase.verifySubstring(missing.message, 'critical multiplier');

            evidence = TestBifurcationRefiner_v3.smoothEvidence();
            evidence.multiplierEstimate = exp(1i * 1.2);
            incompatible = refiner.refineNeimarkSacker(residual, map, ...
                zeros(2, 1), 0, [], evidence);
            testCase.verifyFalse(incompatible.converged);
            testCase.verifyEqual(incompatible.classification, ...
                'refinement_rejected');
            testCase.verifySubstring(incompatible.message, 'incompatible');
        end

        function realRefinementsRejectMissingOrWrongCandidateType(testCase)
            foldResidual = @(u, p) u.^2 + p(1);
            map = @(u, p) -(1 + p(1)) .* u;
            periodResidual = @(u, p) map(u, p) - u;
            refiner = BifurcationRefiner_v3( ...
                'AssumeSmoothCallbacks', true);

            missing = TestBifurcationRefiner_v3.smoothEvidence();
            missing = rmfield(missing, 'multiplierEstimate');
            unitResult = refiner.refineUnitMultiplier( ...
                foldResidual, 0, 0, [], missing);
            testCase.verifyFalse(unitResult.converged);
            testCase.verifyEqual(unitResult.classification, ...
                'refinement_rejected');
            testCase.verifySubstring(unitResult.message, ...
                'explicit finite candidate');

            wrongUnit = TestBifurcationRefiner_v3.smoothEvidence();
            wrongUnit.multiplierEstimate = -1;
            unitResult = refiner.refineUnitMultiplier( ...
                foldResidual, 0, 0, [], wrongUnit);
            testCase.verifyFalse(unitResult.converged);
            testCase.verifySubstring(unitResult.message, 'incompatible');

            wrongPeriodDoubling = ...
                TestBifurcationRefiner_v3.smoothEvidence();
            periodResult = refiner.refinePeriodDoubling( ...
                periodResidual, map, 0, 0, [], wrongPeriodDoubling);
            testCase.verifyFalse(periodResult.converged);
            testCase.verifySubstring(periodResult.message, 'incompatible');
        end

        function rejectsHybridChartBoundary(testCase)
            residual = @(u, p) u.^2 + p(1);
            metadata = TestBifurcationRefiner_v3.smoothEvidence();
            metadata.hybridChartBoundary = true;
            metadata.adjacentSectionSignatures = ...
                {'LO<Apex', 'Apex<LO'};
            refiner = BifurcationRefiner_v3( ...
                'AssumeSmoothCallbacks', true);
            result = refiner.refineUnitMultiplier( ...
                residual, 0, 0, [], metadata);

            testCase.verifyFalse(result.converged);
            testCase.verifyEqual(result.classification, 'refinement_rejected');
            testCase.verifySubstring(result.message, 'hybrid chart');
        end

        function missingEligibilityEvidenceFailsClosed(testCase)
            residual = @(u, p) u.^2 + p(1);
            refiner = BifurcationRefiner_v3( ...
                'AssumeSmoothCallbacks', true);
            result = refiner.refineUnitMultiplier( ...
                residual, 0, 0, [], struct('reliable', true));

            testCase.verifyFalse(result.converged);
            testCase.verifyEqual(result.classification, 'refinement_rejected');
            testCase.verifySubstring(result.message, 'converged');
        end

        function ordinaryFiniteDifferenceRequiresSmoothDeclaration(testCase)
            residual = @(u, p) u.^2 + p(1);
            result = BifurcationRefiner_v3().refineUnitMultiplier( ...
                residual, 0, 0, [], ...
                TestBifurcationRefiner_v3.smoothEvidence());

            testCase.verifyFalse(result.converged);
            testCase.verifyEqual(result.classification, 'refinement_rejected');
            testCase.verifySubstring(result.message, ...
                'AssumeSmoothCallbacks=true');
        end

        function missingReliabilityOrTopologyEvidenceFailsClosed(testCase)
            residual = @(u, p) u.^2 + p(1);
            refiner = BifurcationRefiner_v3( ...
                'AssumeSmoothCallbacks', true);

            metadata = TestBifurcationRefiner_v3.smoothEvidence();
            metadata = rmfield(metadata, 'reliable');
            result = refiner.refineUnitMultiplier( ...
                residual, 0, 0, [], metadata);
            testCase.verifyFalse(result.converged);
            testCase.verifySubstring(result.message, 'reliable');

            metadata = TestBifurcationRefiner_v3.smoothEvidence();
            metadata = rmfield(metadata, 'topologyCompatible');
            result = refiner.refineUnitMultiplier( ...
                residual, 0, 0, [], metadata);
            testCase.verifyFalse(result.converged);
            testCase.verifySubstring(result.message, ...
                'compatible-topology');

            metadata = TestBifurcationRefiner_v3.smoothEvidence();
            metadata = rmfield(metadata, 'section_event_coincidence');
            result = refiner.refineUnitMultiplier( ...
                residual, 0, 0, [], metadata);
            testCase.verifyFalse(result.converged);
            testCase.verifySubstring(result.message, 'section/event');
        end

        function topologyAwareHybridJacobianUsesExecutionMetadata(testCase)
            hybridJacobian = HybridFiniteDifferenceJacobian_v3( ...
                'RelativeCandidateSteps', [1e-3, 3e-4, 1e-4], ...
                'MaximumRelativeError', 2e-3, ...
                'FailurePolicy', 'error');
            refiner = BifurcationRefiner_v3( ...
                'Jacobian', hybridJacobian, ...
                'ResidualAcceptanceTolerance', 2e-7, ...
                'NondegeneracyTolerance', 1e-4);
            result = refiner.refineUnitMultiplier( ...
                @TestBifurcationRefiner_v3.hybridFoldResidual, ...
                0.04, -0.0015, 0, ...
                TestBifurcationRefiner_v3.smoothEvidence());

            testCase.verifyTrue(result.converged, result.message);
            testCase.verifyEqual(result.classification, 'fold');
            testCase.verifyEqual(result.derivativeModel, ...
                'topology-aware-hybrid-finite-difference');
            testCase.verifyTrue(result.finiteDifference.allReliable);
            testCase.verifyEqual( ...
                result.finiteDifference.baseSectionSignature, ...
                'TD>LO>Apex');
        end
    end

    methods (Static, Access = private)
        function metadata = smoothEvidence()
            metadata = struct( ...
                'converged', true, ...
                'reliable', true, ...
                'topologyCompatible', true, ...
                'hybridChartBoundary', false, ...
                'section_event_coincidence', false, ...
                'unresolvedSimultaneousOrdering', false, ...
                'multiplierEstimate', 1, ...
                'adjacentSectionSignatures', {{'LO<Apex', 'Apex<LO'}});
        end


        function [value, metadata] = hybridFoldResidual(u, p, q) %#ok<INUSD>
            value = u.^2 + p(1);
            metadata = struct( ...
                'success', true, ...
                'valid', true, ...
                'admissible', true, ...
                'integration_success', true, ...
                'cycle_complete', true, ...
                'mode_closed', true, ...
                'reliable', true, ...
                'return_multiplicity', 1, ...
                'cyclic_event_signature', 'TD>LO', ...
                'section_relative_event_signature', 'TD>LO>Apex', ...
                'event_cluster_signature', '{TD}>{LO}', ...
                'guard_transversality_margin', 1, ...
                'section_transversality', 1);
        end
    end
end
