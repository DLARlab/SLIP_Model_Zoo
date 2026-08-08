function [perturbedState, info] = ApplySectionPerturbation(baseState, direction, step)
%APPLYSECTIONPERTURBATION Perturb only independent apex-section states.
%
%   XP = APPLYSECTIONPERTURBATION(X, DELTAQ) adds the 12-vector DELTAQ to
%   X([1 2 4:13]).
%
%   XP = APPLYSECTIONPERTURBATION(X, I, H) perturbs reduced coordinate I by
%   H.  XP = APPLYSECTIONPERTURBATION(X, V, H) applies H*V, where V is a
%   12-vector.  X(3)=dy is copied exactly and is never perturbed.

    if ~isnumeric(baseState) || ~isvector(baseState) || ...
            numel(baseState) ~= 13 || any(~isfinite(baseState(:)))
        error('ApplySectionPerturbation:InvalidBaseState', ...
            'baseState must be a finite 13-element model state.');
    end
    if nargin < 2 || ~isnumeric(direction) || isempty(direction) || ...
            any(~isfinite(direction(:)))
        error('ApplySectionPerturbation:InvalidDirection', ...
            'direction must be a finite reduced coordinate or vector.');
    end

    if nargin < 3
        if numel(direction) ~= 12
            error('ApplySectionPerturbation:InvalidDelta', ...
                'The two-input form requires a 12-element reduced delta.');
        end
        reducedDelta = direction(:);
    else
        if ~(isnumeric(step) && isscalar(step) && isfinite(step))
            error('ApplySectionPerturbation:InvalidStep', ...
                'step must be a finite scalar.');
        end
        if isscalar(direction) && direction == fix(direction) && ...
                direction >= 1 && direction <= 12
            reducedDelta = zeros(12,1);
            reducedDelta(direction) = step;
        elseif numel(direction) == 12
            reducedDelta = step .* direction(:);
        else
            error('ApplySectionPerturbation:InvalidDirectionSize', ...
                'direction must be an index from 1 to 12 or a 12-vector.');
        end
    end

    reducedIndices = [1 2 4:13];
    perturbedState = baseState(:);
    normalCoordinate = perturbedState(3);
    perturbedState(reducedIndices) = ...
        perturbedState(reducedIndices) + reducedDelta;
    perturbedState(3) = normalCoordinate;

    if any(~isfinite(perturbedState))
        error('ApplySectionPerturbation:NonfiniteResult', ...
            'The requested perturbation produced a nonfinite state.');
    end

    info = struct();
    info.reducedDelta = reducedDelta;
    info.reducedStateIndices = reducedIndices(:);
    info.sectionNormalIndex = 3;
    info.sectionNormalBefore = normalCoordinate;
    info.sectionNormalAfter = perturbedState(3);
    info.sectionConstraintPreservedExactly = ...
        isequal(perturbedState(3), normalCoordinate);
end
