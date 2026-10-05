function plotComparisonResults(results, testDataLengths, burstErrorRatios)
    % Plot comparison results
    fieldNames = {'S', 'Algebraic', 'Turbo', 'Convolutional'};
    colors = {'b-o', 'r-s', 'g-^', 'm-d'};
    
    % Plot 1: Burst Error Correction vs Data Length
    figure('Name', 'Burst Error Correction Performance');
    for burstIdx = 1:length(burstErrorRatios)
        subplot(2, 2, burstIdx);
        hold on;
        
        for i = 1:length(fieldNames)
            name = fieldNames{i};
            values = zeros(1, length(testDataLengths));
            for dataIdx = 1:length(testDataLengths)
                N = testDataLengths(dataIdx);
                values(dataIdx) = results.(sprintf('N%d', N)).(name).burstErrorCorrection(burstIdx);
            end
            plot(testDataLengths, values, colors{i}, 'LineWidth', 2, 'DisplayName', name);
        end
        
        xlabel('Data Length');
        ylabel('Burst Error Correction Rate');
        title(sprintf('Burst Ratio: %d%%', burstErrorRatios(burstIdx)));
        legend('show');
        grid on;
    end
    
    % Plot 2: Random Error Correction vs Data Length
    figure('Name', 'Random Error Correction Performance');
    hold on;
    
    for i = 1:length(fieldNames)
        name = fieldNames{i};
        values = zeros(1, length(testDataLengths));
        for dataIdx = 1:length(testDataLengths)
            N = testDataLengths(dataIdx);
            values(dataIdx) = results.(sprintf('N%d', N)).(name).randomErrorCorrection;
        end
        plot(testDataLengths, values, colors{i}, 'LineWidth', 2, 'DisplayName', name);
    end
    
    xlabel('Data Length');
    ylabel('Random Error Correction Rate');
    title('Random Error Correction Performance');
    legend('show');
    grid on;
    
    % Plot 3: Computational Complexity vs Data Length
    figure('Name', 'Computational Complexity');
    hold on;
    
    for i = 1:length(fieldNames)
        name = fieldNames{i};
        values = zeros(1, length(testDataLengths));
        for dataIdx = 1:length(testDataLengths)
            N = testDataLengths(dataIdx);
            values(dataIdx) = results.(sprintf('N%d', N)).(name).complexity;
        end
        semilogy(testDataLengths, values, colors{i}, 'LineWidth', 2, 'DisplayName', name);
    end
    
    xlabel('Data Length');
    ylabel('Computation Time (seconds)');
    title('Computational Complexity Comparison');
    legend('show');
    grid on;
end
