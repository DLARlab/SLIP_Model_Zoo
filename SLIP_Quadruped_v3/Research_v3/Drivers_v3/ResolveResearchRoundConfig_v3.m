function cfg=ResolveResearchRoundConfig_v3(profile)
%RESOLVERESEARCHROUNDCONFIG_V3 Immutable source-informed round registration.
    profile=validatestring(profile,{'validation','full'});
    v3=V3Root_v3(mfilename('fullpath'));folder=fullfile(v3,'Research_v3','next_round');
    file=fullfile(folder,['registration_',profile,'.json']);
    if isfile(V3Path_v3(file))
        cfg=jsondecode(fileread(V3Path_v3(file)));AppendCriticalRoundSources_v3();
        cfg=RoundAdditionalCandidates_v3(cfg);cfg=RoundProfileRevisions_v3(cfg);
        cfg=RoundPeriodTwoCandidates_v3(cfg);cfg=RoundSourceMethods_v3(cfg);
        cfg=RoundDomainRevisions_v3(cfg);cfg=RoundTargetedCandidates_v3(cfg);return
    end
    RoundProtection_v3('capture');inventory=RoundSourceInventory_v3();
    old=jsondecode(fileread(V3Path_v3(fullfile(v3,'Research_v3','config','full.json'))));
    cfg=old;cfg.schema_version='matlab-research-round-v3-1';cfg.profile=profile;
    cfg.experiment_id=['next-round-',profile,'-20261007'];cfg.created_utc=char(datetime('now','TimeZone','UTC'));
    cfg.source_inventory='Research_v3/next_round/source_inventory.mat';
    cfg.starting_commit=strtrim(fileread(V3Path_v3(fullfile(folder,'baseline','initial_head.txt'))));
    cfg.historical_domain=old.domain;
    maxEnergy=max(12,1.2*inventory.source_initial_energy_range(2));
    maxSpeed=max(6,1.5*max(abs(inventory.source_initial_speed_range)));
    maxPeriod=max(12,1.5*inventory.source_period_predictor_range(2));
    cfg.domain.energy=[1.000001,maxEnergy];cfg.domain.mean_speed=[-maxSpeed,maxSpeed];
    cfg.domain.initial_speed_diagnostic=[-maxSpeed,maxSpeed];
    cfg.domain.pitch_abs_max=max(1.2,1.2*max(abs(inventory.source_pitch_range)));
    cfg.domain.primitive_period_max=maxPeriod;cfg.domain.event_count_max=128;
    cfg.domain.energy_stages=struct('ordinary_parent_and_P2',[1.000001,3], ...
        'P1_critical_neighborhood',[8,14],'full_source_comparison',[1.000001,maxEnergy]);
    cfg.domain.derivation=struct('energy','1.2 times maximum algebraic mapped source energy; minimum12', ...
        'mean_speed','Prospective broad bound from1.5 times max initial source speed; initial and mean speed remain separate observables', ...
        'period','1.5 times max positive source period predictor; minimum12', ...
        'pitch','1.2 times maximum source absolute pitch; minimum1.2', ...
        'source_initial_ranges',inventory.source_initial_speed_range, ...
        'historical_P1_critical_initial_speed',4.43406193516227, ...
        'historical_P1_critical_kinetic_energy',.5*4.43406193516227^2);
    cfg.budgets.total_wall_seconds=10800;
    cfg.budgets.total_function_evaluations=300000;
    cfg.budgets.per_task_wall_seconds=240;
    cfg.budgets.continuation_batch_points=12;
    cfg.budgets.root_max_iterations=35;cfg.budgets.root_max_function_evaluations=4000;
    cfg.budgets.fixture_columns_per_repair_round=[6,12,24];
    cfg.budgets.minimum_repair_rounds=3;cfg.budgets.continuation_wall_seconds=240;
    cfg.budgets.semantics='One total numerical wall budget across tasks and retries; task slices and point batches only checkpoint progress.';
    cfg.integration=struct('relative_tolerance',1e-10,'absolute_tolerance',1e-12, ...
        'replay_relative_tolerance',2e-12,'replay_absolute_tolerance',2e-14);
    cfg.acceptance=struct('full_closure',1e-8,'reduced_residual',1e-10, ...
        'energy',1e-8,'stance_constraint',1e-8,'parameter',1e-12);
    cfg.parent_only_pronk.wall_seconds=240;cfg.parent_only_pronk.maximum_connections=5;
    cfg.parent_only_pronk.scan_points=24;
    cfg.repair_rounds=struct('id',{'A','B','C'}, ...
        'method',{'direct conversion + fixed-energy correction and quantitative trace', ...
        'adjacent/source-minimum neighbors + physical rephase/retraction + scaled correction', ...
        'adaptive source density + unrestricted physical coordinates + alternate section occurrence'}, ...
        'do_not_claim',{'Raw replay failure does not reject a family.', ...
        'Physical retraction is distinct from nonlinear correction.', ...
        'A successful corrected seed does not certify parent ancestry.'});
    cfg.status='registered_before_numerical_experiments';
    if strcmp(profile,'validation')
        cfg.budgets.total_wall_seconds=1800;cfg.budgets.per_task_wall_seconds=90;
        cfg.budgets.total_function_evaluations=30000;cfg.budgets.continuation_batch_points=3;
        cfg.budgets.fixture_columns_per_repair_round=[2,3,4];
    end
    RoundJSON_v3(file,cfg);save(V3Path_v3(fullfile(folder,['registration_',profile,'.mat'])),'cfg','-v7');
    cfg=RoundAdditionalCandidates_v3(cfg);
    cfg=RoundProfileRevisions_v3(cfg);
    cfg=RoundPeriodTwoCandidates_v3(cfg);
    cfg=RoundSourceMethods_v3(cfg);
    cfg=RoundDomainRevisions_v3(cfg);
    cfg=RoundTargetedCandidates_v3(cfg);
end
