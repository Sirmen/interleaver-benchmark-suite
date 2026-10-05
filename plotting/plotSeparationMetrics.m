function plotSeparationMetrics(stats_all, methods)
% Comprehensive separation analysis - horizontal bars
    
    figure('Name', 'Separation Metrics'); % , 'Position', [100 100 1400 800]);
    
    metrics = {'sepMin', 'sepAvg', 'sepCV', 'eta_sep'};
    titles = {'Sep Min (Higher = Better)', 'Sep Avg', 'Sep CV (Lower = Better)', 'Sep Efficiency'};
    colors = [0.7 0.4 0.4; 0.4 0.7 0.4; 0.4 0.4 0.7; 0.7 0.6 0.3];
    
    for i = 1:4
        subplot(2, 2, i);
        data = extractMetricData(stats_all, methods, metrics{i});
        
        [sortedData, sortIdx] = sort(data, 'descend');
        sortedMethods = methods(sortIdx);
        
        barh(sortedData, 'FaceColor', colors(i,:));
        set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
        xlabel(titles{i});
        title(titles{i}, 'FontSize', 10);
        grid on;
        
        if i == 4 % Efficiency is 0-1
            xlim([0 1]);
        end
        
        % Add value labels
        for k = 1:length(sortedData)
            if ~isnan(sortedData(k)) && isfinite(sortedData(k))
                text(sortedData(k) * 1.05, k, sprintf('%.3f', sortedData(k)), ...
                     'FontSize', 8, 'VerticalAlignment', 'middle');
            end
        end
    end
    
    sgtitle('Separation Metrics (Value-Based Dispersion)', ...
        'FontSize', 14, 'FontWeight', 'bold');
end