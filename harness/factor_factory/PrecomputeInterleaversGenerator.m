function [table_precomputed, erM] = PrecomputeInterleaversGenerator(dataSavePath, config, params, tables, opts)
%PRECOMPUTEINTERLEAVERSGENERATOR  Build the permutation lookup table.
%
%   [table_precomputed, erM] = PrecomputeInterleaversGenerator(dataSavePath, config, params, tables)
%   [...] = PrecomputeInterleaversGenerator(..., opts)
%
% Precomputes, for every method and every encoded length in the sweep, the
% permutation that interleave_all_pc will look up instead of recomputing on
% every trial. The saving is concentrated in a few methods:
%
%     srandom     O(N^2) greedy with backtracking, ~1.5 s at N = 510
%     algebraic   parameter search, 8-14 s for N with a small radical
%     arp         offset search
%     convolutional / chaotic / prime   moderate
%     block, matrix, time, snake, goldenRP, multiDim   closed form, negligible
%
% TWO METHODS ARE DELIBERATELY EXCLUDED
% -------------------------------------
% `random` and `freqRandom` MUST be redrawn every trial. Precomputing them
% would reinstate exactly the defect that was just fixed: the previous code
% called rng(2106) inside the interleaver, so every Monte-Carlo trial at a
% given N used the identical permutation and the reported variance for those
% baselines reflected channel noise only. A lookup table has the same effect.
% They are listed in opts.liveMethods and interleave_all_pc must fall through
% to the live call for them.
%
% `chaotic` is NOT excluded: it is a deterministic design (one permutation per
% length by construction), so caching it is correct.
%
% WHAT ELSE CHANGED FROM THE PREVIOUS GENERATOR
% The old version wrapped every call in try/catch and, on ANY failure, stored
% struct('perm', 1:N, ...) - the IDENTITY - printing a message only when
% opts.verbose && N <= 100. A single crash therefore turned a baseline into
% the identity permutation for the whole sweep, silently. Failures are now
% recorded as failures: no entry is written, the length is listed in
% report.failures, and the run prints a summary.
%
% OUTPUT
%   table_precomputed.perms_<method>  containers.Map keyed 'N_<len>' ->
%       struct(perm, invPerm, L, K, adjN, info)
%
%   invPerm is stored so deinterleaving costs O(N) instead of the O(N log N)
%   sort that deinterleaver_universal performs on every call. Use it as
%       deinterleaved = interleaved(invPerm);   deinterleaved = deinterleaved(1:N);
%   table_precomputed.meta            build date, method list, N range
%   table_precomputed.report          per-method timing, failures, live list
%
% R.T. Sirmen harness, rewritten 2026

   erM = ""; table_precomputed = struct();

   if nargin < 5, opts = struct(); end
   if ~isfield(opts,'verbose'),     opts.verbose = true; end
   if ~isfield(opts,'save'),        opts.save = true;    end
   if ~isfield(opts,'liveMethods'), opts.liveMethods = {'random','freqRandom'}; end
   if ~isfield(opts,'pruneStale'),  opts.pruneStale = false;  end

   % opts.reuseMethods - methods whose entries may be taken from the table
   % already on disk instead of being rebuilt.
   %
   % ONLY LIST A METHOD WHOSE .m FILE HAS NOT CHANGED SINCE THAT TABLE WAS
   % WRITTEN. Reuse is a silent operation: a stale permutation looks exactly
   % like a fresh one, and the sweep that consumes it produces results that
   % look exactly like results. This is the same failure mode as the loader
   % caches that clearHarnessCaches exists to prevent, so the list is
   % deliberately empty by default and must be opted into per run.
   %
   % The case it is for: srandom is O(N^2) and takes over an hour across this
   % length set. Rebuilding it because an unrelated method crashed is pure
   % waste. srandom, algebraic, latinSquare and turbo were untouched by the
   % 2026-08 canonicalisation; arp, drp, multiDim, time, freqDeterm,
   % hierarchical, chaotic, prime and convolutional were NOT - never reuse
   % those against a pre-2026-08 table.
   if ~isfield(opts,'reuseMethods'), opts.reuseMethods = {}; end

   try
      methods = params.intMethods;
      lens    = local_encodedLengths(config);

      if opts.verbose
         fprintf('\n=== PRECOMPUTING INTERLEAVER TABLE ===\n');
         fprintf('methods : %d   lengths : %d  (%d..%d)\n', ...
                 numel(methods), numel(lens), min(lens), max(lens));
         fprintf('live (not cached) : %s\n\n', strjoin(opts.liveMethods, ', '));
      end

      report = struct('method', {}, 'seconds', {}, 'built', {}, 'failed', {}, 'failures', {});

      for mi = 1:numel(methods)
         method = methods{mi};

         if any(strcmp(opts.liveMethods, method))
            if opts.verbose
               fprintf('%-14s SKIPPED - must be redrawn per trial\n', method);
            end
            report(end+1) = struct('method', method, 'seconds', 0, 'built', 0, ...
                                   'failed', 0, 'failures', []);
            continue;
         end

         M = containers.Map('KeyType','char','ValueType','any');
         t0 = tic; nFail = 0; failures = [];

         reuseThis = any(strcmp(opts.reuseMethods, method));
         nReused = 0;

         for li = 1:numel(lens)
            N = lens(li);

            % --- reuse an already-computed entry, if allowed for this method
            % Only for methods whose FILE HAS NOT CHANGED - see opts.reuseMethods
            % in the header. srandom alone costs over an hour to rebuild, and
            % rebuilding it after an unrelated crash is pure waste; reusing a
            % method whose implementation changed is silent corruption. The
            % list is explicit for exactly that reason.
            if reuseThis
               oldEntry = local_existingEntry(dataSavePath, method, N);
               if ~isempty(oldEntry)
                  M(sprintf('N_%d', N)) = oldEntry;
                  nReused = nReused + 1;
                  continue;
               end
            end

            % local_build can THROW rather than return a message - a renamed
            % parameter field, an interleaver raising its own error. Before
            % 2026-08 that escaped to the function-level catch and destroyed
            % the entire build, including every method already computed. One
            % length failing is a length failing.
            try
               [perm, L, K, adjN, info, e] = local_build(method, N, config, params, tables);
            catch MEb
               perm = []; L = 0; K = 0; adjN = 0; info = struct();
               e = sprintf('threw: %s', MEb.message);
            end

            if ~isempty(char(e)) || isempty(perm)
               nFail = nFail + 1; failures(end+1) = N;
               continue;                       % NO identity fallback
            end
            ip = zeros(1, numel(perm));
            ip(perm) = 1:numel(perm);        % inverse, computed once
            % Q and R are stored even though nothing computes with them:
            % interleaver_S_pc / interleaver_algebraic_pc / interleaver_cross_pc
            % read info.Q and info.R UNGUARDED off the cached entry, so an entry
            % without those fields aborts the run with "Unrecognized field name
            % Q" the first time a cached length is hit. Cheap insurance.
            Qv = 1; Rv = 1;
            if isstruct(info)
               if isfield(info, 'Q'), Qv = info.Q; elseif isfield(info, 'f1'), Qv = info.f1; end
               if isfield(info, 'R'), Rv = info.R; elseif isfield(info, 'f2'), Rv = info.f2; end
            end
            M(sprintf('N_%d', N)) = struct('perm', perm, 'invPerm', ip, ...
                                           'L', L, 'K', K, 'Q', Qv, 'R', Rv, ...
                                           'adjN', adjN, 'info', info);
         end

         secs = toc(t0);
         table_precomputed.(sprintf('perms_%s', method)) = M;
         report(end+1) = struct('method', method, 'seconds', secs, ...
                                'built', M.Count, 'failed', nFail, 'failures', failures);

         if opts.verbose
            tag = '';
            if nReused > 0, tag = sprintf('   (%d reused from disk)', nReused); end
            if nFail == 0
               fprintf('%-14s %6.1f s   %4d lengths%s\n', method, secs, M.Count, tag);
            else
               fprintf('%-14s %6.1f s   %4d lengths%s   *** %d FAILED: %s\n', ...
                       method, secs, M.Count, tag, nFail, mat2str(failures(1:min(8,end))));
            end
         end
      end

      table_precomputed.meta = struct('built', datestr(now), ...
                                      'methods', {methods}, ...
                                      'lengths', lens, ...
                                      'liveMethods', {opts.liveMethods});
      table_precomputed.report = report;

      if opts.verbose
         tot = sum([report.seconds]);
         nf  = sum([report.failed]);
         fprintf('\ntotal %.1f s', tot);
         if nf > 0, fprintf('   *** %d (method,length) pairs failed', nf); end
         fprintf('\n');
      end

      if opts.save && ~isempty(dataSavePath)
         [savedFile, erS] = local_save(table_precomputed, dataSavePath, opts.verbose, opts.pruneStale);
         if ~isempty(char(erS)), erM = erS; return; end
         if opts.verbose, fprintf('saved: %s\n', savedFile); end
      end

   catch ME
      erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   end
end

%% ------------------------------------------------------------------------
function lens = local_encodedLengths(config)
% Every encoded length the sweep will actually ask for.
% Shares getSizeList with run_simulations_sci so the table is built for
% exactly the lengths the sweep will request - including an explicit
% config.sizeList, which the standards-aligned grid needs.
%
% PLUS config.encodedLengthList, a UNION of extra encoded lengths to build
% whether or not the current FEC produces them.
%
% WHY THE UNION EXISTS: the permutation table is keyed by ENCODED length, not
% by message length. Change the FEC and the same message grid maps to a
% completely different set of encoded lengths - RS(15,9) sends K = 36m to
% L = 60m, an LDPC(n,k) sends it to ceil(36m/k)*n. A table built for one code
% is simply missing the other code's lengths, and the sweep then silently
% falls back to live generation (or fails) for every method.
%
% Precomputing an extra length costs generator time once; it costs the sweep
% nothing. So the right move when a second FEC is coming is to build the union
% now and never regenerate. Set, for example:
%
%     config.encodedLengthList = 180 * (1:16);   % an LDPC(180,90) grid
%
% and the table will carry both families. Lengths are deduplicated, so any
% overlap is free.
   n = config.FECn; k = config.FECk;
   sizes = getSizeList(config);
   lens = ceil(sizes / k) * n;

   if isfield(config, 'encodedLengthList') && ~isempty(config.encodedLengthList)
      extra = round(config.encodedLengthList(:).');
      extra = extra(extra >= 1);
      lens  = [lens, extra];
   end

   lens = unique(lens);
end

function [perm, L, K, adjN, info, erM] = local_build(method, N, config, params, tables)
% One method, one length. Uses a dummy payload: only the permutation matters.
   perm = []; L = 0; K = 0; adjN = 0; info = struct(); erM = "";
   x   = 1:N;
   pad = config.padSymbol;
   mx  = config.maxExtensionPercentage;
   tp  = tables.table_primes;
   tf  = tables.table_factors;
   P   = params;

   switch method
      case 'block'
         Lb = local_estimateL(N);
         [~, perm, erM] = interleaver_block(x, Lb, pad, mx); L = Lb; K = ceil(N/Lb);
      case 'matrix'
         [~, perm, L, K, erM] = interleaver_matrix(x, pad, mx);
      case 'helical'
         [~, perm, L, K, erM] = interleaver_helical(x, pad, mx);
      case 'helicalScan'
         [~, perm, L, K, erM] = interleaver_helicalScan(x, pad, mx);
      case 'diagonal'
         [~, perm, erM, L, K] = interleaver_diagonal(x, [], [], pad, mx);
      case 'spiral'
         [~, perm, L, K, erM] = interleaver_spiral(x, pad, mx);
      case 'snake'
         [~, perm, L, K, erM] = interleaver_snake(x, pad, mx, tp, tf);
      case 'time'
         [~, perm, L, K, erM] = interleaver_time(x, pad, mx);
      case 'freqDeterm'
         [~, perm, L, K, ~, ~, erM] = interleaver_freqDeterm(x, pad, mx);
      case 'chaotic'
         [~, perm, erM] = interleaver_chaotic(x, local_get(P,'rChaotic',3.9), ...
                                                 local_get(P,'xChaotic',0.5));
      case 'prime'
         [~, perm, L, K, erM] = interleaver_prime(x, pad, mx, tp);
      case 'latinSquare'
         [~, perm, L, K, erM] = interleaver_latinSquare(x, mx);
      case 'algebraic'
         [~, perm, L, K, info, erM] = interleaver_algebraic(x, pad, mx, tp, tf, ...
                                                            local_get(P,'algOpts',struct()));
      case 'turbo'
         [~, perm, info, erM] = interleaver_turbo(x, local_estimateL(N), pad, mx);
      case 'convolutional'
         [~, perm, L, K, erM] = interleaver_convolutional(x, [], [], pad, mx);
      case 'blockCM'
         % v2 - must match interleaver_generic_pc exactly
         nC = config.FECn;
         [~, perm, erM] = interleaver_block(x, nC, pad, mx); L = nC; K = ceil(N/nC);
      case 'convCM'
         % v2 - must match interleaver_generic_pc exactly
         nC = config.FECn;
         Dc = max(1, floor((N / nC) / nC));
         [~, perm, L, K, erM] = interleaver_convolutional(x, nC, Dc, pad, mx);
      case 'hierarchical'
         [~, perm, L, K, Q, R, erM] = interleaver_hierarchical(x, pad, mx);
         info = struct('Q', Q, 'R', R);
      case 'multiDim'
         [~, perm, dims, ax, erM] = interleaver_multiDim(x, pad, mx, ...
                                                         local_get(P,'multiDim_nDims',3));
         info = struct('dims', dims, 'axisOrder', ax);
         if ~isempty(dims), L = dims(1); K = dims(end); info.Q = numel(dims); end
      case 'srandom'
         [~, perm, info, erM] = interleaver_srandom(x, local_get(P,'srandom_spreadS',[]), ...
                                                       local_get(P,'srandom_seed',2106));
      case 'goldenRP'
         [~, perm, info, erM] = interleaver_goldenRP(x, local_get(P,'goldenRP_offset',0));
      % 2026-08: these two matched the PRE-canonicalisation signatures and read
      % fields that no longer exist (drp_ditherW, drp_seed, arp_classC). A
      % missing field is a hard MATLAB error, not a returned message, so it
      % escaped the per-length handling and aborted the whole build - after
      % srandom had already spent 65 minutes that were then thrown away.
      % Every parameter here now goes through local_get, so a renamed or
      % absent field costs a default value, never a run.
      case 'drp'
         [~, perm, info, erM] = interleaver_drp(x, local_get(P,'drp_ditherM',[]), ...
                                                   local_get(P,'drp_strideP',[]));
         if isstruct(info) && isfield(info,'M'), L = info.M; info.Q = info.p; end
      case 'arp'
         % Argument 2 is ignored by the canonical file: C is fixed at 4.
         [~, perm, info, erM] = interleaver_arp(x, [], local_get(P,'arp_strideP',[]), ...
                                                       local_get(P,'arp_offsetsQ',[]));
         if isstruct(info) && isfield(info,'C'), L = info.C; info.Q = info.P0; end
      case 'S'
         [~, perm, L, K, erM] = interleaver_S(x, pad, local_get(P,'extensionPercentage',0.0), ...
                                              local_get(P,'minMultiplier',3), tp, tf, ...
                                              local_get(P,'pairStrategy',"minSum"), ...
                                              local_get(P,'swapStrategy',"oddOnly"));
      otherwise
         erM = sprintf('PrecomputeInterleaversGenerator: unknown method "%s"', method);
         return;
   end

   if ~isempty(perm), adjN = numel(perm); end
end

function e = local_existingEntry(dataSavePath, method, N)
%LOCAL_EXISTINGENTRY  Fetch one cached entry from the table already on disk.
%
%   Returns [] when the file, the field or the key is absent - every one of
%   those simply means "build it".
%
%   The .mat is read ONCE per process and held in a persistent, because this
%   is called for every (method, length) pair and the file is large. The cache
%   key is the path; if you overwrite the table mid-session, clear this
%   function. It is only ever read, never written.
   persistent cachedTable cachedPath
   e = [];
   if isempty(dataSavePath), return; end

   f = fullfile(char(dataSavePath), 'table_factors_precomputed.mat');
   if ~isequal(cachedPath, f)
      cachedTable = [];
      cachedPath  = f;
      if exist(f, 'file') == 2
         try
            S = load(f, 'precomputed_factors');
            if isfield(S, 'precomputed_factors')
               cachedTable = S.precomputed_factors;
            end
         catch
            cachedTable = [];
         end
      end
   end
   if isempty(cachedTable), return; end

   fld = ['perms_' method];
   if ~isfield(cachedTable, fld), return; end
   M = cachedTable.(fld);
   key = sprintf('N_%d', N);
   if ~isa(M, 'containers.Map') || ~M.isKey(key), return; end

   cand = M(key);
   % Only reuse something that is actually a permutation of the right length.
   % A stale entry from a different grid, or the identity the pre-2026
   % generator wrote on failure, must not slip through as "already done".
   if ~isstruct(cand) || ~isfield(cand, 'perm'), return; end
   p = cand.perm(:).';
   if numel(p) ~= N || ~isequal(sort(p), 1:N), return; end

   e = cand;
end

function v = local_get(P, name, dflt)
%LOCAL_GET  Read a parameter, or fall back. Never throws on a missing field.
%   The whole point: a renamed parameter must cost a default, not a build.
   if isstruct(P) && isfield(P, name) && ~isempty(P.(name))
      v = P.(name);
   else
      v = dflt;
   end
end

function L = local_estimateL(N)
   L = 1;
   for a = floor(sqrt(N)):-1:2
      if mod(N, a) == 0, L = a; break; end
   end
   if L == 1, L = 2; end
end

%% ------------------------------------------------------------------------
function [outFile, erM] = local_save(table_precomputed, dataSavePath, verbose, pruneStale)
%LOCAL_SAVE  Merge the new permutations into the harness's existing table.
%
% WHY THIS IS A MERGE AND NOT A PLAIN save()
% ---------------------------------------------------------------------------
% `table_factors_precomputed.mat` is ONE file holding TWO different things:
%
%     precomputed_factors.divs        <- divisor lists, keyed by n
%     precomputed_factors.perms_*     <- one containers.Map per method
%
% Only the perms_* half is rebuilt here. The divs half is produced by
% PrecomputeFactorsGenerator and is read at run time by
% choose_balanced_factors and precompute_hierarchical_perms - i.e. by half the
% matrix-shaped interleavers. An earlier draft of this generator saved a bare
% `table_precomputed` variable to a NEW filename, which would have been invisible
% to PrecomputedInterleaverLoader (it looks for `table` or `precomputed_factors`
% inside table_factors_precomputed.mat); and writing the same filename WITHOUT
% merging would have silently destroyed divs. Both failure modes are quiet:
% choose_balanced_factors just falls back to trial division and everything keeps
% running, slower and - for hierarchical - differently dimensioned.
%
% So: load what is there, replace only the perms_* fields plus meta/report,
% keep everything else byte for byte, and back up the old file first.
   outFile = ''; erM = "";
   try
      if ~exist(dataSavePath, 'dir'), mkdir(dataSavePath); end
      outFile = fullfile(dataSavePath, 'table_factors_precomputed.mat');

      precomputed_factors = struct();
      if exist(outFile, 'file')
         old = load(outFile);
         if isfield(old, 'precomputed_factors')
            precomputed_factors = old.precomputed_factors;
         elseif isfield(old, 'table')
            precomputed_factors = old.table;
         end

         bak = fullfile(dataSavePath, ...
                        sprintf('table_factors_precomputed_backup_%s.mat', datestr(now,'yymmdd_HHMMSS')));
         copyfile(outFile, bak);
         if verbose, fprintf('backup: %s\n', bak); end
      else
         fprintf(2, ['[PrecomputeInterleaversGenerator] WARNING: %s does not exist.\n' ...
                     '   Writing a perms-only table. The divisor table (.divs) will be\n' ...
                     '   ABSENT - run PrecomputeFactorsGenerator too, or\n' ...
                     '   choose_balanced_factors falls back to trial division.\n'], outFile);
      end

      % Stale perms_* left by an older generator: a method that no longer
      % exists under that name. perms_cross is the live example - the file was
      % renamed to snake, nothing reads perms_cross, and it sits in the table
      % looking like a 691-entry method that simply never gets used. Harmless
      % until someone reads the summary and counts it.
      oldFields   = fieldnames(precomputed_factors);
      oldPerms    = oldFields(strncmp(oldFields, 'perms_', 6));
      newFields   = fieldnames(table_precomputed);
      stalePerms  = setdiff(oldPerms, newFields);
      if ~isempty(stalePerms)
         if pruneStale
            precomputed_factors = rmfield(precomputed_factors, stalePerms);
            fprintf('pruned stale: %s\n', strjoin(stalePerms', ', '));
         else
            fprintf(2, ['[!] stale perms_* left in the table: %s\n' ...
                        '    Nothing reads these. opts.pruneStale = true removes them.\n'], ...
                    strjoin(stalePerms', ', '));
         end
      end

      % Replace only what this generator owns.
      nPerm = 0;
      for i = 1:numel(newFields)
         precomputed_factors.(newFields{i}) = table_precomputed.(newFields{i});
         if strncmp(newFields{i}, 'perms_', 6), nPerm = nPerm + 1; end
      end

      if verbose
         kept = setdiff(fieldnames(precomputed_factors), newFields);
         fprintf('merged: %d perms_* rebuilt, %d existing field(s) preserved', nPerm, numel(kept));
         if ~isempty(kept), fprintf(' (%s)', strjoin(kept', ', ')); end
         fprintf('\n');
         if ~isfield(precomputed_factors, 'divs')
            fprintf(2, '   WARNING: no .divs field in the merged table.\n');
         end
      end

      % -v7.3 for the >2 GB tables a full sweep can produce. Octave builds
      % without HDF5 reject it, so fall back rather than lose the run's work.
      try
         save(outFile, 'precomputed_factors', '-v7.3');
      catch
         save(outFile, 'precomputed_factors', '-v7');
         fprintf(2, '   note: -v7.3 unavailable, saved as -v7 (2 GB variable limit)\n');
      end

   catch ME
      erM = sprintf('PrecomputeInterleaversGenerator/local_save: line %d: %s', ME.stack(1).line, ME.message);
   end
end
