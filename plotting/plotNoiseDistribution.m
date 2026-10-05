function erM = plotNoiseDistribution(stats_all, methods, config, ...
                                     rcv_enc_ns, L, burstSize, burstCount)
% Plot noise distribution analysis
% stats_all is now an ARRAY, not a structure with method-named fields
erM = "";
try
    fig = figure('Name', 'Noise Distribution Analysis'); % , 'Position', [100 100 1400 900]);
    
    nMethods = length(methods);
    nCols = min(4, nMethods);
    nTiles = nCols * (ceil(nMethods / nCols));
    
    % Use tiledlayout for better control over axes sharing
    t = tiledlayout(fig, ceil(nMethods / nCols), nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % For each method, plot noise distribution
    for m = 1:nMethods
        method = methods{m};
        
        % Extract stats for this method from array
        methodStats = getMethodStats(stats_all, method);
        
        if isempty(methodStats)
            continue;
        end
        
        % Get the last valid run for visualization
        validIdx = find(arrayfun(@(x) isfield(x, 'noiseLocations') && ...
                                      ~isempty(x.noiseLocations), methodStats), 1, 'last');
        
        if isempty(validIdx)
            continue;
        end
        
        stats = methodStats(validIdx);
        noisePositions = find(stats.noiseLocations);
        permutation = stats.permutation;
        
        % Determine row and column index
        rowIdx = ceil(m / nCols);
        colIdx = mod(m - 1, nCols) + 1;
        
        % Check label visibility flags
        isFirstCol = (colIdx == 1);
        isLastRow = (rowIdx == ceil(nMethods / nCols));
        isFirstTile = (m == 1);
        
        nexttile;
        plotNoisePositionsSubset(noisePositions, permutation, L, method, ...
                                 isLastRow, isFirstCol, isFirstTile);
    end
    
    % % Summary subplot (if needed, this would use the remaining tiles)
    % nexttile(nTiles + 1, [1, nCols]); % Use the next row for summary
    % plotNoiseSpreadingSummary(stats_all, methods, L);
    
    sgtitle(sprintf('Noise Distribution Analysis (N=%d, L=%d, Burst=%.2f×%.1f)', ...
            length(rcv_enc_ns), L, burstSize, burstCount), 'FontSize', 11, 'FontWeight', 'bold');

   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end

catch ME
   erM = sprintf('*** %s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   fprintf('%s\n', erM);
end
end

function plotNoisePositionsSubset(noisePositions, permutation, blockSize, methodName, isLastRow, isFirstCol, isFirstTile)
% Visualize noise positions before and after interleaving
% Added isFirstTile flag to control legend display

    if isempty(noisePositions)
        text(0.5, 0.5, 'No noise data', 'HorizontalAlignment', 'center');
        title(methodName);
        axis off;
        return;
    end
    
    % Map to interleaved positions
    interleavedPositions = permutation(noisePositions);
    
    % Calculate block assignments
    originalBlocks = ceil(noisePositions / blockSize);
    interleavedBlocks = ceil(interleavedPositions / blockSize);
    
    % Calculate spreading metrics
    uniqueInterleavedBlocks = length(unique(interleavedBlocks));
    totalBlocks = max(interleavedBlocks);
    spreadPercentage = 100 * uniqueInterleavedBlocks / totalBlocks;
    
    % Plot
    hold on;
    
    % Original positions (red circles)
    h1 = scatter(noisePositions, ones(size(noisePositions)), 50, 'r', 'filled', ...
            'MarkerFaceAlpha', 0.6);
    
    % Interleaved positions (blue circles)
    h2 = scatter(interleavedPositions, 2*ones(size(interleavedPositions)), 50, 'b', 'filled', ...
            'MarkerFaceAlpha', 0.6);
    
    % Draw lines connecting original to interleaved
    for i = 1:length(noisePositions)
        plot([noisePositions(i), interleavedPositions(i)], [1, 2], ...
             '-', 'LineWidth', 0.5, 'Color', [0.5 0.5 0.5 0.3]);
    end
    
    % Legend: Display only for the first tile
    if isFirstTile
        legend([h1, h2], {'Original', 'Interleaved'}, ...
               'Location', 'northeast', 'FontSize', 8);
    end
    
    % Formatting
    ylim([0.5 2.5]);
    yticks([1 2]);
    
    % Y-Axis Labels: Display only for the leftmost column
    if isFirstCol
      yticklabels({'Original', 'Interleaved'});
    else
      yticklabels({}); % Hide Y-labels
    end
    
    % X-Axis Label: Display only for the last row
    if isLastRow
      xlabel('Position', 'FontSize', 9);
    else
      xticklabels({}); % Hide X-ticks and labels for intermediate rows
    end

    title(sprintf('%s: Spread:%.1f%% (%d/%d)', ...
          methodName, spreadPercentage, uniqueInterleavedBlocks, totalBlocks), ...
          'FontSize', 10, 'Interpreter', 'none');
    grid on;
    box on;
    
    % Adjust axes limits to show all data
    xlim([0, max([noisePositions, interleavedPositions]) + 5]);
end

function plotNoiseSpreadingSummary(stats_all, methods, blockSize)
% Summary comparison of noise spreading across methods
    
    nMethods = length(methods);
    
    % Collect metrics
    blockCoverage = zeros(1, nMethods);
    spreadingEff = zeros(1, nMethods);
    
    for m = 1:nMethods
        method = methods{m};
        methodStats = getMethodStats(stats_all, method);
        if isempty(methodStats)
            continue;
        end
        
        % Average across all runs
        validStats = methodStats(arrayfun(@(x) isfield(x, 'blockOccupancyRatio'), methodStats));
        
        if ~isempty(validStats)
            blockCoverage(m) = mean([validStats.blockOccupancyRatio]);
            spreadingEff(m) = mean([validStats.errorSpreadingEfficiency]);
        end
    end
    
    % Plot comparison
    x = 1:nMethods;
    bar(x - 0.2, blockCoverage, 0.4, 'FaceColor', [0.8 0.4 0.4], ...
        'DisplayName', 'Block Coverage');
    hold on;
    bar(x + 0.2, spreadingEff, 0.4, 'FaceColor', [0.4 0.8 0.4], ...
        'DisplayName', 'Spreading Efficiency');
    
    set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 45);
    ylabel('Score');
    title('Noise Spreading Comparison');
    legend('Location', 'best');
    grid on;
    ylim([0 1]);
end
