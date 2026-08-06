classdef FirstReturnPolicy_v3 < ReturnPolicyBase_v3
    %FIRSTRETURNPOLICY_V3 Accept the first valid directional section return.

    methods
        function obj = FirstReturnPolicy_v3(options)
            obj.Name = 'first-section-return';
            if nargin >= 1
                obj = obj.applyOptions(options);
            end
        end
    end

    methods (Access = protected)
        function [accepted, diagnostics] = acceptCandidate( ...
                ~, candidate, ~)
            accepted = candidate.index == 1;
            diagnostics = struct( ...
                'complete', accepted, ...
                'reason', 'first valid directional section crossing', ...
                'return_multiplicity', 1);
        end
    end
end
