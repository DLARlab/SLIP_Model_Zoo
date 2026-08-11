function report = main_Test_RoadmapBifurcationRobustness(userOptions)
%MAIN_TEST_ROADMAPBIFURCATIONROBUSTNESS Run six secondary-gait tests.
%
%   REPORT = MAIN_TEST_ROADMAPBIFURCATIONROBUSTNESS(OPTIONS) validates the
%   transitions owned by OPTIONS.ExperimentRoot. The root is mandatory;
%   standard packages are dispatched by RunRoadmapReferenceExperiment.
%
%       BG -> HG and FG,  BE -> FE and HE,
%       FG -> GG,         HE -> GE.
%
%   Each targeted historical window is processed in two isolated stages.
%   Stage A loads only the parent, freezes the reduced Floquet crossing,
%   critical orbit, pair-odd eigenvector, timing lift, and nonlinear +/-
%   corrections, and saves parent_only_predictions.mat.  Stage B then loads
%   the held-out daughter branch and validates the frozen prediction.
%
%   This is a retrospective robustness experiment in predeclared windows,
%   not an exhaustive blind scan of the folded parent branches.

    if nargin < 1 || isempty(userOptions)
        userOptions = struct();
    end
    experimentRoot = RequestedExperimentRoot(userOptions);
    paths = RoadmapRobustnessPaths(experimentRoot);
    AddRequiredPaths(paths);
    options = ParseOptions(userOptions,paths);
    transitions = RoadmapBifurcationCases(paths,options.TransitionIDs);
    EnsureOutputDirectories(options);
    if ~isfolder(paths.CheckpointsRoot)
        mkdir(paths.CheckpointsRoot);
    end
    cleanup = StartDiary(options); %#ok<NASGU> keep cleanup alive through run

    report = InitialReport(options,paths,transitions);
    finalMat = fullfile(options.OutputDirectory, ...
        'roadmap_bifurcation_robustness_results.mat');
    parentOnlyMat = fullfile(options.IntermediateDirectory, ...
        'parent_only_predictions.mat');
    checkpointMat = fullfile(paths.CheckpointsRoot, ...
        'parent_only_predictions_checkpoint.mat');
    report.artifacts.finalMat = finalMat;
    report.artifacts.parentOnlyMat = parentOnlyMat;
    report.artifacts.parentCheckpointMat = checkpointMat;

    try
        fprintf('Roadmap Floquet-v2 robustness: %d targeted transitions\n', ...
            numel(transitions));
        analyses = repmat(EmptyAnalysisPlaceholder(),1,numel(transitions));
        for k = 1:numel(transitions)
            spec = transitions(k);
            fprintf('\n[%d/%d] Stage A parent-only: %s (%s -> %s)\n', ...
                k,numel(transitions),spec.ID,spec.ParentCode,spec.DaughterCode);
            caseOptions = options.AnalysisOptions;
            caseOptions.Verbose = options.Verbose;
            caseOptions.ThrowOnFailure = false;
            analyses(k) = AnalyzeRoadmapBifurcationCase(spec,caseOptions);
            % Preserve every completed Stage-A record in the authoritative
            % report before any checkpoint save or stop-on-failure error.
            % Keeping the not-yet-run placeholders makes the array remain
            % shape-compatible with report.transitions after a partial run.
            report.analyses = analyses;
            parentReport = BuildParentReport( ...
                analyses(1:k),transitions(1:k),options,paths,false);
            report.parentOnly = parentReport;
            save(checkpointMat,'parentReport','-v7');
            if ~analyses(k).accepted && options.StopOnCaseFailure
                error('main_Test_RoadmapBifurcationRobustness:ParentCaseFailed', ...
                    'Parent-only case %s failed.',spec.ID);
            end
        end

        parentReport = BuildParentReport( ...
            analyses,transitions,options,paths,true);
        save(parentOnlyMat,'parentReport','-v7');
        report.parentOnly = parentReport;
        % Keep the partial Stage-A checkpoint only while it adds recovery
        % value. Once the complete parent-only record has been saved, the
        % checkpoint is byte-for-byte redundant and must not be packaged.
        RemoveCompletedParentCheckpoint(checkpointMat);
        if isfield(report.artifacts,'parentCheckpointMat')
            report.artifacts = rmfield( ...
                report.artifacts,'parentCheckpointMat');
        end

        validations = repmat(EmptyValidationPlaceholder(),1,numel(transitions));
        for k = 1:numel(transitions)
            spec = transitions(k);
            fprintf('\n[%d/%d] Stage B held-out: %s (%s)\n', ...
                k,numel(transitions),spec.ID,spec.DaughterCode);
            if analyses(k).accepted
                validationOptions = options.ValidationOptions;
                validationOptions.ThrowOnFailure = false;
                validations(k) = ValidateRoadmapTransition( ...
                    analyses(k),spec,validationOptions);
            else
                validations(k) = FailedValidation(spec, ...
                    'Parent-only stage was not accepted.');
            end
            report.analyses = analyses;
            report.validations = validations;
            Checkpoint(finalMat,report);
            if ~validations(k).accepted && options.StopOnCaseFailure
                error('main_Test_RoadmapBifurcationRobustness:ValidationFailed', ...
                    'Held-out validation %s failed.',spec.ID);
            end
        end

        report.analyses = analyses;
        report.validations = validations;
        report.summary = BuildConclusion(analyses,validations,transitions);
        report.status = Ternary(report.summary.accepted,'validated','rejected');
        report.completedAt = Timestamp();
        report.artifacts = SaveArtifacts(report,options,paths);
        if isfield(report,'referenceStageArtifacts')
            report = rmfield(report,'referenceStageArtifacts');
        end
        save(finalMat,'report','-v7');
        % Stage 5 fingerprints the final authoritative MAT. Keep the stage
        % paths out of that MAT to avoid a circular file-hash dependency.
        WriteRoadmapStageArtifacts(report,paths);
        PrintFinalSummary(report);
    catch exception
        report.status = 'failed';
        report.completedAt = Timestamp();
        report.failure = struct('identifier',exception.identifier, ...
            'message',exception.message, ...
            'report',getReport(exception,'extended','hyperlinks','off'));
        Checkpoint(finalMat,report);
        fprintf('\nRoadmap robustness experiment failed: %s\n',exception.message);
        if options.ThrowOnFailure
            rethrow(exception);
        end
    end

    % A scientifically rejected but numerically completed experiment is not
    % an execution failure. Throw only after the numerical catch has closed,
    % so the saved MAT/CSV/Markdown records consistently retain "rejected".
    if options.ThrowOnFailure && strcmp(report.status,'rejected')
        error('main_Test_RoadmapBifurcationRobustness:Rejected', ...
            '%s',report.summary.message);
    end
end

function options = ParseOptions(user,paths)
    if ~isstruct(user) || ~isscalar(user)
        error('main_Test_RoadmapBifurcationRobustness:Options', ...
            'Options must be a scalar structure.');
    end
    defaults = struct();
    defaults.ExperimentRoot = paths.ExperimentRoot;
    defaults.TransitionIDs = {};
    defaults.AnalysisOptions = struct();
    defaults.ValidationOptions = struct();
    defaults.OutputDirectory = paths.FinalResultsRoot;
    defaults.IntermediateDirectory = paths.IntermediateResultsRoot;
    defaults.LogFile = '';
    defaults.MakePlots = true;
    defaults.SaveArtifacts = true;
    defaults.Verbose = true;
    defaults.StopOnCaseFailure = false;
    defaults.OverwriteLog = true;
    defaults.ThrowOnFailure = true;

    names = fieldnames(user);
    allowed = fieldnames(defaults);
    options = defaults;
    for k = 1:numel(names)
        hit = find(strcmpi(names{k},allowed),1);
        if isempty(hit)
            error('main_Test_RoadmapBifurcationRobustness:UnknownOption', ...
                'Unknown option %s.',names{k});
        end
        options.(allowed{hit}) = user.(names{k});
    end
    if ischar(options.TransitionIDs) || ...
            (isstring(options.TransitionIDs) && isscalar(options.TransitionIDs))
        options.TransitionIDs = cellstr(options.TransitionIDs);
    elseif isstring(options.TransitionIDs)
        options.TransitionIDs = cellstr(options.TransitionIDs(:));
    end
    if ~iscell(options.TransitionIDs) || ...
            ~all(cellfun(@(x)ischar(x)||(isstring(x)&&isscalar(x)), ...
                options.TransitionIDs))
        error('main_Test_RoadmapBifurcationRobustness:TransitionIDs', ...
            'TransitionIDs must be a cell array of text IDs.');
    end
    options.TransitionIDs = cellfun(@char,options.TransitionIDs, ...
        'UniformOutput',false);
    normalizedIDs = lower(string(options.TransitionIDs));
    if numel(unique(normalizedIDs)) ~= numel(normalizedIDs)
        error('main_Test_RoadmapBifurcationRobustness:DuplicateTransition', ...
            'TransitionIDs must be unique, ignoring letter case.');
    end
    if ~isstruct(options.AnalysisOptions) || ...
            ~isscalar(options.AnalysisOptions) || ...
            ~isstruct(options.ValidationOptions) || ...
            ~isscalar(options.ValidationOptions)
        error('main_Test_RoadmapBifurcationRobustness:NestedOptions', ...
            'AnalysisOptions and ValidationOptions must be scalar structures.');
    end
    logicals = {'MakePlots','SaveArtifacts','Verbose','StopOnCaseFailure', ...
        'OverwriteLog','ThrowOnFailure'};
    for k = 1:numel(logicals)
        options.(logicals{k}) = ValidateLogical( ...
            options.(logicals{k}),logicals{k});
    end
    options.OutputDirectory = char(string(options.OutputDirectory));
    options.IntermediateDirectory = char(string(options.IntermediateDirectory));
    options.LogFile = char(string(options.LogFile));
    options.ExperimentRoot = char(string(options.ExperimentRoot));
    if ~strcmp(options.ExperimentRoot,paths.ExperimentRoot)
        error('main_Test_RoadmapBifurcationRobustness:ExperimentRoot', ...
            'ExperimentRoot changed while parsing options.');
    end

    suppliedPathFields = struct( ...
        'OutputDirectory',any(strcmpi(names,'OutputDirectory')), ...
        'IntermediateDirectory',any(strcmpi(names,'IntermediateDirectory')), ...
        'LogFile',any(strcmpi(names,'LogFile')));
    options.UserSuppliedFields = names(:).';
    options.UserSuppliedPathFields = suppliedPathFields;
    options.SubsetRouting = struct('enabled',false,'label','','root','', ...
        'outputRoot','','intermediateRoot','','logRoot','', ...
        'outputAutoRouted',false, ...
        'intermediateAutoRouted',false,'logAutoRouted',false);

    if ~isempty(options.TransitionIDs)
        label = SanitizedSubsetLabel(options.TransitionIDs);
        outputRoot = fullfile(paths.ValidationRoot,'subsets',label);
        intermediateRoot = fullfile(paths.SeedSearchRoot,'subsets',label);
        logRoot = fullfile(paths.LogRoot,'subsets',label);
        options.SubsetRouting.enabled = true;
        options.SubsetRouting.label = label;
        % Compatibility alias: root now denotes the canonical validation
        % destination; stage-specific roots below are authoritative.
        options.SubsetRouting.root = outputRoot;
        options.SubsetRouting.outputRoot = outputRoot;
        options.SubsetRouting.intermediateRoot = intermediateRoot;
        options.SubsetRouting.logRoot = logRoot;
        if ~suppliedPathFields.OutputDirectory
            options.OutputDirectory = outputRoot;
            options.SubsetRouting.outputAutoRouted = true;
        end
        if ~suppliedPathFields.IntermediateDirectory
            options.IntermediateDirectory = intermediateRoot;
            options.SubsetRouting.intermediateAutoRouted = true;
        end
        if ~suppliedPathFields.LogFile && ~isempty(options.LogFile)
            options.LogFile = fullfile(logRoot, ...
                'roadmap_robustness_full_experiment.log');
            options.SubsetRouting.logAutoRouted = true;
        end
    end
end

function value = RequestedExperimentRoot(user)
    if ~isstruct(user) || ~isscalar(user)
        error('main_Test_RoadmapBifurcationRobustness:Options', ...
            'Options must be a scalar structure.');
    end
    names = fieldnames(user);
    hits = find(strcmpi(names,'ExperimentRoot'));
    if isempty(hits)
        error('main_Test_RoadmapBifurcationRobustness:ExperimentRootRequired', ...
            ['ExperimentRoot is required. Use ' ...
             'RunRoadmapReferenceExperiment with a package definition, ' ...
             'or pass the owning package root explicitly.']);
    end
    if numel(hits) ~= 1
        error('main_Test_RoadmapBifurcationRobustness:ExperimentRoot', ...
            'ExperimentRoot may be specified only once, ignoring case.');
    end
    value = user.(names{hits});
end

function label = SanitizedSubsetLabel(ids)
    normalized = sort(lower(string(ids(:))));
    normalized = regexprep(normalized,'[^a-z0-9_-]+','_');
    normalized = regexprep(normalized,'^_+|_+$','');
    if any(strlength(normalized) == 0)
        error('main_Test_RoadmapBifurcationRobustness:UnsafeTransitionID', ...
            ['TransitionIDs must contain at least one letter, digit, ' ...
             'underscore, or hyphen.']);
    end
    label = char(strjoin(normalized,'__'));
end

function AddRequiredPaths(paths)
    addpath(paths.ExperimentRoot);
    addpath(paths.SharedImplementationRoot);
    addpath(paths.FloquetRoot);
    floquet.internal.ensureRuntimePaths(true);
end

function EnsureOutputDirectories(options)
    logDirectory = fileparts(options.LogFile);
    directories = {options.OutputDirectory,options.IntermediateDirectory, ...
        logDirectory};
    directories = directories(~cellfun(@isempty,directories));
    directories = unique(directories,'stable');
    for k = 1:numel(directories)
        if ~isfolder(directories{k})
            mkdir(directories{k});
        end
    end
end

function RemoveCompletedParentCheckpoint(filename)
    if ~isfile(filename)
        return
    end
    try
        delete(filename);
    catch cleanupError
        warning( ...
            'main_Test_RoadmapBifurcationRobustness:CheckpointCleanup', ...
            'Completed Stage-A checkpoint could not be removed: %s', ...
            cleanupError.message);
    end
end

function cleanup = StartDiary(options)
    cleanup = [];
    if isempty(options.LogFile)
        return
    end
    directory = fileparts(options.LogFile);
    if ~isfolder(directory), mkdir(directory); end
    if options.OverwriteLog && isfile(options.LogFile)
        delete(options.LogFile);
    end
    diary(options.LogFile);
    cleanup = onCleanup(@()diary('off'));
end

function report = InitialReport(options,paths,transitions)
    report = struct();
    report.version = 'roadmap-bifurcation-robustness-v1';
    report.status = 'running';
    report.startedAt = Timestamp();
    report.completedAt = '';
    report.matlabVersion = version;
    report.repositoryRoot = paths.RepositoryRoot;
    report.experimentRoot = paths.ExperimentRoot;
    report.options = options;
    report.transitions = transitions;
    report.methodScope = ['Retrospective targeted validation in fixed ' ...
        'historical windows. For each transition, its designated daughter ' ...
        'data are excluded from that transition''s Stage-A calculation and ' ...
        'are consulted only in Stage B; a shared branch file may separately ' ...
        'serve as the declared parent of another transition.'];
    report.analyses = repmat(EmptyAnalysisPlaceholder(),1,0);
    report.validations = repmat(EmptyValidationPlaceholder(),1,0);
    report.parentOnly = struct();
    report.summary = struct();
    report.artifacts = struct();
    report.failure = struct();
end

function parent = BuildParentReport(analyses,transitions,options,paths,complete)
    parent = struct();
    parent.version = 'roadmap-parent-only-frozen-predictions-v1';
    parent.generatedAt = Timestamp();
    parent.complete = logical(complete);
    parent.transitionCount = numel(transitions);
    parent.acceptedCount = nnz([analyses.accepted]);
    parent.accepted = complete && all([analyses.accepted]);
    parent.scope = ['Per-transition parent-only calculation after predeclared ' ...
        'window selection. Each transition excludes its own designated ' ...
        'daughter data from Stage A; shared branch-library files may have ' ...
        'a parent role in other transition calculations.'];
    parent.retrospectiveWindowCalibration = true;
    parent.analyses = analyses;
    parent.transitions = transitions;
    parent.analysisOptions = options.AnalysisOptions;
    parent.experimentRoot = paths.ExperimentRoot;
end

function conclusion = BuildConclusion(analyses,validations,transitions)
    parentAccepted = [analyses.accepted];
    heldOutAccepted = [validations.accepted];
    conclusion = struct();
    conclusion.transitionCount = numel(transitions);
    conclusion.parentExperimentCount = numel(unique({transitions.ParentExperiment}));
    conclusion.parentOnlyAcceptedCount = nnz(parentAccepted);
    conclusion.heldOutAcceptedCount = nnz(heldOutAccepted);
    conclusion.expectedCrossingCount = numel(transitions);
    conclusion.detectedCrossingCount = nnz(arrayfun( ...
        @(a)isfield(a,'candidate')&&isstruct(a.candidate)&& ...
        ~isempty(fieldnames(a.candidate)),analyses));
    conclusion.accepted = all(parentAccepted) && all(heldOutAccepted);
    conclusion.coordinates = NaN(1,numel(analyses));
    for k = 1:numel(analyses)
        if isfield(analyses(k),'refinement') && ...
                isfield(analyses(k).refinement,'coordinate')
            conclusion.coordinates(k) = analyses(k).refinement.coordinate;
        end
    end
    conclusion.transitionIDs = {transitions.ID};
    transitionSuffix = Ternary(isscalar(transitions),'','s');
    conclusion.message = sprintf( ...
        ['Parent-only %d/%d; held-out %d/%d; %d targeted transition%s; ' ...
         'robustness status: %s.'], ...
        conclusion.parentOnlyAcceptedCount,numel(transitions), ...
        conclusion.heldOutAcceptedCount,numel(transitions), ...
        numel(transitions),transitionSuffix, ...
        Ternary(conclusion.accepted,'validated','rejected'));
end

function artifacts = SaveArtifacts(report,options,~)
    artifacts = report.artifacts;
    if options.SaveArtifacts
        artifacts = WriteRoadmapRobustnessArtifacts(report,options);
    end
end

function validation = FailedValidation(spec,message)
    validation = EmptyValidationPlaceholder();
    validation.transitionID = spec.ID;
    validation.status = 'not-run';
    validation.rejectionReasons = {message};
end

function value = EmptyAnalysisPlaceholder()
    value = struct('version','','ID','','specification',struct(), ...
        'startedAt','','completedAt','','status','not-run','accepted',false, ...
        'options',struct(),'parentOnlyStages',{{}},'heldOutStagesRun',{{}}, ...
        'daughterDataLoaded',false,'scan',struct(),'candidate',struct(), ...
        'candidateSelection',struct(),'localCoordinateChart',struct(), ...
        'criticalSolution',[],'refinement',struct(),'refinedLocation',struct(), ...
        'symmetry',struct(),'attempts',struct([]),'signPairSymmetry',struct(), ...
        'parentOnlyValidation',struct(),'failure',struct());
end

function value = EmptyValidationPlaceholder()
    value = struct('version','','generatedAt','','accepted',false, ...
        'status','not-run','transitionID','','daughterFile','', ...
        'daughterNearIndex',NaN,'daughterOutgoingIndex',NaN, ...
        'daughterDataRole','','parameterErrorNormInf',NaN, ...
        'coordinateDifference',NaN,'scaledOrbitDistance22',NaN, ...
        'scaledOrbitDifference22',[],'orbitScale22',[], ...
        'linearDirectionAlignment',NaN,'correctionDirectionAlignments',[], ...
        'minimumCorrectionDirectionAlignment',NaN, ...
        'maximumCorrectionDirectionAlignment',NaN, ...
        'criticalPairStateError',NaN,'criticalPairTimingError',NaN, ...
        'daughterPairStateError',NaN,'daughterPairTimingError',NaN, ...
        'daughterGait','','daughterGaitAbbreviation','', ...
        'gaitClassificationError','','nearPeriodicValidation',struct(), ...
        'outgoingPeriodicValidation',struct(),'assertions',struct(), ...
        'rejectionReasons',{{}},'options',struct());
end

function Checkpoint(filename,report)
    try
        save(filename,'report','-v7');
    catch checkpointError
        warning('main_Test_RoadmapBifurcationRobustness:Checkpoint', ...
            'Checkpoint failed: %s',checkpointError.message);
    end
end

function PrintFinalSummary(report)
    fprintf('\n%s\n',report.summary.message);
    for k = 1:numel(report.transitions)
        a=report.analyses(k); v=report.validations(k);
        if a.accepted
            fprintf('  %-9s dx=%.12g parent=%d held-out=%d alignment=%.6f\n', ...
                report.transitions(k).ID,a.refinement.coordinate,a.accepted, ...
                v.accepted,FieldNumber(v,'linearDirectionAlignment',NaN));
        else
            fprintf('  %-9s parent=0 held-out=0\n',report.transitions(k).ID);
        end
    end
end

function value = ValidateLogical(value,name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
        error('main_Test_RoadmapBifurcationRobustness:LogicalOption', ...
            '%s must be scalar logical.',name);
    end
    value = logical(value);
end

function value = FieldNumber(input,name,default)
    if isstruct(input) && isfield(input,name) && ...
            isnumeric(input.(name)) && isscalar(input.(name))
        value = input.(name);
    else
        value = default;
    end
end

function value = Ternary(condition,a,b)
    if condition, value=a; else, value=b; end
end

function value = Timestamp()
    value = char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
end
