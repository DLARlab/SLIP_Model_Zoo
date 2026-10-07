classdef TwistedReturnFamilyResidual_v3 < handle
    %TWISTEDRETURNFAMILYRESIDUAL_V3 Front-swap BL1 equation, physical BL2 orbit.
    % In a full flight-apex chart solve P1(x)=Sf*x, H(x)=E and a signed
    % amplitude. Sf exchanges FL/FR state pairs and leaves the marked BL
    % identity unchanged. Map exposes P2 solely for physical finalization
    % and independent shared-service replay; Newton metadata remains P1.
    properties (SetAccess=private)
        OneFamily
        TwoFamily
        Map
        ClosureTolerance
        Constraint
        StatePermutation
        CoordinatePermutation
        SecondReturnTriggerTolerance = 1e-7
        MinimumFrontSpread = 1e-7
        CommonC1BroydenMetadata = false
    end
    methods
        function obj=TwistedReturnFamilyResidual_v3(oneFamily,twoFamily,constraint,options)
            if nargin<4,options=struct();end
            allowed={'SecondReturnTriggerTolerance','MinimumFrontSpread','CommonC1BroydenMetadata'};
            if ~isstruct(options)||~isscalar(options)||any(~ismember(fieldnames(options),allowed))
                error('TwistedReturnFamilyResidual_v3:Options','Unknown adapter option.');
            end
            for k=1:numel(allowed)
                name=allowed{k};if isfield(options,name),obj.(name)=options.(name);end
                if strcmp(name,'CommonC1BroydenMetadata')
                    if ~islogical(obj.(name))||~isscalar(obj.(name))
                        error('TwistedReturnFamilyResidual_v3:Options','CommonC1BroydenMetadata must be a logical scalar.');
                    end
                    continue
                end
                if ~isscalar(obj.(name))||~isfinite(obj.(name))||obj.(name)<=0
                    error('TwistedReturnFamilyResidual_v3:Options','Thresholds must be positive and finite.');
                end
            end
            schema=QuadrupedSchema_v3.shared();
            expected=setdiff(2:14,schema.State.dy,'stable');
            if ~isa(oneFamily,'EnergyFamilyResidual_v3')||~isa(twoFamily,'EnergyFamilyResidual_v3') ...
                    ||~strcmp(oneFamily.Symmetry,'none')||~strcmp(twoFamily.Symmetry,'none') ...
                    ||any(oneFamily.Chart.mode)||any(twoFamily.Chart.mode) ...
                    ||~isequal(oneFamily.CoordinateIndices(:),expected(:)) ...
                    ||~isequal(oneFamily.CoordinateIndices,twoFamily.CoordinateIndices) ...
                    ||oneFamily.EnergyPivot~=twoFamily.EnergyPivot ...
                    ||~isequal(oneFamily.Chart.reference_state,twoFamily.Chart.reference_state) ...
                    ||~isequal(oneFamily.PhysicalParameter,twoFamily.PhysicalParameter) ...
                    ||~isa(oneFamily.Map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3') ...
                    ||~isa(twoFamily.Map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3') ...
                    ||oneFamily.Map.ReturnPolicy.BLTouchdownsPerReturn~=1 ...
                    ||twoFamily.Map.ReturnPolicy.BLTouchdownsPerReturn~=2
                error('TwistedReturnFamilyResidual_v3:Chart', ...
                    'Use matching unrestricted flight-apex families with actual BL1 and BL2 maps.');
            end
            permutation=(1:14).';
            front=[schema.Leg.AngleIndices(3:4);schema.Leg.RateIndices(3:4)];
            permutation(front(:,1))=front(:,2);permutation(front(:,2))=front(:,1);
            [found,positions]=ismember(permutation(oneFamily.CoordinateIndices),oneFamily.CoordinateIndices);
            if ~all(found)||positions(oneFamily.EnergyPivot)~=oneFamily.EnergyPivot
                error('TwistedReturnFamilyResidual_v3:EnergyPivot','Front swap must preserve the omitted energy-pivot coordinate.');
            end
            n=numel(expected)+1;
            if ~isstruct(constraint)||~all(isfield(constraint,{'reference','normal','target'})) ...
                    ||numel(constraint.reference)~=n||numel(constraint.normal)~=n ...
                    ||~isscalar(constraint.target)||any(~isfinite([constraint.reference(:);constraint.normal(:);constraint.target])) ...
                    ||norm(constraint.normal)==0||constraint.normal(end)~=0 ...
                    ||norm(constraint.normal(positions)+constraint.normal(1:end-1),inf)>1e-12
                error('TwistedReturnFamilyResidual_v3:Constraint', ...
                    'Use a finite front-antisymmetric signed-amplitude normal in (u,E), with zero energy component.');
            end
            obj.OneFamily=oneFamily;obj.TwoFamily=twoFamily;obj.Map=twoFamily.Map;
            obj.ClosureTolerance=min(oneFamily.ClosureTolerance,twoFamily.ClosureTolerance);
            if obj.SecondReturnTriggerTolerance<obj.ClosureTolerance
                error('TwistedReturnFamilyResidual_v3:Trigger','The physical BL2 trigger must include the closure tolerance.');
            end
            obj.Constraint=constraint;obj.StatePermutation=permutation;obj.CoordinatePermutation=positions(:);
        end
        function x=fullState(obj,w,varargin)
            obj.validateCoordinates(w);x=obj.OneFamily.fullState(w(1:end-1));
        end
        function r=evaluate(obj,w,p,q)
            [r,~]=obj.evaluateWithInfo(w,p,q);
        end
        function [r,info]=evaluateWithInfo(obj,w,p,q,context)
            if nargin<5,context=struct();end
            obj.validateCoordinates(w);
            if numel(p)~=11||~isequal(p(1:10),obj.OneFamily.PhysicalParameter)||~isfinite(p(11))
                error('TwistedReturnFamilyResidual_v3:PhysicalParameters','Keep ten physical parameters fixed; append only an internal reference energy.');
            end
            u=w(1:end-1);E=w(end);parameter=[obj.OneFamily.PhysicalParameter;E];
            [~,oneInfo]=obj.OneFamily.evaluateWithInfo(u,parameter,q,context);
            x=obj.fullState(w);swapped=x(obj.StatePermutation);
            swappedEnergy=QuadrupedEnergy_v3.evaluate(swapped,q,parameter(1:10));
            energyDifference=swappedEnergy-oneInfo.energy;
            if abs(energyDifference)>100*eps(max(1,abs(oneInfo.energy)))
                error('TwistedReturnFamilyResidual_v3:EnergySymmetry','The physical front swap failed energy invariance.');
            end
            delta=oneInfo.next_state-swapped;
            constraint=obj.Constraint.normal(:).'*(w(:)-obj.Constraint.reference(:))-obj.Constraint.target;
            r=[delta(obj.OneFamily.CoordinateIndices(obj.OneFamily.ClosureIndices));oneInfo.energy-E;constraint];
            info=oneInfo;
            % Preserve the actual one-return state and event metadata. Its
            % ordinary P1-x closure is distinct from the twisted objective.
            info.one_return_info=oneInfo;
            info.front_swapped_state=swapped;
            info.full_twisted_closure_residual=delta(2:end);
            info.full_twisted_closure_norm=norm(delta(2:end),inf);
            info.physical_residual=r;info.scaled_residual=r;
            info.constraint_residual=constraint;info.augmented_energy=E;
            info.front_swap_energy_difference=energyDifference;
            info.front_spread=norm(x([11,12])-x([13,14]),inf);
            info.physical_two_return_evaluated=false;info.two_return_info=struct();
            info.two_return_failure=struct();
            info.full_physical_closure_residual=[];
            info.full_physical_closure_norm=Inf;info.full_physical_closed=false;
            info.full_physical_closure_tolerance=obj.ClosureTolerance;
            % An admissible nonperiodic one-return objective stays valid.
            % Failure of the additional physical two-return check is retained
            % separately and can never supply a fictitious closed orbit.
            if norm(r,inf)<=obj.SecondReturnTriggerTolerance
                try
                    [~,twoInfo]=obj.TwoFamily.evaluateWithInfo(u,parameter,q,context);
                    info.physical_two_return_evaluated=true;info.two_return_info=twoInfo;
                    info.full_physical_closure_residual=twoInfo.full_physical_closure_residual;
                    info.full_physical_closure_norm=twoInfo.full_physical_closure_norm;
                    info.full_physical_closed=twoInfo.full_physical_closed;
                catch exception
                    info.two_return_failure=struct('identifier',exception.identifier,'message',exception.message);
                end
            end
            if obj.CommonC1BroydenMetadata
                [info,~]=obj.normalizeBroydenMetadata(info);
            end
        end
        function [info,diagnostic]=normalizeBroydenMetadata(obj,rawInfo)
            % Only verified actual BL1 trajectories receive common-C1
            % compatibility keys. A rejected chart retains raw metadata;
            % it grants no normalized Broyden compatibility.
            validator=EventOrderChartJacobian_v3(struct( ...
                'PhysicalParameter',obj.OneFamily.PhysicalParameter,'BLTouchdownsPerReturn',1));
            [normalized,diagnostic]=validator.normalizeMetadata(rawInfo);
            if diagnostic.accepted,info=normalized;else,info=rawInfo;end
            info.common_C1_Broyden_compatibility=diagnostic;
            info.common_C1_Broyden_normalization_used=diagnostic.accepted;
        end
        function orbit=createOrbit(obj,w,p,q,info)
            if nargin<5,[~,info]=obj.evaluateWithInfo(w,p,q);end
            if ~info.physical_two_return_evaluated||~info.full_physical_closed ...
                    ||info.full_twisted_closure_norm>obj.ClosureTolerance ...
                    ||info.front_spread<=obj.MinimumFrontSpread
                error('TwistedReturnFamilyResidual_v3:PhysicalBL2', ...
                    'Actual BL2 closure, full twisted closure and nonzero front spread are required.');
            end
            orbit=obj.TwoFamily.createOrbit(w(1:end-1), ...
                [obj.OneFamily.PhysicalParameter;w(end)],q,info.two_return_info);
        end
        function [modes,diagnostics]=modeCandidates(obj,varargin)
            [modes,diagnostics]=obj.OneFamily.modeCandidates(varargin{:});
        end
    end
    methods (Access=private)
        function validateCoordinates(obj,w)
            if numel(w)~=numel(obj.OneFamily.CoordinateIndices)+1||any(~isfinite(w(:)))
                error('TwistedReturnFamilyResidual_v3:Dimension','Use finite (u,E) coordinates in the full physical flight-apex chart.');
            end
        end
    end
end
