function [metrics, errorsPerBlock] = calcErrorSpreadingMetrics(...
    noiseLocations, permutation, codewordLength)
% Error spreading metrics using CORRECT ECC codeword structure
%
% Inputs:
%   noiseLocations - logical array of errors
%   permutation - interleaver permutation
%   codewordLength - RS message length (k symbols)
%   numCodewords - number of ECC codewords

   N = length(permutation);
   
   numCodewords = ceil(N / codewordLength);

   % Map errors to de-interleaved positions
   permutedNoiseLocations = false(1, N);
   errorIndices = find(noiseLocations);
   
   if ~isempty(errorIndices)
      for i = 1:length(errorIndices)
         permutedNoiseLocations(permutation(errorIndices(i))) = true;
      end
   end
   
   totalErrors = sum(permutedNoiseLocations);
   metrics.totalErrors = totalErrors;
   errorsPerBlock = zeros(1, numCodewords);
   
   if totalErrors == 0
      metrics.blockOccupancyRatio = 0;
      metrics.errorSpreadingEfficiency = 1.0;
      metrics.burstSpreadingDiversity = 1.0;
      metrics.noisyBlocksCount = 0;
      return; 
   end
   
   % Calculate error counts per codeword
   for k = 1:numCodewords
      idxStart = (k - 1) * codewordLength + 1;
      idxEnd = min(k * codewordLength, N);
      errorsPerBlock(k) = sum(permutedNoiseLocations(idxStart:idxEnd));
   end
   
   % Block occupancy
   noisyBlocks = (errorsPerBlock > 0);
   metrics.noisyBlocksCount = sum(noisyBlocks);
   metrics.blockOccupancyRatio = metrics.noisyBlocksCount / numCodewords;
   
   % Error spreading efficiency
   theoreticalMaxAffectedBlocks = min(numCodewords, totalErrors);
   if theoreticalMaxAffectedBlocks == 0
      metrics.errorSpreadingEfficiency = 1.0;
   else
      metrics.errorSpreadingEfficiency = metrics.noisyBlocksCount / theoreticalMaxAffectedBlocks;
   end
   
   % Burst spreading diversity
   noisyBlockErrors = errorsPerBlock(noisyBlocks);
   
   if metrics.noisyBlocksCount <= 1
      metrics.burstSpreadingDiversity = 1.0; 
   else
      mu = mean(noisyBlockErrors);
      sigma = std(noisyBlockErrors);
      CV = sigma / mu;
      metrics.burstSpreadingDiversity = 1 / (1 + CV);
   end
end
