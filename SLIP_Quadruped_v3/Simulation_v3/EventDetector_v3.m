classdef EventDetector_v3
    %EVENTDETECTOR_V3 Integrate one mode and locate its earliest event.
    %
    % The detector freezes the active-guard set over a smooth integration
    % segment, as required by a fixed discrete mode.  Guards that start on
    % zero are initially unarmed.  They are armed only after entering the
    % directional pre-crossing interior, preventing zero-time retriggers
    % without advancing the physical clock artificially.

    properties (SetAccess = private)
        Options
    end

    methods
        function obj = EventDetector_v3(options)
            if nargin < 1
                options = struct();
            end
            obj.Options = EventDetector_v3.mergeOptions( ...
                EventDetector_v3.defaultOptions(), options);
        end

        function [segment, event] = integrate(obj, system, x0, q, p, ...
                tspan, stopCondition, odeOptions)
            %INTEGRATE Propagate one continuous-mode segment.
            if nargin < 7 || isempty(stopCondition)
                stopCondition = [];
            end
            if nargin < 8 || isempty(odeOptions)
                odeOptions = odeset();
            end
            validateattributes(tspan, {'numeric'}, ...
                {'vector', 'numel', 2, 'real', 'finite'});
            tspan = tspan(:).';
            if tspan(2) <= tspan(1)
                error('EventDetector_v3:InvalidTimeSpan', ...
                    'TSPAN must contain increasing start and final times.');
            end
            x0 = x0(:);

            guardTemplate = obj.guardDescriptors(system, ...
                tspan(1), x0, q, p);
            stopTemplate = obj.stopDescriptors(stopCondition, ...
                tspan(1), x0, q, p);
            guardCount = numel(guardTemplate);
            stopCount = numel(stopTemplate);

            guardArmed = obj.initialArming(guardTemplate);
            stopArmed = obj.initialArming(stopTemplate);
            guardInterior = obj.interiorSigns(guardTemplate);
            stopInterior = obj.interiorSigns(stopTemplate);

            odeOptions = obj.configureOdeOptions(odeOptions);
            if guardCount + stopCount > 0
                odeOptions = odeset(odeOptions, 'Events', @eventFunction);
            end

            solver = obj.Options.ODESolver;
            if ischar(solver) || isstring(solver)
                solver = str2func(char(solver));
            end
            flow = @(t, x) obj.evaluateFlow(system, t, x, q, p);
            try
                if guardCount + stopCount > 0
                    [time, state, eventTime, eventState, eventIndex] = ...
                        solver(flow, tspan, x0, odeOptions);
                else
                    [time, state] = solver(flow, tspan, x0, odeOptions);
                    eventTime = [];
                    eventState = [];
                    eventIndex = [];
                end
            catch exception
                wrapped = MException('EventDetector_v3:IntegrationFailed', ...
                    'Continuous integration failed in the active mode.');
                wrapped = addCause(wrapped, exception);
                throwAsCaller(wrapped);
            end

            segment = struct('time', time(:), 'state', state);
            if isempty(eventTime)
                event = obj.noEvent(time(end), state(end, :).');
                return;
            end

            firstTime = min(eventTime);
            timeTolerance = obj.timeTolerance(firstTime);
            firstRows = find(abs(eventTime - firstTime) <= timeTolerance);
            firstRow = firstRows(1);
            eventStateVector = eventState(firstRow, :).';
            % MATLAB can report an early terminal root and still return
            % later samples (in particular at a near-initial event). Only
            % the smooth flow up to the selected earliest event belongs to
            % this mode; later samples cannot precede its reset.
            if firstTime < tspan(1)
                error('EventDetector_v3:EventBeforeSpan', ...
                    'The solver reported an event before the integration span.');
            end
            before = time(:) < firstTime;
            segment.time = [time(before); firstTime];
            segment.state = [state(before, :); eventStateVector.'];
            triggeredChannels = unique(eventIndex(firstRows));

            [guardBatch, stopBatch] = obj.clusterAtEvent( ...
                system, stopCondition, firstTime, eventStateVector, ...
                q, p, guardTemplate, stopTemplate, triggeredChannels);
            event = struct( ...
                'occurred', true, ...
                'time', firstTime, ...
                'state', eventStateVector, ...
                'guard_batch', guardBatch, ...
                'stop_batch', stopBatch, ...
                'stop_occurred', ~isempty(stopBatch), ...
                'triggered_channels', triggeredChannels(:), ...
                'raw_event_times', eventTime(:), ...
                'raw_event_indices', eventIndex(:));

            function [value, isterminal, direction] = eventFunction(t, x)
                guards = obj.guardDescriptors(system, t, x, q, p);
                guardValues = obj.valuesInTemplateOrder( ...
                    guardTemplate, guards);
                stops = obj.stopDescriptors(stopCondition, t, x, q, p);
                stopValues = obj.stopValuesInTemplateOrder( ...
                    stopTemplate, stops);

                [guardValues, guardArmed] = obj.applyArming( ...
                    guardValues, guardArmed, guardInterior);
                [stopValues, stopArmed] = obj.applyArming( ...
                    stopValues, stopArmed, stopInterior);

                value = [guardValues; stopValues];
                % Every system guard is terminal for the current smooth
                % segment; the simulator applies its reset and restarts.
                isterminal = ones(size(value));
                direction = [obj.descriptorDirections(guardTemplate); ...
                    obj.descriptorDirections(stopTemplate)];
            end
        end
    end

    methods (Access = private)
        function options = configureOdeOptions(obj, options)
            if ~isempty(obj.Options.RelTol)
                options = odeset(options, 'RelTol', obj.Options.RelTol);
            end
            if ~isempty(obj.Options.AbsTol)
                options = odeset(options, 'AbsTol', obj.Options.AbsTol);
            end
            if ~isempty(obj.Options.MaxStep) && isfinite(obj.Options.MaxStep)
                options = odeset(options, 'MaxStep', obj.Options.MaxStep);
            end
        end

        function flow = evaluateFlow(~, system, t, x, q, p)
            flow = system.flow(t, x, q, p);
            flow = flow(:);
            if numel(flow) ~= numel(x) || any(~isfinite(flow))
                error('EventDetector_v3:InvalidFlow', ...
                    'SYSTEM.FLOW must return one finite derivative per state.');
            end
        end

        function descriptors = guardDescriptors(~, system, t, x, q, p)
            descriptors = system.activeGuards(t, x, q, p);
            descriptors = EventDetector_v3.normalizeDescriptors( ...
                descriptors, "guard");
        end

        function descriptors = stopDescriptors(obj, condition, t, x, q, p)
            if isempty(condition)
                descriptors = EventDetector_v3.emptyDescriptors();
                return;
            end

            wrapper = struct();
            if isstruct(condition) && isscalar(condition) && ...
                    isfield(condition, 'Function')
                wrapper = condition;
                condition = condition.Function;
            end
            if isa(condition, 'function_handle')
                [raw, terminal, direction, metadata] = ...
                    obj.callStopFunction(condition, t, x, q, p);
            elseif isobject(condition) && ismethod(condition, 'evaluate')
                raw = condition.evaluate(t, x, q, p);
                terminal = [];
                direction = [];
                metadata = struct();
            elseif isstruct(condition)
                raw = condition;
                terminal = [];
                direction = [];
                metadata = struct();
            else
                error('EventDetector_v3:InvalidStopCondition', ...
                    ['StopCondition must be a function handle, descriptor ', ...
                     'structure, or object with an evaluate method.']);
            end

            if isstruct(raw)
                descriptors = EventDetector_v3.normalizeDescriptors( ...
                    raw, "stop");
            else
                values = raw(:);
                if isempty(terminal)
                    terminal = true(size(values));
                end
                if isempty(direction)
                    direction = zeros(size(values));
                end
                terminal = EventDetector_v3.expandToSize(terminal, numel(values));
                direction = EventDetector_v3.expandToSize(direction, numel(values));
                descriptors = repmat(EventDetector_v3.descriptorPrototype(), ...
                    numel(values), 1);
                for k = 1:numel(values)
                    descriptors(k).id = k;
                    descriptors(k).name = "stop_" + k;
                    descriptors(k).value = values(k);
                    descriptors(k).direction = direction(k);
                    descriptors(k).isterminal = logical(terminal(k));
                    descriptors(k).priority = -Inf;
                    descriptors(k).kind = "stop";
                    descriptors(k).enabled = logical(terminal(k));
                    if isstruct(metadata)
                        descriptors(k).metadata = metadata;
                    else
                        descriptors(k).metadata = struct('value', metadata);
                    end
                end
            end
            if ~isempty(fieldnames(wrapper))
                descriptors = EventDetector_v3.applyStopWrapper( ...
                    descriptors, wrapper);
            end
            if ~isempty(descriptors)
                descriptors = descriptors([descriptors.enabled]);
            end
        end

        function [value, terminal, direction, metadata] = ...
                callStopFunction(~, callback, t, x, q, p)
            argumentCount = nargin(callback);
            if argumentCount < 0 || argumentCount >= 4
                arguments = {t, x, q, p};
            elseif argumentCount == 3
                arguments = {t, x, q};
            elseif argumentCount == 2
                arguments = {t, x};
            elseif argumentCount == 1
                arguments = {x};
            else
                arguments = {};
            end

            outputCount = nargout(callback);
            metadata = struct();
            if outputCount == 1
                value = callback(arguments{:});
                terminal = [];
                direction = [];
            elseif outputCount == 2
                [value, terminal] = callback(arguments{:});
                direction = [];
            elseif outputCount == 3
                [value, terminal, direction] = callback(arguments{:});
            else
                try
                    [value, terminal, direction, metadata] = ...
                        callback(arguments{:});
                catch exception
                    if ~EventDetector_v3.isTooManyOutputs(exception)
                        rethrow(exception);
                    end
                    try
                        [value, terminal, direction] = callback(arguments{:});
                    catch exception
                        if ~EventDetector_v3.isTooManyOutputs(exception)
                            rethrow(exception);
                        end
                        try
                            [value, terminal] = callback(arguments{:});
                            direction = [];
                        catch exception
                            if ~EventDetector_v3.isTooManyOutputs(exception)
                                rethrow(exception);
                            end
                            value = callback(arguments{:});
                            terminal = [];
                            direction = [];
                        end
                    end
                end
            end
        end

        function values = valuesInTemplateOrder(~, template, current)
            values = zeros(numel(template), 1);
            for k = 1:numel(template)
                index = EventDetector_v3.findDescriptor(current, template(k).id);
                if isempty(index)
                    % A guard set must remain fixed while q is fixed.  A
                    % missing entry is kept away from zero defensively.
                    values(k) = EventDetector_v3.interiorSign(template(k));
                else
                    values(k) = current(index).value;
                end
            end
        end

        function values = stopValuesInTemplateOrder(~, template, current)
            if numel(current) ~= numel(template)
                error('EventDetector_v3:ChangingStopDimension', ...
                    'StopCondition output size changed during integration.');
            end
            values = zeros(numel(template), 1);
            for k = 1:numel(template)
                index = EventDetector_v3.findDescriptor(current, template(k).id);
                if isempty(index)
                    values(k) = EventDetector_v3.interiorSign(template(k));
                else
                    values(k) = current(index).value;
                end
            end
        end

        function armed = initialArming(obj, descriptors)
            if isempty(descriptors)
                armed = false(0, 1);
                return;
            end
            values = [descriptors.value].';
            armed = abs(values) > obj.Options.ArmingTolerance;
        end

        function signs = interiorSigns(~, descriptors)
            signs = zeros(numel(descriptors), 1);
            for k = 1:numel(descriptors)
                signs(k) = EventDetector_v3.interiorSign(descriptors(k));
            end
        end

        function [values, armed] = applyArming(obj, values, armed, signs)
            for k = 1:numel(values)
                if armed(k)
                    continue;
                end
                if signs(k) * values(k) > obj.Options.ArmingTolerance
                    % The returned value and the bias have the same sign,
                    % hence arming cannot create an artificial crossing.
                    armed(k) = true;
                else
                    values(k) = signs(k) * obj.Options.InteriorBias;
                end
            end
        end

        function [guards, stops] = clusterAtEvent(obj, system, condition, ...
                t, x, q, p, guardTemplate, stopTemplate, triggeredChannels)
            currentGuards = obj.guardDescriptors(system, t, x, q, p);
            guards = EventDetector_v3.emptyDescriptors();
            for k = 1:numel(guardTemplate)
                index = EventDetector_v3.findDescriptor( ...
                    currentGuards, guardTemplate(k).id);
                if isempty(index)
                    descriptor = guardTemplate(k);
                    descriptor.value = NaN;
                else
                    descriptor = currentGuards(index);
                end
                descriptor.directional_derivative = ...
                    obj.guardDirectionalDerivative( ...
                        system, descriptor.id, t, x, q, p);
                wasTriggered = any(triggeredChannels == k);
                eligible = obj.isSimultaneous(descriptor);
                if wasTriggered && ~eligible
                    error('EventDetector_v3:IneligibleTriggeredGuard', ...
                        ['ODE-reported guard %s at t=%.17g fails the ', ...
                         'directed transverse-root contract (g=%.17g, DgF=%.17g).'], ...
                        char(string(descriptor.name)), t, descriptor.value, ...
                        descriptor.directional_derivative);
                end
                if eligible
                    guards(end + 1, 1) = descriptor; %#ok<AGROW>
                end
            end
            guards = EventDetector_v3.sortDescriptors(guards);

            currentStops = obj.stopDescriptors(condition, t, x, q, p);
            stops = EventDetector_v3.emptyDescriptors();
            for k = 1:numel(stopTemplate)
                index = EventDetector_v3.findDescriptor( ...
                    currentStops, stopTemplate(k).id);
                if isempty(index)
                    descriptor = stopTemplate(k);
                    descriptor.value = NaN;
                else
                    descriptor = currentStops(index);
                end
                descriptor.directional_derivative = ...
                    obj.stopDirectionalDerivative( ...
                        system, condition, descriptor.id, t, x, q, p);
                channel = numel(guardTemplate) + k;
                wasTriggered = any(triggeredChannels == channel);
                eligible = obj.isSimultaneous(descriptor);
                if wasTriggered && ~eligible
                    error('EventDetector_v3:IneligibleTriggeredSection', ...
                        ['ODE-reported section %s at t=%.17g fails the ', ...
                         'directed transverse-root contract (h=%.17g, DhF=%.17g).'], ...
                        char(string(descriptor.name)), t, descriptor.value, ...
                        descriptor.directional_derivative);
                end
                if eligible
                    stops(end + 1, 1) = descriptor; %#ok<AGROW>
                end
            end
            stops = EventDetector_v3.sortDescriptors(stops);
        end

        function tf = isSimultaneous(obj, descriptor)
            value = descriptor.value;
            derivative = descriptor.directional_derivative;
            if ~isfinite(value)
                tf = false;
                return;
            end
            % A small guard value alone can be far from its next root
            % when the normal velocity is small. In particular, an apex
            % arming stop must not manufacture an early touchdown. Keep
            % the surface and estimated root-time tests independent.
            valueClose = abs(value) <= obj.Options.EventValueTolerance;
            if isfinite(derivative) && derivative ~= 0
                timeClose = abs(value / derivative) <= ...
                    obj.Options.SimultaneousTimeTolerance;
            else
                % The orientation test below excludes directed grazing.
                % An explicitly nondirectional zero-speed guard has no
                % linear root-time estimate and keeps its value contract.
                timeClose = true;
            end

            direction = descriptor.direction;
            derivativeTolerance = obj.Options.DirectionalDerivativeTolerance;
            directionConsistent = direction == 0 || ...
                (isfinite(derivative) && ...
                 direction * derivative > derivativeTolerance);
            tf = valueClose && timeClose && directionConsistent;
        end

        function derivative = guardDirectionalDerivative(obj, system, id, ...
                t, x, q, p)
            flow = obj.evaluateFlow(system, t, x, q, p);
            step = obj.derivativeStep(t, x, flow);
            plus = obj.guardDescriptors(system, t + step, ...
                x + step * flow, q, p);
            minus = obj.guardDescriptors(system, t - step, ...
                x - step * flow, q, p);
            plusIndex = EventDetector_v3.findDescriptor(plus, id);
            minusIndex = EventDetector_v3.findDescriptor(minus, id);
            if isempty(plusIndex) || isempty(minusIndex)
                derivative = NaN;
            else
                derivative = (plus(plusIndex).value - ...
                    minus(minusIndex).value) / (2 * step);
            end
        end

        function derivative = stopDirectionalDerivative(obj, system, ...
                condition, id, t, x, q, p)
            flow = obj.evaluateFlow(system, t, x, q, p);
            step = obj.derivativeStep(t, x, flow);
            plus = obj.stopDescriptors(condition, t + step, ...
                x + step * flow, q, p);
            minus = obj.stopDescriptors(condition, t - step, ...
                x - step * flow, q, p);
            plusIndex = EventDetector_v3.findDescriptor(plus, id);
            minusIndex = EventDetector_v3.findDescriptor(minus, id);
            if isempty(plusIndex) || isempty(minusIndex)
                derivative = NaN;
            else
                derivative = (plus(plusIndex).value - ...
                    minus(minusIndex).value) / (2 * step);
            end
        end

        function step = derivativeStep(obj, t, x, flow)
            scale = (1 + abs(t) + norm(x, Inf)) / ...
                max(1, norm(flow, Inf));
            step = max(obj.Options.DerivativeStep * scale, ...
                sqrt(eps) * scale);
        end

        function tolerance = timeTolerance(obj, time)
            tolerance = max(obj.Options.EventTimeTolerance, ...
                64 * eps(max(1, abs(time))));
        end
    end

    methods (Static, Access = private)
        function options = defaultOptions()
            options = struct( ...
                'ODESolver', @ode45, ...
                'RelTol', 1e-9, ...
                'AbsTol', 1e-11, ...
                'MaxStep', [], ...
                'EventValueTolerance', 1e-8, ...
                'EventTimeTolerance', 1e-10, ...
                'SimultaneousTimeTolerance', 1e-8, ...
                'DirectionalDerivativeTolerance', 1e-10, ...
                'DerivativeStep', 1e-7, ...
                'ArmingTolerance', 1e-9, ...
                'InteriorBias', 1e-9);
        end

        function output = mergeOptions(defaults, supplied)
            output = defaults;
            if isempty(supplied)
                return;
            end
            if ~isstruct(supplied) || ~isscalar(supplied)
                error('EventDetector_v3:InvalidOptions', ...
                    'Options must be a scalar structure.');
            end
            aliases = struct( ...
                'GuardTolerance', 'EventValueTolerance', ...
                'EventTolerance', 'EventValueTolerance', ...
                'SimultaneousTolerance', 'SimultaneousTimeTolerance');
            names = fieldnames(supplied);
            for k = 1:numel(names)
                name = names{k};
                target = name;
                if isfield(aliases, name)
                    target = aliases.(name);
                end
                if isfield(output, target)
                    output.(target) = supplied.(name);
                end
            end
        end

        function descriptors = normalizeDescriptors(raw, kind)
            if isempty(raw)
                descriptors = EventDetector_v3.emptyDescriptors();
                return;
            end
            if ~isstruct(raw)
                error('EventDetector_v3:InvalidDescriptors', ...
                    'Guard and stop callbacks must return structure arrays.');
            end
            prototype = EventDetector_v3.descriptorPrototype();
            descriptors = repmat(prototype, numel(raw), 1);
            fields = fieldnames(prototype);
            for k = 1:numel(raw)
                for j = 1:numel(fields)
                    field = fields{j};
                    if isfield(raw, field)
                        descriptors(k).(field) = raw(k).(field);
                    end
                end
                if isempty(descriptors(k).id)
                    descriptors(k).id = k;
                end
                if strlength(string(descriptors(k).name)) == 0
                    descriptors(k).name = kind + "_" + k;
                end
                if ~isfinite(descriptors(k).priority)
                    if isnumeric(descriptors(k).id) && isscalar(descriptors(k).id)
                        descriptors(k).priority = double(descriptors(k).id);
                    else
                        descriptors(k).priority = k;
                    end
                end
                descriptors(k).name = string(descriptors(k).name);
                descriptors(k).kind = string(descriptors(k).kind);
                if strlength(descriptors(k).kind) == 0
                    descriptors(k).kind = kind;
                end
                descriptors(k).enabled = logical(descriptors(k).enabled);
                descriptors(k).isterminal = logical(descriptors(k).isterminal);
                if ~isscalar(descriptors(k).value) || ...
                        ~isreal(descriptors(k).value)
                    error('EventDetector_v3:InvalidGuardValue', ...
                        'Each guard value must be a real scalar.');
                end
                if ~ismember(descriptors(k).direction, [-1, 0, 1])
                    error('EventDetector_v3:InvalidDirection', ...
                        'Guard directions must be -1, 0, or +1.');
                end
            end
            descriptors = descriptors([descriptors.enabled]);
        end

        function prototype = descriptorPrototype()
            prototype = struct( ...
                'id', [], ...
                'name', "", ...
                'value', NaN, ...
                'direction', 0, ...
                'isterminal', true, ...
                'priority', NaN, ...
                'enabled', true, ...
                'kind', "", ...
                'leg_index', [], ...
                'interior_sign', [], ...
                'directional_derivative', NaN, ...
                'metadata', struct());
        end

        function descriptors = emptyDescriptors()
            descriptors = repmat( ...
                EventDetector_v3.descriptorPrototype(), 0, 1);
        end

        function signs = descriptorDirections(descriptors)
            if isempty(descriptors)
                signs = zeros(0, 1);
            else
                signs = [descriptors.direction].';
            end
        end

        function signValue = interiorSign(descriptor)
            if ~isempty(descriptor.interior_sign) && ...
                    isfinite(descriptor.interior_sign) && ...
                    descriptor.interior_sign ~= 0
                signValue = sign(descriptor.interior_sign);
            elseif descriptor.direction ~= 0
                signValue = -sign(descriptor.direction);
            else
                signValue = 1;
            end
        end

        function index = findDescriptor(descriptors, id)
            index = [];
            for k = 1:numel(descriptors)
                if isequaln(descriptors(k).id, id)
                    index = k;
                    return;
                end
            end
        end

        function descriptors = sortDescriptors(descriptors)
            if numel(descriptors) < 2
                return;
            end
            priorities = [descriptors.priority].';
            orderIndex = (1:numel(descriptors)).';
            [~, order] = sortrows([priorities, orderIndex], [1, 2]);
            descriptors = descriptors(order);
        end

        function expanded = expandToSize(value, count)
            value = value(:);
            if isscalar(value)
                expanded = repmat(value, count, 1);
            elseif numel(value) == count
                expanded = value;
            else
                error('EventDetector_v3:StopOutputSizeMismatch', ...
                    'StopCondition outputs must have compatible sizes.');
            end
        end

        function descriptors = applyStopWrapper(descriptors, wrapper)
            for k = 1:numel(descriptors)
                if isfield(wrapper, 'name')
                    descriptors(k).name = string(wrapper.name);
                elseif isfield(wrapper, 'Name')
                    descriptors(k).name = string(wrapper.Name);
                end
                if isfield(wrapper, 'priority')
                    descriptors(k).priority = wrapper.priority;
                elseif isfield(wrapper, 'Priority')
                    descriptors(k).priority = wrapper.Priority;
                end
                if isfield(wrapper, 'id')
                    descriptors(k).id = wrapper.id;
                elseif isfield(wrapper, 'Id')
                    descriptors(k).id = wrapper.Id;
                end
            end
        end

        function tf = isTooManyOutputs(exception)
            tf = strcmp(exception.identifier, 'MATLAB:maxlhs') || ...
                contains(exception.message, 'Too many output arguments');
        end

        function event = noEvent(time, state)
            event = struct( ...
                'occurred', false, ...
                'time', time, ...
                'state', state, ...
                'guard_batch', EventDetector_v3.emptyDescriptors(), ...
                'stop_batch', EventDetector_v3.emptyDescriptors(), ...
                'stop_occurred', false, ...
                'triggered_channels', zeros(0, 1), ...
                'raw_event_times', zeros(0, 1), ...
                'raw_event_indices', zeros(0, 1));
        end
    end
end
