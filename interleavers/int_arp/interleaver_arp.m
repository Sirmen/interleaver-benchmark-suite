function [vectorInterleaved, permutation, info, erM] = ...
    interleaver_arp(vectorIn, ~, strideP, offsetsQ)
%INTERLEAVER_ARP  Almost Regular Permutation - published parameters only.
%   C. Berrou, Y. Saouter, C. Douillard, S. Kerouedan, M. Jezequel,
%   "Designing good permutations for turbo codes: towards a single model",
%   IEEE ICC 2004.
%   Standardised as the CTC interleaver of IEEE 802.16 (WiMAX) and as the
%   turbo permutation of DVB-RCS (ETSI EN 301 790, clause 6.4.4.1).
%
% THE STANDARD FORM (level 2)
% ---------------------------------------------------------------------------
%   for j = 0 .. N-1
%       j mod 4 = 0  ->  P = 0
%       j mod 4 = 1  ->  P = N/2 + P1
%       j mod 4 = 2  ->  P = P2
%       j mod 4 = 3  ->  P = N/2 + P3
%   i = (P0*j + P + 1) mod N
%
% Note the asymmetry that is easy to get wrong: P1 and P3 are offset by N/2,
% P2 is not, and the j = 0 class has no offset. The trailing +1 is always
% present.
%
% N MUST BE A MULTIPLE OF 4 - ETSI EN 301 790 cl. 6.4.4.1, verbatim:
%   "The encoder is fed by blocks of k bits or N couples (k = 2*N bits).
%    N is a multiple of 4 (k is a multiple of 8)."
%
% ONLY LEVEL 2 IS APPLIED - DECLARE THIS IN THE PAPER
% ---------------------------------------------------------------------------
% The standards define two levels: level 1 swaps the two bits inside alternate
% duo-binary COUPLES, level 2 permutes the couples. This harness interleaves
% Reed-Solomon symbols over GF(16), not duo-binary couples, so level 1 has no
% counterpart and is omitted. Level 2 is the ARP proper; level 1 is an encoder
% detail of the duo-binary constituent code.
%
% WHY THERE IS NO DERIVATION PATH IN THIS FILE
% ---------------------------------------------------------------------------
% This is the central design decision, and it is a measured result, not a
% preference.
%
% ARP parameters are not given by a formula. Berrou et al. say so outright:
%   "Because these parameters are strongly dependent on the two component
%    codes and on the pattern errors they produce, we are not able yet to
%    provide a systematic way to calculate them."
% Their empirical procedure screens candidates by minimum spatial distance and
% then SELECTS by turbo minimum Hamming distance, measured with the Error
% Impulse Method - a criterion that needs the constituent convolutional codes.
% There is no such criterion in a Reed-Solomon burst channel.
%
% Deriving the offsets from the only channel-relevant criterion available here
% - spread - was tried and rejected on evidence. Using Berrou's own stride
% rule (P0 nearest coprime to sqrt(2N)) and his own S_min criterion over the
% published constraint set, the optimum offsets came out (0,0,0) at ELEVEN of
% the seventeen tabulated lengths. At (0,0,0) every effective offset vanishes
% and the map collapses to i = (P0*j + 1) mod N - a plain relative-prime
% interleaver, i.e. a twin of interleaver_goldenRP with a different stride.
%
% And the derived S_min was NEVER LOWER than the published one - strictly
% higher at 12 of 17 lengths, equal at the other 5:
%       N = 1920 : derived 60 vs published 38
%       N = 1440 : derived 44 vs published 30
%       N =  240 : derived 20 vs published 10
%       N =  108 : derived 12 vs published  6
% If the standard's parameters were chosen to maximise spread, a bounded
% search under that same criterion could not beat them at two thirds of the
% lengths. They were not. They were chosen for turbo distance.
%
% So a "derived ARP" would not be an ARP. It would be a second copy of a
% method already in the benchmark, wearing a standard's name.
%
% A related fact worth reporting: FIVE of the seventeen published rows are
% themselves degenerate. At N = 36, 48, 120, 180 and 216 the tabulated values
% give N/2 + P1 = 0, P2 = 0, N/2 + P3 = 0 (mod N), so the standardised
% interleaver at those lengths IS the plain relative-prime map. Two of them,
% 120 and 180, fall in this study's length set. Genuine dither appears at
% 240, 480, 960, 1440, 1920 and 2400.
%
% CONSEQUENCE FOR THE STUDY: ARP is evaluated only at the lengths where the
% standard defines it. It belongs in the standard-compliant subset table, not
% in the balanced main panel. Any other length returns an error with a message
% saying so - loudly, because a silent fallback is how the previous version
% smuggled Crozier's golden-ratio stride into Berrou's family.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)   (gather index)
% NO PADDING: BE = 1.0 always.
%
% INPUTS
%   arg 2      ignored (C is fixed at 4, the standardised value)
%   strideP    optional P0 override. Supplying it marks info.source = 'user'.
%   offsetsQ   optional [P1 P2 P3] override, likewise.
%
% OUTPUTS
%   info.C / info.P0 / info.P1 / info.P2 / info.P3
%   info.effectiveOffsets   the four (N/2 + Pk) mod N values actually applied
%   info.degenerate         true when all four are zero (plain stride)
%   info.source             'IEEE 802.16' | 'user'
%   info.reference          citation string for the provenance table
%   info.Smin               minimum spatial distance achieved
%
% R.T. Sirmen harness, canonicalised 2026-08; table verified against
% IEEE Std 802.16-2017 and N = 108 added, 2026-10-07

erM = ""; vectorInterleaved = []; permutation = []; info = struct();
try
   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed
      erM = "interleaver_arp: Data shape error. Must be (1xN)"; return;
   end
   N = length(vectorIn);

   if mod(N, 4) ~= 0
      erM = sprintf(['interleaver_arp: N = %d is not a multiple of 4. The ' ...
                     'standardised ARP is undefined here (ETSI EN 301 790 ' ...
                     'cl. 6.4.4.1). No substitute is generated.'], N);
      return;
   end

   [P0, P1, P2, P3, src, ref] = local_published(N);

   if nargin >= 3 && ~isempty(strideP)
      P0 = strideP; src = 'user'; ref = 'user-supplied';
   end
   if nargin >= 4 && ~isempty(offsetsQ)
      if numel(offsetsQ) ~= 3
         erM = "interleaver_arp: offsetsQ must be [P1 P2 P3]"; return;
      end
      P1 = offsetsQ(1); P2 = offsetsQ(2); P3 = offsetsQ(3);
      src = 'user'; ref = 'user-supplied';
   end

   if isempty(P0)
      erM = sprintf(['interleaver_arp: no published parameters for N = %d. ' ...
                     'ARP is evaluated only at standardised lengths ' ...
                     '(24 36 48 72 96 108 120 144 180 192 216 240 480 960 ' ...
                     '1440 1920 2400); see the header for why nothing is ' ...
                     'derived.'], N);
      return;
   end

   if gcd(P0, N) ~= 1
      erM = sprintf('interleaver_arp: gcd(P0,N) must be 1 (N=%d, P0=%d)', N, P0);
      return;
   end

   permutation = local_map(N, P0, P1, P2, P3);

   if numel(unique(permutation)) ~= N
      erM = sprintf('interleaver_arp: not a permutation (N=%d, P=[%d %d %d %d])', ...
                    N, P0, P1, P2, P3);
      permutation = []; return;
   end

   eff = mod([0, N/2 + P1, P2, N/2 + P3], N);

   vectorInterleaved = vectorIn(permutation);
   info = struct('C', 4, 'P0', P0, 'P1', P1, 'P2', P2, 'P3', P3, ...
                 'effectiveOffsets', eff, 'degenerate', all(eff == 0), ...
                 'source', src, 'reference', ref, ...
                 'Smin', local_Smin(permutation, min(32, N-1)));

   if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
   if iscolumn(permutation),       permutation       = permutation';       end

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%% ------------------------------------------------------------------------
function p = local_map(N, P0, P1, P2, P3)
%LOCAL_MAP  The standardised level-2 ARP, vectorised.
%
% Gather convention: output slot j+1 draws from input index i+1, which is what
% the standard's clarified wording means - "Pi(j) provides the interleaved
% address prior to interleaving of the considered couple j" (IEEE 802.16 WG
% maintenance contribution C80216maint-05_149, whose purpose was to remove
% exactly this ambiguity from the published text).
   j  = 0:N-1;
   Pv = zeros(1, N);
   Pv(mod(j,4) == 1) = N/2 + P1;
   Pv(mod(j,4) == 2) = P2;
   Pv(mod(j,4) == 3) = N/2 + P3;
   p = mod(P0 * j + Pv + 1, N) + 1;
end

%% ------------------------------------------------------------------------
function [P0, P1, P2, P3, src, ref] = local_published(N)
%LOCAL_PUBLISHED  The IEEE 802.16 CTC interleaver parameter table.
%
% Columns: N (couples), P0, P1, P2, P3.
%
% SOURCE OF RECORD: IEEE Std 802.16-2017, clause 8.4.9.2.3.2. Every row below
% was read from the standard itself (verified 2026-10-07). The standard splits
% the parameters over two tables and neither alone is complete:
%
%   * Table 8-328, CTC channel coding per modulation, covers
%     N = 24, 36, 48, 72, 96, 108, 120, 144, 180, 192, 216, 240
%   * Table 8-329, the same when supporting IR HARQ, covers
%     N = 24, 48, 72, 96, 144, 192, 240, 480, 960, 1440, 1920, 2400
%
% Seventeen distinct N in the union; N = 240 is in both and the two agree.
% N = 36, 108, 120, 180 and 216 exist ONLY in Table 8-328, which is why a
% copy taken from the HARQ table alone is missing them.
%
% All seventeen rows were verified numerically: each produces a genuine
% bijection under local_map, each has gcd(P0,N) = 1, and each satisfies
% P2 = 0 (mod 4), P1 and P3 even, P1 = P3 (mod 4).
%
% TWO SECONDARY SOURCES DISAGREE WITH THE STANDARD, both at values this file
% does not use:
%   * maintenance contribution C80216maint-05_014r1, Table 327, gives
%     P2 = 160 at N = 240 where the standard gives 60. The standard wins.
%   * the 2004 TGd proposal C80216d-04_23 lists different values for N >= 480.
%     Those were replaced during 2005 maintenance and are obsolete.
% US patent US20110113307A1 (Samsung), Table 1, and ATSC A/323:2024 both agree
% with the standard on every row they share with it.
   T = [  24    5    0    0    0
          36   11   18    0   18
          48   13   24    0   24
          72   11    6    0    6
           96    7   48   24   72
         108   11   54   56    2
         120   13   60    0   60
         144   17   74   72    2
         180   11   90    0   90
         192   11   96   48  144
         216   13  108    0  108
         240   13  120   60  180
         480   53   62   12    2
         960   43   64  300  824
        1440   43  720  360  540
        1920   31    8   24   16
        2400   53   66   24    2 ];

   k = find(T(:,1) == N, 1);
   if isempty(k)
      P0 = []; P1 = []; P2 = []; P3 = []; src = ''; ref = '';
   else
      P0 = T(k,2); P1 = T(k,3); P2 = T(k,4); P3 = T(k,5);
      src = 'IEEE 802.16';
      ref = 'IEEE Std 802.16, CTC interleaver (cl. 8.4.9.2.3.2)';
   end
end

%% ------------------------------------------------------------------------
function s = local_Smin(p, ~)
%LOCAL_SMIN  Berrou's minimum spatial distance, over ALL pairs.
%       S_min = min over i /= j of ( |i - j| + |Pi(i) - Pi(j)| )
%
%   No fixed window. A pair at index distance d contributes at least d + 1, so
%   growth can stop once d reaches the best value found so far - but not
%   before. A constant cap under-reports (reports too large a minimum) exactly
%   when the answer exceeds the cap, which is the regime that matters at large
%   N. The loop below terminates at d = s, so the cost is O(N*s).
   s = inf; d = 1; N = numel(p);
   while d < s && d < N
      s = min(s, d + min(abs(p(1+d:end) - p(1:end-d))));
      d = d + 1;
   end
end
