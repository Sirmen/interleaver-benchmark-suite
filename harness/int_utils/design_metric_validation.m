function D = design_metric_validation(dataPath, opts)
%DESIGN_METRIC_VALIDATION  Validate the design-time, code-aware metrics.
%
%   D = design_metric_validation('<resultsDir>', ...
%           struct('dataDir', '<path to data_PrimeFactor>'))
%
% WHAT THIS TESTS AND WHY IT IS SEPARATE
% ---------------------------------------------------------------------------
% The metric taxonomy has one empty cell: no published measure scores a
% permutation against a known code at design time, without a channel model.
% overT and maxErrCW occupy it. Identifying an empty cell is a weak claim on
% its own - a referee is entitled to ask whether anything useful lives there -
% so these two are put through the SAME validation as the other fourteen:
% correlate against RES, across all eight sweeps, against a threshold declared
% in advance.
%
% This needs no design that uses them and no companion paper. They are metrics,
% computable from any method's permutation, and they are validated here on the
% same 26 methods as everything else.
%
% GRANULARITY DIFFERS FROM THE OTHER METRICS, AND THAT MUST BE STATED
% ---------------------------------------------------------------------------
% The metrics of Section VIII are per trial: each has a value for every
% (method, length, noise, run). overT and maxErrCW are per PERMUTATION - they
% are deterministic functions of (pi, n, t, B) with no channel realization in
% them, so there is exactly one value per (method, length).
%
% The correlation is therefore computed at (method, length) granularity, with
% RES averaged within each such cell. That is a coarser test than the per-trial
% correlations and the two numbers are not directly comparable: averaging
% removes within-cell noise and tends to RAISE |rho|. The comparison that is
% legitimate is between design metrics and other metrics computed at the SAME
% granularity, which is why per-trial metrics are recomputed at cell level here
% as a reference column rather than quoted from Section VIII.
%
% BURST LENGTH IS AN INPUT, NOT A FITTED PARAMETER
% ---------------------------------------------------------------------------
% overT is defined for a burst length B. A design-time metric does not know the
% channel, so B is declared rather than matched to each regime: the defaults
% are n, 2n and 3n - one, two and three codewords. The interesting question is
% precisely whether a channel-agnostic score predicts recovery across four
% channels whose realized burst lengths differ by two orders of magnitude
% (3.2 symbols at GE 0.70, 114 at GE 1.00). Matching B per regime would answer
% an easier question and would not be a design-time metric any more.
%
% REDRAWN METHODS ARE SCORED OVER THEIR ENSEMBLE, NOT EXCLUDED
% ---------------------------------------------------------------------------
% random and freqRandom draw a fresh permutation every frame, so no single
% stored permutation is "theirs". Dropping them was the first approach and it
% was wrong: their design-time score is not undefined, it is an EXPECTATION
% over the ensemble they sample from. It is estimated here by scoring several
% fresh draws and averaging, which answers the question actually being asked -
% what overT does a permutation from this method typically have.
%
% TWO CORRELATIONS, BECAUSE THE POOLED ONE IS CONFOUNDED WITH LENGTH
% ---------------------------------------------------------------------------
% overT varies with N as well as with method, so a correlation pooled over all
% (method, length) cells partly measures a length trend rather than the method
% discrimination a design metric exists to provide. Both are reported:
%
%   rho_pool    Spearman over all cells - comparable to the reference rows,
%               and carrying the same confound as they do
%   rho_within  Spearman across methods WITHIN each length, averaged over
%               lengths - length is held fixed, so this isolates the question
%               "at a given N, does this metric rank the methods correctly"
%
% rho_within is the one a designer cares about. Report both and say which.
%
% R.T. Sirmen harness, 2026-08

   if nargin < 2, opts = struct(); end
   if nargin < 1 || isempty(dataPath)
      c = configure_simulation();
      dataPath = char(c.dataSavePath);
   end
   dataPath = char(dataPath);

   dataDir   = local_opt(opts, 'dataDir', '');
   FECn      = local_opt(opts, 'FECn', 15);
   FECt      = local_opt(opts, 'FECt', 3);
   % B is swept well past 3n: giniLoad was still strengthening at B = 3n in the
   % first run, so the peak - if there is one - lies outside that range and a
   % recommendation of B cannot be made without looking.
   % Swept well past the longest burst the campaign realized (114 symbols at
   % GE 1.00) because giniLoad was still strengthening at B = 8n. Where it
   % stops matters for the recommendation: a metric that keeps improving as B
   % approaches N has stopped measuring burst resilience and started measuring
   % how uniformly the permutation disperses each codeword across the whole
   % frame. Both are legitimate, but they are different claims and the paper
   % must say which one it is recommending.
   Bset      = local_opt(opts, 'Bset', FECn * [1 2 4 8 12 16 24]);
   threshold = local_opt(opts, 'threshold', 0.30);

   % COMMON SUPPORT. A burst cannot be longer than the frame, so every B drops
   % the cells with N <= B - and the largest B drops the most. Comparing rho
   % across B values then compares numbers computed on DIFFERENT cell sets: at
   % B = 24n the five shortest lengths are gone, and if short lengths carry
   % lower within-length correlation their removal raises the average by
   % itself. The rise with B could then be an artifact of the sample changing
   % rather than a property of the metric.
   %
   % With commonSupport true (the default) every B is scored on the same cells:
   % those with N greater than the largest B tested. That costs the short
   % lengths from every row equally and makes the B curve a like-for-like
   % comparison. Set it false to see each B on its own maximal support, which
   % is the right choice if a single B is being reported rather than compared.
   commonSupport = local_opt(opts, 'commonSupport', true);
   ENSEMBLE  = {'random', 'freqRandom'};   % scored over draws, not excluded
   nDraw     = local_opt(opts, 'nDraw', 15);

   if isempty(dataDir)
      error(['design_metric_validation: the permutation table directory is ' ...
             'required (opts.dataDir). Permutations are read from the ' ...
             'precomputed table rather than from results_*.mat, which is 60 GB ' ...
             'of trial records for one permutation per (method, length).']);
   end

   fprintf('\n=================================================================\n');
   fprintf('  DESIGN-METRIC VALIDATION : overT, maxErrCW\n');
   fprintf('  code (n,t) = (%d,%d);  B = %s\n', FECn, FECt, mat2str(Bset));
   fprintf('  threshold |rho| >= %.2f, declared in advance\n', threshold);
   fprintf('=================================================================\n');

   [tpc, erT] = PrecomputedInterleaverLoader(dataDir);
   if erT ~= "", error('design_metric_validation: %s', erT); end

   d = dir(fullfile(dataPath, 'KPItableDetailed_*.mat'));
   if isempty(d), error('design_metric_validation: no KPItableDetailed_*.mat found'); end

   % Five statistics per burst length. overT and maxErrCW were defined before
   % this campaign; meanMaxCW, cvLoad and giniLoad follow from an observation
   % made ON this campaign - that distributional statistics of the per-codeword
   % load outperform extremal ones - and are the design-time counterparts of
   % S_ECC, delta_BS and delta_G respectively. Same threshold, same protocol;
   % the provenance of the hypothesis is recorded, not the standing of the
   % result.
   STATS = {'overT', 'maxErrCW', 'meanMaxCW', 'cvLoad', 'giniLoad'};
   nB = numel(Bset); nStat = numel(STATS);
   names = cell(1, nStat*nB);
   for k = 1:nStat
      for b = 1:nB
         names{(k-1)*nB + b} = sprintf('%s_B%d', STATS{k}, Bset(b));
      end
   end
   REFS  = {'delta_G', 'eta_sep', 'S_ECC'};   % reference rows, same granularity
   names = [names, cellfun(@(r) ['ref: ' r], REFS, 'UniformOutput', false)];
   nDes  = nStat * nB;
   nRow  = nDes + numel(REFS);

   labels = {}; R = []; RW = []; SB = []; Npts = []; nMethodsSeen = NaN;
   permCache = containers.Map();

   % Prime/factor tables are needed to rebuild the redrawn methods live.
   [tp, tfac, erP] = PrimeFactorLoader(dataDir);
   if erP ~= "", error('design_metric_validation: PrimeFactorLoader: %s', erP); end

   for i = 1:numel(d)
      f   = fullfile(d(i).folder, d(i).name);
      lbl = local_label(d(i).name);
      fprintf('  %-16s ', lbl);

      T = local_table(f);
      mCol = 'method'; lCol = 'encodedLen';
      if ~all(ismember({mCol, lCol, 'RES'}, T.Properties.VariableNames))
         fprintf(2, 'skipped (missing method/encodedLen/RES)\n'); continue;
      end
      meth = string(T.(mCol));
      len  = double(T.(lCol));
      res  = double(T.RES);

      % Cell means: one row per (method, length).
      [g, gm, gl] = findgroups(meth, len);
      resBar = splitapply(@mean, res, g);

      if commonSupport
         keepC = gl > max(Bset);
         nDrop = sum(~keepC);
         gm = gm(keepC); gl = gl(keepC); resBar = resBar(keepC);
         if nDrop > 0
            fprintf('(common support N > %d: %d of %d cells dropped) ', ...
                    max(Bset), nDrop, nDrop + numel(gm));
         end
      end

      X = nan(numel(gm), nDes);
      nMiss = 0;
      for k = 1:numel(gm)
         mname = char(gm(k));
         if ismember(mname, ENSEMBLE)
            % Expectation over the ensemble this method samples from.
            acc = zeros(1, nDes); got = 0;
            for dr = 1:nDraw
               [~, p] = interleaver_generic_pc(1:gl(k), mname, 0, 0, [], ...
                                               1000 + dr, tp, tfac, struct());
               if isempty(p), continue; end
               acc = acc + local_all(p, Bset, FECn, FECt, nB);
               got = got + 1;
            end
            if got > 0, X(k, :) = acc / got; else, nMiss = nMiss + 1; end
         else
            p = local_perm(tpc, permCache, mname, gl(k));
            if isempty(p), nMiss = nMiss + 1; continue; end
            X(k, :) = local_all(p, Bset, FECn, FECt, nB);
         end
      end

      nUsable = sum(isfinite(X), 1);
      if any(nUsable < numel(gm))
         worst = min(nUsable);
         fprintf(2, '(WARNING: B>=N still drops up to %d of %d cells) ', ...
                 numel(gm) - worst, numel(gm));
      end

      rho  = nan(nDes, 1);
      rhoW = nan(nDes, 1);
      for c = 1:nDes
         ok = isfinite(X(:, c)) & isfinite(resBar);
         if sum(ok) > 10 && numel(unique(X(ok, c))) > 1
            rho(c) = corr(X(ok, c), resBar(ok), 'type', 'Spearman');
         end
         rhoW(c) = local_withinLength(X(:, c), resBar, gl);
      end

      % Reference rows: per-trial metrics re-aggregated to the SAME cells, so
      % the design metrics have something legitimate to be compared against.
      % Quoting Section VIII's per-trial values here would compare a cell-mean
      % correlation with a per-trial one and read as an advantage that is an
      % artifact of averaging.
      [rhoRef, rhoRefW] = local_refRows(f, gm, gl, resBar, {});

      % Stability is a different claim and needs a different target. A method
      % can be stably mediocre, so correlating a stability score with the LEVEL
      % of RES would understate it by construction. The matched question is
      % whether design-time stability across lengths predicts realized
      % stability across lengths. Both are reported so the reader can see
      % whether the two are confounded.
      SB(:, end+1) = local_stability(X, resBar, gm, gl, nDes); %#ok<AGROW>
      nMethodsSeen = numel(unique(gm));

      labels{end+1} = lbl;                    %#ok<AGROW>
      R(:, end+1)   = [rho;  rhoRef];         %#ok<AGROW>
      RW(:, end+1)  = [rhoW; rhoRefW];        %#ok<AGROW>
      Npts(end+1)   = numel(gm);              %#ok<AGROW>
      if nMiss > 0
         fprintf('%d cells, %d without a stored permutation\n', numel(gm), nMiss);
      else
         fprintf('%d cells\n', numel(gm));
      end
   end

   [labels, si] = sort(labels); R = R(:, si); RW = RW(:, si); SB = SB(:, si); Npts = Npts(si);
   nS = numel(labels);

   %% ---- report ----------------------------------------------------------
   mAbs  = mean(abs(R),  2, 'omitnan');
   pass  = sum(abs(R)  >= threshold, 2);
   mAbsW = mean(abs(RW), 2, 'omitnan');
   passW = sum(abs(RW) >= threshold, 2);

   local_block('POOLED over all (method, length) cells - carries a length trend', ...
               names, labels, R, mAbs, pass, threshold, nRow, nS);
   local_block('WITHIN length, across methods, averaged over lengths', ...
               names, labels, RW, mAbsW, passW, threshold, nRow, nS);

   sbNames = {};
   for c = 1:nDes, sbNames{end+1} = ['stab(' names{c} ') vs stab(RES)']; end %#ok<AGROW>
   for c = 1:nDes, sbNames{end+1} = ['stab(' names{c} ') vs mean RES']; end  %#ok<AGROW>
   % n here is the number of METHODS - stability collapses each method's length
   % series to one number, so that is the sample size. The earlier label divided
   % cells by an assumed length count and was simply wrong.
   local_block(sprintf(['LENGTH STABILITY - one point per method (n = %d methods), ' ...
                        'so these are noisy'], nMethodsSeen), ...
               sbNames, labels, SB, mean(abs(SB), 2, 'omitnan'), ...
               sum(abs(SB) >= threshold, 2), threshold, 2*nDes, nS);
   fprintf('  cells per sweep: '); fprintf('%d ', Npts); fprintf('\n');
   fprintf('  ensemble-scored over %d draws: %s\n', nDraw, strjoin(ENSEMBLE, ', '));
   if commonSupport
      fprintf(['  common support: every B scored on the same cells (N > %d), so the\n' ...
               '  B curve compares the metric and not the sample. Without this the\n' ...
               '  largest B is evaluated without the shortest lengths and can look\n' ...
               '  stronger for that reason alone.\n'], max(Bset));
   else
      fprintf(2, ['  common support OFF: each B uses its own maximal cell set, so rho\n' ...
                  '  values are NOT comparable across B.\n']);
   end
   fprintf(['\n  These are (method, length) cell correlations. Do NOT set them\n' ...
            '  beside the per-trial values of the main validation table: cell\n' ...
            '  averaging removes within-cell variance and inflates |rho|. Compare\n' ...
            '  them only against per-trial metrics recomputed at cell level.\n\n']);

   fprintf(['  Rows marked "ref:" are per-trial metrics re-aggregated to these\n' ...
            '  same cells. They are the only fair comparison for the rows above.\n']);

   D = struct('metrics', {names}, 'sweeps', {labels}, ...
              'rho', R, 'meanAbs', mAbs, 'pass', pass, ...
              'rhoWithin', RW, 'meanAbsWithin', mAbsW, 'passWithin', passW, ...
              'stability', SB, 'stabilityNames', {sbNames}, ...
              'cells', Npts, 'Bset', Bset, 'threshold', threshold, ...
              'ensemble', {ENSEMBLE}, 'nDraw', nDraw);
end

%% ------------------------------------------------------------------------
function local_block(title, names, labels, M, mA, pss, thr, nRow, nS)
   fprintf('\n  === %s ===\n', title);
   fprintf('  %-16s', 'DESIGN METRIC');
   for j = 1:nS, fprintf(' %10s', labels{j}); end
   fprintf(' %9s %6s\n', 'mean|rho|', 'pass');
   fprintf('  %s\n', repmat('-', 1, 18 + 11*nS + 16));
   for c = 1:nRow
      fprintf('  %-16s', names{c});
      for j = 1:nS, fprintf(' %10.3f', M(c, j)); end
      fprintf(' %9.3f %4d/%d\n', mA(c), pss(c), nS);
   end
   fprintf('  %s\n', repmat('-', 1, 18 + 11*nS + 16));
   fprintf('  (threshold |rho| >= %.2f)\n', thr);
end

function v = local_all(p, Bset, n, t, nB)
% All five design statistics at every burst length, in one pass per B.
   v = nan(1, 5*nB);
   for b = 1:nB
      [oT, mx, mm, cv, gi] = designMetricScore(p, Bset(b), n, t);
      v(0*nB + b) = oT;
      v(1*nB + b) = mx;
      v(2*nB + b) = mm;
      v(3*nB + b) = cv;
      v(4*nB + b) = gi;
   end
end

function sb = local_stability(X, resBar, gm, gl, nDes)
% RANK-BASED, because the first construction failed for a diagnosable reason.
%
% Stability was first measured as 1 - CV of the raw value across lengths. CV is
% sigma/|mu|, so a method whose metric sits at a consistently high level gets a
% large denominator, a small CV, and scores as "stable" for having a bad mean.
% That column then correlated strongly with mean RES - not because stability
% predicts recovery, but because it was leaking the level of the metric, which
% is already known to predict recovery.
%
% The fix is a dispersion measure that cannot see the level: rank the methods
% against each other at each length, and measure how much a method's RANK moves
% across lengths. Stability = 1 - (std of rank)/(max possible std), so it is
% scale-free and mean-free by construction, and the same transform is applied
% to RES so the two sides are comparable.
% Per method: the coefficient of variation across lengths, of each design
% statistic and of RES. Stability is reported as 1 - CV so that larger is
% better and the sign matches the other rows.
%
% Two correlations are returned for every statistic: against realized RES
% stability (the matched question) and against mean RES level (to expose any
% confound between being consistent and being good).
   uM = unique(gm);  nM = numel(uM);
   uL = unique(gl);  nL = numel(uL);

   % Rank every method against the others, separately at each length.
   Rd = nan(nM, nL, nDes);   Rr = nan(nM, nL);
   for j = 1:nL
      sel = (gl == uL(j));
      mj  = gm(sel);
      [~, im] = ismember(mj, uM);
      v = resBar(sel);
      ok = isfinite(v);
      if sum(ok) >= 3
         rk = tiedrank(v(ok));
         Rr(im(ok), j) = rk / sum(ok);       % normalised rank in [0,1]
      end
      for c = 1:nDes
         w = X(sel, c); ok = isfinite(w);
         if sum(ok) >= 3
            rk = tiedrank(w(ok));
            Rd(im(ok), j, c) = rk / sum(ok);
         end
      end
   end

   Sd = nan(nM, nDes); Sr = nan(nM, 1); Lr = nan(nM, 1);
   for i = 1:nM
      sel = (gm == uM(i));
      if sum(sel) < 4, continue; end
      Lr(i) = mean(resBar(sel), 'omitnan');
      Sr(i) = local_rankStab(squeeze(Rr(i, :)));
      for c = 1:nDes
         Sd(i, c) = local_rankStab(squeeze(Rd(i, :, c)));
      end
   end
   sb = nan(2*nDes, 1);
   for c = 1:nDes
      ok = isfinite(Sd(:, c)) & isfinite(Sr);
      if sum(ok) >= 8 && numel(unique(Sd(ok, c))) > 1
         sb(c) = corr(Sd(ok, c), Sr(ok), 'type', 'Spearman');
      end
      ok = isfinite(Sd(:, c)) & isfinite(Lr);
      if sum(ok) >= 8 && numel(unique(Sd(ok, c))) > 1
         sb(nDes + c) = corr(Sd(ok, c), Lr(ok), 'type', 'Spearman');
      end
   end
end

function s = local_rankStab(r)
% 1 - (std of normalised rank) / (max attainable std). Scale-free and level-free:
% a method that always sits in the same place scores 1 however good that place
% is, and a method that moves scores less. 0.5 is the largest std a variable on
% [0,1] can have, so it is the normaliser.
   r = r(isfinite(r));
   if numel(r) < 3, s = NaN; return; end
   s = 1 - min(std(r) / 0.5, 1);
end

function c = local_cvv(v) %#ok<DEFNU>
   v = v(isfinite(v));
   if numel(v) < 2, c = NaN; return; end
   m = mean(v);
   if m == 0, c = NaN; else, c = std(v) / abs(m); end
end

function r = local_withinLength(x, y, lens)
% Spearman across methods within each length, then averaged over lengths via
% Fisher z. Holding the length fixed removes the length trend that the pooled
% correlation cannot separate from method discrimination.
   r = NaN;
   uL = unique(lens);
   zs = []; ws = [];
   for i = 1:numel(uL)
      sel = (lens == uL(i)) & isfinite(x) & isfinite(y);
      n = sum(sel);
      if n < 5 || numel(unique(x(sel))) < 2, continue; end
      rr = corr(x(sel), y(sel), 'type', 'Spearman');
      if ~isfinite(rr), continue; end
      rr = max(min(rr, 0.999999), -0.999999);
      zs(end+1) = atanh(rr);  %#ok<AGROW>
      ws(end+1) = n - 3;      %#ok<AGROW>
   end
   if isempty(zs), return; end
   r = tanh(sum(zs .* ws) / sum(ws));
end

%% ------------------------------------------------------------------------
function p = local_perm(tpc, cache, method, N)
   key = sprintf('%s_%d', method, N);
   if isKey(cache, key), p = cache(key); return; end
   p = [];
   fld = sprintf('perms_%s', method);
   if isstruct(tpc) && isfield(tpc, fld)
      M = tpc.(fld);
      k = sprintf('N_%d', N);
      if isa(M, 'containers.Map') && M.isKey(k)
         e = M(k);
         if isstruct(e) && isfield(e, 'perm'), p = e.perm; end
      end
   end
   cache(key) = p;   % containers.Map is a handle object: this persists
end

function T = local_table(f)
   S = load(f); fn = fieldnames(S); T = [];
   for i = 1:numel(fn)
      if istable(S.(fn{i})), T = S.(fn{i}); return; end
   end
   error('design_metric_validation: no table in %s', f);
end

function lbl = local_label(name)
   REG = 'single|multi|ge\d+p\d+';
   GRD = 'common|standards|probe|legacy';
   t = regexp(name, sprintf('_(%s)_(%s)_', REG, GRD), 'tokens', 'once');
   if ~isempty(t), lbl = sprintf('%s/%s', t{1}, t{2}(1)); return; end
   t = regexp(name, sprintf('_(%s)_', REG), 'tokens', 'once');
   if ~isempty(t), lbl = sprintf('%s/?', t{1}); else, lbl = name; end
end

function v = local_opt(s, f, dflt)
   if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = dflt; end
end
