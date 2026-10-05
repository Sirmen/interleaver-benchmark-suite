function plotAdjacencyMetrics(stats_all, methods, config)
% Comprehensive adjacency analysis - horizontal bars
try    
   fig = figure('Name', 'Adjacency Metrics'); % , 'Position', [100 100 1400 800]);
   
   metrics = {'adjMin', 'adjAvg', 'adjCV'}; 
   titles = {'Min_{adj} (Higher = Better)', '\mu_{adj} (Higher = Better)', ...
             'CV_{adj} (Lower = Better)'};
   
   % Create tiled layout
   t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
   
   % Color palette for each subplot
   palette = lines(8);
    
   for i = 1:length(metrics)
      nexttile;
      metric = metrics{i};

      data = extractMetricData(stats_all, methods, metric);
      
      if strcmp(metric, 'adjCV')
         [sortedData, sortIdx] = sort(data, 'ascend'); % Lower CV usually means more uniform spreading
      else
         [sortedData, sortIdx] = sort(data, 'descend');
      end
      sortedMethods = methods(sortIdx);
      
      b = bar(sortedData, 'FaceColor', palette(i+1,:));
      set(gca, 'XTick', 1:numel(methods), 'XTickLabel', sortedMethods, 'XTickLabelRotation', 45);
      % ylabel(titles{i});
      title(titles{i}, 'FontSize', 10);
      grid on;
      
      % if i == 4 
      %    xlim([min(sortedData)*0.9 min(sortedData)*1.1]);
      % end
      ylim([0 max(sortedData)*1.1]);
      
      % % Add value labels
      % for k = 1:length(sortedData)
      %    if ~isnan(sortedData(k)) && isfinite(sortedData(k))
      %       text(k, sortedData(k) * 1.05, sprintf('%.3f', sortedData(k)), ...
      %            'FontSize', 9, 'HorizontalAlignment', 'center');
      %    end
      % end

      hold off;      
   end

   sgtitle('Adjacency Metrics (Index-Based Dispersion)', ...
           'FontSize', 12, 'FontWeight', 'bold');

   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
catch ME
   erM = sprintf('*** %s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   fprintf('%s\n', erM);
end
end
