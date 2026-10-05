%RUN_TIMING_LOGS  Construction cost for Section IX-D, with a saved log.
%
% Timing only. Everything else in run_provenance_logs.m (burst structure, noise
% fidelity, clean region, permutation reach) completed in the run of 29 Sep and
% is in results_v2\logs\provenance_260929_0017.txt; do not repeat it.
%
% WHY THE EARLIER RUN DID NOT FINISH
% ---------------------------------------------------------------------------
% benchmark_runtime checks its per-call budget BETWEEN calls, so a single
% construction that never returns cannot be stopped. interleaver_srandom is a
% rejection search whose acceptance probability falls with N: it completed the
% first eight lengths of the ladder (up to N = 35 938) with reduced repetitions
% and then did not return at N = 59 948.
%
% srandom is therefore not timed here. Its cost is not what the paper claims
% about it; the claim is a domain ceiling, and the stopped run measured that.
% drp also searches, so it is timed on the evaluation grid only, where the
% campaign actually uses it.
%
% WHAT THIS RUNS
%   1. closed-form methods, N = 10^3 to 10^5 (10 log-spaced lengths) - the
%      exponents quoted in Section IX-D
%   2. every method except srandom, on 12 lengths of the evaluation grid - the
%      only place a search cost (drp) resolves
%
% R.T. Sirmen harness, 2026-09

% The results folder comes from the environment so that this script runs
% on any machine: set SINT_RESULTS once to the campaign folder.
dataDir = getenv('SINT_RESULTS');
if isempty(dataDir)
   dataDir = fullfile(pwd, 'data', 'results');
end
logDir  = fullfile(dataDir, 'logs');
if exist(logDir, 'dir') ~= 7, mkdir(logDir); end
stamp   = datestr(now, 'yymmdd_HHMM');
logFile = fullfile(logDir, ['timing_' stamp '.txt']);
matFile = fullfile(logDir, ['timing_' stamp '.mat']);
diary(logFile); diary on
fprintf('run_timing_logs  %s\nMATLAB %s\n', datestr(now), version);

tdir = find_table_dir(dataDir);

% The frame-extension allowance has to be the campaign's, not benchmark_runtime's
% default of 0. A method that pads refuses the length outright when no extension
% is allowed: at maxExt = 0 latinSquare refuses every length that is not a perfect
% square (its K^2 working buffer, not transmitted - BE stays 1), prime refuses
% every length that is not prime, and blockCM refuses every length that is not a
% multiple of n. Those refusals are a property of the option, not of the method,
% and they do not match how the sweep builds the same permutations.
cfg  = configure_simulation();
opts = struct('dataDir', tdir, 'budgetSec', 2, 'maxExt', cfg.maxExtensionPercentage);
fprintf('extension allowance: %.2f (campaign value)\n', opts.maxExt);

CLOSED = {'random','matrix','helical','helicalScan','snake','spiral','diagonal', ...
          'hierarchical','multiDim','latinSquare','time','chaotic','prime','block', ...
          'algebraic','turbo','convolutional','goldenRP','blockCM','convCM','S'};
bigN   = round(logspace(3, 5, 10));      % 1000 ... 100000; 4642, 7743, 35938, 59948 are members
gridN  = 60 * round(linspace(1, 50, 12));

%% 1. scaling ladder, closed-form constructions
fprintf('\n[1/2] scaling ladder, %d methods, N = %d ... %d\n', numel(CLOSED), bigN(1), bigN(end));
t0 = tic; Tbig = benchmark_runtime(CLOSED, bigN, opts);
fprintf('[1/2] done in %.1f min\n', toc(t0)/60);
save(matFile, 'Tbig', 'bigN');

%% 2. evaluation grid, every method except srandom
fprintf('\n[2/2] evaluation grid, N = %d ... %d\n', gridN(1), gridN(end));
t0 = tic; Tgrid = benchmark_runtime([CLOSED, {'drp'}], gridN, opts);
fprintf('[2/2] done in %.1f min\n', toc(t0)/60);
save(matFile, 'Tbig', 'Tgrid', 'bigN', 'gridN');

diary off
fprintf('log: %s\n', logFile);
