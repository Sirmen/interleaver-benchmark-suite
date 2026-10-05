function plotPerformanceComplexityTradeoff(results, KPItableSummary, methods, config)
% Performance vs computational complexity - grouped bars sorted by RES
% Uses KPI metrics (RES) instead of old effectiveness metric
%
% INPUT:
%   results          - Results struct with runtime data
%   KPIsummaryTable  - KPI summary table from calcKPIs
%   methods          - Cell array of method names

    nMethods = length(methods);
    performance = zeros(1, nMethods);
    runtime = zeros(1, nMethods);
    
    % Extract RES scores and runtime
    for i = 1:nMethods
        method = methods{i};
        
        % Get RES from KPI summary table
        idx = strcmp(KPItableSummary.method, method);
        if any(idx)
            performance(i) = KPItableSummary.RES(idx);
        else
            performance(i) = NaN;
        end
        
        % Get runtime
        if isfield(results, 'avIntRuntime_all')
            runtime(i) = mean(extractfield(results.avIntRuntime_all, method));
        else
            runtime(i) = NaN;
        end
    end
    
    % Calculate efficiency: performance per second
    % For RES (Z-score), normalize to positive range first
    RES_shifted = performance - min(performance); % Shift to start at 0
    efficiency = RES_shifted ./ (runtime + 1e-6);  % Avoid division by zero
    
    % Normalize efficiency to [0, 1]
    if max(efficiency) > min(efficiency)
        efficiency = (efficiency - min(efficiency)) / (max(efficiency) - min(efficiency));
    else
        efficiency = ones(size(efficiency)); % All equal
    end
    
    % Sort by efficiency (descending - best at top)
    [sortedEff, sortIdx] = sort(efficiency, 'descend');
    sortedMethods = methods(sortIdx);
    sortedRuntime = runtime(sortIdx);
    sortedRES = performance(sortIdx);
    
    
    fig = figure('Name', 'Performance-Complexity Tradeoff', 'Color', 'w');

    % Calculate appropriate figure height
    barHeight = 25; % pixels per method
    figHeight = max(600, nMethods * barHeight + 150);
    
    % Create horizontal bar chart
    b = barh(sortedEff, 'BarWidth', 0.75);
    b.FaceColor = [0.7, 1.0, 0.8];
    b.EdgeColor = 'k';
    b.LineWidth = 0.5;
    
    % Customize axes
    set(gca, 'YTick', 1:nMethods);
    set(gca, 'YTickLabel', sortedMethods);
    set(gca, 'YDir', 'reverse'); % Best at top
    set(gca, 'FontSize', 10);
    set(gca, 'TickLabelInterpreter', 'none');
    
    xlabel('Normalized Efficiency Score (RES / Runtime)', 'FontSize', 11, 'FontWeight', 'bold');
    % ylabel('Method', 'FontSize', 11, 'FontWeight', 'bold');
    
    % Set x-axis limits with space for labels
    xlim([0, 1.2]);
    
    grid on;
    box on;
    
    % Add efficiency value labels on bars
    for i = 1:nMethods
        if sortedEff(i) > 0.15
            % Inside bar (black text)
            text(sortedEff(i) - 0.05, i, sprintf('%.3f', sortedEff(i)), ...
                 'FontSize', 8, 'Color', [0, 0, 0], ...
                 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'right');
        else
            % Outside bar (black text)
            text(sortedEff(i) + 0.02, i, sprintf('%.3f', sortedEff(i)), ...
                 'FontSize', 8, 'Color', [0, 0, 0], ...
                 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left');
        end
    end
    
    % Add RES column (middle)
    for i = 1:nMethods
        text(1.06, i, sprintf('%.2f', sortedRES(i)), ...
             'FontSize', 9, 'Color', [0.2, 0.2, 0.6], ...
             'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center', ...
             'FontWeight', 'bold');
    end
    
    % Add runtime column (right)
    for i = 1:nMethods
        % Format runtime nicely
        if sortedRuntime(i) < 0.001
            runtimeStr = sprintf('%.0fµs', sortedRuntime(i) * 1e6);
        elseif sortedRuntime(i) < 1
            runtimeStr = sprintf('%.1fms', sortedRuntime(i) * 1000);
        else
            runtimeStr = sprintf('%.2fs', sortedRuntime(i));
        end
        
        text(1.15, i, runtimeStr, ...
             'FontSize', 9, 'Color', [0.4, 0.4, 0.4], ...
             'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center');
    end
    
    % Add column headers
    text(1.06, 0.6, 'RES', ...
         'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.2, 0.2, 0.6], ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    
    text(1.15, 0.6, 'Runtime', ...
         'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.3, 0.3, 0.3], ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    
    
   % Add threshold lines
   hold on;
   xline(0.8, 'b--', 'High Efficiency', 'LabelVerticalAlignment','bottom',...
      'LabelHorizontalAlignment','right','FontSize',10,'FontWeight','bold','ColorMode','auto');
   xline(0.5, 'm--', 'Moderate', 'LabelVerticalAlignment','bottom', ...
      'LabelHorizontalAlignment','right','FontSize',10,'FontWeight','bold','ColorMode','auto');
   hold off;
    
    % Title with explanation
    title({'Performance-Complexity Tradeoff (Sorted by Efficiency)', ...
           'Efficiency = RES_{normalized} / Runtime (Higher is Better)'}, ...
          'FontSize', 12, 'FontWeight', 'bold');
    
    % Adjust axes position for labels
    ax = gca;
    ax.Position(1) = 0.15;  % Left margin
    ax.Position(3) = 0.68;  % Width (space for columns)
    
    % Save if configured
    if isfield(results, 'config') && isfield(results.config, 'saveResults') && ...
       results.config.saveResults && isfield(results.config, 'dataSavePath')
        [saveDir, ~, ~] = fileparts(results.config.dataSavePath);
        savePath = fullfile(saveDir, 'performance_complexity_tradeoff.png');
        saveas(gcf, savePath);
        fprintf('Performance-Complexity tradeoff plot saved to: %s\n', savePath);
    end
   
   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
end
