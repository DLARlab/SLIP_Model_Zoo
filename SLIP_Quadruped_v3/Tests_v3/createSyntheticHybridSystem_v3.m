function system = createSyntheticHybridSystem_v3(kind)
%CREATESYNTHETICHYBRIDSYSTEM_V3 Small analytic systems for v3 regression.
%   KIND='ordering' creates a unit-period oscillator whose LO_FR event
%   passes through the apex as p changes sign.  KIND='radial' creates a
%   unit-period attracting radial oscillator with known Floquet multiplier.

    if nargin < 1
        kind = 'ordering';
    end
    switch lower(char(kind))
        case 'ordering'
            config = commonConfiguration();
            config.ModeSet = [0; 1];
            config.FlowFunction = @orderingFlow;
            config.ActiveGuardsFunction = @orderingGuards;
            config.ResetFunction = @(eventId, t, x, q, p) x;
            config.TransitionFunction = @orderingTransition;
        case 'radial'
            config = commonConfiguration();
            config.ModeSet = 0;
            config.FlowFunction = @radialFlow;
            config.ActiveGuardsFunction = ...
                @(t, x, q, p) struct([]);
            config.ResetFunction = @(eventId, t, x, q, p) x;
            config.TransitionFunction = @(eventId, q) q;
        otherwise
            error('createSyntheticHybridSystem_v3:UnknownKind', ...
                'Unknown synthetic system kind "%s".', char(kind));
    end
    system = HybridSystemBase_v3(config);
end

function config = commonConfiguration()
    config = struct();
    config.StateDimension = 2;
    config.ParameterDimension = 1;
    config.StateNames = {'c', 's'};
    config.ParameterNames = {'mu'};
    config.PhaseIndex = 2;
    config.DefaultUnknownIndices = [1, 2];
    config.DefaultPeriodicIndices = 1;
    config.DefaultTangentIndices = 1;
    config.CanonicalizeFunction = @(x, p) x;
end

function dx = orderingFlow(t, x, q, p) %#ok<INUSD>
    omega = 2 * pi;
    dx = [omega * x(2); -omega * x(1)];
end

function dx = radialFlow(t, x, q, p) %#ok<INUSD>
    omega = 2 * pi;
    gamma = p(1);
    radiusSquared = x(1)^2 + x(2)^2;
    radial = gamma * (1 - radiusSquared);
    dx = [radial * x(1) + omega * x(2); ...
          radial * x(2) - omega * x(1)];
end

function guards = orderingGuards(t, x, q, p) %#ok<INUSD>
    prototype = struct( ...
        'id', 0, 'name', '', 'value', 0, 'direction', 1, ...
        'isterminal', true, 'enabled', true, 'priority', 0, ...
        'kind', '', 'interior_sign', -1, ...
        'leg_index', 1, 'leg_name', 'FR', 'metadata', struct());
    if q == 0
        guards = prototype;
        guards.id = 1;
        guards.name = 'FR_TD';
        guards.value = x(2);
        guards.priority = 1;
        guards.kind = 'touchdown';
    else
        guards = prototype;
        guards.id = 2;
        guards.name = 'FR_LO';
        angle = 2 * pi * p(1);
        guards.value = -x(2) * cos(angle) - x(1) * sin(angle);
        guards.priority = 2;
        guards.kind = 'liftoff';
    end
    guards.metadata = struct('leg_index', 1, 'leg_name', 'FR', ...
        'event_kind', guards.kind, 'source', 'contact');
end

function qplus = orderingTransition(eventId, qminus)
    if eventId == 1 && qminus == 0
        qplus = 1;
    elseif eventId == 2 && qminus == 1
        qplus = 0;
    else
        error('createSyntheticHybridSystem_v3:InvalidTransition', ...
            'Event %d is not enabled in mode %d.', eventId, qminus);
    end
end
