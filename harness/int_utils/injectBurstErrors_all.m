function [received_all, noiseRatio_all, erM] = injectBurstErrors_all(...
    interleaved_all, burstMask, config)
% Inject burst errors to all interleaved sequences using the same burst mask
erM = "";
received_all = struct();
noiseRatio_all = struct();
    
try
   % Get all methods
   methods = fieldnames(interleaved_all);
   
   % Apply errors to each method
   for i = 1:length(methods)
      method = methods{i};
      interleaved = interleaved_all.(method);
      
      % Create copy for received sequence
      received = interleaved;
      
      % Determine effective burst mask for this method
      if length(interleaved) > length(burstMask)
          effectiveMask = [burstMask, zeros(1, length(interleaved) - length(burstMask))];
      else
          effectiveMask = burstMask(1:length(interleaved));
      end
      
      % Apply errors at mask positions
      errorPositions = find(effectiveMask);
      errorCount = 0;
      
      for pos = errorPositions
          % Generate a random symbol different from the current one
          currentSymbol = interleaved(pos);
          attempts = 0;
          while attempts < 10
              newSymbol = randi([0, config.base - 1]);
              if newSymbol ~= currentSymbol
                  received(pos) = newSymbol;
                  errorCount = errorCount + 1;
                  break;
              end
              attempts = attempts + 1;
          end
          
          if attempts >= 10
              % Fallback
              received(pos) = mod(currentSymbol + 1, config.base);
              errorCount = errorCount + 1;
          end
      end
      
      % Calculate noise ratio
      noiseRatio = errorCount / length(interleaved);
      
      % Store results
      received_all.(method) = received;
      noiseRatio_all.(method) = noiseRatio;
   end
     
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%%%%%%%%%%%%%%
