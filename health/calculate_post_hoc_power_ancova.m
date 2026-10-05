function powerCheck = calculate_post_hoc_power_ancova(detailedTable, opts)
% CHECK 13: POST-HOC POWER ANALYSIS (ANCOVA - KPI: RES)
% Validates the power of the Method effect while controlling for noiseActual.
%
% INPUT:
%   detailedTable - The 'T' table from calcKPIs (must have RES, method, noiseActual)
%   opts          - Visualization and verbosity options

    if opts.verbose
        fprintf('CHECK 13: Post-Hoc Power Analysis (ANCOVA on RES)\n');
        fprintf('─────────────────────────────────────────────────────────────\n');
    end

    % 1. Data Preparation
    y = detailedTable.RES;
    group = detailedTable.method;
    covariate = detailedTable.noiseActual;
    
    % 2. Run ANCOVA (using anovan for flexibility)
    % 'continuous', 2 specifies that noiseActual (the 2nd predictor) is a covariate
    [~, tbl, stats] = anovan(y, {group, covariate}, ...
        'continuous', 2, 'varnames', {'Method', 'noiseActual'}, 'display', 'off');

    % 3. Calculate Partial Eta-Squared (η²p) for the Method
    % formula: SS_method / (SS_method + SS_error)
    ss_method = tbl{2,2};
    ss_error = tbl{4,2};
    etaSqP = ss_method / (ss_method + ss_error);
    
    % 4. Degrees of Freedom
    df_effect = tbl{2,3}; % numGroups - 1
    df_error = tbl{4,3};  % totalN - numGroups - 1 (extra -1 for covariate)
    totalN = height(detailedTable);

    % 5. Power Calculation
    % Cohen's f for ANCOVA
    cohensF = sqrt(etaSqP / (1 - etaSqP));
    alpha = opts.alpha;
    
    % Non-centrality parameter
    lambda = (cohensF^2) * totalN;
    f_crit = finv(1 - alpha, df_effect, df_error);
    achievedPower = 1 - ncfcdf(f_crit, df_effect, df_error, lambda);

    % --- Store Results ---
    powerCheck.etaSqP = etaSqP;
    powerCheck.cohensF = cohensF;
    powerCheck.achievedPower = achievedPower;
    powerCheck.PASS = (achievedPower >= 0.80);

    if opts.verbose
        fprintf('  Adjusted Effect Size (η²p): %.4f\n', etaSqP);
        fprintf('  ANCOVA Cohen''s f:           %.4f\n', cohensF);
        fprintf('  Adjusted Power (1-β):      %.4f\n', achievedPower);
        if powerCheck.PASS
            fprintf('  STATUS: ANCOVA POWER SUFFICIENT\n\n');
        else
            fprintf('  STATUS: ANCOVA POWER LOW\n\n');
        end
    end

    % --- Visualization ---
    if opts.plotResults
        fig = figure('Name', 'ANCOVA_Power_Analysis', 'Color', 'w');
        
        % 1. Extract Adjusted Means AND Names from multcompare
        % Dimension 1 is 'Method'
        % c: comparison matrix
        % m: [mean, stderr]
        % h: figure handle (ignored)
        % n: The actual group names
        [~, m, ~, n] = multcompare(stats, 'Dimension', 1, 'Display', 'off'); 
        
        % 2. Clean names (Remove "Method=" if present)
        cleanMethods = strrep(n, 'Method=', '');
        
        % 3. Extract data for plotting
        % m(:,1) contains the adjusted means
        % m(:,2) contains the standard errors
        adjMeans = m(:,1);
        stdErrors = m(:,2);
        
        % 4. Create Vertical Error Bar Plot (Methods on X-Axis)
        x_indices = 1:numel(cleanMethods);
        eb = errorbar(x_indices, adjMeans, stdErrors, 'o', 'LineWidth', 2, ...
            'MarkerSize', 8, 'MarkerFaceColor', [0 .45 .74], 'Color', [0 .45 .74]);
        
        % 5. Formatting
        grid on;
        set(gca, 'XTick', x_indices, 'XTickLabel', cleanMethods, ...
            'TickLabelInterpreter', 'none', 'XTickLabelRotation', 40);
        
        ylabel('Adjusted RES -for Actual Noise');
        title('Scientific Comparison of Resilience-Efficiency (ANCOVA)');
        
        % Add a horizontal line at 0 (The global average)
        yline(0, 'k--', 'Group Mean', 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
        
        % Adjust Y-limits to give space for labels
        y_range = max(adjMeans + stdErrors) - min(adjMeans - stdErrors);
        ylim([min(adjMeans - stdErrors) - 0.2*y_range, max(adjMeans + stdErrors) + 0.2*y_range]);


        if opts.saveResults
            % Retrieve figure name for automatic saving
            saveVars_YMD(opts.figPath, 'png', fig.Name, fig);
        end
    end
end
