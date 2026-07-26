function reports = round1FiniteDifferenceJacobian(fun, z, relativeSteps)
%ROUND1FINITEDIFFERENCEJACOBIAN Multi-step central-difference rank audit.
%   REPORTS records the unscaled, row-normalized, and column-normalized
%   singular spectra. Column steps are relative to max(1,abs(z(j))).

    if nargin < 3 || isempty(relativeSteps)
        relativeSteps = [1e-4, 1e-5, 1e-6];
    end

    z = z(:);
    f0 = fun(z);
    f0 = f0(:);
    reports = repmat(struct( ...
        'relative_step', [], ...
        'absolute_steps', [], ...
        'jacobian', [], ...
        'singular_values', [], ...
        'absolute_rank_threshold', [], ...
        'relative_rank_threshold', [], ...
        'rank_threshold', [], ...
        'rank', [], ...
        'nullity', [], ...
        'right_null_vector', [], ...
        'row_normalized_singular_values', [], ...
        'row_normalized_rank', [], ...
        'column_normalized_singular_values', [], ...
        'column_normalized_rank', []), numel(relativeSteps), 1);

    for iStep = 1:numel(relativeSteps)
        relativeStep = relativeSteps(iStep);
        absoluteSteps = relativeStep * max(1, abs(z));
        jacobian = zeros(numel(f0), numel(z));

        for j = 1:numel(z)
            zPlus = z;
            zMinus = z;
            zPlus(j) = zPlus(j) + absoluteSteps(j);
            zMinus(j) = zMinus(j) - absoluteSteps(j);
            fPlus = fun(zPlus);
            fMinus = fun(zMinus);
            jacobian(:, j) = (fPlus(:) - fMinus(:)) / (2 * absoluteSteps(j));
        end

        [~, singularValuesMatrix, rightVectors] = svd(jacobian, 'econ');
        singularValues = diag(singularValuesMatrix);
        if isempty(singularValues)
            largestSingularValue = 0;
        else
            largestSingularValue = singularValues(1);
        end
        absoluteThreshold = 1e-10;
        relativeThreshold = max(size(jacobian)) * eps(max(1, largestSingularValue));
        rankThreshold = max(absoluteThreshold, relativeThreshold);
        numericalRank = sum(singularValues > rankThreshold);

        rowNorms = vecnorm(jacobian, 2, 2);
        rowScale = max(rowNorms, sqrt(eps));
        rowNormalized = jacobian ./ rowScale;
        rowSingularValues = svd(rowNormalized, 'econ');
        rowRankThreshold = max(absoluteThreshold, ...
            max(size(rowNormalized)) * eps(max(1, rowSingularValues(1))));

        columnNorms = vecnorm(jacobian, 2, 1);
        columnScale = max(columnNorms, sqrt(eps));
        columnNormalized = jacobian ./ columnScale;
        columnSingularValues = svd(columnNormalized, 'econ');
        columnRankThreshold = max(absoluteThreshold, ...
            max(size(columnNormalized)) * eps(max(1, columnSingularValues(1))));

        reports(iStep).relative_step = relativeStep;
        reports(iStep).absolute_steps = absoluteSteps;
        reports(iStep).jacobian = jacobian;
        reports(iStep).singular_values = singularValues;
        reports(iStep).absolute_rank_threshold = absoluteThreshold;
        reports(iStep).relative_rank_threshold = relativeThreshold;
        reports(iStep).rank_threshold = rankThreshold;
        reports(iStep).rank = numericalRank;
        reports(iStep).nullity = numel(z) - numericalRank;
        reports(iStep).right_null_vector = rightVectors(:, end);
        reports(iStep).row_normalized_singular_values = rowSingularValues;
        reports(iStep).row_normalized_rank = sum(rowSingularValues > rowRankThreshold);
        reports(iStep).column_normalized_singular_values = columnSingularValues;
        reports(iStep).column_normalized_rank = ...
            sum(columnSingularValues > columnRankThreshold);
    end
end
