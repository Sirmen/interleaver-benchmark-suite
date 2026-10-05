function d = analyzeDispersion(perm)
% computes S-Parameter
% Dispersion Factor (Gamma): Ratio of unique separations
% Literature: Benedetto & Montorsi (1996)
    N = length(perm);
    pos = zeros(1,N); pos(perm) = 1:N;
    
    % Use sampling for large N to keep performance high
    sampleSize = min(5000, N);
    idx = randperm(N, sampleSize);
    
    % S-Factor (Minimum 2D Distance)
    % Standard: sqrt( (i-j)^2 + (pi(i)-pi(j))^2 )
    d.minDist = calc_spread_factor_invperm(perm, 'sample', sampleSize);
    
    % Dispersion Factor (Gamma): Ratio of unique separations
    diffs = abs(diff(perm));
    d.gamma = length(unique(diffs)) / (N-1);
end
