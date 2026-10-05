function [S_sf, S_sf_avg, erM] = calcSourceSeparationFactor(permutation, n)
%   The Source Separation Factor (S_sf) quantifies the source-domain diversity
%   maintained within each interleaved codeword. It identifies the "weakest link" 
%   in the decoder's window by measuring the minimum normalized distance between 
%   the original ordinal positions of any two symbols that occupy the same 
%   interleaved codeword.
%
%   S_sf = min( min( |s_a - s_b| / n ) )
%
%   Thresholds & Interpretation:
%     <= 1/n : Fragility Limit (Cluster Collision). Original neighbors (e.g., k 
%              and k+1) are forced into the same codeword. High vulnerability
%              to block-aligned bursts.
%        1.0 : Baseline Block Diversity. Every symbol in the codeword comes 
%              from a different source block (distance >= n).
%     >  1.0 : Optimal Dispersion. Symbols are staggered from widely separated 
%              source contexts.
%   
%   Inputs:
%       permutation : 1xN vector containing original indices 1:N
%       n           : Codeword length (e.g., n=255 for RS(255,239))
%
%   Outputs:
%       S_sf        : Global minimum source separation factor (the metric).
%       S_sf_avg    : Average minimum separation across all codewords.
%       erM         : Error message string (empty if successful).

% Initialize outputs
erM = "";
S_sf = NaN; S_sf_avg = NaN; 
try
   N = length(permutation);
   
   % 1. Determine number of full codewords
   numCWs = floor(N / n);
   if numCWs < 1
      error('Permutation length (%d) is shorter than codeword length (%d).', N, n);
   end
   
   % 2. Focus only on the full codewords (truncate leftovers)
   validLen = numCWs * n;
   data = double(permutation(1:validLen));
   
   % 3. Reshape into codewords
   % Reshape fills column-wise, so each column represents one codeword
   cwMatrix = reshape(data, n, numCWs);
   
   % 4. Sort each codeword (Column-wise sort)
   % Sorting the original indices allows us to find the minimum pairwise
   % distance by checking only adjacent elements in the sorted list.
   sortedCWs = sort(cwMatrix, 1);
   
   % 5. Calculate normalized distances between adjacent sorted symbols
   % Division by n normalizes the metric (1.0 = one block width).
   distMatrix = diff(sortedCWs, 1, 1) / n;
   
   % 6. Find the minimum distance for each codeword (local weakness)
   minDistsPerBlock = min(distMatrix, [], 1);
   
   % 7. Compute Global Metrics
   S_sf = min(minDistsPerBlock);      % The single weakest link in the file
   S_sf_avg = mean(minDistsPerBlock); % Average protection level

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   rethrow(erM);
end
end
