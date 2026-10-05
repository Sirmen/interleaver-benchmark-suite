% =========================================================================
% CORRECTED INTERLEAVER METRICS IMPLEMENTATION
% Fixes for suspicious metrics + Priority-based organization
% =========================================================================

%% PRIORITY TIER 1: CRITICAL METRICS (Always Include)
% These 8 metrics provide the most important information about interleaver quality

function metrics = computeCoreTier1Metrics(perm, noiseLocations, blockSize, t_correct)
    % Core metrics that should be computed for every interleaver evaluation
    % 
    % Inputs:
    %   perm - permutation vector (1xN)
    %   noiseLocations - logical array of error positions (1xN) [optional]
    %   blockSize - ECC block size [optional]
    %   t_correct - error correction capability [optional]
    %
    % Outputs:
    %   metrics - struct with 8 core metrics
    
    N = length(perm);
    perm = perm(:)';
    pos = zeros(1,N); 
    pos(perm) = 1:N;
    
    metrics = struct();
    
    % 1. SEPARATION METRICS (structure quality)
    seps_raw = abs(pos(2:end) - pos(1:end-1));
    seps = seps_raw / max(1, N-1);
    metrics.sepMin = min(seps);
    metrics.sepAvg = mean(seps);
    
    % 2. TRANSITION ENTROPY (randomness)
    metrics.Htrans = calcTransitionEntropy(perm);
    
    % 3-5. NOISE DISTANCE METRICS (error separation performance)
    if nargin >= 2 && ~isempty(noiseLocations)
        [metrics.noiseDistMin, metrics.noiseDistAvg, metrics.noiseDistVar] = ...
            computeNoiseDistances(perm, noiseLocations);
    else
        metrics.noiseDistMin = NaN;
        metrics.noiseDistAvg = NaN;
        metrics.noiseDistVar = NaN;
    end
    
    % 6. BURST SPREAD EFFICIENCY (normalized performance)
    if nargin >= 2 && ~isempty(noiseLocations) && nargin >= 3
        metrics.burstSpreadEfficiency = ...
            computeBurstSpreadEfficiency(perm, noiseLocations, blockSize);
    else
        metrics.burstSpreadEfficiency = NaN;
    end
    
    % 7. BLOCK MINIMUM DISTANCE (ECC critical)
    if nargin >= 3 && ~isempty(blockSize)
        metrics.blockMinMin = computeBlockMinDistance(perm, blockSize);
    else
        metrics.blockMinMin = NaN;
    end
    
    % 8. ECC VIOLATIONS (bottom-line performance)
    if nargin >= 2 && ~isempty(noiseLocations) && nargin >= 3 && nargin >= 4
        metrics.eccViolations = calcECCViolations(perm, noiseLocations, blockSize, t_correct);
    else
        metrics.eccViolations = NaN;
    end
end

%% PRIORITY TIER 2: IMPORTANT METRICS (Should Include)
% Additional 7 metrics for comprehensive evaluation

function metrics = computeExtendedTier2Metrics(perm, noiseLocations, blockSize, t_correct)
    % Extended metrics for detailed interleaver characterization
    
    N = length(perm);
    perm = perm(:)';
    pos = zeros(1,N); 
    pos(perm) = 1:N;
    
    metrics = struct();
    
    % 1. SPREAD FACTOR (2D minimum distance)
    if N <= 3000
        metrics.spreadFactor = calcSpreadFactorExact(pos) / (N-1);
    else
        metrics.spreadFactor = calcSpreadFactorSampled(pos, 5000) / (N-1);
    end
    
    % 2. PERIODICITY (lower is better - detects systematic patterns)
    metrics.periodicity = computePeriodicityScore_CORRECTED(perm);
    
    % 3. ADJACENCY MINIMUM (output locality)
    adj_raw = abs(perm(2:end) - perm(1:end-1));
    adj = adj_raw / max(1, N-1);
    metrics.adjMin = min(adj);
    
    % 4. BLOCK ENTROPY (load balancing)
    if nargin >= 3 && ~isempty(blockSize)
        metrics.Hblock = computeBlockEntropy(perm, blockSize);
    else
        metrics.Hblock = NaN;
    end
    
    % 5. NOISE ENTROPY (error distribution quality)
    if nargin >= 2 && ~isempty(noiseLocations) && nargin >= 3
        metrics.Hnoise = computeNoiseEntropy_CW(perm, noiseLocations, blockSize);
    else
        metrics.Hnoise = NaN;
    end
    
    % 6. ECC MARGIN (safety buffer)
    if nargin >= 2 && ~isempty(noiseLocations) && nargin >= 3 && nargin >= 4
        metrics.eccMarginMin = calcECCMargin(perm, noiseLocations, blockSize, t_correct);
    else
        metrics.eccMarginMin = NaN;
    end
    
    % 7. BLOCK OCCUPANCY RATIO (spread across blocks)
    if nargin >= 2 && ~isempty(noiseLocations) && nargin >= 3
        metrics.blockOccupancyRatio = ...
            calcBlockOccupancyRatio(perm, noiseLocations, blockSize);
    else
        metrics.blockOccupancyRatio = NaN;
    end
end

%% PRIORITY TIER 3: OPTIONAL METRICS (Context-Dependent)
% Statistical details and advanced characterization

function metrics = computeOptionalTier3Metrics(perm, noiseLocations, blockSize)
    % Optional metrics for specialized analysis
    
    N = length(perm);
    perm = perm(:)';
    pos = zeros(1,N); 
    pos(perm) = 1:N;
    
    metrics = struct();
    
    % Separation statistics
    seps_raw = abs(pos(2:end) - pos(1:end-1));
    seps = seps_raw / max(1, N-1);
    metrics.sepVar = var(seps);
    metrics.sepCV = std(seps) / (mean(seps) + eps);
    metrics.sepSkewness = skewness(seps);
    metrics.sepKurtosis = kurtosis(seps);
    
    % Adjacency statistics
    adj_raw = abs(perm(2:end) - perm(1:end-1));
    adj = adj_raw / max(1, N-1);
    metrics.adjAvg = mean(adj);
    metrics.adjVar = var(adj);
    metrics.CV_adj = std(adj) / (mean(adj) + eps);
    
    % Triangle metric (Sun & Takeshita)
    if N >= 3
        d1 = diff(perm);
        d2 = diff(d1);
        metrics.triangleT = sum(abs(d2)) / max(1, N-2);
    else
        metrics.triangleT = 0;
    end
    
    % Block average distance
    if nargin >= 3 && ~isempty(blockSize)
        metrics.blockAvg = calcBlockAvgDistance(perm, blockSize);
    else
        metrics.blockAvg = NaN;
    end
    
    % Coverage ratio (CORRECTED version)
    if nargin >= 3 && ~isempty(blockSize)
        metrics.coverageRatio = computeCoverageRatio_CORRECTED(perm, blockSize);
    else
        metrics.coverageRatio = NaN;
    end
end

%% ========================================================================
%% CORRECTED IMPLEMENTATIONS OF SUSPICIOUS METRICS
%% ========================================================================


%% ========================================================================
%% HELPER FUNCTIONS (Corrected and Optimized)
%% ========================================================================

function [minDist, avgDist, varDist] = calcNoiseDistances(perm, noiseLocations)
    % Compute pairwise distances between error positions after interleaving
    
    N = length(perm);
    errorIndices = find(noiseLocations);
    numErrors = length(errorIndices);
    
    if numErrors < 2
        minDist = Inf;
        avgDist = 0;
        varDist = 0;
        return;
    end
    
    % Map errors to interleaved positions
    interleavedErrors = perm(errorIndices);
    
    % Compute all pairwise distances (efficient for reasonable error counts)
    distances = pdist(interleavedErrors', 'euclidean');
    
    % Normalize by interleaver length
    distances = distances / (N - 1);
    
    minDist = min(distances);
    avgDist = mean(distances);
    varDist = var(distances);
end


function Hnoise = computeNoiseEntropy_CW(perm, noiseLocations, blockSize)
    % Entropy of error distribution across blocks after interleaving
    
    N = length(perm);
    numBlocks = ceil(N / blockSize);
    
    errorIndices = find(noiseLocations);
    
    if isempty(errorIndices)
        Hnoise = 0;
        return;
    end
    
    % Map errors through interleaver
    interleavedErrors = perm(errorIndices);
    
    % Assign to blocks
    errorBlocks = ceil(interleavedErrors / blockSize);
    
    % Count distribution
    counts = histcounts(errorBlocks, 1:(numBlocks+1));
    
    % Probabilities
    p = counts / sum(counts);
    p = p(p > 0);
    
    % Entropy
    Hnoise = -sum(p .* log2(p));
end

%% ========================================================================
%% RECOMMENDED USAGE PATTERNS
%% ========================================================================

function example_usage_minimal()
    % MINIMAL EVALUATION: 8 core metrics (fast, essential information)
    
    N = 1000;
    perm = randperm(N);
    
    % Simulate burst errors
    burstStart = 100;
    burstLength = 20;
    noiseLocations = false(1, N);
    noiseLocations(burstStart:burstStart+burstLength-1) = true;
    
    % ECC parameters
    blockSize = 255;
    t_correct = 16;
    
    % Compute only Tier 1 metrics
    metrics = computeCoreTier1Metrics(perm, noiseLocations, blockSize, t_correct);
    
    disp('=== TIER 1: CORE METRICS ===');
    disp(metrics);
end

function example_usage_comprehensive()
    % COMPREHENSIVE EVALUATION: All three tiers
    
    N = 1000;
    perm = randperm(N);
    
    % Simulate burst errors
    burstStart = 100;
    burstLength = 20;
    noiseLocations = false(1, N);
    noiseLocations(burstStart:burstStart+burstLength-1) = true;
    
    % ECC parameters
    blockSize = 255;
    t_correct = 16;
    
    % Compute all tiers
    tier1 = computeCoreTier1Metrics(perm, noiseLocations, blockSize, t_correct);
    tier2 = computeExtendedTier2Metrics(perm, noiseLocations, blockSize, t_correct);
    tier3 = computeOptionalTier3Metrics(perm, noiseLocations, blockSize);
    
    % Combine
    allMetrics = struct();
    fields1 = fieldnames(tier1);
    for i = 1:length(fields1)
        allMetrics.(fields1{i}) = tier1.(fields1{i});
    end
    fields2 = fieldnames(tier2);
    for i = 1:length(fields2)
        allMetrics.(fields2{i}) = tier2.(fields2{i});
    end
    fields3 = fieldnames(tier3);
    for i = 1:length(fields3)
        allMetrics.(fields3{i}) = tier3.(fields3{i});
    end
    
    disp('=== ALL METRICS ===');
    disp(allMetrics);
end

function example_usage_structure_only()
    % STRUCTURE-ONLY EVALUATION: No error simulation needed (very fast)
    % Useful for initial screening of many interleavers
    
    N = 1000;
    perm = randperm(N);
    
    % Only structure metrics (no noiseLocations needed)
    metrics = struct();
    
    pos = zeros(1,N); 
    pos(perm) = 1:N;
    
    % Separation
    seps = abs(pos(2:end) - pos(1:end-1)) / (N-1);
    metrics.sepMin = min(seps);
    metrics.sepAvg = mean(seps);
    
    % Spread factor
    if N <= 3000
        metrics.spreadFactor = calcSpreadFactorExact(pos) / (N-1);
    else
        metrics.spreadFactor = calcSpreadFactorSampled(pos, 5000) / (N-1);
    end
    
    % Transition entropy
    metrics.Htrans = calcTransitionEntropy(perm);
    
    % Periodicity
    metrics.periodicity = computePeriodicityScore_CORRECTED(perm);
    
    disp('=== STRUCTURE-ONLY METRICS (Fast Screening) ===');
    disp(metrics);
    
    % Quick assessment
    fprintf('\n--- Quick Assessment ---\n');
    if metrics.sepMin > 0.3 && metrics.sepAvg > 0.45
        fprintf('✓ Good separation properties\n');
    else
        fprintf('✗ Poor separation (sepMin=%.3f, sepAvg=%.3f)\n', metrics.sepMin, metrics.sepAvg);
    end
    
    if metrics.Htrans > 8
        fprintf('✓ Good randomness (Htrans=%.2f)\n', metrics.Htrans);
    else
        fprintf('✗ Low randomness (Htrans=%.2f)\n', metrics.Htrans);
    end
    
    if metrics.periodicity < 0.2
        fprintf('✓ Low periodicity (%.3f)\n', metrics.periodicity);
    else
        fprintf('⚠ Moderate/high periodicity (%.3f)\n', metrics.periodicity);
    end
end