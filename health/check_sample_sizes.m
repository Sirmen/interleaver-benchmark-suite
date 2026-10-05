%% ========================================================================
%  CHECK 1: SAMPLE SIZES (Adequacy and Balance)
%  ========================================================================
function check = check_sample_sizes(resultsTable, params, opts)
    
    fprintf('CHECK 1: Sample Sizes\n');
    fprintf('─────────────────────────────────────────────────────────────\n');
    
    methods = params.intMethods;
    nM = length(methods);
    
    % Sample size per method (preallocate table)
    check.perMethod = table('Size', [nM, 2], ...
        'VariableTypes', {'cell', 'double'}, ...
        'VariableNames', {'method', 'N'});
    
    for i = 1:nM
        m = methods{i};
        idx = strcmp(resultsTable.method, m);
        check.perMethod.method{i} = m;
        check.perMethod.N(i) = sum(idx);
    end
    
    % Balance metrics
    check.total = height(resultsTable);
    check.min = min(check.perMethod.N);
    check.max = max(check.perMethod.N);
    check.mean = mean(check.perMethod.N);
    check.std = std(check.perMethod.N);
    check.cv = check.std / check.mean;
    check.imbalance = check.max - check.min;
    check.imbalancePercent = 100 * check.imbalance / check.mean;
    
    % Adequacy for ANOVA (rule of thumb: n ≥ 30 per group, preferably ≥ 50)
    check.adequate_basic = check.min >= 30;
    check.adequate_good = check.min >= 50;
    check.adequate_excellent = check.min >= 100;
    
    % Balance quality
    check.balanced = check.cv < opts.balanceTol;
    check.perfectBalance = check.imbalance <= 1; % For controlled sampling
    
    % Pass/Fail
    check.PASS = check.adequate_good && check.balanced;
    
    % Report
    if opts.verbose
        fprintf('  Total samples: %d\n', check.total);
        fprintf('  Samples per method: min=%d, max=%d, mean=%.1f\n', ...
                check.min, check.max, check.mean);
        fprintf('  Imbalance: %d samples (%.1f%%)\n', check.imbalance, check.imbalancePercent);
        fprintf('  CV: %.4f (threshold: %.2f)\n', check.cv, opts.balanceTol);
        fprintf('  Adequacy: ');
        if check.adequate_excellent
            fprintf('EXCELLENT (n≥100)\n');
        elseif check.adequate_good
            fprintf('GOOD (n≥50)\n');
        elseif check.adequate_basic
            fprintf('BASIC (n≥30)\n');
        else
            fprintf('INSUFFICIENT (n<30)\n');
        end
        fprintf('  Balance: %s\n', string(check.balanced));
        fprintf(' -->  OVERALL: %s\n', string(check.PASS));
        if ~check.PASS
            fprintf('  ⚠ WARNING: Sample size issues detected!\n');
        end
        fprintf('\n');
    end
    
    % Visualization
    if opts.plotResults
        fig = figure('Name', 'HA Sample Sizes');
        
        subplot(1,2,1);
        bar(check.perMethod.N, 'FaceColor', [0.3 0.7 0.9]);
        hold on;
        yline(30, 'r--', 'Min (30)                   ', 'LineWidth', 2, 'FontSize', 11);
        yline(50, 'g--', 'Good (50)', 'LineWidth', 2, 'FontSize', 11);
        set(gca, 'XTickLabel', check.perMethod.method);
        set(gca, 'XTick', 1:nM, 'XTickLabel', check.perMethod.method); % Force all ticks
        xtickangle(45);
        set(gca, 'TickLabelInterpreter', 'none'); % Prevents underscores from creating subscripts
        ylabel('Sample Size', 'FontSize', 11);
        title('Sample Size per Method', 'FontSize', 11, 'FontWeight', 'bold');
        grid on;

        subplot(1,2,2);
        expected = mean(check.perMethod.N);
        deviation = check.perMethod.N - expected;
        barh(deviation);
        hold on;
        xline(0, 'k-', 'LineWidth', 2);
        set(gca, 'YTickLabel', check.perMethod.method);
        xlabel('Deviation from Mean', 'FontSize', 12);
        title('Sample Balance Deviation', 'FontSize', 11, 'FontWeight', 'bold');
        grid on;
        
        sgtitle(sprintf('CHECK 1: Sample Sizes [%s]', string(check.PASS)), ...
                'FontSize', 12, 'FontWeight', 'bold');
        
        if opts.saveResults
            saveas(fig, fullfile(opts.figPath, 'check1_sample_sizes.png'));
        end
    end
end
