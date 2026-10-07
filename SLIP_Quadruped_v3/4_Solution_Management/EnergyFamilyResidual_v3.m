classdef EnergyFamilyResidual_v3 < handle
    %ENERGYFAMILYRESIDUAL_V3 Independent conservative orbit-family chart.
    % The final augmented parameter is energy, not a physical model parameter.
    % One closure equation is omitted where its energy-gradient component is
    % nonzero. Every corrected orbit still undergoes full-state closure checks.
    properties (SetAccess = private)
        Map
        BaseProblem
        Chart
        CoordinateIndices
        ClosureIndices
        EnergyPivot
        PhysicalParameter
        Symmetry = 'none'
        ClosureTolerance = 1e-8
        EnergyGradientTolerance = 1e-6
    end
    methods
        function obj = EnergyFamilyResidual_v3(problem, x, q, p, options)
            if nargin < 5, options = struct(); end
            if ~isstruct(options) || ~isscalar(options) || ...
                    any(~ismember(fieldnames(options), ...
                    {'Symmetry','ClosureTolerance','EnergyGradientTolerance'}))
                error('EnergyFamilyResidual_v3:Options', 'Unknown family option.');
            end
            if isfield(options, 'Symmetry'), obj.Symmetry = char(options.Symmetry); end
            if isfield(options, 'ClosureTolerance')
                obj.ClosureTolerance = options.ClosureTolerance;
            end
            if isfield(options, 'EnergyGradientTolerance')
                obj.EnergyGradientTolerance = options.EnergyGradientTolerance;
            end
            if ~(isscalar(obj.ClosureTolerance) && isfinite(obj.ClosureTolerance) ...
                    && obj.ClosureTolerance > 0 ...
                    && isscalar(obj.EnergyGradientTolerance) ...
                    && isfinite(obj.EnergyGradientTolerance) ...
                    && obj.EnergyGradientTolerance > 0)
                error('EnergyFamilyResidual_v3:Options', ...
                    'Closure and energy-gradient tolerances must be positive.');
            end
            schema = QuadrupedSchema_v3.shared();
            x = schema.validateState(x);
            q = schema.validateMode(q);
            p = schema.validateParameter(p);
            if ~any(strcmp(obj.Symmetry, {'none','left-right','pronk'}))
                error('EnergyFamilyResidual_v3:Symmetry', 'Unknown symmetry restriction.');
            end
            obj.Map = problem.Map;
            obj.BaseProblem = problem;
            obj.PhysicalParameter = p(:);
            obj.Chart = QuadrupedPhysicalChart_v3.create(x, q, p);
            obj.CoordinateIndices = obj.Chart.independent_indices;
            if strcmp(obj.Symmetry, 'left-right')
                representatives = [schema.Leg.AngleIndices(1),schema.Leg.RateIndices(1), ...
                    schema.Leg.AngleIndices(3),schema.Leg.RateIndices(3)];
                counterparts = [schema.Leg.AngleIndices(2),schema.Leg.RateIndices(2), ...
                    schema.Leg.AngleIndices(4),schema.Leg.RateIndices(4)];
                if q(1) ~= q(2) || q(3) ~= q(4) || ...
                        norm(x(counterparts)-x(representatives),inf) > 1e-8
                    error('EnergyFamilyResidual_v3:NotSymmetric', ...
                        'The explicit left/right chart requires paired states and modes.');
                end
                duplicates = [schema.Leg.AngleIndices([2,4]), ...
                    schema.Leg.RateIndices([2,4])];
                obj.CoordinateIndices = setdiff(obj.CoordinateIndices, duplicates, 'stable');
            elseif strcmp(obj.Symmetry,'pronk')
                parameter = schema.Parameter;
                pairedParameters=p([parameter.k_l_b,parameter.k_s_b, ...
                    parameter.l_l_b,parameter.rsla_b]) ...
                    -p([parameter.k_l_f,parameter.k_s_f,parameter.l_l_f,parameter.rsla_f]);
                if norm(pairedParameters,inf)>1e-12 ...
                        || abs(p(parameter.l_com)-.5)>1e-12 || ...
                        any(q~=q(1)) ...
                        || norm(x([schema.State.phi,schema.State.dphi]),inf)>1e-8 || ...
                        norm(x(schema.Leg.AngleIndices)-x(schema.Leg.AngleIndices(1)),inf)>1e-8 || ...
                        norm(x(schema.Leg.RateIndices)-x(schema.Leg.RateIndices(1)),inf)>1e-8
                    error('EnergyFamilyResidual_v3:NotPronkInvariant', ...
                        'Pronk restriction requires matched front/back parameters, centered COM, zero pitch and synchronous legs.');
                end
                remove=[schema.State.phi,schema.State.dphi, ...
                    schema.Leg.AngleIndices(2:4),schema.Leg.RateIndices(2:4)];
                obj.CoordinateIndices=setdiff(obj.CoordinateIndices,remove,'stable');
            end
            [~, report] = QuadrupedEnergy_v3.evaluate(x,q,p);
            if report.infinite_pitch_inertia
                error('EnergyFamilyResidual_v3:InfiniteInertia', ...
                    'Use a separately restricted zero-pitch-rate chart for infinite inertia.');
            end
            grad = obj.restrictedEnergyGradient(report.gradient);
            [largest, obj.EnergyPivot] = max(abs(grad));
            if largest < obj.EnergyGradientTolerance
                error('EnergyFamilyResidual_v3:SingularEnergyChart', ...
                    'No regular energy coordinate in this section chart.');
            end
            obj.ClosureIndices = setdiff(1:numel(grad),obj.EnergyPivot,'stable');
        end
        function u = packState(obj,x)
            schema = QuadrupedSchema_v3.shared();
            x = schema.validateState(x);
            u = x(obj.CoordinateIndices);
        end
        function x = fullState(obj,u,varargin)
            if numel(u) ~= numel(obj.CoordinateIndices)
                error('EnergyFamilyResidual_v3:Dimension','Wrong independent coordinate dimension.');
            end
            x = obj.Chart.reference_state;
            x(obj.CoordinateIndices) = u(:);
            schema = QuadrupedSchema_v3.shared();
            if strcmp(obj.Symmetry,'left-right')
                x(schema.Leg.AngleIndices([2,4])) = x(schema.Leg.AngleIndices([1,3]));
                x(schema.Leg.RateIndices([2,4])) = x(schema.Leg.RateIndices([1,3]));
            elseif strcmp(obj.Symmetry,'pronk')
                x(schema.Leg.AngleIndices(2:4))=x(schema.Leg.AngleIndices(1));
                x(schema.Leg.RateIndices(2:4))=x(schema.Leg.RateIndices(1));
            end
            x = QuadrupedPhysicalChart_v3.retract(x,obj.Chart.mode,obj.PhysicalParameter);
        end
        function r = evaluate(obj,u,p,q)
            [r,~] = obj.evaluateWithInfo(u,p,q);
        end
        function [r,info] = evaluateWithInfo(obj,u,p,q,context)
            if nargin < 5, context = struct(); end
            p = p(:);
            if numel(p) ~= 11 || ~isequal(p(1:10), obj.PhysicalParameter) ...
                    || ~isfinite(p(11))
                error('EnergyFamilyResidual_v3:PhysicalParameters', ...
                    'Physical parameters are fixed; append only the orbit energy.');
            end
            if ~isequal(logical(q(:)),logical(obj.Chart.mode(:)))
                error('EnergyFamilyResidual_v3:ModeChart', 'A mode change requires an explicit new chart.');
            end
            x = obj.fullState(u);
            [energy, energyReport] = QuadrupedEnergy_v3.evaluate(x,q,p(1:10));
            grad = obj.restrictedEnergyGradient(energyReport.gradient);
            if abs(grad(obj.EnergyPivot)) < obj.EnergyGradientTolerance
                error('EnergyFamilyResidual_v3:EnergyChartBoundary', ...
                    'The selected energy pivot lost regularity; change charts explicitly.');
            end
            [~,info] = obj.BaseProblem.evaluateWithInfo( ...
                obj.BaseProblem.packState(x),p(1:10),q,context);
            delta = info.next_state(obj.CoordinateIndices)-x(obj.CoordinateIndices);
            r = [delta(obj.ClosureIndices);energy-p(11)];
            info.full_physical_closure_residual = info.next_state(2:end)-x(2:end);
            info.full_physical_closure_norm = norm(info.full_physical_closure_residual,inf);
            info.energy = energy;
            info.energy_pivot = obj.CoordinateIndices(obj.EnergyPivot);
            info.energy_pivot_derivative = grad(obj.EnergyPivot);
            info.full_physical_closure_tolerance = obj.ClosureTolerance;
            info.full_physical_closed = info.full_physical_closure_norm <= obj.ClosureTolerance;
            info.symmetry_restriction = obj.Symmetry;
            info.residual_norm = norm(r,inf);
        end
        function [candidates,diagnostics] = modeCandidates(obj,varargin)
            candidates = {obj.Chart.mode};
            diagnostics = struct('mode',obj.Chart.mode,'reason', ...
                'fixed physical section chart','source','physical-chart');
        end
        function orbit = createOrbit(obj,u,p,q,info)
            if nargin < 5, [~,info] = obj.evaluateWithInfo(u,p,q); end
            if info.full_physical_closure_norm > obj.ClosureTolerance
                error('EnergyFamilyResidual_v3:FullClosure', ...
                    'Omitted/dependent closure failed: %.4g.', info.full_physical_closure_norm);
            end
            orbit = obj.BaseProblem.createOrbit(obj.BaseProblem.packState( ...
                obj.fullState(u)),p(1:10),q,info);
        end
    end
    methods (Access = private)
        function gradient = restrictedEnergyGradient(obj, ambientGradient)
            % Pull DE back through the symmetry lift. Dependent stance rates
            % have zero mechanical-energy derivative in this model.
            schema = QuadrupedSchema_v3.shared();
            ambient = ambientGradient(:);
            if strcmp(obj.Symmetry, 'left-right')
                representative = [schema.Leg.AngleIndices([1,3]), ...
                    schema.Leg.RateIndices([1,3])];
                duplicate = [schema.Leg.AngleIndices([2,4]), ...
                    schema.Leg.RateIndices([2,4])];
                ambient(representative) = ambient(representative) + ambient(duplicate);
            elseif strcmp(obj.Symmetry, 'pronk')
                ambient(schema.Leg.AngleIndices(1)) = sum(ambient(schema.Leg.AngleIndices));
                ambient(schema.Leg.RateIndices(1)) = sum(ambient(schema.Leg.RateIndices));
            end
            gradient = ambient(obj.CoordinateIndices);
        end
    end
end
