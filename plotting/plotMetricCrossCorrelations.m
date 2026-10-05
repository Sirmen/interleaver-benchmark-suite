function plotMetricCrossCorrelations(config, crossCorrResults)
   % Create a wide figure
   fig = figure('Name', 'Metric Cross-Correlations', 'Color', 'w');
   
   % 1. Use the pre-computed results
   corrMatrix = crossCorrResults.crossCorrMatrix;
   metrics = crossCorrResults.validMetrics;
   cleanLabels = formatMetricNames(string(metrics));
   
   %% --- Panel 1: Metric Clustering (Dendrogram) ---
   subplot(1, 2, 1);
   order = plotMetricDendrogram(corrMatrix, cleanLabels);
   title('Metric Similarity Clustering', 'FontSize', 12, 'FontWeight', 'bold');

   %% --- Panel 2: Full Correlation Heatmap ---
   subplot(1, 2, 2);
   
   % Reorder using the dendrogram output
   reorderedCorr = corrMatrix(order, order);
   reorderedLabels = cleanLabels(order);
   
   imagesc(reorderedCorr, [-1 1]);
   
   % High-contrast B&W friendly colormap (Red-White-Blue)
   customMap = [linspace(0,1,32)', linspace(0.3,1,32)', ones(32,1); ... 
                ones(32,1), linspace(1,0.3,32)', linspace(1,0,32)'];    
   colormap(gca, customMap);
   
   % Axis setup
   n = length(reorderedLabels);
   set(gca, 'XTick', 1:n, 'XTickLabel', reorderedLabels, 'XTickLabelRotation', 45, ...
            'YTick', 1:n, 'YTickLabel', reorderedLabels, 'FontSize', 11, 'TickLabelInterpreter', 'tex');

   cb = colorbar; ylabel(cb, 'Correlation (r)');
   title('Metric Cross-Correlations (Ordered)', 'FontSize', 12, 'FontWeight', 'bold');

   if config.saveResults
       saveVars_YMD(config.dataSavePath, 'png', fig.Name, fig);
   end
end

%% 
function order = plotMetricDendrogram(corrMatrix, labels)
    % 1. Convert correlation to distance (1 - |r|)
    % High correlation (1 or -1) = 0 distance
    % No correlation (0) = 1 distance
    distMatrix = 1 - abs(corrMatrix);
    
    % 2. Force symmetry and handle diagonal
    distMatrix = (distMatrix + distMatrix') / 2;
    distMatrix(logical(eye(size(distMatrix)))) = 0;
    
    % 3. Linkage requires squareform of the distance
    linkageTree = linkage(squareform(distMatrix), 'average');
    
    % 4. Plot and return the order
    [~, ~, order] = dendrogram(linkageTree, 0, 'Orientation', 'left', 'Labels', labels);
    xlabel('Distance (1 - |r|)');
end
