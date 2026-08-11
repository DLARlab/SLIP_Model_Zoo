function handles = updateIndicators( ...
        plusAxes, unitAxes, data, index, handles)
%UPDATEFLOQUETINDICATORPLOTS Update reusable Floquet-distance plots.
%
%   The +1 and unit-circle distances are displayed on logarithmic axes.
%   The selected point and the finite global minimum are highlighted.

    if nargin < 5 || isempty(handles)
        handles = struct();
    end
    if ~isgraphics(plusAxes, 'axes') || ~isgraphics(unitAxes, 'axes')
        error('UpdateFloquetIndicatorPlots:InvalidAxes', ...
            'Two valid MATLAB axes or UIAxes handles are required.');
    end
    count = numel(data.branch_index);
    index = ValidateIndex(index, count);
    if ~isstruct(handles) || ~isfield(handles, 'plus_line') || ...
            ~isgraphics(handles.plus_line)
        handles = InitializePlots(plusAxes, unitAxes);
    end

    branchIndex = data.branch_index(:).';
    plus = data.distance_plus_one(:).';
    unit = data.unit_circle_distance(:).';
    plusVisual = PositiveForLogScale(plus);
    unitVisual = PositiveForLogScale(unit);

    [lineIndex, plusLine] = BreakAtIndexGaps(branchIndex, plusVisual);
    [~, unitLine] = BreakAtIndexGaps(branchIndex, unitVisual);
    handles.plus_line.XData = lineIndex;
    handles.plus_line.YData = plusLine;
    handles.unit_line.XData = lineIndex;
    handles.unit_line.YData = unitLine;
    handles.plus_current.XData = branchIndex(index);
    handles.plus_current.YData = plusVisual(index);
    handles.unit_current.XData = branchIndex(index);
    handles.unit_current.YData = unitVisual(index);

    [plusMinimum, plusIndex] = FiniteMinimum(plus);
    [unitMinimum, unitIndex] = FiniteMinimum(unit);
    SetMinimum(handles.plus_minimum, branchIndex, plusMinimum, plusIndex);
    SetMinimum(handles.unit_minimum, branchIndex, unitMinimum, unitIndex);
    title(plusAxes, sprintf('+1 distance | current %.3e', plus(index)));
    title(unitAxes, sprintf('Unit-circle distance | current %.3e', unit(index)));
end

function handles = InitializePlots(plusAxes, unitAxes)
    cla(plusAxes, 'reset');
    cla(unitAxes, 'reset');
    hold(plusAxes, 'on');
    hold(unitAxes, 'on');
    handles = struct();
    handles.plus_line = semilogy(plusAxes, NaN, NaN, '.-', ...
        'Color', [0.85 0.33 0.10], 'LineWidth', 1.5, ...
        'MarkerSize', 7, ...
        'Tag', 'FloquetPlusOneDistanceLine');
    handles.plus_minimum = semilogy(plusAxes, NaN, NaN, 'v', ...
        'LineStyle', 'none', 'MarkerFaceColor', [0.9290 0.6940 0.1250], ...
        'Color', [0.85 0.33 0.10], 'MarkerSize', 8, ...
        'Tag', 'FloquetPlusOneDistanceMinimum');
    handles.plus_current = semilogy(plusAxes, NaN, NaN, 'o', ...
        'LineStyle', 'none', 'MarkerFaceColor', [0.4660 0.6740 0.1880], ...
        'Color', [0.1 0.1 0.1], 'MarkerSize', 8, ...
        'Tag', 'FloquetPlusOneDistanceCurrent');
    handles.unit_line = semilogy(unitAxes, NaN, NaN, '.-', ...
        'Color', [0.00 0.50 0.35], 'LineWidth', 1.5, ...
        'MarkerSize', 7, ...
        'Tag', 'FloquetUnitCircleDistanceLine');
    handles.unit_minimum = semilogy(unitAxes, NaN, NaN, 'd', ...
        'LineStyle', 'none', 'MarkerFaceColor', [0.00 0.50 0.35], ...
        'Color', [0.00 0.35 0.25], 'MarkerSize', 8, ...
        'Tag', 'FloquetUnitCircleDistanceMinimum');
    handles.unit_current = semilogy(unitAxes, NaN, NaN, 'o', ...
        'LineStyle', 'none', 'MarkerFaceColor', [0.4660 0.6740 0.1880], ...
        'Color', [0.1 0.1 0.1], 'MarkerSize', 8, ...
        'Tag', 'FloquetUnitCircleDistanceCurrent');
    xlabel(plusAxes, 'Branch index');
    ylabel(plusAxes, 'd_{+1}', 'Interpreter', 'tex');
    xlabel(unitAxes, 'Branch index');
    ylabel(unitAxes, 'd_u', 'Interpreter', 'tex');
    grid(plusAxes, 'on');
    grid(unitAxes, 'on');
    hold(plusAxes, 'off');
    hold(unitAxes, 'off');
    try
        axtoolbar(plusAxes, {});
        axtoolbar(unitAxes, {});
    catch
    end
end

function SetMinimum(handle, branchIndex, value, index)
    if isempty(index)
        handle.XData = NaN;
        handle.YData = NaN;
    else
        handle.XData = branchIndex(index);
        handle.YData = max(value, eps);
    end
end

function values = PositiveForLogScale(values)
    finite = isfinite(values);
    values(finite) = max(values(finite), eps);
    values(~finite) = NaN;
end

function [value, index] = FiniteMinimum(values)
    valid = find(isfinite(values));
    if isempty(valid)
        value = NaN;
        index = [];
        return;
    end
    [value, local] = min(values(valid));
    index = valid(local);
end

function index = ValidateIndex(index, count)
    if ~(isnumeric(index) && isscalar(index) && isfinite(index))
        error('UpdateFloquetIndicatorPlots:InvalidIndex', ...
            'Index must be a finite numeric scalar.');
    end
    index = round(index);
    if index < 1 || index > count
        error('UpdateFloquetIndicatorPlots:IndexOutOfRange', ...
            'Index must be between 1 and %d.', count);
    end
end

function [xOut, yOut] = BreakAtIndexGaps(x, y)
    if numel(x) < 2
        xOut = x;
        yOut = y;
        return;
    end
    gaps = find(diff(x) ~= 1);
    xOut = x;
    yOut = y;
    for i = numel(gaps):-1:1
        insertAt = gaps(i) + 1;
        xOut = [xOut(1:insertAt-1), NaN, xOut(insertAt:end)];
        yOut = [yOut(1:insertAt-1), NaN, yOut(insertAt:end)];
    end
end
