classdef EssentialBranchSolutionFile_v3
%ESSENTIALBRANCHSOLUTIONFILE_V3 Explicit schema4 scientific storage.
% Private source candidate. It does not replace any live reader or store.
% The projection preserves literal values, historical decisions and distinct
% occurrence/graph identities. It performs no map, root, classification or
% qualification. Caller owns the writer lease and storage-epoch authority.
% Dense trajectories, event states, solver/FD/iteration tapes, display samples
% and runtime residual graphs are deliberately unavailable, without sidecars.
% Actual compressed MAT bytes must fit an explicit finite measured ceiling.
    methods (Static)
        function c=contract()
            c=struct('schema','C1-essential-native-scientific-projection-v1', ...
                'storage_version','BranchSolutionFile_v3:4', ...
                'roles',{{'accepted','nonedge-control','isolated','rejected','historical-unknown'}}, ...
                'omissions','No dense trajectory, event pre/post state, numerical solver/J/FD/iteration tape, sampled classifier/contact/display array, full correction chart, runtime residual/seed graph or optional historical metadata/proof tree is retained. Historical scalar decisions are not recomputed or newly certified.', ...
                'receipt_reference_availability','Historical qualification locators may have been retired; no future locator hash is required unless separately declared current.', ...
                'cluster_membership_domain','member_indices: non-stop event sequence before time sorting; sorted_member_indices: its time-sorted sequence, not full event_history indices.', ...
                'replay_scope','Fresh replay is required for any trajectory-dependent operation; reconstructed views are not equal to the original full runtime objects.');
        end

        function ix=initialize(file,metadata,maximumBytes)
            ix=EssentialBranchSolutionFile_v3.write(file,metadata,cell(0,1),cell(0,1),cell(0,1),cell(0,1),maximumBytes);
        end

        function ix=write(file,metadata,orbits,reports,pointMetadata,contexts,maximumBytes)
            K=EssentialBranchSolutionFile_v3;
            file=K.path(file);K.fresh(file);K.limit(maximumBytes);
            assert(iscell(orbits)&&iscell(reports)&&iscell(pointMetadata)&&iscell(contexts)&& ...
                numel(orbits)==numel(reports)&&numel(orbits)==numel(pointMetadata)&&numel(orbits)==numel(contexts), ...
                'EssentialBranch:Inputs','Supply equally sized explicit orbit/report/essential-metadata/context cells.');
            records=cell(numel(orbits),1);
            for k=1:numel(records),records{k}=K.project(orbits{k},reports{k},pointMetadata{k},contexts{k});end
            ix=K.writeProjections(file,metadata,records,maximumBytes);
        end

        function ix=writeProjections(file,metadata,canonicalRecords,maximumBytes)
            % Fresh bulk storage of the already-projected plain records.
            % Caller owns independent literal source reads and storage-epoch
            % qualification; this method does not establish new admission.
            K=EssentialBranchSolutionFile_v3;
            file=K.path(file);K.fresh(file);K.limit(maximumBytes);
            K.columnCells(canonicalRecords,'canonical scientific projections');
            % graph validates every canonical record, expected occurrence
            % index, unique occurrence ID, owner order and typed graph link.
            K.graph(metadata,canonicalRecords);p=K.pack(metadata,canonicalRecords);
            K.publish(file,p,maximumBytes,'');ix=K.index(file);
        end

        function [ix,pointIndex]=append(file,orbit,report,metadata,context,maximumBytes)
            K=EssentialBranchSolutionFile_v3;K.limit(maximumBytes);file=K.path(file);
            beforeSHA=RoundSHA256_v3(file);p=K.read(file);records=cell(p.point_count+1,1);
            for k=1:p.point_count,records{k}=K.record(p,k);end
            records{end}=K.project(orbit,report,metadata,context);pointIndex=numel(records);
            assert(context.expected_index==pointIndex,'EssentialBranch:ExpectedOrder','The pending context must bind the actual next occurrence index.');
            branch=p.metadata;
            if isfield(metadata,'edge_enabled')&&isequal(metadata.edge_enabled,true)
                assert(isfield(context,'physical_edge_provenance'),'EssentialBranch:EdgeProvenance','An earned edge requires explicit pre-persisted physical-edge provenance.');
                edge=struct('from',metadata.edge_from,'to',pointIndex, ...
                    'component_identity',metadata.component_identity,'provenance',context.physical_edge_provenance);
                branch.physical_edges{end+1,1}=edge;
            end
            K.graph(branch,records);q=K.pack(branch,records);
            assert(isequal(q.point_digests(:,1:p.point_count),p.point_digests),'EssentialBranch:Prefix','Append cannot alter any prior scientific projection.');
            K.publish(file,q,maximumBytes,beforeSHA);ix=K.index(file);
        end

        function yes=isEssential(file)
            vars=whos('-file',file);yes=isequal(sort({vars.name}),{'branch_index','essential_branch'});
            if yes,p=EssentialBranchSolutionFile_v3.read(file);yes=strcmp(p.storage_version,'BranchSolutionFile_v3:4');end
        end

        function ix=index(file)
            K=EssentialBranchSolutionFile_v3;p=K.read(file);points=cell(p.point_count,1);nativeIDs=points;occurrenceIDs=points;actualDigests=zeros(32,p.point_count,'uint8');
            for k=1:p.point_count
                r=K.record(p,k);m=r.metadata;nativeIDs{k}=r.native_id;occurrenceIDs{k}=r.context.occurrence_id;actualDigests(:,k)=K.hexBytes(K.digest(r));
                points{k}=struct('index',k,'component_identity',m.component_identity,'order',m.order, ...
                    'classification',{K.optional(m,'classification',[])},'nativeE',{K.optional(m,'nativeE',[])}, ...
                    'signedmeanU',{K.optional(m,'signedmeanU',[])},'provenance',r.context, ...
                    'metadata',m,'native_id',r.native_id,'occurrence_id',r.context.occurrence_id, ...
                    'solution_variable','','report_variable','','payload_kind','essential-native-scientific-projection', ...
                    'scientific_projection_readback_verified',true,'whole_public_runtime_equality_claimed',false);
            end
            edges=cell(numel(p.metadata.physical_edges),1);
            for k=1:numel(edges),e=p.metadata.physical_edges{k};edges{k}=struct('from',e.from,'to',e.to,'component_identity',e.component_identity);end
            ix=struct('storage_version',p.storage_version,'metadata',p.metadata,'points',{points},'edges',{edges}, ...
                'scientific_projection_contract',p.contract,'essential_storage',K.marker(), ...
                'record_projection_digests',actualDigests,'record_native_ids',{nativeIDs},'occurrence_ids',{occurrenceIDs}, ...
                'numeric_index',p.numeric_index,'numeric_index_columns',{{'nativeE','signedmeanU','signed_initial_dx','period'}}, ...
                'numeric_index_scope','Derived double search hints with NaN for absent/non-scalar values; exact values and literal missingness remain in selected projections.');
        end

        function statistics=storageStatistics(file)
            % Diagnostic summaries only, after the same strict decoded read.
            K=EssentialBranchSolutionFile_v3;p=K.read(file);
            statistics=struct('schema','C1-essential-storage-statistics-v1', ...
                'scope','Strict decoded table counts and whos native-memory bytes. These are not compressed disk sizes, additive contributions, process RSS or scientific qualification.', ...
                'point_count',p.point_count,'decoded_table_field_count',numel(fieldnames(p)), ...
                'decoded_native_memory_bytes',statisticsNativeBytes(p), ...
                'metadata_native_memory_bytes',statisticsNativeBytes(p.metadata), ...
                'tables',struct(),'dictionaries',struct());
            tableNames={'point_table','event_table','cluster_table'};
            for j=1:numel(tableNames)
                t=p.(tableNames{j});groupCount=0;valueElements=0;
                for k=1:numel(t.columns)
                    groups=t.columns{k}.groups;groupCount=groupCount+numel(groups);
                    for g=1:numel(groups),valueElements=valueElements+numel(groups{g}.values);end
                end
                statistics.tables.(tableNames{j})=struct('rows',t.rows,'columns',numel(t.paths), ...
                    'layouts',numel(t.layouts),'groups',groupCount,'value_elements',valueElements, ...
                    'native_memory_bytes',statisticsNativeBytes(t));
            end
            dictionaryNames={'policy','section','method'};
            for j=1:numel(dictionaryNames)
                d=p.dictionaries.(dictionaryNames{j});statistics.dictionaries.(dictionaryNames{j})= ...
                    struct('entries',numel(d),'native_memory_bytes',statisticsNativeBytes(d));
            end
            statistics.graph_rows=struct('physical_edges',numel(p.metadata.physical_edges), ...
                'record_equalities',numel(p.metadata.record_equalities),'qualified_aliases',numel(p.metadata.qualified_aliases), ...
                'numerical_seams',numel(p.metadata.numerical_seams));

            function count=statisticsNativeBytes(value)
                entry=whos('value');count=entry.bytes;
            end
        end

        function [orbits,reports,metadata]=loadSolutions(file,indices)
            K=EssentialBranchSolutionFile_v3;p=K.read(file);K.indices(indices,p.point_count);
            indices=indices(:);orbits=cell(numel(indices),1);reports=orbits;metadata=orbits;
            seen=containers.Map('KeyType','double','ValueType','double');
            for k=1:numel(indices)
                i=double(indices(k));
                if isKey(seen,i),j=seen(i);orbits{k}=orbits{j};reports{k}=reports{j};metadata{k}=metadata{j};continue;end
                r=K.record(p,i);o=HybridOrbit_v3();
                % Clear omitted default-valued properties; defaults are not saved evidence.
                for name=properties(o).',o.(name{1})=[];end
                for name=fieldnames(r.orbit).',o.(name{1})=r.orbit.(name{1});end
                report=r.report;
                for name=fieldnames(r.method).',report.(name{1})=r.method.(name{1});end
                marker=K.marker();marker.native_id=r.native_id;marker.context=r.context;marker.recorded_policy_evidence=r.policy;
                marker.retained_orbit_fields=fieldnames(r.orbit);marker.retained_report_fields=fieldnames(r.report);marker.retained_method_fields=fieldnames(r.method);marker.native_id_available=~isempty(r.native_id);
                o.schema_metadata=struct('essential_storage',marker);report.essential_storage=marker;
                if r.policy.complete
                    report.correction_return_policy=struct('diagnostic_kind','runtime-object-descriptor', ...
                        'source_class',r.policy.configuration.source_class,'settings',r.policy.configuration.settings);
                end
                assert(isequal(K.identity(o),r.native_id),'EssentialBranch:NativeID','Reconstruction changed literal identity-bearing values or ID availability.');
                assert(strcmp(K.digest(K.project(o,report,r.metadata,r.context)),K.hex(p.point_digests(:,i))), ...
                    'EssentialBranch:Projection','A selected thin view must reproject to its original retained scientific values.');
                orbits{k}=o;reports{k}=report;metadata{k}=r.metadata;seen(i)=k;
            end
        end

        function [orbit,report,metadata]=loadSolution(file,index)
            [a,b,c]=EssentialBranchSolutionFile_v3.loadSolutions(file,index);
            assert(numel(a)==1,'EssentialBranch:Bounds','loadSolution requires exactly one occurrence.');orbit=a{1};report=b{1};metadata=c{1};
        end

        function r=projection(file,index)
            p=EssentialBranchSolutionFile_v3.read(file);EssentialBranchSolutionFile_v3.indices(index,p.point_count);
            assert(isscalar(index),'EssentialBranch:Bounds','projection requires exactly one occurrence.');r=EssentialBranchSolutionFile_v3.record(p,index);
        end

        function r=project(orbit,report,metadata,context)
            K=EssentialBranchSolutionFile_v3;contract=K.contract();
            assert(isa(orbit,'HybridOrbit_v3')&&isscalar(orbit)&&isstruct(report)&&isscalar(report), ...
                'EssentialBranch:Source','Supply one literal native orbit and one saved scalar report.');
            K.point(metadata,context);c=K.fields();
            assert(isequal(sort(properties(orbit)),sort(c.all_orbit(:))),'EssentialBranch:OrbitFields','An unknown orbit property requires explicit scientific disposition.');
            prior=[];
            if isstruct(orbit.schema_metadata)&&isfield(orbit.schema_metadata,'essential_storage')
                prior=orbit.schema_metadata.essential_storage;
                assert(isfield(report,'essential_storage')&&isequaln(prior,report.essential_storage),'EssentialBranch:Marker','Thin orbit and report markers must agree.');
                assert(strcmp(prior.schema,contract.schema)&&prior.requires_fresh_replay&&~prior.whole_runtime_equality_claimed,'EssentialBranch:Marker','An incompatible thin view cannot be reimported.');
                report=rmfield(report,'essential_storage');
            else
                assert(~isfield(report,'essential_storage'),'EssentialBranch:Marker','A report-only essential marker is unsupported.');
                assert(isempty(orbit.floquet_multiplier)&&isempty(fieldnames(orbit.stability)), ...
                    'EssentialBranch:Stability','Nonempty Floquet/stability results require a separate explicit essential-result contract.');
            end
            % Original optional report/provenance payload is outside this
            % projection and is neither traversed nor copied. Retained fields
            % still have exact declared shape/class checks.
            v=struct();
            for j=1:numel(c.orbit),name=c.orbit{j};v.(name)=orbit.(name);K.value(v.(name),name,4096);end
            for entry={{'initial_state',14},{'initial_mode',4},{'parameter',10},{'stride_displacement',14},{'poincare_state',14}}
                key=entry{1}{1};n=entry{1}{2};a=v.(key);
                assert((isnumeric(a)||islogical(a))&&(isempty(a)||numel(a)==n),'EssentialBranch:CoreShape','%s must preserve its literal numeric/logical empty value or %d entries.',key,n);
            end
            assert((isnumeric(v.period)||islogical(v.period))&&(isempty(v.period)||isscalar(v.period)), ...
                'EssentialBranch:Period','Preserve a literal scalar period or its empty value.');
            v.mode_history=K.modes(orbit.mode_history);v.event_history=K.events(orbit.event_history);v.event_clusters=K.clusters(orbit.event_clusters);
            v.section_chart=K.select(orbit.section_chart,c.section,c.section_omitted,'section_chart',14);
            v.primitive_cycle=K.primitive(orbit.primitive_cycle);v.gait_identification=K.classifier(orbit.gait_identification);
            for name={'topology_margins','minimum_physical_margins','event_cluster_split_merge_diagnostics'},v.(name{1})=K.margins(orbit.(name{1}),name{1});end
            v.initial_section_admissibility=K.admissibility(orbit.initial_section_admissibility);v.section_return_admissibility=K.admissibility(orbit.section_return_admissibility);
            out=K.reportProjection(report);
            method=K.method(report);
            if isempty(prior),[~,policy]=RecordedReturnPolicy_v3(report);else,policy=prior.recorded_policy_evidence;end
            K.policy(policy);
            nativeID=K.identity(orbit);
            if isfield(context,'native_id'),assert(isequal(context.native_id,nativeID),'EssentialBranch:NativeID','The supplied NativeID differs from the literal source.');end
            r=struct('schema',contract.schema,'native_id',nativeID,'orbit',v,'report',out,'method',method,'policy',policy,'metadata',metadata,'context',context);
            K.canonical(r);
        end
    end

    methods (Static, Access=private)
        function out=reportProjection(report)
            K=EssentialBranchSolutionFile_v3;c=K.fields();
            out=K.select(report,c.report,{},'report',14);
            for j=1:numel(c.report_nested)
                key=c.report_nested{j};if ~isfield(report,key),continue;end
                switch key
                    case 'primitive',out.(key)=K.primitive(report.(key));
                    case 'classification',out.(key)=K.classifier(report.(key));
                    case 'acceptance_gates'
                        K.known(report.(key),c.acceptance_gates,'required acceptance gates');
                        out.(key)=K.select(report.(key),c.acceptance_gates,{},key,14);
                    otherwise,out.(key)=K.select(report.(key),c.(key),c.([key '_omitted']),key,14);
                end
            end
        end

        function c=fields()
            c=struct();
            c.all_orbit={'initial_state','initial_mode','period','parameter','event_history','mode_history','poincare_state','floquet_multiplier','stability','trajectory','stride_displacement','return_policy','return_policy_name','return_multiplicity','candidate_section_count','candidate_apex_count','accepted_crossing_index','accepted_apex_index','section_relative_event_signature','cyclic_event_signature','event_cluster_report','event_clusters','event_cluster_count','event_cluster_signature','cyclic_event_cluster_signature','event_cluster_members','event_cluster_names','event_cluster_center_times','maximum_intra_cluster_spread','minimum_intercluster_gap','cluster_relative_phase','section_cluster_coincidence','section_coincident_cluster_indices','event_cluster_split_merge_diagnostics','event_counts','event_counts_per_leg','guard_transversality_margins','minimum_guard_transversality','section_transversality','topology_margins','minimum_stance_admissibility_margin','minimum_physical_margin','minimum_physical_margins','initial_section_admissibility','section_return_admissibility','section_coincident_events','cycle_completion_diagnostics','schema_metadata','section_chart','primitive_cycle','gait_identification'};
            c.orbit={'initial_state','initial_mode','parameter','period','stride_displacement','poincare_state','return_policy','return_policy_name','return_multiplicity','candidate_section_count','candidate_apex_count','accepted_crossing_index','accepted_apex_index','section_relative_event_signature','cyclic_event_signature','event_cluster_count','event_cluster_signature','cyclic_event_cluster_signature','event_cluster_members','event_cluster_names','event_cluster_center_times','maximum_intra_cluster_spread','minimum_intercluster_gap','cluster_relative_phase','section_cluster_coincidence','section_coincident_cluster_indices','minimum_guard_transversality','section_transversality','minimum_stance_admissibility_margin','minimum_physical_margin'};
            c.section={'id','geometry','crossing_orientation','boundary_ownership','translational_gauge','BL_touchdowns_per_return'};
            c.section_omitted={'contact_mode','return_multiplicity','time_translation'};
            c.report={'schema_version','status','native_status','accepted','initial_scaled_norm','initial_physical_norm','final_scaled_norm','final_physical_norm','full_closure','full_closure_residual','constraint_residual','elapsed_seconds','failure_stage','retryable','energy_pivot','active_coordinate_indices','period','drift','event_signature','acquisition_scope','within_original_clock'};
            c.report_nested={'primitive','classification','acceptance_gates','family_conditions','physical_inequalities','independent_replay','primary_failure','finalization_failure','replay_failure'};
            c.report_all=[c.report,c.report_nested,{'seed','options','acceptance','integration','replay_integration','effective_correction_ode','effective_replay_ode','correction_return_policy','initial_residual','final_residual','final_candidate','solver','partial_evidence','provenance','chart','chart_signature','initial_evaluation','final_coordinates','augmented_parameter','chart_signature','continuation_acquisition','delegated_residual_definition','options_residual_runtime_object_omitted','compact_checkpoint','acquisition_deadlines','acquisition_predictor','acquisition_derivative_scope','acquisition_derivative_method','acquisition_relative_step','options_jacobian_runtime_descriptor_saved'}];
            c.acceptance_gates={'full_closure','mode_closure','target_energy','trajectory_energy_variation','unscaled_family_equations','family_constraint','physical_inequalities','primitive_identity','replay_determinism'};c.acceptance_gates_omitted={};
            c.family_conditions={'residual_class','unscaled_family_equations','unscaled_family_norm','unscaled_family_tolerance','unscaled_equations_passed','requested_energy','requested_energy_origin','target_energy_applicable','actual_energy','target_energy_error','target_energy_tolerance','target_energy_passed','constraint_residual','constraint_tolerance','constraint_passed'};c.family_conditions_omitted={'coordinates'};
            c.physical_inequalities={'energy_at_section','maximum_energy_error','maximum_stance_constraint','minimum_physical_margin','sample_count','virtual_same_time_rows_omitted'};c.physical_inequalities_omitted={};
            c.independent_replay={'repeated_replay_difference','residual_norm','discrete_closed'};c.independent_replay_omitted={'raw_state','section_state','next_state','map_info','first_replay_next_state'};
            c.primary_failure={'identifier','message','exitflag'};c.primary_failure_omitted={'stack'};c.finalization_failure=c.primary_failure;c.finalization_failure_omitted={'stack'};c.replay_failure=c.primary_failure;c.replay_failure_omitted={'stack'};
            c.primitive={'status','reason','recorded_period','primitive_period','cover_count','drift','primitive_drift','closure_error','mode_closed','checked_cover_bound','state_tolerance','event_phase_tolerance','evidence_level','global_primitivity_proved','event_history_complete','proper_apex_count'};
            c.primitive_omitted={'candidates','contact_history_audit','proper_apex_replays'};
            c.classifier={'contract_version','synchrony_predicate_version','label','alias','abbreviation','status','reason','validated_gait_type','canonical_point_label','canonical_label_qualified','suspension_reference_posture','primitive_flight_count','flight_count_certain','descriptive_only','isotropy_proved','period_used','flight_count','raw_positive_flight_count','flight_count_over_recorded_period','hind_pair_asymmetry','fore_pair_asymmetry','hind_pair_synchronized','front_pair_synchronized','fore_pair_synchronized','legacy_original_suffix_verified_flight_count','v3_abbreviation_suffix2_measured','displaylabel'};
            c.classifier_omitted={'color','initial_state_pattern','cycle_synchronization','pip_subtype','event_half_shift_exclusion','all_per_flight_postures','historical_labels','ambiguity','primitive','flight_intervals_on_circle','flight_durations','flight_count_sensitivity','contact_reconstruction','duty_factors','contact_time','contact_functions','touchdown_phases','liftoff_phases','event_occurrences','event_clusters','contact_sync_errors','motion_sync_errors','angle_sync_errors','rate_sync_errors','left_right_half_phase_contact_errors','left_right_half_phase_motion_errors','left_right_lead','lead_pair_names','leg_trajectories','suspension_geometry','schema_metadata'};
            c.event={'index','type','time','guard_id','guard_name','mode_before','mode_after','value','directional_derivative','priority','is_stop'};
            c.event_metadata={'leg_index','leg_name','event_kind','source','event_batch_index','event_batch_size','event_batch_position','event_batch_semantics','event_batch_atomic','is_physical','is_arming','diagnostic_only','contact_policy','scheduled'};
            c.cluster={'index','member_indices','sorted_member_indices','names','sorted_names','center_time','maximum_intra_cluster_spread','adaptive_time_tolerance','relative_phase','token','section_coincident','section_indices','section_names','minimum_section_distance'};
        end

        function out=primitive(value)
            K=EssentialBranchSolutionFile_v3;c=K.fields();out=K.select(value,c.primitive,c.primitive_omitted,'primitive',14);
            if isfield(value,'contact_history_audit'),out.contact_history_audit=K.contact(value.contact_history_audit);end
        end

        function out=classifier(value)
            K=EssentialBranchSolutionFile_v3;c=K.fields();
            out=K.select(value,c.classifier,[c.classifier_omitted,{'tolerances','borderline'}],'classification',14);
            if isfield(value,'contact_reconstruction'),out.contact_reconstruction=K.contact(value.contact_reconstruction);end
            % Preserve bounded decision/tolerance scalars, never candidate masks or samples.
            for name={'tolerances','borderline'}
                if isfield(value,name{1})
                    a=value.(name{1});
                    if strcmp(name{1},'borderline'),K.value(a,'classification.borderline',1);out.borderline=a;
                    else
                        out.tolerances=K.select(a,{'ContactTolerance','MotionTolerance','AngleTolerance','RateTolerance','StanceRateTolerance','SyncFlowTolerance','ParameterTolerance','ApexTolerance','EventTimeTolerance','FlightDurationTolerance','ObservationRelTol','ObservationAbsTol','ObservationMaxStep','ObservationSafetyFactor','GeometryTolerance','SampleCount'}, {'PrimitiveOptions'},'classification.tolerances',14);
                        if isfield(a,'PrimitiveOptions'),out.tolerances.PrimitiveOptions=K.flat(a.PrimitiveOptions,'PrimitiveOptions',16,14);end
                    end
                end
            end
        end

        function out=contact(value)
            K=EssentialBranchSolutionFile_v3;
            keep={'complete','reason','initial_mode','final_mode','cohorts','event_time_tolerance','atomic_cohorts'};
            out=K.select(value,keep,{'events','knots','modes','saved_mode_mismatch'},'saved contact/cohort decision',4096);
            % Cohort indices remain in the saved physicalEvents domain. No
            % cohort or event-index correspondence is reconstructed here.
        end

        function out=margins(value,kind)
            K=EssentialBranchSolutionFile_v3;
            switch kind
                case 'topology_margins',keep={'guard_transversality','section_transversality','event_time_separation','minimum_intercluster_gap','maximum_intra_cluster_spread','section_event_separation','section_cluster_separation','stance_force','stance_force_admissibility','physical','swing_foot_clearance','stance_compression','leg_length','hip_clearance','torso_clearance','contact_complementarity','section_event_coincidence_count','section_cluster_coincidence_count'};
                case 'minimum_physical_margins',keep={'global','swing_foot_clearance','stance_compression','leg_length','hip_clearance','torso_clearance','complementarity_margin','per_leg'};
                otherwise,keep={'reference_supplied','left_cluster_signature','right_cluster_signature','left_cyclic_cluster_signature','right_cyclic_cluster_signature','has_persistent_simultaneous_cluster','has_split','has_merge','has_collision','minimum_intercluster_gap_left','minimum_intercluster_gap_right','cluster_signature_changed','compatible'};
                    % persistent_simultaneous_clusters/event_cluster_splits/
                    % event_cluster_merges diagnosis arrays are not retained.
            end
            extra={};if strcmp(kind,'minimum_physical_margins'),extra={'active_tolerances'};end
            out=K.select(value,keep,extra,kind,14);
            if isfield(value,'active_tolerances'),out.active_tolerances=K.flat(value.active_tolerances,'physical tolerances',16,14);end
        end

        function out=admissibility(value)
            K=EssentialBranchSolutionFile_v3;
            keep={'context','mode','global_validity','strict_global_validity','minimum_physical_margin','admissible','minimum_stance_admissibility_margin','minimum_swing_foot_clearance','minimum_swing_foot_margin','minimum_stance_compression','minimum_stance_compression_margin','minimum_leg_length','minimum_leg_length_margin','minimum_complementarity_margin','minimum_hip_clearance','minimum_hip_clearance_margin','torso_clearance','torso_clearance_margin','per_leg_validity','per_leg_minimum_physical_margin','post_reset_consistency_evaluated','post_reset_guard_consistent','post_reset_mode_consistent'};
            omitted={'context_policy','absolute_leg_angles','hip_heights','hip_clearances','hip_clearance_margins','torso_endpoint_heights','swing_foot_clearances','swing_foot_margins','leg_lengths','stance_leg_lengths','stance_compressions','stance_compression_margins','leg_length_margins','complementarity_residuals','complementarity_margins','downward_orientation_margins','finite_geometry_per_leg','per_leg_failure_reasons','failure_reasons','post_reset_guard_residuals','admissibility_margins','stance_admissibility_margins','invalid_stance_legs','invalid_swing_legs','active_tolerances','active_checks'};
            out=K.select(value,keep,omitted,'one-state physical witnesses',14);
            for name={'active_tolerances','active_checks','context_policy'},if isfield(value,name{1}),out.(name{1})=K.flat(value.(name{1}),name{1},16,14);end,end
        end

        function out=method(report)
            K=EssentialBranchSolutionFile_v3;out=struct();
            if isfield(report,'acceptance'),out.acceptance=K.flat(report.acceptance,'acceptance',16,14);end
            for name={'effective_correction_ode','effective_replay_ode'}
                if isfield(report,name{1}),out.(name{1})=K.select(report.(name{1}),{'RelTol','AbsTol','MaxStep','ODESolver','configured_minimum_RelTol','RelTol_lower_bound'},{},name{1},14);end
            end
            for name={'integration','replay_integration'}
                if ~isfield(report,name{1}),continue;end
                in=report.(name{1});
                keep={'ProcessGuardsAtStop','RecordStopEvent','FailurePolicy','MaxEvents','MaxEventBatches','MaxZeroTimeEvents','RelTol','AbsTol','MaxStep','EventValueTolerance','EventTimeTolerance','SimultaneousTimeTolerance','DirectionalDerivativeTolerance','DerivativeStep','ArmingTolerance','InteriorBias','MaxWallSeconds'};
                out.(name{1})=K.select(in,keep,{'StopCondition','ODEOptions','ODESolver','OutputFcn'},name{1},14);
                if isfield(in,'ODESolver'),out.(name{1}).ODESolver=K.callableName(in.ODESolver);end
                if isfield(in,'ODEOptions'),out.(name{1}).ODEOptions=K.odeOptions(in.ODEOptions);end
            end
            if isfield(report,'options')
                in=report.options;keep={'Energy','Symmetry','ActiveCoordinateIndices','FamilyConstraint','ResidualScale','CoordinateScale','MaxReturnTime','MaxCycleEvents','MaxSectionCrossings','MaxWallSeconds'};
                out.options=K.select(in,keep,{'Constraint','Integration','ReplayIntegration','SolverOptions','Acceptance','Residual','Coordinates','AugmentedParameter'},'options',14);
                if isfield(in,'SolverOptions')
                    so=in.SolverOptions;keep={'Algorithm','MaxIterations','MaxFunctionEvaluations','FunctionTolerance','ResidualAcceptanceTolerance','StepTolerance','OptimalityTolerance','InitialDamping','ReuseJacobian','UseBroyden','JacobianRefreshInterval','MaxWallSeconds','RootNewtonMinimumRcond','RootNewtonLinearSolveTolerance','StateScale','ParameterScale','InvalidTrialPolicy'};
                    out.options.SolverOptions=K.select(so,keep,{'InitialJacobian','Jacobian'},'SolverOptions',14);
                    if isfield(so,'Jacobian'),out.options.SolverOptions.Jacobian=K.derivative(so.Jacobian);end
                end
            end
        end

        function out=odeOptions(value)
            K=EssentialBranchSolutionFile_v3;
            keep={'AbsTol','RelTol','NormControl','NonNegative','OutputSel','Refine','Stats','InitialStep','MaxStep','JPattern','Vectorized','MassSingular','MStateDependence','MvPattern','InitialSlope','MaxOrder','BDF'};
            callbacks={'OutputFcn','Events','Jacobian','Mass'};
            out=K.select(value,keep,callbacks,'ODEOptions',196);
            for name=callbacks
                if ~isfield(value,name{1}),continue;end
                a=value.(name{1});if isempty(a)||isnumeric(a)||islogical(a),K.value(a,['ODEOptions.' name{1}],196);out.(name{1})=a;else,out.(name{1})=K.callableName(a);end
            end
        end

        function out=derivative(value)
            K=EssentialBranchSolutionFile_v3;
            if isempty(value),out=value;return;end
            if isobject(value),source=class(value);settings=struct();for name=properties(value).',settings.(name{1})=value.(name{1});end
            else
                K.exact(value,{'diagnostic_kind','source_class','settings'},'derivative descriptor');
                assert(any(strcmp(value.diagnostic_kind,{'runtime-object-descriptor','essential-method-descriptor'})),'EssentialBranch:Derivative','Unknown derivative descriptor disposition.');source=char(value.source_class);settings=value.settings;
            end
            assert(any(strcmp(source,{'FiniteDifferenceJacobian_v3','ValidSidedFiniteDifferenceJacobian_v3'})), ...
                'EssentialBranch:Derivative','Unknown derivative semantics require explicit method disposition.');
            out=struct('diagnostic_kind','essential-method-descriptor','source_class',source,'settings',K.flat(settings,'derivative settings',24,14));
        end

        function out=callableName(value)
            if isa(value,'function_handle'),out=struct('source_class','function_handle','name',func2str(value),'closure_available',false);
            elseif ischar(value)||isstring(value),out=value;
            elseif isstruct(value)
                K=EssentialBranchSolutionFile_v3;
                if isfield(value,'diagnostic_kind')
                    K.exact(value,{'diagnostic_kind','signature','requires_runtime_reconstruction'},'saved function descriptor');
                    assert(strcmp(value.diagnostic_kind,'runtime-function-descriptor')&&isequal(value.requires_runtime_reconstruction,true),'EssentialBranch:Callback','Unknown saved function descriptor.');K.text(value.signature,'saved callback signature');
                    out=struct('source_class','function_handle','name',value.signature,'closure_available',false);
                else
                    K.exact(value,{'source_class','name','closure_available'},'solver function descriptor');
                    assert(strcmp(value.source_class,'function_handle')&&isequal(value.closure_available,false),'EssentialBranch:Callback','Only a literal function-name descriptor without captured workspace is supported.');K.text(value.name,'callback name');out=value;
                end
            else,error('EssentialBranch:Callback','Only an explicit solver function name/descriptor is retained.');end
        end

        function policy(value)
            K=EssentialBranchSolutionFile_v3;
            K.known(value,{'complete','source_path','configuration','reason','failure'},'recorded policy evidence');
            assert(isfield(value,'complete')&&islogical(value.complete)&&isscalar(value.complete),'EssentialBranch:Policy','Policy completeness must be literal logical scalar evidence.');
            if value.complete
                K.exact(value.configuration,{'source_class','settings'},'policy configuration');
                source=char(value.configuration.source_class);
                switch source
                    case 'BLMarkedApexReturnPolicy_v3',fields={'Name','BLTouchdownsPerReturn','RequireModeClosure','LookaheadMaxTime','LookaheadMaxEvents','TimeTolerance'};
                    case 'EventCycleReturnPolicy_v3',fields={'Name','LegCount','LegNames','RequireModeClosure','EventClassifier'};
                    case 'IteratedReturnPolicy_v3',fields={'Name','Multiplicity'};
                    case 'FirstReturnPolicy_v3',fields={'Name'};
                    otherwise,error('EssentialBranch:Policy','Unknown complete policy configuration.');
                end
                K.exact(value.configuration.settings,fields,'policy settings');
            end
            K.plain(value,0,256);
        end

        function out=events(value)
            K=EssentialBranchSolutionFile_v3;c=K.fields();
            assert(isstruct(value),'EssentialBranch:Events','Saved event history must remain a literal struct array.');out=value;
            discarded=setdiff(fieldnames(value),[c.event,{'metadata'}]);if ~isempty(discarded),out=rmfield(out,discarded);end
            % touchdown_diagnostics and event-state tapes are optional
            % source diagnostics, not retained essential event metadata.
            for k=1:numel(out)
                for name=c.event,if isfield(out,name{1}),K.value(out(k).(name{1}),['event.' name{1}],14);end,end
                if isfield(out,'metadata'),out(k).metadata=K.select(out(k).metadata,c.event_metadata,{},'event.metadata',14);end
            end
        end

        function out=clusters(value)
            K=EssentialBranchSolutionFile_v3;c=K.fields();assert(isstruct(value),'EssentialBranch:Clusters','Saved clusters must be a literal struct array.');out=value;
            discarded=setdiff(fieldnames(value),c.cluster);if ~isempty(discarded),out=rmfield(out,discarded);end
            for k=1:numel(out),for name=c.cluster,if isfield(out,name{1}),K.value(out(k).(name{1}),['cluster.' name{1}],4096);end,end,end
        end

        function value=modes(value)
            K=EssentialBranchSolutionFile_v3;
            assert(iscell(value)||isnumeric(value)||islogical(value),'EssentialBranch:Modes','Mode history must preserve its native cell/numeric/logical representation.');
            if iscell(value),for k=1:numel(value),a=value{k};assert((isnumeric(a)||islogical(a))&&(isempty(a)||numel(a)==4),'EssentialBranch:Modes','Every saved mode entry must remain empty or four-dimensional.');end
            else,assert(isempty(value)||mod(numel(value),4)==0,'EssentialBranch:Modes','Numeric mode history must contain whole four-leg modes.');end
            K.value(value,'mode_history',65536);
        end

        function out=select(value,keep,omitted,label,bound)
            K=EssentialBranchSolutionFile_v3; %#ok<NASGU> omitted documents known discarded producer fields.
            assert(isstruct(value)&&isscalar(value),'EssentialBranch:ScalarRecord','%s must be one scalar source record.',label);out=struct();
            % Select only named essential fields. Do not inspect optional
            % unselected values; canonical persisted records are separately
            % checked against this exact projection and may not hide extras.
            for name=fieldnames(value).',if any(strcmp(name{1},keep)),out.(name{1})=value.(name{1});K.value(out.(name{1}),[label '.' name{1}],bound);end,end
        end

        function out=flat(value,label,fieldBound,valueBound)
            K=EssentialBranchSolutionFile_v3;assert(isstruct(value)&&isscalar(value)&&numel(fieldnames(value))<=fieldBound, ...
                'EssentialBranch:BoundedEvidence','%s must be a bounded scalar evidence/configuration struct.',label);out=value;
            for name=fieldnames(value).',K.value(value.(name{1}),[label '.' name{1}],valueBound);end
        end

        function point(m,c)
            K=EssentialBranchSolutionFile_v3;
            K.known(m,{'component_identity','order','classification','nativeE','signedmeanU','edge_enabled','edge_from'},'essential point metadata');
            assert(all(isfield(m,{'component_identity','order'})),'EssentialBranch:Owner','Point owner and order must be supplied explicitly.');K.text(m.component_identity,'owner');K.integer(m.order,1);
            K.known(c,{'role','occurrence_id','source_reference','source_index','expected_index','native_id','physical_edge_provenance'},'context');
            assert(all(isfield(c,{'role','occurrence_id','source_reference','source_index','expected_index'})),'EssentialBranch:Context','Role, occurrence, historical source/index and expected index are required.');
            contract=K.contract();K.text(c.role,'role');assert(any(strcmp(c.role,contract.roles)),'EssentialBranch:Role','Use one of the five declared source-backed roles.');
            K.text(c.occurrence_id,'occurrence');K.reference(c.source_reference,true);K.integer(c.source_index,1);K.integer(c.expected_index,1);
            if isfield(c,'native_id')&&~isempty(c.native_id),K.nativeID(c.native_id);end
            if isfield(m,'edge_enabled'),assert(islogical(m.edge_enabled)&&isscalar(m.edge_enabled),'EssentialBranch:Edge','edge_enabled is literal logical evidence.');end
            enabled=isfield(m,'edge_enabled')&&isequal(m.edge_enabled,true);hasFrom=isfield(m,'edge_from')&&~isempty(m.edge_from);
            assert(enabled==hasFrom,'EssentialBranch:Edge','A physical edge requires both literal enabled=true and an explicit predecessor.');
            if hasFrom,K.integer(m.edge_from,1);assert(m.edge_from<c.expected_index,'EssentialBranch:Edge','Physical predecessors must be earlier occurrences.');end
            if any(strcmp(c.role,{'nonedge-control','isolated','rejected'})),assert(~enabled,'EssentialBranch:Role','Control, isolated and rejected records cannot acquire physical edges.');end
            for name=fieldnames(m).',K.value(m.(name{1}),['point.' name{1}],14);end
            if isfield(c,'physical_edge_provenance'),K.edgeProvenance(c.physical_edge_provenance,hasFrom,m,c.expected_index);end
        end

        function edgeProvenance(p,enabled,m,target)
            K=EssentialBranchSolutionFile_v3;
            keep={'kind','source_reference','source_from','source_to','receipt_reference','receipt_availability','pending_admission_id','method_reference','facts'};
            K.known(p,keep,'physical edge provenance');assert(all(isfield(p,{'kind','source_reference','source_from','source_to','receipt_reference','receipt_availability'})), ...
                'EssentialBranch:EdgeProvenance','Explicit physical-edge source and receipt disposition are required.');
            K.reference(p.source_reference,true);K.integer(p.source_from,1);K.integer(p.source_to,1);K.text(p.receipt_availability,'receipt availability');
            assert(enabled,'EssentialBranch:EdgeProvenance','Physical-edge provenance cannot silently create an edge.');
            if strcmp(p.kind,'new_native_corrector')
                assert(all(isfield(p,{'pending_admission_id','method_reference','facts'}))&&p.source_from==m.edge_from&&p.source_to==target, ...
                    'EssentialBranch:EdgeProvenance','A new corrector edge must bind its persisted pending ID and literal source/target.');
                K.text(p.pending_admission_id,'pending admission ID');K.reference(p.method_reference,true);K.flat(p.facts,'native edge facts',32,14);
            else,assert(strcmp(p.kind,'historical_physical_edge'),'EssentialBranch:EdgeProvenance','Unknown physical-edge provenance kind.');end
            if strcmp(p.receipt_availability,'not_yet_published'),assert(isempty(p.receipt_reference),'EssentialBranch:FutureReceipt','An unpublished receipt cannot have an invented reference.');
            else,assert(any(strcmp(p.receipt_availability,{'historical_locator','current'})),'EssentialBranch:Receipt','Declare the receipt availability explicitly.');K.reference(p.receipt_reference,true);end
        end

        function graph(m,records)
            K=EssentialBranchSolutionFile_v3;
            K.exact(m,{'schema','role','displayname','physical_edges','record_equalities','qualified_aliases','numerical_seams','source_versions'},'essential branch metadata');
            assert(strcmp(m.schema,'C1-essential-branch-graph-v1'),'EssentialBranch:GraphSchema','Use the explicit essential branch graph schema.');K.text(m.role,'branch role');K.text(m.displayname,'display name');
            assert(iscell(m.source_versions)&&iscolumn(m.source_versions)&&numel(m.source_versions)<=128,'EssentialBranch:Sources','Source versions must be an explicit bounded column of references.');
            for k=1:numel(m.source_versions),K.reference(m.source_versions{k},true);end
            n=numel(records);ids=cell(n,1);owners=cell(n,1);orders=zeros(n,1);
            for k=1:n
                r=records{k};K.canonical(r);assert(r.context.expected_index==k,'EssentialBranch:ExpectedOrder','Expected occurrence indices must match stored order.');
                ids{k}=r.context.occurrence_id;owners{k}=char(r.metadata.component_identity);orders(k)=double(r.metadata.order);
                prior=find(strcmp(owners(1:k-1),owners{k}),1,'last');if ~isempty(prior),assert(orders(k)>orders(prior),'EssentialBranch:OwnerOrder','Within-owner order must strictly increase.');end
            end
            assert(numel(unique(ids))==n,'EssentialBranch:Occurrence','Occurrence identities must be unique; NativeIDs may repeat.');incoming=zeros(n,1);
            K.columnCells(m.physical_edges,'physical edges');
            for k=1:numel(m.physical_edges)
                e=m.physical_edges{k};K.exact(e,{'from','to','component_identity','provenance'},'physical edge');K.pair(e,n);
                assert(~isempty(records{e.from}.native_id)&&~isempty(records{e.to}.native_id),'EssentialBranch:EdgeIdentity','A physical edge requires literal complete endpoint identity values.');
                assert(e.from<e.to&&strcmp(owners{e.from},owners{e.to})&&strcmp(e.component_identity,owners{e.to}), ...
                    'EssentialBranch:PhysicalOwner','An actual physical edge must retain earlier source and equal literal owner.');
                incoming(e.to)=incoming(e.to)+1;assert(incoming(e.to)==1,'EssentialBranch:IncomingEdge','Physical incoming edge must be unique per occurrence.');
                target=records{e.to};assert(isfield(target.metadata,'edge_enabled')&&isequal(target.metadata.edge_enabled,true)&&isequal(target.metadata.edge_from,e.from), ...
                    'EssentialBranch:PointEdge','Caller graph and explicit point predecessor must agree.');
                K.edgeProvenance(e.provenance,true,target.metadata,e.to);
            end
            for k=1:n,enabled=isfield(records{k}.metadata,'edge_enabled')&&isequal(records{k}.metadata.edge_enabled,true);assert(enabled==(incoming(k)==1),'EssentialBranch:PointEdge','No enabled point edge may be omitted from the graph.');end
            for name={'record_equalities','qualified_aliases','numerical_seams'}
                rows=m.(name{1});K.columnCells(rows,name{1});
                for k=1:numel(rows)
                    e=rows{k};K.exact(e,{'from','to','from_native_id','to_native_id','receipt_reference','evidence'},name{1});K.pair(e,n);K.reference(e.receipt_reference,true);
                    K.nativeID(records{e.from}.native_id);K.nativeID(records{e.to}.native_id);K.nativeID(e.from_native_id);K.nativeID(e.to_native_id);
                    assert(strcmp(e.from_native_id,records{e.from}.native_id)&&strcmp(e.to_native_id,records{e.to}.native_id),'EssentialBranch:GraphNativeID','A relation must bind both actual endpoint NativeIDs.');
                    K.exact(e.evidence,{'schema','scalars','original_fines'},'bounded relation evidence');K.text(e.evidence.schema,'evidence schema');K.flat(e.evidence.scalars,'relation scalar evidence',64,14);K.fines(e.evidence.original_fines);
                    if strcmp(name{1},'numerical_seams')
                        s=e.evidence.scalars;assert(all(isfield(s,{'earned_parent_native_id','actual_new_points','actual_new_edges'}))&&isequal(s.actual_new_points,1)&&isequal(s.actual_new_edges,1), ...
                            'EssentialBranch:EarnedSeam','A numerical seam must retain the one-point/one-edge earned-parent witness.');K.nativeID(s.earned_parent_native_id);
                        edges=m.physical_edges;parent=[];for j=1:numel(edges),if edges{j}.to==e.from,parent=edges{j}.from;end,end
                        assert(~isempty(parent)&&strcmp(records{parent}.native_id,s.earned_parent_native_id),'EssentialBranch:EarnedParent','The left seam endpoint must retain its unique actual incoming parent edge.');
                    end
                end
            end
        end

        function fines(value)
            K=EssentialBranchSolutionFile_v3;K.columnCells(value,'historical original fines');assert(numel(value)<=4,'EssentialBranch:Fines','Retain at most four explicit bounded original fine witnesses.');
            fields={'source_reference','MaxStep','full_closure','closure_tolerance','period_scaled_error','period_tolerance','stride_scaled_error','stride_tolerance','primitive','all_nine','current_PK','section_matches','invoked','returned','return_timely','storage_completed','storage_timely','readback_completed','readback_timely','passed'};
            for k=1:numel(value),K.known(value{k},fields,'fine witness');for name=fieldnames(value{k}).',if strcmp(name{1},'source_reference'),K.reference(value{k}.source_reference,true);else,K.value(value{k}.(name{1}),['fine.' name{1}],14);end,end,end
        end

        function p=pack(metadata,records)
            K=EssentialBranchSolutionFile_v3;n=numel(records);assert(n<=double(intmax('uint32')),'EssentialBranch:Count','Occurrence count exceeds the explicit uint32 table contract.');table=K.emptyTable();events=K.emptyTable();clusters=K.emptyTable();
            dictionaries=struct('policy',{cell(0,1)},'section',{cell(0,1)},'method',{cell(0,1)});dictionaryIDs=zeros(n,3,'uint32');
            keys={containers.Map('KeyType','char','ValueType','double'),containers.Map('KeyType','char','ValueType','double'),containers.Map('KeyType','char','ValueType','double')};
            eventRanges=zeros(n,2,'uint32');clusterRanges=eventRanges;eventShapes=cell(n,1);clusterShapes=eventShapes;digests=zeros(32,n,'uint8');hints=nan(n,4);
            for k=1:n
                r=records{k};digests(:,k)=K.hexBytes(K.digest(r));values={r.policy,r.orbit.section_chart,r.method};names={'policy','section','method'};
                for j=1:3
                    key=K.digest(values{j});if isKey(keys{j},key),id=keys{j}(key);else,id=numel(dictionaries.(names{j}))+1;dictionaries.(names{j}){id,1}=values{j};keys{j}(key)=id;end
                    dictionaryIDs(k,j)=uint32(id);
                end
                ev=r.orbit.event_history;cl=r.orbit.event_clusters;eventShapes{k}=struct('size',size(ev),'fields',{fieldnames(ev)});clusterShapes{k}=struct('size',size(cl),'fields',{fieldnames(cl)});
                eventRanges(k,:)=[uint32(events.rows+1),uint32(numel(ev))];clusterRanges(k,:)=[uint32(clusters.rows+1),uint32(numel(cl))];
                for j=1:numel(ev),events=K.addRow(events,ev(j));end
                for j=1:numel(cl),clusters=K.addRow(clusters,cl(j));end
                r.orbit=rmfield(r.orbit,{'event_history','event_clusters','section_chart'});r=rmfield(r,{'policy','method'});table=K.addRow(table,r);
                hints(k,:)=[K.hint(records{k}.metadata,'nativeE'),K.hint(records{k}.metadata,'signedmeanU'),K.elementHint(records{k}.orbit.initial_state,2),K.hint(records{k}.orbit,'period')];
            end
            c=K.contract();p=struct('storage_version',c.storage_version,'contract',c.schema,'point_count',n,'metadata',metadata, ...
                'point_table',table,'event_table',events,'cluster_table',clusters,'dictionaries',dictionaries,'dictionary_ids',dictionaryIDs, ...
                'event_ranges',eventRanges,'event_shapes',{eventShapes},'cluster_ranges',clusterRanges,'cluster_shapes',{clusterShapes}, ...
                'point_digests',digests,'numeric_index',hints);
        end

        function r=record(p,index)
            K=EssentialBranchSolutionFile_v3;r=K.row(p.point_table,index);
            names={'policy','section','method'};values=cell(1,3);for j=1:3,values{j}=p.dictionaries.(names{j}){p.dictionary_ids(index,j)};end
            r.policy=values{1};r.orbit.section_chart=values{2};r.method=values{3};
            r.orbit.event_history=K.ragged(p.event_table,p.event_ranges(index,:),p.event_shapes{index});
            r.orbit.event_clusters=K.ragged(p.cluster_table,p.cluster_ranges(index,:),p.cluster_shapes{index});
            % Restore canonical field order, independently of table assembly order.
            r=orderfields(r,{'schema','native_id','orbit','report','method','policy','metadata','context'});
            c=K.fields();r.orbit=orderfields(r.orbit,[c.orbit,{'mode_history','event_history','event_clusters','section_chart','primitive_cycle','gait_identification','topology_margins','minimum_physical_margins','event_cluster_split_merge_diagnostics','initial_section_admissibility','section_return_admissibility'}]);
            K.canonical(r);assert(strcmp(K.digest(r),K.hex(p.point_digests(:,index))),'EssentialBranch:ProjectionDigest','Stored selected projection class/shape/raw-bit digest mismatch.');
        end

        function value=ragged(table,range,shape)
            K=EssentialBranchSolutionFile_v3;
            if range(2)==0
                value=struct();for j=1:numel(shape.fields),value.(shape.fields{j})=[];end
                value=repmat(value,shape.size);return
            end
            cells=cell(double(range(2)),1);for k=1:numel(cells),cells{k}=K.row(table,double(range(1))+k-1);end
            value=reshape(vertcat(cells{:}),shape.size);assert(isequal(fieldnames(value),shape.fields),'EssentialBranch:RaggedFields','Ragged record fields/order must match its original array descriptor.');
        end

        function t=emptyTable()
            t=struct('rows',0,'paths',{cell(0,1)},'columns',{cell(0,1)},'layouts',{cell(0,1)},'row_layout',zeros(0,1,'uint32'));
        end

        function t=addRow(t,value)
            K=EssentialBranchSolutionFile_v3;[paths,values,layout]=K.flatten(value,'');row=t.rows+1;
            id=[];for j=1:numel(t.layouts),if isequal(t.layouts{j},layout),id=j;break;end,end
            if isempty(id),id=numel(t.layouts)+1;t.layouts{id,1}=layout;end
            t.row_layout(row,1)=uint32(id);
            for j=1:numel(t.columns),t.columns{j}.group(row,1)=uint16(0);t.columns{j}.entry(row,1)=uint32(0);end
            for j=1:numel(paths)
                column=find(strcmp(t.paths,paths{j}),1);
                if isempty(column),column=numel(t.paths)+1;t.paths{column,1}=paths{j};t.columns{column,1}=struct('group',zeros(row,1,'uint16'),'entry',zeros(row,1,'uint32'),'groups',{cell(0,1)});end
                a=values{j};col=t.columns{column};g=[];
                for q=1:numel(col.groups),old=col.groups{q};if strcmp(old.class,class(a))&&isequal(old.shape,size(a))&&old.is_real==K.realness(a),g=q;break;end,end
                if isempty(g),g=numel(col.groups)+1;col.groups{g,1}=struct('class',class(a),'shape',size(a),'is_real',K.realness(a),'values',{reshape(a,[],1)});entry=1;
                else,entry=size(col.groups{g}.values,2)+1;col.groups{g}.values=[col.groups{g}.values,reshape(a,[],1)];end
                assert(g<=double(intmax('uint16'))&&entry<=double(intmax('uint32')),'EssentialBranch:ColumnCapacity','Typed table group/entry capacity is exceeded.');col.group(row)=uint16(g);col.entry(row)=uint32(entry);t.columns{column}=col;
            end
            t.rows=row;
        end

        function [paths,values,layout]=flatten(value,prefix)
            K=EssentialBranchSolutionFile_v3;paths=cell(0,1);values=cell(0,1);layout=cell(0,2);
            assert(isstruct(value)&&isscalar(value),'EssentialBranch:Table','Only closed canonical scalar records enter typed column tables.');
            for name=fieldnames(value).'
                if isempty(prefix),path=name{1};else,path=[prefix '.' name{1}];end
                a=value.(name{1});
                if isstruct(a)
                    assert(isscalar(a),'EssentialBranch:Table','Ragged structs belong in the explicit event/cluster tables.');layout(end+1,:)={path,true};
                    [x,y,z]=K.flatten(a,path);paths=[paths;x];values=[values;y];layout=[layout;z];
                else,layout(end+1,:)={path,false};paths{end+1,1}=path;values{end+1,1}=a;end
            end
        end

        function value=row(t,index)
            K=EssentialBranchSolutionFile_v3;layout=t.layouts{t.row_layout(index)};value=struct();
            for j=1:size(layout,1)
                path=layout{j,1};
                if layout{j,2},a=struct();else
                    column=find(strcmp(t.paths,path),1);col=t.columns{column};g=col.groups{col.group(index)};
                    if isnumeric(g.values)&&~g.is_real
                        realValues=real(g.values);imaginaryValues=imag(g.values);
                        realColumn=reshape(realValues(:,col.entry(index)),g.shape);
                        imaginaryColumn=reshape(imaginaryValues(:,col.entry(index)),g.shape);
                        a=complex(realColumn,imaginaryColumn);
                    else,a=reshape(g.values(:,col.entry(index)),g.shape);end
                end
                parts=strsplit(path,'.');value=K.put(value,parts,a);
            end
        end

        function out=put(out,parts,value)
            if numel(parts)==1,out.(parts{1})=value;else
                if ~isfield(out,parts{1}),out.(parts{1})=struct();end
                out.(parts{1})=EssentialBranchSolutionFile_v3.put(out.(parts{1}),parts(2:end),value);
            end
        end

        function p=read(file)
            K=EssentialBranchSolutionFile_v3;K.requireV7(file);vars=whos('-file',file);
            assert(isequal(sort({vars.name}),{'branch_index','essential_branch'}),'EssentialBranch:Variables','Schema4 contains only its discovery marker and essential table.');
            limits=K.wireLimits();discovery=vars(strcmp({vars.name},'branch_index'));
            assert(strcmp(discovery.class,'struct')&&isequal(discovery.size,[1,1])&&discovery.bytes<=limits.discovery_bytes, ...
                'EssentialBranch:WireDiscovery','Inspect the fixed small scalar-struct discovery marker before loading either variable.');
            stored=vars(strcmp({vars.name},'essential_branch'));
            if strcmp(stored.class,'uint8')
                assert(numel(stored.size)==2&&stored.size(2)==1&&stored.size(1)<=limits.wire_bytes&&stored.bytes==stored.size(1), ...
                    'EssentialBranch:WireBounds','Inspect the declared bounded uint8 column before loading its wire payload.');
            else
                assert(strcmp(stored.class,'struct')&&isequal(stored.size,[1,1]), ...
                    'EssentialBranch:WireClass','Only the explicit wire column or a legacy scalar plain table is supported.');
            end
            data=load(file,'branch_index','essential_branch');
            if isa(data.essential_branch,'uint8'),p=K.wireDecode(data.essential_branch);else,p=data.essential_branch;end;c=K.contract();
            K.exact(p,{'storage_version','contract','point_count','metadata','point_table','event_table','cluster_table','dictionaries','dictionary_ids','event_ranges','event_shapes','cluster_ranges','cluster_shapes','point_digests','numeric_index'},'persistent table');
            assert(strcmp(p.storage_version,c.storage_version)&&strcmp(p.contract,c.schema),'EssentialBranch:Schema','Explicit schema4 and essential contract must agree.');K.integer(p.point_count,0);n=p.point_count;
            expected=struct('storage_version',c.storage_version,'scientific_projection_contract',c.schema,'point_count',n);
            assert(isequal(data.branch_index,expected),'EssentialBranch:Discovery','Physical discovery marker must agree exactly with the table.');
            K.validateTable(p.point_table);K.validateTable(p.event_table);K.validateTable(p.cluster_table);assert(p.point_table.rows==n,'EssentialBranch:Rows','Point count must match actual table rows.');
            K.exact(p.dictionaries,{'policy','section','method'},'dictionaries');assert(isa(p.dictionary_ids,'uint32')&&isequal(size(p.dictionary_ids),[n,3]),'EssentialBranch:Dictionary','Dictionary references must be a native uint32 N-by-3 table.');
            names={'policy','section','method'};
            for j=1:3
                dict=p.dictionaries.(names{j});K.columnCells(dict,'dictionary');
                assert(all(p.dictionary_ids(:,j)>=1&double(p.dictionary_ids(:,j))<=numel(dict)),'EssentialBranch:Dictionary','Dictionary references are out of bounds.');
                assert(isequal(unique(double(p.dictionary_ids(:,j))),(1:numel(dict)).'),'EssentialBranch:UnusedDictionary','Every shared configuration dictionary row must be used.');
                for k=1:numel(dict),K.plain(dict{k},0,4096);end
            end
            K.ranges(p.event_ranges,p.event_shapes,n,p.event_table.rows);K.ranges(p.cluster_ranges,p.cluster_shapes,n,p.cluster_table.rows);
            assert(isa(p.point_digests,'uint8')&&isequal(size(p.point_digests),[32,n]),'EssentialBranch:Digest','One exact 32-byte scientific digest is required per occurrence.');
            assert(isa(p.numeric_index,'double')&&isreal(p.numeric_index)&&isequal(size(p.numeric_index),[n,4]),'EssentialBranch:NumericIndex','Search hints must be an N-by-4 double table.');
            % Full graph semantics are checked against selected literal projections.
            records=cell(n,1);for k=1:n
                records{k}=K.record(p,k);r=records{k};hints=[K.hint(r.metadata,'nativeE'),K.hint(r.metadata,'signedmeanU'),K.elementHint(r.orbit.initial_state,2),K.hint(r.orbit,'period')];
                assert(isequaln(hints,p.numeric_index(k,:)),'EssentialBranch:SearchHints','Derived numeric hints must agree with exact retained source values.');
            end
            K.graph(p.metadata,records);
        end

        function limits=wireLimits()
            % Refusal bounds, not an operating-system peak-memory guarantee.
            limits=struct('wire_bytes',256*1024^2,'discovery_bytes',16*1024,'allocation_charge',512*1024^2, ...
                'nodes',1000000,'container_slots',1000000,'dimension_product',1000000, ...
                'depth',128,'dimensions',128,'fields',4096,'minimum_node_bytes',26);
        end

        function bytes=wireRaw(value,bigEndian)
            assert(isnumeric(value)&&isreal(value)&&~issparse(value), ...
                'EssentialBranch:WireClass','Raw wire planes must be real dense numeric values.');
            if bigEndian&&~ismember(class(value),{'int8','uint8'}),value=swapbytes(value);end
            bytes=reshape(typecast(value(:),'uint8'),[],1);
        end

        function bytes=wireEncode(original)
            % C1ESSWIRE v1: bytes 1:9 magic, 10 version, 11:18 LE u64 body
            % length; root tag is byte 19, flags byte 20, dimension count
            % bytes 21:28, followed by that many LE u64 dimensions.
            % Node tags: 1 double, 2 single, 3 int8, 4 uint8, 5 int16,
            % 6 uint16, 7 int32, 8 uint32, 9 int64, 10 uint64, 11 logical,
            % 12 UTF16 char, 13 missing-aware UTF16 string, 14 cell, 15 struct.
            % All nodes have tag/flags/u64 dimension-count/u64 dimensions.
            % Numeric flag 1 means separate real then imaginary raw planes;
            % flag 0 means real. Other flags are reserved and must be zero.
            % Strings store one 0/1 missing flag per column-major element;
            % nonmissing elements then store u64 UTF16 length and raw units.
            % Structs store u64 field count, ordered counted UTF16 field names,
            % then child nodes in element-major, field-order sequence.
            K=EssentialBranchSolutionFile_v3;wireL=K.wireLimits();
            [~,~,wireEndian]=computer;assert(ismember(wireEndian,'BL')&&isscalar(wireEndian), ...
                'EssentialBranch:WireEndian','Native byte order must be B or L.');wireBigEndian=wireEndian=='B';
            wireData=zeros(65536,1,'uint8');wireUsed=0;wireNodes=0;wireCharge=0;wireSlots=0;
            writerEmit(uint8('C1ESSWIRE').');writerEmit(uint8(1));writerEmit(zeros(8,1,'uint8'));
            writerNode(original,0);wireData(11:18)=K.wireRaw(uint64(wireUsed-18),wireBigEndian);
            bytes=wireData(1:wireUsed);

            function writerEmit(part)
                assert(isa(part,'uint8')&&isreal(part),'EssentialBranch:WireClass','Encoded chunks must be real uint8.');
                needed=wireUsed+numel(part);
                assert(needed<=wireL.wire_bytes,'EssentialBranch:WireBounds','The encoded wire exceeds its explicit byte bound.');
                if needed>numel(wireData),capacity=min(wireL.wire_bytes,max(needed,2*numel(wireData)));wireData(capacity,1)=uint8(0);end
                wireData(wireUsed+1:needed)=part(:);wireUsed=needed;
            end

            function writerCount(countValue)
                assert(isscalar(countValue)&&isfinite(countValue)&&countValue>=0&&countValue==fix(countValue)&&countValue<=flintmax, ...
                    'EssentialBranch:WireBounds','Frame counts must be exact nonnegative integers.');
                writerEmit(K.wireRaw(uint64(countValue),wireBigEndian));
            end

            function writerCharge(amount,slots)
                assert(amount<=wireL.allocation_charge-wireCharge&&slots<=wireL.container_slots-wireSlots, ...
                    'EssentialBranch:WireResource','The documented decoded-allocation charge or container-slot bound is exceeded.');
                wireCharge=wireCharge+amount;wireSlots=wireSlots+slots;
            end

            function writerText(textValue)
                assert(ischar(textValue)&&(isrow(textValue)||isempty(textValue)), ...
                    'EssentialBranch:WireText','Counted text must be a character row.');
                writerCharge(2*numel(textValue),0);writerCount(numel(textValue));writerEmit(K.wireRaw(uint16(textValue(:)),wireBigEndian));
            end

            function writerNode(v,depth)
                assert(depth<=wireL.depth&&wireNodes<wireL.nodes,'EssentialBranch:WireResource','Node count or nesting depth exceeds the explicit wire bound.');wireNodes=wireNodes+1;
                assert(~issparse(v)&&(isnumeric(v)||islogical(v)||ischar(v)||isstring(v)||iscell(v)||isstruct(v)), ...
                    'EssentialBranch:WireClass','Only dense plain numeric/logical/char/string/cell/struct values have a wire representation.');
                dims=size(v);assert(numel(dims)<=wireL.dimensions,'EssentialBranch:WireShape','Dimension count exceeds the wire bound.');
                extent=1;
                for d=1:numel(dims)
                    assert(dims(d)<=flintmax&&dims(d)<=wireL.dimension_product&&extent<=floor(wireL.dimension_product/max(1,dims(d))), ...
                        'EssentialBranch:WireBounds','Every dimension and nonzero dimension product must fit before encoding.');extent=extent*max(1,dims(d));
                end
                count=numel(v);writerCharge(128+8*numel(dims),0);flag=uint8(0);
                classes={'double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64'};
                if isnumeric(v)
                    tag=find(strcmp(class(v),classes));assert(isscalar(tag),'EssentialBranch:WireClass','Unsupported numeric wire class.');
                    flag=uint8(~isreal(v));assert(flag==0||tag<=2,'EssentialBranch:WireClass','Only floating-point classes support complex wire planes.');
                elseif islogical(v),tag=11;elseif ischar(v),tag=12;elseif isstring(v),tag=13;elseif iscell(v),tag=14;else,tag=15;end
                writerEmit(uint8([tag;flag]));writerCount(numel(dims));writerEmit(K.wireRaw(uint64(dims(:)),wireBigEndian));
                if tag<=10
                    widths=[8,4,1,1,2,2,4,4,8,8];writerCharge(count*widths(tag)*(1+double(flag)),0);
                    writerEmit(K.wireRaw(real(v),wireBigEndian));if flag,writerEmit(K.wireRaw(imag(v),wireBigEndian));end
                elseif tag==11
                    writerCharge(count,0);writerEmit(uint8(v(:)));
                elseif tag==12
                    writerCharge(2*count,0);writerEmit(K.wireRaw(uint16(v(:)),wireBigEndian));
                elseif tag==13
                    writerCharge(64*count,count);
                    for s=1:count,absent=ismissing(v(s));writerEmit(uint8(absent));if ~absent,writerText(char(v(s)));end;end
                elseif tag==14
                    writerCharge(16*count,count);assert(count<=wireL.nodes-wireNodes,'EssentialBranch:WireResource','Cell children exceed the remaining node budget.');
                    for s=1:count,writerNode(v{s},depth+1);end
                else
                    names=fieldnames(v);fields=numel(names);assert(fields<=wireL.fields,'EssentialBranch:WireFields','Field count exceeds the explicit wire bound.');
                    assert(fields==0||count<=floor((wireL.container_slots-wireSlots)/fields), ...
                        'EssentialBranch:WireResource','Struct field slots exceed their explicit bound.');
                    slots=count*fields;writerCharge(64*count+16*slots+32*fields,count+slots);writerCount(fields);
                    assert(slots<=wireL.nodes-wireNodes,'EssentialBranch:WireResource','Struct children exceed the remaining node budget.');
                    for f=1:fields,assert(isvarname(names{f}),'EssentialBranch:WireFields','Struct field names must be valid literal MATLAB names.');writerText(names{f});end
                    for s=1:count,for f=1:fields,writerNode(v(s).(names{f}),depth+1);end;end
                end
            end
        end

        function decoded=wireDecode(bytes)
            K=EssentialBranchSolutionFile_v3;wireL=K.wireLimits();
            assert(isa(bytes,'uint8')&&isreal(bytes)&&isequal(size(bytes),[numel(bytes),1])&&numel(bytes)<=wireL.wire_bytes, ...
                'EssentialBranch:WireBounds','The wire must be a bounded real uint8 column.');
            [~,~,wireEndian]=computer;assert(ismember(wireEndian,'BL')&&isscalar(wireEndian), ...
                'EssentialBranch:WireEndian','Native byte order must be B or L.');wireBigEndian=wireEndian=='B';
            wirePosition=1;wireNodes=0;wireCharge=0;wireSlots=0;
            assert(isequal(readerTake(9),uint8('C1ESSWIRE').'),'EssentialBranch:WireMagic','Unknown essential wire magic.');
            assert(readerTake(1)==uint8(1),'EssentialBranch:WireVersion','Unsupported essential wire version.');
            bodyLength=readerCount(wireL.wire_bytes,'body length');assert(bodyLength==numel(bytes)-18, ...
                'EssentialBranch:WireFrameLength','The declared wire body must cover all and only the remaining bytes.');
            decoded=readerNode(0);assert(wirePosition==numel(bytes)+1,'EssentialBranch:WireTrailing','Trailing bytes are not a second payload or extension.');

            function part=readerTake(count)
                assert(isscalar(count)&&isfinite(count)&&count>=0&&count==fix(count)&&count<=flintmax&&count<=numel(bytes)-wirePosition+1, ...
                    'EssentialBranch:WireTruncated','A framed payload exceeds the bytes remaining.');
                part=bytes(wirePosition:wirePosition+count-1);wirePosition=wirePosition+count;
            end

            function count=readerCount(bound,label)
                framed=readerTake(8);raw=typecast(framed(:),'uint64');if wireBigEndian,raw=swapbytes(raw);end
                assert(raw<=uint64(flintmax)&&raw<=uint64(bound),'EssentialBranch:WireBounds','The %s count exceeds its exact-integer or resource bound.',label);
                count=double(raw);
            end

            function readerCharge(amount,slots)
                assert(isfinite(amount)&&amount>=0&&amount<=wireL.allocation_charge-wireCharge&&slots>=0&&slots<=wireL.container_slots-wireSlots, ...
                    'EssentialBranch:WireResource','The documented decoded-allocation charge or container-slot bound is exceeded.');
                wireCharge=wireCharge+amount;wireSlots=wireSlots+slots;
            end

            function textValue=readerText(maxUnits)
                units=readerCount(min(maxUnits,floor((numel(bytes)-wirePosition+1)/2)),'UTF16 units');readerCharge(2*units,0);
                rawUnits=readerPlane(units,'uint16',2);textValue=reshape(char(rawUnits),1,[]);
                assert(isequal(uint16(textValue(:)),rawUnits(:)),'EssentialBranch:WireText','UTF16 code units must survive construction exactly.');
            end

            function plane=readerPlane(count,className,width)
                assert(count<=floor((numel(bytes)-wirePosition+1)/width),'EssentialBranch:WireTruncated','Numeric plane exceeds remaining bytes.');
                rawPlane=readerTake(count*width);plane=typecast(rawPlane(:),className);if wireBigEndian&&width>1,plane=swapbytes(plane);end
                assert(isequal(K.wireRaw(plane,wireBigEndian),rawPlane),'EssentialBranch:WireBits','A numeric plane changed raw payload bits during decoding.');
            end

            function out=readerNode(depth)
                assert(depth<=wireL.depth&&wireNodes<wireL.nodes,'EssentialBranch:WireResource','Node count or nesting depth exceeds the explicit wire bound.');wireNodes=wireNodes+1;
                tag=double(readerTake(1));flag=double(readerTake(1));
                assert(tag>=1&&tag<=15,'EssentialBranch:WireTag','Unknown or reserved node tag.');
                assert(flag==0||(flag==1&&tag<=2),'EssentialBranch:WireFlags','Unknown or invalid node flags.');
                dimensions=readerCount(wireL.dimensions,'dimension count');assert(dimensions>=2,'EssentialBranch:WireShape','MATLAB arrays have at least two stored dimensions.');
                assert(dimensions<=floor((numel(bytes)-wirePosition+1)/8),'EssentialBranch:WireTruncated','Dimension frames exceed the remaining bytes.');
                dims=zeros(1,dimensions);extent=1;
                for d=1:dimensions
                    dims(d)=readerCount(wireL.dimension_product,'dimension');
                    assert(extent<=floor(wireL.dimension_product/max(1,dims(d))),'EssentialBranch:WireBounds','Nonzero dimension products must fit even if another dimension is zero.');extent=extent*max(1,dims(d));
                end
                assert(dimensions==2||dims(end)~=1,'EssentialBranch:WireShape','Trailing singleton dimensions are not a canonical MATLAB size vector.');
                if any(dims==0),count=0;else,count=extent;end
                readerCharge(128+8*dimensions,0);
                classes={'double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64'};
                if tag<=10
                    widths=[8,4,1,1,2,2,4,4,8,8];width=widths(tag);
                    assert(count<=floor((numel(bytes)-wirePosition+1)/(width*(1+flag))),'EssentialBranch:WireTruncated','Numeric real/imaginary planes exceed remaining bytes.');
                    readerCharge(count*width*(1+flag),0);realPlane=readerPlane(count,classes{tag},width);
                    if flag
                        imaginaryPlane=readerPlane(count,classes{tag},width);out=complex(realPlane,imaginaryPlane);
                        assert(~isreal(out)&&isequal(K.wireRaw(real(out),wireBigEndian),K.wireRaw(realPlane,wireBigEndian))&& ...
                            isequal(K.wireRaw(imag(out),wireBigEndian),K.wireRaw(imaginaryPlane,wireBigEndian)), ...
                            'EssentialBranch:WireBits','Complex construction must preserve both raw planes and complex storage.');
                    else,out=realPlane;end
                    out=reshape(out,dims);
                elseif tag==11
                    assert(count<=numel(bytes)-wirePosition+1,'EssentialBranch:WireTruncated','Logical values exceed the remaining bytes.');readerCharge(count,0);raw=readerTake(count);
                    assert(all(raw<=1),'EssentialBranch:WireLogical','Logical bytes must be exactly zero or one.');out=reshape(logical(raw),dims);
                elseif tag==12
                    assert(count<=floor((numel(bytes)-wirePosition+1)/2),'EssentialBranch:WireTruncated','Character units exceed the remaining bytes.');readerCharge(2*count,0);
                    raw=readerPlane(count,'uint16',2);out=reshape(char(raw),dims);assert(isequal(uint16(out(:)),raw(:)), ...
                        'EssentialBranch:WireText','Character construction must preserve all UTF16 code units.');
                elseif tag==13
                    assert(count<=numel(bytes)-wirePosition+1,'EssentialBranch:WireTruncated','String missingness flags exceed remaining bytes.');readerCharge(64*count,count);out=strings(dims);
                    for s=1:count
                        absent=readerTake(1);assert(absent<=1,'EssentialBranch:WireString','String missingness is a literal zero/one flag.');
                        if absent,out(s)=string(missing);assert(ismissing(out(s)),'EssentialBranch:WireString','Missing string construction failed.');else
                            textValue=readerText(floor(wireL.allocation_charge/2));out(s)=string(textValue);literalText=char(out(s));
                            assert(~ismissing(out(s))&&isequal(uint16(literalText(:)),uint16(textValue(:))), ...
                                'EssentialBranch:WireString','String construction must preserve literal UTF16 content independently of missingness.');
                        end
                    end
                elseif tag==14
                    assert(count<=wireL.nodes-wireNodes&&count<=floor((numel(bytes)-wirePosition+1)/wireL.minimum_node_bytes), ...
                        'EssentialBranch:WireResource','Cell children must fit both the remaining node and framed-byte budgets before allocation.');
                    readerCharge(16*count,count);out=cell(dims);for s=1:count,out{s}=readerNode(depth+1);end
                else
                    fields=readerCount(wireL.fields,'struct field count');
                    assert(fields<=floor((numel(bytes)-wirePosition+1)/8),'EssentialBranch:WireTruncated','Struct field-name frames exceed remaining bytes.');
                    assert(fields==0||count<=floor((wireL.container_slots-wireSlots)/fields), ...
                        'EssentialBranch:WireResource','Struct field slots exceed their explicit bound before allocation.');
                    slots=count*fields;assert(slots<=wireL.nodes-wireNodes&&slots<=floor((numel(bytes)-wirePosition+1)/wireL.minimum_node_bytes), ...
                        'EssentialBranch:WireResource','Struct children must fit node and framed-byte budgets before allocation.');
                    readerCharge(64*count+16*slots+32*fields,count+slots);names=cell(fields,1);template=struct();
                    for f=1:fields
                        names{f}=readerText(namelengthmax);assert(isvarname(names{f})&&~any(strcmp(names{f},names(1:f-1))), ...
                            'EssentialBranch:WireFields','Struct names must be valid, ordered and unique; duplicate fields are not overwritten.');template.(names{f})=[];
                    end
                    assert(slots<=floor((numel(bytes)-wirePosition+1)/wireL.minimum_node_bytes), ...
                        'EssentialBranch:WireTruncated','All struct children must fit after their field-name frames, before array allocation.');
                    out=repmat(template,dims);
                    for s=1:count,for f=1:fields,out(s).(names{f})=readerNode(depth+1);end;end
                end
                assert(isequal(size(out),dims),'EssentialBranch:WireShape','Decoded class/container shape differs from its exact framed MATLAB size.');
            end
        end

        function validateTable(t)
            K=EssentialBranchSolutionFile_v3;K.exact(t,{'rows','paths','columns','layouts','row_layout'},'typed column table');K.integer(t.rows,0);K.columnCells(t.paths,'column paths');K.columnCells(t.columns,'columns');K.columnCells(t.layouts,'layouts');
            assert(numel(t.paths)==numel(t.columns)&&numel(unique(t.paths))==numel(t.paths)&&isa(t.row_layout,'uint32')&&isequal(size(t.row_layout),[t.rows,1])&&all(t.row_layout>=1&double(t.row_layout)<=numel(t.layouts)), ...
                'EssentialBranch:TableShape','Typed columns/layouts must have exact row dimensions and unique paths.');
            for j=1:numel(t.paths),K.pathToken(t.paths{j});col=t.columns{j};K.exact(col,{'group','entry','groups'},'typed column');
                assert(isa(col.group,'uint16')&&isa(col.entry,'uint32')&&isequal(size(col.group),[t.rows,1])&&isequal(size(col.entry),[t.rows,1]),'EssentialBranch:ColumnShape','Column presence/group/entry vectors must preserve native types and row dimensions.');K.columnCells(col.groups,'value groups');
                for k=1:numel(col.groups)
                    g=col.groups{k};K.exact(g,{'class','shape','is_real','values'},'value group');K.shape(g.shape);assert(islogical(g.is_real)&&isscalar(g.is_real)&&strcmp(class(g.values),g.class)&&K.realness(g.values)==g.is_real&&ismatrix(g.values)&&size(g.values,1)==prod(g.shape),'EssentialBranch:ValueClass','Group class/shape/realness must match its actual typed dense values.');K.value(g.values,'column group',inf);
                    used=double(col.entry(col.group==k));assert(~isempty(used)&&isequal(unique(used(:)),(1:size(g.values,2)).'),'EssentialBranch:UnusedValues','Every stored group entry must serve an explicit retained field.');
                end
                for k=1:t.rows
                    if col.group(k)==0,assert(col.entry(k)==0,'EssentialBranch:Presence','Missing values use zero group and zero entry together.');else
                        assert(col.group(k)<=numel(col.groups)&&col.entry(k)>=1&&col.entry(k)<=size(col.groups{col.group(k)}.values,2),'EssentialBranch:GroupBounds','Typed value reference is out of bounds.');
                    end
                end
            end
            assert(isequal(unique(double(t.row_layout(:))),(1:numel(t.layouts)).'),'EssentialBranch:UnusedLayouts','No unused layout payload is permitted.');
            for j=1:numel(t.layouts)
                l=t.layouts{j};assert(iscell(l)&&size(l,2)==2,'EssentialBranch:Layout','Layout must be path/container token pairs.');
                for k=1:size(l,1),K.pathToken(l{k,1});assert(islogical(l{k,2})&&isscalar(l{k,2}),'EssentialBranch:Layout','Container tokens are literal scalar logical values.');end
                assert(numel(unique(l(:,1)))==size(l,1),'EssentialBranch:Layout','A layout cannot duplicate a field path.');
                for k=1:size(l,1)
                    parts=strsplit(l{k,1},'.');
                    for depth=1:numel(parts)-1
                        parent=strjoin(parts(1:depth),'.');prior=find(strcmp(l(1:k-1,1),parent));
                        assert(isscalar(prior)&&l{prior,2},'EssentialBranch:LayoutTree','Every dotted path requires an earlier explicit container parent; leaves cannot have descendants.');
                    end
                end
            end
            for i=1:t.rows
                l=t.layouts{t.row_layout(i)};leaf=l(~cell2mat(l(:,2)),1);
                for j=1:numel(t.paths),expected=any(strcmp(t.paths{j},leaf));assert((t.columns{j}.group(i)>0)==expected,'EssentialBranch:Coverage','Layouts and typed value presence must agree exactly.');end
            end
        end

        function ranges(ranges,shapes,n,total)
            K=EssentialBranchSolutionFile_v3;assert(isa(ranges,'uint32')&&isequal(size(ranges),[n,2]),'EssentialBranch:Ragged','Ragged ranges must be uint32 N-by-2.');K.columnCells(shapes,'ragged shapes');assert(numel(shapes)==n,'EssentialBranch:Ragged','One literal array shape is required per point.');next=1;
            for k=1:n,K.exact(shapes{k},{'size','fields'},'ragged shape');K.shape(shapes{k}.size);K.columnCells(shapes{k}.fields,'ragged field names');assert(double(ranges(k,1))==next&&double(ranges(k,2))==prod(shapes{k}.size),'EssentialBranch:Ragged','Ragged ranges must cover each original event/cluster array exactly, in order.');next=next+double(ranges(k,2));end
            assert(next==total+1,'EssentialBranch:Ragged','No hidden or unused ragged row is allowed.');
        end

        function canonical(r)
            K=EssentialBranchSolutionFile_v3;c=K.fields();contract=K.contract();K.exact(r,{'schema','native_id','orbit','report','method','policy','metadata','context'},'scientific projection');
            assert(strcmp(r.schema,contract.schema),'EssentialBranch:Contract','Scientific projection contract mismatch.');if ~isempty(r.native_id),K.nativeID(r.native_id);end;K.point(r.metadata,r.context);
            K.exact(r.orbit,[c.orbit,{'mode_history','event_history','event_clusters','section_chart','primitive_cycle','gait_identification','topology_margins','minimum_physical_margins','event_cluster_split_merge_diagnostics','initial_section_admissibility','section_return_admissibility'}],'essential orbit');
            for name=c.orbit,K.value(r.orbit.(name{1}),name{1},4096);end
            checks={K.events(r.orbit.event_history),r.orbit.event_history;K.clusters(r.orbit.event_clusters),r.orbit.event_clusters; ...
                K.primitive(r.orbit.primitive_cycle),r.orbit.primitive_cycle;K.classifier(r.orbit.gait_identification),r.orbit.gait_identification; ...
                K.select(r.orbit.section_chart,c.section,{},'retained section',14),r.orbit.section_chart; ...
                K.admissibility(r.orbit.initial_section_admissibility),r.orbit.initial_section_admissibility; ...
                K.admissibility(r.orbit.section_return_admissibility),r.orbit.section_return_admissibility; ...
                K.reportProjection(r.report),r.report;K.method(r.method),r.method; ...
                K.margins(r.orbit.topology_margins,'topology_margins'),r.orbit.topology_margins; ...
                K.margins(r.orbit.minimum_physical_margins,'minimum_physical_margins'),r.orbit.minimum_physical_margins; ...
                K.margins(r.orbit.event_cluster_split_merge_diagnostics,'event_cluster_split_merge_diagnostics'),r.orbit.event_cluster_split_merge_diagnostics};
            for j=1:size(checks,1),assert(strcmp(K.digest(checks{j,1}),K.digest(checks{j,2})),'EssentialBranch:HiddenPayload','A retained record contains omitted or unsupported payload.');end
            K.modes(r.orbit.mode_history);K.policy(r.policy);K.plain(r,0,65536);
            for entry={{'initial_state',14},{'initial_mode',4},{'parameter',10},{'stride_displacement',14},{'poincare_state',14}}
                key=entry{1}{1};n=entry{1}{2};a=r.orbit.(key);assert((isnumeric(a)||islogical(a))&&(isempty(a)||numel(a)==n),'EssentialBranch:CoreShape','Retained %s must be empty or preserve %d entries.',key,n);
            end
            assert((isnumeric(r.orbit.period)||islogical(r.orbit.period))&&(isempty(r.orbit.period)||isscalar(r.orbit.period)), ...
                'EssentialBranch:Period','Preserve a literal scalar period or its empty value.');
            o=HybridOrbit_v3();for name={'initial_state','initial_mode','parameter','period','stride_displacement','return_policy_name'},o.(name{1})=r.orbit.(name{1});end
            assert(isequal(K.identity(o),r.native_id),'EssentialBranch:NativeID','Stored NativeID and its availability must bind the literal identity values.');
            if strcmp(r.context.role,'accepted'),assert(isfield(r.report,'accepted')&&isequal(r.report.accepted,true),'EssentialBranch:Role','Accepted role requires literal saved accepted=true.');end
            if strcmp(r.context.role,'rejected')&&isfield(r.report,'accepted'),assert(~isequal(r.report.accepted,true),'EssentialBranch:Role','A saved accepted record cannot be relabeled rejected.');end
        end

        function publish(file,p,maximumBytes,beforeSHA)
            K=EssentialBranchSolutionFile_v3;stage=[tempname(fileparts(file)) '.essential_stage.mat'];K.fresh(stage);
            c=K.contract();branch_index=struct('storage_version',c.storage_version,'scientific_projection_contract',c.schema,'point_count',p.point_count);essential_branch=K.wireEncode(p); %#ok<NASGU>
            save(stage,'branch_index','essential_branch','-v7');a=dir(stage);
            assert(a.bytes<=maximumBytes,'EssentialBranch:ByteLimit','Actual compressed MAT bytes %d exceed the explicitly measured ceiling %.0f; the stage is retained: %s.',a.bytes,maximumBytes,stage);
            first=K.read(stage);second=K.read(stage);assert(strcmp(K.digest(first),K.digest(p))&&strcmp(K.digest(second),K.digest(p)), ...
                'EssentialBranch:Readback','Two installed-stage reads must preserve every retained projection/graph/value exactly.');
            if isempty(beforeSHA),K.fresh(file);else,assert(exist(file,'file')==2&&strcmp(RoundSHA256_v3(file),beforeSHA),'EssentialBranch:ConcurrentChange','The original store changed before publication.');end
            options=javaArray('java.nio.file.CopyOption',1+double(~isempty(beforeSHA)));
            options(1)=javaMethod('valueOf','java.nio.file.StandardCopyOption','ATOMIC_MOVE');
            if ~isempty(beforeSHA),options(2)=javaMethod('valueOf','java.nio.file.StandardCopyOption','REPLACE_EXISTING');end
            sourcePath=java.nio.file.Paths.get(stage,javaArray('java.lang.String',0));targetPath=java.nio.file.Paths.get(file,javaArray('java.lang.String',0));
            java.nio.file.Files.move(sourcePath,targetPath,options);
            installed=K.read(file);assert(strcmp(K.digest(installed),K.digest(p)),'EssentialBranch:Installed','Installed scientific table differs from its verified stage.');
        end

        function marker=marker()
            c=EssentialBranchSolutionFile_v3.contract();marker=struct('schema',c.schema,'historical_evidence_only',true, ...
                'trajectory_available',false,'event_state_tapes_available',false,'solver_tapes_available',false, ...
                'requires_fresh_replay',true,'whole_runtime_equality_claimed',false,'omissions',c.omissions, ...
                'receipt_reference_availability',c.receipt_reference_availability,'cluster_membership_domain',c.cluster_membership_domain);
        end

        function known(value,allowed,label)
            assert(isstruct(value),'EssentialBranch:Structure','%s must be a literal plain struct.',label);unknown=setdiff(fieldnames(value),allowed);
            assert(isempty(unknown),'EssentialBranch:UnknownField','Unreviewed %s fields require explicit disposition: %s.',label,strjoin(unknown,', '));
        end

        function exact(value,allowed,label)
            assert(isstruct(value)&&isscalar(value)&&isequal(sort(fieldnames(value)),sort(allowed(:))), ...
                'EssentialBranch:Fieldset','%s must have exactly its declared scalar fieldset.',label);
        end

        function value(value,label,bound)
            K=EssentialBranchSolutionFile_v3;
            assert(~issparse(value)&&(isnumeric(value)||islogical(value)||ischar(value)||isstring(value)||iscell(value)), ...
                'EssentialBranch:ValueClass','%s must retain a supported dense primitive value, without runtime objects or generic structs.',label);
            if iscell(value)
                assert(numel(value)<=bound,'EssentialBranch:ValueBound','%s exceeds its explicit ragged value bound.',label);
                for k=1:numel(value),a=value{k};assert(~iscell(a)&&~isstruct(a),'EssentialBranch:Cell','Only one-level primitive cells are supported for literal names/modes.');K.value(a,label,4096);end
            elseif ischar(value)||isstring(value)
                textBound=max(4096,bound);assert(numel(value)<=textBound,'EssentialBranch:TextBound','%s exceeds its explicit text-element bound.',label);
                units=0;
                if ischar(value),units=numel(value);else
                    for k=1:numel(value),if ~ismissing(value(k)),units=units+numel(char(value(k)));end,end
                end
                assert(units<=textBound,'EssentialBranch:TextBound','%s exceeds its explicit UTF-16 content bound; missing strings remain literal.',label);
            else
                assert(numel(value)<=bound,'EssentialBranch:ValueBound','%s exceeds its explicit scientific-vector bound.',label);
                assert(any(strcmp(class(value),{'double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64','logical'})), ...
                    'EssentialBranch:NumericClass','Unsupported dense native numeric class.');
            end
        end

        function plain(value,depth,bound)
            K=EssentialBranchSolutionFile_v3;assert(depth<=16,'EssentialBranch:Depth','Essential records cannot contain recursive runtime graphs.');
            if isstruct(value),for k=1:numel(value),for name=fieldnames(value).',K.plain(value(k).(name{1}),depth+1,bound);end,end
            elseif iscell(value),for k=1:numel(value),K.plain(value{k},depth+1,bound);end
            else,K.value(value,'essential plain value',bound);end
        end

        function reference(value,required)
            K=EssentialBranchSolutionFile_v3;if ~required&&isempty(value),return;end;K.exact(value,{'file','sha256'},'historical reference');K.text(value.file,'historical path');K.sha(value.sha256);
        end

        function sha(value)
            assert(ischar(value)&&isrow(value)&&~isempty(regexp(value,'^[0-9a-f]{64}$','once')),'EssentialBranch:SHA','A reference must retain an explicit lowercase SHA256.');
        end

        function nativeID(value)
            assert(ischar(value)&&isrow(value)&&~isempty(regexp(value,'^native-orbit-record:sha256:[0-9a-f]{64}$','once')),'EssentialBranch:NativeID','Retain the literal immutable native record ID.');
        end

        function text(value,label)
            assert((ischar(value)&&isrow(value)&&~isempty(value))||(isstring(value)&&isscalar(value)&&~ismissing(value)&&strlength(value)>0), ...
                'EssentialBranch:Text','%s must be explicit nonempty scalar text.',label);
        end

        function integer(value,minimum)
            assert(isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value)&&value==fix(value)&&value>=minimum&&value<=flintmax, ...
                'EssentialBranch:Integer','An index/count must be an exactly representable bounded integer.');
        end

        function shape(value)
            assert(isa(value,'double')&&isrow(value)&&numel(value)>=2&&all(isfinite(value))&&all(value>=0&value==fix(value))&&prod(value)<=flintmax, ...
                'EssentialBranch:Shape','Preserve the exact finite MATLAB size vector.');
        end

        function columnCells(value,label)
            assert(iscell(value)&&iscolumn(value),'EssentialBranch:ColumnCells','%s must be an explicit column cell array, including 0-by-1 when empty.',label);
        end

        function pair(e,n)
            K=EssentialBranchSolutionFile_v3;K.integer(e.from,1);K.integer(e.to,1);assert(e.from<=n&&e.to<=n&&e.from~=e.to,'EssentialBranch:Pair','Graph endpoints must be distinct actual stored occurrences.');
        end

        function pathToken(value)
            assert(ischar(value)&&isrow(value)&&~isempty(regexp(value,'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)*$','once')), ...
                'EssentialBranch:PathToken','Typed column paths contain only literal MATLAB field names.');
        end

        function indices(value,n)
            assert(isnumeric(value)&&isreal(value)&&(isvector(value)||isempty(value))&&all(isfinite(value))&&all(value>=1&value<=n&value==fix(value)), ...
                'EssentialBranch:Bounds','Use explicit bounded integer occurrence indices.');
        end

        function id=identity(orbit)
            complete=numel(orbit.initial_state)==14&&numel(orbit.initial_mode)==4&&numel(orbit.parameter)==10&&isscalar(orbit.period)&&numel(orbit.stride_displacement)==14;
            if complete,id=OrbitContentIdentity_v3(orbit);else,id=[];end
        end

        function out=realness(value)
            if isnumeric(value),out=isreal(value);else,out=true;end
        end

        function out=hexBytes(value)
            EssentialBranchSolutionFile_v3.sha(value);out=uint8(sscanf(value,'%2x'));assert(isequal(size(out),[32,1]),'EssentialBranch:DigestBytes','Scientific digest must decode to exactly 32 bytes.');
        end

        function out=hex(value)
            assert(isa(value,'uint8')&&isequal(size(value),[32,1]),'EssentialBranch:DigestBytes','Scientific digest storage must be a 32-byte column.');out=lower(reshape(dec2hex(value,2).',1,[]));
        end

        function out=optional(value,key,fallback)
            out=fallback;if isfield(value,key),out=value.(key);end
        end

        function out=hint(value,key)
            out=NaN;if isfield(value,key),a=value.(key);if (isnumeric(a)||islogical(a))&&isscalar(a)&&isreal(a),out=double(a);end,end
        end

        function out=elementHint(value,index)
            out=NaN;if (isnumeric(value)||islogical(value))&&isreal(value)&&numel(value)>=index,out=double(value(index));end
        end

        function out=digest(value)
            [out,schema]=C1ScientificDigest_v3(value);assert(strcmp(schema,'C1-plain-scientific-digest-v1'),'EssentialBranch:DigestContract','The exact scientific digest contract must be source-bound.');
        end

        function limit(value)
            assert(isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value)&&value>0&&value<=flintmax,'EssentialBranch:ByteLimit','Supply a finite positive measured resulting-N byte ceiling; no extrapolated/default ceiling is permitted.');
        end

        function file=path(file)
            EssentialBranchSolutionFile_v3.text(file,'file');file=char(java.io.File(char(file)).getCanonicalPath());assert(exist(fileparts(file),'dir')==7,'EssentialBranch:Directory','The explicit destination directory must already exist.');
        end

        function requireV7(file)
            fid=fopen(file,'rb');assert(fid>=0,'EssentialBranch:Read','Cannot open the explicit essential store.');closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
            header=fread(fid,19,'*char').';assert(strcmp(header,'MATLAB 5.0 MAT-file'),'EssentialBranch:MATFormat','Essential schema4 requires the explicitly supported v7 MAT format.');
        end

        function fresh(file)
            assert(exist(file,'file')==0&&exist(file,'dir')==0,'EssentialBranch:Exists','Refuse overwrite of a pre-existing destination/stage: %s.',file);
        end
    end
end
