function [sizes, described] = getSizeList(config)
%GETSIZELIST  The one place that decides which message lengths a sweep visits.
%
%   sizes = getSizeList(config)
%   [sizes, described] = getSizeList(config)      also returns a one-line
%                                                 description for banners
%
% WHY THIS EXISTS
% ---------------------------------------------------------------------------
% The length list was derived independently in two places -
%     run_simulations_sci.m          for N = config.sizeMin : step : sizeMax
%     PrecomputeInterleaversGenerator sizes = config.sizeMin:sizeStep:sizeMax
% - and they must agree exactly, or the sweep asks the table for lengths the
% table was never built for. That is not a hypothetical: the sizeStep bug of
% early 2026 was precisely a disagreement of this kind, and it cost a full
% mis-scaled runtime projection before anyone noticed. One function, two
% callers, no drift.
%
% TWO MODES
% ---------------------------------------------------------------------------
%   config.sizeList  non-empty  ->  that explicit list is used, verbatim
%                    empty/absent -> config.sizeMin : sizeStep : sizeMax
%
% The explicit list exists because the interesting grids are not arithmetic.
% The standards-aligned grid used in this study is
%
%       config.sizeList = 36 * (1:50);        % K = 36, 72, ..., 1800
%
% which under RS(15,9) gives encoded lengths L = ceil(K/9)*15 = 60*(1:50),
% i.e. 60, 120, ... 3000. Every one of those lengths satisfies at once:
%
%   * L = 0 (mod 4)   - required by the standardised ARP (ETSI EN 301 790
%                       cl. 6.4.4.1: "N is a multiple of 4")
%   * 4 | L           - admits DRP's smallest published dither period; 8 | L
%                       on the multiples of 120, 16 | L on multiples of 240
%   * 60 = 3*4*5      - admits a three-way factorisation for the d = 3
%                       lattice interleaver at every length
%   * K = 36m exactly - 4m codewords with ZERO padding, so BE = 1 for every
%                       method and the bandwidth-efficiency term stops
%                       confounding the comparison
%
% and eight of them (120, 180, 240, 480, 960, 1440, 1920, 2400) carry
% published IEEE 802.16 ARP parameters.
%
% It is also about seventeen times cheaper than the 991-length arithmetic grid
% it replaces, because 9 consecutive K values collapse to ONE encoded length
% and therefore to one permutation - the old grid was paying for the same
% interleaver nine times over.
%
% R.T. Sirmen harness, 2026-08

   sizes = [];

   if isfield(config, 'sizeList') && ~isempty(config.sizeList)
      sizes = config.sizeList(:).';
      sizes = round(sizes);
      sizes = unique(sizes(sizes >= 1));
      if isempty(sizes)
         error('getSizeList: config.sizeList contains no usable length');
      end
      described = sprintf('explicit list, %d lengths (%d..%d)', ...
                          numel(sizes), min(sizes), max(sizes));
      return;
   end

   step = 1;
   if isfield(config, 'sizeStep') && ~isempty(config.sizeStep) && config.sizeStep >= 1
      step = round(config.sizeStep);
   end
   sizes = config.sizeMin : step : config.sizeMax;
   if isempty(sizes)
      error('getSizeList: empty range (sizeMin=%g, sizeStep=%g, sizeMax=%g)', ...
            config.sizeMin, step, config.sizeMax);
   end
   described = sprintf('%d..%d step %d, %d lengths', ...
                       config.sizeMin, config.sizeMax, step, numel(sizes));
end
