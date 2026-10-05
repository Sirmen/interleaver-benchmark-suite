%% run_PrecomputeInterleavers.m
% Builds the permutation half of table_factors_precomputed.mat.
%
% PrecomputeInterleaversGenerator is a FUNCTION now, not a script - it takes
% the sweep's own config and paramsInt instead of a hand-typed N range, so the
% cached lengths are exactly the lengths the sweep will ask for and cannot
% drift from it. This wrapper assembles those arguments the same way
% main_simulation_wrapper does, then calls it.
%
% Run AFTER PrecomputeFactorsGenerator (or skip that if .divs is already
% there), and run clearHarnessCaches AFTERWARDS before any sweep.
%
% R.T. Sirmen harness, 2026

clc; clear; close all;

%% ---------------- USER CONFIG ----------------
% Resolved rather than typed in: find_table_dir looks for
% table_factors_precomputed.mat from here outward and on the MATLAB path.
% Two outputs are requested on purpose: with one, find_table_dir raises
% instead of returning, and the fallback below would never be reached.
% The fallback keeps the historical layout without naming any machine.
[dataDir_PrimeFactor, ~] = find_table_dir();
if isempty(dataDir_PrimeFactor)
   dataDir_PrimeFactor = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data_PrimeFactor');
end

opts.verbose     = true;
opts.save        = true;
opts.liveMethods = {'random', 'freqRandom'};   % never cached - see the generator's header

% perms_cross is a leftover from the old generator: the method is called
% `snake` now and nothing reads perms_cross. true removes stale perms_* fields
% that are not in the current method list. Leaves .divs and everything else.
opts.pruneStale  = true;

% Methods whose entries may be REUSED from the table already on disk instead
% of being rebuilt. Empty = rebuild everything (the safe default).
%
% ONLY LIST METHODS WHOSE .m FILE HAS NOT CHANGED since that table was
% written - a stale permutation is indistinguishable from a fresh one, and the
% sweep that consumes it produces results that look like results.
%
% Untouched by the 2026-08 canonicalisation:
%     srandom  algebraic  latinSquare  turbo  block  matrix  helical
%     helicalScan  snake  spiral  diagonal  goldenRP
% CHANGED - never reuse these against a pre-2026-08 table:
%     arp  drp  multiDim  time  freqDeterm  hierarchical  chaotic
%     prime  convolutional
%
% Worth it for srandom alone: it is O(N^2) and takes over an hour across this
% length set, so an unrelated crash should not cost it twice.
% v2: every method whose .m file is unchanged since the v1 table was built is
% REUSED from that table (all of them - checked by file date on 2026-09-27);
% allIntMethods, so pruneStale drops their entries from the table.
opts.reuseMethods = setdiff(config_for_reuse(), {'blockCM', 'convCM', 'random', 'freqRandom'});
% pruneStale also removes perms_random and perms_freqRandom if the old table
% carries them. That is deliberate: those two are redrawn per frame by design,
% and a cached entry is the very defect that was removed from those files.
% interleaver_generic_pc ignores them anyway, but leaving them in the table
% invites someone to "fix" the omission later.
%% ------------------------------------------------

fprintf('\n=== BUILDING THE PERMUTATION TABLE ===\n');

%% 1. Stale caches out of the way BEFORE we read anything
if exist('clearHarnessCaches', 'file') == 2, clearHarnessCaches(); end

%% 2. Sweep configuration - the single source of truth for which lengths matter
[config, params] = configure_simulation();

% Build the table for EVERY method, not for whatever short list the last
% experiment left in params.intMethods. A method missing from the table still
% works (it takes the live path) but costs the sweep its whole speed-up.
params.intMethods = config.allIntMethods;

% EXPECT THE ENTRY COUNTS TO DROP - that is correct, not a loss.
% The old generator cached a blanket N = 16:510 (691 entries per method). This
% one caches only the lengths the sweep actually asks for:
%     unique(ceil((sizeMin:sizeStep:sizeMax) / FECk) * FECn)
% which for sizeMax = 70 is 7 lengths and for sizeMax = 350 is 38. Everything
% else was never looked up. A length outside the set still works - it takes the
% live path - so widening sizeMax later costs speed, never correctness.
% 2026-08: through getSizeList, so an explicit config.sizeList shows up here
% exactly as the generator will use it. The old arithmetic expression ignored
% sizeList and printed a banner describing a sweep that no longer existed -
% and a banner that lies is worse than no banner.
[msgSizes, sizeDesc] = getSizeList(config);
sweepLens = unique(ceil(msgSizes / config.FECk) * config.FECn);
extraLens = [];
if isfield(config, 'encodedLengthList') && ~isempty(config.encodedLengthList)
   extraLens = setdiff(unique(round(config.encodedLengthList(:).')), sweepLens);
end
allLens = unique([sweepLens, extraLens]);

gm = '(legacy)';
if isfield(config, 'gridMode') && ~isempty(config.gridMode), gm = config.gridMode; end

fprintf('grid mode            : %s\n', gm);
fprintf('message sizes        : %s\n', sizeDesc);
fprintf('FEC                  : n=%d k=%d\n', config.FECn, config.FECk);
fprintf('encoded from sweep   : %d  (%d..%d)\n', numel(sweepLens), min(sweepLens), max(sweepLens));
if ~isempty(extraLens)
   fprintf('extra encoded lengths: %d  (%d..%d)  <- config.encodedLengthList\n', ...
           numel(extraLens), min(extraLens), max(extraLens));
end
fprintf('TABLE WILL COVER     : %d lengths (%d..%d)\n', numel(allLens), min(allLens), max(allLens));
fprintf('methods              : %d\n', numel(params.intMethods));

%% 3. Prime and factor tables
% PrimeFactorLoader, NOT PrimeFactor_PrecomputedLoader - the latter converts
% factors.mat into a .divs map and discards the n<N> records that
% getFactorPairs and interleaver_S look up.
[table_primes, table_factors, erM] = PrimeFactorLoader(char(dataDir_PrimeFactor));
if erM ~= ""
   error('PrimeFactorLoader failed: %s', erM);
end
tables = struct('table_primes', table_primes, 'table_factors', table_factors);

%% 4. Per-method parameters
% configure_interleaver_params needs a representative encoded vector to size
% itself against. The generator overrides the length per entry anyway - only
% the PARAMETER VALUES it sets (seeds, strategies, dither widths, algOpts,
% minMultiplier, extensionPercentage) are used here.
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

fprintf('extensionPercentage_S: %.2f  (S dimensions itself within this budget)\n', ...
        paramsInt.extensionPercentage);
fprintf('minMultiplier        : %d\n\n', paramsInt.minMultiplier);

%% 5. Build
t0 = tic;
[table_precomputed, erM] = PrecomputeInterleaversGenerator( ...
                              char(dataDir_PrimeFactor), config, paramsInt, tables, opts);
if erM ~= ""
   error('PrecomputeInterleaversGenerator failed: %s', erM);
end
fprintf('\nwall clock: %.1f s\n', toc(t0));

%% 6. Drop the caches again so the next thing you run sees the NEW table
if exist('clearHarnessCaches', 'file') == 2, clearHarnessCaches(); end

fprintf('\nNEXT: run DiagnosePrecomputedTable and check it reports no identity\n');
fprintf('      entries and no missing methods before starting the sweep.\n');


function m = config_for_reuse()
   c = configure_simulation();
   m = c.allIntMethods;
end
