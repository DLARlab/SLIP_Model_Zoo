function WriteFloquetAuditTable(filename, value, overwrite)
%WRITEFLOQUETAUDITTABLE Atomically write a derived flat CSV audit view.

    if ~istable(value)
        error('TemplateExperiment:AuditTable', ...
            'The derived audit value must be a table.');
    end
    folder = fileparts(filename);
    if ~isempty(folder) && ~isfolder(folder)
        mkdir(folder);
    end
    temporary = [tempname(ChooseFolder(folder)), '.csv'];
    cleanup = onCleanup(@() DeleteIfPresent(temporary));
    writetable(value, temporary);
    if overwrite
        [ok, message] = movefile(temporary, filename, 'f');
    else
        [ok, message] = movefile(temporary, filename);
    end
    if ~ok
        error('TemplateExperiment:AuditSaveFailed', '%s', message);
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
