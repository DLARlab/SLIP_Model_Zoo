classdef BranchPlotAdapter < handle
%BRANCHPLOTADAPTER Reusable SLIP quadruped branch view and selection.
%
%   ADAPTER = SLIPBRANCHPLOTADAPTER(AX) installs the state-space branch
%   view used by SLIP_Quadruped_GUI on the supplied axes. The original GUI
%   is not called or modified. Branch matrices use the repository format
%   [X(13); E(9); parameters], so a locked selection exposes X(1:22) and
%   the parameter rows separately.
%
%   The displayed state coordinates default to [1 5 2], corresponding to
%   horizontal velocity, pitch rate, and height. Use SETAXISINDICES to
%   reproduce the three state-axis dropdowns. Clicking a branch line locks
%   the nearest continuation point using the same axis-span-normalized
%   three-dimensional distance as SLIP_Quadruped_GUI.

    properties
        SelectionChangedFcn = []
    end

    properties (SetAccess = private)
        Axes
        AxisIndices = [1 5 2]
        AxisOptions
        Datasets
        Selection
    end

    properties (Access = private)
        CurrentMarker = gobjects(0)
        CurrentLabel = gobjects(0)
    end

    methods
        function obj = BranchPlotAdapter(ax, varargin)
            if nargin < 1 || ~isgraphics(ax, 'axes')
                error('SLIPBranchPlotAdapter:InvalidAxes', ...
                    'A valid MATLAB axes or UIAxes handle is required.');
            end

            parser = inputParser;
            parser.FunctionName = 'floquet.gui.plot.BranchPlotAdapter';
            addParameter(parser, 'AxisIndices', [1 5 2]);
            addParameter(parser, 'SelectionChangedFcn', []);
            parse(parser, varargin{:});

            obj.Axes = ax;
            obj.AxisOptions = { ...
                '$\dot{q}_x$', '$q_y$', '$\dot{q}_y$', '$q_{pitch}$', ...
                '$\dot{q}_{pitch}$', '$q_{BL}$', '$\dot{q}_{BL}$', ...
                '$q_{FL}$', '$\dot{q}_{FL}$', '$q_{BR}$', ...
                '$\dot{q}_{BR}$', '$q_{FR}$', '$\dot{q}_{FR}$'};
            obj.Datasets = obj.EmptyDatasets();
            obj.Selection = obj.EmptySelection();
            obj.SelectionChangedFcn = ...
                obj.ValidateCallback(parser.Results.SelectionChangedFcn);

            hold(obj.Axes, 'on');
            view(obj.Axes, [0 90]);
            title(obj.Axes, 'Plottings of Periodic Solutions', ...
                'Interpreter', 'none');
            obj.SetAxisIndices(parser.Results.AxisIndices);
        end

        function lineHandle = AddBranch(obj, name, results, varargin)
        %ADDBRANCH Plot one repository-format continuation branch.
            obj.RequireLiveAxes();
            name = obj.ValidateName(name);
            results = obj.ValidateResults(results);

            existing = obj.FindDatasetByName(name);
            if ~isempty(existing)
                obj.ActivateBranch(name);
                lineHandle = obj.Datasets(existing).Handle;
                return;
            end

            parser = inputParser;
            parser.FunctionName = 'SLIPBranchPlotAdapter.AddBranch';
            addParameter(parser, 'Baseline', false, ...
                @(x) islogical(x) && isscalar(x));
            addParameter(parser, 'Brightness', 1, ...
                @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
            addParameter(parser, 'Color', [], ...
                @(x) isempty(x) || (isnumeric(x) && numel(x) == 3 && ...
                all(isfinite(x(:)))));
            addParameter(parser, 'LineStyle', '', ...
                @(x) ischar(x) || (isstring(x) && isscalar(x)));
            parse(parser, varargin{:});

            [gait, abbreviation, gaitColor, gaitLineStyle] = ...
                obj.ResolveGaitStyle(results);
            if parser.Results.Baseline
                gaitColor = [0.5 0.5 0.5];
            elseif ~isempty(parser.Results.Color)
                gaitColor = reshape(parser.Results.Color, 1, 3);
            end
            if ~isempty(parser.Results.LineStyle)
                gaitLineStyle = char(parser.Results.LineStyle);
            end
            gaitColor = min(1, max(0, ...
                gaitColor .* parser.Results.Brightness));

            indices = obj.AxisIndices;
            lineHandle = plot3(obj.Axes, ...
                results(indices(1), :), results(indices(2), :), ...
                results(indices(3), :), ...
                'LineWidth', 2, 'Color', gaitColor, ...
                'LineStyle', gaitLineStyle, ...
                'ButtonDownFcn', @(src, event) obj.BranchLineClicked(src, event), ...
                'Tag', 'SLIPQuadrupedSolutionBranch');
            if isprop(lineHandle, 'PickableParts')
                lineHandle.PickableParts = 'all';
            end
            lineHandle.HitTest = 'on';
            lineHandle.UserData = struct('DatasetName', name);

            dataset = struct('Name', name, 'Results', results, ...
                'Handle', lineHandle, 'Gait', gait, ...
                'GaitAbbreviation', abbreviation, 'GaitColor', gaitColor, ...
                'GaitLineStyle', gaitLineStyle);
            obj.Datasets(end + 1) = dataset;
            obj.ActivateBranch(name);
        end

        function SetAxisIndices(obj, indices)
        %SETAXISINDICES Change the three displayed state coordinates.
            indices = obj.ValidateAxisIndices(indices);
            obj.AxisIndices = indices;

            if ~isempty(obj.Axes) && isgraphics(obj.Axes, 'axes')
                obj.Axes.XLabel.String = obj.AxisOptions{indices(1)};
                obj.Axes.YLabel.String = obj.AxisOptions{indices(2)};
                obj.Axes.ZLabel.String = obj.AxisOptions{indices(3)};
                obj.Axes.XLabel.Interpreter = 'latex';
                obj.Axes.YLabel.Interpreter = 'latex';
                obj.Axes.ZLabel.Interpreter = 'latex';
                obj.Axes.XLabel.FontSize = 15;
                obj.Axes.YLabel.FontSize = 15;
                obj.Axes.ZLabel.FontSize = 15;
            end

            for k = 1:numel(obj.Datasets)
                if ~isgraphics(obj.Datasets(k).Handle)
                    continue;
                end
                results = obj.Datasets(k).Results;
                obj.Datasets(k).Handle.XData = results(indices(1), :);
                obj.Datasets(k).Handle.YData = results(indices(2), :);
                obj.Datasets(k).Handle.ZData = results(indices(3), :);
            end
            if ~isempty(obj.Selection.Results)
                selected = obj.FindDatasetByName(obj.Selection.DatasetName);
                if ~isempty(selected)
                    obj.Selection = obj.BuildSelection(selected, ...
                        obj.Selection.Index);
                    obj.RefreshSelectionMarker();
                end
            end
        end

        function selection = SelectIndex(obj, name, index)
        %SELECTINDEX Lock one continuation point and notify the client GUI.
            datasetIndex = obj.FindDatasetByName(obj.ValidateName(name));
            if isempty(datasetIndex)
                error('SLIPBranchPlotAdapter:UnknownDataset', ...
                    'No plotted branch is named "%s".', char(string(name)));
            end
            count = size(obj.Datasets(datasetIndex).Results, 2);
            if ~(isnumeric(index) && isscalar(index) && isfinite(index))
                error('SLIPBranchPlotAdapter:InvalidIndex', ...
                    'The branch index must be a finite numeric scalar.');
            end
            index = max(1, min(count, round(index)));

            obj.ActivateBranch(obj.Datasets(datasetIndex).Name);
            obj.Selection = obj.BuildSelection(datasetIndex, index);
            obj.RefreshSelectionMarker();
            obj.NotifySelectionChanged();
            selection = obj.Selection;
        end

        function [selection, found] = SelectNearest(obj, point, preferred)
        %SELECTNEAREST Find and lock the nearest displayed branch point.
            if nargin < 3
                preferred = [];
            end
            [selection, found] = obj.ResolveNearest(point, preferred);
            if ~found
                return;
            end
            selection = obj.SelectIndex(selection.DatasetName, ...
                selection.Index);
        end

        function [selection, found] = ResolveNearest(obj, point, preferred)
        %RESOLVENEAREST Resolve without changing the locked selection.
            if nargin < 3
                preferred = [];
            end
            point = obj.ValidatePoint(point);
            selection = obj.EmptySelection();
            found = false;
            if isempty(obj.Datasets)
                return;
            end

            candidates = 1:numel(obj.Datasets);
            preferredIndex = obj.ResolveDatasetReference(preferred);
            if ~isempty(preferredIndex)
                candidates = preferredIndex;
            end

            xScale = max(diff(obj.Axes.XLim), eps);
            yScale = max(diff(obj.Axes.YLim), eps);
            zScale = max(diff(obj.Axes.ZLim), eps);
            bestDistance = inf;
            for k = candidates
                lineHandle = obj.Datasets(k).Handle;
                if ~isgraphics(lineHandle)
                    continue;
                end
                x = lineHandle.XData(:);
                y = lineHandle.YData(:);
                z = lineHandle.ZData(:);
                distances = ((x - point(1)) ./ xScale).^2 + ...
                    ((y - point(2)) ./ yScale).^2 + ...
                    ((z - point(3)) ./ zScale).^2;
                distances(~isfinite(distances)) = inf;
                [distance, index] = min(distances);
                if ~isempty(distance) && distance < bestDistance
                    bestDistance = distance;
                    selection = obj.BuildSelection(k, index);
                    found = true;
                end
            end
        end

        function ActivateBranch(obj, name)
        %ACTIVATEBRANCH Reproduce the original GUI's 5-versus-2 widths.
            name = obj.ValidateName(name);
            for k = 1:numel(obj.Datasets)
                if ~isgraphics(obj.Datasets(k).Handle)
                    continue;
                end
                if strcmp(obj.Datasets(k).Name, name)
                    obj.Datasets(k).Handle.LineWidth = 5;
                else
                    obj.Datasets(k).Handle.LineWidth = 2;
                end
            end
        end

        function ClearSelection(obj)
            obj.Selection = obj.EmptySelection();
            obj.DeleteSelectionGraphics();
            obj.NotifySelectionChanged();
        end

        function RemoveBranch(obj, name)
            name = obj.ValidateName(name);
            index = obj.FindDatasetByName(name);
            if isempty(index)
                return;
            end
            if isgraphics(obj.Datasets(index).Handle)
                delete(obj.Datasets(index).Handle);
            end
            obj.Datasets(index) = [];
            if strcmp(obj.Selection.DatasetName, name)
                obj.ClearSelection();
            end
        end

        function ClearBranches(obj)
            for k = 1:numel(obj.Datasets)
                if isgraphics(obj.Datasets(k).Handle)
                    delete(obj.Datasets(k).Handle);
                end
            end
            obj.Datasets = obj.EmptyDatasets();
            obj.ClearSelection();
        end

        function names = BranchNames(obj)
            names = {obj.Datasets.Name};
        end

        function dataset = Branch(obj, name)
            index = obj.FindDatasetByName(obj.ValidateName(name));
            if isempty(index)
                dataset = struct([]);
            else
                dataset = obj.Datasets(index);
            end
        end

        function delete(obj)
            if isempty(obj)
                return;
            end
            obj.SelectionChangedFcn = [];
            for k = 1:numel(obj.Datasets)
                if isgraphics(obj.Datasets(k).Handle)
                    delete(obj.Datasets(k).Handle);
                end
            end
            obj.DeleteSelectionGraphics();
        end
    end

    methods (Access = private)
        function BranchLineClicked(obj, source, event)
            if ~isgraphics(source)
                return;
            end
            point = [];
            if isobject(event) && isprop(event, 'IntersectionPoint')
                point = event.IntersectionPoint;
            elseif isstruct(event) && isfield(event, 'IntersectionPoint')
                point = event.IntersectionPoint;
            end
            if isempty(point)
                point = obj.Axes.CurrentPoint;
                point = point(1, 1:3);
            end
            obj.SelectNearest(point, source);
        end

        function selection = BuildSelection(obj, datasetIndex, pointIndex)
            dataset = obj.Datasets(datasetIndex);
            indices = obj.AxisIndices;
            position = [dataset.Results(indices(1), pointIndex), ...
                dataset.Results(indices(2), pointIndex), ...
                dataset.Results(indices(3), pointIndex)];
            parameters = [];
            if size(dataset.Results, 1) > 22
                parameters = dataset.Results(23:end, pointIndex);
            end
            selection = struct('DatasetName', dataset.Name, ...
                'Results', dataset.Results, 'Index', pointIndex, ...
                'Position', position, 'Handle', dataset.Handle, ...
                'X', dataset.Results(1:22, pointIndex), ...
                'Para', parameters);
        end

        function RefreshSelectionMarker(obj)
            if isempty(obj.Selection.Results) || ...
                    ~isgraphics(obj.Axes, 'axes')
                obj.DeleteSelectionGraphics();
                return;
            end
            position = obj.Selection.Position;
            xOffset = 0.02 * max(diff(obj.Axes.XLim), eps);
            yOffset = 0.02 * max(diff(obj.Axes.YLim), eps);
            zOffset = 0.02 * max(diff(obj.Axes.ZLim), eps);
            if isgraphics(obj.CurrentMarker)
                obj.CurrentMarker.XData = position(1);
                obj.CurrentMarker.YData = position(2);
                obj.CurrentMarker.ZData = position(3);
            else
                obj.CurrentMarker = plot3(obj.Axes, position(1), ...
                    position(2), position(3), 'o', ...
                    'LineStyle', 'none', 'MarkerSize', 10, ...
                    'MarkerFaceColor', [0 0 0], ...
                    'MarkerEdgeColor', [0 0 0], 'LineWidth', 1.2, ...
                    'HitTest', 'off', 'Tag', ...
                    'SLIPQuadrupedCurrentSolutionMarker');
            end
            labelPosition = position + [xOffset yOffset zOffset];
            if isgraphics(obj.CurrentLabel)
                obj.CurrentLabel.Position = labelPosition;
                obj.CurrentLabel.String = ' Current Solution';
            else
                obj.CurrentLabel = text(obj.Axes, labelPosition(1), ...
                    labelPosition(2), labelPosition(3), ...
                    ' Current Solution', 'Interpreter', 'none', ...
                    'Color', [0 0 0], 'BackgroundColor', [1 1 1], ...
                    'Margin', 1, 'HorizontalAlignment', 'left', ...
                    'VerticalAlignment', 'bottom', 'HitTest', 'off', ...
                    'Tag', 'SLIPQuadrupedCurrentSolutionLabel');
            end
        end

        function DeleteSelectionGraphics(obj)
            if isgraphics(obj.CurrentMarker)
                delete(obj.CurrentMarker);
            end
            if isgraphics(obj.CurrentLabel)
                delete(obj.CurrentLabel);
            end
            obj.CurrentMarker = gobjects(0);
            obj.CurrentLabel = gobjects(0);
        end

        function NotifySelectionChanged(obj)
            callback = obj.SelectionChangedFcn;
            if isempty(callback)
                return;
            end
            callback(obj, obj.Selection);
        end

        function index = FindDatasetByName(obj, name)
            index = find(strcmp({obj.Datasets.Name}, name), 1);
        end

        function index = ResolveDatasetReference(obj, reference)
            index = [];
            if isempty(reference)
                return;
            end
            if ischar(reference) || (isstring(reference) && isscalar(reference))
                index = obj.FindDatasetByName(char(reference));
                return;
            end
            for k = 1:numel(obj.Datasets)
                if isequal(obj.Datasets(k).Handle, reference)
                    index = k;
                    return;
                end
            end
        end

        function RequireLiveAxes(obj)
            if isempty(obj.Axes) || ~isgraphics(obj.Axes, 'axes')
                error('SLIPBranchPlotAdapter:DeletedAxes', ...
                    'The branch axes has been deleted.');
            end
        end
    end

    methods (Static, Access = private)
        function datasets = EmptyDatasets()
            datasets = struct('Name', {}, 'Results', {}, 'Handle', {}, ...
                'Gait', {}, 'GaitAbbreviation', {}, 'GaitColor', {}, ...
                'GaitLineStyle', {});
        end

        function selection = EmptySelection()
            selection = struct('DatasetName', '', 'Results', [], ...
                'Index', [], 'Position', [], 'Handle', [], 'X', [], ...
                'Para', []);
        end

        function name = ValidateName(name)
            if ~(ischar(name) || (isstring(name) && isscalar(name)))
                error('SLIPBranchPlotAdapter:InvalidName', ...
                    'The dataset name must be a character vector or string scalar.');
            end
            name = char(string(name));
            if isempty(strtrim(name))
                error('SLIPBranchPlotAdapter:InvalidName', ...
                    'The dataset name cannot be empty.');
            end
        end

        function results = ValidateResults(results)
            if ~(isnumeric(results) && ismatrix(results) && ...
                    size(results, 1) >= 22 && size(results, 2) >= 1)
                error('SLIPBranchPlotAdapter:InvalidResults', ...
                    ['Branch results must be a numeric matrix with at least ' ...
                    '22 rows and one continuation point.']);
            end
        end

        function indices = ValidateAxisIndices(indices)
            if ~(isnumeric(indices) && numel(indices) == 3 && ...
                    all(isfinite(indices(:))) && ...
                    all(indices(:) == round(indices(:))) && ...
                    all(indices(:) >= 1) && all(indices(:) <= 13))
                error('SLIPBranchPlotAdapter:InvalidAxisIndices', ...
                    'AxisIndices must contain three integer state rows from 1 to 13.');
            end
            indices = reshape(indices, 1, 3);
        end

        function point = ValidatePoint(point)
            if ~(isnumeric(point) && numel(point) >= 3 && ...
                    all(isfinite(point(1:3))))
                error('SLIPBranchPlotAdapter:InvalidPoint', ...
                    'The cursor point must contain three finite coordinates.');
            end
            point = reshape(point(1:3), 1, 3);
        end

        function callback = ValidateCallback(callback)
            if ~(isempty(callback) || isa(callback, 'function_handle'))
                error('SLIPBranchPlotAdapter:InvalidCallback', ...
                    'SelectionChangedFcn must be empty or a function handle.');
            end
        end

        function [gait, abbreviation, color, lineStyle] = ...
                ResolveGaitStyle(results)
            gait = 'Unclassified';
            abbreviation = '';
            color = [0 0.4470 0.7410];
            lineStyle = '-';
            if exist('Gait_Identification', 'file') ~= 2
                return;
            end
            try
                [candidateGait, candidateAbbreviation, candidateColor, ...
                    candidateLineStyle] = Gait_Identification(results);
                if ~isempty(candidateGait)
                    gait = char(string(candidateGait));
                end
                if ~isempty(candidateAbbreviation)
                    abbreviation = char(string(candidateAbbreviation));
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
                % Classification styling must not block a valid branch view.
            end
        end
    end
end
