function plotPeriodicityAnalysis(stats_all, methods)
% Detailed periodicity analysis - horizontal bars
    
    figure('Name', 'Periodicity Analysis'); % , 'Position', [100 100 1400 900]);
    
    % Number of peaks
    subplot(2, 2, 1);
    data = extractMetricData(stats_all, methods, 'periodicityNumPeaks');
    [sortedData, sortIdx] = sort(data, 'descend');
    sortedMethods = methods(sortIdx);
    
    barh(sortedData, 'FaceColor', [0.7 0.4 0.5]);
    set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
    xlabel('Number of Peaks');
    title('Autocorrelation Peaks');
    grid on;
    
    for k = 1:length(sortedData)
        if ~isnan(sortedData(k))
            text(sortedData(k) * 1.05, k, sprintf('%.0f', sortedData(k)), ...
                 'FontSize', 8, 'VerticalAlignment', 'middle');
        end
    end
    
    % Max peak magnitude
    subplot(2, 2, 2);
    data = extractMetricData(stats_all, methods, 'periodicityMaxPeak');
    [sortedData, sortIdx] = sort(data, 'descend');
    sortedMethods = methods(sortIdx);
    
    barh(sortedData, 'FaceColor', [0.5 0.6 0.7]);
    set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
    xlabel('Max Peak Magnitude');
    title('Strongest Periodic Component');
    grid on;
    
    for k = 1:length(sortedData)
        if ~isnan(sortedData(k))
            text(sortedData(k) * 1.05, k, sprintf('%.3f', sortedData(k)), ...
                 'FontSize', 8, 'VerticalAlignment', 'middle');
        end
    end
    
    % Peak energy
    subplot(2, 2, 3);
    data = extractMetricData(stats_all, methods, 'periodicityPeakEnergy');
    [sortedData, sortIdx] = sort(data, 'descend');
    sortedMethods = methods(sortIdx);
    
    barh(sortedData, 'FaceColor', [0.6 0.5 0.4]);
    set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
    xlabel('Peak Energy');
    title('Total Periodic Energy');
    grid on;
    
    for k = 1:length(sortedData)
        if ~isnan(sortedData(k))
            text(sortedData(k) * 1.05, k, sprintf('%.3f', sortedData(k)), ...
                 'FontSize', 8, 'VerticalAlignment', 'middle');
        end
    end
    
    % Scatter plot
    subplot(2, 2, 4);
    numPeaks = extractMetricData(stats_all, methods, 'periodicityNumPeaks');
    maxPeak = extractMetricData(stats_all, methods, 'periodicityMaxPeak');
    scatter(numPeaks, maxPeak, 100, 'filled', 'MarkerFaceAlpha', 0.6);
    xlabel('Number of Peaks');
    ylabel('Max Peak Magnitude');
    title('Periodicity Profile');
    grid on;
    for i = 1:length(methods)
        text(numPeaks(i), maxPeak(i), ['  ' methods{i}], 'FontSize', 8);
    end
    
    sgtitle('Detailed Periodicity Analysis', 'FontSize', 14, 'FontWeight', 'bold');
end
