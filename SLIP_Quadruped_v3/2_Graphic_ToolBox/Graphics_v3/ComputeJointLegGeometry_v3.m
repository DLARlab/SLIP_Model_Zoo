function geometry = ComputeJointLegGeometry_v3(t, x, q, p)
%COMPUTEJOINTLEGGEOMETRY_V3 Physical body, hip, leg, and foot geometry.
%   GEOMETRY = COMPUTEJOINTLEGGEOMETRY_V3(T,X,Q,P) uses the v3 schema and
%   the recorded contact mode Q=[BL,BR,FL,FR].  It never reconstructs
%   contact from scheduled touchdown/liftoff times.
%
%   Adapted conceptually from ComputeJoint_LegLA.m in the v2 graphics
%   toolbox.  The packed legacy P data contract has intentionally been
%   removed.

schema = QuadrupedSchema_v3();
p = GraphicsDataAdapter_v3.parameterVector(p);
expanded = schema.expandParameters(p);
x = double(x(:));
q = logical(q(:));

if numel(x) ~= schema.State.Dimension || any(~isfinite(x))
    error('ComputeJointLegGeometry_v3:InvalidState', ...
        'X must be a finite v3 quadruped state.');
end
if numel(q) ~= schema.Leg.Count
    error('ComputeJointLegGeometry_v3:InvalidMode', ...
        'Q must contain one contact bit per schema leg.');
end
if ~(isscalar(t) && isfinite(t))
    error('ComputeJointLegGeometry_v3:InvalidTime', ...
        'T must be a finite scalar.');
end

bodyPosition = x([schema.State.x, schema.State.y]);
phi = x(schema.State.phi);
alpha = x(schema.Leg.AngleIndices);
absoluteAngles = phi + alpha;

hipPositions = bodyPosition + ...
    [cos(phi); sin(phi)] * expanded.s.';
legLengths = expanded.l_0;
stance = find(q).';
singularityTolerance = 1e-10;
for leg = stance
    denominator = cos(absoluteAngles(leg));
    if abs(denominator) <= singularityTolerance
        error('ComputeJointLegGeometry_v3:SingularStanceGeometry', ...
            'Stance leg %s is horizontal.', schema.Leg.Names{leg});
    end
    legLengths(leg) = hipPositions(2, leg) / denominator;
end
if any(~isfinite(legLengths)) || any(legLengths <= 0)
    error('ComputeJointLegGeometry_v3:InvalidLegLength', ...
        'Computed leg lengths must be positive and finite.');
end

footDirections = [sin(absoluteAngles).'; -cos(absoluteAngles).'];
footPositions = hipPositions + footDirections .* legLengths.';

geometry = struct( ...
    'time', double(t), ...
    'body_position', bodyPosition, ...
    'body_pose', [bodyPosition; phi], ...
    'hip_positions', hipPositions, ...
    'foot_positions', footPositions, ...
    'absolute_leg_angles', absoluteAngles, ...
    'leg_lengths', legLengths, ...
    'rest_lengths', expanded.l_0, ...
    'compression', expanded.l_0 - legLengths, ...
    'mode', q, ...
    'leg_names', {schema.Leg.Names});
end
