classdef SymmetrySubspace_v3
    %SYMMETRYSUBSPACE_V3 Linear representation and invariant subspaces.
    %   For one or more representation generators rho(g), the invariant
    %   basis spans the common fixed space
    %
    %       Fix(G) = {eta : rho(g) eta = eta for every generator g}.

    properties (SetAccess = private)
        Actions
        Basis
        ComplementBasis
        Tolerance
        Name
        AmbientDimension
    end

    methods
        function obj = SymmetrySubspace_v3(actions, options)
            if nargin < 2 || isempty(options)
                options = struct();
            end
            if nargin < 1 || isempty(actions)
                error('SymmetrySubspace_v3:MissingAction', ...
                    'At least one square linear symmetry action is required.');
            end
            if isnumeric(actions)
                actions = {actions};
            end
            if ~iscell(actions) || isempty(actions)
                error('SymmetrySubspace_v3:Actions', ...
                    'Actions must be a square matrix or a cell array of them.');
            end
            obj.Tolerance = SymmetrySubspace_v3.option( ...
                options, 'Tolerance', 1e-10);
            obj.Name = char(SymmetrySubspace_v3.option( ...
                options, 'Name', 'invariant-subspace'));

            first = actions{1};
            if ~(isnumeric(first) && isreal(first) && ...
                    ismatrix(first) && size(first, 1) == size(first, 2) && ...
                    all(isfinite(first(:))))
                error('SymmetrySubspace_v3:Action', ...
                    'Every action must be a finite real square matrix.');
            end
            n = size(first, 1);
            constraints = zeros(0, n);
            normalizedActions = cell(size(actions));
            for index = 1:numel(actions)
                action = double(actions{index});
                if ~isequal(size(action), [n, n]) || ...
                        any(~isfinite(action(:)))
                    error('SymmetrySubspace_v3:ActionDimension', ...
                        'All actions must have the same finite square size.');
                end
                normalizedActions{index} = action;
                constraints = [constraints; action - eye(n)]; %#ok<AGROW>
            end
            obj.Actions = normalizedActions;
            obj.AmbientDimension = n;
            obj.Basis = null(constraints, obj.Tolerance);
            obj.ComplementBasis = null(obj.Basis.', obj.Tolerance);
        end

        function value = dimension(obj)
            value = size(obj.Basis, 2);
        end

        function eta = lift(obj, coordinates)
            coordinates = coordinates(:);
            if numel(coordinates) ~= obj.dimension()
                error('SymmetrySubspace_v3:CoordinateDimension', ...
                    'Coordinate dimension does not match the invariant basis.');
            end
            eta = obj.Basis * coordinates;
        end

        function coordinates = coordinates(obj, eta)
            eta = obj.validateAmbientVector(eta);
            coordinates = obj.Basis.' * eta;
        end

        function projected = project(obj, eta)
            eta = obj.validateAmbientVector(eta);
            projected = obj.Basis * (obj.Basis.' * eta);
        end

        function residual = invarianceResidual(obj, eta)
            eta = obj.validateAmbientVector(eta);
            residual = zeros(numel(obj.Actions), 1);
            for index = 1:numel(obj.Actions)
                residual(index) = norm( ...
                    obj.Actions{index} * eta - eta, 2);
            end
        end

        function tf = contains(obj, eta, tolerance)
            if nargin < 3 || isempty(tolerance)
                tolerance = obj.Tolerance;
            end
            tf = max(obj.invarianceResidual(eta), [], 'all') <= tolerance;
        end

        function embedded = embed(obj, ambientDimension, indices, name)
            if nargin < 4 || isempty(name)
                name = [obj.Name, '-embedded'];
            end
            indices = indices(:);
            if numel(indices) ~= obj.AmbientDimension || ...
                    any(indices < 1) || any(indices > ambientDimension) || ...
                    numel(unique(indices)) ~= numel(indices)
                error('SymmetrySubspace_v3:Embedding', ...
                    'Embedding indices must match the current ambient dimension.');
            end
            embedding = zeros(ambientDimension, obj.AmbientDimension);
            for index = 1:numel(indices)
                embedding(indices(index), index) = 1;
            end
            actionCells = cell(size(obj.Actions));
            untouched = eye(ambientDimension) - embedding * embedding.';
            for index = 1:numel(obj.Actions)
                actionCells{index} = untouched + ...
                    embedding * obj.Actions{index} * embedding.';
            end
            embedded = SymmetrySubspace_v3(actionCells, struct( ...
                'Tolerance', obj.Tolerance, 'Name', name));
        end
    end

    methods (Static)
        function obj = quadrupedLeftRight(schema, stateIndices)
            if nargin < 1 || isempty(schema)
                schema = QuadrupedSchema_v3.shared();
            end
            if ~isa(schema, 'QuadrupedSchema_v3')
                error('SymmetrySubspace_v3:QuadrupedSchema', ...
                    'schema must be a QuadrupedSchema_v3 object.');
            end
            permutation = eye(schema.State.Dimension);
            swaps = [ ...
                schema.State.alphaBL, schema.State.alphaBR; ...
                schema.State.dalphaBL, schema.State.dalphaBR; ...
                schema.State.alphaFL, schema.State.alphaFR; ...
                schema.State.dalphaFL, schema.State.dalphaFR];
            for index = 1:size(swaps, 1)
                left = swaps(index, 1);
                right = swaps(index, 2);
                permutation([left, right], :) = ...
                    permutation([right, left], :);
            end
            if nargin >= 2 && ~isempty(stateIndices)
                stateIndices = stateIndices(:);
                complement = setdiff((1:schema.State.Dimension).', ...
                    stateIndices, 'stable');
                if norm(permutation(stateIndices, complement), 'fro') > 0
                    error('SymmetrySubspace_v3:NonInvariantCoordinates', ...
                        'Selected state indices are not closed under the action.');
                end
                permutation = permutation(stateIndices, stateIndices);
            end
            obj = SymmetrySubspace_v3(permutation, struct( ...
                'Name', 'quadruped-left-right-fixed'));
        end

        function obj = quadrupedSectionTangent(schema)
            if nargin < 1 || isempty(schema)
                schema = QuadrupedSchema_v3.shared();
            end
            indices = schema.Root.TangentIndices(:);
            restricted = SymmetrySubspace_v3.quadrupedLeftRight( ...
                schema, indices);
            ambientBasis = zeros(schema.State.Dimension, ...
                restricted.dimension());
            ambientBasis(indices, :) = restricted.Basis;
            obj = SymmetrySubspace_v3.fromBasis(ambientBasis, struct( ...
                'Name', 'quadruped-left-right-section-tangent'));
        end

        function obj = fromBasis(basis, options)
            if nargin < 2
                options = struct();
            end
            if ~(isnumeric(basis) && isreal(basis) && ...
                    ismatrix(basis) && all(isfinite(basis(:))) && ...
                    rank(basis) == size(basis, 2))
                error('SymmetrySubspace_v3:Basis', ...
                    'Basis must have finite independent columns.');
            end
            [orthonormal, ~] = qr(basis, 0);
            action = 2 * (orthonormal * orthonormal.') - eye(size(basis, 1));
            obj = SymmetrySubspace_v3(action, options);
        end
    end

    methods (Access = private)
        function eta = validateAmbientVector(obj, eta)
            if ~(isnumeric(eta) && isreal(eta) && isvector(eta) && ...
                    numel(eta) == obj.AmbientDimension && ...
                    all(isfinite(eta(:))))
                error('SymmetrySubspace_v3:AmbientVector', ...
                    'Input must be a finite vector in the action space.');
            end
            eta = double(eta(:));
        end
    end

    methods (Static, Access = private)
        function value = option(options, name, default)
            value = default;
            if isstruct(options) && isfield(options, name)
                value = options.(name);
            end
        end
    end
end
