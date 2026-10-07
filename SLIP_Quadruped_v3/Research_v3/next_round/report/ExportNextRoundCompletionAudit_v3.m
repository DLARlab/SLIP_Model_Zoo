function audit=ExportNextRoundCompletionAudit_v3()
%EXPORTNEXTROUNDCOMPLETIONAUDIT_V3 Summarize saved execution and protection.
% This performs no new orbit simulations, modifies no task checkpoint and
% does not convert an unfinished search into scientific success.
    here=fileparts(mfilename('fullpath'));roundFolder=fileparts(here);
    v3=fileparts(fileparts(roundFolder));repo=fileparts(v3);
    V3LegacyAddPath_v3(fullfile(v3,'Research_v3','Drivers_v3'));
    protection=RoundProtection_v3('verify');
    loaded=load(V3Path_v3(fullfile(roundFolder,'checkpoint_full.mat')),'state');state=loaded.state;
    validation=load(V3Path_v3(fullfile(roundFolder,'solver','solver_validation_summary.mat')),'summary');
    gate=validation.summary;
    gateCurrent=gate.all_required_gates_passed;
    for k=1:numel(gate.source_hashes)
        source=gate.source_hashes(k);
        gateCurrent=gateCurrent&&V3HashMatches_v3(source.sha256, fullfile(v3,source.path));
    end
    audit=struct('schema_version','next-round-completion-audit-v3-1', ...
        'created_utc',char(datetime('now','TimeZone','UTC')), ...
        'starting_commit',state.starting_commit,'matlab_version',version, ...
        'architecture',computer,'execution_status',state.status, ...
        'network_achieved',state.network_achieved, ...
        'global_completeness_claimed',state.global_completeness_claimed, ...
        'charged_numerical_task_wall_seconds',state.numerical_wall_seconds, ...
        'registered_total_wall_seconds',state.config.budgets.total_wall_seconds, ...
        'remaining_wall_seconds',max(0,state.config.budgets.total_wall_seconds-state.numerical_wall_seconds), ...
        'counted_function_evaluations',state.function_evaluations, ...
        'registered_total_function_evaluations',state.config.budgets.total_function_evaluations, ...
        'total_budget_exhausted',state.numerical_wall_seconds>=state.config.budgets.total_wall_seconds || ...
            state.function_evaluations>=state.config.budgets.total_function_evaluations, ...
        'evaluation_count_scope','Completed stored solver/map counters; interruption uncertainties and uncaptured in-flight work remain separately recorded in the ledger.', ...
        'solver_gates_passed',gateCurrent,'solver_gate_source_hashes',gate.source_hashes, ...
        'protection',protection,'unfinished_tasks',struct([]), ...
        'executed_rounds',struct([]),'branch_coverage',struct([]), ...
        'pip_candidates',struct([]),'attachment_accuracy_repairs',struct([]), ...
        'branch_identity_bridges',struct([]),'files_over_100000000_bytes',struct([]), ...
        'maximum_working_file',struct(),'working_file_count',0);
    audit.solver_gate_artifact='Research_v3/next_round/solver/solver_validation_summary.mat';
    for roundName={'A','B','C'}
        selected=strcmp({state.tasks.repair_round},roundName{1}) & [state.tasks.attempts]>0;
        tasks=state.tasks(selected);
        audit.executed_rounds=[audit.executed_rounds,struct('round',roundName{1}, ...
            'distinct_executed_tasks',numel(tasks),'task_ids',{{tasks.id}}, ...
            'actual_attempts',sum([tasks.attempts]))]; %#ok<AGROW>
    end
    for k=1:numel(state.tasks)
        task=state.tasks(k);
        if ~task.execution_completed
            row=struct('id',task.id,'kind',task.kind,'state',task.state, ...
                'scientific_status',task.scientific_status,'attempts',task.attempts, ...
                'phase','','artifact',task.artifact);
            phaseFile=fullfile(roundFolder,'tasks','full',task.id,'phase_checkpoint.mat');
            if isfile(V3Path_v3(phaseFile))
                phase=load(V3Path_v3(phaseFile),'record');
                if isfield(phase,'record')&&isfield(phase.record,'phase'),row.phase=phase.record.phase;end
            else
                familyPhaseFile=fullfile(roundFolder,'tasks','full',task.id,'family_switch_checkpoint.mat');
                if isfile(V3Path_v3(familyPhaseFile))
                    savedPhase=load(V3Path_v3(familyPhaseFile),'phase');
                    if isfield(savedPhase,'phase')&&isfield(savedPhase.phase,'phase'),row.phase=savedPhase.phase.phase;end
                end
            end
            audit.unfinished_tasks=[audit.unfinished_tasks,row]; %#ok<AGROW>
        end
        if isempty(task.artifact)||~isfile(V3Path_v3(fullfile(v3,task.artifact))),continue;end
        saved=load(V3Path_v3(fullfile(v3,task.artifact)),'result');result=saved.result;
        if strcmp(task.kind,'continuation')&&isfield(result,'energy')
            energy=result.energy(:);speed=result.mean_speed(:);
            if isempty(energy),continue;end
            row=struct('id',task.id,'state',task.state,'accepted_records',numel(energy), ...
                'new_point_records',task.new_points,'energy_interval',[min(energy),max(energy)], ...
                'mean_speed_interval',[min(speed),max(speed)],'artifact',task.artifact);
            audit.branch_coverage=[audit.branch_coverage,row]; %#ok<AGROW>
        elseif strcmp(task.kind,'PIP_candidate')&&isfield(result,'phase')
            accepted=0;if isfield(result,'amplitudes')&&~isempty(result.amplitudes),accepted=sum([result.amplitudes.accepted]);end
            attachment='not_yet_evaluated';
            if isfield(result,'attachment_evidence'),attachment=result.attachment_evidence.status;end
            row=struct('id',task.id,'phase',result.phase,'critical_energy',result.critical_energy, ...
                'accepted_signed_daughter_records',accepted,'attachment_status',attachment, ...
                'state',task.state,'artifact',task.artifact);
            audit.pip_candidates=[audit.pip_candidates,row]; %#ok<AGROW>
        elseif strcmp(task.kind,'attachment_accuracy_repair')&&isfield(result,'attachment_evidence')
            row=struct('id',task.id,'source_task_id',result.source_task_id, ...
                'state',task.state,'scientific_status',task.scientific_status, ...
                'attachment_status',result.attachment_evidence.status, ...
                'original_attachment_status',result.original_attachment_evidence.status, ...
                'physically_accepted',result.physically_accepted,'domain_accepted',result.domain_accepted, ...
                'original_records_modified',result.original_records_modified,'artifact',task.artifact);
            audit.attachment_accuracy_repairs=[audit.attachment_accuracy_repairs,row]; %#ok<AGROW>
        elseif strcmp(task.kind,'branch_identity_bridge')&&isfield(result,'accepted_increment_count')
            row=struct('id',task.id,'state',task.state,'scientific_status',task.scientific_status, ...
                'new_continuation_increments',result.accepted_increment_count, ...
                'local_numerical_connection_supported',result.local_numerical_connection_supported, ...
                'rigorous_ancestry_claimed',result.rigorous_ancestry_claimed,'artifact',task.artifact);
            audit.branch_identity_bridges=[audit.branch_identity_bridges,row]; %#ok<AGROW>
        end
    end
    files=workingFiles(repo,'');audit.working_file_count=numel(files);
    if ~isempty(files)
        [~,largest]=max([files.bytes]);audit.maximum_working_file=files(largest);
        audit.files_over_100000000_bytes=files([files.bytes]>100000000);
    end
    audit.working_files_fit_github_limit=isempty(audit.files_over_100000000_bytes);
    assert(audit.working_files_fit_github_limit,'A working file exceeds the requested 100 MB limit.');
    auditPath=fullfile(v3,'Audits_v3','Next_Round_Completion_v3');
    RoundSave_v3([auditPath,'.mat'],struct('audit',audit));RoundJSON_v3([auditPath,'.json'],audit);
    fid=fopen(V3Path_v3([auditPath,'.md']),'w');assert(fid>=0);finish=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'# Executed MATLAB round: completion and remaining-work audit\n\n');
    fprintf(fid,'Saved status: `%s`. Requested network achieved: `%d`; global completeness claimed: `%d`.\n\n',state.status,state.network_achieved,state.global_completeness_claimed);
    fprintf(fid,'Starting commit `%s`; MATLAB `%s`, `%s`. All required solver gates passed: `%d`.\n\n',state.starting_commit,version,computer,audit.solver_gates_passed);
    fprintf(fid,'Charged numerical task wall time: %.6f / %.0f seconds; remaining %.6f seconds. Counted evaluations: %d / %d. Total registered budget exhausted: `%d`. Separate focused audit costs and interruption uncertainty are recorded in their saved audits and the execution ledger. Startup, report waits and postprocessing are not numerical task time.\n\n',audit.charged_numerical_task_wall_seconds,audit.registered_total_wall_seconds,audit.remaining_wall_seconds,audit.counted_function_evaluations,audit.registered_total_function_evaluations,audit.total_budget_exhausted);
    fprintf(fid,'Protection passes against %d pre-existing outside-v3 files: no changed, missing or added outside-v3 files. Working files exceeding 100000000 bytes: %d. Largest scanned working file: `%s`, %d bytes. `.git` object storage is excluded from this working-file scan.\n\n',protection.baseline_count,numel(audit.files_over_100000000_bytes),audit.maximum_working_file.path,audit.maximum_working_file.bytes);
    fprintf(fid,'## Actual research rounds\n\n| Round | Distinct executed tasks | Actual attempts |\n|---|---:|---:|\n');
    for row=audit.executed_rounds,fprintf(fid,'| %s | %d | %d |\n',row.round,row.distinct_executed_tasks,row.actual_attempts);end
    fprintf(fid,'\n## Executed continuation coverage\n\nHistorical points copied into a new trace remain historical. The new-point column counts newly accepted appended records; neither row counts nor matching gait labels establish distinct families or attachment. Batch caps remain resumable checkpoints.\n\n| Task | Records | New records | Energy interval | Mean-speed interval | State |\n|---|---:|---:|---|---|---|\n');
    for row=audit.branch_coverage,fprintf(fid,'| `%s` | %d | %d | [%.12g, %.12g] | [%.12g, %.12g] | `%s` |\n',row.id,row.accepted_records,row.new_point_records,row.energy_interval(1),row.energy_interval(2),row.mean_speed_interval(1),row.mean_speed_interval(2),row.state);end
    fprintf(fid,'\n## PIP candidate phases\n\n| Task | Critical energy | Accepted signed records | Attachment gate | Phase |\n|---|---:|---:|---|---|\n');
    for row=audit.pip_candidates,fprintf(fid,'| `%s` | %.15g | %d | `%s` | `%s` |\n',row.id,row.critical_energy,row.accepted_signed_daughter_records,row.attachment_status,row.phase);end
    fprintf(fid,'\n## Separately registered attachment accuracy repairs\n\nThe original PIP records and their failed gates remain unchanged. A physically accepted repair replaces one record only in a copied ten-record sequence; an unsuccessful physical repair retains the original sequence. Campaign promotion additionally requires domain acceptance. Neither case counts a new branch amplitude.\n\n| Repair task | Source task | Original gate | Copied sequence gate | Physical/domain acceptance | Execution state |\n|---|---|---|---|---|---|\n');
    for row=audit.attachment_accuracy_repairs,fprintf(fid,'| `%s` | `%s` | `%s` | `%s` | `%d` / `%d` | `%s` |\n',row.id,row.source_task_id,row.original_attachment_status,row.attachment_status,row.physically_accepted,row.domain_accepted,row.state);end
    fprintf(fid,'\n## Imported-PK bridge experiment\n\n| Task | New increments | Endpoint/local connection supported | State |\n|---|---:|---|---|\n');
    for row=audit.branch_identity_bridges,fprintf(fid,'| `%s` | %d | `%d` | `%s` |\n',row.id,row.new_continuation_increments,row.local_numerical_connection_supported,row.state);end
    fprintf(fid,'\n## Exact unfinished MATLAB queue\n\n%d tasks remain unfinished. This is incomplete research, not a nonexistence result. Dependencies, repair revisions, counters, failure records and seed provenance are in `Research_v3/next_round/task_queue_full.json` and the native `checkpoint_full.mat`. The table below contains every unfinished task at this snapshot.\n\n| Task | Kind | Execution state | Scientific status | Current phase | Attempts |\n|---|---|---|---|---|---:|\n',numel(audit.unfinished_tasks));
    for row=audit.unfinished_tasks,fprintf(fid,'| `%s` | `%s` | `%s` | `%s` | `%s` | %d |\n',row.id,row.kind,row.state,row.scientific_status,row.phase,row.attempts);end
end

function records=workingFiles(root,prefix)
    listing=V3Dir_v3(fullfile(root,prefix));records=struct('path',{},'bytes',{});
    for k=1:numel(listing)
        item=listing(k);if any(strcmp(item.name,{'.','..','.git'})),continue;end
        relative=fullfile(prefix,item.name);
        if item.isdir,records=[records,workingFiles(root,relative)]; %#ok<AGROW>
        else,records(end+1)=struct('path',strrep(relative,filesep,'/'),'bytes',item.bytes);end %#ok<AGROW>
    end
end
