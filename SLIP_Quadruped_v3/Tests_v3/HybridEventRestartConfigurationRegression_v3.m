function report=HybridEventRestartConfigurationRegression_v3(requirePass)
%HYBRIDEVENTRESTARTCONFIGURATIONREGRESSION_V3 Opaque context policy binding.
% The exact same two linear trajectories use unchanged event tolerances in
% the producing detector. Changed consuming configurations must be rejected,
% rather than silently reinterpreting the producer's arming ownership.
    if nargin<1,requirePass=true;end
    validateattributes(requirePass,{'logical'},{'scalar'});
    system=HybridSystemBase_v3(struct('StateDimension',2,'ParameterDimension',2, ...
        'FlowFunction',@(~,~,~,p)-p,'ActiveGuardsFunction',@guards, ...
        'ResetFunction',@identityReset,'TransitionFunction',@consume));
    producer=EventDetector_v3();x=[1e-6;1.05e-8];q=false(2,1);p=[1;.01];
    [~,first,returned]=producer.integrate(system,x,q,p,[0,2e-6]);ids=[first.guard_batch.id];
    [after,mode]=system.resolveEventBatch(ids,first.time,first.state,q,p);
    ready=producer.prepareRestart(returned,after,mode,ids,{});
    equivalent=EventDetector_v3(producer.Options);
    [~,same]=equivalent.integrate(system,after,mode,p,[first.time,2e-6],[],odeset(),ready);
    [nestedSegment,nested]=equivalent.integrate(system,after,mode,p,[first.time,2e-6],[],odeset('MaxStep',1e-7),ready);
    sameControl=same.occurred&&isequal([same.guard_batch.id],2)&&abs(same.time-1.05e-6)<=2e-10;
    nestedControl=nested.occurred&&isequal([nested.guard_batch.id],2)&&abs(nested.time-1.05e-6)<=2e-10 ...
        &&isequal(nestedSegment.integration_settings.MaxStep,1e-7);
    names={'ODESolver';'RelTol';'AbsTol';'MaxStep';'EventValueTolerance';'EventTimeTolerance'; ...
        'SimultaneousTimeTolerance';'DirectionalDerivativeTolerance';'DerivativeStep';'ArmingTolerance';'InteriorBias'};
    values={@ode23;2e-9;2e-11;1e-7;2e-8;2e-10;2e-8;2e-10;2e-7;1e-6;2e-9};
    assert(isequal(sort(fieldnames(producer.Options)),sort(names)),'HybridEventRestartConfigurationRegression_v3:FieldScope');
    rows=cell(numel(names),1);
    for k=1:numel(names)
        changed=producer.Options;changed.(names{k})=values{k};consumer=EventDetector_v3(changed);
        checks={ ...
            rejection(@()consumer.prepareRestart(returned,after,mode,ids,{})); ...
            rejection(@()consumer.prepareContinuousRestart(returned,returned.state,returned.mode)); ...
            rejection(@()consumer.prepareSimulationRestart(ready,system,[],first.time,after,mode,p)); ...
            rejection(@()consumer.integrate(system,after,mode,p,[first.time,2e-6],[],odeset(),ready))};
        rows{k}=struct('changed_field',names{k},'prepare_physical_restart',checks{1}, ...
            'prepare_continuous_restart',checks{2},'prepare_simulation_restart',checks{3},'integrate_restore',checks{4}, ...
            'passed',all(cellfun(@(v)v.correctly_rejected,checks)));
    end
    changed=EventDetector_v3(struct('ArmingTolerance',1e-6));normalMismatch=false;mismatchTime=NaN;mismatchError='';
    try
        [~,mismatch]=changed.integrate(system,after,mode,p,[first.time,2e-6],[],odeset(),ready);
        normalMismatch=mismatch.occurred&&isequal([mismatch.guard_batch.id],2)&&abs(mismatch.time-1.05e-6)<=2e-10;
        mismatchTime=mismatch.time;
    catch exception,mismatchError=exception.identifier;end
    report=struct('schema','hybrid-event-restart-configuration-regression-v1','rows',{rows}, ...
        'passed',sameControl&&nestedControl&&all(cellfun(@(r)r.passed,rows))&&~normalMismatch&&strcmp(mismatchError,'EventDetector_v3:RestartBinding'), ...
        'same_detector_configuration_control',sameControl,'explicit_nested_ODEOptions_control',nestedControl, ...
        'producer_ArmingTolerance',producer.Options.ArmingTolerance,'changed_ArmingTolerance',1e-6, ...
        'mismatched_arming_restore_completed_normally',normalMismatch,'mismatched_arming_restore_time',mismatchTime, ...
        'mismatched_arming_restore_error',mismatchError,'restart_time',first.time,'guard_value_at_restart',after(2), ...
        'binding_scope','The exact normalized EventDetector.Options only; effective nested ODEOptions are explicit separate inputs and recorded integration settings. No full-profile or saved-orbit admission claim.');
    fprintf('HYBRID_RESTART_CONFIGURATION %s\n',jsonencode(report));
    if requirePass
        assert(report.passed,'HybridEventRestartConfigurationRegression_v3:RegressionFailure', ...
            'All eleven detector configuration fields must bind across every opaque-context lifecycle method.');
    end
end
function out=rejection(run)
    out=struct('correctly_rejected',false,'normal_return',false,'identifier','');
    try,run();out.normal_return=true;
    catch exception,out.identifier=exception.identifier;out.correctly_rejected=strcmp(exception.identifier,'EventDetector_v3:RestartBinding');end
end
function g=guards(~,x,q,~)
    prototype=struct('id',0,'name',"",'value',0,'direction',-1,'isterminal',true, ...
        'enabled',true,'interior_sign',1,'kind',"synthetic-contact",'metadata',struct());
    g=repmat(prototype,0,1);
    for id=find(~q(:)).'
        d=prototype;d.id=id;d.name="configuration_coordinate_"+id;d.value=x(id);
        d.metadata.restart_arming=struct('schema','state-parameter-guard-geometry-v1', ...
            'definition',sprintf('configuration-coordinate-%d-v1',id),'state_dependencies',id,'mode_independent',true);
        g(end+1,1)=d; %#ok<AGROW>
    end
end
function x=identityReset(~,~,x,~,~),end
function q=consume(id,q),q(id)=true;end
