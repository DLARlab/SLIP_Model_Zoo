function result=RunPeriodTwoCandidate_v3(candidateIndex,cfg,outputDirectory,maxWallSeconds,task)
%RUNPERIODTWOCANDIDATE_V3 Correct a preregistered measured -1 sector hypothesis.
% A candidate carries a measured physical direction and explicit BL2 policy.
% Full fresh closure and minimal period remain the shared service's gates.
    registration=cfg.period_two_candidates(candidateIndex);
    if isfield(registration,'method')&&strcmp(registration.method,'front-twisted-BL1-common-C1-Broyden-retry')
        if nargin<5,task=struct('repair_revision',0);end
        result=RunTwistedFrontRetry_v3(registration,cfg,outputDirectory,maxWallSeconds,task);return
    end
    if isfield(registration,'method')&&strcmp(registration.method,'exact-opposed-spread-twisted-restriction')
        if nargin<5,task=struct('repair_revision',0);end
        result=RunOpposedSpreadPeriodTwo_v3(registration,cfg,outputDirectory,maxWallSeconds,task);return
    end
    v3=V3Root_v3(mfilename('fullpath'));
    loaded=load(V3Path_v3(fullfile(v3,registration.candidate_artifact)),registration.candidate_variable);
    candidate=loaded.(registration.candidate_variable);
    if nargin>=5,candidate.repair_revision=task.repair_revision;end
    validateattributes(candidate.physical_directions,{'numeric'},{'nrows',14,'finite','real'});
    assert(candidate.seed.occurrence==2,'A period-two candidate must explicitly prescribe two BL touchdowns.');
    chartAudit=registration.chart_audit;
    audit=jsondecode(fileread(V3Path_v3(fullfile(v3,chartAudit))));
    if ~audit.passed||~isfield(audit,'helper_path')||~isfield(audit,'helper_sha256') ...
            ||~V3HashMatches_v3(audit.helper_sha256, fullfile(v3,audit.helper_path))
        error('RunPeriodTwoCandidate_v3:ChartGate','The declared BL2 event-order derivative gate must pass under the current helper source hash.');
    end
    candidate.event_order_chart_audit=chartAudit;
    candidate.event_order_jacobian_options=struct('PhysicalParameter',candidate.seed.parameter, ...
        'BLTouchdownsPerReturn',2,'RelativeCandidateSteps',1e-4, ...
        'MaximumRelativeError',.001,'FailurePolicy','nan');
    methodFile=fullfile(outputDirectory,'period_two_solver_method_registration.json');
    if ~isfile(V3Path_v3(methodFile))
        method=struct('schema_version','prospective-BL2-chart-correction-v3-1', ...
            'registered_utc',char(datetime('now','TimeZone','UTC')), ...
            'diagnosis','Strict raw contact-order signatures obstructed derivatives despite commuting independent zero-compression factors; measured two-return limiting derivatives agree.', ...
            'gate',chartAudit,'helper_path',audit.helper_path,'helper_sha256',audit.helper_sha256, ...
            'correction','Explicitly counted BL2 common-C1 event-order chart; h=1e-4 with internal h/2 comparison; Broyden reuse and best-candidate continuation between task slices.', ...
            'jacobian_options',candidate.event_order_jacobian_options, ...
            'acceptance_tolerances_changed',false,'domain_changed',false, ...
            'scope','Baseline regular two-TD/LO-per-leg contact cohorts; not the archived one-TD-per-leg two-flight B2 chart or a C2/bifurcation certificate.');
        RoundJSON_v3(methodFile,method);
    end
    phase=RunFamilySectorCorrections_v3(struct(),cfg,outputDirectory,maxWallSeconds,'P2',candidate);
    result=struct('schema_version','period-two-signed-sector-execution-v3-1', ...
        'state',phase.state,'scientific_status','period_two_sector_hypothesis_unresolved', ...
        'candidate_id',registration.id,'candidate_artifact',registration.candidate_artifact, ...
        'family_switch',phase,'function_evaluations',phase.function_evaluations, ...
        'new_points',phase.accepted_count,'message','Two BL returns do not establish a primitive gait; actual flight count/minimality and signed amplitude are independently checked.', ...
        'ancestry_claimed',false,'regular_bifurcation_claimed',false);
    if strcmp(phase.state,'accepted')
        if phase.accepted_count>0,result.scientific_status='period_two_sector_orbits_recovered_attachment_unresolved';
        else,result.state='retryable_failure';result.scientific_status='executed_period_two_sector_corrections_unresolved';end
    end
    RoundJSON_v3(fullfile(outputDirectory,'period_two_candidate.json'),result);
end
