function erM = plotRandomnessPeriodicity(stats_all, methods, config)
% Cross-validation of Structural Randomness and Spectral Integrity
erM = "";
try    
   metrics = {'PSR', 'laplacianEnergy', 'S_factor', 'delta_G'};
   
   titles = {'PSR: Peak-to-Sidelobe Ratio (Aperiodicity)', ...
             'LE: Laplacian Energy (Complexity)', ...
             'S: Spread Factor', '\Delta_{G}: Gini Improvement' };

   fig = figure('Name', 'Framework Cross-Validation: Randomness & Periodicity');
   t = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
   
   nMetrics = numel(metrics);
   palette = lines(nMetrics);   
    
   for i = 1:nMetrics
      nexttile;

      metric = metrics{i};
      data = extractMetricData(stats_all, methods, metric);
      
      % Sort 
      if strcmp(metric, 'PSR')
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
      % set(gca, 'YTickLabel', 'FontSize', 10);
   end
   
   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
catch ME
   erM = sprintf('Error in plotECCMetrics: %s', ME.message);
end
end
