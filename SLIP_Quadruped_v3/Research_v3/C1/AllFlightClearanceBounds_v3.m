function result=AllFlightClearanceBounds_v3(initialState,mode,parameter,duration,options)
%ALLFLIGHTCLEARANCEBOUNDS_V3 Conditional numerical bounds for one raw flight.
% No integration, root search, reset, projection, classification or admission.
% Bounds concern the fixed all-flight smooth extension, not event selection.
% ArithmeticCushion is a caller-supplied bound on the TOTAL propagated error
% of each scalar lower/upper-bound expression, in guard-length units. This
% assumption is recorded, not established here; no outward rounding is used.
    entryUTC=unixNow();entryMono=nano();
    required={'SwingPenetrationTolerance','ArithmeticCushion','Limits'};
    assert(nargin==5&&isstruct(options)&&isscalar(options)&&all(isfield(options,required)), ...
        'FlightBounds:Options','Supply the actual physical tolerance, conditional arithmetic cushion and parent clocks.');
    o=struct('SwingPenetrationTolerance',[],'ArithmeticCushion',[],'Limits',struct(), ...
        'MaxWallSeconds',10,'MaxCells',262144,'MaxDepth',24,'MaximumUnresolvedIntervals',64);
    assert(all(ismember(fieldnames(options),fieldnames(o))),'FlightBounds:Options','Unknown option.');
    for f=fieldnames(options).',o.(f{1})=options.(f{1});end
    validateattributes(o.SwingPenetrationTolerance,{'double'},{'real','finite','scalar','nonnegative'});
    validateattributes(o.ArithmeticCushion,{'double'},{'real','finite','scalar','positive'});
    validateattributes(o.MaxWallSeconds,{'double'},{'real','finite','scalar','positive','<=',60});
    validateattributes(o.MaxCells,{'double'},{'real','finite','scalar','integer','>=',4,'<=',1048576});
    validateattributes(o.MaxDepth,{'double'},{'real','finite','scalar','integer','nonnegative','<=',40});
    validateattributes(o.MaximumUnresolvedIntervals,{'double'},{'real','finite','scalar','integer','positive','<=',1024});
    limits=o.Limits;
    assert(isstruct(limits)&&isscalar(limits)&&all(isfield(limits, ...
        {'deadline_unix_seconds','deadline_monotonic_ns'})),'FlightBounds:Clocks','Supply both parent deadlines.');
    validateattributes(limits.deadline_unix_seconds,{'double'},{'real','finite','scalar'});
    validateattributes(limits.deadline_monotonic_ns,{'double'},{'real','finite','scalar'});
    finishUTC=min(limits.deadline_unix_seconds,entryUTC+o.MaxWallSeconds);
    finishMono=min(limits.deadline_monotonic_ns,entryMono+o.MaxWallSeconds*1e9);
    s=QuadrupedSchema_v3.shared();x=s.validateState(initialState);q=s.validateMode(mode);
    p=s.validateParameter(parameter);expanded=s.expandParameters(p);
    assert(~any(q),'FlightBounds:Mode','The literal initial mode must have all four legs in flight.');
    validateattributes(duration,{'double'},{'real','finite','scalar','positive'});
    a=x(s.Leg.AngleIndices);w=x(s.Leg.RateIndices);r=expanded.rsla;
    L=expanded.l_0;hip=expanded.s;omega=x(s.State.dphi);
    nu=sqrt(expanded.k_s)./L;
    forcing=abs(hip./L)*omega^2;
    angleBound=abs(a-r)+abs(w)*duration+forcing*duration^2/2;
    rateBound=nu.*abs(a-r)+abs(w)+forcing*duration;
    accelBound=nu.^2.*angleBound+forcing;
    curvature=1+abs(hip)*omega^2+L.*((abs(omega)+rateBound).^2+accelBound);
    result=struct('schema','quadruped-all-flight-clearance-enclosure-v1', ...
        'initial_state',initialState,'initial_mode',mode,'parameter',parameter, ...
        'duration',duration,'options',o,'status','UNRESOLVED','legs',{{}}, ...
        'curvature_upper_bounds',curvature,'angular_forcing_upper_bounds',forcing, ...
        'cells_evaluated',0,'all_cells_covered_conditionally',false, ...
        'conditional_violation_observed',false,'return_timely',false, ...
        'formal_continuous_coverage_claimed',false,'absence_of_earlier_touchdown_claimed',false, ...
        'new_admission_claimed',false,'state_projection_performed',false, ...
        'ODE_calls',0,'root_calls',0,'elapsed_seconds',NaN, ...
        'arithmetic_assumption', ...
        ['The supplied cushion bounds total propagated error of every endpoint upper bound and cell lower bound, ' ...
         'including harmonic, forcing and curvature arithmetic. This implementation does not justify that assumption.'], ...
        'scope', ...
        ['Conditional nonpenetration of the fixed all-flight smooth extension at the unchanged physical tolerance. ' ...
         'This does not establish hybrid event ownership, absence of earlier guard zeros, a branch endpoint or completeness.']);
    boundsFinite=all(isfinite([nu;forcing;angleBound;rateBound;accelBound;curvature]));
    for leg=1:s.Leg.Count
        row=struct('leg',s.Leg.Names{leg},'status','UNRESOLVED','passed_cell_count',0, ...
            'cells_evaluated',0,'minimum_passed_lower_bound',Inf, ...
            'minimum_evaluated_endpoint_upper_bound',Inf,'minimum_upper_bound_time',NaN, ...
            'conditional_violation_observed',false,'unresolved_intervals',zeros(0,2), ...
            'unresolved_cell_count',0,'unresolved_intervals_coarsened',false,'unresolved_reason','');
        pending=[0,duration,0];
        if ~boundsFinite
            row=unresolved(row,pending,'nonfinite_model_bound',o);result.legs{leg,1}=row;continue
        end
        while ~isempty(pending)
            if ~timeLeft()
                row=unresolved(row,pending,'deadline',o);break
            end
            if size(pending,1)>o.MaxCells-result.cells_evaluated
                row=unresolved(row,pending,'cell_cap',o);break
            end
            lo=pending(:,1);hi=pending(:,2);depth=pending(:,3);
            [glo,elo]=endpoint(lo,leg);[ghi,ehi]=endpoint(hi,leg);
            upper=[glo+elo;ghi+ehi]+o.ArithmeticCushion;
            lower=min(glo-elo,ghi-ehi)-curvature(leg)*(hi-lo).^2/8-o.ArithmeticCushion;
            count=size(pending,1);row.cells_evaluated=row.cells_evaluated+count;
            result.cells_evaluated=result.cells_evaluated+count;
            if any(~isfinite([upper;lower]))
                row=unresolved(row,pending,'nonfinite_cell_bound',o);break
            end
            [value,k]=min(upper);times=[lo;hi];
            if value<row.minimum_evaluated_endpoint_upper_bound
                row.minimum_evaluated_endpoint_upper_bound=value;row.minimum_upper_bound_time=times(k);
            end
            if value < -o.SwingPenetrationTolerance
                row.conditional_violation_observed=true;row.status='COND_CONSERVATIVE_NUMERICAL_VIOLATION';break
            end
            passed=lower>=-o.SwingPenetrationTolerance;
            row.passed_cell_count=row.passed_cell_count+sum(passed);
            if any(passed),row.minimum_passed_lower_bound=min(row.minimum_passed_lower_bound,min(lower(passed)));end
            lo=lo(~passed);hi=hi(~passed);depth=depth(~passed);
            if isempty(lo),pending=zeros(0,3);row.status='COND_CONSERVATIVE_NUMERICAL_NONPENETRATION';break;end
            mid=lo+(hi-lo)/2;stopped=depth>=o.MaxDepth|mid<=lo|mid>=hi;
            if any(stopped)
                % Keep all not-yet-proved cells; a partial result never
                % promotes the other unresolved intervals to coverage.
                row=unresolved(row,[lo,hi,depth],'depth_or_time_resolution_cap',o);break
            end
            pending=[lo,mid,depth+1;mid,hi,depth+1];
        end
        result.legs{leg,1}=row;
    end
    result.return_timely=timeLeft();
    result.conditional_violation_observed=any(cellfun(@(z)z.conditional_violation_observed,result.legs));
    result.all_cells_covered_conditionally=result.return_timely&&all(cellfun(@(z) ...
        strcmp(z.status,'COND_CONSERVATIVE_NUMERICAL_NONPENETRATION'),result.legs));
    if result.return_timely&&result.conditional_violation_observed
        result.status='COND_CONSERVATIVE_NUMERICAL_VIOLATION';
    elseif result.all_cells_covered_conditionally
        result.status='COND_CONSERVATIVE_NUMERICAL_NONPENETRATION';
    end
    result.elapsed_seconds=(nano()-entryMono)/1e9;

    function yes=timeLeft(),yes=unixNow()<finishUTC&&nano()<finishMono;end
    function [guard,error]=endpoint(t,i)
        z=nu(i)*t;ratio=ones(size(z));nonzero=z~=0;ratio(nonzero)=sin(z(nonzero))./z(nonzero);
        harmonic=r(i)+(a(i)-r(i))*cos(z)+w(i)*t.*ratio;
        phi=x(s.State.phi)+omega*t;
        y=x(s.State.y)+x(s.State.dy)*t-t.^2/2;
        guard=y+hip(i)*sin(phi)-L(i)*cos(phi+harmonic);
        error=L(i)*forcing(i)*t.^2/2;
    end
end

function row=unresolved(row,cells,reason,o)
    intervals=sortrows(cells(:,1:2),1);right=cummax(intervals(:,2));
    first=find([true;intervals(2:end,1)>right(1:end-1)]);
    last=[first(2:end)-1;size(intervals,1)];merged=[intervals(first,1),right(last)];
    if size(merged,1)>o.MaximumUnresolvedIntervals
        merged=[min(merged(:,1)),max(merged(:,2))];row.unresolved_intervals_coarsened=true;
    end
    row.unresolved_intervals=merged;row.unresolved_cell_count=size(cells,1);row.unresolved_reason=reason;
end
function t=unixNow(),t=double(java.time.Instant.now().toEpochMilli())/1000;end
function t=nano(),t=double(java.lang.System.nanoTime());end
