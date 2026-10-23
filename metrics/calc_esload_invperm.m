function esLoad = calc_esload_invperm(perm, B, n)
%CALC_ESLOAD_INVPERM  Design-time counterpart of the error-spreading efficiency.
%
%   esLoad = calc_esload_invperm(perm, B, n)
%
% WHY THIS EXISTS
% ---------------------------------------------------------------------------
% Section 6.7 of the manuscript defines design-time counterparts for three of
% the four a posteriori, n-aware statistics:
%
%       S_ECC -> meanMaxCW      Delta_BS -> cvLoad      Delta_G -> giniLoad
%
% eta_ES has none, and it is not a minor member: it ties Delta_G at 0.924 as
% the strongest a posteriori predictor in the suite. A referee reading the
% counterpart table will ask where its design-time version is. This is it.
%
% THE QUANTITY
% ---------------------------------------------------------------------------
% eta_ES is the fraction of the codewords a burst COULD infect that it does:
%
%       eta_ES = K_err / min(K, B)
%
% for one realized error pattern. The design-time version applies the same
% statistic to the exhaustive sweep instead of to a realization, exactly as
% giniLoad applies Delta_G's Gini coefficient to the sweep:
%
%       esLoad = E_s[ K_err(s) ] / min(K, B)
%
% where K_err(s) is the number of distinct codewords touched by a contiguous
% burst of length B starting at s, and s runs over all N - B + 1 positions.
%
% WHAT IT ADDS OVER giniLoad, AND WHAT IT MAY NOT
% ---------------------------------------------------------------------------
% giniLoad already sees part of this: its Gini coefficient counts the codewords
% a burst leaves untouched. But Gini mixes that count with how unevenly the
% touched codewords are loaded, while this isolates the count alone. Whether
% the isolated count carries information giniLoad does not is an empirical
% question, and the point of scoring it rather than arguing about it.
%
% A SATURATION RISK WORTH STATING IN ADVANCE
% ---------------------------------------------------------------------------
% At the burst lengths that matter here, B is large relative to K and a
% permutation that spreads at all touches nearly every codeword, so esLoad can
% sit near 1 for most methods and discriminate poorly. If that is what the
% measurement shows, it is still an answer: it explains WHY the suite carries
% no counterpart for eta_ES, which is better than leaving the asymmetry
% unexplained. Declared here before the run so the outcome cannot be read as a
% post hoc rationalisation.
%
% COST
% ---------------------------------------------------------------------------
% One sliding window over the frame, maintaining a per-codeword occupancy count
% and the number of nonzero entries. O(N) total, the same sweep cost as the
% other design-time load statistics.
%
% CONVENTION
% ---------------------------------------------------------------------------
% Gather, as everywhere in the harness: interleaved position i carries source
% symbol perm(i), whose codeword is ceil(perm(i)/n). Source symbols are 1-based.

   p = double(perm(:)).';
   N = numel(p);
   esLoad = NaN;
   if N < 1 || n < 1, return; end

   B = min(max(round(B), 1), N);
   cw = ceil(p / n);
   K  = max(cw);

   cnt = zeros(1, K);
   distinct = 0;
   for i = 1:B
      c = cw(i);
      if cnt(c) == 0, distinct = distinct + 1; end
      cnt(c) = cnt(c) + 1;
   end

   nPos = N - B + 1;
   acc  = distinct;
   for s = 2:nPos
      cOut = cw(s - 1);
      cnt(cOut) = cnt(cOut) - 1;
      if cnt(cOut) == 0, distinct = distinct - 1; end
      cIn = cw(s + B - 1);
      if cnt(cIn) == 0, distinct = distinct + 1; end
      cnt(cIn) = cnt(cIn) + 1;
      acc = acc + distinct;
   end

   esLoad = (acc / nPos) / min(K, B);
end
