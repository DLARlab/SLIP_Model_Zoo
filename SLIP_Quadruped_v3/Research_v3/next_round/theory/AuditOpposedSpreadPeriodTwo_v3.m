function audit=AuditOpposedSpreadPeriodTwo_v3()
%AUDITOPPOSEDSPREADPERIODTWO_V3 Actual full-model checks of a restricted proof.
% No shooting correction is attempted. Signed exact predictors, FD matrices,
% crossings, resets, energy, labeled primitivity and descriptive gait are
% checked without changing numerical engines or shared campaign artifacts.
    here=fileparts(mfilename('fullpath'));v3=fileparts(fileparts(fileparts(here)));
    for folder={'Schema_v3','Dynamics_v3','Simulation_v3','Orbit_v3','Numerics_v3','Research_v3/Drivers_v3'}
        V3LegacyAddPath_v3(fullfile(v3,folder{1}));
    end
    loaded=load(V3Path_v3(fullfile(here,'opposed_spread_period_two_candidates.mat')),'catalog');
    catalog=loaded.catalog;registration=catalog.registration;
    assert(V3HashMatches_v3(registration.audit_source_sha256, fullfile(v3,registration.audit_source_path)), ...
        'The audit source differs from the prospective registration.');
    for k=1:numel(registration.engine_hashes)
        item=registration.engine_hashes(k);
        assert(V3HashMatches_v3(item.sha256, fullfile(v3,item.path)), ...
            'An engine source changed after registration: %s.',item.path);
    end
    timer=tic;system=Quadrupedal_Dynamics_v3();p=registration.physical_parameter;
    settings=registration.settings;
    map1=PoincareMap_v3(system,PoincareSection_v3.apex(4),HybridSimulator_v3(settings), ...
        BLMarkedApexReturnPolicy_v3(),struct('MaxReturnTime',20));
    map2=PoincareMap_v3(system,PoincareSection_v3.apex(4),HybridSimulator_v3(settings), ...
        BLMarkedApexReturnPolicy_v3(struct('BLTouchdownsPerReturn',2)),struct('MaxReturnTime',20));
    audit=struct('schema_version','executed-opposed-side-spread-period-two-audit-v3-1', ...
        'created_utc',char(datetime('now','TimeZone','UTC')),'matlab_version',version, ...
        'registration',registration,'direct_invariance',localDirectInvariance(system,p), ...
        'parent_cases',struct([]),'predictor_cases',struct([]),'passed',false,'completed',false, ...
        'map_evaluations',0,'elapsed_seconds',0,'error_identifier','','error_message','', ...
        'interpretation','Exact predictor replay and finite-difference evidence in an analytic restricted model; not nonlinear correction, interval certification, unrestricted C2, a target-family attachment or full stability.');
    try
        for n=registration.resonance_indices
            w=sqrt(20);t=(2*n+1)*pi/(2*w);energy=1+t^2/2;
            F=[cos(w*t),sin(w*t)/w;-w*sin(w*t),cos(w*t)];
            matrix=F*[1;-t]*[1,0]*F;
            measured=zeros(2,2,2);
            for refinement=1:2
                h=registration.fd_steps(refinement);
                for column=1:2
                    direction=zeros(2,1);direction(column)=h;
                    localDeadline(timer,registration.maximum_audit_wall_seconds);
                    xp=map1.evaluate(localLift(energy,direction),false(4,1),p);audit.map_evaluations=audit.map_evaluations+1;
                    localDeadline(timer,registration.maximum_audit_wall_seconds);
                    xm=map1.evaluate(localLift(energy,-direction),false(4,1),p);audit.map_evaluations=audit.map_evaluations+1;
                    measured(:,column,refinement)=(xp([7,8])-xm([7,8]))/(2*h);
                end
            end
            v=[t/20;1];v=v/norm(v);projected=zeros(1,2);
            delta=registration.slope_energy_step;h=registration.slope_direction_step;
            for signIndex=1:2
                signed=[-1,1];sampleEnergy=energy+signed(signIndex)*delta;
                localDeadline(timer,registration.maximum_audit_wall_seconds);
                xp=map1.evaluate(localLift(sampleEnergy,h*v),false(4,1),p);audit.map_evaluations=audit.map_evaluations+1;
                localDeadline(timer,registration.maximum_audit_wall_seconds);
                xm=map1.evaluate(localLift(sampleEnergy,-h*v),false(4,1),p);audit.map_evaluations=audit.map_evaluations+1;
                derivative=(xp([7,8])-xm([7,8]))/(2*h);
                projected(signIndex)=derivative(2)/v(2);
            end
            entry=struct('n',n,'parent_energy',energy,'flight_time',t,'predicted_matrix',matrix, ...
                'measured_matrices',measured,'matrix_error',norm(measured(:,:,2)-matrix,inf), ...
                'refinement_difference',norm(measured(:,:,2)-measured(:,:,1),inf), ...
                'predicted_nonzero_multiplier',-1,'predicted_energy_slope',2, ...
                'measured_projected_energy_slope',diff(projected)/(2*delta), ...
                'projected_crossing_values',projected,'kernel_direction',v, ...
                'twisted_kernel_dimension',1,'twisted_cokernel_dimension',1);
            if isempty(audit.parent_cases),audit.parent_cases=entry;else,audit.parent_cases(end+1)=entry;end %#ok<AGROW>
            fprintf('Opposed spread n%d matrix error %.3g refinement %.3g crossing slope %.9g\n', ...
                n,entry.matrix_error,entry.refinement_difference,entry.measured_projected_energy_slope);
            selected=find([catalog.predictors.resonance_index]==n);
            for k=selected
                predictor=catalog.predictors(k);initial=predictor.state;
                localDeadline(timer,registration.maximum_audit_wall_seconds);
                [single,info1]=map1.evaluate(initial,predictor.mode,p);audit.map_evaluations=audit.map_evaluations+1;
                localDeadline(timer,registration.maximum_audit_wall_seconds);
                [double,info2]=map2.evaluate(initial,predictor.mode,p);audit.map_evaluations=audit.map_evaluations+1;
                opposite=localLift(predictor.energy,-[predictor.a;predictor.b]);
                orbit=localOrbit(initial,predictor.mode,p,double,info2);
                gait=GaitIdentification_v3(orbit);data=HybridCycleData_v3.unpack(orbit);
                energyError=0;invariance=0;modeLeak=false;
                selectedRows=unique(round(linspace(1,numel(data.time),101)));
                for row=selectedRows
                    state=data.state(row,:).';mode=data.mode(row,:).';
                    energyError=max(energyError,abs(QuadrupedEnergy_v3.evaluate(state,mode,p)-predictor.energy));
                    if all(mode==mode(1)),invariance=max(invariance,localManifoldLeak(state));end
                end
                % Mixed intermediate scalar reset rows are not smooth phases.
                for row=1:numel(data.time)-1
                    if data.time(row+1)>data.time(row)+data.time_tolerance
                        modeLeak=modeLeak||~all(data.mode(row,:)==data.mode(row,1));
                    end
                end
                physical=info2.event_history;physical=physical(~[physical.is_stop]);
                counts=arrayfun(@(id)sum([physical.guard_id]==id),system.Schema.Event.IDs);
                fullClosure=norm(double-initial,inf);oneReturnNonclosure=norm(single-initial,inf);
                item=struct('id',predictor.id,'n',n,'touchdown_angle',predictor.touchdown_angle, ...
                    'energy',predictor.energy,'state',initial,'restricted_unknown',predictor.restricted_unknown, ...
                    'BL1_twisted_full_state_residual',norm(single-opposite,inf), ...
                    'BL1_actual_nonclosure',oneReturnNonclosure,'BL2_full_closure',fullClosure, ...
                    'actual_period',info2.period,'actual_horizontal_drift',info2.raw_return_state(1)-initial(1), ...
                    'energy_error_at_recorded_knots',energyError,'smooth_invariance_leak',invariance, ...
                    'mixed_mode_smooth_phase',modeLeak,'actual_contact_counts_by_event_id',counts, ...
                    'actual_event_ids',[physical.guard_id],'actual_event_times',[physical.time], ...
                    'selected_next_BL_occurrence',info2.section_chart.selected_return_BL_occurrence, ...
                    'BL_touchdowns_per_return',info2.section_chart.BL_touchdowns_per_return, ...
                    'physical_admissible',info1.admissible&&info2.admissible, ...
                    'minimum_guard_transversality',info2.minimum_guard_transversality, ...
                    'minimum_stance_admissibility_margin',info2.minimum_stance_admissibility_margin, ...
                    'actual_flight_count',gait.flight_count,'actual_gait_label',char(gait.label), ...
                    'actual_gait_status',char(gait.status),'actual_gait_reason',char(gait.reason), ...
                    'primitive_status',char(gait.primitive.status),'primitive_cover_count',gait.primitive.cover_count, ...
                    'primitive_checked_cover_bound',gait.primitive.checked_cover_bound, ...
                    'contact_sync_errors',gait.contact_sync_errors,'motion_sync_errors',gait.motion_sync_errors, ...
                    'exact_predictor_replay_only',true,'accepted_Newton_steps',0, ...
                    'actual_trace_artifact',['Research_v3/next_round/theory/',predictor.id,'_actual_trace.mat']);
                item.passed=item.BL1_twisted_full_state_residual<registration.full_closure_tolerance ...
                    &&fullClosure<registration.full_closure_tolerance&&oneReturnNonclosure>1e-3 ...
                    &&energyError<registration.energy_tolerance&&invariance<1e-9&&~modeLeak ...
                    &&all(counts==2)&&numel(physical)==16&&item.selected_next_BL_occurrence==3 ...
                    &&item.physical_admissible&&gait.flight_count==2 ...
                    &&gait.primitive.status=="primitive_within_checked_bound"&&gait.primitive.cover_count==1;
                save(V3Path_v3(fullfile(v3,item.actual_trace_artifact)),'predictor','single','double','info1','info2','orbit','gait','item','-v7');
                if isempty(audit.predictor_cases),audit.predictor_cases=item;else,audit.predictor_cases(end+1)=item;end %#ok<AGROW>
                fprintf('%s closure %.3g twist %.3g energy %.3g flights %d primitive %s gait %s/%s pass %d\n', ...
                    predictor.id,fullClosure,item.BL1_twisted_full_state_residual,energyError, ...
                    gait.flight_count,gait.primitive.status,gait.label,gait.status,item.passed);
            end
        end
        audit.completed=true;
        audit.passed=audit.direct_invariance.passed&&numel(audit.predictor_cases)==4 ...
            &&all([audit.predictor_cases.passed]) ...
            &&max([audit.parent_cases.matrix_error])<registration.matrix_error_tolerance ...
            &&max([audit.parent_cases.refinement_difference])<registration.matrix_refinement_tolerance ...
            &&max(abs([audit.parent_cases.measured_projected_energy_slope]-2))<registration.slope_error_tolerance;
    catch exception
        audit.error_identifier=exception.identifier;audit.error_message=exception.message;
    end
    audit.elapsed_seconds=toc(timer);
    audit.engine_hashes_unchanged=true;
    for k=1:numel(registration.engine_hashes)
        item=registration.engine_hashes(k);
        audit.engine_hashes_unchanged=audit.engine_hashes_unchanged ...
            &&V3HashMatches_v3(item.sha256, fullfile(v3,item.path));
    end
    audit.passed=audit.passed&&audit.engine_hashes_unchanged;
    save(V3Path_v3(fullfile(here,'opposed_spread_period_two_audit.mat')),'audit','-v7');
    RoundJSON_v3(fullfile(here,'opposed_spread_period_two_audit.json'),audit);
    assert(audit.passed,'OpposedSpreadAudit:Failed','Audit failed or incomplete: %s %s',audit.error_identifier,audit.error_message);
end
function initial=localLift(energy,u)
    pattern=[1;-1;1;-1];initial=zeros(14,1);initial(3)=energy;
    initial([7,9,11,13])=u(1)*pattern;initial([8,10,12,14])=u(2)*pattern;
end
function leak=localManifoldLeak(state)
    pattern=[1;-1;1;-1];angles=state([7,9,11,13]);rates=state([8,10,12,14]);
    leak=max([abs(state([1,2,5,6]));abs(angles-angles(1)*pattern);abs(rates-rates(1)*pattern)]);
end
function orbit=localOrbit(initial,mode,p,next,info)
    names={'period','event_history','trajectory','stride_displacement','return_policy', ...
        'return_policy_name','return_multiplicity','section_chart','event_cluster_report', ...
        'minimum_guard_transversality','minimum_stance_admissibility_margin','cycle_completion_diagnostics'};
    values=struct('initial_state',initial,'initial_mode',mode,'parameter',p,'poincare_state',next);
    for k=1:numel(names),values.(names{k})=info.(names{k});end
    orbit=HybridOrbit_v3(values);
end
function localDeadline(timer,limit)
    assert(toc(timer)<limit-5,'OpposedSpreadAudit:TimeBudget','Registered standalone audit time limit reached.');
end
function result=localDirectInvariance(system,p)
    pattern=[1;-1;1;-1];A=.01;t=pi/(2*sqrt(20));
    x=localLift(1.5,[A;.013]);x(4)=.1;
    f=system.flow(0,x,false(4,1),p);flightError=localManifoldLeak(f);
    x=localLift(.9,[A;0]);x(4)=-.2;
    x([8,10,12,14])=(-x(4)*sin(A)*cos(A)/x(3))*pattern;
    f=system.flow(0,x,true(4,1),p);stanceError=localManifoldLeak(f);
    [~,energy]=QuadrupedEnergy_v3.evaluate(x,true(4,1),p);
    ids=system.Schema.Event.IDs;td=ids(system.Schema.Event.IsTouchdown);lo=ids(~system.Schema.Event.IsTouchdown);
    beforeTD=localLift(cos(A),[A;-t*sin(A)]);beforeTD(4)=-t;
    [afterTD,qTD]=system.resolveEventBatch(td,0,beforeTD,false(4,1),p);
    beforeLO=localLift(cos(A),[A;-t*sin(A)]);beforeLO(4)=t;
    [afterLO,qLO]=system.resolveEventBatch(lo,0,beforeLO,true(4,1),p);
    guardsTD=system.guardFunctions(0,afterTD,qTD,p);guardsLO=system.guardFunctions(0,beforeLO,true(4,1),p);
    tdLie=[guardsTD(td).directional_derivative];loLie=[guardsLO(lo).directional_derivative];
    expectedTD=t*sin(A)*pattern;expectedLO=-t*sin(A)*pattern;
    resetEnergy=max(abs([QuadrupedEnergy_v3.evaluate(afterTD,qTD,p)-QuadrupedEnergy_v3.evaluate(beforeTD,false(4,1),p), ...
        QuadrupedEnergy_v3.evaluate(afterLO,qLO,p)-QuadrupedEnergy_v3.evaluate(beforeLO,true(4,1),p)]));
    swap=[2,1,4,3];angles=[7,9,11,13];rates=[8,10,12,14];
    swapped=x;swapped(angles)=x(angles(swap));swapped(rates)=x(rates(swap));
    expectedFlow=f;expectedFlow(angles)=f(angles(swap));expectedFlow(rates)=f(rates(swap));
    sideSwapFlowError=norm(system.flow(0,swapped,true(4,1),p)-expectedFlow,inf);
    sideSwapEnergyError=abs(QuadrupedEnergy_v3.evaluate(swapped,true(4,1),p)-QuadrupedEnergy_v3.evaluate(x,true(4,1),p));
    result=struct('flight_flow_invariance_error',flightError,'stance_flow_invariance_error',stanceError, ...
        'stance_flow_energy_identity',abs(energy.conservation_identity_residual), ...
        'TD_reset_rate_formula_error',norm(afterTD([8,10,12,14])-expectedTD,inf), ...
        'LO_reset_rate_formula_error',norm(afterLO([8,10,12,14])-expectedLO,inf), ...
        'TD_postreset_Lie_derivatives',tdLie,'LO_prereset_Lie_derivatives',loLie, ...
        'expected_absolute_guard_derivative',t*cos(A)^2,'reset_energy_error',resetEnergy, ...
        'TD_mode_all_stance',all(qTD),'LO_mode_all_flight',~any(qLO), ...
        'side_swap_flow_error',sideSwapFlowError,'side_swap_energy_error',sideSwapEnergyError);
    result.passed=max([flightError,stanceError,result.stance_flow_energy_identity, ...
        result.TD_reset_rate_formula_error,result.LO_reset_rate_formula_error,resetEnergy, ...
        sideSwapFlowError,sideSwapEnergyError])<1e-12 ...
        &&all(tdLie<0)&&all(loLie>0)&&result.TD_mode_all_stance&&result.LO_mode_all_flight ...
        &&max(abs(tdLie+t*cos(A)^2))<1e-12&&max(abs(loLie-t*cos(A)^2))<1e-12;
end
