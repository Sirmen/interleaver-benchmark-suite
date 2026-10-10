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

   % NOT ONLY .m FILES. A release ships its instructions too, and a path in a
   % README is as machine-specific as one in code: FIGURES_README.md told the
   % reader to set dataDir to one author's own folder, and this function walked
   % past it for three releases because it only ever listed *.m.
   EXT = {'*.m', '*.md', '*.txt', '*.json', '*.cff', '*.yml', '*.yaml'};
   f = [];
   for e = 1:numel(EXT)
      f = [f; dir(fullfile(root, '**', EXT{e}))]; %#ok<AGROW>
   end
   % A DRIVE LETTER IS A LETTER ON ITS OWN, and the earlier pattern did not say
   % so. '[A-Za-z]:\\' also matches the tail of any message ending in a colon and
   % a newline escape: 'path:\n' contains 'h:\', 'arguments:\n' contains 's:\'.
   % Eighty lines of fprintf were reported as hardcoded paths, which is worse
   % than reporting none, because a checker nobody believes is a checker nobody
   % reads, and that is how a real path reaches a release. The lookbehind
   % requires the drive letter to start a token: C:\ is preceded by a quote or a
   % space, the h of path:\n by a t.
   %
   % The UNC branch had the same fault in the other direction: '\\\\[A-Za-z]' also
   % matched a TeX escape written for sprintf, so '\\\\eta_{sep}' in a figure label
   % was read as a share name. A UNC path carries a second separator, \\\\host\\share,
   % and requiring it leaves the escapes alone.
   pat = '((?<![A-Za-z0-9_])[A-Za-z]:\\|\\\\[A-Za-z0-9._-]+\\|/home/|/Users/|OneDrive)';
   hits = {};
   for i = 1:numel(f)
      p = fullfile(f(i).folder, f(i).name);
      if strcmp(f(i).name, 'check_hardcoded_paths.m'), continue; end
      L = splitlines(fileread(p));
      for k = 1:numel(L)
         if endsWith(f(i).name, '.m')
            code = regexprep(L{k}, '%.*$', '');       % comments are not paths the code uses
         else
            code = L{k};                              % % is not a comment outside MATLAB
         end
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
