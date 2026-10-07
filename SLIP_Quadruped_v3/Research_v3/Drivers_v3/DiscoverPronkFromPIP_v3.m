function report=DiscoverPronkFromPIP_v3(configFile,outputDirectory)
%DISCOVERPRONKFROMPIP_V3 Parent-only search in a proved invariant subspace.
% Physical p is fixed. The flight apex energy chart is y=E-dx^2/2.
% Critical directions and validation amplitudes are frozen before correction.
% Prior run files are archived by filename, never loaded as numerical seeds.
% A sign-change scan is bounded evidence and misses tangent/even-multiplicity
% unit multipliers. No derivative across split four-leg contacts is claimed.
    root=V3Root_v3(mfilename('fullpath'));
    originalPath=path;pathCleanup=onCleanup(@()path(originalPath));
    V3LegacyAddPath_v3(root,fullfile(root,'Research_v3','Drivers_v3'));
    folders={'Schema_v3','Dynamics_v3','Simulation_v3','Orbit_v3','Numerics_v3'};
    for k=1:numel(folders),V3LegacyAddPath_v3(fullfile(root,folders{k}));end
    if nargin<1||isempty(configFile)
        configFile=fullfile(root,'Research_v3','config','full.json');
    end
    if nargin<2||isempty(outputDirectory)
        outputDirectory=fullfile(root,'Research_v3','runs','full');
    end
    configFile=V3OutputPath_v3(configFile);
    outputDirectory=V3OutputPath_v3(outputDirectory);
    cfg=jsondecode(fileread(V3Path_v3(configFile)));p=cfg.baseline_v3_parameters(:);
    settings=cfg.parent_only_pronk;s=QuadrupedSchema_v3.shared();
    if ~isequal(p([1,3,5,7]),p([2,4,6,8]))||p(10)~=.5
        error('DiscoverPronkFromPIP_v3:Parameters','Pronk invariant subspace requires matched parameters.');
    end
    validateattributes(settings.scan_points,{'numeric'},{'scalar','integer','>=',2});
    validateattributes(settings.amplitudes,{'numeric'},{'vector','finite','positive'});
    if ~exist(V3Path_v3(outputDirectory),'dir'),mkdir(V3Path_v3(outputDirectory));end
    archiveDirectory=archivePriorRun(outputDirectory);
    system=Quadrupedal_Dynamics_v3();section=PoincareSection_v3.apex(s.State.dy);
    simulator=HybridSimulator_v3(struct('RelTol',settings.relative_tolerance, ...
        'AbsTol',settings.absolute_tolerance));
    map=PoincareMap_v3(system,section,simulator,EventCycleReturnPolicy_v3());
    problem=PeriodicOrbitResidual_v3(map,zeros(14,1));
    replaySimulator=HybridSimulator_v3(struct('RelTol',settings.replay_relative_tolerance, ...
        'AbsTol',settings.replay_absolute_tolerance));
    replayMap=PoincareMap_v3(system,section,replaySimulator,EventCycleReturnPolicy_v3());
    replayProblem=PeriodicOrbitResidual_v3(replayMap,zeros(14,1));
    fd=HybridFiniteDifferenceJacobian_v3(struct( ...
        'RelativeCandidateSteps',settings.derivative_step, ...
        'MaximumRelativeError',settings.derivative_relative_error,'FailurePolicy','nan'));
    fdHalf=fd;fdHalf.RelativeCandidateSteps=settings.derivative_step/2;
    report=struct('schema_version','parent-only-pronk-validation-v3-2', ...
        'model_id',cfg.model_id,'origin','parent-only','physical_parameter',p, ...
        'restriction','pronk invariant subspace; no split-contact derivative claimed', ...
        'domain',cfg.domain,'validation_settings',settings,'status','running', ...
        'parent_samples',struct([]),'brackets',[],'connections',struct([]), ...
        'held_out_daughters_used',false,'prior_run_archive',archiveDirectory, ...
        'scan_scope','det(DP_E-I) sign changes on the registered deterministic grid', ...
        'scan_complete_for_unit_multipliers',false, ...
        'scan_limitations',{{'even-multiplicity or tangent +1 crossings may be missed', ...
        'grid intervals containing an unreliable derivative are not searched', ...
        'only the registered maximum number of sign-change brackets is refined'}}, ...
        'evidence_limitations',{{'finite-difference errors are estimates, not rigorous bounds', ...
        'C2/C3 regularity of the synchronized return chart is a conditional hypothesis', ...
        'restricted attachments do not establish the full quadruped gait network'}});
    timer=tic;energies=linspace(cfg.domain.energy(1),cfg.domain.energy(2),settings.scan_points);
    determinants=nan(size(energies));
    for k=1:numel(energies)
        [matrix,~,info]=parentMatrix(energies(k),fd);
        reliable=info.allReliable && info.classicalDerivative;
        sample=struct('energy',energies(k),'reliable',reliable,'det_DP_minus_I',NaN, ...
            'multipliers_real',[],'multipliers_imag',[], ...
            'derivative',derivativeSummary(matrix,info));
        if reliable
            determinants(k)=det(matrix-eye(3));lambda=eig(matrix);
            sample.det_DP_minus_I=determinants(k);
            sample.multipliers_real=real(lambda);sample.multipliers_imag=imag(lambda);
        end
        if isempty(report.parent_samples),report.parent_samples=sample;
        else,report.parent_samples(end+1)=sample;end
        checkpoint();
        fprintf('PIP parent E %.9g: det %.9g reliable %d\n',energies(k),determinants(k),reliable);
        if budgetExpired(),report.status='budget_exhausted';checkpoint();return;end
    end
    brackets=find(determinants(1:end-1).*determinants(2:end)<0);
    report.brackets=energies([brackets(:),brackets(:)+1]);
    report.sign_change_bracket_count=numel(brackets);
    report.unrefined_bracket_count=max(0,numel(brackets)-settings.maximum_connections);
    for bracketIndex=1:min(numel(brackets),settings.maximum_connections)
        index=brackets(bracketIndex);left=energies(index);right=energies(index+1);fl=determinants(index);
        maxRefinements=ceil(log2((right-left)/settings.energy_bracket_tolerance))+2;
        for iteration=1:max(1,maxRefinements)
            mid=(left+right)/2;[M,~,di]=parentMatrix(mid,fd);
            if ~di.allReliable||~di.classicalDerivative
                report.status='unreliable_critical_refinement';checkpoint();return;
            end
            fm=det(M-eye(3));
            if fl*fm<=0,right=mid;else,left=mid;fl=fm;end
            if right-left<settings.energy_bracket_tolerance,break;end
            if budgetExpired(),report.status='budget_exhausted_during_refinement';checkpoint();return;end
        end
        critical=(left+right)/2;
        [MCoarse,~,coarseInfo]=parentMatrix(critical,fd);
        [M,~,di]=parentMatrix(critical,fdHalf);
        if ~di.allReliable||~di.classicalDerivative||any(~isfinite(M(:)))
            report.status='unreliable_critical_derivative';checkpoint();return;
        end
        [U,D,V]=svd(M-eye(3));direction=V(:,end);leftKernel=U(:,end);
        [~,lead]=max(abs(direction));if direction(lead)<0,direction=-direction;end
        [~,lead]=max(abs(leftKernel));if leftKernel(lead)<0,leftKernel=-leftKernel;end
        matrixUncertainty=max([norm(M-MCoarse,2), ...
            matrixErrorEstimate(M,di),matrixErrorEstimate(MCoarse,coarseInfo)]);
        transversality=estimateTransversality(critical,direction,leftKernel,matrixUncertainty,D(2,2));
        criticalEnergyUncertainty=(right-left)/2;
        if abs(transversality.estimate)>transversality.uncertainty_estimate
            criticalEnergyUncertainty=criticalEnergyUncertainty ...
                +matrixUncertainty/(abs(transversality.estimate)-transversality.uncertainty_estimate);
        else
            criticalEnergyUncertainty=Inf;
        end
        connection=struct('critical_energy',critical,'bracket',[left,right], ...
            'critical_energy_uncertainty_estimate',criticalEnergyUncertainty, ...
            'critical_direction',direction,'left_kernel',leftKernel,'singular_values',diag(D), ...
            'matrix_uncertainty_estimate',matrixUncertainty, ...
            'derivative_uncertainty',[di.columns.estimatedError], ...
            'derivative',derivativeSummary(M,di),'coarse_derivative',derivativeSummary(MCoarse,coarseInfo), ...
            'matrix_half_step_difference',norm(M-MCoarse,2), ...
            'transversality',transversality,'amplitudes',struct([]), ...
            'parent_derivatives_reliable',di.allReliable&&di.classicalDerivative ...
            &&coarseInfo.allReliable&&coarseInfo.classicalDerivative&&transversality.derivatives_reliable, ...
            'reflection_symmetry_at_parameters',all(p([7,8])==0), ...
            'status','candidate_only','evidence',struct());
        predictions=struct('schema_version',report.schema_version, ...
            'critical_energy',critical,'critical_energy_uncertainty_estimate',criticalEnergyUncertainty, ...
            'direction',direction,'left_kernel',leftKernel,'transversality',transversality, ...
            'amplitudes',settings.amplitudes,'validation_settings',settings, ...
            'source','parent derivative only','frozen_utc',char(datetime('now','TimeZone','UTC')));
        predictionFile=sprintf('pronk_predictions_v2_%d.mat',bracketIndex);
        save(V3Path_v3(V3OutputPath_v3(fullfile(outputDirectory,predictionFile))),'predictions','M','MCoarse');
        connection.prediction_artifact=predictionFile;
        if isempty(report.connections),report.connections=connection;
        else,report.connections(end+1)=connection;end
        checkpoint(); % Parent-only record precedes daughter trials.
        for signValue=[-1,1]
            lastEnergy=critical;
            for amplitude=sort(unique(settings.amplitudes(:).'))
                if budgetExpired(),break;end
                signed=signValue*amplitude;guess=[signed*direction;lastEnergy];
                [initialResidual,~]=daughterResidual(guess,[],[],struct());
                solver=RootSolver_v3(struct('MaxIterations',cfg.budgets.root_max_iterations, ...
                    'MaxFunctionEvaluations',cfg.budgets.root_max_function_evaluations, ...
                    'FunctionTolerance',settings.root_function_tolerance, ...
                    'ResidualAcceptanceTolerance',settings.root_residual_tolerance,'Jacobian',fd));
                [z,correction]=solver.solve(@daughterResidual,guess,zeros(0,1),[]);
                entry=struct('signed_amplitude',signed,'converged',correction.converged, ...
                    'reduced_coordinates',z(1:3),'energy',z(4),'period',NaN,'mean_speed',NaN, ...
                    'full_closure',NaN,'replay_full_closure',NaN,'replay_period_difference',NaN, ...
                    'replay_signature_match',false,'distance_to_same_energy_parent',norm(z(1:3)), ...
                    'critical_alignment',abs(direction.'*z(1:3))/max(norm(z(1:3)),eps), ...
                    'amplitude_constraint_error',abs(direction.'*z(1:3)-signed), ...
                    'initial_residual',norm(initialResidual,inf),'final_residual',correction.residualNorm, ...
                    'correction_norm',norm(z-guess,inf),'genuine_correction',false, ...
                    'solver',correction.solver,'solver_iterations',member(correction.output,'iterations',0), ...
                    'solver_counters',solverCounters(correction), ...
                    'trajectory_distinction',struct(),'in_registered_domain',false, ...
                    'reason',correction.message,'classification',struct(),'artifact','');
                entry.genuine_correction=entry.solver_iterations>0 ...
                    &&entry.correction_norm>10*settings.root_residual_tolerance ...
                    &&entry.initial_residual>10*max(entry.final_residual,settings.root_residual_tolerance) ...
                    &&~strcmp(entry.solver,'residual-check');
                orbit=[];replayOrbit=[];classification=struct();
                if correction.converged
                    x=lift(z(1:3),z(4));u=problem.packState(x);
                    [~,details]=problem.evaluateWithInfo(u,p,false(4,1));
                    entry.full_closure=details.residual_norm;
                    [~,replayDetails]=replayProblem.evaluateWithInfo(u,p,false(4,1));
                    entry.replay_full_closure=replayDetails.residual_norm;
                    entry.replay_signature_match=strcmp(details.section_relative_event_signature, ...
                        replayDetails.section_relative_event_signature);
                    if entry.full_closure<=settings.full_closure_tolerance ...
                            &&entry.replay_full_closure<=settings.full_closure_tolerance
                        orbit=problem.createOrbit(u,p,false(4,1),details);
                        replayOrbit=replayProblem.createOrbit(u,p,false(4,1),replayDetails);
                        entry.period=replayOrbit.period;
                        entry.replay_period_difference=abs(orbit.period-replayOrbit.period);
                        entry.mean_speed=replayOrbit.stride_displacement(1)/replayOrbit.period;
                        classification=GaitIdentification_v3(replayOrbit);
                        entry.classification=classificationSummary(classification);
                        entry.trajectory_distinction=trajectoryDistinction(replayOrbit);
                        entry.in_registered_domain=inDomain(replayOrbit,z(4),entry.mean_speed);
                        entry.converged=entry.in_registered_domain&&entry.replay_signature_match;
                        if entry.converged,lastEnergy=z(4);
                        else,entry.reason='replayed root failed domain or event-signature validation';end
                    else
                        entry.converged=false;entry.reason='full physical closure failed at solve or tighter replay tolerances';
                    end
                end
                entry.artifact=sprintf('pronk_daughter_v2_%d_%+.6g.mat',bracketIndex,signed);
                compact=CompactResearchBranch_v3(struct('points',struct('orbit',orbit,'solverInfo',correction)));
                correction=compact.points.solverInfo; % Full accepted traces are saved separately.
                save(V3Path_v3(V3OutputPath_v3(fullfile(outputDirectory,entry.artifact))),'orbit','replayOrbit','entry', ...
                    'classification','correction','predictions','-v7');
                if isempty(connection.amplitudes),connection.amplitudes=entry;
                else,connection.amplitudes(end+1)=entry;end
                connection.evidence=PronkAttachmentEvidence_v3(connection,settings);
                connection.status=connection.evidence.status;
                report.connections(end)=connection;checkpoint();
                fprintf('Pronk validation amplitude %+.3g: convergence %d, replay closure %.3g, corrected %d\n', ...
                    signed,entry.converged,entry.replay_full_closure,entry.genuine_correction);
            end
        end
        connection.evidence=PronkAttachmentEvidence_v3(connection,settings);
        connection.status=connection.evidence.status;report.connections(end)=connection;checkpoint();
        if budgetExpired(),report.status='budget_exhausted';checkpoint();return;end
    end
    report.status='completed_bounded_parent_only_search';checkpoint();

    function x=lift(v,E)
        x=zeros(14,1);x(s.State.dx)=v(1);x(s.State.y)=E-.5*v(1)^2;
        x(s.Leg.AngleIndices)=v(2);x(s.Leg.RateIndices)=v(3);
    end
    function [next,info]=reducedReturn(v,E,context)
        if nargin<3,context=struct();end
        x=lift(v,E);[returned,info]=map.evaluate(x,false(4,1),p,context);
        next=returned([s.State.dx,s.Leg.AngleIndices(1),s.Leg.RateIndices(1)]);
    end
    function [matrix,value,info]=parentMatrix(E,derivative)
        [matrix,value,info]=derivative.compute(@(v,context) reducedReturn(v,E,context),zeros(3,1));
    end
    function [r,info]=daughterResidual(z,~,~,context)
        if nargin<4,context=struct();end
        if z(4)<cfg.domain.energy(1)||z(4)>cfg.domain.energy(2)
            error('DiscoverPronkFromPIP_v3:EnergyDomain','Trial energy lies outside the registered domain.');
        end
        [next,info]=reducedReturn(z(1:3),z(4),context);
        r=[next-z(1:3);direction.'*z(1:3)-signed];
    end
    function result=estimateTransversality(E,v,w,matrixError,gap)
        h=settings.transversality_energy_step;
        if E-h<cfg.domain.energy(1)||E+h>cfg.domain.energy(2)
            error('DiscoverPronkFromPIP_v3:TransversalityDomain','Central mixed derivative leaves the registered domain.');
        end
        [plus,~,pi]=parentMatrix(E+h,fdHalf);[minus,~,mi]=parentMatrix(E-h,fdHalf);
        [plusHalf,~,phi]=parentMatrix(E+h/2,fdHalf);[minusHalf,~,mhi]=parentMatrix(E-h/2,fdHalf);
        coarse=(plus-minus)/(2*h);fine=(plusHalf-minusHalf)/h;
        stencilError=(matrixErrorEstimate(plusHalf,phi)+matrixErrorEstimate(minusHalf,mhi))/h;
        subspaceError=2*matrixError/max(gap-matrixError,eps)*norm(fine,2);
        result=struct('definition','w^T d_E(DP_E-I) v on the fixed-energy pronk chart', ...
            'estimate',w.'*fine*v,'coarse_estimate',w.'*coarse*v, ...
            'uncertainty_estimate',norm(fine-coarse,2)+stencilError+subspaceError, ...
            'energy_step',h,'half_energy_step',h/2, ...
            'mixed_matrix',fine,'coarse_mixed_matrix',coarse, ...
            'half_step_difference',norm(fine-coarse,2),'stencil_error_estimate',stencilError, ...
            'kernel_orientation_error_estimate',subspaceError, ...
            'derivatives_reliable',pi.allReliable&&mi.allReliable&&phi.allReliable&&mhi.allReliable ...
            &&pi.classicalDerivative&&mi.classicalDerivative&&phi.classicalDerivative&&mhi.classicalDerivative, ...
            'stencils',{{derivativeSummary(plus,pi),derivativeSummary(minus,mi), ...
                derivativeSummary(plusHalf,phi),derivativeSummary(minusHalf,mhi)}}, ...
            'error_interpretation','step-refinement estimate; not a rigorous interval bound');
    end
    function result=trajectoryDistinction(orbit)
        result=PronkTrajectoryEvidence_v3(orbit);
    end
    function accepted=inDomain(orbit,E,speed)
        accepted=E>=cfg.domain.energy(1)&&E<=cfg.domain.energy(2) ...
            &&speed>=cfg.domain.mean_speed(1)&&speed<=cfg.domain.mean_speed(2) ...
            &&orbit.period<=cfg.domain.primitive_period_max ...
            &&numel(orbit.event_history)<=cfg.domain.event_count_max ...
            &&max(abs(orbit.trajectory.state(:,s.State.phi)))<=cfg.domain.pitch_abs_max;
    end
    function expired=budgetExpired()
        expired=toc(timer)>settings.wall_seconds;
    end
    function checkpoint()
        report.elapsed_seconds=toc(timer);
        fid=fopen(V3Path_v3(V3OutputPath_v3(fullfile(outputDirectory,'pip_pk_local.json'))),'w');
        if fid<0,error('DiscoverPronkFromPIP_v3:Checkpoint','Cannot open JSON checkpoint.');end
        cleanup=onCleanup(@() fclose(fid));
        fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
        save(V3Path_v3(V3OutputPath_v3(fullfile(outputDirectory,'pip_pk_local_checkpoint.mat'))),'report','-v7');
    end
end

function value=matrixErrorEstimate(M,info)
% FD estimatedError is relative to max(1,norm(column)), not an absolute error.
    relative=[info.columns.estimatedError];
    value=norm(relative.*max(1,vecnorm(M,2,1)),2);
end
function summary=derivativeSummary(M,info)
    summary=struct('matrix',M,'all_reliable',info.allReliable, ...
        'classical_derivative',info.classicalDerivative,'selected_steps',info.selectedSteps, ...
        'relative_column_errors',info.estimatedErrors, ...
        'absolute_matrix_error_estimate',matrixErrorEstimate(M,info), ...
        'map_evaluations',info.mapEvaluations);
end
function summary=classificationSummary(value)
    keys={'label','abbreviation','status','reason','flight_count','raw_positive_flight_count', ...
        'flight_intervals_on_circle','duty_factors','contact_sync_errors','motion_sync_errors', ...
        'hind_pair_synchronized','front_pair_synchronized','borderline'};
    summary=struct();for k=1:numel(keys),summary.(keys{k})=value.(keys{k});end
    primitive=value.primitive;
    summary.primitive=struct('status',primitive.status,'reason',primitive.reason, ...
        'primitive_period',primitive.primitive_period,'cover_count',primitive.cover_count, ...
        'closure_error',primitive.closure_error,'checked_cover_bound',primitive.checked_cover_bound, ...
        'global_primitivity_proved',false);
    summary.full_classification_in_mat_artifact=true;
end
function summary=solverCounters(value)
    keys={'functionEvaluationCount','mapEvaluationCount','cacheHitCount', ...
        'invalidEvaluationCount','jacobianEvaluationCount','acceptedNewtonIterations','invalidTrialCount'};
    summary=struct();for k=1:numel(keys),summary.(keys{k})=member(value,keys{k},NaN);end
end
function value=member(source,key,fallback)
    if isstruct(source)&&isfield(source,key),value=source.(key);else,value=fallback;end
end
function archive=archivePriorRun(directory)
    archive='';
    if ~exist(V3Path_v3(fullfile(directory,'pip_pk_local.json')),'file'),return;end
    stamp=char(datetime('now','TimeZone','UTC','Format','yyyyMMdd''T''HHmmssSSS'));
    archive=V3OutputPath_v3(fullfile(directory,['prior_pronk_run_',stamp]));mkdir(V3Path_v3(archive));
    files=[V3Dir_v3(fullfile(directory,'pip_pk_local*'));V3Dir_v3(fullfile(directory,'pronk_predictions_*.mat')); ...
        V3Dir_v3(fullfile(directory,'pronk_daughter_*.mat'))];
    for k=1:numel(files)
        if ~files(k).isdir
            source=V3OutputPath_v3(fullfile(directory,files(k).name));
            copyfile(V3Path_v3(source),V3Path_v3(fullfile(archive,files(k).name)));
        end
    end
end
