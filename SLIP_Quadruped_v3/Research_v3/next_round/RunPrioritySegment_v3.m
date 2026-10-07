function reports=RunPrioritySegment_v3(taskIds)
%RUNPRIORITYSEGMENT_V3 Execute an ordered checkpoint segment of the full round.
% The public runner owns scientific gates, resume state and the registered
% global budget. Each ID gets one visit here; a slice is not a branch endpoint.
    if nargin<1
        taskIds={'PIP_PK_low_energy_neighborhood','PIP_candidate_1', ...
            'PK_continuation_m1','PK_continuation_p1', ...
            'restricted_daughter_1_m1','restricted_daughter_1_p1', ...
            'restricted_daughter_2_m1','restricted_daughter_2_p1', ...
            'PIP_candidate_2','PIP_candidate_3','P2_source_17_C', ...
            'PIP_n0_measured_flip_BL2_front_hind','PIP_measured_flip_BL2_front_hind'};
    end
    reports=cell(size(taskIds));
    for k=1:numel(taskIds)
        fprintf('\nPriority segment visit %d/%d: %s\n',k,numel(taskIds),taskIds{k});
        reports{k}=RunResearchRound_v3('Profile','full','Resume',true, ...
            'MinRepairRounds',3,'MaxTasks',1,'TaskIds',taskIds(k),'ExecuteNumerics',true);
        if strcmp(reports{k}.status,'total_budget_exhausted')
            reports=reports(1:k);break
        end
    end
    stamp=char(datetime('now','TimeZone','UTC','Format','yyyyMMdd''T''HHmmssSSS'));
    folder=fileparts(mfilename('fullpath'));
    RoundSave_v3(fullfile(folder,['priority_segment_',stamp,'.mat']), ...
        struct('task_ids',{taskIds},'reports',{reports}));
end
