function powerCheck = calculate_post_hoc_power(anovaResults, detailedTable, opts)
% CHECK 12: POST-HOC POWER ANALYSIS (KPI: RES)
% Validates if the simulation had enough samples to detect differences in RES.
%
% INPUT:
%   anovaResults  - Results from the ANOVA performed on RES
%   detailedTable - The 'T' table from calcKPIs containing all RES samples
%   opts          - Visualization and verbosity options

    if opts.verbose
        fprintf('\nCHECK 12: Post-Hoc Power Analysis (KPI: RES)\n');
        fprintf('─────────────────────────────────────────────────────────────\n');
    end

    % 1. Extract Partial Eta-Squared (η²) from the RES ANOVA
    % η² measures the proportion of variance in RES explained by the Method.
    % If not found in anovaResults, we use a conservative estimate based on 
    % typical interleaver performance variance.
    etaSq = 0.40; 
    if isstruct(anovaResults) && isfield(anovaResults, 'etaSq')
        etaSq = anovaResults.etaSq; 
    end
    
    % 2. Calculate Cohen's f (The effect size for F-tests)
    % f = sqrt( η² / (1 - η²) )
    cohensF = sqrt(etaSq / (1 - etaSq));
    
    % 3. Calculate Sample Sizes from the actual RES data
    % We use the detailed table to get exact counts per group
    methodList = unique(detailedTable.method);
    numGroups = length(methodList);
    totalN = height(detailedTable);
    nPerMethod = totalN / numGroups;
    
    % 4. Power Calculation 
    % For large-scale Monte Carlo (N > 1000 per method), power usually 
    % approaches 1.0 (limit of detection is very high).
    alpha = 0.05;
    df_effect = numGroups - 1;
    df_error = totalN - numGroups;
    
    % Non-centrality parameter (lambda)
    lambda = (cohensF^2) * totalN;
    
    % F-critical value
    f_crit = finv(1 - alpha, df_effect, df_error);
    
    % Achieved Power
    achievedPower = 1 - ncfcdf(f_crit, df_effect, df_error, lambda);
    
    % 5. Minimum Detectable Effect (MDE) in RES Units (Z-Scores)
    % This tells you the smallest difference in "Standard Deviations" 
    % that your simulation can reliably distinguish.
    % For 80% power at alpha 0.05:
    mde_res = (2.8 * std(detailedTable.RES)) / sqrt(nPerMethod);
    
    % --- Store Results ---
    powerCheck.KPI = 'RES';
    powerCheck.cohensF = cohensF;
    powerCheck.etaSq = etaSq;
    powerCheck.totalN = totalN;
    powerCheck.achievedPower = achievedPower;
    powerCheck.mde_zscore = mde_res;
    powerCheck.PASS = (achievedPower >= 0.80);

    if opts.verbose
        fprintf('  Effect Size (Cohen''s f):  %.4f\n', cohensF);
        fprintf('  Total Observations (N):   %d\n', totalN);
        fprintf('  Achieved Power (1-β):     %.4f\n', achievedPower);
        fprintf('  Min Detectable Δ (RES):   %.4f Z-units\n', mde_res);
        if powerCheck.PASS
            fprintf(' -->  OVERALL: POWER SUFFICIENT (High Confidence in RES Rankings)\n\n');
        else
            fprintf(' -->  OVERALL: POWER LOW (Consider increasing testRunsMax)\n\n');
        end
    end
end
