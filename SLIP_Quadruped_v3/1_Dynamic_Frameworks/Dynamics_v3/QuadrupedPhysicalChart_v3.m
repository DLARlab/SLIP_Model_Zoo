classdef QuadrupedPhysicalChart_v3
    %QUADRUPEDPHYSICALCHART_V3 Independent coordinates on a contact mode.
    % Stance angular rates are dependent fixed-foot coordinates. This
    % utility does not decide admissibility, event order, or return policy.

    methods (Static)
        function chart = create(x, q, p, options)
            if nargin < 4
                options = struct();
            end
            schema = QuadrupedSchema_v3.shared();
            x = schema.validateState(x);
            q = schema.validateMode(q);
            p = schema.validateParameter(p);
            defaults = struct('TranslationGauge', true, ...
                'ApexSection', true, 'ConstraintTolerance', 1e-8);
            names = fieldnames(options);
            for index = 1:numel(names)
                if ~isfield(defaults, names{index})
                    error('QuadrupedPhysicalChart_v3:InvalidOption', ...
                        'Unknown chart option %s.', names{index});
                end
                defaults.(names{index}) = options.(names{index});
            end
            if ~(islogical(defaults.TranslationGauge) ...
                    && isscalar(defaults.TranslationGauge) ...
                    && islogical(defaults.ApexSection) ...
                    && isscalar(defaults.ApexSection) ...
                    && isnumeric(defaults.ConstraintTolerance) ...
                    && isscalar(defaults.ConstraintTolerance) ...
                    && isfinite(defaults.ConstraintTolerance) ...
                    && defaults.ConstraintTolerance > 0)
                error('QuadrupedPhysicalChart_v3:InvalidOption', ...
                    'Chart flags must be logical and tolerance positive.');
            end
            report = QuadrupedPhysicalChart_v3.report(x, q, p);
            if report.maximum_constraint_residual > defaults.ConstraintTolerance
                error('QuadrupedPhysicalChart_v3:OffManifold', ...
                    'Retract explicitly before constructing a physical chart.');
            end
            if defaults.ApexSection ...
                    && abs(x(schema.State.dy)) > defaults.ConstraintTolerance
                error('QuadrupedPhysicalChart_v3:OffSection', ...
                    'An apex chart requires dy=0.');
            end
            dependent = schema.Leg.RateIndices(logical(q));
            fixed = [];
            if defaults.TranslationGauge
                fixed(end + 1) = schema.State.x;
            end
            if defaults.ApexSection
                fixed(end + 1) = schema.State.dy;
            end
            independent = setdiff(1:schema.State.Dimension, ...
                [dependent, fixed], 'stable');
            chart = struct('chart_id', 'quadruped-mode-physical-v3-1', ...
                'reference_state', x, 'mode', q, 'parameters', p, ...
                'independent_indices', independent, ...
                'dependent_indices', dependent, 'fixed_indices', fixed, ...
                'dimension', numel(independent), 'options', defaults, ...
                'schema_metadata', schema.metadata());
        end

        function x = retract(x, q, p)
            schema = QuadrupedSchema_v3.shared();
            x = schema.validateState(x);
            q = schema.validateMode(q);
            p = schema.validateParameter(p);
            reset = ResetMap_v3(schema);
            for leg = find(q(:)).'
                x(schema.Leg.RateIndices(leg)) = ...
                    reset.projectedAngularRate(x, leg, p);
            end
        end

        function x = lift(chart, u)
            if ~(isnumeric(u) && isreal(u) && isvector(u) ...
                    && numel(u) == chart.dimension && all(isfinite(u(:))))
                error('QuadrupedPhysicalChart_v3:InvalidCoordinates', ...
                    'Coordinates must be a finite vector of chart dimension.');
            end
            x = chart.reference_state;
            x(chart.independent_indices) = u(:);
            x = QuadrupedPhysicalChart_v3.retract( ...
                x, chart.mode, chart.parameters);
        end

        function u = coordinates(chart, x)
            schema = QuadrupedSchema_v3.shared();
            x = schema.validateState(x);
            report = QuadrupedPhysicalChart_v3.report( ...
                x, chart.mode, chart.parameters);
            tolerance = chart.options.ConstraintTolerance;
            if report.maximum_constraint_residual > tolerance
                error('QuadrupedPhysicalChart_v3:OffManifold', ...
                    'State is outside the physical mode manifold.');
            end
            if any(abs(x(chart.fixed_indices) ...
                    - chart.reference_state(chart.fixed_indices)) > tolerance)
                error('QuadrupedPhysicalChart_v3:OffSection', ...
                    'State violates a fixed section/gauge coordinate.');
            end
            u = x(chart.independent_indices);
        end

        function [basis, diagnostics] = tangentBasis(chart)
            % Derivative of the explicit local lift, with step-halving check.
            u = chart.reference_state(chart.independent_indices);
            coarse = zeros(numel(chart.reference_state), chart.dimension);
            fine = coarse;
            for index = 1:chart.dimension
                step = 1e-5 * max(1, abs(u(index)));
                direction = zeros(chart.dimension, 1);
                direction(index) = step;
                coarse(:, index) = ( ...
                    QuadrupedPhysicalChart_v3.lift(chart, u + direction) ...
                    - QuadrupedPhysicalChart_v3.lift(chart, u - direction)) ...
                    / (2 * step);
                fine(:, index) = ( ...
                    QuadrupedPhysicalChart_v3.lift(chart, u + direction / 2) ...
                    - QuadrupedPhysicalChart_v3.lift(chart, u - direction / 2)) ...
                    / step;
            end
            basis = (4 * fine - coarse) / 3;
            diagnostics = struct('method', 'lift-central-richardson', ...
                'step_halving_error', norm(fine - coarse, inf), ...
                'dimension', chart.dimension, ...
                'removed_stance_rate_indices', chart.dependent_indices, ...
                'fixed_indices', chart.fixed_indices);
        end

        function report = report(x, q, p)
            schema = QuadrupedSchema_v3.shared();
            x = schema.validateState(x);
            q = schema.validateMode(q);
            p = schema.validateParameter(p);
            expanded = schema.expandParameters(p);
            phi = x(schema.State.phi);
            theta = phi + x(schema.Leg.AngleIndices);
            height = x(schema.State.y) + expanded.s .* sin(phi);
            anchors = NaN(schema.Leg.Count, 1);
            projected = x(schema.Leg.RateIndices);
            constraints = zeros(schema.Leg.Count, 1);
            reset = ResetMap_v3(schema);
            for leg = find(q(:)).'
                projected(leg) = reset.projectedAngularRate(x, leg, p);
                constraints(leg) = x(schema.Leg.RateIndices(leg)) ...
                    - projected(leg);
                anchors(leg) = x(schema.State.x) ...
                    + expanded.s(leg) * cos(phi) ...
                    + height(leg) * tan(theta(leg));
            end
            report = struct('stance_constraints', constraints, ...
                'maximum_constraint_residual', max(abs(constraints)), ...
                'projected_leg_rates', projected, ...
                'stance_anchors', anchors, ...
                'mode_dimension', schema.State.Dimension - nnz(q), ...
                'translation_apex_dimension', ...
                    schema.State.Dimension - nnz(q) - 2);
        end

        function diagnostics = flowTangency(x, q, p)
            % Numerically verify DC*f=0 and Dxi*f=0 at a physical state.
            schema = QuadrupedSchema_v3.shared();
            x = schema.validateState(x);
            q = schema.validateMode(q);
            p = schema.validateParameter(p);
            dynamics = ContinuousDynamics_v3(schema);
            flow = dynamics.evaluate(0, x, q, p);
            step = 2e-6 / max(1, norm(flow, inf));
            plus = QuadrupedPhysicalChart_v3.report(x + step * flow, q, p);
            minus = QuadrupedPhysicalChart_v3.report(x - step * flow, q, p);
            constraintRate = (plus.stance_constraints ...
                - minus.stance_constraints) / (2 * step);
            anchorRate = (plus.stance_anchors ...
                - minus.stance_anchors) / (2 * step);
            diagnostics = struct('constraint_flow_derivative', constraintRate, ...
                'anchor_flow_derivative', anchorRate, ...
                'maximum_constraint_tangency_residual', ...
                    max(abs(constraintRate)), ...
                'maximum_anchor_tangency_residual', ...
                    max([0; abs(anchorRate(logical(q)))]), ...
                'finite_difference_step', step);
        end
    end
end
