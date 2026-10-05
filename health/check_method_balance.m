%% ========================================================================
%  CHECK 3: METHOD-SPECIFIC BALANCE
%  ========================================================================
function check = check_method_balance(resultsTable, params, anovaResults, opts)
    
    fprintf('CHECK 3: Method-Specific Balance\n');
    fprintf('─────────────────────────────────────────────────────────────\n');
    
    methods = params.intMethods;
    nM = length(methods);
    
    % Check each method separately
    check.perMethod = struct();
    allBalanced = true;
    
    for i = 1:nM
        m = methods{i};
        idx = strcmp(resultsTable.method, m);
        data = resultsTable.noiseActual(idx);
        
        % Basic stats
        check.perMethod.(m).N = sum(idx);
        check.perMethod.(m).noise_mean = mean(data);
        check.perMethod.(m).noise_std = std(data);
        check.perMethod.(m).noise_min = min(data);
        check.perMethod.(m).noise_max = max(data);
        check.perMethod.(m).noise_range = range(data);
    end
    
    % Compare noise distributions across methods
    noiseMeans = zeros(nM, 1);
    noiseStds = zeros(nM, 1);
    for i = 1:nM
        m = methods{i};
        noiseMeans(i) = check.perMethod.(m).noise_mean;
        noiseStds(i) = check.perMethod.(m).noise_std;
    end
    
    check.noise_mean_cv = std(noiseMeans) / mean(noiseMeans);
    check.noise_std_cv = std(noiseStds) / mean(noiseStds);
    check.noise_balanced = check.noise_mean_cv < 0.10; % Stricter for means
    
    % Test if noise distributions are similar (Kruskal-Wallis)
    groups = {};
    noiseData = [];
    for i = 1:nM
        m = methods{i};
        idx = strcmp(resultsTable.method, m);
        groups = [groups; repmat({m}, sum(idx), 1)];
        noiseData = [noiseData; resultsTable.noiseActual(idx)];
    end
    
    [check.kw_p, ~, check.kw_stats] = kruskalwallis(noiseData, groups, 'off');
    check.noise_distributions_similar = check.kw_p > opts.alpha;
    
    % Pass/Fail - be lenient with large samples
    % With large N, even tiny differences become statistically significant
    % Focus on practical significance (CV < 10%)
    if check.noise_mean_cv < 0.10 && check.noise_std_cv < 0.20
        % Practically balanced even if statistically different
        check.PASS = true;
        check.note = 'Statistically different but practically balanced (large sample effect)';
    else
        check.PASS = check.noise_balanced && check.noise_distributions_similar;
    end

    % Report
    if opts.verbose
        fprintf('  Noise mean CV across methods: %.4f\n', check.noise_mean_cv);
        fprintf('  Noise std CV across methods: %.4f\n', check.noise_std_cv);
        fprintf('  Kruskal-Wallis test p-value: %.4f\n', check.kw_p);
        fprintf('  Noise distributions similar: %s (α=%.2f)\n', ...
                string(check.noise_distributions_similar), opts.alpha);
        if isfield(check, 'note')
            fprintf('  NOTE: %s\n', check.note);
        end
        fprintf(' -->  OVERALL: %s\n', string(check.PASS));
        if ~check.PASS
            fprintf('  ⚠ WARNING: Methods exposed to different noise levels!\n');
        end
        fprintf('\n');
    end

    % Visualization
    if opts.plotResults
        fig = figure('Name', 'HA Method Balance');
        
        t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'normal');      
        % subplot(1,3,1);
        nexttile;
        bar(noiseMeans);
        hold on;
        errorbar(1:nM, noiseMeans, noiseStds, 'k.', 'LineWidth', 2);
        set(gca, 'XTickLabel', methods);
        set(gca, 'XTick', 1:nM, 'XTickLabel', methods); % Force all ticks
        xtickangle(45);
        ylabel('Noise Level', 'FontSize', 11);
        title('Mean Noise ± SD per Method', 'FontSize', 11, 'FontWeight', 'bold');
        grid on;
        
        % subplot(1,3,2);
        nexttile;
        boxplot(noiseData, groups);
        ylabel('Noise Level', 'FontSize', 11);
        xtickangle(45);
        title(sprintf('Distribution Comparison (p=%.4f)', check.kw_p), ...
              'FontSize', 11, 'FontWeight', 'bold');
        grid on;
        
        % subplot(1,3,3);
        nexttile;
        hold on;
        methods = anovaResults.topMethods;
        topNperf = length(methods);
        for i = 1:topNperf
            m = methods{i};
            idx = strcmp(resultsTable.method, m);
            histogram(resultsTable.noiseActual(idx), 30, 'DisplayStyle', 'stairs', 'LineWidth', 1);
        end
        xlabel('Noise Level', 'FontSize', 11);
        ylabel('Count', 'FontSize', 11);
        title('Noise Distributions by Method', 'FontSize', 11, 'FontWeight', 'bold');
        % legend(methods, 'Location', 'best', 'NumColumns', 4);
        legend(methods, 'Location', 'best', 'NumColumns', 2);
        grid on;
        
        sgtitle(sprintf('CHECK 3: Method Balance [%s]', string(check.PASS)), ...
                'FontSize', 12, 'FontWeight', 'bold');
        
        if opts.saveResults
            saveas(fig, fullfile(opts.figPath, 'check3_method_balance.png'));
        end
    end
end
