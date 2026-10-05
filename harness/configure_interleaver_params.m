function paramsInt = configure_interleaver_params(paramsInt, config, encoded, intMethods, L, K, tables)
% function paramsInt = configure_interleaver_params(config, encoded, interleaverSizes)

   % Calculate dynamic parameters based on encoded length
   encodedLen = length(encoded);

   % Set up interleaving parameters
   paramsInt.base = config.base;
   paramsInt.encoded = encoded;
   paramsInt.maxExtensionPercentage = config.maxExtensionPercentage;
   paramsInt.maxSize = length(encoded) * (1 + config.maxExtensionPercentage);
   paramsInt.L = L;
   paramsInt.K = K;
   paramsInt.padSymbol = config.padSymbol;
   paramsInt.eccReal = config.eccReal;

   % Create interleaver parameters with dynamic sizing
   % paramsInt.base = config.base;
   % paramsInt.encoded = encoded;
   % paramsInt.padSymbol = config.padSymbol;
   % paramsInt.eccReal = config.eccReal;
   % paramsInt.interleaverSizes = interleaverSizes;
   
%%% %%%%  % High-spread reference interleavers (journal version)
   % S-Random (Divsalar & Pollara). [] lets the method pick floor(sqrt(N/2))-1,
   % the largest spread the greedy search reaches reliably. Generation is
   % O(N^2) but cached per (N,S,seed) inside interleaver_srandom.
   paramsInt.srandom_spreadS = [];
   paramsInt.srandom_seed    = 2106;
   % Golden relative prime (Crozier)
   paramsInt.goldenRP_offset = 0;
   % Dithered Relative Prime (Crozier & Guinand, VTC 2001-Fall)
   % LEAVE THESE EMPTY. The dither period must DIVIDE N - "K must be a
   % multiple of both R and W" - so a hard-coded 8 fails at every length that
   % 8 does not divide (L = 60, 180, 300, ...). Empty lets local_period pick
   % from the published set {16,8,4} by Crozier's own size guidance. The old
   % drp_seed is gone: the canonical file has no RNG, the dithers come from a
   % deterministic search, so a seed would be a knob with nothing behind it.
   paramsInt.drp_ditherM     = [];     % [] -> {16,8,4} by size, must divide N
   paramsInt.drp_strideP     = [];     % [] -> searched under Crozier's S_new

   % Almost Regular Permutation (IEEE 802.16 / DVB-RCS)
   % PUBLISHED PARAMETERS ONLY. C is fixed at 4 (the standardised value) and
   % arp_classC no longer exists - passing anything else is refused, not
   % honoured. Empty stride/offsets mean "use the 802.16 table"; at a length
   % the table does not cover, the method returns an error on purpose. See
   % interleaver_arp.m for why nothing is derived.
   paramsInt.arp_strideP     = [];     % [] -> IEEE 802.16 table
   paramsInt.arp_offsetsQ    = [];     % [] -> IEEE 802.16 table

%%% %%%%  % S parameters
   paramsInt.minMultiplier = 3;
   paramsInt.pairStrategy = "minSum"; % "minL"; % 
   paramsInt.swapStrategy = "oddOnly";
   % paramsInt.S_balance_factor = 0.7;
   paramsInt.extensionPercentage = config.extensionPercentage_S;
   % control extensionPercentage
   if paramsInt.extensionPercentage > paramsInt.maxExtensionPercentage
      paramsInt.extensionPercentage = paramsInt.maxExtensionPercentage;
   end
%    % Load primes and factors data (to speed up S-type interleavers)
%    [paramsInt.table_primes, paramsInt.table_factors, erM] = PrimeFactorLoader(dataDir_PrimeFactor);
%    if erM ~=  ""
%        fprintf(erM);
%        return
%    else
%        fprintf("Loaded primes and factors data");
%    end
   %%% %%%%  %

   % --- REMOVED: Lmatrix / Kmatrix / hStep / hStep_hs -------------------
   % All four were computed here and never read. interleaver_matrix returns its
   % own dimensions (overwritten at interleave_all_pc), and interleaver_helical
   % / interleaver_helicalScan hardcode step = 1. Worse, Lmatrix and Kmatrix
   % were mutually incoherent - Lmatrix ~ sqrt(encodedLen) but Kmatrix ~
   % encodedLen/L with L the RS-derived value, so Lmatrix*Kmatrix ~= encodedLen.
   % Reporting these formulas in the paper's experimental setup would be a false
   % methods statement, so they are gone rather than left as decoration.

   % Frequency / time interleaver grid: both derive Nsc x Nsym from the frame
   % length themselves, so no parameter is needed here. `depth` (time) and the
   % subcarrier stride (frequency) default to values coprime to their axis.
   % STALE COMMENT REMOVED. This used to read "[] -> coprime to Nsym, near
   % Nsym/phi", which described the golden-ratio depth rule - Crozier's rule,
   % imported into a time interleaver where it does not belong, and one of the
   % four places the same published idea had entered the benchmark. The
   % canonical time interleaver uses depth = 1, the textbook value.
   paramsInt.time_depth = [];        % [] -> depth = 1 (canonical)

   % d-dimensional block interleaver order. NOT Blaum-Bruck-Vardy - that
   % citation was wrong and has been removed from interleaver_multiDim.m; the
   % construction is the d-axis generalisation of the block interleaver, and
   % the axis order is REVERSED (the d-dimensional transpose), not rotated.
   % d = 2 would just be the block interleaver, which is already in the set.
   % This value is a declared choice of ours and belongs in the provenance
   % table, not in a comment only.
   paramsInt.multiDim_nDims = 3;
   
   % Convolutional parameters
   % paramsInt.bufferRows = max(2, round(paramsInt.L * 0.6));
   % paramsInt.bufferSlope = max(2, round(paramsInt.bufferRows * 1.8));
   [M, D, erM] = calc_optimal_M_D_convolutional(encodedLen, tables.table_primes);
   if erM ~= "";  error(strcat('Error in configure_interleaver_params: ', erM));  end
   paramsInt.bufferRows = M;  % number of parallel shift registers or branches
   paramsInt.bufferSlope = D; % delay increment applied between successive branches. Delay of branch i is (i-1)xD

   % Chaotic parameters
   paramsInt.rChaotic = 3.9;
   % v2: blockCM and convCM are sized to the code, so they need n
   paramsInt.FECn = config.FECn;
   paramsInt.xChaotic = 0.5;
  
   % Prime (exponential / primitive-root) interleaver: the modulus is the
   % smallest prime P with P-1 >= N and the primitive root is chosen by
   % maximising spread, both inside the method. primeN / shiftPrm were unused.
  
   % Algebraic (QPP). The old option block is gone: every field in it fed the
   % scoring code that operated on the SORTED permutation, i.e. on a constant,
   % and the comments contradicted the values (w_min = 50 was described as
   % "less weight on min separation" while being 100x w_mean; earlyAcceptScore
   % = 0.8 was compared against an unnormalised score of order 1e2..1e5).
   % Parameter selection is now the literature rule - maximise the spread
   % D(pi) = min(|i-j| + |pi(i)-pi(j)|) over valid (f1,f2).
   paramsInt.algOpts = struct();
   paramsInt.algOpts.searchWindow = 16;   % window for the spread evaluation
   
   % Other parameters
   paramsInt.blockSize = max(2, round(paramsInt.L/2));
   paramsInt.blockSize_1 = max(4, round(paramsInt.L*2));
   paramsInt.permutationSeed = 2106; % randi([1000, 3000]); % for freqRandom, random, etc
   paramsInt.maxSize = 10000;
   
   if ~isfield(paramsInt, 'interleaveTime_sum')
      % initiate interleaving Times
      for i = 1:length(intMethods)
         method = intMethods{i};
         paramsInt.interleaveTime_sum.(method) = 0;
         paramsInt.testCount.(method) = 0;
      end
   end

end
