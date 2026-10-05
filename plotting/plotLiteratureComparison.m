function plotLiteratureComparison(R_S, R_cross, R_latin)
% plotLiteratureComparison  Create publication-quality plots comparing interleavers
%
% Generates 4 figures:
%   1. Permutation scatter plots
%   2. Separation & Adjacency distributions
%   3. Distance spectrum
%   4. Key metrics summary

N_S = R_S.N;
N_cross = R_cross.N;
N_latin = R_latin.N;

%% Figure 1: Permutation Scatter Plots
fig1 = figure('Name', 'Permutation Scatter Comparison', 'Position', [100 100 1400 500]);

subplot(1,3,1);
scatter(1:N_S, R_S.pos, 4, 'filled', 'MarkerFaceAlpha', 0.6, 'MarkerEdgeAlpha', 0);
axis([1 N_S 1 N_S]); axis square; grid on;
title(sprintf('S-interleaver (N=%d)', N_S), 'FontWeight', 'bold'); 
xlabel('Original Index i'); ylabel('Interleaved Position pos(i)');
set(gca, 'FontSize', 10);

subplot(1,3,2);
scatter(1:N_cross, R_cross.pos, 4, 'filled', 'MarkerFaceAlpha', 0.6, 'MarkerEdgeAlpha', 0);
axis([1 N_cross 1 N_cross]); axis square; grid on;
title(sprintf('Cross (N=%d)', N_cross), 'FontWeight', 'bold'); 
xlabel('Original Index i'); ylabel('Interleaved Position pos(i)');
set(gca, 'FontSize', 10);

subplot(1,3,3);
scatter(1:N_latin, R_latin.pos, 4, 'filled', 'MarkerFaceAlpha', 0.6, 'MarkerEdgeAlpha', 0);
axis([1 N_latin 1 N_latin]); axis square; grid on;
title(sprintf('Latin Square (N=%d)', N_latin), 'FontWeight', 'bold'); 
xlabel('Original Index i'); ylabel('Interleaved Position pos(i)');
set(gca, 'FontSize', 10);

sgtitle('Permutation Scatter: i vs pos(i) - Reveals Structure', 'FontSize', 14, 'FontWeight', 'bold');

%% Figure 2: Separation and Adjacency Distributions
fig2 = figure('Name', 'Separation & Adjacency Comparison', 'Position', [100 100 1400 700]);

% Separation histograms
subplot(2,3,1);
histogram(R_S.sep.sep, 0:0.02:1, 'Normalization', 'probability', 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'none');
title(sprintf('S-interleaver Separation\nMin=%.3f, Avg=%.3f', R_S.sep.sepMin, R_S.sep.sepAvg), 'FontSize', 10); 
xlabel('|pos(i+1)-pos(i)| / (N-1)'); ylabel('Probability');
xlim([0 1]); grid on; set(gca, 'FontSize', 9);

subplot(2,3,2);
histogram(R_cross.sep.sep, 0:0.02:1, 'Normalization', 'probability', 'FaceColor', [0.8 0.4 0.2], 'EdgeColor', 'none');
title(sprintf('Cross Separation\nMin=%.3f, Avg=%.3f', R_cross.sep.sepMin, R_cross.sep.sepAvg), 'FontSize', 10); 
xlabel('|pos(i+1)-pos(i)| / (N-1)'); ylabel('Probability');
xlim([0 1]); grid on; set(gca, 'FontSize', 9);

subplot(2,3,3);
histogram(R_latin.sep.sep, 0:0.02:1, 'Normalization', 'probability', 'FaceColor', [0.8 0.7 0.2], 'EdgeColor', 'none');
title(sprintf('Latin Square Separation\nMin=%.3f, Avg=%.3f', R_latin.sep.sepMin, R_latin.sep.sepAvg), 'FontSize', 10); 
xlabel('|pos(i+1)-pos(i)| / (N-1)'); ylabel('Probability');
xlim([0 1]); grid on; set(gca, 'FontSize', 9);

% Adjacency histograms
subplot(2,3,4);
histogram(R_S.adj.adj, 0:0.02:1, 'Normalization', 'probability', 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'none');
title(sprintf('S-interleaver Adjacency\nMin=%.3f, Avg=%.3f', R_S.adj.adjMin, R_S.adj.adjAvg), 'FontSize', 10); 
xlabel('|perm(j+1)-perm(j)| / (N-1)'); ylabel('Probability');
xlim([0 1]); grid on; set(gca, 'FontSize', 9);

subplot(2,3,5);
histogram(R_cross.adj.adj, 0:0.02:1, 'Normalization', 'probability', 'FaceColor', [0.8 0.4 0.2], 'EdgeColor', 'none');
title(sprintf('Cross Adjacency\nMin=%.3f, Avg=%.3f', R_cross.adj.adjMin, R_cross.adj.adjAvg), 'FontSize', 10); 
xlabel('|perm(j+1)-perm(j)| / (N-1)'); ylabel('Probability');
xlim([0 1]); grid on; set(gca, 'FontSize', 9);

subplot(2,3,6);
histogram(R_latin.adj.adj, 0:0.02:1, 'Normalization', 'probability', 'FaceColor', [0.8 0.7 0.2], 'EdgeColor', 'none');
title(sprintf('Latin Square Adjacency\nMin=%.3f, Avg=%.3f', R_latin.adj.adjMin, R_latin.adj.adjAvg), 'FontSize', 10); 
xlabel('|perm(j+1)-perm(j)| / (N-1)'); ylabel('Probability');
xlim([0 1]); grid on; set(gca, 'FontSize', 9);

sgtitle('Separation & Adjacency Distributions', 'FontSize', 14, 'FontWeight', 'bold');

%% Figure 3: Distance Spectrum
fig3 = figure('Name', 'Distance Spectrum Comparison', 'Position', [100 100 1400 450]);

subplot(1,3,1);
edges = R_S.distance.edges / (N_S-1);
histogram('BinEdges', edges, 'BinCounts', R_S.distance.counts, 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'none');
title(sprintf('S-interleaver\nMean=%.3f, Var=%.4f', R_S.distance.mean, R_S.distance.var), 'FontSize', 10); 
xlabel('Euclidean Distance / (N-1)'); ylabel('Probability');
grid on; set(gca, 'FontSize', 9);

subplot(1,3,2);
edges = R_cross.distance.edges / (N_cross-1);
histogram('BinEdges', edges, 'BinCounts', R_cross.distance.counts, 'FaceColor', [0.8 0.4 0.2], 'EdgeColor', 'none');
title(sprintf('Cross\nMean=%.3f, Var=%.4f', R_cross.distance.mean, R_cross.distance.var), 'FontSize', 10); 
xlabel('Euclidean Distance / (N-1)'); ylabel('Probability');
grid on; set(gca, 'FontSize', 9);

subplot(1,3,3);
edges = R_latin.distance.edges / (N_latin-1);
histogram('BinEdges', edges, 'BinCounts', R_latin.distance.counts, 'FaceColor', [0.8 0.7 0.2], 'EdgeColor', 'none');
title(sprintf('Latin Square\nMean=%.3f, Var=%.4f', R_latin.distance.mean, R_latin.distance.var), 'FontSize', 10); 
xlabel('Euclidean Distance / (N-1)'); ylabel('Probability');
grid on; set(gca, 'FontSize', 9);

sgtitle('2D Distance Spectrum (Sampled Pairs)', 'FontSize', 14, 'FontWeight', 'bold');

%% Figure 4: Key Metrics Summary (Split by Scale)
fig4 = figure('Name', 'Key Metrics Summary', 'Position', [100 100 1400 700]);

% Extract spread values
if ~isnan(R_S.spread.S_exact)
    spread_S = R_S.spread.S_exact;
    spread_cross = R_cross.spread.S_exact;
    spread_latin = R_latin.spread.S_exact;
else
    spread_S = R_S.spread.S_sampled;
    spread_cross = R_cross.spread.S_sampled;
    spread_latin = R_latin.spread.S_sampled;
end

% Subplot 1: Standard metrics [0-1]
subplot(2,1,1);
metrics_names = {'Sep Min', 'Sep Avg', 'Adj Min', 'Adj Avg', 'Spread', 'Dist Mean'};
values = [
    R_S.sep.sepMin, R_cross.sep.sepMin, R_latin.sep.sepMin;
    R_S.sep.sepAvg, R_cross.sep.sepAvg, R_latin.sep.sepAvg;
    R_S.adj.adjMin, R_cross.adj.adjMin, R_latin.adj.adjMin;
    R_S.adj.adjAvg, R_cross.adj.adjAvg, R_latin.adj.adjAvg;
    spread_S, spread_cross, spread_latin;
    R_S.distance.mean, R_cross.distance.mean, R_latin.distance.mean
];

bar(values);
set(gca, 'XTickLabel', metrics_names, 'XTick', 1:length(metrics_names));
xtickangle(45);
ylabel('Metric Value (0-1 range)');
title('Standard Literature Metrics');
legend({'S-interleaver', 'Cross', 'Latin Square'}, 'Location', 'northeast');
grid on; ylim([0 1.1]);

% Subplot 2: Triangle metric (separate scale)
subplot(2,1,2);
triangle_values = [R_S.triangle.T, R_cross.triangle.T, R_latin.triangle.T];
bar(triangle_values);
set(gca, 'XTickLabel', {'S-interleaver', 'Cross', 'Latin Square'}, 'XTick', 1:3);
xtickangle(45);
ylabel('Triangle Metric T');
title('Triangle Metric (Scrambling Quality)');
grid on;

fprintf('✓ Literature comparison plots generated (4 figures)\n');

end