function s = analyzeSpectralProperties(perm)
%ANALYZESPECTRALPROPERTIES  Spectral summary of a permutation.
%
%   s = analyzeSpectralProperties(perm)
%     s.PSR  peak-to-sidelobe ratio in dB, the paper's APSR, equation (10)
%     s.MSL  the largest nonzero-lag autocorrelation magnitude
%
% The computation now lives in metrics/calc_apsr.m, named after the metric
% the paper defines; this function remains as its caller's interface. It is
% not a redundant layer: collectStatistics_x writes s.PSR into every campaign
% record and the archived correlation_data_*.mat files are keyed on that
% field name, so the name PSR has to survive even though the paper calls the
% quantity APSR. fig5_c5box maps the one to the other and warns against
% renaming the field.
%
% R.T. Sirmen harness, 2026

   [s.PSR, s.MSL] = calc_apsr(perm);
end
