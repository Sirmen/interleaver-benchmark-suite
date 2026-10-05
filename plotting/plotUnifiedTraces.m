function plotUnifiedTraces(results, methods)
    % This assumes results.stats_all is a struct array of all trials
    % We group trials by method and plot the sequence
    
    metrics = {'S_ECC', 'S_ECC_norm', 'eta_ES', 'CR'};
    figure('Name', 'Metric Performance Traces (Trial-by-Trial)', 'Color', 'w');
    t = tiledlayout(4, 1, 'TileSpacing', 'none');
    
    for i = 1:length(metrics)
        nexttile;
        hold on;
        for m = 1:length(methods)
            method = methods{m};
            % Extract the full trace for this specific method
            methodStats = results.stats_all(strcmp({results.stats_all.method}, method));
            traceData = [methodStats.(metrics{i})];
            
            plot(traceData, 'LineWidth', 1.2, 'DisplayName', method);
        end
        ylabel(metrics{i});
        grid on;
        if i == 1, legend('Location', 'eastoutside'); end
    end
    xlabel('Simulation Trial Index');
end