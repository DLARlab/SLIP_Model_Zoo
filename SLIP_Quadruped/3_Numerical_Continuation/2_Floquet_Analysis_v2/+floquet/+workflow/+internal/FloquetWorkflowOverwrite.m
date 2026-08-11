function overwrite = FloquetWorkflowOverwrite(config)
%FLOQUETWORKFLOWOVERWRITE Resolve the explicit stage-artifact policy.

    overwrite = false;
    if isfield(config, 'OverwriteResults')
        value = config.OverwriteResults;
        if ~(isscalar(value) && (islogical(value) || ...
                (isnumeric(value) && isfinite(value) && any(value == [0 1]))))
            error('TemplateExperiment:OverwriteResults', ...
                'OverwriteResults must be scalar logical.');
        end
        overwrite = logical(value);
    end
end
