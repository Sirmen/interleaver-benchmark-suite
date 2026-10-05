function R = validation_supplement(dataPath, opts)
%VALIDATION_SUPPLEMENT  Design-time metrics under the reviewer-requested fields.
%
%   R = validation_supplement(dataPath, struct('tableDir', tableDir))
%
% Recomputes the within-length (method, length) cell correlation of Table IX
% for the five design-time load statistics, under six readings of the same
% campaign:
%
%   base     in-scope field, target RES            (= Table IX)
%   CR       in-scope field, target CR alone        (no rate term, no z-score)
%   nonext   in-scope, the five frame-extending methods removed. BE = 1 for
%            every remaining row, so within a condition RES is an increasing
%            affine function of CR and rho(M, RES) = rho(M, CR) exactly: the
%            target no longer depends on the standardization set at all.
%   le_t     only trials whose realized mean load per codeword is <= t
%   gt_t     only trials whose realized mean load per codeword is  > t
%   lomo     base, recomputed 21 times with one method left out: the range of
%            mean |rho| and of the pass count over the omissions
%
% The published metrics were computed for the same six readings from the
% correlation_data files (pub_supplement.py); this file adds the design-time
% ones, which need the permutations. delta_G and eta_ES are recomputed here
% as well - all fourteen, so this one file reproduces every number of the
% Section VIII-G paragraph; their "base" column must reproduce Table IX
% (delta_G 0.909, eta_ES 0.913, ...), which checks the whole pipeline.
%
% Mean load per codeword = n * E / encodedLen, with E = noiseActual *
% interleavedLen the corrupted-symbol count shared by all methods of a trial.
%
% Uses designMetricScore (exhaustive giniLoad, v26). Design statistics are
% cached by (method, N): the permutation does not depend on the regime.
%
% R. T. Sirmen harness, 2026-09 (v26 revision)

   if nargin < 2, opts = struct(); end
   dataPath = char(dataPath);
   n = local_opt(opts, 'FECn', 15);
   t = local_opt(opts, 'FECt', 3);
   minN = local_opt(opts, 'minN', 24 * n);          % same common support as Table IX
   theta = local_opt(opts, 'threshold', 0.30);
   nDraw = local_opt(opts, 'nDraw', 15);
   OUTS = {'freqDeterm', 'freqRandom'};
   EXT  = {'helical', 'helicalScan', 'matrix', 'prime', 'spiral'};
   ENSEMBLE = {'random', 'freqRandom'};
   DES = {'giniLoad', 12; 'meanMaxCW', 24; 'maxErrCW', 24; 'overT', 12; 'cvLoad', 24; 'giniLoad', 8};
   PUBREF = {'eta_ES', 'delta_G', 'S_ECC', 'delta_BS', 'eta_sep', 'laplacianEnergy', 'U_ECC', ...
             'sepMin', 'adjCV', 'PSR', 'V_ECC', 'adjMin', 'S_sf', 'S_factor'};   % Table IX order

   tableDir = local_opt(opts, 'tableDir', '');
   if isempty(tableDir) || exist(fullfile(char(tableDir), 'table_factors_precomputed.mat'), 'file') ~= 2
      [tableDir, erF] = find_table_dir(dataPath);
      if erF ~= "", error('validation_supplement: %s', erF); end
   end
   [tpc, erT] = PrecomputedInterleaverLoader(tableDir);
   if erT ~= "", error('validation_supplement: %s', erT); end
   [tp, tfac, erP] = PrimeFactorLoader(tableDir);
   if erP ~= "", error('validation_supplement: %s', erP); end

   d = dir(fullfile(dataPath, 'correlation_data_*.mat'));
   if isempty(d), error('validation_supplement: no correlation_data_*.mat in %s', dataPath); end

   mNames = [cellfun(@(s, b) sprintf('%s (%dn)', s, b), DES(:,1), DES(:,2), 'UniformOutput', false); PUBREF(:)];
   nMet = numel(mNames);
   VAR = {'base', 'CR', 'nonext', 'le_t', 'gt_t'};
   RHO = nan(nMet, numel(d), numel(VAR));
   cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
   LOMO = {};                                        % per sweep: [nMet x nMethods]
   methList = {};

   fprintf('\n=================================================================\n');
   fprintf('  VALIDATION SUPPLEMENT  (n,t) = (%d,%d), common support N > %d\n', n, t, minN);
   fprintf('=================================================================\n');
   for si = 1:numel(d)
      f = fullfile(d(si).folder, d(si).name);
      fprintf('  %-48s', d(si).name); tic;
      L = load(f); fn = fieldnames(L); D = [];
      for i = 1:numel(fn), if isstruct(L.(fn{i})), D = L.(fn{i}); break; end, end
      if isempty(D) || ~isfield(D, 'methodNames'), fprintf(2, ' no methodNames - skipped\n'); continue; end
      names = cellstr(D.methodNames(:));
      meth  = string(names(double(D.methodID(:))));
      len   = double(D.encodedLen(:));
      E     = double(D.noiseActual(:)) .* double(D.interleavedLen(:));
      loadCW = n * E ./ len;
      keep  = len > minN & ~ismember(meth, OUTS);
      ext   = ismember(meth, EXT);

      % design statistics per (method, length), cached across sweeps
      [gAll, gmAll, glAll] = findgroups(meth(keep), len(keep));   %#ok<ASGLU>
      uKeys = unique(strcat(gmAll, "_", string(glAll)));
      for k = 1:numel(uKeys)
         key = char(uKeys(k));
         if cache.isKey(key), continue; end
         parts = split(uKeys(k), "_"); mn = char(parts(1)); N = str2double(parts(end));
         cache(key) = local_design(mn, N, tpc, tp, tfac, ENSEMBLE, nDraw, DES, n, t);
      end

      masks = {keep, keep, keep & ~ext, keep & loadCW <= t, keep & loadCW > t};
      tgts  = {'RES', 'CR', 'RES', 'RES', 'RES'};
      for vi = 1:numel(VAR)
         [X, y, gl, gm] = local_cells(D, meth, len, masks{vi}, tgts{vi}, cache, PUBREF);
         RHO(:, si, vi) = local_fz(X, y, gl);
         if vi == 1
            um = unique(gm); lo = nan(nMet, numel(um));
            for j = 1:numel(um)
               sel = gm ~= um(j);
               lo(:, j) = local_fz(X(sel, :), y(sel), gl(sel));
            end
            LOMO{end+1} = lo; methList{end+1} = cellstr(um); %#ok<AGROW>
         end
      end
      fprintf(' %5.1f s\n', toc);
   end

   % ---- optional export of the design statistics per (method, length) -------
   % The cache holds every design statistic this function computed, keyed by
   % method and encoded length. Writing it out lets the per-cell values be
   % checked, and reused, without recomputing a single permutation.
   csvOut = local_opt(opts, 'exportCSV', '');
   if ~isempty(csvOut)
      ks = cache.keys; fid = fopen(csvOut, 'w');
      fprintf(fid, 'method,encodedLen');
      for k = 1:size(DES, 1), fprintf(fid, ',%s_%dn', DES{k, 1}, DES{k, 2}); end
      fprintf(fid, '\n');
      for k = 1:numel(ks)
         parts = split(string(ks{k}), "_");
         fprintf(fid, '%s,%s', parts(1), parts(end));
         fprintf(fid, ',%.10g', cache(ks{k}));
         fprintf(fid, '\n');
      end
      fclose(fid);
      fprintf('  design statistics of %d cells written to %s\n', numel(ks), csvOut);
   end

   % ---- report --------------------------------------------------------------
   fprintf('\n  %-18s', 'metric');
   for vi = 1:numel(VAR), fprintf('%14s', VAR{vi}); end
   fprintf('%26s\n', 'LOMO |rho| range, pass');
   fprintf('  %s\n', repmat('-', 1, 18 + 14*numel(VAR) + 26));
   for c = 1:nMet
      fprintf('  %-18s', mNames{c});
      for vi = 1:numel(VAR)
         v = RHO(c, :, vi);
         if all(~isfinite(v)), fprintf('%14s', 'undef'); continue; end
         fprintf('   %6.3f %d/%d', mean(abs(v), 'omitnan'), sum(abs(v) >= theta), sum(isfinite(v)));
      end
      % LOMO: methods common to all sweeps, drop each in turn everywhere
      allM = methList{1}; for s = 2:numel(methList), allM = intersect(allM, methList{s}); end
      mv = nan(numel(allM), 1); pv = nan(numel(allM), 1);
      for j = 1:numel(allM)
         r = nan(1, numel(LOMO));
         for s = 1:numel(LOMO)
            jj = find(strcmp(methList{s}, allM{j}), 1);
            r(s) = LOMO{s}(c, jj);
         end
         mv(j) = mean(abs(r), 'omitnan'); pv(j) = sum(abs(r) >= theta);
      end
      fprintf('   [%.3f, %.3f] %d-%d\n', min(mv), max(mv), min(pv), max(pv));
   end
   fprintf(['\n  base must reproduce Table IX for the published rows (delta_G 0.909, eta_ES 0.913);\n' ...
            '  giniLoad (12n) may differ from 0.878 in the third decimal only, because\n' ...
            '  it is now exhaustive rather than subsampled.\n']);
   fprintf('  ratio giniLoad(12n)/delta_G per reading:');
   for vi = 1:numel(VAR)
      iG = find(strcmp(mNames, 'delta_G'), 1);
      a = mean(abs(RHO(1, :, vi)), 'omitnan'); b = mean(abs(RHO(iG, :, vi)), 'omitnan');
      fprintf('  %s %.3f', VAR{vi}, a / b);
   end
   fprintf('\n\n');
   R = struct('metrics', {mNames}, 'readings', {VAR}, 'rho', RHO, 'files', {{d.name}}, ...
              'lomo', {LOMO}, 'lomoMethods', {methList});
end

% =========================================================================
function v = local_design(mn, N, tpc, tp, tfac, ENSEMBLE, nDraw, DES, n, t)
   nD = size(DES, 1); v = nan(1, nD);
   if ismember(mn, ENSEMBLE)
      acc = zeros(1, nD); got = 0;
      for dr = 1:nDraw
         [~, p] = interleaver_generic_pc(1:N, mn, 0, 0, [], 1000 + dr, tp, tfac, struct());
         if isempty(p), continue; end
         acc = acc + local_stats(p, DES, n, t); got = got + 1;
      end
      if got > 0, v = acc / got; end
   else
      p = local_perm(tpc, mn, N);
      if ~isempty(p), v = local_stats(p, DES, n, t); end
   end
end

function v = local_stats(p, DES, n, t)
   v = nan(1, size(DES, 1));
   for k = 1:size(DES, 1)
      B = DES{k, 2} * n;
      [oT, mx, mm, cv, gi] = designMetricScore(p, B, n, t);
      switch DES{k, 1}
         case 'giniLoad',  v(k) = gi;
         case 'meanMaxCW', v(k) = mm;
         case 'maxErrCW',  v(k) = mx;
         case 'overT',     v(k) = oT;
         case 'cvLoad',    v(k) = cv;
      end
   end
end

function [X, y, gl, gm] = local_cells(D, meth, len, mask, tgt, cache, PUBREF)
   [g, gm, gl] = findgroups(meth(mask), len(mask));
   yy = double(D.(tgt)(:)); y = splitapply(@(z) mean(z, 'omitnan'), yy(mask), g);
   keys = strcat(gm, "_", string(gl));
   nDes = numel(cache(char(keys(1))));
   X = nan(numel(gm), nDes + numel(PUBREF));
   for k = 1:numel(gm), X(k, 1:nDes) = cache(char(keys(k))); end
   for c = 1:numel(PUBREF)
      xx = double(D.(PUBREF{c})(:));
      X(:, nDes + c) = splitapply(@(z) mean(z, 'omitnan'), xx(mask), g);
   end
end

function r = local_fz(X, y, gl)
% within-length Spearman, Fisher z weighted by (m - 3), as in metric_scorecard
   nM = size(X, 2); r = nan(nM, 1); uL = unique(gl);
   for c = 1:nM
      zs = []; ws = [];
      for i = 1:numel(uL)
         at = gl == uL(i); x = X(at, c); yy = y(at);
         ok = isfinite(x) & isfinite(yy);
         if sum(ok) < 5 || numel(unique(x(ok))) < 2 || numel(unique(yy(ok))) < 2, continue; end
         rr = local_spearman(x(ok), yy(ok));
         if ~isfinite(rr), continue; end
         rr = max(min(rr, 0.999999), -0.999999);
         zs(end+1) = atanh(rr); ws(end+1) = sum(ok) - 3; %#ok<AGROW>
      end
      if ~isempty(zs), r(c) = tanh(sum(zs .* ws) / sum(ws)); end
   end
end

function r = local_spearman(x, y)
% Pearson on average ranks = corr(...,'type','Spearman') with ties averaged;
% written out so the file needs no toolbox.
   rx = local_rank(x); ry = local_rank(y);
   rx = rx - mean(rx); ry = ry - mean(ry);
   r = sum(rx .* ry) / sqrt(sum(rx.^2) * sum(ry.^2));
end

function r = local_rank(x)
   x = x(:); [xs, ix] = sort(x); r = zeros(size(x)); i = 1; m = numel(x);
   while i <= m
      j = i; while j < m && xs(j+1) == xs(i), j = j + 1; end
      r(ix(i:j)) = (i + j) / 2; i = j + 1;
   end
end

function p = local_perm(tpc, method, N)
   p = []; fld = sprintf('perms_%s', method);
   if isstruct(tpc) && isfield(tpc, fld)
      M = tpc.(fld); k = sprintf('N_%d', N);
      if isa(M, 'containers.Map') && M.isKey(k)
         e = M(k); if isstruct(e) && isfield(e, 'perm'), p = e.perm; end
      end
   end
end

function v = local_opt(s, f, dflt)
   if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = dflt; end
end
