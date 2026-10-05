function [vectorInterleaved, permutation, L, K, Q, R, erM] = ...
    interleaver_hierarchical(vectorIn, padSymbol, maxExtensionPercentage)
%INTERLEAVER_HIERARCHICAL  Genuine two-level (multistage) block interleaver.
%
% WHY THIS FILE WAS REWRITTEN
% ---------------------------
% The previous version's second level was provably a no-op, so the method was
% bit-for-bit a PLAIN BLOCK INTERLEAVER. Measured over N = 30..510 with the
% harness's own parameters, its permutation was identical to
% interleaver_block's on 39/39 sampled lengths, and every reported metric
% matched to four decimals (eta_sep 0.3085, minAdj 15.2 / 13.2, BE 1.0000).
%
% Two independent causes, both in precompute_hierarchical_perms.m:
%   line 27-28   Q = max(divsK(divsK>=1));   R = max(divsL(divsL>=1));
%                max(divisors(K)) IS K, so Q = K and R = L, hence the level-2
%                sub-blocks were 1x1.
%   line 50      permBlockIndex = blockIndex;   % identity block perm
%                so even with correct Q,R the second stage was the identity.
%
% THE FIX: A REAL TWO-STAGE INTERLEAVER
%   stage 1 (coarse)  a full-frame L x K block interleaver, which is what
%                     supplies the O(sqrt(N)) separation;
%   stage 2 (fine)    the stage-1 output is cut into Q blocks of size R and
%                     each block is scrambled internally by a stride
%                     permutation coprime to R.
%
%       pi = coarse o fine
%
% Order matters. Doing it the other way round (fine first, then reordering
% whole blocks) caps the separation at the block size R ~ sqrt(N)/2 and makes
% the result WORSE than a single-stage block interleaver - measured eta_sep
% 0.04..0.23 against block's 0.31. Coarse-first keeps the block interleaver's
% separation and adds the within-block scrambling on top, so the method is
% distinct from `block` without being a downgrade of it.
%
% Neither stage is the identity (stage-2 stride is forced > 1), so the two
% levels genuinely compose.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% OUTPUTS
%   L, K   inner block geometry (s1 x s2)
%   Q, R   outer geometry (blocks x block size)
%
% R.T. Sirmen harness, corrected 2026

   erM = ""; vectorInterleaved = []; permutation = []; L = 0; K = 0; Q = 0; R = 0;
   try
      if nargin < 2 || isempty(padSymbol), padSymbol = 0; end
      if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.1; end

      [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
      if failed
         erM = "interleaver_hierarchical: Data shape error. Must be (1xN)"; return;
      end
      N0 = length(vectorIn);
      if N0 < 8, erM = "interleaver_hierarchical: N must be >= 8"; return; end

      % ---- find a length that supports two non-trivial levels -------------
      maxN = floor(N0 * (1 + maxExtensionPercentage));
      N = 0;
      for cand = N0:maxN
         [B, S] = local_split(cand);
         if B >= 2 && S >= 4                     % S >= 4 so the inner stage
            [s1, s2] = local_split(S);           % itself has two dimensions
            if s1 >= 2 && s2 >= 2
               N = cand; Q = B; R = S; L = s1; K = s2; break;
            end
         end
      end
      if N == 0
         erM = sprintf('interleaver_hierarchical: no two-level geometry for N=%d within %.0f%% extension', ...
                       N0, maxExtensionPercentage*100);
         return;
      end

      if N > N0
         vectorPadded = [vectorIn, repmat(padSymbol, 1, N - N0)];
      else
         vectorPadded = vectorIn;
      end

      % ---- stage 1 (coarse): full-frame block interleaver -----------------
      [c1, c2] = local_split(N);
      if c1 < 2, erM = sprintf('interleaver_hierarchical: N=%d has no coarse geometry', N); return; end
      coarse = local_blockPerm(c1, c2);          % gather index over 1..N
      L = c1; K = c2;

      % ---- stage 2 (fine): stride scramble inside each block of size R ----
      stride = local_coprimeStride(R);
      fine = zeros(1, N);
      for o = 1:Q
         base = (o - 1) * R;
         fine(base + (1:R)) = base + mod((0:R-1) * stride, R) + 1;
      end

      % ---- compose: read fine order, then map through the coarse gather ---
      permutation = coarse(fine);

      if numel(unique(permutation)) ~= N
         erM = sprintf('interleaver_hierarchical: not a permutation (N=%d Q=%d R=%d L=%d K=%d)', N, Q, R, L, K);
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
% Factor n as a*b with a <= b and a as large as possible (near-square).
% Returns a = 1 when n is prime.
   a = 1;
   for c = floor(sqrt(n)):-1:2
      if mod(n, c) == 0, a = c; break; end
   end
   b = n / a;
end

function s = local_coprimeStride(R)
%LOCAL_COPRIMESTRIDE  SMALLEST stride >= 2 coprime to R. Not optimised.
%
%   This used to be round(R/phi) adjusted coprime - Crozier's golden relative
%   prime rule. Three of my rewrites had ended up carrying that same published
%   design under three different method names (`time`, `freqDeterm`,
%   `hierarchical`) while `goldenRP` also sat in the table under its own name.
%   That is not a comparison; it is one idea voting four times, and it is why
%   `time` appeared to beat S-Interleaving.
%
%   Stride 1 would make stage 2 the identity and collapse the method into a
%   plain block interleaver - which is already in the table as `block`. So the
%   smallest stride that is BOTH >= 2 and coprime to R is used instead: it
%   keeps the two-level structure the method is defined by, while using no
%   design freedom that could be mistaken for tuning.
   s = 2;
   for c = 2:max(2, R - 1)
      if gcd(c, R) == 1, s = c; return; end
   end
end

function p = local_blockPerm(rows, cols)
% Row-write / column-read block interleaver on rows*cols points, as a gather
% index: p(j) = the source position read at output slot j.
   idx = reshape(1:(rows*cols), cols, rows).';   % row-major fill, rows x cols
   p = reshape(idx, 1, []);                      % column-major read
end
