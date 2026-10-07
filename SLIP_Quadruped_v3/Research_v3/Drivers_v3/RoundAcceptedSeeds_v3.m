function seeds=RoundAcceptedSeeds_v3(tasks,cfg)
%ROUNDACCEPTEDSEEDS_V3 Discover accepted source/sector seeds from saved evidence.
% No orbit is admitted by filename or gait label. Correction acceptance,
% target physical parameters and the prospectively registered domain are
% independently checked before both-direction tasks can be registered.
    v3=V3Root_v3(mfilename('fullpath'));
    example=struct('node','','task_id','','repair_round','','artifact','', ...
        'variable','solution','symmetry','none','label','','flight_count',NaN, ...
        'full_closure',NaN,'duplicate_observations_are_distinct_records',true);
    seeds=example([]);
    for k=1:numel(tasks)
        task=tasks(k);
        if ~any(strcmp(task.kind,{'P1_source','P2_source','period_two_sector','PIP_candidate'}))||isempty(task.artifact),continue;end
        resultFile=fullfile(v3,task.artifact);if ~isfile(V3Path_v3(resultFile)),continue;end
        saved=load(V3Path_v3(resultFile),'result');result=saved.result;
        % The opposed-spread restriction has its own constrained branch
        % progression. Generic full-space continuation changes that chart.
        if isfield(result,'correction_method')&&strcmp(result.correction_method,'exact-opposed-spread-twisted-restriction'),continue;end
        if ~isfield(result,'observations')&&~isfield(result,'family_switch')&&~isfield(result,'amplitudes'),continue;end
        folder=fileparts(task.artifact);
        if strcmp(task.kind,'PIP_candidate')&&isfield(result,'amplitudes')
            if isempty(result.amplitudes)||~isstruct(result.amplitudes)||~isfield(result.amplitudes,'accepted'),continue;end
            for signValue=[-1,1]
                amplitudes=result.amplitudes;
                selected=find([amplitudes.accepted]&sign([amplitudes.signed_amplitude])==signValue);
                if isempty(selected),continue;end
                [~,largest]=max(abs([amplitudes(selected).signed_amplitude]));j=selected(largest);trial=amplitudes(j);
                record=example;record.node=sprintf('%s_daughter_%d',task.id,j);
                record.task_id=task.id;record.repair_round=task.repair_round;
                record.artifact=strrep(fullfile(folder,trial.artifact),filesep,'/');record.variable='orbit';
                record.label=char(trial.gait);record.full_closure=trial.full_closure;
                if ~isfile(V3Path_v3(fullfile(v3,record.artifact))),continue;end
                candidate=load(V3Path_v3(fullfile(v3,record.artifact)),'orbit');
                if isempty(candidate.orbit)||~admitted(candidate.orbit,cfg),continue;end
                classification=GaitIdentification_v3(candidate.orbit);record.flight_count=classification.flight_count;
                record.symmetry='pronk';seeds(end+1)=record; %#ok<AGROW>
            end
        end
        observations=struct([]);if isfield(result,'observations'),observations=result.observations;end
        for j=1:numel(observations)
            obs=observations(j);
            if ~obs.accepted||~obs.target_model_parameters||~obs.accepted_in_registered_domain,continue;end
            record=example;record.node=RoundObservationNode_v3(task.id,obs);
            record.task_id=task.id;record.repair_round=task.repair_round;
            record.artifact=strrep(fullfile(folder,obs.artifact),filesep,'/');
            record.label=obs.gait;record.flight_count=obs.flight_count;record.full_closure=obs.final_closure;
            if ~isfile(V3Path_v3(fullfile(v3,record.artifact))),continue;end
            candidate=load(V3Path_v3(fullfile(v3,record.artifact)),'solution');
            if isempty(candidate.solution)||~admitted(candidate.solution,cfg),continue;end
            record.symmetry=actualSymmetry(candidate.solution);seeds(end+1)=record; %#ok<AGROW>
        end
        if ~isfield(result,'family_switch')||~isfield(result.family_switch,'trials'),continue;end
        for j=1:numel(result.family_switch.trials)
            trial=result.family_switch.trials(j);if ~trial.accepted_periodic_orbit,continue;end
            record=example;record.node=sprintf('%s_sector_%d',task.id,j);
            record.task_id=task.id;record.repair_round=task.repair_round;
            record.artifact=strrep(fullfile(folder,trial.artifact),filesep,'/');
            record.label=trial.descriptive_label;record.flight_count=trial.physical_flight_count;
            record.full_closure=trial.full_closure;
            if ~isfile(V3Path_v3(fullfile(v3,record.artifact))),continue;end
            candidate=load(V3Path_v3(fullfile(v3,record.artifact)),'solution');
            if isempty(candidate.solution)||~admitted(candidate.solution,cfg),continue;end
            record.symmetry=actualSymmetry(candidate.solution);seeds(end+1)=record; %#ok<AGROW>
        end
    end
end
function yes=admitted(orbit,cfg)
    energy=QuadrupedEnergy_v3.evaluate(orbit.initial_state,orbit.initial_mode,orbit.parameter);
    speed=orbit.stride_displacement(1)/orbit.period;
    closure=norm(orbit.poincare_state(2:end)-orbit.initial_state(2:end),inf);
    events=orbit.event_history;physicalEventCount=sum(~[events.is_stop]);
    yes=norm(orbit.parameter-cfg.baseline_v3_parameters(:),inf)<=cfg.acceptance.parameter ...
        &&closure<=cfg.acceptance.full_closure&&energy>=cfg.domain.energy(1)&&energy<=cfg.domain.energy(2) ...
        &&speed>=cfg.domain.mean_speed(1)&&speed<=cfg.domain.mean_speed(2) ...
        &&orbit.period<=cfg.domain.primitive_period_max ...
        &&physicalEventCount<=cfg.domain.event_count_max ...
        &&max(abs(orbit.trajectory.state(:,5)))<=cfg.domain.pitch_abs_max;
end
function symmetry=actualSymmetry(orbit)
    x=orbit.initial_state;q=orbit.initial_mode;p=orbit.parameter;
    angles=x([7,9,11,13]);rates=x([8,10,12,14]);symmetry='none';
    if all(q==q(1))&&norm(angles-angles(1),inf)<1e-8&&norm(rates-rates(1),inf)<1e-8 ...
            &&norm(x([5,6]),inf)<1e-8&&norm(p([1,3,5,7])-p([2,4,6,8]),inf)<1e-12&&abs(p(10)-.5)<1e-12
        symmetry='pronk';
    elseif q(1)==q(2)&&q(3)==q(4)&&norm(angles([2,4])-angles([1,3]),inf)<1e-8 ...
            &&norm(rates([2,4])-rates([1,3]),inf)<1e-8
        symmetry='left-right';
    end
end
