function [uniquePairs, minSumPair, minFactorPair] = findUniqueMultiplierPairs(N, minMultiplier)
% Finds all (a,b) such that a*b=N, a >= b >= minMultiplier (if given)
% T.Sirmen 2024 
%  2025: Enhanced with minFactorPair and faster divisor-based factorization
%
% First finds all unique (a,b) pairs with a * b = N, a ≥ b
% Then applies minMultiplier filtering, and return best pairs
%
% Inputs:
%   - N: integer to factor
%   - minMultiplier: exclude pairs containing a factor < minMultiplier
%        minMultiplier > 0
%        minMultiplier must be integer, rounds to closest integer towards 0
%           e.g. minMultiplier = 2.6 is will be minMultiplier = 2
% Outputs:
%   - uniquePairs: all valid (a,b) pairs such that a*b = N
%   - minSumPair: pair with minimum (a+b), that is the most square-ish a&b
%   shape
%   - minFactorPair: pair with smallest factor >= minMultiplier

   uniquePairs = [];
   minSumPair = [];
   minFactorPair = [];

   if isprime(N)
      error("findUniqueMultiplierPairs: N (%d) is prime.", N);
   end

   if nargin < 2 || isempty(minMultiplier), minMultiplier = 1; end
   if minMultiplier < 1
      minMultiplier = 1;
      warning("findUniqueMultiplierPairs: minMultiplier must be > 0. Assumed 1.");
   end
   minMultiplier = fix(minMultiplier); 

   if N < minMultiplier^2
      error("findUniqueMultiplierPairs: minMultiplier (%d) cannot be satisfied.", minMultiplier);
   end

   % Step 1: Get divisors
   dList = divisors(N);

   % Step 2: Keep only divisors >= minMultiplier
   dList = dList(dList >= minMultiplier);

   % Step 3: Create unique (a,b) pairs where a >= b and a*b = N
   for i = 1:length(dList)
      b = dList(i);
      a = N / b;
      if a < b || mod(a,1) ~= 0
         continue;
      end
      uniquePairs = [uniquePairs; a, b];
   end

   if isempty(uniquePairs)
      error("findUniqueMultiplierPairs: minMultiplier (%d) cannot be satisfied.", minMultiplier);
   end

   % Step 4: Find minSumPair and minFactorPair
   minSum = inf;
   minFac = inf;
   
   for k = 1:size(uniquePairs, 1)
      a = uniquePairs(k, 1);
      b = uniquePairs(k, 2);
      s = a + b;
      f = min(a, b);
      
      if s < minSum
         minSum = s;
         minSumPair = [a, b];
      end
      if f < minFac
         minFac = f;
         minFactorPair = [a, b];
      end
   end
end
