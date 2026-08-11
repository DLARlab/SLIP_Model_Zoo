function tests = test_predict_branch_direction_provenance
%TEST_PREDICT_BRANCH_DIRECTION_PROVENANCE Direction-readiness guards.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testRoot = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(testRoot));
    originalPath = path;
    testCase.addTeardown(@() path(originalPath));
    addpath(root);
end

function testRepeatedDetectorVectorIsRejectedBeforeTimingSolve(testCase)
    candidate = SimpleCandidate();
    candidate.NullDirectionClassification = ...
        'unresolved-repeated-plus-one-cluster';
    candidate.RepeatedNullCluster = true;
    candidate.NullMultiplicity = 3;
    candidate.BranchSwitchReady = false;
    candidate.RefinementStatus = 'unrefined-detector-bracket';
    candidate.ScreeningCandidate = true;

    [X,E,parameters] = BaseOrbit();
    testCase.verifyError(@() floquet.predictBranchDirection( ...
        X,E,parameters,candidate,struct()), ...
        'PredictBranchDirection:UnresolvedRepeatedPlusOneCluster');
end

function testProductionReadyGateRejectsUnrefinedSimpleCandidate(testCase)
    candidate = SimpleCandidate();
    candidate.RefinementStatus = 'unrefined-detector-bracket';
    candidate.ScreeningCandidate = true;
    candidate.BranchSwitchReady = false;
    options = struct('RequireProductionReady',true, ...
        'BranchTangent',UnitVector(12,2));

    [X,E,parameters] = BaseOrbit();
    testCase.verifyError(@() floquet.predictBranchDirection( ...
        X,E,parameters,candidate,options), ...
        'PredictBranchDirection:UnrefinedDirection');
end

function testProductionReadyOptionMustBeStrictLogical(testCase)
    [X,E,parameters] = BaseOrbit();
    testCase.verifyError(@() floquet.predictBranchDirection( ...
        X,E,parameters,SimpleCandidate(), ...
        struct('RequireProductionReady',2)), ...
        'PredictBranchDirection:InvalidLogicalOption');
end

function candidate = SimpleCandidate()
    candidate = struct('Type','+1','Multiplier',1, ...
        'Eigenvector',UnitVector(12,1), ...
        'NullDirectionClassification','additional-null-direction', ...
        'IsAdditionalNullDirection',true, ...
        'IsTrivialBranchTangent',false);
end

function [X,E,parameters] = BaseOrbit()
    X = zeros(13,1);
    E = [(0.1:0.1:0.8).';1];
    parameters = [10;20;2;1;0;0.5;1];
end

function value = UnitVector(count,index)
    value = zeros(count,1);
    value(index) = 1;
end
