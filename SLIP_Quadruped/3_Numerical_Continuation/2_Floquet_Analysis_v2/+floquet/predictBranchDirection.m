function [deltaZ, zPredictor, info] = predictBranchDirection(X, E, Para, eigenData, options)
%PREDICTBRANCHDIRECTION Lift a reduced Floquet mode to a full orbit predictor.
%
%   [DELTAZ,ZPREDICTOR,INFO] = PREDICTBRANCHDIRECTION(X,E,PARA,V,OPTIONS)
%   converts a 12-dimensional Floquet eigenvector V on the apex section
%
%       q = X([1 2 4:13]),        X(3) = dy = 0,
%
%   into a 22-dimensional periodic-orbit predictor [deltaX;deltaE].  The
%   event-time component is not taken from the Floquet eigensystem.  It is
%   induced by solving event timing through BuildPoincareMap in a locally
%   lifted (circular) timing chart.  The default central lift uses
%   X +/- deltaX.  TimingLiftMode='one-sided-sector' evaluates only the
%   selected hybrid sector X + deltaX; this is needed when opposite
%   symmetry-breaking directions legitimately split a simultaneous-event
%   cluster into different internal event orders.
%
%   EIGENDATA may be the numeric 12-vector or a detector result struct with
%   an eigenvector field (eigenvector, vector, v) and optional multiplier
%   and branch-tangent metadata. A numeric vector must be accompanied by
%   OPTIONS.Multiplier for the default same-stride path. OPTIONS fields include:
%
%     Amplitude             scaled state amplitude (default 1e-3)
%     StateScale            12- or 13-vector of positive state scales
%     TimingProbeFactor     central timing probe / Amplitude (default 1)
%     TimingLiftMode        'central' (default) or 'one-sided-sector'
%     PerturbationSign      +1 or -1 orientation applied to the mode
%     MapOptions            options passed unchanged to BuildPoincareMap
%     Multiplier            multiplier override
%     BranchTangent         known branch tangent (12, 13, or 22 entries)
%     TangentCosineTolerance cosine above which a +1 mode is rejected
%     PlusOneTolerance      admissible distance from +1 (default 5e-2)
%     RequirePlusOne        require a +1 mode for the built-in path (true)
%     RequireProductionReady require refined/explicit direction provenance
%     CustomCorrector       custom corrector enabling -1/complex predictors
%     ComplexPhase          phase used to make a complex mode real
%
%   DELTAZ and ZPREDICTOR use the lifted timing chart; INFO also contains a
%   wrapped predictor suitable for direct calls to the legacy dynamics.
%   The built-in same-stride switch intentionally rejects period-doubling
%   (-1), complex, and trivial branch-tangent +1 directions.

    floquet.internal.ensureRuntimePaths(false);
    if nargin < 5 || isempty(options)
        options = struct();
    end

    sectionIndex = [1 2 4:13];
    [X, E, Para] = ValidateBaseInputs(X, E, Para);
    if isstruct(eigenData) && isscalar(eigenData) && ...
            ~HasOption(options, 'StateScale')
        eigenScale = ExtractInfoField(eigenData, ...
            {'StateScale','stateScale','NullDirectionScale'}, []);
        if ~isempty(eigenScale)
            options.StateScale = eigenScale;
        end
    end
    opts = ParseOptions(options, X, sectionIndex);
    [v, multiplier, eigenMeta] = ParseEigenData(eigenData, opts);

    [realMode, classification, requiresCustom, modeWarnings] = ...
        SelectRealMode(v, multiplier, eigenMeta, opts);

    qScale = opts.StateScale;
    weightedModeNorm = norm(realMode ./ qScale);
    if ~(isfinite(weightedModeNorm) && weightedModeNorm > opts.MinimumDirectionNorm)
        error('PredictBranchDirection:DegenerateDirection', ...
            'The Floquet direction is zero or numerically degenerate after scaling.');
    end

    directionQ = realMode / weightedModeNorm;
    [directionQ, orientationFlipped] = OrientDirection(directionQ, opts, sectionIndex);
    directionQ = opts.PerturbationSign * directionQ;
    deltaQ = opts.Amplitude * directionQ;
    deltaX = zeros(13, 1);
    deltaX(sectionIndex) = deltaQ;

    % The apex-section constraint is exact by construction.  Event timing
    % is recomputed for each state perturbation; E itself is never manually
    % perturbed in these return-map calls.
    probe = opts.TimingProbeFactor;
    Xplus = X + probe * deltaX;
    useCentralLift = strcmp(opts.TimingLiftMode, 'central');
    if useCentralLift
        Xminus = X - probe * deltaX;
    else
        Xminus = [];
    end
    if abs(Xplus(3)) > opts.SectionTolerance || ...
            (useCentralLift && abs(Xminus(3)) > opts.SectionTolerance)
        error('PredictBranchDirection:SectionViolation', ...
            'The lifted direction left the apex section (dy must remain zero).');
    end

    referenceTopology = ResolveReferenceTopology(E, opts);
    plusMapOptions = opts.MapOptions;
    plusMapOptions.ReferenceTopology = referenceTopology;
    [qPlus, plusInfo] = CallPoincareMap(Xplus, E, Para, plusMapOptions, '+');
    ValidateMapResult(qPlus, plusInfo, '+', opts);
    topologyPlus = ExtractInfoField(plusInfo, ...
        {'topology','eventTopology','eventOrder','eventOrdering'}, []);

    Eplus = ExtractEventTimes(plusInfo, '+');
    EplusLifted = LiftEventTimesToReference(Eplus, E);
    plusConsistent = ...
        TopologiesConsistent(referenceTopology, topologyPlus, opts.MapOptions) && ...
        TopologyComparisonAccepted(plusInfo);

    if useCentralLift
        % Both probes are compared with the unperturbed orbit's topology.
        % The additional plus/minus comparison is deliberately retained for
        % the central derivative: a derivative is not single-valued if its
        % two probes belong to different hybrid sectors.
        minusMapOptions = opts.MapOptions;
        minusMapOptions.ReferenceTopology = referenceTopology;
        [qMinus, minusInfo] = CallPoincareMap( ...
            Xminus, E, Para, minusMapOptions, '-');
        ValidateMapResult(qMinus, minusInfo, '-', opts);
        topologyMinus = ExtractInfoField(minusInfo, ...
            {'topology','eventTopology','eventOrder','eventOrdering'}, []);
        minusConsistent = ...
            TopologiesConsistent(referenceTopology, topologyMinus, opts.MapOptions) && ...
            TopologyComparisonAccepted(minusInfo);
        topologyConsistent = plusConsistent && minusConsistent && ...
            TopologiesConsistent(topologyPlus, topologyMinus, opts.MapOptions);
        if ~topologyConsistent
            error('PredictBranchDirection:EventTopologyChanged', ...
                ['The + and - timing probes produced different event topology. ' ...
                 'Use TimingLiftMode=''one-sided-sector'' only when the ' ...
                 'opposite probes are known refinements of a simultaneous ' ...
                 'reference-event cluster.']);
        end

        Eminus = ExtractEventTimes(minusInfo, '-');
        EminusLifted = LiftEventTimesToReference(Eminus, E);
        deltaE = (EplusLifted - EminusLifted) / (2 * probe);
        midpointDefect = 0.5 * (EplusLifted + EminusLifted) - E;
        timingScale = DefaultTimingScale(E);
        timingCentralSymmetryError = norm(midpointDefect ./ timingScale, inf);
        method = 'central-event-timing-lift';
    else
        % A simultaneous reference cluster can split in one admissible
        % order for +v and the opposite admissible order for -v.  A sector
        % predictor is therefore defined from one side and is validated
        % only against the clustered base topology.
        if ~plusConsistent
            error('PredictBranchDirection:UnexpectedEventTopology', ...
                ['The selected one-sided timing probe is not an admissible ' ...
                 'refinement of the reference event topology.']);
        end
        topologyConsistent = true;
        topologyMinus = [];
        minusInfo = struct();
        Eminus = [];
        EminusLifted = [];
        deltaE = (EplusLifted - E) / probe;
        timingCentralSymmetryError = NaN;
        method = 'one-sided-sector-event-timing-lift';
        modeWarnings{end+1,1} = ...
            ['One-sided event-time lifting is first-order accurate; verify ' ...
             'the predictor over multiple decreasing amplitudes.'];
    end

    if any(~isfinite(deltaE))
        error('PredictBranchDirection:InvalidTimingDirection', ...
            'The induced central event-time direction contains nonfinite values.');
    end

    deltaZ = [deltaX; deltaE];
    zBase = [X; E];
    zPredictor = zBase + deltaZ;
    zPredictorWrapped = WrapTimingState(zPredictor);

    info = struct();
    info.success = true;
    info.method = method;
    info.sectionIndices = sectionIndex(:);
    info.apexConstraintIndex = 3;
    info.multiplier = multiplier;
    info.classification = classification;
    info.rawEigenvector = v;
    info.realMode = realMode;
    info.stateScale = qScale;
    info.scaledAmplitude = norm(deltaQ ./ qScale);
    info.directionQ = directionQ;
    info.orientationFlipped = orientationFlipped;
    info.perturbationSign = opts.PerturbationSign;
    info.timingLiftMode = opts.TimingLiftMode;
    info.deltaX = deltaX;
    info.deltaE = deltaE;
    info.deltaZ = deltaZ;
    info.zBase = zBase;
    info.zPredictor = zPredictor;
    info.zPredictorWrapped = zPredictorWrapped;
    info.eventTimesPlus = Eplus;
    info.eventTimesMinus = Eminus;
    info.eventTimesPlusLifted = EplusLifted;
    info.eventTimesMinusLifted = EminusLifted;
    info.timingCentralSymmetryError = timingCentralSymmetryError;
    info.timingProbeFactor = probe;
    info.plusMapInfo = plusInfo;
    info.minusMapInfo = minusInfo;
    info.referenceTopology = referenceTopology;
    info.topology = topologyPlus;
    info.sectorTopology = topologyPlus;
    info.oppositeProbeTopology = topologyMinus;
    info.topologyConsistent = topologyConsistent;
    info.requiresCustomCorrector = requiresCustom;
    info.customCorrectorSupplied = ~isempty(opts.CustomCorrector);
    info.tangentCosine = eigenMeta.tangentCosine;
    info.additionalNullDirectionVerified = eigenMeta.additionalNullDirectionVerified;
    info.productionReady = eigenMeta.productionReady;
    info.diagnosticOnly = ~eigenMeta.productionReady;
    info.directionProvenance = eigenMeta.directionProvenance;
    info.productionReadinessReason = eigenMeta.productionReadinessReason;
    info.warnings = [eigenMeta.warnings(:); modeWarnings(:)];
end

function tf = HasOption(options,name)
    tf = isstruct(options) && isscalar(options) && ...
        any(strcmpi(fieldnames(options),name));
end

function [X, E, Para] = ValidateBaseInputs(X, E, Para)
    X = X(:);
    E = E(:);
    Para = Para(:);
    if numel(X) ~= 13 || numel(E) ~= 9
        error('PredictBranchDirection:InvalidBasePoint', ...
            'X and E must contain 13 and 9 entries, respectively.');
    end
    validParameters = numel(Para) == 7 && ...
        all(isfinite(Para) | ((1:7).' == 3 & isinf(Para) & Para > 0));
    if any(~isfinite(X)) || any(~isfinite(E)) || ~validParameters
        error('PredictBranchDirection:NonfiniteInput', ...
            ['X and E must be finite; Para must have seven entries and ' ...
             'only Para(3) may be positive Inf.']);
    end
    if ~(isfinite(E(9)) && E(9) > 0)
        error('PredictBranchDirection:InvalidPeriod', ...
            'The base apex time E(9) must be finite and positive.');
    end
end

function opts = ParseOptions(options, X, sectionIndex)
    if ~isstruct(options) || ~isscalar(options)
        error('PredictBranchDirection:InvalidOptions', ...
            'options must be a scalar struct.');
    end
    opts = options;
    opts.Amplitude = GetOption(options, 'Amplitude', 1e-3);
    opts.TimingProbeFactor = GetOption(options, 'TimingProbeFactor', 1);
    opts.TimingLiftMode = lower(char(string( ...
        GetOption(options, 'TimingLiftMode', 'central'))));
    opts.PerturbationSign = GetOption(options, 'PerturbationSign', 1);
    opts.MapOptions = GetOption(options, 'MapOptions', struct());
    constraints = GetOption(options, 'Constraints', {});
    if ~isfield(opts.MapOptions, 'Constraints') && ~isempty(constraints)
        opts.MapOptions.Constraints = constraints;
    end
    opts.Multiplier = GetOption(options, 'Multiplier', []);
    opts.BranchTangent = GetOption(options, 'BranchTangent', []);
    opts.OrientationReference = GetOption(options, 'OrientationReference', []);
    opts.TangentCosineTolerance = GetOption(options, 'TangentCosineTolerance', 0.90);
    opts.PlusOneTolerance = GetOption(options, 'PlusOneTolerance', 5e-2);
    opts.ImaginaryTolerance = GetOption(options, 'ImaginaryTolerance', 1e-10);
    opts.MinimumDirectionNorm = GetOption(options, 'MinimumDirectionNorm', 1e-12);
    opts.SectionTolerance = GetOption(options, 'SectionTolerance', 1e-12);
    opts.RequirePlusOne = logical(GetOption(options, 'RequirePlusOne', true));
    opts.RequireAdditionalNullDirection = logical( ...
        GetOption(options, 'RequireAdditionalNullDirection', false));
    opts.RequireProductionReady = ValidateLogicalOption( ...
        GetOption(options, 'RequireProductionReady', false), ...
        'RequireProductionReady');
    opts.CustomCorrector = GetOption(options, 'CustomCorrector', []);
    opts.ComplexPhase = GetOption(options, 'ComplexPhase', 0);
    opts.ExpectedTopology = GetOption(options, 'ExpectedTopology', []);

    if ~(isscalar(opts.Amplitude) && isfinite(opts.Amplitude) && opts.Amplitude > 0)
        error('PredictBranchDirection:InvalidAmplitude', ...
            'Amplitude must be a finite positive scalar.');
    end
    if ~(isscalar(opts.TimingProbeFactor) && isfinite(opts.TimingProbeFactor) && ...
            opts.TimingProbeFactor > 0)
        error('PredictBranchDirection:InvalidTimingProbeFactor', ...
            'TimingProbeFactor must be a finite positive scalar.');
    end
    validTimingModes = {'central','one-sided-sector'};
    if ~any(strcmp(opts.TimingLiftMode, validTimingModes))
        error('PredictBranchDirection:InvalidTimingLiftMode', ...
            'TimingLiftMode must be ''central'' or ''one-sided-sector''.');
    end
    if ~(isscalar(opts.PerturbationSign) && isreal(opts.PerturbationSign) && ...
            any(opts.PerturbationSign == [-1 1]))
        error('PredictBranchDirection:InvalidPerturbationSign', ...
            'PerturbationSign must be +1 or -1.');
    end
    if ~isempty(opts.CustomCorrector) && ~isa(opts.CustomCorrector, 'function_handle')
        error('PredictBranchDirection:InvalidCustomCorrector', ...
            'CustomCorrector must be a function handle.');
    end

    defaultFloor = [1; 1; 0.5 * ones(10,1)];
    q = X(sectionIndex);
    defaultScale = max(abs(q), defaultFloor);
    scale = GetOption(options, 'StateScale', defaultScale);
    scale = scale(:);
    if numel(scale) == 13
        scale = scale(sectionIndex);
    end
    if numel(scale) ~= 12 || any(~isfinite(scale)) || any(scale <= 0)
        error('PredictBranchDirection:InvalidStateScale', ...
            'StateScale must be a positive finite 12- or 13-vector.');
    end
    opts.StateScale = scale;
end

function [v, multiplier, meta] = ParseEigenData(eigenData, opts)
    meta = struct('isBranchTangent', false, ...
                  'additionalNullDirection', [], ...
                  'additionalNullDirectionVerified', false, ...
                  'type', '', 'tangentCosine', NaN, ...
                  'nullClassification', '', ...
                  'branchSwitchReady', [], ...
                  'productionReady', false, ...
                  'directionProvenance', 'unrefined-input', ...
                  'productionReadinessReason', ...
                    'No refined or explicit branch-switch-ready provenance.', ...
                  'warnings', {cell(0,1)});
    multiplier = opts.Multiplier;

    if isnumeric(eigenData)
        v = eigenData;
        meta.directionProvenance = 'raw-numeric-direction';
    elseif isstruct(eigenData) && isscalar(eigenData)
        v = ExtractInfoField(eigenData, ...
            {'eigenvector','Eigenvector','vector','Vector','v','V'}, []);
        if isempty(multiplier)
            multiplier = ExtractInfoField(eigenData, ...
                {'multiplier','Multiplier','lambda','Lambda','value'}, []);
        end
        tangentFlag = ExtractInfoField(eigenData, ...
            {'isBranchTangent','IsTrivialBranchTangent', ...
             'isTrivialDirection','trivial'}, false);
        meta.isBranchTangent = IsReliableLogicalTrue(tangentFlag);
        additionalFlag = ExtractInfoField(eigenData, ...
            {'isAdditionalNullDirection','IsAdditionalNullDirection', ...
             'additionalNullDirection'}, []);
        if IsReliableLogical(additionalFlag)
            meta.additionalNullDirection = logical(additionalFlag);
        end
        meta.type = char(string(ExtractInfoField(eigenData, ...
            {'type','Type','classification','crossingType'}, '')));
        meta.nullClassification = char(string(ExtractInfoField(eigenData, ...
            {'NullDirectionClassification', ...
             'nullDirectionClassification'}, '')));
        readyFlag = ExtractInfoField(eigenData, ...
            {'BranchSwitchReady','branchSwitchReady'}, []);
        if IsReliableLogical(readyFlag)
            meta.branchSwitchReady = logical(readyFlag);
        end
        if IsReliableLogicalTrue(readyFlag)
            meta.productionReady = true;
            meta.directionProvenance = ...
                'explicit-branch-switch-ready-direction';
            meta.productionReadinessReason = ...
                'Input explicitly records BranchSwitchReady=true.';
        elseif HasVerifiedRefinementSignature(eigenData)
            meta.productionReady = true;
            meta.directionProvenance = ...
                'verified-refined-critical-orbit-direction';
            meta.productionReadinessReason = [ ...
                'ReadinessDiagnostics verify a unique tangent-free ' ...
                'critical direction.'];
        elseif HasVerifiedInvariantSubspaceResolverSignature(eigenData)
            meta.productionReady = true;
            meta.directionProvenance = ...
                'verified-invariant-subspace-resolver-direction';
            meta.productionReadinessReason = [ ...
                'A symmetry/invariant-subspace resolver supplied the ' ...
                'tangent-free critical direction.'];
        elseif isfield(eigenData,'RefinementStatus') || ...
                isfield(eigenData,'ScreeningCandidate')
            meta.directionProvenance = ...
                'unrefined-detector-screening-direction';
            meta.productionReadinessReason = [ ...
                'Detector brackets screen crossings; they do not refine ' ...
                'a branch-switch direction.'];
        else
            meta.directionProvenance = 'unrefined-structured-direction';
        end
    else
        error('PredictBranchDirection:InvalidEigenData', ...
            'eigenData must be a numeric vector or scalar detector-result struct.');
    end

    v = v(:);
    if numel(v) ~= 12
        error('PredictBranchDirection:WrongEigenvectorDimension', ...
            ['The Floquet eigenvector must have 12 reduced-section entries. ' ...
             'Full-state or event-time eigenvectors are not valid inputs.']);
    end
    if any(~isfinite(real(v))) || any(~isfinite(imag(v)))
        error('PredictBranchDirection:NonfiniteEigenvector', ...
            'The Floquet eigenvector contains nonfinite entries.');
    end
    if ~isempty(multiplier)
        if ~isnumeric(multiplier) || ~isscalar(multiplier) || ...
                ~isfinite(real(multiplier)) || ~isfinite(imag(multiplier))
            error('PredictBranchDirection:InvalidMultiplier', ...
                'The Floquet multiplier must be a finite numeric scalar.');
        end
    end

    if ~isempty(meta.additionalNullDirection)
        meta.additionalNullDirection = logical(meta.additionalNullDirection);
        meta.additionalNullDirectionVerified = meta.additionalNullDirection;
    end

    repeatedUnresolved = strcmp(meta.nullClassification, ...
        'unresolved-repeated-plus-one-cluster') || ...
        IsReliableLogicalTrue(ExtractInfoField(eigenData, ...
            {'RepeatedNullCluster','repeatedNullCluster'}, false));
    if repeatedUnresolved && ~meta.productionReady
        error('PredictBranchDirection:UnresolvedRepeatedPlusOneCluster', ...
            ['A raw vector from a repeated +1 cluster is basis dependent. ' ...
             'Refine the critical invariant subspace and resolve a physical ' ...
             'tangent-free direction before constructing a predictor.']);
    end

    if meta.isBranchTangent || ContainsText(meta.type, 'tangent') || ...
            ContainsText(meta.type, 'trivial')
        error('PredictBranchDirection:TrivialBranchTangent', ...
            ['The supplied +1 direction is the trivial continuation-branch ' ...
             'tangent, not an additional null direction.']);
    end
    if ~isempty(meta.additionalNullDirection) && ~meta.additionalNullDirection
        error('PredictBranchDirection:NoAdditionalNullDirection', ...
            'The detector marked this +1 mode as not being an additional null direction.');
    end

    branchTangent = opts.BranchTangent;
    if isempty(branchTangent) && isstruct(eigenData)
        branchTangent = ExtractInfoField(eigenData, ...
            {'BranchTangent','branchTangent'}, []);
    end
    if ~isempty(branchTangent)
        tangent = ReduceDirection(branchTangent);
        nv = norm(v ./ opts.StateScale);
        nt = norm(tangent ./ opts.StateScale);
        if nv > 0 && nt > 0
            meta.tangentCosine = abs((v ./ opts.StateScale)' * ...
                (tangent ./ opts.StateScale)) / (nv * nt);
        end
        if isfinite(meta.tangentCosine) && ...
                meta.tangentCosine >= opts.TangentCosineTolerance
            error('PredictBranchDirection:TrivialBranchTangent', ...
                ['The Floquet mode has scaled cosine %.6f with the supplied ' ...
                 'branch tangent (limit %.6f).'], ...
                meta.tangentCosine, opts.TangentCosineTolerance);
        end
        meta.additionalNullDirectionVerified = true;
    elseif opts.RequireAdditionalNullDirection
        error('PredictBranchDirection:UnverifiedAdditionalNullDirection', ...
            ['RequireAdditionalNullDirection is true, but no BranchTangent or ' ...
             'positive detector classification was supplied.']);
    else
        meta.warnings{end+1,1} = ...
            'No branch tangent was supplied; the additional +1 null direction was not independently verified.';
    end
    if opts.RequireProductionReady && ~meta.productionReady
        error('PredictBranchDirection:UnrefinedDirection', ...
            ['RequireProductionReady is true, but the supplied direction ' ...
             'has no accepted refinement or BranchSwitchReady provenance.']);
    elseif ~meta.productionReady
        meta.warnings{end+1,1} = [ ...
            'The input direction is unrefined; this predictor is diagnostic ' ...
            'and must not be treated as a validated daughter-branch seed.'];
    end
end

function tf = HasVerifiedRefinementSignature(eigenData)
    tf = false;
    diagnostics = ExtractInfoField(eigenData, ...
        {'ReadinessDiagnostics','readinessDiagnostics'}, []);
    if ~isstruct(diagnostics) || ~isscalar(diagnostics)
        return
    end
    required = {'fullRealNullity','svdNullity','complementDimension'};
    if ~all(isfield(diagnostics,required))
        return
    end
    tf = isequal(diagnostics.fullRealNullity,2) && ...
        isequal(diagnostics.svdNullity,2) && ...
        isequal(diagnostics.complementDimension,1);
end

function tf = HasVerifiedInvariantSubspaceResolverSignature(eigenData)
    required = {'SymmetryCoordinate','CriticalSubspace','BranchTangent', ...
        'StateScale','ReferenceTopology','Solution','Parameters'};
    tf = all(isfield(eigenData,required));
    if ~tf
        return
    end
    tf = ~isempty(eigenData.SymmetryCoordinate) && ...
        isnumeric(eigenData.CriticalSubspace) && ...
        numel(eigenData.CriticalSubspace) == 12 && ...
        isnumeric(eigenData.BranchTangent) && ...
        numel(eigenData.BranchTangent) == 12 && ...
        isnumeric(eigenData.StateScale) && ...
        numel(eigenData.StateScale) == 12 && ...
        isstruct(eigenData.ReferenceTopology) && ...
        isnumeric(eigenData.Solution) && numel(eigenData.Solution) == 22 && ...
        isnumeric(eigenData.Parameters) && numel(eigenData.Parameters) == 7;
end

function value = ValidateLogicalOption(value,name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isreal(value) && isfinite(value) && ...
             any(value == [0 1]))))
        error('PredictBranchDirection:InvalidLogicalOption', ...
            '%s must be scalar logical.',name);
    end
    value = logical(value);
end

function [mode, classification, requiresCustom, warnings] = ...
        SelectRealMode(v, multiplier, meta, opts)
    warnings = cell(0,1);
    type = lower(strtrim(meta.type));
    hasCustom = ~isempty(opts.CustomCorrector);
    complexMode = any(abs(imag(v)) > opts.ImaginaryTolerance);
    complexLambda = ~isempty(multiplier) && ...
        abs(imag(multiplier)) > opts.ImaginaryTolerance;
    minusOne = (~isempty(multiplier) && abs(multiplier + 1) <= opts.PlusOneTolerance) || ...
        ContainsText(type, '-1') || ContainsText(type, 'period') || ...
        ContainsText(type, 'flip');

    if complexMode || complexLambda || ContainsText(type, 'complex') || ...
            ContainsText(type, 'neimark')
        classification = 'complex-unit-circle';
        requiresCustom = true;
        if ~hasCustom
            error('PredictBranchDirection:ComplexSwitchRequiresCustomCorrector', ...
                ['A complex Floquet mode does not define a unique real, same-stride ' ...
                 'branch predictor. Supply a custom normal-form/corrector workflow.']);
        end
        phase = opts.ComplexPhase;
        if ~(isscalar(phase) && isfinite(phase))
            error('PredictBranchDirection:InvalidComplexPhase', ...
                'ComplexPhase must be a finite real scalar.');
        end
        mode = real(exp(1i * phase) * v);
        warnings{end+1,1} = ...
            'A real phase of a complex mode was selected for a user-supplied custom corrector.';
        return;
    end

    if minusOne
        classification = 'minus-one-period-doubling';
        requiresCustom = true;
        if ~hasCustom
            error('PredictBranchDirection:PeriodDoublingRequiresCustomCorrector', ...
                ['A -1 multiplier requires a two-stride/period-doubled residual. ' ...
                 'The built-in same-stride corrector cannot perform this switch.']);
        end
        mode = real(v);
        warnings{end+1,1} = ...
            'The -1 mode is only a seed direction; the custom corrector must impose a two-stride residual.';
        return;
    end

    classification = 'plus-one-additional-null';
    requiresCustom = false;
    if ~isempty(multiplier)
        if abs(imag(multiplier)) <= opts.ImaginaryTolerance && ...
                abs(real(multiplier) - 1) > opts.PlusOneTolerance
            if opts.RequirePlusOne
                error('PredictBranchDirection:NotPlusOne', ...
                    ['The built-in same-stride branch switch requires a +1 ' ...
                     'multiplier; supplied lambda = %.16g%+.16gi.'], ...
                    real(multiplier), imag(multiplier));
            end
            warnings{end+1,1} = ...
                'The supplied multiplier is not close to +1; the predictor may not span a branch null direction.';
        end
    else
        declaredPlusOne = ContainsText(type, '+1') || ...
            ContainsText(type, 'plus-one');
        if opts.RequirePlusOne && ~declaredPlusOne
            error('PredictBranchDirection:MultiplierRequired', ...
                ['A real eigenvector alone cannot distinguish a +1 branch ' ...
                 'mode from an unsupported -1 mode. Supply the Floquet ' ...
                 'multiplier (or set RequirePlusOne=false for an explicitly ' ...
                 'unclassified custom experiment).']);
        end
        warnings{end+1,1} = ...
            'No multiplier was supplied; the direction is explicitly unclassified.';
    end
    mode = real(v);
end

function direction = ReduceDirection(direction)
    direction = direction(:);
    if numel(direction) == 22 || numel(direction) == 13
        direction = direction([1 2 4:13]);
    elseif numel(direction) ~= 12
        error('PredictBranchDirection:InvalidReferenceDirection', ...
            'A branch/reference direction must have 12, 13, or 22 entries.');
    end
    if any(~isfinite(real(direction))) || any(abs(imag(direction)) > 1e-12)
        error('PredictBranchDirection:InvalidReferenceDirection', ...
            'A branch/reference direction must be finite and real.');
    end
    direction = real(direction);
end

function [directionQ, flipped] = OrientDirection(directionQ, opts, sectionIndex)
    flipped = false;
    if isempty(opts.OrientationReference)
        return;
    end
    reference = opts.OrientationReference(:);
    if numel(reference) == 13 || numel(reference) == 22
        reference = reference(sectionIndex);
    elseif numel(reference) ~= 12
        error('PredictBranchDirection:InvalidOrientationReference', ...
            'OrientationReference must have 12, 13, or 22 entries.');
    end
    if any(~isfinite(reference)) || ~isreal(reference)
        error('PredictBranchDirection:InvalidOrientationReference', ...
            'OrientationReference must be finite and real.');
    end
    if dot(directionQ ./ opts.StateScale, reference ./ opts.StateScale) < 0
        directionQ = -directionQ;
        flipped = true;
    end
end

function [q, mapInfo] = CallPoincareMap(X, E, Para, mapOptions, side)
    try
        [q, mapInfo] = floquet.internal.poincare.buildMap( ...
            X, E, Para, mapOptions);
    catch ME
        error('PredictBranchDirection:PoincareMapFailure', ...
            'BuildPoincareMap failed for the %s probe: %s', side, ME.message);
    end
end

function ValidateMapResult(q, mapInfo, side, ~)
    success = ExtractInfoField(mapInfo, ...
        {'success','valid','accepted','isValid'}, true);
    if ~all(logical(success(:)))
        message = MapRejectionMessage(mapInfo);
        error('PredictBranchDirection:InvalidPoincareProbe', ...
            'The %s probe was rejected by BuildPoincareMap: %s', ...
            side, char(string(message)));
    end
    if ~isnumeric(q) || numel(q) ~= 12 || any(~isfinite(q(:)))
        error('PredictBranchDirection:InvalidPoincareReturn', ...
            'The %s probe did not return a finite 12-state Poincare point.', side);
    end
    inputSectionValid = ExtractInfoField(mapInfo, ...
        {'inputOnSection','validInputSection','inputSectionValid'}, true);
    returnSectionValid = ExtractInfoField(mapInfo, ...
        {'returnOnSection','validSection','sectionValid','isOnSection'}, true);
    if ~all(logical(inputSectionValid(:))) || ...
            ~all(logical(returnSectionValid(:)))
        error('PredictBranchDirection:SectionViolation', ...
            'The %s Poincare probe did not return to a valid apex section.', side);
    end
    timingConverged = ExtractInfoField(mapInfo, ...
        {'timingSolverConverged','timingConverged', ...
         'eventTimingConverged','solverConverged'}, true);
    if ~all(logical(timingConverged(:)))
        error('PredictBranchDirection:EventTimingFailure', ...
            'The event timing solver did not converge for the %s probe.', side);
    end
    topologyValid = ExtractInfoField(mapInfo, ...
        {'eventOrderingConsistent','topologyValid'}, true);
    if ~all(logical(topologyValid(:)))
        error('PredictBranchDirection:EventTopologyChanged', ...
            'BuildPoincareMap rejected event ordering for the %s probe.', side);
    end
end

function E = ExtractEventTimes(mapInfo, side)
    E = ExtractInfoField(mapInfo, ...
        {'eventTimes','solvedEventTimes','E','eventTiming','timings'}, []);
    E = E(:);
    if numel(E) ~= 9 || any(~isfinite(E)) || ~(E(9) > 0)
        error('PredictBranchDirection:MissingEventTimes', ...
            ['BuildPoincareMap must report nine finite solved event times ' ...
             'in info.eventTimes; invalid result for the %s probe.'], side);
    end
end

function E_lift = LiftEventTimesToReference(E_in, E_ref)
    E_in = E_in(:);
    E_ref = E_ref(:);
    E_lift = E_in;
    T = E_in(9);
    if ~(isfinite(T) && T > 0)
        error('PredictBranchDirection:InvalidPerturbedPeriod', ...
            'A perturbed timing solution has a nonpositive period.');
    end
    d = mod((E_in(1:8) - E_ref(1:8)) + 0.5*T, T) - 0.5*T;
    E_lift(1:8) = E_ref(1:8) + d;
end

function z = WrapTimingState(z)
    z = z(:);
    T = z(22);
    if ~(isfinite(T) && T > 0)
        error('PredictBranchDirection:InvalidPredictedPeriod', ...
            'The predicted apex time is nonpositive. Reduce Amplitude.');
    end
    z(14:21) = mod(z(14:21), T);
end

function scale = DefaultTimingScale(E)
    T = E(9);
    scale = [max(0.05, 0.25*T) * ones(8,1); max(0.1, 0.5*T)];
end

function topology = ResolveReferenceTopology(E, opts)
    if ~isempty(opts.ExpectedTopology)
        topology = opts.ExpectedTopology;
    elseif isstruct(opts.MapOptions) && ...
            isfield(opts.MapOptions, 'ReferenceTopology') && ...
            ~isempty(opts.MapOptions.ReferenceTopology)
        topology = opts.MapOptions.ReferenceTopology;
    else
        try
            topology = floquet.internal.events.classifyTopology( ...
                E, opts.MapOptions);
        catch ME
            error('PredictBranchDirection:BaseTopologyFailure', ...
                'Unable to classify the base event topology: %s', ME.message);
        end
    end
    valid = ExtractInfoField(topology, {'valid','accepted','isValid'}, true);
    if ~isstruct(topology) || ~all(logical(valid(:)))
        reasons = MapRejectionMessage(topology);
        error('PredictBranchDirection:InvalidBaseTopology', ...
            'The base orbit event topology is invalid: %s', reasons);
    end
end

function tf = TopologiesEqual(a, b, mapOptions)
    if isempty(a) && isempty(b)
        tf = true;
        return;
    end
    if isempty(a) || isempty(b)
        tf = false;
        return;
    end
    if isstruct(a) && isstruct(b)
        mode = 'clustered';
        if nargin >= 3 && isstruct(mapOptions) && ...
                isfield(mapOptions, 'TopologyMode') && ~isempty(mapOptions.TopologyMode)
            mode = lower(char(string(mapOptions.TopologyMode)));
        elseif isfield(a, 'mode') && ~isempty(a.mode)
            mode = lower(char(string(a.mode)));
        end
        if strcmp(mode, 'strict') && isfield(a, 'sortedEventNumbers') && ...
                isfield(b, 'sortedEventNumbers')
            tf = isequal(a.sortedEventNumbers(:), b.sortedEventNumbers(:));
            return;
        end
        if isfield(a, 'clusters') && isfield(b, 'clusters')
            tf = ClusterSequencesEqual(a.clusters, b.clusters);
            return;
        end
        if isfield(a, 'signature') && isfield(b, 'signature')
            tf = strcmp(char(string(a.signature)), char(string(b.signature)));
            return;
        end
    end
    tf = isequaln(a, b);
end

function tf = TopologiesConsistent(reference, candidate, mapOptions)
    if isempty(reference) || isempty(candidate)
        tf = isempty(reference) && isempty(candidate);
        return;
    end
    if isstruct(reference) && isstruct(candidate)
        try
            comparison = floquet.internal.events.compareTopology( ...
                reference, candidate, mapOptions);
            tf = ExtractInfoField(comparison, ...
                {'consistent','isConsistent','accepted'}, false);
            tf = all(logical(tf(:)));
            return;
        catch
            % Fall through to the discrete signature comparison below.
        end
    end
    tf = TopologiesEqual(reference, candidate, mapOptions);
end

function tf = ClusterSequencesEqual(a, b)
    if numel(a) ~= numel(b)
        tf = false;
        return;
    end
    tf = true;
    for i = 1:numel(a)
        if ~isequal(sort(a{i}(:)), sort(b{i}(:)))
            tf = false;
            return;
        end
    end
end

function tf = TopologyComparisonAccepted(mapInfo)
    comparison = ExtractInfoField(mapInfo, {'topologyComparison'}, []);
    if isempty(comparison) || ~isstruct(comparison)
        tf = true;
        return;
    end
    tf = ExtractInfoField(comparison, ...
        {'consistent','isConsistent','accepted','valid'}, true);
    tf = all(logical(tf(:)));
end

function message = MapRejectionMessage(mapInfo)
    message = ExtractInfoField(mapInfo, {'message','reason','failureReason'}, '');
    if isempty(message)
        reasons = ExtractInfoField(mapInfo, {'rejectionReasons'}, {});
        if iscell(reasons) && ~isempty(reasons)
            message = strjoin(cellfun(@(x) char(string(x)), reasons, ...
                'UniformOutput', false), ' | ');
        else
            message = 'unspecified validation failure';
        end
    end
end

function value = ExtractInfoField(s, names, defaultValue)
    value = defaultValue;
    if ~isstruct(s)
        return;
    end
    for i = 1:numel(names)
        if isfield(s, names{i}) && ~isempty(s.(names{i}))
            value = s.(names{i});
            return;
        end
    end
end

function value = GetOption(options, name, defaultValue)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
end

function tf = ContainsText(value, pattern)
    tf = ~isempty(strfind(lower(char(string(value))), lower(pattern))); %#ok<STREMP>
end

function tf = IsReliableLogical(value)
    tf = isscalar(value) && (islogical(value) || ...
        (isnumeric(value) && isfinite(value) && any(value == [0 1])));
end

function tf = IsReliableLogicalTrue(value)
    tf = IsReliableLogical(value) && logical(value);
end
