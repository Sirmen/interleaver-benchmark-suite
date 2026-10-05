close all; clear all; 
N = 40;
data = 1:N;  % [1, 2, 3, 4, 5];
% data = randi([0, 8-1], 1, N);
[interleaved, permutation, rows, slope, err] = interleaver_convolutional_a(data, 'Verbose', true);

% if isempty(err)
    % Analyze the permutation pattern statistically
    stats = analyzePermutationPattern(permutation, length(data), 'PlotResults', true, 'Verbose', true);
    
    % The permutation vector tells you: permutation(i) = output_position_of_input_i
    fprintf('Input position 1 goes to output position %d\n', permutation(1));
    fprintf('Input position 2 goes to output position %d\n', permutation(2));
    
    % we can also use:
    % - stats.displacement: how far each element moved
    % - stats.distance: absolute distance moved
    % - stats.locality.correlation: how much locality is preserved
    % - stats.interleaving.meanSeparation: average separation between consecutive elements
% end

demonstrateDeinterleaver();

%%%

function demonstrateDeinterleaver()
    fprintf('\n=== SIMPLE DEINTERLEAVER DEMO ===\n');
    
    % Test data
    N = 12;
    originalData = randi([1, 50], N, 1);
    
    fprintf('Original data: [%s]\n', num2str(originalData'));
    
    % Interleave
    [interleavedData, ~, ~, ~, erM, stats] = interleaver_convolutional_a(originalData, 'Verbose', false);
    
    if erM ~= ""
        fprintf('Interleaver error: %s\n', erM);
        return;
    end
    
    fprintf('Interleaved:   [%s]\n', num2str(interleavedData'));
    
    % Prepare full transmission (interleaved + delay padding)
    fullTransmission = [interleavedData(:); repmat(NaN, stats.totalDelay, 1)];
    fprintf('Transmitted:   %d symbols (%d data + %d delay)\n', ...
        length(fullTransmission), length(interleavedData), stats.totalDelay);
    
    % Deinterleave - ONE LINE OF CODE!
    [recoveredData, erM] = deinterleaver_convolutional_a(fullTransmission, stats, 'Verbose', true);
    
    if erM ~= ""
        fprintf('Deinterleaver error: %s\n', erM);
        return;
    end
    
    fprintf('Recovered:     [%s]\n', num2str(recoveredData'));
    
    % Verify
    success = isequal(originalData, recoveredData);
    fprintf('Perfect recovery: %s\n', mat2str(success));
    
    if success
        fprintf('✓ DEINTERLEAVER SUCCESS!\n');
    else
        fprintf('✗ DEINTERLEAVER FAILED!\n');
        fprintf('  Differences at positions: %s\n', ...
            num2str(find(originalData ~= recoveredData)'));
        fprintf("  stats.forward: %s\n", num2str(stats.forward));
        fprintf("  stats.inverse: %s\n", num2str(stats.inverse));
    end
end

%%%

function stats = analyzePermutationPattern(permutation, originalLength, varargin)
% Analyze statistical properties of interleaver permutation pattern
%
% Usage:
%   stats = analyzePermutationPattern(permutation, originalLength)
%   stats = analyzePermutationPattern(permutation, originalLength, 'PlotResults', true)
%
% Inputs:
%   permutation    - Permutation vector from interleaver
%   originalLength - Length of original data (before padding)
%   
% Optional parameters:
%   'PlotResults'  - Generate visualization plots (default: false)
%   'Verbose'      - Display detailed statistics (default: true)

   p = inputParser;
   addRequired(p, 'permutation');
   addRequired(p, 'originalLength');
   addParameter(p, 'PlotResults', false, @islogical);
   addParameter(p, 'Verbose', true, @islogical);
   parse(p, permutation, originalLength, varargin{:});
   
   plotResults = p.Results.PlotResults;
   verbose = p.Results.Verbose;
   
   % Initialize statistics structure
   stats = struct();
   
   % Basic properties
   N = length(permutation);
   stats.totalLength = N;
   stats.originalLength = originalLength;
   stats.paddingLength = N - originalLength;
   
   % Displacement analysis
   displacement = permutation - (1:N);
   stats.displacement.mean = mean(displacement);
   stats.displacement.std = std(displacement);
   stats.displacement.max = max(displacement);
   stats.displacement.min = min(displacement);
   stats.displacement.range = stats.displacement.max - stats.displacement.min;
   
   % Distance metrics (how far elements move)
   distances = abs(displacement);
   stats.distance.mean = mean(distances);
   stats.distance.std = std(distances);
   stats.distance.max = max(distances);
   stats.distance.median = median(distances);
   
   % Locality analysis (how much the permutation preserves locality)
   % Measure correlation between original and permuted positions
   [correlation, pValue] = corr((1:N)', permutation');
   stats.locality.correlation = correlation;
   stats.locality.pValue = pValue;
   stats.locality.preserved = correlation > 0.5; % Threshold for "locality preserved"
   
   % Spread analysis
   stats.spread.totalSpread = max(permutation) - min(permutation) + 1;
   stats.spread.efficiency = stats.spread.totalSpread / N; % 1.0 = uses all positions
   
   % Clustering analysis - find runs of consecutive input positions
   consecutiveRuns = [];
   currentRun = 1;
   for i = 2:N
       if permutation(i) == permutation(i-1) + 1
           currentRun = currentRun + 1;
       else
           consecutiveRuns = [consecutiveRuns, currentRun];
           currentRun = 1;
       end
   end
   consecutiveRuns = [consecutiveRuns, currentRun];
   
   stats.clustering.meanRunLength = mean(consecutiveRuns);
   stats.clustering.maxRunLength = max(consecutiveRuns);
   stats.clustering.numRuns = length(consecutiveRuns);
   stats.clustering.fragmentation = stats.clustering.numRuns / N; % Higher = more fragmented
   
   % Interleaving depth analysis (for convolutional interleavers)
   % Look at the pattern of how positions are separated
   separations = [];
   for i = 1:N-1
       sep = permutation(i+1) - permutation(i);
       separations = [separations, sep];
   end
   
   stats.interleaving.meanSeparation = mean(abs(separations));
   stats.interleaving.stdSeparation = std(separations);
   stats.interleaving.maxJump = max(abs(separations));
   
   % Randomness tests
   % Test if permutation looks random vs. structured
   expectedMean = (N+1)/2;
   actualMean = mean(permutation);
   stats.randomness.meanDeviation = abs(actualMean - expectedMean);
   stats.randomness.isStructured = stats.randomness.meanDeviation > N/10; % Heuristic threshold
   
   % Block interleaving detection
   % Check if this could be from a block interleaver
   blockSizes = [2:20]; % Test common block sizes
   bestBlockFit = 0;
   bestBlockSize = 0;
   for blockSize = blockSizes
       if N >= blockSize
           % Test if permutation follows block interleaving pattern
           fit = calcBlockPatternFitScore(permutation, blockSize);
           if fit > bestBlockFit
               bestBlockFit = fit;
               bestBlockSize = blockSize;
           end
       end
   end
   stats.blockPattern.bestFit = bestBlockFit;
   stats.blockPattern.bestBlockSize = bestBlockSize;
   stats.blockPattern.isBlockInterleaver = bestBlockFit > 0.8; % Threshold for block detection
   
   % Statistical distribution of positions
   [entropy, entropyNormalized] = calcEntropy1D(permutation); 
   stats.distribution.entropy = entropy; 
   stats.distribution.entropyNormalized = entropyNormalized; 
   stats.distribution.uniformity = calcUniformityScore(permutation);
   
   % Display results
   if verbose
       fprintf('\n=== PERMUTATION PATTERN ANALYSIS ===\n');
       fprintf('Data length: %d (original: %d, padding: %d)\n', N, originalLength, stats.paddingLength);
       fprintf('\nDisplacement Statistics:\n');
       fprintf('  Mean displacement: %.2f\n', stats.displacement.mean);
       fprintf('  Std displacement:  %.2f\n', stats.displacement.std);
       fprintf('  Max displacement:  %d\n', stats.displacement.max);
       fprintf('  Min displacement:  %d\n', stats.displacement.min);
       fprintf('  Range:            %d\n', stats.displacement.range);
       
       fprintf('\nDistance Statistics:\n');
       fprintf('  Mean distance:    %.2f\n', stats.distance.mean);
       fprintf('  Median distance:  %.2f\n', stats.distance.median);
       fprintf('  Max distance:     %d\n', stats.distance.max);
       
       fprintf('\nLocality Analysis:\n');
       fprintf('  Position correlation: %.3f (p=%.4f)\n', stats.locality.correlation, stats.locality.pValue);
       if stats.locality.preserved
           fprintf('  Locality preserved:   YES\n');
       else
           fprintf('  Locality preserved:   NO\n');
       end
       
       fprintf('\nInterleaving Pattern:\n');
       fprintf('  Mean separation:      %.2f\n', stats.interleaving.meanSeparation);
       fprintf('  Max jump:            %d\n', stats.interleaving.maxJump);
       fprintf('  Mean run length:     %.2f\n', stats.clustering.meanRunLength);
       fprintf('  Fragmentation:       %.3f\n', stats.clustering.fragmentation);
       
       fprintf('\nPattern Classification:\n');
       if stats.randomness.isStructured
           fprintf('  Appears structured:   YES\n');
       else
           fprintf('  Appears structured:   NO\n');
       end
       fprintf('  Block interleaver fit: %.2f (size %d)\n', stats.blockPattern.bestFit, stats.blockPattern.bestBlockSize);
       fprintf('  Entropy_raw:           %.3f\n', stats.distribution.entropy);
       fprintf('  Entropy-Normalized:    %.3f\n', stats.distribution.entropyNormalized);
   end
   
   % Generate plots if requested
   if plotResults
       generatePermutationPlots(permutation, stats);
   end

end

%%%%%%%%%%

function [vectorInterleaved, permutation, bufferRows, bufferSlope, erM, permutationStats] = interleaver_convolutional_a(inData, varargin)
% CONVOLUTIONAL INTERLEAVER WITH PERMUTATION ANALYSIS
% Enhanced version with:
% - Robust permutation pattern extraction
% - Comprehensive error checking
% - Statistical analysis capabilities
% - Verbose debugging output

% Initialize outputs
erM = "";
vectorInterleaved = [];
permutation = [];
bufferRows = [];
bufferSlope = [];
permutationStats = struct();

try
    % Input validation and parameter parsing
    p = inputParser;
    addRequired(p, 'inData', @(x) isnumeric(x) && (isvector(x) || isempty(x)));
    addParameter(p, 'BufferRows', 8, @(x) isscalar(x) && isnumeric(x) && x > 0 && mod(x,1) == 0);
    addParameter(p, 'BufferSlope', 1, @(x) isscalar(x) && isnumeric(x) && x > 0 && mod(x,1) == 0);
    addParameter(p, 'maxExtensionPercentage', 1.35, @(x) isscalar(x) && isnumeric(x) && x >= 1.0);
    addParameter(p, 'padSymbol', NaN, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'AutoOptimize', true, @islogical);
    addParameter(p, 'PerformanceMode', 'realistic', ...
        @(x) ismember(x, {'realistic', 'optimal', 'constrained'}));
    addParameter(p, 'Verbose', false, @islogical);
    addParameter(p, 'PermutationTolerance', 1e-6, @(x) isscalar(x) && x >= 0);
    
    parse(p, inData, varargin{:});
    params = p.Results;
    
    % Convert to column vector
    inData = inData(:);
    N = length(inData);
    if N == 0
        erM = 'Input data cannot be empty';
        return;
    end

    % Parameter optimization
    if params.AutoOptimize
        [bufferRows, bufferSlope] = convolutional_optimizeParameters(...
            N, params.maxExtensionPercentage, params.PerformanceMode);
        if params.Verbose
            fprintf('\nAuto-optimized parameters: BufferRows=%d, BufferSlope=%d\n', ...
                bufferRows, bufferSlope);
        end
    else
        bufferRows = params.BufferRows;
        bufferSlope = params.BufferSlope;
    end

    % Parameter validation
    bufferRows = max(2, bufferRows);
    bufferSlope = max(1, bufferSlope);
    totalDelay = bufferRows * bufferSlope * (bufferRows - 1);

    if params.Verbose
        fprintf('\nConfiguration:\n');
        fprintf('  Input length: %d\n', N);
        fprintf('  Buffer rows: %d\n', bufferRows);
        fprintf('  Buffer slope: %d\n', bufferSlope);
        fprintf('  Total delay: %d\n', totalDelay);
        fprintf('  Pad symbol: %g\n', params.padSymbol);
    end

    % Expansion constraint handling
    expansionRatio = (N + totalDelay) / N;
    if expansionRatio > params.maxExtensionPercentage
        if params.Verbose
            fprintf('Adjusting parameters to meet expansion limit (%.2fx)...\n', ...
                params.maxExtensionPercentage);
        end
        
        % Find valid configurations
        validConfigs = [];
        for br = 2:bufferRows
            for bs = 1:bufferSlope
                td = br * bs * (br - 1);
                if (N + td)/N <= params.maxExtensionPercentage
                    validConfigs = [validConfigs; br bs td];
                end
            end
        end
        
        if isempty(validConfigs)
            erM = sprintf('No configuration found within %.1f%% expansion limit', ...
                (params.maxExtensionPercentage-1)*100);
            return;
        end
        
        % Select configuration with maximum delay
        [~, idx] = max(validConfigs(:,3));
        bufferRows = validConfigs(idx,1);
        bufferSlope = validConfigs(idx,2);
        totalDelay = validConfigs(idx,3);
        
        if params.Verbose
            fprintf('Selected configuration: %d rows, slope %d (delay %d)\n', ...
                bufferRows, bufferSlope, totalDelay);
        end
    end

    % Create interleaver system objects
    interleaverObj = comm.ConvolutionalInterleaver(...
        'NumRegisters', bufferRows, ...
        'RegisterLengthStep', bufferSlope, ...
        'InitialConditions', zeros(bufferRows,1));
    
    % Pad input data
    paddedInput = [inData; repmat(params.padSymbol, totalDelay, 1)];
    paddedLength = length(paddedInput);
    
    if params.Verbose
        fprintf('\nProcessing:\n');
        fprintf('  Original length: %d\n', N);
        fprintf('  Padded length: %d\n', paddedLength);
        fprintf('  Padding samples: %d\n', totalDelay);
    end

    % Perform interleaving
    interleavedOutput = interleaverObj(paddedInput);
    
    % Generate permutation pattern using direct indexing
    [~, permutation] = sort(interleaverObj((1:paddedLength)'));
    permutation = permutation';
    
    % Verify permutation
    if params.Verbose
        reconstructed = paddedInput(permutation);
        mismatch = sum(abs(reconstructed - interleavedOutput) > params.PermutationTolerance);
        
        if mismatch == 0
            fprintf('Permutation verification: SUCCESS\n');
        else
            fprintf('*** Permutation verification FAILED: %d mismatches\n', mismatch);
            
            % Find first mismatch
            errIdx = find(abs(reconstructed - interleavedOutput) > params.PermutationTolerance, 1);
            fprintf('First mismatch at position %d:\n', errIdx);
            fprintf('  Expected: %g\n', interleavedOutput(errIdx));
            fprintf('  Actual  : %g\n', reconstructed(errIdx));
        end
    end

    % Generate inverse permutation
    inversePermutation = zeros(1, paddedLength);
    inversePermutation(permutation) = 1:paddedLength;
    
    % Prepare outputs
    vectorInterleaved = interleavedOutput';
    if isrow(inData)
        vectorInterleaved = vectorInterleaved';
    end
    
    % Prepare statistics structure
    permutationStats = struct(...
        'forward', permutation, ...
        'inverse', inversePermutation, ...
        'totalDelay', totalDelay, ...
        'bufferRows', bufferRows, ...
        'bufferSlope', bufferSlope, ...
        'originalLength', N, ...
        'paddedLength', paddedLength, ...
        'expansionRatio', (N + totalDelay)/N, ...
        'maxDistance', max(abs(permutation - (1:paddedLength))));
    
    if params.Verbose
        fprintf('\nStatistics:\n');
        fprintf('  Inverse Permutation: %s\n', num2str(permutationStats.inverse));
        fprintf('  Expansion ratio: %.3f\n', permutationStats.expansionRatio);
        fprintf('  Max permutation distance: %d\n', permutationStats.maxDistance);
        fprintf('  First 10 permutation indices:\n');
        disp(permutation(1:min(10,end)));
    end

catch ME
    erM = sprintf('Error in interleaver_convolutional_a (line %d): %s', ...
        ME.stack(1).line, ME.message);
    if params.Verbose
        fprintf(2, 'ERROR: %s\n', erM);
    end
end
end

function [deinterleavedData, erM] = deinterleaver_convolutional_a(interleavedData, permutationStats, varargin)
% SIMPLIFIED CONVOLUTIONAL DEINTERLEAVER 
% Recovers original data using inverse permutation only
%
% Inputs:
%   interleavedData   - The interleaved sequence 
%   permutationStats  - Statistics structure from interleaver (must contain 'inverse' field)
%   
% Optional parameters:
%   'Verbose'         - Display debug information (default: false)
%   'StripPadding'    - Remove padding and return only original data (default: true)

% Initialize outputs
erM = "";
deinterleavedData = [];

try
    % Parse inputs
    p = inputParser;
    addRequired(p, 'interleavedData', @(x) isnumeric(x) && isvector(x));
    addRequired(p, 'permutationStats', @isstruct);
    addParameter(p, 'Verbose', false, @islogical);
    addParameter(p, 'StripPadding', true, @islogical);
    
    parse(p, interleavedData, permutationStats, varargin{:});
    params = p.Results;
    
    % Validate inputs
    if ~isfield(permutationStats, 'inverse') || isempty(permutationStats.inverse)
        erM = 'Inverse permutation not found in permutationStats';
        return;
    end
    
    % Convert to column vector and get dimensions
    interleavedData = interleavedData(:);
    receivedLength = length(interleavedData);
    expectedLength = length(permutationStats.inverse);
    
    if params.Verbose
        fprintf('Deinterleaver: received %d symbols, expected %d\n', ...
            receivedLength, expectedLength);
    end
    
    % Handle length mismatch
    if receivedLength < expectedLength
        % Pad with NaN if too short
        interleavedData = [interleavedData; repmat(NaN, expectedLength - receivedLength, 1)];
        if params.Verbose
            fprintf('Padded input to expected length\n');
        end
    elseif receivedLength > expectedLength
        % Truncate if too long
        interleavedData = interleavedData(1:expectedLength);
        if params.Verbose
            fprintf('Truncated input to expected length\n');
        end
    end
    
    % CORE DEINTERLEAVING: Apply inverse permutation
    deinterleavedData = interleavedData(permutationStats.inverse);
    
    % Extract original data (strip padding if requested)
    if params.StripPadding && isfield(permutationStats, 'originalLength')
        deinterleavedData = deinterleavedData(1:permutationStats.originalLength);
        if params.Verbose
            fprintf('Extracted %d original symbols (stripped %d padding symbols)\n', ...
                permutationStats.originalLength, ...
                length(deinterleavedData) - permutationStats.originalLength);
        end
    else
        deinterleavedData = deinterleavedData;
        if params.Verbose
            fprintf('Returned full deinterleaved data (%d symbols)\n', length(deinterleavedData));
        end
    end
    
catch ME
    erM = sprintf('Deinterleaver error: %s', ME.message);
    if params.Verbose
        fprintf(2, 'ERROR: %s\n', erM);
    end
end
end

function [deinterleavedData, originalData, erM] = deinterleaver_convolutional_a_try(interleavedData, permutationStats, varargin)
% CONVOLUTIONAL DEINTERLEAVER 
% Recovers original data from interleaved sequence using permutation statistics
%
% Inputs:
%   interleavedData   - The interleaved sequence (can be partial or complete)
%   permutationStats  - Statistics structure from interleaver_convolutional_enhanced
%   
% Optional parameters:
%   'Method'          - 'permutation' (uses inverse permutation) or 'object' (uses MATLAB object)
%   'Verbose'         - Display debug information
%   'StripPadding'    - Remove padding symbols from output (default: true)
%   'padSymbol'       - Symbol used for padding (default: NaN)

% Initialize outputs
erM = "";
deinterleavedData = [];
originalData = [];

try
    % Parse inputs
    p = inputParser;
    addRequired(p, 'interleavedData', @(x) isnumeric(x) && isvector(x));
    addRequired(p, 'permutationStats', @isstruct);
    addParameter(p, 'Method', 'permutation', @(x) ismember(x, {'permutation', 'object'}));
    addParameter(p, 'Verbose', false, @islogical);
    addParameter(p, 'StripPadding', true, @islogical);
    addParameter(p, 'padSymbol', NaN, @(x) isnumeric(x) && isscalar(x));
    
    parse(p, interleavedData, permutationStats, varargin{:});
    params = p.Results;
    
    % Convert to column vector
    interleavedData = interleavedData(:);
    receivedLength = length(interleavedData);
    
    % Extract parameters from stats
    if ~isfield(permutationStats, 'inverse') || isempty(permutationStats.inverse)
        erM = 'Inverse permutation not available in permutationStats';
        return;
    end
    
    originalLength = permutationStats.originalLength;
    paddedLength = permutationStats.paddedLength;
    totalDelay = permutationStats.totalDelay;
    bufferRows = permutationStats.bufferRows;
    bufferSlope = permutationStats.bufferSlope;
    
    if params.Verbose
        fprintf('\n=== DEINTERLEAVER CONFIGURATION ===\n');
        fprintf('Method: %s\n', params.Method);
        fprintf('Received length: %d\n', receivedLength);
        fprintf('Expected padded length: %d\n', paddedLength);
        fprintf('Original data length: %d\n', originalLength);
        fprintf('Total delay: %d\n', totalDelay);
        fprintf('Buffer: %d rows × %d slope\n', bufferRows, bufferSlope);
    end
    
    % Handle different input lengths
    if receivedLength < paddedLength
        if params.Verbose
            fprintf('WARNING: Received data shorter than expected, padding with padSymbol\n');
        end
        % Pad the received data to full length
        paddedReceived = [interleavedData; repmat(params.padSymbol, paddedLength - receivedLength, 1)];
    elseif receivedLength > paddedLength
        if params.Verbose
            fprintf('WARNING: Received data longer than expected, truncating\n');
        end
        paddedReceived = interleavedData(1:paddedLength);
    else
        paddedReceived = interleavedData;
    end
    
    % METHOD 1: Using inverse permutation (direct and fast)
    if strcmp(params.Method, 'permutation')
        if params.Verbose
            fprintf('\nUsing inverse permutation method...\n');
        end
        
        % Apply inverse permutation to recover original order
        deinterleavedData = paddedReceived(permutationStats.inverse);
        
        if params.Verbose
            fprintf('Deinterleaving completed using permutation\n');
        end
        
    % METHOD 2: Using MATLAB System Object (for verification)
    elseif strcmp(params.Method, 'object')
        if params.Verbose
            fprintf('\nUsing MATLAB deinterleaver object method...\n');
        end
        
        % Create deinterleaver object with same parameters
        deinterleaverObj = comm.ConvolutionalDeinterleaver(...
            'NumRegisters', bufferRows, ...
            'RegisterLengthStep', bufferSlope, ...
            'InitialConditions', zeros(bufferRows,1));
        
        % Apply deinterleaving
        deinterleavedData = deinterleaverObj(paddedReceived);
        
        if params.Verbose
            fprintf('Deinterleaving completed using system object\n');
        end
    end
    
    % Extract original data (remove padding)
    if params.StripPadding
        originalData = deinterleavedData(1:originalLength);
        if params.Verbose
            fprintf('Extracted original data (length %d)\n', originalLength);
        end
    else
        originalData = deinterleavedData;
        if params.Verbose
            fprintf('Keeping padded data (length %d)\n', length(deinterleavedData));
        end
    end
    
    % Verification if we have access to original data in stats
    if isfield(permutationStats, 'originalData')
        maxError = max(abs(originalData - permutationStats.originalData));
        if params.Verbose
            fprintf('Verification: max error = %.2e\n', maxError);
        end
        if maxError > 1e-10
            erM = sprintf('Deinterleaving verification failed (error: %.2e)', maxError);
        end
    end
    
    if params.Verbose
        fprintf('\n=== DEINTERLEAVING RESULTS ===\n');
        fprintf('Deinterleaved length: %d\n', length(deinterleavedData));
        fprintf('Original data length: %d\n', length(originalData));
        if length(originalData) <= 20
            fprintf('Original data: [%s]\n', num2str(originalData'));
        else
            fprintf('Original data (first 10): [%s ...]\n', num2str(originalData(1:10)'));
        end
    end

catch ME
    erM = sprintf('Error in deinterleaver_convolutional: %s', ME.message);
    if params.Verbose
        fprintf(2, 'ERROR: %s\n', erM);
    end
end
end

%%%%%%%%%%

function generatePermutationPlots(permutation, stats)
% Generate visualization plots for permutation analysis
   figure('Position', [100, 100, 1200, 800]);
   
   % Plot 1: Permutation mapping
   subplot(2, 3, 1);
   N = length(permutation);
   plot(1:N, permutation, 'b.-', 'MarkerSize', 4);
   hold on;
   plot(1:N, 1:N, 'r--'); % , 'Alpha', 0.5); % Identity line
   xlabel('Input Position');
   ylabel('Output Position');
   title('Permutation Mapping');
   grid on;
   legend('Actual', 'Identity', 'Location', 'best');
   
   % Plot 2: Displacement
   subplot(2, 3, 2);
   displacement = permutation - (1:N);
   bar(displacement);
   xlabel('Position');
   ylabel('Displacement');
   title(sprintf('Position Displacement (μ=%.2f, σ=%.2f)', stats.displacement.mean, stats.displacement.std));
   grid on;
   
   % Plot 3: Distance histogram
   subplot(2, 3, 3);
   distances = abs(displacement);
   histogram(distances, 'Normalization', 'probability');
   xlabel('Distance Moved');
   ylabel('Probability');
   title(sprintf('Distance Distribution (μ=%.2f)', stats.distance.mean));
   grid on;
   
   % Plot 4: Consecutive runs
   subplot(2, 3, 4);
   consecutiveRuns = [];
   currentRun = 1;
   for i = 2:N
       if permutation(i) == permutation(i-1) + 1
           currentRun = currentRun + 1;
       else
           consecutiveRuns = [consecutiveRuns, currentRun];
           currentRun = 1;
       end
   end
   consecutiveRuns = [consecutiveRuns, currentRun];
   histogram(consecutiveRuns, 'Normalization', 'probability');
   xlabel('Run Length');
   ylabel('Probability');
   title(sprintf('Consecutive Run Lengths (μ=%.2f)', stats.clustering.meanRunLength));
   grid on;
   
   % Plot 5: Separation analysis
   subplot(2, 3, 5);
   separations = diff(permutation);
   plot(abs(separations), 'g.-');
   xlabel('Position');
   ylabel('|Separation|');
   title(sprintf('Position Separations (μ=%.2f)', stats.interleaving.meanSeparation));
   grid on;
   
   % Plot 6: Pattern summary
   subplot(2, 3, 6);
   axis off;
   text(0.1, 0.9, 'PATTERN SUMMARY', 'FontSize', 14, 'FontWeight', 'bold');
   text(0.1, 0.8, sprintf('Correlation: %.3f', stats.locality.correlation));
   text(0.1, 0.7, sprintf('Mean Distance: %.2f', stats.distance.mean));
   text(0.1, 0.6, sprintf('Fragmentation: %.3f', stats.clustering.fragmentation));
   text(0.1, 0.5, sprintf('Entropy-Normalized: %.3f', stats.distribution.entropyNormalized));
   if stats.randomness.isStructured
       structureText = 'YES';
   else
       structureText = 'NO';
   end
   text(0.1, 0.4, sprintf('Structure: %s', structureText));
   text(0.1, 0.3, sprintf('Block Fit: %.2f', stats.blockPattern.bestFit));
   
   sgtitle('Permutation Pattern Analysis');
end
