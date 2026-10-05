function plotErrorSpreadComparison(results, testDataLengths, burstErrorRatios)
    % Create comprehensive plots for error spread comparison
    
    methods = {'S', 'Algebraic', 'Turbo', 'Convolutional'};
    colors = {'b-o', 'r-s', 'g-^', 'm-d'};
    
    figure('Name', 'Error Spread Analysis', 'Position', [100, 100, 1200, 800]);
    
    % Subplot 1: Average Burst Error Spread
    subplot(2, 3, 1);
    hold on;
    for methodIdx = 1:length(methods)
        method = methods{methodIdx};
        spreads = zeros(1, length(testDataLengths));
        
        for dataIdx = 1:length(testDataLengths)
            N = testDataLengths(dataIdx);
            if isfield(results.(sprintf('N%d', N)), method) && ...
               isfield(results.(sprintf('N%d', N)).(method), 'burstErrorSpread')
                metrics = results.(sprintf('N%d', N)).(method);
                spreads(dataIdx) = mean(metrics.burstErrorSpread);
            end
        end
        
        plot(testDataLengths, spreads, colors{methodIdx}, 'LineWidth', 2, 'MarkerSize', 8);
    end
    xlabel('Data Length');
    ylabel('Average Burst Error Spread');
    title('Burst Error Spread vs Data Length');
    legend(methods, 'Location', 'best');
    grid on;
    
    % Subplot 2: Random Error Spread
    subplot(2, 3, 2);
    hold on;
    for methodIdx = 1:length(methods)
        method = methods{methodIdx};
        spreads = zeros(1, length(testDataLengths));
        
        for dataIdx = 1:length(testDataLengths)
            N = testDataLengths(dataIdx);
            if isfield(results.(sprintf('N%d', N)), method) && ...
               isfield(results.(sprintf('N%d', N)).(method), 'randomErrorSpread')
                metrics = results.(sprintf('N%d', N)).(method);
                spreads(dataIdx) = metrics.randomErrorSpread;
            end
        end
        
        plot(testDataLengths, spreads, colors{methodIdx}, 'LineWidth', 2, 'MarkerSize', 8);
    end
    xlabel('Data Length');
    ylabel('Random Error Spread');
    title('Random Error Spread vs Data Length');
    legend(methods, 'Location', 'best');
    grid on;
    
    % Subplot 3: Spread Consistency
    subplot(2, 3, 3);
    hold on;
    for methodIdx = 1:length(methods)
        method = methods{methodIdx};
        consistency = zeros(1, length(testDataLengths));
        
        for dataIdx = 1:length(testDataLengths)
            N = testDataLengths(dataIdx);
            if isfield(results.(sprintf('N%d', N)), method) && ...
               isfield(results.(sprintf('N%d', N)).(method), 'burstErrorSpread')
                metrics = results.(sprintf('N%d', N)).(method);
                consistency(dataIdx) = std(metrics.burstErrorSpread);
            end
        end
        
        plot(testDataLengths, consistency, colors{methodIdx}, 'LineWidth', 2, 'MarkerSize', 8);
    end
    xlabel('Data Length');
    ylabel('Spread Consistency (std dev)');
    title('Error Spread Consistency');
    legend(methods, 'Location', 'best');
    grid on;
    
    sgtitle('Error Spread Analysis Comparison');
end
