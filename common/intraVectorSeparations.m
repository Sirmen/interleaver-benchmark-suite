function [minSeparation, maxSeparation, avgSeparation, separations_normalized, ...
          varSeparation, separationEfficiency, separationCV, separations, erM] = ...
                                                     intraVectorSeparations(data, excludeZero)
% R.Tanju Sirmen - 24/01
% Computes & returns separation between elements of vector V
% Computes the separation of cardinal elements in a way that:
%  starts from 1, finds the position index of 2, computes the separation
%  (i.e. sep_raw = abs(index(1)-index(2))), so on.
%  then all separations are normalized as: sep = sep_raw / (N-1);
% Input:
%  data: 1xN vector of numbers 1-N, as all elements must be unique
%  excludeZero: do not count elements of 0 value
% Output:
%  minSeparation: global min of (index(i)-index(i+1)) for all i, i=1-N
%  maxSeparation: global max of (index(i)-index(i+1)) for all i, i=1-N
%  avgSeparation: average of (index(i)-index(i+1)) for all i, i=1-N
%  separations: separation of every (index(i) to index(i+1)) for all i, i=1-N
%  separations_normalized: normalized to 0-1
%  varSeparation: variance of separations for all i, i=1-N
%  separationEfficiency: how well separation succeeded (against EoE)
%  separationCV: coeff of variance for all i, i: 1-N
erM ="";
try
    % Control & correct shape of data to be 1xN
    [failed, data] = controlCorrectShape_1N(data);
    if failed
        error("Data shape error: (%s) Must be (1xN)", mat2str(size(data)));
    end
    
    % Remove zeros if requested
    if excludeZero
        data = data(data ~= 0);
    end

    if ~isUnique(data)
        error("Data must be made up of unique elements: (%s)", mat2str(data));
    end

    N = length(data);
    EoE = N - 1;
    
    % Handle edge case
    if N <= 1
        [minSeparation, maxSeparation, avgSeparation, separations_normalized, ...
         varSeparation, separationEfficiency, separationCV, separations] = ...
         deal(0, 0, 0, [], 0, 0, 0, []);
        return;
    end
    
    % Position of each value. THIS USED TO BE O(N^2).
    % ------------------------------------------------------------------
    % The old code was
    %       for val = unique_values
    %           positions(val) = find(data == val, 1);
    %       end
    % - one full scan of `data` per distinct value, so N scans of length N.
    % The comment above it said "vectorized approach"; the loop was not.
    %
    % This function is called once per method per trial, so the cost lands on
    % the whole harness, but it only becomes visible on long frames: measured
    % here, a single call costs 7 ms at N = 500 and 41 ms at N = 4000, i.e. it
    % grows as N^2. A structural study over N = 8..10000 spends about an hour
    % inside this loop alone.
    %
    % Assigning through the value as an index does the same work in one pass.
    % The reverse order preserves the old "first occurrence" semantics for
    % duplicated values: later positions are written first and then overwritten
    % by earlier ones. (For a permutation there are no duplicates, so the order
    % is irrelevant there - it is kept only so the function behaves identically
    % on non-permutation input, which the isUnique check above already rejects
    % but which a future caller might allow.)
    unique_values = unique(data);
    max_val = max(unique_values);
    positions = nan(1, max_val);  % NaN for missing values
    positions(data(end:-1:1)) = numel(data):-1:1;
    
    % Find consecutive pairs that exist
    valid_pairs = find(~isnan(positions(1:end-1)) & ~isnan(positions(2:end)));
    num_pairs = length(valid_pairs);
    
    if num_pairs == 0
        [minSeparation, maxSeparation, avgSeparation, separations_normalized, ...
         varSeparation, separationEfficiency, separationCV, separations] = ...
         deal(0, 0, 0, [], 0, 0, 0, []);
        return;
    end
    
    % Vectorized separation calculation
    separations = abs(positions(valid_pairs) - positions(valid_pairs + 1));
    separations_normalized_vals = separations / EoE;
    
    % Create separations_normalized matrix
    separations_normalized = [valid_pairs + 1; separations_normalized_vals];
    
    % Compute statistics (all vectorized)
    minSeparation = min(separations_normalized_vals);
    maxSeparation = max(separations_normalized_vals);
    avgSeparation = mean(separations_normalized_vals);
    varSeparation = var(separations_normalized_vals);
    separationEfficiency = min(2 * avgSeparation, 2 * (1 - avgSeparation));
    separationCV = calcCoefficientOfVariation(separations_normalized_vals);
    
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   % rethrow() takes an MException, not a char array - rethrow(erM) throws its
   % own "Input must be an MException object" and buries the real error. The
   % original exception is what the caller needs.
   rethrow(ME);
end
end
