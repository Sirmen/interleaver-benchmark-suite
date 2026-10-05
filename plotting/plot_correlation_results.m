function plot_correlation_results(corrResults, config)
try
   if isempty(corrResults)
      return;
   end
   
   for i = 1:length(corrResults)
      res = corrResults(i);
      if isempty(res.pivotVariable); continue; end
      
      % Create Figure
      figName = sprintf('Correlation Analysis (%s)', res.pivotVariable);
      fig = figure('Name', figName, 'Color', 'w');
      
      % Pearson Subplot
      subplot(2,1,1);
      if ~isempty(res.corPsorted)
         corrGraphSorted(res.corPsorted, res.sortedVarNames.pearson, "Pearson", res.pivotVariable);
         % title(sprintf('Pearson Correlation with %s (N=%d, Max=%.3f)', ...
         title(sprintf('Pearson Correlation with %s (Max=%.3f)', ...
               res.pivotVariable, res.cMaxP), 'FontSize', 11);
      else
         text(0.5, 0.5, 'No valid Pearson correlations', 'HorizontalAlignment', 'center');
      end
      
      % Spearman Subplot
      subplot(2,1,2);
      if ~isempty(res.corSsorted)
         corrGraphSorted(res.corSsorted, res.sortedVarNames.spearman, "Spearman", res.pivotVariable);
         % title(sprintf('Spearman Correlation with %s (N=%d, Max=%.3f)', ...
         title(sprintf('Spearman Correlation with %s (Max=%.3f)', ...
               res.pivotVariable, res.cMaxS), 'FontSize', 11);
      else
         text(0.5, 0.5, 'No valid Spearman correlations', 'HorizontalAlignment', 'center');
      end
      
      % Unified Super Title
      sgtitle(sprintf('Correlation Distribution: %s', res.pivotVariable), ...
             'FontSize', 12, 'FontWeight', 'bold');
   
      if config.saveResults
         sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
      end
      
   end
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

function corrGraphSorted(correlations, variableNames, corrType, pivotVariable)
% Plot sorted correlation results as horizontal bars
    
    if isempty(correlations) || all(isnan(correlations))
        text(0.5, 0.5, 'No valid correlations to display', ...
             'HorizontalAlignment', 'center', 'FontSize', 14);
        axis off;
        return;
    end
    
    % Limit to top N correlations for readability
    topN = 25;
    maxDisplay = min(topN, length(correlations));
    corrToPlot = correlations(1:maxDisplay);
    varsToPlot = variableNames(1:maxDisplay);
    
    % Create horizontal bar plot
    h = barh(1:maxDisplay, corrToPlot, 'BarWidth', 0.8);
    
    % Color bars based on correlation value
    % Positive = blue, Negative = red
    colors = zeros(maxDisplay, 3);
    for i = 1:maxDisplay
        if corrToPlot(i) >= 0
            colors(i, :) = [0.6, 0.9, 0.6]; % Green for positive
        else
            colors(i, :) = [0.9, 0.6, 0.6]; % Blue for negative
        end
    end
    
    % Apply colors to each bar
    h.FaceColor = 'flat';
    h.CData = colors;
    
    % Customize plot
    varsToPlot = formatMetricNames(varsToPlot);

    set(gca, 'YTick', 1:maxDisplay);
    set(gca, 'YTickLabel', varsToPlot);
    set(gca, 'YDir', 'reverse'); % Highest correlation at top
    set(gca, 'FontSize', 10);
    % set(gca, 'TickLabelInterpreter', 'none'); % Prevent issues with special chars
    
    % xlabel(sprintf('%s Correlation with %s', corrType, pivotVariable), 'FontSize', 10);
    % ylabel('Variables', 'FontSize', 10);
    grid on;
    
    % Add vertical line at zero
    hold on;
    xline(0, 'k--', 'LineWidth', 1.5);
    
    % % Add value labels on bars
    % for i = 1:maxDisplay
    %     if ~isnan(corrToPlot(i))
    %         xPos = corrToPlot(i);
    %         if abs(xPos) < 0.1
    %             % Small values - place label outside
    %             xPos = sign(xPos) * 0.15;
    %         end
    %         text(xPos * 1.15, i, sprintf('%.3f', corrToPlot(i)), ...
    %              'FontSize', 7, 'VerticalAlignment', 'middle', ...
    %              'HorizontalAlignment', 'left');
    %     end
    % end
    % hold off;
    
    % Set x-axis limits with some padding
    maxAbs = max(abs(corrToPlot));
    if maxAbs > 0
        xlim([-maxAbs*1.15, maxAbs*1.15]);
    else
        xlim([-1 1]);
    end
    
    % % Add correlation strength indicators
    % hold on;
    % % Strong correlation threshold
    % xline(0.7, 'g--', 'Strong+', 'LineWidth', 1, 'LabelHorizontalAlignment', 'left', ...
    %       'FontSize', 8, 'Alpha', 0.5);
    % xline(-0.7, 'g--', 'Strong-', 'LineWidth', 1, 'LabelHorizontalAlignment', 'right', ...
    %       'FontSize', 8, 'Alpha', 0.5);
    % % Moderate correlation threshold
    % xline(0.4, 'y--', 'Moderate+', 'LineWidth', 1, 'LabelHorizontalAlignment', 'left', ...
    %       'FontSize', 8, 'Alpha', 0.5);
    % xline(-0.4, 'y--', 'Moderate-', 'LineWidth', 1, 'LabelHorizontalAlignment', 'right', ...
    %       'FontSize', 8, 'Alpha', 0.5);
    % hold off;
end
