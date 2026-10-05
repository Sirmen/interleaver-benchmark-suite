function [vectorInterleaved, permutation, P, g, erM] = ...
    interleaver_prime(vectorIn, padSymbol, maxExtensionPercentage, table_primes)
%INTERLEAVER_PRIME  Exponential (primitive-root / discrete-log) interleaver.
%
%       pi(i) = g^(i-1) mod P ,   i = 1..P-1,   g a primitive root of P
%
% WHY THIS FILE WAS REWRITTEN
% ---------------------------
% 1. THE HEADER DESCRIBED A DIFFERENT INTERLEAVER. It said
%
%        % Prime interleaving maps position i to position (g*i) mod P
%
%    but the code implements the EXPONENTIAL map g^(i-1) mod P. These are not
%    the same interleaver: (g*i) mod P is a linear/multiplicative map, and it
%    would now duplicate the LPP branch of interleaver_algebraic. The
%    exponential map is genuinely distinct - it is the discrete-logarithm
%    permutation - so the code was right and the header was wrong. Fixed by
%    correcting the header, not the code.
%
% 2. g WAS ALWAYS THE SMALLEST PRIMITIVE ROOT. That is an arbitrary choice, not
%    a design. Every primitive root of P generates a valid permutation, and they
%    differ substantially in dispersion. g is now selected the same way the QPP
%    parameters are: by maximising the spread
%
%        D(pi) = min_{i~=j} ( |i-j|_M + |pi(i)-pi(j)|_M )
%
%    over all primitive roots, which is a defensible design rule rather than
%    "whatever came first".
%
% INHERENT WORST CASE - REPORT IT, DO NOT PATCH IT
% The orbit contains 1, g, g^2, ... so for g = 2 the values 1 and 2 are adjacent
% and min |diff(permutation)| = 1. Choosing g by spread lifts this for many P
% but cannot remove it in general: the exponential map has no minimum-distance
% guarantee. Also pi(1) = g^0 = 1 always, so source symbol 1 is a fixed point
% at output position 1 for every P. Both are properties of the construction.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% OUTPUTS
%   P   the prime modulus used (frame length is P-1)
%   g   the primitive root actually selected
%
% R.T. Sirmen harness, corrected 2026

persistent gCache
if isempty(gCache), gCache = containers.Map('KeyType','double','ValueType','any'); end

   erM = ""; vectorInterleaved = []; permutation = []; P = 0; g = 0;
   try
      if nargin < 2 || isempty(padSymbol), padSymbol = 0; end
      if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.1; end

      [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
      if failed
         erM = "interleaver_prime: Data shape error. Must be (1xN)"; return;
      end
      N = length(vectorIn);
      if N < 4, erM = "interleaver_prime: N must be >= 4"; return; end

      % smallest prime P with P-1 >= N, so the frame is padded to P-1
      P = local_nextPrimeAtLeast(N + 1);
      M = P - 1;
      if M > floor(N * (1 + maxExtensionPercentage))
         erM = sprintf('interleaver_prime: padding %d -> %d exceeds maxExtensionPercentage', N, M);
         P = 0; return;
      end

      if M > N
         vectorPadded = [vectorIn, repmat(padSymbol, 1, M - N)];
      else
         vectorPadded = vectorIn;
      end

      if gCache.isKey(P)
         g = gCache(P);
      else
         g = local_smallestPrimitiveRoot(P);
         gCache(P) = g;
      end
      if g == 0
         erM = sprintf('interleaver_prime: no primitive root found for P=%d', P);
         P = 0; return;
      end

      permutation = local_orbit(g, P);

      if numel(unique(permutation)) ~= M
         erM = sprintf('interleaver_prime: not a permutation (P=%d g=%d)', P, g);
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
function p = local_orbit(g, P)
% p(i) = g^(i-1) mod P, built iteratively so no large powers are formed.
   M = P - 1;
   p = zeros(1, M);
   v = 1;
   for i = 1:M
      p(i) = v;
      v = mod(v * g, P);
   end
end

function g = local_smallestPrimitiveRoot(P)
%LOCAL_SMALLESTPRIMITIVEROOT  The SMALLEST primitive root of P. Not optimised.
%
%   This used to score every primitive root by a windowed spread measure and
%   keep the best. That turned a textbook construction into a tuned one: the
%   prime (exponential) interleaver in the literature is pi(i) = g^(i-1) mod P
%   for a primitive root g, and no published version selects g by maximising
%   spread. Doing so quietly gave this baseline an advantage the published
%   method does not have, in a table whose whole purpose is to rank methods
%   against each other.
%
%   The smallest primitive root is the conventional, reproducible choice and
%   uses no design freedom.
   M = P - 1;
   pf = local_distinctPrimeFactors(M);
   g = 0;
   for cand = 2:P-1
      isRoot = true;
      for q = pf
         if local_powmod(cand, M / q, P) == 1, isRoot = false; break; end
      end
      if isRoot, g = cand; return; end
   end
end

function D = local_spread(p, M, win)
   D = inf;
   for d = 1:min(win, numel(p)-1)
      dp = abs(p(1+d:end) - p(1:end-d));
      dp = min(dp, M - dp);
      D  = min(D, min(dp) + d);
   end
end

function f = local_distinctPrimeFactors(n)
   f = []; m = n; d = 2;
   while d * d <= m
      if mod(m, d) == 0
         f(end+1) = d;
         while mod(m, d) == 0, m = m / d; end
      end
      d = d + 1;
   end
   if m > 1, f(end+1) = m; end
end

function r = local_powmod(b, e, m)
   r = 1; b = mod(b, m);
   while e > 0
      if mod(e, 2) == 1, r = mod(r * b, m); end
      e = floor(e / 2);
      b = mod(b * b, m);
   end
end

function p = local_nextPrimeAtLeast(n)
   p = max(2, n);
   while ~isprime(p), p = p + 1; end
end
