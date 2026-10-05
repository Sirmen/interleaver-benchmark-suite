% testInterleave_enhanced
% R.Tanju Sirmen - 2025 (Enhanced with Performance Statistics)
% interleaves then deinterleaves the 1D (1 x N) data vector 
% plots the results, separation statistics, and performance metrics
clear all; close all;

try  
%% setup
   method = "Chaotic Logistic";
   base = 8;

   % Parameters
   
   excludeZero = true;

   padSymbol = base - 1; % Custom padding symbol
   maxExtensionPercentage = 1.34;

   r = 3.9; % Chaotic map parameter. Typically, r is chosen to be 3.9 to ensure chaotic behavior
   x = 0.5; % Initial condition for the logistic map

   % test config
   K = 23;   % Number of rows in the interleaving matrix
   L_min = 3;    % Number of columns in the interleaving matrix
   L_max = 25;
   N_max = 100;
   
   config.verbose = true;

%% Initialize structures for separation analysis and performance tracking
   all_permutations = struct();
   performance_stats = struct();
   test_lengths = [];
   
   % Performance tracking variables
   total_tests = 0;
   successful_tests = 0;
   failed_tests = 0;
   error_details = {};
   
   % Timing and memory tracking
   interleave_times = [];
   deinterleave_times = [];
   memory_usage = [];
   
   % Data size and extension tracking
   original_sizes = [];
   extended_sizes = [];
   extension_ratios = [];
   
   % Error statistics
   error_counts = [];
   error_ratios = [];
   
   % Configuration tracking
   L_values = [];
   test_configs = [];

%% gen data
   fprintf('=== Starting Interleaver Test ===\n');
   start_time_total = tic;
   
   for L=L_min:L_max
      fprintf('Testing L=%d\n', L);
      L_test_count = 0;
      L_success_count = 0;
      
      for N=L+1:N_max
         A = 1:N;  % Simple test data: [1, 2, 3, ..., N]
         total_tests = total_tests + 1;
         L_test_count = L_test_count + 1;

%% interleave:
         % Time the interleaving operation
         tic_interleave = tic;
         [vectorInterleaved, permutation, erM] = interleaver_chaotic(A, r, x);
         interleave_time = toc(tic_interleave);
         
         if erM ~= ""
            failed_tests = failed_tests + 1;
            error_details{end+1} = sprintf('L=%d, N=%d: Interleave error: %s', L, length(A), erM);
         else
      
%% deinterleave:
            % Time the deinterleaving operation
            tic_deinterleave = tic;
            % [vectorRestored, erM_deint] = deinterleaver_helicalScan(vectorInterleaved, permutation, N);
[vectorRestored, erM_deint] = deinterleaver_universal(vectorInterleaved, permutation, length(A));
            deinterleave_time = toc(tic_deinterleave);
            
            if erM_deint ~= ""
               failed_tests = failed_tests + 1;
               error_details{end+1} = sprintf('L=%d, N=%d: Deinterleave error: %s', L, length(A), erM_deint);
            else

%% Error control and analysis
               % Pad or trim to same length for comparison
               vectorRestored_trimmed = vectorRestored(1:N);
               
               [errCount, errRatio] = symerr(A, vectorRestored_trimmed); 
           
               % Timing data
               interleave_times = [interleave_times, interleave_time];
               deinterleave_times = [deinterleave_times, deinterleave_time];
               
               % Size and extension data
               original_sizes = [original_sizes, N];
               extended_sizes = [extended_sizes, length(vectorInterleaved)];
               extension_ratios = [extension_ratios, (length(vectorInterleaved) - length(A)) / length(A) * 100];
               
               % Error data
               error_counts = [error_counts, errCount];
               error_ratios = [error_ratios, errRatio];
               
               % Configuration data
               L_values = [L_values, L];
               test_configs = [test_configs, struct('L', L, 'N', length(A), 'success', errCount == 0)];
               
               % Memory usage (approximate)
               memory_usage = [memory_usage, (length(A) + length(vectorInterleaved) + length(vectorRestored)) * 8]; % bytes
            end
         end

         % Store performance metrics
         if errCount == 0
            successful_tests = successful_tests + 1;
            L_success_count = L_success_count + 1;
         else
            failed_tests = failed_tests + 1;
            error_details{end+1} = sprintf('L=%d, N=%d: Recovery failed with %d errors (%.4f%%)', ...
                L, length(A), errCount, errRatio*100);
         end
         
         % Store permutation for separation analysis
         field_name = sprintf('N_%d', length(A));
         all_permutations.(field_name) = permutation;
         test_lengths = [test_lengths, length(A)];

      end % for N=L*2:300
      % fprintf('%d/%d passed\n', L_success_count, L_test_count);
   end % for L=3:17
   
   total_time = toc(start_time_total);
   
%% Compile Performance Statistics
   performance_stats.summary.total_tests = total_tests;
   performance_stats.summary.successful_tests = successful_tests;
   performance_stats.summary.failed_tests = failed_tests;
   performance_stats.summary.success_rate = successful_tests / total_tests * 100;
   performance_stats.summary.total_time = total_time;
   performance_stats.summary.avg_time_per_test = total_time / total_tests;
   
   % Timing statistics
   performance_stats.timing.interleave.mean = mean(interleave_times);
   performance_stats.timing.interleave.std = std(interleave_times);
   performance_stats.timing.interleave.min = min(interleave_times);
   performance_stats.timing.interleave.max = max(interleave_times);
   performance_stats.timing.interleave.median = median(interleave_times);
   
   performance_stats.timing.deinterleave.mean = mean(deinterleave_times);
   performance_stats.timing.deinterleave.std = std(deinterleave_times);
   performance_stats.timing.deinterleave.min = min(deinterleave_times);
   performance_stats.timing.deinterleave.max = max(deinterleave_times);
   performance_stats.timing.deinterleave.median = median(deinterleave_times);
   
   % Size and extension statistics
   performance_stats.size.original.mean = mean(original_sizes);
   performance_stats.size.original.std = std(original_sizes);
   performance_stats.size.original.range = [min(original_sizes), max(original_sizes)];
   
   performance_stats.size.extension.mean = mean(extension_ratios);
   performance_stats.size.extension.std = std(extension_ratios);
   performance_stats.size.extension.max = max(extension_ratios);
   performance_stats.size.extension.min = min(extension_ratios);
   
   % Memory statistics
   performance_stats.memory.mean = mean(memory_usage) / 1024; % KB
   performance_stats.memory.max = max(memory_usage) / 1024; % KB
   performance_stats.memory.total = sum(memory_usage) / 1024^2; % MB
   
   % Error statistics
   performance_stats.errors.perfect_recovery_count = sum(error_counts == 0);
   performance_stats.errors.perfect_recovery_rate = sum(error_counts == 0) / length(error_counts) * 100;
   performance_stats.errors.max_error_count = max(error_counts);
   performance_stats.errors.max_error_ratio = max(error_ratios);
   performance_stats.errors.avg_error_ratio = mean(error_ratios);

%% Display Performance Summary
   fprintf('\n=== PERFORMANCE SUMMARY ===\n');
   fprintf('Total Tests: %d\n', performance_stats.summary.total_tests);
   fprintf('Successful: %d (%.2f%%)\n', performance_stats.summary.successful_tests, performance_stats.summary.success_rate);
   fprintf('Failed: %d\n', performance_stats.summary.failed_tests);
   fprintf('Total Time: %.3f seconds\n', performance_stats.summary.total_time);
   fprintf('Avg Time per Test: %.6f seconds\n', performance_stats.summary.avg_time_per_test);
   
   fprintf('\n=== TIMING STATISTICS ===\n');
   fprintf('Interleaving - Mean: %.6f s, Std: %.6f s, Range: [%.6f, %.6f] s\n', ...
       performance_stats.timing.interleave.mean, performance_stats.timing.interleave.std, ...
       performance_stats.timing.interleave.min, performance_stats.timing.interleave.max);
   fprintf('Deinterleaving - Mean: %.6f s, Std: %.6f s, Range: [%.6f, %.6f] s\n', ...
       performance_stats.timing.deinterleave.mean, performance_stats.timing.deinterleave.std, ...
       performance_stats.timing.deinterleave.min, performance_stats.timing.deinterleave.max);
   
   fprintf('\n=== SIZE & EXTENSION STATISTICS ===\n');
   fprintf('Data Size - Mean: %.1f, Std: %.1f, Range: [%d, %d]\n', ...
       performance_stats.size.original.mean, performance_stats.size.original.std, ...
       performance_stats.size.original.range(1), performance_stats.size.original.range(2));
   fprintf('Extension - Mean: %.3f%%, Std: %.3f%%, Range: [%.3f%%, %.3f%%]\n', ...
       performance_stats.size.extension.mean, performance_stats.size.extension.std, ...
       performance_stats.size.extension.min, performance_stats.size.extension.max);
   
   fprintf('\n=== MEMORY USAGE ===\n');
   fprintf('Mean per Test: %.2f KB, Max: %.2f KB, Total: %.2f MB\n', ...
       performance_stats.memory.mean, performance_stats.memory.max, performance_stats.memory.total);
   
   fprintf('\n=== ERROR ANALYSIS ===\n');
   fprintf('Perfect Recovery: %d/%d tests (%.2f%%)\n', ...
       performance_stats.errors.perfect_recovery_count, length(error_counts), ...
       performance_stats.errors.perfect_recovery_rate);
   fprintf('Max Error Count: %d, Max Error Ratio: %.3f, Avg Error Ratio: %.3f\n', ...
       performance_stats.errors.max_error_count, performance_stats.errors.max_error_ratio, ...
       performance_stats.errors.avg_error_ratio);
   
   if ~isempty(error_details)
       fprintf('\n=== ERROR DETAILS ===\n');
       for i = 1:min(10, length(error_details))
           fprintf('%d. %s\n', i, error_details{i});
       end
       if length(error_details) > 10
           fprintf('... and %d more errors\n', length(error_details) - 10);
       end
   end

%% Calculate and plot separation statistics
   fprintf('=== Calculating separation statistics ===\n');
   separation_results = analyze_separation_statistics(all_permutations, config, excludeZero);
   
   % Plot the separation statistics
   fprintf('\n=== Plotting separation statistics ===\n');
   plot_separation_statistics(separation_results, test_lengths);

%% Plot Performance Statistics
   fprintf('\n=== Plotting performance statistics ===\n');
   plot_performance_statistics(performance_stats, interleave_times, deinterleave_times, ...
       original_sizes, extension_ratios, error_counts, L_values, memory_usage);

%% Plot original test results (for last successful test)
   if successful_tests > 0
       figure % ('Position', [100, 100, 800, 600]);
       
       subplot(4,1,1);
       plot(1:length(A), A, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4);
       title('Original Data (Last Test)', 'FontSize', 12, 'FontWeight', 'bold');
       xlabel('Index'); ylabel('Value');
       grid on;
       
       subplot(4,1,2);
       plot(1:length(vectorInterleaved), vectorInterleaved, 'r-s', 'LineWidth', 1.5, 'MarkerSize', 4);
       title('Interleaved Data (Last Test)', 'FontSize', 12, 'FontWeight', 'bold');
       xlabel('Index'); ylabel('Value');
       grid on;
       
       subplot(4,1,3);
       plot(1:length(vectorRestored), vectorRestored, 'g-^', 'LineWidth', 1.5, 'MarkerSize', 4);
       title('Deinterleaved Data (Last Test)', 'FontSize', 12, 'FontWeight', 'bold');
       xlabel('Index'); ylabel('Value');
       grid on;
       
       subplot(4,1,4);
       minLength = min(length(A), length(vectorRestored));
       diff = A(1:minLength) - vectorRestored(1:minLength);
       stem(1:length(diff), diff, 'k', 'LineWidth', 1.5);
       title('Difference (Original - Restored)', 'FontSize', 12, 'FontWeight', 'bold');
       xlabel('Index'); ylabel('Difference');
       grid on;
       
       % Add error statistics to the plot
       [errCount, errRatio] = symerr(A(1:minLength), vectorRestored(1:minLength));
       if errCount == 0
           sgtitle(strcat(method,' Interleaver Test - PERFECT RECOVERY'), 'FontSize', 14, 'Color', 'green');
       else
           sgtitle(sprintf(strcat(method,' Interleaver Test - %d ERRORS (%.2f%%)'), errCount, errRatio*100), ...
                   'FontSize', 14, 'Color', 'red');
       end
   end

catch erripd
    errMsgipd = strcat('\n   >>> ERROR in testInterleave <<<\n');
    fprintf(errMsgipd);
    fprintf('Error message: %s\n', erripd.message);
    rethrow(erripd);
end % catch

% Helper function for inline if
function result = iif(condition, trueValue, falseValue)
    if condition
        result = trueValue;
    else
        result = falseValue;
    end
end

%%%%%%%%
function plot_performance_statistics(perf_stats, interleave_times, deinterleave_times, ...
    original_sizes, extension_ratios, error_counts, L_values, memory_usage)

    figure('Name', 'Performance Statistics'); %, 'Position', [150 50 1400 1000]);
    
    % Timing Analysis
    subplot(3,4,1);
    histogram(interleave_times * 1000, 50, 'FaceColor', [0.3 0.6 0.9], 'FaceAlpha', 0.7);
    xlabel('Time (ms)');
    ylabel('Count');
    title('Interleave Time Distribution');
    grid on;
    
    subplot(3,4,2);
    histogram(deinterleave_times * 1000, 50, 'FaceColor', [0.9 0.6 0.3], 'FaceAlpha', 0.7);
    xlabel('Time (ms)');
    ylabel('Count');
    title('Deinterleave Time Distribution');
    grid on;
    
    % Timing vs Size
    subplot(3,4,3);
    scatter(original_sizes, interleave_times * 1000, 20, L_values, 'filled');
    colorbar;
    xlabel('Data Size (N)');
    ylabel('Interleave Time (ms)');
    title('Interleave Time vs Size (colored by L)');
    grid on;
    
    subplot(3,4,4);
    scatter(original_sizes, deinterleave_times * 1000, 20, L_values, 'filled');
    colorbar;
    xlabel('Data Size (N)');
    ylabel('Deinterleave Time (ms)');
    title('Deinterleave Time vs Size (colored by L)');
    grid on;
    
    % Extension Analysis
    subplot(3,4,5);
    histogram(extension_ratios, 30, 'FaceColor', [0.6 0.9 0.6], 'FaceAlpha', 0.7);
    xlabel('Extension Ratio (%)');
    ylabel('Count');
    title('Data Extension Distribution');
    grid on;
    
    subplot(3,4,6);
    scatter(original_sizes, extension_ratios, 20, L_values, 'filled');
    colorbar;
    xlabel('Original Size (N)');
    ylabel('Extension Ratio (%)');
    title('Extension vs Size (colored by L)');
    grid on;
    
    % Memory Usage
    subplot(3,4,7);
    histogram(memory_usage / 1024, 30, 'FaceColor', [0.9 0.6 0.9], 'FaceAlpha', 0.7);
    xlabel('Memory Usage (KB)');
    ylabel('Count');
    title('Memory Usage Distribution');
    grid on;
    
    subplot(3,4,8);
    scatter(original_sizes, memory_usage / 1024, 20, L_values, 'filled');
    colorbar;
    xlabel('Data Size (N)');
    ylabel('Memory Usage (KB)');
    title('Memory vs Size (colored by L)');
    grid on;
    
    % Error Analysis
    subplot(3,4,9);
    error_histogram = histogram(error_counts, 'FaceColor', [0.9 0.3 0.3], 'FaceAlpha', 0.7);
    xlabel('Error Count');
    ylabel('Count');
    title('Error Count Distribution');
    grid on;
    
    % Success Rate by L
    subplot(3,4,10);
    unique_L = unique(L_values);
    success_rates = zeros(size(unique_L));
    for i = 1:length(unique_L)
        L_mask = L_values == unique_L(i);
        success_rates(i) = sum(error_counts(L_mask) == 0) / sum(L_mask) * 100;
    end
    bar(unique_L, success_rates, 'FaceColor', [0.4 0.8 0.4]);
    xlabel('L (Columns)');
    ylabel('Success Rate (%)');
    title('Perfect Recovery Rate by L');
    ylim([0 105]);
    grid on;
    
    % Performance vs L
    subplot(3,4,11);
    avg_interleave_time = zeros(size(unique_L));
    avg_deinterleave_time = zeros(size(unique_L));
    for i = 1:length(unique_L)
        L_mask = L_values == unique_L(i);
        avg_interleave_time(i) = mean(interleave_times(L_mask)) * 1000;
        avg_deinterleave_time(i) = mean(deinterleave_times(L_mask)) * 1000;
    end
    plot(unique_L, avg_interleave_time, 'bo-', 'LineWidth', 2, 'MarkerSize', 6);
    hold on;
    plot(unique_L, avg_deinterleave_time, 'ro-', 'LineWidth', 2, 'MarkerSize', 6);
    xlabel('L (Columns)');
    ylabel('Average Time (ms)');
    title('Average Processing Time by L');
    legend('Interleave', 'Deinterleave', 'Location', 'best');
    grid on;
    
    % Overall Performance Summary
    subplot(3,4,12);
    categories = {'Success Rate', 'Avg Speed', 'Memory Eff', 'Extension'};
    
    % Normalize metrics to 0-100 scale for radar-like display
    success_rate = perf_stats.summary.success_rate;
    speed_score = max(0, 100 - (perf_stats.timing.interleave.mean + perf_stats.timing.deinterleave.mean) * 1000 * 100);
    memory_score = max(0, 100 - perf_stats.memory.mean / 10); % Arbitrary scaling
    extension_score = max(0, 100 - perf_stats.size.extension.mean * 10); % Lower extension is better
    
    scores = [success_rate, speed_score, memory_score, extension_score];
    bar(scores, 'FaceColor', [0.5 0.5 0.8]);
    set(gca, 'XTickLabel', categories, 'XTickLabelRotation', 45);
    ylabel('Score (0-100)');
    title('Overall Performance Metrics');
    ylim([0 105]);
    grid on;
    
    % Add overall statistics text
    sgtitle(sprintf('Performance Analysis: %d tests, %.1f%% success, %.3fs total', ...
        perf_stats.summary.total_tests, perf_stats.summary.success_rate, ...
        perf_stats.summary.total_time), 'FontSize', 14, 'FontWeight', 'bold');
end

%%%%%%%%
function separation_results = analyze_separation_statistics(all_permutations, config, excludeZero)
    separation_results = struct();
    lengths = fieldnames(all_permutations);

    for i = 1:length(lengths)
        N_str = lengths{i};
        N = sscanf(N_str, 'N_%d');
        try
            pattern = all_permutations.(N_str);
            
            % Separation analysis using intraVectorSeparations
            [minSep, maxSep, avgSep, sep_norm, varSep, sepEff, sepCV, sep_raw] = ...
                intraVectorSeparations(pattern, excludeZero);
            
            % Distance analysis using intraVectorDistances
            % Using N as codeword length for full vector analysis
            [minCWmin, minCWmax, minCWavg, varCWmax, varCWavg, avgCW, blockPatternFit, ...
             minAdj, avgAdj, varAdj, cvAdj, adjDistances] = ...
                intraVectorDistances(pattern, N, excludeZero);

            % Calculate additional statistics
            medSep = median(sep_raw);
            stdSep = std(sep_raw);
            
            % Store all metrics in comprehensive structure
            stats = struct();
            
            % Separation metrics
            stats.separation.mean = avgSep;
            stats.separation.std = stdSep;
            stats.separation.min = minSep;
            stats.separation.max = maxSep;
            stats.separation.median = medSep;
            stats.separation.variance = varSep;
            stats.separation.efficiency = sepEff;
            stats.separation.coeff_variation = sepCV;
            stats.separation.raw = sep_raw;
            stats.separation.normalized = sep_norm(2,:);
            
            % Distance metrics
            stats.distance.min_intra_block_min = minCWmin;
            stats.distance.min_intra_block_max = minCWmax;
            stats.distance.min_intra_block_avg = minCWavg;
            stats.distance.var_intra_block_max = varCWmax;
            stats.distance.var_intra_block_avg = varCWavg;
            stats.distance.avg_intra_block = avgCW;
            stats.distance.min_adjacent = minAdj;
            stats.distance.avg_adjacent = avgAdj;
            stats.distance.var_adjacent = varAdj;
            stats.distance.adjCVacent = cvAdj;
            stats.distance.adjacent_distances = adjDistances;
            
            % General info
            stats.N = N;
            stats.status = 'SUCCESS';
            
            separation_results.(N_str) = stats;

        catch ME
            separation_results.(N_str) = struct('status', 'ERROR', 'error', ME.message, 'N', N);
            if config.verbose
                fprintf('FAILED: %s\n', ME.message);
            end
        end
    end
end

%%%
function plot_separation_statistics(separation_results, test_lengths)
    % Plot separation and distance statistics
    valid_lengths = [];
    
    % Separation metrics
    sep_means = []; sep_stds = []; sep_mins = []; sep_maxs = [];
    sep_effs = []; sep_cvs = []; sep_vars = [];
    
    % Distance metrics
    dist_minIntraMins = []; dist_minIntraMaxs = []; dist_minIntraAvgs = [];
    dist_varIntraMaxs = []; dist_varIntraAvgs = []; dist_avgIntras = [];
    dist_minAdjs = []; dist_avgAdjs = []; dist_varAdjs = []; dist_cvAdjs = [];
    
    % Extract all metrics
    for i = 1:length(test_lengths)
        N = test_lengths(i);
        field_name = sprintf('N_%d', N);
        
        if isfield(separation_results, field_name)
            stats = separation_results.(field_name);
            if isfield(stats, 'separation')
                valid_lengths = [valid_lengths, N];
                
                % Separation metrics
                sep_means = [sep_means, stats.separation.mean];
                sep_stds = [sep_stds, stats.separation.std];
                sep_mins = [sep_mins, stats.separation.min];
                sep_maxs = [sep_maxs, stats.separation.max];
                sep_effs = [sep_effs, stats.separation.efficiency];
                sep_cvs = [sep_cvs, stats.separation.coeff_variation];
                sep_vars = [sep_vars, stats.separation.variance];
                
                % Distance metrics
                dist_minIntraMins = [dist_minIntraMins, stats.distance.min_intra_block_min];
                dist_minIntraMaxs = [dist_minIntraMaxs, stats.distance.min_intra_block_max];
                dist_minIntraAvgs = [dist_minIntraAvgs, stats.distance.min_intra_block_avg];
                dist_varIntraMaxs = [dist_varIntraMaxs, stats.distance.var_intra_block_max];
                dist_varIntraAvgs = [dist_varIntraAvgs, stats.distance.var_intra_block_avg];
                dist_avgIntras = [dist_avgIntras, stats.distance.avg_intra_block];
                dist_minAdjs = [dist_minAdjs, stats.distance.min_adjacent];
                dist_avgAdjs = [dist_avgAdjs, stats.distance.avg_adjacent];
                dist_varAdjs = [dist_varAdjs, stats.distance.var_adjacent];
                dist_cvAdjs = [dist_cvAdjs, stats.distance.adjCVacent];
            end
        end
    end
    
    if ~isempty(valid_lengths)
        figure('Name', 'Separation and Distance Statistics'); %, 'Position', [200 50 1400 1000]);
        
        % Separation Metrics -------------------------------------------------
        % Mean separation with std dev
        subplot(3,3,1);
        plot(valid_lengths, sep_means, 'b-', 'LineWidth', 1, 'MarkerSize', 6);
        hold on;
        plot(valid_lengths, sep_means + sep_stds, 'r--', 'LineWidth', 0.5, 'MarkerSize', 6);
        plot(valid_lengths, sep_means - sep_stds, 'r--', 'LineWidth', 0.5, 'MarkerSize', 6);
        xlabel('Interleaver Size (N)');
        ylabel('Separation');
        title('Mean Separation Statistics');
        legend('Mean', '+/- Std Dev', 'Location', 'best');
        grid on;
        
        % Min/Max separation
        subplot(3,3,2);
        plot(valid_lengths, sep_mins, 'r-', 'LineWidth', 1, 'MarkerSize', 6);
        hold on;
        plot(valid_lengths, sep_maxs, 'b-', 'LineWidth', 1, 'MarkerSize', 6);
        xlabel('Interleaver Size (N)');
        ylabel('Normalized Separation');
        title('Min/Max Separation');
        legend('Min', 'Max', 'Location', 'best');
        grid on;
        
        % Separation efficiency and CV
        subplot(3,3,3);
        yyaxis left;
        plot(valid_lengths, sep_effs, 'k-', 'LineWidth', 1, 'MarkerSize', 6);
        ylabel('Efficiency');
        yyaxis right;
        plot(valid_lengths, sep_cvs, 'm-', 'LineWidth', 1, 'MarkerSize', 6);
        ylabel('CV');
        xlabel('Interleaver Size (N)');
        title('Separation Efficiency & CV');
        grid on;
        
        % Distance Metrics ---------------------------------------------------
        % Intra-block distances
        subplot(3,3,4);
        plot(valid_lengths, dist_minIntraMaxs, 'r-', 'LineWidth', 1, 'MarkerSize', 6);
        hold on;
        plot(valid_lengths, dist_minIntraAvgs, 'g-', 'LineWidth', 1, 'MarkerSize', 6);
        plot(valid_lengths, dist_minIntraMins, 'b-', 'LineWidth', 1, 'MarkerSize', 6);
        xlabel('Interleaver Size (N)');
        ylabel('Normalized Distance');
        title('Intra-block Min Distances');
        legend('Min', 'Avg', 'Max', 'Location', 'best');
        grid on;
        
        % Intra-block variance
        subplot(3,3,5);
        plot(valid_lengths, dist_varIntraMaxs, 'b-', 'LineWidth', 1, 'MarkerSize', 6);
        hold on;
        plot(valid_lengths, dist_varIntraAvgs, 'g-', 'LineWidth', 1, 'MarkerSize', 6);
        xlabel('Interleaver Size (N)');
        ylabel('Variance');
        title('Intra-block Distance Variance');
        legend('Max', 'Avg', 'Location', 'best');
        grid on;
        
        % Adjacent distances
        subplot(3,3,6);
        plot(valid_lengths, dist_minAdjs, 'r-', 'LineWidth', 1, 'MarkerSize', 6);
        hold on;
        plot(valid_lengths, dist_avgAdjs, 'b-', 'LineWidth', 1, 'MarkerSize', 6);
        xlabel('Interleaver Size (N)');
        ylabel('Normalized Distance');
        title('Adjacent Distances');
        legend('Min', 'Avg', 'Location', 'best');
        grid on;
        
        % Adjacent distance variance and CV
        subplot(3,3,7);
        yyaxis left;
        plot(valid_lengths, dist_varAdjs, 'k-', 'LineWidth', 1, 'MarkerSize', 6);
        ylabel('Variance');
        yyaxis right;
        plot(valid_lengths, dist_cvAdjs, 'm-', 'LineWidth', 1, 'MarkerSize', 6);
        ylabel('CV');
        xlabel('Interleaver Size (N)');
        title('Adjacent Distance Var & CV');
        grid on;
        
        % Comprehensive distance comparison
        subplot(3,3,8);
        plot(valid_lengths, dist_avgIntras, 'g-', 'LineWidth', 2, 'MarkerSize', 6);
        hold on;
        plot(valid_lengths, dist_avgAdjs, 'b-', 'LineWidth', 2, 'MarkerSize', 6);
        xlabel('Interleaver Size (N)');
        ylabel('Average Distance');
        title('Distance Comparison');
        legend('Intra-block', 'Adjacent', 'Location', 'best');
        grid on;
        
        % Overall quality metrics
        subplot(3,3,9);
        % Calculate normalized quality score (higher is better)
        quality_score = sep_effs .* (1 ./ sep_cvs) .* dist_minAdjs;
        quality_score = quality_score / max(quality_score) * 100; % Normalize to 0-100
        
        plot(valid_lengths, quality_score, 'k-', 'LineWidth', 2, 'MarkerSize', 6);
        xlabel('Interleaver Size (N)');
        ylabel('Quality Score (0-100)');
        title('Overall Interleaver Quality');
        grid on;
        
        sgtitle(sprintf('Separation & Distance Analysis (%d interleavers)', length(valid_lengths)), ...
                'FontSize', 14, 'FontWeight', 'bold');
    else
        fprintf('No valid separation statistics to plot.\n');
    end
end

%%%%%%%%
function [minSep, maxSep, avgSep, sep_norm, varSep, sepEff, sepCV, sep_raw] = intraVectorSeparations_sil(pattern, verbose)
% Calculate intra-vector separations for interleaver pattern analysis
    if nargin < 2
        verbose = false;
    end
    
    N = length(pattern);
    if N < 2
        error('Pattern must have at least 2 elements');
    end
    
    % Calculate all separations
    sep_raw = [];
    for i = 1:N-1
        for j = i+1:N
            sep = abs(pattern(j) - pattern(i));
            sep_raw = [sep_raw, sep];
        end
    end
    
    if isempty(sep_raw)
        minSep = 0; maxSep = 0; avgSep = 0; varSep = 0; sepEff = 0; sepCV = 0;
        sep_norm = [0; 0];
        return;
    end
    
    % Basic statistics
    minSep = min(sep_raw);
    maxSep = max(sep_raw);
    avgSep = mean(sep_raw);
    varSep = var(sep_raw);
    stdSep = std(sep_raw);
    
    % Normalized separations (by N and by max possible)
    sep_norm = [sep_raw / N; sep_raw / max(pattern)];
    
    % Efficiency metric (how well distributed are the separations)
    ideal_sep = N / length(sep_raw);
    sepEff = 1 / (1 + abs(avgSep - ideal_sep) / ideal_sep);
    
    % Coefficient of variation
    if avgSep > 0
        sepCV = stdSep / avgSep;
    else
        sepCV = Inf;
    end
    
    if verbose
        fprintf('Separation Analysis:\n');
        fprintf('  Min: %.3f, Max: %.3f, Avg: %.3f ± %.3f\n', minSep, maxSep, avgSep, stdSep);
        fprintf('  Efficiency: %.3f, CV: %.3f\n', sepEff, sepCV);
    end
end

%%%%%%%%
function [minCWmin, minCWmax, minCWavg, varCWmax, varCWavg, avgCW, ...
          minAdj, avgAdj, varAdj, cvAdj, adjDistances] = intraVectorDistances_sil(pattern, L, verbose)
% Calculate intra-vector distances for interleaver pattern analysis
    if nargin < 3
        verbose = false;
    end
    
    N = length(pattern);
    if N < 2
        error('Pattern must have at least 2 elements');
    end
    
    % Calculate adjacent distances
    adjDistances = [];
    for i = 1:N-1
        dist = abs(pattern(i+1) - pattern(i));
        adjDistances = [adjDistances, dist];
    end
    
    % Adjacent distance statistics
    if ~isempty(adjDistances)
        minAdj = min(adjDistances);
        avgAdj = mean(adjDistances);
        varAdj = var(adjDistances);
        stdAdj = std(adjDistances);
        cvAdj = stdAdj / avgAdj;
    else
        minAdj = 0; avgAdj = 0; varAdj = 0; cvAdj = 0;
    end
    
    % Intra-block analysis (if L is provided and valid)
    if L > 1 && N >= L
        numBlocks = floor(N / L);
        blockMinDists = [];
        blockAvgDists = [];
        blockVarDists = [];
        
        for b = 1:numBlocks
            blockStart = (b-1) * L + 1;
            blockEnd = min(b * L, N);
            blockPattern = pattern(blockStart:blockEnd);
            
            if length(blockPattern) > 1
                blockDists = [];
                for i = 1:length(blockPattern)-1
                    for j = i+1:length(blockPattern)
                        dist = abs(blockPattern(j) - blockPattern(i));
                        blockDists = [blockDists, dist];
                    end
                end
                
                if ~isempty(blockDists)
                    blockMinDists = [blockMinDists, min(blockDists)];
                    blockAvgDists = [blockAvgDists, mean(blockDists)];
                    blockVarDists = [blockVarDists, var(blockDists)];
                end
            end
        end
        
        % Block statistics
        if ~isempty(blockMinDists)
            minCWmin = min(blockMinDists);
            minCWmax = max(blockMinDists);
            minCWavg = mean(blockMinDists);
        else
            minCWmin = 0; minCWmax = 0; minCWavg = 0;
        end
        
        if ~isempty(blockVarDists)
            varCWmax = max(blockVarDists);
            varCWavg = mean(blockVarDists);
        else
            varCWmax = 0; varCWavg = 0;
        end
        
        if ~isempty(blockAvgDists)
            avgCW = mean(blockAvgDists);
        else
            avgCW = 0;
        end
    else
        % If L is not valid, use overall statistics
        minCWmin = minAdj;
        minCWmax = minAdj;
        minCWavg = minAdj;
        varCWmax = varAdj;
        varCWavg = varAdj;
        avgCW = avgAdj;
    end
    
    if verbose
        fprintf('Distance Analysis:\n');
        fprintf('  Adjacent - Min: %.3f, Avg: %.3f ± %.3f, CV: %.3f\n', ...
                minAdj, avgAdj, sqrt(varAdj), cvAdj);
        fprintf('  Intra-block - MinAvg: %.3f, VarAvg: %.3f, OverallAvg: %.3f\n', ...
                minCWavg, varCWavg, avgCW);
    end
end