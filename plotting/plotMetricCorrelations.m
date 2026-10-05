function crossCorrMatrix = plotMetricCrossCorrelations(stats_all, methods, config)

   metrics = config.distance2plot;

   [crossCorrData, validMetrics] = buildDataMatrix(stats_all, methods, metrics);
   crossCorrMatrix = corr(crossCorrData, 'rows', 'pairwise');
   
   figure('Name', 'Key Metric Cross Correlations'); %, 'Position', [100 100 1400 800]);
   
   %% Panel 1: Correlations with pivot variable (cont or effectiveness)
   subplot(1, 2, 1);
   plotMetricDendrogram(stats_all, methods, config);
   
   %% Panel 2: Top 20 absolute correlations
   subplot(1, 2, 2);
   plotTopCorrelations(crossCorrMatrix, validMetrics, 20);
      
   sgtitle('Metrics Correlation Analysis', 'FontSize', 14, 'FontWeight', 'bold');
end

function plotTopCorrelations(corrMatrix, metrics, topK)
% Show top K absolute correlations
    
    n = length(metrics);
    pairs = [];
    
    for i = 1:n
        for j = i+1:n
            if ~isnan(corrMatrix(i,j))
                pairs = [pairs; i, j, corrMatrix(i,j)];
            end
        end
    end
    
    [~, sortIdx] = sort(abs(pairs(:,3)), 'descend');
    pairs = pairs(sortIdx, :);
    pairs = pairs(1:min(topK, size(pairs, 1)), :);
    
    axis off;

    % set(gca, 'FontSize', 10);
    set(gca, 'TickLabelInterpreter', 'none'); % Prevent issues with special chars
    
    text(0.5, 0.98, sprintf('Top %d Strongest Cross-Correlations', topK), ...
         'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    
    yStep = 0.55 / topK;
    for i = 1:size(pairs, 1)
        yPos = 0.94 - i * yStep;
        
        name1 = metrics{pairs(i,1)};
        name2 = metrics{pairs(i,2)};
        corr = pairs(i, 3);
        
        if corr > 0
            color = [0, 0.7, 0];
        else
            color = [0.8, 0, 0];
        end
        
        text(0.05, yPos, sprintf('%.3f', corr), 'FontSize', 11, ...
             'Color', color, 'HorizontalAlignment', 'right');
        text(0.07, yPos, name1, 'FontSize', 11, 'Interpreter', 'none');
        text(0.51, yPos, '↔', 'FontSize', 11);
        text(0.58, yPos, name2, 'FontSize', 11, 'Interpreter', 'none');
    end
end

function crossCorrMatrix = plotMetricDendrogram(stats_all, methods, config)
% Correlation analysis with hierarchical clustering for better readability
try    
    metrics = config.distance2plot;
    nMetrics = length(metrics);
    
    % Build data matrix (same as before)
    totalPoints = 0;
    for m = 1:length(methods)
        methodStats = getMethodStats(stats_all, methods{m});
        totalPoints = totalPoints + length(methodStats);
    end
    
    dataMatrix = zeros(totalPoints, nMetrics);
    idx = 1;
    for m = 1:length(methods)
        method = methods{m};
        methodStats = getMethodStats(stats_all, method);
        for s = 1:length(methodStats)
            for i = 1:nMetrics
                if isfield(methodStats(s), metrics{i})
                    dataMatrix(idx, i) = methodStats(s).(metrics{i});
                else
                    dataMatrix(idx, i) = NaN;
                end
            end
            idx = idx + 1;
        end
    end
    
    validRows = any(~isnan(dataMatrix), 2);
    dataMatrix = dataMatrix(validRows, :);
    
    % Compute correlation matrix
    crossCorrMatrix = corr(dataMatrix, 'rows', 'pairwise');
    
    % Convert to distance matrix for clustering
    distMatrix = 1 - abs(crossCorrMatrix);
    distMatrix(distMatrix < 0) = 0;
    
    % Hierarchical clustering
    linkageTree = linkage(squareform(distMatrix), 'average');
        
    % Dendrogram (shows metric groupings)
    [~, ~, order] = dendrogram(linkageTree, 0, 'Orientation', 'left', 'Labels', metrics);
    title('Metric Clustering', 'FontSize', 12, 'FontWeight', 'bold');

    set(gca, 'FontSize', 10);
    set(gca, 'TickLabelInterpreter', 'none'); % Prevent issues with special chars
    
catch ME
   erM = sprintf('*** %s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   fprintf('%s\n', erM);
end
end

% Helper function
function [dataMatrix, validMetrics] = buildDataMatrix(stats_all, methods, metrics)
try
    totalPoints = 0;
    for m = 1:length(methods)
        methodStats = getMethodStats(stats_all, methods{m});
        totalPoints = totalPoints + length(methodStats);
    end
    
    dataMatrix = NaN(totalPoints, length(metrics));
    idx = 1;
    
    for m = 1:length(methods)
        method = methods{m};
        methodStats = getMethodStats(stats_all, method);
        for s = 1:length(methodStats)
            for i = 1:length(metrics)
                if isfield(methodStats(s), metrics{i})
                    dataMatrix(idx, i) = methodStats(s).(metrics{i});
                end
            end
            idx = idx + 1;
        end
    end
    
    % Remove columns with all NaN
    validCols = any(~isnan(dataMatrix), 1);
    dataMatrix = dataMatrix(:, validCols);
    validMetrics = metrics(validCols);
    
    % Remove rows with all NaN
    validRows = any(~isnan(dataMatrix), 2);
    dataMatrix = dataMatrix(validRows, :);
catch ME
   erM = sprintf('*** %s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   fprintf('%s\n', erM);
end
end
