function revision=RegisterResearchProfileRevision_v3(profile,perTaskWallSeconds,diagnosis,evidence)
%REGISTERRESEARCHPROFILEREVISION_V3 Prospective task-slice cost repair.
% Only the checkpoint slice changes. This does not reset counters, extend
% the total numerical budget, or alter any physical/acceptance tolerances.
    profile=validatestring(profile,{'validation','full'});
    validateattributes(perTaskWallSeconds,{'numeric'},{'scalar','positive','finite'});
    validateattributes(diagnosis,{'char','string'},{'nonempty'});
    v3=V3Root_v3(mfilename('fullpath'));folder=fullfile(v3,'Research_v3','next_round');
    cfg=ResolveResearchRoundConfig_v3(profile);
    if perTaskWallSeconds>cfg.budgets.total_wall_seconds
        error('RegisterResearchProfileRevision_v3:Slice','A task slice cannot exceed the remaining profile total budget.');
    end
    file=fullfile(folder,['profile_revisions_',profile,'.mat']);revisions=struct([]);
    if isfile(V3Path_v3(file)),saved=load(V3Path_v3(file),'revisions');revisions=saved.revisions;end
    revision=struct('schema_version','prospective-task-slice-repair-v3-1','profile',profile, ...
        'revision',numel(revisions)+1,'registered_utc',char(datetime('now','TimeZone','UTC')), ...
        'diagnosis',char(diagnosis),'evidence',evidence, ...
        'previous_task_slice_seconds',cfg.budgets.per_task_wall_seconds, ...
        'per_task_wall_seconds',perTaskWallSeconds,'total_wall_seconds',cfg.budgets.total_wall_seconds, ...
        'acceptance_tolerances_changed',false,'domain_changed',false, ...
        'original_registration_preserved',true,'total_budget_changed',false);
    if isempty(revisions),revisions=revision;else,revisions(end+1)=revision;end
    RoundSave_v3(file,struct('revisions',revisions));
    RoundJSON_v3(fullfile(folder,['profile_revisions_',profile,'.json']),revisions);
end
