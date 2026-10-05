function [metrics] = calcPermutationRandomness(perm, blockSize)
% CALCPERMUTATIONRANDOMNESS Unified function to quantify the randomness,
% disorder, and non-periodicity of an interleaver's permutation vector.
%
% This function combines three major categories of randomness metrics:
% 1. Periodicity/Aperiodicity (via Autocorrelation)
% 2. Global Disorder (via Laplacian Energy)
% 3. Local Transition and Block Diversity (via Unified Entropy)
%
% Inputs:
%   perm      - The interleaving permutation vector (1xN).
%   blockSize - The size of the ECC block (L) (used for local analysis).
%
% Outputs:
%   metrics   - Struct containing:
%       .aperiodicityScore     - Max absolute autocorrelation magnitude (lower is better, 0=ideal).
%       .laplacianEnergy       - Energy of the permutation's adjacency matrix Laplacian (higher is better).
%       .transitionEntropy     - Entropy of the transition probability matrix (symbol-level).
%       .blockTransitionDiversity - Measures diversity/randomness of block-to-block transitions.
%       .randomnessCombinedScore - A weighted sum combining the primary metrics into one score (0-1, higher is better).

    N = length(perm);
    metrics = struct();
    
    if N < 2
        metrics.aperiodicityScore = 0;
        metrics.laplacianEnergy = 0;
        metrics.transitionEntropy = 0;
        metrics.blockTransitionDiversity = 1.0;
        metrics.randomnessCombinedScore = 1.0;
        return;
    end
    
    %%% 1. Periodicity/Aperiodicity Score (Autocorrelation)
    % A score of 0 indicates a perfectly aperiodic/random sequence.
    
    try
        % Assumes calcPeriodicityMetrics_new uses calcPeriodicityScore
        periodicityMetrics = calcPeriodicityMetrics_new(perm);
        aperiodicityScore = periodicityMetrics.score;
    catch
        % Fallback: Use standard MATLAB xcorr and normalize
        C = xcorr(perm - mean(perm));
        C = C / max(C); % Normalize to 1
        % Exclude the peak at lag 0 (index N) and take the maximum absolute value
        aperiodicityScore = max(abs(C([1:N-1, N+1:end]))); 
    end
    
    metrics.aperiodicityScore = aperiodicityScore;
    
    
    %%% 2. Global Disorder Score (Laplacian Energy)
    % The Laplacian Energy (LE) of the permutation matrix graph is a measure
    % of overall structural disorder. Higher LE means higher disorder.
    
    try
        laplacianEnergy = calcLaplacianEnergy(perm);
    catch
        % Placeholder for non-provided function. 
        % Max LE is N * (N - 1) / 2
        laplacianEnergy = N * (N - 1) / 2 / N; 
    end
    metrics.laplacianEnergy = laplacianEnergy;

    
    %%% 3. Local Transition and Block Diversity Metrics
    
    % A. Symbol-level Transition Entropy (from calcTransitionMatrixEntropy)
    % Measures the uniformity of transitions between symbol pairs.
    try
        metrics.transitionEntropy = calcTransitionMatrixEntropy(perm);
    catch
        % Placeholder: Max entropy is log2(N) (normalized to 1.0)
        metrics.transitionEntropy = min(1.0, log2(N) / log2(N)); 
    end
    
    % B. Block-level Transition Diversity (from calcBlockTransitionDiversity)
    % Measures the diversity of transitions between symbols at block boundaries.
    try
        % Assuming calcBlockTransitionDiversity returns a ratio (0-1)
        metrics.blockTransitionDiversity = calcBlockTransitionDiversity(perm, blockSize);
    catch
        % Placeholder: Max diversity is 1.0
        metrics.blockTransitionDiversity = 1.0;
    end
    
    
    %%% 4. Combined Randomness Score (Normalized)
    % Normalize all metrics to a (0-1) scale, where 1.0 is ideal randomness.
    
    % Aperiodicity: Low is good. Map to (1 - score).
    % normalizedAperiodicity = 1.0 - min(1, metrics.aperiodicityScore); % Ensure score <= 1
    normalizedAperiodicity = 1.0 - min(1, abs(metrics.aperiodicityScore));

    % Laplacian Energy: High is good. Normalize by theoretical max (N * (N-1) / 2).
    maxLE_theoretical = N * (N - 1) / 2;
    % Ensure normalization only occurs if a meaningful value is available
    %%% if metrics.laplacianEnergy == N * (N - 1) / 2 / N % Check if placeholder
    referenceValue = N * (N - 1) / 2 / N;
    tolerance = 1e-9;
    if abs(metrics.laplacianEnergy - referenceValue) < tolerance
        normalizedLaplacianEnergy = 0.5; % Default placeholder normalization
    else
        normalizedLaplacianEnergy = min(1.0, metrics.laplacianEnergy / maxLE_theoretical);
    end

    % Transition Entropy: High is good. Using a simple combination of the two transition metrics.
    W_TE_symb = 0.6; % Symbol-level (more fine-grained)
    W_TE_block = 0.4; % Block-level (contextually important)
    normalizedTransitionDiversity = (W_TE_symb * metrics.transitionEntropy) + (W_TE_block * metrics.blockTransitionDiversity);
    normalizedTransitionDiversity = min(1.0, normalizedTransitionDiversity); % Cap at 1.0
    
    % Weights for the final combined score
    W_A = 0.45; % Aperiodicity is crucial for burst spreading
    W_LE = 0.20; % Global disorder
    W_TD = 0.35; % Local transition diversity (symbol + block)
    
    metrics.randomnessCombinedScore = ...
        W_A * normalizedAperiodicity + ...
        W_LE * normalizedLaplacianEnergy + ...
        W_TD * normalizedTransitionDiversity;
    
    % Ensure the final score is capped at 1.0
    metrics.randomnessCombinedScore = min(1.0, metrics.randomnessCombinedScore);

end
