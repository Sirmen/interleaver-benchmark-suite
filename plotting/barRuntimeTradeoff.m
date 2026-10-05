function barRuntimeTradeoff(results, KPItableSummary, selectedMethods, config)
% PLOTCOMBINEDTRADEOFF Combines runtime analysis and performance metrics
% into a single horizontal bar chart sorted by efficiency.
%
% DO NOT PUT THIS FIGURE IN THE PAPER. IT NO LONGER MEASURES THE ALGORITHMS.
% ---------------------------------------------------------------------------
% Since the precomputed table was introduced, every cached method's "runtime"
% is the cost of one containers.Map lookup plus one gather - identical work
% regardless of whether the permutation came from a closed form or from an
% O(N^2) greedy search. The methods that are NOT cached (random, freqRandom,
% and any length outside the table) pay their real construction cost instead.
% So the bars compare "table lookup" against "actual algorithm", and the
% ranking is an artefact of what happens to be cached.
%
% It was already unfair before the table - some methods come from MATLAB's
% Communications Toolbox (compiled) and S-Interleaving does not (interpreted) -
% which is why the plan is to replace the runtime comparison in the manuscript
% with a TIME AND MEMORY COMPLEXITY table. Keep this figure for spotting
% pathological slowness during development; do not publish it, and do not read
% the efficiency ranking as a result.
%
% Two fixes below (2026): the brace-indexing crash on non-cell method lists,
% and a scalar-assignment crash on duplicated summary rows.
%
% INPUT:
%   results          - Struct with avIntRuntime_all (e.g., results.avIntRuntime_all.random)
%   KPItableSummary  - Table with 'method' and 'RES' columns
%   selectedMethods          - Cell array of method names
%   config           - Config struct with saveResults and dataSavePath

    % ARITY GUARD. This function takes FOUR arguments. plot_all_results used to
    % call it with three (results.avIntRuntime_all, selectedMethods, config),
    % which shifted everything left: config landed in selectedMethods and was
    % then indexed as a cell array. The resulting "Brace indexing is not
    % supported for variables of this type" pointed at line 17 of this file and
    % said nothing about the caller. Checked explicitly, once, here.
    if nargin < 4
        error(['barRuntimeTradeoff needs 4 arguments:\n' ...
               '    barRuntimeTradeoff(results, KPItableSummary, selectedMethods, config)\n' ...
               'Got %d. Note the FIRST argument is the whole results struct, not\n' ...
               'results.avIntRuntime_all - this function looks that field up itself.'], nargin);
    end
    if ~isstruct(results) || ~isfield(results, 'avIntRuntime_all')
        error(['barRuntimeTradeoff: first argument must be the results struct ' ...
               'containing avIntRuntime_all (got a %s).'], class(results));
    end
    if ~isa(KPItableSummary, 'table') && ~isstruct(KPItableSummary)
        error(['barRuntimeTradeoff: second argument must be KPItableSummary ' ...
               '(got a %s) - check the argument order at the call site.'], class(KPItableSummary));
    end

    % selectedMethods arrives as a cell array, a string array, a char row, a
    % categorical, or a table column depending on the caller. Line 17 used
    % selectedMethods{i} unconditionally, which is why a string array produced
    %     "Brace indexing is not supported for variables of this type"
    % Normalised once here so every downstream use is a plain cellstr.
    selectedMethods = local_toCellstr(selectedMethods);

    nselectedMethods = length(selectedMethods);
    performance = zeros(1, nselectedMethods);
    runtime = zeros(1, nselectedMethods);

    summaryMethods = local_toCellstr(KPItableSummary.method);

    % --- Data Extraction ---
    for i = 1:nselectedMethods
        method = selectedMethods{i};
        selectedMethodstr = char(method); % Ensure it's a char for field access

        % 1. Get RES (Performance) from the Summary Table
        idx = strcmp(summaryMethods, method);
        if any(idx)
            % find(idx,1): a duplicated method row would otherwise assign a
            % 2-element vector into a scalar slot and abort the whole figure.
            performance(i) = KPItableSummary.RES(find(idx, 1));
        else
            performance(i) = NaN;
        end
        
        % 2. Get Runtime from the results struct
        % FIX: results.avIntRuntime_all is a struct array. 
        % [results.avIntRuntime_all.(selectedMethodstr)] concatenates all 341 entries into one vector.
        if isfield(results, 'avIntRuntime_all') && isfield(results.avIntRuntime_all, selectedMethodstr)
            try
                % Concatenate all struct array entries for this field into one numeric array
                allRuntimes = [results.avIntRuntime_all.(selectedMethodstr)];
                runtime(i) = mean(allRuntimes, 'omitnan');
            catch
                runtime(i) = NaN;
            end
        else
            runtime(i) = NaN;
        end
    end
    
    % --- Efficiency Calculation ---
    % Shift RES to be positive for ratio calculation
    minP = min(performance, [], 'omitnan');
    RES_shifted = performance - minP; 
    efficiency = RES_shifted ./ (runtime + 1e-12); % Use small epsilon
    
    % Normalize efficiency [0, 1] for the primary bar length
    maxE = max(efficiency, [], 'omitnan');
    minE = min(efficiency, [], 'omitnan');
    if maxE > minE
        normEfficiency = (efficiency - minE) / (maxE - minE);
    else
        normEfficiency = ones(size(efficiency));
    end
    
    % --- Sorting ---
    [sortedNormEff, sortIdx] = sort(normEfficiency, 'descend');
    sortedselectedMethods = selectedMethods(sortIdx);
    sortedRuntime = runtime(sortIdx);
    sortedRES = performance(sortIdx);
    
    % --- Plotting ---
    fig = figure('Name', 'Performance-Complexity Combined', 'Color', 'w'); %, 'Position', [100 100 950 650]);
    
    % Use narrower bars and professional blue
    barWidth = 0.65;
    b = barh(sortedNormEff, barWidth);
    b.FaceColor = [0.7, 1.0, 0.8]; 
    b.EdgeColor = 'k';
    b.LineWidth = 0.5;
    
    % Aesthetics
    set(gca, 'YDir', 'reverse'); % Highest efficiency at top
    set(gca, 'YTick', 1:nselectedMethods, 'YTickLabel', sortedselectedMethods);
    set(gca, 'FontSize', 10, 'TickLabelInterpreter', 'none');
    xlabel('Normalized Efficiency (RES_{norm} / Runtime)', 'FontSize', 11, 'FontWeight', 'bold');
    title({'Interleaving Performance vs. Runtime Tradeoff', ...
           'Efficiency = (RES - minRES) / Runtime'}, 'FontSize', 12, 'FontWeight', 'bold');
    
    grid on;
    xlim([0 1.4]); % Space for columns
    
    % --- Data Columns and Labels ---
    for i = 1:nselectedMethods
        % 1. Bar labels (4-digit precision)
        % text(sortedNormEff(i) + 0.01, i, compose('%.4f', sortedNormEff(i)), ...
        %     'FontSize', 8, 'VerticalAlignment', 'middle', 'FontAngle', 'italic');
        if sortedNormEff(i) > 0.15
            % Inside bar (black text)
            text(sortedNormEff(i) - 0.05, i, sprintf('%.3f', sortedNormEff(i)), ...
                 'FontSize', 9, 'Color', [0, 0, 0], ...
                 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'right');
        else
            % Outside bar (black text)
            text(sortedNormEff(i) + 0.02, i, sprintf('%.3f', sortedNormEff(i)), ...
                 'FontSize', 9, 'Color', [0, 0, 0], ...
                 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left');
        end
        
        % 2. RES Column
        text(1.15, i, sprintf('%.2f', sortedRES(i)), ...
            'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.5], ...
            'HorizontalAlignment', 'center');
            
        % 3. Runtime Column
        rt = sortedRuntime(i);
        if rt < 0.001
            rtStr = sprintf('%.0fµs', rt * 1e6);
        elseif rt < 1
            rtStr = sprintf('%.1fms', rt * 1000);
        else
            rtStr = sprintf('%.2fs', rt);
        end
        text(1.30, i, rtStr, ...
            'FontSize', 9, 'Color', [0.3 0.3 0.3], 'HorizontalAlignment', 'center');
    end
    
    % Headers for the pseudo-table
    text(1.15, 0.2, 'RES', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    text(1.30, 0.2, 'Runtime', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    % Adjust margins for layout
    ax = gca;
    ax.Position(1) = 0.22; % More room for long method names
    ax.Position(3) = 0.60; % Space for the text columns
    
    % Add threshold lines
    xline(0.8, '--', 'Color', [0.2, 0.6, 0.2], 'LineWidth', 1.5, 'Alpha', 0.4);
    xline(0.5, '--', 'Color', [0.9, 0.6, 0.2], 'LineWidth', 1.5, 'Alpha', 0.4);
    text(0.8, 0.3, 'High Efficiency', 'FontSize', 8, 'Color', [0.2, 0.6, 0.2], ...
         'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
         'BackgroundColor', [1, 1, 1, 0.8]);
    text(0.5, 0.3, 'Moderate', 'FontSize', 8, 'Color', [0.9, 0.6, 0.2], ...
         'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
         'BackgroundColor', [1, 1, 1, 0.8]);
    
    % --- Save Logic ---
    if isfield(config, 'saveResults') && config.saveResults
        sMsg = savePlot(fig, config.dataSavePath); 
        fprintf('Combined Tradeoff Plot Saved: %s\n', sMsg);
    end
end

function sMsg = savePlot(fig, savePath)
    % Helper to mimic your existing savePlot functionality
    if ~exist(savePath, 'dir'), mkdir(savePath); end
    fullPath = fullfile(savePath, 'Combined_Tradeoff_Plot.png');
    saveas(fig, fullPath);
    sMsg = fullPath;
end

function c = local_toCellstr(x)
%LOCAL_TOCELLSTR  cell / string array / char / categorical -> cellstr row.
   if isstruct(x)
      % Checked FIRST and named explicitly: a struct arriving here is the
      % signature of a dropped or reordered argument at the call site, not an
      % exotic method-list type. Saying so beats falling through to a generic
      % "cannot interpret" further down.
      error(['%s: got a struct where the method list should be. ' ...
             'Check the argument order at the call site.'], mfilename);
   elseif iscellstr(x)
      c = x(:)';
   elseif isstring(x)
      c = cellstr(x(:)');
   elseif ischar(x)
      if size(x, 1) > 1
         c = cellstr(x)';        % char matrix, one method per row
      else
         c = {x};
      end
   elseif exist('iscategorical', 'builtin') || exist('iscategorical', 'file')
      if iscategorical(x)
         c = cellstr(x(:)');
         return;
      end
      c = local_lastResort(x);
   elseif iscell(x)
      c = cellfun(@char, x(:)', 'UniformOutput', false);
   else
      error(['barRuntimeTradeoff: cannot interpret a %s as a method list.\n' ...
             'A struct here almost always means the call site dropped an argument - ' ...
             'the signature is (results, KPItableSummary, selectedMethods, config).'], class(x));
   end
end

function c = local_lastResort(x)
   if iscell(x)
      c = cellfun(@char, x(:)', 'UniformOutput', false);
   else
      error('%s: cannot interpret a %s as a method list', mfilename, class(x));
   end
end
