function audit_dependencies(releaseRoot, outFile)
%AUDIT_DEPENDENCIES  Every file the entry points need, and which ones the release lacks.
%
%   audit_dependencies                                  % release at the default place
%   audit_dependencies('D:\somewhere\interleaver-benchmark-suite')   % another tree
%
% RUN THIS IN YOUR NORMAL MATLAB SESSION, with the full working tree on the path
% — not inside the release. It asks MATLAB for the dependency closure of the
% entry points, which resolves only where every file exists.
%
% It prints, and writes to a text file:
%   1. the toolboxes the code actually uses (for the README's requirements);
%   2. every project file the entry points need;
%   3. the ones missing from the release tree, which is the list to copy.

   % WHERE THE RELEASE IS. The default used to be one machine's build folder,
   % written into the file, which is the thing check_hardcoded_paths exists to
   % stop. The folder holding this file IS the release, so ask for it; set
   % RELEASE_ROOT in the environment to audit a tree other than this one.
   if nargin < 1 || isempty(releaseRoot)
      releaseRoot = getenv('RELEASE_ROOT');
      if isempty(releaseRoot)
         releaseRoot = fileparts(mfilename('fullpath'));
      end
   end
   if nargin < 2 || isempty(outFile)
      outFile = fullfile(pwd, 'dependency_audit.txt');
   end

   ENTRIES = {'reproduce_paper', 'main_simulation_wrapper', 'run_all_sweeps', ...
              'run_simulations_sci', 'run_PrecomputeInterleavers', ...
              'metric_scorecard', 'screen_methods', 'validation_supplement', ...
              'check_noise_fidelity', 'check_kappa_sensitivity', 'health_check', ...
              'export_campaign_csv', 'verify_setup'};

   have = {}; miss = {};
   for i = 1:numel(ENTRIES)
      if isempty(which(ENTRIES{i})), miss{end+1} = ENTRIES{i}; %#ok<AGROW>
      else, have{end+1} = ENTRIES{i}; end %#ok<AGROW>
   end
   if ~isempty(miss)
      fprintf(2, 'not on the path, skipped as entry points: %s\n', strjoin(miss, ', '));
   end
   assert(~isempty(have), 'none of the entry points is on the path');

   fprintf('resolving the dependency closure of %d entry points ...\n', numel(have));
   [flist, plist] = matlab.codetools.requiredFilesAndProducts(have);
   flist = flist(:);

   % project files only: drop anything under the MATLAB installation
   mroot = matlabroot;
   isProj = ~strncmpi(flist, mroot, numel(mroot));
   proj = flist(isProj);

   % which of them the release already has, by file name
   relFiles = dir(fullfile(releaseRoot, '**', '*.m'));
   relNames = lower(string({relFiles.name}));

   missing = {};
   for i = 1:numel(proj)
      [~, nm, ext] = fileparts(proj{i});
      if ~any(relNames == lower(string([nm ext])))
         missing{end+1} = proj{i}; %#ok<AGROW>
      end
   end

   fid = fopen(outFile, 'w');
   c = onCleanup(@() fclose(fid));
   function say(varargin)
      fprintf(varargin{:}); fprintf(fid, varargin{:});
   end

   say('\n=== toolboxes the code uses ===\n');
   for i = 1:numel(plist)
      say('  %-52s %s\n', plist(i).Name, plist(i).Version);
   end

   say('\n=== project files needed: %d ===\n', numel(proj));

   say('\n=== MISSING FROM THE RELEASE: %d ===\n', numel(missing));
   for i = 1:numel(missing)
      say('  %s\n', missing{i});
   end
   if isempty(missing)
      say('  none - the release is closed under its dependencies\n');
   end

   say('\n=== the same list, file names only (paste this back) ===\n');
   for i = 1:numel(missing)
      [~, nm, ext] = fileparts(missing{i});
      say('  %s%s\n', nm, ext);
   end

   fprintf('\nwritten to %s\n', outFile);
end
