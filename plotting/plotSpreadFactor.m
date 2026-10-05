function plotSpreadFactor(stats_all, methods)
% 2D minimum distance visualization - horizontal bars for better readability
    
    figure('Name', 'Spread Factor'); % , 'Position', [100 100 1000 700]);
    
    data = extractMetricData(stats_all, methods, 'spreadFactor');
    
    % Sort data for better visualization
    [sortedData, sortIdx] = sort(data, 'descend');
    sortedMethods = methods(sortIdx);
    
    % Subplot 1: Absolute values
    subplot(1, 2, 1);
    bar(sortedData, 'FaceColor', [0.4 0.6 0.9]);
    set(gca, 'XTick', 1:length(sortedMethods));
    set(gca, 'XTickLabel', sortedMethods, 'FontSize', 10);
    % set(gca, 'YDir', 'reverse'); % Best at top
    ylabel('Spread Factor', 'FontSize', 10);
    title('2D Minimum Distance (Higher = Better)', 'FontSize', 10);
    grid on;
    
    % % Add value labels
    % for k = 1:length(sortedData)
    %     if ~isnan(sortedData(k)) && sortedData(k) > 0
    %         text(sortedData(k) * 1.05, k, sprintf('%.2f', sortedData(k)), ...
    %              'FontSize', 8, 'VerticalAlignment', 'middle');
    %     end
    % end
    
    % Subplot 2: Normalized (relative to best)
    subplot(1, 2, 2);
    ideal = max(data);
    normalizedSorted = sortedData / ideal;
    
    bar(normalizedSorted, 'FaceColor', [0.6 0.8 0.4]);
    set(gca, 'XTick', 1:length(sortedMethods));
    set(gca, 'XTickLabel', sortedMethods, 'FontSize', 10);
    % set(gca, 'YDir', 'reverse'); % Best at top
    ylabel('Normalized Spread Factor', 'FontSize', 10);
    title('Relative to Best Method', 'FontSize', 10);
    grid on;
    ylim([0 1]);
    
    % Add threshold line
    yline(0.8, 'm--', 'Good', 'LineWidth', 1.5, ...
          'LabelHorizontalAlignment', 'left');
    
    % % Add value labels
    % for k = 1:length(normalizedSorted)
    %     if ~isnan(normalizedSorted(k))
    %         text(normalizedSorted(k) * 1.05, k, sprintf('%.2f', normalizedSorted(k)), ...
    %              'FontSize', 8, 'VerticalAlignment', 'middle');
    %     end
    % end
    
    sgtitle('Spread Factor Analysis (Benedetto & Montorsi 1996)', ...
        'FontSize', 12, 'FontWeight', 'bold');
end
