function [interleaved_all, permutation_all, paramsInt, erM] = interleave_all(intMethods, paramsInt)
% applies interleaving to all requested interleaving methods
   %%%
   erM = ""; % assume ok

   %% extract interleaving parameters
   base = paramsInt.base; 
   encoded = paramsInt.encoded; 
   maxSize = paramsInt.maxSize; 
   L = paramsInt.L; 
   K = paramsInt.K; 
   padSymbol = paramsInt.padSymbol; 
   maxExtensionPercentage = paramsInt.maxExtensionPercentage;
   
   %% interleave
   if sum(ismember(intMethods, 'random')) > 0
      method = 'random';
      tic;
      permutationSeed = paramsInt.permutationSeed; % extract additional interleaving parameters
      [interleaved, permutation, erM] = interleaver_random(encoded, L, permutationSeed, padSymbol, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'matrix')) > 0 && (erM == "")  
      method = 'matrix';
      tic;
      [interleaved, permutation, Lmatrix, Kmatrix, erM] = interleaver_matrix(encoded, padSymbol, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.Lmatrix = Lmatrix;  
            paramsInt.Kmatrix = Kmatrix;  
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'convolutional')) > 0 && (erM == "")  
      method = 'convolutional';
      tic;
      bufferRows = paramsInt.bufferRows; % extract additional interleaving parameters
      bufferSlope = paramsInt.bufferSlope; % extract additional interleaving parameters
      [interleaved, permutation, bufferRows_conv, bufferSlope_conv, erM] = ...
          interleaver_convolutional(encoded, bufferRows, bufferSlope, padSymbol, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.bufferRows_conv = bufferRows_conv;  
            paramsInt.bufferSlope_conv = bufferSlope_conv;  
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'helicalScan')) > 0 && (erM == "")  
      method = 'helicalScan';
      tic;
      [interleaved, permutation, LhelicalScan, KhelicalScan, erM] = interleaver_helicalScan(encoded, padSymbol, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.LhelicalScan = LhelicalScan;  
            paramsInt.KhelicalScan = KhelicalScan;  
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'helical')) > 0 && (erM == "")  
      method = 'helical';
      tic;
      [interleaved, permutation, Lhelical, Khelical, erM] = interleaver_helical(encoded, padSymbol, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.Lhelical = Lhelical;  
            paramsInt.Khelical = Khelical;  
            paramsInt.permutations.(method) = permutation; 
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'turbo')) > 0 && (erM == "")  
      method = 'turbo';
      tic;
      blockSize = paramsInt.blockSize; % extract additional interleaving parameters
      [interleaved, permutation, strategy_info, erM] = interleaver_turbo(encoded, blockSize, padSymbol, maxExtensionPercentage);
      % [interleaved, permutation, strategy_info, erM] = interleaver_turbo_fast(encoded, blockSize, padSymbol, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.turbo_strategy_info = strategy_info;  
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'algebraic')) > 0 && (erM == "") 
      method = 'algebraic';
      table_primes = paramsInt.table_primes;
      table_factors = paramsInt.table_factors;
      algOpts = paramsInt.algOpts;
      tic;
      [interleaved, permutation, Lalg, Kalg, debugInfo, erM] = interleaver_algebraic(encoded, padSymbol, maxExtensionPercentage, table_primes, table_factors, algOpts);
      
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.Lalg = Lalg;  
            paramsInt.Kalg = Kalg;  
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'block')) > 0 && (erM == "")  
      method = 'block';
      tic;
      % [interleaved, permutation, erM] = interleaver_block(encoded, L, padSymbol);
      [interleaved, permutation, erM] = interleaver_block(encoded, L, padSymbol, maxExtensionPercentage); 
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'cross')) > 0 && (erM == "")  
      method = 'cross';
      table_primes = paramsInt.table_primes;
      table_factors = paramsInt.table_factors;
      tic;
      [interleaved, permutation, Lcross, Kcross, erM] = ...
         interleaver_cross(encoded, padSymbol, maxExtensionPercentage, table_primes, table_factors);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved;  
            permutation_all.(method) = permutation;  
            paramsInt.permutations.(method) = permutation; 
            paramsInt.Lcross = Lcross;  
            paramsInt.Kcross = Kcross;  
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'spiral')) > 0 && (erM == "")  
      method = 'spiral';
      tic;
      % Lx = round(sqrt(length(encoded)));
      % [interleaved, permutation, Lspiral, Kspiral, erM] = interleaver_spiral_251125(encoded, Lx, padSymbol, maxExtensionPercentage);
      [interleaved, permutation, Lspiral, Kspiral, erM] = interleaver_spiral(encoded, padSymbol, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.Lspiral = Lspiral;  
            paramsInt.Kspiral = Kspiral;  
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'diagonal')) > 0 && (erM == "")  
      method = 'diagonal';
      tic;
      minMultiplier = 2;
      [Ldiagonal, Kdiagonal] = getLK_S(length(encoded), 0, minMultiplier);
      [interleaved, permutation, erM] = interleaver_diagonal(encoded, Ldiagonal, Kdiagonal, padSymbol, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.Ldiagonal = Ldiagonal;  
            paramsInt.Kdiagonal = Kdiagonal;  
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'hierarchical')) > 0 && (erM == "")  
      method = 'hierarchical';
      % table_factors_precomp = paramsInt.table_factors_precomp;
      tic;
      [interleaved, permutation, Lhierarchical, Khierarchical, Qhierarchical, Rhierarchical, erM] = ...
         interleaver_hierarchical(encoded, padSymbol, maxExtensionPercentage); % , table_factors_precomp);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.Lhierarchical = Lhierarchical;  
            paramsInt.Khierarchical = Khierarchical;  
            paramsInt.Qhierarchical = Qhierarchical;  
            paramsInt.Rhierarchical = Rhierarchical;  
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = "hierarchical interleaved size exceeds limit";
         end
      end
   end
   if sum(ismember(intMethods, 'multiDim')) > 0 && (erM == "")  
      method = 'multiDim';
      tic;
      % [interleaved, permutation, multiDimRowPerm, multiDimColPerm, erM] = interleaver_multiDim(encoded, L, padSymbol, maxExtensionPercentage);
      [interleaved, permutation, LmultiDim, KmultiDim, erM] = interleaver_multiDim(encoded, padSymbol, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation;  
            paramsInt.permutations.(method) = permutation; 
            % paramsInt.multiDimRowPerm = multiDimRowPerm;  
            % paramsInt.multiDimColPerm = multiDimColPerm;  
            paramsInt.LmultiDim = LmultiDim;  
            paramsInt.KmultiDim = KmultiDim;  
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'latinSquare')) > 0 && (erM == "")  
      method = 'latinSquare';
      tic;
      [interleaved, permutation, Llatin, Klatin, erM] = interleaver_latinSquare(encoded, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation;  
            paramsInt.permutations.(method) = permutation; 
            paramsInt.Llatin = Llatin;
            paramsInt.Klatin = Klatin;
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = "latinSquare interleaved size exceeds limit";
         end
      end
   end
   if sum(ismember(intMethods, 'time')) > 0 && (erM == "")  
      method = 'time';
      tic;
      [interleaved, permutation, Ltime, Ktime, erM] = interleaver_time(encoded, padSymbol, maxExtensionPercentage);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved;  
            permutation_all.(method) = permutation;  
            paramsInt.permutations.(method) = permutation; 
            paramsInt.Ltime = Ltime;
            paramsInt.Ktime = Ktime;
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'freqRandom')) > 0 && (erM == "")  
      method = 'freqRandom';
      tic;
      interleaving_mode = 'random';
      permutationSeed = paramsInt.permutationSeed; % extract additional interleaving parameters
      [interleaved, permutation, erM] = interleaver_frequency(encoded, L, padSymbol, permutationSeed, maxExtensionPercentage, interleaving_mode);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'freqDeterm')) > 0 && (erM == "")  
      method = 'freqDeterm';
      tic;
      interleaving_mode = 'deterministic';
      permutationSeed = paramsInt.permutationSeed; % extract additional interleaving parameters
      [interleaved, permutation, erM] = interleaver_frequency(encoded, L, padSymbol, permutationSeed, maxExtensionPercentage, interleaving_mode);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation;  
            paramsInt.permutations.(method) = permutation; 
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'chaotic')) > 0 && (erM == "")  
      method = 'chaotic';
      tic;
      rChaotic = paramsInt.rChaotic; % extract additional interleaving parameters
      xChaotic = paramsInt.xChaotic; % extract additional interleaving parameters
      [interleaved, permutation, erM] = interleaver_chaotic(encoded, rChaotic, xChaotic);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved;  
            permutation_all.(method) = permutation;  
            paramsInt.permutations.(method) = permutation; 
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end
   if sum(ismember(intMethods, 'prime')) > 0 && (erM == "")  
      method = 'prime';
      table_primes = paramsInt.table_primes;
      tic;
      [interleaved, permutation, erM] = interleaver_prime(encoded, padSymbol, maxExtensionPercentage, table_primes);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = "prime interleaved size exceeds limit";
         end
      end
   end
%%%%%%%%%%%%%%%%%%%%%%%   
   %%% ---- High-spread reference interleavers (journal version) --------------
   %  All four operate at the exact input length (no padding), so BE = 1.0, and
   %  all four return a GATHER permutation (interleaved = encoded(permutation)),
   %  so deinterleave_all can use deinterleaver_universal with no extra state.

   if sum(ismember(intMethods, 'srandom')) > 0 && (erM == "")
      method = 'srandom';
      tic;
      spreadS = []; srSeed = 2106;
      if isfield(paramsInt, 'srandom_spreadS'), spreadS = paramsInt.srandom_spreadS; end
      if isfield(paramsInt, 'srandom_seed'),    srSeed  = paramsInt.srandom_seed;    end
      [interleaved, permutation, infoSR, erM] = interleaver_srandom(encoded, spreadS, srSeed);
      if erM == ""
         if length(interleaved) <= maxSize % if interleaved size is in limits
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            interleaved_all.(method) = interleaved;
            permutation_all.(method) = permutation;
            paramsInt.permutations.(method) = permutation;
            paramsInt.info_srandom = infoSR;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end

   if sum(ismember(intMethods, 'goldenRP')) > 0 && (erM == "")
      method = 'goldenRP';
      tic;
      gOffset = 0;
      if isfield(paramsInt, 'goldenRP_offset'), gOffset = paramsInt.goldenRP_offset; end
      [interleaved, permutation, infoGRP, erM] = interleaver_goldenRP(encoded, gOffset);
      if erM == ""
         if length(interleaved) <= maxSize % if interleaved size is in limits
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            interleaved_all.(method) = interleaved;
            permutation_all.(method) = permutation;
            paramsInt.permutations.(method) = permutation;
            paramsInt.info_goldenRP = infoGRP;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end

   if sum(ismember(intMethods, 'drp')) > 0 && (erM == "")
      method = 'drp';
      tic;
      dW = 8; dSeed = 2106;
      if isfield(paramsInt, 'drp_ditherW'), dW    = paramsInt.drp_ditherW; end
      if isfield(paramsInt, 'drp_seed'),    dSeed = paramsInt.drp_seed;    end
      [interleaved, permutation, infoDRP, erM] = interleaver_drp(encoded, dW, dSeed);
      if erM == ""
         if length(interleaved) <= maxSize % if interleaved size is in limits
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            interleaved_all.(method) = interleaved;
            permutation_all.(method) = permutation;
            paramsInt.permutations.(method) = permutation;
            paramsInt.info_drp = infoDRP;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end

   if sum(ismember(intMethods, 'arp')) > 0 && (erM == "")
      method = 'arp';
      tic;
      aC = []; aP = []; aQ = [];
      if isfield(paramsInt, 'arp_classC'),   aC = paramsInt.arp_classC;   end
      if isfield(paramsInt, 'arp_strideP'),  aP = paramsInt.arp_strideP;  end
      if isfield(paramsInt, 'arp_offsetsQ'), aQ = paramsInt.arp_offsetsQ; end
      [interleaved, permutation, infoARP, erM] = interleaver_arp(encoded, aC, aP, aQ);
      if erM == ""
         if length(interleaved) <= maxSize % if interleaved size is in limits
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            interleaved_all.(method) = interleaved;
            permutation_all.(method) = permutation;
            paramsInt.permutations.(method) = permutation;
            paramsInt.info_arp = infoARP;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end

   % if sum(ismember(intMethods, 'S')) > 0 && (erM == "")  
   if sum(ismember(intMethods, 'S')) > 0 && (erM == "")  
      method = 'S';
      table_primes = paramsInt.table_primes;
      table_factors = paramsInt.table_factors;
      extensionPercentage = paramsInt.extensionPercentage; % extract additional interleaving parameters
      % minBlockSize = paramsInt.L; % use min L
      minBlockSize = paramsInt.minMultiplier; % 3 / 5 / 7 / ...
      pairStrategy = paramsInt.pairStrategy; % "minSum" or minL
      swapStrategy = paramsInt.swapStrategy; % "oddOnly" or ...
      tic;
      [interleaved, permutation, LsMs, KsMs, erM] = ...
         interleaver_S(encoded, padSymbol, extensionPercentage, minBlockSize, table_primes, table_factors, pairStrategy, swapStrategy);
      if erM == "" 
         if length(interleaved) <= maxSize % if interleaved size is in limits
            paramsInt.interleaveTime_sum.(method) = paramsInt.interleaveTime_sum.(method) + toc;
            interleaved_all.(method) = interleaved; 
            permutation_all.(method) = permutation; 
            paramsInt.permutations.(method) = permutation; 
            paramsInt.LsMs = LsMs;
            paramsInt.KsMs = KsMs;
            paramsInt.testCount.(method) = paramsInt.testCount.(method) + 1;
         else
            erM = strcat(method, "-interleaved size exceeds limit");
         end
      end
   end 
   
   % if no iterleaving succeeded then
   if ~exist('interleaved_all', 'var')
      erM = strcat(erM, " - ", "interleaved none..");
      interleaved_all=[]; permutation_all=[]; 
   end   
end