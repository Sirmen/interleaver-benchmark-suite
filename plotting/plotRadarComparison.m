function plotRadarComparison(results, config, methods, corrResults)
% Using subplots with legend at bottom

   % 1. Extract the Summary Table
   sTable = results.summary;
   sTable.method = string(sTable.method);
   [~, loc] = ismember(string(methods), sTable.method);
   plotTable = sTable(loc, :);
   
   nMethods = height(plotTable);
   colors = lines(nMethods);
   
   % Create figure
   fig = figure('Name', 'Radar Comparison', 'Color', 'w');
   
   % Create plots side-by-side
   ax1 = subplot(1, 2, 1);
   kpiMetrics = config.KPImetrics;
   drawRadarNoLegend(plotTable, methods, kpiMetrics, true, kpiMetrics, colors, 'Core KPIs');
   
   ax2 = subplot(1, 2, 2);
   if ~isempty(corrResults) && isfield(corrResults(1).sortedVarNames, 'spearman')
      minSigCorr = 0.15;
      topNcorr = 6; % 10;
      
      allNames = corrResults(1).sortedVarNames.spearman;
      allRho   = corrResults(1).corSsorted;
      
      sigIdx = abs(allRho) > minSigCorr;
      sigNames = allNames(sigIdx);
      topNmetrics = sigNames(1:min(topNcorr, end));
      
      if ~isempty(topNmetrics)
          plotTitle2 = strcat('Top (', num2str(length(topNmetrics)), ') Correlating Metrics');
          % displayNames = formatMetricNames(topNmetrics);
          displayNames = topNmetrics;
          drawRadarNoLegend(results.stats_all, methods, topNmetrics, false, displayNames, colors, plotTitle2);
      else
          axis off;
          text(0.5, 0.5, 'No significant correlations found', 'HorizontalAlignment', 'center');
      end
   else
      axis off;
      text(0.5, 0.5, 'Correlation Data Missing', 'HorizontalAlignment', 'center');
   end
   
   % Adjust subplot positions to make room for legend at bottom
   % Get current positions
   pos1 = get(ax1, 'Position');
   pos2 = get(ax2, 'Position');
   
   % Move plots up (reduce bottom position)
   newBottom = 0.25;
   newHeight = 0.65;
   
   set(ax1, 'Position', [pos1(1), newBottom, pos1(3), newHeight]);
   set(ax2, 'Position', [pos2(1), newBottom, pos2(3), newHeight]);
   
   % --- Create Common Legend at BOTTOM ---
   % Method: Create dummy plots in one of the existing axes for legend
   hold(ax1, 'on');
   h = gobjects(nMethods, 1);
   for m = 1:nMethods
       h(m) = plot(ax1, NaN, NaN, '-o', 'Color', colors(m,:), ...
                   'LineWidth', 2, 'MarkerSize', 8, ...
                   'DisplayName', string(methods(m)));
   end
   hold(ax1, 'off');
   
   % Create legend at BOTTOM
   lgd = legend(h, 'Orientation', 'horizontal', ...
                'NumColumns', min(nMethods, ceil(nMethods/2)));
   lgd.FontSize = 11;
   lgd.Title.String = 'Methods';
   lgd.Title.FontWeight = 'bold';
   
   % Position legend at bottom center of figure
   lgdPos = lgd.Position;
   lgdWidth = 0.4;  % Width of legend (40% of figure width)
   lgd.Position = [(1-lgdWidth)/2*1.11, 0.19, lgdWidth, lgdPos(4)];
   
   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
end

function drawRadarNoLegend(dataSource, methods, metricNames, KPI, labels, colors, plotTitle)
   % Draw radar plot WITHOUT legend (common legend will be added separately)
   nMethods = length(methods);
   nMetrics = length(metricNames);
   
   % Extract and Normalize Data [0, 1]
   if KPI
      dataMatrix = zeros(nMethods, nMetrics);
      for j = 1:nMetrics
         mName = metricNames{j};
         mName = strcat('mean_',mName);
         if ismember(mName, dataSource.Properties.VariableNames)
            vals = dataSource.(mName);
            vMin = min(vals);
            vMax = max(vals);
            if vMax > vMin
                dataMatrix(:, j) = (vals - vMin) / (vMax - vMin);
            else
                dataMatrix(:, j) = 0.5;
            end
         end
      end
   else
      dataMatrix = zeros(nMethods, nMetrics);
      for i = 1:nMetrics
         rawData = extractMetricData(dataSource, methods, metricNames{i});
         dataMatrix(:, i) = (rawData - min(rawData)) / (max(rawData) - min(rawData) + eps);
      end
   end

   % Format labels for display
   labels = string(labels);
   labels = formatMetricNames(labels);
   
   % Setup Angles
   angles = linspace(0, 2*pi, nMetrics + 1);
   angles = angles(1:end-1);
   
   % Plot Circular Grid
   hold on;
   for r = 0.2:0.2:1
      [gx, gy] = pol2cart(linspace(0, 2*pi, 100), r);
      plot(gx, gy, ':', 'Color', [0.7 0.7 0.7], 'HandleVisibility', 'off');
      text(0.05, r, num2str(r), 'FontSize', 7, 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
   end
   
   % Plot Spoke Lines
   for j = 1:nMetrics
      [sx, sy] = pol2cart(angles(j), 1);
      plot([0 sx], [0 sy], '--', 'Color', [0.8 0.8 0.8], 'HandleVisibility', 'off');
      
      [tx, ty] = pol2cart(angles(j), 1.15);
      text(tx, ty, labels{j}, 'HorizontalAlignment', 'center', 'FontSize', 12);
   end

   % Plot Method Polygons (NO LEGEND)
   for i = 1:nMethods
      vals = dataMatrix(i, :);
      vals_closed = [vals, vals(1)];
      angles_closed = [angles, angles(1)];
      
      [px, py] = pol2cart(angles_closed, vals_closed);
      
      if KPI
         fill(px, py, colors(i,:), 'FaceAlpha', 0.03, 'HandleVisibility', 'off');
      end
      
      % Plot WITHOUT legend handle
      plot(px, py, '-o', 'Color', colors(i,:), 'LineWidth', 1.5, 'MarkerSize', 4, ...
           'HandleVisibility', 'off');
   end
   
   title(plotTitle, 'FontSize', 12, 'FontWeight', 'bold');
   axis equal; axis off;
   hold off;
end
