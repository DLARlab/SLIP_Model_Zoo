classdef BLMarkedApexReturnPolicy_v3 < ReturnPolicyBase_v3
    %BLMARKEDAPEXRETURNPOLICY_V3 Local apex immediately before BL touchdown.
    % The initial apex must be the last downward apex strictly before its
    % next BL TD. Return to the same marking after N explicitly counted BL
    % TD occurrences. A first-return lookahead decides this from events for
    % nearby nonperiodic states, independently of state closure or residual.
    % Changes of apex identity, coincident BL TD, and lost transversality are
    % chart boundaries, not silently repaired by minimizing a residual.
    properties
        BLTouchdownsPerReturn = 1
        RequireModeClosure = true
        LookaheadMaxTime = 20
        LookaheadMaxEvents = 1000
        TimeTolerance = 1e-9
    end
    methods
        function obj=BLMarkedApexReturnPolicy_v3(options)
            obj.Name='BL-marked-apex-return';
            if nargin>0,obj=obj.applyOptions(options);end
            validateattributes(obj.BLTouchdownsPerReturn,{'numeric'},{'scalar','integer','positive'});
            validateattributes(obj.LookaheadMaxTime,{'numeric'},{'scalar','finite','positive'});
            validateattributes(obj.LookaheadMaxEvents,{'numeric'},{'scalar','integer','positive'});
            validateattributes(obj.TimeTolerance,{'numeric'},{'scalar','finite','positive'});
        end
        function state=initialize(obj,initialMode,context)
            state=initialize@ReturnPolicyBase_v3(obj,initialMode,context);
            required={'system','section','simulator','initial_time','initial_state','parameter'};
            if ~all(isfield(context,required))
                error('BLMarkedApexReturnPolicy_v3:MissingContext','Use this policy with PoincareMap_v3.');
            end
            if ~strcmpi(context.section.Name,'apex') || context.section.Direction~=-1
                error('BLMarkedApexReturnPolicy_v3:NotApex','BL marking requires the downward apex geometry.');
            end
            probe=obj.lookahead(context.initial_time,context.initial_state,initialMode,context);
            if ~probe.marked
                error('BLMarkedApexReturnPolicy_v3:OutsideChart', ...
                    'Initial apex is outside the BL marking chart: %s.',probe.reason);
            end
            state.initial_mark=probe;
        end
    end
    methods (Access=protected)
        function [accepted,diagnostics]=acceptCandidate(obj,candidate,state)
            count=0;coincident=false;
            schema=QuadrupedSchema_v3.shared();
            for k=1:numel(candidate.event_history)
                e=candidate.event_history(k);
                if e.is_stop,continue;end
                [leg,kind]=HybridCycleData_v3.eventIdentity(e,schema);
                if isequal(leg,1) && kind=="touchdown"
                    count=count+1;
                    coincident=coincident || abs(e.time-candidate.time)<=obj.TimeTolerance;
                end
            end
            if count>obj.BLTouchdownsPerReturn
                error('BLMarkedApexReturnPolicy_v3:ChartOccurrenceLost', ...
                    'The prescribed BL occurrence was passed before a qualifying apex.');
            end
            mark=struct('marked',false,'reason',"prescribed BL return occurrence has not been reached", ...
                'touchdown_time',NaN,'touchdown_event_index',NaN,'next_apex_time',NaN, ...
                'apex_to_touchdown_margin',NaN,'touchdown_to_next_apex_margin',NaN);
            if count==obj.BLTouchdownsPerReturn && ~coincident
                mark=obj.lookahead(candidate.time,candidate.state,candidate.mode,state.context);
            elseif coincident
                mark.reason="BL touchdown coincides with the apex; strict-before chart is undefined";
            end
            modeClosed=~obj.RequireModeClosure || isequal(logical(candidate.mode(:)),logical(candidate.initial_mode(:)));
            accepted=count==obj.BLTouchdownsPerReturn && mark.marked && modeClosed;
            reason=mark.reason;
            if mark.marked && ~modeClosed,reason="right-continuous section mode has not closed";end
            chart=struct('id',"apex-before-BL-TD-local",'geometry',"dy=0, ddy<0", ...
                'marking',"last downward apex strictly before next BL touchdown", ...
                'BL_touchdowns_per_return',obj.BLTouchdownsPerReturn, ...
                'selected_return_BL_occurrence',count+1,'selected_initial_BL_occurrence',1, ...
                'contact_mode',candidate.mode,'crossing_orientation',-1, ...
                'boundary_ownership',"post-reset/right-continuous", ...
                'time_translation',candidate.time-state.context.initial_time, ...
                'translational_gauge',"system.canonicalizeState", ...
                'return_multiplicity',candidate.index,'initial_mark',state.initial_mark, ...
                'return_mark',mark,'local_domain',"fixed transverse apex and BL event identities, positive separating margins");
            diagnostics=struct('complete',accepted,'reason',reason,'mode_closed',modeClosed, ...
                'BL_touchdown_count',count,'return_multiplicity',candidate.index,'section_chart',chart);
        end
    end
    methods (Access=private)
        function report=lookahead(obj,time,x,q,context)
            opts=struct('InitialTime',time,'MaxReturnTime',obj.LookaheadMaxTime, ...
                'MaxCycleEvents',obj.LookaheadMaxEvents,'MaxSectionCrossings',1);
            map=PoincareMap_v3(context.system,context.section,context.simulator,FirstReturnPolicy_v3(),opts);
            evaluation=struct();
            if isfield(context,'evaluation_options'),evaluation=context.evaluation_options;end
            [~,info]=map.evaluate(x,q,context.parameter,evaluation);
            report=struct('marked',false,'reason',"another downward apex occurs before BL touchdown", ...
                'touchdown_time',NaN,'touchdown_event_index',NaN,'next_apex_time',info.return_time, ...
                'apex_to_touchdown_margin',NaN,'touchdown_to_next_apex_margin',NaN);
            schema=QuadrupedSchema_v3.shared();
            for k=1:numel(info.event_history)
                e=info.event_history(k);[leg,kind]=HybridCycleData_v3.eventIdentity(e,schema);
                if ~isequal(leg,1) || kind~="touchdown",continue;end
                report.touchdown_time=e.time;report.touchdown_event_index=e.index;
                report.apex_to_touchdown_margin=e.time-time;
                report.touchdown_to_next_apex_margin=info.return_time-e.time;
                report.marked=report.apex_to_touchdown_margin>obj.TimeTolerance ...
                    && report.touchdown_to_next_apex_margin>obj.TimeTolerance;
                if report.marked,report.reason="fixed next BL TD occurs strictly between consecutive downward apexes";
                else,report.reason="BL TD lies on an apex chart boundary";end
                return
            end
        end
    end
end
