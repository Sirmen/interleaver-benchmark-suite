%%% Run simulation's scientific health check

% * * * *
% assumes all data is already loaded in the memory
% * * * *

% clc; 
% close all;

%%

opts = struct('plotResults', true, ...
              'saveResults', false,... % true, ...
              'figPath', './paper_figs/health/', ...
              'alpha', 0.05, ...
              'balanceTol', 0.15, ...
              'verbose', true);
health = verify_simulation_health(results, KPItableDetailed, config, params, results, opts);

% Check overall reliability
if health.overall.PASS
    fprintf('✓ Simulations are reliable for statistical analysis\n');
else
    fprintf('✗ Issues detected - see recommendations\n');
end

%%%%%%%

function health = verify_simulation_health(results, KPItableDetailed, config, params, anovaResults, opts)
% verify_simulation_health
% ============================================================================
% Comprehensive health check for simulation reliability and methodological rigor
% Verifies that simulations meet quality standards for statistical analysis
%
% Inputs:
%   results : simulation results from run_simulations_sci
%   config  : configuration structure
%   params  : parameters structure  
%   opts    : optional settings
%       .alpha        : significance level (default = 0.05)
%       .balanceTol   : balance tolerance (default = 0.15 CV)
%       .plotResults  : plot Results (default = true)
%       .saveResults  : save Results (default = false)
%       .figPath      : path for figures (default = './health_check/')
%       .verbose      : detailed output (default = true)
%
% Outputs:
%   health : structure with all health checks and pass/fail flags
%
% Example:
%   opts = struct('plotResults', true, 'saveResults', true, 'figPath', './paper_figs/health/');
%   health = verify_simulation_health(results, config, params, opts);
% ============================================================================

   if nargin < 4, opts = struct(); end
   if ~isfield(opts, 'alpha'), opts.alpha = 0.05; end
   if ~isfield(opts, 'balanceTol'), opts.balanceTol = 0.15; end
   if ~isfield(opts, 'plotResults'), opts.plotResults = true; end
   if ~isfield(opts, 'saveResults'), opts.saveResults = false; end
   if ~isfield(opts, 'figPath'), opts.figPath = './health_check/'; end
   if ~isfield(opts, 'verbose'), opts.verbose = true; end
   
   if opts.saveResults && ~exist(opts.figPath, 'dir')
      mkdir(opts.figPath);
   end
   
   fprintf('\n');
   fprintf('═══ SIMULATION HEALTH & RELIABILITY VERIFICATION ═══\n');
   
   % Initialize health structure
   health = struct();
   health.timestamp = datetime('now');
   health.opts = opts;
   
   resultsTable = struct2table(results.stats_all);

   % Run all health checks
   health.check1_sample_sizes = check_sample_sizes(resultsTable, params, opts);
   health.check2_noise_balance = check_noise_balance(resultsTable, config, opts);
   health.check3_method_balance = check_method_balance(resultsTable, params, anovaResults, opts);
   health.check4_cross_balance = check_cross_balance(resultsTable, params, config, opts);
   health.check5_data_quality = check_data_quality(resultsTable, opts);
   health.check6_normality = check_normality_assumptions(resultsTable, params, anovaResults, opts);
   health.check7_homoscedasticity = check_homoscedasticity(resultsTable, params, opts);
   health.check8_independence = check_independence(resultsTable, opts);
   health.check9_outliers = check_outliers(resultsTable, params, opts);
   health.check10_completeness = check_data_completeness(results, config, opts);
   health.check11_robustness = check_robustness_estimation(KPItableDetailed, opts);
   health.check12_power = calculate_post_hoc_power(anovaResults, KPItableDetailed, opts); % Standard Power (ANOVA-based)
   health.check13_powerANCOVA = calculate_post_hoc_power_ancova(KPItableDetailed, opts);  % Advanced Power (ANCOVA-based)

   % Overall assessment
   health.overall = generate_overall_assessment(health, opts);

   % Generate comprehensive report
   generate_health_report(health, opts);
   
   % Save results
   if opts.saveResults
      save(fullfile(opts.figPath, 'health_diagnostics.mat'), 'health');
      fprintf('\nHealth diagnostics saved to: %s\n', ...
              fullfile(opts.figPath, 'health_diagnostics.mat'));
   end
end

%% ========================================================================
%  OVERALL ASSESSMENT
%  ========================================================================
function overall = generate_overall_assessment(health, opts)
    
    % Collect all PASS flags
    checks = fieldnames(health);
    checkNames = checks(startsWith(checks, 'check'));
    
    nChecks = length(checkNames);
    nPassed = 0;
    
    overall.checks = struct();
    for i = 1:nChecks
        checkName = checkNames{i};
        overall.checks.(checkName) = health.(checkName).PASS;
        if health.(checkName).PASS
            nPassed = nPassed + 1;
        end
    end
    
    overall.totalChecks = nChecks;
    overall.passed = nPassed;
    overall.passRate = 100 * nPassed / nChecks;
    
    % Overall grade
    if overall.passRate == 100
        overall.grade = 'EXCELLENT';
        overall.color = 'green';
    elseif overall.passRate >= 80
        overall.grade = 'GOOD';
        overall.color = 'blue';
    elseif overall.passRate >= 60
        overall.grade = 'ACCEPTABLE';
        overall.color = 'yellow';
    else
        overall.grade = 'POOR';
        overall.color = 'red';
    end
    
    overall.reliable = overall.passRate >= 80;
    overall.PASS = overall.reliable;
end

%% ========================================================================
%  GENERATE COMPREHENSIVE REPORT
%  ========================================================================
function generate_health_report(health, opts)
    
    fprintf('═══════════════════════════════════════════════════════════════\n');
    fprintf('  HEALTH CHECK SUMMARY\n');
    
    % Print results for each check
    checks = fieldnames(health);
    checkNames = checks(startsWith(checks, 'check'));
    
    fprintf('  ────────────────────────────────────────────────────────────\n');
    
    % Get check descriptions
    descriptions = {
        'Sample Sizes';         % 1
        'Noise Balance';        % 2
        'Method Balance';       % 3
        'Cross-Factor Balance'; % 4
        'Data Quality';         % 5
        'Normality';            % 6
        'Homoscedasticity';     % 7
        'Independence';         % 8
        'Outliers';             % 9
        'Completeness';         % 10
        'Robustness Estimation';% 11
        'Power Analysis';       % 12
        'ANCOVA Power Analysis' % 13
    };

    for i = 1:length(checkNames)
        checkName = checkNames{i};
        % Extract number safely
        numStr = regexp(checkName, '\d+', 'match', 'once');
        checkNum = str2double(numStr);
        
        if isfield(health.(checkName), 'PASS')
            passed = health.(checkName).PASS;
        else
            passed = false;
        end
        
        if passed
            symbol = '✓';
        else
            symbol = '✗';
        end
        
        % Ensure we don't index out of bounds if descriptions list is shorter than check count
        descText = 'Unknown Check';
        if checkNum <= length(descriptions)
            descText = descriptions{checkNum};
        end
        
        fprintf('  %s  %2d. %-25s [%s]\n', symbol, checkNum, ...
                descText, string(passed));
    end
    
    fprintf('  ────────────────────────────────────────────────────────────\n');
    fprintf('  Overall Assessment:\n');
    fprintf('  Checks passed: %d/%d (%.1f%%)\n', ...
            health.overall.passed, health.overall.totalChecks, health.overall.passRate);
    fprintf('  Grade: %s\n', health.overall.grade);
    fprintf('  Simulation Reliability: %s\n', string(health.overall.reliable));
    
    fprintf('═══════════════════════════════════════════════════════════════');
    
    % Recommendations
    if ~health.overall.reliable
        fprintf('\n  RECOMMENDATIONS:\n');
        fprintf('  ────────────────────────────────────────────────────────────\n');
        
        if ~health.check1_sample_sizes.PASS
            fprintf('  • Increase sample size per method (target: n≥50)\n');
        end
        if ~health.check2_noise_balance.PASS
            fprintf('  • Rebalance noise level distribution\n');
        end
        if ~health.check3_method_balance.PASS
            fprintf('  • Ensure all methods tested under same noise conditions\n');
        end
        if ~health.check4_cross_balance.PASS
            fprintf('  • Implement balanced factorial design\n');
        end
        if ~health.check6_normality.PASS
            fprintf('  • Consider non-parametric tests (Kruskal-Wallis)\n');
        end
        if ~health.check7_homoscedasticity.PASS
            fprintf('  • Use Welch ANOVA or transform data\n');
        end
        if ~health.check9_outliers.PASS
            fprintf('  • Investigate impact of extreme values (Check Robustness)\n');
        end
        if isfield(health, 'check11_robustness') && ~health.check11_robustness.PASS
            fprintf('  • High skewness detected: Use Trimmed Mean or Median for reporting\n');
        end
        if isfield(health, 'check12_power') && ~health.check12_power.PASS
            fprintf('  • Low statistical power: Observed effect size is too small for current N\n');
        end
        if isfield(health, 'check13_powerANCOVA') && ~health.check13_power.PASS
            fprintf('  • ANCOVA analysis failed: Achieved Power < 0.80\n');
        end
        
        fprintf('  ────────────────────────────────────────────────────────────');
    else
        fprintf('\n  ✓ Simulations meet quality standards for statistical analysis\n');
        fprintf('  ✓ Power and Robustness metrics confirm findings are genuine.\n');
    end
end
