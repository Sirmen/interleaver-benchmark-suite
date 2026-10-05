function L = estimate_L_for_size(N)
% Estimate a reasonable L value for given size N
% This is a heuristic - it can be adjusted based on specific needs
   extensionPercentage = 0;
   minMultiplier = 2;
   [L, ~] = getLK_S(N, extensionPercentage, minMultiplier);
end
