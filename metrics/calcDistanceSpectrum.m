function [spectrum, erM] = calcDistanceSpectrum(permutation, numSamples)
% Calculate distance spectrum for interleaver quality
% Literature: Berrou et al. (1993), Benedetto & Montorsi (1996)
%
% Returns histogram of 2D distances between symbol pairs
erM = ""; spectrum=struct();
try    
    if nargin < 2
        numSamples = round(min(5000, length(permutation)^2 / 4));
    end
    
    N = length(permutation);
    pos = zeros(1, N);
    pos(permutation) = 1:N;
    
    % Sample random pairs
    i_samples = randi(N, numSamples, 1);
    j_samples = randi(N, numSamples, 1);
    valid = i_samples ~= j_samples;
    
    i_samples = i_samples(valid);
    j_samples = j_samples(valid);
    
    % Calculate 2D distances
    distances = sqrt((i_samples - j_samples).^2 + ...
                     (pos(i_samples)' - pos(j_samples)').^2);
    
    % Compute statistics
    spectrum.mean = mean(distances);
    spectrum.std = std(distances);
    spectrum.min = min(distances);
    spectrum.q25 = quantile(distances, 0.25);
    spectrum.median = median(distances);
    spectrum.q75 = quantile(distances, 0.75);
    spectrum.max = max(distances);
    spectrum.cv = spectrum.std / (spectrum.mean + eps); % Coefficient of variation
    
    % Spectral energy (concentration metric)
    [counts, edges] = histcounts(distances, 50, 'Normalization', 'probability');
    spectrum.entropy = -sum(counts(counts>0) .* log2(counts(counts>0)));
    spectrum.spectralUniformity = spectrum.entropy / log2(length(counts));
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
