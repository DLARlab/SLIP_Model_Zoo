function experiment = main_Test_FloquetAnalysis(userOptions)
%MAIN_TEST_FLOQUETANALYSIS Reproduce the pronking Floquet-v2 experiment.
%
%   EXPERIMENT = MAIN_TEST_FLOQUETANALYSIS() loads the canonical pronking
%   branch, evaluates broad points plus neighboring legacy-candidate points,
%   tracks the accepted reduced multipliers, detects persistent crossings, compares the
%   spectra with FDM_v2 output, and creates diagnostic figures.
%
%   EXPERIMENT = MAIN_TEST_FLOQUETANALYSIS(OPTIONS) accepts a scalar struct.
%   Important fields are BranchFile, LegacyFile, LegacySortedFile,
%   SampleIndices, FloquetOptions, TrackOptions, DetectorOptions, MakePlots,
%   Verbose, and SaveFile.  No interactive file chooser or random sampling is
%   used, so an identical configuration selects identical branch points.

    if nargin < 1 || isempty(userOptions)
        userOptions = struct();
    end

    paths = PronkingExperimentPaths();
    AddRequiredPaths(paths);

    defaults = DefaultExperimentOptions(paths);
    config = MergeExperimentOptions(defaults, userOptions);

    branchData = LoadResults(config.BranchFile);
    branch = branchData.results;
    indices = ResolveIndices(config.SampleIndices, size(branch,2));
    pointCount = numel(indices);
    continuationCoordinate = branch(1,indices);
    sectionStates = branch([1 2 4:13],indices);

    multipliers = complex(NaN(12,pointCount), NaN(12,pointCount));
    eigenvectors = cell(1,pointCount);
    matrices = cell(1,pointCount);
    diagnostics = cell(1,pointCount);
    accepted = false(1,pointCount);

    if config.Verbose
        fprintf('Floquet v2: %d pronking points from %s\n', ...
            pointCount, config.BranchFile);
    end

    for k = 1:pointCount
        column = indices(k);
        solution = branch(1:22,column);
        parameters = branch(23:29,column);
        if config.Verbose
            fprintf('  [%d/%d] branch column %d, dx = %.9g\n', ...
                k, pointCount, column, continuationCoordinate(k));
        end
        try
            [M, lambda, V, detail] = floquet.computeFDM( ...
                solution, parameters, config.FloquetOptions);
        catch exception
            M = [];
            lambda = [];
            V = [];
            detail = UnexpectedFailureDiagnostics(exception);
        end

        matrices{k} = M;
        diagnostics{k} = detail;
        accepted(k) = isstruct(detail) && isfield(detail,'accepted') && ...
            logical(detail.accepted) && isequal(size(M),[12 12]) && ...
            numel(lambda) == 12 && isequal(size(V),[12 12]);
        if accepted(k)
            multipliers(:,k) = lambda(:);
            eigenvectors{k} = V;
            if config.Verbose
                fprintf(['      accepted: FD error %.3e, one-sided mismatch ' ...
                    '%.3e, spectral radius %.6g\n'], ...
                    detail.derivativeConvergence.finestRelativeError, ...
                    detail.maximumFinestForwardBackwardError, max(abs(lambda)));
            end
        elseif config.Verbose
            fprintf('      rejected: %s\n', RejectionMessage(detail));
        end
    end

    trackOptions = config.TrackOptions;
    trackOptions.Reliability = accepted;
    [tracks, trackingDiagnostics] = ...
        floquet.internal.tracking.trackMultipliers( ...
        multipliers, eigenvectors, trackOptions);

    detectorOptions = config.DetectorOptions;
    detectorOptions.Reliability = accepted;
    detectorOptions.EventTopologyConsistent = accepted;
    % Only consecutive stored continuation columns count as neighboring
    % points for persistence. Broad plotting samples must not create a
    % fictitious persistent bracket across an uncomputed branch interval.
    detectorOptions.IntervalReliability = diff(indices) == 1;
    detectorOptions.BranchStates = sectionStates;
    detectorOptions.ParameterValues = branch(23:29,indices);
    [candidates, detectorReport] = floquet.detectBifurcations( ...
        tracks, continuationCoordinate, detectorOptions);

    legacy = CompareLegacySpectra(config, indices, multipliers, accepted);
    convergence = CollectConvergenceDiagnostics(diagnostics);

    experiment = struct();
    experiment.version = 'Floquet_Analysis_v2';
    experiment.generatedAt = char(datetime('now', ...
        'Format','yyyyMMdd''T''HHmmss'));
    experiment.repositoryRoot = paths.RepositoryRoot;
    experiment.analysisRoot = paths.FloquetRoot;
    experiment.experimentRoot = paths.ExperimentRoot;
    experiment.config = config;
    experiment.branchFile = config.BranchFile;
    experiment.sampleIndices = indices;
    experiment.continuationCoordinateName = 'initial horizontal speed dx';
    experiment.continuationCoordinate = continuationCoordinate;
    experiment.sectionStates = sectionStates;
    experiment.accepted = accepted;
    experiment.matrices = matrices;
    experiment.multipliers = multipliers;
    experiment.eigenvectors = eigenvectors;
    experiment.diagnostics = diagnostics;
    experiment.convergence = convergence;
    experiment.tracks = tracks;
    experiment.trackingDiagnostics = trackingDiagnostics;
    experiment.candidates = candidates;
    experiment.detectorReport = detectorReport;
    experiment.legacy = legacy;
    experiment.figures = [];

    if config.MakePlots
        experiment.figures = CreateExperimentFigures(experiment);
    end

    if config.Verbose
        PrintCandidateSummary(candidates, accepted, pointCount, legacy);
    end

    if ~isempty(config.SaveFile)
        savePath = char(config.SaveFile);
        savedExperiment = experiment;
        savedExperiment.figures = [];
        save(savePath, 'savedExperiment', '-v7');
        if config.Verbose
            fprintf('Saved reproducible experiment data to %s\n', savePath);
        end
    end
end

function config = DefaultExperimentOptions(paths)
    config = struct();
    config.BranchFile = paths.PronkingBranchFile;
    legacyRoot = fullfile(paths.SlipRoot, '3_Numerical_Continuation', ...
        '2_FloquetAnalysis', '1e-6');
    config.LegacyFile = fullfile(legacyRoot, ...
        'BD1_20_2_PK_1e-06.mat');
    config.LegacySortedFile = fullfile(legacyRoot, ...
        'BD1_20_2_PK_1e-06_sorted.mat');
    % Neighboring columns are essential: persistence is evaluated on both
    % sides of a crossing, not inferred from an isolated near-unit value.
    config.SampleIndices = [1 2 3 38 39 40 41 42 90 179 ...
        194 195 196 197 198 268 358];
    config.FloquetOptions = struct( ...
        'PerturbationMagnitude', 1e-6, ...
        'PerturbationFactors', [4 2 1], ...
        'TopologyMode', 'clustered', ...
        'RejectOnDerivativeNonconvergence', true, ...
        'RejectOnForwardBackwardMismatch', true, ...
        'ErrorOnFailure', false);
    config.TrackOptions = struct( ...
        'MultiplierWeight', 1, ...
        'EigenvectorWeight', 0.25, ...
        'ComputeAssignmentGap', true);
    config.DetectorOptions = struct( ...
        'PersistencePoints', 1, ...
        'RequireBranchTangentForPlusOne', true, ...
        'RejectTrivialBranchTangent', true, ...
        'RejectAmbiguousBranchTangent', true);
    config.MakePlots = true;
    config.Verbose = true;
    config.SaveFile = '';
end

function config = MergeExperimentOptions(defaults, supplied)
    if ~isstruct(supplied) || ~isscalar(supplied)
        error('main_Test_FloquetAnalysis:InvalidOptions', ...
            'Options must be a scalar structure.');
    end
    config = defaults;
    names = fieldnames(supplied);
    allowed = fieldnames(defaults);
    for i = 1:numel(names)
        hit = find(strcmpi(names{i},allowed),1);
        if isempty(hit)
            error('main_Test_FloquetAnalysis:UnknownOption', ...
                'Unknown experiment option ''%s''.', names{i});
        end
        config.(allowed{hit}) = supplied.(names{i});
    end
    logicalFields = {'MakePlots','Verbose'};
    for i = 1:numel(logicalFields)
        value = config.(logicalFields{i});
        if ~(isscalar(value) && (islogical(value) || ...
                (isnumeric(value) && any(value == [0 1]))))
            error('main_Test_FloquetAnalysis:InvalidLogical', ...
                '%s must be a scalar logical.', logicalFields{i});
        end
        config.(logicalFields{i}) = logical(value);
    end
end

function AddRequiredPaths(paths)
    addpath(paths.ExperimentRoot);
    addpath(paths.FloquetRoot);
    floquet.internal.ensureRuntimePaths(false);
end

function data = LoadResults(filename)
    if ~(ischar(filename) || (isstring(filename) && isscalar(filename)))
        error('main_Test_FloquetAnalysis:InvalidBranchFile', ...
            'BranchFile must be a character vector or scalar string.');
    end
    filename = char(filename);
    if ~isfile(filename)
        error('main_Test_FloquetAnalysis:MissingBranchFile', ...
            'Branch data file does not exist: %s', filename);
    end
    data = load(filename,'results');
    if ~isfield(data,'results') || ~isnumeric(data.results) || ...
            size(data.results,1) ~= 29 || isempty(data.results) || ...
            any(~isfinite(data.results(:)))
        error('main_Test_FloquetAnalysis:InvalidBranchData', ...
            'Branch file must contain one finite numeric 29-by-N variable named results.');
    end
end

function indices = ResolveIndices(requested, branchLength)
    if isempty(requested)
        requested = unique(round(linspace(1,branchLength,7)));
    end
    indices = requested(:).';
    if any(~isfinite(indices)) || any(indices ~= floor(indices)) || ...
            any(indices < 1) || any(indices > branchLength)
        error('main_Test_FloquetAnalysis:InvalidSampleIndices', ...
            'SampleIndices must be integer branch columns between 1 and %d.', ...
            branchLength);
    end
    indices = unique(indices,'stable');
    if numel(indices) < 2
        error('main_Test_FloquetAnalysis:TooFewPoints', ...
            'At least two distinct branch points are required.');
    end
end

function detail = UnexpectedFailureDiagnostics(exception)
    detail = struct();
    detail.accepted = false;
    detail.valid = false;
    detail.status = 'unexpected-exception';
    detail.rejectionReasons = {sprintf('%s: %s', ...
        exception.identifier, exception.message)};
    detail.exception = exception;
end

function message = RejectionMessage(detail)
    if isstruct(detail) && isfield(detail,'rejectionReasons') && ...
            ~isempty(detail.rejectionReasons)
        message = strjoin(detail.rejectionReasons,' | ');
    else
        message = 'no accepted reduced Floquet matrix';
    end
end

function legacy = CompareLegacySpectra(config, indices, newLambda, accepted)
    legacy = struct();
    legacy.available = false;
    legacy.file = config.LegacyFile;
    legacy.sortedFile = config.LegacySortedFile;
    legacy.oldCandidateIndices = [];
    legacy.pointComparison = repmat(EmptyLegacyPoint(),1,numel(indices));

    if isfile(config.LegacySortedFile)
        sorted = load(config.LegacySortedFile,'crossingIndices');
        if isfield(sorted,'crossingIndices')
            legacy.oldCandidateIndices = sorted.crossingIndices(:).';
        end
    end
    if ~isfile(config.LegacyFile)
        return;
    end
    old = load(config.LegacyFile,'EigenValues','results');
    if ~isfield(old,'EigenValues') || size(old.EigenValues,1) ~= 13
        return;
    end
    legacy.available = true;
    legacy.oldMultipliers = old.EigenValues;

    for k = 1:numel(indices)
        item = EmptyLegacyPoint();
        item.branchIndex = indices(k);
        item.newAccepted = accepted(k);
        if indices(k) <= size(old.EigenValues,2)
            item.oldAvailable = true;
            item.oldMultipliers = old.EigenValues(:,indices(k));
        end
        if item.oldAvailable && item.newAccepted
            item.newMultipliers = newLambda(:,k);
            distances = abs(item.newMultipliers - item.oldMultipliers.');
            item.newToOldNearestDistance = min(distances,[],2);
            item.oldToNewNearestDistance = min(distances,[],1).';
            item.symmetricSetDistance = max([ ...
                item.newToOldNearestDistance; item.oldToNewNearestDistance]);
            [item.unmatchedOldDistance,item.unmatchedOldIndex] = ...
                max(item.oldToNewNearestDistance);
            item.unmatchedOldMultiplier = ...
                item.oldMultipliers(item.unmatchedOldIndex);
        end
        legacy.pointComparison(k) = item;
    end

    comparable = [legacy.pointComparison.oldAvailable] & ...
        [legacy.pointComparison.newAccepted];
    if any(comparable)
        legacy.maximumSymmetricSetDistance = max( ...
            [legacy.pointComparison(comparable).symmetricSetDistance]);
    else
        legacy.maximumSymmetricSetDistance = NaN;
    end
end

function item = EmptyLegacyPoint()
    item = struct('branchIndex',NaN,'newAccepted',false, ...
        'oldAvailable',false,'newMultipliers',[],'oldMultipliers',[], ...
        'newToOldNearestDistance',[],'oldToNewNearestDistance',[], ...
        'symmetricSetDistance',NaN,'unmatchedOldIndex',NaN, ...
        'unmatchedOldDistance',NaN,'unmatchedOldMultiplier',NaN);
end

function convergence = CollectConvergenceDiagnostics(diagnostics)
    count = numel(diagnostics);
    convergence = struct();
    convergence.derivativeRelativeError = NaN(1,count);
    convergence.forwardBackwardRelativeError = NaN(1,count);
    convergence.periodicResidual = NaN(1,count);
    convergence.timingResidual = NaN(1,count);
    for k = 1:count
        detail = diagnostics{k};
        if ~isstruct(detail)
            continue;
        end
        if isfield(detail,'derivativeConvergence')
            convergence.derivativeRelativeError(k) = ...
                detail.derivativeConvergence.finestRelativeError;
        end
        if isfield(detail,'maximumFinestForwardBackwardError')
            convergence.forwardBackwardRelativeError(k) = ...
                detail.maximumFinestForwardBackwardError;
        end
        if isfield(detail,'baseValidation') && ...
                isfield(detail.baseValidation,'periodicResidualNormInf')
            convergence.periodicResidual(k) = ...
                detail.baseValidation.periodicResidualNormInf;
        end
        if isfield(detail,'baseValidation') && ...
                isfield(detail.baseValidation,'mapInfo') && ...
                isfield(detail.baseValidation.mapInfo,'timingResidualNormInf')
            convergence.timingResidual(k) = ...
                detail.baseValidation.mapInfo.timingResidualNormInf;
        end
    end
end

function figures = CreateExperimentFigures(experiment)
    coordinate = experiment.continuationCoordinate;
    accepted = experiment.accepted;
    lambda = experiment.tracks.Multipliers;

    figureOne = figure('Name','Floquet v2 multipliers','Color','w');
    axesOne = axes(figureOne); hold(axesOne,'on'); axis(axesOne,'equal');
    theta = linspace(0,2*pi,600);
    plot(axesOne,cos(theta),sin(theta),'k--','LineWidth',1, ...
        'DisplayName','unit circle');
    if any(accepted)
        values = experiment.multipliers(:,accepted);
        colors = repmat(coordinate(accepted),12,1);
        scatter(axesOne,real(values(:)),imag(values(:)),36,colors(:), ...
            'filled','MarkerFaceAlpha',0.75,'DisplayName','Floquet v2');
        colorbar(axesOne);
    end
    plot(axesOne,1,0,'kp','MarkerFaceColor',[0.2 0.7 0.2], ...
        'MarkerSize',11,'DisplayName','+1');
    plot(axesOne,-1,0,'kp','MarkerFaceColor',[0.8 0.3 0.2], ...
        'MarkerSize',11,'DisplayName','-1');
    xlabel(axesOne,'Re(\lambda)'); ylabel(axesOne,'Im(\lambda)');
    title(axesOne,'Reduced apex-section Floquet multipliers'); grid(axesOne,'on');
    legend(axesOne,'Location','best');

    figureTwo = figure('Name','Floquet crossing distances','Color','w');
    layout = tiledlayout(figureTwo,3,1,'TileSpacing','compact');
    distanceValues = {abs(lambda-1), abs(lambda+1), abs(abs(lambda)-1)};
    labels = {'|\lambda-1|','|\lambda+1|','||\lambda|-1|'};
    titles = {'Distance from +1','Distance from -1','Distance from unit circle'};
    for panel = 1:3
        ax = nexttile(layout,panel); hold(ax,'on');
        semilogy(ax,coordinate,max(distanceValues{panel},eps).','LineWidth',1);
        for k = find(~accepted)
            xline(ax,coordinate(k),':','Color',[0.75 0.25 0.25]);
        end
        ylabel(ax,labels{panel}); title(ax,titles{panel}); grid(ax,'on');
    end
    xlabel(nexttile(layout,3),'initial horizontal speed dx');

    figureThree = figure('Name','Floquet v2 numerical convergence','Color','w');
    axThree = axes(figureThree); hold(axThree,'on');
    semilogy(axThree,coordinate, ...
        experiment.convergence.derivativeRelativeError,'o-', ...
        'DisplayName','multi-h derivative change');
    semilogy(axThree,coordinate, ...
        experiment.convergence.forwardBackwardRelativeError,'s-', ...
        'DisplayName','forward/backward mismatch');
    semilogy(axThree,coordinate, ...
        experiment.convergence.periodicResidual,'^-', ...
        'DisplayName','periodic residual');
    semilogy(axThree,coordinate, ...
        experiment.convergence.timingResidual,'d-', ...
        'DisplayName','timing residual');
    xlabel(axThree,'initial horizontal speed dx'); ylabel(axThree,'error');
    title(axThree,'Validation and finite-difference convergence');
    grid(axThree,'on'); legend(axThree,'Location','best');

    figureFour = figure('Name','Floquet v2 versus legacy FDM','Color','w');
    axFour = axes(figureFour); hold(axFour,'on'); axis(axFour,'equal');
    plot(axFour,cos(theta),sin(theta),'k--','LineWidth',1, ...
        'DisplayName','unit circle');
    legacyPlotted = false;
    for k = 1:numel(experiment.legacy.pointComparison)
        item = experiment.legacy.pointComparison(k);
        if item.oldAvailable
            scatter(axFour,real(item.oldMultipliers),imag(item.oldMultipliers), ...
                25,[0.65 0.65 0.65],'x','DisplayName', ...
                ConditionalLabel(~legacyPlotted,'legacy FDM (13-D)',''));
            legacyPlotted = true;
        end
    end
    if any(accepted)
        values = experiment.multipliers(:,accepted);
        scatter(axFour,real(values(:)),imag(values(:)),38,[0.1 0.4 0.85], ...
            'filled','DisplayName','validated reduced map (12-D)');
    end
    xlabel(axFour,'Re(\lambda)'); ylabel(axFour,'Im(\lambda)');
    title(axFour,'Unordered spectral comparison with FDM\_v2');
    grid(axFour,'on'); legend(axFour,'Location','best');

    figures = [figureOne figureTwo figureThree figureFour];
end

function value = ConditionalLabel(condition, trueValue, falseValue)
    if condition
        value = trueValue;
    else
        value = falseValue;
    end
end

function PrintCandidateSummary(candidates, accepted, pointCount, legacy)
    fprintf('\nAccepted Floquet matrices: %d/%d\n',nnz(accepted),pointCount);
    fprintf('Persistent validated candidates: %d\n',numel(candidates));
    for i = 1:numel(candidates)
        candidate = candidates(i);
        fprintf(['  %s at dx=%.9g, lambda=%.9g%+.9gi, ' ...
            'confidence=%.3f'], candidate.Type, ...
            candidate.ContinuationParameter, real(candidate.Multiplier), ...
            imag(candidate.Multiplier), candidate.ConfidenceScore);
        if strcmp(candidate.Type,'+1')
            fprintf(', null=%s, multiplicity=%d', ...
                candidate.NullDirectionClassification, ...
                candidate.NullMultiplicity);
        end
        fprintf('\n');
    end
    if legacy.available
        fprintf('Legacy saved threshold candidates: [%s]\n', ...
            strtrim(sprintf('%d ',legacy.oldCandidateIndices)));
        fprintf(['Legacy labels are comparison metadata only; unmatched apex-normal ' ...
            'and symmetry-constrained modes are not Floquet-v2 states.\n']);
    else
        fprintf('Legacy result file was unavailable; comparison was skipped.\n');
    end
end
