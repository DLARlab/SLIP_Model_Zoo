function result=ProcessPIPCandidateQueue_v3(candidateIndex,cfg,outputDirectory,maxWallSeconds)
%PROCESSPIPCANDIDATEQUEUE_V3 Resume spectral/daughter phases of one PIP task.
% Fixed-energy synchronized derivatives are never full-space certificates.
    root=V3Root_v3(mfilename('fullpath'));
    outputDirectory=V3OutputPath_v3(outputDirectory);
    if ~isfolder(V3Path_v3(outputDirectory)),mkdir(V3Path_v3(outputDirectory));end
    oldPath=path;restore=onCleanup(@()path(oldPath)); %#ok<NASGU>
    for folder={'Schema_v3','Dynamics_v3','Simulation_v3','Orbit_v3','Numerics_v3','Stability_v3'}
        V3LegacyAddPath_v3(fullfile(root,folder{1}));
    end
    queue=jsondecode(fileread(V3Path_v3(fullfile(root,'Research_v3','parent_candidate_queue_v3.json'))));
    if candidateIndex<=numel(queue.candidates)
        if iscell(queue.candidates),candidate=queue.candidates{candidateIndex};
        else,candidate=queue.candidates(candidateIndex);end
    else,candidate=cfg.additional_pip_candidates(candidateIndex-numel(queue.candidates));end
    file=fullfile(outputDirectory,'phase_checkpoint.mat');
    p=cfg.baseline_v3_parameters(:);s=QuadrupedSchema_v3.shared();
    settings=cfg.parent_only_pronk;clock=tic;
    scanRegistration=[];scanFile=fullfile(root,'Research_v3','next_round','pip_parent_scan_method_revision.json');
    if isfile(V3Path_v3(scanFile))
        scanRegistration=jsondecode(fileread(V3Path_v3(scanFile)));
        assert(V3HashMatches_v3(...
            scanRegistration.helper_sha256, fullfile(root,'Numerics_v3','RestrictedPIPParentMatrix_v3.m')),'PIP scan helper changed after its registered audit.');
    end
    integration=struct('RelTol',settings.relative_tolerance,'AbsTol',settings.absolute_tolerance,'MaxStep',.05);
    daughterRevision=fullfile(root,'Research_v3','next_round','pip_daughter_resume_method_revision.json');
    if ~isfile(V3Path_v3(daughterRevision))
        policy=struct('registered_utc',char(datetime('now','TimeZone','UTC')), ...
            'measured_obstacle','The n0 -0.0003 attempt started with only3.7796 seconds left: zero Newton steps and unavailable Jacobian, not an ill-conditioning diagnosis.', ...
            'evidence','Research_v3/next_round/tasks/full/PIP_candidate_1/daughter_-0.0003_attempt_1.mat', ...
            'repair','Checkpoint before a new daughter with less than30 seconds remaining; scale a preceding accepted same-sign daughter and its finite corrector Jacobian as a numerical warm start.', ...
            'frozen_parent_predictions_changed',false,'acceptance_tolerances_changed',false, ...
            'jacobian_refresh_interval',5);
        RoundJSON_v3(daughterRevision,policy);
    end
    map=PoincareMap_v3(Quadrupedal_Dynamics_v3(),PoincareSection_v3.apex(s.State.dy), ...
        HybridSimulator_v3(integration),BLMarkedApexReturnPolicy_v3(), ...
        struct('MaxReturnTime',cfg.domain.primitive_period_max,'MaxCycleEvents',cfg.domain.event_count_max));
    fd=HybridFiniteDifferenceJacobian_v3(struct('RelativeCandidateSteps',settings.derivative_step, ...
        'MaximumRelativeError',settings.derivative_relative_error,'FailurePolicy','nan'));
    declaredBracket=member(candidate,'energy_bracket',member(candidate,'grid_interval',[1.0001,1.13343]));
    if isfile(V3Path_v3(file))
        loaded=load(V3Path_v3(file),'record');record=loaded.record;
        if iscell(record.candidate),record.candidate=record.candidate{1};end
        % Earlier execution exposed jsondecode's heterogeneous-cell schema.
        % Preserve every wrong-range observation, including consumed counts,
        % while resuming the actual registered candidate after the repair.
        if record.sample_energies(1)<declaredBracket(1)-1e-6 ...
                ||record.sample_energies(end)>declaredBracket(2)+1e-6 ...
                ||record.sample_energies(end)<declaredBracket(1)
            archive=fullfile(outputDirectory,'phase_checkpoint_before_cell_schema_repair.mat');
            save(V3Path_v3(archive),'record','-v7');
            spentEvaluations=record.function_evaluations;spentSeconds=record.elapsed_seconds;
            record=initialRecord(declaredBracket);record.function_evaluations=spentEvaluations;
            record.elapsed_seconds=spentSeconds;
            record.input_schema_repair=struct('diagnosis','Heterogeneous JSON records are cells; generic member lookup fell back to the n0 range.', ...
                'action','Dereference the selected cell and validate its registered bracket.', ...
                'preserved_failed_execution','phase_checkpoint_before_cell_schema_repair.mat');
        elseif strcmp(record.phase,'refine')&&isfield(candidate,'energy_approximate') ...
                &&~isempty(candidate.energy_approximate) ...
                &&candidate.energy_approximate>=record.bracket(1)&&candidate.energy_approximate<=record.bracket(2)
            record.critical_energy=candidate.energy_approximate;
            record.refinement_method='Known analytic resonance lies inside the independently computed numerical sign bracket; validate its critical matrix at three steps.';
            record.phase='critical_subspace';
        end
        if strcmp(record.state,'retryable_failure')
            % The master queue requires a registered diagnosed repair before
            % scheduling this retry. Preserve its original failure here.
            if ~isfield(record,'failure_history'),record.failure_history={};end
            record.failure_history{end+1}=record.failure;record.state='partial_checkpoint';
        end
    else
        record=initialRecord(declaredBracket);
    end
    if ~isempty(record.amplitudes)
        record.new_points=max(record.new_points,sum([record.amplitudes.accepted]));
        if any([record.amplitudes.accepted])&&strcmp(record.scientific_status,'unprocessed')
            record.scientific_status='independently_closed_restricted_daughter_records';
        end
    end
    try
    while toc(clock)<maxWallSeconds
        switch record.phase
            case 'identify'
                if record.next_sample<=numel(record.sample_energies)
                    E=record.sample_energies(record.next_sample);[M,di]=scanMatrix(E);
                    spectrum=eig(M);
                    if ~isempty(record.parent_samples)
                        previous=record.parent_samples(end);
                        previous=previous.multipliers_real+1i*previous.multipliers_imaginary;
                        permutations=perms(1:3);cost=zeros(size(permutations,1),1);
                        for order=1:size(permutations,1),cost(order)=norm(spectrum(permutations(order,:))-previous);end
                        [~,order]=min(cost);spectrum=spectrum(permutations(order,:));
                    end
                    sample=struct('energy',E,'matrix',M,'reliable',di.allReliable, ...
                        'singular_values',svd(M-eye(3)),'multipliers_real',real(spectrum(:)), ...
                        'multipliers_imaginary',imag(spectrum(:)), ...
                        'determinant',det(M-eye(3)),'derivative',di);
                    record.parent_samples=[record.parent_samples,sample];
                    record.scientific_status='restricted_parent_spectrum_sampled';
                    record.next_sample=record.next_sample+1;checkpoint();
                else
                    if isfield(candidate,'energy_approximate')
                        record.critical_energy=candidate.energy_approximate;
                        record.refinement_method='analytic resonance energy, independently revalidated numerically';
                        record.phase='critical_subspace';
                    elseif isfield(candidate,'contains_analytic_resonance')
                        record.critical_energy=candidate.contains_analytic_resonance.energy_approximate;
                        record.refinement_method='known analytic resonance within queued sign-change bracket';
                        record.phase='critical_subspace';
                    else
                        samples=record.parent_samples;d=[samples.determinant];
                        crossing=find(d(1:end-1).*d(2:end)<0,1);
                        if isempty(crossing)
                            [~,k]=min(arrayfun(@(a)min(a.singular_values),samples));
                            record.critical_energy=samples(k).energy;
                            record.refinement_method='minimum sampled singular value; no critical-point certificate';
                            record.phase='critical_subspace';
                        else
                            record.bracket=[samples(crossing).energy,samples(crossing+1).energy];
                            record.left_determinant=d(crossing);record.phase='refine';
                        end
                    end
                    checkpoint();
                end
            case 'refine'
                if diff(record.bracket)<=settings.energy_bracket_tolerance
                    record.critical_energy=mean(record.bracket);record.refinement_method='sign bracket with singular/eigenvalue tracking';
                    record.phase='critical_subspace';checkpoint();continue
                end
                middle=mean(record.bracket);[M,di]=scanMatrix(middle);
                if ~di.allReliable,error('ProcessPIPCandidateQueue_v3:Derivative','Critical refinement derivative is unreliable.');end
                if record.left_determinant*det(M-eye(3))<=0,record.bracket(2)=middle;
                else,record.bracket(1)=middle;record.left_determinant=det(M-eye(3));end
                record.refinement_iterations=record.refinement_iterations+1;checkpoint();
            case 'critical_subspace'
                k=numel(record.critical_derivatives)+1;
                if k<=3
                    derivative=fd;derivative.RelativeCandidateSteps=settings.derivative_step/2^(k-1);
                    [M,di]=matrix(record.critical_energy,derivative);
                    record.critical_derivatives{k}=struct('matrix',M,'info',di);checkpoint();continue
                end
                M=record.critical_derivatives{3}.matrix;
                [U,D,V]=svd(M-eye(3));direction=V(:,end);left=U(:,end);
                [~,lead]=max(abs(direction));if direction(lead)<0,direction=-direction;end
                [~,lead]=max(abs(left));if left(lead)<0,left=-left;end
                errorEstimate=max(norm(M-record.critical_derivatives{2}.matrix,2), ...
                    norm(record.critical_derivatives{1}.matrix-record.critical_derivatives{2}.matrix,2));
                for j=1:3
                    item=record.critical_derivatives{j};relative=[item.info.columns.estimatedError];
                    errorEstimate=max(errorEstimate,norm(relative.*max(1,vecnorm(item.matrix)),2));
                end
                record.critical_direction=direction;record.left_kernel=left;
                record.singular_values=diag(D);record.matrix_uncertainty_estimate=errorEstimate;
                record.estimated_nullity=sum(diag(D)<=max(1e-6,10*errorEstimate));
                record.scientific_status='restricted_critical_subspace_evaluated';
                record.phase='transversality';checkpoint();
            case 'transversality'
                offsets=[1,-1,.5,-.5]*settings.transversality_energy_step;
                k=numel(record.transversality_samples)+1;
                if k<=4
                    derivative=fd;derivative.RelativeCandidateSteps=settings.derivative_step/4;
                    [M,di]=matrix(record.critical_energy+offsets(k),derivative);
                    record.transversality_samples{k}=struct('matrix',M,'info',di);checkpoint();continue
                end
                h=settings.transversality_energy_step;T=record.transversality_samples;
                coarse=(T{1}.matrix-T{2}.matrix)/(2*h);fine=(T{3}.matrix-T{4}.matrix)/h;
                record.transversality_estimate=record.left_kernel.'*fine*record.critical_direction;
                record.transversality_uncertainty_estimate=norm(fine-coarse,2)+2*record.matrix_uncertainty_estimate/h;
                record.parent_derivatives_reliable=all(cellfun(@(x)x.info.allReliable,record.critical_derivatives)) ...
                    &&all(cellfun(@(x)x.info.allReliable,record.transversality_samples));
                record.scientific_status='restricted_transversality_evaluated';
                record.phase='freeze';checkpoint();
            case 'freeze'
                direction=record.critical_direction;orthogonal=[direction(2);-direction(1);0];
                if norm(orthogonal)<.1,orthogonal=[0;direction(3);-direction(2)];end
                orthogonal=orthogonal/norm(orthogonal);
                record.predictions=struct('frozen_utc',char(datetime('now','TimeZone','UTC')), ...
                    'critical_energy',record.critical_energy,'critical_direction',direction, ...
                    'orthogonal_predictor_offset',.1*orthogonal,'signed_amplitudes', ...
                    [-sort(settings.amplitudes(:).'),sort(settings.amplitudes(:).')], ...
                    'held_out_daughter_data_used',false, ...
                    'scope','Parent derivative only, within the synchronized invariant subspace');
                record.phase='correct_daughters';checkpoint();
            case 'correct_daughters'
                amplitudes=record.predictions.signed_amplitudes;
                if record.next_amplitude>numel(amplitudes)
                    record.phase='evaluate_attachment';checkpoint();continue
                end
                if maxWallSeconds>=30&&maxWallSeconds-toc(clock)<30
                    record.slice_yield_reason='Insufficient remaining slice for a new constrained daughter; retain the pending amplitude.';
                    checkpoint();break
                end
                signed=amplitudes(record.next_amplitude);E=record.critical_energy;
                v=signed*(record.critical_direction+record.predictions.orthogonal_predictor_offset);
                parent=lift(zeros(3,1),E);seed=struct('state',lift(v,E),'mode',false(4,1), ...
                    'parameter',p,'return_policy','BL-marked-apex-return','occurrence',1, ...
                    'provenance',struct('origin','frozen parent-only direction','candidate_id',candidate.id));
                attempt=1;initialJacobian=[];
                if isfield(record,'partial_amplitude')&&record.partial_amplitude.signed_amplitude==signed
                    partial=record.partial_amplitude;seed.state=partial.best_candidate;
                    E=QuadrupedEnergy_v3.evaluate(seed.state,seed.mode,p);
                    initialJacobian=partial.final_jacobian;attempt=partial.attempt+1;
                    if any(~isfinite(initialJacobian(:))),initialJacobian=[];end
                    seed.provenance.resume_from=partial.artifact;
                elseif ~isempty(record.amplitudes)
                    eligible=find([record.amplitudes.accepted] ...
                        &sign([record.amplitudes.signed_amplitude])==sign(signed));
                    if ~isempty(eligible)
                        [~,nearest]=min(abs([record.amplitudes(eligible).signed_amplitude]-signed));
                        previous=record.amplitudes(eligible(nearest));ratio=signed/previous.signed_amplitude;
                        E=record.critical_energy+(previous.energy-record.critical_energy)*ratio^2;
                        seed.state=lift(previous.reduced_coordinates*ratio,E);
                        prior=load(V3Path_v3(fullfile(outputDirectory,previous.artifact)),'correction');
                        initialJacobian=member(prior.correction.solver,'finalJacobian',[]);
                        if any(~isfinite(initialJacobian(:))),initialJacobian=[];end
                        seed.provenance.numerical_warm_start=struct('artifact',previous.artifact, ...
                            'amplitude_ratio',ratio,'energy_predictor','Measured preceding energy shift scaled quadratically; correction remains unconstrained in energy.', ...
                            'frozen_parent_direction_unchanged',true);
                    end
                end
                if isempty(initialJacobian)&&~isempty(record.amplitudes)
                    % A starved slice can retain a useful physical predictor
                    % but no derivative. Reuse a separately accepted nearby
                    % same-sign derivative without discarding that predictor.
                    eligible=find([record.amplitudes.accepted] ...
                        &sign([record.amplitudes.signed_amplitude])==sign(signed));
                    if ~isempty(eligible)
                        [~,nearest]=min(abs([record.amplitudes(eligible).signed_amplitude]-signed));
                        previous=record.amplitudes(eligible(nearest));
                        prior=load(V3Path_v3(fullfile(outputDirectory,previous.artifact)),'correction');
                        candidateJacobian=member(prior.correction.solver,'finalJacobian',[]);
                        if ~isempty(candidateJacobian)&&all(isfinite(candidateJacobian(:)))
                            initialJacobian=candidateJacobian;
                            seed.provenance.jacobian_warm_start_from=previous.artifact;
                        end
                    end
                end
                record.daughter_method_revision='Research_v3/next_round/pip_daughter_resume_method_revision.json';
                family=EnergyFamilyResidual_v3(PeriodicOrbitResidual_v3(map,parent),parent,false(4,1),p,struct('Symmetry','pronk'));
                reference=[family.packState(parent);E];normal=zeros(size(reference));
                normal(find(family.CoordinateIndices==s.State.dx,1))=record.critical_direction(1);
                normal(find(family.CoordinateIndices==s.Leg.AngleIndices(1),1))=record.critical_direction(2);
                normal(find(family.CoordinateIndices==s.Leg.RateIndices(1),1))=record.critical_direction(3);
                options=struct('Symmetry','pronk','Energy',E,'FamilyConstraint','amplitude', ...
                    'Constraint',struct('reference',reference,'normal',normal,'target',signed), ...
                    'Integration',integration,'MaxWallSeconds',max(.1,maxWallSeconds-toc(clock)), ...
                    'SolverOptions',struct('Algorithm','newton','MaxIterations',35, ...
                    'MaxFunctionEvaluations',2000,'UseBroyden',true,'ReuseJacobian',true,'Jacobian',fd, ...
                    'InitialJacobian',initialJacobian), ...
                    'Acceptance',struct('FullClosureTolerance',settings.full_closure_tolerance));
                [orbit,correction]=PeriodicSolutionSolver_v3(seed,options);
                record.function_evaluations=record.function_evaluations+member(correction.solver,'functionEvaluationCount',0);
                artifact=sprintf('daughter_%+.6g_attempt_%d.mat',signed,attempt);
                finalState=correction.final_candidate;
                distance=Inf;if numel(finalState)==14,distance=norm(finalState-parent);end
                entry=struct('signed_amplitude',signed,'accepted',correction.accepted, ...
                    'full_closure',correction.full_closure,'constraint_error',correction.constraint_residual, ...
                    'gait',member(correction.classification,'label','unclassified'), ...
                    'initial_residual',correction.initial_physical_norm,'final_residual',correction.final_physical_norm, ...
                    'accepted_newton_iterations',member(correction.solver,'acceptedNewtonIterations',0), ...
                    'state_distance_to_critical_parent',distance, ...
                    'primary_failure',correction.primary_failure,'replay_failure',correction.replay_failure, ...
                    'artifact',artifact,'converged',correction.accepted,'in_registered_domain',false, ...
                    'energy',NaN,'period',NaN,'mean_speed',NaN,'reduced_coordinates',zeros(3,1), ...
                    'critical_alignment',0,'amplitude_constraint_error',abs(correction.constraint_residual), ...
                    'genuine_correction',false,'replay_full_closure',correction.full_closure, ...
                    'replay_signature_match',false,'replay_period_difference',Inf, ...
                    'trajectory_distinction',struct(),'classification',correction.classification);
                if ~isempty(orbit)
                    entry.energy=QuadrupedEnergy_v3.evaluate(orbit.initial_state,orbit.initial_mode,p);
                    entry.period=orbit.period;entry.mean_speed=orbit.stride_displacement(1)/orbit.period;
                    entry.reduced_coordinates=orbit.initial_state([s.State.dx,s.Leg.AngleIndices(1),s.Leg.RateIndices(1)]);
                    entry.critical_alignment=abs(record.critical_direction.'*entry.reduced_coordinates)/max(norm(entry.reduced_coordinates),eps);
                    entry.genuine_correction=entry.accepted_newton_iterations>0 ...
                        &&norm(finalState-seed.state,inf)>10*settings.root_residual_tolerance;
                    entry.in_registered_domain=entry.energy>=cfg.domain.energy(1)&&entry.energy<=cfg.domain.energy(2) ...
                        &&entry.period<=cfg.domain.primitive_period_max ...
                        &&abs(entry.mean_speed)<=max(abs(cfg.domain.mean_speed));
                    entry.trajectory_distinction=PronkTrajectoryEvidence_v3(orbit);
                    first=member(correction.solver,'orbit',[]);
                    if ~isempty(first)
                        entry.replay_period_difference=abs(first.period-orbit.period);
                        entry.replay_signature_match=isequal(first.section_relative_event_signature,orbit.section_relative_event_signature);
                    end
                end
                save(V3Path_v3(fullfile(outputDirectory,artifact)),'seed','orbit','correction','entry','-v7');
                wallFailure=contains(member(correction.primary_failure,'message',''),'wall budget','IgnoreCase',true);
                if ~correction.accepted&&(wallFailure||toc(clock)>=maxWallSeconds) ...
                        &&numel(correction.final_candidate)==14
                    record.partial_amplitude=struct('signed_amplitude',signed,'attempt',attempt, ...
                        'best_candidate',correction.final_candidate,'artifact',artifact, ...
                        'final_jacobian',member(correction.solver,'finalJacobian',[]), ...
                        'reason','Task slice ended; resume the same constrained daughter from its best candidate.');
                    checkpoint();break
                end
                if isfield(record,'partial_amplitude'),record=rmfield(record,'partial_amplitude');end
                record.new_points=record.new_points+double(entry.accepted);
                if entry.accepted,record.scientific_status='independently_closed_restricted_daughter_records';end
                record.amplitudes=[record.amplitudes,entry];record.next_amplitude=record.next_amplitude+1;checkpoint();
            case 'evaluate_attachment'
                accepted=[record.amplitudes.accepted];
                record.successful_daughters=sum(accepted);record.new_points=max(record.new_points,sum(accepted));
                record.scientific_status='restricted_spectral_candidate_with_executed_daughter_attempts';
                connection=struct('singular_values',record.singular_values, ...
                    'matrix_uncertainty_estimate',record.matrix_uncertainty_estimate, ...
                    'critical_energy_uncertainty_estimate',settings.energy_bracket_tolerance/2, ...
                    'critical_energy',record.critical_energy,'parent_derivatives_reliable',record.parent_derivatives_reliable, ...
                    'transversality',struct('estimate',record.transversality_estimate, ...
                    'uncertainty_estimate',record.transversality_uncertainty_estimate), ...
                    'amplitudes',record.amplitudes,'reflection_symmetry_at_parameters',all(p([7,8])==0));
                record.attachment_evidence=PronkAttachmentEvidence_v3(connection,settings);
                if strcmp(record.attachment_evidence.status,'numerically_supported_restricted_attachment')
                    record.scientific_status=record.attachment_evidence.status;
                end
                record.continuation_queue=struct('amplitude_index',{},'direction',{});
                for signValue=[-1,1]
                    indices=find(accepted&sign([record.amplitudes.signed_amplitude])==signValue);
                    if isempty(indices),continue;end
                    [~,largest]=max(abs([record.amplitudes(indices).signed_amplitude]));
                    for direction=[-1,1]
                        record.continuation_queue(end+1)=struct('amplitude_index',indices(largest),'direction',direction); %#ok<AGROW>
                    end
                end
                record.continuation_selection='Largest accepted amplitude on each signed branch; both arclength directions. Smaller amplitudes validate local attachment.';
                record.phase='continue_daughters';checkpoint();
            case 'continue_daughters'
                if record.next_continuation>numel(record.continuation_queue)
                    record.phase='complete';record.state='accepted';checkpoint();continue
                end
                item=record.continuation_queue(record.next_continuation);
                entry=record.amplitudes(item.amplitude_index);
                artifact=sprintf('daughter_continuation_%d.mat',record.next_continuation);
                branchPath=fullfile(outputDirectory,artifact);previous=struct('points',[]);
                if isfile(V3Path_v3(branchPath))
                    loaded=load(V3Path_v3(branchPath),'branch');previous=loaded.branch;orbit=previous.points(end).orbit;
                else,loaded=load(V3Path_v3(fullfile(outputDirectory,entry.artifact)),'orbit');orbit=loaded.orbit;end
                problem=PeriodicOrbitResidual_v3(map,orbit.initial_state);
                continuationFD=HybridFiniteDifferenceJacobian_v3(struct('RelativeCandidateSteps',settings.derivative_step, ...
                    'MaximumRelativeError',settings.derivative_relative_error));
                options=struct('Symmetry','pronk','MaxPoints',3,'StepSize',.003, ...
                    'MaxWallSeconds',max(.1,maxWallSeconds-toc(clock)), ...
                    'RootSolver',RootSolver_v3(struct('UseBroyden',true,'MaxIterations',35,'Jacobian',continuationFD)), ...
                    'Jacobian',continuationFD,'InitialDirection',item.direction, ...
                    'CheckpointFunction',@(newer)saveContinuation(newer,previous,branchPath), ...
                    'ParameterBounds',cfg.domain.energy(:).');
                if ~isempty(previous.points),options.InitialTangent=previous.points(end).tangent;end
                newer=FixedParameterContinuation_v3.run(problem,problem.packState(orbit.initial_state),p,orbit.initial_mode,options);
                record.function_evaluations=record.function_evaluations ...
                    +sum(arrayfun(@continuationEvaluations,newer.points)) ...
                    +sum(arrayfun(@continuationEvaluations,newer.failures));
                branch=appendBranch(previous,newer);branch=CompactResearchBranch_v3(branch);
                save(V3Path_v3(fullfile(outputDirectory,artifact)),'branch','-v7');
                added=max(0,branch.count-max(1,numel(previous.points)));
                record.new_points=record.new_points+added;
                if branch.count<4
                    record.last_continuation_checkpoint=struct('artifact',artifact,'points',branch.count, ...
                        'new_points',added,'reason',branch.terminationReason,'direction',item.direction);
                    checkpoint();break
                end
                record.continuations=[record.continuations,struct('artifact',artifact,'points',branch.count, ...
                    'reason',branch.terminationReason,'direction',item.direction, ...
                    'energy_range',[min(branch.energy),max(branch.energy)])];
                record.next_continuation=record.next_continuation+1;checkpoint();
            case 'complete'
                break
        end
    end
    catch exception
        record.state='retryable_failure';record.failure=struct('phase',record.phase, ...
            'identifier',exception.identifier,'message',exception.message);
    end
    record.elapsed_seconds=record.elapsed_seconds+toc(clock);checkpoint();result=record;

    function initial=initialRecord(bracket)
        initial=struct('schema_version','phased-PIP-candidate-v3-1','candidate',candidate, ...
            'state','partial_checkpoint','scientific_status','unprocessed', ...
            'phase','identify','restriction','synchronized fixed-energy pronk, BL-marked apex', ...
            'physical_parameter',p,'settings',settings,'parent_samples',struct([]), ...
            'sample_energies',linspace(bracket(1),bracket(2),7),'next_sample',1, ...
            'bracket',bracket,'refinement_iterations',0,'critical_energy',NaN, ...
            'critical_derivatives',{{}},'transversality_samples',{{}}, ...
            'predictions',struct(),'amplitudes',struct([]),'next_amplitude',1, ...
            'continuations',struct([]),'next_continuation',1,'failure',struct(), ...
            'elapsed_seconds',0,'function_evaluations',0,'new_points',0);
    end

    function x=lift(v,E)
        x=zeros(14,1);x(s.State.dx)=v(1);x(s.State.y)=E-.5*v(1)^2;
        x(s.Leg.AngleIndices)=v(2);x(s.Leg.RateIndices)=v(3);
    end
    function [next,info]=reduced(v,E,context)
        [returned,info]=map.evaluate(lift(v,E),false(4,1),p,context);
        next=returned([s.State.dx,s.Leg.AngleIndices(1),s.Leg.RateIndices(1)]);
    end
    function [M,info]=matrix(E,derivative)
        [M,~,info]=derivative.compute(@(v,context)reduced(v,E,context),zeros(3,1));
        record.function_evaluations=record.function_evaluations+info.mapEvaluations;
        if any(~isfinite(M(:)))
            error('ProcessPIPCandidateQueue_v3:NonfiniteDerivative','Parent derivative has nonfinite columns at E %.12g.',E);
        end
    end
    function [M,info]=scanMatrix(E)
        if ~isempty(scanRegistration)&&E>=scanRegistration.validated_energy_interval(1) ...
                &&E<=scanRegistration.validated_energy_interval(2)
            [M,info]=RestrictedPIPParentMatrix_v3(E,p);
            record.scan_method_revision='Research_v3/next_round/pip_parent_scan_method_revision.json';
        else,[M,info]=matrix(E,fd);end
    end
    function checkpoint()
        temporary=[file,'.partial.mat'];save(V3Path_v3(temporary),'record','-v7');movefile(V3Path_v3(temporary),V3Path_v3(file),'f');
        summary=record;
        summary.parent_samples=rmfieldSafe(summary.parent_samples,'derivative');
        summary.critical_derivatives={};summary.transversality_samples={};
        fid=fopen(V3Path_v3(fullfile(outputDirectory,'phase_checkpoint.json')),'w');assert(fid>=0);
        finish=onCleanup(@()fclose(fid)); %#ok<NASGU>
        fprintf(fid,'%s\n',jsonencode(summary,'PrettyPrint',true));
    end
end

function saveContinuation(newer,previous,file)
    branch=CompactResearchBranch_v3(appendBranch(previous,newer));
    save(V3Path_v3(file),'branch','-v7');
end
function branch=appendBranch(previous,newer)
    branch=newer;if isempty(previous.points),return;end
    if isempty(newer.points),branch=previous;return;end
    seam=norm(newer.points(1).orbit.initial_state(2:end)-previous.points(end).orbit.initial_state(2:end),inf);
    if seam>1e-7,error('ProcessPIPCandidateQueue_v3:Seam','Daughter continuation restart moved the saved seam.');end
    points=newer.points;
    for k=2:numel(points)
        points(k).index=numel(previous.points)+k-1;
        points(k).arclength=previous.points(end).arclength+points(k).arclength;
    end
    branch.points=[previous.points,points(2:end)];branch.count=numel(branch.points);
    if isfield(previous,'failures'),branch.failures=[previous.failures,newer.failures];end
    branch=PseudoArclengthContinuation_v3().refreshBranchSummary(branch);
end

function value=member(source,key,fallback)
    if isstruct(source)&&isfield(source,key),value=source.(key);else,value=fallback;end
end
function count=continuationEvaluations(point)
    count=0;
    if isfield(point,'solverInfo')
        info=point.solverInfo;
        if isfield(info,'functionEvaluationCount'),count=info.functionEvaluationCount;
        elseif isfield(info,'solver')&&isfield(info.solver,'functionEvaluationCount')
            count=info.solver.functionEvaluationCount;
        end
    end
end
function value=rmfieldSafe(value,key)
    if isstruct(value)&&isfield(value,key),value=rmfield(value,key);end
end
