function plotErrorSpreadingMetrics(stats_all, methods)
% Error spreading and burst diversity metrics - horizontal bars
    
    figure('Name', 'Error Spreading Metrics'); % , 'Position', [100 100 1400 600]);
    
    metrics = {'errorSpreadingEfficiency', 'blockOccupancyRatio', 'burstSpreadingDiversity'};
    titles = {'Error Spreading Efficiency', 'Block Occupancy Ratio', 'Burst Spreading Diversity'};
    colors = [0.2 0.6 0.8; 0.8 0.4 0.2; 0.4 0.8 0.4];
    
    for i = 1:3
        subplot(1, 3, i);
        data = extractMetricData(stats_all, methods, metrics{i});
        
        [sortedData, sortIdx] = sort(data, 'descend');
        sortedMethods = methods(sortIdx);
        
        barh(sortedData, 'FaceColor', colors(i,:));
        set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
        xlabel(titles{i});
        title(titles{i}, 'FontSize', 10);
        grid on;
        xlim([0 1]);
        
        % Add threshold line
        xline(0.75, 'm--', 'Optimal', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
        
        % Add value labels
        for k = 1:length(sortedData)
            if ~isnan(sortedData(k))
                text(sortedData(k) * 1.05, k, sprintf('%.3f', sortedData(k)), ...
                     'FontSize', 8, 'VerticalAlignment', 'middle');
            end
        end
    end
    
    sgtitle('Burst Spreading Effectiveness', 'FontSize', 14, 'FontWeight', 'bold');
end
