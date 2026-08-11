function tests = test_detect_bifurcation_reliability
%TEST_DETECT_BIFURCATION_RELIABILITY Hard detector/tracker gap contract.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    analysisRoot = fileparts(fileparts(testRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(analysisRoot);
end

function testIntervalGapRestartsRawTrackingAndRejectsBracket(testCase)
    raw = CrossingWithOrderingSwap();
    options = DetectionOptions();
    options.IntervalReliability = [true false true];
    % A nested permissive mask must not override the detector-level gap.
    options.TrackOptions.IntervalReliability = true(1, 3);

    [candidates, report] = ...
        floquet.detectBifurcations(raw, 0:3, options);

    testCase.verifyEmpty(candidates);
    testCase.verifyFalse(report.IntervalReliability(2));
    testCase.verifyFalse( ...
        report.Tracks.Diagnostics.IntervalReliability(2));
    testCase.verifyTrue(report.Tracks.Diagnostics.Restart(3));
    % With no restart, minimum-distance matching swaps these two raw rows.
    testCase.verifyEqual(report.Tracks.Multipliers(:, 3), raw(:, 3), ...
        'AbsTol', 1e-14);
    testCase.verifyGreaterThanOrEqual(report.RawBracketCount, 2);
    testCase.verifyTrue(any(strcmp( ...
        {report.Rejected.Reason}, ...
        'validation-or-event-topology-failed')));
end

function testPointReliabilityGapIsAppliedBeforeRawTracking(testCase)
    raw = CrossingWithOrderingSwap();
    options = DetectionOptions();
    options.Reliability = [true true false true];
    options.TrackOptions.Reliability = true(1, 4);

    [candidates, report] = ...
        floquet.detectBifurcations(raw, 0:3, options);

    testCase.verifyEmpty(candidates);
    testCase.verifyEqual(report.PointReliability, ...
        [true true false true]);
    testCase.verifyEqual(report.Tracks.Diagnostics.Reliability, ...
        [true true false true]);
    testCase.verifyTrue(report.Tracks.Diagnostics.Restart(3));
    testCase.verifyTrue(report.Tracks.Diagnostics.Restart(4));
end

function testTopologyIntervalGapIsAppliedBeforeRawTracking(testCase)
    raw = CrossingWithOrderingSwap();
    options = DetectionOptions();
    options.EventTopologyConsistent = [true false true];

    [candidates, report] = ...
        floquet.detectBifurcations(raw, 0:3, options);

    testCase.verifyEmpty(candidates);
    testCase.verifyEqual(report.IntervalReliability, ...
        [true false true]);
    testCase.verifyTrue(report.Tracks.Diagnostics.Restart(3));
end

function testNaNReliabilityMaskIsRejected(testCase)
    options = DetectionOptions();
    options.Reliability = [true NaN true true];
    testCase.verifyError(@() floquet.detectBifurcations( ...
        CrossingWithOrderingSwap(), 0:3, options), ...
        'DetectBifurcation:Reliability');
end

function testNaNIntervalMaskIsRejected(testCase)
    options = DetectionOptions();
    options.IntervalReliability = [true NaN true];
    testCase.verifyError(@() floquet.detectBifurcations( ...
        CrossingWithOrderingSwap(), 0:3, options), ...
        'DetectBifurcation:IntervalReliability');
end

function testNaNTopologyMaskIsRejected(testCase)
    options = DetectionOptions();
    options.EventTopologyConsistent = [true NaN true];
    testCase.verifyError(@() floquet.detectBifurcations( ...
        CrossingWithOrderingSwap(), 0:3, options), ...
        'DetectBifurcation:EventTopologyConsistent');
end

function testReliabilityMaskSizeIsExact(testCase)
    options = DetectionOptions();
    options.Reliability = true;
    testCase.verifyError(@() floquet.detectBifurcations( ...
        CrossingWithOrderingSwap(), 0:3, options), ...
        'DetectBifurcation:Reliability');
end

function testNestedNaNMaskIsRejectedBeforeTracking(testCase)
    options = DetectionOptions();
    options.TrackOptions.Reliability = [true NaN true true];
    testCase.verifyError(@() floquet.detectBifurcations( ...
        CrossingWithOrderingSwap(), 0:3, options), ...
        'DetectBifurcation:TrackReliability');
end

function testLogicalOptionMustBeFiniteZeroOrOne(testCase)
    options = DetectionOptions();
    options.RejectTrivialBranchTangent = NaN;
    testCase.verifyError(@() floquet.detectBifurcations( ...
        CrossingWithOrderingSwap(), 0:3, options), ...
        'DetectBifurcation:LogicalOption');
end

function testRepeatedPlusOneClusterIsScreenedButDirectionUnresolved(testCase)
    raw = [0.90 0.96 1.04 1.10; ...
           0.91 0.97 1.03 1.09; ...
           0.20 0.20 0.20 0.20];
    vectors = repmat({eye(3)},1,4);
    options = struct('PersistencePoints',1, ...
        'MinimumSignedExcursion',1e-5, ...
        'Eigenvectors',{vectors}, ...
        'TrackOptions',struct('ComputeAssignmentGap',false));

    [candidates,report] = ...
        floquet.detectBifurcations(raw,0:3,options);
    plus = candidates(strcmp({candidates.Type},'+1'));

    testCase.verifyNumElements(plus,2);
    testCase.verifyTrue(all([plus.NullMultiplicity] == 2));
    testCase.verifyTrue(all([plus.RepeatedNullCluster]));
    testCase.verifyTrue(all(strcmp( ...
        {plus.NullDirectionClassification}, ...
        'unresolved-repeated-plus-one-cluster')));
    testCase.verifyTrue(all(isnan( ...
        [plus.IsAdditionalNullDirection])));
    testCase.verifyFalse(any([plus.BranchSwitchReady]));
    testCase.verifyEqual(report.ScreeningCandidateCount,numel(candidates));
    testCase.verifyEqual(report.BranchSwitchReadyCandidateCount,0);
end

function raw = CrossingWithOrderingSwap()
    raw = [0.8 0.9 1.1 1.2; ...
           1.2 1.1 0.9 0.8];
end

function options = DetectionOptions()
    options = struct();
    options.PersistencePoints = 1;
    options.MinimumSignedExcursion = 1e-5;
    options.TrackOptions = struct('ComputeAssignmentGap', false);
end
