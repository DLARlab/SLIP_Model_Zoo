classdef OpposedSpreadFamilyResidual_v3 < handle
    %OPPOSEDSPREADFAMILYRESIDUAL_V3 Exact paired opposed-spread restriction.
    % w=(a,b,E): BL/FL=(a,b), BR/FR=(-a,-b), y=E at a flight apex;
    % dx=phi=dphi=0. Actual BL1 sign reversal plus signed amplitude gives
    % three equations. Full physical BL2 finalization/replay remains separate.
    properties (SetAccess=private)
        OneFamily
        TwoFamily
        Map
        ClosureTolerance
        Constraint
        StatePermutation
        SecondReturnTriggerTolerance = 1e-7
        InvariantTolerance = 1e-8
        ContactCohortTolerance = 1e-8
        MinimumAmplitude = 1e-7
    end
    methods
        function obj=OpposedSpreadFamilyResidual_v3(oneFamily,twoFamily,constraint)
            schema=QuadrupedSchema_v3.shared();expected=setdiff(2:14,schema.State.dy,'stable');
            baseline=[10;10;20;20;1;1;0;0;2;.5];
            if ~isa(oneFamily,'EnergyFamilyResidual_v3')||~isa(twoFamily,'EnergyFamilyResidual_v3') ...
                    ||~strcmp(oneFamily.Symmetry,'none')||~strcmp(twoFamily.Symmetry,'none') ...
                    ||any(oneFamily.Chart.mode)||any(twoFamily.Chart.mode) ...
                    ||~isequal(oneFamily.CoordinateIndices(:),expected(:)) ...
                    ||~isequal(oneFamily.CoordinateIndices,twoFamily.CoordinateIndices) ...
                    ||~isequal(oneFamily.Chart.reference_state,twoFamily.Chart.reference_state) ...
                    ||~isequal(oneFamily.PhysicalParameter,baseline)||~isequal(twoFamily.PhysicalParameter,baseline) ...
                    ||~isa(oneFamily.Map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3') ...
                    ||~isa(twoFamily.Map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3') ...
                    ||oneFamily.Map.ReturnPolicy.BLTouchdownsPerReturn~=1 ...
                    ||twoFamily.Map.ReturnPolicy.BLTouchdownsPerReturn~=2
                error('OpposedSpreadFamilyResidual_v3:Chart', ...
                    'Use matching unrestricted flight-apex families, exact baseline parameters and actual BL1/BL2 maps.');
            end
            for map={oneFamily.Map,twoFamily.Map}
                system=map{1}.System;
                if ~isa(system,'Quadrupedal_Dynamics_v3') ...
                        ||~strcmp(class(system.ContinuousDynamicsComponent),'ContinuousDynamics_v3') ...
                        ||~strcmp(class(system.GuardFunctionsComponent),'GuardFunctions_v3') ...
                        ||~strcmp(class(system.ResetMapComponent),'ResetMap_v3')
                    error('OpposedSpreadFamilyResidual_v3:Model','The exact restriction requires the registered production quadruped components.');
                end
            end
            if ~isstruct(constraint)||~all(isfield(constraint,{'reference','normal','target'})) ...
                    ||numel(constraint.reference)~=3||numel(constraint.normal)~=3 ...
                    ||~isscalar(constraint.target)||any(~isfinite([constraint.reference(:);constraint.normal(:);constraint.target])) ...
                    ||norm(constraint.normal(1:2))==0||constraint.normal(3)~=0
                error('OpposedSpreadFamilyResidual_v3:Constraint','Use a finite signed-amplitude constraint in (a,b,E), with zero energy component.');
            end
            permutation=(1:14).';
            for pair=[1,3;2,4]
                statePairs=[schema.Leg.AngleIndices(pair);schema.Leg.RateIndices(pair)];
                permutation(statePairs(:,1))=statePairs(:,2);permutation(statePairs(:,2))=statePairs(:,1);
            end
            obj.OneFamily=oneFamily;obj.TwoFamily=twoFamily;obj.Map=twoFamily.Map;
            obj.ClosureTolerance=min(oneFamily.ClosureTolerance,twoFamily.ClosureTolerance);
            obj.Constraint=constraint;obj.StatePermutation=permutation;
        end
        function x=fullState(obj,w,varargin)
            obj.validateCoordinates(w);schema=QuadrupedSchema_v3.shared();
            x=zeros(14,1);x(schema.State.x)=obj.OneFamily.Chart.reference_state(schema.State.x);
            x(schema.State.y)=w(3);signs=[1;-1;1;-1];
            x(schema.Leg.AngleIndices)=signs*w(1);x(schema.Leg.RateIndices)=signs*w(2);
        end
        function r=evaluate(obj,w,p,q)
            [r,~]=obj.evaluateWithInfo(w,p,q);
        end
        function [r,info]=evaluateWithInfo(obj,w,p,q,context)
            if nargin<5,context=struct();end
            obj.validateCoordinates(w);
            if numel(p)~=11||~isequal(p(1:10),obj.OneFamily.PhysicalParameter)||~isfinite(p(11))
                error('OpposedSpreadFamilyResidual_v3:PhysicalParameters','Keep the ten physical parameters fixed; energy is an internal orbit coordinate.');
            end
            schema=QuadrupedSchema_v3.shared();x=obj.fullState(w);u=obj.OneFamily.packState(x);
            [~,oneInfo]=obj.OneFamily.evaluateWithInfo(u,[p(1:10);w(3)],q,context);
            next=oneInfo.next_state;reducedNext=[next(schema.Leg.AngleIndices(1));next(schema.Leg.RateIndices(1));oneInfo.energy];
            projectedNext=obj.fullState(reducedNext);leak=norm(next(2:end)-projectedNext(2:end),inf);
            events=oneInfo.map_info.event_history;events=events(~[events.is_stop]);
            ids=[events.guard_id];times=[events.time];
            td=find(schema.Event.IsTouchdown);lo=find(~schema.Event.IsTouchdown);
            if numel(ids)~=8||~isequal(sort(ids(1:4)),sort(td))||~isequal(sort(ids(5:8)),sort(lo))
                error('OpposedSpreadFamilyResidual_v3:ContactOwnership','The exact restriction requires one actual synchronous TD and LO per leg.');
            end
            spans=[max(times(1:4))-min(times(1:4)),max(times(5:8))-min(times(5:8))];
            if leak>obj.InvariantTolerance||any(spans>obj.ContactCohortTolerance)
                error('OpposedSpreadFamilyResidual_v3:InvariantBoundary','Actual return lost the registered opposed-spread restriction or synchronized marked ownership.');
            end
            swapped=x(obj.StatePermutation);delta=next-swapped;
            constraint=obj.Constraint.normal(:).'*(w(:)-obj.Constraint.reference(:))-obj.Constraint.target;
            r=[next(schema.Leg.AngleIndices(1))+w(1);next(schema.Leg.RateIndices(1))+w(2);constraint];
            info=oneInfo;info.one_return_info=oneInfo;info.physical_residual=r;info.scaled_residual=r;
            info.constraint_residual=constraint;info.augmented_energy=w(3);
            info.restricted_coordinates=w(:);info.invariant_leak=leak;info.contact_cohort_spans=spans;
            info.full_twisted_closure_residual=delta(2:end);info.full_twisted_closure_norm=norm(delta(2:end),inf);
            info.physical_two_return_evaluated=false;info.two_return_info=struct();info.two_return_failure=struct();
            info.full_physical_closure_residual=[];info.full_physical_closure_norm=Inf;info.full_physical_closed=false;
            info.full_physical_closure_tolerance=obj.ClosureTolerance;
            if norm(r,inf)<=obj.SecondReturnTriggerTolerance
                try
                    [~,twoInfo]=obj.TwoFamily.evaluateWithInfo(u,[p(1:10);w(3)],q,context);
                    info.physical_two_return_evaluated=true;info.two_return_info=twoInfo;
                    info.full_physical_closure_residual=twoInfo.full_physical_closure_residual;
                    info.full_physical_closure_norm=twoInfo.full_physical_closure_norm;
                    info.full_physical_closed=twoInfo.full_physical_closed;
                catch exception
                    info.two_return_failure=struct('identifier',exception.identifier,'message',exception.message);
                end
            end
        end
        function orbit=createOrbit(obj,w,p,q,info)
            if nargin<5,[~,info]=obj.evaluateWithInfo(w,p,q);end
            if ~info.physical_two_return_evaluated||~info.full_physical_closed ...
                    ||info.full_twisted_closure_norm>obj.ClosureTolerance||norm(w(1:2),inf)<=obj.MinimumAmplitude
                error('OpposedSpreadFamilyResidual_v3:PhysicalBL2','Actual full BL2 closure, full twisted closure and nonzero amplitude are required.');
            end
            orbit=obj.TwoFamily.createOrbit(obj.TwoFamily.packState(obj.fullState(w)), ...
                [obj.OneFamily.PhysicalParameter;w(3)],q,info.two_return_info);
        end
        function [modes,diagnostics]=modeCandidates(obj,varargin)
            [modes,diagnostics]=obj.OneFamily.modeCandidates(varargin{:});
        end
    end
    methods (Access=private)
        function validateCoordinates(~,w)
            if numel(w)~=3||any(~isfinite(w(:)))||w(3)<=0
                error('OpposedSpreadFamilyResidual_v3:Dimension','Use finite (a,b,E) coordinates with positive apex height.');
            end
        end
    end
end
