function saveCrossCorrelationResults(crossCorrResults, config)
% Save cross-correlation analysis to text file

   metrics = config.correlationVariables;
   dataSavePath = config.dataSavePath;

   crossCorrMatrix = crossCorrResults.crossCorrMatrix;
   validMetrics = crossCorrResults.validMetrics;

   % Step 1: Create version string (YYMMDD_version)
   dateStr = char(string(datetime('now', 'Format', 'yyMMdd')));

   % Same regime tag as save_results.m. Deriving it from config.singleBurst
   % alone would file the Gilbert-Elliott cross-correlations under
   % 'single_'/'multi_' and mix them with the fixed-burst runs.
   burstType = burstRegimeTag(config);

   % Same grid tag as save_results.m, for the same reason: the regime alone
   % does not say which length grid produced the file, so a common-grid and a
   % standards-grid run of one regime were distinguishable only by the trailing
   % counter. Optional, so an older config without the field still writes -
   % under the old, ambiguous name.
   if isfield(config, 'gridMode') && ~isempty(config.gridMode)
      gridTag = regexprep(char(config.gridMode), '[^A-Za-z0-9]', '');
   else
      gridTag = '';
   end
   if isempty(gridTag)
      tagPart = burstType;
   else
      tagPart = sprintf('%s_%s', burstType, gridTag);
   end

   % NOTE: dateStr carries the tags as well as the date, because the version
   % counter below searches for '*<dateStr>_*' - the counter must be scoped to
   % the same regime AND grid, or a standards run would continue the numbering
   % of a common run and the two would look like versions of one another.
   dateStr = strcat(tagPart, '_', dateStr);

   ext = 'txt';

   try
      % Search for existing files matching the pattern: *YYMMDD_*.<ext>
      existingFiles = dir(fullfile(dataSavePath, ['*' dateStr '_*.' ext]));
      
      % Extract the version number (the digit group after YYMMDD_)
      % Example file name: MyData_251006_5.mat -> extracts '5'
      tokens = regexp({existingFiles.name}, [dateStr '_(\d+)\.' ext '$'], 'tokens');
      
      % Convert extracted tokens to numbers, filtering out files that didn't match the pattern
      nums = cellfun(@(x) str2double(x{1}), tokens(~cellfun('isempty', tokens)));
      
      % Determine the new copy number (max found + 1, or 1 if none found)
      copyNum = max([0, nums]) + 1;
      
   catch ME
       fprintf('Warning during version check: %s\n', ME.message);
       copyNum = 1;
   end
   
   versionSuffix = sprintf('_%s_%d', dateStr, copyNum); % e.g., _251006_1

   % Construct the full filename: crossCorrResults_YYMMDD_version.txt
   fileName = fullfile(dataSavePath, ['crossCorrResults' versionSuffix '.' ext]);

   % write file
   fid = fopen(fileName, 'w');
   if fid == -1
      warning('Could not create cross-correlation results file: %s', fileName);
      return;
   end
    
   try
      % Write header
      fprintf(fid, 'CROSS-CORRELATION ANALYSIS OF METRICS\n');
      fprintf(fid, '=================================================================\n');
      fprintf(fid, 'Generated: %s\n', datestr(now));
      fprintf(fid, 'Number of metrics: %d\n\n', length(metrics));
      
      % Find and report strongest correlations
      n = length(metrics);
      pairs = [];
      for i = 1:n
         for j = i+1:n
            if ~isnan(crossCorrMatrix(i,j))
               pairs = [pairs; i, j, crossCorrMatrix(i,j)];
            end
         end
      end
      
      [~, sortIdx] = sort(abs(pairs(:,3)), 'descend');
      pairs = pairs(sortIdx, :);
      
      fprintf(fid, 'TOP 50 STRONGEST CROSS-CORRELATIONS\n');
      fprintf(fid, '%-6s %-30s - %-30s %8s\n', 'Rank', 'Metric 1', 'Metric 2', 'r');
      fprintf(fid, '-----------------------------------------------------------------\n');
      
      for k = 1:min(50, size(pairs, 1))
         i = pairs(k, 1);
         j = pairs(k, 2);
         r = pairs(k, 3);
         
         fprintf(fid, '%-6d %-30s - %-30s %8.3f\n', ...
         k, metrics{i}, metrics{j}, r);
      end
      
      % Identify redundant metrics (|r| > 0.95)
      fprintf(fid, 'REDUNDANT METRIC PAIRS (|r| > 0.95)\n');
      fprintf(fid, '-----------------------------------------------------------------\n');
      
      redundantCount = 0;
      for k = 1:size(pairs, 1)
         if abs(pairs(k, 3)) > 0.95
            redundantCount = redundantCount + 1;
            i = pairs(k, 1);
            j = pairs(k, 2);
            fprintf(fid, '  %s - %s (r = %.4f)\n', ...
            metrics{i}, metrics{j}, pairs(k, 3));
         end
      end
      
      if redundantCount == 0
         fprintf(fid, '  No redundant metric pairs found.\n');
      end
      
      % Metric groups by correlation
      fprintf(fid, 'METRIC GROUPS (|r| > 0.80)\n');
      fprintf(fid, '-----------------------------------------------------------------\n');
      
      groups = findMetricGroups(crossCorrMatrix, metrics, 0.80);
      for g = 1:length(groups)
         fprintf(fid, '\nGroup %d (%d metrics):\n', g, length(groups{g}));
         for m = 1:length(groups{g})
            fprintf(fid, '  - %s\n', groups{g}{m});
         end
      end
      
      % Full correlation matrix (compact format)
      fprintf(fid, 'FULL CROSS-CORRELATION MATRIX\n');
      fprintf(fid, '=================================================================\n\n');
      
      for i = 1:n
         fprintf(fid, '%s:\n', metrics{i});
         for j = 1:n
            if i ~= j && ~isnan(crossCorrMatrix(i,j))
               fprintf(fid, ' %-30s: %7.3f\n', metrics{j}, crossCorrMatrix(i,j));
            end
         end
         fprintf(fid, '\n');
      end
      
      fprintf(fid, '=================================================================\n');
      fprintf(fid, 'END OF CROSS-CORRELATION ANALYSIS\n');
      
      fclose(fid);
      fprintf('Cross-correlation results saved to: %s\n', fileName);
      
   catch ME
      fclose(fid);
      warning('Error writing cross-correlation file: %s', ME.message);
   end
end

function groups = findMetricGroups(corrMatrix, metrics, threshold)
    % Find groups of highly correlated metrics
    n = length(metrics);
    visited = false(n, 1);
    groups = {};
    
    for i = 1:n
        if visited(i)
            continue;
        end
        
        % Start new group
        group = {metrics{i}};
        visited(i) = true;
        
        % Find all metrics correlated with this one
        for j = i+1:n
            if ~visited(j) && abs(corrMatrix(i,j)) > threshold
                group{end+1} = metrics{j};
                visited(j) = true;
            end
        end
        
        % Only keep groups with 2+ members
        if length(group) > 1
            groups{end+1} = group;
        end
    end
end
