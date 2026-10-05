function [N, vectorPadded, Nsc, Nsym, erM] = local_grid(vectorIn, padSymbol, maxExt, who)
%LOCAL_GRID  Shared OFDM grid setup for the frequency interleavers.
%   Builds the Nsc x Nsym grid that interleaver_freqDeterm and
%   interleaver_freqRandom both act on, so the two files cannot drift apart in
%   how they lay out the frame - only in how they permute the subcarrier axis.
%
%   Nsc >= Nsym (more subcarriers than symbols) and Nsym >= 3, so the
%   subcarrier axis is the wide one and there is something to decorrelate
%   across symbols.
%
% R.T. Sirmen harness, 2026

   N = 0; vectorPadded = []; Nsc = 0; Nsym = 0; erM = "";

   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed
      erM = sprintf('%s: Data shape error. Must be (1xN)', who); return;
   end
   N0 = length(vectorIn);
   if N0 < 9
      erM = sprintf('%s: N must be >= 9', who); return;
   end

   maxN = floor(N0 * (1 + maxExt));
   for cand = N0:maxN
      a = 1;
      for c = floor(sqrt(cand)):-1:2
         if mod(cand, c) == 0, a = c; break; end
      end
      if a >= 3
         N = cand; Nsym = a; Nsc = cand / a; break;
      end
   end
   if N == 0
      erM = sprintf('%s: no grid with >= 3 OFDM symbols for N=%d within %.0f%% extension', ...
                    who, N0, maxExt*100);
      return;
   end

   if N > N0
      vectorPadded = [vectorIn, repmat(padSymbol, 1, N - N0)];
   else
      vectorPadded = vectorIn;
   end
end
