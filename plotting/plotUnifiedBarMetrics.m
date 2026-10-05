function plotUnifiedBarMetrics(results, methods, config)
    stats_all = results.stats_all;
    nMethods = length(methods);
    
    % % Theme 1: ECC-Aware Framework (The "Big Four")
    % metrics1 = {'S_ECC', 'S_ECC_norm', 'eta_ES', 'CR'};
    % titles1 = {'Sustainability (S_{ECC})', 'Peak Congestion (S_ECC_norm)', ...
    %            'Spreading Efficiency (\eta_{ES})', 'Contribution Ratio (CR)'};
    % createUnifiedFigure('ECC-Aware Performance', metrics1, titles1, stats_all, methods, config);

    % % Theme 2: Structural Spreading & Distance
    % metrics2 = {'d_sep_min', 'eta_sep', 'delta_BS', 'delta_G'};
    % titles2 = {'Min Separation (d_{sep,min})', 'Separation Efficiency', ...
    %            'Spreading Diversity (\Delta_{BS})', 'Gini Improvement (\Delta_G)'};
    % createUnifiedFigure('Spreading & Distance Quality', metrics2, titles2, stats_all, methods, config);

    % Theme 3: Local Constraints & Complexity
    metrics3 = {'adjMin', 'laplacianEnergy'};
    titles3 = {'Min Adjacency (d_{adj,min})', 'Structural Complexity (LE)'};
    createUnifiedFigure('Local Constraints & Randomness', metrics3, titles3, stats_all, methods, config);
end

function createUnifiedFigure(figName, metrics, titles, stats_all, methods, config)
    fig = figure('Name', strcat("* ",figName), 'Color', 'w');
    t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    for i = 1:length(metrics)
        nexttile;
        data = extractMetricData(stats_all, methods, metrics{i});
        
        % Vertical Bar Plot Logic
        % Sort: S_ECC_norm is Lower-is-Better, others are Higher-is-Better
        if strcmp(metrics{i}, 'S_ECC_norm')
            [sortedData, sIdx] = sort(data, 'ascend');
        else
            [sortedData, sIdx] = sort(data, 'descend');
        end
        
        b = bar(sortedData, 'FaceColor', 'flat');
        b.CData = repmat([0.2 0.4 0.6], length(methods), 1); % Professional blue
        
        % Force all labels to show
        set(gca, 'XTick', 1:length(methods), ...
                 'XTickLabel', methods(sIdx), ...
                 'XTickLabelRotation', 45, ...
                 'FontSize', 9);
        
        title(titles{i}, 'FontWeight', 'bold');
        grid on;
        
        % Add Threshold for S_ECC_norm
        if strcmp(metrics{i}, 'S_ECC_norm')
            hold on; yline(config.eccReal, 'r--', 'Capacity'); hold off;
        end
    end
end