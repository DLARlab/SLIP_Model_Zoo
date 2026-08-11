function report = validatePeriodicOrbit(solution, parameters, options)
%VALIDATEPERIODICORBIT Validate a 22-variable periodic-orbit solution.
%
%   REPORT = VALIDATEPERIODICORBIT(SOLUTION22, PARA7, OPTIONS) evaluates a
%   complete apex-to-apex stride with the production timing solve enabled.
%   It separately checks all nine timing equations, the oriented apex
%   section, event order, and the full non-translational fixed-point
%   residual.  REPORT.accepted must be true before finite differencing.

    if nargin < 3
        options = struct();
    end
    floquet.internal.ensureRuntimePaths(false);
    options = floquet.internal.options.resolve(options);
    requestedErrorMode = options.ErrorOnFailure;
    options.ErrorOnFailure = false;

    report = struct();
    report.accepted = false;
    report.valid = false;
    report.status = 'not-evaluated';
    report.rejectionReasons = {};
    report.periodicResidualTolerance = options.PeriodicResidualTolerance;

    validSolution = isnumeric(solution) && isreal(solution) && ...
        isvector(solution) && numel(solution) == 22 && ...
        all(isfinite(solution(:)));
    validParameters = isnumeric(parameters) && isreal(parameters) && ...
        isvector(parameters) && numel(parameters) == 7 && ...
        all(isfinite(parameters(:)) | isinf(parameters(:)));
    if ~validSolution
        report.rejectionReasons{end+1} = ...
            'solution must contain 22 finite values [X(1:13); E(1:9)].';
    end
    if ~validParameters
        report.rejectionReasons{end+1} = ...
            'parameters must contain seven finite values (Para(3) may be Inf).';
    end
    if ~(validSolution && validParameters)
        report = FinishReport(report, requestedErrorMode);
        return;
    end

    solution = solution(:);
    parameters = parameters(:);
    X = solution(1:13);
    eventGuess = solution(14:22);
    report.solution = solution;
    report.parameters = parameters;

    [qInitial, extraction] = ...
        floquet.internal.poincare.extractSectionState(X);
    report.initialSectionState = qInitial;
    report.sectionExtraction = extraction;

    [qReturn, mapInfo] = floquet.internal.poincare.buildMap( ...
        X, eventGuess, parameters, options);
    report.mapInfo = mapInfo;
    report.eventTimingSolverSucceeded = mapInfo.timingSolverConverged;
    report.eventOrderingConsistent = mapInfo.eventOrderingConsistent;
    report.completeStride = mapInfo.completeStride;
    report.initialOnValidApexSection = mapInfo.inputOnSection && ...
        mapInfo.initialApexDescending;
    report.returnOnValidApexSection = mapInfo.returnOnSection && ...
        mapInfo.returnApexDescending;
    report.timingRepeatabilityChecked = options.CheckTimingRepeatability;
    report.timingRepeatable = false;

    if ~mapInfo.accepted
        report.rejectionReasons = [report.rejectionReasons, ...
            PrefixReasons(mapInfo.rejectionReasons, 'Return map: ')];
        report = FinishReport(report, requestedErrorMode);
        return;
    end

    if options.CheckTimingRepeatability
        repeatOptions = options;
        repeatOptions.ReferenceTopology = mapInfo.eventTopology;
        [qRepeat, repeatInfo] = floquet.internal.poincare.buildMap( ...
            X, mapInfo.solvedEventTimes, parameters, repeatOptions);
        repeatability = CompareRepeatedMap( ...
            qReturn, mapInfo, qRepeat, repeatInfo, options);
        report.timingRepeatability = repeatability;
        report.timingRepeatable = repeatability.accepted;
        if ~repeatability.accepted
            report.rejectionReasons = [report.rejectionReasons, ...
                PrefixReasons(repeatability.rejectionReasons, ...
                'Timing repeatability: ')];
            report = FinishReport(report, requestedErrorMode);
            return;
        end
    else
        report.timingRepeatable = true;
        report.timingRepeatability = struct( ...
            'accepted', true, 'checked', false, ...
            'rejectionReasons', {{}}, ...
            'message', 'Timing repeatability check disabled by option.');
    end

    fullReturn = mapInfo.fullReturnState;
    fullResidual = fullReturn - X;
    reducedResidual = qReturn - qInitial;
    report.fullStateReturn = fullReturn;
    report.sectionStateReturn = qReturn;
    report.periodicResidual = fullResidual;
    report.reducedPeriodicResidual = reducedResidual;
    report.periodicResidualNorm2 = norm(fullResidual, 2);
    report.periodicResidualNormInf = norm(fullResidual, inf);
    report.reducedPeriodicResidualNorm2 = norm(reducedResidual, 2);
    report.reducedPeriodicResidualNormInf = norm(reducedResidual, inf);
    report.fixedPointConverged = all(isfinite(fullResidual)) && ...
        report.periodicResidualNormInf <= options.PeriodicResidualTolerance;

    if ~report.fixedPointConverged
        report.rejectionReasons{end+1} = sprintf( ...
            ['Periodic orbit residual is too large: ||P_X(X)-X||_inf=' ...
             '%.3e (tolerance %.3e).'], ...
            report.periodicResidualNormInf, options.PeriodicResidualTolerance);
    end

    report = FinishReport(report, requestedErrorMode);
end

function comparison = CompareRepeatedMap(qFirst, firstInfo, qSecond, secondInfo, options)
    comparison = struct();
    comparison.accepted = false;
    comparison.checked = true;
    comparison.rejectionReasons = {};
    comparison.firstSolvedEventTimes = firstInfo.solvedEventTimes(:);
    comparison.secondMapInfo = secondInfo;
    comparison.tolerance = options.TimingRepeatabilityTolerance;

    if ~secondInfo.accepted
        comparison.rejectionReasons = PrefixReasons( ...
            secondInfo.rejectionReasons, 'Repeated map: ');
        return;
    end

    firstEvents = firstInfo.solvedEventTimes(:);
    secondEvents = secondInfo.solvedEventTimes(:);
    eventDifference = CircularTimingDifference(secondEvents, firstEvents);
    timeScale = max(1, max(abs([firstEvents(9), secondEvents(9)])));
    eventTolerance = options.TimingRepeatabilityTolerance * timeScale;
    returnDifference = qSecond(:) - qFirst(:);
    returnScale = max(1, norm(qFirst, inf));
    returnTolerance = options.TimingRepeatabilityTolerance * returnScale;

    comparison.secondSolvedEventTimes = secondEvents;
    comparison.eventTimingDifference = eventDifference;
    comparison.eventTimingErrorNormInf = norm(eventDifference, inf);
    comparison.eventTimingTolerance = eventTolerance;
    comparison.returnStateDifference = returnDifference;
    comparison.returnStateErrorNormInf = norm(returnDifference, inf);
    comparison.returnStateTolerance = returnTolerance;
    comparison.topologyConsistent = secondInfo.eventOrderingConsistent;

    if comparison.eventTimingErrorNormInf > eventTolerance
        comparison.rejectionReasons{end+1} = sprintf( ...
            ['Solved event times are not repeatable: circular timing error ' ...
             '%.3e exceeds %.3e.'], ...
            comparison.eventTimingErrorNormInf, eventTolerance);
    end
    if comparison.returnStateErrorNormInf > returnTolerance
        comparison.rejectionReasons{end+1} = sprintf( ...
            ['Repeated timing solve changes the Poincare return: state error ' ...
             '%.3e exceeds %.3e.'], ...
            comparison.returnStateErrorNormInf, returnTolerance);
    end
    if ~comparison.topologyConsistent
        comparison.rejectionReasons{end+1} = ...
            'Repeated timing solve changed the reference event topology.';
    end
    comparison.accepted = isempty(comparison.rejectionReasons);
end

function difference = CircularTimingDifference(candidate, reference)
    candidate = candidate(:);
    reference = reference(:);
    difference = candidate - reference;
    period = candidate(9);
    if isfinite(period) && period > 0
        difference(1:8) = mod(difference(1:8) + 0.5*period, period) - ...
            0.5*period;
    end
end

function report = FinishReport(report, errorOnFailure)
    report.accepted = isempty(report.rejectionReasons);
    report.valid = report.accepted;
    if report.accepted
        report.status = 'accepted';
    else
        report.status = 'rejected';
    end

    if ~report.accepted && errorOnFailure
        error('ValidatePeriodicOrbit:Rejected', '%s', ...
            strjoin(report.rejectionReasons, ' | '));
    end
end

function prefixed = PrefixReasons(reasons, prefix)
    prefixed = cell(size(reasons));
    for i = 1:numel(reasons)
        prefixed{i} = [prefix, reasons{i}];
    end
end
