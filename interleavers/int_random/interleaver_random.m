function [vectorInterleaved, permutation, erM] = ...
    interleaver_random(vectorIn, blockSize, permutationSeed, padSymbol, maxExtensionPercentage)
%INTERLEAVER_RANDOM  Uniform random (pseudo-random) interleaver.
%   Berrou/Divsalar-style random baseline: a fresh uniform permutation per
%   frame, reproducible from a single base seed.
%
% WHY THIS FILE WAS REWRITTEN
% ---------------------------
% The previous version called
%
%     rng(permutationSeed);            % permutationSeed = 2106, a constant
%     permutation = randperm(length(inData_padded));
%
% INSIDE the function, on every invocation. Every Monte-Carlo trial at a given
% N therefore used the identical permutation. Three consequences:
%   * the reported variance for this baseline reflects channel noise only and
%     understates the variance of the random-interleaver class;
%   * at each N the baseline is one lucky-or-unlucky draw, with nothing in the
%     output to indicate which;
%   * it is not a random interleaver in the Berrou/Divsalar sense at all - it
%     is one specific fixed permutation.
% It also reset MATLAB's GLOBAL stream as a side effect, which would freeze any
% other randomness downstream in the same trial.
%
% THE FIX
% The global stream is seeded from (base seed + per-call counter) for the draw
% and then RESTORED to its previous state, so each call returns a different
% permutation, the whole run stays reproducible from `permutationSeed` alone,
% and nothing downstream inherits a reseeded generator. Reset the counter
% between runs with:   clear interleaver_random
%
% Two further corrections:
%   * PADDING REMOVED. `blockSize` was used only to pad the frame to a multiple
%     of L; the permutation was a full-length randperm, never block-wise, so
%     the padding served no algorithmic purpose and only cost bandwidth
%     (BE 0.9688 at worst). The argument is now accepted and ignored, kept for
%     call-site compatibility, and BE = 1.0.
%   * the size-error message said "interleaver_block".
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% R.T. Sirmen harness, corrected 2026

persistent callCount baseSeed
   erM = ""; vectorInterleaved = []; permutation = [];
   try
      [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
      if failed
         erM = "interleaver_random: Data shape error. Must be (1xN)"; return;
      end
      N = length(vectorIn);
      if N < 2, erM = "interleaver_random: N must be >= 2"; return; end

      if nargin < 3 || isempty(permutationSeed), permutationSeed = 2106; end

      if isempty(baseSeed) || baseSeed ~= permutationSeed
         baseSeed  = permutationSeed;
         callCount = 0;
      end
      callCount = callCount + 1;

      % draw with our own seed, then hand the generator back untouched
      savedState = rng;
      rng(mod(baseSeed + callCount, 2^31 - 1), 'twister');
      permutation = randperm(N);
      rng(savedState);

      vectorInterleaved = vectorIn(permutation);
      if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
      if iscolumn(permutation),       permutation       = permutation';       end

   catch ME
      erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   end
end
