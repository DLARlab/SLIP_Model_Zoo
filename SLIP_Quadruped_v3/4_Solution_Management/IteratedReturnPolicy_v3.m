classdef IteratedReturnPolicy_v3 < ReturnPolicyBase_v3
    %ITERATEDRETURNPOLICY_V3 Accept the m-th directional section return.
    %   This policy realizes the iterated map P^m without assuming anything
    %   about contact events between successive section crossings.

    properties
        Multiplicity = 1
    end

    methods
        function obj = IteratedReturnPolicy_v3(multiplicity, options)
            obj.Name = 'iterated-section-return';
            if nargin >= 1 && ~isempty(multiplicity)
                obj.Multiplicity = multiplicity;
            end
            if nargin >= 2
                obj = obj.applyOptions(options);
            end
            validateattributes(obj.Multiplicity, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            obj.Multiplicity = double(obj.Multiplicity);
        end
    end

    methods (Access = protected)
        function [accepted, diagnostics] = acceptCandidate( ...
                obj, candidate, ~)
            accepted = candidate.index >= obj.Multiplicity;
            if accepted
                reason = sprintf('requested section iterate P^%d reached', ...
                    obj.Multiplicity);
            else
                reason = sprintf('section iterate %d of %d', ...
                    candidate.index, obj.Multiplicity);
            end
            diagnostics = struct( ...
                'complete', accepted, ...
                'reason', reason, ...
                'requested_multiplicity', obj.Multiplicity, ...
                'return_multiplicity', candidate.index);
        end
    end
end
