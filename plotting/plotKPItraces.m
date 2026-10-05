function plotKPItraces(KPItableDetailed, KPItableSummary, config, methods)
% plotKPITraces - Visualizes KPI metric traces across Ns
%
% Creates subplots showing how CR, BE, effectiveness, and RES vary
% with N for each interleaving method
%
% INPUT:
%   KPIdetailedTable  - Detailed KPI results from calcKPIs
%   KPIsummaryTable   - Aggregated KPI summary from calcKPIs
%   config            - Configuration struct
%
% Creates 4 separate figures:
%   1. CR (Adjusted Contribution Ratio) traces
%   2. BE (Bandwidth Efficiency) traces
%   3. effectiveness (CR × BE) traces
%   4. RES (Resilience-Efficiency Score) traces

    %% Setup
    nMethods = length(methods);
    
    % Get unique Ns
    if isfield(config, 'N_values')
        N_values = config.N_values;
    else
        % Extract from encodedLen
        N_values = unique(KPItableDetailed.encodedLen);
    end
    nLengths = length(N_values);
    
    % Colors for consistent visualization
    colors = lines(nMethods);
    
    %% Organize data by method and N
    % Pre-allocate matrices: [nMethods × nLengths]
    CR_traces = nan(nMethods, nLengths);
    BE_traces = nan(nMethods, nLengths);
    effectiveness_traces = nan(nMethods, nLengths);
    RES_traces = nan(nMethods, nLengths);
    
    for m = 1:nMethods
        methodName = methods{m};
        
        for n = 1:nLengths
            N = N_values(n);
            
            % Find all runs for this method and N
            idx = strcmp(KPItableDetailed.method, methodName) & ...
                  KPItableDetailed.encodedLen == N;
            
            if any(idx)
                % Average across noise levels and runs
                CR_traces(m, n) = mean(KPItableDetailed.CR(idx), 'omitnan');
                BE_traces(m, n) = mean(KPItableDetailed.BE(idx), 'omitnan');
                effectiveness_traces(m, n) = mean(KPItableDetailed.effectiveness(idx), 'omitnan');
                RES_traces(m, n) = mean(KPItableDetailed.RES(idx), 'omitnan');
            end
        end
    end
    
    %% Figure 1: CR (Adjusted Contribution Ratio) Traces
    fig1 = figure('Name', 'CR Traces by N', 'Color', 'w');
    
    for m = 1:nMethods
        methodName = methods{m};
        
        % Get overall mean from summary for title
        sumRow = strcmp(KPItableSummary.method, methodName);
        avgCR = KPItableSummary.CR(sumRow);
        
        subplot(ceil(nMethods/2), 2, m);
        plot(N_values, CR_traces(m, :), 'LineWidth', 1, 'Color', colors(m, :));
        grid on;
        xlabel('N');
        ylabel('CR');
        title(sprintf('%s (Avg CR: %.4f)', methodName, avgCR), ...
              'FontSize', 11, 'FontWeight', 'bold');
        
        % Dynamic y-limits
        ydata = CR_traces(m, :);
        ydata = ydata(~isnan(ydata));
        if ~isempty(ydata)
            ylim([min(ydata)*0.95, max(ydata)*1.05]);
        end
    end
    
    sgtitle('CR vs N', 'FontSize', 12, 'FontWeight', 'bold');
    
    %% Figure 2: BE (Bandwidth Efficiency) Traces
    fig2 = figure('Name', 'Bandwidth Efficiency Traces', 'Color', 'w');
    
    for m = 1:nMethods
        methodName = methods{m};
        
        sumRow = strcmp(KPItableSummary.method, methodName);
        avgBE = KPItableSummary.BE(sumRow);
        
        subplot(ceil(nMethods/2), 2, m);
        plot(N_values, BE_traces(m, :), 'LineWidth', 1, 'Color', colors(m, :));
        grid on;
        xlabel('N');
        ylabel('BE');
        title(sprintf('%s (Avg BE: %.4f)', methodName, avgBE), ...
              'FontSize', 11, 'FontWeight', 'bold');
        
        ydata = BE_traces(m, :);
        ydata = ydata(~isnan(ydata));
        if ~isempty(ydata)
            ylim([min(ydata)*0.95, max(ydata)*1.05]);
        end
    end
    
    sgtitle('Bandwidth Efficiency vs N', 'FontSize', 12, 'FontWeight', 'bold');
    
    %% Figure 3: effectiveness Traces
    fig3 = figure('Name', 'effectiveness Traces', 'Color', 'w');
    
    for m = 1:nMethods
        methodName = methods{m};
        
        sumRow = strcmp(KPItableSummary.method, methodName);
        avgEff = KPItableSummary.effectiveness(sumRow);
        
        subplot(ceil(nMethods/2), 2, m);
        plot(N_values, effectiveness_traces(m, :), 'LineWidth', 1, 'Color', colors(m, :));
        grid on;
        xlabel('N');
        ylabel('E');
        title(sprintf('%s (Avg Eff: %.4f)', methodName, avgEff), ...
              'FontSize', 11, 'FontWeight', 'bold');
        
        ydata = effectiveness_traces(m, :);
        ydata = ydata(~isnan(ydata));
        if ~isempty(ydata)
            ylim([min(ydata)*0.95, max(ydata)*1.05]);
        end
    end
    
    sgtitle('Effectiveness (CR × BE) vs N', 'FontSize', 12, 'FontWeight', 'bold');
    
    %% Figure 4: RES (Resilience-Efficiency Score) Traces
    fig4 = figure('Name', 'RES Traces', 'Color', 'w');
    
    for m = 1:nMethods
        methodName = methods{m};
        
        sumRow = strcmp(KPItableSummary.method, methodName);
        avgRES = KPItableSummary.RES(sumRow);
        
        subplot(ceil(nMethods/2), 2, m);
        plot(N_values, RES_traces(m, :), 'LineWidth', 1,'Color', colors(m, :));
        grid on;
        xlabel('N');
        ylabel('RES_{Z}');
        title(sprintf('%s (Avg RES: %.3f)', methodName, avgRES), ...
              'FontSize', 11, 'FontWeight', 'bold');
        
        % Add zero reference line for RES (Z-score)
        yline(0, 'k--', 'LineWidth', 1, 'Alpha', 0.5);
        
        ydata = RES_traces(m, :);
        ydata = ydata(~isnan(ydata));
        if ~isempty(ydata)
            y_margin = max(abs(ydata)) * 0.1;
            ylim([min(ydata) - y_margin, max(ydata) + y_margin]);
        end
    end
    
    sgtitle('Resilience-Efficiency Score (RES) vs N', 'FontSize', 12, 'FontWeight', 'bold');
    
    %% Save figures if configured
%% ===== Save Figures
   if config.saveResults
      sMsg = savePlot(fig1, config.dataSavePath);  fprintf('%s \n',sMsg);
      sMsg = savePlot(fig2, config.dataSavePath);  fprintf('%s \n',sMsg);
      sMsg = savePlot(fig3, config.dataSavePath);  fprintf('%s \n',sMsg);
      sMsg = savePlot(fig4, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
end
