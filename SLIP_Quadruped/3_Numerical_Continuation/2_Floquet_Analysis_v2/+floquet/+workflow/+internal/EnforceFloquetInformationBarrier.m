function EnforceFloquetInformationBarrier(config, stageName)
%ENFORCEFLOQUETINFORMATIONBARRIER Reject held-out inputs before Stage 5.
%
% Passing one configuration object is convenient, but stages 1--4 must not
% silently receive known daughter files or a held-out validation callback.
% This guard turns that convention into an executable contract.

    if nargin < 2 || isempty(stageName)
        stageName = 'this pre-validation stage';
    end
    if ~isstruct(config) || ~isscalar(config) || ...
            ~isfield(config, 'Validation') || isempty(config.Validation)
        return
    end
    validation = config.Validation;
    if ~isstruct(validation) || ~isscalar(validation)
        error('TemplateExperiment:ValidationConfiguration', ...
            'config.Validation must be a scalar structure.');
    end
    hasReferences = isfield(validation, ...
        'ReferenceDaughterBranchFiles') && ...
        ~isempty(validation.ReferenceDaughterBranchFiles);
    hasCallback = isfield(validation, 'Function') && ...
        ~isempty(validation.Function);
    if hasReferences || hasCallback
        error('TemplateExperiment:InformationBarrier', [ ...
            '%s cannot receive held-out daughter paths or a validation ' ...
            'callback. Keep config.Validation empty through stages 1--4, ' ...
            'then create a Stage-5-only config after predictions are frozen.'], ...
            char(string(stageName)));
    end
end
