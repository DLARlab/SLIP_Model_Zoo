classdef SynchronousPKPhaseResidual_v3 < handle
    %SYNCHRONOUSPKPHASERESIDUAL_V3 Square, forced-phase PK acquisition chart.
    % z=[dx;height;alphaBL;omegaBL;energy;tFlightDown;tStance;tFlightUp].
    % The four guards are redundant only in this exact centered, matched,
    % synchronous, zero-pitch chart. Phase flows can be off their guard
    % equations during Newton trials. They are not autonomous hybrid returns.
    %
    % A result must be handed to the ORIGINAL native BL/PSS problem, using
    % its own energy chart, full-state closure, event capture and all gates.
    % This class deliberately has no createOrbit method. Never give it to
    % PSS as a delegated native residual or reuse its J in a native chart.

    properties (SetAccess=private)
        Schema
        PhysicalParameter
        SourceState
        SourceMode
        Constraint
        ConstraintKind = 'owned-PAL'
        ODEOptions
        ResidualScale
        DeadlineUnixSeconds
        DeadlineMonotonicNs
        InvariantTolerance
        SourceIsExactChart
        AllowNewCandidateChart
        Flow
        Reset
        Transition
        Guards
    end

    methods
        function obj=SynchronousPKPhaseResidual_v3(sourceState,sourceMode,p,constraint,options)
            required={'ODEOptions','DeadlineUnixSeconds','DeadlineMonotonicNs'};
            allowed=[required,{'ResidualScale','InvariantTolerance','AllowNewCandidateChart'}];
            assert(isstruct(options)&&isscalar(options)&&all(isfield(options,required)) ...
                &&all(ismember(fieldnames(options),allowed)), ...
                'SynchronousPKPhase:Options','Supply fixed ODE options and both original deadlines.');
            obj.Schema=QuadrupedSchema_v3.shared();s=obj.Schema;
            obj.SourceState=s.validateState(sourceState);
            obj.SourceMode=s.validateMode(sourceMode);
            obj.PhysicalParameter=s.validateParameter(p);p=obj.PhysicalParameter;
            a=s.Parameter;
            assert(isequal(p([a.k_l_b,a.k_s_b,a.l_l_b,a.rsla_b]), ...
                p([a.k_l_f,a.k_s_f,a.l_l_f,a.rsla_f]))&&p(a.l_com)==.5 ...
                &&isfinite(p(a.j_pitch))&&~any(obj.SourceMode), ...
                'SynchronousPKPhase:Chart','Require literal matched parameters, centered COM and all-flight source mode.');
            obj.AllowNewCandidateChart=false;
            if isfield(options,'AllowNewCandidateChart')
                value=options.AllowNewCandidateChart;
                assert(islogical(value)&&isscalar(value),'SynchronousPKPhase:Chart', ...
                    'AllowNewCandidateChart must be an explicit scalar logical.');
                obj.AllowNewCandidateChart=value;
            end
            x=obj.SourceState;st=s.State;
            obj.SourceIsExactChart=all(x([st.dy,st.phi,st.dphi])==0) ...
                &&all(x(s.Leg.AngleIndices)==x(st.alphaBL)) ...
                &&all(x(s.Leg.RateIndices)==x(st.dalphaBL));
            assert(obj.SourceIsExactChart||obj.AllowNewCandidateChart, ...
                'SynchronousPKPhase:NewChartRequired', ...
                'A nonexact source requires an explicitly declared NEW candidate chart; it is never snapped in place.');
            assert(isstruct(constraint)&&isscalar(constraint) ...
                &&all(isfield(constraint,{'reference','normal','target'})), ...
                'SynchronousPKPhase:Constraint','Supply the original owned [u;E] PAL plane.');
            validateattributes(constraint.reference,{'numeric'},{'real','finite','vector','numel',5});
            validateattributes(constraint.normal,{'numeric'},{'real','finite','vector','numel',5});
            validateattributes(constraint.target,{'numeric'},{'real','finite','scalar'});
            assert(norm(constraint.normal)>0,'SynchronousPKPhase:Constraint','PAL normal must be nonzero.');
            obj.Constraint=constraint;obj.Constraint.reference=constraint.reference(:);
            obj.Constraint.normal=constraint.normal(:);
            if isfield(constraint,'kind')
                assert(ischar(constraint.kind)&&isrow(constraint.kind) ...
                    &&ismember(constraint.kind,{'owned-PAL','initial-flight-clearance'}), ...
                    'SynchronousPKPhase:Constraint','Use owned-PAL or explicit initial-flight-clearance.');
                obj.ConstraintKind=constraint.kind;
            end
            obj.ResidualScale=ones(8,1);
            if isfield(options,'ResidualScale'),obj.ResidualScale=options.ResidualScale(:);end
            validateattributes(obj.ResidualScale,{'numeric'},{'real','finite','positive','vector','numel',8});
            obj.InvariantTolerance=1e-10;
            if isfield(options,'InvariantTolerance'),obj.InvariantTolerance=options.InvariantTolerance;end
            validateattributes(obj.InvariantTolerance,{'numeric'},{'real','finite','positive','scalar'});
            obj.DeadlineUnixSeconds=options.DeadlineUnixSeconds;
            obj.DeadlineMonotonicNs=options.DeadlineMonotonicNs;
            validateattributes(obj.DeadlineUnixSeconds,{'numeric'},{'real','finite','scalar'});
            validateattributes(obj.DeadlineMonotonicNs,{'numeric'},{'real','finite','scalar'});
            assert(isstruct(options.ODEOptions)&&isscalar(options.ODEOptions), ...
                'SynchronousPKPhase:Integration','ODEOptions must be an explicit scalar ODE option structure.');
            obj.ODEOptions=options.ODEOptions;
            assert(isempty(odeget(obj.ODEOptions,'Events',[])) ...
                &&isempty(odeget(obj.ODEOptions,'OutputFcn',[])), ...
                'SynchronousPKPhase:Integration','Forced-phase acquisition takes no native event or external output callback.');
            for key={'RelTol','AbsTol','MaxStep'}
                v=odeget(obj.ODEOptions,key{1},[]);
                assert(~isempty(v)&&isnumeric(v)&&isreal(v)&&all(isfinite(v(:)))&&all(v(:)>0), ...
                    'SynchronousPKPhase:Integration','Specify unchanged positive %s explicitly.',key{1});
            end
            obj.Flow=ContinuousDynamics_v3(s);obj.Reset=ResetMap_v3(s);
            obj.Transition=ModeTransition_v3(s);obj.Guards=GuardFunctions_v3(s);
            obj.checkDeadline();
        end

        function u=packState(obj,x)
            x=obj.Schema.validateState(x);s=obj.Schema.State;
            u=x([s.dx,s.y,s.alphaBL,s.dalphaBL]);
        end

        function x=fullState(obj,z,varargin)
            validateattributes(z,{'numeric'},{'real','finite','vector','numel',8});
            z=z(:);s=obj.Schema;st=s.State;
            x=zeros(st.Dimension,1);x(st.x)=obj.SourceState(st.x);
            x([st.dx,st.y])=z(1:2);
            x(s.Leg.AngleIndices)=z(3);x(s.Leg.RateIndices)=z(4);
        end

        function r=evaluate(obj,z,p,q)
            [r,~]=obj.evaluateWithInfo(z,p,q);
        end

        function [r,info]=evaluateWithInfo(obj,z,p,q,varargin) %#ok<INUSD>
            obj.checkDeadline();z=z(:);
            validateattributes(z,{'numeric'},{'real','finite','vector','numel',8});
            p=obj.Schema.validateParameter(p);q=obj.Schema.validateMode(q);
            assert(isequal(p,obj.PhysicalParameter)&&~any(q), ...
                'SynchronousPKPhase:FixedProblem','Physical parameters and declared flight mode are fixed.');
            tau=z(6:8);
            assert(all(tau>0),'SynchronousPKPhase:Duration', ...
                'Every phase duration must be strictly positive; zero duration is a chart boundary.');
            x0=obj.fullState(z);s=obj.Schema;st=s.State;
            assert(x0(st.y)>0,'SynchronousPKPhase:Geometry','Initial candidate height must be positive.');
            flight=false(4,1);stance=true(4,1);
            td=s.Event.IDs(s.Event.IsTouchdown);lo=s.Event.IDs(~s.Event.IsTouchdown);
            [xD,rowsD,geometryD]=obj.integrate(x0,flight,p,0,tau(1));
            xDplus=obj.Reset.applyBatch(td,tau(1),xD,flight,p);
            assert(isequal(obj.Transition.applyBatch(td,flight),stance), ...
                'SynchronousPKPhase:Modes','Native TD batch must produce all stance.');
            [xL,rowsS,geometryS]=obj.integrate(xDplus,stance,p,tau(1),sum(tau(1:2)));
            xLplus=obj.Reset.applyBatch(lo,sum(tau(1:2)),xL,stance,p);
            assert(isequal(obj.Transition.applyBatch(lo,stance),flight), ...
                'SynchronousPKPhase:Modes','Native LO batch must produce all flight.');
            [xA,rowsA,geometryA]=obj.integrate(xLplus,flight,p,sum(tau(1:2)),sum(tau));
            g0=obj.Guards.legValues(x0,p);f0=obj.Flow.evaluate(0,x0,flight,p);
            dg0=obj.Guards.legLieDerivatives(x0,f0,p);
            expanded=s.expandParameters(p);theta=x0(st.phi)+x0(s.Leg.AngleIndices);
            thetaDot=f0(st.phi)+f0(s.Leg.AngleIndices);
            thetaDDot=f0(st.dphi)+f0(s.Leg.RateIndices);
            ddg0=f0(st.dy)+expanded.s.*(cos(x0(st.phi))*f0(st.dphi) ...
                -sin(x0(st.phi))*f0(st.phi)^2) ...
                +expanded.l_0.*(cos(theta).*thetaDot.^2+sin(theta).*thetaDDot);
            gD=obj.Guards.legValues(xD,p);gL=obj.Guards.legValues(xL,p);
            fD=obj.Flow.evaluate(tau(1),xD,flight,p);
            fL=obj.Flow.evaluate(sum(tau(1:2)),xL,stance,p);
            fA=obj.Flow.evaluate(sum(tau),xA,flight,p);
            dD=obj.Guards.legLieDerivatives(xD,fD,p);
            dL=obj.Guards.legLieDerivatives(xL,fL,p);
            states=[x0,xD,xDplus,xL,xLplus,xA];
            defect=obj.invariantDefect(states);
            assert(defect<=obj.InvariantTolerance,'SynchronousPKPhase:InvariantDrift', ...
                'Forced flow left the declared exact invariant chart numerically (%.9g).',defect);
            H=.5*z(1)^2+z(2);
            planeCoordinate=obj.Constraint.normal.'*(z(1:5)-obj.Constraint.reference);
            if strcmp(obj.ConstraintKind,'owned-PAL')
                selector=planeCoordinate-obj.Constraint.target;
            else
                % F7 stays literal. This eighth row locates a unilateral
                % initial-clearance boundary; it is not a native admission.
                selector=g0(1)-obj.Constraint.target;
            end
            raw=[gD(1);gL(1);xA(st.dy); ...
                xA([st.dx,st.alphaBL,st.dalphaBL])-x0([st.dx,st.alphaBL,st.dalphaBL]);H-z(5);selector];
            r=raw./obj.ResidualScale;
            info=struct('acquisition_evaluation_completed',true, ...
                'acquisition_chart','exact-centered-upright-synchronous-PK-eight-variable', ...
                'forced_phase_trial',true,'autonomous_return_claimed',false, ...
                'native_admission_claimed',false,'phase_durations',tau, ...
                'source_state',obj.SourceState,'source_mode',obj.SourceMode, ...
                'source_is_exact_chart',obj.SourceIsExactChart, ...
                'new_candidate_chart_allowed',obj.AllowNewCandidateChart, ...
                'candidate_lift_delta',x0-obj.SourceState,'initial_state',x0, ...
                'phase_endpoint_states',states,'phase_saved_rows',[rowsD,rowsS,rowsA], ...
                'period_guess',sum(tau),'stride_guess',xA(st.x)-x0(st.x), ...
                'acquisition_full13_delta',xA(2:end)-x0(2:end), ...
                'all_td_guard_values',gD,'all_lo_guard_values',gL, ...
                'initial_guard_values',g0,'initial_guard_rates',dg0, ...
                'initial_guard_second_derivatives',ddg0, ...
                'phase_geometry',{{geometryD,geometryS,geometryA}}, ...
                'all_td_guard_lie_derivatives',dD,'all_lo_guard_lie_derivatives',dL, ...
                'terminal_apex_acceleration',fA(st.dy), ...
                'direction_inequalities_hold',all(dD<0)&&all(dL>0)&&fA(st.dy)<0, ...
                'invariant_defect',defect,'energy',H,'energy_unknown',z(5), ...
                'energy_pivot_coordinate',st.y,'energy_pivot_derivative',1, ...
                'physical_residual',raw,'scaled_residual',r,'residual_scale',obj.ResidualScale, ...
                'constraint_kind',obj.ConstraintKind,'constraint_target',obj.Constraint.target, ...
                'original_PAL_coordinate',planeCoordinate,'constraint_residual',selector, ...
                'handoff_required','Original autonomous BL map and native energy chart/PSS, original owned PAL, full13/all9/fresh replays and event capture; no phase Jacobian reuse.');
            obj.checkDeadline();
        end

        function [modes,details]=modeCandidates(obj,varargin) %#ok<INUSD>
            modes={false(obj.Schema.Leg.Count,1)};
            details=struct('mode',modes{1},'reason','fixed forced-phase candidate chart','source','phase-acquisition-only');
        end
    end

    methods (Access=private)
        function [last,rows,geometry]=integrate(obj,x,q,p,t0,t1)
            obj.checkDeadline();
            assert(isfinite(t1)&&t1>t0,'SynchronousPKPhase:Duration','Finite increasing phase times are required.');
            opts=odeset(obj.ODEOptions,'OutputFcn',@deadlineOutput);
            [time,state]=ode45(@rhs,[t0,t1],x,opts);
            obj.checkDeadline();
            assert(~isempty(time)&&abs(time(end)-t1)<=8*eps(max(1,abs(t1))) ...
                &&all(isfinite(state(:))),'SynchronousPKPhase:Integration', ...
                'A forced phase must actually reach its endpoint with finite states.');
            last=state(end,:).';rows=numel(time);
            s=obj.Schema;expanded=s.expandParameters(p);
            phi=state(:,s.State.phi);alpha=state(:,s.Leg.AngleIndices);
            values=state(:,s.State.y)+sin(phi)*expanded.s.' ...
                -cos(phi+alpha).*expanded.l_0.';
            geometry=struct('time_interval',[t0,t1],'mode',q, ...
                'minimum_saved_guard_per_leg',min(values,[],1).', ...
                'maximum_saved_guard_per_leg',max(values,[],1).', ...
                'first_saved_time_after_start',time(2), ...
                'first_saved_guards_after_start',values(2,:).', ...
                'scope','Original forced-flow saved rows only; not a continuous inequality certificate or autonomous admission.');
            function dx=rhs(t,y)
                % The monotonic bound is checked at every RHS call; both
                % clocks are checked at accepted steps and phase boundaries.
                obj.checkDeadline(false);dx=obj.Flow.evaluate(t,y,q,p);
            end
            function stop=deadlineOutput(~,~,~)
                obj.checkDeadline();stop=0;
            end
        end

        function value=invariantDefect(obj,x)
            s=obj.Schema;st=s.State;
            differences=[x([st.phi,st.dphi],:); ...
                x(s.Leg.AngleIndices,:)-x(st.alphaBL,:); ...
                x(s.Leg.RateIndices,:)-x(st.dalphaBL,:)];
            value=max(abs(differences(:)));
        end

        function checkDeadline(obj,checkUTC)
            if nargin<2,checkUTC=true;end
            assert(double(java.lang.System.nanoTime())<obj.DeadlineMonotonicNs ...
                &&(~checkUTC||posixtime(datetime('now','TimeZone','UTC'))<obj.DeadlineUnixSeconds), ...
                'SynchronousPKPhase:Deadline','The original phase-acquisition deadline expired.');
        end
    end
end
