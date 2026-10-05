function coverageRatio = calcBlockTransitionDiversity(perm, blockSize)
% Measures how well adjacent symbols spread across different blocks
% Fixed normalization and interpretation
% 1. Correct normalization (total possible transitions, not numBlocks)
% 2. Better handling of edge cases
% 3. Clear interpretation
% Interpretation:
% 1.0: perfect - uses all possible block jump distances
% 0.5: moderate - uses half of possible transitions
% near 0: poor - very limited block transition diversity
    
    N = length(perm);
    numBlocks = ceil(N / blockSize);
    
    if N < 2 || numBlocks < 2
        coverageRatio = 0;
        return;
    end
    
    % Determine which block each position maps to
    blocks = ceil(perm / blockSize);
    
    % Compute block transitions for adjacent symbols
    blockTransitions = abs(diff(blocks));
    
    % Count unique non-zero transitions (actual block jumps)
    uniqueTransitions = length(unique(blockTransitions(blockTransitions > 0)));
    
    % Maximum possible unique transitions is (numBlocks - 1)
    % because you can have transitions of size 1, 2, ..., numBlocks-1
    maxPossibleTransitions = numBlocks - 1;
    
    % Normalize
    coverageRatio = uniqueTransitions / max(1, maxPossibleTransitions);
    
end