function [ok, report] = check_path_shadowing(opts)
%CHECK_PATH_SHADOWING  Refuse to run when two files of one name are reachable.
%
%   ok = check_path_shadowing                      % prints, returns true/false
%   [ok, report] = check_path_shadowing(struct('quiet', true))
%   check_path_shadowing(struct('strict', true))   % raises instead of returning
%
% Checks for shadow pairs: MATLAB calls the first file of a given name on the
% path and ignores the rest, so two reachable copies make it ambiguous which one
% produced a result.
%
% Two checks:
%   1. no two .m files inside this release share a name;
%   2. for every name in the release, the file MATLAB would call is the one in
%      the release, not a copy elsewhere on the path.

   if nargin < 1, opts = struct(); end
   if ~isfield(opts, 'quiet'),  opts.quiet  = false; end
   if ~isfield(opts, 'strict'), opts.strict = false; end

   root = fileparts(mfilename('fullpath'));
   files = dir(fullfile(root, '**', '*.m'));
   files = files(~[files.isdir]);

   names = string({files.name})';
   dirs  = string({files.folder})';
   [uniq, ~, g] = unique(names);

   report = struct('name', {}, 'kind', {}, 'paths', {});

   % ---- 1. two copies inside the release ---------------------------------
   for i = 1:numel(uniq)
      k = find(g == i);
      if numel(k) > 1
         report(end+1) = struct('name', uniq(i), 'kind', "duplicate in release", ...
                                'paths', {cellstr(fullfile(dirs(k), names(k)))}); %#ok<AGROW>
      end
   end

   % ---- 2. something outside the release wins ----------------------------
   for i = 1:numel(uniq)
      fn = char(regexprep(uniq(i), '\.m$', ''));
      w = which(fn, '-all');
      if isempty(w), continue; end          % not on the path at all: setup_paths not run
      first = w{1};
      if ~strncmpi(first, root, numel(root))
         report(end+1) = struct('name', uniq(i), 'kind', "shadowed from outside", ...
                                'paths', {w}); %#ok<AGROW>
      end
   end

   ok = isempty(report);

   if ~opts.quiet
      if ok
         fprintf('  path check: no shadowed file (%d names under %s)\n', numel(uniq), root);
      else
         fprintf(2, '\n  PATH SHADOWING, %d name(s):\n', numel(report));
         for i = 1:numel(report)
            fprintf(2, '    %-34s %s\n', report(i).name, report(i).kind);
            for j = 1:numel(report(i).paths)
               mark = ''; if j == 1, mark = '   <-- this one runs'; end
               fprintf(2, '        %s%s\n', report(i).paths{j}, mark);
            end
         end
         fprintf(2, ['\n  Remove the copies, or put this release first on the path:\n' ...
                     '      addpath(genpath(''%s''), ''-begin'')\n\n'], root);
      end
   end

   if opts.strict && ~ok
      error('check_path_shadowing:shadowed', ...
            '%d name(s) resolve to a file outside this release, or appear twice inside it.', ...
            numel(report));
   end
end
