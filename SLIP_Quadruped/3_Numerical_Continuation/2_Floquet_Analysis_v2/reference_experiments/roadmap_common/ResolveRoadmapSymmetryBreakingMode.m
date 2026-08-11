function symmetry = ResolveRoadmapSymmetryBreakingMode(refinement, specification, options)
%RESOLVEROADMAPSYMMETRYBREAKINGMODE Verify the critical leg-swap parity.
%
%   The expected Z2 operator is selected from SPEC.ExpectedBrokenPair.
%   This routine verifies that the parent orbit and branch tangent are even,
%   the refined critical mode is odd, M approximately commutes with the
%   swap, and the near-+1 null space contains exactly one odd direction.
%   DetectBifurcation.NullMultiplicity is intentionally not used as a
%   numerical nullity estimate because its candidate radius is much looser.

    if nargin < 3 || isempty(options)
        options = struct();
    end
    opts = ParseOptions(options);
    ValidateInputs(refinement,specification);
    R = BuildReducedSwap(specification.ExpectedBrokenPair);
    qIndex = [1 2 4:13];
    q = refinement.X(qIndex);
    scale = refinement.eigenData.StateScale(:);
    vector = refinement.eigenData.Eigenvector(:);
    tangent = refinement.localBranchTangent(:);
    M = refinement.floquetMatrix;

    qScaled = q./scale;
    vectorScaled = vector./scale;
    tangentScaled = tangent./scale;
    parentFixedness = norm((R*q-q)./scale)/max(1,norm(qScaled));
    criticalOddResidual = norm(R*vectorScaled+vectorScaled)/ ...
        max(eps,norm(vectorScaled));
    criticalEvenResidual = norm(R*vectorScaled-vectorScaled)/ ...
        max(eps,norm(vectorScaled));
    tangentEvenResidual = norm(R*tangentScaled-tangentScaled)/ ...
        max(eps,norm(tangentScaled));
    commutatorResidual = norm(M*R-R*M,'fro')/max(1,norm(M,'fro'));

    K = refinement.eigenData.FullNearPlusOneSubspace;
    Kscaled = K./scale;
    oddPart = 0.5*(eye(12)-R)*Kscaled;
    [oddBasis,oddRank,oddSingularValues] = ...
        NumericalRange(oddPart,opts.SubspaceRankTolerance);
    if oddRank == 1
        selectedAlignment = abs((vectorScaled/norm(vectorScaled))' * ...
            oddBasis(:,1));
        selectedAlignment = min(1,selectedAlignment);
    else
        selectedAlignment = NaN;
    end

    uncertainty = FieldNumber(refinement, ...
        'richardsonFrobeniusMatrixErrorEstimate',0);
    commutatorTolerance = max(opts.CommutatorTolerance, ...
        opts.UncertaintyFactor*uncertainty/max(1,norm(M,'fro')));
    assertions = struct();
    assertions.parentFixedBySwap = parentFixedness <= opts.ParentFixednessTolerance;
    assertions.branchTangentEven = tangentEvenResidual <= opts.EvenResidualTolerance;
    assertions.criticalDirectionOdd = criticalOddResidual <= opts.OddResidualTolerance;
    assertions.criticalDirectionNotEven = criticalEvenResidual >= opts.MinimumOppositeParityResidual;
    assertions.floquetMapCommutesWithSwap = commutatorResidual <= commutatorTolerance;
    assertions.uniqueOddNearNullDirection = oddRank == 1;
    assertions.selectedModeMatchesOddNullDirection = oddRank == 1 && ...
        selectedAlignment >= opts.MinimumOddSubspaceAlignment;
    names = fieldnames(assertions);
    accepted = true;
    for k = 1:numel(names)
        accepted = accepted && logical(assertions.(names{k}));
    end

    symmetry = struct();
    symmetry.version = 'roadmap-z2-mode-resolution-v1';
    symmetry.accepted = accepted;
    symmetry.brokenPair = specification.ExpectedBrokenPair;
    symmetry.reducedSwapOperator = R;
    symmetry.parentFixedness = parentFixedness;
    symmetry.criticalOddResidual = criticalOddResidual;
    symmetry.criticalEvenResidual = criticalEvenResidual;
    symmetry.tangentEvenResidual = tangentEvenResidual;
    symmetry.commutatorResidual = commutatorResidual;
    symmetry.commutatorTolerance = commutatorTolerance;
    symmetry.oddNullRank = oddRank;
    symmetry.oddNullBasisScaled = oddBasis;
    symmetry.oddNullSingularValues = oddSingularValues;
    symmetry.selectedOddSubspaceAlignment = selectedAlignment;
    symmetry.assertions = assertions;
    symmetry.rejectionReasons = names(~structfun(@logical,assertions)).';
    symmetry.options = opts;
end

function opts = ParseOptions(options)
    defaults = struct( ...
        'ParentFixednessTolerance',1e-6, ...
        'EvenResidualTolerance',1e-3, ...
        'OddResidualTolerance',1e-3, ...
        'MinimumOppositeParityResidual',1, ...
        'CommutatorTolerance',1e-3, ...
        'UncertaintyFactor',20, ...
        'SubspaceRankTolerance',1e-6, ...
        'MinimumOddSubspaceAlignment',0.99);
    if ~isstruct(options) || ~isscalar(options)
        error('ResolveRoadmapSymmetryBreakingMode:Options', ...
            'options must be a scalar structure.');
    end
    opts = defaults;
    names = fieldnames(options);
    allowed = fieldnames(defaults);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k},allowed),1);
        if isempty(hit)
            error('ResolveRoadmapSymmetryBreakingMode:UnknownOption', ...
                'Unknown option %s.',names{k});
        end
        opts.(allowed{hit}) = options.(names{k});
    end
    names = fieldnames(opts);
    for k = 1:numel(names)
        value = opts.(names{k});
        if ~(isscalar(value) && isfinite(value) && value > 0)
            error('ResolveRoadmapSymmetryBreakingMode:PositiveOption', ...
                '%s must be positive and finite.',names{k});
        end
    end
    if opts.MinimumOddSubspaceAlignment > 1
        error('ResolveRoadmapSymmetryBreakingMode:Alignment', ...
            'MinimumOddSubspaceAlignment cannot exceed one.');
    end
end

function ValidateInputs(refinement,specification)
    if ~isstruct(refinement) || ~isscalar(refinement) || ...
            ~isfield(refinement,'accepted') || ~refinement.accepted || ...
            ~isfield(refinement,'branchSwitchReady') || ...
            ~refinement.branchSwitchReady
        error('ResolveRoadmapSymmetryBreakingMode:Refinement', ...
            'An accepted branch-switch-ready refinement is required.');
    end
    if ~isstruct(specification) || ~isscalar(specification) || ...
            ~isfield(specification,'ExpectedBrokenPair') || ...
            ~any(strcmp(specification.ExpectedBrokenPair,{'front','hind'}))
        error('ResolveRoadmapSymmetryBreakingMode:Specification', ...
            'ExpectedBrokenPair must be front or hind.');
    end
end

function R = BuildReducedSwap(pair)
    R = eye(12);
    if strcmp(pair,'hind')
        left = [5 6];
        right = [9 10];
    else
        left = [7 8];
        right = [11 12];
    end
    indices = [left right];
    R(indices,indices) = 0;
    for k = 1:numel(left)
        R(left(k),right(k)) = 1;
        R(right(k),left(k)) = 1;
    end
end

function [basis,rankValue,values] = NumericalRange(A,tolerance)
    [U,S,~] = svd(A,'econ');
    values = diag(S);
    if isempty(values)
        rankValue = 0;
        basis = zeros(size(A,1),0);
        return
    end
    threshold = tolerance*max(1,values(1));
    rankValue = sum(values > threshold);
    basis = U(:,1:rankValue);
end

function value = FieldNumber(input,name,default)
    if isstruct(input) && isfield(input,name) && ...
            isnumeric(input.(name)) && isscalar(input.(name)) && ...
            isfinite(input.(name))
        value = input.(name);
    else
        value = default;
    end
end
