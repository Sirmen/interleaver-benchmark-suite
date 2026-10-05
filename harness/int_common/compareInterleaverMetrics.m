% R.Tanju Sirmen - 2024/02
% Compares EDC decoding performances with & without interleaving of 
%  1D (1xN) random data vectors with error bursts of 
%  various burst block sizes, applying various interleaving schemas
% Analysis the correlation between the interleaving distance metrics 
%  and decoding performances.
% Displays the results.
%
% Transmit stage:
%  generate random data
%  EDC encode
%  interleave
% Receive stage:
%  apply noise (i.e. add burst errors)
%  deinterleave
%  EDC decode
% Evaluation stage:
%  measure the interleaving distance metrics
%  measure the decoding errors
%  correlation analysis
% Display results stage

clear all; close all;
try  
   % data parameters:
   base = 8;

   L = 9;      % Block length          7
   K = 12;     % Number of blocks   25,30,35,40,
   N = L * K;  % Total length of the data vector % 280; % 560;

   padSymbol = 0; % base - 1;

   % RS ecc parameters:
   eccReal = 0.14; 
   % eccReal = 0.28; lenData = 282;

   % interleaving methods:
   intMethods = {'random','matrix','convolution','helical','turbo','algebraic','try1','try2','try3','try4'};
   intMethods = {'helical','algebraic','try1','try2','try4','fft1','fft2'}; % ,'try3'
   
   % correlation parameters:
   corrType = "both"; % pierson & spearman
   removeOutliers = false;
   removeZeroPivot = false;
   lvlSign = 0.02; % correlation significance level
   lvlConf = 0.05; % confidence level
   lvlSignOutliers = lvlConf; % significance level for outlier analysis
   correlationVariables = {'minMinCW','avgMinCW','avgCW', 'minAdj','avgAdj','minSep', 'maxSep','avgSep','W','p','noiseDistMin','noiseDistMax','noiseDistAvg'}; % , 'noise','perf'}; %   
   pivotVariable = 'perf';  %  'decErr';  %  

   % burst err parameters:
   burstSize = L;       % the starting length of error burst
   burstCount = 2;      % how many error bursts to start with to inject
   burstStep = 0.1;    % 0.1; 
   % simulations parameters:
   nTest = 3;% 15;     % 50;   % num of simulations
   nSim = 13;% 55;     % 70;   % num of simulations
   excludeZero = true;  % discard 0 values in distance & separation computations

%% transmit
   ns = 1; d = 0;
   for s=1:nSim  
      % increment bursts
      burstSize = burstSize + burstStep; 
      burstCount = burstCount + burstStep;

      for t=1:nTest
         %% gen data
         A = randi([0 base-1],N,1)'; 

         %% Inject burst errors
         noisyCountMin = N * 0.1;  % Minimum error rate (10%)
         noisyCountMax = N * 0.3;  % Maximum error rate (30%)
         % Create burst errors that will corrupt several adjacent codewords
         [rcv_enc, errorsR, errRateR, noiseLocationsNdx] = addErrBurst(A', burstSize, burstCount, noisyCountMin, noisyCountMax, base-1);

         %% Interleave:
         % interleaving parameters:
         % for helical interleaving:
         hStep = 2; 
         % for convolutional interleaving: higher>more spread, lower>faster (1-3)
         bufferRows= 3; bufferSlope = 2;
         % for random interleaving:
         permutationSeed = 6012;

         % interleave
         if sum(ismember(intMethods, 'random')) > 0
            [int_ran, permutation_ran] = interleaver_random(noiseLocationsNdx, L, permutationSeed, padSymbol); 
         end
         if sum(ismember(intMethods, 'matrix')) > 0
            [int_mat, permutation_mat] = interleaver_matrix(noiseLocationsNdx, L, padSymbol);
         end
         if sum(ismember(intMethods, 'convolution')) > 0
            [int_con, permutation_con] = interleaver_convolutional(noiseLocationsNdx, bufferRows, bufferSlope);
         end
         if sum(ismember(intMethods, 'helical')) > 0
            [int_hel, permutation_hel] = interleaver_helicalScan(noiseLocationsNdx, L, hStep, padSymbol);
         end
         if sum(ismember(intMethods, 'turbo')) > 0
            [int_tur, permutation_tur] = interleaver_turbo(noiseLocationsNdx, L, padSymbol);
         end
         if sum(ismember(intMethods, 'algebraic')) > 0
            [int_alg, permutation_alg] = interleaver_algebraic(noiseLocationsNdx, L, K, padSymbol);
         end
         % if sum(ismember(intMethods, 'try1')) > 0
         %    [int_try1, permutation_try1, erM ] = interleaver_TS_try_1(noiseLocationsNdx, L);
         % end
         % if sum(ismember(intMethods, 'try2')) > 0
         %    [int_try2, permutation_try2, erM] = interleaver_TS_try_2(noiseLocationsNdx, L);
         % end
         % if sum(ismember(intMethods, 'try3')) > 0
         %    [int_try3, permutation_try3, erM] = interleaver_TS_try_3(noiseLocationsNdx, L);
         % end
         % if sum(ismember(intMethods, 'try4')) > 0
         %    [int_try4, permutation_try4, erM] = interleaver_TS_try_4(noiseLocationsNdx);
         % end
         if sum(ismember(intMethods, 'block')) > 0
            int_blo = interleaver_block(noiseLocationsNdx, L, padSymbol);
         end
         if sum(ismember(intMethods, 'TS')) > 0
            int_TS = interleaver_TS(noiseLocationsNdx, L, padSymbol);
         end
         if sum(ismember(intMethods, 'fft1')) > 0
            [int_fft1, permutation_f1, erM] = interleaver_FFT1(noiseLocationsNdx, L);
         end
         if sum(ismember(intMethods, 'fft2')) > 0
            [int_fft2, permutation_f2, erM] = interleaver_FFT2(noiseLocationsNdx, L);
         end
         
         %% Compute & keep distance statistics
         % all symbols are equally likely, so assign equal weights needed 
         %  for Kendall's Coefficient O fConcordance
         priority_weights = ones(1, L) / L; 
         if sum(ismember(intMethods, 'random')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_ran);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj] = intraVectorDistances(permutation_ran, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_ran, excludeZero);
            % rehape data for Kendal's W, by removing excessive data 
            %  (since padding w 0 would change the data characteristics)
            rowK = floor(length(permutation_ran) / L); dataK = reshape(permutation_ran(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="random"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'matrix')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_mat);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj] = intraVectorDistances(permutation_mat, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_mat, excludeZero);
            rowK = floor(length(permutation_mat) / L); dataK = reshape(permutation_mat(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="matrix"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'convolution')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_con);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj] = intraVectorDistances(permutation_con, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_con, excludeZero);
            rowK = floor(length(permutation_con) / L); dataK = reshape(permutation_con(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="convolution"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'helical')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_hel);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj] = intraVectorDistances(permutation_hel, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_hel, excludeZero);
            rowK = floor(length(permutation_hel) / L); dataK = reshape(permutation_hel(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="helical"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'turbo')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_tur);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj,] = intraVectorDistances(permutation_tur, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_tur, excludeZero);
            rowK = floor(length(permutation_tur) / L); dataK = reshape(permutation_tur(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="turbo"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'algebraic')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_alg);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj] = intraVectorDistances(permutation_alg, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_alg, excludeZero);
            rowK = floor(length(permutation_alg) / L); dataK = reshape(permutation_alg(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="algebraic"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'TS')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_TS);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj] = intraVectorDistances(int_TS, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_TS, excludeZero);
            rowK = floor(length(permutation_TS) / L); dataK = reshape(permutation_TS(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="TS"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'block')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_blo);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj] = intraVectorDistances(int_blo, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_B, excludeZero);
            rowK = floor(length(int_blo) / L); dataK = reshape(int_blo(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="block"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'try1')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_try1);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj] = intraVectorDistances(permutation_try1, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_try1, excludeZero);
            rowK = floor(length(permutation_try1) / L); dataK = reshape(permutation_try1(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="try1"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'try2')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_try2);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj] = intraVectorDistances(permutation_try2, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_try2, excludeZero);
            rowK = floor(length(permutation_try2) / L); dataK = reshape(permutation_try2(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="try2"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'try3')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_try3);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minMinCW, dist.maxMinCW, dist.avgMinCW, dist.avgCW, dist.minAdj, dist.avgAdj] = intraVectorDistances(permutation_try3, L, excludeZero);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_try3, excludeZero);
            rowK = floor(length(permutation_try3) / L); dataK = reshape(permutation_try3(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="try3"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'try4')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_try4);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_try4, excludeZero);
            rowK = floor(length(permutation_try4) / L); dataK = reshape(permutation_try4(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="try4"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'fft1')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_fft1);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_f1, excludeZero);
            rowK = floor(length(permutation_f1) / L); dataK = reshape(permutation_f1(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="fft1"; d = d + 1; distAll(d) = dist;
         end
         if sum(ismember(intMethods, 'fft2')) > 0
            [noisePositions, noiseDistances] = distNoisePositions(int_fft2);
            dist.noiseDistMin = min(noiseDistances); dist.noiseDistMax = max(noiseDistances); dist.noiseDistAvg = mean(noiseDistances);
            [dist.minSep, dist.maxSep, dist.avgSep] = intraVectorSeparations(permutation_f2, excludeZero);
            rowK = floor(length(permutation_f2) / L); dataK = reshape(permutation_f2(1:L * rowK), L, rowK)';
            [dist.W, dist.p, Fdist] = calcKendallCoefficientOfConcordanceWeighted(dataK, priority_weights);
               dist.method="fft2"; d = d + 1; distAll(d) = dist;
         end
         
% cse = 3; % 1, 2 or 3
% typ = 'single'; % or 'k'
% [ICC1s] = calcInterclassCorrelations(A, cse, typ);
% rc = calcCorcordanceCorrelationCoefficient(X);
% use normalized entropy for comperability accross diffirent data sizes
% [entropy, entropy_normalized] = calcEntropy1D(dData);
% H = entropy_normalized;
   

      end % for t=1:nTest
   
      % Calculate & keep interleaving info-rate
      if sum(ismember(intMethods, 'random')) > 0
         avIR.random(ns) = length(noiseLocationsNdx) / length(int_ran); 
      end
      if sum(ismember(intMethods, 'matrix')) > 0
         avIR.matrix(ns) = length(noiseLocationsNdx) / length(int_mat); 
      end
      if sum(ismember(intMethods, 'convolution')) > 0
         avIR.convolution(ns) = length(noiseLocationsNdx) / length(int_con); 
      end
      if sum(ismember(intMethods, 'helical')) > 0
         avIR.helical(ns) = length(noiseLocationsNdx) / length(int_hel);
      end
      if sum(ismember(intMethods, 'turbo')) > 0
         avIR.turbo(ns) = length(noiseLocationsNdx) / length(int_tur);
      end
      if sum(ismember(intMethods, 'algebraic')) > 0
         avIR.algebraic(ns) = length(noiseLocationsNdx) / length(int_alg);
      end
      if sum(ismember(intMethods, 'try1')) > 0
         avIR.try1(ns) = length(noiseLocationsNdx) / length(int_try1); 
      end
      if sum(ismember(intMethods, 'try2')) > 0
         avIR.try2(ns) = length(noiseLocationsNdx) / length(int_try2); 
      end
      if sum(ismember(intMethods, 'try3')) > 0
         avIR.try3(ns) = length(noiseLocationsNdx) / length(int_try3); 
      end
      if sum(ismember(intMethods, 'try4')) > 0
         avIR.try4(ns) = length(noiseLocationsNdx) / length(int_try4); 
      end
      if sum(ismember(intMethods, 'block')) > 0
         avIR.blo(ns) = length(noiseLocationsNdx) / length(int_blo); 
      end
      if sum(ismember(intMethods, 'TS')) > 0
         avIR.TS(ns) = length(noiseLocationsNdx) / length(int_TS);   
      end
      if sum(ismember(intMethods, 'fft1')) > 0
         avIR.fft1(ns) = length(noiseLocationsNdx) / length(int_fft1);   
      end
      if sum(ismember(intMethods, 'fft2')) > 0
         avIR.fft2(ns) = length(noiseLocationsNdx) / length(int_fft2);   
      end

      ns = ns + 1;
      fprintf("*");
   end % s=1:nSim  

   %% display results
   displayIntInfoRate(L, K, N, avIR, intMethods);

   displayDistanceStats(distAll, intMethods);

   % plotNoise(true_snr, errLocations', rcv_enc, L, burstSize, burstCount);

return % % % stop here

   %% test WITHout Interleaving:
   % testWithoutInterleaving(base, eccReal, noiseLocationsNdx, noiseLocationsNdx, errorsR);

   %% correlation analysis:
   [corP, corS, corPsorted, corSsorted, cMaxP, cMaxS, N, corData] = ...
      correlationAnalysis(correlationVariables, distAll, corrType, pivotVariable, removeZeroPivot, lvlSign);

   % plot correlation results
   % sorted correlation graphs:
   if ~isempty(corPsorted) && ~isempty(corSsorted)
      figure
      if ~isempty(corPsorted)
         subplot(2,1,1) 
         gData = abs(corPsorted);
         corrGraphSorted(gData, "Pearson", correlationVariables, pivotVariable);
      end
      if ~isempty(corSsorted)
         subplot(2,1,2)
         gData = abs(corSsorted);
         corrGraphSorted(gData, "Spearman", correlationVariables, pivotVariable);
      end
   end
   % % correlation graphs:
   % g1 = abs(corP(:,1));
   % g2 = abs(corS(:,1));
   % corrGraph2(g1, g2, indexNames, pivot);

catch erripd
    rethrow(erripd);
end % catch

%% subs %%%%%%% %%%%%%%

%% testWithoutInterleaving
function [] = testWithoutInterleaving(base, eccReal, msg, encoded, errorsR)
   % apply the same latest burst errors
   rcv_wo = bitxor(encoded, errorsR'); 
   [~, noiseRatio_wo] = symerr(double(encoded), double(rcv_wo)); 

   % RS Decode
   [decodedWo, lenCW, corrCWrate_r1, uncorrCWrate_r1, errCWs, eccReal2, rsDecoder2] = ...
     decoderRS_CW( rcv_wo, base, eccReal );

   % Error statistics WITHOUT Interleaving
   [errCwo, errRwo] = symerr(msg, decodedWo'); % Decoding error count, rate
   p_wo = 1 - (errRwo / noiseRatio_wo); % performance

   rMsg = strcat("\nDecoding performance WITHout interleaving: ",num2str(p_wo), ...
                 "\tDecoding error rate: ",num2str(errRwo));
   fprintf(rMsg);
end

%% displayIntInfoRate
function [] = displayIntInfoRate(L, K, N, avIR, intMethods)
   nMethod = length(intMethods);
   % extract performance data. rows are methods, cols performances 
   for i=1:nMethod
      method = string(intMethods(i));
      irData(i,:) = extractfield(avIR,method);
   end
   %% display Performance results
   rMsg = strcat("\nData L: ",num2str(L),"\tK:",num2str(K),"\tN:",num2str(N)); fprintf(rMsg);
   fprintf("\nInterleaving Information Rates:");
   for i=1:nMethod
      method = string(intMethods(i));
      rMsg = strcat("\n\t", method, ": ", num2str(mean(irData(i,:)),'%.4f')); fprintf(rMsg);
   end
end % displayIntInfoRate

%% correlationAnalysis
function [corP, corS, corPsorted, corSsorted, cMaxP, cMaxS, N, corData] = ...
            correlationAnalysis(correlationVariables, dData, corrType, pivot, removeZeroPivot, lvlSignCor)   
% analyze correlation in FPr vs. internal validity indices
% set corrType to 'Both' to compute both Pearson and Spearman types
try
   % set params
   removeOutliers = true;     % true to remove rows with outlier elements in col
   % significance levels:
   lvlSignOutlier = 0.05;     % significance level for determining outliers
   lvlConfCor = 0.05;         % significance (1-confidence) level for correlation 
   rowCount = size(dData,2);
   colCount = size(correlationVariables,2);
   nCorrCols = colCount+1; % num of vars to be included in corr mtx
   corData = zeros(rowCount, nCorrCols); corData(:) = NaN;
   for r=1:rowCount
      for indx=1:colCount
         ndx = string(correlationVariables(indx));
         corData(r,indx+1) = extractfield(dData(r),ndx);
      end
 	end
   corData(:,1) = extractfield(dData,pivot); 
   % prepare
   pivotCol = 1; 
   agentCols = [2:nCorrCols];  % index columns
   % remove NaNs
  	corData = rmmissing(corData);
   % remove rows w pvtCol value = 0
   if removeZeroPivot
      nz = corData(:, pivotCol) == 0; 
      corData(nz,:) = []; % remove 
   end
   % get sample size subject to analysis
   N = length(corData);
   % analyze correlation (Pierson and/or Spearman) between pivot and data columns
   [corP, corS, corPsorted, corSsorted, cMaxP, cMaxS] = ...
         calcCorrelation(corData, pivotCol, agentCols, ...
                         lvlSignCor, lvlConfCor, ...
                         removeOutliers, lvlSignOutlier, ...
                         corrType);   
catch err
    rethrow(err);
end % catch
end

%% corrGraph
function [] = corrGraphSorted(gData, gTitle, correlationVariables, pivot)   
% draws correlation graph
try
   nRow = size(gData,1);
   nCol = size(gData,2);
   for i=1:nRow
      ndx = gData(i,nCol)-1;
      nameA(i) = correlationVariables(ndx);
   end
   nameS = cellstr(nameA);
   x = categorical(nameS);
   x = reordercats(x,nameS);
  	b = bar(x, gData(:,1), 'g');
   if upper(gTitle) == "PEARSON"
      b = bar(x, gData(:,1), 'b');
   end
   ylabel('R^2')
   xtips1 = b(1).XEndPoints;
   ytips1 = b(1).YEndPoints;
   ata = round(b(1).YData,4);
   labels1 = string(ata);
   text(xtips1,ytips1,labels1,'HorizontalAlignment','center','VerticalAlignment','bottom',...
                              'FontSize',8,'FontAngle','italic','color','m');
   ylim([0 1])
   for is=1:size(gData,1)
      if gData(is,1) < 0.4 % low correlation
         b.FaceColor = 'flat';
         b.CData(is,:) = [.3 .4 .0];
         if upper(gTitle) == "PEARSON"
            b.CData(is,:) = [.0 .3 .3];
         end
      elseif (gData(is,1) < 0.6) % medium correlation
         b.FaceColor = 'flat';
         b.CData(is,:) = [.4 .5 .0];
         if upper(gTitle) == "PEARSON"
            b.CData(is,:) = [.0 .4 .5];
         end
      elseif (gData(is,1) < 0.8) % medium correlation
         b.FaceColor = 'flat';
         b.CData(is,:) = [.6 .7 .3];
         if upper(gTitle) == "PEARSON"
            b.CData(is,:) = [.3 .6 .7];
         end
      end
   end
   title(gTitle), grid on
   grid on, sgtitle(strcat('Correlations (', pivot, ' & distance metrics) in r^2 Order'),'FontSize',12);
catch errcg
   rethrow(errcg);
end % catch
end   

%% corrGraph2
function [] = corrGraph2(gData1, gData2, indexNames, pivot)   
% draws correlation graph
try
   figure
   if ~isempty(gData1)
      subplot(2,1,1)
      x = categorical(indexNames);
      x = reordercats(x,indexNames);
      b = bar(x, gData1, 'g');

      ylabel('R^2')
      xtips1 = b(1).XEndPoints;
      ytips1 = b(1).YEndPoints;
      ata = round(b(1).YData,4);
      labels1 = string(ata);
      text(xtips1,ytips1,labels1,'HorizontalAlignment','center','VerticalAlignment','bottom',...
                                 'FontSize',8,'FontAngle','italic','color','m');
      ylim([0 1])
      for is=1:size(gData1,1)
         if gData1(is,1) < 0.4 % low correlation
            b.FaceColor = 'flat';
            b.CData(is,:) = [.3 .4 .0];
         elseif (gData1(is,1) < 0.6) % medium correlation
            b.FaceColor = 'flat';
            b.CData(is,:) = [.4 .5 .0];
         elseif (gData1(is,1) < 0.8) % hi correlation
            b.FaceColor = 'flat';
            b.CData(is,:) = [.6 .7 .3];
         end
      end
      title('Pearson'), grid on
   end
   if ~isempty(gData2)
      subplot(2,1,2)
      x = categorical(indexNames);
      x = reordercats(x,indexNames);
      b = bar(x, gData2, 'b');

      ylabel('R^2')
      xtips2 = b(1).XEndPoints;
      ytips2 = b(1).YEndPoints;
      ata2 = round(b(1).YData,4);
      labels2 = string(ata2);
      text(xtips2,ytips2,labels2,'HorizontalAlignment','center','VerticalAlignment','bottom',...
                                 'FontSize',8,'FontAngle','italic','color','m');
%          xlabel(sXlbl,'FontSize',9);
      ylim([0 1])
      for is=1:size(gData2,1)
         if gData2(is,1) < 0.4 % low correlation
            b.FaceColor = 'flat';
            b.CData(is,:) = [.0 .3 .3];
         elseif (gData2(is,1) < 0.6) % medium correlation
            b.FaceColor = 'flat';
            b.CData(is,:) = [.0 .4 .5];
         elseif (gData2(is,1) < 0.8) % medium correlation
            b.FaceColor = 'flat';
            b.CData(is,:) = [.3 .6 .7];
         end
      end
      title('Spearman')
   end
   grid on, sgtitle(strcat(' Correlations (', pivot, ' & distance metrics)'),'FontSize',12);
catch errg2
   rethrow(errg2);
end % catch
end   

%% displayPerformances
function displayPerformances(tSNR, avNoise, avE, avP, intMethods)
   %% extract data
   nMethod = length(intMethods);
   % extract performance data. rows are methods, cols performances 
   for i=1:nMethod
      method = string(intMethods(i));
      perfData(i,:) = extractfield(avP,method);
   end
   % extract decoding.error data. rows are methods, cols dec.err 
   for i=1:nMethod
      method = string(intMethods(i));
      errData(i,:) = extractfield(avE,method);
   end
   
   % %% display Performance results
   % fprintf("\nNoise Rates:\n");
   % rMsg = strcat("\tMin: ",num2str(min(avNoise),"%.4f"),"\tMax:",num2str(min(avNoise),"%.4f"),"\tAvg:",num2str(mean(avNoise),"%.4f")); fprintf(rMsg);
   % fprintf("\nAverage Decoding Performances WITH Interleaving:");
   % for i=1:nMethod
   %    method = string(intMethods(i));
   %    rMsg = strcat("\n\t", method, ": ", num2str(mean(perfData(i,:)),'%.4f')); fprintf(rMsg);
   % end
   
   %% plot results
   figure, hold on
   subplot(2,1,1), hold on
   for i=1:nMethod
      plot(perfData(i,:));
   end
   title('Decoding Performances'); ylabel('decoding performance');
   legend(intMethods,'Location','northeast','NumColumns',2);
   %
   subplot(2,1,2), hold on
   for i=1:nMethod
      plot(avNoise,perfData(i,:));
   end
   title('Decoding Performances'); xlabel('noise rate'); ylabel('decoding performance');
   legend(intMethods,'Location','southwest','NumColumns',2);
   %
   % subplot(2,1,2), hold on
   % for i=1:nMethod
   %    % plot(perfData(i,:));
   %    plot(avNoise,errData(i,:));
   % end
   % title('Decoding Error Rates'); xlabel('noise rate'); ylabel('err rate');
   % legend(intMethods,'Location','northwest','NumColumns',2);
   %
   % subplot(2,2,3), hold on
   % for i=1:nMethod
   %    plot(tSNR,perfData(i,:));
   % end
   % title('Decoding Performances'); xlabel('SNR'); ylabel('decoding performance');
   % legend(intMethods,'Location','southeast','NumColumns',2);
   % %
   % subplot(2,2,4), hold on
   % for i=1:nMethod
   %    plot(tSNR,errData(i,:));
   % end
   % title('Decoding Error Rates'); xlabel('SNR'); ylabel('err rate');
   % legend(intMethods,'Location','northeast','NumColumns',2);

   % Enable data tips for hovering
   dcm_obj = datacursormode(gcf);
   set(dcm_obj, 'UpdateFcn', @hoverCallbackName);

   %% bar plot Average Performances
   figure
   x = intMethods;
   y = [];
   for i=1:nMethod
      avgPerf = mean(perfData(i,:));
      y = [y avgPerf];
   end
   b = bar(x, y); 
   ylim([0 1]);
   xtips1 = b(1).XEndPoints;
   ytips1 = b(1).YEndPoints;
   labels1 = string(b(1).YData);
   text(xtips1,ytips1,labels1,'HorizontalAlignment','center','VerticalAlignment','bottom', ...
                              'FontSize',8,'FontAngle','italic','color','r'); 
   title('Average Performances')
end

%% displayDistanceStats
function displayDistanceStats(distAll, intMethods)
try
   % extract distance data
   % rows are metrics, cols are methods
   for i=1:length(intMethods)
      dData(:,i) = extractDistanceData_local(distAll,intMethods(i));
   end

   % bar plot
   figure
   subplot(3,4,1); y = dData(1,:); hold on, grid on, title('minMinCW'); 
      x = intMethods; b = bar(x, y); 
   subplot(3,4,5); y = dData(5,:); hold on, grid on, title('avgCW'); 
      x = intMethods; b = bar(x, y); 
   subplot(3,4,9); y = dData(9,:); hold on, grid on, title('avgMinCW'); 
      x = intMethods; b = bar(x, y); 
   subplot(3,4,2); y = dData(2,:); hold on, grid on, title('minAdj'); 
      x = intMethods; b = bar(x, y); 
   subplot(3,4,6); y = dData(6,:); hold on, grid on, title('W'); 
      x = intMethods; b = bar(x, y); 
   subplot(3,4,10); y = dData(10,:); hold on, grid on, title('avgAdj'); 
      x = intMethods; b = bar(x, y); 
   subplot(3,4,3); y = dData(3,:); hold on, grid on, title('minSep'); 
      x = intMethods; b = bar(x, y); 
   subplot(3,4,7); y = dData(7,:); hold on, grid on, title('maxSep'); 
      x = intMethods; b = bar(x, y); 
   subplot(3,4,11); y = dData(11,:); hold on, grid on, title('avgSep'); 
      x = intMethods; b = bar(x, y);    
   subplot(3,4,4); y = dData(4,:); hold on, grid on, title('noiseDistMin'); 
      x = intMethods; b = bar(x, y); 
   subplot(3,4,8); y = dData(8,:); hold on, grid on, title('noiseDistMax'); 
      x = intMethods; b = bar(x, y); 
   subplot(3,4,12); y = dData(12,:); hold on, grid on, title('noiseDistAvg'); 
      x = intMethods; b = bar(x, y);    
   % ylim([0 1]);
   % xtips1 = b(1).XEndPoints; ytips1 = b(1).YEndPoints;
   % labels1 = string(b(1).YData);
   % text(xtips1,ytips1,labels1,'HorizontalAlignment','center','VerticalAlignment','bottom', ...
   %                            'FontSize',8,'FontAngle','italic','color','r'); 

   grid on, sgtitle('Distance Metrics Averages','FontSize',12);
catch errdm
   rethrow(errdm);
end % catch
end

%% extractDistanceData_local
function fData = extractDistanceData_local(distAll, intMethod)
   fData = zeros(length(intMethod),1);
   % Extract indices where method = intMethod
   indices = strcmp(string({distAll.method}), intMethod);
   filteredData = distAll(indices);
   % Extract values 
   fData(1) = mean([filteredData.minMinCW]); % 1
   fData(5) = mean([filteredData.avgCW]);    % 3  
   fData(9) = mean([filteredData.avgMinCW]); % 2 
   fData(2) = mean([filteredData.minAdj]);  % 4
   fData(10) = mean([filteredData.avgAdj]);  % 6
   fData(6) = mean([filteredData.W]);       % 5
   fData(3) = mean([filteredData.minSep]);  % 7
   fData(7) = mean([filteredData.maxSep]);  % 8
   fData(11) = mean([filteredData.avgSep]);  % 9
   fData(4) = mean([filteredData.noiseDistMin]); % 10 
   fData(8) = mean([filteredData.noiseDistMax]); % 11 
   fData(12) = mean([filteredData.noiseDistAvg]); % 12 
end

%% plotNoise
function [] = plotNoise(true_snr, originalData, noisyData, lenCW, lenBurst, numBurst)
   % Plot the change in true SNR graphically
   figure;
   subplot(2, 1, 1);
   % plot(np_values, true_snr, 'b-');
   plot(true_snr, 'b-');
   % xlabel('Desired Noise Power');
   ylabel('True SNR (dB)');
   title('True SNR with error bursts');
   grid on;
   % Add vertical lines to indicate codeword grids
   for i = 1:lenCW:size(originalData, 1)
      hold on;
      plot([i, i], [min(originalData(:)), max(originalData(:))], 'k--');
   end
   %%%
   % Second subplot: Noise (difference between noisy data and original data)
   subplot(2, 1, 2);
   % Generate the linear indices for the data
   linearIndices = 1:length(originalData);
   noise = noisyData - originalData;
   plot(linearIndices, noise, 'r.-', 'LineWidth', 1.5);
   
   xlabel('error bursts vs. codewords');
   ylabel('Noise Value');
   ttl = strcat('Final noise with error bursts (L:', num2str(lenCW), ' - burstSize:',  num2str(lenBurst), ' - burstCount:',  num2str(numBurst), ')');
   title(ttl);
   grid on;
   
   % Add vertical lines to indicate codeword grids
   for i = 1:lenCW:length(originalData)
      hold on;
      plot([i, i], [min(noise(:)), max(noise(:))], 'k--');
   end
   % plot(noise, 'k--');

   sgtitle(strcat(' Noise with Error Bursts'),'FontSize',12);
   hold off;
end

%% distNoisePositions
function [noiseLocations, noiseDistances] = distNoisePositions(noiseLocationsNdx)
% takes a logical array logicalArray and 
% returns the positions of 1s and the sequential distances between them
   % Find positions of 1s in the logical array
   noiseLocations = find(noiseLocationsNdx);

   % Calculate sequential distances between 1s
   noiseDistances = diff(noiseLocations);
   
   % % Display the results
   % disp('Positions of 1s:');
   % disp(positions);
   % 
   % disp('Sequential distances between 1s:');
   % disp(distances);
end