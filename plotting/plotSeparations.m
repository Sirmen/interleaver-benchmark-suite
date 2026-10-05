function plotSeparations(stats_all, intMethods, selectedMethods)
   % If selectedMethods is not provided, use all methods
   if nargin < 3 || isempty(selectedMethods) 
       selectedMethods = intMethods;
   end
   
   % Filter to only include selected methods
   [filteredStats, filteredMethods] = filterMethods(stats_all, intMethods, selectedMethods);
   
   distances = {'sepMin', 'sepMax', 'sepAvg', 'sepVar', 'sepCV'};
   nDist = length(distances);
   nMethod = length(filteredMethods);

   %% Create comprehensive figure with 2x3 layout
   figure('Name', 'Interleaved Separation Statistics'); % , 'Position', [100 100 1200 800]);
    
   % Create consistent color scheme for all methods
   colors = distinguishable_colors(nMethod);
   % colorScheme = 'colorblind';
   % colors = getColorScheme(colorScheme, length(filteredMethods));
    
   % Store method handles for legend
   method_handles = gobjects(nMethod, 1);
    
   for m = 1:nMethod
      % Extract indices where method = filteredMethod
      indices = strcmp(string({filteredStats.method}), filteredMethods(m));
      filteredData = filteredStats(indices);
      
      if isempty(filteredData)
         continue;
      end
      
      % Get current color
      color = colors(m,:);
      
      % Extract all separation metrics
      sepMin = [filteredData.("sepMin")];
      sepMax = [filteredData.("sepMax")];
      sepAvg = [filteredData.("sepAvg")];
      sepVar = [filteredData.("sepVar")];
      sepCV = [filteredData.("sepCV")];
      sepEff = [filteredData.("eta_sep")];
      
      % Create x-axis (assuming sequential data points)
      x_axis = 1:length(filteredData);
      
      %% Plot 1: Min Separations (detailed)
      subplot(2,3,1);
      plot(x_axis, sepMin, '-', 'Color', color, 'LineWidth', 1.5, 'DisplayName', filteredMethods{m});
      hold on;
      title('Minimum Separations');
      xlabel('N');
      ylabel('Normalized Separation');
      grid on;
      
      %% Plot 2: Average Separations (detailed)
      subplot(2,3,2);
      plot(x_axis, sepAvg, '-', 'Color', color, 'LineWidth', 1.5, 'DisplayName', filteredMethods{m});
      hold on;
      title('Average Separations');
      xlabel('N');
      ylabel('Normalized Separation');
      grid on;
      
      %% Plot 3: Max Separations
      subplot(2,3,3);
      plot(x_axis, sepMax, '-', 'Color', color, 'LineWidth', 1.5, 'DisplayName', filteredMethods{m});
      hold on;
      title('Maximum Separations');
      xlabel('N');
      ylabel('Normalized Separation');
      grid on;
      
      %% Plot 4: Coefficient of Variation
      subplot(2,3,4);
      plot(x_axis, sepCV, '-', 'Color', color, 'LineWidth', 1.5, 'DisplayName', filteredMethods{m});
      hold on;
      title('Coefficient of Variation');
      xlabel('N');
      ylabel('CV');
      grid on;
      
      %% Plot 5: Separation Efficiency
      subplot(2,3,5);
      h = plot(x_axis, sepEff, '-', 'Color', color, 'LineWidth', 1.5, 'DisplayName', filteredMethods{m});
      method_handles(m) = h; % Store handle for legend
      hold on;
      title('Separation Efficiency');
      xlabel('N');
      ylabel('Efficiency Ratio');
      grid on;
      
      %% Plot 6: Statistical Summary
      subplot(2,3,6);
      stats_summary = [mean(sepMin), mean(sepMax), mean(sepAvg), mean(sepVar), mean(sepCV)];
      bar_positions = (1:5) + (m-1)*0.15;
      bar(bar_positions, stats_summary, 0.1, 'FaceColor', color, 'DisplayName', filteredMethods{m});
      hold on;
   end
    
   %% Final plot formatting
   % Set consistent y-limits for comparison
   subplot(2,3,1); ylim([0 max([0.5, max(ylim)])]);
   subplot(2,3,2); ylim([0 max([0.6, max(ylim)])]);
   subplot(2,3,3); ylim([0 max([1.1, max(ylim)])]);
   
   % Final styling for statistical summary plot (Plot 6)
   subplot(2,3,6);
   set(gca, 'XTick', 1:5, 'XTickLabel', {'Min', 'Max', 'Avg', 'Var', 'CV'});
   ylabel('Value');
   xlabel('Metric');
   title('Method Comparison (Mean Values)');
   grid on;
   xlim([0.5 5.5]); % Adjust x-axis limits to fit all bars
    
   %% Add a single shared legend at the bottom
   lgdCols = min(6, nMethod); % legend columns count
   addSharedLegend(filteredMethods, lgdCols, colors);

   % Add overall title
   sgtitle('Interleaver Separation Performance Metrics', 'FontSize', 12, 'FontWeight', 'bold');
   
   % Enable interactive data tips
   dcm_obj = datacursormode(gcf);
   set(dcm_obj, 'UpdateFcn', @hoverCallbackName);
end

function [filteredStats, filteredMethods] = filterMethods(stats_all, allMethods, selectedMethods)
    % Filter statistics and methods to only include selected ones
    if isempty(selectedMethods)
        filteredStats = stats_all;
        filteredMethods = allMethods;
        return;
    end
    
    % Convert to string for consistent comparison
    selectedMethods = string(selectedMethods);
    allMethods = string(allMethods);
    
    % Find indices of selected methods
    [~, methodIndices] = ismember(selectedMethods, allMethods);
    validIndices = methodIndices(methodIndices > 0);
    
    % Filter the methods
    filteredMethods = allMethods(validIndices);
    
    % Filter the statistics data
    filteredStats = stats_all(ismember(string({stats_all.method}), selectedMethods));
end

function output_txt = hoverCallbackName(~, event_obj)
    % Customizes the data tip to show the DisplayName of the line
    hLine = get(event_obj, 'Target');
    output_txt = get(hLine, 'DisplayName');
end