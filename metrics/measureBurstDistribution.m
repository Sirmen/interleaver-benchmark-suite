function [burstDistStats, erM] = measureBurstDistribution(...
    noiseLocations, permutation, eccConfig, numCodewords, encodedLen)
% MEASUREBURSTDISTRIBUTION with CORRECT ECC codeword length
%
% Inputs:
%   noiseLocations - logical array of error positions
%   permutation - interleaver permutation
%   eccConfig - ECC configuration struct (n, k, t_correct)
%   numCodewords - number of ECC codewords (= ceil(N/k))
%   encodedLen - total encoded length
erM = ""; burstDistStats = struct();
try
   % 1. Before interleaving
   [beforeStats, erM] = analyzeBurstDistribution(...
       noiseLocations, eccConfig.n, numCodewords, encodedLen, 'before');
   if erM ~= ""; return; end
   
   % 2. After interleaving (de-interleaved positions)
   N = length(permutation);
   permutedNoiseLocations = false(1, N);
   errorIndices = find(noiseLocations);
   if ~isempty(errorIndices)
      permutedNoiseLocations(permutation(errorIndices)) = true;
   end
   
   [afterStats, erM] = analyzeBurstDistribution(...
      permutedNoiseLocations, eccConfig.n, numCodewords, encodedLen, 'after');
   if erM ~= ""; return; end
   
   % 3. Calculate efficiency (eccConfig.t_correct)
   [efficiencyMetrics, erM] = calcDistributionEfficiency(...
      beforeStats, afterStats, eccConfig, numCodewords);
   if erM ~= ""; return; end
   
   % 4. Extract all metrics (same as before)
   burstDistStats.eccAwareScore = efficiencyMetrics.eccAwareScore;
   burstDistStats.overallScore = efficiencyMetrics.overallScore;
   burstDistStats.eccViolationReduction = efficiencyMetrics.eccViolationReduction;
   
   burstDistStats.before_eccMargin_min = efficiencyMetrics.before_eccMargin_min;
   burstDistStats.after_eccMargin_min = efficiencyMetrics.after_eccMargin_min;
   burstDistStats.before_eccMargin_avg = efficiencyMetrics.before_eccMargin_avg;
   burstDistStats.after_eccMargin_avg = efficiencyMetrics.after_eccMargin_avg;
   
   burstDistStats.before_eccViolations = efficiencyMetrics.before_eccViolations;
   burstDistStats.after_eccViolations = efficiencyMetrics.after_eccViolations;
   
   burstDistStats.before_eccUtilization = efficiencyMetrics.before_eccUtilization;
   burstDistStats.after_eccUtilization = efficiencyMetrics.after_eccUtilization;
   
   burstDistStats.before_noisyPointsPerBlock_max = beforeStats.noisyPointsPerBlock_max;
   burstDistStats.S_ECC_norm = afterStats.noisyPointsPerBlock_max;
   burstDistStats.after_noisyPointsPerBlock_avg = afterStats.noisyPointsPerBlock_avg;
   
   burstDistStats.after_blockOccupancyRatio = afterStats.blockOccupancyRatio;
   
   burstDistStats.before_gini = efficiencyMetrics.before_gini;
   burstDistStats.after_gini = efficiencyMetrics.after_gini;
   burstDistStats.delta_G = efficiencyMetrics.delta_G;
   
   burstDistStats.eccComplianceImprovement = efficiencyMetrics.eccComplianceImprovement;
   burstDistStats.distributionUniformityImprovement = efficiencyMetrics.distributionUniformityImprovement;
   burstDistStats.varianceReduction = efficiencyMetrics.varianceReduction;

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end