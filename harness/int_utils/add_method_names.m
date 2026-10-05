function report = add_method_names(dataDir, opts)
% ADD_METHOD_NAMES  Record methodNames in the correlation_data_*.mat files of
%                   a fresh campaign, after checking the mapping row by row.
%
%   report = add_method_names('<resultsDir>')                  % dry run
%   report = add_method_names('<resultsDir>', struct('apply', true))
%
% correlation_data stores methodID, an index into the sorted unique method
% list of its sweep, but not the list itself. validation_supplement and
% metric_crosscorr refuse a file without methodNames; metric_scorecard falls
% back to sort order with a warning. fix_correlation_data cannot help here: it
% repairs the v1 files against backup_prekpi, which a v2 campaign does not have.
%
% Row i of correlation_data and row i of KPItableDetailed come from trial i of
% the same stats_all. That is checked, not assumed:
%   1. equal row counts;
%   2. encodedLen and noiseActual equal element by element;
%   3. with names = sort(unique(KPI.method)), names(methodID) equals KPI.method
%      on every row;
%   4. RES equal element by element (both were written from the same KPIs).
% Only a file that passes all four is written, and only the methodNames field
% is added. Nothing else in the file changes.
%
% R. Tanju Sirmen study.

   if nargin < 1 || isempty(dataDir), dataDir = pwd; end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'apply'), opts.apply = false; end

   d = dir(fullfile(dataDir, 'correlation_data_*.mat'));
   if isempty(d), error('add_method_names: no correlation_data_*.mat in %s', dataDir); end
   report = struct('file', {}, 'ok', {}, 'note', {});
   fprintf('\n=== ADD METHOD NAMES (%s) ===\n', ternary(opts.apply, 'APPLY', 'dry run'));

   for i = 1:numel(d)
      f   = fullfile(dataDir, d(i).name);
      tag = regexprep(d(i).name, '^correlation_data_|\.mat$', '');
      kf  = fullfile(dataDir, ['KPItableDetailed_' tag '.mat']);
      if exist(kf, 'file') ~= 2
         report(end+1) = local_r(tag, false, 'no matching KPItableDetailed'); continue; %#ok<AGROW>
      end
      S = load(f); vn = fieldnames(S); vn = vn{1}; C = S.(vn);
      if isfield(C, 'methodNames')
         report(end+1) = local_r(tag, true, 'already has methodNames'); continue; %#ok<AGROW>
      end
      T = local_table(load(kf));
      if isempty(T)
         report(end+1) = local_r(tag, false, 'KPI table not found in file'); continue; %#ok<AGROW>
      end
      mid  = double(C.methodID(:));
      meth = string(T.method); meth = meth(:);
      n = numel(mid);
      if numel(meth) ~= n
         report(end+1) = local_r(tag, false, sprintf('row counts differ (%d vs %d)', n, numel(meth))); continue; %#ok<AGROW>
      end
      ok2 = isequal(double(C.encodedLen(:)), double(T.encodedLen(:))) && ...
            max(abs(double(C.noiseActual(:)) - double(T.noiseActual(:)))) < 1e-12;
      names = sort(unique(meth));
      ok3 = all(mid >= 1 & mid <= numel(names) & mid == round(mid)) && all(names(mid) == meth);
      dRES = max(abs(double(C.RES(:)) - double(T.RES(:))));
      ok4 = dRES < 1e-9;
      if ~(ok2 && ok3 && ok4)
         report(end+1) = local_r(tag, false, sprintf('check failed: anchors %d, names %d, RES %d (max dRES %.2e)', ok2, ok3, ok4, dRES)); %#ok<AGROW>
         continue;
      end
      note = sprintf('%d rows, %d methods, all four checks pass', n, numel(names));
      if opts.apply
         C.methodNames = cellstr(names);
         S.(vn) = C;
         save(f, '-struct', 'S', '-v7.3');
         note = [note ' - WRITTEN'];
      end
      report(end+1) = local_r(tag, true, note); %#ok<AGROW>
   end

   for i = 1:numel(report)
      fprintf('  %-28s %-4s %s\n', report(i).file, ternary(report(i).ok, 'OK', 'FAIL'), report(i).note);
   end
   if ~opts.apply && all([report.ok])
      fprintf('\nAll files pass. Run again with struct(''apply'', true) to write.\n');
   end
end

function r = local_r(f, ok, why)
   r = struct('file', f, 'ok', ok, 'note', why);
end

function T = local_table(S)
   T = [];
   fn = fieldnames(S);
   for i = 1:numel(fn)
      v = S.(fn{i});
      if istable(v), T = v; return; end
      if isstruct(v) && numel(v) > 1, T = struct2table(v); return; end
   end
end

function s = ternary(c, a, b)
   if c, s = a; else, s = b; end
end
