function [directions, diagnostics] = ...
    ResolvePronkingCriticalSubspace(refinementDiagnostics, options)
%RESOLVEPRONKINGCRITICALSUBSPACE Resolve the multiple +1 pronking kernel.
%
%   [DIRECTIONS,DIAGNOSTICS] = RESOLVEPRONKINGCRITICALSUBSPACE(REFINEMENT)
%   consumes the diagnostics returned by an accepted RefineCriticalOrbit
%   calculation at the multiple pronking +1 crossing.  The routine:
%
%     1. certifies the numerical nullity of M-I;
%     2. removes the local continuation-branch tangent in the scaled state
%        metric used by the Floquet/branch-prediction diagnostics;
%     3. checks equivariance of M under independent hind- and front-leg
%        label swaps; and
%     4. resolves the three-dimensional additional kernel into bounding,
%        front-spread, and hind-spread symmetry coordinates.
%
%   The reduced apex state is fixed to
%
%       q = [dx,y,phi,dphi,aBL,daBL,aFL,daFL,...
%            aBR,daBR,aFR,daFR].'
%
%   Let RH exchange the BL/BR coordinate pairs and RF exchange FL/FR.
%   The four Z2-by-Z2 projectors are
%
%       P++ = (I+RH)(I+RF)/4,  P+- = (I+RH)(I-RF)/4,
%       P-+ = (I-RH)(I+RF)/4,  P-- = (I-RH)(I-RF)/4.
%
%   For the pronking bifurcation treated here, ker(M-I) must have symmetry
%   ranks [2 1 1 0]: the even-even sector contains the parent tangent and
%   bounding direction, while the other two nonempty sectors contain the
%   front-spread and hind-spread directions.  Removing the parent tangent
%   must therefore leave ranks [1 1 1 0].
%
%   DIRECTIONS is empty when a numerical certificate fails.  On success it
%   contains weighted-unit vectors in fields Bounding, FrontSpread, and
%   HindSpread, as well as Matrix = [Bounding FrontSpread HindSpread].
%   Their signs are deterministic but not physical: both +/- orientations
%   must be tested by a nonlinear branch corrector.
%
%   OPTIONS is an optional scalar struct with fields:
%       ExpectedNullity                 default 4
%       NullityTolerance                default refinement SVD tolerance
%       StateScale                      default diagnostic/reconstructed scale
%       MatrixUncertainty               default Richardson Frobenius estimate
%       CommutatorUncertaintyFactor     default 5
%       MinimumTangentNullProjection    default 0.99
%       SectorRankTolerance             default 1e-3
%       ScaleSymmetryTolerance          default 1e-6
%       SymmetryResidualTolerance       default uncertainty-derived
%       DirectionEigenResidualTolerance default refinement-derived
%       ThrowOnFailure                  default false
%
%   This utility does not modify the hybrid dynamics or event-time solver.
%   It assumes the refined base orbit is pronking and hence is invariant
%   under the two independent leg-label swaps defined above.

    if nargin < 2
        options = struct();
    end
    options = ParseOptions(options);
    ValidateRefinementDiagnostics(refinementDiagnostics);

    directions = EmptyDirections();
    diagnostics = InitialDiagnostics(options);

    M = ValidateRealMatrix(refinementDiagnostics.floquetMatrix, ...
        'floquetMatrix');
    tangent = ValidateRealVector( ...
        refinementDiagnostics.localBranchTangent, 12, ...
        'localBranchTangent');
    if norm(tangent) == 0
        error('ResolvePronkingCriticalSubspace:ZeroTangent', ...
            'localBranchTangent must be nonzero.');
    end

    [stateScale, scaleSource] = ResolveStateScale( ...
        refinementDiagnostics, options.StateScale);
    [matrixUncertainty, uncertaintySource] = ResolveMatrixUncertainty( ...
        refinementDiagnostics, options.MatrixUncertainty);
    [nullityTolerance, nullityToleranceSource] = ...
        ResolveNullityTolerance(refinementDiagnostics, ...
            options.NullityTolerance, M, matrixUncertainty);

    diagnostics.reducedStateOrdering = { ...
        'dx','y','phi','dphi','aBL','daBL','aFL','daFL', ...
        'aBR','daBR','aFR','daFR'};
    diagnostics.floquetMatrix = M;
    diagnostics.stateScale = stateScale;
    diagnostics.stateScaleSource = scaleSource;
    diagnostics.matrixUncertainty = matrixUncertainty;
    diagnostics.matrixUncertaintySource = uncertaintySource;
    diagnostics.nullityTolerance = nullityTolerance;
    diagnostics.nullityToleranceSource = nullityToleranceSource;

    A = M - eye(12);
    [~, singularMatrix, rightVectors] = svd(A, 'econ');
    singularValues = diag(singularMatrix);
    nullMask = singularValues <= nullityTolerance;
    nullBasis = rightVectors(:, nullMask);
    numericalNullity = size(nullBasis, 2);

    diagnostics.singularValuesMminusI = singularValues;
    diagnostics.numericalNullity = numericalNullity;
    diagnostics.expectedNullity = options.ExpectedNullity;
    diagnostics.rawNullBasis = nullBasis;
    if numericalNullity ~= options.ExpectedNullity
        diagnostics.rejectionReasons{end + 1} = sprintf( ...
            ['M-I has numerical nullity %d at tolerance %.3e; the pronking ' ...
             'multiple crossing requires nullity %d.'], ...
            numericalNullity, nullityTolerance, options.ExpectedNullity);
        [directions, diagnostics] = Finish( ...
            directions, diagnostics, options);
        return
    end

    scaledNullBasis = OrthonormalColumns(nullBasis ./ stateScale);
    physicalNullBasis = stateScale .* scaledNullBasis;
    scaledTangent = tangent ./ stateScale;
    scaledTangent = scaledTangent / norm(scaledTangent);
    tangentCoordinates = scaledNullBasis' * scaledTangent;
    tangentProjection = norm(tangentCoordinates);
    diagnostics.scaledNullBasis = scaledNullBasis;
    diagnostics.weightedOrthonormalNullBasis = physicalNullBasis;
    diagnostics.scaledTangent = scaledTangent;
    diagnostics.scaledTangentNullProjection = tangentProjection;
    if tangentProjection < options.MinimumTangentNullProjection
        diagnostics.rejectionReasons{end + 1} = sprintf( ...
            ['The scaled parent tangent projects only %.8f into ker(M-I); ' ...
             'the required minimum is %.8f.'], ...
            tangentProjection, options.MinimumTangentNullProjection);
        [directions, diagnostics] = Finish( ...
            directions, diagnostics, options);
        return
    end

    % Use the projected tangent coordinates so small errors in a branch
    % secant cannot contaminate the additional critical complement.
    tangentCoordinates = tangentCoordinates / norm(tangentCoordinates);
    complementCoefficients = null(tangentCoordinates.');
    scaledAdditionalBasis = scaledNullBasis * complementCoefficients;
    scaledAdditionalBasis = OrthonormalColumns(scaledAdditionalBasis);
    physicalAdditionalBasis = stateScale .* scaledAdditionalBasis;
    additionalDimension = size(physicalAdditionalBasis, 2);
    diagnostics.additionalDimension = additionalDimension;
    diagnostics.expectedAdditionalDimension = options.ExpectedNullity - 1;
    diagnostics.scaledAdditionalBasis = scaledAdditionalBasis;
    diagnostics.additionalCriticalSubspace = physicalAdditionalBasis;
    diagnostics.maximumScaledTangentOverlap = max(abs( ...
        scaledTangent' * scaledAdditionalBasis));
    if additionalDimension ~= options.ExpectedNullity - 1
        diagnostics.rejectionReasons{end + 1} = sprintf( ...
            ['Removing the parent tangent leaves dimension %d, expected ' ...
             '%d for the pronking branch point.'], ...
            additionalDimension, options.ExpectedNullity - 1);
        [directions, diagnostics] = Finish( ...
            directions, diagnostics, options);
        return
    end

    [RH, RF, projectors] = PronkingSymmetryOperators();
    diagnostics.hindSwapMatrix = RH;
    diagnostics.frontSwapMatrix = RF;
    diagnostics.projectors = projectors;
    diagnostics.swapChecks = SwapAlgebraChecks(RH, RF, projectors);

    scaleSymmetryResiduals = [ ...
        norm(RH * stateScale - stateScale, inf), ...
        norm(RF * stateScale - stateScale, inf)] / ...
        max(1, norm(stateScale, inf));
    diagnostics.scaleSymmetryResiduals = scaleSymmetryResiduals;
    diagnostics.scaleSymmetryTolerance = options.ScaleSymmetryTolerance;
    if any(scaleSymmetryResiduals > options.ScaleSymmetryTolerance)
        diagnostics.rejectionReasons{end + 1} = sprintf( ...
            ['The diagnostic state scale is not leg-swap invariant ' ...
             '(hind %.3e, front %.3e; tolerance %.3e).'], ...
            scaleSymmetryResiduals(1), scaleSymmetryResiduals(2), ...
            options.ScaleSymmetryTolerance);
    end

    commutatorH = M * RH - RH * M;
    commutatorF = M * RF - RF * M;
    commutatorNorms = [norm(commutatorH, 'fro'), ...
        norm(commutatorF, 'fro')];
    commutatorRelative = commutatorNorms / max(1, norm(M, 'fro'));
    roundingFloor = 100 * eps(class(M)) * max(1, norm(M, 'fro'));
    commutatorTolerance = max(roundingFloor, ...
        2 * options.CommutatorUncertaintyFactor * matrixUncertainty);
    diagnostics.commutatorHind = commutatorH;
    diagnostics.commutatorFront = commutatorF;
    diagnostics.commutatorFrobeniusNorms = commutatorNorms;
    diagnostics.relativeCommutatorNorms = commutatorRelative;
    diagnostics.commutatorTolerance = commutatorTolerance;
    diagnostics.commutatorUncertaintyFactor = ...
        options.CommutatorUncertaintyFactor;
    diagnostics.commutatorAccepted = ...
        all(commutatorNorms <= commutatorTolerance);
    if ~diagnostics.commutatorAccepted
        diagnostics.rejectionReasons{end + 1} = sprintf( ...
            ['Floquet equivariance is not resolved within the FD uncertainty: ' ...
             '||[M,RH]||_F=%.3e and ||[M,RF]||_F=%.3e, versus %.3e.'], ...
            commutatorNorms(1), commutatorNorms(2), ...
            commutatorTolerance);
    end

    if isempty(options.SymmetryResidualTolerance)
        symmetryTolerance = max([10 * options.SectorRankTolerance, ...
            2 * commutatorTolerance / max(1, norm(M, 'fro')), ...
            options.ScaleSymmetryTolerance]);
    else
        symmetryTolerance = options.SymmetryResidualTolerance;
    end
    tangentHindResidual = norm(RH * tangent - tangent) / norm(tangent);
    tangentFrontResidual = norm(RF * tangent - tangent) / norm(tangent);
    diagnostics.tangentSwapResiduals = [ ...
        tangentHindResidual, tangentFrontResidual];
    diagnostics.symmetryResidualTolerance = symmetryTolerance;
    if max(tangentHindResidual, tangentFrontResidual) > symmetryTolerance
        diagnostics.rejectionReasons{end + 1} = sprintf( ...
            ['The pronking parent tangent is not even under both swaps ' ...
             '(hind %.3e, front %.3e; tolerance %.3e).'], ...
            tangentHindResidual, tangentFrontResidual, symmetryTolerance);
    end

    sectorNames = {'EvenEven','HindEvenFrontOdd', ...
        'HindOddFrontEven','OddOdd'};
    sectorSigns = [1 1; 1 -1; -1 1; -1 -1];
    fullSector = repmat(EmptySector(), 1, 4);
    additionalSector = repmat(EmptySector(), 1, 4);
    projectorValues = {projectors.EvenEven, ...
        projectors.HindEvenFrontOdd, ...
        projectors.HindOddFrontEven, projectors.OddOdd};
    for sectorIndex = 1:4
        fullSector(sectorIndex) = ResolveSector( ...
            projectorValues{sectorIndex}, scaledNullBasis, ...
            physicalNullBasis, stateScale, options.SectorRankTolerance);
        additionalSector(sectorIndex) = ResolveSector( ...
            projectorValues{sectorIndex}, scaledAdditionalBasis, ...
            physicalAdditionalBasis, stateScale, ...
            options.SectorRankTolerance);
        fullSector(sectorIndex).name = sectorNames{sectorIndex};
        additionalSector(sectorIndex).name = sectorNames{sectorIndex};
        fullSector(sectorIndex).swapSigns = sectorSigns(sectorIndex, :);
        additionalSector(sectorIndex).swapSigns = sectorSigns(sectorIndex, :);
    end

    fullRanks = [fullSector.rank];
    additionalRanks = [additionalSector.rank];
    expectedFullRanks = [2 1 1 0];
    expectedAdditionalRanks = [1 1 1 0];
    diagnostics.fullSectorDiagnostics = fullSector;
    diagnostics.additionalSectorDiagnostics = additionalSector;
    diagnostics.fullSectorRanks = fullRanks;
    diagnostics.expectedFullSectorRanks = expectedFullRanks;
    diagnostics.additionalSectorRanks = additionalRanks;
    diagnostics.expectedAdditionalSectorRanks = expectedAdditionalRanks;
    diagnostics.sectorRankTolerance = options.SectorRankTolerance;
    if ~isequal(fullRanks, expectedFullRanks)
        diagnostics.rejectionReasons{end + 1} = sprintf( ...
            ['The full +1 kernel has symmetry ranks [%s], expected ' ...
             '[2 1 1 0].'], IntegerRow(fullRanks));
    end
    if ~isequal(additionalRanks, expectedAdditionalRanks)
        diagnostics.rejectionReasons{end + 1} = sprintf( ...
            ['The tangent-free +1 kernel has symmetry ranks [%s], expected ' ...
             '[1 1 1 0].'], IntegerRow(additionalRanks));
    end

    if ~isempty(diagnostics.rejectionReasons)
        [directions, diagnostics] = Finish( ...
            directions, diagnostics, options);
        return
    end

    bounding = additionalSector(1).basis(:, 1);
    frontSpread = additionalSector(2).basis(:, 1);
    hindSpread = additionalSector(3).basis(:, 1);
    bounding = OrientVector(bounding, stateScale, []);
    frontSpread = OrientVector(frontSpread, stateScale, [7 11]);
    hindSpread = OrientVector(hindSpread, stateScale, [5 9]);

    if isempty(options.DirectionEigenResidualTolerance)
        readinessTolerance = NestedScalar(refinementDiagnostics, ...
            {'branchSwitchReadinessDiagnostics', ...
             'tangentEigenResidualTolerance'}, NaN);
        uncertaintyTolerance = 5 * max(nullityTolerance, ...
            matrixUncertainty) / (1 + norm(M, 2));
        directionEigenTolerance = max(uncertaintyTolerance, ...
            FiniteNonnegativeOr(readinessTolerance, 0));
    else
        directionEigenTolerance = options.DirectionEigenResidualTolerance;
    end
    directionValues = {bounding, frontSpread, hindSpread};
    directionNames = {'Bounding','FrontSpread','HindSpread'};
    directionSigns = [1 1; 1 -1; -1 1];
    directionDiagnostics = repmat(EmptyDirectionDiagnostics(), 1, 3);
    for directionIndex = 1:3
        directionDiagnostics(directionIndex) = CheckDirection( ...
            directionNames{directionIndex}, ...
            directionValues{directionIndex}, directionSigns(directionIndex,:), ...
            A, M, tangent, stateScale, RH, RF, ...
            directionEigenTolerance, symmetryTolerance);
        if ~directionDiagnostics(directionIndex).accepted
            diagnostics.rejectionReasons = [diagnostics.rejectionReasons, ...
                directionDiagnostics(directionIndex).rejectionReasons];
        end
    end

    diagnostics.directionEigenResidualTolerance = ...
        directionEigenTolerance;
    diagnostics.directionDiagnostics = directionDiagnostics;
    diagnostics.orientationConvention = [ ...
        'Bounding: largest scaled entry positive; front spread: ' ...
        'aFL-aFR positive; hind spread: aBL-aBR positive.'];

    if isempty(diagnostics.rejectionReasons)
        directions.Bounding = bounding;
        directions.FrontSpread = frontSpread;
        directions.HindSpread = hindSpread;
        directions.Matrix = [bounding, frontSpread, hindSpread];
        directions.StateScale = stateScale;
        directions.ReducedStateOrdering = diagnostics.reducedStateOrdering;
        directions.Normalization = 'norm(direction./StateScale,2) = 1';
        directions.OrientationConvention = diagnostics.orientationConvention;
        directions.BoundingEigenData = MakeEigenData( ...
            bounding, tangent, stateScale, refinementDiagnostics, ...
            'bounding');
        directions.FrontSpreadEigenData = MakeEigenData( ...
            frontSpread, tangent, stateScale, refinementDiagnostics, ...
            'front-spread-half-bound');
        directions.HindSpreadEigenData = MakeEigenData( ...
            hindSpread, tangent, stateScale, refinementDiagnostics, ...
            'hind-spread-half-bound');
    end

    [directions, diagnostics] = Finish(directions, diagnostics, options);
end

function options = ParseOptions(userOptions)
    if isempty(userOptions)
        userOptions = struct();
    end
    if ~isstruct(userOptions) || ~isscalar(userOptions)
        error('ResolvePronkingCriticalSubspace:InvalidOptions', ...
            'options must be a scalar struct.');
    end
    defaults = struct();
    defaults.ExpectedNullity = 4;
    defaults.NullityTolerance = [];
    defaults.StateScale = [];
    defaults.MatrixUncertainty = [];
    defaults.CommutatorUncertaintyFactor = 5;
    defaults.MinimumTangentNullProjection = 0.99;
    defaults.SectorRankTolerance = 1e-3;
    defaults.ScaleSymmetryTolerance = 1e-6;
    defaults.SymmetryResidualTolerance = [];
    defaults.DirectionEigenResidualTolerance = [];
    defaults.ThrowOnFailure = false;

    supplied = fieldnames(userOptions);
    known = fieldnames(defaults);
    options = defaults;
    for index = 1:numel(supplied)
        match = find(strcmpi(supplied{index}, known), 1);
        if isempty(match)
            error('ResolvePronkingCriticalSubspace:UnknownOption', ...
                'Unknown option ''%s''.', supplied{index});
        end
        options.(known{match}) = userOptions.(supplied{index});
    end

    ValidatePositiveInteger(options.ExpectedNullity, 'ExpectedNullity');
    if options.ExpectedNullity ~= 4
        error('ResolvePronkingCriticalSubspace:ExpectedNullity', ...
            ['This pronking resolver requires ExpectedNullity=4 ' ...
             '(one parent tangent plus three additional directions).']);
    end
    ValidateOptionalPositiveScalar(options.NullityTolerance, ...
        'NullityTolerance');
    ValidateOptionalPositiveVector(options.StateScale, 'StateScale', 12);
    ValidateOptionalNonnegativeScalar(options.MatrixUncertainty, ...
        'MatrixUncertainty');
    ValidatePositiveScalar(options.CommutatorUncertaintyFactor, ...
        'CommutatorUncertaintyFactor');
    ValidateUnitInterval(options.MinimumTangentNullProjection, ...
        'MinimumTangentNullProjection');
    ValidatePositiveScalar(options.SectorRankTolerance, ...
        'SectorRankTolerance');
    ValidateNonnegativeScalar(options.ScaleSymmetryTolerance, ...
        'ScaleSymmetryTolerance');
    ValidateOptionalNonnegativeScalar(options.SymmetryResidualTolerance, ...
        'SymmetryResidualTolerance');
    ValidateOptionalNonnegativeScalar( ...
        options.DirectionEigenResidualTolerance, ...
        'DirectionEigenResidualTolerance');
    if ~(islogical(options.ThrowOnFailure) && isscalar(options.ThrowOnFailure)) && ...
            ~(isnumeric(options.ThrowOnFailure) && ...
              isscalar(options.ThrowOnFailure) && ...
              isfinite(options.ThrowOnFailure) && ...
              any(options.ThrowOnFailure == [0 1]))
        error('ResolvePronkingCriticalSubspace:InvalidThrowOnFailure', ...
            'ThrowOnFailure must be a scalar logical value.');
    end
    options.ThrowOnFailure = logical(options.ThrowOnFailure);
end

function ValidateRefinementDiagnostics(value)
    if ~isstruct(value) || ~isscalar(value)
        error('ResolvePronkingCriticalSubspace:InvalidDiagnostics', ...
            'refinementDiagnostics must be a scalar struct.');
    end
    accepted = isfield(value, 'accepted') && isscalar(value.accepted) && ...
        ((islogical(value.accepted) && value.accepted) || ...
         (isnumeric(value.accepted) && isreal(value.accepted) && ...
          isfinite(value.accepted) && value.accepted == 1));
    if ~accepted
        error('ResolvePronkingCriticalSubspace:UnacceptedRefinement', ...
            ['refinementDiagnostics must come from an accepted ' ...
             'RefineCriticalOrbit calculation.']);
    end
    required = {'floquetMatrix','localBranchTangent'};
    for index = 1:numel(required)
        if ~isfield(value, required{index}) || isempty(value.(required{index}))
            error('ResolvePronkingCriticalSubspace:MissingField', ...
                'refinementDiagnostics.%s is required.', required{index});
        end
    end
end

function M = ValidateRealMatrix(value, name)
    if ~isnumeric(value) || ~isequal(size(value), [12 12]) || ...
            any(~isfinite(real(value(:)))) || ...
            any(~isfinite(imag(value(:))))
        error('ResolvePronkingCriticalSubspace:InvalidMatrix', ...
            '%s must be a finite numeric 12-by-12 matrix.', name);
    end
    imaginaryRatio = norm(imag(value), 'fro') / ...
        max(1, norm(real(value), 'fro'));
    if imaginaryRatio > 1e-12
        error('ResolvePronkingCriticalSubspace:ComplexMatrix', ...
            '%s has relative imaginary norm %.3e.', name, imaginaryRatio);
    end
    M = real(value);
end

function vector = ValidateRealVector(value, count, name)
    if ~isnumeric(value) || ~isvector(value) || numel(value) ~= count || ...
            any(~isfinite(real(value(:)))) || ...
            any(~isfinite(imag(value(:))))
        error('ResolvePronkingCriticalSubspace:InvalidVector', ...
            '%s must be a finite numeric %d-vector.', name, count);
    end
    value = value(:);
    imaginaryRatio = norm(imag(value)) / max(1, norm(real(value)));
    if imaginaryRatio > 1e-12
        error('ResolvePronkingCriticalSubspace:ComplexVector', ...
            '%s has relative imaginary norm %.3e.', name, imaginaryRatio);
    end
    vector = real(value);
end

function [scale, source] = ResolveStateScale(diagnostics, supplied)
    if ~isempty(supplied)
        scale = supplied(:);
        source = 'options.StateScale';
        return
    end
    scale = NestedVector(diagnostics, ...
        {'branchSwitchReadinessDiagnostics','stateScale'}, 12);
    if ~isempty(scale)
        source = 'branchSwitchReadinessDiagnostics.stateScale';
        return
    end
    scale = NestedVector(diagnostics, {'eigenData','StateScale'}, 12);
    if ~isempty(scale)
        source = 'eigenData.StateScale';
        return
    end
    % A multiple kernel makes RefineCriticalOrbit deliberately return before
    % its single-direction readiness path fills stateScale.  The Floquet FD
    % report still retains the exact characteristic scale used to perturb q.
    scale = NestedVector(diagnostics, ...
        {'floquetDiagnostics','perturbationScaling', ...
         'characteristicScale'}, 12);
    if ~isempty(scale)
        source = ['floquetDiagnostics.perturbationScaling.' ...
            'characteristicScale'];
        return
    end

    % Retain a final fallback matching PredictBranchDirection for accepted
    % legacy diagnostics that predate the stored perturbation-scale report.
    q = [];
    if isfield(diagnostics, 'X') && isnumeric(diagnostics.X) && ...
            numel(diagnostics.X) == 13 && all(isfinite(diagnostics.X(:)))
        X = diagnostics.X(:);
        q = X([1 2 4:13]);
    elseif isfield(diagnostics, 'solution') && ...
            isnumeric(diagnostics.solution) && ...
            numel(diagnostics.solution) >= 13 && ...
            all(isfinite(diagnostics.solution(1:13)))
        X = diagnostics.solution(:);
        q = X([1 2 4:13]);
    end
    if ~isempty(q)
        scale = max(abs(q), [1; 1; 0.5 * ones(10,1)]);
        source = 'reconstructed-from-refined-diagnostic-state';
        return
    end
    error('ResolvePronkingCriticalSubspace:MissingStateScale', ...
        ['No valid diagnostic state scale is available and no refined ' ...
         'state exists from which to reconstruct it.']);
end

function [uncertainty, source] = ResolveMatrixUncertainty( ...
        diagnostics, supplied)
    if ~isempty(supplied)
        uncertainty = supplied;
        source = 'options.MatrixUncertainty';
        return
    end
    candidates = { ...
        {'richardsonFrobeniusMatrixErrorEstimate'}, ...
        {'branchSwitchReadinessDiagnostics', ...
         'richardsonFrobeniusMatrixErrorEstimate'}, ...
        {'modeDiagnostics','richardsonFrobeniusErrorEstimate'}, ...
        {'floquetDiagnostics','derivativeConvergence', ...
         'richardsonFrobeniusErrorEstimate'}};
    labels = { ...
        'richardsonFrobeniusMatrixErrorEstimate', ...
        ['branchSwitchReadinessDiagnostics.' ...
         'richardsonFrobeniusMatrixErrorEstimate'], ...
        'modeDiagnostics.richardsonFrobeniusErrorEstimate', ...
        ['floquetDiagnostics.derivativeConvergence.' ...
         'richardsonFrobeniusErrorEstimate']};
    for index = 1:numel(candidates)
        value = NestedScalar(diagnostics, candidates{index}, NaN);
        if isfinite(value) && value >= 0
            uncertainty = value;
            source = labels{index};
            return
        end
    end
    error('ResolvePronkingCriticalSubspace:MissingMatrixUncertainty', ...
        ['A Richardson Frobenius matrix-error estimate is required to ' ...
         'certify the leg-swap commutators.']);
end

function [tolerance, source] = ResolveNullityTolerance( ...
        diagnostics, supplied, M, uncertainty)
    if ~isempty(supplied)
        tolerance = supplied;
        source = 'options.NullityTolerance';
        return
    end
    value = NestedScalar(diagnostics, ...
        {'branchSwitchReadinessDiagnostics','svdNullityTolerance'}, NaN);
    if isfinite(value) && value > 0
        tolerance = value;
        source = 'branchSwitchReadinessDiagnostics.svdNullityTolerance';
        return
    end
    multiplierTolerance = NestedScalar(diagnostics, ...
        {'options','MultiplierTolerance'}, 1e-6);
    clusterTolerance = NestedScalar(diagnostics, ...
        {'options','ClusterSpreadTolerance'}, 1e-5);
    nearRadius = max(10 * multiplierTolerance, clusterTolerance);
    tolerance = max(nearRadius * max(1, norm(M,2)), uncertainty);
    source = 'reconstructed-from-refinement-tolerances';
end

function [RH, RF, projectors] = PronkingSymmetryOperators()
    RH = eye(12);
    RH([5 6 9 10], [5 6 9 10]) = [ ...
        0 0 1 0; 0 0 0 1; 1 0 0 0; 0 1 0 0];
    RF = eye(12);
    RF([7 8 11 12], [7 8 11 12]) = [ ...
        0 0 1 0; 0 0 0 1; 1 0 0 0; 0 1 0 0];
    I = eye(12);
    projectors = struct();
    projectors.EvenEven = (I + RH) * (I + RF) / 4;
    projectors.HindEvenFrontOdd = (I + RH) * (I - RF) / 4;
    projectors.HindOddFrontEven = (I - RH) * (I + RF) / 4;
    projectors.OddOdd = (I - RH) * (I - RF) / 4;
end

function checks = SwapAlgebraChecks(RH, RF, projectors)
    I = eye(12);
    P = {projectors.EvenEven, projectors.HindEvenFrontOdd, ...
        projectors.HindOddFrontEven, projectors.OddOdd};
    idempotence = zeros(1,4);
    orthogonality = zeros(4,4);
    for first = 1:4
        idempotence(first) = norm(P{first} * P{first} - P{first}, 'fro');
        for second = 1:4
            if first ~= second
                orthogonality(first,second) = ...
                    norm(P{first} * P{second}, 'fro');
            end
        end
    end
    checks = struct();
    checks.hindInvolutionResidual = norm(RH * RH - I, 'fro');
    checks.frontInvolutionResidual = norm(RF * RF - I, 'fro');
    checks.generatorCommutatorResidual = norm(RH * RF - RF * RH, 'fro');
    checks.projectorSumResidual = norm( ...
        P{1} + P{2} + P{3} + P{4} - I, 'fro');
    checks.projectorIdempotenceResiduals = idempotence;
    checks.projectorOrthogonalityResiduals = orthogonality;
end

function sector = ResolveSector( ...
        projector, scaledSubspace, physicalSubspace, scale, tolerance)
    projected = projector * physicalSubspace;
    projectedScaled = projected ./ scale;
    % Project back into the certified near-null subspace.  This removes
    % only commutator-sized leakage introduced by finite-difference error.
    projectedInSubspace = scaledSubspace * ...
        (scaledSubspace' * projectedScaled);
    [leftVectors, singularMatrix, ~] = svd(projectedInSubspace, 'econ');
    singularValues = diag(singularMatrix);
    sectorRank = sum(singularValues > tolerance);
    if sectorRank > 0
        basis = scale .* leftVectors(:,1:sectorRank);
        for column = 1:size(basis,2)
            basis(:,column) = basis(:,column) / ...
                norm(basis(:,column) ./ scale);
        end
    else
        basis = zeros(12,0);
    end
    sector = EmptySector();
    sector.rank = sectorRank;
    sector.singularValues = singularValues;
    sector.basis = basis;
    sector.rawProjectedBasis = projected;
    sector.projectedOutsideSubspaceNorm = norm( ...
        projectedScaled - projectedInSubspace, 'fro');
end

function vector = OrientVector(vector, scale, differenceIndices)
    vector = vector / norm(vector ./ scale);
    orientationValue = 0;
    if ~isempty(differenceIndices)
        orientationValue = vector(differenceIndices(1)) - ...
            vector(differenceIndices(2));
    end
    threshold = 100 * eps * max(1, norm(vector,inf));
    if abs(orientationValue) <= threshold
        scaled = vector ./ scale;
        [~, index] = max(abs(scaled));
        orientationValue = scaled(index);
    end
    if orientationValue < 0
        vector = -vector;
    end
end

function details = CheckDirection(name, vector, signs, A, M, tangent, ...
        scale, RH, RF, eigenTolerance, symmetryTolerance)
    scaled = vector ./ scale;
    scaledTangent = tangent ./ scale;
    weightedNorm = norm(scaled);
    eigenResidual = norm(A * vector) / ...
        ((1 + norm(M,2)) * norm(vector));
    tangentCosine = abs(scaledTangent' * scaled) / ...
        (norm(scaledTangent) * weightedNorm);
    hindResidual = norm(RH * vector - signs(1) * vector) / ...
        max(norm(vector), eps);
    frontResidual = norm(RF * vector - signs(2) * vector) / ...
        max(norm(vector), eps);
    reasons = {};
    if abs(weightedNorm - 1) > 1e-10
        reasons{end + 1} = sprintf( ...
            '%s direction has weighted norm %.16g, not one.', ...
            name, weightedNorm);
    end
    if eigenResidual > eigenTolerance
        reasons{end + 1} = sprintf( ...
            '%s normalized (M-I) residual %.3e exceeds %.3e.', ...
            name, eigenResidual, eigenTolerance);
    end
    if tangentCosine > 1e-8
        reasons{end + 1} = sprintf( ...
            '%s scaled tangent overlap %.3e exceeds 1e-8.', ...
            name, tangentCosine);
    end
    if max(hindResidual, frontResidual) > symmetryTolerance
        reasons{end + 1} = sprintf( ...
            ['%s swap residuals (hind %.3e, front %.3e) exceed ' ...
             '%.3e.'], name, hindResidual, frontResidual, symmetryTolerance);
    end
    details = EmptyDirectionDiagnostics();
    details.name = name;
    details.accepted = isempty(reasons);
    details.swapSigns = signs;
    details.weightedNorm = weightedNorm;
    details.euclideanNorm = norm(vector);
    details.normalizedEigenResidual = eigenResidual;
    details.scaledTangentCosine = tangentCosine;
    details.hindSwapResidual = hindResidual;
    details.frontSwapResidual = frontResidual;
    details.rejectionReasons = reasons;
end

function eigenData = MakeEigenData( ...
        vector, tangent, scale, refinement, label)
    eigenData = struct();
    eigenData.Type = '+1';
    eigenData.type = '+1';
    eigenData.Multiplier = 1;
    eigenData.multiplier = 1;
    eigenData.Eigenvector = vector;
    eigenData.eigenvector = vector;
    eigenData.CriticalSubspace = vector;
    eigenData.NullDirectionClassification = 'additional-null-direction';
    eigenData.IsAdditionalNullDirection = true;
    eigenData.isAdditionalNullDirection = true;
    eigenData.IsTrivialBranchTangent = false;
    eigenData.isBranchTangent = false;
    eigenData.BranchTangent = tangent;
    eigenData.branchTangent = tangent;
    eigenData.StateScale = scale;
    eigenData.SymmetryCoordinate = label;
    if isfield(refinement, 'topology')
        eigenData.ReferenceTopology = refinement.topology;
    else
        eigenData.ReferenceTopology = struct();
    end
    if isfield(refinement, 'parameters')
        eigenData.Parameters = refinement.parameters;
    else
        eigenData.Parameters = [];
    end
    if isfield(refinement, 'solution')
        eigenData.Solution = refinement.solution;
    else
        eigenData.Solution = [];
    end
end

function basis = OrthonormalColumns(value)
    if isempty(value)
        basis = zeros(size(value,1),0);
        return
    end
    [Q, R] = qr(value, 0);
    diagonal = abs(diag(R));
    tolerance = max(size(value)) * eps(max(1, norm(R,2)));
    rankValue = sum(diagonal > tolerance);
    basis = Q(:,1:rankValue);
end

function value = NestedScalar(container, path, defaultValue)
    value = container;
    for index = 1:numel(path)
        if ~isstruct(value) || ~isscalar(value) || ...
                ~isfield(value, path{index})
            value = defaultValue;
            return
        end
        value = value.(path{index});
    end
    if ~(isnumeric(value) && isscalar(value) && isreal(value))
        value = defaultValue;
    end
end

function value = NestedVector(container, path, count)
    value = container;
    for index = 1:numel(path)
        if ~isstruct(value) || ~isscalar(value) || ...
                ~isfield(value, path{index})
            value = [];
            return
        end
        value = value.(path{index});
    end
    if ~isnumeric(value) || ~isvector(value) || numel(value) ~= count || ...
            any(~isfinite(value(:))) || any(value(:) <= 0)
        value = [];
        return
    end
    value = value(:);
end

function output = FiniteNonnegativeOr(value, fallback)
    if isnumeric(value) && isscalar(value) && isfinite(value) && value >= 0
        output = value;
    else
        output = fallback;
    end
end

function text = IntegerRow(values)
    text = strtrim(sprintf('%d ', values));
end

function directions = EmptyDirections()
    directions = struct();
    directions.Bounding = [];
    directions.FrontSpread = [];
    directions.HindSpread = [];
    directions.Matrix = [];
    directions.StateScale = [];
    directions.ReducedStateOrdering = {};
    directions.Normalization = '';
    directions.OrientationConvention = '';
    directions.BoundingEigenData = struct();
    directions.FrontSpreadEigenData = struct();
    directions.HindSpreadEigenData = struct();
end

function diagnostics = InitialDiagnostics(options)
    diagnostics = struct();
    diagnostics.accepted = false;
    diagnostics.valid = false;
    diagnostics.status = 'not-evaluated';
    diagnostics.rejectionReasons = {};
    diagnostics.options = options;
end

function sector = EmptySector()
    sector = struct('name', '', 'swapSigns', [NaN NaN], ...
        'rank', 0, 'singularValues', [], 'basis', zeros(12,0), ...
        'rawProjectedBasis', [], 'projectedOutsideSubspaceNorm', NaN);
end

function details = EmptyDirectionDiagnostics()
    details = struct('name', '', 'accepted', false, ...
        'swapSigns', [NaN NaN], 'weightedNorm', NaN, ...
        'euclideanNorm', NaN, 'normalizedEigenResidual', NaN, ...
        'scaledTangentCosine', NaN, 'hindSwapResidual', NaN, ...
        'frontSwapResidual', NaN, 'rejectionReasons', {{}});
end

function [directions, diagnostics] = Finish( ...
        directions, diagnostics, options)
    diagnostics.accepted = isempty(diagnostics.rejectionReasons);
    diagnostics.valid = diagnostics.accepted;
    if diagnostics.accepted
        diagnostics.status = 'accepted';
    else
        diagnostics.status = 'rejected';
        directions = EmptyDirections();
        if options.ThrowOnFailure
            error('ResolvePronkingCriticalSubspace:Rejected', '%s', ...
                strjoin(diagnostics.rejectionReasons, ' | '));
        end
    end
end

function ValidatePositiveInteger(value, name)
    if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
            value >= 1 && value == floor(value))
        error('ResolvePronkingCriticalSubspace:InvalidOption', ...
            '%s must be a positive integer.', name);
    end
end

function ValidatePositiveScalar(value, name)
    if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value > 0)
        error('ResolvePronkingCriticalSubspace:InvalidOption', ...
            '%s must be a positive finite scalar.', name);
    end
end

function ValidateNonnegativeScalar(value, name)
    if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value >= 0)
        error('ResolvePronkingCriticalSubspace:InvalidOption', ...
            '%s must be a nonnegative finite scalar.', name);
    end
end

function ValidateOptionalPositiveScalar(value, name)
    if ~isempty(value)
        ValidatePositiveScalar(value, name);
    end
end

function ValidateOptionalNonnegativeScalar(value, name)
    if ~isempty(value)
        ValidateNonnegativeScalar(value, name);
    end
end

function ValidateOptionalPositiveVector(value, name, count)
    if isempty(value)
        return
    end
    if ~isnumeric(value) || ~isvector(value) || numel(value) ~= count || ...
            any(~isfinite(value(:))) || any(value(:) <= 0)
        error('ResolvePronkingCriticalSubspace:InvalidOption', ...
            '%s must be a positive finite %d-vector.', name, count);
    end
end

function ValidateUnitInterval(value, name)
    if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
            value > 0 && value <= 1)
        error('ResolvePronkingCriticalSubspace:InvalidOption', ...
            '%s must lie in (0,1].', name);
    end
end
