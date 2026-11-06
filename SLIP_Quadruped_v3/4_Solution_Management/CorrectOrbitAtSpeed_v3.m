function [orbit,report]=CorrectOrbitAtSpeed_v3(left,right,fraction,signedTarget,options)
%CORRECTORBITATSPEED_V3 Interpolate a predictor, correct and independently admit.
% Interpolation never constitutes a solution. E is a free orbit coordinate.
% Return selection is copied from the declared source policy, never chosen
% from a closure minimization, a flight count, or a publication filename.
    if nargin<5,options=struct();end
    defaults=struct('Symmetry','none','Integration',struct(),'ReplayIntegration',struct(), ...
        'SolverOptions',struct(),'Acceptance',struct(),'ResidualScale',[], ...
        'CoordinateScale',[],'SpeedTolerance',1e-8,'MaxWallSeconds',120, ...
        'DeadlineUnixSeconds',Inf,'DeadlineMonotonicNs',Inf,'Map',[],'AdmissionReports',{{}});
    options=merge(defaults,options);
    validateattributes(fraction,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
    validateattributes(options.SpeedTolerance,{'numeric'},{'scalar','real','finite','positive'});
    report=struct('accepted',false,'status','not_started','shared_service_report',struct(), ...
        'target_signed_velocity',signedTarget,'target_speed',abs(signedTarget), ...
        'achieved_speed',NaN,'speed_error',NaN,'signed_velocity_error',NaN, ...
        'predictor_fraction',fraction,'predictor_only',true,'classification',struct());orbit=[];
    if ~isequal(left.parameter(:),right.parameter(:))|| ...
            ~isequal(logical(left.initial_mode(:)),logical(right.initial_mode(:)))
        report.status='incompatible_predictor_charts';return
    end
    report.return_section_compatibility=MatchingReturnSection_v3(left,right,options.AdmissionReports);
    if ~report.return_section_compatibility.compatible
        report.status='incompatible_or_unverified_return_section_identity';return
    end
    timeRemaining=options.DeadlineUnixSeconds-posixtime(datetime('now','TimeZone','UTC'));
    monotonicRemaining=(options.DeadlineMonotonicNs-double(java.lang.System.nanoTime))/1e9;
    seconds=min([options.MaxWallSeconds,timeRemaining,monotonicRemaining]);
    if seconds<=0,report.status='budget_refusal';return;end
    if isfinite(monotonicRemaining)||isfinite(timeRemaining)
        % Shared service final independent returns follow the root solve.
        % Reserve time for those returns before launching another root.
        replayReserve=max(30,4*max(left.period,right.period));
        seconds=min(seconds,min(timeRemaining,monotonicRemaining)-replayReserve);
        if seconds<=0,report.status='budget_refusal_for_independent_replay';return;end
    end
    try
        map=options.Map;
        if isempty(map)
            [policy,policyEvidence]=RecordedReturnPolicy_v3(options.AdmissionReports{1});
            if ~policyEvidence.complete
                report.status='missing_actual_return_policy_configuration';return
            end
            map=PoincareMap_v3(Quadrupedal_Dynamics_v3(),PoincareSection_v3.apex(4), ...
                HybridSimulator_v3(options.Integration),policy, ...
                struct('MaxReturnTime',max(30,2*max(left.period,right.period)), ...
                'MaxCycleEvents',1000,'MaxSectionCrossings',64));
        elseif numel(options.AdmissionReports)==2
            mapReport=struct('seed',struct('return_policy',map.ReturnPolicy));
            mapIdentity=MatchingReturnSection_v3(left,left,{options.AdmissionReports{1},mapReport});
            if ~mapIdentity.compatible
                report.status='supplied_map_policy_configuration_mismatch';return
            end
        end
        base=PeriodicOrbitResidual_v3(map,left.initial_state);
        family=EnergyFamilyResidual_v3(base,left.initial_state,left.initial_mode,left.parameter, ...
            struct('Symmetry',options.Symmetry));
        u=(1-fraction)*family.packState(left.initial_state)+fraction*family.packState(right.initial_state);
        state=family.fullState(u);E=QuadrupedEnergy_v3.evaluate(state,left.initial_mode,left.parameter);
        residual=SpeedConstrainedEnergyResidual_v3(family,signedTarget,options.ResidualScale);
        occurrence=1;
        if isa(map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3')
            occurrence=map.ReturnPolicy.BLTouchdownsPerReturn;
        elseif isa(map.ReturnPolicy,'IteratedReturnPolicy_v3')
            occurrence=map.ReturnPolicy.Multiplicity;
        end
        seed=struct('state',state,'mode',left.initial_mode,'parameter',left.parameter, ...
            'return_policy',map.ReturnPolicy,'occurrence',occurrence, ...
            'provenance',struct('kind','equal-speed-level predictor','fraction',fraction, ...
            'signed_target',signedTarget,'interpolated_state_is_not_admitted',true));
        service=struct('Residual',residual,'Coordinates',[u;E], ...
            'AugmentedParameter',left.parameter(:),'MaxWallSeconds',seconds, ...
            'ReplayIntegration',options.ReplayIntegration,'SolverOptions',options.SolverOptions, ...
            'Acceptance',options.Acceptance,'CoordinateScale',options.CoordinateScale);
        [candidate,admission]=PeriodicSolutionSolver_v3(seed,service);
        report.shared_service_report=admission;report.status=admission.status;
        if ~admission.accepted||isempty(candidate),return;end
        primitive=admission.primitive;
        observable=OrbitSpeed_v3(candidate,primitive.primitive_period);
        report.achieved_speed=observable.speed;report.speed_error=observable.speed-abs(signedTarget);
        report.signed_velocity_error=observable.mean_signed_velocity-signedTarget;
        report.classification=admission.classification;
        if abs(report.speed_error)>options.SpeedTolerance|| ...
                abs(report.signed_velocity_error)>options.SpeedTolerance
            report.status='fresh_replay_speed_target_failed';return
        end
        orbit=candidate;report.accepted=true;report.status='accepted';report.predictor_only=false;
    catch exception
        report.status='speed_correction_exception';
        report.failure=struct('identifier',exception.identifier,'message',exception.message);
    end
end
function result=merge(defaults,supplied)
    if ~isstruct(supplied)||~isscalar(supplied)||any(~ismember(fieldnames(supplied),fieldnames(defaults)))
        error('CorrectOrbitAtSpeed_v3:Options','Unknown correction option.');
    end
    result=defaults;keys=fieldnames(supplied);
    for k=1:numel(keys),result.(keys{k})=supplied.(keys{k});end
end
