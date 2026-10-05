function periodicity = calcPeriodicityScore(perm)
% Periodicity detection using autocorrelation
% 1. Normalize input
% 2. Exclude more lags near zero to avoid artifacts
% 3. Return maximum absolute correlation (not just positive)
% Interpretation: 
%  Lower values indicate better (less periodic) interleavers
%  < 0.1: excellent (highly aperiodic)
%  0.1-0.3: good
%  0.3-0.5: moderate
%  > 0.5: poor (periodic patterns detected)
    N = length(perm);
    if N < 10
        periodicity = 0;
        return;
    end
    
    % Normalize to zero mean, unit variance
    normPerm = (perm - mean(perm)) / (std(perm) + eps);
    
    % Compute autocorrelation
    ac = xcorr(normPerm, 'coeff');
    
    % Remove center peak and adjacent lags (artifacts)
    excludeRange = max(1, round(0.02 * N)); % Exclude 2% of length around zero
    centerIdx = N;
    ac(centerIdx-excludeRange:centerIdx+excludeRange) = 0;
    
    % Maximum absolute autocorrelation (detect both positive and negative patterns)
    periodicity = max(abs(ac));
end
