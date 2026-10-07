classdef LegacyStateAdapter_v3
    %LEGACYSTATEADAPTER_V3 Convert v1/v2 state ordering to/from v3.

    methods (Static)
        function newX = toV3State(oldX)
            oldNames = LegacyStateAdapter_v3.oldStateNames();
            schema = QuadrupedSchema_v3.shared();
            newNames = schema.State.Names;
            permutation = LegacyStateAdapter_v3.namesToPermutation( ...
                newNames, oldNames);
            newX = LegacyStateAdapter_v3.permuteCoordinates( ...
                oldX, permutation, numel(oldNames), 'full state');
        end

        function oldX = fromV3State(newX)
            oldNames = LegacyStateAdapter_v3.oldStateNames();
            schema = QuadrupedSchema_v3.shared();
            newNames = schema.State.Names;
            permutation = LegacyStateAdapter_v3.namesToPermutation( ...
                oldNames, newNames);
            oldX = LegacyStateAdapter_v3.permuteCoordinates( ...
                newX, permutation, numel(newNames), 'full state');
        end

        function newU = toV3Unknown(oldU)
            oldNames = LegacyStateAdapter_v3.oldStateNames();
            oldNames = oldNames(2:end);
            schema = QuadrupedSchema_v3.shared();
            newNames = schema.State.Names(schema.Root.UnknownIndices);
            permutation = LegacyStateAdapter_v3.namesToPermutation( ...
                newNames, oldNames);
            newU = LegacyStateAdapter_v3.permuteCoordinates( ...
                oldU, permutation, numel(oldNames), '13-state root input');
        end

        function oldU = fromV3Unknown(newU)
            oldNames = LegacyStateAdapter_v3.oldStateNames();
            oldNames = oldNames(2:end);
            schema = QuadrupedSchema_v3.shared();
            newNames = schema.State.Names(schema.Root.UnknownIndices);
            permutation = LegacyStateAdapter_v3.namesToPermutation( ...
                oldNames, newNames);
            oldU = LegacyStateAdapter_v3.permuteCoordinates( ...
                newU, permutation, numel(newNames), '13-state root input');
        end

        function permutation = fullStatePermutation()
            schema = QuadrupedSchema_v3.shared();
            permutation = LegacyStateAdapter_v3.namesToPermutation( ...
                schema.State.Names, ...
                LegacyStateAdapter_v3.oldStateNames());
        end

        function permutation = unknownPermutation()
            schema = QuadrupedSchema_v3.shared();
            oldNames = LegacyStateAdapter_v3.oldStateNames();
            permutation = LegacyStateAdapter_v3.namesToPermutation( ...
                schema.State.Names(schema.Root.UnknownIndices), ...
                oldNames(2:end));
        end
    end

    methods (Static, Access = private)
        function names = oldStateNames()
            names = { ...
                'x', 'dx', 'y', 'dy', 'phi', 'dphi', ...
                'alphaBL', 'dalphaBL', 'alphaFL', 'dalphaFL', ...
                'alphaBR', 'dalphaBR', 'alphaFR', 'dalphaFR'};
        end

        function permutation = namesToPermutation(targetNames, sourceNames)
            permutation = zeros(1, numel(targetNames));
            for i = 1:numel(targetNames)
                index = find(strcmp(targetNames{i}, sourceNames), 1);
                if isempty(index)
                    error('LegacyStateAdapter_v3:IncompatibleSchema', ...
                        'Coordinate "%s" is absent from the source schema.', ...
                        targetNames{i});
                end
                permutation(i) = index;
            end
        end

        function output = permuteCoordinates(input, permutation, width, label)
            if ~(isnumeric(input) && isreal(input) ...
                    && all(isfinite(input(:))))
                error('LegacyStateAdapter_v3:InvalidState', ...
                    '%s data must be finite and real.', label);
            end
            if isvector(input)
                if numel(input) ~= width
                    error('LegacyStateAdapter_v3:InvalidState', ...
                        '%s vector must contain %d entries.', label, width);
                end
                if isrow(input)
                    output = input(permutation);
                else
                    output = input(permutation(:));
                end
                return;
            end
            if size(input, 2) == width && size(input, 1) ~= width
                output = input(:, permutation);
            elseif size(input, 1) == width && size(input, 2) ~= width
                output = input(permutation, :);
            else
                error('LegacyStateAdapter_v3:AmbiguousStateArray', ...
                    ['%s array must have exactly one coordinate dimension ' ...
                    'of length %d.'], label, width);
            end
        end
    end
end
