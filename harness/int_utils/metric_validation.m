function V = metric_validation(dataPath, opts)
%METRIC_VALIDATION  Spearman rho(metric, RES) for every sweep, consolidated.
%
%   V = metric_validation('<resultsDir>')
%   V = metric_validation(path, struct('threshold', 0.30))
%   V = metric_validation(path, struct('rebuild', true))   % ignore the cache
%
% WHY THIS EXISTS
% ---------------------------------------------------------------------------
% The per-sweep correlation tables were printed to the console by the sweep and
% not written anywhere else, so the two runs whose console output is gone have
% no correlation numbers at all. They are recoverable: the metrics and the
% merged RES are both inside results.stats_all in the saved results_*.mat.
%
% It also produces the form the paper needs. One correlation table per regime
% is eight tables; the manuscript can carry one. This assembles the metrics x
% sweeps matrix, applies the declared retention threshold once, and writes a
% CSV that a table or a figure can be built from without re-reading 60 GB.
%
% TWO SOURCES, AND WHY THE FAST ONE IS CHECKED BEFORE IT IS TRUSTED
% ---------------------------------------------------------------------------
% correlation_data_*.mat is ~9 MB and already holds every numeric scalar field
% of every trial, RES included. results_*.mat is 1-11 GB and holds the same
% metrics plus the permutations and noise locations. Reading the small file is
% obviously preferable - but only if its rows are aligned, and they are not
% guaranteed to be.
%
% prepare_correlation_data/extractFromStructArray accumulates each field
% INDEPENDENTLY and skips non-finite values as it goes:
%
%       if isnumeric(val) && isscalar(val) && isfinite(val)
%           fieldValues(end+1) = val;
%       end
%
% So one NaN in one metric leaves that field one element short, and from that
% record on it is offset against every other field. Correlating them then pairs
% trial i of one metric with trial i+1 of another. Nothing reports it: the
% summary prints "Observations per variable" from the FIRST variable only and
% never compares the rest.
%
% Non-finite values are reachable here - delta_BS is 1/(1+CV) over infected
% codewords and is undefined when none are infected, S_sf takes a min over
% pairs inside a codeword, adjCV is a ratio to a mean that can be zero - so
% this is checked rather than assumed. If every needed field has the same
% length the fast file is used; if not, the sweep falls back to results_*.mat,
% where fields are read by index from the struct array and alignment holds by
% construction. Either way the source is reported per sweep.
%
% The cache is keyed by file name, size and modification time, so re-running is
% instant and a changed file is recomputed rather than served stale. Load one
% large file at a time and clear it: holding two open ended an earlier session.
%
% WHAT IT DOES NOT DO
% ---------------------------------------------------------------------------
% It does not decide anything the paper has not already declared. The threshold
% is an input with a stated default, applied identically to every metric, and
% the full rho matrix is returned so a reader can apply a different one. A
% validation that chooses its own cut-off after seeing the numbers is not a
% validation.
%
% OUTPUT
%   V.metrics    metric names, ordered by mean |rho| descending
%   V.sweeps     sweep labels, '<regime>/<grid>'
%   V.rho        numel(metrics) x numel(sweeps) matrix
%   V.n          trials each rho was computed on
%   V.status     'recommended' | 'moderate' | 'weak' | 'discarded' per metric
%
% R.T. Sirmen harness, 2026-08

   if nargin < 2, opts = struct(); end
   if nargin < 1 || isempty(dataPath)
      c = configure_simulation();
      dataPath = char(c.dataSavePath);
   end
   dataPath = char(dataPath);

   threshold = local_opt(opts, 'threshold', 0.30);
   rebuild   = local_opt(opts, 'rebuild',   false);
   kpi       = local_opt(opts, 'kpi',       'RES');
   metrics   = local_opt(opts, 'metrics', { ...
       'delta_G','eta_ES','S_ECC','eta_sep','delta_BS','PSR', ...
       'U_ECC','V_ECC','adjMin','sepMin','adjCV','laplacianEnergy', ...
       'S_sf','S_factor'});

   cacheFile = fullfile(dataPath, 'metric_validation_cache.mat');
   cache = struct();
   if ~rebuild && exist(cacheFile, 'file')
      try
         L = load(cacheFile); if isfield(L, 'cache'), cache = L.cache; end
      catch
      end
   end

   d = dir(fullfile(dataPath, 'results_*.mat'));
   if isempty(d)
      error('metric_validation: no results_*.mat in %s', dataPath);
   end
   preferSmall = local_opt(opts, 'preferSmall', true);

   fprintf('\n=================================================================\n');
   fprintf('  METRIC VALIDATION : Spearman rho(metric, %s)\n', kpi);
   fprintf('  %d sweep file(s) in %s\n', numel(d), dataPath);
   fprintf('  retention threshold |rho| >= %.2f, declared in advance\n', threshold);
   fprintf('=================================================================\n');

   labels = {}; R = []; Ns = []; DR = [];

   for i = 1:numel(d)
      f    = fullfile(d(i).folder, d(i).name);
      lbl  = local_label(d(i).name);
      key  = local_key(d(i));

      if isfield(cache, key)
         e = cache.(key);
         fprintf('  %-24s  cached\n', lbl);
      else
         e = [];
         % --- fast path: the small correlation_data file, if it is aligned ---
         if preferSmall
            fSmall = strrep(f, [filesep 'results_'], [filesep 'correlation_data_']);
            if exist(fSmall, 'file')
               fprintf('  %-24s  correlation_data ... ', lbl);
               tL = tic;
               [e, why] = local_fromCorrData(fSmall, metrics, kpi);
               if isempty(e)
                  fprintf('REJECTED (%s)\n', why);
                  fprintf('  %-24s  falling back to results (%.1f GB) ... ', ...
                          '', d(i).bytes/1e9);
               else
                  fprintf('%.1f s, n = %d\n', toc(tL), e.n);
               end
            end
         end
         % --- slow path: the full results file, alignment guaranteed ---------
         if isempty(e)
            if ~preferSmall
               fprintf('  %-24s  loading %.1f GB ... ', lbl, d(i).bytes/1e9);
            end
            tL = tic;
            e = local_compute(f, metrics, kpi);
            fprintf('%.0f s, n = %d\n', toc(tL), e.n);
         end
         cache.(key) = e;
         try
            save(cacheFile, 'cache', '-v7.3');
         catch ME
            fprintf(2, '   (cache not written: %s)\n', ME.message);
         end
      end

      labels{end+1} = lbl;      %#ok<AGROW>
      R(:, end+1)   = e.rho(:); %#ok<AGROW>
      Ns(end+1)     = e.n;      %#ok<AGROW>
      if isfield(e, 'D') && ~isempty(e.D)
         DR(:, end+1) = e.D(:);           %#ok<AGROW>
      else
         DR(:, end+1) = nan(numel(metrics), 1); %#ok<AGROW>
      end
   end

   %% ---- order by mean |rho| ---------------------------------------------
   mAbs = mean(abs(R), 2, 'omitnan');
   [~, ord] = sort(mAbs, 'descend');
   metrics = metrics(ord);
   R = R(ord, :);
   if ~isempty(DR), DR = DR(ord, :); end
   mAbs = mAbs(ord);

   % Sweeps in a stable, readable order rather than in directory order.
   [labels, si] = sort(labels);
   R = R(:, si); Ns = Ns(si);
   if ~isempty(DR), DR = DR(:, si); end

   %% ---- classify --------------------------------------------------------
   nS   = numel(labels);
   pass = sum(abs(R) >= threshold, 2);
   status = cell(numel(metrics), 1);
   for k = 1:numel(metrics)
      if pass(k) >= 0.75 * nS
         status{k} = 'recommended';
      elseif pass(k) > 0
         status{k} = 'moderate/split';
      else
         status{k} = 'discarded';
      end
   end

   %% ---- report ----------------------------------------------------------
   fprintf('\n  %-16s', 'METRIC');
   for j = 1:nS, fprintf(' %10s', labels{j}); end
   fprintf(' %8s %6s  %s\n', 'mean|rho|', 'pass', 'status');
   fprintf('  %s\n', repmat('-', 1, 18 + 11*nS + 18));
   for k = 1:numel(metrics)
      fprintf('  %-16s', metrics{k});
      for j = 1:nS, fprintf(' %10.3f', R(k, j)); end
      fprintf(' %8.3f %4d/%d  %s\n', mAbs(k), pass(k), nS, status{k});
   end
   fprintf('  %s\n', repmat('-', 1, 18 + 11*nS + 18));
   fprintf('  pass = sweeps with |rho| >= %.2f. recommended needs >= 75%% of them.\n', threshold);
   fprintf('  Trials per sweep: '); fprintf('%d ', Ns); fprintf('\n');

   % Which file each column came from. A column read from correlation_data
   % passed the row-alignment check; a column read from results did not need
   % one. Report it: the paper states how each number was obtained.
   fprintf('  Source per sweep:');
   for j = 1:nS
      kk = local_key(d(j));
      if isfield(cache, kk) && isfield(cache.(kk), 'source')
         fprintf(' %s=%s', labels{j}, cache.(kk).source);
      end
   end
   fprintf('\n');

   %% ---- discrimination ratio ---------------------------------------------
   if ~isempty(DR) && any(isfinite(DR(:)))
      fprintf('\n  === DISCRIMINATION RATIO  D = between-method var / within-cell var ===\n');
      fprintf('  %-16s %10s %10s   %s\n', 'METRIC', 'median D', 'trials*', 'reading');
      fprintf('  %s\n', repmat('-', 1, 66));
      Dmed = median(DR, 2, 'omitnan');
      for k = 1:numel(metrics)
         if isnan(Dmed(k)), continue; end
         if isinf(Dmed(k)) || Dmed(k) >= 1e3
            if isinf(Dmed(k)), ds = 'inf'; else, ds = sprintf('%.0e', Dmed(k)); end
            fprintf('  %-16s %10s %10s   %s\n', metrics{k}, ds, '0', ...
                    'invariant across realizations');
            continue;
         end
         nreq = max(1, ceil(1 / max(Dmed(k), eps)));
         if Dmed(k) >= 1
            rd = 'one realization separates methods';
         elseif Dmed(k) >= 0.1
            rd = 'a few realizations needed';
         else
            rd = 'dominated by realization noise';
         end
         fprintf('  %-16s %10.3f %10d   %s\n', metrics{k}, Dmed(k), nreq, rd);
      end
      fprintf('  %s\n', repmat('-', 1, 66));
      fprintf(['  "invariant" (D >= 1e3) means the metric barely moves between the\n' ...
               '  realizations of a cell. D says THAT, not why. For the a priori\n' ...
               '  metrics the cause is that they never see the channel. For U_ECC it\n' ...
               '  is not: its numerator is the total error count, which noise\n' ...
               '  balancing holds fixed within a cell - so U_ECC is largely reporting\n' ...
               '  the noise bin rather than the interleaver, which is a plausible\n' ...
               '  mechanism for the weak correlation reported in Section VIII.\n\n' ...
               '  For the rest, trials* is 1/D rounded up - the order of magnitude of\n' ...
               '  realizations needed before a typical between-method difference\n' ...
               '  exceeds the realization noise.\n\n' ...
               '  READ THIS CAREFULLY. The stochastic metrics score D of roughly 1.5\n' ...
               '  to 6, meaning ONE realization already separates methods. They are\n' ...
               '  not noise-dominated and are not expensive to use once a channel\n' ...
               '  model exists. The distinction that survives this measurement is\n' ...
               '  therefore not "few trials versus many" but "needs a channel model\n' ...
               '  versus needs none" - which is the axis of Section V, now with a\n' ...
               '  number attached rather than an assumption.\n']);
   end

   %% ---- csv for the manuscript ------------------------------------------
   csvFile = fullfile(dataPath, sprintf('metric_validation_%s.csv', datestr(now,'yymmdd')));
   try
      T = array2table(R, 'VariableNames', matlab.lang.makeValidName(labels), ...
                         'RowNames', metrics);
      T.mean_abs = mAbs;
      T.pass     = pass;
      T.status   = status;
      writetable(T, csvFile, 'WriteRowNames', true);
      fprintf('\n  consolidated matrix written to:\n    %s\n', csvFile);
   catch ME
      fprintf(2, '  (csv not written: %s)\n', ME.message);
   end

   fprintf(['\n  This matrix is the input to the manuscript''s single validation\n' ...
            '  table and to any figure built from it. Do not re-derive it per\n' ...
            '  regime in the paper: eight per-regime tables report the same\n' ...
            '  numbers and hide the pattern that only the consolidated view\n' ...
            '  shows - which metrics hold across channels and which do not.\n\n']);

   V = struct('metrics', {metrics}, 'sweeps', {labels}, 'rho', R, 'n', Ns, ...
              'D', DR, ...
              'meanAbs', mAbs, 'pass', pass, 'status', {status}, ...
              'threshold', threshold, 'kpi', kpi, 'csv', csvFile);
end

%% ------------------------------------------------------------------------
function D = local_discrimination(Dat, metrics)
% Discrimination ratio: between-method variance over within-cell variance.
%
%   D = var over methods of the per-method mean, averaged within length
%       -------------------------------------------------------------------
%       mean over (method, length, noise) cells of the variance across trials
%
% This is the criterion the literature does not report and the one that decides
% whether a metric can be USED. A metric whose value swings more from one noise
% realization to the next than it does between methods cannot rank methods from
% a single evaluation, however well its long-run mean correlates with recovery.
% D is, to within a constant, the inverse of the number of trials needed to
% resolve a typical method difference: D = 1 means one trial gives a
% signal-to-noise ratio of one, D = 0.01 means a hundred trials are needed for
% the same.
%
% Design-time metrics have zero within-cell variance by construction, so their
% D is infinite. That is not a technicality - it is exactly the property that
% makes them usable at design time, and it is why they are reported alongside
% rather than being compared on rho alone.
   D = nan(numel(metrics), 1);
   if ~all(isfield(Dat, {'methodID', 'encodedLen', 'noiseBin'})), return; end
   mid = double(Dat.methodID(:));
   len = double(Dat.encodedLen(:));
   nb  = double(Dat.noiseBin(:));
   if numel(unique([numel(mid) numel(len) numel(nb)])) ~= 1, return; end

   [cellId, ~, ci] = unique([mid len nb], 'rows');
   [~, ~, mi]      = unique([mid len],    'rows');   % method-within-length groups
   [~, ~, li]      = unique(len);

   for k = 1:numel(metrics)
      if ~isfield(Dat, metrics{k}), continue; end
      x = double(Dat.(metrics{k})(:));
      if numel(x) ~= numel(mid), continue; end
      ok = isfinite(x);
      if sum(ok) < 100, continue; end

      % within-cell variance, averaged over cells
      wv = splitapply(@(v) var(v, 'omitnan'), x, ci);
      withinVar = mean(wv, 'omitnan');

      % between-method variance at fixed length, averaged over lengths
      cellMean = splitapply(@(v) mean(v, 'omitnan'), x, mi);
      lenOfCell = splitapply(@(v) v(1), li, mi);
      bv = splitapply(@(v) var(v, 'omitnan'), cellMean, findgroups(lenOfCell));
      betweenVar = mean(bv, 'omitnan');

      % A metric that is a deterministic function of the permutation takes the
      % same value at all 35 trials of a cell, so withinVar is zero up to
      % floating point and the ratio is not a number worth printing. Detect
      % that case explicitly rather than reporting 1e26.
      % var() over 35 identical doubles does not return exactly zero, so a
      % metric that IS a deterministic function of the permutation lands at
      % D ~ 1e4 rather than at infinity. The classification below therefore
      % works on magnitude and the printed label is neutral about the CAUSE:
      % D says only that a metric does not move between realizations, not why.
      % For eta_sep, PSR, adj_min and the other a priori metrics the cause is
      % that they never see the channel. For U_ECC it is different - its
      % numerator is the total error count, which noise balancing fixes per
      % cell - and calling that "a function of the permutation" would be wrong.
      if isfinite(withinVar) && withinVar > 0
         D(k) = betweenVar / withinVar;
      elseif isfinite(betweenVar) && betweenVar > 0
         D(k) = Inf;
      end
   end
end

function [e, why] = local_fromCorrData(f, metrics, kpi)
% Use the small file ONLY if every needed field has the same number of rows.
% See the header: fields are accumulated independently upstream, so unequal
% lengths mean the columns are offset against one another and any correlation
% computed from them pairs the wrong trials.
   e = []; why = '';
   S = load(f);
   fn = fieldnames(S);
   Dat = [];
   for i = 1:numel(fn)
      if isstruct(S.(fn{i})), Dat = S.(fn{i}); break; end
   end
   if isempty(Dat), why = 'no struct inside'; return; end

   need = [metrics(:); {kpi}];
   have = fieldnames(Dat);
   miss = setdiff(need, have);
   if ~isempty(miss)
      why = sprintf('missing %s', strjoin(miss(1:min(3,end))', ', '));
      return;
   end

   len = cellfun(@(nm) numel(Dat.(nm)), need);
   if numel(unique(len)) ~= 1
      [mn, imn] = min(len); mx = max(len);
      why = sprintf('row counts differ: %s has %d, max %d', need{imn}, mn, mx);
      return;
   end

   y = double(Dat.(kpi)(:));
   rho = nan(numel(metrics), 1);
   for k = 1:numel(metrics)
      x = double(Dat.(metrics{k})(:));
      ok = isfinite(x) & isfinite(y);
      if sum(ok) > 10 && numel(unique(x(ok))) > 1
         rho(k) = corr(x(ok), y(ok), 'type', 'Spearman');
      end
   end
   e = struct('rho', rho, 'n', len(1), 'metrics', {metrics}, 'kpi', kpi, ...
              'source', 'correlation_data', 'D', local_discrimination(Dat, metrics));
end

function e = local_compute(f, metrics, kpi)
% Load one results file, reduce it to the columns needed, drop it.
   S  = load(f);
   fn = fieldnames(S);
   R  = [];
   for i = 1:numel(fn)
      v = S.(fn{i});
      if isstruct(v) && isfield(v, 'stats_all'), R = v; break; end
   end
   if isempty(R)
      error('metric_validation: no results struct with stats_all in %s', f);
   end
   sa = R.stats_all;
   clear S R;                      % release the big copy before doing anything else

   n = numel(sa);
   y = local_col(sa, kpi);
   if all(isnan(y))
      error(['metric_validation: %s not found in stats_all. calcKPIs merges it ' ...
             'back after the sweep; a file saved before that step has metrics ' ...
             'but no KPI to correlate them against.'], kpi);
   end

   rho = nan(numel(metrics), 1);
   for k = 1:numel(metrics)
      x = local_col(sa, metrics{k});
      ok = ~isnan(x) & ~isnan(y);
      % A metric that is constant has no rank order and no correlation; report
      % NaN rather than 0, which would read as "measured, and unrelated".
      if sum(ok) > 10 && numel(unique(x(ok))) > 1
         rho(k) = corr(x(ok), y(ok), 'type', 'Spearman');
      end
   end

   e = struct('rho', rho, 'n', n, 'metrics', {metrics}, 'kpi', kpi, ...
              'source', 'results');
end

function v = local_col(sa, name)
% Pull one scalar field out of a struct array, tolerating the two spellings
% this project carries for the adjacency CV (stats.CV_adj vs reported adjCV).
   alt = {name};
   switch name
      case 'adjCV',  alt = {'adjCV', 'CV_adj'};
      case 'CV_adj', alt = {'CV_adj', 'adjCV'};
   end
   v = nan(numel(sa), 1);
   for a = 1:numel(alt)
      if isfield(sa, alt{a})
         c = {sa.(alt{a})};
         keep = cellfun(@(z) isnumeric(z) && isscalar(z), c);
         v(keep) = cell2mat(c(keep));
         return;
      end
   end
end

function lbl = local_label(name)
   REG = 'single|multi|ge\d+p\d+';
   GRD = 'common|standards|probe|legacy';
   t = regexp(name, sprintf('^results_(%s)_(%s)_', REG, GRD), 'tokens', 'once');
   if ~isempty(t)
      lbl = sprintf('%s/%s', t{1}, t{2}(1));
      return;
   end
   t = regexp(name, sprintf('^results_(%s)_', REG), 'tokens', 'once');
   if ~isempty(t), lbl = sprintf('%s/?', t{1}); else, lbl = name; end
end

function k = local_key(dEntry)
   raw = sprintf('%s_%d_%.6f', dEntry.name, dEntry.bytes, dEntry.datenum);
   k = ['k' regexprep(raw, '[^A-Za-z0-9]', '_')];
   if numel(k) > 60, k = k(1:60); end
end

function v = local_opt(s, f, dflt)
   if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = dflt; end
end
