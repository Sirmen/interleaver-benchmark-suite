function [stats, erM] = analyzeBurstDistribution(...
    noiseLocations, codewordLength, numCodewords, encodedLen, phase)
% Analyze burst distribution with CORRECT ECC message block size
%
% Inputs:
%   noiseLocations - logical array of errors
%   codewordLength - RS CODEWORD length n (symbols per codeword), i.e. eccConfig.n
%                    (callers pass eccConfig.n; the old name said k, which was wrong)
%   numCodewords - number of ECC codewords
%   encodedLen - total encoded length
%   phase - 'before' or 'after' interleaving

erM = "";
stats = struct();
try
   stats.phase = phase;
   stats.totalNoisyPoints = sum(noiseLocations);
   
   if stats.totalNoisyPoints == 0
       stats.noisyBlocksCount = 0;
       stats.noisyPointsPerBlock_min = 0;
       stats.noisyPointsPerBlock_max = 0;
       stats.noisyPointsPerBlock_avg = 0;
       stats.noisyPointsPerBlock_var = 0;
       stats.noisyPointsPerBlock_std = 0;
       stats.blockOccupancyRatio = 0;
       stats.distributionUniformity = 1;
       stats.noisyPointsPerBlock = zeros(1, numCodewords);
       return;
   end
   
   % Initialize: one entry per ECC codeword
   noisyPointsPerBlock = zeros(1, numCodewords);
   
   % Count noisy points per codeword 
   errorIndices = find(noiseLocations);
   for idx = 1:length(errorIndices)
       pos = errorIndices(idx);
       if pos > 0 && pos <= encodedLen
           % Which codeword does this symbol belong to?
           % % % codewordIdx = ceil(pos / messageLength);
           codewordIdx = ceil(pos / codewordLength); 
           if codewordIdx <= numCodewords
               noisyPointsPerBlock(codewordIdx) = noisyPointsPerBlock(codewordIdx) + 1;
           end
       end
   end

   % Calculate statistics
   stats.noisyPointsPerBlock = noisyPointsPerBlock;
   stats.noisyBlocksCount = sum(noisyPointsPerBlock > 0);
   
   noisyBlocks = noisyPointsPerBlock(noisyPointsPerBlock > 0);
   if ~isempty(noisyBlocks)
       stats.noisyPointsPerBlock_min = min(noisyBlocks);
   else
       stats.noisyPointsPerBlock_min = 0;
   end
   
   stats.noisyPointsPerBlock_max = max(noisyPointsPerBlock);
   stats.noisyPointsPerBlock_avg = mean(noisyPointsPerBlock);
   stats.noisyPointsPerBlock_var = var(noisyPointsPerBlock);
   stats.noisyPointsPerBlock_std = std(noisyPointsPerBlock);
   
   stats.blockOccupancyRatio = stats.noisyBlocksCount / numCodewords;
   
   expectedNoisyPerBlock = stats.totalNoisyPoints / numCodewords;
   stats.distributionUniformity = 1 / (1 + (stats.noisyPointsPerBlock_var / (expectedNoisyPerBlock^2 + eps)));
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end
