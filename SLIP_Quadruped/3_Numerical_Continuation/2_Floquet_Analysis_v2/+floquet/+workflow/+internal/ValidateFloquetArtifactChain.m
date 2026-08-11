function chain = ValidateFloquetArtifactChain(config, terminalStage)
%VALIDATEFLOQUETARTIFACTCHAIN Revalidate every current upstream handoff.
%
% TERMINALSTAGE is discovery, refinement, seeds, or daughters.  Validation
% always starts at the current parent file and recursively checks source path
% plus SHA-256 at every configured MAT artifact.  Replacing any upstream file
% after a downstream stage was frozen therefore fails closed.

    terminalStage = validatestring(char(string(terminalStage)), ...
        {'discovery','refinement','seeds','daughters'});
    RequireConfiguredFiles(config, terminalStage);
    [analysis, discoveryFile] = LoadVariable( ...
        config.Files.Discovery, 'analysis');
    [parentIdentity, authority] = ...
        floquet.workflow.internal.ValidateFloquetDiscoveryArtifact(analysis, config, true);

    chain = struct();
    chain.Parent = parentIdentity;
    chain.Discovery = ArtifactIdentity(discoveryFile);
    chain.DiscoveryAuthority = authority;
    if strcmp(terminalStage, 'discovery')
        return
    end

    [refinement, refinementFile] = LoadVariable( ...
        config.Files.Refinement, 'refinementReport');
    ValidateHandoff(refinement, 'SourceDiscoveryFile', ...
        'SourceDiscoverySHA256', discoveryFile, 'refinement');
    chain.Refinement = ArtifactIdentity(refinementFile);
    if strcmp(terminalStage, 'refinement')
        return
    end

    [seeds, seedFile] = LoadVariable(config.Files.Seeds, 'seedReport');
    ValidateHandoff(seeds, 'SourceRefinementFile', ...
        'SourceRefinementSHA256', refinementFile, 'seed');
    chain.Seeds = ArtifactIdentity(seedFile);
    if strcmp(terminalStage, 'seeds')
        return
    end

    [daughters, daughterFile] = LoadVariable( ...
        config.Files.Daughters, 'daughterReport');
    ValidateHandoff(daughters, 'SourceSeedFile', ...
        'SourceSeedSHA256', seedFile, 'daughter');
    ValidateDaughterRayHashes(daughters);
    chain.Daughters = ArtifactIdentity(daughterFile);
end

function ValidateDaughterRayHashes(report)
    if ~isfield(report, 'Records') || ~isstruct(report.Records)
        return
    end
    records = report.Records;
    for k = 1:numel(records)
        outputFile = OptionalText(records(k), 'OutputFile');
        outputHash = OptionalText(records(k), 'OutputSHA256');
        if isempty(outputFile)
            if ~isempty(outputHash)
                error('TemplateExperiment:ArtifactChainContract', ...
                    'Daughter record %d has OutputSHA256 but no OutputFile.', k);
            end
            continue
        end
        if ~isfile(outputFile)
            % Stage 5 retains missing/rejected output records as negative
            % evidence rather than turning the whole inventory unreadable.
            continue
        end
        outputFile = char(java.io.File(outputFile).getCanonicalPath());
        RequireSHA256(outputHash, sprintf( ...
            'daughter record %d OutputSHA256', k));
        currentHash = floquet.workflow.internal.FloquetFileSHA256(outputFile);
        if ~strcmpi(outputHash, currentHash)
            error('TemplateExperiment:ArtifactHashMismatch', [ ...
                'Daughter record %d branch artifact is stale or replaced: ' ...
                'saved %s, current %s (%s).'], ...
                k, outputHash, currentHash, outputFile);
        end
    end
end

function RequireConfiguredFiles(config, terminalStage)
    if ~isstruct(config) || ~isscalar(config) || ...
            ~isfield(config, 'Files') || ~isstruct(config.Files) || ...
            ~isscalar(config.Files)
        error('TemplateExperiment:ArtifactChainConfiguration', ...
            'Artifact-chain validation requires scalar config.Files.');
    end
    order = {'Discovery','Refinement','Seeds','Daughters'};
    count = find(strcmp({'discovery','refinement','seeds','daughters'}, ...
        terminalStage), 1);
    for k = 1:count
        field = order{k};
        if ~isfield(config.Files, field) || ...
                ~IsScalarText(config.Files.(field)) || ...
                isempty(strtrim(char(string(config.Files.(field)))))
            error('TemplateExperiment:ArtifactChainConfiguration', ...
                'config.Files.%s is required for this stage.', field);
        end
    end
end

function [value, filename] = LoadVariable(filename, variable)
    filename = CanonicalExistingFile(filename);
    loaded = load(filename, variable);
    if ~isfield(loaded, variable) || ~isstruct(loaded.(variable)) || ...
            ~isscalar(loaded.(variable))
        error('TemplateExperiment:ArtifactChainContract', ...
            '%s must contain one scalar %s struct.', filename, variable);
    end
    value = loaded.(variable);
end

function ValidateHandoff(report, pathField, hashField, expectedFile, label)
    if ~isfield(report, pathField) || ~IsScalarText(report.(pathField)) || ...
            isempty(strtrim(char(string(report.(pathField)))))
        error('TemplateExperiment:ArtifactChainContract', ...
            '%s report is missing %s.', label, pathField);
    end
    savedFile = CanonicalExistingFile(report.(pathField));
    if ~SamePath(savedFile, expectedFile)
        error('TemplateExperiment:ArtifactSourcePathMismatch', [ ...
            '%s report points to %s, but the current configured upstream ' ...
            'artifact is %s.'], label, savedFile, expectedFile);
    end
    if ~isfield(report, hashField) || ~IsScalarText(report.(hashField))
        error('TemplateExperiment:ArtifactChainContract', ...
            '%s report is missing %s.', label, hashField);
    end
    savedHash = lower(strtrim(char(string(report.(hashField)))));
    RequireSHA256(savedHash, sprintf('%s report field %s', label, hashField));
    currentHash = floquet.workflow.internal.FloquetFileSHA256(expectedFile);
    if ~strcmp(savedHash, currentHash)
        error('TemplateExperiment:ArtifactHashMismatch', [ ...
            '%s report is stale: %s saved %s but the current upstream ' ...
            'artifact hashes to %s.'], label, hashField, savedHash, currentHash);
    end
end

function RequireSHA256(value, label)
    if isempty(regexp(value, '^[0-9a-fA-F]{64}$', 'once'))
        error('TemplateExperiment:ArtifactChainContract', ...
            '%s is not a SHA-256 digest.', label);
    end
end

function value = OptionalText(source, field)
    value = '';
    if isstruct(source) && isscalar(source) && isfield(source, field) && ...
            IsScalarText(source.(field))
        value = strtrim(char(string(source.(field))));
    end
end

function identity = ArtifactIdentity(filename)
    identity = struct('CanonicalPath', filename, ...
        'SHA256', floquet.workflow.internal.FloquetFileSHA256(filename));
end

function filename = CanonicalExistingFile(filename)
    if ~IsScalarText(filename)
        error('TemplateExperiment:ArtifactChainPath', ...
            'Artifact paths must be character vectors or scalar strings.');
    end
    filename = char(string(filename));
    if ~isfile(filename)
        error('TemplateExperiment:MissingStageArtifact', ...
            'Required stage artifact is missing: %s', filename);
    end
    filename = char(java.io.File(filename).getCanonicalPath());
end

function tf = SamePath(left, right)
    if ispc
        tf = strcmpi(left, right);
    else
        tf = strcmp(left, right);
    end
end

function tf = IsScalarText(value)
    tf = ischar(value) || (isstring(value) && isscalar(value));
end
