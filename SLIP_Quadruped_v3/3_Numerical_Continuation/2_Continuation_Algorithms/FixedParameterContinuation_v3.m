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
            options.UsePeriodicSolutionSolver = true;
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
            if numel(direction)~=numel(origin)||any(~isfinite(direction))||norm(direction)==0
                error('FixedParameterContinuation_v3:Direction','Direction must be a finite nonzero vector of physical-chart dimension.');
            end
            direction=direction./norm(direction);
            guess=origin+distance*(scale.*direction);
            solverOptions=struct('MaxIterations',20,'MaxFunctionEvaluations',2000);
            if isfield(options,'SolverOptions'),solverOptions=options.SolverOptions;end
            residual=SphereFamilyResidual_v3(family,origin,scale,distance);
            occurrence=1;
            if isa(problem.Map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3')
                occurrence=problem.Map.ReturnPolicy.BLTouchdownsPerReturn;
            end
            seed=struct('state',family.fullState(guess),'mode',q,'parameter',p, ...
                'return_policy',problem.Map.ReturnPolicy,'occurrence',occurrence, ...
                'provenance',struct('kind','sphere-constrained-second-seed', ...
                'origin_state',problem.fullState(uSeed),'sphere_radius',distance));
            serviceOptions=struct('Residual',residual,'Coordinates',guess, ...
                'AugmentedParameter',p,'SolverOptions',solverOptions);
            for key={'MaxWallSeconds','Acceptance','ReplayIntegration'}
                if isfield(options,key{1}),serviceOptions.(key{1})=options.(key{1});end
            end
            [orbit,acceptanceReport]=PeriodicSolutionSolver_v3(seed,serviceOptions);
            report=acceptanceReport.solver;
            report.converged=acceptanceReport.accepted;
            report.periodic_solution_report=acceptanceReport;
            report.orbit=orbit;
            if isfield(acceptanceReport,'final_coordinates')
                corrected=acceptanceReport.final_coordinates;
            else,corrected=family.packState(acceptanceReport.final_candidate);end
            if ~report.converged
                report.message='Sphere correction failed independent acceptance.';
                if isfield(acceptanceReport.primary_failure,'message'),report.message=acceptanceReport.primary_failure.message;
                elseif isfield(acceptanceReport.replay_failure,'message'),report.message=acceptanceReport.replay_failure.message;end
            end
            report.requested_scaled_distance=distance;
            report.actual_scaled_distance=norm((corrected-origin)./scale);
            report.distance_coordinates=family.CoordinateIndices;
            report.scale=scale;
        end
    end
end
