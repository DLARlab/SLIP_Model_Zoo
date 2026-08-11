function [handles, plotInfo] = updateSpectrum( ...
        ax, FloquetData, index, handles, options)
%UPDATEFLOQUETPLOT Update the complex Floquet-multiplier plot in place.
%
%   HANDLES = UPDATEFLOQUETPLOT(AX, DATA, K) initializes the multiplier
%   plane and displays DATA.eigenvalues(:,K). Passing HANDLES from a prior
%   call updates persistent graphics instead of clearing the axes.
%
%   UPDATEFLOQUETPLOT(...,OPTIONS) accepts AxisMode='unit-circle'
%   (default) for a stable focused view, or AxisMode='fit-current' to fit
%   every finite multiplier at the selected branch point.

    if nargin < 4 || isempty(handles)
        handles = struct();
    end
    if nargin < 5 || isempty(options)
        options = struct();
    end
    options = ResolvePlotOptions(options);
    if ~isgraphics(ax, 'axes')
        error('UpdateFloquetPlot:InvalidAxes', ...
            'A valid MATLAB axes or UIAxes handle is required.');
    end
    pointCount = numel(FloquetData.branch_index);
    index = ValidateIndex(index, pointCount);
    modeCount = size(FloquetData.eigenvalues, 1);
    if NeedsInitialization(handles, modeCount)
        handles = InitializePlot(ax, modeCount);
    end

    values = FloquetData.eigenvalues(:, index);
    finiteMask = isfinite(real(values)) & isfinite(imag(values));
    modeIndices = find(finiteMask);
    finiteValues = values(finiteMask);
    conjugatePairs = ResolveConjugatePairs(FloquetData, index, values);
    modeColorKeys = (1:modeCount).';
    for pairIndex = 1:size(conjugatePairs, 1)
        pair = conjugatePairs(pairIndex, :);
        modeColorKeys(pair) = min(pair);
    end
    visibleColorKeys = modeColorKeys(finiteMask);
    visibleColors = handles.mode_palette(visibleColorKeys, :);
    set(handles.multipliers, 'XData', real(finiteValues), ...
        'YData', imag(finiteValues), 'CData', visibleColors);

    plotInfo = struct('local_index', index, ...
        'branch_index', FloquetData.branch_index(index), ...
        'continuation_parameter', ...
            FloquetData.continuation_parameter(index), ...
        'accepted', IsAccepted(FloquetData, index), ...
        'closest_plus_one_mode', NaN, ...
        'closest_plus_one_value', complex(NaN, NaN), ...
        'closest_minus_one_mode', NaN, ...
        'closest_minus_one_value', complex(NaN, NaN), ...
        'mode_indices', modeIndices, ...
        'mode_color_keys', modeColorKeys, ...
        'visible_mode_color_keys', visibleColorKeys, ...
        'mode_colors', visibleColors, ...
        'conjugate_pairs', conjugatePairs, ...
        'axis_mode', options.AxisMode, ...
        'axis_limit', options.UnitCircleLimit, ...
        'off_scale_count', 0, ...
        'maximum_modulus', NaN);

    if isempty(finiteValues)
        SetMarker(handles.closest_plus_one, complex(NaN, NaN));
        SetMarker(handles.closest_minus_one, complex(NaN, NaN));
    else
        [~, plusLocal] = min(abs(finiteValues - 1));
        [~, minusLocal] = min(abs(finiteValues + 1));
        plusValue = finiteValues(plusLocal);
        minusValue = finiteValues(minusLocal);
        SetMarker(handles.closest_plus_one, plusValue);
        SetMarker(handles.closest_minus_one, minusValue);
        plotInfo.closest_plus_one_mode = modeIndices(plusLocal);
        plotInfo.closest_plus_one_value = plusValue;
        plotInfo.closest_minus_one_mode = modeIndices(minusLocal);
        plotInfo.closest_minus_one_value = minusValue;
    end

    maxRadius = NaN;
    if ~isempty(finiteValues)
        maxRadius = max(abs(finiteValues));
        plotInfo.maximum_modulus = maxRadius;
    end
    if strcmp(options.AxisMode, 'fit-current')
        fitRadius = max(1, maxRadius);
        if ~isfinite(fitRadius)
            fitRadius = 1;
        end
        limit = max(options.UnitCircleLimit, ...
            options.FitMargin * fitRadius);
    else
        limit = options.UnitCircleLimit;
    end
    plotInfo.axis_limit = limit;
    if ~isempty(finiteValues)
        offScale = abs(real(finiteValues)) > limit | ...
            abs(imag(finiteValues)) > limit;
        plotInfo.off_scale_count = nnz(offScale);
    end
    handles.guides.real_axis.XData = [-limit limit];
    handles.guides.imaginary_axis.YData = [-limit limit];
    axis(ax, 'equal');
    xlim(ax, [-limit limit]);
    ylim(ax, [-limit limit]);

    if plotInfo.accepted
        status = 'accepted';
    else
        status = 'rejected';
    end
    titleText = sprintf('Floquet multipliers | branch index %d | %s', ...
        plotInfo.branch_index, status);
    if plotInfo.off_scale_count > 0
        titleText = sprintf('%s | %d off-scale | max |lambda| %.4g', ...
            titleText, plotInfo.off_scale_count, plotInfo.maximum_modulus);
    end
    title(ax, titleText, 'Interpreter', 'none');
end

function options = ResolvePlotOptions(supplied)
    options = struct('AxisMode', 'unit-circle', ...
        'UnitCircleLimit', 1.25, 'FitMargin', 1.15);
    if ~isstruct(supplied) || ~isscalar(supplied)
        error('UpdateFloquetPlot:InvalidOptions', ...
            'OPTIONS must be a scalar structure.');
    end
    suppliedNames = fieldnames(supplied);
    allowedNames = fieldnames(options);
    for i = 1:numel(suppliedNames)
        match = find(strcmpi(suppliedNames{i}, allowedNames), 1);
        if isempty(match)
            error('UpdateFloquetPlot:UnknownOption', ...
                'Unknown option ''%s''.', suppliedNames{i});
        end
        options.(allowedNames{match}) = supplied.(suppliedNames{i});
    end
    mode = options.AxisMode;
    if isstring(mode) && isscalar(mode)
        mode = char(mode);
    end
    if ~ischar(mode)
        error('UpdateFloquetPlot:InvalidAxisMode', ...
            'AxisMode must be ''unit-circle'' or ''fit-current''.');
    end
    mode = lower(strtrim(mode));
    if ~any(strcmp(mode, {'unit-circle', 'fit-current'}))
        error('UpdateFloquetPlot:InvalidAxisMode', ...
            'AxisMode must be ''unit-circle'' or ''fit-current''.');
    end
    options.AxisMode = mode;
    ValidatePositiveScalar(options.UnitCircleLimit, ...
        'UnitCircleLimit');
    ValidatePositiveScalar(options.FitMargin, 'FitMargin');
    if options.UnitCircleLimit <= 1
        error('UpdateFloquetPlot:InvalidUnitCircleLimit', ...
            'UnitCircleLimit must be greater than 1.');
    end
    if options.FitMargin < 1
        error('UpdateFloquetPlot:InvalidFitMargin', ...
            'FitMargin must be at least 1.');
    end
end

function ValidatePositiveScalar(value, name)
    if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
            value > 0)
        error('UpdateFloquetPlot:InvalidOptionValue', ...
            '%s must be a positive finite scalar.', name);
    end
end

function handles = InitializePlot(ax, modeCount)
    cla(ax, 'reset');
    hold(ax, 'on');
    handles = struct();
    handles.guides = floquet.gui.plot.unitCircle(ax);
    handles.mode_palette = TrackedModePalette(modeCount);
    handles.mode_count = modeCount;
    handles.multipliers = scatter(ax, NaN, NaN, 42, ...
        handles.mode_palette(1, :), 'filled', ...
        'MarkerEdgeColor', [0.1 0.1 0.1], ...
        'DisplayName', 'tracked multipliers', ...
        'Tag', 'FloquetMultiplierScatter');
    handles.closest_plus_one = plot(ax, NaN, NaN, 'o', ...
        'Color', [0.85 0.33 0.10], 'MarkerSize', 12, ...
        'LineWidth', 2, 'DisplayName', 'closest to +1', ...
        'Tag', 'FloquetClosestPlusOne');
    handles.closest_minus_one = plot(ax, NaN, NaN, 's', ...
        'Color', [0.49 0.18 0.56], 'MarkerSize', 11, ...
        'LineWidth', 2, 'DisplayName', 'closest to -1', ...
        'Tag', 'FloquetClosestMinusOne');
    hold(ax, 'off');
    legend(ax, 'Location', 'best');
    try
        axtoolbar(ax, {});
    catch
    end
end

function palette = TrackedModePalette(modeCount)
    palette = [];
    if exist('orderedcolors', 'file') ~= 0
        try
            repositoryPalette = orderedcolors('gem12');
            if size(repositoryPalette, 1) >= modeCount
                palette = repositoryPalette(1:modeCount, :);
            end
        catch
        end
    end
    if isempty(palette)
        if exist('turbo', 'file') ~= 0
            palette = turbo(modeCount);
        else
            palette = hsv(modeCount);
        end
    end
end

function tf = NeedsInitialization(handles, modeCount)
    tf = ~isstruct(handles) || ~isfield(handles, 'multipliers') || ...
        ~isgraphics(handles.multipliers) || ...
        ~isfield(handles, 'mode_palette') || ...
        ~isequal(size(handles.mode_palette), [modeCount 3]) || ...
        ~isfield(handles, 'mode_count') || ...
        handles.mode_count ~= modeCount || ...
        ~isfield(handles, 'closest_plus_one') || ...
        ~isgraphics(handles.closest_plus_one) || ...
        ~isfield(handles, 'closest_minus_one') || ...
        ~isgraphics(handles.closest_minus_one);
end

function pairs = ResolveConjugatePairs(data, index, values)
    [pairs, hasTrackingMetadata] = TrackingConjugatePairs(data, index);
    if ~hasTrackingMetadata
        pairs = InferConjugatePairs(values);
    end
    pairs = ValidateConjugatePairs(pairs, numel(values));
end

function [pairs, found] = TrackingConjugatePairs(data, index)
    pairs = zeros(0, 2);
    found = false;
    if ~isfield(data, 'computation_info') || ...
            ~isfield(data.computation_info, 'tracking') || ...
            ~isstruct(data.computation_info.tracking)
        return;
    end
    tracking = data.computation_info.tracking;
    series = [];
    if isfield(tracking, 'ConjugateInfo')
        series = tracking.ConjugateInfo;
    elseif isfield(tracking, 'conjugate_info')
        series = tracking.conjugate_info;
    end
    if isempty(series)
        return;
    end
    if iscell(series)
        if numel(series) < index
            return;
        end
        pointInfo = series{index};
    elseif isstruct(series) && numel(series) >= index
        pointInfo = series(index);
    else
        return;
    end
    if ~isstruct(pointInfo) || ~isscalar(pointInfo)
        return;
    end
    if isfield(pointInfo, 'Pairs')
        pairs = pointInfo.Pairs;
        found = true;
    elseif isfield(pointInfo, 'pairs')
        pairs = pointInfo.pairs;
        found = true;
    end
end

function pairs = InferConjugatePairs(values)
    values = values(:);
    finite = isfinite(real(values)) & isfinite(imag(values));
    scale = max([1; abs(values(finite))]);
    realTolerance = 1e-10 * scale;
    pairTolerance = 1e-8;
    positive = find(finite & imag(values) > realTolerance);
    negative = find(finite & imag(values) < -realTolerance);
    pairs = zeros(0, 2);
    availableNegative = negative(:).';
    for positiveIndex = positive(:).'
        if isempty(availableNegative)
            break;
        end
        residual = abs(values(positiveIndex) - ...
            conj(values(availableNegative))) ./ ...
            (1 + max(abs(values(positiveIndex)), ...
            abs(values(availableNegative))));
        [minimumResidual, location] = min(residual);
        if minimumResidual <= pairTolerance
            pairs(end + 1, :) = [positiveIndex, ...
                availableNegative(location)]; %#ok<AGROW>
            availableNegative(location) = [];
        end
    end
end

function pairs = ValidateConjugatePairs(pairs, modeCount)
    if isempty(pairs)
        pairs = zeros(0, 2);
        return;
    end
    if ~(isnumeric(pairs) && size(pairs, 2) == 2 && ...
            all(isfinite(pairs), 'all') && ...
            all(pairs == round(pairs), 'all') && ...
            all(pairs >= 1, 'all') && all(pairs <= modeCount, 'all') && ...
            all(pairs(:, 1) ~= pairs(:, 2)))
        pairs = zeros(0, 2);
        return;
    end
    pairs = sort(round(pairs), 2);
    pairs = unique(pairs, 'rows', 'stable');
    used = false(modeCount, 1);
    keep = false(size(pairs, 1), 1);
    for pairIndex = 1:size(pairs, 1)
        pair = pairs(pairIndex, :);
        if ~any(used(pair))
            keep(pairIndex) = true;
            used(pair) = true;
        end
    end
    pairs = pairs(keep, :);
end

function SetMarker(handle, value)
    handle.XData = real(value);
    handle.YData = imag(value);
end

function accepted = IsAccepted(data, index)
    accepted = false;
    if isfield(data, 'computation_info') && ...
            isfield(data.computation_info, 'accepted') && ...
            numel(data.computation_info.accepted) >= index
        accepted = logical(data.computation_info.accepted(index));
    end
end

function index = ValidateIndex(index, count)
    if ~(isnumeric(index) && isscalar(index) && isfinite(index))
        error('UpdateFloquetPlot:InvalidIndex', ...
            'Index must be a finite numeric scalar.');
    end
    index = round(index);
    if index < 1 || index > count
        error('UpdateFloquetPlot:IndexOutOfRange', ...
            'Index must be between 1 and %d.', count);
    end
end
