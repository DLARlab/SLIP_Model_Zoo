classdef PseudoArclengthContinuation_v3
    %PSEUDOARCLENGTHCONTINUATION_V3 One-parameter predictor/corrector.
    %   For u in R^m and one active scalar parameter mu, the corrector is
    %
    %       [ R(u,p(mu));
    %         t' * (([u;mu]-[u0;mu0])./scale) - ds ] = 0.
    %
    %   The tangent is the one-dimensional null vector of the finite-
    %   difference Jacobian of R with respect to [u;mu].  The full model
    %   parameter vector is retained, but only one scalar parameter is
    %   freed; otherwise the displayed system would be underdetermined.

    properties
        RootSolver = []
        Jacobian = []
        ActiveParameterIndex = 1
        ActiveParameter = []
        StepSize = 0.02
        MinimumStepSize = 1e-5
        MaximumStepSize = 0.2
        StepGrowth = 1.25
        StepShrink = 0.5
        MaxPoints = 100
        InitialDirection = 1
        InitialTangent = []
        AutoScale = true
        Scale = []
        ParameterBounds = [-Inf, Inf]
        ComputeStability = false
        StabilityAnalyzer = []
        Display = 'off'
        ReuseCorrectorJacobian = true
    end

    methods
        function obj = PseudoArclengthContinuation_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            if isempty(obj.RootSolver)
                obj.RootSolver = RootSolver_v3();
            end
            if isempty(obj.Jacobian)
                obj.Jacobian = HybridFiniteDifferenceJacobian_v3();
            end
            obj.validateOptions();
        end

        function branch = run(obj, residual, u0, p0, q0)
            pReference = p0(:);
            [index, parameterName] = obj.resolveParameter( ...
                residual, numel(pReference));
            obj.ActiveParameterIndex = index;

            [u, initialSolve] = obj.RootSolver.solve( ...
                residual, u0(:), pReference, q0);
            if ~initialSolve.converged
                error('PseudoArclengthContinuation_v3:InitialPoint', ...
                    'The initial fixed-parameter solve failed: %s', ...
                    initialSolve.message);
            end
            q = initialSolve.mode;
            mu = pReference(index);
            z = [u(:); mu];
            initialPoint = obj.makeInitialPoint( ...
                residual, u, pReference, q, initialSolve);
            initialPoint.index = 1;
            initialPoint.arclength = 0;
            initialPoint.continuationCoordinate = mu;
            initialPoint.stability = obj.computePointStability( ...
                residual, initialPoint);
            points = initialPoint;
            failures = repmat(obj.emptyPoint(), 1, 0);

            [tScaled, scale, tangentInfo] = obj.computeTangent( ...
                residual, z, pReference, q, []);
            points(1).tangent = scale .* tScaled;
            points(1).tangentInfo = tangentInfo;
            previousPhysicalTangent = scale .* tScaled;
            ds = min(max(abs(obj.StepSize), obj.MinimumStepSize), ...
                obj.MaximumStepSize);
            accumulatedLength = 0;
            correctorJacobian = [];

            while numel(points) < obj.MaxPoints
                accepted = false;
                trialStep = ds;
                failurePoint = obj.emptyPoint();
                while trialStep >= obj.MinimumStepSize
                    zPredict = z + trialStep .* (scale .* tScaled);
                    muPredict = zPredict(end);
                    if muPredict < obj.ParameterBounds(1) || ...
                            muPredict > obj.ParameterBounds(2)
                        branch = obj.assembleBranch( ...
                            points, failures, index, parameterName);
                        branch.terminationReason = 'parameter bound reached';
                        return
                    end
                    pPredict = obj.parameterAt(pReference, muPredict);
                    modes = obj.RootSolver.candidateModes( ...
                        residual, zPredict(1:end-1), pPredict, q);
                    if isempty(modes)
                        modes = {q};
                    end

                    [corrected, correction] = obj.correctAcrossModes( ...
                        residual, zPredict, z, tScaled, scale, trialStep, ...
                        pReference, modes, correctorJacobian);
                    if correction.converged
                        accepted = true;
                        zNew = corrected(:);
                        uNew = zNew(1:end-1);
                        muNew = zNew(end);
                        pNew = obj.parameterAt(pReference, muNew);
                        qNew = correction.mode;
                        point = obj.makeCorrectedPoint( ...
                            residual, uNew, pNew, qNew, correction);
                        accumulatedLength = accumulatedLength + trialStep;
                        point.index = numel(points) + 1;
                        point.arclength = accumulatedLength;
                        point.continuationCoordinate = muNew;

                        point.topologyBoundary = ...
                            ~obj.compatibleTopology(points(end), point);
                        if point.topologyBoundary
                            % The accepted orbit remains on the continuous
                            % branch, but no unique smooth tangent is claimed
                            % at the chart boundary. Continue internally with
                            % the incoming predictor until a neighboring
                            % smooth chart supplies a new tangent.
                            nextTScaled = tScaled;
                            nextScale = scale;
                            point.tangent = NaN(size(nextTScaled));
                            point.tangentInfo = struct( ...
                                'topologyBoundary', true, ...
                                'reliable', false, ...
                                'reason', ['hybrid topology changed across ', ...
                                    'this interval; smooth tangent unresolved']);
                            point.stability = struct('reliable', false, ...
                                'warning', ['Floquet analysis is unresolved ', ...
                                'at a marked hybrid topology boundary.']);
                        else
                            [nextTScaled, nextScale, tangentInfo] = ...
                                obj.computeTangent(residual, zNew, ...
                                    pReference, qNew, previousPhysicalTangent);
                            point.tangent = nextScale .* nextTScaled;
                            point.tangentInfo = tangentInfo;
                            point.tangentInfo.topologyBoundary = false;
                            point.stability = obj.computePointStability( ...
                                residual, point);
                        end
                        points(end + 1) = point; %#ok<AGROW>

                        z = zNew;
                        q = qNew;
                        pReference(index) = muNew;
                        previousPhysicalTangent = nextScale .* nextTScaled;
                        tScaled = nextTScaled;
                        scale = nextScale;
                        correctorJacobian = obj.member( ...
                            correction.rootInfo, 'finalJacobian', []);
                        if point.topologyBoundary
                            correctorJacobian = [];
                            ds = max(obj.MinimumStepSize, ...
                                trialStep * obj.StepShrink);
                        else
                            ds = min(obj.MaximumStepSize, ...
                                trialStep * obj.StepGrowth);
                        end
                        if strcmpi(obj.Display, 'iter')
                            fprintf(['Pseudo-arclength point %d: mu=%.12g, ' ...
                                'ds=%.3g, ||G||_inf=%.3e, mode=%s\n'], ...
                                numel(points), muNew, trialStep, ...
                                correction.residualNorm, obj.modeText(qNew));
                        end
                        break
                    end
                    failurePoint = obj.makeFailurePoint( ...
                        zPredict, pPredict, q, correction);
                    trialStep = trialStep * obj.StepShrink;
                end

                if ~accepted
                    failures(end + 1) = failurePoint; %#ok<AGROW>
                    branch = obj.assembleBranch( ...
                        points, failures, index, parameterName);
                    branch.terminationReason = 'corrector failed at minimum step';
                    return
                end
            end
            branch = obj.assembleBranch( ...
                points, failures, index, parameterName);
            branch.terminationReason = 'maximum point count reached';
        end
    end

    methods (Access = private)
        function [zBest, resultBest] = correctAcrossModes(obj, residual, ...
                zPredict, zBase, tScaled, scale, ds, pReference, modes, ...
                previousJacobian)
            resultBest = obj.emptyCorrection();
            zBest = zPredict;
            bestScore = Inf;
            for i = 1:numel(modes)
                qTrial = modes{i};
                augmented = @(candidate, varargin) obj.augmentedResidual( ...
                    residual, candidate, zBase, tScaled, scale, ds, ...
                    pReference, qTrial, varargin{:});
                solver = obj.RootSolver;
                if obj.ReuseCorrectorJacobian && ~isempty(previousJacobian)
                    solver.ReuseJacobian = true;
                    solver.InitialJacobian = previousJacobian;
                    solver.UseBroyden = true;
                end
                [zCandidate, rootInfo] = solver.solve( ...
                    augmented, zPredict, zeros(0, 1), []);
                score = rootInfo.residualNorm;
                if rootInfo.converged
                    score = score - 1;
                end
                if isfinite(score) && score < bestScore
                    bestScore = score;
                    zBest = zCandidate;
                    resultBest = obj.emptyCorrection();
                    resultBest.converged = rootInfo.converged;
                    resultBest.mode = qTrial;
                    resultBest.residual = rootInfo.residual;
                    resultBest.residualNorm = rootInfo.residualNorm;
                    resultBest.rootInfo = rootInfo;
                    resultBest.message = rootInfo.message;
                end
            end
        end

        function [value, metadata] = augmentedResidual(obj, residual, ...
                candidate, zBase, tangent, scale, ds, pReference, q, varargin)
            candidate = candidate(:);
            u = candidate(1:end-1);
            p = obj.parameterAt(pReference, candidate(end));
            context = obj.extractEvaluationContext(varargin);
            [r, metadata] = obj.evaluateResidual( ...
                residual, u, p, q, context);
            arclengthConstraint = tangent' * ((candidate - zBase) ./ scale) - ds;
            value = [r(:); arclengthConstraint];
            if isempty(metadata) || ~isstruct(metadata)
                metadata = struct();
            end
        end

        function [tScaled, scale, info] = computeTangent(obj, residual, z, ...
                pReference, q, previousPhysical)
            scale = obj.scaling(z);
            functionValue = @(candidate, varargin) ...
                obj.evaluateAtExtendedPoint( ...
                residual, candidate, pReference, q, varargin{:});
            [A, ~, fdInfo] = obj.Jacobian.compute(functionValue, z);
            if isa(obj.Jacobian, 'HybridFiniteDifferenceJacobian_v3') ...
                    && (~obj.member(fdInfo, 'allReliable', false) ...
                    || ~obj.member(fdInfo, 'classicalDerivative', false))
                error('PseudoArclengthContinuation_v3:UnreliableTangent', ...
                    ['The extended hybrid derivative does not define a ', ...
                     'reliable classical continuation tangent.']);
            end
            if size(A, 2) ~= size(A, 1) + 1
                error('PseudoArclengthContinuation_v3:TangentDimension', ...
                    ['A one-parameter continuation requires an m-by-(m+1) ' ...
                     'extended Jacobian; received %d-by-%d.'], ...
                    size(A, 1), size(A, 2));
            end
            scaledJacobian = A * diag(scale);
            [~, singularValues, V] = svd(scaledJacobian);
            tScaled = V(:, end);
            tScaled = tScaled ./ norm(tScaled);
            physical = scale .* tScaled;

            if isempty(previousPhysical)
                if ~isempty(obj.InitialTangent)
                    reference = obj.InitialTangent(:);
                    if numel(reference) ~= numel(physical)
                        error('PseudoArclengthContinuation_v3:InitialTangent', ...
                            'InitialTangent has an incompatible dimension.');
                    end
                    if dot(physical, reference) < 0
                        tScaled = -tScaled;
                    end
                elseif sign(tScaled(end)) ~= sign(obj.InitialDirection) && ...
                        abs(tScaled(end)) > sqrt(eps)
                    tScaled = -tScaled;
                end
            elseif dot(physical, previousPhysical) < 0
                tScaled = -tScaled;
            end

            values = diag(singularValues);
            info = struct();
            info.extendedJacobian = A;
            info.scaledJacobian = scaledJacobian;
            info.singularValues = values;
            info.rank = sum(values > max(size(A)) * eps(max(values)));
            info.finiteDifference = fdInfo;
            info.scale = scale;
            info.reliable = obj.member(fdInfo, 'allReliable', true);
        end

        function [r, info] = evaluateAtExtendedPoint( ...
                obj, residual, z, pReference, q, varargin)
            z = z(:);
            p = obj.parameterAt(pReference, z(end));
            [r, info] = obj.evaluateResidual( ...
                residual, z(1:end-1), p, q, varargin{:});
        end

        function [r, info] = evaluateResidual( ...
                obj, residual, u, p, q, varargin)
            info = struct();
            if isa(residual, 'function_handle')
                [r, info] = obj.callResidualFunction( ...
                    residual, u, p, q, varargin{:});
            elseif isobject(residual) && ismethod(residual, 'evaluateWithInfo')
                if isempty(varargin)
                    [r, info] = residual.evaluateWithInfo(u, p, q);
                else
                    [r, info] = residual.evaluateWithInfo( ...
                        u, p, q, varargin{:});
                end
            elseif isobject(residual) && ismethod(residual, 'evaluate')
                r = residual.evaluate(u, p, q);
            elseif isstruct(residual) && isfield(residual, 'evaluateWithInfo')
                [r, info] = obj.callResidualFunction( ...
                    residual.evaluateWithInfo, u, p, q, varargin{:});
            elseif isstruct(residual) && isfield(residual, 'evaluate')
                [r, info] = obj.callResidualFunction( ...
                    residual.evaluate, u, p, q, varargin{:});
            else
                error('PseudoArclengthContinuation_v3:ResidualInterface', ...
                    'Residual must be a function handle or expose evaluate().');
            end
            r = r(:);
            if any(~isfinite(r))
                error('PseudoArclengthContinuation_v3:NonfiniteResidual', ...
                    'The residual contains nonfinite values.');
            end
            if isstruct(info)
                names = {'success', 'valid', 'admissible', ...
                    'integration_success', 'cycle_complete', ...
                    'return_policy_accepted', 'modeClosure', ...
                    'mode_closed', 'discrete_closed'};
                for i = 1:numel(names)
                    if isfield(info, names{i}) && ~info.(names{i})
                        error('PseudoArclengthContinuation_v3:InvalidReturn', ...
                            'The hybrid return map rejected this trial.');
                    end
                end
            end
        end

        function context = extractEvaluationContext(~, arguments)
            context = struct();
            for index = numel(arguments):-1:1
                candidate = arguments{index};
                if isstruct(candidate) && isscalar(candidate) ...
                        && any(isfield(candidate, { ...
                        'finiteDifferenceStep', ...
                        'suggestedRelativeTolerance', 'label', ...
                        'SimulationOptions'}))
                    context = candidate;
                    return
                end
            end
        end

        function [value, info] = callResidualFunction( ...
                obj, fun, u, p, q, varargin)
            info = struct();
            n = nargin(fun);
            if n == 1
                arguments = {u};
            elseif n == 2
                arguments = {u, p};
            elseif n == 3
                arguments = {u, p, q};
            else
                if isempty(varargin)
                    arguments = {u, p, q, struct()};
                else
                    arguments = {u, p, q, varargin{:}};
                end
            end
            try
                [value, info] = fun(arguments{:});
            catch exception
                if ~obj.tooManyOutputs(exception)
                    rethrow(exception)
                end
                value = fun(arguments{:});
                info = struct();
            end
        end

        function tf = tooManyOutputs(~, exception)
            tf = any(strcmp(exception.identifier, { ...
                'MATLAB:maxlhs', 'MATLAB:TooManyOutputs', ...
                'MATLAB:unassignedOutputs'}));
        end

        function scale = scaling(obj, z)
            if ~isempty(obj.Scale)
                scale = obj.Scale(:);
                if isscalar(scale)
                    scale = repmat(scale, numel(z), 1);
                end
                if numel(scale) ~= numel(z) || any(scale <= 0)
                    error('PseudoArclengthContinuation_v3:Scale', ...
                        'Scale must be positive and match [u;mu].');
                end
            elseif obj.AutoScale
                scale = 1 + abs(z(:));
            else
                scale = ones(numel(z), 1);
            end
        end

        function p = parameterAt(obj, reference, mu)
            p = reference(:);
            p(obj.ActiveParameterIndex) = mu;
        end

        function point = makeInitialPoint(obj, residual, u, p, q, solveInfo)
            point = obj.emptyPoint();
            point.x = u(:);
            point.p = p(:);
            point.mode = q;
            point.residual = solveInfo.residual;
            point.residualNorm = solveInfo.residualNorm;
            point.converged = solveInfo.converged;
            point.solverInfo = solveInfo;
            point.orbit = solveInfo.orbit;
            point.fullState = solveInfo.fullState;
            point = obj.populateOrbitFields( ...
                point, residual, solveInfo.evaluationInfo);
        end

        function point = makeCorrectedPoint(obj, residual, u, p, q, correction)
            point = obj.emptyPoint();
            point.x = u(:);
            point.p = p(:);
            point.mode = q;
            point.converged = correction.converged;
            point.solverInfo = correction.rootInfo;
            [baseResidual, evalInfo] = obj.evaluateResidual(residual, u, p, q);
            point.residual = baseResidual;
            point.residualNorm = norm(baseResidual, Inf);
            point.fullState = obj.fullState(residual, u, p, q);
            point.orbit = obj.createOrbit(residual, u, p, q, evalInfo);
            point = obj.populateOrbitFields(point, residual, evalInfo);
        end

        function point = populateOrbitFields(obj, point, residual, evalInfo)
            point.period = obj.member(point.orbit, 'period', NaN);
            point.event_history = obj.member( ...
                point.orbit, 'event_history', {});
            point.mode_history = obj.member( ...
                point.orbit, 'mode_history', {});
            point.stability = obj.member(point.orbit, 'stability', []);
            if isnan(point.period)
                point.period = obj.member(evalInfo, 'period', NaN);
            end
            if isempty(point.event_history)
                point.event_history = obj.member(evalInfo, 'event_history', {});
            end
            if isempty(point.mode_history)
                point.mode_history = obj.member(evalInfo, 'mode_history', {});
            end
            mapInfo = obj.mapInfo(evalInfo);
            sources = obj.metadataSources(mapInfo, evalInfo, point.orbit);
            [point.return_policy, point.return_policy_name, ...
                point.cycle_return_policy] = ...
                obj.returnPolicyMetadata(residual, sources);
            candidateSectionCrossings = obj.memberAnySource( ...
                sources, {'candidate_section_crossings', ...
                'candidateSectionCrossings', ...
                'all_candidate_section_crossings'}, struct([]));
            point.candidate_section_count = obj.sectionCandidateCount( ...
                sources, candidateSectionCrossings);
            point.accepted_crossing_index = obj.acceptedCrossingIndex(sources);
            [point.candidate_apex_count, point.accepted_apex_index] = ...
                obj.apexReturnIndices(residual, sources, ...
                point.candidate_section_count, ...
                point.accepted_crossing_index);
            point.return_multiplicity = obj.memberAnySource(sources, ...
                {'return_multiplicity', 'returnMultiplicity'}, 1);
            point.section_relative_signature = obj.memberAnySource(sources, ...
                {'section_relative_event_signature', ...
                 'sectionRelativeEventSignature', 'event_signature'}, '');
            point.cyclic_signature = obj.memberAnySource(sources, ...
                {'cyclic_event_signature', 'cyclicEventSignature', ...
                 'cycle_signature'}, '');
            point.event_counts = obj.memberAnySource(sources, ...
                {'event_counts', 'eventCounts'}, []);
            point.guard_transversality = obj.memberAnySource(sources, ...
                {'guard_transversality', 'guardTransversality', ...
                 'guard_transversality_margin', ...
                 'guard_transversality_margins', ...
                 'minimum_guard_transversality'}, []);
            point.topology_margins = obj.memberAnySource(sources, ...
                {'topology_margins', 'topologyMargins'}, struct());
            point.stance_force_admissibility_margin = obj.memberAnySource( ...
                sources, {'stance_force_admissibility_margin', ...
                'minimum_stance_admissibility_margin'}, Inf);
            point.section_coincident_events = obj.memberAnySource(sources, ...
                {'section_coincident_events', ...
                 'sectionCoincidentEvents'}, struct([]));
            point.root_statistics = struct( ...
                'functionEvaluations', obj.member(point.solverInfo, ...
                    'functionEvaluationCount', 0), ...
                'mapEvaluations', obj.member(point.solverInfo, ...
                    'mapEvaluationCount', 0), ...
                'cacheHits', obj.member(point.solverInfo, ...
                    'cacheHitCount', 0), ...
                'invalidEvaluations', obj.member(point.solverInfo, ...
                    'invalidEvaluationCount', 0), ...
                'modesAttempted', numel(obj.member( ...
                    point.solverInfo, 'candidateModes', {})));
            point.schema_metadata = obj.schemaMetadataFromInfo(evalInfo);
        end

        function point = makeFailurePoint(obj, z, p, q, correction)
            point = obj.emptyPoint();
            point.x = z(1:end-1);
            point.p = p;
            point.mode = q;
            point.continuationCoordinate = z(end);
            point.residual = correction.residual;
            point.residualNorm = correction.residualNorm;
            point.solverInfo = correction.rootInfo;
        end

        function x = fullState(~, residual, u, p, q)
            x = u(:);
            try
                if isobject(residual) && ismethod(residual, 'fullState')
                    try
                        x = residual.fullState(u, p, q);
                    catch
                        try
                            x = residual.fullState(u, p);
                        catch
                            x = residual.fullState(u);
                        end
                    end
                elseif isstruct(residual) && isfield(residual, 'fullState')
                    n = nargin(residual.fullState);
                    if n == 1
                        x = residual.fullState(u);
                    elseif n == 2
                        x = residual.fullState(u, p);
                    else
                        x = residual.fullState(u, p, q);
                    end
                end
            catch
                x = u(:);
            end
            x = x(:);
        end

        function orbit = createOrbit(~, residual, u, p, q, info)
            orbit = [];
            try
                if isobject(residual) && ismethod(residual, 'createOrbit')
                    try
                        orbit = residual.createOrbit(u, p, q, info);
                    catch
                        orbit = residual.createOrbit(u, p, q);
                    end
                elseif isstruct(residual) && isfield(residual, 'createOrbit')
                    orbit = residual.createOrbit(u, p, q, info);
                end
            catch
                orbit = [];
            end
        end

        function stability = computePointStability(obj, residual, point)
            stability = point.stability;
            if ~obj.ComputeStability || isempty(obj.StabilityAnalyzer)
                return
            end
            try
                analyzer = obj.StabilityAnalyzer;
                if isa(analyzer, 'function_handle')
                    stability = analyzer(residual, point.x, point.p, ...
                        point.mode, point.orbit);
                else
                    map = obj.member(residual, 'Map', []);
                    stability = analyzer.analyze( ...
                        map, point.fullState, point.mode, point.p);
                end
            catch ME
                stability = struct('reliable', false, ...
                    'errorIdentifier', ME.identifier, 'message', ME.message);
            end
        end

        function branch = assembleBranch(~, points, failures, index, ...
                parameterName)
            branch = struct();
            branch.type = 'pseudo-arclength';
            branch.activeParameterIndex = index;
            branch.activeParameter = parameterName;
            branch.points = points;
            branch.failures = failures;
            branch.count = numel(points);
            branch.success = isempty(failures);
            branch.x = [points.x];
            branch.p = [points.p];
            branch.full_state = {points.fullState};
            branch.mode = {points.mode};
            branch.period = [points.period];
            branch.event_history = {points.event_history};
            branch.mode_history = {points.mode_history};
            branch.stability = {points.stability};
            branch.orbit = {points.orbit};
            branch.solver_info = {points.solverInfo};
            branch.arclength = [points.arclength];
            branch.continuationCoordinate = [points.continuationCoordinate];
            branch.tangent = {points.tangent};
            branch.return_policy = {points.return_policy};
            branch.return_policy_name = {points.return_policy_name};
            branch.cycle_return_policy = {points.cycle_return_policy};
            branch.candidate_section_count = [points.candidate_section_count];
            branch.candidate_apex_count = [points.candidate_apex_count];
            branch.accepted_crossing_index = ...
                [points.accepted_crossing_index];
            branch.accepted_apex_index = [points.accepted_apex_index];
            branch.return_multiplicity = [points.return_multiplicity];
            branch.section_relative_signature = ...
                {points.section_relative_signature};
            branch.cyclic_signature = {points.cyclic_signature};
            branch.event_counts = {points.event_counts};
            branch.guard_transversality = {points.guard_transversality};
            branch.topology_margins = {points.topology_margins};
            branch.stance_force_admissibility_margin = ...
                [points.stance_force_admissibility_margin];
            branch.section_coincident_events = ...
                {points.section_coincident_events};
            branch.root_statistics = {points.root_statistics};
            branch.schema_metadata = {points.schema_metadata};
            branch.topology_boundary = [points.topologyBoundary];
        end

        function value = member(~, source, name, default)
            value = default;
            if isempty(source)
                return
            end
            if isstruct(source) && isfield(source, name)
                value = source.(name);
            elseif isobject(source) && isprop(source, name)
                value = source.(name);
            end
        end

        function point = emptyPoint(~)
            point = struct( ...
                'index', [], 'arclength', NaN, ...
                'continuationCoordinate', NaN, 'x', [], 'fullState', [], ...
                'p', [], 'mode', [], 'period', NaN, ...
                'event_history', {{}}, 'mode_history', {{}}, ...
                'stability', [], 'orbit', [], 'tangent', [], ...
                'tangentInfo', struct(), 'residual', [], ...
                'residualNorm', Inf, 'converged', false, ...
                'solverInfo', struct(), 'return_policy', '', ...
                'return_policy_name', '', 'cycle_return_policy', '', ...
                'candidate_section_count', NaN, ...
                'candidate_apex_count', NaN, ...
                'accepted_crossing_index', NaN, ...
                'accepted_apex_index', NaN, ...
                'return_multiplicity', NaN, ...
                'section_relative_signature', '', 'cyclic_signature', '', ...
                'event_counts', [], 'guard_transversality', [], ...
                'topology_margins', struct(), 'root_statistics', struct(), ...
                'stance_force_admissibility_margin', Inf, ...
                'section_coincident_events', {struct([])}, ...
                'schema_metadata', struct(), 'topologyBoundary', false);
        end

        function correction = emptyCorrection(~)
            correction = struct('converged', false, 'mode', [], ...
                'residual', [], 'residualNorm', Inf, 'rootInfo', struct(), ...
                'message', 'No mode candidate converged.');
        end

        function [index, name] = resolveParameter(obj, residual, count)
            selector = obj.ActiveParameter;
            if isempty(selector)
                selector = obj.ActiveParameterIndex;
            end
            names = obj.parameterNames(residual);
            if ischar(selector) || (isstring(selector) && isscalar(selector))
                name = char(selector);
                index = find(strcmp(name, names), 1);
                if isempty(index)
                    error('PseudoArclengthContinuation_v3:ParameterName', ...
                        'Unknown active parameter "%s".', name);
                end
            else
                index = selector;
                if ~(isnumeric(index) && isscalar(index) && isfinite(index) && ...
                        index == floor(index) && index >= 1 && index <= count)
                    error('PseudoArclengthContinuation_v3:ParameterIndex', ...
                        'Active parameter index is outside the parameter vector.');
                end
                if numel(names) >= index
                    name = names{index};
                else
                    name = sprintf('p%d', index);
                end
            end
        end

        function names = parameterNames(obj, residual)
            map = obj.member(residual, 'Map', []);
            system = obj.member(map, 'System', []);
            names = obj.member(system, 'ParameterNames', {});
            if isstring(names)
                names = cellstr(names(:).');
            end
        end

        function info = mapInfo(~, evaluationInfo)
            info = evaluationInfo;
            if isstruct(evaluationInfo) && isfield(evaluationInfo, 'map_info')
                info = evaluationInfo.map_info;
            end
            if isempty(info) || ~isstruct(info)
                info = struct();
            end
        end

        function value = memberAny(obj, source, names, default)
            value = default;
            for index = 1:numel(names)
                candidate = obj.member(source, names{index}, []);
                if ~isempty(candidate)
                    value = candidate;
                    return
                end
            end
        end

        function sources = metadataSources(obj, mapInfo, evaluationInfo, orbit)
            cycleDiagnostics = obj.memberAny(mapInfo, ...
                {'cycle_completion_diagnostics', ...
                'cycleCompletionDiagnostics'}, struct());
            if ~isstruct(cycleDiagnostics) || isempty(fieldnames(cycleDiagnostics))
                cycleDiagnostics = obj.memberAny(orbit, ...
                    {'cycle_completion_diagnostics', ...
                    'cycleCompletionDiagnostics'}, struct());
            end
            policyState = obj.memberAny(mapInfo, ...
                {'policy_state', 'policyState'}, struct());
            sources = {mapInfo, evaluationInfo, orbit, ...
                cycleDiagnostics, policyState};
        end

        function value = memberAnySource(obj, sources, names, default)
            for sourceIndex = 1:numel(sources)
                candidate = obj.memberAny(sources{sourceIndex}, names, []);
                if ~isempty(candidate)
                    value = candidate;
                    return
                end
            end
            value = default;
        end

        function [policy, policyName, cyclePolicy] = ...
                returnPolicyMetadata(obj, residual, sources)
            policy = obj.memberAnySource(sources, ...
                {'return_policy', 'returnPolicy', ...
                'cycle_return_policy', 'cycleReturnPolicy', 'policy'}, '');
            policyName = obj.memberAnySource(sources, ...
                {'return_policy_name', 'returnPolicyName', ...
                'cycle_return_policy_name', 'policy_name', 'name'}, '');
            cyclePolicy = obj.memberAnySource(sources, ...
                {'cycle_return_policy', 'cycleReturnPolicy'}, '');

            map = obj.member(residual, 'Map', []);
            policyObject = obj.member(map, 'ReturnPolicy', []);
            if isempty(policy) && ~isempty(policyObject)
                policy = class(policyObject);
            end
            if isempty(policyName) && ~isempty(policyObject)
                policyName = obj.member(policyObject, 'Name', '');
            end
            policy = obj.metadataText(policy);
            policyName = obj.metadataText(policyName);
            if isempty(cyclePolicy)
                cyclePolicy = policy;
            else
                cyclePolicy = obj.metadataText(cyclePolicy);
            end
        end

        function count = sectionCandidateCount(obj, sources, crossings)
            count = obj.memberAnySource(sources, ...
                {'candidate_section_count', 'candidateSectionCount', ...
                'candidate_section_crossing_count', ...
                'candidateSectionCrossingCount', 'candidate_count'}, []);
            if isempty(count) && ~isempty(crossings)
                count = numel(crossings);
            end
            if isempty(count)
                count = obj.memberAnySource(sources, ...
                    {'accepted_crossing_index', 'acceptedCrossingIndex', ...
                    'accepted_index'}, NaN);
            end
            count = obj.scalarIndex(count);
        end

        function index = acceptedCrossingIndex(obj, sources)
            index = obj.memberAnySource(sources, ...
                {'accepted_crossing_index', 'acceptedCrossingIndex', ...
                'accepted_index', 'candidate_index', ...
                'return_multiplicity', 'returnMultiplicity'}, NaN);
            index = obj.scalarIndex(index);
        end

        function [count, index] = apexReturnIndices(obj, residual, ...
                sources, sectionCount, crossingIndex)
            count = obj.memberAnySource(sources, ...
                {'candidate_apex_count', 'candidateApexCount'}, []);
            index = obj.memberAnySource(sources, ...
                {'accepted_apex_index', 'acceptedApexIndex'}, []);
            map = obj.member(residual, 'Map', []);
            section = obj.member(map, 'Section', []);
            sectionName = lower(string(obj.member(section, 'Name', '')));
            isApex = any(sectionName == "apex");
            if isempty(count) && isApex
                count = sectionCount;
            end
            if isempty(index) && isApex
                index = crossingIndex;
            end
            count = obj.scalarIndex(count);
            index = obj.scalarIndex(index);
        end

        function value = scalarIndex(~, value)
            if isempty(value) || ~(isnumeric(value) || islogical(value)) ...
                    || ~isscalar(value)
                value = NaN;
            else
                value = double(value);
            end
        end

        function value = metadataText(~, value)
            if isobject(value)
                value = class(value);
            elseif isstring(value) && isscalar(value)
                value = char(value);
            elseif ~(ischar(value) || isempty(value))
                value = char(string(value));
            end
        end

        function metadata = schemaMetadataFromInfo(obj, info)
            metadata = obj.memberAny(obj.mapInfo(info), ...
                {'schema_metadata', 'schemaMetadata'}, struct());
            if isstruct(metadata) && ~isempty(fieldnames(metadata))
                return
            end
            metadata = struct();
        end

        function compatible = compatibleTopology(~, left, right)
            compatible = isequal(string(left.cyclic_signature), ...
                string(right.cyclic_signature)) && ...
                isequal(string(left.section_relative_signature), ...
                    string(right.section_relative_signature)) && ...
                isequal(left.return_multiplicity, right.return_multiplicity) && ...
                isequal(left.mode, right.mode) && ...
                isempty(right.section_coincident_events);
        end

        function text = modeText(~, mode)
            if isnumeric(mode) || islogical(mode)
                text = mat2str(mode);
            elseif ischar(mode)
                text = mode;
            elseif isstring(mode)
                text = char(mode);
            else
                text = class(mode);
            end
        end

        function obj = applyOptions(obj, options)
            names = fieldnames(options);
            for i = 1:numel(names)
                obj = obj.setOption(names{i}, options.(names{i}));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin), 2) ~= 0
                error('PseudoArclengthContinuation_v3:NameValue', ...
                    'Options must be supplied as name/value pairs.');
            end
            for i = 1:2:numel(varargin)
                obj = obj.setOption(varargin{i}, varargin{i + 1});
            end
        end

        function obj = setOption(obj, name, value)
            list = properties(obj);
            match = find(strcmpi(char(name), list), 1);
            if isempty(match)
                error('PseudoArclengthContinuation_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(list{match}) = value;
        end

        function validateOptions(obj)
            if obj.StepSize == 0 || obj.MinimumStepSize <= 0 || ...
                    obj.MaximumStepSize < obj.MinimumStepSize || ...
                    obj.StepShrink <= 0 || obj.StepShrink >= 1 || ...
                    obj.StepGrowth <= 1 || obj.MaxPoints < 1
                error('PseudoArclengthContinuation_v3:Options', ...
                    'Pseudo-arclength step controls are inconsistent.');
            end
            if numel(obj.ParameterBounds) ~= 2 || ...
                    obj.ParameterBounds(1) > obj.ParameterBounds(2)
                error('PseudoArclengthContinuation_v3:ParameterBounds', ...
                    'ParameterBounds must be [lower upper].');
            end
        end
    end
end
