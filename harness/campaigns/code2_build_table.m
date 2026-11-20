%% code2_build_table.m
% Adds the permutations of an extra-code grid ('code31' RS(31,21) or 'code24'
% RS(24,16); chosen by the global TS_CODE2, see c2_spec) to the permutation
% table, WITHOUT changing any entry already in it.
%
%   >> global TS_CODE2; TS_CODE2 = 'code31';
%   >> clear functions; rehash; code2_build_table
%
% WHY NOT run_PrecomputeInterleavers
% -------------------------------------------------------------------------
% PrecomputeInterleaversGenerator writes each perms_<method> map WHOLE: a map
% holds only the lengths of the current run, so running the usual wrapper
% with TS_GRID_MODE = 'code31' would replace the RS(15,9) permutations the
% published campaign used. That wrapper also sets pruneStale = true, which
% would delete perms_arp (arp is not in the code31 field), and its reuse list
% excludes blockCM and convCM, which depend on n.
%
% So the generator is called with save = false, which builds the new lengths
% only and returns them; this script then MERGES them key by key:
%   key absent from the table          -> added
%   key present, identical permutation -> left as it is
%   key present, DIFFERENT permutation -> nothing is saved, error
% Before saving, the table is copied to a timestamped backup. After saving,
% every entry of the backup is checked to be present and identical.
%
% A method failing at any code31 length stops the script before the merge:
% one refusal aborts every trial at that length (the && (erM == "") chain in
% interleave_all_pc), so the campaign must not start with a hole.
%
% R.T. Sirmen harness, 2026-11-17

clc;
global TS_GRID_MODE TS_SMOKE %#ok<GVMIS>
global TS_CODE2 %#ok<GVMIS>
if isempty(TS_CODE2), c2g = 'code31'; else, c2g = char(TS_CODE2); end
c31Out = campaign_log_dir();
c31Log = fullfile(c31Out, sprintf('%s_build_table_%s.txt', c2g, datestr(now, 'yymmdd_HHMM')));
diary(c31Log); diary on;
try
   S2 = c2_spec();
   if ~isempty(TS_SMOKE) && TS_SMOKE
      error('code2_build_table: TS_SMOKE is set. Clear it: TS_SMOKE = [];');
   end
   TS_GRID_MODE = S2.grid;
   if exist('clearHarnessCaches', 'file') == 2, clearHarnessCaches(); end

   [config, params] = configure_simulation();
   TS_GRID_MODE = [];
   if ~strcmp(config.gridMode, S2.grid) || config.FECn ~= S2.n || config.FECk ~= S2.k || ...
      config.FECt_correct ~= S2.t
      error('code2_build_table: configure_simulation returned %s RS(%d,%d) t=%d, not %s RS(%d,%d) t=%d.', ...
            config.gridMode, config.FECn, config.FECk, config.FECt_correct, S2.grid, S2.n, S2.k, S2.t);
   end
   if ~isempty(config.encodedLengthList)
      error('code2_build_table: encodedLengthList is not empty in this mode; refusing to build extra lengths with this n.');
   end
   if any(strcmp(params.intMethods, 'arp'))
      error('code2_build_table: arp is in the method list; it is undefined on this grid.');
   end

   [tableDir, erD] = find_table_dir();
   if isempty(tableDir), error('code2_build_table: %s', erD); end
   tableFile = fullfile(char(tableDir), 'table_factors_precomputed.mat');
   if exist(tableFile, 'file') ~= 2, error('code2_build_table: %s not found', tableFile); end

   newLens = unique(ceil(getSizeList(config) / config.FECk) * config.FECn);
   fprintf('\n=== %s: building', S2.grid); fprintf(' %d lengths (%d..%d) for %d methods ===\n', ...
           numel(newLens), min(newLens), max(newLens), numel(params.intMethods));
   fprintf('table: %s\n', tableFile);
   if any(mod(newLens, 60) == 0)
      error('code2_build_table: a length is a multiple of 60 (%s) and would share a key with the RS(15,9) grid.', ...
            mat2str(newLens(mod(newLens, 60) == 0)));
   end

   % ---- prime and factor tables, and paramsInt, as run_PrecomputeInterleavers builds them
   [table_primes, table_factors, erM] = PrimeFactorLoader(char(tableDir));
   if erM ~= "", error('PrimeFactorLoader: %s', erM); end
   tables = struct('table_primes', table_primes, 'table_factors', table_factors);
   probeLen = ceil(config.sizeMax / config.FECk) * config.FECn;
   encodedProbe = zeros(1, probeLen);
   Lprobe = 1;
   for a = floor(sqrt(probeLen)):-1:2
      if mod(probeLen, a) == 0, Lprobe = a; break; end
   end
   if Lprobe == 1, Lprobe = 2; end
   Kprobe = ceil(probeLen / Lprobe);
   paramsInt = configure_interleaver_params(params, config, encodedProbe, ...
                                            params.intMethods, Lprobe, Kprobe, tables);

   % ---- build the new lengths only, in memory
   opts = struct('verbose', true, 'save', false, 'pruneStale', false);
   opts.liveMethods  = {'random', 'freqRandom'};
   opts.reuseMethods = {};
   t0 = tic;
   [T, erM] = PrecomputeInterleaversGenerator(char(tableDir), config, paramsInt, tables, opts);
   if erM ~= "", error('PrecomputeInterleaversGenerator: %s', erM); end
   fprintf('built in %.1f min\n', toc(t0)/60);

   rep = T.report;
   bad = rep([rep.failed] > 0);
   if ~isempty(bad)
      for i = 1:numel(bad)
         fprintf(2, '  %-14s FAILED at %s\n', bad(i).method, mat2str(bad(i).failures));
      end
      error(['code2_build_table: %d method(s) cannot be built at some length of this grid. ' ...
             'Nothing was merged. Stopped here; the log has the details.'], numel(bad));
   end
   built = fieldnames(T); built = built(strncmp(built, 'perms_', 6));
   for i = 1:numel(built)
      M = T.(built{i});
      if M.Count ~= numel(newLens)
         error('code2_build_table: %s has %d of %d lengths.', built{i}, M.Count, numel(newLens));
      end
   end

   % ---- merge key by key into the table on disk
   S = load(tableFile, 'precomputed_factors');
   P = S.precomputed_factors;
   nAdded = 0; nSame = 0; clash = {};
   for i = 1:numel(built)
      f = built{i};
      Mnew = T.(f);
      if isfield(P, f)
         Mold = P.(f);
      else
         Mold = containers.Map('KeyType', 'char', 'ValueType', 'any');
      end
      ks = keys(Mnew);
      for k = 1:numel(ks)
         key = ks{k};
         if isKey(Mold, key)
            a = Mold(key); b = Mnew(key);
            if isequal(a.perm(:).', b.perm(:).')
               nSame = nSame + 1;
            else
               clash{end+1} = sprintf('%s %s', f, key); %#ok<SAGROW>
            end
         else
            Mold(key) = Mnew(key);
            nAdded = nAdded + 1;
         end
      end
      P.(f) = Mold;
   end
   if ~isempty(clash)
      fprintf(2, '  %s\n', clash{:});
      error('code2_build_table: %d existing key(s) hold a different permutation. NOTHING SAVED.', numel(clash));
   end
   fprintf('merge: %d entries added, %d already present and identical\n', nAdded, nSame);

   stamp = datestr(now, 'yymmdd_HHMMSS');
   bak = fullfile(char(tableDir), sprintf('table_factors_precomputed_backup_%s_%s.mat', S2.grid, stamp));
   copyfile(tableFile, bak);
   fprintf('backup: %s\n', bak);
   P.(['meta_' S2.grid]) = struct('added', datestr(now), 'lengths', newLens, ...
                          'methods', {params.intMethods}, 'code', sprintf('RS(%d,%d) t=%d', S2.n, S2.k, S2.t), ...
                          'script', 'code2_build_table');
   precomputed_factors = P; %#ok<NASGU>
   save(tableFile, 'precomputed_factors', '-v7.3');
   clear P S T precomputed_factors
   if exist('clearHarnessCaches', 'file') == 2, clearHarnessCaches(); end

   % ---- every entry of the backup must be in the new table, unchanged
   B = load(bak, 'precomputed_factors');   B = B.precomputed_factors;
   N = load(tableFile, 'precomputed_factors'); N = N.precomputed_factors;
   fb = fieldnames(B);
   nChecked = 0; nLost = 0;
   for i = 1:numel(fb)
      if ~isfield(N, fb{i}), fprintf(2, '  field %s missing after save\n', fb{i}); nLost = nLost + 1; continue; end
      if ~isa(B.(fb{i}), 'containers.Map'), continue; end
      Mb = B.(fb{i}); Mn = N.(fb{i});
      kb = keys(Mb);
      for k = 1:numel(kb)
         if ~isKey(Mn, kb{k})
            nLost = nLost + 1; continue;
         end
         a = Mb(kb{k}); c = Mn(kb{k});
         if isstruct(a) && isfield(a, 'perm')
            if ~isequal(a.perm(:).', c.perm(:).'), nLost = nLost + 1; end
         end
         nChecked = nChecked + 1;
      end
   end
   if nLost > 0
      error('code2_build_table: %d old entries are missing or changed. Restore the backup %s.', nLost, bak);
   end
   fprintf('check: %d old entries present and unchanged\n', nChecked);
   fprintf('\nNEXT: clear functions; rehash; code2_smoke\n');

c31_status([c2g '_build_table'], 'OK', c31Log);
catch c31ME
   fprintf(2, '\n*** code2_build_table FAILED ***\n%s\n', getReport(c31ME, 'extended', 'hyperlinks', 'off'));
   c31_status([c2g '_build_table'], 'FAILED', c31Log);
   diary off;
   rethrow(c31ME);
end
diary off;
