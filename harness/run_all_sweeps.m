%% run_all_sweeps.m
% Runs the eight full sweeps in order: two grids x four burst regimes.
%
%   >> run_all_sweeps
%
% WHY A DRIVER RATHER THAN EIGHT MANUAL EDITS
% -------------------------------------------------------------------------
% Eight runs means eight edits to configure_simulation.m, and one mistyped
% selector produces a results file whose name says one thing and whose
% contents are another. That failure is invisible until the analysis, which
% is exactly the kind of thing this project has already paid for once.
%
% The two selectors in configure_simulation.m now consult globals:
%       TS_GRID_MODE, TS_BURST_REGIME
% and fall back to their hard-coded values when the globals are empty. So
% running configure_simulation by hand behaves exactly as before, and this
% driver sets them per iteration.
%
% BEFORE YOU START
%   * verify_setup must report ALL CHECKS PASSED
%   * config.saveResults = true, config.plotResults = false
%   * the Simulation Overrides block at the end of configure_simulation.m
%     must stay commented out - it runs AFTER the grid selector and would
%     overwrite it
%
% HOW A FAILED SWEEP IS DETECTED  (the old comment here was wrong)
% -------------------------------------------------------------------------
% This header used to claim "main_simulation_wrapper returns on error, so the
% loop stops with it". Neither half holds:
%
%   * the wrapper's whole body sits in try/catch and the catch PRINTS the
%     error without rethrowing, so nothing propagates out of it;
%   * `return` inside a SCRIPT called from another script returns to the
%     invoking script - the loop below just continues to the next regime.
%
% So a crashed sweep saved no file, still reached `nDone = nDone + 1`, and the
% batch reported "8 of 8 sweeps" with seven files on disk. Exactly the silent
% gap the comment claimed to prevent.
%
% The loop now counts .mat files in the results folder before and after each
% sweep and marks the sweep OK only if a new one actually landed. Any sweep
% that produced nothing is named in the tally at the end.
%
% Data isolation between regimes is NOT at risk here: run_simulations_sci is a
% FUNCTION whose `results` is an output, not an input, and it opens with
% `results = initResults` - stats_all starts empty every regime and the return
% value replaces the caller's copy wholesale.
%
% RESUMING AFTER A CRASH
% -------------------------------------------------------------------------
% Set START_AT to the number of the first sweep you want to run. The sweeps
% are numbered in the order printed by the tally:
%
%       1  common/multi        5  standards/multi
%       2  common/single       6  standards/single
%       3  common/ge1p00       7  standards/ge1p00
%       4  common/ge0p70       8  standards/ge0p70
%
% So after a crash that completed the first two, set START_AT = 3. Skipped
% sweeps are listed as 'skipped' in the tally so the log stays honest about
% what this invocation did and did not run.
%
% THE RESULTS FILE NAMES DO NOT RECORD THE GRID
% -------------------------------------------------------------------------
% save_results names files <var>_<regime>_<YYMMDD>_<n>.mat, and the regime tag
% comes from burstRegimeTag, which knows nothing about the grid. Run both grids
% on the same day and 'common/multi' and 'standards/multi' differ only by the
% _1 / _2 counter - unrecoverable from the filename alone.
%
% Rather than change the save path naming mid-campaign (which would make the
% files already on disk inconsistent with the ones still to come), this driver
% appends a line to sweep_manifest.txt in the results folder recording, for
% each sweep, the grid, the regime, and every file that appeared while it ran.
% That is the mapping the analysis needs, and it is written incrementally so a
% crash cannot lose the sweeps that already finished.
%
% MEMORY
% -------------------------------------------------------------------------
% main_simulation_wrapper is a script, so its `results` struct - the largest
% object in the run - stays in this workspace after each sweep and is still
% resident while the next one builds its own. The heavy variables are cleared
% between sweeps below. If MATLAB still runs out of memory, run one grid per
% invocation rather than both.
%
% Expect roughly: common ~2 min per regime, standards ~20 s per regime.
% Disk: about 8 GB per common regime at testRunsMax = 35.
%
% R.T. Sirmen harness, 2026-08

clc;

global TS_GRID_MODE TS_BURST_REGIME %#ok<GVMIS>

% ---- resume point: 1 runs everything, 3 resumes after two finished sweeps --
START_AT = 1;

grids   = {'common', 'standards'};
regimes = {'multi', 'single', 'ge1p00', 'ge0p70'};

nDone = 0;
nPlan = numel(grids) * numel(regimes);
t0all = tic;
% Deliberately NOT called `log`: this script and main_simulation_wrapper share
% one workspace, so a variable named `log` shadows MATLAB's log() for every
% script-level line that runs afterwards.
sweepLog = cell(0, 4);

% Results folder, read once. configure_simulation runs here with the globals
% still empty, so it falls back to its own selectors - we want only the path.
cfgPath  = configure_simulation();
savePath = char(cfgPath.dataSavePath);
dBefore     = dir(fullfile(savePath, '*.mat'));
filesBefore = {dBefore.name};
manifest = fullfile(savePath, 'sweep_manifest.txt');
fprintf('  results folder: %s\n  (%d .mat already present)\n', savePath, numel(filesBefore));
fprintf('  manifest:       %s\n', manifest);

fprintf('\n=================================================================\n');
fprintf('  SWEEP PLAN: %d total, starting at %d\n', nPlan, START_AT);
fprintf('=================================================================\n');

for gi = 1:numel(grids)
   for ri = 1:numel(regimes)

      idx = (gi - 1) * numel(regimes) + ri;

      if idx < START_AT
         fprintf('  sweep %d/%d  %s/%s  -- skipped (START_AT = %d)\n', ...
                 idx, nPlan, grids{gi}, regimes{ri}, START_AT);
         sweepLog(end+1, :) = {grids{gi}, regimes{ri}, 0, 'skipped'}; %#ok<SAGROW>
         continue;
      end

      TS_GRID_MODE    = grids{gi};
      TS_BURST_REGIME = regimes{ri};

      fprintf('\n\n#################################################################\n');
      fprintf('###  SWEEP %d/%d :  grid = %-10s  regime = %s\n', ...
              idx, nPlan, TS_GRID_MODE, TS_BURST_REGIME);
      fprintf('#################################################################\n');

      tSweep = tic;
      main_simulation_wrapper;                 %#ok<*NASGU>
      secs = toc(tSweep);

      % Did this sweep actually write anything? The wrapper cannot tell us -
      % it swallows its own errors - so ask the filesystem. Taking the set
      % difference rather than a count also gives us the file names, which is
      % what the manifest needs since the names do not record the grid.
      dAfter     = dir(fullfile(savePath, '*.mat'));
      filesAfter = {dAfter.name};
      newFiles   = setdiff(filesAfter, filesBefore);
      filesBefore = filesAfter;
      okThis     = ~isempty(newFiles);
      % No local helper function: this is a script, and a local function here
      % would not be visible to main_simulation_wrapper.
      if okThis, statusStr = 'ok'; else, statusStr = 'FAILED'; end

      % Manifest: append immediately, so a crash keeps what already ran.
      try
         fid = fopen(manifest, 'a');
         if fid > 0
            fprintf(fid, '%s  sweep %d  grid=%-10s regime=%-7s  %6.1f s  %s\n', ...
                    datestr(now, 'yyyy-mm-dd HH:MM:SS'), idx, grids{gi}, regimes{ri}, ...
                    secs, upper(statusStr));
            for k = 1:numel(newFiles)
               fprintf(fid, '        %s\n', newFiles{k});
            end
            fclose(fid);
         end
      catch MEm
         fprintf(2, '  (manifest not written: %s)\n', MEm.message);
      end

      if okThis
         nDone = nDone + 1;
         fprintf('\n###  done in %.1f s  (%d files written)\n', secs, numel(newFiles));
      else
         fprintf(2, '\n###  *** NO FILE SAVED for %s/%s - this sweep FAILED (%.1f s)\n', ...
                 grids{gi}, regimes{ri}, secs);
         fprintf(2, '###      scroll up for the error the wrapper printed.\n');
      end
      sweepLog(end+1, :) = {grids{gi}, regimes{ri}, secs, statusStr}; %#ok<SAGROW>

      % Free the heavy objects before the next sweep builds its own. `results`
      % alone can be several GB at testRunsMax = 35; leaving it resident while
      % the next sweep allocates is how this batch ran out of memory.
      clear('results', 'anovaResults', 'corrResults', 'correlation_data', ...
            'crossCorrResults', 'KPItableSummary', 'KPItableDetailed', ...
            'selectedMethods', 'burstConfig', 'dAfter', 'filesAfter');
   end
end

% Leave the globals empty so a later manual run reads configure_simulation's
% own selectors again - a stale global is a silent trap.
TS_GRID_MODE = []; TS_BURST_REGIME = [];

nAttempted = nPlan - (START_AT - 1);

fprintf('\n\n=================================================================\n');
fprintf('  BATCH DONE : %d of %d attempted sweeps saved, %.1f min total\n', ...
        nDone, nAttempted, toc(t0all)/60);
if START_AT > 1
   fprintf('  (sweeps 1..%d were skipped by START_AT and are NOT counted)\n', START_AT - 1);
end
fprintf('=================================================================\n');
for i = 1:size(sweepLog, 1)
   fprintf('  %d  %-10s %-8s %8.1f s   %s\n', i, sweepLog{i,1}, sweepLog{i,2}, sweepLog{i,3}, sweepLog{i,4});
end
nFailed = sum(strcmp(sweepLog(:,4), 'FAILED'));
if nFailed > 0
   fprintf(2, '\n  *** %d sweep(s) saved NO results file:\n', nFailed);
   for i = 1:size(sweepLog, 1)
      if strcmp(sweepLog{i,4}, 'FAILED')
         fprintf(2, '        sweep %d : %s / %s\n', i, sweepLog{i,1}, sweepLog{i,2});
      end
   end
   fprintf(2, '      Do not analyse this batch until you know why.\n');
end
fprintf('\n  File-to-grid mapping was appended to:\n    %s\n', manifest);
fprintf('\n  Next: verify the saved files, then generate figures in a CLEAN\n');
fprintf('  session from the saved tables (config.plotResults stays false here).\n\n');
