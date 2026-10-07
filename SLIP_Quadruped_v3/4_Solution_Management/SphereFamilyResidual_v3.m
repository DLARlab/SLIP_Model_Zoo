classdef SphereFamilyResidual_v3 < handle
    %SPHEREFAMILYRESIDUAL_V3 Energy-free orbit family intersected with a sphere.
    % d-1 independent closures plus one radius equation for d physical
    % coordinates. E=H(u) is eliminated, never a physical parameter.
    properties (SetAccess=private)
        Family
        Map
        ClosureTolerance
        Origin
        Scale
        Radius
    end
    methods
        function obj=SphereFamilyResidual_v3(family,origin,scale,radius)
            n=numel(family.CoordinateIndices);
            if numel(origin)~=n||numel(scale)~=n||any(~isfinite(origin(:))) ...
                    ||any(~isfinite(scale(:))|scale(:)<=0)||~isscalar(radius)||~isfinite(radius)||radius<=0
                error('SphereFamilyResidual_v3:Sphere','Use finite origin, positive scales and a positive radius.');
            end
            obj.Family=family;obj.Map=family.Map;obj.ClosureTolerance=family.ClosureTolerance;
            obj.Origin=origin(:);obj.Scale=scale(:);obj.Radius=radius;
        end
        function x=fullState(obj,u,varargin)
            x=obj.Family.fullState(u);
        end
        function r=evaluate(obj,u,p,q)
            [r,~]=obj.evaluateWithInfo(u,p,q);
        end
        function [r,info]=evaluateWithInfo(obj,u,p,q,context)
            if nargin<5,context=struct();end
            if ~isequal(p(:),obj.Family.PhysicalParameter)
                error('SphereFamilyResidual_v3:PhysicalParameter','The ten physical parameters remain fixed.');
            end
            x=obj.fullState(u);energy=QuadrupedEnergy_v3.evaluate(x,q,p);
            [raw,info]=obj.Family.evaluateWithInfo(u,[p(:);energy],q,context);
            constraint=norm((u(:)-obj.Origin)./obj.Scale)-obj.Radius;
            r=[raw(1:end-1);constraint];
            info.constraint_residual=constraint;info.physical_residual=r;
            info.sphere_radius=obj.Radius;info.sphere_distance=constraint+obj.Radius;
            info.sphere_scale=obj.Scale;info.eliminated_family_energy=energy;
        end
        function orbit=createOrbit(obj,u,p,q,info)
            if nargin<5,[~,info]=obj.evaluateWithInfo(u,p,q);end
            energy=QuadrupedEnergy_v3.evaluate(obj.fullState(u),q,p);
            orbit=obj.Family.createOrbit(u,[p(:);energy],q,info);
        end
        function [modes,diagnostics]=modeCandidates(obj,varargin)
            [modes,diagnostics]=obj.Family.modeCandidates(varargin{:});
        end
    end
end
