function [] = plotNoise(true_snr, originalData, noisyData, lenCW, lenBurst, numBurst, num_rows)
try
   %% Plot the change in true SNR graphically
   % figure;
   subplot(num_rows, 1, 1);
   plot(true_snr, 'b-');
   xlabel('sampling');
   % Remove x-axis ticks and labels
   % % set(gca, 'XTick', [], 'XTickLabel', []);
   set(gca, 'XTickLabel', []);
   ylabel('true SNR (dB)');
   title('True SNR with Error Bursts');
   grid on;   % Add vertical lines to indicate codeword grids
   for i = 1:lenCW:size(originalData, 1)
      hold on;
      plot([i, i], [min(originalData(:)), max(originalData(:))], 'k--');
   end
   ylim([(min(true_snr) * 0.8) (max(true_snr) * 1.2)]);

   %% Plot the burst noise positions
   subplot(num_rows, 1, 2);
   
   % Generate the linear indices for the data
   N = length(originalData);
   noise_vector = zeros(1, N);
   
   % Set the error positions to 1
   noise = noisyData - originalData;
   error_indices = find(noise ~= 0); 
   noise_vector(error_indices(:)) = 1;

   % Find the indices where error_vector is 1
   error_indices = find(noise_vector); 
   
   plot(error_indices, zeros(size(error_indices)), 'r', 'Marker', 'd', 'MarkerSize', 10);
   
   xlabel('noise burst positions on codewords');
   xlim([1, N]);
   ylim([-.10 .10]);
   % Remove y-axis ticks and labels
   set(gca, 'YTick', [], 'YTickLabel', []);

   sttl1 = strcat('Last Received Signal with Noise Bursts');
   sttl2 = strcat('L:', num2str(lenCW), ' K:', num2str(round(N/lenCW)), ' - BurstSize:',  num2str(lenBurst,2), ' BurstCount:',  num2str(numBurst,2), ' AverageNoise:',  num2str((lenBurst*numBurst)/N,2));
   title({sttl1, sttl2});
   grid on;
   
   % Add vertical lines to indicate codeword grids
   for i = 1:lenCW:N
      hold on;
      plot([i, i], [min(noise(:)), max(noise(:))], 'b--');
   end

   sgtitle(strcat('Signal With Noise Bursts'),'FontSize',12);
   hold off;
catch errplot
    rethrow(errplot);
end % catch
end
