function [sectionReturn, info] = buildMap(X, eventGuess, parameters, options)
%BUILDPOINCAREMAP Evaluate the reduced apex-to-apex return map.
%
%   [QRETURN, INFO] = BUILDPOINCAREMAP(X, EGUESS, PARA, OPTIONS) calls the
%   production Quadrupedal_ZeroFun_v2 entry point normally (never with
%   'skipSolve').  Consequently its existing timing solver determines the
%   event times appropriate to X.  The authoritative solved timings are
%   read from P(1:9), and no event-time component is part of QRETURN.
%
%   X       : 13-state initial condition on dy=0
%   EGUESS  : 9 timing guesses used only to initialize the timing solver
%   PARA    : 7 production model parameters
%   QRETURN : 12-state return X_APEX([1 2 4:13])
%
%   INFO.accepted is false and QRETURN is empty whenever the timing solve,
%   section orientation, stride coverage, or event topology is invalid.

    if nargin < 4
        options = struct();
    end
    options = floquet.internal.options.resolve(options);

    sectionReturn = [];
    info = InitialDiagnostics(options);

    [validInputs, inputReasons, Xcolumn, Ecolumn, parameterColumn] = ...
        ValidateInputs(X, eventGuess, parameters);
    info.rejectionReasons = [info.rejectionReasons, inputReasons];
    if ~validInputs
        info = FinalizeDiagnostics(info, options);
        return;
    end

    info.inputState = Xcolumn;
    info.inputEventGuess = Ecolumn;
    info.parameters = parameterColumn;
    info.inputSectionVelocity = Xcolumn(3);
    info.inputSectionConstraintError = abs(Xcolumn(3));
    info.inputOnSection = info.inputSectionConstraintError <= ...
        options.SectionTolerance;
    if ~info.inputOnSection
        info.rejectionReasons{end+1} = sprintf( ...
            'Initial state is not on dy=0: |dy|=%.3e exceeds %.3e.', ...
            info.inputSectionConstraintError, options.SectionTolerance);
    end

    Xrow = Xcolumn.';
    Erow = Ecolumn.';
    parameterRow = parameterColumn.';
    dynamicsFunction = options.DynamicsFunction;
    constraints = options.Constraints;

    try
        if options.SuppressDynamicsOutput
            [~, residual, T, Y, P, GRFs, Y_EVENT] = evalc( ...
                'dynamicsFunction(Xrow, Erow, parameterRow, constraints)');
        else
            [residual, T, Y, P, GRFs, Y_EVENT] = ...
                dynamicsFunction(Xrow, Erow, parameterRow, constraints);
        end
        info.dynamicsCallSucceeded = true;
    catch exception
        info.dynamicsExceptionIdentifier = exception.identifier;
        info.dynamicsExceptionMessage = exception.message;
        info.rejectionReasons{end+1} = sprintf( ...
            'Dynamics/event-timing call failed: %s', exception.message);
        info = FinalizeDiagnostics(info, options);
        return;
    end

    residual = residual(:);
    P = P(:);
    info.residualCount = numel(residual);
    info.residual = residual;

    if numel(P) < 9 || any(~isfinite(P(1:min(9,numel(P)))))
        info.rejectionReasons{end+1} = ...
            'Dynamics output P does not contain nine finite solved event times.';
    else
        solvedEventTimes = P(1:9);
        info.solvedEventTimes = solvedEventTimes;
        info.eventTimingCorrection = TimingDifference(solvedEventTimes, Ecolumn);
        info.eventTopology = ...
            floquet.internal.events.classifyTopology(solvedEventTimes, options);
        if ~info.eventTopology.valid
            info.rejectionReasons = [info.rejectionReasons, ...
                PrefixReasons(info.eventTopology.rejectionReasons, 'Event topology: ')];
        end
    end

    if numel(residual) < 9
        info.rejectionReasons{end+1} = sprintf( ...
            'Dynamics returned only %d residuals; all nine timing residuals are required.', ...
            numel(residual));
    else
        info.timingResidual = residual(1:9);
        info.timingResidualAbsolute = abs(info.timingResidual);
        info.timingResidualNormInf = norm(info.timingResidual, inf);
        info.timingResidualsFinite = all(isfinite(info.timingResidual));
        info.timingSolverConverged = info.timingResidualsFinite && ...
            info.timingResidualNormInf <= options.TimingResidualTolerance;
        if ~info.timingSolverConverged
            info.rejectionReasons{end+1} = sprintf( ...
                ['Event timing solver failed the nine-equation residual test: ' ...
                 '||r_timing||_inf=%.3e (tolerance %.3e).'], ...
                info.timingResidualNormInf, options.TimingResidualTolerance);
        end
    end

    trajectoryValid = isnumeric(T) && isreal(T) && isvector(T) && ~isempty(T) && ...
        isnumeric(Y) && isreal(Y) && ismatrix(Y) && size(Y,1) == numel(T) && ...
        size(Y,2) >= 14 && all(isfinite(T(:))) && ...
        all(isfinite(Y(:)));
    eventStatesValid = isnumeric(Y_EVENT) && isreal(Y_EVENT) && ismatrix(Y_EVENT) && ...
        size(Y_EVENT,1) >= 9 && size(Y_EVENT,2) >= 14 && ...
        all(all(isfinite(Y_EVENT(1:9,1:14))));
    grfValid = isnumeric(GRFs) && isreal(GRFs) && ismatrix(GRFs) && ...
        trajectoryValid && size(GRFs,1) == size(Y,1) && ...
        size(GRFs,2) >= max(options.VerticalGRFColumns) && ...
        all(isfinite(GRFs(:)));

    info.trajectoryOutputValid = trajectoryValid;
    info.eventStateOutputValid = eventStatesValid;
    info.groundReactionForceOutputValid = grfValid;
    if ~trajectoryValid
        info.rejectionReasons{end+1} = ...
            'Trajectory output is empty, nonfinite, or has an invalid shape.';
    end
    if ~eventStatesValid
        info.rejectionReasons{end+1} = ...
            'Y_EVENT does not contain nine finite 14-state event rows.';
    end
    if ~grfValid
        info.rejectionReasons{end+1} = ...
            'GRFs does not contain finite vertical force columns 9:12 for every state row.';
    end

    if trajectoryValid && isfield(info, 'solvedEventTimes')
        period = info.solvedEventTimes(9);
        timeScale = max(1, abs(period));
        timeTolerance = options.StrideTimeTolerance * timeScale;
        info.period = period;
        info.trajectoryStartTime = T(1);
        info.trajectoryEndTime = T(end);
        info.trajectoryTimeMonotonic = all(diff(T(:)) >= -timeTolerance);
        info.strideStartError = abs(T(1));
        info.strideEndError = abs(T(end) - period);
        info.completeStride = isfinite(period) && period > 0 && ...
            info.strideStartError <= timeTolerance && ...
            info.strideEndError <= timeTolerance && ...
            info.trajectoryTimeMonotonic;
        if ~info.completeStride
            info.rejectionReasons{end+1} = sprintf( ...
                ['Trajectory does not cover one complete nondecreasing stride: ' ...
                 'T(1)=%.16g, T(end)=%.16g, period=%.16g.'], ...
                T(1), T(end), period);
        end
    end

    if trajectoryValid && eventStatesValid
        fullReturn = Y_EVENT(9,2:14).';
        trajectoryReturn = Y(end,2:14).';
        info.fullReturnState = fullReturn;
        info.trajectoryFinalState = trajectoryReturn;
        info.apexEventFinalStateMismatch = norm( ...
            fullReturn - trajectoryReturn, inf);
        consistencyScale = max(1, norm(fullReturn, inf));
        info.apexIsTerminalEvent = info.apexEventFinalStateMismatch <= ...
            options.TrajectoryConsistencyTolerance * consistencyScale;
        if ~info.apexIsTerminalEvent
            info.rejectionReasons{end+1} = sprintf( ...
                ['The recorded apex state is not the terminal stride state ' ...
                 '(mismatch %.3e).'], info.apexEventFinalStateMismatch);
        end

        info.returnSectionVelocity = fullReturn(3);
        info.returnSectionConstraintError = abs(fullReturn(3));
        info.returnOnSection = info.returnSectionConstraintError <= ...
            options.SectionTolerance;
        if ~info.returnOnSection
            info.rejectionReasons{end+1} = sprintf( ...
                'Return state is not on dy=0: |dy|=%.3e exceeds %.3e.', ...
                info.returnSectionConstraintError, options.SectionTolerance);
        end

        [candidateReturn, extractionInfo] = ...
            floquet.internal.poincare.extractSectionState(fullReturn);
        info.sectionExtraction = extractionInfo;
    else
        candidateReturn = [];
    end

    if grfValid
        verticalColumns = options.VerticalGRFColumns;
        info.initialVerticalGRF = sum(GRFs(1,verticalColumns));
        info.returnVerticalGRF = sum(GRFs(end,verticalColumns));
        info.initialVerticalAcceleration = ...
            info.initialVerticalGRF - options.Gravity;
        info.returnVerticalAcceleration = ...
            info.returnVerticalGRF - options.Gravity;
        info.initialApexDescending = info.initialVerticalAcceleration < ...
            -options.ApexAccelerationTolerance;
        info.returnApexDescending = info.returnVerticalAcceleration < ...
            -options.ApexAccelerationTolerance;
        if ~info.initialApexDescending
            info.rejectionReasons{end+1} = sprintf( ...
                ['Initial dy=0 point is not a downward-curvature apex: ' ...
                 'ddy=%.3e must be below -%.3e.'], ...
                info.initialVerticalAcceleration, options.ApexAccelerationTolerance);
        end
        if ~info.returnApexDescending
            info.rejectionReasons{end+1} = sprintf( ...
                ['Return dy=0 point is not a downward-curvature apex: ' ...
                 'ddy=%.3e must be below -%.3e.'], ...
                info.returnVerticalAcceleration, options.ApexAccelerationTolerance);
        end
    end

    if isfield(info, 'eventTopology') && info.eventTopology.valid
        if isempty(options.ReferenceTopology)
            info.topologyComparison = struct( ...
                'valid', true, 'consistent', true, ...
                'mode', options.TopologyMode, ...
                'rejectionReasons', {{}}, ...
                'referenceSignature', info.eventTopology.signature, ...
                'candidateSignature', info.eventTopology.signature, ...
                'minimumInterclusterPhaseGap', NaN, ...
                'maximumReferenceClusterPhaseSpread', 0, ...
                'referenceClusterSplitSensitivity', ...
                    zeros(info.eventTopology.clusterCount,1));
        else
            info.topologyComparison = ...
                floquet.internal.events.compareTopology( ...
                options.ReferenceTopology, info.eventTopology, options);
            if ~info.topologyComparison.consistent
                info.rejectionReasons = [info.rejectionReasons, ...
                    PrefixReasons(info.topologyComparison.rejectionReasons, ...
                    'Event topology changed: ')];
            end
        end
        info.eventOrderingConsistent = info.topologyComparison.consistent;
    else
        info.eventOrderingConsistent = false;
    end

    if options.StoreTrajectories && info.dynamicsCallSucceeded
        info.trajectory = struct('T', T, 'Y', Y, 'P', P, ...
            'GRFs', GRFs, 'Y_EVENT', Y_EVENT);
    end

    info = FinalizeDiagnostics(info, options);
    if info.accepted
        sectionReturn = candidateReturn;
    end
end

function info = InitialDiagnostics(options)
    info = struct();
    info.accepted = false;
    info.valid = false;
    info.status = 'not-evaluated';
    info.rejectionReasons = {};
    info.dynamicsCallSucceeded = false;
    info.dynamicsExceptionIdentifier = '';
    info.dynamicsExceptionMessage = '';
    info.timingSolverConverged = false;
    info.completeStride = false;
    info.inputOnSection = false;
    info.returnOnSection = false;
    info.initialApexDescending = false;
    info.returnApexDescending = false;
    info.eventOrderingConsistent = false;
    info.reducedStateIndices = options.ReducedStateIndices(:);
    info.sectionNormalStateIndex = options.SectionStateIndex;
    info.tolerances = struct( ...
        'timingResidual', options.TimingResidualTolerance, ...
        'section', options.SectionTolerance, ...
        'apexAcceleration', options.ApexAccelerationTolerance, ...
        'strideTime', options.StrideTimeTolerance, ...
        'topologyCluster', options.TopologyClusterTolerance, ...
        'topologyOrder', options.TopologyOrderTolerance);
end

function [valid, reasons, X, E, parameters] = ValidateInputs(X, E, parameters)
    reasons = {};
    validX = isnumeric(X) && isreal(X) && isvector(X) && numel(X) == 13 && ...
        all(isfinite(X(:)));
    validE = isnumeric(E) && isreal(E) && isvector(E) && numel(E) == 9 && ...
        all(isfinite(E(:)));
    validParameters = isnumeric(parameters) && isreal(parameters) && isvector(parameters) && ...
        numel(parameters) == 7 && all(isfinite(parameters(:)) | isinf(parameters(:)));

    if ~validX
        reasons{end+1} = 'X must contain 13 finite model states.';
    end
    if ~validE
        reasons{end+1} = 'eventGuess must contain nine finite timing values.';
    elseif ~(E(9) > 0)
        reasons{end+1} = 'The guessed apex return time E(9) must be positive.';
        validE = false;
    end
    if ~validParameters
        reasons{end+1} = 'parameters must contain seven finite values (J may be Inf).';
    elseif any(isinf(parameters(:)) & ((1:7).' ~= 3))
        reasons{end+1} = 'Only the inertia parameter Para(3) may be Inf.';
        validParameters = false;
    elseif isinf(parameters(3)) && parameters(3) < 0
        reasons{end+1} = 'Infinite pitch inertia must be positive Inf.';
        validParameters = false;
    end

    valid = validX && validE && validParameters;
    X = X(:);
    E = E(:);
    parameters = parameters(:);
end

function difference = TimingDifference(solved, guess)
    solved = solved(:);
    guess = guess(:);
    period = solved(9);
    difference = zeros(9,1);
    if isfinite(period) && period > 0
        difference(1:8) = mod((solved(1:8) - guess(1:8)) + ...
            0.5 * period, period) - 0.5 * period;
    else
        difference(1:8) = solved(1:8) - guess(1:8);
    end
    difference(9) = solved(9) - guess(9);
end

function prefixed = PrefixReasons(reasons, prefix)
    prefixed = cell(size(reasons));
    for i = 1:numel(reasons)
        prefixed{i} = [prefix, reasons{i}];
    end
end

function info = FinalizeDiagnostics(info, options)
    info.accepted = isempty(info.rejectionReasons);
    info.valid = info.accepted;
    if info.accepted
        info.status = 'accepted';
    else
        info.status = 'rejected';
    end

    if ~info.accepted && options.ErrorOnFailure
        message = strjoin(info.rejectionReasons, ' | ');
        error('BuildPoincareMap:Rejected', '%s', message);
    end
end
