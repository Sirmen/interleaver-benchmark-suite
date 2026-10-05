function Htrans = calcTransitionMatrixEntropy(perm)
% Entropy of the transition matrix between adjacent values (randomness measure)
% Builds a transition matrix T where T(i,j) is the number of times i is followed by j in the permutation.
% Normalizes T to create a probability matrix P.
% Computes entropy: H = −∑P(i,j)log2P(i,j)
    N = length(perm);
    
    if N < 2
        Htrans = 0;
        return;
    end
    
    % Build transition pairs
    transitions = [perm(1:end-1)', perm(2:end)'];
    maxVal = max(perm);
    
    % Count transitions
    T = zeros(maxVal);
    for i = 1:size(transitions, 1)
        T(transitions(i,1), transitions(i,2)) = T(transitions(i,1), transitions(i,2)) + 1;
    end
    
    % Normalize to probabilities
    P = T / sum(T(:));
    P = P(P > 0);
    
    % Compute entropy
    Htrans = -sum(P .* log2(P));
end
