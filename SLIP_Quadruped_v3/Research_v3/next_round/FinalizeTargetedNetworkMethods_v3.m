function audit=FinalizeTargetedNetworkMethods_v3()
%FINALIZETARGETEDNETWORKMETHODS_V3 Register and verify map-free administration.
    v3=V3Root_v3(mfilename('fullpath'));
    folders={'','Schema_v3','Adapters_v3','Dynamics_v3','Simulation_v3','Orbit_v3', ...
        'Numerics_v3','Stability_v3','Graphics_v3','Research_v3/Drivers_v3'};
    for k=1:numel(folders),V3LegacyAddPath_v3(fullfile(v3,folders{k}));end
    folder=fullfile(v3,'Research_v3/next_round');before=load(V3Path_v3(fullfile(folder,'checkpoint_full.mat')),'state');
    audit=struct('schema_version','post-segment-targeted-method-integration-v3-1', ...
        'registered_utc',char(datetime('now','TimeZone','UTC')),'maps_executed',0, ...
        'diagnosis','A final MaxTasks-limited call can leave counters beyond the true budget without the next loop check; an export-only call also resets status to running.', ...
        'repair','Prioritize cumulative wall/evaluation exhaustion at the end of every invocation; preserve counters and task/phase scientific states.', ...
        'physical_model_or_acceptance_changed',false,'total_budget_changed',false, ...
        'previous_main_sha256','be7358b62cbb128cb12425624b49b3e19021c0f6459a2dd880de4a22dda8c58f', ...
        'current_main_sha256',RoundSHA256_v3(fullfile(v3,'RunResearchRound_v3.m')), ...
        'previous_export_sha256','dcd05a5e20f5bded136ebc4bbf6beb37a61033a4ba530eca63efebcb3105106e', ...
        'current_export_sha256',RoundSHA256_v3(fullfile(v3,'Research_v3/Drivers_v3/ExportResearchRound_v3.m')), ...
        'previous_target_loader_sha256','01b7c5b4aa08a5745a47580ba2a907b320d96dd2837a70a789d0da1a134ca6b8', ...
        'current_target_loader_sha256',RoundSHA256_v3(fullfile(v3,'Research_v3/Drivers_v3/RoundTargetedCandidates_v3.m')));
    RoundJSON_v3(fullfile(folder,'targeted_network_integration_registration.json'),audit);
    cfg=ResolveResearchRoundConfig_v3('full');assert(cfg.budgets.total_wall_seconds==10800);
    assert(numel(cfg.attachment_accuracy_repair_candidates)==4);
    ids={cfg.attachment_accuracy_repair_candidates.id};audit.new_task_ids=ids(3:4);
    findings=checkcode(fullfile(v3,'Research_v3/Drivers_v3/RoundTargetedCandidates_v3.m'),'-id');
    assert(isempty(findings));checkcode(fullfile(v3,'RunResearchRound_v3.m'),'-id');
    checkcode(fullfile(v3,'Research_v3/Drivers_v3/ExportResearchRound_v3.m'),'-id');
    gate=jsondecode(fileread(V3Path_v3(fullfile(folder,'solver/solver_validation_summary.json'))));assert(gate.all_required_gates_passed);
    for k=1:numel(gate.source_hashes)
        item=gate.source_hashes(k);assert(V3HashMatches_v3(item.sha256, fullfile(v3,item.path)));
    end
    report=RunResearchRound_v3('Profile','full','Resume',true,'ExecuteNumerics',false);
    after=load(V3Path_v3(fullfile(folder,'checkpoint_full.mat')),'state');
    assert(after.state.numerical_wall_seconds==before.state.numerical_wall_seconds ...
        &&after.state.function_evaluations==before.state.function_evaluations);
    assert(all(ismember(ids(3:4),{after.state.tasks.id})));
    assert(report.local_numerical_imported_PK_bridge_supported);
    if after.state.numerical_wall_seconds>=cfg.budgets.total_wall_seconds ...
            ||after.state.function_evaluations>=cfg.budgets.total_function_evaluations
        assert(strcmp(report.status,'total_budget_exhausted'));
    end
    audit.charged_wall_seconds=after.state.numerical_wall_seconds;
    audit.remaining_wall_seconds=cfg.budgets.total_wall_seconds-after.state.numerical_wall_seconds;
    audit.function_evaluations=after.state.function_evaluations;
    audit.export_counter_invariance_passed=true;audit.current_solver_hash_gate_passed=true;
    audit.bridge_graph_qualification_passed=true;audit.status=report.status;
    phase=load(V3Path_v3(fullfile(folder,'tasks/full/P2_source_17_C/family_switch_checkpoint.mat')),'phase');
    if isfield(phase.phase,'partial_trial')&&~isempty(fieldnames(phase.phase.partial_trial))
        trial=phase.phase.partial_trial;
        audit.C17_partial=trial;
        if isfield(trial,'artifact')&&isfile(V3Path_v3(fullfile(folder,'tasks/full/P2_source_17_C',trial.artifact)))
            saved=load(V3Path_v3(fullfile(folder,'tasks/full/P2_source_17_C',trial.artifact)),'report');r=saved.report;
            audit.C17_diagnostics=struct('initial_residual',r.initial_physical_norm, ...
                'final_residual',r.final_physical_norm,'full_closure',r.full_closure, ...
                'accepted_Newton_steps',r.solver.acceptedNewtonIterations, ...
                'initial_jacobian_used',r.solver.output.initialJacobianUsed, ...
                'primary_failure',r.primary_failure,'replay_failure',r.replay_failure);
        end
    end
    RoundSave_v3(fullfile(folder,'targeted_network_integration_audit.mat'),struct('audit',audit));
    if isfield(audit,'C17_partial'),audit=rmfield(audit,'C17_partial');end
    RoundJSON_v3(fullfile(folder,'targeted_network_integration_audit.json'),audit);
    fprintf('CHARGED %.9f REMAINING %.9f FE %d STATUS %s\n',audit.charged_wall_seconds,audit.remaining_wall_seconds,audit.function_evaluations,audit.status);
    disp(audit.new_task_ids);if isfield(audit,'C17_diagnostics'),disp(audit.C17_diagnostics);end
end
