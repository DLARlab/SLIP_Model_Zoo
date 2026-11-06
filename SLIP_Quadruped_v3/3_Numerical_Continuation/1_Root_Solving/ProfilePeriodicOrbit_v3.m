function result=ProfilePeriodicOrbit_v3(orbit,report,options)
%PROFILEPERIODICORBIT_V3 Profile an existing native orbit; never solve a root.
% One profiled and one unprofiled map/classifier call retain exact settings.
% This is timing/diagnostic evidence, not another admission or branch edge.
    assert(isa(orbit,'HybridOrbit_v3')&&isscalar(orbit)&&isstruct(report)&&isscalar(report) ...
        &&isequal(report.accepted,true),'ProfilePeriodicOrbit:Input','Use an existing native admitted orbit/report.');
    assert(isstruct(options)&&isscalar(options)&&all(isfield(options,{'Budget','MaxWallSeconds'})), ...
        'ProfilePeriodicOrbit:Options','Supply an absolute budget and bounded local duration.');
    assert(isnumeric(options.MaxWallSeconds)&&isscalar(options.MaxWallSeconds) ...
        &&isfinite(options.MaxWallSeconds)&&options.MaxWallSeconds>0, ...
        'ProfilePeriodicOrbit:Options','MaxWallSeconds must be finite and positive.');
    clock=tic;budget=options.Budget;u=nowUnix();m=nano();
    finish=struct('deadline_unix_seconds',min(budget.research_deadline_unix_seconds,u+options.MaxWallSeconds), ...
        'deadline_monotonic_ns',min(budget.research_deadline_monotonic_ns,m+options.MaxWallSeconds*1e9));
    assert(left(finish)>120,'ProfilePeriodicOrbit:Fit','The complete bounded diagnostic must fit.');
    [policy,evidence]=RecordedReturnPolicy_v3(report);
    assert(evidence.complete,'ProfilePeriodicOrbit:Policy','Preserve the complete recorded policy.');
    sourceMap=report.options.Residual.Map;
    assert(isa(sourceMap,'PoincareMap_v3')&&isscalar(sourceMap), ...
        'ProfilePeriodicOrbit:Map','Require the recorded delegated map for this diagnostic.');
    mapOptions=struct();
    for key={'MaxReturnTime','MaxCycleEvents','MaxSectionCrossings','ArmTolerance','InitialTime'}
        mapOptions.(key{1})=sourceMap.(key{1});
    end
    integration=report.integration;
    integration.ODEOptions=odeset(integration.ODEOptions,'OutputFcn',@(~,~,~)double(left(finish)<=0));
    a=report.acceptance;
    classificationOptions=struct('PrimitiveOptions',struct('MaxCover',a.MaxCover, ...
        'StateTolerance',a.PrimitiveStateTolerance,'EventPhaseTolerance',a.PrimitiveEventTolerance));
    original=projection(orbit);result=struct('schema','periodic-orbit-profile-v1', ...
        'native_id',OrbitContentIdentity_v3(orbit),'integration',integration, ...
        'policy_configuration',evidence.configuration,'map_options',mapOptions, ...
        'classification_options',classificationOptions, ...
        'map',{{}},'classification',{{}},'completed',false,'source_unchanged',false, ...
        'root_calls',0,'fresh_admission_claimed',false,'failure',struct());
    cleaner=onCleanup(@()profile('off')); %#ok<NASGU>
    try
        for pass=1:2
            assert(left(finish)>60,'ProfilePeriodicOrbit:Fit','A complete diagnostic call must still fit.');
            descriptor=struct('diagnostic_kind','runtime-object-descriptor', ...
                'source_class',evidence.configuration.source_class,'settings',evidence.configuration.settings);
            [callPolicy,restored]=RecordedReturnPolicy_v3(struct('correction_return_policy',descriptor));
            assert(restored.complete&&isequaln(restored.configuration,evidence.configuration), ...
                'ProfilePeriodicOrbit:Policy','Each fresh map must preserve every recorded policy setting.');
            map=PoincareMap_v3(Quadrupedal_Dynamics_v3(), ...
                sourceMap.Section,HybridSimulator_v3(integration),callPolicy,mapOptions);
            if pass==1,profile('clear');profile('on');end
            fprintf('PERIODIC_PROFILE_MAP_BEGIN pass=%d\n',pass);call=tic;
            [next,info]=map.evaluate(orbit.initial_state,orbit.initial_mode,orbit.parameter);
            seconds=toc(call);
            stats=struct();if pass==1,profile('off');stats=profile('info');end
            delta=next-orbit.initial_state;delta(1)=0;
            [science,omitted]=mapScience(info);
            output=struct('next_state',next,'info',science);
            outputDigest=C1ScientificDigest_v3(output);
            result.map{pass,1}=struct('profiled',pass==1,'seconds',seconds, ...
                'full13_inf',norm(delta(2:end),Inf),'next_state',next,'profile',stats, ...
                'event_signature',info.section_relative_event_signature, ...
                'output',output,'output_typed_digest',outputDigest, ...
                'omitted_map_info_fields',{omitted}, ...
                'parity_scope','Complete declared scientific projection; runtime policy context and auxiliary construction diagnostics are not compared.');
            if pass==2
                assert(strcmp(outputDigest,result.map{1}.output_typed_digest), ...
                    'ProfilePeriodicOrbit:MapParity','Profiled and unprofiled scientific map outputs differ.');
            end
            fprintf('PERIODIC_PROFILE_MAP_RETURN pass=%d seconds=%.9g full13=%.9g\n',pass,seconds,norm(delta(2:end),Inf));
            assert(left(finish)>0,'ProfilePeriodicOrbit:Late','Map returned after the original diagnostic finish.');
        end
        for pass=1:2
            assert(left(finish)>60,'ProfilePeriodicOrbit:Fit','A complete classifier call must still fit.');
            if pass==1,profile('clear');profile('on');end
            fprintf('PERIODIC_PROFILE_CLASSIFIER_BEGIN pass=%d\n',pass);call=tic;
            classification=GaitIdentification_v3(orbit,classificationOptions);
            seconds=toc(call);
            stats=struct();if pass==1,profile('off');stats=profile('info');end
            digest=C1ScientificDigest_v3(classification);
            expected=C1ScientificDigest_v3(report.classification);
            result.classification{pass,1}=struct('profiled',pass==1,'seconds',seconds, ...
                'typed_digest',digest,'stored_output_typed_equal',strcmp(digest,expected),'profile',stats);
            result.classification{pass}.output=classification;
            fprintf('PERIODIC_PROFILE_CLASSIFIER_RETURN pass=%d seconds=%.9g typed_equal=%d\n',pass,seconds,strcmp(digest,expected));
            assert(strcmp(digest,expected),'ProfilePeriodicOrbit:ClassifierParity','The same stored orbit/options must retain the classifier output.');
            assert(left(finish)>0,'ProfilePeriodicOrbit:Late','Classifier returned after the original diagnostic finish.');
        end
        assert(strcmp(C1ScientificDigest_v3(original),C1ScientificDigest_v3(projection(orbit))), ...
            'ProfilePeriodicOrbit:Mutation','Profiling must not change the supplied native orbit.');
        result.source_unchanged=true;result.completed=true;
    catch problem
        profile('off');result.failure=struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack);
    end
    result.elapsed_seconds=toc(clock);
    result.integration.ODEOptions.OutputFcn=[];
end
function out=projection(orbit)
    out=plain(orbit);
end
function [out,omitted]=mapScience(info)
    keys={'period','accepted_period','return_multiplicity','initial_time','return_time', ...
        'initial_state','raw_return_state','poincare_state','initial_mode','final_mode', ...
        'discrete_closed','trajectory','event_history','event_sequence','event_times','mode_sequence', ...
        'minimum_stance_admissibility_margin','minimum_physical_margins','minimum_physical_margin', ...
        'section_return_admissibility','initial_section_admissibility','stance_force_admissibility_margin', ...
        'stride_displacement','canonical_displacement','return_policy','return_policy_name', ...
        'return_policy_was_explicit','candidate_section_count','accepted_crossing_index', ...
        'section_relative_event_signature','cyclic_event_signature','cyclically_canonical_event_signature', ...
        'event_cluster_report','event_clusters','event_cluster_count','event_cluster_signature', ...
        'cyclic_event_cluster_signature','event_cluster_members','event_cluster_names', ...
        'event_cluster_center_times','maximum_intra_cluster_spread','minimum_intercluster_gap', ...
        'cluster_relative_phase','section_cluster_coincidence','section_coincident_cluster_indices', ...
        'event_cluster_split_merge_diagnostics','section_coincident_events','section_chart', ...
        'event_counts_per_leg','guard_transversality_margins','minimum_guard_transversality', ...
        'section_transversality','success','valid','admissible','integration_success', ...
        'return_policy_accepted','cycle_complete'};
    assert(all(isfield(info,keys)),'ProfilePeriodicOrbit:MapEvidence','Required scientific map evidence is missing.');
    out=struct();for k=1:numel(keys),out.(keys{k})=plain(info.(keys{k}));end
    omitted=setdiff(fieldnames(info),keys(:),'stable');
end
function out=plain(value)
    if isa(value,'HybridOrbit_v3')||isa(value,'Trajectory_v3')
        assert(isscalar(value),'ProfilePeriodicOrbit:Projection','Only scalar native evidence objects are supported.');
        keys=properties(value);p=struct();
        for k=1:numel(keys),p.(keys{k})=plain(value.(keys{k}));end
        out=struct('source_class',class(value),'properties',p);
    elseif isstruct(value)
        out=value;keys=fieldnames(value);
        for k=1:numel(value)
            for j=1:numel(keys),out(k).(keys{j})=plain(value(k).(keys{j}));end
        end
    elseif iscell(value)
        out=value;for k=1:numel(value),out{k}=plain(value{k});end
    else
        assert(isnumeric(value)||islogical(value)||ischar(value)||isstring(value), ...
            'ProfilePeriodicOrbit:Projection','Unsupported runtime evidence class %s.',class(value));
        out=value;
    end
end
function value=left(v),value=min(v.deadline_unix_seconds-nowUnix(),(v.deadline_monotonic_ns-nano())/1e9);end
function value=nowUnix(),value=posixtime(datetime('now','TimeZone','UTC'));end
function value=nano(),value=double(java.lang.System.nanoTime());end
