function [vectorInterleaved, permutation, L, K, erM] = interleaver_latinSquare(vectorIn, maxExtensionPercentage)
% R.Tanju Sirmen - 2024
%INTERLEAVER_LATINSQUARE  Latin-square interleaver.
%   Pads the frame to the next perfect square K^2, permutes using a Latin
%   square of order K, then keeps only the positions that map inside the
%   original N - so the OUTPUT IS EXACTLY N SYMBOLS LONG and no padding is
%   transmitted.
%
%   CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% NOTE ON THE EXTENSION GUARD (2026) - kept, but understand what it does.
% ---------------------------------------------------------------------------
% The guard below rejects the frame when K^2 overshoots N by more than
% maxExtensionPercentage. But K^2 is an INTERNAL working length: the
% validIndices step removes every padded position afterwards, and because the
% Latin-square map is a bijection on 1..K^2, exactly N positions survive. The
% transmitted length is always N - this method never costs the channel a single
% extra symbol, and its bandwidth efficiency BE is 1.0 regardless of what the
% guard is set to.
%
% So the guard bounds MEMORY AND BUILD COST, not rate. It is retained because a
% large K^2/N ratio is real work for no benefit, and because removing it would
% silently change which N the sweep reports for this method (lengths just above
% a perfect square currently drop out). Do not present this guard in the paper
% as a rate penalty - it is not one. Contrast with `matrix`, `spiral` and
% `helical`, where the padding IS transmitted and BE < 1.
try
   erM = ""; vectorInterleaved = []; permutation = []; L=0; K=0;
   
   % control & correct shape of data to be 1xN
   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed 
      erM = strcat("interleaver_latinSquare: Data shape error: (", num2str(size(vectorIn)), ") Must be (1xN)");
      error(erM)
   end

   N = length(vectorIn);
   
   % Find smallest square matrix that can contain the data
   K = ceil(sqrt(N));
   paddedLength = K^2;
   
   if paddedLength > (N * (1+maxExtensionPercentage))
      % Bounds the internal K^2 working buffer, NOT the transmitted length -
      % see the header note. Transmitted length is always exactly N.
      erM = strcat("interleaver_latinSquare: Size-adjusted-N error: (", num2str(N), ")");
      return
   end
   
   L = paddedLength/K;
   
   % % Pad with NaN values (will be removed later)
   % vectorInPadded = [vectorIn, NaN(1, paddedLength - N)];
   % Pad with 0 values (will be removed later)
   vectorInPadded = [vectorIn, zeros(1, paddedLength - N)];
   
   % Create Latin square
   latinSquare = createLatinSquare(K, 1);
   
   % Generate permutation from Latin square (column-major order)
   permutation = zeros(1, paddedLength);
   for col = 1:K
      for row = 1:K
         originalPos = (col-1)*K + row;
         newPos = (row-1)*K + latinSquare(row,col);
         permutation(originalPos) = newPos;
      end
   end
   
   % Apply permutation to padded data
   vectorInterleavedPadded = vectorInPadded(permutation);
   
   % Remove padding (keep only original data positions)
   % Keep only the positions whose source index falls inside the original N.
   % Since permutation is a bijection on 1..K^2, exactly N of them do, and the
   % surviving values form a permutation of 1..N.
   validIndices = permutation <= N;
   vectorInterleaved = vectorInterleavedPadded(validIndices);
   permutation = permutation(validIndices);

   if ~isUnique(permutation)
      erM = strcat('\tLatin Square Interleaving Permutation Error:\n', num2str(unique(permutation))," N:",num2str(N));
      return
   end
    
   % Ensure outputs are row vectors
   if iscolumn(vectorInterleaved)
      vectorInterleaved = vectorInterleaved';
   end
   if iscolumn(permutation)
      permutation = permutation';
   end

catch ME
   erM = sprintf('%s Line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end % catch
end