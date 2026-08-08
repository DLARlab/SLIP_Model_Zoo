function report = main_Refresh_RoadmapReferenceArtifacts(userOptions)
%MAIN_REFRESH_ROADMAPREFERENCEARTIFACTS Refresh saved validation artifacts.
%
%   REPORT = MAIN_REFRESH_ROADMAPREFERENCEARTIFACTS() reloads the completed
%   six-transition reference report, repairs derived timing-convergence
%   fields from the already-saved Floquet diagnostics, reruns held-out
%   daughter validation with the current metric implementation, and rewrites
%   the CSV, Markdown, figures, per-case MAT files, and compressed report.
%
%   This utility deliberately does not recompute a Floquet matrix, refine a
%   critical orbit, or correct a branch. Use
%   main_Test_RoadmapBifurcationRobustness for a fully independent dynamics
%   run. It exists so presentation/validation changes can be applied to a
%   frozen parent-only calculation without pretending that Stage A reran.

    if nargin < 1 || isempty(userOptions)
        userOptions = struct();
    end
    paths = RoadmapRobustnessPaths();
    AddRequiredPaths(paths);
    opts = ParseOptions(userOptions,paths);
    loaded = load(opts.ResultFile,'report');
    if ~isfield(loaded,'report') || ~isstruct(loaded.report) || ...
            ~isscalar(loaded.report)
        error('main_Refresh_RoadmapReferenceArtifacts:ResultFile', ...
            'ResultFile must contain one scalar structure named report.');
    end
    report = loaded.report;
    ValidateReport(report);

    count = numel(report.transitions);
    for k = 1:count
        report.analyses(k) = RepairTimingConvergence(report.analyses(k));
        if opts.RerunHeldOutValidation
            validationOptions = report.validations(k).options;
            if ~isstruct(validationOptions) || ~isscalar(validationOptions)
                error('main_Refresh_RoadmapReferenceArtifacts:ValidationOptions', ...
                    'Saved validation options are invalid for %s.', ...
                    report.transitions(k).ID);
            end
            validationOptions.ThrowOnFailure = false;
            report.validations(k) = ValidateRoadmapTransition( ...
                report.analyses(k),report.transitions(k),validationOptions);
        end
    end

    report.methodScope = ['Retrospective targeted validation in fixed ' ...
        'historical windows. For each transition, its designated daughter ' ...
        'data are excluded from that transition''s Stage-A calculation and ' ...
        'are consulted only in Stage B; a shared branch file may separately ' ...
        'serve as the declared parent of another transition.'];
    report.parentOnly.scope = ['Per-transition parent-only calculation after ' ...
        'predeclared window selection. Each transition excludes its own ' ...
        'designated daughter data from Stage A; shared branch-library files ' ...
        'may have a parent role in other transition calculations.'];
    report.parentOnly.analyses = report.analyses;
    report.parentOnly.acceptedCount = nnz([report.analyses.accepted]);
    report.parentOnly.accepted = report.parentOnly.complete && ...
        all([report.analyses.accepted]);
    report.parentOnly.artifactsRefreshedAt = Timestamp();
    report.summary = RefreshConclusion(report);
    report.status = Ternary(report.summary.accepted,'validated','rejected');
    report.artifactsRefreshedAt = Timestamp();
    report.artifactRefreshScope = [ ...
        'Derived timing diagnostics and Stage-B validation only; ' ...
        'frozen Stage-A Floquet/refinement/correction data unchanged.'];

    writeOptions = struct('OutputDirectory',opts.OutputDirectory, ...
        'MakePlots',opts.MakePlots);
    report.artifacts = WriteRoadmapRobustnessArtifacts(report,writeOptions);
    finalMat = fullfile(opts.OutputDirectory, ...
        'roadmap_bifurcation_robustness_results.mat');
    report.artifacts.finalMat = finalMat;
    report.artifacts.parentOnlyMat = fullfile(opts.IntermediateDirectory, ...
        'parent_only_predictions.mat');
    report.artifacts.parentCheckpointMat = fullfile( ...
        opts.IntermediateDirectory,'parent_only_predictions_checkpoint.mat');

    if ~isfolder(opts.OutputDirectory), mkdir(opts.OutputDirectory); end
    if ~isfolder(opts.IntermediateDirectory), mkdir(opts.IntermediateDirectory); end
    parentReport = report.parentOnly;
    save(report.artifacts.parentOnlyMat,'parentReport','-v7');
    save(report.artifacts.parentCheckpointMat,'parentReport','-v7');
    save(finalMat,'report','-v7');

    if opts.ThrowOnFailure && ~report.summary.accepted
        error('main_Refresh_RoadmapReferenceArtifacts:Rejected', ...
            '%s',report.summary.message);
    end
end

function opts = ParseOptions(user,paths)
    defaults = struct('ResultFile',fullfile(paths.FinalResultsRoot, ...
        'roadmap_bifurcation_robustness_results.mat'), ...
        'OutputDirectory',paths.FinalResultsRoot, ...
        'IntermediateDirectory',paths.IntermediateResultsRoot, ...
        'MakePlots',true,'RerunHeldOutValidation',true, ...
        'ThrowOnFailure',true);
    if ~isstruct(user) || ~isscalar(user)
        error('main_Refresh_RoadmapReferenceArtifacts:Options', ...
            'Options must be a scalar structure.');
    end
    opts = defaults;
    names = fieldnames(user);
    allowed = fieldnames(defaults);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k},allowed),1);
        if isempty(hit)
            error('main_Refresh_RoadmapReferenceArtifacts:UnknownOption', ...
                'Unknown option %s.',names{k});
        end
        opts.(allowed{hit}) = user.(names{k});
    end
    textFields = {'ResultFile','OutputDirectory','IntermediateDirectory'};
    for k = 1:numel(textFields)
        opts.(textFields{k}) = char(string(opts.(textFields{k})));
        if isempty(opts.(textFields{k}))
            error('main_Refresh_RoadmapReferenceArtifacts:Path', ...
                '%s cannot be empty.',textFields{k});
        end
    end
    if ~isfile(opts.ResultFile)
        error('main_Refresh_RoadmapReferenceArtifacts:MissingResult', ...
            'Missing result file %s.',opts.ResultFile);
    end
    opts.MakePlots = ValidateLogical(opts.MakePlots,'MakePlots');
    opts.RerunHeldOutValidation = ValidateLogical( ...
        opts.RerunHeldOutValidation,'RerunHeldOutValidation');
    opts.ThrowOnFailure = ValidateLogical(opts.ThrowOnFailure,'ThrowOnFailure');
end

function ValidateReport(report)
    required = {'version','status','transitions','analyses','validations', ...
        'summary','parentOnly','completedAt'};
    for k = 1:numel(required)
        if ~isfield(report,required{k})
            error('main_Refresh_RoadmapReferenceArtifacts:ReportShape', ...
                'Saved report lacks required field %s.',required{k});
        end
    end
    count = numel(report.transitions);
    if count < 1 || numel(report.analyses) ~= count || ...
            numel(report.validations) ~= count
        error('main_Refresh_RoadmapReferenceArtifacts:ReportCount', ...
            'Saved transition, analysis, and validation counts must agree.');
    end
end

function analysis = RepairTimingConvergence(analysis)
    if ~isfield(analysis,'scan') || ...
            ~isfield(analysis.scan,'diagnostics') || ...
            ~iscell(analysis.scan.diagnostics)
        error('main_Refresh_RoadmapReferenceArtifacts:ScanDiagnostics', ...
            'Saved analysis %s has no Floquet diagnostics.',analysis.ID);
    end
    diagnostics = analysis.scan.diagnostics;
    timingResidual = NaN(1,numel(diagnostics));
    for j = 1:numel(diagnostics)
        timingResidual(j) = NestedNumber(diagnostics{j}, ...
            {'baseValidation','mapInfo','timingResidualNormInf'},NaN);
        if ~isfinite(timingResidual(j))
            timingResidual(j) = NestedNumber(diagnostics{j}, ...
                {'baseValidation','eventTimeResidualNormInf'},NaN);
        end
    end
    if any(~isfinite(timingResidual))
        error('main_Refresh_RoadmapReferenceArtifacts:TimingDiagnostics', ...
            'Unable to recover finite timing diagnostics for %s.',analysis.ID);
    end
    analysis.scan.convergence.timingResidual = timingResidual;
end

function conclusion = RefreshConclusion(report)
    analyses = report.analyses;
    validations = report.validations;
    transitions = report.transitions;
    parentAccepted = [analyses.accepted];
    heldOutAccepted = [validations.accepted];
    conclusion = report.summary;
    conclusion.transitionCount = numel(transitions);
    conclusion.parentExperimentCount = numel(unique( ...
        {transitions.ParentExperiment}));
    conclusion.parentOnlyAcceptedCount = nnz(parentAccepted);
    conclusion.heldOutAcceptedCount = nnz(heldOutAccepted);
    conclusion.expectedCrossingCount = numel(transitions);
    conclusion.detectedCrossingCount = nnz(arrayfun(@(a) ...
        isfield(a,'candidate') && isstruct(a.candidate) && ...
        ~isempty(fieldnames(a.candidate)),analyses));
    conclusion.accepted = all(parentAccepted) && all(heldOutAccepted);
    conclusion.coordinates = arrayfun(@(a)a.refinement.coordinate,analyses);
    conclusion.transitionIDs = {transitions.ID};
    suffix = Ternary(isscalar(transitions),'','s');
    conclusion.message = sprintf( ...
        ['Parent-only %d/%d; held-out %d/%d; %d targeted transition%s; ' ...
         'robustness status: %s.'], ...
        conclusion.parentOnlyAcceptedCount,numel(transitions), ...
        conclusion.heldOutAcceptedCount,numel(transitions), ...
        numel(transitions),suffix, ...
        Ternary(conclusion.accepted,'validated','rejected'));
end

function value = NestedNumber(input,names,default)
    value = input;
    for k = 1:numel(names)
        if ~isstruct(value) || ~isscalar(value) || ~isfield(value,names{k})
            value = default;
            return
        end
        value = value.(names{k});
    end
    if ~(isnumeric(value) && isreal(value) && isscalar(value))
        value = default;
    end
end

function AddRequiredPaths(paths)
    addpath(paths.ExperimentRoot,paths.FloquetRoot,paths.UtilitiesRoot, ...
        paths.DynamicsRoot,paths.ContinuationAlgorithmRoot, ...
        paths.SolutionManagementRoot);
end

function value = ValidateLogical(value,name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isreal(value) && isfinite(value) && ...
             any(value == [0 1]))))
        error('main_Refresh_RoadmapReferenceArtifacts:LogicalOption', ...
            '%s must be scalar logical.',name);
    end
    value = logical(value);
end

function value = Ternary(condition,a,b)
    if condition, value=a; else, value=b; end
end

function value = Timestamp()
    value = char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
end
