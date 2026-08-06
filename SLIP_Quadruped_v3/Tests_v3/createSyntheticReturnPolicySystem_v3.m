function system = createSyntheticReturnPolicySystem_v3(kind)
%CREATESYNTHETICRETURNPOLICYSYSTEM_V3 Policy and chart regression systems.
%   TWO-APEX toggles one contact at the same phase once per geometric return,
%   so a complete TD/LO event cycle requires two downward section crossings.
%   COINCIDENT places those contact events exactly on the section. RESOLVER
%   has two contact coordinates but only its first guard is section-near.

    if nargin < 1
        kind = 'two-apex';
    end
    config = commonConfiguration();
    switch lower(char(kind))
        case 'two-apex'
            config.ModeSet = [0; 1];
            config.ActiveGuardsFunction = ...
                @(t, x, q, p) cycleGuard(x, q, false);
            config.TransitionFunction = @cycleTransition;
        case 'two-apex-radial'
            config.ParameterDimension = 1;
            config.ParameterNames = {'gamma'};
            config.ModeSet = [0; 1];
            config.FlowFunction = @radialFlow;
            config.ActiveGuardsFunction = ...
                @(t, x, q, p) cycleGuard(x, q, false);
            config.TransitionFunction = @cycleTransition;
        case 'coincident'
            config.ModeSet = [0; 1];
            config.ActiveGuardsFunction = ...
                @(t, x, q, p) cycleGuard(x, q, true);
            config.TransitionFunction = @cycleTransition;
        case 'resolver'
            config.ModeSet = logical([0, 0; 0, 1; 1, 0; 1, 1]);
            config.ModeValidator = @validateResolverMode;
            config.ActiveGuardsFunction = @resolverGuards;
            config.TransitionFunction = @resolverTransition;
        otherwise
            error('createSyntheticReturnPolicySystem_v3:UnknownKind', ...
                'Unknown synthetic return-policy system "%s".', char(kind));
    end
    system = HybridSystemBase_v3(config);
end

function dx = radialFlow(t, x, q, p) %#ok<INUSD>
    omega = 2 * pi;
    radiusSquared = x(1)^2 + x(2)^2;
    radialRate = p(1) * (1 - radiusSquared);
    dx = [radialRate * x(1) + omega * x(2); ...
          radialRate * x(2) - omega * x(1)];
end

function config = commonConfiguration()
    config = struct();
    config.StateDimension = 2;
    config.ParameterDimension = 0;
    config.StateNames = {'c', 's'};
    config.ParameterNames = {};
    config.PhaseIndex = 2;
    config.DefaultUnknownIndices = [1, 2];
    config.DefaultPeriodicIndices = 1;
    config.DefaultTangentIndices = 1;
    config.FlowFunction = @(t, x, q, p) ...
        [2 * pi * x(2); -2 * pi * x(1)];
    config.ResetFunction = @(eventId, t, x, q, p) x;
    config.CanonicalizeFunction = @(x, p) x;
end

function guard = cycleGuard(x, q, coincident)
    q = logical(q);
    isTouchdown = ~q;
    guard = guardPrototype();
    guard.id = 1 + double(q);
    guard.enabled = true;
    guard.leg_index = 1;
    guard.leg_name = 'L1';
    guard.direction = -1;
    guard.interior_sign = 1;
    if coincident
        guard.value = x(2);
    else
        guard.value = x(1);
    end
    if isTouchdown
        guard.name = 'L1_TD';
        guard.kind = 'touchdown';
    else
        guard.name = 'L1_LO';
        guard.kind = 'liftoff';
    end
    guard.metadata = struct('leg_index', 1, 'leg_name', 'L1', ...
        'event_kind', guard.kind, 'source', 'contact');
end

function qplus = cycleTransition(eventId, qminus)
    expected = 1 + double(logical(qminus));
    if eventId ~= expected
        error('createSyntheticReturnPolicySystem_v3:CycleTransition', ...
            'Event is inconsistent with the current contact mode.');
    end
    qplus = double(~logical(qminus));
end

function guards = resolverGuards(t, x, q, p) %#ok<INUSD>
    q = validateResolverMode(q);
    guards = repmat(guardPrototype(), 2, 1);
    for leg = 1:2
        isTouchdown = ~q(leg);
        guards(leg).id = 2 * leg - double(isTouchdown);
        guards(leg).enabled = true;
        guards(leg).leg_index = leg;
        guards(leg).leg_name = sprintf('L%d', leg);
        guards(leg).direction = -1;
        guards(leg).interior_sign = 1;
        guards(leg).value = x(2) + (leg - 1);
        if isTouchdown
            guards(leg).name = sprintf('L%d_TD', leg);
            guards(leg).kind = 'touchdown';
        else
            guards(leg).name = sprintf('L%d_LO', leg);
            guards(leg).kind = 'liftoff';
        end
        guards(leg).metadata = struct('leg_index', leg, ...
            'leg_name', guards(leg).leg_name, ...
            'event_kind', guards(leg).kind, 'source', 'contact');
    end
end

function qplus = resolverTransition(eventId, qminus)
    qminus = validateResolverMode(qminus);
    leg = ceil(eventId / 2);
    if leg < 1 || leg > 2
        error('createSyntheticReturnPolicySystem_v3:ResolverTransition', ...
            'Unknown resolver event.');
    end
    isTouchdown = mod(eventId, 2) == 1;
    if qminus(leg) == isTouchdown
        error('createSyntheticReturnPolicySystem_v3:ResolverTransition', ...
            'Resolver event is inconsistent with the current mode.');
    end
    qplus = qminus;
    qplus(leg) = isTouchdown;
end

function q = validateResolverMode(q)
    if ~(isnumeric(q) || islogical(q)) || numel(q) ~= 2 ...
            || any(~ismember(double(q(:)), [0, 1]))
        error('createSyntheticReturnPolicySystem_v3:Mode', ...
            'Resolver mode must be a two-entry binary contact vector.');
    end
    q = logical(q(:));
end

function guard = guardPrototype()
    guard = struct( ...
        'id', 0, 'name', '', 'value', 0, 'direction', 0, ...
        'isterminal', true, 'terminal', true, 'enabled', true, ...
        'leg_index', 0, 'leg_name', '', 'kind', '', 'priority', 0, ...
        'source', 'contact', 'interior_sign', 0, ...
        'directional_derivative', NaN, 'metadata', struct());
end
