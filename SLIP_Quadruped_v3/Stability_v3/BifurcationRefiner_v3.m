classdef BifurcationRefiner_v3
    %BIFURCATIONREFINER_V3 Refine smooth codimension-one candidates.
    %   The unit-multiplier refinement solves the Moore--Spence system
    %
    %       F(u,mu)          = 0,
    %       F_u(u,mu) v     = 0,
    %       c' v - 1        = 0.
    %
    %   A candidate is called a fold only after the left/right null-vector
    %   tests and the nondegeneracy coefficients
    %
    %       a = w' F_mu,    b = 1/2 w' F_uu[v,v]
    %
    %   both exceed their configured tolerances.  Period-doubling and
    %   Neimark--Sacker refinements use the derivative of the full-cycle
    %   Poincare map.  All entry points reject unresolved hybrid topology.

    properties
        ActiveParameterIndex = 1
        DifferenceStep = eps^(1/3)
        SecondDifferenceStep = eps^(1/4)
        FunctionTolerance = 1e-10
        StepTolerance = 1e-11
        ResidualAcceptanceTolerance = 1e-8
        MaxIterations = 80
        MaxFunctionEvaluations = 10000
        SingularValueTolerance = 1e-7
        MultiplierTolerance = 1e-6
        CandidateMultiplierTolerance = 5e-2
        NondegeneracyTolerance = 1e-6
        ImaginaryTolerance = 1e-7
        RequireReliable = true
        RequireCompatibleTopology = true
        % Ordinary finite differences are permitted only after the caller
        % explicitly declares that the supplied callbacks are smooth.  A
        % hybrid refinement must instead supply HybridFiniteDifferenceJacobian_v3.
        AssumeSmoothCallbacks = false
        Jacobian = []
    end

    methods
        function obj = BifurcationRefiner_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            if isempty(obj.Jacobian)
                obj.Jacobian = FiniteDifferenceJacobian_v3( ...
                    'Method', 'central', ...
                    'RelativeStep', obj.DifferenceStep);
            end
            obj.validateOptions();
        end

        function result = refineUnitMultiplier(obj, residual, u0, p0, q0, candidate)
            if nargin < 6
                candidate = struct();
            end
            result = obj.emptyResult('unit_multiplier');
            result.derivativeModel = obj.derivativeModel();
            result.eligibilityEvidence = candidate;
            result = obj.recordEligibilityEvidence(result, candidate);
            [eligible, reason] = obj.refinementEligible(candidate);
            if ~eligible
                result.message = reason;
                result.classification = 'refinement_rejected';
                result.topology = candidate;
                return
            end
            [candidateMultiplier, multiplierValid, multiplierReason] = ...
                obj.realCandidateEvidence(candidate, 1, 'unit-multiplier');
            result.initialCandidateMultiplier = candidateMultiplier;
            if ~multiplierValid
                result.message = multiplierReason;
                result.classification = 'refinement_rejected';
                return
            end

            u0 = u0(:);
            p0 = p0(:);
            obj.validateParameterIndex(p0);
            [Fu0, ~] = obj.residualJacobian(residual, u0, p0, q0);
            [~, ~, V0] = svd(Fu0, 'econ');
            v0 = obj.initialVector(candidate, V0(:, end), numel(u0));
            c = obj.normalizationVector(candidate, v0);
            v0 = obj.normalizeRight(v0, c);
            z0 = [u0; p0(obj.ActiveParameterIndex); v0];
            evaluationCount = 0;

            function [value, info] = augmented(z)
                evaluationCount = evaluationCount + 1;
                u = z(1:numel(u0));
                p = p0;
                p(obj.ActiveParameterIndex) = z(numel(u0) + 1);
                v = z(numel(u0) + 2:end);
                [f, info] = obj.evaluateResidualWithInfo(residual, u, p, q0);
                obj.assertMetadataValid(info, 'residual');
                [Fu, derivativeInfo] = obj.residualJacobian(residual, u, p, q0);
                info = obj.augmentedMetadata(info, derivativeInfo);
                value = [f; Fu * v; c' * v - 1];
            end

            [z, solveInfo] = obj.solveAugmented(@augmented, z0);
            n = numel(u0);
            u = z(1:n);
            p = p0;
            p(obj.ActiveParameterIndex) = z(n + 1);
            v = z(n + 2:end);
            [f, topology] = obj.evaluateResidualWithInfo(residual, u, p, q0);
            [Fu, fdInfo] = obj.residualJacobian(residual, u, p, q0);
            [U, S, ~] = svd(Fu, 'econ');
            singularValues = diag(S);
            if isempty(singularValues)
                smallest = NaN;
                w = NaN(size(u));
            else
                smallest = singularValues(end);
                w = U(:, end);
            end
            v = obj.normalizeRight(v, c);
            [w, biorthogonal] = obj.normalizeLeft(w, v);
            Fmu = obj.parameterDerivative(residual, u, p, q0);
            Fuu = obj.secondDirectionalDerivative(residual, u, p, q0, v);
            a = real(w' * Fmu);
            b = 0.5 * real(w' * Fuu);
            nullResidual = norm(Fu * v, Inf);
            converged = solveInfo.converged && ...
                norm(f, Inf) <= obj.ResidualAcceptanceTolerance && ...
                nullResidual <= obj.ResidualAcceptanceTolerance && ...
                obj.derivativeInfoReliable(fdInfo) && ...
                obj.metadataValid(topology) && ...
                isfinite(smallest) && ...
                smallest <= obj.SingularValueTolerance * max(1, norm(Fu, 2));

            result = obj.populateResult(result, u, p, q0, f, solveInfo, ...
                evaluationCount, topology, Fu, fdInfo, v, w, ...
                singularValues, smallest);
            result.nullResidual = nullResidual;
            result.biorthogonalProduct = biorthogonal;
            result.nondegeneracy = struct('a', a, 'b', b, ...
                'tolerance', obj.NondegeneracyTolerance);
            result.criticalMultiplier = 1;
            result.converged = converged;
            result.reliable = converged;
            result.derivativeModel = obj.derivativeModel();
            result.eligibilityEvidence = candidate;
            if converged && abs(a) > obj.NondegeneracyTolerance && ...
                    abs(b) > obj.NondegeneracyTolerance
                result.classification = 'fold';
                result.classificationConfidence = 'validated-local';
                result.message = 'Moore--Spence equations and fold nondegeneracy tests passed.';
            elseif converged && abs(a) <= obj.NondegeneracyTolerance
                result.classification = 'unit_multiplier_degeneracy_unresolved';
                result.classificationConfidence = 'insufficient';
                result.message = ['F_mu is tangent to the range of F_u; ', ...
                    'pitchfork/transcritical/symmetry information is required.'];
            elseif converged
                result.classification = 'degenerate_fold_candidate';
                result.classificationConfidence = 'insufficient';
                result.message = 'The quadratic fold coefficient is below tolerance.';
            else
                result.classification = 'unit_multiplier_refinement_failed';
                result.classificationConfidence = 'none';
                result.message = solveInfo.message;
            end
        end

        function result = refinePeriodDoubling(obj, residual, mapFunction, ...
                u0, p0, q0, candidate)
            if nargin < 7
                candidate = struct();
            end
            result = obj.emptyResult('period_doubling');
            result.derivativeModel = obj.derivativeModel();
            result.eligibilityEvidence = candidate;
            result = obj.recordEligibilityEvidence(result, candidate);
            [eligible, reason] = obj.refinementEligible(candidate);
            if ~eligible
                result.message = reason;
                result.classification = 'refinement_rejected';
                result.topology = candidate;
                return
            end
            [candidateMultiplier, multiplierValid, multiplierReason] = ...
                obj.realCandidateEvidence(candidate, -1, ...
                    'period-doubling');
            result.initialCandidateMultiplier = candidateMultiplier;
            if ~multiplierValid
                result.message = multiplierReason;
                result.classification = 'refinement_rejected';
                return
            end
            u0 = u0(:);
            p0 = p0(:);
            obj.validateParameterIndex(p0);
            DP0 = obj.mapJacobian(mapFunction, u0, p0, q0);
            [vectors0, values0] = eig(DP0, 'vector');
            [~, index0] = min(abs(values0 + 1));
            v0 = obj.initialVector(candidate, real(vectors0(:, index0)), numel(u0));
            c = obj.normalizationVector(candidate, v0);
            v0 = obj.normalizeRight(v0, c);
            z0 = [u0; p0(obj.ActiveParameterIndex); v0];
            residualEvaluations = 0;
            mapEvaluations = 0;

            function [value, info] = augmented(z)
                residualEvaluations = residualEvaluations + 1;
                u = z(1:numel(u0));
                p = p0;
                p(obj.ActiveParameterIndex) = z(numel(u0) + 1);
                v = z(numel(u0) + 2:end);
                [f, info] = obj.evaluateResidualWithInfo(residual, u, p, q0);
                obj.assertMetadataValid(info, 'residual');
                [DP, count, derivativeInfo] = ...
                    obj.mapJacobian(mapFunction, u, p, q0);
                mapEvaluations = mapEvaluations + count;
                info = obj.augmentedMetadata(info, derivativeInfo);
                value = [f; (DP + eye(numel(u))) * v; c' * v - 1];
            end

            [z, solveInfo] = obj.solveAugmented(@augmented, z0);
            n = numel(u0);
            u = z(1:n);
            p = p0;
            p(obj.ActiveParameterIndex) = z(n + 1);
            v = obj.normalizeRight(z(n + 2:end), c);
            [f, topology] = obj.evaluateResidualWithInfo(residual, u, p, q0);
            [DP, count, mapInfo] = obj.mapJacobian(mapFunction, u, p, q0);
            mapEvaluations = mapEvaluations + count;
            criticalMatrix = DP + eye(n);
            [U, S, ~] = svd(criticalMatrix, 'econ');
            singularValues = diag(S);
            smallest = singularValues(end);
            w = U(:, end);
            [w, biorthogonal] = obj.normalizeLeft(w, v);
            values = eig(DP);
            [~, index] = min(abs(values + 1));
            critical = values(index);
            nullResidual = norm(criticalMatrix * v, Inf);
            converged = solveInfo.converged && ...
                norm(f, Inf) <= obj.ResidualAcceptanceTolerance && ...
                nullResidual <= obj.ResidualAcceptanceTolerance && ...
                obj.derivativeInfoReliable(mapInfo) && ...
                obj.metadataValid(topology) && ...
                abs(critical + 1) <= obj.MultiplierTolerance;

            result = obj.populateResult(result, u, p, q0, f, solveInfo, ...
                residualEvaluations, topology, criticalMatrix, mapInfo, ...
                v, w, singularValues, smallest);
            result.mapEvaluations = mapEvaluations;
            result.returnMatrix = DP;
            result.multipliers = values;
            result.criticalMultiplier = critical;
            result.nullResidual = nullResidual;
            result.biorthogonalProduct = biorthogonal;
            result.converged = converged;
            result.reliable = converged;
            result.derivativeModel = obj.derivativeModel();
            result.eligibilityEvidence = candidate;
            if converged
                result.classification = 'period_doubling';
                result.classificationConfidence = 'validated-local';
                result.message = 'The doubled-map critical equation has a reliable multiplier at -1.';
            else
                result.classification = 'period_doubling_refinement_failed';
                result.classificationConfidence = 'none';
                result.message = solveInfo.message;
            end
        end

        function result = refineNeimarkSacker(obj, residual, mapFunction, ...
                u0, p0, q0, candidate)
            if nargin < 7
                candidate = struct();
            end
            result = obj.emptyResult('Neimark_Sacker');
            result.derivativeModel = obj.derivativeModel();
            result.eligibilityEvidence = candidate;
            result = obj.recordEligibilityEvidence(result, candidate);
            [eligible, reason] = obj.refinementEligible(candidate);
            if ~eligible
                result.message = reason;
                result.classification = 'refinement_rejected';
                result.topology = candidate;
                return
            end
            u0 = u0(:);
            p0 = p0(:);
            [candidateMultiplier, candidateVector, candidateValid, ...
                candidateReason] = obj.complexCandidateEvidence( ...
                candidate, numel(u0));
            if ~candidateValid
                result.message = candidateReason;
                result.classification = 'refinement_rejected';
                return
            end
            DP0 = obj.mapJacobian(mapFunction, u0, p0, q0);
            [V0, lambda0] = eig(DP0, 'vector');
            complexIndices = find(abs(imag(lambda0)) > obj.ImaginaryTolerance);
            if isempty(complexIndices)
                result.message = 'The initial matrix has no nonreal conjugate pair.';
                result.classification = 'refinement_rejected';
                return
            end
            spectralDistance = abs(lambda0(complexIndices) - ...
                candidateMultiplier) ./ (1 + abs(candidateMultiplier));
            minimumDistance = min(spectralDistance);
            tied = find(spectralDistance <= minimumDistance + ...
                100 * eps(max(1, minimumDistance)));
            candidateOverlap = NaN(size(complexIndices));
            if ~isempty(candidateVector)
                for overlapIndex = 1:numel(complexIndices)
                    eigenvector = V0(:, complexIndices(overlapIndex));
                    candidateOverlap(overlapIndex) = abs( ...
                        candidateVector' * eigenvector) / ...
                        (norm(candidateVector) * norm(eigenvector));
                end
                if numel(tied) > 1
                    [~, overlapWinner] = max(candidateOverlap(tied));
                    selectedLocalIndex = tied(overlapWinner);
                else
                    selectedLocalIndex = tied(1);
                end
            else
                selectedLocalIndex = tied(1);
            end
            complexIndex = complexIndices(selectedLocalIndex);
            selectionDistance = spectralDistance(selectedLocalIndex);
            selectionOverlap = candidateOverlap(selectedLocalIndex);
            if selectionDistance > obj.CandidateMultiplierTolerance
                result.message = sprintf([ ...
                    'The supplied complex candidate is incompatible with ', ...
                    'the initial return matrix (normalized distance %.3g).'], ...
                    selectionDistance);
                result.classification = 'refinement_rejected';
                result.initialCandidateMultiplier = candidateMultiplier;
                result.initialSelectedMultiplier = lambda0(complexIndex);
                result.candidateSelectionDistance = selectionDistance;
                result.candidateVectorOverlap = selectionOverlap;
                return
            end
            vector0 = V0(:, complexIndex);
            a0 = real(vector0);
            b0 = imag(vector0);
            if norm(a0) <= eps || norm(b0) <= eps
                result.message = 'The complex eigenvector cannot define a real two-dimensional block.';
                result.classification = 'refinement_rejected';
                return
            end
            c = a0 / (a0' * a0);
            a0 = a0 / (c' * a0);
            b0 = b0 - a0 * (c' * b0);
            theta0 = angle(lambda0(complexIndex));
            z0 = [u0; p0(obj.ActiveParameterIndex); a0; b0; theta0];
            mapEvaluations = 0;

            function [value, info] = augmented(z)
                n = numel(u0);
                u = z(1:n);
                p = p0;
                p(obj.ActiveParameterIndex) = z(n + 1);
                a = z(n + 2:2*n + 1);
                b = z(2*n + 2:3*n + 1);
                theta = z(end);
                [f, info] = obj.evaluateResidualWithInfo(residual, u, p, q0);
                obj.assertMetadataValid(info, 'residual');
                [DP, count, derivativeInfo] = ...
                    obj.mapJacobian(mapFunction, u, p, q0);
                mapEvaluations = mapEvaluations + count;
                info = obj.augmentedMetadata(info, derivativeInfo);
                value = [f; ...
                    DP * a - cos(theta) * a + sin(theta) * b; ...
                    DP * b - sin(theta) * a - cos(theta) * b; ...
                    c' * a - 1; c' * b];
            end

            [z, solveInfo] = obj.solveAugmented(@augmented, z0);
            n = numel(u0);
            u = z(1:n);
            p = p0;
            p(obj.ActiveParameterIndex) = z(n + 1);
            a = z(n + 2:2*n + 1);
            b = z(2*n + 2:3*n + 1);
            theta = mod(z(end), 2*pi);
            [f, topology] = obj.evaluateResidualWithInfo(residual, u, p, q0);
            [DP, count, mapInfo] = obj.mapJacobian(mapFunction, u, p, q0);
            mapEvaluations = mapEvaluations + count;
            values = eig(DP);
            target = exp(1i * theta);
            [~, index] = min(abs(values - target));
            critical = values(index);
            [~, conjugateIndex] = min(abs(values - conj(critical)));
            conjugateResidual = abs(values(conjugateIndex) - conj(critical));
            rightVector = a + 1i*b;
            criticalMatrix = DP - target * eye(n);
            eigenResidual = norm(criticalMatrix * rightVector, Inf);
            [~, singularMatrix, ~] = svd(criticalMatrix, 'econ');
            singularValues = diag(singularMatrix);
            [leftVectors, leftValues] = eig(DP', 'vector');
            [~, leftIndex] = min(abs(leftValues - conj(critical)));
            leftVector = leftVectors(:, leftIndex);
            [leftVector, biorthogonal] = ...
                obj.normalizeLeft(leftVector, rightVector);
            converged = solveInfo.converged && ...
                norm(f, Inf) <= obj.ResidualAcceptanceTolerance && ...
                eigenResidual <= obj.ResidualAcceptanceTolerance && ...
                obj.derivativeInfoReliable(mapInfo) && ...
                obj.metadataValid(topology) && ...
                abs(abs(critical) - 1) <= obj.MultiplierTolerance && ...
                abs(imag(critical)) > obj.ImaginaryTolerance && ...
                conjugateResidual <= obj.MultiplierTolerance;

            result = obj.populateResult(result, u, p, q0, f, solveInfo, ...
                0, topology, criticalMatrix, mapInfo, rightVector, ...
                leftVector, singularValues, singularValues(end));
            result.mapEvaluations = mapEvaluations;
            result.returnMatrix = DP;
            result.multipliers = values;
            result.criticalMultiplier = critical;
            result.initialCandidateMultiplier = candidateMultiplier;
            result.initialSelectedMultiplier = lambda0(complexIndex);
            result.candidateSelectionDistance = selectionDistance;
            result.candidateVectorOverlap = selectionOverlap;
            result.criticalAngle = angle(critical);
            result.conjugateMultiplier = values(conjugateIndex);
            result.conjugacyResidual = conjugateResidual;
            result.nullResidual = eigenResidual;
            result.biorthogonalProduct = biorthogonal;
            result.converged = converged;
            result.reliable = converged;
            result.derivativeModel = obj.derivativeModel();
            result.eligibilityEvidence = candidate;
            if converged
                result.classification = 'Neimark_Sacker';
                result.classificationConfidence = 'validated-local';
                result.message = 'A reliable nonreal conjugate pair was refined on the unit circle.';
            else
                result.classification = 'Neimark_Sacker_refinement_failed';
                result.classificationConfidence = 'none';
                result.message = solveInfo.message;
            end
        end
    end

    methods (Access = private)
        function [z, info] = solveAugmented(obj, fun, z0)
            if obj.AssumeSmoothCallbacks
                augmentedJacobian = FiniteDifferenceJacobian_v3( ...
                    'Method', 'central', ...
                    'RelativeStep', obj.DifferenceStep);
            else
                augmentedJacobian = obj.Jacobian;
                augmentedJacobian.CoordinateScale = [];
            end
            solver = RootSolver_v3( ...
                'Algorithm', 'newton', ...
                'FunctionTolerance', obj.FunctionTolerance, ...
                'StepTolerance', obj.StepTolerance, ...
                'OptimalityTolerance', obj.FunctionTolerance, ...
                'ResidualAcceptanceTolerance', obj.ResidualAcceptanceTolerance, ...
                'MaxIterations', obj.MaxIterations, ...
                'MaxFunctionEvaluations', obj.MaxFunctionEvaluations, ...
                'Jacobian', augmentedJacobian);
            [z, info] = solver.solve(fun, z0, zeros(0, 1), []);
        end

        function [J, info] = residualJacobian(obj, residual, u, p, q)
            function [value, metadata] = callback(trial, varargin)
                [value, metadata] = ...
                    obj.evaluateResidualWithInfo(residual, trial, p, q);
                obj.assertMetadataValid(metadata, 'residual');
                metadata = obj.completeTopologyMetadata(metadata);
            end
            [J, ~, info] = obj.Jacobian.compute(@callback, u);
        end

        function [DP, evaluations, info] = mapJacobian(obj, mapFunction, u, p, q)
            function [value, metadata] = callback(trial, varargin)
                [value, metadata] = obj.evaluateMap(mapFunction, trial, p, q);
                metadata = obj.completeTopologyMetadata(metadata);
            end
            [DP, ~, info] = obj.Jacobian.compute(@callback, u);
            evaluations = obj.derivativeEvaluationCount(info);
        end

        function value = parameterDerivative(obj, residual, u, p, q)
            step = obj.DifferenceStep * (1 + abs(p(obj.ActiveParameterIndex)));
            plus = p;
            minus = p;
            plus(obj.ActiveParameterIndex) = plus(obj.ActiveParameterIndex) + step;
            minus(obj.ActiveParameterIndex) = minus(obj.ActiveParameterIndex) - step;
            [~, baseInfo] = ...
                obj.evaluateResidualWithInfo(residual, u, p, q);
            [plusValue, plusInfo] = ...
                obj.evaluateResidualWithInfo(residual, u, plus, q);
            [minusValue, minusInfo] = ...
                obj.evaluateResidualWithInfo(residual, u, minus, q);
            obj.assertCompatibleStencil(baseInfo, plusInfo, minusInfo, ...
                'active-parameter derivative');
            value = (plusValue - minusValue) / (2 * step);
        end

        function value = secondDirectionalDerivative(obj, residual, u, p, q, v)
            direction = v(:) / max(norm(v), eps);
            step = obj.SecondDifferenceStep * (1 + norm(u));
            [f0, baseInfo] = obj.evaluateResidualWithInfo(residual, u, p, q);
            [fp, plusInfo] = obj.evaluateResidualWithInfo( ...
                residual, u + step * direction, p, q);
            [fm, minusInfo] = obj.evaluateResidualWithInfo( ...
                residual, u - step * direction, p, q);
            obj.assertCompatibleStencil(baseInfo, plusInfo, minusInfo, ...
                'second directional derivative');
            value = (fp - 2*f0 + fm) / step^2;
            % Restore the requested (possibly non-unit) directional scale.
            value = value * norm(v)^2;
        end

        function [value, info] = evaluateResidualWithInfo(obj, residual, u, p, q)
            info = struct();
            if isa(residual, 'function_handle')
                [value, info] = obj.callFunctionWithInfo(residual, u, p, q);
            elseif isobject(residual) && ismethod(residual, 'evaluateWithInfo')
                [value, info] = residual.evaluateWithInfo(u, p, q);
            elseif isobject(residual) && ismethod(residual, 'evaluate')
                value = residual.evaluate(u, p, q);
            elseif isstruct(residual) && isfield(residual, 'evaluateWithInfo')
                [value, info] = obj.callFunctionWithInfo( ...
                    residual.evaluateWithInfo, u, p, q);
            elseif isstruct(residual) && isfield(residual, 'evaluate')
                [value, info] = obj.callFunctionWithInfo(residual.evaluate, u, p, q);
            else
                error('BifurcationRefiner_v3:ResidualInterface', ...
                    'Residual must be a function handle or expose evaluate().');
            end
            value = value(:);
            if any(~isfinite(value))
                error('BifurcationRefiner_v3:NonfiniteResidual', ...
                    'The periodic-orbit residual is nonfinite.');
            end
        end

        function value = evaluateResidual(obj, residual, u, p, q)
            [value, info] = obj.evaluateResidualWithInfo(residual, u, p, q);
            if ~obj.metadataValid(info)
                error('BifurcationRefiner_v3:InvalidHybridReturn', ...
                    'The residual evaluation rejected the hybrid return.');
            end
        end

        function [value, info] = evaluateMap(obj, mapFunction, u, p, q)
            if isa(mapFunction, 'function_handle')
                [value, info] = obj.callFunctionWithInfo(mapFunction, u, p, q);
            elseif isobject(mapFunction) && ismethod(mapFunction, 'evaluate')
                [value, info] = mapFunction.evaluate(u, q, p);
            elseif isstruct(mapFunction) && isfield(mapFunction, 'evaluate')
                [value, info] = obj.callFunctionWithInfo(mapFunction.evaluate, u, p, q);
            else
                error('BifurcationRefiner_v3:MapInterface', ...
                    'Map must be a function handle or expose evaluate().');
            end
            value = value(:);
            if numel(value) ~= numel(u) || any(~isfinite(value)) || ...
                    ~obj.metadataValid(info)
                error('BifurcationRefiner_v3:InvalidMapReturn', ...
                    'The full-cycle map returned an invalid state or topology.');
            end
        end

        function [value, info] = callFunctionWithInfo(~, fun, u, p, q)
            n = nargin(fun);
            if n == 1
                arguments = {u};
            elseif n == 2
                arguments = {u, p};
            else
                arguments = {u, p, q};
            end
            info = struct();
            try
                [value, info] = fun(arguments{:});
            catch exception
                if ~any(strcmp(exception.identifier, { ...
                        'MATLAB:maxlhs', 'MATLAB:TooManyOutputs', ...
                        'MATLAB:unassignedOutputs'}))
                    rethrow(exception)
                end
                value = fun(arguments{:});
            end
        end

        function tf = metadataValid(obj, info)
            if obj.AssumeSmoothCallbacks
                tf = true;
            else
                tf = obj.hybridMetadataComplete(info);
            end
            if ~tf || isempty(info) || ~isstruct(info)
                return
            end
            falseFields = {'valid', 'success', 'admissible', ...
                'integration_success', 'cycle_complete', ...
                'return_policy_accepted', 'discrete_closed', ...
                'mode_closed', 'modeClosure'};
            for index = 1:numel(falseFields)
                name = falseFields{index};
                if isfield(info, name) && ~logical(info.(name))
                    tf = false;
                    return
                end
            end
            if obj.RequireReliable && isfield(info, 'reliable') && ...
                    (~isscalar(info.reliable) || ~logical(info.reliable))
                tf = false;
            end
        end

        function [eligible, reason] = refinementEligible(obj, metadata)
            eligible = false;
            reason = '';
            if ~(isstruct(metadata) && isscalar(metadata))
                reason = ['Explicit convergence, reliability, and topology ', ...
                    'evidence is required for refinement.'];
                return
            end

            [converged, convergencePresent] = obj.logicalEvidence(metadata, ...
                {'converged', 'orbit_converged', 'root_converged'});
            if ~convergencePresent || ~converged
                reason = ['A converged periodic-orbit/Floquet candidate must ', ...
                    'be supplied explicitly.'];
                return
            end

            [reliable, reliabilityPresent] = obj.logicalEvidence(metadata, ...
                {'reliable', 'floquetReliable', 'floquet_reliable'});
            if ~reliabilityPresent || ~reliable
                reason = ['Explicit reliable Floquet/derivative evidence is ', ...
                    'required for refinement.'];
                return
            end

            [compatible, compatibilityPresent] = obj.logicalEvidence( ...
                metadata, {'topologyCompatible', 'topology_compatible'});
            if ~compatibilityPresent || ~compatible
                reason = ['Explicit compatible-topology evidence is ', ...
                    'required for refinement.'];
                return
            end
            [chartBoundary, chartEvidence] = obj.logicalAnyEvidence(metadata, ...
                {'hybridChartBoundary', 'hybrid_chart_boundary'});
            [coincidence, coincidenceEvidence] = obj.logicalAnyEvidence( ...
                metadata, {'section_event_coincidence', ...
                'section_cluster_coincidence'});
            [unresolved, orderingEvidence] = obj.logicalAnyEvidence(metadata, ...
                {'unresolvedSimultaneousOrdering', ...
                'unresolved_simultaneous_ordering'});
            if ~chartEvidence || ~coincidenceEvidence || ~orderingEvidence
                reason = ['Explicit evidence excluding chart boundaries, ', ...
                    'section/event coincidence, and unresolved event ', ...
                    'ordering is required.'];
                return
            end
            if chartBoundary || coincidence || unresolved
                reason = ['The candidate lies on an incompatible hybrid chart ', ...
                    'or has unresolved simultaneous-event ordering.'];
                return
            end

            if ~obj.AssumeSmoothCallbacks && ...
                    ~isa(obj.Jacobian, 'HybridFiniteDifferenceJacobian_v3')
                reason = ['Ordinary finite differences require the explicit ', ...
                    'AssumeSmoothCallbacks=true declaration; hybrid refinement ', ...
                    'requires HybridFiniteDifferenceJacobian_v3.'];
                return
            end
            eligible = true;
        end

        function assertMetadataValid(obj, info, source)
            if ~obj.metadataValid(info)
                error('BifurcationRefiner_v3:IncompleteHybridEvidence', ...
                    ['The %s callback did not provide complete, valid hybrid ', ...
                     'topology evidence.'], source);
            end
        end

        function complete = hybridMetadataComplete(obj, info)
            complete = isstruct(info) && isscalar(info) && ...
                ~isempty(fieldnames(info));
            if ~complete
                return
            end
            [cycle, cyclePresent] = obj.logicalEvidenceInSource(info, ...
                {'cycle_complete', 'cycleComplete', ...
                 'return_policy_accepted'});
            [closed, closurePresent] = obj.logicalEvidenceInSource(info, ...
                {'discrete_closed', 'discreteClosure', 'mode_closed', ...
                 'modeClosure'});
            multiplicity = obj.memberAny(info, ...
                {'return_multiplicity', 'returnMultiplicity'}, NaN);
            multiplicityPresent = isscalar(multiplicity) && ...
                isnumeric(multiplicity) && isfinite(multiplicity) && ...
                multiplicity >= 1;
            signaturesPresent = ~isempty(obj.topologySignature(info, 'cyclic')) && ...
                ~isempty(obj.topologySignature(info, 'section')) && ...
                ~isempty(obj.topologySignature(info, 'cluster'));
            complete = cyclePresent && cycle && closurePresent && closed && ...
                multiplicityPresent && signaturesPresent;
            [boundary, ~] = obj.logicalAnyEvidence(info, ...
                {'hybridChartBoundary', 'hybrid_chart_boundary', ...
                 'section_event_coincidence', 'section_cluster_coincidence', ...
                 'unresolvedSimultaneousOrdering', ...
                 'unresolved_simultaneous_ordering'});
            complete = complete && ~boundary;
            if isfield(info, 'topology_metadata_complete')
                complete = complete && ...
                    isscalar(info.topology_metadata_complete) && ...
                    logical(info.topology_metadata_complete);
            end
        end

        function info = completeTopologyMetadata(obj, info)
            if isempty(info) || ~isstruct(info)
                info = struct();
            end
            if ~obj.AssumeSmoothCallbacks
                info.topology_metadata_complete = ...
                    obj.hybridMetadataComplete(info);
            end
        end

        function info = augmentedMetadata(obj, info, derivativeInfo)
            info = obj.completeTopologyMetadata(info);
            reliable = obj.derivativeInfoReliable(derivativeInfo);
            info.derivative_reliable = reliable;
            info.reliable = reliable;
            if ~obj.AssumeSmoothCallbacks
                info.topology_metadata_complete = ...
                    obj.hybridMetadataComplete(info) && reliable;
                info.valid = obj.metadataValid(info) && reliable;
                info.integration_success = info.valid;
            end
        end

        function assertCompatibleStencil(obj, baseline, plus, minus, label)
            if obj.AssumeSmoothCallbacks
                return
            end
            obj.assertMetadataValid(baseline, label);
            obj.assertMetadataValid(plus, label);
            obj.assertMetadataValid(minus, label);
            if ~obj.topologyMetadataCompatible(baseline, plus) || ...
                    ~obj.topologyMetadataCompatible(baseline, minus)
                error('BifurcationRefiner_v3:HybridStencilTopology', ...
                    'The %s stencil crosses a hybrid topology boundary.', label);
            end
        end

        function compatible = topologyMetadataCompatible(obj, left, right)
            compatible = obj.hybridMetadataComplete(left) && ...
                obj.hybridMetadataComplete(right);
            if ~compatible
                return
            end
            multiplicityNames = {'return_multiplicity', 'returnMultiplicity'};
            leftMultiplicity = obj.memberAny(left, multiplicityNames, NaN);
            rightMultiplicity = obj.memberAny(right, multiplicityNames, NaN);
            if ~(isscalar(leftMultiplicity) && isfinite(leftMultiplicity) && ...
                    isequal(leftMultiplicity, rightMultiplicity))
                compatible = false;
                return
            end
            kinds = {'cyclic', 'section', 'cluster'};
            for index = 1:numel(kinds)
                if ~strcmp(obj.topologySignature(left, kinds{index}), ...
                        obj.topologySignature(right, kinds{index}))
                    compatible = false;
                    return
                end
            end
        end

        function signature = topologySignature(obj, source, kind)
            switch kind
                case 'cyclic'
                    names = {'cyclic_event_signature', ...
                        'cyclicEventSignature', 'cycle_signature'};
                case 'section'
                    names = {'section_relative_event_signature', ...
                        'sectionRelativeEventSignature', 'event_signature'};
                otherwise
                    names = {'event_cluster_signature', ...
                        'eventClusterSignature', 'cluster_signature'};
            end
            signature = obj.memberAny(source, names, '');
            if isstring(signature)
                signature = char(strjoin(signature(:), '|'));
            elseif iscell(signature)
                signature = char(strjoin(string(signature(:)), '|'));
            elseif isnumeric(signature) || islogical(signature)
                signature = mat2str(signature);
            elseif ~ischar(signature)
                signature = '';
            end
        end

        function [value, present] = logicalEvidence(obj, metadata, names)
            sources = {metadata, obj.member(metadata, 'topology', struct()), ...
                obj.member(metadata, 'floquet', struct()), ...
                obj.member(metadata, 'diagnostics', struct())};
            value = false;
            present = false;
            for index = 1:numel(sources)
                [value, present] = ...
                    obj.logicalEvidenceInSource(sources{index}, names);
                if present
                    return
                end
            end
        end

        function [value, present] = logicalAnyEvidence(obj, metadata, names)
            sources = {metadata, obj.member(metadata, 'topology', struct()), ...
                obj.member(metadata, 'floquet', struct()), ...
                obj.member(metadata, 'diagnostics', struct())};
            value = false;
            present = false;
            for sourceIndex = 1:numel(sources)
                source = sources{sourceIndex};
                if ~(isstruct(source) && isscalar(source))
                    continue
                end
                for nameIndex = 1:numel(names)
                    name = names{nameIndex};
                    if isfield(source, name) && isscalar(source.(name)) && ...
                            (islogical(source.(name)) || ...
                             isnumeric(source.(name))) && ...
                            isfinite(double(source.(name)))
                        present = true;
                        value = value || logical(source.(name));
                    end
                end
            end
        end

        function [value, present] = logicalEvidenceInSource(~, source, names)
            value = false;
            present = false;
            if ~(isstruct(source) && isscalar(source))
                return
            end
            for index = 1:numel(names)
                if isfield(source, names{index}) && ...
                        isscalar(source.(names{index})) && ...
                        (islogical(source.(names{index})) || ...
                         isnumeric(source.(names{index}))) && ...
                        isfinite(double(source.(names{index})))
                    value = logical(source.(names{index}));
                    present = true;
                    return
                end
            end
        end

        function reliable = derivativeInfoReliable(~, info)
            reliable = false;
            if ~(isstruct(info) && isscalar(info))
                return
            end
            if isfield(info, 'allReliable')
                reliable = isscalar(info.allReliable) && ...
                    logical(info.allReliable);
            elseif isfield(info, 'success')
                reliable = isscalar(info.success) && logical(info.success);
            end
        end

        function count = derivativeEvaluationCount(~, info)
            count = 0;
            if ~(isstruct(info) && isscalar(info))
                return
            end
            if isfield(info, 'mapEvaluations') && ...
                    isscalar(info.mapEvaluations)
                count = info.mapEvaluations;
            elseif isfield(info, 'evaluations') && isscalar(info.evaluations)
                count = info.evaluations;
            end
        end

        function name = derivativeModel(obj)
            if obj.AssumeSmoothCallbacks
                name = 'explicit-smooth-callback-finite-difference';
            else
                name = 'topology-aware-hybrid-finite-difference';
            end
        end

        function result = recordEligibilityEvidence(obj, result, candidate)
            [compatible, compatiblePresent] = obj.logicalEvidence(candidate, ...
                {'topologyCompatible', 'topology_compatible'});
            [boundary, boundaryPresent] = obj.logicalAnyEvidence(candidate, ...
                {'hybridChartBoundary', 'hybrid_chart_boundary'});
            [coincidence, coincidencePresent] = obj.logicalAnyEvidence( ...
                candidate, {'section_event_coincidence', ...
                'section_cluster_coincidence'});
            [unresolved, orderingPresent] = obj.logicalAnyEvidence(candidate, ...
                {'unresolvedSimultaneousOrdering', ...
                'unresolved_simultaneous_ordering'});
            result.topologyCompatible = compatiblePresent && compatible;
            result.hybridChartBoundary = boundaryPresent && boundary;
            result.section_event_coincidence = ...
                coincidencePresent && coincidence;
            result.unresolvedSimultaneousOrdering = ...
                orderingPresent && unresolved;
            result.topologyEvidenceComplete = compatiblePresent && ...
                boundaryPresent && coincidencePresent && orderingPresent;
        end

        function v = initialVector(obj, candidate, fallback, dimension)
            v = obj.member(candidate, 'rightVector', []);
            if isempty(v)
                v = obj.member(candidate, 'right_vector', []);
            end
            if isempty(v)
                v = obj.member(candidate, 'eigenvector', []);
            end
            if isempty(v)
                v = fallback;
            end
            v = real(v(:));
            if numel(v) ~= dimension || norm(v) <= eps
                error('BifurcationRefiner_v3:CriticalVector', ...
                    'The critical right vector has an incompatible dimension.');
            end
        end

        function [multiplier, vector, valid, reason] = ...
                complexCandidateEvidence(obj, candidate, dimension)
            multiplier = obj.memberAny(candidate, { ...
                'criticalMultiplier', 'critical_multiplier', ...
                'multiplierEstimate', 'multiplier_estimate', ...
                'multiplier'}, NaN);
            vector = obj.memberAny(candidate, { ...
                'rightVector', 'right_vector', 'eigenvector'}, []);
            valid = false;
            reason = '';
            if ~(isnumeric(multiplier) && isscalar(multiplier) && ...
                    isfinite(real(multiplier)) && isfinite(imag(multiplier)))
                reason = ['Neimark--Sacker refinement requires an explicit ', ...
                    'finite candidate critical multiplier.'];
                return
            end
            if abs(imag(multiplier)) <= obj.ImaginaryTolerance
                reason = ['The supplied Neimark--Sacker candidate multiplier ', ...
                    'is not demonstrably nonreal.'];
                return
            end
            if ~isempty(vector)
                vector = vector(:);
                if ~isnumeric(vector) || numel(vector) ~= dimension || ...
                        any(~isfinite(real(vector))) || ...
                        any(~isfinite(imag(vector))) || norm(vector) <= eps
                    reason = ['The supplied Neimark--Sacker critical vector ', ...
                        'has an incompatible dimension or is nonfinite.'];
                    return
                end
            end
            valid = true;
        end

        function [multiplier, valid, reason] = realCandidateEvidence( ...
                obj, candidate, target, label)
            multiplier = obj.memberAny(candidate, { ...
                'criticalMultiplier', 'critical_multiplier', ...
                'multiplierEstimate', 'multiplier_estimate', ...
                'multiplier'}, NaN);
            valid = false;
            reason = '';
            if ~(isnumeric(multiplier) && isscalar(multiplier) && ...
                    isfinite(real(multiplier)) && isfinite(imag(multiplier)))
                reason = sprintf([ ...
                    '%s refinement requires an explicit finite candidate ', ...
                    'critical multiplier.'], label);
                return
            end
            if abs(imag(multiplier)) > obj.ImaginaryTolerance || ...
                    abs(multiplier - target) > ...
                        obj.CandidateMultiplierTolerance
                reason = sprintf([ ...
                    'Candidate multiplier %s is incompatible with the ', ...
                    '%s target %+g within tolerance %.3e.'], ...
                    obj.scalarText(multiplier), label, target, ...
                    obj.CandidateMultiplierTolerance);
                return
            end
            valid = true;
        end

        function value = scalarText(~, scalar)
            if ~(isnumeric(scalar) && isscalar(scalar))
                value = '<missing>';
            elseif isreal(scalar)
                value = sprintf('%.16g', scalar);
            else
                value = sprintf('%.16g%+.16gi', real(scalar), imag(scalar));
            end
        end

        function c = normalizationVector(obj, candidate, v)
            c = obj.member(candidate, 'normalizationVector', []);
            if isempty(c)
                c = obj.member(candidate, 'normalization_vector', []);
            end
            if isempty(c)
                c = v / (v' * v);
            end
            c = real(c(:));
            if numel(c) ~= numel(v) || abs(c' * v) <= eps
                error('BifurcationRefiner_v3:Normalization', ...
                    'The normalization vector is orthogonal to the critical vector.');
            end
        end

        function v = normalizeRight(~, v, c)
            scale = c' * v;
            if abs(scale) <= eps
                error('BifurcationRefiner_v3:RightNormalization', ...
                    'The right null vector cannot be normalized by c.');
            end
            v = v / scale;
        end

        function [w, product] = normalizeLeft(~, w, v)
            product = w' * v;
            if abs(product) <= 100 * eps
                w(:) = NaN;
                product = NaN;
                return
            end
            w = w / conj(product);
            product = w' * v;
        end

        function result = populateResult(~, result, u, p, q, f, solveInfo, ...
                evaluations, topology, matrix, fdInfo, v, w, values, smallest)
            result.state = u(:);
            result.parameter = p(:);
            result.mode = q;
            result.residual = f(:);
            result.residualNorm = norm(f, Inf);
            result.rightVector = v;
            result.leftVector = w;
            result.singularValues = values;
            result.smallestSingularValue = smallest;
            result.criticalMatrix = matrix;
            result.finiteDifference = fdInfo;
            result.topology = topology;
            result.solveInfo = solveInfo;
            result.functionEvaluations = evaluations;
            result.mapEvaluations = objMember(solveInfo, 'mapEvaluationCount', 0);

            function value = objMember(source, name, fallback)
                value = fallback;
                if isstruct(source) && isfield(source, name)
                    value = source.(name);
                end
            end
        end

        function result = emptyResult(~, type)
            result = struct( ...
                'type', type, ...
                'converged', false, ...
                'reliable', false, ...
                'topologyCompatible', false, ...
                'topologyEvidenceComplete', false, ...
                'hybridChartBoundary', false, ...
                'section_event_coincidence', false, ...
                'unresolvedSimultaneousOrdering', false, ...
                'classification', 'unrefined', ...
                'classificationConfidence', 'none', ...
                'state', [], ...
                'parameter', [], ...
                'mode', [], ...
                'residual', [], ...
                'residualNorm', Inf, ...
                'criticalMultiplier', NaN, ...
                'initialCandidateMultiplier', NaN, ...
                'initialSelectedMultiplier', NaN, ...
                'candidateSelectionDistance', Inf, ...
                'candidateVectorOverlap', NaN, ...
                'multipliers', [], ...
                'rightVector', [], ...
                'leftVector', [], ...
                'singularValues', [], ...
                'smallestSingularValue', NaN, ...
                'nullResidual', Inf, ...
                'criticalAngle', NaN, ...
                'conjugateMultiplier', NaN, ...
                'conjugacyResidual', Inf, ...
                'biorthogonalProduct', NaN, ...
                'nondegeneracy', struct(), ...
                'criticalMatrix', [], ...
                'returnMatrix', [], ...
                'finiteDifference', struct(), ...
                'derivativeModel', '', ...
                'eligibilityEvidence', struct(), ...
                'topology', struct(), ...
                'solveInfo', struct(), ...
                'functionEvaluations', 0, ...
                'mapEvaluations', 0, ...
                'message', '');
        end

        function value = member(~, source, name, fallback)
            value = fallback;
            if isstruct(source) && isfield(source, name)
                value = source.(name);
            end
        end


        function value = memberAny(~, source, names, fallback)
            value = fallback;
            if ~(isstruct(source) && isscalar(source))
                return
            end
            for index = 1:numel(names)
                if isfield(source, names{index}) && ...
                        ~isempty(source.(names{index}))
                    value = source.(names{index});
                    return
                end
            end
        end

        function obj = applyOptions(obj, options)
            names = fieldnames(options);
            for index = 1:numel(names)
                obj = obj.setOption(names{index}, options.(names{index}));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin), 2) ~= 0
                error('BifurcationRefiner_v3:NameValue', ...
                    'Options must be supplied as name/value pairs.');
            end
            for index = 1:2:numel(varargin)
                obj = obj.setOption(varargin{index}, varargin{index + 1});
            end
        end

        function obj = setOption(obj, name, value)
            names = properties(obj);
            match = find(strcmpi(char(name), names), 1);
            if isempty(match)
                error('BifurcationRefiner_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(names{match}) = value;
        end

        function validateParameterIndex(obj, p)
            if obj.ActiveParameterIndex < 1 || ...
                    obj.ActiveParameterIndex > numel(p) || ...
                    obj.ActiveParameterIndex ~= floor(obj.ActiveParameterIndex)
                error('BifurcationRefiner_v3:ActiveParameterIndex', ...
                    'ActiveParameterIndex is outside the supplied parameter vector.');
            end
        end

        function validateOptions(obj)
            positive = [obj.DifferenceStep, obj.SecondDifferenceStep, ...
                obj.FunctionTolerance, obj.StepTolerance, ...
                obj.ResidualAcceptanceTolerance, obj.SingularValueTolerance, ...
                obj.MultiplierTolerance, obj.NondegeneracyTolerance, ...
                obj.CandidateMultiplierTolerance, ...
                obj.ImaginaryTolerance];
            if any(~isfinite(positive)) || any(positive <= 0) || ...
                    obj.MaxIterations < 1 || obj.MaxFunctionEvaluations < 1
                error('BifurcationRefiner_v3:Options', ...
                    'Tolerances and iteration limits must be positive.');
            end
            logicalOptions = [obj.RequireReliable, ...
                obj.RequireCompatibleTopology, obj.AssumeSmoothCallbacks];
            if any(~ismember(logicalOptions, [false, true]))
                error('BifurcationRefiner_v3:Options', ...
                    'Logical refinement options must be scalar logical values.');
            end
        end
    end
end
