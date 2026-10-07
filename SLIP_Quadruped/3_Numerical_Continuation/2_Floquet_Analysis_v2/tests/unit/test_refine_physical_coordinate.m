function tests = test_refine_physical_coordinate
% Physical chart regression: equal speeds must not collapse height brackets.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
oldPath = path;
testCase.addTeardown(@() path(oldPath));
addpath(root);
floquet.internal.ensureRuntimePaths(false);
slipRoot = fileparts(fileparts(root));
loaded = load(fullfile(slipRoot,'P2_All_Common_Quadrupedal_Gaits', ...
    'PIP_10_20_2.mat'),'results');
testCase.TestData.results = loaded.results;
end

function testDefaultEqualSpeedBracketStillRejected(testCase)
r = testCase.TestData.results(:,1:2);
c = struct('Type','+1','Bracket',r(1,:),'LeftIndex',1,'RightIndex',2);
[z,d] = floquet.refineCriticalOrbit(r,c);
testCase.verifyEmpty(z);
testCase.verifyEqual(d.exceptionIdentifier,'RefineCriticalOrbit:ZeroWidthBracket');
end

function testEqualDxDistinctHeightCorrectorAndMapping(testCase)
r = testCase.TestData.results;
c = struct('Type','+1','Bracket',r(2,[4 5]),'LeftIndex',1,'RightIndex',2);
o = struct('SampleIndices',[4 5], 'ContinuationParameterRow',2, ...
    'ContinuationParameterName','apex height','ParentCorrector',@StopAtChart);
[z,d] = floquet.refineCriticalOrbit(r,c,o);
testCase.verifyEmpty(z); % Deliberate stop before any spectral computation.
testCase.verifyEqual(d.resolvedBranchIndices,[4 5]);
testCase.verifyEqual(d.inputBracket,r(2,[4 5]));
testCase.verifyEqual(d.history(1).coordinate,min(r(2,[4 5])));
testCase.verifyEqual(d.history(1).correction.exitflag,-71);
testCase.verifyEqual(d.history(1).correction.parentCorrector.originalSpeed,0);
testCase.verifyNotEqual(d.exceptionIdentifier,'RefineCriticalOrbit:ZeroWidthBracket');
end

function testCoordinateMatchingAndSortingUseHeight(testCase)
r = testCase.TestData.results(:,1:6);
c = struct('Type','+1','Bracket',r(2,[5 4]));
o = struct('ContinuationParameterRow',2,'ParentCorrector',@StopAtChart);
[~,d] = floquet.refineCriticalOrbit(r,c,o);
testCase.verifyEqual(d.resolvedBranchIndices,[5 4]);
testCase.verifyEqual(d.history(1).coordinate,min(r(2,[4 5])));
testCase.verifyEqual(d.history(1).correction.exitflag,-71);
end

function testFixedHyperplaneUsesSameCoordinateEverywhere(testCase)
r = testCase.TestData.results(:,1:2);
reference = r(1:22,1);
c = struct('Type','+1','Bracket',(r(2,:)-reference(2))/2);
chart = @(z) (z(2)-reference(2))/2;
o = struct('ContinuationCoordinateFunction',chart, ...
    'ParentCorrector',@StopAtGeneralChart);
[~,d] = floquet.refineCriticalOrbit(r,c,o);
testCase.verifyEqual(d.resolvedBranchIndices,[1 2]);
testCase.verifyEqual(d.history(1).coordinate,min(c.Bracket));
testCase.verifyEqual(d.history(1).correction.exitflag,-72);
end

function testRankDeficientParentResidualRejected(testCase)
r = testCase.TestData.results(:,1:2);
c = struct('Type','+1','Bracket',r(2,:));
o = struct('ContinuationParameterRow',2,'ParentCorrector',@RankDeficient);
[~,d] = floquet.refineCriticalOrbit(r,c,o);
rankInfo = d.history(1).correction.jacobianRank;
testCase.verifyFalse(rankInfo.accepted);
testCase.verifyEqual(rankInfo.rank,3);
testCase.verifyEqual(rankInfo.numberOfUnknowns,4);
testCase.verifySubstring(d.history(1).rejectionReasons{1},'not transverse');
end

function testIndependentHeightEmbeddingThenProductionFDM(testCase)
r = testCase.TestData.results(:,1:2);
c = struct('Type','+1','Bracket',r(2,:));
c.Eigenvector = [0;1;zeros(10,1)];
calls = 0;
o = struct('ContinuationParameterRow',2,'ParentCorrector',@EndpointGuard, ...
    'StoreFullFloquetDiagnostics',true);
[~,d] = floquet.refineCriticalOrbit(r,c,o);
correction = d.history(1).correction;
testCase.verifyTrue(correction.accepted);
testCase.verifyTrue(correction.jacobianRank.accepted);
testCase.verifyEqual(correction.jacobianRank.numberOfUnknowns,4);
testCase.verifyLessThanOrEqual(correction.canonicalResidualNormInf,1e-8);
testCase.verifyLessThanOrEqual(abs(correction.coordinateResidual),1e-9);
fdm = d.history(1).floquetDiagnostics;
testCase.verifyTrue(fdm.accepted,strjoin(d.history(1).rejectionReasons));
testCase.verifySize(fdm.centralDerivativeMatrices,[12 12 3]);
testCase.verifyEqual(d.history(1).solution(1),0);
testCase.verifyLessThanOrEqual(abs(d.history(1).solution(2)-r(2,1)),1e-9);
testCase.verifyNumElements(d.history,2);
testCase.verifyEqual(d.history(2).correction.exitflag,-73);
    function [z,info] = EndpointGuard(guess,p,coordinate,context)
        calls = calls+1;
        if calls==1
            [z,info] = EmbeddedParent(guess,p,coordinate,context);
        else
            z = guess;
            info = struct('exitflag',-73);
        end
    end
end

function [z,info] = StopAtChart(guess,~,coordinate,context)
assert(context.coordinateRow==2);
assert(guess(1)==0);
assert(guess(2)==coordinate);
assert(context.coordinateFunction(guess)==coordinate);
z = guess;
info = struct('exitflag',-71,'originalSpeed',guess(1));
end

function [z,info] = StopAtGeneralChart(guess,~,coordinate,context)
assert(abs(context.coordinateFunction(guess)-coordinate)<1e-12);
assert(guess(1)==0);
z = guess;
info = struct('exitflag',-72);
end

function [z,info] = RankDeficient(guess,~,~,~)
z = guess;
info = struct('exitflag',1,'jacobian',diag([1 1 1 0]));
end

function [z,info] = EmbeddedParent(guess,~,coordinate,context)
u0 = [coordinate;guess(14:15);guess(22)];
[u,fval,flag,output,jacobian] = fsolve(@residual,u0,context.fsolveOptions);
z = embed(u);
info = struct('exitflag',flag,'fval',fval,'output',output,'jacobian',jacobian);
    function r = residual(u)
        p = context.canonicalResidual(embed(u));
        r = [p([1 3 9]);u(1)-coordinate];
    end
    function z = embed(u)
        z = zeros(22,1);
        z(2) = u(1);
        z(14:21) = repmat(u(2:3),4,1);
        z(22) = u(4);
    end
end
