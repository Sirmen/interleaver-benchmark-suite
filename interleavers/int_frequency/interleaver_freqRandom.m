function [vectorInterleaved, permutation, Nsc, Nsym, Q, R, erM] = ...
    interleaver_freqRandom(vectorIn, padSymbol, maxExtensionPercentage, randomSeed)
%INTERLEAVER_FREQRANDOM  Pseudo-random OFDM frequency interleaver.
%   Permutes the SUBCARRIER index inside each OFDM symbol with a fresh random
%   permutation per frame. Time (symbol) index untouched.
%
%   Signature matches what interleaver_generic_pc expects in the live
%   interleave_all_pc path:
%       [~, perm, L, K, Q, R, erM] = interleaver_freqRandom(data, pad, maxExt, seed)
%
% WHAT WAS WRONG BEFORE - TWO THINGS
% ----------------------------------
% 1. NOT RANDOM. `rng(randomSeed)` was called INSIDE the function with the
%    harness's fixed seed 2106, so every Monte-Carlo trial at a given N used
%    the identical permutation. The reported variance for this baseline
%    reflected channel noise only, and the "random" interleaver was in fact one
%    specific fixed permutation. It also reset the GLOBAL stream as a side
%    effect.
% 2. NOT A FREQUENCY INTERLEAVER. The greedy construction conditioned on a
%    "subcarrier index" that entered the permutation only through padding, and
%    its minFreqSep guarantee was silently dropped whenever a subcarrier class
%    ran dry (`if isempty(candidates), candidates = find(~used); end`), which
%    happens routinely near the tail. Measured draws fell far below the nominal
%    separation with no warning.
%
% THE FIX
% The frame is given its Nsc x Nsym grid and the permutation acts on the
% subcarrier axis only, so this is a genuine frequency interleaver and the
% exact complement of interleaver_time. The draw uses (base seed + per-call
% counter) with the global stream saved and RESTORED, so:
%   * every call returns a different permutation - it is stochastic again;
%   * the whole run is still reproducible from `randomSeed` alone;
%   * nothing downstream inherits a reseeded generator.
% Reset the counter between runs with:  clear interleaver_freqRandom
%
% DO NOT PRECOMPUTE THIS METHOD. Caching its permutation reinstates defect 1.
% PrecomputeInterleaversGenerator lists it in opts.liveMethods for that reason.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% R.T. Sirmen harness, corrected 2026

persistent callCount baseSeed
   erM = ""; vectorInterleaved = []; permutation = [];
   Nsc = 0; Nsym = 0; Q = 1; R = 1;
   try
      if nargin < 2 || isempty(padSymbol), padSymbol = 0; end
      if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.1; end
      if nargin < 4 || isempty(randomSeed), randomSeed = 2106; end

      [N, vectorPadded, Nsc, Nsym, erM] = freqGridSetup(vectorIn, padSymbol, maxExtensionPercentage, 'freqRandom');
      if ~isempty(char(erM)), return; end

      if isempty(baseSeed) || baseSeed ~= randomSeed
         baseSeed = randomSeed; callCount = 0;
      end
      callCount = callCount + 1;

      savedState = rng;
      rng(mod(baseSeed + callCount, 2^31 - 1), 'twister');
      basePerm = randperm(Nsc);
      rng(savedState);

      permutation = freqGridApply(basePerm, Nsc, Nsym);

      if numel(unique(permutation)) ~= N
         erM = sprintf('interleaver_freqRandom: not a permutation (N=%d Nsc=%d Nsym=%d)', N, Nsc, Nsym);
         permutation = []; return;
      end

      vectorInterleaved = vectorPadded(permutation);
      Q = callCount; R = Nsym;
      if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
      if iscolumn(permutation),       permutation       = permutation';       end

   catch ME
      erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   end
end
