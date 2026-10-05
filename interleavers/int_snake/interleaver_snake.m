function [vectorInterleaved, permutation, L, K, erM] = ...
    interleaver_snake(vectorIn, padSymbol, maxExtensionPercentage, table_primes, table_factors)
%INTERLEAVER_SNAKE  Boustrophedon ("snake") block interleaver.
%
%   Write column-wise into a K x L matrix, read row-wise, reversing every
%   even row:
%
%       pi((r-1)*L + m) = (m-1)*K + r        r odd
%                       = (L-m)*K + r        r even
%
% RENAMED FROM interleaver_cross - AND WHY
% ----------------------------------------
% The file used to be called `cross` and its header claimed:
%
%     % CROSS INTERLEAVER (canonical zigzag / snake interleaver)
%     % Literature definition:
%     %   - Write data column-wise into a KxL matrix
%     %   - Read data row-wise, reversing every even row (snake pattern)
%
% There is no such literature definition. In coding theory the CROSS
% interleaver is the Ramsey/Forney CONVOLUTIONAL interleaver with staggered
% delay lines - the one used in CIRC (cross-interleaved Reed-Solomon coding,
% IEC 60908) and in DVB. It is not a block interleaver at all. What this file
% implements is a boustrophedon (snake) block interleaver: a different object,
% with its own (modest) literature, and it must be named and cited as such.
%
% HONEST NOTE ON ITS WORST CASE
% The row reversal is the defining feature of the method, and it is also the
% sole cause of its worst case: the last element of an odd row and the first
% element of the next row are CONSECUTIVE input indices, so
%
%       min_j |pi^-1(j+1) - pi^-1(j)| = 1
%
% for every N (measured over 30..510, with exactly K-1 such adjacent pairs per
% frame). Without the reversal this would be a plain transpose interleaver
% with min adjacency K - i.e. the "snake" feature strictly costs worst-case
% dispersion. That is a property of the method, not a defect to be patched
% away: report it. It is a clean illustration of the paper's own thesis that
% mean separation and worst-case adjacency are different quantities.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% R.T. Sirmen harness, renamed and corrected 2026

   erM = ""; vectorInterleaved = []; permutation = []; L = 0; K = 0;
   try
      if nargin < 2 || isempty(padSymbol), padSymbol = 0; end
      if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.1; end
      if nargin < 4, table_primes = []; end
      if nargin < 5, table_factors = struct(); end

      [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
      if failed
         erM = "interleaver_snake: Data shape error. Must be (1xN)"; return;
      end
      N0 = length(vectorIn);
      if N0 < 6, erM = "interleaver_snake: N must be >= 6"; return; end

      % Near-square factorisation; one symbol of padding for prime lengths.
      N = N0;
      [K, L] = local_split(N);
      if K < 2
         N = N0 + 1;
         if N > floor(N0 * (1 + maxExtensionPercentage))
            erM = sprintf('interleaver_snake: padding to %d exceeds maxExtensionPercentage', N);
            return;
         end
         [K, L] = local_split(N);
      end
      if K < 2 || L < 2
         erM = sprintf('interleaver_snake: degenerate geometry K=%d L=%d for N=%d', K, L, N);
         return;
      end

      if N > N0
         vectorPadded = [vectorIn, repmat(padSymbol, 1, N - N0)];
      else
         vectorPadded = vectorIn;
      end

      % write column-wise into K x L, read row-wise with even rows reversed
      permutation = zeros(1, N);
      for r = 1:K
         cols = 1:L;
         if mod(r, 2) == 0, cols = fliplr(cols); end
         permutation((r-1)*L + (1:L)) = (cols - 1) * K + r;
      end

      if numel(unique(permutation)) ~= N
         erM = sprintf('interleaver_snake: not a permutation (N=%d K=%d L=%d)', N, K, L);
         permutation = []; return;
      end

      vectorInterleaved = vectorPadded(permutation);
      if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
      if iscolumn(permutation),       permutation       = permutation';       end

   catch ME
      erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   end
end

%% ------------------------------------------------------------------------
function [a, b] = local_split(n)
   a = 1;
   for c = floor(sqrt(n)):-1:2
      if mod(n, c) == 0, a = c; break; end
   end
   b = n / a;
end
