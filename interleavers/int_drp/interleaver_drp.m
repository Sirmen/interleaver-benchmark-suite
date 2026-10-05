function [vectorInterleaved, permutation, info, erM] = ...
    interleaver_drp(vectorIn, ditherM, stridep)
%INTERLEAVER_DRP  Dithered Relative Prime interleaver.
%   S. Crozier and P. Guinand, "High-Performance Low-Memory Interleaver Banks
%   for Turbo-Codes", Proc. 54th IEEE VTC (VTC 2001-Fall), Atlantic City,
%   Oct. 2001, pp. 2394-2398.  Patent US6857087B2.
%
% THE CONSTRUCTION, AS THE PAPER WRITES IT
% ---------------------------------------------------------------------------
%   I_a(i) = R*floor(i/R) + r[i mod R]        read dither,  period R
%   I_b(i) = (s + i*p) mod K                  relative prime stride
%   I_c(i) = W*floor(i/W) + w[i mod W]        write dither, period W
%   I(i)   = I_a( I_b( I_c(i) ) )
%
% with r a permutation of {0..R-1}, w a permutation of {0..W-1}, and
% gcd(p,K) = 1.
%
% THE LENGTH CONSTRAINT IS NOT OPTIONAL. The paper, verbatim:
%   "The interleaver length, K, must be a multiple of both R and W."
% The previous version of this file violated it: W was fixed at 8 whether or
% not it divided K, and the trailing partial block was left in place. That was
% flagged in its own header as a "generalisation"; it is not DRP.
%
% This file uses the case the papers themselves prefer, M = R = W:
%   "This case offers the largest amount of dither for the smallest number of
%    index increments" ... "more convenient and has generally been found to
%    give better distance results."
%
% THE STRIDE IS NOT GOLDEN. THIS WAS THE PREVIOUS VERSION'S OTHER DEFECT.
% ---------------------------------------------------------------------------
% The earlier implementation chose p as the coprime nearest K/phi. That is
% Crozier's rule for a DIFFERENT interleaver - the golden relative prime
% construction of US6339834B1, which is already in this benchmark as
% interleaver_goldenRP. In the DRP paper and patent the word "golden" appears
% only in a background sentence citing that earlier, separate work.
%
% What the DRP sources actually say about p:
%   "a simple relative prime (RP) interleaver can be defined by just one other
%    parameter, p, the modulo-K index increment ... p and K are relative
%    primes"
%   "...then just OPTIMIZING OVER p for each interleaver length."
% So p is a search variable with a single algebraic constraint, gcd(p,K) = 1.
% The only concrete DRP parameter sets published anywhere (Garzon Bohorquez,
% Abdel Nour, Douillard, IEEE WCL 2015, Table I) confirm this: K = 784 with
% p = 25 and 33, K = 6144 with p = 263 and 107. None is near K/phi
% (784/phi = 484.5, 6144/phi = 3797.5).
%
% WHY THE DITHERS ARE SEARCHED HERE RATHER THAN LOOKED UP
% ---------------------------------------------------------------------------
% Crozier and Guinand publish no numeric dither vectors - not in the VTC
% paper, not in the patent, which had every incentive to be enabling. The
% design procedure is explicitly a search:
%   "selecting a small number of 'good' dither combinations (r, w, and s) and
%    then just optimizing over p for each interleaver length"
%   "Distance testing is used to help select the dither parameters."
% and a Crozier-co-authored paper states the search is not even exhaustive:
%   "an exhaustive search with WS=8 is impossible in a reasonable time ...
%    thus, the search was limited to randomly selected dither patterns."
%   (Ould-Cheikh-Mouhamedou, Crozier & Kabal, GLOBECOM 2004)
%
% So there is no table to look up and no formula to apply. What IS published
% is the structure, the constraint set, and the scoring metric. This file
% therefore re-runs Crozier's own procedure under Crozier's own criterion -
% the combined spread introduced in his 2000 Kingston paper,
%       S_new(i,j) = |I(i) - I(j)| + |i - j|,  minimised over pairs, maximised
%                                              over candidates
% - with a bounded, seedless, fully deterministic search. This reproduces a
% published design procedure; it does not invent a new one. The paper must say
% so, and must not present these as Crozier and Guinand's own interleavers.
%
% Contrast with interleaver_arp, where the analogous move was rejected: ARP's
% dither is selected by turbo minimum Hamming distance, a criterion with no
% counterpart here, and optimising ARP for spread collapses it to a plain
% stride. DRP's published criterion IS spread, so re-searching under it is
% faithful.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)   (gather index)
% NO PADDING: BE = 1.0 always.
%
% INPUTS
%   ditherM  dither period M = R = W. [] -> selected by local_period.
%   stridep  stride override. [] -> searched.
%
% OUTPUTS
%   info.M / info.p / info.s / info.r / info.w / info.Snew
%   info.source     'searched' | 'user'
%   info.reference  citation string for the provenance table
%
% R.T. Sirmen harness, canonicalised 2026-08

erM = ""; vectorInterleaved = []; permutation = []; info = struct();
try
   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed
      erM = "interleaver_drp: Data shape error. Must be (1xN)"; return;
   end
   K = length(vectorIn);
   if K < 16, erM = "interleaver_drp: K must be >= 16"; return; end

   % Bind the optional stride BEFORE it is passed anywhere. Referencing an
   % unsupplied argument inside a call expression raises "undefined" before
   % the callee is entered, which is exactly how this failed the first time.
   if nargin < 3, stridep = []; end

   % ---- dither period ------------------------------------------------------
   if nargin >= 2 && ~isempty(ditherM)
      M = ditherM;
      if mod(K, M) ~= 0
         erM = sprintf('interleaver_drp: M = %d does not divide K = %d (paper requires R|K and W|K)', M, K);
         return;
      end
   else
      M = local_period(K);
      if M == 0
         erM = sprintf(['interleaver_drp: no admissible dither period for K = %d. ' ...
                        'DRP requires R|K and W|K; none of {16,8,4} divides it.'], K);
         return;
      end
   end

   % ---- search -------------------------------------------------------------
   [p, s, r, w, Snew] = local_search(K, M, stridep);
   if isempty(p)
      erM = sprintf('interleaver_drp: no coprime stride found in the search band (K=%d)', K);
      return;
   end

   permutation = local_map(K, M, p, s, r, w);

   if numel(unique(permutation)) ~= K
      erM = sprintf('interleaver_drp: not a permutation (K=%d, M=%d, p=%d)', K, M, p);
      permutation = []; return;
   end

   vectorInterleaved = vectorIn(permutation);
   info = struct('M', M, 'p', p, 's', s, 'r', r, 'w', w, 'Snew', Snew, ...
                 'source', 'searched', ...
                 'reference', ['Crozier & Guinand, VTC 2001-Fall (structure); ' ...
                               'dithers re-searched under Crozier''s S_new - ' ...
                               'the published dithers are not available']);

   if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
   if iscolumn(permutation),       permutation       = permutation';       end

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%% ------------------------------------------------------------------------
function M = local_period(K)
%LOCAL_PERIOD  Dither period, from the published size guidance.
%
% Ould-Cheikh-Mouhamedou, CROZIER & Kabal, GLOBECOM 2004 - Crozier is a
% co-author, so this is the authors' own recommendation:
%   "A WS of 4 works well for short blocks (e.g., K < 200) and a WS of 8 is
%    better for medium blocks (e.g., 200 <= K <= 1000)."
% The VTC 2001 paper itself uses M = 8 for K = 512..2048 and M = 16 for
% K = 4096 and 8192, so 16 is the published choice above the medium range.
%
% The chosen value must divide K (R|K, W|K). If it does not, step down through
% the published set {16,8,4} to the largest that does - a declared fallback,
% not a new rule. Nothing outside {16,8,4} is ever used.
   if     K < 200,   want = 4;
   elseif K <= 1000, want = 8;
   else,             want = 16;
   end
   ladder = [16 8 4];
   ladder = ladder(ladder <= want);
   M = 0;
   for c = ladder
      if mod(K, c) == 0, M = c; return; end
   end
end

%% ------------------------------------------------------------------------
function p = local_map(K, M, p_, s, r, w)
%LOCAL_MAP  I(i) = I_a( I_b( I_c(i) ) ), vectorised, 1-based on output.
   i  = 0:K-1;
   ic = M * floor(i / M) + w(mod(i, M) + 1);          % write dither
   ib = mod(s + ic * p_, K);                          % relative prime stride
   ia = M * floor(ib / M) + r(mod(ib, M) + 1);        % read dither
   p  = ia + 1;
end

%% ------------------------------------------------------------------------
function [p, s, r, w, best] = local_search(K, M, pFixed)
%LOCAL_SEARCH  Bounded, deterministic, seedless reconstruction of Crozier's
%              design procedure.
%
% DITHER BANK. r and w are drawn from the affine permutations of {0..M-1},
%       k -> (a*k + b) mod M ,   gcd(a,M) = 1 ,   0 <= b < M
% This is a closed, enumerable family of M*phi(M) permutations (8 for M = 4,
% 32 for M = 8, 128 for M = 16) that contains the identity, all cyclic shifts
% and all reversals. Choosing a bank at all is forced on us - the published
% dithers do not exist in the literature - so the bank is declared here and
% listed in the paper rather than left implicit.
%
% STRIDE BAND. p ranges over the coprimes of K in
%       [ floor(sqrt(K)/2) , ceil(4*sqrt(K)) ]
% This band is not arbitrary: it contains ALL FOUR of the DRP strides that
% appear anywhere in the literature (K = 784, p = 25 and 33, band [14,112];
% K = 6144, p = 263 and 107, band [39,314]). Sweeping every coprime in
% [2,K-2] is affordable at these lengths but adds nothing, since large p is
% equivalent to small K-p under the spread metric.
%
% SEARCH. Greedy coordinate ascent on (p, s, r, w), two passes over p, scored
% by Crozier's combined spread S_new. Greedy because the joint space is
% |bank|^2 * |p| * M, which is exactly the intractability that drove the
% original authors to a partial search. Deterministic order, no RNG, so the
% result is a function of (K, M) alone and is reproducible by a third party.
%
% TIE-BREAKING. Strictly-greater comparison throughout, with candidates
% enumerated in a fixed order, so ties resolve to the first candidate.

   win  = min(16, K-1);
   bank = local_affineBank(M);
   nB   = size(bank, 1);

   % --- stride candidates
   lo = max(2, floor(sqrt(K)/2));
   hi = min(K-2, ceil(4*sqrt(K)));
   cand = lo:hi;
   cand = cand(gcd(cand, K) == 1);
   if ~isempty(pFixed), cand = pFixed; end
   if isempty(cand), p = []; s = 0; r = []; w = []; best = -inf; return; end

   % --- initialise at identity dithers, s = 0
   idn = 0:M-1;
   r = idn; w = idn; s = 0;

   best = -inf; p = cand(1);
   for pass = 1:2
      % (1) stride
      for c = cand
         v = local_Snew(local_map(K, M, c, s, r, w), win);
         if v > best, best = v; p = c; end
      end
      % (2) start offset
      for cs = 0:M-1
         v = local_Snew(local_map(K, M, p, cs, r, w), win);
         if v > best, best = v; s = cs; end
      end
      % (3) read dither
      for b = 1:nB
         v = local_Snew(local_map(K, M, p, s, bank(b,:), w), win);
         if v > best, best = v; r = bank(b,:); end
      end
      % (4) write dither
      for b = 1:nB
         v = local_Snew(local_map(K, M, p, s, r, bank(b,:)), win);
         if v > best, best = v; w = bank(b,:); end
      end
   end
end

%% ------------------------------------------------------------------------
function B = local_affineBank(M)
%LOCAL_AFFINEBANK  All k -> (a*k + b) mod M with gcd(a,M) = 1, in fixed order.
   as = 1:M-1; as = as(gcd(as, M) == 1);
   B  = zeros(numel(as) * M, M);
   n  = 0;
   k  = 0:M-1;
   for a = as
      for b = 0:M-1
         n = n + 1;
         B(n, :) = mod(a * k + b, M);
      end
   end
   B = B(1:n, :);
end

%% ------------------------------------------------------------------------
function s = local_Snew(p, ~)
%LOCAL_SNEW  Crozier's combined spread, minimised over ALL pairs.
%   S. Crozier, "New high-spread high-distance interleavers for turbo-codes",
%   20th Biennial Symp. Communications, Kingston, 2000:
%       S_new = min over i /= j of ( |I(i) - I(j)| + |i - j| )
%
%   THE SWEEP MUST NOT USE A FIXED WINDOW. A pair at index distance d
%   contributes at least d + 1, so once d reaches the best value found so far
%   no larger d can improve it - but until then it can. Capping d at a
%   constant (16 or 32) silently reports a value larger than the true minimum
%   whenever the answer exceeds the cap, and the error grows with K exactly
%   where the metric matters most. Measured before this fix: reported S_new
%   reached 2.29x floor(sqrt(2K)), i.e. well past Crozier's own upper bound of
%   about sqrt(2K) - which is what exposed the bug.
%
%   Growing d while d < s is both correct and cheap: the loop stops at
%   d = s, so the cost is O(K*s) with s = O(sqrt(K)), not O(K^2).
   s = inf; d = 1; N = numel(p);
   while d < s && d < N
      s = min(s, d + min(abs(p(1+d:end) - p(1:end-d))));
      d = d + 1;
   end
end
