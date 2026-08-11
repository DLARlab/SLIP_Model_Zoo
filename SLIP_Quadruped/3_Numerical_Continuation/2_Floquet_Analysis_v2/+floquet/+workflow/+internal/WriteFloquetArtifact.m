function WriteFloquetArtifact(filename, payload, overwrite)
%WRITEFLOQUETARTIFACT Atomically save named variables from a scalar struct.

    if ~isstruct(payload) || ~isscalar(payload) || isempty(fieldnames(payload))
        error('TemplateExperiment:ArtifactPayload', ...
            'Artifact payload must be a nonempty scalar struct.');
    end
    folder = fileparts(filename);
    if ~isempty(folder) && ~isfolder(folder)
        mkdir(folder);
    end
    temporary = [tempname(ChooseFolder(folder)), '.mat'];
    cleanup = onCleanup(@() DeleteIfPresent(temporary));
    save(temporary, '-struct', 'payload', '-v7.3');
    if overwrite
        [ok, message] = movefile(temporary, filename, 'f');
    else
        [ok, message] = movefile(temporary, filename);
    end
    if ~ok
        error('TemplateExperiment:ArtifactSaveFailed', '%s', message);
    end
    clear cleanup
end

function folder = ChooseFolder(folder)
    if isempty(folder)
        folder = pwd;
    end
end

function DeleteIfPresent(filename)
    if isfile(filename)
        delete(filename);
    end
end
