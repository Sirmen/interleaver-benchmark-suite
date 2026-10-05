function [vectorInterleaved, permutation, erM] = interleaver_block(vectorIn, block_size, pad_symbol, maxExtensionPercentage)
% R.Tanju Sirmen - 2023
% BLOCK INTERLEAVER - writes row-wise into a matrix, reads column-wise.
%
% Inputs:
%   vectorIn    - Input data (1xN)
%   block_size  - ROW LENGTH of the interleaver matrix, i.e. the number of
%                 COLUMNS. The matrix built below is num_blocks x block_size.
%   pad_symbol  - Symbol used for padding
%   maxExtensionPercentage - largest tolerated padding, as a fraction of N
%
% Outputs:
%   vectorInterleaved - Interleaved data
%   permutation       - Permutation indices (GATHER: out = in(permutation))
%   erM               - Error message ("" if success)
%
% DOCUMENTATION CORRECTED 2026 - the algorithm was and is correct; the header
% was not. It said block_size is "the number of rows". It is not. The line
%
%       matrix = reshape(inData_padded, block_size, num_blocks)'
%
% reshapes COLUMN-major into block_size x num_blocks and then TRANSPOSES, so
% the working matrix is num_blocks rows by block_size columns, written row-wise
% with consecutive data. block_size is therefore the row length. This matters
% because the caller picks block_size to control burst dispersion: reading
% column-wise separates neighbours by exactly block_size positions, so
% block_size is the guaranteed adjacent separation - a quantity that would be
% num_blocks if the old header were right. Anyone tuning against the old
% description tuned the wrong axis.
%
% SEPARATION: adjacent input symbols land block_size apart, uniformly. There
% is no adj_min = 1 pathology here, unlike helicalScan and spiral.
%
try
   erM = ""; 
   vectorInterleaved = []; 
   permutation = [];
   
   % Ensure input is row vector
   if iscolumn(vectorIn)
      vectorIn = vectorIn';
   elseif ~isvector(vectorIn)
      erM = strcat("interleaver_block: Data shape error: (", num2str(size(vectorIn)), ") Must be (1xN)");
      return
   end
   
   N = length(vectorIn);

   num_blocks = ceil(N / block_size);

   if (num_blocks * block_size) > (N * (1+maxExtensionPercentage))
      erM = strcat("interleaver_block: Size-adjusted-N error: (", num2str(N), ")");
      return
   end
   
   % Pad data to fill the matrix
   padding = pad_symbol * ones(1, num_blocks * block_size - N);
   inData_padded = [vectorIn, padding];
   
   % Working matrix: num_blocks rows x block_size columns, filled row-wise.
   % (`matrix` itself is never read - the permutation is built from indices
   %  below and applied to inData_padded directly. Kept only as documentation
   %  of the layout; delete it if you want the two lines of memory back.)
   matrix = reshape(inData_padded, block_size, num_blocks)';                 %#ok<NASGU>

   % Read column-wise: perm_matrix(:) walks down column 1, then column 2, ...
   % so consecutive OUTPUT positions come from input positions block_size apart.
   perm_matrix = reshape(1:(num_blocks*block_size), block_size, num_blocks)';
   permutation = perm_matrix(:)';

   % Permutation validation. NOTE: this branch is unreachable by construction -
   % perm_matrix holds 1..num_blocks*block_size exactly once, and reshape and
   % transpose are bijections, so permutation is always a permutation. Retained
   % as a tripwire in case the construction above is ever edited.
   if ~isUnique(permutation)
      erM = strcat('interleaver_block: Permutation Error:\n', num2str(unique(permutation)')," N:",num2str(N));
      return
   end
   
   % Apply permutation
   vectorInterleaved = inData_padded(permutation);

   % Ensure input is a vector
   if iscolumn(vectorInterleaved); vectorInterleaved = vectorInterleaved'; end
   if iscolumn(permutation);       permutation = permutation';             end
    
catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end