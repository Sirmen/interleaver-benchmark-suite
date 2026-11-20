function [stats, erM] = collectStatistics_x(config, method, A, L, K, encodedLen, noiseBin, ...
                                            permutation, interleaved, decoded, ...
                                            burstConfig, noiseLocations, decErrRate_woInt, ...
                                            gridL, gridK)
%COLLECTSTATISTICS_X  Per-trial statistics for one method.
%
% L AND K ARE NOT THIS METHOD'S GRID. They are paramsInt.L and paramsInt.K,
% which run_simulations_sci sets from estimate_L_for_size(lenEncoded) once per
% trial, so they are IDENTICAL for every method and describe none of them.
% They are kept under those names because things downstream read them.
%
% gridL and gridK, added 6 November 2026, ARE this method's grid, taken from
% paramsInt.gridLK.(method) which interleave_all_pc now records beside the
% permutation. They are NaN for runs made before that date, and NaN is the
% right answer there - the grid was never recorded, and borrowing paramsInt.L
% would put a wrong number under a right-looking name.
erM = ""; stats = [];
if nargin < 14, gridL = NaN; end
if nargin < 15, gridK = NaN; end
try
   excludeZero = true;
   N = length(A);
   
   % THE DELIVERED CODE, SHORTENING INCLUDED (fix 18 Nov 2026). Without
   % config.FECnShort this derived the MOTHER code: for the shortened
   % RS(24,16) it returned n = 31, t = 5, so every a posteriori metric that
   % partitions the frame into codewords (Delta_G, eta_ES, Delta_BS, S_ECC,
   % U_ECC, V_ECC, S_sf) was computed on 31-symbol words while the decoder
   % used 24. Natural codes (FECnShort empty) are unchanged.
   nShortCS = [];
   if isfield(config, 'FECnShort'), nShortCS = config.FECnShort; end
   eccConfig = configure_FEC_parameters(config.base, config.eccMin, nShortCS);
   if isfield(config, 'FECn') && eccConfig.n ~= config.FECn
      error('collectStatistics_x: metric code n = %d, simulated code n = %d.', eccConfig.n, config.FECn);
   end
   t = eccConfig.t_correct; % Maximum correction capacity per block [cite: 128]
   tau = eccConfig.eccReal; % Normalized capacity [cite: 128]

   noiseCount = sum(noiseLocations);
   noiseRatio = noiseCount / length(interleaved);   
   [~, decodeErrRate] = symerr(A, decoded(1:N)); 
   
   % Standard Setup
   stats.method = method; 
   stats.L = L;  stats.K = K;  stats.N = N; stats.encodedLen = encodedLen;   
   % the grid THIS method chose; see the header on why it is not L and K
   stats.gridL = gridL;  stats.gridK = gridK;
   stats.interleavedLen = length(permutation);   
   stats.permutation = permutation;
   stats.noiseBin = noiseBin; % append noiseBin id
   stats.noiseActual = noiseRatio; 
   stats.noiseLocations = noiseLocations;
   stats.decErrRate_woInt = decErrRate_woInt; 
   stats.decodeErrRate = decodeErrRate; 

   stats.burstConfig = burstConfig;
   stats.eccConfig = eccConfig; 
   
   %%% 1. ECC-AWARE & BURST DISTRIBUTION
   codewordLength = eccConfig.n;
   lenPerm = length(permutation);
   numCodewords = ceil(lenPerm / codewordLength);
   [spreadingMetrics, errorsPerBlock] = calcErrorSpreadingMetrics(...
       noiseLocations, permutation, codewordLength);
   
   % Error Spreading Efficiency (eta_ES): Spatial utilization of the frame [cite: 145, 148]
   stats.eta_ES = spreadingMetrics.errorSpreadingEfficiency;
   
   % Burst Spreading Diversity (delta_BS): Uniformity of error load [cite: 150, 154]
   stats.delta_BS = spreadingMetrics.burstSpreadingDiversity;
   
   % ECC Sustainability Score (S_ECC): (Current Margin / Total Capacity). 
   % True Safety Margin: 1.0 = Perfect, 0 = Limit, <0 = Failure. [cite: 158, 163]
   [statsECC, erM] = calcECCStats(codewordLength, t, permutation, noiseLocations);
   if (erM ~= ""); return; end
   % S_ECC: (Current Margin / Total Capacity). True Safety Margin: 1.0 = Perfect, 0 = Limit, <0 = Failure.
   stats.S_ECC = statsECC.S_ECC; 
   stats.S_ECC_norm = statsECC.S_ECC_norm; % normalized S_ECC
   % eccViolations: Number of blocks that actually failed the RS decoder
   stats.V_ECC = statsECC.V_ECC; 
   % eccUtilization: Average fraction of t-capacity used across all codewords
   stats.U_ECC = statsECC.U_ECC; 
   
   % Source Separation Factor
   [S_sf, S_sf_avg, erM] = calcSourceSeparationFactor(permutation, codewordLength);
   if (erM ~= ""); return; end
   stats.S_sf = S_sf;
   stats.S_sf_avg = S_sf_avg;

   %%% 2. PERMUTATION QUALITY (Legacy Compatibility Maintained)
   % Separation Metrics [cite: 177]
   % S-Factor: Minimum 2D Euclidean distance between symbol mappings. defines "forbidden zone" for symbol clustering   
   stats.S_factor = calc_spread_factor_invperm(permutation);
   % eta_sep: Fraction of theoretical max global separation [cite: 178, 179]
   [stats.sepMin, ~, stats.sepAvg, ~, ~, stats.eta_sep, stats.sepCV, stats.separations, erM] = ...
        intraVectorSeparations(permutation, excludeZero);
   if (erM ~= ""); erM = strcat("Error in collectStatistics_x:", erM); return; end

   % Adjacency & Block Metrics [cite: 170]
   % adjMin: Worst-case distance for originally sequential symbols [cite: 174, 175]
   % MinminBlock: Worst-case original index proximity in a codeword [cite: 164, 169]
   [adjMin, adjAvg, adjCV, erM] = calcAdjDist(permutation);
   if (erM ~= ""); erM = strcat("Error in collectStatistics_x:", erM); return; end
   stats.adjMin = adjMin;
   stats.adjAvg = adjAvg;
   stats.CV_adj = adjCV;
   stats.adjCV  = adjCV;   % configure_simulation.m intMetrics listesi 'adjCV' bekliyor

   % Spectral & Complexity [cite: 184]
   % PSR: Peak-to-Sidelobe Ratio; measures spectral aperiodicity [cite: 186, 188]
   spectral = analyzeSpectralProperties(permutation);
   stats.PSR = spectral.PSR; 
   % Laplacian Energy (LE): Structural complexity measure [cite: 195, 196]
   stats.laplacianEnergy = calcLaplacianEnergy(permutation); 
   
   % Gini Improvement (delta_G): Clustering to uniformity transition [cite: 192, 193]
   [burstDistStats, erM] = measureBurstDistribution(noiseLocations, permutation, eccConfig, numCodewords, encodedLen);
   if (erM ~= ""); erM = strcat("collectStatistics_x/measureBurstDistribution: ", erM); return; end
   stats.delta_G = burstDistStats.delta_G;

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   stats = []; 
end
end