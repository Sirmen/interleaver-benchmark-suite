function Hblocks = calcBlockEntropy(perm, blockSize)
% Entropy of symbol distribution across blocks
    N = length(perm);
    numBlocks = ceil(N / blockSize);
    
    % Assign each symbol to a block
    blockAssignments = ceil(perm / blockSize);
    
    % Count distribution
    counts = histcounts(blockAssignments, 1:(numBlocks+1));
    
    % Compute probabilities
    p = counts / sum(counts);
    p = p(p > 0);
    
    % Entropy
    Hblocks = -sum(p .* log2(p));
end
