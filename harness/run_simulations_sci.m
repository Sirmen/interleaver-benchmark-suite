function [results, success, paramsInt, burstConfig] = run_simulations_sci(config, params, paramsInt, tables)
% run_simulations_sci
% Scientifically controlled Monte-Carlo simulation wrapper

   success = true;
   
   % Initialize results container
   results = initResults;

   % Per-trial statistics are collected into a CELL and concatenated once, at
   % the end. They used to be appended with
   %       results.stats_all = [results.stats_all, stats_d];
   % which copies the entire accumulated struct array on every trial - cost
   % quadratic in the number of trials. At the smoke-test scale (500 trials,
   % 11.5k records) that is invisible; at 8750 trials and 201k records it
   % becomes the dominant cost and the memory churn is worse than the time.
   % A cell append only reallocates a pointer array, and one final
   % concatenation does the real work in a single pass.
   statsChunks = {};
   
   % Noise regimes (percentages)
   noiseLevels = config.noiseLevels;
   testRunsMax = config.testRunsMax;
   maxAttempts = config.noiseTryMax;
   
   % Track overall statistics
   totalValidRuns = 0;
   runs = 0;
   % Loop over all plain message sizes.
   %
   % config.sizeStep WAS IGNORED HERE. 2026.
   % ---------------------------------------------------------------------
   % This line read
   %       for N = config.sizeMin : config.sizeMax
   % with no step, so the sweep always visited EVERY integer size regardless of
   % what config.sizeStep said. The old run_simulations.m (line 13, now
   % commented out at the call site) does honour it; the _sci version that
   % replaced it dropped it.
   %
   % It was not a harmless omission, because three other places DO read the
   % field: main_simulation_wrapper prints it in the banner, and both
   % PrecomputeInterleaversGenerator and PrecomputeFactorsGenerator derive
   % their length range from it. So setting sizeStep = 9 would have built the
   % tables for a thinned grid while the sweep still asked for every size -
   % the console would report "step 9" and the run would do something else.
   %
   % It also invalidated a runtime calibration: a "10-size" test with
   % sizeStep = 100 silently ran all 991 sizes, so extrapolating it by the
   % size ratio overestimated the full sweep by two orders of magnitude.
   % ("Skipped N's: None" in the summary was the tell.)
   %
   % 2026-08: the length list now comes from getSizeList, the single owner
   % shared with PrecomputeInterleaversGenerator, so the sweep can never ask
   % the table for a length the table was not built for. It also accepts an
   % explicit config.sizeList, which is what the standards-aligned grid
   % (K = 36*(1:50) -> encoded 60..3000) needs; an arithmetic range cannot
   % express it. With no sizeList set, behaviour is exactly as before.
   [sizeVector, sizeDesc] = getSizeList(config);
   fprintf('  sweep lengths: %s\n', sizeDesc);
   tSweepStart = tic;   % for the per-length progress line

   for N = sizeVector
      % Run every simulation for testRunsMax times
      validRunsThisN = 0;
   
      % PROGRESS. The old rule was "print every 50th length", written for the
      % 991-length arithmetic grid where it fired about twenty times. On the
      % 50-length standards grid it fires exactly ONCE - at the last length -
      % so a running sweep looks indistinguishable from a hung one. That is
      % how a healthy run came to look like a hang.
      %
      % Print every length when the grid is small enough to bear it, and keep
      % the old thinning for very long grids. Elapsed time and position are
      % included so the remaining time can be extrapolated from the console
      % instead of guessed at.
      runs = runs + 1;
      everyK = 1;
      if numel(sizeVector) > 120, everyK = 50; end
      if mod(runs, everyK) == 0 || runs == 1 || runs == numel(sizeVector)
         fprintf('-- [%3d/%3d] N = %-5d  encoded %-5d  elapsed %6.1f s\n', ...
                 runs, numel(sizeVector), N, ...
                 ceil(N / config.FECk) * config.FECn, toc(tSweepStart));
      end
   
      % Initialize accumulators for this N
      errRate_woInt_all = [];
      decErrRate_all = struct();
      efficiency_all = struct();
      contribution_all = struct();
      sNoise_t = [];
      true_snr_t = [];
      
      % Initialize method structures
      methods = params.intMethods;
      for i = 1:length(methods)
         method = methods{i};
         decErrRate_all.(method) = [];
         efficiency_all.(method) = [];
         contribution_all.(method) = [];
      end

      % Loop over all noise Levels for this N
      for noiseBin = 1:length(noiseLevels) 
         noiseLevel = noiseLevels(noiseBin);
         
         % fprintf('  Noise level %.4f: ', noiseLevel);
         
         % Run every simulation for testRunsMax times
         validRunsThisNoiseLevel = 0;
         
         for run = 1:testRunsMax % run testRunsMax times for this noiseLevel
%% main single test run:             
            singleTrialFailed = true;
            totalAttempts = 0;           
            while (totalAttempts < maxAttempts) && singleTrialFailed
               totalAttempts = totalAttempts + 1;
              
               [stats_d, lastValid, paramsInt, burstConfig, erM] = run_single_trial( ...
                     N, noiseLevel, noiseBin, config, params, paramsInt, tables);
               singleTrialFailed = erM ~= "";
              
               if singleTrialFailed && totalAttempts == maxAttempts
                  fprintf(' Noise retry ');
               end
            end % while run_single_trial not ok
%%            
            if ~singleTrialFailed
               validRunsThisNoiseLevel = validRunsThisNoiseLevel + 1;
               validRunsThisN = validRunsThisN + 1;
               totalValidRuns = totalValidRuns + 1;
               
               % Store valid size
               results.testedSizes = unique([results.testedSizes, N]);
               
               % Accumulate all statistics - see statsChunks at the top
               statsChunks{end+1} = stats_d; %#ok<AGROW>

               %% Store last valid run info
               results.lastValid = lastValid;
               
               % Accumulate metrics for averaging
               errRate_woInt_all = [errRate_woInt_all, lastValid.errRate_woInt];
               sNoise_t = [sNoise_t, lastValid.noiseRatio_rcv_ns];
               true_snr_t = [true_snr_t, lastValid.true_snr];
               
               % Accumulate method-specific metrics
               for i = 1:length(methods)
                  method = methods{i};
                  decErrRate_all.(method) = [decErrRate_all.(method), lastValid.decErrRate_t.(method)];
                  %%%%% %%%%%
               end
            end
            
         end % for testRunsMax times for this noiseLevel
         
         if validRunsThisNoiseLevel == 0 % notify if missing trials
            fprintf('  No valid runs for N=%d, Noise level:%.4f \n', N, noiseLevel);
         elseif validRunsThisNoiseLevel < testRunsMax % notify if missing trials
            fprintf('  Noise level:%.4f (%d/%d valid)\n', noiseLevel, validRunsThisNoiseLevel, testRunsMax);
         end
      
      end % for noiseLevels : Loop over all noise Levels for this N
        
      %% Calculate averages for this N if we have valid data
      if validRunsThisN > 0                  

         % Store per-test-run data
         results.sNoise_t = [results.sNoise_t, sNoise_t];
         results.true_snr_t = [results.true_snr_t, true_snr_t];
         
         % Calculate and store averaged metrics for this N
         results.avNoise_all = [results.avNoise_all, mean(sNoise_t)];
         results.avSNR_all = [results.avSNR_all, mean(true_snr_t)];
         
         % Calculate average interleaving run times  
         [avIntRuntime_ns, erM] = calcAvIntRuntime_all(...
             params.intMethods, paramsInt.interleaveTime_sum, paramsInt.testCount);
         if erM == ""
             results.avIntRuntime_all = [results.avIntRuntime_all, avIntRuntime_ns];
         else
             fprintf("\n\t%s", erM);
         end
      else
         fprintf('  No valid runs for N=%d\n', N);
         results.skippedSizes = [results.skippedSizes, N];
      end % if validRunsThisN > 0 
        
    end % for N
    
    % One concatenation instead of 8750. See statsChunks at the top.
    if isempty(statsChunks)
       results.stats_all = [];
    else
       results.stats_all = [statsChunks{:}];
    end
    clear statsChunks;

    fprintf('\n=== SIMULATION COMPLETES ===\n');
    fprintf('Total valid runs: %d   (%.1f s)\n', totalValidRuns, toc(tSweepStart));
    
    if totalValidRuns == 0
        success = false;
        warning('No valid runs completed. Check configuration.');
    end
end

%%
function [stats_d, lastValid, paramsInt, burstConfig, erM] = run_single_trial( ...
               N, noiseLevel_intended, noiseBin, config, params, paramsInt, tables)
    
    erM = ""; 
    stats_d = [];
    lastValid = struct();
    burstConfig = [];
    
    try
        % Generate data with specified parameters
        [A, erM] = genUniformData(N, config);
        if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end

        % RS encode
        [encoded, ~, ~, ~, ~, ~, erM] = ...
            encoderRS_CW(A, config.base, config.eccReal, config.padSymbol);
        if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end

        lenEncoded = length(encoded);

        % Configure burst parameters for this length and noiseLevel
        burstConfig = configure_burst_parameters(config, lenEncoded, noiseLevel_intended);
        
        % Generate burst mask
        [burstMask, burstInfo, erM] = genBurstMask(lenEncoded, burstConfig);
        if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end

        % Persist what the channel ACTUALLY produced. burstConfig is stored
        % per-trial inside collectStatistics_x (stats.burstConfig), whereas
        % results.lastValid is overwritten on every trial - so anything the
        % validation/robustness pass needs must ride along here.
        burstConfig.realisedBurstInfo = burstInfo;

        % create encodedNoisy for baseline (no interleaving). We need to apply the same errors to the interleved sequences
        [encodedNoisy, erM] = injectBurstErrors_encoded(encoded, burstMask, config);
        if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end

        % RS decode (Without interleaving) - Baseline
        [decoded_woInt, ~, ~, ~, ~, ~, ~, erM] = decoderRS_CW( ...
           encodedNoisy, config.base, config.eccReal);
        if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end
        
        % Without interleaving error rate
        [~, decErrRate_woInt] = symerr(A, decoded_woInt(1:length(A)));
        if decErrRate_woInt == 0 % ensure errors exist
           erM = "decErrRate_woInt=0; retry...";
           % fprintf(strcat('\n ** ',erM,' N:',num2str(N)));  
           return;  
        end

        %%

        % Update interleaver parameters
        L = estimate_L_for_size(lenEncoded);
        K = ceil(N / L);
        paramsInt = configure_interleaver_params(paramsInt, config, encoded, params.intMethods, L, K, tables);

        % Interleave w all methods
        [interleaved_all, permutation_all, paramsInt, erM] = interleave_all_pc(params.intMethods, paramsInt, tables);
        if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end

        % Inject burst errors to all interleaved sequences
        [received_all, noiseRatio_all, erM] = injectBurstErrors_all( ...
           interleaved_all, burstMask, config);
        if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end

        % Deinterleave
        [deinterleaved_all, erM] = deinterleave_all_pc( ...
            params.intMethods, paramsInt, received_all, length(encoded));
        if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end

        % RS decode (with interleaving)
        [decoded_ns_all, ~, ~, ~, erM] = decodeRS_all( ...
            params.intMethods, deinterleaved_all, config.base, config.eccReal);
        if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end

        % With interleaving decode error rates
        [decErrRate_t, erM] = calcDecErrorRates_all(params.intMethods, decoded_ns_all, A);
        if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end
        
        % %% calc KPI metrics of this run
        % % Efficiency
        % [efficiency_t, erM] = calcEfficiency_all(...
        %     params.intMethods, decErrRate_t, decErrRate_woInt, noiseRatio_all);
        % if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end
        % 
        % % CR_adjusted (contribution)
        % [contribution_t, erM] = calcCR_all(...
        %     params.intMethods, decErrRate_t, decErrRate_woInt, noiseRatio_all, noiseLevel_intended);
        % if erM ~= ""; fprintf(strcat('\n ** ',erM,'\n'));  return;  end
% 
% % ----------------
% if isempty(erM)
%     for i = 1:length(params.intMethods)
%         m = params.intMethods{i};
% 
%         % Store as a Nx2 matrix: [MetricValue, NoiseBinIndex]
%         % Use vertical concatenation [ ; ] to add a new row per trial
%         results.avContribution_all.(m)  = [results.avContribution_all.(m);  [contribution_t.(m), noiseBin]];
%         results.avEfficiency_all.(m)    = [results.avEfficiency_all.(m);    [efficiency_t.(m),   noiseBin]];
%         results.avEffectiveness_all.(m) = [results.avEffectiveness_all.(m); [effectiveness_t.(m), noiseBin]];
%     end
% end
% ----------------

        % Collect statistics of this run 
        [stats_d, erM] = collectStatistics_all( ...
            config, params.intMethods, A, paramsInt, burstConfig, noiseBin, ...
            permutation_all, interleaved_all, ...
            decoded_ns_all, burstMask, decErrRate_woInt);
        if erM ~= ""
           fprintf(strcat('\n ** ',erM,'\n'));  return;  
        end

        % Calculate noise ratio for baseline
        [~, noiseRatio_baseLine] = symerr(encoded', encodedNoisy);
        
        % Calculate SNR for baseline
        true_snr = calculateSNR(encoded', encodedNoisy);

        % Store lastValid structure
        lastValid.L = L;
        lastValid.K = K;
        lastValid.encoded_ns = encoded;
        lastValid.rcv_enc_ns = encodedNoisy;
        lastValid.permutations = permutation_all;
        lastValid.interleaved_all = interleaved_all;

        lastValid.errRate_woInt = decErrRate_woInt;
        lastValid.decErrRate_t = decErrRate_t;
        % lastValid.efficiency_t = efficiency_t;
        % lastValid.contribution_t = contribution_t;
        
        lastValid.burstMask = burstMask; 
        lastValid.burstInfo = burstInfo;
        if isfield(burstInfo, 'realisedRate')      % Gilbert-Elliott diagnostics
           lastValid.ge_realisedRate    = burstInfo.realisedRate;
           lastValid.ge_meanBurstLen    = burstInfo.meanBurstLen_realised;
           lastValid.ge_maxBurstLen     = burstInfo.maxBurstLen;
           lastValid.ge_draws           = burstInfo.draws;
           lastValid.ge_forced          = burstInfo.forced;
        end
        
        lastValid.noiseLocations = burstMask;
        lastValid.burstSize_ns = lastValid.burstInfo.totalErrors;
        % In Gilbert-Elliott mode burstConfig.burstCount is only the NOMINAL
        % value used to set the mean burst length; the realised count comes
        % from the chain, so read it back from burstInfo.
        if isfield(burstInfo, 'burstCount')
           lastValid.burstCount_ns = burstInfo.burstCount;
        else
           lastValid.burstCount_ns = burstConfig.burstCount;
        end

        lastValid.noiseRatio_rcv_ns = noiseRatio_baseLine;
        lastValid.true_snr = true_snr;
        lastValid.noiseBin = noiseBin; % noiseBin this run belongs to

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%%%
function [encodedNoisy, erM] = injectBurstErrors_encoded(encoded, burstMask, config)
% apply equivalent errors to the encoded sequence
erM = ""; 
try    
   encodedNoisy = encoded';
   
   % Create equivalent error pattern for encoded sequence
   if length(encodedNoisy) > length(burstMask)
   % Pad burst mask for encoded sequence
   encodedBurstMask = [burstMask, zeros(1, length(encodedNoisy) - length(burstMask))];
   else
   % Use portion of burst mask
   encodedBurstMask = burstMask(1:length(encodedNoisy));
   end
   
   % Apply errors to encoded sequence
   errorPositions = find(encodedBurstMask);
   for pos = errorPositions
   currentSymbol = encodedNoisy(pos);
   attempts = 0;
   while attempts < 10
       newSymbol = randi([0, config.base - 1]);
       if newSymbol ~= currentSymbol
           encodedNoisy(pos) = newSymbol;
           break;
       end
       attempts = attempts + 1;
   end
   if attempts >= 10
       encodedNoisy(pos) = mod(currentSymbol + 1, config.base);
   end
   end
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%%
function [burstMask, burstInfo, erM] = genBurstMask(lenEncoded, burstConfig)
% Generate burst error mask for interleaved sequences
% Uses burstConfig.chunkSizes to determine burst sizes
% lenEncoded: encoded message length

erM = "";
burstMask = zeros(1, lenEncoded);
burstInfo = struct();

try
  % ---- Gilbert-Elliott: the chain draws the whole pattern ----------------
  if isfield(burstConfig, 'geMode') && burstConfig.geMode
      [burstMask, burstInfo, erM] = genGilbertElliottMask(lenEncoded, burstConfig);
      if erM ~= ""; return; end
      burstInfo.CRiguous = false;
      return;                       % skip the fixed-placement path entirely
  end

  % Get chunk sizes from configuration
  chunkSizes = burstConfig.chunkSizes;
  totalExpectedErrors = sum(chunkSizes);
  burstCount = length(chunkSizes);
  
  % Validate that we can fit all bursts
  if totalExpectedErrors > lenEncoded
      erM = sprintf('Total errors (%d) exceed sequence length (%d)', ...
                    totalExpectedErrors, lenEncoded);
      return;
  end
  
  if burstConfig.singleBurstMode || burstCount == 1
      % SINGLE CONTIGUOUS BURST
      burstSize = chunkSizes(1);
      
      if burstSize > lenEncoded
          erM = sprintf('Single burst size (%d) exceeds sequence length (%d)', ...
                        burstSize, lenEncoded);
          return;
      end
      
      % Choose random starting position
      startPos = randi([1, lenEncoded - burstSize + 1]);
      endPos = startPos + burstSize - 1;
      
      % Create contiguous burst mask
      burstMask(startPos:endPos) = 1;
      
      % Record burst information
      burstInfo.burstCount = 1;
      burstInfo.burstSizes = burstSize;
      burstInfo.burstStarts = startPos;
      burstInfo.burstEnds = endPos;
      burstInfo.totalErrors = burstSize;
      burstInfo.CRiguous = true;
      
  else
      % MULTIPLE BURSTS
      % Sort bursts by size (largest first for better placement)
      [sortedSizes, sortIdx] = sort(chunkSizes, 'descend');
      
      % Try multiple times to place all bursts
      maxAttempts = 10;
      success = false;
      
      for attempt = 1:maxAttempts
          tempMask = zeros(1, lenEncoded);
          tempStarts = zeros(1, burstCount);
          tempEnds = zeros(1, burstCount);
          
          placementSuccess = true;
          
          for b = 1:burstCount
              burstSize = sortedSizes(b);
              
              % Find all possible start positions that don't overlap
              possibleStarts = [];
              
              for startPos = 1:(lenEncoded - burstSize + 1)
                  endPos = startPos + burstSize - 1;
                  
                  % Check if this position overlaps with already placed bursts
                  overlap = any(tempMask(startPos:endPos));
                  
                  if ~overlap
                      possibleStarts = [possibleStarts, startPos];
                  end
              end
              
              if isempty(possibleStarts)
                  placementSuccess = false;
                  break;
              end
              
              % Choose random start position
              chosenStart = possibleStarts(randi(length(possibleStarts)));
              tempStarts(b) = chosenStart;
              tempEnds(b) = chosenStart + burstSize - 1;
              
              % Mark this burst in temp mask
              tempMask(tempStarts(b):tempEnds(b)) = 1;
          end
          
          if placementSuccess
              % Restore original order
              [~, reverseIdx] = sort(sortIdx);
              burstStarts = tempStarts(reverseIdx);
              burstEnds = tempEnds(reverseIdx);
              
              % Create final burst mask
              burstMask = zeros(1, lenEncoded);
              for b = 1:burstCount
                  burstMask(burstStarts(b):burstEnds(b)) = 1;
              end
              
              success = true;
              break;
          end
      end
      
      if ~success
          erM = 'Failed to place all bursts without overlap after 10 attempts';
          return;
      end
      
      % Record burst information
      burstInfo.burstCount = burstCount;
      burstInfo.burstSizes = chunkSizes;
      burstInfo.burstStarts = burstStarts;
      burstInfo.burstEnds = burstEnds;
      burstInfo.totalErrors = sum(chunkSizes);
      burstInfo.CRiguous = false;
  end
  
  % Final validation
  actualErrors = sum(burstMask);
  expectedErrors = sum(chunkSizes);
  
  if actualErrors ~= expectedErrors
      erM = sprintf('Failed to generate burst mask: expected %d errors, got %d', ...
                    expectedErrors, actualErrors);
      return;
  end
  
catch ME
  erM = sprintf('%s: Error line %d: %s', ...
                ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%%
function results = initResults()
   results = struct();
   
   % Average metrics across test runs
   results.avNoise_all = [];
   results.avSNR_all = [];
   results.stats_all = [];
   results.avInfoRate_all = [];
   results.avDecodeErrRate_all = [];
   results.avEfficiency_all = [];
   results.avContribution_all = [];
   results.avIntRuntime_all = [];

   % Per-test-run data
   results.sNoise_t = [];
   results.true_snr_t = [];
   
   % Scientific mode tracking
   results.skippedSizes = [];
   
   % Compatibility tracking (from original run_simulations)
   results.testedSizes = [];
   results.methodCompatibility = containers.Map();
   
   results.lastValid = struct();
end

%%
function [A, erM] = genUniformData(N, config)
erM = ""; A=[];
try
   % Generate random integer data in Uniform PDF 
   minVal = 0;
   maxVal = config.base - 1;
   
   A = randi([minVal, maxVal], 1, N);
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end
