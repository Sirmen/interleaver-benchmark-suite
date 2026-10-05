% ┌─────────────────────────────────────────────────────────────┐
% │                    USER CODE                                │
% │  interleaver_generic_pc(data, 'matrix', pad, maxExt, table) │
% └────────────────────────────┬────────────────────────────────┘
%                              │
%                              ▼
%          ┌───────────────────────────────────────┐
%          │   Is precomputed table supplied?      │
%          │         AND                           │
%          │   Does it contain entry for this N?   │
%          └───────────┬───────────────────────────┘
%                      │
%            ┌─────────┴─────────┐
%            │                   │
%           YES                 NO
%            │                   │
%            ▼                   ▼
%     ┌──────────────┐    ┌─────────────────┐
%     │ USE PRECOMP  │    │ CALL ORIGINAL   │
%     │ PERMUTATION  │    │ interleaver_XXX │ XXX e.g. matrix
%     │   (FAST)     │    │   (SLOWER)      │
%     └──────────────┘    └─────────────────┘
%            │                   │
%            └─────────┬─────────┘
%                      │
%                      ▼
%               ┌─────────────┐
%               │   RETURN    │
%               │   RESULT    │
%               └─────────────┘

clc; close all;

fprintf("\n=== ALL INTERLEAVERS TEST (using Precomputed Tables) ===\n");

%% PARAMETERS
padSymbol  = 0;
maxExtPct  = 0.50;

%% PATH TO PRECOMPUTED DATA FOLDER
% Resolved rather than typed in: find_table_dir looks for
% table_factors_precomputed.mat from here outward and on the MATLAB path.
% Two outputs are requested on purpose: with one, find_table_dir raises
% instead of returning, and the fallback below would never be reached.
% The fallback keeps the historical layout without naming any machine.
[dataDir_PrimeFactor, ~] = find_table_dir();
if isempty(dataDir_PrimeFactor)
   dataDir_PrimeFactor = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data_PrimeFactor');
end

%% LOAD TABLES
% Drop the persistent caches first: PrecomputedInterleaverLoader keys its cache
% on the DIRECTORY STRING, never on the file's timestamp, so after a
% regeneration this session would otherwise keep handing back the old table.
if exist('clearHarnessCaches', 'file') == 2, clearHarnessCaches(); end

[table_precomputed, erM] = PrecomputedInterleaverLoader(dataDir_PrimeFactor);
if erM ~= ""
    error('Failed to load precomputed table: %s', erM);
end

% Prime/factor tables for the live-path methods. Use PrimeFactorLoader, NOT
% PrimeFactor_PrecomputedLoader: the latter converts factors.mat into a .divs
% map and DISCARDS the n<N> records, which is exactly what getFactorPairs and
% interleaver_S look up. Same call as main_simulation_wrapper.
[table_primes, table_factors, erM] = PrimeFactorLoader(char(dataDir_PrimeFactor));
if erM ~= ""
    error('Failed to load prime/factor tables: %s', erM);
end

paramsInt = struct();   % live-path defaults are fine for a correctness sweep

if isfield(table_precomputed, 'divs')
    fprintf("  Loaded divisor table entries: %d\n", table_precomputed.divs.Count);
else
    fprintf(2, "  [!] No .divs in the precomputed table - run PrecomputeFactorsGenerator.\n");
end

%% METHOD LIST - 2026
% 'cross' is gone: the file was a boustrophedon block interleaver, not the
% Ramsey/Forney cross interleaver the name denotes, so it is now 'snake'.
% The genuine convolutional cross interleaver is 'convolutional'.
% Four methods added: srandom (Divsalar-Pollara), goldenRP (Crozier),
% drp (Crozier-Guinand), arp (Berrou / DVB-RCS).
interleaverTypes = {'random', 'matrix', 'helical', 'helicalScan', ...
                    'snake', 'spiral', 'diagonal', 'hierarchical', 'multiDim', ...
                    'latinSquare', 'time', 'freqRandom', 'freqDeterm', 'chaotic', ...
                    'prime', 'block', 'algebraic', 'turbo', 'convolutional', ...
                    'srandom', 'goldenRP', 'drp', 'arp', ...
                    'S'};

% random and freqRandom are redrawn per frame BY DESIGN and are never cached.
% Absence from the table is correct for them, not a fault - they take the live
% path in interleaver_generic_pc and are tested here all the same.
liveByDesign = {'random', 'freqRandom'};

availableTypes = {};
for i = 1:length(interleaverTypes)
    t = interleaverTypes{i};
    fieldName = ['perms_' t];
    if isfield(table_precomputed, fieldName)
        count = table_precomputed.(fieldName).Count;
        fprintf("  %-14s cached Ns: %d\n", t, count);
        if count > 0, availableTypes{end+1} = t; end
    elseif any(strcmp(liveByDesign, t))
        fprintf("  %-14s live by design (never cached)\n", t);
        availableTypes{end+1} = t;
    end
end

notCached = setdiff(setdiff(interleaverTypes, availableTypes), liveByDesign);
if ~isempty(notCached)
   fprintf("\n[!] Not in the table: %s\n", strjoin(notCached, ', '));
   fprintf("    Regenerate with PrecomputeInterleaversGenerator, then run\n");
   fprintf("    clearHarnessCaches (the loader caches by directory, not by\n");
   fprintf("    timestamp, so this session would keep serving the old table).\n");
   fprintf("    Testing them live for now.\n\n");
   availableTypes = [availableTypes, notCached];
else
   fprintf("\nAll methods present\n");
end

if isfield(table_precomputed, 'perms_cross')
   fprintf("[!] Table still carries perms_cross - stale, renamed to snake. Ignored.\n");
end

%% TEST RANGE
rng(1);

nMin = 16;
nMax = 510;

% Results storage
results = struct();
for i = 1:length(availableTypes)
    type = availableTypes{i};
    results.(type).minSeps = zeros(1, nMax-nMin+1);
    results.(type).meanSeps = zeros(1, nMax-nMin+1);
    results.(type).time = 0;
    results.(type).errors = 0;
end

fprintf("Running interleaver tests for N=%d..%d ...\n\n", nMin, nMax);

for idx = 1:(nMax-nMin+1)
    N = nMin + idx - 1;

    % === RANDOM DATA ===
    data = randi([0 255], 1, N);
    
    % Test each interleaver type
    for i = 1:length(availableTypes)
        type = availableTypes{i};
        
        try
            t = tic;
            % Pass the prime/factor tables and paramsInt: methods that fall
            % through to the live path (random, freqRandom, and anything not
            % cached) need them. Omitting them left prime/snake/algebraic/S
            % running with empty tables on exactly those lengths.
            [vInt, perm, L, K, Q, R, erM] = ...
                interleaver_generic_pc(data, type, padSymbol, maxExtPct, ...
                                       table_precomputed, 2106, ...
                                       table_primes, table_factors, paramsInt);
            
            results.(type).time = results.(type).time + toc(t);
            
            if erM ~= ""
                fprintf("  Warning: %s interleaver error (N=%d): %s\n", type, N, erM);
                results.(type).errors = results.(type).errors + 1;
                error(erM);
            end
            
            % Deinterleave
            [deint, erM] = deinterleaver_universal(vInt, perm, N);
            if erM ~= ""; error(erM); end
            if ~isequal(deint, data)
                fprintf("  ERROR: Mismatch in %s interleaver at N=%d\n", type, N);
                results.(type).errors = results.(type).errors + 1;
                error(erM);
            end
            
            % Separation metrics
            [minS, ~, avgS] = intraVectorSeparations(perm, true);
            results.(type).minSeps(idx) = minS;
            results.(type).meanSeps(idx) = avgS;
            
        catch ME
            fprintf("  Exception in %s interleaver (N=%d): %s\n", type, N, ME.message);
            results.(type).errors = results.(type).errors + 1;
        end
    end
    
    if mod(N, 25) == 0
        fprintf("  Completed N=%d\n", N);
    end
end

%% PRINT SUMMARY
fprintf("\n===== RESULTS SUMMARY =====\n");
fprintf("N range: %d - %d\n\n", nMin, nMax);

for i = 1:length(availableTypes)
    type = availableTypes{i};
    fprintf("--- %s Interleaver ---\n", upper(type));
    fprintf("  Average run time : %.6f s\n", results.(type).time / (nMax-nMin+1));
    fprintf("  Errors           : %d\n", results.(type).errors);
    
    validIdx = results.(type).minSeps > 0;
    if any(validIdx)
        fprintf("  Avg mean sep     : %.3f\n", mean(results.(type).meanSeps(validIdx)));
        fprintf("  Min min-sep      : %.3f\n", min(results.(type).minSeps(validIdx)));
        fprintf("  Avg min-sep      : %.3f\n", mean(results.(type).minSeps(validIdx)));
    end
    fprintf("\n");
end

%% PLOT RESULTS - ALL BAR GRAPHS
nVals = nMin:nMax;
numTypes = length(availableTypes);
colors = lines(numTypes);

%% Figure 1: Main Comparison Metrics
figure; % ('Position', [100 100 1600 900]);

%% Subplot 1: Average Min Separation
subplot(2,2,1);
avgMinSeps = zeros(1, numTypes);
for i = 1:numTypes
    type = availableTypes{i};
    validIdx = results.(type).minSeps > 0;
    if any(validIdx)
        avgMinSeps(i) = mean(results.(type).minSeps(validIdx));
    end
end

b1 = bar(avgMinSeps);
b1.FaceColor = 'flat';
b1.CData = colors;
set(gca, 'XTick', 1:numTypes, 'XTickLabel', availableTypes, 'XTickLabelRotation', 45);
ylabel('Average Min Separation');
title('Average Min Separation by Interleaver');
grid on;
% Add value labels on bars
for i = 1:numTypes
    text(i, avgMinSeps(i), sprintf('%.2f', avgMinSeps(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
end

%% Subplot 2: Average Mean Separation
subplot(2,2,2);
avgMeanSeps = zeros(1, numTypes);
for i = 1:numTypes
    type = availableTypes{i};
    validIdx = results.(type).meanSeps > 0;
    if any(validIdx)
        avgMeanSeps(i) = mean(results.(type).meanSeps(validIdx));
    end
end

b2 = bar(avgMeanSeps);
b2.FaceColor = 'flat';
b2.CData = colors;
set(gca, 'XTick', 1:numTypes, 'XTickLabel', availableTypes, 'XTickLabelRotation', 45);
ylabel('Average Mean Separation');
title('Average Mean Separation by Interleaver');
grid on;
% Add value labels on bars
for i = 1:numTypes
    text(i, avgMeanSeps(i), sprintf('%.2f', avgMeanSeps(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
end

%% Subplot 3: Minimum of Min Separations
subplot(2,2,3);
minMinSeps = zeros(1, numTypes);
for i = 1:numTypes
    type = availableTypes{i};
    validIdx = results.(type).minSeps > 0;
    if any(validIdx)
        minMinSeps(i) = min(results.(type).minSeps(validIdx));
    end
end

b3 = bar(minMinSeps);
b3.FaceColor = 'flat';
b3.CData = colors;
set(gca, 'XTick', 1:numTypes, 'XTickLabel', availableTypes, 'XTickLabelRotation', 45);
ylabel('Worst-case Min Separation');
title('Minimum Min Separation (Worst Case)');
grid on;
% Add value labels on bars
for i = 1:numTypes
    text(i, minMinSeps(i), sprintf('%.2f', minMinSeps(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
end

%% Subplot 4: Average Processing Time
subplot(2,2,4);
avgTimes = zeros(1, numTypes);
for i = 1:numTypes
    type = availableTypes{i};
    avgTimes(i) = results.(type).time / (nMax-nMin+1) * 1000; % Convert to ms
end

b4 = bar(avgTimes);
b4.FaceColor = 'flat';
b4.CData = colors;
set(gca, 'XTick', 1:numTypes, 'XTickLabel', availableTypes, 'XTickLabelRotation', 45);
ylabel('Average Time (ms)');
title('Average Processing Time per N');
grid on;
% Add value labels on bars
for i = 1:numTypes
    text(i, avgTimes(i), sprintf('%.3f', avgTimes(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
end

%% Figure 2: Grouped Bar Chart Comparison
figure; % ('Position', [150 150 1400 700]);

% Prepare data matrix
comparisonData = [avgMinSeps; avgMeanSeps; minMinSeps; avgTimes]';

b = bar(comparisonData);
set(gca, 'XTick', 1:numTypes, 'XTickLabel', availableTypes, 'XTickLabelRotation', 45);
ylabel('Metric Value');
title('Interleaver Performance - All Metrics Comparison');
legend({'Avg Min Sep', 'Avg Mean Sep', 'Min Min Sep', 'Avg Time (ms)'}, ...
       'Location', 'best', 'FontSize', 10);
grid on;

% Color the bars
colors4 = [0.2 0.4 0.8; 0.8 0.4 0.2; 0.4 0.8 0.2; 0.8 0.2 0.8];
for k = 1:4
    b(k).FaceColor = colors4(k,:);
end

%% Figure 3: Normalized Performance Comparison
figure; % ('Position', [200 200 1400 700]);

% Normalize each metric to 0-1 for better visual comparison
normalizedData = comparisonData;
for col = 1:size(comparisonData, 2)
    maxVal = max(comparisonData(:, col));
    if maxVal > 0
        normalizedData(:, col) = comparisonData(:, col) / maxVal;
    end
end

% Invert time metric (lower is better, so flip it)
normalizedData(:, 4) = 1 - normalizedData(:, 4);

b = bar(normalizedData);
set(gca, 'XTick', 1:numTypes, 'XTickLabel', availableTypes, 'XTickLabelRotation', 45);
ylabel('Normalized Score (0-1, higher is better)');
title('Normalized Interleaver Performance (All Metrics)');
legend({'Avg Min Sep', 'Avg Mean Sep', 'Min Min Sep', 'Speed (inverted)'}, ...
       'Location', 'best', 'FontSize', 10);
grid on;
ylim([0 1.1]);

% Color the bars
for k = 1:4
    b(k).FaceColor = colors4(k,:);
end

%% Figure 4: Overall Performance Ranking
figure; % ('Position', [250 250 1200 700]);

% Calculate composite score (weighted average of normalized metrics)
weights = [0.3, 0.3, 0.2, 0.2]; % [avgMinSep, avgMeanSep, minMinSep, speed]
compositeScore = sum(normalizedData .* weights, 2);

[sortedScores, sortIdx] = sort(compositeScore, 'descend');
sortedTypes = availableTypes(sortIdx);

barh(sortedScores, 'FaceColor', [0.2 0.6 0.8]);
set(gca, 'YTick', 1:numTypes, 'YTickLabel', sortedTypes, 'FontSize', 10);
xlabel('Composite Performance Score (0-1, higher is better)');
title('Overall Interleaver Performance Ranking');
grid on;
xlim([0 1]);

% Add value labels and ranking numbers
for i = 1:numTypes
    text(sortedScores(i) + 0.02, i, sprintf('%.3f', sortedScores(i)), ...
        'VerticalAlignment', 'middle', 'FontSize', 9);
    text(-0.02, i, sprintf('#%d', i), ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'FontSize', 9);
end
