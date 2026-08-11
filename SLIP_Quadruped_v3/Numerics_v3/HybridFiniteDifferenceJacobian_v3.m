classdef HybridFiniteDifferenceJacobian_v3
    %HYBRIDFINITEDIFFERENCEJACOBIAN_V3 Topology-aware return-map derivative.
    %   CALLBACK must accept a trial point and may return
    %
    %       [value, metadata] = callback(point)
    %
    %   VALUE is a finite vector.  METADATA describes the hybrid execution.
    %   The implementation compares h and h/2 estimates, rejects incompatible
    %   cycle topology, and reports one-sided derivatives explicitly when a
    %   unique classical central derivative is unavailable.

    properties
        RelativeCandidateSteps = [1e-3, 3e-4, 1e-4, 3e-5, 1e-5, 3e-6]
        CoordinateScale = []
        UseRichardson = true
        AllowOneSided = true
        MaximumRelativeError = 5e-2
        MinimumGuardTransversality = 1e-7
        MinimumSectionTransversality = 1e-8
        RequireDiscreteClosure = true
        RequireCycleCompletion = true
        RequireCompatibleCyclicSignature = true
        RequireCompatibleSectionSignature = true
        RequireCompatibleClusterSignature = true
        RequireMatchingReturnMultiplicity = true
        IntegrationToleranceFactor = 1e-3
        UseParallel = false
        FailurePolicy = 'nan'       % 'nan' or 'error'
    end

    methods
        function obj = HybridFiniteDifferenceJacobian_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            obj.validateOptions();
        end

        function [jacobian, baseValue, report] = compute(obj, callback, point, varargin)
            if ~isa(callback, 'function_handle')
                error('HybridFiniteDifferenceJacobian_v3:Callback', ...
                    'The return-map callback must be a function handle.');
            end
            if ~(isnumeric(point) && isreal(point) && isvector(point) && ...
                    all(isfinite(point(:))))
                error('HybridFiniteDifferenceJacobian_v3:Point', ...
                    'The differentiation point must be a finite real vector.');
            end

            originalSize = size(point);
            point = double(point(:));
            scale = obj.coordinateScale(point);
            evaluationCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            evaluationCount = 0;

            base = evaluatePoint(point, NaN, 'baseline');
            if ~base.valid
                error('HybridFiniteDifferenceJacobian_v3:InvalidBase', ...
                    'The baseline hybrid return is invalid: %s', base.reason);
            end
            baseValue = base.value;
            outputDimension = numel(baseValue);
            variableCount = numel(point);
            jacobian = NaN(outputDimension, variableCount);
            columns = repmat(obj.emptyColumnReport(), 1, variableCount);

            % parfor cannot safely mutate the shared evaluation cache.  The
            % option is retained and reported; serial cached evaluation is used
            % when a parallel pool is unavailable or cache sharing is required.
            parallelRequested = logical(obj.UseParallel);
            parallelUsed = parallelRequested && obj.parallelAvailable();
            if parallelUsed
                columnJacobians = cell(1, variableCount);
                columnReports = cell(1, variableCount);
                columnEvaluations = zeros(1, variableCount);
                parfor column = 1:variableCount
                    local = obj;
                    local.UseParallel = false;
                    local.CoordinateScale = scale(column);
                    embedded = @(coordinate, context) ...
                        HybridFiniteDifferenceJacobian_v3.evaluateEmbedded( ...
                            callback, point, column, coordinate, context, ...
                            varargin{:});
                    [localJacobian, ~, localReport] = local.compute( ...
                        embedded, point(column));
                    columnJacobians{column} = localJacobian(:, 1);
                    localColumn = localReport.columns(1);
                    localColumn.index = column;
                    columnReports{column} = localColumn;
                    columnEvaluations(column) = localReport.mapEvaluations;
                end
                for column = 1:variableCount
                    jacobian(:, column) = columnJacobians{column};
                    columns(column) = columnReports{column};
                end
                evaluationCount = evaluationCount + sum(columnEvaluations);
            else
                for column = 1:variableCount
                    [jacobian(:, column), columns(column)] = ...
                        differentiateColumn(column);
                end
            end

            failed = find(~[columns.reliable]);
            if ~isempty(failed) && strcmpi(obj.FailurePolicy, 'error')
                error('HybridFiniteDifferenceJacobian_v3:UnreliableColumn', ...
                    'Hybrid derivative column %d was unreliable: %s', ...
                    failed(1), strjoin(columns(failed(1)).failureReasons, '; '));
            end

            report = struct();
            report.method = 'hybrid-step-refinement';
            report.baseMetadata = base.metadata;
            report.baseSignature = obj.signature(base.metadata, 'cyclic');
            report.baseSectionSignature = obj.signature(base.metadata, 'section');
            report.baseClusterSignature = obj.signature(base.metadata, 'cluster');
            report.returnMultiplicity = obj.member(base.metadata, ...
                {'return_multiplicity', 'returnMultiplicity'}, NaN);
            report.columns = columns;
            report.selectedSteps = [columns.selectedStep].';
            report.estimatedErrors = [columns.estimatedError].';
            report.perColumnReliability = [columns.reliable].';
            report.allReliable = all(report.perColumnReliability);
            report.classicalDerivative = report.allReliable && ...
                all(strcmp({columns.differenceType}, 'central-richardson') | ...
                    strcmp({columns.differenceType}, 'central'));
            report.returnMultiplicityPreserved = ...
                all([columns.returnMultiplicityPreserved]);
            report.forwardOneSidedJacobian = obj.oneSidedJacobian( ...
                columns, 'forwardOneSided', outputDimension);
            report.backwardOneSidedJacobian = obj.oneSidedJacobian( ...
                columns, 'backwardOneSided', outputDimension);
            report.forwardOneSidedAvailable = ...
                all(arrayfun(@(entry) entry.forwardOneSided.available, columns));
            report.backwardOneSidedAvailable = ...
                all(arrayfun(@(entry) entry.backwardOneSided.available, columns));
            report.mapEvaluations = evaluationCount;
            report.parallelRequested = parallelRequested;
            report.parallelUsed = parallelUsed;
            report.coordinateScale = scale;

            function [derivative, columnReport] = differentiateColumn(index)
                columnReport = obj.emptyColumnReport();
                columnReport.index = index;
                columnReport.candidateSteps = ...
                    obj.RelativeCandidateSteps(:) .* scale(index);
                candidates = repmat(obj.emptyCandidateReport(), ...
                    1, numel(columnReport.candidateSteps));
                startEvaluations = evaluationCount;

                for candidateIndex = 1:numel(columnReport.candidateSteps)
                    step = columnReport.candidateSteps(candidateIndex);
                    candidates(candidateIndex) = evaluateCandidate(index, step);
                end

                reliableIndices = find([candidates.reliable]);
                if ~isempty(reliableIndices)
                    % Candidate steps are supplied from large to small.  Taking
                    % the first converged h/h2 pair selects the beginning of a
                    % stable plateau instead of blindly taking the smallest h.
                    selectedIndex = reliableIndices(1);
                    selected = candidates(selectedIndex);
                    derivative = selected.derivative;
                    columnReport.reliable = true;
                else
                    errors = [candidates.estimatedError];
                    errors(~isfinite(errors)) = Inf;
                    [~, selectedIndex] = min(errors);
                    if isempty(selectedIndex) || isinf(errors(selectedIndex))
                        selectedIndex = numel(candidates);
                    end
                    selected = candidates(selectedIndex);
                    derivative = selected.derivative;
                    columnReport.reliable = false;
                end

                % Every failed perturbation can legitimately leave the
                % candidate derivative empty. Preserve the Jacobian shape
                % and report the failure as a nonfinite, unreliable column
                % instead of triggering a dimension-assignment exception.
                if isempty(derivative)
                    derivative = NaN(outputDimension, 1);
                end

                columnReport.selectedCandidate = selectedIndex;
                columnReport.selectedStep = selected.step;
                columnReport.derivativeEstimate = derivative;
                columnReport.estimatedError = selected.estimatedError;
                columnReport.differenceType = selected.differenceType;
                columnReport.oneSided = selected.oneSided;
                columnReport.piecewiseSmooth = selected.oneSided || ...
                    selected.topologyChanged;
                columnReport.eventSignatures = selected.eventSignatures;
                columnReport.sectionSignatures = selected.sectionSignatures;
                columnReport.clusterSignatures = selected.clusterSignatures;
                columnReport.returnMultiplicities = ...
                    selected.returnMultiplicities;
                columnReport.returnMultiplicityPreserved = ...
                    selected.returnMultiplicityPreserved;
                columnReport.forwardOneSided = selected.forwardOneSided;
                columnReport.backwardOneSided = selected.backwardOneSided;
                columnReport.failureReasons = selected.failureReasons;
                columnReport.candidates = candidates;
                columnReport.mapEvaluations = evaluationCount - startEvaluations;
            end

            function candidate = evaluateCandidate(index, step)
                candidate = obj.emptyCandidateReport();
                candidate.step = step;
                direction = zeros(variableCount, 1);
                direction(index) = 1;

                plus = evaluatePoint(point + step * direction, step, 'plus-h');
                minus = evaluatePoint(point - step * direction, step, 'minus-h');
                halfStep = step / 2;
                plusHalf = evaluatePoint(point + halfStep * direction, ...
                    halfStep, 'plus-h/2');
                minusHalf = evaluatePoint(point - halfStep * direction, ...
                    halfStep, 'minus-h/2');

                candidate.eventSignatures = { ...
                    obj.signature(plus.metadata, 'cyclic'), ...
                    obj.signature(minus.metadata, 'cyclic'), ...
                    obj.signature(plusHalf.metadata, 'cyclic'), ...
                    obj.signature(minusHalf.metadata, 'cyclic')};
                candidate.sectionSignatures = { ...
                    obj.signature(plus.metadata, 'section'), ...
                    obj.signature(minus.metadata, 'section'), ...
                    obj.signature(plusHalf.metadata, 'section'), ...
                    obj.signature(minusHalf.metadata, 'section')};
                candidate.clusterSignatures = { ...
                    obj.signature(plus.metadata, 'cluster'), ...
                    obj.signature(minus.metadata, 'cluster'), ...
                    obj.signature(plusHalf.metadata, 'cluster'), ...
                    obj.signature(minusHalf.metadata, 'cluster')};
                candidate.returnMultiplicities = [ ...
                    obj.returnMultiplicity(plus.metadata), ...
                    obj.returnMultiplicity(minus.metadata), ...
                    obj.returnMultiplicity(plusHalf.metadata), ...
                    obj.returnMultiplicity(minusHalf.metadata)];
                baseMultiplicity = obj.returnMultiplicity(base.metadata);
                candidate.returnMultiplicityPreserved = ...
                    isfinite(baseMultiplicity) && ...
                    all(isfinite(candidate.returnMultiplicities)) && ...
                    all(candidate.returnMultiplicities == baseMultiplicity);

                plusCompatible = plus.valid && obj.compatible(base.metadata, plus.metadata);
                minusCompatible = minus.valid && obj.compatible(base.metadata, minus.metadata);
                plusHalfCompatible = plusHalf.valid && ...
                    obj.compatible(base.metadata, plusHalf.metadata);
                minusHalfCompatible = minusHalf.valid && ...
                    obj.compatible(base.metadata, minusHalf.metadata);

                % Preserve both adjacent one-sided limits independently of
                % whether either side belongs to the baseline chart.  These
                % are Bouligand diagnostics, not a substitute for a unique
                % classical derivative.  The two h-levels on a side must
                % themselves have compatible hybrid topology.
                candidate.forwardOneSided = oneSidedDiagnostic( ...
                    plus, plusHalf, step, halfStep, true, ...
                    plusCompatible && plusHalfCompatible);
                candidate.backwardOneSided = oneSidedDiagnostic( ...
                    minus, minusHalf, step, halfStep, false, ...
                    minusCompatible && minusHalfCompatible);

                centralValid = plusCompatible && minusCompatible && ...
                    plusHalfCompatible && minusHalfCompatible;
                if centralValid
                    coarse = (plus.value - minus.value) ./ (2 * step);
                    fine = (plusHalf.value - minusHalf.value) ./ step;
                    candidate.estimatedError = norm(fine - coarse) / ...
                        max(1, norm(fine));
                    if obj.UseRichardson
                        candidate.derivative = (4 * fine - coarse) / 3;
                        candidate.differenceType = 'central-richardson';
                    else
                        candidate.derivative = fine;
                        candidate.differenceType = 'central';
                    end
                    candidate.reliable = isfinite(candidate.estimatedError) && ...
                        candidate.estimatedError <= obj.MaximumRelativeError;
                    return
                end

                candidate.topologyChanged = any([ ...
                    plus.valid && ~plusCompatible, ...
                    minus.valid && ~minusCompatible, ...
                    plusHalf.valid && ~plusHalfCompatible, ...
                    minusHalf.valid && ~minusHalfCompatible]);
                candidate.failureReasons = obj.collectReasons( ...
                    {plus, minus, plusHalf, minusHalf}, ...
                    [plusCompatible, minusCompatible, ...
                     plusHalfCompatible, minusHalfCompatible]);

                if ~obj.AllowOneSided
                    return
                end

                if candidate.forwardOneSided.available && ...
                        candidate.forwardOneSided.compatibleWithBase
                    candidate.derivative = ...
                        candidate.forwardOneSided.derivative;
                    candidate.estimatedError = ...
                        candidate.forwardOneSided.estimatedError;
                    candidate.differenceType = 'one-sided-forward';
                    candidate.oneSided = true;
                elseif candidate.backwardOneSided.available && ...
                        candidate.backwardOneSided.compatibleWithBase
                    candidate.derivative = ...
                        candidate.backwardOneSided.derivative;
                    candidate.estimatedError = ...
                        candidate.backwardOneSided.estimatedError;
                    candidate.differenceType = 'one-sided-backward';
                    candidate.oneSided = true;
                end

                % A one-sided estimate is useful piecewise-smooth information,
                % but is deliberately never labelled a unique classical
                % Floquet derivative.
                candidate.reliable = false;
            end

            function side = oneSidedDiagnostic(coarseRecord, fineRecord, ...
                    coarseStep, fineStep, isForward, compatibleWithBase)
                side = obj.emptyOneSidedReport();
                if ~(coarseRecord.valid && fineRecord.valid && ...
                        obj.compatible(coarseRecord.metadata, ...
                            fineRecord.metadata))
                    return
                end
                if isForward
                    coarseDerivative = ...
                        (coarseRecord.value - base.value) ./ coarseStep;
                    fineDerivative = ...
                        (fineRecord.value - base.value) ./ fineStep;
                    side.direction = 'forward';
                else
                    coarseDerivative = ...
                        (base.value - coarseRecord.value) ./ coarseStep;
                    fineDerivative = ...
                        (base.value - fineRecord.value) ./ fineStep;
                    side.direction = 'backward';
                end
                side.derivative = 2 * fineDerivative - coarseDerivative;
                side.estimatedError = norm(fineDerivative - ...
                    coarseDerivative) / max(1, norm(fineDerivative));
                side.available = all(isfinite(side.derivative)) && ...
                    isfinite(side.estimatedError);
                side.converged = side.available && ...
                    side.estimatedError <= obj.MaximumRelativeError;
                side.compatibleWithBase = logical(compatibleWithBase);
                side.cyclicSignature = obj.signature( ...
                    fineRecord.metadata, 'cyclic');
                side.sectionSignature = obj.signature( ...
                    fineRecord.metadata, 'section');
                side.clusterSignature = obj.signature( ...
                    fineRecord.metadata, 'cluster');
                side.returnMultiplicities = [ ...
                    obj.returnMultiplicity(coarseRecord.metadata), ...
                    obj.returnMultiplicity(fineRecord.metadata)];
            end

            function record = evaluatePoint(value, step, label)
                key = sprintf('%.17g,', value);
                if isKey(evaluationCache, key)
                    record = evaluationCache(key);
                    return
                end
                evaluationCount = evaluationCount + 1;
                context = struct( ...
                    'finiteDifferenceStep', step, ...
                    'suggestedRelativeTolerance', ...
                        obj.IntegrationToleranceFactor * abs(step), ...
                    'label', label);
                record = obj.callCallback(callback, ...
                    reshape(value, originalSize), context, varargin{:});
                evaluationCache(key) = record;
            end
        end
    end

    methods (Access = private)
        function record = callCallback(obj, callback, point, context, varargin)
            record = struct('value', [], 'metadata', struct(), ...
                'valid', false, 'reason', '');
            try
                callbackArguments = varargin;
                argumentCount = nargin(callback);
                if argumentCount < 0 || argumentCount >= 2 + numel(varargin)
                    callbackArguments = [{context}, varargin];
                end
                try
                    [value, metadata] = callback(point, callbackArguments{:});
                catch exception
                    if ~obj.isTooManyOutputs(exception)
                        rethrow(exception);
                    end
                    value = callback(point, callbackArguments{:});
                    metadata = struct();
                end
                if ~(isnumeric(value) && isvector(value) && all(isfinite(value(:))))
                    record.reason = 'Callback returned a nonfinite or nonvector value.';
                    return
                end
                if isempty(metadata)
                    metadata = struct();
                end
                record.value = value(:);
                record.metadata = metadata;
                [record.valid, record.reason] = obj.metadataValid(metadata);
            catch exception
                record.reason = sprintf('%s: %s', exception.identifier, exception.message);
                record.metadata = struct('integration_success', false, ...
                    'errorIdentifier', exception.identifier, ...
                    'message', exception.message);
            end
        end

        function [valid, reason] = metadataValid(obj, metadata)
            valid = true;
            reasons = {};
            if isstruct(metadata) && ...
                    isfield(metadata, 'topology_metadata_complete') && ...
                    (~isscalar(metadata.topology_metadata_complete) || ...
                     ~logical(metadata.topology_metadata_complete))
                valid = false;
                reasons{end + 1} = ...
                    'required hybrid topology metadata is incomplete';
            end
            falseFields = {'success', 'valid', 'admissible', ...
                'integration_success', ...
                'integrationSuccess'};
            for index = 1:numel(falseFields)
                field = falseFields{index};
                if isstruct(metadata) && isfield(metadata, field) && ...
                        isscalar(metadata.(field)) && ~logical(metadata.(field))
                    valid = false;
                    reasons{end + 1} = [field, '=false']; %#ok<AGROW>
                end
            end
            if obj.RequireDiscreteClosure
                closure = obj.member(metadata, ...
                    {'discrete_closed', 'discreteClosure', 'mode_closed'}, true);
                if isscalar(closure) && ~logical(closure)
                    valid = false;
                    reasons{end + 1} = 'discrete closure failed';
                end
            end
            if obj.RequireCycleCompletion
                complete = obj.member(metadata, ...
                    {'cycle_complete', 'cycleComplete', 'return_policy_accepted'}, true);
                if isscalar(complete) && ~logical(complete)
                    valid = false;
                    reasons{end + 1} = 'cycle completion failed';
                end
            end
            guardMargin = obj.member(metadata, ...
                {'guard_transversality_margin', 'guardTransversalityMargin', ...
                 'minimum_guard_transversality'}, Inf);
            if isscalar(guardMargin) && isfinite(guardMargin) && ...
                    guardMargin < obj.MinimumGuardTransversality
                valid = false;
                reasons{end + 1} = 'guard transversality is too small';
            end
            sectionMargin = obj.member(metadata, ...
                {'section_transversality', 'sectionTransversality', ...
                 'section_transversality_margin'}, Inf);
            if isscalar(sectionMargin) && isfinite(sectionMargin) && ...
                    sectionMargin < obj.MinimumSectionTransversality
                valid = false;
                reasons{end + 1} = 'section transversality is too small';
            end
            reason = strjoin(reasons, '; ');
        end

        function compatible = compatible(obj, baseline, trial)
            [valid, ~] = obj.metadataValid(trial);
            compatible = valid;
            if ~compatible
                return
            end
            if obj.RequireMatchingReturnMultiplicity
                left = obj.member(baseline, ...
                    {'return_multiplicity', 'returnMultiplicity'}, 1);
                right = obj.member(trial, ...
                    {'return_multiplicity', 'returnMultiplicity'}, 1);
                compatible = isequal(left, right);
            end
            if compatible && obj.RequireCompatibleCyclicSignature
                left = obj.signature(baseline, 'cyclic');
                right = obj.signature(trial, 'cyclic');
                compatible = (isempty(left) && isempty(right)) || ...
                    (~isempty(left) && ~isempty(right) && strcmp(left, right));
            end
            if compatible && obj.RequireCompatibleSectionSignature
                left = obj.signature(baseline, 'section');
                right = obj.signature(trial, 'section');
                compatible = (isempty(left) && isempty(right)) || ...
                    (~isempty(left) && ~isempty(right) && strcmp(left, right));
            end
            if compatible && obj.RequireCompatibleClusterSignature
                left = obj.signature(baseline, 'cluster');
                right = obj.signature(trial, 'cluster');
                compatible = (isempty(left) && isempty(right)) || ...
                    (~isempty(left) && ~isempty(right) && strcmp(left, right));
            end
        end

        function signature = signature(obj, metadata, kind)
            switch kind
                case 'cyclic'
                    names = {'cyclic_event_signature', ...
                        'cyclicEventSignature', 'cycle_signature', ...
                        'cycleSignature'};
                case 'section'
                    names = {'section_relative_event_signature', ...
                        'sectionRelativeEventSignature', ...
                        'event_signature', 'eventSignature'};
                otherwise
                    names = {'event_cluster_signature', ...
                        'eventClusterSignature', 'cluster_signature', ...
                        'clusterSignature'};
            end
            signature = obj.member(metadata, names, '');
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

        function value = returnMultiplicity(obj, metadata)
            value = obj.member(metadata, ...
                {'return_multiplicity', 'returnMultiplicity'}, NaN);
            if ~(isnumeric(value) && isreal(value) && isscalar(value) && ...
                    isfinite(value))
                value = NaN;
            else
                value = double(value);
            end
        end

        function jacobian = oneSidedJacobian(~, columns, field, rowCount)
            jacobian = NaN(rowCount, numel(columns));
            for index = 1:numel(columns)
                side = columns(index).(field);
                if side.available && numel(side.derivative) == rowCount
                    jacobian(:, index) = side.derivative(:);
                end
            end
        end

        function reasons = collectReasons(~, records, compatible)
            labels = {'plus-h', 'minus-h', 'plus-h/2', 'minus-h/2'};
            reasons = {};
            for index = 1:numel(records)
                record = records{index};
                if ~record.valid
                    reasons{end + 1} = sprintf('%s invalid: %s', ...
                        labels{index}, record.reason); %#ok<AGROW>
                elseif ~compatible(index)
                    reasons{end + 1} = sprintf( ...
                        '%s changed cycle topology', labels{index}); %#ok<AGROW>
                end
            end
            if isempty(reasons)
                reasons = {'h and h/2 estimates did not form a reliable plateau'};
            end
        end

        function scale = coordinateScale(obj, point)
            if isempty(obj.CoordinateScale)
                scale = 1 + abs(point);
            else
                scale = obj.CoordinateScale(:);
                if isscalar(scale)
                    scale = repmat(scale, numel(point), 1);
                end
                if numel(scale) ~= numel(point) || any(~isfinite(scale)) || ...
                        any(scale <= 0)
                    error('HybridFiniteDifferenceJacobian_v3:Scale', ...
                        'CoordinateScale must be positive and match the point.');
                end
            end
        end

        function value = member(~, source, names, default)
            value = default;
            if isempty(source) || ~isstruct(source)
                return
            end
            for index = 1:numel(names)
                if isfield(source, names{index})
                    value = source.(names{index});
                    return
                end
            end
        end

        function obj = applyOptions(obj, options)
            if ~isstruct(options) || ~isscalar(options)
                error('HybridFiniteDifferenceJacobian_v3:Options', ...
                    'Options must be a scalar structure.');
            end
            names = fieldnames(options);
            for index = 1:numel(names)
                obj = obj.setOption(names{index}, options.(names{index}));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin), 2) ~= 0
                error('HybridFiniteDifferenceJacobian_v3:NameValue', ...
                    'Options must be supplied as name/value pairs.');
            end
            for index = 1:2:numel(varargin)
                obj = obj.setOption(varargin{index}, varargin{index + 1});
            end
        end

        function obj = setOption(obj, name, value)
            list = properties(obj);
            match = find(strcmpi(char(name), list), 1);
            if isempty(match)
                error('HybridFiniteDifferenceJacobian_v3:UnknownOption', ...
                    'Unknown option "%s".', char(name));
            end
            obj.(list{match}) = value;
        end

        function validateOptions(obj)
            steps = obj.RelativeCandidateSteps(:);
            if isempty(steps) || any(~isfinite(steps)) || any(steps <= 0)
                error('HybridFiniteDifferenceJacobian_v3:Steps', ...
                    'RelativeCandidateSteps must contain positive values.');
            end
            if obj.MaximumRelativeError <= 0 || ...
                    obj.IntegrationToleranceFactor <= 0
                error('HybridFiniteDifferenceJacobian_v3:Tolerances', ...
                    'Error and integration tolerance factors must be positive.');
            end
            if ~any(strcmpi(obj.FailurePolicy, {'nan', 'error'}))
                error('HybridFiniteDifferenceJacobian_v3:FailurePolicy', ...
                    'FailurePolicy must be nan or error.');
            end
        end

        function tf = isTooManyOutputs(~, exception)
            tf = any(strcmp(exception.identifier, { ...
                'MATLAB:maxlhs', 'MATLAB:TooManyOutputs', ...
                'MATLAB:unassignedOutputs'}));
        end

        function tf = parallelAvailable(~)
            tf = false;
            try
                tf = license('test', 'Distrib_Computing_Toolbox') && ...
                    ~isempty(ver('parallel'));
            catch
                tf = false;
            end
        end

        function report = emptyColumnReport(~)
            report = struct('index', 0, 'selectedStep', NaN, ...
                'derivativeEstimate', [], 'estimatedError', Inf, ...
                'reliable', false, 'differenceType', 'unavailable', ...
                'oneSided', false, 'piecewiseSmooth', false, ...
                'eventSignatures', {{}}, 'sectionSignatures', {{}}, ...
                'clusterSignatures', {{}}, ...
                'returnMultiplicities', [], ...
                'returnMultiplicityPreserved', false, ...
                'forwardOneSided', ...
                    HybridFiniteDifferenceJacobian_v3.emptySide(), ...
                'backwardOneSided', ...
                    HybridFiniteDifferenceJacobian_v3.emptySide(), ...
                'failureReasons', {{}}, 'mapEvaluations', 0, ...
                'candidateSteps', [], 'selectedCandidate', NaN, ...
                'candidates', []);
        end

        function report = emptyCandidateReport(~)
            report = struct('step', NaN, 'derivative', [], ...
                'estimatedError', Inf, 'reliable', false, ...
                'differenceType', 'unavailable', 'oneSided', false, ...
                'topologyChanged', false, 'eventSignatures', {{}}, ...
                'sectionSignatures', {{}}, 'clusterSignatures', {{}}, ...
                'returnMultiplicities', [], ...
                'returnMultiplicityPreserved', false, ...
                'forwardOneSided', ...
                    HybridFiniteDifferenceJacobian_v3.emptySide(), ...
                'backwardOneSided', ...
                    HybridFiniteDifferenceJacobian_v3.emptySide(), ...
                'failureReasons', {{}});
        end

        function report = emptyOneSidedReport(~)
            report = HybridFiniteDifferenceJacobian_v3.emptySide();
        end
    end

    methods (Static, Access = private)
        function report = emptySide()
            report = struct('direction', '', 'derivative', [], ...
                'estimatedError', Inf, 'available', false, ...
                'converged', false, 'compatibleWithBase', false, ...
                'cyclicSignature', '', 'sectionSignature', '', ...
                'clusterSignature', '', 'returnMultiplicities', []);
        end

        function [value, metadata] = evaluateEmbedded(callback, basePoint, ...
                index, coordinate, context, varargin)
            trial = basePoint(:);
            trial(index) = coordinate;
            arguments = varargin;
            callbackNargin = nargin(callback);
            if callbackNargin < 0 || ...
                    callbackNargin >= 2 + numel(varargin)
                arguments = [{context}, varargin];
            end
            try
                [value, metadata] = callback(trial, arguments{:});
            catch exception
                tooManyOutputs = any(strcmp(exception.identifier, { ...
                    'MATLAB:maxlhs', 'MATLAB:TooManyOutputs', ...
                    'MATLAB:unassignedOutputs'}));
                if ~tooManyOutputs
                    rethrow(exception)
                end
                value = callback(trial, arguments{:});
                metadata = struct();
            end
        end
    end
end
