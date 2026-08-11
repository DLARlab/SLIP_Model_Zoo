function [zCorrected, info] = CorrectPronkingGaitBranch( ...
        X, E, parameters, predictor, directions, gaitClass, options)
%CORRECTPRONKINGGAITBRANCH Correct a multiplicity-four pronking predictor.
%
%   [Z,INFO] = CORRECTPRONKINGGAITBRANCH(X,E,PARA,PREDICTOR,DIRECTIONS,CLASS)
%   corrects a sector-aware predictor using the canonical periodic-orbit
%   residual plus external symmetry and critical-coordinate conditions.
%   CLASS is 'B', 'F', or 'H':
%
%     B  preserves both left/right leg-pair timing symmetries and fixes b;
%     F  preserves the hind-pair symmetry and fixes nonzero f;
%     H  preserves the front-pair symmetry and fixes nonzero h.
%
%   Here b/f/h are the weighted coordinates returned by
%   ResolvePronkingCriticalSubspace.  Fixing the relevant nonzero coordinate
%   prevents the correction from collapsing back to pronking or bounding.
%   Symmetry equations are appended outside Quadrupedal_ZeroFun_v2 because
%   the production core intentionally remains unchanged.
%
%   Event times are nonlinear correction variables, never Floquet states.
%   The final orbit is independently re-evaluated through ValidatePeriodicOrbit,
%   which invokes the existing production timing solver normally.

    if nargin < 7 || isempty(options)
        options = struct();
    end
    [X,E,parameters] = ValidateBase(X,E,parameters);
    [zPredictor,predictorInfo] = ResolvePredictor(predictor,[X;E]);
    gaitClass = upper(char(string(gaitClass)));
    if ~any(strcmp(gaitClass,{'B','F','H'}))
        error('CorrectPronkingGaitBranch:InvalidGaitClass', ...
            'gaitClass must be ''B'', ''F'', or ''H''.');
    end
    opts = ParseOptions(options,E,predictorInfo);
    [~,stateScale,basisScaled,basisGramError] = ...
        ResolveDirections(directions,opts.BasisOrthogonalityTolerance);
    if ~exist('fsolve','file')
        error('CorrectPronkingGaitBranch:MissingFsolve', ...
            'CorrectPronkingGaitBranch requires Optimization Toolbox fsolve.');
    end
    qIndex = [1 2 4:13];
    coordinateIndex = find(strcmp(gaitClass,{'B','F','H'}),1);
    predictorDeltaQ = (zPredictor(qIndex)-X(qIndex)) ./ stateScale;
    targetAmplitude = basisScaled(:,coordinateIndex)' * predictorDeltaQ;
    if abs(targetAmplitude) <= opts.MinimumTargetAmplitude
        error('CorrectPronkingGaitBranch:DegenerateTargetAmplitude', ...
            ['The predictor has %s-coordinate amplitude %.3e; a nonzero ' ...
             'symmetry-breaking target is required.'], ...
            lower(gaitClass),targetAmplitude);
    end

    context = struct('zBase',[X;E],'parameters',parameters, ...
        'basisScaled',basisScaled,'stateScale',stateScale, ...
        'coordinateIndex',coordinateIndex,'targetAmplitude',targetAmplitude, ...
        'gaitClass',gaitClass,'options',opts);
    objective = @(z) AugmentedResidual(z,context);
    solverException = [];
    try
        [candidate,fval,exitflag,output] = ...
            fsolve(objective,WrapTiming(zPredictor),opts.FsolveOptions);
    catch exception
        solverException = exception;
        candidate = zPredictor;
        fval = NaN;
        exitflag = -Inf;
        output = struct();
    end
    try
        zCorrected = WrapTiming(candidate(:));
    catch candidateError
        if isempty(solverException)
            solverException = candidateError;
        end
        exitflag = -Inf;
        zCorrected = WrapTiming(zPredictor);
    end

    [canonical,canonicalError] = SafeCanonicalResidual( ...
        zCorrected,parameters);
    symmetry = SymmetryResidual(zCorrected,gaitClass);
    amplitude = CriticalAmplitudeResidual(zCorrected,context);
    sectionResidual = abs(zCorrected(3));

    mapOptions = opts.MapOptions;
    mapOptions.ReferenceTopology = opts.ExpectedTopology;
    mapOptions.TopologyMode = 'clustered';
    mapOptions.ErrorOnFailure = false;
    mapOptions.PeriodicResidualTolerance = opts.ReturnMapTolerance;
    periodic = floquet.validatePeriodicOrbit( ...
        zCorrected,parameters,mapOptions);
    [timingDifference,eventTimeError] = TimingAgreement( ...
        zCorrected,periodic,E);
    returnResidualNorm = ScaledReturnResidual(periodic,stateScale);
    [classifiedClass,gait,abbreviation,timingMetrics] = ...
        ClassifyCorrectedGait(zCorrected,opts);

    solverAccepted = isempty(solverException) && isfinite(exitflag) && exitflag > 0;
    canonicalAccepted = isempty(canonicalError) && ...
        norm(canonical,inf) <= opts.ResidualTolerance;
    symmetryAccepted = norm(symmetry,inf) <= opts.SymmetryTolerance;
    amplitudeAccepted = abs(amplitude) <= opts.AmplitudeTolerance;
    sectionAccepted = sectionResidual <= opts.SectionTolerance;
    eventTimingAccepted = eventTimeError <= opts.EventTimeTolerance;
    returnAccepted = returnResidualNorm <= opts.ReturnMapTolerance;
    gaitAccepted = strcmp(classifiedClass,gaitClass);

    info = struct();
    info.accepted = solverAccepted && canonicalAccepted && ...
        symmetryAccepted && amplitudeAccepted && sectionAccepted && ...
        periodic.accepted && returnAccepted && eventTimingAccepted && gaitAccepted;
    info.status = Ternary(info.accepted,'accepted','rejected');
    info.method = 'pronking-symmetry-amplitude-corrector';
    info.gaitClass = gaitClass;
    info.classifiedGaitClass = classifiedClass;
    info.gait = gait;
    info.abbreviation = abbreviation;
    info.timingMetrics = timingMetrics;
    info.criticalBasisGramError = basisGramError;
    info.targetCriticalCoordinate = targetAmplitude;
    info.correctedCriticalCoordinate = targetAmplitude + amplitude;
    info.amplitudeResidual = amplitude;
    info.symmetryResidual = symmetry;
    info.symmetryResidualNormInf = norm(symmetry,inf);
    info.canonicalResidual = canonical;
    info.canonicalResidualNormInf = SafeNorm(canonical,inf);
    info.sectionResidual = sectionResidual;
    info.periodicValidation = periodic;
    info.returnResidualNorm = returnResidualNorm;
    info.eventTimeDifference = timingDifference;
    info.eventTimeError = eventTimeError;
    info.fval = fval;
    info.exitflag = exitflag;
    info.solverOutput = output;
    info.solverException = solverException;
    info.predictorInfo = predictorInfo;
    info.zPredictor = zPredictor;
    info.zCorrected = zCorrected;
    info.validation = struct( ...
        'solverAccepted',solverAccepted, ...
        'canonicalAccepted',canonicalAccepted, ...
        'symmetryAccepted',symmetryAccepted, ...
        'amplitudeAccepted',amplitudeAccepted, ...
        'sectionAccepted',sectionAccepted, ...
        'periodicAccepted',periodic.accepted, ...
        'returnAccepted',returnAccepted, ...
        'eventTimingAccepted',eventTimingAccepted, ...
        'gaitAccepted',gaitAccepted);
    info.rejectionReasons = RejectionReasons(info,canonicalError);
    info.message = Ternary(info.accepted, ...
        sprintf('%s branch correction accepted.',gaitClass), ...
        strjoin(info.rejectionReasons,' | '));
    if opts.ThrowOnFailure && ~info.accepted
        error('CorrectPronkingGaitBranch:CorrectionRejected','%s',info.message);
    end
end

function residual = AugmentedResidual(z,context)
    z = z(:);
    canonical = CanonicalResidual(z,context.parameters);
    symmetry = SymmetryResidual(z,context.gaitClass);
    amplitude = CriticalAmplitudeResidual(z,context);
    residual = [canonical(:); ...
        context.options.SymmetryWeight*symmetry(:); ...
        context.options.AmplitudeWeight*amplitude];
end

function residual = CanonicalResidual(z,parameters)
    residual = Quadrupedal_ZeroFun_v2( ...
        z(1:13).',z(14:22).',parameters(:).',{},'skipSolve');
    residual = residual(:);
end

function residual = SymmetryResidual(z,gaitClass)
    E = z(14:22);
    hindState = [z(6)-z(10);z(7)-z(11)];
    frontState = [z(8)-z(12);z(9)-z(13)];
    hindTiming = [WrappedDifference(E(1),E(5),E(9)); ...
        WrappedDifference(E(2),E(6),E(9))];
    frontTiming = [WrappedDifference(E(3),E(7),E(9)); ...
        WrappedDifference(E(4),E(8),E(9))];
    switch gaitClass
        case 'B'
            residual = [hindState;frontState;hindTiming;frontTiming];
        case 'F'
            residual = [hindState;hindTiming];
        case 'H'
            residual = [frontState;frontTiming];
        otherwise
            residual = Inf;
    end
end

function residual = CriticalAmplitudeResidual(z,context)
    qIndex = [1 2 4:13];
    deltaQScaled = (z(qIndex)-context.zBase(qIndex)) ./ context.stateScale;
    coordinate = context.basisScaled(:,context.coordinateIndex)' * deltaQScaled;
    residual = coordinate-context.targetAmplitude;
end

function [X,E,parameters] = ValidateBase(X,E,parameters)
    X = X(:); E = E(:); parameters = parameters(:);
    validParameters = numel(parameters) == 7 && ...
        all(isfinite(parameters) | ((1:7).' == 3 & isinf(parameters) & parameters > 0));
    if numel(X) ~= 13 || numel(E) ~= 9 || any(~isfinite(X)) || ...
            any(~isfinite(E)) || ~validParameters || E(9) <= 0
        error('CorrectPronkingGaitBranch:InvalidBase', ...
            'X, E, and parameters must be valid 13-, 9-, and 7-vectors.');
    end
end

function [zPredictor,info] = ResolvePredictor(predictor,zBase)
    if isstruct(predictor) && isscalar(predictor)
        info = predictor;
        zPredictor = FieldOr(predictor, ...
            {'zPredictorWrapped','zPredictor','ZPredictor'},[]);
        if isempty(zPredictor)
            delta = FieldOr(predictor,{'deltaZ','DeltaZ'},[]);
            if isempty(delta)
                error('CorrectPronkingGaitBranch:MissingPredictorState', ...
                    ['Predictor information must contain zPredictorWrapped, ' ...
                     'zPredictor, or deltaZ.']);
            end
            zPredictor = zBase+delta(:);
        end
    elseif isnumeric(predictor) && isvector(predictor) && numel(predictor)==22
        info = struct();
        zPredictor = predictor(:);
    else
        error('CorrectPronkingGaitBranch:InvalidPredictor', ...
            'predictor must be a predictor-info struct or an absolute 22-vector.');
    end
    zPredictor = zPredictor(:);
    if numel(zPredictor) ~= 22 || any(~isfinite(zPredictor)) || ...
            ~isreal(zPredictor)
        error('CorrectPronkingGaitBranch:InvalidPredictor', ...
            'The resolved predictor must be a finite real 22-vector.');
    end
end

function [basis,stateScale,basisScaled,gramError] = ...
        ResolveDirections(directions,orthogonalityTolerance)
    if ~isstruct(directions) || ~isscalar(directions)
        error('CorrectPronkingGaitBranch:InvalidDirections', ...
            'directions must be a scalar symmetry-resolution structure.');
    end
    basis = FieldOr(directions,{'Matrix'},[]);
    stateScale = FieldOr(directions,{'StateScale'},[]);
    stateScale = stateScale(:);
    if ~isequal(size(basis),[12 3]) || any(~isfinite(basis(:))) || ...
            numel(stateScale) ~= 12 || any(~isfinite(stateScale)) || ...
            any(stateScale<=0)
        error('CorrectPronkingGaitBranch:DirectionShape', ...
            'directions.Matrix and StateScale must be 12-by-3 and 12-by-1.');
    end
    basisScaled = basis ./ stateScale;
    for k = 1:3
        columnNorm = norm(basisScaled(:,k));
        if columnNorm <= eps
            error('CorrectPronkingGaitBranch:DegenerateDirection', ...
                'Every symmetry-resolved direction must be nonzero.');
        end
        basisScaled(:,k) = basisScaled(:,k)/columnNorm;
        basis(:,k) = basis(:,k)/columnNorm;
    end
    gramError = norm(basisScaled'*basisScaled-eye(3),inf);
    if gramError > orthogonalityTolerance
        error('CorrectPronkingGaitBranch:NonorthogonalDirections', ...
            ['The scaled b/f/h basis is not orthonormal: Gram error %.3e ' ...
             'exceeds %.3e.'],gramError,orthogonalityTolerance);
    end
end

function opts = ParseOptions(options,E,predictorInfo)
    if ~isstruct(options) || ~isscalar(options)
        error('CorrectPronkingGaitBranch:InvalidOptions', ...
            'options must be a scalar structure.');
    end
    defaults = struct();
    defaults.FsolveOptions = optimset('Algorithm','levenberg-marquardt', ...
        'Display','off','TolFun',1e-11,'TolX',1e-11, ...
        'MaxIter',800,'MaxFunEvals',12000);
    defaults.MapOptions = struct('TopologyMode','clustered', ...
        'ErrorOnFailure',false);
    defaults.ExpectedTopology = FieldOr(predictorInfo, ...
        {'sectorTopology','topology'},[]);
    defaults.ResidualTolerance = 1e-8;
    defaults.SymmetryTolerance = 1e-8;
    defaults.AmplitudeTolerance = 1e-8;
    defaults.SectionTolerance = 1e-9;
    defaults.ReturnMapTolerance = 1e-7;
    defaults.EventTimeTolerance = 1e-6;
    defaults.PairSymmetryTolerance = 1e-6;
    defaults.BrokenSymmetryTolerance = 1e-4;
    defaults.MinimumTargetAmplitude = 1e-7;
    defaults.BasisOrthogonalityTolerance = 1e-6;
    defaults.SymmetryWeight = 1;
    defaults.AmplitudeWeight = 1;
    defaults.ThrowOnFailure = false;
    opts = defaults;
    names = fieldnames(options);
    allowed = fieldnames(defaults);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k},allowed),1);
        if isempty(hit)
            error('CorrectPronkingGaitBranch:UnknownOption', ...
                'Unknown option ''%s''.',names{k});
        end
        opts.(allowed{hit}) = options.(names{k});
    end
    positive = {'ResidualTolerance','SymmetryTolerance', ...
        'AmplitudeTolerance','SectionTolerance','ReturnMapTolerance', ...
        'EventTimeTolerance','PairSymmetryTolerance', ...
        'BrokenSymmetryTolerance','MinimumTargetAmplitude', ...
        'BasisOrthogonalityTolerance','SymmetryWeight','AmplitudeWeight'};
    for k = 1:numel(positive)
        value = opts.(positive{k});
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value>0)
            error('CorrectPronkingGaitBranch:InvalidOption', ...
                '%s must be a positive finite scalar.',positive{k});
        end
    end
    if opts.BrokenSymmetryTolerance <= opts.PairSymmetryTolerance
        error('CorrectPronkingGaitBranch:InvalidClassificationBand', ...
            ['BrokenSymmetryTolerance must exceed ' ...
             'PairSymmetryTolerance.']);
    end
    if ~isstruct(opts.MapOptions) || ~isscalar(opts.MapOptions) || ...
            ~isstruct(opts.FsolveOptions) || ~isscalar(opts.FsolveOptions)
        error('CorrectPronkingGaitBranch:InvalidOption', ...
            'MapOptions and FsolveOptions must be scalar structures.');
    end
    algorithm = optimget(opts.FsolveOptions,'Algorithm','levenberg-marquardt');
    if ~strcmpi(char(string(algorithm)),'levenberg-marquardt')
        error('CorrectPronkingGaitBranch:OverdeterminedRequiresLM', ...
            ['The symmetry-amplitude residual is overdetermined; ' ...
             'FsolveOptions.Algorithm must be levenberg-marquardt.']);
    end
    if ~(isscalar(opts.ThrowOnFailure) && ...
            (islogical(opts.ThrowOnFailure) || ...
             (isnumeric(opts.ThrowOnFailure) && any(opts.ThrowOnFailure==[0 1]))))
        error('CorrectPronkingGaitBranch:InvalidOption', ...
            'ThrowOnFailure must be a scalar logical.');
    end
    opts.ThrowOnFailure = logical(opts.ThrowOnFailure);
    if isempty(opts.ExpectedTopology)
        opts.ExpectedTopology = ...
            floquet.internal.events.classifyTopology(E,opts.MapOptions);
    end
    if ~isstruct(opts.ExpectedTopology) || ~isscalar(opts.ExpectedTopology)
        error('CorrectPronkingGaitBranch:InvalidExpectedTopology', ...
            'ExpectedTopology must be a scalar topology structure.');
    end
end

function [difference,errorNorm] = TimingAgreement(z,periodic,baseE)
    difference = Inf(9,1);
    errorNorm = Inf;
    if ~isstruct(periodic) || ~isfield(periodic,'mapInfo') || ...
            ~isstruct(periodic.mapInfo) || ...
            ~isfield(periodic.mapInfo,'solvedEventTimes')
        return
    end
    solved = periodic.mapInfo.solvedEventTimes(:);
    candidate = z(14:22);
    if numel(solved)~=9 || any(~isfinite(solved))
        return
    end
    difference = solved-candidate;
    T = solved(9);
    if isfinite(T) && T>0
        difference(1:8) = mod(difference(1:8)+0.5*T,T)-0.5*T;
    end
    scale = ones(9,1)*max(0.05,0.25*baseE(9));
    scale(9) = max(0.1,0.5*baseE(9));
    errorNorm = norm(difference./scale,inf);
end

function value = ScaledReturnResidual(periodic,stateScale)
    value = Inf;
    if isstruct(periodic) && ...
            isfield(periodic,'reducedPeriodicResidual')
        residual = periodic.reducedPeriodicResidual(:);
        if numel(residual)==12 && all(isfinite(residual))
            value = norm(residual./stateScale,inf);
        end
    end
end

function [classLabel,gait,abbreviation,metrics] = ClassifyCorrectedGait(z,opts)
    E = z(14:22);
    T = E(9);
    phase = @(a,b) WrappedDifference(a,b,T)/T;
    hind = max(abs([phase(E(1),E(5)),phase(E(2),E(6))]));
    front = max(abs([phase(E(3),E(7)),phase(E(4),E(8))]));
    foreHind = max(abs([phase(E(1),E(3)),phase(E(2),E(4)), ...
        phase(E(5),E(7)),phase(E(6),E(8))]));
    if hind<=opts.PairSymmetryTolerance && front<=opts.PairSymmetryTolerance
        if foreHind>=opts.BrokenSymmetryTolerance
            classLabel='B';
        else
            classLabel='PK';
        end
    elseif hind<=opts.PairSymmetryTolerance && front>=opts.BrokenSymmetryTolerance
        classLabel='F';
    elseif front<=opts.PairSymmetryTolerance && hind>=opts.BrokenSymmetryTolerance
        classLabel='H';
    else
        classLabel='mixed';
    end
    try
        [gait,abbreviation] = Gait_Identification(z);
        gait = char(string(gait));
        abbreviation = char(string(abbreviation));
    catch
        gait = 'unidentified';
        abbreviation = '';
    end
    metrics = struct('hindPairPhaseError',hind, ...
        'frontPairPhaseError',front,'foreHindPhaseSeparation',foreHind);
end

function [residual,exception] = SafeCanonicalResidual(z,parameters)
    exception = [];
    try
        residual = CanonicalResidual(z,parameters);
    catch caught
        residual = NaN;
        exception = caught;
    end
end

function reasons = RejectionReasons(info,canonicalError)
    reasons = {};
    if ~info.validation.solverAccepted
        if ~isempty(info.solverException)
            reasons{end+1} = sprintf('solver exception: %s', ...
                info.solverException.message);
        else
            reasons{end+1} = sprintf('fsolve exitflag %.6g',info.exitflag);
        end
    end
    if ~isempty(canonicalError)
        reasons{end+1} = sprintf('canonical error: %s',canonicalError.message);
    elseif ~info.validation.canonicalAccepted
        reasons{end+1} = sprintf('canonical residual %.3e', ...
            info.canonicalResidualNormInf);
    end
    if ~info.validation.symmetryAccepted
        reasons{end+1} = sprintf('symmetry residual %.3e', ...
            info.symmetryResidualNormInf);
    end
    if ~info.validation.amplitudeAccepted
        reasons{end+1} = sprintf('amplitude residual %.3e', ...
            abs(info.amplitudeResidual));
    end
    if ~info.validation.sectionAccepted
        reasons{end+1} = sprintf('section residual %.3e',info.sectionResidual);
    end
    if ~info.validation.periodicAccepted
        reasons{end+1} = sprintf('periodic validation: %s', ...
            strjoin(info.periodicValidation.rejectionReasons,'; '));
    end
    if ~info.validation.returnAccepted
        reasons{end+1} = sprintf('scaled return residual %.3e', ...
            info.returnResidualNorm);
    end
    if ~info.validation.eventTimingAccepted
        reasons{end+1} = sprintf('solved event-time mismatch %.3e', ...
            info.eventTimeError);
    end
    if ~info.validation.gaitAccepted
        reasons{end+1} = sprintf('classified as %s, expected %s', ...
            info.classifiedGaitClass,info.gaitClass);
    end
end

function value = WrappedDifference(a,b,T)
    value = mod((a-b)+0.5*T,T)-0.5*T;
end

function z = WrapTiming(z)
    z = z(:);
    if numel(z)~=22 || ~isreal(z) || any(~isfinite(z)) || z(22)<=0
        error('CorrectPronkingGaitBranch:InvalidTimingState', ...
            'The candidate must be a finite real 22-vector with positive period.');
    end
    z(14:21)=mod(z(14:21),z(22));
end

function value = FieldOr(structure,names,defaultValue)
    if ischar(names) || isstring(names)
        names = cellstr(names);
    end
    value = defaultValue;
    if ~isstruct(structure)
        return
    end
    for k = 1:numel(names)
        if isfield(structure,names{k}) && ~isempty(structure.(names{k}))
            value = structure.(names{k});
            return
        end
    end
end

function value = SafeNorm(array,p)
    if isempty(array) || any(~isfinite(array(:)))
        value=Inf;
    else
        value=norm(array,p);
    end
end

function output = Ternary(condition,ifTrue,ifFalse)
    if condition
        output=ifTrue;
    else
        output=ifFalse;
    end
end
