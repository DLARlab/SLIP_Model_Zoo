function [zCorrected, info] = correctBranchSwitch(X, E, Para, predictor, options)
%CORRECTBRANCHSWITCH Correct a Floquet branch predictor to a periodic orbit.
%
%   [ZCORRECTED,INFO] = CORRECTBRANCHSWITCH(X,E,PARA,PREDICTOR,OPTIONS)
%   sends a 22-dimensional state/event-time predictor to FSOLVE using the
%   canonical Quadrupedal_ZeroFun_v2 residual with the 'skipSolve' flag.
%   An additional scaled predictor condition removes the local singular
%   freedom at a +1 bifurcation.  Event times remain nonlinear-orbit
%   unknowns; they are never treated as Floquet states.
%
%   PREDICTOR may be DELTAZ returned by PredictBranchDirection, an absolute
%   predictor when OPTIONS.PredictorIsAbsolute is true, or the INFO struct
%   returned by PredictBranchDirection.  Useful OPTIONS fields are:
%
%     Constraints             constraints passed to the canonical residual
%     FsolveOptions           optimset-compatible solver options
%     StateScale              positive 22-vector used by predictor geometry
%     ConstraintMode          'hyperplane' (default), 'amplitude', 'radius'
%     ConstraintWeight        positive scalar (default 1)
%     ResidualTolerance       canonical residual acceptance (default 1e-8)
%     ConstraintTolerance     predictor constraint acceptance (default 1e-7)
%     ValidateWithPoincareMap independently validate corrected map (true)
%     MapOptions              options passed to BuildPoincareMap
%     ExpectedTopology        topology required during validation
%     CustomCorrector         required for -1 or complex branch switching
%     ThrowOnFailure          throw rather than return INFO.accepted=false
%
%   The built-in corrector is deliberately limited to an additional real
%   +1 null direction of the one-stride map.  A -1 multiplier requires a
%   two-stride residual and a complex unit-circle pair requires a suitable
%   normal-form/torus workflow; either must be supplied as CustomCorrector.

    floquet.internal.ensureRuntimePaths(false);
    if nargin < 5 || isempty(options)
        options = struct();
    end

    [X, E, Para] = ValidateBaseInputs(X, E, Para);
    opts = ParseOptions(options, E);
    zBase = [X; E];
    [deltaZ, zPredictor, predictorInfo] = ...
        ResolvePredictor(predictor, zBase, opts);
    [classification, multiplier, branchTangent, requiresCustom] = ...
        PredictorClassification(predictorInfo, opts);

    if branchTangent
        error('CorrectBranchSwitch:TrivialBranchTangent', ...
            ['A continuation-branch tangent at +1 is not a branch-switch ' ...
             'direction. Supply an independently verified additional null mode.']);
    end

    if requiresCustom && isempty(opts.CustomCorrector)
        if strcmp(classification, 'minus-one-period-doubling')
            error('CorrectBranchSwitch:PeriodDoublingRequiresCustomCorrector', ...
                ['A -1 multiplier requires a two-stride periodic residual; ' ...
                 'the built-in same-stride corrector is intentionally disabled.']);
        else
            error('CorrectBranchSwitch:ComplexSwitchRequiresCustomCorrector', ...
                ['A complex unit-circle crossing requires a custom real ' ...
                 'normal-form/torus corrector.']);
        end
    end

    scale = opts.StateScale;
    localDelta = LocalStateDifference(zPredictor, zBase);
    predictorRadius = norm(localDelta ./ scale);
    if ~(isfinite(predictorRadius) && predictorRadius > opts.MinimumPredictorNorm)
        error('CorrectBranchSwitch:DegeneratePredictor', ...
            'The scaled branch predictor has zero or negligible length.');
    end
    tangentScaled = (localDelta ./ scale) / predictorRadius;
    zInitial = WrapTimingState(zPredictor);

    if ~isempty(opts.CustomCorrector)
        context = BuildCustomContext(zBase, zInitial, deltaZ, Para, ...
            predictorInfo, classification, multiplier, opts, scale, ...
            predictorRadius, tangentScaled);
        [zCorrected, customInfo] = InvokeCustomCorrector(opts.CustomCorrector, context);
        zCorrected = ValidateCustomCandidate(zCorrected);
        info = ValidateCustomResult(zCorrected, zBase, zInitial, deltaZ, Para, ...
            predictorInfo, classification, multiplier, opts, customInfo, ...
            scale, predictorRadius, tangentScaled);
        if ~info.accepted && opts.ThrowOnFailure
            error('CorrectBranchSwitch:CustomCorrectionRejected', '%s', info.message);
        end
        return;
    end

    if ~exist('fsolve', 'file')
        error('CorrectBranchSwitch:MissingFsolve', ...
            'CorrectBranchSwitch requires Optimization Toolbox fsolve.');
    end

    objective = @(z) AugmentedResidual(z, zBase, zInitial, Para, opts, ...
        scale, predictorRadius, tangentScaled);
    solverException = [];
    try
        [zCandidate, fval, exitflag, output] = ...
            fsolve(objective, zInitial, opts.FsolveOptions);
    catch ME
        solverException = ME;
        zCandidate = zInitial;
        fval = NaN;
        exitflag = -Inf;
        output = struct();
    end

    rejectedCandidate = zCandidate;
    try
        zCorrected = WrapTimingState(ValidateCandidateShape(zCandidate));
    catch candidateError
        zCorrected = zInitial;
        if isempty(solverException)
            solverException = candidateError;
        end
    end
    info = ValidateStandardResult(zCorrected, zBase, zInitial, deltaZ, Para, ...
        predictorInfo, classification, multiplier, opts, fval, exitflag, ...
        output, solverException, scale, predictorRadius, tangentScaled);
    info.rawSolverCandidate = rejectedCandidate;

    if ~info.accepted && opts.ThrowOnFailure
        error('CorrectBranchSwitch:CorrectionRejected', '%s', info.message);
    end
end

function [X, E, Para] = ValidateBaseInputs(X, E, Para)
    X = X(:);
    E = E(:);
    Para = Para(:);
    if numel(X) ~= 13 || numel(E) ~= 9
        error('CorrectBranchSwitch:InvalidBasePoint', ...
            'X and E must contain 13 and 9 entries, respectively.');
    end
    validParameters = numel(Para) == 7 && ...
        all(isfinite(Para) | ((1:7).' == 3 & isinf(Para) & Para > 0));
    if any(~isfinite(X)) || any(~isfinite(E)) || ~validParameters
        error('CorrectBranchSwitch:NonfiniteInput', ...
            ['X and E must be finite; Para must have seven entries and ' ...
             'only Para(3) may be positive Inf.']);
    end
    if ~(isfinite(E(9)) && E(9) > 0)
        error('CorrectBranchSwitch:InvalidPeriod', ...
            'The base apex time E(9) must be finite and positive.');
    end
end

function opts = ParseOptions(options, E)
    if ~isstruct(options) || ~isscalar(options)
        error('CorrectBranchSwitch:InvalidOptions', ...
            'options must be a scalar struct.');
    end
    opts = options;
    opts.Constraints = GetOption(options, 'Constraints', {});
    opts.ConstraintMode = lower(char(string( ...
        GetOption(options, 'ConstraintMode', 'hyperplane'))));
    opts.ConstraintWeight = GetOption(options, 'ConstraintWeight', 1);
    opts.ResidualTolerance = GetOption(options, 'ResidualTolerance', 1e-8);
    opts.ConstraintTolerance = GetOption(options, 'ConstraintTolerance', 1e-7);
    opts.SectionTolerance = GetOption(options, 'SectionTolerance', 1e-9);
    opts.EventTimeTolerance = GetOption(options, 'EventTimeTolerance', 1e-6);
    opts.ReturnMapTolerance = GetOption(options, 'ReturnMapTolerance', 1e-7);
    opts.MinimumPredictorNorm = GetOption(options, 'MinimumPredictorNorm', 1e-10);
    opts.PredictorConsistencyTolerance = GetOption( ...
        options, 'PredictorConsistencyTolerance', 1e-10);
    opts.PredictorIsAbsolute = logical(GetOption(options, 'PredictorIsAbsolute', false));
    opts.ValidateWithPoincareMap = logical( ...
        GetOption(options, 'ValidateWithPoincareMap', true));
    opts.ValidateCustomWithCanonicalResidual = logical( ...
        GetOption(options, 'ValidateCustomWithCanonicalResidual', false));
    opts.MapOptions = GetOption(options, 'MapOptions', struct());
    if ~isfield(opts.MapOptions, 'Constraints') && ~isempty(opts.Constraints)
        opts.MapOptions.Constraints = opts.Constraints;
    end
    opts.ExpectedTopology = GetOption(options, 'ExpectedTopology', []);
    if isempty(opts.ExpectedTopology) && ...
            isfield(opts.MapOptions, 'ReferenceTopology') && ...
            ~isempty(opts.MapOptions.ReferenceTopology)
        opts.ExpectedTopology = opts.MapOptions.ReferenceTopology;
    elseif isempty(opts.ExpectedTopology) && opts.ValidateWithPoincareMap
        try
            opts.ExpectedTopology = ...
                floquet.internal.events.classifyTopology(E, opts.MapOptions);
        catch ME
            error('CorrectBranchSwitch:BaseTopologyFailure', ...
                'Unable to classify the base event topology: %s', ME.message);
        end
    end
    if ~isempty(opts.ExpectedTopology)
        topologyValid = ExtractInfoField(opts.ExpectedTopology, ...
            {'valid','accepted','isValid'}, true);
        if ~isstruct(opts.ExpectedTopology) || ...
                ~all(logical(topologyValid(:)))
            error('CorrectBranchSwitch:InvalidBaseTopology', ...
                'ExpectedTopology/base event topology must be a valid topology struct.');
        end
    end
    opts.CustomCorrector = GetOption(options, 'CustomCorrector', []);
    opts.Multiplier = GetOption(options, 'Multiplier', []);
    opts.Classification = char(string(GetOption(options, 'Classification', '')));
    opts.IsBranchTangent = logical(GetOption(options, 'IsBranchTangent', false));
    opts.PlusOneTolerance = GetOption(options, 'PlusOneTolerance', 5e-2);
    opts.ImaginaryTolerance = GetOption(options, 'ImaginaryTolerance', 1e-10);
    opts.ThrowOnFailure = logical(GetOption(options, 'ThrowOnFailure', false));

    validModes = {'hyperplane','amplitude','oriented-amplitude','radius'};
    if ~any(strcmp(opts.ConstraintMode, validModes))
        error('CorrectBranchSwitch:InvalidConstraintMode', ...
            'ConstraintMode must be hyperplane, amplitude, oriented-amplitude, or radius.');
    end
    scalarPositive = {'ConstraintWeight','ResidualTolerance', ...
        'ConstraintTolerance','SectionTolerance','EventTimeTolerance', ...
        'ReturnMapTolerance','MinimumPredictorNorm', ...
        'PredictorConsistencyTolerance'};
    for i = 1:numel(scalarPositive)
        value = opts.(scalarPositive{i});
        if ~(isscalar(value) && isfinite(value) && value > 0)
            error('CorrectBranchSwitch:InvalidOptionValue', ...
                '%s must be a finite positive scalar.', scalarPositive{i});
        end
    end
    if ~isempty(opts.CustomCorrector) && ~isa(opts.CustomCorrector, 'function_handle')
        error('CorrectBranchSwitch:InvalidCustomCorrector', ...
            'CustomCorrector must be a function handle.');
    end

    defaultScale = DefaultStateScale(E);
    scale = GetOption(options, 'StateScale', defaultScale);
    scale = scale(:);
    if numel(scale) ~= 22 || any(~isfinite(scale)) || any(scale <= 0)
        error('CorrectBranchSwitch:InvalidStateScale', ...
            'StateScale must be a positive finite 22-vector.');
    end
    opts.StateScale = scale;

    defaultFsolve = optimset( ...
        'Algorithm', 'levenberg-marquardt', ...
        'ScaleProblem', 'jacobian', ...
        'Display', 'off', ...
        'MaxFunEvals', 15000, ...
        'MaxIter', 3000, ...
        'TolFun', 1e-11, ...
        'TolX', 1e-12);
    opts.FsolveOptions = GetOption(options, 'FsolveOptions', defaultFsolve);
end

function [deltaZ, zPredictor, predictorInfo] = ...
        ResolvePredictor(predictor, zBase, opts)
    predictorInfo = struct();
    if isnumeric(predictor)
        value = predictor(:);
        if numel(value) ~= 22
            error('CorrectBranchSwitch:InvalidPredictor', ...
                'A numeric predictor must contain 22 entries.');
        end
        if opts.PredictorIsAbsolute
            zPredictor = value;
            deltaZ = LocalStateDifference(zPredictor, zBase);
        else
            deltaZ = value;
            zPredictor = zBase + deltaZ;
        end
    elseif isstruct(predictor) && isscalar(predictor)
        predictorInfo = predictor;
        deltaZ = ExtractInfoField(predictor, {'deltaZ','DeltaZ','direction'}, []);
        zPredictor = ExtractInfoField(predictor, ...
            {'zPredictor','ZPredictor','predictor','predictedState'}, []);
        if isempty(deltaZ) && isempty(zPredictor)
            error('CorrectBranchSwitch:InvalidPredictorStruct', ...
                'Predictor struct must contain deltaZ or zPredictor.');
        end
        if isempty(zPredictor)
            deltaZ = deltaZ(:);
            zPredictor = zBase + deltaZ;
        elseif isempty(deltaZ)
            zPredictor = zPredictor(:);
            deltaZ = LocalStateDifference(zPredictor, zBase);
        else
            deltaZ = deltaZ(:);
            zPredictor = zPredictor(:);
            if numel(deltaZ) ~= 22 || numel(zPredictor) ~= 22
                error('CorrectBranchSwitch:InvalidPredictorStruct', ...
                    'Predictor struct deltaZ and zPredictor must each have 22 entries.');
            end
            impliedDelta = LocalStateDifference(zPredictor, zBase);
            mismatch = norm((impliedDelta - deltaZ) ./ opts.StateScale, inf);
            if ~isfinite(mismatch) || mismatch > opts.PredictorConsistencyTolerance
                error('CorrectBranchSwitch:InconsistentPredictorStruct', ...
                    ['Predictor struct deltaZ and zPredictor disagree in the ' ...
                     'local timing chart (scaled mismatch %.3e).'], mismatch);
            end
        end
    else
        error('CorrectBranchSwitch:InvalidPredictor', ...
            'predictor must be a numeric 22-vector or scalar predictor-info struct.');
    end

    if numel(deltaZ) ~= 22 || numel(zPredictor) ~= 22 || ...
            any(~isfinite(deltaZ)) || any(~isfinite(zPredictor)) || ...
            ~isreal(deltaZ) || ~isreal(zPredictor)
        error('CorrectBranchSwitch:InvalidPredictor', ...
            'The resolved predictor and deltaZ must be finite, real 22-vectors.');
    end
    if abs(deltaZ(3)) > opts.SectionTolerance || ...
            abs(zPredictor(3) - zBase(3)) > opts.SectionTolerance
        error('CorrectBranchSwitch:SectionDirectionViolation', ...
            'The predictor perturbs dy, which is constrained by the apex section.');
    end
end

function [classification, multiplier, isTangent, requiresCustom] = ...
        PredictorClassification(predictorInfo, opts)
    classification = opts.Classification;
    multiplier = opts.Multiplier;
    isTangent = opts.IsBranchTangent;
    requiresCustom = false;

    if isstruct(predictorInfo)
        if isempty(classification)
            classification = char(string(ExtractInfoField(predictorInfo, ...
                {'classification','type','Type','crossingType'}, '')));
        end
        if isempty(multiplier)
            multiplier = ExtractInfoField(predictorInfo, ...
                {'multiplier','Multiplier','lambda','value'}, []);
        end
        tangentFlag = ExtractInfoField(predictorInfo, ...
            {'isBranchTangent','IsTrivialBranchTangent', ...
             'isTrivialDirection','trivial'}, false);
        isTangent = isTangent || IsReliableLogicalTrue(tangentFlag);
        customFlag = ExtractInfoField(predictorInfo, ...
            {'requiresCustomCorrector'}, false);
        requiresCustom = IsReliableLogicalTrue(customFlag);
    end

    label = lower(classification);
    if ContainsText(label, 'tangent') || ContainsText(label, 'trivial')
        isTangent = true;
    end
    complexMultiplier = ~isempty(multiplier) && ...
        abs(imag(multiplier)) > opts.ImaginaryTolerance;
    minusOne = ~isempty(multiplier) && ...
        abs(multiplier + 1) <= opts.PlusOneTolerance;
    if complexMultiplier || ContainsText(label, 'complex') || ...
            ContainsText(label, 'neimark') || ContainsText(label, 'torus')
        classification = 'complex-unit-circle';
        requiresCustom = true;
    elseif minusOne || ContainsText(label, '-1') || ...
            ContainsText(label, 'period') || ContainsText(label, 'flip')
        classification = 'minus-one-period-doubling';
        requiresCustom = true;
    elseif isempty(classification)
        classification = 'plus-one-additional-null-unverified';
    end

    if ~isempty(multiplier) && ~requiresCustom && ...
            abs(real(multiplier) - 1) > opts.PlusOneTolerance
        error('CorrectBranchSwitch:NotPlusOne', ...
            ['The built-in same-stride corrector requires a +1 multiplier; ' ...
             'supplied lambda = %.16g%+.16gi.'], real(multiplier), imag(multiplier));
    end
end

function residual = AugmentedResidual(z, zBase, zPredictor, Para, opts, ...
        scale, predictorRadius, tangentScaled)
    z = z(:);
    canonical = CanonicalResidual(z, Para, opts.Constraints);
    constraint = PredictorConstraint(z, zBase, zPredictor, scale, ...
        predictorRadius, tangentScaled, opts.ConstraintMode);
    residual = [canonical(:); opts.ConstraintWeight * constraint];
end

function residual = CanonicalResidual(z, Para, constraints)
    residual = Quadrupedal_ZeroFun_v2( ...
        z(1:13).', z(14:22).', Para(:).', constraints, 'skipSolve');
    residual = residual(:);
end

function value = PredictorConstraint(z, zBase, zPredictor, scale, ...
        predictorRadius, tangentScaled, mode)
    switch mode
        case 'hyperplane'
            difference = LocalStateDifference(z, zPredictor) ./ scale;
            value = dot(difference, tangentScaled);
        case {'amplitude','oriented-amplitude'}
            difference = LocalStateDifference(z, zBase) ./ scale;
            value = dot(difference, tangentScaled) - predictorRadius;
        case 'radius'
            difference = LocalStateDifference(z, zBase) ./ scale;
            value = norm(difference) - predictorRadius;
        otherwise
            error('CorrectBranchSwitch:InternalConstraintMode', ...
                'Unsupported predictor constraint mode %s.', mode);
    end
end

function info = ValidateStandardResult(z, zBase, zPredictor, deltaZ, Para, ...
        predictorInfo, classification, multiplier, opts, fval, exitflag, ...
        output, solverException, scale, predictorRadius, tangentScaled)
    info = CommonInfo(z, zBase, zPredictor, deltaZ, predictorInfo, ...
        classification, multiplier, opts, scale, predictorRadius, tangentScaled);
    info.usedCustomCorrector = false;
    info.fval = fval;
    info.exitflag = exitflag;
    info.solverOutput = output;
    info.solverException = solverException;

    [canonical, canonicalError] = SafeCanonicalResidual(z, Para, opts.Constraints);
    info.canonicalResidual = canonical;
    info.canonicalResidualNorm = SafeNorm(canonical);
    info.constraintResidual = PredictorConstraint(z, zBase, zPredictor, ...
        scale, predictorRadius, tangentScaled, opts.ConstraintMode);
    info.sectionResidual = abs(z(3));
    info.mapValidation = EmptyMapValidation();

    solverConverged = isempty(solverException) && isfinite(exitflag) && exitflag > 0;
    canonicalOK = isempty(canonicalError) && ...
        info.canonicalResidualNorm <= opts.ResidualTolerance;
    constraintOK = isfinite(info.constraintResidual) && ...
        abs(info.constraintResidual) <= opts.ConstraintTolerance;
    sectionOK = info.sectionResidual <= opts.SectionTolerance;

    if opts.ValidateWithPoincareMap
        info.mapValidation = ValidatePoincareMap(z, Para, opts, predictorInfo);
        mapOK = info.mapValidation.accepted;
    else
        mapOK = true;
        info.mapValidation.message = 'Poincare-map validation disabled by caller.';
    end

    info.accepted = solverConverged && canonicalOK && constraintOK && sectionOK && mapOK;
    info.validation = struct( ...
        'solverConverged', solverConverged, ...
        'canonicalResidualOK', canonicalOK, ...
        'predictorConstraintOK', constraintOK, ...
        'sectionOK', sectionOK, ...
        'poincareMapOK', mapOK);
    info.message = BuildValidationMessage(info, canonicalError);
end

function info = ValidateCustomResult(z, zBase, zPredictor, deltaZ, Para, ...
        predictorInfo, classification, multiplier, opts, customInfo, ...
        scale, predictorRadius, tangentScaled)
    if numel(z) == 22
        info = CommonInfo(z, zBase, zPredictor, deltaZ, predictorInfo, ...
            classification, multiplier, opts, scale, predictorRadius, tangentScaled);
        info.sectionResidual = abs(z(3));
        sectionOK = info.sectionResidual <= opts.SectionTolerance;
    else
        % A two-stride or torus corrector may use a problem-specific unknown
        % vector.  Its validation contract, not the one-stride 22-vector
        % chart, is authoritative.
        info = struct();
        info.accepted = false;
        info.method = 'custom-branch-corrector';
        info.classification = classification;
        info.multiplier = multiplier;
        info.zBase = zBase;
        info.zPredictor = zPredictor;
        info.zCorrected = z;
        info.X = [];
        info.E = [];
        info.deltaZ = deltaZ;
        info.correctedDeltaZ = [];
        info.predictorInfo = predictorInfo;
        info.stateScale = scale;
        info.predictorRadius = predictorRadius;
        info.predictorTangentScaled = tangentScaled;
        info.constraintMode = 'owned-by-custom-corrector';
        info.constraints = opts.Constraints;
        info.sectionResidual = ExtractInfoField(customInfo, ...
            {'sectionResidual','apexSectionResidual'}, NaN);
        sectionFlag = ExtractInfoField(customInfo, ...
            {'sectionValid','validSection','apexSectionValid'}, true);
        sectionOK = all(logical(sectionFlag(:)));
    end
    info.usedCustomCorrector = true;
    info.customInfo = customInfo;
    info.exitflag = ExtractInfoField(customInfo, {'exitflag','ExitFlag'}, NaN);
    info.solverOutput = ExtractInfoField(customInfo, {'output','solverOutput'}, struct());
    info.fval = ExtractInfoField(customInfo, {'fval','residual'}, []);
    customAccepted = logical(ExtractInfoField(customInfo, ...
        {'accepted','success','converged'}, true));

    if opts.ValidateCustomWithCanonicalResidual
        if numel(z) == 22
            [canonical, canonicalError] = SafeCanonicalResidual(z, Para, opts.Constraints);
            info.canonicalResidual = canonical;
            info.canonicalResidualNorm = SafeNorm(canonical);
            canonicalOK = isempty(canonicalError) && ...
                info.canonicalResidualNorm <= opts.ResidualTolerance;
        else
            canonicalError = MException( ...
                'CorrectBranchSwitch:CustomCanonicalDimension', ...
                ['Canonical one-stride validation was requested for a custom ' ...
                 '%d-dimensional solution.'], numel(z));
            canonicalOK = false;
            info.canonicalResidual = [];
            info.canonicalResidualNorm = NaN;
        end
    else
        canonicalError = [];
        canonicalOK = true;
        info.canonicalResidual = [];
        info.canonicalResidualNorm = NaN;
    end

    % The custom path can represent a two-stride orbit or a complex-mode
    % normal form, so one-stride BuildPoincareMap validation is not imposed.
    info.mapValidation = EmptyMapValidation();
    info.mapValidation.message = ...
        'Custom corrector owns topology and return-map validation.';
    info.accepted = all(customAccepted(:)) && canonicalOK && sectionOK;
    info.validation = struct( ...
        'customCorrectorAccepted', all(customAccepted(:)), ...
        'canonicalResidualOK', canonicalOK, ...
        'sectionOK', sectionOK, ...
        'poincareMapOK', NaN);
    if info.accepted
        info.message = 'Custom branch correction accepted.';
    elseif ~isempty(canonicalError)
        info.message = sprintf('Custom candidate canonical validation failed: %s', ...
            canonicalError.message);
    else
        info.message = 'Custom branch correction was rejected by its validation flags.';
    end
end

function info = CommonInfo(z, zBase, zPredictor, deltaZ, predictorInfo, ...
        classification, multiplier, opts, scale, predictorRadius, tangentScaled)
    info = struct();
    info.accepted = false;
    info.method = 'periodic-residual-with-predictor-constraint';
    info.classification = classification;
    info.multiplier = multiplier;
    info.zBase = zBase;
    info.zPredictor = zPredictor;
    info.zCorrected = z;
    info.X = z(1:13);
    info.E = z(14:22);
    info.deltaZ = deltaZ;
    info.correctedDeltaZ = LocalStateDifference(z, zBase);
    info.predictorInfo = predictorInfo;
    info.stateScale = scale;
    info.predictorRadius = predictorRadius;
    info.predictorTangentScaled = tangentScaled;
    info.constraintMode = opts.ConstraintMode;
    info.constraints = opts.Constraints;
end

function validation = ValidatePoincareMap(z, Para, opts, predictorInfo)
    validation = EmptyMapValidation();
    expected = opts.ExpectedTopology;
    if isempty(expected) && isstruct(predictorInfo)
        expected = ExtractInfoField(predictorInfo, ...
            {'topology','eventTopology','expectedTopology'}, []);
    end
    mapOptions = opts.MapOptions;
    if ~isempty(expected)
        mapOptions.ReferenceTopology = expected;
    end
    try
        [qReturn, mapInfo] = floquet.internal.poincare.buildMap( ...
            z(1:13), z(14:22), Para, mapOptions);
        validation.mapInfo = mapInfo;
        validation.qReturn = qReturn(:);
    catch ME
        validation.message = sprintf('BuildPoincareMap failed: %s', ME.message);
        validation.exception = ME;
        return;
    end

    mapSuccess = ExtractInfoField(validation.mapInfo, ...
        {'success','valid','accepted','isValid'}, true);
    if ~all(logical(mapSuccess(:)))
        validation.message = MapRejectionMessage(validation.mapInfo);
        return;
    end
    if numel(validation.qReturn) ~= 12 || any(~isfinite(validation.qReturn))
        validation.message = 'BuildPoincareMap returned an invalid reduced state.';
        return;
    end

    qInitial = z([1 2 4:13]);
    validation.returnResidual = validation.qReturn - qInitial;
    qScale = opts.StateScale([1 2 4:13]);
    validation.returnResidualNorm = norm(validation.returnResidual ./ qScale, inf);
    returnOK = validation.returnResidualNorm <= opts.ReturnMapTolerance;

    solvedE = ExtractInfoField(validation.mapInfo, ...
        {'eventTimes','solvedEventTimes','E','eventTiming','timings'}, []);
    if isempty(solvedE)
        validation.eventTimeError = Inf;
        timingOK = false;
    else
        solvedE = solvedE(:);
        if numel(solvedE) ~= 9 || any(~isfinite(solvedE)) || solvedE(9) <= 0
            validation.eventTimeError = Inf;
            timingOK = false;
        else
            timingDifference = EventTimeDifference(solvedE, z(14:22));
            timingScale = opts.StateScale(14:22);
            validation.eventTimeDifference = timingDifference;
            validation.eventTimeError = norm(timingDifference ./ timingScale, inf);
            timingOK = validation.eventTimeError <= opts.EventTimeTolerance;
        end
    end

    topology = ExtractInfoField(validation.mapInfo, ...
        {'topology','eventTopology','eventOrder','eventOrdering'}, []);
    if isempty(expected)
        topologyOK = true;
    else
        topologyOK = TopologiesConsistent(expected, topology, mapOptions) && ...
            TopologyComparisonAccepted(validation.mapInfo);
    end
    validation.topology = topology;
    validation.expectedTopology = expected;
    validation.returnResidualOK = returnOK;
    validation.eventTimingOK = timingOK;
    validation.topologyOK = topologyOK;
    validation.accepted = returnOK && timingOK && topologyOK;
    if validation.accepted
        validation.message = 'Independent Poincare-map validation passed.';
    else
        validation.message = sprintf( ...
            'Map validation failed (return=%d, timing=%d, topology=%d).', ...
            returnOK, timingOK, topologyOK);
    end
end

function validation = EmptyMapValidation()
    validation = struct('accepted', false, 'message', '', 'mapInfo', struct(), ...
        'qReturn', [], 'returnResidual', [], 'returnResidualNorm', Inf, ...
        'eventTimeDifference', [], 'eventTimeError', Inf, ...
        'topology', [], 'expectedTopology', [], ...
        'returnResidualOK', false, 'eventTimingOK', false, ...
        'topologyOK', false, 'exception', []);
end

function [residual, exception] = SafeCanonicalResidual(z, Para, constraints)
    exception = [];
    try
        residual = CanonicalResidual(z, Para, constraints);
    catch ME
        residual = NaN;
        exception = ME;
    end
end

function message = BuildValidationMessage(info, canonicalError)
    if info.accepted
        message = sprintf(['Branch correction accepted: residual %.3e, ' ...
            'constraint %.3e.'], info.canonicalResidualNorm, ...
            abs(info.constraintResidual));
        return;
    end
    reasons = cell(0,1);
    if ~isempty(info.solverException)
        reasons{end+1,1} = sprintf('solver exception: %s', info.solverException.message);
    elseif ~(isfinite(info.exitflag) && info.exitflag > 0)
        reasons{end+1,1} = sprintf('fsolve exitflag %.6g', info.exitflag);
    end
    if ~isempty(canonicalError)
        reasons{end+1,1} = sprintf('canonical residual error: %s', canonicalError.message);
    elseif ~info.validation.canonicalResidualOK
        reasons{end+1,1} = sprintf('periodic residual %.3e exceeds tolerance', ...
            info.canonicalResidualNorm);
    end
    if ~info.validation.predictorConstraintOK
        reasons{end+1,1} = sprintf('predictor constraint %.3e exceeds tolerance', ...
            abs(info.constraintResidual));
    end
    if ~info.validation.sectionOK
        reasons{end+1,1} = sprintf('apex dy residual %.3e exceeds tolerance', ...
            info.sectionResidual);
    end
    if ~info.validation.poincareMapOK
        reasons{end+1,1} = info.mapValidation.message;
    end
    if isempty(reasons)
        reasons = {'unspecified validation failure'};
    end
    message = strjoin(reasons, '; ');
end

function context = BuildCustomContext(zBase, zPredictor, deltaZ, Para, ...
        predictorInfo, classification, multiplier, opts, scale, ...
        predictorRadius, tangentScaled)
    context = struct();
    context.zBase = zBase;
    context.X = zBase(1:13);
    context.E = zBase(14:22);
    context.Para = Para;
    context.deltaZ = deltaZ;
    context.zPredictor = zPredictor;
    context.predictorInfo = predictorInfo;
    context.classification = classification;
    context.multiplier = multiplier;
    context.constraints = opts.Constraints;
    context.options = opts;
    context.stateScale = scale;
    context.predictorRadius = predictorRadius;
    context.predictorTangentScaled = tangentScaled;
    context.canonicalResidual = @(z) CanonicalResidual(z, Para, opts.Constraints);
    context.localDifference = @LocalStateDifference;
end

function [z, customInfo] = InvokeCustomCorrector(corrector, context)
    try
        [z, customInfo] = corrector(context);
    catch firstError
        try
            result = corrector(context);
            if isstruct(result)
                z = ExtractInfoField(result, ...
                    {'zCorrected','solution','z','state'}, []);
                customInfo = result;
            else
                z = result;
                customInfo = struct();
            end
        catch secondError
            error('CorrectBranchSwitch:CustomCorrectorFailure', ...
                'Custom corrector failed: %s | %s', ...
                firstError.message, secondError.message);
        end
    end
end

function z = ValidateCandidateShape(z)
    z = z(:);
    if numel(z) ~= 22 || any(~isfinite(z)) || ~isreal(z)
        error('CorrectBranchSwitch:InvalidCorrectedCandidate', ...
            'A corrected candidate must be a finite real 22-vector.');
    end
    if ~(z(22) > 0)
        error('CorrectBranchSwitch:InvalidCorrectedPeriod', ...
            'The corrected apex time must be positive.');
    end
end

function z = ValidateCustomCandidate(z)
    if ~isnumeric(z) || isempty(z) || any(~isfinite(z(:))) || ~isreal(z)
        error('CorrectBranchSwitch:InvalidCustomCandidate', ...
            'A custom corrector must return a nonempty finite real numeric solution.');
    end
    z = z(:);
    if numel(z) == 22 && ~(z(22) > 0)
        error('CorrectBranchSwitch:InvalidCustomPeriod', ...
            'A 22-state custom candidate must have positive apex time z(22).');
    end
end

function difference = LocalStateDifference(z, reference)
    z = z(:);
    reference = reference(:);
    difference = z - reference;
    T = reference(22);
    if ~(isfinite(T) && T > 0)
        T = z(22);
    end
    if isfinite(T) && T > 0
        difference(14:21) = mod((z(14:21) - reference(14:21)) + 0.5*T, T) - 0.5*T;
    end
end

function difference = EventTimeDifference(E, reference)
    E = E(:);
    reference = reference(:);
    difference = E - reference;
    T = reference(9);
    if ~(isfinite(T) && T > 0)
        T = E(9);
    end
    if isfinite(T) && T > 0
        difference(1:8) = mod((E(1:8) - reference(1:8)) + 0.5*T, T) - 0.5*T;
    end
end

function z = WrapTimingState(z)
    z = z(:);
    T = z(22);
    if ~(isfinite(T) && T > 0)
        error('CorrectBranchSwitch:InvalidPredictedPeriod', ...
            'The predictor/corrector apex time must be positive.');
    end
    z(14:21) = mod(z(14:21), T);
end

function scale = DefaultStateScale(E)
    T = E(9);
    eventScale = max(0.05, 0.25*T);
    periodScale = max(0.1, 0.50*T);
    scale = [10; 1; 1; 0.5; 0.5; ...
             0.3; 0.3; 0.3; 0.3; ...
             0.3; 0.3; 0.3; 0.3; ...
             eventScale * ones(8,1); periodScale];
end

function n = SafeNorm(value)
    if isempty(value) || any(~isfinite(value(:)))
        n = Inf;
    else
        n = norm(value(:));
    end
end

function tf = TopologiesEqual(a, b)
    if isempty(a) && isempty(b)
        tf = true;
        return;
    end
    if isempty(a) || isempty(b)
        tf = false;
        return;
    end
    try
        tf = isequaln(a, b);
    catch
        tf = strcmp(char(string(a)), char(string(b)));
    end
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
            % Fall through to exact comparison for foreign topology types.
        end
    end
    tf = TopologiesEqual(reference, candidate);
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
            message = 'BuildPoincareMap rejected the candidate.';
        end
    else
        message = char(string(message));
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
