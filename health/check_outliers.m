%% ========================================================================
%  CHECK 9: OUTLIER DETECTION
%  ========================================================================
function check = check_outliers(resultsTable, params, opts)
    
    fprintf('CHECK 9: Outlier Detection\n');
    fprintf('─────────────────────────────────────────────────────────────\n');
    
    methods = params.intMethods;
    nM = length(methods);
    
    check.perMethod = struct();
    totalOutliers = 0;
    
    for i = 1:nM
        m = methods{i};
        idx = strcmp(resultsTable.method, m) & ~isnan(resultsTable.RES);
        data = resultsTable.RES(idx);
        
        % IQR method
        Q1 = quantile(data, 0.25);
        Q3 = quantile(data, 0.75);
        IQR = Q3 - Q1;
        lowerBound = Q1 - 1.5*IQR;
        upperBound = Q3 + 1.5*IQR;
        
        outliers = data < lowerBound | data > upperBound;
        
        check.perMethod.(m).N = length(data);
        check.perMethod.(m).nOutliers = sum(outliers);
        check.perMethod.(m).outlierPct = 100 * sum(outliers) / length(data);
        check.perMethod.(m).lowerBound = lowerBound;
        check.perMethod.(m).upperBound = upperBound;
        
        totalOutliers = totalOutliers + sum(outliers);
    end
    
    check.totalOutliers = totalOutliers;
    check.totalSamples = height(resultsTable);
    check.outlierRate = 100 * totalOutliers / check.totalSamples;
    check.acceptable = check.outlierRate < 5; % < 5% outliers
    
    % Pass/Fail
    check.PASS = check.acceptable;
    
    % Report
    if opts.verbose
        fprintf('  Total outliers: %d (%.2f%%)\n', totalOutliers, check.outlierRate);
        fprintf('  Per-method outlier rates:\n');
        for i = 1:nM
            m = methods{i};
            fprintf('    %s: %d outliers (%.2f%%)\n', m, ...
                    check.perMethod.(m).nOutliers, ...
                    check.perMethod.(m).outlierPct);
        end
        fprintf(' -->  OVERALL: %s\n', string(check.PASS));
        if ~check.PASS
            fprintf('  ⚠ WARNING: High outlier rate detected!\n');
            fprintf('  Consider: Robust methods or outlier investigation\n');
        end
        fprintf('\n');
    end
    
    % Visualization
    if opts.plotResults
        fig = figure('Name', 'HA Outlier Detectios');
        t = tiledlayout(1, 1);
        
        nexttile;
        groups = resultsTable.method(~isnan(resultsTable.RES));
        data = resultsTable.RES(~isnan(resultsTable.RES));
        
        % Use boxchart(groups, data)
        boxchart(categorical(groups), data);
        
        ylabel('RES');
        title(sprintf('Outlier Detection (%.2f%% outliers)', check.outlierRate), ...
              'FontSize', 11);
        grid on;
        
        title(t, sprintf('CHECK 9: Outliers [%s]', string(check.PASS)), ...
                'FontSize', 11, 'FontWeight', 'bold');
        
        if opts.saveResults
            saveas(fig, fullfile(opts.figPath, 'check9_outliers.png'));
        end
    end
end
