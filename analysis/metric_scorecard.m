function S = metric_scorecard(dataPath, opts)
%METRIC_SCORECARD  Every metric, one unit of analysis, with uncertainty.
%
%   S = metric_scorecard([], struct('dataDir', dataDir))
%
% WHY THIS REPLACES THE TWO SEPARATE VALIDATION TABLES
% ---------------------------------------------------------------------------
% metric_validation scores the published metrics per TRIAL. design_metric_
% validation scores the design-time metrics per (method, length) CELL, because
% they have no per-trial value to give. Putting both in one ordered table -
% which the manuscript did - compares numbers computed at different units of
% analysis, and cell averaging removes within-cell noise, so the cell rows are
% inflated relative to the trial rows by the aggregation alone.
%
% A footnote saying so is not enough: the prose then ranked them against each
% other anyway. The fix is not a warning but a common unit. Here every metric,
% published or new, is reduced to (method, length) cell means and correlated
% with cell-mean RES within length. One table, one unit, directly rankable.
%
% WHAT ELSE IS ADDED, AND WHY
% ---------------------------------------------------------------------------
% * BLOCK BOOTSTRAP over lengths. A point estimate of 0.903 against 0.926 does
%   not by itself support a claim of parity: the two correlations share methods,
%   lengths and the same RES values, so they are strongly dependent. Resampling
%   lengths with replacement gives an interval for each rho and, more to the
%   point, for the RATIO and DIFFERENCE against the reference metric, which is
%   what the parity claim is actually about.
%
% * HELD-OUT SELECTION. The burst length B and the three new load statistics
%   were chosen after looking at this campaign. Selecting B on one grid and
%   reporting it on the other converts an internal optimum into an out-of-sample
%   number. The two grids differ in methods and lengths, so this is not a clean
%   split, but it is a real one and it is available at no cost.
%
% OPTIONS
%   dataDir      REQUIRED, the permutation table directory
%   FECn, FECt   code parameters, default 15 and 3
%   Bset         burst lengths, default n*[1 2 4 8 12 16 24]
%   nBoot        bootstrap resamples, default 5000 (cheap: a reweighting)
%   refMetric    metric the ratio is taken against, default 'delta_G'
%   threshold    retention threshold, default 0.30
%
% R.T. Sirmen harness, 2026-08

   if nargin < 2, opts = struct(); end
   if nargin < 1 || isempty(dataPath)
      c = configure_simulation(); dataPath = char(c.dataSavePath);
   end
   dataPath = char(dataPath);

   dataDir   = local_opt(opts, 'dataDir', '');
   FECn      = local_opt(opts, 'FECn', 15);
   FECt      = local_opt(opts, 'FECt', 3);
   Bset      = local_opt(opts, 'Bset', FECn * [1 2 4 8 12 16 24]);
   nBoot     = local_opt(opts, 'nBoot', 5000);   % cheap now: a reweighting, not a refit
   refMetric = local_opt(opts, 'refMetric', 'delta_G');
   threshold = local_opt(opts, 'threshold', 0.30);
   nDraw     = local_opt(opts, 'nDraw', 15);
   ENSEMBLE  = {'random', 'freqRandom'};
   PUB = {'delta_G','eta_ES','S_ECC','eta_sep','delta_BS','PSR','U_ECC', ...
          'V_ECC','adjMin','sepMin','adjCV','laplacianEnergy','S_sf','S_factor'};
   STATS = {'overT','maxErrCW','meanMaxCW','cvLoad','giniLoad'};

   % TWO DIFFERENT FOLDERS, and they are easy to swap by accident.
   %   dataPath (arg 1) holds the sweep output, KPItableDetailed_*.mat etc.
   %   dataDir  (opts)  holds the precomputed permutation and factor tables.
   % opts.tableDir is accepted as the clearer name for the second.
   tableDir = local_opt(opts, 'tableDir', dataDir);
   % Neither given, or given wrong: look for the table instead of failing on
   % a folder the caller only thought held it. Passing the results folder for
   % both is the easiest mistake in this harness, and it fails with a message
   % that reads as a missing file rather than as a wrong folder.
   if isempty(tableDir) || exist(fullfile(char(tableDir), 'table_factors_precomputed.mat'), 'file') ~= 2
      if ~isempty(tableDir)
         fprintf(2, 'metric_scorecard: no precomputed table in %s - searching\n', char(tableDir));
      end
      [found, erF] = find_table_dir(dataPath);
      if erF ~= ""
         error('metric_scorecard: %s', erF);
      end
      tableDir = found;
   end

   [tpc, erT] = PrecomputedInterleaverLoader(tableDir);
   if erT ~= "", error('metric_scorecard: %s', erT); end
   [tp, tfac, erP] = PrimeFactorLoader(tableDir);
   if erP ~= "", error('metric_scorecard: %s', erP); end

   d = dir(fullfile(dataPath, 'KPItableDetailed_*.mat'));
   if isempty(d), error('metric_scorecard: no KPItableDetailed_*.mat found'); end

   % ---- restrict to one length grid, when asked ---------------------------
   % The block bootstrap resamples whole lengths, so a sweep contributes as
   % many blocks as it has distinct lengths: 44 on the common grid and 5 on
   % the standards grid at this support. Pooling them gives the standards
   % sweeps a vote in an interval whose width they cannot resolve. Running
   % the common grid alone is the check on whether that matters, and if the
   % headline ratio survives it, the coarse-interval caveat is confined to
   % the standards results rather than attached to the study's main claim.
   % ---- methods excluded from the correlation, by declared scope ----------
   % A metric is validated by how well it orders METHODS, so which methods are
   % in the field decides what the number means. Two of them - the frequency
   % interleavers - are structurally confined to about 3 % of the frame
   % (check_permutation_reach) and therefore cannot spread a time-domain
   % burst at all. Every spreading metric ranks them last correctly and for
   % free, which inflates every correlation in the table. Dropping them is the
   % conservative direction and the effect is measured rather than assumed.
   % THE DEFAULT FIELD IS THE IN-SCOPE ONE, because that is the field the
   % manuscript reports. It was {} - the full twenty-three - and running the
   % documented command therefore reproduced numbers that do NOT appear in
   % any table, silently: 1012 cells against the paper's 924, and coefficients
   % moving by up to 0.2 with nothing on screen to say why. metric_crosscorr
   % already dropped these two by default, so the two scripts disagreed about
   % what "the field" meant. Pass dropMethods {} for the full field, which is
   % the ablation Section VIII-G reports.
   dropMethods = local_opt(opts, 'dropMethods', {'freqDeterm', 'freqRandom'});
   if isfield(opts, 'dropMethods') && isempty(opts.dropMethods), dropMethods = {}; end
   if ischar(dropMethods), dropMethods = {dropMethods}; end
   if ~isempty(dropMethods)
      fprintf('  FIELD: in scope, %s excluded from every correlation\n', strjoin(dropMethods, ', '));
   else
      fprintf(2, '  FIELD: FULL, every method included. These are the ablation\n');
      fprintf(2, '  numbers of Section VIII-G, not the numbers in the tables.\n');
   end

   gridFilter = local_opt(opts, 'gridFilter', '');
   if ~isempty(gridFilter)
      keep = ~cellfun(@isempty, regexp({d.name}, ['_' gridFilter '_'], 'once'));
      if ~any(keep)
         error('metric_scorecard: gridFilter "%s" matches no file', gridFilter);
      end
      fprintf('  gridFilter "%s": %d of %d condition file(s) retained\n', ...
              gridFilter, sum(keep), numel(d));
      d = d(keep);
   end

   names = PUB;
   for k = 1:numel(STATS)
      for b = 1:numel(Bset)
         names{end+1} = sprintf('%s_B%d', STATS{k}, Bset(b)); %#ok<AGROW>
      end
   end
   nM = numel(names);

   fprintf('\n=================================================================\n');
   fprintf('  METRIC SCORECARD  -  all %d metrics at (method, length) cell level\n', nM);
   fprintf('  code (n,t) = (%d,%d);  B = %s;  bootstrap = %d\n', ...
           FECn, FECt, mat2str(Bset), nBoot);
   fprintf('  common support: N > %d, so every B is scored on identical cells\n', max(Bset));
   fprintf('=================================================================\n');

   labels = {}; grids = {}; RHO = []; RT = []; BW = []; IQ = []; MD = []; CI = []; BOOT = {};
   % The per-length correlations themselves, not only their median and IQR.
   % C5 is a statement about a distribution, and a figure of that distribution
   % cannot be drawn from two summary numbers: a box built from a median and
   % an IQR assumes a symmetry the data need not have.
   PL = {}; LN = {};

   for si = 1:numel(d)
      f = fullfile(d(si).folder, d(si).name);
      [lbl, grd] = local_label(d(si).name);
      fprintf('  %-18s ', lbl);

      [X, resBar, gm, gl] = local_cellMatrix(f, names, PUB, STATS, Bset, ...
                                FECn, FECt, tpc, tp, tfac, ENSEMBLE, nDraw, max(Bset), dropMethods);
      if isempty(X), fprintf('skipped\n'); continue; end

      % TRIAL-LEVEL within length, for the published metrics only. This exists
      % to separate two changes that were made at once. The earlier validation
      % table was per TRIAL and POOLED over lengths; this table is per CELL and
      % WITHIN length. Comparing the two attributes the difference to nothing in
      % particular. With the trial-level within-length value in hand,
      %
      %    pooled -> within-length     is the length-conditioning effect
      %    within-length trial -> cell is the aggregation effect
      %
      % and each can be reported for what it is. Cell means average over the
      % noise bins and runs of a cell, so the aggregation effect includes the
      % removal of that scatter - which is the point.
      rhoTrial = local_trialWithinLength(f, PUB, max(Bset));

      % Per-length Fisher z, computed ONCE. The block bootstrap resamples whole
      % lengths, and a length's own correlation does not change when other
      % lengths are drawn - only which z values enter the average does. So the
      % bootstrap is a reweighting of these z values, not a recomputation.
      %
      % Recomputing was the first implementation and it was unusable: 49 metrics
      % x 2000 draws x ~44 lengths is over four million corr() calls per sweep,
      % hours for what takes seconds. It was also no more correct - the block
      % bootstrap over lengths is exactly this reweighting.
      uL = unique(gl);
      nL = numel(uL);
      Z = nan(nM, nL); W = zeros(nM, nL);
      % NOT `i`: that is the sweep loop's variable. MATLAB reassigns a for
      % variable each pass so this would still run, but shadowing the outer
      % index inside a nested loop is how a reader - or a port to any other
      % language - gets it wrong.
      for li = 1:nL
         at = (gl == uL(li));
         yy = resBar(at);
         for c = 1:nM
            xx = X(at, c);
            ok = isfinite(xx) & isfinite(yy);
            if sum(ok) < 5 || numel(unique(xx(ok))) < 2, continue; end
            rr = corr(xx(ok), yy(ok), 'type', 'Spearman');
            if ~isfinite(rr), continue; end
            rr = max(min(rr, 0.999999), -0.999999);
            Z(c, li) = atanh(rr);
            W(c, li) = sum(ok) - 3;
         end
      end
      % BETWEEN-LENGTH component, and the spread of the per-length correlations.
      %
      % A within-length correlation that is much larger than the pooled one is
      % either a real effect that pooling destroyed, or an artifact. The two are
      % distinguishable: pooling mixes the within-length relation with the
      % BETWEEN-length one, so if a metric trends with N in a direction unrelated
      % to how RES trends with N, the pooled number is dominated by that trend
      % and the within-length signal is masked. Reporting the between-length
      % correlation shows directly whether that is what happened.
      %
      % The interquartile range of the per-length correlations is the second
      % check: a Fisher-z average of 0.40 assembled from lengths scattered
      % between -0.3 and +0.9 is not the same claim as one assembled from
      % lengths all near 0.40, and only the second deserves to be quoted.
      lmMet = nan(nL, nM); lmRes = nan(nL, 1);
      for li = 1:nL
         at = (gl == uL(li));
         lmRes(li) = mean(resBar(at), 'omitnan');
         lmMet(li, :) = mean(X(at, :), 1, 'omitnan');
      end
      bt = nan(nM, 1);
      for c = 1:nM
         ok = isfinite(lmMet(:, c)) & isfinite(lmRes);
         if sum(ok) >= 5 && numel(unique(lmMet(ok, c))) > 1
            bt(c) = corr(lmMet(ok, c), lmRes(ok), 'type', 'Spearman');
         end
      end
      perLen = tanh(Z);
      iqrL = nan(nM, 1); medL = nan(nM, 1);
      for c = 1:nM
         v = perLen(c, isfinite(perLen(c, :)));
         if numel(v) >= 4, iqrL(c) = iqr(v); medL(c) = median(v); end
      end

      Zf = Z; Zf(~isfinite(Zf)) = 0;               % NaN lengths carry no weight
      Wf = W; Wf(~isfinite(Z))  = 0;
      rho = tanh(sum(Zf .* Wf, 2) ./ max(sum(Wf, 2), eps));

      % SEEDED. The bootstrap drew from whatever state the global stream was
      % in, so two runs on identical data gave ratio intervals differing in
      % the third decimal - 1.067 on one run, 1.068 in the manuscript - and
      % no table in a reproducibility paper can carry a number its own code
      % does not return. The seed is fixed per sweep and the caller's stream
      % is restored afterwards, so nothing downstream inherits it.
      rs_ = rng; rng(20260926 + numel(labels), 'twister');
      pick = randi(nL, nL, nBoot);                 % one index set for ALL metrics,
      rng(rs_);
      Bt = nan(nM, nBoot);                         % so the dependence is preserved
      for r = 1:nBoot
         q = pick(:, r);
         Bt(:, r) = tanh(sum(Zf(:, q) .* Wf(:, q), 2) ./ max(sum(Wf(:, q), 2), eps));
      end

      labels{end+1} = lbl;  grids{end+1} = grd;   %#ok<AGROW>
      RHO(:, end+1) = rho;                        %#ok<AGROW>
      RT(:, end+1)  = rhoTrial;                   %#ok<AGROW>
      BW(:, end+1)  = bt;                          %#ok<AGROW>
      IQ(:, end+1)  = iqrL;                        %#ok<AGROW>
      MD(:, end+1)  = medL;                        %#ok<AGROW>
      BOOT{end+1} = Bt;                           %#ok<AGROW>
      PL{end+1} = perLen;   LN{end+1} = uL(:).';         %#ok<AGROW>
      % Report the method count, not only the cell count. A dropMethods
      % option that silently does nothing is invisible in "1012 cells";
      % it is obvious in "23 methods" when 21 were requested.
      nMeth = numel(unique(gm));
      fprintf('%d cells, %d lengths, %d methods', numel(gm), nL, nMeth);
      if ~isempty(dropMethods) && any(ismember(string(dropMethods), unique(gm)))
         fprintf(2, '   <-- DROP DID NOT TAKE EFFECT: %s still present', ...
                 strjoin(intersect(cellstr(dropMethods), cellstr(unique(gm))), ', '));
      end
      if nL < 8
         fprintf(2, '   <-- only %d length blocks: the bootstrap CI for this sweep is coarse', nL);
      end
      fprintf('\n');
   end

   nS = numel(labels);
   mAbs = mean(abs(RHO), 2, 'omitnan');
   pass = sum(abs(RHO) >= threshold, 2);

   %% ---- main table -------------------------------------------------------
   ri = find(strcmp(names, refMetric), 1);
   [~, ord] = sort(mAbs, 'descend');

   mTri = mean(abs(RT), 2, 'omitnan');
   mBw  = mean(BW, 2, 'omitnan');
   mIq  = mean(IQ, 2, 'omitnan');
   mMd  = mean(MD, 2, 'omitnan');
   fprintf('\n  %-20s %8s %8s %8s %8s %8s %14s %5s %s\n', 'METRIC', 'cell', 'trial', ...
           'between', 'med/len', 'IQR/len', '95% CI (cell)', 'pass', 'ratio to ref [CI]');
   fprintf('  %s\n', repmat('-', 1, 96));
   ratios = nan(nM, 3);
   for kk = 1:nM
      c = ord(kk);
      allB = cell2mat(cellfun(@(z) z(c, :), BOOT, 'UniformOutput', false));
      lo = prctile(abs(allB), 2.5); hi = prctile(abs(allB), 97.5);
      % ratio |rho_c| / |rho_ref|, resampled jointly so the dependence is kept
      rr = [];
      for j = 1:nS
         rr = [rr, abs(BOOT{j}(c, :)) ./ max(abs(BOOT{j}(ri, :)), eps)]; %#ok<AGROW>
      end
      ratios(c, :) = [mAbs(c) / mAbs(ri), prctile(rr, 2.5), prctile(rr, 97.5)];
      if c <= numel(PUB) && isfinite(mTri(c))
         tstr = sprintf('%8.3f', mTri(c));
      else
         tstr = sprintf('%8s', '-');      % design metrics have no per-trial value
      end
      fprintf('  %-20s %8.3f %s %8.3f %8.3f %8.3f [%.3f, %.3f] %3d/%d %.3f [%.3f, %.3f]\n', ...
              names{c}, mAbs(c), tstr, mBw(c), mMd(c), mIq(c), lo, hi, ...
              pass(c), nS, ratios(c,1), ratios(c,2), ratios(c,3));
   end
   fprintf('  %s\n', repmat('-', 1, 96));
   fprintf(['\n  "between" is the Spearman correlation of the LENGTH MEANS - the metric\n' ...
            '  averaged over methods at each N against RES averaged the same way. It\n' ...
            '  isolates the trend with N that a pooled correlation mixes into the\n' ...
            '  within-length signal. A metric whose within-length value far exceeds\n' ...
            '  its pooled one, and whose "between" has a different sign or magnitude,\n' ...
            '  was masked by that trend rather than lifted by the aggregation.\n\n' ...
            '  "med/len" and "IQR/len" summarise the per-length correlations directly.\n' ...
            '  A Fisher-z average is only worth quoting when the lengths agree: a wide\n' ...
            '  IQR means the average is a summary of disagreement, not of a stable\n' ...
            '  effect, and should be reported as such.\n\n' ...
            '  "trial|rho|" is the SAME within-length correlation computed on the raw\n' ...
            '  per-trial records instead of cell means; "aggregation" is the difference.\n' ...
            '  It exists because the earlier table changed two things at once - per\n' ...
            '  trial to per cell, AND pooled to within length - so the shift in the\n' ...
            '  conclusions could not be attributed. With this column the two effects\n' ...
            '  are separable, and a metric whose value moves mostly here is one whose\n' ...
            '  per-trial correlation was suppressed by realization scatter rather than\n' ...
            '  by any lack of signal.\n\n' ...
            '  All rows are (method, length) cell correlations within length, so they\n' ...
            '  ARE directly comparable. CI is a block bootstrap with the length as the\n' ...
            '  resampling unit, pooled over sweeps. The ratio column is |rho| divided\n' ...
            '  by |rho| of %s, resampled jointly so the dependence between the two is\n' ...
            '  preserved - a ratio interval containing 1 means parity is not excluded.\n'], refMetric);

   %% ---- held-out selection ------------------------------------------------
   fprintf('\n  === HELD-OUT: B chosen on one grid, reported on the other ===\n');
   isC = strcmp(grids, 'common');
   if any(isC) && any(~isC)
      for k = 1:numel(STATS)
         idxB = find(startsWith(names, [STATS{k} '_B']));
         mc = mean(abs(RHO(idxB, isC)), 2, 'omitnan');
         [~, best] = max(mc);
         cB = idxB(best);
         ms = mean(abs(RHO(cB, ~isC)), 2, 'omitnan');
         fprintf('  %-12s selected %-14s on common (%.3f)  ->  standards %.3f\n', ...
                 STATS{k}, names{cB}, mc(best), ms);
      end
      fprintf(['  The selected B is the argmax on the common grid only; the number to\n' ...
               '  the right was not used to choose it. The two grids differ in method\n' ...
               '  set and length set, so this is a held-out evaluation and not a clean\n' ...
               '  split - state it that way.\n']);
   else
      fprintf('  (needs both grids present)\n');
   end

   S = struct('metrics', {names}, 'sweeps', {labels}, 'grids', {grids}, ...
              'rho', RHO, 'rhoTrial', RT, 'meanAbsTrial', mTri, ...
              'between', BW, 'iqrPerLength', IQ, 'medPerLength', MD, ...
              'meanAbs', mAbs, 'pass', pass, 'ratio', ratios, ...
              'boot', {BOOT}, 'perLength', {PL}, 'lengths', {LN}, ...
              'threshold', threshold, 'Bset', Bset, ...
              'refMetric', refMetric);
   fprintf('\n');
end

%% ------------------------------------------------------------------------
function [X, resBar, gm, gl] = local_cellMatrix(kpiFile, names, PUB, STATS, ...
                                    Bset, n, t, tpc, tp, tfac, ENSEMBLE, nDraw, minN, dropMethods)
% One row per (method, length): cell-mean of every published metric, and the
% design statistics of that method's permutation. Same rows, same unit.
   X = []; resBar = []; gm = []; gl = [];
   T = local_table(kpiFile);
   V = T.Properties.VariableNames;
   if ~all(ismember({'method','encodedLen','RES'}, V)), return; end
   meth = string(T.method); len = double(T.encodedLen); res = double(T.RES);

   % The fallback methodID mapping below is sort(unique(names)) over the FULL
   % method set that wrote correlation_data. It must be taken before any drop,
   % or excluding a method silently shifts every published metric onto the
   % wrong name. (With methodNames present this branch is not used, but a
   % latent decoder that is only correct by accident is not acceptable.)
   methAll = meth;

   % Excluded methods leave before the cells are formed, so they contribute
   % neither a row nor a rank. Dropping them afterwards would leave holes in
   % the cell matrix and change the support instead of the field.
   %
   % NOTE the argument index. dropMethods is the 14th parameter, and this
   % guard read "nargin >= 15" - one too many - so the drop never executed and
   % the run printed the banner while scoring the full method set. The cell
   % count is what exposed it: 1012 cells / 44 lengths = 23 methods, exactly
   % the number that should have become 21.
   if nargin < 14, dropMethods = {}; end
   if ~isempty(dropMethods)
      keepRow = ~ismember(meth, string(dropMethods));
      meth = meth(keepRow); len = len(keepRow); res = res(keepRow);
      T = T(keepRow, :);
   end

   [g, gm, gl] = findgroups(meth, len);
   resBar = splitapply(@mean, res, g);
   keep = gl > minN;
   gm = gm(keep); gl = gl(keep); resBar = resBar(keep);

   nM = numel(names); nP = numel(PUB);
   X = nan(numel(gm), nM);

   % --- published metrics, averaged to the same cells ---------------------
   cf = strrep(kpiFile, 'KPItableDetailed_', 'correlation_data_');
   if exist(cf, 'file')
      L = load(cf); fn = fieldnames(L); D = [];
      for i = 1:numel(fn), if isstruct(L.(fn{i})), D = L.(fn{i}); break; end, end
      if ~isempty(D) && isfield(D, 'methodID') && isfield(D, 'encodedLen')
         % methodID is an index into a name list the file did not used to
         % carry, so the mapping had to be reconstructed as sort(unique(...))
         % of the names seen elsewhere, guarded only by a COUNT check. A count
         % agreeing proves nothing about the order: any file whose method set
         % differs from the one that built the codes decodes to the wrong
         % names with no symptom, and only the 14 published metrics are
         % affected, since the design metrics come straight from permutations.
         % fix_correlation_data writes methodNames into the file. Use it when
         % it is there, and say so when it is not.
         if isfield(D, 'methodNames')
            nameList = cellstr(D.methodNames(:));
            trusted  = true;
         else
            nameList = sort(unique(cellstr(methAll)));
            trusted  = false;
         end
         mid = double(D.methodID(:)); dlen = double(D.encodedLen(:));
         okMap = numel(mid) == numel(dlen) && max(mid) <= numel(nameList) && min(mid) >= 1;
         if trusted
            okMap = okMap && isequal(sort(unique(mid))', 1:numel(nameList));
         else
            okMap = okMap && numel(unique(mid)) == numel(nameList);
            if okMap
               warning(['metric_scorecard: %s carries no methodNames, so the ' ...
                        'methodID-to-name mapping is inferred from sort order and ' ...
                        'is NOT verified. Run fix_correlation_data to record the ' ...
                        'names in the file.'], cf);
            end
         end
         if okMap
            nm = string(nameList(mid));
            [g2, m2, l2] = findgroups(nm, dlen);
            key  = strcat(string(gm), '_', string(gl));
            key2 = strcat(string(m2), '_', string(l2));
            [tf2, loc] = ismember(key2, key);
            for c = 1:nP
               if ~isfield(D, PUB{c}), continue; end
               v = double(D.(PUB{c})(:));
               if numel(v) ~= numel(mid), continue; end
               cm = splitapply(@(z) mean(z, 'omitnan'), v, g2);
               X(loc(tf2), c) = cm(tf2);
            end
         end
      end
   end

   % --- design metrics from the permutation --------------------------------
   nB = numel(Bset);
   for k = 1:numel(gm)
      mn = char(gm(k));
      if ismember(mn, ENSEMBLE)
         acc = zeros(1, numel(STATS)*nB); got = 0;
         for dr = 1:nDraw
            [~, p] = interleaver_generic_pc(1:gl(k), mn, 0, 0, [], 1000+dr, tp, tfac, struct());
            if isempty(p), continue; end
            acc = acc + local_allStats(p, Bset, n, t, numel(STATS));
            got = got + 1;
         end
         if got > 0, X(k, nP+1:end) = acc / got; end
      else
         p = local_perm(tpc, mn, gl(k));
         if isempty(p), continue; end
         X(k, nP+1:end) = local_allStats(p, Bset, n, t, numel(STATS));
      end
   end
end

function rt = local_trialWithinLength(kpiFile, PUB, minN)
% Within-length Spearman on the RAW per-trial records, for the published
% metrics. Same conditioning as the cell version (group by length), same
% Fisher-z combination - the only difference is that no cell averaging has
% been applied, which is exactly the quantity being isolated.
   rt = nan(numel(PUB), 1);
   cf = strrep(kpiFile, 'KPItableDetailed_', 'correlation_data_');
   if ~exist(cf, 'file'), return; end
   L = load(cf); fn = fieldnames(L); D = [];
   for i = 1:numel(fn), if isstruct(L.(fn{i})), D = L.(fn{i}); break; end, end
   if isempty(D) || ~isfield(D, 'encodedLen') || ~isfield(D, 'RES'), return; end
   len = double(D.encodedLen(:)); y = double(D.RES(:));
   if numel(len) ~= numel(y), return; end
   keep = len > minN;
   len = len(keep); y = y(keep);
   uL = unique(len);
   for c = 1:numel(PUB)
      if ~isfield(D, PUB{c}), continue; end
      x = double(D.(PUB{c})(:));
      if numel(x) ~= numel(keep), continue; end
      x = x(keep);
      zs = []; ws = [];
      for i = 1:numel(uL)
         at = (len == uL(i)) & isfinite(x) & isfinite(y);
         nn = sum(at);
         if nn < 20 || numel(unique(x(at))) < 2, continue; end
         rr = corr(x(at), y(at), 'type', 'Spearman');
         if ~isfinite(rr), continue; end
         rr = max(min(rr, 0.999999), -0.999999);
         zs(end+1) = atanh(rr); ws(end+1) = nn - 3; %#ok<AGROW>
      end
      if ~isempty(zs), rt(c) = tanh(sum(zs .* ws) / sum(ws)); end
   end
end

function v = local_allStats(p, Bset, n, t, nStat)
   nB = numel(Bset); v = nan(1, nStat*nB);
   for b = 1:nB
      [oT, mx, mm, cv, gi] = designMetricScore(p, Bset(b), n, t);
      v(0*nB+b) = oT; v(1*nB+b) = mx; v(2*nB+b) = mm; v(3*nB+b) = cv; v(4*nB+b) = gi;
   end
end

function r = local_withinLength(x, y, lens)
% Spearman across methods within each length, combined over lengths by a
% weighted Fisher z transform (weights n-3). Stated explicitly because raw
% correlation coefficients should not be averaged without saying how.
   r = NaN; uL = unique(lens); zs = []; ws = [];
   for i = 1:numel(uL)
      sel = (lens == uL(i)) & isfinite(x) & isfinite(y);
      nn = sum(sel);
      if nn < 5 || numel(unique(x(sel))) < 2, continue; end
      rr = corr(x(sel), y(sel), 'type', 'Spearman');
      if ~isfinite(rr), continue; end
      rr = max(min(rr, 0.999999), -0.999999);
      zs(end+1) = atanh(rr); ws(end+1) = nn - 3; %#ok<AGROW>
   end
   if isempty(zs), return; end
   r = tanh(sum(zs .* ws) / sum(ws));
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

function T = local_table(f)
   L = load(f); fn = fieldnames(L); T = [];
   for i = 1:numel(fn), if istable(L.(fn{i})), T = L.(fn{i}); return; end, end
   error('metric_scorecard: no table in %s', f);
end

function [lbl, grd] = local_label(name)
   REG = 'single|multi|ge\d+p\d+'; GRD = 'common|standards|probe|legacy';
   t = regexp(name, sprintf('_(%s)_(%s)_', REG, GRD), 'tokens', 'once');
   if ~isempty(t), lbl = sprintf('%s/%s', t{1}, t{2}(1)); grd = t{2}; return; end
   t = regexp(name, sprintf('_(%s)_', REG), 'tokens', 'once');
   if ~isempty(t), lbl = sprintf('%s/?', t{1}); else, lbl = name; end
   grd = 'unknown';
end

function v = local_opt(s, f, dflt)
   if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = dflt; end
end
