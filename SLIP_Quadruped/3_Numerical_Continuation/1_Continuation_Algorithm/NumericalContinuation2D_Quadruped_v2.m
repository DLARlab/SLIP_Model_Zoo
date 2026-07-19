function report = NumericalContinuation2D_Quadruped_v2( ...
        paraset1, paraset2, ParaScan, radius, initial_index, numOPTS, scanOptions)
%NUMERICALCONTINUATION2D_QUADRUPED_V2 Scan a 1-D branch over a model parameter.
% Legacy call (kept for compatibility):
%   NumericalContinuation2D_Quadruped_v2(set1,set2,key,radius,index,opts)
%
% Preferred call (the target values may be unordered):
%   report = NumericalContinuation2D_Quadruped_v2(targets,key,radius,index,opts)
%
% Recommended lineage call (selected branch and exact seed pair):
%   source = struct('BranchFile',file,'SeedIndices',[i i+1]);
%   report = NumericalContinuation2D_Quadruped_v2(source,targets,key,radius,[],opts);
%
% A generated scan can be specified without listing every target:
%   scan = struct('Bounds',[0.5 1.5],'Step',0.1);
%   report = NumericalContinuation2D_Quadruped_v2(scan,key,radius,[],opts);
%
% The scanner selects the closest saved branch for every target, transports
% a same-gait seed pair with adaptive parameter steps, restores the requested
% state-only seed radius, and only then starts the 1-D continuation.

    if nargin < 1
        error('NumericalContinuation2D:MissingScan', ...
            'Provide target values or a scan struct.');
    end
    lineageCall = IsLineageSourceSpec(paraset1);
    compactCall = ~lineageCall && nargin >= 2 && IsTextScalar(paraset2);
    if compactCall
        compactParaScan = paraset2;
        compactRadius = [];
        compactInitialIndex = [];
        compactNumOPTS = [];
        compactScanOptions = struct();
        if nargin >= 3, compactRadius = ParaScan; end
        if nargin >= 4, compactInitialIndex = radius; end
        if nargin >= 5, compactNumOPTS = initial_index; end
        if nargin >= 6 && ~isempty(numOPTS), compactScanOptions = numOPTS; end

        paraset2 = [];
        ParaScan = compactParaScan;
        radius = compactRadius;
        initial_index = compactInitialIndex;
        numOPTS = compactNumOPTS;
        scanOptions = compactScanOptions;
    else
        if nargin < 2, paraset2 = []; end
        if nargin < 3, ParaScan = []; end
        if nargin < 4, radius = []; end
        if nargin < 5, initial_index = []; end
        if nargin < 6, numOPTS = []; end
        if nargin < 7, scanOptions = struct(); end
    end

    if isempty(ParaScan)
        error('NumericalContinuation2D:MissingParameter', ...
            'A parameter key is required (kl, ks, j, ll, lb, or krl).');
    end
    if isempty(radius), radius = 0.02; end
    if isempty(numOPTS), numOPTS = DefaultSolverOptions(); end
    if isempty(scanOptions), scanOptions = struct(); end

    [parameterKey, parameterIndex] = ParameterDefinition(ParaScan);
    if lineageCall
        targets = ResolveScanTargets(paraset2, []);
    else
        targets = ResolveScanTargets(paraset1, paraset2);
    end
    options = ResolveScanOptions(scanOptions);
    ValidateScanInputs(targets, radius, initial_index, options);

    if lineageCall
        source = ResolveLineageSource( ...
            paraset1, parameterIndex, parameterKey, initial_index, options);
        options = ConfigureLineageRun(options, source, targets, parameterKey, radius);
        report = RunLineageScan(source, targets, parameterIndex, parameterKey, ...
            radius, numOPTS, options);
        return;
    end

    branchFolder = char(string(options.BranchFolder));
    catalog = BuildBranchCatalog(branchFolder, parameterIndex, options);
    if isempty(catalog)
        error('NumericalContinuation2D:NoBranches', ...
            'No valid branch MAT-files were found in "%s".', branchFolder);
    end

    report = InitializeReport(targets, parameterKey, radius, branchFolder);
    pendingTargets = targets;
    EmitStatus(options, sprintf( ...
        '2-D continuation scan started.\nParameter: %s\nTargets: %d\nValid source branches: %d', ...
        parameterKey, numel(targets), numel(catalog)));

    while ~isempty(pendingTargets)
        [pendingTargets, skippedTargets] = RemoveExistingTargets( ...
            pendingTargets, catalog, options);
        if ~isempty(skippedTargets)
            report.skipped_targets = [report.skipped_targets, skippedTargets];
            for iSkip = 1:numel(skippedTargets)
                EmitStatus(options, sprintf('%s = %.12g already has a saved branch; skipping.', ...
                    parameterKey, skippedTargets(iSkip)));
            end
        end
        if isempty(pendingTargets)
            break;
        end

        [targetValue, targetPosition] = SelectNextTarget(pendingTargets, catalog, options);
        pendingTargets(targetPosition) = [];
        EmitStatus(options, sprintf('Current target: %s = %.12g', parameterKey, targetValue));

        try
            targetRun = SolveTargetFromCatalog(targetValue, catalog, parameterIndex, ...
                parameterKey, radius, initial_index, numOPTS, options);
            [branchResults, flags, continuationInfo] = RunTargetContinuation( ...
                targetRun, radius, numOPTS, options, parameterKey);

            [savedFile, scanInfo] = SaveScannedBranch(branchResults, flags, ...
                continuationInfo, targetRun, parameterKey, parameterIndex, radius, options);
            catalog(end + 1, 1) = CatalogEntryFromResults( ...
                savedFile, branchResults, parameterIndex, targetRun.expectedGait); %#ok<AGROW>

            runSummary = struct( ...
                'target', targetValue, ...
                'source_parameter', targetRun.sourceParameter, ...
                'source_file', targetRun.sourceFile, ...
                'gait', targetRun.expectedGait.abbr, ...
                'seed_state_distance', targetRun.seedInfo.distance, ...
                'seed_distance_error', targetRun.seedInfo.distanceError, ...
                'seed_residuals', [targetRun.seedInfo.seed1ResidualNorm, ...
                    targetRun.seedInfo.seed2ResidualNorm], ...
                'result_file', savedFile, ...
                'point_count', size(branchResults, 2), ...
                'flags', flags, ...
                'scan_info', scanInfo);
            report.runs(end + 1) = runSummary;
            report.completed_targets(end + 1) = targetValue;
            report.completed_files{end + 1} = savedFile;
            EmitStatus(options, sprintf( ...
                'Target completed: %s = %.12g\nGait: %s\nPoints: %d\nSaved: %s', ...
                parameterKey, targetValue, targetRun.expectedGait.abbr, ...
                size(branchResults, 2), savedFile));
        catch ME
            failure = struct('target', targetValue, 'message', FlattenMessage(ME));
            report.failures(end + 1) = failure;
            EmitStatus(options, sprintf('Target failed: %s = %.12g\n%s', ...
                parameterKey, targetValue, failure.message));
            if ~options.ContinueOnFailure
                rethrow(ME);
            end
        end
    end

    report.success = isempty(report.failures);
    report.finished_at = datetime('now');
    EmitStatus(options, sprintf( ...
        '2-D continuation scan finished.\nCompleted: %d\nSkipped: %d\nFailed: %d', ...
        numel(report.completed_targets), numel(report.skipped_targets), numel(report.failures)));
end

function source = ResolveLineageSource( ...
        sourceSpec, parameterIndex, parameterKey, initialIndex, options)
    branchFile = GetStructField(sourceSpec, {'BranchFile', 'File', 'Filename'});
    sourceResults = GetStructField(sourceSpec, {'Results', 'BranchResults'});
    X1 = GetStructField(sourceSpec, {'X1', 'Seed1'});
    X2 = GetStructField(sourceSpec, {'X2', 'Seed2'});
    Para = GetStructField(sourceSpec, {'Para', 'Parameters'});
    seedIndices = GetStructField(sourceSpec, {'SeedIndices', 'Indices'});
    sourceName = GetStructField(sourceSpec, {'Name', 'BranchName'});

    if ~isempty(branchFile)
        branchFile = ResolveExistingFile(branchFile);
    else
        branchFile = '';
    end
    if isempty(sourceResults) && ~isempty(branchFile)
        data = load(branchFile, 'results');
        if ~isfield(data, 'results')
            error('NumericalContinuation2D:MissingSourceResults', ...
                'The selected source file does not contain results.');
        end
        sourceResults = data.results;
    end
    if ~isempty(sourceResults) && (size(sourceResults, 1) < 29 || size(sourceResults, 2) < 2)
        error('NumericalContinuation2D:InvalidSourceBranch', ...
            'The selected source branch must contain at least 29 rows and two columns.');
    end

    if isempty(X1) || isempty(X2)
        if isempty(sourceResults)
            error('NumericalContinuation2D:MissingSourceSeeds', ...
                'Provide X1/X2 or a source branch with SeedIndices.');
        end
        if isempty(seedIndices)
            seedStart = ResolveSourceSeedStart(initialIndex, size(sourceResults, 2), options);
            seedIndices = [seedStart, seedStart + 1];
        elseif isscalar(seedIndices)
            seedIndices = [seedIndices, seedIndices + 1];
        end
        seedIndices = round(seedIndices(:).');
        if numel(seedIndices) ~= 2 || any(seedIndices < 1) || ...
                any(seedIndices > size(sourceResults, 2)) || seedIndices(1) == seedIndices(2)
            error('NumericalContinuation2D:InvalidSourceSeedIndices', ...
                'SeedIndices must select two distinct columns from the source branch.');
        end
        X1 = sourceResults(1:22, seedIndices(1));
        X2 = sourceResults(1:22, seedIndices(2));
    elseif isempty(seedIndices)
        seedIndices = [NaN, NaN];
    else
        seedIndices = seedIndices(:).';
    end

    X1 = SafeRegulateState(X1);
    X2 = SafeRegulateState(X2);
    if isempty(Para)
        if isempty(sourceResults)
            error('NumericalContinuation2D:MissingSourceParameters', ...
                'Provide Para when the source branch results are unavailable.');
        end
        parameterColumn = 1;
        if ~isempty(seedIndices) && isfinite(seedIndices(1))
            parameterColumn = seedIndices(1);
        end
        Para = sourceResults(23:end, parameterColumn);
    end
    Para = Para(:);
    if numel(Para) < parameterIndex || any(~isfinite(Para))
        error('NumericalContinuation2D:InvalidSourceParameters', ...
            'The source parameter vector is incomplete or non-finite.');
    end

    gait1 = SafeGaitInfo(X1);
    gait2 = SafeGaitInfo(X2);
    if ~GaitsMatch(gait1, gait2)
        error('NumericalContinuation2D:SourceGaitMismatch', ...
            'The selected source seeds do not have the same identifiable gait.');
    end
    if ~GaitMatchesFilter(gait1, options.TargetGait)
        error('NumericalContinuation2D:SourceGaitFilterMismatch', ...
            'The source seed gait %s does not match TargetGait.', gait1.abbr);
    end
    sourceResiduals = [SafeDynamicsResidualNorm(X1, Para), ...
        SafeDynamicsResidualNorm(X2, Para)];
    if any(sourceResiduals >= options.SourceResidualTolerance)
        error('NumericalContinuation2D:InvalidSourceResidual', ...
            'Source seed residuals [%.3e %.3e] must be below %.3e.', ...
            sourceResiduals(1), sourceResiduals(2), options.SourceResidualTolerance);
    end

    if isempty(sourceName)
        if isempty(branchFile)
            sourceName = 'SelectedBranch';
        else
            [~, sourceName] = fileparts(branchFile);
        end
    end
    source = struct();
    source.name = char(string(sourceName));
    source.branchFile = branchFile;
    source.results = sourceResults;
    source.X1 = X1;
    source.X2 = X2;
    source.Para = Para;
    source.seedIndices = seedIndices;
    source.parameter = Para(parameterIndex);
    source.gait = gait1;
    source.sourceResiduals = sourceResiduals;
    source.lineageId = BuildLineageId(source, parameterKey);
end

function seedStart = ResolveSourceSeedStart(initialIndex, pointCount, options)
    if isempty(initialIndex)
        seedStart = round(options.InitialSeedFraction * pointCount);
    elseif initialIndex > 0 && initialIndex < 1
        seedStart = round(initialIndex * pointCount);
    else
        seedStart = round(initialIndex);
    end
    seedStart = max(1, min(pointCount - 1, seedStart));
end

function options = ConfigureLineageRun(options, source, targets, parameterKey, radius)
    if isempty(options.OutputFolder)
        if isempty(options.OutputRoot)
            if isempty(source.branchFile)
                outputRoot = pwd;
            else
                outputRoot = fileparts(source.branchFile);
            end
        else
            outputRoot = char(string(options.OutputRoot));
        end
        if ~isfolder(outputRoot)
            error('NumericalContinuation2D:InvalidOutputRoot', ...
                'OutputRoot does not exist: %s', outputRoot);
        end
        if isempty(options.RunName)
            runName = BuildLineageRunName(source.name, parameterKey, targets);
        else
            runName = SanitizeFileToken(options.RunName);
        end
        outputFolder = fullfile(outputRoot, runName);
    else
        outputFolder = char(string(options.OutputFolder));
    end
    if ~isfolder(outputFolder)
        [created, message] = mkdir(outputFolder);
        if ~created
            error('NumericalContinuation2D:OutputFolderCreateFailed', ...
                'Unable to create output folder "%s": %s', outputFolder, message);
        end
    end
    [resolved, attributes] = fileattrib(outputFolder);
    if ~resolved
        error('NumericalContinuation2D:OutputFolderResolveFailed', ...
            'Unable to resolve output folder "%s".', outputFolder);
    end
    outputFolder = attributes.Name;

    options.OutputFolder = outputFolder;
    options.BranchFolder = outputFolder;
    InitializeLineageRunFiles(source, targets, parameterKey, radius, options);
    if options.ChangeToOutputFolder
        cd(outputFolder);
        EmitStatus(options, sprintf('Current folder changed to scan output:\n%s', outputFolder));
    end
end

function InitializeLineageRunFiles(source, targets, parameterKey, radius, options)
    manifestPath = fullfile(options.OutputFolder, 'scan_manifest.mat');
    if isfile(manifestPath)
        if ~options.ResumeExisting
            error('NumericalContinuation2D:RunFolderExists', ...
                'The run folder already contains a manifest and ResumeExisting is false.');
        end
        data = load(manifestPath, 'manifest');
        if ~isfield(data, 'manifest')
            error('NumericalContinuation2D:InvalidManifest', ...
                'The existing scan manifest is invalid.');
        end
        VerifyLineageManifest(data.manifest, source, targets, parameterKey, radius);
    else
        manifest = BaseLineageManifest(source, targets, parameterKey, radius);
        save(manifestPath, 'manifest');
    end

    sourcePath = fullfile(options.OutputFolder, 'scan_source.mat');
    if options.CopySourceBranch && ~isfile(sourcePath)
        sourceInfo = source;
        sourceInfo.results = [];
        if isempty(source.results)
            save(sourcePath, 'sourceInfo');
        else
            results = source.results;
            save(sourcePath, 'sourceInfo', 'results');
        end
    end
end

function VerifyLineageManifest(manifest, source, targets, parameterKey, radius)
    required = {'lineage_id', 'parameter_key', 'targets', 'radius'};
    if ~all(isfield(manifest, required))
        error('NumericalContinuation2D:InvalidManifest', ...
            'The existing manifest is missing required lineage fields.');
    end
    manifestTargets = sort(manifest.targets(:));
    requestedTargets = sort(targets(:));
    sameTargets = numel(manifestTargets) == numel(requestedTargets) && ...
        all(abs(manifestTargets - requestedTargets) <= ...
        max(1e-10, 1e-8 * max(1, max(abs(targets)))));
    sameRadius = abs(manifest.radius - radius) <= max(1e-10, 1e-8 * max(1, radius));
    if ~strcmp(manifest.lineage_id, source.lineageId) || ...
            ~strcmpi(manifest.parameter_key, parameterKey) || ~sameTargets || ~sameRadius
        error('NumericalContinuation2D:ManifestMismatch', ...
            ['The existing run folder belongs to a different source, target list, ' ...
            'parameter, or radius. Set RunName or OutputFolder to a different location.']);
    end
end

function manifest = BaseLineageManifest(source, targets, parameterKey, radius)
    manifest = struct();
    manifest.version = 2;
    manifest.lineage_id = source.lineageId;
    manifest.source_name = source.name;
    manifest.source_file = source.branchFile;
    manifest.source_parameter = source.parameter;
    manifest.source_seed_indices = source.seedIndices;
    manifest.source_gait = source.gait.abbr;
    manifest.parameter_key = parameterKey;
    manifest.targets = targets;
    manifest.radius = radius;
    manifest.radius_uses_states_only = true;
    manifest.completed_targets = [];
    manifest.skipped_targets = [];
    manifest.failed_targets = [];
    manifest.blocked_targets = [];
    manifest.completed_files = {};
    manifest.created_at = datetime('now');
    manifest.updated_at = manifest.created_at;
end

function report = RunLineageScan( ...
        source, targets, parameterIndex, parameterKey, radius, numOPTS, options)
    catalog = BuildLineageCatalog(options.OutputFolder, parameterIndex, source.lineageId);
    sourceEntry = EmptyCatalogEntry();
    sourceEntry.file = source.branchFile;
    sourceEntry.parameter = source.parameter;
    sourceEntry.pointCount = size(source.results, 2);
    sourceEntry.gait = source.gait;
    sourceEntry.results = source.results;
    sourceEntry.lineageId = source.lineageId;
    sourceEntry.seedPair = LineageSeedPair(source.X1, source.X2, source.Para, ...
        source.seedIndices, source.branchFile);
    catalog(end + 1, 1) = sourceEntry;

    report = InitializeReport(targets, parameterKey, radius, options.OutputFolder);
    report.mode = 'lineage';
    report.lineage_id = source.lineageId;
    report.source_branch = source.branchFile;
    report.output_folder = options.OutputFolder;
    report.blocked_targets = [];
    report.blocked_reasons = {};

    sourceTolerance = ParameterTolerance(source.parameter, options);
    sourceTargets = targets(abs(targets - source.parameter) <= sourceTolerance);
    if ~isempty(sourceTargets)
        report.skipped_targets = [report.skipped_targets, sourceTargets];
    end
    lowerTargets = sort(targets(targets < source.parameter - sourceTolerance), 'descend');
    upperTargets = sort(targets(targets > source.parameter + sourceTolerance), 'ascend');

    EmitStatus(options, sprintf([ ...
        'Lineage scan started.\nSource: %s\nGait: %s\nSource %s: %.12g\n' ...
        'Lower targets: %d\nUpper targets: %d\nOutput: %s'], ...
        source.name, source.gait.abbr, parameterKey, source.parameter, ...
        numel(lowerTargets), numel(upperTargets), options.OutputFolder));
    UpdateLineageManifest(source, targets, parameterKey, radius, report, options);

    [report, catalog] = RunLineageDirection('lower', lowerTargets, source, ...
        report, catalog, parameterIndex, parameterKey, radius, numOPTS, options);
    [report, catalog] = RunLineageDirection('upper', upperTargets, source, ...
        report, catalog, parameterIndex, parameterKey, radius, numOPTS, options); %#ok<ASGLU>

    report.success = isempty(report.failures) && isempty(report.blocked_targets);
    report.finished_at = datetime('now');
    UpdateLineageManifest(source, targets, parameterKey, radius, report, options);
    EmitStatus(options, sprintf([ ...
        'Lineage scan finished.\nCompleted: %d\nResumed/skipped: %d\n' ...
        'Failed: %d\nBlocked: %d\nOutput: %s'], ...
        numel(report.completed_targets), numel(report.skipped_targets), ...
        numel(report.failures), numel(report.blocked_targets), options.OutputFolder));
end

function [report, catalog] = RunLineageDirection(directionName, directionTargets, ...
        source, report, catalog, parameterIndex, parameterKey, radius, numOPTS, options)
    frontier = LineageFrontierFromSource(source);
    for iTarget = 1:numel(directionTargets)
        targetValue = directionTargets(iTarget);
        existingIndex = FindLineageTarget(catalog, targetValue, source.lineageId, ...
            source.gait, parameterIndex, options);
        if ~isempty(existingIndex)
            frontier = LineageFrontierFromEntry(catalog(existingIndex), source.gait);
            report.skipped_targets(end + 1) = targetValue;
            EmitStatus(options, sprintf( ...
                '%s lineage target resumed.\n%s = %.12g\nFile: %s', ...
                UpperFirst(directionName), parameterKey, targetValue, frontier.sourceFile));
            UpdateLineageManifest(source, report.targets, parameterKey, radius, report, options);
            continue;
        end

        EmitStatus(options, sprintf( ...
            '%s lineage target started.\n%s: %.12g -> %.12g\nSource: %s', ...
            UpperFirst(directionName), parameterKey, frontier.parameter, ...
            targetValue, frontier.sourceFile));
        try
            targetRun = SolveLineageTarget(frontier, targetValue, parameterIndex, ...
                radius, numOPTS, options, source.lineageId, directionName);
            [branchResults, flags, continuationInfo] = RunTargetContinuation( ...
                targetRun, radius, numOPTS, options, parameterKey);
            [savedFile, scanInfo] = SaveScannedBranch(branchResults, flags, ...
                continuationInfo, targetRun, parameterKey, parameterIndex, radius, options);

            entry = CatalogEntryFromResults( ...
                savedFile, branchResults, parameterIndex, targetRun.expectedGait);
            entry.lineageId = source.lineageId;
            entry.seedPair = LineageSeedPair(targetRun.X1, targetRun.X2, ...
                targetRun.Para, targetRun.sourceSeedIndices, savedFile);
            catalog(end + 1, 1) = entry; %#ok<AGROW>
            frontier = LineageFrontierFromEntry(entry, source.gait);

            runSummary = BuildRunSummary(targetValue, targetRun, branchResults, ...
                flags, savedFile, scanInfo);
            report.runs(end + 1) = runSummary;
            report.completed_targets(end + 1) = targetValue;
            report.completed_files{end + 1} = savedFile;
            UpdateLineageManifest(source, report.targets, parameterKey, radius, report, options);
        catch ME
            failure = struct('target', targetValue, 'message', FlattenMessage(ME));
            report.failures(end + 1) = failure;
            remainingTargets = directionTargets((iTarget + 1):end);
            report.blocked_targets = [report.blocked_targets, remainingTargets];
            for iBlocked = 1:numel(remainingTargets)
                report.blocked_reasons{end + 1} = sprintf( ...
                    '%s frontier stopped after %.12g failed.', directionName, targetValue);
            end
            UpdateLineageManifest(source, report.targets, parameterKey, radius, report, options);
            EmitStatus(options, sprintf([ ...
                '%s lineage frontier stopped.\nFailed %s = %.12g\nReason: %s\n' ...
                'Farther targets blocked: %d'], ...
                UpperFirst(directionName), parameterKey, targetValue, ...
                failure.message, numel(remainingTargets)));
            if ~options.ContinueOnFailure
                rethrow(ME);
            end
            break;
        end
    end
end

function targetRun = SolveLineageTarget(frontier, targetValue, parameterIndex, ...
        radius, numOPTS, options, lineageId, directionName)
    [X1, X2, Para, transportInfo] = TransportSeedPair( ...
        frontier.X1, frontier.X2, frontier.Para, targetValue, parameterIndex, ...
        frontier.expectedGait, numOPTS, options);
    [X1, X2, seedInfo] = ReconditionSeedPairAtRadius( ...
        X1, X2, Para, radius, frontier.expectedGait, numOPTS, options);

    targetRun = struct();
    targetRun.target = targetValue;
    targetRun.X1 = X1;
    targetRun.X2 = X2;
    targetRun.Para = Para;
    targetRun.expectedGait = frontier.expectedGait;
    targetRun.sourceFile = frontier.sourceFile;
    targetRun.sourceParameter = frontier.parameter;
    targetRun.sourceSeedIndices = frontier.seedIndices;
    targetRun.transportInfo = transportInfo;
    targetRun.seedInfo = seedInfo;
    targetRun.lineageId = lineageId;
    targetRun.direction = directionName;
end

function catalog = BuildLineageCatalog(folder, parameterIndex, lineageId)
    files = dir(fullfile(folder, '*.mat'));
    catalog = repmat(EmptyCatalogEntry(), 0, 1);
    for iFile = 1:numel(files)
        filePath = fullfile(files(iFile).folder, files(iFile).name);
        try
            variables = whos('-file', filePath);
            names = {variables.name};
            if ~any(strcmp(names, 'scanInfo')) || ~any(strcmp(names, 'results'))
                continue;
            end
            data = load(filePath, 'scanInfo');
            scanInfo = data.scanInfo;
            if ~isfield(scanInfo, 'lineage_id') || ...
                    ~strcmp(scanInfo.lineage_id, lineageId) || ...
                    ~isfield(scanInfo, 'seed_pair') || ...
                    ~ValidLineageSeedPair(scanInfo.seed_pair)
                continue;
            end
            resultVariable = variables(strcmp(names, 'results'));
            entry = EmptyCatalogEntry();
            entry.file = filePath;
            entry.parameter = scanInfo.target_value;
            entry.pointCount = resultVariable(1).size(2);
            entry.gait = struct('valid', true, ...
                'type', scanInfo.expected_gait_type, ...
                'abbr', scanInfo.expected_gait_abbr);
            entry.lineageId = lineageId;
            entry.seedPair = scanInfo.seed_pair;
            if numel(scanInfo.seed_pair.Para) < parameterIndex
                continue;
            end
            catalog(end + 1, 1) = entry; %#ok<AGROW>
        catch ME
            warning('NumericalContinuation2D:LineageCatalogReadFailed', ...
                'Ignoring lineage file "%s": %s', filePath, ME.message);
        end
    end
end

function index = FindLineageTarget( ...
        catalog, targetValue, lineageId, expectedGait, parameterIndex, options)
    index = [];
    tolerance = ParameterTolerance(targetValue, options);
    for iEntry = 1:numel(catalog)
        if strcmp(catalog(iEntry).lineageId, lineageId) && ...
                abs(catalog(iEntry).parameter - targetValue) <= tolerance && ...
                LineageEntryIsReusable(catalog(iEntry), targetValue, ...
                expectedGait, parameterIndex, options)
            index = iEntry;
            return;
        end
    end
end

function reusable = LineageEntryIsReusable( ...
        entry, targetValue, expectedGait, parameterIndex, options)
    reusable = false;
    if ~ValidLineageSeedPair(entry.seedPair) || ...
            numel(entry.seedPair.Para) < parameterIndex || ...
            abs(entry.seedPair.Para(parameterIndex) - targetValue) > ...
            ParameterTolerance(targetValue, options)
        return;
    end
    gait1 = SafeGaitInfo(entry.seedPair.X1);
    gait2 = SafeGaitInfo(entry.seedPair.X2);
    if ~GaitsMatch(gait1, expectedGait) || ~GaitsMatch(gait2, expectedGait)
        return;
    end
    residual1 = SafeDynamicsResidualNorm(entry.seedPair.X1, entry.seedPair.Para);
    residual2 = SafeDynamicsResidualNorm(entry.seedPair.X2, entry.seedPair.Para);
    reusable = residual1 < options.SourceResidualTolerance && ...
        residual2 < options.SourceResidualTolerance;
end

function frontier = LineageFrontierFromSource(source)
    frontier = struct('X1', source.X1, 'X2', source.X2, ...
        'Para', source.Para, 'parameter', source.parameter, ...
        'expectedGait', source.gait, 'sourceFile', source.branchFile, ...
        'seedIndices', source.seedIndices);
end

function frontier = LineageFrontierFromEntry(entry, expectedGait)
    frontier = struct('X1', entry.seedPair.X1(:), 'X2', entry.seedPair.X2(:), ...
        'Para', entry.seedPair.Para(:), 'parameter', entry.parameter, ...
        'expectedGait', expectedGait, 'sourceFile', entry.file, ...
        'seedIndices', entry.seedPair.SeedIndices);
end

function seedPair = LineageSeedPair(X1, X2, Para, seedIndices, sourceFile)
    seedPair = struct('X1', X1(:), 'X2', X2(:), 'Para', Para(:), ...
        'SeedIndices', seedIndices, 'SourceFile', sourceFile);
end

function valid = ValidLineageSeedPair(seedPair)
    required = {'X1', 'X2', 'Para', 'SeedIndices', 'SourceFile'};
    valid = isstruct(seedPair) && all(isfield(seedPair, required)) && ...
        numel(seedPair.X1) == 22 && numel(seedPair.X2) == 22 && ...
        ~isempty(seedPair.Para) && all(isfinite([seedPair.X1(:); ...
        seedPair.X2(:); seedPair.Para(:)]));
end

function summary = BuildRunSummary(targetValue, targetRun, results, flags, savedFile, scanInfo)
    summary = struct( ...
        'target', targetValue, ...
        'source_parameter', targetRun.sourceParameter, ...
        'source_file', targetRun.sourceFile, ...
        'gait', targetRun.expectedGait.abbr, ...
        'seed_state_distance', targetRun.seedInfo.distance, ...
        'seed_distance_error', targetRun.seedInfo.distanceError, ...
        'seed_residuals', [targetRun.seedInfo.seed1ResidualNorm, ...
            targetRun.seedInfo.seed2ResidualNorm], ...
        'result_file', savedFile, ...
        'point_count', size(results, 2), ...
        'flags', flags, ...
        'scan_info', scanInfo);
end

function UpdateLineageManifest(source, targets, parameterKey, radius, report, options)
    manifest = BaseLineageManifest(source, targets, parameterKey, radius);
    manifestPath = fullfile(options.OutputFolder, 'scan_manifest.mat');
    previous = struct();
    if isfile(manifestPath)
        data = load(manifestPath, 'manifest');
        if isfield(data, 'manifest')
            previous = data.manifest;
        end
    end
    if isfield(previous, 'created_at')
        manifest.created_at = previous.created_at;
    end

    manifest.completed_targets = UniqueNumericHistory( ...
        PreviousManifestValue(previous, 'completed_targets'), report.completed_targets);
    manifest.skipped_targets = UniqueNumericHistory( ...
        PreviousManifestValue(previous, 'skipped_targets'), report.skipped_targets);
    manifest.failed_targets = UniqueNumericHistory( ...
        PreviousManifestValue(previous, 'failed_targets'), [report.failures.target]);
    if isfield(report, 'blocked_targets')
        manifest.blocked_targets = UniqueNumericHistory( ...
            PreviousManifestValue(previous, 'blocked_targets'), report.blocked_targets);
    end
    manifest.failed_targets = setdiff(manifest.failed_targets, manifest.completed_targets, 'stable');
    manifest.blocked_targets = setdiff(manifest.blocked_targets, manifest.completed_targets, 'stable');
    previousFiles = PreviousManifestValue(previous, 'completed_files');
    if ~iscell(previousFiles)
        previousFiles = {};
    end
    manifest.completed_files = unique([previousFiles(:); report.completed_files(:)], 'stable').';
    manifest.updated_at = datetime('now');

    temporaryPath = fullfile(options.OutputFolder, 'scan_manifest_temp.mat');
    save(temporaryPath, 'manifest');
    [moved, message] = movefile(temporaryPath, manifestPath, 'f');
    if ~moved
        error('NumericalContinuation2D:ManifestSaveFailed', ...
            'Unable to update the scan manifest: %s', message);
    end
end

function name = BuildLineageRunName(sourceName, parameterKey, targets)
    name = sprintf('%s_scan_%s_%s', SanitizeFileToken(sourceName), ...
        parameterKey, ParameterListToken(targets));
    name = SanitizeFileToken(name);
end

function token = ParameterListToken(targets)
    targets = sort(targets(:).');
    if numel(targets) <= 8
        parts = arrayfun(@NumericFileToken, targets, 'UniformOutput', false);
        token = strjoin(parts, '_');
    else
        token = sprintf('%s_to_%s_n%d', NumericFileToken(min(targets)), ...
            NumericFileToken(max(targets)), numel(targets));
    end
end

function values = PreviousManifestValue(manifest, fieldName)
    if isfield(manifest, fieldName)
        values = manifest.(fieldName);
    else
        values = [];
    end
end

function values = UniqueNumericHistory(previousValues, currentValues)
    values = unique([previousValues(:).', currentValues(:).'], 'stable');
end

function token = NumericFileToken(value)
    token = sprintf('%.8g', value);
    token = strrep(token, '-', 'm');
    token = strrep(token, '.', 'p');
    token = strrep(token, '+', '');
end

function lineageId = BuildLineageId(source, parameterKey)
    values = [source.X1(:); source.X2(:); source.Para(:)];
    scaled = mod(abs(round(values * 1e8)), 4294967291);
    weights = mod((1:numel(scaled)).', 65521) + 1;
    checksum = mod(sum(mod(scaled .* weights, 4294967291)), 4294967291);
    lineageId = sprintf('%s__%s__%.12g__%s', ...
        SanitizeFileToken(source.name), parameterKey, source.parameter, ...
        lower(dec2hex(round(checksum), 8)));
end

function filePath = ResolveExistingFile(fileValue)
    filePath = char(string(fileValue));
    if ~isfile(filePath)
        candidate = fullfile(pwd, filePath);
        if isfile(candidate)
            filePath = candidate;
        else
            error('NumericalContinuation2D:SourceFileNotFound', ...
                'Source branch file not found: %s', filePath);
        end
    end
    info = dir(filePath);
    filePath = fullfile(info(1).folder, info(1).name);
end

function textOut = UpperFirst(textIn)
    textOut = char(string(textIn));
    if ~isempty(textOut)
        textOut(1) = upper(textOut(1));
    end
end

function targetRun = SolveTargetFromCatalog(targetValue, catalog, parameterIndex, ...
        parameterKey, radius, initialIndex, numOPTS, options)
    sourceOrder = SourceCandidateOrder(catalog, targetValue, options);
    if isempty(sourceOrder)
        error('NumericalContinuation2D:NoMatchingSource', ...
            'No source branch matches the requested gait filter.');
    end

    sourceOrder = sourceOrder(1:min(numel(sourceOrder), options.MaxSourceBranches));
    attemptMessages = cell(0, 1);
    for iSource = 1:numel(sourceOrder)
        source = catalog(sourceOrder(iSource));
        try
            sourceResults = LoadCatalogResults(source);
            pairCandidates = FindSourceSeedPairs(sourceResults, initialIndex, options);
        catch ME
            attemptMessages{end + 1, 1} = sprintf('%s: %s', ...
                SourceLabel(source), FlattenMessage(ME)); %#ok<AGROW>
            continue;
        end

        for iPair = 1:numel(pairCandidates)
            pair = pairCandidates(iPair);
            EmitStatus(options, sprintf( ...
                'Trying source %d/%d: %s\nSource %s = %.12g\nSeed columns: %d, %d\nGait: %s', ...
                iSource, numel(sourceOrder), SourceLabel(source), parameterKey, ...
                source.parameter, pair.indices(1), pair.indices(2), pair.gait.abbr));
            try
                [X1, X2, Para, transportInfo] = TransportSeedPair( ...
                    pair.X1, pair.X2, pair.Para, targetValue, parameterIndex, ...
                    pair.gait, numOPTS, options);
                [X1, X2, seedInfo] = ReconditionSeedPairAtRadius( ...
                    X1, X2, Para, radius, pair.gait, numOPTS, options);

                targetRun = struct();
                targetRun.target = targetValue;
                targetRun.X1 = X1;
                targetRun.X2 = X2;
                targetRun.Para = Para;
                targetRun.expectedGait = pair.gait;
                targetRun.sourceFile = source.file;
                targetRun.sourceParameter = source.parameter;
                targetRun.sourceSeedIndices = pair.indices;
                targetRun.transportInfo = transportInfo;
                targetRun.seedInfo = seedInfo;
                return;
            catch ME
                attemptMessages{end + 1, 1} = sprintf('%s, columns %d-%d: %s', ...
                    SourceLabel(source), pair.indices(1), pair.indices(2), ...
                    FlattenMessage(ME)); %#ok<AGROW>
            end
        end
    end

    if isempty(attemptMessages)
        details = 'No valid source attempts were available.';
    else
        maxMessages = min(8, numel(attemptMessages));
        details = strjoin(attemptMessages(1:maxMessages), ' | ');
    end
    error('NumericalContinuation2D:TargetSeedFailure', ...
        'Could not prepare same-gait seeds for %s = %.12g. %s', ...
        parameterKey, targetValue, details);
end

function pairs = FindSourceSeedPairs(results, initialIndex, options)
    if size(results, 1) < 29 || size(results, 2) < 2
        error('NumericalContinuation2D:InvalidBranch', ...
            'The source branch must contain at least 29 rows and two columns.');
    end

    pointCount = size(results, 2);
    if isempty(initialIndex) || ~isfinite(initialIndex)
        preferredIndex = max(1, min(pointCount - 1, ...
            round(options.InitialSeedFraction * pointCount)));
    elseif initialIndex > 0 && initialIndex < 1
        preferredIndex = max(1, min(pointCount - 1, round(initialIndex * pointCount)));
    else
        preferredIndex = max(1, min(pointCount - 1, round(initialIndex)));
    end

    pairStarts = 1:(pointCount - 1);
    [~, pairOrder] = sort(abs((pairStarts + 0.5) - preferredIndex), 'ascend');
    pairs = repmat(EmptySeedPair(), 0, 1);
    for iPair = 1:numel(pairOrder)
        idx1 = pairStarts(pairOrder(iPair));
        idx2 = idx1 + 1;
        X1 = SafeRegulateState(results(1:22, idx1));
        X2 = SafeRegulateState(results(1:22, idx2));
        Para = results(23:end, idx1);
        if any(~isfinite([X1; X2; Para]))
            continue;
        end

        gait1 = SafeGaitInfo(X1);
        gait2 = SafeGaitInfo(X2);
        if ~GaitsMatch(gait1, gait2) || ~GaitMatchesFilter(gait1, options.TargetGait)
            continue;
        end

        residual1 = SafeDynamicsResidualNorm(X1, Para);
        residual2 = SafeDynamicsResidualNorm(X2, Para);
        if residual1 >= options.SourceResidualTolerance || ...
                residual2 >= options.SourceResidualTolerance
            continue;
        end
        if StateDistance(X1, X2) <= options.MinimumSeedSeparation
            continue;
        end

        pair = EmptySeedPair();
        pair.X1 = X1;
        pair.X2 = X2;
        pair.Para = Para(:);
        pair.indices = [idx1, idx2];
        pair.gait = gait1;
        pair.sourceResiduals = [residual1, residual2];
        pairs(end + 1, 1) = pair; %#ok<AGROW>
        if numel(pairs) >= options.MaxSeedPairsPerBranch
            break;
        end
    end

    if isempty(pairs)
        error('NumericalContinuation2D:NoSameGaitPair', ...
            ['No adjacent, non-collapsed seed pair near the preferred index had ' ...
            'matching gaits and source residuals below %.3e.'], ...
            options.SourceResidualTolerance);
    end
end

function [X1, X2, Para, info] = TransportSeedPair( ...
        X1, X2, Para, targetValue, parameterIndex, expectedGait, numOPTS, options)
    X1 = SafeRegulateState(X1);
    X2 = SafeRegulateState(X2);
    Para = Para(:);
    sourceValue = Para(parameterIndex);
    parameterTolerance = ParameterTolerance(targetValue, options);

    [X1, sourceSolve1] = RefineSourceSeed(X1, X2, Para, expectedGait, numOPTS, options);
    [X2, sourceSolve2] = RefineSourceSeed(X2, X1, Para, expectedGait, numOPTS, options);

    emptyAttempts = repmat(struct( ...
        'parameter', [], ...
        'step', [], ...
        'accepted', false, ...
        'seed1', struct(), ...
        'seed2', struct()), 0, 1);
    info = struct('sourceValue', sourceValue, 'targetValue', targetValue, ...
        'sourceRefinement', struct('seed1', sourceSolve1, 'seed2', sourceSolve2), ...
        'acceptedSteps', 0, 'rejectedSteps', 0, 'attempts', emptyAttempts);
    if abs(targetValue - sourceValue) <= parameterTolerance
        Para(parameterIndex) = targetValue;
        return;
    end

    totalSpan = abs(targetValue - sourceValue);
    direction = sign(targetValue - sourceValue);
    nominalStep = totalSpan / options.InitialTransportDivisions;
    maximumStep = nominalStep * options.MaximumTransportStepFactor;
    stepMagnitude = min(nominalStep, maximumStep);
    minimumStep = max(parameterTolerance, totalSpan * options.MinimumTransportStepFraction);
    transportOPTS = BoundedTransportSolverOptions(numOPTS, options);
    transportOptions = options;
    transportOptions.MaxCorrectorGuesses = min( ...
        options.MaxCorrectorGuesses, options.TransportMaxCorrectorGuesses);
    previousX1 = [];
    previousX2 = [];
    previousStep = stepMagnitude;
    currentValue = sourceValue;
    consecutiveRejects = 0;
    transportAttemptCount = 0;
    smallAcceptedStepCount = 0;

    while abs(targetValue - currentValue) > parameterTolerance
        transportAttemptCount = transportAttemptCount + 1;
        if transportAttemptCount > options.MaxTransportAttempts
            error('NumericalContinuation2D:TransportStagnated', ...
                ['Parameter transport exceeded %d correction attempts at %.12g ' ...
                'while targeting %.12g.'], ...
                options.MaxTransportAttempts, currentValue, targetValue);
        end
        remaining = abs(targetValue - currentValue);
        stepMagnitude = min(stepMagnitude, remaining);
        trialValue = currentValue + direction * stepMagnitude;
        if remaining <= stepMagnitude * (1 + 1e-12)
            trialValue = targetValue;
        end
        ParaTrial = Para;
        ParaTrial(parameterIndex) = trialValue;

        predictorScale = stepMagnitude / max(previousStep, eps);
        EmitStatus(options, sprintf([ ...
            'Parameter transport trial.\nValue: %.12g -> %.12g\n' ...
            'Step: %.4g\nCorrecting Seed 1'], ...
            currentValue, trialValue, stepMagnitude));
        [ok1, xTry1, solve1] = TryPeriodicSolution( ...
            X1, previousX1, X2, ParaTrial, expectedGait, predictorScale, ...
            transportOPTS, transportOptions);
        if ok1
            EmitStatus(options, sprintf([ ...
                'Parameter transport trial.\nValue: %.12g -> %.12g\n' ...
                'Step: %.4g\nSeed 1 accepted; correcting Seed 2'], ...
                currentValue, trialValue, stepMagnitude));
            [ok2, xTry2, solve2] = TryPeriodicSolution( ...
                X2, previousX2, X1, ParaTrial, expectedGait, predictorScale, ...
                transportOPTS, transportOptions);
        else
            ok2 = false;
            xTry2 = X2;
            solve2 = SkippedSolveInfo('not attempted because Seed 1 failed');
        end

        accepted = ok1 && ok2;
        if accepted
            gait1 = SafeGaitInfo(xTry1);
            gait2 = SafeGaitInfo(xTry2);
            accepted = GaitsMatch(gait1, gait2) && GaitsMatch(gait1, expectedGait);
        end

        attempt = struct('parameter', trialValue, 'step', stepMagnitude, ...
            'accepted', accepted, 'seed1', solve1, 'seed2', solve2);
        info.attempts(end + 1) = attempt;
        if accepted
            acceptedFrom = currentValue;
            oldX1 = X1;
            oldX2 = X2;
            X1 = xTry1;
            X2 = xTry2;
            previousX1 = oldX1;
            previousX2 = oldX2;
            previousStep = stepMagnitude;
            Para = ParaTrial;
            currentValue = trialValue;
            consecutiveRejects = 0;
            info.acceptedSteps = info.acceptedSteps + 1;
            if stepMagnitude < nominalStep * options.SmallTransportStepFraction
                smallAcceptedStepCount = smallAcceptedStepCount + 1;
            else
                smallAcceptedStepCount = 0;
            end
            EmitStatus(options, sprintf([ ...
                'Parameter transport accepted.\nValue: %.12g -> %.12g\n' ...
                'Step: %.4g\nGait: %s\nResiduals: %.3e, %.3e'], ...
                acceptedFrom, currentValue, stepMagnitude, expectedGait.abbr, ...
                solve1.residualNorm, solve2.residualNorm));
            if smallAcceptedStepCount >= options.MaxTransportSmallAcceptedSteps
                error('NumericalContinuation2D:TransportStagnated', ...
                    ['Parameter transport is converging toward a boundary near %.12g: ' ...
                    '%d consecutive accepted steps were below %.3g of the nominal step. ' ...
                    'The requested target %.12g was not reached.'], ...
                    currentValue, smallAcceptedStepCount, ...
                    options.SmallTransportStepFraction, targetValue);
            end
            stepMagnitude = min(maximumStep, stepMagnitude * options.TransportStepGrowth);
        else
            info.rejectedSteps = info.rejectedSteps + 1;
            consecutiveRejects = consecutiveRejects + 1;
            stepMagnitude = stepMagnitude / 2;
            EmitStatus(options, sprintf([ ...
                'Parameter transport rollback triggered.\nRejected value: %.12g\n' ...
                'New step: %.4g\nSeed 1: %s\nSeed 2: %s'], ...
                trialValue, stepMagnitude, solve1.message, solve2.message));
            if stepMagnitude < minimumStep || ...
                    consecutiveRejects > options.MaxTransportBacktracks
                error('NumericalContinuation2D:TransportFailed', ...
                    ['Adaptive transport stalled at %.12g while targeting %.12g. ' ...
                    'Last seed results: %s | %s'], ...
                    currentValue, targetValue, solve1.message, solve2.message);
            end
        end
    end

    Para(parameterIndex) = targetValue;
    info.finalValue = Para(parameterIndex);
end

function solverOptions = BoundedTransportSolverOptions(numOPTS, options)
    maxIterations = optimget(numOPTS, 'MaxIter', options.TransportMaxIterations);
    if isempty(maxIterations) || ~isfinite(maxIterations) || maxIterations <= 0
        maxIterations = options.TransportMaxIterations;
    else
        maxIterations = min(maxIterations, options.TransportMaxIterations);
    end

    maxEvaluations = optimget(numOPTS, 'MaxFunEvals', ...
        options.TransportMaxFunctionEvaluations);
    if isempty(maxEvaluations) || ~isfinite(maxEvaluations) || maxEvaluations <= 0
        maxEvaluations = options.TransportMaxFunctionEvaluations;
    else
        maxEvaluations = min(maxEvaluations, options.TransportMaxFunctionEvaluations);
    end

    solverOptions = optimset(numOPTS, ...
        'MaxIter', maxIterations, ...
        'MaxFunEvals', maxEvaluations);
end

function [X, solveInfo] = RefineSourceSeed( ...
        X, Xother, Para, expectedGait, numOPTS, options)
    residualNorm = SafeDynamicsResidualNorm(X, Para);
    if residualNorm < options.ResidualTolerance
        solveInfo = struct('accepted', true, 'residualNorm', residualNorm, ...
            'exitflag', NaN, 'output', struct(), 'guessIndex', 0, ...
            'message', 'source seed already satisfies strict tolerance');
        return;
    end

    [accepted, X, solveInfo] = TryPeriodicSolution( ...
        X, [], Xother, Para, expectedGait, 1, numOPTS, options);
    if ~accepted
        error('NumericalContinuation2D:SourceRefinementFailed', ...
            'A source seed could not be refined below %.3e: %s', ...
            options.ResidualTolerance, solveInfo.message);
    end
end

function [accepted, Xbest, solveInfo] = TryPeriodicSolution( ...
        Xcurrent, Xprevious, Xother, Para, expectedGait, predictorScale, numOPTS, options)
    guesses = BuildPeriodicGuesses(Xcurrent, Xprevious, Xother, predictorScale, options);
    accepted = false;
    Xbest = Xcurrent;
    bestResidual = Inf;
    bestMessage = 'no converged same-gait candidate';
    bestExitflag = -Inf;
    bestOutput = struct();
    bestGuessIndex = NaN;

    for iGuess = 1:size(guesses, 2)
        try
            [xTry, ~, exitflag, output] = fsolve( ...
                @(X) Quadrupedal_ZeroFun_v2(X, Para, 'skipSolve'), ...
                guesses(:, iGuess), numOPTS);
            xTry = SafeRegulateState(xTry);
            residualNorm = SafeDynamicsResidualNorm(xTry, Para);
            gait = SafeGaitInfo(xTry);
            gaitOK = GaitsMatch(gait, expectedGait);
            if residualNorm < bestResidual
                Xbest = xTry;
                bestResidual = residualNorm;
                bestExitflag = exitflag;
                bestOutput = output;
                bestGuessIndex = iGuess;
            end
            if exitflag > 0 && residualNorm < options.ResidualTolerance && gaitOK
                accepted = true;
                Xbest = xTry;
                bestResidual = residualNorm;
                bestExitflag = exitflag;
                bestOutput = output;
                bestGuessIndex = iGuess;
                bestMessage = sprintf('accepted guess %d', iGuess);
                break;
            elseif ~gaitOK
                bestMessage = sprintf('gait changed to %s', gait.abbr);
            else
                bestMessage = sprintf('exitflag %g, residual %.3e', exitflag, residualNorm);
            end
        catch ME
            bestMessage = FlattenMessage(ME);
        end
    end

    solveInfo = struct('accepted', accepted, 'residualNorm', bestResidual, ...
        'exitflag', bestExitflag, 'output', bestOutput, ...
        'guessIndex', bestGuessIndex, 'message', bestMessage);
end

function solveInfo = SkippedSolveInfo(message)
    solveInfo = struct('accepted', false, 'residualNorm', Inf, ...
        'exitflag', NaN, 'output', struct(), 'guessIndex', NaN, ...
        'message', message);
end

function guesses = BuildPeriodicGuesses(Xcurrent, Xprevious, Xother, predictorScale, options)
    Xcurrent = SafeRegulateState(Xcurrent);
    Xother = SafeRegulateState(Xother);
    guesses = Xcurrent;
    if ~isempty(Xprevious)
        predictor = Xcurrent + predictorScale * (Xcurrent - Xprevious);
        guesses(:, end + 1) = SafeRegulateState(predictor);
    end

    pairDirection = Xother - Xcurrent;
    pairNorm = norm(pairDirection(1:13));
    if pairNorm > options.MinimumSeedSeparation
        perturbation = options.TransportGuessPerturbation * pairDirection;
        guesses(:, end + 1) = SafeRegulateState(Xcurrent + perturbation);
        guesses(:, end + 1) = SafeRegulateState(Xcurrent - perturbation);
    end

    preferredStates = [1, 2, 3, 5];
    perturbationSize = options.TransportGuessPerturbation * ...
        max(1e-3, norm(Xcurrent(1:13)) / sqrt(13));
    for iState = 1:numel(preferredStates)
        guess = Xcurrent;
        guess(preferredStates(iState)) = guess(preferredStates(iState)) + perturbationSize;
        guesses(:, end + 1) = SafeRegulateState(guess); %#ok<AGROW>
        if size(guesses, 2) >= options.MaxCorrectorGuesses
            break;
        end
    end

    guesses = RemoveDuplicateColumns(guesses, options.GuessDuplicateTolerance);
    guesses = guesses(:, 1:min(size(guesses, 2), options.MaxCorrectorGuesses));
end

function [X1, X2, info] = ReconditionSeedPairAtRadius( ...
        X1, X2, Para, radius, expectedGait, numOPTS, options)
    X1 = SafeRegulateState(X1);
    X2 = SafeRegulateState(X2);
    Para = Para(:);

    seed1Residual = SafeDynamicsResidualNorm(X1, Para);
    if seed1Residual >= options.ResidualTolerance
        [ok, X1, seed1Solve] = TryPeriodicSolution( ...
            X1, [], X2, Para, expectedGait, 1, numOPTS, options);
        if ~ok
            error('NumericalContinuation2D:SeedOneInvalid', ...
                'Target Seed 1 could not be refined: %s', seed1Solve.message);
        end
        seed1Residual = seed1Solve.residualNorm;
    end

    directions = BuildRadiusDirections(X1, X2, options);
    rollbackFactors = options.RadiusGuessFactors;
    distanceTolerance = max(options.DistanceAbsoluteTolerance, ...
        options.DistanceRelativeTolerance * radius);
    bestResidual = Inf;
    bestDistanceError = Inf;
    bestMessage = 'no radius-constrained attempt completed';
    attemptCount = 0;

    for iDirection = 1:size(directions, 2)
        if attemptCount >= options.MaxRadiusSolveAttempts, break; end
        for iTiming = 1:2
            if attemptCount >= options.MaxRadiusSolveAttempts, break; end
            if iTiming == 1
                timingSource = X2;
            else
                timingSource = X1;
            end
            for iFactor = 1:numel(rollbackFactors)
                if attemptCount >= options.MaxRadiusSolveAttempts, break; end
                attemptCount = attemptCount + 1;
                factor = rollbackFactors(iFactor);
                guess = X1;
                guess(1:13) = X1(1:13) + factor * radius * directions(:, iDirection);
                guess(14:22) = timingSource(14:22);
                guess = SafeRegulateState(guess);
                EmitStatus(options, sprintf([ ...
                    'Target-radius solve attempt.\nDirection: %d/%d\n' ...
                    'Attempt: %d/%d\nGuess factor: %.2f\nTarget state distance: %.6g'], ...
                    iDirection, size(directions, 2), attemptCount, ...
                    options.MaxRadiusSolveAttempts, factor, radius));
                try
                    [xTry, ~, exitflag, output] = fsolve( ...
                        @(X) RadiusConstrainedResidual(X, X1, Para, radius), guess, numOPTS);
                    xTry = SafeRegulateState(xTry);
                    periodicResidual = SafeDynamicsResidualNorm(xTry, Para);
                    distance = StateDistance(X1, xTry);
                    distanceError = abs(distance - radius);
                    gait = SafeGaitInfo(xTry);
                    gaitOK = GaitsMatch(gait, expectedGait);

                    if periodicResidual < bestResidual || ...
                            (abs(periodicResidual - bestResidual) <= eps && ...
                            distanceError < bestDistanceError)
                        bestResidual = periodicResidual;
                        bestDistanceError = distanceError;
                        bestMessage = sprintf( ...
                            'exitflag %g, residual %.3e, distance error %.3e, gait %s', ...
                            exitflag, periodicResidual, distanceError, gait.abbr);
                    end

                    if exitflag > 0 && periodicResidual < options.ResidualTolerance && ...
                            distanceError <= distanceTolerance && gaitOK
                        X2 = xTry;
                        info = struct( ...
                            'distance', distance, ...
                            'distanceError', distanceError, ...
                            'distanceTolerance', distanceTolerance, ...
                            'seed1ResidualNorm', seed1Residual, ...
                            'seed2ResidualNorm', periodicResidual, ...
                            'gaitType', gait.type, ...
                            'gaitAbbr', gait.abbr, ...
                            'exitflag', exitflag, ...
                            'output', output, ...
                            'directionIndex', iDirection, ...
                            'guessFactor', factor);
                        EmitStatus(options, sprintf([ ...
                            'Target seed pair validated.\nGait: %s\nResiduals: %.3e, %.3e\n' ...
                            'State distance: %.9g\nDistance error: %.3e'], ...
                            gait.abbr, seed1Residual, periodicResidual, ...
                            distance, distanceError));
                        return;
                    end
                catch ME
                    bestMessage = FlattenMessage(ME);
                end
            end
        end
    end

    error('NumericalContinuation2D:RadiusSolveFailed', ...
        ['Could not produce a same-gait second seed at state radius %.6g. ' ...
        'Best result: %s'], radius, bestMessage);
end

function directions = BuildRadiusDirections(X1, X2, options)
    directions = zeros(13, 0);
    pairDirection = NormalizeDirection(X2(1:13) - X1(1:13));
    if ~isempty(pairDirection)
        directions(:, end + 1) = pairDirection;
        directions(:, end + 1) = -pairDirection;
    end

    preferredStates = [1, 2, 3, 5, 6, 8, 10, 12];
    for iState = 1:numel(preferredStates)
        direction = zeros(13, 1);
        direction(preferredStates(iState)) = 1;
        directions(:, end + 1) = direction; %#ok<AGROW>
        directions(:, end + 1) = -direction; %#ok<AGROW>
    end

    stream = RandStream('mt19937ar', 'Seed', options.RandomSeed);
    for iRandom = 1:options.RandomRadiusDirections
        direction = NormalizeDirection(randn(stream, 13, 1));
        if ~isempty(direction)
            directions(:, end + 1) = direction; %#ok<AGROW>
        end
    end
    directions = RemoveDuplicateColumns(directions, options.GuessDuplicateTolerance);
end

function residual = RadiusConstrainedResidual(X, X1, Para, radius)
    periodicResidual = Quadrupedal_ZeroFun_v2(X, Para, 'skipSolve');
    distanceResidual = (StateDistance(X1, X(:)) - radius) / max(radius, 1e-12);
    residual = [periodicResidual(:); distanceResidual];
end

function [results, flags, continuationInfo] = RunTargetContinuation( ...
        targetRun, radius, numOPTS, options, parameterKey)
    runOptions = options.ContinuationRunOptions;
    if ~isstruct(runOptions)
        error('NumericalContinuation2D:InvalidRunOptions', ...
            'ContinuationRunOptions must be a struct.');
    end
    runOptions.SaveTempSol = true;
    runOptions.RequireTemporarySave = true;
    runOptions.TemporarySolutionFile = fullfile( ...
        char(string(options.BranchFolder)), 'solution_tempo.mat');
    runOptions.DeleteTempSolOnFinish = true;
    if ~isfield(runOptions, 'BranchTitle')
        runOptions.BranchTitle = sprintf('2-D Scan | %s = %.12g', ...
            parameterKey, targetRun.target);
    end

    EmitStatus(options, sprintf( ...
        'Starting 1-D continuation at target.\nGait: %s\nState radius: %.6g', ...
        targetRun.expectedGait.abbr, radius));
    [results, flags, continuationInfo] = NumericalContinuation1D_Quadruped_v2( ...
        targetRun.X1, targetRun.X2, targetRun.Para, radius, numOPTS, runOptions);
    WaitForScanControl(options);
end

function [savedFile, scanInfo] = SaveScannedBranch(results, flags, continuationInfo, ...
        targetRun, parameterKey, parameterIndex, radius, options)
    continuationInfo = RemoveTransientFunctionHandles(continuationInfo);
    scanInfo = struct();
    scanInfo.parameter_key = parameterKey;
    scanInfo.parameter_index = parameterIndex;
    scanInfo.target_value = targetRun.target;
    scanInfo.source_file = targetRun.sourceFile;
    scanInfo.source_parameter = targetRun.sourceParameter;
    scanInfo.source_seed_indices = targetRun.sourceSeedIndices;
    scanInfo.expected_gait_type = targetRun.expectedGait.type;
    scanInfo.expected_gait_abbr = targetRun.expectedGait.abbr;
    scanInfo.radius = radius;
    scanInfo.radius_uses_states_only = true;
    scanInfo.transport = targetRun.transportInfo;
    scanInfo.final_seed = targetRun.seedInfo;
    if isfield(targetRun, 'lineageId')
        scanInfo.lineage_id = targetRun.lineageId;
        scanInfo.direction = targetRun.direction;
        scanInfo.seed_pair = LineageSeedPair(targetRun.X1, targetRun.X2, ...
            targetRun.Para, targetRun.sourceSeedIndices, targetRun.sourceFile);
    end
    scanInfo.created_at = datetime('now');

    if ~options.SaveBranches
        savedFile = '';
        return;
    end

    baseName = BranchFilename(results, parameterKey, parameterIndex);
    savedFile = fullfile(char(string(options.BranchFolder)), baseName);
    if isfile(savedFile) && ~options.OverwriteExisting
        savedFile = UniqueFilePath(savedFile);
    end
    save(savedFile, 'results', 'flags', 'continuationInfo', 'scanInfo');
end

function value = RemoveTransientFunctionHandles(value)
    if isa(value, 'function_handle')
        value = [];
        return;
    end

    if iscell(value)
        for i = 1:numel(value)
            value{i} = RemoveTransientFunctionHandles(value{i});
        end
        return;
    end

    if isstruct(value)
        fieldNames = fieldnames(value);
        for elementIndex = 1:numel(value)
            for fieldIndex = 1:numel(fieldNames)
                fieldName = fieldNames{fieldIndex};
                value(elementIndex).(fieldName) = RemoveTransientFunctionHandles( ...
                    value(elementIndex).(fieldName));
            end
        end
    end
end

function filename = BranchFilename(results, parameterKey, parameterIndex)
    Para = results(23:end, 1);
    gait = SafeGaitInfo(results(1:22, max(1, round(size(results, 2) / 2))));
    abbr = SanitizeFileToken(gait.abbr);
    if numel(abbr) >= 2 && abbr(2) == '2'
        prefix = 'BD2';
    else
        prefix = 'BD1';
    end

    if any(strcmp(parameterKey, {'kl', 'ks', 'j'}))
        filename = sprintf('%s_%.12g_%.12g_%.12g_%s.mat', ...
            prefix, Para(1), Para(2), Para(3), abbr);
    else
        filename = sprintf('%s_%.12g_%.12g_%.12g_%s_%.12g.mat', ...
            prefix, Para(1), Para(2), Para(3), abbr, Para(parameterIndex));
    end
    filename = strrep(filename, '+', '');
end

function catalog = BuildBranchCatalog(folder, parameterIndex, options)
    files = dir(fullfile(folder, '*.mat'));
    catalog = repmat(EmptyCatalogEntry(), 0, 1);
    for iFile = 1:numel(files)
        if files(iFile).isdir || IsTemporaryBranchFile(files(iFile).name)
            continue;
        end
        filePath = fullfile(files(iFile).folder, files(iFile).name);
        try
            variables = whos('-file', filePath);
            resultVariable = variables(strcmp({variables.name}, 'results'));
            if isempty(resultVariable) || numel(resultVariable(1).size) < 2 || ...
                    resultVariable(1).size(1) < 29 || resultVariable(1).size(2) < 2
                continue;
            end
            resultSize = resultVariable(1).size;
            sampleIndex = max(1, round(resultSize(2) / 2));
            if IsVersion73MatFile(filePath)
                branchData = matfile(filePath);
                parameterValue = branchData.results(22 + parameterIndex, 1);
                sampleState = branchData.results(1:22, sampleIndex);
            else
                data = load(filePath, 'results');
                parameterValue = data.results(22 + parameterIndex, 1);
                sampleState = data.results(1:22, sampleIndex);
            end
            entry = EmptyCatalogEntry();
            entry.file = filePath;
            entry.parameter = parameterValue;
            entry.pointCount = resultSize(2);
            entry.gait = SafeGaitInfo(sampleState);
            if ~isfinite(entry.parameter) || ~GaitMatchesFilter(entry.gait, options.TargetGait)
                continue;
            end
            catalog(end + 1, 1) = entry; %#ok<AGROW>
        catch ME
            warning('NumericalContinuation2D:BranchCatalogReadFailed', ...
                'Ignoring "%s": %s', filePath, ME.message);
        end
    end
end

function entry = CatalogEntryFromResults(filePath, results, parameterIndex, fallbackGait)
    entry = EmptyCatalogEntry();
    entry.file = filePath;
    entry.parameter = results(22 + parameterIndex, 1);
    entry.pointCount = size(results, 2);
    sampleIndex = max(1, round(size(results, 2) / 2));
    entry.gait = SafeGaitInfo(results(1:22, sampleIndex));
    if ~entry.gait.valid && ~isempty(fallbackGait)
        entry.gait = fallbackGait;
    end
    if isempty(filePath)
        entry.results = results;
    end
end

function results = LoadCatalogResults(entry)
    if ~isempty(entry.results)
        results = entry.results;
        return;
    end
    data = load(entry.file, 'results');
    if ~isfield(data, 'results')
        error('NumericalContinuation2D:MissingResults', ...
            'The source file does not contain a results variable.');
    end
    results = data.results;
end

function [pending, skipped] = RemoveExistingTargets(pending, catalog, options)
    skipped = [];
    if ~options.SkipExisting
        return;
    end
    keep = true(size(pending));
    parameters = [catalog.parameter];
    for iTarget = 1:numel(pending)
        tolerance = ParameterTolerance(pending(iTarget), options);
        if any(abs(parameters - pending(iTarget)) <= tolerance)
            keep(iTarget) = false;
            skipped(end + 1) = pending(iTarget); %#ok<AGROW>
        end
    end
    pending = pending(keep);
end

function [target, position] = SelectNextTarget(pending, catalog, options)
    sourceParameters = [catalog.parameter];
    costs = Inf(size(pending));
    for iTarget = 1:numel(pending)
        validSource = false(size(catalog));
        for iSource = 1:numel(catalog)
            validSource(iSource) = GaitMatchesFilter(catalog(iSource).gait, options.TargetGait);
        end
        if any(validSource)
            costs(iTarget) = min(abs(sourceParameters(validSource) - pending(iTarget)));
        end
    end
    [~, position] = min(costs);
    if isempty(position) || ~isfinite(costs(position))
        error('NumericalContinuation2D:NoMatchingSource', ...
            'No valid source branch is available for the pending targets.');
    end
    target = pending(position);
end

function order = SourceCandidateOrder(catalog, target, options)
    valid = false(size(catalog));
    for iSource = 1:numel(catalog)
        valid(iSource) = GaitMatchesFilter(catalog(iSource).gait, options.TargetGait);
    end
    candidates = find(valid);
    [~, localOrder] = sort(abs([catalog(candidates).parameter] - target), 'ascend');
    order = candidates(localOrder);
end

function targets = ResolveScanTargets(scanSpec, legacySecondSet)
    if isstruct(scanSpec)
        explicitTargets = GetStructField(scanSpec, {'Targets', 'TargetValues', 'Values'});
        if ~isempty(explicitTargets)
            targets = explicitTargets;
        else
            bounds = GetStructField(scanSpec, {'Bounds', 'Range'});
            step = GetStructField(scanSpec, {'Step', 'Increment'});
            if isempty(bounds) || numel(bounds) ~= 2 || isempty(step) || ~isscalar(step)
                error('NumericalContinuation2D:InvalidScanSpec', ...
                    'A scan struct requires Targets, or two Bounds plus a scalar Step.');
            end
            targets = ValuesFromBounds(bounds, step);
        end
    else
        targets = [scanSpec(:).', legacySecondSet(:).'];
    end
    if ~isnumeric(targets) || ~isreal(targets)
        error('NumericalContinuation2D:InvalidTargets', ...
            'Scan targets must be real numeric values.');
    end
    if any(~isfinite(targets))
        error('NumericalContinuation2D:NonfiniteTargets', ...
            'Every scan target must be finite.');
    end
    targets = ApproximateUnique(targets(:).');
end

function values = ValuesFromBounds(bounds, step)
    bounds = bounds(:).';
    if ~all(isfinite(bounds)) || ~isfinite(step) || step == 0
        error('NumericalContinuation2D:InvalidBounds', ...
            'Bounds and Step must be finite, and Step must be nonzero.');
    end
    direction = sign(bounds(2) - bounds(1));
    if direction == 0
        values = bounds(1);
        return;
    end
    step = direction * abs(step);
    values = bounds(1):step:bounds(2);
    endpointTolerance = max(1e-12, 1e-10 * max(1, abs(bounds(2))));
    if isempty(values) || abs(values(end) - bounds(2)) > endpointTolerance
        values(end + 1) = bounds(2);
    else
        values(end) = bounds(2);
    end
end

function values = ApproximateUnique(values)
    uniqueValues = [];
    for iValue = 1:numel(values)
        tolerance = max(1e-12, 1e-10 * max(1, abs(values(iValue))));
        if isempty(uniqueValues) || all(abs(uniqueValues - values(iValue)) > tolerance)
            uniqueValues(end + 1) = values(iValue); %#ok<AGROW>
        end
    end
    values = uniqueValues;
end

function options = ResolveScanOptions(userOptions)
    options = struct();
    options.BranchFolder = pwd;
    options.OutputRoot = '';
    options.OutputFolder = '';
    options.RunName = '';
    options.ResumeExisting = true;
    options.CopySourceBranch = true;
    options.ChangeToOutputFolder = true;
    options.TargetGait = '';
    options.SkipExisting = true;
    options.OverwriteExisting = false;
    options.SaveBranches = true;
    options.ContinueOnFailure = true;
    options.InitialSeedFraction = 0.25;
    options.MaxSourceBranches = 8;
    options.MaxSeedPairsPerBranch = 5;
    options.InitialTransportDivisions = 10;
    options.MinimumTransportStepFraction = 1e-4;
    options.MaxTransportBacktracks = 10;
    options.TransportStepGrowth = 1.5;
    options.MaximumTransportStepFactor = 1;
    options.TransportMaxIterations = 40;
    options.TransportMaxFunctionEvaluations = 1000;
    options.TransportMaxCorrectorGuesses = 3;
    options.MaxTransportAttempts = 50;
    options.MaxTransportSmallAcceptedSteps = 3;
    options.SmallTransportStepFraction = 0.1;
    options.TransportGuessPerturbation = 0.05;
    options.MaxCorrectorGuesses = 8;
    options.ResidualTolerance = 1e-9;
    options.SourceResidualTolerance = 1e-6;
    options.DistanceRelativeTolerance = 1e-4;
    options.DistanceAbsoluteTolerance = 1e-7;
    options.ParameterRelativeTolerance = 1e-8;
    options.ParameterAbsoluteTolerance = 1e-10;
    options.MinimumSeedSeparation = 1e-10;
    options.GuessDuplicateTolerance = 1e-12;
    options.RadiusGuessFactors = [1, 0.75, 0.5, 0.25];
    options.MaxRadiusSolveAttempts = 32;
    options.RandomRadiusDirections = 8;
    options.RandomSeed = 314159;
    options.ContinuationRunOptions = struct();
    options.StatusFcn = [];
    options.ControlFcn = [];

    if ~isstruct(userOptions)
        error('NumericalContinuation2D:InvalidOptions', ...
            'scanOptions must be a struct.');
    end
    names = fieldnames(userOptions);
    for iName = 1:numel(names)
        name = names{iName};
        if ~isfield(options, name)
            error('NumericalContinuation2D:UnknownOption', ...
                'Unknown scan option "%s".', name);
        end
        options.(name) = userOptions.(name);
    end
end

function ValidateScanInputs(targets, radius, initialIndex, options)
    if isempty(targets)
        error('NumericalContinuation2D:EmptyTargets', ...
            'The scan contains no finite target values.');
    end
    if any(targets <= 0)
        error('NumericalContinuation2D:NonpositiveTarget', ...
            'Scanned physical parameter values must be positive.');
    end
    if ~isscalar(radius) || ~isfinite(radius) || radius <= 0
        error('NumericalContinuation2D:InvalidRadius', ...
            'radius must be a finite positive scalar.');
    end
    if ~isempty(initialIndex) && (~isnumeric(initialIndex) || ~isreal(initialIndex) || ...
            ~isscalar(initialIndex) || ~isfinite(initialIndex) || initialIndex <= 0)
        error('NumericalContinuation2D:InvalidInitialIndex', ...
            'initial_index must be empty, a positive column index, or a fraction in (0,1).');
    end
    if ~isfolder(char(string(options.BranchFolder)))
        error('NumericalContinuation2D:InvalidFolder', ...
            'BranchFolder does not exist: %s', char(string(options.BranchFolder)));
    end
    if ~isscalar(options.ResidualTolerance) || ~isfinite(options.ResidualTolerance) || ...
            options.ResidualTolerance <= 0 || options.ResidualTolerance > 1e-9
        error('NumericalContinuation2D:LooseResidualTolerance', ...
            'ResidualTolerance must be positive and at most 1e-9.');
    end
    if ~isscalar(options.SourceResidualTolerance) || ...
            ~isfinite(options.SourceResidualTolerance) || ...
            options.SourceResidualTolerance < options.ResidualTolerance
        error('NumericalContinuation2D:InvalidSourceResidualTolerance', ...
            'SourceResidualTolerance must be finite and no smaller than ResidualTolerance.');
    end
    positiveIntegerFields = {'MaxSourceBranches', 'MaxSeedPairsPerBranch', ...
        'InitialTransportDivisions', 'MaxTransportBacktracks', 'MaxCorrectorGuesses', ...
        'MaxRadiusSolveAttempts', 'TransportMaxIterations', ...
        'TransportMaxFunctionEvaluations', 'TransportMaxCorrectorGuesses', ...
        'MaxTransportAttempts', 'MaxTransportSmallAcceptedSteps'};
    for iField = 1:numel(positiveIntegerFields)
        value = options.(positiveIntegerFields{iField});
        if ~isscalar(value) || ~isfinite(value) || value < 1 || value ~= round(value)
            error('NumericalContinuation2D:InvalidOptionValue', ...
                '%s must be a positive integer.', positiveIntegerFields{iField});
        end
    end
    if ~isscalar(options.RandomRadiusDirections) || ...
            ~isfinite(options.RandomRadiusDirections) || ...
            options.RandomRadiusDirections < 0 || ...
            options.RandomRadiusDirections ~= round(options.RandomRadiusDirections)
        error('NumericalContinuation2D:InvalidOptionValue', ...
            'RandomRadiusDirections must be a nonnegative integer.');
    end
    if ~isempty(options.StatusFcn) && ~isa(options.StatusFcn, 'function_handle')
        error('NumericalContinuation2D:InvalidStatusFcn', ...
            'StatusFcn must be empty or a function handle.');
    end
    if ~isempty(options.ControlFcn) && ~isa(options.ControlFcn, 'function_handle')
        error('NumericalContinuation2D:InvalidControlFcn', ...
            'ControlFcn must be empty or a function handle.');
    end
    if ~isscalar(options.MaximumTransportStepFactor) || ...
            ~isfinite(options.MaximumTransportStepFactor) || ...
            options.MaximumTransportStepFactor < 1
        error('NumericalContinuation2D:InvalidOptionValue', ...
            'MaximumTransportStepFactor must be a finite scalar at least 1.');
    end
    if ~isscalar(options.SmallTransportStepFraction) || ...
            ~isfinite(options.SmallTransportStepFraction) || ...
            options.SmallTransportStepFraction <= 0 || ...
            options.SmallTransportStepFraction > 1
        error('NumericalContinuation2D:InvalidOptionValue', ...
            'SmallTransportStepFraction must be in (0, 1].');
    end
    logicalFields = {'SkipExisting', 'OverwriteExisting', 'SaveBranches', ...
        'ContinueOnFailure', 'ResumeExisting', 'CopySourceBranch', ...
        'ChangeToOutputFolder'};
    for iField = 1:numel(logicalFields)
        value = options.(logicalFields{iField});
        if ~(islogical(value) || isnumeric(value)) || ~isscalar(value) || ...
                ~isfinite(value) || ~ismember(value, [0 1])
            error('NumericalContinuation2D:InvalidOptionValue', ...
                '%s must be a logical scalar.', logicalFields{iField});
        end
    end
    if ~isnumeric(options.RadiusGuessFactors) || isempty(options.RadiusGuessFactors) || ...
            any(~isfinite(options.RadiusGuessFactors)) || ...
            any(options.RadiusGuessFactors <= 0)
        error('NumericalContinuation2D:InvalidRadiusGuessFactors', ...
            'RadiusGuessFactors must contain finite positive values.');
    end
end

function [key, index] = ParameterDefinition(ParaScan)
    key = lower(strtrim(char(string(ParaScan))));
    switch key
        case 'kl'
            index = 1;
        case 'ks'
            index = 2;
        case 'j'
            index = 3;
        case 'll'
            index = 4;
        case 'lb'
            index = 6;
        case 'krl'
            index = 7;
        otherwise
            error('NumericalContinuation2D:UnknownParameter', ...
                'Unknown scan parameter "%s".', key);
    end
end

function options = DefaultSolverOptions()
    options = optimset('Algorithm', 'levenberg-marquardt', ...
        'ScaleProblem', 'jacobian', ...
        'Display', 'iter', ...
        'MaxFunEvals', 50000, ...
        'MaxIter', 3000, ...
        'UseParallel', false, ...
        'TolFun', 1e-12, ...
        'TolX', 1e-12);
end

function gait = SafeGaitInfo(X)
    gait = struct('valid', false, 'type', 'Unknown', 'abbr', 'Unknown');
    try
        X = SafeRegulateState(X);
        [gaitType, gaitAbbr, ~, ~] = Gait_Identification(X);
        gait.type = strtrim(char(string(gaitType)));
        gait.abbr = strtrim(char(string(gaitAbbr)));
        invalid = {'', 'unknown', 'n/a', 'na'};
        gait.valid = ~any(strcmpi(gait.type, invalid)) && ...
            ~any(strcmpi(gait.abbr, invalid));
    catch
        % The invalid default is safer than guessing a gait after an error.
    end
end

function matches = GaitsMatch(gait1, gait2)
    matches = gait1.valid && gait2.valid && ...
        strcmpi(gait1.type, gait2.type) && strcmpi(gait1.abbr, gait2.abbr);
end

function matches = GaitMatchesFilter(gait, gaitFilter)
    filterText = strtrim(char(string(gaitFilter)));
    if isempty(filterText)
        matches = true;
        return;
    end
    matches = gait.valid && (strcmpi(gait.abbr, filterText) || ...
        strcmpi(gait.type, filterText));
end

function X = SafeRegulateState(X)
    X = X(:);
    if numel(X) ~= 22
        error('NumericalContinuation2D:InvalidState', ...
            'A continuation state must contain 22 values.');
    end
    X = EventTimingRegulation(X);
end

function residualNorm = SafeDynamicsResidualNorm(X, Para)
    try
        residual = Quadrupedal_ZeroFun_v2(X, Para, 'skipSolve');
        residualNorm = norm(residual(:));
        if ~isfinite(residualNorm)
            residualNorm = Inf;
        end
    catch
        residualNorm = Inf;
    end
end

function distance = StateDistance(X1, X2)
    distance = norm(X2(1:13) - X1(1:13));
end

function direction = NormalizeDirection(direction)
    direction = direction(:);
    magnitude = norm(direction);
    if ~isfinite(magnitude) || magnitude < 1e-12
        direction = [];
    else
        direction = direction / magnitude;
    end
end

function values = RemoveDuplicateColumns(values, tolerance)
    if isempty(values)
        return;
    end
    keep = true(1, size(values, 2));
    for iColumn = 2:size(values, 2)
        for jColumn = 1:(iColumn - 1)
            if keep(jColumn) && norm(values(:, iColumn) - values(:, jColumn)) <= tolerance
                keep(iColumn) = false;
                break;
            end
        end
    end
    values = values(:, keep);
end

function tolerance = ParameterTolerance(value, options)
    tolerance = max(options.ParameterAbsoluteTolerance, ...
        options.ParameterRelativeTolerance * max(1, abs(value)));
end

function report = InitializeReport(targets, parameterKey, radius, folder)
    report = struct();
    report.parameter = parameterKey;
    report.targets = targets;
    report.radius = radius;
    report.radius_uses_states_only = true;
    report.branch_folder = folder;
    report.started_at = datetime('now');
    report.finished_at = [];
    report.completed_targets = [];
    report.completed_files = {};
    report.skipped_targets = [];
    report.failures = repmat(struct('target', [], 'message', ''), 0, 1);
    report.runs = repmat(struct( ...
        'target', [], 'source_parameter', [], 'source_file', '', 'gait', '', ...
        'seed_state_distance', [], 'seed_distance_error', [], ...
        'seed_residuals', [], 'result_file', '', 'point_count', [], ...
        'flags', [], 'scan_info', struct()), 0, 1);
    report.success = false;
end

function entry = EmptyCatalogEntry()
    entry = struct('file', '', 'parameter', NaN, 'pointCount', 0, ...
        'gait', struct('valid', false, 'type', 'Unknown', 'abbr', 'Unknown'), ...
        'results', [], 'lineageId', '', 'seedPair', struct());
end

function pair = EmptySeedPair()
    pair = struct('X1', [], 'X2', [], 'Para', [], 'indices', [], ...
        'gait', struct('valid', false, 'type', 'Unknown', 'abbr', 'Unknown'), ...
        'sourceResiduals', []);
end

function label = SourceLabel(source)
    if isempty(source.file)
        label = '<in-memory branch>';
    else
        [~, name, extension] = fileparts(source.file);
        label = [name extension];
    end
end

function temporary = IsTemporaryBranchFile(filename)
    lowerName = lower(filename);
    temporary = startsWith(lowerName, 'solution_temp') || ...
        startsWith(lowerName, 'solution_tempo') || ...
        startsWith(lowerName, 'solution_staging') || ...
        startsWith(lowerName, 'xfinal_temp');
end

function supported = IsVersion73MatFile(filePath)
    supported = false;
    fileID = fopen(filePath, 'r');
    if fileID < 0
        return;
    end
    cleanup = onCleanup(@() fclose(fileID));
    header = fread(fileID, 128, '*char').';
    supported = contains(header, 'MATLAB 7.3 MAT-file');
end

function path = UniqueFilePath(path)
    [folder, name, extension] = fileparts(path);
    suffix = 2;
    candidate = path;
    while isfile(candidate)
        candidate = fullfile(folder, sprintf('%s_%d%s', name, suffix, extension));
        suffix = suffix + 1;
    end
    path = candidate;
end

function token = SanitizeFileToken(token)
    token = regexprep(char(string(token)), '[^A-Za-z0-9_.-]+', '_');
    if isempty(token)
        token = 'Unknown';
    end
end

function value = GetStructField(data, candidateNames)
    value = [];
    fields = fieldnames(data);
    for iName = 1:numel(candidateNames)
        match = find(strcmpi(fields, candidateNames{iName}), 1);
        if ~isempty(match)
            value = data.(fields{match});
            return;
        end
    end
end

function EmitStatus(options, message)
    disp(message);
    if ~isempty(options.StatusFcn)
        try
            options.StatusFcn(message);
        catch ME
            warning('NumericalContinuation2D:StatusCallbackFailed', ...
                'StatusFcn failed: %s', ME.message);
        end
    end
    WaitForScanControl(options);
end

function WaitForScanControl(options)
    if isempty(options.ControlFcn)
        return;
    end

    while true
        drawnow;
        try
            callbackValue = options.ControlFcn();
        catch ME
            warning('NumericalContinuation2D:ControlCallbackFailed', ...
                'ControlFcn failed: %s', ME.message);
            return;
        end

        pauseRequested = false;
        stopRequested = false;
        if isstruct(callbackValue)
            if isfield(callbackValue, 'pauseRequested') && ...
                    ~isempty(callbackValue.pauseRequested)
                pauseRequested = logical(callbackValue.pauseRequested(1));
            end
            if isfield(callbackValue, 'stopRequested') && ...
                    ~isempty(callbackValue.stopRequested)
                stopRequested = logical(callbackValue.stopRequested(1));
            end
        elseif islogical(callbackValue) && isscalar(callbackValue)
            stopRequested = callbackValue;
        end

        if stopRequested
            error('NumericalContinuation2D:OperationStopped', ...
                '2-D scan stopped by the user.');
        end
        if ~pauseRequested
            return;
        end
        pause(0.05);
    end
end

function message = FlattenMessage(exception)
    message = strtrim(strrep(exception.message, newline, ' | '));
end

function tf = IsLineageSourceSpec(value)
    if ~isstruct(value) || ~isscalar(value)
        tf = false;
        return;
    end
    fields = fieldnames(value);
    sourceFields = {'BranchFile', 'File', 'Filename', 'Results', ...
        'BranchResults', 'X1', 'Seed1', 'X2', 'Seed2', 'SeedIndices'};
    tf = any(cellfun(@(name) any(strcmpi(fields, name)), sourceFields));
end

function tf = IsTextScalar(value)
    tf = ischar(value) || (isstring(value) && isscalar(value));
end
