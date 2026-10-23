function S = calc_srandom_spread_invperm(perm)
%CALC_SRANDOM_SPREAD_INVPERM  Achieved S-random spread of a permutation.
%
%   S = calc_srandom_spread_invperm(perm)
%
%   S. Dolinar and D. Divsalar, JPL TDA Progress Report 42-122, 1995;
%   D. Divsalar and F. Pollara, JPL TDA Progress Report 42-123, 1995.
%
% THE QUANTITY
% ---------------------------------------------------------------------------
% The S-random construction accepts a candidate position only if it satisfies
%
%       |i - j| < s   =>   |pi(i) - pi(j)| >= s
%
% for a declared s. Read as a METRIC rather than a construction rule, the
% achieved spread is the largest s for which the permutation satisfies it:
%
%       S = max { s : min_{1 <= d < s} m(d) >= s },   m(d) = min_i |pi(i+d)-pi(i)|
%
% WHY IT IS A THIRD DISTINCT MEMBER OF THE SPREAD FAMILY
% ---------------------------------------------------------------------------
% Sfactor minimizes an L2 distance, S_new minimizes an L1 distance, and this
% one minimizes neither: it is the largest threshold that a two-sided
% implication survives. Three different functionals on the same point set, so
% their method rankings are three separate empirical questions.
%
% WHY IT MATTERS FOR THIS BENCHMARK IN PARTICULAR
% ---------------------------------------------------------------------------
% srandom is in the method set with its published parameter rule
% s = floor(sqrt(N/2)). The DECLARED s is therefore known for one method and
% the ACHIEVED s is defined for all of them, which is exactly the asymmetry
% the provenance audit exists to expose. Scoring it says whether the quantity
% srandom is built to maximize predicts recovery for the other twenty-five.
%
% COST
% ---------------------------------------------------------------------------
% m(d) is one vectorized min per d, and the loop stops at d = S with
% S = O(sqrt(N)), so the cost is O(N*sqrt(N)).

   p = double(perm(:)).';
   N = numel(p);
   if N < 2, S = NaN; return; end

   % s = 1 holds vacuously: there is no d with 1 <= d < 1.
   S = 1;
   M = inf;                               % running min_{1<=d<=s-1} m(d)
   for s = 2:N
      d = s - 1;
      M = min(M, min(abs(p(1+d:end) - p(1:end-d))));
      if M >= s, S = s; else, break; end
   end
end
