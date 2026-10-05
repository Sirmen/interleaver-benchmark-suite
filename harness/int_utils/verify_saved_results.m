function verify_saved_results(dataSavePath, dateStr, regimeFilter, deep)
%VERIFY_SAVED_RESULTS  Check that a simulation run really landed on disk.
%
%   verify_saved_results(config.dataSavePath)              % today (auto)
%   verify_saved_results(config.dataSavePath, '260821')    % a specific day
%   verify_saved_results(config.dataSavePath, [], 'ge1p00')% one regime only
%   verify_saved_results(path, '260828')                   % yesterday's files
%   verify_saved_results(path, [], '', false)              % listing only, fast
%
% The date argument is OPTIONAL. Leave it out (or pass []) and today's date is
% used; if nothing was written today - a run that started before midnight and
% finished after it, say - the newest date present is used instead and the
% report says which one it picked. So the normal call is just:
%
%     verify_saved_results(config.dataSavePath)
%
% Answers "did the save work?" with evidence rather than a green tick:
%   * which regimes were written (single / multi / ge1p00 / ge0p70)
%   * which variables each regime produced, and their versions
%   * how many trial records are inside, and for which methods
%   * whether the 4 new interleavers are present
%   * whether burstConfig.realisedBurstInfo survived (the field the
%     validation/robustness pass needs)
%   * for GE runs: realised noise rate, burst structure, forced fraction
%   * whether the KPI fields (RES/CR/effectiveness) were merged back in
%
% Files are named  <var>_<regime>_<yymmdd>_<ver>.mat  by saveVars_YMD, and the
% variable inside is named  <var>_<regime>.
%
% R.T. Sirmen harness integration, 2026

   % deep = false skips loading the results_*.mat files. Those are 1-11 GB each
   % and loading eight of them to print an inventory is minutes of disk for
   % information the file listing already gives. The deep pass is what checks
   % trial counts, method lists, realisedBurstInfo and the merged KPI fields,
   % so run it deliberately - once, on the run you are about to quote - rather
   % than every time you want to see what is on disk.
   if nargin < 4 || isempty(deep), deep = true; end
   if nargin < 3, regimeFilter = ''; end
   if nargin < 2, dateStr = ''; end
   if nargin < 1 || isempty(dataSavePath)
      error('verify_saved_results: dataSavePath is required.');
   end

   fprintf('\n=== SAVE VERIFICATION ===\n');
   fprintf('path : %s\n', dataSavePath);

   if ~exist(dataSavePath, 'dir')
      fprintf('*** Directory does not exist. Nothing was saved.\n\n');
      return;
   end

   autoDate = isempty(dateStr);
   if autoDate, dateStr = datestr(now, 'yymmdd'); end

   allFiles = dir(fullfile(dataSavePath, sprintf('*_%s_*.mat', dateStr)));

   if isempty(allFiles) && autoDate
      % A run that crossed midnight writes under yesterday's stamp. Fall back
      % to the newest date actually present rather than reporting "nothing".
      everything = dir(fullfile(dataSavePath, '*.mat'));
      dates = {};
      for i = 1:numel(everything)
         tk = regexp(everything(i).name, '_(\d{6})_\d+\.mat$', 'tokens', 'once');
         if ~isempty(tk), dates{end+1} = tk{1}; end
      end
      if ~isempty(dates)
         dateStr = max(dates);
         if iscell(dateStr), dateStr = dateStr{1}; end
         allFiles = dir(fullfile(dataSavePath, sprintf('*_%s_*.mat', dateStr)));
         fprintf('note : nothing saved today, showing the newest date found\n');
      end
   end

   fprintf('date : %s\n', dateStr);
   if ~isempty(regimeFilter), fprintf('regime filter : %s\n', regimeFilter); end
   fprintf('\n');

   if isempty(allFiles)
      fprintf('*** No .mat files found. Check config.saveResults and dataSavePath.\n\n');
      return;
   end

   % ---- group files by regime suffix ------------------------------------
   regimes = {};
   for i = 1:numel(allFiles)
      r = local_regimeOf(allFiles(i).name, dateStr);
      if ~isempty(r) && ~any(strcmp(regimes, r)), regimes{end+1} = r; end
   end
   regimes = sort(regimes);
   if ~isempty(regimeFilter)
      regimes = regimes(strcmp(regimes, regimeFilter));
      if isempty(regimes)
         fprintf('*** No files for regime "%s" on %s.\n\n', regimeFilter, dateStr);
         return;
      end
   end

   fprintf('%-18s %-6s %-9s %s\n', 'REGIME_GRID', 'FILES', 'TOTAL MB', 'VARIABLES');
   fprintf('%s\n', repmat('-', 1, 78));
   for i = 1:numel(regimes)
      idx = arrayfun(@(f) strcmp(local_regimeOf(f.name, dateStr), regimes{i}), allFiles);
      fs  = allFiles(idx);
      vars = unique(cellfun(@(n) local_varOf(n, regimes{i}, dateStr), {fs.name}, 'UniformOutput', false));
      fprintf('%-18s %-6d %-9.2f %s\n', regimes{i}, numel(fs), sum([fs.bytes])/1e6, strjoin(vars, ', '));
   end

   % ---- inspect the results_* file of each regime ------------------------
   if ~deep
      fprintf(['\n  (listing only - pass deep = true to load each results_*.mat and\n' ...
               '   check trial counts, method lists, realisedBurstInfo and KPI merge)\n']);
      fprintf('=== END ===\n\n');
      return;
   end
   for i = 1:numel(regimes)
      reg = regimes{i};
      pat = sprintf('results_%s_%s_*.mat', reg, dateStr);
      rf  = dir(fullfile(dataSavePath, pat));
      fprintf('\n--------------------------------------------------------------\n');
      fprintf('RUN: %s\n', reg);
      if isempty(rf)
         fprintf('  *** no results_%s_* file - the run did not reach save_results\n', reg);
         continue;
      end
      [~, newest] = max([rf.datenum]);
      fname = fullfile(dataSavePath, rf(newest).name);
      fprintf('  file : %s  (%.2f MB, %d version(s) today)\n', ...
              rf(newest).name, rf(newest).bytes/1e6, numel(rf));

      S = load(fname);
      fn = fieldnames(S);
      R  = S.(fn{1});

      if ~isfield(R, 'stats_all') || isempty(R.stats_all)
         fprintf('  *** stats_all missing or empty\n');
         continue;
      end
      sa = R.stats_all;
      fprintf('  trial records : %d\n', numel(sa));

      methods = unique({sa.method});
      fprintf('  methods (%d)   : %s\n', numel(methods), strjoin(methods, ', '));
      wanted = {'srandom','goldenRP','drp','arp'};
      miss = wanted(~ismember(wanted, methods));
      if isempty(miss)
         fprintf('  new methods   : all 4 present\n');
      else
         fprintf('  new methods   : MISSING %s\n', strjoin(miss, ', '));
      end

      % --- the field the robustness pass needs ---
      if ~isfield(sa(1), 'burstConfig')
         fprintf('  *** burstConfig not stored per trial\n');
      elseif ~isfield(sa(1).burstConfig, 'realisedBurstInfo')
         fprintf('  *** burstConfig.realisedBurstInfo MISSING - patched\n');
         fprintf('      run_simulations_sci.m not installed?\n');
      else
         fprintf('  realisedBurstInfo : present on trial 1\n');
         nOK = sum(arrayfun(@(s) isfield(s.burstConfig, 'realisedBurstInfo'), sa));
         fprintf('  realisedBurstInfo : present on %d / %d trials\n', nOK, numel(sa));

         bi = arrayfun(@(s) s.burstConfig.realisedBurstInfo, sa);
         fprintf('  burst count   : mean %.2f  (min %d, max %d)\n', ...
                 mean([bi.burstCount]), min([bi.burstCount]), max([bi.burstCount]));
         fprintf('  total errors  : mean %.1f\n', mean([bi.totalErrors]));

         if isfield(bi(1), 'realisedRate')       % Gilbert-Elliott only
            fprintf('  --- Gilbert-Elliott ---\n');
            fprintf('  e_B           : %.2f\n', bi(1).e_B);
            fprintf('  realised rate : mean %.4f  (min %.4f, max %.4f)\n', ...
                    mean([bi.realisedRate]), min([bi.realisedRate]), max([bi.realisedRate]));
            fprintf('  mean burstLen : %.2f   max burstLen: %d\n', ...
                    mean([bi.meanBurstLen_realised]), max([bi.maxBurstLen]));
            fprintf('  draws         : mean %.2f\n', mean([bi.draws]));
            fprintf('  FORCED into band : %.1f%% of trials  <-- report this\n', ...
                    100 * mean([bi.forced]));
         end
      end

      % --- did calcKPIs merge its columns back in? ---
      kpi = {'RES','CR','effectiveness'};
      have = kpi(ismember(kpi, fieldnames(sa(1))));
      if numel(have) == numel(kpi)
         v = [sa.RES];
         fprintf('  KPI fields    : %s   (RES mean %.4f, %d NaN)\n', ...
                 strjoin(have, ', '), mean(v(~isnan(v))), sum(isnan(v)));
      else
         fprintf('  KPI fields    : only %s  - calcKPIs ran before save?\n', strjoin(have, ', '));
      end
   end

   fprintf('\n=== END ===\n\n');
end

%% ------------------------------------------------------------------------
function r = local_regimeOf(name, dateStr)
% Returns the run tag: '<regime>' for old names, '<regime>_<grid>' for new ones.
%
%   results_ge1p00_260821_1.mat          -> 'ge1p00'
%   results_ge1p00_common_260829_1.mat   -> 'ge1p00_common'
%
% THIS USED TO TAKE THE SINGLE TOKEN BEFORE THE DATE, which was right while the
% name was <var>_<regime>_<date>_<n>. Once save_results started appending the
% grid, that token became the GRID: the summary table listed 'common' in its
% REGIME column and the results-file lookup then searched for
% results_common_*.mat, which never exists. The run had saved perfectly and the
% verifier reported "the run did not reach save_results" - a false alarm on
% every sweep, and exactly the kind that trains you to ignore the verifier.
   r = '';
   % SINGLE backslash. MATLAB does not process escapes in single-quoted
   % strings, and REG is passed to sprintf as an ARGUMENT, not as the format -
   % so '\\d' would reach regexp as a literal backslash followed by 'd' and
   % never match. Only the format string itself needs '\\d'.
   %
   % With '\\d' here, 'ge1p00' and 'ge0p70' matched nothing, both patterns
   % fell through, those four files were assigned no regime at all, and the
   % summary silently listed only the two runs whose tags happen to contain no
   % digits (single, multi). Six sweeps on disk, two in the report.
   REG = 'single|multi|ge\d+p\d+';
   GRD = 'common|standards|probe|legacy';

   tok = regexp(name, sprintf('^.+?_(%s)_(%s)_%s_\\d+\\.mat$', REG, GRD, dateStr), ...
                'tokens', 'once');
   if ~isempty(tok)
      r = [tok{1} '_' tok{2}];
      return;
   end

   tok = regexp(name, sprintf('^.+?_(%s)_%s_\\d+\\.mat$', REG, dateStr), 'tokens', 'once');
   if ~isempty(tok), r = tok{1}; end
end

function v = local_varOf(name, regime, dateStr)
% results_ge1p00_common_260829_1.mat, tag 'ge1p00_common' -> 'results'
% The tag now may contain an underscore, so it is escaped before use as a
% pattern rather than interpolated raw.
   v = '';
   tok = regexp(name, sprintf('^(.+?)_%s_%s_\\d+\\.mat$', regexptranslate('escape', regime), dateStr), ...
                'tokens', 'once');
   if ~isempty(tok), v = tok{1}; end
end
