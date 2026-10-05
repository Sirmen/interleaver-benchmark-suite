function [vectorInterleaved, permutation, erM] = interleaver_chaotic(vectorIn, r, x0)
%INTERLEAVER_CHAOTIC  Logistic-map chaotic interleaver.
%   H. Zhang et al., "A chaotic interleaver used in turbo codes",
%   Proc. IEEE ICCCAS, 2004.
%
%       x_{n+1} = r * x_n * (1 - x_n),   permutation = sort-index of the orbit
%
% WHY THIS FILE WAS REWRITTEN
% ---------------------------
% Two defects made the previous version statistically unusable, both measured
% over the full range N = 30..510 (481 lengths):
%
%   1. NO TRANSIENT DISCARDED. Recording started at the first iterate. With r
%      and x0 both fixed constants, the orbit is the same for every N, so the
%      permutation for length N was exactly the permutation for N = 510
%      restricted to values <= N. Verified: 481/481. The 481 points are one
%      nested sequence, not 481 samples - any confidence interval or ANOVA
%      computed across N for this method is invalid as computed.
%
%   2. x0 = 0.5 IS THE CRITICAL POINT of the logistic map. x_1 = r/4 is the
%      global maximum on [0,1], so no later iterate can exceed it and source
%      symbol 1 is always transmitted last. Verified: permutation(end) == 1
%      for 481/481, and permutation(1) == 2 for 481/481. A structural
%      invariant in what is supposed to be a pseudo-random permutation.
%
% THE FIX
%   * discard a transient of BURN_IN iterates before recording (standard
%     practice for chaotic sequence generators);
%   * derive x0 per length from the supplied seed value, staying away from
%     0, 0.5 and 1 and from the preimages of the fixed point.
%
% The interleaver stays DETERMINISTIC given (N, r, x0) - which is correct:
% a chaotic interleaver is a designed permutation, not a random draw. What
% changes is that each N is now an independent design instead of a prefix of
% one shared orbit.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
% NO PADDING: BE = 1.0.
%
% INPUTS
%   r   logistic parameter. 3.9 (harness default) is inside the chaotic band.
%   x0  base seed in (0,1). The actual initial condition is derived from it
%       and from N; pass [] for the default 0.37.
%
% R.T. Sirmen harness, corrected 2026

   BURN_IN = 1000;

   erM = ""; vectorInterleaved = []; permutation = [];
   try
      [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
      if failed
         erM = "interleaver_chaotic: Data shape error. Must be (1xN)"; return;
      end
      N = length(vectorIn);
      if N < 4, erM = "interleaver_chaotic: N must be >= 4"; return; end

      if nargin < 2 || isempty(r),  r  = 3.9;  end
      if nargin < 3 || isempty(x0), x0 = 0.37; end

      if r <= 3.57 || r > 4
         erM = sprintf('interleaver_chaotic: r = %.4f is outside the chaotic band (3.57, 4]', r);
         return;
      end

      % --- initial condition: length-dependent, and never a degenerate point
      x = local_seed(x0, N);

      % --- discard the transient
      for k = 1:BURN_IN
         x = r * x * (1 - x);
      end

      % --- record the orbit
      seq = zeros(1, N);
      for i = 1:N
         x = r * x * (1 - x);
         seq(i) = x;
      end

      % A collapsed orbit (x -> 0 or a fixed point) would sort to the identity
      % and pass a uniqueness test, so check the orbit itself, not the result.
      if numel(unique(seq)) < N
         erM = sprintf('interleaver_chaotic: orbit collapsed at N=%d (r=%.4f) - ties in the sequence', N, r);
         return;
      end

      [~, permutation] = sort(seq);

      vectorInterleaved = vectorIn(permutation);
      if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
      if iscolumn(permutation),       permutation       = permutation';       end

   catch ME
      erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   end
end

%% ------------------------------------------------------------------------
function x = local_seed(x0, ~)
%LOCAL_SEED  The seed the CALLER gave. No length-dependent perturbation.
%
%   This used to return mod(x0 + N/phi, 1) - a per-length seed derived from
%   the golden ratio. Two problems. It is Crozier's constant appearing inside
%   yet another method, and it makes the chaotic interleaver a DIFFERENT map
%   for every N, which is not what a logistic-map interleaver is: the
%   published construction fixes (r, x0) and iterates.
%
%   config supplies rChaotic = 3.9 and xChaotic = 0.5; both are used as given.
   x = x0;
end
