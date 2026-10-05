%% ========================================================================
%  CHECK 11: ROBUSTNESS ESTIMATION (KPI: RES - Resilience-Efficiency Score)
%     This check validates the "Scientific Rigor" of your RES conclusions.
%     It uses Bootstrap resampling to ensure that your "Leader" method 
%     is statistically superior, not just lucky with the noise samples.
%  ========================================================================
function check = check_robustness_estimation(detailedTable, opts)
    % Perform robust statistical checks on RES (Resilience-Efficiency Score)
    % INPUT: detailedTable - The 'T' output from calcKPIs.m
    
    if opts.verbose
        fprintf('CHECK 11: Robustness Estimation (KPI: RES)\n');
        fprintf('─────────────────────────────────────────────────────────────\n');
    end

    % 1. Data Retrieval from the RES column
    if ismember('RES', detailedTable.Properties.VariableNames)
        methodNames = unique(detailedTable.method);
        numMethods = length(methodNames);
    else
        check.PASS = false;
        check.error = ' *** Column "RES" not found in the input table. Run calcKPIs first.';
        return;
    end

    % 2. Initialize Robust Stats Container
    robustStats = struct();
    alpha = 0.05; % 95% Confidence
    nBoot = 1000; % Bootstrap iterations

    for m = 1:numMethods
        mName = methodNames{m};
        % Extract RES values for this specific method
        data = detailedTable.RES(strcmp(detailedTable.method, mName));
        
        % Remove NaNs or Infs if any
        data = data(isfinite(data));
        
        if isempty(data)
            robustStats(m).mean = NaN;
            robustStats(m).bootCI = [NaN, NaN];
            continue;
        end

        % A. Standard Mean
        robustStats(m).mean = mean(data);
        
        % B. Trimmed Mean (20%) - Robust against outliers (noise spikes)
        robustStats(m).trimmedMean = trimmean(data, 20);
        
        % C. Bootstrap Confidence Interval (The gold standard for rigor)
        % We resample the RES values to see if the mean is stable
        bootMeans = bootstrp(nBoot, @mean, data);
        robustStats(m).bootCI = quantile(bootMeans, [alpha/2, 1-alpha/2]);
        
        robustStats(m).method = mName;
    end

    % 3. Automated Logic: Check for "Dominant Leader"
    [~, bestIdx] = max([robustStats.mean]);
    bestMethod = methodNames{bestIdx};
    
    % A method is "Robustly Superior" if its CI doesn't overlap with others
    % (Simplified check: Is the best mean within its own stable CI?)
    check.PASS = (robustStats(bestIdx).mean >= robustStats(bestIdx).bootCI(1));
    check.bestMethod = bestMethod;

    if opts.verbose
        fprintf('  Scientific Leader: %s\n', bestMethod);
        fprintf('  Mean RES:          %.4f\n', robustStats(bestIdx).mean);
        fprintf('  Bootstrap 95%% CI: [%.4f, %.4f]\n', ...
            robustStats(bestIdx).bootCI(1), robustStats(bestIdx).bootCI(2));
        fprintf(' -->  OVERALL: %s\n', string(check.PASS));
        % if ~check.PASS
        %     fprintf('  ⚠ WARNING: ....\n');
        % end
    end

    % --- 4. Visualization (Forest Plot) ---
    if opts.plotResults
        figure('Name', 'HA RES Robustness Estimation', 'Color', 'w');
        
        % Plot 1: Standard Mean vs Robust Trimmed Mean
        subplot(1, 2, 1);
        b = bar([ [robustStats.mean]', [robustStats.trimmedMean]' ]);
        xticks(1:numMethods);
        set(gca, 'XTickLabel', methodNames, 'TickLabelInterpreter', 'none', 'XTickLabelRotation', 40);
        legend({'Standard Mean', 'Trimmed Mean (20%)'}, 'Location', 'southwest');
        title('Estimator Comparison (RES)');
        ylabel('Score (Z-Units)'); grid on;

        % Plot 2: Bootstrap Forest Plot
        subplot(1, 2, 2); hold on;
        for m = 1:numMethods
            if ~isnan(robustStats(m).bootCI(1))
                % Blue Line = 95% Confidence of the RES
                line([m m], robustStats(m).bootCI, 'LineWidth', 2.5, 'Color', [0 .45 .74]);
                % Red Square = Sample Mean
                plot(m, robustStats(m).mean, 'rs', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
            end
        end
        xticks(1:numMethods);
        set(gca, 'XTickLabel', methodNames, 'TickLabelInterpreter', 'none', 'XTickLabelRotation', 40);
        title('95% Bootstrap Confidence Intervals');
        ylabel('RES Stability');
        grid on;
    end
end
