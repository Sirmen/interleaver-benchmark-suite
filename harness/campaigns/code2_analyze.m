%% code2_analyze.m
% After run_code2_sweeps: checks, in-scope restandardization and the Table 4
% statistics for one further campaign (TS_CODE2, see c2_spec).
%
%   >> clear functions; rehash; code2_analyze
%
% Order matters. Coverage and health first: a campaign that fails them is not
% quotable. restandardize_scope runs dry first, so its three self-checks are
% in the log before anything is rewritten; originals go to backup_scope.
% The scorecard, the design-cell file and the correlation_data files are
% copied to the log folder with the grid in their names, so two campaigns
% never overwrite each other there.
%
% R.T. Sirmen harness, 2026-11-17

clc;
global TS_CODE2 TS_GRID_MODE %#ok<GVMIS>
if isempty(TS_CODE2), c2g = 'code31'; else, c2g = char(TS_CODE2); end
c31Out = campaign_log_dir();
c31Log = fullfile(c31Out, sprintf('%s_analyze_%s.txt', c2g, datestr(now, 'yymmdd_HHMM')));
diary(c31Log); diary on;
try
   S2 = c2_spec();
   fprintf('=== %s analysis  %s ===\n', S2.grid, datestr(now));
   % 1. every method at every length, in every regime. check_length_coverage
   %    recognizes the published grids by their RS(15,9) message lengths, so
   %    for one-grid codes it gets the grid as 'expected'; for the n = 15
   %    codes, whose files hold two grids at another k, every file is checked
   %    here against the lengths and field of its own grid mode instead.
   if numel(S2.grids) == 1
      TS_GRID_MODE = S2.grids{1};
      [cfgA, ~] = configure_simulation();
      TS_GRID_MODE = [];
      check_length_coverage(S2.dir, struct('FECn', S2.n, 'FECk', S2.k, 'outDir', c31Out, ...
                            'expected', cfgA.sizeList));
   else
      covBad = 0;
      for gi = 1:numel(S2.grids)
         g = S2.grids{gi};
         TS_GRID_MODE = g;
         [cfgA, parA] = configure_simulation();
         TS_GRID_MODE = [];
         wantL = unique(ceil(cfgA.sizeList / cfgA.FECk) * cfgA.FECn);
         dk = dir(fullfile(S2.dir, sprintf('KPItableDetailed_*_%s_*.mat', g)));
         if numel(dk) ~= 4
            error('code2_analyze: %d KPItableDetailed files for %s, expected 4.', numel(dk), g);
         end
         for f = 1:numel(dk)
            Sk = load(fullfile(dk(f).folder, dk(f).name)); fk = fieldnames(Sk); Tk = [];
            for q = 1:numel(fk), if istable(Sk.(fk{q})), Tk = Sk.(fk{q}); break; end, end
            gotM = unique(string(Tk.method));
            okM = isequal(sort(gotM(:)), sort(string(parA.intMethods(:))));
            okL = true;
            for mi = 1:numel(parA.intMethods)
               Lm = unique(double(Tk.encodedLen(string(Tk.method) == string(parA.intMethods{mi}))));
               if ~isequal(Lm(:).', wantL(:).'), okL = false; end
            end
            fprintf('coverage %-40s %d methods, %d lengths  %s\n', dk(f).name, numel(gotM), numel(wantL), ...
                    char(string(okM && okL) + ""));
            if ~(okM && okL), covBad = covBad + 1; end
         end
      end
      if covBad > 0, error('code2_analyze: %d file(s) with a method or length hole.', covBad); end
   end

   % 2. method names into correlation_data, after the row-by-row check of
   %    add_method_names (row counts, anchors, names(methodID) == KPI.method,
   %    RES). Without them metric_scorecard maps methodID by sort order
   %    unverified, and validation_supplement skips every file.
   add_method_names(S2.dir);                               % dry run
   add_method_names(S2.dir, struct('apply', true));

   % 3. the blocking health checks of Supplementary Section S4 (4 conditions per grid mode)
   %    The verdict is written to the log and read there before any number
   %    is used; it does not stop the script, because H5 compares RES with
   %    the standardization it finds and the files may already be on the
   %    in-scope set from an earlier pass.
   H2 = health_check(S2.dir, struct('expectConditions', S2.nCond, 'runsPerCell', 35));
   fprintf('health verdict for %s: %s\n', S2.grid, H2.verdict);

   % 4. RES on the in-scope set, as for the published campaign. Once only:
   %    restandardize_scope writes KPI_SCOPE.txt when it applies, and a second
   %    pass would test its formula against already restandardized values.
   if exist(fullfile(S2.dir, 'KPI_SCOPE.txt'), 'file') == 2
      fprintf('restandardize_scope: already applied (KPI_SCOPE.txt present), not repeated\n');
   else
      restandardize_scope(S2.dir);                         % dry run
      restandardize_scope(S2.dir, struct('apply', true));
   end

   % 5. Table 4 statistics at this (n, t): writes scorecard_metrics.csv
   c2Table = find_table_dir();
   SC2 = metric_scorecard(S2.dir, struct('dataDir', c2Table, 'FECn', S2.n, 'FECt', S2.t)); %#ok<NASGU>

   % 6. the design-time statistics of the supplement readings
   R2 = validation_supplement(S2.dir, struct('tableDir', c2Table, 'FECn', S2.n, 'FECt', S2.t, ...
                              'exportCSV', fullfile(S2.dir, 'design_cells_supplement.csv'))); %#ok<NASGU>

   % 7. every design-time statistic per (method, length), esLoad and B_guar included
   %    At n = 15 the file name carries t, so design_cells_all_n15.csv (t = 3,
   %    the published campaign) is never overwritten.
   c2tag = S2.tag;
   export_design_cells_all(S2.dir, struct('FECn', S2.n, 'FECt', S2.t, 'tableDir', c2Table, 'tag', c2tag));

   % 8. copies in the log folder, named by grid
   for c2f = {'scorecard_metrics.csv', 'design_cells_supplement.csv', 'KPI_SCOPE.txt'}
      if exist(fullfile(S2.dir, c2f{1}), 'file') == 2
         copyfile(fullfile(S2.dir, c2f{1}), fullfile(c31Out, [S2.grid '_' c2f{1}]));
      end
   end
   c2cd = dir(fullfile(S2.dir, 'correlation_data_*.mat'));
   for k = 1:numel(c2cd), copyfile(fullfile(c2cd(k).folder, c2cd(k).name), c31Out); end
   fprintf('\n=== done. Outputs in %s\n', c31Out);

   c31_status([c2g '_analyze'], 'OK', c31Log);
catch c31ME
   fprintf(2, '\n*** code2_analyze FAILED ***\n%s\n', getReport(c31ME, 'extended', 'hyperlinks', 'off'));
   c31_status([c2g '_analyze'], 'FAILED', c31Log);
   diary off;
   rethrow(c31ME);
end
diary off;
