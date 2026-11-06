function parameter=CatalogPhysicalParameter_v3(entry)
%CATALOGPHYSICALPARAMETER_V3 Validate exact p10 across MAT/JSON catalog paths.
% Explicit seventeen-digit tokens preserve Inf when JSON numeric null becomes
% NaN. A null without its explicit Inf token is never interpreted as inertia.
    if ~isstruct(entry)||~isscalar(entry)||~isfield(entry,'physical_parameter')
        error('CatalogPhysicalParameter_v3:Metadata','A scalar entry with physical_parameter is required.');
    end
    numeric=entry.physical_parameter(:);
    if isfield(entry,'physical_parameter_tokens')&&~isempty(entry.physical_parameter_tokens)
        tokens=entry.physical_parameter_tokens;
        if ~(iscellstr(tokens)||isstring(tokens))||numel(tokens)~=10
            error('CatalogPhysicalParameter_v3:Tokens','Exactly ten explicit parameter tokens are required.');
        end
        parameter=str2double(string(tokens(:)));
        if any(isnan(parameter))||numel(numeric)~=10||~isnumeric(numeric)||~isreal(numeric)
            error('CatalogPhysicalParameter_v3:Tokens','Invalid parameter token/numeric metadata.');
        end
        matches=(numeric==parameter)|(isnan(numeric)&isinf(parameter)&parameter>0);
        if ~all(matches)
            error('CatalogPhysicalParameter_v3:Mismatch','Parameter tokens differ from the numeric full p10 metadata.');
        end
    else
        parameter=numeric;
    end
    schema=QuadrupedSchema_v3.shared();parameter=schema.validateParameter(parameter);
end
