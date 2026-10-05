function [summaryTable] = plotIntEffectiveness(summaryTable, efficiencyData, contributionData, effectivenessData, intMethods)
% Refactored to use summaryTable for efficiency
% summaryTable contains: Method, CR, eta_ER, Effectiveness, DER
    % Creates separate figures for each metric using Table data for titles
    nMethod = length(intMethods);
    methods = cellstr(summaryTable.Method);
    
    % % --- 1. DER Figure ---
    % figure('Name', 'Decoding Success Rate Traces');
    % for m = 1:nMethod
    %     methodName = methods{m};
    %     % Find row in table for this method to get the pre-calculated mean
    %     row = summaryTable(summaryTable.Method == methodName, :);
    % 
    %     subplot(ceil(nMethod/2), 2, m);
    %     plot(1 - inforateData(m,:), 'Color', [0.2 0.6 0.5]); 
    %     grid on;
    %     title(sprintf('%s (Avg Success: %.4f)', methodName, 1 - row.DER), 'FontSize', 10);
    %     ylim([-0.1 1.1]);
    % end

    % --- 2. Contribution (CR) Figure ---
    figure('Name', 'Error-Recovery Contribution Traces');
    for m = 1:nMethod
        methodName = methods{m};
        row = summaryTable(summaryTable.Method == methodName, :);
        
        pDdata = contributionData(m,:);
        subplot(ceil(nMethod/2), 2, m);
        plot(pDdata, 'Color', [0.7 0.3 0.3]); 
        grid on;
        title(sprintf('%s (Avg CR: %.4f)', methodName, row.CR), 'FontSize', 10);
        ylim([min(pDdata)*0.9 max(pDdata)*1.1]);
    end

    % --- 3. Efficiency (eta_ER) Figure ---
    figure('Name', 'Efficiency Traces');
    for m = 1:nMethod
        methodName = methods{m};
        row = summaryTable(summaryTable.Method == methodName, :);
        
        pDdata = efficiencyData(m,:);
        subplot(ceil(nMethod/2), 2, m);
        plot(pDdata, 'Color', [0.3 0.3 0.7]); 
        grid on;
        ylim([min(pDdata)*0.9 max(pDdata)*1.1]);
        title(sprintf('%s (Avg \\eta_E_R: %.4f)', methodName, row.eta_ER), 'FontSize', 10);
    end

    % --- 4. Effectiveness Figure ---
    figure('Name', 'System Effectiveness Traces');
    for m = 1:nMethod
        methodName = methods{m};
        row = summaryTable(summaryTable.Method == methodName, :);
        pDdata = effectivenessData(m,:);
        subplot(ceil(nMethod/2), 2, m);
        plot(pDdata, 'Color', [0.3 0.7 0.3]); 
        grid on;
        title(sprintf('%s (Avg Eff: %.4f)', methodName, row.Effectiveness), 'FontSize', 10);
        ylim([min(pDdata)*0.9 max(pDdata)*1.1]);
    end
end
