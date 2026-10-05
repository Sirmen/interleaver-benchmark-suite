%% DiagnosePrecomputedTable.m
% Diagnose issues with the precomputed interleaver table.
%
% 2026: THE CHECK COULD NOT SEE ITS MOST LIKELY FAILURE
% ---------------------------------------------------------------------------
% The three tests below were: non-empty, long enough, all-unique. An IDENTITY
% permutation (1:N) passes all three - it is non-empty, exactly N long, and
% perfectly unique. But the identity is precisely what the OLD generators
% wrote whenever an interleaver call raised:
%
%     precomputed_factors.(mapFieldName)(key) = ...
%         struct('perm', 1:N, 'K', N, 'L', 1, 'Q', 1, 'R', 1, 'adjN', N);
%
% printed only when N <= 100. So a table where a whole method had collapsed to
% "do nothing" was reported as "No problems found!" - and the sweep then
% measured an interleaver that does not interleave, which reads as a poor
% baseline rather than a broken one.
%
% Identity and near-identity detection added below. Also flags methods whose
% entry COUNT is short against the requested range, which is how a partially
% built table shows up.

% Resolved rather than typed in: find_table_dir looks for
% table_factors_precomputed.mat from here outward and on the MATLAB path.
% Two outputs are requested on purpose: with one, find_table_dir raises
% instead of returning, and the fallback below would never be reached.
% The fallback keeps the historical layout without naming any machine.
[dataDir, ~] = find_table_dir();
if isempty(dataDir)
   dataDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data_PrimeFactor');
end

% Nrange DEFAULTS TO THE SWEEP'S OWN ENCODED LENGTHS, not a blanket 16:510.
% The generator caches exactly the lengths the sweep asks for -
%     unique(ceil((sizeMin:sizeStep:sizeMax) / FECk) * FECn)
% - which for the current config is a handful, not 495. Checking against
% 16:510 made a correct table report "487 of 495 requested lengths absent"
% for every method: alarming, and wrong. Those 487 were never cached because
% they are never requested.
try
    [cfgD, ~] = configure_simulation();
    Nrange = unique(ceil((cfgD.sizeMin:cfgD.sizeStep:cfgD.sizeMax) / cfgD.FECk) * cfgD.FECn);
    fprintf('Nrange from configure_simulation: %d encoded lengths (%d..%d)\n', ...
            numel(Nrange), min(Nrange), max(Nrange));
catch
    Nrange = 16:510;
    fprintf(2, 'configure_simulation unavailable - falling back to 16:510.\n');
end

DiagnosePrecomputedTable_(dataDir, Nrange);

%%%

function DiagnosePrecomputedTable_(dataDir, Nrange)
% Diagnose problems in precomputed table
%
% USAGE:
%   DiagnosePrecomputedTable(dataDir, 16:125)

if nargin < 2
    Nrange = 16:125;
end

fprintf('=== Diagnosing Precomputed Table ===\n');
fprintf('Data directory: %s\n', dataDir);
fprintf('Checking N = %d to %d\n\n', min(Nrange), max(Nrange));

% Load table
[table, erM] = PrecomputedInterleaverLoader(dataDir);
if erM ~= ""
    error('Failed to load table: %s', erM);
end

% Get all interleaver types
interleaverTypes = fieldnames(table);
interleaverTypes = interleaverTypes(startsWith(interleaverTypes, 'perms_'));

fprintf('Found %d interleaver types in table:\n', length(interleaverTypes));

% Check each type
problemTypes = {};
for i = 1:length(interleaverTypes)
    typeName = interleaverTypes{i};
    typeShort = strrep(typeName, 'perms_', '');
    
    permMap = table.(typeName);
    fprintf('  %s: %d entries\n', typeShort, permMap.Count);
    
    % Check for problems in this type
    problems = 0; nIdentity = 0; nMissing = 0; shown = 0;
    for N = Nrange
        key = sprintf('N_%d', N);
        if ~permMap.isKey(key)
            nMissing = nMissing + 1;
            continue;
        end
        entry = permMap(key);
        p = entry.perm(:).';

        if isempty(p)
            problems = problems + 1;
            if shown < 5, fprintf('    [X] N=%d: Empty permutation\n', N); shown = shown + 1; end
        elseif length(p) < N
            problems = problems + 1;
            if shown < 5
                fprintf('    [X] N=%d: too short (length=%d, need=%d)\n', N, length(p), N);
                shown = shown + 1;
            end
        elseif length(unique(p)) ~= length(p)
            problems = problems + 1;
            if shown < 5, fprintf('    [X] N=%d: non-unique\n', N); shown = shown + 1; end
        elseif isequal(p, 1:length(p))
            % THE IDENTITY. Passes every structural test and interleaves nothing.
            nIdentity = nIdentity + 1;
            problems = problems + 1;
            if shown < 5
                fprintf('    [X] N=%d: IDENTITY permutation - this method does not interleave here\n', N);
                shown = shown + 1;
            end
        end
    end
    if shown >= 5 && problems > shown
        fprintf('    ... and %d more\n', problems - shown);
    end

    if nMissing > 0
        fprintf(['    [!] %d of %d sweep lengths absent - these run live ' ...
                 '(correct, just slower)\n'], nMissing, numel(Nrange));
    end
    if nIdentity > 0
        fprintf('    [!] %d IDENTITY entries - almost certainly an old generator''s\n', nIdentity);
        fprintf('        silent fallback, not a real permutation. Rebuild this method.\n');
    end

    if problems > 0
        problemTypes{end+1} = typeShort;
        fprintf('    [!] %d problem(s) in %s\n', problems, typeShort);
    end
end

%% Methods the sweep expects but the table does not carry
expected = {'block','matrix','helical','helicalScan','diagonal','spiral','snake', ...
            'time','freqDeterm','hierarchical','multiDim','latinSquare','chaotic', ...
            'prime','algebraic','turbo','convolutional','srandom','goldenRP','drp','arp','S'};
present = strrep(interleaverTypes, 'perms_', '');
absent  = setdiff(expected, present);
stale   = intersect(present, {'cross'});   % renamed to snake in 2026

if ~isempty(absent)
    fprintf('\n[!] NOT IN TABLE: %s\n', strjoin(absent, ', '));
    fprintf('    These fall through to a live call on every frame - correct results,\n');
    fprintf('    but no speed-up, and `random`/`freqRandom` are meant to.\n');
end
if ~isempty(stale)
    fprintf('\n[!] STALE NAME IN TABLE: %s\n', strjoin(stale, ', '));
    fprintf('    `cross` was renamed `snake` in 2026. Nothing reads perms_cross now.\n');
end

fprintf('\n');

if isempty(problemTypes)
    fprintf('[OK] No problems found!\n');
else
    fprintf('[X] Problems found in: %s\n', strjoin(problemTypes, ', '));
    fprintf('\n');
    fprintf('RECOMMENDATION\n');
    fprintf('  1) [table_pc, erM] = PrecomputeInterleaversGenerator(dataDir, config, paramsInt, tables);\n');
    fprintf('     (the generator takes the sweep config now, not an N range - it\n');
    fprintf('      derives the encoded lengths from FECn/FECk and sizeMin..sizeMax)\n');
    fprintf('  2) clearHarnessCaches      %% the loaders cache by directory, not by\n');
    fprintf('                             %% timestamp, and would serve the old table\n');
    fprintf('  3) re-run this diagnostic\n');
end

end


%% FixPrecomputedTable.m
% Regenerate only the problematic N values

function FixPrecomputedTable(dataDir, problemNs, options)
% Fix specific N values in existing precomputed table
%
% USAGE:
%   FixPrecomputedTable(dataDir, 121:125)

if nargin < 3
    options = struct();
end
if ~isfield(options, 'verbose'), options.verbose = true; end
if ~isfield(options, 'padSymbol'), options.padSymbol = 0; end
if ~isfield(options, 'maxExtPct'), options.maxExtPct = 0.50; end

fprintf('\n=== Fixing Precomputed Table ===\n');
fprintf('Data directory: %s\n', dataDir);
fprintf('Fixing N = ');
disp(problemNs);
fprintf('\n');

% Load existing table
file = fullfile(dataDir, 'table_factors_precomputed.mat');
if ~exist(file, 'file')
    error('Table file not found: %s', file);
end

fprintf('Loading existing table...\n');
data = load(file);

if isfield(data, 'precomputed_factors')
    table = data.precomputed_factors;
elseif isfield(data, 'table')
    table = data.table;
else
    error('Invalid table format');
end

% Get interleaver configs
interleaverConfigs = {
    struct('name', 'random',          'func', 'interleaver_random')
    struct('name', 'matrix',          'func', 'interleaver_matrix')
    struct('name', 'helical',         'func', 'interleaver_helical')
    struct('name', 'helicalScan',     'func', 'interleaver_helicalScan')
    struct('name', 'cross',           'func', 'interleaver_cross')
    struct('name', 'spiral',          'func', 'interleaver_spiral')
    struct('name', 'diagonal',        'func', 'interleaver_diagonal')
    struct('name', 'hierarchical',    'func', 'interleaver_hierarchical')
    struct('name', 'multiDim',        'func', 'interleaver_multiDim')
    struct('name', 'latinSquare',     'func', 'interleaver_latinSquare')
    struct('name', 'time',            'func', 'interleaver_time')
    struct('name', 'freqRandom',      'func', 'interleaver_freqRandom')
    struct('name', 'freqDeterm',      'func', 'interleaver_freqDeterm')
    struct('name', 'chaotic',         'func', 'interleaver_chaotic')
    struct('name', 'prime',           'func', 'interleaver_prime')
    struct('name', 'block',           'func', 'interleaver_block')
    struct('name', 'algebraic',       'func', 'interleaver_algebraic')
    struct('name', 'turbo',           'func', 'interleaver_turbo')
    struct('name', 'convolutional',   'func', 'interleaver_convolutional')
    struct('name', 'S',               'func', 'interleaver_S')
};

% Filter to available functions
availableConfigs = {};
for i = 1:length(interleaverConfigs)
    if exist(interleaverConfigs{i}.func, 'file') == 2
        availableConfigs{end+1} = interleaverConfigs{i};
    end
end

fprintf('Regenerating %d N values for %d interleavers...\n', ...
    length(problemNs), length(availableConfigs));

% Fix each N
fixed = 0;
failed = 0;

for N = problemNs
    key = sprintf('N_%d', N);
    
    % Update divisors if needed
    if ~table.divs.isKey(N)
        table.divs(N) = computeDivisors(N);
    end
    
    for cfg_idx = 1:length(availableConfigs)
        cfg = availableConfigs{cfg_idx};
        mapFieldName = ['perms_' cfg.name];
        
        try
            entry = callInterleaver(cfg.func, N, options);
            
            % Verify entry is valid
            if isempty(entry.perm) || length(entry.perm) < N
                error('Generated invalid permutation');
            end
            
            table.(mapFieldName)(key) = entry;
            fixed = fixed + 1;
            
        catch ME
            % NO IDENTITY FALLBACK. Writing struct('perm', 1:N, ...) here is what
            % put undetectable identity permutations into the table in the first
            % place - see the header. A failure is left as a MISSING entry, which
            % makes interleaver_generic_pc take the live path for that length:
            % slower, correct, and visible.
            fprintf('  [X] %s(N=%d) failed: %s  (left missing - will run live)\n', ...
                    cfg.name, N, ME.message);
            if table.(mapFieldName).isKey(key)
                remove(table.(mapFieldName), key);
            end
            failed = failed + 1;
        end
    end
    
    if options.verbose
        fprintf('  Fixed N=%d\n', N);
    end
end

% Save updated table
fprintf('\nSaving updated table...\n');
precomputed_factors = table;
save(file, 'precomputed_factors', '-v7.3');

fprintf('[OK] Done!\n');
fprintf('   Fixed: %d entries\n', fixed);
fprintf('   Failed: %d entries (left missing - they will run live)\n', failed);

end


%% Helper functions

function divs = computeDivisors(n)
    divs = [];
    sqrtN = floor(sqrt(n));
    for i = 1:sqrtN
        if mod(n, i) == 0
            divs = [divs, i];
            if i ~= n/i
                divs = [divs, n/i];
            end
        end
    end
    divs = sort(unique(divs));
end

function entry = callInterleaver(funcName, N, options)
    dummy = 1:N;
    
    % Try different signatures
    try
        [vOut, perm, L, K, Q, R, erM] = feval(funcName, dummy, options.padSymbol, options.maxExtPct);
        if erM == ""
            entry = struct('perm', perm(:)', 'L', L, 'K', K, 'Q', Q, 'R', R, 'adjN', length(perm));
            return;
        end
    catch
    end
    
    try
        [vOut, perm, L, K] = feval(funcName, dummy, options.padSymbol, options.maxExtPct);
        entry = struct('perm', perm(:)', 'L', L, 'K', K, 'Q', 1, 'R', 1, 'adjN', length(perm));
        return;
    catch
    end
    
    try
        [vOut, perm] = feval(funcName, dummy, options.padSymbol);
        entry = struct('perm', perm(:)', 'L', 1, 'K', length(perm), 'Q', 1, 'R', 1, 'adjN', length(perm));
        return;
    catch
    end
    
    try
        [vOut, perm] = feval(funcName, dummy);
        entry = struct('perm', perm(:)', 'L', 1, 'K', length(perm), 'Q', 1, 'R', 1, 'adjN', length(perm));
        return;
    catch ME
        error('All signatures failed: %s', ME.message);
    end
end
