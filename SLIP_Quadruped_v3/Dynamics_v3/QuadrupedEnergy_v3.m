classdef QuadrupedEnergy_v3
    %QUADRUPEDENERGY_V3 Body and contacting massless-leg spring energy.
    % Infinite inertia returns reduced energy, never Inf*zero arithmetic.

    methods (Static)
        function [energy, report] = evaluate(x, q, p)
            schema = QuadrupedSchema_v3.shared();
            x = schema.validateState(x);
            q = schema.validateMode(q);
            p = schema.validateParameter(p);
            expanded = schema.expandParameters(p);
            state = schema.State;
            theta = x(state.phi) + x(schema.Leg.AngleIndices);
            height = x(state.y) + expanded.s .* sin(x(state.phi));
            physical = QuadrupedPhysicalChart_v3.report(x, q, p);
            kinetic = 0.5 * (x(state.dx)^2 + x(state.dy)^2);
            infiniteInertia = isinf(expanded.j_pitch);
            if ~infiniteInertia
                kinetic = kinetic + 0.5 * expanded.j_pitch * x(state.dphi)^2;
            end
            compression = zeros(schema.Leg.Count, 1);
            compression(logical(q)) = expanded.l_0(logical(q)) ...
                - height(logical(q)) ./ cos(theta(logical(q)));
            springs = 0.5 * expanded.k_l .* compression.^2;
            energy = kinetic + x(state.y) + sum(springs);
            gradient = zeros(state.Dimension, 1);
            gradient(state.dx) = x(state.dx);
            gradient(state.dy) = x(state.dy);
            gradient(state.y) = 1;
            if ~infiniteInertia
                gradient(state.dphi) = expanded.j_pitch * x(state.dphi);
            end
            for leg = find(q(:)).'
                force = expanded.k_l(leg) * compression(leg);
                secant = 1 / cos(theta(leg));
                angularLengthDerivative = height(leg) ...
                    * secant * tan(theta(leg));
                gradient(state.y) = gradient(state.y) - force * secant;
                gradient(state.phi) = gradient(state.phi) - force ...
                    * (expanded.s(leg) * cos(x(state.phi)) * secant ...
                    + angularLengthDerivative);
                gradient(schema.Leg.AngleIndices(leg)) = ...
                    -force * angularLengthDerivative;
            end
            dynamics = ContinuousDynamics_v3(schema);
            [flow, flowReport] = dynamics.evaluate(0, x, q, p);
            predictedRate = 0;
            if infiniteInertia
                predictedRate = -flowReport.pitch_torque * x(state.dphi);
            end
            report = struct('gradient', gradient, ...
                'kinetic_energy', kinetic, 'gravity_energy', x(state.y), ...
                'stance_spring_energy_per_leg', springs, ...
                'infinite_pitch_inertia', infiniteInertia, ...
                'energy_definition', 'body-plus-stance-springs', ...
                'flow_energy_rate', gradient.' * flow, ...
                'predicted_flow_energy_rate', predictedRate, ...
                'conservation_identity_residual', gradient.' * flow - predictedRate, ...
                'conservation_applicable', ~infiniteInertia || x(state.dphi) == 0, ...
                'physical_mode_report', physical);
        end
    end
end
