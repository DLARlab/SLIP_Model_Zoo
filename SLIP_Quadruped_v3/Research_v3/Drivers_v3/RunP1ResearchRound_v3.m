function result=RunP1ResearchRound_v3(task,cfg,outputDirectory,maxWallSeconds)
%RUNP1RESEARCHROUND_V3 Single-flight source recovery and critical neighborhoods.
% P1 tasks target PK, bound, both independent half-bound orientations and
% gallop. Source labels are predictors, never classification or ancestry.
    clock=tic;result=RecoverRoundSource_v3(task,cfg,outputDirectory,maxWallSeconds,'P1');
    if strcmp(task.repair_round,'C')&&result.next_column_index>numel(result.selected_columns)
        result.landing_alternative=RunLandingPredictorAlternatives_v3(result,cfg,outputDirectory,max(0,maxWallSeconds-toc(clock)));
        result.function_evaluations=result.function_evaluations+result.landing_alternative.function_evaluations;
        result.new_points=result.new_points+result.landing_alternative.accepted_count;
        result.accepted_count=result.accepted_count+result.landing_alternative.accepted_count;
        alternative=result.landing_alternative.accepted_observations;
        if ~isempty(alternative)
            if ~isfield(result.observations,'candidate_variant')
                for k=1:numel(result.observations),result.observations(k).candidate_variant='mapped_source';end
            end
            fields=fieldnames(alternative);
            for fieldIndex=1:numel(fields)
                name=fields{fieldIndex};
                if ~isfield(result.observations,name)
                    for k=1:numel(result.observations),result.observations(k).(name)=[];end
                end
            end
            fields=fieldnames(result.observations);
            for fieldIndex=1:numel(fields)
                name=fields{fieldIndex};
                if ~isfield(alternative,name)
                    for k=1:numel(alternative),alternative(k).(name)=[];end
                end
            end
            result.observations=[result.observations,orderfields(alternative,result.observations)];
            result.state='accepted';result.scientific_status='alternative_source_landing_orbits_recovered_ancestry_unresolved';
        end
        if strcmp(result.landing_alternative.state,'partial_checkpoint'),result.state='partial_checkpoint';end
    end
    if result.next_column_index>numel(result.selected_columns)
        result.family_switch=RunFamilySectorCorrections_v3(result,cfg,outputDirectory,max(0,maxWallSeconds-toc(clock)),'P1');
        result.function_evaluations=result.function_evaluations+result.family_switch.function_evaluations;
        result.new_points=result.new_points+result.family_switch.accepted_count;
        if strcmp(result.family_switch.state,'partial_checkpoint'),result.state='partial_checkpoint';end
    end
    result.requested_network={'PK','BD','HB_front','HB_hind','GP'};
    result.phase_count_target=1;
    result.family_specific_method='P1 source/critical neighborhoods; physical unconstrained left/right directions after paired source correction';
    RoundJSON_v3(fullfile(outputDirectory,'source_recovery.json'),result);
end
