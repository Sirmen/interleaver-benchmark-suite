%% PrecomputeFactorsGenerator.m
% Builds the DIVISOR half of table_factors_precomputed.mat.
%
% READ THIS BEFORE RUNNING - THE OLD VERSION DESTROYED THE PERMUTATION TABLE
% =========================================================================
% table_factors_precomputed.mat holds TWO independent things:
%
%     precomputed_factors.divs      <- divisor lists      (THIS script)
%     precomputed_factors.perms_*   <- permutation tables (PrecomputeInterleaversGenerator)
%
% The previous version of this file built BOTH. It opened with
%
%     precomputed_factors = struct();
%     precomputed_factors.perms_random = mkmap();   ... etc
%
% i.e. FRESH, EMPTY maps, then filled them with its own interleaver calls and
% saved the whole struct. It did load the existing file first - but only to
% pass it to the interleavers as `table_factors_src`; it never merged it back.
%
% So running this script after PrecomputeInterleaversGenerator silently:
%   * threw away every permutation the other generator had just built,
%   * replaced them with its own - including the IDENTITY PERMUTATION for any
%     (method, N) whose call raised, printed only when N <= 100,
%   * wrote `perms_cross` instead of `perms_snake`, and
%   * omitted srandom, goldenRP, drp and arp entirely, so those four methods
%     would fall through to a live call on every single frame of the sweep.
%
% None of that raises an error. The run just produces numbers that are wrong
% in a direction that flatters nothing in particular - a baseline reduced to
% the identity permutation looks like a very bad interleaver, which is exactly
% the kind of result nobody questions.
%
% THIS VERSION ONLY BUILDS divs, AND IT MERGES.
% Permutations belong to PrecomputeInterleaversGenerator. Run order no longer
% matters, and neither script can clobber the other.
%
% R.T. Sirmen harness, rewritten 2026

clc; close all; clear;

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
outputDir = char(dataDir_PrimeFactor);

% Nrange is DERIVED from the sweep, not typed in. A hard-coded ceiling is the
% failure mode here: widen config.sizeMax and the divisor table silently stops
% covering the new lengths, choose_balanced_factors falls back to trial
% division, and everything keeps running - slower, and with `hierarchical`
% dimensioned differently. Divisors are cheap, so the range is padded 50%%
% above whatever the sweep currently asks for.
try
   [cfgD, ~] = configure_simulation();
   % 2026-08: via getSizeList, so an explicit config.sizeList is honoured -
   % the old arithmetic expression ignored it and would size the divisor table
   % against a range the sweep no longer uses. config.encodedLengthList is
   % folded in too, because those lengths reach the same interleavers.
   maxSweepLen = max(ceil(getSizeList(cfgD) / cfgD.FECk) * cfgD.FECn);
   if isfield(cfgD, 'encodedLengthList') && ~isempty(cfgD.encodedLengthList)
      maxSweepLen = max(maxSweepLen, max(cfgD.encodedLengthList));
   end
   Nrange = 16:ceil(maxSweepLen * 1.5);
   fprintf('Nrange from configure_simulation: 16..%d (sweep needs up to %d)\n', ...
           max(Nrange), maxSweepLen);
catch
   Nrange = 16:1020;
   fprintf(2, 'configure_simulation unavailable - falling back to 16..1020.\n');
end
verbose = true;
%% ------------------------------------------------

outFile = fullfile(outputDir, 'table_factors_precomputed.mat');
fprintf('Divisor table: N = %d..%d\n', min(Nrange), max(Nrange));
fprintf('Target file  : %s\n\n', outFile);

if ~exist(outputDir, 'dir'), mkdir(outputDir); end

%% Load what is already there - we are adding to it, not replacing it
precomputed_factors = struct();
if exist(outFile, 'file')
    existing = load(outFile);
    if isfield(existing, 'precomputed_factors')
        precomputed_factors = existing.precomputed_factors;
    elseif isfield(existing, 'table')
        precomputed_factors = existing.table;
    end

    bak = fullfile(outputDir, sprintf('table_factors_precomputed_backup_%s.mat', ...
                                      datestr(now, 'yymmdd_HHMMSS')));
    copyfile(outFile, bak);
    fprintf('backup: %s\n', bak);

    permFields = fieldnames(precomputed_factors);
    permFields = permFields(strncmp(permFields, 'perms_', 6));
    fprintf('existing permutation tables: %d (kept untouched)\n', numel(permFields));
else
    fprintf('No existing file - creating a new one (divisors only).\n');
end

%% Build / refresh the divisor map
if isfield(precomputed_factors, 'divs') && isa(precomputed_factors.divs, 'containers.Map')
    divs = precomputed_factors.divs;
    fprintf('extending existing divisor map (%d keys)\n', divs.Count);
else
    divs = containers.Map('KeyType', 'double', 'ValueType', 'any');
end

t0 = tic; nNew = 0;
for N = Nrange
    if ~divs.isKey(N)
        divs(N) = enumerate_divs(N);
        nNew = nNew + 1;
    end
end
precomputed_factors.divs = divs;
fprintf('divisors: %d total, %d new, %.2f s\n', divs.Count, nNew, toc(t0));

%% Save
try
    save(outFile, 'precomputed_factors', '-v7.3');
catch
    save(outFile, 'precomputed_factors', '-v7');
    fprintf(2, 'note: -v7.3 unavailable, saved as -v7\n');
end
fprintf('saved: %s\n', outFile);

%% Summary
fprintf('\n===== SUMMARY =====\n');
fprintf('divs                 : %d keys\n', precomputed_factors.divs.Count);
fn = fieldnames(precomputed_factors);
fn = fn(strncmp(fn, 'perms_', 6));
if isempty(fn)
    fprintf('permutation tables   : none yet - run PrecomputeInterleaversGenerator\n');
else
    for i = 1:numel(fn)
        M = precomputed_factors.(fn{i});
        if isa(M, 'containers.Map')
            fprintf('%-20s : %d\n', fn{i}, M.Count);
        end
    end
end

fprintf(['\nNOTE: PrecomputedInterleaverLoader and PrimeFactorLoader cache in\n' ...
         'persistent variables. Run  clearHarnessCaches  before the sweep, or\n' ...
         'this session keeps serving the table from before this write.\n']);

%% ========== HELPERS ==========
function d = enumerate_divs(n)
    dv = [];
    r = floor(sqrt(n));
    for k = 1:r
        if mod(n, k) == 0
            dv(end+1) = k; %#ok<AGROW>
            if k ~= n/k, dv(end+1) = n/k; end %#ok<AGROW>
        end
    end
    d = sort(unique(dv));
    if isempty(d), d = [1, n]; end
end
