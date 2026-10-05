%% ========================================================================
%  CHECK 7: HOMOSCEDASTICITY (Equal Variances)
%  ========================================================================
function check = check_homoscedasticity(resultsTable, params, opts)
    
    fprintf('CHECK 7: Homoscedasticity (Equal Variances)\n');
    fprintf('─────────────────────────────────────────────────────────────\n');
    
    methods = params.intMethods;
    nM = length(methods);
    
    % Collect variances per method
    variances = zeros(nM, 1);
    sampleSizes = zeros(nM, 1);
    
    for i = 1:nM
        m = methods{i};
        idx = strcmp(resultsTable.method, m) & ~isnan(resultsTable.RES);
        data = resultsTable.RES(idx);
        
        variances(i) = var(data);
        sampleSizes(i) = length(data);
    end
    
    check.variances = variances;
    check.std = sqrt(variances);
    check.methods = methods;
    
    % Levene's test
    groups = resultsTable.method(~isnan(resultsTable.RES));
    data = resultsTable.RES(~isnan(resultsTable.RES));
    
    [check.levene_p, check.levene_stats] = vartestn(data, groups, 'TestType', 'LeveneAbsolute', 'Display', 'off');
    check.equalVar_levene = check.levene_p > opts.alpha;
    
    % Variance ratio test (max/min < 4 is acceptable)
    check.varianceRatio = max(variances) / min(variances);
    check.equalVar_ratio = check.varianceRatio < 4;
    
    % Pass/Fail
    check.PASS = check.equalVar_levene || check.equalVar_ratio;
    
    % Report
    if opts.verbose
        fprintf('  Levene test p-value: %.4f\n', check.levene_p);
        fprintf('  Equal variances (Levene): %s (α=%.2f)\n', ...
                string(check.equalVar_levene), opts.alpha);
        fprintf('  Variance ratio (max/min): %.2f\n', check.varianceRatio);
        fprintf('  Acceptable ratio (<4): %s\n', string(check.equalVar_ratio));
        fprintf('\n  Per-method standard deviations:\n');
        for i = 1:nM
            fprintf('    %s: %.4f\n', methods{i}, check.std(i));
        end
        fprintf(' -->  OVERALL: %s\n', string(check.PASS));
        if ~check.PASS
            fprintf('  ⚠ WARNING: Unequal variances detected!\n');
            fprintf('  Consider: Welch ANOVA or transformation\n');
        end
        fprintf('\n');
    end
    
    % Visualization
   if opts.plotResults
      fig = figure('Name', 'HA Homoscedasticity');
      t = tiledlayout(1, 2, 'TileSpacing', 'compact'); 
      
      % Left Plot: Bar chart
      nexttile;
      bar(check.std);
      set(gca, 'XTickLabel', methods);
      set(gca, 'XTick', 1:nM, 'XTickLabel', methods); % Force all ticks
      xtickangle(45);
      ylabel('Standard Deviation');
      title('Variability by Method', 'FontSize', 11);
      grid on;
      
      % Right Plot: Boxchart (Modern replacement)
      nexttile;
      % Convert to categorical so boxchart handles names correctly
      boxchart(categorical(groups), data); 
      ylabel('RES');
      title(sprintf('Spread Comparison (p=%.4f)', check.levene_p), ...
           'FontSize', 11);
      grid on;
      
      title(t, sprintf('CHECK 7: Homoscedasticity [%s]', string(check.PASS)), ...
             'FontSize', 11, 'FontWeight', 'bold');
      
      if opts.saveResults
         saveas(fig, fullfile(opts.figPath, 'check7_homoscedasticity.png'));
      end
   end
end
