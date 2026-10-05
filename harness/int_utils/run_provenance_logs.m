%RUN_PROVENANCE_LOGS  Regenerate, with a saved log, the manuscript numbers that
% have no archived source (WORKLOG.md, "Carried over, not traceable").
% Run from the harness folder with the path set as for a sweep. No sweep is
% run; nothing in results_v2 is modified except the new logs folder.
%
%   1. VII-B  Gilbert-Elliott burst structure             ge_burst_stats
%   2. VII-B  realized density vs target, kappa           check_noise_fidelity
%   3. VI-B   clean region charged back by C_NN           check_clean_region
%   4. III-I  codewords a burst of 8n lands in (N=1200)   check_permutation_reach
%   5. IX-D   construction cost and scaling               benchmark_runtime
%

% The results folder comes from the environment so that this script runs
% on any machine: set SINT_RESULTS once to the campaign folder.
dataDir = getenv('SINT_RESULTS');
if isempty(dataDir)
   dataDir = fullfile(pwd, 'data', 'results');
end
logDir  = fullfile(dataDir, 'logs');
if exist(logDir, 'dir') ~= 7, mkdir(logDir); end
stamp = datestr(now, 'yymmdd_HHMM');
logFile = fullfile(logDir, ['provenance_' stamp '.txt']);
diary(logFile); diary on
fprintf('run_provenance_logs  %s\nMATLAB %s\n', datestr(now), version);

%% 1. burst structure (both GE regimes, common grid; a few minutes)
G = ge_burst_stats(struct('grid', 'common'));

%% 2. noise fidelity
F = check_noise_fidelity(dataDir);

%% 3. clean region: locate each method's worst extension in the campaign, then score it
W  = check_clean_region([], struct('dataDir', dataDir, 'dataOnly', true));
Rw = check_clean_region([W.N], struct('dataDir', dataDir));

%% 4. structural screen quantities at the two screen lengths
P1200 = check_permutation_reach(1200);
P1440 = check_permutation_reach(1440);

%% 5. construction cost: 10^3..10^5 (log-spaced) and the evaluation grid
tdir = find_table_dir(dataDir);
methods = {'random','matrix','helical','helicalScan','snake','spiral','diagonal','hierarchical', ...
           'multiDim','latinSquare','time','chaotic','prime','block','algebraic','turbo', ...
           'convolutional','srandom','goldenRP','drp','blockCM','convCM','S'};
Tbig  = benchmark_runtime(methods, round(logspace(3, 5, 10)), struct('dataDir', tdir, 'budgetSec', 2));
Tgrid = benchmark_runtime(methods, 60:60:3000, struct('dataDir', tdir, 'budgetSec', 2));

save(fullfile(logDir, ['provenance_' stamp '.mat']), 'G', 'F', 'W', 'Rw', 'P1200', 'P1440', 'Tbig', 'Tgrid');
diary off
fprintf('log: %s\n', logFile);
