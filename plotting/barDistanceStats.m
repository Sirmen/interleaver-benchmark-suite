function barDistanceStats(distAll, intMethods, distances)
try
    % Extract distance data
    % rows are metrics, cols are methods
    nMethod = length(intMethods);
    dData = zeros(length(distances), nMethod);
    
    for i = 1:nMethod
        [methodData, erM] = extractDistanceData(distAll, intMethods{i}, distances);
        if ~isempty(erM)
            error(erM);
        end
        dData(:,i) = methodData;
    end
    % Define metrics to exclude from each subplot
    excludeFromGeneral = {'Hblock', 'Hsep', 'Htrans'};
    excludeFromNoiseBurst = {'before_eccViolations', 'Hnoise'};
    % Separate metrics into groups
    % Core Performance
    corePerformanceMetrics = {
        'effectiveness', 'cont', 'noise', 'decodeErrRate'
    };
    
    % Burst Distribution
    burstSpreadMetrics = {
        'errorSpreadingEfficiency', 'blockOccupancyRatio', 'burstSpreadingDiversity', ...
        'before_noisyPointsPerBlock_max', 'S_ECC_norm', ...
        'after_noisyPointsPerBlock_avg', 'noisyBlocksCount', ...
        'noiseDistMin', 'noiseDistAvg', 'noiseDistVar', 'noiseUniformity', 'Hnoise'
    };

    createMetricFigure(burstSpreadMetrics, dData, distances, intMethods, ...
                       'Burst Distribution');
catch errdm
    fprintf('Error in barDistanceStats: %s\n', errdm.message);
    rethrow(errdm);
end
end

function createMetricFigure(metricNames, dData, allDistances, intMethods, figureTitle)
% Create horizontal bar chart figure for a group of metrics
try    
    % Find indices of metrics that exist in the distances list
    [~, metricIndices] = ismember(metricNames, allDistances);
    metricIndices = metricIndices(metricIndices > 0); % Remove zeros (non-existent metrics)
    
    if isempty(metricIndices)
        fprintf('Warning: No metrics found for "%s"\n', figureTitle);
        return;
    end
    
    nDist = length(metricIndices);
    fig = figure('Name', figureTitle); % , 'Position', [100 100 1400 900]);
    
    % Calculate layout
    rowCount = min(3, nDist);
    colCount = ceil(nDist / rowCount);
    
    t = tiledlayout(fig, rowCount, colCount, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    for idx = 1:nDist
        d = metricIndices(idx);
        dist = string(allDistances{d});
        
        nexttile;
        
        y = dData(d, :); 
        
        % Check if all values are NaN
        if all(isnan(y))
            text(0.5, 0.5, 'Data not available', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'Color', 'red');
            title([dist ' (Missing)'], 'Interpreter', 'none', 'Color', 'red', 'FontSize', 9);
            axis off;
            continue;
        end
        
        % Sort by value
        [y_Sorted, sortIdx] = sort(y, 'descend');
        x = intMethods(sortIdx); 
        
        % Horizontal bars
        b = barh(y_Sorted, 'BarWidth', 0.7);
        hold on, grid on;
        
        % Colorize bars based on value (optional - makes it prettier)
        colormap(parula);
        cmap = parula(length(y_Sorted));
        [~, colorIdx] = sort(y_Sorted);
        for k = 1:length(b.YData)
            b.CData(k,:) = cmap(find(colorIdx == k),:);
        end
        
        % Set y-tick labels to method names
        ax = gca;
        ax.YTick = 1:length(x);
        ax.YTickLabel = x;
        ax.YAxis.FontSize = 9;
        ax.YAxis.FontAngle = 'italic';  
        ax.XAxis.FontSize = 8;
        
        title(dist, 'Interpreter', 'none', 'FontSize', 9, 'FontWeight', 'normal');
        
        % Safe xlim setting
        validValues = y_Sorted(~isnan(y_Sorted) & isfinite(y_Sorted));
        
        if ~isempty(validValues)
            xMin_data = min(validValues);
            xMax_data = max(validValues);
        
            dataRange = xMax_data - xMin_data;
            
            % If the range is zero (all values are the same), give a small default range
            if dataRange == 0
                dataRange = 1; 
            end
        
            % Calculate padding based on the data range
            padding = dataRange * 0.2;
            
            xMin = xMin_data - padding;
            xMax = xMax_data + padding;
        
            % If data is entirely positive, ensure xMin doesn't go below 0
           if xMin_data >= 0
              xMin = max(0, xMin); 
           end

           % If data is entirely negative, ensure xMax doesn't go above 0
           if xMax_data <= 0
              xMax = min(0, xMax);
           end
            
           xlim([xMin xMax]);
        else
            % Default limits if no valid data is present
            xlim([0 1]);
        end

        % Add value labels on bars 
        for k = 1:length(y_Sorted)
            val = y_Sorted(k);
            if ~isnan(val) && isfinite(val)
                % Position calculation for horizontal bar (x-coordinate is the value, y-coordinate is the index k)
                
                % Offset calculation: adjust based on the sign of the value
                % Padding text outside the bar
                textOffset = dataRange * 0.01; 
                
                if val >= 0
                    % For positive bars, place text slightly right of the bar's end
                    xPos = val + textOffset;
                    alignment = 'left';
                else
                    % For negative bars, place text slightly left of the bar's end
                    xPos = val - textOffset;
                    alignment = 'right';
                end
                
                text(xPos, k, sprintf('%.3f', val), ...
                     'HorizontalAlignment', alignment, ...
                     'VerticalAlignment', 'middle', ...
                     'FontSize', 9, 'FontAngle', 'italic');
            end
        end

    end
    
    title(t, figureTitle, 'FontSize', 13, 'FontWeight', 'bold');
catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
    fprintf(strcat('\n ** ', erM, '\n'));
end
end