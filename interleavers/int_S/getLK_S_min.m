function [L, K, erM] = getLK_S_min(N, minMultiplier, table_primes, table_factors, pairStrategy)
% Choose L,K with minimal extension i.e. providing the squarest matrix
erM = ""; L = 0; K = 0;
adjustedN = N;

try
   pairStrategy = lower(pairStrategy);

   if isInPrimesTable(N, table_primes)
      adjustedN = N + 1;
   end
   
   % [factors, ~] = getFactorPairs(adjustedN, table_factors, minMultiplier);
   [minSumPair, minFactorPair, erM] = getFactorPairs(adjustedN, table_factors, minMultiplier);
   if erM ~= ""
      erM = strcat("Error in getLK_S_min:\n",erM);
      return;
   end
   
   if isempty(minSumPair)
      [uniquePairs, minSumPair, minFactorPair] = findUniqueMultiplierPairs(adjustedN, 2);
   end

   if pairStrategy == "minsum"
      factors_obj = sort(minSumPair, 2);
   else
      factors_obj = sort(minFactorPair, 2);
   end

   L = factors_obj(1);
   K = factors_obj(2);

catch ME
    erM = sprintf("getLK_S_min error: %s", ME.message);
    L = 0; K = 0;
end
end
