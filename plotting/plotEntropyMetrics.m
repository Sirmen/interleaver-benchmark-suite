function plotEntropyMetrics(stats_all, methods)
% All entropy metrics together - horizontal bars
    
   figure('Name', 'Entropy Metrics'); % , 'Position', [100 100 1400 600]);
   
   entropies = {'Hnoise', 'H', 'Hsep', 'Hblock', 'transitionEntropy'};
   titles = {'Noise Entropy','Permutation Entropy', 'Separation Entropy', 'Block Entropy', 'Transition Entropy'};
   
   nEntropies = numel(entropies);
   colors = [0.8 0.4 0.4;  0.4 0.8 0.4;  0.4 0.4 0.8;  0.8 0.8 0.4;  0.4 0.8 0.8];

    for i = 1:nEntropies
        subplot(1, nEntropies, i);
        data = extractMetricData(stats_all, methods, entropies{i});
        
        % Sort for better visualization
        [sortedData, sortIdx] = sort(data, 'descend');
        sortedMethods = methods(sortIdx);
        
        hb = barh(sortedData, 'FaceColor', colors(i,:));

        set(gca, 'YTick', 1:length(sortedMethods), 'YTickLabel', sortedMethods);
        set(gca, 'YTickLabelRotation', 0);
        % xlabel(titles{i});
        title(titles{i}, 'FontSize', 10);
        xlim([0 max(sortedData)*1.3]);
        set(gca, 'XTick', linspace(0,max(sortedData),4));

        grid on;
        
        % Add value labels
        for k = 1:length(sortedData)
            if ~isnan(sortedData(k)) && sortedData(k) > 0
                text(sortedData(k) * 1.02, k, sprintf('%.3f', sortedData(k)), ...
                     'FontSize', 8, 'VerticalAlignment', 'middle');
            end
        end
    end
    
    sgtitle('Information-Theoretic Metrics', 'FontSize', 14, 'FontWeight', 'bold');
end
