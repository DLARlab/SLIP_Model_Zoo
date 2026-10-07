function [solution, diagnostics] = refineCriticalOrbit(varargin)
%REFINECRITICALORBIT Refine a bracketed Floquet crossing on periodic orbits.
%
%   [SOLUTION,DIAGNOSTICS] = REFINECRITICALORBIT(BRANCH,CANDIDATE,OPTIONS)
%   refines a +1, -1, or complex-unit-circle candidate returned by
%   DetectBifurcation. BRANCH may be a numeric 29-by-N continuation array,
%   a load result with field `results`, or a struct with `results` plus an
%   optional `sampleIndices` mapping. A struct containing `branchFile` is
%   also accepted and the `results` variable is loaded from that file.
%
%   [SOLUTION,DIAGNOSTICS] = REFINECRITICALORBIT(...
%       ZLEFT,ZRIGHT,PARAMETERS,CANDIDATE,OPTIONS)
%   accepts two explicit 22-vectors. PARAMETERS is a shared 7-vector or a
%   7-by-2 matrix containing endpoint parameters.
%
%   DetectBifurcation indices are sample-local. This function never assumes
%   that they are continuation-column indices: it uses OPTIONS.BracketIndices,
%   a supplied sampleIndices map, or a unique match against CANDIDATE.Bracket.
%   Ambiguous coordinate matches are rejected.
%
%   Every trial orbit is first interpolated in the physical state and in the
%   continuation framework's locally lifted circular timing chart. It is
%   then corrected at the prescribed physical continuation coordinate
%   with the canonical residual
%
%       Quadrupedal_ZeroFun_v2(X,E,Para,Constraints,'skipSolve')
%
%   augmented by the coordinate constraint (X(1)=dx by default). Event times are orbit-corrector
%   unknowns, not Floquet coordinates. ComputeFloquetFDM is then recomputed
%   on the corrected orbit using the endpoint event topology as a required
%   reference. A safeguarded secant step is used when it lies safely inside
%   the bracket; otherwise bisection is used.
%
%   The target mode is followed using eigenvector overlap. A nearly repeated
%   real +1/-1 eigenvalue is tracked as its invariant subspace and the mean
%   signed multiplier is refined. The refinement is accepted only if the
%   subspace dimension is preserved, its principal overlap is adequate, and
%   the critical eigenvalues remain clustered. A supplied OPTIONS.TargetSubspace
%   may be used to disambiguate a known repeated mode. Unsupported or
%   defective eigenspaces are explicitly rejected rather than silently
%   selecting one numerically arbitrary eigenvector.
%   For a repeated real +1 TargetSubspace that contains a known trivial
%   direction, ExcludedTargetDirection removes the selected eigenvalue whose
%   normalized eigenvector has greatest normalized overlap with that
%   direction from the scalar crossing residual. The complete matched
%   eigenspace and selected spectrum remain available in the diagnostics.
%   This option does not resolve an exactly degenerate eigenspace whose
%   individual eigenvectors rotate too strongly to identify the supplied
%   direction; MinimumExcludedTargetOverlap rejects that ambiguity.
%
%   On success SOLUTION is the corrected 22-vector. On every numerical or
%   validation failure SOLUTION is [] and DIAGNOSTICS.accepted is false.
%   OPTIONS.ThrowOnFailure=true rethrows the recorded exception.
%
%   Principal OPTIONS (all optional):
%       SampleIndices                   local-to-branch column map
%       BracketIndices                  explicit two continuation columns
%       RequireAdjacentBranchPoints     default true
%       Constraints                     canonical residual constraints, {}
%       ContinuationParameterRow        physical X row, default 1 (dx)
%       ContinuationParameterName       chart label, default dx / X(row)
%       ContinuationCoordinateFunction  optional scalar c(z), overrides row
%       ParentCorrector                 optional [z,info]=f(guess,Para,c,context)
%       FloquetOptions                  options for ComputeFloquetFDM
%       FsolveOptions                   optimset-compatible options
%       CorrectEndpoints                correct both saved endpoints, true
%       AllowParameterInterpolation     permit linear Para interpolation, false
%       ParameterTolerance              fixed-Para comparison tolerance, 1e-12
%       ResidualTolerance               canonical infinity norm, 1e-8
%       CoordinateConstraintTolerance   accepted abs(c(z)-cTrial), 1e-9
%       MultiplierTolerance             final crossing residual, 1e-6
%       CriticalMultiplierUncertaintyTolerance  coarse/fine mode error, same
%       CoordinateTolerance             final coordinate bracket tolerance, 1e-6
%       MaxIterations                   safeguarded iterations, 20
%       SecantGuardFraction             interior guard, 0.1
%       MinimumModeOverlap              simple-mode overlap, 0.5
%       MinimumSubspaceOverlap          smallest principal cosine, 0.5
%       DegenerateEigenvalueTolerance   repeated-root relative gap, 1e-6
%       ClusterSpreadTolerance          final repeated-root spread, 1e-5
%       TargetSearchRadius              search about +/-1/unit circle, 0.25
%       TargetSubspace                  optional 12-by-r reference basis
%       ExcludedTargetDirection         optional trivial +1 direction, []
%       MinimumExcludedTargetOverlap    exclusion assignment threshold, 0.5
%       MaximumSubspaceDimension        default 4
%       ComplexPairTolerance            relative conjugacy error, 1e-5
%       EventTimeAgreementTolerance     corrected/solved E agreement, 1e-7
%       MaximumBranchTangentOverlap     predictor-ready +1 test, 0.9
%       MinimumBranchTangentNullProjection  tangent/null membership, 0.99
%       ReferenceTopology               optional required topology struct
%       StoreFullFloquetDiagnostics     retain every full FD report, false
%       ThrowOnFailure                  default false
%
%   DIAGNOSTICS contains the resolved branch columns, initial/final bracket,
%   correction and Floquet histories, selected multiplier indices, overlap
%   metrics, final matrix/spectrum/eigenspace, topology comparisons, and all
%   rejection reasons.
%
%   ParentCorrector permits a justified lower-dimensional parent embedding.
%   context provides coordinateFunction, coordinateRow, coordinateName,
%   coordinateScale, canonicalResidual, fsolveOptions, residualTolerance and
%   coordinateTolerance. Return info.exitflag>0 and info.jacobian of the
%   independent correction residual INCLUDING the coordinate equation.
%   Its Jacobian must have full column rank; all canonical residual, timing,
%   topology, and full 12-state FDM checks are still performed independently.
%   Parent restrictions belong in this hook, never in FloquetOptions.
%   A fixed local hyperplane can be supplied as ContinuationCoordinateFunction
%   c(z)=tHat'*((lift(z)-zReference)./scale), fixed unit tHat and fixed scale.
%   The caller must lift event times continuously about the fixed reference
%   and use the same chart in the parent corrector and candidate bracket.

    floquet.internal.ensureRuntimePaths(false);
    diagnostics = InitialDiagnostics();
    throwOnFailure = false;

    try
        [problem, candidate, userOptions] = ParseInvocation(varargin{:});
        if isstruct(userOptions) && isscalar(userOptions) && ...
                isfield(userOptions, 'ThrowOnFailure')
            throwOnFailure = logical(userOptions.ThrowOnFailure);
        end
        options = ParseOptions(userOptions);
        throwOnFailure = options.ThrowOnFailure;
        diagnostics.options = options;
        diagnostics.candidate = candidate;

        [leftInput, rightInput, mapping] = ResolveProblem(problem, candidate, options);
        diagnostics.inputMode = problem.mode;
        diagnostics.resolvedBranchIndices = mapping.branchIndices;
        diagnostics.indexMapping = mapping;
        diagnostics.inputBracket = [leftInput.coordinate, rightInput.coordinate];

        [leftInput, rightInput] = SortEndpoints(leftInput, rightInput);
        if leftInput.coordinate == rightInput.coordinate
            error('RefineCriticalOrbit:ZeroWidthBracket', ...
                'The two endpoint %s values must be distinct.', ...
                options.ContinuationParameterName);
        end
        ValidateParameterVariation(leftInput.parameters, ...
            rightInput.parameters, options);

        floquetOptions = options.FloquetOptions;
        [hasFloquetConstraints, floquetConstraints, constraintField] = ...
            FieldValueCaseInsensitive(floquetOptions, 'Constraints');
        if hasFloquetConstraints
            if ~(iscell(floquetConstraints) || isstruct(floquetConstraints))
                error('RefineCriticalOrbit:FloquetConstraints', ...
                    'FloquetOptions.Constraints must be a cell array or struct.');
            end
            if ~isempty(options.Constraints) && ...
                    ~isempty(floquetConstraints) && ...
                    ~isequaln(options.Constraints, floquetConstraints)
                error('RefineCriticalOrbit:ConstraintMismatch', ...
                    ['Constraints and FloquetOptions.Constraints differ; ' ...
                     'one residual definition must be used by the corrector, ' ...
                     'timing solver, and Floquet map.']);
            end
            if ~isempty(floquetConstraints)
                options.Constraints = floquetConstraints;
            end
            if ~strcmp(constraintField, 'Constraints')
                floquetOptions = rmfield(floquetOptions, constraintField);
            end
        end
        floquetOptions.Constraints = options.Constraints;
        options.FloquetOptions = floquetOptions;
        diagnostics.options = options;
        [referenceTopology, endpointTopology] = ResolveReferenceTopology( ...
            leftInput.solution(14:22), rightInput.solution(14:22), ...
            floquetOptions, options.ReferenceTopology);
        diagnostics.referenceTopology = referenceTopology;
        diagnostics.endpointTopology = endpointTopology;
        floquetOptions.ReferenceTopology = referenceTopology;

        left = EvaluateOrbit(leftInput.coordinate, leftInput.solution, ...
            leftInput.parameters, referenceTopology, floquetOptions, ...
            options, 'left-endpoint', options.CorrectEndpoints);
        diagnostics.history(end + 1) = HistoryView(left, options);
        RequireEvaluation(left, 'left endpoint');

        [left.mode, target] = InitializeTargetMode( ...
            left.multipliers, left.eigenvectors, candidate, options);
        left = AttachCriticalModeUncertainty(left, target, options);
        left.signedValue = left.mode.signedValue;
        diagnostics.target = target;
        diagnostics.history(end) = HistoryView(left, options);

        right = EvaluateOrbit(rightInput.coordinate, rightInput.solution, ...
            rightInput.parameters, referenceTopology, floquetOptions, ...
            options, 'right-endpoint', options.CorrectEndpoints);
        diagnostics.history(end + 1) = HistoryView(right, options);
        RequireEvaluation(right, 'right endpoint');
        right.mode = MatchTargetMode(right.multipliers, right.eigenvectors, ...
            target, left.mode, options);
        right = AttachCriticalModeUncertainty(right, target, options);
        right.signedValue = right.mode.signedValue;
        diagnostics.history(end) = HistoryView(right, options);

        [left, right] = SortEvaluations(left, right);
        RequireSignedBracket(left.signedValue, right.signedValue);
        diagnostics.initialSignedBracket = [left.signedValue, right.signedValue];

        best = BetterEvaluation(left, right);
        converged = IsRefinementConverged(best, left, right, options);
        iteration = 0;
        while ~converged && iteration < options.MaxIterations
            iteration = iteration + 1;
            [trialCoordinate, stepKind] = SafeguardedCoordinate(left, right, options);
            alpha = (trialCoordinate - left.coordinate) / ...
                (right.coordinate - left.coordinate);
            trialGuess = CircularOrbitInterpolation( ...
                left.solution, right.solution, alpha);
            trialParameters = InterpolateParameters( ...
                left.parameters, right.parameters, alpha);
            referenceMode = NearestReferenceMode( ...
                trialCoordinate, left, right);

            trial = EvaluateOrbit(trialCoordinate, trialGuess, ...
                trialParameters, referenceTopology, floquetOptions, ...
                options, stepKind, true);
            if trial.accepted
                try
                    trial.mode = MatchTargetMode( ...
                        trial.multipliers, trial.eigenvectors, target, ...
                        referenceMode, options);
                    trial = AttachCriticalModeUncertainty( ...
                        trial, target, options);
                    trial.signedValue = trial.mode.signedValue;
                catch modeError
                    trial.accepted = false;
                    trial.rejectionReasons{end + 1} = sprintf( ...
                        '%s: %s', modeError.identifier, modeError.message);
                    trial.exception = modeError;
                end
            end
            diagnostics.history(end + 1) = HistoryView(trial, options);

            % A failed secant evaluation receives one bisection fallback.
            if ~trial.accepted && strcmp(stepKind, 'secant')
                midpoint = 0.5 * (left.coordinate + right.coordinate);
                alpha = (midpoint - left.coordinate) / ...
                    (right.coordinate - left.coordinate);
                midpointGuess = CircularOrbitInterpolation( ...
                    left.solution, right.solution, alpha);
                midpointParameters = InterpolateParameters( ...
                    left.parameters, right.parameters, alpha);
                referenceMode = NearestReferenceMode(midpoint, left, right);
                trial = EvaluateOrbit(midpoint, midpointGuess, ...
                    midpointParameters, referenceTopology, floquetOptions, ...
                    options, 'bisection-fallback', true);
                if trial.accepted
                    try
                        trial.mode = MatchTargetMode( ...
                            trial.multipliers, trial.eigenvectors, target, ...
                            referenceMode, options);
                        trial = AttachCriticalModeUncertainty( ...
                            trial, target, options);
                        trial.signedValue = trial.mode.signedValue;
                    catch modeError
                        trial.accepted = false;
                        trial.rejectionReasons{end + 1} = sprintf( ...
                            '%s: %s', modeError.identifier, modeError.message);
                        trial.exception = modeError;
                    end
                end
                diagnostics.history(end + 1) = HistoryView(trial, options);
            end
            RequireEvaluation(trial, sprintf('iteration %d', iteration));

            [left, right] = UpdateBracket(left, right, trial);
            best = BetterEvaluation(best, trial);
            diagnostics.bracketHistory(end + 1, :) = [ ...
                left.coordinate, right.coordinate, ...
                left.signedValue, right.signedValue];

            converged = IsRefinementConverged(best, left, right, options);
            if converged
                break
            end
        end

        if ~IsRefinementConverged(best, left, right, options)
            error('RefineCriticalOrbit:RefinementNotConverged', ...
                ['Safeguarded refinement ended with |critical residual| %.3e, ' ...
                 'cluster spread %.3e, coarse/fine uncertainty %.3e ' ...
                 '(tolerance %.3e), and coordinate bracket width %.3e.'], ...
                abs(best.signedValue), best.mode.clusterSpread, ...
                best.mode.criticalMultiplierUncertainty, ...
                options.CriticalMultiplierUncertaintyTolerance, ...
                abs(right.coordinate - left.coordinate));
        end

        % The accepted orbit already carries a freshly recomputed Floquet
        % matrix and a topology-validated canonical correction.
        solution = best.solution;
        diagnostics.accepted = true;
        diagnostics.valid = true;
        diagnostics.status = 'accepted';
        diagnostics.iterations = iteration;
        diagnostics.finalBracket = [left.coordinate, right.coordinate];
        diagnostics.finalSignedBracket = [left.signedValue, right.signedValue];
        diagnostics.coordinate = best.coordinate;
        diagnostics.parameters = best.parameters;
        diagnostics.solution = best.solution;
        diagnostics.X = best.solution(1:13);
        diagnostics.E = best.solution(14:22);
        diagnostics.correctorCanonicalResidualNormInf = ...
            best.correction.canonicalResidualNormInf;
        diagnostics.canonicalResidualNormInf = ...
            best.timingValidation.canonicalResidualNormInf;
        diagnostics.coordinateConstraintResidual = ...
            best.correction.coordinateResidual;
        diagnostics.multiplierResidual = best.signedValue;
        diagnostics.criticalMultiplierUncertainty = ...
            best.mode.criticalMultiplierUncertainty;
        diagnostics.criticalMultiplierUncertaintyTolerance = ...
            options.CriticalMultiplierUncertaintyTolerance;
        diagnostics.richardsonFrobeniusMatrixErrorEstimate = ...
            best.mode.richardsonFrobeniusErrorEstimate;
        diagnostics.multiplier = best.mode.representativeMultiplier;
        diagnostics.criticalMultipliers = best.mode.selectedMultipliers;
        diagnostics.refinementMultipliers = best.mode.residualMultipliers;
        diagnostics.excludedTargetIndex = ...
            best.mode.excludedTargetIndex;
        diagnostics.excludedTargetValue = ...
            best.mode.excludedTargetMultiplier;
        diagnostics.excludedTargetOverlap = ...
            best.mode.excludedTargetOverlap;
        diagnostics.excludedTargetOverlapGap = ...
            best.mode.excludedTargetOverlapGap;
        diagnostics.criticalEigenvector = best.mode.representativeEigenvector;
        diagnostics.criticalSubspace = best.mode.basis;
        diagnostics.criticalRealInvariantSubspace = ...
            best.mode.realInvariantSubspace;
        diagnostics.modeDiagnostics = best.mode;
        diagnostics.floquetMatrix = best.matrix;
        diagnostics.multipliers = best.multipliers;
        diagnostics.eigenvectors = best.eigenvectors;
        diagnostics.floquetDiagnostics = best.floquetDiagnostics;
        diagnostics.periodicValidation = ...
            FirstField(best.floquetDiagnostics, {'baseValidation'}, struct());
        diagnostics.timingValidation = best.timingValidation;
        diagnostics.authoritativeSolvedEventTimes = ...
            best.authoritativeSolvedEventTimes;
        diagnostics.topology = best.topology;
        diagnostics.topologyComparison = best.topologyComparison;
        [diagnostics.localBranchTangent, ...
            diagnostics.localBranchTangentDiagnostics] = ...
            LocalReducedBranchTangent(left, right);
        [diagnostics.eigenData, diagnostics.branchSwitchReady, ...
            diagnostics.branchSwitchReadyReason, ...
            diagnostics.branchSwitchReadinessDiagnostics] = ...
            PredictorReadyData(best, candidate, ...
                diagnostics.localBranchTangent, options);
    catch exception
        solution = [];
        diagnostics.accepted = false;
        diagnostics.valid = false;
        diagnostics.status = 'rejected';
        diagnostics.rejectionReasons{end + 1} = sprintf( ...
            '%s: %s', exception.identifier, exception.message);
        diagnostics.exceptionIdentifier = exception.identifier;
        diagnostics.exceptionMessage = exception.message;
        if throwOnFailure
            rethrow(exception);
        end
    end
end

function diagnostics = InitialDiagnostics()
    diagnostics = struct();
    diagnostics.accepted = false;
    diagnostics.valid = false;
    diagnostics.status = 'not-evaluated';
    diagnostics.rejectionReasons = {};
    diagnostics.exceptionIdentifier = '';
    diagnostics.exceptionMessage = '';
    diagnostics.options = struct();
    diagnostics.candidate = struct();
    diagnostics.inputMode = '';
    diagnostics.resolvedBranchIndices = [];
    diagnostics.indexMapping = struct();
    diagnostics.inputBracket = [];
    diagnostics.referenceTopology = struct();
    diagnostics.endpointTopology = struct();
    diagnostics.target = struct();
    diagnostics.branchSwitchReady = false;
    diagnostics.branchSwitchReadyReason = ...
        'No accepted refined critical orbit is available.';
    diagnostics.branchSwitchReadinessDiagnostics = struct();
    diagnostics.eigenData = [];
    diagnostics.localBranchTangent = [];
    diagnostics.localBranchTangentDiagnostics = struct();
    diagnostics.history = repmat(EmptyHistory(), 1, 0);
    diagnostics.bracketHistory = zeros(0, 4);
end

function [problem, candidate, options] = ParseInvocation(varargin)
    count = numel(varargin);
    if count == 2 || count == 3
        problem = struct('mode', 'branch', 'branch', varargin{1});
        candidate = varargin{2};
        if count == 3
            options = varargin{3};
        else
            options = struct();
        end
    elseif count == 4 || count == 5
        problem = struct('mode', 'explicit-endpoints', ...
            'left', varargin{1}, 'right', varargin{2}, ...
            'parameters', varargin{3});
        candidate = varargin{4};
        if count == 5
            options = varargin{5};
        else
            options = struct();
        end
    else
        error('RefineCriticalOrbit:Invocation', ...
            ['Use (branch,candidate,options) or ' ...
             '(zLeft,zRight,parameters,candidate,options).']);
    end
    if ~isstruct(candidate) || ~isscalar(candidate)
        error('RefineCriticalOrbit:Candidate', ...
            'candidate must be one scalar DetectBifurcation candidate struct.');
    end
end

function options = ParseOptions(user)
    if nargin < 1 || isempty(user)
        user = struct();
    end
    if ~isstruct(user) || ~isscalar(user)
        error('RefineCriticalOrbit:Options', ...
            'options must be a scalar struct.');
    end
    options = struct();
    options.SampleIndices = [];
    options.BracketIndices = [];
    options.RequireAdjacentBranchPoints = true;
    options.IndexCoordinateTolerance = 1e-8;
    options.Constraints = {};
    options.ContinuationParameterRow = 1;
    options.ContinuationParameterName = '';
    options.ContinuationCoordinateFunction = [];
    options.ParentCorrector = [];
    options.FloquetOptions = struct();
    options.FsolveOptions = DefaultFsolveOptions();
    options.CorrectEndpoints = true;
    options.AllowParameterInterpolation = false;
    options.ParameterTolerance = 1e-12;
    options.ResidualTolerance = 1e-8;
    options.CoordinateConstraintTolerance = 1e-9;
    options.CoordinateConstraintWeight = 1;
    options.CoordinateScale = [];
    options.ParentJacobianRankTolerance = 1e-9;
    options.MultiplierTolerance = 1e-6;
    options.CriticalMultiplierUncertaintyTolerance = [];
    options.CoordinateTolerance = 1e-6;
    options.MaxIterations = 20;
    options.SecantGuardFraction = 0.1;
    options.MinimumModeOverlap = 0.5;
    options.MinimumSubspaceOverlap = 0.5;
    options.DegenerateEigenvalueTolerance = 1e-6;
    options.ClusterSpreadTolerance = 1e-5;
    options.TargetSearchRadius = 0.25;
    options.TargetSubspace = [];
    options.ExcludedTargetDirection = [];
    options.MinimumExcludedTargetOverlap = 0.5;
    options.MaximumSubspaceDimension = 4;
    options.ModeEigenvalueWeight = 0.1;
    options.ModeAmbiguityTolerance = 1e-4;
    options.ImaginaryTolerance = 1e-7;
    options.ComplexPairTolerance = 1e-5;
    options.EventTimeAgreementTolerance = 1e-7;
    options.MaximumBranchTangentOverlap = 0.9;
    options.MinimumBranchTangentNullProjection = 0.99;
    options.ReferenceTopology = [];
    options.StoreFullFloquetDiagnostics = false;
    options.ThrowOnFailure = false;

    supplied = fieldnames(user);
    allowed = fieldnames(options);
    for i = 1:numel(supplied)
        hit = find(strcmpi(supplied{i}, allowed), 1);
        if isempty(hit)
            error('RefineCriticalOrbit:UnknownOption', ...
                'Unknown option "%s".', supplied{i});
        end
        options.(allowed{hit}) = user.(supplied{i});
    end
    if isempty(options.CriticalMultiplierUncertaintyTolerance)
        options.CriticalMultiplierUncertaintyTolerance = ...
            options.MultiplierTolerance;
    end

    logicalNames = {'RequireAdjacentBranchPoints', 'CorrectEndpoints', ...
        'AllowParameterInterpolation', ...
        'StoreFullFloquetDiagnostics', 'ThrowOnFailure'};
    for i = 1:numel(logicalNames)
        value = options.(logicalNames{i});
        if ~(isscalar(value) && (islogical(value) || ...
                (isnumeric(value) && any(value == [0 1]))))
            error('RefineCriticalOrbit:LogicalOption', ...
                '%s must be a scalar logical.', logicalNames{i});
        end
        options.(logicalNames{i}) = logical(value);
    end
    positive = {'IndexCoordinateTolerance', 'ParameterTolerance', ...
        'ResidualTolerance', ...
        'CoordinateConstraintTolerance', 'CoordinateConstraintWeight', ...
        'ParentJacobianRankTolerance', ...
        'MultiplierTolerance', 'CoordinateTolerance', ...
        'CriticalMultiplierUncertaintyTolerance', ...
        'MinimumModeOverlap', 'MinimumSubspaceOverlap', ...
        'DegenerateEigenvalueTolerance', 'ClusterSpreadTolerance', ...
        'TargetSearchRadius', 'ModeEigenvalueWeight', ...
        'MinimumExcludedTargetOverlap', ...
        'ModeAmbiguityTolerance', 'ImaginaryTolerance', ...
        'ComplexPairTolerance', 'EventTimeAgreementTolerance', ...
        'MaximumBranchTangentOverlap', ...
        'MinimumBranchTangentNullProjection'};
    for i = 1:numel(positive)
        value = options.(positive{i});
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value > 0)
            error('RefineCriticalOrbit:PositiveOption', ...
                '%s must be a positive finite scalar.', positive{i});
        end
    end
    if options.MinimumModeOverlap > 1 || options.MinimumSubspaceOverlap > 1 || ...
            options.MinimumExcludedTargetOverlap > 1
        error('RefineCriticalOrbit:OverlapOption', ...
            'Mode/subspace/excluded-direction overlaps must not exceed one.');
    end
    if options.MaximumBranchTangentOverlap > 1 || ...
            options.MinimumBranchTangentNullProjection > 1
        error('RefineCriticalOrbit:BranchTangentOverlapOption', ...
            'Branch-tangent overlap/projection thresholds must not exceed one.');
    end
    if ~(isscalar(options.MaxIterations) && options.MaxIterations >= 1 && ...
            options.MaxIterations == floor(options.MaxIterations))
        error('RefineCriticalOrbit:MaxIterations', ...
            'MaxIterations must be a positive integer.');
    end
    if ~(isscalar(options.MaximumSubspaceDimension) && ...
            options.MaximumSubspaceDimension >= 1 && ...
            options.MaximumSubspaceDimension == ...
                floor(options.MaximumSubspaceDimension))
        error('RefineCriticalOrbit:MaximumSubspaceDimension', ...
            'MaximumSubspaceDimension must be a positive integer.');
    end
    if ~(isscalar(options.SecantGuardFraction) && ...
            isfinite(options.SecantGuardFraction) && ...
            options.SecantGuardFraction > 0 && ...
            options.SecantGuardFraction < 0.5)
        error('RefineCriticalOrbit:SecantGuardFraction', ...
            'SecantGuardFraction must lie strictly between zero and 0.5.');
    end
    if ~isempty(options.CoordinateScale) && ...
            ~(isscalar(options.CoordinateScale) && ...
              isfinite(options.CoordinateScale) && options.CoordinateScale > 0)
        error('RefineCriticalOrbit:CoordinateScale', ...
            'CoordinateScale must be empty or a positive finite scalar.');
    end
    row = options.ContinuationParameterRow;
    if ~(isnumeric(row) && isscalar(row) && isfinite(row) && ...
            row == floor(row) && row >= 1 && row <= 13 && row ~= 3)
        error('RefineCriticalOrbit:ContinuationParameterRow', ...
            'ContinuationParameterRow must be an X row in [1 2 4:13].');
    end
    for name = {'ContinuationCoordinateFunction','ParentCorrector'}
        value = options.(name{1});
        if ~isempty(value) && ~isa(value,'function_handle')
            error('RefineCriticalOrbit:CoordinateCallback', ...
                '%s must be empty or a function handle.', name{1});
        end
    end
    if isempty(options.ContinuationParameterName)
        if ~isempty(options.ContinuationCoordinateFunction)
            options.ContinuationParameterName = 'custom physical coordinate';
        elseif row == 1
            options.ContinuationParameterName = 'dx';
        else
            options.ContinuationParameterName = sprintf('X(%d)',row);
        end
    elseif ~(ischar(options.ContinuationParameterName) || ...
            (isstring(options.ContinuationParameterName) && ...
             isscalar(options.ContinuationParameterName)))
        error('RefineCriticalOrbit:ContinuationParameterName', ...
            'ContinuationParameterName must be a character vector or scalar string.');
    end
    options.ContinuationParameterName = char(options.ContinuationParameterName);
    if ~isstruct(options.FloquetOptions) || ~isscalar(options.FloquetOptions)
        error('RefineCriticalOrbit:FloquetOptions', ...
            'FloquetOptions must be a scalar struct.');
    end
    if ~(iscell(options.Constraints) || isstruct(options.Constraints))
        error('RefineCriticalOrbit:Constraints', ...
            'Constraints must be a cell array or accepted constraint struct.');
    end
    if ~isempty(options.TargetSubspace) && ...
            (~isnumeric(options.TargetSubspace) || ...
             size(options.TargetSubspace, 1) ~= 12 || ...
             any(~isfinite(options.TargetSubspace(:))))
        error('RefineCriticalOrbit:TargetSubspace', ...
            'TargetSubspace must be empty or a finite 12-by-r matrix.');
    end
    if ~isempty(options.ExcludedTargetDirection) && ...
            (~isnumeric(options.ExcludedTargetDirection) || ...
             ~isvector(options.ExcludedTargetDirection) || ...
             numel(options.ExcludedTargetDirection) ~= 12 || ...
             ~isreal(options.ExcludedTargetDirection) || ...
             any(~isfinite(options.ExcludedTargetDirection(:))) || ...
             norm(options.ExcludedTargetDirection(:)) == 0)
        error('RefineCriticalOrbit:ExcludedTargetDirection', ...
            ['ExcludedTargetDirection must be empty or a nonzero finite ' ...
             'real 12-vector.']);
    end
    if ~isempty(options.BracketIndices) && ...
            ~(isnumeric(options.BracketIndices) && ...
              numel(options.BracketIndices) == 2)
        error('RefineCriticalOrbit:BracketIndices', ...
            'BracketIndices must be empty or contain exactly two indices.');
    end
end

function value = DefaultFsolveOptions()
    value = optimset('Algorithm', 'levenberg-marquardt', ...
        'ScaleProblem', 'jacobian', 'Display', 'off', ...
        'MaxFunEvals', 20000, 'MaxIter', 3000, ...
        'TolFun', 1e-11, 'TolX', 1e-12);
end

function [left, right, mapping] = ResolveProblem(problem, candidate, options)
    if strcmp(problem.mode, 'explicit-endpoints')
        zLeft = ValidateSolution(problem.left, 'left');
        zRight = ValidateSolution(problem.right, 'right');
        parameters = ValidateEndpointParameters(problem.parameters);
        left = MakeEndpoint(zLeft, parameters(:, 1), options);
        right = MakeEndpoint(zRight, parameters(:, 2), options);
        mapping = struct('method', 'explicit-endpoints', ...
            'branchIndices', [], 'sampleIndices', [], ...
            'candidateLocalIndices', CandidateLocalIndices(candidate));
        VerifyCandidateBracket(candidate, [left.coordinate, right.coordinate], ...
            options.IndexCoordinateTolerance);
        return
    end

    [results, sampleIndices, source] = ExtractResults(problem.branch, options);
    if ~isnumeric(results) || size(results, 1) ~= 29 || isempty(results)
        error('RefineCriticalOrbit:ResultsShape', ...
            'Branch results must be a nonempty 29-by-N numeric array.');
    end
    stateRows = results(1:22, :);
    if any(~isfinite(stateRows(:)))
        error('RefineCriticalOrbit:NonfiniteResults', ...
            'Branch state/event-time entries must be finite.');
    end

    [indices, method] = ResolveBranchIndices( ...
        results, sampleIndices, candidate, options);
    if options.RequireAdjacentBranchPoints && abs(diff(indices)) ~= 1
        error('RefineCriticalOrbit:NonadjacentBracket', ...
            ['Resolved branch columns %d and %d are not adjacent. Refine ' ...
             'the continuation branch or explicitly disable this check.'], ...
            indices(1), indices(2));
    end
    left = MakeEndpoint(results(1:22, indices(1)), ...
        results(23:29, indices(1)), options);
    right = MakeEndpoint(results(1:22, indices(2)), ...
        results(23:29, indices(2)), options);
    VerifyCandidateBracket(candidate, [left.coordinate, right.coordinate], ...
        options.IndexCoordinateTolerance);
    mapping = struct('method', method, 'source', source, ...
        'branchIndices', indices, 'sampleIndices', sampleIndices, ...
        'candidateLocalIndices', CandidateLocalIndices(candidate));
end

function endpoint = MakeEndpoint(solution, parameters, options)
    endpoint = struct('solution', ValidateSolution(solution, 'endpoint'), ...
        'parameters', ValidateParameters(parameters), ...
        'coordinate', PhysicalCoordinate(solution, options));
end

function [results, sampleIndices, source] = ExtractResults(input, options)
    sampleIndices = options.SampleIndices(:).';
    source = 'numeric input';
    if isnumeric(input)
        results = input;
        return
    end
    if ~isstruct(input) || ~isscalar(input)
        error('RefineCriticalOrbit:BranchInput', ...
            'Branch input must be numeric or a scalar struct.');
    end
    source = 'struct input';
    results = FirstField(input, {'results', 'Results'}, []);
    if isempty(sampleIndices)
        sampleIndices = FirstField(input, ...
            {'sampleIndices', 'SampleIndices'}, []);
        sampleIndices = sampleIndices(:).';
    end
    if isempty(results)
        filename = FirstField(input, ...
            {'branchFile', 'BranchFile', 'filename', 'Filename'}, '');
        if isempty(filename) || ~isfile(filename)
            error('RefineCriticalOrbit:MissingResults', ...
                'The branch struct has neither results nor a valid branchFile.');
        end
        loaded = load(filename, 'results');
        if ~isfield(loaded, 'results')
            error('RefineCriticalOrbit:MissingResultsVariable', ...
                'Branch file %s does not contain results.', filename);
        end
        results = loaded.results;
        source = char(filename);
    end
end

function [indices, method] = ResolveBranchIndices( ...
        results, sampleIndices, candidate, options)
    count = size(results, 2);
    coordinates = zeros(1,count);
    for column = 1:count
        coordinates(column) = PhysicalCoordinate(results(1:22,column),options);
    end
    local = CandidateLocalIndices(candidate);
    bracket = CandidateBracket(candidate);

    if ~isempty(options.BracketIndices)
        indices = ValidateIndices(options.BracketIndices, count);
        method = 'explicit BracketIndices';
        return
    end
    if ~isempty(sampleIndices)
        if isempty(local) || any(local > numel(sampleIndices))
            error('RefineCriticalOrbit:SampleIndexMap', ...
                'Candidate local indices cannot be mapped by SampleIndices.');
        end
        mapped = sampleIndices(local);
        % A full branch uses mapped columns; a sampled branch already has
        % local columns. Coordinate consistency decides safely.
        if all(mapped >= 1 & mapped <= count) && ...
                CoordinatesMatch(coordinates(mapped), bracket, ...
                    options.IndexCoordinateTolerance)
            indices = ValidateIndices(mapped, count);
            method = 'sampleIndices to full branch';
            return
        elseif all(local <= count) && ...
                CoordinatesMatch(coordinates(local), bracket, ...
                    options.IndexCoordinateTolerance)
            indices = ValidateIndices(local, count);
            method = 'sampled branch local indices';
            return
        else
            error('RefineCriticalOrbit:UnsafeSampleIndexMap', ...
                ['Neither mapped nor local SampleIndices reproduce the ' ...
                 'candidate coordinate bracket.']);
        end
    end
    if ~isempty(local) && all(local <= count) && ...
            CoordinatesMatch(coordinates(local), bracket, ...
                options.IndexCoordinateTolerance)
        indices = ValidateIndices(local, count);
        method = 'verified direct candidate indices';
        return
    end
    if isempty(bracket)
        error('RefineCriticalOrbit:UnmappedCandidate', ...
            ['Candidate indices do not map directly and Candidate.Bracket is ' ...
             'unavailable. Supply SampleIndices or BracketIndices.']);
    end
    indices = zeros(1, 2);
    for side = 1:2
        scale = 1 + abs(bracket(side));
        hits = find(abs(coordinates - bracket(side)) <= ...
            options.IndexCoordinateTolerance * scale);
        if numel(hits) ~= 1
            error('RefineCriticalOrbit:AmbiguousCoordinateMap', ...
                ['Candidate bracket coordinate %.16g matched %d branch ' ...
                 'columns. Supply BracketIndices explicitly.'], ...
                bracket(side), numel(hits));
        end
        indices(side) = hits;
    end
    indices = ValidateIndices(indices, count);
    method = 'unique candidate-coordinate match';
end

function indices = ValidateIndices(indices, count)
    indices = indices(:).';
    if numel(indices) ~= 2 || any(~isfinite(indices)) || ...
            any(indices ~= floor(indices)) || any(indices < 1) || ...
            any(indices > count) || indices(1) == indices(2)
        error('RefineCriticalOrbit:BranchIndices', ...
            'Resolved branch indices must be two distinct columns in range.');
    end
end

function local = CandidateLocalIndices(candidate)
    left = FirstField(candidate, {'LeftIndex', 'leftIndex'}, []);
    right = FirstField(candidate, {'RightIndex', 'rightIndex'}, []);
    if isempty(left) || isempty(right)
        local = [];
    else
        local = [left, right];
        if any(~isfinite(local)) || any(local ~= floor(local)) || any(local < 1)
            error('RefineCriticalOrbit:CandidateIndices', ...
                'Candidate LeftIndex/RightIndex must be positive integers.');
        end
    end
end

function bracket = CandidateBracket(candidate)
    bracket = FirstField(candidate, {'Bracket', 'bracket'}, []);
    if isempty(bracket)
        left = FirstField(candidate, {'LeftCoordinate'}, []);
        right = FirstField(candidate, {'RightCoordinate'}, []);
        if ~isempty(left) && ~isempty(right)
            bracket = [left, right];
        end
    end
    if ~isempty(bracket)
        bracket = bracket(:).';
        if numel(bracket) ~= 2 || any(~isfinite(bracket)) || ~isreal(bracket)
            error('RefineCriticalOrbit:CandidateBracket', ...
                'Candidate Bracket must contain two finite real coordinates.');
        end
    end
end

function tf = CoordinatesMatch(values, bracket, tolerance)
    if isempty(bracket) || numel(values) ~= 2
        tf = false;
        return
    end
    scale = 1 + abs(bracket);
    tf = all(abs(values(:).' - bracket(:).') <= tolerance .* scale);
end

function VerifyCandidateBracket(candidate, coordinates, tolerance)
    bracket = CandidateBracket(candidate);
    if ~isempty(bracket) && ~CoordinatesMatch(coordinates, bracket, tolerance)
        error('RefineCriticalOrbit:BracketMismatch', ...
            ['Resolved orbit coordinates [%.16g %.16g] do not match the ' ...
             'candidate bracket [%.16g %.16g].'], coordinates, bracket);
    end
end

function solution = ValidateSolution(solution, label)
    solution = solution(:);
    if numel(solution) ~= 22 || any(~isfinite(solution)) || ~isreal(solution)
        error('RefineCriticalOrbit:Solution', ...
            '%s solution must be a finite real 22-vector.', label);
    end
    if solution(22) <= 0
        error('RefineCriticalOrbit:Period', ...
            '%s solution must have a positive apex period.', label);
    end
end

function parameters = ValidateEndpointParameters(parameters)
    if isvector(parameters) && numel(parameters) == 7
        parameters = repmat(parameters(:), 1, 2);
    elseif isequal(size(parameters), [2, 7])
        parameters = parameters.';
    end
    if ~isequal(size(parameters), [7, 2])
        error('RefineCriticalOrbit:EndpointParameters', ...
            'parameters must be a shared 7-vector or a 7-by-2 matrix.');
    end
    parameters(:, 1) = ValidateParameters(parameters(:, 1));
    parameters(:, 2) = ValidateParameters(parameters(:, 2));
end

function parameters = ValidateParameters(parameters)
    parameters = parameters(:);
    valid = numel(parameters) == 7 && ...
        all(isfinite(parameters) | ...
            (((1:7).' == 3) & isinf(parameters) & parameters > 0));
    if ~valid
        error('RefineCriticalOrbit:Parameters', ...
            ['Parameters must contain seven values; only the third value ' ...
             'may be positive Inf.']);
    end
end

function [left, right] = SortEndpoints(left, right)
    if left.coordinate > right.coordinate
        temporary = left;
        left = right;
        right = temporary;
    end
end

function [left, right] = SortEvaluations(left, right)
    if left.coordinate > right.coordinate
        temporary = left;
        left = right;
        right = temporary;
    end
end

function ValidateParameterVariation(left, right, options)
    finite = isfinite(left) & isfinite(right);
    infiniteMatch = all(isinf(left(~finite)) & isinf(right(~finite)) & ...
        sign(left(~finite)) == sign(right(~finite)));
    scale = 1 + max(abs([left(finite), right(finite)]), [], 2);
    if isempty(scale)
        finiteMatch = true;
    else
        finiteMatch = all(abs(left(finite) - right(finite)) <= ...
            options.ParameterTolerance .* scale);
    end
    if ~(finiteMatch && infiniteMatch) && ...
            ~options.AllowParameterInterpolation
        error('RefineCriticalOrbit:VaryingParameters', ...
            ['Endpoint physical parameters differ. Fixed-coordinate orbit refinement ' ...
             'does not define their continuation law; either provide shared ' ...
             'parameters or explicitly set AllowParameterInterpolation=true.']);
    end
end

function [reference, endpoint] = ResolveReferenceTopology( ...
        leftE, rightE, floquetOptions, supplied)
    left = floquet.internal.events.classifyTopology(leftE, floquetOptions);
    right = floquet.internal.events.classifyTopology(rightE, floquetOptions);
    if ~left.valid || ~right.valid
        error('RefineCriticalOrbit:EndpointTopology', ...
            'Both endpoint event topologies must be valid.');
    end
    if isempty(supplied)
        reference = left;
    else
        reference = supplied;
        if ~isstruct(reference) || ~isfield(reference, 'valid') || ...
                ~reference.valid
            error('RefineCriticalOrbit:ReferenceTopology', ...
                'ReferenceTopology must be a valid topology struct.');
        end
    end
    leftComparison = floquet.internal.events.compareTopology( ...
        reference, left, floquetOptions);
    rightComparison = floquet.internal.events.compareTopology( ...
        reference, right, floquetOptions);
    if ~leftComparison.consistent || ~rightComparison.consistent
        error('RefineCriticalOrbit:EndpointTopologyMismatch', ...
            'The two bracket endpoints do not preserve the reference topology.');
    end
    endpoint = struct('left', left, 'right', right, ...
        'leftComparison', leftComparison, 'rightComparison', rightComparison);
end

function evaluation = EvaluateOrbit(coordinate, guess, parameters, ...
        referenceTopology, floquetOptions, options, source, correct)
    evaluation = EmptyEvaluation();
    evaluation.coordinate = coordinate;
    evaluation.parameters = parameters;
    evaluation.source = source;
    if correct
        [corrected, correction] = CorrectAtCoordinate( ...
            guess, parameters, coordinate, referenceTopology, ...
            floquetOptions, options);
    else
        corrected = guess(:);
        correction = ValidateUncorrected(corrected, parameters, coordinate, ...
            referenceTopology, floquetOptions, options);
    end
    evaluation.correction = correction;
    if ~correction.accepted
        evaluation.rejectionReasons = correction.rejectionReasons;
        return
    end
    try
        [matrix, multipliers, eigenvectors, floquetDiagnostics] = ...
            floquet.computeFDM(corrected, parameters, floquetOptions);
    catch exception
        evaluation.exception = exception;
        evaluation.rejectionReasons{end + 1} = sprintf( ...
            'ComputeFloquetFDM failed: %s', exception.message);
        return
    end
    evaluation.floquetDiagnostics = floquetDiagnostics;
    if isempty(matrix) || ~isstruct(floquetDiagnostics) || ...
            ~isfield(floquetDiagnostics, 'accepted') || ...
            ~floquetDiagnostics.accepted
        reasons = FirstField(floquetDiagnostics, {'rejectionReasons'}, ...
            {'Floquet computation was rejected.'});
        evaluation.rejectionReasons = [evaluation.rejectionReasons, reasons];
        return
    end
    if ~isequal(size(matrix), [12 12]) || numel(multipliers) ~= 12 || ...
            ~isequal(size(eigenvectors), [12 12])
        evaluation.rejectionReasons{end + 1} = ...
            'Floquet result does not have the reduced 12-dimensional shape.';
        return
    end
    try
        [coarseMatrix, coarseMultipliers, coarseEigenvectors, ...
            richardsonFrobeniusError] = ...
            ExtractCoarseFloquet(floquetDiagnostics);
    catch exception
        evaluation.exception = exception;
        evaluation.rejectionReasons{end + 1} = sprintf( ...
            'Critical-mode uncertainty data are unavailable: %s', ...
            exception.message);
        return
    end
    [authoritative, timingValidation] = ValidateAuthoritativeTiming( ...
        corrected, parameters, coordinate, floquetDiagnostics, referenceTopology, ...
        floquetOptions, options);
    evaluation.timingValidation = timingValidation;
    if ~timingValidation.accepted
        evaluation.rejectionReasons = [evaluation.rejectionReasons, ...
            timingValidation.rejectionReasons];
        return
    end
    evaluation.solution = authoritative;
    evaluation.authoritativeSolvedEventTimes = authoritative(14:22);
    evaluation.topology = timingValidation.topology;
    evaluation.topologyComparison = timingValidation.topologyComparison;
    evaluation.correction.authoritativeCanonicalResidual = ...
        timingValidation.canonicalResidual;
    evaluation.correction.authoritativeCanonicalResidualNormInf = ...
        timingValidation.canonicalResidualNormInf;
    evaluation.matrix = matrix;
    evaluation.multipliers = multipliers(:);
    evaluation.eigenvectors = eigenvectors;
    evaluation.coarseMatrix = coarseMatrix;
    evaluation.coarseMultipliers = coarseMultipliers;
    evaluation.coarseEigenvectors = coarseEigenvectors;
    evaluation.richardsonFrobeniusErrorEstimate = ...
        richardsonFrobeniusError;
    evaluation.accepted = true;
end

function [matrix, multipliers, eigenvectors, richardsonError] = ...
        ExtractCoarseFloquet(floquetDiagnostics)
    central = FirstField(floquetDiagnostics, ...
        {'centralDerivativeMatrices'}, []);
    if ~isnumeric(central) || ndims(central) ~= 3 || ...
            ~isequal(size(central, 1), 12) || ...
            ~isequal(size(central, 2), 12) || size(central, 3) < 2
        error('RefineCriticalOrbit:MissingCoarseFloquet', ...
            'At least two 12-by-12 central derivative levels are required.');
    end
    matrix = central(:, :, end - 1);
    if any(~isfinite(matrix(:)))
        error('RefineCriticalOrbit:NonfiniteCoarseFloquet', ...
            'The penultimate central derivative matrix is nonfinite.');
    end
    [eigenvectors, values] = eig(matrix);
    multipliers = diag(values);
    if any(~isfinite(real(multipliers))) || ...
            any(~isfinite(imag(multipliers))) || ...
            any(~isfinite(real(eigenvectors(:)))) || ...
            any(~isfinite(imag(eigenvectors(:))))
        error('RefineCriticalOrbit:CoarseEigensystem', ...
            'The penultimate central derivative eigensystem is nonfinite.');
    end
    convergence = FirstField(floquetDiagnostics, ...
        {'derivativeConvergence'}, struct());
    richardsonError = FirstField(convergence, ...
        {'richardsonFrobeniusErrorEstimate'}, NaN);
    if ~(isnumeric(richardsonError) && isscalar(richardsonError) && ...
            isfinite(richardsonError) && richardsonError >= 0)
        error('RefineCriticalOrbit:RichardsonEstimate', ...
            'A finite nonnegative Richardson Frobenius estimate is required.');
    end
end

function [solution, validation] = ValidateAuthoritativeTiming( ...
        corrected, parameters, coordinate, floquetDiagnostics, referenceTopology, ...
        floquetOptions, options)
    validation = struct('accepted', false, 'rejectionReasons', {{}}, ...
        'solvedEventTimes', [], 'correctedEventTimes', corrected(14:22), ...
        'circularDifference', [], 'agreementErrorNormInf', Inf, ...
        'agreementTolerance', NaN, 'canonicalResidual', [], ...
        'coordinateResidual', Inf, ...
        'canonicalResidualNormInf', Inf, 'topology', struct(), ...
        'topologyComparison', struct(), 'periodicValidation', struct());
    solution = [];
    baseValidation = FirstField(floquetDiagnostics, ...
        {'baseValidation'}, struct());
    validation.periodicValidation = baseValidation;
    mapInfo = FirstField(baseValidation, {'mapInfo'}, struct());
    solved = FirstField(mapInfo, {'solvedEventTimes'}, []);
    solved = solved(:);
    if numel(solved) ~= 9 || any(~isfinite(solved)) || solved(9) <= 0
        validation.rejectionReasons{end + 1} = ...
            'Normal timing solver did not report nine valid solved event times.';
        return
    end
    validation.solvedEventTimes = solved;
    difference = CircularEventDifference(solved, corrected(14:22));
    tolerance = options.EventTimeAgreementTolerance * max(1, solved(9));
    validation.circularDifference = difference;
    validation.agreementErrorNormInf = norm(difference, inf);
    validation.agreementTolerance = tolerance;
    if validation.agreementErrorNormInf > tolerance
        validation.rejectionReasons{end + 1} = sprintf( ...
            ['Canonical corrected event times disagree with the normal timing ' ...
             'solver by %.3e (tolerance %.3e).'], ...
            validation.agreementErrorNormInf, tolerance);
        return
    end

    solution = corrected(:);
    solution(14:22) = solved;
    try
        canonical = CanonicalResidual(solution, parameters, options.Constraints);
        validation.coordinateResidual = PhysicalCoordinate(solution,options) - coordinate;
        [topology, comparison] = ValidateTopology( ...
            solved, referenceTopology, floquetOptions);
    catch exception
        validation.rejectionReasons{end + 1} = sprintf( ...
            'Authoritative timing validation failed: %s', exception.message);
        solution = [];
        return
    end
    validation.canonicalResidual = canonical;
    validation.canonicalResidualNormInf = norm(canonical, inf);
    validation.topology = topology;
    validation.topologyComparison = comparison;
    if validation.canonicalResidualNormInf > options.ResidualTolerance
        validation.rejectionReasons{end + 1} = sprintf( ...
            ['Canonical residual with authoritative solved event times is ' ...
             '%.3e (tolerance %.3e).'], ...
            validation.canonicalResidualNormInf, options.ResidualTolerance);
    end
    if abs(validation.coordinateResidual) > options.CoordinateConstraintTolerance
        validation.rejectionReasons{end + 1} = sprintf( ...
            'Authoritative solved timing changes the %s coordinate by %.3e.', ...
            options.ContinuationParameterName,validation.coordinateResidual);
    end
    if ~comparison.consistent
        validation.rejectionReasons = [validation.rejectionReasons, ...
            PrefixReasons(comparison.rejectionReasons, ...
                'Authoritative event topology: ')];
    end
    validation.accepted = isempty(validation.rejectionReasons);
    if ~validation.accepted
        solution = [];
    end
end

function difference = CircularEventDifference(candidate, reference)
    candidate = candidate(:);
    reference = reference(:);
    difference = candidate - reference;
    period = candidate(9);
    difference(1:8) = mod(difference(1:8) + 0.5 * period, period) - ...
        0.5 * period;
end

function [corrected, info] = CorrectAtCoordinate(guess, parameters, ...
        coordinate, referenceTopology, floquetOptions, options)
    info = EmptyCorrection();
    corrected = [];
    guess = WrapTimingState(guess(:));
    if isempty(options.ContinuationCoordinateFunction)
        guess(options.ContinuationParameterRow) = coordinate;
    end
    coordinateScale = options.CoordinateScale;
    if isempty(coordinateScale)
        coordinateScale = max(1, abs(coordinate));
    end
    objective = @(z) CorrectionResidual(z, parameters, coordinate, ...
        coordinateScale, options);
    try
        if isempty(options.ParentCorrector)
            [candidate, fval, exitflag, output, jacobian] = ...
                fsolve(objective, guess, options.FsolveOptions);
        else
            context = struct('coordinateRow', options.ContinuationParameterRow, ...
                'coordinateName', options.ContinuationParameterName, ...
                'coordinateFunction', @(z) PhysicalCoordinate(z,options), ...
                'coordinateScale', coordinateScale, ...
                'canonicalResidual', @(z) CanonicalResidual(z,parameters,options.Constraints), ...
                'fsolveOptions', options.FsolveOptions, ...
                'residualTolerance', options.ResidualTolerance, ...
                'coordinateTolerance', options.CoordinateConstraintTolerance);
            [candidate, parentInfo] = ...
                options.ParentCorrector(guess,parameters,coordinate,context);
            if ~isstruct(parentInfo) || ~isscalar(parentInfo)
                error('RefineCriticalOrbit:ParentCorrectorDiagnostics', ...
                    'ParentCorrector must return a scalar diagnostics struct.');
            end
            info.parentCorrector = parentInfo;
            exitflag = FirstField(parentInfo,{'exitflag'},NaN);
            fval = FirstField(parentInfo,{'fval'},[]);
            output = FirstField(parentInfo,{'output'},struct());
            jacobian = FirstField(parentInfo,{'jacobian'},[]);
        end
    catch exception
        info.exception = exception;
        info.rejectionReasons{end + 1} = sprintf( ...
            'Periodic-orbit corrector failed: %s', exception.message);
        return
    end
    info.exitflag = exitflag;
    info.output = output;
    info.fval = fval;
    if ~(isfinite(exitflag) && exitflag > 0)
        info.rejectionReasons{end + 1} = sprintf( ...
            'Periodic-orbit corrector exitflag was %g.', exitflag);
        return
    end
    % Preserve the legacy dx corrector exactly; an opted-in chart or parent
    % embedding must additionally demonstrate independent residual rank.
    if ~isempty(options.ParentCorrector) || ...
            options.ContinuationParameterRow ~= 1 || ...
            ~isempty(options.ContinuationCoordinateFunction)
        info.jacobianRank = CorrectionJacobianRank(jacobian,options);
        if ~info.jacobianRank.accepted
            info.rejectionReasons{end + 1} = info.jacobianRank.reason;
            return
        end
    end
    try
        candidate = WrapTimingState(ValidateSolution(candidate,'corrected'));
        canonical = CanonicalResidual(candidate, parameters, options.Constraints);
    catch exception
        info.exception = exception;
        info.rejectionReasons{end + 1} = sprintf( ...
            'Corrected candidate validation failed: %s', exception.message);
        return
    end
    info.canonicalResidual = canonical;
    info.canonicalResidualNormInf = norm(canonical, inf);
    info.coordinateResidual = PhysicalCoordinate(candidate,options) - coordinate;
    if info.canonicalResidualNormInf > options.ResidualTolerance
        info.rejectionReasons{end + 1} = sprintf( ...
            'Canonical residual %.3e exceeds %.3e.', ...
            info.canonicalResidualNormInf, options.ResidualTolerance);
    end
    if abs(info.coordinateResidual) > options.CoordinateConstraintTolerance
        info.rejectionReasons{end + 1} = sprintf( ...
            '%s residual %.3e exceeds %.3e.', ...
            options.ContinuationParameterName,abs(info.coordinateResidual), ...
            options.CoordinateConstraintTolerance);
    end
    [topology, comparison] = ValidateTopology( ...
        candidate(14:22), referenceTopology, floquetOptions);
    info.topology = topology;
    info.topologyComparison = comparison;
    if ~comparison.consistent
        info.rejectionReasons = [info.rejectionReasons, ...
            PrefixReasons(comparison.rejectionReasons, 'Event topology: ')];
    end
    info.accepted = isempty(info.rejectionReasons);
    if info.accepted
        corrected = candidate;
    end
end

function info = ValidateUncorrected(solution, parameters, coordinate, ...
        referenceTopology, floquetOptions, options)
    info = EmptyCorrection();
    try
        solution = WrapTimingState(solution);
        canonical = CanonicalResidual(solution, parameters, options.Constraints);
        info.canonicalResidual = canonical;
        info.canonicalResidualNormInf = norm(canonical, inf);
        info.coordinateResidual = PhysicalCoordinate(solution,options) - coordinate;
        [info.topology, info.topologyComparison] = ValidateTopology( ...
            solution(14:22), referenceTopology, floquetOptions);
    catch exception
        info.exception = exception;
        info.rejectionReasons{end + 1} = exception.message;
        return
    end
    if info.canonicalResidualNormInf > options.ResidualTolerance
        info.rejectionReasons{end + 1} = 'Endpoint canonical residual is too large.';
    end
    if abs(info.coordinateResidual) > options.CoordinateConstraintTolerance
        info.rejectionReasons{end + 1} = ...
            'Endpoint physical state does not match its continuation coordinate.';
    end
    if ~info.topologyComparison.consistent
        info.rejectionReasons{end + 1} = 'Endpoint topology is inconsistent.';
    end
    info.accepted = isempty(info.rejectionReasons);
end

function residual = CorrectionResidual(z, parameters, coordinate, ...
        coordinateScale, options)
    canonical = CanonicalResidual(z, parameters, options.Constraints);
    coordinateResidual = options.CoordinateConstraintWeight * ...
        (PhysicalCoordinate(z,options) - coordinate) / coordinateScale;
    residual = [canonical(:); coordinateResidual];
end

function coordinate = PhysicalCoordinate(z,options)
    z = z(:);
    if isempty(options.ContinuationCoordinateFunction)
        coordinate = z(options.ContinuationParameterRow);
    else
        coordinate = options.ContinuationCoordinateFunction(z);
    end
    if ~(isnumeric(coordinate) && isreal(coordinate) && ...
            isscalar(coordinate) && isfinite(coordinate))
        error('RefineCriticalOrbit:PhysicalCoordinate', ...
            'The physical continuation coordinate must be a finite real scalar.');
    end
end

function info = CorrectionJacobianRank(jacobian,options)
    info = struct('accepted',false,'rank',0,'numberOfUnknowns',0, ...
        'singularValues',[],'columnScale',[], ...
        'relativeTolerance',options.ParentJacobianRankTolerance,'reason','');
    if ~isnumeric(jacobian) || isempty(jacobian) || ~ismatrix(jacobian) || ...
            ~isreal(jacobian) || any(~isfinite(jacobian(:)))
        info.reason = ['The parent corrector must provide its finite real ' ...
            'independent residual Jacobian, including the coordinate equation.'];
        return
    end
    info.numberOfUnknowns = size(jacobian,2);
    columnScale = sqrt(sum(jacobian.^2,1));
    info.columnScale = columnScale;
    scaled = jacobian ./ max(columnScale,realmin);
    values = svd(scaled);
    info.singularValues = values;
    info.rank = sum(values > options.ParentJacobianRankTolerance * max(values));
    info.accepted = info.rank == info.numberOfUnknowns;
    if ~info.accepted
        info.reason = sprintf(['Parent correction Jacobian rank %d is less than ' ...
            '%d unknowns; the continuation chart is not transverse.'], ...
            info.rank,info.numberOfUnknowns);
    end
end

function residual = CanonicalResidual(z, parameters, constraints)
    z = z(:);
    if numel(z) ~= 22 || any(~isfinite(z)) || z(22) <= 0
        error('RefineCriticalOrbit:CorrectorState', ...
            'The corrector state must be a finite 22-vector with positive period.');
    end
    residual = Quadrupedal_ZeroFun_v2(z(1:13).', z(14:22).', ...
        parameters(:).', constraints, 'skipSolve');
    residual = residual(:);
    if isempty(residual) || any(~isfinite(residual))
        error('RefineCriticalOrbit:CanonicalResidual', ...
            'Canonical skipSolve residual returned nonfinite values.');
    end
end

function [topology, comparison] = ValidateTopology(E, reference, options)
    topology = floquet.internal.events.classifyTopology(E, options);
    comparison = floquet.internal.events.compareTopology( ...
        reference, topology, options);
end

function z = WrapTimingState(z)
    z = z(:);
    if numel(z) ~= 22 || ~isfinite(z(22)) || z(22) <= 0
        error('RefineCriticalOrbit:TimingState', ...
            'Timing state must have a positive finite period.');
    end
    z(14:21) = mod(z(14:21), z(22));
end

function [mode, target] = InitializeTargetMode( ...
        multipliers, eigenvectors, candidate, options)
    type = CandidateType(candidate);
    candidateVector = FirstField(candidate, ...
        {'Eigenvector', 'eigenvector'}, []);
    if isempty(candidateVector) || ~isnumeric(candidateVector) || ...
            numel(candidateVector) ~= 12 || any(~isfinite(candidateVector(:)))
        error('RefineCriticalOrbit:CandidateEigenvector', ...
            'Candidate must contain a finite 12-dimensional Eigenvector.');
    end
    candidateVector = candidateVector(:) / norm(candidateVector);

    target = struct();
    target.type = type;
    target.targetValue = TargetValue(type);
    target.dimension = 1;
    target.referenceBasis = candidateVector;
    target.autoDegenerateSubspace = false;
    target.excludedDirection = [];

    if ~isempty(options.TargetSubspace)
        basis = OrthonormalBasis(options.TargetSubspace, ...
            options.MaximumSubspaceDimension);
        target.dimension = size(basis, 2);
        target.referenceBasis = basis;
        target.autoDegenerateSubspace = target.dimension > 1;
        if ~isempty(options.ExcludedTargetDirection)
            if ~strcmp(type, '+1')
                error('RefineCriticalOrbit:ExcludedDirectionTargetType', ...
                    ['ExcludedTargetDirection is supported only for a real ' ...
                     '+1 TargetSubspace.']);
            end
            if target.dimension < 2
                error('RefineCriticalOrbit:ExcludedDirectionDimension', ...
                    ['ExcludedTargetDirection requires a TargetSubspace ' ...
                     'with dimension at least two.']);
            end
            direction = options.ExcludedTargetDirection(:);
            target.excludedDirection = direction / norm(direction);
        end
        mode = MatchTargetMode(multipliers, eigenvectors, target, ...
            EmptyModeReference(target), options);
        target.referenceBasis = mode.basis;
        target.initialCenter = mode.center;
        return
    end

    if ~isempty(options.ExcludedTargetDirection)
        error('RefineCriticalOrbit:ExcludedDirectionNeedsTargetSubspace', ...
            ['ExcludedTargetDirection requires an explicit repeated ' ...
             'TargetSubspace so the complete eigenspace remains tracked.']);
    end

    if strcmp(type, 'complex-unit-circle')
        target.dimension = 2;
        target.referenceBasis = OrthonormalBasis( ...
            [candidateVector, conj(candidateVector)], 2);
        if size(target.referenceBasis, 2) ~= 2
            error('RefineCriticalOrbit:ComplexCandidateSubspace', ...
                'Complex candidate does not define a two-dimensional pair subspace.');
        end
        mode = MatchComplexPair(multipliers, eigenvectors, target, ...
            EmptyModeReference(target), options);
        target.referenceBasis = mode.basis;
        target.initialCenter = mode.center;
        return
    end

    eligible = RealEligible(multipliers, target.targetValue, options);
    if isempty(eligible)
        error('RefineCriticalOrbit:NoInitialRealMode', ...
            'No real multiplier near the requested target was found.');
    end
    overlaps = VectorOverlaps(candidateVector, eigenvectors(:, eligible));
    [bestOverlap, location] = max(overlaps);
    if bestOverlap < options.MinimumModeOverlap
        error('RefineCriticalOrbit:InitialModeOverlap', ...
            'Best endpoint eigenvector overlap %.3f is below %.3f.', ...
            bestOverlap, options.MinimumModeOverlap);
    end
    bestIndex = eligible(location);
    bestValue = multipliers(bestIndex);
    scale = 1 + abs(bestValue);
    cluster = eligible(abs(multipliers(eligible) - bestValue) <= ...
        options.DegenerateEigenvalueTolerance * scale);
    if numel(cluster) > options.MaximumSubspaceDimension
        error('RefineCriticalOrbit:LargeDegenerateSubspace', ...
            ['The target belongs to a %d-dimensional repeated cluster; ' ...
             'MaximumSubspaceDimension is %d.'], ...
            numel(cluster), options.MaximumSubspaceDimension);
    end
    basis = OrthonormalBasis(eigenvectors(:, cluster), ...
        options.MaximumSubspaceDimension);
    if size(basis, 2) ~= numel(cluster)
        error('RefineCriticalOrbit:DefectiveTargetCluster', ...
            ['The repeated multiplier cluster is numerically defective. ' ...
             'A unique invariant subspace cannot be constructed.']);
    end
    target.dimension = numel(cluster);
    target.referenceBasis = basis;
    target.autoDegenerateSubspace = numel(cluster) > 1;
    mode = BuildMode(cluster, multipliers, eigenvectors, target, ...
        basis, bestOverlap, 0, options);
    target.referenceBasis = mode.basis;
    target.initialCenter = mode.center;
end

function evaluation = AttachCriticalModeUncertainty( ...
        evaluation, target, options)
    coarseMode = MatchTargetMode(evaluation.coarseMultipliers, ...
        evaluation.coarseEigenvectors, target, evaluation.mode, options);
    uncertainty = abs(evaluation.mode.signedValue - ...
        coarseMode.signedValue);
    if ~isfinite(uncertainty)
        error('RefineCriticalOrbit:CriticalMultiplierUncertainty', ...
            'Coarse/fine critical-mode uncertainty is nonfinite.');
    end
    evaluation.mode.coarseSignedValue = coarseMode.signedValue;
    evaluation.mode.coarseSelectedMultipliers = ...
        coarseMode.selectedMultipliers;
    evaluation.mode.coarseResidualMultipliers = ...
        coarseMode.residualMultipliers;
    evaluation.mode.coarseModeOverlap = coarseMode.overlap;
    evaluation.mode.coarseExcludedTargetIndex = ...
        coarseMode.excludedTargetIndex;
    evaluation.mode.coarseExcludedTargetMultiplier = ...
        coarseMode.excludedTargetMultiplier;
    evaluation.mode.coarseExcludedTargetOverlap = ...
        coarseMode.excludedTargetOverlap;
    evaluation.mode.coarseExcludedTargetOverlapGap = ...
        coarseMode.excludedTargetOverlapGap;
    evaluation.mode.criticalMultiplierUncertainty = uncertainty;
    evaluation.mode.criticalMultiplierUncertaintyTolerance = ...
        options.CriticalMultiplierUncertaintyTolerance;
    evaluation.mode.richardsonFrobeniusErrorEstimate = ...
        evaluation.richardsonFrobeniusErrorEstimate;
end

function mode = MatchTargetMode(multipliers, eigenvectors, target, ...
        referenceMode, options)
    if strcmp(target.type, 'complex-unit-circle')
        mode = MatchComplexPair(multipliers, eigenvectors, target, ...
            referenceMode, options);
        return
    end
    eligible = RealEligible(multipliers, target.targetValue, options);
    r = target.dimension;
    if numel(eligible) < r
        error('RefineCriticalOrbit:InsufficientTargetModes', ...
            'Only %d eligible real modes remain for a dimension-%d target.', ...
            numel(eligible), r);
    end
    combinations = nchoosek(eligible, r);
    if r == 1
        combinations = combinations(:);
    end
    referenceBasis = referenceMode.basis;
    referenceCenter = referenceMode.center;
    scores = Inf(size(combinations, 1), 1);
    overlaps = zeros(size(scores));
    bases = cell(size(scores));
    for i = 1:size(combinations, 1)
        indices = combinations(i, :);
        basis = OrthonormalBasis(eigenvectors(:, indices), r);
        if size(basis, 2) ~= r
            continue
        end
        singularValues = svd(referenceBasis' * basis);
        overlap = min(real(singularValues));
        center = mean(multipliers(indices));
        distance = abs(center - referenceCenter) / (1 + abs(referenceCenter));
        scores(i) = (1 - mean(real(singularValues))) + ...
            options.ModeEigenvalueWeight * distance;
        overlaps(i) = overlap;
        bases{i} = basis;
    end
    [bestScore, best] = min(scores);
    if ~isfinite(bestScore)
        error('RefineCriticalOrbit:TargetSubspaceMatch', ...
            'No full-rank target eigenspace could be matched.');
    end
    if overlaps(best) < options.MinimumSubspaceOverlap
        error('RefineCriticalOrbit:TargetSubspaceOverlap', ...
            'Smallest principal overlap %.3f is below %.3f.', ...
            overlaps(best), options.MinimumSubspaceOverlap);
    end
    if r == 1 && numel(scores) > 1
        ordered = sort(scores);
        if ordered(2) - ordered(1) <= options.ModeAmbiguityTolerance
            error('RefineCriticalOrbit:AmbiguousSimpleMode', ...
                ['Two simple-mode assignments have indistinguishable cost. ' ...
                 'Supply TargetSubspace for a repeated/ambiguous mode.']);
        end
    end
    indices = combinations(best, :);
    mode = BuildMode(indices, multipliers, eigenvectors, target, ...
        bases{best}, overlaps(best), bestScore, options);
end

function mode = MatchComplexPair(multipliers, eigenvectors, target, ...
        referenceMode, options)
    scale = 1 + abs(multipliers);
    positive = find(imag(multipliers) > options.ImaginaryTolerance .* scale & ...
        abs(abs(multipliers) - 1) <= options.TargetSearchRadius);
    if isempty(positive)
        error('RefineCriticalOrbit:NoComplexTarget', ...
            'No positive-imaginary multiplier near the unit circle was found.');
    end
    referenceBasis = referenceMode.basis;
    referenceCenter = referenceMode.center;
    bestCost = Inf;
    bestIndices = [];
    bestBasis = [];
    bestOverlap = 0;
    bestConjugacy = Inf;
    for i = positive(:).'
        candidates = setdiff(1:numel(multipliers), i);
        relative = abs(multipliers(candidates) - conj(multipliers(i))) ./ ...
            max(1, abs(multipliers(i)));
        [conjugacy, location] = min(relative);
        if conjugacy > options.ComplexPairTolerance
            continue
        end
        pair = [i, candidates(location)];
        basis = OrthonormalBasis(eigenvectors(:, pair), 2);
        if size(basis, 2) ~= 2
            continue
        end
        singularValues = svd(referenceBasis' * basis);
        overlap = min(real(singularValues));
        center = multipliers(i);
        distance = abs(center - referenceCenter) / (1 + abs(referenceCenter));
        cost = (1 - mean(real(singularValues))) + ...
            options.ModeEigenvalueWeight * distance;
        if cost < bestCost
            bestCost = cost;
            bestIndices = pair;
            bestBasis = basis;
            bestOverlap = overlap;
            bestConjugacy = conjugacy;
        end
    end
    if isempty(bestIndices) || bestOverlap < options.MinimumSubspaceOverlap
        error('RefineCriticalOrbit:ComplexPairMatch', ...
            ['No conjugate invariant pair met the conjugacy and principal-' ...
             'overlap requirements.']);
    end
    mode = BuildMode(bestIndices, multipliers, eigenvectors, target, ...
        bestBasis, bestOverlap, bestCost, options);
    mode.conjugacyError = bestConjugacy;
    [~, representative] = max(imag(mode.selectedMultipliers));
    mode.representativeMultiplier = mode.selectedMultipliers(representative);
    mode.representativeEigenvector = ...
        eigenvectors(:, bestIndices(representative));
end

function mode = BuildMode(indices, multipliers, eigenvectors, target, ...
        basis, overlap, cost, options)
    values = multipliers(indices);
    mode = EmptyModeReference(target);
    mode.selectedIndices = indices(:).';
    mode.selectedMultipliers = values(:);
    mode.basis = basis;
    mode.dimension = size(basis, 2);
    mode.overlap = overlap;
    mode.assignmentCost = cost;
    mode.center = mean(values);
    residualLocalIndices = 1:numel(values);
    if ~isempty(target.excludedDirection)
        excludedOverlaps = VectorOverlaps( ...
            target.excludedDirection, eigenvectors(:, indices));
        [excludedOverlap, excludedLocalIndex] = max(excludedOverlaps);
        orderedExcludedOverlaps = sort(excludedOverlaps, 'descend');
        if numel(orderedExcludedOverlaps) > 1
            excludedOverlapGap = orderedExcludedOverlaps(1) - ...
                orderedExcludedOverlaps(2);
        else
            excludedOverlapGap = excludedOverlap;
        end
        if excludedOverlap < options.MinimumExcludedTargetOverlap
            error('RefineCriticalOrbit:ExcludedDirectionOverlap', ...
                ['Best selected-eigenvector overlap with the excluded ' ...
                 'direction is %.6f, below the required %.6f.'], ...
                excludedOverlap, options.MinimumExcludedTargetOverlap);
        end
        residualLocalIndices(excludedLocalIndex) = [];
        if isempty(residualLocalIndices)
            error('RefineCriticalOrbit:EmptyResidualCluster', ...
                ['Excluding the supplied trivial direction left no ' ...
                 'multiplier for the crossing residual.']);
        end
        mode.excludedTargetLocalIndex = excludedLocalIndex;
        mode.excludedTargetIndex = indices(excludedLocalIndex);
        mode.excludedTargetMultiplier = values(excludedLocalIndex);
        mode.excludedTargetOverlap = excludedOverlap;
        mode.excludedTargetOverlapGap = excludedOverlapGap;
    end
    residualValues = values(residualLocalIndices);
    mode.residualLocalIndices = residualLocalIndices(:).';
    mode.residualIndices = indices(residualLocalIndices);
    mode.residualMultipliers = residualValues(:);
    mode.residualCenter = mean(residualValues);
    if strcmp(target.type, 'complex-unit-circle')
        signed = abs(residualValues) - 1;
        mode.signedValue = mean(signed);
        mode.clusterSpread = max(signed) - min(signed);
        mode.realInvariantSubspace = [];
    else
        signed = real(residualValues) - target.targetValue;
        mode.signedValue = mean(signed);
        mode.clusterSpread = max(signed) - min(signed);
        mode.realInvariantSubspace = RealInvariantBasis( ...
            eigenvectors(:, indices), mode.dimension);
    end
    representativeIndices = indices(residualLocalIndices);
    [~, representative] = max(VectorOverlaps(target.referenceBasis(:, 1), ...
        eigenvectors(:, representativeIndices)));
    mode.representativeMultiplier = residualValues(representative);
    mode.representativeEigenvector = ...
        eigenvectors(:, representativeIndices(representative));
    mode.clusterAccepted = mode.clusterSpread <= ...
        max(options.ClusterSpreadTolerance, ...
            10 * options.DegenerateEigenvalueTolerance);
end

function reference = EmptyModeReference(target)
    reference = struct('basis', target.referenceBasis, ...
        'center', target.targetValue, 'dimension', target.dimension, ...
        'selectedIndices', [], 'selectedMultipliers', [], ...
        'residualLocalIndices', [], 'residualIndices', [], ...
        'residualMultipliers', [], 'residualCenter', NaN, ...
        'signedValue', NaN, 'clusterSpread', NaN, 'overlap', NaN, ...
        'assignmentCost', NaN, 'representativeMultiplier', NaN, ...
        'representativeEigenvector', [], 'clusterAccepted', false, ...
        'conjugacyError', NaN, 'realInvariantSubspace', [], ...
        'excludedTargetLocalIndex', NaN, ...
        'excludedTargetIndex', NaN, ...
        'excludedTargetMultiplier', NaN, ...
        'excludedTargetOverlap', NaN, ...
        'excludedTargetOverlapGap', NaN, ...
        'coarseSignedValue', NaN, 'coarseSelectedMultipliers', [], ...
        'coarseResidualMultipliers', [], ...
        'coarseExcludedTargetIndex', NaN, ...
        'coarseExcludedTargetMultiplier', NaN, ...
        'coarseExcludedTargetOverlap', NaN, ...
        'coarseExcludedTargetOverlapGap', NaN, ...
        'coarseModeOverlap', NaN, 'criticalMultiplierUncertainty', Inf, ...
        'criticalMultiplierUncertaintyTolerance', NaN, ...
        'richardsonFrobeniusErrorEstimate', Inf);
    if strcmp(target.type, 'complex-unit-circle')
        reference.center = FirstComplexReference(target.referenceBasis);
    end
end

function basis = RealInvariantBasis(vectors, dimension)
    % The rank test is deliberately independent of an arbitrary
    % complex phase on individual eigenvectors.  A nearly-real conjugate
    % cluster can have intrinsically complex eigenvectors while its invariant
    % subspace is a perfectly valid real subspace.
    realSpan = [real(vectors), imag(vectors)];
    [U, S, ~] = svd(realSpan, 'econ');
    singularValues = diag(S);
    if isempty(singularValues)
        numericalRank = 0;
    else
        rankTolerance = max(size(realSpan)) * eps(max(singularValues));
        numericalRank = sum(singularValues > rankTolerance);
    end
    if numericalRank ~= dimension
        error('RefineCriticalOrbit:DefectiveRealInvariantSubspace', ...
            ['The dimension-%d nominally real multiplier cluster has real ' ...
             'span rank %d, so it does not define the requested real ' ...
             'invariant subspace.'], dimension, numericalRank);
    end
    basis = U(:, 1:dimension);
    for column = 1:size(basis, 2)
        [~, pivot] = max(abs(basis(:, column)));
        if basis(pivot, column) < 0
            basis(:, column) = -basis(:, column);
        end
    end
end

function value = FirstComplexReference(~)
    % Only modal overlap is meaningful before the first endpoint pair is
    % selected; using unit modulus makes the eigenvalue-distance term benign.
    value = 1;
end

function eligible = RealEligible(multipliers, target, options)
    scale = 1 + abs(multipliers);
    eligible = find(abs(imag(multipliers)) <= ...
        options.ImaginaryTolerance .* scale & ...
        abs(real(multipliers) - target) <= options.TargetSearchRadius);
end

function overlaps = VectorOverlaps(reference, vectors)
    reference = reference(:);
    referenceNorm = norm(reference);
    overlaps = zeros(1, size(vectors, 2));
    for i = 1:size(vectors, 2)
        denominator = referenceNorm * norm(vectors(:, i));
        if denominator > 0
            overlaps(i) = min(1, abs(reference' * vectors(:, i)) / denominator);
        end
    end
end

function basis = OrthonormalBasis(values, maximumDimension)
    if isempty(values)
        basis = [];
        return
    end
    [U, S, ~] = svd(values, 'econ');
    singularValues = diag(S);
    if isempty(singularValues)
        basis = [];
        return
    end
    tolerance = max(size(values)) * eps(max(singularValues));
    rankValue = sum(singularValues > tolerance);
    rankValue = min(rankValue, maximumDimension);
    basis = U(:, 1:rankValue);
end

function type = CandidateType(candidate)
    type = char(string(FirstField(candidate, {'Type', 'type'}, '')));
    if ~any(strcmp(type, {'+1', '-1', 'complex-unit-circle'}))
        error('RefineCriticalOrbit:CandidateType', ...
            'Candidate Type must be +1, -1, or complex-unit-circle.');
    end
    if strcmp(type, '+1')
        trivial = FirstField(candidate, ...
            {'IsTrivialBranchTangent'}, false);
        additional = FirstField(candidate, ...
            {'IsAdditionalNullDirection'}, true);
        if IsLogicalTrue(trivial) || IsLogicalFalse(additional)
            error('RefineCriticalOrbit:TrivialPlusOne', ...
                'A trivial branch-tangent +1 mode is not a critical branch direction.');
        end
    end
end

function target = TargetValue(type)
    if strcmp(type, '+1')
        target = 1;
    elseif strcmp(type, '-1')
        target = -1;
    else
        target = 1;
    end
end

function tf = IsLogicalTrue(value)
    tf = isscalar(value) && (islogical(value) || isnumeric(value)) && ...
        isfinite(double(value)) && logical(value);
end

function tf = IsLogicalFalse(value)
    tf = isscalar(value) && (islogical(value) || isnumeric(value)) && ...
        isfinite(double(value)) && ~logical(value);
end

function reference = NearestReferenceMode(coordinate, left, right)
    if abs(coordinate - left.coordinate) <= abs(right.coordinate - coordinate)
        reference = left.mode;
    else
        reference = right.mode;
    end
end

function RequireEvaluation(evaluation, label)
    if ~evaluation.accepted
        if isempty(evaluation.rejectionReasons)
            reason = 'unknown evaluation failure';
        else
            reason = strjoin(evaluation.rejectionReasons, ' | ');
        end
        error('RefineCriticalOrbit:EvaluationRejected', ...
            '%s was rejected: %s', label, reason);
    end
end

function RequireSignedBracket(left, right)
    % MultiplierTolerance is a convergence criterion, not a sign
    % surrogate: a small nonzero value must still retain its sign so that the
    % coordinate interval continues to contain the crossing.
    if ~isfinite(left) || ~isfinite(right)
        error('RefineCriticalOrbit:NonfiniteBracket', ...
            'Endpoint target-mode residuals must be finite.');
    end
    if left == 0 || right == 0
        return
    end
    if sign(left) == sign(right)
        error('RefineCriticalOrbit:LostMultiplierBracket', ...
            ['Recomputed target mode does not bracket the crossing: ' ...
             '[%.6e %.6e].'], left, right);
    end
end

function [coordinate, kind] = SafeguardedCoordinate(left, right, options)
    width = right.coordinate - left.coordinate;
    denominator = right.signedValue - left.signedValue;
    coordinate = NaN;
    if isfinite(denominator) && abs(denominator) > eps
        coordinate = (left.coordinate * right.signedValue - ...
            right.coordinate * left.signedValue) / denominator;
    end
    guard = options.SecantGuardFraction * width;
    if ~isfinite(coordinate) || coordinate <= left.coordinate + guard || ...
            coordinate >= right.coordinate - guard
        coordinate = 0.5 * (left.coordinate + right.coordinate);
        kind = 'bisection';
    else
        kind = 'secant';
    end
end

function [left, right] = UpdateBracket(left, right, trial)
    RequireSignedBracket(left.signedValue, right.signedValue);
    % Only an exact zero may replace the ordinary opposite-sign invariant.
    % MultiplierTolerance is deliberately not used here: a tolerance-near
    % point is not proof that the root lies at that coordinate.
    if left.signedValue == 0
        right = left;
        return
    elseif right.signedValue == 0
        left = right;
        return
    elseif trial.signedValue == 0
        left = trial;
        right = trial;
        return
    end
    if sign(trial.signedValue) == sign(left.signedValue)
        left = trial;
    elseif sign(trial.signedValue) == sign(right.signedValue)
        right = trial;
    else
        error('RefineCriticalOrbit:BracketUpdate', ...
            'Trial target residual cannot be assigned to either bracket side.');
    end
    RequireSignedBracket(left.signedValue, right.signedValue);
end

function evaluation = BetterEvaluation(first, second)
    if abs(second.signedValue) < abs(first.signedValue)
        evaluation = second;
    else
        evaluation = first;
    end
end

function tf = IsMultiplierConverged(evaluation, options)
    tf = evaluation.accepted && isfield(evaluation, 'mode') && ...
        ~isempty(evaluation.mode) && isfinite(evaluation.signedValue) && ...
        abs(evaluation.signedValue) <= options.MultiplierTolerance && ...
        evaluation.mode.clusterSpread <= options.ClusterSpreadTolerance && ...
        isfinite(evaluation.mode.criticalMultiplierUncertainty) && ...
        evaluation.mode.criticalMultiplierUncertainty <= ...
            options.CriticalMultiplierUncertaintyTolerance;
end

function tf = IsRefinementConverged(evaluation, left, right, options)
    width = abs(right.coordinate - left.coordinate);
    tf = IsMultiplierConverged(evaluation, options) && ...
        isfinite(width) && width <= options.CoordinateTolerance;
end

function [eigenData, ready, reason, details] = PredictorReadyData( ...
        evaluation, candidate, localTangent, options)
    eigenData = [];
    ready = false;
    type = char(string(FirstField(candidate, {'Type', 'type'}, '')));
    details = struct('type', type, 'nearPlusOneRadius', NaN, ...
        'nearPlusOneIndices', [], 'nearPlusOneMultipliers', [], ...
        'fullRealNullSubspace', [], 'fullRealNullity', NaN, ...
        'singularValuesMminusI', [], 'svdNullityTolerance', NaN, ...
        'richardsonFrobeniusMatrixErrorEstimate', NaN, ...
        'svdNullity', NaN, 'tangentEigenResidual', NaN, ...
        'tangentEigenResidualTolerance', NaN, ...
        'scaledTangentNullProjection', NaN, ...
        'complementDimension', NaN, 'selectedModeAlignment', NaN, ...
        'scaledTangentComplementOverlap', NaN, ...
        'complementEigenResidual', NaN, 'stateScale', [], ...
        'detectorDirectionVerified', false, ...
        'explicitInvariantSubspaceResolution', false, ...
        'targetSubspaceDimension', NaN);
    if ~strcmp(type, '+1')
        reason = sprintf(['A %s crossing is not an additional +1 null ' ...
            'direction for steady branch switching.'], type);
        return
    end

    classification = char(string(FirstField(candidate, ...
        {'NullDirectionClassification'}, '')));
    additional = FirstField(candidate, ...
        {'IsAdditionalNullDirection'}, NaN);
    trivial = FirstField(candidate, {'IsTrivialBranchTangent'}, NaN);
    detectorDirectionVerified = ...
        strcmp(classification, 'additional-null-direction') && ...
        IsLogicalTrue(additional) && IsLogicalFalse(trivial);
    targetDimension = 0;
    if ~isempty(options.TargetSubspace)
        targetDimension = size(OrthonormalBasis(options.TargetSubspace, ...
            options.MaximumSubspaceDimension), 2);
    end
    explicitSubspaceResolution = targetDimension == 2 && ...
        ~isempty(options.ExcludedTargetDirection);
    details.detectorDirectionVerified = detectorDirectionVerified;
    details.explicitInvariantSubspaceResolution = ...
        explicitSubspaceResolution;
    details.targetSubspaceDimension = targetDimension;
    if ~(detectorDirectionVerified || explicitSubspaceResolution)
        reason = ['The detector direction is unresolved and no explicit ' ...
            'two-dimensional +1 invariant subspace with a known excluded ' ...
            'trivial direction was supplied.'];
        return
    end

    tangent = localTangent(:);
    if numel(tangent) ~= 12 || any(~isfinite(real(tangent))) || ...
            any(~isfinite(imag(tangent))) || norm(tangent) == 0 || ...
            norm(imag(tangent)) > ...
                options.ImaginaryTolerance * (1 + norm(real(tangent)))
        reason = ['The final corrected coordinate bracket did not yield a ' ...
            'valid real 12-state local branch tangent.'];
        return
    end
    tangent = real(tangent) / norm(real(tangent));

    multipliers = evaluation.multipliers(:);
    nearRadius = max(10 * options.MultiplierTolerance, ...
        options.ClusterSpreadTolerance);
    near = find(abs(multipliers - 1) <= ...
        nearRadius .* (1 + abs(multipliers)));
    details.nearPlusOneRadius = nearRadius;
    details.nearPlusOneIndices = near(:).';
    details.nearPlusOneMultipliers = multipliers(near);
    if numel(near) < 2
        reason = ['The final Floquet matrix has fewer than two near-+1 ' ...
            'directions, so no additional null direction is verified.'];
        return
    end
    try
        fullNullBasis = RealInvariantBasis( ...
            evaluation.eigenvectors(:, near), numel(near));
    catch subspaceError
        reason = sprintf('Near-+1 real invariant subspace is unresolved: %s', ...
            subspaceError.message);
        return
    end
    details.fullRealNullSubspace = fullNullBasis;
    details.fullRealNullity = size(fullNullBasis, 2);

    matrixMinusIdentity = evaluation.matrix - eye(12);
    singularValues = svd(matrixMinusIdentity);
    matrixNorm = norm(evaluation.matrix, 2);
    matrixUncertainty = evaluation.mode.richardsonFrobeniusErrorEstimate;
    svdTolerance = max(nearRadius * max(1, matrixNorm), ...
        matrixUncertainty);
    svdNullity = sum(singularValues <= svdTolerance);
    tangentEigenResidual = norm(matrixMinusIdentity * tangent) / ...
        ((1 + matrixNorm) * norm(tangent));
    tangentResidualTolerance = 5 * max(nearRadius, ...
        matrixUncertainty / (1 + matrixNorm));
    details.singularValuesMminusI = singularValues;
    details.svdNullityTolerance = svdTolerance;
    details.richardsonFrobeniusMatrixErrorEstimate = matrixUncertainty;
    details.svdNullity = svdNullity;
    details.tangentEigenResidual = tangentEigenResidual;
    details.tangentEigenResidualTolerance = tangentResidualTolerance;
    if svdNullity ~= 2
        reason = sprintf(['M-I has numerical nullity %d (expected exactly 2 ' ...
            'for one tangent plus one unique additional direction).'], ...
            svdNullity);
        return
    end
    if tangentEigenResidual > tangentResidualTolerance
        reason = sprintf(['The final local branch tangent has normalized ' ...
            '(M-I)t residual %.3e, exceeding %.3e.'], ...
            tangentEigenResidual, tangentResidualTolerance);
        return
    end

    reduced = evaluation.solution([1 2 4:13]);
    stateScale = max(abs(reduced), [1; 1; 0.5 * ones(10, 1)]);
    scaledNullBasis = OrthonormalBasis( ...
        fullNullBasis ./ stateScale, size(fullNullBasis, 2));
    scaledTangent = tangent ./ stateScale;
    scaledTangent = scaledTangent / norm(scaledTangent);
    tangentCoordinates = scaledNullBasis' * scaledTangent;
    tangentProjection = norm(tangentCoordinates);
    details.stateScale = stateScale;
    details.scaledTangentNullProjection = tangentProjection;
    if tangentProjection < options.MinimumBranchTangentNullProjection
        reason = sprintf(['The scaled local tangent projects only %.6f into ' ...
            'the final near-+1 null subspace (minimum %.6f).'], ...
            tangentProjection, options.MinimumBranchTangentNullProjection);
        return
    end

    coefficientComplement = null(tangentCoordinates(:).');
    scaledComplement = scaledNullBasis * coefficientComplement;
    details.complementDimension = size(scaledComplement, 2);
    if size(scaledComplement, 2) ~= 1
        reason = sprintf(['Removing the branch tangent leaves a dimension-%d ' ...
            'additional near-null subspace; no unique predictor exists.'], ...
            size(scaledComplement, 2));
        return
    end
    scaledComplement = scaledComplement / norm(scaledComplement);

    selectedBasis = evaluation.mode.realInvariantSubspace;
    selectedScaledBasis = OrthonormalBasis( ...
        selectedBasis ./ stateScale, size(selectedBasis, 2));
    selectedAlignment = min(1, norm(selectedScaledBasis' * scaledComplement));
    details.selectedModeAlignment = selectedAlignment;
    if selectedAlignment < options.MinimumModeOverlap
        reason = sprintf(['The unique transverse near-null direction has ' ...
            'only %.6f alignment with the tracked critical mode.'], ...
            selectedAlignment);
        return
    end

    vector = stateScale .* scaledComplement;
    vector = vector / norm(vector);
    scaledVector = vector ./ stateScale;
    scaledVector = scaledVector / norm(scaledVector);
    tangentOverlap = min(1, abs(scaledTangent' * scaledVector));
    complementEigenResidual = norm(matrixMinusIdentity * vector) / ...
        ((1 + matrixNorm) * norm(vector));
    details.scaledTangentComplementOverlap = tangentOverlap;
    details.complementEigenResidual = complementEigenResidual;
    if tangentOverlap >= options.MaximumBranchTangentOverlap || ...
            complementEigenResidual > tangentResidualTolerance
        reason = sprintf(['The proposed complement failed the final null-' ...
            'direction check (scaled tangent overlap %.3e, eigen residual %.3e).'], ...
            tangentOverlap, complementEigenResidual);
        return
    end

    multiplier = 1 + evaluation.mode.signedValue;

    eigenData = struct();
    eigenData.Type = '+1';
    eigenData.type = '+1';
    eigenData.Multiplier = multiplier;
    eigenData.multiplier = multiplier;
    eigenData.Eigenvector = vector;
    eigenData.eigenvector = vector;
    eigenData.CriticalSubspace = vector;
    eigenData.FullNearPlusOneSubspace = fullNullBasis;
    eigenData.NearPlusOneMultipliers = multipliers(near);
    eigenData.MatchedEigenSubspace = evaluation.mode.basis;
    eigenData.NullDirectionClassification = 'additional-null-direction';
    eigenData.IsAdditionalNullDirection = true;
    eigenData.isAdditionalNullDirection = true;
    eigenData.IsTrivialBranchTangent = false;
    eigenData.isBranchTangent = false;
    eigenData.BranchTangent = tangent;
    eigenData.branchTangent = tangent;
    eigenData.DetectorBranchTangent = FirstField(candidate, ...
        {'BranchTangent', 'branchTangent'}, []);
    eigenData.BranchTangentOverlap = tangentOverlap;
    eigenData.StateScale = stateScale;
    eigenData.ReadinessDiagnostics = details;
    eigenData.ReferenceTopology = evaluation.topology;
    eigenData.Parameters = evaluation.parameters;
    eigenData.Solution = evaluation.solution;
    ready = true;
    reason = ['Verified real additional +1 direction; eigenData is ready ' ...
        'for PredictBranchDirection.'];
end

function [tangent, info] = LocalReducedBranchTangent(left, right)
    tangent = [];
    info = struct('accepted', false, ...
        'coordinateBracket', [left.coordinate, right.coordinate], ...
        'coordinateWidth', right.coordinate - left.coordinate, ...
        'rawTangent', [], 'norm', NaN, 'rejectionReason', '');
    width = right.coordinate - left.coordinate;
    if ~isfinite(width) || width <= 0 || isempty(left.solution) || ...
            isempty(right.solution)
        info.rejectionReason = ...
            'The final corrected bracket is unavailable or has nonpositive width.';
        return
    end
    reducedIndices = [1 2 4:13];
    raw = (right.solution(reducedIndices) - ...
        left.solution(reducedIndices)) / width;
    magnitude = norm(raw);
    info.rawTangent = raw;
    info.norm = magnitude;
    if numel(raw) ~= 12 || any(~isfinite(raw)) || magnitude <= 0
        info.rejectionReason = ...
            'The final corrected bracket produced an invalid reduced tangent.';
        return
    end
    tangent = raw / magnitude;
    info.accepted = true;
end

function z = CircularOrbitInterpolation(left, right, alpha)
    left = left(:);
    right = right(:);
    left = WrapTimingState(left);
    right = WrapTimingState(right);
    leftPeriod = left(22);
    rightPeriod = right(22);
    leftPhase = left(14:21) / leftPeriod;
    rightPhase = right(14:21) / rightPeriod;
    phaseDifference = mod((rightPhase - leftPhase) + 0.5, 1) - 0.5;
    phase = mod(leftPhase + alpha * phaseDifference, 1);
    z = (1 - alpha) * left + alpha * right;
    period = (1 - alpha) * leftPeriod + alpha * rightPeriod;
    z(22) = period;
    z(14:21) = phase * period;
end

function parameters = InterpolateParameters(left, right, alpha)
    left = left(:);
    right = right(:);
    parameters = zeros(7, 1);
    for i = 1:7
        if isinf(left(i)) || isinf(right(i))
            if isinf(left(i)) && isinf(right(i)) && ...
                    sign(left(i)) == sign(right(i))
                parameters(i) = left(i);
            else
                error('RefineCriticalOrbit:InfiniteParameterInterpolation', ...
                    'Infinite endpoint parameter %d is inconsistent.', i);
            end
        else
            parameters(i) = (1 - alpha) * left(i) + alpha * right(i);
        end
    end
end

function history = HistoryView(evaluation, options)
    history = EmptyHistory();
    history.accepted = evaluation.accepted;
    history.source = evaluation.source;
    history.coordinate = evaluation.coordinate;
    history.parameters = evaluation.parameters;
    history.solution = evaluation.solution;
    history.rejectionReasons = evaluation.rejectionReasons;
    history.correction = evaluation.correction;
    history.timingValidation = evaluation.timingValidation;
    history.topology = evaluation.topology;
    history.topologyComparison = evaluation.topologyComparison;
    history.signedValue = evaluation.signedValue;
    history.mode = evaluation.mode;
    if options.StoreFullFloquetDiagnostics
        history.floquetDiagnostics = evaluation.floquetDiagnostics;
    else
        history.floquetDiagnostics = FloquetSummary( ...
            evaluation.floquetDiagnostics);
    end
end

function summary = FloquetSummary(value)
    summary = struct();
    if ~isstruct(value) || isempty(fieldnames(value))
        return
    end
    names = {'accepted', 'status', 'rejectionReasons', ...
        'perturbationMagnitudes', 'selectedPerturbationMagnitude', ...
        'derivativeConverged', 'maximumFinestForwardBackwardError', ...
        'successfulPerturbedMapCount', 'requestedPerturbedMapCount'};
    for i = 1:numel(names)
        if isfield(value, names{i})
            summary.(names{i}) = value.(names{i});
        end
    end
    if isfield(value, 'derivativeConvergence') && ...
            isfield(value.derivativeConvergence, 'finestRelativeError')
        summary.finestDerivativeConvergenceError = ...
            value.derivativeConvergence.finestRelativeError;
    end
end

function evaluation = EmptyEvaluation()
    evaluation = struct('accepted', false, 'source', '', ...
        'coordinate', NaN, 'parameters', [], 'solution', [], ...
        'correction', EmptyCorrection(), 'matrix', [], ...
        'multipliers', [], 'eigenvectors', [], ...
        'coarseMatrix', [], 'coarseMultipliers', [], ...
        'coarseEigenvectors', [], ...
        'richardsonFrobeniusErrorEstimate', Inf, ...
        'floquetDiagnostics', struct(), 'topology', struct(), ...
        'topologyComparison', struct(), 'timingValidation', struct(), ...
        'authoritativeSolvedEventTimes', [], 'mode', struct(), ...
        'signedValue', NaN, 'rejectionReasons', {{}}, 'exception', []);
end

function correction = EmptyCorrection()
    correction = struct('accepted', false, 'exitflag', NaN, ...
        'output', struct(), 'fval', [], 'canonicalResidual', [], ...
        'canonicalResidualNormInf', Inf, 'coordinateResidual', Inf, ...
        'parentCorrector',struct(),'jacobianRank',struct(), ...
        'topology', struct(), 'topologyComparison', struct(), ...
        'rejectionReasons', {{}}, 'exception', []);
end

function history = EmptyHistory()
    history = struct('accepted', false, 'source', '', 'coordinate', NaN, ...
        'parameters', [], 'solution', [], 'signedValue', NaN, ...
        'mode', struct(), 'correction', EmptyCorrection(), ...
        'timingValidation', struct(), 'topology', struct(), ...
        'topologyComparison', struct(), 'floquetDiagnostics', struct(), ...
        'rejectionReasons', {{}});
end

function reasons = PrefixReasons(reasons, prefix)
    if ischar(reasons) || (isstring(reasons) && isscalar(reasons))
        reasons = {char(reasons)};
    end
    if isempty(reasons)
        reasons = {prefix};
        return
    end
    for i = 1:numel(reasons)
        reasons{i} = [prefix, char(string(reasons{i}))];
    end
end

function value = FirstField(source, names, default)
    value = default;
    if ~isstruct(source)
        return
    end
    for i = 1:numel(names)
        if isfield(source, names{i})
            value = source.(names{i});
            return
        end
    end
end

function [found, value, actualName] = FieldValueCaseInsensitive(source, name)
    found = false;
    value = [];
    actualName = '';
    if ~isstruct(source)
        return
    end
    names = fieldnames(source);
    hit = find(strcmpi(name, names), 1);
    if isempty(hit)
        return
    end
    found = true;
    actualName = names{hit};
    value = source.(actualName);
end
