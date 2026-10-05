function K = check_kappa_sensitivity(dataDir, opts)
%CHECK_KAPPA_SENSITIVITY  What changes if C_NN carries no kappa.
%
%   K = check_kappa_sensitivity('<resultsDir>')
%   K = check_kappa_sensitivity(dataDir, struct('write', true))
%
% WHY
% ===========================================================================
% check_noise_fidelity showed that the four Gilbert-Elliott sweeps did not
% realize their labelled noise: every bin received about 0.22, so kappa, the
% realized-to-target density of a trial, runs from about 1.23 in the lowest
% bin to 0.84 in the highest. By Lemma 1 C_NN_j = BE_j * kappa, so the CR of
% every method in a GE trial carries that factor. Within one trial it is
% common to every method and cannot reorder them. RES, however, is
% standardized over all cells of a condition, across bins, so kappa can move
% it a little. This script measures how much, from the saved tables, without
% re-simulating anything.
%
% WHAT IT DOES, PER SWEEP
%   1. kappa per row, read from the row itself:
%         kappa = noiseActual * interleavedLen / (encodedLen * target)
%      (noiseActual * interleavedLen is the corrupted count E; Lemma 1.)
%   2. checks RES = w1*CR_z + w2*BE_z on the stored rows (Lemma 4).
%   3. RECOVERS how the harness standardized CR - over which rows, in which
%      groups, with which normalization - by testing candidates against the
%      stored CR_z, and reports the reproduction error. Nothing is assumed.
%   4. recomputes CR without kappa (CR / kappa, i.e. C_NN := BE_j), restandard-
%      izes it exactly the recovered way, and rebuilds RES.
%   5. reports: kappa range, largest shift in a method's mean RES, every rank
%      move among in-scope methods, and the per-length Spearman agreement of
%      the (method, length) cell means that the metric validation uses.
%
% With opts.write = true it also writes the kappa-free tables to
% <dataDir>\kappa_free\, with the config and correlation_data files copied
% alongside, so metric_scorecard and screen_methods can be run on them
% unchanged:
%
%   S2 = metric_scorecard(fullfile(dataDir, 'kappa_free'));
%
% Only CR, CR_z, RES (and C_NN, if stored) are replaced. correlation_data is
% copied as it is, so the "1 trial" column of the scorecard is NOT kappa-free;
% that column is reported for contrast only and is not a ranking criterion.
%
% OPTIONS
%   write        write the kappa-free tables                 [false]
%   dropMethods  outside the RES/validation field             [freqDeterm freqRandom]
%   minN         support used by the validation (N > 24n)     [360]
%
% R.T. Sirmen harness, 2026

   if nargin < 1 || isempty(dataDir)
      c = configure_simulation(); dataDir = char(c.dataSavePath);
   end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'write'),       opts.write = false; end
   if ~isfield(opts, 'dropMethods'), opts.dropMethods = {'freqDeterm', 'freqRandom'}; end
   if ~isfield(opts, 'minN'),        opts.minN = 360; end

   % The RES weights are READ FROM THE DATA, not assumed. The first version
   % called cfg_weights, which is a local function of screen_methods and
   % invisible from here. Rather than copy a weight - two copies is how two
   % halves of a sum come to disagree - each sweep's weights are fitted from
   % its own stored RES, CR_z and BE_z, and the residual of that fit IS the
   % Lemma 4 check. The manuscript states (0.5, 0.5).
   d = dir(fullfile(dataDir, 'KPItableDetailed_*.mat'));
   if isempty(d), error('check_kappa_sensitivity: no KPItableDetailed_*.mat in %s', dataDir); end
   outDir = fullfile(dataDir, 'kappa_free');
   if opts.write && exist(outDir, 'dir') ~= 7, mkdir(outDir); end

   fprintf('\n=== KAPPA SENSITIVITY: CR and RES with C_NN := BE (kappa removed) ===\n');
   fprintf('RES weights fitted per sweep from the stored rows; in-scope field drops: %s\n\n', strjoin(opts.dropMethods, ', '));

   K = struct('sweep', {}, 'kappaBin', {}, 'lemma4', {}, 'zScheme', {}, 'zPop', {}, ...
              'zErr', {}, 'maxDmeanRES', {}, 'moves', {}, 'rhoMin', {}, 'rhoMed', {});
   for i = 1:numel(d)
      f = fullfile(dataDir, d(i).name);
      tag = regexprep(d(i).name, '^KPItableDetailed_|\.mat$', '');
      [T, vname, S] = local_table(f);
      cfg = local_config(dataDir, d(i).name);
      need = {'method','encodedLen','interleavedLen','noiseActual','noiseBin','CR','CR_z','BE_z','RES'};
      if isempty(T) || isempty(cfg)
         fprintf(2, '%-30s  table or config missing - skipped\n', tag); continue;
      end
      miss = need(~ismember(need, T.Properties.VariableNames));
      if ~isempty(miss)
         fprintf(2, '%-30s  missing columns: %s - skipped\n', tag, strjoin(miss, ', ')); continue;
      end

      meth = string(T.method);
      len  = double(T.encodedLen); ilen = double(T.interleavedLen);
      bin  = double(T.noiseBin);   nact = double(T.noiseActual);
      CR   = double(T.CR); CRz = double(T.CR_z); BEz = double(T.BE_z); RES = double(T.RES);
      tgt  = nan(size(bin));
      okb  = bin >= 1 & bin <= numel(cfg.noiseLevels);
      tgt(okb) = cfg.noiseLevels(bin(okb));
      kap  = nact .* ilen ./ (len .* tgt);
      inS  = ~ismember(meth, string(opts.dropMethods));

      % --- 1. kappa per bin, from BE = 1 rows ------------------------------
      ub = unique(bin(okb)).'; kb = nan(size(ub));
      for k = 1:numel(ub), kb(k) = mean(kap(bin == ub(k) & ilen == len), 'omitnan'); end

      % --- 2. Lemma 4 on the stored rows ----------------------------------
      fin = isfinite(RES) & isfinite(CRz) & isfinite(BEz);
      w = ([CRz(fin) BEz(fin)] \ RES(fin)).';
      l4 = max(abs(RES(fin) - (w(1) * CRz(fin) + w(2) * BEz(fin))));

      % --- 3. recover the standardization ---------------------------------
      [scheme, gid] = local_scheme(CR, CRz, len, bin);
      [pop, zErr] = local_population(CR, CRz, gid, inS, meth, len, bin);

      % --- 4. kappa-free CR, same standardization -------------------------
      CRn = CR ./ kap;
      bad = ~isfinite(CRn); CRn(bad) = CR(bad);
      CRzn = local_apply(CRn, gid, inS, meth, len, bin, pop);
      RESn = w(1) * CRzn + w(2) * BEz;

      % --- 5. what moved ---------------------------------------------------
      um = unique(meth(inS)); mo = nan(numel(um), 1); mn = mo;
      for k = 1:numel(um)
         a = meth == um(k); mo(k) = mean(RES(a), 'omitnan'); mn(k) = mean(RESn(a), 'omitnan');
      end
      r1 = zeros(numel(um), 1); r2 = r1;
      [~, o1] = sort(mo, 'descend'); r1(o1) = 1:numel(um);
      [~, o2] = sort(mn, 'descend'); r2(o2) = 1:numel(um);
      mv = find(r1 ~= r2);
      moves = cell(numel(mv), 1);
      for k = 1:numel(mv)
         moves{k} = sprintf('%s %d->%d', um(mv(k)), r1(mv(k)), r2(mv(k)));
      end

      % per-length Spearman of (method, length) cell means, the validation unit
      sup = inS & len > opts.minN;
      ul = unique(len(sup)); rho = nan(numel(ul), 1);
      for k = 1:numel(ul)
         a = sup & len == ul(k);
         [g, ~, gi] = unique(meth(a));
         x = accumarray(gi, RES(a), [numel(g) 1], @mean);
         y = accumarray(gi, RESn(a), [numel(g) 1], @mean);
         if numel(g) >= 3, rho(k) = local_spearman(x, y); end
      end

      fprintf('%-30s  kappa by bin: %s\n', tag, sprintf('%.3f ', kb));
      fprintf('      weights fitted: w = [%.6f %.6f]; Lemma 4 residual on stored rows %.2e\n', w(1), w(2), l4);
      fprintf('      CR_z reproduced as: groups = %s, population = %s, max error %.2e%s\n', ...
              scheme, pop, zErr, local_flag(zErr));
      fprintf('      largest shift in a method''s mean RES: %.4f\n', max(abs(mn - mo)));
      if isempty(moves)
         fprintf('      rank moves among %d in-scope methods: none\n', numel(um));
      else
         fprintf('      rank moves among %d in-scope methods: %s\n', numel(um), strjoin(moves, ', '));
      end
      fprintf('      per-length Spearman, old vs kappa-free cell RES: min %.4f, median %.4f over %d lengths\n\n', ...
              min(rho), median(rho, 'omitnan'), sum(isfinite(rho)));

      K(end+1) = struct('sweep', tag, 'kappaBin', kb, 'lemma4', l4, 'zScheme', scheme, ...
                        'zPop', pop, 'zErr', zErr, 'maxDmeanRES', max(abs(mn - mo)), ...
                        'moves', {moves}, 'rhoMin', min(rho), 'rhoMed', median(rho, 'omitnan')); %#ok<AGROW>

      if opts.write
         T.CR = CRn; T.CR_z = CRzn; T.RES = RESn;
         if ismember('C_NN', T.Properties.VariableNames)
            T.C_NN = double(T.C_NN) ./ kap;
         end
         S.(vname) = T;
         save(fullfile(outDir, d(i).name), '-struct', 'S', '-v7.3');
         for pre = {'config', 'correlation_data'}
            src = fullfile(dataDir, regexprep(d(i).name, '^KPItableDetailed', pre{1}));
            if exist(src, 'file'), copyfile(src, outDir); end
         end
      end
   end

   if opts.write
      fprintf('kappa-free tables written to %s\n', outDir);
      fprintf('next:  S2 = metric_scorecard(fullfile(dataDir, ''kappa_free''));\n\n');
   end
end

% =========================================================================
function [scheme, gid] = local_scheme(CR, CRz, len, bin)
% Which grouping did the harness standardize within? The coarsest one under
% which CR_z is an exact affine function of CR in every group.
   names = {'condition', 'noise bin', 'length', 'length x bin'};
   keys  = {ones(size(len)), bin, len, [len bin]};
   scheme = 'NOT FOUND'; gid = ones(size(len));
   for s = 1:numel(names)
      [~, ~, g] = unique(keys{s}, 'rows');
      worst = 0;
      for k = 1:max(g)
         a = g == k & isfinite(CR) & isfinite(CRz);
         if sum(a) < 3 || max(CR(a)) == min(CR(a)), continue; end
         p = [CR(a) ones(sum(a), 1)] \ CRz(a);
         worst = max(worst, max(abs(CRz(a) - [CR(a) ones(sum(a), 1)] * p)));
      end
      if worst < 1e-6 * max(1, max(abs(CRz)))
         scheme = names{s}; gid = g; return;
      end
   end
end

function [best, err] = local_population(CR, CRz, gid, inS, meth, len, bin)
% Over which rows were mu and sigma taken? Every candidate is tried against
% the stored CR_z and the one that reproduces it is used.
   cands = {'rows in scope, n-1', 'rows in scope, n', 'all rows, n-1', 'all rows, n', ...
            'cells in scope, n-1', 'cells all, n-1'};
   err = inf; best = cands{1};
   for c = 1:numel(cands)
      z = local_apply(CR, gid, inS, meth, len, bin, cands{c});
      e = max(abs(z - CRz), [], 'omitnan');
      if e < err, err = e; best = cands{c}; end
   end
end

function z = local_apply(x, gid, inS, meth, len, bin, pop)
   z = nan(size(x));
   for k = 1:max(gid)
      a = gid == k;
      if contains(pop, 'in scope'), b = a & inS; else, b = a; end
      if startsWith(pop, 'cells')
         [~, ~, ci] = unique([double(categorical(meth(b))) len(b) bin(b)], 'rows');
         v = accumarray(ci, x(b), [], @(q) mean(q, 'omitnan'));
      else
         v = x(b); v = v(isfinite(v));
      end
      if endsWith(pop, ', n'), s = std(v, 1); else, s = std(v, 0); end
      z(a) = (x(a) - mean(v)) ./ s;
   end
end

function r = local_spearman(x, y)
   r = corr_(local_rank(x), local_rank(y));
end

function c = corr_(a, b)
   a = a - mean(a); b = b - mean(b);
   c = sum(a .* b) / sqrt(sum(a .^ 2) * sum(b .^ 2));
end

function r = local_rank(v)
% average ranks for ties, no toolbox
   [s, o] = sort(v(:)); r = zeros(size(s)); n = numel(s); i = 1;
   while i <= n
      j = i;
      while j < n && s(j + 1) == s(i), j = j + 1; end
      r(o(i:j)) = (i + j) / 2; i = j + 1;
   end
end

function s = local_flag(e)
   if e < 1e-6, s = ''; else, s = '   <-- NOT REPRODUCED; results below are approximate'; end
end

function [T, vname, S] = local_table(f)
   S = load(f); fn = fieldnames(S); T = []; vname = '';
   for i = 1:numel(fn)
      if istable(S.(fn{i})), T = S.(fn{i}); vname = fn{i}; return; end
   end
end

function cfg = local_config(dataPath, kpiName)
   cfg = [];
   fp = fullfile(dataPath, regexprep(kpiName, '^KPItableDetailed', 'config'));
   if ~exist(fp, 'file'), return; end
   S = load(fp); fn = fieldnames(S);
   for i = 1:numel(fn)
      v = S.(fn{i});
      if isstruct(v) && isscalar(v) && isfield(v, 'noiseLevels'), cfg = v; return; end
   end
end
