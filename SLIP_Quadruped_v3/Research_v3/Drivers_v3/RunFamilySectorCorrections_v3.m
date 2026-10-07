function phase=RunFamilySectorCorrections_v3(sourceResult,cfg,outputDirectory,maxWallSeconds,study,candidate)
%RUNFAMILYSECTORCORRECTIONS_V3 Distinct P1/P2 signed physical-sector searches.
% Amplitude constraints are inside the d+1 corrector. Sector guesses are
% symmetry-informed candidates, not critical eigenvectors or ancestry.
    file=fullfile(outputDirectory,'family_switch_checkpoint.mat');clock=tic;
    if nargin<6,candidate=[];end
    repairRevision=0;
    if isfield(sourceResult,'last_repair_revision'),repairRevision=sourceResult.last_repair_revision;end
    if ~isempty(candidate)&&isfield(candidate,'repair_revision'),repairRevision=candidate.repair_revision;end
    if isfile(V3Path_v3(file)),loaded=load(V3Path_v3(file),'phase');phase=loaded.phase;
    else
        if isempty(candidate),[seed,label,admitted,sourceArtifact]=chooseSeed(sourceResult,outputDirectory);
        else
            seed=candidate.seed;label=candidate.parent_label;admitted=candidate.parent_independently_admitted;
            sourceArtifact=candidate.evidence;RoundSave_v3(fullfile(outputDirectory,'registered_spectral_candidate.mat'),struct('candidate',candidate));
        end
        phase=struct('schema_version','family-sector-correction-v3-1','study',study, ...
            'state','partial_checkpoint','phase','freeze','parent_seed',seed, ...
            'parent_descriptive_label',label,'parent_independently_admitted',admitted, ...
            'parent_source_artifact',sourceArtifact,'predictions',struct([]), ...
            'next_trial',1,'trials',struct([]),'accepted_count',0,'function_evaluations',0, ...
            'last_repair_revision',repairRevision, ...
            'hypothesis','signed physical symmetry-sector correction; no branch point or ancestry presumed', ...
            'ancestry_claimed',false,'regular_bifurcation_claimed',false);
    end
    if repairRevision>number(phase,'last_repair_revision',0)
        if isempty(candidate)
            [phase.parent_seed,phase.parent_descriptive_label,phase.parent_independently_admitted,phase.parent_source_artifact]=chooseSeed(sourceResult,outputDirectory);
        else,phase.parent_seed=candidate.seed;end
        phase.phase='freeze';phase.state='partial_checkpoint';phase.predictions=struct([]);phase.next_trial=1;
        phase.last_repair_revision=repairRevision;
        if isfield(phase,'partial_trial'),phase=rmfield(phase,'partial_trial');end
    end
    if ~isempty(phase.trials)&&~isfield(phase.trials,'base_descriptive_label')
        for k=1:numel(phase.trials)
            phase.trials(k).base_descriptive_label=baseLabel(phase.trials(k).descriptive_label);
            phase.trials(k).descriptive_label=flightLabel(phase.trials(k).base_descriptive_label,phase.trials(k).physical_flight_count);
        end
    end
    if isempty(candidate)&&~phase.parent_independently_admitted&&isfield(sourceResult,'observations')
        [newSeed,newLabel,admitted,newArtifact]=chooseSeed(sourceResult,outputDirectory);
        if admitted
            phase.parent_seed=newSeed;phase.parent_descriptive_label=newLabel;
            phase.parent_independently_admitted=true;phase.parent_source_artifact=newArtifact;
            phase.predictions=struct([]);phase.next_trial=1;phase.phase='freeze';phase.state='partial_checkpoint';
            if isfield(phase,'partial_trial'),phase=rmfield(phase,'partial_trial');end
        end
    end
    if isempty(phase.parent_seed)
        phase.state='unresolved_obstruction';phase.phase='no_source_predictor';checkpoint();return
    end
    if norm(phase.parent_seed.parameter-cfg.baseline_v3_parameters(:),inf)>cfg.acceptance.parameter
        phase.state='unresolved_obstruction';phase.phase='diagnostic_source_has_other_model_parameters';
        phase.message='Nonbaseline source retained as a diagnostic; target-network sector corrections require the registered ten physical parameters.';
        checkpoint();return
    end
    if strcmp(phase.phase,'freeze')
        seed=phase.parent_seed;x=QuadrupedPhysicalChart_v3.retract(seed.state,seed.mode,seed.parameter);
        phase.parent_seed.state=x;
        try
            chart=QuadrupedPhysicalChart_v3.create(x,seed.mode,seed.parameter);
            E=QuadrupedEnergy_v3.evaluate(x,seed.mode,seed.parameter);
            if isempty(candidate)
                [directions,targets,flightCounts]=sectors(phase.parent_descriptive_label,study);
                amplitudes=[-1e-3,1e-3];directionOrigin='fixed-parameter leg symmetry sector; no critical eigenvector claim';
            else
                directions=candidate.physical_directions;targets=candidate.target_labels;
                flightCounts=candidate.target_flight_counts;amplitudes=candidate.signed_amplitudes;
                directionOrigin=candidate.direction_origin;
            end
            for k=1:size(directions,2)
                direction=directions(chart.independent_indices,k);
                if norm(direction)<1e-12,error('RunFamilySectorCorrections_v3:Direction','The proposed sector has no independent physical section component.');end
                direction=direction/norm(direction);
                for signed=amplitudes
                    targetBase=baseLabel(targets{k});
                    prediction=struct('sector_index',k,'target_label',flightLabel(targetBase,flightCounts(k)), ...
                        'target_base_label',targetBase, ...
                        'target_positive_duration_flights',flightCounts(k),'signed_amplitude',signed, ...
                        'repair_revision',repairRevision, ...
                        'independent_indices',chart.independent_indices,'reference',[x(chart.independent_indices);E], ...
                        'normal',[direction;0],'seed_state',QuadrupedPhysicalChart_v3.lift(chart,x(chart.independent_indices)+signed*direction), ...
                        'frozen_utc',char(datetime('now','TimeZone','UTC')), ...
                        'direction_origin',directionOrigin);
                    if isempty(phase.predictions),phase.predictions=prediction;else,phase.predictions(end+1)=prediction;end %#ok<AGROW>
                end
            end
            phase.phase='correct';checkpoint(); % Frozen before any daughter solve.
        catch exception
            phase.state='unresolved_obstruction';phase.phase='predictor_manifold_unavailable';
            phase.failure=struct('identifier',exception.identifier,'message',exception.message);
            checkpoint();return
        end
    end
    while phase.next_trial<=numel(phase.predictions)&&toc(clock)<maxWallSeconds
        if maxWallSeconds-toc(clock)<30,break;end
        index=phase.next_trial;prediction=phase.predictions(index);seed=phase.parent_seed;seed.state=prediction.seed_state;
        attempt=1;initialJacobian=[];
        if isfield(phase,'partial_trial')&&phase.partial_trial.prediction_index==index
            seed.state=phase.partial_trial.best_candidate;initialJacobian=phase.partial_trial.final_jacobian;
            if any(~isfinite(initialJacobian(:)))||~isequal(size(initialJacobian),[numel(prediction.reference),numel(prediction.reference)]),initialJacobian=[];end
            if ~isempty(initialJacobian)
                saved=load(V3Path_v3(fullfile(outputDirectory,phase.partial_trial.artifact)),'report');old=saved.report;
                same=norm(old.seed.parameter(:)-seed.parameter(:),inf)<1e-12&&isequal(old.seed.mode(:),seed.mode(:)) ...
                    &&old.seed.occurrence==seed.occurrence&&isequal(old.options.Constraint.reference(:),prediction.reference(:)) ...
                    &&isequal(old.options.Constraint.normal(:),prediction.normal(:))&&old.options.Constraint.target==prediction.signed_amplitude;
                if ~same,initialJacobian=[];end
            end
            attempt=phase.partial_trial.attempt+1;seed.provenance.resumed_best_candidate=phase.partial_trial.artifact;
        end
        seed.provenance.signed_sector_prediction=prediction;
        options=struct('Symmetry','none','FamilyConstraint','amplitude', ...
            'Constraint',struct('reference',prediction.reference,'normal',prediction.normal,'target',prediction.signed_amplitude), ...
            'Energy',QuadrupedEnergy_v3.evaluate(seed.state,seed.mode,seed.parameter),'MaxWallSeconds',max(1,maxWallSeconds-toc(clock)), ...
            'MaxReturnTime',cfg.domain.primitive_period_max,'MaxCycleEvents',cfg.domain.event_count_max, ...
            'Integration',struct('RelTol',cfg.integration.relative_tolerance,'AbsTol',cfg.integration.absolute_tolerance), ...
            'ReplayIntegration',struct('RelTol',cfg.integration.replay_relative_tolerance,'AbsTol',cfg.integration.replay_absolute_tolerance), ...
            'SolverOptions',struct('MaxIterations',cfg.budgets.root_max_iterations,'MaxFunctionEvaluations',cfg.budgets.root_max_function_evaluations, ...
                'UseBroyden',true,'JacobianRefreshInterval',5,'FunctionTolerance',1e-12, ...
                'InitialJacobian',initialJacobian,'ReuseJacobian',~isempty(initialJacobian), ...
                'ResidualAcceptanceTolerance',cfg.acceptance.reduced_residual), ...
            'Acceptance',struct('FullClosureTolerance',cfg.acceptance.full_closure,'EnergyTolerance',cfg.acceptance.energy));
        if ~isempty(candidate)&&isfield(candidate,'event_order_jacobian_options')
            options.SolverOptions.Jacobian=EventOrderChartJacobian_v3(candidate.event_order_jacobian_options);
        elseif strcmp(study,'P2')||strcmp(study,'P1')
            isRoundC=isfield(sourceResult,'repair_round')&&strcmp(sourceResult.repair_round,'C');
            x=phase.parent_seed.state;q=phase.parent_seed.mode;
            synchronized=~any(q)&&norm(x([5,6]),inf)<1e-8 ...
                &&norm(x([7,9,11,13])-x(7),inf)<1e-8&&norm(x([8,10,12,14])-x(8),inf)<1e-8;
            if isRoundC&&phase.parent_independently_admitted&&synchronized&&phase.parent_seed.occurrence==1
                gate=BL1SectorChartGate(cfg);
                options.SolverOptions.Jacobian=EventOrderChartJacobian_v3(struct('PhysicalParameter',seed.parameter, ...
                    'BLTouchdownsPerReturn',1,'RelativeCandidateSteps',1e-4,'MaximumRelativeError',.001,'FailurePolicy','nan'));
                phase.common_chart_gate=gate;
            end
        end
        % Predictor and its equation are saved before any physics/return call.
        artifact=sprintf('sector_%02d_signed_%+.6g_revision_%03d_attempt_%03d.mat', ...
            prediction.sector_index,prediction.signed_amplitude,repairRevision,attempt);
        RoundSave_v3(fullfile(outputDirectory,['predictor_',artifact]),struct('seed',seed,'prediction',prediction,'options',options));
        [solution,report]=PeriodicSolutionSolver_v3(seed,options);
        trial=struct('prediction',prediction,'accepted_periodic_orbit',~isempty(solution), ...
            'target_model_parameters',false,'accepted_in_registered_domain',false, ...
            'target_gait_recovered',false,'descriptive_label','unresolved','base_descriptive_label','unresolved','physical_flight_count',NaN, ...
            'full_closure',report.full_closure,'amplitude_constraint_error',number(report,'constraint_residual',NaN), ...
            'primary_failure',report.primary_failure,'replay_failure',report.replay_failure, ...
            'artifact',artifact,'ancestry_claimed',false,'parent_independently_admitted',phase.parent_independently_admitted);
        if ~isempty(solution)
            classification=GaitIdentification_v3(solution);trial.base_descriptive_label=char(classification.label);
            trial.physical_flight_count=classification.flight_count;
            trial.descriptive_label=flightLabel(trial.base_descriptive_label,trial.physical_flight_count);
            trial.target_model_parameters=norm(solution.parameter-cfg.baseline_v3_parameters(:),inf)<=cfg.acceptance.parameter;
            trial.accepted_in_registered_domain=inDomain(solution,cfg);
            trial.target_gait_recovered=strcmp(trial.base_descriptive_label,baseLabel(prediction.target_label)) ...
                &&trial.physical_flight_count==prediction.target_positive_duration_flights;
            phase.accepted_count=phase.accepted_count+1;
        end
        RoundSave_v3(fullfile(outputDirectory,artifact),struct('solution',solution,'report',report,'trial',trial,'seed',seed,'prediction',prediction));
        phase.function_evaluations=phase.function_evaluations+solverCount(report);
        wallFailure=contains(failureMessage(report.primary_failure),'wall budget','IgnoreCase',true);
        if isempty(solution)&&(wallFailure||toc(clock)>=maxWallSeconds)&&numel(report.final_candidate)==14
            phase.partial_trial=struct('prediction_index',index,'attempt',attempt, ...
                'best_candidate',report.final_candidate,'final_jacobian',member(report.solver,'finalJacobian',[]), ...
                'artifact',artifact,'reason','Numerical task slice ended; same signed constraint resumes from best candidate and reliable final Jacobian.');
            checkpoint();break
        end
        if isfield(phase,'partial_trial'),phase=rmfield(phase,'partial_trial');end
        if isempty(phase.trials),phase.trials=trial;
        else,trial=orderfields(trial,phase.trials);phase.trials(end+1)=trial;end %#ok<AGROW>
        phase.next_trial=index+1;checkpoint();
        fprintf('%s signedsector%d amplitude%+.3g accepted%d target%d closure%.3g\n',study,prediction.sector_index,prediction.signed_amplitude,trial.accepted_periodic_orbit,trial.target_gait_recovered,trial.full_closure);
    end
    if phase.next_trial>numel(phase.predictions),phase.phase='executed_signed_sector_trials';phase.state='accepted';end
    checkpoint();
    function checkpoint()
        RoundSave_v3(file,struct('phase',phase));summary=phase;
        summary=rmfield(summary,'parent_seed');RoundJSON_v3(fullfile(outputDirectory,'family_switch.json'),summary);
    end
end
function [seed,label,admitted,artifact]=chooseSeed(result,outputDirectory)
    seed=[];label='';admitted=false;artifact='';if isempty(result.observations),return;end
    observations=result.observations;
    current=true(size(observations));
    if isfield(observations,'repair_revision')&&isfield(result,'last_repair_revision'),current=[observations.repair_revision]==result.last_repair_revision;end
    eligible=[observations.accepted]&current;
    if isfield(observations,'target_model_parameters'),eligible=eligible&[observations.target_model_parameters];end
    if isfield(observations,'accepted_in_registered_domain'),eligible=eligible&[observations.accepted_in_registered_domain];end
    index=find(eligible,1);if isempty(index),index=find(current,1);end
    if isempty(index),index=1;end
    obs=observations(index);artifact=obs.artifact;
    file=fullfile(outputDirectory,artifact);loaded=load(V3Path_v3(file),'solution','predictor');
    if ~isempty(loaded.solution)
        orbit=loaded.solution;occurrence=1;
        if isstruct(orbit.section_chart)&&isfield(orbit.section_chart,'BL_touchdowns_per_return'),occurrence=orbit.section_chart.BL_touchdowns_per_return;end
        seed=struct('state',orbit.initial_state,'mode',orbit.initial_mode,'parameter',orbit.parameter, ...
            'return_policy',orbit.return_policy,'occurrence',occurrence,'provenance',struct('source_correction_artifact',artifact));
        label=obs.gait;admitted=true;
    else
        seed=loaded.predictor;label=sourceHint(result.source.source_path);
    end
end
function label=sourceHint(file)
    if contains(file,'PK'),label='PK';elseif contains(file,'PIP'),label='PIP';elseif contains(file,'B2'),label='B2';
    elseif any(contains(file,{'_FE','_FG','FG_GG'})),label='HB_front';
    elseif any(contains(file,{'_HE','_HG','GE_HE'})),label='HB_hind';
    elseif any(contains(file,{'_GE','_GG'})),label='GP';else,label='BD';end
end
function [directions,targets,counts]=sectors(label,study)
    bound=zeros(14,1);bound([7,9])=1;bound([11,13])=-1;
    front=zeros(14,1);front(11)=1;front(13)=-1;
    hind=zeros(14,1);hind(7)=1;hind(9)=-1;
    switch baseLabel(label)
        case {'PK','PIP'},directions=bound;targets={'BD'};
        case 'BD',directions=[front,hind];targets={'HB_front','HB_hind'};
        case 'HB_front',directions=hind;targets={'GP'};
        case 'HB_hind',directions=front;targets={'GP'};
        otherwise,directions=zeros(14,0);targets={};
    end
    count=1;if strcmp(study,'P2'),count=2;end
    counts=repmat(count,1,numel(targets));
end
function label=baseLabel(label)
    switch char(label)
        case 'B2',label='BD';case 'F2',label='HB_front';case 'H2',label='HB_hind';case 'G2',label='GP';case 'PK2',label='PK';
    end
end
function label=flightLabel(label,count)
    if count~=2,return;end
    switch char(label)
        case 'BD',label='B2';case 'HB_front',label='F2';case 'HB_hind',label='H2';case 'GP',label='G2';case 'PK',label='PK2';
    end
end
function value=number(report,name,fallback)
    value=fallback;if isfield(report,name),value=report.(name);end
end
function value=member(report,name,fallback)
    value=fallback;if isfield(report,name),value=report.(name);end
end
function message=failureMessage(failure)
    message='';if isfield(failure,'message'),message=failure.message;end
end
function gate=BL1SectorChartGate(cfg)
    v3=V3Root_v3(mfilename('fullpath'));
    file='Research_v3/next_round/theory/event_order_chart_validation.json';
    baseline=jsondecode(fileread(V3Path_v3(fullfile(v3,file))));
    currentFile='Research_v3/next_round/theory/two_BL_chart_validation.json';
    current=jsondecode(fileread(V3Path_v3(fullfile(v3,currentFile))));
    if ~baseline.common_reliable||~baseline.common_classical_first_derivative||~baseline.common_chart_verified ...
            ||~baseline.baseline_chart_admitted||~baseline.missing_actual_events_rejected||~current.passed ...
            ||~V3HashMatches_v3(current.helper_sha256, fullfile(v3,current.helper_path))
        error('RunFamilySectorCorrections_v3:ChartGate','The common-C1 regular BL1 chart must have executed evidence under the current helper hash.');
    end
    gate=struct('BL1_evidence',file,'current_source_gate',currentFile, ...
        'helper_path',current.helper_path,'helper_sha256',current.helper_sha256, ...
        'scope','Independently admitted synchronous flight-to-flight BL1 parent; every actual trial verifies its two transverse zero-compression cohorts; no C2 claim.');
    registration=fullfile(v3,'Research_v3','next_round','family_sector_chart_repair_registration.json');
    if ~isfile(V3Path_v3(registration))
        record=struct('schema_version','prospective-source-C-sector-chart-repair-v3-1', ...
            'registered_utc',char(datetime('now','TimeZone','UTC')), ...
            'diagnosis','RoundA PK-control signed bound sector had closure.00096176955 and no finite raw-order hybrid Jacobian despite independently admitted synchronous parent.', ...
            'failed_evidence','Research_v3/next_round/tasks/full/P2_source_17_A/source_recovery.json', ...
            'repair','Apply independently validated common-C1 event-order metadata only within actual regular BL1 cohort chart; h=1e-4 with h/2 refinement and unchanged acceptance.', ...
            'gate',gate,'full_closure_tolerance',cfg.acceptance.full_closure, ...
            'acceptance_tolerances_changed',false,'domain_changed',false);
        RoundJSON_v3(registration,record);
    end
end
function value=solverCount(report)
    value=0;if isfield(report,'solver')&&isfield(report.solver,'functionEvaluationCount'),value=report.solver.functionEvaluationCount;end
end
function inside=inDomain(orbit,cfg)
    energy=QuadrupedEnergy_v3.evaluate(orbit.initial_state,orbit.initial_mode,orbit.parameter);
    speed=orbit.stride_displacement(1)/orbit.period;
    inside=energy>=cfg.domain.energy(1)&&energy<=cfg.domain.energy(2) ...
        &&speed>=cfg.domain.mean_speed(1)&&speed<=cfg.domain.mean_speed(2) ...
        &&orbit.period<=cfg.domain.primitive_period_max ...
        &&max(abs(orbit.trajectory.state(:,5)))<=cfg.domain.pitch_abs_max ...
        &&sum(~[orbit.event_history.is_stop])<=cfg.domain.event_count_max;
end
