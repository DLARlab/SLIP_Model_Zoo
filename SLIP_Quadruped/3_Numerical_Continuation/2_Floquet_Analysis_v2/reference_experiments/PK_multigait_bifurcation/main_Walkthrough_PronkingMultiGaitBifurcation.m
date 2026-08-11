%% Pronking multi-gait bifurcation: section-by-section walkthrough
% This pedagogical script exposes each numerical and validation layer of the
% targeted PK reference experiment. Run it one section at a time in the
% MATLAB editor. It is not a generic floquet.workflow.Session.
%
% The safe default, "inspect-saved", loads the frozen authoritative result
% and independently replays its corrected periodic orbits without writing
% files. To recompute the FDMs, critical orbit, six local rays, plots,
% and numbered reference artifacts, deliberately change executionMode to
% "recompute-package" in Step 1.
%
% WARNING: the current reference-stage writer always writes package-local
% numbered artifacts and reference_experiment_config.mat. Therefore a full
% recomputation modifies this frozen package even if a different specialized
% OutputDirectory is supplied. Commit, copy, or use a disposable worktree
% before choosing "recompute-package".
%
% When using MATLAB's Run Section command for the first time, execute Steps
% 1 and 2 in order (or run the complete script once). Later sections depend
% on the paths and variables established there.

%% Step 1 - Reset MATLAB and choose how far this walkthrough should run

% 01. Remove variables from an earlier walkthrough execution.
clearvars;

% 02. Close figures left by an earlier analysis.
close all;

% 03. Clear the Command Window so stage output is easy to audit.
clc;

% 04. Keep the frozen package unchanged by default.
%     Use "recompute-package" only when package artifact replacement is
%     intentional.
executionMode = "inspect-saved";

% 05. Reevaluate every corrected 22-variable orbit with the production
%     residual and timing solver. This is read-only with the options below.
runIndependentReplay = true;

% 06. Leave report and figure opening opt-in because these commands create
%     editor/graphics windows.
openSavedEvidence = false;

% 07. Leave centralized tests opt-in. The expensive numerical tests remain
%     controlled by their documented environment variables.
runFastPackageTests = false;

% 08. Freeze the numerical values expected from this packaged experiment.
expectedSampleIndices = 194:198;
expectedCriticalDx = 4.43406193516227;
criticalDxTolerance = 2e-6;

%% Step 2 - Locate the relocatable package and configure MATLAB paths

% 09. Resolve this script instead of assuming MATLAB started in the
%     repository root.
walkthroughFile = mfilename('fullpath');
if isempty(walkthroughFile)
    % Run Section may evaluate in the base workspace on some MATLAB
    % releases. In that case resolve this already-open script from the path.
    walkthroughFile = which( ...
        'main_Walkthrough_PronkingMultiGaitBifurcation');
end
assert(~isempty(walkthroughFile), ...
    ['Run the saved script once, or add its package folder to the path, ' ...
    'before executing individual sections.']);

% 10. The script lives directly inside the PK reference package.
experimentRoot = fileparts(walkthroughFile);

% 11. Two parent folders above the experiment is the clean Floquet-v2 root.
floquetRoot = fileparts(fileparts(experimentRoot));

% 12. Add only the clean public package and this reference experiment.
addpath(floquetRoot);
addpath(experimentRoot);

% 13. Confirm that the qualified clean-root numerical API is available.
%     No compatibility setup or recursive path addition is required.
assert(~isempty(which('floquet.computeFDM')), ...
    'The qualified Floquet-v2 numerical API is not available.');

% 14. Resolve all live input, artifact, dynamics, and test paths from the
%     experiment-local path authority.
paths = PronkingExperimentPaths();

% 15. Confirm that path resolution did not select another package copy.
assert(strcmp(paths.ExperimentRoot,experimentRoot), ...
    'PronkingExperimentPaths resolved a different package root.');

% 16. Confirm that the intended full experiment entry point is active.
resolvedEntry = which('main_Test_PronkingMultiGaitBifurcation');
expectedEntry = fullfile(experimentRoot, ...
    'main_Test_PronkingMultiGaitBifurcation.m');
assert(strcmp(resolvedEntry,expectedEntry), ...
    'MATLAB resolved the wrong pronking experiment entry point.');

fprintf('Pronking package: %s\n',experimentRoot);
fprintf('Floquet-v2 root: %s\n',floquetRoot);

%% Step 3 - Validate the packaged parent and held-out daughter inputs

% 17. Load the only branch permitted in discovery, critical refinement, and
%     nonlinear seed construction.
parentData = load(paths.PronkingBranchFile,'results');

% 18. Require the canonical 29-by-891 continuation representation.
assert(isfield(parentData,'results'));
assert(isequal(size(parentData.results),[29 891]), ...
    'The packaged pronking parent must be a 29-by-891 results matrix.');

% 19. Reject malformed numerical data before any dynamics call.
assert(all(isfinite(parentData.results(:))), ...
    'The pronking parent contains nonfinite values.');

% 20. Confirm that every prescribed discovery column is present.
assert(max(expectedSampleIndices) <= size(parentData.results,2));

% 21. List the six known branches that are quarantined to held-out
%     validation. These files never determine an FDM perturbation direction.
daughterCodes = ["BE" "BG" "FE" "FG" "HE" "HG"];
daughterFiles = strings(size(daughterCodes));
for k = 1:numel(daughterCodes)
    daughterFiles(k) = fullfile(paths.DaughterBranchRoot, ...
        sprintf('BD1_20_2_%s.mat',char(daughterCodes(k))));
    assert(isfile(daughterFiles(k)), ...
        sprintf('Missing held-out daughter file: %s', ...
        char(daughterFiles(k))));
end

% 22. Display the parent columns used by this targeted reference scan.
parentScanTable = table(expectedSampleIndices(:), ...
    parentData.results(1,expectedSampleIndices).', ...
    'VariableNames',{'BranchColumn','dx'});
disp(parentScanTable);

% 23. Release the large parent matrix; the experiment entry point reloads it
%     from the authoritative package path when recomputation is requested.
clear parentData;

%% Step 4 - Define the auditable full-recomputation settings

% 24. Use scaled four-level central differences. Event times are re-solved
%     for every signed perturbation but are not Floquet coordinates.
floquetOptions = struct( ...
    'PerturbationMagnitude',5e-7, ...
    'PerturbationFactors',[8 4 2 1], ...
    'TopologyMode','clustered', ...
    'RejectOnDerivativeNonconvergence',true, ...
    'RejectOnForwardBackwardMismatch',true, ...
    'ErrorOnFailure',false);

% 25. Spell out the package defaults so this walkthrough is an auditable
%     numerical record rather than an implicit one-line call.
recomputeOptions = struct( ...
    'BranchFile',paths.PronkingBranchFile, ...
    'RoadmapDirectory',paths.DaughterBranchRoot, ...
    'SampleIndices',expectedSampleIndices, ...
    'FloquetOptions',floquetOptions, ...
    'RunNonlinearSearch',true, ...
    'OutputDirectory',paths.ResultsRoot, ...
    'LogFile','', ...
    'OverwriteLog',true, ...
    'MakePlots',true, ...
    'Verbose',true, ...
    'ThrowOnFailure',true);

% 26. Identify the authoritative specialized report in this package.
resultFile = fullfile(paths.ResultsRoot, ...
    'pronking_multigait_validation_results.mat');

%% Step 5 - Load the frozen result or deliberately recompute the package

switch executionMode
    case "inspect-saved"
        % 27. Read the existing authoritative report without recomputation.
        assert(isfile(resultFile), ...
            sprintf('The frozen pronking result is missing: %s',resultFile));
        saved = load(resultFile,'report');
        assert(isfield(saved,'report') && isstruct(saved.report) && ...
            isscalar(saved.report), ...
            'The authoritative MAT file does not contain a scalar report.');
        report = saved.report;
        elapsedSeconds = NaN;
        fprintf('Loaded frozen report: %s\n',resultFile);

    case "recompute-package"
        % 28. This branch intentionally replaces package artifacts.
        warning('PKWalkthrough:PackageOverwrite', [ ...
            'Full recomputation will overwrite frozen PK package artifacts, ' ...
            'reference_experiment_config.mat, and invalidate SHA256SUMS.']);
        tic;
        report = main_Test_PronkingMultiGaitBifurcation(recomputeOptions);
        elapsedSeconds = toc;
        fprintf('Full recomputation elapsed time: %.1f seconds\n', ...
            elapsedSeconds);

    otherwise
        error('PKWalkthrough:ExecutionMode', ...
            'executionMode must be "inspect-saved" or "recompute-package".');
end

% 29. The complete reference result must validate both the linear critical
%     space and the nonlinear six-ray search.
assert(strcmp(report.status,'verified'), ...
    sprintf('Expected a verified pronking report; observed %s.', ...
    report.status));
assert(report.conclusion.blindSixArmDiscoveryValidated, ...
    'The report did not certify the six oriented nonlinear rays.');

fprintf('Report status: %s\n',report.status);

%% Step 6 - Inspect the five reduced Floquet matrices and detected candidates

% 30. Extract the parent-only reduced-Poincare discovery calculation.
discovery = report.floquetExperiment;

% 31. Confirm exact, ordered coverage of the prescribed local branch window.
assert(isequal(discovery.sampleIndices,expectedSampleIndices));

% 32. No rejected FDM point may be hidden inside the critical bracket.
assert(all(discovery.accepted), ...
    'At least one pronking FDM in columns 194:198 was rejected.');

% 33. Flatten the important finite-difference diagnostics for manual review.
pointCount = numel(discovery.sampleIndices);
fdRelativeError = NaN(pointCount,1);
forwardBackwardError = NaN(pointCount,1);
spectralRadius = NaN(pointCount,1);
for k = 1:pointCount
    detail = discovery.diagnostics{k};
    assert(detail.accepted);
    fdRelativeError(k) = ...
        detail.derivativeConvergence.finestRelativeError;
    forwardBackwardError(k) = ...
        detail.maximumFinestForwardBackwardError;
    spectralRadius(k) = max(abs(discovery.multipliers(:,k)));
end

fdTable = table(discovery.sampleIndices(:), ...
    discovery.continuationCoordinate(:),fdRelativeError, ...
    forwardBackwardError,spectralRadius, ...
    'VariableNames',{'BranchColumn','dx','FDRelativeError', ...
    'ForwardBackwardError','SpectralRadius'});
disp(fdTable);

% 34. Display candidate values without struct2table, whose heterogeneous
%     fields are not a rectangular table.
candidates = discovery.candidates;
assert(~isempty(candidates),'No persistent candidates were detected.');
candidateTable = table(string({candidates.Type}).', ...
    [candidates.ContinuationParameter].', ...
    [candidates.Multiplier].',[candidates.ConfidenceScore].', ...
    'VariableNames',{'Type','DetectedDx','Multiplier','Confidence'});
disp(candidateTable);

% 35. A repeated pronking kernel requires at least three additional +1
%     candidate tracks before invariant-subspace refinement.
plusCandidates = candidates(strcmp({candidates.Type},'+1'));
assert(numel(plusCandidates) >= 3, ...
    'Expected at least three additional +1 candidate tracks.');

%% Step 7 - Verify the corrected critical orbit and multiplier root

% 36. The detector interpolation is not the bifurcation point. The corrected
%     periodic orbit returned by the refiner is authoritative.
refinement = report.critical.refinement;
assert(refinement.accepted);

% 37. Check the corrected critical coordinate and final bracket width.
assert(abs(refinement.coordinate-expectedCriticalDx) < ...
    criticalDxTolerance);
assert(abs(diff(refinement.finalBracket)) <= 2e-6);

% 38. Require small spectral uncertainty and a closed periodic orbit.
assert(refinement.criticalMultiplierUncertainty <= 2e-6);
assert(refinement.canonicalResidualNormInf <= 1e-8);
assert(refinement.periodicValidation.accepted);
assert(refinement.timingValidation.accepted);
assert(isequal(size(refinement.floquetMatrix),[12 12]));
assert(numel(report.critical.solution) == 22);

refinementTable = table(refinement.coordinate, ...
    abs(diff(refinement.finalBracket)), ...
    refinement.multiplierResidual, ...
    refinement.criticalMultiplierUncertainty, ...
    refinement.canonicalResidualNormInf, ...
    'VariableNames',{'CriticalDx','BracketWidth','MultiplierResidual', ...
    'MultiplierUncertainty','CanonicalResidualInf'});
disp(refinementTable);

%% Step 8 - Verify the four-dimensional kernel and three physical directions

% 39. Resolve the tangent plus three symmetry-breaking directions from
%     ker(M-I), rather than trusting arbitrary eigenvectors of a repeated root.
symmetry = report.symmetry.diagnostics;
directions = report.symmetry.directions;
assert(symmetry.accepted);

% 40. The full kernel contains one parent tangent and three additional modes.
assert(symmetry.numericalNullity == 4);
assert(symmetry.additionalDimension == 3);

% 41. Verify the expected full and tangent-free symmetry-sector ranks.
assert(isequal(symmetry.fullSectorRanks,[2 1 1 0]));
assert(isequal(symmetry.additionalSectorRanks,[1 1 1 0]));

% 42. Columns are bounding, front-spread, and hind-spread directions in the
%     12-coordinate reduced apex chart.
assert(isequal(size(directions.Matrix),[12 3]));
directionNames = ["Bounding";"FrontSpread";"HindSpread"];
directionNorms = vecnorm(directions.Matrix./directions.StateScale,2,1).';
directionTable = table(directionNames,directionNorms);
disp(directionTable);

%% Step 9 - Verify the parent-only nonlinear search found six persistent rays

% 43. The nonlinear search uses symmetry-derived directions and production
%     timing lifts; daughter branch files are not seed data.
search = report.nonlinearSearch;
assert(strcmp(search.status,'verified'));
assert(search.blindSixArmDiscoveryValidated);

% 44. Six seeds at two radii produce 12 accepted nonlinear branch points.
assert(search.attemptCount == 12);
assert(search.nonParentAcceptedCount == 12);
assert(search.persistentClusterCount == 6);
assert(isequal(search.persistentClassCounts,[2 2 2]));

% 45. Check every accepted corrected orbit and its corrector provenance.
acceptedAttempts = search.attempts([search.attempts.nonParentAccepted]);
assert(numel(acceptedAttempts) == 12);
assert(all([acceptedAttempts.predictorAccepted]));
assert(all([acceptedAttempts.correctorAccepted]));
assert(all([acceptedAttempts.transverseFraction] > 0.2));
assert(all(strcmp({acceptedAttempts.correctorMethod}, ...
    'pronking-symmetry-amplitude-corrector')));

for k = 1:numel(acceptedAttempts)
    attempt = acceptedAttempts(k);
    info = attempt.correctorInfo;
    assert(strcmp(attempt.requestedGaitClass,attempt.gaitClass));
    assert(all(struct2array(info.validation)));
    assert(info.canonicalResidualNormInf <= 1e-8);
    assert(info.symmetryResidualNormInf <= 1e-7);
    assert(abs(info.amplitudeResidual) <= 1e-7);
    assert(info.returnResidualNorm <= 1e-7);
    assert(info.eventTimeError <= 1e-6);
    assert(info.periodicValidation.accepted);
end

attemptTable = table([acceptedAttempts.index].', ...
    [acceptedAttempts.radius].',string({acceptedAttempts.seedLabel}).', ...
    string({acceptedAttempts.requestedGaitClass}).', ...
    string({acceptedAttempts.gaitClass}).', ...
    [acceptedAttempts.canonicalResidualNorm].', ...
    [acceptedAttempts.returnResidualNorm].', ...
    [acceptedAttempts.eventTimeError].', ...
    'VariableNames',{'Attempt','Radius','Seed','RequestedClass', ...
    'CorrectedClass','CanonicalResidual','ReturnResidual','EventTimeError'});
disp(attemptTable);

% 46. Show the six oriented clusters that persist at both radii.
persistentClusters = search.clusters([search.clusters.persistent]);
clusterTable = table([persistentClusters.id].', ...
    string({persistentClusters.gaitClass}).', ...
    reshape({persistentClusters.radii},[],1), ...
    reshape({persistentClusters.attemptIndices},[],1), ...
    [persistentClusters.maximumCanonicalResidual].', ...
    [persistentClusters.maximumReturnResidual].', ...
    'VariableNames',{'Cluster','GaitClass','Radii','AttemptIndices', ...
    'MaximumCanonicalResidual','MaximumReturnResidual'});
disp(clusterTable);

%% Step 10 - Inspect the separate six-branch held-out validation record

% 47. This is the first walkthrough step that interprets BE, BG, FE, FG, HE,
%     and HG. The production report currently evaluates this comparison
%     before its nonlinear search, but neither the daughter data nor this
%     validation output is passed into the search directions, timing lifts,
%     correctors, or clustering.
validation = report.daughterValidation;
assert(validation.accepted);
assert(validation.linearPredictionValidated);
assert(validation.threeGaitClassesIdentified);
assert(validation.savedDaughterAgreementValidated);

% 48. The held-out representatives must span the same three-dimensional
%     tangent-free critical space.
assert(validation.daughterDirectionRank == 3);
assert(min(validation.principalCosines) > 0.98);

% 49. Verify the expected gait order, symmetry classes, and periodic orbits.
daughters = validation.daughters;
assert(isequal(string({daughters.code}),daughterCodes));
assert(isequal(string({daughters.predictedClass}), ...
    ["B" "B" "F" "F" "H" "H"]));
assert(all([daughters.classificationMatches]));
assert(all([daughters.timingSymmetryMatches]));
assert(all([daughters.periodicOrbitAccepted]));

daughterTable = table(string({daughters.code}).', ...
    string({daughters.expectedClass}).', ...
    string({daughters.predictedClass}).', ...
    string({daughters.abbreviation}).', ...
    [daughters.transverseAlignment].', ...
    [daughters.angleDegrees].', ...
    [daughters.projectionResidual].', ...
    'VariableNames',{'Daughter','ExpectedClass','PredictedClass', ...
    'IdentifiedGait','CriticalSpaceAlignment','AngleDegrees', ...
    'ProjectionResidual'});
disp(daughterTable);

fprintf('Principal cosines: %s\n', ...
    mat2str(validation.principalCosines(:).',9));

%% Step 11 - Independently replay all corrected periodic orbits

if runIndependentReplay
    % 50. WriteCsv=false and an empty LogFile make this replay read-only.
    audit = main_HandValidate_PronkingBifurcation(struct( ...
        'ResultsFile',resultFile, ...
        'OutputCsv','', ...
        'LogFile','', ...
        'WriteCsv',false, ...
        'Verbose',true, ...
        'ThrowOnFailure',true));

    % 51. The replay recomputes canonical residuals, normal timing solves,
    %     Poincare closure, topology, and gait classification for all 12 points.
    assert(audit.accepted);
    assert(audit.replayedOrbitCount == 12);
    assert(audit.acceptedOrbitCount == 12);
    assert(audit.allAccepted);
    assert(audit.sixArmStructurePresent);
    assert(isequal(audit.persistentClassCounts,[2 2 2]));
    disp(audit.table);
else
    fprintf('Independent replay skipped by Step 1 setting.\n');
end

%% Step 12 - Inspect flat audit tables and optional saved figures

% 52. MAT files remain numerical authority. These CSV files are flat manual
%     projections and are not inputs to downstream calculations.
summaryFile = fullfile(paths.ResultsRoot, ...
    'pronking_multigait_validation_summary.csv');
attemptsFile = fullfile(paths.ResultsRoot, ...
    'pronking_branch_search_attempts.csv');
clustersFile = fullfile(paths.ResultsRoot, ...
    'pronking_branch_search_clusters.csv');
orbitsFile = fullfile(paths.ResultsRoot, ...
    'pronking_corrected_orbits.csv');
markdownFile = fullfile(paths.ResultsRoot, ...
    'pronking_multigait_validation_report.md');

% 53. Confirm that the flattened evidence has the expected cardinality.
evidenceFiles = {summaryFile,attemptsFile,clustersFile,orbitsFile,markdownFile};
for k = 1:numel(evidenceFiles)
    assert(isfile(evidenceFiles{k}), ...
        sprintf('Missing saved evidence file: %s',evidenceFiles{k}));
end
savedDaughterTable = readtable(summaryFile);
savedAttemptTable = readtable(attemptsFile);
savedClusterTable = readtable(clustersFile);
savedOrbitTable = readtable(orbitsFile);
assert(height(savedDaughterTable) == 6);
assert(height(savedAttemptTable) == 12);
assert(height(savedClusterTable) == 6);
assert(height(savedOrbitTable) == 12);

disp(savedDaughterTable);
disp(savedClusterTable);

% 54. Open the Markdown report and portable PNG evidence when requested.
if openSavedEvidence
    edit(markdownFile);
    figureNames = { ...
        'pronking_critical_spectrum.png', ...
        'pronking_critical_directions.png', ...
        'pronking_corrected_branch_rays.png', ...
        'pronking_daughter_validation.png'};
    for k = 1:numel(figureNames)
        figureFile = fullfile(paths.ResultsRoot,figureNames{k});
        assert(isfile(figureFile), ...
            sprintf('Missing saved figure: %s',figureFile));
        pixels = imread(figureFile);
        figure('Name',figureNames{k},'Color','w');
        image(pixels);
        axis image off;
    end
end

%% Step 13 - Optionally run the fast centralized package regressions

if runFastPackageTests
    % 55. Fast mode expects expensive gates to be unset. Gated production
    %     cases will be reported as Incomplete, which is not a failure.
    assert(~strcmp(getenv('SLIP_RUN_LONG_FLOQUET_TESTS'),'1'), ...
        'Unset SLIP_RUN_LONG_FLOQUET_TESTS for the fast walkthrough test.');
    assert(~strcmp(getenv('SLIP_RUN_BRANCH_SWITCH_TESTS'),'1'), ...
        'Unset SLIP_RUN_BRANCH_SWITCH_TESTS for the fast walkthrough test.');
    assert(~strcmp(getenv('SLIP_RUN_PRONKING_GAIT_CORRECTOR_TESTS'),'1'), ...
        ['Unset SLIP_RUN_PRONKING_GAIT_CORRECTOR_TESTS for the fast ' ...
        'walkthrough test.']);

    testRoot = fullfile(floquetRoot,'tests','production');
    suite = [ ...
        testsuite(fullfile(testRoot,'test_pronking_branch.m')), ...
        testsuite(fullfile(testRoot, ...
            'test_pronking_multigait_prediction.m'))];
    testResults = run(suite);
    disp(testResults);
    assert(~any([testResults.Failed]), ...
        'At least one fast pronking package regression failed.');
else
    fprintf('Fast centralized tests skipped by Step 1 setting.\n');
end

%% Step 14 - Print the final scientific interpretation

fprintf('\nPronking walkthrough completed successfully.\n');
fprintf('  Corrected critical dx: %.15g\n',refinement.coordinate);
fprintf('  dim ker(M-I): %d\n',symmetry.numericalNullity);
fprintf('  Tangent-free critical dimension: %d\n', ...
    symmetry.additionalDimension);
fprintf('  Persistent [B F H] rays: %s\n', ...
    mat2str(search.persistentClassCounts));
fprintf('  Held-out minimum alignment: %.9f\n', ...
    min([daughters.transverseAlignment]));
fprintf(['  Interpretation: one corrected pronking point has three additional ' ...
    '+1 directions and six persistent oriented nonlinear rays.\n']);
