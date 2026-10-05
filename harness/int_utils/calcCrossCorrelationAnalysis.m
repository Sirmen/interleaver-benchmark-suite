function [crossCorrResults, erM] = calcCrossCorrelationAnalysis(stats_all, methods, config)
% Analyzes Cross-Correlations in metrics 
%         erM - error message (empty if successful)
% -------------------------------------------------------------------------
erM = "";    crossCorrResults = struct();
crossCorrResults.crossCorrMatrix = []; crossCorrResults.validMetrics = [];
try
   metrics = config.correlationVariables;   

   [crossCorrData, validMetrics, erM] = buildDataMatrix(stats_all, methods, metrics);
   if erM ~= ""
      fprintf(erM); return;
   end
   
   crossCorrMatrix = corr(crossCorrData, 'rows', 'pairwise');

   crossCorrResults.crossCorrMatrix = crossCorrMatrix;
   crossCorrResults.validMetrics = validMetrics;

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   fprintf('%s\n', erM);
end
end

%% Helper function
function [dataMatrix, validMetrics, erM] = buildDataMatrix(stats_all, methods, metrics)
erM = ""; dataMatrix = []; validMetrics = [];
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
