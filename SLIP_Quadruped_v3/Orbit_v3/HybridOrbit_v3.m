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
        return_policy = ""
        return_policy_name = ""
        return_multiplicity = 1
        candidate_section_count = 0
        candidate_apex_count = 0
        accepted_crossing_index = []
        accepted_apex_index = []
        section_relative_event_signature = ""
        cyclic_event_signature = ""
        event_cluster_report = struct()
        event_clusters = struct([])
        event_cluster_count = 0
        event_cluster_signature = ""
        cyclic_event_cluster_signature = ""
        event_cluster_members = {}
        event_cluster_names = {}
        event_cluster_center_times = []
        maximum_intra_cluster_spread = 0
        minimum_intercluster_gap = Inf
        cluster_relative_phase = []
        section_cluster_coincidence = false
        section_coincident_cluster_indices = []
        event_cluster_split_merge_diagnostics = struct()
        event_counts = struct([])
        event_counts_per_leg = struct([])
        guard_transversality_margins = []
        minimum_guard_transversality = NaN
        section_transversality = NaN
        topology_margins = struct()
        minimum_stance_admissibility_margin = Inf
        minimum_physical_margin = Inf
        minimum_physical_margins = struct()
        initial_section_admissibility = struct()
        section_return_admissibility = struct()
        section_coincident_events = struct([])
        cycle_completion_diagnostics = struct()
        schema_metadata = struct()
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
