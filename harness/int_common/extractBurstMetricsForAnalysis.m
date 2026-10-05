function metrics = extractBurstMetricsForAnalysis(results, methods)
% Extract burst metrics - handles array structure
    metrics = struct();
    stats_all = results.stats_all;
    
    for i = 1:length(methods)
        method = methods{i};
        methodStats = getMethodStats(stats_all, method);
        
        if ~isempty(methodStats)
            metrics.(method).eccAwareScore = [methodStats.eccAwareScore];
            metrics.(method).errorSpreadingEfficiency = [methodStats.errorSpreadingEfficiency];
            metrics.(method).burstSpreadingDiversity = [methodStats.burstSpreadingDiversity];
            metrics.(method).delta_G = [methodStats.delta_G];
        end
    end
end