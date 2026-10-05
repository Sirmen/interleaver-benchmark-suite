% =========================================================================
% S-INTERLEAVING SIMULATION FRAMEWORK
% R. Tanju Sirmen
%
% Bu blok koddan uretildi: cagri grafigi taranarak, dosya adlari gercekte
% bulunduklari klasorlere gore gruplandi. Elle yazilmadi.
% =========================================================================
%
% CALISMA SIRASI (bu dosyanin adimlari)
% -------------------------------------------------------------------------
%  0. loadFactorTables         -> PrimeFactorLoader, PrecomputedInterleaverLoader
%  1. configure_simulation     -> configure_FEC_parameters -> calcParametersRS
%  2. run_simulations_sci      ANA DONGU  (interleave_all_pc yolu)
%  3. calcKPIs                 -> calcKPIs_engine
%  4. calcANOVA_analysis
%  5. calcCorrelation_analysis -> prepare_correlation_data, displayCorrResults
%  7. calcCrossCorrelationAnalysis -> getMethodStats
%  8. save_results / saveCrossCorrelationResults / verify_saved_results
%  9. plot_all_results
%
% NOT: adim 6 yok (numaralandirma tarihsel). run_simulations.m ve
%      analyze_and_plot_results.m ARTIK KULLANILMIYOR; canli yol _sci'dir.
%
% -------------------------------------------------------------------------
% interleaversTest/            ust seviye akis
% -------------------------------------------------------------------------
%  main_simulation_wrapper.m       bu dosya
%  configure_simulation.m          config + params; burstRegime secici burada
%  configure_FEC_parameters.m      -> calcParametersRS.m
%  configure_burst_parameters.m    hedef gurultu, chunkSizes, GE dali
%  configure_interleaver_params.m  yontem parametreleri.
%                                  KALDIRILDI: Lmatrix, Kmatrix, hStep, hStep_hs
%                                  (hesaplaniyor ama hicbir yerde okunmuyordu)
%                                  KALDIRILDI: algOpts'un eski 9 alani (skorlama
%                                  sirali permutasyon uzerinde calisiyordu = sabit)
%  run_simulations_sci.m           ana dongu + alt fonksiyonlar:
%                                    run_single_trial, genBurstMask,
%                                    injectBurstErrors_encoded, initResults
%  save_results.m                  -> burstRegimeTag, saveVars_YMD
%  saveCrossCorrelationResults.m   -> burstRegimeTag
%  verify_saved_results.m          kayit dogrulama (rejim/alan/KPI kontrolu)
%  plot_all_results.m              tum cizim fonksiyonlarinin dagiticisi
%
% -------------------------------------------------------------------------
% int_utils/                   simulasyon cekirdegi
% -------------------------------------------------------------------------
%  interleave_all_pc.m         CANLI serpistirme dagiticisi (24 yontem)
%  deinterleave_all_pc.m       jenerik: hepsini deinterleaver_universal'a verir
%  interleave_all.m            _pc'siz varyant - su an KULLANILMIYOR
%  deinterleave_all.m          _pc'siz varyant - su an KULLANILMIYOR
%  injectBurstErrors_all.m     maskeyi tum yontemlere ayni sekilde uygular
%  genGilbertElliottMask.m     iki durumlu Markov patlama kanali        [YENI]
%  burstRegimeTag.m            single/multi/ge1p00/ge0p70 dosya oneki   [YENI]
%  encoderRS_CW.m  decoderRS_CW.m  decodeRS_all.m  calcDecErrorRates_all.m
%  calcAvIntRuntime_all.m  calcAvDecodeErrRate_all.m  calcAvEfficiency_all.m
%  calcEfficiency_all.m  calcInfoRates_all.m  calcCR_all.m
%  isNoiseLevelOk_all.m  estimate_L_for_size.m  calculateSNR.m
%  collectStatistics_all.m     yontemler uzerinde doner
%    -> collectStatistics_x.m  TUM OLCUTLER burada toplanir:
%         calcErrorSpreadingMetrics   eta_ES, delta_BS
%         calcECCStats                S_ECC, V_ECC, U_ECC
%         calcSourceSeparationFactor  S_sf
%         calc_spread_factor_invperm  S_factor
%         intraVectorSeparations      sepMin, sepAvg, eta_sep, sepCV
%         calcAdjDist                 adjMin, adjAvg, adjCV
%         analyzeSpectralProperties   PSR
%         calcLaplacianEnergy         laplacianEnergy
%         measureBurstDistribution    delta_G
%  calcKPIs.m  calcKPIs_engine.m  calcANOVA_analysis.m
%  calcCorrelation_analysis.m  calcCrossCorrelationAnalysis.m
%  analyzeSpectralProperties.m  calcAdjDist.m  calcSourceSeparationFactor.m
%
% -------------------------------------------------------------------------
% metrics/                     olcut cekirdegi
% -------------------------------------------------------------------------
%  calcErrorSpreadingMetrics.m  calcECCStats.m  calc_spread_factor_invperm.m
%  measureBurstDistribution.m   -> analyzeBurstDistribution.m
%                               -> calcDistributionEfficiency.m
%                                    -> calcGiniCoefficient.m
%                                    -> assessECCSustainability.m
%  intraVectorSeparations_.m  intraVectorDistances_.m  calcLaplacianEnergy_.m
%  calcECCViolations.m  calcECCMargin.m  calcDistanceSpectrum.m
%  calcPeriodicityMetrics.m  calcPermutationRandomness.m  verifyMetricsCollection.m
%
% -------------------------------------------------------------------------
% int_common/                  paylasilan yardimcilar
% -------------------------------------------------------------------------
%  swapRowsOddEven.m  swapColsOddEven.m       (S-Interleaving takas cekirdegi)
%  controlCorrectShape_1N.m  controlCorrectShape_N1.m
%  extractMetricData.m  formatMetricNames.m  getMethodStats.m
%  prepare_correlation_data.m  prepare_cross_correlation_data.m
%
% -------------------------------------------------------------------------
% interleavers/  (int_<yontem>/ alt klasorleri)      24 YONTEM
% -------------------------------------------------------------------------
%  matris tabanli : block  matrix  helical  helicalScan  diagonal  spiral
%  stokastik      : random  chaotic
%  cebirsel       : algebraic (QPP/LPP, spread'e gore secilmis f1,f2)
%                   turbo (QPP)  prime (us alma / ilkel kok)  latinSquare
%  cok kademeli   : hierarchical (kaba blok o ince blok-ici adim)
%  cok boyutlu    : multiDim (3-B kafes, Blaum-Bruck-Vardy eksen dondurmesi)
%  OFDM eksenli   : time (sembol ekseni)  freqDeterm / freqRandom (alt tasiyici)
%                   ikisi ayni Nsc x Nsym izgarasinin FARKLI eksenlerini permute
%                   eder - DVB-T/T2 ve LTE'nin ayri ayri tanimladigi cift
%  akis           : convolutional
%  snake          : snake   (eski 'cross' - CIRC evrisimli cross DEGIL)  [AD DEGISTI]
%  yuksek spread  : srandom  goldenRP  drp  arp                          [YENI]
%  onerilen       : S       -> interleaver_S / interleaver_S_pc
%                             -> getLK_S_min -> getFactorPairs -> getLK_strategy
%                                            -> findUniqueMultiplierPairs
%                                            -> isInPrimesTable
%  deinterleaver_universal.m  permutasyondan tersini alir - hepsi icin yeterli
%
% -------------------------------------------------------------------------
% factor_factory/              onhesaplanmis tablolar
% -------------------------------------------------------------------------
%  PrimesFactorsGenerator.m  PrecomputeFactorsGenerator.m
%  PrecomputeInterleaversGenerator.m
%  PrimeFactorLoader.m  PrecomputedInterleaverLoader.m
%  PrimeFactor_PrecomputedLoader.m
%
% -------------------------------------------------------------------------
% analyzeSimulationHealth/     saglik/saglamlik protokolu (adim 4 icinde)
% -------------------------------------------------------------------------
%  analyzeSimulationHealth.m -> check_sample_sizes  check_noise_balance
%     check_method_balance  check_cross_balance  check_data_quality
%     check_normality_assumptions  check_homoscedasticity  check_independence
%     check_outliers  check_data_completeness  check_robustness_estimation
%     calculate_post_hoc_power  calculate_post_hoc_power_ancova
%
% -------------------------------------------------------------------------
% int_plotting/  (plot_all_results.m tarafindan cagrilir)
% -------------------------------------------------------------------------
%  plotKPItraces  plotKPIbyNoise  plotKPIBoxplots  plotKPIScenarios
%  plotECCMetrics  plotAdjacencyMetrics  plotAdjBlock  plotSepAvg
%  plotDistanceSpectrum  plotRandomnessPeriodicity  plotRadarComparison
%  plotNoiseDistribution  plotNoisePositions  plotMetricCrossCorrelations
%  plotPerformanceComplexityTradeoff  barRuntimes  barRuntimeTradeoff
%  plot_anova_results  plot_correlation_results        (hepsi -> savePlot.m)
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
   % [results, success, paramsInt, burstConfig] = run_simulations(config, params, paramsInt);
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
