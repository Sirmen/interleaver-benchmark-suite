function [minSumPair, minFactorPair, erM] = getFactorPairs(n, factor_data, minFactor)
% Get minSum and minFactor pairs for number n
% If no factors satisfy >= minFactor, decrement minFactor until at least 2
%
% ONE FIX, 2026: THE NO-CACHE BRANCH COULD NOT ACTUALLY DECREMENT
% ---------------------------------------------------------------------------
% Both branches below are written the same way - loop while currentMinFactor
% >= 2, stop as soon as a valid pair set appears. That works in the cached
% branch, where the filter simply returns an empty matrix when nothing
% qualifies.
%
% It could not work in the else branch, because findUniqueMultiplierPairs does
% not RETURN empty when the constraint cannot be met - it THROWS:
%
%     error("findUniqueMultiplierPairs: minMultiplier (%d) cannot be satisfied.", ...)
%     error("findUniqueMultiplierPairs: N (%d) is prime.", N)
%
% The exception escaped the while loop, was caught by the function-level
% try/catch at the bottom, and came back as
%     "getFactorPairs error: findUniqueMultiplierPairs: minMultiplier (3) cannot be satisfied."
% on the FIRST iteration - so currentMinFactor never reached 2 and the
% documented fallback never ran once. For n = 2p (34, 38, 46, ...) the only
% factor pair is (2, p), so minFactor = 3 always throws and those lengths were
% rejected outright.
%
% The call is now wrapped: a throw is treated as "no pairs at this
% minFactor", which is what the loop was always written to expect. The cached
% branch is unchanged.
%
% This only bites when factor_data lacks the n<N> record. Two ways that
% happens: the length is outside the generated range, or factor_data is not
% the struct getFactorPairs expects - note that PrimeFactor_PrecomputedLoader
% returns a struct holding ONLY a .divs map and drops the n<N> records
% entirely, so everything routed through that loader takes this branch.
erM = ""; minSumPair=[]; minFactorPair=[];
try    
   cache_key = sprintf('n%d', n);
   
   if isfield(factor_data, cache_key)
      data = factor_data.(cache_key);
      all_pairs = data.all_pairs;
        
      % Try with decreasing minFactor until we find valid pairs
      currentMinFactor = minFactor;
      valid_pairs = [];
      
      while currentMinFactor >= 2
         valid_pairs = all_pairs(all_pairs(:,1) >= currentMinFactor & all_pairs(:,2) >= currentMinFactor, :);
         if ~isempty(valid_pairs)
            break; % Found valid pairs
         end
         currentMinFactor = currentMinFactor - 1;
      end
      
      if isempty(valid_pairs)
         erM = sprintf('No factor pairs found with minimum factor >= 2 for number %d', n);
         return
      end
      
      % Use the found valid pairs
      all_pairs = valid_pairs;
   
      % Find minSum pair (smallest L + K)
      [L, K, erM] = getLK_strategy(all_pairs, "minsum");
      if erM ~= ""
         erM = strcat("Error in getFactorPairs:\n",erM);
         return;
      end
      minSumPair = [L K];
      
      % Find minFactor pair (pair with the smallest minimum factor)
      [L, K, erM] = getLK_strategy(all_pairs, "minl");
      if erM ~= ""
         erM = strcat("Error in getFactorPairs:\n",erM);
         return;
      end
      minFactorPair = [L K];
              
   else % if isfield(factor_data, cache_key)
      % For non-cached case, try with decreasing minFactor
      currentMinFactor = minFactor;
      uniquePairs = [];
      minSumPair_temp = [];
      minFactorPair_temp = [];
      
      while currentMinFactor >= 2
         try
            [uniquePairs, minSumPair_temp, minFactorPair_temp] = ...
               findUniqueMultiplierPairs(n, currentMinFactor);
         catch
            % findUniqueMultiplierPairs throws instead of returning empty when
            % the constraint cannot be met (and when n is prime). Same meaning
            % as an empty result for this loop - keep decrementing.
            uniquePairs = [];
         end
         if ~isempty(uniquePairs)
            break; % Found valid pairs
         end
         currentMinFactor = currentMinFactor - 1;
      end
      
      if isempty(uniquePairs)
         erM = sprintf('No factor pairs found with minimum factor >= 2 for number %d', n);
         return
      end
      
      minSumPair = minSumPair_temp;
      minFactorPair = minFactorPair_temp;
   end

catch ME
    erM = sprintf("getFactorPairs error: %s", ME.message);
end
end
