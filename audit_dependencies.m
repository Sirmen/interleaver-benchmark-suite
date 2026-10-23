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

   % EVERY ENTRY POINT IS NAMED HERE. These are the files a person runs, so
   % nothing calls them and the closure cannot reach them. Naming them costs
   % a line each and makes the set arguable; the prefix rule this list
   % replaced cost eleven hidden files (see the note further down).
   ENTRIES = { ...
      ... % the paper and the campaign
      'reproduce_paper', 'main_simulation_wrapper', 'run_all_sweeps', ...
      'run_simulations_sci', 'run_PrecomputeInterleavers', 'export_campaign_csv', ...
      ... % the analyses reproduce_paper drives, also run on their own
      'metric_scorecard', 'screen_methods', 'validation_supplement', ...
      'check_noise_fidelity', 'check_kappa_sensitivity', ...
      ... % release integrity and campaign health
      'verify_setup', 'check_path_shadowing', 'check_hardcoded_paths', ...
      'health_check', 'health_selftest', ...
      ... % metric design and validation tools
      'metric_validation', 'metric_crosscorr', 'crosscorr_selftest', ...
      'design_metric_validation', 'design_metric_extension', ...
      'laplacianEnergy_degeneracy_test', 'dump_table13_ntcell', ...
      'check_le_uecc', 'check_uecc_invariance', 'verify_pairing', ...
      'verify_tablefree_equivalence', 'check_clean_region', ...
      'check_permutation_reach', 'ge_burst_stats', ...
      ... % campaign bookkeeping, provenance and scope
      'restandardize_scope', 'add_method_names', 'tag_legacy_results', ...
      'run_provenance_logs', 'run_timing_logs', 'audit_methods', ...
      ... % tables, figures and per-family diagnostics
      'make_figures_CEE', 'PrimesFactorsGenerator', 'PrecomputeFactorsGenerator', ...
      'DiagnosePrecomputedTable', 'test_all_interleavers_precomputed', ...
      'diagnose_snake', 'verify_arp_table', 'sintperm_ref', 'test_swapRows'};

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

   % THE OTHER DIRECTION: what the release carries and nothing reaches.
   % ----------------------------------------------------------------------
   % The closure above answers "what is missing". The question that decides
   % what to withdraw is its complement: which released files no entry point
   % needs. The data are already here, so it is a set difference, and not
   % computing it is how a tree accumulates files from a driver that was
   % replaced - main_simulation_wrapper once called run_simulations, now
   % run_simulations_sci, and whatever only the old line needed stayed.
   %
   % THIS LIST IS CANDIDATES, NOT A VERDICT. requiredFilesAndProducts
   % follows static calls; a file reached only through feval, str2func, a
   % name built at run time or a callback will not appear in the closure and
   % will show up here although it is live. Move what is left to a quarantine
   % folder and run the entry points; deleting is for later.
   %
   % NOTHING IS SUPPRESSED BY NAME. An earlier version of this report hid
   % every name beginning test_, check_, verify_ or fig, on the assumption
   % that such a file is an entry point of its own. In this tree the prefix
   % does not carry that meaning: check_path_shadowing IS an entry point,
   % while check_sample_sizes is a step of analyzeSimulationHealth, and so
   % the filter hid eleven files of the retired line behind the four it was
   % meant to hide. A report that drops rows silently cannot be audited, and
   % a suppression rule that is right nine times in ten is worse than none,
   % because the tenth row is the one that matters. The declared ENTRIES are
   % marked as reached; every other unreached file is printed with its date,
   % and the reader decides.
   needed = false(size(relFiles));
   projNames = strings(numel(proj), 1);
   for i = 1:numel(proj)
      [~, nm, ext] = fileparts(proj{i});
      projNames(i) = lower(string([nm ext]));
   end
   for i = 1:numel(relFiles)
      needed(i) = any(projNames == lower(string(relFiles(i).name)));
   end
   % Entry points are reached by definition, even when nothing calls them.
   % Only the declared list and this file itself, by name and in full - no
   % prefixes. A tool that belongs here belongs in ENTRIES, where it is
   % visible and can be argued with.
   for i = 1:numel(relFiles)
      [~, nm] = fileparts(relFiles(i).name);
      ok = any(strcmpi(nm, ENTRIES)) || strcmpi(nm, 'audit_dependencies') || ...
           strcmpi(nm, 'setup_paths');
      % The one prefix rule that is kept, and the reason it is safe: it is
      % SCOPED BY DIRECTORY. A test_* file under interleavers/ is the unit
      % test of the family in that folder - there are two dozen of them and
      % naming each buys nothing. The rule that was removed applied a prefix
      % across the whole tree, where check_ means an entry point in the root
      % and a step of a retired protocol under health/. The folder supplies
      % the meaning the prefix on its own does not carry.
      if ~ok
         rel = erase(fullfile(relFiles(i).folder, relFiles(i).name), [releaseRoot filesep]);
         ok = strncmpi(nm, 'test_', 5) && ...
              strncmpi(rel, ['interleavers' filesep], numel('interleavers') + 1);
      end
      if ok, needed(i) = true; end
   end
   unreached = relFiles(~needed);
   % SORTED BY DATE, NEWEST FIRST, BECAUSE THE DATE IS THE REAL SIGNAL.
   % Name patterns cannot separate a live tool from dead code here: this
   % tree is a box of standalone scripts, and a file nothing calls is
   % usually one a PERSON calls. What does separate them is when they were
   % last touched. A driver that was replaced leaves its dependants frozen
   % at the date of the switch, while the tools of the current line keep
   % moving with the work. Read the list from the bottom.
   if ~isempty(unreached)
      [~, ord] = sort([unreached.datenum], 'descend');
      unreached = unreached(ord);
   end
   say('\n=== IN THE RELEASE BUT NOT REACHED: %d ===\n', numel(unreached));
   say('  (candidates to quarantine; see the caveat in this file)\n');
   say('  newest first - the old end of this list is where a replaced\n');
   say('  driver leaves its dependants behind\n');
   for i = 1:numel(unreached)
      rp = erase(fullfile(unreached(i).folder, unreached(i).name), [releaseRoot filesep]);
      say('  %s  %s\n', datestr(unreached(i).datenum, 'yyyy-mm-dd'), rp);
   end
   if isempty(unreached)
      say('  none - every released file is reached from an entry point\n');
   end

   % ----------------------------------------------------------------------
   % WHAT SHIPS IS THE GIT TREE, NOT THIS DIRECTORY.
   % Everything above compares the call closure against the files on disk.
   % An archive is built from the commit, so a file present here and absent
   % from git does not ship, and a file deleted here but still tracked does.
   % On 2026-10-23 this directory held seven metric implementations that git
   % had never seen, and tracked ninety files that had been deleted from it,
   % while the report above said nothing was missing. Both lists were true
   % of the directory and neither was true of the release.
   git = local_git(releaseRoot);
   if isempty(git)
      say('\n=== GIT: not a repository, or git unavailable - not checked ===\n');
   else
      onDisk = strings(numel(relFiles), 1);
      for i = 1:numel(relFiles)
         onDisk(i) = string(erase(fullfile(relFiles(i).folder, relFiles(i).name), ...
                                  [releaseRoot filesep]));
      end
      onDisk  = replace(onDisk, '\', '/');
      untrack = setdiff(onDisk, git);
      ghost   = setdiff(git, onDisk);
      ghost   = ghost(endsWith(ghost, '.m'));   % only code is our business here
      say('\n=== HERE BUT NOT IN GIT: %d ===\n', numel(untrack));
      say('  (would NOT ship; git add them or accept their absence)\n');
      for i = 1:numel(untrack), say('  %s\n', untrack(i)); end
      say('\n=== IN GIT BUT NOT HERE: %d ===\n', numel(ghost));
      say('  (WOULD ship unless the deletion is committed)\n');
      for i = 1:numel(ghost), say('  %s\n', ghost(i)); end
      if isempty(untrack) && isempty(ghost)
         say('\n  git and this directory agree\n');
      end
   end

   fprintf('\nwritten to %s\n', outFile);
end

function files = local_git(root)
%LOCAL_GIT  Tracked paths, '/'-separated, or empty when git cannot answer.
   files = strings(0, 1);
   if ~isfolder(fullfile(root, '.git')), return; end
   old = pwd; c = onCleanup(@() cd(old));
   cd(root);
   [st, out] = system('git ls-files -z');
   if st ~= 0, files = strings(0, 1); return; end
   parts = split(string(out), char(0));
   parts = parts(strlength(parts) > 0);
   files = replace(parts, '\', '/');
end
