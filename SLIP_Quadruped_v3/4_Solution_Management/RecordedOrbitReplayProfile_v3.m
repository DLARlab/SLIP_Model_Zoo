function [profile,evidence]=RecordedOrbitReplayProfile_v3(orbit,report)
%RECORDEDORBITREPLAYPROFILE_V3 Bind saved PSS replay settings to their orbit.
% Returns recorded DATA, including any runtime descriptors, unchanged. It
% neither reconstructs callbacks nor executes a map, replay or admission.
profile=struct();
evidence=struct('schema','recorded-orbit-replay-profile-v1','complete',false,'reason','UNSUPPORTED_SAVED_PRODUCER', ...
    'source_contract','','producer_name','','profile_path','','recorded_EventTimeTolerance',[], ...
    'physical_parameter_prefix_bound',false,'augmented_parameter_length',NaN,'initial_energy_parameter',[], ...
    'parameter_source_path','','energy_parameter_scope','For PSS reports the role of optional element11 follows the actual residual and family contract; its presence alone does not establish a fixed target or solved orbit energy.', ...
    'trajectory_contract','','full_duplicate_trace_preserved',false,'retained_lineage_bound',false, ...
    'settings_are_recorded_data',true,'runtime_callbacks_reconstructed',false,'historical_admission_rechecked',false, ...
    'source_mutations',0,'failure',struct());
try
    assert(isa(orbit,'HybridOrbit_v3')&&isscalar(orbit)&&isa(orbit.trajectory,'Trajectory_v3'), ...
        'RecordedReplayProfile:Orbit','A literal native orbit with its full primary trajectory is required.');
    assert(isstruct(report)&&isscalar(report)&&isequal(member(report,'accepted',false),true)&&strcmp(member(report,'status',''),'accepted') ...
        &&isfield(report,'independent_replay')&&isfield(report,'replay_integration'), ...
        'RecordedReplayProfile:Producer','An explicit known accepted second-fresh-replay producer is required.');
    contract=member(report,'schema_version','');
    if strcmp(contract,'periodic-solution-solver-v3-2')
        p=report.augmented_parameter(:);evidence.parameter_source_path='report.augmented_parameter';
        evidence.producer_name='PeriodicSolutionSolver_v3';
        if numel(p)==11,evidence.initial_energy_parameter=p(11);end
    elseif strcmp(contract,'root-free-fixed-energy-admission-v1')
        assert(isequal(report.solver.root_solver_calls,0)&&isequal(report.solver.correction_performed,false) ...
            &&isequal(report.solver.coordinates_changed,false),'RecordedReplayProfile:Producer','The known root-free producer retains zero-correction facts.');
        p=report.seed.parameter(:);assert(numel(p)==10,'RecordedReplayProfile:Parameter','The root-free producer owns literal seed physical p10.');
        evidence.parameter_source_path='report.seed.parameter';evidence.producer_name='ValidateStoredPeriodicOrbit_v3';
    else,error('RecordedReplayProfile:Producer','Unsupported saved second-replay producer.');end
    d=report.independent_replay;mi=d.map_info;
    assert(isnumeric(p)&&isreal(p)&&all(isfinite(p))&&any(numel(p)==[10,11]) ...
        &&isequaln(p(1:10),orbit.parameter(:)), ...
        'RecordedReplayProfile:Parameter','Bind the physical first10 parameters; an optional11th energy value is separate metadata.');
    evidence.physical_parameter_prefix_bound=true;evidence.augmented_parameter_length=numel(p);
    assert(isequaln(d.section_state(:),orbit.initial_state(:))&&isequaln(mi.initial_state(:),orbit.initial_state(:)) ...
        &&isequaln(mi.initial_mode(:),orbit.initial_mode(:))&&isequaln(mi.period,orbit.period) ...
        &&isequaln(mi.stride_displacement,orbit.stride_displacement) ...
        &&strcmp(string(mi.return_policy_name),string(orbit.return_policy_name)), ...
        'RecordedReplayProfile:Lineage','The saved state/mode/period/stride/policy must match the second fresh replay.');
    if isa(mi.trajectory,'Trajectory_v3')
        for name={'time','state','mode','event_history','event_batches'}
            assert(isequaln(mi.trajectory.(name{1}),orbit.trajectory.(name{1})), ...
                'RecordedReplayProfile:Lineage','The full raw duplicate trajectory differs from the literal saved orbit.');
        end
        assert(isequaln(mi.event_history,orbit.event_history),'RecordedReplayProfile:Lineage','The actual replay event history differs.');
        evidence.trajectory_contract='full-native-second-fresh-replay';evidence.full_duplicate_trace_preserved=true;
    else
        summary=mi.trajectory;
        required={'diagnostic_kind','source_class','full_trace_preserved','sample_count','time_interval', ...
            'initial_state','final_state','initial_mode','final_mode'};
        assert(isstruct(summary)&&isscalar(summary)&&all(isfield(summary,required)) ...
            &&strcmp(summary.diagnostic_kind,'duplicate-trajectory-summary')&&strcmp(summary.source_class,'Trajectory_v3') ...
            &&isequal(summary.full_trace_preserved,false), ...
            'RecordedReplayProfile:CompactContract','Only the exact known duplicate-trajectory summary is supported.');
        % Reuse the existing known transformation, without a new serializer or
        % an invented duplicate full trace. Primary input handles are untouched.
        holder=CompactResearchBranch_v3(struct('trajectory',orbit.trajectory));expected=holder.trajectory;
        assert(isequaln(summary,expected),'RecordedReplayProfile:CompactLineage', ...
            'Every declared retained summary field must match compaction of the actual primary trajectory.');
        holder=CompactResearchBranch_v3(struct('event_history',orbit.event_history));
        assert(isequaln(mi.event_history,holder.event_history),'RecordedReplayProfile:CompactLineage','Retained replay event history differs.');
        evidence.trajectory_contract='CompactResearchBranch-v3 duplicate-trajectory-summary';
        evidence.full_duplicate_trace_preserved=false;
    end
    recorded=report.replay_integration;
    assert(isstruct(recorded)&&isscalar(recorded)&&isfield(recorded,'EventTimeTolerance'), ...
        'RecordedReplayProfile:Profile','Literal replay EventTimeTolerance is required; no default is supplied.');
    validateattributes(recorded.EventTimeTolerance,{'double'},{'real','finite','scalar','positive'});
    profile=recorded;evidence.complete=true;evidence.reason='KNOWN_SAVED_SECOND_REPLAY_PROFILE_BOUND';
    evidence.source_contract=[contract,' accepted second-fresh-replay'];
    evidence.profile_path='report.replay_integration';evidence.recorded_EventTimeTolerance=recorded.EventTimeTolerance;
    evidence.retained_lineage_bound=true;
catch problem
    profile=struct();evidence.reason=problem.identifier;
    evidence.failure=struct('identifier',problem.identifier,'message',problem.message);
end
end
function value=member(s,key,fallback),value=fallback;if isstruct(s)&&isscalar(s)&&isfield(s,key),value=s.(key);end;end
