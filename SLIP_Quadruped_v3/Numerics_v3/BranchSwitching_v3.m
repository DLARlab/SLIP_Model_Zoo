classdef BranchSwitching_v3
    %BRANCHSWITCHING_V3 Local predictors and correctors at critical orbits.
    %   Unit-multiplier switching starts from the two signed predictors
    %
    %       u_+ = u_* + epsilon v,   u_- = u_* - epsilon v,
    %
    %   and corrects the periodic-orbit residual together with a local
    %   pseudo-arclength/branch-separation equation.  A converged nonlinear
    %   solve is accepted only after cycle closure, admissibility, topology,
    %   residual, and parent-separation checks have passed.
    %
    %   Period-doubling switching solves P_C^2(u,mu)-u=0 while enforcing
    %   ||P_C(u,mu)-u|| > PeriodOneExclusionTolerance as a hard corrector
    %   validity condition.  Trials on the period-one branch are invalid,
    %   so a period-one orbit is never relabelled as a period-two solution.

    properties
        ActiveParameterIndex = 1
        PredictorAmplitude = 1e-3
        ResidualAcceptanceTolerance = 1e-8
        ParentDistanceTolerance = 1e-6
        PeriodOneExclusionTolerance = 1e-6
        CriticalMultiplierTolerance = 1e-4
        SymmetryTolerance = 1e-8
        EnableDeflation = false
        DeflationPower = 2
        DeflationShift = 1
        RequirePhysicalAdmissibility = true
        RequireCycleClosure = true
        RequireModeClosure = true
        RequireTopologyMetadata = true
        RootSolver = []
        ParentBranchDistanceFunction = []
    end

    methods
        function obj = BranchSwitching_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            if isempty(obj.RootSolver)
                obj.RootSolver = RootSolver_v3(struct( ...
                    'Algorithm', 'newton', ...
                    'FunctionTolerance', min(1e-10, ...
                        obj.ResidualAcceptanceTolerance), ...
                    'ResidualAcceptanceTolerance', ...
                        obj.ResidualAcceptanceTolerance, ...
                    'MaxIterations', 120, ...
                    'MaxFunctionEvaluations', 10000));
            end
            obj.validateOptions();
        end

        function predictors = unitMultiplierPredictors(obj, critical, epsilon)
            %UNITMULTIPLIERPREDICTORS Construct the signed null-vector pair.
            if nargin < 3 || isempty(epsilon)
                epsilon = obj.PredictorAmplitude;
            end
            [uStar, pStar, mode, vector] = obj.criticalData(critical);
            direction = obj.normalizeVector(vector);
            predictors = struct();
            predictors.amplitude = epsilon;
            predictors.direction = direction;
            predictors.plus = obj.predictorRecord( ...
                +1, uStar, pStar, mode, direction, epsilon);
            predictors.minus = obj.predictorRecord( ...
                -1, uStar, pStar, mode, direction, epsilon);
        end

        function result = switchUnitMultiplier(obj, residual, critical, varargin)
            %SWITCHUNITMULTIPLIER Correct both signed local predictors.
            epsilon = obj.optionalAmplitude(varargin{:});
            result = obj.emptySwitchResult('unit_multiplier');
            [eligible, reason, multiplier] = ...
                obj.criticalEligibleForMultiplier(critical, +1, ...
                    'unit-multiplier');
            result.criticalMultiplier = multiplier;
            result.requiredCriticalMultiplier = +1;
            result.criticalMultiplierTolerance = ...
                obj.CriticalMultiplierTolerance;
            if ~eligible
                result.message = reason;
                result.classification = 'switch_rejected';
                result.criticalPoint = critical;
                return
            end

            predictors = obj.unitMultiplierPredictors(critical, epsilon);
            [uStar, pStar, mode, ~] = obj.criticalData(critical);
            records = [predictors.plus, predictors.minus];
            attempts = repmat(obj.emptyAttempt(), 1, 2);
            for index = 1:2
                attempts(index) = obj.correctUnitPredictor( ...
                    residual, critical, uStar, pStar, mode, records(index));
            end
            result = obj.finishSwitchResult( ...
                result, critical, predictors, attempts);
        end

        function result = unitMultiplier(obj, varargin)
            %UNITMULTIPLIER Concise alias for switchUnitMultiplier.
            result = obj.switchUnitMultiplier(varargin{:});
        end

        function result = switchPeriodDoubling(obj, mapFunction, critical, varargin)
            %SWITCHPERIODDOUBLING Correct P_C^2(u,mu)-u from both sides.
            epsilon = obj.optionalAmplitude(varargin{:});
            result = obj.emptySwitchResult('period_doubling');
            [eligible, reason, multiplier] = ...
                obj.criticalEligibleForMultiplier(critical, -1, ...
                    'period-doubling');
            result.criticalMultiplier = multiplier;
            result.requiredCriticalMultiplier = -1;
            result.criticalMultiplierTolerance = ...
                obj.CriticalMultiplierTolerance;
            if ~eligible
                result.message = reason;
                result.classification = 'switch_rejected';
                result.criticalPoint = critical;
                return
            end

            predictors = obj.unitMultiplierPredictors(critical, epsilon);
            [uStar, pStar, mode, ~] = obj.criticalData(critical);
            records = [predictors.plus, predictors.minus];
            attempts = repmat(obj.emptyAttempt(), 1, 2);
            for index = 1:2
                attempts(index) = obj.correctPeriodTwoPredictor( ...
                    mapFunction, critical, uStar, pStar, mode, records(index));
            end
            result = obj.finishSwitchResult( ...
                result, critical, predictors, attempts);
            result.periodOneExclusionTolerance = ...
                obj.PeriodOneExclusionTolerance;
        end

        function result = periodDoubling(obj, varargin)
            %PERIODDOUBLING Concise alias for switchPeriodDoubling.
            result = obj.switchPeriodDoubling(varargin{:});
        end

        function result = switchSymmetryBreaking( ...
                obj, residual, critical, symmetryAction, varargin)
            %SWITCHSYMMETRYBREAKING Correct in a non-fixed representation.
            %   The supplied actions define their common fixed subspace.
            %   The critical vector is orthogonally projected into its
            %   complement before either signed predictor or local
            %   branch-separation equation is formed.  This method never
            %   infers a pitchfork solely from lambda=1.
            result = obj.emptySwitchResult('symmetry_breaking');
            [eligible, reason, multiplier] = ...
                obj.criticalEligibleForMultiplier(critical, +1, ...
                    'symmetry-breaking unit-multiplier');
            result.criticalMultiplier = multiplier;
            result.requiredCriticalMultiplier = +1;
            result.criticalMultiplierTolerance = ...
                obj.CriticalMultiplierTolerance;
            if ~eligible
                result.message = reason;
                result.classification = 'switch_rejected';
                result.criticalPoint = critical;
                return
            end

            actions = obj.symmetryActions(symmetryAction);
            [uStar, ~, ~, vector] = obj.criticalData(critical);
            projection = obj.symmetryBreakingProjection(actions, vector);
            originalRepresentation = ...
                obj.vectorRepresentation(actions, vector);
            if ~projection.hasNonzeroBreakingComponent
                result.message = sprintf([ ...
                    'The critical vector has no resolvable component in ', ...
                    'the symmetry-breaking complement (relative norm ', ...
                    '%.3e <= %.3e).'], ...
                    projection.relativeBreakingComponent, ...
                    obj.SymmetryTolerance);
                result.classification = 'switch_rejected';
                result.criticalPoint = critical;
                result.symmetry = obj.symmetryRecord(actions, projection, ...
                    originalRepresentation, struct(), {}, struct([]));
                return
            end

            projectedCritical = critical;
            projectedCritical.rightVector = projection.projectedVector;
            result = obj.switchUnitMultiplier( ...
                residual, projectedCritical, varargin{:});
            result.type = 'symmetry_breaking';
            result.criticalPoint = critical;
            result.projectedCriticalPoint = projectedCritical;
            representation = obj.vectorRepresentation( ...
                actions, projection.projectedVector);
            parentStabilizer = obj.stabilizer(actions, uStar);
            attempts = result.attempts;
            for index = 1:numel(attempts)
                attempts(index).childStabilizer = ...
                    obj.stabilizer(actions, attempts(index).state);
                attempts(index).parentStabilizer = parentStabilizer;
                attempts(index).criticalRepresentation = representation;
                attempts(index).symmetryBreakingProjectionResidual = ...
                    norm(projection.fixedSubspaceBasis' * ...
                        attempts(index).predictor.direction, 2);
            end
            result.attempts = attempts;
            result.solutions = attempts([attempts.accepted]);
            result.symmetry = obj.symmetryRecord(actions, projection, ...
                originalRepresentation, representation, ...
                parentStabilizer, attempts);
            if result.accepted
                result.classification = 'symmetry_breaking_branch_candidate';
                result.message = [result.message, ' Symmetry metadata were ', ...
                    'recorded; no pitchfork/transcritical label was inferred.'];
            else
                result.classification = 'symmetry_breaking_switch_failed';
            end
        end

        function result = symmetryBreaking(obj, varargin)
            %SYMMETRYBREAKING Concise alias for switchSymmetryBreaking.
            result = obj.switchSymmetryBreaking(varargin{:});
        end

        function branch = continueSwitchedBranch( ...
                obj, residual, switchedSolution, continuation)
            %CONTINUESWITCHEDBRANCH Hand an accepted child to PAL continuation.
            switchType = obj.member(switchedSolution, 'type', 'unit_multiplier');
            solution = obj.acceptedSolution(switchedSolution);
            if nargin < 4 || isempty(continuation)
                continuation = PseudoArclengthContinuation_v3();
            end
            continuation.ActiveParameterIndex = obj.ActiveParameterIndex;
            branch = continuation.run(residual, solution.state, ...
                solution.parameter, solution.mode);
            branch.branchSwitch = obj.branchProvenance(solution);
            branch.branchSwitch.type = switchType;
        end

        function branch = continuePeriodDoubledBranch( ...
                obj, mapFunction, switchedSolution, continuation)
            %CONTINUEPERIODDOUBLEDDBRANCH Continue the doubled return equation.
            solution = obj.acceptedSolution(switchedSolution);
            if nargin < 4 || isempty(continuation)
                continuation = PseudoArclengthContinuation_v3();
            end
            continuation.ActiveParameterIndex = obj.ActiveParameterIndex;
            doubled = @(u, p, q, varargin) ...
                obj.doubledResidual(mapFunction, u, p, q, varargin{:});
            branch = continuation.run(doubled, solution.state, ...
                solution.parameter, solution.mode);

            distances = NaN(1, branch.count);
            for index = 1:branch.count
                [first, ~] = obj.evaluateCallback( ...
                    mapFunction, branch.points(index).x, ...
                    branch.points(index).p, branch.points(index).mode);
                distances(index) = norm( ...
                    first(:) - branch.points(index).x(:), Inf);
            end
            branch.periodOneDistances = distances;
            branch.periodOneExclusionTolerance = ...
                obj.PeriodOneExclusionTolerance;
            branch.periodTwoValid = ...
                distances > obj.PeriodOneExclusionTolerance;
            branch.branchSwitch = obj.branchProvenance(solution);
            branch.branchSwitch.type = 'period_doubling';
            if any(~branch.periodTwoValid)
                branch.success = false;
                branch.terminationReason = [branch.terminationReason, ...
                    '; period-one exclusion failed on the doubled branch'];
            end
        end

        function [value, info] = doubledReturnResidual( ...
                obj, mapFunction, u, p, q)
            %DOUBLEDRETURNRESIDUAL Public P_C^2-I residual constructor.
            [value, info] = obj.doubledResidual(mapFunction, u, p, q);
        end
    end

    methods (Access = private)
        function attempt = correctUnitPredictor(obj, residual, critical, ...
                uStar, pStar, mode, predictor)
            n = numel(uStar);
            zStar = [uStar; pStar(obj.ActiveParameterIndex)];
            direction = [predictor.sign .* predictor.direction; 0];
            zPredict = [predictor.state; pStar(obj.ActiveParameterIndex)];
            epsilon = predictor.amplitude;

            function [value, info] = augmented(candidate, varargin)
                u = candidate(1:n);
                p = pStar;
                p(obj.ActiveParameterIndex) = candidate(end);
                [f, info] = obj.evaluateCallback(residual, u, p, mode);
                factor = obj.deflationFactor(candidate, zStar, u, p, mode);
                arc = direction' * (candidate - zStar) - epsilon;
                value = [factor .* f(:); arc];
            end

            [z, solveInfo] = obj.solveCorrector(@augmented, zPredict);
            u = z(1:n);
            p = pStar;
            p(obj.ActiveParameterIndex) = z(end);
            [f, info] = obj.evaluateCallback(residual, u, p, mode);
            attempt = obj.assessAttempt(critical, predictor, solveInfo, ...
                u, p, mode, f, info, z, zStar);
            attempt.correctorEquation = 'periodic-residual-plus-local-pseudo-arclength';
            attempt.branchSeparationConstraint = direction' * (z - zStar);
            attempt.targetBranchSeparation = epsilon;
        end

        function attempt = correctPeriodTwoPredictor(obj, mapFunction, ...
                critical, uStar, pStar, mode, predictor)
            n = numel(uStar);
            zStar = [uStar; pStar(obj.ActiveParameterIndex)];
            direction = [predictor.sign .* predictor.direction; 0];
            zPredict = [predictor.state; pStar(obj.ActiveParameterIndex)];
            epsilon = predictor.amplitude;

            function [value, info] = augmented(candidate, varargin)
                u = candidate(1:n);
                p = pStar;
                p(obj.ActiveParameterIndex) = candidate(end);
                [f, info] = obj.doubledResidual(mapFunction, u, p, mode);
                factor = obj.deflationFactor(candidate, zStar, u, p, mode);
                arc = direction' * (candidate - zStar) - epsilon;
                value = [factor .* f(:); arc];
            end

            [z, solveInfo] = obj.solveCorrector(@augmented, zPredict);
            u = z(1:n);
            p = pStar;
            p(obj.ActiveParameterIndex) = z(end);
            [f, info, mapDiagnostics] = ...
                obj.doubledResidual(mapFunction, u, p, mode);
            attempt = obj.assessAttempt(critical, predictor, solveInfo, ...
                u, p, mode, f, info, z, zStar);
            attempt.correctorEquation = ...
                'doubled-return-residual-plus-local-pseudo-arclength';
            attempt.branchSeparationConstraint = direction' * (z - zStar);
            attempt.targetBranchSeparation = epsilon;
            attempt.periodOneDistance = mapDiagnostics.periodOneDistance;
            attempt.periodOneExcluded = attempt.periodOneDistance > ...
                obj.PeriodOneExclusionTolerance;
            attempt.mapDiagnostics = mapDiagnostics;
            if ~attempt.periodOneExcluded
                attempt.accepted = false;
                attempt.failureReasons{end + 1} = sprintf( ...
                    ['period-one exclusion failed: ||P_C(u)-u||_inf=', ...
                     '%.3e <= %.3e'], attempt.periodOneDistance, ...
                    obj.PeriodOneExclusionTolerance);
            end
            attempt.message = obj.attemptMessage(attempt);
        end

        function [residual, info, diagnostics] = doubledResidual( ...
                obj, mapFunction, u, p, q, varargin)
            [first, firstInfo] = obj.evaluateCallback(mapFunction, u, p, q);
            qSecond = obj.memberAny(firstInfo, ...
                {'final_mode', 'finalMode', 'return_mode', 'mode'}, q);
            [second, secondInfo] = obj.evaluateCallback( ...
                mapFunction, first, p, qSecond);
            residual = second(:) - u(:);
            info = obj.combineMapInfo(firstInfo, secondInfo);
            periodOneDistance = norm(first(:) - u(:), Inf);
            periodOneExcluded = periodOneDistance > ...
                obj.PeriodOneExclusionTolerance;
            diagnostics = struct( ...
                'firstReturnState', first(:), ...
                'secondReturnState', second(:), ...
                'firstReturnInfo', firstInfo, ...
                'secondReturnInfo', secondInfo, ...
                'periodOneDistance', periodOneDistance, ...
                'periodOneExclusionTolerance', ...
                    obj.PeriodOneExclusionTolerance, ...
                'periodOneExcluded', periodOneExcluded, ...
                'doubledResidualNorm', norm(residual, Inf));
            info.doubled_map_diagnostics = diagnostics;
            info.period_one_distance = periodOneDistance;
            info.period_one_excluded = periodOneExcluded;
            info.period_two_valid = periodOneExcluded;
            if ~periodOneExcluded
                % This is part of the nonlinear corrector's validity
                % contract, not only a post-processing classification.
                % RootSolver_v3 therefore rejects line-search trials that
                % collapse onto the parent period-one branch.
                info.success = false;
                info.valid = false;
                info.integration_success = false;
                info.failure_reason = sprintf( ...
                    ['period-one exclusion failed: ||P_C(u)-u||_inf=', ...
                     '%.3e <= %.3e'], periodOneDistance, ...
                    obj.PeriodOneExclusionTolerance);
            end
        end

        function [z, solveInfo] = solveCorrector(obj, augmented, zPredict)
            solver = obj.RootSolver;
            solver.ResidualAcceptanceTolerance = ...
                obj.ResidualAcceptanceTolerance;
            [z, solveInfo] = solver.solve( ...
                augmented, zPredict, zeros(0, 1), []);
        end

        function attempt = assessAttempt(obj, critical, predictor, ...
                solveInfo, u, p, mode, residual, info, z, zStar)
            attempt = obj.emptyAttempt();
            attempt.sign = predictor.sign;
            attempt.predictor = predictor;
            attempt.state = u(:);
            attempt.parameter = p(:);
            attempt.mode = mode;
            attempt.extendedState = z(:);
            attempt.residual = residual(:);
            attempt.residualNorm = norm(residual(:), Inf);
            attempt.rootInfo = solveInfo;
            attempt.converged = obj.member(solveInfo, 'converged', false);
            attempt.parentDistance = obj.parentDistance(z, zStar, u, p, mode);
            [attempt.admissible, admissibilityEvidence] = ...
                obj.admissibilityStatus(info);
            [attempt.cycleClosed, cycleEvidence] = obj.cycleStatus(info);
            [attempt.modeClosed, modeEvidence] = obj.modeStatus(info);
            attempt.topology = obj.topologyRecord(critical, info);
            attempt.topologyRecorded = attempt.topology.recorded;
            [attempt.topologyReliable, reliabilityEvidence] = ...
                obj.explicitLogical(info, ...
                    {'reliable', 'floquetReliable', 'derivative_reliable'});
            [attempt.topologyCompatible, compatibilityEvidence] = ...
                obj.explicitLogical(info, ...
                    {'topologyCompatible', 'topology_compatible'});
            attempt.evaluationInfo = info;
            reasons = {};
            if ~attempt.converged
                reasons{end + 1} = 'nonlinear corrector did not converge';
            end
            if attempt.residualNorm > obj.ResidualAcceptanceTolerance
                reasons{end + 1} = sprintf( ... %#ok<AGROW>
                    'periodic residual %.3e exceeds %.3e', ...
                    attempt.residualNorm, obj.ResidualAcceptanceTolerance);
            end
            if attempt.parentDistance <= obj.ParentDistanceTolerance
                reasons{end + 1} = sprintf( ... %#ok<AGROW>
                    'candidate is not separated from the parent (%.3e)', ...
                    attempt.parentDistance);
            end
            if obj.RequirePhysicalAdmissibility && ...
                    (~admissibilityEvidence || ~attempt.admissible)
                reasons{end + 1} = ... %#ok<AGROW>
                    'physical admissibility was absent or failed';
            end
            if obj.RequireCycleClosure && (~cycleEvidence || ~attempt.cycleClosed)
                reasons{end + 1} = ... %#ok<AGROW>
                    'full hybrid event-cycle closure was absent or failed';
            end
            if obj.RequireModeClosure && (~modeEvidence || ~attempt.modeClosed)
                reasons{end + 1} = ... %#ok<AGROW>
                    'discrete mode closure was absent or failed';
            end
            if obj.RequireTopologyMetadata && ...
                    (~attempt.topologyRecorded || ...
                     ~attempt.topology.complete || ...
                     ~reliabilityEvidence || ...
                     ~attempt.topologyReliable || ~compatibilityEvidence || ...
                     ~attempt.topologyCompatible)
                reasons{end + 1} = [ ...
                    'complete, reliable, compatible hybrid topology ', ...
                    'metadata were not recorded'];
            end
            attempt.failureReasons = reasons;
            attempt.accepted = isempty(reasons);
            attempt.message = obj.attemptMessage(attempt);
        end

        function result = finishSwitchResult( ...
                obj, result, critical, predictors, attempts)
            result.criticalPoint = critical;
            result.predictors = predictors;
            result.attempts = attempts;
            accepted = [attempts.accepted];
            result.solutions = attempts(accepted);
            result.accepted = any(accepted);
            result.converged = result.accepted;
            result.acceptedSigns = [attempts(accepted).sign];
            result.derivativeModel = 'critical-null-vector-local-corrector';
            result.parentDeflationEnabled = obj.EnableDeflation;
            if result.accepted
                result.classification = [result.type, '_branch_switched'];
                result.message = sprintf( ...
                    '%d of %d signed predictors produced accepted child solutions.', ...
                    sum(accepted), numel(attempts));
            else
                result.classification = [result.type, '_switch_failed'];
                messages = unique(string({attempts.message}), 'stable');
                result.message = char(strjoin(messages, ' | '));
            end
        end

        function factor = deflationFactor(obj, z, zStar, u, p, mode)
            if ~obj.EnableDeflation
                factor = 1;
                return
            end
            distance = obj.parentDistance(z, zStar, u, p, mode);
            distance = max(distance, sqrt(eps));
            factor = distance.^(-obj.DeflationPower) + obj.DeflationShift;
        end

        function distance = parentDistance(obj, z, zStar, u, p, mode)
            if isempty(obj.ParentBranchDistanceFunction)
                scale = 1 + abs(zStar(:));
                distance = norm((z(:) - zStar(:)) ./ scale, 2);
                return
            end
            callback = obj.ParentBranchDistanceFunction;
            argumentCount = nargin(callback);
            if argumentCount == 1
                distance = callback(z);
            elseif argumentCount == 2
                distance = callback(u, p);
            else
                distance = callback(u, p, mode);
            end
            if ~(isscalar(distance) && isreal(distance) && isfinite(distance) && ...
                    distance >= 0)
                error('BranchSwitching_v3:ParentDistance', ...
                    'ParentBranchDistanceFunction must return a finite nonnegative scalar.');
            end
        end

        function [value, info] = evaluateCallback(~, callback, u, p, q)
            if ~isa(callback, 'function_handle')
                error('BranchSwitching_v3:Callback', ...
                    'Residual and map callbacks must be function handles.');
            end
            argumentCount = nargin(callback);
            if argumentCount == 1
                arguments = {u};
            elseif argumentCount == 2
                arguments = {u, p};
            else
                arguments = {u, p, q};
            end
            info = struct();
            try
                [value, info] = callback(arguments{:});
            catch exception
                if ~BranchSwitching_v3.tooManyOutputs(exception)
                    rethrow(exception)
                end
                value = callback(arguments{:});
            end
            if ~(isnumeric(value) && isvector(value) && all(isfinite(value(:))))
                error('BranchSwitching_v3:CallbackValue', ...
                    'Callback values must be finite numeric vectors.');
            end
            value = value(:);
            if isempty(info)
                info = struct();
            end
            if ~isstruct(info)
                error('BranchSwitching_v3:CallbackMetadata', ...
                    'Callback metadata must be a structure.');
            end
        end

        function combined = combineMapInfo(obj, first, second)
            combined = struct();
            combined.success = obj.logicalStatus(first, ...
                {'success', 'valid', 'integration_success'}, true) && ...
                obj.logicalStatus(second, ...
                {'success', 'valid', 'integration_success'}, true);
            combined.valid = combined.success;
            combined.admissible = obj.logicalStatus(first, ...
                {'admissible', 'physically_admissible'}, false) && ...
                obj.logicalStatus(second, ...
                {'admissible', 'physically_admissible'}, false);
            combined.cycle_complete = obj.logicalStatus(first, ...
                {'cycle_complete', 'cycleComplete', ...
                 'return_policy_accepted'}, false) && ...
                obj.logicalStatus(second, ...
                {'cycle_complete', 'cycleComplete', ...
                 'return_policy_accepted'}, false);
            combined.mode_closed = obj.logicalStatus(first, ...
                {'mode_closed', 'modeClosure', 'discrete_closed'}, false) && ...
                obj.logicalStatus(second, ...
                {'mode_closed', 'modeClosure', 'discrete_closed'}, false);
            combined.reliable = obj.logicalStatus(first, ...
                {'reliable', 'floquetReliable', 'derivative_reliable'}, false) && ...
                obj.logicalStatus(second, ...
                {'reliable', 'floquetReliable', 'derivative_reliable'}, false);
            combined.topologyCompatible = obj.logicalStatus(first, ...
                {'topologyCompatible', 'topology_compatible'}, false) && ...
                obj.logicalStatus(second, ...
                {'topologyCompatible', 'topology_compatible'}, false);
            combined.cyclic_event_signature = obj.joinSignatures( ...
                obj.signature(first, 'cyclic'), obj.signature(second, 'cyclic'));
            combined.section_relative_event_signature = obj.joinSignatures( ...
                obj.signature(first, 'section'), obj.signature(second, 'section'));
            combined.event_cluster_signature = obj.joinSignatures( ...
                obj.signature(first, 'cluster'), obj.signature(second, 'cluster'));
            [firstMultiplicity, firstMultiplicityPresent] = ...
                obj.numericEvidence(first, {'return_multiplicity', ...
                    'returnMultiplicity'});
            [secondMultiplicity, secondMultiplicityPresent] = ...
                obj.numericEvidence(second, {'return_multiplicity', ...
                    'returnMultiplicity'});
            if firstMultiplicityPresent && secondMultiplicityPresent
                combined.return_multiplicity = ...
                    firstMultiplicity + secondMultiplicity;
            else
                combined.return_multiplicity = NaN;
            end
            combined.return_multiplicity_evidence = ...
                firstMultiplicityPresent && secondMultiplicityPresent;

            combined = obj.combineNegativeTopologyEvidence(combined, ...
                first, second, 'hybridChartBoundary', ...
                {'hybridChartBoundary', 'hybrid_chart_boundary'});
            combined = obj.combineNegativeTopologyEvidence(combined, ...
                first, second, 'section_event_coincidence', ...
                {'section_event_coincidence', ...
                 'sectionEventCoincidence'});
            combined = obj.combineNegativeTopologyEvidence(combined, ...
                first, second, 'section_cluster_coincidence', ...
                {'section_cluster_coincidence', ...
                 'sectionClusterCoincidence'});
            combined = obj.combineNegativeTopologyEvidence(combined, ...
                first, second, 'unresolvedSimultaneousOrdering', ...
                {'unresolvedSimultaneousOrdering', ...
                 'unresolved_simultaneous_ordering'});
            combined.first_cycle = first;
            combined.second_cycle = second;
        end

        function record = topologyRecord(obj, critical, info)
            criticalTopology = obj.member(critical, 'topology', struct());
            cyclic = obj.signature(info, 'cyclic');
            section = obj.signature(info, 'section');
            cluster = obj.signature(info, 'cluster');
            [multiplicity, multiplicityPresent] = obj.numericEvidence( ...
                info, {'return_multiplicity', 'returnMultiplicity'});
            multiplicityValid = multiplicityPresent && ...
                multiplicity >= 1 && multiplicity == floor(multiplicity);
            [chartBoundary, chartBoundaryPresent] = obj.explicitLogical( ...
                info, {'hybridChartBoundary', 'hybrid_chart_boundary'});
            [sectionEventCoincidence, sectionEventPresent] = ...
                obj.explicitLogical(info, {'section_event_coincidence', ...
                    'sectionEventCoincidence'});
            [sectionClusterCoincidence, sectionClusterPresent] = ...
                obj.explicitLogical(info, {'section_cluster_coincidence', ...
                    'sectionClusterCoincidence'});
            [unresolvedOrdering, unresolvedOrderingPresent] = ...
                obj.explicitLogical(info, ...
                    {'unresolvedSimultaneousOrdering', ...
                     'unresolved_simultaneous_ordering'});
            signatureEvidence = [~isempty(strtrim(cyclic)), ...
                ~isempty(strtrim(section)), ~isempty(strtrim(cluster))];
            negativeBoundaryEvidence = chartBoundaryPresent && ...
                sectionEventPresent && sectionClusterPresent && ...
                unresolvedOrderingPresent && ~chartBoundary && ...
                ~sectionEventCoincidence && ~sectionClusterCoincidence && ...
                ~unresolvedOrdering;
            complete = all(signatureEvidence) && multiplicityValid && ...
                negativeBoundaryEvidence;
            record = struct( ...
                'recorded', complete, ...
                'complete', complete, ...
                'cyclicSignature', cyclic, ...
                'sectionRelativeSignature', section, ...
                'eventClusterSignature', cluster, ...
                'signatureEvidence', signatureEvidence, ...
                'returnMultiplicity', multiplicity, ...
                'returnMultiplicityPresent', multiplicityPresent, ...
                'returnMultiplicityValid', multiplicityValid, ...
                'hybridChartBoundary', chartBoundary, ...
                'hybridChartBoundaryPresent', chartBoundaryPresent, ...
                'sectionEventCoincidence', sectionEventCoincidence, ...
                'sectionEventCoincidencePresent', sectionEventPresent, ...
                'sectionClusterCoincidence', sectionClusterCoincidence, ...
                'sectionClusterCoincidencePresent', ...
                    sectionClusterPresent, ...
                'unresolvedSimultaneousOrdering', unresolvedOrdering, ...
                'unresolvedSimultaneousOrderingPresent', ...
                    unresolvedOrderingPresent, ...
                'negativeBoundaryEvidence', negativeBoundaryEvidence, ...
                'critical', criticalTopology, ...
                'solution', info);
        end

        function [status, evidence] = admissibilityStatus(obj, info)
            names = {'admissible', 'physically_admissible', ...
                'physical_admissibility'};
            [status, evidence] = obj.explicitLogical(info, names);
        end

        function [status, evidence] = cycleStatus(obj, info)
            names = {'cycle_complete', 'cycleComplete', ...
                'return_policy_accepted', 'full_cycle_closed'};
            [status, evidence] = obj.explicitLogical(info, names);
        end

        function [status, evidence] = modeStatus(obj, info)
            names = {'mode_closed', 'modeClosure', 'discrete_closed', ...
                'discreteClosure'};
            [status, evidence] = obj.explicitLogical(info, names);
        end

        function [status, evidence] = explicitLogical(~, source, names)
            status = false;
            evidence = false;
            if ~isstruct(source)
                return
            end
            for index = 1:numel(names)
                if isfield(source, names{index}) && ...
                        isscalar(source.(names{index})) && ...
                        (islogical(source.(names{index})) || ...
                         isnumeric(source.(names{index}))) && ...
                        isfinite(double(source.(names{index})))
                    evidence = true;
                    status = logical(source.(names{index}));
                    return
                end
            end
        end

        function [value, present] = logicalEvidence(~, sources, names)
            value = false;
            present = false;
            for sourceIndex = 1:numel(sources)
                source = sources{sourceIndex};
                if ~(isstruct(source) && isscalar(source))
                    continue
                end
                for nameIndex = 1:numel(names)
                    name = names{nameIndex};
                    if isfield(source, name) && isscalar(source.(name)) && ...
                            (islogical(source.(name)) || ...
                             isnumeric(source.(name))) && ...
                            isfinite(double(source.(name)))
                        value = logical(source.(name));
                        present = true;
                        return
                    end
                end
            end
        end

        function [value, present] = logicalAnyEvidence(~, sources, names)
            value = false;
            present = false;
            for sourceIndex = 1:numel(sources)
                source = sources{sourceIndex};
                if ~(isstruct(source) && isscalar(source))
                    continue
                end
                for nameIndex = 1:numel(names)
                    name = names{nameIndex};
                    if isfield(source, name) && isscalar(source.(name)) && ...
                            (islogical(source.(name)) || ...
                             isnumeric(source.(name))) && ...
                            isfinite(double(source.(name)))
                        present = true;
                        value = value || logical(source.(name));
                    end
                end
            end
        end

        function status = logicalStatus(obj, source, names, default)
            [status, evidence] = obj.explicitLogical(source, names);
            if ~evidence
                status = default;
            end
        end

        function signature = signature(obj, source, kind)
            switch kind
                case 'cyclic'
                    names = {'cyclic_event_signature', ...
                        'cyclicEventSignature', 'cycle_signature'};
                case 'section'
                    names = {'section_relative_event_signature', ...
                        'sectionRelativeEventSignature', 'event_signature', ...
                        'eventSignature'};
                otherwise
                    names = {'event_cluster_signature', ...
                        'eventClusterSignature', 'cluster_signature'};
            end
            signature = obj.memberAny(source, names, '');
            if isstring(signature)
                signature = char(strjoin(signature(:), '|'));
            elseif iscell(signature)
                signature = char(strjoin(string(signature(:)), '|'));
            elseif isnumeric(signature) || islogical(signature)
                signature = mat2str(signature);
            elseif ~ischar(signature)
                signature = '';
            end
        end

        function joined = joinSignatures(~, first, second)
            if isempty(strtrim(first)) || isempty(strtrim(second))
                joined = '';
            else
                joined = [first, ' || ', second];
            end
        end

        function combined = combineNegativeTopologyEvidence( ...
                obj, combined, first, second, outputName, inputNames)
            [firstValue, firstPresent] = obj.explicitLogical( ...
                first, inputNames);
            [secondValue, secondPresent] = obj.explicitLogical( ...
                second, inputNames);
            evidenceName = [outputName, 'Evidence'];
            combined.(evidenceName) = firstPresent && secondPresent;
            if combined.(evidenceName)
                combined.(outputName) = firstValue || secondValue;
            else
                combined.(outputName) = NaN;
            end
        end

        function [value, present] = numericEvidence(obj, source, names)
            value = obj.memberAny(source, names, []);
            present = isnumeric(value) && isscalar(value) && ...
                isreal(value) && isfinite(value);
            if ~present
                value = NaN;
            end
        end

        function [eligible, reason] = criticalEligible(obj, critical)
            eligible = isstruct(critical) && isscalar(critical);
            reason = '';
            if ~eligible
                reason = 'A scalar refined-critical-point structure is required.';
                return
            end
            if ~isfield(critical, 'converged') || ...
                    ~isscalar(critical.converged) || ...
                    ~logical(critical.converged)
                eligible = false;
                reason = ['Explicit evidence of a converged critical-point ', ...
                    'refinement is required.'];
                return
            end
            topology = obj.member(critical, 'topology', struct());
            sources = {critical, topology};
            [reliable, reliabilityPresent] = obj.logicalEvidence( ...
                sources, {'reliable', 'floquetReliable', 'floquet_reliable'});
            if ~reliabilityPresent || ~reliable
                eligible = false;
                reason = ['Explicit reliable Floquet/critical-derivative ', ...
                    'evidence is required for branch switching.'];
                return
            end
            [compatible, compatibilityPresent] = obj.logicalEvidence( ...
                sources, {'topologyCompatible', 'topology_compatible'});
            if ~compatibilityPresent || ~compatible
                eligible = false;
                reason = ['Explicit compatible-topology evidence is required ', ...
                    'for branch switching.'];
                return
            end
            [boundary, boundaryPresent] = obj.logicalAnyEvidence(sources, ...
                {'hybridChartBoundary', 'hybrid_chart_boundary'});
            [coincidence, coincidencePresent] = obj.logicalAnyEvidence( ...
                sources, {'section_event_coincidence', ...
                'section_cluster_coincidence'});
            [unresolved, orderingPresent] = obj.logicalAnyEvidence(sources, ...
                {'unresolvedSimultaneousOrdering', ...
                'unresolved_simultaneous_ordering'});
            if ~boundaryPresent || ~coincidencePresent || ~orderingPresent
                eligible = false;
                reason = ['Explicit evidence excluding chart boundaries, ', ...
                    'section/event coincidence, and unresolved event ordering ', ...
                    'is required for branch switching.'];
                return
            end
            if boundary || coincidence || unresolved
                eligible = false;
                reason = ['Branch switching is not permitted at an ', ...
                    'unresolved hybrid chart/event-order boundary.'];
                return
            end
            try
                obj.criticalData(critical);
            catch exception
                eligible = false;
                reason = exception.message;
            end
        end

        function [eligible, reason, multiplier] = ...
                criticalEligibleForMultiplier(obj, critical, target, label)
            %CRITICALELIGIBLEFORMULTIPLIER Fail closed on critical type.
            [eligible, reason] = obj.criticalEligible(critical);
            multiplier = NaN;
            if ~eligible
                return
            end
            multiplier = obj.memberAny(critical, ...
                {'criticalMultiplier', 'critical_multiplier', ...
                 'multiplier', 'lambda'}, []);
            if ~(isnumeric(multiplier) && isscalar(multiplier) && ...
                    isfinite(multiplier))
                eligible = false;
                multiplier = NaN;
                reason = sprintf([ ...
                    'An explicit finite scalar critical multiplier near ', ...
                    '%+g is required for %s branch switching.'], ...
                    target, label);
                return
            end
            if abs(multiplier - target) > obj.CriticalMultiplierTolerance
                eligible = false;
                reason = sprintf([ ...
                    'Critical multiplier %s is not within %.3e of the ', ...
                    'required value %+g for %s branch switching.'], ...
                    obj.scalarText(multiplier), ...
                    obj.CriticalMultiplierTolerance, target, label);
            end
        end

        function [u, p, mode, vector] = criticalData(obj, critical)
            u = obj.memberAny(critical, {'state', 'u', 'x'}, []);
            p = obj.memberAny(critical, {'parameter', 'p'}, []);
            mode = obj.memberAny(critical, {'mode', 'initial_mode'}, []);
            vector = obj.memberAny(critical, ...
                {'rightVector', 'right_vector', 'nullVector', ...
                 'eigenvector', 'criticalVector'}, []);
            if ~(isnumeric(u) && isvector(u) && ~isempty(u) && ...
                    all(isfinite(u(:))))
                error('BranchSwitching_v3:CriticalState', ...
                    'The critical state must be a finite nonempty vector.');
            end
            if ~(isnumeric(p) && isvector(p) && ~isempty(p) && ...
                    all(isfinite(p(:))))
                error('BranchSwitching_v3:CriticalParameter', ...
                    'The critical parameter must be a finite nonempty vector.');
            end
            if ~(isnumeric(vector) && isvector(vector) && ...
                    numel(vector) == numel(u) && ...
                    all(isfinite(vector(:))) && norm(vector(:)) > eps)
                error('BranchSwitching_v3:CriticalVector', ...
                    'A finite nonzero critical right vector is required.');
            end
            u = u(:);
            p = p(:);
            vector = real(vector(:));
            if obj.ActiveParameterIndex < 1 || ...
                    obj.ActiveParameterIndex > numel(p) || ...
                    obj.ActiveParameterIndex ~= floor(obj.ActiveParameterIndex)
                error('BranchSwitching_v3:ActiveParameterIndex', ...
                    'ActiveParameterIndex is outside the parameter vector.');
            end
        end

        function record = predictorRecord(~, signValue, uStar, pStar, ...
                mode, direction, epsilon)
            record = struct( ...
                'sign', signValue, ...
                'amplitude', epsilon, ...
                'state', uStar + signValue .* epsilon .* direction, ...
                'parameter', pStar, ...
                'mode', mode, ...
                'direction', direction);
        end

        function vector = normalizeVector(~, vector)
            vector = real(vector(:));
            vector = vector ./ norm(vector, 2);
        end

        function epsilon = optionalAmplitude(obj, varargin)
            epsilon = obj.PredictorAmplitude;
            if isempty(varargin)
                return
            end
            if isscalar(varargin) && isnumeric(varargin{1})
                epsilon = varargin{1};
            elseif numel(varargin) == 2 && strcmpi(varargin{1}, 'Amplitude')
                epsilon = varargin{2};
            else
                error('BranchSwitching_v3:AmplitudeArgument', ...
                    'Supply either an amplitude or ''Amplitude'', value.');
            end
            if ~(isscalar(epsilon) && isreal(epsilon) && ...
                    isfinite(epsilon) && epsilon > 0)
                error('BranchSwitching_v3:PredictorAmplitude', ...
                    'Predictor amplitude must be a positive finite scalar.');
            end
        end

        function actions = symmetryActions(~, symmetry)
            if isnumeric(symmetry)
                actions = {symmetry};
            elseif iscell(symmetry)
                actions = symmetry;
            elseif isobject(symmetry) && isprop(symmetry, 'Actions')
                actions = symmetry.Actions;
            elseif isstruct(symmetry) && isfield(symmetry, 'Actions')
                actions = symmetry.Actions;
            elseif isstruct(symmetry) && isfield(symmetry, 'actions')
                actions = symmetry.actions;
            else
                error('BranchSwitching_v3:SymmetryAction', ...
                    'Supply a matrix, cell array, or object with Actions.');
            end
            if isnumeric(actions)
                actions = {actions};
            end
            if isempty(actions)
                error('BranchSwitching_v3:SymmetryAction', ...
                    'At least one symmetry action is required.');
            end
        end

        function projection = symmetryBreakingProjection( ...
                obj, actions, vector)
            %SYMMETRYBREAKINGPROJECTION Split Fix(G) and its complement.
            vector = real(vector(:));
            dimension = numel(vector);
            constraints = zeros(dimension .* numel(actions), dimension);
            identity = eye(dimension);
            for index = 1:numel(actions)
                action = actions{index};
                obj.validateAction(action, dimension);
                rows = (index - 1) .* dimension + (1:dimension);
                constraints(rows, :) = action - identity;
            end
            fixedBasis = null(constraints, obj.SymmetryTolerance);
            if isempty(fixedBasis)
                fixedBasis = zeros(dimension, 0);
                breakingBasis = eye(dimension);
            elseif size(fixedBasis, 2) == dimension
                breakingBasis = zeros(dimension, 0);
            else
                breakingBasis = null(fixedBasis', obj.SymmetryTolerance);
            end
            fixedProjector = fixedBasis * fixedBasis';
            breakingProjector = identity - fixedProjector;
            projected = breakingProjector * vector;
            projectionNorm = norm(projected, 2);
            vectorNorm = norm(vector, 2);
            relativeNorm = projectionNorm / max(vectorNorm, eps);
            threshold = obj.SymmetryTolerance * max(1, vectorNorm);
            hasComponent = projectionNorm > threshold;
            if hasComponent
                projectedDirection = projected / projectionNorm;
            else
                projectedDirection = zeros(dimension, 1);
            end
            projection = struct( ...
                'originalVector', vector, ...
                'projectedVector', projectedDirection, ...
                'unnormalizedProjectedVector', projected, ...
                'fixedComponent', fixedProjector * vector, ...
                'fixedSubspaceBasis', fixedBasis, ...
                'symmetryBreakingBasis', breakingBasis, ...
                'fixedSubspaceProjector', fixedProjector, ...
                'symmetryBreakingProjector', breakingProjector, ...
                'fixedSubspaceDimension', size(fixedBasis, 2), ...
                'symmetryBreakingDimension', size(breakingBasis, 2), ...
                'projectionNorm', projectionNorm, ...
                'relativeBreakingComponent', relativeNorm, ...
                'projectionThreshold', threshold, ...
                'hasNonzeroBreakingComponent', hasComponent, ...
                'orthogonalityResidual', ...
                    norm(fixedBasis' * projected, 2), ...
                'projectorIdempotenceResidual', ...
                    norm(breakingProjector * breakingProjector - ...
                        breakingProjector, 2));
        end

        function record = symmetryRecord(~, actions, projection, ...
                originalRepresentation, projectedRepresentation, ...
                parentStabilizer, attempts)
            childStabilizers = {};
            if ~isempty(attempts) && isfield(attempts, 'childStabilizer')
                childStabilizers = {attempts.childStabilizer};
            end
            record = struct( ...
                'actionCount', numel(actions), ...
                'actions', {actions}, ...
                'fixedSubspaceBasis', projection.fixedSubspaceBasis, ...
                'symmetryBreakingBasis', ...
                    projection.symmetryBreakingBasis, ...
                'fixedSubspaceProjector', ...
                    projection.fixedSubspaceProjector, ...
                'symmetryBreakingProjector', ...
                    projection.symmetryBreakingProjector, ...
                'fixedSubspaceDimension', ...
                    projection.fixedSubspaceDimension, ...
                'symmetryBreakingDimension', ...
                    projection.symmetryBreakingDimension, ...
                'originalCriticalVector', projection.originalVector, ...
                'projectedCriticalVector', projection.projectedVector, ...
                'unnormalizedProjectedCriticalVector', ...
                    projection.unnormalizedProjectedVector, ...
                'relativeBreakingComponent', ...
                    projection.relativeBreakingComponent, ...
                'projectionNorm', projection.projectionNorm, ...
                'projectionThreshold', projection.projectionThreshold, ...
                'projectionOrthogonalityResidual', ...
                    projection.orthogonalityResidual, ...
                'hasNonzeroBreakingComponent', ...
                    projection.hasNonzeroBreakingComponent, ...
                'originalCriticalVectorRepresentation', ...
                    originalRepresentation, ...
                'criticalVectorRepresentation', ...
                    projectedRepresentation, ...
                'criticalVectorBreaksSymmetry', ...
                    projection.hasNonzeroBreakingComponent && ...
                    isstruct(projectedRepresentation) && ...
                    isfield(projectedRepresentation, 'invariant') && ...
                    any(~projectedRepresentation.invariant), ...
                'parentStabilizer', {parentStabilizer}, ...
                'childStabilizers', {childStabilizers}, ...
                'bifurcationClassification', ...
                    'not_inferred_from_unit_multiplier');
        end

        function representation = vectorRepresentation(obj, actions, vector)
            vector = vector(:);
            characters = NaN(1, numel(actions));
            residuals = NaN(1, numel(actions));
            invariant = false(1, numel(actions));
            for index = 1:numel(actions)
                action = actions{index};
                obj.validateAction(action, numel(vector));
                transformed = action * vector;
                characters(index) = real(vector' * transformed) / ...
                    real(vector' * vector);
                residuals(index) = norm(transformed - vector, 2) / ...
                    max(1, norm(vector, 2));
                invariant(index) = residuals(index) <= obj.SymmetryTolerance;
            end
            representation = struct( ...
                'characters', characters, ...
                'invarianceResiduals', residuals, ...
                'invariant', invariant, ...
                'label', obj.representationLabel(invariant));
        end

        function names = stabilizer(obj, actions, state)
            names = {};
            if isempty(state)
                return
            end
            state = state(:);
            for index = 1:numel(actions)
                action = actions{index};
                obj.validateAction(action, numel(state));
                residual = norm(action * state - state, 2) / ...
                    max(1, norm(state, 2));
                if residual <= obj.SymmetryTolerance
                    names{end + 1} = sprintf('g%d', index); %#ok<AGROW>
                end
            end
        end

        function validateAction(~, action, dimension)
            if ~(isnumeric(action) && isreal(action) && ...
                    isequal(size(action), [dimension, dimension]) && ...
                    all(isfinite(action(:))))
                error('BranchSwitching_v3:SymmetryDimension', ...
                    'Every symmetry action must match the state dimension.');
            end
        end

        function label = representationLabel(~, invariant)
            if all(invariant)
                label = 'fixed-subspace';
            elseif any(invariant)
                label = 'mixed-generator-isotropy';
            else
                label = 'symmetry-breaking-subspace';
            end
        end

        function solution = acceptedSolution(~, input)
            if isstruct(input) && isfield(input, 'accepted') && ...
                    isscalar(input.accepted) && logical(input.accepted) && ...
                    isfield(input, 'state')
                solution = input;
                return
            end
            if isstruct(input) && isfield(input, 'solutions') && ...
                    ~isempty(input.solutions)
                solution = input.solutions(1);
                return
            end
            error('BranchSwitching_v3:AcceptedSolution', ...
                'An accepted switched solution is required for continuation.');
        end

        function value = branchProvenance(obj, solution)
            value = struct( ...
                'parentDistance', solution.parentDistance, ...
                'predictorSign', solution.sign, ...
                'topology', solution.topology, ...
                'periodOneExclusionTolerance', ...
                    obj.PeriodOneExclusionTolerance, ...
                'derivativeModel', ...
                    'critical-null-vector-local-corrector');
        end

        function message = attemptMessage(~, attempt)
            if attempt.accepted
                message = 'Corrected child passed all branch-switch acceptance checks.';
            else
                message = strjoin(attempt.failureReasons, '; ');
            end
        end

        function result = emptySwitchResult(~, type)
            result = struct( ...
                'type', type, ...
                'accepted', false, ...
                'converged', false, ...
                'classification', 'unattempted', ...
                'criticalPoint', struct(), ...
                'predictors', struct(), ...
                'attempts', struct([]), ...
                'solutions', struct([]), ...
                'acceptedSigns', [], ...
                'derivativeModel', '', ...
                'parentDeflationEnabled', false, ...
                'criticalMultiplier', NaN, ...
                'requiredCriticalMultiplier', NaN, ...
                'criticalMultiplierTolerance', NaN, ...
                'periodOneExclusionTolerance', NaN, ...
                'projectedCriticalPoint', struct(), ...
                'symmetry', struct(), ...
                'message', '');
        end

        function attempt = emptyAttempt(~)
            attempt = struct( ...
                'sign', NaN, ...
                'accepted', false, ...
                'converged', false, ...
                'predictor', struct(), ...
                'state', [], ...
                'parameter', [], ...
                'mode', [], ...
                'extendedState', [], ...
                'residual', [], ...
                'residualNorm', Inf, ...
                'parentDistance', 0, ...
                'admissible', false, ...
                'cycleClosed', false, ...
                'modeClosed', false, ...
                'topologyRecorded', false, ...
                'topologyReliable', false, ...
                'topologyCompatible', false, ...
                'topology', struct(), ...
                'evaluationInfo', struct(), ...
                'rootInfo', struct(), ...
                'correctorEquation', '', ...
                'branchSeparationConstraint', NaN, ...
                'targetBranchSeparation', NaN, ...
                'periodOneDistance', NaN, ...
                'periodOneExcluded', false, ...
                'mapDiagnostics', struct(), ...
                'parentStabilizer', {{}}, ...
                'childStabilizer', {{}}, ...
                'criticalRepresentation', struct(), ...
                'symmetryBreakingProjectionResidual', NaN, ...
                'failureReasons', {{}}, ...
                'message', '');
        end

        function obj = applyOptions(obj, options)
            if ~(isstruct(options) && isscalar(options))
                error('BranchSwitching_v3:Options', ...
                    'Options must be a scalar structure.');
            end
            names = fieldnames(options);
            for index = 1:numel(names)
                obj = obj.setOption(names{index}, options.(names{index}));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin), 2) ~= 0
                error('BranchSwitching_v3:NameValue', ...
                    'Options must be supplied as name/value pairs.');
            end
            for index = 1:2:numel(varargin)
                obj = obj.setOption(varargin{index}, varargin{index + 1});
            end
        end

        function obj = setOption(obj, name, value)
            names = properties(obj);
            match = find(strcmpi(char(name), names), 1);
            if isempty(match)
                error('BranchSwitching_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(names{match}) = value;
        end

        function validateOptions(obj)
            positive = [obj.PredictorAmplitude, ...
                obj.ResidualAcceptanceTolerance, ...
                obj.ParentDistanceTolerance, ...
                obj.PeriodOneExclusionTolerance, ...
                obj.CriticalMultiplierTolerance, obj.SymmetryTolerance, ...
                obj.DeflationPower, obj.DeflationShift];
            if any(~isfinite(positive)) || any(positive <= 0)
                error('BranchSwitching_v3:Options', ...
                    'Amplitudes, tolerances, and deflation values must be positive.');
            end
            if ~(isempty(obj.ParentBranchDistanceFunction) || ...
                    isa(obj.ParentBranchDistanceFunction, 'function_handle'))
                error('BranchSwitching_v3:ParentDistanceFunction', ...
                    'ParentBranchDistanceFunction must be empty or a function handle.');
            end
            if ~isa(obj.RootSolver, 'RootSolver_v3')
                error('BranchSwitching_v3:RootSolver', ...
                    'RootSolver must be a RootSolver_v3 object.');
            end
        end

        function value = member(~, source, name, default)
            value = default;
            if isstruct(source) && isfield(source, name)
                value = source.(name);
            end
        end

        function value = memberAny(obj, source, names, default)
            value = default;
            if ~isstruct(source)
                return
            end
            for index = 1:numel(names)
                candidate = obj.member(source, names{index}, []);
                if ~isempty(candidate)
                    value = candidate;
                    return
                end
            end
        end

        function value = numericMember(obj, source, names, default)
            value = obj.memberAny(source, names, default);
            if ~(isscalar(value) && isnumeric(value) && isfinite(value))
                value = default;
            end
        end

        function value = scalarText(~, number)
            if isreal(number)
                value = sprintf('%.16g', number);
            else
                value = sprintf('%.16g%+.16gi', real(number), imag(number));
            end
        end
    end

    methods (Static, Access = private)
        function tf = tooManyOutputs(exception)
            tf = any(strcmp(exception.identifier, { ...
                'MATLAB:maxlhs', 'MATLAB:TooManyOutputs', ...
                'MATLAB:unassignedOutputs'}));
        end
    end
end
