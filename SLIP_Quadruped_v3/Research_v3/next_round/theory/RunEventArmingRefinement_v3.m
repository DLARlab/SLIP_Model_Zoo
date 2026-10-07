function report=RunEventArmingRefinement_v3()
%RUNEVENTARMINGREFINEMENT_V3 Execute short-phase and physical event audits.
    here=fileparts(mfilename('fullpath'));
    v3=fileparts(fileparts(fileparts(here)));
    paths={'Schema_v3','Adapters_v3','Dynamics_v3','Simulation_v3','Orbit_v3'};
    for k=1:numel(paths),V3LegacyAddPath_v3(fullfile(v3,paths{k}));end
    report=struct('schema_version','event-arming-refinement-v3-1', ...
        'matlab_version',version,'created_utc',char(datetime('now','TimeZone','UTC')), ...
        'physical_closure_acceptance',1e-8,'physical_period_refinement_tolerance',1e-7);
    shortCases=cell(12,1);index=0;
    for duration=[1e-3,1e-4]
        for arming=[1e-9,1e-11]
            for subdivision=[4,16,64]
                index=index+1;
                detector=EventDetector_v3(struct('RelTol',1e-12,'AbsTol',1e-15, ...
                    'MaxStep',duration/subdivision,'ArmingTolerance',arming, ...
                    'EventValueTolerance',1e-12,'SimultaneousTimeTolerance',1e-10, ...
                    'EventTimeTolerance',1e-12));
                [segment,event]=detector.integrate(ArmingAuditSystem_v3(duration), ...
                    0,false,[],[0,2*duration],[],odeset());
                assert(event.occurred&&event.time>0,'Positive duration return was lost.');
                assert(numel(event.guard_batch)==1,'Unexpected physical event batch.');
                assert(abs(event.time-duration)<1e-9,'Synthetic physical root is inaccurate.');
                assert(all(diff(segment.time)>=0)&&max(segment.time)<=event.time, ...
                    'Chronological selected-root truncation failed.');
                shortCases{index}=struct('duration',duration,'arming_tolerance',arming, ...
                    'MaxStep',duration/subdivision,'event_time',event.time, ...
                    'root_error',abs(event.time-duration), ...
                    'arming_restart_count',segment.arming_restart_count, ...
                    'physical_event_count',numel(event.guard_batch), ...
                    'effective_options',segment.integration_settings);
            end
        end
    end
    report.short_phase_cases=vertcat(shortCases{:});
    schema=QuadrupedSchema_v3.shared();
    fixture=load(V3Path_v3(fullfile(v3,'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits', ...
        'SourceFixtures_v3','PK_20_2.mat')),'results');
    old=fixture.results(:,1);pk=zeros(14,1);
    pk(schema.Root.UnknownIndices)=LegacyStateAdapter_v3.toV3Unknown(old(1:13));
    parameters=LegacyParameterAdapter_v3.toV3(old(23:29),'v2-exact');
    pip=zeros(14,1);pip(3)=1.5551652516426646;
    seeds={pip,pk};names={'PIP','imported_PK'};
    relative=[1e-9,1e-11,1e-12];absolute=[1e-11,1e-13,1e-14];
    step=[.03,.01,.003];arming=[1e-9,1e-10,1e-11];
    physical=cell(6,1);index=0;reference=cell(2,1);
    for target=1:2
        for refinement=1:3
            settings=struct('RelTol',relative(refinement),'AbsTol',absolute(refinement), ...
                'MaxStep',step(refinement),'ArmingTolerance',arming(refinement));
            simulator=HybridSimulator_v3(settings);
            map=PoincareMap_v3(Quadrupedal_Dynamics_v3(),PoincareSection_v3.apex(4), ...
                simulator,BLMarkedApexReturnPolicy_v3(),struct('MaxReturnTime',10));
            x=seeds{target};q=false(4,1);
            [next,info]=map.evaluate(x,q,parameters);
            closure=norm(next(2:end)-x(2:end),inf);
            history=info.event_history;
            physicalEvents=history(~[history.is_stop]);
            signature=char(info.section_relative_event_signature);
            if refinement==1
                reference{target}=struct('period',info.period,'signature',signature, ...
                    'next',next,'event_times',[physicalEvents.time]);
            end
            ref=reference{target};
            energy=zeros(size(info.trajectory.state,1),1);
            constraints=energy;
            for k=1:numel(energy)
                state=info.trajectory.state(k,:).';mode=info.trajectory.mode(k,:).';
                energy(k)=QuadrupedEnergy_v3.evaluate(state,mode,parameters);
                chartReport=QuadrupedPhysicalChart_v3.report(state,mode,parameters);
                constraints(k)=chartReport.maximum_constraint_residual;
            end
            item=struct('target',names{target},'refinement',refinement, ...
                'settings',settings,'full_closure',closure,'period',info.period, ...
                'discrete_closed',info.discrete_closed,'signature',signature, ...
                'same_signature',strcmp(signature,ref.signature), ...
                'physical_event_count',numel(physicalEvents), ...
                'positive_first_event_time',min([physicalEvents.time])>0, ...
                'period_change_from_baseline',abs(info.period-ref.period), ...
                'state_change_from_baseline',norm(next-ref.next,inf), ...
                'energy_range',max(energy)-min(energy), ...
                'max_stance_constraint',max(constraints), ...
                'chronological',all(diff(info.trajectory.time)>=0));
            assert(closure<report.physical_closure_acceptance&&item.discrete_closed, ...
                'Physical replay failed fixed acceptance.');
            assert(item.same_signature&&item.physical_event_count==8&& ...
                item.positive_first_event_time&&item.chronological, ...
                'Physical event ownership/refinement failed.');
            assert(item.period_change_from_baseline<report.physical_period_refinement_tolerance);
            index=index+1;physical{index}=item;
            save(V3Path_v3(fullfile(here,sprintf('arming_%s_%02d.mat',names{target},refinement))), ...
                'info','item','x','q','parameters','-v7');
            fprintf('%s refinement %d closure %.3g period %.12g eventcount %d\n', ...
                names{target},refinement,closure,info.period,item.physical_event_count);
        end
    end
    report.physical_cases=vertcat(physical{:});
    report.passed=true;report.max_physical_closure=max([report.physical_cases.full_closure]);
    report.max_short_phase_root_error=max([report.short_phase_cases.root_error]);
    save(V3Path_v3(fullfile(here,'event_arming_refinement.mat')),'report','-v7');
    fid=fopen(V3Path_v3(fullfile(here,'event_arming_refinement.json')),'w');assert(fid>=0);
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
end
