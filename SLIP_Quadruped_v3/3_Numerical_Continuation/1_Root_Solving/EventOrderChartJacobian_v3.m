classdef EventOrderChartJacobian_v3 < HybridFiniteDifferenceJacobian_v3
    %EVENTORDERCHARTJACOBIAN_V3 Explicit common-C1 quadruped derivative chart.
    % Only compatibility metadata is normalized. Actual return states,
    % physical guards, times, resets, residuals and acceptance are unchanged.
    % The chart admits regular TD-all/LO-all orderings of independent
    % zero-compression leg events. It is not a C2 certificate.
    properties
        PhysicalParameter=[]
        MinimumCohortGap=1e-4
        MaximumGuardValue=2e-8
        BLTouchdownsPerReturn=1
    end
    methods
        function obj=EventOrderChartJacobian_v3(options)
            if nargin<1,options=struct();end
            own={'PhysicalParameter','MinimumCohortGap','MaximumGuardValue','BLTouchdownsPerReturn'};
            base=options;
            for k=1:numel(own)
                if isfield(base,own{k}),base=rmfield(base,own{k});end
            end
            obj@HybridFiniteDifferenceJacobian_v3(base);
            for k=1:numel(own)
                if isfield(options,own{k}),obj.(own{k})=options.(own{k});end
            end
            if ~isempty(obj.PhysicalParameter)
                schema=QuadrupedSchema_v3.shared();
                obj.PhysicalParameter=schema.validateParameter(obj.PhysicalParameter);
            end
            validateattributes(obj.MinimumCohortGap,{'numeric'},{'scalar','real','finite','positive'});
            validateattributes(obj.MaximumGuardValue,{'numeric'},{'scalar','real','finite','positive'});
            validateattributes(obj.BLTouchdownsPerReturn,{'numeric'},{'scalar','integer','>=',1,'<=',2});
        end
        function [matrix,baseValue,report]=compute(obj,callback,point,varargin)
            observations=struct('accepted',{},'reason',{},'chart',{});
            [matrix,baseValue,report]=compute@HybridFiniteDifferenceJacobian_v3( ...
                obj,@chartedCallback,point,varargin{:});
            report.commonC1EventOrderChart=all([observations.accepted]);
            report.eventOrderChartObservations=observations;
            report.derivativeRegularityScope='common-first-derivative-under-recorded-regular-model-hypotheses; no C2 certificate';
            function [value,metadata]=chartedCallback(trial,context,varargin)
                count=nargin(callback);
                if count<0||count>=2+numel(varargin)
                    [value,metadata]=callback(trial,context,varargin{:});
                else
                    [value,metadata]=callback(trial,varargin{:});
                end
                [metadata,diagnostic]=obj.normalizeMetadata(metadata);
                observations(end+1)=diagnostic;
                if ~diagnostic.accepted
                    error('EventOrderChartJacobian_v3:OutsideDeclaredChart', ...
                        'Common C1 event-order derivative chart failed: %s.',diagnostic.reason);
                end
            end
        end
        function [metadata,diagnostic]=normalizeMetadata(obj,metadata)
            diagnostic=struct('accepted',false,'reason','','chart',struct());
            try
                info=metadata;
                if isfield(metadata,'map_info'),info=metadata.map_info;end
                assert(isfield(info,'policy_state')&&isfield(info.policy_state,'context'), ...
                    'Complete physical map context is required.');
                context=info.policy_state.context;
                assert(isfield(context,'system')&&isa(context.system,'Quadrupedal_Dynamics_v3'), ...
                    'The declared chart applies only to the actual v3 quadruped model.');
                system=context.system;
                assert(strcmp(class(system.ContinuousDynamicsComponent),'ContinuousDynamics_v3')&& ...
                    strcmp(class(system.GuardFunctionsComponent),'GuardFunctions_v3')&& ...
                    strcmp(class(system.ResetMapComponent),'ResetMap_v3'), ...
                    'Custom components require their own event-order derivative theorem.');
                p=context.parameter(:);assert(numel(p)==10&&isfinite(p(9)));
                if ~isempty(obj.PhysicalParameter)
                    assert(isequal(p,obj.PhysicalParameter),'The fixed physical parameter changed.');
                end
                chart=info.section_chart;
                cycles=obj.BLTouchdownsPerReturn;
                assert(isfield(chart,'BL_touchdowns_per_return')&&chart.BL_touchdowns_per_return==cycles&& ...
                    chart.selected_return_BL_occurrence==cycles+1, ...
                    'The explicit BL-marked occurrence changed.');
                assert(~any(info.initial_mode)&&~any(info.final_mode), ...
                    'This chart is registered on a flight-to-flight section.');
                assert(info.admissible&&info.discrete_closed&&info.cycle_complete, ...
                    'Physical admissibility, discrete closure or cycle completion failed.');
                assert(info.minimum_guard_transversality>=obj.MinimumGuardTransversality&& ...
                    info.section_transversality>=obj.MinimumSectionTransversality, ...
                    'A guard or the marked section lost transversality.');
                assert(isempty(info.section_coincident_events), ...
                    'A coincident section contact requires separate ownership transport.');
                events=info.event_history;events=events(~[events.is_stop]);
                ids=[events.guard_id];times=[events.time];
                assert(numel(ids)==8*cycles, ...
                    'The explicit actual contact count changed.');
                cohortGaps=zeros(1,2*cycles-1);
                for cycle=1:cycles
                    offset=8*(cycle-1);pair=ids(offset+(1:8));
                    assert(isequal(sort(pair),1:8), ...
                        'Each repeated cohort requires one actual touchdown and liftoff per leg.');
                    assert(all(ismember(pair(1:4),[1,3,5,7]))&& ...
                        all(ismember(pair(5:8),[2,4,6,8])), ...
                        'TD and LO cohorts interleaved or the declared cohort chart changed.');
                    cohortGaps(2*cycle-1)=min(times(offset+(5:8)))-max(times(offset+(1:4)));
                    if cycle<cycles
                        cohortGaps(2*cycle)=min(times(offset+(9:12)))-max(times(offset+(5:8)));
                    end
                end
                gap=min(cohortGaps);
                assert(gap>obj.MinimumCohortGap,'Distinct repeated contact cohorts lost separation.');
                maximum=max(abs([events.value]));
                assert(maximum<=obj.MaximumGuardValue, ...
                    'A reset did not occur on its zero-compression surface.');
                record=struct('id','quadruped-independent-zero-compression-common-C1', ...
                    'raw_cyclic_signature',char(info.cyclic_event_signature), ...
                    'raw_section_signature',char(info.section_relative_event_signature), ...
                    'raw_cluster_signature',char(info.event_cluster_signature), ...
                    'actual_event_ids',ids,'actual_event_times',times, ...
                    'cohort_gap',gap,'maximum_guard_residual',maximum, ...
                    'cohort_gaps',cohortGaps,'BL_touchdowns_per_return',cycles, ...
                    'physical_parameter',p,'hypotheses','regular transverse same-mode explicitly marked return and independent zero-compression leg factors', ...
                    'regularity_scope','common first derivative; C2 unestablished');
                metadata.raw_cyclic_event_signature=info.cyclic_event_signature;
                metadata.raw_section_relative_event_signature=info.section_relative_event_signature;
                metadata.raw_event_cluster_signature=info.event_cluster_signature;
                metadata.cyclic_event_signature='common-C1-TD-BLBRFLFR-LO-BLBRFLFR';
                metadata.section_relative_event_signature='BL-marked-common-C1-TD-LO';
                metadata.event_cluster_signature='common-C1-independent-zero-compression-leg-cohorts';
                if cycles==2
                    metadata.cyclic_event_signature='common-C1-TD-LO-TD-LO-two-BL';
                    metadata.section_relative_event_signature='BL2-marked-common-C1-two-TD-LO-cohorts';
                    metadata.event_cluster_signature='common-C1-independent-zero-compression-two-leg-cohorts';
                end
                metadata.event_order_chart=record;
                diagnostic.accepted=true;diagnostic.reason='verified declared model/cohort chart';diagnostic.chart=record;
            catch exception
                diagnostic.reason=sprintf('%s: %s',exception.identifier,exception.message);
            end
        end
    end
end
