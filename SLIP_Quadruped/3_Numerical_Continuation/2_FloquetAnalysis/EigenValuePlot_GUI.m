function EigenValuePlot_GUI()
    % Create a figure for the GUI, with increased width to fit the eigenvalue norms
    screenSize = get(0, 'ScreenSize');
    fig = figure('Name', 'Eigenvalue Visualization', 'NumberTitle', 'off', 'Position', [0.05*screenSize(3), 0.25*screenSize(4), 1800, 600]);

    % Create a file selection button
    uicontrol('Style', 'pushbutton', 'String', 'Select .mat File', ...
              'Units', 'normalized', 'Position', [0.05 0.9 0.2 0.05], ...
              'Callback', @(src, event) selectFile());

    % Initialize variables
    eigenvalueMatrix = [];
    eigenvectorCells = {}; % Cell array to hold eigenvectors
    eigenvalueNormMatrix = []; % Matrix to hold eigenvalue norms
    results = [];
    crossingMatrix = []; % Matrix to track crossings
    crossingIndices = []; % Array to store column indices where crossings occur
    n = 0; % Number of eigenvalues
    m = 0; % Number of solutions
    filename = ''; % Store the original filename
    isPlaying = false; % Flag for play state
    hQuiver = []; % Declare hQuiver globally for access in all functions
    currentDot = []; % Declare currentDot globally
    normTextBox = []; % Handle for the annotation displaying all eigenvalue norms

    % Create UI elements: Slider, Play button, Pause button, and Record button
    slider = uicontrol('Style', 'slider', 'Min', 1, 'Max', 1, 'Value', 1, ...
                       'Units', 'normalized', 'Position', [0.05 0.05 0.5 0.05], ...
                       'SliderStep', [1 1], ...
                       'Callback', @(src, event) updatePlot(round(src.Value)), ...
                       'Enable', 'off');  % Disable until data is loaded

    playButton = uicontrol('Style', 'togglebutton', 'String', 'Play', ...
                           'Units', 'normalized', 'Position', [0.6 0.05 0.08 0.05], ...
                           'Callback', @(src, event) playSolutions(), 'Enable', 'off');

    pauseButton = uicontrol('Style', 'pushbutton', 'String', 'Pause', ...
                            'Units', 'normalized', 'Position', [0.7 0.05 0.08 0.05], ...
                            'Callback', @(src, event) pausePlayback(), 'Enable', 'off');

    recordButton = uicontrol('Style', 'pushbutton', 'String', 'Record GIF', ...
                             'Units', 'normalized', 'Position', [0.8 0.05 0.08 0.05], ...
                             'Callback', @(src, event) recordGif(), 'Enable', 'off');

    % Callback function for file selection
    function selectFile()
        % Open a file selection dialog
        [file, path] = uigetfile('*.mat', 'Select a .mat file');
        if isequal(file, 0)
            disp('File selection canceled');
            return;
        end

        % Load the selected .mat file
        filename = fullfile(path, file);
        data = load(filename);

        % Check if required variables exist in the loaded data
        if ~isfield(data, 'EigenValues') || ~isfield(data, 'results') || ~isfield(data, 'EigenVectors') || ~isfield(data, 'EigenValuesNorm')
            errordlg('The .mat file must contain ''EigenValues'', ''results'', ''EigenVectors'', and ''EigenValuesNorm'' variables.', 'File Error');
            return;
        end

        % Extract eigenvalue matrix, eigenvector cells, eigenvalue norm matrix, and results from the loaded data
        EigenValues = data.EigenValues;
        EigenVectors = data.EigenVectors;
        EigenValuesNorm = data.EigenValuesNorm;
        results = data.results;

        % Update the number of solutions and eigenvalues
        [n, m] = size(EigenValues);

        % Initialize the crossing matrix (zeros)
        crossingMatrix = zeros(n, m);

        % Sort the eigenvalue matrix, eigenvector cells, and eigenvalue norms
        [eigenvalueMatrix, eigenvectorCells, eigenvalueNormMatrix] = sortEigenvaluesVectorsAndNorms(EigenValues, EigenVectors, EigenValuesNorm, n, m);

        % Detect crossings for each eigenvalue and update the crossing matrix
        detectCrossings();

        % Find the column indices where crossings occur and store them in crossingIndices
        findCrossingIndices();

        % Save the sorted data, including the crossing indices, to a new file
        saveSortedData(filename);

        % Enable the slider and set its range
        set(slider, 'Max', m, 'SliderStep', [1/(m-1) , 1/(m-1)], 'Enable', 'on');
        set(playButton, 'Enable', 'on');
        set(pauseButton, 'Enable', 'on');
        set(recordButton, 'Enable', 'on');

        % Initial plot display
        initializePlots();
        updatePlot(1);
    end

    % % Function to detect crossings (norms crossing 1) and update the crossing matrix
    % function detectCrossings()
    %     for i = 1:n
    %         for j = 2:m % Start from the second solution to compare with the first
    %             normPrev = eigenvalueNormMatrix(i, j - 1);
    %             normCurrent = eigenvalueNormMatrix(i, j);
    % 
    %             % Check if there is a crossing between <1 and >1 or vice versa
    %             if (normPrev < 1 && normCurrent > 1) || (normPrev > 1 && normCurrent < 1)
    %                 crossingMatrix(i, j) = 1; % Mark the crossing
    %             end
    %         end
    %     end
    % end

    % Function to detect crossings and classify bifurcation types with accuracy threshold
    function detectCrossings()
        % Extract accuracy threshold from the file name
        threshold = extractAccuracyThreshold(filename);
    
        % Reset the crossing matrix
        crossingMatrix = zeros(n, m);
    
        % Loop over all eigenvalues for all solutions
        for i = 1:n
            for j = 2:m
                normPrev = eigenvalueNormMatrix(i, j - 1);
                normCurrent = eigenvalueNormMatrix(i, j);
    
                % Get real and imaginary parts for both previous and current eigenvalues
                realPrev = real(eigenvalueMatrix(i, j - 1));
                realCurrent = real(eigenvalueMatrix(i, j));
                imagPrev = imag(eigenvalueMatrix(i, j - 1));
                imagCurrent = imag(eigenvalueMatrix(i, j));
    
                % Treat tiny imaginary parts as zero based on threshold
                if abs(imagPrev) < threshold
                    imagPrev = 0;
                end
                if abs(imagCurrent) < threshold
                    imagCurrent = 0;
                end
    
                % Saddle-Node (SNPO) Bifurcation: Real eigenvalue crosses +1
                if (realPrev < 1 && realCurrent > 1 && imagPrev == 0 && imagCurrent == 0) || ...
                   (realPrev > 1 && realCurrent < 1 && imagPrev == 0 && imagCurrent == 0)
                    crossingMatrix(i, j) = 1; % Type 1: SNPO
    
                % Period-Doubling Bifurcation: Real eigenvalue crosses -1
                elseif (realPrev > -1 && realCurrent < -1 && imagPrev == 0 && imagCurrent == 0) || ...
                       (realPrev < -1 && realCurrent > -1 && imagPrev == 0 && imagCurrent == 0)
                    crossingMatrix(i, j) = 2; % Type 2: Period-Doubling
    
                % Hopf Bifurcation: Complex conjugate eigenvalues cross norm = 1
                elseif ((normPrev < 1 && normCurrent > 1) || (normPrev > 1 && normCurrent < 1)) && ...
                        (imagPrev ~= 0 || imagCurrent ~= 0)
                    crossingMatrix(i, j) = 3; % Type 3: Hopf
    
                % % Torus (Quasi-Periodic) Bifurcation: Additional eigenvalues remain on the unit circle
                % elseif isTorusBifurcation(j, threshold)
                %     crossingMatrix(i, j) = 4; % Type 4: Torus Bifurcation
                end
            end
        end
    end
    
    % Helper function to detect Torus bifurcation
    function isTorus = isTorusBifurcation(solutionIndex, threshold)
        % Check if at least two eigenvalues remain on the unit circle
        norms = eigenvalueNormMatrix(:, solutionIndex);
        imagParts = imag(eigenvalueMatrix(:, solutionIndex));
    
        % Ignore tiny imaginary parts based on threshold
        imagParts(abs(imagParts) < threshold) = 0;
    
        % Count eigenvalues near the unit circle with significant imaginary parts
        numOnCircle = sum(abs(norms - 1) < 1e-3 & abs(imagParts) > threshold);
        isTorus = numOnCircle >= 2; % At least 2 eigenvalues should stay near the unit circle
    end
    
    % Function to extract accuracy threshold from file name
    function threshold = extractAccuracyThreshold(filename)
        % Extract the part of the filename that contains the accuracy (e.g., "1e-7")
        match = regexp(filename, '\d+e-\d+', 'match');
        if ~isempty(match)
            threshold = str2double(match{1});
        else
            threshold = 1e-6; % Default value if no accuracy is specified
        end
    end



    % Function to find column indices where crossings occur and store them in crossingIndices
    function findCrossingIndices()
        crossingIndices = [];  % Reset the array

        % Loop over each column and check if there are non-zero values in that column
        for j = 1:m
            if any(crossingMatrix(:, j))  % If there is any non-zero entry in this column
                crossingIndices(end + 1) = j;  % Store the column index
            end
        end
    end

    % Function to sort eigenvalue matrix, rearrange eigenvectors, and sort eigenvalue norms
    function [sortedEigenvalues, sortedEigenvectors, sortedEigenvalueNorms] = sortEigenvaluesVectorsAndNorms(eigenvalues, eigenvectors, eigenvalueNorms, numEigenvalues, numSolutions)
        % Initialize the sorted matrix and vectors with the first solution unchanged
        sortedEigenvalues = eigenvalues;
        sortedEigenvectors = eigenvectors;
        sortedEigenvalueNorms = eigenvalueNorms;
        
        % Loop through each solution starting from the second one
        for col = 2:numSolutions
            % Extract the previous and current columns of eigenvalues
            prevColumn = sortedEigenvalues(:, col - 1);
            currentColumn = sortedEigenvalues(:, col);

            % Initialize a new column to store sorted eigenvalues
            newColumn = zeros(numEigenvalues, 1);

            % Create a flag array to check which eigenvalues are already used
            usedIndices = false(numEigenvalues, 1);

            % Store the sorting index for eigenvectors and eigenvalue norms
            sortingIndex = zeros(numEigenvalues, 1);

            % Loop through each eigenvalue in the previous column
            for i = 1:numEigenvalues
                prevEigenvalue = prevColumn(i);

                % Find the closest eigenvalue in the current column
                distances = abs(currentColumn - prevEigenvalue);
                
                % Mark already used eigenvalues as far away
                distances(usedIndices) = inf;

                % Find the index of the closest eigenvalue
                [~, closestIndex] = min(distances);

                % Assign this eigenvalue to the new column and mark it as used
                newColumn(i) = currentColumn(closestIndex);
                usedIndices(closestIndex) = true;

                % Record the sorting index
                sortingIndex(i) = closestIndex;
            end

            % Replace the current column with the sorted version
            sortedEigenvalues(:, col) = newColumn;

            % Rearrange the corresponding eigenvectors using the sorting index
            % Each cell contains a 13-column matrix of eigenvectors
            tempEigenvectors = eigenvectors{col};  % Get the matrix from the cell
            sortedEigenvectors{col} = tempEigenvectors(:, sortingIndex);  % Sort columns

            % Rearrange the eigenvalue norms using the sorting index
            sortedEigenvalueNorms(:, col) = eigenvalueNorms(sortingIndex, col);
        end
    end

    % Function to save sorted data into a new .mat file
    function saveSortedData(originalFilename)
        [~, name, ~] = fileparts(originalFilename);  % Extract the file name
        newFilename = fullfile(name + "_sorted.mat"); % Append '_sorted.mat' to the file name
        
        % Save the relevant variables to the new file
        save(newFilename, 'eigenvalueMatrix', 'eigenvectorCells', 'eigenvalueNormMatrix', 'results', 'crossingMatrix', 'crossingIndices');
        
        disp(['Sorted data saved to: ', newFilename]);
    end

    % Function to initialize the plots and eigenvalue norms display
    function initializePlots()
        % Create the left and right axes
        leftAx = axes('Units', 'normalized', 'Position', [0.05, 0.25, 0.4, 0.6]);
        hold(leftAx, 'on');

        % Extract gait information and plotting parameters
        [gait, abbr, color_plot, linetype] = Gait_Identification_Asym(results);

        % Plot the branch on the Poincare section in the left axes
        branchPlot = plot3(leftAx, results(1,:), results(5,:), results(2,:), ...
                           'LineWidth', 3, 'Color', color_plot, 'LineStyle', linetype);

        % Create a marker to indicate the current solution
        currentDot = plot3(leftAx, results(1,1), results(5,1), results(2,1), ...
                           'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k'); % Now global

        % Label axes and set view
        title(leftAx, 'Plottings of Periodic Solutions');
        xlabel(leftAx, '$\dot{q}_x  [\sqrt{gl_0}]$', 'Interpreter', 'LaTex', 'FontSize', 15);
        ylabel(leftAx, '$\dot{q}_{pitch}  [rad/s]$', 'Interpreter', 'LaTex', 'FontSize', 15);
        zlabel(leftAx, '$y [l_0]$', 'Interpreter', 'LaTex', 'FontSize', 15);
        view(leftAx, [0 90]); % Set view to top-down
        pbaspect(leftAx, [1.2 1 1]); % Aspect ratio

        % Adjust x-axis and y-axis limits based on data range
        xData = results(1,:);
        yData = results(5,:);
        minX = 0;
        maxX = max(xData);
        minY = min(yData);
        maxY = max(yData);
        yRange = max(maxY - minY, 0.1); % Minimum range of 0.1
        xlim(leftAx, [minX, maxX]);
        ylim(leftAx, [min(-0.05, minY - 0.05 * yRange), max(0.05, maxY + 0.05 * yRange)]);

        % Add legend for the left axes
        legend(leftAx, [branchPlot, currentDot], {'Solution Branch', 'Current Solution'}, 'Location', 'northeastoutside');

        % Create the right axis with the calculated position and aspect ratio
        rightAx = axes('Units', 'normalized', 'Position', [0.45, 0.25, 0.4, 0.6]);
        hold(rightAx, 'on');

        % Plot the unit circle in the right axes
        theta = linspace(0, 2*pi, 100);
        plot(rightAx, cos(theta), sin(theta), '--k', 'LineWidth', 1);

        % Set axis limits and properties for the right axes
        axis(rightAx, 'equal');
        axis(rightAx, [-1.5 1.5 -1.5 1.5]);
        xlabel(rightAx, 'Real Part');
        ylabel(rightAx, 'Imaginary Part');
        title(rightAx, 'Eigenvalues on Real/Imaginary Axes');
        grid(rightAx, 'on');

        % Use hsv color map for distinct colors in the right axes
        colors = hsv(n);

        % Initialize quiver objects for all eigenvalue entries in the right axes
        hQuiver = gobjects(n, 1); % Now global
        for i = 1:n
            hQuiver(i) = quiver(rightAx, 0, 0, 0, 0, 'AutoScale', 'off', ...
                'MaxHeadSize', 0.5, 'LineWidth', 1.5, 'Color', colors(i, :));
        end

        % Create a legend for the eigenvalue entries in the right axes
        legendEntries = arrayfun(@(x) sprintf('Eigenvalue %d', x), 1:n, 'UniformOutput', false);
        legend(rightAx, hQuiver, legendEntries, 'Location', 'bestoutside');

        % Add a single text area to display all eigenvalue norms
        normTextBox = annotation('textbox', [0.82, 0.35, 0.15, 0.5], ...
                                          'FitBoxToText', 'on', 'BackgroundColor', 'w', ...
                                          'EdgeColor', 'none', 'FontSize', 8, ...
                                          'String', '');
    end

    % Function to update the plot and eigenvalue norms based on the current solution index
    function updatePlot(index)
        if isempty(eigenvalueMatrix) || isempty(results)
            return;
        end

        % Get real and imaginary parts of the eigenvalues for the current solution
        re = real(eigenvalueMatrix(:, index));
        im = imag(eigenvalueMatrix(:, index));

        % Update each quiver with new eigenvalue data
        for i = 1:n
            set(hQuiver(i), 'UData', re(i), 'VData', im(i));
        end

        % Update the current dot position in the left axes
        set(currentDot, 'XData', results(1,index), 'YData', results(5,index), 'ZData', results(2,index));

        % Update the title with the current solution index
        title(sprintf('Eigenvalues for Solution %d', index));

        % Concatenate all eigenvalue norms into a single string for the annotation
        eigenvalueNormsForCurrentSolution = eigenvalueNormMatrix(:, index);
        normText = '';
        for i = 1:n
            normText = sprintf('%sEigenvalue %d Norm:\n%0.4f\n', normText, i, eigenvalueNormsForCurrentSolution(i));
        end

        % Update the text box with the concatenated norms
        set(normTextBox, 'String', normText);
    end

    % Function to automatically play through all solutions
    function playSolutions()
        isPlaying = true;
        set(playButton, 'String', 'Playing...');
        
        % Start from the current slider position
        for j = round(slider.Value):m
            % Check if paused or figure is closed at every iteration
            if ~isPlaying || ~isvalid(fig)
                set(playButton, 'String', 'Play');
                return;
            end
            
            % Update the slider position and plot
            slider.Value = j;
            updatePlot(j);
            
            % Allow MATLAB to process UI events (including button presses)
            drawnow;
            
            % Shorter pause to improve responsiveness
            pause(0.05); % Reduce the pause duration to improve UI responsiveness
            
            % Check if playback was paused during the iteration
            if ~isPlaying
                set(playButton, 'String', 'Play');
                return;
            end
        end
        
        % Playback is done
        isPlaying = false;
        set(playButton, 'String', 'Play');
    end

    % Function to pause the playback
    function pausePlayback()
        isPlaying = false;  % Set the flag to stop the playback
        drawnow;            % Process any pending UI events immediately
    end

    % Function to record the animation as a GIF
    function recordGif()
        gifFilename = 'eigenvalue_animation.gif';
        recording = true;
        set(recordButton, 'String', 'Recording...');
        
        % Create the GIF by looping through all solutions
        for j = 1:m
            updatePlot(j);
            drawnow; % Ensure the plot updates before capturing the frame
            frame = getframe(fig);
            img = frame2im(frame);
            [imind, cm] = rgb2ind(img, 256);

            % Write to the GIF file
            if j == 1
                imwrite(imind, cm, gifFilename, 'gif', 'Loopcount', inf, 'DelayTime', 0.1);
            else
                imwrite(imind, cm, gifFilename, 'gif', 'WriteMode', 'append', 'DelayTime', 0.1);
            end
        end
        recording = false;
        set(recordButton, 'String', 'Record GIF');
        disp(['GIF recorded and saved as ', gifFilename]);
    end

end
