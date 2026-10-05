function [gini, erM] = calcGiniCoefficient(values)
% Calculate Gini coefficient to measure inequality of distribution
% Returns value between 0 (perfect equality) and 1 (maximum inequality)
%
% For interleaver analysis:
%   - 0 means errors are perfectly distributed across all blocks
%   - 1 means all errors are concentrated in one block
%   - Zeros (blocks with no errors) should be INCLUDED in calculation
%
% Literature: Damgård & Østergaard (2006), Yitzhaki (1979)
erM = ""; gini=0;
try    
    % Input validation
    if ~isvector(values)
        error('Input must be a vector');
    end
    
    values = values(:); % Convert to column vector
    n = length(values);
    
    % Handle edge cases
    if n == 0 || all(values == 0)
        gini = 0; % Perfect equality when all zeros
        return;
    end
    
    if n == 1
        gini = 0; % Only one value, no inequality possible
        return;
    end
    
    % CRITICAL: Include ALL values (including zeros) for interleaver analysis
    % This is important because zeros represent blocks with no errors,
    % which is a good thing for distribution quality
    
    % Sort values (zeros will be at the beginning)
    sortedValues = sort(values);
    
    % Standard Gini coefficient formula
    % Gini = (2 * sum(i * x_i)) / (n * sum(x_i)) - (n+1)/n
    index = (1:n)';
    totalSum = sum(sortedValues);
    
    if totalSum == 0
        gini = 0; % All zeros case
        return;
    end
    
    numerator = 2 * sum(index .* sortedValues);
    denominator = n * totalSum;
    
    gini = (numerator / denominator) - (n + 1) / n;
    
    % Ensure within [0, 1] (handles numerical precision issues)
    gini = max(0, min(1, gini));
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
