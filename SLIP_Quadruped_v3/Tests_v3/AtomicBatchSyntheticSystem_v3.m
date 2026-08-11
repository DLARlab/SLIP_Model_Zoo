classdef AtomicBatchSyntheticSystem_v3 < HybridSystemBase_v3
    %ATOMICBATCHSYNTHETICSYSTEM_V3 Coupled-reset fixture for batch tests.

    properties (SetAccess = private)
        Priorities
    end

    methods
        function obj = AtomicBatchSyntheticSystem_v3(priorities)
            if nargin < 1
                priorities = [1, 2];
            end
            validateattributes(priorities, {'numeric'}, ...
                {'vector', 'numel', 2, 'real', 'finite'});
            config = struct( ...
                'StateDimension', 1, ...
                'ParameterDimension', 0, ...
                'ModeSet', (0:3).', ...
                'StateNames', {{'clock'}}, ...
                'ParameterNames', {{}}, ...
                'FlowFunction', @(t, x, q, p) 1, ...
                'ResetFunction', @AtomicBatchSyntheticSystem_v3.scalarReset, ...
                'TransitionFunction', ...
                    @AtomicBatchSyntheticSystem_v3.scalarTransition);
            obj@HybridSystemBase_v3(config);
            obj.Priorities = priorities(:).';
        end

        function guards = activeGuards(obj, t, x, q, p) %#ok<INUSD>
            x = obj.validateState(x);
            q = obj.validateMode(q);
            obj.validateParameter(p);
            if q ~= 0
                guards = struct([]);
                return
            end
            prototype = struct( ...
                'id', 0, 'name', "", 'value', x(1) - 1, ...
                'direction', 1, 'isterminal', true, 'enabled', true, ...
                'priority', 0, 'kind', "impact", 'leg_index', [], ...
                'interior_sign', -1, 'directional_derivative', 1, ...
                'metadata', struct('source', 'atomic-batch-test'));
            guards = repmat(prototype, 2, 1);
            for index = 1:2
                guards(index).id = index;
                guards(index).name = "impact_" + index;
                guards(index).priority = obj.Priorities(index);
            end
        end

        function [xplus, qplus, batchInfo] = resolveEventBatch(obj, ...
                eventIds, t, xminus, qminus, p) %#ok<INUSD>
            xminus = obj.validateState(xminus);
            obj.validateMode(qminus);
            obj.validateParameter(p);
            ids = AtomicBatchSyntheticSystem_v3.numericIds(eventIds);
            if numel(ids) ~= 2 || ~isequal(sort(ids), [1; 2])
                error('AtomicBatchSyntheticSystem_v3:UnexpectedBatch', ...
                    'The atomic fixture expects events 1 and 2 together.');
            end

            % This deliberately is not either scalar reset product.  It is a
            % stand-in for one coupled impulse solve performed from xminus.
            xplus = xminus + 10;
            qplus = 3;
            batchInfo = struct( ...
                'semantics', "coupled-atomic-test-reset", ...
                'atomic', true, ...
                'fallback', false, ...
                'priority_independent', true, ...
                'commutativity_checked', false, ...
                'reset_order_commutes', false, ...
                'transition_order_commutes', true, ...
                'commutativity_error', 1);
        end
    end

    methods (Static, Access = private)
        function xplus = scalarReset(eventId, t, xminus, qminus, p) %#ok<INUSD>
            if eventId == 1
                xplus = 2 * xminus;
            elseif eventId == 2
                xplus = xminus + 1;
            else
                error('AtomicBatchSyntheticSystem_v3:UnknownEvent', ...
                    'Unknown synthetic event ID.');
            end
        end

        function qplus = scalarTransition(eventId, qminus)
            qplus = bitset(uint8(qminus), eventId, true);
            qplus = double(qplus);
        end

        function ids = numericIds(eventIds)
            if iscell(eventIds)
                ids = cellfun(@double, eventIds(:));
            else
                ids = double(eventIds(:));
            end
        end
    end
end
