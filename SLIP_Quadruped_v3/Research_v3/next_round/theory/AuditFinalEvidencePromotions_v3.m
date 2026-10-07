function audit=AuditFinalEvidencePromotions_v3()
%AUDITFINALEVIDENCEPROMOTIONS_V3 Typed saved-evidence review; no maps/solves.
% The earlier nine-record audit and its source remain reproducible unchanged.
    timer=tic;here=fileparts(mfilename('fullpath'));v3=fileparts(fileparts(fileparts(here)));
    for folder={'Schema_v3','Adapters_v3','Dynamics_v3','Simulation_v3','Orbit_v3', ...
            'Numerics_v3','Stability_v3','Research_v3/Drivers_v3'},V3LegacyAddPath_v3(fullfile(v3,folder{1}));end
    graphPath='Research_v3/next_round/graph/index_full.json';graphHash=RoundSHA256_v3(fullfile(v3,graphPath));
    graph=jsondecode(fileread(V3Path_v3(fullfile(v3,graphPath))));
    positive={'recovered_orbit','restricted_daughter','restricted_period_two_orbit','restricted_period_two_predictor_replay'};
    selected=graph.nodes(arrayfun(@(n)ismember(n.type,positive)&&endsWith(n.evidence,'.mat'),graph.nodes));
    records=struct([]);
    for k=1:numel(selected)
        node=selected(k);[saved,digest]=stableLoad(node.evidence);orbit=[];accepted=false;closure=Inf;reportedFlight=NaN;
        if isfield(saved,'solution'),orbit=saved.solution;elseif isfield(saved,'orbit'),orbit=saved.orbit;end
        if isfield(saved,'observation')
            accepted=saved.observation.accepted;closure=saved.observation.final_closure;reportedFlight=saved.observation.flight_count;
        elseif isfield(saved,'entry'),accepted=saved.entry.accepted;closure=saved.entry.full_closure;
        elseif isfield(saved,'trial')
            trial=saved.trial;
            if isfield(trial,'accepted'),accepted=trial.accepted;elseif isfield(trial,'accepted_periodic_orbit'),accepted=trial.accepted_periodic_orbit;end
            closure=member(trial,'full_closure',Inf);reportedFlight=member(trial,'actual_flight_count',member(trial,'physical_flight_count',NaN));
        elseif isfield(saved,'item')
            accepted=saved.item.passed;closure=saved.item.BL2_full_closure;reportedFlight=saved.item.actual_flight_count;
        end
        assert(~isempty(orbit)&&accepted,'Positive graph node lacks an accepted saved orbit: %s.',node.id);
        gait=GaitIdentification_v3(orbit);data=HybridCycleData_v3.unpack(orbit);ids=[data.history.guard_id];counts=arrayfun(@(id)sum(ids==id),1:8);
        label=flightLabel(char(gait.label),gait.flight_count);standing=startsWith(node.type,'restricted_period_two');
        countGate=all(counts>=1);if standing,countGate=all(counts==2)&&gait.flight_count==2;end
        labelMatch=strcmp(char(node.label),label);primitive=char(gait.primitive.status);
        valid=labelMatch&&countGate&&closure<=1e-8&&strcmp(primitive,'primitive_within_checked_bound') ...
            &&(~isfinite(reportedFlight)||reportedFlight==gait.flight_count);
        item=struct('id',node.id,'artifact',node.evidence,'artifact_sha256',digest,'graph_type',node.type, ...
            'reported_label',char(node.label),'recomputed_label',label,'classification_status',char(gait.status), ...
            'primitive_status',primitive,'checked_cover_bound',gait.primitive.checked_cover_bound, ...
            'global_primitivity_proved_by_numerical_check',gait.primitive.global_primitivity_proved, ...
            'physical_flight_count',gait.flight_count,'reported_flight_count',reportedFlight, ...
            'contact_counts_TD_then_LO',counts,'actual_event_count',numel(ids), ...
            'energy',QuadrupedEnergy_v3.evaluate(orbit.initial_state,orbit.initial_mode,orbit.parameter), ...
            'period',orbit.period,'horizontal_drift',orbit.stride_displacement(1),'recorded_full_closure',closure, ...
            'saved_trajectory_closure',gait.primitive.closure_error,'label_matches',labelMatch,'passed',valid);
        if isempty(records),records=item;else,records(end+1)=item;end %#ok<AGROW>
    end
    accuracy=struct([]);files=V3Dir_v3(fullfile(v3,'Research_v3/next_round/tasks/full','**','accuracy_repair_r*.mat'));
    for k=1:numel(files)
        relative=strrep(fullfile(files(k).folder,files(k).name),[v3,filesep],'');[saved,digest]=stableLoad(relative);
        if ~isfield(saved,'result')||~saved.result.physically_accepted||~saved.result.domain_accepted,continue;end
        copied=saved.copiedRecord;p=saved.orbit.parameter(:);
        connection=struct('singular_values',copied.singular_values,'matrix_uncertainty_estimate',copied.matrix_uncertainty_estimate, ...
            'critical_energy_uncertainty_estimate',copied.settings.energy_bracket_tolerance/2,'critical_energy',copied.critical_energy, ...
            'parent_derivatives_reliable',copied.parent_derivatives_reliable,'transversality',struct('estimate',copied.transversality_estimate, ...
            'uncertainty_estimate',copied.transversality_uncertainty_estimate),'amplitudes',copied.amplitudes, ...
            'reflection_symmetry_at_parameters',all(p([7,8])==0));
        recomputed=PronkAttachmentEvidence_v3(connection,copied.settings);origins=struct([]);
        for j=1:numel(copied.amplitudes)
            entry=copied.amplitudes(j);local=strcmp(entry.artifact,saved.result.artifact);
            if local,path=fullfile(files(k).folder,entry.artifact);
            else,path=fullfile(v3,'Research_v3/next_round/tasks/full',saved.result.source_task_id,entry.artifact);end
            assert(isfile(V3Path_v3(path)),'Accuracy-copy provenance cannot resolve original/replacement artifact.');
            origin=struct('signed_amplitude',entry.signed_amplitude,'artifact',strrep(path,[v3,filesep],''), ...
                'sha256',RoundSHA256_v3(path),'is_replacement',local);
            if isempty(origins),origins=origin;else,origins(end+1)=origin;end %#ok<AGROW>
        end
        item=struct('artifact',relative,'sha256',digest,'source_task_id',saved.result.source_task_id, ...
            'reported_attachment_status',saved.result.attachment_evidence.status,'recomputed_attachment_status',recomputed.status, ...
            'attachment_evidence',recomputed,'resolved_amplitude_provenance',origins, ...
            'copied_records_count',sum(~[origins.is_replacement]),'new_replacement_records_count',sum([origins.is_replacement]), ...
            'new_amplitudes_count',0,'original_records_modified',saved.result.original_records_modified, ...
            'passed',strcmp(recomputed.status,saved.result.attachment_evidence.status));
        if isempty(accuracy),accuracy=item;else,accuracy(end+1)=item;end %#ok<AGROW>
    end
    bridges=struct([]);files=V3Dir_v3(fullfile(v3,'Research_v3/next_round/tasks/full','**','bridge_checkpoint.mat'));
    for k=1:numel(files)
        relative=strrep(fullfile(files(k).folder,files(k).name),[v3,filesep],'');[saved,digest]=stableLoad(relative);phase=saved.phase;
        replays=struct([]);lastOrbit=[];
        for j=1:numel(phase.accepted_points)
            point=phase.accepted_points(j);path=fullfile(files(k).folder,point.artifact);path=strrep(path,[v3,filesep],'');
            [record,pointHash]=stableLoad(path);lastOrbit=record.solution;
            item=struct('index',point.index,'artifact',path,'sha256',pointHash,'full_closure',record.report.full_closure, ...
                'constraint_error',record.report.constraint_residual,'locality_gate',record.trial.continuation_locality_gate, ...
                'passed',record.report.accepted&&record.report.full_closure<=1e-8 ...
                    &&abs(record.report.constraint_residual)<=1e-8&&record.trial.continuation_locality_gate);
            if isempty(replays),replays=item;else,replays(end+1)=item;end %#ok<AGROW>
        end
        endpoint=struct();identity=false;targetProvenance=false;targetHash='';
        completed=phase.fresh_seed_records==1&&phase.accepted_increment_count==4;
        if completed&&~isempty(lastOrbit)
            registration=jsondecode(fileread(V3Path_v3(fullfile(v3,'Research_v3/next_round/low_energy_PK_bridge_registration.json'))));
            [frozen,hash]=stableLoad(registration.candidates.candidate_artifact);assert(strcmp(hash,registration.candidates.candidate_sha256));
            candidate=frozen.candidate;[endpoint,~]=ComparePronkBridgeOrbits_v3(lastOrbit,candidate.target_orbit,candidate.comparison_tolerances);
            identity=endpoint.same_local_numerical_orbit_supported;
            frozenTarget=find(strcmp({candidate.input_hashes.path},candidate.target_artifact));
            assert(isscalar(frozenTarget)&&candidate.target_entry.signed_amplitude==-.01);
            targetHash=candidate.input_hashes(frozenTarget).sha256;
        end
        replayPass=completed&&numel(replays)==5&&all([replays.passed]);attachment=false;
        for j=1:numel(accuracy)
            if strcmp(accuracy(j).source_task_id,'PIP_PK_low_energy_neighborhood')
                attachment=attachment||strcmp(accuracy(j).recomputed_attachment_status,'numerically_supported_restricted_attachment');
                if completed&&strcmp(accuracy(j).recomputed_attachment_status,'numerically_supported_restricted_attachment')
                    origins=accuracy(j).resolved_amplitude_provenance;
                    exactNegative=find([origins.signed_amplitude]==-.01&~[origins.is_replacement]);
                    assert(isscalar(exactNegative),'Composed attachment must retain the original negative -.01 daughter.');
                    [originalNegative,originalHash]=stableLoad(origins(exactNegative).artifact);
                    targetProvenance=targetProvenance||(strcmp(originalHash,targetHash) ...
                        &&originalNegative.entry.accepted&&originalNegative.entry.signed_amplitude==-.01 ...
                        &&isequal(originalNegative.orbit.initial_state,candidate.target_orbit.initial_state) ...
                        &&isequal(originalNegative.orbit.parameter,candidate.target_orbit.parameter));
                end
            end
        end
        localConnection=replayPass&&identity;
        item=struct('artifact',relative,'sha256',digest,'fresh_source_admission_records',phase.fresh_seed_records, ...
            'accepted_increment_count',phase.accepted_increment_count,'fresh_replay_records',replays, ...
            'all_five_fresh_replays_and_locality_pass',replayPass,'recomputed_endpoint_comparison',endpoint, ...
            'endpoint_identity_supported',identity,'reported_local_connection',phase.local_numerical_connection_supported, ...
            'local_numerical_connection_supported',localConnection,'low_PIP_restricted_attachment_supported',attachment, ...
            'frozen_negative_target_sha256',targetHash,'frozen_negative_target_provenance_verified',targetProvenance, ...
            'composed_low_PIP_to_imported_PK_numerical_connection_supported',localConnection&&attachment&&targetProvenance, ...
            'rigorous_or_global_ancestry_claimed',false,'passed',~phase.local_numerical_connection_supported||localConnection);
        if isempty(bridges),bridges=item;else,bridges(end+1)=item;end %#ok<AGROW>
    end
    analytic=graph.nodes(strcmp({graph.nodes.type},'analytic_restricted_local_existence'));
    for k=1:numel(analytic)
        token=regexp(analytic(k).id,'n(\d+)$','tokens','once');index=str2double(token{1});exact=1+(2*index+1)^2*pi^2/160;
        assert(contains(analytic(k).scope,sprintf('%.16g',exact)),'Analytic resonance numbering was conflated with numerical candidate numbering.');
    end
    assert(V3HashMatches_v3(graphHash, fullfile(v3,graphPath)),'Graph changed during final review.');
    stamp=char(datetime('now','TimeZone','UTC','Format','yyyyMMdd''T''HHmmssSSS'));
    audit=struct('schema_version','independent-final-evidence-promotion-audit-v3-2','created_utc',stamp,'matlab_version',version, ...
        'helper_sha256',RoundSHA256_v3([mfilename('fullpath'),'.m']),'graph_snapshot_artifact',graphPath, ...
        'graph_snapshot_sha256',graphHash,'graph_network_achieved',graph.network_achieved, ...
        'graph_global_completeness_claimed',graph.global_completeness_claimed,'positive_orbit_records_checked',numel(records), ...
        'records',records,'accuracy_copy_reviews',accuracy,'bridge_reviews',bridges, ...
        'non_unresolved_edges',graph.edges(~strcmp({graph.edges.type},'unresolved_candidate')), ...
        'time_phase_equivalence_edges',graph.edges(strcmp({graph.edges.type},'time_phase_equivalence')), ...
        'elapsed_saved_data_postprocessing_seconds',toc(timer),'new_maps',0,'new_simulations',0, ...
        'passed',allPassed(records)&&allPassed(accuracy)&&allPassed(bridges) ...
            &&~graph.network_achieved&&~graph.global_completeness_claimed, ...
        'scope','Saved complete physical histories and typed claims reviewed independently; counts may duplicate orbits. No new dynamics replay, unrestricted C2, interval certification, full stability, global completeness or nonexistence claim.');
    stem=['independent_final_evidence_promotion_audit_',stamp];relative=['Research_v3/next_round/theory/',stem];
    RoundSave_v3(fullfile(here,[stem,'.mat']),struct('audit',audit));RoundJSON_v3(fullfile(here,[stem,'.json']),audit);
    RoundJSON_v3(fullfile(here,'independent_final_evidence_promotion_audit_latest.json'), ...
        struct('mat_artifact',[relative,'.mat'],'json_artifact',[relative,'.json'],'passed',audit.passed,'created_utc',stamp));
    assert(audit.passed,'Positive typed evidence failed independent final scientific promotion review.');
    fprintf('Final saved-evidence review passed: %d orbit records, %d accuracy-copy gates, %d bridge reviews; no maps.\n',numel(records),numel(accuracy),numel(bridges));
    function [saved,digest]=stableLoad(relative)
        path=fullfile(v3,relative);before=RoundSHA256_v3(path);saved=load(V3Path_v3(path));digest=RoundSHA256_v3(path);
        assert(strcmp(before,digest),'Evidence changed during saved-data read: %s.',relative);
    end
end
function value=member(object,name,fallback)
    value=fallback;if isstruct(object)&&isfield(object,name),value=object.(name);end
end
function value=allPassed(records)
    value=isempty(records)||all([records.passed]);
end
function label=flightLabel(label,count)
    if count~=2,return;end
    switch label
        case 'BD',label='B2';case 'HB_front',label='F2';case 'HB_hind',label='H2';case 'GP',label='G2';case 'PK',label='PK2';
    end
end
