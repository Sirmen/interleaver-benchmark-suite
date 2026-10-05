function uniformityScore = calcUniformityScore(data)
% Calculates how uniformly distributed 'data', using Chi-square statistic.
%   Returns a normalized uniformity score in [0,1] (1 = perfectly uniform).
%
%   Input:
%       data - Input data vector (integer or real-valued)
%   Output:
%       uniformityScore - Normalized score between 0 and 1

    % Input validation
    data = data(:);  % Ensure column vector
    N = length(data);
    
    if N == 0
        uniformityScore = NaN;
        return;
    end

    % Get bin edges and expected counts
    [binEdges, expectedCount] = decideBinningStrategy(data, N);
    
    % Compute observed histogram
    observed = histcounts(data, binEdges);
    
    % Calculate uniformity score
   % Calculate the normalized uniformity score
   expected = ones(1, length(observed)) * expectedCount;
   
   % Avoid division by zero
   validBins = expected > 0;
   if ~any(validBins)
      uniformityScore = NaN;
      return;
   end
   
   % Chi-square statistic
   chiSq = sum((observed(validBins) - expected(validBins)).^2 ./ expected(validBins));
   
   % Normalize: worst-case chiSq is when all data falls into 1 bin
   maxChiSq = sum(expected(validBins)); % = sum(expected)
   uniformityScore = 1 - min(1, chiSq / maxChiSq);
end
