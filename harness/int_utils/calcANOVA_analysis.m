function [anovaResults, results, erM] = calcANOVA_analysis(results, config, params)
% calcANOVA_analysis - Two-way ANOVA (Method × Noise) for configurable pivot metrics
%
% Works with dynamic variables from config.pivotVariables
%
% Purpose:
%   Answers: "Do interleavers behave differently across noise regimes?"
%   - Verifies systematic differences between interleavers
%   - Quantifies effect sizes (η²)
%   - Analyzes robustness across noise levels
%   - Focuses on significant S-interleaver differences if detected
%
% Inputs:
%   results - Simulation results structure with stats_all field
%   config  - Configuration structure with:
%             .pivotVariables - Cell array of metric names (e.g., {'cont', 'effectiveness'})
%             .noiseBins - Number of noise level bins for discretization
%             .noiseLevels - (Optional) Pre-defined bin edges
%   params  - Parameters structure with:
%             .topN - Number of top-performing methods to identify
%
% Outputs:
%   anovaResults - Structure containing:
%                  .raw_data - Filtered data table
%                  .(metricName) - ANOVA results for each pivot metric
%                  .
%                  .methodStats - Per-method noise statistics
%                  .interpretation - Statistical interpretation flags
%   results.summary - Table - Descriptive stats of primary metrics by method
%                 {'method', 'mean', 'std', 'sem'}
%   results.topMethods - Top N performing methods (N comes from config)
%   results.topMethods_CRscores - Top N performing methods CR scores
%   erM - Error message (empty if successful)

erM = "";
anovaResults = struct();

try
    %% ============================================================
    %% 1. INPUT VALIDATION & DATA PREPARATION
    %% ============================================================
    
    % Validate inputs
    if ~isfield(results, 'stats_all') || isempty(results.stats_all)
        erM = "stats_all not found in results";
        error(erM);
    end
    
    if ~isfield(config, 'pivotVariables') || isempty(config.pivotVariables)
        erM = "config.pivotVariables not defined";
        error(erM);
    end
    
    if ~isfield(config, 'noiseBins')
        config.noiseBins = 3; % Default to 3 bins
        warning('config.noiseBins not set, using default: 3');
    end
    
    if ~isfield(params, 'topN')
        params.topN = 5; % Default to top 5
        warning('params.topN not set, using default: 5');
    end
    
    stats = results.stats_all;
    nObs = numel(stats);
    pivotVariables = config.pivotVariables;
    nMetrics = length(pivotVariables);
    
    %% ============================================================
    %% 2. BUILD ANALYSIS TABLE
    %% ============================================================
    % Extract common fields
    method = cell(nObs, 1);
    noise = zeros(nObs, 1);
    
    for i = 1:nObs
        method{i} = stats(i).method;
        noise(i) = stats(i).noiseActual;
    end
    
    % Create base table
    data = table(method, noise, 'VariableNames', {'method', 'noise'});
    
    % Add pivot variables dynamically
    for m = 1:nMetrics
        metricName = pivotVariables{m};
        
        if ~isfield(stats, metricName)
            warning('Metric "%s" not found in stats_all. Skipping...', metricName);
            continue;
        end
        
        metricData = zeros(nObs, 1);
        for i = 1:nObs
            if isfield(stats(i), metricName)
                metricData(i) = stats(i).(metricName);
            else
                metricData(i) = NaN;
            end
        end
        
        data.(metricName) = metricData;
    end
    
    % Remove rows with any invalid values in pivot variables
    validMask = true(height(data), 1);
    for m = 1:nMetrics
        metricName = pivotVariables{m};
        if ismember(metricName, data.Properties.VariableNames)
            validMask = validMask & isfinite(data.(metricName));
        end
    end
    
    data = data(validMask, :);
    
    fprintf('Valid observations: %d\n', height(data));
    fprintf('Methods: %d unique\n', numel(unique(data.method)));
    fprintf('Noise levels: %d unique values\n', numel(unique(data.noise)));
    fprintf('Pivot variables: %s\n', strjoin(pivotVariables, ', '));
    
    %% ============================================================
    %% 3. DISCRETIZE NOISE INTO BINS
    %% ============================================================
    
    nBins = config.noiseBins;
    
    % Discretize noise levels
    if isfield(config, 'noiseLevels') && numel(config.noiseLevels) == (nBins + 1)
        data.noiseCat = discretize(data.noise, config.noiseLevels);
    else
        data.noiseCat = discretize(data.noise, nBins);
    end
    
   %% Calculate representative noise level for each bin (median)
   %  Define noise levels
   noiseLevels = config.noiseLevels;
   % Calculate midpoints to create boundary edges
   % This ensures a value like 0.133 is mapped to Cat 1, and 0.135 to Cat 2
   midpoints = noiseLevels(1:end-1) + (noiseLevels(2:end) - noiseLevels(1:end-1))/2;
   edges = [-Inf, midpoints, Inf];
   % Categorize the data. noiseCat will be an integer from 1 to 7
   data.noiseCat = discretize(data.noise, edges);
   % Count  
   for k = 1:nBins
      idx = (data.noiseCat == k);
      if any(idx)
         noiseCounts(k) = sum(idx);
      end
   end
    
   fprintf('\nNoise Bin Summary:\n');
   disp(table((1:nBins)', noiseLevels', noiseCounts', ...
              'VariableNames', {'noiseCat', 'noiseLevel', 'N'}));
   
   % Verify all bins have data
   fprintf('Noise category distribution:\n');
   tabulate(data.noiseCat);
   
   % Store in results
   anovaResults.raw_data = data;
   anovaResults.noiseBins = nBins;
   anovaResults.noiseLevels = noiseLevels;
   anovaResults.noiseCounts = noiseCounts;
    
    %% ============================================================
    %% 4. TWO-WAY ANOVA FOR EACH PIVOT METRIC
    %% ============================================================
    
   for m = 1:nMetrics
      metricName = pivotVariables{m};
      
      % Skip if metric not in table
      if ~ismember(metricName, data.Properties.VariableNames)
         warning('Skipping ANOVA for "%s" - not in data table', metricName);
         continue;
      end
      
      fprintf('\n TWO-WAY ANOVA: %s ---------------\n', metricName);
      
      Y = data.(metricName);
% Y = tiedrank(Y);

      G = {data.method, data.noiseCat};
      
      % Run ANOVA
      [p, tbl, stats_anova] = anovan(Y, G, ...
                                    'model', 'interaction', ...
                                    'varnames', {'Method', 'Noise'}, ...
                                    'display', 'off');
      
      % Extract sums of squares
      SS_method = tbl{2, 2};
      SS_noise = tbl{3, 2};
      SS_int = tbl{4, 2};
      SS_total = tbl{end, 2};
      
      % Calculate effect sizes (η²)
      eta2_method = SS_method / SS_total;
      eta2_noise = SS_noise / SS_total;
      eta2_int = SS_int / SS_total;
      
      % Store results
      R = struct();
      R.p_method = p(1);
      R.p_noise = p(2);
      R.p_interaction = p(3);
      R.eta2_method = eta2_method;
      R.eta2_noise = eta2_noise;
      R.eta2_interaction = eta2_int;
      R.anova_table = tbl;
      R.stats = stats_anova;
      
      % Console summary
      fprintf('\t Method effect:      p = %.2e, η² = %.3f', p(1), eta2_method);
      if eta2_method > 0.14
         fprintf(' (LARGE)');
      elseif eta2_method > 0.06
         fprintf(' (MEDIUM)');
      elseif eta2_method > 0.01
         fprintf(' (SMALL)');
      end
      fprintf('\n');
      
      fprintf('\t Noise effect:       p = %.2e, η² = %.3f', p(2), eta2_noise);
      if eta2_noise > 0.14
         fprintf(' (LARGE)');
      elseif eta2_noise > 0.06
         fprintf(' (MEDIUM)');
      elseif eta2_noise > 0.01
         fprintf(' (SMALL)');
      end
      fprintf('\n');
      
      fprintf('\t Method×Noise int.:  p = %.2e, η² = %.3f', p(3), eta2_int);
      if p(3) < 0.05
         fprintf(' (SIGNIFICANT)');
      end
      fprintf('\n');
      
      %% --------------------------------------------------------
      %% 5. POST-HOC ANALYSIS (if method effect is significant)
      %% --------------------------------------------------------
      
      if p(1) < 0.001
         fprintf('\nPost-hoc Tukey–Kramer on Method\n');
         
         [c, means, ~, gnames] = multcompare(stats_anova, ...
                                            'Dimension', 1, ...
                                            'CType', 'tukey-kramer', ...
                                            'Display', 'off');
         
         R.posthoc.comparisons = c;
         R.posthoc.means = means;
         R.posthoc.groups = gnames;
         
         % Focus on S-interleaver (if present)
         % sIdx = find(strcmp(gnames, 'S'));
         sIdx = find(strcmp(gnames, 'Method=S'));
         if ~isempty(sIdx)
            rows = (c(:, 1) == sIdx | c(:, 2) == sIdx);
            R.posthoc.S_vs_all = c(rows, :);
            
            fprintf('\nSignificant S-interleaver differences: -----\n');
            hasSignificant = false;
            for k = find(rows)'
               if c(k, 6) < 0.001
                  hasSignificant = true;
                 if c(k, 1) == sIdx
                    other = gnames{c(k, 2)};
                    diff = c(k, 4);
                 else
                    other = gnames{c(k, 1)};
                    diff = -c(k, 4);
                 end
                 fprintf('  S vs %-15s Δ=%+.4f (p<0.001)\n', other, diff);
               end
            end
            
            if ~hasSignificant
               fprintf('  (No pairwise differences at p<0.001)\n');
            end
         else
            fprintf('  S-interleaver not found in methods\n');
         end
      else
         fprintf('\nMethod effect not significant (p=%.3f) - skipping post-hoc\n', p(1));
      end
      
      % Store results for this metric
      anovaResults.(metricName) = R;
   end
    
   %% ============================================================
   %% 6. DESCRIPTIVE STATISTICS (for paper tables)
   %% ============================================================
   
   fprintf('METHOD DESCRIPTIVE STATISTICS\n');
   
   % Get all available pivot variables in data
   availableVars = intersect(pivotVariables, data.Properties.VariableNames);
   
   if isempty(availableVars)
      warning('No pivot variables found in data for summary statistics');
   else
      summary = grpstats(data, 'method', ...
                       {'mean', 'std', 'sem'}, ...
                        'DataVars', availableVars);
     
      % Sort by first pivot variable (descending)
      sortVar = ['mean_' availableVars{1}];
      if ismember(sortVar, summary.Properties.VariableNames)
         summary = sortrows(summary, sortVar, 'descend');
      end
     
      % anovaResults.summary = summary;
      results.summary = summary;
     
      % Print formatted table
      fprintf('\n%-15s', 'Method');
      for v = 1:length(availableVars)
         fprintf(' %12s', [availableVars{v} '(μ)']);
      end
      fprintf('\n%s\n', repmat('-', 1, 15 + 13*length(availableVars)));
     
      for i = 1:height(summary)
         fprintf('%-15s', summary.method{i});
         for v = 1:length(availableVars)
            meanVar = ['mean_' availableVars{v}];
            fprintf(' %12.4f', summary.(meanVar)(i));
         end
         fprintf('\n');
      end
   end
    
   %% ============================================================
   %% 7. DETERMINE TOP-N PERFORMING METHODS
   %% ============================================================
   
   methods = unique(data.method, 'stable');
   nM = numel(methods);
   topN = params.topN;
   
   % Use first pivot variable as ranking criterion
   rankingMetric = pivotVariables{1};
   
   if ~ismember(rankingMetric, data.Properties.VariableNames)
     warning('Ranking metric "%s" not available. Using first available metric.', rankingMetric);
     rankingMetric = availableVars{1};
   end
   
   meanValues = nan(nM, 1);
    
   for i = 1:nM
      idx = strcmp(data.method, methods{i});
      meanValues(i) = mean(data.(rankingMetric)(idx), 'omitnan');
   end
    
   % Rank descending (higher is better for most metrics)
   [sortedValues, ord] = sort(meanValues, 'descend');
   
   topK = min(topN, nM);
   topMethods = methods(ord(1:topK));
   topMethods_CRscores = sortedValues(1:topK);
   
   % fprintf('\nTop %d Methods (by %s):\n', topK, rankingMetric);
   % for i = 1:topK
   %    fprintf('  %d. %-15s  %s = %.4f\n', i, topMethods{i}, rankingMetric, topMethods_CRscores(i));
   % end
    
   % Store in anovaResults
   anovaResults.methodRanking.methods = methods;
   anovaResults.methodRanking.meanValues = meanValues;
   anovaResults.methodRanking.order = ord;
   anovaResults.methodRanking.rankingMetric = rankingMetric;
   
   % Store in results
   results.topMethods = topMethods;
   results.topMethods_CRscores = topMethods_CRscores;
    
   %% ============================================================
   %% 8. PER-METHOD NOISE STATISTICS (for all pivot variables)
   %% ============================================================
    
    % fprintf('\nBuilding per-method noise statistics...\n');
    
    methodStats = struct();
    
    for i = 1:nM
        methodName = methods{i};
        methodStats.(methodName).noise = anovaResults.noiseLevels;
        
        % For each pivot variable
        for v = 1:length(availableVars)
            varName = availableVars{v};
            
            mu = nan(nBins, 1);
            sem = nan(nBins, 1);
            N_samples = zeros(nBins, 1);
            
            for k = 1:nBins
                idx = strcmp(data.method, methodName) & data.noiseCat == k;
                y = data.(varName)(idx);
                
                N_samples(k) = numel(y);
                
                if N_samples(k) > 1
                    mu(k) = mean(y, 'omitnan');
                    sem(k) = std(y, 'omitnan') / sqrt(N_samples(k));
                end
            end
            
            methodStats.(methodName).(['mean_' varName]) = mu;
            methodStats.(methodName).(['sem_' varName]) = sem;
            methodStats.(methodName).(['N_' varName]) = N_samples;
        end
    end
    
    anovaResults.methodStats = methodStats;
    
    %% ============================================================
    %% 9. INTERPRETATION FLAGS (for reporting)
    %% ============================================================
    
    fprintf('STATISTICAL INTERPRETATION FLAGS ---------\n');
    
    interpretation = struct();
    
    % Check if any metric shows strong method effect
    interpretation.method_effect_strong = false;
    interpretation.noise_effect_strong = false;
    interpretation.interaction_present = false;
    
    for v = 1:length(availableVars)
        varName = availableVars{v};
        if isfield(anovaResults, varName)
            R = anovaResults.(varName);
            
            if R.eta2_method > 0.14
                interpretation.method_effect_strong = true;
                interpretation.(['method_effect_strong_' varName]) = true;
            end
            
            if R.eta2_noise > 0.14
                interpretation.noise_effect_strong = true;
                interpretation.(['noise_effect_strong_' varName]) = true;
            end
            
            if R.p_interaction < 0.05
                interpretation.interaction_present = true;
                interpretation.(['interaction_present_' varName]) = true;
            end
        end
    end
    
    anovaResults.interpretation = interpretation;
    
    fprintf('\t - Strong method effect (η²>0.14): %s\n', ...
        logical2str(interpretation.method_effect_strong));
    fprintf('\t - Strong noise effect (η²>0.14):  %s\n', ...
        logical2str(interpretation.noise_effect_strong));
    fprintf('\t - Method×Noise interaction (p<0.05): %s\n', ...
        logical2str(interpretation.interaction_present));
    
    % Per-metric breakdown
    fprintf('\nPer-metric breakdown: ---------\n');
    for v = 1:length(availableVars)
        varName = availableVars{v};
        if isfield(anovaResults, varName)
            R = anovaResults.(varName);
            fprintf('  %s:\n', varName);
            fprintf('    Method effect: η²=%.3f', R.eta2_method);
            if R.eta2_method > 0.14, fprintf(' (STRONG)'); end
            fprintf('\n');
            fprintf('    Noise effect:  η²=%.3f', R.eta2_noise);
            if R.eta2_noise > 0.14, fprintf(' (STRONG)'); end
            fprintf('\n');
            fprintf('    Interaction:   p=%.4f', R.p_interaction);
            if R.p_interaction < 0.05, fprintf(' (SIGNIFICANT)'); end
            fprintf('\n');
        end
    end
    
    fprintf(' --- ANOVA ANALYSIS COMPLETED SUCCESSFULLY ---\n');
    
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   fprintf('\n*** ERROR IN ANOVA ANALYSIS ***\n');
   fprintf('%s\n', erM);
   anovaResults.error = ME;
end

end
