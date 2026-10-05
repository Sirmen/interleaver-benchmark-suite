function [overT, maxErr, meanMax, cvLoad, giniLoad] = designMetricScore(perm, B, n, t)
%DESIGNMETRICSCORE  The five design-time load statistics, one O(N) pass.
%
%   [overT, maxErrCW, meanMaxCW, cvLoad, giniLoad] = designMetricScore(perm, B, n, t)
%
% Standalone because two callers need it - design_metric_validation and
% metric_scorecard - and this project has twice paid for the same routine
% existing in two places and drifting apart. One definition, one file.
%
% Verified against a brute-force implementation over 320 random permutations:
% overT, maxErrCW, meanMaxCW and cvLoad agree exactly. giniLoad is now also
% exhaustive (every start position): it used to be read on a subsample of about
% two hundred positions, which is not the statistic of Section V-F. A codeword
% holds at most n symbols, so its load never exceeds min(B, n) and the Gini is
% read off the histogram in O(n) per position - the full sweep is O(N*n).
% (2026-09-27, v26: subsampling removed.)
%
% Exhaustive over every burst start position, in O(N) rather than O(N^2/n).
%
% A burst at interleaved positions [s, s+B) corrupts source symbols
% perm(s..s+B-1); the codeword of source symbol p is ceil(p/n). Sliding s by
% one changes exactly two entries of the per-codeword count, so the count
% vector is updated in O(1). The running maximum is maintained through a
% histogram of counts, and the number of codewords over capacity through a
% single counter - so neither statistic needs an O(K) rescan per position.
%
% Bursts do not wrap: s runs to N-B+1, matching the frame model used in the
% campaign.
   perm = perm(:).';
   N = numel(perm);
   % A burst at least as long as the frame is not a meaningful configuration:
   % every start position fails trivially and the load distribution carries no
   % information about the permutation. Return NaN for all five so those cells
   % are dropped from the correlation rather than pinned at a constant, which
   % would drag every method toward the same value and dilute the measurement.
   if B >= N
      overT = NaN; maxErr = NaN; meanMax = NaN; cvLoad = NaN; giniLoad = NaN;
      return;
   end

   cw   = ceil(perm / n);
   K    = max(cw);
   cnt  = zeros(1, K);
   hist = zeros(1, B + 2);      % hist(c+1) = #codewords holding count c
   hist(1) = K;
   curMax = 0;
   nOver  = 0;
   sumSq  = 0;                  % sum of squared counts, for the load CV
   nNZ    = 0;                  % codewords currently carrying at least one error

   % Gini is exhaustive: evaluated at every start position (see header).
   cMax = min(B, n);            % no codeword can carry more than n errors
   giniAcc = 0; giniN = 0;

   % prime the window with s = 1
   for j = 1:B
      c = cw(j);
      o = cnt(c); v = o + 1; cnt(c) = v;
      hist(o+1) = hist(o+1) - 1; hist(v+1) = hist(v+1) + 1;
      sumSq = sumSq + v*v - o*o;
      if o == 0, nNZ = nNZ + 1; end
      if v > curMax, curMax = v; end
      if o == t, nOver = nOver + 1; end
   end
   nPos  = N - B + 1;
   nFail = double(nOver > 0);
   maxErr = curMax;
   sumMax = curMax;
   sumCV  = dms_cv(B, sumSq, nNZ);
   giniAcc = giniAcc + dms_gini(hist, K, B, cMax); giniN = giniN + 1;

   for s = 2:nPos
      % leaving position s-1
      c = cw(s-1);
      o = cnt(c); v = o - 1; cnt(c) = v;
      hist(o+1) = hist(o+1) - 1; hist(v+1) = hist(v+1) + 1;
      sumSq = sumSq + v*v - o*o;
      if v == 0, nNZ = nNZ - 1; end
      if o == t + 1, nOver = nOver - 1; end
      while curMax > 0 && hist(curMax+1) == 0, curMax = curMax - 1; end

      % entering position s+B-1
      c = cw(s+B-1);
      o = cnt(c); v = o + 1; cnt(c) = v;
      hist(o+1) = hist(o+1) - 1; hist(v+1) = hist(v+1) + 1;
      sumSq = sumSq + v*v - o*o;
      if o == 0, nNZ = nNZ + 1; end
      if v > curMax, curMax = v; end
      if o == t, nOver = nOver + 1; end

      if nOver > 0, nFail = nFail + 1; end
      if curMax > maxErr, maxErr = curMax; end
      sumMax = sumMax + curMax;
      sumCV  = sumCV + dms_cv(B, sumSq, nNZ);
      giniAcc = giniAcc + dms_gini(hist, K, B, cMax); giniN = giniN + 1;
   end

   overT    = nFail  / nPos;
   meanMax  = sumMax / nPos;
   cvLoad   = sumCV  / nPos;
   giniLoad = giniAcc / max(giniN, 1);
end

function c = dms_cv(B, sumSq, nNZ)
% Coefficient of variation of the error load over the codewords that carry any
% error. The window always holds exactly B errors, so the mean over nonzero
% codewords is B/nNZ and only the second moment has to be tracked.
   if nNZ < 2, c = 0; return; end
   mu  = B / nNZ;
   var = sumSq / nNZ - mu * mu;
   if var <= 0, c = 0; else, c = sqrt(var) / mu; end
end

function g = dms_gini(hist, K, B, cMax)
% Gini coefficient of the per-codeword load, read straight off the histogram in
% O(min(B,n)) using the sorted-rank identity
%       G = 2*sum(i*x_i)/(K*sum(x)) - (K+1)/K,   x ascending.
% Counts are bounded by B and the histogram already holds them grouped by
% value, so no sort is needed: the h entries of value c occupy a contiguous
% block of ranks.
   if K < 2 || B == 0, g = 0; return; end
   r = 0; acc = 0;
   for c = 0:cMax
      h = hist(c+1);
      if h == 0, continue; end
      % ranks r+1 .. r+h, so sum of ranks = h*r + h*(h+1)/2
      acc = acc + c * (h * r + h * (h + 1) / 2);
      r = r + h;
   end
   g = 2 * acc / (K * B) - (K + 1) / K;
   if g < 0, g = 0; end
end
