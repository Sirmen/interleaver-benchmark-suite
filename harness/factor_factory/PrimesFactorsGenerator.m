% Resolved rather than typed in: find_table_dir looks for
% table_factors_precomputed.mat from here outward and on the MATLAB path.
% Two outputs are requested on purpose: with one, find_table_dir raises
% instead of returning, and the fallback below would never be reached.
% The fallback keeps the historical layout without naming any machine.
[outputDir, ~] = find_table_dir();
if isempty(outputDir)
   outputDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data_PrimeFactor');
end
Nmax = 100000;

PrimeFactorGenerator_(Nmax, outputDir);

%%%

function PrimeFactorGenerator_(Nmax, outputDir)
    % Simple prime and factor pair generator
    if nargin < 2
        outputDir = 'prime_factor_data';
    end
    if nargin < 1
        Nmax = 100000;
    end
    
    fprintf('Generating primes and factor pairs up to %d...\n', Nmax);
    
    % Create output directory
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    
    % Generate primes using Sieve of Eratosthenes
    fprintf('Generating primes...\n');
    tic;
    primes = sieveOfEratosthenes(Nmax);
    elapsed_primes = toc;
    fprintf('Generated %d primes in %.3f seconds\n', length(primes), elapsed_primes);
    
    % Generate factor pairs for all numbers
    fprintf('Generating factor pairs...\n');
    tic;
    factor_data = struct();
    
    for n = 2:Nmax
        pairs = computeFactorPairs(n);
        
        % Find minSum pair (smallest L + K)
        sums = sum(pairs, 2);
        [~, minSumIdx] = min(sums);
        minSumPair = pairs(minSumIdx, :);
        
        % Find minFactor pair (pair with smallest minimum factor)
        min_factors = min(pairs, [], 2);
        [~, minFactorIdx] = min(min_factors);
        minFactorPair = pairs(minFactorIdx, :);
        
        factor_data.(sprintf('n%d', n)) = struct(...
            'all_pairs', pairs, ...
            'min_sum_pair', minSumPair, ...
            'min_factor_pair', minFactorPair);
        
        % Progress indicator
        if mod(n, 10000) == 0
            fprintf('Progress: %d/%d (%.1f%%)\n', n, Nmax, 100*n/Nmax);
        end
    end
    elapsed_factors = toc;
    fprintf('Generated factor pairs for %d numbers in %.3f seconds\n', Nmax-1, elapsed_factors);
    
    % Save data in binary format for fastest loading
    fprintf('Saving data...\n');
    
    % Save primes as binary
    primes_file = fullfile(outputDir, 'primes.bin');
    fid = fopen(primes_file, 'wb');
    fwrite(fid, length(primes), 'uint32');
    fwrite(fid, primes, 'uint32');
    fclose(fid);
    
    % Save factor data as MAT file (struct can't be easily saved as binary)
    factor_file = fullfile(outputDir, 'factors.mat');
    save(factor_file, 'factor_data', '-v7.3');
    
    % Save metadata
    metadata.generation_date = datetime('now');
    metadata.Nmax = Nmax;
    metadata.primes_count = length(primes);
    save(fullfile(outputDir, 'metadata.mat'), 'metadata');
    
    fprintf('Data saved to: %s\n', outputDir);
    fprintf('Total time: %.3f seconds\n', elapsed_primes + elapsed_factors);
end

function primes = sieveOfEratosthenes(n)
    if n < 2
        primes = [];
        return;
    end
    
    sieve = true(n, 1);
    sieve(1) = false;
    
    sqrt_n = floor(sqrt(n));
    for i = 2:sqrt_n
        if sieve(i)
            sieve(i*i:i:n) = false;
        end
    end
    
    primes = find(sieve);
end

function pairs = computeFactorPairs(n)
    pairs = [];
    for i = 1:n
        if mod(n, i) == 0
            j = n / i;
            pairs = [pairs; max(i,j), min(i,j)];
        end
    end
    pairs = unique(pairs, 'rows');
end
