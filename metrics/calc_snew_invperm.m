function S = calc_snew_invperm(perm)
%CALC_SNEW_INVPERM  Crozier's combined spread S_new of a permutation.
%
%   S = calc_snew_invperm(perm)
%
%   S. Crozier, "New high-spread high-distance interleavers for turbo-codes",
%   20th Biennial Symp. Communications, Kingston, 2000:
%
%       S_new = min over i ~= j of ( |pi(i) - pi(j)| + |i - j| )
%
% ATTRIBUTION CHECKED
% ---------------------------------------------------------------------------
% The Kingston 2000 paper is not indexed online, but Crozier and Guinand,
% "High-performance low-memory interleaver banks for turbo-codes", VTC-Fall
% 2001 - the DRP paper the harness already cites - restates it as equations
% (3) to (5), S''(i,j) = |I(i)-I(j)| + |i-j| minimised over j and then over i,
% and says it "is defined as" the Kingston paper. So the definition used here
% matches the published one and the citation is sound.
%
% The same paper puts the theoretical maximum spread at floor(sqrt(2K)) WITH
% DUAL TAIL-BITING. That qualifier matters: the bound belongs to the circular
% case. It is still the right smell test for a linear frame, since a reported
% value far above it means the sweep was capped (see below), but it should not
% be quoted as a hard bound for linear frames.
%
% WHY THIS METRIC IN PARTICULAR
% ---------------------------------------------------------------------------
% It is the criterion the benchmark itself uses: DRP's stride and dither
% vectors are not published at any length on either grid, so they are
% re-searched under S_new, which IS published (Table III of the manuscript).
% The benchmark therefore selects one method's parameters with a metric that
% is not among the nineteen it validates. Scoring it here closes that gap.
%
% RELATION TO Sfactor
% ---------------------------------------------------------------------------
% Sfactor (calc_spread_factor_invperm) is the Takeshita-Costello spread: the
% same minimum over the same point set under the EUCLIDEAN norm. S_new is the
% L1 form. They are not monotonically related pair by pair, so the minima can
% be attained at different pairs and the induced method rankings can differ.
% Scoring both is what makes "we scored the spread family" a measured claim
% rather than an assumption about norms.
%
% THE SWEEP MUST NOT USE A FIXED WINDOW
% ---------------------------------------------------------------------------
% Lifted unchanged from local_Snew in interleaver_drp.m so the metric scored
% here is bit-for-bit the one the DRP search optimizes. A pair at index
% distance d contributes at least d + 1, so once d reaches the best value
% found so far no larger d can improve it - but until then it can. Capping d
% at a constant silently reports a value LARGER than the true minimum whenever
% the answer exceeds the cap, and the error grows with N exactly where the
% metric matters most. Growing d while d < s is correct and costs O(N*s) with
% s = O(sqrt(N)), not O(N^2).
%
% ORIENTATION
% ---------------------------------------------------------------------------
% The minimum of |pi(i)-pi(j)| + |i-j| over all pairs is unchanged by swapping
% pi for its inverse: the point set is reflected across the diagonal and the L1
% distance is symmetric in its two coordinates. perm is used directly, as in
% the DRP search.

   p = double(perm(:)).';
   N = numel(p);
   if N < 2, S = NaN; return; end

   S = inf; d = 1;
   while d < S && d < N
      S = min(S, d + min(abs(p(1+d:end) - p(1:end-d))));
      d = d + 1;
   end
end
