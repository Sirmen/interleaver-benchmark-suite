function plotKPIScatterMatrix(KPItableDetailed, config)
% plotKPIScatterMatrix - Pairwise scatter plots of KPI metrics

    % Extract KPI data
    CR = KPItableDetailed.CR;
    BE = KPItableDetailed.BE;
    Eff = KPItableDetailed.effectiveness;
    RES = KPItableDetailed.RES;
    
    % Create matrix
    data = [CR, BE, Eff, RES];
    varNames = {'CR', 'BE', 'Effectiveness', 'RES'};
    
    fig = figure('Name', 'KPI Scatter Matrix', 'Color', 'w');
    
    [~, ax] = plotmatrix(data);
    
    % Set axis labels
    for i = 1:4
        ylabel(ax(i, 1), varNames{i}, 'FontWeight', 'bold');
        xlabel(ax(4, i), varNames{i}, 'FontWeight', 'bold');
    end
    
    sgtitle('KPI Metric Correlations', 'FontSize', 15, 'FontWeight', 'bold');
    
    %% Save
    if isfield(config, 'saveResults') && config.saveResults && ...
       isfield(config, 'dataSavePath')
        [saveDir, ~, ~] = fileparts(config.dataSavePath);
        saveas(fig, fullfile(saveDir, 'KPI_scatter_matrix.png'));
        fprintf('KPI scatter matrix saved\n');
    end
end
