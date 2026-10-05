function [noisyPointsSorted, noisyPointDistances_normalized] = checkNoisePositions(noiseLocations, permutation)
% returns: 
%     noisyPointsSorted: sorted noisy positions in the original message (may be spread after interleaving)
%     noisyPointDistances_normalized: the sequential distances between noisyPoints
%        (err.burst, so, distance between noisy points in interleaved msg is 1)
% inputs:
%     noiseLocation: actual noisy positions in the received (i.e. interleaved & noised) message
%     permutation: relates the original and interleaved message

   % Transform noisy locations to original locations before interleaving
   noisePositionIndices = noiseLocations == 1;
   noisePositions = permutation(noisePositionIndices);
   
   noisePositionsAdjusted = noisePositions(noisePositions ~= 0);
   
   % sort Noisy points
   noisyPointsSorted = sort(noisePositionsAdjusted);
   
   % Calculate sequential distances between noisy points in terms of original locations
   if length(noisyPointsSorted) > 1
      noisyPointDistances = diff(noisyPointsSorted);
      % Normalize
      noisyPointDistances_normalized = noisyPointDistances / (length(permutation) - 1);
   else
      noisyPointsSorted = [];
      noisyPointDistances_normalized = [];
   end
end
