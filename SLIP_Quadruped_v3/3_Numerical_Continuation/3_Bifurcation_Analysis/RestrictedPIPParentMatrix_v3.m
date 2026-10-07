function [matrix,info]=RestrictedPIPParentMatrix_v3(energy,parameter,options)
%RESTRICTEDPIPPARENTMATRIX_V3 Variational map of the baseline vertical parent.
% Coordinates are [dx; common alpha; common dalpha] on the fixed-energy
% flight apex, with y=E-dx^2/2. This is restricted to synchronized pronk and
% to the exact documented baseline p. It is not a full-space derivative.
% The vertical trajectory is analytic; its 2-by-2 stance variational
% fundamental matrix is integrated numerically. Contact timing variations
% vanish to first order at the vertical parent in this fixed-energy chart.
    baseline=[10;10;20;20;1;1;0;0;2;.5];
    if nargin<2||isempty(parameter),parameter=baseline;end
    if nargin<3,options=struct();end
    if ~isequal(parameter(:),baseline)
        error('RestrictedPIPParentMatrix_v3:Parameters', ...
            'This restricted formula requires the exact baseline physical parameters.');
    end
    validateattributes(energy,{'numeric'},{'real','finite','scalar','>',1,'<',20});
    relativeTolerance=option(options,'RelTol',1e-12);
    absoluteTolerance=option(options,'AbsTol',1e-14);
    validateattributes(relativeTolerance,{'numeric'},{'real','finite','scalar','positive'});
    validateattributes(absoluteTolerance,{'numeric'},{'real','finite','scalar','positive'});
    touchdownSpeed=sqrt(2*(energy-1));verticalFrequency=sqrt(40);
    swingFrequency=sqrt(20);a=1/40;
    stanceTime=(2*pi-2*atan(touchdownSpeed/(a*verticalFrequency)))/verticalFrequency;
    minimumHeight=1-a-sqrt(a^2+(touchdownSpeed/verticalFrequency)^2);
    flight=eye(3);phase=swingFrequency*touchdownSpeed;
    flight(2:3,2:3)=[cos(phase),sin(phase)/swingFrequency; ...
        -swingFrequency*sin(phase),cos(phase)];
    touchdownReduction=[1,0,0;0,1,0];
    liftoffLift=[1,0;0,1;-1,-touchdownSpeed];
    maximumStep=option(options,'MaxStep',stanceTime/100);
    validateattributes(maximumStep,{'numeric'},{'real','finite','scalar','positive'});
    integration=odeset('RelTol',relativeTolerance,'AbsTol',absoluteTolerance,'MaxStep',maximumStep);
    [times,states]=ode45(@variational,[0,stanceTime],reshape(eye(2),4,1),integration);
    stance=reshape(states(end,:).',2,2);
    matrix=flight*liftoffLift*stance*touchdownReduction*flight;
    info=struct('schema_version','restricted-baseline-PIP-variational-v3-1', ...
        'method','analytic vertical orbit with numerically integrated restricted stance variational flow', ...
        'coordinate_order',{{'dx','common_alpha','common_dalpha'}}, ...
        'restriction','synchronized pronk, fixed energy, flight apex, exact baseline parameters', ...
        'energy',energy,'physical_parameter',parameter(:),'flight_time',touchdownSpeed, ...
        'stance_time',stanceTime,'period',2*touchdownSpeed+stanceTime, ...
        'minimum_vertical_height',minimumHeight,'flight_matrix',flight, ...
        'touchdown_reduction',touchdownReduction,'stance_matrix',stance,'liftoff_lift',liftoffLift, ...
        'RelTol',relativeTolerance,'AbsTol',absoluteTolerance,'MaxStep',maximumStep, ...
        'variational_output_points',numel(times),'matrix_rank',rank(matrix), ...
        'determinant_DP_minus_I',det(matrix-eye(3)), ...
        'allReliable',true,'classicalDerivative',true,'mapEvaluations',0, ...
        'scope_limitation','No unrestricted quadruped derivative or higher-order contact regularity certificate.');
    function derivative=variational(time,packed)
        height=1-a+a*cos(verticalFrequency*time) ...
            -touchdownSpeed/verticalFrequency*sin(verticalFrequency*time);
        verticalVelocity=-a*verticalFrequency*sin(verticalFrequency*time) ...
            -touchdownSpeed*cos(verticalFrequency*time);
        generator=[0,-40*(1-height);-1/height,-verticalVelocity/height];
        derivative=reshape(generator*reshape(packed,2,2),4,1);
    end
end

function value=option(options,name,fallback)
    if isfield(options,name),value=options.(name);else,value=fallback;end
end
