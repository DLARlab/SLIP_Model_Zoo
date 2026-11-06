classdef SpeedConstrainedEnergyResidual_v3 < handle
    %SPEEDCONSTRAINEDENERGYRESIDUAL_V3 Free energy plus nonlinear mean speed.
    % For d independent section coordinates: d-1 return closures, H(u)-E,
    % and Delta_x(u)/T(u)-signed_target give d+1 equations in [u;E].
    % The signed target avoids differentiating abs at a travel reversal.
    properties (SetAccess=private)
        Family
        Map
        ClosureTolerance
        SignedTarget
        ResidualScale
    end
    methods
        function obj=SpeedConstrainedEnergyResidual_v3(family,signedTarget,scale)
            n=numel(family.CoordinateIndices)+1;
            if nargin<3||isempty(scale),scale=ones(n,1);end
            validateattributes(signedTarget,{'numeric'},{'scalar','real','finite'});
            if numel(scale)~=n||any(~isfinite(scale(:))|scale(:)<=0)
                error('SpeedConstrainedEnergyResidual_v3:Scale','One positive scale per d+1 equation is required.');
            end
            obj.Family=family;obj.Map=family.Map;obj.ClosureTolerance=family.ClosureTolerance;
            obj.SignedTarget=signedTarget;obj.ResidualScale=scale(:);
        end
        function x=fullState(obj,w,varargin)
            obj.checkDimension(w);x=obj.Family.fullState(w(1:end-1));
        end
        function r=evaluate(obj,w,p,q)
            [r,~]=obj.evaluateWithInfo(w,p,q);
        end
        function [r,info]=evaluateWithInfo(obj,w,p,q,context)
            if nargin<5,context=struct();end
            obj.checkDimension(w);
            if ~isequal(p(:),obj.Family.PhysicalParameter)
                error('SpeedConstrainedEnergyResidual_v3:PhysicalParameter','The ten physical parameters remain fixed.');
            end
            E=w(end);[raw,info]=obj.Family.evaluateWithInfo(w(1:end-1),[p(:);E],q,context);
            schema=QuadrupedSchema_v3.shared();mapInfo=info.map_info;
            delta=mapInfo.stride_displacement(:);T=mapInfo.period;
            if numel(delta)~=schema.StateDimension||any(~isfinite(delta))|| ...
                    ~isscalar(T)||~isfinite(T)||T<=0
                error('SpeedConstrainedEnergyResidual_v3:Observable','Return did not supply a finite full displacement and positive period.');
            end
            signed=delta(schema.TranslationIndex)/T;constraint=signed-obj.SignedTarget;
            physical=[raw(:);constraint];
            info.physical_residual=physical;info.constraint_residual=constraint;
            info.requested_energy=E;info.augmented_energy=E;
            info.mean_signed_velocity=signed;info.speed=abs(signed);
            info.target_signed_velocity=obj.SignedTarget;info.target_speed=abs(obj.SignedTarget);
            info.speed_error=abs(signed)-abs(obj.SignedTarget);
            info.observable_definition='stride_displacement(schema.TranslationIndex)/return_period';
            info.residual_scale=obj.ResidualScale;r=physical./obj.ResidualScale;
            info.scaled_residual=r;
        end
        function orbit=createOrbit(obj,w,p,q,info)
            if nargin<5,[~,info]=obj.evaluateWithInfo(w,p,q);end
            obj.checkDimension(w);
            orbit=obj.Family.createOrbit(w(1:end-1),[p(:);w(end)],q,info);
        end
        function [modes,details]=modeCandidates(obj,varargin)
            [modes,details]=obj.Family.modeCandidates(varargin{:});
        end
    end
    methods (Access=private)
        function checkDimension(obj,w)
            if numel(w)~=numel(obj.Family.CoordinateIndices)+1||any(~isfinite(w(:)))
                error('SpeedConstrainedEnergyResidual_v3:Dimension','Use finite [independent u;free E] coordinates.');
            end
        end
    end
end
