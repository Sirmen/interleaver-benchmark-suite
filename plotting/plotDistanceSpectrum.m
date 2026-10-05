function plotDistanceSpectrum(stats_all, methods, config)
% Analyzes the spreading distribution (Distance Spectrum)
try
   % Framework Metrics
   metrics = { 'sepAvg', 'sepMin', 'eta_sep', 'sepCV', 'eta_ES', 'delta_BS' };
   titles = { '\mu_{sep}: Average Separation', 'Min_{sep}: Burst Protection', ...
              '\eta_{sep}: Separation Efficiency ', 'CV_{sep}: Spreading Uniformity', ...
              '\eta_{ES}: Error Spreading Efficiency', ...
              '\Delta_{BS}: Burst Spreading Diversity)'};

   fig = figure('Name', 'Distance Spectrum Analysis');
   t = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
   set(fig, 'Color', 'w'); %, 'Position', [100, 100, 1200, 800]);
   
   nMetrics = numel(metrics);
   palette = lines(nMetrics);   

   for i = 1:nMetrics
      nexttile;
      metric = metrics{i};
      data = extractMetricData(stats_all, methods, metric);

      if strcmp(metric, 'sepCV')
         [sortedData, sortIdx] = sort(data, 'ascend'); % Lower CV usually means more uniform spreading
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

   end

   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
    
catch ME
   erM = sprintf('Error in plotECCMetrics: %s', ME.message);
end
end
