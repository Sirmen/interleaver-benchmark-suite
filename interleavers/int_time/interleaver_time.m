function [vectorInterleaved, permutation, Nsc, Nsym, erM] = ...
    interleaver_time(vectorIn, padSymbol, maxExtensionPercentage, depth)
%INTERLEAVER_TIME  OFDM time-domain interleaver: permutes ACROSS OFDM symbols
%   at a fixed subcarrier.
%
% WHY THIS FILE WAS REWRITTEN, AND WHY "TIME" CAN BE A REAL METHOD
% ----------------------------------------------------------------
% The previous version had no time-domain content whatsoever - it was a plain
% block interleaver, bit-for-bit identical to interleaver_matrix on 39/39
% sampled lengths (eta_sep 0.2716, minAdj 13.7/14.8, BE 0.9835 for both). As a
% separate row in a results table it was not defensible.
%
% It is defensible once the frame is given the structure a time interleaver
% actually needs. An OFDM frame is a 2-D grid
%
%       Nsc subcarriers  x  Nsym OFDM symbols
%
% and the two standard interleavers act on DIFFERENT axes of that same grid:
%
%   frequency interleaver : permutes the SUBCARRIER index within one symbol
%                           (all symbols use the same, or a symbol-dependent,
%                            subcarrier permutation)
%   time interleaver      : permutes the SYMBOL index for a fixed subcarrier,
%                           i.e. moves a sample forward or back in TIME
%
% Those are genuinely different permutations of the same grid, which is why
% DVB-T, DVB-T2 and LTE all specify both. Implementing the time axis is what
% makes this method distinct from every block interleaver in the set instead
% of a duplicate of one.
%
% CONSTRUCTION
% Data is written into the grid subcarrier-first (the natural mapping order).
% Subcarrier s is then cyclically rotated along the TIME axis by
%
%       shift(s) = mod(s * depth, Nsym)
%
% a subcarrier-dependent time delay - the same idea as the DVB-T2 time
% interleaver's rotating delay, expressed as a closed-form block permutation
% so the frame stays self-contained (no flush, BE unaffected).
%
%       grid(s, t)  ->  grid(s, mod(t - s*depth, Nsym))
%
% `depth` is chosen coprime to Nsym so the rotation set covers all delays.
% Consecutive input samples are consecutive in subcarrier, so they receive
% delays differing by `depth` symbols - i.e. they end up depth*Nsc apart in
% the serialised frame. That is the time interleaver's dispersion mechanism,
% and it is orthogonal to what the frequency interleaver does.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% OUTPUTS
%   Nsc, Nsym   the grid actually used
%
% R.T. Sirmen harness, corrected 2026

   erM = ""; vectorInterleaved = []; permutation = []; Nsc = 0; Nsym = 0;
   try
      if nargin < 2 || isempty(padSymbol), padSymbol = 0; end
      if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.1; end
      if nargin < 4, depth = []; end

      [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
      if failed
         erM = "interleaver_time: Data shape error. Must be (1xN)"; return;
      end
      N0 = length(vectorIn);
      if N0 < 9, erM = "interleaver_time: N must be >= 9"; return; end

      % ---- grid: near-square, and at least 3 OFDM symbols so the time axis
      %      has something to permute
      maxN = floor(N0 * (1 + maxExtensionPercentage));
      N = 0;
      for cand = N0:maxN
         [a, b] = local_split(cand);
         if a >= 3
            N = cand; Nsc = b; Nsym = a; break;     % more subcarriers than symbols
         end
      end
      if N == 0
         erM = sprintf('interleaver_time: no grid with >= 3 OFDM symbols for N=%d within %.0f%%', ...
                       N0, maxExtensionPercentage*100);
         return;
      end

      if N > N0
         vectorPadded = [vectorIn, repmat(padSymbol, 1, N - N0)];
      else
         vectorPadded = vectorIn;
      end

      % CANONICAL DEPTH = 1. Do not restore the golden-ratio version.
      % --------------------------------------------------------------
      % This used to call local_coprimeDepth(Nsym), which returns
      % round(Nsym/phi) adjusted to be coprime with Nsym. That is not an OFDM
      % time-interleaver parameter - it is CROZIER'S GOLDEN RELATIVE PRIME
      % rule, and `goldenRP` is already a separate method in the comparison.
      % Entering the same idea twice under two names distorts the whole
      % ranking table, and it made `time` beat S-Interleaving for a reason
      % that has nothing to do with time interleaving.
      %
      % depth = 1 is the plain diagonal read: subcarrier s is delayed by s
      % symbols. That is the textbook time interleaver and uses no design
      % freedom at all.
      if isempty(depth), depth = 1; end
      if depth < 1 || depth >= Nsym || gcd(depth, Nsym) ~= 1
         erM = sprintf('interleaver_time: depth must be in 1..%d and coprime to Nsym=%d (got %s)', ...
                       Nsym-1, Nsym, num2str(depth));
         return;
      end

      % ---- input index -> (subcarrier s, symbol t), subcarrier-first mapping
      i0 = 0:N-1;
      s  = mod(i0, Nsc);            % subcarrier
      t  = floor(i0 / Nsc);         % OFDM symbol

      % ---- rotate each subcarrier along the TIME axis
      t2 = mod(t - s * depth, Nsym);

      % ---- serialise back, subcarrier-first
      out = t2 * Nsc + s;           % 0-based output position of input i0

      % gather index: permutation(outputSlot) = sourceIndex
      permutation = zeros(1, N);
      permutation(out + 1) = i0 + 1;

      if numel(unique(permutation)) ~= N
         erM = sprintf('interleaver_time: not a permutation (N=%d Nsc=%d Nsym=%d depth=%d)', N, Nsc, Nsym, depth);
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

