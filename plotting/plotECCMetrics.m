function erM = plotECCMetrics(stats_all, methods, config)
% Comprehensive visualization for the Generalized Interleaving Framework
% Focuses on ECC-Awareness, Burst Spreading, and Recovery Gain.
    
erM = "";
try    
   fig = figure('Name', 'ECC-Aware and Recovery Metrics');
   set(fig, 'Color', 'w'); %, 'Position', [100, 100, 1200, 800]);
    
   metrics = {'S_ECC_norm', 'S_sf', 'V_ECC', 'U_ECC'};
   
   titles = {'S_{ECCnorm}: ECC Sustainability Score', ...
             'S_{sf}: Source Separation Factor', ...
             'V_{ECC}: ECC Violations', 'U_{ECC}: ECC Utilization'};
   
   t = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
   title(t, 'Interleaver Performance via Generalized ECC-Aware Metrics', 'FontSize', 12, 'FontWeight', 'bold');
   
   nMethods = numel(methods);
   nMetrics = numel(metrics);
   palette = lines(nMetrics);   
    
   for i = 1:nMetrics
      nexttile;
      x = extractMetricData(stats_all, methods, metrics{i});
      
      if all(isnan(x))
         text(0.5, 0.5, 'Metric Data N/A', 'HorizontalAlignment', 'center', 'Color', 'r');
         title(titles{i}, 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
         axis off; continue;
      end
      
      % Lower is better for: S_ECC_norm (Sustainability Index), eccViolations, eccUtilization
      if ismember(metrics{i}, {'S_ECC_norm', 'V_ECC', 'U_ECC'})
         [x_Sorted, sortIdx] = sort(x, 'ascend');
      else
         [x_Sorted, sortIdx] = sort(x, 'descend');
      end
      
      y_Methods = methods(sortIdx); 
      
      b = bar(x_Sorted, 'FaceColor', palette(i,:));
      % % Apply a gradient color scheme for visual clarity
      % b.CData = parula(length(x_Sorted)); 
      
      title(titles{i}, 'FontSize', 10, 'FontWeight', 'bold');
      grid on;
      set(gca, 'XTickLabel', y_Methods, 'XTick', 1:nMethods, 'FontSize', 10);
      xtickangle(45);

      % Add a reference line for the 'Hard Limit' on the S_ECC_norm plot
      if strcmp(metrics{i}, 'S_ECC_norm')
         hold on;
         yline(config.eccReal, 'm--', 'Code Capacity (\tau)', ...
            'LabelHorizontalAlignment','left','FontSize',10,'FontWeight','bold','ColorMode','auto');
         hold off;
      end
      % Add a reference threshold for Violations:
      if strcmp(metrics{i}, 'V_ECC')
         hold on;
         yline(0, 'k-', 'Zero Failure Target','FontSize',10,'FontWeight','bold','ColorMode','auto');
         hold off;
      end        
      % Add a reference line for the 'Fragile zone' on S_ECC
      if strcmp(metrics{i}, 'S_ECC')
         hold on;
         yline(0, 'b--', 'Failure Threshold','FontSize',10,'FontWeight','bold','ColorMode','auto');
         hold off;
      end
      % Special annotations for Source Dispersion Factor (S_sf)
      if strcmp(metrics{i}, 'S_sf') || strcmp(metrics{i}, 'MinminBlock')
         n = stats_all(1).eccConfig.n; % Assuming n is stored in your stats
         N = length(stats_all(1).permutation);
         
         % 1. Fragility Threshold (1/n)
         thresh = 1/n;
         line_thresh = yline(thresh, '--b', 'Fragility Threshold (1/n)', ...
           'FontSize', 10, 'FontWeight', 'bold', ...
           'LabelVerticalAlignment', 'top', 'LineWidth', 2);
         
         % 2. Baseline Diversity (1.0)
         line_base = yline(1.0, ':k', 'Uniform Block Diversity', ...
           'FontSize', 10, 'FontWeight', 'bold', ...
           'LabelVerticalAlignment', 'bottom');
         
         % % 3. Theoretical Max Limit
         % s_df_max = (N-1) / (n*(n-1));
         % line_max = yline(s_df_max, '-.g', 'Theoretical Max', ...
         %    'FontSize', 10, 'FontWeight', 'bold', ...
         %    'LabelVerticalAlignment', 'top');
         
         % Adjust Y-axis to show the max limit clearly
         ylim([0, max(max(x_Sorted)*1.1, 1.1)]);
      end
   end

   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
    
catch ME
   erM = sprintf('Error in plotECCMetrics: %s', ME.message);
end
end