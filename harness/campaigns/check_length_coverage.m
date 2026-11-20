function R = check_length_coverage(dataPath, opts)
%CHECK_LENGTH_COVERAGE  Did every method get every length, or are there holes?
%
%   R = check_length_coverage('<resultsDir>');
%   R = check_length_coverage('<campaigns>/code31', struct('FECn',31,'FECk',21,'expected',84*setdiff(1:24,15)));
%
% WHY THIS EXISTS
% ---------------------------------------------------------------------------
% interleave_all_pc runs its methods in sequence and guards every block after
% the first with "&& (erM == "")". A method that cannot be defined at a given
% length therefore does not merely skip itself - it leaves erM set, every
% later block is passed over, run_single_trial returns the error, and the
% TRIAL IS DISCARDED WHOLE. No method contributes a row at that length, and
% the retry loop cannot help because the failure depends on the length, not
% on the noise draw.
%
% This was found on 31 October 2026 when interleaver_drp refused K = 2201 in
% an RS(31,21) run. DRP requires 4 | K and K = n * numBlocks, so with
% n = 31 = 3 (mod 4) it needs numBlocks = 0 (mod 4) and fails at about three
% lengths in four. The question this file answers is whether the SAME thing
% happened, unnoticed, in the campaigns already recorded.
%
% The arithmetic says it did not: at n = 15 the encoded length is
% K = 15 * ceil(len/9), and on the 36*(1:50) grid ceil(36i/9) = 4i exactly, so
% K = 60i and 4 | K at every length. That is a prediction, and predictions
% about one's own published data are worth checking rather than asserting -
% hence this file. A hole found here would mean the campaign silently ran on
% fewer lengths than it reports.
%
% WHAT IT REPORTS
%   per regime, the number of distinct lengths each method actually has
%   any length where the methods DISAGREE (which should be impossible given
%     the all-or-nothing trial, and would mean something else is wrong)
%   any length from the expected grid that is absent for everyone
%   the DRP admissibility prediction beside the observed coverage
%
% R.T. Sirmen harness, 2026-10-31

   if nargin < 2, opts = struct(); end
   n        = local_opt(opts, 'FECn', 15);
   k        = local_opt(opts, 'FECk', 9);
   expected = local_opt(opts, 'expected', 36*(1:50));
   outDir   = local_opt(opts, 'outDir', campaign_log_dir());
   if ~exist(outDir, 'dir'), mkdir(outDir); end

   d = dir(fullfile(dataPath, 'KPItableDetailed_*.mat'));
   if isempty(d), error('check_length_coverage: no KPItableDetailed_*.mat in %s', dataPath); end

   stamp  = datestr(now, 'yymmdd_HHMMSS');
   outTxt = fullfile(outDir, sprintf('length_coverage_%s.txt', stamp));
   fid = fopen(outTxt, 'w'); if fid < 0, fid = 1; end

   local_say(fid, '\n=================================================================\n');
   local_say(fid, '  LENGTH COVERAGE PER METHOD\n');
   local_say(fid, '  %s\n', dataPath);
   local_say(fid, '  assuming RS(%d,%d) and an expected grid of %d lengths\n', ...
             n, k, numel(expected));
   local_say(fid, '=================================================================\n');

   % The field list must match the struct assigned at the end of the loop,
   % in the same order: MATLAB refuses "Subscripted assignment between
   % dissimilar structures" otherwise, and it refuses it AFTER every regime
   % has been printed, so the failure looks like it came from the data.
   R = struct('regime', {}, 'file', {}, 'grid', {}, 'nLenMin', {}, ...
              'nLenMax', {}, 'nLen', {}, 'missing', {}, 'methodsAgree', {});

   for f = 1:numel(d)
      T = local_loadTable(load(fullfile(dataPath, d(f).name)));
      regime = local_regime(d(f).name);
      if isempty(T), local_say(fid, '\n  %s: no table inside, skipped\n', regime); continue; end
      if ~ismember('method', T.Properties.VariableNames)
         local_say(fid, '\n  %s: no method column, skipped\n', regime); continue;
      end
      lenVar = '';
      for cand = {'encodedLen', 'N', 'size', 'len'}
         if ismember(cand{1}, T.Properties.VariableNames), lenVar = cand{1}; break; end
      end
      if isempty(lenVar)
         local_say(fid, '\n  %s: no length column, skipped\n', regime); continue;
      end

      meth = unique(T.method, 'stable');
      local_say(fid, '\n  regime %s   (%s)   %d methods\n', regime, lenVar, numel(meth));
      local_say(fid, '    %-12s %8s %10s\n', 'method', 'lengths', 'rows');
      local_say(fid, '    %s\n', repmat('-', 1, 34));
      counts = zeros(numel(meth), 1);
      lensPerMethod = cell(numel(meth), 1);
      for i = 1:numel(meth)
         sel = strcmp(T.method, meth{i});
         lensPerMethod{i} = unique(T.(lenVar)(sel));
         counts(i) = numel(lensPerMethod{i});
         local_say(fid, '    %-12s %8d %10d\n', meth{i}, counts(i), sum(sel));
      end
      local_say(fid, '    %s\n', repmat('-', 1, 34));

      % --- do the methods agree with each other? -------------------------
      allSame = true;
      for i = 2:numel(meth)
         if ~isequal(lensPerMethod{i}, lensPerMethod{1}), allSame = false; end
      end
      if allSame
         local_say(fid, '    all methods cover the SAME lengths  (expected: a failed\n');
         local_say(fid, '    trial is discarded whole, so holes are shared)\n');
      else
         local_say(fid, ['    *** METHODS COVER DIFFERENT LENGTHS. That should not be\n' ...
                         '    *** possible with an all-or-nothing trial, so something\n' ...
                         '    *** other than a voided trial is at work here.\n']);
         for i = 1:numel(meth)
            extra = setdiff(lensPerMethod{i}, lensPerMethod{1});
            lack  = setdiff(lensPerMethod{1}, lensPerMethod{i});
            if ~isempty(extra) || ~isempty(lack)
               local_say(fid, '      %-12s +%d / -%d vs %s\n', ...
                         meth{i}, numel(extra), numel(lack), meth{1});
            end
         end
      end

      % --- which expected lengths are absent for everyone? ---------------
      % A RESULTS FOLDER HOLDS MORE THAN ONE GRID. results_v2 carries both
      % the 'common' sweep on 36*(1:50) and the 'standards' sweep on the
      % eight 802.16 rows that are multiples of 15, and they sit in the same
      % directory as separate files. Measuring a standards file against the
      % 50-length grid reports 42 lengths "missing" from a sweep that never
      % had them - which this file did on its first run, against the
      % published campaign. A checker that cries wolf about correct data is
      % worse than no checker, so the grid is now IDENTIFIED rather than
      % assumed: the observed set is matched against every known grid, and
      % only a set that matches none is reported as holed.
      have = lensPerMethod{1}(:)';
      grids = { 'common',    36*(1:50) ; ...
                'standards', [72 108 144 288 576 864 1152 1440] };
      if isfield(opts, 'expected') && ~isempty(opts.expected)
         grids(end+1, :) = {'opts.expected', opts.expected(:)'};
      end

      matched = ''; missing = [];
      for g = 1:size(grids, 1)
         enc = unique(n * ceil(grids{g,2} / k));
         if isequal(sort(have), sort(enc)), matched = grids{g,1}; break; end
      end

      if ~isempty(matched)
         local_say(fid, '    grid: matches ''%s'' EXACTLY (%d lengths). Nothing missing.\n', ...
                   matched, numel(have));
      else
         % No exact match. Report against the known grid it overlaps most,
         % which is the one it was most likely meant to be.
         best = 1; bestHit = -1;
         for g = 1:size(grids, 1)
            enc = unique(n * ceil(grids{g,2} / k));
            hit = numel(intersect(enc, have));
            if hit > bestHit, bestHit = hit; best = g; end
         end
         ref = unique(n * ceil(grids{best,2} / k));
         missing = setdiff(ref, have);
         extra   = setdiff(have, ref);
         local_say(fid, '    grid: matches NO known grid exactly.\n');
         local_say(fid, '      closest is ''%s'': %d of %d present, MISSING %d\n', ...
                   grids{best,1}, bestHit, numel(ref), numel(missing));
         if ~isempty(missing), local_say(fid, '      missing: %s\n', local_list(missing)); end
         if ~isempty(extra),   local_say(fid, '      unexpected: %s\n', local_list(extra)); end
      end

      % --- the DRP prediction, beside the observation --------------------
      % Measured on the lengths this file ACTUALLY has, not on an assumed
      % grid, so the prediction and the observation are about the same set.
      predBad = have(arrayfun(@(K) ~any(mod(K, [16 8 4]) == 0), have));
      local_say(fid, '    DRP admissibility: 4|K fails at %d of %d lengths present\n', ...
                numel(predBad), numel(have));
      if ~isempty(predBad)
         local_say(fid, '      predicted void: %s\n', local_list(predBad));
         if isempty(missing)
            local_say(fid, ['      ...but NOTHING is missing from the data, so either drp\n' ...
                            '      was not in this run''s method set or it never refused.\n']);
         end
      else
         local_say(fid, '      none - every length admits a dither period, so drp\n');
         local_say(fid, '      cannot have voided a trial in this campaign.\n');
      end

      R(end+1) = struct('regime', regime, 'file', d(f).name, 'grid', matched, ...
                        'nLenMin', min(counts), 'nLenMax', max(counts), ...
                        'nLen', numel(have), 'missing', missing, ...
                        'methodsAgree', allSame); %#ok<AGROW>
   end

   local_say(fid, '\n=================================================================\n');
   local_say(fid, '  %-28s %-12s %7s %s\n', 'file', 'grid', 'lengths', 'methods agree');
   local_say(fid, '  %s\n', repmat('-', 1, 68));
   for i = 1:numel(R)
      g = R(i).grid; if isempty(g), g = '** none **'; end
      local_say(fid, '  %-28s %-12s %7d %s\n', ...
                local_trim(R(i).file, 28), g, R(i).nLen, local_yn(R(i).methodsAgree));
   end
   local_say(fid, '  %s\n', repmat('-', 1, 68));
   clean = ~isempty(R) && all(cellfun(@isempty, {R.missing})) && ...
           all(~cellfun(@isempty, {R.grid})) && all([R.methodsAgree]) && ...
           all([R.nLenMin] == [R.nLenMax]);
   if clean
      local_say(fid, ['  NO HOLES. Every file matches a known grid exactly and every\n' ...
                      '  method in it has every length of that grid. Nothing was\n' ...
                      '  silently dropped.\n' ...
                      '\n  A folder holding files on DIFFERENT grids is normal and is\n' ...
                      '  not a hole: results_v2 carries the 50-length ''common'' sweep\n' ...
                      '  and the 8-length ''standards'' sweep side by side, which is\n' ...
                      '  what the campaign''s "eight conditions" are made of.\n']);
   else
      local_say(fid, ['  SOMETHING IS OFF. A file matches no known grid, or its methods\n' ...
                      '  cover different lengths. Read the per-regime sections above\n' ...
                      '  before quoting any length count from this folder.\n']);
   end
   local_say(fid, '=================================================================\n');
   local_say(fid, '\n  written: %s\n', outTxt);
   if fid > 1, fclose(fid); end
   fprintf('\n  check_length_coverage: %s\n', outTxt);
end

% -------------------------------------------------------------------------
function s = local_yn(ok)
   if ok, s = 'yes'; else, s = 'NO'; end
end

function s = local_trim(s, n)
   if numel(s) > n, s = ['...' s(end-n+4:end)]; end
end

function s = local_list(v)
   v = v(:)';
   if numel(v) > 14, s = sprintf('%d ', v(1:14)); s = [s '...']; else, s = sprintf('%d ', v); end
end

function T = local_loadTable(S)
   T = [];
   fn = fieldnames(S);
   for i = 1:numel(fn)
      if istable(S.(fn{i})), T = S.(fn{i}); return; end
   end
end

function r = local_regime(name)
   tok = regexp(name, 'KPItableDetailed_([a-zA-Z0-9]+)_', 'tokens', 'once');
   if isempty(tok), r = '?'; else, r = tok{1}; end
end

function v = local_opt(o, f, dflt)
   if isstruct(o) && isfield(o, f) && ~isempty(o.(f)), v = o.(f); else, v = dflt; end
end

function local_say(fid, varargin)
   fprintf(varargin{:});
   if fid > 1, fprintf(fid, varargin{:}); end
end
