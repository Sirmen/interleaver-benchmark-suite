function [sustainability] = assessECCSustainability(beforeStats, afterStats, eccCapacityPerBlock)
% Assess whether ECC capability is maintained or improved after interleaving
    
    beforeNoisy = beforeStats.noisyPointsPerBlock;
    afterNoisy = afterStats.noisyPointsPerBlock;
    totalBlocks = length(beforeNoisy);
    
    % Classification of blocks based on ECC capability
    sustainability.eccCapacityPerBlock = eccCapacityPerBlock;
    
    % Before interleaving analysis
    before_safe = sum(beforeNoisy <= eccCapacityPerBlock);
    before_marginal = sum(beforeNoisy == eccCapacityPerBlock);
    before_overloaded = sum(beforeNoisy > eccCapacityPerBlock);
    
    % After interleaving analysis  
    after_safe = sum(afterNoisy <= eccCapacityPerBlock);
    after_marginal = sum(afterNoisy == eccCapacityPerBlock);
    after_overloaded = sum(afterNoisy > eccCapacityPerBlock);
    
    % Store counts
    sustainability.before_safeBlocks = before_safe;
    sustainability.before_marginalBlocks = before_marginal;
    sustainability.before_overloadedBlocks = before_overloaded;
    sustainability.after_safeBlocks = after_safe;
    sustainability.after_marginalBlocks = after_marginal;
    sustainability.after_overloadedBlocks = after_overloaded;
    
    % Calculate improvement
    sustainability.safeBlocksImprovement = after_safe - before_safe;
    sustainability.overloadedBlocksReduction = before_overloaded - after_overloaded;
    
    % ECC sustainability score (0-1, higher is better)
    sustainability.score = (after_safe - after_overloaded) / totalBlocks;
    
    % Normalized improvements (0-1)
    sustainability.safeBlocksImprovement_normalized = max(-1, min(1, sustainability.safeBlocksImprovement / totalBlocks));
    sustainability.overloadedBlocksReduction_normalized = max(-1, min(1, sustainability.overloadedBlocksReduction / totalBlocks));
    
    % Determine sustainability level
    if after_overloaded == 0
        sustainability.level = 'EXCELLENT';
        sustainability.description = 'All blocks within ECC capability';
    elseif after_overloaded < before_overloaded
        sustainability.level = 'IMPROVED';
        sustainability.description = sprintf('Reduced overloaded blocks from %d to %d', before_overloaded, after_overloaded);
    elseif after_overloaded == before_overloaded
        sustainability.level = 'MAINTAINED';
        sustainability.description = sprintf('ECC violations unchanged (%d blocks)', after_overloaded);
    else
        sustainability.level = 'DEGRADED';
        sustainability.description = sprintf('Increased overloaded blocks from %d to %d', before_overloaded, after_overloaded);
    end
end
