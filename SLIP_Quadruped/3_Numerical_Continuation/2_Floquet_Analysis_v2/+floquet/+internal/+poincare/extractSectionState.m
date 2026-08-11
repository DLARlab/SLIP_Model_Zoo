function [sectionState, info] = extractSectionState(state)
%EXTRACTSECTIONSTATE Remove translation and the apex-normal coordinate.
%
%   Q = EXTRACTSECTIONSTATE(X) accepts the 13-state model initial state X.
%   Q = EXTRACTSECTIONSTATE(YAPEX) also accepts a 14-state integrated row;
%   its horizontal position is first removed.  In both cases Q is a 12-by-1
%   vector ordered by full-X indices [1 2 4:13].

    if ~isnumeric(state) || ~isvector(state) || any(~isfinite(state(:)))
        error('ExtractSectionState:InvalidState', ...
            'state must be a finite numeric vector of length 13 or 14.');
    end

    input = state(:);
    if numel(input) == 13
        fullState = input;
        source = 'model-state-X';
        translationalCoordinate = [];
    elseif numel(input) == 14
        translationalCoordinate = input(1);
        fullState = input(2:14);
        source = 'integrated-state-Y';
    else
        error('ExtractSectionState:InvalidLength', ...
            'state must have length 13 (X) or 14 (integrated Y).');
    end

    reducedIndices = [1 2 4:13];
    sectionState = fullState(reducedIndices);

    info = struct();
    info.source = source;
    info.fullState = fullState;
    info.reducedStateIndices = reducedIndices(:);
    info.excludedSectionStateIndex = 3;
    info.excludedSectionStateValue = fullState(3);
    info.translationalCoordinate = translationalCoordinate;
end
