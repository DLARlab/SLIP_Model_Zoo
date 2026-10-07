classdef FiniteDifferenceJacobian_v3
    %FINITEDIFFERENCEJACOBIAN_V3 Dimension-independent finite differences.
    %   The default perturbation in coordinate i is
    %       sqrt(eps) * (1 + abs(x(i))).
    %   Forward and central formulas are supported.  Function values are
    %   always treated as column vectors, so rectangular Jacobians are valid.

    properties
        Method = 'forward'
        RelativeStep = []
        MinimumStep = 0
        MaximumStep = Inf
        CheckFinite = true
        FailurePolicy = 'error'       % 'error' or 'nan'
    end

    methods
        function obj = FiniteDifferenceJacobian_v3(varargin)
            if nargin == 1 && isstruct(varargin{1})
                obj = obj.applyOptions(varargin{1});
            elseif nargin > 0
                obj = obj.applyNameValue(varargin{:});
            end
            obj.validateOptions();
        end

        function [J, f0, info] = compute(obj, fun, x, varargin)
            if ~isa(fun, 'function_handle')
                error('FiniteDifferenceJacobian_v3:InvalidFunction', ...
                    'fun must be a function handle.');
            end
            if ~isnumeric(x) || ~isvector(x) || ~isreal(x)
                error('FiniteDifferenceJacobian_v3:InvalidPoint', ...
                    'x must be a real numeric vector.');
            end

            originalSize = size(x);
            x = x(:);
            n = numel(x);
            method = lower(char(obj.Method));
            relStep = obj.effectiveRelativeStep(x);
            steps = relStep .* (1 + abs(x));
            steps = max(steps, obj.MinimumStep);
            steps = min(steps, obj.MaximumStep);
            steps(steps == 0) = relStep;

            [f0, baseError] = obj.safeEvaluate(fun, reshape(x, originalSize), varargin{:});
            if ~isempty(baseError)
                error('FiniteDifferenceJacobian_v3:BaseEvaluationFailed', ...
                    'The base function evaluation failed: %s', baseError);
            end
            m = numel(f0);
            J = NaN(m, n, 'like', f0);
            failed = false(1, n);
            messages = cell(1, n);
            evaluations = 1;

            for i = 1:n
                ei = zeros(n, 1, 'like', x);
                ei(i) = steps(i);
                switch method
                    case 'forward'
                        [fp, message] = obj.safeEvaluate( ...
                            fun, reshape(x + ei, originalSize), varargin{:});
                        evaluations = evaluations + 1;
                        if isempty(message) && numel(fp) == m
                            J(:, i) = (fp - f0) ./ steps(i);
                        else
                            failed(i) = true;
                            messages{i} = obj.dimensionMessage(message, fp, m);
                        end
                    case 'central'
                        [fp, messageP] = obj.safeEvaluate( ...
                            fun, reshape(x + ei, originalSize), varargin{:});
                        [fm, messageM] = obj.safeEvaluate( ...
                            fun, reshape(x - ei, originalSize), varargin{:});
                        evaluations = evaluations + 2;
                        if isempty(messageP) && isempty(messageM) && ...
                                numel(fp) == m && numel(fm) == m
                            J(:, i) = (fp - fm) ./ (2 * steps(i));
                        else
                            failed(i) = true;
                            messages{i} = obj.dimensionMessage( ...
                                strjoin({messageP, messageM}, ' '), fp, m);
                        end
                end
            end

            if any(failed) && strcmpi(obj.FailurePolicy, 'error')
                first = find(failed, 1, 'first');
                error('FiniteDifferenceJacobian_v3:PerturbationFailed', ...
                    'Finite-difference column %d failed: %s', ...
                    first, messages{first});
            end

            info = struct();
            info.method = method;
            info.steps = steps;
            info.relativeStep = relStep;
            info.evaluations = evaluations;
            info.failedColumns = find(failed);
            info.messages = messages;
            info.success = ~any(failed);
        end

        function varargout = jacobian(obj, varargin)
            [varargout{1:nargout}] = obj.compute(varargin{:});
        end
    end

    methods (Access = private)
        function relStep = effectiveRelativeStep(obj, x)
            if isempty(obj.RelativeStep)
                if isa(x, 'single')
                    relStep = sqrt(eps('single'));
                else
                    relStep = sqrt(eps('double'));
                end
            else
                relStep = obj.RelativeStep;
            end
        end

        function [value, message] = safeEvaluate(obj, fun, x, varargin)
            message = '';
            value = [];
            try
                value = fun(x, varargin{:});
                if ~isnumeric(value) || ~isvector(value)
                    message = 'Function output must be a numeric vector.';
                    value = [];
                    return
                end
                value = value(:);
                if obj.CheckFinite && any(~isfinite(value))
                    message = 'Function output contains nonfinite values.';
                end
            catch ME
                message = ME.message;
            end
        end

        function message = dimensionMessage(~, message, value, expected)
            if isempty(message) && numel(value) ~= expected
                message = sprintf( ...
                    'Output length changed from %d to %d.', expected, numel(value));
            elseif isempty(message)
                message = 'Unknown perturbation evaluation failure.';
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
                error('FiniteDifferenceJacobian_v3:NameValue', ...
                    'Options must be supplied as name/value pairs.');
            end
            for i = 1:2:numel(varargin)
                obj = obj.setOption(varargin{i}, varargin{i + 1});
            end
        end

        function obj = setOption(obj, name, value)
            name = char(name);
            propertiesList = properties(obj);
            match = find(strcmpi(name, propertiesList), 1);
            if isempty(match)
                error('FiniteDifferenceJacobian_v3:UnknownOption', ...
                    'Unknown option "%s".', name);
            end
            obj.(propertiesList{match}) = value;
        end

        function validateOptions(obj)
            if ~any(strcmpi(obj.Method, {'forward', 'central'}))
                error('FiniteDifferenceJacobian_v3:Method', ...
                    'Method must be ''forward'' or ''central''.');
            end
            if ~isempty(obj.RelativeStep) && ...
                    (~isscalar(obj.RelativeStep) || obj.RelativeStep <= 0)
                error('FiniteDifferenceJacobian_v3:RelativeStep', ...
                    'RelativeStep must be a positive scalar.');
            end
            if obj.MinimumStep < 0 || obj.MaximumStep <= 0 || ...
                    obj.MinimumStep > obj.MaximumStep
                error('FiniteDifferenceJacobian_v3:StepBounds', ...
                    'Finite-difference step bounds are inconsistent.');
            end
            if ~any(strcmpi(obj.FailurePolicy, {'error', 'nan'}))
                error('FiniteDifferenceJacobian_v3:FailurePolicy', ...
                    'FailurePolicy must be ''error'' or ''nan''.');
            end
        end
    end
end
