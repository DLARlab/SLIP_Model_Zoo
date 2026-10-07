function result=RunP2ResearchRound_v3(task,cfg,outputDirectory,maxWallSeconds)
%RUNP2RESEARCHROUND_V3 Double-flight B2, front-spread, hind-spread and G2 tasks.
% Includes ordinary/delayed PIP and the distinct PK_B2 parent as source
% comparisons. Delayed-law mismatch is not a family-level impossibility.
    clock=tic;result=RecoverRoundSource_v3(task,cfg,outputDirectory,maxWallSeconds,'P2');
    if result.next_column_index>numel(result.selected_columns)
        result.family_switch=RunFamilySectorCorrections_v3(result,cfg,outputDirectory,max(0,maxWallSeconds-toc(clock)),'P2');
        result.function_evaluations=result.function_evaluations+result.family_switch.function_evaluations;
        result.new_points=result.new_points+result.family_switch.accepted_count;
        if strcmp(result.family_switch.state,'partial_checkpoint'),result.state='partial_checkpoint';end
    end
    result.requested_network={'PIP','B2','F2','H2','G2','PK_B2_bridge'};
    result.phase_count_target=2;
    result.family_specific_method='P2 occurrence-aware double-flight correction, ordinary-PIP bridge and distinct front/hind spread directions';
    RoundJSON_v3(fullfile(outputDirectory,'source_recovery.json'),result);
end
