function plotECCPerformance(Stats_none, Stats_S, Stats_cross, Stats_latin)
% plotECCPerformanceExtended  Create comprehensive ECC performance plots
%
% Generates 2 figures with extended metrics from collectStatistics

%% Figure 1: Core ECC Performance
fig1 = figure('Name', 'ECC Performance Comparison', 'Position', [100 100 1400 900]);

% Extract burst lengths
burstLens = [Stats_S.burstLength];

% Extract SER (decode error rate)
SER_none = [Stats_none.decodeErrRate_mean];
SER_S = [Stats_S.decodeErrRate_mean];
SER_cross = [Stats_cross.decodeErrRate_mean];
SER_latin = [Stats_latin.decodeErrRate_mean];

% Extract Effectiveness
Eff_none = [Stats_none.effectiveness_mean];
Eff_S = [Stats_S.effectiveness_mean];
Eff_cross = [Stats_cross.effectiveness_mean];
Eff_latin = [Stats_latin.effectiveness_mean];

% Extract ECC-Aware Score
ECC_none = [Stats_none.eccAwareScore_mean];
ECC_S = [Stats_S.eccAwareScore_mean];
ECC_cross = [Stats_cross.eccAwareScore_mean];
ECC_latin = [Stats_latin.eccAwareScore_mean];

% Extract ECC Violations
Viol_none = [Stats_none.eccViolations_after_mean];
Viol_S = [Stats_S.eccViolations_after_mean];
Viol_cross = [Stats_cross.eccViolations_after_mean];
Viol_latin = [Stats_latin.eccViolations_after_mean];

%% Subplot 1: SER vs Burst Length
subplot(2,2,1);
semilogy(burstLens, SER_none, 'k--o', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'w'); hold on;
semilogy(burstLens, SER_S, 'b-s', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'b');
semilogy(burstLens, SER_cross, 'r-^', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'r');
semilogy(burstLens, SER_latin, 'g-d', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'g');
xlabel('Burst Length (symbols)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Symbol Error Rate (SER)', 'FontSize', 11, 'FontWeight', 'bold');
title('Decoded SER vs Burst Length', 'FontSize', 12, 'FontWeight', 'bold');
legend({'No Interleaver', 'S-interleaver', 'Cross', 'Latin Square'}, ...
       'Location', 'northwest', 'FontSize', 10);
grid on; hold off;
set(gca, 'FontSize', 10);

%% Subplot 2: Effectiveness vs Burst Length
subplot(2,2,2);
plot(burstLens, Eff_none, 'k--o', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'w'); hold on;
plot(burstLens, Eff_S, 'b-s', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'b');
plot(burstLens, Eff_cross, 'r-^', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'r');
plot(burstLens, Eff_latin, 'g-d', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'g');
xlabel('Burst Length (symbols)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Effectiveness (InfoRate × Containment)', 'FontSize', 11, 'FontWeight', 'bold');
title('System Effectiveness vs Burst Length', 'FontSize', 12, 'FontWeight', 'bold');
legend({'No Interleaver', 'S-interleaver', 'Cross', 'Latin Square'}, ...
       'Location', 'northeast', 'FontSize', 10);
grid on; hold off;
set(gca, 'FontSize', 10);

%% Subplot 3: ECC-Aware Score vs Burst Length
subplot(2,2,3);
plot(burstLens, ECC_none, 'k--o', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'w'); hold on;
plot(burstLens, ECC_S, 'b-s', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'b');
plot(burstLens, ECC_cross, 'r-^', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'r');
plot(burstLens, ECC_latin, 'g-d', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'g');
xlabel('Burst Length (symbols)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('ECC-Aware Score', 'FontSize', 11, 'FontWeight', 'bold');
title('ECC-Aware Distribution Score', 'FontSize', 12, 'FontWeight', 'bold');
legend({'No Interleaver', 'S-interleaver', 'Cross', 'Latin Square'}, ...
       'Location', 'northeast', 'FontSize', 10);
grid on; hold off;
set(gca, 'FontSize', 10);
ylim([0 1.1]);

%% Subplot 4: ECC Violations vs Burst Length
subplot(2,2,4);
plot(burstLens, Viol_none, 'k--o', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'w'); hold on;
plot(burstLens, Viol_S, 'b-s', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'b');
plot(burstLens, Viol_cross, 'r-^', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'r');
plot(burstLens, Viol_latin, 'g-d', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'g');
xlabel('Burst Length (symbols)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Mean ECC Violations (blocks)', 'FontSize', 11, 'FontWeight', 'bold');
title('Blocks Exceeding ECC Capability', 'FontSize', 12, 'FontWeight', 'bold');
legend({'No Interleaver', 'S-interleaver', 'Cross', 'Latin Square'}, ...
       'Location', 'northwest', 'FontSize', 10);
grid on; hold off;
set(gca, 'FontSize', 10);

sgtitle('ECC Performance: RS Encoding + Interleaving vs Burst Errors', ...
        'FontSize', 14, 'FontWeight', 'bold');

%% Figure 2: Burst Distribution Analysis
fig2 = figure('Name', 'Burst Distribution & Efficiency', 'Position', [150 150 1400 900]);

% Extract burst spread metrics
SpreadEff_none = [Stats_none.burstSpreadEfficiency_mean];
SpreadEff_S = [Stats_S.burstSpreadEfficiency_mean];
SpreadEff_cross = [Stats_cross.burstSpreadEfficiency_mean];
SpreadEff_latin = [Stats_latin.burstSpreadEfficiency_mean];

% Extract burst diversity
Diversity_none = [Stats_none.burstDiversityScore_mean];
Diversity_S = [Stats_S.burstDiversityScore_mean];
Diversity_cross = [Stats_cross.burstDiversityScore_mean];
Diversity_latin = [Stats_latin.burstDiversityScore_mean];

% Extract separation efficiency
SepEff_none = [Stats_none.eta_sep_mean];
SepEff_S = [Stats_S.eta_sep_mean];
SepEff_cross = [Stats_cross.eta_sep_mean];
SepEff_latin = [Stats_latin.eta_sep_mean];

% Extract ECC utilization
Util_none = [Stats_none.eccUtilization_mean];
Util_S = [Stats_S.eccUtilization_mean];
Util_cross = [Stats_cross.eccUtilization_mean];
Util_latin = [Stats_latin.eccUtilization_mean];

%% Subplot 1: Burst Spread Efficiency
subplot(2,2,1);
plot(burstLens, SpreadEff_none, 'k--o', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'w'); hold on;
plot(burstLens, SpreadEff_S, 'b-s', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'b');
plot(burstLens, SpreadEff_cross, 'r-^', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'r');
plot(burstLens, SpreadEff_latin, 'g-d', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'g');
xlabel('Burst Length (symbols)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Burst Spread Efficiency', 'FontSize', 11, 'FontWeight', 'bold');
title('How Well Burst is Spread Across Blocks', 'FontSize', 12, 'FontWeight', 'bold');
legend({'No Interleaver', 'S-interleaver', 'Cross', 'Latin Square'}, ...
       'Location', 'best', 'FontSize', 10);
grid on; hold off;
set(gca, 'FontSize', 10);

%% Subplot 2: Burst Diversity Score
subplot(2,2,2);
plot(burstLens, Diversity_none, 'k--o', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'w'); hold on;
plot(burstLens, Diversity_S, 'b-s', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'b');
plot(burstLens, Diversity_cross, 'r-^', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'r');
plot(burstLens, Diversity_latin, 'g-d', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'g');
xlabel('Burst Length (symbols)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Burst Diversity Score', 'FontSize', 11, 'FontWeight', 'bold');
title('Diversity of Burst Distribution', 'FontSize', 12, 'FontWeight', 'bold');
legend({'No Interleaver', 'S-interleaver', 'Cross', 'Latin Square'}, ...
       'Location', 'best', 'FontSize', 10);
grid on; hold off;
set(gca, 'FontSize', 10);

%% Subplot 3: Separation Efficiency
subplot(2,2,3);
plot(burstLens, SepEff_none, 'k--o', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'w'); hold on;
plot(burstLens, SepEff_S, 'b-s', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'b');
plot(burstLens, SepEff_cross, 'r-^', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'r');
plot(burstLens, SepEff_latin, 'g-d', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'g');
xlabel('Burst Length (symbols)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Separation Efficiency', 'FontSize', 11, 'FontWeight', 'bold');
title('Adjacent Symbol Separation Quality', 'FontSize', 12, 'FontWeight', 'bold');
legend({'No Interleaver', 'S-interleaver', 'Cross', 'Latin Square'}, ...
       'Location', 'best', 'FontSize', 10);
grid on; hold off;
set(gca, 'FontSize', 10);

%% Subplot 4: ECC Capacity Utilization
subplot(2,2,4);
plot(burstLens, Util_none*100, 'k--o', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'w'); hold on;
plot(burstLens, Util_S*100, 'b-s', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'b');
plot(burstLens, Util_cross*100, 'r-^', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'r');
plot(burstLens, Util_latin*100, 'g-d', 'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', 'g');
xlabel('Burst Length (symbols)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('ECC Capacity Utilization (%)', 'FontSize', 11, 'FontWeight', 'bold');
title('Percentage of ECC Capacity Used', 'FontSize', 12, 'FontWeight', 'bold');
legend({'No Interleaver', 'S-interleaver', 'Cross', 'Latin Square'}, ...
       'Location', 'northwest', 'FontSize', 10);
grid on; hold off;
set(gca, 'FontSize', 10);

sgtitle('Burst Distribution Analysis & ECC Efficiency', ...
        'FontSize', 14, 'FontWeight', 'bold');

fprintf('✓ ECC performance plots generated (2 figures with 8 subplots total)\n');

end