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
% FORCED AGAINST UNFORCED
% A reviewer asked whether repairing the few masks that miss the acceptance band
% distorts the error structure the paper is about. The repair adds or removes
% symbols at the edges of existing runs (genGilbertElliottMask/local_nudge), so
% the claim is that it moves run LENGTHS and not the run count. That is a claim,
% and this function measures it: run-length distributions are accumulated
% separately for forced and unforced masks and compared by their quantiles and a
% two-sample Kolmogorov-Smirnov statistic computed here, with no toolbox. The
% magnitude of each repair is reported too, in symbols and as a share of the
% mask's error count, because a two-symbol repair on a 114-symbol run is a
% different thing from a fifty-symbol one. R(k).forcedCmp carries all of it.
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
      lenF = cell(nTot, 1); lenU = cell(nTot, 1);     % run lengths, forced / unforced
      lenP = cell(nTot, 1);                           % the forced masks BEFORE repair
      nudgeAbs = []; nudgeRel = []; nudgeRun = [];
      for N = lenEnc(:).'
         for rho = rhos(:).'
            bc = configure_burst_parameters(cfg, N, rho);
            for r = 1:nRuns
               [~, g, erM] = genGilbertElliottMask(N, bc);
               if erM ~= "", error('ge_burst_stats: %s', erM); end
               q = q + 1;
               nb(q) = g.burstCount; mlf(q) = g.meanBurstLen_realised;
               fz(q) = g.forced; dr(q) = g.draws;
               if g.forced
                  lenF{q} = g.burstSizes(:);
                  lenP{q} = g.burstSizesPre(:);
                  nudgeAbs(end+1, 1) = abs(g.nudge); %#ok<AGROW>
                  nudgeRel(end+1, 1) = abs(g.nudge) / max(1, g.totalErrors); %#ok<AGROW>
                  nudgeRun(end+1, 1) = g.nudgeRuns; %#ok<AGROW>
               else
                  lenU{q} = g.burstSizes(:);
               end
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
      R(k).forcedCmp = local_cmp(vertcat(lenF{:}), vertcat(lenU{:}), ...
                                 nudgeAbs, nudgeRel, nudgeRun, vertcat(lenP{:}));
   end

   local_report(R);
end

%% ------------------------------------------------------------------------
function C = local_cmp(xF, xU, nAbs, nRel, nRun, xP)
% Summaries of the two run-length samples, plus the size of the repairs.
   C = struct();
   C.nRunsForced   = numel(xF);
   C.nRunsUnforced = numel(xU);
   C.qForced   = local_q(xF);
   C.qUnforced = local_q(xU);
   C.meanForced   = local_mean(xF);
   C.meanUnforced = local_mean(xU);
   C.ks = local_ks(xF, xU);
   % The paired comparison: the same masks, before and after the repair. This is
   % the one that answers "does the repair distort the structure", because the
   % selection is held fixed on both sides.
   C.ksRepair    = local_ks(xP, xF);
   C.meanPre     = local_mean(xP);
   C.qPre        = local_q(xP);
   C.nRunsPre    = numel(xP);
   C.nudgeMeanSymbols = local_mean(nAbs);
   C.nudgeMaxSymbols  = local_max(nAbs);
   C.nudgeMeanShare   = local_mean(nRel);
   C.runsChangedPct   = 100 * local_mean(nRun ~= 0);
end

function q = local_q(x)
% Quantiles without the Statistics Toolbox: linear interpolation on the
% midpoint convention, the same one quantile() uses by default.
   p = [0.05 0.25 0.50 0.75 0.95];
   if isempty(x), q = nan(size(p)); return; end
   x = sort(x(:)); n = numel(x);
   pos = p * n + 0.5;
   lo = max(1, floor(pos)); hi = min(n, ceil(pos)); w = pos - lo;
   q = (1 - w) .* x(lo).' + w .* x(hi).';
end

function d = local_ks(x, y)
% Two-sample Kolmogorov-Smirnov statistic, sup|F1 - F2|. No toolbox, no p-value:
% with hundreds of thousands of runs any p is zero and says nothing, whereas the
% statistic is an effect size on the distribution and can be read directly.
   if isempty(x) || isempty(y), d = NaN; return; end
   x = sort(x(:)); y = sort(y(:));
   g = unique([x; y]);
   Fx = local_ecdf(x, g); Fy = local_ecdf(y, g);
   d = max(abs(Fx - Fy));
end

function F = local_ecdf(x, grid)
   F = zeros(numel(grid), 1); n = numel(x); j = 1;
   for i = 1:numel(grid)
      while j <= n && x(j) <= grid(i), j = j + 1; end
      F(i) = (j - 1) / n;
   end
end

function c = local_kscrit(n, m, k)
% Asymptotic two-sample KS critical value, k = 1.36 at 5 %, 1.22 at 10 %.
   if n == 0 || m == 0, c = NaN; else, c = k * sqrt((n + m) / (n * m)); end
end

function m = local_mean(x)
   if isempty(x), m = NaN; else, m = mean(double(x(:))); end
end

function m = local_max(x)
   if isempty(x), m = NaN; else, m = max(double(x(:))); end
end

function local_report(R)
   fprintf('\n=== FORCED AGAINST UNFORCED MASKS: RUN LENGTHS ===\n');
   fprintf('%-8s %9s %11s %9s %9s %9s %9s %9s %7s\n', 'regime', 'sample', 'mean', ...
           'p05', 'p25', 'p50', 'p75', 'p95', 'runs');
   for k = 1:numel(R)
      C = R(k).forcedCmp;
      fprintf('%-8s %9s %11.2f %9.0f %9.0f %9.0f %9.0f %9.0f %7d\n', R(k).regime, ...
              'unforced', C.meanUnforced, C.qUnforced, C.nRunsUnforced);
      fprintf('%-8s %9s %11.2f %9.0f %9.0f %9.0f %9.0f %9.0f %7d\n', '', ...
              'forced', C.meanForced, C.qForced, C.nRunsForced);
      fprintf('%-8s %9s %11.2f %9.0f %9.0f %9.0f %9.0f %9.0f %7d\n', '', ...
              'pre-repair', C.meanPre, C.qPre, C.nRunsPre);
      fprintf('%-8s %9s  KS(forced vs unforced) = %.4f  [selection + repair]\n', '', '', C.ks);
      fprintf('%-8s %9s  KS(before vs after repair, same masks) = %.4f  [repair alone]  crit 5%% = %.4f, 10%% = %.4f\n', ...
              '', '', C.ksRepair, local_kscrit(C.nRunsPre, C.nRunsForced, 1.36), ...
              local_kscrit(C.nRunsPre, C.nRunsForced, 1.22));
      fprintf('%-8s %9s  repair: mean %.1f symbols (%.2f %% of the mask), max %d; run count changed in %.1f %% of repairs\n\n', ...
              '', '', C.nudgeMeanSymbols, 100 * C.nudgeMeanShare, ...
              round(C.nudgeMaxSymbols), C.runsChangedPct);
   end
   fprintf(['Read KS as sup|F1 - F2| over run length. Two statistics are given because\n' ...
            'they answer different questions. Forced against unforced carries both the\n' ...
            'selection (a forced mask missed the band fifty times, so it was an unusual\n' ...
            'draw before anything was repaired) and the repair. Before against after, on\n' ...
            'the same masks, isolates the repair. The second is the one to quote.\n\n']);
end

function local_restore(oldR, oldG)
   global TS_BURST_REGIME TS_GRID_MODE %#ok<GVMIS>
   TS_BURST_REGIME = oldR; TS_GRID_MODE = oldG;
end
