function R = target_sensitivity(dataPath, opts)
%TARGET_SENSITIVITY  Table 4 associations against outcome targets other than RES.
%
%   R = target_sensitivity(dataPath, struct('tableDir', tableDir))
%
% A referee can object that the metrics are validated against RES, a composite
% defined by the same author, and to a lesser degree against CR, which is a
% floored and density-corrected transform of the decoded error rate. This
% script recomputes the within-length (method, length) cell correlation of
% Table 4 against four targets, on the same cells and with the same estimator
% (Spearman within length, Fisher z over lengths with weight n - 3, mean of
% |rho| over the condition files):
%
%   RES      the composite                                   (= Table 4)
%   CR       recovery alone                                  (= Table S3 row)
%   DER      the decoded symbol error rate with interleaving, decodeErrRate,
%            exactly as the simulation recorded it: no floor, no C_NN, no
%            z-score. A good metric correlates NEGATIVELY with it; |rho| is
%            what is compared.
%   DERgain  decErrRate_woInt - decodeErrRate, the absolute reduction against
%            the uninterleaved baseline of the same trial.
%
% NOTHING IS RE-SIMULATED. decodeErrRate and decErrRate_woInt are columns of
% KPItableDetailed_*.mat; the metric values are in correlation_data_*.mat.
% The two files of a sweep are row-aligned by construction, and that is
% CHECKED here rather than assumed: method, encodedLen and CR must agree row
% by row, or the sweep is refused.
%
% The in-scope field and the common support are those of Table 4: freqDeterm
% and freqRandom excluded, N > 24n.
%
% OPTIONS  tableDir, FECn (15), FECt (3), minN (24n), threshold (0.30),
%          outDir (the current folder), nDraw (15)
%
% R. T. Sirmen harness, 2026-11

   if nargin < 2, opts = struct(); end
   dataPath = char(dataPath);
   n = local_opt(opts, 'FECn', 15);
   t = local_opt(opts, 'FECt', 3);
   minN  = local_opt(opts, 'minN', 24 * n);
   theta = local_opt(opts, 'threshold', 0.30);
   nDraw = local_opt(opts, 'nDraw', 15);
   outDir = char(local_opt(opts, 'outDir', pwd));
   OUTS = {'freqDeterm', 'freqRandom'};
   ENSEMBLE = {'random', 'freqRandom'};
   DES = {'giniLoad', 12; 'meanMaxCW', 24; 'maxErrCW', 24; 'overT', 12; 'cvLoad', 24};
   PUBREF = {'delta_G', 'eta_ES', 'S_ECC', 'delta_BS', 'eta_sep', 'sepMin', ...
             'laplacianEnergy', 'U_ECC', 'V_ECC', 'PSR', 'adjCV', 'adjMin', 'S_sf', 'S_factor'};
   TGT = {'RES', 'CR', 'DER', 'DERgain'};

   tableDir = local_opt(opts, 'tableDir', '');
   if isempty(tableDir) || exist(fullfile(char(tableDir), 'table_factors_precomputed.mat'), 'file') ~= 2
      [tableDir, erF] = find_table_dir(dataPath);
      if erF ~= "", error('target_sensitivity: %s', erF); end
   end
   [tpc, erT] = PrecomputedInterleaverLoader(tableDir);
   if erT ~= "", error('target_sensitivity: %s', erT); end
   [tp, tfac, erP] = PrimeFactorLoader(tableDir);
   if erP ~= "", error('target_sensitivity: %s', erP); end

   d = dir(fullfile(dataPath, 'correlation_data_*.mat'));
   if isempty(d), error('target_sensitivity: no correlation_data_*.mat in %s', dataPath); end

   stamp = datestr(now, 'yymmdd_HHMMSS'); %#ok<TNOW1,DATST>
   if ~exist(outDir, 'dir'), mkdir(outDir); end
   logFile = fullfile(outDir, ['target_sensitivity_' stamp '.txt']);
   csvFile = fullfile(outDir, ['target_sensitivity_' stamp '.csv']);
   % The log is a diary of its own. The caller's diary (reproduce_paper is
   % usually run under one) is switched back on at exit; diary('off') alone
   % silenced everything printed after this function returned.
   prevDiary = {get(0, 'Diary'), get(0, 'DiaryFile')};
   diary('off'); diary(logFile);
   cleanupObj = onCleanup(@() local_restore_diary(prevDiary)); %#ok<NASGU>

   mNames = [cellfun(@(s, b) sprintf('%s (%dn)', s, b), DES(:,1), DES(:,2), 'UniformOutput', false); PUBREF(:)];
   nMet = numel(mNames);
   RHO = nan(nMet, numel(d), numel(TGT));
   cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
   used = false(1, numel(d));

   fprintf('\n=================================================================\n');
   fprintf('  TARGET SENSITIVITY  (n,t) = (%d,%d), common support N > %d\n', n, t, minN);
   fprintf('  data  %s\n', dataPath);
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

      % --- the decoded error rates, from the KPI table of the SAME sweep ---
      kf = fullfile(d(si).folder, strrep(d(si).name, 'correlation_data_', 'KPItableDetailed_'));
      if exist(kf, 'file') ~= 2, fprintf(2, ' no %s - skipped\n', kf); continue; end
      K = load(kf); kn = fieldnames(K); T = [];
      for i = 1:numel(kn), if istable(K.(kn{i})), T = K.(kn{i}); break; end, end
      need = {'method', 'encodedLen', 'CR', 'decodeErrRate', 'decErrRate_woInt'};
      if isempty(T) || ~all(ismember(need, T.Properties.VariableNames))
         fprintf(2, ' KPI table lacks a required column - skipped\n'); continue;
      end
      if height(T) ~= numel(len)
         fprintf(2, ' ROW COUNT differs (%d KPI, %d correlation) - skipped\n', height(T), numel(len)); continue;
      end
      badM = sum(string(T.method) ~= meth);
      badL = sum(double(T.encodedLen) ~= len);
      if isfield(D, 'CR')
         badC = sum(abs(double(T.CR) - double(D.CR(:))) > 1e-9);
      else
         badC = 0;
      end
      if badM + badL + badC > 0
         fprintf(2, ' NOT ROW-ALIGNED: method %d, length %d, CR %d rows differ - skipped\n', badM, badL, badC);
         continue;
      end
      Y = struct();
      Y.RES     = double(D.RES(:));
      Y.CR      = double(T.CR);
      Y.DER     = double(T.decodeErrRate);
      Y.DERgain = double(T.decErrRate_woInt) - double(T.decodeErrRate);

      keep = len > minN & ~ismember(meth, OUTS);
      [~, gmAll, glAll] = findgroups(meth(keep), len(keep));
      uKeys = unique(strcat(gmAll, "_", string(glAll)));
      for k = 1:numel(uKeys)
         key = char(uKeys(k));
         if cache.isKey(key), continue; end
         parts = split(uKeys(k), "_"); mn = char(parts(1)); N = str2double(parts(end));
         cache(key) = local_design(mn, N, tpc, tp, tfac, ENSEMBLE, nDraw, DES, n, t);
      end
      for ti = 1:numel(TGT)
         [X, y, gl] = local_cellsY(D, meth, len, keep, Y.(TGT{ti}), cache, PUBREF);
         RHO(:, si, ti) = local_fz(X, y, gl);
      end
      used(si) = true;
      fprintf(' aligned, %d rows, %5.1f s\n', numel(len), toc);
   end

   nUsed = sum(used);
   fprintf('\n  %d of %d condition files used.\n', nUsed, numel(d));
   fprintf('\n  mean |rho| over the condition files, and the number clearing %.2f\n', theta);
   fprintf('  %-18s', 'metric');
   for ti = 1:numel(TGT), fprintf('%16s', TGT{ti}); end
   fprintf('%14s\n', 'sign vs DER');
   fprintf('  %s\n', repmat('-', 1, 18 + 16*numel(TGT) + 14));
   fid = fopen(csvFile, 'w');
   fprintf(fid, 'metric');
   for ti = 1:numel(TGT), fprintf(fid, ',absrho_%s,pass_%s,n_%s', TGT{ti}, TGT{ti}, TGT{ti}); end
   fprintf(fid, ',meanSigned_DER\n');
   for c = 1:nMet
      fprintf('  %-18s', mNames{c}); fprintf(fid, '%s', mNames{c});
      for ti = 1:numel(TGT)
         v = RHO(c, used, ti);
         if all(~isfinite(v)), fprintf('%16s', 'undef'); fprintf(fid, ',,,'); continue; end
         fprintf('     %6.3f %d/%d', mean(abs(v), 'omitnan'), sum(abs(v) >= theta), sum(isfinite(v)));
         fprintf(fid, ',%.4f,%d,%d', mean(abs(v), 'omitnan'), sum(abs(v) >= theta), sum(isfinite(v)));
      end
      sv = mean(RHO(c, used, 3), 'omitnan');
      fprintf('%14.3f\n', sv); fprintf(fid, ',%.4f\n', sv);
   end
   fclose(fid);
   fprintf(['\n  RES must reproduce Table 4 (delta_G 0.924, eta_ES 0.924, giniLoad (12n) 0.898)\n' ...
            '  and CR the "target CR alone" row of Table S3 (0.908 / 0.919 / 0.893).\n' ...
            '  If either does not, stop: the DER columns are then not comparable.\n']);
   fprintf('\n  log  %s\n  csv  %s\n\n', logFile, csvFile);
   R = struct('metrics', {mNames}, 'targets', {TGT}, 'rho', RHO, 'files', {{d.name}}, 'used', used);
end

function [X, y, gl] = local_cellsY(D, meth, len, mask, yy, cache, PUBREF)
   [g, gm, gl] = findgroups(meth(mask), len(mask));
   y = splitapply(@(z) mean(z, 'omitnan'), yy(mask), g);
   keys = strcat(gm, "_", string(gl));
   nDes = numel(cache(char(keys(1))));
   X = nan(numel(gm), nDes + numel(PUBREF));
   for k = 1:numel(gm), X(k, 1:nDes) = cache(char(keys(k))); end
   for c = 1:numel(PUBREF)
      if ~isfield(D, PUBREF{c}), continue; end
      xx = double(D.(PUBREF{c})(:));
      X(:, nDes + c) = splitapply(@(z) mean(z, 'omitnan'), xx(mask), g);
   end
end

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

function local_restore_diary(prev)
   diary('off');
   if strcmp(prev{1}, 'on'), diary(prev{2}); end
end
