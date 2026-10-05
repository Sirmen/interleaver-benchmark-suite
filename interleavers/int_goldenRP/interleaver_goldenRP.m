function [vectorInterleaved, permutation, info, erM] = ...
    interleaver_goldenRP(vectorIn, startOffset)
% Golden relative-prime interleaver.   Crozier, 2000  (harness ref [7]).
%
% A deterministic, length-agnostic, O(N) interleaver built from a single
% stride P placed at the golden ratio of N and forced relatively prime to N:
%
%     permutation(i) = mod( s + (i-1)*P, N ) + 1 ,   gcd(P, N) = 1
%
% The golden stride maximises the minimum gap between successive multiples
% (three-distance theorem), which is why it competes with S-random on spread
% while staying fully deterministic and table-free.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)   (gather index)
% NO PADDING: BE = 1.0 always.
%
% WHY IT IS IN THE BENCHMARK: this is the closest deterministic, zero-overhead,
% arbitrary-length competitor to S-Interleaving. Beating it is what shows the
% structured swapping earns its keep; losing to it would be equally worth
% knowing before a reviewer finds out.
%
% R.T. Sirmen harness integration, 2026

erM = ""; vectorInterleaved = []; permutation = []; info = struct();
try
   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed
      erM = "interleaver_goldenRP: Data shape error. Must be (1xN)"; return;
   end
   N = length(vectorIn);
   if N < 3, erM = "interleaver_goldenRP: N must be >= 3"; return; end
   if nargin < 2 || isempty(startOffset), startOffset = 0; end

   P = local_goldenStride(N);
   permutation = mod(startOffset + (0:N-1) * P, N) + 1;

   if numel(unique(permutation)) ~= N
      erM = sprintf('interleaver_goldenRP: not a permutation (N=%d, P=%d)', N, P);
      permutation = []; return;
   end

   vectorInterleaved = vectorIn(permutation);
   info = struct('P', P, 'startOffset', startOffset);

   if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
   if iscolumn(permutation),       permutation       = permutation';       end

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%% ------------------------------------------------------------------------
function P = local_goldenStride(N)
% Nearest value to N/phi that is relatively prime to N.
   phi = (1 + sqrt(5)) / 2;
   p0  = round(N / phi);
   P   = 0;
   for d = 0:N
      for cand = [p0 - d, p0 + d]
         if cand >= 1 && cand < N && gcd(cand, N) == 1
            P = cand; break;
         end
      end
      if P > 0, break; end
   end
   if P == 0, P = 1; end
end
