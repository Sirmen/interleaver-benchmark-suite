% Complete test application for prime and factor functionality

clear all; close all;

% Resolved rather than typed in: find_table_dir looks for
% table_factors_precomputed.mat from here outward and on the MATLAB path.
% Two outputs are requested on purpose: with one, find_table_dir raises
% instead of returning, and the fallback below would never be reached.
% The fallback keeps the historical layout without naming any machine.
[dataDir, ~] = find_table_dir();
if isempty(dataDir)
   dataDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data_PrimeFactor');
end
Nmax = 100000; % 100K
minFactorConstraints = 2:17; % Test different constraints

% % Step 1: Generate data (if needed)
% test_genData(Nmax, minFactorConstraints, dataDir);

% Step 2: Load primes and factors data
[table_primes, table_factors] = load_PrimeFactorData(dataDir);

% Step 3: Test prime checking
testNumbers = [17, 100, 6880, 10000, 12345, 2, 1, 97, 232323];
testPrimeFactor(table_primes, table_factors, testNumbers, minFactorConstraints);
    
fprintf('\n=== Test Complete ===\n');

%%%%%

function test_genData(Nmax, minFactorConstraints, dataDir)
    if ~exist(dataDir, 'dir') || isempty(dir(fullfile(dataDir, '*.bin'))) || isempty(dir(fullfile(dataDir, '*.mat')))
        fprintf('Generating data...\n');
        PrimeFactorGenerator(Nmax, dataDir); % Generate 
        fprintf('\n');
    end
end

function [table_primes, table_factors] = load_PrimeFactorData(dataDir)
   [table_primes, table_factors] = PrimeFactorLoader(dataDir);
   fprintf('\n');
end

function testPrimeFactor(table_primes, table_factors, testNumbers, minFactorConstraints)
   fprintf('=== Prime Number Testing ===\n');
   for i = 1:length(testNumbers)
      N = testNumbers(i);
      fprintf('\n ** Testing number %d', N);
      isPrime = isInPrimesTable(N, table_primes);
      if isPrime
         fprintf(': PRIME');
      else
         fprintf(': COMPOSITE  > Factor Pairs:\n');
           
         fprintf('%-12s %-15s %-15s\n', ' MinFactor', 'minSumPair', 'minFactorPair');
         fprintf('%s\n', repmat('-', 45, 1));
           
         for j = 1:length(minFactorConstraints)
            minFactor = minFactorConstraints(j);
            [minSumPair, minFactorPair, erM] = getFactorPairs(N, table_factors, minFactor);
            % disp results
            if erM ~= ""
               fprintf('%-12d ERROR: %s\n', minFactor, erM);
            else
               % compute manually
               [uniquePairs, minSumPair_manual, minFactorPair_manual] = findUniqueMultiplierPairs(N, minFactor);

               fprintf('\t %-8d [%3d, %-4d]     [%3d, %-4d] ', ...
                    minFactor, minSumPair(1), minSumPair(2), minFactorPair(1), minFactorPair(2));

               % compare manual and table-retrieved pairs
               if minSumPair == minSumPair_manual
                  fprintf('\t minSumPair ok'); 
               else
                  fprintf('\t minSumPair !'); 
               end
               if minFactorPair == minFactorPair_manual
                  fprintf('\t minFactorPair ok \n'); 
               else
                  fprintf('\t minFactorPair ! \n'); 
               end
            end
         end
      end
   end
end
