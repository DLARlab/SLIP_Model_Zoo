classdef QuadrupedAdmissibility_v3
    %QUADRUPEDADMISSIBILITY_V3 Model-owned unilateral geometry checks.
    %
    % The report distinguishes transient ODE stages from accepted hybrid
    % states.  ODE-stage reports allow a configurable, small excursion past
    % a contact surface; accepted, post-reset, and section-return reports use
    % the strict physical tolerances.  Stance length is evaluated only for
    % stance legs.  Swing-foot clearance is evaluated directly from the
    % rest-length geometry, without division by cos(phi+alpha).

    properties (SetAccess = private)
        Schema
        SwingPenetrationTolerance = 1e-8
        StanceTensionTolerance = 1e-8
        MinimumLegLength = 1e-8
        MinimumBackHipHeight = 0
        MinimumFrontHipHeight = 0
        MinimumTorsoClearance = 0
        ComplementarityTolerance = 1e-8
        PostResetGuardTolerance = 1e-7
        GeometryTolerance = 1e-10
        MinimumDownwardCosine = 0
        ODEStageSurfaceTolerance = 1e-5
        CheckBackHipClearance = true
        CheckFrontHipClearance = true
        CheckTorsoGroundIntersection = true
        CheckFiniteGeometry = true
        CheckPostResetGuardConsistency = true
        CheckModeGuardComplementarity = true
        CheckDownwardLegOrientation = true
    end

    methods
        function obj = QuadrupedAdmissibility_v3(schema, options)
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
                error('QuadrupedAdmissibility_v3:InvalidSchema', ...
                    'Schema must be a QuadrupedSchema_v3 instance.');
            end
            obj.Schema = schema;
            obj = obj.applyOptions(options);
        end

        function report = evaluate(obj, x, q, p, context, contextData)
            %EVALUATE Return physical margins without throwing on failure.
            if nargin < 5 || isempty(context)
                context = 'accepted-state';
            end
            if nargin < 6 || isempty(contextData)
                contextData = struct();
            end
            context = obj.normalizeContext(context);
            if ~isstruct(contextData) || ~isscalar(contextData)
                error('QuadrupedAdmissibility_v3:InvalidContextData', ...
                    'Context data must be a scalar structure.');
            end
            if ~(isnumeric(x) && isreal(x) && isvector(x) ...
                    && numel(x) == obj.Schema.State.Dimension)
                error('QuadrupedAdmissibility_v3:InvalidStateShape', ...
                    'Quadruped state must be a real 14-vector.');
            end
            x = double(x(:));
            q = obj.Schema.validateMode(q);
            p = obj.Schema.validateParameter(p);

            state = obj.Schema.State;
            leg = obj.Schema.Leg;
            expanded = obj.Schema.expandParameters(p);
            stanceMask = logical(q);
            swingMask = ~stanceMask;

            phi = x(state.phi);
            alpha = x(leg.AngleIndices);
            theta = phi + alpha;
            cosineTheta = cos(theta);
            hipHeight = x(state.y) + expanded.s .* sin(phi);
            swingFootHeight = hipHeight ...
                - expanded.l_0 .* cosineTheta;

            % A swing leg has its prescribed rest length.  Only stance legs
            % require the ground-intersection constraint length h/cos(theta).
            legLength = expanded.l_0;
            stanceLegLength = NaN(leg.Count, 1);
            compression = NaN(leg.Count, 1);
            singularStance = stanceMask & (...
                ~isfinite(cosineTheta) ...
                | abs(cosineTheta) <= obj.GeometryTolerance);
            regularStance = stanceMask & ~singularStance;
            stanceLegLength(regularStance) = ...
                hipHeight(regularStance) ./ cosineTheta(regularStance);
            legLength(regularStance) = stanceLegLength(regularStance);
            compression(regularStance) = expanded.l_0(regularStance) ...
                - stanceLegLength(regularStance);

            backHipHeight = hipHeight(find(leg.BackMask, 1, 'first'));
            frontHipHeight = hipHeight(find(leg.FrontMask, 1, 'first'));
            torsoEndpointHeights = [backHipHeight; frontHipHeight];
            torsoClearance = min(torsoEndpointHeights);

            isODEStage = strcmp(context, 'ode-stage');
            swingTolerance = obj.SwingPenetrationTolerance;
            stanceTolerance = obj.StanceTensionTolerance;
            complementarityTolerance = obj.ComplementarityTolerance;
            if isODEStage
                swingTolerance = max(swingTolerance, ...
                    obj.ODEStageSurfaceTolerance);
                stanceTolerance = max(stanceTolerance, ...
                    obj.ODEStageSurfaceTolerance);
                complementarityTolerance = max( ...
                    complementarityTolerance, ...
                    obj.ODEStageSurfaceTolerance);
            end

            swingMargins = Inf(leg.Count, 1);
            swingMargins(swingMask) = ...
                swingFootHeight(swingMask) + swingTolerance;
            stanceMargins = Inf(leg.Count, 1);
            stanceMargins(regularStance) = ...
                compression(regularStance) + stanceTolerance;
            stanceMargins(singularStance) = -Inf;
            legLengthMargins = Inf(leg.Count, 1);
            legLengthMargins(stanceMask) = ...
                stanceLegLength(stanceMask) - obj.MinimumLegLength;

            hipMinimum = repmat(obj.MinimumFrontHipHeight, leg.Count, 1);
            hipMinimum(leg.BackMask) = obj.MinimumBackHipHeight;
            hipMargins = hipHeight - hipMinimum;
            torsoMargin = torsoClearance - obj.MinimumTorsoClearance;
            downwardMargins = cosineTheta - obj.MinimumDownwardCosine;

            complementarityResiduals = zeros(leg.Count, 1);
            complementarityResiduals(swingMask) = max(0, ...
                -swingFootHeight(swingMask));
            complementarityResiduals(stanceMask) = max(0, ...
                swingFootHeight(stanceMask));
            complementarityMargins = complementarityTolerance ...
                - complementarityResiduals;

            finitePerLeg = isfinite(theta) & isfinite(cosineTheta) ...
                & isfinite(hipHeight) & isfinite(swingFootHeight) ...
                & isfinite(legLength);
            finitePerLeg(stanceMask) = finitePerLeg(stanceMask) ...
                & isfinite(stanceLegLength(stanceMask)) ...
                & isfinite(compression(stanceMask));

            perLegValidity = true(leg.Count, 1);
            perLegReasons = repmat({{}}, leg.Count, 1);
            failureReasons = {};

            for i = leg.Indices
                legName = leg.Names{i};
                if obj.CheckFiniteGeometry && ~finitePerLeg(i)
                    reason = sprintf('invalid_leg_geometry:%s', legName);
                    [perLegValidity, perLegReasons, failureReasons] = ...
                        obj.recordLegFailure(i, reason, perLegValidity, ...
                        perLegReasons, failureReasons);
                end
                if swingMask(i) && swingMargins(i) < 0
                    reason = sprintf('swing_foot_penetration:%s', legName);
                    [perLegValidity, perLegReasons, failureReasons] = ...
                        obj.recordLegFailure(i, reason, perLegValidity, ...
                        perLegReasons, failureReasons);
                end
                if stanceMask(i) && stanceMargins(i) < 0
                    reason = sprintf('stance_tension:%s', legName);
                    [perLegValidity, perLegReasons, failureReasons] = ...
                        obj.recordLegFailure(i, reason, perLegValidity, ...
                        perLegReasons, failureReasons);
                end
                if stanceMask(i) && legLengthMargins(i) <= 0
                    reason = sprintf('invalid_leg_geometry:%s', legName);
                    [perLegValidity, perLegReasons, failureReasons] = ...
                        obj.recordLegFailure(i, reason, perLegValidity, ...
                        perLegReasons, failureReasons);
                end
                checkHip = (leg.BackMask(i) ...
                    && obj.CheckBackHipClearance) ...
                    || (leg.FrontMask(i) ...
                    && obj.CheckFrontHipClearance);
                if checkHip && hipMargins(i) < 0
                    if leg.BackMask(i)
                        reason = sprintf( ...
                            'back_hip_ground_contact:%s', legName);
                    else
                        reason = sprintf( ...
                            'front_hip_ground_contact:%s', legName);
                    end
                    [perLegValidity, perLegReasons, failureReasons] = ...
                        obj.recordLegFailure(i, reason, perLegValidity, ...
                        perLegReasons, failureReasons);
                end
                if obj.CheckModeGuardComplementarity ...
                        && complementarityMargins(i) < 0
                    reason = sprintf( ...
                        'contact_complementarity_loss:%s', legName);
                    [perLegValidity, perLegReasons, failureReasons] = ...
                        obj.recordLegFailure(i, reason, perLegValidity, ...
                        perLegReasons, failureReasons);
                end
                if obj.CheckDownwardLegOrientation ...
                        && downwardMargins(i) <= 0
                    reason = sprintf( ...
                        'invalid_downward_leg_orientation:%s', legName);
                    [perLegValidity, perLegReasons, failureReasons] = ...
                        obj.recordLegFailure(i, reason, perLegValidity, ...
                        perLegReasons, failureReasons);
                end
            end

            if obj.CheckFiniteGeometry ...
                    && (~all(isfinite(x)) ...
                    || any(~isfinite(torsoEndpointHeights)))
                failureReasons{end + 1} = 'invalid_nonfinite_geometry';
            end
            if obj.CheckTorsoGroundIntersection && torsoMargin < 0
                failureReasons{end + 1} = 'torso_ground_contact';
                perLegValidity(:) = false;
                for i = leg.Indices
                    perLegReasons{i}{end + 1} = ...
                        'torso_ground_contact';
                end
            end

            [postResetResiduals, postResetModeConsistent, ...
                postResetGuardConsistent, postResetEvaluated, ...
                postResetReasons] = obj.postResetChecks( ...
                context, contextData, q, swingFootHeight);
            if obj.CheckPostResetGuardConsistency && postResetEvaluated
                failureReasons = [failureReasons, postResetReasons];
            end

            failureReasons = unique(failureReasons, 'stable');
            globalValidity = all(perLegValidity) ...
                && isempty(failureReasons);

            strictSwingValid = all(~swingMask ...
                | swingFootHeight >= -obj.SwingPenetrationTolerance);
            strictStanceValid = all(~stanceMask ...
                | (compression >= -obj.StanceTensionTolerance ...
                & stanceLegLength > obj.MinimumLegLength));
            strictComplementarityValid = ...
                ~obj.CheckModeGuardComplementarity ...
                || all(complementarityResiduals ...
                    <= obj.ComplementarityTolerance);
            strictGlobalValidity = globalValidity;
            if isODEStage
                strictGlobalValidity = globalValidity ...
                    && strictSwingValid && strictStanceValid ...
                    && strictComplementarityValid;
            end

            perLegMinimumMargins = Inf(leg.Count, 1);
            for i = leg.Indices
                legMargins = [swingMargins(i), stanceMargins(i), ...
                    legLengthMargins(i)];
                if (leg.BackMask(i) && obj.CheckBackHipClearance) ...
                        || (leg.FrontMask(i) ...
                        && obj.CheckFrontHipClearance)
                    legMargins(end + 1) = hipMargins(i); %#ok<AGROW>
                end
                if obj.CheckModeGuardComplementarity
                    legMargins(end + 1) = ...
                        complementarityMargins(i); %#ok<AGROW>
                end
                if obj.CheckDownwardLegOrientation
                    legMargins(end + 1) = downwardMargins(i); %#ok<AGROW>
                end
                perLegMinimumMargins(i) = min(legMargins);
            end
            activeMargins = perLegMinimumMargins;
            if obj.CheckTorsoGroundIntersection
                activeMargins(end + 1) = torsoMargin;
            end
            if obj.CheckPostResetGuardConsistency && postResetEvaluated
                activeMargins = [activeMargins; ...
                    obj.PostResetGuardTolerance ...
                    - postResetResiduals(:)];
            end
            minimumPhysicalMargin = min(activeMargins);
            if obj.CheckFiniteGeometry && ~all(finitePerLeg)
                minimumPhysicalMargin = -Inf;
            end

            report = struct();
            report.context = context;
            report.context_policy = struct( ...
                'strict_accepted_state_checks', ~isODEStage, ...
                'allows_transient_event_surface_overshoot', isODEStage);
            report.mode = q;
            report.absolute_leg_angles = theta;
            report.hip_heights = hipHeight;
            report.hip_clearances = hipHeight;
            report.hip_clearance_margins = hipMargins;
            report.torso_endpoint_heights = torsoEndpointHeights;
            report.torso_clearance = torsoClearance;
            report.torso_clearance_margin = torsoMargin;
            report.swing_foot_clearances = swingFootHeight;
            report.swing_foot_margins = swingMargins;
            report.minimum_swing_foot_clearance = ...
                min([Inf; swingFootHeight(swingMask)]);
            report.minimum_swing_foot_margin = min(swingMargins);
            report.leg_lengths = legLength;
            report.stance_leg_lengths = stanceLegLength;
            report.stance_compressions = compression;
            report.stance_compression_margins = stanceMargins;
            report.minimum_stance_compression = ...
                min([Inf; compression(stanceMask)]);
            report.minimum_stance_compression_margin = ...
                min(stanceMargins);
            report.leg_length_margins = legLengthMargins;
            report.minimum_leg_length = ...
                min([Inf; stanceLegLength(stanceMask)]);
            report.minimum_leg_length_margin = min(legLengthMargins);
            report.complementarity_residuals = ...
                complementarityResiduals;
            report.complementarity_margins = complementarityMargins;
            report.minimum_complementarity_margin = ...
                min(complementarityMargins);
            report.minimum_hip_clearance = min(hipHeight);
            report.minimum_hip_clearance_margin = min(hipMargins);
            report.downward_orientation_margins = downwardMargins;
            report.finite_geometry_per_leg = finitePerLeg;
            report.per_leg_validity = perLegValidity;
            report.per_leg_failure_reasons = perLegReasons;
            report.per_leg_minimum_physical_margin = ...
                perLegMinimumMargins;
            report.global_validity = globalValidity;
            report.strict_global_validity = strictGlobalValidity;
            report.minimum_physical_margin = minimumPhysicalMargin;
            report.failure_reasons = failureReasons;
            report.post_reset_consistency_evaluated = postResetEvaluated;
            report.post_reset_guard_residuals = postResetResiduals;
            report.post_reset_guard_consistent = postResetGuardConsistent;
            report.post_reset_mode_consistent = postResetModeConsistent;
            report.active_tolerances = obj.activeTolerances( ...
                swingTolerance, stanceTolerance, ...
                complementarityTolerance);
            report.active_checks = obj.activeChecks();

            % Compatibility names used by the existing simulator and
            % boundary diagnostics.  New consumers should use the explicit
            % physical fields above.
            report.admissible = globalValidity;
            report.admissibility_margins = perLegMinimumMargins;
            report.minimum_stance_admissibility_margin = ...
                min(stanceMargins);
            report.stance_admissibility_margins = stanceMargins;
            report.invalid_stance_legs = find(stanceMask ...
                & (stanceMargins < 0 | legLengthMargins <= 0));
            report.invalid_swing_legs = find(swingMask ...
                & swingMargins < 0);
        end

        function report = assertAdmissible(obj, x, q, p, ...
                context, contextData)
            %ASSERTADMISSIBLE Throw only for the selected context policy.
            if nargin < 5 || isempty(context)
                context = 'accepted-state';
            end
            if nargin < 6
                contextData = struct();
            end
            report = obj.evaluate(x, q, p, context, contextData);
            if report.global_validity
                return;
            end
            message = strjoin(report.failure_reasons, ', ');
            if isempty(message)
                message = 'unspecified physical-admissibility failure';
            end
            error('QuadrupedAdmissibility_v3:PhysicallyInadmissible', ...
                'Quadruped %s is inadmissible: %s.', ...
                report.context, message);
        end
    end

    methods (Access = private)
        function obj = applyOptions(obj, options)
            if ~isstruct(options) || ~isscalar(options)
                error('QuadrupedAdmissibility_v3:InvalidOptions', ...
                    'Options must be supplied as a scalar structure.');
            end
            names = fieldnames(options);
            nonnegative = { ...
                'SwingPenetrationTolerance', ...
                'StanceTensionTolerance', ...
                'MinimumBackHipHeight', ...
                'MinimumFrontHipHeight', ...
                'MinimumTorsoClearance', ...
                'ComplementarityTolerance', ...
                'PostResetGuardTolerance', ...
                'MinimumDownwardCosine', ...
                'ODEStageSurfaceTolerance'};
            positive = {'MinimumLegLength', 'GeometryTolerance'};
            logicalNames = { ...
                'CheckBackHipClearance', ...
                'CheckFrontHipClearance', ...
                'CheckTorsoGroundIntersection', ...
                'CheckFiniteGeometry', ...
                'CheckPostResetGuardConsistency', ...
                'CheckModeGuardComplementarity', ...
                'CheckDownwardLegOrientation'};
            allowed = [nonnegative, positive, logicalNames];
            for i = 1:numel(names)
                name = names{i};
                if ~any(strcmp(name, allowed))
                    error('QuadrupedAdmissibility_v3:InvalidOptions', ...
                        'Unknown option "%s".', name);
                end
                value = options.(name);
                if any(strcmp(name, logicalNames))
                    if ~(islogical(value) && isscalar(value))
                        error('QuadrupedAdmissibility_v3:InvalidOptions', ...
                            '%s must be a logical scalar.', name);
                    end
                elseif ~(isnumeric(value) && isreal(value) ...
                        && isscalar(value) && isfinite(value) ...
                        && ((any(strcmp(name, positive)) && value > 0) ...
                        || (any(strcmp(name, nonnegative)) && value >= 0)))
                    error('QuadrupedAdmissibility_v3:InvalidOptions', ...
                        '%s has an invalid scalar tolerance.', name);
                else
                    value = double(value);
                end
                obj.(name) = value;
            end
        end

        function context = normalizeContext(~, context)
            if ~(ischar(context) ...
                    || (isstring(context) && isscalar(context)))
                error('QuadrupedAdmissibility_v3:InvalidContext', ...
                    'Admissibility context must be a text scalar.');
            end
            context = lower(strrep(strrep(char(context), '_', '-'), ' ', '-'));
            switch context
                case {'ode', 'ode-stage', 'stage', 'rk-stage'}
                    context = 'ode-stage';
                case {'accepted', 'accepted-state', 'event-state'}
                    context = 'accepted-state';
                case {'post-reset', 'reset'}
                    context = 'post-reset';
                case {'section', 'section-return', 'return'}
                    context = 'section-return';
                otherwise
                    error('QuadrupedAdmissibility_v3:InvalidContext', ...
                        'Unknown admissibility context "%s".', context);
            end
        end

        function [validity, perLegReasons, reasons] = recordLegFailure( ...
                ~, legIndex, reason, validity, perLegReasons, reasons)
            validity(legIndex) = false;
            perLegReasons{legIndex}{end + 1} = reason;
            reasons{end + 1} = reason;
        end

        function [residuals, modeConsistent, guardConsistent, ...
                evaluated, reasons] = postResetChecks(obj, context, data, ...
                q, guardValues)
            residuals = zeros(0, 1);
            modeConsistent = true(0, 1);
            guardConsistent = true(0, 1);
            evaluated = false;
            reasons = {};
            if ~strcmp(context, 'post-reset') ...
                    || ~obj.CheckPostResetGuardConsistency
                return;
            end
            if isfield(data, 'event_ids')
                eventIds = data.event_ids;
            elseif isfield(data, 'eventIds')
                eventIds = data.eventIds;
            elseif isfield(data, 'event_id')
                eventIds = data.event_id;
            else
                % A post-reset report without event metadata remains useful
                % for geometry/complementarity, but cannot claim that reset
                % guard consistency was evaluated.
                return;
            end
            if isempty(eventIds)
                return;
            end
            if iscell(eventIds)
                rawIds = eventIds(:);
            elseif isstring(eventIds)
                rawIds = num2cell(eventIds(:));
            elseif isnumeric(eventIds) && isreal(eventIds) ...
                    && isvector(eventIds)
                rawIds = num2cell(eventIds(:));
            else
                error('QuadrupedAdmissibility_v3:InvalidContextData', ...
                    'Post-reset event IDs must be a vector of IDs or names.');
            end
            eventIds = zeros(numel(rawIds), 1);
            for index = 1:numel(rawIds)
                eventIds(index) = obj.Schema.eventId(rawIds{index});
            end
            evaluated = true;
            residuals = zeros(numel(eventIds), 1);
            modeConsistent = false(numel(eventIds), 1);
            guardConsistent = false(numel(eventIds), 1);
            for k = 1:numel(eventIds)
                id = eventIds(k);
                [legIndex, isTouchdown] = ...
                    obj.Schema.eventLegKind(id);
                residuals(k) = abs(guardValues(legIndex));
                guardConsistent(k) = residuals(k) ...
                    <= obj.PostResetGuardTolerance;
                modeConsistent(k) = logical(q(legIndex)) ...
                    == logical(isTouchdown);
                if ~guardConsistent(k)
                    reasons{end + 1} = sprintf( ...
                        'post_reset_guard_inconsistency:%s', ...
                        obj.Schema.Event.Names{id}); %#ok<AGROW>
                end
                if ~modeConsistent(k)
                    reasons{end + 1} = sprintf( ...
                        'post_reset_mode_inconsistency:%s', ...
                        obj.Schema.Event.Names{id}); %#ok<AGROW>
                end
            end
        end

        function tolerances = activeTolerances(obj, swing, stance, comp)
            tolerances = struct( ...
                'swing_penetration', swing, ...
                'stance_tension', stance, ...
                'minimum_leg_length', obj.MinimumLegLength, ...
                'minimum_back_hip_height', obj.MinimumBackHipHeight, ...
                'minimum_front_hip_height', obj.MinimumFrontHipHeight, ...
                'minimum_torso_clearance', obj.MinimumTorsoClearance, ...
                'complementarity', comp, ...
                'post_reset_guard', obj.PostResetGuardTolerance, ...
                'geometry', obj.GeometryTolerance, ...
                'minimum_downward_cosine', ...
                    obj.MinimumDownwardCosine, ...
                'ode_stage_surface', obj.ODEStageSurfaceTolerance);
        end

        function checks = activeChecks(obj)
            checks = struct( ...
                'back_hip_clearance', obj.CheckBackHipClearance, ...
                'front_hip_clearance', obj.CheckFrontHipClearance, ...
                'torso_ground_intersection', ...
                    obj.CheckTorsoGroundIntersection, ...
                'finite_geometry', obj.CheckFiniteGeometry, ...
                'post_reset_guard_consistency', ...
                    obj.CheckPostResetGuardConsistency, ...
                'mode_guard_complementarity', ...
                    obj.CheckModeGuardComplementarity, ...
                'downward_leg_orientation', ...
                    obj.CheckDownwardLegOrientation);
        end
    end
end
