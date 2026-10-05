function plotBER_SNR(SNR_vals, BER_matrix, selectedMethods)
% Plots SNR statistics and BER vs. SNR for selected methods.
% Inputs:
%  SNR_vals : 1 x nSNR array of SNR values (dB)
%  BER_matrix : nMethod x nSNR matrix (averaged BERs per method) OR
%              struct array with method fields
%  selectedMethods: cell array of method names to plot (optional)
% Outputs:
%  Figure with two subplots: SNR statistics and BER performance.

   % Validate inputs
   if isempty(SNR_vals) || isempty(BER_matrix)
       error('Inputs SNR_vals and BER_matrix must not be empty.');
   end
   
   % Handle different input formats for BER_matrix
   if isstruct(BER_matrix)
       % If BER_matrix is a struct array, extract method names and data
       if isscalar(BER_matrix)
           % Single struct with multiple fields (methods)
           methodNames = fieldnames(BER_matrix);
           nMethod = length(methodNames);
           
           % Convert to matrix format: nMethod x nSNR
           BER_data = zeros(nMethod, length(SNR_vals));
           for i = 1:nMethod
               method_data = BER_matrix.(methodNames{i});
               if length(method_data) ~= length(SNR_vals)
                   error('Method %s has %d values but SNR_vals has %d values', ...
                       methodNames{i}, length(method_data), length(SNR_vals));
               end
               BER_data(i, :) = method_data(:)'; % Ensure row vector
           end
       else
           % Array of structs (one per SNR point)
           methodNames = fieldnames(BER_matrix(1));
           nMethod = length(methodNames);
           
           if length(BER_matrix) ~= length(SNR_vals)
               error('BER_matrix array length (%d) must match SNR_vals length (%d)', ...
                   length(BER_matrix), length(SNR_vals));
           end
           
           % Extract data: nMethod x nSNR
           BER_data = zeros(nMethod, length(SNR_vals));
           for i = 1:nMethod
               for j = 1:length(SNR_vals)
                  methodName = methodNames{i};
                  BER_data(i, j) = BER_matrix(j).(methodName);
               end
           end
       end
   else
       % Assume BER_matrix is already in nMethod x nSNR format
       [nMethod, nSNR] = size(BER_matrix);
       if nSNR ~= length(SNR_vals)
           error('BER_matrix columns (%d) must match SNR_vals length (%d)', ...
               nSNR, length(SNR_vals));
       end
       BER_data = BER_matrix;
       % Generate generic method names
       methodNames = arrayfun(@(x) sprintf('Method%d', x), 1:nMethod, 'UniformOutput', false);
   end
   
   % Filter methods if selectedMethods is provided
   if nargin >= 3 && ~isempty(selectedMethods)
       if ischar(selectedMethods)
           selectedMethods = {selectedMethods}; % Convert single string to cell
       end
       
       % Find indices of selected methods
       [~, methodIndices] = ismember(selectedMethods, methodNames);
       validIndices = methodIndices(methodIndices > 0);
       
       if isempty(validIndices)
           warning('No matching methods found. Plotting all methods.');
           validIndices = 1:nMethod;
           filteredMethodNames = methodNames;
           filteredBER_data = BER_data;
       else
           % Filter the data
           filteredMethodNames = methodNames(validIndices);
           filteredBER_data = BER_data(validIndices, :);
       end
   else
       % Plot all methods if no selection is provided
       validIndices = 1:nMethod;
       filteredMethodNames = methodNames;
       filteredBER_data = BER_data;
   end
   
   nFilteredMethods = length(validIndices);
   
   % Define markers and colors
   colors = lines(nFilteredMethods); % Distinct colors for each method
   
   figure('Name', 'SNR vs. BER');
   
   % --- Plot 1: SNR Statistics ---
   subplot(2, 1, 1);
   hold on;
   
   % Compute SNR statistics
   overall_snr_mean = mean(SNR_vals);
   overall_snr_std = std(SNR_vals);
   overall_snr_min = min(SNR_vals);
   overall_snr_max = max(SNR_vals);
   
   % Plot SNR values and statistics
   plot(SNR_vals, 'b-', 'LineWidth', 1.5, 'DisplayName', 'SNR Values');
   yline(overall_snr_mean, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Mean');
   yline(overall_snr_mean + overall_snr_std, 'm-.', 'DisplayName', '+1σ');
   yline(overall_snr_mean - overall_snr_std, 'm-.', 'DisplayName', '-1σ');
   
   % Labels and formatting
   xlabel('Sample Index');
   ylabel('SNR (dB)');
   title(sprintf('SNR Statistics: Mean=%.2f ± %.2f dB, Range=[%.2f, %.2f] dB', ...
       overall_snr_mean, overall_snr_std, overall_snr_min, overall_snr_max));
   legend('Location', 'best', 'NumColumns', 5);
   ylim([overall_snr_min * 0.9, overall_snr_max * 1.1]);
   grid on;
   
   % --- Plot 2: BER vs. SNR ---
   subplot(2, 1, 2);
   hold on;
   
   % Sort SNR values and corresponding BER data for proper line plotting
   [SNR_sorted, sort_idx] = sort(SNR_vals);
   BER_sorted = filteredBER_data(:, sort_idx);
   
   % Plot each method's BER curve
   for i = 1:nFilteredMethods
       bers = BER_sorted(i, :);
       
       % Clean the data: remove NaN/Inf values and ensure positive values
       valid_idx = isfinite(bers) & (bers > 0);
       clean_snr = SNR_sorted(valid_idx);
       clean_bers = bers(valid_idx);
       
       % Ensure minimum BER for log scale
       clean_bers = max(clean_bers, 1e-10);
       
       if ~isempty(clean_snr)
           hp = plot(clean_snr, clean_bers, ...
               'Color', colors(i,:), ...
               'LineStyle', '-', ...
               'LineWidth', 1.5, ...
               'DisplayName', filteredMethodNames{i});
           
           % Special formatting for specific methods if needed
           if strcmp(filteredMethodNames{i}, 'withoutInt')
               hp.LineStyle = '-.';
               hp.LineWidth = 2;
               hp.DisplayName = 'without interleaving';
           end
       else
           warning('No valid data points for method: %s', filteredMethodNames{i});
       end
   end
   
   % Labels and formatting
   xlabel('SNR (dB)');
   ylabel('Decode Error Rate');
   title('Decode Error Rate vs. SNR under Burst Noise');
   legend('Location', 'southwest', 'NumColumns', 5);
   grid on;
   set(gca, 'YScale', 'log');
   
   % Set reasonable axis limits
   if ~isempty(filteredBER_data)
       valid_bers = filteredBER_data(isfinite(filteredBER_data) & filteredBER_data > 0);
       if ~isempty(valid_bers)
           min_ber = min(valid_bers);
           max_ber = max(valid_bers);
           ylim([max(min_ber/10, 1e-6), min(max_ber*10, 1)]);
       else
           ylim([1e-4, 1]);
       end
   else
       ylim([1e-4, 1]);
   end
   
   xlim([min(SNR_vals)-1, max(SNR_vals)+1]);
   
   % Enable data cursor mode for interactive exploration
   datacursormode on;

   % Enable data tips for hovering
   dcm_obj = datacursormode(gcf);
   set(dcm_obj, 'UpdateFcn', @hoverCallbackName);

end
