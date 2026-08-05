classdef HybridOrbit_v3 < handle
    %HYBRIDORBIT_V3 Data object for one periodic hybrid orbit.
    %   Gait classification is intentionally absent.  It is a downstream
    %   interpretation of event_history, never part of the solved orbit.

    properties
        initial_state = []
        initial_mode = []
        period = NaN
        parameter = []
        event_history = struct([])
        mode_history = {}
        poincare_state = []
        floquet_multiplier = []
        stability = struct()
        trajectory = []
        stride_displacement = []
    end

    methods
        function obj = HybridOrbit_v3(values)
            if nargin < 1 || isempty(values)
                return
            end
            if ~isstruct(values)
                error('HybridOrbit_v3:InvalidInput', ...
                    'Constructor input must be a structure.');
            end
            names = fieldnames(values);
            for i = 1:numel(names)
                name = names{i};
                if ~isprop(obj, name)
                    error('HybridOrbit_v3:UnknownProperty', ...
                        'Unknown orbit property "%s".', name);
                end
                obj.(name) = values.(name);
            end
            obj.validate();
        end

        function setFloquetResult(obj, result)
            if isempty(result)
                obj.floquet_multiplier = [];
                obj.stability = struct();
                return
            end
            if isfield(result, 'multipliers')
                obj.floquet_multiplier = result.multipliers;
            end
            obj.stability = result;
        end

        function data = toStruct(obj)
            names = properties(obj);
            data = struct();
            for i = 1:numel(names)
                data.(names{i}) = obj.(names{i});
            end
        end

        function validate(obj)
            if ~isempty(obj.initial_state) && ...
                    any(~isfinite(obj.initial_state(:)))
                error('HybridOrbit_v3:InvalidState', ...
                    'initial_state must be finite.');
            end
            if ~(isnan(obj.period) || ...
                    (isscalar(obj.period) && isfinite(obj.period) && ...
                    obj.period > 0))
                error('HybridOrbit_v3:InvalidPeriod', ...
                    'period must be positive and finite.');
            end
            if ~isempty(obj.parameter) && ...
                    any(~isfinite(obj.parameter(~isinf(obj.parameter))))
                error('HybridOrbit_v3:InvalidParameter', ...
                    'parameter contains NaN values.');
            end
        end
    end
end
