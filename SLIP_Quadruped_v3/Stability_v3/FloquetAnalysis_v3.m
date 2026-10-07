classdef FloquetAnalysis_v3
    %FLOQUETANALYSIS_V3 Finite-difference hybrid Poincare stability.
    %   The differentiated object is the complete event-driven return map,
    %   including guard-time changes and reset maps.  Perturbations are made
    %   only in a section-tangent, symmetry-reduced coordinate set.

    properties
        TangentIndices = []
        TangentBasis = []
        Differencing = 'hybrid'
        RelativeStep = []
        Jacobian = []
        StabilityTolerance = 1e-6
        RequireDiscreteClosure = true
        RequireCycleCompletion = true
        RequireMatchingEventSignature = true
        RequireCompatibleSectionSignature = true
        RequireCompatibleClusterSignature = true
        ThrowOnTopologyChange = false
        ProjectionFunction = []
        ComputeAmbientJacobian = false
        MinimumGuardTransversality = 1e-7
        MinimumSectionTransversality = 1e-8
        MaximumSubspaceLeakage = 1e-6
    end

    methods
        function obj = FloquetAnalysis_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            if ~any(strcmpi(obj.Differencing, ...
                    {'hybrid', 'forward', 'central'}))
                error('FloquetAnalysis_v3:Differencing', ...
                    'Differencing must be hybrid, forward, or central.');
            end
        end

        function result = analyze(obj, map, x, q, p, options)
            if nargin < 6
                options = struct();
            end
            local = obj;
            if ~isempty(options)
                local = local.applyOptions(options);
            end
            x = x(:);
            p = p(:);
            xTemplate = local.projectState(map, x, p);
            physicalChart = [];
            system = local.member(map, 'System', []);
            if isa(system, 'Quadrupedal_Dynamics_v3')
                physicalChart = QuadrupedPhysicalChart_v3.create(xTemplate,q,p);
                previousProjection = local.ProjectionFunction;
                local.ProjectionFunction = @physicalProjection;
                if isempty(local.TangentBasis) && isempty(local.TangentIndices)
                    local.TangentIndices = physicalChart.independent_indices;
                end
                if any(ismember(local.TangentIndices,physicalChart.dependent_indices))
                    error('FloquetAnalysis_v3:DependentStanceCoordinate', ...
                        'Stance rates are dependent coordinates; use the physical chart.');
                end
                if any(~ismember(local.TangentIndices,physicalChart.independent_indices))
                    error('FloquetAnalysis_v3:NonphysicalTangentIndices', ...
                        'Tangent indices must be independent coordinates of the physical section chart.');
                end
            end
            [indices, tangentBasis, basisLeftInverse] = ...
                local.resolveTangentChart(map, numel(xTemplate));
            physicalBasis = [];
            if ~isempty(physicalChart)
                [physicalBasis,~] = QuadrupedPhysicalChart_v3.tangentBasis(physicalChart);
                if ~isempty(tangentBasis)
                    independentBasis = tangentBasis(physicalChart.independent_indices,:);
                    physicalLift = physicalBasis * independentBasis;
                    if norm(tangentBasis-physicalLift,inf) ...
                            > 1e-7 * max(1,norm(tangentBasis,inf))
                        error('FloquetAnalysis_v3:NonphysicalTangentBasis', ...
                            'The supplied basis leaves the physical mode/section tangent space.');
                    end
                    % Extract physical free coordinates before symmetry
                    % restriction: nonlinear manifold curvature is not
                    % leakage into a forbidden symmetry sector.
                    extraction = eye(numel(xTemplate));
                    extraction = extraction(physicalChart.independent_indices,:);
                    basisLeftInverse = (independentBasis.'*independentBasis) ...
                        \ independentBasis.' * extraction;
                end
            end
            if isempty(tangentBasis)
                eta0 = xTemplate(indices);
            else
                eta0 = zeros(size(tangentBasis, 2), 1);
            end

            evaluations = repmat(struct( ...
                'coordinates', [], 'state', [], 'nextState', [], ...
                'mapInfo', struct(), 'eventSignature', '', ...
                'discreteClosed', true, 'subspaceLeakage', 0), 1, 0);
            baseReturnedState = [];
            ambientEvaluations = repmat(struct( ...
                'state', [], 'projectedState', [], 'nextState', [], ...
                'mapInfo', struct(), 'eventSignature', '', ...
                'discreteClosed', true), 1, 0);

            if isempty(local.Jacobian)
                if strcmpi(local.Differencing, 'hybrid')
                    arguments = { ...
                        'RequireDiscreteClosure', local.RequireDiscreteClosure, ...
                        'RequireCycleCompletion', local.RequireCycleCompletion, ...
                        'RequireCompatibleCyclicSignature', ...
                            local.RequireMatchingEventSignature, ...
                        'RequireCompatibleSectionSignature', ...
                            local.RequireCompatibleSectionSignature, ...
                        'RequireCompatibleClusterSignature', ...
                            local.RequireCompatibleClusterSignature, ...
                        'MinimumGuardTransversality', ...
                            local.MinimumGuardTransversality, ...
                        'MinimumSectionTransversality', ...
                            local.MinimumSectionTransversality, ...
                        'FailurePolicy', 'nan'};
                    if ~isempty(local.RelativeStep)
                        arguments = [arguments, {'RelativeCandidateSteps', ...
                            local.RelativeStep .* [1, 0.5, 0.25]}];
                    end
                    fd = HybridFiniteDifferenceJacobian_v3(arguments{:});
                else
                    arguments = {'Method', local.Differencing, ...
                        'FailurePolicy', 'nan'};
                    if ~isempty(local.RelativeStep)
                        arguments = [arguments, ...
                            {'RelativeStep', local.RelativeStep}];
                    end
                    fd = FiniteDifferenceJacobian_v3(arguments{:});
                end
            else
                fd = local.Jacobian;
            end
            hybridDifferencing = isa(fd, ...
                'HybridFiniteDifferenceJacobian_v3');
            [DP, etaNext, fdInfo] = fd.compute(@reducedReturn, eta0);
            chartDimension = numel(eta0);
            if size(DP, 1) ~= chartDimension || ...
                    size(DP, 2) ~= chartDimension
                error('FloquetAnalysis_v3:MapDimension', ...
                    ['The reduced return map must preserve chart dimension; ' ...
                     'received a %d-by-%d derivative.'], ...
                    size(DP, 1), size(DP, 2));
            end

            ambientDP = [];
            ambientNext = [];
            ambientFdInfo = struct();
            if local.ComputeAmbientJacobian
                [ambientDP, ambientNext, ambientFdInfo] = ...
                    fd.compute(@ambientReturn, xTemplate);
            end

            if any(~isfinite(DP(:)))
                eigenvectors = NaN(size(DP));
                multipliers = NaN(size(DP, 1), 1);
                spectralRadius = NaN;
                margin = NaN;
                stability = 'unresolved';
            else
                [eigenvectors, diagonal] = eig(DP);
                multipliers = diag(diagonal);
                spectralRadius = max(abs(multipliers));
                if isempty(spectralRadius)
                    spectralRadius = 0;
                end
                margin = 1 - spectralRadius;
                if margin > local.StabilityTolerance
                    stability = 'stable';
                elseif margin < -local.StabilityTolerance
                    stability = 'unstable';
                else
                    stability = 'marginal';
                end
            end

            signatures = {evaluations.eventSignature};
            adjacentSectionSignatures = {};
            if isempty(signatures)
                baseSignature = '';
                baseSectionSignature = '';
                matchingSignatures = true;
                matchingSectionSignatures = true;
                baseInfo = struct();
            else
                baseSignature = signatures{1};
                baseInfo = evaluations(1).mapInfo;
                baseSectionSignature = local.sectionSignature(baseInfo);
                adjacentSectionSignatures = {baseSectionSignature};
                if hybridDifferencing
                    % Only the selected h/h2 plateau defines DP. Exploratory
                    % larger steps may cross topology and be rejected by the
                    % hybrid differentiator; they must not invalidate a
                    % smaller compatible selected plateau.
                    matchingSignatures = true;
                    matchingSectionSignatures = true;
                    columns = local.member(fdInfo, 'columns', struct([]));
                    for columnIndex = 1:numel(columns)
                        candidates = columns(columnIndex).candidates;
                        selectedIndex = columns(columnIndex).selectedCandidate;
                        if isempty(candidates) || ~isfinite(selectedIndex) || ...
                                selectedIndex < 1 || ...
                                selectedIndex > numel(candidates)
                            matchingSignatures = false;
                            matchingSectionSignatures = false;
                            break
                        end
                        selected = candidates(selectedIndex);
                        selectedSignatures = selected.eventSignatures;
                        selectedSignatures = selectedSignatures( ...
                            ~cellfun(@isempty, selectedSignatures));
                        if ~isempty(baseSignature) && ...
                                any(~strcmp(baseSignature, selectedSignatures))
                            matchingSignatures = false;
                        end
                        selectedSectionSignatures = selected.sectionSignatures;
                        selectedSectionSignatures = selectedSectionSignatures( ...
                            ~cellfun(@isempty, selectedSectionSignatures));
                        adjacentSectionSignatures = [ ...
                            adjacentSectionSignatures, ...
                            selectedSectionSignatures]; %#ok<AGROW>
                        if ~isempty(baseSectionSignature) && ...
                                any(~strcmp(baseSectionSignature, ...
                                    selectedSectionSignatures))
                            matchingSectionSignatures = false;
                        end
                    end
                else
                    matchingSignatures = ...
                        all(strcmp(baseSignature, signatures));
                    sectionSignatures = arrayfun( ...
                        @(entry) local.sectionSignature(entry.mapInfo), ...
                        evaluations, 'UniformOutput', false);
                    adjacentSectionSignatures = sectionSignatures;
                    matchingSectionSignatures = isempty(sectionSignatures) || ...
                        all(strcmp(baseSectionSignature, sectionSignatures));
                end
            end
            adjacentSectionSignatures = adjacentSectionSignatures( ...
                ~cellfun(@isempty, adjacentSectionSignatures));
            adjacentSectionSignatures = unique( ...
                adjacentSectionSignatures, 'stable');
            if hybridDifferencing
                baseMetadata = local.member( ...
                    fdInfo, 'baseMetadata', struct());
                matchingClosure = local.member( ...
                    baseMetadata, 'discrete_closed', true);
                matchingMultiplicity = local.member( ...
                    fdInfo, 'returnMultiplicityPreserved', false);
                matchingCycleCompletion = ...
                    local.cycleComplete(baseMetadata);
            else
                closure = [evaluations.discreteClosed];
                matchingClosure = isempty(closure) || all(closure);
                multiplicities = arrayfun(@(entry) local.member( ...
                    entry.mapInfo, 'return_multiplicity', 1), evaluations);
                matchingMultiplicity = isempty(multiplicities) || ...
                    all(multiplicities == multiplicities(1));
                cycleComplete = arrayfun(@(entry) local.cycleComplete( ...
                    entry.mapInfo), evaluations);
                matchingCycleCompletion = isempty(cycleComplete) || ...
                    all(cycleComplete);
            end
            fdReliable = local.member(fdInfo, 'allReliable', true);
            classicalDerivative = local.member( ...
                fdInfo, 'classicalDerivative', true);
            baseTransversality = local.transversalityMargins(baseInfo);
            transverse = baseTransversality.guard >= ...
                local.MinimumGuardTransversality && ...
                baseTransversality.section >= ...
                local.MinimumSectionTransversality;
            coincidentEvents = local.member( ...
                baseInfo, 'section_coincident_events', []);
            if isempty(coincidentEvents)
                coincidentEvents = local.member( ...
                    baseInfo, 'sectionCoincidentEvents', []);
            end
            topologyMargins = local.member( ...
                baseInfo, 'topology_margins', struct());
            coincidenceCount = local.member(topologyMargins, ...
                'section_event_coincidence_count', 0);
            hasSectionEventCoincidence = ~isempty(coincidentEvents) || ...
                (isscalar(coincidenceCount) && isfinite(coincidenceCount) ...
                    && coincidenceCount > 0);
            selectedSubspaceLeakage = local.selectedStencilLeakage( ...
                evaluations, eta0, fdInfo, tangentBasis);
            subspaceInvariant = selectedSubspaceLeakage <= ...
                local.MaximumSubspaceLeakage;
            reliable = matchingClosure && matchingSignatures && ...
                (~local.RequireCompatibleSectionSignature || ...
                    matchingSectionSignatures) && ...
                matchingMultiplicity && matchingCycleCompletion && ...
                fdReliable && classicalDerivative && transverse && ...
                ~hasSectionEventCoincidence && subspaceInvariant && ...
                all(isfinite(DP(:)));
            if local.ThrowOnTopologyChange && ...
                    ((local.RequireMatchingEventSignature && ...
                        ~matchingSignatures) || ...
                     (local.RequireCompatibleSectionSignature && ...
                        ~matchingSectionSignatures))
                error('FloquetAnalysis_v3:EventSignatureChanged', ...
                    ['Finite-difference trials changed the cyclic or ', ...
                     'section-relative topology; a single smooth Floquet ', ...
                     'matrix is not valid at this perturbation scale.']);
            end

            result = struct();
            result.poincareMatrix = DP;
            result.floquetMatrix = DP;
            result.jacobian = DP;
            result.multipliers = multipliers;
            result.eigenvectors = eigenvectors;
            if isempty(tangentBasis)
                if ~isempty(physicalChart)
                    [~,columns] = ismember(indices,physicalChart.independent_indices);
                    result.ambientEigenvectors = physicalBasis(:,columns)*eigenvectors;
                else
                    result.ambientEigenvectors = local.liftEigenvectors( ...
                        eigenvectors, indices, numel(xTemplate));
                end
            else
                result.ambientEigenvectors = tangentBasis * eigenvectors;
            end
            result.ambientJacobian = ambientDP;
            result.ambientPoincareMatrix = ambientDP;
            result.ambientReturnState = ambientNext;
            result.ambientPerturbations = ambientEvaluations;
            result.ambientFiniteDifference = ambientFdInfo;
            result.spectralRadius = spectralRadius;
            result.stabilityMargin = margin;
            result.stability_margin = margin;
            result.stability = stability;
            result.stable = strcmp(stability, 'stable');
            result.reliable = reliable;
            result.eventSignaturesMatch = matchingSignatures;
            result.sectionSignaturesMatch = matchingSectionSignatures;
            result.discreteClosurePreserved = matchingClosure;
            result.eventSignature = baseSignature;
            result.cycleSignature = baseSignature;
            result.sectionRelativeSignature = baseSectionSignature;
            result.section_relative_signature = baseSectionSignature;
            result.eventClusterSignature = local.member(baseInfo, ...
                'event_cluster_signature', '');
            result.event_cluster_signature = result.eventClusterSignature;
            result.adjacentSectionSignatures = adjacentSectionSignatures;
            result.adjacent_section_signatures = adjacentSectionSignatures;
            result.hybridChartBoundary = hasSectionEventCoincidence || ...
                ~matchingSectionSignatures;
            result.returnMultiplicity = local.member( ...
                baseInfo, 'return_multiplicity', 1);
            result.return_multiplicity = result.returnMultiplicity;
            result.cycleCompletionPreserved = matchingCycleCompletion;
            result.returnMultiplicityPreserved = matchingMultiplicity;
            result.forwardOneSidedPoincareMatrix = local.member( ...
                fdInfo, 'forwardOneSidedJacobian', []);
            result.backwardOneSidedPoincareMatrix = local.member( ...
                fdInfo, 'backwardOneSidedJacobian', []);
            result.forwardOneSidedAvailable = local.member( ...
                fdInfo, 'forwardOneSidedAvailable', false);
            result.backwardOneSidedAvailable = local.member( ...
                fdInfo, 'backwardOneSidedAvailable', false);
            result.transversalityMargins = baseTransversality;
            result.sectionEventCoincidence = hasSectionEventCoincidence;
            result.sectionCoincidentEvents = coincidentEvents;
            result.tangentIndices = indices;
            result.tangentBasis = tangentBasis;
            result.symmetryRestricted = ~isempty(tangentBasis);
            result.physicalChart = physicalChart;
            result.physicalCoordinateDimension = chartDimension;
            result.physicalTangentBasis = [];
            if ~isempty(physicalChart)
                result.symmetryRestricted = ~isempty(tangentBasis) ...
                    && size(tangentBasis,2) < physicalChart.dimension;
                if isempty(tangentBasis)
                    [~,columns] = ismember(indices,physicalChart.independent_indices);
                    result.physicalTangentBasis = physicalBasis(:,columns);
                else
                    result.physicalTangentBasis = tangentBasis;
                end
            end
            result.removedPhysicalDirections = struct( ...
                'phase_section', [], 'translation_gauge', [], ...
                'dependent_stance_rates', []);
            result.energyNeutrality = struct('applicable', false);
            if ~isempty(physicalChart)
                schema = system.Schema;
                result.removedPhysicalDirections.phase_section = schema.State.dy;
                result.removedPhysicalDirections.translation_gauge = schema.State.x;
                result.removedPhysicalDirections.dependent_stance_rates = ...
                    physicalChart.dependent_indices;
                [~, energyReport] = QuadrupedEnergy_v3.evaluate(xTemplate,q,p);
                if isempty(tangentBasis)
                    [~,columns] = ismember(indices,physicalChart.independent_indices);
                    coordinateEnergyGradient = energyReport.gradient.'*physicalBasis(:,columns);
                else
                    coordinateEnergyGradient = energyReport.gradient.'*tangentBasis;
                end
                result.energyNeutrality = struct( ...
                    'applicable', energyReport.conservation_applicable, ...
                    'coordinate_gradient', coordinateEnergyGradient, ...
                    'left_unit_residual', norm(coordinateEnergyGradient*DP ...
                        - coordinateEnergyGradient,inf), ...
                    'note', 'At a fixed point, DE*DP=DE is structural when energy is conserved; no multiplier is deleted.');
            end
            result.baseState = xTemplate;
            result.baseCoordinates = eta0;
            result.returnCoordinates = etaNext;
            result.baseMapInfo = baseInfo;
            result.perturbations = evaluations;
            result.finiteDifference = fdInfo;
            result.differencing = local.Differencing;
            result.finiteDifferenceStepReport = local.member( ...
                fdInfo, 'columns', struct([]));
            result.perColumnReliability = local.member( ...
                fdInfo, 'perColumnReliability', true(size(DP, 2), 1));
            result.selectedSubspaceLeakage = selectedSubspaceLeakage;
            result.subspaceInvariant = subspaceInvariant;
            if hasSectionEventCoincidence
                result.warning = ['The base return has a section/event ', ...
                    'coincidence; a unique smooth Floquet matrix is ', ...
                    'unresolved at this hybrid boundary.'];
            elseif local.RequireCompatibleSectionSignature && ...
                    ~matchingSectionSignatures
                result.warning = ['Finite-difference trials entered ', ...
                    'different section-relative event charts; one-sided ', ...
                    'limits are diagnostic but no unique classical ', ...
                    'Floquet matrix is defined.'];
            elseif ~fdReliable || ~classicalDerivative
                result.warning = ['Finite-difference columns did not define ', ...
                    'a converged unique classical hybrid derivative.'];
            elseif ~matchingSignatures
                result.warning = ['Finite-difference trials changed event ' ...
                    'signature; the map is piecewise smooth at this scale.'];
            elseif ~matchingClosure
                result.warning = ['A finite-difference trial did not return ' ...
                    'to the initial discrete mode.'];
            elseif ~matchingMultiplicity
                result.warning = ['Finite-difference trials changed the ', ...
                    'accepted return multiplicity; no single cycle-return ', ...
                    'derivative is defined by this stencil.'];
            elseif ~subspaceInvariant
                result.warning = ['The selected return-map stencil leaks ', ...
                    'outside the supplied symmetry/tangent subspace; ', ...
                    'block multipliers are not invariantly defined.'];
            else
                result.warning = '';
            end

            function state = physicalProjection(state,parameter)
                if isempty(previousProjection)
                    state = map.Section.project(state,parameter);
                else
                    state = previousProjection(state,parameter);
                end
                state = QuadrupedPhysicalChart_v3.retract(state,q,parameter);
            end

            function [coordinatesNext, metadata] = reducedReturn(coordinates, varargin)
                if isempty(tangentBasis)
                    trial = xTemplate;
                    trial(indices) = coordinates(:);
                else
                    trial = xTemplate + tangentBasis * coordinates(:);
                end
                trial = local.projectState(map, trial, p);
                [nextState, mapInfo] = local.evaluateMap( ...
                    map, trial, q, p, varargin{:});
                nextState = nextState(:);
                if numel(nextState) ~= numel(trial) || ...
                        any(~isfinite(nextState))
                    error('FloquetAnalysis_v3:InvalidReturnState', ...
                        'The Poincare map returned an invalid state.');
                end
                discreteClosed = local.discreteClosed(mapInfo, q);
                if ~hybridDifferencing && local.RequireDiscreteClosure && ...
                        ~discreteClosed
                    % Keep the value for diagnostics, then reject the map.
                    error('FloquetAnalysis_v3:DiscreteClosure', ...
                        'A perturbed return did not close in the discrete mode.');
                end
                if isempty(tangentBasis)
                    coordinatesNext = nextState(indices);
                    subspaceLeakage = 0;
                else
                    coordinatesNext = basisLeftInverse * ...
                        (nextState - xTemplate);
                    if isempty(baseReturnedState)
                        baseReturnedState = nextState;
                        subspaceLeakage = 0;
                    else
                        returnedPerturbation = ...
                            nextState - baseReturnedState;
                        transversePerturbation = returnedPerturbation ...
                            - tangentBasis * (basisLeftInverse ...
                                * returnedPerturbation);
                        if ~isempty(physicalChart)
                            returnedPerturbation = returnedPerturbation( ...
                                physicalChart.independent_indices);
                            transversePerturbation = transversePerturbation( ...
                                physicalChart.independent_indices);
                        end
                        subspaceLeakage = norm( ...
                            transversePerturbation, 2) / max( ...
                                norm(returnedPerturbation, 2), sqrt(eps));
                    end
                end
                mapInfo.subspace_leakage = subspaceLeakage;
                record = struct();
                record.coordinates = coordinates(:);
                record.state = trial;
                record.nextState = nextState;
                record.mapInfo = mapInfo;
                record.eventSignature = local.eventSignature(mapInfo);
                record.discreteClosed = discreteClosed;
                record.subspaceLeakage = subspaceLeakage;
                evaluations(end + 1) = record;
                metadata = local.hybridMetadata(mapInfo, discreteClosed);
            end

            function [nextState, metadata] = ambientReturn(state, varargin)
                state = state(:);
                projected = local.projectState(map, state, p);
                [nextState, mapInfo] = local.evaluateMap( ...
                    map, projected, q, p, varargin{:});
                nextState = nextState(:);
                if numel(nextState) ~= numel(projected) || ...
                        any(~isfinite(nextState))
                    error('FloquetAnalysis_v3:InvalidAmbientReturnState', ...
                        'The ambient Poincare map returned an invalid state.');
                end
                discreteClosed = local.discreteClosed(mapInfo, q);
                if ~hybridDifferencing && local.RequireDiscreteClosure && ...
                        ~discreteClosed
                    error('FloquetAnalysis_v3:AmbientDiscreteClosure', ...
                        ['An ambient finite-difference trial did not return ', ...
                         'to the initial discrete mode.']);
                end
                record = struct();
                record.state = state;
                record.projectedState = projected;
                record.nextState = nextState;
                record.mapInfo = mapInfo;
                record.eventSignature = local.eventSignature(mapInfo);
                record.discreteClosed = discreteClosed;
                ambientEvaluations(end + 1) = record;
                metadata = local.hybridMetadata(mapInfo, discreteClosed);
            end
        end

        function result = analyzeResidual(obj, residual, u, p, q, options)
            if nargin < 6
                options = struct();
            end
            if ~(isobject(residual) && isprop(residual, 'Map')) && ...
                    ~(isstruct(residual) && isfield(residual, 'Map'))
                error('FloquetAnalysis_v3:ResidualInterface', ...
                    'The residual must expose its Poincare Map.');
            end
            map = residual.Map;
            if isobject(residual) && ismethod(residual, 'fullState')
                x = residual.fullState(u);
            elseif isstruct(residual) && isfield(residual, 'fullState')
                x = residual.fullState(u);
            else
                x = u(:);
            end
            if ~isfield(options,'TangentIndices') && ~isfield(options,'TangentBasis') ...
                    && isempty(obj.TangentIndices) && isempty(obj.TangentBasis)
                if isobject(residual) && isprop(residual, 'TangentIndices')
                    requestedIndices = residual.TangentIndices;
                elseif isstruct(residual) && isfield(residual, 'TangentIndices')
                    requestedIndices = residual.TangentIndices;
                else
                    requestedIndices = [];
                end
                system = obj.member(map,'System',[]);
                if isa(system,'Quadrupedal_Dynamics_v3') ...
                        && isequal(requestedIndices,system.DefaultTangentIndices)
                    % A legacy ambient default is not an explicit physical
                    % grounded chart; analyze() selects the mode manifold.
                    requestedIndices = [];
                end
                options.TangentIndices = requestedIndices;
            end
            result = obj.analyze(map, x, q, p, options);
        end

        function [multipliers, eigenvectors, margin, result] = ...
                compute(obj, varargin)
            result = obj.analyze(varargin{:});
            multipliers = result.multipliers;
            eigenvectors = result.eigenvectors;
            margin = result.stabilityMargin;
        end

        function result = analyzeOrbit(obj, map, orbit, options)
            if nargin < 4
                options = struct();
            end
            result = obj.analyze(map, orbit.initial_state, ...
                orbit.initial_mode, orbit.parameter, options);
            if isobject(orbit) && ismethod(orbit, 'setFloquetResult')
                orbit.setFloquetResult(result);
            end
        end
    end

    methods (Access = private)
        function leakage = selectedStencilLeakage(obj, evaluations, ...
                baseCoordinates, fdInfo, tangentBasis)
            if isempty(tangentBasis)
                leakage = 0;
                return
            end
            if isempty(evaluations)
                leakage = Inf;
                return
            end
            columns = obj.member(fdInfo, 'columns', struct([]));
            if isempty(columns)
                leakage = max([evaluations.subspaceLeakage]);
                return
            end
            leakage = 0;
            for columnIndex = 1:numel(columns)
                step = columns(columnIndex).selectedStep;
                if ~(isscalar(step) && isfinite(step) && step > 0)
                    leakage = Inf;
                    return
                end
                direction = zeros(numel(baseCoordinates), 1);
                direction(columnIndex) = 1;
                targets = [ ...
                    baseCoordinates + step .* direction, ...
                    baseCoordinates - step .* direction, ...
                    baseCoordinates + 0.5 .* step .* direction, ...
                    baseCoordinates - 0.5 .* step .* direction];
                for targetIndex = 1:size(targets, 2)
                    distances = arrayfun(@(entry) norm( ...
                        entry.coordinates(:) - ...
                            targets(:, targetIndex), Inf), evaluations);
                    [distance, match] = min(distances);
                    tolerance = 128 * eps(max(1, ...
                        norm(targets(:, targetIndex), Inf)));
                    if isempty(match) || distance > tolerance
                        leakage = Inf;
                        return
                    end
                    leakage = max(leakage, ...
                        evaluations(match).subspaceLeakage);
                end
            end
        end

        function state = projectState(obj, map, state, p)
            state = state(:);
            if ~isempty(obj.ProjectionFunction)
                state = obj.ProjectionFunction(state, p);
                state = state(:);
                return
            end
            section = obj.member(map, 'Section', []);
            if ~isempty(section)
                if isobject(section) && ismethod(section, 'project')
                    state = section.project(state, p);
                elseif isstruct(section) && isfield(section, 'project')
                    state = section.project(state, p);
                end
            end
            state = state(:);
        end

        function indices = resolveTangentIndices(obj, map, n)
            indices = obj.TangentIndices;
            if isempty(indices)
                system = obj.member(map, 'System', []);
                indices = obj.member(system, 'DefaultTangentIndices', []);
            end
            if isempty(indices)
                warning('FloquetAnalysis_v3:AmbientCoordinates', ...
                    ['No reduced tangent indices were supplied. The full ' ...
                     'ambient derivative can contain phase or symmetry modes.']);
                indices = 1:n;
            end
            indices = indices(:).';
            if any(indices < 1) || any(indices > n) || ...
                    numel(unique(indices)) ~= numel(indices)
                error('FloquetAnalysis_v3:TangentIndices', ...
                    'TangentIndices must be unique valid state indices.');
            end
        end

        function [indices, basis, leftInverse] = ...
                resolveTangentChart(obj, map, n)
            basis = obj.TangentBasis;
            leftInverse = [];
            if isempty(basis)
                indices = obj.resolveTangentIndices(map, n);
                return
            end
            if ~(isnumeric(basis) && isreal(basis) && ...
                    size(basis, 1) == n && size(basis, 2) >= 1 && ...
                    all(isfinite(basis(:))))
                error('FloquetAnalysis_v3:TangentBasis', ...
                    ['TangentBasis must be a finite real n-by-r matrix ', ...
                     'with n equal to the state dimension.']);
            end
            if rank(basis) ~= size(basis, 2)
                error('FloquetAnalysis_v3:TangentBasisRank', ...
                    'TangentBasis columns must be linearly independent.');
            end
            leftInverse = (basis.' * basis) \ basis.';
            indices = [];
        end

        function [next, info] = evaluateMap(obj, map, x, q, p, varargin)
            info = struct();
            context = varargin;
            if isa(map, 'function_handle')
                try
                    [next, info] = map(x, q, p, context{:});
                catch firstError
                    try
                        next = map(x, q, p, context{:});
                    catch
                        try
                            [next, info] = map(x, q, p);
                        catch
                            try
                                next = map(x, q, p);
                                info = struct();
                            catch
                                rethrow(firstError)
                            end
                        end
                    end
                end
            elseif isobject(map) && ismethod(map, 'evaluate')
                try
                    [next, info] = map.evaluate(x, q, p, context{:});
                catch exception
                    if isempty(context) || ~obj.isTooManyInputs(exception)
                        rethrow(exception)
                    end
                    [next, info] = map.evaluate(x, q, p);
                end
            elseif isstruct(map) && isfield(map, 'evaluate')
                try
                    [next, info] = map.evaluate(x, q, p, context{:});
                catch exception
                    if isempty(context) || ~obj.isTooManyInputs(exception)
                        rethrow(exception)
                    end
                    [next, info] = map.evaluate(x, q, p);
                end
            else
                error('FloquetAnalysis_v3:MapInterface', ...
                    'map must be a function handle or expose evaluate().');
            end
        end

        function tf = discreteClosed(~, info, q)
            tf = true;
            if ~isstruct(info)
                return
            end
            if isfield(info, 'discrete_closed')
                tf = logical(info.discrete_closed);
            elseif isfield(info, 'mode_closed')
                tf = logical(info.mode_closed);
            elseif isfield(info, 'final_mode')
                tf = isequal(info.final_mode, q);
            end
        end

        function signature = eventSignature(~, info)
            signature = '';
            if ~isstruct(info)
                return
            end
            cyclicFields = {'cyclic_event_signature', ...
                'cyclicEventSignature', 'cycle_signature', 'cycleSignature'};
            for i = 1:numel(cyclicFields)
                if isfield(info, cyclicFields{i}) && ...
                        ~isempty(info.(cyclicFields{i}))
                    value = info.(cyclicFields{i});
                    if ischar(value)
                        signature = value;
                    else
                        signature = char(strjoin(string(value(:)), '>'));
                    end
                    return
                end
            end
            sequence = [];
            fields = {'event_sequence', 'eventSequence', 'event_history'};
            for i = 1:numel(fields)
                if isfield(info, fields{i})
                    sequence = info.(fields{i});
                    break
                end
            end
            if isempty(sequence)
                return
            end
            if isstruct(sequence)
                if isfield(sequence, 'event_type')
                    sequence = {sequence.event_type};
                elseif isfield(sequence, 'type')
                    % Trajectory_v3 and PoincareMap_v3 use `type` as the
                    % canonical physical-event field.  Accept it when a
                    % generic map supplies event history without an
                    % already-canonical cyclic signature.
                    sequence = {sequence.type};
                elseif isfield(sequence, 'name')
                    sequence = {sequence.name};
                elseif isfield(sequence, 'event_id')
                    sequence = {sequence.event_id};
                else
                    signature = sprintf('struct[%d]', numel(sequence));
                    return
                end
            end
            if isnumeric(sequence) || islogical(sequence)
                signature = mat2str(sequence(:).');
            elseif ischar(sequence)
                signature = sequence;
            elseif isstring(sequence)
                signature = strjoin(cellstr(sequence(:)), '>');
            elseif iscell(sequence)
                parts = cell(size(sequence));
                for i = 1:numel(sequence)
                    item = sequence{i};
                    if isnumeric(item) || islogical(item)
                        parts{i} = mat2str(item);
                    elseif ischar(item)
                        parts{i} = item;
                    elseif isstring(item)
                        parts{i} = char(item);
                    else
                        parts{i} = class(item);
                    end
                end
                signature = strjoin(parts(:).', '>');
            end
        end

        function signature = sectionSignature(obj, info)
            signature = obj.memberAny(info, { ...
                'section_relative_event_signature', ...
                'sectionRelativeEventSignature', 'event_signature', ...
                'eventSignature'}, '');
            if isstring(signature)
                signature = char(strjoin(signature(:), '>'));
            elseif iscell(signature)
                signature = char(strjoin(string(signature(:)), '>'));
            elseif isnumeric(signature) || islogical(signature)
                signature = mat2str(signature);
            elseif ~ischar(signature)
                signature = '';
            end
        end

        function tf = cycleComplete(obj, info)
            tf = obj.memberAny(info, ...
                {'cycle_complete', 'cycleComplete', ...
                 'return_policy_accepted'}, true);
            tf = isscalar(tf) && logical(tf);
        end

        function metadata = hybridMetadata(obj, info, discreteClosed)
            metadata = info;
            if isempty(metadata) || ~isstruct(metadata)
                metadata = struct();
            end
            metadata.topology_metadata_complete = ...
                obj.topologyMetadataComplete(info);
            metadata.discrete_closed = discreteClosed;
            metadata.integration_success = obj.memberAny(info, ...
                {'integration_success', 'success'}, true);
            metadata.cycle_complete = obj.cycleComplete(info);
            metadata.return_multiplicity = obj.memberAny(info, ...
                {'return_multiplicity', 'returnMultiplicity'}, 1);
            metadata.cyclic_event_signature = obj.eventSignature(info);
            metadata.section_relative_event_signature = obj.memberAny(info, ...
                {'section_relative_event_signature', ...
                 'sectionRelativeEventSignature', 'event_signature'}, '');
            metadata.event_cluster_signature = obj.memberAny(info, ...
                {'event_cluster_signature', 'eventClusterSignature', ...
                 'cluster_signature', 'clusterSignature'}, '');
            margins = obj.transversalityMargins(info);
            metadata.guard_transversality_margin = margins.guard;
            metadata.section_transversality = margins.section;
        end

        function complete = topologyMetadataComplete(obj, info)
            % A default hybrid Floquet calculation is meaningful only when
            % the map supplies evidence for every topology check.  Defaults
            % such as closure=true or transversality=Inf are useful for
            % smooth finite differences, but must not certify a hybrid
            % derivative when the callback omitted the corresponding data.
            if isempty(info) || ~isstruct(info)
                complete = false;
                return
            end
            closureEvidence = obj.hasAnyField(info, { ...
                'discrete_closed', 'discreteClosure', 'mode_closed', ...
                'final_mode'});
            cycleEvidence = obj.hasAnyField(info, { ...
                'cycle_complete', 'cycleComplete', ...
                'return_policy_accepted'});
            multiplicityEvidence = obj.hasAnyField(info, { ...
                'return_multiplicity', 'returnMultiplicity'});
            cyclicSignatureEvidence = obj.hasAnyNonemptyField(info, { ...
                'cyclic_event_signature', 'cyclicEventSignature', ...
                'cycle_signature', 'cycleSignature', 'event_sequence', ...
                'eventSequence', 'event_history'});
            sectionSignatureEvidence = obj.hasAnyNonemptyField(info, { ...
                'section_relative_event_signature', ...
                'sectionRelativeEventSignature', 'event_signature', ...
                'eventSignature'});
            clusterSignatureEvidence = obj.hasAnyNonemptyField(info, { ...
                'event_cluster_signature', 'eventClusterSignature', ...
                'cluster_signature', 'clusterSignature'});
            guardEvidence = obj.hasAnyField(info, { ...
                'guard_transversality_margin', ...
                'minimum_guard_transversality'});
            sectionEvidence = obj.hasAnyField(info, { ...
                'section_transversality', ...
                'section_transversality_margin'});
            complete = (~obj.RequireDiscreteClosure || closureEvidence) && ...
                (~obj.RequireCycleCompletion || cycleEvidence) && ...
                multiplicityEvidence && cyclicSignatureEvidence && ...
                (~obj.RequireCompatibleSectionSignature || ...
                    sectionSignatureEvidence) && ...
                (~obj.RequireCompatibleClusterSignature || ...
                    clusterSignatureEvidence) && ...
                guardEvidence && sectionEvidence;
        end

        function tf = hasAnyField(~, source, names)
            tf = isstruct(source) && any(cellfun( ...
                @(name) isfield(source, name), names));
        end

        function tf = hasAnyNonemptyField(~, source, names)
            tf = false;
            if ~isstruct(source)
                return
            end
            for index = 1:numel(names)
                if isfield(source, names{index}) && ...
                        ~isempty(source.(names{index}))
                    tf = true;
                    return
                end
            end
        end

        function margins = transversalityMargins(obj, info)
            margins = struct();
            guard = obj.memberAny(info, ...
                {'guard_transversality_margin', ...
                 'minimum_guard_transversality'}, Inf);
            if isempty(guard)
                guard = Inf;
            elseif ~isscalar(guard)
                guard = min(abs(guard(:)));
            end
            section = obj.memberAny(info, ...
                {'section_transversality', ...
                 'section_transversality_margin'}, Inf);
            if isempty(section)
                section = Inf;
            elseif ~isscalar(section)
                section = min(abs(section(:)));
            end
            margins.guard = abs(guard);
            margins.section = abs(section);
        end

        function lifted = liftEigenvectors(~, vectors, indices, n)
            lifted = zeros(n, size(vectors, 2), 'like', vectors);
            lifted(indices, :) = vectors;
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

        function tf = isTooManyInputs(~, exception)
            tf = any(strcmp(exception.identifier, { ...
                'MATLAB:maxrhs', 'MATLAB:TooManyInputs'}));
        end

        function obj = applyOptions(obj, options)
            if ~isstruct(options)
                error('FloquetAnalysis_v3:Options', ...
                    'Options must be a structure.');
            end
            names = fieldnames(options);
            for i = 1:numel(names)
                obj = obj.setOption(names{i}, options.(names{i}));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin), 2) ~= 0
                error('FloquetAnalysis_v3:NameValue', ...
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
                error('FloquetAnalysis_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(list{match}) = value;
        end
    end
end
