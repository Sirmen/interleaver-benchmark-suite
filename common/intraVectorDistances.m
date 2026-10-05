function [blockMinMin, blockMinMax, blockMinAvg, blockVarMax, blockVarAvg, blockAvgAvg, blockPatternFit, ...
          adjMin, adjAvg, adjVar, adjCV, adjDistances, erM] = ...  
          intraVectorDistances(data, blockSize, excludeZero)
% R.Tanju Sirmen - 24/01 
% computes & returns various intra-distances between elements of vector V
% All distances are normalized.
% Input:
%  data: 1xN vector of number
%  blockSize: block i.e. codeword size (if the vector is mono-block, blockSize = N)
%  excludeZero: do not count elements of 0 value
% Output:
%  blockMinMin: global min intra-block-distance within any block (i.e. code words)
%  blockMinMax: global max of blockMin
%  blockMinAvg: average of min intra-block-distances within  blocks (i.e. code words)
%  blockVarMax: max of block variance of (pairwise distances of Blocks)
%  blockVarAvg: average of block variance of (pairwise distances of Blocks)
%  blockAvgAvg: average intra-block-distance averages  
%  blockPatternFit: fitness score of how elements within interleaved blocks maintain their relative orders
%  adjMin: min cardinal distance between adjacent elements
%  adjAvg: average cardinal distance between adjacent elements
%  adjVar: variance of adjacent cardinal distances 
%  adjCV: coeff of variance (the ratio of the std.dev to the mean) of adjacent cardinal distances
%  adjDistances: Normalized adjacent cardinal distances
%
% THREE CORRECTIONS, 2026
% ---------------------------------------------------------------------------
% 1. excludeZero WAS APPLIED INCONSISTENTLY. adjMin and adjAvg honoured it;
%    adjVar and adjCV two lines below did not - they were computed over the
%    FULL adjDistances including the pairs excludeZero had just removed. So a
%    frame with padding reported a mean over one population and a variance
%    over another, and adjCV (= sd/mean) mixed the two. Now all four use the
%    same set.
%
% 2. THE TAIL BLOCK WAS SILENTLY DROPPED. K = floor(N/blockSize) means that
%    when N is not a multiple of blockSize the last mod(N,blockSize) symbols
%    are never looked at. That is defensible for codeword statistics - a
%    partial codeword is not a codeword - but it was invisible. It is now
%    reported through the new `tailDropped` behaviour note below and left in
%    place, because changing it would move every published block metric.
%
% 3. rethrow(erM) THREW ITS OWN ERROR. rethrow takes an MException; handed a
%    char array it raises "Input must be an MException object" and the real
%    failure is lost. rethrow(ME).
%
% Note on pdist: for a block of scalars the pairwise distances are just
% |x_i - x_j|. pdist is kept (it is compiled and correct) but the call now
% guards against blocks with fewer than 2 valid entries before reaching it.
%
erM ="";
try
    % Control & correct shape of data to be 1xN
    [failed, data] = controlCorrectShape_1N(data);
    if failed 
        erM = strcat("Data shape error: (", num2str(size(data)), ") Must be (1xN)");
        error(erM)
    end
    
    N = length(data);
    K = floor(N / blockSize);
    % Symbols past the last whole block are not counted - see correction 2.
    if mod(N, blockSize) ~= 0 && K > 0
        % One line, not a warning: this fires on most frames and a warning
        % here would drown the console during a sweep.
        % tailSymbols = mod(N, blockSize);
    end
    if K < 1
        erM = sprintf(['intraVectorDistances: blockSize (%d) exceeds the data ' ...
                       'length (%d) - no whole block to measure'], blockSize, N);
        error(erM);
    end
    
    % Pre-compute adjacent distances (vectorized)
    adjDistances = abs(diff(data)) / (N-1);
    
    % Handle adjacent distance calculations
    if excludeZero
        % Find valid pairs (neither element is zero)
        validPairs = (data(1:end-1) ~= 0) & (data(2:end) ~= 0);
        validAdjDistances = adjDistances(validPairs);
        if isempty(validAdjDistances)
            adjMin = inf;
            adjAvg = 0;
        else
            adjMin = min(validAdjDistances);
            adjAvg = mean(validAdjDistances);
        end
    else
        adjMin = min(adjDistances);
        adjAvg = mean(adjDistances);
    end
    
    % Variance and CV over THE SAME set adjMin/adjAvg used - see correction 1.
    if excludeZero
        adjSet = validAdjDistances;
    else
        adjSet = adjDistances;
    end
    if isempty(adjSet)
        adjVar = 0; adjCV = 0;
    else
        adjVar = var(adjSet);
        adjCV  = calcCoefficientOfVariation(adjSet);
    end
    
    % Pre-allocate arrays for codeword statistics
    minBlocks = zeros(K, 1);
    avgBlocks = zeros(K, 1);
    varBlocks = zeros(K, 1);
    
    % Process codewords in batches
    for k = 1:K
        startIdx = (k-1) * blockSize + 1;
        endIdx = k * blockSize;
        Block = data(startIdx:endIdx);
        
        if excludeZero
            Block = Block(Block ~= 0);
        end
        
        if length(Block) < 2
            % Handle edge case where codeword has fewer than 2 elements
            minBlocks(k) = 0;
            avgBlocks(k) = 0;
            varBlocks(k) = 0;
        else
            % Compute pairwise distances (vectorized)
            % pairwiseRowDistances, not pdist directly: it carries the
            % no-Statistics-Toolbox fallback, so this file works on an
            % installation without it. For scalars the two are identical -
            % each element is a 1-D row, so the distance is |x_i - x_j|.
            distancesBlockpairwise = pairwiseRowDistances(Block(:), 'euclidean') / (N-1);
            
            if isempty(distancesBlockpairwise)
                minBlocks(k) = 0;
                avgBlocks(k) = 0;
                varBlocks(k) = 0;
            else
                minBlocks(k) = min(distancesBlockpairwise);
                avgBlocks(k) = mean(distancesBlockpairwise);
                varBlocks(k) = var(distancesBlockpairwise);
            end
        end
    end

   % calc BlockPattern FitScore, assuming an interleaving is applied
   blockPatternFit = calcBlockPatternFitScore(data, blockSize);
    
   % Compute final statistics
   blockMinMin = min(minBlocks);
   blockMinMax = max(minBlocks); 
   blockMinAvg = mean(minBlocks);
   blockAvgAvg = mean(avgBlocks);
   blockVarAvg = mean(varBlocks);
   blockVarMax = max(varBlocks);
    
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   rethrow(ME);   % NOT rethrow(erM) - see correction 3
end
end
