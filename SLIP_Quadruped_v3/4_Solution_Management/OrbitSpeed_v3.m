function observable=OrbitSpeed_v3(orbit,primitivePeriod)
%ORBITSPEED_V3 Scalar signed drift and speed of a primitive native orbit.
% stride_displacement is a full state vector. Only TranslationIndex is x.
% A stored multiple must be reduced/admitted before using this observable.
    schema=QuadrupedSchema_v3.shared();
    if nargin<2||isempty(primitivePeriod),primitivePeriod=orbit.period;end
    validateattributes(primitivePeriod,{'numeric'},{'scalar','real','finite','positive'});
    delta=orbit.stride_displacement(:);
    if numel(delta)~=schema.StateDimension||any(~isfinite(delta))
        error('OrbitSpeed_v3:Displacement','Expected the complete finite native displacement vector.');
    end
    if ~isscalar(orbit.period)||~isfinite(orbit.period)|| ...
            abs(orbit.period-primitivePeriod)>1e-8*max(1,primitivePeriod)
        error('OrbitSpeed_v3:MultipleCover','Displacement and primitive period must describe the same admitted cycle.');
    end
    dx=delta(schema.TranslationIndex);signed=dx/primitivePeriod;
    observable=struct('horizontal_displacement',dx,'primitive_period',primitivePeriod, ...
        'mean_signed_velocity',signed,'speed',abs(signed),'direction',sign(signed), ...
        'apex_dx',orbit.initial_state(schema.State.dx),'translation_index',schema.TranslationIndex, ...
        'definition','Delta_x/T; U=abs(Delta_x/T), using one primitive leg-labeled cycle');
end
