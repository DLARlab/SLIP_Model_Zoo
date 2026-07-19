classdef SLIP_Trajectories_Quad < OutputCLASS
    properties
        figs;      % figure handles (classic or UIFigure)
        axes;      % 3 axes handles
        Lines;     % cell array of line handles {torso, back, front}
    end

    methods
        function obj = SLIP_Trajectories_Quad(T, Y, PlotTargets)
            obj.slowDown = 1;
            obj.rate = 0.05;

            % ============================================================
            % Handle input format for PlotTargets:
            % - Case 1: PlotTargets is a 3×1 array of axes handles
            %   -> Used in GUI (e.g., App Designer); axes already exist.
            %   -> All three axes must share the same GUI ancestor.
            %
            % - Case 2: PlotTargets is a 2×1 array of figure handles
            %   -> First figure for torso; second for back/front legs.
            %   -> Subplots are automatically created in figure(2).
            % ============================================================

            if size(PlotTargets,1) == 3
                obj.axes = PlotTargets;
                top_ancestors = arrayfun(@(ax) ancestor(ax, {'matlab.ui.Figure','matlab.graphics.figure.Figure'}), obj.axes, 'UniformOutput', false);
                if ~isequal(top_ancestors{:})
                    error('All three axes must share the same top-level GUI ancestor.');
                end
                obj.figs = top_ancestors{1};

            elseif size(PlotTargets,1) == 2
                obj.figs = PlotTargets;
                obj.axes = gobjects(3,1);
                figure(obj.figs(1)); clf(obj.figs(1));
                obj.axes(1) = axes('Parent', obj.figs(1));
                figure(obj.figs(2)); clf(obj.figs(2));
                subplot(2,1,1); obj.axes(2) = gca;
                subplot(2,1,2); obj.axes(3) = gca;
            else
                error('PlotTargets must be 3 axes or 2 figure handles');
            end

            obj = obj.InitializePlots(T, Y);
        end

        function obj = InitializePlots(obj, T, Y)

            FontSize = 12;

            % === 1. Torso ===
            cla(obj.axes(1)); hold(obj.axes(1), 'on'); grid(obj.axes(1), 'on');
            obj.Lines{1} = plot(obj.axes(1), T, Y(:,2:6), '-');
            xlabel(obj.axes(1), 'Stride Time  $[\sqrt{l_0/g}]$', 'Interpreter','LaTeX', 'FontSize', FontSize);
            legend(obj.axes(1), {'$\dot{x}$','$y$','$\dot{y}$','$\phi$','$\dot{\phi}$'}, 'Interpreter','LaTeX');
            title(obj.axes(1), 'Trajectories of the Torso', 'FontSize', FontSize);
            xlim(obj.axes(1), [0 T(end)]);
            torso_min = min(Y(:,2:6), [], 'all');
            torso_max = max(Y(:,2:6), [], 'all');
            ylim(obj.axes(1), [torso_min*(1-0.1*sign(torso_min)) torso_max*(1 + 0.1*sign(torso_max))])

            % === Compute common y-limits for leg plots with padding ===
            leg_indices = [7 8 9 10 11 12 13 14];
            leg_angle_min = min(Y(:, leg_indices), [], 'all');
            leg_angle_max = max(Y(:, leg_indices), [], 'all');
            leg_range = leg_angle_max - leg_angle_min;
            padded_ylim = [leg_angle_min - 0.05*leg_range, leg_angle_max + 0.05*leg_range];

            % === 2. Back Legs ===
            cla(obj.axes(2)); hold(obj.axes(2), 'on'); grid(obj.axes(2), 'on');
            obj.Lines{2} = plot(obj.axes(2), T, Y(:,[7 8 11 12]), '-');
            xlabel(obj.axes(2), 'Stride Time  $[\sqrt{l_0/g}]$', 'Interpreter','LaTeX', 'FontSize', FontSize);
            legend(obj.axes(2), {'$\alpha_{BL}$','$\dot{\alpha}_{BL}$','$\alpha_{BR}$','$\dot{\alpha}_{BR}$'}, 'Interpreter','LaTeX');
            title(obj.axes(2), 'Trajectories of the Back Legs', 'FontSize', FontSize);
            xlim(obj.axes(2), [0 T(end)]);
            ylim(obj.axes(2), padded_ylim);
%             pbaspect(obj.axes(2), [2 1 1]);

            % === 3. Front Legs ===
            cla(obj.axes(3)); hold(obj.axes(3), 'on'); grid(obj.axes(3), 'on');
            obj.Lines{3} = plot(obj.axes(3), T, Y(:,[9 10 13 14]), '-');
            xlabel(obj.axes(3), 'Stride Time  $[\sqrt{l_0/g}]$', 'Interpreter','LaTeX', 'FontSize', FontSize);
            legend(obj.axes(3), {'$\alpha_{FL}$','$\dot{\alpha}_{FL}$','$\alpha_{FR}$','$\dot{\alpha}_{FR}$'}, 'Interpreter','LaTeX');
            title(obj.axes(3), 'Trajectories of the Front Legs', 'FontSize', FontSize);
            xlim(obj.axes(3), [0 T(end)]);
            ylim(obj.axes(3), padded_ylim);
%             pbaspect(obj.axes(3), [2 1 1]);
        end

        function obj = update(obj, T_, Y_, updateTorso, updateLegs)
            % updateTorso and updateLegs are optional booleans (default true).
            % Passing false skips updating that section, leaving its static plot intact.
            if nargin < 4, updateTorso = true; end
            if nargin < 5, updateLegs  = true; end

            if ~isa(obj.figs, 'matlab.ui.Figure')
                figure(obj.figs);  % only valid for classic figures
            end

            % === Update Torso lines ===
            if updateTorso
                torso_lines = obj.Lines{1};
                torso_idx = 2:6;
                for i = 1:5
                    torso_lines(i).XData = T_;
                    torso_lines(i).YData = Y_(:,torso_idx(i));
                end
            end

            % === Update Back leg lines ===
            if updateLegs
                back_lines = obj.Lines{2};
                back_idx = [7 8 11 12];
                for i = 1:4
                    back_lines(i).XData = T_;
                    back_lines(i).YData = Y_(:,back_idx(i));
                end

                % === Update Front leg lines ===
                front_lines = obj.Lines{3};
                front_idx = [9 10 13 14];
                for i = 1:4
                    front_lines(i).XData = T_;
                    front_lines(i).YData = Y_(:,front_idx(i));
                end
            end

        end
    end
end
