function report = ExportRoadmapReferencePackage(packageRoot,transitionIDs,userOptions)
%EXPORTROADMAPREFERENCEPACKAGE Export a local reference-result subset.
%
%   REPORT = EXPORTROADMAPREFERENCEPACKAGE(PACKAGEROOT,TRANSITIONIDS)
%   extracts the named transitions from the authoritative combined roadmap
%   report and writes an independently inspectable reference result beneath
%   PACKAGEROOT.  The package must use the experiment data convention
%
%       data/parent_branch/
%       data/held_out_daughter_branches/
%
%   Parent and daughter branch MAT files are copied byte-for-byte from the
%   combined experiment.  Saved Stage-A Floquet matrices, critical-orbit
%   refinements, timing lifts, and nonlinear corrections are not recomputed
%   or numerically changed.  Every embedded input/output path is remapped to
%   the local package.  Stage-B held-out validation is then rerun using the
%   copied local daughter branches, and all derived artifacts are regenerated.
%
%   This function exports reference evidence; it is not a substitute for a
%   package's main_Test_* entry point, which must recompute Stage A from its
%   local parent branch.
%
%   Optional USEROPTIONS fields:
%       SourceResultFile  authoritative combined MAT file
%       MakePlots         regenerate PNG and FIG files (default true)
%       ThrowOnFailure    throw after saving a rejected export (default true)

%   The final report records explicit combined-reference provenance,
%   including the source report SHA-256, report version, completion time,
%   selected source indices, and the fact that Stage A was not recomputed.


    if nargin < 3 || isempty(userOptions)
        userOptions = struct();
    end
    sourcePaths = RoadmapRobustnessPaths();
    AddRequiredPaths(sourcePaths);
    packageRoot = ValidatePackageRoot(packageRoot,sourcePaths.ExperimentRoot);
    transitionIDs = ValidateTransitionIDs(transitionIDs);
    options = ParseOptions(userOptions,sourcePaths);

    loaded = load(options.SourceResultFile,'report');
    if ~isfield(loaded,'report') || ~isstruct(loaded.report) || ...
            ~isscalar(loaded.report)
        error('ExportRoadmapReferencePackage:SourceReport', ...
            'SourceResultFile must contain one scalar structure named report.');
    end
    sourceReport = loaded.report;
    ValidateSourceReport(sourceReport);
    [sourceIndices,canonicalIDs] = ResolveTransitionIndices( ...
        sourceReport.transitions,transitionIDs);

    local = LocalPaths(packageRoot);
    EnsureDirectories(local);
    sourceExperimentRoot = char(string(sourceReport.experimentRoot));

    sourceTransitions = sourceReport.transitions(sourceIndices);
    sourceAnalyses = sourceReport.analyses(sourceIndices);
    localTransitions = sourceTransitions;
    localAnalyses = sourceAnalyses;
    localValidations = sourceReport.validations(sourceIndices);

    for k = 1:numel(sourceIndices)
        sourceSpec = sourceTransitions(k);
        localSpec = LocalizeSpecification(sourceSpec,local);
        CopyAndVerifyBranch(sourceSpec.ParentFile,localSpec.ParentFile);
        CopyAndVerifyBranch(sourceSpec.DaughterFile,localSpec.DaughterFile);

        localAnalysis = LocalizeAnalysis(sourceAnalyses(k),localSpec);
        AssertStageAUnchanged(sourceAnalyses(k),localAnalysis);
        validationOptions = ResolveValidationOptions( ...
            sourceReport.validations(sourceIndices(k)));
        localValidation = ValidateRoadmapTransition( ...
            localAnalysis,localSpec,validationOptions);
        if ~strcmp(char(string(localValidation.daughterFile)), ...
                localSpec.DaughterFile)
            error('ExportRoadmapReferencePackage:ValidationPath', ...
                'Held-out validation for %s did not use the local daughter.', ...
                localSpec.ID);
        end

        localTransitions(k) = localSpec;
        localAnalyses(k) = localAnalysis;
        localValidations(k) = localValidation;
    end

    report = sourceReport;
    report.experimentRoot = packageRoot;
    report.options = LocalizeRunOptions(sourceReport.options,local,canonicalIDs);
    report.transitions = localTransitions;
    report.analyses = localAnalyses;
    report.validations = localValidations;
    report.methodScope = [ ...
        'Package-local reference export of a retrospective targeted-window ' ...
        'validation. Stage-A Floquet/refinement/correction data are frozen ' ...
        'from the combined roadmap reference; every selected transition''s ' ...
        'Stage-B validation was recomputed using only its package-local ' ...
        'held-out daughter branch. Use this package''s main_Test_* driver ' ...
        'for an independent Stage-A recomputation.'];
    report.parentOnly = BuildLocalParentReport( ...
        sourceReport.parentOnly,localAnalyses,localTransitions,packageRoot);
    report.summary = BuildLocalSummary( ...
        localAnalyses,localValidations,localTransitions);
    report.status = Ternary(report.summary.accepted,'validated','rejected');
    report.failure = struct();
    report.artifactsRefreshedAt = Timestamp();
    report.artifactRefreshScope = [ ...
        'Package-local path remap and Stage-B held-out validation only; ' ...
        'combined-reference Stage-A Floquet/refinement/correction data ' ...
        'remain numerically unchanged.'];
    report.referenceExport = BuildProvenance( ...
        options.SourceResultFile,sourceReport,sourceIndices,canonicalIDs, ...
        packageRoot);

    finalMat = fullfile(local.FinalResultsRoot, ...
        'roadmap_bifurcation_robustness_results.mat');
    parentOnlyMat = fullfile(local.IntermediateResultsRoot, ...
        'parent_only_predictions.mat');
    parentCheckpointMat = fullfile(local.IntermediateResultsRoot, ...
        'parent_only_predictions_checkpoint.mat');
    report.artifacts = struct('finalMat',finalMat, ...
        'parentOnlyMat',parentOnlyMat, ...
        'parentCheckpointMat',parentCheckpointMat);
    writeOptions = struct('OutputDirectory',local.FinalResultsRoot, ...
        'MakePlots',options.MakePlots);
    report.artifacts = WriteRoadmapRobustnessArtifacts(report,writeOptions);
    report.artifacts.finalMat = finalMat;
    report.artifacts.parentOnlyMat = parentOnlyMat;
    report.artifacts.parentCheckpointMat = parentCheckpointMat;

    parentReport = report.parentOnly;
    save(parentOnlyMat,'parentReport','-v7');
    save(parentCheckpointMat,'parentReport','-v7');
    save(finalMat,'report','-v7');

    VerifyExport(report,sourceReport,sourceIndices,sourceExperimentRoot,local);
    reloaded = load(finalMat,'report');
    VerifyExport(reloaded.report,sourceReport,sourceIndices, ...
        sourceExperimentRoot,local);

    fprintf(['Exported %d combined-reference transition(s) to %s; ' ...
        'Stage-B accepted %d/%d.\n'],numel(canonicalIDs),packageRoot, ...
        report.summary.heldOutAcceptedCount,numel(canonicalIDs));
    if options.ThrowOnFailure && ~report.summary.accepted
        error('ExportRoadmapReferencePackage:Rejected', ...
            '%s',report.summary.message);
    end
end

function options = ParseOptions(user,paths)
    if ~isstruct(user) || ~isscalar(user)
        error('ExportRoadmapReferencePackage:Options', ...
            'userOptions must be a scalar structure.');
    end
    defaults = struct('SourceResultFile',fullfile(paths.FinalResultsRoot, ...
        'roadmap_bifurcation_robustness_results.mat'), ...
        'MakePlots',true,'ThrowOnFailure',true);
    options = defaults;
    names = fieldnames(user);
    allowed = fieldnames(defaults);
    for k = 1:numel(names)
        hit = find(strcmpi(names{k},allowed),1);
        if isempty(hit)
            error('ExportRoadmapReferencePackage:UnknownOption', ...
                'Unknown option %s.',names{k});
        end
        options.(allowed{hit}) = user.(names{k});
    end
    options.SourceResultFile = char(string(options.SourceResultFile));
    if ~isfile(options.SourceResultFile)
        error('ExportRoadmapReferencePackage:MissingSource', ...
            'Missing source report %s.',options.SourceResultFile);
    end
    options.MakePlots = ValidateLogical(options.MakePlots,'MakePlots');
    options.ThrowOnFailure = ValidateLogical( ...
        options.ThrowOnFailure,'ThrowOnFailure');
end

function root = ValidatePackageRoot(value,sourceRoot)
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error('ExportRoadmapReferencePackage:PackageRoot', ...
            'packageRoot must be scalar text.');
    end
    root = char(string(value));
    if isempty(root)
        error('ExportRoadmapReferencePackage:PackageRoot', ...
            'packageRoot cannot be empty.');
    end
    if ~IsAbsolutePath(root)
        root = fullfile(pwd,root);
    end
    root = char(java.io.File(root).getCanonicalPath());
    sourceRoot = char(java.io.File(sourceRoot).getCanonicalPath());
    if strcmp(root,sourceRoot) || startsWith(root,[sourceRoot filesep])
        error('ExportRoadmapReferencePackage:SourceOverwrite', ...
            ['The package root cannot be the combined source experiment ' ...
             'or one of its descendants.']);
    end
    if ~isfolder(root)
        [created,message] = mkdir(root);
        if ~created
            error('ExportRoadmapReferencePackage:CreateRoot', ...
                'Unable to create %s: %s',root,message);
        end
    end
end

function tf = IsAbsolutePath(value)
    if ispc
        tf = ~isempty(regexp(value,'^[A-Za-z]:[\\/]|^\\\\','once'));
    else
        tf = startsWith(value,filesep);
    end
end

function ids = ValidateTransitionIDs(value)
    if ischar(value) || (isstring(value) && isscalar(value))
        value = cellstr(value);
    elseif isstring(value)
        value = cellstr(value(:));
    end
    if ~iscell(value) || isempty(value) || ...
            ~all(cellfun(@(x)ischar(x)||(isstring(x)&&isscalar(x)),value))
        error('ExportRoadmapReferencePackage:TransitionIDs', ...
            'transitionIDs must be a nonempty cell array of scalar text.');
    end
    ids = cellfun(@char,value(:).','UniformOutput',false);
    lowered = lower(string(ids));
    if numel(unique(lowered)) ~= numel(lowered)
        error('ExportRoadmapReferencePackage:DuplicateID', ...
            'transitionIDs must be unique, ignoring case.');
    end
end

function ValidateSourceReport(report)
    required = {'version','status','completedAt','repositoryRoot', ...
        'experimentRoot','options','transitions','analyses','validations', ...
        'parentOnly','summary'};
    for k = 1:numel(required)
        if ~isfield(report,required{k})
            error('ExportRoadmapReferencePackage:SourceField', ...
                'Source report lacks required field %s.',required{k});
        end
    end
    count = numel(report.transitions);
    if count < 1 || numel(report.analyses) ~= count || ...
            numel(report.validations) ~= count
        error('ExportRoadmapReferencePackage:SourceCount', ...
            'Source transition, analysis, and validation counts must agree.');
    end
    if ~strcmp(char(string(report.status)),'validated') || ...
            ~IsTrueField(report.summary,'accepted')
        error('ExportRoadmapReferencePackage:SourceRejected', ...
            'Only the authoritative validated source report may be exported.');
    end
end

function [indices,canonicalIDs] = ResolveTransitionIndices(transitions,ids)
    available = {transitions.ID};
    indices = zeros(1,numel(ids));
    for k = 1:numel(ids)
        hit = find(strcmpi(ids{k},available));
        if isempty(hit)
            error('ExportRoadmapReferencePackage:UnknownTransition', ...
                'Unknown transition ID %s.',ids{k});
        elseif numel(hit) ~= 1
            error('ExportRoadmapReferencePackage:AmbiguousTransition', ...
                'Source report contains duplicate transition ID %s.',ids{k});
        end
        indices(k) = hit;
    end
    canonicalIDs = available(indices);
    parentCodes = {transitions(indices).ParentCode};
    if numel(unique(parentCodes)) ~= 1
        error('ExportRoadmapReferencePackage:MixedParents', ...
            'One local package must contain transitions from one parent branch.');
    end
end

function paths = LocalPaths(root)
    paths = struct();
    paths.ExperimentRoot = root;
    paths.ParentBranchRoot = fullfile(root,'data','parent_branch');
    paths.HeldOutDaughterBranchRoot = fullfile( ...
        root,'data','held_out_daughter_branches');
    paths.FinalResultsRoot = fullfile(root,'results','final');
    paths.IntermediateResultsRoot = fullfile(root,'results','intermediate');
    paths.LogRoot = fullfile(root,'logs');
end

function EnsureDirectories(paths)
    names = fieldnames(paths);
    for k = 1:numel(names)
        if endsWith(names{k},'Root') && ~isfolder(paths.(names{k}))
            [created,message] = mkdir(paths.(names{k}));
            if ~created
                error('ExportRoadmapReferencePackage:CreateDirectory', ...
                    'Unable to create %s: %s',paths.(names{k}),message);
            end
        end
    end
end

function local = LocalizeSpecification(source,paths)
    local = source;
    [~,parentName,parentExtension] = fileparts(source.ParentFile);
    [~,daughterName,daughterExtension] = fileparts(source.DaughterFile);
    local.ParentFile = fullfile(paths.ParentBranchRoot, ...
        [parentName parentExtension]);
    local.DaughterFile = fullfile(paths.HeldOutDaughterBranchRoot, ...
        [daughterName daughterExtension]);
end

function analysis = LocalizeAnalysis(source,specification)
    analysis = source;
    analysis.specification = specification;
    if ~isfield(analysis,'scan') || ~isstruct(analysis.scan) || ...
            ~isscalar(analysis.scan) || ~isfield(analysis.scan,'branchFile')
        error('ExportRoadmapReferencePackage:ScanPath', ...
            'Analysis %s lacks scan.branchFile.',analysis.ID);
    end
    analysis.scan.branchFile = specification.ParentFile;
    if ~isfield(analysis,'refinement') || ...
            ~isstruct(analysis.refinement) || ...
            ~isscalar(analysis.refinement) || ...
            ~isfield(analysis.refinement,'indexMapping') || ...
            ~isstruct(analysis.refinement.indexMapping) || ...
            ~isscalar(analysis.refinement.indexMapping) || ...
            ~isfield(analysis.refinement.indexMapping,'source')
        error('ExportRoadmapReferencePackage:RefinementPath', ...
            'Analysis %s lacks refinement.indexMapping.source.',analysis.ID);
    end
    analysis.refinement.indexMapping.source = specification.ParentFile;
end

function CopyAndVerifyBranch(source,destination)
    source = char(string(source));
    destination = char(string(destination));
    if ~isfile(source)
        error('ExportRoadmapReferencePackage:MissingBranch', ...
            'Missing source branch %s.',source);
    end
    directory = fileparts(destination);
    if ~isfolder(directory), mkdir(directory); end
    if ~strcmp(char(java.io.File(source).getCanonicalPath()), ...
            char(java.io.File(destination).getCanonicalPath()))
        [copied,message] = copyfile(source,destination,'f');
        if ~copied
            error('ExportRoadmapReferencePackage:CopyBranch', ...
                'Unable to copy %s: %s',source,message);
        end
    end
    sourceData = load(source);
    localData = load(destination);
    if ~isequaln(sourceData,localData)
        error('ExportRoadmapReferencePackage:BranchMismatch', ...
            'Copied branch differs from source: %s.',destination);
    end
end

function AssertStageAUnchanged(source,local)
    source = ClearAnalysisPaths(source);
    local = ClearAnalysisPaths(local);
    if ~isequaln(source,local)
        error('ExportRoadmapReferencePackage:StageAMutated', ...
            'A non-path Stage-A field changed while exporting %s.',local.ID);
    end
end

function analysis = ClearAnalysisPaths(analysis)
    analysis.specification.ParentFile = '';
    analysis.specification.DaughterFile = '';
    analysis.scan.branchFile = '';
    analysis.refinement.indexMapping.source = '';
end

function options = ResolveValidationOptions(savedValidation)
    if ~isstruct(savedValidation) || ~isscalar(savedValidation) || ...
            ~isfield(savedValidation,'options') || ...
            ~isstruct(savedValidation.options) || ...
            ~isscalar(savedValidation.options)
        error('ExportRoadmapReferencePackage:ValidationOptions', ...
            'Saved validation options are missing or invalid.');
    end
    options = savedValidation.options;
    options.ThrowOnFailure = false;
end

function options = LocalizeRunOptions(source,paths,ids)
    options = source;
    options.TransitionIDs = ids;
    options.OutputDirectory = paths.FinalResultsRoot;
    options.IntermediateDirectory = paths.IntermediateResultsRoot;
    options.LogFile = fullfile(paths.LogRoot, ...
        'roadmap_robustness_full_experiment.log');
    if isfield(options,'ExperimentRoot')
        options.ExperimentRoot = paths.ExperimentRoot;
    end
    if isfield(options,'SubsetRouting') && ...
            isstruct(options.SubsetRouting) && ...
            isscalar(options.SubsetRouting)
        options.SubsetRouting.enabled = false;
        options.SubsetRouting.label = '';
        options.SubsetRouting.root = paths.ExperimentRoot;
        options.SubsetRouting.outputAutoRouted = false;
        options.SubsetRouting.intermediateAutoRouted = false;
        options.SubsetRouting.logAutoRouted = false;
    end
end

function parent = BuildLocalParentReport(source,analyses,transitions,root)
    parent = source;
    parent.complete = true;
    parent.transitionCount = numel(transitions);
    parent.acceptedCount = nnz([analyses.accepted]);
    parent.accepted = all([analyses.accepted]);
    parent.scope = [ ...
        'Package-local frozen Stage-A reference extracted from the combined ' ...
        'roadmap calculation. All embedded branch paths refer to the local ' ...
        'parent/held-out inputs; no Floquet matrix, critical orbit, timing ' ...
        'lift, or nonlinear correction was recomputed by the exporter.'];
    parent.analyses = analyses;
    parent.transitions = transitions;
    parent.experimentRoot = root;
end

function summary = BuildLocalSummary(analyses,validations,transitions)
    parentAccepted = [analyses.accepted];
    heldOutAccepted = [validations.accepted];
    summary = struct();
    summary.transitionCount = numel(transitions);
    summary.parentExperimentCount = numel(unique({transitions.ParentExperiment}));
    summary.parentOnlyAcceptedCount = nnz(parentAccepted);
    summary.heldOutAcceptedCount = nnz(heldOutAccepted);
    summary.expectedCrossingCount = numel(transitions);
    summary.detectedCrossingCount = nnz(arrayfun(@(a) ...
        isfield(a,'candidate') && isstruct(a.candidate) && ...
        ~isempty(fieldnames(a.candidate)),analyses));
    summary.accepted = all(parentAccepted) && all(heldOutAccepted);
    summary.coordinates = NaN(1,numel(analyses));
    for k = 1:numel(analyses)
        if isfield(analyses(k),'refinement') && ...
                isfield(analyses(k).refinement,'coordinate')
            summary.coordinates(k) = analyses(k).refinement.coordinate;
        end
    end
    summary.transitionIDs = {transitions.ID};
    suffix = Ternary(isscalar(transitions),'','s');
    summary.message = sprintf( ...
        ['Parent-only %d/%d; held-out %d/%d; %d targeted transition%s; ' ...
         'package reference status: %s.'], ...
        summary.parentOnlyAcceptedCount,numel(transitions), ...
        summary.heldOutAcceptedCount,numel(transitions), ...
        numel(transitions),suffix,Ternary(summary.accepted, ...
        'validated','rejected'));
end

function provenance = BuildProvenance(sourceFile,sourceReport,indices,ids,root)
    provenance = struct();
    provenance.version = 'combined-roadmap-reference-export-v1';
    provenance.exportedAt = Timestamp();
    provenance.packageRoot = root;
    provenance.sourceExperiment = 'roadmap_bifurcation_robustness';
    provenance.sourceReportRelativePath = RepositoryRelativePath( ...
        sourceFile,sourceReport.repositoryRoot);
    provenance.sourceReportSHA256 = FileSHA256(sourceFile);
    provenance.sourceReportVersion = char(string(sourceReport.version));
    provenance.sourceReportStatus = char(string(sourceReport.status));
    provenance.sourceReportCompletedAt = char(string(sourceReport.completedAt));
    provenance.sourceTransitionIndices = indices;
    provenance.sourceTransitionIDs = ids;
    provenance.stageAFloquetRecomputed = false;
    provenance.stageAReferenceValuesUnchanged = true;
    provenance.branchInputsCopiedAndCompared = true;
    provenance.heldOutValidationRecomputedWithLocalData = true;
    provenance.artifactsRegeneratedFromLocalReport = true;
end

function value = RepositoryRelativePath(filename,repositoryRoot)
    filename = char(java.io.File(filename).getCanonicalPath());
    repositoryRoot = char(java.io.File(repositoryRoot).getCanonicalPath());
    prefix = [repositoryRoot filesep];
    if startsWith(filename,prefix)
        value = filename(numel(prefix)+1:end);
    else
        value = filename;
    end
    value = strrep(value,filesep,'/');
end

function hash = FileSHA256(filename)
    handle = fopen(filename,'rb');
    if handle < 0
        error('ExportRoadmapReferencePackage:HashFile', ...
            'Unable to open %s for hashing.',filename);
    end
    cleanup = onCleanup(@()fclose(handle));
    digest = java.security.MessageDigest.getInstance('SHA-256');
    while true
        bytes = fread(handle,1024*1024,'*uint8');
        if isempty(bytes), break; end
        digest.update(typecast(bytes(:),'int8'));
    end
    raw = typecast(digest.digest(),'uint8');
    hash = lower(reshape(dec2hex(raw,2).',1,[]));
end

function VerifyExport(report,sourceReport,sourceIndices,sourceRoot,paths)
    count = numel(sourceIndices);
    if numel(report.transitions) ~= count || ...
            numel(report.analyses) ~= count || ...
            numel(report.validations) ~= count
        error('ExportRoadmapReferencePackage:VerifyCount', ...
            'Exported transition, analysis, and validation counts disagree.');
    end
    expectedIDs = {sourceReport.transitions(sourceIndices).ID};
    if ~isequal({report.transitions.ID},expectedIDs) || ...
            ~isequal({report.analyses.ID},expectedIDs) || ...
            ~isequal({report.validations.transitionID},expectedIDs)
        error('ExportRoadmapReferencePackage:VerifyIDs', ...
            'Exported transition identities or ordering changed.');
    end
    for k = 1:count
        spec = report.transitions(k);
        analysis = report.analyses(k);
        validation = report.validations(k);
        if ~isequaln(analysis.specification,spec)
            error('ExportRoadmapReferencePackage:VerifySpecification', ...
                'Analysis specification differs for %s.',spec.ID);
        end
        if ~strcmp(analysis.scan.branchFile,spec.ParentFile) || ...
                ~strcmp(analysis.refinement.indexMapping.source,spec.ParentFile)
            error('ExportRoadmapReferencePackage:VerifyParentPath', ...
                'Parent path remap is incomplete for %s.',spec.ID);
        end
        if ~strcmp(validation.daughterFile,spec.DaughterFile)
            error('ExportRoadmapReferencePackage:VerifyDaughterPath', ...
                'Daughter path remap is incomplete for %s.',spec.ID);
        end
        if ~isfile(spec.ParentFile) || ~isfile(spec.DaughterFile)
            error('ExportRoadmapReferencePackage:VerifyData', ...
                'Local input data are missing for %s.',spec.ID);
        end
        AssertStageAUnchanged(sourceReport.analyses(sourceIndices(k)),analysis);
    end
    if ~isequaln(report.parentOnly.transitions,report.transitions) || ...
            ~isequaln(report.parentOnly.analyses,report.analyses)
        error('ExportRoadmapReferencePackage:VerifyParentReport', ...
            'parentOnly does not match the exported transition subset.');
    end
    if report.summary.transitionCount ~= count || ...
            report.summary.expectedCrossingCount ~= count || ...
            ~isequal(report.summary.transitionIDs,expectedIDs)
        error('ExportRoadmapReferencePackage:VerifySummary', ...
            'Subset summary is inconsistent with exported transitions.');
    end
    if ~strcmp(report.experimentRoot,paths.ExperimentRoot) || ...
            ~strcmp(report.parentOnly.experimentRoot,paths.ExperimentRoot) || ...
            ~strcmp(report.options.OutputDirectory,paths.FinalResultsRoot) || ...
            ~strcmp(report.options.IntermediateDirectory, ...
            paths.IntermediateResultsRoot)
        error('ExportRoadmapReferencePackage:VerifyRoots', ...
            'One or more report roots are not package-local.');
    end
    stale = FindTextMatches(report,sourceRoot,'report');
    if ~isempty(stale)
        error('ExportRoadmapReferencePackage:StaleSourcePath', ...
            'Combined source paths remain in exported fields: %s', ...
            strjoin(stale,', '));
    end
    if ~isfield(report,'referenceExport') || ...
            ~IsTrueField(report.referenceExport, ...
            'stageAReferenceValuesUnchanged') || ...
            ~IsTrueField(report.referenceExport, ...
            'heldOutValidationRecomputedWithLocalData')
        error('ExportRoadmapReferencePackage:VerifyProvenance', ...
            'Combined-reference provenance is missing or incomplete.');
    end
end

function matches = FindTextMatches(value,needle,path)
    matches = {};
    if isstruct(value)
        fields = fieldnames(value);
        for element = 1:numel(value)
            for k = 1:numel(fields)
                childPath = sprintf('%s(%d).%s',path,element,fields{k});
                matches = [matches; FindTextMatches( ...
                    value(element).(fields{k}),needle,childPath)]; %#ok<AGROW>
            end
        end
    elseif iscell(value)
        for k = 1:numel(value)
            matches = [matches; FindTextMatches( ...
                value{k},needle,sprintf('%s{%d}',path,k))]; %#ok<AGROW>
        end
    elseif isstring(value)
        if any(contains(value,needle))
            matches = {path};
        end
    elseif ischar(value)
        if contains(value,needle)
            matches = {path};
        end
    end
end

function AddRequiredPaths(paths)
    addpath(paths.ExperimentRoot,paths.FloquetRoot,paths.UtilitiesRoot, ...
        paths.DynamicsRoot,paths.ContinuationAlgorithmRoot, ...
        paths.SolutionManagementRoot);
end

function value = IsTrueField(input,name)
    value = isstruct(input) && isscalar(input) && isfield(input,name) && ...
        isscalar(input.(name)) && ...
        (islogical(input.(name)) || isnumeric(input.(name))) && ...
        isfinite(input.(name)) && logical(input.(name));
end

function value = ValidateLogical(value,name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isreal(value) && isfinite(value) && ...
            any(value == [0 1]))))
        error('ExportRoadmapReferencePackage:LogicalOption', ...
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
