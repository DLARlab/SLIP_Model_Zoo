classdef PeriodicOrbitResidual_v3 < handle
    %PERIODICORBITRESIDUAL_V3 Relative fixed-point equations for P_H.
    %   The ambient state can contain symmetry and section-normal
    %   directions.  UnknownIndices preserve a legacy input layout, while
    %   PeriodicIndices select only independent return-map equations.

    properties
        Map
        TemplateState
        UnknownIndices
        PeriodicIndices
        TangentIndices
        IncludePhaseConstraint = true
        RequireDiscreteClosure = true
    end

    properties (SetAccess = private)
        LastModeResolution = struct()
    end

    methods
        function obj = PeriodicOrbitResidual_v3(map, templateState, options)
            if nargin < 2 || isempty(templateState)
                templateState = zeros(map.System.StateDimension, 1);
            end
            obj.Map = map;
            obj.TemplateState = templateState(:);
            if numel(obj.TemplateState) ~= map.System.StateDimension
                error('PeriodicOrbitResidual_v3:TemplateDimension', ...
                    'TemplateState has the wrong dimension.');
            end

            obj.UnknownIndices = map.System.DefaultUnknownIndices;
            obj.PeriodicIndices = map.System.DefaultPeriodicIndices;
            obj.TangentIndices = map.System.DefaultTangentIndices;
            if isempty(obj.UnknownIndices)
                obj.UnknownIndices = 1:map.System.StateDimension;
            end
            if isempty(obj.PeriodicIndices)
                obj.PeriodicIndices = obj.UnknownIndices;
            end
            if isempty(obj.TangentIndices)
                obj.TangentIndices = obj.PeriodicIndices;
            end

            if nargin >= 3 && ~isempty(options)
                names = fieldnames(options);
                for i = 1:numel(names)
                    if ~isprop(obj, names{i})
                        error('PeriodicOrbitResidual_v3:UnknownOption', ...
                            'Unknown residual option "%s".', names{i});
                    end
                    obj.(names{i}) = options.(names{i});
                end
            end
            obj.validateIndices();
        end

        function x = fullState(obj, u)
            u = u(:);
            if numel(u) ~= numel(obj.UnknownIndices)
                error('PeriodicOrbitResidual_v3:UnknownDimension', ...
                    'Expected %d state unknowns, received %d.', ...
                    numel(obj.UnknownIndices), numel(u));
            end
            x = obj.TemplateState;
            x(obj.UnknownIndices) = u;
        end

        function u = packState(obj, x)
            x = x(:);
            obj.Map.System.validateState(x);
            u = x(obj.UnknownIndices);
        end

        function residual = evaluate(obj, u, p, q)
            [residual, ~] = obj.evaluateWithInfo(u, p, q);
        end

        function [residual, details] = evaluateWithInfo( ...
                obj, u, p, q, evaluationOptions)
            if nargin < 5
                evaluationOptions = struct();
            end
            rawState = obj.fullState(u);
            sectionState = obj.Map.Section.project(rawState, p);
            [nextState, mapInfo] = obj.Map.evaluate( ...
                sectionState, q, p, evaluationOptions);

            periodicResidual = nextState(obj.PeriodicIndices) - ...
                sectionState(obj.PeriodicIndices);
            if obj.IncludePhaseConstraint
                phaseResidual = obj.Map.Section.value(rawState, p);
                residual = [periodicResidual(:); phaseResidual];
            else
                phaseResidual = [];
                residual = periodicResidual(:);
            end

            details = struct();
            details.raw_state = rawState;
            details.section_state = sectionState;
            details.next_state = nextState;
            details.periodic_residual = periodicResidual(:);
            details.phase_residual = phaseResidual;
            details.map_info = mapInfo;
            details.discrete_closed = mapInfo.discrete_closed;
            details.mode_closed = mapInfo.discrete_closed;
            details.return_policy = mapInfo.return_policy;
            details.return_policy_name = mapInfo.return_policy_name;
            details.return_multiplicity = mapInfo.return_multiplicity;
            details.candidate_section_count = ...
                mapInfo.candidate_section_count;
            details.candidate_apex_count = mapInfo.candidate_apex_count;
            details.accepted_crossing_index = ...
                mapInfo.accepted_crossing_index;
            details.accepted_apex_index = mapInfo.accepted_apex_index;
            details.section_relative_event_signature = ...
                mapInfo.section_relative_event_signature;
            details.cyclic_event_signature = ...
                mapInfo.cyclic_event_signature;
            details.event_counts_per_leg = mapInfo.event_counts_per_leg;
            details.event_counts = mapInfo.event_counts;
            details.cycle_completion_diagnostics = ...
                mapInfo.cycle_completion_diagnostics;
            details.guard_transversality_margins = ...
                mapInfo.guard_transversality_margins;
            details.section_transversality = mapInfo.section_transversality;
            details.topology_margins = mapInfo.topology_margins;
            details.section_coincident_events = ...
                mapInfo.section_coincident_events;
            details.schema_metadata = mapInfo.schema_metadata;
            details.success = mapInfo.success;
            details.integration_success = mapInfo.integration_success;
            details.cycle_complete = mapInfo.cycle_complete;
            details.return_policy_accepted = ...
                mapInfo.return_policy_accepted;
            details.guard_transversality_margin = ...
                mapInfo.minimum_guard_transversality;
            details.minimum_guard_transversality = ...
                mapInfo.minimum_guard_transversality;
            details.minimum_stance_admissibility_margin = ...
                mapInfo.minimum_stance_admissibility_margin;
            details.residual_norm = norm(residual, inf);
            details.admissible = logical(mapInfo.admissible) && ...
                (~obj.RequireDiscreteClosure || mapInfo.discrete_closed);
            details.valid = details.admissible;
        end

        function [residual, details] = ambientResidual(obj, u, p, q)
            %AMBIENTRESIDUAL Literal [P_H(x)-x; h(x)] diagnostic.
            %   This vector is intentionally not the default root problem:
            %   it contains symmetry and section-normal redundancies.
            rawState = obj.fullState(u);
            sectionState = obj.Map.Section.project(rawState, p);
            [nextState, mapInfo] = obj.Map.evaluate(sectionState, q, p);
            residual = [nextState - sectionState; ...
                obj.Map.Section.value(rawState, p)];
            details = struct('raw_state', rawState, ...
                'section_state', sectionState, 'next_state', nextState, ...
                'map_info', mapInfo, ...
                'discrete_closed', mapInfo.discrete_closed, ...
                'residual_norm', norm(residual, inf));
        end

        function [candidates, diagnostics] = modeCandidates(obj, u, p, q)
            state = obj.Map.Section.project(obj.fullState(u), p);
            [candidates, resolution] = obj.Map.modeCandidates(state, q, p);
            obj.LastModeResolution = resolution;
            if ~iscell(candidates)
                if isvector(candidates) && ~isscalar(candidates)
                    candidates = {candidates};
                else
                    candidates = num2cell(candidates, 2);
                end
            end
            diagnostics = resolution.candidates;
            for i = 1:numel(diagnostics)
                diagnostics(i).source = 'local-section-mode-resolver';
            end
        end

        function orbit = createOrbit(obj, u, p, q, details)
            if nargin < 5 || isempty(details)
                [~, details] = obj.evaluateWithInfo(u, p, q);
            end
            mapInfo = details.map_info;
            values = struct();
            values.initial_state = details.section_state;
            values.initial_mode = q;
            values.period = mapInfo.period;
            values.parameter = p(:);
            values.event_history = mapInfo.event_history;
            values.mode_history = mapInfo.mode_sequence;
            values.poincare_state = mapInfo.poincare_state;
            values.trajectory = mapInfo.trajectory;
            values.stride_displacement = mapInfo.stride_displacement;
            values.return_policy = mapInfo.return_policy;
            values.return_policy_name = mapInfo.return_policy_name;
            values.return_multiplicity = mapInfo.return_multiplicity;
            values.candidate_section_count = ...
                mapInfo.candidate_section_count;
            values.candidate_apex_count = mapInfo.candidate_apex_count;
            values.accepted_crossing_index = ...
                mapInfo.accepted_crossing_index;
            values.accepted_apex_index = mapInfo.accepted_apex_index;
            values.section_relative_event_signature = ...
                mapInfo.section_relative_event_signature;
            values.cyclic_event_signature = ...
                mapInfo.cyclic_event_signature;
            values.event_counts = mapInfo.event_counts;
            values.event_counts_per_leg = mapInfo.event_counts_per_leg;
            values.guard_transversality_margins = ...
                mapInfo.guard_transversality_margins;
            values.minimum_guard_transversality = ...
                mapInfo.minimum_guard_transversality;
            values.section_transversality = mapInfo.section_transversality;
            values.topology_margins = mapInfo.topology_margins;
            values.minimum_stance_admissibility_margin = ...
                mapInfo.minimum_stance_admissibility_margin;
            values.section_coincident_events = ...
                mapInfo.section_coincident_events;
            values.cycle_completion_diagnostics = ...
                mapInfo.cycle_completion_diagnostics;
            values.schema_metadata = mapInfo.schema_metadata;
            orbit = HybridOrbit_v3(values);
        end

        function n = residualDimension(obj)
            n = numel(obj.PeriodicIndices) + ...
                double(obj.IncludePhaseConstraint);
        end
    end

    methods (Access = private)
        function validateIndices(obj)
            n = obj.Map.System.StateDimension;
            groups = {obj.UnknownIndices, obj.PeriodicIndices, ...
                obj.TangentIndices};
            names = {'UnknownIndices', 'PeriodicIndices', 'TangentIndices'};
            for i = 1:numel(groups)
                indices = groups{i};
                if isempty(indices) || any(indices < 1) || ...
                        any(indices > n) || numel(unique(indices)) ~= numel(indices)
                    error('PeriodicOrbitResidual_v3:InvalidIndices', ...
                        '%s must contain unique valid state indices.', names{i});
                end
            end
            if obj.residualDimension() ~= numel(obj.UnknownIndices)
                warning('PeriodicOrbitResidual_v3:NonSquareResidual', ...
                    ['The configured residual has %d equations for %d ', ...
                     'unknowns. RootSolver_v3 will require a compatible ', ...
                     'least-squares algorithm.'], ...
                    obj.residualDimension(), numel(obj.UnknownIndices));
            end
        end
    end
end
