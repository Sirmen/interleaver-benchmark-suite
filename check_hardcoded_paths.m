function hits = check_hardcoded_paths(root)
%CHECK_HARDCODED_PATHS  List .m files that contain an absolute path.
%
%   check_hardcoded_paths            % from the repository root
%
% A release that finds its tables only at C:\Users\... runs on one machine.
% This lists every line with a drive letter, a UNC path or a /home, /Users
% path, so each can be replaced by find_table_dir() or a dataDir argument
% before the release is tagged.

   if nargin < 1, root = fileparts(mfilename('fullpath')); end
   f = dir(fullfile(root, '**', '*.m'));
   pat = '([A-Za-z]:\\|\\\\[A-Za-z]|/home/|/Users/|OneDrive)';
   hits = {};
   for i = 1:numel(f)
      p = fullfile(f(i).folder, f(i).name);
      if strcmp(f(i).name, 'check_hardcoded_paths.m'), continue; end
      L = splitlines(fileread(p));
      for k = 1:numel(L)
         code = regexprep(L{k}, '%.*$', '');          % comments are not paths the code uses
         if ~isempty(regexp(code, pat, 'once'))
            hits(end+1, :) = {p, k, strtrim(L{k})}; %#ok<AGROW>
            fprintf('%s:%d  %s\n', p, k, strtrim(L{k}));
         end
      end
   end
   if isempty(hits)
      fprintf('check_hardcoded_paths: none found\n');
   else
      fprintf(2, 'check_hardcoded_paths: %d line(s) to fix before release\n', size(hits, 1));
   end
end
