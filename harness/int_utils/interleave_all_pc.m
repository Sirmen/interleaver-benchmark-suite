function [interleaved_all, permutation_all, paramsInt, erM] = interleave_all_pc(intMethods, paramsInt, tables)
% Applies interleaving to all requested interleaving methods using precomputed (_pc) versions
% 
% USAGE:
%   [interleaved_all, permutation_all, paramsInt, erM] = interleave_all_pc(intMethods, paramsInt, tables)
%
% INPUTS:
%   intMethods - cell array of method names (e.g., {'random', 'matrix', 'S'})
%   paramsInt  - struct with all parameters including:
%                - encoded: input data vector
%                - padSymbol, maxExtensionPercentage, etc.
%   tables
%                - table_precomputed: precomputed interleaver table
%                - table_primes, table_factors: for special interleavers

erM = ""; % assume ok

%% Extract interleaving parameters
encoded = paramsInt.encoded; 
maxSize = paramsInt.maxSize; 
padSymbol = paramsInt.padSymbol; 
maxExtensionPercentage = paramsInt.maxExtensionPercentage;
table_precomputed = tables.table_precomputed;

% Optional parameters for special interleavers
if isfield(tables, 'table_primes')
    table_primes = tables.table_primes;
else
    table_primes = [];
end

if isfield(tables, 'table_factors')
    table_factors = tables.table_factors;
else
    table_factors = [];
end

%% Interleave with _pc versions

% RANDOM
if sum(ismember(intMethods, 'random')) > 0
    method = 'random';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'random', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation;
                paramsInt.Lrandom = L;
                paramsInt.Krandom = K;
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% MATRIX
if sum(ismember(intMethods, 'matrix')) > 0 && (erM == "")  
    method = 'matrix';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'matrix', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.Lmatrix = L;  
                paramsInt.Kmatrix = K;  
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% CONVOLUTIONAL
if sum(ismember(intMethods, 'convolutional')) > 0 && (erM == "")  
    method = 'convolutional';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'convolutional', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.bufferRows_conv = R;  
                paramsInt.bufferSlope_conv = 1; % Default from precompute
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% HELICALSCAN
if sum(ismember(intMethods, 'helicalScan')) > 0 && (erM == "")  
    method = 'helicalScan';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'helicalScan', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.LhelicalScan = L;  
                paramsInt.KhelicalScan = K;  
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% HELICAL
if sum(ismember(intMethods, 'helical')) > 0 && (erM == "")  
    method = 'helical';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'helical', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.Lhelical = L;  
                paramsInt.Khelical = K;  
                paramsInt.permutations.(method) = permutation; 
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% TURBO
if sum(ismember(intMethods, 'turbo')) > 0 && (erM == "")  
    method = 'turbo';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'turbo', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.turbo_strategy_info = struct(); % Strategy stored in precompute
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% ALGEBRAIC (needs special wrapper)
if sum(ismember(intMethods, 'algebraic')) > 0 && (erM == "") 
    method = 'algebraic';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'algebraic', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.Lalg = L;  
                paramsInt.Kalg = K;  
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% BLOCK
if sum(ismember(intMethods, 'block')) > 0 && (erM == "")  
    method = 'block';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'block', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% BLOCKCM, CONVCM  (v2: the code-matched classics; one loop, same bookkeeping
%                  as every other block, same "&& (erM == "")" chain)
for newM = {'blockCM', 'convCM'}
   method = newM{1};
   if sum(ismember(intMethods, method)) > 0 && (erM == "")
      tic;
      try
         if ~isfield(paramsInt, 'interleaveTime_sum') || ~isfield(paramsInt.interleaveTime_sum, method)
            paramsInt.interleaveTime_sum.(method) = 0;
         end
         if ~isfield(paramsInt, 'testCount') || ~isfield(paramsInt.testCount, method)
            paramsInt.testCount.(method) = 0;
         end
         [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, method, padSymbol, maxExtensionPercentage, ...
                                   table_precomputed, paramsInt.permutationSeed, ...
                                   table_primes, table_factors, paramsInt);
         if erM == ""
            if length(interleaved) <= maxSize
               interleaved_all.(method) = interleaved;
               permutation_all.(method) = permutation;
               paramsInt.permutations.(method) = permutation;
               paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
               paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
               erM = strcat(method, "-interleaved size exceeds limit");
            end
         end
      catch ME
         erM = sprintf('%s error: %s', method, ME.message);
      end
   end
end

% SNAKE  (was 'cross' - renamed: the file implements a boustrophedon block
%         interleaver, not the Ramsey/Forney convolutional cross interleaver
%         that the name denotes in coding theory)
if sum(ismember(intMethods, 'snake')) > 0 && (erM == "")
    method = 'snake';
    tic;
    try
        % counters may be missing if paramsInt was built from an older method list
        if ~isfield(paramsInt, 'interleaveTime_sum') || ~isfield(paramsInt.interleaveTime_sum, method)
            paramsInt.interleaveTime_sum.(method) = 0;
        end
        if ~isfield(paramsInt, 'testCount') || ~isfield(paramsInt.testCount, method)
            paramsInt.testCount.(method) = 0;
        end
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'snake', padSymbol, maxExtensionPercentage, ...
                                   table_precomputed, paramsInt.permutationSeed, ...
                                   table_primes, table_factors, paramsInt);

        if erM == ""
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved;
                permutation_all.(method) = permutation;
                paramsInt.permutations.(method) = permutation;
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% SPIRAL
if sum(ismember(intMethods, 'spiral')) > 0 && (erM == "")  
    method = 'spiral';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'spiral', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.Lspiral = L;  
                paramsInt.Kspiral = K;  
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% DIAGONAL
if sum(ismember(intMethods, 'diagonal')) > 0 && (erM == "")  
    method = 'diagonal';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'diagonal', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.Ldiagonal = L;  
                paramsInt.Kdiagonal = K;  
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% HIERARCHICAL
if sum(ismember(intMethods, 'hierarchical')) > 0 && (erM == "")  
    method = 'hierarchical';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'hierarchical', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.Lhierarchical = L;  
                paramsInt.Khierarchical = K;  
                paramsInt.Qhierarchical = Q;  
                paramsInt.Rhierarchical = R;  
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = "hierarchical interleaved size exceeds limit";
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% MULTIDIM
if sum(ismember(intMethods, 'multiDim')) > 0 && (erM == "")  
    method = 'multiDim';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'multiDim', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation;  
                paramsInt.permutations.(method) = permutation; 
                paramsInt.LmultiDim = L;  
                paramsInt.KmultiDim = K;  
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% LATINSQUARE
if sum(ismember(intMethods, 'latinSquare')) > 0 && (erM == "")  
    method = 'latinSquare';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'latinSquare', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation;  
                paramsInt.permutations.(method) = permutation; 
                paramsInt.Llatin = L;
                paramsInt.Klatin = K;
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = "latinSquare interleaved size exceeds limit";
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% TIME
if sum(ismember(intMethods, 'time')) > 0 && (erM == "")  
    method = 'time';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'time', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved;  
                permutation_all.(method) = permutation;  
                paramsInt.permutations.(method) = permutation; 
                paramsInt.Ltime = L;
                paramsInt.Ktime = K;
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% FREQRANDOM
if sum(ismember(intMethods, 'freqRandom')) > 0 && (erM == "")  
    method = 'freqRandom';
    tic;
    try
        if isfield(paramsInt, 'randomSeed')
            randomSeed = paramsInt.randomSeed;
        else
            randomSeed = 2106;
        end
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'freqRandom', padSymbol, maxExtensionPercentage, table_precomputed, randomSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% FREQDETERM
if sum(ismember(intMethods, 'freqDeterm')) > 0 && (erM == "")  
    method = 'freqDeterm';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'freqDeterm', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation;  
                paramsInt.permutations.(method) = permutation; 
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% CHAOTIC
if sum(ismember(intMethods, 'chaotic')) > 0 && (erM == "")  
    method = 'chaotic';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'chaotic', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved;  
                permutation_all.(method) = permutation;  
                paramsInt.permutations.(method) = permutation; 
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% PRIME (needs special wrapper)
if sum(ismember(intMethods, 'prime')) > 0 && (erM == "")  
    method = 'prime';
    tic;
    try
        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'prime', padSymbol, maxExtensionPercentage, table_precomputed, paramsInt.permutationSeed, table_primes, table_factors, paramsInt);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = "prime interleaved size exceeds limit";
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% S (needs special wrapper)
%%% ===== High-spread reference interleavers (journal version) ==============
%  No precomputed table is used: these four are O(N) closed forms (S-Random is
%  O(N^2) but caches internally), so there is nothing to look up. They operate
%  at the exact input length (BE = 1.0) and return a GATHER permutation, which
%  is all deinterleave_all_pc needs - it inverts every method generically
%  through deinterleaver_universal.

if sum(ismember(intMethods, 'srandom')) > 0 && (erM == "")
    method = 'srandom';
    tic;
    try
        % counters may be missing if this method was added after paramsInt was built
        if ~isfield(paramsInt, 'interleaveTime_sum') || ~isfield(paramsInt.interleaveTime_sum, method)
            paramsInt.interleaveTime_sum.(method) = 0;
        end
        if ~isfield(paramsInt, 'testCount') || ~isfield(paramsInt.testCount, method)
            paramsInt.testCount.(method) = 0;
        end

        spreadS = []; srSeed = 2106;
        if isfield(paramsInt, 'srandom_spreadS'), spreadS = paramsInt.srandom_spreadS; end
        if isfield(paramsInt, 'srandom_seed'),    srSeed  = paramsInt.srandom_seed;    end
        [interleaved, permutation, L, K, Q, R, erM, infoNew] = ...
            interleaver_generic_pc(encoded, 'srandom', padSymbol, maxExtensionPercentage, ...
                                   table_precomputed, paramsInt.permutationSeed, ...
                                   table_primes, table_factors, paramsInt);

        if erM == ""
            if length(interleaved) <= maxSize
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                interleaved_all.(method) = interleaved;
                permutation_all.(method) = permutation;
                paramsInt.permutations.(method) = permutation;
                paramsInt.info_srandom = infoNew;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

if sum(ismember(intMethods, 'goldenRP')) > 0 && (erM == "")
    method = 'goldenRP';
    tic;
    try
        % counters may be missing if this method was added after paramsInt was built
        if ~isfield(paramsInt, 'interleaveTime_sum') || ~isfield(paramsInt.interleaveTime_sum, method)
            paramsInt.interleaveTime_sum.(method) = 0;
        end
        if ~isfield(paramsInt, 'testCount') || ~isfield(paramsInt.testCount, method)
            paramsInt.testCount.(method) = 0;
        end

        gOffset = 0;
        if isfield(paramsInt, 'goldenRP_offset'), gOffset = paramsInt.goldenRP_offset; end
        [interleaved, permutation, L, K, Q, R, erM, infoNew] = ...
            interleaver_generic_pc(encoded, 'goldenRP', padSymbol, maxExtensionPercentage, ...
                                   table_precomputed, paramsInt.permutationSeed, ...
                                   table_primes, table_factors, paramsInt);

        if erM == ""
            if length(interleaved) <= maxSize
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                interleaved_all.(method) = interleaved;
                permutation_all.(method) = permutation;
                paramsInt.permutations.(method) = permutation;
                paramsInt.info_goldenRP = infoNew;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

if sum(ismember(intMethods, 'drp')) > 0 && (erM == "")
    method = 'drp';
    tic;
    try
        % counters may be missing if this method was added after paramsInt was built
        if ~isfield(paramsInt, 'interleaveTime_sum') || ~isfield(paramsInt.interleaveTime_sum, method)
            paramsInt.interleaveTime_sum.(method) = 0;
        end
        if ~isfield(paramsInt, 'testCount') || ~isfield(paramsInt.testCount, method)
            paramsInt.testCount.(method) = 0;
        end

        dW = 8; dSeed = 2106;
        if isfield(paramsInt, 'drp_ditherW'), dW    = paramsInt.drp_ditherW; end
        if isfield(paramsInt, 'drp_seed'),    dSeed = paramsInt.drp_seed;    end
        [interleaved, permutation, L, K, Q, R, erM, infoNew] = ...
            interleaver_generic_pc(encoded, 'drp', padSymbol, maxExtensionPercentage, ...
                                   table_precomputed, paramsInt.permutationSeed, ...
                                   table_primes, table_factors, paramsInt);

        if erM == ""
            if length(interleaved) <= maxSize
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                interleaved_all.(method) = interleaved;
                permutation_all.(method) = permutation;
                paramsInt.permutations.(method) = permutation;
                paramsInt.info_drp = infoNew;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

if sum(ismember(intMethods, 'arp')) > 0 && (erM == "")
    method = 'arp';
    tic;
    try
        % counters may be missing if this method was added after paramsInt was built
        if ~isfield(paramsInt, 'interleaveTime_sum') || ~isfield(paramsInt.interleaveTime_sum, method)
            paramsInt.interleaveTime_sum.(method) = 0;
        end
        if ~isfield(paramsInt, 'testCount') || ~isfield(paramsInt.testCount, method)
            paramsInt.testCount.(method) = 0;
        end

        aC = []; aP = []; aQ = [];
        if isfield(paramsInt, 'arp_classC'),   aC = paramsInt.arp_classC;   end
        if isfield(paramsInt, 'arp_strideP'),  aP = paramsInt.arp_strideP;  end
        if isfield(paramsInt, 'arp_offsetsQ'), aQ = paramsInt.arp_offsetsQ; end
        [interleaved, permutation, L, K, Q, R, erM, infoNew] = ...
            interleaver_generic_pc(encoded, 'arp', padSymbol, maxExtensionPercentage, ...
                                   table_precomputed, paramsInt.permutationSeed, ...
                                   table_primes, table_factors, paramsInt);

        if erM == ""
            if length(interleaved) <= maxSize
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                interleaved_all.(method) = interleaved;
                permutation_all.(method) = permutation;
                paramsInt.permutations.(method) = permutation;
                paramsInt.info_arp = infoNew;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end

% S  (the reference matrix interleaver)
% Routed through interleaver_generic_pc, like every other method, so that the
% tic/toc below times the same call stack for all of them. The permutation is
% unchanged: the two routes were compared at all 50 sweep lengths and returned
% element-wise identical results.
%
% The parameters are passed explicitly. The generic 'S' case reads
% paramsInt.extensionPercentage, which defaults to 0, while the frame carries
% maxExtensionPercentage; the locals below put the frame budget into the struct
% handed to the dispatcher, so S keeps the budget it had. It is inert in this
% campaign - BE = 1.0000 for S in all eight sweeps, so no extension ever fired -
% but inert is not absent.
if sum(ismember(intMethods, 'S')) > 0 && (erM == "")  
    method = 'S';
    tic;
    try
        % Accumulators for this method, created on first use.
        if ~isfield(paramsInt, 'interleaveTime_sum') || ~isfield(paramsInt.interleaveTime_sum, method)
            paramsInt.interleaveTime_sum.(method) = 0;
        end
        if ~isfield(paramsInt, 'testCount') || ~isfield(paramsInt.testCount, method)
            paramsInt.testCount.(method) = 0;
        end

        % Extract S-specific parameters (same defaults as before this change)
        if isfield(paramsInt, 'minMultiplier')
            minMultiplier = paramsInt.minMultiplier;
        else
            minMultiplier = 2;
        end
        
        if isfield(paramsInt, 'pairStrategy')
            pairStrategy = paramsInt.pairStrategy;
        else
            pairStrategy = 'minSum';
        end
        
        if isfield(paramsInt, 'swapStrategy')
            swapStrategy = paramsInt.swapStrategy;
        else
            swapStrategy = 'oddOnly';
        end

        % Hand the dispatcher exactly what interleaver_S_pc used to receive.
        paramsInt_S = paramsInt;
        paramsInt_S.minMultiplier       = minMultiplier;
        paramsInt_S.pairStrategy        = pairStrategy;
        paramsInt_S.swapStrategy        = swapStrategy;
        paramsInt_S.extensionPercentage = maxExtensionPercentage;

        [interleaved, permutation, L, K, Q, R, erM] = ...
            interleaver_generic_pc(encoded, 'S', padSymbol, maxExtensionPercentage, ...
                                   table_precomputed, paramsInt.permutationSeed, ...
                                   table_primes, table_factors, paramsInt_S);
        
        if erM == "" 
            if length(interleaved) <= maxSize
                paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
                interleaved_all.(method) = interleaved; 
                permutation_all.(method) = permutation; 
                paramsInt.permutations.(method) = permutation; 
                paramsInt.LsMs = L;
                paramsInt.KsMs = K;
                paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
            else
                erM = strcat(method, "-interleaved size exceeds limit");
            end
        end
    catch ME
        erM = sprintf('%s error: %s', method, ME.message);
    end
end 

% If no interleaving succeeded
if ~exist('interleaved_all', 'var')
    erM = strcat(erM, " - ", "interleaved none..");
    interleaved_all = []; 
    permutation_all = []; 
end   

%% ------------------------------------------------------------------------
%% COMPLETENESS CHECK
% Every method in intMethods must have produced a permutation. Without this,
% a method with no matching block above simply produces nothing, every OTHER
% method succeeds, and the run dies much later inside getDeintParams with
% "Unrecognized field name" - which points at the deinterleaver and wastes an
% afternoon. Ask here, where the answer is known.
if erM == ""
    missing = {};
    for iChk = 1:numel(intMethods)
        mChk = intMethods{iChk};
        if ~isfield(paramsInt, 'permutations') || ~isfield(paramsInt.permutations, mChk)
            missing{end+1} = mChk; %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        erM = sprintf(['interleave_all_pc: no block produced a permutation for: %s\n' ...
                       '  This file handles a fixed list of method names. A name in\n' ...
                       '  intMethods with no matching block here is silently ignored.\n' ...
                       '  If the name was renamed (cross -> snake), this file is stale.'], ...
                      strjoin(missing, ', '));
    end
end

end
