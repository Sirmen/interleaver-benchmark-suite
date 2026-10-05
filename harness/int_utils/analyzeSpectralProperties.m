function s = analyzeSpectralProperties(perm)
% PSR: Peak-to-Sidelobe Ratio
%  In dB: 10*log10(MainPeak / MaxSidelobe)
%  Higher is better (less periodic)
    % Normalize data for autocorrelation
    x = (perm - mean(perm)) / std(perm);
    ac = xcorr(x, 'coeff');
    N = length(perm);
    
    % Central peak is at ac(N)
    mainPeak = ac(N);
    sidelobes = abs(ac);
    sidelobes(N) = 0; % Remove main peak
    
    maxSidelobe = max(sidelobes);
    
    s.PSR = 10 * log10(mainPeak / (maxSidelobe + eps));
    s.MSL = maxSidelobe;
end
