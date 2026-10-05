function [vectorInterleaved, permutation, Nsc, Nsym, erM] = ...
    interleaver_frequency(vectorIn, L, padSymbol, permutationSeed, maxExtensionPercentage, mode)
%INTERLEAVER_FREQUENCY  OFDM frequency-domain interleaver: permutes the
%   SUBCARRIER index within each OFDM symbol.
%
%   mode = 'deterministic'  subcarrier permutation from a coprime stride
%   mode = 'random'         a fresh pseudo-random subcarrier permutation
%
% WHY THIS FILE WAS REWRITTEN
% ---------------------------
% 1. IT WAS NOT A FREQUENCY INTERLEAVER. `L` ("number of subcarriers") entered
%    the permutation only through totalSymbols = ceil(N/L)*L, i.e. purely as
%    padding: two different L that divide N produced the IDENTICAL permutation
%    (verified at N = 255 for L = 5, 15, 17). There was no subcarrier mapping
%    and no OFDM symbol structure. The deterministic branch was a stride-3/5/7/11
%    decimation of the whole frame - over N = 30..510 the stride took exactly
%    four values, so burst dispersion never grew with N. It was also bit-identical
%    to interleaver_multiDim at N = 30, 37..42.
%
% 2. THE RANDOM BRANCH WAS NOT RANDOM. `rng(randomSeed)` was called inside the
%    function with the harness's fixed seed 2106, so every Monte-Carlo trial at
%    a given N used the same permutation and the reported variance for this
%    baseline reflected channel noise only.
%
% 3. Three files held two permutations: interleaver_frequency's two branches
%    were character-for-character interleaver_freqRandom.m and
%    interleaver_freqDeterm.m.
%
% THE FIX
% The frame is given the 2-D structure a frequency interleaver needs:
%
%       Nsc subcarriers  x  Nsym OFDM symbols
%
% and the permutation acts on the SUBCARRIER axis, leaving the symbol (time)
% index alone. That makes it the exact complement of interleaver_time, which
% permutes the symbol axis at fixed subcarrier - the pair DVB-T, DVB-T2 and LTE
% all specify, and two genuinely different permutations of the same grid.
%
% To avoid a trivially periodic map the subcarrier permutation is SYMBOL
% DEPENDENT: symbol t uses the base permutation rotated by t, which is what
% real frequency interleavers do to decorrelate successive symbols.
%
% The random mode now draws a fresh permutation per call, seeded from
% (base seed + call counter) with the global stream saved and restored, so the
% run stays reproducible from `permutationSeed` alone without freezing the
% baseline. Reset with:  clear interleaver_frequency
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% R.T. Sirmen harness, corrected 2026

persistent callCount baseSeed
   erM = ""; vectorInterleaved = []; permutation = []; Nsc = 0; Nsym = 0;
   try
      if nargin < 3 || isempty(padSymbol), padSymbol = 0; end
      if nargin < 4 || isempty(permutationSeed), permutationSeed = 2106; end
      if nargin < 5 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.1; end
      if nargin < 6 || isempty(mode), mode = 'deterministic'; end
      mode = lower(mode);
      if ~any(strcmp(mode, {'deterministic','random'}))
         erM = "interleaver_frequency: mode must be 'deterministic' or 'random'"; return;
      end

      [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
      if failed
         erM = "interleaver_frequency: Data shape error. Must be (1xN)"; return;
      end
      N0 = length(vectorIn);
      if N0 < 9, erM = "interleaver_frequency: N must be >= 9"; return; end

      % ---- grid: at least 3 subcarriers so the frequency axis is non-trivial
      maxN = floor(N0 * (1 + maxExtensionPercentage));
      N = 0;
      for cand = N0:maxN
         [a, b] = local_split(cand);
         if a >= 3
            N = cand; Nsym = a; Nsc = b; break;    % more subcarriers than symbols
         end
      end
      if N == 0
         erM = sprintf('interleaver_frequency: no grid with >= 3 subcarriers for N=%d within %.0f%%', ...
                       N0, maxExtensionPercentage*100);
         return;
      end

      if N > N0
         vectorPadded = [vectorIn, repmat(padSymbol, 1, N - N0)];
      else
         vectorPadded = vectorIn;
      end

      % ---- base subcarrier permutation
      if strcmp(mode, 'random')
         if isempty(baseSeed) || baseSeed ~= permutationSeed
            baseSeed = permutationSeed; callCount = 0;
         end
         callCount = callCount + 1;
         savedState = rng;
         rng(mod(baseSeed + callCount, 2^31 - 1), 'twister');
         basePerm = randperm(Nsc);
         rng(savedState);
      else
         s = local_coprimeStride(Nsc);
         basePerm = mod((0:Nsc-1) * s, Nsc) + 1;
      end

      % ---- apply per symbol, rotated by the symbol index
      i0 = 0:N-1;
      s_in = mod(i0, Nsc);              % subcarrier of the input sample
      t    = floor(i0 / Nsc);           % OFDM symbol

      permutation = zeros(1, N);
      for tt = 0:Nsym-1
         rot = mod(basePerm + tt - 1, Nsc) + 1;      % symbol-dependent rotation
         permutation(tt*Nsc + (1:Nsc)) = tt*Nsc + rot;
      end

      if numel(unique(permutation)) ~= N
         erM = sprintf('interleaver_frequency: not a permutation (N=%d Nsc=%d Nsym=%d)', N, Nsc, Nsym);
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

function s = local_coprimeStride(n)
   phi = (1 + sqrt(5)) / 2;
   s0 = max(2, round(n / phi));
   s = 0;
   for k = 0:n
      for c = [s0 - k, s0 + k]
         if c >= 2 && c < n && gcd(c, n) == 1, s = c; break; end
      end
      if s > 0, break; end
   end
   if s == 0, s = 1; end
end
