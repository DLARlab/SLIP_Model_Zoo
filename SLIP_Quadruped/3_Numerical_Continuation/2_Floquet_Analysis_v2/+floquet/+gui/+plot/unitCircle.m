function handles = unitCircle(ax, options)
%PLOTUNITCIRCLE Draw static guides for a Floquet multiplier plane.
%
%   HANDLES = PLOTUNITCIRCLE(AX) draws the real and imaginary axes, the
%   unit circle, and the +1/-1 reference locations into AX. Existing
%   graphics with the utility's tags are replaced; unrelated graphics are
%   retained.

    if nargin < 1 || isempty(ax) || ~isgraphics(ax, 'axes')
        error('PlotUnitCircle:InvalidAxes', ...
            'A valid MATLAB axes or UIAxes handle is required.');
    end
    if nargin < 2 || isempty(options)
        options = struct();
    end
    defaults = struct('Radius', 1, 'Limit', 1.25, ...
        'CircleColor', [0.25 0.25 0.25], ...
        'AxisColor', [0.65 0.65 0.65]);
    options = MergeOptions(defaults, options);

    tags = {'FloquetUnitCircle', 'FloquetRealAxis', ...
        'FloquetImaginaryAxis', 'FloquetPlusOneTarget', ...
        'FloquetMinusOneTarget'};
    for i = 1:numel(tags)
        old = findall(ax, 'Tag', tags{i});
        if ~isempty(old)
            delete(old);
        end
    end

    held = ishold(ax);
    hold(ax, 'on');
    theta = linspace(0, 2*pi, 721);
    limit = max(options.Limit, 1.1 * options.Radius);
    handles = struct();
    handles.real_axis = plot(ax, [-limit limit], [0 0], '-', ...
        'Color', options.AxisColor, 'LineWidth', 0.8, ...
        'HitTest', 'off', 'HandleVisibility', 'off', ...
        'Tag', 'FloquetRealAxis');
    handles.imaginary_axis = plot(ax, [0 0], [-limit limit], '-', ...
        'Color', options.AxisColor, 'LineWidth', 0.8, ...
        'HitTest', 'off', 'HandleVisibility', 'off', ...
        'Tag', 'FloquetImaginaryAxis');
    handles.unit_circle = plot(ax, options.Radius*cos(theta), ...
        options.Radius*sin(theta), 'k--', 'LineWidth', 1.1, ...
        'DisplayName', 'unit circle', 'HitTest', 'off', ...
        'Tag', 'FloquetUnitCircle');
    handles.plus_one_target = plot(ax, 1, 0, '+', ...
        'Color', [0.85 0.33 0.10], 'MarkerSize', 9, 'LineWidth', 1.2, ...
        'DisplayName', '+1', 'HitTest', 'off', ...
        'Tag', 'FloquetPlusOneTarget');
    handles.minus_one_target = plot(ax, -1, 0, '+', ...
        'Color', [0.49 0.18 0.56], 'MarkerSize', 9, 'LineWidth', 1.2, ...
        'DisplayName', '-1', 'HitTest', 'off', ...
        'Tag', 'FloquetMinusOneTarget');
    xlim(ax, [-limit limit]);
    ylim(ax, [-limit limit]);
    axis(ax, 'equal');
    grid(ax, 'on');
    box(ax, 'on');
    xlabel(ax, 'Real(\lambda)', 'Interpreter', 'tex');
    ylabel(ax, 'Imag(\lambda)', 'Interpreter', 'tex');
    if ~held
        hold(ax, 'off');
    end
end

function options = MergeOptions(options, supplied)
    if ~isstruct(supplied) || ~isscalar(supplied)
        error('PlotUnitCircle:InvalidOptions', ...
            'Options must be a scalar structure.');
    end
    names = fieldnames(supplied);
    allowed = fieldnames(options);
    for i = 1:numel(names)
        match = find(strcmpi(names{i}, allowed), 1);
        if isempty(match)
            error('PlotUnitCircle:UnknownOption', ...
                'Unknown option ''%s''.', names{i});
        end
        options.(allowed{match}) = supplied.(names{i});
    end
    if ~(isnumeric(options.Radius) && isscalar(options.Radius) && ...
            isfinite(options.Radius) && options.Radius > 0) || ...
            ~(isnumeric(options.Limit) && isscalar(options.Limit) && ...
            isfinite(options.Limit) && options.Limit > 0)
        error('PlotUnitCircle:InvalidScale', ...
            'Radius and Limit must be positive finite scalars.');
    end
end
