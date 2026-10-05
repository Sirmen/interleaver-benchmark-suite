%% ========================================================================
%  CHECK 10: DATA COMPLETENESS
%  ========================================================================
function check = check_data_completeness(results, config, opts)
    
    fprintf('CHECK 10: Data Completeness\n');
    fprintf('─────────────────────────────────────────────────────────────\n');
    
    % Expected vs actual
    expectedN = length(config.sizeMin:config.sizeMax);
    
    % Use testedSizes if testedSizes doesn't exist (for run_simulations_sci compatibility)
    if isfield(results, 'testedSizes') && ~isempty(results.testedSizes)
        testedSizes = unique(results.testedSizes);
    else
        testedSizes = [];
    end
    
    % Get skipped Ns
    if isfield(results, 'skippedSizes') && ~isempty(results.skippedSizes)
        skippedSizes = results.skippedSizes;
    else
        skippedSizes = [];
    end
    
    actualN = length(testedSizes);
    skippedN = length(skippedSizes);
    
    check.expected = expectedN;
    check.actual = actualN;
    check.skipped = skippedN;
    check.completionRate = 100 * actualN / expectedN;
    check.complete = actualN == expectedN;
    check.highCompletion = check.completionRate >= 90;
    
    % Check if skipped Ns are random or systematic
    if skippedN > 0
        check.skippedSizes = skippedSizes;
        check.testedSizes = testedSizes;
        
        % Are skipped Ns clustered?
        if skippedN > 1
            skippedDiffs = diff(sort(skippedSizes));
            check.clustered = any(skippedDiffs == 1);
        else
            check.clustered = false;
        end
    end
    
    % Pass/Fail
    check.PASS = check.highCompletion;
    
    % Report
    if opts.verbose
        fprintf('  Expected block sizes: %d\n', expectedN);
        fprintf('  Valid block sizes: %d\n', actualN);
        fprintf('  Skipped block sizes: %d\n', skippedN);
        fprintf('  Completion rate: %.1f%%\n', check.completionRate);
        if actualN > 0
            fprintf('  Valid N range: [%d, %d]\n', min(testedSizes), max(testedSizes));
        end
        if skippedN > 0
            fprintf('*  Skipped Ns: %s\n', mat2str(skippedSizes));
            if check.clustered
                fprintf('**  Pattern: CLUSTERED (may indicate systematic issue)\n');
            else
                fprintf('  Pattern: RANDOM\n');
            end
        end
        fprintf(' -->  OVERALL: %s\n', string(check.PASS));
        if ~check.PASS
            fprintf('  ⚠ WARNING: Low completion rate!\n');
        end
        fprintf('\n');
    end
    
    % Visualization
    if opts.plotResults
        fig = figure('Name', 'HA Data Completeness');
        
        t = tiledlayout(1,1);
        nexttile;       

        allN = config.sizeMin:config.sizeMax;
        completed = ismember(allN, testedSizes);
        
        bar(allN, completed);
        xlabel('Block Size (N)', 'FontSize', 11);
        ylabel('Completed (1=Yes, 0=No)', 'FontSize', 11);
        title(sprintf('Data Completeness (%.1f%%)', check.completionRate), ...
              'FontSize', 11, 'FontWeight', 'bold');
        ylim([0 1.2]);
        grid on;
        
        title(t, sprintf('CHECK 10: Completeness [%s]', string(check.PASS)), ...
                      'FontSize', 11, 'FontWeight', 'bold');
        if opts.saveResults
            saveas(fig, fullfile(opts.figPath, 'check10_completeness.png'));
        end
    end
end
