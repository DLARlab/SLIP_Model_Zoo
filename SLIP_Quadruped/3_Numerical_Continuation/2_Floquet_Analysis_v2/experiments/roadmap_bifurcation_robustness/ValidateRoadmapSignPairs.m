function report = ValidateRoadmapSignPairs(attempts, specification, refinement, options)
%VALIDATEROADMAPSIGNPAIRS Verify +/- corrections are leg-swap equivalents.

    if nargin < 4 || isempty(options)
        options = struct();
    end
    opts = ParseOptions(options);
    if ~isstruct(attempts) || isempty(attempts)
        error('ValidateRoadmapSignPairs:Attempts', ...
            'A nonempty correction-attempt array is required.');
    end
    amplitudes = unique([attempts.amplitude],'stable');
    pairs = repmat(EmptyPair(),1,numel(amplitudes));
    for k = 1:numel(amplitudes)
        amplitude = amplitudes(k);
        minus = find([attempts.amplitude] == amplitude & ...
            [attempts.sign] == -1,1);
        plus = find([attempts.amplitude] == amplitude & ...
            [attempts.sign] == 1,1);
        pair = EmptyPair();
        pair.amplitude = amplitude;
        if isempty(minus) || isempty(plus)
            pair.message = 'A perturbation sign is missing.';
            pairs(k) = pair;
            continue
        end
        pair.minusAttemptIndex = minus;
        pair.plusAttemptIndex = plus;
        pair.bothAccepted = attempts(minus).acceptedBranchPoint && ...
            attempts(plus).acceptedBranchPoint;
        if ~pair.bothAccepted
            pair.message = 'Both corrected signs were not accepted branch points.';
            pairs(k) = pair;
            continue
        end
        swappedMinus = ApplyFullSwap( ...
            attempts(minus).zCorrected,specification.ExpectedBrokenPair);
        difference = LocalDifference( ...
            attempts(plus).zCorrected,swappedMinus);
        scale = StateScale(refinement.E);
        pair.scaledDifference = difference./scale;
        pair.scaledErrorNormInf = norm(pair.scaledDifference,inf);
        pair.accepted = pair.scaledErrorNormInf <= opts.PairSwapTolerance;
        if pair.accepted
            pair.message = 'Corrected signs are pair-swap equivalents.';
        else
            pair.message = sprintf('Pair-swap error %.3e exceeds %.3e.', ...
                pair.scaledErrorNormInf,opts.PairSwapTolerance);
        end
        pairs(k) = pair;
    end
    report = struct();
    report.version = 'roadmap-corrected-sign-pair-v1';
    report.brokenPair = specification.ExpectedBrokenPair;
    report.pairs = pairs;
    report.acceptedPairCount = nnz([pairs.accepted]);
    report.requiredPairCount = numel(amplitudes);
    report.accepted = report.acceptedPairCount == report.requiredPairCount;
    report.maximumScaledPairSwapError = max([pairs.scaledErrorNormInf]);
    report.options = opts;
end

function opts = ParseOptions(options)
    opts = struct('PairSwapTolerance',1e-4);
    if ~isstruct(options) || ~isscalar(options)
        error('ValidateRoadmapSignPairs:Options', ...
            'options must be a scalar structure.');
    end
    names = fieldnames(options);
    for k = 1:numel(names)
        if ~strcmpi(names{k},'PairSwapTolerance')
            error('ValidateRoadmapSignPairs:UnknownOption', ...
                'Unknown option %s.',names{k});
        end
        opts.PairSwapTolerance = options.(names{k});
    end
    if ~(isscalar(opts.PairSwapTolerance) && ...
            isfinite(opts.PairSwapTolerance) && opts.PairSwapTolerance > 0)
        error('ValidateRoadmapSignPairs:Tolerance', ...
            'PairSwapTolerance must be positive and finite.');
    end
end

function z = ApplyFullSwap(z,pair)
    z = z(:);
    if numel(z) ~= 22
        error('ValidateRoadmapSignPairs:State', ...
            'Corrected states must contain 22 entries.');
    end
    if strcmp(pair,'hind')
        z = SwapBlocks(z,[6 7],[10 11]);
        z = SwapBlocks(z,[14 15],[18 19]);
    elseif strcmp(pair,'front')
        z = SwapBlocks(z,[8 9],[12 13]);
        z = SwapBlocks(z,[16 17],[20 21]);
    else
        error('ValidateRoadmapSignPairs:Pair', ...
            'Broken pair must be front or hind.');
    end
end

function value = SwapBlocks(value,left,right)
    temporary = value(left);
    value(left) = value(right);
    value(right) = temporary;
end

function difference = LocalDifference(candidate,reference)
    candidate = candidate(:);
    reference = reference(:);
    difference = candidate-reference;
    T = reference(22);
    difference(14:21) = mod(difference(14:21)+0.5*T,T)-0.5*T;
end

function scale = StateScale(E)
    T = E(9);
    scale = [10;1;1;0.5;0.5;0.3*ones(8,1); ...
        max(0.05,0.25*T)*ones(8,1);max(0.1,0.5*T)];
end

function pair = EmptyPair()
    pair = struct('amplitude',NaN,'minusAttemptIndex',NaN, ...
        'plusAttemptIndex',NaN,'bothAccepted',false,'accepted',false, ...
        'scaledDifference',[],'scaledErrorNormInf',Inf,'message','');
end
