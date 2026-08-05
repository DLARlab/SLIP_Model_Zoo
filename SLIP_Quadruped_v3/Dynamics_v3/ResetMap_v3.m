classdef ResetMap_v3
    %RESETMAP_V3 Legacy-compatible massless-leg contact reset.
    %
    % Body position and velocity are continuous.  At both touchdown and
    % liftoff, only the affected leg angular rate is projected so that the
    % horizontal position of its massless foot is instantaneously stationary.

    methods
        function xplus = apply(obj, eventId, t, xminus, qminus, p) %#ok<INUSD>
            [xminus, qminus, p] = ResetMap_v3.validateInputs( ...
                xminus, qminus, p);
            eventId = ModeTransition_v3.normalizeEventId(eventId);
            [legIndex, isTouchdown] = ...
                ModeTransition_v3.eventLegKind(eventId);

            expectedContact = ~isTouchdown;
            if qminus(legIndex) ~= expectedContact
                error('ResetMap_v3:EventModeMismatch', ...
                    '%s is not enabled in the supplied pre-event mode.', ...
                    ModeTransition_v3.EventNames{eventId});
            end

            rateIndices = [8, 10, 12, 14];
            xplus = xminus;
            xplus(rateIndices(legIndex)) = obj.projectedAngularRate( ...
                xminus, legIndex, p);
        end

        function xplus = applyBatch(obj, eventIds, t, xminus, qminus, p)
            xplus = xminus;
            qwork = ModeTransition_v3.validateModeVector(qminus);
            transition = ModeTransition_v3();
            ids = eventIds(:);
            normalized = zeros(size(ids));
            for i = 1:numel(ids)
                normalized(i) = ModeTransition_v3.normalizeEventId(ids(i));
            end
            if numel(unique(ceil(normalized / 2))) ~= numel(normalized)
                error('ResetMap_v3:ConflictingBatch', ...
                    'A simultaneous reset batch may contain at most one event per leg.');
            end
            normalized = sort(normalized);
            for i = 1:numel(normalized)
                xplus = obj.apply(normalized(i), t, xplus, qwork, p);
                qwork = transition.apply(normalized(i), qwork);
            end
        end

        function dalpha = projectedAngularRate(~, x, legIndex, p)
            [x, ~, p] = ResetMap_v3.validateInputs( ...
                x, false(4, 1), p);
            if ~(isnumeric(legIndex) && isscalar(legIndex) ...
                    && isfinite(legIndex) && legIndex == fix(legIndex) ...
                    && legIndex >= 1 && legIndex <= 4)
                error('ResetMap_v3:InvalidLeg', ...
                    'Leg index must be an integer from 1 through 4.');
            end

            lb = p(6);
            offsets = [-lb; 1 - lb; -lb; 1 - lb];
            angleIndices = [7, 9, 11, 13];

            offset = offsets(legIndex);
            alpha = x(angleIndices(legIndex));
            theta = x(5) + alpha;
            hipHeight = x(3) + offset * sin(x(5));
            denominator = hipHeight / cos(theta)^2;
            numerator = x(2) - offset * sin(x(5)) * x(6) ...
                + (x(4) + offset * cos(x(5)) * x(6)) * tan(theta);

            if ~isfinite(denominator) || denominator == 0
                error('ResetMap_v3:SingularProjection', ...
                    'Foot-velocity projection is singular for leg %d.', legIndex);
            end
            dalpha = -x(6) - numerator / denominator;
            if ~isfinite(dalpha)
                error('ResetMap_v3:SingularProjection', ...
                    'Foot-velocity projection is nonfinite for leg %d.', legIndex);
            end
        end
    end

    methods (Static, Access = private)
        function [x, q, p] = validateInputs(x, q, p)
            if ~(isnumeric(x) && isreal(x) && isvector(x) ...
                    && numel(x) == 14 && all(isfinite(x(:))))
                error('ResetMap_v3:InvalidState', ...
                    'Quadruped state must be a finite real 14-vector.');
            end
            if ~(isnumeric(p) && isreal(p) && isvector(p) && numel(p) == 7 ...
                    && all(isfinite(p([1, 2, 4, 5, 6, 7]))) ...
                    && (isfinite(p(3)) || isinf(p(3))))
                error('ResetMap_v3:InvalidParameter', ...
                    'Quadruped parameter must be a real 7-vector.');
            end
            x = double(x(:));
            p = double(p(:));
            q = ModeTransition_v3.validateModeVector(q);
        end
    end
end
