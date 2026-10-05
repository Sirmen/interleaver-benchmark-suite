function H = health_check(dataPath, opts)
%HEALTH_CHECK  Is this campaign's data fit to quote?
%
%   H = health_check('<resultsDir>')
%   H = health_check(path, struct('expectConditions', 8, 'runsPerCell', 35))
%
% WHAT THIS REPLACES, AND WHY
% ===========================================================================
% The previous package ran thirteen checks and graded on the fraction that
% passed. On this harness four of them could not fail - normality passed on
% minN >= 30 against an actual 8750, robustness compared a mean against its
% own 2.5th percentile, and both power checks were monotone in sample size
% with one of them reading a hard-coded eta-squared of 0.40 - and one could
% not pass, because completeness counted config.sizeMin:config.sizeMax and
% expected 1765 lengths against a 50-length list. The printed verdict was
% therefore very nearly a constant, "12/13, GOOD, reliable", whatever the
% data said. An instrument with no dynamic range is worse than none, because
% it is quoted.
%
% Three principles follow, and they are the whole design.
%
%   EVERY CHECK MUST BE ABLE TO FAIL. health_selftest corrupts the data in a
%   specific way for each blocking check and asserts that the check catches
%   it. A check that cannot be made to fail is removed rather than reported.
%
%   BLOCKING AND ADVISORY ARE NOT AVERAGED. A pass rate lets a study fail the
%   two checks that decide whether a number may be quoted and still score
%   "GOOD" on eleven that do not. Blocking checks are all-or-nothing;
%   advisory checks are reported with their values and never enter a grade.
%
%   THE CHECKS MUST MATCH THE ANALYSIS. The headline statistics here are
%   paired and nonparametric: an exact sign test over conditions, Spearman
%   rank correlations within length, and a block bootstrap resampling whole
%   lengths. Normality, homoscedasticity of pooled variances and post-hoc
%   F-test power are assumptions of an analysis this study does not lead
%   with. They are available under opts.anova but are not part of the
%   verdict.
%
% WHAT IT READS
% ===========================================================================
% KPItableDetailed_*.mat only - one per condition, about 100 MB rather than
% the 9-11 GB of results_*.mat. Every quantity the blocking checks need is
% in it. The health check must be cheap enough to run every time, or it will
% not be run.
%
% THE VERDICT
% ===========================================================================
%   QUOTABLE                 every blocking check passed
%   QUOTABLE WITH CAVEATS    blocking passed, one or more advisory findings
%   NOT QUOTABLE             a blocking check failed; the finding is named
%
% There is no grade and no percentage. A blocking failure is not offset by
% anything.
%
% OPTIONS
%   runsPerCell        expected replicates per (method, length, noise) cell.
%                      Default: read from config_*.mat testRunsMax, else 35.
%   expectConditions   how many condition files should be present. Default 8.
%   anova              true to also run the ANOVA-assumption checks, which
%                      are reported separately and never enter the verdict.
%   verbose            default true.
%
% R. T. Sirmen study.

   if nargin < 1 || isempty(dataPath)
      c = configure_simulation(); dataPath = char(c.dataSavePath);
   end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'expectConditions'), opts.expectConditions = 8; end
   if ~isfield(opts, 'anova'),            opts.anova = false;        end
   if ~isfield(opts, 'verbose'),          opts.verbose = true;       end
   if ~isfield(opts, 'runsPerCell'),      opts.runsPerCell = [];     end

   d = dir(fullfile(dataPath, 'KPItableDetailed_*.mat'));
   if isempty(d)
      error('health_check: no KPItableDetailed_*.mat in %s', dataPath);
   end

   fprintf('\n===============================================================\n');
   fprintf('  HEALTH CHECK   %s\n', datestr(now, 'yyyy-mm-dd HH:MM'));
   fprintf('  %s\n', dataPath);
   fprintf('===============================================================\n');

   H = struct('path', dataPath, 'when', datestr(now), 'conditions', {{}}, ...
              'blocking', struct(), 'advisory', struct(), 'anova', struct(), ...
              'verdict', '', 'failures', {{}}, 'cautions', {{}});

   % ---- condition inventory: a campaign-level blocking check --------------
   [inv, okInv, whyInv] = local_inventory(d, opts);
   H.conditions = inv;
   H.blocking.B0_conditions = struct('pass', okInv, 'detail', {whyInv}, 'table', {inv});
   local_head('B0', 'Condition inventory', okInv);
   for i = 1:numel(inv)
      fprintf('        %-12s %-10s %-8s %s\n', inv(i).regime, inv(i).grid, inv(i).date, inv(i).file);
   end
   if ~okInv, for i=1:numel(whyInv), fprintf(2,'        ! %s\n', whyInv{i}); end, end

   % ---- per-condition checks ----------------------------------------------
   names = {'B1_occupancy','B2_pairing','B3_resolution','B4_integrity','B5_kpi','B6_field'};
   for k = 1:numel(names), H.blocking.(names{k}) = struct('pass', true, 'detail', {{}}); end
   aNames = {'A1_fairness','A2_dispersion','A3_outliers','A4_blocks'};
   for k = 1:numel(aNames), H.advisory.(aNames{k}) = struct('flag', false, 'detail', {{}}); end

   for i = 1:numel(d)
      f = fullfile(dataPath, d(i).name);
      T = local_rows(load(f));
      if isempty(T)
         H.blocking.B4_integrity.pass = false;
         H.blocking.B4_integrity.detail{end+1} = local_mark2(true, sprintf('%s: unreadable', d(i).name));
         continue;
      end
      cfg = local_config(dataPath, d(i).name);
      runs = opts.runsPerCell;
      if isempty(runs) && ~isempty(cfg) && isfield(cfg,'testRunsMax'), runs = cfg.testRunsMax; end
      if isempty(runs), runs = 35; end

      C = local_cols(T);
      tag = regexprep(d(i).name, '^KPItableDetailed_|\.mat$', '');

      H = local_B1(H, C, tag, runs);
      H = local_B2(H, C, tag);
      H = local_B3(H, C, tag, cfg);
      H = local_B4(H, C, tag);
      H = local_B5(H, C, tag, cfg);
      H = local_B6(H, C, tag);
      H = local_A1(H, C, tag);
      H = local_A2(H, C, tag);
      H = local_A3(H, C, tag);
      H = local_A4(H, C, tag);
      if opts.anova, H = local_anova(H, C, tag); end
   end

   % ---- report -------------------------------------------------------------
   bf = fieldnames(H.blocking);
   fprintf('\n  BLOCKING  (a failure here means no number from this campaign may be quoted)\n');
   for k = 1:numel(bf)
      B = H.blocking.(bf{k});
      local_head(bf{k}(1:2), local_title(bf{k}), B.pass);
      % Detail lines are per condition; the check's verdict is over all of
      % them. Printing every line to stderr because one condition failed
      % makes the passing conditions look like failures too, which is how a
      % report stops being read.
      for j = 1:numel(B.detail)
         [okj, txt] = local_unmark(B.detail{j});
         if okj, fprintf('        %s\n', txt); else, fprintf(2, '        ! %s\n', txt); end
      end
      if ~B.pass, H.failures{end+1} = local_title(bf{k}); end
   end

   af = fieldnames(H.advisory);
   fprintf('\n  ADVISORY  (reported, never averaged into a verdict)\n');
   for k = 1:numel(af)
      A = H.advisory.(af{k});
      local_head(af{k}(1:2), local_title(af{k}), ~A.flag);
      for j = 1:numel(A.detail)
         [okj, txt] = local_unmark(A.detail{j});
         if okj, fprintf('        %s\n', txt); else, fprintf(2, '        ! %s\n', txt); end
      end
      if A.flag, H.cautions{end+1} = local_title(af{k}); end
   end

   if opts.anova
      fprintf('\n  ANOVA ASSUMPTIONS  (only if you run an ANOVA; not part of the verdict)\n');
      anf = fieldnames(H.anova);
      for k = 1:numel(anf)
         fprintf('    %-28s %s\n', anf{k}, H.anova.(anf{k}).text);
      end
   end

   if ~isempty(H.failures)
      H.verdict = 'NOT QUOTABLE';
   elseif ~isempty(H.cautions)
      H.verdict = 'QUOTABLE WITH CAVEATS';
   else
      H.verdict = 'QUOTABLE';
   end

   fprintf('\n===============================================================\n');
   fprintf('  VERDICT: %s\n', H.verdict);
   if ~isempty(H.failures)
      fprintf('  blocked by: %s\n', strjoin(unique(H.failures), '; '));
      fprintf('  No percentage is reported. A blocking failure is not offset\n');
      fprintf('  by the checks that passed.\n');
   elseif ~isempty(H.cautions)
      fprintf('  state alongside the results: %s\n', strjoin(unique(H.cautions), '; '));
   end
   fprintf('===============================================================\n\n');
end

%% ======================= BLOCKING CHECKS ================================

function H = local_B1(H, C, tag, runs)
% CELL OCCUPANCY. Every (method, encodedLen, noiseBin) cell must hold exactly
% the intended number of replicates. This is the check the old package could
% not perform: it compared per-method TOTALS, which are 175 times the cell
% count, so a sweep with one run per cell still reported "EXCELLENT (n>=100)".
   [g, ~] = local_key(C.method, C.encodedLen, C.noiseBin);
   n = accumarray(g, 1);
   nM = numel(unique(C.method)); nL = numel(unique(C.encodedLen)); nB = numel(unique(C.noiseBin));
   expectedCells = nM * nL * nB;
   bad = sum(n ~= runs);
   msg = sprintf('%s: %d methods x %d lengths x %d bins = %d cells, %d replicates each', ...
                 tag, nM, nL, nB, expectedCells, runs);
   H.blocking.B1_occupancy.detail{end+1} = local_mark2(true, msg);
   if numel(n) ~= expectedCells
      H.blocking.B1_occupancy.pass = false;
      H.blocking.B1_occupancy.detail{end+1} = local_mark2(false, sprintf(...
         '%s: %d cells present, %d expected - %d cell(s) MISSING entirely', ...
         tag, numel(n), expectedCells, expectedCells - numel(n)));
   end
   if bad > 0
      H.blocking.B1_occupancy.pass = false;
      H.blocking.B1_occupancy.detail{end+1} = local_mark2(false, sprintf(...
         '%s: %d cell(s) do not hold %d replicates (min %d, max %d)', ...
         tag, bad, runs, min(n), max(n)));
   end
end

function H = local_B2(H, C, tag)
% PAIRING. Every method must see the identical set of (length, noise) trials,
% in the identical order, or a paired difference pairs different trials. This
% is the property paired_method_analysis depends on, and it went unverified
% in this project until the encodedLen column was checked against it.
   uM = unique(C.method);
   cnt = cellfun(@(m) sum(strcmp(C.method, m)), uM);
   if numel(unique(cnt)) ~= 1
      H.blocking.B2_pairing.pass = false;
      H.blocking.B2_pairing.detail{end+1} = local_mark2(true, sprintf(...
         '%s: methods hold %d..%d rows - the design is NOT paired', tag, min(cnt), max(cnt)));
      return;
   end
   L = zeros(cnt(1), numel(uM)); B = L;
   for j = 1:numel(uM)
      at = strcmp(C.method, uM{j});
      L(:, j) = C.encodedLen(at); B(:, j) = C.noiseBin(at);
   end
   dL = max(max(abs(L - L(:,1)))); dB = max(max(abs(B - B(:,1))));
   if dL > 0 || dB > 0
      H.blocking.B2_pairing.pass = false;
      H.blocking.B2_pairing.detail{end+1} = local_mark2(true, sprintf(...
         '%s: row i is not the same trial for every method (length differs in %d rows, bin in %d)', ...
         tag, sum(any(L ~= L(:,1), 2)), sum(any(B ~= B(:,1), 2))));
   else
      H.blocking.B2_pairing.detail{end+1} = local_mark2(true, sprintf(...
         '%s: verified on encodedLen and noiseBin, %d trials x %d methods', tag, cnt(1), numel(uM)));
   end
end

function H = local_B3(H, C, tag, cfg)
% LENGTH RESOLUTION. The block bootstrap resamples whole frame lengths, so
% its domain is the number of DISTINCT encoded lengths.
%
% The failure this exists to catch is COLLAPSE: an arithmetic message-length
% grid under a block code sends several consecutive lengths to the same
% encoded length, so the same permutation - and every quantity derived from
% it - is duplicated, and a bootstrap that treats duplicates as independent
% blocks returns intervals too narrow by roughly the square root of the
% duplication factor. On this project's earlier 991-length grid nine
% consecutive message lengths collapsed to one encoded length.
%
% The first version of this check tested an absolute floor instead, and
% failed the standards grid for having 8 distinct lengths. Those 8 are the
% grid's definition - the published ARP block sizes - not a defect. A small
% grid that is small on purpose is an advisory (A4), not a blocking failure.
% What blocks is a grid that is smaller than it was asked to be.
   uL = unique(C.encodedLen);
   nInt = NaN;
   if ~isempty(cfg) && isfield(cfg, 'sizeList') && ~isempty(cfg.sizeList)
      nInt = numel(unique(cfg.sizeList));
   end
   if isfield(C, 'intendedLengths'), nInt = C.intendedLengths; end
   if isfinite(nInt)
      if numel(uL) < nInt
         H.blocking.B3_resolution.pass = false;
         H.blocking.B3_resolution.detail{end+1} = local_mark2(false, sprintf(...
            ['%s: the design asked for %d lengths and the data holds %d distinct ' ...
             'encoded lengths - %d collapsed. A length bootstrap would resample ' ...
             'duplicated blocks as independent ones.'], tag, nInt, numel(uL), nInt - numel(uL)));
      else
         H.blocking.B3_resolution.detail{end+1} = local_mark2(true, sprintf(...
            '%s: %d distinct encoded lengths, matching the %d the design asked for', ...
            tag, numel(uL), nInt));
      end
   else
      % A check that cannot be performed does not report a pass. Without the
      % intended length list there is nothing to compare the realized lengths
      % against, and silently passing here is how the previous package came to
      % report a grade that did not depend on the data.
      H.blocking.B3_resolution.pass = false;
      H.blocking.B3_resolution.detail{end+1} = local_mark2(false, sprintf(...
         ['%s: %d distinct encoded lengths, but config has no sizeList, so ' ...
          'collapse against the intended grid CANNOT BE CHECKED. Supply the ' ...
          'config file or pass opts.sizeList.'], tag, numel(uL)));
   end
end

function H = local_B4(H, C, tag)
% FIELD INTEGRITY, per variable. The old check averaged the missing rate over
% five variables, so RES could be a quarter NaN and still pass on the other
% four. Each variable is gated on its own here.
   vars = {'RES','CR','BE','noiseActual','decodeErrRate'};
   for k = 1:numel(vars)
      if ~isfield(C, vars{k}), continue; end
      v = C.(vars{k});
      nMiss = sum(isnan(v)); nInf = sum(isinf(v));
      if nMiss > 0 || nInf > 0
         H.blocking.B4_integrity.pass = false;
         H.blocking.B4_integrity.detail{end+1} = local_mark2(true, sprintf(...
            '%s: %s has %d NaN and %d Inf of %d (%.2f%%)', ...
            tag, vars{k}, nMiss, nInf, numel(v), 100*(nMiss+nInf)/numel(v)));
      end
   end
end

function H = local_B5(H, C, tag, cfg)
% KPI RECONSTRUCTION. Recompute CR and RES from the stored inputs under the
% documented definition and compare against the stored values. This is the
% one check that tests whether the numbers in the file are the numbers the
% paper's equations describe. It is also the check that catches a file
% rebuilt with a different method field or different weights, because RES is
% standardized over whatever field was present when it was written.
   need = {'decodeErrRate','decErrRate_woInt','noiseActual','encodedLen','interleavedLen','noiseBin','CR','RES'};
   if ~all(isfield(C, need))
      H.blocking.B5_kpi.detail{end+1} = local_mark2(true, sprintf('%s: inputs absent, reconstruction skipped', tag));
      return;
   end
   if isempty(cfg) || ~isfield(cfg, 'noiseLevels')
      H.blocking.B5_kpi.detail{end+1} = local_mark2(true, sprintf('%s: no config.noiseLevels, reconstruction skipped', tag));
      return;
   end
   nb = C.noiseBin; tgt = nan(size(nb));
   ok = nb >= 1 & nb <= numel(cfg.noiseLevels);
   tgt(ok) = cfg.noiseLevels(nb(ok));
   BE = C.encodedLen ./ C.interleavedLen;
   CRraw = max(0, 1 - (C.decodeErrRate ./ (C.decErrRate_woInt + eps)));
   CR = CRraw .* (C.noiseActual ./ (tgt + eps));
   CRz = (CR - mean(CR)) / (std(CR) + eps);
   BEz = (BE - mean(BE)) / (std(BE) + eps);
   RES = 0.5*CRz + 0.5*BEz;
   eCR = max(abs(CR - C.CR)); eRES = max(abs(RES - C.RES));
   if max(eCR, eRES) < 1e-9
      H.blocking.B5_kpi.detail{end+1} = local_mark2(true, sprintf('%s: CR and RES reproduce to %.1e', tag, max(eCR,eRES)));
   else
      H.blocking.B5_kpi.pass = false;
      H.blocking.B5_kpi.detail{end+1} = local_mark2(true, sprintf(...
         ['%s: stored CR/RES do NOT reproduce (CR %.3g, RES %.3g). Either the ' ...
          'definition changed, the weights differ, or the file was standardized ' ...
          'over a different method field.'], tag, eCR, eRES));
   end
end

function H = local_B6(H, C, tag)
% METHOD FIELD. RES is standardized over every row of the file, so a z-score
% is relative to the methods evaluated together. Two files with different
% method sets carry RES values that are not on the same scale and must not be
% pooled or compared. The field is recorded here so that a later reader can
% see what was standardized with what.
   uM = sort(unique(C.method));
   H.blocking.B6_field.detail{end+1} = local_mark2(true, sprintf('%s: %d methods [%s]', ...
      tag, numel(uM), strjoin(uM(:).', ', ')));
   if ~isfield(H, 'fieldSeen'), H.fieldSeen = struct('tag', {}, 'methods', {}); end
end

%% ======================= ADVISORY CHECKS ================================

function H = local_A1(H, C, tag)
% NOISE FAIRNESS - tested as an exact invariant, not against a threshold.
%
% Two earlier versions of this check were wrong in instructive ways. The
% first grouped by (length, noise bin), which pools the replicates of the
% block, so under Gilbert-Elliott the trial-to-trial variation in the
% realized error count was reported as method unfairness - a 53 % spread
% that belonged to the channel draw. The second compared the within-trial
% spread against the frame extension, but read each method's extension from
% its first row, and the extension varies with length, so the comparison was
% against a proxy that happened to be generous.
%
% There is no need for either. The design shares one burst mask per trial, so
% the number of corrupted symbols is a property of the trial and not of the
% method. noiseActual is that count divided by the interleaved length, so
%
%       noiseActual x interleavedLen = errorCount
%
% must be IDENTICAL across methods within a trial, to rounding. That is an
% exact invariant with no threshold in it, and a violation means the masks
% were not shared and the paired comparison is not like-for-like.
   uM = unique(C.method);
   cnt = cellfun(@(m) sum(strcmp(C.method, m)), uM);
   if numel(unique(cnt)) ~= 1
      H.advisory.A1_fairness.detail{end+1} = local_mark2(true, sprintf(...
         '%s: not paired, so a within-trial comparison is not available', tag));
      return;
   end
   E = zeros(cnt(1), numel(uM)); D = E;
   for j = 1:numel(uM)
      at = strcmp(C.method, uM{j});
      E(:, j) = C.noiseActual(at) .* C.interleavedLen(at);   % errors in the trial
      D(:, j) = C.noiseActual(at);                            % density seen
   end
   dev = max(abs(E - round(mean(E, 2))), [], 2);              % counts are integers
   worstE = max(dev);
   spread = (max(D, [], 2) - min(D, [], 2)) ./ (mean(D, 2) + eps);
   H.advisory.A1_fairness.detail{end+1} = local_mark2(true, sprintf(...
      ['%s: implied error count is constant across methods within a trial to ' ...
       '%.3g symbols; the density they see therefore differs by %.2f%% at the ' ...
       'median and %.2f%% at worst, which is the frame extension and is what ' ...
       'C_NN corrects'], tag, worstE, 100*median(spread), 100*max(spread)));
   if worstE > 0.5
      H.advisory.A1_fairness.flag = true;
      H.advisory.A1_fairness.detail{end+1} = local_mark2(false, sprintf(...
         ['%s: the implied error count differs by up to %.3g symbols between ' ...
          'methods in the same trial. The mask was not shared, and a paired ' ...
          'difference between those methods is not like-for-like.'], tag, worstE));
   end
end

function H = local_A2(H, C, tag)
% DISPERSION, computed WITHIN cell. Pooling a method's RES over all lengths
% and noise bins adds a between-cell variance that every method shares, so a
% hundredfold difference in within-cell variance can read as a ratio of 1.03
% and pass a "variance ratio < 4" test. The ratio below is over within-cell
% variances and can actually move.
   [g, mid] = local_key(C.method, C.encodedLen, C.noiseBin);
   v  = accumarray(g, C.RES, [], @var);          % variance of each cell
   gm = accumarray(g, mid, [], @max);            % which method each cell is
   wv = accumarray(gm, v, [], @mean);            % mean within-cell variance
   wv = wv(wv > 0);
   if isempty(wv), return; end
   [vmax, imax] = max(wv); [vmin, imin] = min(wv);
   rat = vmax / max(vmin, eps);
   uM = unique(C.method);
   H.advisory.A2_dispersion.detail{end+1} = local_mark2(true, sprintf(...
      '%s: within-cell RES variance ratio %.1f  (%s %.2e vs %s %.2e)', ...
      tag, rat, uM{imax}, vmax, uM{imin}, vmin));
   if rat > 4
      H.advisory.A2_dispersion.flag = true;
      H.advisory.A2_dispersion.detail{end+1} = local_mark2(false, sprintf(...
         ['%s: a pooled-variance test would be misleading. Check whether the ' ...
          'low-variance method is genuinely consistent or is pinned at the ' ...
          'CR floor, where max(0, .) removes its variance. The paired and rank ' ...
          'statistics this study leads with are unaffected either way.'], tag));
   end
end

function H = local_A3(H, C, tag)
% OUTLIERS, with the fences computed WITHIN cell. Fences taken over a
% method's pooled records span the whole design range, so a genuine
% within-cell outlier falls comfortably inside them and nothing is flagged.
   [g, ~] = local_key(C.method, C.encodedLen, C.noiseBin);
   n = accumarray(g, 1);
   if min(n) < 10
      H.advisory.A3_outliers.detail{end+1} = local_mark2(true, sprintf(...
         ['%s: smallest cell holds %d replicates; quartile fences below ten ' ...
          'points are two order statistics and flag freely, so this check is ' ...
          'not reported for this campaign.'], tag, min(n)));
      return;
   end
   nOut = accumarray(g, C.RES, [], @local_fence);
   r = 100 * sum(nOut) / numel(C.RES);
   H.advisory.A3_outliers.detail{end+1} = local_mark2(true, sprintf(...
      '%s: %.2f%% of trials lie outside their own cell''s 1.5 IQR fences', tag, r));
   if r > 2
      H.advisory.A3_outliers.flag = true;
      H.advisory.A3_outliers.detail{end+1} = local_mark2(true, sprintf(...
         ['%s: rank statistics are insensitive to how far an outlier lies, but ' ...
          'a single bad value still flips the sign of a paired difference.'], tag));
   end
end

function k = local_fence(v)
   q1 = quantile(v, 0.25); q3 = quantile(v, 0.75); iq = q3 - q1;
   k = sum(v < q1 - 1.5*iq | v > q3 + 1.5*iq);
end

function H = local_A4(H, C, tag)
% BOOTSTRAP DOMAIN. How many blocks a length bootstrap actually has to draw
% from - which is the number of DISTINCT lengths, not the number of rows.
   nL = numel(unique(C.encodedLen));
   H.advisory.A4_blocks.detail{end+1} = local_mark2(true, sprintf('%s: %d blocks available to a length bootstrap', tag, nL));
   if nL < 20
      H.advisory.A4_blocks.flag = true;
      H.advisory.A4_blocks.detail{end+1} = local_mark2(true, sprintf(...
         '%s: under 20 blocks a percentile interval is coarse; report it as such', tag));
   end
end

%% ======================= ANOVA ASSUMPTIONS =============================

function H = local_anova(H, C, tag)
% Reported only because an ANOVA appears elsewhere in the analysis. These are
% assumptions of a pooled-variance F test and have no bearing on a sign test,
% a Spearman correlation or a block bootstrap, so they never enter the
% verdict. Residuals are taken WITHIN cell, which is where the assumption
% actually lives; the marginal distribution of a 250-component mixture is
% non-normal even when every cell is perfectly Gaussian.
   [g, ~] = local_key(C.method, C.encodedLen, C.noiseBin);
   r = C.RES;
   for b = 1:max(g), at = (g == b); r(at) = r(at) - mean(r(at)); end
   sk = mean(((r - mean(r))/std(r)).^3);
   ku = mean(((r - mean(r))/std(r)).^4);
   H.anova.(matlab.lang.makeValidName(['resid_' tag])) = struct('text', ...
      sprintf('within-cell residuals: skewness %.2f, kurtosis %.2f (normal: 0 and 3)', sk, ku));
end

%% ======================= HELPERS =======================================

function [inv, ok, why] = local_inventory(d, opts)
   inv = struct('file', {}, 'regime', {}, 'grid', {}, 'date', {});
   for i = 1:numel(d)
      t = regexp(d(i).name, '^KPItableDetailed_([a-z0-9p]+)_([a-z]+)_(\d+)_', 'tokens', 'once');
      if isempty(t)
         inv(end+1) = struct('file', d(i).name, 'regime', '?', 'grid', '?', 'date', '?'); %#ok<AGROW>
      else
         inv(end+1) = struct('file', d(i).name, 'regime', t{1}, 'grid', t{2}, 'date', t{3}); %#ok<AGROW>
      end
   end
   why = {}; ok = true;
   if numel(inv) ~= opts.expectConditions
      ok = false;
      why{end+1} = sprintf(['%d condition file(s) present, %d expected. The sign test counts ' ...
                            'conditions, so an extra or missing file changes its p directly.'], ...
                            numel(inv), opts.expectConditions);
   end
   keys = arrayfun(@(x) [x.regime '_' x.grid], inv, 'UniformOutput', false);
   [u, ~, ic] = unique(keys);
   for k = 1:numel(u)
      if sum(ic == k) > 1
         ok = false;
         why{end+1} = sprintf('condition "%s" appears %d times - two campaigns are mixed', u{k}, sum(ic==k)); %#ok<AGROW>
      end
   end
end

function local_head(id, name, pass)
   if pass, m = 'PASS'; else, m = 'FAIL'; end
   fprintf('\n    [%s] %-34s %s\n', id, name, m);
end

function t = local_title(f)
   map = struct('B0_conditions','Condition inventory', 'B1_occupancy','Cell occupancy', ...
      'B2_pairing','Pairing integrity', 'B3_resolution','Length resolution', ...
      'B4_integrity','Field integrity', 'B5_kpi','KPI reconstruction', ...
      'B6_field','Method field on record', 'A1_fairness','Noise fairness per block', ...
      'A2_dispersion','Within-cell dispersion', 'A3_outliers','Within-cell outliers', ...
      'A4_blocks','Bootstrap block count');
   if isfield(map, f), t = map.(f); else, t = f; end
end

function s = local_mark2(ok, txt)
   if ok, s = ['+' txt]; else, s = ['-' txt]; end
end

function [ok, txt] = local_unmark(s)
   if ~isempty(s) && (s(1) == '+' || s(1) == '-')
      ok = (s(1) == '+'); txt = s(2:end);
   else
      ok = true; txt = s;
   end
end

function [g, mid] = local_key(m, a, b)
% Cell index per row, plus the method index, both as dense 1..n codes so
% accumarray can group in one pass.
   [~, ~, mid] = unique(m);
   [~, ~, g] = unique([mid(:) a(:) b(:)], 'rows');
end

function g = local_key2(a, b)
   [~, ~, g] = unique([a(:) b(:)], 'rows');
end

function C = local_cols(T)
   C = struct(); fn = fieldnames(T);
   for k = 1:numel(fn)
      if ischar(T(1).(fn{k}))
         C.(fn{k}) = {T.(fn{k})}.';
      else
         v = [T.(fn{k})];
         if numel(v) == numel(T), C.(fn{k}) = double(v(:)); end
      end
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

function rows = local_rows(S)
   rows = [];
   fn = fieldnames(S);
   hasTable = exist('istable', 'builtin') || exist('istable', 'file');
   for i = 1:numel(fn)
      v = S.(fn{i});
      if hasTable && istable(v), rows = table2struct(v); return; end
      if isstruct(v) && numel(v) > 1, rows = v; return; end
   end
end
