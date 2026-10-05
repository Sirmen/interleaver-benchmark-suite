function names = audit_methods(dataDir)
%AUDIT_METHODS  Every distinct method name in the campaign files, before upload.
%
%   audit_methods(getenv('SINT_RESULTS'))
%
% Run this before building the Zenodo package. The archive must carry the
% methods Table I lists and no others; a .mat uploaded unfiltered can carry
% more than that, and an upload cannot be taken back afterwards.

   if nargin < 1 || isempty(dataDir), dataDir = getenv('SINT_RESULTS'); end
   assert(~isempty(dataDir) && isfolder(dataDir), 'give the campaign folder');

   pats = {'KPItableDetailed_*.mat', 'correlation_data_*.mat', 'scorecard_v2.mat', ...
           'anovaResults_*.mat', 'paramsInt_*.mat'};
   names = strings(0, 1);
   for p = 1:numel(pats)
      d = dir(fullfile(dataDir, pats{p}));
      for i = 1:numel(d)
         f = fullfile(dataDir, d(i).name);
         S = load(f);
         found = local_scan(S);
         if ~isempty(found)
            fprintf('%-46s %s\n', d(i).name, strjoin(cellstr(found'), ', '));
            names = unique([names; found]);
         else
            fprintf('%-46s (no method column found)\n', d(i).name);
         end
      end
   end

   fprintf('\n--- distinct method names across the campaign ---\n');
   for i = 1:numel(names), fprintf('   %s\n', names(i)); end

   % Checked against the list the paper reports rather than against a list of
   % what to look for: a name nobody thought to search for is exactly the one
   % that slips through.
   expected = string(TABLE_I_METHODS);
   extra = setdiff(names, expected);
   missing = setdiff(expected, names);

   if ~isempty(missing)
      fprintf(2, '\n   not found in these files: %s\n', strjoin(cellstr(missing'), ', '));
   end
   if ~isempty(extra)
      fprintf(2, '\n*** METHODS THAT TABLE I DOES NOT LIST: %s\n', strjoin(cellstr(extra'), ', '));
      fprintf(2, '    Pass them to export_campaign_csv as opts.dropMethods.\n');
      fprintf(2, '    Nothing may be uploaded until these rows are gone.\n');
   else
      fprintf('\n   every name in these files is one Table I lists\n');
   end
end

% -------------------------------------------------------------------------
function m = TABLE_I_METHODS()
   m = {'random', 'matrix', 'helical', 'helicalScan', 'snake', 'spiral', ...
        'diagonal', 'hierarchical', 'multiDim', 'latinSquare', 'time', ...
        'freqRandom', 'freqDeterm', 'chaotic', 'prime', 'block', 'algebraic', ...
        'turbo', 'convolutional', 'srandom', 'goldenRP', 'drp', 'arp', ...
        'blockCM', 'convCM', 'S'};
end

% -------------------------------------------------------------------------
function out = local_scan(S)
   out = strings(0, 1);
   fn = fieldnames(S);
   for j = 1:numel(fn)
      v = S.(fn{j});
      if istable(v) && ismember('method', v.Properties.VariableNames)
         out = unique([out; unique(string(v.method))]);
      elseif isstruct(v) && isfield(v, 'method')
         out = unique([out; unique(string({v.method}'))]);
      elseif iscellstr(v) || isstring(v) %#ok<ISCLSTR>
         s = string(v(:));
         if numel(s) < 60 && any(strcmpi(s, 'srandom'))   % looks like a method list
            out = unique([out; s]);
         end
      end
   end
end
