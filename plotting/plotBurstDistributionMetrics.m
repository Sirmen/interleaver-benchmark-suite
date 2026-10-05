function [extractedMetrics] = plotBurstDistributionMetrics(results, methods)
    % Create improved comparison plots with proper scaling for each metric
    
    extractedMetrics = extractBurstDistributionMetrics(results, methods);
    
    % % Create a comprehensive figure with properly scaled subplots
    % figure('Name', 'Burst Distribution Performance Comparison');
    % 
    % % Strategy 1: Individual metric comparison with proper scaling
    % subplot(3,4,1);
    % % plotIndividualMetric(extractedMetrics, methods, 'eccAwareScore', 'ECC Awareness Score', true);
    % 
    % subplot(3,4,2);
    % % plotIndividualMetric(extractedMetrics, methods, 'eccComplianceImprovement', 'ECC Compliance Improvement', true);
    % 
    % subplot(3,4,3);
    % % plotIndividualMetric(extractedMetrics, methods, 'eccViolationReduction', 'ECC Violation Reduction', true);
    % 
    % subplot(3,4,4);
    % % plotIndividualMetric(extractedMetrics, methods, 'maxConcentrationReduction', 'Max Concentration Reduction', true);
    % 
    % subplot(3,4,5);
    % % plotIndividualMetric(extractedMetrics, methods, 'delta_G', 'Gini Improvement', true);
    % 
    % subplot(3,4,6);
    % % plotIndividualMetric(extractedMetrics, methods, 'varianceReduction', 'Variance Reduction', true);
    % 
    % subplot(3,4,7);
    % plotIndividualMetric(extractedMetrics, methods, 'distributionUniformityImprovement', 'Uniformity Improvement', true);
    % 
    % subplot(3,4,8);
    % plotIndividualMetric(extractedMetrics, methods, 'burstSpreadingEffectiveness', 'Spreading Effectiveness', true);
    % 
    % subplot(3,4,9);
    % % plotIndividualMetric(extractedMetrics, methods, 'after_eccMargin_min', 'ECC Margin (min)', true);
    % 
    % subplot(3,4,10);
    % % plotIndividualMetric(extractedMetrics, methods, 'after_eccUtilization', 'ECC Utilization', true);
    % 
    % subplot(3,4,11);
    % % plotIndividualMetric(extractedMetrics, methods, 'after_eccViolations', 'ECC Violations', false); % Lower is better
    % 
    % subplot(3,4,12);
    % % plotIndividualMetric(extractedMetrics, methods, 'S_ECC_norm', 'Max Noisy Points/Block', false); % Lower is better
    % 
    % sgtitle('Individual Metric Performance Comparison', 'FontSize', 12, 'FontWeight', 'bold');
    % 
    % Create a second figure for summary and ranking
    figure('Name', 'Performance Summary and Ranking');
    
    % Summary score comparison
    subplot(2,2,1);
    plotSummaryScore(extractedMetrics, methods);
    title('Overall Performance Score');
    
    % Rank-based comparison
    subplot(2,2,2);
    plotRankComparison(extractedMetrics, methods);
    title('Average Ranking');
    
    % Performance by category (normalized)
    subplot(2,2,3);
    plotCategoryPerformance(extractedMetrics, methods, 'eccCritical');
    title('ECC-Critical Metrics (Normalized)', 'FontSize', 11, 'FontWeight', 'bold');
    
    subplot(2,2,4);
    plotCategoryPerformance(extractedMetrics, methods, 'eccMargin');
    title('ECC Margin Metrics (Normalized)', 'FontSize', 11, 'FontWeight', 'bold');
    
    sgtitle('Performance Summary Analysis', 'FontSize', 12, 'FontWeight', 'bold');
end

% plotting helpers

function plotIndividualMetric(metrics, methods, metricName, titleText, higherIsBetter)
    % Plot individual metric with proper scaling and clear interpretation
    metricData = [metrics.(metricName)];
    numMethods = length(methods);
    
    % Create bar plot
    bar(metricData);
    set(gca, 'XTickLabel', methods, 'XTickLabelRotation', 45);
    title(titleText);
    ylabel('Value');
    grid on;
    
    % Add value labels on bars
    for i = 1:numMethods
        text(i, metricData(i) + max(metricData)*0.02, sprintf('%.2f', metricData(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
    end
    
    % Color code based on performance
    if higherIsBetter
        [~, bestIdx] = max(metricData);
        colors = repmat([0.7, 0.7, 0.7], numMethods, 1); % Gray for all
        colors(bestIdx, :) = [0.2, 0.6, 0.2]; % Green for best
    else
        [~, bestIdx] = min(metricData);
        colors = repmat([0.7, 0.7, 0.7], numMethods, 1); % Gray for all
        colors(bestIdx, :) = [0.2, 0.6, 0.2]; % Green for best
    end
    
    % Apply colors
    colormap(colors);
    
    % Add performance direction indicator
    if higherIsBetter
        direction = ' Higher is better';
    else
        direction = ' Lower is better';
    end
    text(0.02, 0.98, direction, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', [1, 1, 1, 0.7], 'FontSize', 8);
end

function plotCategoryPerformance(metrics, methods, category)
    % Plot normalized performance by category
    switch category
        case 'eccCritical'
            metricNames = {'eccAwareScore', 'eccComplianceImprovement', 'eccViolationReduction', 'maxConcentrationReduction'};
        case 'distributionQuality'
            metricNames = {'delta_G', 'varianceReduction', 'distributionUniformityImprovement', 'burstSpreadingEffectiveness'};
        case 'eccMargin'
            metricNames = {'after_eccMargin_min', 'after_eccUtilization', 'after_eccViolations', 'S_ECC_norm'};
    end
    
    numMetrics = length(metricNames);
    numMethods = length(methods);
    
    % Prepare normalized data
    normalizedData = zeros(numMethods, numMetrics);
    
    for i = 1:numMetrics
        metricData = [metrics.(metricNames{i})];
        % Determine direction and normalize
        if contains(metricNames{i}, {'Violation', 'noisyPoints'})
            % Lower is better
            normalizedData(:, i) = 1 - ((metricData - min(metricData)) / (max(metricData) - min(metricData) + eps));
        else
            % Higher is better
            normalizedData(:, i) = (metricData - min(metricData)) / (max(metricData) - min(metricData) + eps);
        end
    end
    
    % Calculate average normalized performance per method
    avgPerformance = mean(normalizedData, 2);
    
    % Sort methods by performance (descending - higher is better)
    [sortedPerformance, sortIdx] = sort(avgPerformance, 'descend');
    sortedMethods = methods(sortIdx);
    
    % Plot horizontal bars for better label visibility
    barh(sortedPerformance, 'BarWidth', 0.7);
    
    % Set method names as y-tick labels
    ax = gca;
    ax.YTick = 1:numMethods;
    ax.YTickLabel = sortedMethods;
    ax.YAxis.FontSize = 10; % Larger font for method names
    ax.XAxis.FontSize = 10;
    
    xlabel('Normalized Performance (0-1)', 'FontSize', 12);
    xlim([0 1]);
    grid on;
    
    % Add value labels on bars
    for i = 1:numMethods
        if sortedPerformance(i) > 0.1 % Only add text if bar is reasonably long
            text(sortedPerformance(i) - (sortedPerformance(i) * 0.15), i, sprintf('%.2f', sortedPerformance(i)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', 'Color', 'white', 'FontSize', 9);
        else
            % For very short bars, place text outside
            text(sortedPerformance(i) + 0.02, i, sprintf('%.2f', sortedPerformance(i)), ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', 'Color', 'black', 'FontSize', 9);
        end
    end
    
    % Add title
    title(['Performance Comparison - ' category ' (Sorted by Performance)'], 'FontSize', 12, 'FontWeight', 'bold');
end

function plotRankComparison(metrics, methods)
    % Rank-based comparison
    allMetrics = fieldnames(metrics);
    numMetrics = length(allMetrics);
    numMethods = length(methods);
    ranks = zeros(numMethods, numMetrics);
    
    for i = 1:numMetrics
        metricData = [metrics.(allMetrics{i})];
        if contains(allMetrics{i}, {'Violation', 'noisyPoints'})
            [~, sortedIndices] = sort(metricData, 'ascend');
        else
            [~, sortedIndices] = sort(metricData, 'descend');
        end
        for j = 1:numMethods
            ranks(sortedIndices(j), i) = j;
        end
    end
    
    avgRanks = mean(ranks, 2);
    
    % Sort methods by average rank (ascending - lower is better)
    [sortedRanks, sortIdx] = sort(avgRanks, 'descend');
    sortedMethods = methods(sortIdx);
    
    % Plot horizontal bars for better label visibility
    barh(sortedRanks, 'BarWidth', 0.7);
    
    % Set method names as y-tick labels
    ax = gca;
    ax.YTick = 1:numMethods;
    ax.YTickLabel = sortedMethods;
    ax.YAxis.FontSize = 10; % Larger font for method names
    ax.XAxis.FontSize = 10;
    
    xlabel('Average Rank', 'FontSize', 12);
    grid on;
    
    % Add value labels on bars
    for i = 1:numMethods
        if sortedRanks(i) > max(sortedRanks) * 0.15 % Only add text inside if bar is reasonably long
            text(sortedRanks(i) - (sortedRanks(i) * 0.15), i, sprintf('%.2f', sortedRanks(i)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', 'Color', 'white', 'FontSize', 9);
        else
            % For very short bars, place text outside
            text(sortedRanks(i) + max(sortedRanks) * 0.02, i, sprintf('%.2f', sortedRanks(i)), ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', 'Color', 'black', 'FontSize', 9);
        end
    end
    
    % Add title
    title('Average Ranking Comparison (Sorted by Performance)', 'FontSize', 12, 'FontWeight', 'bold');
end

function plotSummaryScore(metrics, methods)
    % Overall performance score
    allMetrics = fieldnames(metrics);
    numMetrics = length(allMetrics);
    numMethods = length(methods);
    scores = zeros(numMethods, 1);
    
    for i = 1:numMetrics
        metricData = [metrics.(allMetrics{i})];
        if contains(allMetrics{i}, {'Violation', 'noisyPoints'})
            normalized = 1 - ((metricData - min(metricData)) / (max(metricData) - min(metricData) + eps));
        else
            normalized = (metricData - min(metricData)) / (max(metricData) - min(metricData) + eps);
        end
        scores = scores + normalized';
    end
    
    scores = (scores / numMetrics) * 100;
    
    % Sort methods by score (descending - higher is better)
    [sortedScores, sortIdx] = sort(scores, 'descend');
    sortedMethods = methods(sortIdx);
    
    % Plot horizontal bars for better label visibility
    barh(sortedScores, 'BarWidth', 0.7);
    
    % Set method names as y-tick labels
    ax = gca;
    ax.YTick = 1:numMethods;
    ax.YTickLabel = sortedMethods;
    ax.YAxis.FontSize = 10; % Larger font for method names
    ax.XAxis.FontSize = 10;
    
    xlabel('Overall Score (%)', 'FontSize', 12);
    xlim([0 100]);
    grid on;
    
    % Add value labels on bars
    for i = 1:numMethods
        if sortedScores(i) > 15 % Only add text inside if bar is reasonably long (>15%)
            text(sortedScores(i) - (sortedScores(i) * 0.15), i, sprintf('%.1f', sortedScores(i)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', 'Color', 'white', 'FontSize', 9);
        else
            % For very short bars, place text outside
            text(sortedScores(i) + 2, i, sprintf('%.1f', sortedScores(i)), ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', 'Color', 'black', 'FontSize', 9);
        end
    end
    
    % Add title
    title('Overall Performance Score (Sorted by Score)', 'FontSize', 12, 'FontWeight', 'bold');
end

function plotParallelCoordinates(metrics, methods)
    % Use parallel coordinates plot as an alternative to radar chart
    keyMetrics = {'eccAwareScore', 'eccComplianceImprovement', 'delta_G', ...
                 'varianceReduction', 'after_eccMargin_min', 'burstSpreadingEffectiveness'};
    
    numMetrics = length(keyMetrics);
    numMethods = length(methods);
    
    % Prepare normalized data (0-1, where 1 is best)
    data = zeros(numMethods, numMetrics);
    metricLabels = cell(1, numMetrics);
    
    for i = 1:numMetrics
        metricData = [metrics.(keyMetrics{i})];
        metricLabels{i} = keyMetrics{i};
        
        % Determine if higher is better (most metrics) or lower is better
        if contains(keyMetrics{i}, {'Violation', 'noisyPoints'})
            % For these, lower values are better
            data(:, i) = 1 - ((metricData - min(metricData)) / (max(metricData) - min(metricData) + eps));
        else
            % For most metrics, higher values are better
            data(:, i) = (metricData - min(metricData)) / (max(metricData) - min(metricData) + eps);
        end
    end
    
    % Create parallel coordinates plot
    parallelcoords(data, 'Group', categorical(repmat(methods', 1, 1)), ...
                  'Labels', metricLabels, 'Quantile', 0.25);
    legend(methods, 'Location', 'bestoutside');
    ylim([0 1]);
    ylabel('Normalized Performance (1 = Best)');
end

function plotMetricGroupNormalized(metrics, metricNames, methods, titleText)
    % Normalize each metric to 0-1 scale for better comparison
    numMetrics = length(metricNames);
    numMethods = length(methods);
    
    % Prepare data matrix
    data = zeros(numMethods, numMetrics);
    for i = 1:numMetrics
        metricData = [metrics.(metricNames{i})];
        
        % Normalize to 0-1 range (handle negative values if needed)
        if all(metricData >= 0)
            % For positive-only metrics
            if max(metricData) > 0
                data(:, i) = metricData / max(metricData);
            else
                data(:, i) = zeros(size(metricData));
            end
        else
            % For metrics that can be negative
            minVal = min(metricData);
            maxVal = max(metricData);
            if maxVal - minVal > 0
                data(:, i) = (metricData - minVal) / (maxVal - minVal);
            else
                data(:, i) = zeros(size(metricData));
            end
        end
    end
    
    % Create grouped bar plot
    bar(data, 'grouped');
    set(gca, 'XTickLabel', methods, 'XTickLabelRotation', 45);
    title(titleText);
    ylabel('Normalized Performance (0-1)');
    legend(metricNames, 'Location', 'bestoutside');
    grid on;
end

function plotSummaryLineChart(metrics, metricNames, methods, titleText)
    % Create line plot for comparing methods across key metrics
    numMetrics = length(metricNames);
    numMethods = length(methods);
    
    % Prepare data matrix (normalized)
    data = zeros(numMethods, numMetrics);
    for i = 1:numMetrics
        metricData = [metrics.(metricNames{i})];
        
        % Normalize each metric separately
        if all(metricData >= 0)
            if max(metricData) > 0
                data(:, i) = metricData / max(metricData);
            else
                data(:, i) = zeros(size(metricData));
            end
        else
            minVal = min(metricData);
            maxVal = max(metricData);
            if maxVal - minVal > 0
                data(:, i) = (metricData - minVal) / (maxVal - minVal);
            else
                data(:, i) = zeros(size(metricData));
            end
        end
    end
    
    % Create line plot
    colors = lines(numMethods);
    hold on;
    for i = 1:numMethods
        plot(1:numMetrics, data(i, :), 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', colors(i, :), 'DisplayName', methods{i});
    end
    
    set(gca, 'XTick', 1:numMetrics, 'XTickLabel', metricNames, 'XTickLabelRotation', 45);
    title(titleText);
    ylabel('Normalized Performance (0-1)');
    xlabel('Metrics');
    legend('Location', 'bestoutside');
    grid on;
    ylim([0 1.1]);
    hold off;
end

%% extraction helpers

function [extractedMetrics] = extractBurstDistributionMetrics(stats_all, methods)
    % Extract burst distribution metrics from results structure for analysis
    
    numMethods = length(methods);
    extractedMetrics = struct();
    
    % Initialize arrays for each metric
    metricNames = {
        'eccAwareScore', 'eccComplianceImprovement', 'eccViolationReduction',...
        'maxConcentrationReduction', 'delta_G', 'varianceReduction',...
        'distributionUniformityImprovement', 'burstSpreadingEffectiveness',...
        'after_eccMargin_min', 'after_eccUtilization', 'before_eccViolations',...
        'after_eccViolations', 'S_ECC_norm',...
        'after_noisyPointsPerBlock_avg', 'after_blockOccupancyRatio'
    };
    
    % Initialize metric arrays
    for i = 1:length(metricNames)
        extractedMetrics.(metricNames{i}) = zeros(1, numMethods);
    end
    
    % Extract values for each method
    for methodIdx = 1:numMethods
        methodName = methods{methodIdx};
        
        % Find all entries for this method
        % allMethodIndices = find(strcmp(string({results.stats_all.method}), methodName));
        allMethodIndices = find(strcmp(string({stats_all.method}), methodName));
        
        if isempty(allMethodIndices)
            fprintf('Warning: No data found for method %s\n', methodName);
            continue;
        end
        
        % Initialize arrays to collect values from all runs for this method
        methodMetrics = struct();
        for j = 1:length(metricNames)
            methodMetrics.(metricNames{j}) = [];
        end
        
        % Collect values from all runs for this method
        for runIdx = 1:length(allMethodIndices)
            i = allMethodIndices(runIdx);
            
            try
                if isfield(stats_all(i), 'burstDistribution') && ~isempty(stats_all(i).burstDistribution)
                    bd = stats_all(i).burstDistribution;
                    
                    % Collect each metric value, ensuring scalar output
                    methodMetrics.eccAwareScore(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'eccAwareScore', 0)));
                    methodMetrics.eccComplianceImprovement(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'eccComplianceImprovement', 0)));
                    methodMetrics.eccViolationReduction(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'eccViolationReduction', 0)));
                    methodMetrics.maxConcentrationReduction(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'maxConcentrationReduction', 0)));
                    methodMetrics.delta_G(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'delta_G', 0)));
                    methodMetrics.varianceReduction(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'varianceReduction', 0)));
                    methodMetrics.distributionUniformityImprovement(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'distributionUniformityImprovement', 0)));
                    methodMetrics.burstSpreadingEffectiveness(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'burstSpreadingEffectiveness', 0)));
                    methodMetrics.after_eccMargin_min(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'after_eccMargin_min', 0)));
                    methodMetrics.after_eccUtilization(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'after_eccUtilization', 0)));
                    methodMetrics.before_eccViolations(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'before_eccViolations', 0)));
                    methodMetrics.after_eccViolations(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd, 'after_eccViolations', 0)));
                    
                    % Handle nested 'after' struct fields
                    if isfield(bd, 'after') && isstruct(bd.after)
                        methodMetrics.S_ECC_norm(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd.after, 'noisyPointsPerBlock_max', 0)));
                        methodMetrics.after_noisyPointsPerBlock_avg(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd.after, 'noisyPointsPerBlock_avg', 0)));
                        methodMetrics.after_blockOccupancyRatio(end+1) = ensureScalar(handleInfNaN(getFieldSafe(bd.after, 'blockOccupancyRatio', 0)));
                    else
                        methodMetrics.S_ECC_norm(end+1) = 0;
                        methodMetrics.after_noisyPointsPerBlock_avg(end+1) = 0;
                        methodMetrics.after_blockOccupancyRatio(end+1) = 0;
                    end
                end
            catch ME
                fprintf('Warning: Error extracting burst metrics for method %s, run %d: %s\n', methodName, runIdx, ME.message);
            end
        end
        
        % Calculate average for each metric across all runs
        for j = 1:length(metricNames)
            metricName = metricNames{j};
            if ~isempty(methodMetrics.(metricName))
                extractedMetrics.(metricName)(methodIdx) = mean(methodMetrics.(metricName), 'omitnan');
            else
                extractedMetrics.(metricName)(methodIdx) = 0;
            end
        end
    end
end

function [value] = getFieldSafe(structure, fieldName, defaultValue)
    % Safely get field value with default fallback
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end

function [cleanValue] = handleInfNaN(value)
try
    % Handle Inf, NaN, and empty values for plotting/correlation analysis
    % Now handles both scalar and array inputs
    
    if isempty(value)
        cleanValue = 0; % Use 0 as default for empty
        return;
    end
    
    % For array inputs, process each element
    if ~isscalar(value)
        cleanValue = zeros(size(value));
        for i = 1:numel(value)
            cleanValue(i) = handleInfNaNScalar(value(i));
        end
    else
        cleanValue = handleInfNaNScalar(value);
    end
    
catch errhin
   fprintf('err in handleInfNaN: %s\n', errhin.message);
   if ~isempty(value)
      fprintf('... value type: %s, size: %s\n', class(value), mat2str(size(value)));
      if numel(value) <= 10
          fprintf('... value: '); 
          disp(value);
      end
   end
   cleanValue = 0; % Fallback
end
end

function cleanValue = handleInfNaNScalar(value)
% Handle scalar values only
    if isempty(value) || any(isinf(value)) || any(isnan(value))
        cleanValue = 0; % Use 0 as default
    else
        cleanValue = double(value); % Ensure numeric type
    end
end

function scalarValue = ensureScalar(value)
    % Ensure the output is always a scalar
    if isempty(value)
        scalarValue = 0;
    elseif ~isscalar(value)
        % If it's an array, take the mean or first element
        if isnumeric(value)
            scalarValue = mean(value(:), 'omitnan');
            if isnan(scalarValue)
                scalarValue = 0;
            end
        else
            scalarValue = 0;
        end
    else
        scalarValue = value;
    end
end