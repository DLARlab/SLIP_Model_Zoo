function catalog = InspectFloquetDaughterRays(config)
%INSPECTFLOQUETDAUGHTERRAYS List corrected signed rays eligible for Stage 4.
%
%   CATALOG = INSPECTFLOQUETDAUGHTERRAYS(CONFIG) validates the artifact
%   chain through Stage 3 and returns a GUI-friendly, read-only catalog.
%   AcceptedAttemptIndices index seedReport.Attempts directly.  A Stage-4
%   RaySelection must explicitly choose exactly two of those indices and
%   repeat CATALOG.SourceSeedSHA256.

    if nargin < 1 || ~isstruct(config) || ~isscalar(config) || ...
            ~isfield(config, 'Files') || ~isfield(config.Files, 'Seeds')
        error('TemplateExperiment:InvalidConfiguration', ...
            'A scalar workflow config with Files.Seeds is required.');
    end
    floquet.workflow.internal.AddFloquetNumericalPaths(config);
    chain = floquet.workflow.internal.ValidateFloquetArtifactChain(config, 'seeds');
    loaded = load(config.Files.Seeds, 'seedReport');
    if ~isfield(loaded, 'seedReport') || ...
            ~isstruct(loaded.seedReport) || ...
            ~isscalar(loaded.seedReport) || ...
            ~isfield(loaded.seedReport, 'Attempts') || ...
            ~isstruct(loaded.seedReport.Attempts)
        error('TemplateExperiment:SeedReportContract', ...
            'Seed MAT file must contain scalar seedReport with Attempts.');
    end
    attempts = loaded.seedReport.Attempts;
    acceptedMask = false(1, numel(attempts));
    for k = 1:numel(attempts)
        acceptedMask(k) = StrictTrueField(attempts(k), 'Accepted');
        ValidateAttemptIdentity(attempts(k), k);
    end

    acceptedIndices = find(acceptedMask);
    rows = repmat(EmptyRow(), 1, 0);
    if ~isempty(acceptedIndices)
        keys = cell(1, numel(acceptedIndices));
        for k = 1:numel(acceptedIndices)
            keys{k} = RayKey(attempts(acceptedIndices(k)));
        end
        uniqueKeys = unique(keys, 'stable');
        rows = repmat(EmptyRow(), 1, numel(uniqueKeys));
        for k = 1:numel(uniqueKeys)
            memberIndices = acceptedIndices(strcmp(keys, uniqueKeys{k}));
            memberAttempts = attempts(memberIndices);
            amplitudes = [memberAttempts.Amplitude];
            [distinctAmplitudes, first] = unique(amplitudes, 'sorted');
            distinctIndices = memberIndices(first);
            row = EmptyRow();
            row.RayID = uniqueKeys{k};
            row.CandidateID = char(string(memberAttempts(1).CandidateID));
            row.DirectionID = char(string(memberAttempts(1).DirectionID));
            row.Sign = sign(memberAttempts(1).Sign);
            row.AcceptedAttemptIndices = memberIndices;
            row.AcceptedAmplitudes = amplitudes;
            row.DistinctAttemptIndices = distinctIndices;
            row.DistinctAmplitudes = distinctAmplitudes;
            row.Eligible = numel(distinctAmplitudes) >= 2;
            if row.Eligible
                row.Status = 'eligible-two-or-more-distinct-corrected-seeds';
                row.Message = ...
                    'Select exactly two distinct accepted attempts on this ray.';
            else
                row.Status = 'ineligible-insufficient-distinct-amplitudes';
                row.Message = ...
                    'At least two accepted, distinct amplitudes are required.';
            end
            rows(k) = row;
        end
    end

    catalog = struct();
    catalog.WorkflowStage = 'daughter-ray-selection-catalog';
    catalog.SourceSeedFile = chain.Seeds.CanonicalPath;
    catalog.SourceSeedSHA256 = chain.Seeds.SHA256;
    catalog.Rows = rows;
    catalog.EligibleRayIDs = {rows([rows.Eligible]).RayID};
    catalog.SelectionContract = struct( ...
        'RequiredFields', {{'RayID','SeedAttemptIndices', ...
            'SeedAmplitudes','SourceSeedSHA256'}}, ...
        'SeedAttemptCount', 2, ...
        'Description', [ ...
            'Each selection chooses two accepted, distinct-amplitude ' ...
            'attempts on one signed ray and is bound to this seed SHA-256.']);
end

function row = EmptyRow()
    row = struct('RayID', '', 'CandidateID', '', 'DirectionID', '', ...
        'Sign', NaN, 'AcceptedAttemptIndices', [], ...
        'AcceptedAmplitudes', [], 'DistinctAttemptIndices', [], ...
        'DistinctAmplitudes', [], 'Eligible', false, ...
        'Status', 'not-evaluated', 'Message', '');
end

function ValidateAttemptIdentity(attempt, index)
    requiredText = {'CandidateID','DirectionID'};
    for k = 1:numel(requiredText)
        field = requiredText{k};
        if ~isfield(attempt, field) || ~IsNonemptyScalarText(attempt.(field))
            error('TemplateExperiment:SeedReportContract', ...
                'Seed attempt %d has invalid %s.', index, field);
        end
    end
    if ~isfield(attempt, 'Sign') || ~isnumeric(attempt.Sign) || ...
            ~isreal(attempt.Sign) || ~isscalar(attempt.Sign) || ...
            ~isfinite(attempt.Sign) || attempt.Sign == 0
        error('TemplateExperiment:SeedReportContract', ...
            'Seed attempt %d has invalid nonzero Sign.', index);
    end
    if ~isfield(attempt, 'Amplitude') || ~isnumeric(attempt.Amplitude) || ...
            ~isreal(attempt.Amplitude) || ~isscalar(attempt.Amplitude) || ...
            ~isfinite(attempt.Amplitude) || attempt.Amplitude <= 0
        error('TemplateExperiment:SeedReportContract', ...
            'Seed attempt %d has invalid positive Amplitude.', index);
    end
end

function tf = StrictTrueField(source, field)
    tf = false;
    if ~isfield(source, field)
        return
    end
    value = source.(field);
    tf = isscalar(value) && isreal(value) && ...
        ((islogical(value) && value) || ...
         (isnumeric(value) && isfinite(value) && value == 1));
end

function key = RayKey(attempt)
    key = sprintf('%s__%s__sign_%+d', char(string(attempt.CandidateID)), ...
        char(string(attempt.DirectionID)), sign(attempt.Sign));
end

function tf = IsNonemptyScalarText(value)
    tf = (ischar(value) && isrow(value)) || ...
        (isstring(value) && isscalar(value));
    if tf
        tf = strlength(strtrim(string(value))) > 0;
    end
end
