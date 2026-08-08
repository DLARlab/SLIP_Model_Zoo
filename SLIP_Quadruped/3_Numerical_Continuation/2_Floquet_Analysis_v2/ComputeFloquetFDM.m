function [M, multipliers, eigenvectors, diagnostics] = ...
    ComputeFloquetFDM(solution, parameters, options)
%COMPUTEFLOQUETFDM Differentiate the reduced apex Poincare return map.
%
%   [M,LAMBDA,V,DIAGNOSTICS] = COMPUTEFLOQUETFDM(SOLUTION22,PARA7,OPTIONS)
%   computes
%
%       M(:,i) = (P(q+h_i e_i) - P(q-h_i e_i))/(2 h_i)
%
%   on q=X([1 2 4:13]).  X(3)=dy is held fixed by the apex section and
%   horizontal position is absent from X by translational reduction.  Each
%   perturbed call uses the production timing solver; event times are never
%   finite-difference coordinates.
%
%   The calculation is explicitly rejected (M=[], LAMBDA=[], V=[]) when
%   the base orbit, any perturbed map, derivative refinement, or
%   forward/backward consistency check fails under the configured policy.

    if nargin < 3
        options = struct();
    end
    options = ResolveFloquetOptions(options);
    requestedErrorMode = options.ErrorOnFailure;
    options.ErrorOnFailure = false;

    M = [];
    multipliers = [];
    eigenvectors = [];
    diagnostics = InitialDiagnostics(options);

    baseReport = ValidatePeriodicOrbit(solution, parameters, options);
    diagnostics.baseValidation = baseReport;
    if ~baseReport.accepted
        diagnostics.rejectionReasons = PrefixReasons( ...
            baseReport.rejectionReasons, 'Base orbit: ');
        diagnostics = FinishDiagnostics(diagnostics, requestedErrorMode);
        return;
    end

    solution = solution(:);
    Xstar = solution(1:13);
    qstar = baseReport.initialSectionState;
    qBaseReturn = baseReport.sectionStateReturn;
    solvedEventTimes = baseReport.mapInfo.solvedEventTimes;
    referenceTopology = baseReport.mapInfo.eventTopology;

    diagnostics.baseState = Xstar;
    diagnostics.baseSectionState = qstar;
    diagnostics.baseMapValue = qBaseReturn;
    diagnostics.baseSolvedEventTimes = solvedEventTimes;
    diagnostics.referenceTopology = referenceTopology;

    [steps, stepInfo] = ScalePerturbation( ...
        qstar, options.PerturbationMagnitudes, options);
    diagnostics.perturbationSteps = steps;
    diagnostics.perturbationScaling = stepInfo;
    diagnostics.perturbationMagnitudes = options.PerturbationMagnitudes;
    actualStepRatios = steps(:,1:end-1) ./ steps(:,2:end);
    diagnostics.actualPerturbationStepRatios = actualStepRatios;
    if any(~isfinite(actualStepRatios(:))) || any(actualStepRatios(:) <= 1)
        diagnostics.rejectionReasons{end+1} = [ ...
            'Scaled perturbation levels are not strictly decreasing. ' ...
            'At least two requested levels collapsed to the same actual ' ...
            'step, so derivative convergence cannot be tested.'];
        diagnostics = FinishDiagnostics(diagnostics, requestedErrorMode);
        return;
    end

    stateDimension = numel(qstar);
    levelCount = size(steps,2);
    plusValues = NaN(stateDimension, stateDimension, levelCount);
    minusValues = NaN(stateDimension, stateDimension, levelCount);
    plusInfo = cell(stateDimension, levelCount);
    minusInfo = cell(stateDimension, levelCount);
    mapAccepted = false(stateDimension, levelCount, 2);

    mapOptions = options;
    mapOptions.ReferenceTopology = referenceTopology;
    stopRequested = false;

    for level = 1:levelCount
        for coordinate = 1:stateDimension
            h = steps(coordinate, level);
            [Xplus, plusPerturbation] = ApplySectionPerturbation( ...
                Xstar, coordinate, h);
            [Xminus, minusPerturbation] = ApplySectionPerturbation( ...
                Xstar, coordinate, -h);

            [qPlus, plusMap] = BuildPoincareMap( ...
                Xplus, solvedEventTimes, parameters, mapOptions);
            [qMinus, minusMap] = BuildPoincareMap( ...
                Xminus, solvedEventTimes, parameters, mapOptions);

            plusMap.appliedPerturbation = plusPerturbation;
            minusMap.appliedPerturbation = minusPerturbation;
            plusInfo{coordinate,level} = plusMap;
            minusInfo{coordinate,level} = minusMap;
            mapAccepted(coordinate,level,1) = plusMap.accepted;
            mapAccepted(coordinate,level,2) = minusMap.accepted;

            if plusMap.accepted
                plusValues(:,coordinate,level) = qPlus;
            else
                diagnostics.rejectionReasons = [diagnostics.rejectionReasons, ...
                    PrefixReasons(plusMap.rejectionReasons, sprintf( ...
                    'FD level %d coordinate %d (+): ', level, coordinate))];
            end
            if minusMap.accepted
                minusValues(:,coordinate,level) = qMinus;
            else
                diagnostics.rejectionReasons = [diagnostics.rejectionReasons, ...
                    PrefixReasons(minusMap.rejectionReasons, sprintf( ...
                    'FD level %d coordinate %d (-): ', level, coordinate))];
            end

            if (~plusMap.accepted || ~minusMap.accepted) && ...
                    options.StopOnFirstFailure
                stopRequested = true;
                break;
            end
        end
        if stopRequested
            break;
        end
    end

    diagnostics.mapDiagnostics = struct('plus', {plusInfo}, 'minus', {minusInfo});
    diagnostics.mapAccepted = mapAccepted;
    diagnostics.successfulPerturbedMapCount = nnz(mapAccepted);
    diagnostics.requestedPerturbedMapCount = 2 * stateDimension * levelCount;
    diagnostics.allPerturbedMapsAccepted = all(mapAccepted(:));

    if ~diagnostics.allPerturbedMapsAccepted
        if stopRequested
            diagnostics.rejectionReasons{end+1} = ...
                'Finite differencing stopped after the first rejected perturbed map.';
        end
        diagnostics = FinishDiagnostics(diagnostics, requestedErrorMode);
        return;
    end

    forward = NaN(stateDimension, stateDimension, levelCount);
    backward = NaN(stateDimension, stateDimension, levelCount);
    central = NaN(stateDimension, stateDimension, levelCount);
    forwardBackwardAbsolute = NaN(stateDimension, levelCount);
    forwardBackwardRelative = NaN(stateDimension, levelCount);
    centralSymmetryDefect = NaN(stateDimension, levelCount);

    for level = 1:levelCount
        for coordinate = 1:stateDimension
            h = steps(coordinate,level);
            forward(:,coordinate,level) = ...
                (plusValues(:,coordinate,level) - qBaseReturn) ./ h;
            backward(:,coordinate,level) = ...
                (qBaseReturn - minusValues(:,coordinate,level)) ./ h;
            central(:,coordinate,level) = ...
                (plusValues(:,coordinate,level) - ...
                 minusValues(:,coordinate,level)) ./ (2*h);

            difference = forward(:,coordinate,level) - ...
                backward(:,coordinate,level);
            forwardBackwardAbsolute(coordinate,level) = norm(difference,2);
            derivativeScale = 1 + norm(central(:,coordinate,level),2);
            forwardBackwardRelative(coordinate,level) = ...
                forwardBackwardAbsolute(coordinate,level) ./ derivativeScale;
            centralSymmetryDefect(coordinate,level) = norm( ...
                plusValues(:,coordinate,level) + ...
                minusValues(:,coordinate,level) - 2*qBaseReturn, 2) ./ ...
                (1 + norm(qBaseReturn,2));
        end
    end

    convergence = DerivativeConvergence(central, steps, options);
    diagnostics.mapValues = struct('plus', plusValues, 'minus', minusValues);
    diagnostics.forwardDerivativeMatrices = forward;
    diagnostics.backwardDerivativeMatrices = backward;
    diagnostics.centralDerivativeMatrices = central;
    diagnostics.forwardBackwardAbsoluteError = forwardBackwardAbsolute;
    diagnostics.forwardBackwardRelativeError = forwardBackwardRelative;
    diagnostics.centralSymmetryDefect = centralSymmetryDefect;
    diagnostics.derivativeConvergence = convergence;
    diagnostics.derivativeConverged = convergence.converged;
    diagnostics.finestForwardBackwardError = ...
        forwardBackwardRelative(:,end);
    diagnostics.maximumFinestForwardBackwardError = ...
        max(forwardBackwardRelative(:,end));
    diagnostics.forwardBackwardConsistent = ...
        diagnostics.maximumFinestForwardBackwardError <= ...
        options.ForwardBackwardTolerance;

    if options.RejectOnDerivativeNonconvergence && ...
            ~diagnostics.derivativeConverged
        diagnostics.rejectionReasons{end+1} = sprintf( ...
            ['Central derivative did not converge across perturbation levels: ' ...
             'finest relative change %.3e exceeds %.3e.'], ...
            convergence.finestRelativeError, ...
            options.DerivativeConvergenceTolerance);
    end
    if options.RejectOnForwardBackwardMismatch && ...
            ~diagnostics.forwardBackwardConsistent
        diagnostics.rejectionReasons{end+1} = sprintf( ...
            ['Forward/backward derivatives are inconsistent: finest maximum ' ...
             'relative mismatch %.3e exceeds %.3e.'], ...
            diagnostics.maximumFinestForwardBackwardError, ...
            options.ForwardBackwardTolerance);
    end

    selectedLevel = levelCount;
    candidateMatrix = central(:,:,selectedLevel);
    diagnostics.selectedPerturbationLevel = selectedLevel;
    diagnostics.selectedPerturbationMagnitude = ...
        options.PerturbationMagnitudes(selectedLevel);
    diagnostics.selectedMatrix = candidateMatrix;

    if any(~isfinite(candidateMatrix(:)))
        diagnostics.rejectionReasons{end+1} = ...
            'The selected central-difference matrix contains nonfinite entries.';
    end

    if isempty(diagnostics.rejectionReasons)
        [candidateVectors, candidateValues] = eig(candidateMatrix);
        candidateMultipliers = diag(candidateValues);
        if any(~isfinite(real(candidateMultipliers))) || ...
                any(~isfinite(imag(candidateMultipliers))) || ...
                any(~isfinite(real(candidateVectors(:)))) || ...
                any(~isfinite(imag(candidateVectors(:))))
            diagnostics.rejectionReasons{end+1} = ...
                'Eigenvalue decomposition returned nonfinite values.';
        else
            M = candidateMatrix;
            multipliers = candidateMultipliers;
            eigenvectors = candidateVectors;
            diagnostics.multipliers = multipliers;
            diagnostics.eigenvectors = eigenvectors;
            basis = zeros(13,12);
            basis(options.ReducedStateIndices,:) = eye(12);
            diagnostics.sectionEmbedding = basis;
            diagnostics.fullStateEigenvectors = basis * eigenvectors;
        end
    end

    diagnostics = FinishDiagnostics(diagnostics, requestedErrorMode);
    if ~diagnostics.accepted
        M = [];
        multipliers = [];
        eigenvectors = [];
    end
end

function diagnostics = InitialDiagnostics(options)
    diagnostics = struct();
    diagnostics.accepted = false;
    diagnostics.valid = false;
    diagnostics.status = 'not-evaluated';
    diagnostics.rejectionReasons = {};
    diagnostics.method = 'scaled multi-level central finite difference';
    diagnostics.mapDefinition = 'reduced apex-to-apex Poincare return map';
    diagnostics.reducedStateIndices = options.ReducedStateIndices(:);
    diagnostics.excludedStateCoordinates = struct( ...
        'translation', 'integrated Y(1)=x (not present in X)', ...
        'sectionNormal', 'X(3)=dy');
    diagnostics.options = options;
end

function convergence = DerivativeConvergence(central, steps, options)
    levelCount = size(central,3);
    dimension = size(central,2);
    absoluteErrors = NaN(levelCount-1,1);
    relativeErrors = NaN(levelCount-1,1);
    columnAbsoluteErrors = NaN(dimension,levelCount-1);
    columnRelativeErrors = NaN(dimension,levelCount-1);

    for level = 2:levelCount
        difference = central(:,:,level) - central(:,:,level-1);
        absoluteErrors(level-1) = norm(difference,'fro');
        relativeErrors(level-1) = absoluteErrors(level-1) ./ ...
            (1 + norm(central(:,:,level),'fro'));
        for coordinate = 1:dimension
            columnAbsoluteErrors(coordinate,level-1) = ...
                norm(difference(:,coordinate),2);
            columnRelativeErrors(coordinate,level-1) = ...
                columnAbsoluteErrors(coordinate,level-1) ./ ...
                (1 + norm(central(:,coordinate,level),2));
        end
    end

    fine = levelCount;
    coarse = levelCount - 1;
    richardsonEstimate = NaN(size(central,1), dimension);
    richardsonRatio = NaN(dimension,1);
    for coordinate = 1:dimension
        ratio = steps(coordinate,coarse) / steps(coordinate,fine);
        richardsonRatio(coordinate) = ratio;
        if isfinite(ratio) && ratio > 1
            richardsonEstimate(:,coordinate) = abs( ...
                central(:,coordinate,fine) - central(:,coordinate,coarse)) ./ ...
                (ratio^2 - 1);
        end
    end

    observedOrder = NaN(dimension,1);
    if levelCount >= 3
        for coordinate = 1:dimension
            eCoarse = columnAbsoluteErrors(coordinate,end-1);
            eFine = columnAbsoluteErrors(coordinate,end);
            ratio1 = steps(coordinate,end-2) / steps(coordinate,end-1);
            ratio2 = steps(coordinate,end-1) / steps(coordinate,end);
            effectiveRatio = sqrt(ratio1 * ratio2);
            if eCoarse > 0 && eFine > 0 && isfinite(effectiveRatio) && ...
                    effectiveRatio > 1
                observedOrder(coordinate) = log(eCoarse/eFine) / ...
                    log(effectiveRatio);
            end
        end
    end

    convergence = struct();
    convergence.absoluteMatrixError = absoluteErrors;
    convergence.relativeMatrixError = relativeErrors;
    convergence.columnAbsoluteError = columnAbsoluteErrors;
    convergence.columnRelativeError = columnRelativeErrors;
    convergence.finestAbsoluteError = absoluteErrors(end);
    convergence.finestRelativeError = relativeErrors(end);
    convergence.finestColumnRelativeError = columnRelativeErrors(:,end);
    convergence.richardsonStepRatio = richardsonRatio;
    convergence.richardsonAbsoluteErrorEstimate = richardsonEstimate;
    convergence.richardsonFrobeniusErrorEstimate = ...
        norm(richardsonEstimate,'fro');
    convergence.observedCentralDifferenceOrder = observedOrder;
    convergence.tolerance = options.DerivativeConvergenceTolerance;
    convergence.converged = isfinite(convergence.finestRelativeError) && ...
        convergence.finestRelativeError <= options.DerivativeConvergenceTolerance && ...
        all(isfinite(convergence.finestColumnRelativeError)) && ...
        all(convergence.finestColumnRelativeError <= ...
            options.DerivativeConvergenceTolerance);
end

function diagnostics = FinishDiagnostics(diagnostics, errorOnFailure)
    diagnostics.accepted = isempty(diagnostics.rejectionReasons);
    diagnostics.valid = diagnostics.accepted;
    if diagnostics.accepted
        diagnostics.status = 'accepted';
    else
        diagnostics.status = 'rejected';
    end
    if ~diagnostics.accepted && errorOnFailure
        error('ComputeFloquetFDM:Rejected', '%s', ...
            strjoin(diagnostics.rejectionReasons, ' | '));
    end
end

function prefixed = PrefixReasons(reasons, prefix)
    prefixed = cell(size(reasons));
    for i = 1:numel(reasons)
        prefixed{i} = [prefix, reasons{i}];
    end
end
