function selections = NormalizeFloquetRaySelections( ...
        selections, seedReport, sourceSeedSHA256)
%NORMALIZEFLOQUETRAYSELECTIONS Validate explicit two-seed continuation rays.
%
% Each selection is bound to the current seed artifact and contains:
%   RayID, SeedAttemptIndices, SeedAmplitudes, SourceSeedSHA256.
% Extra fields are retained for forward-compatible GUI annotations.

    if istable(selections)
        selections = table2struct(selections);
    end
    if ~isstruct(selections) || isempty(selections)
        error('FloquetWorkflow:RaySelectionContract', ...
            'At least one signed-ray selection struct is required.');
    end
    if ~isstruct(seedReport) || ~isscalar(seedReport) || ...
            ~isfield(seedReport, 'Attempts') || ...
            ~isstruct(seedReport.Attempts)
        error('FloquetWorkflow:SeedReportContract', ...
            'The validated seed report must contain a struct array Attempts.');
    end
    sourceSeedSHA256 = lower(strtrim(char(string(sourceSeedSHA256))));
    if isempty(regexp(sourceSeedSHA256, '^[0-9a-f]{64}$', 'once'))
        error('FloquetWorkflow:SeedArtifactSHA256', ...
            'The current seed artifact identity must be a SHA-256 digest.');
    end

    attempts = seedReport.Attempts;
    selections = selections(:).';
    rayIDs = strings(1, numel(selections));
    for k = 1:numel(selections)
        selection = selections(k);
        RequireField(selection, 'RayID');
        RequireField(selection, 'SeedAttemptIndices');
        rayID = ScalarText(selection.RayID, 'RayID');
        indices = selection.SeedAttemptIndices;
        if ~(isnumeric(indices) && isreal(indices) && ...
                numel(indices) == 2 && all(isfinite(indices)) && ...
                all(indices == floor(indices)) && ...
                all(indices >= 1) && all(indices <= numel(attempts)) && ...
                numel(unique(indices)) == 2)
            error('FloquetWorkflow:RaySelectionContract', [ ...
                'SeedAttemptIndices for %s must contain exactly two ' ...
                'distinct valid integer indices.'], rayID);
        end
        indices = reshape(indices, 1, []);
        chosen = attempts(indices);
        if ~all(arrayfun(@AttemptAccepted, chosen))
            error('FloquetWorkflow:RaySelectionRejectedSeed', ...
                'Every selected seed attempt for %s must be accepted.', rayID);
        end
        actualRayIDs = arrayfun(@AttemptRayID, chosen, ...
            'UniformOutput', false);
        if ~all(strcmp(actualRayIDs, rayID))
            error('FloquetWorkflow:RaySelectionMixedRay', [ ...
                'Selected attempts for %s must share that candidate, ' ...
                'direction, and sign.'], rayID);
        end
        amplitudes = arrayfun(@AttemptAmplitude, chosen);
        if any(amplitudes <= 0) || numel(unique(amplitudes)) ~= 2
            error('FloquetWorkflow:RaySelectionAmplitude', ...
                ['The two seeds for %s must use distinct positive ' ...
                'amplitudes.'], rayID);
        end
        [amplitudes, order] = sort(amplitudes);
        indices = indices(order);

        if isfield(selection, 'SeedAmplitudes') && ...
                ~isempty(selection.SeedAmplitudes)
            configured = selection.SeedAmplitudes;
            if ~(isnumeric(configured) && isreal(configured) && ...
                    numel(configured) == 2 && all(isfinite(configured)))
                error('FloquetWorkflow:RaySelectionAmplitude', ...
                    'SeedAmplitudes for %s must contain two finite values.', ...
                    rayID);
            end
            configured = sort(reshape(configured, 1, []));
            tolerance = 32 * eps(max(1, max(abs(amplitudes))));
            if any(abs(configured - amplitudes) > tolerance)
                error('FloquetWorkflow:RaySelectionAmplitude', [ ...
                    'SeedAmplitudes for %s do not match the selected ' ...
                    'attempt records.'], rayID);
            end
        end
        if isfield(selection, 'SourceSeedSHA256') && ...
                ~isempty(selection.SourceSeedSHA256)
            configuredSHA = strtrim(char(string( ...
                selection.SourceSeedSHA256)));
            if ~strcmpi(configuredSHA, sourceSeedSHA256)
                error('FloquetWorkflow:RaySelectionStale', ...
                    'Ray %s was selected from a different seed artifact.', ...
                    rayID);
            end
        end

        selections(k).RayID = rayID;
        selections(k).SeedAttemptIndices = indices;
        selections(k).SeedAmplitudes = amplitudes;
        selections(k).SourceSeedSHA256 = sourceSeedSHA256;
        rayIDs(k) = string(rayID);
    end
    if numel(unique(rayIDs)) ~= numel(rayIDs)
        error('FloquetWorkflow:DuplicateRaySelection', ...
            'Each signed RayID may be selected only once.');
    end
end

function RequireField(value, field)
    if ~isfield(value, field)
        error('FloquetWorkflow:RaySelectionContract', ...
            'Every ray selection must contain field %s.', field);
    end
end

function value = ScalarText(value, label)
    if ~(ischar(value) || (isstring(value) && isscalar(value)))
        error('FloquetWorkflow:RaySelectionContract', ...
            '%s must be scalar text.', label);
    end
    value = strtrim(char(string(value)));
    if isempty(value)
        error('FloquetWorkflow:RaySelectionContract', ...
            '%s must not be empty.', label);
    end
end

function accepted = AttemptAccepted(attempt)
    accepted = isfield(attempt, 'Accepted') && ...
        isscalar(attempt.Accepted) && ...
        (islogical(attempt.Accepted) || ...
         (isnumeric(attempt.Accepted) && isreal(attempt.Accepted) && ...
          isfinite(attempt.Accepted) && any(attempt.Accepted == [0 1]))) && ...
        logical(attempt.Accepted);
end

function amplitude = AttemptAmplitude(attempt)
    if ~isfield(attempt, 'Amplitude') || ...
            ~(isnumeric(attempt.Amplitude) && isreal(attempt.Amplitude) && ...
              isscalar(attempt.Amplitude) && isfinite(attempt.Amplitude))
        error('FloquetWorkflow:SeedReportContract', ...
            'Every selectable seed attempt must have a finite Amplitude.');
    end
    amplitude = attempt.Amplitude;
end

function rayID = AttemptRayID(attempt)
    required = {'CandidateID', 'DirectionID', 'Sign'};
    for k = 1:numel(required)
        if ~isfield(attempt, required{k})
            error('FloquetWorkflow:SeedReportContract', ...
                'Seed attempt is missing field %s.', required{k});
        end
    end
    candidateID = ScalarText(attempt.CandidateID, 'CandidateID');
    directionID = ScalarText(attempt.DirectionID, 'DirectionID');
    signValue = attempt.Sign;
    if ~(isnumeric(signValue) && isreal(signValue) && ...
            isscalar(signValue) && isfinite(signValue) && signValue ~= 0)
        error('FloquetWorkflow:SeedReportContract', ...
            'Every selectable seed attempt must have a nonzero finite Sign.');
    end
    rayID = sprintf('%s__%s__sign_%+d', ...
        candidateID, directionID, sign(signValue));
end
