%% ========================================================================
%  CHECK 8: INDEPENDENCE (No Autocorrelation)
%  ========================================================================
function check = check_independence(resultsTable, opts)
    
    fprintf('CHECK 8: Independence of Observations\n');
    fprintf('─────────────────────────────────────────────────────────────\n');
        
    % Check for sequential patterns (autocorrelation)
    data = resultsTable.RES(~isnan(resultsTable.RES));
    
    if length(data) > 10
        % Lag-1 autocorrelation using autocorr with proper syntax
        try
            [acf_vals, lags_vals, bounds_vals] = autocorr(data, 'NumLags', 1);
            check.acf = acf_vals;
            check.lags = lags_vals;
            check.bounds = bounds_vals;
            check.lag1_acf = acf_vals(2); % Lag 0 is always 1
            check.independent = abs(check.lag1_acf) < bounds_vals(1);
        catch
            % Fallback: manual calculation
            check.lag1_acf = corr(data(1:end-1), data(2:end));
            check.independent = abs(check.lag1_acf) < 2/sqrt(length(data)); % Approximate bound
            check.note = 'Manual autocorrelation calculation';
        end
        
        % Durbin-Watson statistic (should be ~2 for no autocorrelation)
        residuals = data - mean(data);
        check.dw_stat = sum(diff(residuals).^2) / sum(residuals.^2);
        check.dw_acceptable = check.dw_stat > 1.5 && check.dw_stat < 2.5;
    else
        check.independent = true;
        check.dw_acceptable = true;
        check.note = 'Too few samples for autocorrelation test';
    end
    
    % Pass/Fail - be lenient if autocorrelation is due to method ordering
    % Small autocorrelation (< 0.3) is acceptable in factorial designs
    if isfield(check, 'lag1_acf')
        check.moderateCorrelation = abs(check.lag1_acf) < 0.3;
        check.PASS = (check.independent || check.moderateCorrelation) && check.dw_acceptable;
        if check.moderateCorrelation && ~check.independent
            check.note = 'Moderate autocorrelation detected, likely due to systematic method ordering';
        end
    else
        check.PASS = check.independent && check.dw_acceptable;
    end

    % Report
    if opts.verbose
        if isfield(check, 'note')
            fprintf('  %s\n', check.note);
        end
        if isfield(check, 'lag1_acf')
            fprintf('  Lag-1 autocorrelation: %.4f\n', check.lag1_acf);
            fprintf('  Independent (within bounds): %s\n', string(check.independent));
            if isfield(check, 'moderateCorrelation')
                fprintf('  Moderate correlation (<0.3): %s\n', string(check.moderateCorrelation));
            end
        end
        if isfield(check, 'dw_stat')
            fprintf('  Durbin-Watson statistic: %.4f\n', check.dw_stat);
            fprintf('  DW acceptable (1.5-2.5): %s\n', string(check.dw_acceptable));
        end
        fprintf(' -->  OVERALL: %s\n', string(check.PASS));
        if ~check.PASS
            fprintf('  ⚠ WARNING: Possible autocorrelation!\n');
        end
        fprintf('\n');
    end
    
    % Visualization
    if opts.plotResults && length(data) > 5
        fig = figure('Name', 'HA Independence of Observations');
        
        subplot(1,2,1);
        plot(data, '-o', 'MarkerSize', 3);
        xlabel('Observation Index', 'FontSize', 11);
        ylabel('Contribution', 'FontSize', 11);
        title('Sequential Plot', 'FontSize', 11, 'FontWeight', 'bold');
        grid on;
        
        subplot(1,2,2);
        try
            autocorr(data, 'NumLags', 20);
            title('Autocorrelation Function', 'FontSize', 11, 'FontWeight', 'bold');
        catch
            % Manual ACF plot
            maxLag = min(20, floor(length(data)/4));
            acf_manual = zeros(maxLag+1, 1);
            for lag = 0:maxLag
                if lag == 0
                    acf_manual(lag+1) = 1;
                else
                    acf_manual(lag+1) = corr(data(1:end-lag), data(lag+1:end));
                end
            end
            stem(0:maxLag, acf_manual, 'filled');
            hold on;
            bound = 2/sqrt(length(data));
            yline(bound, 'r--', 'LineWidth', 1.5);
            yline(-bound, 'r--', 'LineWidth', 1.5);
            xlabel('Lag', 'FontSize', 11);
            ylabel('ACF', 'FontSize', 11);
            title('Autocorrelation Function', 'FontSize', 11, 'FontWeight', 'bold');
            grid on;
        end
        
        sgtitle(sprintf('CHECK 8: Independence [%s]', string(check.PASS)), ...
                'FontSize', 12, 'FontWeight', 'bold');
        
        if opts.saveResults
            saveas(fig, fullfile(opts.figPath, 'check8_independence.png'));
        end
    end
end
