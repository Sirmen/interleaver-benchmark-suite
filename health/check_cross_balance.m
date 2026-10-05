function check = check_cross_balance(resultsTable, params, config, opts)
%% ========================================================================
%  CHECK 4: CROSS-FACTOR BALANCE (Method × Noise)
%  ========================================================================
    
   fprintf('CHECK 4: Cross-Factor Balance (Method × Noise)\n');
   fprintf('─────────────────────────────────────────────────────────────\n');
   
   methods = params.intMethods;
   nM = length(methods);
    
   % 1. Determine Noise Bins
   if isfield(config, 'noiseBins')
       nBins = config.noiseBins;
   else
       nBins = length(config.noiseLevels);
   end
   
   % 2. Use existing 'noiseBin' column (intended bins)
   if ismember('noiseBin', resultsTable.Properties.VariableNames)
       resultsTable.noiseCat = resultsTable.noiseBin;
   else
       warning('  ⚠ noiseBin column not found. Recalculating bins (Legacy Mode).');
       noiseLevels = config.noiseLevels;
       midpoints = noiseLevels(1:end-1) + diff(noiseLevels)/2;
       edges = [-Inf, midpoints, Inf];
       resultsTable.noiseCat = discretize(resultsTable.noiseActual, edges);
   end

   % 3. Build Count Matrix for INTENDED bins
   countMatrix_bin = zeros(nM, nBins);
   methodCol = string(resultsTable.method); 
   
   for i = 1:nM
      m = string(methods{i});
      for b = 1:nBins
         idx = (methodCol == m) & (resultsTable.noiseCat == b);
         countMatrix_bin(i, b) = sum(idx);
      end
   end
    
   check.countMatrix = countMatrix_bin;
   check.methods = methods;
   check.nBins = nBins;
    
   % 4. Calculate Balance Metrics
   check.min = min(countMatrix_bin(:));
   check.max = max(countMatrix_bin(:));
   check.mean = mean(countMatrix_bin(:));
   check.std = std(countMatrix_bin(:));
   check.cv = check.std / (check.mean + eps);
   check.emptyCells = sum(countMatrix_bin(:) == 0);
   check.fullCoverage = check.emptyCells == 0;
   
   % Chi-square test
   expected = mean(countMatrix_bin(:));
   if expected > 0
       chi2stat = sum((countMatrix_bin(:) - expected).^2 / expected);
       df = numel(countMatrix_bin) - 1;
       check.chi2_p = 1 - chi2cdf(chi2stat, df);
   else
       check.chi2_p = 0;
   end
   check.uniform = check.chi2_p > opts.alpha; 
   check.balanced = check.cv < opts.balanceTol;
   check.PASS = check.fullCoverage && check.balanced;
    
   %% 5. Analyze ACTUAL noise distribution
   noiseLevels = config.noiseLevels;
   noiseActual = resultsTable.noiseActual;
   
   % Check for out-of-range values
   outOfRange_low = sum(noiseActual < noiseLevels(1));
   outOfRange_high = sum(noiseActual > noiseLevels(end));
   
   fprintf('  Noise Range Analysis:\n');
   fprintf('    Expected range: [%.4f, %.4f]\n', noiseLevels(1), noiseLevels(end));
   fprintf('    Actual range:   [%.4f, %.4f]\n', min(noiseActual), max(noiseActual));
   fprintf('    Below minimum:  %d samples (%.2f%%)\n', ...
           outOfRange_low, 100*outOfRange_low/height(resultsTable));
   fprintf('    Above maximum:  %d samples (%.2f%%)\n', ...
           outOfRange_high, 100*outOfRange_high/height(resultsTable));
   
   % Create extended bins to capture all actual noise
   if outOfRange_low > 0 || outOfRange_high > 0
       fprintf('  ⚠ WARNING: Actual noise values outside intended range!\n');
       
       % Extended bins: [<min | intended bins | >max]
       nBins_extended = nBins + (outOfRange_low > 0) + (outOfRange_high > 0);
       
       % Create extended edges
       noiseActualMin = min(noiseActual); 
       noiseActualMax = max(noiseActual); 

       if outOfRange_low > 0
         extendedLevels = [noiseActualMin noiseLevels];
       else
         extendedLevels = noiseLevels;
       end
       if outOfRange_high > 0
         extendedLevels = [extendedLevels noiseActualMax];
       end

       binLabels = arrayfun(@(x) sprintf('%.3f', x), noiseLevels, 'UniformOutput', false);
       
       if outOfRange_low > 0
           binLabels = [{'< min'} binLabels];
       end
       if outOfRange_high > 0
           binLabels = [binLabels {'> max'}];
       end
       
       % Recalculate with extended bins
       midpoints_ext = extendedLevels(1:end-1) + diff(extendedLevels)/2;
       edges_ext = [-Inf, midpoints_ext, Inf];
       resultsTable.noiseCat_actual = discretize(noiseActual, edges_ext);
   else
       % No out-of-range values, use standard bins
       nBins_extended = nBins;
       midpoints = noiseLevels(1:end-1) + diff(noiseLevels)/2;
       edges = [-Inf, midpoints, Inf];
       resultsTable.noiseCat_actual = discretize(noiseActual, edges);
       binLabels = arrayfun(@(x) sprintf('%.3f', x), noiseLevels, 'UniformOutput', false);
   end
   
   % Build count matrix for ACTUAL noise with extended bins
   countMatrix_actual = zeros(nM, nBins_extended);
   
   for i = 1:nM
       m = string(methods{i});
       for b = 1:nBins_extended
           idx = (methodCol == m) & (resultsTable.noiseCat_actual == b);
           countMatrix_actual(i, b) = sum(idx);
       end
   end
   
   % Store extended info
   check.nBins_extended = nBins_extended;
   check.countMatrix_actual = countMatrix_actual;
   check.binLabels = binLabels;
   check.outOfRange_low = outOfRange_low;
   check.outOfRange_high = outOfRange_high;

   check.minActual = min(countMatrix_actual(:));
   check.maxActual = max(countMatrix_actual(:));
   check.meanActual = mean(countMatrix_actual(:));
   check.stdActual = std(countMatrix_actual(:));
   check.cvActual = check.stdActual / (check.meanActual + eps);
   
   % Verify total counts match
   total_intended = sum(countMatrix_bin(:));
   total_actual = sum(countMatrix_actual(:));
   
   fprintf('\n  Sample Count Verification:\n');
   fprintf('    Intended bins total: %d\n', total_intended);
   fprintf('    Actual bins total:   %d\n', total_actual);
   
   if total_intended == total_actual
       fprintf('    ✓ Counts match!\n');
   else
       fprintf('    ✗ MISMATCH! Difference: %d samples\n', total_actual - total_intended);
   end
   
   % 6. Reporting
   if opts.verbose
      fprintf('\n  Design Summary:\n');
      fprintf('    Design cells (intended): %d × %d = %d\n', nM, nBins, nM*nBins);
      fprintf('    Design cells (actual):   %d × %d = %d\n', nM, nBins_extended, nM*nBins_extended);
      fprintf('    Samples per cell: min=%d, max=%d, mean=%.1f\n', ...
              check.min, check.max, check.mean);
      fprintf('    CV: %.4f (threshold: %.2f)\n', check.cv, opts.balanceTol);
      fprintf('    Empty cells: %d\n', check.emptyCells);
      fprintf('    Uniformity p-value: %.4f\n', check.chi2_p);
      fprintf('  --> OVERALL: %s\n', string(check.PASS));
      if ~check.PASS
         fprintf('    ⚠ WARNING: Unbalanced factorial design detected!\n');
      end
      fprintf('\n');
   end
    
   %% 7. Visualization
   if opts.plotResults
      fig = figure('Name', 'HA Cross-Factor Balance', 'Color', 'w');
      t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
      
      %% Subplot 1: Heatmap - Intended Bins
      nexttile;
      imagesc(countMatrix_bin);
      colormap(gca, parula);
      cb = colorbar;
      ylabel(cb, 'Sample Count', 'FontSize', 10);
      set(gca, 'YTick', 1:nM, 'YTickLabel', methods, 'FontSize', 11, ...
          'TickLabelInterpreter', 'none');
      set(gca, 'XTick', 1:nBins);
      xlabel('Noise Bin Index', 'FontSize', 11, 'FontWeight', 'bold');
      % ylabel('Method', 'FontSize', 11, 'FontWeight', 'bold');
      title(sprintf('Method × Noise-Bin (Total=%d)', sum(countMatrix_bin(:))), ...
            'FontSize', 11, 'FontWeight', 'bold');
      
      % Add counts
      for i = 1:nM
         for j = 1:nBins
             text(j, i, sprintf('%d', countMatrix_bin(i,j)), ...
                 'HorizontalAlignment', 'center', 'Color', 'w', ...
                 'FontSize', 8, 'FontWeight', 'bold');
         end
      end
      
      %% Subplot 2: Histogram - Bins
      nexttile;
      histogram(countMatrix_bin(:), 20, 'FaceColor', [0.6 0.7 0.9]);
      hold on;
      xline(check.mean, 'b--', sprintf('Mean=%.1f', check.mean), ...
            'LineWidth', 2, 'LabelVerticalAlignment', 'top','LabelOrientation','aligned');
      xlabel('Samples per Cell', 'FontSize', 11, 'FontWeight', 'bold');
      ylabel('Frequency', 'FontSize', 11, 'FontWeight', 'bold');
      title('Cell Count Distribution', 'FontSize', 11, 'FontWeight', 'bold');
      grid on;
      box on;
      
      %% Subplot 3: Heatmap - Actual Noise (Extended Bins)
      nexttile;
      imagesc(countMatrix_actual);
      colormap(gca, parula);
      cb = colorbar;
      ylabel(cb, 'Sample Count', 'FontSize', 10);
      set(gca, 'YTick', 1:nM, 'YTickLabel', methods, 'FontSize', 11, ...
          'TickLabelInterpreter', 'none');
      set(gca, 'XTick', 1:nBins_extended, 'XTickLabel', binLabels, ...
          'XTickLabelRotation', 45, 'FontSize', 10);
      xlabel('Actual Noise', 'FontSize', 11, 'FontWeight', 'bold');
      % ylabel('Method', 'FontSize', 11, 'FontWeight', 'bold');
      title(sprintf('Method × Actual-Noise (Total=%d)', sum(countMatrix_actual(:))), ...
            'FontSize', 11, 'FontWeight', 'bold');
      
      % Add counts
      for i = 1:nM
         for j = 1:nBins_extended
             if countMatrix_actual(i,j) > 0
                 text(j, i, sprintf('%d', countMatrix_actual(i,j)), ...
                     'HorizontalAlignment', 'center', 'Color', 'w', ...
                     'FontSize', 8, 'FontWeight', 'bold');
             end
         end
      end
      
      % Highlight out-of-range bins with different border
      if outOfRange_low > 0
          rectangle('Position', [0.5, 0.5, 1, nM], 'EdgeColor', 'r', ...
                   'LineWidth', 2.5, 'LineStyle', '-');
      end
      if outOfRange_high > 0
          rectangle('Position', [nBins_extended-0.5, 0.5, 1, nM], ...
                   'EdgeColor', 'r', 'LineWidth', 2.5, 'LineStyle', '-');
      end
      
      
      %% Subplot 4: Histogram - Actual Noise
      nexttile;
      histogram(countMatrix_actual(:), 20, 'FaceColor', [0.6 0.7 0.9]);
      hold on;
      xline(check.meanActual, 'm--', sprintf('Mean=%.1f', check.meanActual), ...
            'LineWidth', 2, 'LabelVerticalAlignment', 'top', 'LabelHorizontalAlignment','right');
      xlabel('Samples per Cell', 'FontSize', 11, 'FontWeight', 'bold');
      ylabel('Frequency', 'FontSize', 11, 'FontWeight', 'bold');
      title('Actual Noise Count Distribution', 'FontSize', 11, 'FontWeight', 'bold');
      grid on;
      box on;


      sgtitle(sprintf('CHECK 4: Cross-Factor Balance [%s] | Out-of-range: %d low, %d high', ...
                      string(check.PASS), outOfRange_low, outOfRange_high), ...
              'FontSize', 13, 'FontWeight', 'bold');
      
      if opts.saveResults
         saveas(fig, fullfile(opts.figPath, 'check4_cross_balance.png'));
         fprintf('  Figure saved: check4_cross_balance.png\n');
      end
   end
end
