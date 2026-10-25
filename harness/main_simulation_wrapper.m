% =========================================================================
% S-INTERLEAVING SIMULATION FRAMEWORK
% R. Tanju Sirmen
%
% The map below was generated from the code: the call graph was walked and
% the file names grouped by the folder each one actually sits in. Paths are
% those of this release.
% =========================================================================
%
% ORDER OF EXECUTION (the steps of this file)
% -------------------------------------------------------------------------
%  0. loadFactorTables         local function at the foot of this file
%                              -> PrimeFactorLoader, PrecomputedInterleaverLoader
%  1. configure_simulation     -> configure_FEC_parameters -> calcParametersRS
%  2. run_simulations_sci      THE MAIN LOOP  (the interleave_all_pc path)
%  3. calcKPIs                 -> calcKPIs_engine
%  4. calcANOVA_analysis
%  5. calcCorrelation_analysis -> prepare_correlation_data, displayCorrResults
%  7. calcCrossCorrelationAnalysis -> getMethodStats
%  8. save_results / saveCrossCorrelationResults / verify_saved_results
%  9. plot_all_results
%
% There is no step 6: the numbering is kept as it was so that the step
% numbers in the console output and in the saved logs still line up.
%
% -------------------------------------------------------------------------
% harness/                     top-level flow
% -------------------------------------------------------------------------
%  main_simulation_wrapper.m       this file
%  configure_simulation.m          config + params; the regime and grid
%                                  selectors live here
%  configure_FEC_parameters.m      -> calcParametersRS.m (common/)
%  configure_burst_parameters.m    target noise, chunkSizes, the GE branch
%  configure_interleaver_params.m  per-method parameters
%  run_simulations_sci.m           the main loop, with its own subfunctions:
%                                    run_single_trial, genBurstMask,
%                                    injectBurstErrors_encoded, initResults
%  estimate_L_for_size.m           frame length for a requested payload
%  save_results.m                  -> burstRegimeTag, saveVars_YMD
%  saveCrossCorrelationResults.m   -> burstRegimeTag
%
% -------------------------------------------------------------------------
% harness/int_utils/           the simulation core
% -------------------------------------------------------------------------
%  interleave_all_pc.m         the live interleaving dispatcher (26 methods)
%  deinterleave_all_pc.m       generic: hands every method to
%                              deinterleaver_universal
%  interleaver_generic_pc.m    the per-method call site behind the dispatcher
%  injectBurstErrors_all.m     applies one mask to every method identically
%  genGilbertElliottMask.m     the two-state Markov burst channel
%  burstRegimeTag.m            the single/multi/ge1p00/ge0p70 file prefix
%  decodeRS_all.m  calcDecErrorRates_all.m  calcAvIntRuntime_all.m
%  calcKPIs.m  calcKPIs_engine.m  calcANOVA_analysis.m
%  calcCorrelation_analysis.m  calcCrossCorrelationAnalysis.m
%  displayCorrResults.m  verify_saved_results.m
%  collectStatistics_all.m     loops over the methods
%    -> collectStatistics_x.m  EVERY METRIC IS GATHERED HERE:
%         calcErrorSpreadingMetrics   eta_ES, delta_BS
%         calcECCStats                S_ECC, V_ECC, U_ECC
%         calcSourceSeparationFactor  S_sf
%         calc_spread_factor_invperm  S_factor
%         intraVectorSeparations      sepMin, sepAvg, eta_sep, sepCV
%         calcAdjDist                 adjMin, adjAvg, adjCV
%         analyzeSpectralProperties   PSR  -> metrics/calc_apsr
%         calcLaplacianEnergy         laplacianEnergy
%         measureBurstDistribution    delta_G
%
% -------------------------------------------------------------------------
% metrics/                     the metric core
% -------------------------------------------------------------------------
%  calcErrorSpreadingMetrics.m  calcECCStats.m  calc_spread_factor_invperm.m
%  calc_apsr.m  calc_bguar_invperm.m  calc_esload_invperm.m
%  calc_dispersion_invperm.m  calc_adjdispersion_invperm.m
%  calc_snew_invperm.m  calc_srandom_spread_invperm.m
%  calcBlockPatternFitScore.m
%  measureBurstDistribution.m   -> analyzeBurstDistribution.m
%                               -> calcDistributionEfficiency.m
%                                    -> calcGiniCoefficient.m
%                                    -> assessECCSustainability.m
%
% -------------------------------------------------------------------------
% common/                      shared numeric helpers and the RS codec
% -------------------------------------------------------------------------
%  encoderRS_CW.m  decoderRS_CW.m  getRSCodec.m  calcParametersRS.m
%  intraVectorSeparations.m  intraVectorDistances.m  pairwiseRowDistances.m
%  calcLaplacianEnergy.m  calcCoefficientOfVariation.m  calculateSNR.m
%  controlCorrectShape_1N.m  controlCorrectShape_N1.m
%  createLatinSquare.m  findUniqueMultiplierPairs.m  saveVars_YMD.m
%
% -------------------------------------------------------------------------
% harness/int_common/          shared harness helpers
% -------------------------------------------------------------------------
%  swapRowsOddEven.m  swapColsOddEven.m   (the S-Interleaving swap core)
%  getSizeList.m      the single owner of the length grid
%  extractMetricData.m  getMethodStats.m  prepare_correlation_data.m
%
% -------------------------------------------------------------------------
% interleavers/  (one int_<method>/ subfolder each)       26 METHODS
% -------------------------------------------------------------------------
%  matrix-based   : block  matrix  helical  helicalScan  diagonal  spiral
%  stochastic     : random  chaotic
%  algebraic      : algebraic (QPP/LPP, f1 and f2 chosen on spread)
%                   turbo (QPP)  prime (exponentiation / primitive root)
%                   latinSquare
%  multi-stage    : hierarchical (a coarse block step then a fine
%                   within-block step)
%  multi-dimensional : multiDim (3-D lattice, Blaum-Bruck-Vardy axis
%                   rotation)
%  OFDM axes      : time (symbol axis)
%                   freqDeterm / freqRandom (subcarrier axis)
%                   the two permute DIFFERENT axes of the same Nsc x Nsym
%                   grid - the pair that DVB-T/T2 and LTE define separately
%  stream         : convolutional
%  snake          : snake (formerly 'cross'; NOT the convolutional cross
%                   interleaver of CIRC)
%  high-spread    : srandom  goldenRP  drp  arp
%  code-matched   : blockCM  convCM
%  proposed       : S       -> interleaver_S
%                             -> getLK_S_min -> getFactorPairs
%                                            -> getLK_strategy
%                                            -> findUniqueMultiplierPairs
%                                            -> isInPrimesTable
%  deinterleaver_universal.m   inverts a permutation; enough for all of them
%  choose_balanced_factors.m   the near-square factorisation several
%                              matrix-based methods share
%
% -------------------------------------------------------------------------
% harness/factor_factory/      the precomputed tables
% -------------------------------------------------------------------------
%  PrimesFactorsGenerator.m  PrecomputeFactorsGenerator.m
%  PrecomputeInterleaversGenerator.m  run_PrecomputeInterleavers.m
%  PrimeFactorLoader.m  PrecomputedInterleaverLoader.m
%  getFactorPairs.m  isInPrimesTable.m  DiagnosePrecomputedTable.m
%  clearHarnessCaches.m   call this after regenerating any table: four of
%                         the loaders cache by directory path
%
% -------------------------------------------------------------------------
% health/                      campaign health checks H0-H6
% -------------------------------------------------------------------------
%  health_check.m       H0-H6; every check returns a verdict, never a score
%  health_selftest.m    shows that every blocking check CAN fail
%
% -------------------------------------------------------------------------
% plotting/  (called by plot_all_results.m)
% -------------------------------------------------------------------------
%  plotKPItraces  plotKPIbyNoise  plotKPIBoxplots  plotKPIScenarios
%  plotECCMetrics  plotAdjacencyMetrics  plotAdjBlock  plotSepAvg
%  plotDistanceSpectrum  plotRandomnessPeriodicity  plotRadarComparison
%  plotNoiseDistribution  plotNoisePositions  plotMetricCrossCorrelations
%  plotPerformanceComplexityTradeoff  barRuntimes  barRuntimeTradeoff
%  plot_anova_results  plot_correlation_results  formatMetricNames
%                                                   (all -> savePlot.m)
%
% These are the campaign's own diagnostic plots. The seven figures of the
% paper are produced by analysis/, not from here.
%
% =========================================================================

% main_simulation_wrapper.m
% Wrapper script for interleaving simulation framework
% Coordinates all functions into a complete workflow

% Clear workspace and close figures
close all; 
% clc; 
% % % clear; 

try
   paramsInt = struct();
   paramsInt.algOpts = struct();

   tables = struct();
   
   %% 0. Load precomputed interleavers, primes and factors data (to speed up interleavers)
   % Resolved rather than typed in: find_table_dir looks for
   % table_factors_precomputed.mat from here outward and on the MATLAB path.
   % Two outputs are requested on purpose: with one, find_table_dir raises
   % instead of returning, and the fallback below would never be reached.
   % The fallback keeps the historical layout without naming any machine.
   [dataDir_PrimeFactor, ~] = find_table_dir();
   if isempty(dataDir_PrimeFactor)
      dataDir_PrimeFactor = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data_PrimeFactor');
   end

   % [paramsInt.table_precomputed, paramsInt.table_primes, paramsInt.table_factors, erM] = loadFactorTables(dataDir_PrimeFactor);
   [tables.table_precomputed, tables.table_primes, tables.table_factors, erM] = loadFactorTables(dataDir_PrimeFactor);
   if erM ~=  ""; fprintf(erM); return; end
   fprintf("Tables Loaded  \n");

   %% 1. Initialize Simulation
   fprintf('Initializing simulation parameters...\n');
   [config, params] = configure_simulation();
   
   %% 2. Run Simulations
   % 2026-08: the old banner read "Testing size range: %d-%d (step %d)", which
   % is false whenever config.sizeList is set - the grid is an explicit list,
   % not an arithmetic range, and "step 1" implies 1765 lengths where the
   % sweep visits 50. It also never named the two selectors that decide what
   % this run IS, so two runs of the same file could differ in grid and regime
   % with nothing in the log to tell them apart months later.
   gmLbl = '(legacy)'; if isfield(config,'gridMode')    && ~isempty(config.gridMode),    gmLbl = config.gridMode;    end
   brLbl = '(unset)';  if isfield(config,'burstRegime') && ~isempty(config.burstRegime), brLbl = config.burstRegime; end
   [~, sizeDesc] = getSizeList(config);

   fprintf('\tMethods (%d):\n %s | PDFs: %s\n', ...
       numel(params.intMethods), strjoin(params.intMethods, ', '), strjoin(params.dPDF, ','));
   fprintf('\tGrid mode: %-10s | Burst regime: %s\n', gmLbl, brLbl);
   fprintf('\tSizes: %s | Mode: %s\n', sizeDesc, config.sizeTestMode);
   fprintf('\ttestRunsMax: %d | noiseBins: %d | save: %d | plot: %d\n', ...
       config.testRunsMax, config.noiseBins, config.saveResults, config.plotResults);
   % Console label must name the regime that will actually run; with GE on,
   % 'Single-Burst'/'Multi-Burst' would be actively misleading.
   switch burstRegimeTag(config)
      case 'single', burstType = 'Single-Burst';
      case 'multi',  burstType = 'Multi-Burst';
      otherwise,     burstType = sprintf('Gilbert-Elliott (e_B=%.2f)', config.ge_errProbBad);
   end
   fprintf(strcat('\t',burstType,' Noise regimes (edge percentages): '));
   fprintf('%.4f ', config.noiseLevels);
   fprintf('\n\t=== SIMULATION STARTS ===');
   [results, success, paramsInt, burstConfig] = run_simulations_sci(config, params, paramsInt, tables);
   if ~success; fprintf('Simulations failed...\n'); return; end
   
   %% 3. Analyze Results, compute KPIs, etc
   fprintf('Analyzing results, computing KPIs...\n');
   % Compute KPI with specific weights (e.g., balanced)
   [KPItableSummary, KPItableDetailed, results, erM] = calcKPIs(results, config, [0.5, 0.5]);
   if erM ~= ""; fprintf(erM); return; end %%% QUIT..!
   fprintf('=== KPI Results (balanced scenario): ===\n'); disp(KPItableSummary); % Display balanced KPI summary

   %% 4. ANOVA analysis 
   fprintf('\n\t=== TWO-WAY ANOVA ANALYSIS (Method × Noise), please wait ===\n');
   [anovaResults, results, erM] = calcANOVA_analysis(results, config, params);
   if erM ~= "";  fprintf(strcat("\n*** ", erM)); return;  end %%% QUIT..!
   
   %% 5. Correlation analysis
   if config.corr
      fprintf('\n\t=== CORRELATION ANALYSIS, please wait ===\n');
      verbose = true; % display corr results on screen?
      [corrResults, correlation_data, erM] = calcCorrelation_analysis(results, config, verbose);
      if erM ~= ""; fprintf(strcat("\n*** ", erM)); return;  end %%% QUIT..!
   end

   %% 7. Analyze Cross-Correlations in metrics
   fprintf('\t=== CROSS-CORRELATION ANALYSIS of metrics, please wait ===\n');
   [crossCorrResults, erM] = calcCrossCorrelationAnalysis(results.stats_all, params.intMethods, config);
   if erM ~= "";  fprintf(strcat("\n*** ", erM)); return;  end %%% QUIT..!

   %% 8. Save results, if configured
   if config.saveResults
      save_results(config, results, params, paramsInt, config, burstConfig, anovaResults, correlation_data, crossCorrResults, KPItableDetailed);
         saveCrossCorrelationResults(crossCorrResults, config)

      % --- did it actually land on disk? (own try/catch so a hiccup here is
      %     not mistaken for a simulation failure by the outer handler) ---
      try
         verify_saved_results(config.dataSavePath);
      catch MEv
         fprintf('\n(verify_saved_results skipped: %s)\n', MEv.message);
      end
   end

   %% 9. Plot Results
   if config.plotResults
      % decide which method results to plot
      selectedMethods = params.intMethods;
% config.saveResults = false;
% selectedMethods = results.topMethods(:); % selectedMethods = params.intMethods;
      plot_all_results(results, KPItableSummary, KPItableDetailed, anovaResults, corrResults, config, params, selectedMethods, crossCorrResults);
   end   
   
   fprintf('\n Simulation completed!\n');
   % summarize
   fprintf("\t Tested N's: [%d - %d]",results.testedSizes(1),results.testedSizes(end));
   fprintf("\t Skipped N's: "); 
   if isempty(results.skippedSizes)
      fprintf('None\n'); 
   else
      disp(results.skippedSizes);
   end
   fprintf("\t Tested encoded message lengths: [%d - %d] \n",results.stats_all(1).encodedLen(1),results.stats_all(end).encodedLen(end));
        
catch ME
   fprintf('\nError encountered during simulation:\n');
   fprintf('%s\n', ME.message);
   fprintf('Stack trace:\n');
   for k = 1:length(ME.stack)
      fprintf('File: %s\nName: %s\nLine: %d\n\n', ...
          ME.stack(k).file, ...
          ME.stack(k).name, ...
          ME.stack(k).line);
   end
end

%%%
   
function [table_pc, table_primes, table_factors, erM] = loadFactorTables(dataDir_PrimeFactor)   
   erM = ""; table_pc = []; table_primes = []; table_factors = [];

   [table_primes, table_factors, erM] = PrimeFactorLoader(dataDir_PrimeFactor);
   fprintf('--- Loading Precomputed Interleavers Table ---\n');
   [table_pc, erM] = PrecomputedInterleaverLoader(dataDir_PrimeFactor);
   if erM ~= ""
       erM = strcat('Failed to Precomputed Interleavers table: %s', erM); return;
   end

   fprintf('--- Loading Primes & Factors Tables ---\n');
   [table_primes, table_factors, erM] = PrimeFactorLoader(dataDir_PrimeFactor);
   if erM ~= ""
       erM = strcat('Failed to Primes & Factors table: %s', erM); return;
   end
end
