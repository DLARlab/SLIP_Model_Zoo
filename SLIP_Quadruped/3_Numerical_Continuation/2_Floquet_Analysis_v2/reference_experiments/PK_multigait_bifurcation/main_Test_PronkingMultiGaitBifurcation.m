function report = main_Test_PronkingMultiGaitBifurcation(userOptions)
%MAIN_TEST_PRONKINGMULTIGAITBIFURCATION Validate the multiway pronking point.
%
%   REPORT = MAIN_TEST_PRONKINGMULTIGAITBIFURCATION() performs a
%   reproducible calculation near pronking columns 195--196:
%
%     1. recompute and track the reduced Floquet maps on columns 194:198;
%     2. refine the complete four-dimensional near-+1 invariant space;
%     3. remove the pronking tangent and resolve bounding/front/hind modes;
%     4. compare those predictions with held-out BE/BG/FE/FG/HE/HG data;
%     5. optionally attempt sector-aware nonlinear branch corrections;
%     6. save MAT, CSV, Markdown, and PNG artifacts for manual review.
%
%   Daughter branches are never used to construct the Floquet matrix or
%   refine the critical orbit.  They enter only in the held-out validation
%   stage.  The output flags distinguish a validated critical subspace from
%   a complete blind nonlinear enumeration of six daughter rays.

    if nargin < 1 || isempty(userOptions)
        userOptions = struct();
    end
    paths = PronkingExperimentPaths();
    AddRequiredPaths(paths);
    options = ParseOptions(userOptions, paths);
    EnsureDirectory(options.OutputDirectory);
    logCleanup = StartDiary(options.LogFile,options.OverwriteLog, ...
        'Pronking multi-gait clean-root reference experiment',paths); %#ok<NASGU>

    report = InitialReport(options, paths.ExperimentRoot, ...
        paths.RepositoryRoot);
    outputMat = fullfile(options.OutputDirectory, ...
        'pronking_multigait_validation_results.mat');
    report.artifacts.mat = outputMat;

    try
        experimentOptions = struct( ...
            'BranchFile',options.BranchFile, ...
            'SampleIndices',options.SampleIndices, ...
            'FloquetOptions',options.FloquetOptions, ...
            'TrackOptions',options.TrackOptions, ...
            'DetectorOptions',options.DetectorOptions, ...
            'MakePlots',false, ...
            'Verbose',options.Verbose, ...
            'SaveFile','');
        experiment = main_Test_FloquetAnalysis(experimentOptions);
        report.floquetExperiment = RemoveGraphics(experiment);
        Checkpoint(outputMat, report);

        plusCandidates = experiment.candidates( ...
            strcmp({experiment.candidates.Type},'+1'));
        if numel(plusCandidates) < 3
            error('main_Test_PronkingMultiGaitBifurcation:MissingPlusOneCluster', ...
                ['Expected at least three additional +1 candidates near the ' ...
                 'multiway pronking point; found %d.'], numel(plusCandidates));
        end
        [targetSubspace,trivialTangent] = ...
            BuildFullNearPlusOneTarget(experiment, plusCandidates);
        if size(targetSubspace,2) ~= 4
            error('main_Test_PronkingMultiGaitBifurcation:TargetRank', ...
                ['Tangent plus candidate modes must span a four-dimensional ' ...
                 'real invariant space; obtained rank %d.'], ...
                size(targetSubspace,2));
        end

        refineOptions = options.RefinementOptions;
        refineOptions.FloquetOptions = options.FloquetOptions;
        refineOptions.TargetSubspace = targetSubspace;
        refineOptions.ExcludedTargetDirection = trivialTangent;
        refineOptions.MaximumSubspaceDimension = 4;
        refineOptions.ThrowOnFailure = false;
        [criticalSolution, refinement] = floquet.refineCriticalOrbit( ...
            experiment, plusCandidates(1), refineOptions);
        report.critical = struct( ...
            'solution',criticalSolution, ...
            'refinement',refinement, ...
            'targetSubspace',targetSubspace, ...
            'excludedTrivialTangent',trivialTangent, ...
            'plusCandidates',plusCandidates);
        Checkpoint(outputMat, report);
        if ~refinement.accepted
            error('main_Test_PronkingMultiGaitBifurcation:RefinementRejected', ...
                'Critical-orbit refinement was rejected: %s', ...
                strjoin(refinement.rejectionReasons,' | '));
        end

        [directions, symmetryDiagnostics] = ...
            ResolvePronkingCriticalSubspace(refinement, ...
                options.SymmetryOptions);
        report.symmetry = struct('directions',directions, ...
            'diagnostics',symmetryDiagnostics);
        Checkpoint(outputMat, report);
        if ~symmetryDiagnostics.accepted
            error('main_Test_PronkingMultiGaitBifurcation:SymmetryResolutionRejected', ...
                'Critical-space symmetry resolution was rejected: %s', ...
                strjoin(symmetryDiagnostics.rejectionReasons,' | '));
        end

        validationOptions = options.ValidationOptions;
        validationOptions.RoadmapDirectory = options.RoadmapDirectory;
        validationOptions.FloquetOptions = options.FloquetOptions;
        daughterValidation = ValidatePronkingDaughterBranches( ...
            refinement, directions, validationOptions);
        report.daughterValidation = daughterValidation;
        Checkpoint(outputMat, report);

        if options.RunNonlinearSearch
            searchOptions = options.SearchOptions;
            searchOptions.FloquetOptions = options.FloquetOptions;
            searchOptions.Verbose = options.Verbose;
            report.nonlinearSearch = ExplorePronkingBranchSwitch( ...
                refinement, directions, searchOptions);
        else
            report.nonlinearSearch = struct( ...
                'status','not-requested', ...
                'blindSixArmDiscoveryValidated',false, ...
                'message','RunNonlinearSearch was false.');
        end

        report.conclusion = BuildConclusion(report);
        report.status = report.conclusion.status;
        report.completedAt = Timestamp();
        report.artifacts = SaveArtifacts(report, options);
        if isfield(report,'referenceStageArtifacts')
            report = rmfield(report,'referenceStageArtifacts');
        end
        save(outputMat,'report','-v7');
        % The compact validation index fingerprints this final MAT, so it is
        % deliberately materialized only after the authoritative save.
        WritePronkingStageArtifacts(report,paths);

        if options.Verbose
            PrintSummary(report);
        end
        if options.ThrowOnFailure && strcmp(report.status,'failed')
            error('main_Test_PronkingMultiGaitBifurcation:ValidationFailed', ...
                '%s', report.conclusion.summary);
        end
    catch exception
        report.status = 'failed';
        report.completedAt = Timestamp();
        report.failure = struct('identifier',exception.identifier, ...
            'message',exception.message, ...
            'report',getReport(exception,'extended','hyperlinks','off'));
        Checkpoint(outputMat, report);
        if options.ThrowOnFailure
            rethrow(exception);
        elseif options.Verbose
            fprintf('Pronking multi-gait experiment failed: %s\n', ...
                exception.message);
        end
    end
end

function options = ParseOptions(user, paths)
    if ~isstruct(user) || ~isscalar(user)
        error('main_Test_PronkingMultiGaitBifurcation:InvalidOptions', ...
            'Options must be a scalar structure.');
    end
    defaults = struct();
    defaults.BranchFile = paths.PronkingBranchFile;
    defaults.RoadmapDirectory = paths.DaughterBranchRoot;
    defaults.SampleIndices = 194:198;
    defaults.FloquetOptions = struct( ...
        'PerturbationMagnitude',5e-7, ...
        'PerturbationFactors',[8 4 2 1], ...
        'TopologyMode','clustered', ...
        'RejectOnDerivativeNonconvergence',true, ...
        'RejectOnForwardBackwardMismatch',true, ...
        'ErrorOnFailure',false);
    defaults.TrackOptions = struct( ...
        'MultiplierWeight',1,'EigenvectorWeight',0.25, ...
        'ComputeAssignmentGap',true);
    defaults.DetectorOptions = struct( ...
        'PersistencePoints',1, ...
        'RequireBranchTangentForPlusOne',true, ...
        'RejectTrivialBranchTangent',true, ...
        'RejectAmbiguousBranchTangent',true);
    defaults.RefinementOptions = struct( ...
        'CoordinateTolerance',2e-6, ...
        'MultiplierTolerance',2e-6, ...
        'CriticalMultiplierUncertaintyTolerance',2e-6, ...
        'ClusterSpreadTolerance',2e-5, ...
        'MinimumSubspaceOverlap',0.35, ...
        'MinimumExcludedTargetOverlap',0.35, ...
        'MaxIterations',25, ...
        'StoreFullFloquetDiagnostics',false);
    defaults.SymmetryOptions = struct();
    defaults.ValidationOptions = struct( ...
        'ValidatePeriodicOrbits',true, ...
        'ThrowOnFailure',false);
    defaults.SearchOptions = struct();
    defaults.RunNonlinearSearch = true;
    defaults.OutputDirectory = paths.ResultsRoot;
    defaults.LogFile = '';
    defaults.OverwriteLog = true;
    defaults.MakePlots = true;
    defaults.Verbose = true;
    defaults.ThrowOnFailure = true;

    options = defaults;
    supplied = fieldnames(user);
    allowed = fieldnames(defaults);
    for k = 1:numel(supplied)
        hit = find(strcmpi(supplied{k},allowed),1);
        if isempty(hit)
            error('main_Test_PronkingMultiGaitBifurcation:UnknownOption', ...
                'Unknown option ''%s''.', supplied{k});
        end
        options.(allowed{hit}) = user.(supplied{k});
    end

    logicalFields = {'RunNonlinearSearch','OverwriteLog','MakePlots', ...
        'Verbose','ThrowOnFailure'};
    for k = 1:numel(logicalFields)
        value = options.(logicalFields{k});
        if ~(isscalar(value) && (islogical(value) || ...
                (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
            error('main_Test_PronkingMultiGaitBifurcation:InvalidLogical', ...
                '%s must be a scalar logical.',logicalFields{k});
        end
        options.(logicalFields{k}) = logical(value);
    end
    structFields = {'FloquetOptions','TrackOptions','DetectorOptions', ...
        'RefinementOptions','SymmetryOptions','ValidationOptions','SearchOptions'};
    for k = 1:numel(structFields)
        if ~isstruct(options.(structFields{k})) || ...
                ~isscalar(options.(structFields{k}))
            error('main_Test_PronkingMultiGaitBifurcation:InvalidNestedOptions', ...
                '%s must be a scalar structure.',structFields{k});
        end
    end
    options.BranchFile = char(string(options.BranchFile));
    options.RoadmapDirectory = char(string(options.RoadmapDirectory));
    options.OutputDirectory = char(string(options.OutputDirectory));
    options.LogFile = char(string(options.LogFile));
end

function report = InitialReport(options, analysisRoot, repositoryRoot)
    report = struct();
    report.version = 'pronking-multigait-bifurcation-v2';
    report.status = 'running';
    report.startedAt = Timestamp();
    report.completedAt = '';
    report.analysisRoot = analysisRoot;
    report.repositoryRoot = repositoryRoot;
    report.matlabVersion = version;
    report.options = options;
    report.artifacts = struct();
end

function [target,tangent] = BuildFullNearPlusOneTarget(experiment, candidates)
    coordinates = experiment.continuationCoordinate;
    candidateCoordinate = median([candidates.ContinuationParameter]);
    [~,right] = min(abs(coordinates - candidateCoordinate));
    if coordinates(right) <= candidateCoordinate
        left = max(1,right);
        right = min(numel(coordinates),right+1);
    else
        left = max(1,right-1);
    end
    tangent = experiment.sectionStates(:,right) - ...
        experiment.sectionStates(:,left);
    tangent = tangent / norm(tangent);
    vectors = [candidates.Eigenvector];
    realSpan = [tangent, real(vectors), imag(vectors)];
    [U,S,~] = svd(realSpan,'econ');
    values = diag(S);
    tolerance = max(size(realSpan)) * eps(max(values));
    numericalRank = sum(values > tolerance);
    target = U(:,1:min(4,numericalRank));
end

function conclusion = BuildConclusion(report)
    validation = report.daughterValidation;
    search = report.nonlinearSearch;
    conclusion = struct();
    conclusion.criticalCoordinate = ...
        report.critical.refinement.coordinate;
    conclusion.nearPlusOneNullity = ...
        report.symmetry.diagnostics.numericalNullity;
    conclusion.additionalCriticalDimension = ...
        report.symmetry.diagnostics.additionalDimension;
    conclusion.linearPredictionValidated = ...
        validation.linearPredictionValidated;
    conclusion.threeGaitClassesIdentified = ...
        validation.threeGaitClassesIdentified;
    conclusion.savedDaughterAgreementValidated = ...
        validation.savedDaughterAgreementValidated;
    conclusion.blindSixArmDiscoveryValidated = LogicalField( ...
        search,'blindSixArmDiscoveryValidated',false);

    if conclusion.linearPredictionValidated && ...
            conclusion.threeGaitClassesIdentified
        if conclusion.blindSixArmDiscoveryValidated
            conclusion.status = 'verified';
            conclusion.summary = ...
                ['Floquet-v2 identified the three gait classes and the ' ...
                 'nonlinear search recovered six persistent oriented rays.'];
        else
            conclusion.status = 'linear-validated';
            conclusion.summary = ...
                ['Floquet-v2 identified the three-dimensional critical ' ...
                 'space and all three held-out gait classes; complete blind ' ...
                 'six-ray nonlinear enumeration remains unverified.'];
        end
    else
        conclusion.status = 'failed';
        conclusion.summary = ...
            ['The critical-space or held-out gait-direction validation did ' ...
             'not meet its numerical acceptance criteria.'];
    end
end

function artifacts = SaveArtifacts(report, options)
    artifacts = report.artifacts;
    output = options.OutputDirectory;
    artifacts.mat = fullfile(output,'pronking_multigait_validation_results.mat');
    artifacts.summaryCsv = fullfile(output, ...
        'pronking_multigait_validation_summary.csv');
    artifacts.criticalCsv = fullfile(output, ...
        'pronking_critical_orbit.csv');
    artifacts.searchAttemptsCsv = fullfile(output, ...
        'pronking_branch_search_attempts.csv');
    artifacts.searchClustersCsv = fullfile(output, ...
        'pronking_branch_search_clusters.csv');
    artifacts.correctedOrbitsCsv = fullfile(output, ...
        'pronking_corrected_orbits.csv');
    artifacts.markdown = fullfile(output, ...
        'pronking_multigait_validation_report.md');

    WriteDaughterTable(report.daughterValidation.daughters, ...
        artifacts.summaryCsv);
    WriteCriticalTable(report.critical.refinement, artifacts.criticalCsv);
    WriteSearchTables(report.nonlinearSearch,artifacts.searchAttemptsCsv, ...
        artifacts.searchClustersCsv);
    WriteCorrectedOrbitTable(report.nonlinearSearch, ...
        artifacts.correctedOrbitsCsv);
    WriteMarkdownReport(report, artifacts.markdown);

    if options.MakePlots
        plotFiles = CreatePlots(report,output);
        artifacts.plots = plotFiles;
    else
        artifacts.plots = struct();
    end
end

function WriteDaughterTable(daughters, filename)
    count = numel(daughters);
    code = strings(count,1);
    expectedClass = strings(count,1);
    predictedClass = strings(count,1);
    gait = strings(count,1);
    abbreviation = strings(count,1);
    nearIndex = zeros(count,1);
    outgoingIndex = zeros(count,1);
    nearDx = zeros(count,1);
    outgoingDx = zeros(count,1);
    scaledOrbitDistance22 = zeros(count,1);
    transverseAlignment = zeros(count,1);
    angleDegrees = zeros(count,1);
    boundingCoordinate = zeros(count,1);
    frontSpreadCoordinate = zeros(count,1);
    hindSpreadCoordinate = zeros(count,1);
    hindPairPhaseError = zeros(count,1);
    frontPairPhaseError = zeros(count,1);
    periodicOrbitAccepted = false(count,1);
    for k = 1:count
        code(k) = daughters(k).code;
        expectedClass(k) = daughters(k).expectedClass;
        predictedClass(k) = daughters(k).predictedClass;
        gait(k) = daughters(k).gait;
        abbreviation(k) = daughters(k).abbreviation;
        nearIndex(k) = daughters(k).nearIndex;
        outgoingIndex(k) = daughters(k).outgoingIndex;
        nearDx(k) = daughters(k).nearDx;
        outgoingDx(k) = daughters(k).outgoingDx;
        scaledOrbitDistance22(k) = daughters(k).scaledOrbitDistance22;
        transverseAlignment(k) = daughters(k).transverseAlignment;
        angleDegrees(k) = daughters(k).angleDegrees;
        boundingCoordinate(k) = daughters(k).criticalCoordinates(1);
        frontSpreadCoordinate(k) = daughters(k).criticalCoordinates(2);
        hindSpreadCoordinate(k) = daughters(k).criticalCoordinates(3);
        hindPairPhaseError(k) = daughters(k).hindPairPhaseError;
        frontPairPhaseError(k) = daughters(k).frontPairPhaseError;
        periodicOrbitAccepted(k) = daughters(k).periodicOrbitAccepted;
    end
    tableValue = table(code,expectedClass,predictedClass,gait,abbreviation, ...
        nearIndex,outgoingIndex,nearDx,outgoingDx,scaledOrbitDistance22, ...
        transverseAlignment,angleDegrees,boundingCoordinate, ...
        frontSpreadCoordinate,hindSpreadCoordinate,hindPairPhaseError, ...
        frontPairPhaseError,periodicOrbitAccepted);
    writetable(tableValue,filename);
end

function WriteCriticalTable(refinement, filename)
    labels = ["dx";"y";"dy";"phi";"dphi";"alphaBL";"dalphaBL"; ...
        "alphaFL";"dalphaFL";"alphaBR";"dalphaBR";"alphaFR"; ...
        "dalphaFR";"tBL_TD";"tBL_LO";"tFL_TD";"tFL_LO"; ...
        "tBR_TD";"tBR_LO";"tFR_TD";"tFR_LO";"T_apex"];
    values = refinement.solution(:);
    writetable(table(labels,values,'VariableNames',{'variable','value'}),filename);
end

function WriteSearchTables(search,attemptFilename,clusterFilename)
    if ~isstruct(search) || ~isfield(search,'attempts') || ...
            isempty(search.attempts)
        writetable(table(),attemptFilename);
        writetable(table(),clusterFilename);
        return
    end
    attempts = search.attempts;
    count = numel(attempts);
    index = reshape([attempts.index],[],1);
    radius = reshape([attempts.radius],[],1);
    seedLabel = string({attempts.seedLabel}).';
    requestedGaitClass = string({attempts.requestedGaitClass}).';
    classSelectionMethod = string({attempts.classSelectionMethod}).';
    correctorMethod = string({attempts.correctorMethod}).';
    sectorSignature = string({attempts.sectorSignature}).';
    predictorAccepted = reshape([attempts.predictorAccepted],[],1);
    correctorAccepted = reshape([attempts.correctorAccepted],[],1);
    nonParentAccepted = reshape([attempts.nonParentAccepted],[],1);
    gaitClass = string({attempts.gaitClass}).';
    abbreviation = string({attempts.abbreviation}).';
    canonicalResidualNorm = reshape([attempts.canonicalResidualNorm],[],1);
    returnResidualNorm = reshape([attempts.returnResidualNorm],[],1);
    eventTimeError = reshape([attempts.eventTimeError],[],1);
    transverseFraction = reshape([attempts.transverseFraction],[],1);
    hindPairPhaseError = reshape([attempts.hindPairPhaseError],[],1);
    frontPairPhaseError = reshape([attempts.frontPairPhaseError],[],1);
    foreHindPhaseSeparation = reshape( ...
        [attempts.foreHindPhaseSeparation],[],1);
    rejectionStage = string({attempts.rejectionStage}).';
    rejectionIdentifier = string({attempts.rejectionIdentifier}).';
    rejectionMessage = string({attempts.rejectionMessage}).';
    coefficientB = NaN(count,1);
    coefficientF = NaN(count,1);
    coefficientH = NaN(count,1);
    seedB = NaN(count,1);
    seedF = NaN(count,1);
    seedH = NaN(count,1);
    targetCriticalCoordinate = NaN(count,1);
    correctedCriticalCoordinate = NaN(count,1);
    symmetryResidualNorm = Inf(count,1);
    amplitudeResidual = Inf(count,1);
    sectionResidual = Inf(count,1);
    periodicValidationAccepted = false(count,1);
    exitflag = NaN(count,1);
    predictorDx = NaN(count,1);
    correctedDx = NaN(count,1);
    predictorPeriod = NaN(count,1);
    correctedPeriod = NaN(count,1);
    for k = 1:count
        seed = attempts(k).seedCoefficients;
        if numel(seed)==3
            seedB(k)=seed(1); seedF(k)=seed(2); seedH(k)=seed(3);
        end
        value = attempts(k).correctedCoefficients;
        if numel(value) == 3
            coefficientB(k) = value(1);
            coefficientF(k) = value(2);
            coefficientH(k) = value(3);
        end
        info = attempts(k).correctorInfo;
        targetCriticalCoordinate(k) = ScalarField( ...
            info,'targetCriticalCoordinate',NaN);
        correctedCriticalCoordinate(k) = ScalarField( ...
            info,'correctedCriticalCoordinate',NaN);
        symmetryResidualNorm(k) = ScalarField( ...
            info,'symmetryResidualNormInf',Inf);
        amplitudeResidual(k) = abs(ScalarField( ...
            info,'amplitudeResidual',Inf));
        sectionResidual(k) = ScalarField(info,'sectionResidual',Inf);
        exitflag(k) = ScalarField(info,'exitflag',NaN);
        validation = StructField(info,'periodicValidation',struct());
        periodicValidationAccepted(k) = LogicalField( ...
            validation,'accepted',false);
        if numel(attempts(k).zPredictor)==22
            predictorDx(k)=attempts(k).zPredictor(1);
            predictorPeriod(k)=attempts(k).zPredictor(22);
        end
        if numel(attempts(k).zCorrected)==22
            correctedDx(k)=attempts(k).zCorrected(1);
            correctedPeriod(k)=attempts(k).zCorrected(22);
        end
    end
    attemptTable = table(index,radius,seedLabel,requestedGaitClass, ...
        classSelectionMethod,correctorMethod,sectorSignature, ...
        seedB,seedF,seedH,predictorAccepted,correctorAccepted, ...
        nonParentAccepted,gaitClass,abbreviation, ...
        canonicalResidualNorm,returnResidualNorm,eventTimeError, ...
        transverseFraction,coefficientB,coefficientF,coefficientH, ...
        targetCriticalCoordinate,correctedCriticalCoordinate, ...
        symmetryResidualNorm,amplitudeResidual,sectionResidual, ...
        periodicValidationAccepted,exitflag,predictorDx,correctedDx, ...
        predictorPeriod,correctedPeriod, ...
        hindPairPhaseError,frontPairPhaseError,foreHindPhaseSeparation, ...
        rejectionStage,rejectionIdentifier,rejectionMessage);
    writetable(attemptTable,attemptFilename);

    if isfield(search,'clusters')
        clusters = search.clusters;
    else
        clusters = [];
    end
    if isempty(clusters)
        writetable(table(),clusterFilename);
        return
    end
    clusterCount = numel(clusters);
    id = reshape([clusters.id],[],1);
    gaitClass = string({clusters.gaitClass}).';
    isPersistent = reshape([clusters.persistent],[],1);
    attemptCount = zeros(clusterCount,1);
    radiusCount = zeros(clusterCount,1);
    directionB = zeros(clusterCount,1);
    directionF = zeros(clusterCount,1);
    directionH = zeros(clusterCount,1);
    maximumCanonicalResidual = reshape( ...
        [clusters.maximumCanonicalResidual],[],1);
    maximumReturnResidual = reshape([clusters.maximumReturnResidual],[],1);
    for k = 1:clusterCount
        attemptCount(k) = numel(clusters(k).attemptIndices);
        radiusCount(k) = numel(clusters(k).radii);
        directionB(k) = clusters(k).meanDirection(1);
        directionF(k) = clusters(k).meanDirection(2);
        directionH(k) = clusters(k).meanDirection(3);
    end
    clusterTable = table(id,gaitClass,isPersistent,attemptCount,radiusCount, ...
        directionB,directionF,directionH,maximumCanonicalResidual, ...
        maximumReturnResidual);
    writetable(clusterTable,clusterFilename);
end

function WriteCorrectedOrbitTable(search,filename)
    if ~isstruct(search) || ~isfield(search,'attempts') || ...
            isempty(search.attempts)
        writetable(table(),filename);
        return
    end
    attempts = search.attempts;
    selected = find([attempts.nonParentAccepted]);
    if isempty(selected)
        writetable(table(),filename);
        return
    end
    valid = arrayfun(@(k) numel(attempts(k).zCorrected)==22,selected);
    selected = selected(valid);
    if isempty(selected)
        writetable(table(),filename);
        return
    end
    orbit = [attempts(selected).zCorrected].';
    variableNames = {'dx','y','dy','phi','dphi','alphaBL','dalphaBL', ...
        'alphaFL','dalphaFL','alphaBR','dalphaBR','alphaFR','dalphaFR', ...
        'tBL_TD','tBL_LO','tFL_TD','tFL_LO','tBR_TD','tBR_LO', ...
        'tFR_TD','tFR_LO','T_apex'};
    orbitTable = array2table(orbit,'VariableNames',variableNames);
    attemptIndex = reshape([attempts(selected).index],[],1);
    radius = reshape([attempts(selected).radius],[],1);
    requestedGaitClass = string({attempts(selected).requestedGaitClass}).';
    gaitClass = string({attempts(selected).gaitClass}).';
    abbreviation = string({attempts(selected).abbreviation}).';
    metadata = table(attemptIndex,radius,requestedGaitClass, ...
        gaitClass,abbreviation);
    writetable([metadata orbitTable],filename);
end

function value = ScalarField(structure,name,defaultValue)
    value = defaultValue;
    if isstruct(structure) && isscalar(structure) && ...
            isfield(structure,name)
        candidate = structure.(name);
        if isnumeric(candidate) && isscalar(candidate) && isfinite(candidate)
            value = candidate;
        end
    end
end

function value = StructField(structure,name,defaultValue)
    if isstruct(structure) && isscalar(structure) && ...
            isfield(structure,name) && isstruct(structure.(name))
        value = structure.(name);
    else
        value = defaultValue;
    end
end

function WriteMarkdownReport(report, filename)
    handle = fopen(filename,'w');
    if handle < 0
        error('main_Test_PronkingMultiGaitBifurcation:ReportFile', ...
            'Unable to write report file %s.',filename);
    end
    cleanup = onCleanup(@() fclose(handle));
    refinement = report.critical.refinement;
    symmetry = report.symmetry.diagnostics;
    validation = report.daughterValidation;
    fprintf(handle,'# Pronking multi-gait Floquet-v2 validation\n\n');
    fprintf(handle,'Generated: `%s`  \n',report.completedAt);
    fprintf(handle,'MATLAB: `%s`\n\n',report.matlabVersion);
    fprintf(handle,'## Outcome\n\n%s\n\n',report.conclusion.summary);
    fprintf(handle,'- Status: `%s`\n',report.conclusion.status);
    fprintf(handle,'- Refined critical dx: `%.15g`\n',refinement.coordinate);
    fprintf(handle,'- Final dx bracket: `[%.15g, %.15g]`\n', ...
        refinement.finalBracket(1),refinement.finalBracket(2));
    fprintf(handle,'- Critical multiplier uncertainty: `%.3e`\n', ...
        refinement.criticalMultiplierUncertainty);
    fprintf(handle,'- Canonical residual infinity norm: `%.3e`\n', ...
        refinement.canonicalResidualNormInf);
    fprintf(handle,'- Numerical nullity of M-I: `%d`\n', ...
        symmetry.numericalNullity);
    fprintf(handle,'- Additional critical dimension: `%d`\n\n', ...
        symmetry.additionalDimension);
    fprintf(handle,'## Symmetry sectors\n\n');
    fprintf(handle,'Full near-+1 ranks `[++, +-, -+, --]`: `%s`  \n', ...
        mat2str(symmetry.fullSectorRanks));
    fprintf(handle,'Additional ranks `[bounding, front, hind, mixed]`: `%s`  \n', ...
        mat2str(symmetry.additionalSectorRanks));
    fprintf(handle,'Commutator Frobenius norms `[hind, front]`: `%s`  \n', ...
        mat2str(symmetry.commutatorFrobeniusNorms,6));
    fprintf(handle,'Commutator tolerance: `%.3e`\n\n', ...
        symmetry.commutatorTolerance);
    fprintf(handle,'## Held-out daughter comparison\n\n');
    fprintf(handle,'| Code | Expected | Predicted | dx near | Alignment | Angle (deg) | Hind pair | Front pair |\n');
    fprintf(handle,'|---|---|---|---:|---:|---:|---:|---:|\n');
    for k = 1:numel(validation.daughters)
        d = validation.daughters(k);
        fprintf(handle,'| %s | %s | %s | %.9g | %.8f | %.4f | %.3e | %.3e |\n', ...
            d.code,d.expectedClass,d.predictedClass,d.nearDx, ...
            d.transverseAlignment,d.angleDegrees, ...
            d.hindPairPhaseError,d.frontPairPhaseError);
    end
    fprintf(handle,'\nPrincipal cosines: `%s`  \n', ...
        mat2str(validation.principalCosines.',8));
    fprintf(handle,'Principal angles (degrees): `%s`\n\n', ...
        mat2str(validation.principalAnglesDegrees.',6));
    fprintf(handle,'## Nonlinear six-arm correction\n\n');
    search = report.nonlinearSearch;
    if isstruct(search) && isfield(search,'attempts') && ...
            ~isempty(search.attempts)
        fprintf(handle,'- Search status: `%s`\n',search.status);
        fprintf(handle,'- Corrector: `%s`\n',search.correctorMode);
        fprintf(handle,'- Seed provenance: `%s`\n', ...
            search.options.SeedProvenance);
        fprintf(handle,'- Attempts: `%d`\n',search.attemptCount);
        fprintf(handle,'- Accepted non-parent corrections: `%d`\n', ...
            search.nonParentAcceptedCount);
        fprintf(handle,'- Persistent oriented clusters: `%d`\n', ...
            search.persistentClusterCount);
        fprintf(handle,'- Persistent class counts `[B F H]`: `%s`\n', ...
            mat2str(search.persistentClassCounts));
        fprintf(handle,'- Blind six-arm verification: `%d`\n\n', ...
            search.blindSixArmDiscoveryValidated);
        fprintf(handle,'| Cluster | Class | Persistent | Radii | Direction [b f h] | max canonical | max return |\n');
        fprintf(handle,'|---:|---|---:|---|---|---:|---:|\n');
        for k = 1:numel(search.clusters)
            c = search.clusters(k);
            fprintf(handle,'| %d | %s | %d | `%s` | `%s` | %.3e | %.3e |\n', ...
                c.id,c.gaitClass,c.persistent,mat2str(c.radii), ...
                mat2str(c.meanDirection.',6), ...
                c.maximumCanonicalResidual,c.maximumReturnResidual);
        end
        fprintf(handle,'\n');
    else
        fprintf(handle,'Nonlinear correction was not requested or produced no attempts.\n\n');
    end
    fprintf(handle,'## Interpretation and limitation\n\n');
    fprintf(handle,['The reduced FDM predicts a three-dimensional ' ...
        'additional +1 critical space. The saved daughter branches were ' ...
        'not used to construct that space or the nonlinear seeds; their ' ...
        'outgoing secants are a held-out validation set. The nonlinear ' ...
        'claim additionally requires independently closed periodic orbits, ' ...
        'production-solver event-time agreement, the expected gait ' ...
        'isotropy, and persistence over two radii. The MAT file records ' ...
        'every accepted and rejected correction attempt.\n']);
end

function files = CreatePlots(report, output)
    files = struct();
    daughters = report.daughterValidation.daughters;
    coordinates = [daughters.criticalCoordinates];
    codes = {daughters.code};

    figureOne = figure('Visible','off','Color','w');
    hold on; grid on; axis equal;
    colors = lines(numel(codes));
    for k = 1:numel(codes)
        quiver3(0,0,0,coordinates(1,k),coordinates(2,k), ...
            coordinates(3,k),0,'LineWidth',1.8,'Color',colors(k,:));
        text(coordinates(1,k),coordinates(2,k),coordinates(3,k), ...
            ['  ',codes{k}],'FontWeight','bold');
    end
    xlabel('bounding coordinate b');
    ylabel('front-spread coordinate f');
    zlabel('hind-spread coordinate h');
    title('Held-out daughter secants in the Floquet critical space');
    view(38,24);
    files.directionPng = fullfile(output,'pronking_critical_directions.png');
    exportgraphics(figureOne,files.directionPng,'Resolution',220);
    close(figureOne);

    figureTwo = figure('Visible','off','Color','w');
    tiledlayout(2,1,'TileSpacing','compact');
    nexttile;
    bar([daughters.transverseAlignment]);
    ylim([0.95 1.001]); grid on;
    set(gca,'XTick',1:numel(codes),'XTickLabel',codes);
    ylabel('critical-space alignment');
    yline(report.daughterValidation.options.MinimumSubspaceAlignment,'--');
    nexttile;
    errors = [[daughters.hindPairPhaseError].', ...
        [daughters.frontPairPhaseError].'];
    semilogy(max(errors,eps),'o-','LineWidth',1.3);
    grid on;
    set(gca,'XTick',1:numel(codes),'XTickLabel',codes);
    ylabel('wrapped pair-phase error');
    legend({'hind pair','front pair'},'Location','best');
    files.validationPng = fullfile(output,'pronking_daughter_validation.png');
    exportgraphics(figureTwo,files.validationPng,'Resolution',220);
    close(figureTwo);

    figureThree = figure('Visible','off','Color','w');
    multipliers = report.critical.refinement.multipliers;
    plot(real(multipliers),imag(multipliers),'ko','MarkerFaceColor',[0.2 0.5 0.8]);
    hold on; grid on; axis equal;
    theta = linspace(0,2*pi,500);
    plot(cos(theta),sin(theta),'k--');
    plot(1,0,'r+','MarkerSize',12,'LineWidth',2);
    xlabel('Re(\lambda)'); ylabel('Im(\lambda)');
    title(sprintf('Reduced Floquet spectrum at dx = %.10g', ...
        report.critical.refinement.coordinate));
    files.spectrumPng = fullfile(output,'pronking_critical_spectrum.png');
    exportgraphics(figureThree,files.spectrumPng,'Resolution',220);
    close(figureThree);

    search = report.nonlinearSearch;
    if isstruct(search) && isfield(search,'attempts') && ...
            any([search.attempts.nonParentAccepted])
        accepted = search.attempts([search.attempts.nonParentAccepted]);
        figureFour = figure('Visible','off','Color','w');
        hold on; grid on; axis equal;
        classes = {'B','F','H'};
        classColors = lines(3);
        handles = gobjects(1,3);
        for classIndex = 1:3
            selected = accepted(strcmp({accepted.gaitClass}, ...
                classes{classIndex}));
            points = zeros(numel(selected),3);
            for k = 1:numel(selected)
                points(k,:) = selected(k).radius * ...
                    selected(k).correctedCoefficients(:).';
                plot3([0 points(k,1)],[0 points(k,2)], ...
                    [0 points(k,3)],'-','Color', ...
                    0.65*classColors(classIndex,:)+0.35);
            end
            if ~isempty(points)
                handles(classIndex) = scatter3(points(:,1),points(:,2), ...
                    points(:,3),48,classColors(classIndex,:),'filled');
            end
        end
        xlabel('scaled b correction');
        ylabel('scaled f correction');
        zlabel('scaled h correction');
        title('Corrected daughter rays at all persistence radii');
        present = isgraphics(handles);
        legend(handles(present),classes(present),'Location','best');
        view(38,24);
        files.correctedRaysPng = fullfile(output, ...
            'pronking_corrected_branch_rays.png');
        exportgraphics(figureFour,files.correctedRaysPng,'Resolution',220);
        close(figureFour);
    end
end

function PrintSummary(report)
    refinement = report.critical.refinement;
    validation = report.daughterValidation;
    fprintf('\nPronking multi-gait validation: %s\n',report.conclusion.status);
    fprintf('  critical dx = %.15g, bracket width %.3e\n', ...
        refinement.coordinate,diff(refinement.finalBracket));
    fprintf('  nullity(M-I) = %d, additional dimension = %d\n', ...
        report.symmetry.diagnostics.numericalNullity, ...
        report.symmetry.diagnostics.additionalDimension);
    fprintf('  principal cosines = %s\n', ...
        mat2str(validation.principalCosines.',8));
    for k = 1:numel(validation.daughters)
        d = validation.daughters(k);
        fprintf('  %s: predicted=%s alignment=%.8f angle=%.4f deg periodic=%d\n', ...
            d.code,d.predictedClass,d.transverseAlignment,d.angleDegrees, ...
            d.periodicOrbitAccepted);
    end
    search = report.nonlinearSearch;
    if isfield(search,'persistentClassCounts')
        fprintf(['  nonlinear search: %s, accepted=%d, persistent=%d, ' ...
            'counts=%s, blind-six=%d\n'],search.status, ...
            search.nonParentAcceptedCount,search.persistentClusterCount, ...
            mat2str(search.persistentClassCounts), ...
            search.blindSixArmDiscoveryValidated);
    end
    fprintf('  %s\n',report.conclusion.summary);
    fprintf('  artifacts: %s\n',report.artifacts.mat);
end

function AddRequiredPaths(paths)
    addpath(paths.ExperimentRoot);
    addpath(paths.FloquetRoot);
    floquet.internal.ensureRuntimePaths(true);
end

function experiment = RemoveGraphics(experiment)
    if isfield(experiment,'figures')
        experiment.figures = [];
    end
end

function EnsureDirectory(directory)
    if ~isfolder(directory)
        [created,message] = mkdir(directory);
        if ~created
            error('main_Test_PronkingMultiGaitBifurcation:OutputDirectory', ...
                'Unable to create output directory: %s',message);
        end
    end
end

function cleanup = StartDiary(logFile,overwriteLog,label,paths)
    cleanup = [];
    if isempty(logFile)
        return
    end
    EnsureDirectory(fileparts(logFile));
    if overwriteLog && isfile(logFile)
        delete(logFile);
    end
    diary(logFile);
    cleanup = onCleanup(@()diary('off'));
    fprintf('%s\n',label);
    fprintf('Started: %s\n',char(datetime('now','TimeZone','local', ...
        'Format','yyyy-MM-dd HH:mm:ss Z')));
    fprintf('MATLAB: %s\n',version);
    fprintf('Package: %s\n',paths.ExperimentRoot);
end

function Checkpoint(filename, report)
    save(filename,'report','-v7');
end

function value = LogicalField(structure,name,defaultValue)
    if isstruct(structure) && isfield(structure,name) && ...
            ~isempty(structure.(name))
        candidate = structure.(name);
        value = isscalar(candidate) && logical(candidate);
    else
        value = defaultValue;
    end
end

function value = Timestamp()
    value = char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
end
