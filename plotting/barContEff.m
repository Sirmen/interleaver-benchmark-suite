function barContEff(summaryTable)
    % summaryTable: Table containing Method, CR, eta_ER, Effectiveness, DER
    
    % Configuration
    barWidth = 0.6;
    limMul = 1.25;
    axisFontSize = 10;
    methods = cellstr(summaryTable.Method);
    
    figure('Name', 'Unified Performance Metrics', 'Units', 'normalized'); %, 'Position', [0.1, 0.1, 0.8, 0.8]);
    
    % --- Subplot 1: Decoding Performance ---
    subplot(4,1,1);
    perf = 1 - summaryTable.DER;
    b1 = bar(perf, barWidth, 'FaceColor', [0.7 0.7 0.7]);
    title('Mean Decoding Performance', 'FontSize', axisFontSize + 1);
    ylabel('Performance');
    formatBar(b1, methods, [0 max(summaryTable.DER)*limMul], axisFontSize);

    % --- Subplot 2: Contribution Ratio (CR) ---
    subplot(4,1,2);
    b2 = bar(summaryTable.CR, barWidth, 'FaceColor', [0.8 0.4 0.4]);
    title('Average Contribution (CR)', 'FontSize', axisFontSize + 1);
    ylabel('CR');
    formatBar(b2, methods, [0 max(summaryTable.CR)*limMul], axisFontSize);

    % --- Subplot 3: Efficiency (eta_ER) ---
    subplot(4,1,3);
    b3 = bar(summaryTable.eta_ER, barWidth, 'FaceColor', [0.3 0.4 0.8]);
    title('Average Efficiency (\eta_{ER})', 'FontSize', axisFontSize + 1);
    ylabel('\eta_{ER}');
    formatBar(b3, methods, [0 max(summaryTable.eta_ER)*limMul], axisFontSize);

    % --- Subplot 4: Effectiveness Score ---
    subplot(4,1,4);
    b4 = bar(summaryTable.Effectiveness, barWidth, 'FaceColor', [0.4 0.8 0.3]);
    title('System Effectiveness (CR \times InfoRate)', 'FontSize', axisFontSize + 1);
    ylabel('E');
    formatBar(b4, methods, [0 max(summaryTable.Effectiveness)*limMul], axisFontSize);
end

function formatBar(barObj, xLabels, yLimits, fSize)
    grid on;
    set(gca, 'XTick', 1:length(xLabels), 'XTickLabel', xLabels, 'FontSize', fSize);
    % if yLimits(2) > 0, ylim(yLimits); end
    ylim([0 1]);

    % Add text labels on top of bars
    xtips = barObj.XEndPoints;
    ytips = barObj.YEndPoints;
    labels = compose('%.4f', barObj.YData);
    text(xtips, ytips, labels, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'FontSize', 8, 'FontWeight', 'bold');
end
