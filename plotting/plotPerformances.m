function contData = plotPerformances(avNoise, avDecErr, avCont, intMethods, statsAll, selectedMethods)
   % If selectedMethods is not provided or is empty, use all methods
   if nargin < 6 || isempty(selectedMethods)
       selectedMethods = intMethods;
   end
   
   % Filter to only include selected methods
   [filteredMethods, methodIndices] = filterMethods(intMethods, selectedMethods);
   nMethod = length(filteredMethods);

   % extract performance data. rows are methods, cols performances 
   contData = [];
   for i=1:length(intMethods)
      method = string(intMethods(i));
      contData(i,:) = extractfield(avCont,method);
   end
   % Filter contData to only selected methods
   contData = contData(methodIndices, :);

   % extract decoding.error data. rows are methods, cols dec.err 
   errData = [];
   for i=1:length(intMethods)
      method = string(intMethods(i));
      errData(i,:) = extractfield(avDecErr,method);
   end
   % Filter errData to only selected methods
   errData = errData(methodIndices, :);

   % Create consistent color scheme for filtered methods
   colorScheme = 'colorblind';
   colors = getColorScheme(colorScheme, length(filteredMethods));
   
   % Store method names and colors for consistent legend
   methodColors = containers.Map();
   for i = 1:length(filteredMethods)
       methodColors(filteredMethods{i}) = colors(i,:);
   end

   figure('Name', 'ContVsLen'); hold on

   % Subplot 1: DecodingError rates across N
   subplot(2,2,1);
   plotErrorRates(errData, filteredMethods, avNoise, colors);
   
   % Subplot 2: Error rates vs Burst Severity 
   subplot(2,2,2);
   plotErrorVsBurstSeverity(errData, filteredMethods, avNoise, colors);

   % plot Contribution Performances vs N
   subplot(2, 2, 3);
   plotContributionVsN(statsAll, filteredMethods, colors);

   % plot Contribution Performances vs L
   subplot(2, 2, 4);
   plotContributionVsL(statsAll, filteredMethods, colors);

   % Enable data tips for hovering
   dcm_obj = datacursormode(gcf);
   set(dcm_obj, 'UpdateFcn', @hoverCallbackName);
    
   % Add single shared legend at the bottom with consistent colors
   lgdCols = min(6, length(filteredMethods)); % Adjust columns based on number of methods
   addSharedLegend(filteredMethods, lgdCols, colors);
   
end

function [filteredMethods, methodIndices] = filterMethods(allMethods, selectedMethods)
    % Filter methods to only include selected ones
    % If selectedMethods is empty, return all methods
    
    % Convert to string for consistent comparison
    allMethods = string(allMethods);
    
    % Handle empty selectedMethods case
    if isempty(selectedMethods) || (isstring(selectedMethods) && selectedMethods == "") || (ischar(selectedMethods) && isempty(selectedMethods))
        filteredMethods = allMethods;
        methodIndices = 1:length(allMethods);
        return;
    end
    
    % Convert selectedMethods to string
    selectedMethods = string(selectedMethods);
    
    % Find indices of selected methods
    [~, methodIndices] = ismember(selectedMethods, allMethods);
    validIndices = methodIndices(methodIndices > 0);
    
    % Filter the methods
    filteredMethods = allMethods(validIndices);
    methodIndices = validIndices;
end

function plotErrorRates(errData, intMethods, avNoise, colors)
    % Subplot 1: Error Rate Line Plot across different N values
    hold on;
    for i = 1:length(intMethods)
        plot(errData(i,:), 'Color', colors(i,:), 'DisplayName', intMethods{i}, ...
             'LineWidth', 1);
    end
    
    title(sprintf('Decoding Error Rates (avg noise: %.3f)', mean(avNoise,'omitnan')));
    ylabel('Error Rate');
    xlabel('Test Run Index');
    grid on;
end

function plotErrorVsBurstSeverity(errData, intMethods, avNoise, colors)
    % plot Error rates vs Burst Severity using errData directly
    % Shows how increasing noise severity affects each method's performance
    
    hold on;
    
    % errData is nMethod x nDataPoints matrix
    % avNoise is the corresponding noise levels for each data point
    nMethods = size(errData, 1);
    nDataPoints = size(errData, 2);
    
    % Ensure avNoise matches errData dimensions
    if length(avNoise) ~= nDataPoints
        warning('avNoise length (%d) does not match errData columns (%d)', ...
                length(avNoise), nDataPoints);
        % Use indices as fallback
        noise_x_axis = 1:nDataPoints;
        xlabel_text = 'Data Point Index';
        title_text = 'Error Rate vs Data Point Index';
    else
        noise_x_axis = avNoise;
        xlabel_text = 'Average Noise Level';
        title_text = 'Error Rate vs Noise Severity';
    end
    
    % Plot each method's error rate vs noise severity
    for i = 1:nMethods
        method_errors = errData(i, :);
        
        % Remove any NaN or invalid values
        valid_idx = isfinite(method_errors) & isfinite(noise_x_axis);
        clean_noise = noise_x_axis(valid_idx);
        clean_errors = method_errors(valid_idx);
        
        if ~isempty(clean_noise)
            % Sort by noise level for smooth line plotting
            [sorted_noise, sort_idx] = sort(clean_noise);
            sorted_errors = clean_errors(sort_idx);
            
            % Plot with consistent colors
            plot(sorted_noise, sorted_errors, ...
                'Color', colors(i,:), 'LineWidth', 1, 'DisplayName', intMethods{i});
        else
            warning('No valid data points for method: %s', intMethods{i});
        end
    end
    
    % Labels and formatting
    xlabel(xlabel_text);
    ylabel('Decoding Error Rate');
    title(title_text);
    grid on;
    
    % Set reasonable axis limits
    if any(isfinite(errData(:)))
        valid_errors = errData(isfinite(errData));
        if ~isempty(valid_errors)
            y_min = max(0, min(valid_errors) * 0.9);
            y_max = max(valid_errors) * 1.1;
            ylim([y_min, y_max]);
        end
    end
    
    if length(avNoise) == nDataPoints
        xlim([min(avNoise) * 0.95, max(avNoise) * 1.05]);
    end
end

function plotContributionVsN(statsAll, intMethods, colors)
% Plots contribution vs. data length (N) for multiple methods.
% Inputs:
%   statsAll    : Structure array containing method stats (fields: method, N, L, cont)
%   intMethods  : Cell array of method names to plot
%   colors      : Nx3 matrix of RGB colors for each method

    hold on;
    grid on;
    
    for i = 1:length(intMethods)
        % Filter data for the current method
        indices = strcmp(string({statsAll.method}), intMethods(i));
        filteredData = statsAll(indices);
        
        % Extract N and contributions
        Ns = double(string({filteredData.N}));
        contributions = double(string({filteredData.CR}));
        
        % Compute mean contribution per unique N
        Nunique = unique(Ns);
        Cn = zeros(size(Nunique));
        for n = 1:length(Nunique)
            Cn(n) = mean(contributions(Ns == Nunique(n)));
        end
        
        % Plot
        plot(Nunique, Cn, ...
            'Color', colors(i,:), ...
            'DisplayName', intMethods{i}, ...
            'LineWidth', 1);
        hold on;
    end
    
    xlabel('Data Length (N)');
    ylabel('Contribution');
    title('Contribution vs. Data Length');
end

function plotContributionVsL(statsAll, intMethods, colors)
% Plots contribution vs. Block length (L) for multiple methods.
% Inputs:
%   statsAll    : Structure array containing method stats (fields: method, N, L, cont)
%   intMethods  : Cell array of method names to plot
%   colors      : Nx3 matrix of RGB colors for each method

    hold on;
    grid on;
    
    for i = 1:length(intMethods)
        % Filter data for the current method
        indices = strcmp(string({statsAll.method}), intMethods(i));
        filteredData = statsAll(indices);
        
        % Extract L and contributions
        Ls = double(string({filteredData.L}));
        contributions = double(string({filteredData.CR}));
        
        % Compute mean contribution per unique L
        Lunique = unique(Ls);
        Cl = zeros(size(Lunique));
        for l = 1:length(Lunique)
            Cl(l) = mean(contributions(Ls == Lunique(l)));
        end
        
        % Plot
        plot(Lunique, Cl, ...
            'Color', colors(i,:), ...
            'DisplayName', intMethods{i}, ...
            'LineWidth', 1.5);
    end
    
    xlabel('Block Length (L)');
    ylabel('Contribution');
    title('Contribution vs. Block Length');
end

function colors = getColorScheme(colorScheme, nColors)
    switch lower(colorScheme)
        case 'colorblind'
            % FIXED: Colorblind-friendly palette with distinct colors
            % Orange, Blue, Green (matching your image)
            base_colors = [0.9,0.6,0;      % Orange (chaotic)
                          0.35,0.7,0.9;    % Light Blue (latinSquare) 
                          0,0.6,0.5;       % Teal/Green (SoddOnly)
                          0.95,0.9,0.25;   % Yellow
                          0,0.45,0.7;      % Dark Blue
                          0.8,0.4,0;       % Dark Orange
                          0.8,0.6,0.7;     % Pink
                          0.6,0.6,0.6];    % Gray
        case 'grayscale'
            % Grayscale palette
            gray_vals = linspace(0.1, 0.8, nColors);
            base_colors = [gray_vals', gray_vals', gray_vals'];
        otherwise
            % Default MATLAB colors
            base_colors = lines(nColors);
    end
    
    % Repeat colors if needed
    if nColors > size(base_colors, 1)
        colors = repmat(base_colors, ceil(nColors/size(base_colors,1)), 1);
        colors = colors(1:nColors, :);
    else
        colors = base_colors(1:nColors, :);
    end
end
