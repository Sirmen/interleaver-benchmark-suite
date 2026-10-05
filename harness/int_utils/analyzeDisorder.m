function d = analyzeDisorder(perm)
% computes:
% - Normalized Entropy (H) and 
% - Laplacian Energy (LE): A Proxy measure of the graph-theoretical complexity 
%     of the permutation (Sun & Takeshita).
%     For a rigorous LE, one would use the Laplacian Matrix, 
%     but for speed in simulations, we use the second-order dispersion (Lambda).
    N = length(perm);
    % Normalized Entropy (H)
    [~, H_val] = calcEntropy1D(perm);
    d.H = H_val / log2(N); % Normalize to [0,1]
    
    % Laplacian Energy (LE)
    % % % adj = abs(diff(perm)) == 1; % Simple adjacency
    % for speed in simulations, use the second-order dispersion (Lambda).
    d.LE = mean(abs(diff(diff(perm)))); 
end
