function [crossCorrMatrix, validMetrics] = prepare_cross_correlation_data(stats_all, config, params)

   methods = params.intMethods;
   metrics = config.distance2plot;

   totalPoints = 0;
   for m = 1:length(methods)
     methodStats = getMethodStats(stats_all, methods{m});
     totalPoints = totalPoints + length(methodStats);
   end
   
   crossCorrMatrix = NaN(totalPoints, length(metrics));
   idx = 1;
   
   for m = 1:length(methods)
     method = methods{m};
     methodStats = getMethodStats(stats_all, method);
     for s = 1:length(methodStats)
         for i = 1:length(metrics)
             if isfield(methodStats(s), metrics{i})
                 crossCorrMatrix(idx, i) = methodStats(s).(metrics{i});
             end
         end
         idx = idx + 1;
     end
   end
   
   % Remove columns with all NaN
   validCols = any(~isnan(crossCorrMatrix), 1);
   crossCorrMatrix = crossCorrMatrix(:, validCols);
   validMetrics = metrics(validCols);
   
   % Remove rows with all NaN
   validRows = any(~isnan(crossCorrMatrix), 2);
   crossCorrMatrix = crossCorrMatrix(validRows, :);
end