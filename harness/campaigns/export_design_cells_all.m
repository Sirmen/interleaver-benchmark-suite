function outCsv = export_design_cells_all(resultsDir, opts)
%EXPORT_DESIGN_CELLS_ALL  Every design-time statistic per (method, length), as CSV.
%
%   export_design_cells_all('<resultsDir>')
%   export_design_cells_all('<campaigns>/code31', struct('FECn', 31, 'FECt', 5))
%
% design_cells_v2.csv, released with the campaign data, carries six columns
% and lacks esLoad and B_guar, so two recommended metrics of Table 4 could not
% be rescored from the released files alone. This writes all of them, with
% the SAME calls metric_scorecard makes (local_allStats / local_detStats,
% copied below, and the same ensemble draws for the two methods redrawn per
% frame), so a value here is the value metric_scorecard correlated:
%
%   overT, maxErrCW, meanMaxCW, cvLoad, giniLoad, esLoad   at every B in Bset
%   B_guar, dispersion, Snew, S_ach, adjDispersion         one column each
%
% Lengths and methods are read from the KPItableDetailed files of the folder,
% so the cells are exactly the campaign's. Written to
% <resultsDir>\design_cells_all_n<FECn>.csv.
%
% R.T. Sirmen harness, 2026-11-17

   if nargin < 2, opts = struct(); end
   % Log to the campaign log folder unless a caller already keeps a diary
   % (code2_analyze does; switching the diary file here would cut its log in two).
   logDir = campaign_log_dir();
   ownDiary = strcmp(get(0, 'Diary'), 'off');
   logFile = '';
   if ownDiary
      logFile = fullfile(logDir, sprintf('export_design_cells_all_%s.txt', datestr(now, 'yymmdd_HHMM')));
      diary(logFile); diary on;
      cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>
   end
   n     = local_opt(opts, 'FECn', 15);
   t     = local_opt(opts, 'FECt', 3);
   Bset  = local_opt(opts, 'Bset', n * [1 2 4 8 12 16 24]);
   nDraw = local_opt(opts, 'nDraw', 15);
   ENSEMBLE = {'random', 'freqRandom'};
   STATS = {'overT','maxErrCW','meanMaxCW','cvLoad','giniLoad','esLoad'};
   DET   = {'B_guar','dispersion','Snew','S_ach','adjDispersion'};

   tableDir = local_opt(opts, 'tableDir', '');
   if isempty(tableDir), tableDir = find_table_dir(); end
   [tpc, erT] = PrecomputedInterleaverLoader(char(tableDir));
   if erT ~= "", error('export_design_cells_all: %s', erT); end
   [tp, tfac, erP] = PrimeFactorLoader(char(tableDir));
   if erP ~= "", tp = []; tfac = struct(); end

   d = dir(fullfile(resultsDir, 'KPItableDetailed_*.mat'));
   if isempty(d), error('export_design_cells_all: no KPItableDetailed_*.mat in %s', resultsDir); end
   M = strings(0, 1); Lx = zeros(0, 1);
   for i = 1:numel(d)
      S = load(fullfile(d(i).folder, d(i).name)); fn = fieldnames(S); T = [];
      for k = 1:numel(fn), if istable(S.(fn{k})), T = S.(fn{k}); break; end, end
      if isempty(T), continue; end
      M  = [M;  string(T.method)];      %#ok<AGROW>
      Lx = [Lx; double(T.encodedLen)];  %#ok<AGROW>
   end
   [~, ia] = unique(strcat(M, '_', string(Lx)));
   M = M(ia); Lx = Lx(ia);
   fprintf('export_design_cells_all: %d cells, n = %d, t = %d, B = %s\n', numel(M), n, t, mat2str(Bset));

   hdr = {'method', 'encodedLen'};
   for k = 1:numel(STATS)
      for b = 1:numel(Bset), hdr{end+1} = sprintf('%s_B%d', STATS{k}, Bset(b)); end %#ok<AGROW>
   end
   hdr = [hdr, DET];
   nV = numel(STATS)*numel(Bset) + numel(DET);
   V = nan(numel(M), nV);
   for k = 1:numel(M)
      mn = char(M(k)); N = Lx(k);
      if ismember(mn, ENSEMBLE)
         acc = zeros(1, nV); got = 0;
         for dr = 1:nDraw
            [~, p] = interleaver_generic_pc(1:N, mn, 0, 0, [], 1000+dr, tp, tfac, struct());
            if isempty(p), continue; end
            acc = acc + [local_allStats(p, Bset, n, t, numel(STATS)), local_detStats(p, n, t, numel(DET))];
            got = got + 1;
         end
         if got > 0, V(k, :) = acc / got; end
      else
         p = local_perm(tpc, mn, N);
         if isempty(p), fprintf(2, '  no permutation for %s at %d\n', mn, N); continue; end
         V(k, :) = [local_allStats(p, Bset, n, t, numel(STATS)), local_detStats(p, n, t, numel(DET))];
      end
      if mod(k, 100) == 0, fprintf('  %d / %d\n', k, numel(M)); end
   end

   % opts.tag is appended to the name (e.g. '_t2'), so campaigns at the same
   % n but another t do not overwrite each other's file.
   outCsv = fullfile(resultsDir, sprintf('design_cells_all_n%d%s.csv', n, local_opt(opts, 'tag', '')));
   fid = fopen(outCsv, 'w');
   fprintf(fid, '%s\n', strjoin(hdr, ','));
   for k = 1:numel(M)
      fprintf(fid, '%s,%d', M(k), Lx(k));
      fprintf(fid, ',%.10g', V(k, :));
      fprintf(fid, '\n');
   end
   fclose(fid);
   fprintf('wrote %s\n', outCsv);
   copyfile(outCsv, logDir);
   fprintf('copied to %s\n', logDir);
   if ownDiary, c31_status(sprintf('export_cells_n%d', n), 'OK', logFile); end
end

function v = local_allStats(p, Bset, n, t, nStat)
% Copied from metric_scorecard: the same calls in the same slots.
   nB = numel(Bset); v = nan(1, nStat*nB);
   for b = 1:nB
      [oT, mx, mm, cv, gi] = designMetricScore(p, Bset(b), n, t);
      v(0*nB+b) = oT; v(1*nB+b) = mx; v(2*nB+b) = mm; v(3*nB+b) = cv; v(4*nB+b) = gi;
      v(5*nB+b) = calc_esload_invperm(p, Bset(b), n);
   end
end

function v = local_detStats(p, n, t, nDet)
% Copied from metric_scorecard: the order ties each value to its name.
   v = nan(1, nDet);
   v(1) = calc_bguar_invperm(p, n, t);
   v(2) = calc_dispersion_invperm(p);
   v(3) = calc_snew_invperm(p);
   v(4) = calc_srandom_spread_invperm(p);
   v(5) = calc_adjdispersion_invperm(p);
end

function p = local_perm(tpc, method, N)
   p = []; fld = sprintf('perms_%s', method);
   if isstruct(tpc) && isfield(tpc, fld)
      Mp = tpc.(fld); k = sprintf('N_%d', N);
      if isa(Mp, 'containers.Map') && Mp.isKey(k)
         e = Mp(k); if isstruct(e) && isfield(e, 'perm'), p = e.perm; end
      end
   end
end

function v = local_opt(s, f, dflt)
   if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = dflt; end
end
