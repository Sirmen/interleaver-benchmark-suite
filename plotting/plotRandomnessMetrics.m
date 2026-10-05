function plotRandomnessMetrics(stats_all, methods)
% Comprehensive randomness dashboard - horizontal bars
    
    figure('Name', 'Randomness Metrics'); % , 'Position', [100 100 1400 900]);
    
    % Combined score
    subplot(2, 3, 1);
    data = extractMetricData(stats_all, methods, 'randomnessCombinedScore');
    [sortedData, sortIdx] = sort(data, 'descend');
    sortedMethods = methods(sortIdx);
    
    barh(sortedData, 'FaceColor', [0.5 0.3 0.7]);
    set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
    xlabel('Combined Score');
    title('Overall Randomness Score', 'FontSize', 10);
    grid on;
    xlim([0 1]);
    
    for k = 1:length(sortedData)
        if ~isnan(sortedData(k))
            text(sortedData(k) * 1.05, k, sprintf('%.3f', sortedData(k)), ...
                 'FontSize', 7, 'VerticalAlignment', 'middle');
        end
    end
    
    % Aperiodicity
    subplot(2, 3, 2);
    data = extractMetricData(stats_all, methods, 'aperiodicityScore');
    [sortedData, sortIdx] = sort(data, 'descend');
    sortedMethods = methods(sortIdx);
    
    barh(sortedData, 'FaceColor', [0.3 0.7 0.5]);
    set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
    xlabel('Aperiodicity Score');
    title('Aperiodicity (Higher = Better)', 'FontSize', 10);
    grid on;
    xlim([0 1]);
    
    for k = 1:length(sortedData)
        if ~isnan(sortedData(k))
            text(sortedData(k) * 1.05, k, sprintf('%.3f', sortedData(k)), ...
                 'FontSize', 7, 'VerticalAlignment', 'middle');
        end
    end
    
    % Laplacian Energy
    subplot(2, 3, 3);
    data = extractMetricData(stats_all, methods, 'laplacianEnergy');
    [sortedData, sortIdx] = sort(data, 'descend');
    sortedMethods = methods(sortIdx);
    
    barh(sortedData, 'FaceColor', [0.7 0.3 0.3]);
    set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
    xlabel('Laplacian Energy');
    title('Structural Randomness', 'FontSize', 10);
    grid on;
    
    for k = 1:length(sortedData)
        if ~isnan(sortedData(k))
            text(sortedData(k) * 1.05, k, sprintf('%.3f', sortedData(k)), ...
                 'FontSize', 7, 'VerticalAlignment', 'middle');
        end
    end
    
    % Spread Factor
    subplot(2, 3, 4);
    data = extractMetricData(stats_all, methods, 'spreadFactor');
    [sortedData, sortIdx] = sort(data, 'descend');
    sortedMethods = methods(sortIdx);
    
    barh(sortedData, 'FaceColor', [0.2 0.5 0.8]);
    set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
    xlabel('Spread Factor');
    title('2D Minimum Distance', 'FontSize', 10);
    grid on;
    
    for k = 1:length(sortedData)
        if ~isnan(sortedData(k))
            text(sortedData(k) * 1.05, k, sprintf('%.2f', sortedData(k)), ...
                 'FontSize', 7, 'VerticalAlignment', 'middle');
        end
    end
    
    % Block Transition Diversity
    subplot(2, 3, 5);
    data = extractMetricData(stats_all, methods, 'blockTransitionDiversity');
    [sortedData, sortIdx] = sort(data, 'descend');
    sortedMethods = methods(sortIdx);
    
    barh(sortedData, 'FaceColor', [0.8 0.6 0.2]);
    set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
    xlabel('Transition Diversity');
    title('Block Transition Coverage', 'FontSize', 10);
    grid on;
    xlim([0 1]);
    
    for k = 1:length(sortedData)
        if ~isnan(sortedData(k))
            text(sortedData(k) * 1.05, k, sprintf('%.3f', sortedData(k)), ...
                 'FontSize', 7, 'VerticalAlignment', 'middle');
        end
    end
    
    % Scatter: Aperiodicity vs Laplacian
    subplot(2, 3, 6);
    aperiodicity = extractMetricData(stats_all, methods, 'aperiodicityScore');
    laplacian = extractMetricData(stats_all, methods, 'laplacianEnergy');
    scatter(aperiodicity, laplacian, 100, 'filled', 'MarkerFaceAlpha', 0.6);
    xlabel('Aperiodicity Score');
    ylabel('Laplacian Energy');
    title('Aperiodicity vs Structural Randomness', 'FontSize', 10);
    grid on;
    for i = 1:length(methods)
        text(aperiodicity(i), laplacian(i), ['  ' methods{i}], 'FontSize', 8);
    end
    
    sgtitle('Permutation Randomness & Structure', 'FontSize', 14, 'FontWeight', 'bold');
end
