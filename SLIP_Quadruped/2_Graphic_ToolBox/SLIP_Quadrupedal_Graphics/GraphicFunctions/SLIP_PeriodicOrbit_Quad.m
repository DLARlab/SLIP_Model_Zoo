classdef SLIP_PeriodicOrbit_Quad < OutputCLASS 
    properties 
        fig; % The output window
        axes;
        % Patch objects used in the graphical representation
        Orbit;
        Poincare_Section;
        Current_Position;
        Text;
    end
  
    methods
        % Constructor:
        function obj = SLIP_PeriodicOrbit_Quad(Y,plotPositions,FigOrAx,gaitcolor)
            obj.slowDown = 1;      % Run this in real time.
            obj.rate     = 0.05;   % with 25 fps
            
            if isa(FigOrAx, 'matlab.ui.Figure')
                obj.fig = FigOrAx;     clf(obj.fig);
                % Set window properties
                set(obj.fig, 'Name','Periodic Orbit');  % Window title
                set(obj.fig, 'Color','w');          % Background color
                set(obj.fig, 'Renderer','OpenGL');
                set(obj.fig, 'position', plotPositions);
                
                obj.axes = axes(obj.fig);  hold on;

            elseif isa(FigOrAx, 'matlab.graphics.axis.Axes') || isa(FigOrAx, 'matlab.ui.control.UIAxes')
                obj.axes = FigOrAx;
                obj.fig = ancestor(obj.axes, 'figure');
                set(obj.axes, 'Position', plotPositions, 'Box', 'Off')
            else
                error('Third input must be either a figure handle or axes handle.');
            end

            obj = obj.InitializePlots(Y, gaitcolor);
        end

        function obj = InitializePlots(obj, Y, gaitcolor)
            cla(obj.axes, 'reset');
            hold(obj.axes, 'on');

            xlo = min(Y(:,2)); xhi = max(Y(:,2));
            ylo = min(Y(:,4)); yhi = max(Y(:,4));
            zlo = min(Y(:,6)); zhi = max(Y(:,6));
            xpad = max(abs(xhi - xlo)*0.1, 0.01);
            ypad = max(abs(yhi - ylo)*0.1, 0.01);
            zpad = max(abs(zhi - zlo)*0.1, 0.02);
            obj.axes.XLim = [xlo - xpad, xhi + xpad];
            obj.axes.YLim = [ylo - ypad, yhi + ypad];
            obj.axes.ZLim = [zlo - zpad, zhi + zpad];

            xlabel(obj.axes, '$\dot{q}_x  [\sqrt{gl_0}]$', 'Interpreter', 'LaTex', 'FontSize', 15);
            ylabel(obj.axes, '$\dot{q}_z  [\sqrt{gl_0}]$', 'Interpreter', 'LaTex', 'FontSize', 15);
            zlabel(obj.axes, '$\dot{q}_{pitch}  [rad/s]$', 'Interpreter', 'LaTex', 'FontSize', 15);

            obj.axes.Title.String = 'Periodic Orbit of The Solution';

            obj.Orbit = plot3(Y(:,2),Y(:,4),Y(:,6),'LineWidth',2,'Color',[0 0 0],'Parent',obj.axes);

            obj.Poincare_Section = fill3(...
                [xlo - xpad, xhi + xpad, xhi + xpad, xlo - xpad], ...
                [0 0 0 0], ...
                [zlo - zpad, zlo - zpad, zhi + zpad, zhi + zpad], ...
                [0.7 0.7 0.7], 'Parent', obj.axes, 'FaceAlpha', 0.3);

            % textPS: left-top corner of the Poincare section plane (y = 0),
            %         inset 10% of each axis range away from the corner
            x_range = (xhi + xpad) - (xlo - xpad);
            z_range = (zhi + zpad) - (zlo - zpad);
            textPS = text((xlo - xpad) + x_range * 0.10, 0, (zhi + zpad) - z_range * 0.10, ...
                           {'Poincare Section','$\dot{q}_z = 0$'}, 'Interpreter','LaTex', ...
                           'HorizontalAlignment','left', 'VerticalAlignment','top', 'Parent',obj.axes);

            % textPO: middle of x-lim, 1/4 y-range below the Poincare plane (negative ydot side),
            %         1/4 z-range up from the bottom z-limit
            x_mid   = (xlo + xhi) / 2;
            y_range = (yhi + ypad) - (ylo - ypad);
            y_off   = -y_range * 0.25;
            z_qtr   = (zlo - zpad) + z_range * 0.25;
            textPO = text(x_mid, y_off, z_qtr, ...
                          'Periodic Orbit', 'HorizontalAlignment','center', 'Parent',obj.axes);

            obj.Text = struct('textPS',textPS,'textPO',textPO);

            obj.Current_Position = scatter3(Y(1,2),Y(1,4),Y(1,6),120,'filled','Parent',obj.axes,...
                                            'MarkerEdgeColor',gaitcolor,'MarkerFaceColor',gaitcolor);

            obj.axes.View = [45 30];
        end

        function obj = update(obj,y)
            if isgraphics(obj.Current_Position)
                set(obj.Current_Position,'xData',y(2),'yData',y(4),'zData',y(6));
            end
        end
    end
end
