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
        InitialTangentData = []
        AutoScale = true
        Scale = []
        ParameterBounds = [-Inf, Inf]
        ComputeStability = false
        StabilityAnalyzer = []
        Display = 'off'
        ReuseCorrectorJacobian = true
        MaxWallSeconds = Inf
        CheckpointFunction = []
        StopFunction = []
        TangentRankTolerance = 1e-10
        UsePeriodicSolutionSolver = false
    end

    properties (Access=private)
        RunTimer=[]
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

        function branch = refreshBranchSummary(obj, branch)
            % Rebuild convenience arrays after joining resumed point records.
            % POINTS is authoritative; retain run-specific metadata separately.
            summary=obj.assembleBranch(branch.points,branch.failures, ...
                branch.activeParameterIndex,branch.activeParameter);
            keys=fieldnames(summary);
            for index=1:numel(keys)
                branch.(keys{index})=summary.(keys{index});
            end
        end

        function data=tangentRestartData(obj,point,residual,compatibilityRevision)
            % Bind a retained complete derivative to this exact restart.
            % The caller retains its source artifact and epoch compatibility
            % audit; reuse changes no residual, closure or physical gate.
            if nargin<4,compatibilityRevision=[];end
            info=point.tangentInfo;
            if ~isfield(info,'extendedJacobian')||~isfield(info,'finiteDifference') ...
                    ||~obj.member(info.finiteDifference,'allReliable',false) ...
                    ||~obj.member(info.finiteDifference,'classicalDerivative',false) ...
                    ||any(~isfinite(info.extendedJacobian(:)))
                error('PseudoArclengthContinuation_v3:RestartDerivative','A complete reliable classical derivative is required.');
            end
            z=[point.x(:);point.p(obj.ActiveParameterIndex)];
            context=obj.tangentContext(residual,z,point.p,point.mode);
            if ~isequaln(context.full_state,point.fullState(:))
                error('PseudoArclengthContinuation_v3:RestartGeometry', ...
                    'Restart residual lifts to a different physical state.');
            end
            sameContext=isfield(info,'derivative_context') ...
                &&isequaln(info.derivative_context,context);
            if ~sameContext
                if ~isstruct(compatibilityRevision)||~isscalar(compatibilityRevision) ...
                        ||~all(isfield(compatibilityRevision,{'artifact','artifact_sha256','scope'})) ...
                        ||~isfile(compatibilityRevision.artifact) ...
                        ||~strcmp(obj.sourceDigest(compatibilityRevision.artifact),compatibilityRevision.artifact_sha256)
                    error('PseudoArclengthContinuation_v3:RestartContext', ...
                        ['Derivative context differs or predates context binding. ', ...
                         'An explicit source-bound compatibility audit is required.']);
                end
            end
            data=struct('context',context, ...
                'extendedJacobian',info.extendedJacobian, ...
                'finiteDifference',info.finiteDifference,'source_point_index',point.index, ...
                'compatibility_revision',compatibilityRevision);
        end

        function compatible=tangentRestartCompatible(obj,data,point,residual)
            % Zero-map check of the exact numerical and geometric context.
            z=[point.x(:);point.p(obj.ActiveParameterIndex)];
            compatible=isstruct(data)&&isfield(data,'context') ...
                &&isequaln(data.context,obj.tangentContext(residual,z,point.p,point.mode));
        end

        function branch = run(obj, residual, u0, p0, q0)
            runTimer = tic;
            obj.RunTimer=runTimer;
            pReference = p0(:);
            [index, parameterName] = obj.resolveParameter( ...
                residual, numel(pReference));
            obj.ActiveParameterIndex = index;

            obj.RootSolver.MaxWallSeconds = min(obj.RootSolver.MaxWallSeconds,obj.MaxWallSeconds);
            if obj.UsePeriodicSolutionSolver
                [u, initialSolve] = obj.periodicCorrection(residual,u0(:), ...
                    pReference,q0,obj.RootSolver,[]);
            else
                [u, initialSolve] = obj.RootSolver.solve( ...
                    residual, u0(:), pReference, q0);
            end
            if ~initialSolve.converged
                if obj.UsePeriodicSolutionSolver
                    correction=obj.emptyCorrection();
                    correction.mode=q0;correction.rootInfo=initialSolve;
                    correction.residual=initialSolve.residual;
                    correction.residualNorm=initialSolve.residualNorm;
                    correction.message=initialSolve.message;
                    failure=obj.makeFailurePoint([u0(:);pReference(index)], ...
                        pReference,q0,correction);
                    branch=obj.assembleBranch(repmat(obj.emptyPoint(),1,0), ...
                        failure,index,parameterName);
                    branch.terminationReason='initial correction failed before an accepted branch point';
                    branch.retryable_checkpoint=true;
                    obj.checkpoint(branch);
                    return
                end
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
            if initialPoint.topologyBoundary
                error('PseudoArclengthContinuation_v3:InitialTopologyBoundary', ...
                    ['The initial orbit lies on a section/event or hybrid ', ...
                     'chart boundary. A unique smooth pseudo-arclength ', ...
                     'tangent and Floquet matrix are not defined there; ', ...
                     'start from either adjacent smooth chart.']);
            end
            initialPoint.stability = obj.computePointStability( ...
                residual, initialPoint);
            points = initialPoint;
            failures = repmat(obj.emptyPoint(), 1, 0);
            obj.checkpoint(obj.assembleBranch(points,failures,index,parameterName));
            if obj.MaxPoints==1
                branch=obj.assembleBranch(points,failures,index,parameterName);
                branch.terminationReason='requested initial admission only';
                obj.checkpoint(branch);
                return
            end

            try
                [tScaled, scale, tangentInfo] = obj.computeTangent( ...
                    residual, z, pReference, q, []);
            catch exception
                branch=obj.assembleBranch(points,failures,index,parameterName);
                branch.terminationReason='initial tangent requires a compatible regular chart';
                branch.retryable_checkpoint=true;
                branch.tangent_failure=obj.exceptionRecord(exception);
                obj.checkpoint(branch);
                return
            end
            points(1).tangentInfo=tangentInfo;
            if ~tangentInfo.reliable
                branch=obj.assembleBranch(points,failures,index,parameterName);
                branch.terminationReason='initial tangent unresolved; accepted state retained';
                branch.retryable_checkpoint=true;branch.tangent_failure=tangentInfo.failure;
                obj.checkpoint(branch);return
            end
            points(1).tangent = scale .* tScaled;
            points(1).tangentInfo = tangentInfo;
            previousPhysicalTangent = scale .* tScaled;
            ds = min(max(abs(obj.StepSize), obj.MinimumStepSize), ...
                obj.MaximumStepSize);
            accumulatedLength = 0;
            correctorJacobian = [];

            while numel(points) < obj.MaxPoints
                if toc(runTimer) >= obj.MaxWallSeconds || ...
                        (~isempty(obj.StopFunction) && obj.StopFunction())
                    branch = obj.assembleBranch(points,failures,index,parameterName);
                    branch.terminationReason = 'wall budget or requested stop';
                    obj.checkpoint(branch);
                    return
                end
                accepted = false;
                trialStep = ds;
                failurePoint = obj.emptyPoint();
                while trialStep >= obj.MinimumStepSize
                    if toc(runTimer)>=obj.MaxWallSeconds || ...
                            (~isempty(obj.StopFunction)&&obj.StopFunction())
                        branch=obj.assembleBranch(points,failures,index,parameterName);
                        branch.terminationReason='wall budget or requested stop inside recovery';
                        branch.retryable_checkpoint=true;
                        obj.checkpoint(branch);return
                    end
                    obj.RootSolver.MaxWallSeconds=min(obj.RootSolver.MaxWallSeconds, ...
                        max(.001,obj.MaxWallSeconds-toc(runTimer)));
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
                    try
                        modes = obj.RootSolver.candidateModes( ...
                            residual, zPredict(1:end-1), pPredict, q);
                        if isempty(modes),modes={q};end
                        [corrected, correction] = obj.correctAcrossModes( ...
                            residual, zPredict, z, tScaled, scale, trialStep, ...
                            pReference, modes, correctorJacobian);
                    catch exception
                        corrected=zPredict;
                        correction=obj.emptyCorrection();
                        correction.mode=q;
                        correction.rootInfo=obj.failedRootInfo(exception,q, ...
                            obj.fullState(residual,zPredict(1:end-1),pPredict,q));
                        correction.message=correction.rootInfo.message;
                    end
                    if correction.converged
                        try
                        zNew = corrected(:);
                        uNew = zNew(1:end-1);
                        muNew = zNew(end);
                        pNew = obj.parameterAt(pReference, muNew);
                        qNew = correction.mode;
                        point = obj.makeCorrectedPoint( ...
                            residual, uNew, pNew, qNew, correction);
                        nextLength = accumulatedLength + trialStep;
                        point.index = numel(points) + 1;
                        point.arclength = nextLength;
                        point.continuationCoordinate = muNew;

                        point.event_cluster_transition = ...
                            obj.clusterTransition(points(end), point);
                        point.topologyBoundary = point.topologyBoundary || ...
                            point.section_cluster_coincidence || ...
                            ~obj.compatibleTopology(points(end), point);
                        % Closure/replay has accepted this point already.
                        % Save it before starting the next derivative so a
                        % deadline cannot discard a physically valid orbit.
                        admittedBranch=obj.assembleBranch([points,point],failures,index,parameterName);
                        admittedBranch.terminationReason='accepted point awaiting tangent refresh';
                        obj.checkpoint(admittedBranch);
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
                            try
                                [nextTScaled, nextScale, tangentInfo] = ...
                                    obj.computeTangent(residual, zNew, ...
                                        pReference, qNew, previousPhysicalTangent);
                            catch tangentException
                                % Even a rejected baseline sample belongs to
                                % the NEXT derivative. The accepted orbit
                                % above must remain the restart seam.
                                point.tangent=NaN(size(zNew));
                                point.tangentInfo=struct('reliable',false, ...
                                    'failure',obj.exceptionRecord(tangentException));
                                points(end+1)=point; %#ok<AGROW>
                                branch=obj.assembleBranch(points,failures,index,parameterName);
                                branch.terminationReason='accepted point retained; tangent evaluation failed';
                                branch.retryable_checkpoint=true;
                                branch.tangent_failure=point.tangentInfo.failure;
                                obj.checkpoint(branch);return
                            end
                            if ~tangentInfo.reliable
                                point.tangent=NaN(size(zNew));point.tangentInfo=tangentInfo;
                                points(end+1)=point; %#ok<AGROW>
                                branch=obj.assembleBranch(points,failures,index,parameterName);
                                branch.terminationReason='accepted point retained; tangent refresh unresolved';
                                branch.retryable_checkpoint=true;branch.tangent_failure=tangentInfo.failure;
                                obj.checkpoint(branch);return
                            end
                            point.tangent = nextScale .* nextTScaled;
                            point.tangentInfo = tangentInfo;
                            point.tangentInfo.topologyBoundary = false;
                            point.stability = obj.computePointStability( ...
                                residual, point);
                        end
                        catch exception
                            correction.converged=false;
                            correction.message=sprintf('Post-correction recovery: %s: %s', ...
                                exception.identifier,exception.message);
                            correction.rootInfo.postCorrectionFailure=struct( ...
                                'identifier',exception.identifier,'message',exception.message);
                        end
                        if correction.converged
                        accepted = true;
                        accumulatedLength = nextLength;
                        points(end + 1) = point; %#ok<AGROW>
                        obj.checkpoint(obj.assembleBranch(points,failures,index,parameterName));

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
                    end
                    failurePoint = obj.makeFailurePoint( ...
                        zPredict, pPredict, q, correction);
                    failurePoint.failed_predictor=obj.fullState( ...
                        residual,zPredict(1:end-1),pPredict,q);
                    failurePoint.last_accepted_point=struct( ...
                        'index',points(end).index,'x',points(end).x, ...
                        'fullState',points(end).fullState,'p',points(end).p, ...
                        'mode',points(end).mode,'arclength',points(end).arclength);
                    failurePoint.retry_step=trialStep*obj.StepShrink;
                    failures(end+1)=failurePoint; %#ok<AGROW>
                    obj.checkpoint(obj.assembleBranch(points,failures,index,parameterName));
                    trialStep = trialStep * obj.StepShrink;
                end

                if ~accepted
                    branch = obj.assembleBranch( ...
                        points, failures, index, parameterName);
                    branch.terminationReason = 'corrector failed at minimum step';
                    branch.retryable_checkpoint=true;
                    obj.checkpoint(branch);
                    return
                end
            end
            branch = obj.assembleBranch( ...
                points, failures, index, parameterName);
            branch.terminationReason = 'maximum point count reached';
        end
    end

    methods (Access = private)
        function checkpoint(obj,branch)
            if ~isempty(obj.CheckpointFunction)
                obj.CheckpointFunction(branch);
            end
        end
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
                try
                if obj.UsePeriodicSolutionSolver
                    constraint=struct('reference',zBase,'normal',tScaled./scale,'target',ds);
                    [zCandidate,rootInfo]=obj.periodicCorrection(residual,zPredict, ...
                        pReference,qTrial,solver,constraint);
                else
                    [zCandidate, rootInfo] = solver.solve( ...
                        augmented, zPredict, zeros(0, 1), []);
                end
                catch exception
                    zCandidate=zPredict;
                    rootInfo=obj.failedRootInfo(exception,qTrial, ...
                        obj.fullState(residual,zPredict(1:end-1), ...
                        obj.parameterAt(pReference,zPredict(end)),qTrial));
                end
                score = rootInfo.residualNorm;
                if rootInfo.converged
                    score = score - 1;
                end
                if isempty(fieldnames(resultBest.rootInfo)) || ...
                        (isfinite(score) && score < bestScore)
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

        function [coordinates,rootInfo]=periodicCorrection(obj,family,guess,p,q,solver,constraint)
            if isa(family,'EnergyFamilyResidual_v3') && obj.ActiveParameterIndex==11
                if isempty(constraint)
                    residual=family;seedState=family.fullState(guess);
                else
                    residual=ConstrainedEnergyResidual_v3(family,[],constraint,[]);
                    seedState=family.fullState(guess(1:end-1));
                end
            elseif isobject(family)&&ismethod(family,'continuationResidual') ...
                    &&isprop(family,'PhysicalParameter')&&isprop(family,'Map')
                % Explicit delegated family contract: its residual owns the
                % chart lift and unscaled family/observable equations.
                residual=family.continuationResidual(constraint);
                seedState=residual.fullState(guess,p,q);
            else
                error('PseudoArclengthContinuation_v3:PeriodicService', ...
                    ['Shared correction requires an energy family or an ', ...
                    'explicit continuationResidual contract.']);
            end
            occurrence=1;
            if isa(family.Map.ReturnPolicy,'BLMarkedApexReturnPolicy_v3')
                occurrence=family.Map.ReturnPolicy.BLTouchdownsPerReturn;
            end
            seed=struct('state',seedState,'mode',q,'parameter',family.PhysicalParameter, ...
                'return_policy',family.Map.ReturnPolicy,'occurrence',occurrence, ...
                'provenance',struct('origin','fixed-parameter energy continuation'));
            solverOptions=struct();names=properties(solver);
            for k=1:numel(names),solverOptions.(names{k})=solver.(names{k});end
            options=struct('Residual',residual,'Coordinates',guess, ...
                'AugmentedParameter',p,'SolverOptions',solverOptions, ...
                'MaxWallSeconds',solver.MaxWallSeconds, ...
                'Acceptance',struct('FullClosureTolerance',family.ClosureTolerance));
            [orbit,report]=PeriodicSolutionSolver_v3(seed,options);
            coordinates=guess;rootInfo=report.solver;
            if isempty(fieldnames(rootInfo))
                failure=report.primary_failure;
                rootInfo=obj.failedRootInfo(failure,q,report.final_candidate);
            end
            if isfield(report,'final_coordinates'),coordinates=report.final_coordinates;end
            rootInfo.converged=report.accepted;rootInfo.orbit=orbit;
            rootInfo.fullState=report.final_candidate;
            rootInfo.periodic_solution_report=report;
            rootInfo.periodicAcceptance=struct('accepted',report.accepted, ...
                'full_closure',report.full_closure,'constraint_residual',report.constraint_residual, ...
                'primary_failure',report.primary_failure,'replay_failure',report.replay_failure, ...
                'effective_integration',report.integration,'replay_integration',report.replay_integration);
            if ~report.accepted
                rootInfo.message=[rootInfo.message,'; shared physical acceptance not established'];
            end
        end

        function record=exceptionRecord(~,exception)
            record=struct('identifier',exception.identifier,'message',exception.message);
            if isa(exception,'MException')
                record.stack=exception.stack;
                record.causes=cellfun(@(cause)struct('identifier',cause.identifier, ...
                    'message',cause.message),exception.cause,'UniformOutput',false);
            end
        end

        function info=failedRootInfo(obj,exception,q,state)
            failure=obj.exceptionRecord(exception);
            info=struct('converged',false,'primaryConverged',false, ...
                'mode',q,'residual',[],'residualNorm',Inf,'orbit',[], ...
                'fullState',state,'evaluationInfo',struct(), ...
                'message',[failure.identifier,': ',failure.message], ...
                'primaryErrorIdentifier',failure.identifier, ...
                'primaryMessage',failure.message,'primaryExitflag',-1, ...
                'functionEvaluationCount',0,'mapEvaluationCount',0, ...
                'finalJacobian',[],'failure',failure);
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
            context=obj.tangentContext(residual,z,pReference,q);
            reused=isempty(previousPhysical)&&~isempty(obj.InitialTangentData) ...
                &&isequaln(obj.InitialTangentData.context,context);
            if reused
                A=obj.InitialTangentData.extendedJacobian;
                fdInfo=obj.InitialTangentData.finiteDifference;
            else
                try
                    [A, ~, fdInfo] = obj.Jacobian.compute(functionValue, z);
                catch exception
                    if isempty(obj.RunTimer)||toc(obj.RunTimer)<obj.MaxWallSeconds
                        rethrow(exception)
                    end
                    % No accepted baseline means no derivative matrix can
                    % be claimed. Preserve the original callback failure.
                    tScaled=[];
                    info=struct('extendedJacobian',[], ...
                        'finiteDifference',struct(),'scale',scale,'reliable',false, ...
                        'derivative_context',context,'restart_derivative_reused',false, ...
                        'failure',struct('identifier','PseudoArclengthContinuation_v3:TangentWallBudget', ...
                            'message','Wall budget exhausted before a complete tangent baseline.', ...
                            'original_failure',obj.exceptionRecord(exception)));
                    return
                end
            end
            info=struct('extendedJacobian',A,'finiteDifference',fdInfo, ...
                'scale',scale,'reliable',false,'failure',struct(), ...
                'derivative_context',context,'restart_derivative_reused',reused);
            if isa(obj.Jacobian, 'HybridFiniteDifferenceJacobian_v3') ...
                    && (~obj.member(fdInfo, 'allReliable', false) ...
                    || ~obj.member(fdInfo, 'classicalDerivative', false))
                identifier='PseudoArclengthContinuation_v3:UnreliableTangent';
                if ~isempty(obj.RunTimer)&&toc(obj.RunTimer)>=obj.MaxWallSeconds
                    identifier='PseudoArclengthContinuation_v3:TangentWallBudget';
                end
                info.failure=struct('identifier',identifier,'message', ...
                    'Extended hybrid derivative incomplete; retained columns do not define an accepted tangent.');
                tScaled=[];return
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
            rankTolerance = max(max(size(A)) * eps(max(values)), ...
                obj.TangentRankTolerance * max(values));
            info.extendedJacobian = A;
            info.scaledJacobian = scaledJacobian;
            info.singularValues = values;
            info.rank = sum(values > rankTolerance);
            info.rankTolerance = rankTolerance;
            info.finiteDifference = fdInfo;
            info.scale = scale;
            info.reliable = obj.member(fdInfo, 'allReliable', true);
            if info.rank ~= size(A, 1)
                info.reliable=false;
                info.failure=struct('identifier','PseudoArclengthContinuation_v3:NonuniqueTangent', ...
                    'message',sprintf('Extended residual rank %d for %d rows; unique tangent unresolved.',info.rank,size(A,1)));
                tScaled=[];
            end
        end

        function context=tangentContext(obj,residual,z,p,q)
            % pReference may still contain the preceding active scalar when
            % this derivative is refreshed at a newly accepted z.
            p=obj.parameterAt(p,z(end));
            derivative=struct();
            if isobject(obj.Jacobian)
                names=properties(obj.Jacobian);
                for k=1:numel(names),derivative.(names{k})=obj.Jacobian.(names{k});end
            end
            map=obj.member(residual,'Map',[]);
            policy=obj.member(map,'ReturnPolicy',[]);count=1;
            if isa(policy,'BLMarkedApexReturnPolicy_v3'),count=policy.BLTouchdownsPerReturn;end
            sources={class(residual),class(obj.Jacobian),'PseudoArclengthContinuation_v3', ...
                class(map),'Quadrupedal_Dynamics_v3','ContinuousDynamics_v3', ...
                'GuardFunctions_v3','ResetMap_v3','HybridSimulator_v3','EventDetector_v3',class(policy)};
            fingerprints=cell(size(sources));
            for k=1:numel(sources)
                file=which(sources{k});
                if isempty(file)||~isfile(file),fingerprints{k}='unavailable';continue;end
                fingerprints{k}=obj.sourceDigest(file);
            end
            simulator=obj.member(map,'Simulator',[]);
            context=struct('z',z(:),'parameter',p(:),'mode',q(:), ...
                'active_parameter_index',obj.ActiveParameterIndex,'residual_class',class(residual), ...
                'derivative_class',class(obj.Jacobian),'derivative_options',derivative, ...
                'integration',obj.member(simulator,'Options',struct()), ...
                'full_state',obj.fullState(residual,z(1:end-1),p,q), ...
                'residual_contract',obj.numericalContract(residual,0), ...
                'section_contract',obj.numericalContract(obj.member(map,'Section',[]),0), ...
                'policy_contract',obj.numericalContract(policy,0), ...
                'map_options',struct('MaxReturnTime',obj.member(map,'MaxReturnTime',[]), ...
                    'MaxSectionCrossings',obj.member(map,'MaxSectionCrossings',[]), ...
                    'MaxCycleEvents',obj.member(map,'MaxCycleEvents',[]), ...
                    'ArmTolerance',obj.member(map,'ArmTolerance',[]), ...
                    'InitialTime',obj.member(map,'InitialTime',[])), ...
                'BL_occurrence',count,'source_classes',{sources},'source_sha256',{fingerprints});
        end

        function contract=numericalContract(obj,source,depth)
            % Capture public geometry/equations, excluding map and caches.
            % A custom family can expose a smaller explicit immutable contract.
            contract=struct('type',class(source));
            if isobject(source)&&ismethod(source,'continuationContext')
                contract.values=source.continuationContext();return
            end
            if isstruct(source),names=fieldnames(source);
            elseif isobject(source),names=properties(source);
            else,contract.values=source;return
            end
            omit={'Map','System','Simulator','LastModeResolution'};
            for k=1:numel(names)
                name=names{k};if any(strcmp(name,omit)),continue;end
                value=source.(name);
                if isa(value,'function_handle')
                    value=functions(value);
                elseif isobject(value)
                    if depth>=4
                        error('PseudoArclengthContinuation_v3:ResidualContext', ...
                            'Nested custom geometry requires continuationContext().');
                    end
                    value=obj.numericalContract(value,depth+1);
                end
                contract.(name)=value;
            end
        end

        function value=sourceDigest(~,file)
            stream=fopen(file,'rb');
            if stream<0,error('PseudoArclengthContinuation_v3:SourceContext','Cannot read context source.');end
            close=onCleanup(@()fclose(stream)); %#ok<NASGU>
            digest=java.security.MessageDigest.getInstance('SHA-256');
            while ~feof(stream),digest.update(fread(stream,1048576,'*uint8'));end
            raw=typecast(digest.digest(),'uint8');value=lower(reshape(dec2hex(raw,2).',1,[]));
        end

        function [r, info] = evaluateAtExtendedPoint( ...
                obj, residual, z, pReference, q, varargin)
            z = z(:);
            if ~isempty(obj.RunTimer)&&toc(obj.RunTimer)>=obj.MaxWallSeconds
                error('PseudoArclengthContinuation_v3:TangentWallBudget', ...
                    'Continuation wall budget exhausted before another tangent map sample.');
            end
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
            obj.assertPhysicalClosure(solveInfo.evaluationInfo);
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
            point.fullState=obj.member(correction.rootInfo,'fullState',[]);
            point.failure=obj.member(correction.rootInfo,'failure', ...
                obj.member(correction.rootInfo,'periodicAcceptance',struct()));
            [baseResidual, evalInfo] = obj.evaluateResidual(residual, u, p, q);
            obj.assertPhysicalClosure(evalInfo);
            point.residual = baseResidual;
            point.residualNorm = norm(baseResidual, Inf);
            point.fullState = obj.fullState(residual, u, p, q);
            if obj.UsePeriodicSolutionSolver
                point.orbit=correction.rootInfo.orbit;
                if isempty(point.orbit)
                    error('PseudoArclengthContinuation_v3:UnacceptedOrbit', ...
                        'The shared periodic corrector supplied no independently accepted orbit.');
                end
            else
                point.orbit = obj.createOrbit(residual, u, p, q, evalInfo);
            end
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
            point.event_cluster_report = obj.memberAnySource(sources, ...
                {'event_cluster_report', 'eventClusterReport'}, struct());
            point.event_clusters = obj.memberAnySource(sources, ...
                {'event_clusters', 'eventClusters'}, struct([]));
            point.event_cluster_count = obj.memberAnySource(sources, ...
                {'event_cluster_count', 'eventClusterCount'}, ...
                numel(point.event_clusters));
            point.event_cluster_signature = obj.memberAnySource(sources, ...
                {'event_cluster_signature', 'eventClusterSignature'}, '');
            point.minimum_intercluster_gap = obj.memberAnySource(sources, ...
                {'minimum_intercluster_gap', 'minimumInterclusterGap'}, Inf);
            point.maximum_intra_cluster_spread = obj.memberAnySource( ...
                sources, {'maximum_intra_cluster_spread', ...
                'maximumIntraClusterSpread'}, 0);
            point.cluster_relative_phase = obj.memberAnySource(sources, ...
                {'cluster_relative_phase', 'clusterRelativePhase'}, []);
            point.section_cluster_coincidence = logical( ...
                obj.memberAnySource(sources, ...
                    {'section_cluster_coincidence', ...
                     'sectionClusterCoincidence'}, false));
            point.event_cluster_split_merge_diagnostics = ...
                obj.memberAnySource(sources, ...
                    {'event_cluster_split_merge_diagnostics', ...
                     'eventClusterSplitMergeDiagnostics'}, struct());
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
            point.minimum_physical_margin = obj.memberAnySource( ...
                sources, {'minimum_physical_margin', ...
                'minimumPhysicalMargin'}, Inf);
            point.minimum_physical_margins = obj.memberAnySource( ...
                sources, {'minimum_physical_margins', ...
                'minimumPhysicalMargins'}, struct());
            point.section_coincident_events = obj.memberAnySource(sources, ...
                {'section_coincident_events', ...
                 'sectionCoincidentEvents'}, struct([]));
            point.topologyBoundary = logical(obj.memberAnySource(sources, ...
                {'hybrid_chart_boundary', 'hybridChartBoundary', ...
                 'topology_boundary', 'topologyBoundary'}, false)) || ...
                point.section_cluster_coincidence || ...
                ~isempty(point.section_coincident_events);
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

        function assertPhysicalClosure(~, info)
            if isstruct(info) && isfield(info, 'full_physical_closure_norm') ...
                    && isfield(info, 'full_physical_closure_tolerance') ...
                    && info.full_physical_closure_norm > info.full_physical_closure_tolerance
                error('PseudoArclengthContinuation_v3:FullPhysicalClosure', ...
                    'Independent equations converged but full physical closure failed: %.4g.', ...
                    info.full_physical_closure_norm);
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
            branch.event_cluster_report = {points.event_cluster_report};
            branch.event_clusters = {points.event_clusters};
            branch.event_cluster_count = [points.event_cluster_count];
            branch.event_cluster_signature = ...
                {points.event_cluster_signature};
            branch.minimum_intercluster_gap = ...
                [points.minimum_intercluster_gap];
            branch.maximum_intra_cluster_spread = ...
                [points.maximum_intra_cluster_spread];
            branch.cluster_relative_phase = ...
                {points.cluster_relative_phase};
            branch.section_cluster_coincidence = ...
                [points.section_cluster_coincidence];
            branch.event_cluster_transition = ...
                {points.event_cluster_transition};
            branch.event_cluster_split_merge_diagnostics = ...
                {points.event_cluster_split_merge_diagnostics};
            branch.event_counts = {points.event_counts};
            branch.guard_transversality = {points.guard_transversality};
            branch.topology_margins = {points.topology_margins};
            branch.stance_force_admissibility_margin = ...
                [points.stance_force_admissibility_margin];
            branch.minimum_physical_margin = ...
                [points.minimum_physical_margin];
            branch.minimum_physical_margins = ...
                {points.minimum_physical_margins};
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
                'event_cluster_report', struct(), ...
                'event_clusters', struct([]), 'event_cluster_count', 0, ...
                'event_cluster_signature', '', ...
                'minimum_intercluster_gap', Inf, ...
                'maximum_intra_cluster_spread', 0, ...
                'cluster_relative_phase', [], ...
                'section_cluster_coincidence', false, ...
                'event_cluster_transition', struct(), ...
                'event_cluster_split_merge_diagnostics', struct(), ...
                'event_counts', [], 'guard_transversality', [], ...
                'topology_margins', struct(), 'root_statistics', struct(), ...
                'stance_force_admissibility_margin', Inf, ...
                'minimum_physical_margin', Inf, ...
                'minimum_physical_margins', struct(), ...
                'section_coincident_events', {struct([])}, ...
                'schema_metadata', struct(), 'topologyBoundary', false, ...
                'failed_predictor',[],'last_accepted_point',struct(), ...
                'retry_step',NaN,'failure',struct());
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
                isempty(right.section_coincident_events) && ...
                ~right.section_cluster_coincidence;
            if compatible && ~isempty(fieldnames( ...
                    right.event_cluster_transition))
                compatible = right.event_cluster_transition.compatible;
            end
        end

        function diagnostics = clusterTransition(~, left, right)
            diagnostics = struct();
            if isempty(fieldnames(left.event_cluster_report)) || ...
                    isempty(fieldnames(right.event_cluster_report))
                return
            end
            diagnostics = EventCluster_v3().compare( ...
                left.event_cluster_report, right.event_cluster_report);
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
