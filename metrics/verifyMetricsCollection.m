function verifyMetricsCollection(stats, expectedMetrics)
% Verify that all expected metrics were collected
% % In your main simulation loop, after collectStatistics:
% [stats, erM] = collectStatistics(...);
% 
% if isempty(erM) && ~isempty(stats)
%     % Verify metrics
%     expectedMetrics = {
%         'effectiveness', 'cont', ...
%         'eccAwareScore', 'eccViolationReduction', 'after_eccMargin_min', ...
%         'before_gini', 'after_gini', 'delta_G', ...
%         'errorSpreadingEfficiency', 'blockOccupancyRatio', 'burstSpreadingDiversity', ...
%         'randomnessCombinedScore', 'aperiodicityScore', 'periodicityNumPeaks', 'periodicityMaxPeak', ...  
%         'spreadFactor', 'laplacianEnergy', ...
%         'periodicityPeakEnergy', 'blockTransitionDiversity', 'transitionEntropy', ...
%         'triangleMetric', 'lambdaMin', 'lambdaAvg', ...
%         'sepMin', 'sepAvg', 'sepCV', 'eta_sep', ...
%         'adjMin', 'adjAvg', 'CV_adj', 'adjUniformity', ...
%         'blockMinMin', 'blockMinAvg', 'blockAvgAvg', ...
%         'H', 'Hsep', 'Hblock', ...
%         'after_eccUtilization', 'after_eccViolations', ...
%         'before_noisyPointsPerBlock_max', 'S_ECC_norm', ...
%         'after_noisyPointsPerBlock_avg'
%     };
% 
%     verifyMetricsCollection(stats, expectedMetrics);
% end
    
    fprintf('\n=== Verifying Metrics Collection ===\n');
    
    if isempty(stats)
        fprintf('⚠ Stats is empty!\n');
        return;
    end
    
    availableFields = fieldnames(stats);
    missingMetrics = {};
    presentMetrics = {};
    
    for i = 1:length(expectedMetrics)
        metric = expectedMetrics{i};
        if ismember(metric, availableFields)
            presentMetrics{end+1} = metric;
        else
            missingMetrics{end+1} = metric;
        end
    end
    
    fprintf('Expected metrics: %d\n', length(expectedMetrics));
    fprintf('Present metrics:  %d ✓\n', length(presentMetrics));
    fprintf('Missing metrics:  %d\n', length(missingMetrics));
    
    if ~isempty(missingMetrics)
        fprintf('\n⚠ Missing Metrics:\n');
        for i = 1:length(missingMetrics)
            fprintf('  - %s\n', missingMetrics{i});
        end
    else
        fprintf('\n✓ All metrics collected successfully!\n');
    end
    
    fprintf('====================================\n\n');
end