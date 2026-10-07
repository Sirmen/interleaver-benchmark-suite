function verify_arp_table(mode)
%VERIFY_ARP_TABLE  Audit of the ARP parameter table over all seventeen block
%   sizes IEEE Std 802.16-2017 tabulates (clause 8.4.9.2.3.2, Tables 8-328
%   and 8-329).
%
%   verify_arp_table           published rows + derived search for N <= 240
%   verify_arp_table('full')   all seventeen, exhaustively
%
% 'full' NEEDS THE MEX. The search is over N^3/32 offset triples: 3.5 million
% at N = 480, 28 million at 960, 432 million at 2400. The MATLAB loops below
% are the readable reference and are usable to about N = 480; past that they
% take days. Build the compiled search once and 'full' finishes in minutes:
%
%       mex arp_derived_search.c
%
% This file calls it when it is on the path and says so; otherwise it refuses
% lengths above 480 rather than appearing to hang.
%
% It prints the three counts Section III-C quotes:
%   1. every published row is a bijection and meets the published constraints;
%   2. how many of the seventeen rows are degenerate (all effective offsets 0);
%   3. for an ARP derived from the published constraints alone, at how many
%      lengths the optimising offsets come out (0,0,0), and how the derived
%      Smin compares with the published one.
%
% Derivation rule, as declared in Section III-C: C = 4 with C | N; P0 the
% coprime of N nearest sqrt(2N); P2 a multiple of 4; P1 and P3 even with
% P1 = P3 (mod 4); offsets chosen to maximise Berrou's Smin.
%
% WHY THE FULL SEARCH IS FEASIBLE AT ALL
% ---------------------------------------------------------------------------
% The search is over N^3/32 offset triples and the obvious Smin costs O(N*s)
% each, which puts N = 2400 out of reach. It is not needed. Write
%
%     p(j) = (P0*j + e_{j mod 4} + 1) mod N,  e = [0, N/2+P1, P2, N/2+P3].
%
% For index distance d the class of j+d is (j+d) mod 4, so within one class
%
%     p(j+d) - p(j) = P0*d + e_{(c+d) mod 4} - e_c   (mod N),
%
% the same value for every j of that class. Both the positive and the negative
% representative occur among those j, so the smallest |difference| at distance
% d is min over the four classes of min(w, N-w). Smin therefore costs O(s)
% from the four offsets alone, with no length-N array: a factor of N.
%
% Even with that, MATLAB loops at N = 2400 take days, because the saving is in
% the per-candidate cost and not in the number of candidates. The compiled
% arp_derived_search does the whole search at N = 2400 in about 90 s.
%
% R.T. Sirmen harness, 2026-10-07

   if nargin < 1, mode = ''; end
   N17 = [24 36 48 72 96 108 120 144 180 192 216 240 480 960 1440 1920 2400];

   fprintf('\n== 1. published rows ==\n');
   nDeg = 0;
   for N = N17
      [~, p, inf_] = interleaver_arp(1:N);
      bij = numel(unique(p)) == N;
      ok  = gcd(inf_.P0,N)==1 && mod(inf_.P2,4)==0 && mod(inf_.P1,2)==0 ...
            && mod(inf_.P3,2)==0 && mod(inf_.P1,4)==mod(inf_.P3,4);
      sSlow = sminSlow(p);
      sFast = sminFast(N, inf_.P0, inf_.P1, inf_.P2, inf_.P3);
      assert(bij && ok, 'row N=%d fails its own constraints', N);
      assert(sSlow == sFast, 'fast Smin disagrees at N=%d', N);   % identity check
      nDeg = nDeg + inf_.degenerate;
      fprintf('N=%5d  bijection=%d  constraints=%d  degenerate=%d  Smin=%d\n', ...
              N, bij, ok, inf_.degenerate, sSlow);
   end
   fprintf('degenerate rows: %d of %d\n', nDeg, numel(N17));

   fprintf('\n== 2. derived ARP (exhaustive) ==\n');
   lim = 240;
   haveMex = exist('arp_derived_search', 'file') == 3;
   if strcmpi(mode,'full')
      if haveMex
         lim = inf;
         fprintf('(using the compiled arp_derived_search)\n');
      else
         lim = 480;
         warning(['arp_derived_search MEX not found; stopping at N = 480. ' ...
                  'Run "mex arp_derived_search.c" to do all seventeen.']);
      end
   end
   nZero = 0; nHigh = 0; nEq = 0; nLow = 0; nRun = 0;
   for N = N17
      if N > lim, continue; end
      [sD, P] = deriveBest(N);
      [~, ~, inf_] = interleaver_arp(1:N);
      sP = sminFast(N, inf_.P0, inf_.P1, inf_.P2, inf_.P3);
      z = all(P(2:4) == 0);
      nZero = nZero + z; nRun = nRun + 1;
      nHigh = nHigh + (sD > sP); nEq = nEq + (sD == sP); nLow = nLow + (sD < sP);
      fprintf('N=%5d  derived Smin=%3d  P=(%d, %d,%d,%d)  zero=%d | published Smin=%3d\n', ...
              N, sD, P(1), P(2), P(3), P(4), z, sP);
   end
   fprintf(['over %d lengths: offsets (0,0,0) at %d; derived Smin higher at %d, ' ...
            'equal at %d, lower at %d\n'], nRun, nZero, nHigh, nEq, nLow);
end

% -------------------------------------------------------------------------
function s = sminSlow(p)
%SMINSLOW  Berrou's minimum spatial distance, straight from the permutation.
   s = inf; d = 1; N = numel(p);
   while d < s && d < N
      s = min(s, d + min(abs(p(1+d:end) - p(1:end-d))));
      d = d + 1;
   end
end

% -------------------------------------------------------------------------
function s = sminFast(N, P0, P1, P2, P3)
%SMINFAST  The same number from the four effective offsets alone. See header.
   e = [0, mod(N/2+P1,N), mod(P2,N), mod(N/2+P3,N)];
   s = inf; d = 1;
   while d < s && d < N
      m = N;
      for c = 0:3
         w = mod(P0*d + e(1+mod(c+d,4)) - e(1+c), N);
         m = min(m, min(w, N-w));
      end
      s = min(s, d + m); d = d + 1;
   end
end

% -------------------------------------------------------------------------
function [best, P] = deriveBest(N)
   P0 = nearestCoprime(N);
   if exist('arp_derived_search', 'file') == 3
      [best, off] = arp_derived_search(N, P0);
      P = [P0 off];
      return;
   end
   half = N/2; best = -1; P = [P0 0 0 0];
   for P1 = 0:2:N-1
      for P3 = mod(P1,4):4:N-1
         for P2 = 0:4:N-1
            e = [0, mod(half+P1,N), P2, mod(half+P3,N)];
            A = mod([1, P0+half+P1+1, 2*P0+P2+1, 3*P0+half+P3+1], 4);
            if numel(unique(A)) ~= 4, continue; end   % bijection test
            s = sminOffsets(N, P0, e, best);
            if s > best, best = s; P = [P0 P1 P2 P3]; end
         end
      end
   end
end

function s = sminOffsets(N, P0, e, bound)
   s = 2*N; d = 1;
   while d < s && d < N
      m = N;
      for c = 0:3
         w = mod(P0*d + e(1+mod(c+d,4)) - e(1+c), N);
         m = min(m, min(w, N-w));
      end
      s = min(s, d + m);
      if s <= bound, return; end      % cannot beat the incumbent
      d = d + 1;
   end
end

function v = nearestCoprime(N)
   t = sqrt(2*N); bestd = inf; v = [];
   for k = 2:N-1
      if gcd(k,N) == 1 && abs(k-t) < bestd, bestd = abs(k-t); v = k; end
   end
end
