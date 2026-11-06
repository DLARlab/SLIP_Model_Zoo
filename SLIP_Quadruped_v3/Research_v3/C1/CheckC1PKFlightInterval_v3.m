function result=CheckC1PKFlightInterval_v3(initialState,mode,parameter,duration,options)
%CHECKC1PKFLIGHTINTERVAL_V3 Conditional supplement for one literal raw flight.
% The caller owns the interval/event-history selection and endpoint evidence.
% PASS concerns this fixed smooth all-flight extension, not new admission.
% Arithmetic cushions are assumptions, not verified floating-point bounds.
required={'SwingPenetrationTolerance','ArithmeticCushion','DerivativeCushion', ...
    'CurvatureCushion','Limits','InitialEndpointKind','FinalEndpointKind', ...
    'EndpointTimeTolerance','ActualFinalState'};
assert(nargin==5&&isstruct(options)&&isscalar(options)&&all(isfield(options,required)), ...
    'C1Flight:Options','Supply actual tolerances, literal endpoint evidence and both parent clocks.');
o=struct('SwingPenetrationTolerance',[],'ArithmeticCushion',[],'DerivativeCushion',[], ...
    'CurvatureCushion',[],'Limits',struct(),'InitialEndpointKind','','FinalEndpointKind','', ...
    'EndpointTimeTolerance',[],'ActualFinalState',[],'MaxWallSeconds',30, ...
    'MaxCells',262144,'MaxDepth',24,'MaximumUnresolvedIntervals',64);
assert(all(ismember(fieldnames(options),fieldnames(o))),'C1Flight:Options','Unknown option.');
for name=fieldnames(options).',o.(name{1})=options.(name{1});end
for name={'ArithmeticCushion','DerivativeCushion','CurvatureCushion','EndpointTimeTolerance'}
    validateattributes(o.(name{1}),{'double'},{'real','finite','scalar','positive'});
end
validateattributes(o.MaxWallSeconds,{'double'},{'real','finite','scalar','positive','<=',60});
validateattributes(duration,{'double'},{'real','finite','scalar','positive'});
assert(ischar(o.InitialEndpointKind)&&any(strcmp(o.InitialEndpointKind,{'apex','LO'})) ...
    &&ischar(o.FinalEndpointKind)&&any(strcmp(o.FinalEndpointKind,{'apex','TD'})), ...
    'C1Flight:Kinds','Use literal apex/LO at the start and apex/TD at the end.');
assert(isstruct(o.Limits)&&all(isfield(o.Limits,{'deadline_unix_seconds','deadline_monotonic_ns'})), ...
    'C1Flight:Limits','Both parent deadlines are required.');
entry=clockNow();finish=struct('deadline_unix_seconds',min(o.Limits.deadline_unix_seconds,entry.u+o.MaxWallSeconds), ...
    'deadline_monotonic_ns',min(o.Limits.deadline_monotonic_ns,entry.m+o.MaxWallSeconds*1e9));
s=QuadrupedSchema_v3.shared();x=s.validateState(initialState);q=s.validateMode(mode);p=s.validateParameter(parameter);
last=s.validateState(o.ActualFinalState);assert(~any(q),'C1Flight:Mode','Use an actual all-flight mode.');
a=s.expandParameters(p);physical=QuadrupedAdmissibility_v3(s);
assert(isequal(o.SwingPenetrationTolerance,physical.SwingPenetrationTolerance), ...
    'C1Flight:PhysicalTolerance','Retain the actual native swing-penetration tolerance.');
result=struct('schema','C1-literal-flight-conditional-supplement-v1','status','UNASSESSED', ...
    'reason','','initial_state',initialState,'initial_mode',mode,'parameter',parameter, ...
    'actual_final_state',o.ActualFinalState,'duration',duration,'options',o, ...
    'physical_bounds',struct(),'strict_interior_bounds',struct(),'endpoint_checks',{{}}, ...
    'native_endpoint_consistency',struct(),'strict_interior_interval',[], ...
    'reference_rebase',struct(),'physical_nonpenetration_conditionally_covered',false, ...
    'strict_positive_interior_conditionally_covered',false,'no_distinct_earlier_TD_conditionally_observed',false, ...
    'return_timely',false,'failure',struct(),'ODE_calls',0,'root_calls',0, ...
    'new_admission_claimed',false,'source_projection_performed',false, ...
    'formal_continuous_coverage_claimed',false,'actual_event_history_ownership_verified',false, ...
    'scope',['Caller binds literal all-flight interval and endpoint kinds to actual history. ', ...
    'PASS requires conditional physical coverage, strict interior guard positivity and unique owned event-window roots. ', ...
    'It does not establish other physical inequalities, orbit closure, classification or a branch attachment.'], ...
    'arithmetic_assumption',['Caller guard/derivative/curvature cushions bound TOTAL propagated arithmetic and supplied-state error ', ...
    'in their respective units, including rebase inflation, endpoint comparisons and curvature inequalities. No outward rounding is used.']);
try
    check(finish);whole=bound(x,q,p,duration,o.SwingPenetrationTolerance,o.ArithmeticCushion,o,finish);
    result.physical_bounds=whole;
    if whole.return_timely&&whole.conditional_violation_observed
        result.status='VIOLATION';result.reason='CONDITIONAL_NEGATIVE_GUARD_BEYOND_UNCHANGED_PHYSICAL_TOLERANCE';
    elseif ~whole.all_cells_covered_conditionally
        result.reason='WHOLE_INTERVAL_PHYSICAL_COVERAGE_UNASSESSED';
    else
        result.physical_nonpenetration_conditionally_covered=true;
        flow=ContinuousDynamics_v3(s);guards=GuardFunctions_v3(s);
        n0=nativePoint(x,q,p,0,flow,guards);n1=nativePoint(last,q,p,duration,flow,guards);
        h0=harmonic(0,x,a,s);h1=harmonic(duration,x,a,s);
        guardErrors=[abs(n0.guard-h0.guard),abs(n1.guard-h1.guard)];
        slopeErrors=[abs(n0.slope-h0.slope),abs(n1.slope-h1.slope)];
        consistent=all(guardErrors(:,1)<=o.ArithmeticCushion) ...
            &&all(guardErrors(:,2)<=h1.guard_error+o.ArithmeticCushion) ...
            &&all(slopeErrors(:,1)<=o.DerivativeCushion) ...
            &&all(slopeErrors(:,2)<=h1.slope_error+o.DerivativeCushion);
        result.native_endpoint_consistency=struct('initial_native',n0,'final_native',n1, ...
            'initial_reference',h0,'final_reference',h1,'guard_errors',guardErrors, ...
            'slope_errors',slopeErrors,'within_conditional_envelopes',consistent, ...
            'caller_retains_responsibility_for_actual_final_state_lineage',true);
        if ~consistent
            result.reason='ACTUAL_ENDPOINT_OUTSIDE_DECLARED_MODEL_ARITHMETIC_ENVELOPE';
        else
            epsilon=o.EndpointTimeTolerance;
            left=double(strcmp(o.InitialEndpointKind,'LO'))*epsilon;
            right=duration-double(strcmp(o.FinalEndpointKind,'TD'))*epsilon;
            result.strict_interior_interval=[left,right];
            assert(right>left&&epsilon<duration/4,'C1Flight:EndpointWindows','Recorded time windows must leave a nonempty interval.');
            % Obtain the existing model curvature bound on the slightly extended
            % reference interval. Its cell verdict is not used as coverage.
            ko=boundOptions(o,finish,o.SwingPenetrationTolerance,o.ArithmeticCushion);
            ko.MaxCells=4;ko.MaxDepth=0;ko.MaxWallSeconds=min(2,remaining(finish));
            curvatureOnly=AllFlightClearanceBounds_v3(x,q,p,duration+epsilon,ko);
            K=curvatureOnly.curvature_upper_bounds+o.CurvatureCushion;
            result.curvature_upper_bounds_for_endpoint_windows=K;
            if left>0
                result.endpoint_checks{end+1,1}=eventWindow('LO',0,epsilon,x,a,s,n0,K,o);
            end
            if right<duration
                result.endpoint_checks{end+1,1}=eventWindow('TD',duration,epsilon,x,a,s,n1,K,o);
            end
            start=harmonic(left,x,a,s);D=right-left;
            % This is a bounding REFERENCE CENTER, never a changed source state.
            % Both original and reference-started forced flights share the same
            % harmonic center. Their guard difference is at most the sum of
            % their forcing remainders, uniformly over the strict interval.
            inflation=max(a.l_0.*whole.angular_forcing_upper_bounds)*(right^2+D^2)/2;
            strict=bound(start.state,q,p,D,0,o.ArithmeticCushion+inflation,o,finish);
            result.strict_interior_bounds=strict;
            result.reference_rebase=struct('time',left,'state',start.state, ...
                'uniform_guard_difference_allowance',inflation,'original_source_changed',false, ...
                'reference_center_is_not_an_admitted_or_literal_propagated_state',true);
            strictPass=strict.all_cells_covered_conditionally&&all(cellfun(@(r)r.minimum_passed_lower_bound>0,strict.legs));
            endpointPass=all(cellfun(@(r)r.unique_zero_in_recorded_window&&r.native_direction_consistent,result.endpoint_checks));
            result.strict_positive_interior_conditionally_covered=strictPass;
            if strictPass&&endpointPass&&remaining(finish)>0
                result.status='PASS';result.reason='CONDITIONAL_PHYSICAL_AND_NO_ADDITIONAL_TD_SUPPLEMENT_PASSED';
                result.no_distinct_earlier_TD_conditionally_observed=true;
            elseif ~endpointPass
                result.reason='OWNED_ENDPOINT_UNIQUENESS_OR_DIRECTION_UNASSESSED';
            else
                result.reason='STRICT_INTERIOR_POSITIVITY_UNASSESSED';
            end
        end
    end
catch problem,result.failure=struct('identifier',problem.identifier,'message',problem.message);result.reason='NUMERICAL_OR_RESOURCE_CHECK_UNASSESSED';end
ended=clockNow();result.return_timely=remaining(finish)>0;result.elapsed_seconds=(ended.m-entry.m)/1e9;
if ~result.return_timely&&strcmp(result.status,'PASS'),result.status='UNASSESSED';result.no_distinct_earlier_TD_conditionally_observed=false;result.reason='LOCAL_OR_PARENT_DEADLINE_EXPIRED';end
end

function out=eventWindow(kind,time,e,x,a,s,native,K,o)
lo=harmonic(time-e,x,a,s);hi=harmonic(time+e,x,a,s);mid=harmonic(time,x,a,s);
if strcmp(kind,'LO')
    bracket=lo.guard+lo.guard_error+o.ArithmeticCushion<0 ...
        &hi.guard-hi.guard_error-o.ArithmeticCushion>0;
    monotone=mid.slope-mid.slope_error-o.DerivativeCushion-K*e>0;
    direction=native.slope-o.DerivativeCushion>0;
else
    bracket=lo.guard-lo.guard_error-o.ArithmeticCushion>0 ...
        &hi.guard+hi.guard_error+o.ArithmeticCushion<0;
    monotone=mid.slope+mid.slope_error+o.DerivativeCushion+K*e<0;
    direction=native.slope+o.DerivativeCushion<0;
end
out=struct('kind',kind,'nominal_time',time,'recorded_time_tolerance',e, ...
    'window',[time-e,time+e],'reference_left',lo,'reference_right',hi, ...
    'opposite_guard_signs_conditionally_observed',bracket, ...
    'derivative_fixed_sign_conditionally_observed',monotone, ...
    'unique_zero_in_recorded_window',all(bracket&monotone), ...
    'native_direction_consistent',all(direction),'scope','One zero per leg in this owned time-uncertainty window; no arbitrary excluded interval.');
end
function point=harmonic(t,x,a,s)
w=x(s.State.dphi);nu=sqrt(a.k_s)./a.l_0;z=nu*t;ratio=ones(4,1);nz=z~=0;ratio(nz)=sin(z(nz))./z(nz);
angle=a.rsla+(x(s.Leg.AngleIndices)-a.rsla).*cos(z)+x(s.Leg.RateIndices)*t.*ratio;
rate=-(x(s.Leg.AngleIndices)-a.rsla).*nu.*sin(z)+x(s.Leg.RateIndices).*cos(z);
y=x(s.State.y)+x(s.State.dy)*t-t^2/2;phi=x(s.State.phi)+w*t;theta=phi+angle;
F=abs(a.s./a.l_0)*w^2;angleError=F*t^2/2;rateError=F*abs(t);
state=x;state(s.State.x)=x(s.State.x)+x(s.State.dx)*t;state(s.State.y)=y;state(s.State.dy)=x(s.State.dy)-t;
state(s.State.phi)=phi;state(s.Leg.AngleIndices)=angle;state(s.Leg.RateIndices)=rate;
guard=y+a.s*sin(phi)-a.l_0.*cos(theta);
slope=state(s.State.dy)+a.s*cos(phi)*w+a.l_0.*sin(theta).*(w+rate);
point=struct('time',t,'state',state,'guard',guard,'slope',slope, ...
    'guard_error',a.l_0.*angleError,'slope_error',a.l_0.*(rateError+abs(w+rate).*angleError));
end
function out=nativePoint(x,q,p,t,flow,guards)
f=flow.evaluate(t,x,q,p);out=struct('state',x,'flow',f,'guard',guards.legValues(x,p), ...
    'slope',guards.legLieDerivatives(x,f,p));
end
function out=bound(x,q,p,T,tolerance,cushion,o,limit)
bo=boundOptions(o,limit,tolerance,cushion);out=AllFlightClearanceBounds_v3(x,q,p,T,bo);
end
function bo=boundOptions(o,limit,tolerance,cushion)
bo=struct('SwingPenetrationTolerance',tolerance,'ArithmeticCushion',cushion, ...
    'Limits',limit,'MaxWallSeconds',min(60,remaining(limit)),'MaxCells',o.MaxCells, ...
    'MaxDepth',o.MaxDepth,'MaximumUnresolvedIntervals',o.MaximumUnresolvedIntervals);
end
function n=clockNow(),n=struct('u',double(java.time.Instant.now().toEpochMilli())/1000,'m',double(java.lang.System.nanoTime()));end
function v=remaining(l),n=clockNow();v=min(l.deadline_unix_seconds-n.u,(l.deadline_monotonic_ns-n.m)/1e9);end
function check(l),assert(remaining(l)>0,'C1Flight:Deadline','Parent/local clock expired.');end
