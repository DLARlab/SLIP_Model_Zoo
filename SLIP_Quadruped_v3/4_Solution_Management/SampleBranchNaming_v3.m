function [audit,samples]=SampleBranchNaming_v3(component,options)
%SAMPLEBRANCHNAMING_V3 Admit all resolved intersections at twenty speed levels.
% component: stable component_id, ordered_verified, connectivity_evidence,
% points(:) with orbit_id, orbit, admission_report; monotone_edges_verified.
% Explicit source identities survive every point and modal label change.
% Missing correction, uncertain limb membership or edge resolution remains
% incomplete. A shared label never establishes component connectivity.
    if nargin<2,options=struct();end
    defaults=struct('SpeedTolerance',1e-8,'DirectionTolerance',1e-10, ...
        'ConstantSpeedTolerance',1e-10,'Correction',struct(), ...
        'ReclassifyStored',true,'MaxCorrections',Inf,'DeadlineUnixSeconds',Inf, ...
        'DeadlineMonotonicNs',Inf,'CheckpointFunction',[],'ResumeFunction',[], ...
        'MaxPredictorNeighborhoodFactor',1,'ClassificationOptions',struct());
    options=merge(defaults,options);samples=struct([]);
    validateattributes(options.SpeedTolerance,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(options.MaxPredictorNeighborhoodFactor,{'numeric'},{'scalar','real','finite','positive'});
    required={'component_id','ordered_verified','connectivity_evidence','points'};
    if ~isstruct(component)||~isscalar(component)||~all(isfield(component,required)) ...
            ||isempty(component.component_id)||~isequal(component.ordered_verified,true) ...
            ||~hasEvidence(component.connectivity_evidence)||isempty(component.points)
        error('SampleBranchNaming_v3:Component','An identified, verified ordered connected component with explicit evidence is required.');
    end
    points=component.points;n=numel(points);
    if ~all(isfield(points,{'orbit_id','orbit','admission_report'}))|| ...
            numel(unique({points.orbit_id}))~=n
        error('SampleBranchNaming_v3:PointIdentity','Every source point needs a distinct stable orbit identity, orbit and admission evidence.');
    end
    p=points(1).orbit.parameter(:);v=zeros(1,n);counts=nan(1,n);certain=false(1,n);classes=cell(1,n);
    for k=1:n
        orbit=points(k).orbit;report=points(k).admission_report;
        if ~isequal(orbit.parameter(:),p)||~admitted(report)
            error('SampleBranchNaming_v3:Admission','Every point must retain the same exact p10 and original nine-gate primitive admission.');
        end
        gait=report.classification;
        if options.ReclassifyStored,gait=GaitIdentification_v3(orbit,options.ClassificationOptions);end
        classes{k}=gait;checkClass(gait);
        observable=OrbitSpeed_v3(orbit,report.primitive.primitive_period);
        v(k)=observable.mean_signed_velocity;counts(k)=gait.primitive_flight_count;certain(k)=gait.flight_count_certain;
    end
    resolution=false(1,max(0,n-1));
    if isfield(component,'monotone_edges_verified'),resolution=component.monotone_edges_verified;end
    plan=BranchSpeedLevelPlan_v3(v,counts,struct('DirectionTolerance',options.DirectionTolerance, ...
        'ConstantSpeedTolerance',options.ConstantSpeedTolerance,'FlightCountCertain',certain, ...
        'MonotoneEdgesVerified',resolution));
    partitions=struct([]);corrections=0;
    for partitionIndex=1:numel(plan.partitions)
        part=plan.partitions(partitionIndex);levels=repmat(levelTemplate(),1,20);
        tolerance=options.SpeedTolerance;
        if part.applicable,tolerance=min(tolerance,diff(part.speed_range)/190);end
        for j=1:20
            registered=part.levels(j);level=levelTemplate();level.target_speed=registered.target_speed;
            level.complete=registered.resolution_complete&&part.applicable;
            level.reason=registered.reason;level.target_tolerance=tolerance;
            for hitIndex=1:numel(registered.intersections)
                hit=registered.intersections(hitIndex);trial=trialTemplate();
                trial.intersection_plan=hit;trial.target_speed=registered.target_speed;
                left=hit.left_point;right=hit.right_point;target=part.direction*registered.target_speed;
                context=struct('component_id',component.component_id,'partition_index',partitionIndex, ...
                    'level_index',j,'intersection_index',hitIndex,'target_speed',registered.target_speed);
                cachedTrial=[];cachedSample=[];
                if ~isempty(options.ResumeFunction)
                    [cachedTrial,cachedSample]=options.ResumeFunction(context);
                end
                candidates=unique([left,right]);sourceIndex=[];
                for candidate=candidates
                    if abs(abs(v(candidate))-registered.target_speed)<=tolerance&& ...
                            abs(v(candidate)-target)<=tolerance
                        sourceIndex=candidate;break
                    end
                end
                if ~isempty(cachedTrial)&&~cachedTrial.accepted
                    % The resume owner may retain a completed failed
                    % experiment until a justified successor is declared.
                    trial=restoreTrial(cachedTrial);trial.intersection_plan=hit;trial.target_speed=registered.target_speed;
                    orbit=[];gait=struct();identity='';admission=struct();
                elseif ~isempty(cachedSample)&&~isempty(cachedTrial)&&cachedTrial.accepted
                    if ~admitted(cachedSample.admission_report)
                        error('SampleBranchNaming_v3:ResumeAdmission','Cached intersection lacks its original nine-gate primitive admission.');
                    end
                    trial=restoreTrial(cachedTrial);trial.intersection_plan=hit;trial.target_speed=registered.target_speed;
                    orbit=cachedSample.orbit;gait=cachedSample.classification;
                    if options.ReclassifyStored,gait=GaitIdentification_v3(orbit,options.ClassificationOptions);end
                    identity=cachedSample.orbit_id;admission=cachedSample.admission_report;
                elseif ~isempty(sourceIndex)
                    orbit=points(sourceIndex).orbit;gait=classes{sourceIndex};
                    identity=points(sourceIndex).orbit_id;admission=points(sourceIndex).admission_report;
                    trial.origin='stored_admitted_point';trial.status='accepted';trial.accepted=true;
                    trial.source_point_index=sourceIndex;trial.membership=struct('verified_source_point',true);
                else
                    orbit=[];gait=struct();identity='';admission=struct();
                    remaining=min(options.DeadlineUnixSeconds-posixtime(datetime('now','TimeZone','UTC')), ...
                        (options.DeadlineMonotonicNs-double(java.lang.System.nanoTime))/1e9);
                    if corrections>=options.MaxCorrections||remaining<=0
                        trial.status='budget_refusal';
                    elseif left==right||~hit.resolution_verified
                        trial.status='unresolved_intersection';
                    else
                        correction=options.Correction;correction.SpeedTolerance=tolerance;
                        correction.AdmissionReports={points(left).admission_report,points(right).admission_report};
                        correction.DeadlineUnixSeconds=options.DeadlineUnixSeconds;
                        correction.DeadlineMonotonicNs=options.DeadlineMonotonicNs;
                        [orbit,report]=CorrectOrbitAtSpeed_v3(points(left).orbit,points(right).orbit, ...
                            hit.predictor_fraction,target,correction);corrections=corrections+1;
                        trial.origin='speed_constrained_shared_service';trial.status=report.status;
                        trial.correction_report=report;trial.accepted=report.accepted;
                        if report.accepted
                            admission=report.shared_service_report;gait=report.classification;
                            trial.membership=membership(orbit,points(left).orbit,points(right).orbit, ...
                                options.MaxPredictorNeighborhoodFactor);
                            if ~trial.membership.within_registered_neighborhood
                                trial.accepted=false;trial.status='limb_membership_unresolved';
                            else
                                identity=OrbitContentIdentity_v3(orbit);
                            end
                        end
                    end
                end
                if trial.accepted
                    checkClass(gait);observable=OrbitSpeed_v3(orbit,admission.primitive.primitive_period);
                    trial.achieved_speed=observable.speed;trial.speed_error=observable.speed-registered.target_speed;
                    trial.signed_velocity_error=observable.mean_signed_velocity-target;
                    trial.classification=gait;trial.orbit_id=identity;
                    if abs(trial.speed_error)>tolerance||abs(trial.signed_velocity_error)>tolerance ...
                            ||~gait.flight_count_certain||gait.primitive_flight_count~=part.primitive_flight_count
                        trial.accepted=false;trial.status='speed_direction_or_flight_partition_mismatch';
                    end
                end
                if trial.accepted
                    duplicate=findEquivalent(samples,orbit,target,tolerance);
                    if isempty(duplicate)
                        sample=struct('orbit_id',identity,'parent_component_id',component.component_id, ...
                            'partition_index',partitionIndex,'level_index',j,'intersection_index',hitIndex, ...
                            'orbit',orbit,'admission_report',admission,'classification',gait, ...
                            'speed_observable',observable,'source_orbit_ids',{{points(left).orbit_id,points(right).orbit_id}});
                        samples=append(samples,sample);trial.sample_index=numel(samples);
                    else
                        trial.sample_index=duplicate;trial.orbit_id=samples(duplicate).orbit_id;
                        % A fold has distinct path intersections. Convergence
                        % of both limbs to the same cycle leaves one missing.
                        if any([level.trials.sample_index]==duplicate)
                            trial.accepted=false;trial.status='duplicate_cycle_at_distinct_intersection';
                        end
                    end
                end
                level.trials=append(level.trials,trial);
                if ~isempty(options.CheckpointFunction)
                    latest=[];
                    if trial.accepted,latest=samples(trial.sample_index);end
                    options.CheckpointFunction(trial,latest,context);
                end
                if trial.accepted
                    level.labels{end+1}=char(gait.canonical_point_label);
                    level.qualified(end+1)=gait.canonical_label_qualified;
                    level.sample_indices(end+1)=trial.sample_index;
                else
                    level.complete=false;
                end
            end
            if isempty(level.labels),level.complete=false;end
            levels(j)=level;
        end
        votes=BranchNamingVotes_v3(levels);part.levels=levels;part.voting=votes;
        part.parent_component_id=component.component_id;
        part.partition_id=sprintf('%s/partition-%02d',char(component.component_id),partitionIndex);
        part.actual_physical_orbit_count=numel(unique([levels.sample_indices]));
        part.method_applicable=part.applicable;
        part.canonical_branch_name='';
        if votes.canonical_name_qualified,part.canonical_branch_name=votes.mode;end
        if ~part.applicable
            part.voting.canonical_name_qualified=false;part.voting.provisional=true;
            part.method_exception='PIP keeps its explicit C0 identity; isolated or constant-speed ordinary data are not a sampled branch.';
        else,part.method_exception='';end
        partitions=append(partitions,part);
    end
    parent=component.component_id;if isfield(component,'parent_component_id'),parent=component.parent_component_id;end
    audit=struct('schema_version','twenty-speed-branch-naming-v3.1','component_id',component.component_id, ...
        'parent_component_id',parent,'connectivity_evidence',component.connectivity_evidence, ...
        'physical_parameter',p,'source_orbit_ids',{{points.orbit_id}},'source_point_count',n, ...
        'source_mean_signed_velocities',v,'partitions',partitions,'plan',plan, ...
        'actual_physical_orbit_count',numel(samples),'correction_attempt_count',corrections, ...
        'options',options,'new_connectivity_claimed',false, ...
        'point_labels_overwritten',false,'complete',all(arrayfun(@(x)x.voting.complete,partitions)), ...
        'note','Modal names describe twenty equal speed locations on each resolved partition; they do not relabel individual points or join components.');
end
function out=levelTemplate()
    out=struct('target_speed',NaN,'target_tolerance',NaN,'complete',false,'reason','', ...
        'labels',{{}},'qualified',false(1,0),'sample_indices',[],'trials',struct([]));
end
function out=trialTemplate()
    out=struct('intersection_plan',struct(),'target_speed',NaN,'achieved_speed',NaN, ...
        'speed_error',NaN,'signed_velocity_error',NaN,'origin','','status','not_started', ...
        'accepted',false,'source_point_index',[],'sample_index',0,'orbit_id','', ...
        'classification',struct(),'correction_report',struct(),'membership',struct());
end
function trial=restoreTrial(saved)
    % Compaction adds diagnostic metadata. Keep the public trial schema
    % uniform when old checkpoints and new numerical attempts share a level.
    trial=trialTemplate();fields=fieldnames(trial);
    for k=1:numel(fields)
        key=fields{k};if isfield(saved,key),trial.(key)=saved.(key);end
    end
end
function yes=admitted(report)
    keys={'full_closure','mode_closure','target_energy','trajectory_energy_variation', ...
        'unscaled_family_equations','family_constraint','physical_inequalities','primitive_identity','replay_determinism'};
    yes=isstruct(report)&&isscalar(report)&&all(isfield(report,{'accepted','acceptance_gates','primitive','classification'})) ...
        &&isequal(report.accepted,true)&&all(isfield(report.acceptance_gates,keys));
    if ~yes,return;end
    for k=1:numel(keys),yes=yes&&isequal(report.acceptance_gates.(keys{k}),true);end
    yes=yes&&isfield(report.primitive,'status')&&isfield(report.primitive,'cover_count') ...
        &&strcmp(char(report.primitive.status),'primitive_within_checked_bound')&&report.primitive.cover_count==1;
end
function checkClass(gait)
    [~,currentContract]=GaitSemanticTable_v3();
    fields={'contract_version','canonical_point_label','canonical_label_qualified', ...
        'validated_gait_type','primitive_flight_count','flight_count_certain'};
    if ~isstruct(gait)||~isscalar(gait)||~all(isfield(gait,fields))|| ...
            ~strcmp(gait.contract_version,currentContract)
        error('SampleBranchNaming_v3:Classification','Recompute the versioned native classification before sampling.');
    end
end
function check=membership(orbit,left,right,factor)
    scale=max(1,max(abs([left.initial_state(:),right.initial_state(:)]),[],2));
    schema=QuadrupedSchema_v3.shared();indices=setdiff(1:schema.StateDimension,schema.TranslationIndex);
    a=left.initial_state(indices)./scale(indices);b=right.initial_state(indices)./scale(indices);
    c=orbit.initial_state(indices)./scale(indices);d=b-a;length2=sum(d.^2);
    if length2<=eps,t=NaN;distance=norm(c-a);limit=1e-7;
    else,t=dot(c-a,d)/length2;distance=norm(c-(a+max(0,min(1,t))*d));limit=max(1e-7,factor*sqrt(length2));end
    closedMode=isequal(logical(orbit.initial_mode(:)),logical(left.initial_mode(:)));
    valid=closedMode&&distance<=limit&&(isnan(t)||t>=-.25&&t<=1.25);
    check=struct('within_registered_neighborhood',valid,'scaled_transverse_distance',distance, ...
        'maximum_distance',limit,'projected_bracket_fraction',t,'mode_chart_matches',closedMode, ...
        'evidence_scope','Numerical local bracket neighborhood; no global connectivity theorem claimed.');
end
function index=findEquivalent(samples,orbit,target,tolerance)
    index=[];schema=QuadrupedSchema_v3.shared();indices=setdiff(1:schema.StateDimension,schema.TranslationIndex);
    for k=1:numel(samples)
        other=samples(k).orbit;
        if isequal(logical(other.initial_mode(:)),logical(orbit.initial_mode(:))) ...
                &&isequal(other.parameter(:),orbit.parameter(:)) ...
                &&abs(other.period-orbit.period)<=1e-8*max(1,orbit.period) ...
                &&norm(other.initial_state(indices)-orbit.initial_state(indices),inf)<=1e-8
            % Nearby state/period records can belong to distinct speed
            % levels. Search every candidate for a literal stored orbit
            % that independently satisfies the current signed target.
            stored=OrbitSpeed_v3(other,samples(k).admission_report.primitive.primitive_period);
            if abs(stored.speed-abs(target))<=tolerance ...
                    &&abs(stored.mean_signed_velocity-target)<=tolerance
                index=k;return
            end
        end
    end
end
function result=append(result,item)
    if isempty(result),result=item;else,result(end+1)=item;end
end
function result=merge(defaults,supplied)
    if ~isstruct(supplied)||~isscalar(supplied)||any(~ismember(fieldnames(supplied),fieldnames(defaults)))
        error('SampleBranchNaming_v3:Options','Unknown sampling option.');
    end
    result=defaults;keys=fieldnames(supplied);
    for k=1:numel(keys),result.(keys{k})=supplied.(keys{k});end
end
function yes=hasEvidence(value)
    yes=(ischar(value)&&~isempty(strtrim(value))) ...
        ||(isstring(value)&&isscalar(value)&&strlength(strtrim(value))>0) ...
        ||(isstruct(value)&&isscalar(value)&&~isempty(fieldnames(value)));
end
