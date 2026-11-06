classdef SynchronousPKGroundedPhaseResidual_v3 < handle
    %SYNCHRONOUSPKGROUNDEDPHASERESIDUAL_V3 NEW grounded-apex acquisition.
    % z=[dx;height;commonAlpha;energy;tStance1;tFlight;tStance2].
    % The stance rates are dependent physical coordinates. Forced smooth
    % phases may be off their guard equations during Newton acquisition.
    % This is not an autonomous return and deliberately has no createOrbit.
    % A root requires the original native BL/PSS admission and all its gates.

    properties (SetAccess=private)
        Schema
        PhysicalParameter
        SourceState
        SourceMode
        Constraint
        CoordinateIndices
        EnergyPivot
        ClosureIndices
        EnergyGradientTolerance
        ODEOptions
        ResidualScale
        InvariantTolerance
        DeadlineUnixSeconds
        DeadlineMonotonicNs
        Flow
        Reset
        Transition
        Guards
    end

    methods
        function obj=SynchronousPKGroundedPhaseResidual_v3(sourceState,sourceMode,p,constraint,options)
            required={'ODEOptions','DeadlineUnixSeconds','DeadlineMonotonicNs'};
            allowed=[required,{'ResidualScale','InvariantTolerance','EnergyGradientTolerance'}];
            assert(isstruct(options)&&isscalar(options)&&all(isfield(options,required)) ...
                &&all(ismember(fieldnames(options),allowed)), ...
                'SynchronousPKGrounded:Options','Supply explicit integration and both original deadlines.');
            obj.Schema=QuadrupedSchema_v3.shared();s=obj.Schema;st=s.State;pp=s.Parameter;
            obj.SourceState=s.validateState(sourceState);obj.SourceMode=s.validateMode(sourceMode);
            obj.PhysicalParameter=s.validateParameter(p);p=obj.PhysicalParameter;
            assert(all(obj.SourceMode)&&p(pp.l_com)==.5&&isfinite(p(pp.j_pitch)) ...
                &&isequal(p([pp.k_l_b,pp.k_s_b,pp.l_l_b,pp.rsla_b]), ...
                    p([pp.k_l_f,pp.k_s_f,pp.l_l_f,pp.rsla_f])), ...
                'SynchronousPKGrounded:Chart','Require matched, centered parameters and an explicit all-stance NEW chart.');
            x=obj.SourceState;
            assert(all(x([st.dy,st.phi,st.dphi])==0) ...
                &&all(x(s.Leg.AngleIndices)==x(st.alphaBL)) ...
                &&all(x(s.Leg.RateIndices)==x(st.dalphaBL)), ...
                'SynchronousPKGrounded:ExactChart','Supply a literal NEW upright synchronous grounded state; never snap a source orbit.');
            physical=QuadrupedPhysicalChart_v3.report(x,obj.SourceMode,p);
            assert(physical.maximum_constraint_residual<=1e-10, ...
                'SynchronousPKGrounded:PhysicalChart','NEW source stance rates must already satisfy their physical constraint.');
            assert(isstruct(constraint)&&isscalar(constraint) ...
                &&all(isfield(constraint,{'reference','normal','target'})), ...
                'SynchronousPKGrounded:Constraint','Supply one fixed linear selector in [dx;height;alpha;energy].');
            validateattributes(constraint.reference,{'numeric'},{'real','finite','vector','numel',4});
            validateattributes(constraint.normal,{'numeric'},{'real','finite','vector','numel',4});
            validateattributes(constraint.target,{'numeric'},{'real','finite','scalar'});
            assert(norm(constraint.normal)>0,'SynchronousPKGrounded:Constraint','The selector normal must be nonzero.');
            obj.Constraint=constraint;obj.Constraint.reference=constraint.reference(:);obj.Constraint.normal=constraint.normal(:);
            obj.CoordinateIndices=[st.dx,st.y,st.alphaBL];
            obj.EnergyGradientTolerance=1e-6;
            if isfield(options,'EnergyGradientTolerance'),obj.EnergyGradientTolerance=options.EnergyGradientTolerance;end
            validateattributes(obj.EnergyGradientTolerance,{'numeric'},{'real','finite','positive','scalar'});
            [~,gradient]=obj.energy(x);[largest,obj.EnergyPivot]=max(abs(gradient));
            assert(largest>=obj.EnergyGradientTolerance,'SynchronousPKGrounded:EnergyChart','No regular energy coordinate at this NEW seed.');
            obj.ClosureIndices=setdiff(1:3,obj.EnergyPivot,'stable');
            obj.ResidualScale=ones(7,1);
            if isfield(options,'ResidualScale'),obj.ResidualScale=options.ResidualScale(:);end
            validateattributes(obj.ResidualScale,{'numeric'},{'real','finite','positive','vector','numel',7});
            obj.InvariantTolerance=1e-10;
            if isfield(options,'InvariantTolerance'),obj.InvariantTolerance=options.InvariantTolerance;end
            validateattributes(obj.InvariantTolerance,{'numeric'},{'real','finite','positive','scalar'});
            obj.DeadlineUnixSeconds=options.DeadlineUnixSeconds;obj.DeadlineMonotonicNs=options.DeadlineMonotonicNs;
            validateattributes(obj.DeadlineUnixSeconds,{'numeric'},{'real','finite','scalar'});
            validateattributes(obj.DeadlineMonotonicNs,{'numeric'},{'real','finite','scalar'});
            obj.ODEOptions=options.ODEOptions;
            assert(isstruct(obj.ODEOptions)&&isscalar(obj.ODEOptions) ...
                &&isempty(odeget(obj.ODEOptions,'Events',[]))&&isempty(odeget(obj.ODEOptions,'OutputFcn',[])), ...
                'SynchronousPKGrounded:Integration','Forced acquisition takes no event or external output callback.');
            for key={'RelTol','AbsTol','MaxStep'}
                value=odeget(obj.ODEOptions,key{1},[]);
                assert(isnumeric(value)&&~isempty(value)&&all(isfinite(value(:)))&&all(value(:)>0), ...
                    'SynchronousPKGrounded:Integration','Specify a positive finite %s.',key{1});
            end
            obj.Flow=ContinuousDynamics_v3(s);obj.Reset=ResetMap_v3(s);
            obj.Transition=ModeTransition_v3(s);obj.Guards=GuardFunctions_v3(s);obj.checkDeadline();
        end

        function u=packState(obj,x)
            x=obj.Schema.validateState(x);u=x(obj.CoordinateIndices);
        end

        function x=fullState(obj,z,varargin) %#ok<INUSD>
            validateattributes(z,{'numeric'},{'real','finite','vector','numel',7});z=z(:);
            s=obj.Schema;st=s.State;x=zeros(st.Dimension,1);x(st.x)=obj.SourceState(st.x);
            x(st.dx)=z(1);x(st.y)=z(2);x(s.Leg.AngleIndices)=z(3);
            assert(x(st.y)>0&&cos(z(3))>1e-10, ...
                'SynchronousPKGrounded:Geometry','Require positive height and downward nonsingular legs.');
            for leg=1:s.Leg.Count,x(s.Leg.RateIndices(leg))=obj.Reset.projectedAngularRate(x,leg,obj.PhysicalParameter);end
        end

        function r=evaluate(obj,z,p,q)
            [r,~]=obj.evaluateWithInfo(z,p,q);
        end

        function [r,info]=evaluateWithInfo(obj,z,p,q,varargin) %#ok<INUSD>
            obj.checkDeadline();validateattributes(z,{'numeric'},{'real','finite','vector','numel',7});z=z(:);
            p=obj.Schema.validateParameter(p);q=obj.Schema.validateMode(q);
            assert(isequal(p,obj.PhysicalParameter)&&all(q), ...
                'SynchronousPKGrounded:FixedProblem','Physical parameters and the grounded initial mode are fixed.');
            tau=z(5:7);assert(all(tau>0),'SynchronousPKGrounded:Duration','Every phase duration must be strictly positive.');
            x0=obj.fullState(z);s=obj.Schema;st=s.State;expanded=s.expandParameters(p);
            assert(x0(st.y)<=expanded.l_0(1)*cos(z(3)), ...
                'SynchronousPKGrounded:InitialCompression','The NEW grounded apex must be compressive.');
            f0=obj.Flow.evaluate(0,x0,q,p);
            assert(f0(st.dy)<0,'SynchronousPKGrounded:InitialApex','The NEW initial section must be a downward COM apex.');
            [H,gradient]=obj.energy(x0);
            assert(abs(gradient(obj.EnergyPivot))>=obj.EnergyGradientTolerance, ...
                'SynchronousPKGrounded:EnergyChartBoundary','The registered energy pivot lost regularity; rechart explicitly.');
            stance=true(4,1);flight=false(4,1);
            td=s.Event.IDs(s.Event.IsTouchdown);lo=s.Event.IDs(~s.Event.IsTouchdown);
            [xL,rowsS1,geometryS1]=obj.integrate(x0,stance,p,0,tau(1));
            xLplus=obj.Reset.applyBatch(lo,tau(1),xL,stance,p);
            assert(isequal(obj.Transition.applyBatch(lo,stance),flight),'SynchronousPKGrounded:Modes','LO batch must produce all flight.');
            [xD,rowsF,geometryF]=obj.integrate(xLplus,flight,p,tau(1),sum(tau(1:2)));
            xDplus=obj.Reset.applyBatch(td,sum(tau(1:2)),xD,flight,p);
            assert(isequal(obj.Transition.applyBatch(td,flight),stance),'SynchronousPKGrounded:Modes','TD batch must produce all stance.');
            [xA,rowsS2,geometryS2]=obj.integrate(xDplus,stance,p,sum(tau(1:2)),sum(tau));
            gL=obj.Guards.legValues(xL,p);gD=obj.Guards.legValues(xD,p);
            fL=obj.Flow.evaluate(tau(1),xL,stance,p);fD=obj.Flow.evaluate(sum(tau(1:2)),xD,flight,p);
            fA=obj.Flow.evaluate(sum(tau),xA,stance,p);
            dL=obj.Guards.legLieDerivatives(xL,fL,p);dD=obj.Guards.legLieDerivatives(xD,fD,p);
            states=[x0,xL,xLplus,xD,xDplus,xA];defect=obj.invariantDefect(states);
            assert(defect<=obj.InvariantTolerance,'SynchronousPKGrounded:InvariantDrift','Forced flow left the declared invariant chart (%.9g).',defect);
            closure=xA(obj.CoordinateIndices)-x0(obj.CoordinateIndices);
            selector=obj.Constraint.normal.'*(z(1:4)-obj.Constraint.reference)-obj.Constraint.target;
            raw=[gL(1);gD(1);xA(st.dy);closure(obj.ClosureIndices);H-z(4);selector];
            r=raw./obj.ResidualScale;
            noFlightApex=(xLplus(st.dy)>0&&xD(st.dy)>0)||(xLplus(st.dy)<0&&xD(st.dy)<0);
            info=struct('acquisition_evaluation_completed',true, ...
                'acquisition_chart','NEW-exact-centered-upright-synchronous-grounded-PK-seven-variable', ...
                'forced_phase_trial',true,'autonomous_return_claimed',false,'native_admission_claimed',false, ...
                'source_state',obj.SourceState,'source_mode',obj.SourceMode,'new_candidate_chart',true, ...
                'candidate_lift_delta',x0-obj.SourceState,'initial_state',x0,'phase_durations',tau, ...
                'phase_endpoint_states',states,'phase_saved_rows',[rowsS1,rowsF,rowsS2], ...
                'phase_geometry',{{geometryS1,geometryF,geometryS2}},'period_guess',sum(tau), ...
                'stride_guess',xA(st.x)-x0(st.x),'acquisition_full13_delta',xA(2:end)-x0(2:end), ...
                'independent_coordinate_closure',closure,'all_lo_guard_values',gL,'all_td_guard_values',gD, ...
                'all_lo_guard_lie_derivatives',dL,'all_td_guard_lie_derivatives',dD, ...
                'initial_apex_acceleration',f0(st.dy),'terminal_apex_acceleration',fA(st.dy), ...
                'direction_inequalities_hold',all(dL>0)&&all(dD<0)&&fA(st.dy)<0, ...
                'flight_vertical_velocities',[xLplus(st.dy);xD(st.dy)], ...
                'flight_has_no_interior_apex',noFlightApex, ...
                'BL_marking_still_requires_native_verification',true,'invariant_defect',defect, ...
                'energy',H,'energy_unknown',z(4),'restricted_energy_gradient',gradient, ...
                'energy_pivot_position',obj.EnergyPivot,'energy_pivot_coordinate',obj.CoordinateIndices(obj.EnergyPivot), ...
                'energy_pivot_derivative',gradient(obj.EnergyPivot),'closure_positions',obj.ClosureIndices, ...
                'constraint_residual',selector,'physical_residual',raw,'scaled_residual',r, ...
                'residual_scale',obj.ResidualScale, ...
                'handoff_required','Original autonomous grounded BL map, native energy chart and shared PSS; full13/all9 plus continuous flight/topology qualification before any P/M claim.');
            obj.checkDeadline();
        end

        function [modes,details]=modeCandidates(obj,varargin) %#ok<INUSD>
            modes={true(obj.Schema.Leg.Count,1)};
            details=struct('mode',modes{1},'reason','explicit NEW grounded forced-phase chart','source','acquisition-only');
        end
    end

    methods (Access=private)
        function [H,gradient]=energy(obj,x)
            [H,e]=QuadrupedEnergy_v3.evaluate(x,obj.SourceMode,obj.PhysicalParameter);
            s=obj.Schema;gradient=[e.gradient(s.State.dx);e.gradient(s.State.y);sum(e.gradient(s.Leg.AngleIndices))];
        end

        function [last,rows,geometry]=integrate(obj,x,q,p,t0,t1)
            obj.checkDeadline();assert(isfinite(t1)&&t1>t0,'SynchronousPKGrounded:Duration','Increasing finite phase endpoints required.');
            opts=odeset(obj.ODEOptions,'OutputFcn',@deadlineOutput);
            [time,state]=ode45(@rhs,[t0,t1],x,opts);obj.checkDeadline();
            assert(numel(time)>=2&&abs(time(end)-t1)<=8*eps(max(1,abs(t1)))&&all(isfinite(state(:))), ...
                'SynchronousPKGrounded:Integration','Forced phase must reach its endpoint with finite states.');
            last=state(end,:).';rows=numel(time);s=obj.Schema;expanded=s.expandParameters(p);
            phi=state(:,s.State.phi);alpha=state(:,s.Leg.AngleIndices);
            gaps=state(:,s.State.y)+sin(phi)*expanded.s.'-cos(phi+alpha).*expanded.l_0.';
            geometry=struct('time_interval',[t0,t1],'mode',q,'minimum_saved_guard_per_leg',min(gaps,[],1).', ...
                'maximum_saved_guard_per_leg',max(gaps,[],1).','minimum_saved_height',min(state(:,s.State.y)), ...
                'scope','Saved forced-flow samples only; no continuous physical or event-ownership claim.');
            function dx=rhs(t,y),obj.checkDeadline(false);dx=obj.Flow.evaluate(t,y,q,p);end
            function stop=deadlineOutput(~,~,~),obj.checkDeadline();stop=0;end
        end

        function value=invariantDefect(obj,x)
            s=obj.Schema;st=s.State;
            delta=[x([st.phi,st.dphi],:);x(s.Leg.AngleIndices,:)-x(st.alphaBL,:);x(s.Leg.RateIndices,:)-x(st.dalphaBL,:)];
            value=max(abs(delta(:)));
        end

        function checkDeadline(obj,checkUTC)
            if nargin<2,checkUTC=true;end
            assert(double(java.lang.System.nanoTime())<obj.DeadlineMonotonicNs ...
                &&(~checkUTC||posixtime(datetime('now','TimeZone','UTC'))<obj.DeadlineUnixSeconds), ...
                'SynchronousPKGrounded:Deadline','The original acquisition deadline expired.');
        end
    end
end
