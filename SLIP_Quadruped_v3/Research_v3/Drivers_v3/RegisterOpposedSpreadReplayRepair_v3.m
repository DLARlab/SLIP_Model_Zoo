function revision=RegisterOpposedSpreadReplayRepair_v3()
%REGISTEROPPOSEDSPREADREPLAYREPAIR_V3 Record the measured public option fix.
% Preserve the original method registration and failed preflight artifacts.
% Call only while the full master writer is stopped; this runs no simulation.
    v3=V3Root_v3(mfilename('fullpath'));folder=fullfile(v3,'Research_v3/next_round');
    base='Research_v3/next_round/opposed_spread_campaign_registration.json';
    method=jsondecode(fileread(V3Path_v3(fullfile(v3,base))));hashes=method.source_hashes;
    for k=1:numel(hashes),hashes(k).sha256=RoundSHA256_v3(fullfile(v3,hashes(k).path));end
    replay=method.replay_integration;
    assert(isfield(replay,'ArmingTolerance'),'Expected the preserved original full-simulator replay setting.');
    replay=rmfield(replay,'ArmingTolerance');
    file=fullfile(folder,'opposed_spread_campaign_method_revisions.json');
    if isfile(V3Path_v3(file))
        journal=jsondecode(fileread(V3Path_v3(file)));latest=journal.entries(end);
        if isequal(latest.source_hashes,hashes),revision=latest;return;end
        number=latest.revision+1;
    else
        journal=struct('schema_version','prospective-opposed-spread-method-journal-v3-1', ...
            'base_registration',base,'entries',struct([]));number=1;
    end
    evidence=cell(1,2);
    signs={'negative','positive'};
    for k=1:2
        task=sprintf('opposed_spread_n0_%s_A1e-3_campaign',signs{k});
        source=fullfile(folder,'tasks/full',task,'result.mat');
        evidence{k}=['Research_v3/next_round/method_history/',task,'_before_replay_schema_fix_result.mat'];
        target=fullfile(v3,evidence{k});
        if ~isfile(V3Path_v3(target)),assert(isfile(V3Path_v3(source)),'Missing measured task failure.');copyfile(V3Path_v3(source),V3Path_v3(target));end
    end
    revision=struct('revision',number,'registered_utc',char(datetime('now','TimeZone','UTC')), ...
        'diagnosis','Both standing tasks rejected unknown top-level ReplayIntegration.ArmingTolerance before map or Newton evaluation. Complete simulator settings had been passed through a narrower public replay-options interface.', ...
        'repair','Pass only the six public replay override fields; the delegated map retains its own simulator arming settings. No physics, map, acceptance or true numerical budget changes.', ...
        'replay_integration',replay,'source_hashes',hashes, ...
        'previous_driver_source','Research_v3/next_round/method_history/RunOpposedSpreadPeriodTwo_v3_before_replay_schema_fix.txt', ...
        'failure_evidence',{evidence}, ...
        'known_failed_solver_evaluations',0,'acceptance_tolerances_changed',false);
    if isempty(journal.entries),journal.entries=revision;else,journal.entries(end+1)=revision;end
    RoundSave_v3(fullfile(folder,'opposed_spread_campaign_method_revisions.mat'),struct('journal',journal));
    RoundJSON_v3(file,journal);
end
