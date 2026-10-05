function corrPeaks = calcAutoCorrelationPeaks(data)
% Peaks in autocorrelation function (excluding zero lag)
    ac = xcorr(data - mean(data), 'coeff');
    N = length(data);
    ac(N) = 0; % remove zero-lag peak
    [pks, ~] = findpeaks(ac);
    corrPeaks = pks;
end
