function [L, K] = getLK_S(N, extensionPercentage, minMultiplier)
   % if enforced, extend length by extensionPercentage to reduce error hit probability
   extendedN = ceil(N * (1 + extensionPercentage));

   % [dataLenRS, K] = closestRSEncodedLength(L, extendedN);
   dataLenRS = extendedN;

   % if N is prime then N=N+1 and int-S can be applied as usual.
   if isprime(dataLenRS) 
      dataLenRS = dataLenRS + 1;
   end

   % find 2 greatest common divisiors  
   [uniquePairs, minSumPair, minFactorPair] = findUniqueMultiplierPairs(dataLenRS, minMultiplier);
   K = minSumPair(1); % greater one is K
   L = minSumPair(2); % smaller one is L
end
