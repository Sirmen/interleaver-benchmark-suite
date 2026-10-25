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
% [41] of the paper, Brest and Boskovic, defines the peak sidelobe level as
% an integer, PSL = max|C_k|, and reports it in decibels as
%
%     NPSL [dB] = 20 log10 (PSL / L)
%
% which is NEGATIVE, since PSL <= L, and on which smaller is better. For a
% +-1 sequence C_0 = L, so that ratio is exactly the r(k) used here. APSR
% negates and halves it: APSR = -NPSL/2.
%
% So the constant between the two is NEGATIVE, not positive, and the two
% orderings are reverses of each other. That is deliberate - the suite reads
% larger as better - and it is harmless because Section 8 reports |rho|,
% which a reversal leaves unchanged.
%
% Switching to twenty would make APSR the plain negation of NPSL, which is
% tidier, and it is still not worth doing: APSR is discarded on C2, so its
% printed value enters no verdict, every rank statistic is invariant to the
% factor, and the archived campaign stores this quantity computed with ten.
% Changing the paper alone would break the correspondence between the paper
% and the data it cites, which is the thing this release exists to keep.
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
