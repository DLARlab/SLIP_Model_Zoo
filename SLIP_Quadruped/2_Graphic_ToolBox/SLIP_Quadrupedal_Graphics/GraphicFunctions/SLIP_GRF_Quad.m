classdef SLIP_GRF_Quad < OutputCLASS
    properties
        fig;       % Figure handle
        ax;        % Axis handle (1 axis for all GRFs)
        Lines;     % Line handles: [LH, LF, RF, RH]
        Legend;    % Fixed legend handle
    end

    methods
        function obj = SLIP_GRF_Quad(T, GRFs, PlotTarget)
            % Initialize OutputCLASS properties (inherited)
            obj.slowDown = 1;
            obj.rate = 0.05;

            % Handle axes or figure input
            if isa(PlotTarget, 'matlab.graphics.axis.Axes') || isa(PlotTarget, 'matlab.ui.control.UIAxes')
                obj.ax = PlotTarget;
                obj.fig = ancestor(obj.ax, {'matlab.ui.Figure','matlab.graphics.figure.Figure'});
            elseif isa(PlotTarget, 'matlab.ui.Figure') || isa(PlotTarget, 'matlab.graphics.figure.Figure')
                obj.fig = PlotTarget;
                figure(obj.fig); clf(obj.fig);
                obj.ax = axes('Parent', obj.fig);
            else
                error('PlotTarget must be an axis or figure handle.');
            end

            obj = obj.InitializePlots(T, GRFs);
        end

        function obj = InitializePlots(obj, T, GRFs)

            cla(obj.ax);   hold(obj.ax, 'on');   grid(obj.ax, 'on');

            orange = [217 83 25] / 256;
            blue   = [0 114 189] / 256;

            FBL = GRFs(:,1); % LH
            FFL = GRFs(:,2); % LF
            FBR = GRFs(:,3); % RH
            FFR = GRFs(:,4); % RF

            obj.Lines(1,1) = plot(obj.ax, T, FBL, '-',  'Color', orange, 'LineWidth', 2);
            obj.Lines(2,1) = plot(obj.ax, T, FFL, ':',  'Color', orange, 'LineWidth', 2.5);
            obj.Lines(3,1) = plot(obj.ax, T, FFR, ':',  'Color', blue,   'LineWidth', 2.5);
            obj.Lines(4,1) = plot(obj.ax, T, FBR, '-',  'Color', blue,   'LineWidth', 2);

            FontSize = 12;

            xlabel(obj.ax, 'Stride Time  $[\sqrt{l_0/g}]$', 'Interpreter', 'LaTeX', 'FontSize', FontSize);
            ylabel(obj.ax, 'Vertical GRF  $[m_0g]$', 'Interpreter', 'LaTeX', 'FontSize', FontSize);
            title(obj.ax, 'Ground Reaction Forces');
            obj.Legend = legend(obj.ax, {'LH','LF','RF','RH'}, ...
                'Location', 'northeast', 'AutoUpdate', 'off');
            box(obj.ax, 'on');
            xlim(obj.ax, [0 T(end)]);
            
            grf_min = min(GRFs(:,1:4), [], 'all');
            grf_max = max(GRFs(:,1:4), [], 'all');
            ylim(obj.ax, [grf_min*(1-0.1*sign(grf_min))  grf_max*(1 + 0.1*sign(grf_max))])
        end

        function obj = update(obj, T_, GRF_)

            if ~isa(obj.fig, 'matlab.ui.Figure')
                figure(obj.fig);  % only valid for classic figures
            end

            % t: scalar time, grf: 1×4 vector [FBL, FFL, FBR, FFR]
            for i = 1:4
                set(obj.Lines(i), 'XData', T_, 'YData', GRF_(:,i));
            end

        end
    end
end
