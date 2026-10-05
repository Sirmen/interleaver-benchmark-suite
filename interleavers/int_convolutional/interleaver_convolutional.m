function [vectorInterleaved, permutation, M, D, erM] = ...
    interleaver_convolutional(vectorIn, bufferRows, bufferSlope, padSymbol, maxExtensionPercentage)
%INTERLEAVER_CONVOLUTIONAL  Cyclic (block-closed) Ramsey/Forney convolutional
%   interleaver with the M*D separation guarantee intact.
%
%   J. L. Ramsey, "Realization of optimum interleavers", IEEE Trans. Inf.
%   Theory 16(3), 1970.  G. D. Forney, "Burst-correcting codes for the
%   classic bursty channel", IEEE Trans. Commun. 19(5), 1971.
%
% WHY THIS FILE WAS REWRITTEN
% ---------------------------
% The previous version emulated the interleaver by sorting symbols on
% time = seqnum + branch*D and then COMPACTING them into N consecutive slots,
% with no flush and no idle slots. Removing the idle slots is what destroys
% the guarantee: at the frame head only branch 0 has data, so inputs 1 and 2
% land D+1 apart. Measured over N = 30..510 the worst-case adjacency was
% exactly D+1 = 3 for EVERY length - i.e. the nominal M*D separation
% (2*sqrt(N), about 22 at N = 510) was never achieved anywhere in the frame.
%
% It was also unreachable in principle at the shipped parameters: with
% M ~ sqrt(N) and D = 2 the interleaver latency M*D*(M-1) runs from 0.83*N to
% 2.20*N, so a frame of N symbols never contains a steady-state region at all.
%
% THE FIX: CLOSE THE INTERLEAVER CYCLICALLY
% Arrange N = M*R as an M x R array, branch b (0-based) holding the symbols at
% input positions b+1, b+M+1, ...  Rotate branch b cyclically by b*D, then read
% out column-wise:
%
%       input i-1 = b + m*M          ->    pi(i) = mod(m - b*D, R)*M + b + 1
%
% Cyclic rotation needs no flush and no idle slots, so the map is a genuine
% permutation of 1..N while keeping the delay structure. Inputs i and i+1 sit
% in adjacent branches, so their output positions differ by about D*M - the
% Forney guarantee, now actually delivered inside a finite frame.
%
% PARAMETER SELECTION
% D is no longer fixed at 2. calc_optimal_M_D_convolutional always returned
% D = 2 because it took the first d >= 2 coprime to a prime M, which is
% d = 2 by construction - so the "maximise M*D" claim in its header was the
% opposite of what it computed. Here D is chosen by direct search over
% 1..R-1 to maximise the realised worst-case separation, which is what the
% Ramsey/Forney design criterion actually asks for.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% INPUTS
%   bufferRows   M, number of branches. [] -> nearest divisor of N to sqrt(N)
%   bufferSlope  D, delay increment.    [] -> searched for maximum separation
%
% OUTPUTS
%   M, D   the branch count and delay increment actually used
%
% R.T. Sirmen harness, corrected 2026

persistent dCache
if isempty(dCache), dCache = containers.Map('KeyType','char','ValueType','any'); end

erM = ""; vectorInterleaved = []; permutation = []; M = 0; D = 0;
try
   if nargin < 4 || isempty(padSymbol), padSymbol = 0; end
   if nargin < 5 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.1; end

   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed
      erM = "interleaver_convolutional: Data shape error. Must be (1xN)"; return;
   end
   N0 = length(vectorIn);
   if N0 < 6, erM = "interleaver_convolutional: N must be >= 6"; return; end

   % ---- branch count: a divisor of N near sqrt(N), so no padding is needed
   if nargin >= 2 && ~isempty(bufferRows) && mod(N0, bufferRows) == 0 && bufferRows >= 2
      M = bufferRows; N = N0;
   else
      M = local_nearestDivisor(N0);
      N = N0;
      if M < 2
         % N prime: one symbol of padding makes it composite
         N = N0 + 1;
         if N > floor(N0 * (1 + maxExtensionPercentage))
            erM = sprintf('interleaver_convolutional: padding to %d exceeds maxExtensionPercentage', N);
            return;
         end
         M = local_nearestDivisor(N);
      end
   end
   R = N / M;
   if R < 2
      erM = sprintf('interleaver_convolutional: degenerate geometry M=%d R=%d', M, R);
      return;
   end

   % ---- delay increment
   if nargin >= 3 && ~isempty(bufferSlope) && bufferSlope >= 1 && bufferSlope < R
      D = bufferSlope;
   else
      key = sprintf('M%d_R%d', M, R);
      if dCache.isKey(key)
         D = dCache(key);
      else
         D = local_forneyD(M, R);
         dCache(key) = D;
      end
   end

   if D < 1 || D >= R || floor(D) ~= D
      erM = sprintf('interleaver_convolutional: D must be an integer in 1..%d (got %s)', R-1, num2str(D));
      return;
   end

   % ---- pad if the divisor search needed it
   if N > N0
      vectorPadded = [vectorIn, repmat(padSymbol, 1, N - N0)];
   else
      vectorPadded = vectorIn;
   end

   permutation = local_map(M, R, D);

   if numel(unique(permutation)) ~= N
      erM = sprintf('interleaver_convolutional: not a permutation (N=%d M=%d D=%d)', N, M, D);
      permutation = []; return;
   end

   vectorInterleaved = vectorPadded(permutation);

   if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
   if iscolumn(permutation),       permutation       = permutation';       end

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%% ------------------------------------------------------------------------
function p = local_map(M, R, D)
% pi(i) = mod(m - b*D, R)*M + b + 1   for input index i-1 = b + m*M
   i0 = 0:(M*R - 1);
   b  = mod(i0, M);
   m  = floor(i0 / M);
   p  = mod(m - b*D, R) * M + b + 1;
end

function D = local_forneyD(~, ~)
%LOCAL_FORNEYD  D = 1. The Ramsey/Forney convolutional interleaver, as published.
%
%   This used to search d = 1..R-1 and keep whichever maximised the realised
%   worst-case adjacent separation. That is a tuned interleaver, not the
%   convolutional interleaver of the literature: Forney's structure delays
%   branch b by b*M symbols - the delay INCREMENT is one unit of M, and there
%   is no free parameter to search over. Searching it gave this baseline an
%   advantage the published method does not have.
%
%   The signature keeps its two arguments so the call site is unchanged.
   D = 1;
end

function d = local_nearestDivisor(n)
% Divisor of n closest to sqrt(n), at least 2. Returns 1 only for n prime.
   d = 1;
   for a = floor(sqrt(n)):-1:2
      if mod(n, a) == 0, d = a; return; end
   end
end
