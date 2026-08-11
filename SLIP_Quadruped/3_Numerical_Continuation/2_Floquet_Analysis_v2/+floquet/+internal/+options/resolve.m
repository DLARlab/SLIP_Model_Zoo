function options = resolve(userOptions)
%RESOLVEFLOQUETOPTIONS Validate and complete Floquet-analysis options.
%
%   OPTIONS = RESOLVEFLOQUETOPTIONS(USEROPTIONS) supplies the numerical
%   defaults shared by the reduced Poincare-map implementation.  Field
%   names are matched case-insensitively.  Unknown fields are rejected so
%   that misspelled tolerances cannot silently weaken validation.

    if nargin < 1 || isempty(userOptions)
        userOptions = struct();
    end
    if ~isstruct(userOptions) || ~isscalar(userOptions)
        error('ResolveFloquetOptions:InvalidOptions', ...
            'options must be a scalar structure.');
    end

    options = DefaultOptions();
    aliases = OptionAliases();
    suppliedNames = fieldnames(userOptions);
    canonicalNames = fieldnames(options);

    for i = 1:numel(suppliedNames)
        supplied = suppliedNames{i};
        canonical = MatchCanonicalName(supplied, canonicalNames, aliases);
        if isempty(canonical)
            error('ResolveFloquetOptions:UnknownOption', ...
                'Unknown Floquet option ''%s''.', supplied);
        end
        options.(canonical) = userOptions.(supplied);
    end

    options = ValidateOptions(options);
end

function options = DefaultOptions()
    options = struct();

    % Model interface.  The default call deliberately omits 'skipSolve':
    % the production function must determine the perturbed event times.
    options.DynamicsFunction = @Quadrupedal_ZeroFun_v2;
    options.Constraints = {};
    options.SuppressDynamicsOutput = true;
    options.StoreTrajectories = false;

    % Reduced apex section X([1 2 4:13]); X(3)=dy is the section-normal
    % coordinate.  These indices are a mathematical invariant, not an
    % option exposed for alteration.
    options.ReducedStateIndices = [1 2 4:13];
    options.SectionStateIndex = 3;
    options.VerticalGRFColumns = 9:12;
    options.Gravity = 1;

    % Scaled central differences.  Levels are sorted coarse-to-fine.
    options.PerturbationMagnitude = 1e-6;
    options.PerturbationFactors = [4 2 1];
    options.PerturbationMagnitudes = [];
    options.StateScale = ones(12,1);
    options.MinimumAbsoluteStep = 100 * eps;

    % Validation tolerances in the nondimensional model units.
    options.PeriodicResidualTolerance = 1e-7;
    options.TimingResidualTolerance = 1e-7;
    options.CheckTimingRepeatability = true;
    options.TimingRepeatabilityTolerance = 1e-8;
    options.SectionTolerance = 1e-8;
    options.ApexAccelerationTolerance = 1e-9;
    options.StrideTimeTolerance = 1e-8;
    options.TrajectoryConsistencyTolerance = 1e-8;

    % Strict mode preserves the total label order.  Clustered mode permits
    % permutations inside nominal simultaneous-event clusters, but never
    % permits events from different nominal clusters to interleave.
    options.TopologyMode = 'clustered';
    options.TopologyClusterTolerance = 1e-7;
    options.TopologyOrderTolerance = 1e-10;
    options.ReferenceTopology = [];

    % Accuracy reporting and optional strict rejection.
    options.DerivativeConvergenceTolerance = 5e-3;
    options.ForwardBackwardTolerance = 5e-3;
    options.RejectOnDerivativeNonconvergence = true;
    options.RejectOnForwardBackwardMismatch = true;
    options.StopOnFirstFailure = false;
    options.ErrorOnFailure = false;
end

function aliases = OptionAliases()
    aliases = struct();
    aliases.FDSize = 'PerturbationMagnitude';
    aliases.fd_size = 'PerturbationMagnitude';
    aliases.FiniteDifferenceStep = 'PerturbationMagnitude';
    aliases.RelativePerturbations = 'PerturbationMagnitudes';
    aliases.PerturbationSizes = 'PerturbationMagnitudes';
    aliases.TypicalStateScale = 'StateScale';
    aliases.PhysicalResidualTolerance = 'TimingResidualTolerance';
    aliases.EventResidualTolerance = 'TimingResidualTolerance';
    aliases.EventTimingRepeatabilityTolerance = 'TimingRepeatabilityTolerance';
    aliases.EventTopologyMode = 'TopologyMode';
    aliases.EventClusterTolerance = 'TopologyClusterTolerance';
    aliases.ThrowOnFailure = 'ErrorOnFailure';
end

function canonical = MatchCanonicalName(name, canonicalNames, aliases)
    canonical = '';
    index = find(strcmpi(name, canonicalNames), 1);
    if ~isempty(index)
        canonical = canonicalNames{index};
        return;
    end

    aliasNames = fieldnames(aliases);
    index = find(strcmpi(name, aliasNames), 1);
    if ~isempty(index)
        canonical = aliases.(aliasNames{index});
    end
end

function options = ValidateOptions(options)
    if ~isa(options.DynamicsFunction, 'function_handle')
        error('ResolveFloquetOptions:InvalidDynamicsFunction', ...
            'DynamicsFunction must be a function handle.');
    end
    if ~(iscell(options.Constraints) || isstruct(options.Constraints))
        error('ResolveFloquetOptions:InvalidConstraints', ...
            'Constraints must be a cell array or structure accepted by the dynamics function.');
    end

    immutableIndices = [1 2 4:13];
    if ~isequal(options.ReducedStateIndices(:).', immutableIndices)
        error('ResolveFloquetOptions:InvalidReduction', ...
            'ReducedStateIndices is fixed to [1 2 4:13].');
    end
    if ~isequal(options.SectionStateIndex, 3)
        error('ResolveFloquetOptions:InvalidSectionIndex', ...
            'SectionStateIndex is fixed to X(3)=dy.');
    end
    if ~isequal(options.VerticalGRFColumns(:).', 9:12)
        error('ResolveFloquetOptions:InvalidGRFColumns', ...
            'VerticalGRFColumns is fixed to 9:12 for the production GRFs output.');
    end

    scalarPositive = { ...
        'PerturbationMagnitude', 'MinimumAbsoluteStep', ...
        'PeriodicResidualTolerance', 'TimingResidualTolerance', ...
        'TimingRepeatabilityTolerance', ...
        'SectionTolerance', 'StrideTimeTolerance', ...
        'TrajectoryConsistencyTolerance', ...
        'TopologyClusterTolerance', 'DerivativeConvergenceTolerance', ...
        'ForwardBackwardTolerance'};
    for i = 1:numel(scalarPositive)
        name = scalarPositive{i};
        value = options.(name);
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value > 0)
            error('ResolveFloquetOptions:InvalidPositiveScalar', ...
                '%s must be a positive finite scalar.', name);
        end
    end

    scalarNonnegative = {'ApexAccelerationTolerance', ...
        'TopologyOrderTolerance'};
    for i = 1:numel(scalarNonnegative)
        name = scalarNonnegative{i};
        value = options.(name);
        if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value >= 0)
            error('ResolveFloquetOptions:InvalidNonnegativeScalar', ...
                '%s must be a nonnegative finite scalar.', name);
        end
    end

    if ~(isnumeric(options.Gravity) && isscalar(options.Gravity) && ...
            isfinite(options.Gravity) && options.Gravity > 0)
        error('ResolveFloquetOptions:InvalidGravity', ...
            'Gravity must be a positive finite scalar.');
    end

    if ~isempty(options.PerturbationMagnitudes)
        magnitudes = options.PerturbationMagnitudes(:).';
    else
        factors = options.PerturbationFactors(:).';
        if isempty(factors) || any(~isfinite(factors)) || any(factors <= 0)
            error('ResolveFloquetOptions:InvalidPerturbationFactors', ...
                'PerturbationFactors must contain positive finite values.');
        end
        magnitudes = options.PerturbationMagnitude .* factors;
    end
    if numel(magnitudes) < 2 || any(~isfinite(magnitudes)) || any(magnitudes <= 0)
        error('ResolveFloquetOptions:InvalidPerturbationMagnitudes', ...
            'At least two positive finite perturbation magnitudes are required.');
    end
    magnitudes = unique(magnitudes, 'sorted');
    magnitudes = fliplr(magnitudes); % coarse to fine
    if numel(magnitudes) < 2
        error('ResolveFloquetOptions:InsufficientDistinctSteps', ...
            'At least two distinct perturbation magnitudes are required.');
    end
    options.PerturbationMagnitudes = magnitudes;

    scale = options.StateScale(:);
    if ~(isnumeric(scale) && (isscalar(scale) || numel(scale) == 12) && ...
            all(isfinite(scale)) && all(scale > 0))
        error('ResolveFloquetOptions:InvalidStateScale', ...
            'StateScale must be a positive scalar or a 12-element positive vector.');
    end
    if isscalar(scale)
        scale = repmat(scale, 12, 1);
    end
    options.StateScale = scale;

    if isstring(options.TopologyMode) && isscalar(options.TopologyMode)
        options.TopologyMode = char(options.TopologyMode);
    end
    if ~ischar(options.TopologyMode) || ...
            ~any(strcmpi(options.TopologyMode, {'strict','clustered'}))
        error('ResolveFloquetOptions:InvalidTopologyMode', ...
            'TopologyMode must be ''strict'' or ''clustered''.');
    end
    options.TopologyMode = lower(options.TopologyMode);

    logicalFields = {'SuppressDynamicsOutput', 'StoreTrajectories', ...
        'CheckTimingRepeatability', ...
        'RejectOnDerivativeNonconvergence', ...
        'RejectOnForwardBackwardMismatch', 'StopOnFirstFailure', ...
        'ErrorOnFailure'};
    for i = 1:numel(logicalFields)
        name = logicalFields{i};
        value = options.(name);
        if ~(islogical(value) && isscalar(value)) && ...
                ~(isnumeric(value) && isscalar(value) && any(value == [0 1]))
            error('ResolveFloquetOptions:InvalidLogical', ...
                '%s must be a scalar logical value.', name);
        end
        options.(name) = logical(value);
    end

    if ~isempty(options.ReferenceTopology) && ~isstruct(options.ReferenceTopology)
        error('ResolveFloquetOptions:InvalidReferenceTopology', ...
            'ReferenceTopology must be empty or a topology structure.');
    end
end
