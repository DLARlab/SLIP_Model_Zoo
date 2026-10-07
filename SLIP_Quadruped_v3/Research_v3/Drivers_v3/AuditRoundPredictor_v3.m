function result=AuditRoundPredictor_v3(fixtureIndex,cfg,outputDirectory,maxWallSeconds)
%AUDITROUNDPREDICTOR_V3 Execute quantitative traces of saved repaired seeds.
% This measures the first physical failure and raw rejected integration
% segment after B's transformation; no periodic orbit is accepted here.
    v3=V3Root_v3(mfilename('fullpath'));clock=tic;
    loaded=load(V3Path_v3(fullfile(v3,'Research_v3','next_round','source_inventory.mat')),'inventory');
    study='P2';if startsWith(loaded.inventory.records(fixtureIndex).source.study,'P1'),study='P1';end
    sourceTask=sprintf('%s_source_%02d_B',study,fixtureIndex);
    sourceFolder=fullfile(v3,'Research_v3','next_round','tasks',cfg.profile,sourceTask);
    loaded=load(V3Path_v3(fullfile(sourceFolder,'source_checkpoint.mat')),'result');source=loaded.result;
    checkpointFile=fullfile(outputDirectory,'trace_checkpoint.mat');
    if isfile(V3Path_v3(checkpointFile)),saved=load(V3Path_v3(checkpointFile),'result');result=saved.result;
    else
        columns=1:min(3,numel(source.observations));
        result=struct('schema_version','repaired-source-flow-audit-v3-1','state','partial_checkpoint', ...
            'scientific_status','repaired_predictor_flow_not_periodic_acceptance','source_task',sourceTask, ...
            'observation_indices',columns,'next_index',1,'cases',struct([]),'new_points',0,'function_evaluations',0);
    end
    for k=result.next_index:numel(result.observation_indices)
        if toc(clock)>=maxWallSeconds,break;end
        observation=source.observations(result.observation_indices(k));
        predictorFile=strrep(observation.artifact,'_correction.mat','_predictor.mat');
        seed=load(V3Path_v3(fullfile(sourceFolder,predictorFile)),'predictor');
        trace=SourceTrialTrace_v3(seed.predictor,struct('Horizon',min(observation.source_period,cfg.domain.primitive_period_max), ...
            'Integration',struct('RelTol',cfg.integration.relative_tolerance,'AbsTol',cfg.integration.absolute_tolerance)));
        artifact=sprintf('column_%05d_repaired_predictor_trace.mat',observation.column);
        RoundSave_v3(fullfile(outputDirectory,artifact),struct('trace',trace,'predictor',seed.predictor,'observation',observation));
        failure=trace.first_physical_failure;
        if ~isempty(fieldnames(failure))
            geometry=failure.diagnostics;
            failure.axial_forces_from_geometry=seed.predictor.parameter([1,1,2,2]).*geometry.stance_compressions;
            failure.axial_forces_from_geometry(~failure.mode)=0;
            failure.force_evaluation_scope='Algebraic diagnostic on rejected state; no force clamp or accepted physical flow.';
        end
        entry=struct('column',observation.column,'execution_success',trace.execution.success, ...
            'completed_physical_samples',numel(trace.trajectory.time),'actual_events',trace.actual_events, ...
            'first_physical_failure',failure,'first_event_discrepancy',trace.first_event_discrepancy, ...
            'artifact',artifact,'accepted_periodic_solution',false);
        if isempty(result.cases),result.cases=entry;else,result.cases(end+1)=entry;end %#ok<AGROW>
        result.next_index=k+1;saveCheckpoint();
    end
    if result.next_index>numel(result.observation_indices),result.state='accepted';result.scientific_status='repaired_predictor_flow_diagnosis_executed';end
    saveCheckpoint();
    function saveCheckpoint()
        RoundSave_v3(checkpointFile,struct('result',result));RoundJSON_v3(fullfile(outputDirectory,'predictor_audit.json'),result);
    end
end
