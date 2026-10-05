function plotKPIbyNoise(KPItableDetailed, config, selectedMethods)
% Shows KPI degradation across noise levels
% Creates subplots for each method showing how CR, BE, effectiveness,
% and RES change with noise intensity

    nMethods = length(selectedMethods);
    noiseLevels = config.noiseLevels;
    nBins = length(noiseLevels);
    
    colors = lines(nMethods);
    line_styles = {'-', '--', '-.', ':'};
    
    %% Organize data by method and noise bin
    CR_by_noise = nan(nMethods, nBins);
    BE_by_noise = nan(nMethods, nBins);
    Eff_by_noise = nan(nMethods, nBins);
    RES_by_noise = nan(nMethods, nBins);
    
    for m = 1:nMethods
        methodName = selectedMethods{m};
        for n = 1:nBins
            idx = strcmp(KPItableDetailed.method, methodName) & ...
                  KPItableDetailed.noiseBin == n;
            
            if any(idx)
                CR_by_noise(m, n) = mean(KPItableDetailed.CR(idx), 'omitnan');
                BE_by_noise(m, n) = mean(KPItableDetailed.BE(idx), 'omitnan');
                Eff_by_noise(m, n) = mean(KPItableDetailed.effectiveness(idx), 'omitnan');
                RES_by_noise(m, n) = mean(KPItableDetailed.RES(idx), 'omitnan');
            end
        end
    end
    
   %% Create figure
   fig = figure('Name', 'KPI vs Noise Level', 'Color', 'w');
   t = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
   title(t, 'KPI Degradation Across Noise Levels', 'FontSize', 12, 'FontWeight', 'bold');
   
   % Subplot 1: CR vs Noise
   ax1 = nexttile; hold on; grid on; box on;
   for m = 1:nMethods
     hMethods(m) = plot(noiseLevels, CR_by_noise(m, :), line_styles{mod(m,4)+1}, 'LineWidth', 1, ...
          'Color', colors(m, :), 'DisplayName', selectedMethods{m});
   end
   xlabel('Noise Level', 'FontSize', 12);
   ylabel('CR', 'FontSize', 12);
   title('CR vs Noise', 'FontSize', 12, 'FontWeight', 'bold');
   
   % Subplot 2: effectiveness vs Noise
   nexttile; hold on; grid on; box on;
   for m = 1:nMethods
     plot(noiseLevels, Eff_by_noise(m, :), line_styles{mod(m,4)+1}, 'LineWidth', 1, ...
          'Color', colors(m, :), 'DisplayName', selectedMethods{m});
   end
   xlabel('Noise Level', 'FontSize', 12);
   ylabel('E', 'FontSize', 12);
   title('Effectiveness vs Noise', 'FontSize', 12, 'FontWeight', 'bold');
   
   % Subplot 3: RES vs Noise
   nexttile; hold on; grid on; box on;
   for m = 1:nMethods
     plot(noiseLevels, RES_by_noise(m, :), line_styles{mod(m,4)+1}, 'LineWidth', 1, ...
          'Color', colors(m, :), 'DisplayName', selectedMethods{m});
   end
   yline(0, 'k--', 'Mean', 'LineWidth', 1, 'Alpha', 0.6);
   xlabel('Noise Level', 'FontSize', 12);
   ylabel('RES_{Z}', 'FontSize', 12);
   title('Resilience-Efficiency Score vs Noise', 'FontSize', 12, 'FontWeight', 'bold');

   % --- Create one legend for all 3 top plots. 
   % 'Orientation', 'horizontal' and 'Layout', 'flow' puts it in a clear row.
   nCols = min(5,nMethods);
   lgd = legend(ax1, hMethods, cellstr(selectedMethods), 'Orientation', 'horizontal', ...
       'NumColumns', nCols, 'Interpreter', 'none', 'FontSize', 10);
   lgd.Layout.Tile = 'south'; % Places it
    
   % sgtitle('KPI Degradation Across Noise Levels', 'FontSize', 12, 'FontWeight', 'bold');
    
   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
end
