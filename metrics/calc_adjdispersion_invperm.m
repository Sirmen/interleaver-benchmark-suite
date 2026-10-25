function gam = calc_adjdispersion_invperm(perm)
%CALC_ADJDISPERSION_INVPERM  Distinct adjacent displacement magnitudes.
%
%   gam = calc_adjdispersion_invperm(perm)
%
%       gam = |{ |perm(i+1) - perm(i)| : i = 1..N-1 }| / (N-1)
%
% WHAT THIS IS AND WHY IT IS SCORED SEPARATELY FROM dispersion
% ---------------------------------------------------------------------------
% This is the quantity that analyzeDispersion.m computes and calls the
% "Dispersion Factor (Gamma)". It shipped in the released suite while appearing
% nowhere among the validated metrics, so a reader who opened the repository
% found a dispersion measure that no table accounted for. Scoring it settled
% that: it is the adj_gamma row of Table 8, discarded on C2.
%
% It is the LAG-1 RESTRICTION of dispersion (calc_dispersion_invperm), with
% two further reductions: it keeps only adjacent pairs, and it takes the
% magnitude, discarding the sign of the displacement. Running both answers a
% question worth asking on its own - whether the all-pairs signed count buys
% anything over the cheap adjacent-magnitude count, or whether the lag-1
% summary already carries the discriminating information.
%
% ATTRIBUTION IS UNVERIFIED
% ---------------------------------------------------------------------------
% analyzeDispersion.m credits "Benedetto & Montorsi (1996)". That has NOT been
% checked against the source and must not be carried into the manuscript on
% the strength of a code comment. The quantity is well defined without the
% attribution; if it is to be cited, the primary source has to be read first.
% The all-pairs measure in calc_dispersion_invperm is the one with a located
% definition (Andrews-Heegard-Kozen TR97-1634).
%
% RANGE
% ---------------------------------------------------------------------------
% In (0, 1]. The identity gives one distinct magnitude, so 1/(N-1). A
% permutation whose adjacent jumps are all different gives 1.
%
% NOT THE SAME AS adjCV
% ---------------------------------------------------------------------------
% adjCV is the coefficient of variation of the same adjacent jump sizes: it
% measures their spread in magnitude. This counts how many distinct values
% occur and is blind to how far apart they are. Two permutations can share an
% adjCV and differ here, and conversely.

   p = double(perm(:)).';
   N = numel(p);
   if N < 2, gam = NaN; return; end

   gam = numel(unique(abs(diff(p)))) / (N - 1);
end
