function [apsr, maxSidelobe] = calc_apsr(perm)
%CALC_APSR  Autocorrelation Peak-to-Sidelobe Ratio of a permutation, in dB.
%
%   apsr               = calc_apsr(perm)
%   [apsr, sidelobe]   = calc_apsr(perm)
%
% This is equation (10) of the paper: APSR = -10 log10 max_{k != 0} |r(k)|,
% where r is the aperiodic autocorrelation of the gather sequence after
% standardization to zero mean and unit variance, normalized so r(0) = 1.
% A high APSR means no nonzero lag reproduces the arrangement, so the
% permutation carries no cyclic period.
%
% WHY THIS FILE EXISTS, AND WHY IT IS NAMED THIS WAY
% ===========================================================================
% The computation lived in analyzeSpectralProperties, under the name the
% statistic carries in the sequence-design literature (PSR) rather than the
% name the paper gives it. A reader checking equation (10) against the code
% looks in metrics/ for something called APSR, finds calcPeriodicityMetrics -
% a different, unused quantity - and concludes the metric is not implemented.
% Two reviewers asked about the dB convention in exactly this way. The
% arithmetic is unchanged; only its address is.
%
% THE FACTOR OF TEN IS A DECLARED CONVENTION, NOT AN ERROR.
% The peak sidelobe level of sequence design is conventionally reported as
% 20 log10 of an amplitude ratio. Ten is used here and declared as such in
% Section 6.3. The two differ by a positive constant, so every rank
% correlation, every C2 and C5 verdict and every sensitivity result in the
% paper is identical under either; only the printed decibel value changes.
% Changing it now would oblige a re-run and a re-archiving of every stored
% result for no change in any reported conclusion.
%
% THE FIELD NAME IN THE RESULTS IS STILL 'PSR'.
% correlation_data_*.mat and the campaign records key this quantity as PSR,
% and fig5_c5box maps that field to the printed label APSR. The field name
% is load-bearing across archived data and is deliberately not renamed; see
% the note in fig5_c5box.m.
%
% R.T. Sirmen harness, 2026

   N = numel(perm);
   % Standardize before correlating: the gather sequence is a ramp-like
   % integer vector, and without removing the mean the zero-lag term would
   % swamp every sidelobe and the ratio would measure the mean, not the
   % structure.
   x = (perm - mean(perm)) / std(perm);

   % Aperiodic (linear) autocorrelation, 'coeff' so that r(0) = 1. The zero
   % lag sits at index N of the 2N-1 returned samples.
   ac = xcorr(x, 'coeff');

   mainPeak = ac(N);
   sidelobes = abs(ac);
   sidelobes(N) = 0;                 % exclude the peak itself
   maxSidelobe = max(sidelobes);

   % eps guards a permutation whose sidelobes all vanish; it is below the
   % resolution of every reported value and is kept so the result is finite
   % rather than Inf.
   apsr = 10 * log10(mainPeak / (maxSidelobe + eps));
end
