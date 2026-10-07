function cfg=RoundProfileRevisions_v3(cfg)
%ROUNDPROFILEREVISIONS_V3 Apply separately recorded task-slice revisions.
% The original registration and total numerical budget remain immutable.
    v3=V3Root_v3(mfilename('fullpath'));
    file=fullfile(v3,'Research_v3','next_round',['profile_revisions_',cfg.profile,'.mat']);
    if ~isfile(V3Path_v3(file)),return;end
    saved=load(V3Path_v3(file),'revisions');revisions=saved.revisions;
    for k=1:numel(revisions)
        revision=revisions(k);
        if revision.total_wall_seconds~=cfg.budgets.total_wall_seconds
            error('RoundProfileRevisions_v3:Budget','A slice revision cannot change the true total budget.');
        end
        cfg.budgets.per_task_wall_seconds=revision.per_task_wall_seconds;
    end
    cfg.profile_revision_history=['Research_v3/next_round/profile_revisions_',cfg.profile,'.json'];
end
