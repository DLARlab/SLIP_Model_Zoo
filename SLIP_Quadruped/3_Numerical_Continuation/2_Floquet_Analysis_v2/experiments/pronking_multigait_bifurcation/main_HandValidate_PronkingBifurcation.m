function audit = main_HandValidate_PronkingBifurcation(userOptions)
%MAIN_HANDVALIDATE_PRONKINGBIFURCATION Replay all saved daughter solutions.
%
%   AUDIT = MAIN_HANDVALIDATE_PRONKINGBIFURCATION() loads the result MAT
%   produced by main_Test_PronkingMultiGaitBifurcation, independently
%   reevaluates every accepted corrected orbit with the canonical residual
%   and normal production event-timing solve, and writes a flat audit CSV.
%   It does not reuse saved residual or acceptance values when deciding the
%   replay result.
%
%   Useful options are ResultsFile, OutputCsv, WriteCsv, Verbose, and
%   ThrowOnFailure.  This function is intentionally small enough to serve
%   as a hand-validation starting point in the MATLAB editor.

    if nargin < 1 || isempty(userOptions)
        userOptions = struct();
    end
    paths = PronkingExperimentPaths();
    AddRequiredPaths(paths);
    opts = ParseOptions(userOptions,paths);

    loaded = load(opts.ResultsFile,'report');
    if ~isfield(loaded,'report') || ~isstruct(loaded.report)
        error('main_HandValidate_PronkingBifurcation:MissingReport', ...
            'ResultsFile does not contain a scalar report structure.');
    end
    report = loaded.report;
    if ~isfield(report,'nonlinearSearch') || ...
            ~isfield(report.nonlinearSearch,'attempts')
        error('main_HandValidate_PronkingBifurcation:MissingSearch', ...
            'The saved report does not contain nonlinear search attempts.');
    end
    attempts = report.nonlinearSearch.attempts;
    selected = find([attempts.nonParentAccepted]);
    if isempty(selected)
        error('main_HandValidate_PronkingBifurcation:NoAcceptedOrbits', ...
            'The saved report contains no accepted corrected daughter orbit.');
    end

    searchOptions = report.nonlinearSearch.options;
    parameters = report.critical.refinement.parameters(:);
    stateScale = report.symmetry.directions.StateScale(:);
    records = repmat(EmptyRecord(),numel(selected),1);
    for row = 1:numel(selected)
        attemptIndex = selected(row);
        attempt = attempts(attemptIndex);
        records(row) = ReplayAttempt(attempt,attemptIndex,parameters, ...
            stateScale,searchOptions,report.options.FloquetOptions);
        if opts.Verbose
            r = records(row);
            fprintf(['[%2d] rho=%.1e requested=%s replay=%s accepted=%d ' ...
                'canonical=%.3e return=%.3e timing=%.3e\n'], ...
                r.attemptIndex,r.radius,r.requestedGaitClass, ...
                r.replayedGaitClass,r.accepted,r.canonicalResidualNorm, ...
                r.returnResidualNorm,r.eventTimeError);
        end
    end

    resultTable = struct2table(records,'AsArray',true);
    if opts.WriteCsv
        writetable(resultTable,opts.OutputCsv);
    end
    persistentCounts = report.nonlinearSearch.persistentClassCounts;
    audit = struct();
    audit.version = 'pronking-hand-validation-v1';
    audit.generatedAt = char(datetime('now', ...
        'Format','yyyyMMdd''T''HHmmss'));
    audit.resultsFile = opts.ResultsFile;
    audit.outputCsv = opts.OutputCsv;
    audit.criticalCoordinate = report.critical.refinement.coordinate;
    audit.records = records;
    audit.table = resultTable;
    audit.replayedOrbitCount = numel(records);
    audit.acceptedOrbitCount = nnz([records.accepted]);
    audit.allAccepted = all([records.accepted]);
    audit.persistentClassCounts = persistentCounts;
    audit.sixArmStructurePresent = ...
        report.nonlinearSearch.persistentClusterCount==6 && ...
        isequal(persistentCounts,[2 2 2]);
    audit.accepted = audit.allAccepted && audit.sixArmStructurePresent;
    if opts.Verbose
        fprintf(['Replay summary: %d/%d orbits accepted, critical dx=%.15g, ' ...
            'persistent [B F H]=%s, six-arm=%d\n'], ...
            audit.acceptedOrbitCount,audit.replayedOrbitCount, ...
            audit.criticalCoordinate,mat2str(persistentCounts), ...
            audit.sixArmStructurePresent);
        if opts.WriteCsv
            fprintf('Audit CSV: %s\n',opts.OutputCsv);
        end
    end
    if opts.ThrowOnFailure && ~audit.accepted
        error('main_HandValidate_PronkingBifurcation:ReplayRejected', ...
            'At least one corrected orbit or the six-arm cluster structure failed replay.');
    end
end

function record = ReplayAttempt(attempt,attemptIndex,parameters, ...
        stateScale,searchOptions,floquetOptions)
    z = attempt.zCorrected(:);
    if numel(z)~=22 || any(~isfinite(z))
        error('main_HandValidate_PronkingBifurcation:InvalidOrbit', ...
            'Attempt %d does not contain a finite 22-vector.',attemptIndex);
    end
    canonical = Quadrupedal_ZeroFun_v2( ...
        z(1:13).',z(14:22).',parameters.',{},'skipSolve');
    canonicalNorm = norm(canonical,inf);

    mapOptions = floquetOptions;
    mapOptions.TopologyMode = 'clustered';
    mapOptions.ErrorOnFailure = false;
    mapOptions.PeriodicResidualTolerance = ...
        searchOptions.ReturnMapTolerance;
    if isfield(attempt,'predictorInfo') && ...
            isfield(attempt.predictorInfo,'sectorTopology')
        mapOptions.ReferenceTopology = ...
            attempt.predictorInfo.sectorTopology;
    end
    periodic = ValidatePeriodicOrbit(z,parameters,mapOptions);
    returnNorm = Inf;
    timingError = Inf;
    topologyAccepted = false;
    if periodic.accepted
        returnNorm = norm(periodic.reducedPeriodicResidual(:)./ ...
            stateScale,inf);
        solved = periodic.mapInfo.solvedEventTimes(:);
        difference = CircularTimingDifference(solved,z(14:22));
        timingScale = ones(9,1)*max(0.05,0.25*z(22));
        timingScale(9) = max(0.1,0.5*z(22));
        timingError = norm(difference./timingScale,inf);
        topologyAccepted = periodic.eventOrderingConsistent;
    end

    [hindPhase,frontPhase,foreHindPhase] = TimingDefects(z(14:22));
    hindState = norm(z(6:7)-z(10:11),inf);
    frontState = norm(z(8:9)-z(12:13),inf);
    replayedClass = ClassifyTiming(hindPhase,frontPhase,foreHindPhase, ...
        searchOptions.PairSymmetryTolerance, ...
        searchOptions.BrokenSymmetryTolerance);
    requestedClass = char(string(attempt.requestedGaitClass));
    switch requestedClass
        case 'B'
            stateSymmetry = max(hindState,frontState);
        case 'F'
            stateSymmetry = hindState;
        case 'H'
            stateSymmetry = frontState;
        otherwise
            stateSymmetry = Inf;
    end
    accepted = canonicalNorm<=searchOptions.CanonicalResidualTolerance && ...
        periodic.accepted && topologyAccepted && ...
        returnNorm<=searchOptions.ReturnMapTolerance && ...
        timingError<=searchOptions.EventTimeTolerance && ...
        stateSymmetry<=searchOptions.ConstraintTolerance && ...
        strcmp(replayedClass,requestedClass);

    record = EmptyRecord();
    record.attemptIndex = attemptIndex;
    record.radius = attempt.radius;
    record.requestedGaitClass = string(requestedClass);
    record.replayedGaitClass = string(replayedClass);
    record.abbreviation = string(attempt.abbreviation);
    record.accepted = accepted;
    record.canonicalResidualNorm = canonicalNorm;
    record.returnResidualNorm = returnNorm;
    record.eventTimeError = timingError;
    record.topologyAccepted = topologyAccepted;
    record.periodicValidationAccepted = periodic.accepted;
    record.hindStateSymmetryError = hindState;
    record.frontStateSymmetryError = frontState;
    record.hindPairPhaseError = hindPhase;
    record.frontPairPhaseError = frontPhase;
    record.foreHindPhaseSeparation = foreHindPhase;
    record.dx = z(1);
    record.period = z(22);
end

function options = ParseOptions(user,paths)
    if ~isstruct(user) || ~isscalar(user)
        error('main_HandValidate_PronkingBifurcation:InvalidOptions', ...
            'Options must be a scalar structure.');
    end
    resultDirectory = paths.ResultsRoot;
    options = struct( ...
        'ResultsFile',fullfile(resultDirectory, ...
            'pronking_multigait_validation_results.mat'), ...
        'OutputCsv',fullfile(resultDirectory, ...
            'pronking_hand_validation_replay.csv'), ...
        'WriteCsv',true,'Verbose',true,'ThrowOnFailure',true);
    names = fieldnames(user);
    allowed = fieldnames(options);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k},allowed),1);
        if isempty(hit)
            error('main_HandValidate_PronkingBifurcation:UnknownOption', ...
                'Unknown option ''%s''.',names{k});
        end
        options.(allowed{hit}) = user.(names{k});
    end
    options.ResultsFile = char(string(options.ResultsFile));
    options.OutputCsv = char(string(options.OutputCsv));
    logicalFields = {'WriteCsv','Verbose','ThrowOnFailure'};
    for k = 1:numel(logicalFields)
        value = options.(logicalFields{k});
        if ~(isscalar(value) && (islogical(value) || ...
                (isnumeric(value) && isfinite(value) && any(value==[0 1]))))
            error('main_HandValidate_PronkingBifurcation:InvalidLogical', ...
                '%s must be a scalar logical.',logicalFields{k});
        end
        options.(logicalFields{k}) = logical(value);
    end
end

function difference = CircularTimingDifference(candidate,reference)
    difference = candidate(:)-reference(:);
    T = candidate(9);
    if isfinite(T) && T>0
        difference(1:8) = mod(difference(1:8)+0.5*T,T)-0.5*T;
    end
end

function [hind,front,foreHind] = TimingDefects(E)
    E = E(:);
    T = E(9);
    phase = @(a,b) mod((a-b)/T+0.5,1)-0.5;
    hind = max(abs([phase(E(1),E(5)),phase(E(2),E(6))]));
    front = max(abs([phase(E(3),E(7)),phase(E(4),E(8))]));
    foreHind = max(abs([phase(E(1),E(3)),phase(E(2),E(4)), ...
        phase(E(5),E(7)),phase(E(6),E(8))]));
end

function gaitClass = ClassifyTiming(hind,front,foreHind,pairTol,brokenTol)
    if hind<=pairTol && front<=pairTol
        if foreHind>=brokenTol
            gaitClass = 'B';
        else
            gaitClass = 'PK';
        end
    elseif hind<=pairTol && front>=brokenTol
        gaitClass = 'F';
    elseif front<=pairTol && hind>=brokenTol
        gaitClass = 'H';
    else
        gaitClass = 'mixed';
    end
end

function record = EmptyRecord()
    record = struct('attemptIndex',NaN,'radius',NaN, ...
        'requestedGaitClass',"",'replayedGaitClass',"", ...
        'abbreviation',"",'accepted',false, ...
        'canonicalResidualNorm',Inf,'returnResidualNorm',Inf, ...
        'eventTimeError',Inf,'topologyAccepted',false, ...
        'periodicValidationAccepted',false, ...
        'hindStateSymmetryError',Inf,'frontStateSymmetryError',Inf, ...
        'hindPairPhaseError',Inf,'frontPairPhaseError',Inf, ...
        'foreHindPhaseSeparation',0,'dx',NaN,'period',NaN);
end

function AddRequiredPaths(paths)
    addpath(paths.ExperimentRoot);
    addpath(paths.FloquetRoot);
    addpath(paths.UtilitiesRoot);
    addpath(paths.DynamicsRoot);
    addpath(paths.ContinuationAlgorithmRoot);
    addpath(paths.SolutionManagementRoot);
end
