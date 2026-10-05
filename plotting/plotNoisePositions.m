function erM = plotNoisePositions(stats_all, methods, config, rcv_enc_ns, burstSize, burstCount)
erM = "";
try    
    fig = figure('Name', 'Noise Positions'); % , 'Position', [100 100 1400 900]);
    
    lenCW = config.FECn;
    nMethods = length(methods);
    nCols = min(4, nMethods);
    % nTiles = nCols * (ceil(nMethods / nCols));
    
    % Use tiledlayout for better control over axes sharing
    t = tiledlayout(fig, ceil(nMethods / nCols), nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % For each method, plot noise distribution
    for m = 1:nMethods
        nexttile;
        plotNo = 0;
        plotMethodNoisePositions(stats_all, methods, lenCW, plotNo);
    end
    
    sgtitle(sprintf('Deinterleaved Noise Positions (N=%d, CW Len=%d, Burst=%.2f×%.1f)', ...
            length(rcv_enc_ns), lenCW, burstSize, burstCount), 'FontSize', 12, 'FontWeight', 'bold');

   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
    
catch ME
   erM = sprintf('*** %s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   fprintf('%s\n', erM);
end
end

%%%%

function [] = plotMethodNoisePositions(stats_all, intMethods, lenCW, plotNo)
try
   % Number of arrays 
   M = length(intMethods);

   % Calculate the number of subplot rows&cols
   max_rows = 12;
   num_rows = length(intMethods)+2;
   num_cols = 1;
   if M > max_rows
      num_rows = max_rows;
      num_cols = ceil(M / num_rows);
   end

   for k=1:M
      % extract data for every int. method
      indices = strcmp(string({stats_all.method}), intMethods(k));
      filteredData = stats_all(indices);
      
      [rows,cols] = size(filteredData);
      lastData = filteredData(:,cols);
      noiseLocations = (lastData.noiseLocations);
      permutation = lastData.permutation;

      N = length(permutation);
      
      % Convert noiseLocations to binary mask
      if all(noiseLocations == 0 | noiseLocations == 1)
          % Case 1: Already binary mask (0s and 1s)
          if length(noiseLocations) == N
              binaryMask = noiseLocations;
          else
              % If binary mask but wrong length, use it as is
              binaryMask = noiseLocations;
              N = length(binaryMask);
          end
      else
          % Case 2: noiseLocations contains indices (e.g., [115, 116, 117, ...])
          % Create binary mask of zeros
          binaryMask = zeros(1, N);
          
          % Only set positions that are within valid range
          validIndices = noiseLocations(noiseLocations >= 1 & noiseLocations <= N);
          if ~isempty(validIndices)
              binaryMask(validIndices) = 1;
          end
      end
      
      % Use the binary mask to find noisy positions in permutation
      noise_idx = find(binaryMask == 1);
      
      % Map through permutation if needed
      if length(binaryMask) == length(permutation)
          noisyPositions = permutation(noise_idx);
      else
          % If binary mask doesn't match permutation length, use noise_idx directly
          noisyPositions = noise_idx;
      end

      % Create the new interleaved binary mask
      noise_vector = zeros(1, N); 
      noise_vector(noisyPositions) = 1;
            
      % Find the indices where error_vector is 1
      error_idx = find(noise_vector); 

      % Plot the error positions
      subplot(num_rows, num_cols, k+plotNo);
      hold on;
      plot(error_idx, zeros(size(error_idx)), 'r', 'Marker', 'x', 'MarkerSize', 11);

      ttl = strcat(intMethods(k),' - Corrupted count:', num2str(length(error_idx)), ' (', num2str((length(error_idx)/N),2), ')');
      xlabel(ttl, 'FontSize', 11);
      xlim([1, N]);
      ylim([-.10 .10]);
      % Remove y-axis ticks and labels
      set(gca, 'YTick', [], 'YTickLabel', []);

      % Adjust subplot parameters
      % set(gca, 'Position', get(gca, 'Position') + [0.01, 0, -0.02, 0]);

      if k < M-1
         % Remove x-axis labels for all other subplots
         set(gca, 'XTickLabel', []);
      end

      % title(intMethods(k));
      grid on;

      % Add vertical dashed lines to indicate CWs
      for c = lenCW:lenCW:N
         % grid on; 
         hold on;
         % plot([c, c], 1, 'k--');
         line([c c], [-.20 .20], 'Color', 'b', 'LineStyle', '--');
      end
   end

   % % Adjust figure properties to reduce column gap
   % set(gcf, 'Units', 'normalized', 'Position', [0.1, 0.1, 0.8, 0.8]);

   sgttl = strcat('Permuted Noise (CW len:', num2str(lenCW), ' K:', num2str(round(N/lenCW)), ')');
   sgtitle(sgttl,'FontSize',12);
      
catch errdm
   rethrow(errdm);
end % catch
end
