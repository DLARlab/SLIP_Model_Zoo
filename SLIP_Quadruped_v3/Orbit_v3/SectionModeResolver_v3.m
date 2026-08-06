classdef SectionModeResolver_v3 < handle
    %SECTIONMODERESOLVER_V3 Generate local discrete section charts.
    %   The previous accepted mode is always retained. Additional modes are
    %   obtained only by applying model-provided transitions for contact
    %   guards that are both section-near and directionally consistent.
    %   Exhaustive mode enumeration is available only through allModes().

    properties
        SectionModeTolerance = 1e-7
        DirectionTolerance = 1e-10
        DerivativeStep = 1e-7
        MaxCombinationGuards = 8
    end

    methods
        function obj = SectionModeResolver_v3(options)
            if nargin >= 1 && ~isempty(options)
                if ~isstruct(options) || ~isscalar(options)
                    error('SectionModeResolver_v3:InvalidOptions', ...
                        'Resolver options must be a scalar structure.');
                end
                names = fieldnames(options);
                for i = 1:numel(names)
                    if ~isprop(obj, names{i})
                        error('SectionModeResolver_v3:UnknownOption', ...
                            'Unknown resolver option "%s".', names{i});
                    end
                    obj.(names{i}) = options.(names{i});
                end
            end
            validateattributes(obj.SectionModeTolerance, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'nonnegative'});
            validateattributes(obj.DirectionTolerance, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'nonnegative'});
            validateattributes(obj.DerivativeStep, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'positive'});
            validateattributes(obj.MaxCombinationGuards, {'numeric'}, ...
                {'scalar', 'integer', 'nonnegative'});
        end

        function [modes, diagnostics] = resolve( ...
                obj, system, section, x, previousMode, p, time) %#ok<INUSD>
            if nargin < 7 || isempty(time)
                time = 0;
            end
            x = system.validateState(x);
            previousMode = system.validateMode(previousMode);
            p = system.validateParameter(p);

            descriptors = system.guardFunctions( ...
                time, x, previousMode, p);
            if isempty(descriptors)
                descriptors = struct([]);
            end
            guardReport = repmat(SectionModeResolver_v3.guardPrototype(), ...
                numel(descriptors), 1);
            eligible = false(numel(descriptors), 1);
            for i = 1:numel(descriptors)
                descriptor = descriptors(i);
                value = double(descriptor.value);
                derivative = obj.directionalDerivative( ...
                    system, descriptor, time, x, previousMode, p);
                direction = 0;
                if isfield(descriptor, 'direction')
                    direction = double(descriptor.direction);
                end
                near = isfinite(value) && ...
                    abs(value) <= obj.SectionModeTolerance;
                consistent = direction == 0 || ...
                    direction * derivative > obj.DirectionTolerance;
                eligible(i) = near && consistent;

                guardReport(i).id = descriptor.id;
                guardReport(i).name = ...
                    SectionModeResolver_v3.descriptorName(descriptor);
                guardReport(i).value = value;
                guardReport(i).direction = direction;
                guardReport(i).directional_derivative = derivative;
                guardReport(i).near = near;
                guardReport(i).direction_consistent = consistent;
                guardReport(i).eligible = eligible(i);
                if ~near
                    guardReport(i).reason = 'guard is not section-near';
                elseif ~consistent
                    guardReport(i).reason = ...
                        'guard crossing direction is inconsistent';
                else
                    guardReport(i).reason = ...
                        'section-near directionally consistent guard';
                end
            end

            eligibleDescriptors = descriptors(eligible);
            if numel(eligibleDescriptors) > obj.MaxCombinationGuards
                error('SectionModeResolver_v3:TooManyCoincidentGuards', ...
                    ['%d section-near guards exceed MaxCombinationGuards=%d. ', ...
                     'Increase the explicit limit to explore all combinations.'], ...
                    numel(eligibleDescriptors), obj.MaxCombinationGuards);
            end

            maximumCandidates = 2^numel(eligibleDescriptors);
            candidateBuffer = repmat( ...
                SectionModeResolver_v3.candidatePrototype(), ...
                maximumCandidates, 1);
            candidateCount = 1;
            candidateBuffer(1) = SectionModeResolver_v3.makeCandidate( ...
                previousMode, 'previous accepted section mode', [], strings(0, 1));
            rejectionBuffer = repmat( ...
                SectionModeResolver_v3.rejectionPrototype(), ...
                max(0, maximumCandidates - 1), 1);
            rejectedCount = 0;

            nEligible = numel(eligibleDescriptors);
            for mask = 1:(2^nEligible - 1)
                selected = bitget(mask, 1:nEligible) ~= 0;
                batch = eligibleDescriptors(selected);
                [~, order] = sort(SectionModeResolver_v3.priorities(batch));
                batch = batch(order);
                mode = previousMode;
                ids = zeros(numel(batch), 1);
                names = strings(numel(batch), 1);
                failed = false;
                failure = '';
                for j = 1:numel(batch)
                    ids(j) = batch(j).id;
                    names(j) = SectionModeResolver_v3.descriptorName(batch(j));
                    try
                        if ismethod(system, 'adjacentMode')
                            mode = system.adjacentMode(batch(j).id, mode);
                        else
                            mode = system.transition(batch(j).id, mode);
                        end
                    catch exception
                        failed = true;
                        failure = exception.message;
                        break
                    end
                end
                if failed
                    rejectedCount = rejectedCount + 1;
                    rejectionBuffer(rejectedCount) = struct( ...
                        'event_ids', ids, 'event_names', names, ...
                        'reason', failure);
                    continue
                end
                candidates = candidateBuffer(1:candidateCount);
                if SectionModeResolver_v3.containsMode(candidates, mode)
                    continue
                end
                reason = sprintf(['local chart across simultaneous guard ', ...
                    'set {%s}'], strjoin(cellstr(names), ', '));
                candidateCount = candidateCount + 1;
                candidateBuffer(candidateCount) = ...
                    SectionModeResolver_v3.makeCandidate( ...
                    mode, reason, ids, names);
            end

            candidates = candidateBuffer(1:candidateCount);
            rejected = rejectionBuffer(1:rejectedCount);
            modes = {candidates.mode}.';
            diagnostics = struct( ...
                'strategy', 'local-section-guard-resolution', ...
                'previous_mode', previousMode, ...
                'section_mode_tolerance', obj.SectionModeTolerance, ...
                'guards', guardReport, ...
                'candidates', candidates, ...
                'rejected_candidates', rejected, ...
                'all_modes_attempted', false);
        end

        function [modes, diagnostics] = allModes( ...
                ~, system, x, previousMode, p)
            %ALLMODES Explicit exhaustive/debugging mode enumeration.
            modes = system.modeCandidates(x, previousMode, p);
            candidates = repmat(SectionModeResolver_v3.candidatePrototype(), ...
                numel(modes), 1);
            for i = 1:numel(modes)
                candidates(i) = SectionModeResolver_v3.makeCandidate( ...
                    modes{i}, 'explicit exhaustive/debugging search', ...
                    [], strings(0, 1));
            end
            diagnostics = struct( ...
                'strategy', 'explicit-all-modes', ...
                'previous_mode', previousMode, ...
                'section_mode_tolerance', NaN, ...
                'guards', repmat(SectionModeResolver_v3.guardPrototype(), 0, 1), ...
                'candidates', candidates, ...
                'rejected_candidates', ...
                    repmat(SectionModeResolver_v3.rejectionPrototype(), 0, 1), ...
                'all_modes_attempted', true);
        end
    end

    methods (Access = private)
        function derivative = directionalDerivative( ...
                obj, system, descriptor, time, x, q, p)
            if isfield(descriptor, 'directional_derivative') ...
                    && isfinite(descriptor.directional_derivative)
                derivative = double(descriptor.directional_derivative);
                return
            end
            flow = system.flow(time, x, q, p);
            scale = max([1; abs(time); norm(x, inf)]);
            step = obj.DerivativeStep * scale / max(1, norm(flow, inf));
            plus = system.guardFunctions( ...
                time + step, x + step * flow, q, p);
            minus = system.guardFunctions( ...
                time - step, x - step * flow, q, p);
            plusValue = SectionModeResolver_v3.matchValue(plus, descriptor);
            minusValue = SectionModeResolver_v3.matchValue(minus, descriptor);
            derivative = (plusValue - minusValue) / (2 * step);
        end
    end

    methods (Static, Access = private)
        function value = matchValue(descriptors, target)
            matches = false(numel(descriptors), 1);
            if isfield(descriptors, 'id') && isfield(target, 'id')
                matches = reshape([descriptors.id], [], 1) == target.id;
            end
            if ~any(matches)
                names = string({descriptors.name});
                matches = names(:) == ...
                    SectionModeResolver_v3.descriptorName(target);
            end
            index = find(matches, 1);
            if isempty(index)
                error('SectionModeResolver_v3:GuardDisappeared', ...
                    'A guard descriptor disappeared during differentiation.');
            end
            value = double(descriptors(index).value);
        end

        function name = descriptorName(descriptor)
            if isfield(descriptor, 'name')
                name = string(descriptor.name);
            else
                name = "guard";
            end
        end

        function priorities = priorities(descriptors)
            priorities = zeros(numel(descriptors), 1);
            if ~isempty(descriptors) && isfield(descriptors, 'priority')
                priorities = reshape([descriptors.priority], [], 1);
            end
        end

        function tf = containsMode(candidates, mode)
            tf = false;
            for i = 1:numel(candidates)
                if SectionModeResolver_v3.modeEquals(candidates(i).mode, mode)
                    tf = true;
                    return
                end
            end
        end

        function tf = modeEquals(left, right)
            if isnumeric(left) || islogical(left)
                tf = (isnumeric(right) || islogical(right)) ...
                    && isequal(double(left(:)), double(right(:)));
            else
                tf = isequal(left, right);
            end
        end

        function candidate = makeCandidate(mode, reason, ids, names)
            candidate = SectionModeResolver_v3.candidatePrototype();
            candidate.mode = mode;
            candidate.reason = reason;
            candidate.event_ids = ids(:);
            candidate.event_names = names(:);
        end

        function value = candidatePrototype()
            value = struct('mode', [], 'reason', '', ...
                'event_ids', [], 'event_names', strings(0, 1));
        end

        function value = guardPrototype()
            value = struct( ...
                'id', [], 'name', "", 'value', NaN, 'direction', 0, ...
                'directional_derivative', NaN, 'near', false, ...
                'direction_consistent', false, 'eligible', false, ...
                'reason', '');
        end

        function value = rejectionPrototype()
            value = struct('event_ids', [], ...
                'event_names', strings(0, 1), 'reason', '');
        end
    end
end
