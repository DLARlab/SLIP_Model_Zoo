classdef BranchSolutionFile_v3
    %BRANCHSOLUTIONFILE_V3 One transactional MAT file with isolated point reads.
    % A single writer owns a file. Objects are never compacted or changed.
    % Each point has separate solution_NNNNNN and report_NNNNNN variables.

    methods (Static)
        function branch_index = initialize(file, metadata)
            file = BranchSolutionFile_v3.fileName(file);
            assert(~isfile(file) && ~isfolder(file), ...
                'BranchSolutionFile_v3:Exists', 'Initialize requires a new file.');
            assert(isstruct(metadata) && isscalar(metadata), ...
                'BranchSolutionFile_v3:Metadata', 'Metadata must be a scalar struct.');
            BranchSolutionFile_v3.validateValue(metadata, false, 0);
            folder = fileparts(file);
            if ~isfolder(folder), mkdir(folder); end
            stage = [tempname(folder), '.mat'];
            cleanup = onCleanup(@() BranchSolutionFile_v3.removeStage(stage));
            branch_index = struct('storage_version', 'BranchSolutionFile_v3:2', ...
                'metadata', metadata, 'points', {cell(0, 1)}, 'edges', {cell(0, 1)});
            save(stage, 'branch_index', '-v7');
            saved = BranchSolutionFile_v3.index(stage);
            BranchSolutionFile_v3.assertEqual(branch_index, saved, false, 0);
            BranchSolutionFile_v3.commit(stage, file);
            clear cleanup
        end

        function [branch_index, pointIndex] = append(file, orbit, report, pointMetadata)
            file = BranchSolutionFile_v3.fileName(file);
            branch_index = BranchSolutionFile_v3.index(file);
            assert(strcmp(class(orbit), 'HybridOrbit_v3') && isscalar(orbit), ...
                'BranchSolutionFile_v3:Orbit', 'Each point requires one native HybridOrbit_v3.');
            BranchSolutionFile_v3.validateValue(orbit, true, 0);
            BranchSolutionFile_v3.validateValue(report, false, 0);
            BranchSolutionFile_v3.validatePointMetadata(pointMetadata);
            pointIndex = numel(branch_index.points) + 1;
            identity = char(pointMetadata.component_identity);
            previousOrder = 0;
            for k = 1:numel(branch_index.points)
                if strcmp(branch_index.points{k}.component_identity, identity)
                    previousOrder = branch_index.points{k}.order;
                end
            end
            if isfield(pointMetadata, 'order')
                order = pointMetadata.order;
            else
                order = previousOrder + 1;
            end
            BranchSolutionFile_v3.positiveIndex(order);
            assert(order > previousOrder, 'BranchSolutionFile_v3:Order', ...
                'Point order must increase within its component.');
            edgeEnabled = isfield(pointMetadata, 'edge_enabled') && pointMetadata.edge_enabled;
            hasFrom = isfield(pointMetadata, 'edge_from') && ~isempty(pointMetadata.edge_from);
            assert(edgeEnabled == hasFrom, 'BranchSolutionFile_v3:Edge', ...
                'An edge requires edge_enabled=true and one existing edge_from point.');
            if edgeEnabled
                from = pointMetadata.edge_from;
                BranchSolutionFile_v3.positiveIndex(from);
                assert(from < pointIndex && ...
                    strcmp(branch_index.points{from}.component_identity, identity), ...
                    'BranchSolutionFile_v3:Edge', 'Edges join existing points in the same component.');
                branch_index.edges{end + 1, 1} = struct('from', from, ...
                    'to', pointIndex, 'component_identity', identity);
            end
            solutionName = sprintf('solution_%06d', pointIndex);
            reportName = sprintf('report_%06d', pointIndex);
            branch_index.points{end + 1, 1} = struct('index', pointIndex, ...
                'component_identity', identity, 'order', order, ...
                'classification', char(pointMetadata.classification), ...
                'nativeE', pointMetadata.nativeE, 'signedmeanU', pointMetadata.signedmeanU, ...
                'provenance', pointMetadata.provenance, 'metadata', pointMetadata, ...
                'solution_variable', solutionName, 'report_variable', reportName, ...
                'whole_public_data_readback_verified', true);
            stage = [tempname(fileparts(file)), '.mat'];
            cleanup = onCleanup(@() BranchSolutionFile_v3.removeStage(stage));
            [copied, message] = copyfile(file, stage);
            assert(copied, 'BranchSolutionFile_v3:Copy', '%s', message);
            payload = struct('branch_index', branch_index);
            payload.(solutionName) = orbit;
            payload.(reportName) = report;
            save(stage, '-struct', 'payload', '-append');
            saved = load(stage, solutionName, reportName);
            BranchSolutionFile_v3.assertEqual(orbit, saved.(solutionName), true, 0);
            BranchSolutionFile_v3.assertEqual(report, saved.(reportName), false, 0);
            savedIndex = BranchSolutionFile_v3.index(stage);
            BranchSolutionFile_v3.assertEqual(branch_index, savedIndex, false, 0);
            BranchSolutionFile_v3.commit(stage, file);
            clear cleanup
        end

        function [branch_index, pointIndices] = appendBatch(file, orbits, reports, pointMetadata)
            %APPENDBATCH Append one ordered batch in a single transaction.
            % All inputs are equally sized column cells. edge_from uses the
            % absolute file index and may name an earlier point in this batch.
            % An empty column-cell batch validates the file and does not write.
            % One writer owns the file; pending admissions remain the caller's
            % responsibility until the returned commit is independently read.
            file = BranchSolutionFile_v3.fileName(file);
            branch_index = BranchSolutionFile_v3.index(file);
            assert(iscell(orbits) && ismatrix(orbits) && size(orbits, 2) == 1 && ...
                iscell(reports) && isequal(size(reports), size(orbits)) && ...
                iscell(pointMetadata) && isequal(size(pointMetadata), size(orbits)), ...
                'BranchSolutionFile_v3:Batch', 'Batch inputs must be equal-sized column cells.');
            count = numel(orbits);
            pointIndices = numel(branch_index.points) + (1:count).';
            if count == 0, return; end
            payload = struct();
            for k = 1:count
                orbit = orbits{k};
                report = reports{k};
                metadata = pointMetadata{k};
                assert(strcmp(class(orbit), 'HybridOrbit_v3') && isscalar(orbit), ...
                    'BranchSolutionFile_v3:Orbit', 'Each point requires one native HybridOrbit_v3.');
                BranchSolutionFile_v3.validateValue(orbit, true, 0);
                BranchSolutionFile_v3.validateValue(report, false, 0);
                BranchSolutionFile_v3.validatePointMetadata(metadata);
                pointIndex = pointIndices(k);
                identity = char(metadata.component_identity);
                previousOrder = 0;
                for j = 1:numel(branch_index.points)
                    if strcmp(branch_index.points{j}.component_identity, identity)
                        previousOrder = branch_index.points{j}.order;
                    end
                end
                if isfield(metadata, 'order'), order = metadata.order;
                else, order = previousOrder + 1; end
                BranchSolutionFile_v3.positiveIndex(order);
                assert(order > previousOrder, 'BranchSolutionFile_v3:Order', ...
                    'Point order must increase within its component.');
                edgeEnabled = isfield(metadata, 'edge_enabled') && metadata.edge_enabled;
                hasFrom = isfield(metadata, 'edge_from') && ~isempty(metadata.edge_from);
                assert(edgeEnabled == hasFrom, 'BranchSolutionFile_v3:Edge', ...
                    'An edge requires edge_enabled=true and one existing edge_from point.');
                if edgeEnabled
                    from = metadata.edge_from;
                    BranchSolutionFile_v3.positiveIndex(from);
                    assert(from < pointIndex && ...
                        strcmp(branch_index.points{from}.component_identity, identity), ...
                        'BranchSolutionFile_v3:Edge', 'Edges join existing points in the same component.');
                    branch_index.edges{end + 1, 1} = struct('from', from, ...
                        'to', pointIndex, 'component_identity', identity);
                end
                solutionName = sprintf('solution_%06d', pointIndex);
                reportName = sprintf('report_%06d', pointIndex);
                branch_index.points{end + 1, 1} = struct('index', pointIndex, ...
                    'component_identity', identity, 'order', order, ...
                    'classification', char(metadata.classification), ...
                    'nativeE', metadata.nativeE, 'signedmeanU', metadata.signedmeanU, ...
                    'provenance', metadata.provenance, 'metadata', metadata, ...
                    'solution_variable', solutionName, 'report_variable', reportName, ...
                    'whole_public_data_readback_verified', true);
                payload.(solutionName) = orbit;
                payload.(reportName) = report;
            end
            BranchSolutionFile_v3.validateIndex(branch_index);
            payload.branch_index = branch_index;
            stage = [tempname(fileparts(file)), '.mat'];
            cleanup = onCleanup(@() BranchSolutionFile_v3.removeStage(stage));
            [copied, message] = copyfile(file, stage);
            assert(copied, 'BranchSolutionFile_v3:Copy', '%s', message);
            save(stage, '-struct', 'payload', '-append');
            names = fieldnames(payload);
            saved = load(stage, names{:});
            for k = 1:count
                solutionName = sprintf('solution_%06d', pointIndices(k));
                reportName = sprintf('report_%06d', pointIndices(k));
                BranchSolutionFile_v3.assertEqual(orbits{k}, saved.(solutionName), true, 0);
                BranchSolutionFile_v3.assertEqual(reports{k}, saved.(reportName), false, 0);
            end
            savedIndex = BranchSolutionFile_v3.index(stage);
            BranchSolutionFile_v3.assertEqual(branch_index, saved.branch_index, false, 0);
            BranchSolutionFile_v3.assertEqual(branch_index, savedIndex, false, 0);
            BranchSolutionFile_v3.commit(stage, file);
            clear cleanup
        end

        function branch_index = index(file)
            file = BranchSolutionFile_v3.fileName(file);
            BranchSolutionFile_v3.requireV7(file);
            saved = load(file, 'branch_index');
            assert(isfield(saved, 'branch_index'), ...
                'BranchSolutionFile_v3:Index', 'The file has no branch_index.');
            branch_index = saved.branch_index;
            BranchSolutionFile_v3.validateIndex(branch_index);
            variables = whos('-file', file);
            expected = cell(1 + 2 * numel(branch_index.points), 1);
            expected{1} = 'branch_index';
            for k = 1:numel(branch_index.points)
                expected{2 * k} = branch_index.points{k}.solution_variable;
                expected{2 * k + 1} = branch_index.points{k}.report_variable;
            end
            assert(isequal(sort({variables.name}.'), sort(expected)), ...
                'BranchSolutionFile_v3:Variables', 'The top-level variables disagree with the index.');
            for k = 1:numel(branch_index.points)
                item = variables(strcmp({variables.name}, branch_index.points{k}.solution_variable));
                assert(strcmp(item.class, 'HybridOrbit_v3') && isequal(item.size, [1, 1]), ...
                    'BranchSolutionFile_v3:Orbit', 'Every indexed solution must be one native HybridOrbit_v3.');
            end
        end

        function [orbits, reports, pointMetadata] = loadSolutions(file, pointIndices)
            %LOADSOLUTIONS Validate the index once, then load selected points.
            % Results are column cells in requested order. Repeated indices
            % refer to the same objects in this one native load; use separate
            % calls when independent deserialization is required.
            file = BranchSolutionFile_v3.fileName(file);
            branch_index = BranchSolutionFile_v3.index(file);
            assert(isnumeric(pointIndices) && isreal(pointIndices) && ...
                (isvector(pointIndices) || isempty(pointIndices)), ...
                'BranchSolutionFile_v3:Bounds', ...
                'Point indices must be a real numeric vector.');
            pointIndices = pointIndices(:);
            count = numel(pointIndices);
            orbits = cell(count, 1);
            reports = cell(count, 1);
            pointMetadata = cell(count, 1);
            variables = cell(count * (1 + double(nargout > 1)), 1);
            variableIndex = 0;
            for k = 1:count
                BranchSolutionFile_v3.positiveIndex(pointIndices(k));
                assert(pointIndices(k) <= numel(branch_index.points), ...
                    'BranchSolutionFile_v3:Bounds', 'Point index is outside this file.');
                point = branch_index.points{pointIndices(k)};
                variableIndex = variableIndex + 1;
                variables{variableIndex} = point.solution_variable;
                if nargout > 1
                    variableIndex = variableIndex + 1;
                    variables{variableIndex} = point.report_variable;
                end
            end
            if count == 0, return; end
            saved = load(file, variables{:});
            for k = 1:count
                point = branch_index.points{pointIndices(k)};
                orbit = saved.(point.solution_variable);
                assert(strcmp(class(orbit), 'HybridOrbit_v3') && isscalar(orbit), ...
                    'BranchSolutionFile_v3:Orbit', 'The saved solution is not one native HybridOrbit_v3.');
                BranchSolutionFile_v3.validateValue(orbit, true, 0);
                orbits{k} = orbit;
                if nargout > 1
                    report = saved.(point.report_variable);
                    BranchSolutionFile_v3.validateValue(report, false, 0);
                    reports{k} = report;
                end
                if nargout > 2, pointMetadata{k} = point.metadata; end
            end
        end

        function [orbit, report, pointMetadata] = loadSolution(file, pointIndex)
            file = BranchSolutionFile_v3.fileName(file);
            branch_index = BranchSolutionFile_v3.index(file);
            BranchSolutionFile_v3.positiveIndex(pointIndex);
            assert(pointIndex <= numel(branch_index.points), ...
                'BranchSolutionFile_v3:Bounds', 'Point index is outside this file.');
            point = branch_index.points{pointIndex};
            saved = load(file, point.solution_variable);
            orbit = saved.(point.solution_variable);
            assert(strcmp(class(orbit), 'HybridOrbit_v3') && isscalar(orbit), ...
                'BranchSolutionFile_v3:Orbit', 'The saved solution is not one native HybridOrbit_v3.');
            BranchSolutionFile_v3.validateValue(orbit, true, 0);
            if nargout > 1
                savedReport = load(file, point.report_variable);
                report = savedReport.(point.report_variable);
                BranchSolutionFile_v3.validateValue(report, false, 0);
            end
            if nargout > 2, pointMetadata = point.metadata; end
        end
    end

    methods (Static, Access = private)
        function file = fileName(file)
            BranchSolutionFile_v3.textScalar(file);
            file = char(java.io.File(char(file)).getCanonicalPath());
            [~, ~, extension] = fileparts(file);
            assert(strcmpi(extension, '.mat'), ...
                'BranchSolutionFile_v3:Path', 'The branch file must end in .mat.');
        end

        function textScalar(value)
            assert((ischar(value) && isrow(value)) || (isstring(value) && isscalar(value)), ...
                'BranchSolutionFile_v3:Text', 'Expected nonempty scalar text.');
            assert(~ismissing(string(value)) && strlength(strtrim(string(value))) > 0, ...
                'BranchSolutionFile_v3:Text', 'Expected nonempty scalar text.');
        end

        function positiveIndex(value)
            assert(isnumeric(value) && isreal(value) && isscalar(value) && ...
                isfinite(value) && value >= 1 && value == fix(value) && value <= flintmax, ...
                'BranchSolutionFile_v3:Bounds', 'Expected one positive integer index.');
        end

        function validatePointMetadata(value)
            required = {'component_identity', 'classification', 'nativeE', 'signedmeanU', 'provenance'};
            assert(isstruct(value) && isscalar(value) && all(isfield(value, required)), ...
                'BranchSolutionFile_v3:Metadata', 'Point metadata lacks a required field.');
            BranchSolutionFile_v3.textScalar(value.component_identity);
            BranchSolutionFile_v3.textScalar(value.classification);
            for name = {'nativeE', 'signedmeanU'}
                number = value.(name{1});
                assert(isnumeric(number) && isreal(number) && isscalar(number) && ...
                    (isfinite(number) || isnan(number)), ...
                    'BranchSolutionFile_v3:Metadata', 'Energy and signed mean speed are scalars; NaN means unknown.');
            end
            assert(isstruct(value.provenance) && isscalar(value.provenance), ...
                'BranchSolutionFile_v3:Metadata', 'Provenance must be a scalar struct.');
            if isfield(value, 'edge_enabled')
                assert(islogical(value.edge_enabled) && isscalar(value.edge_enabled), ...
                    'BranchSolutionFile_v3:Edge', 'edge_enabled must be a logical scalar.');
            end
            BranchSolutionFile_v3.validateValue(value, false, 0);
        end

        function validateIndex(value)
            assert(isstruct(value) && isscalar(value) && ...
                isequal(sort(fieldnames(value)), sort({'storage_version'; 'metadata'; 'points'; 'edges'})) && ...
                strcmp(value.storage_version, 'BranchSolutionFile_v3:2') && ...
                isstruct(value.metadata) && isscalar(value.metadata) && ...
                iscell(value.points) && ismatrix(value.points) && size(value.points, 2) == 1 && ...
                iscell(value.edges) && ismatrix(value.edges) && size(value.edges, 2) == 1, ...
                'BranchSolutionFile_v3:Index', 'Unsupported or malformed branch_index.');
            BranchSolutionFile_v3.validateValue(value, false, 0);
            lastOrder = containers.Map('KeyType', 'char', 'ValueType', 'double');
            for k = 1:numel(value.points)
                point = value.points{k};
                required = {'index', 'component_identity', 'order', 'classification', ...
                    'nativeE', 'signedmeanU', 'provenance', 'metadata', ...
                    'solution_variable', 'report_variable', 'whole_public_data_readback_verified'};
                assert(isstruct(point) && isscalar(point) && all(isfield(point, required)), ...
                    'BranchSolutionFile_v3:Index', 'Malformed point row.');
                BranchSolutionFile_v3.validatePointMetadata(point.metadata);
                BranchSolutionFile_v3.positiveIndex(point.order);
                assert(isequal(point.index, k) && ...
                    strcmp(point.solution_variable, sprintf('solution_%06d', k)) && ...
                    strcmp(point.report_variable, sprintf('report_%06d', k)) && ...
                    isequal(point.whole_public_data_readback_verified, true) && ...
                    strcmp(point.component_identity, char(point.metadata.component_identity)) && ...
                    strcmp(point.classification, char(point.metadata.classification)) && ...
                    isequaln(point.nativeE, point.metadata.nativeE) && ...
                    isequaln(point.signedmeanU, point.metadata.signedmeanU) && ...
                    isequaln(point.provenance, point.metadata.provenance), ...
                    'BranchSolutionFile_v3:Index', 'Point row disagrees with its original metadata.');
                previous = 0;
                if isKey(lastOrder, point.component_identity)
                    previous = lastOrder(point.component_identity);
                end
                assert(point.order > previous, ...
                    'BranchSolutionFile_v3:Order', 'Component point order must increase.');
                if isfield(point.metadata, 'order')
                    assert(isequaln(point.order, point.metadata.order), ...
                        'BranchSolutionFile_v3:Order', 'The original explicit point order must be retained.');
                else
                    assert(point.order == previous + 1, ...
                        'BranchSolutionFile_v3:Order', 'An implicit order must follow its own component.');
                end
                lastOrder(point.component_identity) = double(point.order);
            end
            seen = false(numel(value.points), 1);
            for k = 1:numel(value.edges)
                edge = value.edges{k};
                assert(isstruct(edge) && isscalar(edge) && all(isfield(edge, {'from', 'to', 'component_identity'})), ...
                    'BranchSolutionFile_v3:Edge', 'Malformed edge row.');
                BranchSolutionFile_v3.positiveIndex(edge.from);
                BranchSolutionFile_v3.positiveIndex(edge.to);
                assert(edge.from < edge.to && edge.to <= numel(value.points) && ~seen(edge.to), ...
                    'BranchSolutionFile_v3:Edge', 'Edges require distinct bounded point indices.');
                target = value.points{edge.to};
                assert(strcmp(value.points{edge.from}.component_identity, target.component_identity) && ...
                    strcmp(edge.component_identity, target.component_identity) && ...
                    isfield(target.metadata, 'edge_enabled') && isequal(target.metadata.edge_enabled, true) && ...
                    isfield(target.metadata, 'edge_from') && isequal(target.metadata.edge_from, edge.from), ...
                    'BranchSolutionFile_v3:Edge', 'An edge must match the target point explicit edge metadata.');
                seen(edge.to) = true;
            end
            for k = 1:numel(value.points)
                metadata = value.points{k}.metadata;
                enabled = isfield(metadata, 'edge_enabled') && metadata.edge_enabled;
                hasFrom = isfield(metadata, 'edge_from') && ~isempty(metadata.edge_from);
                assert(enabled == hasFrom && enabled == seen(k), ...
                    'BranchSolutionFile_v3:Edge', 'Every explicit edge has exactly one index row.');
            end
        end

        function validateValue(value, allowNative, depth)
            assert(depth <= 128, 'BranchSolutionFile_v3:Depth', ...
                'Cyclic or excessively nested data is unsupported.');
            if isnumeric(value) || islogical(value) || ischar(value) || isstring(value)
                return
            elseif iscell(value)
                for k = 1:numel(value)
                    BranchSolutionFile_v3.validateValue(value{k}, allowNative, depth + 1);
                end
            elseif isstruct(value)
                names = fieldnames(value);
                for k = 1:numel(value)
                    for j = 1:numel(names)
                        BranchSolutionFile_v3.validateValue(value(k).(names{j}), allowNative, depth + 1);
                    end
                end
            elseif allowNative && any(strcmp(class(value), {'HybridOrbit_v3', 'Trajectory_v3'}))
                names = properties(value);
                for k = 1:numel(value)
                    for j = 1:numel(names)
                        BranchSolutionFile_v3.validateValue(value(k).(names{j}), true, depth + 1);
                    end
                end
            else
                error('BranchSolutionFile_v3:ValueClass', ...
                    'Unsupported data class %s; reports and metadata must contain plain data.', class(value));
            end
        end

        function assertEqual(original, saved, allowNative, depth)
            assert(depth <= 128 && strcmp(class(original), class(saved)) && ...
                isequal(size(original), size(saved)), ...
                'BranchSolutionFile_v3:Readback', 'Readback class, shape or nesting differs.');
            if isnumeric(original) || islogical(original)
                assert(issparse(original) == issparse(saved) && isreal(original) == isreal(saved) && ...
                    isequaln(original, saved), 'BranchSolutionFile_v3:Readback', 'Readback values or storage type differ.');
            elseif ischar(original) || isstring(original)
                assert(isequaln(original, saved), ...
                    'BranchSolutionFile_v3:Readback', 'Readback text values differ.');
            elseif iscell(original)
                for k = 1:numel(original)
                    BranchSolutionFile_v3.assertEqual(original{k}, saved{k}, allowNative, depth + 1);
                end
            elseif isstruct(original)
                names = fieldnames(original);
                assert(isequal(names, fieldnames(saved)), ...
                    'BranchSolutionFile_v3:Readback', 'Readback struct fields differ.');
                for k = 1:numel(original)
                    for j = 1:numel(names)
                        BranchSolutionFile_v3.assertEqual(original(k).(names{j}), saved(k).(names{j}), allowNative, depth + 1);
                    end
                end
            else
                assert(allowNative && any(strcmp(class(original), {'HybridOrbit_v3', 'Trajectory_v3'})), ...
                    'BranchSolutionFile_v3:Readback', 'Unexpected readback object class.');
                names = sort(properties(original));
                assert(isequal(names, sort(properties(saved))), ...
                    'BranchSolutionFile_v3:Readback', 'Readback public properties differ.');
                for k = 1:numel(original)
                    for j = 1:numel(names)
                        BranchSolutionFile_v3.assertEqual(original(k).(names{j}), saved(k).(names{j}), true, depth + 1);
                    end
                end
            end
        end

        function requireV7(file)
            fid = fopen(file, 'r');
            assert(fid >= 0, 'BranchSolutionFile_v3:Missing', 'Cannot read the branch file.');
            cleanup = onCleanup(@() fclose(fid));
            header = fread(fid, 128, '*uint8');
            assert(numel(header) == 128 && startsWith(char(header(1:116).'), 'MATLAB 5.0 MAT-file'), ...
                'BranchSolutionFile_v3:Version', 'A compressed Level 5 v7 branch file is required.');
            endian = char(header(127:128).');
            assert(any(strcmp(endian, {'IM', 'MI'})), ...
                'BranchSolutionFile_v3:Version', 'Invalid MAT-file byte-order marker.');
            if strcmp(endian, 'IM'), machine = 'ieee-le'; else, machine = 'ieee-be'; end
            firstType = fread(fid, 1, 'uint32', 0, machine);
            assert(isequal(firstType, 15), ...
                'BranchSolutionFile_v3:Version', 'The MAT file must begin with a compressed data element.');
            clear cleanup
        end

        function commit(stage, file)
            options = javaArray('java.nio.file.CopyOption', 2);
            options(1) = javaMethod('valueOf', 'java.nio.file.StandardCopyOption', 'ATOMIC_MOVE');
            options(2) = javaMethod('valueOf', 'java.nio.file.StandardCopyOption', 'REPLACE_EXISTING');
            javaMethod('move', 'java.nio.file.Files', java.io.File(stage).toPath(), ...
                java.io.File(file).toPath(), options);
        end

        function removeStage(stage)
            if isfile(stage), delete(stage); end
        end
    end
end
