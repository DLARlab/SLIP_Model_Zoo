function analysis = AnalyzeRoadmapBifurcationCase(specification, options)
%ANALYZEROADMAPBIFURCATIONCASE Targeted parent-only bifurcation prediction.
%
%   ANALYSIS = ANALYZEROADMAPBIFURCATIONCASE(SPEC,OPTIONS) performs the
%   complete detection/refinement/prediction/correction pipeline using only
%   SPEC.ParentFile.  SPEC.DaughterFile is deliberately not loaded here.
%   Held-out comparison is the separate responsibility of
%   ValidateRoadmapTransition.

    if nargin < 2 || isempty(options)
        options = struct();
    end
    opts = ParseOptions(options);
    ValidateSpecification(specification);
    analysis = InitialAnalysis(specification,opts);

    try
        scanOptions = opts.ScanOptions;
        scanOptions.Verbose = opts.Verbose;
        scan = ComputeRoadmapFloquetScan( ...
            specification.ParentFile,specification.ScanIndices,scanOptions);
        analysis.scan = scan;
        if ~all(scan.accepted)
            error('AnalyzeRoadmapBifurcationCase:RejectedFloquetMap', ...
                '%s accepted only %d/%d parent Floquet maps.', ...
                specification.ID,nnz(scan.accepted),numel(scan.accepted));
        end

        [candidate,candidateDiagnostics] = SelectUniqueCandidate( ...
            scan,specification);
        analysis.candidate = candidate;
        analysis.candidateSelection = candidateDiagnostics;
        analysis.localCoordinateChart = ValidateLocalCoordinateChart( ...
            specification.ParentFile,scan,candidate,opts);

        refinementOptions = opts.RefinementOptions;
        if ~isfield(refinementOptions,'FloquetOptions') || ...
                isempty(refinementOptions.FloquetOptions)
            refinementOptions.FloquetOptions = scan.options.FloquetOptions;
            % Three decreasing levels retain an independent Richardson
            % check while avoiding a redundant coarsest level at every
            % safeguarded critical-orbit iteration.
            refinementOptions.FloquetOptions.PerturbationFactors = [4 2 1];
        end
        refinementOptions.BracketIndices = ...
            analysis.localCoordinateChart.branchColumns;
        refinementOptions.ThrowOnFailure = false;
        [criticalSolution,refinement] = RefineCriticalOrbit( ...
            scan,candidate,refinementOptions);
        analysis.criticalSolution = criticalSolution;
        analysis.refinement = refinement;
        if ~refinement.accepted
            error('AnalyzeRoadmapBifurcationCase:RefinementRejected', ...
                '%s refinement failed: %s',specification.ID, ...
                JoinReasons(refinement));
        end
        analysis.refinedLocation = ValidateRefinedLocation( ...
            specification.ParentFile,refinement, ...
            analysis.localCoordinateChart,opts);
        if ~refinement.branchSwitchReady
            error('AnalyzeRoadmapBifurcationCase:BranchSwitchNotReady', ...
                '%s: %s',specification.ID, ...
                refinement.branchSwitchReadyReason);
        end
        analysis.symmetry = ResolveRoadmapSymmetryBreakingMode( ...
            refinement,specification,opts.SymmetryOptions);
        if ~analysis.symmetry.accepted
            error('AnalyzeRoadmapBifurcationCase:SymmetryResolutionRejected', ...
                '%s critical mode failed the expected %s-swap checks: %s', ...
                specification.ID,specification.ExpectedBrokenPair, ...
                strjoin(analysis.symmetry.rejectionReasons,' | '));
        end

        analysis.attempts = RunPredictorCorrectorGrid( ...
            refinement,specification,opts);
        analysis.signPairSymmetry = ValidateRoadmapSignPairs( ...
            analysis.attempts,specification,refinement,opts.SignPairOptions);
        analysis.parentOnlyValidation = EvaluateParentOnlyValidation( ...
            analysis,opts);
        analysis.accepted = analysis.parentOnlyValidation.accepted;
        analysis.status = Ternary(analysis.accepted, ...
            'targeted-parent-only-prediction-validated', ...
            'targeted-parent-only-prediction-rejected');
        analysis.completedAt = Timestamp();
        if opts.Verbose
            PrintSummary(analysis);
        end
        if opts.ThrowOnFailure && ~analysis.accepted
            error('AnalyzeRoadmapBifurcationCase:ParentOnlyValidationRejected', ...
                '%s',strjoin(analysis.parentOnlyValidation.rejectionReasons,' | '));
        end
    catch exception
        analysis.accepted = false;
        analysis.status = 'failed';
        analysis.completedAt = Timestamp();
        analysis.failure = struct('identifier',exception.identifier, ...
            'message',exception.message, ...
            'report',getReport(exception,'extended','hyperlinks','off'));
        if opts.Verbose
            fprintf('  %s failed: %s\n',specification.ID,exception.message);
        end
        if opts.ThrowOnFailure
            rethrow(exception);
        end
    end
end

function opts = ParseOptions(options)
    if ~isstruct(options) || ~isscalar(options)
        error('AnalyzeRoadmapBifurcationCase:InvalidOptions', ...
            'options must be a scalar structure.');
    end
    defaults = struct();
    defaults.ScanOptions = struct();
    defaults.RefinementOptions = struct( ...
        'CoordinateTolerance',5e-6, ...
        'MultiplierTolerance',2e-6, ...
        'CriticalMultiplierUncertaintyTolerance',2e-6, ...
        'ClusterSpreadTolerance',2e-5, ...
        'MinimumModeOverlap',0.35, ...
        'MinimumSubspaceOverlap',0.35, ...
        'MaxIterations',25, ...
        'StoreFullFloquetDiagnostics',false);
    defaults.MapOptions = struct( ...
        'TopologyMode','clustered', ...
        'CheckTimingRepeatability',true, ...
        'ErrorOnFailure',false);
    defaults.SymmetryOptions = struct();
    defaults.PredictorOptions = struct( ...
        'TimingLiftMode','one-sided-sector', ...
        'TimingProbeFactor',1, ...
        'RequireAdditionalNullDirection',true);
    defaults.CorrectorOptions = struct( ...
        'ConstraintMode','oriented-amplitude', ...
        'ResidualTolerance',1e-8, ...
        'ConstraintTolerance',1e-7, ...
        'ReturnMapTolerance',1e-7, ...
        'EventTimeTolerance',1e-6, ...
        'ValidateWithPoincareMap',true, ...
        'ThrowOnFailure',false);
    defaults.SignPairOptions = struct('PairSwapTolerance',1e-4);
    defaults.PredictionAmplitudes = [1e-2 5e-3];
    defaults.PerturbationSigns = [-1 1];
    defaults.MinimumAcceptedRadiiPerSign = 2;
    defaults.MinimumCoordinateIncrement = 1e-7;
    defaults.MaximumRefinedChordError = 0.05;
    defaults.MinimumTransverseFraction = 0.2;
    defaults.Verbose = true;
    defaults.ThrowOnFailure = false;

    opts = defaults;
    names = fieldnames(options);
    allowed = fieldnames(defaults);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k},allowed),1);
        if isempty(hit)
            error('AnalyzeRoadmapBifurcationCase:UnknownOption', ...
                'Unknown option %s.',names{k});
        end
        opts.(allowed{hit}) = options.(names{k});
    end
    nested = {'ScanOptions','RefinementOptions','MapOptions', ...
        'SymmetryOptions', ...
        'PredictorOptions','CorrectorOptions','SignPairOptions'};
    for k = 1:numel(nested)
        if ~isstruct(opts.(nested{k})) || ~isscalar(opts.(nested{k}))
            error('AnalyzeRoadmapBifurcationCase:NestedOptions', ...
                '%s must be a scalar structure.',nested{k});
        end
    end
    opts.PredictionAmplitudes = unique( ...
        opts.PredictionAmplitudes(:).','stable');
    if isempty(opts.PredictionAmplitudes) || ...
            any(~isfinite(opts.PredictionAmplitudes)) || ...
            any(opts.PredictionAmplitudes <= 0)
        error('AnalyzeRoadmapBifurcationCase:PredictionAmplitudes', ...
            'PredictionAmplitudes must be positive finite values.');
    end
    opts.PerturbationSigns = unique(opts.PerturbationSigns(:).','stable');
    if ~isequal(sort(opts.PerturbationSigns),[-1 1])
        error('AnalyzeRoadmapBifurcationCase:PerturbationSigns', ...
            'Both and only perturbation signs -1 and +1 are required.');
    end
    if ~(isscalar(opts.MinimumAcceptedRadiiPerSign) && ...
            opts.MinimumAcceptedRadiiPerSign >= 1 && ...
            opts.MinimumAcceptedRadiiPerSign == ...
                floor(opts.MinimumAcceptedRadiiPerSign) && ...
            opts.MinimumAcceptedRadiiPerSign <= ...
                numel(opts.PredictionAmplitudes))
        error('AnalyzeRoadmapBifurcationCase:PersistenceCount', ...
            'MinimumAcceptedRadiiPerSign is inconsistent with the amplitude grid.');
    end
    positives = {'MinimumCoordinateIncrement','MaximumRefinedChordError', ...
        'MinimumTransverseFraction'};
    for k = 1:numel(positives)
        value = opts.(positives{k});
        if ~(isscalar(value) && isfinite(value) && value > 0)
            error('AnalyzeRoadmapBifurcationCase:PositiveOption', ...
                '%s must be positive and finite.',positives{k});
        end
    end
    if opts.MinimumTransverseFraction >= 1
        error('AnalyzeRoadmapBifurcationCase:TransverseFraction', ...
            'MinimumTransverseFraction must be below one.');
    end
    opts.Verbose = ValidateLogical(opts.Verbose,'Verbose');
    opts.ThrowOnFailure = ValidateLogical(opts.ThrowOnFailure,'ThrowOnFailure');
end

function ValidateSpecification(spec)
    required = {'ID','ParentFile','ParentCode','ExpectedCandidateType', ...
        'ExpectedGaitAbbreviation','ScanIndices'};
    if ~isstruct(spec) || ~isscalar(spec)
        error('AnalyzeRoadmapBifurcationCase:Specification', ...
            'specification must be a scalar registry item.');
    end
    for k = 1:numel(required)
        if ~isfield(spec,required{k}) || isempty(spec.(required{k}))
            error('AnalyzeRoadmapBifurcationCase:Specification', ...
                'Specification lacks %s.',required{k});
        end
    end
    if ~isfile(spec.ParentFile)
        error('AnalyzeRoadmapBifurcationCase:MissingParent', ...
            'Missing parent branch %s.',spec.ParentFile);
    end
end

function analysis = InitialAnalysis(spec,opts)
    analysis = struct();
    analysis.version = 'roadmap-targeted-parent-transition-analysis-v1';
    analysis.ID = spec.ID;
    analysis.specification = spec;
    analysis.startedAt = Timestamp();
    analysis.completedAt = '';
    analysis.status = 'running';
    analysis.accepted = false;
    analysis.options = opts;
    analysis.parentOnlyStages = { ...
        'reduced Floquet scan','candidate selection', ...
        'critical-orbit refinement','timing lift','nonlinear correction'};
    analysis.heldOutStagesRun = {};
    analysis.daughterDataLoaded = false;
    analysis.scan = struct();
    analysis.candidate = struct();
    analysis.candidateSelection = struct();
    analysis.localCoordinateChart = struct();
    analysis.criticalSolution = [];
    analysis.refinement = struct();
    analysis.refinedLocation = struct();
    analysis.symmetry = struct();
    analysis.attempts = repmat(EmptyAttempt(),1,0);
    analysis.signPairSymmetry = struct();
    analysis.parentOnlyValidation = struct();
    analysis.failure = struct();
end

function [candidate,diagnostics] = SelectUniqueCandidate(scan,spec)
    candidates = scan.candidates;
    keep = false(1,numel(candidates));
    for k = 1:numel(candidates)
        keep(k) = strcmp(FieldText(candidates(k),'Type',''), ...
                spec.ExpectedCandidateType) && ...
            strcmp(FieldText(candidates(k), ...
                'NullDirectionClassification',''), ...
                'additional-null-direction') && ...
            LogicalField(candidates(k),'IsAdditionalNullDirection',false) && ...
            ~LogicalField(candidates(k),'IsTrivialBranchTangent',true);
    end
    selected = find(keep);
    diagnostics = struct('candidateCount',numel(candidates), ...
        'eligibleIndices',selected,'eligibleCount',numel(selected), ...
        'allCandidateTypes',{{candidates.Type}}, ...
        'selectionUsesDaughterData',false);
    if numel(selected) ~= 1
        error('AnalyzeRoadmapBifurcationCase:CandidateCount', ...
            ['%s expected exactly one persistent additional +1 candidate ' ...
             'inside its predeclared parent window; found %d.'], ...
            spec.ID,numel(selected));
    end
    candidate = candidates(selected);
end

function chart = ValidateLocalCoordinateChart(filename,scan,candidate,opts)
    loaded = load(filename,'results');
    branch = loaded.results;
    local = [candidate.LeftIndex candidate.RightIndex];
    columns = scan.sampleIndices(local);
    if numel(columns) ~= 2 || abs(diff(columns)) ~= 1
        error('AnalyzeRoadmapBifurcationCase:NonadjacentBracket', ...
            'The selected crossing does not use adjacent parent columns.');
    end
    first = min(columns);
    last = max(columns);
    neighborhood = max(1,first-1):min(size(branch,2),last+1);
    coordinates = branch(1,neighborhood);
    increments = diff(coordinates);
    bracketIncrement = diff(branch(1,columns));
    sameOrientation = all(sign(increments) == sign(bracketIncrement));
    incrementResolved = abs(bracketIncrement) >= opts.MinimumCoordinateIncrement;
    if ~sameOrientation || ~incrementResolved
        error('AnalyzeRoadmapBifurcationCase:UnsafeCoordinateChart', ...
            ['The local X(1)=dx chart crosses or is unresolved near a fold. ' ...
             'Use a pseudo-arclength refiner for this bracket.']);
    end
    chart = struct();
    chart.accepted = true;
    chart.branchColumns = columns;
    chart.neighborhoodColumns = neighborhood;
    chart.coordinates = coordinates;
    chart.increments = increments;
    chart.bracketCoordinate = branch(1,columns);
    chart.bracketIncrement = bracketIncrement;
    chart.orientation = sign(bracketIncrement);
    chart.minimumAbsoluteIncrement = min(abs(increments));
    chart.foldDetected = false;
    chart.coordinateName = 'X(1)=initial horizontal speed';
end

function location = ValidateRefinedLocation(filename,refinement,chart,opts)
    loaded = load(filename,'results');
    branch = loaded.results;
    columns = chart.branchColumns;
    qIndex = [1 2 4:13];
    qLeft = branch(qIndex,columns(1));
    qRight = branch(qIndex,columns(2));
    xLeft = branch(1,columns(1));
    xRight = branch(1,columns(2));
    alpha = (refinement.coordinate-xLeft)/(xRight-xLeft);
    qChord = (1-alpha)*qLeft + alpha*qRight;
    qScale = max(abs(refinement.X(qIndex)),[1;1;0.5*ones(10,1)]);
    chordError = norm((refinement.X(qIndex)-qChord)./qScale);
    inside = alpha >= -1e-8 && alpha <= 1+1e-8;
    accepted = inside && isfinite(chordError) && ...
        chordError <= opts.MaximumRefinedChordError;
    location = struct('accepted',accepted,'alpha',alpha, ...
        'insideBracket',inside,'scaledChordError',chordError, ...
        'maximumScaledChordError',opts.MaximumRefinedChordError, ...
        'branchColumns',columns,'coordinate',refinement.coordinate);
    if ~accepted
        error('AnalyzeRoadmapBifurcationCase:RefinementLeftLocalSegment', ...
            ['Refined orbit did not remain on the verified local parent ' ...
             'segment (alpha %.6g, chord error %.3e).'],alpha,chordError);
    end
end

function attempts = RunPredictorCorrectorGrid(refinement,spec,opts)
    count = numel(opts.PredictionAmplitudes)*numel(opts.PerturbationSigns);
    attempts = repmat(EmptyAttempt(),1,count);
    cursor = 0;
    for radiusIndex = 1:numel(opts.PredictionAmplitudes)
        amplitude = opts.PredictionAmplitudes(radiusIndex);
        for signValue = opts.PerturbationSigns
            cursor = cursor+1;
            attempt = EmptyAttempt();
            attempt.index = cursor;
            attempt.radiusIndex = radiusIndex;
            attempt.amplitude = amplitude;
            attempt.sign = signValue;
            try
                predictorOptions = opts.PredictorOptions;
                predictorOptions.Amplitude = amplitude;
                predictorOptions.PerturbationSign = signValue;
                predictorOptions.MapOptions = opts.MapOptions;
                predictorOptions.ExpectedTopology = refinement.topology;
                predictorOptions.BranchTangent = ...
                    refinement.localBranchTangent;
                if isfield(refinement.eigenData,'StateScale')
                    predictorOptions.StateScale = ...
                        refinement.eigenData.StateScale;
                end
                [deltaZ,zPredictor,predictorInfo] = ...
                    PredictBranchDirection(refinement.X,refinement.E, ...
                        refinement.parameters,refinement.eigenData, ...
                        predictorOptions);
                attempt.predictorAccepted = true;
                attempt.deltaZ = deltaZ;
                attempt.zPredictor = zPredictor;
                attempt.predictorInfo = predictorInfo;
            catch predictorError
                attempt.rejectionStage = 'predictor';
                attempt.rejectionIdentifier = predictorError.identifier;
                attempt.rejectionMessage = predictorError.message;
                attempts(cursor) = attempt;
                continue
            end

            try
                correctorOptions = opts.CorrectorOptions;
                correctorOptions.MapOptions = opts.MapOptions;
                correctorOptions.ExpectedTopology = ...
                    predictorInfo.sectorTopology;
                [zCorrected,correctorInfo] = CorrectBranchSwitch( ...
                    refinement.X,refinement.E,refinement.parameters, ...
                    predictorInfo,correctorOptions);
                attempt.correctorAccepted = correctorInfo.accepted;
                attempt.zCorrected = zCorrected;
                attempt.correctorInfo = correctorInfo;
                if correctorInfo.accepted
                    attempt = CharacterizeCorrection( ...
                        attempt,refinement,spec,opts);
                else
                    attempt.rejectionStage = 'corrector-validation';
                    attempt.rejectionIdentifier = ...
                        'CorrectBranchSwitch:CorrectionRejected';
                    attempt.rejectionMessage = correctorInfo.message;
                end
            catch correctorError
                attempt.rejectionStage = 'corrector';
                attempt.rejectionIdentifier = correctorError.identifier;
                attempt.rejectionMessage = correctorError.message;
            end
            attempts(cursor) = attempt;
        end
    end
end

function attempt = CharacterizeCorrection(attempt,refinement,spec,opts)
    z = attempt.zCorrected(:);
    qIndex = [1 2 4:13];
    scale = refinement.eigenData.StateScale(:);
    displacement = (z(qIndex)-refinement.X(qIndex))./scale;
    tangent = refinement.localBranchTangent(:)./scale;
    tangent = tangent/norm(tangent);
    transverse = displacement-tangent*(tangent'*displacement);
    totalNorm = norm(displacement);
    transverseNorm = norm(transverse);
    attempt.scaledStateDisplacement = displacement;
    attempt.scaledTransverseDirection = transverse/max(transverseNorm,eps);
    attempt.scaledDisplacementNorm = totalNorm;
    attempt.scaledTransverseNorm = transverseNorm;
    attempt.transverseFraction = transverseNorm/max(totalNorm,eps);
    try
        [gait,abbreviation] = Gait_Identification(z);
        attempt.gait = char(string(gait));
        attempt.gaitAbbreviation = char(string(abbreviation));
    catch gaitError
        attempt.gait = '';
        attempt.gaitAbbreviation = '';
        attempt.gaitClassificationError = sprintf('%s: %s', ...
            gaitError.identifier,gaitError.message);
    end
    attempt.expectedGait = strcmp( ...
        attempt.gaitAbbreviation,spec.ExpectedGaitAbbreviation);
    attempt.nonParent = attempt.transverseFraction >= ...
        opts.MinimumTransverseFraction;
    attempt.acceptedBranchPoint = attempt.correctorAccepted && ...
        attempt.expectedGait && attempt.nonParent;
    if ~attempt.acceptedBranchPoint
        attempt.rejectionStage = 'gait-or-transverse-validation';
        attempt.rejectionIdentifier = ...
            'AnalyzeRoadmapBifurcationCase:UnexpectedCorrectedBranch';
        attempt.rejectionMessage = sprintf( ...
            'gait=%s expected=%s transverse fraction=%.3e', ...
            attempt.gaitAbbreviation,spec.ExpectedGaitAbbreviation, ...
            attempt.transverseFraction);
    end
end

function validation = EvaluateParentOnlyValidation(analysis,opts)
    attempts = analysis.attempts;
    signs = opts.PerturbationSigns;
    acceptedPerSign = zeros(size(signs));
    predictorPerSign = zeros(size(signs));
    correctorPerSign = zeros(size(signs));
    for k = 1:numel(signs)
        selected = [attempts.sign] == signs(k);
        predictorPerSign(k) = nnz([attempts(selected).predictorAccepted]);
        correctorPerSign(k) = nnz([attempts(selected).correctorAccepted]);
        acceptedPerSign(k) = nnz([attempts(selected).acceptedBranchPoint]);
    end
    assertions = struct();
    assertions.allFloquetMapsAccepted = all(analysis.scan.accepted);
    assertions.uniquePersistentAdditionalPlusOne = ...
        analysis.candidateSelection.eligibleCount == 1;
    assertions.localCoordinateChartAccepted = ...
        analysis.localCoordinateChart.accepted;
    assertions.criticalRefinementAccepted = analysis.refinement.accepted;
    assertions.refinedPointStayedOnLocalSegment = ...
        analysis.refinedLocation.accepted;
    assertions.branchSwitchDirectionVerified = ...
        analysis.refinement.branchSwitchReady;
    assertions.expectedPairSwapModeVerified = analysis.symmetry.accepted;
    assertions.bothSectorTimingLiftsAccepted = ...
        all(predictorPerSign >= opts.MinimumAcceptedRadiiPerSign);
    assertions.bothNonlinearBranchesAccepted = ...
        all(acceptedPerSign >= opts.MinimumAcceptedRadiiPerSign);
    assertions.correctedSignsArePairSwapEquivalent = ...
        analysis.signPairSymmetry.accepted;
    names = fieldnames(assertions);
    values = false(size(names));
    for k = 1:numel(names)
        values(k) = logical(assertions.(names{k}));
    end
    validation = struct();
    validation.accepted = all(values);
    validation.assertions = assertions;
    validation.predictorAcceptedPerSign = predictorPerSign;
    validation.correctorAcceptedPerSign = correctorPerSign;
    validation.acceptedBranchPointsPerSign = acceptedPerSign;
    validation.minimumAcceptedRadiiPerSign = ...
        opts.MinimumAcceptedRadiiPerSign;
    validation.rejectionReasons = names(~values).';
    validation.daughterDataUsed = false;
    validation.scope = ['targeted parent-only calculation in a predeclared ' ...
        'historical window; not an exhaustive branch-wide blind search'];
end

function attempt = EmptyAttempt()
    attempt = struct('index',NaN,'radiusIndex',NaN,'amplitude',NaN, ...
        'sign',NaN,'predictorAccepted',false,'correctorAccepted',false, ...
        'acceptedBranchPoint',false,'deltaZ',[],'zPredictor',[], ...
        'zCorrected',[],'predictorInfo',struct(),'correctorInfo',struct(), ...
        'gait','','gaitAbbreviation','','gaitClassificationError','', ...
        'expectedGait',false,'nonParent',false, ...
        'scaledStateDisplacement',[],'scaledTransverseDirection',[], ...
        'scaledDisplacementNorm',NaN,'scaledTransverseNorm',NaN, ...
        'transverseFraction',NaN,'rejectionStage','', ...
        'rejectionIdentifier','','rejectionMessage','');
end

function PrintSummary(analysis)
    refinement = analysis.refinement;
    accepted = nnz([analysis.attempts.acceptedBranchPoint]);
    fprintf(['  %s: dx=%.12g, lambda=%.9g%+.9gi, ' ...
        'branch points=%d/%d, status=%s\n'], ...
        analysis.ID,refinement.coordinate,real(refinement.multiplier), ...
        imag(refinement.multiplier),accepted,numel(analysis.attempts), ...
        analysis.status);
end

function value = ValidateLogical(value,name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
        error('AnalyzeRoadmapBifurcationCase:LogicalOption', ...
            '%s must be scalar logical.',name);
    end
    value = logical(value);
end

function value = FieldText(input,name,default)
    if isstruct(input) && isfield(input,name)
        value = char(string(input.(name)));
    else
        value = default;
    end
end

function value = LogicalField(input,name,default)
    if isstruct(input) && isfield(input,name) && ...
            isscalar(input.(name)) && ...
            (islogical(input.(name)) || isnumeric(input.(name))) && ...
            isfinite(double(input.(name)))
        value = logical(input.(name));
    else
        value = default;
    end
end

function message = JoinReasons(input)
    if isstruct(input) && isfield(input,'rejectionReasons') && ...
            ~isempty(input.rejectionReasons)
        message = strjoin(input.rejectionReasons,' | ');
    elseif isstruct(input) && isfield(input,'exceptionMessage')
        message = input.exceptionMessage;
    else
        message = 'unspecified refinement failure';
    end
end

function value = Ternary(condition,a,b)
    if condition
        value = a;
    else
        value = b;
    end
end

function value = Timestamp()
    value = char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
end
