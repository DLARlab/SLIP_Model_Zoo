function [orbit, report, framework] = QuadrupedalExample_v3(options)
%QUADRUPEDALEXAMPLE_V3 Reproduce a legacy orbit with event-driven guards.
%   [ORBIT,REPORT,FRAMEWORK] = QuadrupedalExample_v3() loads an asymmetric
%   stored solution only for its initial state and parameter vector.  The
%   legacy event times are not supplied to v3; all eight contact events and
%   the next apex are discovered from state-triggered guards.

    if nargin < 1 || isempty(options)
        options = struct();
    end
    defaults = struct( ...
        'FixtureFile', 'PK_20_2.mat', ...
        'FixtureColumn', 1, ...
        'Refine', false, ...
        'ComputeStability', false, ...
        'MaxReturnTime', 3, ...
        'ArmTolerance', 1e-7, ...
        'ResidualTolerance', 2e-5);
    options = mergeOptions(defaults, options);

    repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
    addV3Paths(repositoryRoot);
    fixturePath = fullfile(repositoryRoot, 'SLIP_Quadruped', ...
        'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits', ...
        '1_Roadmap', options.FixtureFile);
    data = load(fixturePath, 'results');
    if options.FixtureColumn < 1 || ...
            options.FixtureColumn > size(data.results, 2)
        error('QuadrupedalExample_v3:FixtureColumn', ...
            'FixtureColumn is outside the stored branch.');
    end

    legacy = data.results(:, options.FixtureColumn);
    u0 = legacy(1:13);
    p = legacy(23:29);
    q0 = false(4, 1);

    system = Quadrupedal_Dynamics_v3();
    simulator = HybridSimulator_v3();
    section = PoincareSection_v3.apex(4, struct( ...
        'ValueTolerance', 1e-9, 'DerivativeTolerance', 1e-10));
    map = PoincareMap_v3(system, section, simulator, struct( ...
        'MaxReturnTime', options.MaxReturnTime, ...
        'ArmTolerance', options.ArmTolerance));
    problem = PeriodicOrbitResidual_v3(map, zeros(14, 1));

    solveInfo = struct('used', false);
    if options.Refine
        solver = RootSolver_v3();
        [u, solveInfo] = solver.solve(problem, u0, p, q0);
        orbit = solveInfo.orbit;
        if isempty(orbit)
            [~, details] = problem.evaluateWithInfo( ...
                u, p, solveInfo.mode);
            orbit = problem.createOrbit(u, p, solveInfo.mode, details);
        end
    else
        u = u0;
        [~, details] = problem.evaluateWithInfo(u, p, q0);
        orbit = problem.createOrbit(u, p, q0, details);
    end

    [residual, details] = problem.evaluateWithInfo(u, p, orbit.initial_mode);
    report = struct();
    report.fixture_path = fixturePath;
    report.fixture_column = options.FixtureColumn;
    report.residual = residual;
    report.residual_norm = norm(residual, inf);
    report.recovered = report.residual_norm <= options.ResidualTolerance && ...
        details.discrete_closed;
    report.period = orbit.period;
    report.event_sequence = details.map_info.event_sequence;
    report.event_times = details.map_info.event_times;
    report.mode_sequence = details.map_info.mode_sequence;
    report.stride_displacement = details.map_info.stride_displacement(1);
    report.solve_info = solveInfo;

    if options.ComputeStability
        analyzer = FloquetAnalysis_v3();
        stability = analyzer.analyze( ...
            map, orbit.initial_state, orbit.initial_mode, p);
        orbit.setFloquetResult(stability);
        report.stability = stability;
    else
        report.stability = struct();
    end

    framework = struct('system', system, 'simulator', simulator, ...
        'section', section, 'map', map, 'residual', problem);
end

function addV3Paths(repositoryRoot)
    folders = {'Dynamics_v3', 'Simulation_v3', 'Orbit_v3', ...
        'Numerics_v3', 'Stability_v3'};
    for i = 1:numel(folders)
        addpath(fullfile(repositoryRoot, folders{i}));
    end
end

function result = mergeOptions(defaults, overrides)
    if ~isstruct(overrides)
        error('QuadrupedalExample_v3:Options', ...
            'Options must be a structure.');
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
