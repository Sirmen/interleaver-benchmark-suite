function plotKPIScenarios(detailedTable, config, methods)
% plotKPIScenarios - Visualizes method behavior across priority scenarios
% Iteratively calls calcKPIs_engine to explore the Resilience-Efficiency trade-off.
%
% INPUT:
%   results - struct containing raw simulation logs (.stats_all)
%   config  - struct containing noise reference levels

   % 1. Define the Scenario Range: [w_resilience, w_efficiency]
   weights_range = 0.1:0.05:0.9;
   nPoints = length(weights_range);
   nMethods = length(methods);
   
   % Pre-allocate for constant metrics (computed once)
   cr_mean = zeros(nMethods, 1);
   be_mean = zeros(nMethods, 1);
   cr_z_mean = zeros(nMethods, 1);
   be_z_mean = zeros(nMethods, 1);
   efc_mean = zeros(nMethods, 1);
   
   % Pre-allocate for weight-dependent metrics
   contrib_cr_history = zeros(nMethods, nPoints);
   contrib_be_history = zeros(nMethods, nPoints);
   res_history = zeros(nMethods, nPoints);
   efc_history = zeros(nMethods, nPoints);

   % Get Balanced Scenario (w=0.5) KPI for the bar plot
   [summary_bal, ~, ~] = calcKPIs_engine(detailedTable, config, [0.5, 0.5], methods);
   summary_init = summary_bal;

   for m = 1:nMethods
       mName = methods{m};
       idx = find(strcmp(summary_init.method, mName));
       if ~isempty(idx)
           cr_mean(m) = summary_init.CR(idx);
           be_mean(m) = summary_init.BE(idx);
           cr_z_mean(m) = summary_init.CR_z(idx); 
           be_z_mean(m) = summary_init.BE_z(idx);  
           efc_mean(m) = summary_init.effectiveness(idx);  
       end
   end
   
   % --- Sweep across weight scenarios ---
   for i = 1:nPoints
       w_res = weights_range(i);
       w_be = 1 - w_res;
       weights = [w_res, w_be];
       
       % Compute weighted contributions (linear in weights)
       for m = 1:nMethods
           contrib_cr_history(m, i) = weights(1) * cr_z_mean(m);
           contrib_be_history(m, i) = weights(2) * be_z_mean(m);
           efc_history(m, i) = weights(2) * be_z_mean(m);
       end
       
       % Get RES from engine (for verification/consistency)
       [summary, ~, ~] = calcKPIs_engine(detailedTable, config, weights, methods);
       for m = 1:nMethods
           mName = methods{m};
           idx = find(strcmp(summary.method, mName));
           if ~isempty(idx)
               res_history(m, i) = summary.RES(idx);
           end
       end
   end
   
%%% --- Visualization ---
   fig = figure('Color', 'w', 'Name', 'KPI Analysis');
   
   t = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
   title(t, 'KPI Analysis', 'FontSize', 12, 'FontWeight', 'bold');
%    colors = lines(nMethods);
% colors = turbo(nMethods);      % Good for many distinct colors
colors = hsv(nMethods);        % Classic, but might be too vibrant
% colors = colorcube(nMethods);  % Specifically designed for many categories
% colors = prism(nMethods);      % Distinct qualitative colors
% colors = parula(nMethods);     % Perceptually uniform

% Add line style cycling
line_styles = {'-', '--', '-.', ':'};

   %% SUBPLOT 1: CR Behavioral Sensitivity (The "Crossover" Plot)
   ax1 = nexttile; hold on; grid on; box on;

   for m = 1:nMethods
       hMethods(m) = plot(weights_range, contrib_cr_history(m, :), line_styles{mod(m,4)+1}, 'LineWidth', 1.5, ...
           'Color', colors(m, :), 'DisplayName', char(methods{m}));
   end
   
   yline(0, 'k-', 'LineWidth', 0.5, 'Alpha', 0.5);
   xlabel('Weight on Resilience (w_{CR})');
   ylabel('w_{CR} \times CR_{Z}');
   xlim([0, 1]);
   title('CR Contribution to RES');
   % legend('Location', 'northwest', 'Interpreter', 'none', 'FontSize', 9);
    
   %% SUBPLOT 2: Bandwidth Effectiveness (BE Behavioral Sensitivity (The "Crossover" Plot)
   nexttile; hold on; grid on; box on;
   
   for m = 1:nMethods
       plot(weights_range, contrib_be_history(m, :), line_styles{mod(m,4)+1}, 'LineWidth', 1.5, ...
           'Color', colors(m, :), 'DisplayName', char(methods{m}));
   end
   
   yline(0, 'k-', 'LineWidth', 0.5, 'Alpha', 0.5);
   xlabel('Weight on Resilience (w_{CR})');
   ylabel('w_{BE} \times BE_{Z}');
   xlim([0, 1]);
   title('BE Contribution to RES');
   % legend('Location', 'west', 'Interpreter', 'none', 'FontSize', 9);
   
   %% SUBPLOT 3: RES Across Weight Scenarios
   nexttile; hold on; grid on; box on;
   
   for m = 1:nMethods
       plot(weights_range, res_history(m, :), line_styles{mod(m,4)+1}, 'LineWidth', 1, ...
           'Color', colors(m, :), 'DisplayName', char(methods{m}));
   end
   
   % Scenario markers
   h1 = xline(0.3, '-.', 'Efficiency', 'Color', [0.1,0.1,0.7], 'LineWidth', 1.5, ...
       'LabelVerticalAlignment', 'bottom', 'FontWeight', 'bold', 'FontSize', 10);
   h2 = xline(0.5, '-.', 'Balanced', 'Color', [0.1,0.4,0.1], 'LineWidth', 1.5, ...
       'LabelVerticalAlignment', 'bottom', 'FontWeight', 'bold', 'FontSize', 10);
   h3 = xline(0.8, '-.', 'Resilience', 'Color', [0.7,0.1,0.1], 'LineWidth', 1.5, ...
       'LabelVerticalAlignment', 'bottom', 'FontWeight', 'bold', 'FontSize', 10);
   set([h1 h2 h3], 'HandleVisibility', 'off');
   
   yline(0, 'k-', 'Mean', 'LineWidth', 1, 'Alpha', 0.6);
   xlabel('Weight on Resilience (w_{CR})');
   xlabel('\leftarrow w_{BE} -- Priority -- w_{CR} \rightarrow');
   ylabel('RES ');
   xlim([0, 1]);
   title('RES Across Weight Scenarios');
   % legend('Location', 'west', 'Interpreter', 'none', 'FontSize', 10);
   
   % --- Create one legend for all 3 top plots. 
   % 'Orientation', 'horizontal' and 'Layout', 'flow' puts it in a clear row.
   nCols = min(5,nMethods);
   lgd = legend(ax1, hMethods, cellstr(methods), 'Orientation', 'horizontal', ...
       'NumColumns', nCols, 'Interpreter', 'none', 'FontSize', 10);
   lgd.Layout.Tile = 'north'; % Places it at the very top, above the plots

   %% SUBPLOT 4: CR Balanced Comparison Barplot
   nexttile;

   [~, sort_idx] = sort(cr_mean, 'descend');
   bar_data = cr_mean(sort_idx);
   bar_methods = methods(sort_idx);
   
   b = bar(bar_data, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 0.8);
   for i = 1:length(bar_data)
       b.CData(i,:) = colors(sort_idx(i), :);
   end
   
   set(gca, 'XTick', 1:nMethods, 'XTickLabel', bar_methods, 'TickLabelInterpreter', 'none', ...
       'XTickLabelRotation', 40, 'FontSize', 10);
   % 'XTick', 1:nMethods Forces a tick for every single method

   ylabel('CR');
   title('Resilience Capability');
   grid on;
   ylim([0, max(bar_data)*1.15]);
   
   % for i = 1:length(bar_data)
   %     text(i, bar_data(i), sprintf('%.3f', bar_data(i)), ...
   %         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
   %         'FontSize', 9, 'FontWeight', 'bold');
   % end
   
   %% SUBPLOT 5: Effectiveness
   nexttile;

   [~, sort_idx] = sort(efc_mean, 'descend');
   bar_data = efc_mean(sort_idx);
   bar_methods = methods(sort_idx);
   
   b = bar(bar_data, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 0.8);
   for i = 1:length(bar_data)
       b.CData(i,:) = colors(sort_idx(i), :);
   end
   
   set(gca, 'XTick', 1:nMethods, 'XTickLabel', bar_methods, 'TickLabelInterpreter', 'none', ...
       'XTickLabelRotation', 40, 'FontSize', 10);
   ylabel('E');
   title('Effectiveness');
   grid on;
   ylim([0, max(bar_data)*1.15]);
   
   % for i = 1:length(bar_data)
   %     text(i, bar_data(i), sprintf('%.3f', bar_data(i)), ...
   %         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
   %         'FontSize', 9, 'FontWeight', 'bold');
   % end
   
   %% SUBPLOT 6: RES Balanced Comparison Barplot
   nexttile;

   bar_data = summary_bal.RES;
   bar_methods = summary_bal.method;
   
   b = bar(bar_data, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 0.8);
   
   for i = 1:length(bar_data)
       if bar_data(i) >= 0
           b.CData(i,:) = [0.2 0.7 0.3];
       else
           b.CData(i,:) = [0.8 0.3 0.2];
       end
   end
   
   set(gca, 'XTick', 1:nMethods, 'XTickLabel', bar_methods, 'TickLabelInterpreter', 'none', ...
       'XTickLabelRotation', 40, 'FontSize', 10);
   ylabel('RES_{Z}');
   title('RES (Balanced Scenario: w_{CR}=w_{BE}=0.5)');
   yline(0, 'k--', 'Mean', 'LineWidth', 1.5);
   grid on;
   
   y_range = max(bar_data) - min(bar_data);
   for i = 1:length(bar_data)
       if bar_data(i) >= 0
           y_offset = 0.03 * y_range;
           valign = 'bottom';
       else
           y_offset = -0.03 * y_range;
           valign = 'top';
       end
       % text(i, bar_data(i) + y_offset, sprintf('%.2f', bar_data(i)), ...
       %     'HorizontalAlignment', 'center', 'VerticalAlignment', valign, ...
       %     'FontSize', 9, 'FontWeight', 'bold');
   end
   
   ylim([min(bar_data) - 0.15*y_range, max(bar_data) + 0.15*y_range]);

%% ===== Save Figure
   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);
      fprintf('%s \n',sMsg);
   end
end

