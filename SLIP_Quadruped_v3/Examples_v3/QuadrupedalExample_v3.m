function [orbit, report, framework] = QuadrupedalExample_v3(options)
%QUADRUPEDALEXAMPLE_V3 Refine a converted legacy seed as a v3 full cycle.
%   [ORBIT,REPORT,FRAMEWORK] = QuadrupedalExample_v3() explicitly converts
%   one stored v2 branch point, discovers all contact events, closes a full
%   per-leg touchdown/liftoff cycle, and refines the 13 continuous root
%   coordinates. Legacy event times and gait labels are never inputs.

    if nargin < 1 || isempty(options)
        options = struct();
    end
    defaults = struct( ...
        'FixtureFile', 'PK_20_2.mat', ...
        'FixtureColumn', 1, ...
        'LegacyParameterPolicy', 'v2-exact', ...
        'InitialUnknownPerturbation', [], ...
        'Refine', true, ...
        'ComputeStability', false, ...
        'MaxReturnTime', 5, ...
        'MaxSectionCrossings', 8, ...
        'MaxCycleEvents', 128, ...
        'ArmTolerance', 1e-7, ...
        'SectionModeTolerance', 1e-7, ...
        'ResidualTolerance', 1e-7, ...
        'SolverOptions', struct(), ...
        'StabilityOptions', struct());
    options = mergeOptions(defaults, options);

    v3Root = fileparts(fileparts(mfilename('fullpath')));
    originalPath = path;
    restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
    addV3Paths(v3Root);
    fixturePath = resolveFixture(v3Root, options.FixtureFile);
    data = load(fixturePath, 'results');
    if ~isfield(data, 'results')
        error('QuadrupedalExample_v3:FixtureFormat', ...
            'The fixture must contain a numeric results array.');
    end
    if options.FixtureColumn < 1 || ...
            options.FixtureColumn > size(data.results, 2)
        error('QuadrupedalExample_v3:FixtureColumn', ...
            'FixtureColumn is outside the stored branch.');
    end

    legacy = data.results(:, options.FixtureColumn);
    schema = QuadrupedSchema_v3.shared();
    convertedSeed = LegacyStateAdapter_v3.toV3Unknown(legacy(1:13));
    perturbation = options.InitialUnknownPerturbation;
    if isempty(perturbation)
        perturbation = zeros(size(convertedSeed));
    elseif isscalar(perturbation)
        perturbation = repmat(double(perturbation), size(convertedSeed));
    else
        perturbation = double(perturbation(:));
    end
    if numel(perturbation) ~= numel(convertedSeed) || ...
            any(~isfinite(perturbation))
        error('QuadrupedalExample_v3:InitialUnknownPerturbation', ...
            'InitialUnknownPerturbation must be finite and have 13 entries.');
    end
    uSeed = convertedSeed + perturbation;
    [parameter, conversionReport] = LegacyParameterAdapter_v3.toV3( ...
        legacy(23:29), options.LegacyParameterPolicy);
    initialMode = LegacyModeAdapter_v3.toV3( ...
        false(schema.Leg.Count, 1));

    system = Quadrupedal_Dynamics_v3();
    simulator = HybridSimulator_v3();
    section = PoincareSection_v3.apex(schema.State.dy, struct( ...
        'ValueTolerance', 1e-9, 'DerivativeTolerance', 1e-10));
    policyOptions = struct( ...
        'LegCount', schema.Leg.Count, ...
        'LegNames', {schema.Leg.Names});
    returnPolicy = EventCycleReturnPolicy_v3(policyOptions);
    modeResolver = SectionModeResolver_v3(struct( ...
        'SectionModeTolerance', options.SectionModeTolerance));
    map = PoincareMap_v3(system, section, simulator, returnPolicy, struct( ...
        'ModeResolver', modeResolver, ...
        'MaxReturnTime', options.MaxReturnTime, ...
        'MaxSectionCrossings', options.MaxSectionCrossings, ...
        'MaxCycleEvents', options.MaxCycleEvents, ...
        'ArmTolerance', options.ArmTolerance));
    problem = PeriodicOrbitResidual_v3( ...
        map, zeros(schema.State.Dimension, 1));

    [seedResidual, seedDetails] = problem.evaluateWithInfo( ...
        uSeed, parameter, initialMode);
    solveInfo = struct('used', false, 'converged', false, ...
        'mapEvaluationCount', 0, 'functionEvaluationCount', 0, ...
        'cacheHitCount', 0, 'candidateModes', {{initialMode}});
    if options.Refine
        solverOptions = options.SolverOptions;
        if isempty(fieldnames(solverOptions))
            solverOptions = struct( ...
                'ResidualAcceptanceTolerance', options.ResidualTolerance, ...
                'FunctionTolerance', min(1e-10, options.ResidualTolerance), ...
                'MaxIterations', 75, ...
                'MaxFunctionEvaluations', 2000);
        end
        solver = RootSolver_v3(solverOptions);
        [rootCoordinates, solveInfo] = solver.solve( ...
            problem, uSeed, parameter, initialMode);
        solveInfo.used = true;
        if ~solveInfo.converged
            error('QuadrupedalExample_v3:RootDidNotConverge', ...
                'Actual v3 root refinement failed: %s', solveInfo.message);
        end
        acceptedMode = solveInfo.mode;
    else
        rootCoordinates = uSeed;
        acceptedMode = initialMode;
    end

    [residual, details] = problem.evaluateWithInfo( ...
        rootCoordinates, parameter, acceptedMode);
    if options.Refine && ~isempty(solveInfo.orbit)
        orbit = solveInfo.orbit;
    else
        orbit = problem.createOrbit( ...
            rootCoordinates, parameter, acceptedMode, details);
    end

    report = struct();
    report.fixture_path = fixturePath;
    report.fixture_column = options.FixtureColumn;
    report.legacy_parameter_conversion = conversionReport;
    report.converted_seed = convertedSeed;
    report.initial_guess = uSeed;
    report.initial_unknown_perturbation = perturbation;
    report.schema_metadata = schema.metadata();
    report.seed_residual = seedResidual;
    report.seed_residual_norm = norm(seedResidual, inf);
    report.residual = residual;
    report.residual_norm = norm(residual, inf);
    report.converged = ~options.Refine || solveInfo.converged;
    report.recovered = report.converged && ...
        report.residual_norm <= options.ResidualTolerance && ...
        details.discrete_closed && details.map_info.cycle_complete;
    report.period = orbit.period;
    report.return_multiplicity = details.map_info.return_multiplicity;
    report.event_sequence = details.map_info.event_sequence;
    report.event_times = details.map_info.event_times;
    report.event_history = details.map_info.event_history;
    report.mode_sequence = details.map_info.mode_sequence;
    report.initial_mode = details.map_info.initial_mode;
    report.final_mode = details.map_info.final_mode;
    report.event_counts_per_leg = ...
        details.map_info.event_counts_per_leg;
    report.section_relative_event_signature = ...
        details.map_info.section_relative_event_signature;
    report.cyclic_event_signature = ...
        details.map_info.cyclic_event_signature;
    report.cycle_completion_diagnostics = ...
        details.map_info.cycle_completion_diagnostics;
    report.stride_displacement = ...
        details.map_info.stride_displacement(schema.State.x);
    report.map_evaluations = memberOr( ...
        solveInfo, 'mapEvaluationCount', double(~options.Refine));
    report.function_evaluations = memberOr( ...
        solveInfo, 'functionEvaluationCount', double(~options.Refine));
    report.cache_hits = memberOr(solveInfo, 'cacheHitCount', 0);
    report.modes_attempted = numel(memberOr( ...
        solveInfo, 'candidateModes', {acceptedMode}));
    report.mode_resolution = memberOr( ...
        solveInfo, 'modeResolution', struct());
    report.solve_info = solveInfo;
    report.seed_details = seedDetails;

    if options.ComputeStability
        analyzer = FloquetAnalysis_v3();
        stability = analyzer.analyze(map, orbit.initial_state, ...
            orbit.initial_mode, parameter, options.StabilityOptions);
        orbit.setFloquetResult(stability);
        report.stability = stability;
    else
        report.stability = struct();
    end

    framework = struct('schema', schema, 'system', system, ...
        'simulator', simulator, 'section', section, ...
        'returnPolicy', returnPolicy, 'modeResolver', modeResolver, ...
        'map', map, 'residual', problem);
end

function fixturePath = resolveFixture(v3Root, fixtureFile)
    fixtureFile = char(fixtureFile);
    if isfile(fixtureFile)
        fixturePath = fixtureFile;
        return
    end
    fixturePath = fullfile(v3Root, ...
        'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits', ...
        'SourceFixtures_v3', fixtureFile);
    if ~isfile(fixturePath)
        error('QuadrupedalExample_v3:FixtureMissing', ...
            'Cannot find legacy fixture "%s".', fixtureFile);
    end
end

function addV3Paths(v3Root)
    folders = {'Schema_v3', 'Adapters_v3', 'Dynamics_v3', ...
        'Simulation_v3', 'Orbit_v3', 'Numerics_v3', ...
        'Stability_v3', 'Graphics_v3'};
    for i = 1:numel(folders)
        addpath(fullfile(v3Root, folders{i}));
    end
end

function value = memberOr(source, name, fallback)
    value = fallback;
    if isstruct(source) && isfield(source, name)
        value = source.(name);
    end
end

function result = mergeOptions(defaults, overrides)
    if ~isstruct(overrides) || ~isscalar(overrides)
        error('QuadrupedalExample_v3:Options', ...
            'Options must be a scalar structure.');
    end
    result = defaults;
    names = fieldnames(overrides);
    for i = 1:numel(names)
        if ~isfield(defaults, names{i})
            error('QuadrupedalExample_v3:UnknownOption', ...
                'Unknown option "%s".', names{i});
        end
        result.(names{i}) = overrides.(names{i});
    end
end
