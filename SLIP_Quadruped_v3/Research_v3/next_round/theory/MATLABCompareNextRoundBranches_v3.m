function audit=MATLABCompareNextRoundBranches_v3(options)
%MATLABCOMPARENEXTROUNDBRANCHES_V3 Read-only physical branch-nearness audit.
% All accepted branch points participate in the apex search. Trajectory
% diagnostics use saved event-aware one-sided data; no shooting is performed.
    if nargin<1,options=struct();end
    timer=tic;
    options=defaults(options,struct('ClosureTolerance',1e-8, ...
        'SynchronizationTolerance',1e-7,'SampleCount',257,'PhaseTolerance',1e-9));
    here=fileparts(mfilename('fullpath'));v3=fileparts(fileparts(fileparts(here)));
    for folder={'Schema_v3','Dynamics_v3','Simulation_v3','Orbit_v3','Numerics_v3','Research_v3/Drivers_v3'}
        V3LegacyAddPath_v3(fullfile(v3,folder{1}));
    end
    baseline=[10;10;20;20;1;1;0;0;2;.5];groups=struct('id',{},'scope',{},'points',{});manifest=struct([]);skipped=struct([]);
    fullTasks=fullfile(v3,'Research_v3','next_round','tasks','full');
    files=V3Dir_v3(fullfile(fullTasks,'**','branch.mat'));
    for k=1:numel(files)
        path=fullfile(files(k).folder,files(k).name);[id,~]=recordedTaskIdentity(files(k));
        readBranch(path,['full_',id],'full-task accepted continuation points');
    end
    files=V3Dir_v3(fullfile(fullTasks,'**','daughter_continuation_*.mat'));
    for k=1:numel(files)
        path=fullfile(files(k).folder,files(k).name);
        [continuationTaskId,continuationFileId]=recordedTaskIdentity(files(k));
        readBranch(path,['full_',continuationTaskId,'_',continuationFileId], ...
            'full-task accepted signed-daughter continuation points');
    end
    files=V3Dir_v3(fullfile(fullTasks,'PIP*','daughter_*.mat'));
    for k=1:numel(files)
        if startsWith(files(k).name,'daughter_continuation_'),continue;end
        path=fullfile(files(k).folder,files(k).name);[~,id,folderExtension]=fileparts(files(k).folder);id=[id,folderExtension];
        readDaughter(path,['full_',id,'_amplitude_samples'],'full-task corrected signed daughters',false);
    end
    for pattern={'restricted_trial_r*.mat','bridge_point_*.mat'}
        files=V3Dir_v3(fullfile(fullTasks,'**',pattern{1}));
        for k=1:numel(files)
            path=fullfile(files(k).folder,files(k).name);[~,id,folderExtension]=fileparts(files(k).folder);id=[id,folderExtension];
            readServiceOrbit(path,['full_',id],'accepted shared-service saved records; admission and continuation remain separate');
        end
    end
    files=V3Dir_v3(fullfile(fullTasks,'**','accuracy_repair_r*.mat'));
    for k=1:numel(files)
        path=fullfile(files(k).folder,files(k).name);[~,id,folderExtension]=fileparts(files(k).folder);id=[id,folderExtension];
        readAccuracyCopy(path,['full_',id,'_copied_amplitude_evidence']);
    end
    files=V3Dir_v3(fullfile(here,'opposed_spread_n*_actual_trace.mat'));
    for k=1:numel(files)
        path=fullfile(files(k).folder,files(k).name);
        [loaded,digest]=readStable(path,{'orbit','item','predictor'});addManifest(path,'exact restricted predictor replay',digest);
        if ~loaded.item.passed,skip(path,'predictor replay did not pass');continue;end
        metadata=struct('marked_TD_angle',loaded.predictor.touchdown_angle,'resonance_index',loaded.predictor.resonance_index);
        addPoint(sprintf('theory_opposed_spread_n%d',metadata.resonance_index), ...
            'saved exact-predictor replay; no nonlinear correction/new campaign progress',loaded.orbit,path,1,metadata);
    end
    for family=1:2
        files=V3Dir_v3(fullfile(v3,'Research_v3','runs','full',sprintf('pronk_daughter_v2_%d_*.mat',family)));
        for k=1:numel(files)
            readDaughter(fullfile(files(k).folder,files(k).name), ...
                sprintf('historical_restricted_daughter_%d',family),'historical restricted amplitude representatives',true);
        end
    end
    importedFull=any(arrayfun(@(g)startsWith(g.id,'full_PK_continuation'),groups));
    if ~importedFull
        for sign=[-1,1]
            path=fullfile(v3,'Research_v3','runs','full',sprintf('family_%+d.mat',sign));
            if isfile(V3Path_v3(path)),readBranch(path,'historical_imported_PK','historical imported PK fallback; ancestry unresolved');end
        end
    end
    % Validation samples are useful references, never full-profile progress.
    validation=fullfile(v3,'Research_v3','next_round','tasks','validation','PK_continuation_m1','branch.mat');
    if isfile(V3Path_v3(validation)),readBranch(validation,'validation_imported_PK_m1','executed validation reference only');end
    comparisons=struct([]);summary=struct([]);
    for a=1:numel(groups)
        points=groups(a).points;
        item=struct('id',groups(a).id,'scope',groups(a).scope,'accepted_point_records',numel(points), ...
            'point_artifacts',{{points.artifact}},'point_indices',[points.point_index], ...
            'energy_range',[min([points.energy]),max([points.energy])], ...
            'period_range',[min([points.period]),max([points.period])], ...
            'synchronized_pronk_reflection_eligible_count',sum([points.reflection_eligible]), ...
            'endpoints_are_finite_checkpoint_boundaries',true);
        if isempty(summary),summary=item;else,summary(end+1)=item;end %#ok<AGROW>
        for b=a+1:numel(groups)
            [ia,ib,reflected,apexDistance]=closest(points,groups(b).points);
            pa=points(ia);pb=groups(b).points(ib);
            wave=compareTrajectory(pa,pb,reflected);
            comparedState=pb.state;if reflected,comparedState=reflect(comparedState);end
            assert(abs(apexDistance-norm(pa.state(2:end)-comparedState(2:end),inf))<=128*eps(max(1,apexDistance)), ...
                'The stored closest distance differs from the selected physical states.');
            pair=struct('first_group',groups(a).id,'second_group',groups(b).id, ...
                'all_accepted_points_searched',true,'first_point',pointSummary(pa), ...
                'second_point',pointSummary(pb),'horizontal_reflection_applied',reflected, ...
                'same_physical_parameters',isequal(pa.parameter,pb.parameter), ...
                'closest_physical_apex_state_distance',apexDistance, ...
                'absolute_energy_gap',abs(pa.energy-pb.energy), ...
                'absolute_period_gap',abs(pa.period-pb.period), ...
                'signed_drift_gap',pa.drift-(-1)^reflected*pb.drift, ...
                'absolute_reflected_drift_gap',abs(pa.drift-(-1)^reflected*pb.drift), ...
                'endpoint_to_other_branch_distances',endpointDistances(points,groups(b).points), ...
                'trajectory',wave,'identity_or_ancestry_established',false);
            if isempty(comparisons),comparisons=pair;else,comparisons(end+1)=pair;end %#ok<AGROW>
        end
    end
    reflectionPairs=struct([]);
    for groupIndex=1:numel(groups)
        records=groups(groupIndex).points;bestReflected=Inf;selected=[];
        for firstIndex=1:numel(records)
            for secondIndex=firstIndex+1:numel(records)
                if ~records(firstIndex).reflection_eligible||~records(secondIndex).reflection_eligible ...
                        ||records(firstIndex).drift*records(secondIndex).drift>=0,continue;end
                reflectedState=reflect(records(secondIndex).state);
                trial=norm(records(firstIndex).state(2:end)-reflectedState(2:end),inf);
                if trial<bestReflected,bestReflected=trial;selected=[firstIndex,secondIndex];end
            end
        end
        if isempty(selected),continue;end
        firstPoint=records(selected(1));secondPoint=records(selected(2));
        item=struct('group',groups(groupIndex).id,'first_point',pointSummary(firstPoint), ...
            'second_point',pointSummary(secondPoint),'opposite_recorded_drift_signs',true, ...
            'reflected_apex_state_distance',bestReflected, ...
            'absolute_energy_gap',abs(firstPoint.energy-secondPoint.energy), ...
            'absolute_period_gap',abs(firstPoint.period-secondPoint.period), ...
            'absolute_reflected_drift_gap',abs(firstPoint.drift+secondPoint.drift), ...
            'trajectory',compareTrajectory(firstPoint,secondPoint,true), ...
            'exact_isotropy_or_ancestry_established',false);
        if isempty(reflectionPairs),reflectionPairs=item;else,reflectionPairs(end+1)=item;end %#ok<AGROW>
    end
    reflectionAudit=checkReflection();
    assert(max([reflectionAudit.flow_equivariance_error,reflectionAudit.guard_equivariance_error, ...
        reflectionAudit.reset_equivariance_error,reflectionAudit.energy_invariance_error])<1e-8, ...
        'The proposed model reflection failed its independent flow/guard/reset/energy check.');
    standingPhasePairs=struct([]);
    for firstGroup=1:numel(groups)
        for secondGroup=1:numel(groups)
            for firstIndex=1:numel(groups(firstGroup).points)
                pa=groups(firstGroup).points(firstIndex);if ~(pa.marked_TD_angle>0),continue;end
                for secondIndex=1:numel(groups(secondGroup).points)
                    pb=groups(secondGroup).points(secondIndex);if ~(pb.marked_TD_angle<0),continue;end
                    if pa.resonance_index~=pb.resonance_index||abs(pa.marked_TD_angle+pb.marked_TD_angle)>1e-12,continue;end
                    wave=compareTrajectory(pa,pb,false);
                    item=struct('first_group',groups(firstGroup).id,'second_group',groups(secondGroup).id, ...
                        'first_point',pointSummary(pa),'second_point',pointSummary(pb), ...
                        'resonance_index',pa.resonance_index,'absolute_TD_angle',abs(pa.marked_TD_angle), ...
                        'leg_permutation_applied',false,'horizontal_reflection_applied',false, ...
                        'expected_phase_shift',.5,'actual_trajectory_comparison',wave, ...
                        'energy_gap',abs(pa.energy-pb.energy),'period_gap',abs(pa.period-pb.period), ...
                        'scope','Opposite signs at fixed n and magnitude are proved marked half-period phases; saved actual trajectories numerically check correspondence, not a new orbit or family.');
                    if isempty(standingPhasePairs),standingPhasePairs=item;else,standingPhasePairs(end+1)=item;end %#ok<AGROW>
                end
            end
        end
    end
    stamp=char(datetime('now','TimeZone','UTC','Format','yyyyMMdd''T''HHmmssSSS'));
    stem=['branch_comparison_',stamp];artifact=['Research_v3/next_round/theory/',stem];
    audit=struct('schema_version','physical-branch-comparison-v3-1','created_utc',stamp, ...
        'matlab_version',version,'options',options,'baseline_parameter',baseline, ...
        'helper_path','Research_v3/next_round/theory/MATLABCompareNextRoundBranches_v3.m', ...
        'helper_sha256',RoundSHA256_v3([mfilename('fullpath'),'.m']), ...
        'manifest',manifest,'skipped',skipped,'branch_summaries',summary, ...
        'comparisons',comparisons,'opposite_signed_reflection_pairs',reflectionPairs,'reflection_model_audit',reflectionAudit, ...
        'opposed_spread_half_period_pairs',standingPhasePairs,'elapsed_saved_data_postprocessing_seconds',toc(timer), ...
        'new_shooting_simulations',0,'ancestry_established',false,'closure_certification_performed',false, ...
        'scope',['Nearest sampled physical states and event-aware trajectory differences are numerical diagnostics. ', ...
            'Different energies exclude individual orbit identity, not ancestry. Finite endpoints are checkpoints, ', ...
            'and no sampled nearness establishes a connected branch. Reflection is restricted to exact baseline ', ...
            'parameters and numerically synchronized-pronk trajectories, with finite residuals retained.']);
    RoundSave_v3(fullfile(v3,[artifact,'.mat']),struct('audit',audit));
    compact=audit;
    for k=1:numel(compact.comparisons),compact.comparisons(k).trajectory=rmfield(compact.comparisons(k).trajectory, ...
            {'phase_samples','first_samples','second_samples','first_modes','second_modes'});end
    for k=1:numel(compact.opposite_signed_reflection_pairs),compact.opposite_signed_reflection_pairs(k).trajectory=rmfield(compact.opposite_signed_reflection_pairs(k).trajectory, ...
            {'phase_samples','first_samples','second_samples','first_modes','second_modes'});end
    for k=1:numel(compact.opposed_spread_half_period_pairs)
        compact.opposed_spread_half_period_pairs(k).actual_trajectory_comparison=rmfield( ...
            compact.opposed_spread_half_period_pairs(k).actual_trajectory_comparison, ...
            {'phase_samples','first_samples','second_samples','first_modes','second_modes'});
    end
    RoundJSON_v3(fullfile(v3,[artifact,'.json']),compact);
    RoundJSON_v3(fullfile(here,'branch_comparison_latest.json'),struct('mat_artifact',[artifact,'.mat'], ...
        'json_artifact',[artifact,'.json'],'created_utc',stamp,'branch_count',numel(groups), ...
        'pair_comparisons',numel(comparisons),'new_shooting_simulations',0));
    writeDocument(compact,[artifact,'.json']);
    fprintf('Compared %d accepted branch/sample groups, %d nearest-point pairs; no shooting. Snapshot %s\n',numel(groups),numel(comparisons),artifact);

    function readBranch(path,id,scope)
        [loaded,digest]=readStable(path,{'branch'});addManifest(path,'branch',digest);
        if ~isfield(loaded,'branch')||~isfield(loaded.branch,'points'),skip(path,'missing accepted point array');return;end
        points=loaded.branch.points;
        for index=1:numel(points)
            if isfield(points(index),'orbit')&&~isempty(points(index).orbit)
                addPoint(id,scope,points(index).orbit,path,index);
            end
        end
    end
    function readDaughter(path,id,scope,historical)
        [loaded,digest]=readStable(path,{'orbit','replayOrbit','entry'});addManifest(path,'signed daughter',digest);
        if ~isfield(loaded,'entry'),skip(path,'missing acceptance record');return;end
        entry=loaded.entry;admitted=false;
        if historical
            admitted=isfield(entry,'converged')&&entry.converged&&isfield(entry,'in_registered_domain')&&entry.in_registered_domain ...
                &&isfield(entry,'replay_full_closure')&&entry.replay_full_closure<=options.ClosureTolerance;
        elseif isfield(entry,'accepted'),admitted=entry.accepted;end
        if ~admitted,skip(path,'saved daughter was not accepted');return;end
        orbit=[];if isfield(loaded,'replayOrbit'),orbit=loaded.replayOrbit;end
        if isempty(orbit)&&isfield(loaded,'orbit'),orbit=loaded.orbit;end
        addPoint(id,scope,orbit,path,1);
    end
    function readServiceOrbit(path,id,scope)
        [loaded,digest]=readStable(path,{'solution','report','trial'});addManifest(path,'shared-service orbit',digest);
        if ~isfield(loaded,'trial')||~loaded.trial.accepted||~isfield(loaded,'solution') ...
                ||isempty(loaded.solution)||~loaded.report.accepted,skip(path,'service trial not independently admitted');return;end
        metadata=struct('marked_TD_angle',NaN,'resonance_index',NaN);
        if isfield(loaded.trial,'touchdown_angle'),metadata.marked_TD_angle=loaded.trial.touchdown_angle;metadata.resonance_index=0;end
        addPoint(id,scope,loaded.solution,path,1,metadata);
    end
    function readAccuracyCopy(path,id)
        [copyInput,copyDigest]=readStable(path,{'result','copiedRecord'});addManifest(path,'accuracy replacement and copied provenance',copyDigest);
        if ~isfield(copyInput,'result')||~copyInput.result.physically_accepted||~copyInput.result.domain_accepted ...
                ||~isfield(copyInput,'copiedRecord'),skip(path,'accuracy replacement was not admitted');return;end
        sourceFolder=fullfile(fullTasks,copyInput.result.source_task_id);
        for j=1:numel(copyInput.copiedRecord.amplitudes)
            entry=copyInput.copiedRecord.amplitudes(j);if ~entry.accepted,continue;end
            if strcmp(entry.artifact,copyInput.result.artifact),pointPath=fullfile(fileparts(path),entry.artifact);
            else,pointPath=fullfile(sourceFolder,entry.artifact);end
            assert(isfile(V3Path_v3(pointPath)),'Accuracy-copy entry lacks its explicitly resolved original/replacement artifact.');
            readDaughter(pointPath,id,'accuracy evidence copy of original amplitude set plus one replacement; duplicates are not new families/progress',false);
        end
    end
    function addPoint(id,scope,orbit,path,index,metadata)
        if nargin<6,metadata=struct('marked_TD_angle',NaN,'resonance_index',NaN);end
        if isempty(orbit)||isempty(orbit.poincare_state),skip(path,'missing physical orbit/closure state');return;end
        closure=norm(orbit.poincare_state(2:end)-orbit.initial_state(2:end),inf);
        if ~isfinite(closure)||closure>options.ClosureTolerance,skip(path,'saved full closure exceeds comparison admission threshold');return;end
        try,data=HybridCycleData_v3.unpack(orbit);catch exception,skip(path,exception.identifier);return;end
        p=orbit.parameter(:);exactBaseline=isequal(p,baseline);x=orbit.initial_state(:);x(1)=0;
        [~,first]=unique(data.time,'stable');[~,last]=unique(data.time,'last');rows=unique([first;last]);
        angles=data.state(rows,[7,9,11,13]);rates=data.state(rows,[8,10,12,14]);
        motion=max([abs(angles-angles(:,1)),abs(rates-rates(:,1)),abs(data.state(rows,[5,6]))],[],'all');
        disagreement=any(data.mode~=data.mode(:,1),2);dt=diff(data.time);
        contactResidual=sum(dt.*double(disagreement(1:end-1)))/data.period;
        reflectionEligible=exactBaseline&&motion<=options.SynchronizationTolerance&&contactResidual<=options.SynchronizationTolerance;
        history=data.history;ids=[history.guard_id];phases=([history.time]-data.start_time)/data.period;
        item=struct('artifact',relative(path),'point_index',index,'state',x,'mode',orbit.initial_mode(:),'parameter',p, ...
            'energy',QuadrupedEnergy_v3.evaluate(orbit.initial_state,orbit.initial_mode,p), ...
            'period',data.period,'drift',data.state(end,1)-data.state(1,1), ...
            'saved_full_closure',closure,'exact_baseline_parameter',exactBaseline, ...
            'marked_TD_angle',metadata.marked_TD_angle,'resonance_index',metadata.resonance_index, ...
            'synchronization_motion_residual',motion,'synchronization_contact_fraction',contactResidual, ...
            'reflection_eligible',reflectionEligible,'ids',ids,'phases',phases,'data',data);
        g=find(strcmp({groups.id},id),1);
        if isempty(g),groups(end+1)=struct('id',id,'scope',scope,'points',item); %#ok<AGROW>
        else,groups(g).points(end+1)=item;end
    end
    function addManifest(path,kind,digest)
        item=struct('artifact',relative(path),'sha256',digest,'kind',kind);
        if isempty(manifest),manifest=item;else,manifest(end+1)=item;end
    end
    function [loaded,digest]=readStable(path,names)
        for attempt=1:3
            before=RoundSHA256_v3(path);inventory=whos('-file',V3Path_v3(path));available=intersect(names,{inventory.name});
            loaded=load(V3Path_v3(path),available{:});digest=RoundSHA256_v3(path);
            if strcmp(before,digest),return;end
        end
        error('MATLABCompareNextRoundBranches_v3:MovingSnapshot', ...
            'The branch artifact changed during three consecutive snapshot reads: %s',relative(path));
    end
    function skip(path,reason)
        item=struct('artifact',relative(path),'reason',reason);
        if isempty(skipped),skipped=item;else,skipped(end+1)=item;end
    end
    function value=relative(path),value=strrep(path,[v3,filesep],'');end
    function [ia,ib,reflected,distance]=closest(a,b)
        distance=Inf;ia=1;ib=1;reflected=false;
        for j=1:numel(b)
            for i=1:numel(a)
                d=norm(a(i).state(2:end)-b(j).state(2:end),inf);
                if d<distance,distance=d;ia=i;ib=j;reflected=false;end
                if a(i).reflection_eligible&&b(j).reflection_eligible
                    rx=reflect(b(j).state);d=norm(a(i).state(2:end)-rx(2:end),inf);
                    if d<distance,distance=d;ia=i;ib=j;reflected=true;end
                end
            end
        end
    end
    function distances=endpointDistances(a,b)
        distances=zeros(2,2);indices={unique([1,numel(a)]),unique([1,numel(b)])};
        for side=1:2
            for endpoint=1:2
                if side==1,point=a(indices{1}(min(endpoint,numel(indices{1}))));[~,~,~,distance]=closest(point,b);
                else,point=b(indices{2}(min(endpoint,numel(indices{2}))));[~,~,~,distance]=closest(a,point);end
                distances(side,endpoint)=distance;
            end
        end
    end
    function item=pointSummary(point)
        item=rmfield(point,{'data'});
    end
    function wave=compareTrajectory(a,b,reflected)
        bIds=b.ids;if reflected,bIds=eventPermutation(bIds);end
        phaseCandidates=0;
        for contactIdentity=1:8
            ap=a.phases(a.ids==contactIdentity);bp=b.phases(bIds==contactIdentity);
            for av=ap,phaseCandidates=[phaseCandidates,mod(bp-av,1)];end %#ok<AGROW>
        end
        phaseCandidates=unique(phaseCandidates);best=Inf;
        for shift=phaseCandidates
            phase=unique([linspace(0,1,options.SampleCount).';a.phases(:);mod(b.phases(:)-shift,1)]);
            % Avoid comparing opposite reset sides merely because nearby
            % event phases differ below the declared phase resolution.
            interior=phase;
            events=[a.phases(:);mod(b.phases(:)-shift,1)];
            for ep=events.',interior(abs(CircularPhase_v3.difference(interior,ep))<=options.PhaseTolerance)=[];end
            interior=unique([0;interior;1]);
            [xa,qa]=lift(a,interior,0,false);[xb,qb]=lift(b,interior,shift,reflected);
            mismatch=max(abs(xa-xb),[],'all');
            if mismatch<best
                best=mismatch;chosen=shift;samplePhase=interior;sampleA=xa;sampleB=xb;modeA=qa;modeB=qb;
            end
        end
        countsA=arrayfun(@(id)sum(a.ids==id),1:8);countsB=arrayfun(@(id)sum(bIds==id),1:8);
        countMatch=isequal(countsA,countsB);eventPhaseGap=NaN;leftGap=NaN;rightGap=NaN;
        if countMatch
            eventPhaseGap=0;leftGap=0;rightGap=0;
            for contactIdentity=1:8
                ap=sort(a.phases(a.ids==contactIdentity));original=b.phases(bIds==contactIdentity);bp=mod(original-chosen,1);[bp,order]=sort(bp);original=original(order);
                if isempty(ap),continue;end
                distance=Inf;permutation=1:numel(bp);
                for turn=0:numel(bp)-1
                    perm=circshift(1:numel(bp),turn);trial=max(abs(CircularPhase_v3.difference(ap,bp(perm))));
                    if trial<distance,distance=trial;permutation=perm;end
                end
                eventPhaseGap=max(eventPhaseGap,distance);
                for side={'left','right'}
                    [xap,~]=lift(a,ap(:),0,false,side{1});
                    alignedPhase=mod(original(permutation)-chosen,1);
                    [xbp,~]=lift(b,alignedPhase(:),chosen,reflected,side{1});
                    gap=max(abs(xap-xbp),[],'all');
                    if strcmp(side{1},'left'),leftGap=max(leftGap,gap);else,rightGap=max(rightGap,gap);end
                end
            end
        end
        wave=struct('phase_shift_of_second',chosen,'searched_phase_candidates',numel(phaseCandidates), ...
            'phase_alignment_method','zero and all matching per-leg contact-phase differences', ...
            'interpolation','saved smooth-side linear interpolation with explicit left/right event values', ...
            'maximum_interior_state_mismatch',best,'maximum_interior_nontranslation_mismatch',max(abs(sampleA(:,2:end)-sampleB(:,2:end)),[],'all'), ...
            'interior_mode_mismatch_fraction',mean(any(modeA~=modeB,2)), ...
            'per_guard_contact_count_match',countMatch,'first_contact_counts',countsA,'second_contact_counts',countsB, ...
            'maximum_matched_event_phase_gap',eventPhaseGap, ...
            'maximum_matched_pre_event_state_mismatch',leftGap,'maximum_matched_post_event_state_mismatch',rightGap, ...
            'phase_samples',samplePhase,'first_samples',sampleA,'second_samples',sampleB,'first_modes',modeA,'second_modes',modeB, ...
            'finite_sampling_is_isotropy_proof',false,'different_energy_excludes_ancestry',false);
    end
    function [x,q]=lift(point,phase,shift,reflected,side)
        if nargin<5,side='right';end
        unwrapped=phase+shift;turns=floor(unwrapped);local=unwrapped-turns;
        % Keep phase1 at its actual terminal state when no phase rotation is
        % used, preserving the recorded post-return side.
        terminal=unwrapped>0&abs(local)<=eps(max(1,abs(unwrapped)));local(terminal)=1;turns(terminal)=turns(terminal)-1;
        [x,q]=HybridCycleData_v3.sample(point.data,point.data.start_time+local*point.period,side);
        x(:,1)=x(:,1)+turns*point.drift;
        [origin,~]=HybridCycleData_v3.sample(point.data,point.data.start_time+shift*point.period,'right');
        x(:,1)=x(:,1)-origin(1);
        if reflected,x=reflect(x.').';q=q(:,[3,4,1,2]);end
    end
    function y=reflect(x)
        y=x;y([1,2,5,6],:)=-x([1,2,5,6],:);
        y([7,8,9,10,11,12,13,14],:)=-x([11,12,13,14,7,8,9,10],:);
    end
    function out=eventPermutation(ids)
        schema=QuadrupedSchema_v3.shared();legPermutation=[3,4,1,2];permutation=zeros(1,schema.Event.Count);
        for event=schema.Event.IDs
            targetLeg=legPermutation(schema.Event.LegIndices(event));
            permutation(event)=find(schema.Event.LegIndices==targetLeg & ...
                schema.Event.IsTouchdown==schema.Event.IsTouchdown(event),1);
        end
        out=permutation(ids);
    end
    function result=checkReflection()
        flowError=0;guardError=0;resetError=0;energyError=0;sampleCount=0;system=Quadrupedal_Dynamics_v3();
        for g=1:numel(groups)
            candidates=find([groups(g).points.reflection_eligible],1);
            if isempty(candidates),continue;end
            point=groups(g).points(candidates);phase=linspace(0,1,13).';
            [x,q]=HybridCycleData_v3.sample(point.data,point.data.start_time+phase*point.period);
            for row=1:size(x,1)
                state=x(row,:).';mode=q(row,:).';rx=reflect(state);rq=mode([3,4,1,2]);
                f=system.flow(0,state,mode,baseline);rf=system.flow(0,rx,rq,baseline);
                flowError=max(flowError,norm(rf-reflect(f),inf));
                guards=system.guardFunctions(0,state,mode,baseline);rg=system.guardFunctions(0,rx,rq,baseline);
                guardError=max(guardError,max(abs([rg(eventPermutation(1:8)).value]-[guards.value])));
                energyError=max(energyError,abs(QuadrupedEnergy_v3.evaluate(state,mode,baseline)-QuadrupedEnergy_v3.evaluate(rx,rq,baseline)));
                for guardIndex=find([guards.enabled])
                    plus=system.reset(guardIndex,0,state,mode,baseline);rplus=system.reset(eventPermutation(guardIndex),0,rx,rq,baseline);
                    resetError=max(resetError,norm(rplus-reflect(plus),inf));
                end
                sampleCount=sampleCount+1;
            end
        end
        result=struct('baseline_parameter_required_exactly',true,'model_reflection_leg_permutation',[3,4,1,2], ...
            'sample_count',sampleCount,'flow_equivariance_error',flowError,'guard_equivariance_error',guardError, ...
            'reset_equivariance_error',resetError,'energy_invariance_error',energyError, ...
            'numerical_check_replaces_algebraic_proof',false);
    end
    function writeDocument(value,jsonArtifact)
        path=fullfile(v3,'Docs_v3','Next_Round_Branch_Comparison_v3.md');fid=fopen(V3Path_v3(path),'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
        fprintf(fid,'# Physical branch and trajectory comparisons\n\n');
        fprintf(fid,'This MATLAB snapshot reads all accepted points in the available full-task branches, corrected daughters and labeled historical/validation references. No new shooting or closure certification is performed. Endpoints are finite checkpoints. [Versioned numerical evidence](../%s).\n\n',jsonArtifact);
        fprintf(fid,'At the exact baseline parameters, horizontal reflection changes `(x,dx,phi,dphi,alpha,beta)` signs and exchanges hind/front legs `[3,4,1,2]`. In the synchronized-pronk restriction the leg exchange is redundant; common guards remain common. With pitch zero, compression depends on `y/cos(alpha)`, horizontal force is odd, vertical force even, and common stance rate `−(v*cos(alpha)^2+dy*sin(alpha)*cos(alpha))/y` is odd. Swing rate/acceleration are odd at zero rest angle. Thus flow, guard/reset maps and energy commute with the reflection; `dy=0` and its crossing direction are unchanged. The common BL occurrence is preserved after whole-orbit reflection because all TDs coincide. This does not authorize arbitrary leg permutations or comparison at different physical parameters. [Flow](../1_Dynamic_Frameworks/Dynamics_v3/ContinuousDynamics_v3.m), [guards](../1_Dynamic_Frameworks/Dynamics_v3/GuardFunctions_v3.m), [reset](../1_Dynamic_Frameworks/Dynamics_v3/ResetMap_v3.m), [restricted analytic chart](Restricted_Odd_Quarter_PIP_Existence_v3.md).\n\n');
        fprintf(fid,'Saved finite synchronization residuals determine numerical eligibility; they do not prove exact isotropy. The reflection model check evaluated %d saved states: flow, guard, reset and energy errors %.3g, %.3g, %.3g and %.3g.\n\n',value.reflection_model_audit.sample_count,value.reflection_model_audit.flow_equivariance_error,value.reflection_model_audit.guard_equivariance_error,value.reflection_model_audit.reset_equivariance_error,value.reflection_model_audit.energy_invariance_error);
        fprintf(fid,'| First group | Second group | Closest apex distance | Energy gap | Period gap | Reflected drift gap | Interior trajectory mismatch | Matched post-event mismatch |\n|---|---|---:|---:|---:|---:|---:|---:|\n');
        for reportIndex=1:numel(value.comparisons)
            pair=value.comparisons(reportIndex);fprintf(fid,'| `%s` | `%s` | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |\n',pair.first_group,pair.second_group,pair.closest_physical_apex_state_distance,pair.absolute_energy_gap,pair.absolute_period_gap,pair.absolute_reflected_drift_gap,pair.trajectory.maximum_interior_state_mismatch,pair.trajectory.maximum_matched_post_event_state_mismatch);
        end
        fprintf(fid,'\nOpposite signed representatives within a group were also compared after the same allowed reflection. These sampled agreements check actual trajectories; they are not exact isotropy proofs.\n\n');
        fprintf(fid,'| Group | Reflected apex distance | Energy gap | Period gap | Reflected drift gap | Interior mismatch | Matched post-event mismatch |\n|---|---:|---:|---:|---:|---:|---:|\n');
        for reportIndex=1:numel(value.opposite_signed_reflection_pairs)
            pair=value.opposite_signed_reflection_pairs(reportIndex);fprintf(fid,'| `%s` | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |\n',pair.group,pair.reflected_apex_state_distance,pair.absolute_energy_gap,pair.absolute_period_gap,pair.absolute_reflected_drift_gap,pair.trajectory.maximum_interior_state_mismatch,pair.trajectory.maximum_matched_post_event_state_mismatch);
        end
        fprintf(fid,'\nThe nearest search removes only constant horizontal translation and optionally applies the stated reflection. Trajectory phase candidates come from matching physical contact events; interpolation remains on recorded smooth sides and explicitly compares both sides of each matched event. Gaps below the phase resolution are excluded from the interior grid and retained separately as matched-event phase gaps. All states and differences use the model nondimensional coordinates with unit component scales. Sampling/interpolation differences are numerical diagnostics without validated error bounds. Distinct energies exclude identity of individual conservative orbits after reflection/rephasing, but do not establish or exclude a connecting branch. Equal gait names and small sampled distances establish no ancestry.\n');
        fprintf(fid,'\nOpposed-spread signed records are separately checked under their proved half-period time-phase relation with unchanged leg labels. Accuracy-copy groups explicitly resolve original amplitude files under their source task, retaining only the replacement in the accuracy task; copied records are not new families or continuation progress. Bridge groups contain freshly admitted source evidence and actual accepted increments, whose local connection/identity gate remains separate.\n\n');
        fprintf(fid,'| Opposed-spread first group | Second group | Absolute TD angle | Measured phase shift | Energy gap | Period gap | Interior mismatch | Matched post-event mismatch |\n|---|---|---:|---:|---:|---:|---:|---:|\n');
        for reportIndex=1:numel(value.opposed_spread_half_period_pairs)
            pair=value.opposed_spread_half_period_pairs(reportIndex);wave=pair.actual_trajectory_comparison;
            fprintf(fid,'| `%s` | `%s` | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |\n',pair.first_group,pair.second_group,pair.absolute_TD_angle,wave.phase_shift_of_second,pair.energy_gap,pair.period_gap,wave.maximum_interior_state_mismatch,wave.maximum_matched_post_event_state_mismatch);
        end
    end
end
function [taskId,fileId]=recordedTaskIdentity(item)
% A relocated flat branch still belongs to its original continuation task.
    v3=V3Root_v3();current=fullfile(item.folder,item.name);
    map=jsondecode(fileread(fullfile(v3,'Audits_v3','Folder_Organization','locations.json')));
    recorded=current;
    for k=1:numel(map.files)
        if strcmp(current,fullfile(v3,map.files(k).new_path))
            recorded=fullfile(v3,map.files(k).old_path);break;
        end
    end
    [folder,fileId]=fileparts(recorded);[~,taskId,extension]=fileparts(folder);taskId=[taskId,extension];
end
function value=defaults(value,base)
    for name=fieldnames(value).',assert(isfield(base,name{1}),'Unknown comparison option.');end
    for name=fieldnames(base).',if ~isfield(value,name{1}),value.(name{1})=base.(name{1});end;end
end
