function plotTransitionMetrics(stats_all, methods)
% Transition entropy and diversity - horizontal bars
    
    figure('Name', 'Transition Metrics'); % , 'Position', [100 100 1200 600]);
    
    % Transition Entropy
    subplot(1, 2, 1);
    transEntropy = extractMetricData(stats_all, methods, 'transitionEntropy');
    [sortedData, sortIdx] = sort(transEntropy, 'descend');
    sortedMethods = methods(sortIdx);
    
    barh(sortedData, 'FaceColor', [0.7 0.5 0.6]);
    set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
    xlabel('Transition Entropy');
    title('Local Pattern Entropy');
    grid on;
    
    for k = 1:length(sortedData)
        if ~isnan(sortedData(k)) && sortedData(k) > 0
            text(sortedData(k) * 1.02, k, sprintf('%.3f', sortedData(k)), ...
                 'FontSize', 8, 'VerticalAlignment', 'middle');
        end
    end
    
    % Block Transition Diversity
    subplot(1, 2, 2);
    blockTransDiv = extractMetricData(stats_all, methods, 'blockTransitionDiversity');
    [sortedData, sortIdx] = sort(blockTransDiv, 'descend');
    sortedMethods = methods(sortIdx);
    
    barh(sortedData, 'FaceColor', [0.5 0.7 0.6]);
    set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
    xlabel('Block Transition Diversity');
    title('Block Jump Coverage');
    grid on;
    xlim([0 1]);
    
    for k = 1:length(sortedData)
        if ~isnan(sortedData(k)) && sortedData(k) > 0
            text(sortedData(k) * 1.05, k, sprintf('%.3f', sortedData(k)), ...
                 'FontSize', 8, 'VerticalAlignment', 'middle');
        end
    end
    
    sgtitle('Transition Analysis', 'FontSize', 14, 'FontWeight', 'bold');
end