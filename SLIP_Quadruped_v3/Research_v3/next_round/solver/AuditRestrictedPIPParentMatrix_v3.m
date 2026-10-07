function summary=AuditRestrictedPIPParentMatrix_v3(outputDirectory)
%AUDITRESTRICTEDPIPPARENTMATRIX_V3 Production flow and independent map audit.
    v3=V3Root_v3(mfilename('fullpath'));
    V3LegacyAddPath_v3(genpath(V3Path_v3(v3)));if nargin<1,outputDirectory=fileparts(mfilename('fullpath'));end
    outputDirectory=V3OutputPath_v3(outputDirectory);
    p=[10;10;20;20;1;1;0;0;2;.5];s=QuadrupedSchema_v3.shared();
    helper=fullfile(v3,'Numerics_v3','RestrictedPIPParentMatrix_v3.m');
    registration=struct('schema_version','restricted-PIP-variational-registration-v3-1', ...
        'registered_utc',char(datetime('now','TimeZone','UTC')), ...
        'helper_sha256',RoundSHA256_v3(helper),'physical_parameter',p, ...
        'fresh_energies',[1.1,3,8],'relative_matrix_threshold',1e-5, ...
        'flow_generator_absolute_threshold',1e-8,'independent_replay_closure_threshold',1e-8, ...
        'scope','Fixed-energy synchronized pronk parent; no unrestricted derivative claim');
    save(V3Path_v3(fullfile(outputDirectory,'pip_analytic_registration.mat')),'registration','-v7');
    summary=struct('schema_version','restricted-PIP-variational-audit-v3-1','passed',false, ...
        'registration',registration,'recorded_comparisons',struct([]), ...
        'fresh_comparisons',struct([]),'flow_generator_error',NaN,'liftoff_projection_error',NaN, ...
        'integration_refinement_error',NaN,'invalid_parameter_rejected',false, ...
        'invalid_energy_rejected',false,'elapsed_seconds',0);
    timer=tic;flow=ContinuousDynamics_v3();reset=ResetMap_v3();
    derivativeStep=1e-6;flowErrors=[];resetErrors=[];
    for energy=registration.fresh_energies
        [M,analytic]=RestrictedPIPParentMatrix_v3(energy,p);
        [refined,~]=RestrictedPIPParentMatrix_v3(energy,p,struct('RelTol',2e-13,'AbsTol',2e-15));
        summary.integration_refinement_error=max([0,summary.integration_refinement_error,norm(M-refined,2)/max(1,norm(refined,2))]);
        td=analytic.flight_time;om=sqrt(40);a=1/40;
        for tau=[0,.2,.5,.8,1]*analytic.stance_time
            x=zeros(14,1);x(s.State.y)=1-a+a*cos(om*tau)-td/om*sin(om*tau);
            x(s.State.dy)=-a*om*sin(om*tau)-td*cos(om*tau);
            actual=zeros(2);for column=1:2
                plus=x;minus=x;
                if column==1,plus(s.State.dx)=derivativeStep;minus(s.State.dx)=-derivativeStep;
                else,plus(s.Leg.AngleIndices)=derivativeStep;minus(s.Leg.AngleIndices)=-derivativeStep;end
                positive=flow.evaluate(tau,plus,true(4,1),p);negative=flow.evaluate(tau,minus,true(4,1),p);
                actual(:,column)=(positive([s.State.dx,s.Leg.AngleIndices(1)]) ...
                    -negative([s.State.dx,s.Leg.AngleIndices(1)]))/(2*derivativeStep);
            end
            expected=[0,-40*(1-x(s.State.y));-1/x(s.State.y),-x(s.State.dy)/x(s.State.y)];
            flowErrors(end+1)=norm(actual-expected,inf); %#ok<AGROW>
        end
        x=zeros(14,1);x(s.State.y)=1;x(s.State.dy)=td;
        actual=zeros(3,2);for column=1:2
            plus=x;minus=x;
            if column==1,plus(s.State.dx)=derivativeStep;minus(s.State.dx)=-derivativeStep;
            else,plus(s.Leg.AngleIndices)=derivativeStep;minus(s.Leg.AngleIndices)=-derivativeStep;end
            positive=reset.applyBatch([2,4,6,8],0,plus,true(4,1),p);
            negative=reset.applyBatch([2,4,6,8],0,minus,true(4,1),p);
            indices=[s.State.dx,s.Leg.AngleIndices(1),s.Leg.RateIndices(1)];
            actual(:,column)=(positive(indices)-negative(indices))/(2*derivativeStep);
        end
        resetErrors(end+1)=norm(actual-analytic.liftoff_lift,inf); %#ok<AGROW>
    end
    summary.flow_generator_error=max(flowErrors);summary.liftoff_projection_error=max(resetErrors);
    try,RestrictedPIPParentMatrix_v3(2,p+[1;zeros(9,1)]);catch e,summary.invalid_parameter_rejected=strcmp(e.identifier,'RestrictedPIPParentMatrix_v3:Parameters');end
    try,RestrictedPIPParentMatrix_v3(20,p);catch,summary.invalid_energy_rejected=true;end
    % Historical evidence is read as a comparison, never used as a seed.
    for k=1:2
        relative=fullfile('Research_v3','runs','full',sprintf('pronk_predictions_v2_%d.mat',k));
        old=load(V3Path_v3(fullfile(v3,relative)));energy=old.predictions.critical_energy;
        [analytic,~]=RestrictedPIPParentMatrix_v3(energy,p);
        entry=struct('artifact',relative,'artifact_sha256',RoundSHA256_v3(fullfile(v3,relative)), ...
            'energy',energy,'recorded_matrix',old.M,'analytic_matrix',analytic, ...
            'relative_matrix_error',norm(analytic-old.M,2)/max(1,norm(old.M,2)));
        summary.recorded_comparisons=[summary.recorded_comparisons,entry];checkpoint();
    end
    integration=struct('RelTol',1e-11,'AbsTol',1e-13,'MaxStep',.025, ...
        'EventOptions',struct('ValueTolerance',1e-10,'TimeTolerance',1e-12,'SimultaneousTolerance',1e-10));
    map=PoincareMap_v3(Quadrupedal_Dynamics_v3(),PoincareSection_v3.apex(s.State.dy), ...
        HybridSimulator_v3(integration),BLMarkedApexReturnPolicy_v3());
    fd=HybridFiniteDifferenceJacobian_v3(struct('RelativeCandidateSteps',[1e-4,5e-5], ...
        'MaximumRelativeError',1e-3,'FailurePolicy','nan'));
    for energy=registration.fresh_energies
        [M,value,info]=fd.compute(@(v,context)reducedReturn(v,energy,context),zeros(3,1));
        [analytic,details]=RestrictedPIPParentMatrix_v3(energy,p);
        tighter=integration;tighter.RelTol=1e-12;tighter.AbsTol=1e-14;tighter.MaxStep=.0125;
        tighter.EventOptions.ValueTolerance=1e-11;tighter.EventOptions.TimeTolerance=1e-13;
        tighter.EventOptions.SimultaneousTolerance=1e-11;
        fresh=PoincareMap_v3(Quadrupedal_Dynamics_v3(),PoincareSection_v3.apex(s.State.dy), ...
            HybridSimulator_v3(tighter),BLMarkedApexReturnPolicy_v3());
        initial=lift(zeros(3,1),energy);[returned,replay]=fresh.evaluate(initial,false(4,1),p);
        entry=struct('energy',energy,'finite_difference_matrix',M,'analytic_matrix',analytic, ...
            'relative_matrix_error',norm(analytic-M,2)/max(1,norm(M,2)), ...
            'finite_difference_reliable',info.allReliable&&info.classicalDerivative, ...
            'map_evaluations',info.mapEvaluations,'returned_reduced_state',value, ...
            'independent_full_closure',norm(returned(s.DefaultPeriodicIndices)-initial(s.DefaultPeriodicIndices),inf), ...
            'independent_period_error',abs(replay.period-details.period), ...
            'minimum_vertical_height',details.minimum_vertical_height,'derivative_info',info, ...
            'analytic_info',details,'replay_info',replay);
        summary.fresh_comparisons=[summary.fresh_comparisons,entry];checkpoint();
        fprintf('Restricted PIP E %.9g relative derivative error %.3g fresh closure %.3g\n',energy,entry.relative_matrix_error,entry.independent_full_closure);
    end
    summary.passed=summary.flow_generator_error<=registration.flow_generator_absolute_threshold ...
        &&summary.liftoff_projection_error<=registration.flow_generator_absolute_threshold ...
        &&summary.integration_refinement_error<=1e-9 ...
        &&all([summary.recorded_comparisons.relative_matrix_error]<=registration.relative_matrix_threshold) ...
        &&all([summary.fresh_comparisons.relative_matrix_error]<=registration.relative_matrix_threshold) ...
        &&all([summary.fresh_comparisons.finite_difference_reliable]) ...
        &&all([summary.fresh_comparisons.independent_full_closure]<=registration.independent_replay_closure_threshold) ...
        &&summary.invalid_parameter_rejected&&summary.invalid_energy_rejected;
    checkpoint();disp(summary);
    function x=lift(v,E)
        x=zeros(14,1);x(s.State.y)=E-v(1)^2/2;x(s.State.dx)=v(1);
        x(s.Leg.AngleIndices)=v(2);x(s.Leg.RateIndices)=v(3);
    end
    function [value,info]=reducedReturn(v,E,context)
        [returned,info]=map.evaluate(lift(v,E),false(4,1),p,context);
        value=returned([s.State.dx,s.Leg.AngleIndices(1),s.Leg.RateIndices(1)]);
    end
    function checkpoint()
        summary.elapsed_seconds=toc(timer);
        save(V3Path_v3(fullfile(outputDirectory,'pip_analytic_audit.mat')),'summary','-v7');
        compact=summary;
        if ~isempty(compact.fresh_comparisons),compact.fresh_comparisons=rmfield(compact.fresh_comparisons,{'derivative_info','analytic_info','replay_info'});end
        f=fopen(V3Path_v3(fullfile(outputDirectory,'pip_analytic_audit.json')),'w');finish=onCleanup(@()fclose(f));
        fprintf(f,'%s\n',jsonencode(compact,'PrettyPrint',true));
    end
end
