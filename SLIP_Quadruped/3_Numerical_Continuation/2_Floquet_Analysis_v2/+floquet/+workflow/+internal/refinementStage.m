function refinementReport = refinementStage(config)
%REFINEFLOQUETCANDIDATESTAGE Refine every selected crossing group safely.
%
% Unsupported or unresolved candidates are records in the saved report; a
% fixed-dx fold, repeated space without a resolver, or one failed corrector
% does not erase the rest of a blind branch inventory.

    ValidateConfig(config);
    floquet.workflow.internal.RequireWritableFloquetWorkflowConfig(config);
    floquet.workflow.internal.EnforceFloquetInformationBarrier(config, 'critical-orbit refinement');
    RequireConfirmedSelection(config.Selection);
    RequireFile(config.Files.Discovery, ...
        'Run the parent-only discovery stage first.');
    floquet.workflow.internal.AddFloquetNumericalPaths(config);
    chain = floquet.workflow.internal.ValidateFloquetArtifactChain(config, 'discovery');
    summaryFile = ResolveSummaryFile(config);
    overwrite = floquet.workflow.internal.FloquetWorkflowOverwrite(config);
    floquet.workflow.internal.PreflightFloquetArtifacts( ...
        {config.Files.Refinement, summaryFile}, overwrite, ...
        {chain.Parent.CanonicalPath, chain.Discovery.CanonicalPath});
    loaded = load(config.Files.Discovery, 'analysis');
    if ~isfield(loaded, 'analysis')
        error('TemplateExperiment:DiscoveryContract', ...
            'Discovery MAT file does not contain variable analysis.');
    end
    analysis = loaded.analysis;
    candidates = SelectCandidates(analysis.candidates, ...
        config.Selection.CandidateIDs);

    if isempty(candidates)
        groupIDs = {};
    else
        groupIDs = unique({candidates.CandidateID}, 'stable');
    end
    records = repmat(EmptyRecord(), 1, numel(groupIDs));
    for k = 1:numel(groupIDs)
        group = candidates(strcmp({candidates.CandidateID}, groupIDs{k}));
        record = EmptyRecord();
        record.CandidateID = groupIDs{k};
        record.CandidateType = CandidateType(group(1));
        record.CandidateCount = numel(group);
        record.GroupCandidates = group;
        try
            [candidate, options] = ConfigureGroup(group, analysis, config);
            record.Candidate = candidate;
            record.CandidateType = CandidateType(candidate);
            chartCheck = VerifyFixedDxChart( ...
                group, analysis, config.Refinement);
            record.ChartCheck = chartCheck;
            record.NearbyFoldWarning = chartCheck.NearbyFoldWarning;
            options.SampleIndices = analysis.sampleIndices;
            options.ThrowOnFailure = false;
            problem = struct('branchFile', ...
                floquet.workflow.internal.ResolveFloquetParentBranch(config), ...
                'sampleIndices', analysis.sampleIndices);
            [solution, diagnostics] = floquet.refineCriticalOrbit( ...
                problem, candidate, options);
            record.Solution = solution;
            record.Diagnostics = diagnostics;
            record.Accepted = logical(diagnostics.accepted);
            if record.Accepted
                record.Status = 'accepted-refined-critical-orbit';
                record.Message = 'Critical-orbit refinement was accepted.';
            else
                record.Status = 'rejected-refinement';
                record.Message = DiagnosticMessage(diagnostics, ...
                    'Critical-orbit refinement did not meet acceptance tests.');
            end
        catch exception
            record.Accepted = false;
            record.Status = FailureStatus(exception.identifier);
            record.ErrorIdentifier = exception.identifier;
            record.Message = exception.message;
        end
        records(k) = record;
    end

    refinementReport = struct();
    refinementReport.WorkflowStage = 'critical-orbit-confirmation';
    refinementReport.WorkflowConfigSchemaVersion = config.SchemaVersion;
    refinementReport.ArtifactLayoutVersion = config.ArtifactLayoutVersion;
    refinementReport.SourceDiscoveryFile = chain.Discovery.CanonicalPath;
    refinementReport.SourceDiscoverySHA256 = chain.Discovery.SHA256;
    refinementReport.ValidatedArtifactChain = chain;
    refinementReport.Records = records;
    refinementReport.AcceptedCandidateIDs = ...
        {records([records.Accepted]).CandidateID};
    refinementReport.UnresolvedCandidateIDs = ...
        {records(~[records.Accepted]).CandidateID};
    refinementReport.Status = ReportStatus(records);
    refinementReport.CreatedAt = Timestamp();
    refinementReport.Policy = [ ...
        'Failures and unsupported candidate types are retained per candidate; ' ...
        'they do not terminate refinement of other discovered groups.'];
    refinementReport.Reproducibility = struct( ...
        'MATLABVersion', version, ...
        'NumericalOptions', config.Refinement.Options, ...
        'DxMonotonicityNeighborRadius', ...
            config.Refinement.DxMonotonicityNeighborRadius, ...
        'DxMonotonicityTolerance', ...
            config.Refinement.DxMonotonicityTolerance, ...
        'ConfigureGroup', floquet.workflow.internal.FloquetCallbackIdentity( ...
            config.Refinement.ConfigureGroup));

    floquet.workflow.internal.WriteFloquetArtifact(config.Files.Refinement, ...
        struct('refinementReport', refinementReport), overwrite);
    floquet.workflow.internal.WriteFloquetAuditTable(summaryFile, ...
        RefinementSummary(records), overwrite);
end

function filename = ResolveSummaryFile(config)
    if isfield(config.Files, 'RefinementSummary') && ...
            ~isempty(config.Files.RefinementSummary)
        filename = config.Files.RefinementSummary;
    else
        filename = fullfile(fileparts(config.Files.Refinement), ...
            'refinement_summary.csv');
    end
end

function summary = RefinementSummary(records)
    count = numel(records);
    candidateID = strings(count, 1);
    candidateType = strings(count, 1);
    candidateCount = zeros(count, 1);
    accepted = false(count, 1);
    status = strings(count, 1);
    errorIdentifier = strings(count, 1);
    message = strings(count, 1);
    nearbyFoldWarning = false(count, 1);
    coordinate = NaN(count, 1);
    multiplierReal = NaN(count, 1);
    multiplierImag = NaN(count, 1);
    multiplierResidual = NaN(count, 1);
    for k = 1:count
        candidateID(k) = string(records(k).CandidateID);
        candidateType(k) = string(records(k).CandidateType);
        candidateCount(k) = records(k).CandidateCount;
        accepted(k) = records(k).Accepted;
        status(k) = string(records(k).Status);
        errorIdentifier(k) = string(records(k).ErrorIdentifier);
        message(k) = string(records(k).Message);
        nearbyFoldWarning(k) = records(k).NearbyFoldWarning;
        coordinate(k) = DiagnosticNumber(records(k).Diagnostics, 'coordinate');
        multiplier = DiagnosticValue(records(k).Diagnostics, ...
            'multiplier', NaN);
        if isnumeric(multiplier) && isscalar(multiplier)
            multiplierReal(k) = real(multiplier);
            multiplierImag(k) = imag(multiplier);
        end
        multiplierResidual(k) = DiagnosticNumber( ...
            records(k).Diagnostics, 'multiplierResidual');
    end
    summary = table(candidateID, candidateType, candidateCount, accepted, ...
        status, errorIdentifier, message, nearbyFoldWarning, coordinate, ...
        multiplierReal, multiplierImag, multiplierResidual);
end

function value = DiagnosticNumber(source, field)
    value = DiagnosticValue(source, field, NaN);
    if ~(isnumeric(value) && isscalar(value))
        value = NaN;
    end
end

function value = DiagnosticValue(source, field, fallback)
    value = fallback;
    if isstruct(source) && isscalar(source) && isfield(source, field)
        value = source.(field);
    end
end

function ValidateConfig(config)
    required = {'ExperimentRoot','ParentBranchFile','Selection', ...
        'Refinement','Files'};
    if nargin < 1 || ~isstruct(config) || ~isscalar(config)
        error('TemplateExperiment:InvalidConfiguration', ...
            'The shared workflow requires one scalar ExperimentConfig struct.');
    end
    for k = 1:numel(required)
        if ~isfield(config, required{k})
            error('TemplateExperiment:MissingConfiguration', ...
                'ExperimentConfig is missing field %s.', required{k});
        end
    end
end

function RequireConfirmedSelection(selection)
    if ~isstruct(selection) || ~isscalar(selection) || ...
            ~isfield(selection, 'CandidateIDs') || ...
            ~isfield(selection, 'Confirmed')
        error('TemplateExperiment:CandidateSelectionContract', [ ...
            'config.Selection must contain CandidateIDs and Confirmed. ' ...
            'Run and inspect Stage 1 before configuring Stage 2.']);
    end
    confirmed = selection.Confirmed;
    if ~(islogical(confirmed) && isscalar(confirmed))
        error('TemplateExperiment:CandidateSelectionContract', ...
            'config.Selection.Confirmed must be one logical scalar.');
    end
    if ~confirmed
        error('TemplateExperiment:CandidateSelectionNotConfirmed', [ ...
            'Stage 2 is locked until the frozen Stage-1 candidate inventory ' ...
            'has been reviewed. Set Selection.Confirmed=true explicitly; ' ...
            'then empty CandidateIDs means select all discovered groups.']);
    end
end

function check = VerifyFixedDxChart(group, analysis, refinement)
    if ~isfield(analysis, 'states') || size(analysis.states, 1) < 1
        error('TemplateExperiment:MissingBranchStates', ...
            'Discovery artifact does not contain the branch states.');
    end
    left = min([group.LeftIndex]);
    right = max([group.RightIndex]);
    radius = refinement.DxMonotonicityNeighborRadius;
    if ~(isnumeric(radius) && isscalar(radius) && isfinite(radius) && ...
            radius >= 0 && radius == floor(radius))
        error('TemplateExperiment:DxMonotonicityNeighborRadius', ...
            'DxMonotonicityNeighborRadius must be a nonnegative integer.');
    end
    bracket = left:right;
    window = max(1, left - radius):min(size(analysis.states, 2), ...
        right + radius);
    dx = analysis.states(1, window);
    tolerance = refinement.DxMonotonicityTolerance;
    if isempty(tolerance)
        tolerance = 1e-10 * max(1, max(abs(dx)));
    end
    if ~(isnumeric(tolerance) && isscalar(tolerance) && ...
            isfinite(tolerance) && tolerance >= 0)
        error('TemplateExperiment:DxMonotonicityTolerance', ...
            'DxMonotonicityTolerance must be empty or nonnegative finite.');
    end
    bracketDx = analysis.states(1, bracket);
    bracketIncrements = diff(bracketDx);
    bracketMonotone = ~isempty(bracketIncrements) && ...
        (all(bracketIncrements > tolerance) || ...
         all(bracketIncrements < -tolerance));
    windowIncrements = diff(dx);
    windowMonotone = ~isempty(windowIncrements) && ...
        (all(windowIncrements > tolerance) || ...
         all(windowIncrements < -tolerance));
    check = struct();
    check.BracketLocalIndices = bracket;
    check.BracketBranchColumns = analysis.branchIndices(bracket);
    check.WindowLocalIndices = window;
    check.WindowBranchColumns = analysis.branchIndices(window);
    check.DxBracket = bracketDx;
    check.DxWindow = dx;
    check.Tolerance = tolerance;
    check.BracketMonotone = bracketMonotone;
    check.NearbyWindowMonotone = windowMonotone;
    check.NearbyFoldWarning = bracketMonotone && ~windowMonotone;
    if check.NearbyFoldWarning
        check.Message = [ ...
            'The candidate bracket is one-to-one in dx, but the expanded ' ...
            'neighbor window changes direction. Refinement is allowed and ' ...
            'its numerical convergence determines acceptance.'];
    else
        check.Message = 'The candidate bracket is locally one-to-one in dx.';
    end
    if ~bracketMonotone
        rawColumns = analysis.branchIndices(bracket);
        error('TemplateExperiment:FixedDxFold', [ ...
            'RefineCriticalOrbit fixes X(1)=dx, but dx is not locally ' ...
            'one-to-one inside candidate %s bracket (branch columns %d:%d). ' ...
            'Use an arclength-constrained critical-orbit refiner; do not ' ...
            'force the fixed-dx corrector through a fold.'], ...
            group(1).CandidateID, rawColumns(1), rawColumns(end));
    end
end

function [candidate, options] = ConfigureGroup(group, analysis, config)
    options = config.Refinement.Options;
    if isscalar(group)
        candidate = group(1);
        return
    end
    callback = config.Refinement.ConfigureGroup;
    if isempty(callback) || ~isa(callback, 'function_handle')
        error('TemplateExperiment:RepeatedGroupNeedsResolver', ...
            ['Candidate group %s contains %d tracked crossings. Supply ' ...
             'config.Refinement.ConfigureGroup to build and refine the ' ...
             'complete invariant subspace.'], group(1).CandidateID, numel(group));
    end
    [candidate, options] = callback(group, analysis, options);
    if ~isstruct(candidate) || ~isscalar(candidate) || ...
            ~isstruct(options) || ~isscalar(options)
        error('TemplateExperiment:InvalidGroupConfiguration', ...
            'ConfigureGroup must return one candidate and one options struct.');
    end
end

function candidates = SelectCandidates(candidates, requested)
    if isempty(candidates)
        return
    end
    if ~isfield(candidates, 'CandidateID')
        error('TemplateExperiment:MissingCandidateID', ...
            'Discovery predates stable candidate IDs; rerun main_RunDiscovery.');
    end
    if isempty(requested)
        return
    end
    requested = cellstr(string(requested));
    known = unique({candidates.CandidateID}, 'stable');
    missing = setdiff(requested, known, 'stable');
    if ~isempty(missing)
        error('TemplateExperiment:UnknownCandidateID', ...
            'Unknown CandidateID(s): %s', strjoin(missing, ', '));
    end
    candidates = candidates(ismember({candidates.CandidateID}, requested));
end

function type = CandidateType(candidate)
    if isfield(candidate, 'Type')
        type = char(string(candidate.Type));
    elseif isfield(candidate, 'type')
        type = char(string(candidate.type));
    else
        type = '';
    end
end

function message = DiagnosticMessage(diagnostics, fallback)
    message = fallback;
    names = {'message','status'};
    for k = 1:numel(names)
        if isstruct(diagnostics) && isfield(diagnostics, names{k}) && ...
                (ischar(diagnostics.(names{k})) || ...
                 (isstring(diagnostics.(names{k})) && ...
                  isscalar(diagnostics.(names{k}))))
            message = char(diagnostics.(names{k}));
            return
        end
    end
end

function status = FailureStatus(identifier)
    switch identifier
        case 'TemplateExperiment:FixedDxFold'
            status = 'unresolved-fixed-dx-fold';
        case 'TemplateExperiment:RepeatedGroupNeedsResolver'
            status = 'unsupported-repeated-critical-group';
        otherwise
            status = 'failed-refinement-exception';
    end
end

function status = ReportStatus(records)
    if isempty(records)
        status = 'complete-no-candidates';
    elseif all([records.Accepted])
        status = 'complete-all-accepted';
    elseif any([records.Accepted])
        status = 'complete-with-unresolved-candidates';
    else
        status = 'complete-no-refined-candidate';
    end
end

function record = EmptyRecord()
    record = struct('CandidateID', '', 'CandidateType', '', ...
        'CandidateCount', 0, 'Candidate', struct(), ...
        'GroupCandidates', struct([]), 'Solution', [], ...
        'Diagnostics', struct(), 'Accepted', false, ...
        'ChartCheck', struct(), 'NearbyFoldWarning', false, ...
        'Status', 'not-evaluated', 'ErrorIdentifier', '', 'Message', '');
end

function RequireFile(filename, hint)
    if ~isfile(filename)
        error('TemplateExperiment:MissingStageArtifact', ...
            '%s Missing file: %s', hint, filename);
    end
end

function value = Timestamp()
    value = char(datetime('now', 'TimeZone', 'local', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end
