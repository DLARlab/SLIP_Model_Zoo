function replay = main_HandValidate_RoadmapBifurcations(userOptions)
%MAIN_HANDVALIDATE_ROADMAPBIFURCATIONS Replay saved results independently.
%
%   This inexpensive hand-audit entry point reloads the frozen final MAT,
%   validates its schema and accepted status, reevaluates canonical residuals
%   and production return maps, reclassifies corrected gaits, and reruns the
%   held-out daughter comparison by default. It does not recompute Floquet
%   matrices; use main_Test_RoadmapBifurcationRobustness for that purpose.
%
%   Per-transition exceptions are recorded in the output CSV instead of
%   aborting the replay. Consequently a rejected or partially damaged result
%   still produces a complete hand-inspection table and REPLAY.accepted=false.

    if nargin < 1 || isempty(userOptions)
        userOptions = struct();
    end
    paths = RoadmapRobustnessPaths();
    AddRequiredPaths(paths);
    opts = ParseOptions(userOptions,paths);
    EnsureParentDirectory(opts.OutputCsv,'OutputCsv');
    if ~isempty(opts.LogFile)
        EnsureParentDirectory(opts.LogFile,'LogFile');
    end
    cleanup = StartDiary(opts); %#ok<NASGU>

    loaded = load(opts.ResultFile,'report');
    if ~isfield(loaded,'report') || ~isstruct(loaded.report) || ...
            ~isscalar(loaded.report)
        error('main_HandValidate_RoadmapBifurcations:ResultFile', ...
            'ResultFile must contain one scalar structure named report.');
    end
    report = loaded.report;
    [count,reportIssues] = ValidateReportEnvelope(report);

    Transition = strings(count,1);
    RefinedDx = NaN(count,1);
    CriticalResidual = NaN(count,1);
    CriticalMapResidual = NaN(count,1);
    MaximumCorrectedResidual = NaN(count,1);
    MaximumCorrectedMapResidual = NaN(count,1);
    AcceptedMinus = zeros(count,1);
    AcceptedPlus = zeros(count,1);
    ObservedGaits = strings(count,1);
    DaughterDxDifference = NaN(count,1);
    LinearAlignment = NaN(count,1);
    MinimumCorrectionAlignment = NaN(count,1);
    ScaledOrbitDistance = NaN(count,1);
    SavedValidationAccepted = false(count,1);
    RecomputedValidationAccepted = false(count,1);
    Passed = false(count,1);
    Reasons = strings(count,1);
    recomputedValidations = cell(1,count);

    fprintf('Independent hand replay: %d roadmap transitions\n',count);
    if ~isempty(reportIssues)
        fprintf('  report-level issues: %s\n',strjoin(reportIssues,' | '));
    end
    for k = 1:count
        reasons = reportIssues(:);
        try
            spec = report.transitions(k);
            analysis = report.analyses(k);
            savedValidation = report.validations(k);
            Transition(k) = string(FieldText(spec,'ID',sprintf('row_%d',k)));
            reasons = [reasons; ValidateRowIdentity( ...
                analysis,savedValidation,spec,k)]; %#ok<AGROW>

            if ~IsTrueField(analysis,'accepted')
                reasons{end+1,1} = 'saved parent-only analysis rejected'; %#ok<AGROW>
            end
            if ~isfield(analysis,'parentOnlyValidation') || ...
                    ~IsTrueField(analysis.parentOnlyValidation,'accepted')
                reasons{end+1,1} = ...
                    'saved parent-only validation rejected or missing'; %#ok<AGROW>
            else
                reasons = [reasons; AssertionFailures( ...
                    analysis.parentOnlyValidation,'saved parent-only')]; %#ok<AGROW>
            end

            SavedValidationAccepted(k) = IsTrueField(savedValidation,'accepted');
            if ~SavedValidationAccepted(k)
                reasons{end+1,1} = 'saved held-out validation rejected'; %#ok<AGROW>
            end
            reasons = [reasons; AssertionFailures( ...
                savedValidation,'saved held-out')]; %#ok<AGROW>
            reasons = [reasons; NonfiniteHeldOutMetrics( ...
                savedValidation,'saved held-out')]; %#ok<AGROW>

            refinement = RequireRefinement(analysis);
            RefinedDx(k) = RequireFiniteScalar( ...
                refinement.coordinate,'refined coordinate');
            criticalZ = RequireFiniteVector( ...
                refinement.solution,22,'critical solution');
            parameters = RequireFiniteParameters(refinement.parameters);
            criticalConstraints = ResolveCriticalConstraints(analysis,refinement);
            criticalCanonical = Quadrupedal_ZeroFun_v2( ...
                criticalZ(1:13).',criticalZ(14:22).',parameters.', ...
                criticalConstraints,'skipSolve');
            criticalCanonical = RequireFiniteResidual( ...
                criticalCanonical,'critical canonical residual');
            CriticalResidual(k) = norm(criticalCanonical(:),inf);
            reasons = [reasons; RejectNonfiniteScalar( ...
                CriticalResidual(k),'critical canonical residual')]; %#ok<AGROW>

            criticalMapOptions = ResolveMapOptions( ...
                analysis,opts.MapOptions,criticalConstraints);
            criticalMap = ValidatePeriodicOrbit( ...
                criticalZ,parameters,criticalMapOptions);
            CriticalMapResidual(k) = FieldNumber( ...
                criticalMap,'periodicResidualNormInf',NaN);
            reasons = [reasons; RejectNonfiniteScalar( ...
                CriticalMapResidual(k),'critical return-map residual')]; %#ok<AGROW>
            if ~IsTrueField(criticalMap,'accepted')
                reasons{end+1,1} = 'critical production return map rejected'; %#ok<AGROW>
            end

            if CriticalResidual(k) > opts.ResidualTolerance
                reasons{end+1,1} = ...
                    'critical canonical residual too large'; %#ok<AGROW>
            end
            if CriticalMapResidual(k) > opts.ResidualTolerance
                reasons{end+1,1} = ...
                    'critical return-map residual too large'; %#ok<AGROW>
            end

            acceptedAttempts = AcceptedAttempts(analysis);
            if isempty(acceptedAttempts)
                reasons{end+1,1} = 'no accepted corrected branch points'; %#ok<AGROW>
                AcceptedMinus(k) = 0;
                AcceptedPlus(k) = 0;
            else
                signs = [acceptedAttempts.sign];
                if ~isnumeric(signs) || ~isreal(signs) || ...
                        any(~isfinite(signs)) || ...
                        any(~ismember(signs,[-1 1]))
                    error('main_HandValidate_RoadmapBifurcations:AttemptSigns', ...
                        'Accepted corrected attempts must have finite +/-1 signs.');
                end
                AcceptedMinus(k) = nnz(signs == -1);
                AcceptedPlus(k) = nnz(signs == 1);
            end
            residuals = NaN(1,numel(acceptedAttempts));
            mapResiduals = NaN(1,numel(acceptedAttempts));
            gaits = strings(1,numel(acceptedAttempts));
            for j = 1:numel(acceptedAttempts)
                try
                    attempt = acceptedAttempts(j);
                    z = RequireFiniteVector(attempt.zCorrected,22, ...
                        sprintf('corrected solution %d',j));
                    attemptConstraints = ResolveAttemptConstraints( ...
                        attempt,analysis);
                    residual = Quadrupedal_ZeroFun_v2( ...
                        z(1:13).',z(14:22).',parameters.', ...
                        attemptConstraints,'skipSolve');
                    residual = RequireFiniteResidual(residual,sprintf( ...
                        'corrected canonical residual %d',j));
                    residuals(j) = norm(residual(:),inf);
                    attemptMapOptions = ResolveMapOptions( ...
                        analysis,opts.MapOptions,attemptConstraints);
                    map = ValidatePeriodicOrbit( ...
                        z,parameters,attemptMapOptions);
                    mapResiduals(j) = FieldNumber( ...
                        map,'periodicResidualNormInf',NaN);
                    if ~IsTrueField(map,'accepted')
                        reasons{end+1,1} = sprintf( ...
                            'corrected production map %d rejected',j); %#ok<AGROW>
                    end
                    [~,abbr] = Gait_Identification(z);
                    gaits(j) = string(abbr);
                catch attemptError
                    reasons{end+1,1} = sprintf( ...
                        'corrected attempt %d failed: %s: %s',j, ...
                        attemptError.identifier,attemptError.message); %#ok<AGROW>
                end
            end

            reasons = [reasons; RejectNonfiniteVector( ...
                residuals,'corrected canonical residuals')]; %#ok<AGROW>
            reasons = [reasons; RejectNonfiniteVector( ...
                mapResiduals,'corrected return-map residuals')]; %#ok<AGROW>
            MaximumCorrectedResidual(k) = FiniteMaximum(residuals);
            MaximumCorrectedMapResidual(k) = FiniteMaximum(mapResiduals);
            if ~isempty(gaits)
                observed = unique(gaits(strlength(gaits) > 0),'stable');
                if ~isempty(observed)
                    ObservedGaits(k) = strjoin(observed,'/');
                end
            end

            if isfinite(MaximumCorrectedResidual(k)) && ...
                    MaximumCorrectedResidual(k) > opts.ResidualTolerance
                reasons{end+1,1} = ...
                    'corrected canonical residual too large'; %#ok<AGROW>
            end
            if isfinite(MaximumCorrectedMapResidual(k)) && ...
                    MaximumCorrectedMapResidual(k) > opts.ResidualTolerance
                reasons{end+1,1} = ...
                    'corrected return-map residual too large'; %#ok<AGROW>
            end
            if AcceptedMinus(k) < opts.MinimumCorrectionsPerSign || ...
                    AcceptedPlus(k) < opts.MinimumCorrectionsPerSign
                reasons{end+1,1} = ...
                    'insufficient persistent +/- corrections'; %#ok<AGROW>
            end
            expectedGait = string(FieldText( ...
                spec,'ExpectedGaitAbbreviation',''));
            if isempty(gaits) || strlength(expectedGait) == 0 || ...
                    any(gaits ~= expectedGait)
                reasons{end+1,1} = 'corrected gait mismatch'; %#ok<AGROW>
            end

            activeValidation = savedValidation;
            if opts.RerunHeldOutValidation
                heldOutOptions = ResolveHeldOutOptions( ...
                    savedValidation,opts.HeldOutValidationOptions);
                activeValidation = ValidateRoadmapTransition( ...
                    analysis,spec,heldOutOptions);
                recomputedValidations{k} = activeValidation;
                RecomputedValidationAccepted(k) = ...
                    IsTrueField(activeValidation,'accepted');
                if ~RecomputedValidationAccepted(k)
                    reasons{end+1,1} = ...
                        'independently recomputed held-out validation rejected'; %#ok<AGROW>
                end
                reasons = [reasons; AssertionFailures( ...
                    activeValidation,'recomputed held-out')]; %#ok<AGROW>
                reasons = [reasons; NonfiniteHeldOutMetrics( ...
                    activeValidation,'recomputed held-out')]; %#ok<AGROW>
            else
                recomputedValidations{k} = struct( ...
                    'status','not-requested','accepted',NaN);
                RecomputedValidationAccepted(k) = SavedValidationAccepted(k);
            end

            DaughterDxDifference(k) = FieldNumber( ...
                activeValidation,'coordinateDifference',NaN);
            LinearAlignment(k) = FieldNumber( ...
                activeValidation,'linearDirectionAlignment',NaN);
            MinimumCorrectionAlignment(k) = FieldNumber(activeValidation, ...
                'minimumCorrectionDirectionAlignment',NaN);
            ScaledOrbitDistance(k) = FieldNumber( ...
                activeValidation,'scaledOrbitDistance22',NaN);
            reasons = [reasons; RejectNonfiniteScalar( ...
                DaughterDxDifference(k),'held-out coordinate difference')]; %#ok<AGROW>
            reasons = [reasons; RejectNonfiniteScalar( ...
                LinearAlignment(k),'held-out linear alignment')]; %#ok<AGROW>
            reasons = [reasons; RejectNonfiniteScalar( ...
                MinimumCorrectionAlignment(k), ...
                'held-out correction alignment')]; %#ok<AGROW>
            reasons = [reasons; RejectNonfiniteScalar( ...
                ScaledOrbitDistance(k),'held-out scaled orbit distance')]; %#ok<AGROW>
            if DaughterDxDifference(k) > opts.MaximumCoordinateDifference
                reasons{end+1,1} = 'held-out coordinate mismatch'; %#ok<AGROW>
            end
            if LinearAlignment(k) < opts.MinimumDirectionAlignment
                reasons{end+1,1} = 'held-out direction mismatch'; %#ok<AGROW>
            end
            % The held-out validator applies the configured threshold to
            % both signs at their smallest persistent accepted radius.  The
            % scalar stored here is deliberately the global diagnostic
            % minimum over every radius, so it must not override that
            % sign-aware assertion (a coarse radius may be less linear).
        catch rowError
            if strlength(Transition(k)) == 0
                Transition(k) = "row_" + string(k);
            end
            reasons{end+1,1} = sprintf('row exception: %s: %s', ...
                rowError.identifier,rowError.message); %#ok<AGROW>
        end

        reasons = UniqueNonemptyReasons(reasons);
        Passed(k) = isempty(reasons);
        Reasons(k) = strjoin(string(reasons),' | ');
        fprintf(['  %-9s pass=%d dx=%.12g residual=%.3e gait=%s ' ...
            'held-out=%d\n'],char(Transition(k)),Passed(k),RefinedDx(k), ...
            MaximumCorrectedResidual(k),char(ObservedGaits(k)), ...
            RecomputedValidationAccepted(k));
    end

    tableValue = table(Transition,RefinedDx,CriticalResidual, ...
        CriticalMapResidual,MaximumCorrectedResidual, ...
        MaximumCorrectedMapResidual,AcceptedMinus,AcceptedPlus, ...
        ObservedGaits,DaughterDxDifference,LinearAlignment, ...
        MinimumCorrectionAlignment,ScaledOrbitDistance, ...
        SavedValidationAccepted,RecomputedValidationAccepted,Passed,Reasons);
    writetable(tableValue,opts.OutputCsv);
    replay = struct('version','roadmap-hand-replay-v2', ...
        'generatedAt',Timestamp(),'accepted',all(Passed), ...
        'sourceReportVersion',FieldText(report,'version',''), ...
        'sourceReportStatus',FieldText(report,'status',''), ...
        'reportIssues',{reportIssues},'table',tableValue, ...
        'recomputedValidations',{recomputedValidations}, ...
        'resultFile',opts.ResultFile,'outputCsv',opts.OutputCsv, ...
        'logFile',opts.LogFile,'options',opts);
    fprintf('Hand replay accepted: %d/%d\n',nnz(Passed),count);
    if opts.ThrowOnFailure && ~replay.accepted
        error('main_HandValidate_RoadmapBifurcations:Rejected', ...
            'At least one hand-replay row failed; inspect %s.',opts.OutputCsv);
    end
end

function opts = ParseOptions(user,paths)
    defaults = struct();
    defaults.ResultFile = fullfile(paths.FinalResultsRoot, ...
        'roadmap_bifurcation_robustness_results.mat');
    defaults.OutputCsv = fullfile(paths.FinalResultsRoot, ...
        'roadmap_hand_validation_replay.csv');
    defaults.LogFile = fullfile(paths.LogRoot, ...
        'roadmap_robustness_hand_validation.log');
    defaults.MapOptions = struct();
    defaults.RerunHeldOutValidation = true;
    defaults.HeldOutValidationOptions = struct();
    defaults.ResidualTolerance = 1e-8;
    defaults.MinimumCorrectionsPerSign = 2;
    defaults.MaximumCoordinateDifference = 0.02;
    defaults.MinimumDirectionAlignment = 0.90;
    defaults.MinimumCorrectionAlignment = 0.80;
    defaults.OverwriteLog = true;
    defaults.ThrowOnFailure = true;
    if ~isstruct(user) || ~isscalar(user)
        error('main_HandValidate_RoadmapBifurcations:Options', ...
            'Options must be a scalar structure.');
    end
    opts = defaults;
    names = fieldnames(user);
    allowed = fieldnames(defaults);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k},allowed),1);
        if isempty(hit)
            error('main_HandValidate_RoadmapBifurcations:UnknownOption', ...
                'Unknown option %s.',names{k});
        end
        opts.(allowed{hit}) = user.(names{k});
    end
    opts.ResultFile = char(string(opts.ResultFile));
    opts.OutputCsv = char(string(opts.OutputCsv));
    opts.LogFile = char(string(opts.LogFile));
    if ~isfile(opts.ResultFile)
        error('main_HandValidate_RoadmapBifurcations:MissingResult', ...
            'Missing result file %s.',opts.ResultFile);
    end
    if isempty(opts.OutputCsv)
        error('main_HandValidate_RoadmapBifurcations:OutputCsv', ...
            'OutputCsv cannot be empty.');
    end
    if ~isstruct(opts.MapOptions) || ~isscalar(opts.MapOptions) || ...
            ~isstruct(opts.HeldOutValidationOptions) || ...
            ~isscalar(opts.HeldOutValidationOptions)
        error('main_HandValidate_RoadmapBifurcations:NestedOptions', ...
            'MapOptions and HeldOutValidationOptions must be scalar structures.');
    end
    opts.RerunHeldOutValidation = ValidateLogical( ...
        opts.RerunHeldOutValidation,'RerunHeldOutValidation');
    opts.OverwriteLog = ValidateLogical(opts.OverwriteLog,'OverwriteLog');
    opts.ThrowOnFailure = ValidateLogical(opts.ThrowOnFailure,'ThrowOnFailure');
    positive = {'ResidualTolerance','MaximumCoordinateDifference', ...
        'MinimumDirectionAlignment','MinimumCorrectionAlignment'};
    for k = 1:numel(positive)
        value = opts.(positive{k});
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value > 0)
            error('main_HandValidate_RoadmapBifurcations:PositiveOption', ...
                '%s must be positive and finite.',positive{k});
        end
    end
    if opts.MinimumDirectionAlignment > 1 || ...
            opts.MinimumCorrectionAlignment > 1
        error('main_HandValidate_RoadmapBifurcations:Alignment', ...
            'Alignment thresholds cannot exceed one.');
    end
    if ~(isnumeric(opts.MinimumCorrectionsPerSign) && ...
            isscalar(opts.MinimumCorrectionsPerSign) && ...
            isfinite(opts.MinimumCorrectionsPerSign) && ...
            opts.MinimumCorrectionsPerSign >= 1 && ...
            opts.MinimumCorrectionsPerSign == floor(opts.MinimumCorrectionsPerSign))
        error('main_HandValidate_RoadmapBifurcations:CorrectionCount', ...
            'MinimumCorrectionsPerSign must be a positive integer.');
    end
end

function cleanup = StartDiary(opts)
    cleanup = [];
    if isempty(opts.LogFile)
        return
    end
    if opts.OverwriteLog && isfile(opts.LogFile)
        delete(opts.LogFile);
    end
    diary(opts.LogFile);
    cleanup = onCleanup(@()diary('off'));
end

function EnsureParentDirectory(filename,label)
    directory = fileparts(filename);
    if isempty(directory)
        return
    end
    if ~isfolder(directory)
        [created,message] = mkdir(directory);
        if ~created
            error('main_HandValidate_RoadmapBifurcations:OutputDirectory', ...
                'Unable to create the %s directory %s: %s', ...
                label,directory,message);
        end
    end
end

function [count,issues] = ValidateReportEnvelope(report)
    required = {'version','status','transitions','analyses','validations', ...
        'summary','parentOnly'};
    for k = 1:numel(required)
        if ~isfield(report,required{k})
            error('main_HandValidate_RoadmapBifurcations:ReportShape', ...
                'Saved report lacks required field %s.',required{k});
        end
    end
    if ~isstruct(report.transitions) || ~isvector(report.transitions) || ...
            ~isstruct(report.analyses) || ~isvector(report.analyses) || ...
            ~isstruct(report.validations) || ~isvector(report.validations)
        error('main_HandValidate_RoadmapBifurcations:ReportShape', ...
            ['Transitions, analyses, and validations must be vector ' ...
             'structure arrays.']);
    end
    count = numel(report.transitions);
    if count < 1 || numel(report.analyses) ~= count || ...
            numel(report.validations) ~= count
        error('main_HandValidate_RoadmapBifurcations:ReportCount', ...
            ['Saved report must have equal nonzero transition, analysis, ' ...
             'and validation counts.']);
    end
    issues = cell(0,1);
    if ~strcmp(FieldText(report,'version',''), ...
            'roadmap-bifurcation-robustness-v1')
        issues{end+1,1} = 'unexpected saved report version';
    end
    if ~strcmp(FieldText(report,'status',''),'validated')
        issues{end+1,1} = 'saved report status is not validated';
    end
    if ~isstruct(report.summary) || ~isscalar(report.summary) || ...
            ~IsTrueField(report.summary,'accepted')
        issues{end+1,1} = 'saved report summary is absent or rejected';
    end
    summaryCount = FieldNumber(report.summary,'transitionCount',NaN);
    if ~isfinite(summaryCount) || summaryCount ~= count
        issues{end+1,1} = 'saved summary transition count is inconsistent';
    end
    if ~isstruct(report.parentOnly) || ~isscalar(report.parentOnly) || ...
            ~IsTrueField(report.parentOnly,'complete') || ...
            ~IsTrueField(report.parentOnly,'accepted')
        issues{end+1,1} = 'saved parent-only stage is incomplete or rejected';
    elseif ~isfield(report.parentOnly,'analyses') || ...
            ~isstruct(report.parentOnly.analyses) || ...
            ~isvector(report.parentOnly.analyses) || ...
            numel(report.parentOnly.analyses) ~= count
        issues{end+1,1} = 'saved parent-only analysis count is inconsistent';
    end
    ids = string(arrayfun(@(x)FieldText(x,'ID',''), ...
        report.transitions,'UniformOutput',false));
    if any(strlength(ids) == 0) || numel(unique(ids)) ~= count
        issues{end+1,1} = 'transition IDs are empty or duplicated';
    end
    issues = UniqueNonemptyReasons(issues);
end

function reasons = ValidateRowIdentity(analysis,validation,spec,index)
    reasons = cell(0,1);
    if ~isstruct(spec) || ~isscalar(spec) || ...
            ~isstruct(analysis) || ~isscalar(analysis) || ...
            ~isstruct(validation) || ~isscalar(validation)
        reasons{end+1,1} = sprintf('row %d contains nonscalar structures',index);
        return
    end
    id = FieldText(spec,'ID','');
    if isempty(id)
        reasons{end+1,1} = sprintf('row %d has no transition ID',index);
    end
    if ~strcmp(FieldText(analysis,'ID',''),id)
        reasons{end+1,1} = 'analysis and specification IDs differ';
    end
    if ~strcmp(FieldText(validation,'transitionID',''),id)
        reasons{end+1,1} = 'validation and specification IDs differ';
    end
end

function refinement = RequireRefinement(analysis)
    if ~isfield(analysis,'refinement') || ...
            ~isstruct(analysis.refinement) || ...
            ~isscalar(analysis.refinement) || ...
            ~IsTrueField(analysis.refinement,'accepted')
        error('main_HandValidate_RoadmapBifurcations:Refinement', ...
            'An accepted scalar refinement is required.');
    end
    refinement = analysis.refinement;
end

function attempts = AcceptedAttempts(analysis)
    attempts = struct([]);
    if ~isfield(analysis,'attempts') || ~isstruct(analysis.attempts) || ...
            isempty(analysis.attempts) || ...
            ~isfield(analysis.attempts,'acceptedBranchPoint')
        return
    end
    mask = false(1,numel(analysis.attempts));
    for k = 1:numel(mask)
        value = analysis.attempts(k).acceptedBranchPoint;
        mask(k) = IsScalarBoolean(value) && logical(value);
    end
    attempts = analysis.attempts(mask);
end

function constraints = ResolveCriticalConstraints(analysis,refinement)
    found = false;
    if isfield(refinement,'options') && isstruct(refinement.options) && ...
            isscalar(refinement.options) && ...
            isfield(refinement.options,'Constraints')
        constraints = refinement.options.Constraints;
        found = true;
    end
    if ~found && isfield(analysis,'options') && ...
            isstruct(analysis.options) && isscalar(analysis.options) && ...
            isfield(analysis.options,'RefinementOptions') && ...
            isstruct(analysis.options.RefinementOptions) && ...
            isscalar(analysis.options.RefinementOptions) && ...
            isfield(analysis.options.RefinementOptions,'Constraints')
        constraints = analysis.options.RefinementOptions.Constraints;
        found = true;
    end
    if ~found && isfield(analysis,'options') && ...
            isstruct(analysis.options) && isscalar(analysis.options) && ...
            isfield(analysis.options,'CorrectorOptions') && ...
            isstruct(analysis.options.CorrectorOptions) && ...
            isscalar(analysis.options.CorrectorOptions) && ...
            isfield(analysis.options.CorrectorOptions,'Constraints')
        constraints = analysis.options.CorrectorOptions.Constraints;
        found = true;
    end
    if ~found
        error('main_HandValidate_RoadmapBifurcations:SavedConstraints', ...
            'No saved canonical-residual constraints were found.');
    end
    constraints = ValidateConstraints(constraints,'critical constraints');
end

function constraints = ResolveAttemptConstraints(attempt,analysis)
    found = false;
    if isfield(attempt,'correctorInfo') && ...
            isstruct(attempt.correctorInfo) && ...
            isscalar(attempt.correctorInfo) && ...
            isfield(attempt.correctorInfo,'constraints')
        constraints = attempt.correctorInfo.constraints;
        found = true;
    end
    if ~found && isfield(analysis,'options') && ...
            isstruct(analysis.options) && isscalar(analysis.options) && ...
            isfield(analysis.options,'CorrectorOptions') && ...
            isstruct(analysis.options.CorrectorOptions) && ...
            isscalar(analysis.options.CorrectorOptions) && ...
            isfield(analysis.options.CorrectorOptions,'Constraints')
        constraints = analysis.options.CorrectorOptions.Constraints;
        found = true;
    end
    if ~found
        error('main_HandValidate_RoadmapBifurcations:SavedConstraints', ...
            'No saved corrector constraints were found for the attempt.');
    end
    constraints = ValidateConstraints(constraints,'corrected constraints');
end

function constraints = ValidateConstraints(constraints,label)
    if isempty(constraints)
        constraints = {};
    end
    if ~(iscell(constraints) || isstruct(constraints))
        error('main_HandValidate_RoadmapBifurcations:Constraints', ...
            '%s must be a cell array or structure.',label);
    end
end

function mapOptions = ResolveMapOptions(analysis,override,constraints)
    if ~isfield(analysis,'options') || ~isstruct(analysis.options) || ...
            ~isscalar(analysis.options) || ...
            ~isfield(analysis.options,'MapOptions')
        error('main_HandValidate_RoadmapBifurcations:SavedMapOptions', ...
            'The analysis does not contain saved MapOptions.');
    end
    mapOptions = analysis.options.MapOptions;
    if ~isstruct(mapOptions) || ~isscalar(mapOptions)
        error('main_HandValidate_RoadmapBifurcations:SavedMapOptions', ...
            'Saved MapOptions must be a scalar structure.');
    end
    mapOptions = MergeStruct(mapOptions,override);
    mapOptions.Constraints = constraints;
    mapOptions.ErrorOnFailure = false;
end

function options = ResolveHeldOutOptions(savedValidation,override)
    if ~isstruct(savedValidation) || ~isscalar(savedValidation) || ...
            ~isfield(savedValidation,'options') || ...
            ~isstruct(savedValidation.options) || ...
            ~isscalar(savedValidation.options)
        error('main_HandValidate_RoadmapBifurcations:SavedValidationOptions', ...
            'The saved held-out validation options are absent or invalid.');
    end
    options = savedValidation.options;
    options = MergeStruct(options,override);
    options.ThrowOnFailure = false;
end

function result = MergeStruct(base,override)
    if ~isstruct(base) || ~isscalar(base) || ...
            ~isstruct(override) || ~isscalar(override)
        error('main_HandValidate_RoadmapBifurcations:OptionMerge', ...
            'Option merge inputs must be scalar structures.');
    end
    result = base;
    names = fieldnames(override);
    for k = 1:numel(names)
        result.(names{k}) = override.(names{k});
    end
end

function reasons = AssertionFailures(container,label)
    reasons = cell(0,1);
    if ~isstruct(container) || ~isscalar(container) || ...
            ~isfield(container,'assertions') || ...
            ~isstruct(container.assertions) || ...
            ~isscalar(container.assertions) || ...
            isempty(fieldnames(container.assertions))
        reasons{end+1,1} = sprintf('%s assertions are absent or invalid',label);
        return
    end
    names = fieldnames(container.assertions);
    for k = 1:numel(names)
        value = container.assertions.(names{k});
        valid = IsScalarBoolean(value);
        if ~valid || ~logical(value)
            reasons{end+1,1} = sprintf('%s assertion failed: %s', ...
                label,names{k}); %#ok<AGROW>
        end
    end
end

function reasons = NonfiniteHeldOutMetrics(validation,label)
    scalarNames = {'parameterErrorNormInf','coordinateDifference', ...
        'scaledOrbitDistance22','linearDirectionAlignment', ...
        'minimumCorrectionDirectionAlignment', ...
        'maximumCorrectionDirectionAlignment','criticalPairStateError', ...
        'criticalPairTimingError','daughterPairStateError', ...
        'daughterPairTimingError'};
    reasons = cell(0,1);
    for k = 1:numel(scalarNames)
        value = FieldNumber(validation,scalarNames{k},NaN);
        reasons = [reasons; RejectNonfiniteScalar( ...
            value,sprintf('%s %s',label,scalarNames{k}))]; %#ok<AGROW>
    end
    if ~isfield(validation,'correctionDirectionAlignments')
        reasons{end+1,1} = sprintf( ...
            '%s correctionDirectionAlignments are missing',label);
    else
        reasons = [reasons; RejectNonfiniteVector( ...
            validation.correctionDirectionAlignments, ...
            sprintf('%s correctionDirectionAlignments',label))];
    end
end

function reasons = RejectNonfiniteScalar(value,label)
    reasons = cell(0,1);
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value))
        reasons{1,1} = sprintf('%s is missing or nonfinite',label);
    end
end

function reasons = RejectNonfiniteVector(value,label)
    reasons = cell(0,1);
    if ~isnumeric(value) || ~isreal(value) || isempty(value) || ...
            any(~isfinite(value(:)))
        reasons{1,1} = sprintf('%s contain missing or nonfinite values',label);
    end
end

function value = RequireFiniteScalar(value,label)
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value))
        error('main_HandValidate_RoadmapBifurcations:FiniteScalar', ...
            '%s must be a finite real scalar.',label);
    end
end

function value = RequireFiniteVector(value,count,label)
    value = value(:);
    if ~isnumeric(value) || ~isreal(value) || numel(value) ~= count || ...
            any(~isfinite(value))
        error('main_HandValidate_RoadmapBifurcations:FiniteVector', ...
            '%s must contain %d finite real values.',label,count);
    end
end

function value = RequireFiniteResidual(value,label)
    if ~isnumeric(value) || ~isreal(value) || isempty(value) || ...
            any(~isfinite(value(:)))
        error('main_HandValidate_RoadmapBifurcations:FiniteResidual', ...
            '%s must be a nonempty finite real numeric array.',label);
    end
end

function value = RequireFiniteParameters(value)
    value = value(:);
    valid = isnumeric(value) && numel(value) == 7 && isreal(value) && ...
        all(isfinite(value) | (((1:7).' == 3) & isinf(value) & value > 0));
    if ~valid
        error('main_HandValidate_RoadmapBifurcations:Parameters', ...
            ['Saved parameters must contain seven real values; only the ' ...
             'third may be positive Inf.']);
    end
end

function value = FiniteMaximum(values)
    if isempty(values) || any(~isfinite(values(:)))
        value = NaN;
    else
        value = max(values(:));
    end
end

function value = FieldNumber(input,name,default)
    if isstruct(input) && isscalar(input) && isfield(input,name) && ...
            isnumeric(input.(name)) && isreal(input.(name)) && ...
            isscalar(input.(name))
        value = input.(name);
    else
        value = default;
    end
end

function value = FieldText(input,name,default)
    if isstruct(input) && isscalar(input) && isfield(input,name) && ...
            (ischar(input.(name)) || ...
             (isstring(input.(name)) && isscalar(input.(name))))
        value = char(string(input.(name)));
    else
        value = default;
    end
end

function tf = IsTrueField(input,name)
    tf = false;
    if ~isstruct(input) || ~isscalar(input) || ~isfield(input,name)
        return
    end
    value = input.(name);
    tf = IsScalarBoolean(value) && logical(value);
end

function tf = IsScalarBoolean(value)
    tf = isscalar(value) && isreal(value) && ...
        (islogical(value) || isnumeric(value)) && isfinite(double(value)) && ...
        any(double(value) == [0 1]);
end

function reasons = UniqueNonemptyReasons(reasons)
    if isempty(reasons)
        reasons = cell(0,1);
        return
    end
    reasons = reasons(:);
    keep = cellfun(@(x)(ischar(x) || ...
        (isstring(x) && isscalar(x))) && strlength(string(x)) > 0,reasons);
    reasons = cellstr(unique(string(reasons(keep)),'stable'));
    reasons = reasons(:);
end

function AddRequiredPaths(paths)
    addpath(paths.ExperimentRoot,paths.FloquetRoot,paths.UtilitiesRoot, ...
        paths.DynamicsRoot,paths.SolutionManagementRoot);
end

function value = ValidateLogical(value,name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
        error('main_HandValidate_RoadmapBifurcations:LogicalOption', ...
            '%s must be scalar logical.',name);
    end
    value = logical(value);
end

function value = Timestamp()
    value = char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
end
