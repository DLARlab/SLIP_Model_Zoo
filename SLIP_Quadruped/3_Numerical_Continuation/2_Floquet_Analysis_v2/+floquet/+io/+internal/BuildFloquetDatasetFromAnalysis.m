function [FloquetData, outputFile] = BuildFloquetDatasetFromAnalysis( ...
        analysis, options)
%BUILDFLOQUETDATASETFROMANALYSIS Create a GUI view without recomputing FDM.
%
%   DATA = BUILDFLOQUETDATASETFROMANALYSIS(ANALYSIS) converts the canonical
%   result of AnalyzeFloquetBranch into the FloquetData schema consumed by
%   FloquetAnalysisGUI. Reduced matrices, solved event times, acceptance,
%   canonical tracks, and DetectBifurcation candidates are copied from the
%   analysis. TrackFloquetMultipliers is run only to obtain the historical
%   GUI color/order representation; it does not accept candidates.
%
%   [DATA,FILE] = ...(...,OPTIONS) optionally saves DATA when
%   OPTIONS.SaveDataset is true. OPTIONS fields are OutputFile, Overwrite,
%   SaveDataset, and BranchName.

    if nargin < 2 || isempty(options)
        options = struct();
    end
    opts = ParseOptions(options);
    ValidateAnalysis(analysis);
    authority = ResolveAnalysisAuthority(analysis);

    indices = analysis.branchIndices(:).';
    coordinate = analysis.continuationCoordinate(:).';
    accepted = logical(analysis.accepted(:).');
    pointCount = numel(indices);
    rawValues = analysis.rawMultipliers;
    rawVectors = PackRawEigenvectors(analysis.rawEigenvectors, pointCount);

    displayOptions = struct('Reliability', accepted, ...
        'IntervalReliability', logical(analysis.intervalReliability(:).'));
    [displayValues, displayVectors, displayTracking] = ...
        floquet.io.internal.TrackFloquetMultipliers( ...
            rawValues, rawVectors, displayOptions);
    [distancePlus, distanceMinus, distanceUnit] = ...
        Distances(displayValues, accepted);
    tangentAvailable = false;
    if isfield(analysis, 'branchTangents') && ...
            isnumeric(analysis.branchTangents)
        tangentAvailable = any(all(isfinite(analysis.branchTangents), 1));
    end
    indicators = ProjectCandidates(analysis.candidates, indices, accepted);

    solvedTimes = analysis.solvedEventTimes;
    baseTimingValid = all(isfinite(solvedTimes), 1) & solvedTimes(9, :) > 0;
    sourceFile = '';
    if isfield(analysis, 'source') && isfield(analysis.source, 'file')
        sourceFile = analysis.source.file;
    end
    branchName = opts.BranchName;
    if isempty(branchName)
        if isfield(analysis, 'source') && ...
                isfield(analysis.source, 'branchName') && ...
                ~isempty(analysis.source.branchName)
            branchName = analysis.source.branchName;
        elseif isfield(analysis, 'source') && ...
                isfield(analysis.source, 'stem') && ...
                ~isempty(analysis.source.stem)
            branchName = analysis.source.stem;
        else
            branchName = 'continuation_branch';
        end
    end

    info = struct();
    info.schema_version = '1.1-analysis-view';
    info.generated_at = Timestamp();
    info.status = DatasetStatus(accepted);
    info.accepted = accepted;
    info.base_event_time_valid = baseTimingValid;
    info.accepted_count = nnz(accepted);
    info.rejected_count = pointCount - nnz(accepted);
    info.floquet_method = ...
        'corrected reduced Poincare-map finite-difference derivative';
    info.algorithm_id = authority.datasetAlgorithmID;
    info.production_evaluator = authority.productionEvaluator;
    info.scientific_authority = authority.scientificAuthority;
    info.map_definition = ...
        'DP on the 12-coordinate apex-to-apex Poincare section';
    info.reduced_state_indices = [1 2 4:13];
    info.section_normal_state_index = 3;
    info.event_time_policy = ...
        'solved internally; not included in the Floquet state';
    info.floquet_state_includes_event_times = false;
    info.branch_point_test_available = false;
    info.branch_tangent_classification_available = tangentAvailable;
    if isfield(analysis, 'fixedPhysicalParameterSegment')
        info.fixed_physical_parameter_segment = ...
            analysis.fixedPhysicalParameterSegment;
    end
    if isfield(analysis, 'parameterConstancy')
        info.parameter_constancy = analysis.parameterConstancy;
    end
    info.plus_one_label_policy = 'candidate +1 Floquet degeneracy';
    info.source_file = sourceFile;
    info.selected_columns = indices;
    info.source_analysis_version = analysis.version;
    info.source_analysis_algorithm_id = analysis.algorithmID;
    info.source_analysis_production_evaluator = ...
        authority.productionEvaluator;
    info.source_analysis_scientific_authority = ...
        authority.scientificAuthority;
    info.source_analysis_full_parent_coverage = ...
        authority.fullParentCoverage;
    info.source_analysis_ordered_parent_coverage = ...
        authority.orderedParentCoverage;
    info.source_analysis_parent_only = authority.parentOnly;
    info.scientific_authority_basis = authority.basis;
    info.analysis_authority_role = authority.role;
    info.source_analysis_provenance = analysis.provenance;
    info.source_analysis_quality = analysis.quality;
    info.raw_eigenvalues = rawValues;
    info.raw_eigenvectors = rawVectors;
    info.tracking = displayTracking;
    info.visualization_tracking = displayTracking;
    info.visualization_tracking_role = ...
        'GUI ordering/color continuity only; not a candidate detector.';
    info.authoritative_tracks = analysis.tracks;
    info.authoritative_tracking = analysis.trackingDiagnostics;
    info.authoritative_detector = 'DetectBifurcation';
    info.authoritative_candidates = analysis.candidates;
    info.detector_report = analysis.detectorReport;
    info.candidate_summary = CandidateSummary( ...
        analysis.candidates, indices, tangentAvailable);
    if isfield(analysis, 'baseEventTopologies')
        info.base_event_topology = analysis.baseEventTopologies;
    end
    if isfield(analysis, 'adjacentTopologyConsistent')
        info.adjacent_event_topology_consistent = ...
            analysis.adjacentTopologyConsistent;
    end
    if isfield(analysis, 'adjacentTopologyComparisons')
        info.adjacent_event_topology_comparison = ...
            analysis.adjacentTopologyComparisons;
    end
    info.interval_reliability = analysis.intervalReliability;
    info.dataset_role = ...
        'lossless GUI view derived from canonical AnalyzeFloquetBranch result';
    info.matlab_version = version;

    FloquetData = struct();
    FloquetData.branch_index = indices;
    FloquetData.continuation_parameter = coordinate;
    FloquetData.solution_state = analysis.states;
    FloquetData.event_time = solvedTimes;
    FloquetData.floquet_matrix = analysis.matrices;
    FloquetData.eigenvalues = displayValues;
    FloquetData.eigenvectors = displayVectors;
    FloquetData.distance_plus_one = distancePlus;
    FloquetData.distance_minus_one = distanceMinus;
    FloquetData.unit_circle_distance = distanceUnit;
    FloquetData.bifurcation_indicator = indicators;
    FloquetData.computation_info = info;
    FloquetData.branch_name = branchName;
    FloquetData.continuation_parameter_name = ...
        analysis.continuationParameterName;
    FloquetData.model_parameters = analysis.parameters;
    FloquetData.schema_version = '1.1-analysis-view';

    outputFile = '';
    if opts.SaveDataset
        outputFile = CanonicalOutput(opts.OutputFile);
        if ~isempty(sourceFile) && SameCanonicalPath(outputFile, sourceFile)
            error('BuildFloquetDatasetFromAnalysis:OutputIsSource', ...
                ['A derived GUI dataset must not overwrite the parent ' ...
                 'continuation-branch source file.']);
        end
        analysisFile = AnalysisOutputFile(analysis);
        if ~isempty(analysisFile) && ...
                SameCanonicalPath(outputFile, analysisFile)
            error('BuildFloquetDatasetFromAnalysis:OutputIsAnalysis', ...
                ['A derived GUI dataset must not overwrite the canonical ' ...
                 'AnalyzeFloquetBranch artifact.']);
        end
        SaveAtomically(outputFile, FloquetData, opts.Overwrite);
    end
end

function opts = ParseOptions(options)
    defaults = struct('SaveDataset', false, 'OutputFile', '', ...
        'Overwrite', false, 'BranchName', '');
    if ~isstruct(options) || ~isscalar(options)
        error('BuildFloquetDatasetFromAnalysis:InvalidOptions', ...
            'options must be a scalar structure.');
    end
    opts = defaults;
    supplied = fieldnames(options);
    allowed = fieldnames(defaults);
    for k = 1:numel(supplied)
        hit = find(strcmpi(supplied{k}, allowed), 1);
        if isempty(hit)
            error('BuildFloquetDatasetFromAnalysis:UnknownOption', ...
                'Unknown option %s.', supplied{k});
        end
        opts.(allowed{hit}) = options.(supplied{k});
    end
    opts.SaveDataset = Logical(opts.SaveDataset, 'SaveDataset');
    opts.Overwrite = Logical(opts.Overwrite, 'Overwrite');
    textFields = {'OutputFile', 'BranchName'};
    for k = 1:numel(textFields)
        value = opts.(textFields{k});
        if isstring(value) && isscalar(value), value = char(value); end
        if ~ischar(value)
            error('BuildFloquetDatasetFromAnalysis:TextOption', ...
                '%s must be text.', textFields{k});
        end
        opts.(textFields{k}) = value;
    end
    if opts.SaveDataset && isempty(strtrim(opts.OutputFile))
        error('BuildFloquetDatasetFromAnalysis:OutputFile', ...
            'OutputFile is required when SaveDataset is true.');
    end
end

function ValidateAnalysis(analysis)
    required = {'version','algorithmID','provenance','branchIndices', ...
        'continuationCoordinate','continuationParameterName','states', ...
        'solvedEventTimes','parameters','matrices','rawMultipliers', ...
        'rawEigenvectors','accepted','intervalReliability','tracks', ...
        'trackingDiagnostics','candidates','detectorReport','quality'};
    if ~isstruct(analysis) || ~isscalar(analysis) || ...
            ~all(isfield(analysis, required)) || ...
            ~startsWith(char(string(analysis.version)), ...
                'floquet-branch-analysis-')
        error('BuildFloquetDatasetFromAnalysis:InvalidAnalysis', ...
            'Input must be a canonical AnalyzeFloquetBranch result.');
    end
    count = numel(analysis.branchIndices);
    if count < 1 || ~isequal(size(analysis.states), [13 count]) || ...
            ~isequal(size(analysis.solvedEventTimes), [9 count]) || ...
            ~isequal(size(analysis.parameters), [7 count]) || ...
            ~isequal([size(analysis.matrices,1), size(analysis.matrices,2), ...
                size(analysis.matrices,3)], [12 12 count]) || ...
            ~isequal(size(analysis.rawMultipliers), [12 count]) || ...
            numel(analysis.accepted) ~= count
        error('BuildFloquetDatasetFromAnalysis:AnalysisShape', ...
            'Canonical analysis arrays have inconsistent point counts.');
    end
end

function authority = ResolveAnalysisAuthority(analysis)
    canonicalAlgorithm = ...
        'reduced-poincare-fdm-v2-canonical-branch-scan';
    if ~strcmp(char(string(analysis.algorithmID)), canonicalAlgorithm)
        error('BuildFloquetDatasetFromAnalysis:AnalysisAlgorithm', ...
            ['The analysis algorithm identifier is not the canonical ' ...
             'AnalyzeFloquetBranch implementation.']);
    end
    provenance = analysis.provenance;
    if ~isstruct(provenance) || ~isscalar(provenance) || ...
            ~isfield(provenance, 'productionEvaluator')
        error('BuildFloquetDatasetFromAnalysis:MissingEvaluatorProvenance', ...
            ['Canonical analysis provenance must state whether the ' ...
             'production Floquet evaluator was used.']);
    end
    productionEvaluator = ProvenanceLogical( ...
        provenance.productionEvaluator, 'productionEvaluator');

    % Authority belongs to a canonical, parent-only, full ordered scan.  A
    % production evaluator is necessary but deliberately insufficient: a
    % windowed production scan remains a diagnostic view.  All predicates
    % must be recorded by AnalyzeFloquetBranch and agree with the actual
    % selected columns before the derived cache may retain authority.
    fullParentCoverage = RecordedLogical( ...
        provenance, 'fullParentCoverage', false);
    orderedParentCoverage = RecordedLogical( ...
        provenance, 'orderedParentCoverage', false);
    topFullParentCoverage = RecordedLogical( ...
        analysis, 'fullParentCoverage', false);
    topOrderedParentCoverage = RecordedLogical( ...
        analysis, 'fullOrderedParentCoverage', false);
    coverageRecordFull = false;
    coverageRecordOrdered = false;
    if isfield(analysis,'coverage') && isstruct(analysis.coverage) && ...
            isscalar(analysis.coverage)
        coverageRecordFull = RecordedLogical( ...
            analysis.coverage,'fullParentCoverage',false);
        coverageRecordOrdered = RecordedLogical( ...
            analysis.coverage,'fullOrderedParentCoverage',false);
    end
    parentOnly = RecordedLogical(provenance, 'parentDataOnly', false);
    noDaughterData = ~RecordedLogical( ...
        provenance, 'daughterDataLoaded', true);
    topParentOnly = RecordedLogical(analysis, 'parentOnly', false);
    topNoDaughterData = ~RecordedLogical( ...
        analysis, 'daughterDataLoaded', true);

    sourcePointCount = NaN;
    if isfield(analysis, 'source') && isstruct(analysis.source) && ...
            isscalar(analysis.source) && ...
            isfield(analysis.source, 'fullBranchPointCount')
        sourcePointCount = analysis.source.fullBranchPointCount;
    end
    validSourceCount = isnumeric(sourcePointCount) && ...
        isscalar(sourcePointCount) && isfinite(sourcePointCount) && ...
        sourcePointCount >= 1 && sourcePointCount == floor(sourcePointCount);
    actualFullOrderedCoverage = validSourceCount && ...
        isequal(double(analysis.branchIndices(:).'), 1:sourcePointCount);
    if (fullParentCoverage || orderedParentCoverage) && ...
            ~actualFullOrderedCoverage
        error('BuildFloquetDatasetFromAnalysis:InconsistentCoverage', ...
            ['Analysis provenance declares full-parent coverage, but the ' ...
             'stored columns are not exactly 1:N for the source branch.']);
    end

    explicitAuthority = RecordedLogical( ...
        provenance, 'scientificAuthority', false) && ...
        RecordedLogical(analysis, 'scientificAuthority', false);
    scientificAuthority = productionEvaluator && fullParentCoverage && ...
        orderedParentCoverage && topFullParentCoverage && ...
        topOrderedParentCoverage && coverageRecordFull && ...
        coverageRecordOrdered && actualFullOrderedCoverage && ...
        parentOnly && noDaughterData && topParentOnly && ...
        topNoDaughterData && explicitAuthority;
    declaredTrue = RecordedLogical( ...
        provenance, 'scientificAuthority', false) || ...
        RecordedLogical(analysis, 'scientificAuthority', false);
    if declaredTrue && ~scientificAuthority
        error('BuildFloquetDatasetFromAnalysis:InconsistentAuthority', ...
            ['Scientific authority was declared without canonical ' ...
             'production, parent-only, full ordered branch coverage.']);
    end

    authority = struct();
    authority.productionEvaluator = productionEvaluator;
    authority.scientificAuthority = scientificAuthority;
    authority.fullParentCoverage = fullParentCoverage && ...
        topFullParentCoverage && coverageRecordFull && ...
        actualFullOrderedCoverage;
    authority.orderedParentCoverage = orderedParentCoverage && ...
        topOrderedParentCoverage && coverageRecordOrdered && ...
        actualFullOrderedCoverage;
    authority.parentOnly = parentOnly && noDaughterData && ...
        topParentOnly && topNoDaughterData;
    authority.basis = [ ...
        'canonical algorithm + production evaluator + parent-only ' ...
        'provenance + exact ordered 1:N source coverage'];
    if scientificAuthority
        authority.role = 'authoritative-analysis-derived-gui-view';
    elseif productionEvaluator
        authority.role = 'diagnostic-production-analysis-view';
    else
        authority.role = 'diagnostic-nonproduction-analysis-view';
    end
    if productionEvaluator
        authority.datasetAlgorithmID = 'reduced-poincare-fdm-v2';
    else
        authority.datasetAlgorithmID = 'nonproduction-evaluator';
    end
end

function value = RecordedLogical(source, field, fallback)
    value = fallback;
    if ~isstruct(source) || ~isscalar(source) || ~isfield(source, field)
        return
    end
    raw = source.(field);
    if ~(isscalar(raw) && (islogical(raw) || ...
            (isnumeric(raw) && isreal(raw) && isfinite(raw) && ...
             any(raw == [0 1]))))
        error('BuildFloquetDatasetFromAnalysis:AuthorityProvenance', ...
            '%s must be scalar logical when present.', field);
    end
    value = logical(raw);
end

function value = ProvenanceLogical(value, name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isreal(value) && isfinite(value) && ...
             any(value == [0 1]))))
        error('BuildFloquetDatasetFromAnalysis:EvaluatorProvenance', ...
            'analysis.provenance.%s must be scalar logical.', name);
    end
    value = logical(value);
end

function filename = AnalysisOutputFile(analysis)
    filename = '';
    if ~isfield(analysis, 'outputFile') || isempty(analysis.outputFile)
        return
    end
    value = analysis.outputFile;
    if isstring(value) && isscalar(value)
        value = char(value);
    end
    if ~ischar(value)
        error('BuildFloquetDatasetFromAnalysis:AnalysisOutputFile', ...
            'analysis.outputFile must be scalar text when present.');
    end
    filename = strtrim(value);
end

function vectors = PackRawEigenvectors(input, count)
    vectors = complex(NaN(12, 12, count), NaN(12, 12, count));
    if isnumeric(input) && ndims(input) == 3 && ...
            isequal([size(input,1), size(input,2), size(input,3)], ...
                [12 12 count])
        vectors = input;
        return
    end
    if ~iscell(input) || numel(input) ~= count
        error('BuildFloquetDatasetFromAnalysis:RawEigenvectors', ...
            'rawEigenvectors must contain one 12-by-12 matrix per point.');
    end
    for k = 1:count
        if ~isempty(input{k})
            if ~isequal(size(input{k}), [12 12])
                error('BuildFloquetDatasetFromAnalysis:RawEigenvectors', ...
                    'Raw eigenvector matrix %d is not 12-by-12.', k);
            end
            vectors(:, :, k) = input{k};
        end
    end
end

function [dPlus, dMinus, dUnit] = Distances(values, accepted)
    count = size(values, 2);
    dPlus = NaN(1, count);
    dMinus = NaN(1, count);
    dUnit = NaN(1, count);
    for k = find(accepted)
        lambda = values(:, k);
        dPlus(k) = min(abs(lambda - 1));
        dMinus(k) = min(abs(lambda + 1));
        dUnit(k) = min(abs(abs(lambda) - 1));
    end
end

function indicators = ProjectCandidates(candidates, indices, accepted)
    empty = struct('branch_index', NaN, 'is_candidate', false, ...
        'candidate_plus_one', false, 'candidate_minus_one', false, ...
        'candidate_unit_circle', false, 'candidate_torus', false, ...
        'labels', {{}}, 'details', struct([]));
    indicators = repmat(empty, 1, numel(indices));
    for k = 1:numel(indices), indicators(k).branch_index = indices(k); end
    for k = 1:numel(candidates)
        candidate = candidates(k);
        local = candidate.LeftIndex + (candidate.Fraction > 0.5);
        if local < 1 || local > numel(indices) || ~accepted(local)
            error('BuildFloquetDatasetFromAnalysis:CandidateIndex', ...
                'Canonical candidate %d does not map to an accepted point.', k);
        end
        [field, label] = CandidatePresentation(candidate.Type);
        indicators(local).is_candidate = true;
        indicators(local).(field) = true;
        if strcmp(field, 'candidate_unit_circle')
            indicators(local).candidate_torus = true;
        end
        if ~any(strcmp(indicators(local).labels, label))
            indicators(local).labels{end + 1} = label;
        end
        if isempty(indicators(local).details)
            indicators(local).details = candidate;
        else
            indicators(local).details(end + 1) = candidate;
        end
    end
end

function [field, label] = CandidatePresentation(type)
    switch char(string(type))
        case '+1'
            field = 'candidate_plus_one';
            label = 'candidate +1 Floquet degeneracy';
        case '-1'
            field = 'candidate_minus_one';
            label = 'candidate period-doubling';
        case 'complex-unit-circle'
            field = 'candidate_unit_circle';
            label = 'candidate torus';
        otherwise
            error('BuildFloquetDatasetFromAnalysis:CandidateType', ...
                'Unsupported canonical candidate type %s.', char(string(type)));
    end
end

function summary = CandidateSummary(candidates, indices, tangentAvailable)
    summary = struct();
    summary.method = 'canonical persistent DetectBifurcation projection';
    summary.authority = 'AnalyzeFloquetBranch';
    summary.visualization_tracking_used_for_detection = false;
    summary.branch_point_test_available = false;
    summary.branch_tangent_classification_available = tangentAvailable;
    summary.authoritative_candidates = candidates;
    summary.candidates = candidates;
    summary.plus_one_indices = CandidateIndices(candidates, indices, '+1');
    summary.minus_one_indices = CandidateIndices(candidates, indices, '-1');
    summary.unit_circle_indices = CandidateIndices( ...
        candidates, indices, 'complex-unit-circle');
end

function output = CandidateIndices(candidates, indices, type)
    output = [];
    for k = 1:numel(candidates)
        if strcmp(char(string(candidates(k).Type)), type)
            local = candidates(k).LeftIndex + (candidates(k).Fraction > 0.5);
            output(end + 1) = indices(local); %#ok<AGROW>
        end
    end
    output = unique(output, 'stable');
end

function status = DatasetStatus(accepted)
    if all(accepted), status = 'complete';
    elseif any(accepted), status = 'partial';
    else, status = 'failed';
    end
end

function SaveAtomically(filename, FloquetData, overwrite)
    if isfile(filename) && ~overwrite
        error('BuildFloquetDatasetFromAnalysis:OutputExists', ...
            'Output file already exists: %s', filename);
    end
    folder = fileparts(filename);
    if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
    temporary = [tempname(Conditional(isempty(folder), pwd, folder)), '.mat'];
    cleanup = onCleanup(@() DeleteIfPresent(temporary));
    metadata = whos('FloquetData');
    if metadata.bytes < 1.8e9
        save(temporary, 'FloquetData', '-v7');
    else
        save(temporary, 'FloquetData', '-v7.3');
    end
    if overwrite
        [ok, message] = movefile(temporary, filename, 'f');
    else
        [ok, message] = movefile(temporary, filename);
    end
    if ~ok
        error('BuildFloquetDatasetFromAnalysis:SaveFailed', '%s', message);
    end
    clear cleanup
end

function tf = SameCanonicalPath(left, right)
    left = char(java.io.File(char(string(left))).getCanonicalPath());
    right = char(java.io.File(char(string(right))).getCanonicalPath());
    if ispc
        tf = strcmpi(left, right);
    else
        tf = strcmp(left, right);
    end
end

function filename = CanonicalOutput(filename)
    filename = char(string(filename));
    [~, ~, extension] = fileparts(filename);
    if ~strcmpi(extension, '.mat')
        error('BuildFloquetDatasetFromAnalysis:OutputExtension', ...
            'OutputFile must have a .mat extension.');
    end
    file = java.io.File(filename);
    filename = char(file.getCanonicalPath());
end

function value = Logical(value, name)
    if ~(isscalar(value) && (islogical(value) || ...
            (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
        error('BuildFloquetDatasetFromAnalysis:LogicalOption', ...
            '%s must be scalar logical.', name);
    end
    value = logical(value);
end

function value = Conditional(condition, yes, no)
    if condition, value = yes; else, value = no; end
end

function DeleteIfPresent(filename)
    if isfile(filename), delete(filename); end
end

function value = Timestamp()
    value = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
end
