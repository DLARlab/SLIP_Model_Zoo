function tests = test_canonical_evaluator_identity
%TEST_CANONICAL_EVALUATOR_IDENTITY Reject same-name shadow evaluators.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    floquetRoot = fileparts(fileparts(testRoot));
    addpath(floquetRoot);
    testCase.TestData.FloquetRoot = floquetRoot;
end

function testCanonicalRepositoryEvaluatorsAreRecognized(testCase)
    [computeProduction,computeIdentity] = ...
        floquet.internal.provenance.evaluatorIdentity( ...
        @floquet.computeFDM,'floquet.computeFDM');
    [validationProduction,validationIdentity] = ...
        floquet.internal.provenance.evaluatorIdentity( ...
        @floquet.validatePeriodicOrbit,'floquet.validatePeriodicOrbit');

    verifyTrue(testCase, computeProduction);
    verifyTrue(testCase, validationProduction);
    verifyTrue(testCase, computeIdentity.FileMatches);
    verifyTrue(testCase, validationIdentity.FileMatches);
end

function testShadowedComputeIsRejectedAtAnalysisBoundaries(testCase)
    shadow = MakeShadowHandle(testCase, 'ComputeFloquetFDM');
    [production,identity] = ...
        floquet.internal.provenance.evaluatorIdentity( ...
        shadow, 'floquet.computeFDM');
    verifyFalse(testCase, production);
    verifyFalse(testCase, identity.NameMatches);
    verifyFalse(testCase, identity.FileMatches);

    options = struct('ComputeFunction', shadow, 'Verbose', false);
    verifyError(testCase, @() floquet.analyzeBranch( ...
        MinimalBranch(), [], options), ...
        'AnalyzeFloquetBranch:NonProductionEvaluator');
end

function testShadowedComputeIsRejectedByDiscoveryGate(testCase)
    shadow = MakeShadowHandle(testCase, 'ComputeFloquetFDM');
    root = tempname;
    mkdir(root);
    testCase.addTeardown(@() RemoveDirectory(root));
    branch = MinimalBranch();
    parentFile = fullfile(root, 'parent.mat');
    save(parentFile, 'branch');
    config = floquet.workflow.internal.BuildFloquetWorkflowConfig( ...
        root,testCase.TestData.FloquetRoot);
    config.ParentBranchFile = parentFile;
    identityConfig = struct('ExperimentRoot',root, ...
        'ParentBranchFile',parentFile,'ExpectedParentSHA256','');
    parentIdentity = ...
        floquet.workflow.internal.FloquetParentIdentity(identityConfig);
    config.ExpectedParentSHA256 = parentIdentity.FileSHA256;
    config.AnalysisOptions.ComputeFunction = shadow;

    verifyError(testCase, @() ...
        floquet.workflow.internal.discoveryStage(config), ...
        'TemplateExperiment:NonProductionDiscovery');
end

function testShadowedValidatorCannotGrantDaughterAuthority(testCase)
    shadow = MakeShadowHandle(testCase, 'ValidatePeriodicOrbit');
    critical = zeros(22, 1);
    critical(2) = 1;
    critical(14:21) = (0.1:0.1:0.8).';
    critical(22) = 1;
    direction = zeros(12, 1);
    direction(1) = 1;
    seed1 = critical;
    seed2 = critical;
    seed1(1) = 0.01;
    seed2(1) = 0.02;
    parameters = [1; 1; Inf; 1; 1; 1; 1];
    options = struct( ...
        'CriticalSolution', critical, ...
        'Direction', direction, ...
        'ValidateSeeds', false, ...
        'ValidateOutput', false, ...
        'RequireConsistentOutputTopology', false, ...
        'ValidationFunction', shadow, ...
        'ContinuationFunction', @FakeContinuation);

    [~,info] = floquet.continueDaughterBranch( ...
        seed1, seed2, parameters, options);
    verifyFalse(testCase, info.validationAuthority.productionEvaluator);
    verifyFalse(testCase, ...
        info.validationAuthority.evaluatorIdentity.NameMatches);
    verifyFalse(testCase, ...
        info.validationAuthority.evaluatorIdentity.FileMatches);
    verifyFalse(testCase, ...
        info.validationAuthority.scientificAcceptanceEligible);
end

function handle = MakeShadowHandle(testCase, functionName)
    folder = tempname;
    mkdir(folder);
    filename = fullfile(folder, [functionName '.m']);
    stream = fopen(filename, 'w');
    if stream < 0
        error('FloquetTest:ShadowFixture', ...
            'Could not create shadow-function fixture.');
    end
    closer = onCleanup(@() fclose(stream));
    fprintf(stream, 'function varargout = %s(varargin)\n', functionName);
    fprintf(stream, 'varargout = cell(1,nargout);\n');
    fprintf(stream, 'end\n');
    clear closer
    addpath(folder, '-begin');
    rehash
    ClearNamedFunction(functionName);
    handle = str2func(functionName);
    testCase.addTeardown(@() RemoveShadow(folder, functionName));
end

function ClearNamedFunction(functionName)
    eval(sprintf('clear %s', functionName));
end

function RemoveShadow(folder, functionName)
    if ContainsPath(folder)
        rmpath(folder);
    end
    ClearNamedFunction(functionName);
    if isfolder(folder)
        rmdir(folder, 's');
    end
    rehash
end

function present = ContainsPath(folder)
    entries = strsplit(path, pathsep);
    present = any(strcmp(entries, folder));
end

function RemoveDirectory(folder)
    if isfolder(folder)
        rmdir(folder, 's');
    end
end

function branch = MinimalBranch()
    branch = zeros(29, 3);
    branch(1, :) = 1:3;
    branch(14:21, :) = repmat((0.1:0.1:0.8).', 1, 3);
    branch(22, :) = 1;
    branch(23:24, :) = 1;
    branch(25, :) = Inf;
    branch(26:29, :) = 1;
end

function [results, direction, diagnostics] = FakeContinuation( ...
        solution1, solution2, parameters, ~, ~, ~)
    results = [solution1, solution2, solution2];
    results(1, 3) = results(1, 3) + 0.01;
    results = [results; repmat(parameters, 1, 3)];
    direction = results(:, end) - results(:, end - 1);
    diagnostics = struct();
end
