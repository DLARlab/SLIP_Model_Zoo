classdef ReturnPolicyBase_v3 < handle
    %RETURNPOLICYBASE_V3 Acceptance contract for section-return candidates.
    %   PoincareMap_v3 locates directional crossings of a geometric section.
    %   A return policy decides which crossing closes the map being computed.
    %   Policies receive cumulative physical event history and right-continuous
    %   section modes; they never prescribe an event ordering.

    properties (SetAccess = protected)
        Name = 'return-policy'
    end

    methods
        function state = initialize(obj, initialMode, context)
            if nargin < 3
                context = struct();
            end
            state = struct( ...
                'policy', class(obj), ...
                'name', obj.Name, ...
                'initial_mode', initialMode, ...
                'candidate_count', 0, ...
                'accepted', false, ...
                'accepted_index', [], ...
                'last_diagnostics', struct(), ...
                'context', context);
        end

        function [accepted, state, diagnostics] = assess( ...
                obj, candidate, state)
            %ASSESS Test one section crossing against the policy contract.
            obj.validateCandidate(candidate);
            if nargin < 3 || isempty(state)
                state = obj.initialize(candidate.initial_mode, struct());
            end
            if state.accepted
                error('ReturnPolicyBase_v3:AlreadyAccepted', ...
                    'A return policy cannot assess candidates after acceptance.');
            end

            state.candidate_count = state.candidate_count + 1;
            [accepted, diagnostics] = obj.acceptCandidate(candidate, state);
            accepted = logical(accepted);
            if ~isscalar(accepted)
                error('ReturnPolicyBase_v3:InvalidDecision', ...
                    'A return-policy decision must be one logical scalar.');
            end
            if ~isstruct(diagnostics) || ~isscalar(diagnostics)
                error('ReturnPolicyBase_v3:InvalidDiagnostics', ...
                    'Return-policy diagnostics must be a scalar structure.');
            end

            diagnostics.policy = class(obj);
            diagnostics.policy_name = obj.Name;
            diagnostics.candidate_index = candidate.index;
            diagnostics.accepted = accepted;
            if ~isfield(diagnostics, 'return_multiplicity')
                diagnostics.return_multiplicity = candidate.index;
            end
            state.last_diagnostics = diagnostics;
            if accepted
                state.accepted = true;
                state.accepted_index = candidate.index;
            end
        end
    end

    methods (Access = protected)
        function [accepted, diagnostics] = acceptCandidate( ...
                obj, candidate, state)
            accepted = false; %#ok<NASGU>
            diagnostics = struct('candidate_index', candidate.index, ...
                'candidate_count', state.candidate_count); %#ok<NASGU>
            error('ReturnPolicyBase_v3:AbstractPolicy', ...
                ['%s defines an interface. Construct a concrete return ', ...
                 'policy.'], class(obj));
        end

        function obj = applyOptions(obj, options)
            if isempty(options)
                return
            end
            if ~isstruct(options) || ~isscalar(options)
                error('ReturnPolicyBase_v3:InvalidOptions', ...
                    'Return-policy options must be a scalar structure.');
            end
            names = fieldnames(options);
            for i = 1:numel(names)
                if ~isprop(obj, names{i})
                    error('ReturnPolicyBase_v3:UnknownOption', ...
                        'Unknown return-policy option "%s".', names{i});
                end
                obj.(names{i}) = options.(names{i});
            end
        end
    end

    methods (Static, Access = private)
        function validateCandidate(candidate)
            required = {'index', 'initial_mode', 'mode', 'event_history'};
            if ~isstruct(candidate) || ~isscalar(candidate)
                error('ReturnPolicyBase_v3:InvalidCandidate', ...
                    'A section-crossing candidate must be a scalar structure.');
            end
            for i = 1:numel(required)
                if ~isfield(candidate, required{i})
                    error('ReturnPolicyBase_v3:InvalidCandidate', ...
                        'Candidate is missing field "%s".', required{i});
                end
            end
            validateattributes(candidate.index, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            if ~isstruct(candidate.event_history)
                error('ReturnPolicyBase_v3:InvalidCandidate', ...
                    'Candidate event_history must be a structure array.');
            end
        end
    end
end
