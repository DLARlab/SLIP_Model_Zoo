function [handles, plotInfo] = updateBranch( ...
        ax, FloquetData, index, handles)
%UPDATEBRANCHPLOT Update a continuation branch and Floquet candidates.
%
%   The horizontal coordinate is the original continuation branch index;
%   the vertical coordinate is DATA.continuation_parameter. Gaps in a
%   sparsely sampled branch are not joined by a line.

    if nargin < 4 || isempty(handles)
        handles = struct();
    end
    if ~isgraphics(ax, 'axes')
        error('UpdateBranchPlot:InvalidAxes', ...
            'A valid MATLAB axes or UIAxes handle is required.');
    end
    pointCount = numel(FloquetData.branch_index);
    index = ValidateIndex(index, pointCount);
    if NeedsInitialization(handles)
        handles = InitializePlot(ax, FloquetData);
    end

    branchIndex = FloquetData.branch_index(:).';
    coordinate = FloquetData.continuation_parameter(:).';
    [lineX, lineY] = BreakAtIndexGaps(branchIndex, coordinate);
    handles.branch.XData = lineX;
    handles.branch.YData = lineY;

    indicators = FloquetData.bifurcation_indicator;
    plusMask = logical([indicators.candidate_plus_one]);
    minusMask = logical([indicators.candidate_minus_one]);
    unitMask = logical([indicators.candidate_unit_circle]);
    handles.plus_candidates.XData = branchIndex(plusMask);
    handles.plus_candidates.YData = coordinate(plusMask);
    handles.minus_candidates.XData = branchIndex(minusMask);
    handles.minus_candidates.YData = coordinate(minusMask);
    handles.unit_candidates.XData = branchIndex(unitMask);
    handles.unit_candidates.YData = coordinate(unitMask);

    accepted = IsAccepted(FloquetData, index);
    handles.current.XData = branchIndex(index);
    handles.current.YData = coordinate(index);

    rejected = ~AcceptedVector(FloquetData, pointCount);
    handles.rejected.XData = branchIndex(rejected);
    handles.rejected.YData = coordinate(rejected);

    parameterName = 'continuation parameter';
    if isfield(FloquetData, 'continuation_parameter_name') && ...
            ~isempty(FloquetData.continuation_parameter_name)
        parameterName = char(string( ...
            FloquetData.continuation_parameter_name));
    end
    xlabel(ax, 'Branch index');
    ylabel(ax, parameterName, 'Interpreter', 'none');
    title(ax, sprintf('Solution branch | current index %d', ...
        branchIndex(index)), 'Interpreter', 'none');
    grid(ax, 'on');
    box(ax, 'on');

    labels = indicators(index).labels;
    plotInfo = struct('local_index', index, ...
        'branch_index', branchIndex(index), ...
        'continuation_parameter', coordinate(index), ...
        'accepted', accepted, 'candidate_labels', {labels}, ...
        'gait', handles.gait, ...
        'gait_abbreviation', handles.gait_abbreviation, ...
        'gait_color', handles.gait_color, ...
        'gait_line_style', handles.gait_line_style);
end

function handles = InitializePlot(ax, data)
    cla(ax, 'reset');
    hold(ax, 'on');
    [gait, abbreviation, gaitColor, gaitLineStyle] = ...
        ResolveGaitStyle(data);
    handles = struct();
    handles.branch = plot(ax, NaN, NaN, '.-', ...
        'Color', gaitColor, 'LineStyle', gaitLineStyle, ...
        'LineWidth', 1.8, ...
        'MarkerSize', 8, ...
        'DisplayName', sprintf('%s solution branch', gait), ...
        'Tag', 'FloquetSolutionBranch');
    handles.plus_candidates = plot(ax, NaN, NaN, '^', ...
        'LineStyle', 'none', 'Color', [0.85 0.33 0.10], ...
        'MarkerFaceColor', [0.9290 0.6940 0.1250], ...
        'MarkerSize', 8, ...
        'DisplayName', 'candidate +1 Floquet degeneracy', ...
        'Tag', 'FloquetPlusOneCandidateMarkers');
    handles.minus_candidates = plot(ax, NaN, NaN, 'v', ...
        'LineStyle', 'none', 'Color', [0.49 0.18 0.56], ...
        'MarkerFaceColor', [0.49 0.18 0.56], 'MarkerSize', 8, ...
        'DisplayName', 'candidate period-doubling', ...
        'Tag', 'FloquetMinusOneCandidateMarkers');
    handles.unit_candidates = plot(ax, NaN, NaN, 'd', ...
        'LineStyle', 'none', 'Color', [0.00 0.50 0.35], ...
        'MarkerFaceColor', [0.00 0.50 0.35], 'MarkerSize', 8, ...
        'DisplayName', 'candidate torus', ...
        'Tag', 'FloquetUnitCircleCandidateMarkers');
    handles.rejected = plot(ax, NaN, NaN, 'x', ...
        'LineStyle', 'none', 'Color', [0.6350 0.0780 0.1840], ...
        'MarkerSize', 7, 'DisplayName', 'rejected computation', ...
        'Tag', 'FloquetRejectedPointMarkers');
    handles.current = plot(ax, NaN, NaN, '.', ...
        'LineStyle', 'none', 'Color', [0 0 0], ...
        'MarkerSize', 24, ...
        'DisplayName', 'current solution', ...
        'Tag', 'FloquetCurrentMarker');
    handles.gait = gait;
    handles.gait_abbreviation = abbreviation;
    handles.gait_color = gaitColor;
    handles.gait_line_style = gaitLineStyle;
    hold(ax, 'off');
    legend(ax, 'Location', 'best');
    try
        axtoolbar(ax, {});
    catch
    end
end

function [gait, abbreviation, color, lineStyle] = ResolveGaitStyle(data)
    gait = 'Unclassified';
    abbreviation = '';
    color = [0 0.4470 0.7410];
    lineStyle = '-';
    if exist('Gait_Identification', 'file') ~= 2 || ...
            ~isfield(data, 'solution_state') || ...
            ~isfield(data, 'event_time') || ...
            size(data.solution_state, 1) ~= 13 || ...
            size(data.event_time, 1) ~= 9 || ...
            size(data.solution_state, 2) ~= size(data.event_time, 2)
        return;
    end

    eventTime = data.event_time;
    if isfield(data, 'computation_info') && ...
            isfield(data.computation_info, 'input_event_time_guess')
        inputGuess = data.computation_info.input_event_time_guess;
        if isequal(size(inputGuess), size(eventTime))
            missing = ~isfinite(eventTime);
            eventTime(missing) = inputGuess(missing);
        end
    end
    gaitInput = [data.solution_state; eventTime];
    usable = all(isfinite(gaitInput), 1);
    if ~any(usable)
        return;
    end
    try
        [candidateGait, candidateAbbreviation, candidateColor, ...
            candidateLineStyle] = Gait_Identification(gaitInput(:, usable));
        candidateGait = char(string(candidateGait));
        candidateAbbreviation = char(string(candidateAbbreviation));
        if ~isempty(candidateGait)
            gait = candidateGait;
        end
        if ~isempty(candidateAbbreviation)
            abbreviation = candidateAbbreviation;
        end
        if isnumeric(candidateColor) && numel(candidateColor) == 3 && ...
                all(isfinite(candidateColor(:)))
            color = reshape(candidateColor, 1, 3);
        end
        candidateLineStyle = char(string(candidateLineStyle));
        if any(strcmp(candidateLineStyle, {'-', '--', ':', '-.'}))
            lineStyle = candidateLineStyle;
        end
    catch
        % Gait styling must not prevent inspection of a valid dataset.
    end
end

function tf = NeedsInitialization(handles)
    tf = ~isstruct(handles) || ~isfield(handles, 'branch') || ...
        ~isgraphics(handles.branch) || ~isfield(handles, 'current') || ...
        ~isgraphics(handles.current);
end

function [xOut, yOut] = BreakAtIndexGaps(x, y)
    if numel(x) < 2
        xOut = x;
        yOut = y;
        return;
    end
    gap = find(diff(x) ~= 1);
    xOut = x;
    yOut = y;
    for i = numel(gap):-1:1
        insertAt = gap(i) + 1;
        xOut = [xOut(1:insertAt-1), NaN, xOut(insertAt:end)];
        yOut = [yOut(1:insertAt-1), NaN, yOut(insertAt:end)];
    end
end

function accepted = AcceptedVector(data, count)
    accepted = false(1, count);
    if isfield(data, 'computation_info') && ...
            isfield(data.computation_info, 'accepted') && ...
            numel(data.computation_info.accepted) == count
        accepted = logical(data.computation_info.accepted(:).');
    end
end

function accepted = IsAccepted(data, index)
    values = AcceptedVector(data, numel(data.branch_index));
    accepted = values(index);
end

function index = ValidateIndex(index, count)
    if ~(isnumeric(index) && isscalar(index) && isfinite(index))
        error('UpdateBranchPlot:InvalidIndex', ...
            'Index must be a finite numeric scalar.');
    end
    index = round(index);
    if index < 1 || index > count
        error('UpdateBranchPlot:IndexOutOfRange', ...
            'Index must be between 1 and %d.', count);
    end
end
