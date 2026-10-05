function burstConfig = configure_burst_parameters(config, interleavedSize, noiseLevel)
% Dynamically configure burst parameters based on interleaved size and noise level
% noiseLevel is a percentage (e.g., 0.05 for 5% errors)

    % Basic configuration
    burstConfig.singleBurstMode = config.singleBurst;
    burstConfig.contiguous = config.singleBurst;  % Single burst is contiguous

    % Gilbert-Elliott mode overrides the fixed single/multi placement
    burstConfig.geMode = isfield(config, 'gilbertElliott') && config.gilbertElliott;
    if burstConfig.geMode
        if isfield(config, 'ge_errProbBad'),   burstConfig.ge_errProbBad   = config.ge_errProbBad;   else, burstConfig.ge_errProbBad   = 1.0; end
        if isfield(config, 'ge_meanBurstLen'), burstConfig.ge_meanBurstLen = config.ge_meanBurstLen; else, burstConfig.ge_meanBurstLen = [];  end
        if isfield(config, 'ge_maxDraws'),     burstConfig.ge_maxDraws     = config.ge_maxDraws;     else, burstConfig.ge_maxDraws     = 50;  end
        burstConfig.singleBurstMode = false;
        burstConfig.contiguous      = false;
    end
    
    % Calculate target error count from noiseLevel (which is a percentage)
    targetNoisyCount = round(noiseLevel * interleavedSize);
    
    % Ensure minimum of 1 error
    targetNoisyCount = max(1, targetNoisyCount);
    
    % Ensure it doesn't exceed interleavedSize
    targetNoisyCount = min(targetNoisyCount, interleavedSize);
    
    % Store the target
    burstConfig.targetNoisyCount = targetNoisyCount;

    if burstConfig.geMode
        % The chain decides burst count and lengths; we only fix the target
        % rate and the acceptance band the realised count must fall into.
        % ACCEPTANCE BAND (v26). The campaign of the paper accepted a Gilbert-
        % Elliott mask as soon as its error count fell anywhere in the range of
        % the whole noise grid, [noisyRateMin, noisyRateMax]. With about three
        % bursts per frame the count is very variable, so the accepted draws
        % spread over that range in every bin and all five bins realized a mean
        % density of about 0.22 (Section IX-A of the paper). The default is now
        % a band of half a bin width around the bin's own target. Set
        % config.ge_bandMode = 'grid' to reproduce the archived campaign.
        bandMode = 'target';
        if isfield(config, 'ge_bandMode') && ~isempty(config.ge_bandMode), bandMode = config.ge_bandMode; end
        switch bandMode
           case 'grid'
              loRate = config.noisyRateMin;  hiRate = config.noisyRateMax;
           case 'target'
              if config.noiseBins > 1
                 halfBin = (config.noisyRateMax - config.noisyRateMin) / (2 * (config.noiseBins - 1));
              else
                 halfBin = 0.05 * noiseLevel;
              end
              loRate = noiseLevel - halfBin;  hiRate = noiseLevel + halfBin;
           otherwise
              error('configure_burst_parameters: unknown ge_bandMode "%s"', bandMode);
        end
        burstConfig.ge_bandMode   = bandMode;
        burstConfig.minNoisyCount = max(1, round(loRate * interleavedSize));
        burstConfig.maxNoisyCount = min(interleavedSize, round(hiRate * interleavedSize));
        burstConfig.burstCount    = config.maxBurstCount;   % nominal, sets mean burst length
        burstConfig.chunkSizes    = targetNoisyCount;       % kept for API compatibility
        burstConfig.noiseLevel     = noiseLevel;
        burstConfig.interleavedSize = interleavedSize;
        return;
    end

    if burstConfig.singleBurstMode
        % SINGLE BURST MODE
        burstConfig.burstCount = 1;
        burstConfig.chunkSizes = targetNoisyCount;  % Single chunk with all errors
        
    else
        % MULTI-BURST MODE
        % Maximum number of bursts (from config)
        maxBurstCount = min(config.maxBurstCount, floor(targetNoisyCount / 2));
        
        % Ensure at least 2 bursts for multi-burst mode
        if maxBurstCount < 2
            % Fall back to single burst if we can't have at least 2 bursts
            burstConfig.singleBurstMode = true;
            burstConfig.contiguous = true;
            burstConfig.burstCount = 1;
            burstConfig.chunkSizes = targetNoisyCount;
        else
            % Determine actual number of bursts (between 2 and maxBurstCount)
            burstCount = randi([2, maxBurstCount]);
            
            % Distribute errors among bursts (each burst >= 2)
            chunkSizes = distribute_errors_to_bursts(targetNoisyCount, burstCount);
            
            % Ensure no chunk is too small (must be at least 2)
            chunkSizes = max(chunkSizes, 2);
            
            % Store configuration
            burstConfig.burstCount = burstCount;
            burstConfig.chunkSizes = chunkSizes;
        end
    end
    
    % Store for debugging/reference
    burstConfig.noiseLevel = noiseLevel;
    burstConfig.interleavedSize = interleavedSize;
end

function chunkSizes = distribute_errors_to_bursts(totalErrors, burstCount)
    % Distribute total errors among bursts with constraint: each burst >= 2
    
    % Start with minimum size (2) for each burst
    chunkSizes = ones(1, burstCount) * 2;
    remaining = totalErrors - (burstCount * 2);
    
    if remaining < 0
        % Can't have this many bursts, adjust burst count
        burstCount = floor(totalErrors / 2);
        if burstCount < 2
            burstCount = 1;
            chunkSizes = totalErrors;
            return;
        end
        chunkSizes = ones(1, burstCount) * 2;
        remaining = totalErrors - (burstCount * 2);
    end
    
    % Distribute remaining errors randomly
    for i = 1:remaining
        burstIdx = randi([1, burstCount]);
        chunkSizes(burstIdx) = chunkSizes(burstIdx) + 1;
    end
    
    % Shuffle the chunk sizes
    chunkSizes = chunkSizes(randperm(length(chunkSizes)));
end

function burstConfig = configure_burst_parameters_old(config, interleavedSize, noiseLevel)
% Dynamically configure burst parameters based on data size and base config
     
   burstConfig.singleBurstMode = config.singleBurst;
   burstConfig.contiguous = ~config.singleBurst;
   
   burstConfig.noisyRateMin = config.noisyRateMin;
   burstConfig.noisyRateMax = config.noisyRateMax; 
   
   burstConfig.minBurstSize = 2;  % Each burst must have at least that many errors
   burstConfig.burstCount = config.maxBurstCount; % e.g., 2 or 3

   burstConfig.minNoisyCount = round(burstConfig.noisyRateMin * interleavedSize); 
   burstConfig.maxNoisyCount = round(burstConfig.noisyRateMax * interleavedSize); 

   noisyCount = round(noiseLevel * interleavedSize); 

   if burstConfig.singleBurstMode 
      burstConfig.chunkSizes(1) = noisyCount;
   else % multi-burst mode
      % adjust burst chunks
      % Check if target noisyCount is feasible
      %.....
      % if not, reduce burstConfig.burstCount and check again.....
      chunkSize = round(noisyCount / burstConfig.burstCount);
      burstConfig.chunkSizes = ones(1, burstConfig.burstCount) * chunkSize;
      if (chunkSize * burstConfig.burstCount) > noisyCount
         burstConfig.chunkSizes(end) = burstConfig.chunkSizes(end) - 1;
      end
      % assure minBurstSize
      for i=1:burstConfig.maxNoisyCount
         if burstConfig.chunkSizes(i) < burstConfig.minBurstSize
            burstConfig.chunkSizes(i) = burstConfig.minBurstSize;
         end
      end
   end
end
