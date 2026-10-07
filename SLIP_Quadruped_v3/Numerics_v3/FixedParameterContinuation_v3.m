classdef FixedParameterContinuation_v3
    %FIXEDPARAMETERCONTINUATION_V3 Energy family using the shared PAL engine.
    methods (Static)
        function [branch,family] = run(problem,uSeed,p,q,options)
            if nargin < 5, options = struct(); end
            symmetry = 'none';
            if isfield(options,'Symmetry')
                symmetry = options.Symmetry; options = rmfield(options,'Symmetry');
            end
            seedState = problem.fullState(uSeed);
            family = EnergyFamilyResidual_v3(problem,seedState,q,p,struct('Symmetry',symmetry));
            coords = family.packState(seedState);
            energy = QuadrupedEnergy_v3.evaluate(seedState,q,p);
            options.ActiveParameterIndex = 11;
            options.ActiveParameter = [];
            options.ComputeStability = false;
            engine = PseudoArclengthContinuation_v3(options);
            branch = engine.run(family,coords,[p(:);energy],q);
            branch.family_coordinate = 'body-plus-stance-spring-energy';
            branch.physical_parameter = p(:);
            branch.symmetry_restriction = symmetry;
            branch.energy = arrayfun(@(point) point.p(11),branch.points);
            branch.augmented_parameter_note = 'p(11) is family energy; physical model p remains p(1:10).';
        end
        function [orbit,report] = secondSeed(problem,uSeed,p,q,distance,options)
            % Correct a sphere in independent scaled physical coordinates.
            if nargin < 6, options = struct(); end
            if ~(isscalar(distance) && isfinite(distance) && distance>0)
                error('FixedParameterContinuation_v3:Distance','Distance must be positive.');
            end
            symmetry='none';if isfield(options,'Symmetry'),symmetry=options.Symmetry;end
            family=EnergyFamilyResidual_v3(problem,problem.fullState(uSeed),q,p,struct('Symmetry',symmetry));
            origin=family.packState(problem.fullState(uSeed));
            scale=max(1,abs(origin));
            direction=zeros(size(origin));direction(family.EnergyPivot)=1;
            if isfield(options,'Direction'),direction=options.Direction(:);end
            direction=direction./norm(direction);
            guess=origin+distance*(scale.*direction);
            solverOptions=struct('MaxIterations',20,'MaxFunctionEvaluations',2000);
            if isfield(options,'SolverOptions'),solverOptions=options.SolverOptions;end
            solver=RootSolver_v3(solverOptions);
            [corrected,report]=solver.solve(@sphereResidual,guess,p,q);
            report.requested_scaled_distance=distance;
            report.actual_scaled_distance=norm((corrected-origin)./scale);
            report.distance_coordinates=family.CoordinateIndices;
            report.scale=scale;
            orbit=[];
            if report.converged
                x=family.fullState(corrected);E=QuadrupedEnergy_v3.evaluate(x,q,p);
                [~,info]=family.evaluateWithInfo(corrected,[p(:);E],q);
                orbit=family.createOrbit(corrected,[p(:);E],q,info);
                report.orbit=orbit;
            end
            function [r,info]=sphereResidual(u,~,~,context)
                if nargin<4,context=struct();end
                x=family.fullState(u);E=QuadrupedEnergy_v3.evaluate(x,q,p);
                [r,info]=family.evaluateWithInfo(u,[p(:);E],q,context);
                r(end)=norm((u-origin)./scale)-distance;
            end
        end
    end
end
