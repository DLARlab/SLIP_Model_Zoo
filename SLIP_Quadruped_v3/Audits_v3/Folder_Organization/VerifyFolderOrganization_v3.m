function report = VerifyFolderOrganization_v3()
%VERIFYFOLDERORGANIZATION_V3 Audit relocation without rerunning numerics.
% Checks actual bytes, historical path resolution, saved solver-gate source
% epochs, and unchanged campaign checkpoints. Journal acceptance is explicitly
% an epoch check and does not itself prove numerical equivalence of source edits.
    root = V3Root_v3(mfilename('fullpath'));
    previousPath = path;
    restorePath = onCleanup(@() path(previousPath)); %#ok<NASGU>
    V3AddPaths_v3(root);
    auditDirectory = fullfile(root, 'Audits_v3', 'Folder_Organization');
    mapFile = fullfile(auditDirectory, 'locations.json');
    beforeFile = fullfile(auditDirectory, 'before_manifest.json');
    removedFile = fullfile(auditDirectory, 'removed_files.json');
    journalFile = fullfile(auditDirectory, 'source_relocations.json');
    locations = jsondecode(fileread(mapFile));
    before = jsondecode(fileread(beforeFile));
    removed = jsondecode(fileread(removedFile));
    assert(isfile(journalFile), 'VerifyFolderOrganization_v3:MissingJournal', ...
        'Complete the prospective source relocation journal before verification.');
    beforeHashes = containers.Map({before.files.path}, {before.files.sha256});
    removedPaths = {removed.files.path};
    mappedPaths = {locations.files.old_path};
    report = struct('schema_version', 'v3-folder-organization-verification-1', ...
        'checked_utc', char(datetime('now', 'TimeZone', 'UTC')), ...
        'matlab_version', version, 'platform', computer, ...
        'locations_sha256', RoundSHA256_v3(mapFile), ...
        'before_manifest_sha256', RoundSHA256_v3(beforeFile), ...
        'source_relocation_journal_sha256', RoundSHA256_v3(journalFile), ...
        'mapped_files', numel(locations.files), 'existing_files', 0, ...
        'verified_aliases', 0, 'scientific_files_checked', 0, ...
        'core_source_files_checked', 0, 'other_source_files_checked', 0, ...
        'journaled_source_matches', 0, 'numerical_maps_executed', 0, ...
        'campaign_checkpoint_writes', 0, 'passed', false);
    report.failures = struct('path', {}, 'reason', {}, 'expected_sha256', {}, 'actual_sha256', {});
    report.source_epoch_matches = struct('path', {}, 'match_kind', {}, ...
        'expected_sha256', {}, 'current_sha256', {});
    report.scope = ['Exact byte preservation establishes unchanged saved numerical evidence and core source. ', ...
        'Journaled source matches establish recorded original/current epochs only; ', ...
        'they do not independently certify numerical equivalence of path edits.'];

    unmapped = setdiff({before.files.path}, [mappedPaths, removedPaths]);
    for k = 1:numel(unmapped)
        report = failure(report, unmapped{k}, 'Retained baseline file is absent from the location map.', '', '');
    end
    for k = 1:numel(locations.directories)
        record = locations.directories(k);
        if ~isfolder(fullfile(root, record.new_path))
            report = failure(report, record.new_path, 'Mapped current directory is missing.', '', '');
        end
    end
    for k = 1:numel(locations.files)
        record = locations.files(k);
        current = fullfile(root, record.new_path);
        if ~isfile(current)
            report = failure(report, record.new_path, 'Mapped current file is missing.', record.sha256, '');
            continue;
        end
        report.existing_files = report.existing_files + 1;
        if ~isKey(beforeHashes, record.old_path) || ~strcmp(beforeHashes(record.old_path), record.sha256)
            report = failure(report, record.old_path, 'Location-map original hash disagrees with the baseline.', '', record.sha256);
        end
        historical = fullfile(root, record.old_path);
        if ~samePath(V3Path_v3(historical), current)
            report = failure(report, record.old_path, 'Historical location resolves to the wrong current file.', '', '');
        end
        if isfield(record, 'aliases')
            for j = 1:numel(record.aliases)
                alias = record.aliases{j};
                if samePath(V3Path_v3(fullfile(root, alias)), current)
                    report.verified_aliases = report.verified_aliases + 1;
                else
                    report = failure(report, alias, 'Historical alias resolves to the wrong current file.', '', '');
                end
            end
        end
        [~, ~, extension] = fileparts(record.old_path);
        isCore = ~isempty(regexp(record.old_path, ...
            '^(Schema_v3|Adapters_v3|Dynamics_v3|Simulation_v3|Orbit_v3|Numerics_v3|Stability_v3|Graphics_v3)/.*\.m$', 'once'));
        if any(strcmpi(extension, {'.mat', '.json', '.fig', '.png'})) || isCore
            actual = RoundSHA256_v3(current);
            if ~strcmp(actual, record.sha256)
                report = failure(report, record.old_path, 'Scientific artifact or core source bytes changed.', record.sha256, actual);
            end
            if isCore
                report.core_source_files_checked = report.core_source_files_checked + 1;
            else
                report.scientific_files_checked = report.scientific_files_checked + 1;
            end
        elseif strcmpi(extension, '.m')
            [matched, detail] = V3HashMatches_v3(record.sha256, current);
            report.other_source_files_checked = report.other_source_files_checked + 1;
            report.source_epoch_matches(end+1) = struct('path', record.new_path, ...
                'match_kind', detail.match_kind, 'expected_sha256', detail.expected_sha256, ...
                'current_sha256', detail.current_sha256); %#ok<AGROW>
            if ~matched
                report = failure(report, record.old_path, 'Changed non-core source lacks a verified relocation epoch.', record.sha256, detail.current_sha256);
            elseif strcmp(detail.match_kind, 'journaled_source_relocation')
                report.journaled_source_matches = report.journaled_source_matches + 1;
            end
        end
    end

    gateFile = V3Path_v3(fullfile(root, 'Research_v3', 'next_round', 'solver', 'solver_validation_summary.mat'));
    saved = load(gateFile, 'summary');
    gate = saved.summary;
    report.solver_gate_cases = numel(gate.cases);
    report.solver_gate_sources = numel(gate.source_hashes);
    report.solver_gate_source_bytes_match = true;
    if report.solver_gate_cases ~= 7 || ~gate.all_required_gates_passed || ~all([gate.cases.passed])
        report = failure(report, 'solver_validation_summary.mat', 'The saved seven required gates are not all passing.', '', '');
    end
    if report.solver_gate_sources ~= 7
        report = failure(report, 'solver_validation_summary.mat', 'Expected seven saved canonical source hashes.', '', '');
    end
    for k = 1:numel(gate.source_hashes)
        source = gate.source_hashes(k);
        current = V3Path_v3(fullfile(root, source.path));
        actual = RoundSHA256_v3(current);
        if ~strcmp(actual, source.sha256)
            report.solver_gate_source_bytes_match = false;
            report = failure(report, source.path, 'Saved canonical solver gate no longer matches exact source bytes.', source.sha256, actual);
        end
    end

    report.campaign_checkpoints = struct('profile', {}, 'sha256', {}, 'status', {}, ...
        'numerical_wall_seconds', {}, 'function_evaluations', {}, 'total_wall_seconds', {}, ...
        'total_function_evaluations', {}, 'task_count', {}, 'unfinished_tasks', {});
    for profile = {'full', 'validation'}
        relative = ['Research_v3/next_round/checkpoint_', profile{1}, '.mat'];
        current = V3Path_v3(fullfile(root, relative));
        actual = RoundSHA256_v3(current);
        if ~isKey(beforeHashes, relative) || ~strcmp(beforeHashes(relative), actual)
            report = failure(report, relative, 'Campaign checkpoint bytes changed during organization.', '', actual);
        end
        saved = load(current, 'state');
        state = saved.state;
        report.campaign_checkpoints(end+1) = struct('profile', profile{1}, 'sha256', actual, ...
            'status', state.status, 'numerical_wall_seconds', state.numerical_wall_seconds, ...
            'function_evaluations', state.function_evaluations, ...
            'total_wall_seconds', state.config.budgets.total_wall_seconds, ...
            'total_function_evaluations', state.config.budgets.total_function_evaluations, ...
            'task_count', numel(state.tasks), 'unfinished_tasks', sum(~[state.tasks.execution_completed])); %#ok<AGROW>
    end

    oldGlob = 'Research_v3/next_round/tasks/full/*/continuation.json';
    expected = regexptranslate('wildcard', oldGlob);
    expectedRows = find(~cellfun('isempty', regexp(mappedPaths, ['^', expected, '$'], 'once')));
    listing = V3Dir_v3(fullfile(root, oldGlob));
    actualPaths = arrayfun(@(item) canonical(fullfile(item.folder, item.name)), listing, 'UniformOutput', false);
    expectedPaths = arrayfun(@(index) canonical(fullfile(root, locations.files(index).new_path)), expectedRows, 'UniformOutput', false);
    report.historical_continuation_glob = struct('pattern', oldGlob, 'expected_count', numel(expectedPaths), ...
        'actual_count', numel(actualPaths), 'expected_six', numel(expectedPaths) == 6, ...
        'passed', numel(expectedPaths) == 6 && numel(actualPaths) == 6 && ...
            isequal(sort(actualPaths(:)), sort(expectedPaths(:))), 'current_paths', {actualPaths});
    if ~report.historical_continuation_glob.passed
        report = failure(report, oldGlob, 'Historical continuation glob did not find precisely the six retained continuations.', '', '');
    end
    report.passed = isempty(report.failures);
    RoundJSON_v3(fullfile(auditDirectory, 'report.json'), report);
    fprintf('Folder organization audit: passed=%d; %d files; %d scientific artifacts; %d core sources; %d journaled source epochs; %d failures.\n', ...
        report.passed, report.existing_files, report.scientific_files_checked, ...
        report.core_source_files_checked, report.journaled_source_matches, numel(report.failures));
    assert(report.passed, 'VerifyFolderOrganization_v3:Failed', ...
        'Organization verification failed; inspect Audits_v3/Folder_Organization/report.json.');
end

function report = failure(report, file, reason, expected, actual)
    report.failures(end+1) = struct('path', file, 'reason', reason, ...
        'expected_sha256', expected, 'actual_sha256', actual);
end

function matched = samePath(first, second)
    matched = strcmp(canonical(first), canonical(second));
end

function value = canonical(value)
    value = char(java.io.File(char(value)).getCanonicalPath());
end
