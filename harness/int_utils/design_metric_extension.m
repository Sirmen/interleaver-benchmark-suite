function E = design_metric_extension(dataPath, opts)
%DESIGN_METRIC_EXTENSION  Score classical metrics left out of the nineteen.
%
%   E = design_metric_extension('C:\TS_data\S-Int\results_v2', ...
%          struct('dataDir', 'C:\...\interleaverDeinterleaver\data_PrimeFactor'))
%
% WHAT THIS ADDS
% ---------------------------------------------------------------------------
% The published suite scores nineteen metrics. Five further a priori measures
% from the classical interleaver literature are not among them:
%
%   dispersion  Heegard-Wicker, restated as equation (14) of Takeshita and
%               Costello 2000. Fraction of distinct displacement vectors. This
%               is the quality measure [14] ACTUALLY uses: that paper defines
%               no spread factor, so the metric the manuscript attributes to it
%               in equation (6b) is not in it, and the metric it does use is
%               not in the suite. Validated against the source's own published
%               values (0.81 for random, 1 for a Costas array).
%   Snew        Crozier 2000. The L1 combined spread the benchmark ITSELF uses
%               to re-search DRP's stride and dither (Table III), i.e. a metric
%               the benchmark selects with but does not validate. The turbo
%               literature's "spread" is this L1 form, not the Euclidean one
%               that equation (6b) of the manuscript computes, so this row also
%               settles what the spread family actually scores.
%   S_ach       Achieved S-random spread. srandom carries the published rule
%               s = floor(sqrt(N/2)); the achieved value is defined for every
%               method.
%   B_guar      Guaranteed correctable burst length: the largest B no burst of
%               which can put more than t errors in any codeword. This is the
%               classical Ramsey-Forney depth guarantee stated for an arbitrary
%               permutation, and it is a priori and (n,t)-aware, so it lands in
%               the cell the manuscript reports as holding overT alone.
%   esLoad      The design-time counterpart of eta_ES, which is the one
%               a posteriori statistic in the suite that passes every
%               criterion and has no counterpart defined for it. Read at the
%               same burst length as the giniLoad anchor, so the two are
%               directly comparable.
%   adjDisp     The "Dispersion Factor (Gamma)" that analyzeDispersion.m
%               computes and ships in the release without appearing in any
%               table: distinct adjacent displacement magnitudes over N-1. It
%               is the lag-1 restriction of dispersion, so running both says
%               whether the all-pairs count buys anything.
%
% NO CAMPAIGN RE-RUN IS NEEDED. All three are deterministic functions of the
% permutation alone, so the objective is read from the saved KPItableDetailed
% files and the metrics are computed from the stored permutation table. The
% 1.02 million trial records are not touched.
%
% WHY THIS IS A SEPARATE FILE
% ---------------------------------------------------------------------------
% design_metric_validation.m produces numbers that are in the manuscript.
% Nothing here edits it, so nothing here can move them.
%
% THE ANCHOR ROWS DECIDE WHETHER THE NEW ROWS MAY BE READ
% ---------------------------------------------------------------------------
% The same pass re-scores giniLoad at its reported burst length and eta_sep,
% whose published within-length values are 0.898 and 0.676. Those two numbers
% are the test of this script, not of the metrics: they depend on the cell
% set, the objective column and the Fisher-z combination all being the ones
% the paper used. If they do not reproduce, the new rows are not evidence and
% the script says so instead of printing plausible-looking numbers.
%
% STATISTIC
% ---------------------------------------------------------------------------
% Identical to design_metric_validation: Spearman across methods WITHIN each
% length, combined over lengths by Fisher z with weights n-3, one value per
% condition file, then averaged over conditions. C2 pass is |rho| >= threshold
% per condition; the IQR column is the interquartile range of the per-length
% correlations, which is the C5 quantity.
%
% Writes design_metric_extension.csv next to the results for reading back.
%
% R.T. Sirmen harness, 2026-10

   if nargin < 2, opts = struct(); end
   if nargin < 1 || isempty(dataPath)
      c = configure_simulation();
      dataPath = char(c.dataSavePath);
   end
   dataPath = char(dataPath);

   dataDir   = local_opt(opts, 'dataDir', '');
   FECn      = local_opt(opts, 'FECn', 15);
   FECt      = local_opt(opts, 'FECt', 3);
   threshold = local_opt(opts, 'threshold', 0.30);
   nDraw     = local_opt(opts, 'nDraw', 15);
   % Bset exists here only to reproduce the paper's CELL SET and the giniLoad
   % anchor. The three new metrics have no burst length. Pass the same Bset the
   % published run used, or the anchors will not land.
   Bset      = local_opt(opts, 'Bset', FECn * [1 2 4 8 12 16 24]);
   Bgini     = local_opt(opts, 'Bgini', 12 * FECn);
   commonSupport = local_opt(opts, 'commonSupport', true);
   ENSEMBLE  = {'random', 'freqRandom'};
   % THE SCOPE DROP IS PART OF THE DEFINITION OF THE FIELD, NOT A FILTER.
   % metric_scorecard removes these two from every correlation before the
   % cells are formed, so the published |rho| values are computed on 23
   % methods, not 25. Scoring the full set shifts every number: it is what
   % made the first run of this script miss the giniLoad anchor by 0.006.
   dropMethods = local_opt(opts, 'dropMethods', {'freqDeterm', 'freqRandom'});
   if isfield(opts, 'dropMethods') && isempty(opts.dropMethods), dropMethods = {}; end
   if ischar(dropMethods), dropMethods = {dropMethods}; end

   if isempty(dataDir)
      error(['design_metric_extension: the permutation table directory is ' ...
             'required (opts.dataDir).']);
   end

   NEW   = {'dispersion', 'Snew', 'S_ach', 'B_guar', 'adjDispersion', 'esLoad'};
   CLS   = {'a priori, agn.', 'a priori, agn.', 'a priori, agn.', ...
            'a priori, (n,t)', 'a priori, agn.', 'a priori, n'};
   ANCH  = {sprintf('anchor: giniLoad_B%d', Bgini), 'anchor: eta_sep'};
   names = [NEW, ANCH];
   nNew  = numel(NEW); nCol = numel(names);

   fprintf('\n=================================================================\n');
   fprintf('  METRIC EXTENSION : dispersion, Snew, S_ach, B_guar, adjDispersion, esLoad\n');
   fprintf('  code (n,t) = (%d,%d);  cell set from max(B) = %d\n', ...
           FECn, FECt, max(Bset));
   fprintf('  threshold |rho| >= %.2f;  anchors must give 0.898 / 0.676\n', threshold);
   fprintf('=================================================================\n');

   [tpc, erT] = PrecomputedInterleaverLoader(dataDir);
   if erT ~= "", error('design_metric_extension: %s', erT); end
   [tp, tfac, erP] = PrimeFactorLoader(dataDir);
   if erP ~= "", error('design_metric_extension: PrimeFactorLoader: %s', erP); end

   d = dir(fullfile(dataPath, 'KPItableDetailed_*.mat'));
   if isempty(d), error('design_metric_extension: no KPItableDetailed_*.mat found'); end

   permCache = containers.Map();
   metCache  = containers.Map();      % method_N -> [dispersion Snew S_ach gini]

   labels = {}; RW = []; IQ = []; NL = [];

   for i = 1:numel(d)
      f   = fullfile(d(i).folder, d(i).name);
      lbl = local_label(d(i).name);
      fprintf('  %-16s ', lbl);

      T = local_table(f);
      if ~all(ismember({'method', 'encodedLen', 'RES'}, T.Properties.VariableNames))
         fprintf(2, 'skipped (missing method/encodedLen/RES)\n'); continue;
      end
      meth = string(T.method);
      len  = double(T.encodedLen);
      res  = double(T.RES);
      methAll = meth;        % taken BEFORE the drop: the name-map fallback needs it

      % Scope drop before the cells are formed, as metric_scorecard does it.
      % Dropping afterwards would leave holes in the cell matrix and change the
      % support rather than the field.
      if ~isempty(dropMethods)
         keepRow = ~ismember(meth, string(dropMethods));
         meth = meth(keepRow); len = len(keepRow); res = res(keepRow);
      end

      [g, gm, gl] = findgroups(meth, len);
      resBar = splitapply(@mean, res, g);

      if commonSupport
         keepC = gl > max(Bset);
         nDrop = sum(~keepC);
         gm = gm(keepC); gl = gl(keepC); resBar = resBar(keepC);
         if nDrop > 0
            fprintf('(N > %d: %d cells dropped) ', max(Bset), nDrop);
         end
      end

      % eta_sep anchor, re-aggregated onto these same cells. The published
      % metrics are NOT columns of KPItableDetailed - they live in the
      % correlation_data_*.mat beside it, keyed by a numeric methodID.
      sepBar = local_pubMetric(f, 'eta_sep', gm, gl, methAll);

      X = nan(numel(gm), nCol);
      X(:, nCol) = sepBar;                       % last column is the eta_sep anchor

      for k = 1:numel(gm)
         mname = char(gm(k));
         key = sprintf('%s_%d', mname, gl(k));
         if isKey(metCache, key)
            X(k, 1:nNew+1) = metCache(key);
            continue;
         end
         if ismember(mname, ENSEMBLE)
            acc = zeros(1, nNew+1); got = 0;
            for dr = 1:nDraw
               [~, p] = interleaver_generic_pc(1:gl(k), mname, 0, 0, [], ...
                                               1000 + dr, tp, tfac, struct());
               if isempty(p), continue; end
               acc = acc + local_one(p, Bgini, FECn, FECt);
               got = got + 1;
            end
            if got > 0, v = acc / got; else, v = nan(1, nNew+1); end
         else
            p = local_perm(tpc, permCache, mname, gl(k));
            if isempty(p), v = nan(1, nNew+1); else, v = local_one(p, Bgini, FECn, FECt); end
         end
         metCache(key) = v;
         X(k, 1:nNew+1) = v;
      end

      rw = nan(1, nCol); iq = nan(1, nCol); nl = nan(1, nCol);
      for c = 1:nCol
         [rw(c), perLen] = local_withinLength(X(:, c), resBar, gl);
         if numel(perLen) >= 2, iq(c) = iqr(perLen); end
         nl(c) = numel(perLen);
      end

      labels{end+1} = lbl;  %#ok<AGROW>
      RW = [RW; rw];  IQ = [IQ; iq];  NL = [NL; nl];  %#ok<AGROW>
      fprintf('ok (%d cells, %d lengths)\n', numel(gm), nl(1));
   end

   if isempty(RW), error('design_metric_extension: no condition produced a result'); end

   mRW  = mean(abs(RW), 1, 'omitnan');
   mIQ  = mean(IQ, 1, 'omitnan');
   pass = sum(abs(RW) >= threshold, 1);
   nCond = size(RW, 1);

   fprintf('\n  %-26s %8s %7s %8s   %s\n', 'metric', '|rho|', 'pass', 'IQR', 'class');
   fprintf('  %s\n', repmat('-', 1, 72));
   for c = 1:nNew
      fprintf('  %-26s %8.3f %4d/%-2d %8.3f   %s\n', ...
              names{c}, mRW(c), pass(c), nCond, mIQ(c), CLS{c});
   end
   fprintf('  %s\n', repmat('-', 1, 72));
   for c = nNew+1:nCol
      fprintf('  %-26s %8.3f %4d/%-2d %8.3f\n', names{c}, mRW(c), pass(c), nCond, mIQ(c));
   end

   okG = abs(mRW(nNew+1) - 0.898) <= 0.004;
   okS = abs(mRW(nNew+2) - 0.676) <= 0.004;
   fprintf('\n  ANCHOR CHECK\n');
   fprintf('    giniLoad  %.3f  expected 0.898   %s\n', mRW(nNew+1), local_v(okG));
   fprintf('    eta_sep   %.3f  expected 0.676   %s\n', mRW(nNew+2), local_v(okS));
   if okG && okS
      fprintf(['    Both anchors reproduce. The three rows above are measured on\n' ...
               '    the same cells, against the same objective, by the same statistic.\n']);
   else
      fprintf(2, ['    ANCHORS DO NOT REPRODUCE. Do not read the new rows. Check that\n' ...
                  '    Bset matches the published run and that dataPath is results_v2.\n']);
   end

   % C4 - REGIME ROBUSTNESS, printed rather than inferred.
   %
   % C4 asks whether the metric keeps its SIGN in every burst regime. The pass
   % count cannot answer that: pass is computed on |rho|, so a metric that
   % reverses sign between regimes still clears the threshold in each of them
   % and reads 8/8. RW already holds the signed per-condition values, so the
   % test costs nothing - it was simply never reported, which left the C4
   % column of Table X unfillable from this script's output.
   okC4 = false(1, nCol);
   for c = 1:nCol
      v = RW(~isnan(RW(:, c)), c);
      okC4(c) = isempty(v) || all(sign(v) == sign(v(1)));
   end
   fprintf('\n  C4  REGIME ROBUSTNESS - sign constant over all %d conditions\n', nCond);
   fprintf('  %s\n', repmat('-', 1, 72));
   for c = 1:nCol
      fprintf('  %-26s %-5s  signed rho:', names{c}, local_v(okC4(c)));
      fprintf(' %+.3f', RW(:, c));
      fprintf('\n');
   end

   E = struct('names', {names}, 'labels', {labels}, 'rho_within', RW, ...
              'iqr', IQ, 'nLengths', NL, 'mean_abs_rho', mRW, 'mean_iqr', mIQ, ...
              'pass', pass, 'nCond', nCond, 'threshold', threshold, ...
              'Bset', Bset, 'Bgini', Bgini, 'anchorsOk', okG && okS, 'okC4', okC4);

   try
      out = fullfile(dataPath, 'design_metric_extension.csv');
      Tout = table(names(:), mRW(:), pass(:), repmat(nCond, nCol, 1), mIQ(:), ...
                   'VariableNames', {'metric', 'abs_rho_within', 'pass', 'nCond', 'IQR'});
      writetable(Tout, out);
      fprintf('\n  wrote %s\n', out);
   catch err
      fprintf(2, '\n  could not write CSV: %s\n', err.message);
   end

   try
      out2 = fullfile(dataPath, 'design_metric_extension_bycond.csv');
      fid = fopen(out2, 'w');
      if fid < 0, error('cannot open %s', out2); end
      fprintf(fid, 'condition');
      for c = 1:nCol, fprintf(fid, ',%s', names{c}); end
      fprintf(fid, '\n');
      for r = 1:nCond
         fprintf(fid, '%s', labels{r});
         fprintf(fid, ',%.15g', RW(r, :));
         fprintf(fid, '\n');
      end
      fclose(fid);
      fprintf('  wrote %s\n', out2);
   catch err
      fprintf(2, '  could not write per-condition CSV: %s\n', err.message);
   end
end

%% ------------------------------------------------------------------------
function v = local_one(p, Bgini, n, t)
% The five new metrics plus the giniLoad anchor, one permutation. The order
% must match NEW in the caller, with the anchor last.
   [~, ~, ~, ~, gi] = designMetricScore(p, Bgini, n, t);
   v = [calc_dispersion_invperm(p), ...
        calc_snew_invperm(p), ...
        calc_srandom_spread_invperm(p), ...
        calc_bguar_invperm(p, n, t), ...
        calc_adjdispersion_invperm(p), ...
        calc_esload_invperm(p, Bgini, n), ...
        gi];
end

function [r, rr] = local_withinLength(x, y, lens)
% Copied from design_metric_validation so the statistic cannot drift, with the
% per-length vector returned as well because the IQR column needs it.
   r = NaN; rr = [];
   uL = unique(lens);
   zs = []; ws = [];
   for i = 1:numel(uL)
      sel = (lens == uL(i)) & isfinite(x) & isfinite(y);
      n = sum(sel);
      if n < 5 || numel(unique(x(sel))) < 2, continue; end
      v = corr(x(sel), y(sel), 'type', 'Spearman');
      if ~isfinite(v), continue; end
      rr(end+1) = v;  %#ok<AGROW>
      v = max(min(v, 0.999999), -0.999999);
      zs(end+1) = atanh(v);  %#ok<AGROW>
      ws(end+1) = n - 3;     %#ok<AGROW>
   end
   if isempty(zs), return; end
   r = tanh(sum(zs .* ws) / sum(ws));
end

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
   cache(key) = p;
end

function v = local_pubMetric(kpiFile, name, gm, gl, methAll)
% One published metric, cell-averaged onto the SAME (method, length) cells.
% Mirrors metric_scorecard's decoding exactly, including the untrusted-name-map
% guard: older correlation_data files carry only a numeric methodID, and a
% count check proves nothing about the ORDER, so a file whose method set
% differs from the one that wrote the codes decodes to the wrong names with no
% symptom. If the mapping cannot be trusted the metric is returned as NaN
% rather than silently wrong.
   v = nan(numel(gm), 1);
   cf = strrep(kpiFile, 'KPItableDetailed_', 'correlation_data_');
   if exist(cf, 'file') ~= 2, return; end
   L = load(cf); fn = fieldnames(L); D = [];
   for i = 1:numel(fn)
      if isstruct(L.(fn{i})), D = L.(fn{i}); break; end
   end
   if isempty(D) || ~isfield(D, 'methodID') || ~isfield(D, 'encodedLen'), return; end
   if ~isfield(D, name), return; end

   if isfield(D, 'methodNames')
      nameList = cellstr(D.methodNames(:)); trusted = true;
   else
      nameList = sort(unique(cellstr(methAll))); trusted = false;
   end
   mid = double(D.methodID(:)); dlen = double(D.encodedLen(:));
   if numel(mid) ~= numel(dlen) || max(mid) > numel(nameList) || min(mid) < 1, return; end
   if trusted
      if ~isequal(sort(unique(mid))', 1:numel(nameList)), return; end
   else
      if numel(unique(mid)) ~= numel(nameList), return; end
      fprintf(2, ['\n    NOTE: %s carries no methodNames; the methodID mapping is\n' ...
                  '    inferred from sort order and is not verified. Run\n' ...
                  '    fix_correlation_data to record the names in the file.\n'], cf);
   end

   x = double(D.(name)(:));
   if numel(x) ~= numel(mid), return; end
   nm = string(nameList(mid));
   [g2, m2, l2] = findgroups(nm, dlen);
   cm = splitapply(@(z) mean(z, 'omitnan'), x, g2);
   key  = strcat(string(gm),  '_', string(gl));
   key2 = strcat(string(m2),  '_', string(l2));
   [tf2, loc] = ismember(key2, key);
   v(loc(tf2)) = cm(tf2);
end

function T = local_table(f)
   S = load(f); fn = fieldnames(S); T = [];
   for i = 1:numel(fn)
      if istable(S.(fn{i})), T = S.(fn{i}); return; end
   end
   error('design_metric_extension: no table in %s', f);
end

function lbl = local_label(name)
   REG = 'single|multi|ge\d+p\d+';
   GRD = 'common|standards|probe|legacy';
   t = regexp(name, sprintf('_(%s)_(%s)_', REG, GRD), 'tokens', 'once');
   if ~isempty(t), lbl = sprintf('%s/%s', t{1}, t{2}(1)); return; end
   t = regexp(name, sprintf('_(%s)_', REG), 'tokens', 'once');
   if ~isempty(t), lbl = sprintf('%s/?', t{1}); else, lbl = name; end
end

function s = local_v(ok)
   if ok, s = 'OK'; else, s = 'MISMATCH'; end
end

function v = local_opt(s, f, dflt)
   if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = dflt; end
end
