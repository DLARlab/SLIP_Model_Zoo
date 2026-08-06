classdef ResetMap_v3
    %RESETMAP_V3 Massless-leg contact reset in canonical v3 coordinates.
    %
    % Body position and velocity are continuous.  Only the affected leg's
    % angular-rate state is projected to zero horizontal foot velocity.

    properties (SetAccess = private)
        Schema
        SingularityTolerance = 1e-10
    end

    methods
        function obj = ResetMap_v3(schema, options)
            if nargin < 1 || isempty(schema)
                schema = QuadrupedSchema_v3.shared();
                if nargin < 2 || isempty(options)
                    options = struct();
                end
            elseif isstruct(schema) && nargin == 1
                options = schema;
                schema = QuadrupedSchema_v3.shared();
            elseif nargin < 2 || isempty(options)
                options = struct();
            end
            if ~isa(schema, 'QuadrupedSchema_v3')
                error('ResetMap_v3:InvalidSchema', ...
                    'Schema must be a QuadrupedSchema_v3 instance.');
            end
            if ~isstruct(options) || ~isscalar(options)
                error('ResetMap_v3:InvalidOptions', ...
                    'Options must be a scalar structure.');
            end
            obj.Schema = schema;
            if isfield(options, 'SingularityTolerance')
                value = options.SingularityTolerance;
                if ~(isnumeric(value) && isreal(value) && isscalar(value) ...
                        && isfinite(value) && value > 0)
                    error('ResetMap_v3:InvalidOptions', ...
                        'SingularityTolerance must be positive and finite.');
                end
                obj.SingularityTolerance = double(value);
            end
            unknown = setdiff(fieldnames(options), {'SingularityTolerance'});
            if ~isempty(unknown)
                error('ResetMap_v3:InvalidOptions', ...
                    'Unknown option "%s".', unknown{1});
            end
        end

        function xplus = apply(obj, eventId, t, xminus, qminus, p) %#ok<INUSD>
            [xminus, qminus, p] = obj.validateInputs(xminus, qminus, p);
            eventId = obj.Schema.eventId(eventId);
            [legIndex, isTouchdown] = obj.Schema.eventLegKind(eventId);

            expectedContact = ~isTouchdown;
            if qminus(legIndex) ~= expectedContact
                error('ResetMap_v3:EventModeMismatch', ...
                    '%s is not enabled in the supplied pre-event mode.', ...
                    obj.Schema.Event.Names{eventId});
            end

            xplus = xminus;
            rateIndex = obj.Schema.Leg.RateIndices(legIndex);
            xplus(rateIndex) = obj.projectedAngularRate(xminus, legIndex, p);
        end

        function xplus = applyBatch(obj, eventIds, t, xminus, qminus, p)
            xplus = xminus;
            qwork = obj.Schema.validateMode(qminus);
            transition = ModeTransition_v3(obj.Schema);
            ids = obj.normalizeEventVector(eventIds);
            legIndices = obj.Schema.Event.LegIndices(ids);
            if numel(unique(legIndices)) ~= numel(ids)
                error('ResetMap_v3:ConflictingBatch', ...
                    'A simultaneous reset batch may contain at most one event per leg.');
            end
            ids = sort(ids);
            for i = 1:numel(ids)
                xplus = obj.apply(ids(i), t, xplus, qwork, p);
                qwork = transition.apply(ids(i), qwork);
            end
        end

        function dalpha = projectedAngularRate(obj, x, legIndex, p)
            [x, ~, p] = obj.validateInputs( ...
                x, false(obj.Schema.Leg.Count, 1), p);
            if ~(isnumeric(legIndex) && isscalar(legIndex) ...
                    && isfinite(legIndex) && legIndex == fix(legIndex) ...
                    && any(legIndex == obj.Schema.Leg.Indices))
                error('ResetMap_v3:InvalidLeg', ...
                    'Leg index must identify BL, BR, FL, or FR.');
            end

            state = obj.Schema.State;
            expanded = obj.Schema.expandParameters(p);
            hipOffset = expanded.s(legIndex);
            angleIndex = obj.Schema.Leg.AngleIndices(legIndex);
            alpha = x(angleIndex);
            phi = x(state.phi);
            dphi = x(state.dphi);
            theta = phi + alpha;
            cosineTheta = cos(theta);
            if abs(cosineTheta) <= obj.SingularityTolerance
                error('ResetMap_v3:SingularProjection', ...
                    'Foot projection has singular absolute leg angle for %s.', ...
                    obj.Schema.Leg.Names{legIndex});
            end

            hipHeight = x(state.y) + hipOffset * sin(phi);
            denominator = hipHeight / cosineTheta^2;
            denominatorScale = max(1, abs(hipHeight) / cosineTheta^2);
            numerator = x(state.dx) - hipOffset * sin(phi) * dphi ...
                + (x(state.dy) + hipOffset * cos(phi) * dphi) ...
                    * tan(theta);

            if ~isfinite(denominator) ...
                    || abs(denominator) ...
                        <= obj.SingularityTolerance * denominatorScale
                error('ResetMap_v3:SingularProjection', ...
                    'Foot-velocity projection is singular for %s.', ...
                    obj.Schema.Leg.Names{legIndex});
            end
            dalpha = -dphi - numerator / denominator;
            if ~isfinite(dalpha)
                error('ResetMap_v3:SingularProjection', ...
                    'Foot-velocity projection is nonfinite for %s.', ...
                    obj.Schema.Leg.Names{legIndex});
            end
        end
    end

    methods (Access = private)
        function [x, q, p] = validateInputs(obj, x, q, p)
            x = obj.Schema.validateState(x);
            q = obj.Schema.validateMode(q);
            p = obj.Schema.validateParameter(p);
        end

        function ids = normalizeEventVector(obj, events)
            if ischar(events) || (isstring(events) && isscalar(events))
                ids = obj.Schema.eventId(events);
                return;
            end
            if iscell(events) || isstring(events)
                ids = zeros(numel(events), 1);
                for i = 1:numel(events)
                    if iscell(events)
                        event = events{i};
                    else
                        event = events(i);
                    end
                    ids(i) = obj.Schema.eventId(event);
                end
                return;
            end
            if ~isnumeric(events) || ~isreal(events)
                error('ResetMap_v3:InvalidEvent', ...
                    'Events must be IDs or event names.');
            end
            ids = zeros(numel(events), 1);
            for i = 1:numel(events)
                ids(i) = obj.Schema.eventId(events(i));
            end
        end
    end
end
