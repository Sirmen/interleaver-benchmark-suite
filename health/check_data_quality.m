%% ========================================================================
%  CHECK 5: DATA QUALITY (Missing, Invalid, Outliers)
%  ========================================================================
function check = check_data_quality(resultsTable, opts)
    
    fprintf('CHECK 5: Data Quality\n');
    fprintf('─────────────────────────────────────────────────────────────\n');
    
    % Key variables to check
    keyVars = {'noiseActual', 'RES', 'CR', 'effectiveness', 'N'};
    xLabels = {'noiseActual', 'RES', 'CR', 'effectiveness', 'N'};
    available = keyVars(ismember(keyVars, resultsTable.Properties.VariableNames));
    
    check.total = height(resultsTable);
    check.perVariable = struct();
    
    for i = 1:length(available)
        var = available{i};
        data = resultsTable.(var);
        
        check.perVariable.(var).missing = sum(isnan(data));
        check.perVariable.(var).infinite = sum(isinf(data));
        check.perVariable.(var).missingPct = 100 * check.perVariable.(var).missing / check.total;
        check.perVariable.(var).valid = check.total - check.perVariable.(var).missing - check.perVariable.(var).infinite;
        check.perVariable.(var).validPct = 100 * check.perVariable.(var).valid / check.total;
    end
    
    % Overall quality
    totalMissing = sum(structfun(@(x) x.missing, check.perVariable));
    totalInfinite = sum(structfun(@(x) x.infinite, check.perVariable));
    
    check.totalMissing = totalMissing;
    check.totalInfinite = totalInfinite;
    check.missingRate = totalMissing / (check.total * length(available));
    check.highQuality = check.missingRate < 0.05; % < 5% missing
    
    % Pass/Fail
    check.PASS = check.highQuality && totalInfinite == 0;
    
    % Report
    if opts.verbose
        fprintf('  Total records: %d\n', check.total);
        fprintf('  Variables checked: '); disp(available);
        fprintf(' -->  OVERALL missing rate: %.2f%%\n', 100*check.missingRate);
        fprintf('  Total infinite values: %d\n', totalInfinite);
        fprintf('  Per-variable quality:\n');
        for i = 1:length(available)
            var = available{i};
            fprintf('    %s: %.1f%% valid (%d/%d)\n', var, ...
                    check.perVariable.(var).validPct, ...
                    check.perVariable.(var).valid, check.total);
        end
        fprintf(' -->  OVERALL: %s\n', string(check.PASS));
        if ~check.PASS
            fprintf('  ⚠ WARNING: Data quality issues detected!\n');
        end
        fprintf('\n');
    end
    
    % Visualization
   if opts.plotResults
      fig = figure('Name', 'HA Data Quality');
      t = tiledlayout(1,1); % Use tiled layout for better spacing
      
      validPcts = zeros(length(available), 1);
      for i = 1:length(available)
         validPcts(i) = check.perVariable.(available{i}).validPct;
      end
      
      nexttile;
      bar(validPcts);
      hold on;
      yline(95, 'm--', '95% threshold', 'LineWidth', 2);
      ylim([0 105]);
      set(gca, 'XTickLabel', available);
      xtickangle(45);
      ylabel('Valid Data (%)', 'FontSize', 11);
      % xlabel(xLabels, 'FontSize', 11);
      title('Data Completeness by Variable', 'FontSize', 11, 'FontWeight', 'bold');
      grid on;
      
      % Set the layout title instead of sgtitle
      title(t, sprintf('CHECK 5: Data Quality [%s]', string(check.PASS)), ...
             'FontSize', 11, 'FontWeight', 'bold');
      
      if opts.saveResults
         saveas(fig, fullfile(opts.figPath, 'check5_data_quality.png'));
      end
   end
end
