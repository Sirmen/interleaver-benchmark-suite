function [efficiency, erM] = calcDistributionEfficiency(...
    beforeStats, afterStats, eccConfig, numCodewords, useAdaptiveWeights)
% Calculate efficiency metrics with CORRECT ECC parameters
%
% Inputs:
%   beforeStats, afterStats - burst distribution stats
%   eccConfig - ECC configuration struct (n, k, t_correct)
%   numCodewords - number of ECC codewords
%   useAdaptiveWeights - optional adaptive weighting

erM = ""; efficiency = struct();
try    
   if nargin < 5
      useAdaptiveWeights = false;
   end
   
   efficiency.before = beforeStats;
   efficiency.after = afterStats;
   
   % ECC parameters
   t_correct = eccConfig.t_correct;  % Correctable symbols per codeword
   efficiency.eccCapacityPerBlock = t_correct;
   efficiency.eccConfig = eccConfig;
   
   % Get noisy points per block arrays
   beforeNoisy = beforeStats.noisyPointsPerBlock;
   afterNoisy = afterStats.noisyPointsPerBlock;
   totalBlocks = numCodewords;
   
   % ECC capability analysis (USING CORRECT t_correct)
   efficiency.before_eccViolations = sum(beforeNoisy > t_correct);
   efficiency.after_eccViolations = sum(afterNoisy > t_correct);
   efficiency.eccViolationReduction = efficiency.before_eccViolations - efficiency.after_eccViolations;
   
   % Compliance ratios
   efficiency.before_eccComplianceRatio = sum(beforeNoisy <= t_correct) / totalBlocks;
   efficiency.after_eccComplianceRatio = sum(afterNoisy <= t_correct) / totalBlocks;
   efficiency.eccComplianceImprovement = efficiency.after_eccComplianceRatio - efficiency.before_eccComplianceRatio;
   
   % ECC margin analysis
   efficiency.before_eccMargin_avg = t_correct - beforeStats.noisyPointsPerBlock_avg;
   efficiency.after_eccMargin_avg = t_correct - afterStats.noisyPointsPerBlock_avg;
   efficiency.before_eccMargin_min = t_correct - beforeStats.noisyPointsPerBlock_max;
   efficiency.after_eccMargin_min = t_correct - afterStats.noisyPointsPerBlock_max;
   
   % ECC utilization
   if t_correct == 0
      efficiency.before_eccUtilization = 0;
      efficiency.after_eccUtilization = 0;
   else
      efficiency.before_eccUtilization = min(1, beforeStats.noisyPointsPerBlock_avg / t_correct);
      efficiency.after_eccUtilization = min(1, afterStats.noisyPointsPerBlock_avg / t_correct);
   end
   
   % ... rest of the function remains the same ...
   % (Gini, normalization, scoring, etc.)
   
   % Correctable blocks ratio
   if beforeStats.noisyBlocksCount == 0
      efficiency.before_correctableBlocksRatio = 1;
   else
      efficiency.before_correctableBlocksRatio = sum(beforeNoisy <= t_correct & beforeNoisy > 0) / beforeStats.noisyBlocksCount;
   end
   
   if afterStats.noisyBlocksCount == 0
      efficiency.after_correctableBlocksRatio = 1;
   else
      efficiency.after_correctableBlocksRatio = sum(afterNoisy <= t_correct & afterNoisy > 0) / afterStats.noisyBlocksCount;
   end
   
   % Improvement metrics
   efficiency.blockOccupancyImprovement = afterStats.blockOccupancyRatio - beforeStats.blockOccupancyRatio;
   efficiency.distributionUniformityImprovement = afterStats.distributionUniformity - beforeStats.distributionUniformity;
   efficiency.varianceReduction = beforeStats.noisyPointsPerBlock_var - afterStats.noisyPointsPerBlock_var;
   efficiency.standardDeviationReduction = beforeStats.noisyPointsPerBlock_std - afterStats.noisyPointsPerBlock_std;
   
   maxPossibleConcentration = max(beforeStats.noisyPointsPerBlock_max, afterStats.noisyPointsPerBlock_max);
   if maxPossibleConcentration > 0
      efficiency.maxConcentrationReduction_normalized = (beforeStats.noisyPointsPerBlock_max - afterStats.noisyPointsPerBlock_max) / maxPossibleConcentration;
   else
      efficiency.maxConcentrationReduction_normalized = 0;
   end
   efficiency.maxConcentrationReduction = beforeStats.noisyPointsPerBlock_max - afterStats.noisyPointsPerBlock_max;
   
   % Normalize improvements
   if t_correct == 0
      marginImprovement = 0;
   else
      marginImprovement = max(0, min(1, (efficiency.after_eccMargin_min - efficiency.before_eccMargin_min) / t_correct));
   end
   
   concentrationImprovement = max(0, min(1, efficiency.maxConcentrationReduction_normalized));
   complianceImprovement = max(0, min(1, efficiency.eccComplianceImprovement));
   uniformityImprovement = max(0, min(1, efficiency.distributionUniformityImprovement));
   occupancyImprovement = max(0, min(1, efficiency.blockOccupancyImprovement));
   
   efficiency.normalizedImprovements.margin = marginImprovement;
   efficiency.normalizedImprovements.concentration = concentrationImprovement;
   efficiency.normalizedImprovements.compliance = complianceImprovement;
   efficiency.normalizedImprovements.uniformity = uniformityImprovement;
   efficiency.normalizedImprovements.occupancy = occupancyImprovement;
   
   % Weights
   if useAdaptiveWeights
      weights = adaptiveWeights(t_correct, beforeStats.totalNoisyPoints, beforeNoisy, afterNoisy);
   else
      weights.compliance = 0.35;
      weights.margin = 0.25;
      weights.uniformity = 0.25;
      weights.concentration = 0.15;
   end
    
   efficiency.eccAwareScore = weights.compliance * complianceImprovement + ...
                              weights.margin * marginImprovement + ...
                              weights.uniformity * uniformityImprovement + ...
                              weights.concentration * concentrationImprovement;
   
   efficiency.weightsUsed = weights;
   efficiency.overallScore = 0.4 * uniformityImprovement + ...
                             0.3 * occupancyImprovement + ...
                             0.3 * concentrationImprovement;
    
   if beforeStats.noisyBlocksCount > 0
      efficiency.burstSpreadingEffectiveness = min(1, afterStats.noisyBlocksCount / beforeStats.noisyBlocksCount);
   else
      efficiency.burstSpreadingEffectiveness = 1;
   end
   
   efficiency.before_gini = calcGiniCoefficient(beforeNoisy);
   efficiency.after_gini = calcGiniCoefficient(afterNoisy);
   efficiency.delta_G = max(0, min(1, efficiency.before_gini - efficiency.after_gini));
   
   efficiency.eccSustainability = assessECCSustainability(beforeStats, afterStats, t_correct);
   
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end