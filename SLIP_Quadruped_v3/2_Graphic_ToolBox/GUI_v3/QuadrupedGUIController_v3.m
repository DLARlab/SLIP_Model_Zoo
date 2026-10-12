classdef QuadrupedGUIController_v3 < handle
    %QUADRUPEDGUICONTROLLER_V3 Testable state and shared-service GUI actions.
    % Numerical algorithms remain in the v3 simulation/orbit/numerics layers.
    % Pause/stop are cooperative at accepted/rejected point boundaries.
    properties (SetAccess = private)
        Root
        Schema
        Folder
        Datasets = struct('name', {}, 'source', {}, 'solutions', {}, 'components', {}, 'ordered_components', {}, 'line_warnings', {})
        SelectedDataset = 0
        SelectedIndex = 0
        Candidate = []
        PredictedCandidate = []
        SolvedCandidate = []
        SecondSeed = []
        SecondSeedBase = []
        Run = struct()
        Status = 'Ready.'
        Closing = false
        LastNumericalFailure = struct()
    end
    properties
        CorrectionSymmetry = 'none'
        ReturnPolicyOverride = 'stored'
        ReturnOccurrences = 1
        AcceptanceTolerance = 1e-8
        SolverOptions = struct('Algorithm', 'newton', ...
            'ResidualAcceptanceTolerance', 1e-8, ...
            'FunctionTolerance', 1e-10, 'MaxIterations', 40, ...
            'MaxFunctionEvaluations', 1200)
    end
    methods
        function obj = QuadrupedGUIController_v3(root)
            if nargin < 1
                root = V3Root_v3(mfilename('fullpath'));
            end
            obj.Root = char(java.io.File(root).getCanonicalPath());
            obj.Schema = QuadrupedSchema_v3.shared();
            obj.Folder = obj.Root;
        end
        function path = confinedPath(obj, path, mustExist)
            if nargin < 3, mustExist = false; end
            path = char(path);
            if ~java.io.File(path).isAbsolute()
                path = fullfile(obj.Root, path);
            end
            path = char(java.io.File(V3Path_v3(path)).getCanonicalPath());
            if ~(strcmp(path, obj.Root) || startsWith(path, [obj.Root, filesep]))
                error('QuadrupedGUIController_v3:OutsideV3', ...
                    'GUI input and output paths must resolve inside SLIP_Quadruped_v3.');
            end
            if mustExist && ~isfile(V3Path_v3(path)) && ~isfolder(V3Path_v3(path))
                error('QuadrupedGUIController_v3:MissingPath', 'Missing v3 path: %s', path);
            end
        end
        function files = setFolder(obj, folder)
            folder = obj.confinedPath(folder, true);
            if ~isfolder(V3Path_v3(folder))
                error('QuadrupedGUIController_v3:NotFolder', 'Choose a v3 folder.');
            end
            obj.Folder = folder;
            listing = V3Dir_v3(fullfile(folder, '*.mat'));
            files = {};
            for fileIndex = 1:numel(listing)
                variables = whos('-file', fullfile(listing(fileIndex).folder, listing(fileIndex).name));
                if any(ismember({variables.name}, {'solution','solutions','orbit','branch','study','results'}))
                    files{end + 1} = listing(fileIndex).name;
                end
            end
            % Named continua are the usual entry point; historical evidence
            % remains available after them in the same folder.
            named = ~cellfun('isempty', regexp(files, '^C[0-9]+_[A-Za-z0-9]+_[-+0-9.e]+_[-+0-9.e]+_[-+0-9.e]+\.mat$', 'once'));
            files = [sort(files(named)), sort(files(~named))];
        end
        function index = loadDataset(obj, file, policy)
            if nargin < 3, policy = 'v2-exact'; end
            file = obj.confinedPath(file, true);
            data = load(V3Path_v3(file));
            solutions = obj.extractSolutions(data, policy);
            if isempty(solutions)
                error('QuadrupedGUIController_v3:DatasetFormat', ...
                    'No recognized v3 orbit/solution/branch or explicit results fixture was found.');
            end
            solutions = obj.savedDisplayClassifications(data, solutions);
            [~, name, ext] = fileparts(file);
            [components, ordered, warnings] = obj.extractComponents(data, numel(solutions));
            dataset = struct('name', [name, ext], 'source', file, 'solutions', {solutions}, ...
                'components', components, 'ordered_components', ordered, 'line_warnings', {warnings});
            index = find(strcmp({obj.Datasets.source}, file), 1);
            if isempty(index)
                obj.Datasets(end + 1) = dataset;
                index = numel(obj.Datasets);
            else
                obj.Datasets(index) = dataset;
            end
            obj.select(index, 1);
            obj.Status = sprintf('Loaded %s: %d solutions; imported states require replay.', dataset.name, numel(solutions));
            if ~isempty(warnings), obj.Status = [obj.Status, ' ', strjoin(warnings, ' ')]; end
        end
        function select(obj, dataset, index)
            if dataset < 1 || dataset > numel(obj.Datasets) || ...
                    index < 1 || index > numel(obj.Datasets(dataset).solutions) || index ~= fix(index)
                error('QuadrupedGUIController_v3:Selection', 'Invalid dataset/solution selection.');
            end
            obj.SelectedDataset = dataset;
            obj.SelectedIndex = index;
            obj.Candidate = [];
            obj.SecondSeed = [];
            obj.SecondSeedBase = [];
        end
        function record = selectSeed(obj, source, value)
            % All continuation tabs share the same explicit first seed.
            obj.requireOpen();
            if nargin < 3, value = obj.SelectedIndex; end
            if obj.SelectedDataset == 0
                error('QuadrupedGUIController_v3:NoSelection', 'Select a dataset first.');
            end
            count = numel(obj.Datasets(obj.SelectedDataset).solutions);
            switch char(source)
                case 'Cursor'
                    obj.Candidate = [];
                    record = obj.selected();
                case 'Index input'
                    validateattributes(value, {'numeric'}, {'scalar', 'integer', '>=', 1, '<=', count});
                    if value ~= obj.SelectedIndex, obj.select(obj.SelectedDataset, value);
                    else, obj.Candidate = []; end
                    record = obj.selected();
                case 'Percentage input'
                    validateattributes(value, {'numeric'}, {'scalar', 'finite', '>=', 0, '<=', 100});
                    index = 1 + round((count-1)*value/100);
                    if index ~= obj.SelectedIndex, obj.select(obj.SelectedDataset, index);
                    else, obj.Candidate = []; end
                    record = obj.selected();
                case 'Solver'
                    if isempty(obj.SolvedCandidate) || ~obj.SolvedCandidate.accepted
                        error('QuadrupedGUIController_v3:SolverSeed', 'Solve and validate a candidate before choosing Solver.');
                    end
                    record = obj.SolvedCandidate; obj.Candidate = record;
                otherwise
                    error('QuadrupedGUIController_v3:SeedSource', 'Unknown seed source %s.', char(source));
            end
            if ~isempty(obj.SecondSeedBase) && ...
                    ~(isequal(record.initial_state, obj.SecondSeedBase.initial_state) && ...
                    isequal(record.initial_mode, obj.SecondSeedBase.initial_mode) && ...
                    isequal(record.parameter, obj.SecondSeedBase.parameter))
                obj.SecondSeed = []; obj.SecondSeedBase = [];
            end
        end
        function removeSecondSeed(obj)
            obj.SecondSeed = [];
            obj.SecondSeedBase = [];
            obj.Status = 'Removed the solved second seed.';
        end
        function [first, second] = seedPair(obj)
            first = obj.SecondSeedBase;
            if isempty(first), first = obj.currentSeed(); end
            second = obj.SecondSeed;
        end
        function record = candidate(obj, kind)
            kind=validatestring(kind,{'predicted','solved'});
            if strcmp(kind,'predicted'),record=obj.PredictedCandidate;else,record=obj.SolvedCandidate;end
            if isempty(record)
                error('QuadrupedGUIController_v3:Candidate','No %s candidate is available.',kind);
            end
        end
        function removeCandidate(obj, kind)
            if nargin<2
                obj.Candidate=[];obj.PredictedCandidate=[];obj.SolvedCandidate=[];
                obj.removeCandidateDatasets('predicted');obj.removeCandidateDatasets('solved');
                obj.Status='Removed edited and solved candidates.';return
            end
            kind=validatestring(kind,{'predicted','solved'});
            obj.removeCandidateDatasets(kind);
            if strcmp(kind,'predicted')
                if isequaln(obj.Candidate,obj.PredictedCandidate),obj.Candidate=obj.SolvedCandidate;end
                obj.PredictedCandidate=[];obj.Status='Removed the predicted seed marker and prediction.';
            else
                % The legacy Remove Solved action hides its marker while
                % retaining the solved numerical record for Save/Solver.
                obj.Status='Removed the solved seed marker; the solved solution remains available.';
            end
        end
        function requestClose(obj)
            % The last completed point is already checkpointed. A close
            % request must not start another save while a solver is active.
            obj.Closing = true;
            if ~isempty(fieldnames(obj.Run)) && any(strcmp(obj.Run.status, {'running', 'paused'}))
                obj.Run.status = 'stopped';
                obj.Run.terminal_reason = 'GUI closed; last completed point remains checkpointed';
            end
        end
        function tf = isClosing(obj)
            tf = obj.Closing;
        end
        function remove(obj, index)
            if nargin < 2, index = obj.SelectedDataset; end
            if index == 0, return; end
            source=obj.Datasets(index);
            removePrediction=obj.candidateBelongsTo(obj.PredictedCandidate,source);
            removeSolved=obj.candidateBelongsTo(obj.SolvedCandidate,source);
            obj.Datasets(index) = [];
            obj.SelectedDataset = 0; obj.SelectedIndex = 0;
            obj.Candidate = []; obj.SecondSeed = []; obj.SecondSeedBase = [];
            if removePrediction,obj.PredictedCandidate=[];obj.removeCandidateDatasets('predicted');end
            if removeSolved,obj.SolvedCandidate=[];obj.removeCandidateDatasets('solved');end
            if ~isempty(obj.Datasets), obj.select(1, 1); end
        end
        function removeAll(obj)
            obj.Datasets = struct('name', {}, 'source', {}, 'solutions', {}, 'components', {}, 'ordered_components', {}, 'line_warnings', {});
            obj.SelectedDataset = 0; obj.SelectedIndex = 0;
            obj.Candidate = []; obj.SecondSeed = []; obj.SecondSeedBase = [];
            obj.PredictedCandidate = []; obj.SolvedCandidate = [];
        end
        function record = selected(obj)
            if obj.SelectedDataset == 0
                error('QuadrupedGUIController_v3:NoSelection', 'Select a solution first.');
            end
            record = obj.Datasets(obj.SelectedDataset).solutions{obj.SelectedIndex};
        end
        function mask = filter(obj, dataset, parameterName, value, tolerance)
            if nargin < 5, tolerance = 1e-10; end
            solutions = obj.Datasets(dataset).solutions;
            mask = true(1, numel(solutions));
            if isempty(parameterName) || strcmp(parameterName, '<none>'), return; end
            index = obj.Schema.parameterIndex(parameterName);
            for k = 1:numel(solutions)
                mask(k) = abs(solutions{k}.parameter(index)-value) <= tolerance * max(1, abs(value));
            end
        end
        function segments = lineSegments(obj, dataset, mask)
            % A display line follows one declared ordered component only.
            % Filtering splits that order at hidden records rather than
            % introducing a new edge across a filtered gap.
            count = numel(obj.Datasets(dataset).solutions);
            if nargin < 3, mask = true(1, count); end
            assert(isvector(mask) && numel(mask) == count);
            mask = logical(mask(:).'); segments = struct('component_index', {}, 'record_indices', {});
            for component = obj.Datasets(dataset).ordered_components
                indices = component.record_indices;
                changes = diff([false, mask(indices), false]);
                starts = find(changes == 1); stops = find(changes == -1)-1;
                for k = 1:numel(starts)
                    run = indices(starts(k):stops(k));
                    if numel(run) < 2, continue; end
                    segments(end+1) = struct('component_index', component.component_index, 'record_indices', run); %#ok<AGROW>
                end
            end
        end
        function record = editSeed(obj, state, parameter, mode)
            record = obj.selected();
            record.initial_state = obj.Schema.validateState(state);
            record.parameter = obj.Schema.validateParameter(parameter);
            record.initial_mode = obj.Schema.validateMode(mode);
            record.orbit = []; record.accepted = false;
            record.status = 'edited seed; unvalidated';
            record.provenance.editor = 'SLIP_Quadruped_GUI_v3';
            record=obj.withCandidateSource(record);
            obj.Candidate = record; obj.PredictedCandidate = record;
        end
        function record = perturb(obj, stateAmplitude, parameterAmplitude, seed)
            validateattributes(stateAmplitude, {'numeric'}, {'scalar', 'finite', 'nonnegative'});
            validateattributes(parameterAmplitude, {'numeric'}, {'scalar', 'finite', 'nonnegative'});
            validateattributes(seed, {'numeric'}, {'scalar', 'integer', 'nonnegative'});
            record = obj.currentSeed();
            old = rng; cleanup = onCleanup(@() rng(old));
            rng(seed, 'twister');
            scale = max(1, abs(record.initial_state));
            state = record.initial_state + stateAmplitude .* scale .* randn(obj.Schema.StateDimension, 1);
            state(obj.Schema.TranslationIndex) = 0;
            state(obj.Schema.PhaseIndex) = 0;
            parameter = record.parameter;
            finite = isfinite(parameter);
            parameter(finite) = parameter(finite) + parameterAmplitude .* ...
                max(1, abs(parameter(finite))) .* randn(nnz(finite), 1);
            obj.Schema.validateParameter(parameter); % Invalid perturbations are visible errors.
            record.initial_state = state; record.parameter = parameter;
            record.orbit = []; record.accepted = false;
            record.status = 'perturbed seed; unvalidated';
            record.provenance.rng_seed = seed;
            record=obj.withCandidateSource(record);
            obj.Candidate = record; obj.PredictedCandidate = record;
        end
        function record = predict(obj, multiplier)
            validateattributes(multiplier, {'numeric'}, {'scalar', 'finite'});
            record = obj.currentSeed();
            if isempty(obj.SecondSeed)
                error('QuadrupedGUIController_v3:SecondSeed', 'Validate a second seed before a secant prediction.');
            end
            [first, second] = obj.seedPair();
            record.initial_state = first.initial_state + multiplier .* (second.initial_state-first.initial_state);
            record.initial_state(obj.Schema.TranslationIndex) = 0;
            record.initial_state(obj.Schema.PhaseIndex) = 0;
            record.orbit = []; record.accepted = false; record.status = 'secant prediction; unvalidated';
            record=obj.withCandidateSource(record);
            obj.Candidate = record; obj.PredictedCandidate = record;
        end
        function record = replay(obj, record)
            if nargin < 2, record = obj.currentSeed(); end
            obj.requireOpen();
            framework = obj.framework(record);
            u = framework.residual.packState(record.initial_state);
            try
                [residual, details] = framework.residual.evaluateWithInfo(u, record.parameter, record.initial_mode);
            catch exception
                % Integration layers retain their diagnostic wrapper. A
                % user close remains a GUI cancellation at this boundary.
                obj.requireOpen();
                rethrow(exception);
            end
            obj.requireOpen();
            record.orbit = framework.residual.createOrbit(u, record.parameter, record.initial_mode, details);
            record.return_policy_name = char(record.orbit.return_policy_name);
            if isfield(record.orbit.section_chart, 'BL_touchdowns_per_return')
                record.BL_touchdowns_per_return = record.orbit.section_chart.BL_touchdowns_per_return;
            end
            record.residual = residual;
            scale = max(1, abs(record.initial_state));
            raw = details.next_state-details.section_state;
            raw(obj.Schema.TranslationIndex) = 0;
            record.scaled_residual = raw ./ scale;
            record.residual_norm = norm(record.scaled_residual, Inf);
            record.accepted = record.residual_norm <= obj.AcceptanceTolerance && details.admissible && ...
                details.discrete_closed && details.cycle_complete;
            record.validation = details;
            if record.accepted, record.status = 'accepted forward replay';
            else, record.status = 'replayed; closure/admissibility acceptance failed'; end
            record.classification = GaitIdentification_v3(record.orbit);
            obj.Status = sprintf('%s; scaled full residual %.3e.', record.status, record.residual_norm);
        end
        function record = presentationRecord(obj, record)
            % Viewing stored trajectories does not certify numerical
            % acceptance. Edited states without an orbit require a replay.
            if nargin < 2, record = obj.currentSeed(); end
            obj.requireOpen();
            if ~obj.hasCompleteTrajectory(record)
                record = obj.replay(record);
                if ~record.accepted
                    error('QuadrupedGUIController_v3:VisualizationAcceptance', ...
                        'This seed has no stored complete trajectory and failed fresh replay.');
                end
            end
            if isempty(fieldnames(record.classification))
                record.classification = GaitIdentification_v3(record.orbit);
            end
        end
        function [color, classification] = gaitColor(obj, record)
            if nargin < 2, record = obj.currentSeed(); end
            classification = record.classification;
            if isempty(fieldnames(classification)) && ~isempty(record.orbit) && ...
                    isstruct(record.orbit.gait_identification) && ~isempty(fieldnames(record.orbit.gait_identification))
                classification = record.orbit.gait_identification;
            end
            if isempty(fieldnames(classification)) && obj.hasCompleteTrajectory(record)
                classification = GaitIdentification_v3(record.orbit);
            end
            mapping = GaitSemanticTable_v3();
            label = "unclassified";
            if isstruct(classification) && isfield(classification, 'label')
                label = string(classification.label);
            end
            row = find(mapping.label == label, 1);
            if isempty(row), row = find(mapping.label == "unclassified", 1); end
            color = mapping.color(row, :);
        end
        function colors = gaitColors(obj, dataset)
            if nargin < 2, dataset = obj.SelectedDataset; end
            obj.requireOpen();
            records = obj.Datasets(dataset).solutions;
            colors = zeros(numel(records), 3);
            for k = 1:numel(records)
                obj.requireOpen();
                [colors(k, :), classification] = obj.gaitColor(records{k});
                % Classify unfamiliar imports once, keeping the result only
                % in this GUI's memory. Canonical publications already carry
                % the matching descriptive classification in branch.records.
                obj.Datasets(dataset).solutions{k}.classification = classification;
                if mod(k, 16) == 0
                    drawnow limitrate;
                    obj.requireOpen();
                end
            end
        end
        function record = inspect(obj)
            record = obj.replay(obj.selected());
            obj.Datasets(obj.SelectedDataset).solutions{obj.SelectedIndex} = record;
        end
        function record = correct(obj, record, scope)
            obj.requireOpen();
            if nargin < 2, record = obj.currentSeed(); end
            if nargin < 3, symmetry=obj.CorrectionSymmetry;else,symmetry=obj.scopeSymmetry(scope);end
            record=obj.correctRecord(record,symmetry,obj.SolverOptions);
            record=obj.withCandidateSource(record);obj.Candidate=record;
            if record.accepted,obj.SolvedCandidate=record;end
        end
        function record = secondSeed(obj, radius, scope)
            obj.requireOpen();
            obj.LastNumericalFailure=struct();
            if nargin < 3, scope = 'full'; end
            validateattributes(radius, {'numeric'}, {'scalar', 'finite', 'positive'});
            first = obj.replay(obj.currentSeed());
            if ~first.accepted
                error('QuadrupedGUIController_v3:UnacceptedSeed', 'The first seed must pass independent replay.');
            end
            if exist(V3Path_v3('FixedParameterContinuation_v3'), 'file') ~= 2
                error('QuadrupedGUIController_v3:FamilyService', 'Shared fixed-parameter family service is unavailable.');
            end
            framework = obj.framework(first);
            symmetry = obj.scopeSymmetry(scope);
            options = struct('Symmetry', symmetry, 'SolverOptions', obj.solverOptionsFor(first,framework,obj.SolverOptions));
            if isfield(obj.SolverOptions, 'MaxWallSeconds')
                options.MaxWallSeconds = obj.SolverOptions.MaxWallSeconds;
            end
            [orbit, report] = FixedParameterContinuation_v3.secondSeed(framework.residual, ...
                framework.residual.packState(first.initial_state), first.parameter, first.initial_mode, radius, options);
            obj.requireOpen();
            if isempty(orbit) || ~report.converged
                obj.LastNumericalFailure=struct('action','second-seed','report',report,'source_state',first.initial_state, ...
                    'parameter',first.parameter,'scope',scope,'radius',radius);
                error('QuadrupedGUIController_v3:SecondSeedFailure', 'No accepted second seed: %s', report.message);
            end
            record = obj.normalize(orbit);
            record = obj.replay(record);
            if ~record.accepted
                error('QuadrupedGUIController_v3:SecondSeedReplay', 'Second seed failed independent replay.');
            end
            distance = report.actual_scaled_distance;
            record.provenance.distance_coordinates = report.distance_coordinates;
            record.provenance.distance_scale = report.scale;
            if abs(distance-radius) > max(1e-7, radius*1e-3)
                error('QuadrupedGUIController_v3:SecondSeedRadius', ...
                    'Accepted second seed distance %.12g differs from target %.12g.', distance, radius);
            end
            record.provenance.scaled_state_distance = distance;
            record.provenance.target_scaled_state_distance = radius;
            record.solver_info=report;
            obj.SecondSeedBase = first;
            obj.SecondSeed = record;
            obj.Status = sprintf('Validated second seed at scaled physical-state distance %.6g.', distance);
        end
        function record = analyzeFloquet(obj, scope)
            if nargin < 2, scope = 'full'; end
            record = obj.replay(obj.currentSeed());
            if ~record.accepted
                error('QuadrupedGUIController_v3:UnacceptedOrbit', 'Floquet analysis requires accepted forward replay.');
            end
            framework = obj.framework(record);
            analyzer = FloquetAnalysis_v3();
            options = struct();
            if strcmp(scope, 'left/right')
                schema = obj.Schema;
                invariant = SymmetrySubspace_v3.quadrupedSectionTangent(schema);
                restricted = SymmetryRestrictedFloquet_v3(invariant, struct('BlockName', 'left/right'));
                result = restricted.analyze(framework.map, record.initial_state, record.initial_mode, record.parameter, options);
            elseif strcmp(scope, 'pronk')
                family = EnergyFamilyResidual_v3(framework.residual, record.initial_state, ...
                    record.initial_mode, record.parameter, struct('Symmetry', 'pronk'));
                [physicalBasis, ~] = QuadrupedPhysicalChart_v3.tangentBasis(family.Chart);
                [~, columns] = ismember(family.CoordinateIndices, family.Chart.independent_indices);
                basis = physicalBasis(:, columns);
                for j = 1:numel(family.CoordinateIndices)
                    if family.CoordinateIndices(j) == obj.Schema.Leg.AngleIndices(1)
                        basis(obj.Schema.Leg.AngleIndices, j) = 1;
                    elseif family.CoordinateIndices(j) == obj.Schema.Leg.RateIndices(1)
                        basis(obj.Schema.Leg.RateIndices, j) = 1;
                    end
                end
                options.TangentBasis = basis;
                result = analyzer.analyze(framework.map, record.initial_state, record.initial_mode, record.parameter, options);
                result.symmetryRestricted = true; result.symmetryBlock = 'pronk-invariant-section';
                result.derivative_model = 'pronk-restricted-classical';
            else
                result = analyzer.analyze(framework.map, record.initial_state, record.initial_mode, record.parameter, options);
            end
            record.stability = result;
            record.orbit.setFloquetResult(result);
            obj.Candidate = record;
            obj.Datasets(obj.SelectedDataset).solutions{obj.SelectedIndex} = record;
            obj.Status = sprintf('Floquet scope %s; reliable=%d. A multiplier candidate alone is not a branch certificate.', scope, result.reliable);
        end
        function events = bifurcationDiagnostics(obj, dataset)
            if nargin < 2, dataset = obj.SelectedDataset; end
            records = obj.Datasets(dataset).solutions;
            data = struct('stability', {{}}, 'cyclic_signature', {{}}, ...
                'section_relative_signature', {{}}, 'event_cluster_signature', {{}}, ...
                'return_multiplicity', [], 'topology_boundary', []);
            scopes = {};
            for k = 1:numel(records)
                record = records{k};
                if record.accepted && isfield(record.stability, 'multipliers') && ~isempty(record.orbit)
                    data.stability{end + 1} = record.stability;
                    data.cyclic_signature{end + 1} = char(record.orbit.cyclic_event_signature);
                    data.section_relative_signature{end + 1} = char(record.orbit.section_relative_event_signature);
                    data.event_cluster_signature{end + 1} = char(record.orbit.event_cluster_signature);
                    data.return_multiplicity(end + 1) = record.orbit.return_multiplicity;
                    data.topology_boundary(end + 1) = record.orbit.section_cluster_coincidence || ~isempty(record.orbit.section_coincident_events);
                    if isfield(record.stability, 'symmetryBlock'), scopes{end + 1} = record.stability.symmetryBlock;
                    else, scopes{end + 1} = 'full'; end
                end
            end
            if numel(data.stability) < 2
                error('QuadrupedGUIController_v3:BifurcationSeries', 'Analyze at least two compatible accepted points.');
            end
            if numel(unique(scopes)) ~= 1
                error('QuadrupedGUIController_v3:BifurcationScope', 'Compare spectra from the same physical/symmetry chart.');
            end
            detector = BifurcationDetector_v3();
            events = detector.detect(data);
        end
        function index = plotCandidate(obj, name, kind)
            if nargin < 2, name = 'Solved seed'; end
            if nargin<3
                % Retain compatibility with unowned transient comparison
                % plots. Explicit kind identifies only GUI-owned markers.
                record=obj.currentSeed();
                if isfield(record.provenance,'gui_candidate_kind'),record.provenance=rmfield(record.provenance,'gui_candidate_kind');end
            else
                kind=validatestring(kind,{'predicted','solved'});record=obj.candidate(kind);
                obj.removeCandidateDatasets(kind);record.provenance.gui_candidate_kind=kind;
            end
            index = numel(obj.Datasets) + 1;
            obj.Datasets(index) = struct('name', name, 'source', '', 'solutions', {{record}}, ...
                'components', struct([]), 'ordered_components', struct('component_index', {}, 'record_indices', {}), ...
                'line_warnings', {{}});
        end
        function file = saveSolution(obj, file, kind)
            if nargin<3,solution=obj.currentSeed();else,solution=obj.candidate(kind);end
            if ~solution.accepted
                error('QuadrupedGUIController_v3:SaveUnaccepted', 'Correct and validate the solution before saving.');
            end
            file = obj.prepareOutput(file);
            solution = obj.compactRecord(solution);
            schema_metadata = obj.Schema.metadata();
            % Compressed MAT v7 avoids HDF5 overhead for the many small
            % diagnostic structures while preserving all numerical values.
            save(V3Path_v3(file), 'solution', 'schema_metadata', '-v7');
            obj.Status = ['Saved accepted solution: ', file];
        end
        function startRun(obj, kind, parameter1, values1, parameter2, values2, options)
            if nargin < 7, options = struct(); end
            obj.requireOpen();
            if ~isempty(fieldnames(obj.Run)) && strcmp(obj.Run.status, 'running')
                error('QuadrupedGUIController_v3:Busy', 'Pause or stop the active run first.');
            end
            kind = validatestring(kind, {'fixed', 'parameter', 'scan', 'family-scan'});
            if strcmp(kind,'family-scan')
                [first,second]=obj.seedPair();
                if isempty(second),error('QuadrupedGUIController_v3:ScanSeedPair','Solve and validate a second seed before a family scan.');end
                first=obj.replay(first);second=obj.replay(second);
                obj.validateScanPair(first,second,[]);seed=first;
            else
                seed = obj.replay(obj.currentSeed());
            end
            if ~seed.accepted, error('QuadrupedGUIController_v3:Seed', 'Run requires an accepted seed.'); end
            defaults = struct('Checkpoint', fullfile(obj.Root, 'GUI_v3', 'Outputs_v3', 'gui-partial.mat'), ...
                'MaxPoints', 10, 'StepSize', 0.01, 'Scope', 'full', 'Radius', []);
            names = fieldnames(options);
            for k = 1:numel(names)
                if ~isfield(defaults, names{k}), error('QuadrupedGUIController_v3:RunOption', 'Unknown run option %s.', names{k}); end
                defaults.(names{k}) = options.(names{k});
            end
            obj.prepareOutput(defaults.Checkpoint);
            validateattributes(defaults.MaxPoints, {'numeric'}, {'scalar','finite','integer','>=',1});
            validateattributes(defaults.StepSize, {'numeric'}, {'scalar','finite','positive'});
            if ~strcmp(kind, 'fixed')
                obj.Schema.parameterIndex(parameter1);
                validateattributes(values1, {'numeric'}, {'vector', 'finite', 'nonempty'});
                if strcmp(kind, 'scan')
                    obj.Schema.parameterIndex(parameter2);
                    if strcmp(parameter1, parameter2), error('QuadrupedGUIController_v3:ScanAxes', 'Use two different parameters.'); end
                    validateattributes(values2, {'numeric'}, {'vector', 'finite', 'nonempty'});
                    [a, b] = ndgrid(values1(:), values2(:)); queue = [a(:), b(:)];
                else
                    queue = [values1(:), zeros(numel(values1), 1)];
                end
            else
                queue = [(1:defaults.MaxPoints).', zeros(defaults.MaxPoints, 1)];
            end
            if strcmp(kind,'family-scan')
                validateattributes(defaults.MaxPoints, {'numeric'}, {'scalar','finite','integer','>=',2});
                for target=values1(:).'
                    p=first.parameter;p(obj.Schema.parameterIndex(parameter1))=target;obj.Schema.validateParameter(p);
                end
                distance=obj.scanPairDistance(first,second,defaults.Scope);
                if isempty(defaults.Radius),defaults.Radius=distance;end
                validateattributes(defaults.Radius,{'numeric'},{'scalar','finite','positive'});
                scan=struct('source_pair',{{first,second}},'working_pair',{{first,second}}, ...
                    'target_pairs',{cell(1,size(queue,1))},'expected_label',char(first.classification.label), ...
                    'stage','target','trial_first',[],'trial_value',NaN,'transport_step',0, ...
                    'minimum_transport_step',0,'transport_attempts',0,'target_transport_history',struct('parameter',{},'step',{},'accepted',{},'identifier',{},'reason',{}), ...
                    'target_value',NaN,'direction',1,'component_index',0,'branch_seed',[], ...
                    'initial_tangent',[],'next_tangent',[],'radius',defaults.Radius);
            end
            obj.Run = struct('kind', kind, 'status', 'running', 'queue', queue, 'next', 1, ...
                'parameter1', parameter1, 'parameter2', parameter2, 'seed', seed, ...
                'accepted', {{}}, 'rejected', {{}}, 'options', defaults, ...
                'family_energy', QuadrupedEnergy_v3.evaluate(seed.initial_state, seed.initial_mode, seed.parameter), ...
                'next_tangent', [], 'solver_options', obj.SolverOptions, 'terminal_reason', '', 'started_at', char(datetime('now')));
            if strcmp(kind,'family-scan')
                obj.Run.branches=struct('target_index',{},'target_value',{},'parameter',{},'direction',{},'record_indices',{},'status',{},'terminal_reason',{});
                obj.Run.family_scan=scan;
            end
            obj.checkpoint();
            obj.Status = sprintf('%s run started: %d points.', kind, size(queue, 1));
        end
        function stepRun(obj)
            if obj.Closing || isempty(fieldnames(obj.Run)) || ~strcmp(obj.Run.status, 'running'), return; end
            if strcmp(obj.Run.kind,'family-scan'),obj.stepFamilyScan();return;end
            k = obj.Run.next;
            if k > size(obj.Run.queue, 1)
                obj.Run.status = 'complete'; obj.Run.terminal_reason = 'requested point budget exhausted';
                obj.checkpoint(); obj.Status = 'Requested run completed; no global branch completeness is implied.'; return
            end
            seed = obj.Run.seed;
            try
                if strcmp(obj.Run.kind, 'fixed')
                    framework = obj.framework(seed);
                    solverOptions=obj.solverOptionsFor(seed,framework,obj.Run.solver_options);
                    settings = struct('MaxPoints', 2, 'StepSize', obj.Run.options.StepSize, ...
                        'Symmetry', obj.scopeSymmetry(obj.Run.options.Scope), ...
                        'RootSolver', RootSolver_v3(solverOptions));
                    if isfield(solverOptions,'Jacobian'),settings.Jacobian=solverOptions.Jacobian;end
                    if ~isempty(obj.Run.next_tangent), settings.InitialTangent = obj.Run.next_tangent; end
                    branch = FixedParameterContinuation_v3.run(framework.residual, ...
                        framework.residual.packState(seed.initial_state), seed.parameter, seed.initial_mode, settings);
                    if branch.count < 2, error('QuadrupedGUIController_v3:FixedStep', '%s', branch.terminationReason); end
                    record = obj.recordFromPoint(branch.points(2));
                    obj.Run.next_tangent = branch.points(2).tangent;
                else
                    p = seed.parameter;
                    p(obj.Schema.parameterIndex(obj.Run.parameter1)) = obj.Run.queue(k, 1);
                    if strcmp(obj.Run.kind, 'scan')
                        p(obj.Schema.parameterIndex(obj.Run.parameter2)) = obj.Run.queue(k, 2);
                    end
                    obj.Schema.validateParameter(p);
                    gridSeed = seed; gridSeed.parameter = p;
                    framework = obj.framework(gridSeed);
                    [problem, u] = obj.correctionProblem(framework, gridSeed, obj.scopeSymmetry(obj.Run.options.Scope));
                    augmented = [p(:); obj.Run.family_energy];
                    solverOptions=obj.solverOptionsFor(gridSeed,framework,obj.Run.solver_options);
                    service = NumericalContinuation1D_v3(struct('RootSolver', RootSolver_v3(solverOptions), ...
                        'ActiveParameter', obj.Run.parameter1));
                    branch = service.run(problem, u, augmented, seed.initial_mode, p(obj.Schema.parameterIndex(obj.Run.parameter1)));
                    if branch.count == 0, error('QuadrupedGUIController_v3:GridCorrection', 'Point correction failed.'); end
                    record = obj.recordFromPoint(branch.points(end));
                end
                if obj.Closing, return; end
                record = obj.replay(record);
                if ~record.accepted, error('QuadrupedGUIController_v3:PointReplay', 'Point failed independent closure/admissibility replay.'); end
                record.provenance.gui_queue_index = k;
                record.provenance.gui_queue_values = obj.Run.queue(k, :);
                obj.Run.accepted{end + 1} = record;
                obj.Run.seed = record;
                obj.Candidate = record;
                obj.Status = sprintf('%s: point %d/%d accepted; residual %.3e.', obj.Run.kind, k, size(obj.Run.queue, 1), record.residual_norm);
            catch exception
                if obj.Closing, return; end
                obj.Run.rejected{end + 1} = struct('queue_index', k, 'values', obj.Run.queue(k, :), ...
                    'identifier', exception.identifier, 'reason', exception.message);
                obj.Status = sprintf('Point %d rejected: %s', k, exception.message);
                if strcmp(obj.Run.kind, 'fixed')
                    obj.Run.status = 'failed'; obj.Run.terminal_reason = exception.message;
                end
            end
            if obj.Closing, return; end
            obj.Run.next = k + 1;
            obj.checkpoint();
        end
        function pauseRun(obj)
            if ~isempty(fieldnames(obj.Run)) && strcmp(obj.Run.status, 'running')
                obj.Run.status = 'paused'; obj.Run.terminal_reason = 'user pause at point boundary'; obj.checkpoint();
            end
        end
        function resumeRun(obj, file)
            obj.requireOpen();
            if nargin > 1 && ~isempty(file)
                file = obj.confinedPath(file, true);
                loaded = load(V3Path_v3(file), 'gui_run');
                if ~isfield(loaded, 'gui_run'), error('QuadrupedGUIController_v3:CheckpointFormat', 'Missing gui_run.'); end
                obj.Run = loaded.gui_run;
                % Resume the file the user chose, including a copied audit
                % checkpoint, rather than overwriting its historical source.
                obj.Run.options.Checkpoint = file;
                obj.SolverOptions = obj.Run.solver_options;
                if strcmp(obj.Run.kind,'family-scan')
                    scan=obj.Run.family_scan;
                    for key={'source_pair','working_pair'}
                        pair=scan.(key{1});
                        for seedIndex=1:2,pair{seedIndex}=obj.replay(obj.normalize(pair{seedIndex}));end
                        obj.validateScanPair(pair{1},pair{2},scan.expected_label);scan.(key{1})=pair;
                    end
                    for key={'trial_first','branch_seed'}
                        if ~isempty(scan.(key{1})),scan.(key{1})=obj.replay(obj.normalize(scan.(key{1})));obj.requireScanRecord(scan.(key{1}),[]);end
                    end
                    obj.Run.family_scan=scan;
                    obj.SecondSeedBase=scan.source_pair{1};obj.SecondSeed=scan.source_pair{2};
                end
            end
            if isempty(fieldnames(obj.Run)), error('QuadrupedGUIController_v3:NoRun', 'No partial run to resume.'); end
            obj.Run.status = 'running'; obj.Run.terminal_reason = ''; obj.checkpoint();
        end
        function stopRun(obj)
            if ~isempty(fieldnames(obj.Run)) && any(strcmp(obj.Run.status, {'running', 'paused'}))
                obj.Run.status = 'stopped'; obj.Run.terminal_reason = 'user stop at point boundary'; obj.checkpoint();
            end
        end
        function plotRun(obj)
            if isempty(fieldnames(obj.Run)) || isempty(obj.Run.accepted)
                error('QuadrupedGUIController_v3:NoAcceptedRun', 'No accepted partial results.');
            end
            components = struct('record_indices', {}, 'record_kind', {}); ordered = struct('component_index', {}, 'record_indices', {});
            if strcmp(obj.Run.kind,'family-scan')
                for k=1:numel(obj.Run.branches)
                    indices=obj.Run.branches(k).record_indices;
                    components(k)=struct('record_indices',indices,'record_kind','ordered_gui_family_scan_continuation');
                    ordered(k)=struct('component_index',k,'record_indices',indices);
                end
            elseif any(strcmp(obj.Run.kind, {'fixed', 'parameter'}))
                queue = NaN(1, numel(obj.Run.accepted));
                for k = 1:numel(queue)
                    record = obj.Run.accepted{k};
                    if isfield(record.provenance, 'gui_queue_index'), queue(k) = record.provenance.gui_queue_index; end
                end
                if all(isfinite(queue))
                    starts = [1, find(diff(queue) ~= 1)+1]; stops = [starts(2:end)-1, numel(queue)];
                    for k = 1:numel(starts)
                        indices = starts(k):stops(k);
                        components(k) = struct('record_indices', indices, ...
                            'record_kind', ['ordered_gui_', obj.Run.kind, '_continuation']);
                        ordered(k) = struct('component_index', k, 'record_indices', indices);
                    end
                end
            end
            obj.Datasets(end + 1) = struct('name', [obj.Run.kind, ' partial results'], ...
                'source', obj.Run.options.Checkpoint, 'solutions', {obj.Run.accepted}, ...
                'components', components, 'ordered_components', ordered, 'line_warnings', {{}});
            obj.select(numel(obj.Datasets), 1);
        end
        function frames = frames(obj, strides, preserveEvents, record)
            if nargin < 2, strides = 1; end
            if nargin < 3, preserveEvents = true; end
            validateattributes(strides, {'numeric'}, {'scalar', 'integer', 'positive'});
            if nargin < 4, record = obj.presentationRecord();
            else, record = obj.presentationRecord(record); end
            [one, report] = ResampleHybridTrajectory_v3(record.orbit.trajectory, 'FrameRate', 25, 'PreserveEventFrames', preserveEvents);
            frames = one; frames.resampling_report = report;
            frames.time = []; frames.state = []; frames.mode = [];
            drift = record.orbit.stride_displacement(obj.Schema.TranslationIndex);
            for k = 0:strides-1
                x = one.state; x(:, obj.Schema.TranslationIndex) = x(:, obj.Schema.TranslationIndex) + k*drift;
                frames.time = [frames.time; one.time+k*record.orbit.period];
                frames.state = [frames.state; x];
                frames.mode = [frames.mode; one.mode];
            end
            frames.strides = strides; frames.primitive_classification = record.classification;
        end
        function file = prepareOutput(obj, file)
            file = obj.confinedPath(file);
            parent = fileparts(file);
            if ~isfolder(V3Path_v3(parent)), mkdir(V3Path_v3(parent)); end
        end
    end
    methods (Access = private)
        function record = correctRecord(obj, record, symmetry, solverOptions)
            obj.requireOpen();
            framework = obj.framework(record);
            [problem, u, augmented] = obj.correctionProblem(framework, record, symmetry);
            solverOptions=obj.solverOptionsFor(record,framework,solverOptions);
            seed=struct('state',record.initial_state,'mode',record.initial_mode, ...
                'parameter',record.parameter,'return_policy',framework.map.ReturnPolicy, ...
                'occurrence',1,'provenance',record.provenance);
            if isa(framework.map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3')
                seed.occurrence=framework.map.ReturnPolicy.BLTouchdownsPerReturn;
            end
            options=struct('Residual',problem,'Coordinates',u, ...
                'AugmentedParameter',augmented,'SolverOptions',solverOptions, ...
                'Acceptance',struct('FullClosureTolerance',obj.AcceptanceTolerance));
            if isfield(solverOptions, 'MaxWallSeconds')
                options.MaxWallSeconds = solverOptions.MaxWallSeconds;
            end
            [orbit,report]=PeriodicSolutionSolver_v3(seed,options);
            obj.requireOpen();
            record.solver_info=report.solver;
            record.validation=report;
            if ~report.accepted
                message='fresh correction/replay acceptance failed';
                if isfield(report.solver,'message'),message=report.solver.message;end
                if isfield(report.primary_failure,'message'),message=report.primary_failure.message;end
                if isfield(report.replay_failure,'message'),message=report.replay_failure.message;end
                record.initial_state=report.final_candidate;
                record.accepted = false; record.status = ['correction failed: ', message];
                obj.Status = record.status;
                return
            end
            record.initial_state=orbit.initial_state;record.initial_mode=orbit.initial_mode;
            record.orbit=orbit;record.return_policy_name=char(orbit.return_policy_name);
            record.residual=report.full_closure_residual;
            record.scaled_residual=record.residual./max(1,abs(record.initial_state));
            record.residual_norm=norm(record.scaled_residual,inf);
            record.accepted=true;record.classification=report.classification;
            record.status='corrected and independently replayed by shared periodic service';
            obj.Status=sprintf('%s; full closure %.3e.',record.status,report.full_closure);
        end
        function record=withCandidateSource(obj,record)
            if isfield(record.provenance,'gui_candidate_source'),return;end
            if obj.SelectedDataset>0
                source=obj.Datasets(obj.SelectedDataset);
                record.provenance.gui_candidate_source=source.source;
                record.provenance.gui_candidate_source_name=source.name;
            end
        end
        function tf=candidateBelongsTo(~,record,source)
            tf=false;if isempty(record)||~isfield(record.provenance,'gui_candidate_source'),return;end
            key=record.provenance.gui_candidate_source;
            if ~isempty(key),tf=strcmp(key,source.source);
            elseif isempty(source.source)&&isfield(record.provenance,'gui_candidate_source_name')
                tf=strcmp(record.provenance.gui_candidate_source_name,source.name);
            end
        end
        function removeCandidateDatasets(obj,kind)
            owned=false(1,numel(obj.Datasets));
            for k=1:numel(owned)
                data=obj.Datasets(k);
                if ~isempty(data.source)||numel(data.solutions)~=1,continue;end
                provenance=data.solutions{1}.provenance;
                owned(k)=isfield(provenance,'gui_candidate_kind')&&strcmp(provenance.gui_candidate_kind,kind);
            end
            indices=find(owned);if isempty(indices),return;end
            selected=obj.SelectedDataset;obj.Datasets(indices)=[];
            if selected>0&&owned(selected)
                if isempty(obj.Datasets),obj.SelectedDataset=0;obj.SelectedIndex=0;
                else,obj.SelectedDataset=1;obj.SelectedIndex=1;end
            else
                obj.SelectedDataset=selected-sum(indices<selected);
            end
        end
        function stepFamilyScan(obj)
            % The legacy 2D workflow is a family of 1D branches, with one
            % physical parameter fixed at each target. One numerical action
            % is taken per tick; only independently replayed records enter
            % the displayed branches and the checkpointed accepted list.
            k=obj.Run.next;scan=obj.Run.family_scan;
            if k>size(obj.Run.queue,1)
                obj.Run.status='complete';obj.Run.terminal_reason='requested parameter targets exhausted';
                obj.Status='Family scan finished; retained target/direction failures remain explicit.';obj.checkpoint();return
            end
            parameterIndex=obj.Schema.parameterIndex(obj.Run.parameter1);
            try
                switch scan.stage
                    case 'target'
                        scan.target_value=obj.Run.queue(k,1);pairs=[{scan.source_pair},scan.target_pairs];
                        distances=Inf(size(pairs));
                        for j=1:numel(pairs)
                            if ~isempty(pairs{j}),distances(j)=abs(pairs{j}{1}.parameter(parameterIndex)-scan.target_value);end
                        end
                        [~,nearest]=min(distances);scan.working_pair=pairs{nearest};
                        for seedIndex=1:2,scan.working_pair{seedIndex}=obj.replay(scan.working_pair{seedIndex});end
                        obj.validateScanPair(scan.working_pair{1},scan.working_pair{2},scan.expected_label);
                        span=abs(scan.target_value-scan.working_pair{1}.parameter(parameterIndex));
                        scan.transport_step=span/4;scan.minimum_transport_step=max(1e-10*max(1,abs(scan.target_value)),span*1e-4);
                        scan.transport_attempts=0;scan.target_transport_history=struct('parameter',{},'step',{},'accepted',{},'identifier',{},'reason',{});scan.trial_first=[];
                        if span<=scan.minimum_transport_step,scan.stage='radius';else,scan.stage='transport-first';end
                        obj.Status=sprintf('Family target %d/%d: %s=%.12g; transporting the validated seed pair.',k,size(obj.Run.queue,1),obj.Run.parameter1,scan.target_value);
                    case 'transport-first'
                        if scan.transport_attempts>=24,error('QuadrupedGUIController_v3:ScanTransportLimit','Adaptive pair transport exceeded 24 attempts.');end
                        current=scan.working_pair{1}.parameter(parameterIndex);remaining=abs(scan.target_value-current);
                        scan.trial_value=current+sign(scan.target_value-current)*min(scan.transport_step,remaining);
                        if remaining<=scan.transport_step*(1+1e-12),scan.trial_value=scan.target_value;end
                        scan.transport_attempts=scan.transport_attempts+1;
                        trial=scan.working_pair{1};trial.parameter(parameterIndex)=scan.trial_value;trial.orbit=[];trial.accepted=false;
                        scan.trial_first=obj.correctRecord(trial,obj.scopeSymmetry(obj.Run.options.Scope),obj.Run.solver_options);obj.requireScanRecord(scan.trial_first,scan.expected_label);
                        scan.stage='transport-second';obj.Status=sprintf('First seed transported to %s=%.12g; correcting its partner.',obj.Run.parameter1,scan.trial_value);
                    case 'transport-second'
                        trial=scan.working_pair{2};trial.parameter(parameterIndex)=scan.trial_value;trial.orbit=[];trial.accepted=false;
                        second=obj.correctRecord(trial,obj.scopeSymmetry(obj.Run.options.Scope),obj.Run.solver_options);obj.validateScanPair(scan.trial_first,second,scan.expected_label);
                        scan.working_pair={scan.trial_first,second};scan.trial_first=[];
                        history=struct('parameter',scan.trial_value,'step',scan.transport_step,'accepted',true,'identifier','','reason','');
                        scan.target_transport_history(end+1)=history;
                        remaining=abs(scan.target_value-scan.trial_value);
                        if remaining<=scan.minimum_transport_step,scan.stage='radius';
                        else,scan.transport_step=min(1.5*scan.transport_step,remaining);scan.stage='transport-first';end
                        obj.Status=sprintf('Validated seed pair transported to %s=%.12g.',obj.Run.parameter1,scan.trial_value);
                    case 'radius'
                        first=scan.working_pair{1};second=scan.working_pair{2};
                        distance=obj.scanPairDistance(first,second,obj.Run.options.Scope);
                        tolerance=max(1e-7,scan.radius*1e-3);
                        if abs(distance-scan.radius)>tolerance
                            framework=obj.framework(first);symmetry=obj.scopeSymmetry(obj.Run.options.Scope);
                            family=EnergyFamilyResidual_v3(framework.residual,first.initial_state,first.initial_mode,first.parameter,struct('Symmetry',symmetry));
                            direction=family.packState(second.initial_state)-family.packState(first.initial_state);
                            settings=struct('Symmetry',symmetry,'Direction',direction,'SolverOptions',obj.solverOptionsFor(first,framework,obj.Run.solver_options));
                            if isfield(obj.Run.solver_options,'MaxWallSeconds'),settings.MaxWallSeconds=obj.Run.solver_options.MaxWallSeconds;end
                            [orbit,report]=FixedParameterContinuation_v3.secondSeed(framework.residual,framework.residual.packState(first.initial_state),first.parameter,first.initial_mode,scan.radius,settings);
                            obj.requireOpen();
                            if isempty(orbit)||~report.converged,error('QuadrupedGUIController_v3:ScanRadius','Target radius correction failed: %s',report.message);end
                            second=obj.replay(obj.normalize(orbit));obj.validateScanPair(first,second,scan.expected_label);
                            distance=obj.scanPairDistance(first,second,obj.Run.options.Scope);
                        end
                        if abs(distance-scan.radius)>tolerance,error('QuadrupedGUIController_v3:ScanRadius','Target pair does not satisfy the requested physical-state radius.');end
                        scan.working_pair={first,second};scan.target_pairs{k}=scan.working_pair;
                        first=obj.annotateScanRecord(first,k,1);second=obj.annotateScanRecord(second,k,1);
                        base=numel(obj.Run.accepted);obj.Run.accepted(end+1:end+2)={first,second};
                        component=struct('target_index',k,'target_value',scan.target_value,'parameter',obj.Run.parameter1,'direction',1, ...
                            'record_indices',base+[1 2],'status','running','terminal_reason','');
                        obj.Run.branches(end+1)=component;scan.component_index=numel(obj.Run.branches);
                        framework=obj.framework(first);family=EnergyFamilyResidual_v3(framework.residual,first.initial_state,first.initial_mode,first.parameter,struct('Symmetry',obj.scopeSymmetry(obj.Run.options.Scope)));
                        energy1=QuadrupedEnergy_v3.evaluate(first.initial_state,first.initial_mode,first.parameter);
                        energy2=QuadrupedEnergy_v3.evaluate(second.initial_state,second.initial_mode,second.parameter);
                        scan.initial_tangent=[family.packState(second.initial_state)-family.packState(first.initial_state);energy2-energy1];
                        if norm(scan.initial_tangent)==0,error('QuadrupedGUIController_v3:ScanSecant','The validated target pair has a zero family secant.');end
                        scan.next_tangent=scan.initial_tangent;scan.branch_seed=second;scan.direction=1;scan.stage='branch';
                        obj.Run.seed=second;obj.Candidate=second;
                        obj.Status=sprintf('Target %d pair validated at radius %.6g; starting fixed-parameter continuation.',k,distance);
                    case 'branch'
                        component=scan.component_index;
                        if numel(obj.Run.branches(component).record_indices)>=obj.Run.options.MaxPoints
                            obj.Run.branches(component).status='complete';obj.Run.branches(component).terminal_reason='requested direction point budget exhausted';
                            scan=obj.advanceScanDirection(scan);
                        else
                            seed=scan.branch_seed;framework=obj.framework(seed);
                            solverOptions=obj.solverOptionsFor(seed,framework,obj.Run.solver_options);
                            settings=struct('MaxPoints',2,'StepSize',obj.Run.options.StepSize,'InitialTangent',scan.next_tangent, ...
                                'Symmetry',obj.scopeSymmetry(obj.Run.options.Scope),'RootSolver',RootSolver_v3(solverOptions));
                            if isfield(solverOptions,'Jacobian'),settings.Jacobian=solverOptions.Jacobian;end
                            branch=FixedParameterContinuation_v3.run(framework.residual,framework.residual.packState(seed.initial_state),seed.parameter,seed.initial_mode,settings);
                            obj.requireOpen();
                            if branch.count<2,error('QuadrupedGUIController_v3:ScanBranch','%s',branch.terminationReason);end
                            record=obj.replay(obj.recordFromPoint(branch.points(2)));obj.requireScanRecord(record,[]);
                            record=obj.annotateScanRecord(record,k,scan.direction);obj.Run.accepted{end+1}=record;
                            obj.Run.branches(component).record_indices(end+1)=numel(obj.Run.accepted);
                            scan.branch_seed=record;scan.next_tangent=branch.points(2).tangent;
                            obj.Run.seed=record;obj.Candidate=record;
                            obj.Status=sprintf('Family target %d/%d direction %+d: %d/%d accepted points.',k,size(obj.Run.queue,1),scan.direction,numel(obj.Run.branches(component).record_indices),obj.Run.options.MaxPoints);
                        end
                    otherwise
                        error('QuadrupedGUIController_v3:ScanStage','Unknown family scan stage %s.',scan.stage);
                end
            catch exception
                if obj.Closing,return;end
                if any(strcmp(scan.stage,{'transport-first','transport-second'}))
                    history=struct('parameter',scan.trial_value,'step',scan.transport_step,'accepted',false,'identifier',exception.identifier,'reason',exception.message);
                    scan.target_transport_history(end+1)=history;scan.trial_first=[];scan.transport_step=scan.transport_step/2;
                    if scan.transport_step>=scan.minimum_transport_step&&scan.transport_attempts<24
                        scan.stage='transport-first';obj.Status=sprintf('Seed-pair transport rejected; retrying a smaller parameter step: %s',exception.message);
                    else
                        obj.recordScanFailure(scan,exception);obj.Run.next=k+1;scan.stage='target';
                    end
                elseif strcmp(scan.stage,'branch')
                    obj.Run.branches(scan.component_index).status='failed';obj.Run.branches(scan.component_index).terminal_reason=exception.message;
                    obj.recordScanFailure(scan,exception);scan=obj.advanceScanDirection(scan);
                else
                    obj.recordScanFailure(scan,exception);obj.Run.next=k+1;scan.stage='target';
                end
            end
            if obj.Closing,return;end
            obj.Run.family_scan=scan;obj.checkpoint();
        end
        function scan=advanceScanDirection(obj,scan)
            if scan.direction==1
                first=scan.working_pair{1};base=obj.Run.branches(scan.component_index).record_indices(1);
                component=struct('target_index',obj.Run.next,'target_value',scan.target_value,'parameter',obj.Run.parameter1,'direction',-1, ...
                    'record_indices',base,'status','running','terminal_reason','');
                obj.Run.branches(end+1)=component;scan.component_index=numel(obj.Run.branches);
                scan.direction=-1;scan.branch_seed=first;scan.next_tangent=-scan.initial_tangent;scan.stage='branch';obj.Run.seed=first;
            else
                obj.Run.next=obj.Run.next+1;scan.stage='target';scan.branch_seed=[];
            end
        end
        function record=annotateScanRecord(obj,record,target,direction)
            record.provenance.gui_queue_index=target;record.provenance.gui_queue_values=obj.Run.queue(target,:);
            record.provenance.gui_family_scan_parameter=obj.Run.parameter1;
            record.provenance.gui_family_scan_target=obj.Run.queue(target,1);record.provenance.gui_family_scan_direction=direction;
        end
        function recordScanFailure(obj,scan,exception)
            obj.Run.rejected{end+1}=struct('queue_index',obj.Run.next,'values',obj.Run.queue(obj.Run.next,:), ...
                'stage',scan.stage,'direction',scan.direction,'identifier',exception.identifier,'reason',exception.message, ...
                'transport_history',scan.target_transport_history);
            obj.Status=sprintf('Family target %d %s rejected: %s',obj.Run.next,scan.stage,exception.message);
        end
        function validateScanPair(obj,first,second,label)
            obj.requireScanRecord(first,label);obj.requireScanRecord(second,char(first.classification.label));
            if strcmp(char(first.classification.label),'unclassified')
                error('QuadrupedGUIController_v3:ScanUnclassifiedPair','Seed-pair transport requires an identifiable source gait.');
            end
            if ~isequal(first.parameter,second.parameter)||~isequal(first.initial_mode,second.initial_mode)|| ...
                    ~strcmp(first.return_policy_name,second.return_policy_name)|| ...
                    ~isequaln(first.BL_touchdowns_per_return,second.BL_touchdowns_per_return)
                error('QuadrupedGUIController_v3:ScanPairChart','The seed pair must share the physical parameters, mode, and return chart.');
            end
            if norm(first.initial_state-second.initial_state)<=eps
                error('QuadrupedGUIController_v3:ScanPairCollapsed','The transported seed pair collapsed to one state.');
            end
        end
        function requireScanRecord(~,record,label)
            if ~record.accepted||isempty(record.orbit)||~isfield(record.classification,'label')
                error('QuadrupedGUIController_v3:ScanAcceptance','Each seed/point must pass native independent replay and gait identification.');
            end
            if ~isempty(label)&&~strcmp(char(record.classification.label),char(label))
                error('QuadrupedGUIController_v3:ScanGait','Seed transport changed the identified gait from %s to %s.',char(label),char(record.classification.label));
            end
        end
        function distance=scanPairDistance(obj,first,second,scope)
            framework=obj.framework(first);family=EnergyFamilyResidual_v3(framework.residual,first.initial_state,first.initial_mode,first.parameter,struct('Symmetry',obj.scopeSymmetry(scope)));
            origin=family.packState(first.initial_state);other=family.packState(second.initial_state);
            distance=norm((other-origin)./max(1,abs(origin)));
        end
        function options=solverOptionsFor(obj,record,framework,options)
            % A supplied derivative is an explicit numerical choice. The
            % common-C1 alternative is selected only from a fresh actual
            % map satisfying its registered model/flight/cohort hypotheses;
            % its wrapper qualifies every subsequent physical probe again.
            if isfield(options,'Jacobian')&&~isempty(options.Jacobian),return;end
            if ~isa(framework.map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3'),return;end
            occurrence=framework.map.ReturnPolicy.BLTouchdownsPerReturn;
            if ~ismember(occurrence,[1 2]),return;end
            settings=struct('PhysicalParameter',record.parameter,'BLTouchdownsPerReturn',occurrence);
            if isfield(options,'MaxWallSeconds'),settings.MaxWallSeconds=options.MaxWallSeconds;end
            derivative=EventOrderChartJacobian_v3(settings);
            try
                [~,metadata]=framework.residual.evaluateWithInfo(framework.residual.packState(record.initial_state),record.parameter,record.initial_mode);
                [~,qualification]=derivative.normalizeMetadata(metadata);
            catch exception
                obj.requireOpen();
                % Generic differentiation remains responsible for exposing
                % ordinary map failures or charts outside these hypotheses.
                if strcmp(exception.identifier,'QuadrupedGUIController_v3:Closing'),rethrow(exception);end
                return
            end
            obj.requireOpen();
            if qualification.accepted,options.Jacobian=derivative;end
        end
        function solutions = savedDisplayClassifications(~, data, solutions)
            % Use the publisher's per-record labels, never the filename or
            % dataset abbreviation. This is display metadata, not replay.
            if ~isfield(data, 'branch') || ~isstruct(data.branch) || ~isscalar(data.branch) || ...
                    ~isfield(data.branch, 'schema_version') || ...
                    ~strcmp(data.branch.schema_version, 'named-continua-GUI-v3-2') || ...
                    ~isfield(data.branch, 'records') || numel(data.branch.records) ~= numel(solutions)
                return
            end
            records = data.branch.records;
            required = {'solution_index', 'classification_label', 'classification_status', 'physical_flight_count', 'period', 'signed_drift'};
            if ~isstruct(records) || ~all(isfield(records, required)), return; end
            for k = 1:numel(solutions)
                record = solutions{k}; saved = records(k);
                if ~isempty(fieldnames(record.classification)) || isempty(record.orbit), continue; end
                orbit = record.orbit;
                consistent = saved.solution_index == k && isequaln(saved.period, orbit.period) && ...
                    ~isempty(orbit.stride_displacement) && isequaln(saved.signed_drift, orbit.stride_displacement(1));
                if ~consistent, continue; end
                record.classification = struct('label', string(saved.classification_label), ...
                    'status', string(saved.classification_status), 'flight_count', saved.physical_flight_count, ...
                    'source', 'saved named-continuum per-record classification', ...
                    'descriptive_only', true, 'fresh_replay_performed', false);
                solutions{k} = record;
            end
        end
        function requireOpen(obj)
            if obj.Closing
                error('QuadrupedGUIController_v3:Closing', 'The GUI is closing; numerical work was cancelled.');
            end
        end
        function status = integrationControl(obj, ~, ~, flag)
            status = 0;
            if strcmp(flag, 'done'), return; end
            % Yield at accepted ODE steps so window-close and stop callbacks
            % can run. The numerical vector field and event policy are intact.
            drawnow limitrate;
            obj.requireOpen();
        end
        function tf = hasCompleteTrajectory(obj, record)
            tf = false;
            if isempty(record.orbit) || ~isa(record.orbit, 'HybridOrbit_v3'), return; end
            orbit = record.orbit; trajectory = orbit.trajectory;
            if ~(isscalar(orbit.period) && isfinite(orbit.period) && orbit.period > 0) || isempty(trajectory), return; end
            if ~isa(trajectory, 'Trajectory_v3'), return; end
            time = trajectory.time(:); state = trajectory.state;
            if numel(time) < 2 || size(state, 1) ~= numel(time) || size(state, 2) ~= obj.Schema.StateDimension || any(~isfinite(time)) || any(~isfinite(state), 'all'), return; end
            tolerance = max(1e-9, 1e-7*orbit.period);
            consistent = isequal(record.initial_state, orbit.initial_state) && ...
                isequal(record.initial_mode, orbit.initial_mode) && isequal(record.parameter, orbit.parameter);
            tf = consistent && all(diff(time) >= 0) && abs((time(end)-time(1))-orbit.period) <= tolerance;
        end
        function [components, ordered, warnings] = extractComponents(~, data, count)
            components = struct([]); ordered = struct('component_index', {}, 'record_indices', {}); warnings = {};
            if isfield(data, 'branch') && isstruct(data.branch) && isscalar(data.branch) && isfield(data.branch, 'components')
                components = data.branch.components;
                if ~isstruct(components)
                    warnings = {'Invalid component metadata; displaying points without connecting lines.'}; return
                end
                for k = 1:numel(components)
                    component = components(k); declared = false;
                    if isfield(component, 'record_kind')
                        declared = startsWith(string(component.record_kind), 'ordered_') ...
                            && contains(string(component.record_kind), 'continuation');
                    end
                    if isfield(component, 'ordered') && islogical(component.ordered) && isscalar(component.ordered)
                        declared = component.ordered;
                    end
                    if ~isscalar(declared) || ~declared, continue; end
                    indices = []; if isfield(component, 'record_indices'), indices = component.record_indices; end
                    if ~isnumeric(indices) || ~isreal(indices) || ~isvector(indices) || any(~isfinite(indices)) ...
                            || any(indices ~= fix(indices)) || any(indices < 1 | indices > count) || numel(unique(indices)) ~= numel(indices)
                        warnings{end+1} = sprintf('Invalid ordered component %d indices; displaying its points without a connecting line.', k); %#ok<AGROW>
                        continue
                    end
                    ordered(end+1) = struct('component_index', k, 'record_indices', double(indices(:).')); %#ok<AGROW>
                end
            elseif ~any(isfield(data, {'solutions', 'solution', 'orbit'})) && isfield(data, 'branch') ...
                    && isstruct(data.branch) && isscalar(data.branch) && isfield(data.branch, 'points')
                % The native historical branch.points contract supplies an
                % ordered point sequence. Generic top-level solution/sample
                % arrays never acquire that fallback or an inferred order.
                components = struct('record_indices', 1:count, 'record_kind', 'ordered_historical_branch_points_continuation');
                ordered = struct('component_index', 1, 'record_indices', 1:count);
            end
        end
        function record = currentSeed(obj)
            obj.requireOpen();
            if isempty(obj.Candidate), record = obj.selected(); else, record = obj.Candidate; end
        end
        function framework = framework(obj, record)
            obj.requireOpen();
            schema = obj.Schema;
            system = Quadrupedal_Dynamics_v3();
            simulator = HybridSimulator_v3(struct('ODEOptions', ...
                odeset('OutputFcn', @(t, x, flag) obj.integrationControl(t, x, flag))));
            section = PoincareSection_v3.apex(schema.PhaseIndex);
            policyName = record.return_policy_name;
            occurrences = record.BL_touchdowns_per_return;
            if ~strcmp(obj.ReturnPolicyOverride, 'stored')
                policyName = obj.ReturnPolicyOverride; occurrences = obj.ReturnOccurrences;
            end
            if strcmp(policyName, 'BL-marked-apex-return')
                if ~(isscalar(occurrences) && isfinite(occurrences) && occurrences >= 1 && occurrences == fix(occurrences))
                    error('QuadrupedGUIController_v3:UnknownReturnOccurrence', ...
                        'Saved BL chart lacks its touchdown occurrence count; choose an explicit BL policy and count.');
                end
                policy = BLMarkedApexReturnPolicy_v3(struct('BLTouchdownsPerReturn', occurrences));
            elseif strcmp(policyName, 'event-cycle-return')
                policy = EventCycleReturnPolicy_v3(struct('LegCount', schema.Leg.Count, 'LegNames', {schema.LegNames}));
            else
                error('QuadrupedGUIController_v3:UnsupportedReturnChart', ...
                    'Unknown stored return chart %s; select a supported explicit policy to change charts.', policyName);
            end
            map = PoincareMap_v3(system, section, simulator, policy, struct('MaxReturnTime', 8, ...
                'MaxSectionCrossings', 24, 'MaxCycleEvents', 256, 'ArmTolerance', 1e-7));
            residual = PeriodicOrbitResidual_v3(map, record.initial_state);
            framework = struct('map', map, 'residual', residual, 'system', system);
        end
        function [problem, u, augmented] = correctionProblem(obj, framework, record, symmetry)
            if nargin < 4, symmetry = obj.CorrectionSymmetry; end
            problem = EnergyFamilyResidual_v3(framework.residual, record.initial_state, ...
                record.initial_mode, record.parameter, struct('Symmetry', symmetry));
            u = problem.packState(record.initial_state);
            energy = QuadrupedEnergy_v3.evaluate(record.initial_state, record.initial_mode, record.parameter);
            augmented = [record.parameter(:); energy];
        end
        function symmetry = scopeSymmetry(~, scope)
            if strcmp(scope, 'pronk'), symmetry = 'pronk';
            elseif strcmp(scope, 'left/right'), symmetry = 'left-right';
            elseif any(strcmp(scope, {'full', 'none'})), symmetry = 'none';
            else, error('QuadrupedGUIController_v3:Scope', 'Unknown physical chart scope.'); end
        end
        function checkpoint(obj)
            gui_run = obj.Run;
            gui_run.seed = obj.compactRecord(gui_run.seed);
            for recordIndex = 1:numel(gui_run.accepted)
                gui_run.accepted{recordIndex} = obj.compactRecord(gui_run.accepted{recordIndex});
            end
            if isfield(gui_run,'family_scan')
                scan=gui_run.family_scan;
                for key={'source_pair','working_pair'}
                    pair=scan.(key{1});for seedIndex=1:2,pair{seedIndex}=obj.compactRecord(pair{seedIndex});end;scan.(key{1})=pair;
                end
                for targetIndex=1:numel(scan.target_pairs)
                    pair=scan.target_pairs{targetIndex};
                    for seedIndex=1:numel(pair),pair{seedIndex}=obj.compactRecord(pair{seedIndex});end
                    scan.target_pairs{targetIndex}=pair;
                end
                for key={'trial_first','branch_seed'}
                    if ~isempty(scan.(key{1})),scan.(key{1})=obj.compactRecord(scan.(key{1}));end
                end
                gui_run.family_scan=scan;
            end
            file = obj.prepareOutput(obj.Run.options.Checkpoint);
            save(V3Path_v3(file), 'gui_run', '-v7');
        end
        function record = compactRecord(~, record)
            [packed, report] = CompactResearchBranch_v3(struct('points', record));
            record = packed.points; record.compact_checkpoint = report;
        end
        function solutions = extractSolutions(obj, data, policy)
            solutions = {};
            if isfield(data, 'solutions'), source = data.solutions;
            elseif isfield(data, 'solution'), source = {data.solution};
            elseif isfield(data, 'orbit'), source = {data.orbit};
            elseif isfield(data, 'branch') && isfield(data.branch, 'points')
                source = num2cell(data.branch.points);
            elseif isfield(data, 'study') && isfield(data.study, 'base'), source = {data.study.base};
            elseif isfield(data, 'results') && isnumeric(data.results) && size(data.results, 1) >= 29
                source = cell(1, size(data.results, 2));
                for k = 1:numel(source)
                    raw = data.results(:, k);
                    u = LegacyStateAdapter_v3.toV3Unknown(raw(1:13));
                    x = zeros(obj.Schema.StateDimension, 1); x(obj.Schema.DefaultUnknownIndices) = u;
                    p = LegacyParameterAdapter_v3.toV3(raw(23:29), policy);
                    source{k} = struct('initial_state', x, 'parameter', p, ...
                        'initial_mode', false(4, 1), 'provenance', struct('conversion_policy', policy, 'source_column', k, ...
                        'event_times_ignored', true));
                end
            else, source = {}; end
            if ~iscell(source), source = num2cell(source); end
            for k = 1:numel(source)
                solutions{end + 1} = obj.normalize(source{k});
            end
        end
        function record = recordFromPoint(obj, point)
            record = obj.normalize(point);
        end
        function record = normalize(obj, source)
            if isa(source, 'HybridOrbit_v3')
                orbit = source; source = source.toStruct();
            elseif isstruct(source) && isfield(source, 'orbit') && isa(source.orbit, 'HybridOrbit_v3')
                orbit = source.orbit;
            elseif isstruct(source) && isfield(source, 'orbit') && ...
                    isstruct(source.orbit) && isscalar(source.orbit) && ...
                    all(isfield(source.orbit, {'initial_state', 'initial_mode', 'parameter', 'period'})) && ...
                    ~isfield(source.orbit, 'diagnostic_kind')
                orbit = HybridOrbit_v3(source.orbit);
            elseif isstruct(source) && isscalar(source) && ...
                    all(isfield(source, {'initial_state', 'initial_mode', 'parameter', 'period', 'section_chart'})) && ...
                    ~isfield(source, 'diagnostic_kind')
                orbit = HybridOrbit_v3(source);
            else, orbit = []; end
            record = struct('initial_state', [], 'initial_mode', [], 'parameter', [], ...
                'orbit', orbit, 'accepted', false, 'status', 'imported; unvalidated', ...
                'residual', [], 'scaled_residual', [], 'residual_norm', Inf, 'validation', struct(), ...
                'classification', struct(), 'solver_info', struct(), 'stability', struct(), 'provenance', struct(), ...
                'return_policy_name', 'event-cycle-return', 'BL_touchdowns_per_return', 1);
            if ~isempty(orbit)
                record.initial_state = orbit.initial_state; record.initial_mode = orbit.initial_mode; record.parameter = orbit.parameter;
                if ~isempty(orbit.return_policy_name), record.return_policy_name = char(orbit.return_policy_name); end
                if strcmp(record.return_policy_name, 'BL-marked-apex-return')
                    record.BL_touchdowns_per_return = NaN;
                    if isfield(orbit.section_chart, 'BL_touchdowns_per_return')
                        record.BL_touchdowns_per_return = orbit.section_chart.BL_touchdowns_per_return;
                    end
                end
            else
                if isfield(source, 'initial_state'), record.initial_state = source.initial_state;
                elseif isfield(source, 'fullState'), record.initial_state = source.fullState;
                elseif isfield(source, 'unknown')
                    record.initial_state = zeros(obj.Schema.StateDimension, 1);
                    record.initial_state(obj.Schema.DefaultUnknownIndices) = source.unknown;
                elseif isfield(source, 'x') && numel(source.x) == obj.Schema.StateDimension
                    record.initial_state = source.x;
                end
                if isfield(source, 'initial_mode'), record.initial_mode = source.initial_mode;
                elseif isfield(source, 'mode'), record.initial_mode = source.mode; end
                if isfield(source, 'parameter'), record.parameter = source.parameter;
                elseif isfield(source, 'p'), record.parameter = source.p; end
            end
            names = fieldnames(record);
            for k = 1:numel(names)
                if isstruct(source) && isfield(source, names{k}) && ~isempty(source.(names{k}))
                    if strcmp(names{k}, 'orbit') && ~isempty(orbit), continue; end
                    record.(names{k}) = source.(names{k});
                end
            end
            if isempty(fieldnames(record.classification)) && ~isempty(orbit) && ...
                    isstruct(orbit.gait_identification) && isfield(orbit.gait_identification, 'label')
                record.classification = orbit.gait_identification;
            end
            if strcmp(record.return_policy_name, 'BL-marked-apex-return') && isempty(orbit) && ~isfield(source, 'BL_touchdowns_per_return')
                record.BL_touchdowns_per_return = NaN;
            end
            record.initial_state = obj.Schema.validateState(record.initial_state);
            record.parameter = obj.Schema.validateParameter(record.parameter);
            record.initial_mode = obj.Schema.validateMode(record.initial_mode);
            record.accepted = false; % Stored acceptance is never trusted as a replay certificate.
        end
    end
end
