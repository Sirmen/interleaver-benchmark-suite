function plotKPIHeatmaps(KPItableDetailed, config)
% plotKPIHeatmaps - Heatmap visualization of KPIs
%
% Creates heatmaps showing Method × Noise for each KPI metric

    methods = unique(KPItableDetailed.method, 'stable');
    nMethods = length(methods);
    noiseLevels = config.noiseLevels;
    nBins = length(noiseLevels);
    
    %% Organize data
    CR_matrix = nan(nMethods, nBins);
    BE_matrix = nan(nMethods, nBins);
    Eff_matrix = nan(nMethods, nBins);
    RES_matrix = nan(nMethods, nBins);
    
    for m = 1:nMethods
        for n = 1:nBins
            idx = strcmp(KPItableDetailed.method, methods{m}) & ...
                  KPItableDetailed.noiseBin == n;
            
            if any(idx)
                CR_matrix(m, n) = mean(KPItableDetailed.CR(idx), 'omitnan');
                BE_matrix(m, n) = mean(KPItableDetailed.BE(idx), 'omitnan');
                Eff_matrix(m, n) = mean(KPItableDetailed.effectiveness(idx), 'omitnan');
                RES_matrix(m, n) = mean(KPItableDetailed.RES(idx), 'omitnan');
            end
        end
    end
    
    %% Create figure
    fig = figure('Name', 'KPI Heatmaps', 'Color', 'w');
    
    noiseLabels = arrayfun(@(x) sprintf('%.3f', x), noiseLevels, 'UniformOutput', false);
    
    % CR Heatmap
    subplot(2, 2, 1);
    imagesc(CR_matrix);
    colorbar;
    colormap(subplot(2, 2, 1), parula);
    set(gca, 'XTick', 1:nBins, 'XTickLabel', noiseLabels, 'XTickLabelRotation', 45);
    set(gca, 'YTick', 1:nMethods, 'YTickLabel', methods, 'TickLabelInterpreter', 'none');
    xlabel('Noise Level', 'FontWeight', 'bold');
    ylabel('Method', 'FontWeight', 'bold');
    title('CR_{adj} Heatmap', 'FontSize', 13, 'FontWeight', 'bold');
    
    % Add values as text
    for m = 1:nMethods
        for n = 1:nBins
            if ~isnan(CR_matrix(m, n))
                text(n, m, sprintf('%.3f', CR_matrix(m, n)), ...
                     'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'w', 'FontWeight', 'bold');
            end
        end
    end
    
    % BE Heatmap
    subplot(2, 2, 2);
    imagesc(BE_matrix);
    colorbar;
    colormap(subplot(2, 2, 2), parula);
    set(gca, 'XTick', 1:nBins, 'XTickLabel', noiseLabels, 'XTickLabelRotation', 45);
    set(gca, 'YTick', 1:nMethods, 'YTickLabel', methods, 'TickLabelInterpreter', 'none');
    xlabel('Noise Level', 'FontWeight', 'bold');
    ylabel('Method', 'FontWeight', 'bold');
    title('BE Heatmap', 'FontSize', 13, 'FontWeight', 'bold');
    
    for m = 1:nMethods
        for n = 1:nBins
            if ~isnan(BE_matrix(m, n))
                text(n, m, sprintf('%.3f', BE_matrix(m, n)), ...
                     'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'w', 'FontWeight', 'bold');
            end
        end
    end
    
    % Effectiveness Heatmap
    subplot(2, 2, 3);
    imagesc(Eff_matrix);
    colorbar;
    colormap(subplot(2, 2, 3), parula);
    set(gca, 'XTick', 1:nBins, 'XTickLabel', noiseLabels, 'XTickLabelRotation', 45);
    set(gca, 'YTick', 1:nMethods, 'YTickLabel', methods, 'TickLabelInterpreter', 'none');
    xlabel('Noise Level', 'FontWeight', 'bold');
    ylabel('Method', 'FontWeight', 'bold');
    title('Effectiveness Heatmap', 'FontSize', 13, 'FontWeight', 'bold');
    
    for m = 1:nMethods
        for n = 1:nBins
            if ~isnan(Eff_matrix(m, n))
                text(n, m, sprintf('%.3f', Eff_matrix(m, n)), ...
                     'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'w', 'FontWeight', 'bold');
            end
        end
    end
    
    % RES Heatmap
    subplot(2, 2, 4);
    imagesc(RES_matrix);
    colorbar;
    colormap(subplot(2, 2, 4), redblue); % Diverging colormap for Z-scores
    set(gca, 'XTick', 1:nBins, 'XTickLabel', noiseLabels, 'XTickLabelRotation', 45);
    set(gca, 'YTick', 1:nMethods, 'YTickLabel', methods, 'TickLabelInterpreter', 'none');
    xlabel('Noise Level', 'FontWeight', 'bold');
    ylabel('Method', 'FontWeight', 'bold');
    title('RES Heatmap (Z-score)', 'FontSize', 13, 'FontWeight', 'bold');
    
    for m = 1:nMethods
        for n = 1:nBins
            if ~isnan(RES_matrix(m, n))
                text(n, m, sprintf('%.2f', RES_matrix(m, n)), ...
                     'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'k', 'FontWeight', 'bold');
            end
        end
    end
    
    sgtitle('KPI Performance Heatmaps (Method × Noise)', 'FontSize', 15, 'FontWeight', 'bold');
    
   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
end

% Helper: Red-Blue diverging colormap
function cmap = redblue(m)
    if nargin < 1, m = 64; end
    r = [(0:m/2-1)'/(m/2-1); ones(m/2,1)];
    g = [(0:m/2-1)'/(m/2-1); (m/2-1:-1:0)'/(m/2-1)];
    b = [ones(m/2,1); (m/2-1:-1:0)'/(m/2-1)];
    cmap = [r g b];
end
