function export_campaign_csv(dataDir, outDir, opts)
%EXPORT_CAMPAIGN_CSV  Build the Zenodo data package from a campaign folder.
%
%   export_campaign_csv(getenv('SINT_RESULTS'), '<outDir>')
%   export_campaign_csv(getenv('SINT_RESULTS'), '<outDir>', ...
%                       struct('dropMethods', {{'<name>'}}))
%
% Writes, into outDir:
%   KPItableDetailed_*.mat   filtered, the tables every reported number comes from
%   KPItableDetailed_*.csv.gz  the same rows, readable without MATLAB
%   correlation_data_*.mat   filtered the same way
%   config_*, params_*, paramsInt_*, burstConfig_*, crossCorrResults_*  copied
%   design_cells_v2.csv, KPI_SCOPE.txt, sweep_manifest.txt, analysis_*.txt  copied
%
% The originals are never modified.
%
% METHODS THE PAPER DOES NOT REPORT
% ===========================================================================
% A campaign folder can hold rows for methods outside Table I, and uploading a
% file that still holds them publishes them. Run audit_methods first, pass
% every such name in opts.dropMethods, and this function refuses to write
% anything while a name it was not told about is still in the tables.

   if nargin < 3, opts = struct(); end
   if ~isfield(opts, 'dropMethods'), opts.dropMethods = {}; end
   if ~isfield(opts, 'force'),       opts.force = false; end
   assert(~isempty(dataDir) && isfolder(dataDir), 'give the campaign folder');
   if exist(outDir, 'dir') ~= 7, mkdir(outDir); end
   drop = string(opts.dropMethods);

   d = dir(fullfile(dataDir, 'KPItableDetailed_*.mat'));
   assert(~isempty(d), 'no KPItableDetailed_*.mat in %s', dataDir);

   % ---- 0. refuse to run on an unaudited set -------------------------------
   seen = strings(0, 1);
   for i = 1:numel(d)
      S = load(fullfile(dataDir, d(i).name));
      fn = fieldnames(S);
      for j = 1:numel(fn)
         T = S.(fn{j});
         if istable(T) && ismember('method', T.Properties.VariableNames)
            seen = unique([seen; unique(string(T.method))]);
         end
      end
   end
   % Against the list the paper reports, not against a list of what to look
   % for: a name nobody thought to search for is the one that slips through.
   expected = string({'random', 'matrix', 'helical', 'helicalScan', 'snake', ...
      'spiral', 'diagonal', 'hierarchical', 'multiDim', 'latinSquare', 'time', ...
      'freqRandom', 'freqDeterm', 'chaotic', 'prime', 'block', 'algebraic', ...
      'turbo', 'convolutional', 'srandom', 'goldenRP', 'drp', 'arp', ...
      'blockCM', 'convCM', 'S'});
   missed = setdiff(setdiff(seen, expected), drop);
   if ~isempty(missed) && ~opts.force
      error('export_campaign_csv:unreported', ...
            ['These are in the tables, are not in Table I and are not in\n' ...
             'dropMethods:\n   %s\n' ...
             'Add them, or pass opts.force = true if they are meant to be public.'], ...
            strjoin(cellstr(missed'), ', '));
   end

   % ---- 1. the KPI tables, filtered, as .mat and as gzip CSV ---------------
   % The standardization constants are taken BEFORE anything is dropped, over
   % the same in-scope field the campaign used (KPI_SCOPE.txt: every method
   % except freqDeterm and freqRandom). Without them, a reader holding only
   % the filtered archive cannot re-derive CR_z, BE_z and RES, because two of
   % the methods that set the mean and the spread are not in it.
   OUTSCOPE = ["freqDeterm", "freqRandom"];
   cons = table();
   for i = 1:numel(d)
      S = load(fullfile(dataDir, d(i).name));
      fn = fieldnames(S);
      for j = 1:numel(fn)
         T = S.(fn{j});
         if ~istable(T) || ~ismember('method', T.Properties.VariableNames), continue; end
         ins = ~ismember(string(T.method), OUTSCOPE);
         for v = ["CR", "BE"]
            if ~ismember(v, string(T.Properties.VariableNames)), continue; end
            x = T.(char(v))(ins);
            cons = [cons; table(string(d(i).name), v, mean(x, 'omitnan'), std(x, 'omitnan'), ...
                                sum(ins), 'VariableNames', ...
                                {'file', 'quantity', 'mean', 'sd', 'nInScope'})]; %#ok<AGROW>
         end
      end
   end
   if ~isempty(cons)
      writetable(cons, fullfile(outDir, 'standardization_constants.csv'));
      fprintf('   wrote standardization_constants.csv (%d rows)\n', height(cons));
   end

   for i = 1:numel(d)
      S = load(fullfile(dataDir, d(i).name));
      fn = fieldnames(S);
      for j = 1:numel(fn)
         T = S.(fn{j});
         if ~istable(T), continue; end
         if ~isempty(drop) && ismember('method', T.Properties.VariableNames)
            keep = ~ismember(string(T.method), drop);
            fprintf('%s: dropped %d of %d rows\n', d(i).name, sum(~keep), numel(keep));
            T = T(keep, :); S.(fn{j}) = T;
         end
         csv = fullfile(outDir, regexprep(d(i).name, '\.mat$', '.csv'));
         writetable(T, csv); gzip(csv); delete(csv);
         fprintf('   wrote %s.gz  (%d rows)\n', csv, height(T));
      end
      save(fullfile(outDir, d(i).name), '-struct', 'S', '-v7.3');
   end

   % ---- 2. correlation_data, filtered the same way -------------------------
   c = dir(fullfile(dataDir, 'correlation_data_*.mat'));
   for i = 1:numel(c)
      S = load(fullfile(dataDir, c(i).name));
      S = local_drop(S, drop, c(i).name);
      save(fullfile(outDir, c(i).name), '-struct', 'S', '-v7.3');
   end

   % ---- 3. the small companions, copied as they are ------------------------
   plain = {'config_*.mat', 'params_*.mat', 'paramsInt_*.mat', 'burstConfig_*.mat', ...
            'crossCorrResults_*.mat', 'crossCorrResults_*.txt', 'KPI_SCOPE.txt', ...
            'sweep_manifest.txt', 'design_cells_v2.csv', 'analysis_*.txt'};
   n = 0;
   for p = 1:numel(plain)
      f = dir(fullfile(dataDir, plain{p}));
      for i = 1:numel(f)
         copyfile(fullfile(dataDir, f(i).name), outDir); n = n + 1;
      end
   end
   fprintf('   copied %d companion files\n', n);

   % ---- 4. what the package weighs ----------------------------------------
   w = dir(fullfile(outDir, '*'));
   mb = sum([w(~[w.isdir]).bytes]) / 1024^2;
   fprintf('\npackage: %d files, %.1f MB in %s\n', sum(~[w.isdir]), mb, outDir);
   fprintf(['\nBefore uploading, open one CSV and confirm no withheld method is in\n' ...
            'the method column. A published Zenodo record cannot be unpublished.\n']);
end

% -------------------------------------------------------------------------
function S = local_drop(S, drop, name)
   if isempty(drop), return; end
   fn = fieldnames(S);
   for j = 1:numel(fn)
      v = S.(fn{j});
      if istable(v) && ismember('method', v.Properties.VariableNames)
         keep = ~ismember(string(v.method), drop);
         if any(~keep)
            fprintf('%s/%s: dropped %d rows\n', name, fn{j}, sum(~keep));
            S.(fn{j}) = v(keep, :);
         end
      elseif isstruct(v) && isfield(v, 'method')
         keep = ~ismember(string({v.method}'), drop);
         if any(~keep)
            fprintf('%s/%s: dropped %d entries\n', name, fn{j}, sum(~keep));
            S.(fn{j}) = v(keep);
         end
      end
   end
end
