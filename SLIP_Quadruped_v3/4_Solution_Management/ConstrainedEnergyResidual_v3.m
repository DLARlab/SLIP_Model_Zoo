classdef ConstrainedEnergyResidual_v3 < handle
    %CONSTRAINEDENERGYRESIDUAL_V3 Shared fixed and augmented family equations.
    % An augmented energy is an orbit coordinate; PhysicalParameter stays 10D.
    properties (SetAccess=private)
        Family
        Map
        ClosureTolerance
        ActivePositions
        ReferenceCoordinates
        EquationPositions
        Constraint
        Augmented
        ResidualScale
    end
    methods
        function obj=ConstrainedEnergyResidual_v3(family,active,constraint,scale)
            obj.Family=family;obj.Map=family.Map;
            obj.ClosureTolerance=family.ClosureTolerance;
            n=numel(family.CoordinateIndices);
            if isempty(active),active=1:n;end
            if numel(unique(active))~=numel(active)||any(active<1|active>n) ...
                    || ~ismember(family.EnergyPivot,active)
                error('ConstrainedEnergyResidual_v3:ActiveCoordinates', ...
                    'Active positions must be unique valid family coordinates including its energy pivot.');
            end
            obj.ActivePositions=active(:);
            obj.ReferenceCoordinates=family.packState(family.Chart.reference_state);
            obj.EquationPositions=[find(ismember(family.ClosureIndices,active)),n];
            obj.Constraint=constraint;obj.Augmented=~isempty(constraint);
            count=numel(active)+double(obj.Augmented);
            if isempty(scale),scale=ones(count,1);end
            if numel(scale)~=count||any(~isfinite(scale(:))|scale(:)<=0)
                error('ConstrainedEnergyResidual_v3:Scale','ResidualScale requires one positive scale per equation.');
            end
            obj.ResidualScale=scale(:);
            if obj.Augmented
                if numel(constraint.reference)~=count||numel(constraint.normal)~=count ...
                        ||~isscalar(constraint.target)||any(~isfinite([constraint.reference(:);constraint.normal(:);constraint.target])) ...
                        ||norm(constraint.normal)==0
                    error('ConstrainedEnergyResidual_v3:Constraint', ...
                        'A finite nonzero linear normal and reference in (active u,E) are required.');
                end
            end
        end
        function [u,energy]=unpack(obj,w,p)
            u=obj.ReferenceCoordinates;u(obj.ActivePositions)=w(1:numel(obj.ActivePositions));
            if obj.Augmented,energy=w(end);else,energy=p(11);end
        end
        function x=fullState(obj,w,varargin)
            u=obj.ReferenceCoordinates;u(obj.ActivePositions)=w(1:numel(obj.ActivePositions));
            x=obj.Family.fullState(u);
        end
        function r=evaluate(obj,w,p,q)
            [r,~]=obj.evaluateWithInfo(w,p,q);
        end
        function [r,info]=evaluateWithInfo(obj,w,p,q,context)
            if nargin<5,context=struct();end
            [u,E]=obj.unpack(w,p);parameter=[obj.Family.PhysicalParameter;E];
            [raw,info]=obj.Family.evaluateWithInfo(u,parameter,q,context);
            r=raw(obj.EquationPositions);
            if obj.Augmented
                constraintValue=obj.Constraint.normal(:).'*(w(:)-obj.Constraint.reference(:))-obj.Constraint.target;
                r=[r(:);constraintValue];
            else,constraintValue=0;end
            info.physical_residual=r(:);info.constraint_residual=constraintValue;
            info.augmented_energy=E;info.residual_scale=obj.ResidualScale;
            r=r(:)./obj.ResidualScale;info.scaled_residual=r;
        end
        function orbit=createOrbit(obj,w,p,q,info)
            if nargin<5,[~,info]=obj.evaluateWithInfo(w,p,q);end
            [u,E]=obj.unpack(w,p);
            orbit=obj.Family.createOrbit(u,[obj.Family.PhysicalParameter;E],q,info);
        end
        function [modes,details]=modeCandidates(obj,varargin)
            [modes,details]=obj.Family.modeCandidates(varargin{:});
        end
    end
end
