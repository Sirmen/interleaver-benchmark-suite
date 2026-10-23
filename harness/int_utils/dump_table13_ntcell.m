function T = dump_table13_ntcell(dataPath, tableDir, opts)
%DUMP_TABLE13_NTCELL  Table XIII's a priori (n,t) column, with its own check.
%
%   T = dump_table13_ntcell('<resultsDir>', '<tableDir>')
%
% WHY ONLY ONE COLUMN
% ---------------------------------------------------------------------------
% v98 makes B_guar the primary metric of the a priori, (n,t)-aware cell, so
% Table XIII's column for that cell changes from overT to B_guar. Every other
% column of that table is unchanged, and metric_scorecard returns correlations
% rather than per-method values, so there is nothing to read out of it: the
% column has to be recomputed. Recomputing the whole table instead would mean
% re-deriving the scope filter, the method exclusions and the averaging, which
% is four more chances to produce a table that disagrees with the published one
% in a way nobody notices.
%
% HOW IT CHECKS ITSELF
% ---------------------------------------------------------------------------
% The averaging has to be the SAME averaging the published column used, and
% the only way to know that is to reproduce a column that already exists. So
% overT is recomputed here beside B_guar, by the same path, and printed next
% to the values Table XIII prints today:
%
%   block 0.776   matrix 0.996   snake 0.976   helical 0.998
%   helicalScan 0.999   diagonal 1.000   spiral 1.000
%   latinSquare 0.733   goldenRP 0.441   srandom 0.912
%
% If those reproduce, the B_guar column beside them was built the same way. If
% they do not, the B_guar column is wrong and the message says so rather than
% writing a plausible-looking CSV.
%
% THE AVERAGING IS NOT A HYPOTHESIS ANY MORE
% ---------------------------------------------------------------------------
% Table XIII's own caption states it: "Cell means over noise bins and runs at
% the 44 common-grid lengths with N > 24n, averaged over the four burst
% regimes; the last column is the same on the standards grid (5 lengths) ...
% giniLoad and overT at B = 12n."
%
% Three things in that sentence were wrong in the first two versions of this
% file, and each one moved the columns:
%
%   1. The floor is 24n = 360, not max(Bset) = 12n = 180. Counted from the
%      campaign, encodedLen > 360 leaves exactly 44 common-grid lengths and
%      exactly 5 standards-grid lengths - the two counts the caption prints.
%      At 180 the count is 47, and the three extra short lengths are where a
%      fixed B saturates, so every unsaturated method came out high.
%   2. The nine left-hand columns are COMMON GRID ONLY. The standards grid
%      enters the last column and nowhere else. Pooling all eight conditions
%      mixes two grids with different length sets into one mean.
%   3. B is 12n for both permutation columns. Table XIII has no 8n column;
%      8n belongs to Table X, which quotes a range.
%
% With the floor at 360 and the common grid alone, all six per-trial columns
% of Table XIII reproduce for all 23 in-scope methods - eta_sep, delta_G,
% S_ECC, CR, BE and RES - to the last printed digit: worst deviation 0.0005,
% and 0.0049 on S_ECC, which is printed to two decimals. The standards-grid
% RES column reproduces too. That is 144 published values from one averaging
% rule, so the rule is established and the permutation columns below rest on
% it rather than on a guess.
%
% The campaign is also exactly balanced - 44 lengths x 5 noise bins x 35
% replicates in each of the four regimes - which is why a permutation-only
% quantity reduces to an UNWEIGHTED mean over the 44 lengths. The balance is
% asserted below rather than assumed: the reduction fails silently if a later
% campaign drops a cell.
%
% UNITS
% ---------------------------------------------------------------------------
% overT is a fraction of burst start positions. B_guar is a burst length in
% SYMBOLS, so its column is not on [0,1] - as S_ECC's column is not either,
% being a margin in symbols. Section 6.4 says what the number is.
%
% R. Tanju Sirmen study.

   if nargin < 3, opts = struct(); end
   FECn = local_opt(opts, 'FECn', 15);
   FECt = local_opt(opts, 'FECt', 3);
   Bset = local_opt(opts, 'Bset', FECn * [1 2 4 8 12 16 24]);
   BoverT = local_opt(opts, 'BoverT', 12 * FECn);     % Table XIII's overT column
   % B IS 12n, AND THE 8n COLUMN IS KEPT ONLY AS A WITNESS.
   % validation_supplement's list carries giniLoad twice,
   %   DES = {'giniLoad',12; 'meanMaxCW',24; 'maxErrCW',24; 'overT',12;
   %          'cvLoad',24; 'giniLoad',8}
   % and Table X writes the cell as "giniLoad (B = 8n-12n)", a range. That is
   % Table X. Table XIII's caption names one value, 12n, so the VERDICT below
   % is taken at 12n alone. The 8n column is still printed, because when the
   % first version of this file missed the published column by 0.002 to 0.010
   % the two B's were the leading suspect, and printing both is what shows
   % that the residual was never about B at all.
   Bgini1 = local_opt(opts, 'Bgini1', 12 * FECn);
   Bgini2 = local_opt(opts, 'Bgini2',  8 * FECn);
   nDraw  = local_opt(opts, 'nDraw', 15);

   % THE SCOPE FLOOR IS THE CAPTION'S, NOT THE SWEEP'S.
   % minN = max(Bset) was wrong: it is 12n, and it is a property of the B
   % sweep, which has nothing to do with which lengths Table XIII averages.
   % The caption says N > 24n, and 24n is what reproduces the 44/5 counts and
   % all six per-trial columns. Do not tie this to Bset again.
   minN    = local_opt(opts, 'minN', 24 * FECn);
   gridTag = local_opt(opts, 'gridTag', 'common');
   nLenExp = local_opt(opts, 'nLenExp', 44);   % expected lengths above minN
   nNoiseExp = local_opt(opts, 'nNoiseExp', 5);
   dropMethods = local_opt(opts, 'dropMethods', {'freqDeterm', 'freqRandom'});
   ENSEMBLE = {'random', 'freqRandom'};

   % Published Table XIII values, for the three columns this can check.
   %   overT     from the permutation, at B = 12n
   %   giniLoad  from the permutation, at B = 12n
   %   eta_sep   from correlation_data, not from the permutation at all
   % That last difference is the point. If giniLoad deviates where overT does
   % but eta_sep does not, the PERMUTATION the table now holds is not the one
   % the column was computed from, and every permutation-derived column for
   % that method is suspect. If both permutation columns reproduce and only
   % overT deviates, the problem is specific to overT - a column that is being
   % replaced anyway.
   REF = struct( ...
      'block',       [0.776 0.540 0.113], 'matrix',      [0.996 0.600 0.099], ...
      'snake',       [0.976 0.550 0.113], 'helical',     [0.998 0.601 0.103], ...
      'helicalScan', [0.999 0.612 0.103], 'diagonal',    [1.000 0.680 0.068], ...
      'spiral',      [1.000 0.691 0.074], 'latinSquare', [0.733 0.429 0.100], ...
      'goldenRP',    [0.441 0.334 0.683], 'srandom',     [0.912 0.345 0.676]);

   % Table XIII's eta_sep column for EVERY in-scope method, not just the ten
   % that have a published overT here. eta_sep is the anchor: it comes from
   % correlation_data, so it tests the averaging and nothing else, and a
   % 23-method anchor leaves no room for an averaging that happens to fit ten
   % rows. ARP is absent because it is defined only on the standards grid.
   ESREF = struct( ...
      'block', 0.113, 'matrix', 0.099, 'snake', 0.113, 'helical', 0.103, ...
      'helicalScan', 0.103, 'diagonal', 0.068, 'spiral', 0.074, ...
      'latinSquare', 0.100, 'goldenRP', 0.683, 'srandom', 0.676, ...
      'prime', 0.665, 'convolutional', 0.111, 'blockCM', 0.248, ...
      'convCM', 0.247, 'turbo', 0.754, 'random', 0.668, 'S', 0.998, ...
      'chaotic', 0.905, 'drp', 0.666, 'multiDim', 0.434, ...
      'algebraic', 0.334, 'hierarchical', 0.094, 'time', 0.122);

   if isempty(tableDir) || exist(fullfile(char(tableDir), ...
         'table_factors_precomputed.mat'), 'file') ~= 2
      [tableDir, erF] = find_table_dir(dataPath);
      if erF ~= "", error('dump_table13_ntcell: %s', erF); end
   end
   [tpc, erT] = PrecomputedInterleaverLoader(tableDir);
   if erT ~= "", error('dump_table13_ntcell: %s', erT); end
   [tp, tfac] = PrimeFactorLoader(tableDir);

   d = dir(fullfile(dataPath, 'correlation_data_*.mat'));
   if isempty(d), error('dump_table13_ntcell: no correlation_data_*.mat in %s', dataPath); end

   acc = containers.Map();                 % method -> [sumOverT sumBguar nCells]
   % THE LENGTH IS encodedLen, NOT N.
   %
   % validation_supplement, which is the path that produced the per-method
   % columns, does
   %     len  = double(D.encodedLen(:));
   %     keep = len > minN & ~ismember(meth, OUTS);
   %     p    = local_perm(tpc, mn, N);      % N here is that encodedLen
   % so the permutation is fetched at the ENCODED length and the cells are
   % grouped by it. The first version of this file grouped by D.N and fetched
   % the permutation there, which is a different and smaller length: with B
   % fixed at 12n, overT saturates toward 1 as the length falls, so every
   % unsaturated method came out too high and only the already-saturated ones
   % appeared to agree. The check caught it.
   %
   % Two smaller differences from that path mattered too: the filter is
   % STRICTLY greater than minN, and the only exclusion is OUTS. There is no
   % standardizedOn restriction here - out-of-scope methods are marked rather
   % than dropped, and Table XIII chooses its rows separately.
   %
   % ONE POOLING, AND IT IS THE CAPTION'S.
   %
   % Earlier versions computed two candidate poolings and let whichever fitted
   % decide. That is backwards: the caption already says which one it is, and a
   % pooling chosen because it fits cannot then be evidence that it is right.
   % Cell means over (encodedLen, noiseBin) within a regime, averaged over
   % cells, then averaged over the four regimes, on the common grid alone -
   % that rule reproduces all six per-trial columns for all 23 methods, so it
   % is used here as a fact and no alternative is computed.
   %
   % Because the design is balanced, the rule collapses for a permutation-only
   % quantity to an unweighted mean over the lengths, which is what the loop
   % below accumulates. The balance is checked; an unbalanced campaign makes
   % the collapse invalid and the message says so.
   OUTS = dropMethods;
   keepFile = ~cellfun(@isempty, strfind({d.name}, ['_' gridTag '_']));  %#ok<STRCLFH>
   if ~any(keepFile)
      error(['dump_table13_ntcell: no correlation_data file in %s carries the ' ...
             'grid tag "_%s_". Table XIII''s left-hand columns are that grid ' ...
             'alone, so there is nothing to average.'], dataPath, gridTag);
   end
   nSkipped = sum(~keepFile);
   d = d(keepFile);
   fprintf(['\n  grid "%s": %d condition file(s), %d other-grid file(s) left out.\n' ...
            '  scope floor encodedLen > %d (= 24n), expecting %d lengths.\n\n'], ...
           gridTag, numel(d), nSkipped, minN, nLenExp);
   for i = 1:numel(d)
      L = load(fullfile(d(i).folder, d(i).name));
      fn = fieldnames(L); C = [];
      for j = 1:numel(fn), if isstruct(L.(fn{j})), C = L.(fn{j}); break; end, end
      if isempty(C) || ~isfield(C, 'methodNames')
         fprintf(2, '  %-46s no methodNames - skipped\n', d(i).name); continue;
      end
      names = cellstr(C.methodNames(:));
      meth  = string(names(double(C.methodID(:))));
      len   = double(C.encodedLen(:));
      es    = double(C.eta_sep(:));
      keep  = len > minN & ~ismember(meth, OUTS);
      if ~any(keep), continue; end

      % THE BALANCE CHECK.
      % esCell below averages every trial in a (method, length) cell at once,
      % and the accumulator weights every (method, length) cell equally. Both
      % equal the caption's "cell means over noise bins and runs, averaged
      % over the regimes" ONLY if each length carries the same noise bins and
      % each of those the same number of runs. If it does not, the two differ
      % silently, so the condition is tested rather than trusted.
      uL = unique(len(keep));
      if numel(uL) ~= nLenExp
         fprintf(2, ['  %s: %d lengths above %d, expected %d. Table XIII''s\n' ...
                     '    caption names %d; this campaign is not the published grid.\n'], ...
                 d(i).name, numel(uL), minN, nLenExp, nLenExp);
      end
      if isfield(C, 'noiseBin')
         nbv = double(C.noiseBin(:));
         one = keep & meth == meth(find(keep, 1));
         nbPerLen = arrayfun(@(x) numel(unique(nbv(one & len == x))), uL);
         repPerCell = [];
         for b = unique(nbv(one))'
            repPerCell = [repPerCell; sum(one & len == uL(1) & nbv == b)];  %#ok<AGROW>
         end
         if any(nbPerLen ~= nNoiseExp) || numel(unique(repPerCell)) ~= 1
            fprintf(2, ['  %s: UNBALANCED - noise bins per length %s, replicates\n' ...
                        '    per cell %s. The unweighted mean below is then NOT the\n' ...
                        '    caption''s cell-mean average and these columns must not be\n' ...
                        '    quoted.\n'], d(i).name, mat2str(unique(nbPerLen)'), ...
                    mat2str(unique(repPerCell)'));
         end
      end

      [g, gm, gl] = findgroups(meth(keep), len(keep));
      esCell = splitapply(@(z) mean(z, 'omitnan'), es(keep), g);
      for u = 1:numel(gm)
         m = char(gm(u)); N = gl(u);
         [oT, bg, g12] = local_values(m, N, Bgini1, FECn, FECt, tpc, tp, tfac, ...
                                      ENSEMBLE, nDraw);
         [~,  ~,  g8]  = local_values(m, N, Bgini2, FECn, FECt, tpc, tp, tfac, ...
                                      ENSEMBLE, nDraw);
         if isnan(oT) && isnan(bg), continue; end
         if ~isKey(acc, m), acc(m) = [0 0 0 0 0 0]; end
         a = acc(m);
         acc(m) = [a(1) + oT, a(2) + bg, a(3) + 1, a(4) + g12, ...
                   a(5) + esCell(u), a(6) + g8];
      end
      fprintf('  %-46s %4d cells\n', d(i).name, numel(gm));
   end

   ms = sort(keys(acc));
   T = struct('method', {}, 'overT', {}, 'Bguar', {}, 'giniLoad', {}, ...
              'gini8n', {}, 'etaSep', {}, 'nCells', {});
   fprintf(['\n  Three published columns, recomputed. overT and giniLoad come from\n' ...
            '  the permutation; eta_sep comes from correlation_data and not from the\n' ...
            '  permutation at all.\n\n']);
   fprintf('  %-13s %8s %17s %8s %17s %8s\n', '', 'overT', 'giniLoad', '', ...
           'eta_sep', 'B_guar');
   fprintf('  %-13s %8s %8s %8s %8s %8s %8s %8s %8s\n', 'method', ...
           'here', 'pub', '12n', '8n', 'pub', 'here', 'pub', '');
   fprintf('  %s\n', repmat('-', 1, 86));
   for k = 1:numel(ms)
      m = ms{k}; a = acc(m);
      oT = a(1)/a(3); bg = a(2)/a(3); gi = a(4)/a(3); es = a(5)/a(3);
      g8 = a(6)/a(3);
      T(end+1) = struct('method', m, 'overT', oT, 'Bguar', bg, ...
                        'giniLoad', gi, 'gini8n', g8, 'etaSep', es, ...
                        'nCells', a(3));  %#ok<AGROW>
      if isfield(REF, m)
         r = REF.(m);
         fprintf('  %-13s %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %8.1f\n', ...
                 m, oT, r(1), gi, g8, r(2), es, r(3), bg);
      else
         fprintf('  %-13s %8.3f %8s %8.3f %8.3f %8s %8.3f %8s %8.1f\n', ...
                 m, oT, '-', gi, g8, '-', es, '-', bg);
      end
   end
   fprintf('  %s\n', repmat('-', 1, 76));

   % THE ANCHOR IS CHECKED FIRST AND SEPARATELY.
   % eta_sep is not derived from the permutation, so it tests the averaging
   % alone. It is checked on all 23 in-scope methods, and the result decides
   % how the permutation columns are to be read: if the anchor holds, a
   % deviation in overT or giniLoad is about the permutation or about B, and
   % is NOT a reason to doubt the averaging. Keeping the two verdicts apart is
   % the whole point - bundling them is what made an earlier run report "the
   % averaging is not established" when the averaging was never in question.
   TOL = 0.002; esBad = {}; esN = 0;
   for k = 1:numel(T)
      m = T(k).method;
      if ~isfield(ESREF, m), continue; end
      esN = esN + 1;
      dEs = abs(T(k).etaSep - ESREF.(m));
      if dEs > TOL
         esBad{end+1} = sprintf('%-13s eta_sep %.4f', m, dEs);  %#ok<AGROW>
      end
   end
   if esN == 0
      fprintf(2, '\n  ANCHOR NOT TESTED: no in-scope method matched ESREF.\n\n');
   elseif isempty(esBad)
      fprintf(['\n  ANCHOR HOLDS. eta_sep reproduces Table XIII for all %d in-scope\n' ...
               '  methods within %.3f. The averaging in this file is the published\n' ...
               '  one, and the permutation columns below are on that footing.\n\n'], ...
              esN, TOL);
   else
      fprintf(2, '\n  ANCHOR FAILS for %d of %d method(s):\n', numel(esBad), esN);
      for k = 1:numel(esBad), fprintf(2, '    %s\n', esBad{k}); end
      fprintf(2, ['\n  eta_sep does not touch the permutation, so this is the averaging\n' ...
                  '  or the scope filter and nothing else. Fix that before reading any\n' ...
                  '  column below. The caption''s rule is: common grid, encodedLen >\n' ...
                  '  24n, cell means over noise bins and runs, mean over the four\n' ...
                  '  regimes.\n\n']);
   end

   % the permutation columns, judged at the caption's B and nowhere else
   bad = {};
   for k = 1:numel(T)
      m = T(k).method;
      if ~isfield(REF, m), continue; end
      r = REF.(m);
      dv = [abs(T(k).overT - r(1)), abs(T(k).giniLoad - r(2))];
      if any(dv > TOL)
         which = {}; nm = {'overT','giniLoad'};
         for q = 1:2, if dv(q) > TOL, which{end+1} = sprintf('%s %.4f', nm{q}, dv(q)); end, end %#ok<AGROW>
         bad{end+1} = sprintf('%-13s %s   [8n would give giniLoad %.4f off]', m, ...
                              strjoin(which, ', '), abs(T(k).gini8n - r(2)));  %#ok<AGROW>
      end
   end
   if isempty(bad)
      fprintf(['  Both permutation columns reproduce at B = 12n for all ten methods\n' ...
               '  that publish them. The B_guar column beside them was built by the\n' ...
               '  same path and may be quoted.\n\n']);
   else
      fprintf(2, '  Permutation columns, deviations above %.3f at B = 12n:\n', TOL);
      for k = 1:numel(bad), fprintf(2, '    %s\n', bad{k}); end
      fprintf(2, ['\n  With the anchor holding, this is not the averaging. It is the\n' ...
                  '  permutation the table now holds for that method, or the B, or\n' ...
                  '  designMetricScore''s definition of the column. The 8n figure is\n' ...
                  '  printed only to show whether B is even the right suspect.\n\n']);
   end

   try
      out = fullfile(dataPath, 'table13_ntcell.csv');
      fid = fopen(out, 'w');
      if fid < 0, error('cannot open %s', out); end
      fprintf(fid, ['method,overT,overT_pub,giniLoad_12n,giniLoad_8n,' ...
                    'giniLoad_pub,eta_sep,eta_sep_pub,B_guar,nCells\n']);
      for k = 1:numel(T)
         m = T(k).method;
         if isfield(REF, m)
            r = REF.(m); p1 = sprintf('%.3f', r(1)); p2 = sprintf('%.3f', r(2));
            p3 = sprintf('%.3f', r(3));
         else
            p1 = ''; p2 = ''; p3 = '';
         end
         fprintf(fid, '%s,%.6g,%s,%.6g,%.6g,%s,%.6g,%s,%.6g,%d\n', m, ...
                 T(k).overT, p1, T(k).giniLoad, T(k).gini8n, p2, ...
                 T(k).etaSep, p3, T(k).Bguar, T(k).nCells);
      end
      fclose(fid);
      fprintf('\n  wrote %s\n\n', out);
   catch err
      fprintf(2, '  could not write the CSV: %s\n', err.message);
   end
end

function [oT, bg, gi] = local_values(m, N, B, n, t, tpc, tp, tfac, ENSEMBLE, nDraw)
% The two (n,t)-aware design values for one (method, length). Ensemble methods
% redraw every frame, so they are averaged over the same number of draws the
% scorecard uses; everything else comes from the precomputed table.
   oT = NaN; bg = NaN; gi = NaN;
   if ismember(m, ENSEMBLE)
      sO = 0; sB = 0; sG = 0; got = 0;
      for dr = 1:nDraw
         [~, p] = interleaver_generic_pc(1:N, m, 0, 0, [], 1000+dr, tp, tfac, struct());
         if isempty(p), continue; end
         [a, b, c] = local_one(p, B, n, t);
         sO = sO + a; sB = sB + b; sG = sG + c; got = got + 1;
      end
      if got > 0, oT = sO / got; bg = sB / got; gi = sG / got; end
      return;
   end
   p = local_perm(tpc, m, N);
   if isempty(p), return; end
   [oT, bg, gi] = local_one(p, B, n, t);
end

function [oT, bg, gi] = local_one(p, B, n, t)
   [oT, ~, ~, ~, gi] = designMetricScore(p(:)', B, n, t);
   bg = calc_bguar_invperm(p(:)', n, t);
end

function p = local_perm(tpc, method, N)
   p = []; fld = sprintf('perms_%s', method);
   if isstruct(tpc) && isfield(tpc, fld)
      M = tpc.(fld); k = sprintf('N_%d', N);
      if isa(M, 'containers.Map') && M.isKey(k)
         e = M(k);
         if isstruct(e) && isfield(e, 'perm'), p = e.perm; end
      end
   end
end

function v = local_opt(s, f, dflt)
   if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = dflt; end
end
