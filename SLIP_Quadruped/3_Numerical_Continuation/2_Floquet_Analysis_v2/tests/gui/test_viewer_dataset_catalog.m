function tests = test_viewer_dataset_catalog
%TEST_VIEWER_DATASET_CATALOG Contract for checked-in viewer datasets.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(testRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(root);
    testCase.TestData.Root = root;
end

function testEveryCatalogEntryLoadsAsDiagnosticCache(testCase)
    names = { ...
        'BD1_20_2_BE_floquet.mat', ...
        'BD1_20_2_BG_floquet.mat', ...
        'BD1_20_2_FE_floquet.mat', ...
        'BD1_20_2_FG_floquet.mat', ...
        'BD1_20_2_GE_floquet.mat', ...
        'BD1_20_2_GG_floquet.mat', ...
        'BD1_20_2_HE_floquet.mat', ...
        'BD1_20_2_HG_floquet.mat', ...
        'PK_20_2_floquet.mat'};
    pointCounts = [443 474 228 212 200 277 180 538 891];
    acceptedCounts = [443 474 228 212 200 274 180 522 867];

    dataDirectory = fullfile(testCase.TestData.Root, 'reference_data', ...
        'viewer_datasets');
    files = dir(fullfile(dataDirectory, '*_floquet.mat'));
    testCase.verifyEqual(sort({files.name}), sort(names), ...
        'The GUI cache catalog changed without updating its contract test.');

    for k = 1:numel(names)
        filename = fullfile(dataDirectory, names{k});
        [data, info] = floquet.io.loadDataset(filename);
        testCase.verifyEqual(info.schema_version, '1.0', names{k});
        testCase.verifyEqual(info.point_count, pointCounts(k), names{k});
        testCase.verifyEqual(info.accepted_count, acceptedCounts(k), names{k});
        testCase.verifyFalse(data.computation_info.scientific_authority, ...
            names{k});
        testCase.verifyEqual(data.computation_info.dataset_role, ...
            'diagnostic-gui-cache', names{k});
        clear data
    end
end
