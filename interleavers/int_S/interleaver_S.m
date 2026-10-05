function [vectorInterleaved, permutation, Lmin, Kmin, erM] = ...
        interleaver_S(vectorIn, padSymbol, maxExtensionPercentage, minMultiplier, ...
                      table_primes, table_factors, pairStrategy, swapStrategy)
% S-Interleaver (vectorized, equivalent to original swap-based version)
% R. Tanju Sirmen – 2025
%
% Args:
%   pairStrategy : 'minSum' or 'minL'
%   swapStrategy : 'oddOnly' or 'alternate'
%   minMultiplier: choose the pairs from (min L >= minMultiplier)
%   table_primes, table_factors: lookup tables for factorization speedup
%
% The permutation is *identical* to the reference swapRowsOddEven/swapColsOddEven
% version (v1) but executes much faster.

% ------------------ Initialization ------------------
erM = ""; vectorInterleaved = []; permutation = []; Lmin = 0; Kmin = 0;

if nargin < 5 || isempty(minMultiplier), minMultiplier = 0; end
if nargin < 8, swapStrategy = 'oddOnly'; end
if nargin < 7, pairStrategy = 'minSum'; end

pairStrategy  = lower(pairStrategy);
swapStrategy  = lower(swapStrategy);
minMultiplier = max(2, minMultiplier);

if ~isnumeric(vectorIn) || isempty(vectorIn)
    erM = "Input must be a non-empty numeric vector"; return;
end
if ~ismember(pairStrategy, ["minsum","minl"])
    erM = "Invalid pairStrategy"; return;
end
if ~ismember(swapStrategy, ["oddonly","alternate"])
    erM = "Invalid swapStrategy"; return;
end

vectorIn = vectorIn(:)'; 
N = length(vectorIn);

% ------------------ Factor selection ------------------
try
    [Lmin, Kmin, erM] = getLK_S_min(N, minMultiplier, table_primes, table_factors, pairStrategy);
    if erM ~= ""
        erM = strcat("Error in interleaver_S:\n",erM);
        return;
    end

    adjustedN = Lmin * Kmin;

    if adjustedN > floor(N * (1 + maxExtensionPercentage))
        erM = sprintf('Extension exceeds maxExtensionPercentage (%.2f%%)', maxExtensionPercentage * 100);
        Lmin = 0; Kmin = 0; return;
    end

    % pad, if needed
    if adjustedN > N
        vectorIn(end+1:adjustedN) = padSymbol;
    end

    % generate permutation
    permutation = getPermutation_S_min(adjustedN, Lmin, swapStrategy);

    % interleave
    vectorInterleaved = vectorIn(permutation); 
    
    % Ensure outputs are row vectors
    if iscolumn(vectorInterleaved)
        vectorInterleaved = vectorInterleaved';
    end
    if iscolumn(permutation)
        permutation = permutation';
    end

catch ME
    erM = sprintf("Error in interleaver_S: %s", ME.message);
end
end


%% ------------------------------------------------------------------------
function permutation = getPermutation_S_min(N, L, swapStrategy)
   K = N / L;
   
   % Create index matrix
   indices = reshape(1:N, K, L)';  % L x K
   
   % set swapping strategy
   swapOdd_Rows = true;    % ODD rows only
   swapOdd_Cols = true;    % ODD columns only
   if swapStrategy == "alternate"
      swapOdd_Cols = false;   % EVEN columns only
   end

   % Swap rows
   [indices, erM] = swapRowsOddEven(indices, swapOdd_Rows);
   if erM ~= ""
      error(strcat("err in getPermutation_S_enhanced-swap-rows:\n", erM))
   end
   
   % Swap columns 
   [indices, erM] = swapColsOddEven(indices, swapOdd_Cols);
   if erM ~= ""
      error(strcat("err in getPermutation_S_enhanced-swap-cols:\n", erM))
   end
   
   % Flatten to get permutation
   permutation = reshape(indices, 1, []);

   % % if swapStrategy == "alternate"
   % %%% swap positions of min separated points w positions of max-separated points
   % [permutation, erM] = swapSepMinMax(permutation); 
   % if erM ~= ""; return; end
   % % end
end
