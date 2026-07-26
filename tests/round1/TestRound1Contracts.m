classdef TestRound1Contracts < matlab.unittest.TestCase
    properties
        RepositoryRoot
        ReferenceFile
        ReferenceResults
    end

    methods (TestClassSetup)
        function loadReference(testCase)
            here = fileparts(mfilename('fullpath'));
            testCase.RepositoryRoot = fileparts(fileparts(here));
            addpath(genpath(fullfile(testCase.RepositoryRoot, 'SLIP_Quadruped')));
            addpath(fullfile(testCase.RepositoryRoot, 'tools', 'audit'));
            testCase.ReferenceFile = fullfile(testCase.RepositoryRoot, ...
                'SLIP_Quadruped', ...
                'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits', ...
                '1_Roadmap', 'PK_20_2.mat');
            data = load(testCase.ReferenceFile, 'results');
            testCase.ReferenceResults = data.results;
        end
    end

    methods (Test)
        function allStoredBranchesUse29RowSchema(testCase)
            files = dir(fullfile(testCase.RepositoryRoot, 'SLIP_Quadruped', '**', '*.mat'));
            testCase.verifyGreaterThanOrEqual(numel(files), 1);
            for iFile = 1:numel(files)
                data = load(fullfile(files(iFile).folder, files(iFile).name), 'results');
                testCase.assertTrue(isfield(data, 'results'), files(iFile).name);
                testCase.verifyEqual(size(data.results, 1), 29, files(iFile).name);
                testCase.verifyGreaterThanOrEqual(size(data.results, 2), 1, ...
                    files(iFile).name);
                testCase.verifyTrue(isnumeric(data.results), files(iFile).name);
            end
        end

        function importantEntryPointsResolve(testCase)
            names = {'SLIP_Quadruped_GUI', 'Quadrupedal_ZeroFun_v2', ...
                'SolveQuadrupedalZE', 'NumericalContinuation1D_Quadruped_v2', ...
                'NumericalContinuation2D_Quadruped_v2', ...
                'ParameterVarying2D_Quadruped_v2', 'EventTimingRegulation', ...
                'Gait_Identification', 'Func_alphaB_VA_v2', 'Func_alphaF_VA_v2'};
            for iName = 1:numel(names)
                testCase.verifyNotEmpty(which(names{iName}), names{iName});
            end
        end

        function referenceArtifactsMatchRound1Baseline(testCase)
            expectedPaths = [ ...
                "1_Dynamic_Frameworks/QuadrupedalSystemDynamics.mlx"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/1_PK_BD.fig"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/2_HB_GP.fig"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/BD1_20_2_BE.mat"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/BD1_20_2_BG.mat"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/BD1_20_2_FE.mat"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/BD1_20_2_FG.mat"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/BD1_20_2_GE.mat"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/BD1_20_2_GG.mat"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/BD1_20_2_HE.mat"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/BD1_20_2_HG.mat"
                "P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap/PK_20_2.mat"];
            expectedHashes = [ ...
                "94b078b9b5666c9f56cb2ff2b29e0086ecc8dd4dc6d6bd892c8f6b1d62313930"
                "469e00bbafb9ae046945b20ca9690c0dc4c7379c63a42d5f8901b01e1dbb3f65"
                "b2909a65009aaa6afa81a5770a71815a1b549ab52aae6c77572cd25773f23fd0"
                "3ab8e1f47ea788a95faa541bed9bf02ad53b5e4107f5601a19f96f5464b87d0c"
                "ccff690f6a6b468ee623259f68dfe71dc077dcf552e35869324bc39c132b2be0"
                "e8cd3ab486a1badbc6ea1356ed85b22ea4003b01fe1ea60fb3ec2ec829fa4a0b"
                "231895dbb454f914a6f9bd269d2108e761728f3e1cc7a5548be7f0b6a1b6cbf3"
                "90d1670caf34062f0705e26000bbf99cd901b1aa8adf034f93dc1db152e4bba7"
                "81844c79b77df1390db003a13fde2043629793865a93b73fe9b79b62696028b1"
                "c3f7bd53f05729cada19cdb8b074e91d6861849d13c0555b2e5a1812a532c892"
                "756295fa6459dddab2e56000205be88e9a25215c67c423856933f6053008ae10"
                "45835bb5024b1dc9b875c7b8f7b205769f537a4ff4144c763058537f44dbf401"];
            hashes = round1ArtifactHashes(fullfile( ...
                testCase.RepositoryRoot, 'SLIP_Quadruped'));
            actualPaths = replace(hashes.relative_path, filesep, "/");
            testCase.verifyEqual(actualPaths, expectedPaths);
            testCase.verifyEqual(hashes.sha256, expectedHashes);
        end

        function staleSolverTargetIsCurrentlyMissing(testCase)
            % CHARACTERIZATION OF CONFIRMED DEFECT in SolveQuadrupedalZE.
            testCase.verifyEmpty(which('Quadrupedal_ZeroFun_v2_test'));
        end

        function residualAndOutputDimensions(testCase)
            X = testCase.ReferenceResults(1:22, 1);
            Para = testCase.ReferenceResults(23:29, 1);
            [residual, T, Y, P, GRFs, YEvent] = ...
                Quadrupedal_ZeroFun_v2(X, Para, 'skipSolve');

            testCase.verifySize(residual, [22, 1]);
            testCase.verifyEqual(size(T, 2), 1);
            testCase.verifyGreaterThan(size(T, 1), 0);
            testCase.verifySize(Y, [numel(T), 14]);
            testCase.verifySize(P, [1, 16]);
            testCase.verifySize(GRFs, [numel(T), 12]);
            testCase.verifySize(YEvent, [9, 14]);
            testCase.verifyTrue(all(isfinite(residual)));
        end

        function residualDimensionsForSupportedConfigurations(testCase)
            X = testCase.ReferenceResults(1:22, 1);
            Para = testCase.ReferenceResults(23:29, 1);
            pairConstraint = {'(BL,BR)'};

            base = Quadrupedal_ZeroFun_v2(X, Para, 'skipSolve');
            constrained = Quadrupedal_ZeroFun_v2( ...
                X, Para, pairConstraint, 'skipSolve');
            ParaInfiniteInertia = Para;
            ParaInfiniteInertia(3) = Inf;
            infiniteInertia = Quadrupedal_ZeroFun_v2( ...
                X, ParaInfiniteInertia, 'skipSolve');
            both = Quadrupedal_ZeroFun_v2( ...
                X, ParaInfiniteInertia, pairConstraint, 'skipSolve');

            testCase.verifyNumElements(base, 22);
            testCase.verifyNumElements(constrained, 24);
            testCase.verifyNumElements(infiniteInertia, 23);
            testCase.verifyNumElements(both, 25);
        end

        function multiplePairConstraintsUseOnlyFirstRecognizedPair(testCase)
            % CHARACTERIZATION OF CURRENT DEFECT: the elseif chain composes
            % only the first recognized pair in its fixed source order.
            X = testCase.ReferenceResults(1:22, 1);
            Para = testCase.ReferenceResults(23:29, 1);
            backPairOnly = Quadrupedal_ZeroFun_v2( ...
                X, Para, {'(BL,BR)'}, 'skipSolve');
            multiplePairs = Quadrupedal_ZeroFun_v2( ...
                X, Para, {'(FL,FR)', '(BL,BR)'}, 'skipSolve');
            testCase.verifyEqual(multiplePairs, backPairOnly);
        end

        function acceptedStructConstraintFailsDownstream(testCase)
            % CHARACTERIZATION OF CURRENT DEFECT: the parser accepts a
            % struct that the downstream ismember chain cannot consume.
            X = testCase.ReferenceResults(1:22, 1);
            Para = testCase.ReferenceResults(23:29, 1);
            didError = false;
            try
                Quadrupedal_ZeroFun_v2( ...
                    X, Para, struct('pair', '(BL,BR)'), 'skipSolve');
            catch
                didError = true;
            end
            testCase.verifyTrue(didError);
        end

        function generatedBackConstraintIsDifferentiallyConsistent(testCase)
            q = [0.3; 1.1; 0.1; 0.2; -0.2];
            dq = [0.4; 0.05; 0.12; 0; 0];
            ddq = [0.1; -0.2; 0.03; 0; 0];
            lb = 0.45;
            input = [q; dq; ddq; lb];
            [dalpha, ddalpha] = Func_alphaB_VA_v2(input);
            dq(4) = dalpha;
            ddq(4) = ddalpha;
            VerifyFootConstraint(testCase, q, dq, ddq, lb, true);
        end

        function generatedFrontConstraintIsDifferentiallyConsistent(testCase)
            q = [0.3; 1.1; 0.1; 0.2; -0.2];
            dq = [0.4; 0.05; 0.12; 0; 0];
            ddq = [0.1; -0.2; 0.03; 0; 0];
            lb = 0.45;
            input = [q; dq; ddq; lb];
            [dalpha, ddalpha] = Func_alphaF_VA_v2(input);
            dq(5) = dalpha;
            ddq(5) = ddalpha;
            VerifyFootConstraint(testCase, q, dq, ddq, lb, false);
        end
    end
end

function VerifyFootConstraint(testCase, q, dq, ddq, lb, isBack)
    velocityStep = 1e-6;
    velocity = (FootX(q + velocityStep * dq, lb, isBack) - ...
        FootX(q - velocityStep * dq, lb, isBack)) / (2 * velocityStep);
    testCase.verifyEqual(velocity, 0, 'AbsTol', 1e-7);

    accelerationStep = 1e-4;
    qPlus = q + accelerationStep * dq + ...
        0.5 * accelerationStep^2 * ddq;
    qMinus = q - accelerationStep * dq + ...
        0.5 * accelerationStep^2 * ddq;
    acceleration = (FootX(qPlus, lb, isBack) - 2 * FootX(q, lb, isBack) + ...
        FootX(qMinus, lb, isBack)) / accelerationStep^2;
    testCase.verifyEqual(acceleration, 0, 'AbsTol', 2e-5);
end

function xFoot = FootX(q, lb, isBack)
    x = q(1);
    y = q(2);
    phi = q(3);
    if isBack
        alpha = q(4);
        jointX = x - lb * cos(phi);
        jointY = y - lb * sin(phi);
    else
        alpha = q(5);
        jointX = x + (1 - lb) * cos(phi);
        jointY = y + (1 - lb) * sin(phi);
    end
    xFoot = jointX + jointY * tan(phi + alpha);
end
