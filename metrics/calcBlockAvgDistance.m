function avgDist = calcBlockAvgDistance(perm, blockSize)
    % Average of mean pairwise distances within blocks
    
    N = length(perm);
    numBlocks = floor(N / blockSize);
    
    avgDistances = zeros(numBlocks, 1);
    
    for k = 1:numBlocks
        startIdx = (k-1) * blockSize + 1;
        endIdx = k * blockSize;
        block = perm(startIdx:endIdx);
        
        if length(block) < 2
            avgDistances(k) = 0;
        else
            distances = pdist(block', 'euclidean') / (N-1);
            avgDistances(k) = mean(distances);
        end
    end
    
    avgDist = mean(avgDistances);
end
