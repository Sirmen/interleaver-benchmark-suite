function plot_all_results(...
      results, KPItableSummary, KPItableDetailed, anovaResults, corrResults, config, params, selectedMethods, crossCorrResults)
% PLOT_ALL_RESULTS - visualization framework for interleaver evaluation
% Organized into logical sections: Performance, ECC-Awareness, Permutation Quality
% 
% Inputs:
%   results - simulation results structure
%   config  - configuration parameters
%   params  - simulation parameters

try
   lastValid = results.lastValid;
   stats_all = results.stats_all;
    
   %% SECTION 1: CORE PERFORMANCE METRICS
   fprintf('Section 1: Core Performance Analysis plots...\n');

   % % % % 1.1 BER vs SNR (fundamental performance)
   % % % selMet_snr = selectedMethods;
   % % % selMet_snr{length(selectedMethods)+1} = 'withoutInt';
   % % % plotBER_SNR(results.avSNR_all, results.avDecodeErrRate_all, selMet_snr);

   % 1.1 Visualize KPI across all weight scenarios
   plotKPIScenarios(KPItableDetailed, config, selectedMethods);

   % 1.2 KPI traces
   plotKPItraces(KPItableDetailed, KPItableSummary, config, selectedMethods);

   % 1.3 KPI by Noise
   plotKPIbyNoise(KPItableDetailed, config, selectedMethods);

   plotKPIBoxplots(KPItableDetailed, config, selectedMethods);
   % % % plotKPIHeatmaps(KPItableDetailed, config, selectedMethods);
   % % % plotKPIScatterMatrix(KPItableDetailed, config, selectedMethods)


   %% SECTION 2: ECC-AWARENESS & BURST DISTRIBUTION
   fprintf('Section 2: ECC-Awareness & Burst Distribution plots...\n');

   % 2.1 ECC-Aware Metrics (violations, margins, scores)
   plotECCMetrics(stats_all, selectedMethods, config);

   % 2.2 Noise Distribution Visualization
   plotNoiseDistribution(stats_all, selectedMethods, config, lastValid.rcv_enc_ns, ...
                         lastValid.L, lastValid.burstSize_ns, lastValid.burstCount_ns);

   % 2.3 Noise Distribution Visualization
   plotNoisePositions(stats_all, selectedMethods, config, lastValid.rcv_enc_ns, ...
                      lastValid.burstSize_ns, lastValid.burstCount_ns);


   %% SECTION 3: PERMUTATION QUALITY - RANDOMNESS & STRUCTURE
   fprintf('Section 3: Permutation Quality - Randomness plots...\n');

   % 3.1   
   plotDistanceSpectrum(stats_all, selectedMethods, config);

   plotRandomnessPeriodicity(stats_all, selectedMethods, config);

   %% SECTION 4: PERMUTATION QUALITY - DISPERSION
   fprintf('Section 4: Permutation Quality - Dispersion plots...\n');

   % 4.1 Separation Statistics
   plotSepAvg(lastValid.L, lastValid.K, stats_all, selectedMethods, config);

   % 4.2 Adjacency traces
   plotAdjBlock(lastValid.L, lastValid.K, lastValid.permutations, selectedMethods, config);

   % 4.3 Adjacency Statistics
   plotAdjacencyMetrics(stats_all, selectedMethods, config);

   %% SECTION 7: STATISTICAL RESULTS
   fprintf('Section 7: Statistical Analysis plots...\n');

   % 7.1 ANOVA plot
   plot_anova_results(anovaResults, results, selectedMethods, config);

   % 7.2 Radar/Spider plot for top correlating metrics
   plotRadarComparison(results, config, selectedMethods, corrResults);

   % 7.3 Correlations plot
   if config.corr
     plot_correlation_results(corrResults, config);
   end

   % 7.4 Metric Cross-Correlations
   plotMetricCrossCorrelations(config, crossCorrResults);

   %% SECTION 8: COMPUTATIONAL EFFICIENCY
   fprintf('Section 8: Computational Analysis plots...\n');

   % 8.1 Runtime comparison
   barRuntimes(results.avIntRuntime_all, selectedMethods, config);

   % 8.2 Performance vs Complexity trade-off
   plotPerformanceComplexityTradeoff(results, KPItableSummary, selectedMethods, config);
   
   % ARGUMENT ORDER FIXED, 2026. This line used to read
   %     barRuntimeTradeoff(results.avIntRuntime_all, selectedMethods, config)
   % - three arguments into a four-argument function:
   %     function barRuntimeTradeoff(results, KPItableSummary, selectedMethods, config)
   % so results got avIntRuntime_all, KPItableSummary got the method list,
   % selectedMethods got CONFIG, and config was never passed at all (which also
   % silently disabled the save, guarded by nargin > 3).
   % The symptom was "Brace indexing is not supported" on selectedMethods{i} -
   % a config struct being indexed as a cell array. It reads like a type
   % problem in the plotting function; it is a call-site problem here.
   % Note the first argument: the function does isfield(results,'avIntRuntime_all')
   % internally, so it wants the WHOLE results struct.
   barRuntimeTradeoff(results, KPItableSummary, selectedMethods, config);

   fprintf('=== All plots generated successfully ===\n\n');

catch ME
   erM = sprintf('*** %s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   fprintf('%s\n', erM);
end
end

%%%
