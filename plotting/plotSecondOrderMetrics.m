function plotSecondOrderMetrics(stats_all, methods)
% Focuses on worst-case local constraints (Second-Order properties)
    fig = figure('Name', 'Framework: Second-Order/Local Metrics');
    
    metrics = {'MinminBlock', 'adjMin'};
    titles = {'MinminBlock: Codeword Diversity', ...
              'd_{adj,min}: Local Adjacency'};
    % colors = [0.2 0.2 0.6; 0.6 0.2 0.2; 0.4 0.4 0.4];
    
    t = tiledlayout(1, 2, 'TileSpacing', 'compact');
    set(fig, 'Color', 'w'); %, 'Position', [100, 100, 1200, 800]);
    
    for i = 1:2
        nexttile;
        data = extractMetricData(stats_all, methods, metrics{i});
        
        [sortedData, sortIdx] = sort(data, 'descend');
        b = bar(sortedData, 'FaceColor', 'flat'); % colors(i,:));
        b.CData = parula(length(sortedData)); 
        set(gca, 'XTick', 1:length(methods), 'XTickLabel', methods(sortIdx));
        title(titles{i}, 'FontSize', 10);
        grid on;
    end
end