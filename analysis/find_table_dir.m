function [dirOut, erM] = find_table_dir(startDir, quiet)
%FIND_TABLE_DIR  Locate the folder holding table_factors_precomputed.mat.
%
%   d = find_table_dir                       % search from cwd and the path
%   d = find_table_dir(resultsDir)           % search from there, outward
%   [d, erM] = find_table_dir(...)           % erM non-empty instead of raising
%
% WHY THIS EXISTS
% ===========================================================================
% The harness reads from two folders that look alike and are not:
%
%   the RESULTS folder   KPItableDetailed_*.mat, correlation_data_*.mat, the
%                        output of a sweep
%   the TABLE folder     table_factors_precomputed.mat, the precomputed
%                        permutations and divisor lists a sweep reads
%
% Every entry point that needs both takes them as two arguments, and passing
% the results folder for both is the single easiest mistake to make in this
% project. It fails with "Precomputed file not found" naming the results
% folder, which reads as a missing file rather than as a wrong folder.
%
% A function that looks is better than a caller who remembers. The search is
% ordered from the most specific place to the most general, and reports which
% one answered, so a table found somewhere unexpected is visible rather than
% silently used.
%
% WHERE IT LOOKS, in order
%   1. startDir itself
%   2. startDir's parent, and the usual siblings: tables, table, precomputed,
%      precomputedTables, data
%   3. the current folder and its parent
%   4. the MATLAB path, via which()
%
% It does not recurse downward. A file found by walking a tree is a file
% whose location nobody controls, and two copies of a precomputed table that
% differ is a failure mode this project has already paid for once.

   if nargin < 1, startDir = ''; end
   if nargin < 2, quiet = false; end
   FILE = 'table_factors_precomputed.mat';
   dirOut = ''; erM = "";

   cand = {};
   if ~isempty(startDir)
      startDir = char(startDir);
      cand{end+1} = startDir;
      p = fileparts(local_strip(startDir));
      if ~isempty(p)
         cand{end+1} = p;
         for s = {'tables', 'table', 'precomputed', 'precomputedTables', 'data'}
            cand{end+1} = fullfile(p, s{1}); %#ok<AGROW>
         end
      end
   end
   cand{end+1} = pwd;
   cand{end+1} = fileparts(pwd);

   seen = {};
   for i = 1:numel(cand)
      c = local_strip(cand{i});
      if isempty(c) || any(strcmpi(seen, c)), continue; end
      seen{end+1} = c; %#ok<AGROW>
      if exist(fullfile(c, FILE), 'file') == 2
         dirOut = c;
         if ~quiet, fprintf('  precomputed tables: %s\n', dirOut); end
         return;
      end
   end

   % The path, last. A table reached this way is correct but not obviously
   % correct, so it is announced even when quiet was asked for.
   w = which(FILE);
   if ~isempty(w)
      dirOut = fileparts(w);
      fprintf('  precomputed tables found on the MATLAB path: %s\n', dirOut);
      return;
   end

   erM = sprintf(['%s was not found. Looked in:\n%s\n' ...
                  'and on the MATLAB path. Give the folder that holds it as\n' ...
                  'opts.tableDir - it is NOT the results folder.'], ...
                 FILE, sprintf('    %s\n', seen{:}));
   if nargout < 2, error('find_table_dir:notFound', '%s', erM); end
end

% -------------------------------------------------------------------------
function s = local_strip(s)
   s = char(s);
   while ~isempty(s) && (s(end) == filesep || s(end) == '/' || s(end) == '\')
      s(end) = [];
   end
end
