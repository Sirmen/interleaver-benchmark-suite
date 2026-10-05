function [L, K, erM] = getLK_strategy(factors, pairStrategy)
% returns L and K based on the pairStrategy i.e. "minSum" or "minL"
erM = ""; L = 0; K = 0;
try
   pairStrategy = lower(pairStrategy);
   % Ensure factors is sorted with L <= K for each pair
   factors_sorted = sort(factors, 2);
   if pairStrategy == "minsum"
      % Find row with minimum sum
      [~, idx] = min(sum(factors_sorted, 2));
      L = factors_sorted(idx, 1);
      K = factors_sorted(idx, 2);
   else % "minl" strategy
      % Find row with minimum L
      [~, idx] = min(factors_sorted(:, 1));
      L = factors_sorted(idx, 1);
      K = factors_sorted(idx, 2);
   end
catch ME
   erM = sprintf("getLK error: %s", ME.message);
   L = 0; K = 0;
end
end
