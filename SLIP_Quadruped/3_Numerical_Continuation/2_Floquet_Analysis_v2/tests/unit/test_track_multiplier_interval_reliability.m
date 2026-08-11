function tests = test_track_multiplier_interval_reliability
%TEST_TRACK_MULTIPLIER_INTERVAL_RELIABILITY Segment tracking at bad intervals.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(testRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(root);
end

function testTrackerRestartsAtTopologyGap(testCase)
    raw = [0.2 0.21 1.3 1.31; 1.2 1.19 0.3 0.31];
    options = struct('IntervalReliability', [true false true], ...
        'ComputeAssignmentGap', false);
    [tracks, diagnostics] = ...
        floquet.internal.tracking.trackMultipliers(raw, [], options);
    testCase.verifyEqual(tracks.Multipliers(:, 2), [0.21; 1.19], ...
        'AbsTol', 1e-14);
    testCase.verifyEqual(tracks.Multipliers(:, 3), raw(:, 3), ...
        'AbsTol', 1e-14);
    testCase.verifyTrue(diagnostics.Restart(3));
    testCase.verifyFalse(diagnostics.IntervalReliability(2));
    testCase.verifyEqual(tracks.Multipliers(:, 4), [1.31; 0.31], ...
        'AbsTol', 1e-14);
end

function testIntervalVectorSizeIsChecked(testCase)
    raw = [0.2 0.3 0.4; 1.2 1.1 1.0];
    testCase.verifyError( ...
        @() floquet.internal.tracking.trackMultipliers(raw, [], ...
        struct('IntervalReliability', true)), ...
        'TrackMultipliers:IntervalReliabilitySize');
end
