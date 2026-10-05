function [outPerm, erM, newMinSep, bestAvgSep] = swapSepMinMax(inPerm)
% swaps positions of all min separated points w positions of max-separated points
% retrieves every min (and max) separated point as:
% dpMin: [dp1st_Min dp2nd_Min]
% dpMax: [dp1st_Max dp2nd_Max]
% checks all possible 4 combinations of swapping: i.e.:
% dp1st_Min with dp1st_Max,
% dp1st_Min with dp2st_Max,
% dp2st_Min with dp1st_Max,
% dp2st_Min with dp2st_Max
% picks the one yielding the best avg&min separation statistics
try
    outPerm=[]; erM=""; newMinSep=0; bestAvgSep=0;
    %%%
    perm = inPerm;
    bestPerm = perm;
    excludeZero = true;
    
    % get min & max separations in permutation
    [sepMin_0, sepMax_0, sepAvg_0, separations_normalized_vals] = intraVectorSeparations(perm, excludeZero);
    
    bestAvgSep = sepAvg_0; % current best average separation
    newMinSep = sepMin_0; % current min separation
    
    % Create data point pairs and their separations
    % Assuming separations correspond to consecutive pairs in perm
    n = length(perm);
    dp_pairs = [];
    sep_values = [];
    
    % Build pairs and their separations (assuming consecutive pairs)
    for i = 1:n-1
        dp_pairs(end+1, :) = [perm(i), perm(i+1)];
        sep_values(end+1) = separations_normalized_vals(i);
    end
    % Add wrap-around pair if needed (circular)
    if length(separations_normalized_vals) == n
        dp_pairs(end+1, :) = [perm(n), perm(1)];
        sep_values(end+1) = separations_normalized_vals(n);
    end
    
    % identify the min separated data points
    ndxMin = (sep_values == sepMin_0);
    dpMin_pairs = dp_pairs(ndxMin, :);
    
    % find positions in perm for min separated pairs
    perPosMin = [];
    for i = 1:size(dpMin_pairs, 1)
        pos1 = find(perm == dpMin_pairs(i, 1));
        pos2 = find(perm == dpMin_pairs(i, 2));
        perPosMin(i, :) = [pos1, pos2];
    end
    
    % identify the max separated data points
    ndxMax = (sep_values == sepMax_0);
    dpMax_pairs = dp_pairs(ndxMax, :);
    
    % find positions of dp-pairs in perm for max separated pairs
    perPosMax = [];
    for i = 1:size(dpMax_pairs, 1)
        pos1 = find(perm == dpMax_pairs(i, 1));
        pos2 = find(perm == dpMax_pairs(i, 2));
        perPosMax(i, :) = [pos1, pos2];
    end
    
    % swap data points in perm corresponding to min with max
    % check all 4 combinations of swapping
    sTimes = min(size(dpMin_pairs, 1), size(dpMax_pairs, 1));
    
    for i = 1:sTimes
        % retrieve min and max separated points pair positions
        perPosMin_i = perPosMin(i, :);
        perPosMax_i = perPosMax(i, :);
        
        % check all 4 combinations of swapping
        for j = 1:2
            for k = 1:2
                % Create a copy of perm for this swap attempt
                tempPerm = perm;
                
                % Perform the swap
                tmpData = tempPerm(perPosMin_i(j));
                tempPerm(perPosMin_i(j)) = tempPerm(perPosMax_i(k));
                tempPerm(perPosMax_i(k)) = tmpData;
                
                % get new separations in permutation
                [sepMin_new, sepMax_new, sepAvg_new, ~] = intraVectorSeparations(tempPerm, excludeZero);
                
                % pick if yields a better sepAvg & sepMin
                if (sepAvg_new > bestAvgSep) && (sepMin_new >= newMinSep)
                    bestAvgSep = sepAvg_new; % new best average separation
                    newMinSep = sepMin_new; % new best min separation
                    bestPerm = tempPerm;
                end
            end
        end
    end
    
    outPerm = bestPerm;
    
catch errssmm
    erM = strcat("Error in swapSepMinMax:\n", errssmm.message);
    % rethrow(errssmm);
end % catch
end