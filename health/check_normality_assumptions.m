%% ========================================================================
%  CHECK 6: NORMALITY ASSUMPTIONS (for ANOVA)
%  ========================================================================
function check = check_normality_assumptions(resultsTable, params, anovaResults, opts)
    
    fprintf('CHECK 6: Normality Assumptions\n');
    fprintf('─────────────────────────────────────────────────────────────\n');
    
    methods = params.intMethods;
    nM = length(methods);
    
    % Check normality for each method's contribution data
    check.perMethod = struct();
    normalCount = 0;
    
    % Suppress lillietest warning about small p-values
    warning('off', 'stats:lillietest:OutOfRangePLow');
    
    for i = 1:nM
        m = methods{i};
        idx = strcmp(resultsTable.method, m) & ~isnan(resultsTable.CR);
        data = resultsTable.CR(idx);
        
        % Shapiro-Wilk test (if available) or Lilliefors test
        try
            [~, check.perMethod.(m).p_value] = swtest(data);
        catch
            [~, check.perMethod.(m).p_value] = lillietest(data);
        end
        
        check.perMethod.(m).N = length(data);
        check.perMethod.(m).normal = check.perMethod.(m).p_value > opts.alpha;
        
        if check.perMethod.(m).normal
            normalCount = normalCount + 1;
        end
    end
    
    % Restore warning state
    warning('on', 'stats:lillietest:OutOfRangePLow');
    
    check.normalCount = normalCount;
    check.normalPct = 100 * normalCount / nM;
    check.allNormal = normalCount == nM;
    check.mostNormal = normalCount >= 0.7 * nM; % 70% threshold
    
    % ANOVA is robust to moderate deviations if n is large
    minN = min(structfun(@(x) x.N, check.perMethod));
    check.robustDueToSize = minN >= 30;
    
    % Pass/Fail (ANOVA is robust, so we're lenient)
    check.PASS = check.mostNormal || check.robustDueToSize;
    
    % Report
    if opts.verbose
        fprintf('  Methods tested: %d\n', nM);
        fprintf('  Normal distributions: %d (%.1f%%)\n', normalCount, check.normalPct);
        fprintf('  Minimum sample size: %d\n', minN);
        fprintf('  Robust due to large n: %s\n', string(check.robustDueToSize));
        if ~check.allNormal
            fprintf('* NOTE: Non-normal data detected, but large sample sizes\n');
            fprintf('        ensure ANOVA robustness (Central Limit Theorem)\n');
        end
        fprintf('  Per-method results:\n');
        for i = 1:nM
            m = methods{i};
            fprintf('    %s: p=%.4f [%s]\n', m, ...
                    check.perMethod.(m).p_value, ...
                    string(check.perMethod.(m).normal));
        end
        fprintf(' -->  OVERALL: %s\n', string(check.PASS));
        if ~check.PASS
            fprintf('  ⚠ WARNING: Normality assumptions may be violated!\n');
            fprintf('  Consider: non-parametric tests (Kruskal-Wallis)\n');
        end
        fprintf('\n');
    end
    
   % Visualization
   if opts.plotResults
      fig = figure('Name', 'HA Normality Assumptions');
      
      % select only the top performer methods
      methods = anovaResults.topMethods;
      topNperf = length(methods);
      totalPlots = min(nM, topNperf);

      % CALCULATE 2-ROW LAYOUT:
      numRows = 2;
      numColsLayout = ceil(totalPlots / numRows);

      % Initialize Tiled Layout
      % 'TileSpacing','compact' prevents the plots from being too small
      t = tiledlayout(numRows, numColsLayout, 'TileSpacing', 'compact', 'Padding', 'normal');      
      for i = 1:totalPlots
         m = methods{i};
         
         % Locate data for this specific method
         idx = strcmp(resultsTable.method, m) & ~isnan(resultsTable.CR);
         data = resultsTable.CR(idx);
         
         % Move to the next available tile
         nexttile;
         
         if ~isempty(data)
             qqplot(data);
             ylim([-0.1,1.1]);
             title(sprintf('%s (p=%.3f)', m, check.perMethod.(m).p_value), ...
                   'FontSize', 11, 'FontWeight', 'bold');
             grid on;
         else
             text(0.5, 0.5, 'No Data', 'HorizontalAlignment', 'center');
         end
      end
      
      % Global Layout Title (replaces sgtitle)
      title(t, sprintf('CHECK 6: Normality (Top %d Methods) [%s]', totalPlots, string(check.PASS)), ...
             'FontSize', 11, 'FontWeight', 'bold');
      
      if opts.saveResults
         saveas(fig, fullfile(opts.figPath, 'check6_normality.png'));
      end
   end
end
