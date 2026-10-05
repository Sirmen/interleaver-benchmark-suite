function plotGiniAnalysis(stats_all, methods)
% Gini coefficient analysis for distribution inequality
    
    figure('Name', 'Gini Coefficient Analysis'); % , 'Position', [100 100 1200 500]);
    
    % Extract data
    before_gini = extractMetricData(stats_all, methods, 'before_gini');
    after_gini = extractMetricData(stats_all, methods, 'after_gini');
    gini_improvement = extractMetricData(stats_all, methods, 'delta_G');
    
    % Subplot 1: Before vs After
    subplot(1, 2, 1);
    x = 1:length(methods);
    bar(x - 0.2, before_gini, 0.4, 'FaceColor', [0.8 0.4 0.4], 'DisplayName', 'Before');
    hold on;
    bar(x + 0.2, after_gini, 0.4, 'FaceColor', [0.3 0.6 0.9], 'DisplayName', 'After');
    set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 45);
    ylabel('Gini Coefficient');
    title('Distribution Inequality');
    legend('Location', 'best');
    grid on;
    ylim([0 1]);
    
    % Subplot 2: Improvement
    subplot(1, 2, 2);
    bar(gini_improvement, 'FaceColor', [0.4 0.8 0.4]);
    set(gca, 'XTick', x, 'XTickLabel', methods, 'XTickLabelRotation', 45);
    % set(gca, 'XTickLabel', methods, 'XTickLabelRotation', 45);
    ylabel('Gini Improvement');
    title('Inequality Reduction');
    grid on;
    % yline(0, 'r--', 'No Change');
    % 
    % % Subplot 3: Scatter plot
    % subplot(1, 3, 3);
    % scatter(before_gini, after_gini, 100, 'filled', 'MarkerFaceAlpha', 0.6);
    % hold on;
    % plot([0 1], [0 1], 'r--', 'LineWidth', 1.5, 'DisplayName', 'No Change');
    % xlabel('Before Interleaving');
    % ylabel('After Interleaving');
    % title('Gini Coefficient Transformation');
    % legend('Location', 'best');
    % grid on;
    % axis equal;
    % xlim([0 1]); ylim([0 1]);
    % 
    % for i = 1:length(methods)
    %     text(before_gini(i), after_gini(i), ['  ' methods{i}], 'FontSize', 8);
    % end
    
    sgtitle('Error Distribution Inequality (Gini Coefficient)', ...
        'FontSize', 14, 'FontWeight', 'bold');
end