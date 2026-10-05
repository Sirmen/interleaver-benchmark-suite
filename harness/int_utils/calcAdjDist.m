function [adjMin, adjAvg, adjCV, erM] = calcAdjDist(dVector)
% Calculates distances of adjacent symbols
%
% INPUTS:
%   dVector : The interleaved sequence of original indices
%
% OUTPUTS:
%  adjMin: min cardinal distance between adjacent elements
%  adjAvg: average cardinal distance between adjacent elements
%  adjCV: coeff of variance (the ratio of the std.dev to the mean) of adjacent cardinal distances

erM ="";
adjMin=NaN; adjAvg=NaN; adjCV=NaN;
try
    N = length(dVector);

    % --- 1. Adjacency Metrics (Global) ---
    d_adj_norm = abs(diff(dVector)) / (N - 1);
    adjMin = min(d_adj_norm);
    adjAvg = mean(d_adj_norm);
    adjCV  = std(d_adj_norm) / (adjAvg + eps);

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   rethrow(erM);
end
end
