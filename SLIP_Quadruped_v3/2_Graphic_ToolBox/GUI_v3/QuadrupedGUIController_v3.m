classdef QuadrupedGUIController_v3 < handle
    %QUADRUPEDGUICONTROLLER_V3 Testable state and shared-service GUI actions.
    % Numerical algorithms remain in the v3 simulation/orbit/numerics layers.
    % Pause/stop are cooperative at accepted/rejected point boundaries.
    properties (SetAccess = private)
        Root
        Schema
        Folder
        Datasets = struct('name', {}, 'source', {}, 'solutions', {})
        SelectedDataset = 0
        SelectedIndex = 0
        Candidate = []
        SecondSeed = []
        Run = struct()
        Status = 'Ready.'
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
            [~, name, ext] = fileparts(file);
            dataset = struct('name', [name, ext], 'source', file, 'solutions', {solutions});
            index = find(strcmp({obj.Datasets.source}, file), 1);
            if isempty(index)
                obj.Datasets(end + 1) = dataset;
                index = numel(obj.Datasets);
            else
                obj.Datasets(index) = dataset;
            end
            obj.select(index, 1);
            obj.Status = sprintf('Loaded %s: %d solutions; imported states require replay.', dataset.name, numel(solutions));
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
        end
        function remove(obj, index)
            if nargin < 2, index = obj.SelectedDataset; end
            if index == 0, return; end
            obj.Datasets(index) = [];
            obj.SelectedDataset = 0; obj.SelectedIndex = 0;
            obj.Candidate = []; obj.SecondSeed = [];
            if ~isempty(obj.Datasets), obj.select(1, 1); end
        end
        function removeAll(obj)
            obj.Datasets = struct('name', {}, 'source', {}, 'solutions', {});
            obj.SelectedDataset = 0; obj.SelectedIndex = 0;
            obj.Candidate = []; obj.SecondSeed = [];
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
        function record = editSeed(obj, state, parameter, mode)
            record = obj.selected();
            record.initial_state = obj.Schema.validateState(state);
            record.parameter = obj.Schema.validateParameter(parameter);
            record.initial_mode = obj.Schema.validateMode(mode);
            record.orbit = []; record.accepted = false;
            record.status = 'edited seed; unvalidated';
            record.provenance.editor = 'SLIP_Quadruped_GUI_v3';
            obj.Candidate = record;
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
            obj.Candidate = record;
        end
        function record = predict(obj, multiplier)
            validateattributes(multiplier, {'numeric'}, {'scalar', 'finite'});
            record = obj.currentSeed();
            if isempty(obj.SecondSeed)
                error('QuadrupedGUIController_v3:SecondSeed', 'Validate a second seed before a secant prediction.');
            end
            first = obj.selected(); second = obj.SecondSeed;
            record.initial_state = first.initial_state + multiplier .* (second.initial_state-first.initial_state);
            record.initial_state(obj.Schema.TranslationIndex) = 0;
            record.initial_state(obj.Schema.PhaseIndex) = 0;
            record.orbit = []; record.accepted = false; record.status = 'secant prediction; unvalidated';
            obj.Candidate = record;
        end
        function record = replay(obj, record)
            if nargin < 2, record = obj.currentSeed(); end
            framework = obj.framework(record);
            u = framework.residual.packState(record.initial_state);
            [residual, details] = framework.residual.evaluateWithInfo(u, record.parameter, record.initial_mode);
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
        function record = inspect(obj)
            record = obj.replay(obj.selected());
            obj.Datasets(obj.SelectedDataset).solutions{obj.SelectedIndex} = record;
        end
        function record = correct(obj, record)
            if nargin < 2, record = obj.currentSeed(); end
            framework = obj.framework(record);
            [problem, u, augmented] = obj.correctionProblem(framework, record);
            seed=struct('state',record.initial_state,'mode',record.initial_mode, ...
                'parameter',record.parameter,'return_policy',framework.map.ReturnPolicy, ...
                'occurrence',1,'provenance',record.provenance);
            if isa(framework.map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3')
                seed.occurrence=framework.map.ReturnPolicy.BLTouchdownsPerReturn;
            end
            options=struct('Residual',problem,'Coordinates',u, ...
                'AugmentedParameter',augmented,'SolverOptions',obj.SolverOptions, ...
                'Acceptance',struct('FullClosureTolerance',obj.AcceptanceTolerance));
            [orbit,report]=PeriodicSolutionSolver_v3(seed,options);
            record.solver_info=report.solver;
            record.validation=report;
            if ~report.accepted
                message='fresh correction/replay acceptance failed';
                if isfield(report.solver,'message'),message=report.solver.message;end
                if isfield(report.primary_failure,'message'),message=report.primary_failure.message;end
                if isfield(report.replay_failure,'message'),message=report.replay_failure.message;end
                record.initial_state=report.final_candidate;
                record.accepted = false; record.status = ['correction failed: ', message];
                obj.Candidate = record; obj.Status = record.status;
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
            obj.Candidate = record;
        end
        function record = secondSeed(obj, radius, scope)
            if nargin < 3, scope = 'full'; end
            validateattributes(radius, {'numeric'}, {'scalar', 'finite', 'positive'});
            first = obj.replay(obj.selected());
            if ~first.accepted
                error('QuadrupedGUIController_v3:UnacceptedSeed', 'The first seed must pass independent replay.');
            end
            if exist(V3Path_v3('FixedParameterContinuation_v3'), 'file') ~= 2
                error('QuadrupedGUIController_v3:FamilyService', 'Shared fixed-parameter family service is unavailable.');
            end
            framework = obj.framework(first);
            symmetry = obj.scopeSymmetry(scope);
            options = struct('Symmetry', symmetry, 'SolverOptions', obj.SolverOptions);
            [orbit, report] = FixedParameterContinuation_v3.secondSeed(framework.residual, ...
                framework.residual.packState(first.initial_state), first.parameter, first.initial_mode, radius, options);
            if isempty(orbit) || ~report.converged
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
        function index = plotCandidate(obj, name)
            if nargin < 2, name = 'Solved seed'; end
            record = obj.currentSeed();
            index = numel(obj.Datasets) + 1;
            obj.Datasets(index) = struct('name', name, 'source', '', 'solutions', {{record}});
            obj.select(index, 1);
        end
        function file = saveSolution(obj, file)
            solution = obj.currentSeed();
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
            if ~isempty(fieldnames(obj.Run)) && strcmp(obj.Run.status, 'running')
                error('QuadrupedGUIController_v3:Busy', 'Pause or stop the active run first.');
            end
            seed = obj.replay(obj.currentSeed());
            if ~seed.accepted, error('QuadrupedGUIController_v3:Seed', 'Run requires an accepted seed.'); end
            defaults = struct('Checkpoint', fullfile(obj.Root, 'GUI_v3', 'Outputs_v3', 'gui-partial.mat'), ...
                'MaxPoints', 10, 'StepSize', 0.01, 'Scope', 'full');
            names = fieldnames(options);
            for k = 1:numel(names)
                if ~isfield(defaults, names{k}), error('QuadrupedGUIController_v3:RunOption', 'Unknown run option %s.', names{k}); end
                defaults.(names{k}) = options.(names{k});
            end
            obj.prepareOutput(defaults.Checkpoint);
            kind = validatestring(kind, {'fixed', 'parameter', 'scan'});
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
            obj.Run = struct('kind', kind, 'status', 'running', 'queue', queue, 'next', 1, ...
                'parameter1', parameter1, 'parameter2', parameter2, 'seed', seed, ...
                'accepted', {{}}, 'rejected', {{}}, 'options', defaults, ...
                'family_energy', QuadrupedEnergy_v3.evaluate(seed.initial_state, seed.initial_mode, seed.parameter), ...
                'next_tangent', [], 'solver_options', obj.SolverOptions, 'terminal_reason', '', 'started_at', char(datetime('now')));
            obj.checkpoint();
            obj.Status = sprintf('%s run started: %d points.', kind, size(queue, 1));
        end
        function stepRun(obj)
            if isempty(fieldnames(obj.Run)) || ~strcmp(obj.Run.status, 'running'), return; end
            k = obj.Run.next;
            if k > size(obj.Run.queue, 1)
                obj.Run.status = 'complete'; obj.Run.terminal_reason = 'requested point budget exhausted';
                obj.checkpoint(); obj.Status = 'Requested run completed; no global branch completeness is implied.'; return
            end
            seed = obj.Run.seed;
            try
                if strcmp(obj.Run.kind, 'fixed')
                    framework = obj.framework(seed);
                    settings = struct('MaxPoints', 2, 'StepSize', obj.Run.options.StepSize, ...
                        'Symmetry', obj.scopeSymmetry(obj.Run.options.Scope), ...
                        'RootSolver', RootSolver_v3(obj.Run.solver_options));
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
                    service = NumericalContinuation1D_v3(struct('RootSolver', RootSolver_v3(obj.Run.solver_options), ...
                        'ActiveParameter', obj.Run.parameter1));
                    branch = service.run(problem, u, augmented, seed.initial_mode, p(obj.Schema.parameterIndex(obj.Run.parameter1)));
                    if branch.count == 0, error('QuadrupedGUIController_v3:GridCorrection', 'Point correction failed.'); end
                    record = obj.recordFromPoint(branch.points(end));
                end
                record = obj.replay(record);
                if ~record.accepted, error('QuadrupedGUIController_v3:PointReplay', 'Point failed independent closure/admissibility replay.'); end
                record.provenance.gui_queue_index = k;
                record.provenance.gui_queue_values = obj.Run.queue(k, :);
                obj.Run.accepted{end + 1} = record;
                obj.Run.seed = record;
                obj.Candidate = record;
                obj.Status = sprintf('%s: point %d/%d accepted; residual %.3e.', obj.Run.kind, k, size(obj.Run.queue, 1), record.residual_norm);
            catch exception
                obj.Run.rejected{end + 1} = struct('queue_index', k, 'values', obj.Run.queue(k, :), ...
                    'identifier', exception.identifier, 'reason', exception.message);
                obj.Status = sprintf('Point %d rejected: %s', k, exception.message);
                if strcmp(obj.Run.kind, 'fixed')
                    obj.Run.status = 'failed'; obj.Run.terminal_reason = exception.message;
                end
            end
            obj.Run.next = k + 1;
            obj.checkpoint();
        end
        function pauseRun(obj)
            if ~isempty(fieldnames(obj.Run)) && strcmp(obj.Run.status, 'running')
                obj.Run.status = 'paused'; obj.Run.terminal_reason = 'user pause at point boundary'; obj.checkpoint();
            end
        end
        function resumeRun(obj, file)
            if nargin > 1 && ~isempty(file)
                file = obj.confinedPath(file, true);
                loaded = load(V3Path_v3(file), 'gui_run');
                if ~isfield(loaded, 'gui_run'), error('QuadrupedGUIController_v3:CheckpointFormat', 'Missing gui_run.'); end
                obj.Run = loaded.gui_run;
                obj.Run.options.Checkpoint = obj.confinedPath(obj.Run.options.Checkpoint);
                obj.SolverOptions = obj.Run.solver_options;
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
            obj.Datasets(end + 1) = struct('name', [obj.Run.kind, ' partial results'], ...
                'source', obj.Run.options.Checkpoint, 'solutions', {obj.Run.accepted});
            obj.select(numel(obj.Datasets), 1);
        end
        function frames = frames(obj, strides, preserveEvents)
            if nargin < 2, strides = 1; end
            if nargin < 3, preserveEvents = true; end
            validateattributes(strides, {'numeric'}, {'scalar', 'integer', 'positive'});
            record = obj.replay(obj.currentSeed());
            if ~record.accepted, error('QuadrupedGUIController_v3:VisualizationAcceptance', 'Animation requires an accepted complete orbit.'); end
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
        function record = currentSeed(obj)
            if isempty(obj.Candidate), record = obj.selected(); else, record = obj.Candidate; end
        end
        function framework = framework(obj, record)
            schema = obj.Schema;
            system = Quadrupedal_Dynamics_v3(); simulator = HybridSimulator_v3();
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
                    record.(names{k}) = source.(names{k});
                end
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
