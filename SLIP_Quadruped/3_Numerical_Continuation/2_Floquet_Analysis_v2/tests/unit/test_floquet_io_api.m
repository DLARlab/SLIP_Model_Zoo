function tests = test_floquet_io_api
%TEST_FLOQUET_IO_API Namespaced I/O API dispatch and error contracts.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    unitRoot = fileparts(mfilename('fullpath'));
    floquetRoot = fileparts(fileparts(unitRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(floquetRoot);
end

function testPublicIOEntryPointsAreResolvable(testCase)
    names = {'floquet.io.loadDataset', 'floquet.io.exportDataset', ...
        'floquet.io.trackDisplayMultipliers'};
    for k = 1:numel(names)
        testCase.verifyNotEmpty(which(names{k}), names{k});
    end
end

function testDisplayTrackerDispatchesToCanonicalImplementation(testCase)
    values = [0.2 0.21 0.22; 1.1 1.0 0.9; 0.5 0.52 0.51];
    vectors = repmat(eye(3), 1, 1, 3);
    options = struct('ComputeAssignmentGap', false);

    [expectedValues, expectedVectors, expectedInfo] = ...
        floquet.io.internal.TrackFloquetMultipliers( ...
        values, vectors, options);
    [actualValues, actualVectors, actualInfo] = ...
        floquet.io.trackDisplayMultipliers(values, vectors, options);

    testCase.verifyEqual(actualValues, expectedValues);
    testCase.verifyEqual(actualVectors, expectedVectors);
    testCase.verifyEqual(actualInfo.Assignments, expectedInfo.Assignments);
    testCase.verifyEqual(actualInfo.Reliability, expectedInfo.Reliability);
end

function testLoadFacadePreservesStableErrorContract(testCase)
    testCase.verifyError(@() floquet.io.loadDataset(), ...
        'LoadFloquetDataset:MissingSource');
end

function testExportFacadePreservesStableErrorContract(testCase)
    testCase.verifyError(@() floquet.io.exportDataset(struct()), ...
        'BuildFloquetDatasetFromAnalysis:InvalidAnalysis');
end

function testRetiredDiagnosticGeneratorIsNotResolvable(testCase)
    testCase.verifyEmpty(which('floquet.io.generateDiagnosticDataset'));
    testCase.verifyEmpty(which( ...
        'floquet.io.internal.GenerateFloquetDataset'));
end
