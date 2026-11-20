%% run_code2_sweeps.m
% One extra-code campaign of the metric validation (TS_CODE2, see c2_spec):
% one sweep per burst regime on each grid mode of the campaign. code31 and
% code24 run one grid with the common field (25 methods, arp excluded);
% c15t2 and c15t4 run the common grid and then the standards grid, where arp
% joins the field (26 methods).
%
%   >> clear functions; rehash; run_code2_sweeps
%
% run_all_sweeps stays as it is: it is the driver of the primary campaign.
%
% BEFORE YOU START: code2_build_table and code2_smoke have passed for this
% grid, TS_SMOKE is empty, and the grid's results folder is empty (or holds
% only the regimes before TS_CODE2_START, on a resume).
%
% RES, CR_z and BE_z come out standardised over EVERY row of a sweep;
% code2_analyze puts them on the in-scope set before any correlation.
%
% R.T. Sirmen harness, 2026-11-17

clc;
global TS_GRID_MODE TS_BURST_REGIME TS_SMOKE TS_CODE2 TS_CODE2_START %#ok<GVMIS>
if isempty(TS_CODE2), c2g = 'code31'; else, c2g = char(TS_CODE2); end
c31Out = campaign_log_dir();
c31Log = fullfile(c31Out, sprintf('%s_sweeps_%s.txt', c2g, datestr(now, 'yymmdd_HHMM')));
diary(c31Log); diary on;
try
   S2 = c2_spec();

   REGIMES = {'multi', 'single', 'ge1p00', 'ge0p70'};
   % Every (grid mode, regime) pair of the campaign, grids outer, as
   % run_all_sweeps orders the published campaign. TS_CODE2_START indexes
   % this list (1..4 for one grid, 1..8 for two).
   [gIdx, rIdx] = meshgrid(1:numel(S2.grids), 1:numel(REGIMES));
   % reshape to rows: a one-grid campaign has a 1x1 S2.grids, and indexing a
   % scalar cell by a column returns a column (vertcat failed on code24).
   SWEEPS = [reshape(S2.grids(gIdx(:)), 1, []); reshape(REGIMES(rIdx(:)), 1, [])].';
   if isempty(TS_CODE2_START), START_AT = 1; else, START_AT = TS_CODE2_START; end

   if ~isempty(TS_SMOKE) && TS_SMOKE
      error('run_code2_sweeps: TS_SMOKE is still set. Clear it: TS_SMOKE = [];');
   end

   % Every grid mode is checked before the first sweep, so a wrong setting
   % in the second grid does not surface hours into the run.
   for gi = 1:numel(S2.grids)
      g = S2.grids{gi};
      TS_GRID_MODE = g;
      [cfg, c31Par] = configure_simulation();
      TS_GRID_MODE = [];
      savePath = char(cfg.dataSavePath);
      if ~strcmp(cfg.gridMode, g), error('run_code2_sweeps: gridMode is %s, not %s', cfg.gridMode, g); end
      if cfg.FECn ~= S2.n || cfg.FECk ~= S2.k || cfg.FECt_correct ~= S2.t
         error('run_code2_sweeps: %s is RS(%d,%d) t=%d, expected RS(%d,%d) t=%d.', g, cfg.FECn, cfg.FECk, cfg.FECt_correct, S2.n, S2.k, S2.t);
      end
      if ~strcmpi(savePath, S2.dir)
         error('run_code2_sweeps: %s saves to %s, not %s. Refusing.', g, savePath, S2.dir);
      end
      if any(strcmp(c31Par.intMethods, 'arp')) ~= any(strcmp(S2.arpGrids, g))
         error('run_code2_sweeps: arp in the field of %s contradicts c2_spec.', g);
      end
      fprintf('\n  %s: RS(%d,%d) t=%d  eccReal %.5f  band [%.4f %.4f]  %d lengths  %d methods\n', g, ...
              cfg.FECn, cfg.FECk, cfg.FECt_correct, cfg.eccReal, cfg.noiseLevels(1), cfg.noiseLevels(end), ...
              numel(cfg.sizeList), numel(c31Par.intMethods));
      fprintf('     lengths %s\n', mat2str(unique(ceil(cfg.sizeList/cfg.FECk)*cfg.FECn)));
   end

   dBefore = dir(fullfile(savePath, '*.mat')); filesBefore = {dBefore.name};
   manifest = fullfile(savePath, ['sweep_manifest_' S2.grid '.txt']);

   fprintf('\n=================================================================\n');
   fprintf('  EXTRA-CODE CAMPAIGN  -  %s, %d sweeps (from %d)\n', upper(S2.grid), size(SWEEPS, 1), START_AT);
   fprintf('=================================================================\n');
   fprintf('  runs %d x noise bins %d per cell\n', cfg.testRunsMax, cfg.noiseBins);
   fprintf('  results   %s\n', savePath);
   if numel(filesBefore) > 0 && START_AT == 1
      fprintf(2, '  *** %d .mat already in the folder on a FRESH run. They would be pooled.\n', numel(filesBefore));
      fprintf(2, '  *** Move them aside, or set TS_CODE2_START for a resume.\n');
      error('run_code2_sweeps: folder not empty');
   end

   nDone = 0; t0all = tic; sweepLog = cell(0, 3);
   for ri = 1:size(SWEEPS, 1)
      gNow = SWEEPS{ri, 1}; rNow = SWEEPS{ri, 2};
      if ri < START_AT
         sweepLog(end+1, :) = {[gNow '/' rNow], 0, 'skipped'}; %#ok<SAGROW>
         continue;
      end
      TS_GRID_MODE    = gNow;            % reasserted every sweep
      TS_BURST_REGIME = rNow;
      fprintf('\n#################################################################\n');
      fprintf('###  SWEEP %d/%d :  grid = %s   regime = %s   %s\n', ri, size(SWEEPS, 1), gNow, ...
              rNow, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
      fprintf('#################################################################\n');
      tSweep = tic;
      main_simulation_wrapper;           %#ok<*NASGU>
      secs = toc(tSweep);

      dAfter = dir(fullfile(savePath, '*.mat')); filesAfter = {dAfter.name};
      newFiles = setdiff(filesAfter, filesBefore); filesBefore = filesAfter;
      if isempty(newFiles), statusStr = 'FAILED'; else, statusStr = 'ok'; nDone = nDone + 1; end
      fid = fopen(manifest, 'a');
      if fid > 0
         fprintf(fid, '%s  sweep %d  grid=%s  regime=%-7s  %7.1f s  %s\n', ...
                 datestr(now, 'yyyy-mm-dd HH:MM:SS'), ri, gNow, rNow, secs, upper(statusStr));
         for k = 1:numel(newFiles), fprintf(fid, '        %s\n', newFiles{k}); end
         fclose(fid);
      end
      if strcmp(statusStr, 'FAILED')
         fprintf(2, '\n###  *** NO FILE SAVED for %s/%s - scroll up for the error.\n', gNow, rNow);
      else
         fprintf('\n###  done in %.1f min  (%d files)\n', secs/60, numel(newFiles));
      end
      sweepLog(end+1, :) = {[gNow '/' rNow], secs, statusStr}; %#ok<SAGROW>
      clear('results', 'anovaResults', 'corrResults', 'correlation_data', 'crossCorrResults', ...
            'KPItableSummary', 'KPItableDetailed', 'selectedMethods', 'burstConfig');
   end
   TS_GRID_MODE = []; TS_BURST_REGIME = [];

   fprintf('\n=================================================================\n');
   fprintf('  CAMPAIGN DONE : %d sweep(s) saved, %.1f min\n', nDone, toc(t0all)/60);
   for i = 1:size(sweepLog, 1)
      fprintf('  %-16s %8.1f s   %s\n', sweepLog{i,1}, sweepLog{i,2}, sweepLog{i,3});
   end
   if any(strcmp(sweepLog(:,3), 'FAILED'))
      fprintf(2, '  *** a sweep saved nothing: do not analyse this batch until you know why.\n');
   else
      fprintf('\nNEXT: clear functions; rehash; code2_analyze\n');
   end
   fprintf('  manifest : %s\n', manifest);
   if any(strcmp(sweepLog(:,3), 'FAILED')), error('run_code2_sweeps: a sweep saved nothing'); end
   copyfile(manifest, c31Out);
c31_status([c2g '_sweeps'], 'OK', c31Log);
catch c31ME
   fprintf(2, '\n*** run_code2_sweeps FAILED ***\n%s\n', getReport(c31ME, 'extended', 'hyperlinks', 'off'));
   c31_status([c2g '_sweeps'], 'FAILED', c31Log);
   diary off;
   rethrow(c31ME);
end
diary off;
