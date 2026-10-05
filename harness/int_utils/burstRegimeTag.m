function tag = burstRegimeTag(config)
%BURSTREGIMETAG  One name for the burst regime, used by every save path.
%
%   tag = burstRegimeTag(config)   ->  'single' | 'multi' | 'ge1p00' | 'ge0p70'
%
% Gilbert-Elliott is a THIRD regime and its two e_B settings are two regimes
% again, so the tag must not be derived from config.singleBurst alone. Both
% save_results.m and saveCrossCorrelationResults.m call this, so the file
% prefixes can never drift apart - which is exactly how GE output would end up
% mixed into (or overwriting) the fixed-burst results.
%
% R.T. Sirmen harness integration, 2026

   if isfield(config, 'gilbertElliott') && config.gilbertElliott
      eB = 1.0;
      if isfield(config, 'ge_errProbBad') && ~isempty(config.ge_errProbBad)
         eB = config.ge_errProbBad;
      end
      tag = sprintf('ge%s', strrep(sprintf('%.2f', eB), '.', 'p'));   % ge1p00 / ge0p70
   elseif isfield(config, 'singleBurst') && config.singleBurst
      tag = 'single';
   else
      tag = 'multi';
   end
end
