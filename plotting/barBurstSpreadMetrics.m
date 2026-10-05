function erM = barBurstSpreadMetrics(stats_all, methods, config)
% Visualization of ECC-Aware Spreading & Capacity Metrics
erM = "";
try
   fig = figure('Name', 'Generalized Framework: Burst & Capacity Metrics'); 
   
   % Framework Metrics
   metrics = { 'eta_ES', 'delta_BS', 'S_ECC_norm', 'S_ECC' };
   titles = { '\eta_{ES}: Spreading Efficiency', '\Delta_{BS}: Spreading Diversity', ...
              'S_ECC_norm: ECC Sustainability Score', 'S_{ECC}: Sustainability Score'};
   
   nMetrics = numel(metrics);
   t = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

   palette = lines(nMetrics);   

   for i = 1:nMetrics
      nexttile;
      metric = metrics{i};
      data = extractMetricData(stats_all, methods, metric);
      
      % Sort Logic: S_ECC_norm is 'Lower is Better', others are 'Higher is Better'
      if strcmp(metric, 'S_ECC_norm')
          [sortedData, sortIdx] = sort(data, 'ascend');
      else
          [sortedData, sortIdx] = sort(data, 'descend');
      end
      sortedMethods = methods(sortIdx);
      
      b = bar(sortedData, 'FaceColor', palette(i,:));
      
      % UI Formatting
      title(titles{i}, 'FontSize', 10, 'FontWeight', 'bold');
      grid on;
      set(gca, 'XTickLabel', sortedMethods, 'XTick', 1:length(methods), 'FontSize', 10);
      xtickangle(45);
      % set(gca, 'YTickLabel', 'FontSize', 10);

      % Add capacity threshold line for S_ECC_norm
      if strcmp(metric, 'S_ECC_norm')
         hold on;
         yline(config.eccReal, 'r--', 'Limit (\tau)', 'LineWidth', 1.5);
         hold off;
      end
      
      % Add failure threshold for S_ECC
      if strcmp(metric, 'S_ECC')
         hold on;
         yline(0, 'k-', 'Failure', 'LineWidth', 1.2);
         hold off;
      end
   end

   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
catch ME
   erM = sprintf('Error in plotECCMetrics: %s', ME.message);
end
end