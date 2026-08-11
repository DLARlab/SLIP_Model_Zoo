function [steps, info] = scalePerturbation(sectionState, magnitudes, options)
%SCALEPERTURBATION Construct coordinate-scaled finite-difference steps.
%
%   STEPS = SCALEPERTURBATION(Q, MAGNITUDES, OPTIONS) returns a 12-by-L
%   matrix.  Entry (i,k) is
%
%       MAGNITUDES(k) * max(abs(Q(i)), OPTIONS.StateScale(i)).
%
%   Q is the reduced apex-section state ordered by X([1 2 4:13]).

    if nargin < 3
        options = struct();
    end
    options = floquet.internal.options.resolve(options);

    q = sectionState(:);
    if numel(q) ~= 12 || any(~isfinite(q))
        error('ScalePerturbation:InvalidSectionState', ...
            'sectionState must contain 12 finite reduced coordinates.');
    end

    if nargin < 2 || isempty(magnitudes)
        magnitudes = options.PerturbationMagnitudes;
    end
    magnitudes = magnitudes(:).';
    if isempty(magnitudes) || any(~isfinite(magnitudes)) || any(magnitudes <= 0)
        error('ScalePerturbation:InvalidMagnitudes', ...
            'magnitudes must contain positive finite values.');
    end

    characteristicScale = max(abs(q), options.StateScale);
    steps = characteristicScale * magnitudes;

    minimum = options.MinimumAbsoluteStep .* max(1, characteristicScale);
    clipped = steps < minimum;
    for k = 1:size(steps,2)
        steps(:,k) = max(steps(:,k), minimum);
    end

    info = struct();
    info.sectionState = q;
    info.characteristicScale = characteristicScale;
    info.relativeMagnitudes = magnitudes;
    info.steps = steps;
    info.minimumAbsoluteSteps = minimum;
    info.minimumStepApplied = clipped;
    info.reducedStateIndices = options.ReducedStateIndices(:);
end
