function X = metric_crosscorr(dataDir, opts)
%METRIC_CROSSCORR  Metric-to-metric cross-correlation, and the mediation test.
%
%   X = metric_crosscorr(dataDir)
%   X = metric_crosscorr(dataDir, struct('apply', true))
%
% WHY THIS EXISTS
% ===========================================================================
% Section VIII-G advances one claim that no surviving artefact supports:
% S_sf correlates weakly with RES yet strongly with V_ECC, which suggests an
% indirect path S_sf -> V_ECC -> CR. The crossCorrResults_* files it rested on
% were fitted to the pre-rebuild method field and were renamed .stale; the
% function that built them is gone with the pipeline it belonged to.
%
% Two pairwise correlations do not establish a path. If S_sf acts on CR only
% through V_ECC, then holding V_ECC fixed must remove the S_sf-CR association:
%
%       rho(S_sf, CR | V_ECC) = [ r_sc - r_sv * r_vc ]
%                               / sqrt( (1 - r_sv^2)(1 - r_vc^2) )
%
% must fall toward zero while r_sv and r_vc stay large. If it does not, the
% claim is a restatement of two correlations and must be withdrawn rather than
% repeated. This function computes the full matrix AND that partial, so the
% claim is settled either way instead of being carried on plausibility.
%
% UNIT OF ANALYSIS
% ===========================================================================
% The (method, length) cell mean within length, the same unit Section VIII-A
% argues for and the same one Table IX uses. A pooled per-trial matrix is
% computed alongside it, because a metric pair can look related pooled and
% unrelated within length for exactly the reason Section VIII-C sets out, and
% the two must be visibly separate rather than silently averaged.
%
% Out-of-scope methods (Section III-I) are excluded by default. They are two
% leverage points in a field of twenty-odd, and Section VIII-G measures what
% they do to a correlation; there is no reason to let them do it again here.
%
% OPTIONS
%   dropMethods   methods excluded          [{'freqDeterm','freqRandom'}]
%   minN          smallest length scored    [360]
%   apply         write crossCorrResults_*  [false]
%   pairs         extra mediation triples to test, as {x,m,y} rows

   if nargin < 1 || isempty(dataDir)
      c = configure_simulation(); dataDir = char(c.dataSavePath);
   end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'dropMethods'), opts.dropMethods = {'freqDeterm','freqRandom'}; end
   if ~isfield(opts, 'minN'),        opts.minN  = 360;   end
   if ~isfield(opts, 'apply'),       opts.apply = false; end
   if ~isfield(opts, 'pairs')
      % x -> m -> y : the claim under test, and two controls that should
      % behave differently if the partial correlation is doing its job.
      opts.pairs = { 'S_sf',   'V_ECC', 'CR'; ...
                     'S_sf',   'U_ECC', 'CR'; ...
                     'eta_sep','delta_G','CR' };
   end

   PUB = {'delta_G','eta_ES','S_ECC','eta_sep','delta_BS','PSR','U_ECC', ...
          'V_ECC','adjMin','sepMin','adjCV','laplacianEnergy','S_sf','S_factor'};
   TARGET = {'CR','RES'};

   d = dir(fullfile(dataDir, 'correlation_data_*.mat'));
   if isempty(d), error('metric_crosscorr: no correlation_data_*.mat in %s', dataDir); end

   fprintf('\n=== METRIC CROSS-CORRELATION  (Spearman) ===\n%s\n', dataDir);
   if ~isempty(opts.dropMethods)
      fprintf('excluded: %s\n', strjoin(opts.dropMethods, ', '));
   end
   fprintf('unit: (method, length) cell mean within length; N > %d\n\n', opts.minN);

   names = [PUB, TARGET];
   nV = numel(names);
   accCell = zeros(nV); accPear = zeros(nV); accTrial = zeros(nV); nSweep = 0;
   X = struct('sweep', {}, 'crossCorrMatrix', {}, 'validMetrics', {}, 'pooled', {});

   for k = 1:numel(d)
      f = fullfile(dataDir, d(k).name);
      [V, len, meth, ok] = local_load(f, names, opts.dropMethods);
      if ~ok, fprintf('  %-46s unreadable - SKIPPED\n', d(k).name); continue; end

      keep = len > opts.minN;
      V = V(keep, :); len = len(keep); meth = meth(keep);
      if isempty(V), fprintf('  %-46s no rows above minN\n', d(k).name); continue; end

      % --- cell means, then Spearman within length, Fisher-z averaged -------
      g = local_group(meth, len);
      C = zeros(max(g), nV); L = zeros(max(g), 1);
      for c = 1:max(g)
         at = (g == c);
         C(c, :) = mean(V(at, :), 1, 'omitnan');
         L(c) = len(find(at, 1));
      end
      Rcell  = local_withinLength(C, L, @local_spear);
      Pcell  = local_withinLength(C, L, @local_pears);
      Rtrial = local_spear(V);            % pooled per trial, for contrast

      accCell  = accCell  + Rcell;
      accPear  = accPear  + Pcell;
      accTrial = accTrial + Rtrial;
      nSweep = nSweep + 1;

      X(end+1) = struct('sweep', d(k).name, 'crossCorrMatrix', Rcell, ...
                        'validMetrics', {names}, 'pooled', Rtrial); %#ok<AGROW>

      if opts.apply, local_write(dataDir, d(k).name, Rcell, names, Rtrial); end
      fprintf('  %-46s %d cells\n', d(k).name, size(C,1));
   end

   if nSweep == 0, error('metric_crosscorr: nothing usable'); end
   Rc = accCell / nSweep; Rt = accTrial / nSweep; Pc = accPear / nSweep;

   % ---- the mediation test ------------------------------------------------
   fprintf('\n  MEDIATION TEST   does x reach y only through m?\n');
   fprintf('  %-10s %-10s %-6s %8s %8s %8s %9s %9s  %s\n', ...
           'x', 'm', 'y', 'r(x,y)', 'r(x,m)', 'r(m,y)', 'part.S', 'part.P', 'reading');
   fprintf('  %s\n', repmat('-', 1, 92));
   for p = 1:size(opts.pairs, 1)
      xi = find(strcmp(names, opts.pairs{p,1}), 1);
      mi = find(strcmp(names, opts.pairs{p,2}), 1);
      yi = find(strcmp(names, opts.pairs{p,3}), 1);
      if isempty(xi) || isempty(mi) || isempty(yi)
         fprintf('  %-10s %-10s %-6s   (a variable is absent)\n', opts.pairs{p,:}); continue;
      end
      rxy = Rc(xi,yi); rxm = Rc(xi,mi); rmy = Rc(mi,yi);
      [parS, okS] = local_partial(rxy, rxm, rmy);
      [parP, okP] = local_partial(Pc(xi,yi), Pc(xi,mi), Pc(mi,yi));
      if ~okS || ~okP
         fprintf('  %-10s %-10s %-6s %8.3f %8.3f %8.3f %9s %9s  %s\n', ...
                 opts.pairs{p,:}, rxy, rxm, rmy, 'undef', 'undef', ...
                 'UNDEFINED: a leg is collinear on the ranks; mediation not separable');
         continue;
      end
      % Graded, because a partial correlation measures how much of an
      % association survives conditioning, not whether a structural model is
      % true. The Pearson column decides, since only there does a pure path
      % drive the partial to zero; the Spearman column is reported for
      % consistency with every other correlation in the paper.
      frac = abs(parP) / max(abs(Pc(xi,yi)), eps);
      if abs(rxm) <= 0.3 || abs(rmy) <= 0.3
         note = 'NOT mediation: a leg is too weak to carry the association';
      elseif frac < 0.25
         note = 'consistent with mediation: conditioning removes the association';
      elseif frac < 0.70
         note = 'partial mediation: some of the association bypasses m';
      else
         note = 'NOT mediation: the association survives conditioning';
      end
      fprintf('  %-10s %-10s %-6s %8.3f %8.3f %8.3f %9.3f %9.3f  %s\n', ...
              opts.pairs{p,:}, rxy, rxm, rmy, parS, parP, note);
   end

   % ---- the matrix, printed once, cell level ------------------------------
   fprintf('\n  CELL-LEVEL MATRIX, mean over %d sweeps (|r| < 0.10 shown as . ; n/a = a variable is constant here)\n\n     ', nSweep);
   for j = 1:nV, fprintf('%7s', local_short(names{j})); end
   fprintf('\n');
   for i = 1:nV
      fprintf('  %-14s', local_short(names{i}));
      for j = 1:nV
         if i == j, fprintf('%7s', '1');
         elseif ~isfinite(Rc(i,j)), fprintf('%7s', 'n/a');
         elseif abs(Rc(i,j)) < 0.10, fprintf('%7s', '.');
         else, fprintf('%7.2f', Rc(i,j)); end
      end
      fprintf('\n');
   end

   fprintf(['\n  Rows are cell means within length, Fisher-z averaged over lengths\n' ...
            '  and then over sweeps. The pooled per-trial matrix is in the returned\n' ...
            '  struct as .pooled; a pair that is strong there and weak here differs\n' ...
            '  for the reason of Section VIII-C and must not be quoted from the\n' ...
            '  pooled form.\n\n']);
   if ~opts.apply
      fprintf('  DRY RUN - re-run with struct(''apply'', true) to write crossCorrResults_*.\n\n');
   end
end

% =========================================================================
function [V, len, meth, ok] = local_load(f, names, drop)
   V = []; len = []; meth = []; ok = false;
   S = load(f); fn = fieldnames(S); D = [];
   for i = 1:numel(fn), if isstruct(S.(fn{i})), D = S.(fn{i}); break; end, end
   if isempty(D) || ~isfield(D, 'encodedLen'), return; end
   len = double(D.encodedLen(:)); nR = numel(len);

   if isfield(D, 'methodNames') && isfield(D, 'methodID')
      nameList = cellstr(D.methodNames(:));
      mid = double(D.methodID(:));
      if max(mid) > numel(nameList) || min(mid) < 1, return; end
      meth = nameList(mid);
   else
      % Without methodNames the code-to-name mapping would have to be guessed
      % from sort order, which is the failure fix_correlation_data exists to
      % remove. Refuse rather than guess.
      fprintf(2, '  %s carries no methodNames - run fix_correlation_data first\n', f);
      return;
   end

   V = nan(nR, numel(names));
   for j = 1:numel(names)
      if isfield(D, names{j})
         v = double(D.(names{j})(:));
         if numel(v) == nR, V(:, j) = v; end
      end
   end
   if ~isempty(drop)
      keep = ~ismember(meth, drop);
      V = V(keep, :); len = len(keep); meth = meth(keep);
   end
   ok = true;
end

function g = local_group(meth, len)
   key = strcat(meth(:), '|', cellstr(num2str(len(:))));
   [~, ~, g] = unique(key);
end

function R = local_withinLength(C, L, cfun)
% Spearman within each length, combined by Fisher z with weight n-3. The
% weighting and the transform are the same as metric_scorecard uses, so a
% number here is comparable with a number there.
   uL = unique(L); nV = size(C, 2);
   Z = zeros(nV); W = zeros(nV);
   for k = 1:numel(uL)
      at = (L == uL(k));
      if sum(at) < 5, continue; end
      r = cfun(C(at, :));
      w = max(0, sum(at) - 3);
      r = max(min(r, 1 - 1e-12), -1 + 1e-12);
      z = atanh(r);
      live = isfinite(z);
      z(~live) = 0;
      Z = Z + w * z; W = W + w * live;   % a constant column adds no weight
   end
   R = tanh(Z ./ W);          % W = 0 where no length could measure the pair
   R(W == 0) = NaN;
   R(1:nV+1:end) = 1;
end

function [p, ok] = local_partial(rxy, rxm, rmy)
% Undefined when a leg is collinear: the denominator goes to zero and the
% ratio diverges. The self-test produced 185.79 from exactly that, which is
% not a large partial correlation but an absent one.
   den2 = (1 - rxm^2) * (1 - rmy^2);
   if den2 < 1e-6, p = NaN; ok = false; return; end
   p = max(min((rxy - rxm*rmy) / sqrt(den2), 1), -1); ok = true;
end

function R = local_pears(M)
% Pearson on the values. It is reported beside the Spearman partial because
% the mediation arithmetic is exact only for Pearson: under a linear Gaussian
% path r_xy = r_xm*r_my holds, so a pure path drives the partial to zero.
% On ranks that identity does not hold, and a pure path leaves a residual that
% is a property of the rank transform rather than of the data.
   [nR, nV] = size(M);
   A = M;
   for j = 1:nV
      v = A(:, j); ok = isfinite(v);
      if any(ok), v(~ok) = mean(v(ok)); else, v(:) = 0; end
      A(:, j) = v;
   end
   A = A - mean(A, 1);
   s = sqrt(sum(A.^2, 1));
   dead = (s == 0); s(dead) = 1;
   R = (A' * A) ./ (s' * s);
   R = max(min(R, 1), -1);
   R(dead, :) = NaN; R(:, dead) = NaN;
   R(1:size(R,1)+1:end) = 1;
end

function R = local_spear(M)
% Spearman = Pearson on ranks, columns ranked independently, NaNs given the
% column mean rank so a missing metric does not delete a whole row.
   [nR, nV] = size(M);
   Rk = zeros(nR, nV);
   for j = 1:nV
      v = M(:, j); ok = isfinite(v);
      r = nan(nR, 1);
      if any(ok)
         r(ok) = local_tiedrank(v(ok));
         r(~ok) = mean(r(ok));
      else
         r(:) = 1;
      end
      Rk(:, j) = r;
   end
   Rk = Rk - mean(Rk, 1);
   s = sqrt(sum(Rk.^2, 1));
   % A CONSTANT COLUMN HAS NO CORRELATION, NOT A CORRELATION OF ZERO.
   % Substituting eps for a zero norm returns 0, which prints as "no
   % association measured" when the truth is "not measurable" - the same class
   % of error as printing a partial correlation of 185.79. NaN, and a legend
   % entry for it, is the honest output.
   dead = (s == 0); s(dead) = 1;
   R = (Rk' * Rk) ./ (s' * s);
   R = max(min(R, 1), -1);
   R(dead, :) = NaN; R(:, dead) = NaN;
   R(1:size(R,1)+1:end) = 1;
end

function r = local_tiedrank(v)
   [~, i] = sort(v); r = zeros(size(v)); r(i) = 1:numel(v);
   [u, ~, g] = unique(v);
   for k = 1:numel(u)
      at = (g == k);
      if sum(at) > 1, r(at) = mean(r(at)); end
   end
end

function s = local_short(n)
   s = n;
   if numel(s) > 6, s = s(1:6); end
end

function local_write(dataDir, corrName, R, names, Rt)
   base = regexprep(corrName, '^correlation_data_', 'crossCorrResults_');
   crossCorrResults = struct('crossCorrMatrix', R, 'validMetrics', {names}, ...
                             'pooledMatrix', Rt, 'unit', 'cellMeanWithinLength', ...
                             'built', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<NASGU>
   fp = fullfile(dataDir, base);
   save(fp, 'crossCorrResults');
   st = [fp '.stale'];
   if exist(st, 'file'), delete(st); end
   fprintf('     written: %s\n', base);
end
