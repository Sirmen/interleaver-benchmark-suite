function [deinterleaved_all, erM] = deinterleave_all(intMethods, paramsInt, received_all, lenEncoded)
try
   erM=""; deinterleaved_all=[];
   %%%
   %%% ---- High-spread reference interleavers (journal version) --------------
   %  Pure permutation methods: deinterleaver_universal inverts them from the
   %  stored permutation alone, so no method-specific deinterleaver is needed.
   if sum(ismember(intMethods, 'srandom')) > 0 && erM == ""
      method = 'srandom';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'goldenRP')) > 0 && erM == ""
      method = 'goldenRP';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'drp')) > 0 && erM == ""
      method = 'drp';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'arp')) > 0 && erM == ""
      method = 'arp';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'random')) > 0
      method = 'random';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      % permutationSeed = paramsInt.permutationSeed; % extract deint parameters
      % [deintA, erM] = deinterleaver_random(received, permutationSeed); 
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'matrix')) > 0 && erM == ""
      method = 'matrix';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      % L = paramsInt.L; % extract deint parameters
      % [deintA, erM] = deinterleaver_matrix(received, L);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'convolutional')) > 0 && erM == ""
      method = 'convolutional';
      % extract deint parameters
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      % bufferRows = paramsInt.bufferRows_conv;
      % bufferSlope = paramsInt.bufferSlope_conv;
      % [deintA, erM] = deinterleaver_convolutional(received, ...
      %   'Permutation', permutation, 'BufferRows', bufferRows, 'BufferSlope', bufferSlope, 'OriginalLength', lenEncoded, 'Verbose', false);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'helicalScan')) > 0 && erM == ""
      method = 'helicalScan';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'helical')) > 0 && erM == ""
      method = 'helical';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_helical(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'turbo')) > 0 && erM == ""
      method = 'turbo';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      % blockSize = paramsInt.blockSize; % extract deint parameters
% strategy_info = paramsInt.turbo_strategy_info;
% [deintA, erM] = deinterleaver_turbo_fast(received, strategy_info);
      % [deintA, erM] = deinterleaver_turbo(received, blockSize, lenEncoded);  
      % [deintA, erM] = deinterleaver_turbo(received, strategy_info);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'algebraic')) > 0 && erM == ""
      method = 'algebraic';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      % Lalg = paramsInt.Lalg; % extract deint parameters
      % Kalg = paramsInt.Kalg; % extract deint parameters
      % padSymbol = paramsInt.padSymbol; % extract deint parameters
      % [deintA, erM] = deinterleaver_algebraic(received, Lalg, Kalg, padSymbol, lenEncoded);  
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'block')) > 0 && erM == ""
      method = 'block';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      % L = paramsInt.L; % extract deint parameters
      % [deintA, erM] = deinterleaver_block(received, L); 
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'cross')) > 0 && erM == ""
      method = 'cross';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      % [deintA, erM] = deinterleaver_cross(received, L);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'spiral')) > 0 && erM == ""
      method = 'spiral';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'diagonal')) > 0 && erM == ""
      method = 'diagonal';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'hierarchical')) > 0 && erM == ""
      method = 'hierarchical';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'multiDim')) > 0 && erM == ""
      method = 'multiDim';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      % L = paramsInt.L; % extract deint parameters
      % [deintA, erM] = deinterleaver_multiDim(received, paramsInt.multiDimRowPerm, paramsInt.multiDimColPerm, L);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'latinSquare')) > 0 && erM == ""
      method = 'latinSquare';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'time')) > 0 && erM == ""
      method = 'time';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
   if sum(ismember(intMethods, 'freqRandom')) > 0 && erM == ""
      method = 'freqRandom';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      % L = paramsInt.L; % extract deint parameters
      % permutationSeed = paramsInt.permutationSeed;
      % [deintA, erM] = deinterleaver_frequency(received, L, permutationSeed);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end  
   end
   if sum(ismember(intMethods, 'freqDeterm')) > 0 && erM == ""
      method = 'freqDeterm';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      % L = paramsInt.L; % extract deint parameters
      % permutationSeed = paramsInt.permutationSeed;
      % [deintA, erM] = deinterleaver_frequency(received, L, permutationSeed);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end  
   end
   if sum(ismember(intMethods, 'chaotic')) > 0 && erM == ""
      method = 'chaotic';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      rChaotic = paramsInt.rChaotic; % extract deint parameters
      xChaotic = paramsInt.xChaotic; % extract deint parameters
      [deintA, erM] = deinterleaver_chaotic(received, rChaotic, xChaotic);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end  
   end
   if sum(ismember(intMethods, 'prime')) > 0 && erM == ""
      method = 'prime';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end  
   end
%%%%%%%%%
   if sum(ismember(intMethods, 'S')) > 0 && erM == ""
      method = 'S';
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
%%%%%%%%%
   if erM ~= ""
      erM = strcat(upper(method), " - ",erM);
   end
catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

function [permutation, received] = getDeintParams(paramsInt, received_all, method)
% extract params or this method
   permutation = paramsInt.permutations.(method); 
   received = received_all.(method); % extract received sequence
end