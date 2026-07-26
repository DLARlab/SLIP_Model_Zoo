function report = runRound1Audit()
%RUNROUND1AUDIT Reproduce the non-invasive SLIP Quadruped Round 1 audit.
%   REPORT = RUNROUND1AUDIT() runs static checks, characterization tests,
%   bounded numerical baselines, and reference-artifact integrity checks.
%   All generated output is confined to artifacts/round1-audit.

    repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
    sourceRoot = fullfile(repositoryRoot, 'SLIP_Quadruped');
    auditHelpers = fullfile(repositoryRoot, 'tools', 'audit');
    testRoot = fullfile(repositoryRoot, 'tests', 'round1');
    artifactRoot = fullfile(repositoryRoot, 'artifacts', 'round1-audit');
    if ~isfolder(artifactRoot)
        mkdir(artifactRoot);
    end

    originalDirectory = pwd;
    originalPath = path;
    originalFigureVisibility = get(groot, 'defaultFigureVisible');
    cleanup = onCleanup(@() RestoreSession( ...
        originalDirectory, originalPath, originalFigureVisibility)); %#ok<NASGU>

    addpath(genpath(sourceRoot));
    addpath(auditHelpers);
    addpath(testRoot);
    cd(artifactRoot);
    rng(314159, 'twister');
    set(groot, 'defaultFigureVisible', 'off');

    diaryFile = fullfile(artifactRoot, 'round1-audit.log');
    if exist(diaryFile, 'file')
        delete(diaryFile);
    end
    diary(diaryFile);
    diaryCleanup = onCleanup(@() diary('off')); %#ok<NASGU>

    fprintf('SLIP Model Zoo Round 1 audit\n');
    fprintf('Started: %s\n', char(datetime('now', 'TimeZone', 'local')));
    fprintf('Repository: %s\n', repositoryRoot);
    fprintf('RNG: rng(314159,''twister'')\n');

    report = struct();
    report.started_at = datetime('now', 'TimeZone', 'local');
    report.repository_root = repositoryRoot;
    report.artifact_root = artifactRoot;
    report.random_seed = 314159;
    report.environment = CaptureEnvironment(repositoryRoot);
    report.reference_hashes_before = round1ArtifactHashes(sourceRoot);
    writetable(report.reference_hashes_before, ...
        fullfile(artifactRoot, 'reference-hashes-before.csv'));

    report.name_resolution = CaptureNameResolution(artifactRoot);
    report.dependencies = CaptureDependencies(sourceRoot, artifactRoot);
    report.code_analyzer = RunCodeAnalyzer(sourceRoot, artifactRoot);
    report.tests = RunCharacterizationTests(testRoot, artifactRoot);

    referenceFile = fullfile(sourceRoot, ...
        'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits', ...
        '1_Roadmap', 'PK_20_2.mat');
    report.reference_case = struct('file', referenceFile, 'column', 1);
    report.baselines = RunBoundedBaselines(referenceFile, artifactRoot);
    report.jacobian = RunJacobianAudit(referenceFile, artifactRoot);

    report.reference_hashes_after = round1ArtifactHashes(sourceRoot);
    writetable(report.reference_hashes_after, ...
        fullfile(artifactRoot, 'reference-hashes-after.csv'));
    report.reference_artifacts_unchanged = isequal( ...
        report.reference_hashes_before(:, 1:3), ...
        report.reference_hashes_after(:, 1:3));
    fprintf('Reference artifacts unchanged: %d\n', ...
        report.reference_artifacts_unchanged);

    report.finished_at = datetime('now', 'TimeZone', 'local');
    reportFile = fullfile(artifactRoot, 'round1-audit-report.mat');
    save(reportFile, 'report', '-v7');
    fprintf('Finished: %s\n', char(report.finished_at));
    fprintf('Report: %s\n', reportFile);
end

function environment = CaptureEnvironment(repositoryRoot)
    environment = struct();
    [~, environment.commit] = system( ...
        sprintf('git -C "%s" rev-parse HEAD', repositoryRoot));
    [~, environment.branch] = system( ...
        sprintf('git -C "%s" branch --show-current', repositoryRoot));
    [~, environment.git_status] = system( ...
        sprintf('git -C "%s" status --short --branch', repositoryRoot));
    [~, environment.operating_system] = system('uname -a');
    environment.commit = strtrim(environment.commit);
    environment.branch = strtrim(environment.branch);
    environment.git_status = strtrim(environment.git_status);
    environment.operating_system = strtrim(environment.operating_system);
    environment.matlab_version = version;
    environment.matlab_release = version('-release');
    environment.architecture = computer('arch');
    environment.toolboxes = ver;
    environment.desktop_available = usejava('desktop');
    environment.jvm_available = usejava('jvm');
    environment.display_environment = getenv('DISPLAY');
    environment.rng_state = rng;
    environment.matlab_search_path = path;

    fprintf('Commit: %s\n', environment.commit);
    fprintf('Branch: %s\n', environment.branch);
    fprintf('Git status:\n%s\n', environment.git_status);
    fprintf('OS: %s\n', environment.operating_system);
    fprintf('MATLAB: %s (%s), %s\n', environment.matlab_version, ...
        environment.matlab_release, environment.architecture);
    fprintf('Desktop available: %d; JVM available: %d; DISPLAY="%s"\n', ...
        environment.desktop_available, environment.jvm_available, ...
        environment.display_environment);
    fprintf('Installed products:\n');
    for iProduct = 1:numel(environment.toolboxes)
        fprintf('  %s %s\n', environment.toolboxes(iProduct).Name, ...
            environment.toolboxes(iProduct).Version);
    end
    fprintf('MATLAB search path:\n%s\n', environment.matlab_search_path);
end

function resolution = CaptureNameResolution(artifactRoot)
    names = {'SLIP_Quadruped_GUI', 'Quadrupedal_ZeroFun_v2', ...
        'SolveQuadrupedalZE', 'NumericalContinuation1D_Quadruped_v2', ...
        'NumericalContinuation2D_Quadruped_v2', ...
        'ParameterVarying2D_Quadruped_v2', 'EventTimingRegulation', ...
        'Gait_Identification', 'Func_alphaB_VA_v2', ...
        'Func_alphaF_VA_v2', 'Quadrupedal_ZeroFun_v2_test'};
    resolution = repmat(struct('name', '', 'matches', {{}}), numel(names), 1);
    outputFile = fullfile(artifactRoot, 'which-all.txt');
    fileID = fopen(outputFile, 'w');
    fileCleanup = onCleanup(@() fclose(fileID)); %#ok<NASGU>
    for iName = 1:numel(names)
        matches = which(names{iName}, '-all');
        if ischar(matches)
            matches = cellstr(matches);
        end
        resolution(iName).name = names{iName};
        resolution(iName).matches = matches;
        fprintf(fileID, '%s\n', names{iName});
        if isempty(matches)
            fprintf(fileID, '  <unresolved>\n');
        else
            fprintf(fileID, '  %s\n', matches{:});
        end
    end
    fprintf('Name-resolution report: %s\n', outputFile);
end

function dependencies = CaptureDependencies(sourceRoot, artifactRoot)
    dependencies = struct('status', 'not-run', 'required_files', {{}}, ...
        'products', []);
    entryPoints = { ...
        fullfile(sourceRoot, 'SLIP_Quadruped_GUI.m'), ...
        fullfile(sourceRoot, '1_Dynamic_Frameworks', 'v2', ...
            'Quadrupedal_ZeroFun_v2.m'), ...
        fullfile(sourceRoot, '3_Numerical_Continuation', ...
            '1_Continuation_Algorithm', ...
            'NumericalContinuation1D_Quadruped_v2.m'), ...
        fullfile(sourceRoot, '3_Numerical_Continuation', ...
            '1_Continuation_Algorithm', ...
            'NumericalContinuation2D_Quadruped_v2.m')};
    try
        [requiredFiles, products] = ...
            matlab.codetools.requiredFilesAndProducts(entryPoints);
        dependencies.status = 'completed';
        dependencies.required_files = requiredFiles;
        dependencies.products = products;
        save(fullfile(artifactRoot, 'dependency-analysis.mat'), ...
            'requiredFiles', 'products');
        fprintf('Dependency analysis completed: %d files, %d products.\n', ...
            numel(requiredFiles), numel(products));
    catch exception
        dependencies.status = 'failed';
        dependencies.error = getReport(exception, 'extended', ...
            'hyperlinks', 'off');
        fprintf('Dependency analysis failed:\n%s\n', dependencies.error);
    end
end

function analyzer = RunCodeAnalyzer(sourceRoot, artifactRoot)
    files = dir(fullfile(sourceRoot, '**', '*.m'));
    analyzer = struct('status', 'completed', 'files', {{}}, ...
        'messages', {{}}, 'error', '');
    analyzer.files = arrayfun(@(item) fullfile(item.folder, item.name), ...
        files, 'UniformOutput', false);
    analyzer.messages = cell(numel(files), 1);
    try
        for iFile = 1:numel(files)
            analyzer.messages{iFile} = checkcode(analyzer.files{iFile}, ...
                '-id', '-struct');
        end
        save(fullfile(artifactRoot, 'code-analyzer.mat'), 'analyzer');
        messageCount = sum(cellfun(@numel, analyzer.messages));
        fprintf('Code Analyzer completed: %d files, %d messages.\n', ...
            numel(files), messageCount);
    catch exception
        analyzer.status = 'failed';
        analyzer.error = getReport(exception, 'extended', ...
            'hyperlinks', 'off');
        fprintf('Code Analyzer failed:\n%s\n', analyzer.error);
    end
end

function testSummary = RunCharacterizationTests(testRoot, artifactRoot)
    testSummary = struct('status', 'not-run', 'passed', 0, ...
        'failed', 0, 'incomplete', 0, 'error', '');
    try
        suite = testsuite(testRoot, 'IncludeSubfolders', true);
        results = run(suite);
        testSummary.status = 'completed';
        testSummary.passed = sum([results.Passed]);
        testSummary.failed = sum([results.Failed]);
        testSummary.incomplete = sum([results.Incomplete]);
        save(fullfile(artifactRoot, 'test-results.mat'), 'results');
        fprintf('Tests: %d passed, %d failed, %d incomplete.\n', ...
            testSummary.passed, testSummary.failed, testSummary.incomplete);
    catch exception
        testSummary.status = 'failed';
        testSummary.error = getReport(exception, 'extended', ...
            'hyperlinks', 'off');
        fprintf('Tests failed to run:\n%s\n', testSummary.error);
    end
end

function baselines = RunBoundedBaselines(referenceFile, artifactRoot)
    data = load(referenceFile, 'results');
    branch = data.results;
    z = branch(1:22, 1);
    parameters = branch(23:29, 1);
    baselines = struct();

    baselines.residual_only = TimedOperation(@() ...
        Quadrupedal_ZeroFun_v2(z, parameters, 'skipSolve'));
    if strcmp(baselines.residual_only.status, 'completed')
        baselines.residual_only.residual_norm = ...
            norm(baselines.residual_only.output);
    end

    baselines.full_output = TimedOperation(@() ...
        FullStrideOutputs(z, parameters));
    if strcmp(baselines.full_output.status, 'completed')
        outputs = baselines.full_output.output;
        baselines.full_output.residual_norm = norm(outputs.residual);
        baselines.full_output.ode_output_points = numel(outputs.T);
    end

    baselines.root_correction = RunRootCorrection(z, parameters);
    baselines.continuation = RunShortContinuation(branch, parameters);
    baselines.gait_single = TimedOperation(@() GaitOutputs(z));
    baselines.gait_branch = TimedOperation(@() GaitOutputs(branch(1:22, :)));
    baselines.graphics = RunHeadlessGraphics( ...
        baselines.full_output, artifactRoot);
    baselines.mat_catalog = TimeMatCatalog(fileparts(referenceFile));
    baselines.profile = RunProfileBaseline(z, parameters, artifactRoot);
    save(fullfile(artifactRoot, 'bounded-baselines.mat'), 'baselines');
end

function result = RunRootCorrection(z, parameters)
    if isempty(which('fsolve'))
        result = struct('status', 'blocked', ...
            'error', 'fsolve is unresolved (Optimization Toolbox unavailable).');
        return;
    end
    perturbed = z + 1e-7 * max(1, abs(z)) .* sin((1:numel(z)).');
    options = optimset('Algorithm', 'levenberg-marquardt', ...
        'Display', 'off', 'MaxIter', 8, 'MaxFunEvals', 100, ...
        'TolFun', 1e-10, 'TolX', 1e-10);
    timer = tic;
    try
        [solution, residual, exitflag, output] = fsolve( ...
            @(candidate) Quadrupedal_ZeroFun_v2( ...
                candidate, parameters, 'skipSolve'), perturbed, options);
        result = struct('status', 'completed', 'seconds', toc(timer), ...
            'input', perturbed, 'solution', solution, ...
            'residual_norm', norm(residual), 'exitflag', exitflag, ...
            'solver_output', output, 'options', options);
    catch exception
        result = struct('status', 'failed', 'seconds', toc(timer), ...
            'error', getReport(exception, 'extended', 'hyperlinks', 'off'), ...
            'options', options);
    end
end

function result = RunShortContinuation(branch, parameters)
    if size(branch, 2) < 2
        result = struct('status', 'blocked', ...
            'error', 'Reference branch has fewer than two columns.');
        return;
    end
    options = optimset('Algorithm', 'levenberg-marquardt', ...
        'Display', 'off', 'MaxIter', 2, 'MaxFunEvals', 50, ...
        'TolFun', 1e-10, 'TolX', 1e-10);
    runtime = struct('ResetFigureOnStart', false, ...
        'ClearCommandWindow', false, 'SaveTempSol', false, ...
        'IlluSols', false, 'DisplayCommandStatus', false, ...
        'DirectionPauseSeconds', 0, 'FailurePauseSeconds', 0, ...
        'RadiusReductionPauseSeconds', 0, ...
        'PromptVelocityZeroCrossing', false, ...
        'MaxIterationsPerDirection', 1);
    timer = tic;
    try
        [results, flags, info] = NumericalContinuation1D_Quadruped_v2( ...
            branch(1:22, 1), branch(1:22, 2), parameters, ...
            0.01, options, runtime);
        result = struct('status', 'completed', 'seconds', toc(timer), ...
            'result_columns', size(results, 2), 'flags', flags, ...
            'info', info, 'options', options, 'runtime_options', runtime);
    catch exception
        result = struct('status', 'failed', 'seconds', toc(timer), ...
            'error', getReport(exception, 'extended', 'hyperlinks', 'off'), ...
            'options', options, 'runtime_options', runtime);
    end
end

function result = RunHeadlessGraphics(fullOutputBaseline, artifactRoot)
    if ~strcmp(fullOutputBaseline.status, 'completed')
        result = struct('status', 'blocked', ...
            'error', 'Full-output stride baseline did not complete.');
        return;
    end
    timer = tic;
    figureHandle = [];
    try
        output = fullOutputBaseline.output;
        figureHandle = figure('Visible', 'off');
        axesHandle = axes('Parent', figureHandle);
        graphic = SLIP_PeriodicOrbit_Quad(output.Y, ...
            [0.13 0.11 0.775 0.815], axesHandle, [0 0.4470 0.7410]);
        graphic.update(output.Y(1, :));
        drawnow;
        outputFile = fullfile(artifactRoot, 'headless-periodic-orbit.png');
        exportgraphics(figureHandle, outputFile);
        result = struct('status', 'completed', 'seconds', toc(timer), ...
            'file', outputFile);
        close(figureHandle);
    catch exception
        if ~isempty(figureHandle) && isgraphics(figureHandle)
            close(figureHandle);
        end
        result = struct('status', 'failed', 'seconds', toc(timer), ...
            'error', getReport(exception, 'extended', 'hyperlinks', 'off'));
    end
end

function result = TimeMatCatalog(folder)
    files = dir(fullfile(folder, '*.mat'));
    timer = tic;
    loadedBytes = 0;
    columns = zeros(numel(files), 1);
    try
        for iFile = 1:numel(files)
            data = load(fullfile(files(iFile).folder, files(iFile).name), ...
                'results');
            info = whos('data');
            loadedBytes = loadedBytes + info.bytes;
            columns(iFile) = size(data.results, 2);
        end
        result = struct('status', 'completed', 'seconds', toc(timer), ...
            'files', numel(files), 'loaded_workspace_bytes', loadedBytes, ...
            'columns', columns);
    catch exception
        result = struct('status', 'failed', 'seconds', toc(timer), ...
            'error', getReport(exception, 'extended', 'hyperlinks', 'off'));
    end
end

function result = RunProfileBaseline(z, parameters, artifactRoot)
    timer = tic;
    try
        profile clear;
        profile on;
        Quadrupedal_ZeroFun_v2(z, parameters, 'skipSolve');
        profile off;
        profileInfo = profile('info');
        profileRoot = fullfile(artifactRoot, 'profile-residual-only');
        if ~isfolder(profileRoot)
            mkdir(profileRoot);
        end
        profsave(profileInfo, profileRoot);
        save(fullfile(artifactRoot, 'profile-residual-only.mat'), ...
            'profileInfo');
        result = struct('status', 'completed', 'seconds', toc(timer), ...
            'profile_root', profileRoot, ...
            'function_count', numel(profileInfo.FunctionTable));
    catch exception
        profile off;
        result = struct('status', 'failed', 'seconds', toc(timer), ...
            'error', getReport(exception, 'extended', 'hyperlinks', 'off'));
    end
end

function jacobian = RunJacobianAudit(referenceFile, artifactRoot)
    data = load(referenceFile, 'results');
    z = data.results(1:22, 1);
    parameters = data.results(23:29, 1);
    timer = tic;
    try
        reports = round1FiniteDifferenceJacobian(@(candidate) ...
            Quadrupedal_ZeroFun_v2(candidate, parameters, 'skipSolve'), ...
            z, [1e-4, 1e-5, 1e-6]);
        jacobian = struct('status', 'completed', 'seconds', toc(timer), ...
            'reports', reports);
        save(fullfile(artifactRoot, 'jacobian-audit.mat'), ...
            'reports', 'z', 'parameters');
        fprintf('Jacobian audit completed in %.6g seconds.\n', ...
            jacobian.seconds);
    catch exception
        jacobian = struct('status', 'failed', 'seconds', toc(timer), ...
            'error', getReport(exception, 'extended', 'hyperlinks', 'off'));
        fprintf('Jacobian audit failed:\n%s\n', jacobian.error);
    end
end

function result = TimedOperation(operation)
    timer = tic;
    try
        output = operation();
        result = struct('status', 'completed', 'seconds', toc(timer), ...
            'output', output);
    catch exception
        result = struct('status', 'failed', 'seconds', toc(timer), ...
            'error', getReport(exception, 'extended', 'hyperlinks', 'off'));
    end
end

function output = FullStrideOutputs(z, parameters)
    [output.residual, output.T, output.Y, output.P, output.GRFs, ...
        output.Y_EVENT] = Quadrupedal_ZeroFun_v2( ...
        z, parameters, 'skipSolve');
end

function output = GaitOutputs(results)
    [output.gait, output.abbreviation, output.color, output.line_type] = ...
        Gait_Identification(results);
end

function RestoreSession(directory, savedPath, figureVisibility)
    diary('off');
    cd(directory);
    path(savedPath);
    set(groot, 'defaultFigureVisible', figureVisibility);
end
