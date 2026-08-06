classdef LegacyModeAdapter_v3
    %LEGACYMODEADAPTER_V3 Convert [BL FL BR FR] modes to/from v3.

    methods (Static)
        function newQ = toV3(oldQ)
            schema = QuadrupedSchema_v3.shared();
            permutation = LegacyModeAdapter_v3.namesToPermutation( ...
                schema.Leg.Names, LegacyModeAdapter_v3.oldLegNames());
            newQ = LegacyModeAdapter_v3.permuteModes( ...
                oldQ, permutation, schema.Leg.Count);
        end

        function oldQ = fromV3(newQ)
            schema = QuadrupedSchema_v3.shared();
            permutation = LegacyModeAdapter_v3.namesToPermutation( ...
                LegacyModeAdapter_v3.oldLegNames(), schema.Leg.Names);
            oldQ = LegacyModeAdapter_v3.permuteModes( ...
                newQ, permutation, schema.Leg.Count);
        end

        function permutation = permutation()
            schema = QuadrupedSchema_v3.shared();
            permutation = LegacyModeAdapter_v3.namesToPermutation( ...
                schema.Leg.Names, LegacyModeAdapter_v3.oldLegNames());
        end
    end

    methods (Static, Access = private)
        function names = oldLegNames()
            names = {'BL', 'FL', 'BR', 'FR'};
        end

        function permutation = namesToPermutation(targetNames, sourceNames)
            permutation = zeros(1, numel(targetNames));
            for i = 1:numel(targetNames)
                permutation(i) = find(strcmp(targetNames{i}, sourceNames), 1);
            end
        end

        function output = permuteModes(input, permutation, width)
            if ~(isnumeric(input) || islogical(input)) || ~isreal(input) ...
                    || any(~isfinite(double(input(:)))) ...
                    || any((double(input(:)) ~= 0) & (double(input(:)) ~= 1))
                error('LegacyModeAdapter_v3:InvalidMode', ...
                    'Mode data must contain only binary entries.');
            end
            if isvector(input)
                if numel(input) ~= width
                    error('LegacyModeAdapter_v3:InvalidMode', ...
                        'Mode vector must contain four entries.');
                end
                if isrow(input)
                    output = logical(input(permutation));
                else
                    output = logical(input(permutation(:)));
                end
                return;
            end
            if size(input, 2) == width && size(input, 1) ~= width
                output = logical(input(:, permutation));
            elseif size(input, 1) == width && size(input, 2) ~= width
                output = logical(input(permutation, :));
            else
                error('LegacyModeAdapter_v3:AmbiguousModeArray', ...
                    ['Mode array must have exactly one coordinate dimension ' ...
                    'of length four.']);
            end
        end
    end
end
