function [vectorInterleaved, permutation, L, K, erM] = interleaver_spiral(vectorIn, padSymbol, maxExtensionPercentage)
%INTERLEAVER_SPIRAL  Spiral (boustrophedon-ring) interleaver.
%   Lays the frame on an L x K grid and reads it outer-ring to inner-ring:
%   top row left-to-right, right column down, bottom row right-to-left, left
%   column up, then repeat on the shrunken rectangle.
%
%   CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% THREE CORRECTIONS, 2026
% -----------------------
% 1. ERROR STRING (real fix). The shape-check error read
%       "interleaver_prime - Data shape error"
%    - a copy-paste from interleaver_prime.m. Any malformed input to the SPIRAL
%    method was reported as a failure of the PRIME method, which is exactly the
%    kind of thing that costs an afternoon during a sweep. Now says spiral.
%
% 2. FILL ORDER (comment only). The header and the inline comment both said
%    "row-major". reshape(1:(L*K), L, K) is COLUMN-major, and sub2ind([L K],r,c)
%    = (c-1)*L + r is column-major too - so the file is internally consistent
%    and produces a valid permutation; only the description was wrong. The
%    variable idx_linear is never read at all.
%
% 3. adj_min = 1 IS INHERENT. DO NOT "FIX" IT.
%    Along a vertical leg of the spiral (right column downward, left column
%    upward) the linear indices are (c-1)*L + r for consecutive r, i.e. they
%    step by exactly 1. So consecutive OUTPUT positions draw consecutive INPUT
%    symbols on every vertical leg, and the minimum adjacent separation is 1 for
%    every N. The horizontal legs are the good ones (they step by L).
%    Like helicalScan, spiral is in the comparison precisely BECAUSE it has
%    strong average dispersion and a worst case of 1 - report adj_min and
%    mu_adj side by side rather than dropping the method.

erM = ""; vectorInterleaved = []; permutation = []; L = 0; K = 0;
try
   if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.34; end
   if nargin < 2 || isempty(padSymbol), padSymbol = 0; end
   
   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed
      erM = strcat("interleaver_spiral: Data shape error: (", num2str(size(vectorIn)), ") Must be (1xN)");
      return;
   end

   N0 = numel(vectorIn);
   if N0 == 0
      erM = 'interleaver_spiral - Empty input';
      return;
   end
    
   % choose K, L
   [L, K, Npad] = choose_balanced_factors(N0, maxExtensionPercentage);
   adjustedN = L * K;

   if adjustedN > (N0 * (1+maxExtensionPercentage))
      erM = strcat("interleaver_spiral Size-adjusted-N error: (", num2str(N0), ")");
      return
   end

   % pad
   if adjustedN > N0
      vectorInP = [vectorIn, repmat(padSymbol, 1, adjustedN - N0)];
   else
      vectorInP = vectorIn;
   end

   %% Grid is L rows x K columns, indexed COLUMN-major (see correction 2):
   %% cell (r,c) holds linear index (c-1)*L + r, which is what sub2ind returns
   %% below. idx_linear is never read - kept only to show the layout.
   idx_linear = reshape(1:(L*K), L, K);                                    %#ok<NASGU>
   % create spiral ordering over LxK and map to linear indices
   spiralOrder = zeros(L*K,1);
   top = 1; bottom = L; left = 1; right = K;
   pos = 1;
   while top <= bottom && left <= right
      % left -> right (top row)
      for c = left:right
         spiralOrder(pos) = sub2ind([L K], top, c); pos = pos + 1;
      end
      top = top + 1;
      if top > bottom, break; end
   
      % top -> bottom (right col). NOTE: consecutive r means consecutive linear
      % indices - this leg is where adj_min = 1 comes from. Inherent; see
      % correction 3 in the header.
      for r = top:bottom
         spiralOrder(pos) = sub2ind([L K], r, right); pos = pos + 1;
      end
      right = right - 1;
      if left > right, break; end
   
      % right -> left (bottom row)
      if top <= bottom
         for c = right:-1:left
             spiralOrder(pos) = sub2ind([L K], bottom, c); pos = pos + 1;
         end
         bottom = bottom - 1;
      end
   
      % bottom -> top (left col)
      if left <= right
         for r = bottom:-1:top
             spiralOrder(pos) = sub2ind([L K], r, left); pos = pos + 1;
         end
         left = left + 1;
      end
   end
   
   if pos-1 ~= L*K || any(spiralOrder==0)
      erM = 'interleaver_spiral: spiral ordering generation failed.';
      return;
   end
   
   % Now permutation: we filled matrix in row-major order with linear indices 1..L*K.
   % reading in spiral gives mapping from spiral position -> matrix linear index.
   % Apply that mapping to get permutation over 1..Ntarget
   permutation = spiralOrder(:).';           % 1 x (L*K) with values in 1..(L*K)
   % Now map these matrix indices to positions in original row-major linearization:
   % the permutation indexes the row-major positions: vectorInP(permutation)
   vectorInterleaved = vectorInP(permutation);
   
   % Ensure outputs are row vectors
   vectorInterleaved = vectorInterleaved(:).';
   permutation = permutation(:).';

catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end
