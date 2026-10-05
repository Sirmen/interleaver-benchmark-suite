function tag_legacy_results(dataPath, gridTag, doIt)
%TAG_LEGACY_RESULTS  Insert a grid tag into result files saved before save_results carried one.
%
%   tag_legacy_results(path, 'common')          % DRY RUN - prints the plan only
%   tag_legacy_results(path, 'common', true)    % actually renames
%
% WHY
% -------------------------------------------------------------------------
% save_results used to name files
%       <var>_<regime>_<YYMMDD>_<n>.mat
% and the regime tag alone does not say which length grid the run used. It now
% writes
%       <var>_<regime>_<grid>_<YYMMDD>_<n>.mat
% This function brings files written before that change into the new scheme so
% one results folder does not hold two naming conventions.
%
% It is NOT a bulk renamer. It refuses anything it is not certain about:
%
%   * a file that already carries a known grid tag is skipped;
%   * a file whose name does not match the exact expected pattern is skipped
%     and reported, never guessed at;
%   * a rename whose target already exists is refused, not overwritten.
%
% Every sweep writes nine or ten variables, so two completed regimes are about
% twenty files. Renaming them by hand is how one gets missed, and a single file
% left with the old name is worse than none renamed - it will be picked up by
% the fallback heuristic and silently labelled with whichever grid the guess
% happens to produce.
%
% DRY RUN IS THE DEFAULT. Read the plan, then re-run with doIt = true.
%
% R.T. Sirmen harness, 2026-08

   if nargin < 3 || isempty(doIt), doIt = false; end
   if nargin < 2 || isempty(gridTag), error('tag_legacy_results: give a grid tag, e.g. ''common'''); end

   dataPath = char(dataPath);
   gridTag  = regexprep(char(gridTag), '[^A-Za-z0-9]', '');
   if isempty(gridTag), error('tag_legacy_results: grid tag is empty after cleaning'); end

   KNOWN_GRIDS   = {'common', 'standards', 'probe', 'legacy'};
   KNOWN_REGIMES = {'single', 'multi', 'ge1p00', 'ge0p70'};

   % Not just .mat: saveCrossCorrelationResults writes .txt under the same
   % ambiguous scheme, and a folder half-renamed is worse than one not renamed
   % at all. The strict pattern below is what keeps this safe - sweep_manifest.txt
   % and any other free-form file cannot match it, so they are never touched.
   EXTS = {'mat', 'txt', 'csv'};

   d = [];
   for e = EXTS
      d = [d; dir(fullfile(dataPath, ['*.' e{1}]))]; %#ok<AGROW>
   end
   if isempty(d)
      fprintf('tag_legacy_results: no %s files in %s\n', strjoin(EXTS, '/'), dataPath);
      return;
   end

   % <var>_<regime>_<YYMMDD>_<counter>.<ext>
   pat = ['^(?<var>.+)_(?<reg>' strjoin(KNOWN_REGIMES, '|') ')_(?<date>\d{6})_(?<n>\d+)' ...
          '\.(?<ext>' strjoin(EXTS, '|') ')$'];

   plan = cell(0, 2);
   skipTagged = {};
   skipNoMatch = {};

   for i = 1:numel(d)
      f = d(i).name;

      % Already tagged?
      isTagged = false;
      for g = KNOWN_GRIDS
         if contains(f, ['_' g{1} '_'])
            isTagged = true; break;
         end
      end
      if isTagged
         skipTagged{end+1} = f; %#ok<AGROW>
         continue;
      end

      t = regexp(f, pat, 'names', 'once');
      if isempty(t)
         skipNoMatch{end+1} = f; %#ok<AGROW>
         continue;
      end

      newName = sprintf('%s_%s_%s_%s_%s.%s', t.var, t.reg, gridTag, t.date, t.n, t.ext);
      plan(end+1, :) = {f, newName}; %#ok<AGROW>
   end

   %% ---- report -----------------------------------------------------------
   fprintf('\n=================================================================\n');
   fprintf('  tag_legacy_results  ->  grid tag "%s"\n', gridTag);
   fprintf('  folder: %s\n', dataPath);
   if doIt
      fprintf('  MODE: RENAMING\n');
   else
      fprintf('  MODE: DRY RUN (nothing will be changed)\n');
   end
   fprintf('=================================================================\n');

   if ~isempty(skipTagged)
      fprintf('\n  already tagged, left alone (%d):\n', numel(skipTagged));
      for i = 1:numel(skipTagged), fprintf('     %s\n', skipTagged{i}); end
   end

   if ~isempty(skipNoMatch)
      fprintf(2, '\n  *** name not understood, left alone (%d):\n', numel(skipNoMatch));
      for i = 1:numel(skipNoMatch), fprintf(2, '     %s\n', skipNoMatch{i}); end
      fprintf(2, '      Check these by hand before you rely on the folder.\n');
   end

   if isempty(plan)
      fprintf('\n  nothing to rename.\n\n');
      return;
   end

   fprintf('\n  to rename (%d):\n', size(plan, 1));
   for i = 1:size(plan, 1)
      fprintf('     %-46s ->  %s\n', plan{i,1}, plan{i,2});
   end

   %% ---- collision check runs in BOTH modes -------------------------------
   collide = false;
   for i = 1:size(plan, 1)
      if exist(fullfile(dataPath, plan{i,2}), 'file')
         fprintf(2, '\n  *** target already exists: %s\n', plan{i,2});
         collide = true;
      end
   end
   if collide
      fprintf(2, '\n  Refusing to rename anything. Resolve the collisions first.\n\n');
      return;
   end

   if ~doIt
      fprintf('\n  Dry run only. Re-run with:\n');
      fprintf('     tag_legacy_results(''%s'', ''%s'', true)\n\n', dataPath, gridTag);
      return;
   end

   %% ---- do it ------------------------------------------------------------
   nOk = 0;
   for i = 1:size(plan, 1)
      try
         movefile(fullfile(dataPath, plan{i,1}), fullfile(dataPath, plan{i,2}));
         nOk = nOk + 1;
      catch ME
         fprintf(2, '  failed: %s  (%s)\n', plan{i,1}, ME.message);
      end
   end
   fprintf('\n  renamed %d of %d.\n', nOk, size(plan, 1));

   % Record what was done, in the same manifest run_all_sweeps appends to, so
   % the folder carries its own history.
   try
      fid = fopen(fullfile(dataPath, 'sweep_manifest.txt'), 'a');
      if fid > 0
         fprintf(fid, '%s  tag_legacy_results: %d files tagged grid=%s\n', ...
                 datestr(now, 'yyyy-mm-dd HH:MM:SS'), nOk, gridTag);
         for i = 1:size(plan, 1)
            fprintf(fid, '        %s\n', plan{i,2});
         end
         fclose(fid);
      end
   catch
      fprintf(2, '  (manifest not written)\n');
   end
   fprintf('\n');
end
