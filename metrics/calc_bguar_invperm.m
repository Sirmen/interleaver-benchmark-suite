function [Bguar, kWorst] = calc_bguar_invperm(perm, n, t)
%CALC_BGUAR_INVPERM  Guaranteed correctable burst length of a permutation.
%
%   [Bguar, kWorst] = calc_bguar_invperm(perm, n, t)
%
%   Bguar is the largest burst length B such that NO burst of length B, at ANY
%   start position, can place more than t errors in any codeword:
%
%       Bguar = max { B : max_{s,k} e_k(s,B) <= t }
%
% CLOSED FORM
% ---------------------------------------------------------------------------
% Let codeword k own the transmission positions p_{k,1} < ... < p_{k,n}. A
% burst of length B starting at s covers [s, s+B-1], so it delivers t+1 or
% more errors to codeword k exactly when some window of length B contains t+1
% of that codeword's positions, i.e. when p_{k,j+t} - p_{k,j} <= B-1 for some
% j. The guarantee therefore survives at B iff
%
%       B <= min_k min_{j=1..n-t} ( p_{k,j+t} - p_{k,j} )
%
% and Bguar is that minimum. One O(N) pass, no search over B, no realization.
%
% WHY IT IS NOT A RESTATEMENT OF overT OR maxErrCW
% ---------------------------------------------------------------------------
% overT(B) and maxErrCW(B) are read at a DECLARED burst length. Bguar is the
% largest B at which overT is still exactly zero, which is a different
% functional of the same load surface: two permutations can agree on overT at
% B = 12n and differ in Bguar, because overT at one B says nothing about where
% the first failure appears. The relation is "Bguar = sup{B : overT(B) = 0}",
% not a monotone transform of overT at a fixed B.
%
% WHY IT IS WORTH HAVING
% ---------------------------------------------------------------------------
% It is the classical burst-correction guarantee of Ramsey and Forney, stated
% for an ARBITRARY permutation rather than for the matrix or delay-line
% structures the classical results assume. It is a priori and (n,t)-aware, so
% it falls in the cell the manuscript reports as holding overT alone.
%
% SELF-CHECK THAT FIXES THE CONVENTION
% ---------------------------------------------------------------------------
% For a block interleaver with one codeword per row of a K-by-n matrix, read
% by columns, codeword k occupies positions k, k+K, ..., k+(n-1)K, so every
% p_{k,j+t} - p_{k,j} equals t*K and Bguar = t*K. That is exactly the depth-I
% guarantee I*t of [3], [4] with I = K. A result that is not t*K for blockCM
% means the codeword map below does not match the harness convention.
%
% CONVENTION
% ---------------------------------------------------------------------------
% Gather, as everywhere in the harness: interleaved position i carries source
% symbol perm(i). The codeword of a source symbol s is ceil(s/n), so the
% codeword seen at position i is ceil(perm(i)/n). Source symbols are 1-based.

   p = double(perm(:)).';
   N = numel(p);
   Bguar = NaN; kWorst = NaN;
   if N < 2 || n < 1 || t < 0, return; end
   if n <= t
      % Every codeword is shorter than the capacity: nothing can exceed t.
      Bguar = N; return;
   end

   cw = ceil(p / n);                 % codeword index carried at each position
   K  = max(cw);

   % Group the transmission positions by codeword with one sort. sort is stable
   % in both MATLAB and Octave, so within each group the positions come out in
   % ascending transmission order, which is what the closed form needs.
   [cws, ord] = sort(cw(:));
   bnd = [0; find(diff(cws)); numel(cws)];   % group k spans bnd(k)+1 : bnd(k+1)

   Bguar = inf;
   for k = 1:numel(bnd)-1
      q = ord(bnd(k)+1 : bnd(k+1)).';
      m = numel(q);
      if m <= t, continue; end       % a short codeword can never exceed t
      g = min(q(1+t:m) - q(1:m-t));
      if g < Bguar, Bguar = g; kWorst = cws(bnd(k)+1); end
   end

   if isinf(Bguar), Bguar = N; kWorst = NaN; end
end
