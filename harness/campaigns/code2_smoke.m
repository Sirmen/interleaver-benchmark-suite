%% code2_smoke.m
% End-to-end check of an extra-code campaign (TS_CODE2, see c2_spec) before
% it starts: for each of its grid modes one regime, the three smoke lengths
% the configure_simulation case yields, two runs, written to the smoke folder.
%
%   >> clear functions; rehash; code2_smoke
%
% Passes only if EVERY method of the field has rows at EVERY smoke length.
% A method refusing a length does not skip itself: it aborts the whole trial
% for every method (interleave_all_pc), so a hole here would become a missing
% length for the entire campaign.
%
% R.T. Sirmen harness, 2026-11-17

clc;
global TS_GRID_MODE TS_BURST_REGIME TS_SMOKE TS_CODE2 %#ok<GVMIS>
if isempty(TS_CODE2), c2g = 'code31'; else, c2g = char(TS_CODE2); end
c31Out = campaign_log_dir();
c31Log = fullfile(c31Out, sprintf('%s_smoke_%s.txt', c2g, datestr(now, 'yymmdd_HHMM')));
diary(c31Log); diary on;
try
   S2 = c2_spec();
   % The smoke folder is the one configure_simulation chooses when TS_SMOKE is set.
   TS_SMOKE = true; TS_GRID_MODE = S2.grids{1};
   cfgSmk = configure_simulation(); smokeDir = char(cfgSmk.dataSavePath);
   TS_SMOKE = []; TS_GRID_MODE = [];
   if ~exist(smokeDir, 'dir'), mkdir(smokeDir); end
   % One smoke run per grid mode of the campaign: at n = 15 the standards
   % grid is the one that carries arp, so it is smoked on its own.
   for sgi = 1:numel(S2.grids)
      sg = S2.grids{sgi};
      TS_GRID_MODE = sg;
      [cfgSm, parSm] = configure_simulation();
      TS_GRID_MODE = [];
      wantM = string(parSm.intMethods(:));
      wantL = ceil(cfgSm.sizeList([1 4 8]) / cfgSm.FECk) * cfgSm.FECn;
      smokeBefore = dir(fullfile(smokeDir, 'KPItableDetailed_*.mat'));
      smokeBefore = {smokeBefore.name};

      TS_SMOKE = true; TS_GRID_MODE = sg; TS_BURST_REGIME = 'multi';
      t0smoke = tic;
      main_simulation_wrapper;
      smokeSecs = toc(t0smoke);
      TS_SMOKE = []; TS_GRID_MODE = []; TS_BURST_REGIME = [];

      smokeAfter = dir(fullfile(smokeDir, 'KPItableDetailed_*.mat'));
      smokeNew = setdiff({smokeAfter.name}, smokeBefore);
      if isempty(smokeNew)
         error('code2_smoke: no new KPItableDetailed file in %s for %s. Scroll up for the error the wrapper printed.', smokeDir, sg);
      end
      smokeFile = fullfile(smokeDir, smokeNew{end});
      Ssm = load(smokeFile); vsm = fieldnames(Ssm); Tsm = Ssm.(vsm{1});
      if ~istable(Tsm), Tsm = struct2table(Tsm); end

      gotM = string(Tsm.method);
      gotL = Tsm.encodedLen;

      fprintf('\n=== %s smoke: %s (%.1f min) ===\n', sg, smokeNew{end}, smokeSecs/60);
      fprintf('code RS(%d,%d) t=%d, band [%.4f %.4f], lengths %s\n', cfgSm.FECn, cfgSm.FECk, ...
              cfgSm.FECt_correct, cfgSm.noiseLevels(1), cfgSm.noiseLevels(end), mat2str(wantL));
      if cfgSm.FECn ~= S2.n || cfgSm.FECk ~= S2.k || cfgSm.FECt_correct ~= S2.t
         error('code2_smoke: %s ran RS(%d,%d) t=%d, expected RS(%d,%d) t=%d.', sg, ...
               cfgSm.FECn, cfgSm.FECk, cfgSm.FECt_correct, S2.n, S2.k, S2.t);
      end
      holes = 0;
      for i = 1:numel(wantM)
         nPer = arrayfun(@(L) sum(gotM == wantM(i) & gotL == L), wantL);
         flag = '';
         if any(nPer == 0), flag = '   <-- HOLE'; holes = holes + 1; end
         fprintf('  %-14s %s%s\n', wantM(i), mat2str(nPer), flag);
      end
      extra = setdiff(unique(gotM), wantM);
      if ~isempty(extra), fprintf(2, '  unexpected methods: %s\n', strjoin(extra, ', ')); end
      if holes > 0 || ~isempty(extra)
         error('code2_smoke: %d method(s) with a hole on %s. Do not start the campaign.', holes, sg);
      end
      fprintf('SMOKE PASSED on %s: %d methods x %d lengths.\n', sg, numel(wantM), numel(wantL));
   end
   fprintf('\nNEXT: clear functions; rehash; run_code2_sweeps\n');

c31_status([c2g '_smoke'], 'OK', c31Log);
catch c31ME
   fprintf(2, '\n*** code2_smoke FAILED ***\n%s\n', getReport(c31ME, 'extended', 'hyperlinks', 'off'));
   c31_status([c2g '_smoke'], 'FAILED', c31Log);
   diary off;
   rethrow(c31ME);
end
diary off;
