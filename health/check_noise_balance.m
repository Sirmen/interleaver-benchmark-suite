function check = check_noise_balance(resultsTable, config, opts)
    fprintf('CHECK 2: Noise Level Balance & Fairness\n');
    fprintf('─────────────────────────────────────────────────────────────\n');
    
    methods = unique(resultsTable.method);
    nMethods = length(methods);
    noiseBins = unique(resultsTable.noiseBin);
    nBins = length(noiseBins);

    % 1. Execution Balance (The "Design" check)
    binCounts = groupsummary(resultsTable, 'noiseBin').GroupCount;
    check.designCV = std(binCounts) / mean(binCounts);

    % 2. Fairness Analysis (The "Honest" part)
    % since different methods have different mean noises in the SAME bin
    stats = groupsummary(resultsTable, {'noiseBin', 'method'}, 'mean', 'noiseActual');
    
    % Calculate the "Method Bias": Max difference between methods in the same bin
    maxBiasPerBin = zeros(nBins, 1);
    for i = 1:nBins
        binData = stats.mean_noiseActual(stats.noiseBin == i);
        maxBiasPerBin(i) = (max(binData) - min(binData)) / (mean(binData) + eps);
    end
    check.avgMethodBias = mean(maxBiasPerBin);
    
    % 3. Unique Levels Report
    uniquePerMethod = zeros(nMethods, 1);
    for i = 1:nMethods
        uniquePerMethod(i) = length(unique(resultsTable.noiseActual(strcmp(resultsTable.method, methods{i}))));
    end

    % Reporting
    fprintf('  Design Balance (CV): %.4f (Execution is %s)\n', ...
        check.designCV, interpPass(check.designCV < 0.01));
    fprintf('  Treatment Bias:      %.2f%% (Fairness/Expansion error)\n', check.avgMethodBias * 100);
    fprintf('  Unique Noise levels: %d total\n', length(unique(resultsTable.noiseActual)));
    
    % Detail Table
    fprintf('  Method Bias Breakdown:\n');
    fprintf('  %-20s | %-15s | %-10s\n', 'Method', 'Avg Actual Noise', 'Unique Levels');
    fprintf('  %s\n', repmat('-', 1, 52));
    methodSummary = groupsummary(resultsTable, 'method', 'mean', 'noiseActual');
    for i = 1:nMethods
        fprintf('  %-20s | %-15.4f | %-10d\n', ...
            string(methodSummary.method(i)), methodSummary.mean_noiseActual(i), uniquePerMethod(i));
    end

    check.PASS = (check.designCV < opts.balanceTol) && (check.avgMethodBias < 0.05);
    fprintf(' -->  OVERALL HONESTY: %s\n', string(check.PASS));

    %% 4. Visualization: Seeing the Jitter
    if opts.plotResults
        figure('Name', 'CHECK 2: HA Noise Fairness & Jitter');
        
        % Scatter plot with method colors
        hold on;
        colors = lines(nMethods);
        for i = 1:nMethods
            mIdx = strcmp(resultsTable.method, methods{i});
            % Add small X-jitter to see overlapping points
            xJitter = resultsTable.noiseBin(mIdx) + (rand(sum(mIdx),1)-0.5)*0.3;
            scatter(xJitter, resultsTable.noiseActual(mIdx), 12, colors(i,:), 'filled', ...
                'MarkerFaceAlpha', 0.4, 'DisplayName', char(methods{i}));
        end
        
        % Add target lines
        hs = [];
        for val = config.noiseLevels
            h = yline(val, 'k--', 'Target', 'Alpha', 0.3);
            hs = [hs h];
        end
        set(hs, 'HandleVisibility', 'off');
        
        xlabel('Intended Noise Bin');
        ylabel('Actual Noise Density (Errors/Length)');
        title('Noise "Jitter" by Method (Length Expansion Effect)');
        grid on;
        % Put legend outside because there are 20 methods
        legend('Location', 'eastoutside', 'FontSize', 8);
    end
end

function str = interpPass(val)
    if val; str = 'PERFECT'; else; str = 'IMBALANCED'; end
end
