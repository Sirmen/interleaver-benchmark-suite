function plot_anova_results(anovaResults, results, methodsSelected, config)
% plot_anova_results visualization aligned with two-way ANOVA
% Layout:
%   [Tile 1] Bar Chart: Mean RES per Method (Sorted)
%   [Tile 2] Bar Chart: Mean Effectiveness per Method (Sorted)
%   [Tile 3] Interaction: Method × Noise (First half of top methods)
%   [Tile 4] Interaction: Method × Noise (Second half of top methods)

   summary     = results.summary;
   methodsTop  = results.topMethods(:);
   methodStats = anovaResults.methodStats;
   noiseLv     = anovaResults.noiseLevels(:);

   %% Filter to only include selected methods
   allMethodFields = summary.method; % Get all method names from summary
   
   % Find which fields to keep (intersection of all fields and selected methods)
   fieldsToKeep = intersect(allMethodFields, methodsSelected);
   
   if (length(allMethodFields) ~= length(fieldsToKeep))
      % Filter summary table to only include rows for selected methods
      summary = summary(ismember(summary.method, methodsSelected), :);
   
      % Remove fields that are not in the selected methods list
      for i = 1:length(allMethodFields)
          if ~ismember(allMethodFields{i}, fieldsToKeep)
              methodStats = rmfield(methodStats, allMethodFields{i});
          end
      end
   end

   %% Sort summary by RES to make the bar charts readable/ordered
   summary = sortrows(summary, 'mean_RES', 'descend');
   
   fig = figure('Name', 'ANOVA', 'Units', 'normalized'); % , 'Position', [0.1 0.1 0.8 0.7]);
   tlo = tiledlayout(2, 2, 'TileSpacing', 'Compact', 'Padding', 'Compact');
   
   %% ==============================================================
   % TILE 1: RES Ratio Bar Chart
   % ==============================================================
   nexttile; hold on;
   x = 1:height(summary);
   
   % Draw Bars
   bar(x, summary.mean_RES, 'FaceColor', [0.3 0.6 0.8], 'EdgeColor', 'none');
   
   % Draw Confidence Intervals (1.96 * SEM)
   errorbar(x, summary.mean_RES, 1.96 * summary.sem_CR, 'k.', ...
            'LineWidth', 1.2, 'CapSize', 6);
   
   set(gca, 'XTick', x, 'XTickLabel', summary.method, 'XTickLabelRotation', 45);
   ylabel('Mean RES');
   title('RES: Resiliance Efficiency Score');
   grid on;
   
   %% ==============================================================
   % TILE 2: Effectiveness Bar Chart
   % ==============================================================
   nexttile; hold on;
   
   [sortedData, sortIdx] = sort(summary.mean_effectiveness, 'descend');
   sortedMethods = summary.method(sortIdx);
   
   % Draw Bars
   % bar(x, summary.mean_effectiveness, 'FaceColor', [0.8 0.6 0.3], 'EdgeColor', 'none');
   bar(x, sortedData, 'FaceColor', [0.8 0.6 0.3], 'EdgeColor', 'none');
   
   % Draw Confidence Intervals
   errorbar(x, sortedData, 1.96 * summary.sem_effectiveness(sortIdx), 'k.', ...
            'LineWidth', 1.2, 'CapSize', 6);
   
   % set(gca, 'XTick', x, 'XTickLabel', summary.method, 'XTickLabelRotation', 45);
   set(gca, 'XTick', x, 'XTickLabel', sortedMethods, 'XTickLabelRotation', 45);
   ylabel('Mean Effectiveness');
   title('Secondary Metric: System Effectiveness');
   grid on;

   %% ==============================================================
   % TILES 3 & 4: Interaction plots (Method x Noise)
   % ==============================================================
   topN = numel(methodsTop);
   
   if topN == 0
       nexttile; text(0.5,0.5, 'No top methods data', 'H', 'center'); axis off;
       nexttile; axis off;
   else
       splitPoint = ceil(topN/2);
       
       % Tile 3: First half of top performers
       nexttile;
       halve1 = methodsTop(1:splitPoint);
       plot_interaction(halve1, methodStats, noiseLv);
       title(sprintf('Interaction: Method × Noise (Top 1–%d)', splitPoint));
       xlabel('Noise Level (relative to ECC)');
       ylabel('Mean RES');
       
       % Tile 4: Second half of top performers
       nexttile;
       if topN > 1
         halve2 = methodsTop(splitPoint+1:end);
         plot_interaction(halve2, methodStats, noiseLv);
         title(sprintf('Interaction: Method × Noise (Top %d–%d)', splitPoint+1, topN));
       else
         text(0.5, 0.5, 'Only one top method identified', 'H', 'center');
         axis off;
       end
       xlabel('Noise Level (relative to ECC)');
   end
   
   % Global Title
   title(tlo, 'ANOVA Statistical Summary: Interleaver Performance & Robustness', ...
         'FontSize', 12, 'FontWeight', 'bold');
   
   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
end

function plot_interaction(methodList, methodStats, noiseLv)
   if isempty(methodList), return; end
   if ischar(methodList), methodList = {methodList}; end
   
   colors = lines(numel(methodList));
   hold on;
   
   % Legend proxy for confidence ribbon
   fill(nan, nan, [0.5 0.5 0.5], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'DisplayName', '95% CI');
   
   for i = 1:numel(methodList)
       m = methodList{i};
       if ~isfield(methodStats, m), continue; end
       
       st = methodStats.(m);
       mu = st.mean_RES;
       ci = 1.96 * st.sem_CR;
       
       valid = ~isnan(mu) & ~isnan(ci) & st.N_CR > 1;
       x_plot  = noiseLv(valid);
       mu_plot = mu(valid);
       ci_plot = ci(valid);
   
       if numel(x_plot) < 2, continue; end
   
       % Plot Confidence Ribbon
       fill([x_plot; flipud(x_plot)], [mu_plot - ci_plot; flipud(mu_plot + ci_plot)], ...
            colors(i,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
   
       % Plot Mean Line
       plot(x_plot, mu_plot, '-o', 'Color', colors(i,:), 'LineWidth', 1, 'DisplayName', m);
       hold on;
   end
   
   legend('Location', 'best', 'NumColumns', 2, 'Interpreter', 'none', 'FontSize', 8);
   grid on;
end
