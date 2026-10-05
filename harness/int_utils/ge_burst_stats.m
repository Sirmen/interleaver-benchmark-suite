function R = ge_burst_stats(opts)
%GE_BURST_STATS  Realized burst structure of the Gilbert-Elliott regimes.
%
%   R = ge_burst_stats                                   % both GE regimes, common grid
%   R = ge_burst_stats(struct('grid', 'standards'))
%
% Section VII-B of the manuscript reports, for the common grid, the mean number
% of bursts per frame, their mean length, the longest burst, and the share of
% masks forced into the acceptance band. The per-trial geInfo is not stored in
% the results files, so these statistics are regenerated here by drawing masks
% with the campaign's own generator and configuration: configure_simulation,
% configure_burst_parameters and genGilbertElliottMask, at every length, noise
% level and run of the grid. The draws are not the campaign's draws (the seed
% differs); they are draws from the same channel, which is what the text
% describes.
%
% OPTIONS
%   regimes  {'ge1p00','ge0p70'}
%   grid     'common' | 'standards'                       ['common']
%   seed     rng seed                                     [1]
%   runs     masks per (length, noise level)              [config.testRunsMax]
%
% OUTPUT  one row per regime: frames, mean bursts per frame, mean burst length
%         pooled over bursts, mean of per-frame mean burst length, longest burst,
%         share of forced masks (%), mean draws per mask.
%
% R.T. Sirmen harness, 2026-09

   if nargin < 1, opts = struct(); end
   if ~isfield(opts, 'regimes'), opts.regimes = {'ge1p00', 'ge0p70'}; end
   if ~isfield(opts, 'grid'),    opts.grid = 'common'; end
   if ~isfield(opts, 'seed'),    opts.seed = 1; end

   global TS_BURST_REGIME TS_GRID_MODE %#ok<GVMIS>
   oldR = TS_BURST_REGIME; oldG = TS_GRID_MODE;
   restore = onCleanup(@() local_restore(oldR, oldG)); %#ok<NASGU>

   rng(opts.seed, 'twister');
   fprintf('\n=== GILBERT-ELLIOTT BURST STRUCTURE (%s grid, seed %d) ===\n', opts.grid, opts.seed);
   fprintf('%-8s %8s %10s %12s %14s %8s %9s %8s\n', 'regime', 'frames', 'bursts/fr', ...
           'meanLen(all)', 'meanLen(frame)', 'maxLen', 'forced %', 'draws');
   R = struct('regime', {}, 'frames', {}, 'burstsPerFrame', {}, 'meanLenPooled', {}, ...
              'meanLenPerFrame', {}, 'maxLen', {}, 'forcedPct', {}, 'meanDraws', {});
   for k = 1:numel(opts.regimes)
      TS_BURST_REGIME = opts.regimes{k}; TS_GRID_MODE = opts.grid;
      cfg  = configure_simulation();
      lenEnc = cfg.sizeList * 15 / 9;           % encoded length N = K * n / k, RS(15,9)
      rhos = cfg.noiseLevels;
      nRuns = cfg.testRunsMax;
      if isfield(opts, 'runs'), nRuns = opts.runs; end
      nTot = numel(lenEnc) * numel(rhos) * nRuns;
      nb = zeros(nTot, 1); mlf = zeros(nTot, 1); fz = false(nTot, 1); dr = zeros(nTot, 1);
      sumLen = 0; nBursts = 0; mx = 0; q = 0;
      for N = lenEnc(:).'
         for rho = rhos(:).'
            bc = configure_burst_parameters(cfg, N, rho);
            for r = 1:nRuns
               [~, g, erM] = genGilbertElliottMask(N, bc);
               if erM ~= "", error('ge_burst_stats: %s', erM); end
               q = q + 1;
               nb(q) = g.burstCount; mlf(q) = g.meanBurstLen_realised;
               fz(q) = g.forced; dr(q) = g.draws;
               sumLen = sumLen + sum(g.burstSizes); nBursts = nBursts + numel(g.burstSizes);
               mx = max(mx, g.maxBurstLen);
            end
         end
      end
      R(k).regime = opts.regimes{k}; R(k).frames = q;
      R(k).burstsPerFrame = mean(nb); R(k).meanLenPooled = sumLen / max(1, nBursts);
      R(k).meanLenPerFrame = mean(mlf); R(k).maxLen = mx;
      R(k).forcedPct = 100 * mean(fz); R(k).meanDraws = mean(dr);
      fprintf('%-8s %8d %10.2f %12.1f %14.1f %8d %9.2f %8.2f\n', R(k).regime, q, ...
              R(k).burstsPerFrame, R(k).meanLenPooled, R(k).meanLenPerFrame, mx, R(k).forcedPct, R(k).meanDraws);
   end
end

function local_restore(oldR, oldG)
   global TS_BURST_REGIME TS_GRID_MODE %#ok<GVMIS>
   TS_BURST_REGIME = oldR; TS_GRID_MODE = oldG;
end
