function blockPatternScore = calcBlockPatternFitScore(perm, blockSize)
% This metric detects block interleaver patterns
% It checks whether a given permutation aligns with a block interleaving pattern.
% Each block of size blockSize is checked to see if the modulo pattern of elements 
%  matches what would be expected for a block interleaver.
% The final fit score is computed as:
%  fitScore = number of matches / total tests
%  i.e. fitScore: score of how elements within interleaved blocks maintain their relative orders
% It is a normalized score in [0,1]
% Score near 1.0: Input is a block interleaver
% Score near 0.0: Input is NOT a block interleaver
%  It is NOT a quality metric - it's a pattern detector
%  Only use if you specifically need to classify interleaver types
    
    warning('blockPatternScore is a pattern detector, not a quality metric. Consider removing.');
    
    N = length(perm);
    numBlocks = floor(N / blockSize);
    matches = 0;
    totalTests = 0;
    
    for block = 1:numBlocks
        startIdx = (block-1) * blockSize + 1;
        endIdx = min(block * blockSize, N);
        blockPerm = perm(startIdx:endIdx);
        
        expectedPattern = mod(blockPerm - 1, blockSize) + 1;
        actualPattern = mod((startIdx:endIdx) - 1, blockSize) + 1;
        
        matches = matches + sum(expectedPattern == actualPattern);
        totalTests = totalTests + length(actualPattern);
    end
    
    if totalTests > 0
        blockPatternScore = matches / totalTests;
    else
        blockPatternScore = 0;
    end
    
end
