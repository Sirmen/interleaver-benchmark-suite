function periodicityMetrics = calcPeriodicityMetrics(perm)
% Comprehensive periodicity analysis combining autocorrelation approaches
%
% Returns:
%   .score - max absolute autocorrelation (from calcPeriodicityScore)
%   .numPeaks - count of significant peaks
%   .maxPeak - maximum peak magnitude
%   .avgPeak - average peak magnitude
%   .peakEnergy - sum of squared peaks (energy measure)
%
% Interpretation:
%   Lower values = more aperiodic
%   Combined metric: weighted average of score and normalized peak metrics

    % Get base periodicity score
    periodicityMetrics.score = calcPeriodicityScore(perm);
    
    % Get autocorrelation peaks
    peaks = calcAutoCorrelationPeaks(perm);
    
    if isempty(peaks)
        periodicityMetrics.numPeaks = 0;
        periodicityMetrics.maxPeak = 0;
        periodicityMetrics.avgPeak = 0;
        periodicityMetrics.peakEnergy = 0;
        periodicityMetrics.combinedScore = periodicityMetrics.score;
    else
        periodicityMetrics.numPeaks = length(peaks);
        periodicityMetrics.maxPeak = max(abs(peaks));
        periodicityMetrics.avgPeak = mean(abs(peaks));
        periodicityMetrics.peakEnergy = sum(peaks.^2) / length(peaks);
        
        % Combined metric (0-1 scale, lower is better)
        % Normalize peak count by reasonable maximum (e.g., 20 peaks)
        normalizedPeakCount = min(1, periodicityMetrics.numPeaks / 20);
        
        % Weighted combination
        periodicityMetrics.combinedScore = ...
            0.5 * periodicityMetrics.score + ...
            0.25 * periodicityMetrics.maxPeak + ...
            0.15 * normalizedPeakCount + ...
            0.10 * periodicityMetrics.peakEnergy;
    end
end
